# Lumo 3D — Android Build Anleitung fuer Heinz

Stand: Commit `84e2f41` (gehaerteter Linux-Testbuild + Android-Pipeline)
Engine: Godot 4.6.3.stable

## Was bereits vorbereitet ist (im Repo)

| Komponente | Status |
|---|---|
| Android-Export-Preset in `export_presets.cfg` | ✅ arm64-v8a, min-SDK 24, target-SDK 34 |
| Package: `dev.ullmann.lumo3d`, version 0.1.0 | ✅ |
| 0 unnoetige Permissions | ✅ (keine Internet/Location/Mic/Camera) |
| `tools/build_android.sh` (Auto-Detection + Build) | ✅ |
| `tools/install_android.sh` (adb install -r) | ✅ |
| `tools/logcat_lumo.sh` (gefilterter Logcat) | ✅ |
| `tools/setup_android_keystore.sh` (Debug-Keystore) | ✅ |
| Debug-Keystore (im Container) | ✅ - lokal muss neu erzeugt werden |
| Export-Templates (Godot 4.6.3 stable) | ✅ im Container; lokal aus Editor laden |

## Was lokal noch fehlt (auf deinem Desktop / Laptop)

- Android SDK (nicht im Container praktikabel installierbar)
- `ANDROID_HOME` / PATH-Eintrag
- Komponenten: `platform-tools`, `build-tools;34.0.0`, `platforms;android-34`
- Optional: Android Studio (gibt GUI fuer alles oben)

## Installations-Pfad A — Android Studio (empfohlen fuer Erstinstall)

1. Download: https://developer.android.com/studio
2. Installieren, beim Setup "Standard"-Profil waehlen
3. Studio einmal oeffnen — er installiert SDK + platform-tools + build-tools automatisch
4. Pfad notieren: meistens `~/Android/Sdk`
5. PATH + Env setzen (siehe unten)

## Installations-Pfad B — Nur cmdline-tools (Linux/Mac, kein GUI)

```bash
mkdir -p ~/Android/Sdk/cmdline-tools
cd ~/Android/Sdk/cmdline-tools
# Linux:
curl -L https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -o tools.zip
# macOS:
# curl -L https://dl.google.com/android/repository/commandlinetools-mac-11076708_latest.zip -o tools.zip
unzip tools.zip
mv cmdline-tools latest
rm tools.zip
```

## Umgebungsvariablen (in `~/.bashrc` / `~/.zshrc`)

```bash
export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools"
```

Danach: neue Shell oeffnen oder `source ~/.bashrc`.

## SDK-Komponenten installieren

Du kannst alles manuell machen — oder einfach mein Skript mit
`--auto-setup` rufen, das macht `sdkmanager --licenses + Komponenten`
in einem Schritt:

```bash
cd /pfad/zum/lumo-godot
bash tools/build_android.sh --auto-setup
```

Manuell:

```bash
yes | sdkmanager --licenses
sdkmanager "platform-tools" "build-tools;34.0.0" "platforms;android-34"
```

## Debug-Keystore

Wird automatisch von `build_android.sh` erzeugt wenn fehlend. Manuell:

```bash
bash tools/setup_android_keystore.sh
```

Erzeugt `~/.android/debug.keystore` mit Standard-Parametern (alias=
androiddebugkey, storepass=keypass=android, RSA 3072, 9999 Tage).

## Ein-Befehl-Build

```bash
cd /pfad/zum/lumo-godot
bash tools/build_android.sh
# erzeugt: exports/android/lumo3d-debug.apk (geschaetzt 80-100 MB)
```

Das Skript prueft 14 Voraussetzungen, ruft `godot --headless
--export-debug "Android"`, verifiziert die APK-Groesse + optional die
Signatur via apksigner.

## Auf das Handy aufspielen

```bash
# 1. Handy via USB anschliessen
# 2. Auf dem Handy: Einstellungen > Ueber das Telefon
#    -> 7x auf Build-Nummer tippen (Entwickleroptionen aktivieren)
# 3. Einstellungen > Entwickleroptionen > USB-Debugging AN
# 4. Beim ersten Anschluss: USB-Debug-Dialog auf dem Handy bestaetigen
# 5. Installieren:
bash tools/install_android.sh
```

Falls mehrere Geraete:

```bash
adb devices
# z.B. Output: 1234ABCD  device
ADB_SERIAL=1234ABCD bash tools/install_android.sh
```

## Live-Logs vom Handy

```bash
bash tools/logcat_lumo.sh
# Filtert auf: Godot, Lumo, ERROR, FATAL, ANR, Vulkan, OpenGL,
# Audio, Input, AndroidRuntime
# Speichert parallel nach: exports/android/logcat_lumo_<timestamp>.txt
# Strg+C zum Beenden
```

Vor wichtigem Test: Buffer leeren mit
`bash tools/logcat_lumo.sh --clear`.

## Bekannte Limits

- **Erster Build dauert lange**: Godot muss alle Assets erstmal
  importieren + die Templates packen. 30-90 s normal.
- **Vor Build-Templates-Download**: ~900 MB einmaliger Download wenn
  noch nicht vorhanden.
- **SDK-Lizenzen muessen bestaetigt werden**: einmal `yes | sdkmanager
  --licenses` (macht --auto-setup automatisch).
- **Release-Keystore**: noch nicht erzeugt. Debug-APK reicht fuer
  alle Tests. Erst wenn du in den Play Store willst, brauchst du
  einen Release-Keystore (nicht Teil dieser Mission).
- **AAB statt APK**: Play Store will heutzutage `.aab`. Im Preset auf
  `export_format=1` umstellen + `use_gradle_build=true` setzen. Aktuell
  bewusst APK = einfacher Direkt-Install.

## Was Heinz nach Test zurueckmelden soll

- **Geraet**: Hersteller + Modell
- **Android-Version**: z.B. "Android 14, OneUI 6"
- **FPS-Eindruck**: fluessig / leichtes Ruckeln / unbenutzbar
- **Touch**: reagieren Portale auf Tap?
- **Camera-Drag**: dreht sich die Kamera bei Wisch?
- **Lumo sichtbar**: Hoodie/Stern/Augen erkennbar?
- **Portale lesbar**: Beschriftung Lernen/Spiele/Eltern gross genug?
- **Crash-Logs**: bei Absturz `exports/android/logcat_lumo_*.txt`
  schicken

## Naechste Mission nach Handy-Test

- Optik OK + FPS OK → echtes `lumo_fox.glb` (Blender / Meshy)
- Optik gut, FPS ruckelt → Quality-Profile-Detection feiner
  (LOW als Android-Default)
- Touch schwierig → Hitbox-Vergroesserung / Tap-vs-Drag-Tuning
- Lumo zu klein → Kamera-Radius reduzieren oder Lumo skalieren
