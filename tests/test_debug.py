"""Verify the documented debugger against an actual paused QEMU CPU."""
import os
import shutil
import socket
import subprocess
from qemu import Machine

debugger = os.environ.get("GDB") or shutil.which("gdb") or shutil.which("x86_64-elf-gdb")
assert debugger, "Install GDB (macOS: brew install x86_64-elf-gdb)"
with socket.socket() as reservation:
    reservation.bind(("127.0.0.1", 0))
    port = reservation.getsockname()[1]
with Machine(extra=("-S", "-gdb", f"tcp:127.0.0.1:{port}")) as machine:
    result = subprocess.run([
        debugger, "-q", "-nx", "-batch", "-ex", "set architecture i386",
        "-ex", f"target remote 127.0.0.1:{port}", "-ex", "hbreak *0x10000",
        "-ex", "continue", "-ex", 'printf "ENTRY_PC=%x CS=%x CR0=%x ESP=%x\\n", $eip, $cs, $cr0, $esp',
        "-ex", "x/4i $eip", "-ex", "detach",
    ], capture_output=True, text=True, timeout=15)
    assert result.returncode == 0, result.stderr + result.stdout
    assert "ENTRY_PC=10000 CS=8 CR0=11 ESP=90000" in result.stdout, result.stdout
    machine.wait("noOS> ")
print("PASS: actual GDB hardware breakpoint at protected-mode entry; registers and disassembly")
