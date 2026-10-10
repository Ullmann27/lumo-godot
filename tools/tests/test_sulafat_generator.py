import base64
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import wave

spec = importlib.util.spec_from_file_location("sulafat",
    Path(__file__).parents[1] / "generate_sulafat_voices.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


def speech():
    output = io.BytesIO()
    with wave.open(output, "wb") as audio:
        audio.setnchannels(1)
        audio.setsampwidth(2)
        audio.setframerate(24000)
        audio.writeframes(b"\x10\x01" * 4800)
    return output.getvalue()


class SulafatGeneratorTest(unittest.TestCase):
    def test_reference_profile_is_fixed_and_compressed_audio_is_rejected(self):
        self.assertEqual(module.MODEL, "gemini-2.5-pro-preview-tts")
        payload = {"candidates": [{"content": {"parts": [{"inlineData": {
            "mimeType": "audio/mpeg", "data": base64.b64encode(b"\x10" * 9600).decode()
        }}]}}]}
        with self.assertRaisesRegex(RuntimeError, "not PCM"):
            module.decode_provider_audio(payload)
        with self.assertRaisesRegex(RuntimeError, "silent"):
            silent = bytearray(speech())
            silent[44:] = b"\0" * (len(silent) - 44)
            module.validate_wav(bytes(silent))

    def test_resume_reuses_all_verified_recordings_without_provider_calls(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            voice, stage = root / "voice", root / "stage"
            paths = [voice / "letters" / f"{chr(97 + n)}.wav" for n in range(26)]
            paths += [voice / "words" / f"word{n}.wav" for n in range(26)]
            with patch.object(module, "VOICE", voice), patch.object(
                module, "generate", return_value=speech()) as generate:
                first = module.generate_batch(paths, stage)
                self.assertEqual(generate.call_count, 52)
                generate.reset_mock()
                second = module.generate_batch(paths, stage)
                self.assertEqual(first, second)
                generate.assert_not_called()
                receipt = stage / "letters/a.json"
                data = json.loads(receipt.read_text())
                data["model"] = "different-voice-model"
                receipt.write_text(json.dumps(data))
                module.generate_batch(paths, stage)
                self.assertEqual(generate.call_count, 1)
            self.assertFalse((voice / "sulafat_manifest.json").exists())

    def test_partial_batch_never_changes_product_and_keeps_completed_staging(self):
        with tempfile.TemporaryDirectory() as tmp:
            voice, stage = Path(tmp) / "voice", Path(tmp) / "stage"
            paths = [voice / "letters" / f"{chr(97 + n)}.wav" for n in range(26)]
            paths += [voice / "words" / f"word{n}.wav" for n in range(26)]
            with patch.object(module, "VOICE", voice), patch.object(
                module, "generate", side_effect=[speech(), RuntimeError("offline")]):
                with self.assertRaisesRegex(RuntimeError, "offline"):
                    module.generate_batch(paths, stage)
            self.assertTrue((stage / "letters/a.wav").exists())
            self.assertFalse(voice.exists())


if __name__ == "__main__":
    unittest.main()
