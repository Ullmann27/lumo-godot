# Dorf-Kampagne – Vorschlag für Etappe 2 (noch nicht umgesetzt)

Stand 18.11.2026, nach Etappe 1 (Grafik und Welt). Dieser Vorschlag baut auf
der neuen Karte (`assets/creative/village3d/terrain/village_heightmap.tres`)
und den vorhandenen 12 Kapiteln in `build_settlement_economy.gd` auf. Spielregeln,
Wirtschaft und Speicherformat sind hier **nicht** verändert; jede Änderung daran
gehört in Etappe 2 mit eigenen Tests.

## Leitidee

„Lumos Tal“ – eine erzählte Geschichte über eine Saison: Vom ersten Zelt am
Fluss bis zur Stadt, die mit dem Nachbardorf ein Fest feiert. Jedes Kapitel hat
einen Schauplatz auf der Karte, eine Figur, die erzählt, ein klares Ziel und
einen Lernbezug (Zählen, Rechnen, Planen, Lesen, Sachunterricht). Kinder sehen
den Fortschritt an Bauwerken in der Welt, nicht nur an Zahlen.

## Figuren

| Figur | Rolle | Modell |
|---|---|---|
| Lumo | erzählt, zeigt Wege, läuft durchs Dorf | echter geriggter Lumo (`lumo_rigged_actor.gd`) |
| Nelli (Hase) | Felder, Wasser, Brot | vorhandene Dorffreundin |
| Bruno (Biber) | Holz, Stein, Brücken | vorhandener Dorffreund |
| Tilda (Ente) | Handel, Lieferungen am Steg | vorhandene Dorffreundin |
| Löwe, Eule, Hase Nova, Eichhörnchen, Schildkröte | Nachbarn, Bootsleute, Kutscher, KI-Mitbauer | Roster (`lumo_opponent_roster.gd`), sitzende Posen auf Booten/Wagen; Lauf-Animationen kommen mit dem Figuren-Neubau |
| Mira (Nachbardorf) | freundliche Mitbauerin im Osten | Roster-Figur, eigene Stadt auf derselben Karte |

## Schauplätze auf der neuen Karte

- **Wiesenwinkel** (Ortsmitte West, x≈−100): erste Felder, flach, immer bebaubar.
- **Flussufer und Liefersteg** (x≈±6, z≈9): Tildas Boote, Lagerhaus.
- **Wassermühle** (Westufer, z≈−30): Mühlrad dreht sich – Brot-Kapitel.
- **Drei Steinbrücken** (z = −58 / 0 / 58): Verbindung zum Nachbardorf.
- **Felshügel mit Wachtürmen** (z. B. x≈−172/z≈50): nicht bebaubar – Aussicht,
  Erkundung, Sternenbeobachtung.
- **Bergsee West/Ost** (x≈∓230): Ausflugsziel, Quellwasser.
- **Nordgebirge mit Schnee**: Abenteuer-Kapitel (Wetter, Höhe, Tiere).
- **Südküste mit Strand**: Fest am Meer im Finale.
- **Nachbardorf Ost** (x≈+100): Miras Stadt wächst sichtbar mit.

## Kapitelstruktur (5 Akte, 15 Kapitel)

