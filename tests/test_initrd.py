import pathlib
import struct
import tempfile
from qemu import Machine, ROOT

with Machine() as machine:
    machine.wait("noOS> ")
    assert "Validated read-only initrd" in machine.output()
    machine.shell("cd /initrd")
    output = machine.shell("ls", "manual.txt")
    assert "hello.txt" in output and "Read-only initrd /" in output
    machine.shell("cat hello.txt", "read by the Assembly kernel.")
    machine.shell("cat manual.txt", "actual emulated disk I/O.")
    machine.shell("cat missing", "File not found")
    machine.shell("cat", "Usage: cat FILE")
    machine.shell("pwd", "/initrd\n")
    machine.shell("cd /")
    machine.shell("cd missing", "not found")

raw = (ROOT / "build/noos.img").read_bytes()
initrd = (ROOT / "build/initrd.bin").read_bytes()
offset = raw.index(initrd)
mutations = [(0, b"FAIL"), (8, struct.pack("<I", 17)),
             (16+32, struct.pack("<I", 0xfffffff0)),
             (16+36, struct.pack("<I", 0xfffffff0)),
             (16, b"x" * 32), (56, initrd[16:48])]
with tempfile.TemporaryDirectory() as directory:
    for index, (relative, replacement) in enumerate(mutations):
        bad = bytearray(raw)
        bad[offset+relative:offset+relative+len(replacement)] = replacement
        image = pathlib.Path(directory) / f"bad{index}.img"
        image.write_bytes(bad)
        with Machine(image=image) as machine:
            machine.wait("[FS ERROR] Invalid initrd metadata")
            machine.wait("KERNEL PANIC: exception 3")
print("PASS: real read-only initrd ls/cat/pwd/cd and bounds/name/count/duplicate corruption rejection")
