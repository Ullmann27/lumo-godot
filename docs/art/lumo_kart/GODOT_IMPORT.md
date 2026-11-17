# Godot-Import und Animationswechsel

Die GLBs enthalten vollständige Translation-, Rotations- und Skalierungskanäle
für die Fahrerposen. Für einen direkten Laufzeitimport ist der vierte Parameter
von `GLTFDocument.generate_scene` auf `false` zu setzen:

```gdscript
var model = document.generate_scene(state, 30.0, false, false)
```

Beim normalen Editorimport ist entsprechend
`animation/remove_immutable_tracks=false` zu wählen. Der mitgelieferte isolierte
`tools/lumo_kart_art/asset_contract_loader.gd` erhält diese Kanäle ausdrücklich.

Die Prüfung hat am Rabbit-Export `869bd782ca7f3f5ab616ac3a3c1852432ad60783844e3564542f9f56f17d8c9a`
einen tatsächlichen Unterschied gezeigt: Mit der Standardeinstellung blieben
nach einem vorherigen `idle` beim Wechsel zu `kart_seated` Transformationswerte
erhalten; die gemessenen Handknochen lagen dadurch auf Y=0,625 m statt Y=1,055 m.
Die ursprüngliche negative Messung steht in `godot_contacts_probe.json`. Dies
ist ein Import-/Wechselfehler; der GLB enthält die konstanten Rückstellkanäle.
Die endgültige Prüfung misst die Sequenz mit erhaltenen Kanälen erneut und
schreibt einen eigenen Bericht. Eine bloß vorhandene Animationsliste reicht
als Funktionsnachweis nicht aus.

Offizielle Dokumentation für die verwendete Godot-Version:

- [Godot 4.6 GLTFDocument: generate_scene](https://docs.godotengine.org/en/4.6/classes/class_gltfdocument.html#class-gltfdocument-method-generate-scene)
- [Godot 4.6 ResourceImporterScene](https://docs.godotengine.org/en/4.6/classes/class_resourceimporterscene.html)

## Einbaugrenze

Der Helper lädt Modelle, erhält die Animationsverträge, verbindet Modulsockets
und erzeugt konkave statische Tunnelkollisionen. Er ist ein isoliertes Angebot
an das Hauptteam. Keine dieser Methoden ist in `kart_vehicle.gd`, `kart_world.gd`
oder `kart_island.gd` eingehängt. Die vorhandene Rivalenliste bleibt unverändert.
