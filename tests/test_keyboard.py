from qemu import Machine

with Machine() as machine:
    machine.wait("keyboard diagnostic input active")
    assert "Bounded keyboard queue PASS" in machine.output()
    keys = [("a", 0x61), ("shift-a", 0x41), ("a", 0x61),
            ("caps_lock", None), ("a", 0x41), ("shift-a", 0x61),
            ("caps_lock", None), ("ret", 10), ("backspace", 8),
            ("tab", 9), ("esc", 27), ("up", 0x100), ("down", 0x101),
            ("left", 0x102), ("right", 0x103), ("home", 0x104),
            ("end", 0x105), ("delete", 0x106)]
    for key, expected in keys:
        start = len(machine.output())
        machine.key(key)
        if expected is not None:
            machine.wait(f"key=0x{expected:08X}", start=start)
    output = machine.output()
    assert output.count("key=") == 16, output
    machine.command("inject-nmi")
    machine.wait("KERNEL PANIC: exception 2 error=0x00000000")
    machine.wait("CPU halted. Reset required.")
print("PASS: PS/2 IRQ1, make/break, Shift, Caps Lock and editing keys")
print("PASS: bounded event queue, IDT exception number/error/EIP and panic halt")
