# MASTERPROMPT FÜR CLAUDE CODE — LUMO 3D CHARACTER SYSTEM

## 0. Sofort lesen

Du arbeitest ausschließlich im Godot-Projekt:

`/home/user/lumo-godot/`

Das Flutter-Projekt `lumo-lernen` darf nicht verändert werden.

Aktueller Stand aus dem letzten Bericht:
- Flutter bleibt auf `e705bcc` unangetastet.
- Godot ist aktuell bei `df55e99`.
- Vorherige relevante Godot-Commits:
  - `6b2798a` = mobile 3D shell / free visual upgrade pass
  - `deecf63` = generated 3D visual asset pack integriert
  - `df55e99` = Android-Export-Diagnose gehärtet
- Android SDK fehlt im Container noch, Keystore-Skript existiert.
- App-Shell hat Boot → Intro → Home.
- Home hat Lumo, Portale, Sternenfeld, AssetLoader, PerformanceManager, Quality Profiles.
- 176 generierte PNG-Assets wurden bereits in die App-Asset-Pipeline integriert.
- Dieses ZIP liefert jetzt LUMO-Referenzbilder + Produktionsauftrag für den echten animierten 3D-LUMO.

## 1. Wichtige Sicherheitsregeln

Vor jeder Änderung ausführen:

```bash
pwd
git status --short
git log --oneline -8
test -f project.godot && echo "Godot project confirmed"
```

Pflicht:
1. Arbeitsordner muss `/home/user/lumo-godot/` sein.
2. Keine Datei außerhalb `/home/user/lumo-godot/` ändern.
3. Flutter-Projekt `lumo-lernen` nicht anfassen.
4. Keine falschen Erfolgsmeldungen.
5. Keine neuen kostenpflichtigen Dienste, keine API-Keys, keine Cloudpflicht.
6. Keine Monsteränderung ohne Validierung.
7. Kein APK-Erfolg behaupten, solange Android SDK fehlt.
8. Bestehende Systeme nicht zerstören:
   - EventBus
   - AssetLoader
   - PerformanceManager
   - Boot/Intro/Home Flow
   - Portal-System
   - vorhandene generated assets
   - Android-Diagnose-Skripte

## 2. Auftrag

Du sollst aus den Bildern im Ordner:

`01_LUMO_REFERENCE_IMAGES/`

einen echten, animierten, mobilen 3D-LUMO-Charakter für Godot aufbauen.

Wichtig:
- Die Bilder sind nicht als 2D-Deko gedacht.
- Sie sind Produktionsreferenzen für Modellierung, Rig, Animation, Gesichtssystem und App-Verhalten.
- Du sollst sie in die App-Pipeline bringen und in Godot sichtbar verwerten.
- Ziel ist ein LUMO, der sich wie ein lebendiger App-Begleiter verhält.

## 3. Referenzbilder und Zweck

Pflicht: zuerst alle Bilder listen und intern auswerten.

```bash
find 01_LUMO_REFERENCE_IMAGES -type f -iname "*.png" | sort
```

Nutze sie so:

1. `01_master_character_sheet.png`
   - Identität
   - Farben
   - Hoodie
   - Stern-Emblem
   - Gesamtcharakter
   - Proportionen

2. `02_orthographic_model_sheet.png`
   - A-Pose / T-Pose
   - Front / Side / Back
   - Tail Volume
   - Hoodie Construction
   - Paw Shape
   - Ear Shape
   - Scale / Silhouette

3. `03_facial_expression_sheet.png`
   - Emotionen:
     - neutral
     - happy
     - excited
     - laughing
     - curious
     - thinking
     - surprised
     - sad
     - determined
     - sleepy
     - proud
     - speaking

4. `04_mouth_viseme_sheet.png`
   - Mouth/Lip-Sync:
     - rest
     - smile
     - A
     - E
     - I
     - O
     - U
     - F/V
     - L
     - M/B/P
     - W/Q
     - surprise open
     - grin
     - closed smile

5. `05_eye_blink_sheet.png`
   - Eye states:
     - open neutral
     - happy squint
     - blink closed
     - half blink
     - wink left
     - wink right
     - surprised wide
     - sleepy half-lid
     - curious raised brow
     - sad brows
     - determined brows

6. `06_gesture_arm_pose_sheet.png`
   - App gestures:
     - wave
     - point left/right
     - thumbs up
     - hands on hips
     - open arms welcome
     - holding a star
     - explaining
     - celebrating
     - listening
     - thinking
     - gentle presenting

7. `07_walk_cycle_keyposes.png`
   - Walk cycle:
     - contact
     - down
     - passing
     - up
     - mirrored phases
     - friendly bouncy timing

8. `08_jump_hop_keyposes.png`
   - Jump/hop:
     - anticipation
     - takeoff
     - airborne
     - apex
     - happy mid-air
     - landing
     - settle
     - playful hop

