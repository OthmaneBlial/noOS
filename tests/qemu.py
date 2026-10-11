"""Small QMP harness for emulated PS/2 input, VGA memory and real screenshots."""
import json
import os
import pathlib
import socket
import subprocess
import tempfile
import time

ROOT = pathlib.Path(__file__).resolve().parents[1]


class Machine:
    def __init__(self, memory="128M", image=None, extra=()):
        self.tmp = tempfile.TemporaryDirectory()
        self.directory = pathlib.Path(self.tmp.name)
        self.serial = self.directory / "serial.log"
        self.debug = self.directory / "boot.log"
        self.events = []
        self.process = subprocess.Popen([
            os.environ.get("QEMU", "qemu-system-i386"), "-machine", "pc",
            "-m", memory, "-drive", f"format=raw,file={image or ROOT / 'build/noos.img'}",
            "-display", "none", "-serial", f"file:{self.serial}",
            "-debugcon", f"file:{self.debug}", "-no-reboot", "-no-shutdown",
            "-qmp", f"unix:{self.directory / 'qmp'},server=on,wait=off", *extra,
        ], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        self.socket = socket.socket(socket.AF_UNIX)
        deadline = time.monotonic() + 5
        while True:
            try:
                self.socket.connect(str(self.directory / "qmp"))
                break
            except (FileNotFoundError, ConnectionRefusedError):
                if time.monotonic() > deadline or self.process.poll() is not None:
                    self.close()
                    raise AssertionError("QEMU did not open QMP")
                time.sleep(0.02)
        self.socket.settimeout(5)
        self.stream = self.socket.makefile("rwb", buffering=0)
        assert "QMP" in self._read()
        self.command("qmp_capabilities")

    def _read(self):
        line = self.stream.readline()
        assert line, "QMP disconnected"
        return json.loads(line)

    def command(self, execute, arguments=None):
        message = {"execute": execute}
        if arguments is not None:
            message["arguments"] = arguments
        self.stream.write(json.dumps(message).encode() + b"\n")
        while True:
            reply = self._read()
            if "event" in reply:
                self.events.append(reply)
            elif "error" in reply:
                raise AssertionError(reply["error"])
            elif "return" in reply:
                return reply["return"]

    def hmp(self, command):
        return self.command("human-monitor-command", {"command-line": command})

    def output(self):
        return "".join(path.read_text(errors="replace") if path.exists() else ""
                       for path in (self.debug, self.serial))

    def wait(self, text, start=0, timeout=10):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            output = self.output()
            if text in output[start:]:
                return output
            assert self.process.poll() is None, "QEMU exited unexpectedly"
            time.sleep(0.01)
        raise AssertionError(f"Wanted {text!r}, got:\n{self.output()[start:]}")

    def key(self, key):
        self.command("send-key", {"keys": [{"type": "qcode", "data": k}
                                          for k in key.split("-")], "hold-time": 5})
        time.sleep(0.012)

    def type(self, text):
        punctuation = {" ": "spc", ".": "dot", "/": "slash", "-": "minus",
                       "=": "equal", ",": "comma", ";": "semicolon"}
        for char in text:
            if char.isupper():
                self.key("shift-" + char.lower())
            else:
                self.key(punctuation.get(char, char))

    def memory(self, address, size):
        target = self.directory / "memory.bin"
        self.hmp(f'pmemsave {address:#x} {size} "{target}"')
        return target.read_bytes()

    def screen(self):
        return self.memory(0xb8000, 4000)[::2].decode("cp437")

    def screenshot(self, target):
        target = pathlib.Path(target).resolve()
        target.parent.mkdir(parents=True, exist_ok=True)
        self.command("screendump", {"filename": str(target)})

    def close(self):
        if getattr(self, "process", None) and self.process.poll() is None:
            self.process.terminate()
            self.process.wait(timeout=5)
        if hasattr(self, "stream"):
            self.stream.close()
        if hasattr(self, "socket"):
            self.socket.close()
        self.tmp.cleanup()

    def __enter__(self):
        return self

    def __exit__(self, *_):
        self.close()
