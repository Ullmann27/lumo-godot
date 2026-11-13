# Bauwelt-Siedlung: unabhängige Regeln-, Profil- und Touchprüfung

Arbeitszweig: `chatgpt/lumo-nextgen-20261113`. Diese Prüfung betrifft die neue produktive Siedlung/Wettbau-Variante. Der Varianten-Einstieg bleibt der tatsächliche Bauwelt-Bildschirm. Zustandsmodell: Root; Geometrie/Umgebung: Team D; die hier beschriebenen UI- und Abnahmekorrekturen: Team C.

## Tatsächliche Befunde und Korrekturen

| Vorher reproduzierbar | Jetzt implementiert | Beleg |
|---|---|---|
| Vier frühe Häuser, nächster Tag: kein Rohstoffproduzent, Undo gelöscht, keine bezahlbare weitere Aktion. Auch 100 zusätzliche Tage helfen nicht. | Reversibler Rückbau gibt die statischen Baukosten zurück, gemeinsam mit Undo/Redo und Speicherstand. | Original-Auditlog und produktiver Farm-Rückbau per Touch; Modellprüfung der vollständigen Wiederaufbaufolge. |
| Nach öffentlichen Käufen, Tagen, Markttransaktionen der UI-Menge 5 und Rückbau: Ausbau verbraucht den letzten Baustoffvorrat; 3 Holz/1 Stein, nur zwei geschützte Häuser. | Ausbau verlangt Holzwerkstatt und Steinbruch. Spieler, KI und sichtbares can_expand verwenden dieselbe Regel. | Historischer vollständiger Repro; erweiterte Modellprüfung. |
| Ohne Ausbau: acht Wohnhäuser, ein Bauernhof und vorher angespartes Essen wachsen zu 16 Bewohnern bei 0 Holz/0 Stein. Alle Häuser sind benötigt; Farmrückbau reicht nur für dieselbe Farm. | Normaler Wohnschutz bleibt. Ein ausdrücklich bestätigter Umbau darf Bewohner vorübergehend ausziehen lassen. Die zwei Gründer bleiben mindestens im Startlager. Das gesamte Hauskapital wird wieder verfügbar; Undo/Redo und Reload bewahren Bewohner und Material atomar. | Historischer 122-Tage-Repro ausschließlich mit öffentlichen Aktionen; Modellprüfung mit vollständiger Wiederaufnahme von Holz-/Steinproduktion. |
| `child:a` und `child?a` sowie lange gemeinsame Präfixe teilten den bereinigten Dateinamen. | Exakte Roh-ID im Envelope, ausschließlich SHA256 der Roh-ID im Dateinamen; unterschiedliche Kinder, Projektplätze und Varianten werden unabhängig geprüft. | Dateipfad-/Envelope-Tests mit den echten Kollisionspaaren. |
| Nach Android-Pause konnte ein bereits offener Marktdialog weiter Rohstoffe ausgeben. | Pause schließt alle offenen Handels-/Umzugsdialoge. Ihre verzögerten Callbacks prüfen die Sperre erneut. | Tatsächliches geöffnetes Fenster, Pause, anschließend ausstehender Callback: Zustand bleibt identisch. |
| Nach 22 KI-Tagen war die Runde beendet, aber eine tägliche Essensmeldung verdeckte den Sieger; kein Neustartweg. | Gewinnertext hat Vorrang. Neue Runde sucht einen freien bestehenden Platz 1–6. Bei sechs belegten Plätzen bleiben alle Dateien erhalten; Zur Bauwelt führt zur vorhandenen bewussten Projektwahl. | Echte KI-Runde bis zum Sieg; echte Neustart-Touchaktion; bytegleiche Vorherdatei; zusätzlich belegte-Sechs-Plätze-Fixture ohne Überschreiben. |
| Deaktivierte Gebäudekosten waren schlecht lesbar. | Eigene dunkle deaktivierte Schrift, heller gedämpfter Hintergrund und ruhige Kontrastträger hinter beiden HUD-Bereichen. | Neue Rendereraufnahme noch erforderlich. |

Die alten freien Bauwelt-Dateien besitzen weiterhin ihre frühere bereinigte Kind-ID. Diese Prüfung stellt keine Migration oder vollständige Profilisolation des Altmoduls dar; die Grenze wurde an Root gemeldet. Die neue Siedlungsvariante erhält die unveränderte Router-ID und verwendet ihren eigenen geschützten Speicherpfad.

