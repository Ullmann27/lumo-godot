"""Targeted exterior-only portal rebuild preserving every other GLB byte."""
import hashlib
import json
from pathlib import Path
import sys

import bpy
from mathutils import Matrix

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_tunnel_kit as kit


def remove_collection(name):
    coll = bpy.data.collections.get(name)
    if coll:
        for obj in list(coll.objects):
            bpy.data.objects.remove(obj, do_unlink=True)
        bpy.data.collections.remove(coll)


def main():
    repo = Path(sys.argv[sys.argv.index("--") + 1]).resolve()
    theme_id = "zauberwald"
    assets = repo / "assets/kart/production/tracks" / theme_id
    source = repo / "art/lumo_kart/blender/tracks/zauberwald_tunnel_workshop.blend"
    evidence = repo / "evidence/lumo_kart_art/tracks/zauberwald"
    targets = {"portal_entry.glb", "portal_entry_lod1.glb", "portal_exit.glb", "portal_exit_lod1.glb"}
    frozen = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in assets.glob("*.glb") if p.name not in targets}
    manifest = json.loads((assets / "manifest.json").read_text())
    bpy.ops.wm.open_mainfile(filepath=str(source))
    kit.ICO_CACHE.clear()
    kit.CUBE_CACHE.clear()
    kit.DETAIL_LOD = 0
    theme = kit.THEMES[theme_id]
    mats = {key: bpy.data.materials[f"{theme_id}_{key}"] for key in ("outer","inner","trim","accent","light","secondary","roof")}
    remove_collection("REVIEW_Assembled_Track")
    roots, paths = {}, {}
    for kind in manifest["modules"]:
        if kind not in ("portal_entry", "portal_exit"):
            coll = bpy.data.collections["SOURCE_" + kind]
            roots[kind] = next(o for o in coll.objects if o.get("module_kind") == kind)
            paths[kind] = kit.TrackPath(kind)
    for kind in ("portal_entry", "portal_exit"):
        remove_collection("SOURCE_" + kind)
        coll = kit.collection("SOURCE_" + kind)
        root, path = kit.make_module(kind, theme_id, theme, mats, coll)
        export_collection = kit.collection("PORTAL_EXPORT_" + kind)
        clone = kit.instance_module(root, export_collection, Matrix.Identity(4), "PortalExport")
        kit.combine_by_material(clone)
        kit.export_glb(assets / f"{kind}.glb", kit.descendants(clone))
        manifest["modules"][kind]["lod0"] = kit.audit(clone)
        kit.DETAIL_LOD = 1
        lod, _ = kit.make_module(kind, theme_id, theme, mats, export_collection)
        kit.DETAIL_LOD = 0
        kit.combine_by_material(lod)
        kit.export_glb(assets / f"{kind}_lod1.glb", kit.descendants(lod))
        manifest["modules"][kind]["lod1"] = kit.audit(lod)
        remove_collection(export_collection.name)
        roots[kind], paths[kind] = root, path
    kit.prepare_review(roots, paths, theme_id, mats, evidence, False, False)
    bpy.ops.file.pack_all()
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(source), compress=True)
    (assets / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    after = {name: hashlib.sha256((assets / name).read_bytes()).hexdigest() for name in frozen}
    assert frozen == after, "A frozen non-portal or collision GLB changed"
    report = dict(changed_visible_glbs=sorted(targets), preserved_glb_sha256=after,
                  scope="Exterior portal roots only; inner race modules and every collision proxy preserved byte-for-byte")
    (evidence / "portal_refinement_scope.json").write_text(json.dumps(report, indent=2) + "\n")
    print("PORTAL_REFINEMENT_PASS", len(targets), "changed", len(frozen), "byte-identical", flush=True)


if __name__ == "__main__":
    main()
