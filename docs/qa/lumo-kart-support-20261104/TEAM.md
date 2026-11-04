# Lumo Kart: Unterstützungsrunde mit zehn Spezialaufgaben

Datum: 4. November 2026 (Europe/Vienna).

## Auftrag und Arbeitsweise

Heinz hat drei weitere Helfer für Lumo Kart angefordert und insgesamt zehn
Agenten gewünscht. Alle zehn hier aufgeführten Helferaufträge wurden gestartet.
Die Laufzeit erlaubte bis zu drei gleichzeitig aktive Helfer neben der
Koordination; die zehn Aufträge wurden deshalb in aufeinanderfolgenden Wellen
bearbeitet. Auftrag 2 endete ohne eigenen Patch oder verwertbaren Abschluss;
seine Basisprüfung übernahm die Koordination.

Änderungen wurden auf getrennten Zweigen bearbeitet und einzeln überprüft.
Der produktive Hauptzweig wurde nicht verändert. Die originale Lumo-Figur und
vorhandene Strecken bleiben die Ausgangsbasis. Die Referenzmappe ist ein
Gestaltungsziel; Quellcodeprüfungen beweisen keine visuelle Gleichheit mit ihr.

## Quellstand und Wiederherstellung

Zunächst wurde im geteilten Arbeitsbereich der lokale Stand
`7dd22580c4a4b65e2586be66ab4283e5b28c054e` auf
`assist/lumo-kart-reference-team-20261104` gefunden. Er enthielt zusätzliche
Sonnenhafen-Grafikarbeit. Nach dem Ausfall und Neuaufbau der Ausführungsumgebung
waren dieser Checkout und die neuen temporären Helfer-Worktrees in dieser
Sitzung nicht mehr verfügbar. Die GitHub-Abfrage dieses Commits lieferte 404.
Ob eine weitere Kopie außerhalb dieser Sitzung besteht, ist nicht geklärt. Es wird nicht
behauptet, dass er im wiederhergestellten Stand enthalten ist.

Die nachfolgende Umsetzung basiert ausdrücklich auf dem erneut von GitHub
abgerufenen Commit `a81ddf12d594cc252caef7503162e89c6b26e1c7`, Zweig
`integration/lumo-2006-native-20261103`. Ein sauberer Godot-4.6.3-Import von
492 Ressourcen endete mit Exit 0 und ohne Engine-/Script-/Parsefehler.
Jeder Helfer erhielt einen eigenen Importcache und ausschließlich solche
Importdeskriptoren, deren Quelldateien per SHA256 mit diesem Stand übereinstimmen.

Die Ergänzungen müssen vor einer Integration in einen wiedergefundenen neueren
Hauptchat-Stand gegen dessen aktuelle Dateien geprüft werden. Sie sind kein
Ersatz für die zusätzliche Grafikarbeit des anderen Teams.

## Zuständigkeiten

| Nr. | Spezialgebiet | Arbeitsgrenze | Status |
|---|---|---|---|
| 1 | Grafik und Referenzen | Originalreferenzen wieder verfügbar machen | abgeschlossen: Referenzmappe wiederhergestellt |
| 2 | Fahrphysik-Erstprüfung | Fahrcontroller und Antrieb | ohne Patch beendet; Basisprüfung durch Koordination, Vertiefung durch 5 und 7 |
| 3 | Fahreranimation | Lumo-Animationsadapter, reale Fahrerregression | abgeschlossen: Taktrückstand korrigiert, Tests bestanden |
| 4 | Renderqualität für die Android-Integration | Qualitätswechsel und unterstützte Effekte | abgeschlossen: Fähigkeitsprüfung für HIGH korrigiert; Hosttests bestanden |
| 5 | Sprünge und Landung | Rampen-, Landungs- und Rücksetzverhalten | abgeschlossen: zwei bestehende Regressionen bestanden, kein Produktionspatch |
| 6 | Touchsteuerung | Fingerbesitz und korrekte Tastenfreigabe | abgeschlossen: fremde Maustastenfreigabe setzt Lenkung nicht mehr zurück |
| 7 | Gegner und Rennablauf | Gegnerzustände und bestehende Rennverträge | abgeschlossen: 103 Rosterprüfungen und Itemfeedback-Regression bestanden |
| 8 | Ressourcen und Darstellung | Blender-Geometriezählung ohne Rig-Hilfsobjekte | abgeschlossen: 1 tatsächliches Mesh, 30.000 Dreiecke; Original und Rückexport unverändert |
| 9 | Unabhängige Codeprüfung | reproduzierte Änderungen der Helfer | abgeschlossen: keine blockierenden Befunde; ein konkreter Testhinweis behoben |
| 10 | Integrationsübergabe | Quellidentität, Belege, offene Prüfschritte | gestartet |

