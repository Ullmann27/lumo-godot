# Android-Kart: freie Bühne und getrennte Touchbereiche

## Belegter Fehler und abgegrenzte Korrektur

Die tatsächliche Android-Tour aus Host `c0ff902552e94856ea1dcda3cfb1f07e9e2044ed`,
Actions-Run `43203717096`, zeigte bei **2400×1080 und 420 dpi** zwei Fehler:
Der Header lag hinter den Navigationstabs; die bildschirmbreiten Modusreihen
verdeckten das reale Kart. Diese APK ist kein visueller Freigabenachweis.

Die native Baseline ist lokal `95e51bd3576a86283bd25da9614310de06bd3d30`,
remote `0aa89cdea3a07d0c2bc0a31a153737a1fee41454`, identischer Tree
`f721fd75095d7244c1152c43cd83dcd8a88d5985`.

Der reproduzierende Lauf verwendet die wirkliche Dichte **2,625**, den
erweiterten logischen Viewport **1600×720** und Root-Pixelskalierung **1,5**.
Insets `(links0, oben32, rechts0, unten126)` ergeben die in den Screenshots
gemessene sichere Fläche von **2400×922 ab y32**. Diese Werte reproduzieren
diese beobachtete Android-Konstellation; sie werden nicht als allgemeine
Android-Konstanten in die Produktion eingebaut.

Das geerbte Sternlabel hatte automatischen Zeilenumbruch, eine minimale
Breite von nur einem logischen Pixel und dadurch **133 logische Pixel
Mindesthöhe**. Es streckte den gesamten Header; die Tabposition blieb an
der geplanten 48-dp-Höhe. Der Fix entfernt den Umbruch für dieses eine
Symbol, zentriert es und bestimmt die nächste Zeile erst aus den wirklichen
Header-Minima. Die Container können nach Größenwechseln wieder schrumpfen.

Auf ausreichend breiten, kurzen Flächen stehen die drei Rennmodi jetzt
links in echten, mindestens 48 dp hohen Zeilen. Die Optionen nutzen ihre
benötigte Breite. Die Landing meldet nach dem Layout die tatsächlich freie
Fläche an die bestehende 3D-Kamera. Auch die Auswahlansicht berücksichtigt
ihre sichtbaren Bedienelemente. Die vorhandenen Modelle, Rennen, Karts,
Speicherwege, Inspektionsansichten und Navigation bleiben unverändert.

## Gemessene Vorher-/Nachherwerte

| Eigenschaft im exakten Android-Fall | Baseline | Korrektur |
|---|---:|---:|
| Header y / Höhe in echten Pixeln | 63,5 / 205,5 | 63,5 / 132 |
| Unterkante Header | 269 | 195,5 |
| Oberkante Tabs | 210,5 | 216,5 |
| Trennung | 58,5 px Überlappung | 21 px freier Abstand |
| Unterer Spielewelt-Touch | kein `games`, wechselt zu Tempo | genau ein `games`, Auswahl bleibt |
| Landing: Chassis-/Kopf-Überdeckungen durch UI | 20 | 0 |
| Reale Modellpunkte hinter Kamera / außerhalb Preview | 0 / 0 | 0 / 0 |

Der Spielewelt-Touch wird bei **85 % der tatsächlichen Buttonhöhe** als
`InputEventScreenTouch` mit Drücken und Loslassen eingespeist. In der
Baseline landet er bei `(2229; 236,075)` auf Tempo. Nach der Korrektur
landet er bei `(2229; 173,6)` auf Spielewelt. Garage → Fahrer → Garage
wiederholt dieselbe Prüfung und erhält jeweils die richtige Auswahl.

