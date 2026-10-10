#!/usr/bin/env python3
"""Replace every legacy letter/word voice WAV with Gemini Sulafat.

Mandatory GEMINI_API_KEY environment variable. No child's data is sent:
only the 52 static words/letters stored in this repository.
All files are staged before they overwrite legacy voice WAVs. The
runtime's sulafat_manifest.json then proves that only those generated
files can play; no legacy eSpeak recording can slip through.
"""
import base64
import hashlib
import json
import os
from pathlib import Path
import sys
import tempfile
import urllib.error
import urllib.request
import wave
import io

ROOT = Path(__file__).resolve().parents[1]
VOICE = ROOT / "assets/audio/voice"
MODEL = os.environ.get("GEMINI_TTS_MODEL", "gemini-3.1-flash-tts-preview")
KEY = os.environ.get("GEMINI_API_KEY", "").strip()

def generate(text: str) -> bytes:
    if not KEY:
        raise RuntimeError("GEMINI_API_KEY not set; refusing to replace existing voice")
    prompt = ("Sprich mit der originalen warmen Sulafat-Stimme in klar verständlichem Deutsch. "
              "Lies NUR genau den Buchstaben beziehungsweise das Wort vor, "
              "ohne Einleitung, Erklärung oder Zusätze: " + text)
    payload = {
      "contents": [{"role": "user", "parts": [{"text": prompt}]}],
      "generationConfig": {
        "responseModalities": ["AUDIO"],
        "speechConfig": {"voiceConfig": {
          "prebuiltVoiceConfig": {"voiceName": "Sulafat"}
        }}
      }
    }
    request = urllib.request.Request(
      f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent",
      data=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
      headers={"Content-Type": "application/json", "x-goog-api-key": KEY},
      method="POST",
    )
    with urllib.request.urlopen(request, timeout=50) as response:
        body = json.load(response)
    parts = body.get("candidates", [{}])[0].get("content", {}).get("parts", [])
    data = next((p.get("inlineData", {}).get("data") for p in parts if p.get("inlineData")), None)
    if not data:
        raise RuntimeError("Provider returned no generated audio")
    audio = base64.b64decode(data, validate=True)
    if audio[:4] == b"RIFF" and audio[8:12] == b"WAVE":
        source = io.BytesIO(audio)
        with wave.open(source) as w:
            if w.getnchannels() != 1 or w.getsampwidth() != 2 or w.getframerate() != 24000:
                raise RuntimeError("Unexpected audio format; do not overwrite legacy")
        return audio
    if len(audio) < 100 or len(audio) % 2:
        raise RuntimeError("Gemini PCM is malformed")
    dest = io.BytesIO()
    with wave.open(dest, "wb") as writer:
        writer.setnchannels(1)
        writer.setsampwidth(2)
        writer.setframerate(24000)
        writer.writeframes(audio)
    return dest.getvalue()

def main() -> None:
    paths = sorted([*VOICE.glob("letters/*.wav"), *VOICE.glob("words/*.wav")])
    if len(paths) != 52:
        raise RuntimeError(f"Expected 52 voice files, found {len(paths)}; refusing partial replacement")
    with tempfile.TemporaryDirectory(prefix="lumo_sulafat_") as tmp:
        staging = Path(tmp)
        checksums = {}
        for idx, src in enumerate(paths, 1):
            rel = src.relative_to(VOICE)
            spoken = src.stem.upper() if rel.parts[0] == "letters" else src.stem.capitalize()
            print(f"Generating Sulafat {idx}/{len(paths)}: {rel}", flush=True)
            wav = generate(spoken)
            target = staging / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(wav)
            checksums[str(rel)] = hashlib.sha256(wav).hexdigest()
        if len(checksums) != len(paths):
            raise RuntimeError("Incomplete Sulafat generation; leaving legacy untouched")
        for src in paths:
            src.write_bytes((staging / src.relative_to(VOICE)).read_bytes())
        manifest = {
            "version": 1,
            "voice": "Sulafat",
            "generation": "Gemini TTS",
            "model": MODEL,
            "files": checksums,
        }
        (VOICE / "sulafat_manifest.json").write_text(
            json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf8"
        )
    print("52 Sulafat replacement voice files staged and committed-ready.")

if __name__ == "__main__":
    main()
