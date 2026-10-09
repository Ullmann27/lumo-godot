# Dauerhafte Rundenzeiten und sichtbare Ergebnisse · 9. Oktober 2026

BASE ist exakt `c95fc489219223e3d66e8ed1a7a4dbe933b05f08`, Tree
`88ea7aa46b05bd8a702770b95fa0709311d39ab0`. Das freie lokale Paket liegt auf
`codex/lumo-lap-session-2026-10-08`; maßgeblicher RESULT ist danach der
frische integrierte HEAD von Godot-PR29, nicht dieser lokale BASE-HEAD.
Root koordiniert die Integration und den anschließenden
exakten App-Pin für1906. Kein Main-/Release-/APK-Abschluss wird hier behauptet.

Ein tatsächlich gefahrenes Rennen beweist den Fehler: Nach der ersten Runde
26.183333 Sekunden wurde bei Gate10/32.316667 Sekunden pausiert und die echte
ConfigFile gespeichert. Eine neue Spielinstanz behielt Fortschritt und
Ergebnis-ID, verlor aber `lap_times` und `lap_started_at`. An Gate16 meldete sie
fälschlich51.283 Sekunden als beste Runde statt der tatsächlich gemessenen
zweiten Runde25.100 Sekunden. Ein erneutes Öffnen des abgeschlossenen Ergebnisses
entfernte die sichtbare Beste-Runde-Zeile ganz. Zusätzlich publizierte derselbe
Lauf Gesamtzeit51.3, während die echte UI51.283 zeigte. Die nachfolgenden
natürlichen Läufe haben eigene gemessene Zeiten; nichts wurde auf passende
Zehntelsekunden gesetzt.

Das kleine Produktpaket speichert beide Rundenfelder in der bestehenden atomaren
ConfigFile. Beim Wiederherstellen werden Typen, endliche positive Intervalle,
Startzeit, Summen und tatsächlich absolvierte Gates gemeinsam geprüft, nach der
bestehenden v1/v2-Gatekorrektur. Fehlende/ungültige spätere Runden erhalten
`lap_started_at=-1` als ausdrücklich unbekannte Messung. Dieser Zustand überlebt
weiteres Speichern; die unvollständige Runde wird nicht erfunden, erst an der
nächsten geordneten Linie beginnt wieder eine vollständig messbare Runde.
Erste-Runde-Altsaves behalten den bekannten Rennstart0. Für bereits fertige
Altsaves zeigt die UI den vorhandenen positiven endlichen Payload-Bestwert,
sofern er nicht größer als Gesamtzeit plus0.001 Sekunden ist, ohne neue Historie,
Belohnung oder Payloadänderung zu erzeugen. Zukünftige Ergebnisse veröffentlichen
`elapsedSeconds` auf0.001 statt0.1 Sekunden, passend zur vorhandenen UI.
Physikzeit, Rekorde, Belohnungsschwellen, Ergebnis-ID, ACK und Datenfeldtypen
bleiben erhalten. Es gibt keine neue Abhängigkeit und keinen neuen Renderer.

Die vorhandene Continuity-Probe behält alle45 ursprünglichen Assertions. Sie
bekommt103 zusätzliche Werteprüfungen (alle97 Timingbedingungen plus sechs
ResultUI-Bedingungen vor/nach dem nächsten normalen Physiktick): tatsächlich gefahrene16 Gates mit
Lap2-Pause, Grafikwechsel und NEW-instance Resume; exakte Fortschritts-/ID-
Kontinuität; beide vollständig gemessenen Runden; fertiges Resultat erneut
öffnen; bekannte Gesamt-/Bestzeit; genau eine Host-Belohnung und echter ACK.
20 ausdrücklich zugewiesene Legacy-/Fehlerfixtures prüfen fehlende einzelne
Felder, Typen einschließlich bool/string, Null-/negative-/NaN-/INF-Intervalle,
unplausible Startzeit/Summe/Gateanzahl und den falschen Lap2-Start0. Dazu kommen
Sentinel-Resave, ausgelassene Legacy-Teilmessung, nachfolgende volle Messung,
v1–v4, unbekanntes Finish und neun bekannte/ungültige Payload-Bestwerte. Diese
zugewiesenen Fixtures sind keine Fahr-Runden- oder Gerätebehauptung.

