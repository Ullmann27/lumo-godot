# Testversion 2064 im Spielbild

Der Godot-Stand der APK ist `d513e805a256ac4d2234b329a30b2b25536766bf`. Die drei Vergleichstafeln zeigen oben das in Blender gerenderte Wahrzeichen, in der Mitte die Godot-Rennkamera mit 2176 × 1812 Pixeln und unten das Hochformat mit 1080 × 2340 Pixeln. Die Übersichten sind verkleinert. Die Spielbilder entstanden im Compatibility-Renderer unter Xvfb. Die Aufnahmeroutine prüft zusätzlich mit zwei vorübergehenden Markierungsfarben, ob das Modell zwischen Kulisse und HUD sichtbar ist. Die Tafeln zeigen die Originalmaterialien.

- [Werftkran, Leuchtpilze, Gondel, Signalspule und Kristallgeode](Strecken_2064_1.webp)
- [Tukan, Eispokal, Schmelzofen, Schneeschuhe und Planetenmodell](Strecken_2064_2.webp)
- [Sternensegel, Mikroskop und Kapokbaum](Strecken_2064_3.webp)
- [Sechs Teile im geöffneten Konfigurator](Werkstatt_2064.webp). Regenreifen und Tandemflügel sitzen am Kart. Lenkung, Bremse, Getriebe und Ballast zeigt die Werkstatt zur Inspektion neben dem Fahrzeug.
- [Riesengarten, Mitspieler, Sternenpost und fünf weitere Spiele](SPIELBILDER_2063.md)

## Veröffentlichtes Android-Paket

Die direkt aus dem öffentlichen Release heruntergeladene ARM64-Datei hat 506.214.708 Byte. Der lokal neu erstellte APK-Prüfbericht stimmt mit dem veröffentlichten Bericht überein. Godot 4.6.3 hat aus dem eingebetteten Spielpaket alle 13 Kurvenwahrzeichen mit je drei Detailstufen und Farb- und Normaltexturen geladen. [Test-APK 0.13.52+2064 und Prüfsummen](https://github.com/Ullmann27/lumo-lernen/releases/tag/lumo-test-0.13.52-2064-45038346436)

## Rennprüfung

In einem lokalen Lauf über zwei Runden mit Startwert 7 erreichten das Spieler-Kart und fünf Gegner auf jeder der 14 Strecken das Ziel. Die Rettungswolke setzte das Spieler-Kart auf Winter-Sprint und Dschungelherz je zweimal auf den Vorplatz der schmalen Brücke zurück. Auf den Steilkurven gab es in diesem Lauf keine Rücksetzung.

Im getrennten Ereignistest kam der erste registrierte Höhepunkt auf den 13 überarbeiteten Strecken nach 1,9 bis 5,8 Sekunden. Die größte Lücke zwischen zwei Höhepunkten lag je nach Strecke zwischen 4,9 und 9,5 Sekunden. Im Riesengarten waren es 9,3 Sekunden bis zum ersten Höhepunkt und maximal 15,2 Sekunden zwischen zwei Höhepunkten. Das Höhenprofil aller 14 Fahrbahnen umfasst je nach Strecke 15 bis 24 Meter zwischen tiefstem und höchstem Punkt.

## Mobile-Renderer

Godot 4.6.3, Vulkan mit Mesa llvmpipe unter Linux. Bei 480 × 360 Pixeln erreichte das Profil LOW im festen Riesengarten-Bild einen Median von 106,76 ms, ein 95. Perzentil von 125,46 ms und 121 Draw-Calls im Median über 30 gemessene Frames. Der Test prüfte auch das Einsetzen der Sprenger und das Abnehmen des Dunsts in Runde zwei. [Beide Runden im Mobile-Renderer](Riesengarten_Mobile_2064.webp)

Die drei Profile wurden zusätzlich bei **2176 × 1812 Pixeln** an derselben Stelle in Runde zwei gemessen. Je Profil liefen sechs Aufwärmdurchläufe vor 30 Messframes. Die Werte enthalten Software-Rendering und Synchronisation im geteilten Container. [Spielbilder aller drei Profile](Mobile_Profile_2064.webp)

| Profil | Median | 95. Perzentil | Draw-Calls im Median |
| --- | ---: | ---: | ---: |
| LOW | 886,31 ms | 1603,92 ms | 162 |
| MEDIUM | 1593,56 ms | 1725,44 ms | 196 |
| HIGH | 3037,63 ms | 3248,18 ms | 215 |

Messungen am Galaxy Z Fold7 stehen aus. [Checkliste für Heinz](GALAXY_Z_FOLD7.md)
