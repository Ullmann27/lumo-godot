# Lumo Next Gen – unabhängiges Godot-Audit, 23.10.2026

Geprüfte Basis: `3a3142608f6b150ee251373ba81e6face2eed4b3`, Godot **4.6.3.stable.official.7d41c59c4**, Linux. Auditbranch: `codex/lumo-godot-nextgen-audit-20261023`. Kein Main-Merge, Android-Export oder Release. Alle Belege dieses Audits liegen unter [evidence/nextgen-audit-20261023](evidence/nextgen-audit-20261023/).

## Basis und Abstammung

`git merge-base --is-ancestor` bestätigt jeweils Exit 0:

| Erhaltener Stand | SHA / PR |
| --- | --- |
| Verifizierte Gameplay-Basis | `63cecf09fa89dd504cc468ebd121b4ec71a0f36c` |
| Integrierte Astra-Menüs | `928fed3c7f0b39357e0f06463ce13c8d5677d6e1`, [PR 113](https://github.com/Ullmann27/lumo-godot/pull/113) |
| SOL-Menü-/dp-Korrekturen | `700baf49828eda693ecce15b415847818b1b56d3`, [PR 114](https://github.com/Ullmann27/lumo-godot/pull/114) |
| Neuester vorhandener passender Remote-Stand | `3a3142608f6b150ee251373ba81e6face2eed4b3`, `origin/claude/kart-landing-landscape-fit-20261022` |

**3a314 enthält 700baf4 vollständig und ist dessen direkter Folgecommit.** Der zusätzliche Commit korrigiert ausschließlich den Landing-Fit und ergänzt dessen Regression/Bildbelege. Ein Rücksetzen auf PR 113/114 wäre ein Verlust dieses Landscape-Fixes. Beide PRs waren beim Live-Abruf offen. Die historische `OPUS_NEXT.md`-Übergabe endet am 9.10.; auch die Übergabe vom 17.10. ersetzt keinen aktuellen SHA-/APK-Nachweis. Die letzten Engine-Smokes nach dem isolierten Hub-Fix wurden erneut ausgeführt; die Kart-Quellen sind gegenüber 3a314 bytegleich.

Der separat gepushte, kleine Runtime-/Regressionscommit ist **`4d0fd40fdf188be6ca86057596c7b51f41701fa3`**. Er ist direkter Nachfolger von 3a314 und der passende neue Pin-Kandidat für genau diesen Hub-Fix; dieser Audit ändert keine App-Pindatei.

## Tatsächlicher Einstieg und Navigation

- `project.godot` startet **`scenes/app/boot.tscn`**, Script `scripts/app/app_boot.gd`.
- Boot lädt die gültige Host-/CLI-Option `scene`; ohne gültige Auswahl **`games` → `scenes/games/game_hub.tscn`**. Bei `scene=kart` lädt Boot direkt `kart_island.tscn`; die alten Intro-/Home-Szenen sind nicht der normale Bootpfad.
- Im echten Kart-Start ohne `--script` montiert `_show_garage()` automatisch **`KartReferenceLanding`**. Garage/Preview bleiben verborgen. Cup, Zeitrennen und Sonnenhafen bleiben im Premium-Menü; erst die ausdrückliche Garage-Wahl öffnet die vorhandene Anpassung. START startet das konfigurierte echte Rennen.
- Das neue Prüfszenario unter `docs/evidence/.../production-entry.tscn` startet ausdrücklich **ohne `--script`**: echte Boot-/Routerkette, bei `scene=games` echter Touch auf Kart, automatisches Premium-Menü und direkter Zeitrennenstart. Damit wird die automatische Produktionsverzweigung geprüft; die älteren Script-Tests montieren das Landing teilweise ausdrücklich selbst.

## Gefundener und gezielt behobener Navigationsfehler

Die vorhandenen Hub-Smoke-/Capturetests meldeten auf 3a314 PASS, obwohl beide echten Hub-Bilder **keine Spieleauswahl** zeigten. `ScrollableRealGameActions` hatte Höhe 0: `SIZE_SHRINK_END` reservierte dem ScrollContainer keinen vertikalen Raum.

Die ergänzte Regression wurde zuerst gegen diesen Zustand ausgeführt: **FAIL „Real game routes are clipped by a collapsed scroll area“**. Die einzige Runtimeänderung setzt den ScrollContainer auf **`SIZE_EXPAND_FILL`**. Danach sind alle drei Routen tatsächlich sichtbar bzw. erreichbar; der Test prüft Scroll- und Bildschirmgrenzen auf vier Größen. Originalmenü, Lernoptionen, Assets, Rennen und Speicherformate bleiben erhalten. Neue Hub-Bilder dokumentieren die sichtbare Auswahl.

## Frisch ausgeführte Prüfungen

| Prüfung | Tatsächliches Ergebnis |
| --- | --- |
| Headless Editor-Import | Exit 0; keine `SCRIPT ERROR`, `Parse Error` oder `ERROR:` |
| `tools/validate_project.py` | **117 PASS / 7 WARN / 0 FAIL** |
| Landing-Fit, headless und echter GL-Renderer | **PASS**, 2400×1080@2.625, 1600×720@2, 2316×904@2.625, 2176×1812@2.625; alle fünf Beschriftungen über START, Ziele ≥48 dp |
| Echter Kart-Owner / Premium START | **PASS**, Cup mit echtem Spieler und fünf Gegnern |
| Boot-/Loading-Regression | **PASS** (Erstlauf 149, final 139 Checks; Ladefortschrittsabfragen zählen pro Frame), reales Laden, Originalmodell-Texturen, Retry/Timeout, Kart-Szenenwechsel |
| Race-Bridge | **PASS**, Pause/Resume-ID, genau eine Belohnung, Integer `solved=0`, ACK-Fehler behält Save, Cup-/Legacy-Verhalten |
| Physikregression | **PASS**, tatsächliche Leitplankenfahrten auf zwölf Strecken sowie Drift, Pedale, Boost und Wolkenweg |
| Vollständige Touch-Menütour | **PASS**, fünf Setupseiten, echte Einstellungen, Rückkehr und konfigurierter Rennstart auf 640×360, 320×740, 840×960, 1280×720; **24 echte PNGs** |
| Sichtbare Hub-Routen nach Fix | **PASS**, vier Größen; zusätzliche echte Hub-Renderbilder |
| Produktions-Boot ohne `--script` | **PASS**, headless und GL bei direktem Kart-Einstieg sowie Boot→Hub→echter Kart-Touch→überspringbarem Intro→Premium-Menü |
| Vollständiges Zweirundenrennen mit GL | **TIMEOUT nach 420 s**, Start, Pause und Wiederaufnahme sichtbar; kein Abschluss-PASS dieses Laufs |
| Geänderter Sichtbarkeitstest: `gdlint` / `gdformat --check` | **PASS / PASS** |
| Repo-weites `gdlint` / `gdformat --check` (gdtoolkit 4.5.0) | Vor Änderung bereits **1016 Probleme / 175 zu formatierende Dateien**; keine pauschale Bereinigung |

Die sieben Validatorwarnungen betreffen sechs ältere Manifest-GLBs und das nicht ausführbare `tools/build_web_bundle.sh`. Die verwendeten Menübilder und der Kart-Lumo wurden durch reale Engine-Prüfungen geladen. GL-Belege nutzen Mesa llvmpipe; erwartete Renderer-/V-Sync-Warnungen sind vollständig in den Logs erhalten.

## Grenzen und Folgeprüfung

- Der Hub verwendet weiterhin die vorhandene prozedurale `lumo_character.tscn`; der kleine Fuchs im Bild entspricht nicht der aufwendigen illustrierten Kart-Figur. Keine Referenzgleichheit behauptet.
- Reproduzierbarer separater CLI-Befund: `--reduceAnimations=true` kommt als String an und scheitert in `app_boot.gd:68` an `bool(String)`. Normaler CLI-Start passiert; Android liefert diese Option typisiert über die Host-Bridge. Der CLI-Befund wurde nicht auf Verdacht in einen Android-Runtimefix umgebaut.
- `kart_loading_regression.gd --navigation-only` ohne Fenstergröße scheitert im Headless-64×64-Default. Dieselbe Diagnose mit 720×1280 passiert **110 Checks**; die kanonische Variante mit Größenmatrix passiert 149. Dies ist kein belegter Android-Navigationsfehler.
- Die neue Sichtbarkeitsregression des Hubs belegt Grenzen/Erreichbarkeit. Die bisherigen Hub-Smokes prüfen Mindesthöhen in logischen Koordinaten; daraus folgt kein zusätzlicher physischer Android-48-dp-Nachweis.
- Nächster Android-Schritt: exakten Kandidaten einschließlich des belegten Hub-Fixes pinnen, APK/PCK-Quell-SHA und Hash prüfen, dann API 35/36 mit echter Premium-Einstiegskette testen: alle fünf Karten bei 2400×1080/420 dpi, Garage/Einstellungen/Zurück, zwei tatsächlich gefahrene Runden/16 Gates, Pause/Resume/Reopen, Ergebnis, genau eine Belohnung und native Rückkehr. Kein Rückfall auf alte Flutter-/Godot-Menüs. Ein echter Fold-/FPS-/Ton-Nachweis und neue Android-Abnahme bleiben offen.

## Reproduktion

```bash
# Echte Produktionsverzweigung, kein --script-Testmodus:
audit_data_dir="$(mktemp -d)"
XDG_DATA_HOME="$audit_data_dir" godot --headless --path . docs/evidence/nextgen-audit-20261023/production-entry.tscn -- --scene=kart
XDG_DATA_HOME="$audit_data_dir" godot --headless --path . docs/evidence/nextgen-audit-20261023/production-entry.tscn -- --scene=games

# Neue sichtbare Hub-Regressionsbedingungen:
XDG_DATA_HOME="$audit_data_dir" godot --headless --path . --script res://scripts/tests/kart_nextgen_ui_smoke.gd

# Echte Bilder, mit X11-Display / alternativ xvfb-run:
LIBGL_ALWAYS_SOFTWARE=1 godot --path . --rendering-method gl_compatibility --audio-driver Dummy --script res://scripts/tests/kart_nextgen_ui_capture.gd
```

Desktop-Proben wurden mit getrennten `XDG_DATA_HOME`-Verzeichnissen ausgeführt. PNG-Originale und die 24 Bilder der Menütour liegen im Arbeitsverzeichnis `/workspace/scratch/lumo-godot-audit-20261023/`; ausgewählte unveränderte Bildabmessungen wurden nur als JPEG archiviert. [image-provenance.json](evidence/nextgen-audit-20261023/image-provenance.json) enthält Original-/Archivhashes. Keine generierten Konzeptbilder als Runtime-Belege.
