# Operation Next Level: bestehendes Kart-Menü

## Ausgang und Entwicklungsgrenze

Eigener Branch `computer/lumo-next-level-menu-2026-10-11`, Ausgang
`7cb03702d98578faa77f13ab02daf392af051dad` aus
[PR #55](https://github.com/Ullmann27/lumo-godot/pull/55).
Der ausgelieferte Produktcode 1928 bleibt zunächst auf
`6063f56fd4ff13afef61509f52d1d4fdab012654` aus
[PR #54](https://github.com/Ullmann27/lumo-godot/pull/54).
Die Differenz ist ausschließlich die dokumentierte Test-Ressourcenbereinigung.

Flutter-Fortsetzungsstand ist `bef1403ed5d0243f8c6daca2717e998081cab15e`
aus [PR #259](https://github.com/Ullmann27/lumo-lernen/pull/259).
Die tatsächliche 1928-APK verwendet Flutter-Produktquelle `8ba6b1f`.
Es wird weder `main` gemergt noch ein fremder Branch überschrieben.

## Tatsächlich festgestellte sichtbare Probleme

Der vorhandene Godot-Menütest wurde vor diesen Änderungen bei
2176 × 1812 Pixeln / Dichte 2,25 im GL-Kompatibilitätsrenderer ausgeführt:
52 Prüfungen, null Fehler, echter Screenshot. Trotzdem sind sichtbare
Abweichungen zur bestätigten Referenz `50665.jpg` vorhanden.

- **Heller Rand:** Der originale Hintergrund enthält selbst einen weißen
  rechten Rand ab x = 1069 und einen unteren Rand ab y = 1907.
  Dies ist in den tatsächlichen WebP-Pixeln nachgewiesen.
- **Safe-Area-Hintergrund:** Die bisherigen Hintergründe füllen nur das
  eingerückte Bedienfeld, nicht zuverlässig die gesamte Fläche.
- **Bühne:** Zu große Leuchtringe verlassen links und rechts die Vorschau.
- **Materialwirkung:** Sehr harte lokale Glanzlichter erzeugen fleckige
  weiße Reflexe auf dem vorhandenen Kart.
- **Hinweis:** Weiße kleine Schrift liegt ohne Kontrastfläche auf dem
  detailreichen Weltbild.

## Begrenzte Korrektur

Das neue `kart_menu_art.gd` schließt ausschließlich den bereits eingebrannten
hellen Rand beim Sampling aus. Die Originaldatei wird nicht verändert.
Das bestehende Menü besitzt weiterhin alle tatsächlichen Setup-Schritte,
native Eingaben, reale Modi und genau eine große Weiter-Aktion.

Die Weltillustration bleibt ein originales 2D-Hintergrundbild. Lumo, Kart und
die neue transparente Leuchtbühne sind echte 3D-Laufzeitobjekte.
Eine vollständig dreidimensionale Fantasy-Hintergrundwelt wird nicht behauptet.
Das bestehende 65-Knochen-Modell, seine Texturen und neun Clips bleiben unverändert.
Keine neue Gesichtsanimation oder Lippensynchronisation wird behauptet.
Rennphysik, Kollisionen, Profile, Belohnungen und Sulafat werden nicht verändert.

## Abnahme

Die begrenzte Menükorrektur ist lokal implementiert und visuell geprüft.
Die weitergehende AAA-Abnahme ist davon zu unterscheiden: Die Hintergrundwelt
ist weiterhin eine 2D-Originalillustration, das bestehende Kart erreicht noch
nicht jede Form-/Materialeigenschaft der Originalreferenz, und eine physische
Samsung-Abnahme sowie ein neuer Android-Build stehen aus.

- **11 Größen-/Dichte-/Randkonfigurationen:** echter GL-Lauf, 752 Prüfungen,
  null Fehler einschließlich 28 realen Begrüßungsframes und 84 projizierten
  Kopf-/Handgelenkprüfungen. Orphan-Nodes 0 → 0.
- **Headless-Menümatrix:** 628 Prüfungen / null Fehler vor der letzten ovalen
  Bühnenform; dieselben Geometrieprüfungen liefen anschließend vollständig
  im tatsächlichen GL-Renderer. Keine Tests wurden abgeschaltet.
- **Touch-Menüweg:** echter GL-Lauf, Cup und anderes Kart ausgewählt,
  fünf native Setup-Schritte, Rennen mit fünf Gegnern gestartet; 1280 × 720,
  800 × 480, 640 × 320 mit expliziten 16/32/16/48-Pixel-Systemrändern.
  Dieser Lauf fand vor der letzten rein visuellen ovalen Bühnenform statt;
  CI wiederholt den vollständigen Menüweg auf dem Commit.
- **Bestehende Rennanimation:** 2.069 Prüfungen / null Fehler, tatsächlicher
  Rampenflug mit 36 Physikframes, Handkontakt höchstens ca. 1,14 mm.
  Der Zieleinlauf ist eine ausdrücklich dokumentierte Finish-Fixture,
  kein neu vollständig durchgefahrener Drei-Runden-Nachweis.
- **Laden:** 88 reale Headless-Prüfungen / null Fehler, inklusive bestehendem
  Ressourcenloader, unveränderten Modelltexturen, Fehler, Retry und echtem
  Szenenwechsel. Kein erfundener Ladeprozentsatz.
- **Fold-Dichtefixture:** 2176 × 1812, Dichte 2,25, 967,1 × 805,3 dp.
  Moduskarte ca. 338,5 × 72,1 dp, Weiter 240 × 72,1 dp.
  Alle fünf Modi passen gleichzeitig; Mindestaktionen weiterhin ≥ 48 dp.
- **Statisch:** Projektvalidator 117 PASS / 7 bestehende WARN / 0 FAIL;
  vier vorhandene Streckenpakete und Sky-Halo-Authoring-Vertrag erfolgreich.

Alle neuen Bildbelege stammen aus Linux, Godot 4.6.3, GL-Kompatibilität,
Mesa/llvmpipe. Es gibt rendererbedingte V-Sync-/AA-/Fog-Warnungen; „warnungsfrei“
wird nicht behauptet. 10 gespeicherte Videobilder/s sind eine Aufnahmerate,
keine gemessenen Android-FPS. Die 48 Sterne sind isolierte Screenshot-Testdaten.
Die abschließenden Vergleichsaufnahmen verwenden ein eigenes frisches
XDG-Testverzeichnis ohne gespeichertes Testrennen. Keine echten Kinderprofile.

## Erhaltene Quelldateien

- **Original-Weltbild:** SHA-256
  `0bdf969d0a3662367a7473820e05044e5bd8b3ab8df12e209db256d4db94e8dd`.
- **Original-Rig-GLB:** SHA-256
  `3559f700784bc1006905ee3aae01e8bcfbffb95b4f621f7430ce771ba0e3efd5`.

Der neue Kamerafit tastet sichtbare Chassis-/Reifen-Geometrie, die tatsächliche
Kopfposition und die Leuchtringe ab. Ein erster zu großer Standfigur-Rahmen
machte Lumo klein und wurde nach dem echten Bildvergleich ersetzt.
Eine erste schmale Hinweisfläche verursachte vertikalen Buchstabenumbruch;
dieser Fehler wurde repariert und besitzt nun eine eigene Regression.

## Anschließende Nutzerwünsche

Nach dieser Kart-Menü-Etappe werden die alten Lernansichten „Formen“ und
„Zahlen bis 10“ sowie Lumo Cards modernisiert, nicht erst nach allen großen
Streckenarbeiten. Die hochgeladenen `51009.jpg`, `51007.jpg` und `51012.jpg`
sind echte Vorher-Belege; `50723.png` ist die Lumo-Cards-Zielreferenz.
Keine dieser Flutter-Änderungen ist in dieser Menüetappe bereits fertig.

Die neueren Aufnahmen `51018.jpg`, `51020.jpg`, `51022.jpg` bestätigen
weiterhin die alten Formen-, Minus- und Zahlenoberflächen. `51024.jpg`
zeigt das bereits vorhandene Plus-bis-10-Mathe-Abenteuer, dessen originaler
Lumo, Bibliothekswelt, Hologlasflächen, Fortschrittsanzeige und große blaue
Antworten ausdrücklich als gemeinsame Grundlage für die übrigen Aufgaben
verwendet werden sollen. Keine zweite Designbibliothek und keine Neuschreibung
der Aufgabenbewertung.
