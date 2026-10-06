# Track implementation progress

## Etappe 1 – unmittelbare Turbo-Reaktion

- Agent: GitHub Copilot Coding Agent; konkreter Modellname in dieser Sitzung nicht sichtbar.
- Datum: 2026-10-05.
- Arbeitszweig: `copilot/lumo-kart-upload-streckenpakete`, Umsetzungs-PR #15 auf Referenz-PR #14.
- Basis-SHA: `7351f1756e1910389450e041185b846823a97e92`.
- Ergebnis-SHA für Laufzeitänderung und Regression: `1c090c112400762e349647b60d20733be824b46c`.
- Produktdateien: `scripts/games/kart_island.gd`, `scripts/tests/kart_physics_regression.gd`.

### Befund und Änderung

Der Touch-Callback nimmt einen gültigen Boost synchron an, setzt `boost_time` und startet den Boost-Sound. Die bisherige Physik erhöhte aber nur das Zieltempo um 42 Prozent; die Beschleunigung blieb gleich. Solange das Kart unter seinem normalen Zieltempo lag, brachte der Boost deshalb im ersten Physikschritt keinen zusätzlichen Geschwindigkeitszuwachs. Die Beschleunigung ist jetzt bei aktivem Turbo und steigendem Zieltempo verdoppelt; auch während eines Sprungs kann ein aktiver Turbo die Geschwindigkeit erhöhen. Das bestehende Zieltempo, der Controller und das Fahrgefühl außerhalb aktiver Turbozustände bleiben unangetastet.

Der gezielte Engine-Test protokolliert den Touch-Signalpfad, die angenommene Boostladung, den ersten Physikschritt, die Geschwindigkeitsänderung sowie den Zustand von Flammen-VFX und Audioplayer. Im Testlauf: +0,333 m/s mit Boost gegenüber +0,167 m/s ohne Boost; die vom Harness gemessenen Abstände waren 869 µs bis zur Annahme und 129 µs bis zum explizit aufgerufenen Physikschritt. Das sind synthetische Headless-Testwerte, keine Messung der realen Touch- oder Geräte-Latenz.

### Prüfung

- Godot 4.6.3 Headless-Import: bestanden.
- `scripts/tests/kart_physics_regression.gd`: bestanden, einschließlich gleichzeitiger Lenkung, Doppeltippen/leerem Slot, Countdown-/Pause-/Finish-Sperre, Neustart, Boost-Pad und Sprung.
- `tools/validate_project.py`: 117 PASS, 7 WARN, 0 FAIL. Die Warnungen betreffen fehlende optionale Modell-Assets und ein nicht ausführbares Build-Tool.
- `tools/validate_project.sh`: alle vorhandenen Testgruppen bestanden (Kart, Physik, Sprung, Touch, Welt, Pause-Layout, Fahrzeug und Host-Brücke).
- `git diff --check`: bestanden. `gdlint` und `gdformat` waren in der Sandbox nicht installiert.
- Read-only Kart-Physics-Review: keine hochsicheren Regressionen gefunden. PR-Validierung lieferte keine CodeQL-Analyse für GDScript; der allgemeine Code-Review-Dienst konnte das angeforderte Modell nicht starten. PR #15 hatte zum Prüfzeitpunkt keine GitHub-Check-Runs.
- Keine Geräteprüfung, kein Laufzeit-Screenshot und keine FPS-Messung durchgeführt.

### Offen und nächste Schritte

- Fold-/Resize-Pass ist jetzt als separate Etappe vor Fold-Freigabe und Streckenausbau in `TRACK_BUILD_ROADMAP.md` aufgenommen. Befund: `size_changed` aktualisiert nur Safe-Area-Margen; Kart fordert Landscape an; adaptive Controls und Hinge-Handling sind noch nicht nachgewiesen.
- Als nächstes vor Laufzeitänderungen die genaue Flutter-Testmatrix aus lumo-lernen PR #197 (`docs/TASK_FOLD_2026-10-05.md`) abrufen und die portrait-Activity-/Sensor-Landscape-Grenze mit dem zuständigen Bearbeiter koordinieren. Die Web-Abfrage auf den angegebenen Dateipfad lieferte 404; Matrix hier daher nur anhand des Godot-Kommentars erfasst. Keine Flutter-Datei oder kein Manifest wurde geändert.
- Auf einem echten Android-Gerät Eingabe-zu-Physik-/Audio-Latenz prüfen; keine Gerätewerte aus dem Harness ableiten.
- Bodenpfeile anhand lokaler Streckentangenten prüfen und gegebenenfalls pro Segment korrigieren; gekrümmte, geneigte und gespiegelte Segmente abdecken.
- Erst nach separatem Claim einen vorhandenen Abschnitt mit echter Streckengeometrie erweitern und Runde, Rampe, Landung, Checkpoints und KI-Fahrt nachweisen.
- Opus wurde nicht gestartet. Spätere konkrete Aufgabe: nach einem echten Gameplay-Nachweis den vorhandenen Look des ausgebauten Abschnitts stilkritisch prüfen, ohne Laufzeitgrafik oder Figuren pauschal zu ersetzen.


