import time
from qemu import Machine

with Machine() as machine:
    machine.wait("noOS> ")
    for command, expected in [("help", "color FB"), ("version", "noOS 0.1.0"),
                              ("about", "BIOS-booted operating system"),
                              ("   echo hello world", "hello world\n"),
                              ("nonsense", "Unknown command: nonsense"),
                              ("version wrong", "Usage: version"),
                              ("color zz", "Usage: color FB"),
                              ("echo", "noOS> "), ("", "noOS> ")]:
        machine.shell(command, expected)
    machine.shell("clear")
    assert machine.screen().startswith("noOS> ")
    machine.type("echo ac")
    machine.key("left")
    machine.type("b")
    machine.key("home")
    machine.key("right")
    machine.key("delete")
    machine.type("c")
    machine.key("end")
    machine.key("backspace")
    machine.type("c")
    machine.key("ret")
    machine.wait("abc\nnoOS> ")
    machine.key("up")
    machine.key("down")
    machine.type("echo draft")
    machine.key("up")
    machine.key("down")
    machine.key("ret")
    machine.wait("draft\nnoOS> ")
    machine.shell("history", "echo draft")
    machine.shell("color e1", "Terminal color updated")
    cells = machine.memory(0xb8000, 4000)
    assert 0x1e in cells[1::2]
    for index in range(25):
        machine.shell(f"echo line{index}", f"line{index}\n")
    assert "line24" in machine.screen()
    machine.type("echo " + "x" * 150)
    machine.key("ret")
    machine.wait("x" * 122 + "\nnoOS> ")
    machine.shell("version", "noOS 0.1.0")
    machine.shell("panic", "KERNEL PANIC: exception 6 error=0x00000000")
    machine.wait("CPU halted. Reset required.")

with Machine() as machine:
    machine.wait("noOS> ")
    before = len(machine.output())
    machine.shell("reboot", "Rebooting noOS")
    machine.wait("noOS kernel entry", start=before)
    machine.wait("noOS> ", start=before)

with Machine() as machine:
    machine.wait("noOS> ")
    machine.shell("halt", "System halted.")
    time.sleep(0.05)
    registers = machine.hmp("info registers")
    assert "HLT=1" in registers, registers
    output = machine.output()
    machine.type("version")
    assert machine.output() == output

print("PASS: command parsing, usage/errors, empty input, editing, bounded lines, history")
print("PASS: VGA scrolling/color/clear, real exception, hardware reboot and CLI/HLT")
