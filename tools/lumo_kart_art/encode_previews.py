#!/usr/bin/env python3
"""Encode actual Godot viewport captures and preserve their measured provenance."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

KINDS = {
    "tunnel": ("tunnel_frames", "tunnel_capture.json", "lumo_zauberwald_flythrough.mp4", 96),
    "karts": ("turntable_frames", "turntable_capture.json", "lumo_aurora_karts.mp4", 144),
    "drivers": ("animation_frames", "animation_capture.json", "lumo_driver_animations.mp4", 312),
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("kind", choices=KINDS)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--remove-frames", action="store_true")
    parser.add_argument("--frames-root", type=Path)
    args = parser.parse_args()
    folder_name, receipt_name, movie_name, expected_frames = KINDS[args.kind]
    evidence = args.root.resolve() / "evidence/lumo_kart_art/review"
    folder = (args.frames_root.resolve() if args.frames_root else evidence) / folder_name
    receipt_path = evidence / receipt_name
    receipt = json.loads(receipt_path.read_text())
    frames = receipt["frames"]
    if len(frames) != expected_frames:
        raise RuntimeError(f"Incomplete {args.kind} recording: {len(frames)}/{expected_frames}")
    for number, record in enumerate(frames):
        path = folder / f"{number:04d}.png"
        if record["frame"] != number or sha256(path) != record["sha256"]:
            raise RuntimeError(f"Capture provenance mismatch: {path}")
    movie = evidence / movie_name
    temporary = movie.with_name(movie.stem + ".encoding.mp4")
    command = ["ffmpeg", "-hide_banner", "-loglevel", "warning", "-y",
               "-framerate", str(receipt["fps"]), "-i", str(folder / "%04d.png"),
               "-frames:v", str(len(frames)), "-an", "-c:v", "libx264",
               "-threads", "2", "-preset", "medium", "-crf", "18",
               "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(temporary)]
    subprocess.run(command, check=True)
    probe = json.loads(subprocess.check_output([
        "ffprobe", "-v", "error", "-count_frames", "-show_streams", "-show_format",
        "-of", "json", str(temporary)], text=True))
    video = next(stream for stream in probe["streams"] if stream["codec_type"] == "video")
    if int(video["nb_read_frames"]) != len(frames):
        raise RuntimeError("Encoded video frame count does not match the captured frames")
    temporary.replace(movie)
    selected = evidence / "video_stills"
    selected.mkdir(exist_ok=True)
    for index in (0, len(frames) // 2, len(frames) - 1):
        shutil.copyfile(folder / f"{index:04d}.png", selected / f"{args.kind}_{index:04d}.png")
    report = {
        "movie": movie.relative_to(args.root.resolve()).as_posix(),
        "sha256": sha256(movie), "bytes": movie.stat().st_size,
        "capture_receipt": receipt_path.relative_to(args.root.resolve()).as_posix(),
        "capture_receipt_sha256": sha256(receipt_path),
        "captured_frames": len(frames), "encoded_frames": int(video["nb_read_frames"]),
        "width": video["width"], "height": video["height"], "fps": video["r_frame_rate"],
        "duration_seconds": float(video["duration"]), "codec": video["codec_name"],
        "pixel_format": video["pix_fmt"], "renderer": receipt["renderer"],
        "physical_android": False, "runtime_fps_measurement": False,
        "method": "Frame-by-frame capture of actual Godot rendering; encoded with FFmpeg, no generated concept imagery",
    }
    movie.with_suffix(".json").write_text(json.dumps(report, indent=2) + "\n")
    if args.remove_frames:
        for record in frames:
            (folder / f"{record['frame']:04d}.png").unlink()
        folder.rmdir()
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
