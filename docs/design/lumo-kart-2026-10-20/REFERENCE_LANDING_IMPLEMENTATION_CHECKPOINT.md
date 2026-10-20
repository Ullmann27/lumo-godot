# LUMO KART – TECHNISCHER ZWISCHENSTAND: REFERENZ IN FUNKTIONALE TEILE ZERLEGEN
**Stand:** 20.10.2026
**Branch:** `design/lumo-kart-premium-ui-implementation-20261020`
**Draft-PR:** https://github.com/Ullmann27/lumo-godot/pull/111

## Echt implementiert
- `scripts/games/kart_reference_landing.gd`: neue, native Godot-Landing mit eigenständigen Bereichen für Logo, Szenen-Hero, zwei Rennmodi, Strecken-/Garage-/Einstellungskarten, realem Startbutton und Rückweg. Landscape zweispaltig (Menü links, Hero rechts), Portrait untereinander mit Scroll und großen Touchzielen.
- `scripts/games/kart_garage_menu.gd`: Landing wird im echten Spiel beim normalen Start angezeigt (außer automatisierte `--script`-Tests und vorhandene fortsetzbare Rennen); der bisherige Kart-Konfigurator bleibt vollständig erhalten und wird nach Auswahl sichtbar.
- Schaltflächen: `cup` → realer Sternen-Cup; `time_trial` → echtes Zeitrennen; `sonnenhafen` → echte Track-Auswahl mit vorgewähltem Sonnenhafen; `garage` → Fahrzeugauswahl; `settings` → vorhandener Eltern-/Einstellungsbereich; `START` → echter `start_requested`-Pfad über vorhandenes Setup, nicht ein Placeholder; `Zurück` → Spielewelt.
- `scripts/tests/kart_reference_landing_visual.gd`: Funktionstest und reale Godot-Render-Screenshots in Landscape 1280×720 und Portrait 690×829; im vorhandenen Workflow `.github/workflows/lumo-nextgen-design-smoke.yml` eingehängt.
- `tools/build_lumo_reference_sprites.py`: reproduzierbare Erzeugung der aus **exakt demselben Originalbild** gewonnenen WebP-Assets mit weichen transparenten Rändern und dokumentierten Zuschnittkoordinaten.

## Dateitransfer / Bildwahrheit
Die neun WebP-Elemente aus dem Benutzer-Referenzbild wurden lokal erzeugt und als **LUMO_KART_TRANSPARENTE_GODOT_ASSETS_20261020.zip** im Chat bereitgestellt. Die Originaldatei hat 941×1672 Pixel. Im Verzeichnis `assets/kart/landing` fehlen diese Binary-Dateien noch im GitHub-Branch, weil die GitHub-Schreibschnittstelle in dieser Sitzung nur UTF-8-Dateien bzw. vom Modell mitgelieferte Text-/Base64-Blobstrings annimmt und bisher keine vollständige Übertragung der Binärbilder bestätigt wurde. Kein stillschweigendes „hochgeladen“ behaupten.

**Sobald die WebP-Dateien in Git sind**, lädt die Landing sie automatisch statt des markentreuen Bestandsbilds: `cinematic_hero.webp`, `sunset_world.webp`, `kart_logo_art.webp`, `grand_prix_art.webp`, `time_trial_art.webp`, `sonnenhafen_art.webp`, `garage_art.webp`, `settings_art.webp`, `lumo_avatar.webp`. Der Import ist 1:1 reproduzierbar mit:
```
python3 -m pip install Pillow
python3 tools/build_lumo_reference_sprites.py /pfad/zur/original_referenz.png
```
Die resultierenden Originalcrops sind **keine perfekte Freistellung der einzelnen Objekte** (Kulissenreste möglich); sie besitzen Alpharänder und sind als dekorative Bildschichten vorgesehen. Alle Labels/Buttons bleiben Godot Controls, die Inhalte kommen aus tatsächlichem Spielstand/Setup.

## Prüfstand
Der neue Landing-Render-/Funktionslauf vom 20.10.2026 über GitHub Actions lief bereits mit vorhandenen Fallback-Grafiken erfolgreich; weitere Layoutänderungen und die globale Stage-2-Regression müssen pro neuem HEAD erneut abgenommen werden. Ein vorheriger globaler Stage-2-Lauf scheiterte wegen Portrait-Reihenfolge Hero/Mode-Karten, obwohl der separate ProductionMenu-Test 628/628 Prüfungen bestand. Die Portrait-Containergröße wurde danach korrigiert; PASS erst mit neuem CI-Beleg.

## Nächster Schritt
1. Binary-Assets **wirklich** ins Repository bringen; `ResLoader.exists` prüfen.
2. CI beider Layouts sowie Stage-2-Regression auf aktuellem PR-Head durchführen und Fehler korrigieren.
3. Echte Screenshots **nach** Assetimport visuell mit der freigegebenen Originalreferenz vergleichen; eingebrannte Schriftreste/Kulissen bei Bedarf durch echte Alphamasken verbessern.
4. Für finale Android-Auslieferung ein echtes APK-Build- und Fold-Geräte-Rendering machen.
5. Alle Änderungen in PR #111 lassen; `main` nicht ändern.
