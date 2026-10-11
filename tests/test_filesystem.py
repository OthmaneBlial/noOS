import pathlib
import struct
import tempfile
from qemu import Machine, ROOT
from data_image import empty_volume, checksum


def active_metadata(raw):
    candidates = []
    for bank in (0, 1):
        data = bytearray(raw[bank*2560:(bank+1)*2560])
        stored = struct.unpack_from("<I", data, 12)[0]
        struct.pack_into("<I", data, 12, 0)
        if checksum(data) == stored:
            candidates.append((struct.unpack_from("<I", data, 8)[0], bank, data))
    return max(candidates)


with tempfile.TemporaryDirectory() as directory:
    disk = pathlib.Path(directory) / "persistent.img"
    disk.write_bytes(empty_volume())
    with Machine(data_disk=disk) as machine:
        machine.wait("noOS> ")
        assert "Persistent noFS mounted on IDE slave" in machine.output()
        machine.shell("mkdir notes", "Created.")
        machine.shell("cd notes")
        machine.shell("pwd", "/notes\n")
        machine.shell("touch note.txt", "Created.")
        machine.shell("write note.txt persists across QEMU", "Written and flushed")
        machine.shell("cat note.txt", "persists across QEMU\n")
        machine.shell("write note.txt replaced text", "Written and flushed")
        machine.shell("cd ..")
        machine.shell("rm notes", "Directory is not empty")
        machine.shell("mkdir notes", "Name already exists")
        machine.shell("mkdir bad/name", "Usage: mkdir/touch")
        machine.shell("mkdir initrd", "Name already exists")
        machine.shell("cd /initrd")
        machine.shell("touch denied", "Write unavailable")
        machine.shell("cat hello.txt", "Hello from the noOS initrd.")
        machine.shell("cd /")
    raw = disk.read_bytes()
    generation, bank, metadata = active_metadata(raw)
    assert generation >= 4
    slot = next(i for i in range(32) if metadata[512+i*64+16:512+i*64+48].split(b"\0")[0] == b"note.txt")
    size, data_bank = struct.unpack_from("<II", metadata, 512+slot*64+8)
    lba = 16 + slot * 16 + data_bank * 8
    assert raw[lba*512:lba*512+size] == b"replaced text"
    tampered = bytearray(raw)
    tampered[lba*512] ^= 1
    bad_data = pathlib.Path(directory) / "bad-data.img"
    bad_data.write_bytes(tampered)
    with Machine(data_disk=bad_data) as machine:
        machine.wait("noOS> ")
        machine.shell("cd notes")
        machine.shell("cat note.txt", "checksum mismatch; contents not displayed")
    with Machine(data_disk=disk) as machine:
        machine.wait("noOS> ")
        machine.shell("cd notes")
        machine.shell("cat note.txt", "replaced text\n")
        machine.shell("rm note.txt", "Removed.")
        machine.shell("cd ..")
        machine.shell("rm notes", "Removed.")
        machine.shell("cd notes", "not found")
        for index in range(32):
            machine.shell(f"touch f{index}", "Created.")
        machine.shell("touch overflow", "table is full")
        machine.shell("rm f0", "Removed.")
        machine.shell("touch reused", "Created.")
    with Machine(data_disk=disk) as machine:
        machine.wait("noOS> ")
        machine.shell("ls", "reused")
        machine.shell("cat f0", "not found")

    # A corrupt metadata bank must not be trusted; the independently valid other bank survives.
    raw = bytearray(disk.read_bytes())
    _, bank, _ = active_metadata(raw)
    raw[bank * 2560 + 12] ^= 0x80
    recover = pathlib.Path(directory) / "recover.img"
    recover.write_bytes(raw)
    with Machine(data_disk=recover) as machine:
        machine.wait("noOS> ")
        assert "Persistent noFS mounted" in machine.output()
        machine.shell("ls", "f31")
    raw[12] ^= 0x40
    raw[2560+12] ^= 0x40
    corrupt = pathlib.Path(directory) / "corrupt.img"
    corrupt.write_bytes(raw)
    before = corrupt.read_bytes()
    with Machine(data_disk=corrupt) as machine:
        machine.wait("noOS> ")
        assert "noFS unavailable; disk left untouched" in machine.output()
        machine.shell("touch denied", "Write unavailable")
        machine.shell("cat /initrd/hello.txt", "Hello from the noOS initrd.")
    assert corrupt.read_bytes() == before

    # Valid checksums cannot bypass structure validation.
    for kind in ("size", "cycle", "name", "duplicate", "bank", "mount-name"):
        bad = empty_volume()
        meta = bytearray(bad[:2560])
        struct.pack_into("<4I", meta, 512, 1, 0, 0, 0)
        meta[512+16:512+18] = b"a\0"
        if kind == "size":
            struct.pack_into("<I", meta, 512+8, 4097)
        elif kind == "cycle":
            struct.pack_into("<II", meta, 512, 2, 1)
        elif kind == "name":
            meta[512+16:512+48] = b"x" * 32
        elif kind == "duplicate":
            meta[576:640] = meta[512:576]
        elif kind == "bank":
            struct.pack_into("<I", meta, 512+12, 2)
        elif kind == "mount-name":
            meta[512+16:512+23] = b"initrd\0"
        struct.pack_into("<I", meta, 12, 0)
        struct.pack_into("<I", meta, 12, checksum(meta))
        bad[:2560] = meta
        bad[2560:5120] = meta
        image = pathlib.Path(directory) / f"invalid-{kind}.img"
        image.write_bytes(bad)
        with Machine(data_disk=image) as machine:
            machine.wait("noOS> ")
            assert "noFS unavailable; disk left untouched" in machine.output(), kind
        assert image.read_bytes() == bad

print("PASS: actual IDE PIO writes, raw disk content, close/reopen persistence, directories and rm")
print("PASS: 32-slot exhaustion/reuse, read-only mount, corrupt-bank recovery and untouched invalid disk")
