# CLAUDE.md - Lumo 3D Mobile App Shell (Godot 4.6.3)

> **Tech-Leitlinie**: Nutze moderne Mobile-3D-Techniken: Godot Mobile
> Renderer, Quality Profiles, GLB/glTF Asset Pipeline, KTX2/BasisU
> Texturkompression, PBR Materials, Mobile Shader Fallbacks, Touch
> Raycasting, Safe-Area UI, GPU Instancing/MultiMesh, LOD/Culling,
> baked lighting, Headless CI und Android Export Diagnostics. Ziel ist
> keine Tech-Demo, sondern eine performante 3D-Lernwelt auf Android.

Dieses Projekt ist eine **separate** Godot 4.x 3D-App.
Es liegt unter `/home/user/lumo-godot/` und teilt KEINE Dateien mit
der Flutter-App `/home/user/lumo-lernen/` (HEAD bleibt unangetastet).

## App-Flow

```
Boot (boot.tscn)
  ↓ 0.5 s, ColorRect + Label "Lumo"
Intro 3D (intro_3d.tscn)
  ↓ 4.5 s ODER Tap/Klick = skip
  ↓ leuchtender Stern + Kamera-Dolly
Home 3D (home_3d.tscn)
  ↓ Lumo + 3 Portale + MultiMesh-Sternenfeld
  ↓ Touch-Orbit-Kamera (Drag yaw/pitch, Tap = Portal-Pick)
Portal-Tap
  ↓ EventBus.portal_selected(type)
  ↓ Demo-Log: "portal_<type>_selected"
```

## Autoloads (project.godot)

| Name | Pfad | Zweck |
|---|---|---|
| `EventBus` | `scripts/systems/event_bus.gd` | globale Signals (10 Stueck) |
| `PerformanceManager` | `scripts/systems/performance_manager.gd` | LOW/MEDIUM/HIGH Profile |
| `MobileRuntime` | `scripts/app/mobile_runtime.gd` | Safe-Area + Engine-Defaults |
| `SceneRouter` | `scripts/app/scene_router.gd` | `goto("boot"|"intro"|"home"|"loading")` |
| `AssetLoader` | `scripts/systems/asset_loader.gd` | ID-basiertes Manifest-Loading + Placeholder |

Reihenfolge in project.godot ist wichtig: EventBus zuerst (alle anderen
abhaengig), AssetLoader zuletzt (haengt vom Manifest ab das stehen muss).

## Engine & Sprache

- Godot **4.6.3-stable** (lokal unter `/home/user/tools/godot`)
- **GDScript** mit statischer Typisierung
- Renderer pro Plattform:
  - **Forward+** auf Desktop/Native (voller Featureset)
  - **Mobile** auf Android (Vulkan-Lite, schlanker)
  - **gl_compatibility** auf Web (GLES3, max. Browser-Kompatibilitaet)
- Orientation: **Portrait** (handheld)
- Default-Viewport: 720x1280 (Hochformat)

## High-Performance Rendering-Pipeline

Aktiv in `scenes/default_env.tres` (wird ueber
`rendering/environment/defaults/default_environment` projektweit
aktiviert; pro Szene kann ein eigenes WorldEnvironment ueberschrieben
werden):

- **Volumetric Fog**: density 0.025, warm-cremig (95/78/55), length 50m
- **SSAO**: radius 1.2, intensity 1.2, power 1.6
- **Glow/Bloom**: intensity 0.75, bloom 0.20, hdr_threshold 1.0
- **Fog** (Standard depth fog): density 0.010, warm aerial perspective
- **Filmic Tonemapping**, exposure 1.0, white 6.0
- **Adjustments**: saturation 1.10, contrast 1.05 (warmer Look)
- **Sky**: ProceduralSky orange→violett Sonnenuntergangsgradient

## Performance Quality Profiles (PerformanceManager)

| Profil | Glow | Fog | Vol-Fog | SSAO | MSAA | TAA | Default-Plattform |
|---|---|---|---|---|---|---|---|
| **LOW** | aus | aus | aus | aus | 0 | aus | (manueller Override) |
| **MEDIUM** | an | an | aus | aus | 2x | aus | Android, iOS, Web |
| **HIGH** | an | an | an | an | 4x | an | Linux, macOS, Windows |

