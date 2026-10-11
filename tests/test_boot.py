"""Boot actual x86 hardware in QEMU; never execute kernel code on the host."""
import os
import pathlib
import subprocess
import tempfile
import time

ROOT = pathlib.Path(__file__).resolve().parents[1]


def boot(image, expected):
    with tempfile.TemporaryDirectory() as tmp:
        serial = pathlib.Path(tmp) / "serial.log"
        debug = pathlib.Path(tmp) / "boot.log"
        process = subprocess.Popen([
            os.environ.get("QEMU", "qemu-system-i386"), "-machine", "pc",
            "-m", "128M", "-drive", f"format=raw,file={image}",
            "-display", "none", "-serial", f"file:{serial}",
            "-debugcon", f"file:{debug}", "-no-reboot", "-no-shutdown",
        ], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        start = time.monotonic()
        try:
            while time.monotonic() - start < 10:
                text = "".join(p.read_text(errors="replace") if p.exists() else ""
                               for p in (debug, serial))
                if expected in text:
                    return text, time.monotonic() - start
                if process.poll() is not None:
                    raise AssertionError(process.stderr.read().decode())
                time.sleep(0.02)
            raise AssertionError(f"Boot timeout: wanted {expected!r}\n{text}")
        finally:
            process.terminate()
            process.wait(timeout=5)


def main():
    image = ROOT / "build/noos.img"
    raw = image.read_bytes()
    assert raw[510:512] == b"\x55\xaa"
    output, elapsed = boot(image, "noOS kernel entry")
    for marker in ("Boot sector loaded", "Kernel loaded", "A20 enabled",
                   "GDT initialized", "Protected mode activated"):
        assert marker in output, marker
    with tempfile.TemporaryDirectory() as tmp:
        bad = pathlib.Path(tmp) / "short.img"
        bad.write_bytes(raw[:512])
        boot(bad, "BOOT ERROR")
        bad.write_bytes(raw[:9*512])
        boot(bad, "Kernel disk read failed")
    print(f"PASS: boot signature, BIOS loading, A20, protected-mode kernel; {elapsed:.3f}s")
    print("PASS: truncated stage2/kernel disks produce explicit boot diagnostics")


if __name__ == "__main__":
    main()
