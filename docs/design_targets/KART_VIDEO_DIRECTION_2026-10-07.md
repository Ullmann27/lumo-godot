# Lumo Kart – verbindliche Video-Qualitätsrichtung (2026-10-07)

Heinz hat zwei 10-Sekunden-Referenzvideos (1280×720, 24 fps) als Zielbild für das **echte laufende Spiel** vorgegeben. Diese Dateien sind Designreferenz, kein Runtime-Nachweis und kein Asset-Lieferant. Fremde Namen, Logos, Figuren, Strecken oder Marken werden nicht kopiert.

## Was aus den Referenzen verbindlich übernommen wird

### Kamera / Game feel
- Third-Person-Chase-Kamera nahe und tief hinter dem Kart.
- Das Fahrzeug bleibt groß und sofort lesbar; die Strecke und das nächste Landmark bleiben gleichzeitig im Bild.
- Geschwindigkeit wird durch einen begrenzten FOV-Punch, leuchtende Fahrbahnelemente und vorhandene Kart-FX vermittelt, nicht durch unlesbare Kamerasprünge.
- Sprünge behalten Horizont und Landebereich im Blick.
- Reduced Motion deaktiviert Roll-/Speed-Punch und behält eine ruhige Basisansicht.

### Fahrbahn / Material
- Glänzende, klar gerichtete Fahrbahn statt matter grauer Fläche.
- Sichtbare, originale Lumo-Leitlichter an den Fahrbahnrändern.
- Stark lesbare Kurvenmarkierung, Boost-/Sprungzonen und Setpiece-Silhouetten.
- Nachtwelten: Cyan/Orange/Violett gegen dunklen Untergrund.
- Helle Welten: hohe Farbsättigung, klare Sonne/Himmel-Trennung, ohne weiße UI-Flächen auszubrennen.

### Welt / Komposition
- Große Landmarken müssen bereits mehrere Sekunden vor dem Erreichen erkennbar sein.
- Vordergrund, Mittelgrund und Hintergrund sollen gleichzeitig Tiefe erzeugen.
- Keine leeren Flächen, die wichtiger als die Strecke werden.
- Himmelswelten benötigen dichte Wolken-/Inselstaffelung; Nachtwelten benötigen klare Emissionsquellen und leuchtende Streckenführung.
- Looping/Brücke/Rampe zählt nur dann als Gameplay-Feature, wenn die echte Physik-, Kamera-, AI-, Collision- und Respawn-Prüfung bestanden ist. Ein Bild allein reicht nicht.

## Technische Mindestabnahme

Der Visual-Pass ist nur dann als integriert zu melden, wenn:

1. ein echter Godot-Lauf dieselben Dateien erzeugt, die geprüft werden;
2. 1280×720 Runtime-Captures aus der tatsächlichen Chase-Kamera existieren;
3. Holo-City und Himmelsinseln Filmic Tonemapping sowie sichtbaren Glow/Contrast/Saturation-Grade verwenden;
4. die Fahrbahn den neuen glossy/emissive Shader tatsächlich gebunden hat;
5. Baseline-FOV, Speed-FOV und Boost-FOV begrenzt und per Regression geprüft sind;
6. bestehende Kart-Physik, Modi und Rivalen-Fairness weiter bestehen;
7. ein visueller Vergleich weiterhin **VISUAL_GAP / NOT FINISHED** lautet, solange die echten Frames den Referenzen sichtbar deutlich unterlegen sind.

## Aktuelle Implementierungsparameter

Die Parameter liegen zentral in scripts/games/kart_visual_grade.gd:

- Chase-Distanz: 5,45–6,15 m
- Kamerahöhe: 2,72 m
- Look-ahead: 9,6 m + geschwindigkeitsabhängige Verlängerung
- Basis-FOV: 64°
- Speed-FOV: 70°
- Boost-FOV: 78°
- begrenzter Kamera-Roll nur ohne Reduced Motion
- High-Profil: Filmic + Glow + Contrast/Saturation und glossy/emissive Road Grade

Diese Werte sind Ausgangspunkt für echte Captures; sie dürfen anhand messbarer Frame-Befunde weiter getunt werden.

## Nicht erfüllt allein durch diesen Pass

- kein physischer Fold-7-/60-FPS-Nachweis;
- keine AAA-Qualitätsbehauptung;
- keine automatisch „fertige“ Strecke;
- keine neuen 3D-Charakter-Rigs oder DCC-Modelle;
- keine Übernahme der Referenznamen „Volcano Night Run“ oder „Candy Cloud Circuit“.

Die Referenzen definieren die **Qualität der sichtbaren Runtime**, nicht eine Lizenz zum Kopieren ihres Inhalts.