9. `09_turnaround_rotation_sheet.png`
   - rotation loop
   - silhouette consistency
   - turn-left / turn-right / turntable preview

10. `10_interaction_app_behavior_sheet.png`
   - app role:
     - greeting
     - idle stance
     - idle bounce
     - listening to a child
     - speaking/explaining
     - celebrating success
     - encouraging after mistake
     - reading floating card
     - pointing to portal
     - giving reward star

## 4. Zielarchitektur in Godot

Lege sauber und additiv an:

```text
assets/characters/lumo/reference/
assets/characters/lumo/materials/
assets/characters/lumo/textures/
assets/characters/lumo/generated/
scenes/characters/lumo/
scripts/characters/lumo/
```

Kopiere die Referenzbilder nach:

`assets/characters/lumo/reference/`

aber:
- nicht nur kopieren
- auch in Manifest und Doku registrieren
- in einer Showcase-Szene sichtbar machen

## 5. Ziel-Dateien

Erstelle oder verbessere:

```text
scenes/characters/lumo/lumo_character.tscn
scenes/characters/lumo/lumo_showcase.tscn
scripts/characters/lumo/lumo_character_controller.gd
scripts/characters/lumo/lumo_animation_state.gd
scripts/characters/lumo/lumo_eye_system.gd
scripts/characters/lumo/lumo_mouth_system.gd
scripts/characters/lumo/lumo_behavior_controller.gd
scripts/characters/lumo/lumo_reference_board.gd
assets/characters/lumo/reference/lumo_reference_manifest.json
assets/manifests/assets.json
tools/validate_project.py
CLAUDE.md
```

Wenn vorhandene Dateien existieren:
- nicht blind überschreiben
- integrieren
- alte Kompatibilität erhalten

## 6. Modell-/Charakterstrategie

Da noch kein echtes `lumo_fox.glb` existiert:

Baue eine verbesserte Godot-native LUMO-Charakterbasis.

Mindestanforderung:
- sichtbarer Kopf
- Körper
- Ohren
- Schnauze
- Augen
- Augenbrauen
- Mund
- Arme
- Hände/Pfoten
- Beine
- Füße
- Schwanz
- violetter Hoodie
- gelber Stern
- weiche Farben gemäß Referenz

Das ist eine Zwischenstufe, aber muss deutlich besser sein als ein Primitive-Dummy.

Wichtig:
- so strukturieren, dass später `lumo_fox.glb` ersetzt/eingehängt werden kann
- Root/API darf bleiben
- Visual kann später getauscht werden

## 7. Animationen — Pflicht

Baue ein Animation-/State-System, auch wenn erste Animationen noch vereinfacht sind.

Pflichtanimationen:
- `idle`
- `idle_bounce`
- `blink`
- `greeting_wave`
- `listen`
- `speak_explain`
- `encourage`
- `celebrate`
- `walk_loop`
- `jump_hop`
- `point_portal`
- `reward_star`
- `turn_left`
- `turn_right`

Wenn echtes Bone-Rig nicht realistisch ist:
- nutze AnimationPlayer / Tween / Node-Transforms
- Augen/Mund als separate Mesh-/Texture-/Material-Zustände
- Arme/Kopf/Schwanz über Node-Rotation
- wichtig ist sichtbare App-Illusion + saubere API

## 8. Mouth / Viseme System

Implementiere ein leichtgewichtiges System:

```gdscript
set_mouth_shape(shape: String)
speak_text_preview(text: String)
start_speaking()
stop_speaking()
```

Mundformen:
- rest
- smile
- a
- e
- i
- o
- u
- fv
- l
- mbp
- wq
- surprise_open
- grin
- closed_smile

Wenn nötig:
- Mouth-Mesh skalieren/verformen
- unterschiedliche kleine Meshes sichtbar/unsichtbar schalten
- Materialwechsel
- einfache Open/Close-Jaw-Illusion
- keine schwere LipSync-Bibliothek erzwingen

## 9. Eye / Blink System

Implementiere:

```gdscript
blink()
set_eye_state(state: String)
set_brow_state(state: String)
```

Eye states:
- open_neutral
- happy_squint
- blink_closed
- half_blink
- wink_left
- wink_right
- surprised_wide
- sleepy_half_lid

Brow states:
- neutral
- curious
- sad
- determined
- happy

Blink automatisch:
- alle 3 bis 6 Sekunden zufällig
- in LOW-Profil weniger/leichter, falls nötig
- muss pausierbar sein

## 10. Behavior API

Implementiere eine einfache API:

```gdscript
play_behavior("greet")
play_behavior("listen")
play_behavior("speak")
play_behavior("explain")
play_behavior("encourage")
play_behavior("celebrate")
play_behavior("point_portal")
play_behavior("reward_star")
play_behavior("walk")
play_behavior("jump")
```

Diese API soll später aus Lernfragen, Portalen und Result-Dialogen getriggert werden können.

## 11. Integration in Home