Identische finale Probe SHA256
`a6f17131675e84a7576e8db770a02823f66623b062164287908866b802a4e8a3`:
sauberes c95-BASE103/52FAIL/51PASS/Exit1 → Kandidat103PASS/0FAIL/Exit0.
Der tatsächliche finale BASE-Lauf liegt in `base-speed-full/`; ältere
Proben-SHAs sind historische Zwischenstufen, nicht diese identische Abnahme.
Die frühere reine Timingstufe hatte BASE97/46FAIL → Kandidat97PASS; ein
weiterer sauberer UI-Vorlauf auf diesem Timingkandidaten bestand97 Bedingungen
und scheiterte an genau den sechs neuen UI-Bedingungen. Offizielle
Godot4.6.3 `7d41c59c4`. Die finale Kandidatenprobe läuft mit echtem X11/
`gl_compatibility`, Software-OpenGL4.5/llvmpipe, strict Engine-/Wrapper-Exit0 und
ohne ERROR/Leak. Das Projektsetting ist weiterhin `forward_plus`; die
Runtime-Methode wird separat mit `RenderingServer.get_current_rendering_method`
ausgewiesen. Headless bleibt ein eigener Nachweis.

Ein weiterer tatsächlicher ResultUI-Vergleich deckte auf, dass das normale
cine-Ergebnis die Fahrcontrols versteckt, das gespeicherte und das direkte
noncinematic Ergebnis sie aber sichtbar lässt und Aktionen erst im nächsten
Tick deaktiviert. `_show_result` verbirgt nun dieselbe Controlszeile, aktualisiert
den bestehenden HUD-Zustand sofort und setzt dieselbe Platz-/Zielmessage wie
die Zielfahrt. Der gespeicherte Resumehinweis darf eine fertige Message nicht
überschreiben; er bleibt ausschließlich für unfertige Rennen erhalten. Kamera,
Zielfahrt, Physik, Modalrouting und normales Pause/Resume bleiben unverändert.
JSON zeigt für gespeicherte und direkte Resultate sofort und nach dem nächsten
Tick: Controls unsichtbar, fünf Fahraktionen deaktiviert, Message konsistent.

Die echte vorherige Resultat-Reopen-Aufnahme zeigte zudem73km/h, obwohl das
fertige Kart stand; das tatsächlich gefahrene direkte Training zeigte35km/h.
Mit derselben finalen Probe bestand dieser UI-Vorlauf auf Produkt81520
101 Bedingungen und scheiterte an genau zwei Geschwindigkeitsanzeigen. Nur die
drei HUD-Textzweige zeigen bei `finished` jetzt0km/h. Der gespeicherte rohe
Geschwindigkeitswert bleibt unverändert; gewöhnliche Fahrt und Pause behalten
ihre Anzeige. JSON erfasst den echten HUD-Text und daraus gelesene km/h vor
und nach dem nächsten Tick, für beide Resultatpfade jeweils0.

Die bestehende CompleteFlow-Probe erhält alle21 ursprünglichen Assertions,
den ursprünglichen Gate4-Resume und alle fünf ursprünglichen PNG-Rollen. Sie
ergänzt einen zweiten echten Touch-Pause/Save/Reopen bei Gate12 sowie ein
fertiges Resultat-Reopen vor ACK. Sechs echte PNGs einschließlich
`06-reopened-result.png`; tatsächlich sichtbare Gesamtzeit01:22.983 und beste
Runde00:41.183 stimmen mit dem Original-Payload überein.16 geordnete Gates,
Reset0, Integer solved0, drei Sterne, eine Host-Belohnung, ACK und erneute
Garage bleiben strikt geprüft. Der native Host ist ein Testdouble, kein
Android-Walletbeweis. Die bestehenden22 App-Proben bleiben22; keine neue
Pflichtprobe ersetzt eine alte.

Finale Rohbelege liegen getrennt in
`tools-runtime/final-1906/lap-session-author/`: `base-speed-full/` (identische
finale103RED), `speed-base/` (101PASS/2FAIL auf81520), `speed-gl-final/`
(103GREEN, PNG), `speed-gl-complete-flow/` (sechs PNGs und JSON),
`speed-time-format.log` (unveränderte29er-Zeitprobe PASS), Import- und Lintlogs.
Continuity schreibt in CI `exports/race-continuity/lap-session-evidence.json`
und `result_reopen.png`; CompleteFlow weiterhin `exports/complete-flow/`.
JSON enthält reale Runtime-/Quell-/Proben-/PNG-Hashes und früh eingefrorene
expected/actual-Werte. Finale Produktion SHA256
`7e600e57bcd2c7783da04caca22be4b51004d375e984aabe3b386861ffc1a6db`.
Finale CompleteFlow-Probe SHA256
`a260568656f2c4b5d6501b71e511cdfde3fb2d03e1f9f14c6dabc1e5dbbfd917`.

