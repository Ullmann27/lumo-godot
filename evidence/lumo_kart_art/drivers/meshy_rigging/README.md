# Neun Meshy-Fahrer mit Körper- und Gesichtsrig

Stand: 24. November 2026. Auftrag: die noch ungeriggten Lumo-Fahrer mit Skeletten ausstatten.

## Ergebnis

Die neun erhaltenen Meshy-Originale aus `art/lumo_kart/meshy/20261123/drivers/` sind an die vorhandene Lumo-Fahrerschnittstelle gebunden. Jeder Fahrer besitzt ein Skin mit 26 Knochen, zwölf Animationen und drei explizite Detailstufen. Die produktiven Dateien stehen unter `assets/kart/production/drivers/<id>/`; die vorhandene Kart- und Karten-Rosterauflösung verwendet diese Pfade bereits.

Alle ursprünglichen Texturdreiecke und ihre UV-Konnektivität sind in LOD0 erhalten. Die Originaldateien und ihr Quellmanifest wurden nicht verändert. Ihr Ausgangszustand hatte jeweils null Skins und null Animationen; `meshy_original_rig_baseline.json` hält diesen erwarteten negativen Ausgangstest fest.

| Fahrer | ID | Dreiecke LOD0 | Dreiecke LOD1 | Dreiecke LOD2 |
| --- | --- | ---: | ---: | ---: |
| Löwe | lion | 24.073 | 16.367 | 12.515 |
| Eule | owl | 24.168 | 14.700 | 9.966 |
| Nova, Hase | rabbit | 23.548 | 14.736 | 10.331 |
| Eichhörnchen | squirrel | 24.141 | 15.394 | 11.020 |
| Schildkröte | turtle | 24.265 | 14.804 | 10.074 |
| Frosch | frog | 22.081 | 12.950 | 8.385 |
| Milo, Otter | otter | 24.166 | 15.368 | 10.970 |
| Dachs Bruno | badger | 24.174 | 14.675 | 9.927 |
| Mika, Katze | cat | 24.152 | 14.190 | 9.209 |

Die 27 GLBs umfassen zusammen 63.988.772 Bytes. Das ist die Größe der Quelldateien, keine gemessene APK-Größe oder Laufzeitspeicherbelegung.

## Skelett und Animationen

Das gemeinsame Rig umfasst Root, Pelvis, Spine, Chest, Neck, Head und Tail; je Seite UpperArm, Forearm, Hand, Thigh, Shin, Foot und Ear; außerdem Jaw, Eye.L/R und Lid.L/R. Nicht im Original dargestellte Anhänge behalten ungewichtete Kompatibilitätsknochen. Fremde Körperflächen werden diesen Knochen nicht zugeordnet.

Enthaltene Clips:

- `idle`, `kart_seated`, `kart_steer_left`, `kart_steer_right`, `kart_jump`;
- `celebrate`, `kart_celebrate`, `kart_hit`;
- `greeting_wave`, `agree_nod`, `point_portal`, `card_play`.

Jeder Clip enthält Translation, Quaternion-Rotation und Skalierung für alle 26 Knochen, also 78 Kanäle. Die bestehenden Importvorgaben behalten unveränderte Rücksetzspuren und verwenden die drei gelieferten LODs. Grip-, Foot-, Head-, Neck- und Seat-Marker bleiben mit der produktiven Sitz- und Lenkschnittstelle kompatibel.

Pro Vertex werden höchstens vier normalisierte Knochengewichte exportiert. Die Gewichte entstehen in der ursprünglichen A-Pose; anschließend wird das Originalmesh in den Sitz-Restzustand eingepasst. Die Gelenkübergänge sind entlang der jeweiligen Gliedmaßen begrenzt. Ein geometrischer Abstandstest verhindert, dass Hände auf Hüfthöhe den Beinen zugeordnet werden.

### Anatomische Sonderfälle

