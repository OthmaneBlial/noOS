import re
import struct
from qemu import Machine

with Machine() as machine:
    machine.wait("noOS> ")
    assert "Paging enabled (supervisor identity map, null guard)" in machine.output()
    registers = machine.hmp("info registers")
    cr0 = int(re.search(r"CR0=([0-9A-Fa-f]+)", registers)[1], 16)
    cr3 = int(re.search(r"CR3=([0-9A-Fa-f]+)", registers)[1], 16)
    assert cr0 & 0x80010000 == 0x80010000
    assert cr3 >= 0x100000 and cr3 % 4096 == 0
    directory = struct.unpack("<1024I", machine.memory(cr3, 4096))
    for index, entry in enumerate(directory):
        if index < 32:
            assert entry & 7 == 3
            table = struct.unpack("<1024I", machine.memory(entry & ~4095, 4096))
            for page, mapping in enumerate(table):
                address = (index * 1024 + page) * 4096
                if address == 0:
                    assert mapping == 0
                else:
                    assert mapping & ~4095 == address
                    assert mapping & 7 == 3
                    if address == 0xb8000:
                        assert mapping & 0x18 == 0x18
        else:
            assert entry == 0
    machine.shell("panic page", "KERNEL PANIC: exception 14 error=0x00000000")
    machine.wait("CR2=0x00000000")

for command, vector, error in [("panic gp", 13, 0x18), ("panic divide", 0, 0)]:
    with Machine() as machine:
        machine.wait("noOS> ")
        machine.shell(command, f"exception {vector} error=0x{error:08X}")
        machine.wait("CPU halted. Reset required.")
print("PASS: CR0/CR3, all 32768 page mappings, supervisor permissions and null guard")
print("PASS: real page fault, GP error code and divide exception diagnostics")
