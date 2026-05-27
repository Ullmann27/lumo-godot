# LUMO 3D CHARACTER PRODUCTION PLAN

## Ziel
Aus den Referenzbildern wird ein echter Godot-LUMO gebaut: animiert, interaktiv, mobil performant.

## Produktionsphasen

### Phase 1 — Import & Reference Board
- Referenzbilder nach `assets/characters/lumo/reference/`
- Manifest erzeugen
- Showcase-Szene mit Referenzliste/Board

### Phase 2 — Character Structure
- Lumo Root
- VisualRoot
- Head
- Body
- Hoodie
- Arms
- Legs
- Tail
- Eyes
- Brows
- Mouth
- StarEmblem
- AnimationRoot

### Phase 3 — Animation System
- AnimationPlayer
- BehaviorController
- EyeSystem
- MouthSystem
- State enum/string states

### Phase 4 — App Behaviors
- greet
- idle
- listen
- speak
- explain
- encourage
- celebrate
- point_portal
- reward_star
- walk
- jump

### Phase 5 — Mobile Optimization
- Mesh/Node count prüfen
- Alpha-Overdraw vermeiden
- Quality Profile beachten
- 60-FPS-Ziel dokumentieren

## Wichtig
Das Ziel ist nicht sofort ein perfektes AAA-Rig. Das Ziel ist eine saubere, austauschbare, Godot-native Charakterbasis, die bereits sichtbar lebt und später durch ein echtes GLB ersetzt werden kann.