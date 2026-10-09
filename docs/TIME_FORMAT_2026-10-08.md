# Konsistente Ergebniszeiten · 8. Oktober 2026

BASE: `ad3ee9c9a1e2cfa60a6d2fe4970181b3150a1a1b`.
Der aktuelle RESULT ist der frische HEAD von
`codex/lumo-time-format-2026-10-08`; anschließend exakt in der App für APK1906
pinnen. Main und Releases bleiben unverändert. APK1906 ist noch nicht gebaut.

Im originalen nativen1905-Artefakt11580229408, Actions37846382465, zeigt
`complete-flow/04-result.png` „Beste Runde 00:40.000“, während das tatsächliche
Ergebnis `bestLapSeconds=41.0` enthält. Die gemessenen Gatezeiten
82.7999999999966 minus41.7999999999989 ergeben40.9999999999977 Sekunden.
Der bisherige Formatter trennt ganze Sekunden vor dem Runden der Millisekunden;
bei1000 gerundeten Millisekunden geht der Sekundenübertrag verloren.
Das Originalbild bleibt unverändert: SHA256
`b0631040fce20d9c4975cfcfef925add804a4748a579e83996f024a2539e88b9`.

Die einzige Produktänderung liegt in `KartIsland._format_time`: Gesamtdauer
einmal auf ganzzahlige Millisekunden runden, danach Minuten, Sekunden und
Millisekunden aus diesem Integer ableiten. Fahrphysik, Checkpoints, gespeicherte
Zeiten, Ergebnis-ID, Ergebnis-Payload und Belohnungsverarbeitung werden nicht
verändert. Die vorhandene CompleteFlow-Probe erhält zusätzlich eine Prüfung
des tatsächlich sichtbaren `ResultStats`-Labels gegen den Ergebnis-Payload und
dokumentiert dessen Text sowie die ungerundete beste Runde.

Die neue unabhängige `kart_time_format_regression.gd` enthält29 feste Erwartungen:
den original beobachteten Wert, Sekunden-/Minutenüberträge, Halbmillisekunden,
Null und gewöhnliche Zeiten. Identisches Test-SHA256 auf BASE und Korrektur:
`15f8b808ec1e5b598f24c9cf224246a129e821625bd02a38ccf5794349e28b1e`.
Exakte Godot4.6.3 `7d41c59c4`: BASE Exit1/21PASS/8FAIL; Korrektur
Exit0/29PASS/0FAIL, ohne Script-/Enginefehler oder Leaks. Kalter Import mit
regulärer Logdatei Exit0. Alle bisherigen21 CI-Proben und die37er-Modalprobe
bleiben erhalten; der App-Workflow ergänzt diese Zeitprobe als22. Prüfung.

Der tatsächliche neue native CompleteFlow besteht strikt mit Engine- und
Wrapper-Exit0,16 geordneten Gates, gespeicherter Wiederaufnahme, Ergebnis,
ACK und genau einer Belohnung. Fünf neue echte PNGs. Sichtbares Label und
direkt angesehenes Ergebnisbild zeigen nun „Beste Runde 00:41.000“;
ungerundete Runde40.9999999999977, Payload41.0. Alle Quellfile-Hashes vor/nach
dem Lauf sind identisch. Die abschließenden Übergabedokumente wurden danach
geschrieben; Laufzeitcode und Tests bleiben bytegleich zum geprüften Stand.
Der native Host ist ein Testdouble, kein Android-Walletnachweis.

Neue Zeitprobe, additive CompleteFlow-Probe und Formatterabschnitt bestehen
Lint/Format. Vollständige Projektbasis:391 vorhandene Lintmeldungen und46
bereits unformatierte Dateien, keine neuen Meldungen. Projektvalidator:
117PASS/7 vorhandeneWARN/0FAIL. Ein erster Diagnostikvergleich scheiterte an
verschobenen Zeilennummern; der erhaltene Folgevergleich bewahrt Dateinamen,
Fehlertexte/-arten und deren Häufigkeit und ignoriert ausschließlich Positionen.
Keine Produkt-Testanforderung wurde abgeschwächt.

Verwendete Primärquellen: offizielle
[Godot4.6 roundi-Dokumentation](https://docs.godotengine.org/en/4.6/classes/class_@globalscope.html#class-globalscope-method-roundi)
und [GDScript-Integerdivision](https://docs.godotengine.org/en/4.6/tutorials/scripting/gdscript/gdscript_basics.html#operators).
Die vorhandene API wird mit eigenem Code verwendet; kein fremder Code,
keine neue Abhängigkeit und keine externen Assets werden übernommen.

**VISUAL_GAP / NOT FINISHED:** Dieser kleine Paketabschluss bestätigt nur die
Zeitdarstellung und erhaltenen nativen Abläufe. Neue exakte APK1906/API35/36,
physisches Fold, Android-Latenz, CPU/GPU/Speicher/Soak und akustische Abnahme
sind hier NOT EXECUTED. Bestehende Modell-, Welt- und Beleuchtungsabweichungen
bleiben offen. Keine Referenzgleichheit oder60FPS zugesagt.