## Referenz und erstes überprüftes Ergebnis

Die Originalmappe wurde aus dem bestehenden Projektordner erneut abgerufen:
`libfile_dca26bf12c6c8191a18643ce74547a26`, 75.905.897 Bytes, 152 Seiten.
Die Koordination hat die Bildtafeln Sonnenhafen auf den Seiten 16 und 17
visuell geprüft sowie die Vorgaben auf den Seiten 98 und 112–118 gelesen.
Insbesondere bleiben die vorhandene Originalfigur, klare Fahrbahnränder und
die Trennung von technischem Hosttest und Android-Leistungsnachweis verbindlich.
Die Mappe selbst kennzeichnet ihre Bilder als Designreferenzen.

Der Fahreradapter verlor zuvor den Rest seines 30-Hz-Intervalls. In einem
zweisekündigen Test ergaben 50-/75-Hz-Eingaben nur 50 Clipauswertungen,
144-Hz-Eingaben 57. Nach der begrenzten Akkumulatorkorrektur ergeben alle
geprüften Eingaberaten 30/50/60/75/90/120/144 Hz jeweils 60 Auswertungen.
Die neue Regression bestand 1.196 Prüfungen, die vorhandene
Fahrer-Produktintegration 2.069 Prüfungen. Das tatsächliche importierte
Lumo-Modell wurde verwendet; seine Geometrie blieb unverändert.
Die maximale gemessene Handankerabweichung in der neuen Regression betrug
1,1494 mm bei 6 mm Prüftoleranz. Pause, lange Einzel-Frames, wechselnde normale
Frame-Dauern und das Freigeben der Figureninstanzen sind mitgeprüft.

Der Original-Baseline-Lauf von `kart_physics_regression.gd` bestand ebenfalls.
Er liefert noch keinen Vorher-Nachher-Nachweis einer Fahrphysikänderung.

## Weitere überprüfte Ergebnisse

Die Qualitätsstufe HIGH überschreibt die vorhandene Renderer-/Plattformpolitik
nicht mehr. SSAO und volumetrischer Nebel folgen nun derselben Freigabe wie in
KartEnvironmentPolish. Die neue Regression bestand unter den drei auf dem
Linux-Host ausgewählten Renderermethoden Compatibility, Mobile und Forward+.
Die bestehenden Prüfungen für Rendererprofile, Qualitätspersistenz und
Szenenwechsel bestanden ebenfalls. Die Belege samt bekannten Startwarnungen
stehen in `evidence/render_quality/README.md`. Mobile als Renderermethode ist
kein Android-Gerätetest.

Der Joystick gibt einen mit der linken Maustaste gehaltenen Lenkeingriff nur
bei Freigabe dieser Taste auf. Die neue Regression reproduzierte zuvor genau
drei Fehler bei einer zwischenzeitlich losgelassenen rechten Taste und bestand
nach der Ein-Bedingungs-Korrektur. Die bestehenden Touch-Integrationstests
bestanden ebenfalls. Geprüft wurden synthetische InputEvents im tatsächlichen
Godot-Control-/Viewport-Pfad, einschließlich zweitem Finger, Freigabe außerhalb
und Deaktivierung. Physische Touchhardware und Gerätelatenz sind nicht geprüft.

Die Koordination hat die neue Fahrer-, Renderer- und Joystickregression nach
der jeweiligen Übernahme in ihren gemeinsamen Zweig erneut erfolgreich
ausgeführt. Dies prüft die übernommenen Änderungen; es ersetzt keinen
vollständigen App-Build.

