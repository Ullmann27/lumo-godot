# LUMO Kart: eigener Spielauftritt nach dem Referenzvergleich

## Auftrag und geprüfte Ausgangslage

Heinz verlangt einen deutlich aufwendigeren Spielauftritt: Hauptmenü, weitere
Strecken und wahrnehmbares Fahrfeedback sollen zusammen wie ein Kartspiel wirken.
Mario Kart World dient als Qualitäts- und Strukturreferenz, nicht als Vorlage zum
Übernehmen von Figuren, Strecken, Symbolen, Musik oder Grafiken.

Ausgangsquelle ist der am 13. November 2026 live geprüfte Native-Head von PR 157,
`ada5ed81ad62339f15289da62670c0a4f9f7f2b9`. Zugehöriger Flutter-Kandidat:
PR 461, `3c712129fef8f144d8946fad567b9ed11c628a60`. Diese bestehende
APK-/Recovery-Arbeit wird durch den getrennten Grafikzweig nicht ersetzt.

Die tatsächlichen aktuellen `landing-1280x720.png` und `landing-412x915.png`
aus der Quellenabnahme wurden betrachtet. Original-Lumo und das ausgewählte Kart
sind bereits echte 3D-Objekte. Die geschlossene, überwiegend dunkelblaue Garage
und die ähnlichen Schaltflächen bestimmen jedoch noch den gesamten Einstieg.

## Referenzen, tatsächlich gesichtet

