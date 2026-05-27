# CLAUDE.md - Lumo 3D (Godot 4.x)

Dieses Projekt ist ein **neues, separates** Godot 4.x 3D-Projekt.
Es liegt unter `/home/user/lumo-godot/` und teilt sich KEINE Dateien
mit der Flutter-App `/home/user/lumo-lernen/`.

## Engine & Sprache

- Godot **4.6.3-stable** (lokal unter `/home/user/tools/godot`)
- **GDScript** mit statischer Typisierung (`var x: int`, `func foo() -> bool`)
- Renderer: Forward Plus (3D-orientiert, modernste Pipeline)
- MSAA 4x fuer 3D, weiches Antialiasing
- Standard-Aufloesung 1280x720, stretch=canvas_items

## Projekt-Struktur

```
lumo-godot/
  project.godot       # Engine-Config
  CLAUDE.md           # Diese Datei
  icon.svg            # App-Icon
  scenes/
    main.tscn         # Hauptszene mit Camera3D + Sonne + Wuerfel
  scripts/
    rotator.gd        # Rotation-Logik fuer den Test-Wuerfel
  assets/
    models/           # .glb / .obj fuer 3D-Objekte (Blender-Export)
    textures/         # PBR-Maps (diffuse, normal, roughness)
```

## Code-Stil-Richtlinien

- **Statische Typisierung** ueberall wo moeglich:
  - `var speed: float = 1.5`
  - `func _process(delta: float) -> void:`
  - Klassen-Variablen mit Typ-Annotation
- `class_name` fuer wiederverwendbare Skripte
- `@export` fuer Editor-konfigurierbare Felder
- Konstanten in `SCREAMING_SNAKE_CASE`
- Funktionen + Variablen in `snake_case`
- Szenen-Namen in `PascalCase` (z.B. `MainScene.tscn`)
- `gdlint scripts/datei.gd` vor Commit, `gdformat scripts/datei.gd` zum
  Formatieren (Tool: gdtoolkit 4.5.0 unter `~/.local/bin/`)

## Headless-Modus

Der Container hat keine GUI - der Godot-Editor laesst sich nur ueber
`--headless` betreiben. Bedeutet:
- `godot --headless --quit` -> Projekt parse-checken
- `godot --headless --check-only path.gd` -> einzelnes Script pruefen
- Keine visuelle Vorschau, kein Editor-Viewport im Container

Echte 3D-Wiedergabe (Spielen + Sehen) braucht ein Linux-Desktop oder ein
Windows/Mac-System mit installiertem Godot 4.6.3.

## Aktuelle To-Dos

- [x] Step 1: Projekt-Struktur + Godot 4.6.3 lokal
- [x] Step 2: CLAUDE.md (diese Datei)
- [x] Step 3: 3D-Hauptszene main.tscn (Node3D-Root, Camera3D,
      DirectionalLight3D, WorldEnvironment, MeshInstance3D Box)
- [x] Step 4: scripts/rotator.gd mit _process(delta) Rotation
- [x] Step 5: Headless-Parse-Check (--import + --quit-after 60)
- [x] Step 6: export_presets.cfg fuer Web + Android
- [x] Step 7: Git-Repo init + erster Commit
- [ ] Optional: Blender-Asset-Pipeline (Blender ist nicht installiert -
      muss noch via apt oder Snap nachgezogen werden)
- [ ] Optional: PBR-Texturen via Hugging Face / Poly Haven CC0
- [ ] Heinz oeffnet das Projekt einmal im echten Godot-Editor um die
      Szene live zu sehen + lokale Export-Templates installieren

## Architektur der Hauptszene (`scenes/main.tscn`)

```
Main (Node3D)                          <- Root, Container fuer alles
├── WorldEnvironment                   <- Grundbeleuchtung + Sky + Bloom
│     environment:
│       background_mode = 2 (Sky)
│       sky = ProceduralSkyMaterial
│       tonemap = Filmic
│       glow_enabled = true, intensity 0.6, bloom 0.15
│       ambient_light_source = 3 (vom Sky)
├── Sun (DirectionalLight3D)           <- "Sonne", warmes Licht von oben
│     position (0, 4, 0), Vorw-Neigung
│     color (1, 0.95, 0.85), energy 1.2
│     shadow_enabled = true
├── Camera3D                           <- Default Kamera
│     position (0, 1.5, 4), FOV 60deg
│     leicht nach unten geneigt um Cube anzuschauen
└── TestCube (MeshInstance3D)          <- Sichtbares 3D-Testobjekt
      mesh = BoxMesh 1.5x1.5x1.5
      material = StandardMaterial3D
        albedo orange (1, 0.48, 0.18)
        metallic 0.2, roughness 0.35
        emission orange-warm energy 0.18
      script = rotator.gd
        _process(delta): rotation.y += speed_y*delta
                         rotation.x += speed_x*delta
```

