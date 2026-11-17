# Lernstudio: aktuelles Teilen, Multiplizieren und Bruchrechnen

## Tatsächlicher Ausgangsbefund

Die native Lernwerkstatt hatte bereits acht gültige Deskriptortypen und echte
Zehner-, Gruppen-, Hunderter-, Bruch-, Silben- und Pflanzenszenen. Die bekannte
8+5-Erklärung ist vorhandener Bestand. Division fehlte. Das Gruppenmodell
füllte eine Gruppe nach der anderen und konnte gleichmäßiges Teilen nicht
darstellen. Der Flutter-Aufgabenadapter lieferte für × und : keine Operanden.

## Neue produktive Funktion

`learning_activity.gd` akzeptiert `equal_sharing` mit der tatsächlichen
Ausgangsmenge und Anzahl der Gruppen. Die Bedienung verteilt pro Runde einen
Würfel an jede Gruppe. Bei 12 : 3 laufen die Zielplätze 0,4,8,1,5,9 usw.; nach
jeder vollständigen Runde haben alle drei Gruppen genau gleich viele Würfel.
Kein Objekt verschwindet, wird dupliziert oder durch eine andere Aufgabe ersetzt.

Die vorhandene `learning_world.gd` erstellt die echten Würfel und räumlichen
Gruppenablagen. Jede Gruppe zeigt ihre tatsächliche aktuelle Menge als TextMesh;
die nächste Gruppe wird hervorgehoben. Ziehen, Antippen eines Würfels und der
mindestens 52 logische Pixel hohe Aktionsknopf verwenden denselben Modellweg.
Layoutwechsel erhalten die bereits verteilten Gruppen. Pause sperrt weitere
Aktionen; Neustart stellt dieselbe Ausgangsmenge wieder her.

Der Anschluss erfolgt aus der aktuellen adaptiven Flutter-Aufgabe über
`NativeLearningActivity`, den bestehenden Android-Host und die vorhandene
Produktionsroute `learning`. Die Kotlin-Zulassung enthält `equal_sharing`.
Zusätzlich erreichen vorhandene ×-Aufgaben das bestehende Gruppenmodell und
gleichnamige Bruchadditionen das vorhandene räumliche Bruchmodell.

## Bewusste Grenzen und Bestandsschutz

Das neue Einzelwürfelmodell unterstützt 2–6 Gruppen mit jeweils 1–6 Würfeln,
also höchstens 36 echte Objekte. Nicht ganzzahlige Ergebnisse, größere Mengen,
ungültige Operanden und unpassende Aufgabenlösungen werden nicht verändert oder
heimlich vereinfacht; sie behalten ihre bisherige Lernansicht. Multiplikation
verwendet die vorhandene Grenze 6 × 6, Bruchaddition höchstens zwölf gleich
große Teile und nur echte gleichnamige Brüche innerhalb eines Ganzen.

Es gibt keine neue Profildatenbank und keine Speichermigration. Die native
Werkstatt meldet weiterhin nur `illustrated`. Flutter markiert Hilfe vor dem
Start und bewertet erst die spätere echte Antwort. Schreibtrainer, Journal,
Kinderprofilgrenzen, Offline-Sprachfreigabe und Testsperren bleiben zuständig.

## Tatsächlich ausgeführte Prüfungen

- `learning_sharing_regression.gd`: **1811 Prüfungen bestanden**, einschließlich
  Mengeninvarianz, fairer Verteilung, fehlerhafter JSON-Eingaben, echter
  ScreenTouch-Ereignisse auf Würfel/Aktionsknopf, Layoutwechsel, Pause und Neustart.
- Vorhandenes `learning_world_regression.gd`: **5328 Prüfungen bestanden**.
- Die vier bearbeiteten/neuen GDScript-Dateien bestehen `gdformat --check`.
- `learning_sharing_capture.gd` kompiliert und verweigert Headless-Betrieb
  ausdrücklich mit Exitcode 1. Das ist ein negativer Gate-Test, kein Renderbild.

Rohlogs und SHA-256 der bearbeiteten Dateien stehen in
`docs/evidence/studio-learning-20261113/RESULT.json`. Die Laufzeittests sind keine
Android- oder Fold7-Messung und belegen keine 60 FPS.

## Noch zu prüfende Bilder

Der Renderer-Capture erzeugt sechs echte Vorher-/Runden-/Ergebnisbilder für
12 : 3 in 1280 × 720 und 412 × 915. Er prüft vollständige Objektgrenzen zwischen
Header und Footer, korrekte räumliche Gruppenzähler und tatsächliche Touch-
Aktionen. Die Bilder und das Manifest müssen im zentralen Grafik-/Android-Lauf
erzeugt und visuell geprüft werden. Dieser Teilbericht behauptet keine bereits
geprüften neuen Screenshots und keine neue APK.