`PerformanceManager.set_profile(Profile.LOW)` setzt sofort alle
Environment + Viewport-Flags um. Per Plattform wird beim Start
automatisch das passende Profil gewaehlt.

**Wichtig**: Volumetric Fog, SSAO, TAA, FSR2 sind **Forward+-only**.
Beim Mobile-Renderer werden sie automatisch ignoriert - kein
Code-Schaden, der LOW-Branch ist nur explizit zur Sicherheit.

## Reaktive Architektur (EventBus)

10 globale Signals lose Knoten-Kopplung:

```gdscript
EventBus.boot_started
EventBus.scene_loaded(scene_name)
EventBus.scene_changed(from_id, to_id)
EventBus.asset_loader_ready(model_count)
EventBus.assets_load_complete(count)
EventBus.asset_instanced(path, node)
EventBus.quality_profile_changed(profile_name)
EventBus.platform_detected(platform_name)
EventBus.portal_selected(portal_type)        # "learn" | "games" | "parent"
EventBus.portal_hovered(portal_type, hovered)
EventBus.companion_ready
EventBus.companion_reaction(reaction)
```

## Mobile Bedienung (Touch + Safe-Area)

### Touch-Orbit-Kamera (`scripts/camera/mobile_touch_camera.gd`)

- **Drag horizontal** = yaw (Kamera-Drehung um Insel)
- **Drag vertikal** = pitch (clamped -0.45..-0.05 rad, kein Ueberschlag)
- **Mouse-Wheel** = Radius (clamped 4.0..9.0)
- **Tap-vs-Drag**: <8 px Distanz + <250 ms Dauer = Tap (Event durchlassen)
- Mouse-Fallback fuer Desktop (linke Maustaste = ScreenDrag)
- Sanfte Interpolation via `lerp(position, desired, follow_lerp_speed*delta)`

### Safe-Area (`scripts/ui/mobile_safe_area.gd` + MobileRuntime)

- `MobileRuntime.get_safe_area_insets() -> Rect2`
- Fallback bei fehlenden Werten: Top 32 px, Bottom 48 px, Side 16 px
- `MobileSafeArea.apply_safe_margins(control)` setzt offsets

### Portal-Picking (3D-Raycast)

- Jedes `HubPortal` hat eine `Area3D` mit SphereShape3D r=1.4
  (groesser als das visuelle Torus-Mesh!) - grosse Touch-Targets
- `input_ray_pickable=true` aktiviert Touch-Raycast vom Viewport
- Bei Tap: kurzer Scale-Pulse 1.0 → 1.18 → 1.0 + EventBus-Emit

## ID-basiertes Asset-Manifest

`assets/manifests/assets.json` definiert IDs:

```json
{
  "models": {
    "lumo_fox": "res://assets/models/lumo_fox.glb",
    ...
  },
  "materials": { ... },
  "_fetch_prompts": { ... }  // optional fuer fetch_assets.py
}
```

**AssetLoader-API** (Autoload):

```gdscript
var fox: Node3D = AssetLoader.get_model("lumo_fox")  # NIE null
AssetLoader.has_model("lumo_fox")                      # bool
var mat: Material = AssetLoader.get_material("holographic_soft")
```

Wenn ein Asset fehlt: **Magenta-Box-Placeholder** mit Label "missing: id"
wird zurueckgegeben. Niemals null, niemals Crash.

## Lumo Companion (Platzhalter aus Primitiven)

`scenes/characters/lumo_companion.tscn` baut Lumo aus Capsule + Sphere +
Box-Ohren ohne externes Asset. Idle-Bob (Sinus 6 cm Amplitude) plus
Look-At-Camera wenn `look_target_path` gesetzt ist.

Spaeter ersetzbar durch echtes `assets/models/lumo_fox.glb` via
`AssetLoader.get_model("lumo_fox")` als Kind statt der Primitiven.

## MultiMesh Sternenfeld (`scripts/hub/star_field.gd`)

