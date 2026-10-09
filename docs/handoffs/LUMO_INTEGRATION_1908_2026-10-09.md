# Lumo 1908 – gemeinsamer Quellstand, noch keine APK-Freigabe

Status: **VISUAL_GAP / NOT FINISHED**. Dieser Eintrag ersetzt frühere Aussagen über
verlorene oder noch ausstehende Recovery3-Läufe. Historische Nachweise bleiben
historisch und werden nicht auf neue Quellen übertragen.

## Tatsächliche Stände und Verbindung

- Godot BASE dieser Integration: `99cdb776df10e8cc719d19792c17074c887b5112`.
  Die 14 Karts, Werte, Werkstatt, Item-Anzeigen und Sky-Retention bleiben erhalten.
- Zweiter Integrationsparent: Recovery `4bdbaf9a237bd3170f833db365c67731ec3fb13a`;
  dessen zwei Runtime-Test-Cleanups werden unverändert übernommen.
- App BASE des getrennten 1908-Arbeitsbaums:
  `36391b2d2a332e93f3bac46bf21afb83fad15d8a`; vorbereitet als `0.12.5+1908`.
  Der gespeicherte Pin bleibt vorerst 99cdb. Eine spätere Änderung erfordert
  den endgültigen Godot-Head und aktuelle, unverfälschte positive Runtimebelege.
- Fremder tatsächlicher Build 1907: Actions `37880993479`, App 36391 / Godot 99cdb.
  Build erfolgreich; Android-Kart-Prüfungen 35/36 zuletzt noch laufend.
  Sein APK-Inhalt wurde hier noch nicht unabhängig heruntergeladen/verifiziert.
- Main und Release werden nicht geändert. Keine 1908-APK gebaut oder ausgeliefert.

## Bestandsmatrix

| Bereich | Stand | Konkreter Nachweis / offene Lücke |
|---|---|---|
| App/Godot-Host, Ergebnis-ID/ACK/Rückkehr | vorhanden, aktuelle Integration noch nicht Android-geprüft | Recovery4bdb: 104 Runden + 10 Lifecycle und zwei vollständige Touch-Abläufe mit je16 Toren/9 Prüfungen |
| 14 Karts, Werte, Tuning | vorhanden | aktuelle99-basierte Headless-Werte-/Geometrieprüfungen und unabhängiger14er-LOD-Vergleich bestanden |
| Profilbezogenes Werkstattbudget | bestätigt fehlerhaft, hier repariert | gleicher24er-Test: BASE9PASS/15FAIL → Kandidat24PASS; identischer ursprünglicher7er-Fall ebenfalls grün |
| Sonnenhafen-Licht HIGH | visuell unzureichend, begrenzt verbessert | drei gepaarte echte GL-Ansichten: Clipping−20,15/32,40/41,58%; Kontrast erhalten; vollständige Integration noch zu rendern |
| Zieleinlauf/Kamera | bestätigt fehlerhaft und visuell unzureichend | echtes Ausrollen verlässt Fahrbahn, große nahe Bauteile verdecken Resultat; separater Versuch läuft, hier noch nicht übernommen |
| LOW, bewegte Kanten und Referenzvideo | nicht getestet auf neuem Grafikstand | LOW-Werte bleiben erhalten; keine Referenzvideo-Bewegungsabnahme behauptet |
| Android/Fold, Langzeitstabilität, CPU/GPU/Speicher | nicht getestet für1908 | Emulator, physisches Fold und Geräteperformance getrennt; keine60-FPS-Zusage |

## Änderungen und ihre Grenzen

ProgressStore speichert je gültigem `childKey` einen nicht sinkenden Lifetime-Zähler
in der bestehenden `progress.cfg`. Neue Schlüssel erben keinen anderen Profilbestand.
Ausgebbare Sterne kommen unverändert vom Flutter-Host; Belohnung/ACK/Race-Save bleiben
unverändert. Alte Hosts ohne Schlüssel und Standalone behalten den skalaren Altbestand.
Der Fehler ist für unterschiedliche Host-Schlüssel reproduziert, nicht für einen
normalen Android-Profilreset: Dieser löscht native Fortschritts-/Werkstattdateien.

Die bestehenden Runtime-Test-Cleanups halten ihren Startup-Sky bis nach dem letzten
Draw und lassen einen fertigen Draw vor dem natürlichen Test-Rebuild zu. Assertions
und Grenzwerte bleiben unverändert. Sie ersetzen keine Produkt-Physik.

Sonnenhafen HIGH erhält nur drei Lichtwerte: Ambient0,20, Sonne0,68, Exposure0,94.
LOW behält0,28/0,84/1,03. Keine anderen Welten, Renderer, Meshes oder Shader werden
ersetzt. Der Nutzen ist bescheiden; Ferne, Geländer und Fell/Stoff bleiben offene
visuelle Abweichungen.

## Tatsächliche Prüfungen

- Recovery4bdb unabhängig geschlossen: GL104+10, Zeit29, zweimal Original-Flow9
  mit16 geordneten Toren/sechs echten PNGs, ACK/eine Belohnung/kein neuer Race-Save.
  Original-BASIS c95:54PASS/50FAIL und Lifecycle7PASS/3FAIL. Diese gelten nicht
  als Runtimeabnahme der neuen99-basierten1908-Quellen.
-99-basierter Profil/Cleanup-Kandidat vor Lichtgraft:24Profil+104Runden+10Lifecycle
  +29Zeit PASS; FleetStats, unveränderte Vehicle/Details/ArmContact/SteeringGrip
  und zusätzlicher unabhängiger14-Design-LOD-Lauf PASS. Headless, keine Geräte-FPS.
- App1908-Draft:579QA+36Scripts PASS, keine Skips; unabhängig68 Quell-/AST-Prüfungen,
  22Bashsteps/sechs Pythonblöcke syntaktisch geprüft. 48 ursprüngliche QA-Dateien,
  sechs Scripts-Dateien,17 GL-Proben/24 Native-Marker und fremde IQ/Flutter-Arbeit erhalten.
- Validator117PASS/7WARN/0FAIL. Vollständiger Lint ist nicht grün: BASE644,
  Kandidat645 Alt-/Strukturmeldungen; hinzu kommt der erhaltene1002-Zeilen-Test
  über dem1000-Limit. Format62 historische Dateien; kein Massenrewrite für grün.

## Quellen und nächster Schritt

Vorhandene Projekt-Implementierungen, Godot4.6 `ConfigFile`, `Environment` und
`RenderingServer`-Dokumentation sowie offizielles gdtoolkit4.5(MIT) zur Prüfung.
Keine fremden Figuren/Welten oder blind übernommener Runtimecode.
Offizielle4.6.3-Enginebytes geprüft; angezeigte Source-Commit-Zuordnung bleibt
ungeklärt und ist keine bestätigte allgemeine Engineursache.

Nächster Schritt: Zieleinlaufversuch anhand fester Kriterien abschließen; akzeptierte
Änderung separat übernehmen. Danach exakten gemeinsamen Head einfrieren, vollständige
Native-/Touch-/GL-Abläufe samt Bildern prüfen, Produktionsreader ohne historische
Binding-Overrides positiv prüfen, App-Pin setzen und1908 bauen. Erst tatsächliche
APK-/Android-Auswertung erlaubt eine Auslieferung; Referenztreue bleibt offen.