| Quelle | Beobachtung beziehungsweise belegte Information |
| --- | --- |
| [Nintendo: Items & Techniques](https://www.nintendo.com/us/gaming-systems/switch-2/featured-games/mario-kart-world/items-and-techniques/) | Die offiziellen Bilder für Drift, Jump Boost und Rocket Start wurden heruntergeladen und betrachtet. Reifenkontakt, Auspuff und Aktion geben dem Effekt einen nachvollziehbaren Ursprung; die Figuren und der Fahrweg bleiben erkennbar. |
| [Nintendo: Ask the Developer, Chapter 2](https://www.nintendo.com/en-gb/News/2025/May/Ask-the-Developer-Vol-18-Mario-Kart-World-Chapter-2-2832717.html) | Die Entwickler beschreiben zusammenhängende Landschaftskontexte, markante Abschnittswechsel und gezielt lesbare Ziele. Das Interview erläutert auch den Aufwand für Tageszeit, Wetter und Performance. |
| [Nintendo: Modes](https://www.nintendo.com/us/gaming-systems/switch-2/featured-games/mario-kart-world/modes/) | Modusstruktur und Rennen durch miteinander verbundene Strecken. Daraus entsteht für LUMO keine Behauptung einer bereits vorhandenen offenen Welt. |
| [Nintendo Life: tatsächlicher World-Startbildschirm](https://www.nintendolife.com/guides/mario-kart-world-how-to-play-free-roam) | Das zugehörige Original-Screenshot wurde betrachtet: großer Fahrer in der Rennumgebung und wenige markante Auswahlzeilen. |
| [Unboxholics: tatsächliche World-Moduswahl](https://unboxholics.com/reviews/games/nintendo-switch-2/122535-mario-kart-world-review-to-proto-system-seller-tou-nintendo-switch-2) | Das zugehörige Screenshot wurde betrachtet: unterschiedliche Modussymbole und große aktionsbetonte Szene. |
| [SEGA: CrossWorlds 2.0 vom 4. November 2026](https://sonicracing.sega.com/en/details/0002126gfgbf5vluio.html) | Offizielle Menüüberarbeitung; das Bild der drei World-Match-Unteroptionen wurde betrachtet. Es zeigt keine vollständige Home-Ansicht. |
| [SEGA: CrossWorlds Features](https://asia.sega.com/SonicRacingCrossWorlds/en/about.html) | Strecken verändern sich über Runden und setzen erkennbare neue Ereignisse. LUMO übernimmt hieraus das Gestaltungsprinzip der Abwechslung, keine Travel Rings oder fremde Weltgestaltung. |
| [Activision: CTR Adventure](https://support.activision.com/uk/en/crash-team-racing/articles/adventure-mode-in-crash-team-racing-nitro-fueled) | Offizielle Beschreibung von erkundbaren Bereichen, Rennen, Fortschritt und Fahrzeuganpassung. Diese Quelle wurde gelesen; eine gesichtete CTR-Videoaufnahme wird nicht behauptet. |

Die externen Bilder dienen ausschließlich der Recherche. Kein fremdes Bild,
Logo, Charaktermodell oder Musikstück wird als LUMO-Spielasset eingecheckt.
Die folgenden Ziele sind eigene Designableitungen, keine Aussagen der Hersteller.

## Drei zusammengehörige Arbeitsbereiche

### 1. Einstieg als eigene LUMO-Szene

Die Landing-Ansicht öffnet sich zu einer warmen Sonnenhafen-Promenade. Original-
Lumo und das tatsächlich ausgewählte Kart bleiben die Hauptfiguren. Wasser,
Landschaft, eine erkennbare Straße und gestaffelte Tiefenebenen vermitteln schon
vor dem Start die Rennwelt. Die vorhandene Werkstatt bleibt beim Aufrufen ihrer
Funktionen erhalten. Dieselbe Auswahl, derselbe Viewport und die vorhandenen
Routen bleiben maßgeblich.

Hauptmodi bekommen unterschiedliche, verständliche Rennzeichen und eine klare
Auswahlreaktion. Die Startaktion bleibt sofort erreichbar. Kamerabewegung und
Umgebungsanimation müssen den bestehenden Modus für reduzierte Bewegung sowie
App-Pause und Wiederaufnahme respektieren. Ein sichtbarer Eintrag darf nur einen
tatsächlich angeschlossenen Spielmodus versprechen.

### 2. Zwei Strecken mit zusammenhängenden Höhepunkten

Winter-Sprint erhält eine alpine Staffelung aus Fels und Schnee, Bergstationen,
Seilbahn und einer Eisgalerie vor dem bestehenden Sprungabschnitt. Die Galerie
öffnet sich anschließend ins Panorama. Der neue Rahmen darf keine Fahrbahn oder
Landefläche verdecken oder blockieren.

Kristall-Canyon erhält einen eigenen geologischen Zusammenhang: eine Schlucht,
markante Kristallwände und ein breites Felsmotiv entlang der vorhandenen Route.
Große Silhouetten, beleuchtete Materialkontraste und gezielt freie Sichtachsen
sollen die Strecke charakterisieren. Neue Geometrie verändert keine existierende
Fahrkurve, Kollisionsregel oder Gegnerentscheidung.

Beide Module verwenden begrenzte Geometrie und vorhandene Batching-Mechanismen.
Die Prüfung berücksichtigt die räumliche Ausdehnung der Objekte sowie alle
relevanten Fahrbahnabschnitte, nicht nur einen Objektmittelpunkt.

### 3. Fahrereignisse sichtbar machen

Driftladung, tatsächlicher Turbo, Item-Aufnahme und Landung bekommen eine
zusammenhängende eigene LUMO-Effektsprache. Spuren entstehen an echten Reifen-
und Auspuffpositionen in Weltkoordinaten und verblassen zeitlich. Die vorhandenen
Ladestufen und Spielzustände steuern sie; die Grafik erfindet keine zusätzliche
Belohnung und verändert keine Geschwindigkeit.

Ein begrenzter Pool verhindert fortlaufende Objektvermehrung. Pause, Neustart,
Rücksetzen, Szenenwechsel und reduzierte Bewegung müssen korrekt behandelt
werden. Ein Teleport darf keine lange Spur quer durch die Welt erzeugen.

## Nachweise vor einer Ergebnisbehauptung

- Echter Import und zielgerichtete Tests auf dem kombinierten Quellstand.
- Native Touch-Eingaben für Moduswahl, Garage, Rückkehr und Rennstart.
- Tatsächliche Rendererbilder für 1280×720, 412×915, 690×829 und kurze
  Querformatansichten; Originalfigur, Kart, Straßenführung und Bedienelemente
  müssen sichtbar bleiben.
- Mindestens 48 dp große Touch-Ziele; keine neue Überdeckung durch Kulisse,
  Effekte oder Schaltflächen.
- Vergleichsaufnahmen mit gleicher Kamera und ausdrücklich benannter Quelle.
- Bestehende Gameplay-/Fahrphysikprüfungen bleiben erhalten. Kein Test wird
  abgeschwächt, um eine Grafikänderung durchzulassen.
- Rendererbilder und Headless-Tests sind keine Messung von 60 FPS, Temperatur
  oder Eingabelatenz auf dem physischen Fold7.

Dieses Dokument hält Auftrag, Recherche und Qualitätskriterien fest. Es ist
allein kein Implementierungs-, Grafikabnahme- oder APK-Veröffentlichungsnachweis.
