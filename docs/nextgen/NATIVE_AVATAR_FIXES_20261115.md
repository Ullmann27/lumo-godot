# Native LUMO: kanonische Audio- und Abbruchkopplung

Stand 15.11.2026. Produktionsbasis ist der byteweise eingefrorene Runtime-Snapshot
`505ed43c49c6a87885ba8a1a8d76c42a495c274e`. Der von Root gelieferte Scope-Fix
`1e2ef7da3003868c911bd7fde95b96cd72b55cb6` wurde lokal als `1693265` übernommen.
Nur den anschließenden Avatar-Fix übernehmen; der Scope-Fix gehört Root bereits.

## Verhalten

- Der Lern-Actor bindet `protocolVersion: 1`, `sessionId`, `taskId`, `revision`,
  `cancelEpoch` und die exakte optionale `stepId`. Fehlend/null ist ein anderer
  Zustand als ein expliziter Schritt. Alte `schema/version/contextRevision`-
  Ersatzumschläge sind keine produktive kanonische Identität.
- Positive ganzzahlige `turnId` haben einen Highwater pro Aufgabenbindung.
  Turn 1 kann nach Turn 2 keine alte Geste wiederbeleben. Ein neuer Aufgaben-
  besitzer darf seine eigene Zählung beginnen. Objektkennung und Aktion werden
  vor der Mutation geprüft; die Figur bewertet keine Antwort und vergibt nichts.
- Tatsächlich über JSON eingelesene numerische Audio-IDs funktionieren auch als
  GDScript-Float. Bruchzahlen, falsche IDs, andere Besitzer/Schritte und beendete
  Audio-Leases verändern weder Mund noch Oberfläche noch Segmentfortschritt.
- `learning_world._tick_speech` bleibt der einzige Poll- und Segmentbesitzer.
  `_apply_speech_status` ist ein kleiner Validierungshaken; die Next-Unterklasse
  bindet jeden `_start_audio_segment`, einschließlich Wort/Ba/na/ne. Der alte
  Base/Fox-Pfad bleibt funktionsfähig und wird separat geprüft.
- Entfernen des aktiven Blick-/Zeigeobjekts stoppt dessen Turn und Transport.
  Entfernen eines unbeteiligten Objekts lässt den laufenden Turn bestehen.
  Aufgabe, Stop, Pause, Fokusverlust und Besitzwechsel neutralisieren gemeinsam
  die alte Darbietung. Resume startet sie nicht erneut.
- Kanonische Objektaliasnamen zeigen auf echte aktuelle Nodes bzw. ausdrücklich
  registrierte Weltanker. Silbenhinweise benutzen die exakte ID. Muster- und
  Aufgabenkarte sind angebunden. Unbestätigte Vorschläge verschwinden bei Stop;
  bereits gelegte Objekte bleiben erhalten. Die Bestätigung bleibt in Flutter.
- Die tatsächlich projizierten Bounds von Muster, Aufgabenkarte und Pflanze
  werden bei engem Textlayout in die freie Fläche eingepasst. Keine globalen
  Actor-, Kart- oder Dschungeldateien wurden verändert.

## Messprotokoll v1

Der reale Base-`_process` (auch für die Factory-Unterklasse) schreibt ungefähr
alle fünf aktiven Sekunden eine einzelne Zeile `LUMO_LEARNING_PERF <JSON>`.
`schema` ist `lumo.learning.perf`, `version` ist 1. Felder:

| Feld | Einheit/Bedeutung |
| --- | --- |
| `kind`, `platform`, `renderer`, `display_driver`, `adapter` | Aufgabenart und tatsächliche Laufzeit-/Renderermetadaten; keine Aufgaben- oder Kindtexte |
| `reduced_motion` | tatsächliche Szeneneinstellung |
| `window_index`, `window_ms`, `sample_count` | monotoner Fensterzähler, reale Millisekunden, tatsächlich erfasste Frameintervalle |
| `frame_ms.mean/p50/p95/p99/max` | monotone Abstände aus `Time.get_ticks_usec`, Millisekunden; Perzentile nach Nearest Rank |
| `frame_ms.over_16_7_count/fraction` | Anzahl/Anteil strikt über 16,7 ms |
| `process_ms.mean/p95/max` | Godot `Performance.TIME_PROCESS`, in Millisekunden umgerechnet |
| `render.draw_calls_mean/primitives_mean/render_objects_mean` | Mittel der tatsächlichen Godot-Renderzähler pro Sample |
| `render.objects_mean/nodes_mean` | Mittel der tatsächlichen Engine-Objekt-/Nodezähler |
| `fox_usable_samples` | Samples mit tatsächlich nutzbarer Figur |
| `speech_playing_samples` | Samples mit akzeptiertem Sprachstatus `playing` |
| `speech_playing_audible_samples` | davon `audible: true`; kein Schluss aus Textlänge |
| `effects_active_samples` | vorhandene sichtbare/prozessierende Ambience, aktive Instanzen und tatsächlich fortgeschrittene Animationszeit |
| `speech_fox_effects_samples` | alle drei Bedingungen im selben Sample |

Pause, Fokuswechsel und Aufgabenartwechsel verwerfen unvollständige Fenster.
Die Messung ändert weder Qualitätsprofil noch Framelimit. Ein begrenztes Fenster
fasst höchstens 8.192 Intervalle; bei vorzeitigem Überlauf wird es verworfen,
nicht mit erfundenen Werten ergänzt. `adapter` ist ein zusätzliches festes
v1-Metadatenfeld. Eine Software-Renderer-Messung ist kein Android-FPS-Nachweis.

## Prüfung und verbleibende Grenzen

Realer Godot-4.6.3-Lauf am Fixstand: Actor **300/0**, vollständige native
Route **5.478/0**, Original-Base/Fox **69/0** Checks/Fehler. In diesen drei
Logs gibt es keine Scriptfehler oder Warnungen. `gdlint` und `gdformat --check`
für die neun geänderten/neuen GDScripts sind grün; Projektvalidator **118/0/0**.

Die unabhängigen Prüfungen stehen in:

- `scripts/tests/nextgen_avatar_contract_review.gd`: importiertes Rig, echte
  Morphwerte, AudioStreamPlayer-Testsignal, kanonisches JSON und Abbruchvertrag.
- `scripts/tests/nextgen_learning_route_review.gd`: echte geroutete Szene,
  zwölf begrenzte native Aufgabenarten, fünf Fenstergrößen, 150%-Text,
  tatsächliche Touch-Buttons, Segmente und Lifecycle. Der Sprachhost ist eine
  offen deklarierte Bridge-Fixture, keine behauptete Android-TTS-Aufnahme.
- `scripts/tests/nextgen_learning_base_audio_regression.gd`: Original-Fox/Base,
  numerische IDs, alle Silbensegmente, fehlerhafte Besitzer/Schritte und Probe-Reset.

Das ist keine vollständige Flutter-Routenabdeckung. Physische Android-Audio-
und 60-FPS-Abnahme brauchen den tatsächlichen APK-Lauf. Die kleinen Logs,
aktuelle Screenshots und echte Software-Renderer-Messfenster folgen als
gesonderter QA-Beleg; kein erneuter Vollimport oder neue Engine ist erforderlich.