- Die Flügel der Eule folgen den Armketten.
- Die vollständigen Schweifflächen von Löwe, Otter und Eule wurden anhand der verschweißten Originaltopologie unterhalb eines gemessenen Ansatzschnitts ausgewählt. Am Ansatz wird ausschließlich zum Becken überblendet. Originale Schweifspitzen werden zusätzlich über ihre erhaltenen UVs auf falsche Beinzuordnung geprüft.
- Die getrennten Schwanzkomponenten von Hase und Eichhörnchen sitzen an ihren anatomisch angepassten Beckenankern.
- Der Schildkrötenpanzer hat einen einheitlichen Restzustand und einen starren Spine-Einfluss. Sein weicher Rand verbindet ihn mit dem Körper. Alle 2.506 Kernvertices sind zu 100 Prozent an Spine gebunden; 5.922 innere Originalkanten wurden über zwölf Clips mit jeweils neun Zeitpunkten auf Formstabilität geprüft.
- Getrennte Originalaugen sind an ihre tatsächlichen Augenkomponenten gebunden. Beim Otter bleibt die durchgehende Gesichtsfläche erhalten; die Blickrotation ist auf 0,045 Radiant begrenzt. Die Augenpositionen wurden gegen die ursprüngliche Textur und ihre UVs geprüft.
- Zusätzliche skinnbare Lidschalen mit einer feinen Lidfalte ermöglichen sichtbare Augenschlüsse. Die Katze verwendet eine angepasste Schließweite für ihre flachen Augenkomponenten.

## Texturen und Porträts

Die ursprünglichen UVs und Farbatlanten werden weiterverwendet. Die eingebetteten 2.048-Pixel-Texturen werden für die Laufzeit auf 1.024 × 1.024 Pixel verkleinert und neu als PNG gepackt. Der Export prüft die tatsächlichen eingebetteten Bildabmessungen; eine reine Blender-Anzeigeänderung reicht dafür nicht.

Pro GLB gibt es einen Originalatlas und drei Materialflächen: Originalmaterial, Lidfläche und Lidfalte. Rückseiten-Culling bleibt aktiviert. Alle neun transparenten Menüporträts werden aus diesen geriggten Figuren gerendert. Auch das Karten-HUD verwendet jetzt für alle neun Fahrer dieselben aktuellen Porträts.

Der bisherige pauschale 1,5-MiB-Dateitest bezog sich auf die früheren Figuren ohne eingebetteten Farbatlas. Die neue Prüfung trennt die Ressourcen: höchstens 2 MiB für Geometrie/Rig/Animation und höchstens 1,5 MiB für genau einen eingebetteten PNG-Atlas mit maximal 1.024 × 1.024 Pixeln. Dreiecks-, Knochen-, Clip-, Culling-, Kontakt- und LOD-Prüfungen bleiben erhalten. Die größte Datei ist die Eule mit 3.205.288 Bytes; ihr Atlas hat 1.565.951 Bytes und der übrige GLB-Inhalt 1.639.337 Bytes.

## Nachweise

`meshy_rig_validation.json` enthält den unabhängigen Binärtest aller 27 Exporte. Er liest GLB-Accessorwerte, berechnet glTF-Animationen und lineares Skinning selbst und verwendet weder Blender noch den Rig-Generator zur Auswertung. Alle 27 Dateien bestehen. Die maximale Abweichung der Gewichtssumme von eins beträgt 1,2666 × 10⁻⁷; die maximale neutrale Bind-Abweichung beträgt 2,1996 × 10⁻⁷ Meter.

`meshy_rig_visual_review.json` und die zugehörige Bildtafel dokumentieren 63 tatsächlich gerenderte Blender-Ansichten: Sitzpose von vorn und von der Seite, Blinzeln, Lenken, Winken, Jubeln und stehender Leerlauf für jeden Fahrer. Die Sichtprüfung fand in diesen Ansichten keine verbleibenden wesentlichen Riggingfehler. Sichtbare Eigenheiten der ursprünglichen Geometrie werden im Prüfprotokoll ausdrücklich benannt.

