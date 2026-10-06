# QA Acceptance - Sonnenhafen

## Collision
simple road rail/checkpoint/item proxies only; decorative geometry does not imply collision

## Low-detail parity
track width, route, item positions, checkpoint and safe respawn must match high detail

## Learning separation
no quiz, answer timer, learning cup, or correct-answer boost in race

## Performance
MultiMesh repeated props; separate mobile LOD0/LOD1/background; avoid unnecessary transparent materials and background shadows

Also run tools/validate_track_packs.py, existing Kart regressions and real Godot runtime captures against all 48 view definitions.
