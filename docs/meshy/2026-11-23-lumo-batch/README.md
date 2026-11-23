# LUMO Meshy batch · 23 November 2026

This directory records the isolated LUMO image-to-3D generation batch recovered from the connected Meshy account.

## What is proven

- 29 succeeded, textured `image-to-3d` tasks belong to the recovered LUMO batch window.
- Their normalized geometry separates into 10 upright character candidates, 14 low/wide vehicle-body candidates, four environment/garage candidates and one unresolved upright outlier.
- Two later succeeded character-shaped image-to-3D tasks are recorded separately as rework candidates.
- The simultaneous Imperathen/Roman work uses explicit Roman `text-to-3d` prompts and is excluded from this LUMO manifest.

## What is deliberately not claimed

Opaque image-to-3D tasks do not preserve a trustworthy original LUMO asset name in the task metadata. Therefore this record does **not** invent a mapping such as “task X = Frosch” or “task Y = Kart 7”. Identity is assigned only after a visual/source match can be demonstrated.

## Production gate

A Meshy model is a candidate, not automatically a production replacement. Before replacing a committed LUMO asset it must pass:

1. source/identity match;
2. complete geometry from the required gameplay views;
3. material and texture quality;
4. correct orientation, scale and collision envelope;
5. Android-appropriate LOD plan;
6. driver-seat, wheel and camera clearance for vehicles;
7. rig, skin and required reaction animation compatibility for animated characters;
8. real Godot import and runtime regression.

Existing authored production drivers remain authoritative until a candidate passes that gate. The current imported driver set already has LOD0/1/2, the gameplay skeleton and authored kart/menu reactions; a visually attractive but unrigged or shallow portrait reconstruction must not silently replace it.

## Security / provenance

Expiring Meshy download URLs and signatures are intentionally not committed. The durable identifiers are the Meshy task IDs and measured metadata in `manifest.json`.
