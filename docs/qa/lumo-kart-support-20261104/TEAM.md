# Lumo Kart: Unterstützungsrunde mit zehn Spezialaufgaben

Datum: 4. November 2026 (Europe/Vienna).

## Auftrag und Arbeitsweise

Heinz hat drei weitere Helfer für Lumo Kart angefordert und insgesamt zehn
Agenten gewünscht. Diese Runde verwendet drei gleichzeitig aktive Helfer neben
der Koordination. Weitere Spezialisten werden nacheinander gestartet, sobald
ein Platz frei wird. Ein geplanter Auftrag zählt nicht als gestarteter Agent.

Änderungen entstehen auf getrennten Zweigen und werden einzeln überprüft.
Der produktive Hauptzweig wird nicht verändert. Die originale Lumo-Figur und
vorhandene Strecken bleiben die Ausgangsbasis. Die Referenzmappe ist ein
Gestaltungsziel; Quellcodeprüfungen beweisen keine visuelle Gleichheit mit ihr.

## Quellstand und Wiederherstellung

Zunächst wurde im geteilten Arbeitsbereich der lokale Stand
`7dd22580c4a4b65e2586be66ab4283e5b28c054e` auf
`assist/lumo-kart-reference-team-20261104` gefunden. Er enthielt zusätzliche
Sonnenhafen-Grafikarbeit. Nach dem Ausfall und Neuaufbau der Ausführungsumgebung
waren dieser Checkout und die neuen temporären Helfer-Worktrees nicht mehr
verfügbar. Die GitHub-Abfrage dieses Commits lieferte 404. Es wird nicht
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
| 1 | Grafik und Referenzen | Materialien, Shader, Originalreferenzen | gestartet |
| 2 | Fahrphysik | Fahrcontroller, Antrieb, zugehörige Regressionen | gestartet |
| 3 | Fahreranimation | Lumo-Animationsadapter, reale Fahrerregression | gestartet |
| 4 | Android-Renderqualität | Qualitätswechsel und unterstützte Effekte | eingeplant |
| 5 | Sprünge und Landung | Rampen-, Landungs- und Rücksetzverhalten | eingeplant |
| 6 | Touchsteuerung | Fingerbesitz, Freigabe, Fokuswechsel | eingeplant |
| 7 | Gegner und Rennablauf | Gegnerzustände und bestehende Rennverträge | eingeplant |
| 8 | Ressourcen und Darstellung | begrenzte technische und visuelle Prüfungen | eingeplant |
| 9 | Unabhängige Codeprüfung | reproduzierte Änderungen der Helfer | eingeplant |
| 10 | Integrationsübergabe | Quellidentität, Belege, offene Freigabeschritte | eingeplant |

## Nachweisgrenzen

Godot-Hosttests, native Desktopbilder, Blenderbilder und Android-Gerätetests
werden getrennt ausgewiesen. Ein erfolgreicher Import oder eine bestandene
Regression beweist weder 60 FPS auf dem Fold7 noch eine fertig signierte APK.
Diese Unterstützungsrunde veröffentlicht kein App-Update ohne dessen eigenen
Build-, Signatur- und Gerätebeleg.
