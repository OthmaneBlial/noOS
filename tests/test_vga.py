from qemu import Machine

with Machine() as machine:
    machine.wait("VGA terminal ready")
    assert "VGA self-test PASS" in machine.output()
    screen = machine.screen()
    assert "No Linux. No Windows. No C. Just Assembly." in screen
    assert "x86 / 32-bit protected mode" in screen
    cells = machine.memory(0xb8000, 4000)
    assert all(attribute == 0x0b for attribute in cells[1::2])
    machine.screenshot("build/first-screen.ppm")
print("PASS: actual VGA text buffer, attributes, welcome screen and QEMU screendump")