Ein **MultiMeshInstance3D** mit 80 Sterne-Instanzen auf einer Kugelschale
um die Home-Insel. **Ein Draw-Call fuer alle 80**. Pro Frame werden nur
10 Sterne animiert (Subset-Bobbing) - 8x billiger als 80 einzeln zu
updaten. SphereMesh radius 0.5 + emissive StandardMaterial3D
(`shading_mode = SHADING_MODE_UNSHADED`, `vertex_color_use_as_albedo`).

Pattern fuer spaetere Sterne im Mini-Game / Konfetti: gleiche Datei
kopieren, `star_count` hochsetzen, `PALETTE` anpassen.

## Mobile Shader Fallbacks

Der vorhandene `assets/shaders/holographic.gdshader` ist
`unshaded + blend_add` - **gl_compat-kompatibel** und lauft auf allen
drei Renderern. Bei neuen Shadern auf folgende Regeln achten:

- `render_mode unshaded` macht den Shader Renderer-agnostisch
- Keine `hint_screen_texture` (Forward+ only)
- Keine `hint_depth_texture` ohne Fallback (gl_compat hat sie eingeschraenkt)
- PerformanceManager kann via ShaderMaterial-Uniform `emission_strength`
  drosseln statt den Shader auszuschalten

## CC0-Asset-Quellen (optional, fuer spaetere Iterationen)

In dieser Mission wurden KEINE externen Assets heruntergeladen. Bei
Bedarf sind diese CC0-Quellen Heinz' freie Wahl:

| Quelle | URL | Format | Lizenz |
|---|---|---|---|
| Poly Haven | https://polyhaven.com | .hdr, .exr, PBR-Texturen, kleine .glb | CC0 |
| ambientCG | https://ambientcg.com | PBR-Materialien, HDRIs, Decals | CC0 |
| Kenney | https://kenney.nl | Game-Asset-Kits, UI, Audio | CC0 |

**Regel**: bei tatsaechlicher Nutzung URL + Lizenz pro Datei in einem
`assets/CREDITS.md` vermerken (auch wenn CC0 keine Attribution fordert -
Doku fuer Heinz, was woher kommt).

## Texturkompression-Empfehlung (KTX2 / Basis Universal)

Godot 4.6 unterstuetzt **KTX2** mit Basis Universal nativ. Workflow
fuer spaeter:

```bash
# CLI-Tool toktx aus KTX-Software (apt: ktx) konvertiert PNG/JPG -> KTX2
toktx --bcmp --genmipmap out.ktx2 in.png

# ODER via gltfpack (Teil von meshoptimizer):
gltfpack -i model.gltf -o model.glb -tc
```

Vorteile auf Mobile: ~4-8x kleinere VRAM-Belegung, GPU-Direct-Decode,
keine CPU-Decompression-Pause beim Laden. Empfehlung:

- 3D-Texturen: 1024 px max, KTX2-komprimiert
- Pixel-Art: NICHT komprimieren (Artefakte sichtbar)
- HDRIs: bleiben .hdr / .exr (Mobile profitiert von 1024 px Resize)

## LOD / Culling / Baked Lighting (Empfehlung fuer spaeter)

- **Frustum-Culling**: Godot-Default, automatisch aktiv
- **Manuelles LOD**: `MeshInstance3D.lod_bias` oder
  `visibility_range_begin/end` per Mesh
- **Occlusion Culling**: `OccluderInstance3D` mit Box-Occludern in
  Mini-Games mit mehreren Raeumen (Home-Insel braucht das noch nicht)
- **LightmapGI**: fuer statische Home-Insel-Geometrie - drastisch
  billiger als Realtime-Shadows auf Handy. Pipeline: alle statischen
  Meshes -> `use_in_baked_light = true` -> LightmapGI-Knoten -> Bake

## CI / Validation

```bash
# Vor jedem Commit
~/.local/bin/gdlint $(find scripts -name '*.gd' -type f)
~/.local/bin/gdformat --check $(find scripts -name '*.gd' -type f)
python3 tools/validate_project.py

# Engine-Smoke
/home/user/tools/godot --headless --import
/home/user/tools/godot --headless --quit-after 60 res://scenes/app/boot.tscn
/home/user/tools/godot --headless --quit-after 60 res://scenes/app/home_3d.tscn
```