## Produktive Dateien

- `scripts/creative/build_settlement_world.gd`: Rückbau, Dialog mit konkreter Bewohnerfolge, Abbruch/Bestätigung, Pausensperren, sichere Kind-/Platzpfade, Ergebnis und neuer Projektplatz, zugängliche HUD-Kontraste. Handels- und Umzugsdialoge werden in die App eingebettet und im sichtbaren Safe-Area-Rechteck positioniert; die vorherige Einbettungseinstellung wird beim Verlassen wiederhergestellt.
- Der Wohnraumdialog erklärt vor jeder Zustimmung, wie viele Bewohner ausziehen und wie viele bleiben. Bei den zwei Gründern nennt er ausdrücklich das Startlager. Jede Aktion besitzt mindestens 48×48 logische Pixel; Abbruch verändert keine Regeln. Vor dem bestätigten Umbau wird zudem der ursprüngliche Snapshot abgeglichen.
- `creative_nextgen_environment.gd` (Team D) ist nach der bestehenden Tagesumgebung aufgerufen. Die beiden Ufer besitzen geteilte Bank-/Grasmaterialien, die Grundstücke dasselbe Bodenmaterial. Genau zwei dünne Gras-Meshes kommen dazu; Kollisionen und Regeln bleiben im bestehenden Modell.
- `scripts/tests/build_settlement_play_regression.gd`: echte Bauwelt-Navigation, Strahlen-/Touchauswahl, Bau und Rückbau, Ressourcen, KI-Geometrie, unabhängige Dateien, echte Tage bis zum Sieg, neues Projekt, Profilgrenzen, Pause und Wohnraumdialog.

## Tatsächlich ausgeführt

Godot `4.6.3.stable.official.7d41c59c4`, Linux, getrennte `XDG_DATA_HOME`-Verzeichnisse:

| Prüfung | Ergebnis |
|---|---|
| `build_settlement_regression.gd` | PASS, 194 Prüfungen; gespiegelte vollständige KI-Kampagne 22 Tage. Von Team C nach dem abschließenden Modellfix erneut ausgeführt. |
| `build_settlement_play_regression.gd` | PASS, 127 Headless-Prüfungen; keine Script- oder Resource-Fehlermeldung im abschließenden Lauf. |
| Reversible Touch-Interaktionen | Farm gebaut, berührt, rückgebaut; Undo/Redo ohne Ressourcenvervielfachung. |
| Expliziter Wohnumbau | Echte Käufe und ein echter Tag erzeugen drei Bewohner. Im 412×915-Layout erklärt der Dialog den Übergang 3→2; tatsächliche Touch-Zustimmung führt ihn aus; Undo/Redo stellt den exakten vorherigen Snapshot wieder her. |
| Eingabe-/Dialoggrenzen | Abbruch ohne Änderung, ausstehende Bestätigung nach Pause ohne Änderung; die beiden Dialogaktionen sichtbar und mindestens 48×48 im Porträt. |
| Vorherige CI-Version `096c9d20a3a1b92605e0a4f648e1afd87f967b9a` | 114 gerenderte Spielprüfungen bestanden, anschließend acht GL-Texturleaks à 21.844 Bytes. Daher **kein bestandenes Gesamtgate**. Die aktuellen Umzugsdialogprüfungen postdatieren diesen Lauf. |

Der aktuelle Capturepfad erzeugt fünf echte Szenenbilder und `06_settlement_relocation.png` als echte Textur des kompakten Dialog-Viewports. Der sechste Screenshot besitzt deshalb die tatsächliche kleinere Dialoggröße. Ein Headless-Aufruf mit `--capture` wird abgewiesen. Die finalen Rendererbilder und Android-/Fold7-Prüfungen stehen aus. Der GL-Lifetime-Fehler wird von Team D an den betroffenen Ressourcenmodulen untersucht; kein Logfilter blendet ihn aus.

Die überprüften Logs, historischen Repro-Skripte und Quellcode-Hashes stehen in `docs/evidence/nextgen-settlement-review-20261113/`. Die historischen Skripte dokumentieren vor dem Fix nachgewiesene Regeln und sollen gegen die korrigierten Regeln nicht unverändert als Erfolgstest verwendet werden.
