# Inter-App-Bridge: Godot 3D-Hub → Flutter-Lern-App

Stand: 2026-06-03

## Architektur

```
┌─────────────────────────┐         lumolernen://open          ┌──────────────────────────┐
│  Lumo 3D (Godot)         │   ───── Android Deep-Link ─────▶   │  Lumo Lernen (Flutter)   │
│  Package dev.ullmann.lumo3d │                                 │  Package dev.ullmann.lumo.lumo_lernen │
│  3D-Erlebnis-Einstieg    │                                    │  Lernsystem (Aufgaben)   │
└─────────────────────────┘                                    └──────────────────────────┘
```

- **Godot** = 3D-Hub / Erlebnis-Einstieg.
- **Flutter** = eigentliches Lernsystem (klassengerechte Aufgaben, Lumo Cards, Lesen, …).
- Tap auf das **Lernen**-Portal im Godot-Hub öffnet die Flutter-App.

## Technische Details

### Godot-Seite (dieses Repo)

`scripts/systems/flutter_bridge.gd`:

```gdscript
FlutterBridge.launch_learning_app("learn")
# -> OS.shell_open("lumolernen://open?section=learn")
```

- Nur auf Android aktiv (sonst `false`).
- Gibt `false` zurück wenn kein Intent-Resolver da ist (Flutter nicht installiert).

`scripts/app/home_controller.gd` → `_handle_portal("learn")`:
1. Versucht `FlutterBridge.launch_learning_app("learn")`.
2. Erfolg → Flutter-App öffnet sich, Godot bleibt im Hintergrund.
3. Misserfolg → Hinweis-Label `UILayer/FlutterHint` + Fallback auf die interne
   3D-Lese-Welt (`SceneRouter.goto("learn")`). **Godot funktioniert also auch
   ganz ohne Flutter-App weiter.**

### Flutter-Seite (Repo Ullmann27/lumo-lernen)

Beide CI-Workflows (`release-apk.yml`, `android-debug-apk.yml`) patchen den
generierten `AndroidManifest.xml` additiv + idempotent:

```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW"/>
    <category android:name="android.intent.category.DEFAULT"/>
    <category android:name="android.intent.category.BROWSABLE"/>
    <data android:scheme="lumolernen"/>
</intent-filter>
```

innerhalb der `MainActivity` (vor `</activity>`).

## Intent-Extras / Deep-Link-Parameter

| URI | Bedeutung |
|-----|-----------|
| `lumolernen://open` | App am Home öffnen |
| `lumolernen://open?section=learn` | (optional, künftig) direkt in den Lern-Bereich |

> Hinweis: Section-Routing in der Flutter-App ist optional/künftig. Aktuell
> öffnet jeder Deep-Link die App am Startbildschirm — der Sprung selbst ist das
> Wesentliche.

## Installation für den Gerätetest

Beide APKs auf dasselbe Android-Gerät (arm64) installieren:

1. **Lumo 3D (Godot)** — Release `v0.1.4`:
   `https://github.com/Ullmann27/lumo-godot/releases/download/v0.1.4/lumo3d-debug.apk`

2. **Lumo Lernen (Flutter)** — Release `build-215` (oder neuer):
   `https://github.com/Ullmann27/lumo-lernen/releases` → `Lumo-Lernen-latest.apk`

## Test-Schritte

1. Beide APKs installieren (bei „Play Protect"-Warnung: „Trotzdem installieren").
2. **Lumo 3D** öffnen → Boot → Intro → 3D-Hub.
3. Auf das **Lernen**-Portal tippen.
4. **Erwartet:** Lumo Lernen (Flutter) öffnet sich.
5. Zurück-Taste → wieder im Godot-Hub.

### Fallback-Test (nur Godot installiert)

1. Nur **Lumo 3D** installieren, Flutter NICHT.
2. Lernen-Portal tippen.
3. **Erwartet:** kurzer Hinweis „Lumo Lernen-App nicht gefunden" +
   die interne 3D-Lese-Welt öffnet sich.

## Bekannte Grenzen / nächste Schritte

- App-zu-App-Sprung ist **nur auf echtem Gerät** verifizierbar (kein Headless-Test
  möglich) — daher Gerätetest durch Heinz nötig.
- Section-Routing in Flutter (Deep-Link-Parameter auswerten) noch offen.
- Rücksprung Flutter → Godot (z. B. „3D-Welt"-Button in Flutter) existiert separat
  über das `lib/features/lumo3d/lumo3d_launcher.dart` (Flutter → `dev.ullmann.lumo3d`).
