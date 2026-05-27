# Lumo 3D Asset Pack — Godot Import Notes

Dieses Paket enthält programmgenerierte Original-PNGs für eine mobile 3D-Lernwelt.

## Einsatz in Godot 4
- `textures/albedo/*`: Base Color / Albedo für StandardMaterial3D
- `textures/normal/*`: Normal Map passend zu Albedo-Materialien
- `textures/emission/*`: Emission Maps für Portale/Hologrid
- `particles/*`: transparente Partikel-Sprites für GPUParticles3D oder billboards
- `billboards/*`: 3D-Billboard-Objekte, Icons, Orbs, Kristalle, Lernsymbole
- `portals/*`: transparente Portal-Ringe für MeshInstance3D Plane + Unshaded/Emission
- `sky_gradients/*`: Hintergründe, Panorama-Planes, WorldEnvironment-Backdrops
- `ui_panels/*`: 3D/2D UI-Panels
- `masks/*`: Alpha-/Dissolve-/Shader-Masken

## Mobile Empfehlung
- Android: Texturen mit Basis Universal/VRAM Compression testen.
- Transparente Partikel klein halten und nicht zu viele Overdraw-Layers.
- Portale als flache Planes verwenden, `billboard = enabled` nur falls nötig.
- Glow in Quality Profiles abschaltbar machen.
- MultiMesh für viele Stern-/Orb-Objekte nutzen.

## Lizenz
Alle Dateien wurden hier programmgesteuert erzeugt, keine externen Bitmaps/Logos/Watermarks.
