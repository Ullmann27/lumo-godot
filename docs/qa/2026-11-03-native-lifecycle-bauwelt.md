# Native Prüfung: Original-Lumo, Bauwelt und Capture-Lebensdauer

Stand: 3. November 2026. Integrations-PR: [#129](https://github.com/Ullmann27/lumo-godot/pull/129).

## Reproduzierter Fehler und eng begrenzte Abhilfe

Der ältere [Stunt-Lauf 41657189168](https://github.com/Ullmann27/lumo-godot/actions/runs/41657189168) erzeugte am Commit `bc1f61338fb1e1be3311bf4c229a8fc09487e904` alle zehn Precision-PNGs. Trotzdem scheiterte der strenge Runner anschließend an einer ObjectDB-Warnung und zwei noch verwendeten Ressourcen. Die damalige Ausgabe enthielt keine Ressourcennamen.

Eine getrennte lokale Diagnose führte dieselbe tatsächliche Kart-Szene und denselben Fahrablauf ohne Bildausgabe aus. Bei schnellen Zustandswechseln blieb der Exit sauber. Mit 150 ms zwischen Zuständen war der Fehler reproduzierbar. Das vollständige `--verbose`-Log identifizierte Ogg-Musik-/Effektressourcen und deren Playbacks für `sonnenhafen.ogg` und `drift.ogg`. In diesem Lauf waren es vier Ressourcen. Das belegt einen zeitabhängigen Audio-Lifecycle-Fehler beim sofortigen Beenden des Capture-Prozesses; es belegt keinen Render- oder Speicherverlust im normal weiterlaufenden Spiel.

`kart_sonnenhafen_precision_capture.gd` sammelt deshalb vor dem Freigeben der Szene ausschließlich schwache Referenzen auf die tatsächlichen Audiostreams. Nach `queue_free()` darf der Audio-Thread seine Freigabe abarbeiten. Der Test verlangt innerhalb von zwei Sekunden, dass jeder beobachtete Stream wirklich freigegeben ist; andernfalls scheitert eine Assertion. Die PASS-Ausgabe folgt erst danach. Zusätzlich müssen alle zehn erwarteten Zustände aufgenommen worden sein.

Musik und Effekte bleiben während des vollständigen Ablaufs aktiv. Der strenge Runner und seine Fehlererkennung bleiben unverändert. Es werden weder Audiowarnungen unterdrückt noch Ressourcen künstlich aus dem Cache gelöscht. Die lokale zuvor fehlschlagende Diagnose meldete mit der Abhilfe vier freigegebene Audiostreams und einen sauberen Exit.

## Original-Lumo in Jump

Lokal mit Godot `4.6.3.stable.official.7d41c59c4` geprüft:

- `lumo_65bone_walk_gait_regression.gd`: tatsächliche alternierende Bein-/Fußbewegung, Pause, reduzierte Bewegung, Neutralstellung und bestehende Kart-Pose.
- `lumo_original_jump_visual_regression.gd`: importiertes Originalmodell mit 65 Knochen sichtbar; prozeduraler Ersatz unsichtbar; Bodenkontakt, Bewegung durch Touch-Eingabe, unveränderte visuelle Wurzelposition, Pause und Fortsetzen.
- `jump_regression.gd`: vollständiger physischer Weg über zwölf Inseln, drei Lernstopps, Kollisionen, Sprung, Kontrollpunkte, Wiederholung und Speichern/Fortsetzen. Der vollständige Lauf endete nach 1.018 Simulationsframes ohne Absturz oder Leak-Ausgabe.

Der ursprüngliche Jump-Rig-Test prüfte diese Eigenschaften ausschließlich headless. Sein optionaler Modus `--capture` verlangt jetzt zusätzlich einen tatsächlichen GL-Display und schreibt vier 720×1280-Bilder der normalen Spielkamera: am Boden, beim Gehen, pausiert und nach Fortsetzen. Der Standardmodus bleibt für die schnelle Logikprüfung erhalten. Der bestehende Rig-Workflow führt beide Varianten aus und hinterlegt den geprüften Source-SHA.

Die allgemeine Projektprüfung `tools/validate_project.py` ergab 117 PASS, sieben WARN und null FAIL. Sechs Warnungen betreffen ältere zentrale Manifest-Einträge ohne Modelldatei (`lumo_fox`, `hub_island`, `portal_learn`, `portal_games`, `portal_parent`, `star_collectible`), für die der AssetLoader einen Platzhalter vorsieht. Die siebte betrifft das fehlende Ausführungsbit von `tools/build_web_bundle.sh`. Diese Warnungen sind nicht behoben. Der hier geprüfte Jump-Spieler verwendet nachweislich den vorhandenen importierten `assets/characters/lumo_animated/Lumo-Animated-Mobile.glb`, nicht den alten `lumo_fox`-Manifestpfad.

## Tatsächlicher Bauwelt-Nachweis

Der [native Prüflauf 41735507220](https://github.com/Ullmann27/lumo-godot/actions/runs/41735507220) lief auf `ce5be65a5b183af246d017e8bf4686a9b9d0d03e` erfolgreich. Dieser Commit enthält den Original-Lumo-Jump-Stand und die neuen Diagnose-Gates, aber noch nicht die nachfolgende Precision-Teardown-Abhilfe und den zusätzlichen Jump-Bildmodus.

Das Bauwelt-Artefakt [13278522491](https://github.com/Ullmann27/lumo-godot/actions/runs/41735507220/artifacts/13278522491) enthält vier tatsächlich gerenderte 1280×720-PNGs und die Laufprotokolle. ZIP-SHA-256: `d42f1f4863524d2a8562ba85755c219f33152dd0b0b1fc598fd61442fbf80faa`.

Der verwendete Renderer war Godot GL Compatibility mit Mesa/llvmpipe. Die Prüfung rief `save_world(false)` auf, leerte anschließend das offene Modell, lud den JSON-Spielstand mit `load_world(false)` wieder und prüfte Teilezahl und erfolgreiches Brückenziel. Die vier Bilder zeigen:

1. Eine gebaute Burg mit 161 Teilen und der tatsächlichen Werkzeugleiste.
2. Die wiederhergestellte Welt mit 163 Teilen und fertiger Brücke; die Oberfläche bestätigt das erfüllte Bauziel.
3. Den tragenden Turm mit Laterne.
4. Das tatsächliche Pausenmenü mit Weiterbauen, Speichern und Zur Spielwelt.

Zusätzlich bestanden lokal die Bauwelt-Prüfungen für tragende Teile, Kollisionen, durchgehende Flussüberquerung, Haus-/Burg-/Dorf-/Turmziele, Undo/Redo und die Ablehnung überlappender Daten beim Laden. Eine getrennte Headless-Diagnose der tatsächlichen Szene bestätigte auch den JSON-Disk-Roundtrip. Diese Headless-Diagnose wird ausdrücklich nicht als Bildnachweis verwendet.

## Visuelle Einordnung und Grenzen

Die Bauwelt-Bilder sind Laufzeitbilder, keine Referenzposter. Die Bedienflächen und Bauziele sind lesbar; Burg, Brücke und Turm sind tatsächliche veränderbare Geometrie. Geometrie und Beleuchtung bleiben vergleichsweise einfach, und die Werkzeugleisten enthalten viel Text. Der Lauf belegt keine vollständige Übereinstimmung mit der hochwertigen Referenzmappe und keinen abgeschlossenen AAA-Qualitätsstand.

Auch das Precision-Artefakt [13277254660](https://github.com/Ullmann27/lumo-godot/actions/runs/41735507220/artifacts/13277254660) enthält zehn tatsächliche Laufzeitbilder: Looping-Anfahrt, Schanze/Lücke, rote/grüne/orange Tempoanzeige, Flug, Landung und zu kurzen Sprung. ZIP-SHA-256: `3c817aa6a065537b314b9b9864c8eef36c88d0c536b3a86586a1974fad0a12cb`. Sein zufällig sauberer Exit am noch ungeänderten Capture bestätigt, dass der ältere Fehler zeitabhängig ist; er ersetzt die gezielte Abhilfe nicht.

Diese GL-Läufe sind keine Messung auf einem physischen Android-Gerät und kein Nachweis stabiler 60 FPS. Der native Bauwelt-Start aus der APK, Speichern/Neustart, Rückkehr in die Flutter-App und der endgültige Download-Kanal benötigen zusätzlich die Android-/Release-Gates auf dem finalen Produktpin. Die vollständige GL-Wiederholung nach dem Lifecycle-Patch sowie die vier neuen Jump-Bilder müssen mit ihrem tatsächlichen Run und Commit dokumentiert werden, bevor diese Nachweise als abgeschlossen gelten.
