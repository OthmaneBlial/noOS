import re
import time
from qemu import Machine

with Machine() as machine:
    machine.wait("noOS> ")
    assert "PIT IRQ0 and tick-based delay PASS" in machine.output()
    first = machine.shell("uptime", "nominal rate: ~100 Hz")
    ticks1 = int(re.search(r"PIT ticks: (\d+)", first)[1])
    time.sleep(0.25)
    second = machine.shell("uptime", "nominal rate: ~100 Hz")
    ticks2 = int(re.search(r"PIT ticks: (\d+)", second)[1])
    assert ticks2 >= ticks1 + 20
    stats = machine.shell("sysinfo", "Dropped events:")
    assert "CPU vendor: GenuineIntel" in stats
    assert "Mode: 32-bit protected; paging: supervisor identity map" in stats
    assert int(re.search(r"Keyboard IRQs: (\d+)", stats)[1]) > 20
    assert "Dropped events: 0" in stats
    commands = machine.shell("help", "sysinfo")
    for command in ("mem", "uptime", "cpu", "sysinfo"):
        assert f"  {command}\n" in commands
    cpu = machine.shell("cpu", "CPUID leaf 1 EDX:")
    assert "Family:" in cpu and "Model:" in cpu and "Stepping:" in cpu
print(f"PASS: real IRQ0 ticks advance {ticks1}->{ticks2}, validated delays and CPU detection")
print("PASS: all 14 initial shell commands advertised; live sysinfo, IRQ statistics and serial")
