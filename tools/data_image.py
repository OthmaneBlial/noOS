"""Create a NEW noFS volume. Existing persistent data is never overwritten."""
import pathlib
import struct

ROOT = pathlib.Path(__file__).resolve().parents[1]
SECTORS = 1024
META_BYTES = 5 * 512


def checksum(data):
    result = 2166136261
    for byte in data:
        result = ((result ^ byte) * 16777619) & 0xffffffff
    return result


def empty_volume():
    metadata = bytearray(META_BYTES)
    struct.pack_into("<6I", metadata, 0, 0x53464f4e, 1, 0, 0, SECTORS, 32)
    struct.pack_into("<I", metadata, 12, checksum(metadata))
    disk = bytearray(SECTORS * 512)
    disk[:META_BYTES] = metadata
    disk[META_BYTES:META_BYTES * 2] = metadata
    return disk


if __name__ == "__main__":
    target = ROOT / "data/noos-data.img"
    target.parent.mkdir(parents=True, exist_ok=True)
    try:
        with target.open("xb") as stream:
            stream.write(empty_volume())
        print(f"Created new persistent noFS volume: {target}")
    except FileExistsError:
        print("Existing persistent volume preserved")
