"""Vertrag der Eigenbau-Assets der Abenteuerwelten (Schatzinsel, Bühne, Atelier, Spielewelt).

Prüft die tatsächlich eingecheckten GLBs und Texturen: erwartete Modelle, Dreiecks-
budgets, endliche Positionen, nur benannte Materialien ohne eingebettete Bilder,
Texturgrößen <= 1024 px, keine Einzeldatei > 1,5 MB und Gesamtgröße <= 20 MB.
"""
import json
import math
from pathlib import Path
import re
import struct
import unittest

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "assets/creative/adventure"
KIT = ROOT / "scripts/creative/adventure_kit.gd"
EXPECTED = {
    "flora": {"tree_oak_a", "tree_oak_b", "tree_oak_c", "palm_a", "palm_b", "bush_a", "bush_b", "fern", "grass_tuft", "grass_flowers"},
    "ruins": {"rock_a", "rock_b", "rock_c", "boulder_cliff", "ruin_column", "ruin_column_broken", "ruin_column_fallen",
              "ruin_wall", "ruin_arch", "cave_entrance", "star_castle", "arch_welcome", "arch_gate", "shells"},
    "props": {"lighthouse", "campfire", "tent", "crate", "barrel", "signpost"},
    "fauna": {"crab", "gull", "butterfly"},
    "stage": {"speaker_tower", "truss_beam", "moving_head"},
    "atelier": {"atelier_lamp", "easel", "paint_jars"},
    "hub": {"gate_stone", "gate_wood", "gate_ring"},
}
COMPONENT = {5120: ("b", 1), 5121: ("B", 1), 5122: ("h", 2), 5123: ("H", 2), 5125: ("I", 4), 5126: ("f", 4)}
SIZE = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def read_glb(path):
    data = path.read_bytes()
    magic, version, _length = struct.unpack_from("<4sII", data, 0)
    if magic != b"glTF" or version != 2:
        raise ValueError("not a glTF 2 binary")
    json_len, json_type = struct.unpack_from("<I4s", data, 12)
    doc = json.loads(data[20:20 + json_len])
    bin_off = 20 + json_len
    bin_len, _bin_type = struct.unpack_from("<I4s", data, bin_off)
    return doc, data[bin_off + 8: bin_off + 8 + bin_len]


def accessor_values(doc, blob, index):
    acc = doc["accessors"][index]
    view = doc["bufferViews"][acc["bufferView"]]
    fmt, width = COMPONENT[acc["componentType"]]
    comps = SIZE[acc["type"]]
    stride = view.get("byteStride", width * comps)
    start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    for i in range(acc["count"]):
        yield struct.unpack_from("<" + fmt * comps, blob, start + i * stride)


def mesh_stats(doc, blob, mesh):
    tris = 0
    finite = True
    materials = set()
    for prim in mesh["primitives"]:
        if "indices" in prim:
            tris += doc["accessors"][prim["indices"]]["count"] // 3
        else:
            tris += doc["accessors"][prim["attributes"]["POSITION"]]["count"] // 3
        for value in accessor_values(doc, blob, prim["attributes"]["POSITION"]):
            if not all(math.isfinite(v) for v in value):
                finite = False
        if "material" in prim:
            materials.add(doc["materials"][prim["material"]]["name"])
    return tris, finite, materials


class AdventureArtTests(unittest.TestCase):
    def test_every_model_set_has_its_models_finite_and_within_budget(self):
        kit_source = KIT.read_text()
        known_materials = set(re.findall(r'"([a-z_]+)"', kit_source))
        for set_name, names in EXPECTED.items():
            path = BASE / "models" / f"adventure_{set_name}.glb"
            self.assertTrue(path.exists(), path)
            self.assertLess(path.stat().st_size, 1_500_000, path)
            doc, blob = read_glb(path)
            self.assertNotIn("images", doc, "Texturen liegen einmal extern, nicht im GLB")
            found = {}
            for node in doc["nodes"]:
                if "mesh" in node:
                    found[node["name"]] = doc["meshes"][node["mesh"]]
            self.assertEqual(set(found), names, set_name)
            for name, mesh in found.items():
                tris, finite, materials = mesh_stats(doc, blob, mesh)
                self.assertTrue(finite, name)
                self.assertGreater(tris, 1, name)
                self.assertLess(tris, 6000, f"{name} bleibt mobil ({tris} Dreiecke)")
                self.assertTrue(materials, name)
                for material in materials:
                    self.assertIn(material, known_materials, f"{name}: Material {material} hat eine Zuordnung in AdventureKit")

    def test_textures_are_small_bounded_and_counted(self):
        from PIL import Image  # bpyenv bringt Pillow mit
        files = [p for p in (BASE / "textures").iterdir() if p.suffix in {".png", ".jpg"}]
        self.assertGreaterEqual(len(files), 30)
        for path in files:
            self.assertLess(path.stat().st_size, 1_500_000, path)
            with Image.open(path) as img:
                self.assertLessEqual(max(img.size), 1024, path)
        total = sum(p.stat().st_size for p in BASE.rglob("*") if p.is_file() and p.suffix in {".png", ".jpg", ".glb"})
        self.assertLess(total, 20 * 1024 * 1024)

    def test_shaders_stay_mobile_and_compatibility_safe(self):
        for path in (BASE / "shaders").glob("*.gdshader"):
            text = path.read_text()
            self.assertNotIn("hint_screen_texture", text, path)
            self.assertNotIn("hint_depth_texture", text, path)
            self.assertIn("shader_type spatial", text, path)

    def test_corrupt_position_is_detected(self):
        doc, blob = read_glb(BASE / "models/adventure_fauna.glb")
        prim = doc["meshes"][0]["primitives"][0]
        acc = doc["accessors"][prim["attributes"]["POSITION"]]
        view = doc["bufferViews"][acc["bufferView"]]
        broken = bytearray(blob)
        struct.pack_into("<f", broken, view.get("byteOffset", 0) + acc.get("byteOffset", 0), float("nan"))
        _tris, finite, _mats = mesh_stats(doc, bytes(broken), doc["meshes"][0])
        self.assertFalse(finite)


if __name__ == "__main__":
    unittest.main()
