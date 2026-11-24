# Godot-Integration für Lumo 2081 — 24.11.2026

## Integrierter Quellstand

Arbeitszweig: `integration/godot-2081-20261124`. Main bleibt unverändert.

- Ausgangspunkt `c3f459eca88f659da1a9e4af1c990c804e715528` (Godot-Pin von 2080).
- `e0f70a3afa134df895989fbab132470419f70341`: enthält den World-Kart-Speicherfix #226, den sichtbaren Ersteintritt und die Führung, die sieben zusätzlichen Orte, neun Originalfiguren, Dialoge, vier Missionsketten, neun Figurenkarten und #229 mit strenger Inhalts-/Speicherprüfung.
- `34ccd80da414085fb3a5f8446b08fbaacba0aa1a`: enthält zusätzlich #227 bis `6c8371aa46ac2cb30113a5bc25b80f557e5cba92`, also den jüngsten Kart-Bodenkontakt, die Reifenanpassung an Hänge und die Steinkollisionen, sowie den ursprünglichen strengen Prüfablauf.
- `6ca95867737b13fd5115e8f2680eb0a682e1fd4d`: übernimmt die korrigierten nativen CI-Erwartungen (geriggte Fahrer, Gang, Hoist-Import).

Diese Zweige wurden mit echten Git-Merges zusammengeführt. Die Laufzeitdateien `lumo_world.gd` und `lumo_world_art.gd` wurden automatisch konfliktfrei kombiniert. Die vorhandenen Originalmodelle und Spielfunktionen bleiben im Ausgangsbaum enthalten.

## Befunde an den zusätzlich genannten alten Zweigen

- `agent/tutor3d` ist bereits Vorfahr von `c3f459ec` (218 Commits dahinter, kein eigener neuer Commit). Daraus fehlt kein weiterer Godot-Quellstand.
- `fix/lumo-world-gait-20261123` (`82d251ae`) ist historisch abgezweigt, seine Funktion ist bereits enthalten: Der Schauspieler hat auf beiden Seiten exakt Blob `289cafa182ee7886f36512b4a07a2941aa1fcfc8`; die World führt `player.velocity` zu, und beide Prüfungen für artikuliertes Gehen bei reduzierter Bewegung stehen bereits in der aktuellen World-Regression. Das Ergebnis wurde erneut in Godot 4.6.3 ausgeführt.
- `delivery/lumo-schach-2048-20261118` (`4db43829`) enthält die frühere Schachfassung mit `chess_position.gd` und `chess_board.gd`. Der aktuelle Ausgangsstand enthält bereits deren weiterentwickelten Ersatz: `chess_rules.gd`, `chess_ai.gd`, `chess_coach.gd`, `chess_school.gd`, `chess_session.gd`, `chess_set.gd`, die 2D-Ansicht und die wesentlich erweiterte `chess_table.gd`. Schach ist in Boot, Router und HostBridge registriert. Die alte Fassung wurde deshalb nicht über diese Entwicklung geschrieben. Ihre Dateien sind kein fehlendes neues Schachmodul.

## Reparatur der fehlgeschlagenen Kart-Prüfung

Der ursprüngliche strenge Lauf `45425127603` war tatsächlich rot. Die Originalfehler wurden lokal am kombinierten Stand reproduziert und als `baseline-first.log` und `baseline-ground.log` erhalten.

1. Der Dekorationstest rief zusätzlich zur laufenden Szenenphysik `_drive_tick` auf. Damit wurden pro Rahmen Bremse und Gas nacheinander verarbeitet. Er benutzt jetzt denselben echten Stick-Eingabepfad wie die Ersteintrittsfahrt.
2. Der südliche Startpunkt für den Torpfosten lag bereits im benachbarten Kompasssockel. Der Test fährt jetzt aus einem freien nördlichen Anfahrtsbereich; eine neue Prüfung bestätigt ausdrücklich, dass der Start nicht in einer Kollision liegt. Die Anforderungen an Fahrstrecke, Körperüberschneidung und 3-cm-Reifenkontakt bleiben erhalten.
3. Die sechs beim Beenden gehaltenen Ressourcen waren echte Musik-/Umgebungs-Playbacks. Die Prüfungen schließen die Produktionsszene und beobachten über den bestehenden WeakRef-Helfer, dass Szene und Mixer-Playbacks wirklich freigegeben sind. Keine Fehlerfilter, kein Abschwächen des externen Probe-Runners.

## Tatsächlich ausgeführt

Godot `4.6.3.stable.official.7d41c59c4`, Linux x86_64, vollständiger Laufzeit-Asset-Import. Der Engine-ZIP-Hash wurde gegen den schon verwendeten Projektwert geprüft. Alle unten genannten Prüfungen liefen mit dem unveränderten strengen `tools/run_godot_probe.py`; Enginefehler oder fehlender PASS-Marker führen zu einem Fehlerstatus.

| Prüfung | Ergebnis |
|---|---:|
| Ersteintritt, echte Stick-Fahrt, Parken, Neustart, Führung | PASS 134 |
| Reifenkontakt, Hänge, Stein-/Torkollision, Altspielstände, Fallrücksetzung | PASS 51 |
| Tatsächliche World-Szene: Originalfiguren, Dialogbuttons, vier Ketten, Album, Speichern/Neustart | PASS 183 |
| Missions-/Kartenintegrität und zwölf konkrete Klassenstufenfragen | PASS 201 |
| Kart-Speicher und Kartenkomponente | PASS 63 |
| Bestehende World-Regression | PASS 206 |
| Terrain-/Geräteszenen-Regression | PASS 59 |
| Weltkarte | PASS 174 |
| Weltkamera | PASS 27 |
| Reales 65-Knochen-Gangbild einschließlich Ruhemodus | PASS |

Die neun numerischen Prüfungen enthalten zusammen **1098** Prüfpunkte; der Gangtest hat einen separaten PASS-Marker. Originalprotokolle, Quellenhashes und Prüfsummen liegen unter `docs/evidence/integration-2081-20261124/`.

Der neue Integrationstest betätigt tatsächliche Dialogschaltflächen, prüft eine falsche Antwort ohne Fortschritt, durchläuft alle vier Missionsketten, sammelt die neun Karten im tatsächlichen Journal und öffnet den geschriebenen World-Spielstand erneut. Zwischen Begegnungen werden feste Testpositionen gesetzt. Die echten Stick-Fahrten werden separat durch die Ersteintritts- und Bodenprüfungen abgedeckt.

## Weiter zur APK

Der Flutter-Godot-Pin soll auf den endgültigen Commit dieses Zweigs gesetzt werden. `.github/workflows/lumo-2081-world-integration-qa.yml` wiederholt die zehn Prüfungen aus dem exakten veröffentlichten Stand und archiviert Commit, Baum und Originalprotokolle. Ein gestarteter CI-Lauf ist noch kein bestandenes Ergebnis.

Android-APK, Flutter-Einbettung, Hardware-Touch, tatsächliche Sprachwiedergabe auf Android und Geräte-FPS werden hier nicht als geprüft behauptet. Einige der neuen Hallen/Plätze verwenden weiterhin die im Inhalt ausdrücklich gekennzeichnete Prototypgeometrie. Das ist eine Integration vorhandener Entwicklung, kein Nachweis fertiger AAA-Grafik oder echter Online-Mitspieler.
