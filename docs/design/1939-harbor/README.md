# Sonnenhafen: authored wave pavilions

Existing design source: `docs/design_targets/2026-10-05-tracks/Track_04_aqua_harbor_rush/track_04_hero_2560.png`. Original mesh construction uses this project's maritime arch/wave vocabulary and navy/cyan/ivory palette. No third-party model, music or copied lettering; existing project/reference attribution remains intact.

Editable source: `Sonnenhafen-Wave-Pavilion.blend`. Reproduce with Blender 4.3.2 and `tools/harbor/build_pavilion.py` (exports are derived outputs; running overwrites those outputs). UV0, five PBR material groups, opaque metallic canopy, emissive cyan inlays. No added realtime lights or texture downloads.

LOD0: 2,764 triangles; LOD1: 1,260; LOD2: 412. All three GLBs together 220,936 bytes. Each instance has five mesh surfaces. Distance switching: 55/110/210 metres; low-detail starts with LOD1. Six static pier colliders stay outside the existing racing guardrails. The canopy clears the road by more than five metres.

Actual runtime integration: `scenes/games/props/harbor_wave_pavilion.tscn` -> `kart_harbor_pavilions.gd` -> `kart_world.gd`, at 3.5%, 43% and 85% of Sonnenhafen. No race progression, steering, save or reward logic modified.

Validation: local Godot import and two detail-tier placement/collider/LOD regression passed. GL screenshots, desktop render counters, complete Stage2 and Android performance remain separately evidenced by the current runs. Desktop Mesa counters are not physical Android FPS measurements. Blender source folder is excluded from runtime import with `.gdignore`; only published GLBs enter Godot.
