"""Render reproducible review views from the editable tunnel .blend source."""
import argparse
from pathlib import Path
import sys

import bpy
from mathutils import Vector

VIEWS = {
    "portal": ((17, -20, 11), (0, 5, 3.5), 29),
    "interior": ((0, 7, 2.52), (0, 18, 1.25), 23.05),
    "bend": ((0, 13, 2.52), (2.0, 25, 1.25), 23.05),
    "rear": ((34, 66, 12), (16, 44, 3), 31),
    "underside": ((42, -32, -32), (4, 20, -0.5), 26),
}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, required=True)
    parser.add_argument("--theme", required=True)
    parser.add_argument("--views", nargs="+", default=list(VIEWS))
    parser.add_argument("--width", type=int, default=1600)
    parser.add_argument("--height", type=int, default=1000)
    parser.add_argument("--samples", type=int, default=32)
    parser.add_argument("--threads", type=int, default=3)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    root = args.repo.resolve()
    source = root / "art/lumo_kart/blender/tracks" / f"{args.theme}_tunnel_workshop.blend"
    target = root / "evidence/lumo_kart_art/tracks" / args.theme
    target.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.open_mainfile(filepath=str(source))
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.use_denoising = False
    scene.cycles.samples = args.samples
    scene.render.threads_mode = "FIXED"
    scene.render.threads = args.threads
    scene.render.resolution_x = args.width
    scene.render.resolution_y = args.height
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    cam = scene.camera
    cam.data.sensor_fit = "VERTICAL"
    cam.data.sensor_height = 24
    for name in args.views:
        pos, focus, lens = VIEWS[name]
        cam.location = pos
        cam.rotation_euler = (Vector(focus) - cam.location).to_track_quat("-Z", "Y").to_euler()
        cam.data.lens = lens
        ground = bpy.data.objects.get("ReviewGround")
        if ground:
            ground.hide_render = name == "underside"
            if any(o.get("lumo_terrain_cover") for o in scene.objects):
                ground.location.z = -0.10
        if name == "underside":
            data = bpy.data.lights.new("UndersideInspectionFill", "AREA")
            data.energy, data.size = 12500, 25
            lamp = bpy.data.objects.new("UndersideInspectionFill", data)
            scene.collection.objects.link(lamp)
            lamp.location = (12, 15, -20)
            lamp.rotation_euler = (Vector((4, 17, -1)) - lamp.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = str(target / f"{args.theme}_{name}.png")
        bpy.ops.render.render(write_still=True)
        print("LUMO_TRACK_RENDER", args.theme, name, args.width, args.height, flush=True)


if __name__ == "__main__":
    main()