## Etappe 2 – Fold-/Resize-Pass und Fahrtrichtungs-Chevrons

- Agent: ChatGPT, direkt auf dem bestehenden Umsetzungszweig von PR #17.
- Ausgangs-Head vor dieser Etappe: `00cb001369d081a97d660e4a249a4539d502558b`.
- Aktueller Ergebnis-Head: `d190ee4d64019aa813644b7123635122e20c884f`.
- Produktdatei: `scripts/games/kart_island.gd`.
- Regressionen: `scripts/tests/kart_pause_layout_regression.gd`, `scripts/tests/kart_physics_regression.gd`.

### Umsetzung

1. `Viewport.size_changed` führt jetzt nicht mehr nur die Safe-Area-Neuberechnung aus, sondern einen gemeinsamen Resize-Pass.
2. Joystick und rechter Pedal-Cluster werden aus der aktuellen logischen Viewport-Höhe neu dimensioniert; feste Ausgangsmaße bleiben als Designbasis erhalten.
3. Minimap und Pause-/Ergebnis-Modal werden bei Größenänderungen neu eingerahmt.
4. Die Kamera verwendet eine begrenzte, seitenverhältnisabhängige Basis-FOV und behält den Boost-FOV-Aufschlag bei, statt auf jedem Seitenverhältnis starr 68/76 Grad zu verwenden.
5. Der vorhandene Pause-/Fold-Regressionstest deckt nun zusätzliche Innen-/Querformatgrößen ab und prüft, dass Rennsteuerung und Kamera nach Resize innerhalb der Safe-Area bleiben.
6. Die leuchtenden Turbo-Chevrons werden geometrisch aus der lokalen Fahrtrichtung `-basis.z` aufgebaut. Die Arme konvergieren damit explizit in Fahrtrichtung statt ihre Richtung nur aus einer Rotationskonvention abzuleiten.
7. Ein Regressionstest prüft den positiven Richtungs-Dot-Product der Chevron-Arme und ihre Links-/Rechts-Symmetrie.

### Abgrenzung / noch offen

- Der Android-Host-Fix liegt getrennt in lumo-lernen PR #197: `LumoGameActivity` wird dort von `portrait` auf `sensorLandscape` umgestellt und durch einen Regressionstest abgesichert.
- Hinge-Geometrie wird nicht erfunden. Solange der Android-Host keine explizite Falz-/Occlusion-Geometrie an Godot übergibt, kann Godot nur Safe-Area/Cutout und die tatsächliche Fenstergröße berücksichtigen.
- Für die Godot-Commits dieser Etappe war zum Dokumentationszeitpunkt kein automatischer GitHub-Workflow-Run vorhanden. Die neuen Regressionen sind eingecheckt, aber ein tatsächlicher Godot-Lauf muss noch als PASS/FAIL/SKIP nachgetragen werden.
- Kein echter Fold-7-Test und keine FPS-Messung ausgeführt.
- Nächster Produktblock: vollständigen Muster-Streckenabschnitt im bestehenden Opus-Stil ausbauen und danach die zehn Welten skalieren.


## Etappe 3 – Himmelsinseln Stage 2 + Mystery Items

- Basis: integrierter Kart-Stand aus PR #17 / `edc47b6`.
- Arbeitsbranch: `chatgpt/kart-himmelsinseln-stage2-2026-10-05`.

### Direkt umgesetzt

1. **Himmelsinseln verlängert**
   - nur `bergwelt` wird horizontal um Faktor 1,18 skaliert;
   - Kurvenradien werden dadurch nicht künstlich enger;
   - prozedurale Inseln, Brücken, Cave, Ruinen und Deko folgen weiterhin der echten Streckenkurve.

