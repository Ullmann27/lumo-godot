extends Node
## Bildweise Glättung im Rennen (nur Darstellung, keine Spielregel).
## Das Rennen rechnet Karts, Kamera und Raketen im festen 60-Hz-Physiktakt. Zeigt das
## Gerät nicht genau ein Bild je Takt (z. B. 45–55 Bilder/s oder 120 Hz mit Bildratenbremse),
## springen diese Knoten je Bild mal 0, mal 1, mal 2 Takte weit: genau das ruckelt.
## Dieser Knoten merkt sich nach jedem Takt die echte Lage (`curr`) und die davor (`prev`)
## und zeigt zwischen zwei Takten die passende Zwischenlage
## (`Engine.get_physics_interpolation_fraction()`). Vor jedem neuen Takt stellt er die
## echte Lage wieder her, damit die Spiellogik nie die Anzeige-Lage sieht.
## Zusätzlich trägt er reine Anzeige-Versätze ein (z. B. „Gegner wirbelt in die Luft“),
## die ebenfalls vor jedem Takt verschwinden – Runden, Checkpoints und Fahrbahn bleiben
## damit unberührt.
## Fremde Schreibzugriffe (Tests, Rücksetzer, Menü-Tweens) werden erkannt und übernommen.

## Weiter als so viele Meter in einem Takt = Teleport (Rücksetzer, Start): kein Gleiten.
const SNAP_DISTANCE: float = 6.0

## Liefert die zu glättenden Knoten (Array von Node3D); leer = Glättung ruht.
var nodes_provider: Callable
## Optional: Callable(node: Node3D) -> Variant; ein Transform3D wird in Knoten-Raum
## nach der Zwischenlage angehängt (reiner Anzeige-Versatz), sonst null.
var offset_provider: Callable
## Tests ohne echten Physiktakt rufen begin_tick()/end_tick() selbst und setzen das.
var manual: bool = false
## Zwischenlage für manual (0..1), z. B. aus einer nachgestellten Bildfolge.
var manual_fraction: float = 1.0
var enabled: bool = true
var ticks: int = 0
## Statistik für Tests/Messung.
var interpolated_frames: int = 0
var adopted_writes: int = 0
var _entries: Dictionary = {}


func _ready() -> void:
	name = "KartFrameSmoother"
	# Nach jeder anderen Physik (Erfassen) und nach jedem anderen _process (Anzeigen).
	process_physics_priority = 100000
	process_priority = 100000
	if not get_tree().physics_frame.is_connected(_on_physics_frame):
		get_tree().physics_frame.connect(_on_physics_frame)


func _exit_tree() -> void:
	restore_all()
	if get_tree() != null and get_tree().physics_frame.is_connected(_on_physics_frame):
		get_tree().physics_frame.disconnect(_on_physics_frame)


func _on_physics_frame() -> void:
	if not manual:
		begin_tick()


func _physics_process(_delta: float) -> void:
	if not manual:
		end_tick()


func tracked_count() -> int:
	return _entries.size()


## Vor dem Takt: echte Lage zurück (nur wenn niemand sonst inzwischen geschrieben hat).
func begin_tick() -> void:
	for id in _entries:
		var entry: Dictionary = _entries[id]
		var node: Node3D = entry.target.get_ref()
		if not is_instance_valid(node) or not bool(entry.shown):
			continue
		if node.transform.is_equal_approx(entry.shown_transform):
			node.transform = entry.curr
		else:
			adopted_writes += 1
		entry.shown = false


## Nach dem Takt: neue echte Lage merken.
func end_tick() -> void:
	ticks += 1
	var nodes: Array = _wanted_nodes()
	var seen: Dictionary = {}
	for node in nodes:
		if not is_instance_valid(node) or not (node as Node3D).is_inside_tree():
			continue
		var id: int = node.get_instance_id()
		seen[id] = true
		var now: Transform3D = (node as Node3D).transform
		if _entries.has(id):
			var entry: Dictionary = _entries[id]
			entry.prev = entry.curr
			entry.curr = now
			if entry.prev.origin.distance_to(now.origin) > SNAP_DISTANCE:
				entry.prev = now
		else:
			_entries[id] = {
				"target": weakref(node), "prev": now, "curr": now, "shown": false, "shown_transform": now
			}
	for id in _entries.keys():
		if not seen.has(id):
			_entries.erase(id)


## Alles auf die echte Lage zurück (Ende des Rennens, Szenenwechsel).
func restore_all() -> void:
	begin_tick()
	_entries.clear()


func _wanted_nodes() -> Array:
	if not enabled or not nodes_provider.is_valid():
		return []
	var result: Variant = nodes_provider.call()
	return result if result is Array else []


func _process(_delta: float) -> void:
	if _entries.is_empty():
		return
	var fraction: float = (
		clampf(manual_fraction, 0.0, 1.0)
		if manual
		else clampf(Engine.get_physics_interpolation_fraction(), 0.0, 1.0)
	)
	for id in _entries:
		var entry: Dictionary = _entries[id]
		var node: Node3D = entry.target.get_ref()
		if not is_instance_valid(node):
			continue
		var expected: Transform3D = entry.shown_transform if bool(entry.shown) else entry.curr
		if not node.transform.is_equal_approx(expected):
			# Jemand anderes hat die Lage gesetzt: übernehmen, nicht überschreiben.
			adopted_writes += 1
			entry.prev = node.transform
			entry.curr = node.transform
			entry.shown = false
			continue
		var shown: Transform3D = entry.prev.interpolate_with(entry.curr, fraction)
		if offset_provider.is_valid():
			var extra: Variant = offset_provider.call(node)
			if extra is Transform3D:
				shown = shown * (extra as Transform3D)
		node.transform = shown
		entry.shown_transform = shown
		entry.shown = true
		interpolated_frames += 1


## Anzeige-Lage eines Knotens zwischen den Takten (für Tests).
func display_transform(node: Node3D) -> Variant:
	var entry: Variant = _entries.get(node.get_instance_id())
	return entry.shown_transform if entry is Dictionary and bool(entry.shown) else null