Im Home soll LUMO nicht nur stehen.

Mindestens:
- beim Start: `greet`
- danach: `idle_bounce`
- bei Portal-Fokus/Tap später: `point_portal`
- Test-Hotkeys oder Debug-Buttons in Showcase-Szene, nicht zwingend im Home
- vorhandener Home-Flow darf nicht brechen

## 12. Showcase-Szene

Pflicht:

`scenes/characters/lumo/lumo_showcase.tscn`

Diese Szene soll:
- LUMO zeigen
- eine Reference Board / Bildtafel oder Textliste der geladenen Sheets zeigen
- automatisch einige Animationen nacheinander abspielen
- Logs ausgeben:
  - `lumo_showcase_ready`
  - `behavior:greet`
  - `behavior:speak`
  - `behavior:celebrate`
  - `behavior:walk`
  - `behavior:jump`

Headless muss laden können.

## 13. Performance

- 60 FPS Ziel
- Mobile-first
- keine übertriebenen Mesh-Mengen
- kein dauerhafter Partikel-Overkill
- Augen/Mund-System leichtgewichtig
- Quality Profile respektieren
- Android MEDIUM konservativ
- LOW muss LUMO weiter funktionsfähig halten

## 14. AssetLoader / Manifest

Erweitere `assets/manifests/assets.json`:
- Referenzbilder als `lumo_reference_*`
- ggf. LUMO-Materialien
- ggf. LUMO-Character-Scene-ID

AssetLoader darf dadurch nicht brechen.

## 15. validate_project.py erweitern

Neue Checks:
- `assets/characters/lumo/reference/` existiert
- mindestens 10 LUMO-Referenzbilder existieren
- `lumo_reference_manifest.json` valide
- `scenes/characters/lumo/lumo_character.tscn` existiert
- `scenes/characters/lumo/lumo_showcase.tscn` existiert
- LUMO-Skripte existieren
- Home lädt weiter
- fehlendes echtes `lumo_fox.glb` bleibt WARN, nicht FAIL

## 16. Tests

Am Ende ausführen:

```bash
pwd
git status --short
find assets/characters/lumo/reference -type f -iname "*.png" | wc -l
python3 tools/validate_project.py
gdlint $(find scripts -name "*.gd" -type f)
gdformat --check $(find scripts -name "*.gd" -type f)
godot --headless --import
godot --headless --quit-after 60 res://scenes/app/home_3d.tscn
godot --headless --quit-after 60 res://scenes/characters/lumo/lumo_showcase.tscn
bash tools/build_android.sh
git diff --stat
```

Wenn Godot-Binary anders heißt:
- suchen
- konsistent verwenden

## 17. Commit-Regel

Commit nur, wenn:
- Flutter unangetastet
- Referenzbilder integriert
- LUMO sichtbar verbessert
- Showcase lädt
- Home lädt
- validate_project.py PASS oder PASS mit akzeptierten WARNs
- gdlint/gdformat grün
- Android-Diagnose ehrlich bleibt

Commit Message:

```bash
git add .
git commit -m "feat(godot): build animated lumo character reference system"
```

## 18. Abschlussbericht

Am Ende exakt:

```text
LUMO 3D CHARACTER REFERENCE SYSTEM REPORT

A. Safety
1. Arbeitsordner:
2. Git HEAD vor Arbeit:
3. Git HEAD nach Arbeit:
4. Flutter unangetastet:
5. Dateien außerhalb Godot geändert:

B. Reference ZIP Processing
6. ZIP/Referenzordner gefunden:
7. Referenzbilder kopiert nach:
8. Anzahl Referenzbilder:
9. Manifest erstellt:
10. Welche Referenzbilder wurden wofür verwendet:

C. Character System
11. Neue Szenen:
12. Neue Skripte:
13. Neue Assets/Materialien:
14. Charakterbasis verbessert:
15. Austauschbarkeit gegen lumo_fox.glb:

D. Animation System
16. Idle:
17. Idle Bounce:
18. Blink/Eyes:
19. Mouth/Visemes:
20. Gestures:
21. Walk:
22. Jump:
23. Turn:
24. Behavior API:

E. App Integration
25. Home-Integration:
26. Showcase-Szene:
27. EventBus/AssetLoader/PerformanceManager-Anbindung:
28. Debug-/Testverhalten:

F. Mobile Performance
29. 60-FPS-Strategie:
30. LOW/MEDIUM/HIGH Verhalten:
31. Overdraw-/Mesh-Risiken:
32. Was bleibt für echtes Handy zu prüfen:

G. Validation
33. validate_project.py:
34. gdlint:
35. gdformat:
36. Headless Import:
37. Headless Home:
38. Headless Showcase:
39. Android-Diagnose:
40. git diff --stat:

H. Result
41. Sichtbare Verbesserung:
42. Nicht erledigt und warum:
43. Nächster bester Schritt:
44. Commit durchgeführt:
45. Commit-Hash:
```