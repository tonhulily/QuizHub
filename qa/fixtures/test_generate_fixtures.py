import re
import struct
import tempfile
import unittest
import zlib
from pathlib import Path

from generate_fixtures import MIB, PNG_SIGNATURE, write_files


def read_png(path: Path) -> tuple[dict[bytes, bytes], list[bytes]]:
    data = path.read_bytes()
    assert data.startswith(PNG_SIGNATURE)
    offset = len(PNG_SIGNATURE)
    chunks = {}
    order = []
    while offset < len(data):
        length = struct.unpack_from(">I", data, offset)[0]
        kind = data[offset + 4 : offset + 8]
        start = offset + 8
        payload = data[start : start + length]
        crc = struct.unpack_from(">I", data, start + length)[0]
        assert crc == zlib.crc32(kind + payload)
        chunks[kind] = payload
        order.append(kind)
        offset = start + length + 4
        if kind == b"IEND":
            break
    assert offset == len(data)
    assert order[-1] == b"IEND"
    return chunks, order


class FixtureGeneratorTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.output = Path(self.temp.name) / "fixtures"
        write_files(self.output)

    def tearDown(self):
        self.temp.cleanup()

    def test_word_boundary_and_whitespace_fixtures(self):
        expected = {
            "post_499_words.txt": 499,
            "post_500_words.txt": 500,
            "post_501_words.txt": 501,
            "post_500_mixed_whitespace.txt": 500,
        }
        for name, count in expected.items():
            text = (self.output / name).read_text(encoding="utf-8")
            self.assertEqual(len(text.strip().split()), count, name)
        self.assertTrue(any(ord(char) > 127 for char in text))

    def test_password_fixture_lengths_and_invalid_characters(self):
        for length in (5, 6, 32, 33):
            value = (self.output / f"password_{length}.txt").read_text()
            self.assertEqual(len(value), length)
            self.assertRegex(value, re.compile(r"^[A-Za-z0-9]+$"))
        self.assertRegex((self.output / "password_special_char.txt").read_text(), r"[^A-Za-z0-9]")
        self.assertIn(" ", (self.output / "password_embedded_space.txt").read_text())

    def test_pngs_are_decodable_chunks_at_exact_byte_boundaries(self):
        small_pngs = []
        pixels = []
        for index in range(1, 6):
            path = self.output / f"photo_{index}.png"
            small_pngs.append(path.read_bytes())
            chunks, order = read_png(path)
            self.assertEqual(struct.unpack(">IIBBBBB", chunks[b"IHDR"]), (1, 1, 8, 6, 0, 0, 0))
            pixel = zlib.decompress(chunks[b"IDAT"])
            self.assertEqual(len(pixel), 5)
            self.assertEqual(pixel[0], 0)
            pixels.append(pixel[1:])
            self.assertEqual(order[-1], b"IEND")
        self.assertEqual(len(set(small_pngs)), 5)
        self.assertEqual(len(set(pixels)), 5)
        for name, size in (
            ("image_exact_4mib.png", 4 * MIB),
            ("image_over_4mib_by_1.png", 4 * MIB + 1),
        ):
            self.assertEqual((self.output / name).stat().st_size, size)
            chunks, order = read_png(self.output / name)
            self.assertEqual(zlib.decompress(chunks[b"IDAT"])[0], 0)
            self.assertIn(b"raNd", order)
        self.assertEqual(sum(1 for p in self.output.glob("photo_*.png")), 5)

    def test_gif_fixtures_have_palette_and_valid_one_pixel_lzw_index(self):
        for name in ("animated.gif", "animated_uppercase.GIF"):
            content = (self.output / name).read_bytes()
            self.assertTrue(content.startswith((b"GIF87a", b"GIF89a")))
            width, height, flags = struct.unpack_from("<HHB", content, 6)
            self.assertEqual((width, height), (1, 1))
            self.assertTrue(flags & 0x80, "global color table must be present")
            palette_size = 1 << ((flags & 0x07) + 1)
            offset = 13
            palette = content[offset : offset + palette_size * 3]
            self.assertEqual(len(palette), palette_size * 3)
            offset += len(palette)
            self.assertEqual(content[offset], 0x2C)
            left, top, image_width, image_height, local_flags = struct.unpack_from(
                "<HHHHB", content, offset + 1
            )
            self.assertEqual((left, top, image_width, image_height), (0, 0, 1, 1))
            offset += 10
            if local_flags & 0x80:
                local_size = 1 << ((local_flags & 0x07) + 1)
                palette = content[offset : offset + local_size * 3]
                offset += len(palette)
            min_code_size = content[offset]
            self.assertEqual(min_code_size, 2)
            offset += 1
            block_size = content[offset]
            self.assertEqual(block_size, 2)
            compressed = content[offset + 1 : offset + 1 + block_size]
            self.assertEqual(len(compressed), block_size)
            end_block = offset + 1 + block_size
            self.assertEqual(content[end_block : end_block + 2], b"\x00;")
            codes = [(int.from_bytes(compressed, "little") >> shift) & 0x07 for shift in (0, 3, 6)]
            self.assertEqual(codes[0], 1 << min_code_size)  # clear
            self.assertLess(codes[1], len(palette) // 3)  # pixel index exists in palette
            self.assertEqual(codes[2], (1 << min_code_size) + 1)  # end of information

    def test_generator_refuses_to_overwrite_different_existing_content(self):
        path = self.output / "photo_1.png"
        path.write_bytes(b"keep this file")
        with self.assertRaises(FileExistsError):
            write_files(self.output)
        self.assertEqual(path.read_bytes(), b"keep this file")

    def test_generator_refuses_output_and_file_symlinks(self):
        target = Path(self.temp.name) / "target.txt"
        target.write_bytes(b"keep this file")
        linked_output = Path(self.temp.name) / "linked-output"
        try:
            linked_output.symlink_to(target.parent, target_is_directory=True)
        except (NotImplementedError, OSError):
            self.skipTest("symlink creation is not available")
        with self.assertRaises(FileExistsError):
            write_files(linked_output)
        self.assertEqual(list(Path(self.temp.name).glob("linked-output/photo_*.png")), [])

        photo = self.output / "photo_1.png"
        photo.unlink()
        photo.symlink_to(target)
        with self.assertRaises(FileExistsError):
            write_files(self.output)
        self.assertEqual(target.read_bytes(), b"keep this file")


if __name__ == "__main__":
    unittest.main()