`validate_project.py` prueft:
- Pflicht-Verzeichnisse (scenes/app, scripts/systems, assets/manifests, ...)
- Pflicht-Szenen + Pflicht-Skripte
- Autoloads in project.godot
- Manifest valides JSON + Per-Asset-WARN bei fehlender Datei
- Keine Flutter-Dateien im Repo
- Tools ausfuehrbar
- CLAUDE.md hat Schluesselwoerter "mobile", "boot", "home", "performance"

Exit 0 bei PASS oder WARN; Exit 1 nur bei FAIL.

## Build & Export

### Android (Diagnose-getrieben)

```bash
tools/build_android.sh
```

Prueft Godot-Binary, Export-Templates, Preset, JDK, Android SDK,
Debug-Keystore. Bei jeder Luecke gibt es einen konkreten Next-Step
(z.B. `apt install openjdk-17-jdk-headless`, `keytool ... debug.keystore`).
Nur wenn alle PASS: echter APK-Export. Sonst Exit 1 + Bericht.

Aktueller Container-Stand (2026-05-27): 4 PASS / 2 WARN (Android SDK +
Keystore fehlen). APK-Build erst nach lokaler Heinz-Einrichtung
moeglich.

### Web

```bash
tools/build_web.sh        # Komplett-Pipeline (laedt Templates wenn fehlen)
```

**Bekanntes Problem**: `--export-release "Web"` liefert
`Cannot export project ... due to configuration errors` ohne Detail.
`--export-pack` funktioniert (PCK wird generiert). Workaround:

```bash
# Pack-only - funktioniert immer
godot --headless --export-pack "Web" exports/web/lumo3d.pck

# HTML-Wrapper: einmal lokal im Desktop-Editor "Project > Export >
# Web > Export Project" laufen lassen, danach im Headless ok
```

### Localhost-Server

```bash
python3 tools/serve_web.py            # http://127.0.0.1:8000
```

Setzt `Cross-Origin-Opener-Policy: same-origin` +
`Cross-Origin-Embedder-Policy: require-corp` (Pflicht fuer Godot Web
mit SharedArrayBuffer + Threads). Loggt jede Anfrage nach
`/tmp/lumo_serve.log`.

## Verzeichnisstruktur

```
lumo-godot/
  project.godot                    # Engine + Autoloads + Renderer-Pfade
  CLAUDE.md                        # Diese Datei
  icon.svg                         # App-Icon
  export_presets.cfg               # Web + Android Profiles
  .gitignore                       # .godot/ + exports/ + assets/models/*.glb
  scenes/
    app/
      boot.tscn, intro_3d.tscn, home_3d.tscn, loading_screen.tscn
    hub/
      hub_portal.tscn, star_field.tscn
    characters/
      lumo_companion.tscn
    games/
      .gitkeep                     # spaeter Mini-Games
    default_env.tres
  scripts/
    app/
      app_boot.gd, scene_router.gd, mobile_runtime.gd,
      intro_controller.gd, home_controller.gd
    camera/
      mobile_touch_camera.gd
    characters/
      lumo_companion.gd
    hub/
      portal_interaction.gd, star_field.gd
    systems/
      event_bus.gd, performance_manager.gd, asset_loader.gd
    ui/
      mobile_safe_area.gd
  assets/
    manifests/assets.json
    materials/holographic_soft.tres
    shaders/holographic.gdshader
    models/             # .glb (gitignored - via AI oder manuell)
    textures/           # PBR-Maps (gitignored)
    audio/              # Sounds (spaeter)
    generated/          # AI-output
  tools/
    validate_project.py
    build_android.sh
    build_web.sh
    serve_web.py
    fetch_assets.py
  exports/              # (gitignored) lokale Build-Outputs
```

## Wichtige Schutzregeln

1. **KEINE Dateien aus `/home/user/lumo-lernen/` aendern.**
2. **KEIN Editor-GUI starten** im Container (nur Headless funktioniert).
3. **Vor Commit immer `gdlint` + `gdformat --check` + `validate_project.py`** durchlaufen.
4. **CC0-Lizenz**: jede externe Datei mit URL + Lizenz dokumentieren.
5. **Keine grossen Binaerdateien committen** (Texturen >1 MB lieber
   regenerieren als versionieren).
