# Spielbilder zur Testversion 2063

Godot 4.6.3, Compatibility-Renderer unter Xvfb mit Mesa llvmpipe. Der Spielstand für die APK ist `2e2ff5d`. Die Vergleichsbilder sind für die Übersicht verkleinert.

- [Riesengarten](Riesengarten.webp) – fünf in Blender neu exportierte Wahrzeichen sowie die Rennkamera in zwei Runden. Die Originalbilder haben 2176 × 1812 und 1080 × 2340 Pixel. Der Sprenger läuft ab der zweiten Runde und der Dunst nimmt ab.
- [Kart-Fahrer](Fahrervergleich.webp) – Original-Lumo und sechs Mitspieler. Die Garage zeigt alle Figuren zur Inspektion im selben Kart. Die drei unteren Reihen verwenden eine Vergleichskamera an den echten Rennfahrzeugen. Andere Karts sind während des jeweiligen Porträts ausgeblendet. Die Zielposen wurden über den Ergebnisablauf ausgelöst. Der Frosch fährt auf Dschungelherz.
- [Wolkenhafen](Wolkenhafen.webp) – Cycles-Ansichten der exportierten Modelle neben Spielansichten des Stegs und des Sternseglers.
- [Weitere Spiele](Spiele.webp) – Sternenjagd nach dem Antippen, Puzzle-Atelier, Rhythm Party, Wolkeninseln und Schatzsuche. Die Bilder dokumentieren einzelne Spielzustände.
- [Gerätetest am Galaxy Z Fold7](GALAXY_Z_FOLD7.md)

## Messung im Container

Riesengarten bei Meter 175 in Runde zwei, 2176 × 1812. Je Profil sechs Aufwärmdurchläufe und 30 gemessene Frames. Zeit zwischen fertigen Frames einschließlich Szenentakt und Synchronisation. Der Container nutzte einen CPU-Renderer und war während der Messung geteilt.

| Profil | Median | P95 | Draw-Calls (Median) |
| --- | ---: | ---: | ---: |
| LOW | 776 ms | 907 ms | 204 |
| MEDIUM | 1432 ms | 2254 ms | 286 |
| HIGH | 2223 ms | 3656 ms | 302 |

Die Messung am Fold7 steht aus.
