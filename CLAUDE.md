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
  project.godot                 # Engine-Config + Autoloads + Renderer-Pfade
  CLAUDE.md                     # Diese Datei
  icon.svg                      # App-Icon
  export_presets.cfg            # Web + Android Build-Profiles
  .gitignore                    # .godot/ + exports/ + Import-Cache
  scenes/
    main.tscn                   # Root: Main(+main_controller) + Sun + Camera +
                                #   HoloCube(+rotator + ShaderMaterial) +
                                #   AssetLoader(+asset_loader)
    default_env.tres            # Environment: VolumetricFog + SSAO + Glow
  scripts/
    event_bus.gd                # Autoload: globale Signals (Event-Bus)
    main_controller.gd          # Bindet EventBus-Listener im Main
    rotator.gd                  # Sichtbare Rotation, emittiert speed_changed
    asset_loader.gd             # Scannt assets/models/ + instanziiert .glb
  shaders/
    holographic.gdshader        # Spatial-Shader: Grid + Scanline + Fresnel
  assets/
    models/                     # .glb (statisch oder via tools/fetch_assets.py)
    textures/                   # PBR-Maps (CC0 von Poly Haven, optional)
  tools/
    fetch_assets.py             # KI-Asset-Pipeline (Meshy/Replicate -> .glb)
    assets.json                 # Batch-Config fuer fetch_assets.py
    build_web.sh                # CI/CD: --export-release Web -> exports/web/
    serve_web.py                # Localhost-Server fuer Web-Build + Perf-Log
  exports/                      # (gitignored) lokale Build-Outputs
    web/index.html              # nach build_web.sh
    android/lumo3d.apk          # nach 'godot --export-release Android ...'
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

## High-Performance Rendering-Pipeline

Plattform-spezifische Renderer (`project.godot`):

| Plattform | Renderer | Begruendung |
|---|---|---|
| Desktop / Native | `forward_plus` (Vulkan) | Voller Featureset: SSAO, Volumetric Fog, Glow |
| Mobile (Android) | `mobile` (Vulkan-Lite) | Schlanker fuer Smartphones, gleiche Shader |
| Web (HTML5/WASM) | `gl_compatibility` (GLES3) | Max. Browser-Kompatibilitaet, kein Vulkan-WebGPU-Risiko |

Aktive Post-Processing-Effekte in `scenes/default_env.tres`:

- **Volumetric Fog**: Density 0.045, light albedo Lila-Tinted, length 65m,
  GI-Inject 0.5 (Licht streut realistisch durch Nebel)
- **SSAO** (Screen-Space Ambient Occlusion): Radius 1.4, Intensity 1.6,
  Power 1.8 (sichtbare Schatten in Ecken/Spalten)
- **Glow/Bloom**: Intensity 0.85, Bloom 0.18, HDR-Threshold 1.0
  (Emission > 1 leuchtet, kombiniert mit Tonemap=Filmic)
- **Fog** (Standard depth fog): Density 0.012, aerial perspective 0.35
- **Adjustments**: Saturation 1.15, Contrast 1.08 (knackigere Farben)

## Reaktive Architektur: Event-Bus + Holographic Shader

### Event-Bus (`scripts/event_bus.gd`, Autoload `EventBus`)

Globale Signals fuer lose Knoten-Kopplung:

| Signal | Wer feuert | Wer hoert | Zweck |
|---|---|---|---|
| `scene_loaded(name)` | `main_controller.gd` | beliebig | App-Start-Heartbeat |
| `assets_load_complete(count)` | `asset_loader.gd` | `main_controller.gd` | Count der dyn. geladenen .glb |
| `asset_instanced(path, node)` | `asset_loader.gd` | beliebig | Pro-Item-Event waehrend Load |
| `rotation_speed_changed(y, x)` | `rotator.gd` | `main_controller.gd` | Demo-Reaktivitaet |
| `cube_interacted(intensity)` | TBD (UI/Tap) | TBD (Shader-Param-Animator) | spaeter |

### Holographic Shader (`shaders/holographic.gdshader`)