### Kamera-Setup

- Position: `(0, 1.5, 4)` - 1.5 m hoch, 4 m hinter dem Cube
- FOV: 60 Grad (mittelweit, kein Fisheye)
- Leichte Nach-unten-Neigung in der Transform-Matrix damit der Cube
  zentral im Bild sitzt
- Aktuell statisch - spaeter optional Orbit-Kamera (Mouse-Drag) via
  zusaetzliches Skript

### Render-Pipeline

- **Renderer**: Forward Plus (3D-State-of-the-Art in Godot 4)
- **MSAA**: 4x in 3D fuer weiche Kanten
- **Bloom/Glow**: aktiv, Intensitaet 0.6 - Orange-Material des Cubes
  glueht leicht
- **Tonemap**: Filmic (kontrastreicher als Linear)
- **Sky**: ProceduralSkyMaterial mit dunkelblauem Top + warmem Horizont

## CLI-Cheatsheet

Alle Befehle aus `/home/user/lumo-godot/` ausfuehren, Godot-Binary liegt
unter `/home/user/tools/godot`.

### Entwicklung (im Cloud-Container)

```bash
# Projekt-Cache neu aufbauen (nach Asset-Aenderung)
/home/user/tools/godot --headless --import

# Smoke-Test der Szene (60 Frames ~1s, sauber beenden)
/home/user/tools/godot --headless --verbose \
  --quit-after 60 res://scenes/main.tscn

# GDScript-Lint
~/.local/bin/gdlint scripts/*.gd

# GDScript-Format (Schreibt zurueck)
~/.local/bin/gdformat scripts/*.gd

# GDScript-Format Check ohne Aenderung
~/.local/bin/gdformat --check scripts/*.gd
```

### Build & Export (auf Heinz' Desktop, NICHT im Container)

Voraussetzung: Export-Templates fuer Godot 4.6.3 lokal installiert
(einmaliger Download von ~500 MB pro Plattform via Editor > Manage
Export Templates ODER via CLI):

```bash
# Web (HTML5/WebAssembly)
godot --headless --export-release "Web" exports/web/index.html

# Android (arm64-v8a, debug-keystore)
godot --headless --export-release "Android" exports/android/lumo3d.apk
```

### Testen der Builds

```bash
# Web im lokalen Browser
python3 -m http.server -d exports/web 8000
# -> http://localhost:8000

# Android aufs Handy via adb
adb install -r exports/android/lumo3d.apk
adb shell am start -n dev.ullmann.lumo3d/com.godot.game.GodotApp
```

## Git-Workflow

```bash
cd /home/user/lumo-godot
git status                    # Aenderungen sehen
git add scenes/ scripts/      # Spezifisch stagen, NICHT git add -A
git commit -m "feat: ..."     # Klare Conventional-Commit-Nachricht
```

KEIN Auto-Push - Heinz pusht selbst nach GitHub wenn er bereit ist.

## Tools-Status im Container (Stand 2026-05-27)

| Tool      | Status                  | Pfad                                    |
|-----------|-------------------------|-----------------------------------------|
| Godot 4.6 | installiert             | /home/user/tools/godot                  |
| gdlint    | installiert             | ~/.local/bin/gdlint                     |
| gdformat  | installiert             | ~/.local/bin/gdformat                   |
| Blender   | **NICHT installiert**   | (apt install blender oder snap)         |
| Python 3  | installiert (3.11)      | /usr/bin/python3                        |

## Wichtige Regeln

1. KEINE Dateien aus `/home/user/lumo-lernen/` aendern.
2. KEIN Editor-Modus starten (nur Headless funktioniert hier).
3. Vor Commit immer `gdlint` durchlaufen.
4. Wenn die Lumo-Lernen-Flutter-App beruehrt werden muss: separate
   Session, anderes Verzeichnis.
