"""Host-observed QEMU latency, including QMP/TCG overhead; no hardware claims."""
import json
import pathlib
import statistics
import sys
import time

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tests"))
from qemu import Machine

boots = []
responses = []
for _ in range(3):
    start = time.monotonic()
    with Machine() as machine:
        machine.wait("noOS> ")
        boots.append((time.monotonic() - start) * 1000)
        machine.type("version")
        offset = len(machine.output())
        start = time.monotonic()
        machine.key("ret")
        machine.wait("noOS 0.1.0", start=offset)
        responses.append((time.monotonic() - start) * 1000)
report = {
    "method": "3 local QEMU TCG pc/128M boots; host wall time including QMP input overhead",
    "boot_to_prompt_ms": boots,
    "median_boot_to_prompt_ms": round(statistics.median(boots), 3),
    "enter_to_version_response_ms": responses,
    "median_enter_to_response_ms": round(statistics.median(responses), 3),
    "binary_bytes": {name: (ROOT / "build" / name).stat().st_size
                     for name in ("stage1.bin", "stage2.bin", "kernel.bin", "noos.img")},
    "memory": "128 MiB management ceiling; 64 KiB heap arena; 33 pinned paging frames",
    "limits": "These local observations are neither physical-hardware results nor performance guarantees.",
}
(ROOT / "build/measurements.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(report, indent=2))
