import pathlib
import re
import struct
import tempfile
from qemu import Machine, ROOT

def allocated(machine):
    return int(re.search(r"Allocated frames: (\d+)", machine.shell("mem"))[1])

with Machine() as machine:
    machine.wait("noOS> ")
    baseline = allocated(machine)
    for _ in range(3):
        output = machine.shell("run hello.elf", "status=0x00000000")
        assert "CPL=3" in output and "real ELF32 Assembly program" in output
        assert allocated(machine) == baseline
    output = machine.shell("run checks.elf", "status=0x00000000")
    assert "AB\nELF BSS/RW data and cross-page syscall checks PASS" in output
    assert allocated(machine) == baseline
    output = machine.shell("run fault.elf", "status=0xFFFFFFFF")
    assert "exception 14 error=0x00000005" in output
    assert allocated(machine) == baseline
    machine.shell("run hello.txt", "[ELF ERROR]")
    machine.shell("run missing", "Usage: run NAME.elf")
    machine.shell("version", "noOS 0.1.0")

raw = (ROOT / "build/noos.img").read_bytes()
elf = (ROOT / "build/hello.elf").read_bytes()
assert elf[:7] == b"\x7fELF\x01\x01\x01"
offset = raw.index(elf)
mutations = [
    (0, b"FAIL"), (4, b"\x02"), (5, b"\x02"), (6, b"\x02"),
    (7, b"\x03"), (8, b"\x01"), (16, struct.pack("<H", 3)),
    (18, struct.pack("<H", 62)), (20, struct.pack("<I", 2)),
    (36, struct.pack("<I", 1)), (40, struct.pack("<H", 51)),
    (42, struct.pack("<H", 31)), (44, struct.pack("<H", 0)),
    (44, struct.pack("<H", 5)), (28, struct.pack("<I", 0xfffffff0)),
    (28, struct.pack("<I", len(elf)-4)),
    (52, struct.pack("<I", 3)), (56, struct.pack("<I", 4097)),
    (56, struct.pack("<I", 0xfffff000)), (60, struct.pack("<I", 0x10000)),
    (60, struct.pack("<I", 0x40000001)), (68, struct.pack("<I", 0xffffffff)),
    (72, struct.pack("<I", 0)), (72, struct.pack("<I", 0xffffffff)),
    (72, struct.pack("<I", 65537)), (76, struct.pack("<I", 7)),
    (76, struct.pack("<I", 4)), (80, struct.pack("<I", 1)),
    (24, struct.pack("<I", 0x40001000)),
]
with tempfile.TemporaryDirectory() as directory:
    for index, (relative, replacement) in enumerate(mutations):
        bad = bytearray(raw)
        bad[offset+relative:offset+relative+len(replacement)] = replacement
        image = pathlib.Path(directory) / f"bad{index}.img"
        image.write_bytes(bad)
        with Machine(image=image) as machine:
            machine.wait("noOS> ")
            baseline = allocated(machine)
            machine.shell("run hello.elf", "[ELF ERROR]")
            assert allocated(machine) == baseline
            machine.shell("version", "noOS 0.1.0")
    # Two-segment overlap with otherwise valid headers must also be rejected.
    bad = bytearray(raw)
    checks = raw.index((ROOT / "build/checks.elf").read_bytes())
    struct.pack_into("<I", bad, checks+84+8, 0x40000000)
    image = pathlib.Path(directory) / "overlap.img"
    image.write_bytes(bad)
    with Machine(image=image) as machine:
        machine.wait("noOS> ")
        machine.shell("run checks.elf", "[ELF ERROR]")
print(f"PASS: real ELF32 code/data/BSS, checked cross-page syscalls, fault recovery, no frame leaks and {len(mutations)+1} malformed ELF rejections")