6. **Keine bezahlten APIs** ohne explizite Heinz-Anweisung.

## Generated Asset Pack (lumo3d_assets)

**Stand**: 176 PNG-Originale + JSON-Manifest integriert in
`assets/generated/lumo3d_assets/`. Lizenzlage: programmgenerierte
Originale ohne fremde Bitmaps/Logos/Watermarks - kein
Lizenzrisiko, kein Attribution-Zwang.

```
assets/generated/lumo3d_assets/
  asset_manifest.json    Pack-Manifest (pack_name, counts, assets)
  README.md
  docs/GODOT_IMPORT_NOTES.md
  textures/albedo/       12 PNG (grass_magic, stone_warm, wood_warm_soft, ...)
  textures/normal/       12 PNG (passend zu albedo, fuer PBR-Materialien)
  textures/emission/     23 PNG (portal_*/hologrid_*/crystal_*)
  particles/             32 PNG (gold/cyan/violet/green *_particle_01..08)
  billboards/            28 PNG (crystal/star/orb/book/number)
  portals/               20 PNG (portal_learn_*/games_*/parent_*/magic_*)
  sky_gradients/         12 PNG (sunrise_magic, twilight_violet, dream_blue, ...)
  ui_panels/             16 PNG (panel_gold/cyan/wood/sky)
  masks/                 20 PNG (radial/dissolve/pulse-Masken)
```

### Generierte Materialien (`assets/materials/generated/`)

12 `.tres` StandardMaterial3D mit albedo/normal/emission je nach Quelle:

| Material | Verwendung | Texturen |
|---|---|---|
| `mat_stone_warm` | Home-Insel-Boden | stone_warm albedo + normal |
| `mat_grass_magic` | alternativ Insel | grass_magic albedo + normal |
| `mat_wood_warm` | spaeter Brett/Tisch | wood_warm_soft albedo + normal |
| `mat_hologrid_cyan` | Hologramm-Plates | hologrid_cyan albedo + normal + emission |
| `mat_crystal_floor` | Glanz-Boden | crystal_floor albedo + normal + emission |
| `mat_portal_learn` | Portal "Lernen" Plane | portal_learn_01 + emission, unshaded + add-blend |
| `mat_portal_games` | Portal "Spiele" Plane | portal_games_01 + emission, unshaded + add-blend |
| `mat_portal_parent` | Portal "Eltern" Plane | portal_parent_01 + emission, unshaded + add-blend |
| `mat_sky_backdrop` | Home-Backdrop-Plane | sunrise_magic Sky-Gradient, unshaded |
| `mat_billboard_crystal` | Deko-Billboards | crystal_billboard_01, unshaded + alpha |
| `mat_billboard_book` | Deko-Billboards | book_billboard_04, unshaded + alpha |
| `mat_particle_gold` | spaeter GPUParticles3D | gold_particle_01, unshaded + alpha |

Portal-Materialien sind **double-sided** (`cull_mode = CULL_DISABLED`)
und **additiv geblendet** (`blend_mode = BLEND_MODE_ADD`) damit die
Magie bei jeder Kamerarichtung leuchtet.

### Home-Szene nutzt das Asset-Pack

- **Insel**: PlaneMesh 14x14 mit `mat_stone_warm` (PBR mit Normal-Map)
- **Backdrop**: QuadMesh 60x30 hinter der Szene mit `mat_sky_backdrop` (unshaded Sky-Gradient)
- **Portale**: jedes hat eine QuadMesh `PortalPlane` mit `mat_portal_<type>`, dazu der bisherige Torus-Ring fuer 3D-Tiefe und das Label3D
- **Decorations**: 0-6 Billboard-Quads (Crystal/Book) auf der Insel-Peripherie, Material aus AssetLoader; Anzahl per Profil

### AssetLoader-API (erweitert)

```gdscript
AssetLoader.get_model("lumo_fox") -> Node3D       # nie null (Magenta-Box)
AssetLoader.get_texture("lumo_par_gold_particle_01") -> Texture2D  # nie null (Magenta-Schachbrett)
AssetLoader.get_material("mat_portal_learn") -> Material  # null wenn ID unbekannt
AssetLoader.has_asset(id) -> bool                  # ueber ALLE Kategorien
```

