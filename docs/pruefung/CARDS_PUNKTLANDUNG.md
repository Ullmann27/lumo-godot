# Lumo Cards · Punktlandung aus der Spielauswahl bis zum Ergebnis

Die drei [Spielbilder](Cards_Punktlandung_2085.webp) stammen aus einer durchgehenden Partie in Godot 4.6.3. Das Kind wählt Punktlandung in der Auswahl mit vier Spielen. In der ersten Wertung bleibt Ziel 2 stehen. Eule Ella gewinnt mit der Karte 2, der angezeigte Abstand ist 0. Nach sieben Vergleichen zeigt der Tisch Platz zwei und die einmal gebuchten zwei Sterne.

| Prüflauf | Ergebnis |
| --- | --- |
| Lokaler Godot-Lauf ohne Renderer | 47/47, sieben vollständige Zahlenvergleiche |
| Lokaler X11-Lauf mit OpenGL Compatibility und echten Spielbildern bei 860 × 780 | 50/50, sieben vollständige Zahlenvergleiche und drei verifizierte Einzelbilder |
| Android-Emulator der Folgefassung und physische Geräte | NICHT GETESTET |

Beide Läufe bedienen die Auswahl, Einführung, Einstellungen, Handkarten und den Ergebnisbildschirm durch Touch-Ereignisse. Sie prüfen den Zahlenabstand anhand der gespielten Karten, die bestätigte Rückgabe an die Spielewelt und die Freigabe der 3D-Szene.

Prüfskript: scripts/tests/cards_punktlandung_reveal_regression.gd. Für den gerenderten Lauf LUMO_PUNKTLANDUNG_BELEGE auf einen beschreibbaren Ordner setzen und Godot mit --disable-render-loop starten. Das Skript aktiviert den Renderer für die drei Aufnahmen.
