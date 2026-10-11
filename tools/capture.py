"""Capture the real QEMU VGA display; PNG conversion preserves its pixels."""
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tests"))
from qemu import Machine

with Machine() as machine:
    machine.wait("noOS> ")
    machine.screenshot(ROOT / "screenshots/noos.ppm")
target = ROOT / "screenshots/noos.png"
subprocess.run(["sips", "-s", "format", "png", str(ROOT / "screenshots/noos.ppm"),
                "--out", str(target)], check=True, capture_output=True)
(ROOT / "screenshots/noos.ppm").unlink()
site_target = ROOT / "site/screenshots/noos.png"
site_target.parent.mkdir(parents=True, exist_ok=True)
site_target.write_bytes(target.read_bytes())
print(f"Actual QEMU framebuffer capture: {target}")
