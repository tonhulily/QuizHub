#!/usr/bin/env python3
"""Generate local-only QuizHub QA boundary fixtures using Python's stdlib."""

from __future__ import annotations

import argparse
import json
import struct
import zlib
from pathlib import Path

MIB = 1024 * 1024
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
GIF_1PX = (
    b"GIF89a"
    b"\x01\x00\x01\x00\x80\x00\x00"
    b"\x00\x00\x00\xff\xff\xff"
    b"\x2c\x00\x00\x00\x00\x01\x00\x01\x00\x00"
    b"\x02\x02\x44\x01\x00\x3b"
)


def png_chunk(kind: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))


def png_bytes(color: tuple[int, int, int, int], target_size: int | None = None) -> bytes:
    ihdr = struct.pack(">IIBBBBB", 1, 1, 8, 6, 0, 0, 0)
    idat = zlib.compress(b"\x00" + bytes(color))
    chunks = [png_chunk(b"IHDR", ihdr), png_chunk(b"IDAT", idat)]
    if target_size is not None:
        base_size = len(PNG_SIGNATURE) + sum(map(len, chunks)) + len(png_chunk(b"IEND", b""))
        payload_size = target_size - base_size - 12
        if payload_size < 0:
            raise ValueError(f"Target PNG size is too small: {target_size}")
        # Unknown ancillary data is valid PNG padding and keeps the image decodable.
        chunks.append(png_chunk(b"raNd", bytes(payload_size)))
    chunks.append(png_chunk(b"IEND", b""))
    result = PNG_SIGNATURE + b"".join(chunks)
    if target_size is not None and len(result) != target_size:
        raise AssertionError(f"PNG size {len(result)} != requested {target_size}")
    return result


def build_files() -> dict[str, bytes]:
    words = ("cây", "nhị", "phân", "cân", "bằng", "dữ", "liệu", "Bách", "Khoa", "học", "tốt")

    def text_for(count: int, separator: str = " ") -> bytes:
        return separator.join(words[i % len(words)] for i in range(count)).encode("utf-8")

    files = {
        "post_499_words.txt": text_for(499),
        "post_500_words.txt": text_for(500),
        "post_501_words.txt": text_for(501),
        "post_500_mixed_whitespace.txt": text_for(500, " \t\n  \r\n"),
        "password_5.txt": b"Abc12",
        "password_6.txt": b"Abc123",
        "password_32.txt": b"A" * 32,
        "password_33.txt": b"A" * 33,
        "password_special_char.txt": b"Abc12!x",
        "password_embedded_space.txt": b"Abc 123",
        "animated.gif": GIF_1PX,
        "animated_uppercase.GIF": GIF_1PX,
    }
    for index, color in enumerate(
        ((220, 20, 60, 255), (0, 128, 0, 255), (30, 90, 200, 255), (255, 180, 0, 255), (90, 40, 130, 255)),
        start=1,
    ):
        files[f"photo_{index}.png"] = png_bytes(color)
    files["image_exact_4mib.png"] = png_bytes((20, 120, 220, 255), 4 * MIB)
    files["image_over_4mib_by_1.png"] = png_bytes((220, 120, 20, 255), 4 * MIB + 1)
    return files


def write_files(output: Path) -> list[Path]:
    files = build_files()
    manifest = {
        "purpose": "QuizHub manual QA input fixtures; not evidence of app or backend behavior.",
        "files": {name: {"bytes": len(content)} for name, content in files.items()},
    }
    all_files = {
        **files,
        "manifest.json": (json.dumps(manifest, ensure_ascii=False, indent=2) + "\n").encode(),
    }
    if any(path.is_symlink() for path in (output, *output.parents)):
        raise FileExistsError(f"Refusing to write through a symlink path: {output}")
    output.mkdir(parents=True, exist_ok=True)
    for name, content in all_files.items():
        path = output / name
        if path.is_symlink() or (
            path.exists() and (not path.is_file() or path.read_bytes() != content)
        ):
            raise FileExistsError(f"Refusing to overwrite a different file: {path}")
    for name, content in all_files.items():
        path = output / name
        if not path.exists():
            path.write_bytes(content)
    return [output / name for name in all_files]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "output",
        nargs="?",
        type=Path,
        default=Path("qa-artifacts/fixtures"),
        help="output folder (default: ignored local qa-artifacts/fixtures)",
    )
    args = parser.parse_args()
    paths = write_files(args.output)
    print(f"Generated or verified {len(paths)} fixture files in {args.output}")


if __name__ == "__main__":
    main()
