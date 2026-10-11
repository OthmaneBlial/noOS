import re
from qemu import Machine

def allocated(machine):
    return int(re.search(r"Allocated frames: (\d+)", machine.shell("mem"))[1])

with Machine() as machine:
    machine.wait("noOS> ")
    baseline = allocated(machine)
    for _ in range(3):
        output = machine.shell("user demo", "status=0x00000000")
        assert "CPL=3; syscall entered on TSS kernel stack" in output
        assert "Hello from real ring 3" in output
        assert allocated(machine) == baseline
    for mode, diagnostic in [
        ("fault", "exception 14 error=0x00000005"),
        ("write", "exception 14 error=0x00000007"),
        ("stack", "exception 14 error=0x00000004"),
        ("io", "exception 13 error=0x00000000"),
    ]:
        output = machine.shell("user " + mode, "status=0xFFFFFFFF")
        assert diagnostic in output, output
        assert allocated(machine) == baseline
        machine.shell("version", "noOS 0.1.0")
    machine.shell("tasks on", "preemption enabled")
    start = len(machine.output())
    machine.type("user spin")
    machine.key("ret")
    machine.wait("CPL=3; syscall entered", start=start)
    for _ in range(20):
        machine.command("stop")
        registers = machine.hmp("info registers")
        if "CPL=3" in registers:
            break
        machine.command("cont")
    assert "CPL=3" in registers and re.search(r"CS =001b", registers), registers
    cr3 = int(re.search(r"CR3=([0-9a-fA-F]+)", registers)[1], 16)
    assert cr3 > 0x100000
    directory = machine.memory(cr3, 4096)
    import struct
    pde = struct.unpack_from("<I", directory, 256*4)[0]
    assert pde & 7 == 7
    table = struct.unpack("<1024I", machine.memory(pde & ~4095, 4096))
    assert table[0] & 7 == 5 and table[31] & 7 == 7
    assert table[30] == 0
    assert "TR =0028" in registers
    machine.command("cont")
    machine.wait("status=0x00000000", start=start)
    machine.shell("ps", "worker-b READY")
    machine.shell("tasks off", "Workers stopped")
    assert allocated(machine) == baseline
print("PASS: actual CPL3/TSS stack, private CR3, checked syscalls, protected kernel/code/guard/I/O, fault recovery and frame cleanup")