Cyberpunk-Effekt auf dem HoloCube. Parameter im Inspector + via
ShaderMaterial-Uniforms:

- `base_color` (Cyan #4DD9FF) - Grundfarbe der Grid-Linien
- `edge_color` (Orange #FF8C33) - Fresnel-Ringraender
- `grid_density` (1-64) - Anzahl Linien pro UV-Achse
- `scan_speed` - Geschwindigkeit der wandernden Scanline
- `fresnel_power` - Schaerfe des Edge-Glows
- `pulse_speed` - Atem-Tempo
- `emission_strength` - Master-Multiplier (>1 triggert Bloom)

Render-Mode: `unshaded, blend_add` - addiert auf Hintergrund (kein
Albedo), reagiert daher direkt mit dem Volumetric Fog dahinter.

## KI-Asset-Pipeline (`tools/fetch_assets.py`)

Holt prozedurale 3D-Modelle aus externen AI-APIs:

```bash
# Eine einzelne Anfrage
python3 tools/fetch_assets.py --prompt "low-poly sci-fi crate" --provider meshy

# Batch-Modus aus JSON
python3 tools/fetch_assets.py --config tools/assets.json
```

Provider:

| Provider | API-Key (env) | Output |
|---|---|---|
| `meshy` | `MESHY_API_KEY` | .glb in `assets/models/` |
| `replicate` | `REPLICATE_API_TOKEN` (+ `REPLICATE_MODEL_VERSION`) | .glb |
| `dryrun` | - | Placeholder-GLB (gueltiges leeres glTF) |

Ohne Key faellt der Provider automatisch auf `dryrun` zurueck - das
Skript laeuft IMMER durch, die Godot-AssetLoader-Pipeline kann nie
ueber Null-Bytes stolpern.

Der **Godot-AssetLoader** (`scripts/asset_loader.gd`) scannt
`res://assets/models/` beim App-Start, instanziiert jede `.glb` via
`GLTFDocument.append_from_file()`, verteilt sie entlang der X-Achse und
emittiert `asset_instanced` + `assets_load_complete` ueber den EventBus.

## CI/CD-Build-Pipeline

### Web (HTML5/WebAssembly)

```bash
# Komplett-Build (laedt Templates automatisch wenn fehlen, ~900 MB)
tools/build_web.sh

# Oder explizit Debug-Build (mit Profiler)
tools/build_web.sh --debug
```

Output: `exports/web/{index.html, index.wasm, index.pck, index.js, ...}`

**Bekanntes Problem (Container-Headless):** `godot --headless
--export-release "Web"` liefert aktuell `Cannot export project ... due
to configuration errors` OHNE detaillierte Meldung. Das `--export-pack`
funktioniert sauber (PCK wird generiert), nur der HTML-Wrapper-Schritt
scheitert an der Validierung. Workaround: einmal lokal im Editor
"Project > Export > Web > Export Project" laufen lassen - Godot
synchronisiert dabei die Preset-Defaults und fixt das stillschweigend.
Danach laeuft der Headless-Build im Container.

```bash
# Sanity-Test ohne HTML-Wrapper (immer erfolgreich)
godot --headless --export-pack "Web" exports/web/lumo3d.pck
```

### Localhost-Server fuer Tests

```bash
# Default: 127.0.0.1:8000
python3 tools/serve_web.py

# Auf allen Interfaces
python3 tools/serve_web.py --bind 0.0.0.0 --port 8000
```

Setzt `Cross-Origin-Opener-Policy: same-origin` +
`Cross-Origin-Embedder-Policy: require-corp` (sonst kein SharedArrayBuffer
- Godot 4 Web-Builds brauchen das fuer Threads). Logs in
`/tmp/lumo_serve.log` fuer Performance-Profiling der Anfragen.

### Android

```bash
godot --headless --export-release "Android" exports/android/lumo3d.apk
```

Templates muessen lokal installiert sein (Editor > Manage Export
Templates). Im Container ist Android-Build nicht praktikabel (Android
SDK + JDK + Build-Tools brauchen ~3 GB).

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
