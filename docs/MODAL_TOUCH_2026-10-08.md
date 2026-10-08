# Kart-Modal: echte Touchgesten · 8. Oktober 2026

BASE: `18238d48f96b76c4175b705a9bf05e82e339bdd0`, Godot 4.6.3.
Aktuellen RESULT immer am Branch-HEAD und im App-Pin lesen, nicht aus früheren
1900-/1902-Berichten übernehmen. Dieses Paket ergänzt den Countdown-Pausefix.

Die tatsächlich gebaute APK1903 (App `3e1d0eb3`, Actions `37817947080`)
scheitert auf API36 am Pause-Scrollen: Vier protokollierte Androidgesten
`[912,559 → 912,322]` starten auf „Ton: an“. Zehn Originalbilder halten
dieselben Button-/Scrollbalkenpositionen; die Gas-Einstellung bleibt verborgen.
API35 verliert bereits vor dem Fullrace die Emulatorverbindung. Die begrenzte
QA-Reparatur dafür liegt separat in der App; sie ändert keinen Spielzustand.

## Kleine Produktänderung

Nur direkte Button-Kinder von `modal_column` erhalten `MOUSE_FILTER_PASS`.
Damit erreichen Touchgesten deren `ScrollContainer`; bei Scrollbeginn wird
die vorgemerkte Buttonaktion verworfen. Die Verbindung gilt auch nach einem
Neuaufbau des Pause-/Ergebnisdialogs. Slider, feste Pause-Navigation, Garage
und Renncontrols behalten ihre bisherigen Filter und ihre Architektur.

Der neue Test `scripts/tests/kart_modal_touch_regression.gd` verlangt echte
Engine-Frontend-Eingaben, Scrollbewegung, unveränderte Aktionszähler und
Spielzustände sowie normale Taps mit genau einer Aktion. Kein Scrollwert,
Checkpoint, Ergebnis oder ACK wird gesetzt. Der Ergebnisdialog wird durch
natürlich berechnete zwei Runden mit allen 16 Gates erreicht.

Identisches finales Test-SHA256 auf BASE und Kandidat:
`41db7836226d254732f9338d1afb1df4f6c5698c619ce56b2883742b03c63a5c`.
BASE strikt RED: Exit1, erster Button-Drag 0→0, zwei tatsächliche PNGs.
Kandidat strikt GREEN: Exit0, `[KartModalTouch] PASS:`, 35 Prüfungen,
sechs echte Button-Drag-Fälle und 14 tatsächliche PNGs. Geprüft sind
Ton/Gas/Weiterfahren/Neue-Fahrt-Taps, Drag-Cancellation, Slider, feste Footer,
Viewportwechsel, separate Rennfinger und Loslassen außerhalb der Controls.

Zwei frühere Kandidatenprüfungen bleiben als fehlgeschlagene Testläufe erhalten:
fehlendes Wheel-Loslassen ließ die Testfixture den Mausfokus behalten; danach
fehlte die reale Scrollvorbereitung für den Ergebnis-Down-Drag. Beide Fehler
wurden durch vollständige öffentliche Eingaben korrigiert, ohne die
Erwartungen abzuschwächen. Frühere Parse-/Importfixturefehler zählen nicht als
Verhaltens-RED des Produkts.

## Quellen und Grenzen

Offizielle Godot-Quellen des tatsächlich verwendeten Engine-Commits
`7d41c59c4`: `scene/main/viewport.cpp`, `scene/gui/scroll_container.cpp`,
`servers/display_server.cpp`, `platform/android/display_server_android.cpp`
und Android `GodotInputHandler.java`/`GodotGestureHandler.kt`.
Die MIT-Quellen wurden gelesen; kein fremder Code wurde in das Produkt kopiert.
Die Anpassung verwendet das bestehende Control-Eingaberouting.
Direkte Quellen: [ScrollContainer](https://github.com/godotengine/godot/blob/7d41c59c4/scene/gui/scroll_container.cpp)
und [Viewport](https://github.com/godotengine/godot/blob/7d41c59c4/scene/main/viewport.cpp).

Der native Test läuft mit echtem Desktop-GL/Mesa und einer vorübergehenden
Touchscreen-Frontend-Emulation, die ausschließlich in der Testfixture gilt.
Projektsettings werden nicht verändert. Das ist keine Android-/OS-Touchlatenz-,
GPU- oder physische Foldmessung. Erst die neue exakte APK samt tatsächlichen
API35-/36-Läufen bestätigt den Androidnutzen, zwei Runden, Ergebnis/ACK,
einmalige Belohnung und Flutter-Rückkehr.

**VISUAL_GAP / NOT FINISHED**: Referenztreue der Produktionsmodelle und Welt,
akustische Abnahme, physisches Fold und Zielgeräteprofiling bleiben offen.
Der App-Kandidat muss eine neue Buildnummer 1904 bekommen, weil APK1903
bereits real gebaut wurde. Main und Releases werden nicht verändert.
