# Lumo Kart: Strecken und Landschaften — 23. November 2026

## Integrierter Ausbau

Alle 15 Produktionsstrecken verwenden die gemeinsame Erweiterung. Der tatsächliche
native Prüflauf zählt **59 zusätzliche befahrbare Aktionssequenzen**
und **207 thematische Landschaftsgruppen**. Diese Zahlen bezeichnen den
zusätzlichen Ausbau, nicht die Gesamtzahl aller bereits vorhandenen Streckenelemente.

| Strecke (interne ID) | Zusätzliche Aktionssequenzen | Landschaftsgruppen | Befahrbare Loop-Abzweigung |
| --- | ---: | ---: | --- |
| sonnenhafen | 3 | 13 | Ja |
| zauberwald | 3 | 11 | Nein |
| bergwelt | 4 | 12 | Nein |
| holo_city | 4 | 12 | Nein |
| crystal_canyon | 4 | 12 | Nein |
| jungle_temple | 4 | 12 | Nein |
| candy_cloud | 4 | 12 | Ja |
| volcano_night | 4 | 12 | Ja |
| winter_sprint | 3 | 12 | Nein |
| galaxy_ringway | 4 | 12 | Ja |
| desert_drift | 4 | 12 | Nein |
| learning_lab | 4 | 12 | Nein |
| jungle_emerald_3600 | 6 | 25 | Nein |
| riesengarten_2400 | 3 | 17 | Nein |
| windwerk_3000 | 5 | 21 | Nein |

Panorama-Schanzen, Engstellen und alternative Turbospuren berücksichtigen belegte
Abschnitte und Schutzabstände. Die sichtbare Rampenoberfläche verwendet dasselbe
Kontaktprofil wie die Fahrphysik. Landschaftsgruppen verwenden gebündelte Instanzen,
Entfernungsstufen und thematische Leucht- beziehungsweise Bewegungseffekte.

## Zusammenhängende Loopings

Sonnenhafen, Candy Cloud, Volcano Night und Galaxy Ringway behalten eine
durchgängige Hauptstraße und erhalten angeschlossene Loop-Abzweigungen mit
Zufahrt, Loopbahn und Rückführung. Renderdeck, Kartposition und Kartorientierung
verwenden dieselbe räumliche Bahn. Auch innerhalb des Loops wirken die
tatsächlichen Fahrzeugfaktoren auf Antrieb, Bremsen und seitliche Reaktion.

Die Nahtprüfung bleibt unverändert streng: 3 mm Höhen-, 5 mm Quer-,
2,5 Grad Tangenten- und 1 cm Breitendifferenz. Die vollständige native
Abnahme wiederholt sie für alle vier Loop-Verbindungen.

## Präzisionssprung und unterschiedliche Fahrzeugaufbauten

Eine sichtbar markierte Bremshilfe vor dem Sonnenhafen-Präzisionssprung verwendet
die tatsächlichen normalen Bremskräfte des montierten Karts. Der Flug selbst
erhält keine nachträgliche Positionskorrektur. Die Landung erfolgt vor dem
folgenden Tunnel.

Die Reihenfolge der Kontaktprüfung wurde an einem echten Fehler korrigiert:
Überquert ein Physikschritt die Absprungkante und den nur 0,5 m später beginnenden
Spalt gleichzeitig, muss zuerst der überquerte Rampenabsprung ausgewertet werden.
Unabhängiges Hineinrollen beziehungsweise Rückwärtsfahren in eine Lücke bleibt
ein freier Fall. Fünf zeitliche Phasen einschließlich drei gleichzeitiger
Lippen-/Spaltüberquerungen und zwei unabhängige Fallfälle sind geprüft.

Im tatsächlichen Godot-4.6.3-GL-Lauf ergeben sich:

| Montierter Aufbau | Einfahrtempo | Tempo an der Lippe | Abstand der Landung zum Tunnel |
| --- | ---: | ---: | ---: |
| Stella, vollständig ausgebaut, schnellster gemeinsamer Tempo-/Boostsatz | 107,842 m/s | 61,785 m/s | 76,58 m |
| Gleicher Stella ohne Bremsen-Ausbaustufen, leichte Bremse | 107,842 m/s | 61,785 m/s | 76,72 m |
| Gecko Velo ohne Ausbaustufen, leichte Bremse | 68,708 m/s | 61,785 m/s | 76,04 m |

Alle drei durchfahren die Bremshilfe, heben tatsächlich ab und landen ohne
Rücksetzung. Die kostenpflichtigen Teile werden im Test über die echten
Freischalt- und Montage-APIs eingesetzt.

## Freie Fahrbahn und sichtbare Landschaft

Die vollständigen Fußabdrücke der Galaxy-Planeten samt Ringen halten Abstand
zur gesamten Straße und zum Außenloop. Drei große Planeten behalten ihren
Radius von 30 m; ihre Ringe haben nun 42 m Außenradius und sind außerhalb
der Kugeln sichtbar. Die real gerenderten Instanzen werden geprüft:
zwölf normale Planetenringe, drei große Kugeln und drei große Außenringe.

Die zuvor gleichförmig grüne Fläche im Zauberwald ist das Dach des Feensee-
Unterwasserabschnitts. Sie wird mit dem vorhandenen Wassershader dargestellt.
Die Wassergeometrie bleibt erhalten. 45 Positionen und Spuren verwenden die
echte Spielkameramethode; im geprüften Abschnitt bleiben mindestens 1,591 m
Abstand unter dem Dach. Die seitliche Landschaftsaufnahme steht oberhalb des
Wassers, nicht unter dem Inselterrain. Ihr Blick wurde nicht verschoben.

## Nachweis und Grenzen

Die gezielte Prüfung auf Quelle `096866a09c9d8579132cdc8b7da197aca1c8a3f3`
ist vollständig erfolgreich:
https://github.com/Ullmann27/lumo-godot/actions/runs/45141398931

Sie verwendet Godot 4.6.3 mit echtem OpenGL-Compatibility-Renderer und enthält
vier unveränderte PNG-Aufnahmen, Messwerte und vollständige Protokolle.
Artefakt: `kart-diagnostic-proof-45141398931`, ID `14802965550`.

Der anschließende Gesamtlauf prüft zusätzlich alle Fahrzeuge, Loop-Nähte,
den Online-Ablauf und Bilder aller fünfzehn Strecken. Der APK-Bau akzeptiert
nur einen insgesamt grünen nativen Lauf des exakt eingebetteten Quellcommits.
Diese Prüfungen ersetzen keine Messung von 60 FPS auf einem physischen
Android-Gerät.
