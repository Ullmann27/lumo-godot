# Native Lernbuttons: Schriftkontrast der interaktiven Zustände

Basis ist ausschließlich Native `678cb38fea3a83a7f5841e71fba9bb2f3bfa2eef`.
Der Produktionsdelta liegt vollständig in `learning_world.gd::_button`:
Die schon vorhandene dunkle normale Schriftfarbe wird auch für Hover, Fokus,
gedrückt und Hover+gedrückt ausdrücklich gesetzt. Hintergründe, Geometrie,
Signale, Disabled-Zustand und sämtliche Lern-/Sprach-/Scopefunktionen bleiben
bytegleich. Der Next-/Wonder-Einstieg erbt diese Factory unverändert.

## Anlass und Aussagegrenze

Das bytegleiche Original `0529-runtime-voice-stop.png` stammt aus dem fehlgeschlagenen
Supplemental-Lauf 43828196598. „Stimme stoppen“ erscheint sehr hell auf hellem Grün;
die Nachbarlabels sind dunkel. Im ebenfalls originalen Bild 0530 ist schon wieder
„Schritt anhören“ in demselben hellen Schriftzustand sichtbar. Herkunft und Hashes
beider Bilder sowie des Journals stehen in `android-trigger.json`; hier ist nur
0529 nochmals aufbewahrt. Das vollständige Originalarchiv liegt im Flutter-Repo.

Das Journal enthält keinen Stop-Tastendruck. Der konkrete damalige Godot-Drawmode
ist nicht protokolliert. Weder eine funktional deaktivierte Taste noch ein
unwirksamer Audiostopp wird daraus behauptet. Der ursprüngliche Androidlauf bleibt
FAIL; dieser Fix wurde noch nicht in einer neuen Android-APK ausgeführt.

## Tatsächlich ausgeführte Regression

Ein unverändertes GDScript wurde zuerst gegen die exakten Basisbytes, dann gegen
den Fix ausgeführt. Engine ist die vorhandene offizielle **Godot 4.6.3**, Hash
`7d41c59c457bd5a245092b4e7eb2d833e3b3f8c3`; Binary-SHA und Befehle stehen in den
beiden Provenienzdateien. Kein Download, keine neue Engine, keine Assetkopie.

Das Script liest die produktive `_button`-Methode unverändert aus der Quelldatei
und kompiliert sie direkt mit Godot. Es erstellt daraus echte Buttons beider
Paletten. Es kopiert weder die Factory noch deren Farben in eine Ersatzlogik.
Godots tatsächliches Default-Theme bestätigt alle fünf geprüften Font-Namen.
Die Basis löst Hover/Fokus zu `#f2f2f2`, gedrückt/Hover+gedrückt zu `#ffffff` auf.

Die Prüfung wertet die tatsächlich aufgelösten Theme-Farben und StyleBox-Hintergründe
aus. Alle fünf interaktiven Schriftfarben werden gegen alle vier opaken
Hintergründe geprüft, einschließlich des Fokus-Overlays. Die Mindestanforderung
dieser Regression beträgt 4,5:1. Dadurch muss der Test keine interne
Godot-Prioritätslogik für Kombinationen nachbauen.

Zusätzlich werden echte Eingaben über `Viewport.push_input` und echter Fokus
verwendet: normal, Fokus, Hover, Hover+Fokus, gehaltene Maustaste+Hover+Fokus,
gehaltene Leertaste mit/ohne Hover sowie Loslassen. Die Engine bestätigt 16
Zustandsbeobachtungen und insgesamt sechs Signalaktivierungen. Die produktiven
Buttons bleiben nicht umschaltend; deren Hover+gedrückt ist tatsächlich
`DRAW_PRESSED`. Das zusätzliche Theme-Item `font_hover_pressed_color` wird deshalb
als Palettenwert geprüft, ohne einen nicht beobachteten Drawmode zu behaupten.

| Unverändertes Prüfscript | Basis / RED | Fix / GREEN |
| --- | ---: | ---: |
| Prüfbedingungen | 79 | 79 |
| Erfüllt | 47 | 79 |
| Verletzt | 32, ausschließlich Kontrast | 0 |
| Echter Input-/Fokuszustand | 16/16 | 16/16 |
| Signalaktivierungen | 6 | 6 |
| Kleinster geprüfter Kontrast, helle grüne Palette | 1,102359:1 | 6,437931:1 |
| Kleinster geprüfter Kontrast, goldene Palette | 1,779591:1 | 4,634526:1 |

Rohlogs: `red.log` und `green.log`; sämtliche Farben, Verhältnisse und
Eingabebeobachtungen: `red.json` und `green.json`. Der Test-SHA ist in beiden
Resultaten identisch. `scope-verification.json` hält zusätzlich die überprüften
Bytegleichheiten außerhalb der Schriftfarben fest.

## Reproduzierbare kleine Laufumgebung

Das echte verwendete Projekt ohne Autoloads oder Assets ist als
`isolated-project.godot` erhalten. Für einen eigenen Lauf in einem leeren
Scratch-Verzeichnis diese Datei dort `project.godot` nennen und ausführen:

```sh
LUMO_LEARNING_WORLD_SOURCE=/absolute/repo/scripts/learning/learning_world.gd \
LUMO_CONTRAST_OUTPUT=/absolute/scratch/result.json \
godot --headless --path /absolute/scratch \
  --script /absolute/repo/scripts/tests/learning_button_state_contrast_regression.gd
```

Die genauen tatsächlich ausgeführten absoluten Pfade stehen in den Provenienzdateien.
Ein lokaler Xorg-Start mit vorhandenem Dummy-Treiber scheiterte bereits am Anlegen
der Listening-Sockets. Die erfolgreiche Prüfung verwendet daher **Headless**:
reale Engine-Themeauflösung und reale Button-Eingabe, aber keine neue gerenderte
Pixelaufnahme. Sie ersetzt weder einen vollständigen Lernwelt-/Androidlauf noch
eine akustische, Mund-/Gesten- oder zeitgenaue Stopprüfung.

Die Disabled-Palette wurde lediglich ausgelesen und bleibt unverändert; daraus
wird keine neue Kontrastfreigabe für deaktivierte Controls abgeleitet. `gdlint`
und `gdformat` waren lokal nicht installiert. Der vollständige Strukturvalidator
wurde im bewusst sparsamen Worktree ohne Assets nicht ausgeführt. Die geprüfte
Methode und der Test wurden tatsächlich von Godot kompiliert und ausgeführt.
