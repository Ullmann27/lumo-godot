# Lumo: vorhandenes Kart als editierbare 3D-Quelle

## Nachgewiesene Werkzeugkette

Die vorhandene Spielgeometrie aus
[kart_vehicle.gd](https://github.com/Ullmann27/lumo-godot/blob/4577e26f1b917f963c947964b7e54c2c2d6f2b53/scripts/games/kart_vehicle.gd)
wurde unverändert in Godot 4.6.3 erzeugt, als GLB exportiert und in Godot
reimportiert. Blender 5.0.1 importierte dieses GLB, speicherte eine editierbare
`.blend`-Datei und exportierte erneut GLB. Dieses zweite GLB wurde anschließend
in Godot reimportiert und auf Geometrieanzahl sowie Materialbelegung geprüft.

Die ausgeführten Prüfungen ermittelten 24 Mesh-Objekte, 124.210 Dreiecke und
62 Materialressourcen. Blender fand 4 Bilder und keine Armature. Der finale
Godot-Roundtrip bestätigt identische Mesh- und Dreieckszahl und ein Material
auf jeder Oberfläche. Die JSON-Berichte liegen bei den Exporten.

## Reproduktion

Erst alle vorgesehenen Quelldateien committen. Die Entwickler-Werkzeuge
zeichnen den tatsächlichen Commit und lokale getrackte Abweichungen auf.
Unversionierte Zwischenstände sind keine freigegebene Art-Basis.

```sh
godot --headless --path . --script res://tools/aaa_export_runtime_asset.gd
blender --background --factory-startup --python tools/aaa_blender_archive.py -- \
  exports/aaa-production/lumo-comet-existing.glb exports/aaa-production
godot --headless --path . --script res://tools/aaa_verify_glb.gd
```

Exporter und Godot-Verifikation akzeptieren zusätzlich `-- --output=/absoluter/pfad`.
Blender muss denselben Ordner als zweites Argument erhalten. Der Exporter
inventarisiert das Original-GLB mit SHA-256; Blender protokolliert Eingangs-
und Ausgangsprüfsummen. Godot lehnt nachträglich veränderte Dateien ab.
Der Roundtrip prüft Geometrieanzahl und vorhandene Materialbelegung, nicht
Pixelgleichheit, korrekte UVs oder shaderübergreifende Materialidentität.

Es werden die vorhandenen Originalformen und Materialressourcen übernommen.
Unsichtbare Fernansicht sowie Laufzeit-Flammen/Funken werden nicht exportiert.
Pivot-Hierarchie und lokale Transformationen bleiben enthalten. Das Archiv
liegt außerhalb der ausgelieferten Spielfiles; keine zusätzlichen GLB- oder
Blender-Produktionsdateien vergrößern dadurch die APK.

## Bewusste Grenzen

Dies ist eine nachweislich importierbare, statische Produktionsquelle,
kein neu retopologisierter oder skelettgeriggter AAA-Charakter. Prozedurale
GDScript-Animationen werden nicht als erfundene GLTF-Animationen ausgegeben.
Kein automatischer Austausch des getesteten Laufzeitmodells. Keine behauptete
Materialgleichheit eines Offline-Renderings, keine Geräte-FPS-Freigabe.
Die Geometriezahlen sind Inventarwerte, kein Nachweis eines mobilen Budgets.

Quelle: vorhandenes nutzereigenes Repository. Es wurden keine externen
Stock-Modelle, kostenpflichtigen Generatoren oder neuen Assetlizenzen ergänzt.

## Grafik-Übergabe ohne erneute Recherche

`tools/aaa_reference_packet.py` sammelt ausschließlich vorhandene Originalreferenzen,
echte Aufnahmen und das geprüfte 3D-Archiv. Es startet weder einen Renderer
noch eine Bildgenerierung. Es weist falsche Referenzprüfsummen, ungültige
Aufnahmegrößen, veraltete Laufzeitaufnahmen, schmutzige Quellstände und eine
Abweichung zwischen App-Pin und Godot-Laufzeit zurück.

```sh
python3 -m unittest discover -s tools -p test_aaa_reference_packet.py -v
python3 tools/aaa_reference_packet.py \
  --app-repo ../lumo-lernen \
  --menu-captures exports/aaa-menu \
  --model-captures exports/reference-design \
  --cards-captures ../lumo-lernen/ci-out/cards-visual \
  --assets exports/aaa-production \
  --output exports/astra-handoff
```

Die Ausgabe enthält `handoff-manifest.json`, unveränderte Originalreferenzen,
Bildmetadaten, echte Screenshots, `.blend`, zwei GLBs und Prüfberichte.
Die Ausgabe bleibt außerhalb aller Runtime-Exports. Android-FPS,
Gerätetests, APK-Abnahme und finale Art-Freigabe sind ausdrücklich nicht
Bestandteil dieses Entwickler-Pakets.
