#!/usr/bin/env python3
"""Lumos Sternenpost: alle Blender-Modelle der Welt Wolkenhafen.

Aufruf: /home/user/tools/bpyenv/bin/python tools/lumo_skypost_art/build_skypost_models.py [modell ...]
Ausgabe: assets/skypost/models/<modell>.glb, Objekte <modell>_lod0/_lod1/_lod2 (+ bewegliche Teile)
und assets/skypost/models/skypost_models.json (Dreiecke je Stufe, Drehpunkte).

Alles selbst modelliert (keine fremde Geometrie, keine Bilder). Godot setzt die Sichtweiten
der Stufen (scripts/games/skypost/sky_post_models.gd) und ersetzt Wand-, Lack- und
Inselmaterialien durch eigene Shader bzw. Farbvarianten.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import skypost_geo as G  # noqa: E402
import build_glider as GL  # noqa: E402
import build_world as W  # noqa: E402

ROOT = HERE.parents[1]
OUT = G.OUT


def glider():
    m = GL.mats()
    root = G.empty("sternsegler")
    info = {"lods": [], "pivots": {}}
    for detail in range(3):
        model = G.Model()
        GL.body(model, m, detail)
        if detail > 0:
            # Distant levels carry the control surfaces in their rest pose.
            GL.aileron(model, m, -1)
            GL.aileron(model, m, 1)
            GL.elevator(model, m)
            GL.rudder(model, m)
        obj = model.build("sternsegler_lod%d" % detail, root)
        info["lods"].append(G.tri_count(obj))
    parts = {
        "Yoke": (GL.YOKE_AT, lambda mdl: GL.yoke(mdl, m, 0), True),
        "Propeller": (GL.PROP_AT, lambda mdl: GL.propeller(mdl, m, 0), True),
        "AileronL": (GL.aileron_hinge(-1), lambda mdl: GL.aileron(mdl, m, -1), False),
        "AileronR": (GL.aileron_hinge(1), lambda mdl: GL.aileron(mdl, m, 1), False),
        "Elevator": (GL.ELEVATOR_AT, lambda mdl: GL.elevator(mdl, m), False),
        "Rudder": (GL.RUDDER_AT, lambda mdl: GL.rudder(mdl, m), False),
    }
    for name, (pivot, make, local) in parts.items():
        model = G.Model()
        make(model)
        obj = model.build(name, root, origin=pivot, local=local)
        info["pivots"][name] = [round(v, 4) for v in pivot]
        info["lods"][0] += G.tri_count(obj)
    G.export_glb(root, OUT / "sternsegler.glb")
    return info


BUILDERS = {"sternsegler": glider}
BUILDERS.update(W.BUILDERS)


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    wanted = args or list(BUILDERS)
    OUT.mkdir(parents=True, exist_ok=True)
    manifest_path = OUT / "skypost_models.json"
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
    for name in wanted:
        G.reset_scene()
        info = BUILDERS[name]()
        manifest[name] = info
        print("[skypost] %s: lods %s" % (name, info["lods"]))
    manifest_path.write_text(json.dumps(dict(sorted(manifest.items())), indent=1) + "\n")


if __name__ == "__main__":
    main()
