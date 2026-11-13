# Gemeinsamer Szenenabbau: sechs Renderer-Verbraucher

Die sechs vorhandenen Kart-Probes verwenden jetzt den eingefrorenen Helper
`scripts/tests/helpers/kart_scene_teardown.gd`. Erfolg wird erst ausgegeben,
wenn die echte Szene und ihre beobachteten Audio-Playbacks freigegeben sind.
Ein fehlgeschlagener Abbau führt zu FAIL und Exit 1. Die Helper-Datei wurde
von diesem Teilauftrag nicht verändert.

**Alle sechs bestehenden CI-Verträge verlangen den Renderer. Diese
Renderer-Gates wurden hier nicht ausgeführt.** Drei Probes erlauben zusätzlich
einen unveränderten Headless-Lauf ihrer Logik; die anderen drei wurden
hier ausschließlich geparst. Ein frischer CI-Lauf muss die echten
Rendererprüfungen ausführen.

## Konkreter Anschluss

- PauseLayout prüft Garage, Rennszene und den eigenen Host vor PASS. Sein
  begründeter verzögerter Quit bleibt erhalten.
- PlayerFullRoute sichert seine tatsächlichen Fahrdaten vor dem Abbau. Sowohl
  Terminalstatus als auch JSON-Bericht werden danach ausgegeben. Die bisherigen
  festen Ersatzwartezeiten sind durch den beobachteten Abbau ersetzt.
- Garage3DTouch prüft beide Szenen separat; MenuDepth prüft seine Produktionsszene.
- RivalFlight prüft seine Szene vor dem endgültigen PASS. Zwischenmeldungen
  lauten jetzt „checked“, damit kein vorgezogener PASS erscheint.
- StuntContinuity besitzt erstmals einen ausdrücklichen geprüften Szenenabbau.

Bestehende Assertions, Eingaben, Save-/abandoned-Logik und notwendige
Layoutframes sind erhalten. Der unveränderte Helper begrenzt den Abbau auf
2000 Millisekunden realer Zeit und meldet gehaltene konkrete Klassen.

## Tatsächliche lokale Ergebnisse

| Probe | Lokaler Umfang | Ergebnis |
|---|---|---|
| PlayerFullRoute | Headless-Logik und echter Abbau | Sauber; drei Playbacks nach 82 ms frei |
| Garage3DTouch | Headless-Logik und echter Abbau | 27 Checks; native Szene 65 ms, Legacy-Szene 53 ms |
| MenuDepth | Headless-Logik und echter Abbau | 41 Checks; ein Playback nach 51 ms frei |
| PauseLayout | Ausschließlich Parse-Prüfung | Exit 0, keine Parse-/Enginefehler |
| RivalFlight | Ausschließlich Parse-Prüfung | Exit 0, keine Parse-/Enginefehler |
| StuntContinuity | Ausschließlich Parse-Prüfung | Exit 0, keine Parse-/Enginefehler |

Die drei regulären Laufprotokolle enthalten keine geprüften Engine-,
Script-, Parse- oder Leakfehler. Alle 858 erfassten Produkt-/Asset-/Szenen-,
Verbraucher-, Basis-, Helper- und Runnerdateien blieben während der Prüfungen
unverändert. Die disjunkten Verbraucherdateien der anderen Agenten gehören
nicht zu diesem Laufmanifest. Das ist kein Stempel für den gesamten
zwischenzeitlich bearbeiteten Repositorybaum.

## Isolierter abgeleiteter Fehlerlauf

`negative-held-playback/` enthält einen ausdrücklich abgeleiteten
Fault-Injection-Lauf des unveränderten PlayerFullRoute-Verbrauchers. Nur die
externe Fixture hält am tatsächlichen Zieleinlauf eine reale
`AudioStreamPlaybackOggVorbis`-Referenz fest. Verbraucher, Produktion und Helper
bleiben unverändert; deren Hashes sind vor und nach dem Lauf belegt.

Nach 2004 ms meldet der Helper die bereits freigegebene Szene und die absichtlich
gehaltene Audioklasse. Der Verbraucher und der unveränderte strenge Runner
enden mit Exit 1. Es erscheint kein `[PlayerFullRoute] PASS`. Der vollständige
Original-JSON-Bericht enthält `status: FAIL`, obwohl der echte Fahrverlauf
16 Checkpoints, zwei Loops, acht Sprünge, acht Landungen und keinen Reset
erreicht. Der gespeicherte Report ist ein Fehlernachweis, keine Freigabe.

Nur `kart_regression.gd` im getrennten Root-Auftrag war zuvor als tatsächlicher
CI-Abbaufehler belegt. Die sechs hier angeschlossenen Probes schließen konkret
im Quellcode gelesene fehlende Freigabebedingungen. Der isolierte negative Lauf
wird nicht als ursprünglicher Produktions- oder CI-Fehler ausgegeben.

## Originale und Wiederprüfbarkeit

`manifest.json` enthält für jede gespeicherte Datei Original- und Speicherhash,
Größe, Herkunft und Kompression. Alle gzip-Dateien sind verlustfrei mit
`mtime=0` gespeichert und wurden nach dem Schreiben zurückdekodiert und
bytegenau mit der Originalquelle verglichen. Die ursprünglichen und die
geprüften sechs Quellversionen, der unveränderte Helper, das exakte Delta,
sämtliche Rohlogs und die vollständigen Fahrberichte sind enthalten.

Der Ausgangscommit ist `a59dca033d1ad6afa4afbf0b51b03e04fe8c4ef9`.
Die Änderungen lagen bei den Prüfungen uncommittet im eigenen Integrationsbaum.
Kommandos, Zeiten und die ausdrücklichen lokalen Prüfgrenzen stehen in den
unveränderten Ergebnisdateien. Es gab keinen Commit, keinen Ref-Eingriff,
keinen CI-Rerun und keine Renderer- oder Androidfreigabe durch diesen Auftrag.