Die tatsächlich importierten Dateien wurden mit Godot 4.6.3 geprüft:

| Prüfung | Prüfpunkte | Fehler |
| --- | ---: | ---: |
| Rig-, Gesichts-, Material- und Ressourcenvertrag | 1.558 | 0 |
| Produktiver Fahreradapter mit Sitz, Lenken, Reaktionen, Pause und LOD-Wechsel | 8.245 | 0 |
| Karten-Roster, Figurenreaktionen und passende Porträtpfade | 119 | 0 |

Die größte dabei gemessene Handabweichung an den Lenkpunkten beträgt 0,2082 mm. Die Godot-Protokolle, Quellinventare und Aufnahmen mit dem tatsächlichen Comet-Kart sind separat in diesem Nachweisordner abgelegt. Blender-Ansichten und Godot-Laufzeitaufnahmen sind unterschiedliche Nachweisarten.

Der tatsächliche Flutter-Paketprüfer bestätigt außerdem alle 27 Quelldateien gegen das neue Produktionsmanifest (`flutter_source_inventory.json`). Seine bestehenden Export- und Paketidentitätstests umfassen 54 erfolgreiche Python-Tests. Diese Quellenprüfung ist kein Nachweis einer bereits gebauten APK.

## Reproduktion

Getestete Erzeugung: Blender 4.3.2. Getestete Godot-Laufzeit: 4.6.3. Der unabhängige Prüfer benötigt Python und NumPy.

```bash
blender -b -t 2 --python-exit-code 1 \
  -P tools/lumo_kart_art/drivers/rig_meshy_drivers.py -- \
  --review /tmp/lumo-meshy-review
python3 tools/lumo_kart_art/drivers/write_animal_manifest.py
python3 tools/lumo_kart_art/drivers/validate_meshy_rigs.py \
  --output /tmp/lumo-meshy-validation.json
godot --headless --editor --import --quit
godot --headless --script res://scripts/tests/lumo_rival_rig_contract_regression.gd
godot --headless --script res://scripts/tests/lumo_kart_production_driver_regression.gd
godot --headless --script res://scripts/tests/cards_character_roster_regression.gd
```

Das Produktionsmanifest bindet Generator, Anatomiedaten, unveränderte Meshy-Quellen, alle LOD-Dateien und Porträts an ihre SHA-256-Werte. Anatomieänderungen erzwingen eine erneute Erzeugung, bevor das Manifest geschrieben werden kann. Die `.blend`-Arbeitsdateien sind daraus reproduzierbar und werden nicht versioniert.

## Auslieferungsstand

Die Arbeit basiert auf Godot-Commit `0086e1a2aaac0086d406bcf2d2e705b336929f34` und Flutter-Commit `a7626c17cb38691a3b3d5a974d84ce274d6acf4b` des Entwicklungszweigs `repair/lumo-device-bugs-2078`.

Der erste Uploadversuch nach GitHub wurde von der automatischen Freigabeprüfung abgelehnt: Sie verlangte eine ausdrückliche Freigabe für die Übertragung der neuen Modelle, Porträts, Quellen und Nachweise an das Repository. Der abgelehnte Upload wurde nicht über einen anderen Übertragungsweg umgangen. Die vollständige lokale Änderung wird zur konkreten Freigabe bereitgestellt.

Die Flutter-Integration pinnt den geprüften Godot-Stand. Der vorbereitete 2078-Buildablauf ergänzt die unabhängige Rigprüfung, die echten Godot-Regressionsprüfungen und die Paketprüfung aller 27 Modelle. Eine neue APK, ein Android-Emulator-Ergebnis, eine Play-Veröffentlichung oder 60 FPS auf einem physischen Android-Gerät werden durch diesen lokalen Rigging-Nachweis nicht behauptet.
