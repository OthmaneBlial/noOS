from qemu import Machine
import re

with Machine() as machine:
    machine.wait("noOS> ")
    assert "Cooperative tasks: contexts/stacks/round-robin PASS" in machine.output()
    assert "PIT preemption: non-yielding workers/context restoration PASS" in machine.output()
    output = machine.shell("ps", "worker-b DONE")
    assert "0  shell RUNNING" in output
    assert "worker-a DONE" in output
    machine.shell("tasks bad", "Usage: tasks on|off")
    machine.shell("tasks on", "PIT preemption enabled")
    first = machine.shell("ps", "worker-b READY")
    second = machine.shell("ps", "worker-b READY")
    for name in ("worker-a", "worker-b"):
        pattern = name + r" READY work=(\d+) switches=(\d+) ticks=(\d+)"
        a = tuple(map(int, re.search(pattern, first).groups()))
        b = tuple(map(int, re.search(pattern, second).groups()))
        assert all(y > x for x, y in zip(a, b)), (name, a, b)
    machine.shell("tasks off", "Workers stopped")
    machine.shell("ps", "worker-b DONE")
    machine.shell("version", "noOS 0.1.0")
print("PASS: cooperative contexts, separate stacks, actual PIT preemption, advancing non-yielding workers and responsive shell")