Frühe Fixturefehler bleiben erhalten: zu strenger neuer binärer Floatvergleich
wurde durch unveränderte semantische JSON-Zahlenprüfung ersetzt; fehlende
ConfigFile-Schlüssel mit nullDefault und ungeprüftes Löschen erzeugten echte
Enginefehler und wurden vor gültiger Abnahme mit Existenzprüfungen korrigiert;
ein falscher neuer ProgressStore-Zugriff wurde durch `total_stars()` ersetzt.
Die erste97GREEN-Evidenz ist **EVIDENCE_BLOCKED**, weil mutable Arrayreferenzen
später durch Restore verändert wurden. Ausschließlich der Evidenzsink kopiert
nun Container tief; alle97 Bedingungen bleiben identisch. Danach erfolgte die
oben angegebene neue identische BASE→GREEN-Abnahme. Keine alten Assertions,
Strictwrapper, Fehlererkennung oder Zeitprüfungen wurden abgeschwächt.

Beide geänderten Tests bestehen Lint und Format. Gesamtes Projekt BASE/Kandidat
je391 vorhandene Lintdiagnosen und46 unformatierte Dateien, keine neue
positionsunabhängige Diagnose. Das separate Peer-Probe-Skript bleibt bytegleich:
BASE1PASS/4FAIL → Kandidat5PASS/0FAIL. Ein eigener unveränderter
UI-Peernachweis besteht zusätzlich BASE3PASS/6FAIL → Kandidat9PASS/0FAIL,
einschließlich echter Restart-Button-Signalroute mit frischer Ergebnis-ID.
Die zusätzliche unveränderte Speed-Peerprobe V4 besteht auf81520
7PASS/3FAIL → final7e60010PASS/0FAIL: roher Wert12 bleibt erhalten,
Fahrt/Pause zeigen43km/h, fertige Resultate sofort/nächster Tick0km/h;
Belohnung/Payload und echte Restart-Button-Signalroute bleiben korrekt.
Peer bestätigt acht erlaubte bestehende
Produktfunktionen plus einen Restorehelper; alle anderen Produktfunktionen und
64 andere Testdateien sind unverändert.

KartRegression und RaceBridge wurden zusätzlich auf81520 tatsächlich
headless geschlossen, beide EngineExit0 ohne ERROR/Leak. Diese sind historische
Kernnachweise auf81520, keine erneut ausgeführten7e600-Läufe. Der unabhängige
finale Scopevergleich belegt danach ausschließlich die drei HUD-Textausdrücke
und deren lokale Anzeigevariable, keine Geschwindigkeits-/Physikzustandsänderung.

Verwendete Primärquellen: offizielle
[Godot4.6 ConfigFile-Dokumentation](https://docs.godotengine.org/en/4.6/classes/class_configfile.html)
für `has_section_key`, `get_value` und `erase_section_key` sowie
[Godot4.6 JSON-Dokumentation](https://docs.godotengine.org/en/4.6/classes/class_json.html)
für serialisierte Werte. Die APIs werden mit eigenem lokalem Code verwendet;
kein fremder Code, Asset, Modell oder Lizenzpaket wird übernommen.

**VISUAL_GAP / NOT FINISHED:** Der Paketabschluss gilt für dauerhafte
Rundenmessung und native Resultatkontinuität. Exakte neue APK1906/API35/36,
physisches Fold, Android-Inputlatenz, CPU/GPU/Speicher/Soak und Tonabnahme sind
hier NOT EXECUTED. Modell-, Welt-, Licht-, Loop-AI- und weitere Runtime-Lücken
werden durch diese Zeitkorrektur nicht abgeschlossen. Nächster Schritt:
geprüften frischen Godot-RESULT integrieren, App exakt pinnen, dieselben22
nativen Proben und den vollständigen Android-/ACK-/Walletablauf aus der
wirklich gebauten neuen APK prüfen.
