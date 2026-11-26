# Sternenpost auf dem kleinen Bildschirm

Im vorherigen Menü waren die Stufen und Lackfarben in Reihen mit festen Mindestbreiten untergebracht. Bei 640 × 480 Pixeln reichte die rechte Spalte über den sichtbaren Fensterrand. Bei 2340 × 1080 Pixeln lag der Start unterhalb der sichtbaren Optionen und erforderte Scrollen. In der korrigierten Oberfläche passen sich die Spalten an die verfügbare Breite an. Lackfarben und Rätseloption dürfen umbrechen. Start und Fortsetzen stehen fest am Fuß der Karte. Der Einstellungsbereich scrollt für sich.

Wenn eine Schaltfläche die Ansicht wechselt, wird das alte Menü sofort ausgeblendet. Godot entfernt seine Bedienelemente nach der Eingabeverarbeitung. Dadurch bleibt der laufende Touchevent bis zu seinem Ende gültig.

[Vorher und nachher in der tatsächlichen Godot-Ausgabe](Sternenpost_Bedienung_Konsole.webp)

| Prüfung | Befund |
| --- | --- |
| Lokaler X11-Lauf mit Godot 4.6.3 und OpenGL Compatibility | **211/211**. Das Menü blieb in fünf Fensterformaten innerhalb der sicheren Fläche. Bei 640 × 480 ließen sich Hilfe, Wolkenrennen, Lieferflug, Extrem, letzter Lack und Rätsel über Touch bedienen. Der gestartete Flug ließ sich pausieren, speichern und mit derselben Ergebnis-ID fortsetzen. |
| Native Flugtests mit Flugbot | **94/94**. Alle drei Lieferstufen, alle drei Wolkenrennen mit Gegnern im Ziel, Freiflug mit Album, Rettung, Kindwechsel, gespeicherte Tour und einmalige Sternbelohnung bestanden. |
| Android-Emulator und physischer Fold7 mit dieser Änderung | **NICHT GETESTET**. Die Fold-Fenstermaße und die Dichte 2,625 wurden lokal nachgebildet. |

Reproduktion mit scripts/tests/sky_post_menu_layout_regression.gd im Fenster und scripts/tests/sky_post_regression.gd ohne Renderer. Der Fensterlauf speichert Aufnahmen, wenn LUMO_SKY_POST_BELEGE auf einen beschreibbaren Ordner zeigt.
