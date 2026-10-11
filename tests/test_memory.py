import re
from qemu import Machine

previous = 0
for memory in ("16M", "64M", "128M", "256M"):
    with Machine(memory=memory) as machine:
        machine.wait("noOS> ")
        output = machine.output()
        assert "E820 map preserved" in output
        assert "Frames: allocate/free/fragmentation/exhaustion/invalid PASS" in output
        assert "Heap: split/coalesce/exhaustion/invalid PASS" in output
        stats = machine.shell("mem", "heap arena: 64 KiB")
        usable = int(re.search(r"E820 usable KiB: (\d+)", stats)[1])
        managed = int(re.search(r"Managed usable frames: (\d+)", stats)[1])
        free = int(re.search(r"Free frames: (\d+)", stats)[1])
        used = int(re.search(r"Allocated frames: (\d+)", stats)[1])
        assert usable > previous
        previous = usable
        assert 0 < free <= managed <= 32768 - 256
        assert free + used == managed
        count = int.from_bytes(machine.memory(0x4ff0, 2), "little")
        assert 0 < count <= 128
        print(f"PASS: {memory} E820={usable}KiB, managed={managed}, free={free}, used={used}")
