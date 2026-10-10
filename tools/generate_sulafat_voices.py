#!/usr/bin/env python3
"""Replace every legacy letter/word voice WAV with Gemini Sulafat.

Mandatory GEMINI_API_KEY environment variable. No child's data is sent:
only the 52 static words/letters stored in this repository.
All files are staged before they overwrite legacy voice WAVs. The
runtime's sulafat_manifest.json then proves that only those generated
files can play; no legacy eSpeak recording can slip through.
"""
import base64
import argparse
import hashlib
import json
import os
from pathlib import Path
import sys
import urllib.error
import urllib.request
import wave
import io

ROOT = Path(__file__).resolve().parents[1]
VOICE = ROOT / "assets/audio/voice"
REFERENCE_MODEL = "gemini-2.5-pro-preview-tts"
PROFILE = "lumo-sulafat-reference-v1"
MODEL = os.environ.get("GEMINI_TTS_MODEL", REFERENCE_MODEL)
KEY = os.environ.get("GEMINI_API_KEY", "").strip()

def validate_wav(audio: bytes) -> bytes:
    if len(audio) < 44 or len(audio) > 480044:
        raise RuntimeError("Invalid static speech size")
    with wave.open(io.BytesIO(audio)) as w:
        if w.getnchannels() != 1 or w.getsampwidth() != 2 or w.getframerate() != 24000:
            raise RuntimeError("Unexpected audio format; do not overwrite legacy")
        if not 2400 <= w.getnframes() <= 240000:
            raise RuntimeError("Static speech must be between 0.1 and 10 seconds")
        frames = w.readframes(w.getnframes())
        if len(frames) != w.getnframes() * 2 or not any(frames):
            raise RuntimeError("Truncated or silent static speech")
    return audio


def decode_provider_audio(body: dict) -> bytes:
    parts = body.get("candidates", [{}])[0].get("content", {}).get("parts", [])
    inline = next((p.get("inlineData") for p in parts if p.get("inlineData")), None)
    if not inline or not isinstance(inline.get("data"), str) or len(inline["data"]) > 700000:
        raise RuntimeError("Provider returned no bounded generated audio")
    audio = base64.b64decode(inline["data"], validate=True)
    if audio[:4] == b"RIFF" and audio[8:12] == b"WAVE":
        return validate_wav(audio)
    mime = str(inline.get("mimeType", "")).lower()
    if mime not in ("audio/pcm;rate=24000", "audio/l16;codec=pcm;rate=24000",
                    "audio/l16;rate=24000", "audio/pcm", "audio/l16"):
        raise RuntimeError("Compressed or unknown audio is not PCM")
    if len(audio) < 4800 or len(audio) > 480000 or len(audio) % 2:
        raise RuntimeError("Gemini PCM is malformed")
    dest = io.BytesIO()
    with wave.open(dest, "wb") as writer:
        writer.setnchannels(1)
        writer.setsampwidth(2)
        writer.setframerate(24000)
        writer.writeframes(audio)
    return validate_wav(dest.getvalue())


def generate(text: str, use_credential_proxy: bool = False) -> bytes:
    if MODEL != REFERENCE_MODEL:
        raise RuntimeError("Refusing unapproved reference-model change")
    if not KEY and not use_credential_proxy:
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
      headers={"Content-Type": "application/json", **({"x-goog-api-key": KEY} if KEY else {})},
      method="POST",
    )
    with urllib.request.urlopen(request, timeout=50) as response:
        raw = response.read(700001)
        if len(raw) > 700000:
            raise RuntimeError("Provider response exceeds static speech limit")
        body = json.loads(raw)
    return decode_provider_audio(body)


def generate_batch(paths: list[Path], staging: Path, use_credential_proxy: bool = False) -> dict:
    if len(paths) != 52 or len(set(paths)) != 52:
        raise RuntimeError("Expected exactly 52 distinct voice files")
    checksums = {}
    for idx, src in enumerate(paths, 1):
        rel = src.relative_to(VOICE)
        spoken = src.stem.upper() if rel.parts[0] == "letters" else src.stem.capitalize()
        target = staging / rel
        receipt = target.with_suffix(".json")
        expected = {"text": spoken, "voice": "Sulafat", "model": MODEL, "profile": PROFILE}
        reuse = False
        if target.is_file() and receipt.is_file():
            try:
                prior = json.loads(receipt.read_text())
                audio = validate_wav(target.read_bytes())
                reuse = all(prior.get(k) == v for k, v in expected.items()) and (
                    prior.get("sha256") == hashlib.sha256(audio).hexdigest())
            except (ValueError, RuntimeError, wave.Error, EOFError):
                reuse = False
        if not reuse:
            print(f"Generating Sulafat {idx}/{len(paths)}: {rel}", flush=True)
            audio = generate(spoken, use_credential_proxy)
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(audio)
            receipt.write_text(json.dumps({**expected,
                "sha256": hashlib.sha256(audio).hexdigest()}, ensure_ascii=False) + "\n")
        else:
            print(f"Reusing verified Sulafat: {rel}", flush=True)
        checksums[str(rel)] = hashlib.sha256(target.read_bytes()).hexdigest()
    return checksums

def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--credential-proxy", action="store_true",
        help="Use the secure Computer HTTP credential injection, never a pasted key")
    parser.add_argument("--stage-dir", type=Path, default=ROOT / ".lumo-voice-staging")
    parser.add_argument("--publish", action="store_true",
        help="Replace the complete bank only after reviewing the generated audio")
    args = parser.parse_args()
    paths = sorted([*VOICE.glob("letters/*.wav"), *VOICE.glob("words/*.wav")])
    if len(paths) != 52:
        raise RuntimeError(f"Expected 52 voice files, found {len(paths)}; refusing partial replacement")
    staging = args.stage_dir
    checksums = generate_batch(paths, staging, args.credential_proxy)
    if not args.publish:
        print("52 recordings staged for audible comparison. Product audio remains unchanged.")
        return
    if args.publish:
        if len(checksums) != len(paths):
            raise RuntimeError("Incomplete Sulafat generation; leaving legacy untouched")
        for src in paths:
            src.write_bytes((staging / src.relative_to(VOICE)).read_bytes())
        manifest = {
            "version": 1,
            "voice": "Sulafat",
            "generation": "Gemini TTS",
            "model": MODEL,
            "profile": PROFILE,
            "files": checksums,
        }
        (VOICE / "sulafat_manifest.json").write_text(
            json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf8"
        )
    print("52 Sulafat replacement voice files staged and committed-ready.")

if __name__ == "__main__":
    main()
