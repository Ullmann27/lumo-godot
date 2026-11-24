# Lumo World: Korrektur der tatsächlichen Spielansichten

Ausgangspunkt ist Godot `9decd8eb59b03f31cdc7b2a33b0703a1e0d9b8c2`.
Die fünf vorhandenen Capture-Positionen, ihre Auflösungen und der normale
Kameraverlauf bleiben unverändert. Der Patch korrigiert Produktverhalten.

## Befunde und Änderungen

| Sichtbarer Befund in Build 2069 | Produktkorrektur |
| --- | --- |
| Laub verdeckt Kart und eigenes Dorf. | Der World-Kamerahelfer prüft echte Baum-/Buschgrenzen zwischen Kamera und Figur sowie das räumliche Volumen vor der Kamera einschließlich Viewport-Ecken. Nur die betroffenen Instanzen werden aus dem Sichtbereich genommen und danach wiederhergestellt. |
| „Ansprechen“ reicht über den rechten Rand. | Das Layout misst die tatsächliche minimale Buttonbreite nach Textänderungen, richtet die ganze Spalte rechts aus und hält den Joystick daneben. Das Mindestmaß des vorhandenen Joysticks wird nur für die World-Instanz angepasst. |
| Der Schulweg endet optisch an einem hohen Steinsockel. | Die vorhandenen Dorfmodelle werden auf ihrer ursprünglichen Bodenebene y=0 aufgestellt. Ihr für Hänge vorgesehener Sockel bleibt im Boden. Eine kollidierende Rampe und ein Podest führen zur vorhandenen, richtig ausgerichteten Schultür. |
| Ein großes schwebendes Schild überlagert Lumo auf der Schatzinsel. | Ein kleines, fest ausgerichtetes Wegschild „Sonnendorf →“ steht seitlich des Wegs. Die ursprüngliche Schatzsuche wird nicht verändert. |

## Vegetation und Erhaltung bestehender Daten

`GeometryInstance3D.transparency` wird im Compatibility-Renderer nicht unterstützt.
Die Korrektur verwendet deshalb einen privaten MultiMesh-Arbeitspuffer und
behält dessen ursprüngliche Grenzen (`custom_aabb`) bei. Material, Mesh,
Quellressource, Elternsichtbarkeit, LOD-Sichtweiten und Kollisionen bleiben
erhalten. Der bestehende Dorfspielstand wird weiterhin ausschließlich gelesen.

Der vorhandene Batch-Erzeuger speichert zusätzlich seine unveränderten
Authoring-Transformationen als Ressourcenmetadaten. So entstehen die
Kameraabfragen und privaten Puffer ohne Rücklesen des GPU-Buffers. Das ist
auch für den Headless-Dummy notwendig, der keine echten MultiMesh-Drawdaten
bereitstellt. Resource-Austausch und freigegebene Instanzen werden erkannt;
beim Szenenende werden Sichtbarkeit und ursprüngliche Ressourcen restauriert.

API-Grundlage: [GeometryInstance3D, Godot 4.6](https://docs.godotengine.org/en/4.6/classes/class_geometryinstance3d.html)
und [MultiMesh, Godot 4.6](https://docs.godotengine.org/en/4.6/classes/class_multimesh.html).

## Lokale Prüfung

Godot 4.7.2, Headless-Dummy, jeweils Exit 0:

- `lumo_world_regression.gd`: **194 Checks bestanden**. Dazu gehören beide
  protokollierten Problempositionen, echte Baumgeometrie am Rand des
  Kameravolumens, Wiederherstellung nach Wegblick, Erhaltung versteckter
  LOD-Eltern, Zielwechsel, Puffer-Neuaufbau und Freigabe. Lumo läuft mit dem
  echten Joystick ab `(110, 0.2, -20)` bis auf das Türpodest; der Test prüft
  Fortschritt und Höhe des tatsächlichen CharacterBody ohne Teleport.
- `lumo_world_hud_regression.gd`: **499 Checks bestanden**. Vier Größen
  (344×882, 640×360, 720×1280, 1280×720), jeweils Gespräch, Portal,
  erneutes Gespräch sowie deaktivierte Interaktion an der Schule. Geprüft
  werden vollständige Labels, sichere Ränder, mindestens 48px große
  Schaltflächen und Überschneidungsfreiheit mit dem Joystick.

Die vollständigen finalen Ausgaben stehen in
`lumo-world-2070-local-regression.txt`. Frühere fehlgeschlagene Prüfläufe
gelten nicht als Nachweis für den finalen Patch.

## Noch erforderliche sichtbare Abnahme

Die lokalen Headless-Prüfungen erzeugen keine Spielbilder und belegen keine
Android-Bildrate. Die vorhandene CI muss alle fünf Ansichten mit Godot 4.6.3
im tatsächlichen Compatibility-Renderer erneut aufnehmen. Der Capture prüft
zusätzlich die echten Transformationen der verdeckenden Draw-Instanzen und
ihrer unveränderten Quelle; `vegetationClearance.rendererVerified` muss für
jede Ansicht wahr sein. Die Screenshots bleiben die visuelle Abnahmegrundlage.