Für die Sprungberechnung bestanden 37 Prüfungen der vorhandenen Präzisions-
Regression sowie die bestehende dynamische Prüfung für normalen Absprung,
Landung, Landeboost, zu langsamen Anlauf, Rettung und Checkpoint-Reihenfolge.
Die aktuelle Präzisionsrampe ist 3 m hoch und zielt 14,5–31 m weit. Der in der
Referenzmappe verlangte Flug in 2–3 km Höhe ist damit weder umgesetzt noch
abgenommen. Das grafische Präzisions-Stuntszenario wurde hier nicht ausgeführt.

Die Gegnerliste bestand 103 Prüfungen zu den fünf Identitäten, Referenzdateien,
Pfadgrenzen und ausgewählten Rotationen. Die bestehende Itemfeedback-Regression
bestand ebenfalls: Puls-Vorwarnung ohne Soforttreffer, Ausweichen, Schildblock,
Gegnerschild und begrenzter Boost. Die Sichtbarkeitsaussagen dieses Tests beruhen
auf `visual_state()`-Flags, nicht auf gerenderten Pixeln. Positionen und Zustände
werden im Test gezielt gesetzt; ein vollständiger KI-Rennlauf wurde damit nicht
abgenommen. Die Rosterprüfung lädt nicht sämtliche Figurenmodelle oder Animationen.

Das Blender-Prüfwerkzeug zählte bislang ein vom glTF-Importer erzeugtes
Knochenanzeige-Hilfsobjekt mit: 2 Meshes und 30.080 Dreiecke statt 1 Mesh und
30.000 Dreiecken. Die Korrektur verwendet tatsächliche
`pose_bone.custom_shape`-Objektreferenzen, keine Namens- oder Sichtbarkeitsfilter.
Ein Blender-4.3.2-Lauf sowie das direkte Auslesen der GLB-Geometriedaten
bestätigen die korrigierte Zählung. Der Original-SHA256 bleibt
`3559f700784bc1006905ee3aae01e8bcfbffb95b4f621f7430ce771ba0e3efd5`;
auch der Rückexport ist bytegleich zum vorigen Rückexport. Es wurde kein neues
Modell eingebunden. Die vorhandene Meldung zur fehlenden optionalen
Draco-Bibliothek und die Samplerwarnung sind im Log erhalten. Dieser Lauf
bestätigt weder Materialtreue noch eine bestimmte Bildrate.

## Unabhängige Codeprüfung

Auftrag 9 prüfte alle vier Implementierungsänderungen einschließlich Blender
und die drei neuen Godot-Regressionen lesend. Dabei wurden keine blockierenden
Fehler gefunden. Der Reviewer startete keine zusätzlichen Tests.

Ein nichtblockierender Hinweis betraf die Aussagekraft des Renderer-Szenenwechsels:
Unter Compatibility und Mobile waren die Anfangswerte der zweiten Umgebung
bereits passend. Die Koordination ließ diese Umgebung daraufhin bewusst mit den
entgegengesetzten Werten zur zuvor geprüften HIGH-Umgebung starten. Damit muss
der Szenenwechsel in allen drei Fällen tatsächlich den Zustand korrigieren.
Die verstärkte Regression bestand anschließend mit dem strikten Probe-Runner
unter Compatibility, Mobile und Forward+ (jeweils Exit 0). Die drei
`renderer-strengthened-*.log`-Dateien belegen diese gezielte Nachprüfung.

## Nachweisgrenzen

Godot-Hosttests, native Desktopbilder, Blenderbilder und Android-Gerätetests
werden getrennt ausgewiesen. Ein erfolgreicher Import oder eine bestandene
Regression beweist weder 60 FPS auf dem Fold7 noch eine fertig signierte APK.
Diese Unterstützungsrunde veröffentlicht kein App-Update ohne dessen eigenen
Build-, Signatur- und Gerätebeleg.

Eine tatsächliche native Startprobe mit X11 scheiterte; auch der automatische
Wayland-Versuch konnte keinen Displayserver öffnen. DISPLAY und WAYLAND_DISPLAY
sind nicht gesetzt, ein /dev/dri-Gerät steht in dieser Umgebung nicht bereit.
Der Fehlerbeleg ist als `native-renderer-availability.log` erhalten. Deshalb
liegt aus dieser Runde kein gerendertes aktuelles Spielbild vor; die visuell
geprüften Sonnenhafen-Bilder stammen aus der Referenzmappe.
