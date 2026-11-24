# Unabhängige visuelle Prüfung des gemeinsamen Stands b357

Capture-Produktstand: `b357b2f8decb4b11b0cc45e9fde2b8df5ec9cbe1`. Vier Rennkamera-Bildpaare und drei Garage-Bildpaare wurden visuell angesehen. Die vier Bilder des korrekt zugeordneten Renn-Reruns wurden danach nochmals geöffnet. Kein neuer Rendererjob und keine Produktänderung durch diesen Review.

## Herkunft und Vergleichbarkeit

Der erste Renncapture hatte ein leeres `source_sha`. Er wurde nicht umetikettiert. Der Integrator wiederholte das unveränderte Fixture mit dem verifizierten Commit. Finales `capture.json`, `provenance.json`, alle vier PNG-Hashes und die im Git-Objekt b357 gespeicherten Fixture-/Rennskripthashes stimmen überein. Die Provenienz dokumentiert saubere Quellen vor/nach der Aufnahme. Der während des Reviews bereits weitergezogene HEAD 8bd40b4b7f77d3c259c8beecc768c13de46d1979 enthält gegenüber b357 ausschließlich Dokumentation und zwei Capture-Helfer; der getrackte Arbeitsbaum war sauber.

Rennen: Kamera-/Spielertransformationen, FOV 55°, 1280 × 720, High, Seed 2014, reduzierte Bewegung, Engine/Renderer und Capture-Skript sind exakt zur Baseline 207bfbc passend. Garage: FOV 37°, Sitzclip bei 0,3 s, Yaw −0,25, High, Seed, Bildschirm-/Preview-Auflösungen sind gleich. Ein gespeicherter Kamera-Basiswert unterscheidet sich um genau 0,000001 (0,977191 → 0,977190). Alle Garage-Metadaten nennen b357 und saubere Quellen. Relevante Garage-/Lumo-Quellen der Baseline c9b77 sind gegenüber 207bfbc unverändert.

## Sichtbefund

- Bei 18, 60 und 110 m sind Bogenfenster, Läden, Gesimse, Balkone und Markisen in einer zusammengehörigen Gestaltung sichtbar. Bei 160 m bleibt das Bild weitgehend unverändert; kein Nachweis eines kompletten Streckenumbaus.
- Keine neue offensichtliche Meshüberschneidung oder Textabschneidung in den geprüften Ansichten. Fahrbahn, Kurvenhinweis, Original-Lumo und HUD werden nicht neu verdeckt. Zeitliches Z-Fighting oder sämtliche Kamerawinkel sind damit nicht ausgeschlossen.
- Garage: Wandgliederung, Bodenfelder, Podiumsmarkierungen und Werkstattschubladen bilden einen klareren Raum. Der ursprüngliche Comet und Lumo bleiben konsistent. Gesicht, Brille, Proportionen und Rennanzug erscheinen unverändert; der GLB-Hash bestätigt unveränderte Modelldaten.
- Zurück, Weiter und die Auswahl sind in 1280 × 720, 412 × 915 und 690 × 829 sichtbar. Im Phoneformat passt „Rundum“ vollständig; der Baseline-Ansichtsname war abgeschnitten.
- Im Foldformat ist weiterhin nur die erste Fahrzeugkarte im Scrollausschnitt sichtbar. Die bestehenden Statistiktexte bleiben sehr klein. Der neue dekorative Wandslogan ist im Phone-/Foldformat ebenfalls klein; der farbige Originalhintergrund bleibt unruhig.

## Exakte Draw Calls

| Bild | Vorher | Nachher b357 | Differenz | Zählbereich |
|---|---:|---:|---:|---|
| Rennen 18 m | 350 | 391 | +41 | Gesamter Frame, RenderingServer |
| Rennen 60 m | 278 | 313 | +35 | Gesamter Frame, RenderingServer |
| Rennen 110 m | 269 | 287 | +18 | Gesamter Frame, RenderingServer |
| Rennen 160 m | 250 | 250 | +0 | Gesamter Frame, RenderingServer |
| Garage 1280 × 720 | 213 | 147 | -66 | Nur sichtbarer Preview-SubViewport |
| Garage 412 × 915 | 207 | 138 | -69 | Nur sichtbarer Preview-SubViewport |
| Garage 690 × 829 | 220 | 150 | -70 | Nur sichtbarer Preview-SubViewport |

Rennen und Garage verwenden verschiedene Zählbereiche. Keine unmittelbare Gegenüberstellung über beide Bereiche hinweg und keine FPS-Aussage. Umgebung: Godot 4.6.3 Compatibility unter Linux/Mesa llvmpipe, High-Qualität.

## Grenzen

Diese Prüfung umfasst Standbilder. Das Rennfixture steht bei 0 km/h und verwendet reduzierte Bewegung. Vollständige Fahrt, Looping/Rampen, Animation und Touchfunktionen benötigen die gesonderten Funktionsnachweise. Android-Emulator und echte Hardware wurden durch diesen Review nicht geprüft.

Das zuvor belegte Gecko-Schuh-/Karosserie-Clipping existiert bereits im Originaladapter und bleibt offen. Die hier geprüfte Comet-Frontansicht beseitigt oder widerlegt diesen Seitenansichtsbefund nicht.

Daten, Bildhashes, Primitive-/Objektzähler und abgeglichene Felder: [visual-review.json](visual-review.json).
