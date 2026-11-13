# Tatsächliche Stilprüfung vor dem Renderer-Checkpoint

Die historische `CLAUDE.md` nennt `gdlint` und `gdformat --check` vor jedem Commit. Diese Werkzeuge wurden zusätzlich zu Godots tatsächlichem Import mit installiertem **gdtoolkit 4.5.0** ausgeführt. Es wird keine vollständig grüne repositoryweite Stilprüfung behauptet.

| Quelle | Dateien | gdlint | gdformat --check |
| --- | ---: | ---: | ---: |
| Unveränderte Basis `1d5c5cb45a323228f627ec529e6ff1ddd86f1c57` | 396 | 1330 Befunde, Exit 1 | 238 Dateien, Exit 1 |
| Entwicklung vor Formatierung | 432 | 2029 Befunde, Exit 1 | 276 Dateien, Exit 1 |
| Entwicklung nach begrenzter Formatierung | 432 | 1449 Befunde, Exit 1 | 241 Dateien, Exit 1 |

Alle **36 neuen GDScript-Dateien** wurden mit eingeschalteter semantischer Sicherheitsprüfung formatiert und bestehen gemeinsam `gdformat --check`. 35 wurden dabei geändert. Bestehende große Dateien wurden nicht pauschal umgeschrieben. Der verbleibende Stilbefund besteht überwiegend aus Zeilenlängen, Deklarationsreihenfolge und vorhandenen Größenregeln; er ist weiterhin offen, einschließlich neuer Befunde. Keine Linterregel wurde abgeschaltet und kein Fehlerstatus in PASS umgewandelt.

Rohlogs und genaue Dateiliste liegen in `docs/evidence/nextgen-style-20261113/`. Funktions-, Speicher-, Renderer- und Android-Abnahme laufen getrennt am finalen Commit. Vorherige lokale Modul-Hashberichte beschreiben ihre damaligen Quellen; der anschließende vollständige CI-Lauf prüft die jetzt formatierten Quellen erneut. Die reine Formatierung ist kein neuer Gameplay- oder Leistungsnachweis.

## Korrektur nach tatsächlicher CI-Kompilierung

Commit `c5c71145` wurde durch den echten Godot-4.6.3-Compiler abgelehnt: `gdformat 4.5.0` hatte zwei mehrzeilige anonyme Callbacks im Siedlungsdialog so eingerückt, dass Godot sie nicht lesen konnte. Die AST-Prüfung des Formatierers war deshalb kein ausreichender Compilerbeleg. Beide Callbacks sind nun benannte gebundene Methoden mit denselben Transaktions-/Dialogwachen.

Danach wurden alle 36 neuen Skripte im echten Godot mit geladenen Produktions-Autoloads kompiliert: **36 bestanden**, Exit 0. Der tatsächliche Siedlungs-Spielablauf bestand erneut **127 Prüfungen**, das Wirtschaftsmodell **194 Prüfungen** einschließlich einer vollständigen fair gespiegelt gespielten KI-Kampagne. Die Formatprüfung der korrigierten Datei besteht; verbleibende Linterbefunde werden im Rohlog unverändert ausgewiesen. Ein isoliertes `--check-only` ohne Autoloads wurde nicht als gültiger Fehlschlag der Produktionsskripte gewertet. Der nachfolgende vollständige Renderer-/CI-Lauf bleibt erforderlich.
