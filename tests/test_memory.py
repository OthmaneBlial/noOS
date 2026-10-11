import re
import struct
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
        records = list(struct.iter_unpack("<QQII", machine.memory(0x5000, count * 24)))
        actual_usable = sum(length for _, length, kind, _ in records if kind == 1) // 1024
        assert usable == actual_usable
        eligible = set()
        for base, length, kind, _ in records:
            if kind == 1:
                eligible.update(range(max(256, (base + 4095) // 4096),
                                      min(32768, (base + length) // 4096)))
        for base, length, kind, _ in records:
            if kind != 1:
                eligible.difference_update(range(base // 4096,
                                                min(32768, (base + length + 4095) // 4096)))
        assert managed == len(eligible)
        assert used == 33
        report = machine.shell("bench", "below tick resolution.")
        assert re.search(r"100000 alloc/free pairs; elapsed PIT ticks: \d+", report)
        after = machine.shell("mem", "heap arena: 64 KiB")
        assert int(re.search(r"Free frames: (\d+)", after)[1]) == free
        assert int(re.search(r"Allocated frames: (\d+)", after)[1]) == used
        print(f"PASS: {memory} E820={usable}KiB, managed={managed}, free={free}, used={used}")
