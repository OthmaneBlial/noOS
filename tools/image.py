"""Host-only deterministic image builder. No host runtime enters the kernel."""
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
BUILD = ROOT / "build"
STAGE2_SECTORS = 8
SECTOR = 512


def main():
    kernel = (BUILD / "kernel.bin").read_bytes()
    sectors = (len(kernel) + SECTOR - 1) // SECTOR
    if not 0 < sectors <= 768:
        raise ValueError("kernel must fit below the reserved boot stack")
    if sys.argv[1] == "layout":
        (BUILD / "layout.inc").write_text(f"%define KERNEL_SECTORS {sectors}\n")
    elif sys.argv[1] == "build":
        stage1 = (BUILD / "stage1.bin").read_bytes()
        stage2 = (BUILD / "stage2.bin").read_bytes()
        assert len(stage1) == SECTOR and stage1[-2:] == b"\x55\xaa"
        assert 0 < len(stage2) <= STAGE2_SECTORS * SECTOR
        image = stage1 + stage2.ljust(STAGE2_SECTORS * SECTOR, b"\0")
        image += kernel.ljust(sectors * SECTOR, b"\0")
        (BUILD / "noos.img").write_bytes(image)
        print(f"Built {len(image)} byte BIOS disk image")
    elif sys.argv[1] == "size":
        for name in ("stage1.bin", "stage2.bin", "kernel.bin", "noos.img"):
            print(f"{name:14} {(BUILD / name).stat().st_size:8} bytes")
        print("Image includes sector padding; executable sizes are separate.")
    else:
        raise ValueError("expected layout, build or size")


if __name__ == "__main__":
    main()
