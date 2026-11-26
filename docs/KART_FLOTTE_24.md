# 24 fahrbare Lumo-Karts

Die ersten 14 Fahrzeuge behalten Kennungen, Startnummern, Sternschwellen und ihre zugelassenen Meshy-Nahmodelle. Die zehn neuen Karosserien sind Eigenentwürfe für Lumo. Ihr Blender-Quellcode steht in `tools/lumo_kart_art/karts/console_fleet.py`. Der Generator verwendet lokale Geometrie und PBR-Materialien ohne fremde Fahrzeugvorlagen oder neue externe Dateien. Die drei vorhandenen mechanischen Fahrwerke übernehmen Räder, Lenkung, Federung und die Sitz- und Griffpunkte für die Fahreranimationen.

| Kart | Karosserie | Stärke |
| --- | --- | --- |
| Kupferpfeil | Torpedonase, Rundscheinwerfer und gebogene Kotflügel | Bremsen |
| Dünenspur | Offener Rallye-Buggy mit sichtbarem Überrollbügel | Antritt und Sand |
| Schneewacht | Winter-Rallye mit breitem Stoßfänger und Arbeitsscheinwerfern | Bremsen und Stabilität |
| Kristallfalter | Gefaltete Seiten in Kristallform | Geraden und Kurven |
| Hafenflitzer | Hölzern wirkendes Vordeck und zwei seitliche Schwimmer | Kurven |
| Glutstrom | Kühlrippen und tiefe Doppel-Lippe | Turbo |
| Wolkenkurier | Geteilte Scheinwerfergondeln und hochgezogene Leitwerke | Lenkung und Bremsen |
| Moosläufer | Runde Geländekarosserie mit Schutzbügeln | Abseits der Fahrbahn |
| Mondsprint | Geteilte Nase und hochgezogene Mittelrippe | Gerade und Turbo |
| Werkmeister | Breite Werkstattkarosserie mit sichtbaren Werkzeugfächern | Bremsen und Stabilität |

Jeder GLB-Export hat drei getrennte Karosserie-LODs, Montagepunkte, Startnummern- und Aufkleberpunkte sowie eine eigene Nahdetail-Gruppe für die Garage. Die farbigen freigestellten WebP-Aufnahmen stammen aus Blender Cycles und werden für Godot und Flutter aus derselben Datei übernommen. Fahrwerte und Freischaltungen stehen in `kart_fleet.gd`. Die Motorsynthese verwendet in `kart_fx/kart_motor_voice.gd` je Typ eigene Grundfrequenz, Zündcharakteristik und elektrischen Anteil.

```sh
blender -b -t 2 --python tools/lumo_kart_art/karts/build_fleet.py -- \
  --only kupferpfeil --only duenenspur --only schneewacht --only kristallfalter \
  --only hafenflitzer --only glutstrom --only wolkenkurier --only mooslaeufer \
  --only mondsprint --only werkmeister --samples 18 --flutter ../lumo-lernen
```

In Godot bleiben die automatisch erzeugten Mesh-LOD-Stufen für diese Exporte ausgeschaltet, weil die Laufzeit zwischen den drei gelieferten Netzen umschaltet. Für den gemeinsamen Veröffentlichungsstand muss `scripts/verify_kart_fleet_mirror.py` im Flutter-Projekt gegen den gepinnten Godot-Commit laufen.