2. **Neues Sternentor-Setpiece**
   - sieben leuchtende Torbögen nach den Tempelruinen;
   - Cyan/Violett-Wechsel, Goldsterne, eigener Streckenmarker;
   - kontinuierliche Fahrbahn, kein Fake-Tunnel und keine erfundene Kollision.

3. **Sicheres Respawn am Sprung**
   - neue `safe_respawn_distance()`-Regel;
   - Reset landet nicht im offenen Gap und nicht mitten in der Rampen-Gefahrenzone;
   - bestehende geordnete Checkpoint-Logik bleibt erhalten.

4. **Mystery-/Zufallsboxen**
   - fünf sichtbare, leuchtende Item-Boxen pro Runde;
   - jede Box kann pro Runde einmal eingesammelt werden;
   - Position 5–6 erhält höhere Boost-Chance als Führende;
   - vorhandene Items bleiben `boost`, `shield`, `pulse`.

### Regressionen

- `kart_track_contract.gd` schützt:
  - Himmelsinseln als Long-Form-Kurs (>400 m),
  - Respawn außerhalb des Sprung-Gaps.
- `kart_physics_regression.gd` schützt:
  - fünf Mystery-Boxen,
  - stärkere Catch-up-Boost-Gewichtung hinten,
  - unmittelbaren Item-Pickup.

### Noch offen

- tatsächlichen Godot-Prüflauf für diese Etappe ausführen;
- echte Laufzeit-Screenshots des neuen Sternentors;
- zweites physisches Sprung-/Alternativrouten-Setpiece;
- Rivalen sollen Items aktiv taktisch einsetzen;
- weitere neun Referenzwelten auf denselben Detailstandard skalieren;
- Fold-7/FPS weiterhin nicht als getestet behaupten.


### Rivalen-Item-Taktik

- Rivalen besitzen jetzt eigene Item-Slots, Cooldowns, Boost-Zeit und Schild-Zeit.
- Rivalen nehmen dieselben Mystery-Box-Positionen als Item-Quelle wahr.
- Überhol-/Comeback-Logik nutzt die aktuelle Platzierung des jeweiligen Rivalen.
- Boost wird taktisch genutzt, wenn der Spieler vor dem Rivalen liegt.
- Lichtimpuls kann den Spieler aus kurzer Distanz abbremsen, sofern kein Schild aktiv ist.
- Rivalen-Schild blockiert den Lichtimpuls des Spielers.
- `kart_physics_regression.gd` prüft Boost-Nutzung, Schild und Rivalen-Pulse.

Aktueller Stage-2-Head nach dieser Erweiterung: `b048d1eba00f8ac9f2a2c9a5d25cf69a023b2dd6`.


### Validation follow-up

- Copilot checked commit `cc8cafb0e0ac3a37b0adc6a9f927aa8908c3c870`: `tools/validate_project.py` passed with 117 PASS / 7 WARN / 0 FAIL.
- Godot parser/lint and the focused Kart regression scripts remain SKIP because Godot/gdlint/gdformat are not available in that runner.
- Manual review found a later-lap respawn edge case: cumulative race distance was compared directly with lap-local jump geometry. `cc8cafb0e0ac3a37b0adc6a9f927aa8908c3c870` fixes the local/cumulative distance handling.
- `894720592473d886b8f599a5251cec1002723898` adds a later-lap regression assertion; execution is still SKIP until a Godot runner is available.
- lumo-lernen PR #197 still pins Godot `a369da2dc208fcd9d5451c7007d8b1f9e7bf52a1`, not this Stage-2 branch. A future candidate build must deliberately update that pin only after Kart validation and then verify provenance again.
- No Fold-device or FPS claim.


## Etappe 4 – Sonnenhafen Referenzqualitäts-Pass

Auslöser: Heinz' neue Family-Kart-Racer-Referenzbilder mit breiten Asphaltkurven, rot/weißen Curbs, Fels-/Gras-Terrassen, Tribünen, Wasserfall, Streckenbeleuchtung und klaren Item-Reihen.

### Recherche vor der Umsetzung

