# Lumo reference design — 8 October 2026

The starter Comet retains navy/anthracite coachwork, cyan lights, restrained gold edges and an original fox driver. The fox has brown eyes, white cheek/muzzle fur, blue goggles and a navy suit with a cyan L. Short fur is real opaque geometry; the head, eyes, ears, jaw, steering grip and tail retain their animated joints. A lower bucket seat exposes the back badge. The tail emerges outside the right seat edge.

All five actions use separate normal/pressed/disabled transparent PNGs. The first four come from the approved asset pack; DRIFT is an additional matching original control. Captions use Nunito at runtime. The base and thumb of the analog stick remain separate textures, with a 0.4 physical diameter ratio and 128/1024 travel.

Track detail adds bounded service decks, marshals, spectators and planted light columns. Footprints clear nearby parallel lanes and jump gaps. High/low profiles use spatial MultiMesh batches. Previous harbor placement and fleet geometry work is preserved. Claude’s 640855f preview/physics fix is included.

Real capture commands: `godot --rendering-method gl_compatibility --script scripts/tests/kart_reference_capture.gd`, `kart_visual_quality_capture.gd`, `kart_fold_controls_regression.gd`. Captures are runtime evidence, not concept images. Texture illustrations in Flutter menus remain illustrations.

Known limits: the procedural 3D model is a closer interpretation, not a proven pixel-identical reconstruction of the supplied rendered character. No physical Samsung/Fold or 60 FPS claim is made. Android install, upgrade and gameplay results must come from the exact APK CI run.
