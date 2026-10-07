from pathlib import Path
import struct
import tempfile
import unittest

from tools.prepare_android_assets import (
    COMMAND_LINE,
    PACK_NAME,
    check_pack_header,
    decode_command_line,
    encode_command_line,
    prepare_assets,
)


PACK = struct.pack("<4s4I", b"GDPC", 3, 4, 6, 3) + b"exported project payload"


class AndroidAssetsTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.pack = self.root / "exported.pck"
        self.pack.write_bytes(PACK)
        self.assets = self.root / "assets"

    def test_binary_command_line_uses_official_little_endian_utf8_byte_counts(self):
        # Fixed bytes independently encode one two-byte letter and a four-byte emoji.
        encoded = encode_command_line(("ä🦊",))
        expected = b"\x01\x00\x00\x00\x06\x00\x00\x00\xc3\xa4\xf0\x9f\xa6\x8a"
        self.assertEqual(encoded, expected)
        self.assertEqual(decode_command_line(expected), ("ä🦊",))
        self.assertEqual(decode_command_line(encode_command_line(COMMAND_LINE)), COMMAND_LINE)

    def test_rejects_invalid_or_truncated_command_line_frames(self):
        malformed = (
            b"",
            struct.pack("<I", 1),
            struct.pack("<II", 1, 8) + b"short",
            struct.pack("<II", 1, 65536),
            struct.pack("<II", 1, 0),
            encode_command_line(COMMAND_LINE) + b"\x00",
            struct.pack("<II", 1, 1) + b"\xff",
        )
        for data in malformed:
            with self.subTest(data=data):
                with self.assertRaises(ValueError):
                    decode_command_line(data)
        for argument in ("", "a" * 65536, "ä" * 32768):
            with self.subTest(argument_length=len(argument)):
                with self.assertRaises(ValueError):
                    encode_command_line((argument,))

    def test_pack_header_requires_matching_godot_version(self):
        check_pack_header(PACK)
        invalid = (
            PACK[:19],
            struct.pack("<4s4I", b"NOPE", 3, 4, 6, 3),
            struct.pack("<4s4I", b"GDPC", 2, 4, 6, 3),
            struct.pack("<4s4I", b"GDPC", 3, 4, 5, 3),
            struct.pack("<4s4I", b"GDPC", 3, 4, 6, 2),
        )
        for data in invalid:
            with self.subTest(data=data):
                with self.assertRaises(ValueError):
                    check_pack_header(data)

    def test_prepare_places_pack_and_binary_startup_at_assets_root_idempotently(self):
        prepare_assets(self.pack, self.assets)
        self.assertEqual({path.name for path in self.assets.iterdir()}, {PACK_NAME, "_cl_"})
        self.assertEqual((self.assets / PACK_NAME).read_bytes(), PACK)
        self.assertTrue((self.assets / "_cl_").is_file())
        startup = (self.assets / "_cl_").read_bytes()
        self.assertEqual(decode_command_line(startup), COMMAND_LINE)
        prepare_assets(self.pack, self.assets)
        prepare_assets(self.assets / PACK_NAME, self.assets)
        self.assertEqual((self.assets / "_cl_").read_bytes(), startup)
        self.assertEqual(self.pack.read_bytes(), PACK)

    def test_migrates_only_known_legacy_command_line_directory(self):
        legacy = self.assets / "_cl_"
        legacy.mkdir(parents=True)
        (legacy / PACK_NAME).write_bytes(b"old broken layout")
        unrelated = self.assets / "notice.txt"
        unrelated.write_text("keep this")
        prepare_assets(self.pack, self.assets)
        self.assertTrue(legacy.is_file())
        self.assertEqual(decode_command_line(legacy.read_bytes()), COMMAND_LINE)
        self.assertEqual((self.assets / PACK_NAME).read_bytes(), PACK)
        self.assertEqual(unrelated.read_text(), "keep this")
        prepare_assets(self.pack, self.assets)

    def test_refuses_unknown_legacy_contents_without_deleting_any_files(self):
        legacy = self.assets / "_cl_"
        legacy.mkdir(parents=True)
        known = legacy / PACK_NAME
        known.write_bytes(b"retain until reviewed")
        unknown = legacy / "important.txt"
        unknown.write_text("keep me")
        with self.assertRaisesRegex(ValueError, "Unexpected files"):
            prepare_assets(self.pack, self.assets)
        self.assertTrue(legacy.is_dir())
        self.assertEqual(known.read_bytes(), b"retain until reviewed")
        self.assertEqual(unknown.read_text(), "keep me")
        self.assertFalse((self.assets / PACK_NAME).exists())

    def test_invalid_pack_does_not_change_existing_assets(self):
        prepare_assets(self.pack, self.assets)
        previous = (self.assets / "_cl_").read_bytes()
        self.pack.write_bytes(b"invalid export")
        with self.assertRaises(ValueError):
            prepare_assets(self.pack, self.assets)
        self.assertEqual((self.assets / PACK_NAME).read_bytes(), PACK)
        self.assertEqual((self.assets / "_cl_").read_bytes(), previous)


if __name__ == "__main__":
    unittest.main()