- TheDuckCow/godot-road-generator 0.9.4 (MIT) als Straßen-/Lane-/Authoring-Referenz geprüft.
- TokisanGames/Terrain3D (MIT) als Terrain-Authoring-Kandidat geprüft; noch keine Runtime-Abhängigkeit.
- GDQuest godot-shaders (Source MIT) für stylized directional tint / Wasserfall-Techniken geprüft.
- Godot SurfaceTool + MultiMesh bleiben Versandbasis der mobilen Lumo-Strecken.

Details: `docs/track_expansion/2026-10-05/OPEN_SOURCE_TRACK_TECH.md`.

### Direkt umgesetzt

- neuer stylized vertex-tint Shader für prozedurale Lumo-Terrainmeshes,
- Sonnenhafen auf filmische, hellere Tagesbeleuchtung abgestimmt,
- rot/weiße Curbs,
- `LUMO GRAND PRIX`-Starttor,
- echte Startaufstellungs-Markierungen,
- zwei prozedurale Tribünen mit MultiMesh-kompatibler Crowd,
- gelb/schwarze Kurven-Warnboards,
- Straßenlaternen,
- eigener Küsten-Wasserfall mit Fels- und Grasterrasse,
- keine fremden Franchise-Assets, Logos, Figuren oder exakten Streckenlayouts übernommen.

### Lizenz / Attribution

- `THIRD_PARTY_NOTICES.md` ergänzt.
- Der neue Lumo-Shader ist für unsere Vertex-Farben umgeschrieben; keine GDQuest-Art-Assets wurden importiert.

### Abnahme noch offen

- Godot-Parser/Runtime für aktuellen Head,
- echter Sonnenhafen-Runtime-Screenshot,
- Performance-/Draw-Call-Messung,
- Fold-Geräte-FPS weiterhin nicht als geprüft behaupten.


## Etappe 5 – Physischer Wolkenweg-Split auf Himmelsinseln

- Agent: ChatGPT, direkt auf dem bestehenden PR-#18-Branch.
- Ausgangs-Head: `b310aa0e224c3b1c26d26e506fe933a9df6e90d5`.
- Implementierungs-Head vor dieser Fortschrittsnotiz: `251c157772a22d0d442a375462ea408d3c06faea`.
- Abgrenzung: nur Himmelsinseln; vorhandene Opus-Farb-/Landmarkenrichtung bleibt erhalten. Kein Merge nach `main`, kein Force-Push.
- Claim-Prüfung vor Umsetzung: keine offenen Review-Threads oder Reviews und kein neuer PR-Kommentar, der diesen nächsten Setpiece-Schritt beansprucht. Stage 2 und Rivalen-Item-Taktik waren bereits umgesetzt.

### Direkt umgesetzt

1. **Zweite echte Routenentscheidung**
   - zwischen Tempelruinen und Sternentor liegt jetzt der erhöhte linke `WOLKENWEG`;
   - die rechte `HAUPTWEG`-Spur bleibt auf der ursprünglichen Fahrbahnhöhe;
   - der Split beginnt und endet weich und ist vollständig vor dem Sternentor wieder zusammengeführt.

2. **Physische Fahrhöhe statt Dekor-Attrappe**
   - `split_route_height()` bildet die zusätzliche Höhe längs und quer kontinuierlich ab;
   - Spieler-Fahrhöhe und Fahrzeugneigung verwenden diese Funktion;
   - Rivalen verwenden dieselbe Höhen-/Neigungslogik entsprechend ihrer tatsächlichen Spur;
   - die visuelle Wolkenweg-Platte, Leuchtkanten und Stützen folgen derselben Geometrie.

3. **Opus-Richtung bewahrt**
   - bestehende Himmelsinseln-Palette mit Cyan, Violett, Gold und Navy weiterverwendet;
   - keine fremden Franchise-Assets oder kopierten Streckenbauteile;
   - keine Änderung an bestehendem Sprung, Mystery Items oder Sternentor.

### Regressionen

- `kart_track_contract.gd` schützt:
  - ausreichenden Abstand zum bestehenden Sprung;
  - Rejoin vor dem Sternentor;
  - erhöhte linke Spur bei unveränderter rechter Hauptspur;
  - weichen Beginn/Ende sowie positive/negative Rampenneigung.
- `kart_physics_regression.gd` enthält `_test_wolkenweg_split_route()`:
  - linke Spur ist physisch >1,5 m erhöht;
  - rechte Spur bleibt auf Originalhöhe;
  - `_move_vertically()` setzt den Spieler tatsächlich auf beide unterschiedlichen Fahrhöhen.

