# Sonnenhafen – erste neue Stadtregion von LUMO WORLD (Team C1/C2, 26.11.2026)

Hafenstadt südlich des Festlands (x 80–266, z −112…−176), über die **Sonnenbrücke**
(Straße, x≈200) und den **Fischersteg** (Fußweg, x≈118) mit der bestehenden Welt
verbunden; vom Hauptweg führt der **Hafenweg** (x≈203) hinunter, daneben der
**Kart-Parkplatz Sonnenhafen**. Bestehende Orte, Missionen und Spielstände bleiben
unverändert (Spielstand-Abschnitt `sonnenhafen`, ältere Stände starten die Region frisch).

## Bausteine
| Teil | Datei |
|---|---|
| Baukasten (Blender, 71 Module, gemeinsamer Dorf-Atlas 1024 px, Godot-LODs) | `tools/lumo_world_art/build_sonnenhafen_kit.py` → `assets/creative/lumo_world/sonnenhafen/kit/` |
| Stadtplan (Reihen, Wahrzeichen, Innenräume, Wege, Spots) | `assets/creative/lumo_world/sonnenhafen/sonnenhafen_layout.json`, `scripts/creative/lumo_world_sonnenhafen_layout.gd` |
| Stadtbau (MultiMesh je Modul und Stadtviertel, Kollision, Wasserkanten, Navmesh) | `scripts/creative/lumo_world_sonnenhafen_town.gd` |
| Bewohner (14, Persönlichkeit, Wohnort, Beruf, Interessen, Beziehungen, Tagesplan) | `assets/creative/lumo_world/sonnenhafen/sonnenhafen_residents.json` |
| NPC-Gehirn (Utility-KI + Zustandsautomat, Erinnerung, Klatsch, Begrüßung) | `scripts/creative/lumo_world_npc_brain.gd` |
| NPC-Körper (NavigationAgent3D mit Ausweichen nah, Polyline fern, Animation) | `scripts/creative/lumo_world_npc_crowd.gd` |
| Region (Missionen, Laden, Kontor, Fischkisten, Lernrunde, Abendlicht, Karte, Journal) | `scripts/creative/lumo_world_sonnenhafen.gd` |
| Missionen (gleiches Schema wie `open_world_content.json`) | `assets/creative/lumo_world/sonnenhafen/sonnenhafen_quests.json` |

Kleine, gezielte Änderungen an gemeinsamen Dateien: `lumo_world.gd` (Region einhängen,
Speichern, Aktionen, HUD, Karte, Journal, Lernquittung), `lumo_world_map.gd`
(Regionsflächen, Regionsfiguren, Ortsname), `lumo_world_quests.gd` (Figurenquelle
`resident`, Schrittart `event`), `build_village_art.gd` (`bundle_at()` für Kit-Modelle).

## Spielinhalt
- Betretbar mit Mechanik: **Hafenkrämer** (Handel mit Muscheln – Spielmünzen, kein echtes
  Geld; Rechnung wird angezeigt) und **Kontor im Speicher** (Lieferbrett, 8 wiederkehrende
  Lieferaufträge mit Adresse zum Lesen). Dach und Obergeschoss werden innen ausgeblendet.
- Offene **Fischhalle** (Kisten abstellen), Markt mit Ständen und Brunnen, Piers mit
  Booten, Mole mit Leuchtturm, Kran, Netzgestelle.
- Fünf Aufträge: *Willkommen in Sonnenhafen* (Ida), *Frischer Fang* (Jonte, Frieda),
  *Waren berechnen* (Greta, **Lernmission** über den bestehenden Lern-Anschluss
  `school_numbers`/„Lumos Weltschule“ + klassenstufengerechte Preisrechnung),
  *Licht für den Leuchtturm* (Ole, Kauf im Laden), *Die erste Lieferung* (Hinnerk).
  Belohnung: Muscheln, Gegenstände, fünf Figurenkarten; jede Belohnung genau einmal.

## NPC-Verhalten
Tagesuhr = bestehende World-Routinen (720 s = 8–22 Uhr, vier Phasen). Bewohner wählen
Tätigkeiten nach Gewicht, Persönlichkeit, Abwechslung (zuletzt besuchte Orte zählen
weniger) und Entfernung, plaudern mit Freunden (Sprechblasen, Neuigkeiten über Lumo
werden weitererzählt), grüßen Lumo (mit Erinnerung) und gehen abends durch ihre eigene
Haustür nach Hause. Jede Figur ist als „Computerfigur“ beschriftet; alles lokal.
Gehfiguren: nur Dorf-Figuren mit echtem `Walk`-Clip (Hase, Biber, Ente) und
Gliederfiguren mit Schwunggelenken (Löwe, Mensch). **Sitzende Kart-Rigs werden nie als
Gehfiguren verwendet.** Sobald Team B2 echte Geh-/Laufzyklen für die Rivalen liefert,
können weitere Körper in `sonnenhafen_residents.json → bodies` eingetragen werden;
`lumo_world_npc_crowd.gd` erkennt jeden Clip, dessen Name mit „walk“ beginnt.

## Leistung / Grafikstufen
Ein Material für die ganze Stadt, Module als MultiMesh je Viertel (≈175 Stapel),
Sichtweiten je Modulklasse; LOW lässt reine Zierteile weg und verkürzt Sichtweiten,
vier Marktlichter (OmniLight) nur auf HIGH, animierte Figuren je Stufe 6/10/14, ferne Figuren ohne
Ausweichen und Animation. Keine Gerätemessung (Fold7) in dieser Etappe.

## Prüfen
```
godot --headless --path . --script res://scripts/tests/lumo_world_sonnenhafen_npc_regression.gd
godot --headless --path . --script res://scripts/tests/lumo_world_sonnenhafen_mission_regression.gd
godot --headless --path . --script res://scripts/tests/lumo_world_sonnenhafen_save_regression.gd
xvfb-run -a -s '-screen 0 2560x2560x24' godot --path . --rendering-method gl_compatibility \
  --audio-driver Dummy --script res://scripts/tests/lumo_world_sonnenhafen_capture.gd -- --out=<dir>
/home/user/tools/bpyenv/bin/python tools/lumo_world_art/build_sonnenhafen_kit.py   # Kit neu bauen
```
Neue Bewohner: Eintrag in `sonnenhafen_residents.json` (Spots aus dem Layout, Zuhause
`<reihe>:<index>`). Neue Aufträge: `sonnenhafen_quests.json` (Schritte `talk`, `visit`,
`drive`, `event`; Ereignisse: `fish_crates_done`, `harbour_lesson_done`,
`bought_<ware>`, `delivery_done`; `requiresItem` verlangt einen Gegenstand).