Die Projektionsprüfung benutzt echte Chassis-/Reifen-AABBs und Kopf-/Ohrpunkte
des aktuellen Modells. Sie fordert zugleich: vor der Kamera, innerhalb des
realen Preview-Rechtecks und ohne Schnitt mit sichtbaren UI-Elementen.
Der bestehende Test gegen die Studiowände bleibt erhalten. Zusätzlich
bestätigt `final-probe.log` für Landing und Garage jeweils **100 Randstrahlen
ohne Schnitt mit den sichtbaren Studiomesh-AABBs**. Der Landing-Kameraursprung
liegt vor der offenen Vorderkante der rechten Wand; seine x-Koordinate allein
ist deshalb kein Occlusion-Kriterium.

## Tatsächlich ausgeführte Prüfung

| Prüfung | Ergebnis |
|---|---|
| Identische finale Spatial-Regression gegen unveränderte Baseline | **FAIL, Exit1, 554 Checks, 5/5 Fälle abgeschlossen** |
| Finale Spatial-Regression gegen Korrektur | **PASS, Exit0, 554 Checks, 5/5 Fälle abgeschlossen** |
| Vorhandene vier Größenfälle | 1280×720, 412×915, 690×829, 640×320 bleiben enthalten |
| Neuer fünfter Fall | 2400×1080, Dichte2,625, Insets und Root-Skalierung wie oben |
| Compact-Kart-Auswahl | **181 Checks, 4/4 Fälle, Exit0** |
| Sichtbare Touch-Ziele | **240 Controls mit mindestens48×48 dp, Exit0** |
| Projektvalidator | **117 PASS / 7 WARN / 0 FAIL, Exit0** |
| Shellsyntax und Diff-Whitespace | `bash -n` und `git diff --check` erfolgreich |
| `gdlint` / `gdformat --check` | nicht installiert, jeweils Exit127; kein Erfolg behauptet |

Die beiden finalen Spatial-Läufe verwenden bytegleich denselben Test;
sein SHA256 und sämtliche Quellen-/Loghashes stehen in `RESULT.json`.
Die Negativkontrolle endet regulär mit einem Fehlercode und allen fünf
abgeschlossenen Fällen. Ein Lauf ohne Abschlussmarker wird vom bestehenden
Probe-Runner abgewiesen. Der ältere Touch-Ziel-Test protokolliert nach seinem
PASS die bekannte Teardown-Meldung `2 resources still in use at exit`;
die neuen finalen Spatial-Logs enthalten diese Meldung nicht.

Alle lokalen Engine-Läufe hier sind **headless mit Godot4.6.3**, mit
getrennten XDG-Daten. Sie belegen Geometrie, Projektion und echten
Eingabetransport; sie ersetzen kein gerendertes Android-Bild. Der bestehende
Renderer-Gate erzeugt weiterhin echte Screenshots und verweigert Captures im
Headless-Modus. Seine virtuelle Leinwand wurde auf **2560×2560** vergrößert,
damit auch der zusätzliche 2400-Pixel-Fall vollständig Platz hat.

Eine neue Renderer-/APK-Abnahme für diesen Quellstand bleibt erforderlich.
Es wurde in diesem Fixauftrag keine lokale APK neu gebaut und nichts
veröffentlicht. Die Rohlogs wurden unverändert aus den tatsächlichen Läufen
übernommen.

### Reproduktion

Die vorhandene `tools/validate_action_stage.sh` führt den erweiterten
Spatial-Test mit einem echten Renderer und `--capture` aus. Die begrenzte
lokale Geometrie-/Eingabeprüfung lautete:

```sh
XDG_DATA_HOME=/tmp/lumo-layout-data XDG_CONFIG_HOME=/tmp/lumo-layout-config \
  timeout 150s godot --headless --path . \
  --script res://scripts/tests/kart_spatial_menu_regression.gd
```

Für die Negativkontrolle wurde genau dieselbe Testdatei in ein ignoriertes
`exports`-Verzeichnis der unveränderten Baseline kopiert und dort mit
eigenen XDG-Verzeichnissen ausgeführt. Keine Baseline-Produktionsdatei wurde
dabei verändert. `probe.gd` ist die zusätzliche reine Koordinaten-/Randstrahl-
Diagnose; sie ist kein zusätzlicher Produktionspfad.