| Akt | Kapitel | Schauplatz | Ziel im Spiel | Lernbezug |
|---|---|---|---|---|
| I Ankommen | 1 Ein Zuhause im Wiesenwinkel | Wiesenwinkel | Wohnhaus + Bauernhof | Zählen bis 10, Rohstoffe erkennen |
| | 2 Wasser für alle | Wiesenwinkel/Fluss | Brunnen, 4 Bewohner versorgen | Mengen vergleichen (mehr/weniger) |
| | 3 Brunos Werkstatt | Waldrand | Holzwerkstatt + Steinbruch | Ursache–Wirkung (Produktion pro Tag) |
| II Handel | 4 Tildas erster Handel | Liefersteg | Markt, Tausch | Plus/Minus bis 20, Tauschwert |
| | 5 Zwei von zehn für die Stadt | Ortsmitte | 10 Münzen, Stadtkasse | Anteile/Brüche spielerisch (2 von 10) |
| | 6 Vom Korn zum Brot | Wassermühle | Kornfeld, Bäckerei, 3 Brote | Reihenfolgen, Prozesse |
| III Wachsen | 7 Platz für eine Familie | Lernhaus | Lernhaus, erstes Kind | Lesen kurzer Sätze (Schulglocke) |
| | 8 Unsere gemeinsame Brücke | Mittlere Brücke | Lieferbrücke finanzieren | Planen und Sparen über Tage |
| | 9 Ein Dorf mit vielen Aufgaben | Erweiterte Ortsteile | 24 Bewohner, 6 Gebiete | Einmaleins-Vorstufe (Reihen von Häusern) |
| IV Gemeinschaft | 10 Füreinander sorgen | Fürsorgehaus | Fürsorgehaus, Spielplatz, Bewässerung | Sachunterricht: Gesundheit |
| | 11 Aus Nachbarn wird eine Stadt | Nachbardorf | Kooperation mit Mira (gemeinsames Projekt) | Fairness, Vergleich zweier Städte |
| | 12 Das Wachturm-Rätsel (neu) | Felshügel | Aussichtspunkt erreichen (Lumo laufen) | Orientierung, Karte lesen, Himmelsrichtungen |
| V Großes Lumo-Land | 13 Quelle am Bergsee (neu) | Bergsee West | Wasserleitung planen | Längen schätzen, Höhe/Gefälle |
| | 14 Der Sturm im Gebirge (neu) | Nordgebirge | Vorräte für 3 Tage | Vorausplanen, Vorrat rechnen |
| | 15 Fest an der Küste (neu) | Südküste + beide Dörfer | 80 Bewohner, alle Gebiete, Fest | Rückblick, Lesen einer kleinen Geschichte |

Die heutigen Kapitel 1–11 bleiben inhaltlich erhalten (gleiche Ziele, gleiche
IDs), Kapitel 12 („Das große Lumo-Land“) wird zum Akt-V-Bogen 13–15 ausgebaut.

## Erzählform

- Kurze Zwischenszenen mit fester Kamera (Startblick, Brücke, Mühle, Hügel),
  vorgelesener Text (vorhandene Stimme) und Lumo-Gesten (`greet`, `point`,
  `celebrate`).
- Pro Kapitel eine sichtbare Veränderung der Welt: Fahne auf dem Wachturm,
  Boot am Steg, Laternen an der Brücke, Feuerwerk im Finale.
- Kapitelkarte (`build_campaign_map.gd`) zeigt Akte als Wege durch das Tal.

## KI-Nachbar und Freibau

- Mira baut im Osten nach denselben Regeln (vorhandener Rival-Plan) – künftig
  sichtbar als Baustellen mit Gerüst (Gerüst-Modell ist schon da).
- Freibau bleibt nach jedem Kapitel offen; Kapitelziele blockieren nie.

## Technische Vorbereitung aus Etappe 1

- Bebaubarkeit pro Feld ist im Modell (`plot_buildable`) – Kapitel können
  „Bau auf Wiese X“ verlangen, ohne neue Regeln.
- Landmarken (Mühle, Wachtürme, Brücken, Steg, Lager) sind Szenenknoten mit
  festen Positionen – geeignet als Kapitel-Ziele und Kamera-Anker.
- Tageszeit (`set_time_of_day`) und Tageswechsel-Lauf können Zwischenszenen
  tragen.

## Offene Fragen an Heinz

1. 15 Kapitel oder bei 12 bleiben und Akt V verdichten?
2. Soll Mira im Kapitel 11 sichtbar „mitspielen“ (KI-Züge pro Tag) oder nur
   als Erzählfigur auftreten?
3. Lernbezug pro Kapitel fest oder an die Klassenstufe des Kindes gekoppelt?
