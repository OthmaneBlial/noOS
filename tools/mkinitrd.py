"""Pack a bounded read-only initrd; all runtime interpretation stays in NASM."""
import pathlib
import struct

ROOT = pathlib.Path(__file__).resolve().parents[1]
MAGIC = b"NIRD"
MAX_FILES = 16


def pack(files):
    assert 0 < len(files) <= MAX_FILES
    assert len({name for name, _ in files}) == len(files)
    offset = 16 + len(files) * 40
    directory = bytearray()
    data = bytearray()
    for name, content in files:
        encoded = name.encode("ascii")
        assert 0 < len(encoded) <= 31 and all(32 <= x < 127 and x != 47 for x in encoded)
        directory.extend(struct.pack("<32sII", encoded, offset, len(content)))
        data.extend(content)
        offset += len(content)
    return struct.pack("<4sIII", MAGIC, 1, len(files), offset) + directory + data


if __name__ == "__main__":
    files = [(p.name, p.read_bytes()) for p in sorted((ROOT / "initrd").iterdir()) if p.is_file()]
    image = pack(files)
    (ROOT / "build/initrd.bin").write_bytes(image)
    print(f"Packed {len(files)} actual initrd files, {len(image)} bytes")