### Commits dieser Etappe

- `92d3ed7fef7bc6830379dbf14b5ef85327188534` – Wolkenweg-Setpiece und Höhenprofil.
- `4554879e4830faecfa381e9fc2262fc1d8c267e3` – World-API für alternative Routenhöhe/-neigung.
- `61646c0443da20c5212214311341a55a72a77321` – Rejoin-Abstand vor Sternentor korrigiert.
- `de992325585ec12fc1062669b051ab9a2b7360aa` / `9c59091dad1b47ad28516b5cdcdd9e388e52fe07` – Spieler-/Rivalen-Fahrhöhe und Neigung.
- `4e653d4617b68698403f1e4527b8ab58fe3f899d` – Track-/Physics-Regressionen.
- `251c157772a22d0d442a375462ea408d3c06faea` – typisierte Markerfarbe.

### Validierungsstand

- Letzter vollständig abgeschlossener Stage-2-GitHub-Lauf vor dieser Etappe: Workflow `37355529872` auf `b310aa0e224c3b1c26d26e506fe933a9df6e90d5`: **PASS**.
- GitHub-Workflow `37367174927` auf `8b587a4526940cfd24b4bb448030709a275ecab2`: **PASS** – 117 PASS / 7 WARN / 0 FAIL; Godot 4.6.3 Import/Parse, Track-Contract, Kart-Physics, Xvfb-Fold-/Pause-Matrix und Sonnenhafen-/Himmelsinseln-Runtime-Captures bestanden. `[KartSplit]` bestätigt Wolkenweg +2,20 m und Hauptweg +0,00 m.
- Physisches Fold-Gerät, reales Android-Gerät und FPS-Messung: **SKIP** – nicht ausgeführt; Xvfb ist kein Geräte- oder FPS-Nachweis.
- `lumo-lernen` pinnt den neuen Stand noch nicht: PR-#197-Branch `chatgpt/fold-resize-fix-2026-10-05` steht auf Godot `a369da2dc208fcd9d5451c7007d8b1f9e7bf52a1`; Test-APK-Branch `chatgpt/lumo-test-apk-2026-10-05` auf `2ba65940eb250e7fac5a4bbaccdc6d730daed307`. Vor einer neuen APK muss der freigegebene PR-#18-SHA bewusst aktualisiert und die Provenienz erneut geprüft werden.

### Nächster Schritt

Erst den Wolkenweg-Lauf abschließen und einen reproduzierbaren Fehler gegebenenfalls minimal korrigieren. Danach ist der nächste unbeanspruchte Produktblock die Übertragung des bewährten Detail-/Setpiece-Prinzips auf die übrigen Streckenwelten, weiterhin weltweise und begrenzt statt als großer gleichzeitiger Umbau.



## Etappe 6 – Zauberwald Qualitäts-Skalierung

- Agent: ChatGPT, direkt auf PR #18 / `chatgpt/kart-himmelsinseln-stage2-2026-10-05`.
- Ausgangs-Head: `f7118a0c5d39b405d7945f160a75705bee7657de`.
- Claim-Prüfung vor Umsetzung: keine offenen Review-Threads oder Reviews und kein neuer PR-Kommentar, der den nächsten Welt-Ausbau beansprucht.
- Opus-Richtung bleibt erhalten: dunkles Waldblau, Türkis/Cyan, Flieder/Violett, biolumineszente Pilze/Kristalle; keine fremden Franchise-Assets oder kopierten Streckenlayouts.

### Direkt umgesetzt

- `b80c536a2273f3d37520d043335bc0db13bbdff0` – erster weltweiser Skalierungsschritt nach Himmelsinseln:
  - zwei große leuchtende Wald-Bögen bei ca. 23,5 % und 78,5 % der Runde;
  - vier klar lesbare Kristall-/Pilz-Beacon-Zonen;
  - zusätzliche Glühkugeln nur im höheren Detailmodus;
  - eigener größerer Pilzhain als Landmarke bei ca. 72 %;
  - vorhandener Baumtunnel und `LICHTERHAIN` bleiben unverändert eingebettet.
