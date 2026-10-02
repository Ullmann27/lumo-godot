from pathlib import Path
import struct
import tempfile
import unittest
import warnings
import zipfile

from tools.package_android_apk import prepare_apk, verify_apk


class AndroidApkPackagingTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.source = self.root / "input.apk"
        self.output = self.root / "prepared.apk"

    @staticmethod
    def _entry(archive, name, payload, compression=zipfile.ZIP_STORED, alignment=1):
        entry = zipfile.ZipInfo(name, (2026, 10, 2, 18, 0, 0))
        entry.compress_type = compression
        entry.external_attr = 0o100644 << 16
        entry.comment = b"retained metadata"
        offset = archive.fp.tell() + 30 + len(name.encode("ascii"))
        padding = (-offset) % alignment
        if padding:
            if padding < 4:
                padding += alignment
            entry.extra = struct.pack("<HH", 0xFFFF, padding - 4) + bytes(padding - 4)
        archive.writestr(entry, payload)

    def _fixture(self, *, compression=zipfile.ZIP_STORED, alignment=4, native_stored=False):
        with zipfile.ZipFile(self.source, "w") as archive:
            archive.comment = b"archive comment"
            self._entry(archive, "AndroidManifest.xml", b"binary manifest fixture")
            self._entry(archive, "classes.dex", b"dex\n035\0fixture")
            self._entry(archive, "assets/_cl_/lumo3d.pck", b"game pack", zipfile.ZIP_DEFLATED)
            self._entry(archive, "resources.arsc", b"resource table", compression, alignment)
            self._entry(
                archive,
                "lib/arm64-v8a/libgodot_android.so",
                b"arm64 native payload",
                zipfile.ZIP_STORED if native_stored else zipfile.ZIP_DEFLATED,
                16384 if native_stored else 1,
            )

    def test_rejects_original_deflated_resources_fault(self):
        self._fixture(compression=zipfile.ZIP_DEFLATED)
        with self.assertRaisesRegex(ValueError, "resources.arsc must be uncompressed"):
            verify_apk(self.source)

    def test_rejects_stored_but_misaligned_resources(self):
        self._fixture(alignment=1)
        with zipfile.ZipFile(self.source) as archive:
            resources = archive.getinfo("resources.arsc")
            self.assertNotEqual((resources.header_offset + 30 + len(resources.filename)) % 4, 0)
        with self.assertRaisesRegex(ValueError, "4-byte boundary"):
            verify_apk(self.source)

    def test_accepts_aligned_resources_and_compressed_native_libraries(self):
        self._fixture()
        verify_apk(self.source)

    def test_accepts_16_kib_aligned_stored_native_libraries(self):
        self._fixture(native_stored=True)
        verify_apk(self.source)

    def test_rejects_misaligned_stored_native_library(self):
        self._fixture()
        with zipfile.ZipFile(self.source, "a") as archive:
            self._entry(archive, "lib/arm64-v8a/libother.so", b"uncompressed native library")
        with self.assertRaisesRegex(ValueError, "16-KiB alignment"):
            verify_apk(self.source)

    def test_prepare_preserves_payload_formats_metadata_and_dependency_meta_inf(self):
        self._fixture(compression=zipfile.ZIP_DEFLATED)
        removed = (
            "lib/x86/libgodot_android.so",
            "lib/armeabi-v7a/libgodot_android.so",
            "META-INF/OLD.SF",
            "META-INF/OLD.RSA",
            "META-INF/OLD.DSA",
            "META-INF/OLD.EC",
            "META-INF/MANIFEST.MF",
        )
        retained = (
            "META-INF/services/example.Service",
            "META-INF/androidx.core_core.version",
            "META-INF/LICENSE",
        )
        with zipfile.ZipFile(self.source, "a") as archive:
            for name in removed + retained:
                self._entry(archive, name, name.encode(), zipfile.ZIP_DEFLATED)
        prepare_apk(self.source, self.output)
        with zipfile.ZipFile(self.source) as original, zipfile.ZipFile(self.output) as output:
            self.assertEqual(output.comment, original.comment)
            for name in removed:
                self.assertNotIn(name, output.namelist())
            for name in original.namelist():
                if name in removed:
                    continue
                self.assertEqual(output.read(name), original.read(name))
                before, after = original.getinfo(name), output.getinfo(name)
                self.assertEqual(after.date_time, before.date_time)
                self.assertEqual(after.external_attr, before.external_attr)
                self.assertEqual(after.extra, before.extra)
                self.assertEqual(after.comment, before.comment)
                expected = zipfile.ZIP_STORED if name == "resources.arsc" else before.compress_type
                self.assertEqual(after.compress_type, expected)

    def test_rejects_preparing_over_input_or_a_hard_link(self):
        self._fixture()
        with self.assertRaisesRegex(ValueError, "different files"):
            prepare_apk(self.source, self.source)
        self.output.hardlink_to(self.source)
        with self.assertRaisesRegex(ValueError, "different files"):
            prepare_apk(self.source, self.output)

    def test_rejects_duplicate_paths(self):
        self._fixture()
        with warnings.catch_warnings():
            warnings.simplefilter("ignore", UserWarning)
            with zipfile.ZipFile(self.source, "a") as archive:
                archive.writestr("classes.dex", b"duplicate")
        with self.assertRaisesRegex(ValueError, "duplicate ZIP paths"):
            verify_apk(self.source)

    def test_rejects_corrupt_payload(self):
        self._fixture()
        with zipfile.ZipFile(self.source) as archive:
            dex = archive.getinfo("classes.dex")
        with self.source.open("r+b") as stream:
            stream.seek(dex.header_offset + 30 + len(dex.filename))
            stream.write(b"X")
        with self.assertRaisesRegex(ValueError, "ZIP CRC failed"):
            verify_apk(self.source)

    def test_rejects_missing_required_payload(self):
        self._fixture()
        for missing in ("AndroidManifest.xml", "classes.dex", "assets/_cl_/lumo3d.pck"):
            with self.subTest(missing=missing):
                path = self.root / "incomplete.apk"
                with zipfile.ZipFile(self.source) as source, zipfile.ZipFile(path, "w") as output:
                    for entry in source.infolist():
                        if entry.filename != missing:
                            output.writestr(entry, source.read(entry))
                with self.assertRaisesRegex(ValueError, "missing required file"):
                    verify_apk(path)

    def test_rejects_unwanted_abi_and_missing_wanted_native_library(self):
        self._fixture()
        with self.assertRaisesRegex(ValueError, "no native library for x86"):
            verify_apk(self.source, "x86")
        with zipfile.ZipFile(self.source, "a") as archive:
            self._entry(archive, "lib/x86/libgodot_android.so", b"x86")
        with self.assertRaisesRegex(ValueError, "unwanted native ABI"):
            verify_apk(self.source)


if __name__ == "__main__":
    unittest.main()
