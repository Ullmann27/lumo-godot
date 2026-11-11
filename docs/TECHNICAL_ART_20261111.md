# LUMO Technical Art — 11. November 2026

## Arbeitsbasis und Status

**WIP: Ausgangsaufnahmen gesichert, Umsetzung läuft. Kein APK-/Geräteerfolg behauptet.**

Aktuell neu gelesen: Godot PR #150 `207bfbc5377c0f3e8be800854c83ddf2110ac3f6`,
Flutter PR #451 `696db258693465acfc27d051c9c0874710ac9046`. Beide Integrations-PRs
sind offen und unverändert. Die Default-Branches stammen vom 16. Oktober;
sie sind keine neuere integrierte Basis. Godot PR #151 ist ein älterer,
konfliktbehafteter Geometrie-Arbeitszweig, kein neuerer abgenommener Kandidat.
Die frische Branch-Inventur wurde vor Änderungen durchgeführt.

Godot 4.6.3; Flutter-CI 3.44.9. Bestehende Architektur, Paketkennung,
Speicherformate und Engine-Version bleiben erhalten.

## Gelesene Originalquellen

- `Lumo_Referenzmappe_2026-11-03.pdf`, zugängliches Drive-Original
  `1bQuAZdoaTk-wCuo5oTfuCt2WDMVhi-R_`; 75.905.897 Bytes,
  SHA-256 `d29b4e3709765eb7f179bf7094bc2a3a088cd2428760195780544d99a59b636c`.
  Tatsächlich visuell geprüft: Seite 10 (Figur), 16 und 17 (Sonnenhafen).
- Bestehende Garagenreferenzen im Flutter-Repository:
  `docs/design/2026-10-10-lumo-games/references/50294.png` und
  `docs/design_targets/2026-10-04/kart/k01_garage.png`.
- Tatsächlich ausgeliefertes Originalmodell
  `assets/characters/lumo_animated/Lumo-Animated-Mobile.glb`, SHA-256
  `3559f700784bc1006905ee3aae01e8bcfbffb95b4f621f7430ce771ba0e3efd5`:
  65 Knochen, neun Clips, keine Morph Targets, keine Augen-/Kieferknochen.

Die Mappe enthält generierte Designreferenzen. Diese werden ausdrücklich nicht
als implementierte Spielgrafik ausgegeben. Das ausgelieferte Originalmodell
trägt einen Rennanzug; es wird nicht stillschweigend durch die Konzeptfigur ersetzt.
Kein kostenpflichtiger Dienst und kein neues fremdes Asset wird verwendet.

## Vergleichsmatrix

| Bereich | Zustand in 2014 | Originalreferenz | Konkrete Umsetzung (in Arbeit) | Nachweis |
|---|---|---|---|---|
| Sonnenhafen-Startviertel | Ausgearbeitete Schauseiten überwiegend längs orientiert; Straßenflanken flach | S. 16–17: warme Putzfassaden, Steinbögen, Balkone, blau/creme Markisen | Wiederverwendbares Fassadenset an vorhandenen Grundrissen, zur Straße orientiert; begrenzte Instanzen und klare Materialunterschiede | Echte Ausgangsbilder `before/harbor`; geplante identische Rennkamerapositionen 18/60/110/160 m |
| Garage | Echter 3D-Raum, sehr dunkler Boden, flache Wand-/Werkstattelemente; Kamerasprünge | Vorhandene Garagenbilder: Marineblau, helle Tragstruktur, warmer Raum, Cyan am Drehteller | Modellierter Werkstattplatz und ruhige Kamerafahrt; tatsächliche große Projektionstreffer; Auswahlreaktion auf neuer Figur | Echte `before/garage`-Bilder; vorhandene Touch-/Layoutprüfungen bleiben |
| Original-Lumo | Vorhandene neun Clips; Sitzpose statisch; Auswahl-Nicken wird bei Kartwechsel verworfen | S. 10 und vorhandenes GLB: orange/weiß, blaue Brille, originale Silhouette | Dezentes Sitzen/Atmen, begrenzter Blick, einmaliger Landungsimpuls auf vorhandenem Rig | Echte Originalaufnahmen `before/lumo`; neue und bestehende Rig-/Kontaktprüfungen |

## Dateizuständigkeiten

| Verantwortlicher | Schreibbereich |
|---|---|
| Sonnenhafen-Agent | `kart_sonnenhafen_generation.gd`, neues Straßenfassadenset, eigene Regressionen/Dokumentation |
| Garage-Agent | `kart_garage_interior.gd`, `kart_garage_menu.gd`, eigene Regressionen/Dokumentation |
| Lumo-Agent | `lumo_kart_animation_adapter.gd`, eigene Regressionen/Captures/Dokumentation |
| Hauptintegrator | Gemeinsame Anschlussstellen, Vergleichsaufnahmen, Fahr-/Integrationstests, Dokumentation, Flutter-Pin und PRs |

Alle drei Agenten wurden tatsächlich gestartet und arbeiten in getrennten
Git-Worktrees. Keine fremden Branches werden überschrieben; kein Force-Push,
kein Merge nach main.

## Nachweisgrenzen

Ausgangsaufnahmen: tatsächlicher Godot-Renderer, Linux x86_64, Mesa llvmpipe
(Software-OpenGL), Xorg, Godot 4.6.3. Details und Dateihashes in
`docs/evidence/technical-art-20261111/before/manifest.json`.

Die neue `kart_technical_art_capture.gd` verwendet die Produktionsszene und
`_update_camera()` mit fest gesetzten Vergleichspositionen. Das ist ein
reproduzierbarer Bildvergleich, keine vorgetäuschte Fahrprüfung. Die separate
unveränderte `kart_player_full_route_regression.gd` prüft echte Steuereingaben,
zwei vollständige Runden, Loopings, Rampen und Checkpoints.

| Abnahme | Stand bei diesem Checkpoint |
|---|---|
| Ausgangsbilder im tatsächlichen Renderer | PASS |
| Original-Rig-Aufnahme und 34 bestehende Assertions | PASS |
| Neue Produktänderungen integriert | IN ARBEIT |
| Neue vollständige Fahr-/Garage-Regressionen | AUSSTEHEND |
| Android-Emulator für neue Änderungen | NOT RUN |
| Physisches Android/Fold7, FPS, Temperatur, RAM | NOT RUN |
| Neue APK/Veröffentlichung | NICHT ERSTELLT |

Die 2014-CI belegt ausschließlich den bisherigen Kandidaten, nicht die
kommenden Änderungen. Ergebnisse werden nach tatsächlicher Ausführung ergänzt.