- `2449b8586f9dc784f8ea4c02256e6ed4916c044a` – Zauberwald-Showcase-Harness mit sechs fest definierten Kamerapositionen ergänzt. Der Harness ist eingecheckt und vom Import-Parser erfasst, wird vom bestehenden Stage-2-Workflow aber noch nicht als eigener Capture-Schritt ausgeführt.

### Validierung

- Der zuvor abgebrochene Workflow `37367669408` auf `f7118a0c5d39b405d7945f160a75705bee7657de` wurde gezielt neu gestartet und endete vollständig **PASS**.
- GitHub-Workflow `37377702786` auf `2449b8586f9dc784f8ea4c02256e6ed4916c044a`: **PASS**.
  - Static project validator: PASS.
  - Godot 4.6.3 Import / GDScript- und Shader-Parse: PASS, einschließlich des neuen Zauberwald-Codes und des neuen Showcase-Skripts.
  - Track geometry contract: PASS.
  - Kart physics regression: PASS.
  - Xvfb-Fold-/Pause-Layoutregression: PASS.
  - Bestehende Sonnenhafen-/Himmelsinseln-Runtime-Captures: PASS.
- Eigenständiger Zauberwald-Runtime-Capture: **SKIP** – der neue Showcase-Harness ist noch nicht im bestehenden Workflow-Capture-Schritt aufgerufen.
- Physisches Fold-Gerät, reales Android-Gerät und FPS-Messung: **SKIP** – nicht ausgeführt.

### Integrationsgrenze

- PR #18 bleibt offen und mergebar; der Branch ist gegenüber `integration/lumo-kart-opus-tracks-2026-10-05` weiterhin divergiert und liegt 1 Commit hinter der Base.
- `lumo-lernen` PR #197 pinnt weiterhin `a369da2dc208fcd9d5451c7007d8b1f9e7bf52a1` und damit einen älteren Godot-Stand. Vor einer neuen APK muss der freigegebene PR-#18-SHA bewusst gepinnt und die Provenienz erneut geprüft werden.
- Nächster begrenzter Welt-Ausbau: `holo_city` oder die nächste noch nicht auf Referenzqualität gebrachte Welt; weiter weltweise statt als gleichzeitiger Zehn-Welten-Umbau.


## Etappe 7 – Holo City Referenzqualitäts-Pass

- Agent: ChatGPT, direkt auf PR #18 / `chatgpt/kart-himmelsinseln-stage2-2026-10-05`.
- Ausgangs-Head: `8ea903e3ef2398bd761ee23039e78c3db89a6808`.
- Keine offenen Review-Threads oder fremden Claims auf diesem Produktblock.

### Direkt umgesetzt

1. **Stadt dichter und lesbarer**
   - höherer Tower-Dichtegrad im High-Detail-Profil;
   - vorhandene Glas-/Neon-Sprache bleibt erhalten;
   - zusätzliche Fahrbahn-Lichtmarkierungen in Cyan/Violett.

2. **Neue große Setpieces**
   - `NOVA-LINK` und `AURORA-LINK` als hoch liegende Skybridges;
   - `LUMO NEXUS` und `STAR CORE` als hohe Landmark-Spire mit Leuchtringen;
   - Billboard-Canyon und zusätzliche Transit-Beacons;
   - vorhandene Holo-Gates bleiben erhalten.

3. **Echte Runtime-Abnahme**
   - neuer `kart_holo_city_showcase.gd` mit sechs reproduzierbaren Kamerapositionen;
   - Stage-2-Workflow erfasst jetzt Sonnenhafen, Himmelsinseln, Zauberwald und Holo City als echte Godot-Runtime-PNGs.

4. **Vorbereitung auf mehr als vier Strecken**
   - Sternen-Cup-UI und Ergebnisanzeige beziehen die Rennanzahl jetzt aus `CATALOG.TRACKS.size()`;
   - Garage erzeugt die Cup-Streckenfolge dynamisch aus dem Track-Katalog;
   - `kart_modes_regression.gd` skaliert mit der tatsächlichen Track-Anzahl;
   - eigener CI-Schritt für den dynamischen Cup-Flow ergänzt.

### Validierung

- Workflow `37418699124` auf Head `7e860234fa9d3e0d511f3a4a43fb8487c6de9d5d`: **PASS**.
  - Static project validator: PASS.
  - Godot 4.6.3 Import / GDScript- und Shader-Parse: PASS.
  - Track geometry contract: PASS.
  - Kart physics regression: PASS.
  - Kart mode + dynamischer Cup: PASS.
  - Xvfb-Fold-/Pause-Layoutregression: PASS.
  - Runtime-Captures aller vier aktuellen Welten: PASS.
