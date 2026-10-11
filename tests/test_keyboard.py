from qemu import Machine

with Machine() as machine:
    machine.wait("noOS> ")
    assert "Bounded keyboard queue PASS" in machine.output()
    machine.type("echo ")
    for key in ("a", "shift-a", "a", "caps_lock", "a", "shift-a", "caps_lock"):
        machine.key(key)
    machine.key("ret")
    machine.wait("aAaAa\nnoOS> ")
    machine.type("junk")
    machine.key("esc")
    machine.type("echo")
    machine.key("tab")
    machine.type("ready")
    machine.key("ret")
    machine.wait("ready\nnoOS> ")
    machine.command("inject-nmi")
    machine.wait("KERNEL PANIC: exception 2 error=0x00000000")
    machine.wait("CPU halted. Reset required.")
print("PASS: PS/2 IRQ1, make/break, Shift, Caps Lock and editing keys")
print("PASS: bounded event queue, IDT exception number/error/EIP and panic halt")
