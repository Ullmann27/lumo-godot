# Lumo auf dem Galaxy Z Fold7 prüfen

APK-Version und Buildnummer aus der App, Godot-Commit aus dem Baunachweis, Android-Version, Grafikprofil und Datum notieren. Ein vorhandenes Kinderprofil behalten. Für Aufnahmen einen lokalen Testnamen verwenden.

| Versuch | Durchführung und erwartetes Ergebnis | Gerätebefund |
| --- | --- | --- |
| Kart-Hauptmenü | Garage verlassen und das Hauptmenü **mindestens zehn Minuten** sichtbar lassen. Nach einer, fünf und zehn Minuten prüfen, ob Lumo und Kart vollständig sichtbar sind. Einmal auf- und zuklappen. Zeitpunkt jedes Verschwindens sowie einer sichtbaren Reparatur notieren. | NICHT GETESTET |
| Riesengarten | Mit langsamem und mit schnellem Kart die drei Steilkurven im Schlauch fahren. Innenlinie und goldene Außenlinie ausprobieren. In der Topfspirale bis unter die obere Bahn fahren. Freie Durchfahrt, ruhigen Horizont, Gegner und Rücksetzer beobachten. | NICHT GETESTET |
| Runde zwei | Kurz vor dem ersten Rundenwechsel pausieren, fortsetzen und über die Linie fahren. Die Sicht soll allmählich klarer werden. In der Tautropfen-Allee unter dem ersten Wasserbogen hindurchfahren und eine Stelle außerhalb der Wasserlinie vergleichen. | NICHT GETESTET |
| Weitere Strecken | Auf Dschungeltempel, Winter-Sprint und Wüsten-Drift von der Einfahrt bis zum Tunnelausgang fahren. Jeweils auf Lichtwechsel, freie Landung, Sammelzonen und alle Gegner achten. Strecke, Abschnitt und Profil bei Rucklern notieren. | NICHT GETESTET |
| Sternenpost | Über die App-Kachel starten, zwei Briefe zustellen, pausieren und zum Menü zurückkehren. Weiterfliegen und die Tour beenden. Sternestand vor dem Start und nach der Rückkehr vergleichen. Das Ergebnis ein zweites Mal öffnen und prüfen, ob der Stand stabil bleibt. | NICHT GETESTET |
| Lumo-Lauf | Eine Welt bis zum Ziel laufen. Medaille und Bestzeit ablesen und nach erneutem Start vergleichen. | NICHT GETESTET |
| 3D-Nachhilfe | Je eine Plus-, Minus- und Malaufgabe öffnen. Darstellungen und Hilfeschritte antippen. Nach dem Zuklappen prüfen, ob Figuren, Aufgabe und Bedienelemente weiterhin sichtbar und erreichbar sind. | NICHT GETESTET |

### Zusätzlicher Durchgang für Build 2065

| Versuch | Durchführung und erwartetes Ergebnis | Gerätebefund |
| --- | --- | --- |
| Nach der Ziellinie | Ein Einzelrennen beenden, „Zur Streckenwahl“ und dann „Karts“ antippen. Beim nächsten Cup-Ergebnis „Neue Fahrt auswählen“ öffnen. In beiden Fällen Lumo und Kart ansehen und drehen. Dasselbe mit einem Faltwechsel am Ergebnisbildschirm wiederholen. | NICHT GETESTET |
| Bremsen in der Werkstatt | Das ganze Kart ansehen, „Teile wechseln“ öffnen und Serie mit Sportbremse vergleichen. Das gewählte Teil und Lumo bleiben sichtbar. Den Bremsweg vom gleichen Starttempo auf derselben Geraden vergleichen. | NICHT GETESTET |
| Motoren im Starterfeld | Im Stand ohne Gas zuhören, dann vor Grün Gas halten und lösen. Nach dem Losfahren bremsen. Mit demselben Kart den Auspuff wechseln und zum Vergleich ein Kart mit anderem Antrieb wählen. Beim Vorbeifahren auf die Richtung des gegnerischen Motors achten. | NICHT GETESTET |
| Lumos Windwerk | Zwei volle Runden fahren. An den Schiebeplatten zuerst die sichere Linie und dann die schnellere Linie nehmen. Die Torzeichen auf der zweiten Runde erneut lesen. | NICHT GETESTET |
| Dorf und Spieltisch | Ein Haus frei setzen, ein Gehege ziehen und durch das Tor gehen. Die Starthilfe beenden und allein weiterbauen. Am Kartentisch eine Partie Punktlandung und am neuen Schachbrett einen legalen Zug spielen. | NICHT GETESTET |
| Erklären und selbst lösen | In der ersten Klasse ein Bild antippen und eine Sachaufgabe mit Anschauung lösen. In der zweiten Klasse Bild und Text verbinden. In Klasse drei oder vier die Strategie selbst begründen. Beobachten, wohin Lumo beim Vormachen und nach einem Fehler zeigt. | NICHT GETESTET |

Für 2064 zusätzlich die Rechenhilfe bei **8 + 5**, **14 − 8** und **6 × 7** oder bei einer gleichartigen Aufgabe öffnen. Das Kind lässt den ersten Sprung auf der Zehn landen und führt den zweiten selbst aus. Beim Punktefeld die goldene Reihe erklären lassen und das Feld drehen. Für einen Vergleich mit einem späteren Übungstag bei gleich schweren, neuen Aufgaben die Anzahl selbstständiger Lösungen, Versuche und benötigter Hilfen im selben lokalen Profil notieren.

Die Menüdiagnose kann auf einem per USB verbundenen Rechner während des Versuchs mitlaufen:

```sh
adb logcat -v time | rg --line-buffered 'KartMenu'
```

Bei einem Eintrag `[KartMenu] preview_repair:<grund>` den genauen Grund, die Uhrzeit und den sichtbaren Zustand vor und nach dem Eintrag aufschreiben. Bei einem leeren Protokoll nur das beobachtete Verhalten festhalten. Testergebnis pro Zeile als **PASS GERÄT**, **FEHLER** oder **NICHT GETESTET** eintragen.