- Physisches Fold-Gerät / Android-FPS: weiterhin **SKIP** – nicht behauptet.

### Nächster unbeanspruchter Produktblock

Die bestehende Vier-Strecken-Basis ist jetzt technisch auf einen größeren Track-Katalog vorbereitet. Nächster Schritt: die fünfte eigenständige Welt aus den vorhandenen Referenzpaketen als vollständige Fahrstrecke anlegen, statt weitere harte Vier-Welten-Annahmen einzubauen. Favorisierte Reihenfolge: Crystal Canyon / Kristall-Canyon zuerst, danach Vulkan, Wüste, Galaxy, Candy/Cloud und Learning-Lab – jeweils weltweise mit Runtime-Capture und Regression.


## Etappe 8 – strukturierte Track-Developer-Packs und Sky-Halo-Authoring-Prototyp

- Ausgangs-Head: `9f20f3e94cc1607f9668f674185a982ffed3ceba`.
- Verbindliche Produktgrenze: `docs/track_expansion/2026-10-06/TRACK_DEVELOPER_PACK_SPEC.md`.
- Scope: vier vorhandene Katalogstrecken; keine alternative Spline-/Streckenarchitektur und keine Aktivierung von Inversionsphysik.

### Developer-Packs

`docs/track_expansion/2026-10-06/packs/` enthält je eine maschinenlesbare JSON-Quelle für Sonnenhafen, Zauberwald, Himmelsinseln und Hologramm-City plus Manifest. Die Packs enthalten:

- **130 / 120 / 120 / 122** einzeln benannte, überprüfbare Details in Katalogreihenfolge;
- jeweils genau **48** definierte Views mit 32 Orbitwinkeln, vier Orthographic-, vier Driver-, zwei Signature-, zwei Loop- und vier Debug-/Spezialansichten;
- die originalen Control-Point-Koordinaten aus `kart_tracks.gd`, Runtime-Samplingregeln, 10,8-m-Fahrbahnbreite, Rail-/Wall-Maße, acht Checkpoint-Anker, zehn KI-Linienanker, Setpiece-Status, Material-/Performance-/Collision-QA und Mystery-Prism-Zonen;
- ausschließlich die Core-Items `boost`, `shield` und `pulse` sowie die in der Spec festgehaltenen positionsabhängigen Fairnessgewichte.

`tools/validate_track_packs.py` prüft JSON, Control-Point-Abgleich, Mindestzahlen, eindeutige IDs, View-Verteilung, Mystery-Item-Vertrag und Loop-Sperre. Letzter lokaler Lauf: alle vier Packs und der Sky-Halo-Sicherheitsvertrag **PASS**; `python3 tools/validate_project.py`: **117 PASS / 7 WARN / 0 FAIL**.

### Sky Halo

- `scenes/games/track_authoring/sky_halo_loop_authoring.tscn` und `scripts/games/authoring/sky_halo_loop_authoring.gd` erzeugen einen 360°-Mesh-Prototyp auf Basis eines 12-m-Mittelradius, 10,8-m-Fahrbahnbreite und 96 Segmenten.
- Das Authoring-Szeneobjekt markiert sich als nicht befahrbar, enthält keine Physics-Collider und wird von `kart_world.gd` nicht geladen. Es ersetzt keine bestehende Himmelsinseln-Spline.
- Die vier Loopings bleiben `planned_requires_inverted_physics`; Gravitation/Up-Vektor, Kamera, KI, Collision, Checkpoint/Respawn und kompletter Player-/AI-Lauf sind nicht als bestanden behauptet.

### Noch nicht validiert

- Godot-Import/Parser, Laufzeitdarstellung des Sky-Halo-Meshes und vollständige Player-/AI-/Respawn-/Reverse-/Checkpoint-Läufe: **SKIP**, bis der aktuelle PR-Head im Godot-Workflow geprüft ist.
- Runtime-Captures des neuen Authoring-Prototyps: **SKIP**; er ist absichtlich kein Runtime-Rennsetpiece.
- Kein Fold-Gerätetest, keine FPS-Messung und kein Merge nach `main`.
