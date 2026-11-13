# Godot-Integrationsinventur — 13. November 2026

Zeitpunkt: 12:42 UTC / 13:42 Europe/Vienna. Zuständigkeit: ausschließlich Integration und Reparatur. Keine Produktdatei wurde durch diese Inventur geändert.

## Tatsächliche Ausgangsbasis

- Repository: [Ullmann27/lumo-godot](https://github.com/Ullmann27/lumo-godot).
- [PR #157](https://github.com/Ullmann27/lumo-godot/pull/157), offener Draft: `chatgpt/lumo-nextgen-20261113` an `ada5ed81ad62339f15289da62670c0a4f9f7f2b9`.
- Basis von PR #157: `chatgpt/lumo-action-stage-20261112` an `1d5c5cb45a323228f627ec529e6ff1ddd86f1c57` (PR #156).
- Integrationsarbeitsbereich dieses Teams: `integration/lumo-connections-20261113`, angelegt vom Hauptagenten auf ada5ed81. Hauptbranch und fremde aktive Arbeitsbäume werden nicht verändert.
- Native Quellstand und Flutter-Pin sind getrennt zu prüfen. Eine grüne Native-Suite beweist keine fertig abgenommene APK.

## Abdeckung und Methode

Live gelesen wurden Metadaten und HEAD-SHAs von **30 älteren/relevanten PRs** sowie PR #157. Für jeden der 30 wurde GitHubs Commitvergleich vom exakten Quell-HEAD nach ada5ed81 aufgerufen. Bei abweichender Historie wurde der eindeutige Dateisatz zwischen Mergebase und Quell-HEAD geprüft. Produktpfade und vorhandene Gate-Anschlüsse wurden im zugewiesenen Integrationsbaum gelesen. Die wichtigsten Integrationstage sind10.–13. November; ausgewählte ältere Vorläufer vom3.–6. November sind zusätzlich enthalten.

Zusätzlich wurden zwei Seiten des Branch-Verzeichnisses und die aktuelle Suche nach 20261113-Zweigen gelesen. Dies ist **keine vollständige Inhaltsabnahme aller historischen Oktoberzweige**. Eine offene PR, ein divergierter Commitgraph oder ein alter grüner Workflow ist allein kein Beweis für fehlenden Produktcode oder aktuelle Integrationsreife. Selektiv portierte Inhalte besitzen teilweise keine durchgängige Commit-Abstammung.

Der Vergleich in der Tabelle beschreibt stets den heutigen Native-Stand relativ zum alten PR-HEAD: `ahead` und 0 hinter bedeuten vollständige Abstammung; `diverged` erfordert Inhaltsprüfung. Die Zahlen zählen Commits, keine Funktionen.

## Live-Inventur

| Quelle | Quellzweig | Exakter Quell-HEAD | Verhältnis heute | Integrationsentscheidung |
|---|---|---|---|---|
| [#121](https://github.com/Ullmann27/lumo-godot/pull/121) | `feat/sonnenhafen-physics-ramp-mainline-loop-20261103` | `820742f4d2652ecd08f0addc1710381e8975214b` | diverged, +161/−14 | Nachfolger im aktuellen Stunt-/Ballistikpfad; alter Gesamtzweig ist kein geeigneter Merge. Kein isolierter fehlender Fix nachgewiesen. |
| [#122](https://github.com/Ullmann27/lumo-godot/pull/122) | `feat/lumo-65bone-grounded-walk-20261103` | `8e742ad49ca35aea70cbe810efb58d9f98b70e6d` | diverged, +161/−6 | Original-Rig-/Walk-Pfad und zugehöriges aktuelles Nextgen-Gate vorhanden; keinen alten Actor überschreiben. |
| [#124](https://github.com/Ullmann27/lumo-godot/pull/124) | `grok/lumo-gait-cycle2` | `372937e6a48fd87358378df396f4000f236954eb` | diverged, +161/−2 | Gait-Modul und Hauptsuite vorhanden; alte Jump-Datei würde neuere Nextgen-Steuerung zurücksetzen. |
| [#125](https://github.com/Ullmann27/lumo-godot/pull/125) | `grok/sonnenhafen-jump-cycle1` | `1300b0097beff18188109f195b7d743853085306` | ahead, +149/−0 | Vollständiger Vorfahr des aktuellen Native-Stands; keine erneute Übernahme. |
| [#126](https://github.com/Ullmann27/lumo-godot/pull/126) | `grok/lumo-renderkit-cycle3` | `3af44ad2f708faa304cb9795b740e27e0c1c648b` | diverged, +161/−5 | RenderKit-Module und Hauptsuite vorhanden; alte Jump-/Kart-Dateien nicht übernehmen. |
| [#127](https://github.com/Ullmann27/lumo-godot/pull/127) | `chatgpt/lumo-all-games-integration-20261103` | `91b8cdba48d539ba48836bfac5f6b62c0d6cfa41` | ahead, +138/−0 | Vollständiger Vorfahr des aktuellen Native-Stands; keine erneute Übernahme. |
| [#128](https://github.com/Ullmann27/lumo-godot/pull/128) | `chatgpt/lumo-original-fox-jump-20261103` | `bc1f61338fb1e1be3311bf4c229a8fc09487e904` | ahead, +135/−0 | Vollständiger Vorfahr des aktuellen Native-Stands; keine erneute Übernahme. |
| [#129](https://github.com/Ullmann27/lumo-godot/pull/129) | `integration/lumo-2006-native-20261103` | `a81ddf12d594cc252caef7503162e89c6b26e1c7` | ahead, +132/−0 | Vollständiger Vorfahr des aktuellen Native-Stands; keine erneute Übernahme. |
| [#130](https://github.com/Ullmann27/lumo-godot/pull/130) | `grok/lumo-bauplan` | `c2e5161d099a2107f8cd4964dc8a873f5284c05c` | diverged, +132/−1 | Einziger Rest ist BAUPLAN_AUSGANGSLAGE.md; kein Produktcode. |
| [#131](https://github.com/Ullmann27/lumo-godot/pull/131) | `assist/lumo-kart-support-team-20261104` | `25cf93ca35b89835abdd7d2e57b61f887dbbbd89` | ahead, +127/−0 | Vollständiger Vorfahr des aktuellen Native-Stands; keine erneute Übernahme. |
| [#133](https://github.com/Ullmann27/lumo-godot/pull/133) | `lumo-next/design-worlds-20261110` | `bff06fbe02705458c4999ec6ef5f94646c33c9bd` | ahead, +127/−0 | Vollständiger Vorfahr des aktuellen Native-Stands; keine erneute Übernahme. |
| [#134](https://github.com/Ullmann27/lumo-godot/pull/134) | `lumo-next/kart-integration-20261110` | `8c1bf1ddcdc9a2c311c87ad49326bbf4c1af0aa5` | ahead, +113/−0 | Vollständiger Vorfahr des aktuellen Native-Stands; keine erneute Übernahme. |
| [#135](https://github.com/Ullmann27/lumo-godot/pull/135) | `lumo-next/godot-integration-20261110` | `9947346ecc526512904adecec1815312020beb62` | ahead, +75/−0 | Vollständiger Vorfahr des aktuellen Native-Stands; keine erneute Übernahme. |
| [#136](https://github.com/Ullmann27/lumo-godot/pull/136) | `lumo-next/eleven-tracks-20261110` | `e46262c7876c377d649d21439ba644f1df033a43` | ahead, +77/−0 | Vollständiger Vorfahr des aktuellen Native-Stands; keine erneute Übernahme. |
| [#137](https://github.com/Ullmann27/lumo-godot/pull/137) | `lumo-next/game-identity-2013-20261110` | `568b0df09dff233df3fc2de837590d2fdf452fca` | ahead, +69/−0 | Vollständiger Vorfahr des aktuellen Native-Stands; keine erneute Übernahme. |
| [#138](https://github.com/Ullmann27/lumo-godot/pull/138) | `lumo-2013/guard-ci-20261110` | `0f74baed12fdc520b507ff60d426f5c20b3e3790` | diverged, +68/−1 | Einziger Rest sind drei historische Cover-PNGs; keine Abnahme als Verbesserung gegenüber heutigen Bildern. |
| [#139](https://github.com/Ullmann27/lumo-godot/pull/139) | `lumo-2013/integration-20261110` | `47bef06db45d61d50ecd06d0b0cd0a69b9a25917` | ahead, +51/−0 | Vollständiger Vorfahr des aktuellen Native-Stands; keine erneute Übernahme. |
| [#140](https://github.com/Ullmann27/lumo-godot/pull/140) | `lumo-2013/bauwelt-20261110` | `fe493ea1d9e44e20ca87fbd3ffbae3bb1f658878` | ahead, +66/−0 | Vollständiger Vorfahr des aktuellen Native-Stands; keine erneute Übernahme. |
| [#141](https://github.com/Ullmann27/lumo-godot/pull/141) | `lumo-2013/creative-godot-20261110` | `74fa4d1631a2903f61bb112e5ba6a6399be64612` | diverged, +64/−1 | Einziger Rest ist TEST_RESULTS.md; spätere Reparaturlinie #148 ist Vorfahr. |
| [#142](https://github.com/Ullmann27/lumo-godot/pull/142) | `lumo-2013/guard-flakes-20261110` | `3968a1cf42def7666ea469b06f62523ab758bdd1` | ahead, +68/−0 | Vollständiger Vorfahr des aktuellen Native-Stands; keine erneute Übernahme. |
| [#143](https://github.com/Ullmann27/lumo-godot/pull/143) | `lumo-2013/jump-20261110` | `74f358d639f66f8419f45edad2da667a5d54cc84` | diverged, +69/−1 | Produktinhalt selektiv übernommen und durch heutige Jump-Expeditionen erweitert; Gate validate_2014.sh/jump_extras_regression. |
| [#144](https://github.com/Ullmann27/lumo-godot/pull/144) | `lumo-2013/bauwelt-sandbox-20261110` | `b5da336b2a0e24c5e0af102f32b9d566591a5c83` | diverged, +66/−11 | Füllen/Kopieren/Spiegeln/Undo samt UI übernommen; beide Sandbox-Gates in validate_2014.sh. PR-Text über leeren Checkpoint ist veraltet. |
| [#145](https://github.com/Ullmann27/lumo-godot/pull/145) | `lumo-2013/puzzle-20261110` | `284925e979c070fc495bd6529f2635e4d5ac2d4c` | diverged, +69/−1 | Atelier/Motive/Teilzahlen übernommen; puzzle_expansion_regression in validate_2014.sh. |
| [#146](https://github.com/Ullmann27/lumo-godot/pull/146) | `lumo-2013/kart-menu-20261110` | `9b150498503c2628d025674a2329557450793f1a` | diverged, +69/−1 | Garage selektiv in 2014, Lufttricks in #155 übernommen; Touch-/AirTrick-Gates vorhanden. Altes Fünf-Schritt-Menü nicht wiederherstellen. |
| [#148](https://github.com/Ullmann27/lumo-godot/pull/148) | `lumo-2013/creative-repair-20261110` | `7de43014f7a8983ac79aa1d9ba85a152fec4b79b` | ahead, +52/−0 | Vollständiger Vorfahr des aktuellen Native-Stands; keine erneute Übernahme. |
| [#150](https://github.com/Ullmann27/lumo-godot/pull/150) | `lumo-2014/integration-20261110` | `207bfbc5377c0f3e8be800854c83ddf2110ac3f6` | ahead, +30/−0 | Vollständiger Vorfahr des aktuellen Native-Stands; keine erneute Übernahme. |
| [#151](https://github.com/Ullmann27/lumo-godot/pull/151) | `lumo-2014/kart-geometry-20261110` | `a632ee9d415cfff8d3c5d6d76c0aa9cf6b09fb3d` | diverged, +51/−4 | Physischer Loop/Rivalenflug übernommen und später erweitert; drei passende Gates in validate_2014.sh. |
| [#152](https://github.com/Ullmann27/lumo-godot/pull/152) | `chatgpt/lumo-technical-art-20261111` | `e885b145c500da3db979c33b437c0432891be3ad` | diverged, +26/−4 | Produktstand b357b2f8 ist gemeinsamer Vorfahr; vier spätere Commits enthalten historische Nachweise und zwei Capture-Skripte, keinen fehlenden Gameplay-Fix. |
| [#155](https://github.com/Ullmann27/lumo-godot/pull/155) | `chatgpt/lumo-2016-gameplay-effects-20261111` | `b4ccf593d7833e8c259ff0f963494b00d245d03d` | ahead, +25/−0 | Vollständiger Vorfahr des aktuellen Native-Stands; keine erneute Übernahme. |
| [#156](https://github.com/Ullmann27/lumo-godot/pull/156) | `chatgpt/lumo-action-stage-20261112` | `1d5c5cb45a323228f627ec529e6ff1ddd86f1c57` | ahead, +14/−0 | Vollständiger Vorfahr des aktuellen Native-Stands; keine erneute Übernahme. |

## Nachgewiesene aktuelle Prüflaufanschlüsse

Folgende Anschlüsse wurden im aktuellen Dateibaum direkt gelesen:

- `tools/validate_2014.sh`: `kart_loop_contact_regression`, `kart_stunt_continuity_regression`, `kart_rival_flight_regression`, `jump_extras_regression`, `build_sandbox_tools_regression`, `build_sandbox_ui_regression`, `puzzle_expansion_regression`, `kart_garage_3d_touch_regression`.
- `tools/validate_technical_art.sh`: `kart_air_trick_regression`.
- `tools/validate_project.sh`: `lumo_gait_regression` und `lumo_renderkit_regression`.
- `tools/validate_nextgen.sh`: `lumo_65bone_walk_gait_regression`.

Die Auswahl beantwortet die konkrete Frage, ob die historischen Arbeiten #143–146/#151 sowie Walk/RenderKit noch unverbunden herumliegen. Ihre hier genannten Produktteile und Tests sind bereits verbunden. Die dokumentierten Portierungen stehen in `docs/reports/LUMO_2014_OTHER_GAMES_20261110.md`, `docs/development/LUMO_2016_GAMEPLAY_EFFECTS_20261111.md`, `docs/NEXTGEN_BAUWELT_20261113.md` und `docs/NEXTGEN_JUMP_20261113.md`. Diese alten Berichte wurden gegen die aktuellen Datei-/Gate-Anschlüsse gelesen und nicht als neue Testausführung ausgegeben.

## Frischer CI-Status

Für exakten Commit ada5ed81 liefert `fetch_commit_workflow_runs` derzeit 14 PR-Workflows, alle `completed/success`. Der Connector liefert PR-getriggerte Läufe und nur seine erste Seite; daraus wird keine Vollständigkeit sämtlicher Repository-Läufe abgeleitet.

Der wesentliche [Native-Abnahmelauf 43399721309](https://github.com/Ullmann27/lumo-godot/actions/runs/43399721309) ist laut Live-Abfrage inzwischen erfolgreich. Seine drei Jobketten sind vollständig `success`:

| Job | Kennung | Ergebnis |
|---|---|---|
| learning-preview |131799274058|success|
| gameplay |131799274407|success|
| new-worlds |131799274636|success|

Die Beschreibung von PR #157 nennt den Lauf noch als laufend; diese Statusangabe ist veraltet. Die Abfrage des klassischen CombinedStatus ergibt eine leere Statusliste, nicht einen fehlgeschlagenen Test. In dieser Inventur wurden keine neuen lokalen Spieltests oder Bildabnahmen ausgeführt und keine historischen Renderbilder als aktuelle Nachweise ausgegeben.

## Laufende Entwicklungsteams und Übernahmepunkt

- Studio-Team: im gemeinsamen Workspace unter `/workspace/scratch/5987865ae883/lumo-godot`, Zweig `chatgpt/lumo-studio-20261113`. Derselbe Zweig existiert jetzt remote. GitHub-Compare gegen ada5ed81 ergab zum Abfragezeitpunkt **identical**,0/0 Commits und 0 Dateien; Suche nach einer PR dieses Heads ergab keinen Treffer. Es lag damit noch kein neuer veröffentlichter Produkt-Delta zur Übernahme vor.
- Grafik-Team: im gemeinsamen Workspace unter `/workspace/scratch/777ac99b0ad0/lumo-godot`, Zweig `chatgpt/lumo-graphics-expansion-20261113`, lokaler HEAD ada5ed81 bei erster Sichtung. Die aktuelle GitHub-Branchsuche zeigte diesen Zweig noch nicht. Ungesicherte Änderungen wurden nicht kopiert.
- Die Teamstandorte sind beobachtete Arbeitsbereiche, kein Beweis für laufende Prozesse oder Liefertermine. Neue übergebene exakte Commit-SHAs müssen erneut auf Änderungen, Abhängigkeiten und bestandene aktuelle Tests geprüft werden, bevor sie in den Integrationszweig gelangen.

## Ergebnis und nächste Übernahme

Im konkret geprüften Satz wurde **noch kein fehlender fertiger Gameplay-Anschluss belegt**, der eine zusätzliche Produktänderung rechtfertigt. Die ehemaligen WIP-Zweige #143–146 sind wesentliche Beispiele für bereits portierte Arbeit mit inzwischen veralteter PR-Beschreibung. Ein Gesamtmerge würde alte Menüs/Controller gegen neuere produktive Varianten ausspielen.

Übernahmebereit ist die bereits veröffentlichte Nativebasis ada5ed81 mit ihrem grünen Native-Lauf; die tatsächliche Host-Anbindung, APK-Abnahme und laufende Recovery besitzt der Flutter-/Integrationsstrom. Neue Studio-/Grafik-Lieferungen werden erst nach veröffentlichtem Quellenstand übernommen. PRs bleiben erhalten; kein Main-Merge, kein Force-Push, keine fremden Branchänderungen und keine Behauptung einer physischen Fold7-/60-FPS-Abnahme.
