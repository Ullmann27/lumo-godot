# Renderqualität: HIGH respektiert die Laufzeitfähigkeiten

## Basis und Umfang

Prüfbasis: `65c7dfa10cf4cc9b17191697323d95284f68ac5b`, auf dem wiederhergestellten Grafikstand `a81ddf12d594cc252caef7503162e89c6b26e1c7` mit bereits übernommener Fahrer-Taktkorrektur. Godot 4.6.3, Linux-Host, headless. Produktionsänderung ausschließlich in `scripts/systems/performance_manager.gd`.

## Reproduzierbarer Fehler

Die HIGH-Stufe setzte SSAO und volumetrischen Nebel bisher bedingungslos auf `true`. Damit überschreibt sie beim Qualitätswechsel und bei der erneuten Anwendung nach einem Szenenwechsel die bestehende Renderer-/Plattformpolitik von `KartEnvironmentPolish`: erweiterte Effekte sind dort nur für Forward+ außerhalb der mobilen Plattform freigegeben.

Die neue Regression erstellt eine mit `KartEnvironmentPolish` konfigurierte Umgebung, setzt HIGH, wechselt LOW → HIGH und prüft anschließend einen echten SceneTree-Szenenwechsel mit weiterhin gewähltem HIGH. Der gespeicherte Projekt-Renderer wird im Test absichtlich auf Forward+ gesetzt, damit der Test die tatsächliche Laufzeitentscheidung absichert.

RED vor der Korrektur, Compatibility-Laufzeit:

```text
[KartQualityRenderer] high renderer=gl_compatibility ssao=true volumetric_fog=true expected=false
SCRIPT ERROR: Assertion failed: HIGH must preserve the renderer/platform SSAO capability gate
[KartQualityRenderer] low-to-high renderer=gl_compatibility ssao=true volumetric_fog=true expected=false
SCRIPT ERROR: Assertion failed: HIGH must preserve the renderer/platform SSAO capability gate
```

Der strikte Probe-Runner meldete Exit 1. Ein GDScript-assert in einer Helperfunktion kann lediglich diese Funktion beenden; deshalb gilt ein gedruckter PASS-Marker allein nicht als Erfolg. `tools/run_godot_probe.py` prüft zusätzlich den Prozessstatus und Script-/Parse-/Assertion-Fehler.

## Minimale Korrektur

HIGH ermittelt die Freigabe mit `RenderingServer.get_current_rendering_method() == "forward_plus" and not OS.has_feature("mobile")` und verwendet sie für beide Effektschalter. Damit entspricht die Anwendung durch PerformanceManager der bereits vorhandenen KartEnvironmentPolish-Politik. Desktop-Forward+ behält beide Effekte bei HIGH.

Die Aussage betrifft die Konsistenz der Projektpolitik. Godot 4.6.3 nennt SSAO in seiner Startup-Warnung als für Forward+ oder Compatibility verfügbar; SSAO wird daher hier nicht pauschal als technisch unmöglich unter Compatibility bezeichnet. Volumetrischer Nebel ist Forward+ vorbehalten.

## Gezielte Ergebnisse

Alle GREEN-Läufe wurden einzeln mit getrennten XDG-Verzeichnissen, CPU-Affinität `6,7` und dem strikten Probe-Runner ausgeführt. Alle sechs beendeten sich mit Exit 0 und dem geforderten PASS-Marker.

| Belegdatei | Prüfung | Ergebnis |
| --- | --- | --- |
| `red_gl_compatibility.log` | Neue Regression vor Korrektur | Erwartetes RED, Probe-Runner Exit 1 |
| `green_gl_compatibility.log` | HIGH, LOW → HIGH, Szenenwechsel unter Compatibility | PASS; SSAO und volumetrischer Nebel jeweils false |
| `green_mobile.log` | Dieselben drei Stufen unter Mobile-Renderer | PASS; beide Effekte jeweils false |
| `green_forward_plus.log` | Dieselben drei Stufen unter Forward+ | PASS; beide Effekte jeweils true |
| `existing_renderer_profiles.log` | `kart_renderer_profile_regression.gd` | PASS; 12 Fähigkeitskombinationen, tatsächlicher Renderer, full-low-full |
| `existing_quality_persistence.log` | `kart_quality_persistence_regression.gd` | PASS; Autoload lesen/schreiben, Dateipersistenz, Szenensignal |
| `existing_scene_switch.log` | `kart_quality_scene_switch_regression.gd` | PASS; echte SceneTree-Wechsel wenden LOW ohne Speichern erneut an |

## Reproduktion

Vom Worktree-Verzeichnis aus, für einen isolierten Compatibility-GREEN-Lauf:

```bash
mkdir -p /workspace/scratch/24cce871676c/xdg/render_quality/recheck/{data,config,cache}
XDG_DATA_HOME=/workspace/scratch/24cce871676c/xdg/render_quality/recheck/data \
XDG_CONFIG_HOME=/workspace/scratch/24cce871676c/xdg/render_quality/recheck/config \
XDG_CACHE_HOME=/workspace/scratch/24cce871676c/xdg/render_quality/recheck/cache \
python3 tools/run_godot_probe.py \
  --log evidence/render_quality/recheck_gl_compatibility.log \
  --timeout 40 --required '[KartQualityRenderer] PASS' \
  -- taskset -c 6,7 /usr/local/bin/godot --headless --path . \
  --rendering-method gl_compatibility \
  --script res://scripts/tests/kart_quality_renderer_regression.gd
```

Für die anderen Renderer `mobile` beziehungsweise `forward_plus` und jeweils eigene Log-/XDG-Pfade verwenden. Die drei vorhandenen Regressionen wurden mit Compatibility und den PASS-Präfixen `[RendererProfiles] PASS`, `[KartQualityPersist] PASS` und `[KartQualitySceneSwitch] PASS` ausgeführt.

## Bestehende Warnungen und Aussagegrenzen

Die Compatibility-Läufe enthalten bereits beim Start Warnungen zur Screen-space-AA-Einstellung und zu volumetrischem Nebel; Mobile meldet beim Start SSAO und volumetrischen Nebel. Diese stammen aus den bestehenden Start-/Default-Environment-Einstellungen und sind im RED sowie weiterhin in GREEN sichtbar. Dieser gezielte Fix bereinigt diese separaten Startup-Einstellungen nicht. Es wird ausdrücklich kein warnungsfreier Start behauptet.

Verifiziert sind Laufzeitkonfiguration, Qualitätswechsel, Szenenwechsel und Persistenz auf einem Linux-Host. `--rendering-method mobile` wählt den Mobile-Renderer, emuliert jedoch kein Android-Gerät und setzt nicht die Plattformkennung Android. Headless-Prüfungen belegen keine visuelle Renderqualität, GPU-Zeit, Android-Leistungssteigerung oder stabile 60 FPS. Dafür liegen aus diesem Prüfschritt keine Gerätedaten vor.
