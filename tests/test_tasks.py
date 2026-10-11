from qemu import Machine

with Machine() as machine:
    machine.wait("noOS> ")
    assert "Cooperative tasks: contexts/stacks/round-robin PASS" in machine.output()
    output = machine.shell("ps", "worker-b DONE work=3")
    assert "0  shell RUNNING" in output
    assert "worker-a DONE work=3" in output
    machine.shell("version", "noOS 0.1.0")
print("PASS: real saved CPU contexts, distinct kernel stacks, cooperative round-robin and task status")