Logs:
- `asset_material_loaded:<id>` bei Erfolg
- `asset_texture_loaded:<id>` bei Erfolg
- `asset_texture_missing_using_placeholder:<id>` bei Fallback
- WARN bei jedem fehlenden Asset

## Performance Profile vs Asset-Nutzung

| Profil | Sterne (MultiMesh) | Billboards | Portal-Emission | Glow/SSAO |
|---|---|---|---|---|
| LOW | 12 | 0 | x 0.5 | aus |
| MEDIUM | 40 | 3 | x 1.0 | Glow+Fog |
| HIGH | 80 | 6 | x 1.4 | alles + Vol-Fog |

`PerformanceManager.get_star_count()`,
`get_billboard_count()`, `get_portal_emission_multiplier()` werden vom
HomeController und PortalInteraction beim Spawn bzw. `_apply_type()`
abgefragt. Profil-Wechsel zur Laufzeit spawnt nicht neu — gilt erst beim
naechsten Home-Mount.

## Texture-Compression Empfehlung (KTX2 / Basis Universal)

Aktueller Container-Build hat Texturen unkomprimiert (PNG je 10-25 KB,
gesamt ~6.7 MB). Fuer Android-Release vor APK-Build:

1. Im Editor: alle PNGs in `assets/generated/lumo3d_assets/` markieren
   → Import-Tab → `compress/mode` = `VRAM Compressed` (S3TC/BPTC) ODER
   `Basis Universal` (kleinste APK)
2. Oder per CLI: `gltfpack -tc` / `toktx --bcmp --genmipmap`
3. Alpha-Texturen (particles/billboards/portals): sparsam einsetzen,
   Overdraw begrenzen, Plane-Groesse moderat halten

## Aktuelle To-Dos

- [x] Mobile App Shell mit Boot → Intro → Home → Portale
- [x] 5 Autoloads (EventBus, PerformanceManager, MobileRuntime, SceneRouter, AssetLoader)
- [x] PerformanceManager mit LOW/MEDIUM/HIGH Profilen + Star/Billboard/Emission-Helpern
- [x] Touch-Orbit-Kamera mit Tap-vs-Drag-Trennung
- [x] Portal-System mit Area3D-Raycast
- [x] Lumo-Companion-Platzhalter aus Primitiven
- [x] MultiMesh-Sternenfeld (Anzahl per Profil, 1 Draw-Call)
- [x] ID-basiertes Asset-Manifest mit Magenta-Placeholder
- [x] Holographic-Shader auf gl_compat-kompatibel
- [x] validate_project.py + build_android.sh
- [x] Headless-CI sauber gruen
- [x] **Asset-Pack `lumo3d_assets` integriert** (176 PNG, 12 Materialien, AssetLoader-API erweitert)
- [x] Home-Szene nutzt Insel-Material + Sky-Backdrop + Portal-Texturen + Billboards
- [ ] **Naechster Schritt** (Heinz entscheidet):
  - Android-SDK + Keystore einrichten → echte APK
  - Echtes `lumo_fox.glb` (Blender oder Meshy mit API-Key)
  - Premium Visual Tuning (PostFX, LightmapGI-Bake der Insel)
  - Erstes Mini-Game `star_collect_game` als Portal-Ziel
- [ ] KTX2/Basis-Universal-Konvertierung der Pack-Texturen vor APK-Release
- [ ] LightmapGI-Bake der statischen Home-Insel

## Tools-Status im Container (Stand 2026-05-27)

| Tool | Status | Pfad |
|---|---|---|
| Godot 4.6.3 | installiert | /home/user/tools/godot |
| Export-Templates 4.6.3.stable | installiert | ~/.local/share/godot/export_templates/4.6.3.stable/ |
| gdlint / gdformat | installiert | ~/.local/bin/ |
| JDK 21 | installiert | /usr/bin/java |
| Android SDK | **NICHT installiert** | (apt + setup) |
| Debug-Keystore | **NICHT vorhanden** | (keytool generieren) |
| Blender | **NICHT installiert** | (optional, apt install -y blender) |
| Python 3.11 | installiert | /usr/bin/python3 |
