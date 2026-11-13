# Visuelle Prüfung: acht native Godot-Vorher-/Nachherbilder

**Ergebnis: kein sichtbarer Blocker; eingefrorenen Stand unverändert weiterprüfen.**

Geprüfter Quellstand: `9eb25fcb158342639badb0e953a8fe7945fda6ce`. Baseline: `ada5ed81ad62339f15289da62670c0a4f9f7f2b9`.
Alle acht 720 × 840-PNGs wurden einzeln mit `view_image` geöffnet und tatsächlich angesehen. SHA-256, Dateigröße und Abmessungen stimmen jeweils mit dem heruntergeladenen Renderer-Manifest überein. Vollständige Hashes und Einzelbefunde stehen in `native_renderer_review.json`.

Der Rendererlog weist Godot 4.6.3, X11, OpenGL Compatibility und Mesa llvmpipe aus. Er meldet acht erfolgreich aufgenommene Frames. Es sind echte Godot-Aufnahmen des Originalmodells.

## Sichtbarer Befund

Der Originalfuchs bleibt erkennbar erhalten: Gesicht, Brille, Anzug, Handschuhe, Schwanz und Materialien sind vollständig. Es gibt keine doppelte Figur, keine fehlenden Körperteile und keine neu sichtbare grobe Verformung. Am deutlichsten ist die Verbesserung beim Sprung und bei der Landung: Die Knie ziehen nachvollziehbar an; Schuhe und Sohlen bleiben vollständig und konsistenter ausgerichtet.

| Datei | SHA-256, Anfang | Visueller Einzelbefund |
| --- | --- | --- |
| `before_walk.png` | `e963e44f8bcb604c` | Originalfigur vollständig; Knie-/Fußstellung relativ breit und Sohlen unterschiedlich geneigt. Keine fehlenden Materialien oder doppelte Figur. |
| `after_walk.png` | `ee838afa26760e01` | Originalfigur erhalten; sichtbare Kniebeugung, zusammenhängende Gliedmaßen und vollständig erkennbare, gleichmäßiger ausgerichtete Sohlen. Kein sichtbarer neuer Blocker. |
| `before_sprint.png` | `a490cdfad6626530` | Originalfigur vollständig; diese Stichprobe zeigt eine recht aufrechte Haltung mit relativ gestreckten Beinen. |
| `after_sprint.png` | `1a0c94b4a770315a` | Tieferer Schwerpunkt, gebeugte Knie und erkennbare Körperneigung. Intakte Schuh-/Handgeometrie. Standbild liegt in einer anderen Schrittphase als Before und belegt allein keine Geschwindigkeit. |
| `before_jump_rise.png` | `dc2a537f56f807ec` | Beine vergleichsweise wenig angezogen, Schuhspitzen kippen nach unten; Sprunghaltung aus dem Einzelbild schwach erkennbar. |
| `after_jump_rise.png` | `80a2f272b3e0b4e7` | Deutlich angezogene Knie und sichtbarer Abstand beider Füße zur Bodenebene; Schuhe bleiben als vollständige Formen erkennbar. Arme und Schwanz zusammenhängend. |
| `before_land.png` | `f4146c517e89bc05` | Schuhspitzen kippen stark nach unten; die untere Schuhkontur wirkt an der Bodenebene angeschnitten. |
| `after_land.png` | `d9442204e757b11d` | Beide Schuhe einschließlich Sohlen vollständig sichtbar, Knie zur Landung gebeugt und Standform besser nachvollziehbar. Kein sichtbares Strecken oder Abreißen eines Gliedmaßes. |

## Grenzen der Aussage

Die kontrastreiche Studiobeleuchtung erzeugt helle Reflexe, in Before und After gleichermaßen. Sie verhindert keine Identitäts- oder Gliedmaßenprüfung, erlaubt aber zusammen mit dieser Kameraperspektive keine millimetergenaue Aussage über Bodenkontakt. Dafür gelten die separaten Endeffektor- und Gameplayprüfungen.

Walk und Sprint haben nach derselben verstrichenen Simulationszeit unterschiedliche Schrittphasen, weil die Schrittlänge korrigiert wurde. Das ist bei der Bildinterpretation zu berücksichtigen. Ein Einzelbild beweist weder flüssige Übergänge noch Geschwindigkeit, Eingabegefühl, GPU-Zeit oder Fold7-FPS. Die Bilder belegen keine neue Gesichts- oder Lippenanimation.

Keine Produktdatei wurde aufgrund dieser Prüfung geändert. Keine zusätzliche Gestaltungsrunde wurde gestartet.
