# Gemeinsame Android-Safe-Area: Quellencheckpoint vor neuer Native-CI

Die 21 expliziten Quelldateien sind eingefroren. Die eigentlichen Layouts verwenden einen gemeinsamen, rein lesenden Android-View-Adapter und Cache; Cards behält seinen bestehenden Layout-Sidecarvertrag. Regeln und Speicherformate werden nicht geändert.

Dieser Checkpoint enthält 13 tatsächlich abgeschlossene betroffene lokale Gates sowie den neuen gemeinsamen Headlesslauf (112 Prüfungen) und echten lokalen Xorg-Lauf (124 Prüfungen, vier PNGs). Alle 15 ursprünglich gemessenen Ziele sind vollständig außerhalb der Plattformränder und mindestens 48 dp groß. Die frühere Gegenprobe an796b hatte neun unsichere Ziele. Die Original-Logs werden unverändert übernommen.

Zwei lokale Abschlüsse bleiben in diesem historischen Checkpoint ausdrücklich offen: die Werkstatt-Gesamtprüfung und der neue Cards-Rendererlauf. Ihre Sitzungs-Handles waren nach einer Unterbrechung nicht mehr verfügbar; Teilbilder und Teilprüfungen werden nicht als vollständiges PASS ausgegeben. Nur diese beiden Pflichtläufe werden auf identischen Quellbytes nochmals abgeschlossen und später mit separaten Originalabschlussdaten ergänzt.

Die Plattformgrenze ist eine kontrollierte Fixture. Die Bilder stammen aus Godots echtem lokalen Software-Renderer; sie sind keine Android-Screenshots und kein Leistungsnachweis. Die neue verpflichtende Native-CI und die tatsächlichen Android35/37-Tests bleiben erforderlich.
