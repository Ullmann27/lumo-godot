"""Inspect actual exported GLBs with Python stdlib; fail on missing content."""
import argparse
import hashlib
import json
import struct
from pathlib import Path

NEW = {"learn_idle_breathe","learn_listen","learn_think","learn_explain",
       "learn_point","learn_nod","learn_unsure","learn_encourage",
       "learn_celebrate","learn_interrupt","learn_return_listen","learn_farewell"}
OLD = {"idle","greeting_wave","celebrate","point_portal","agree_nod",
       "kart_seated","kart_steer_left","kart_steer_right","kart_jump"}
PROPS = {"CounterBerry","CounterBerryGold","LetterTile","TenBundle","ShapeCircle",
         "ShapeSquare","ShapeTriangle","TenFrameCell","LearningPodium"}


def parse(path):
    binary = path.read_bytes()
    assert binary[:4] == b"glTF"
    version, length = struct.unpack_from("<II",binary,4)
    assert version == 2 and length == len(binary)
    at = 12
    data = None
    while at < len(binary):
        n, kind = struct.unpack_from("<II",binary,at)
        if kind == 0x4e4f534a:
            data = json.loads(binary[at+8:at+8+n].decode())
        at += 8+n
    assert at == len(binary) and isinstance(data,dict)
    return data


def check(character, objects, report_path):
    c, p = parse(character), parse(objects)
    names = {a.get("name","") for a in c.get("animations",[])}
    assert NEW <= names, "new animation missing: " + str(NEW-names)
    assert OLD <= names, "original animation lost: " + str(OLD-names)
    nodes = {n.get("name","") for n in c.get("nodes",[])}
    assert "MouthVisemes" in nodes, "mouth geometry missing"
    assert any(n.startswith("Eyelid") for n in nodes), "eyelids missing"
    assert len(c.get("skins", [])) == 1
    assert len(c["skins"][0]["joints"]) == 65
    morphs = set()
    triangles = 0
    for mesh in c.get("meshes", []):
        for primitive in mesh.get("primitives",[]):
            assert primitive.get("mode",4) == 4
            triangles += c["accessors"][primitive["indices"]]["count"] // 3
            if primitive.get("targets"):
                morphs.update(mesh.get("extras",{}).get("targetNames",[]))
    assert triangles <= 36000, ("triangle budget: %d" % triangles)
    assert len([s for s in morphs if s.startswith("viseme_")]) >= 8, str(morphs)
    prop_nodes = {n.get("name","") for n in p.get("nodes",[])}
    assert PROPS <= prop_nodes, str(PROPS-prop_nodes)
    assert character.stat().st_size < 22000000
    audit = {
        "character_sha256": hashlib.sha256(character.read_bytes()).hexdigest(),
        "props_sha256": hashlib.sha256(objects.read_bytes()).hexdigest(),
        "triangles": triangles, "bones": 65, "clips_original": sorted(OLD),
        "clips_added": sorted(NEW), "morphs": sorted(morphs),
        "props": sorted(PROPS), "android_fps_measured": False}
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(audit,indent=2)+"\n")
    print("LUMO_CHAT3_GLB_PASS", json.dumps(audit))
    return audit


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("character",type=Path)
    p.add_argument("props",type=Path)
    p.add_argument("audit",type=Path)
    a = p.parse_args()
    check(a.character,a.props,a.audit)
