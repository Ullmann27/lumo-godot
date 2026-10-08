extends RefCounted
## Roadside furniture uses the world's spatial MultiMesh batches.
## Every footprint is checked against the road before placement.

const NAVY := Color("183755")
const WHITE := Color("edf3ee")
const CYAN := Color("70e5ed")
const WOOD := Color("b78155")
const FLOWER := Color("ed8fab")
const GREEN := Color("57a583")
const KINDS: Array[String] = ["pit", "tribune", "planter", "bench", "waylight", "crystal"]
const ROAD_CLEARANCE: float = 8.5


static func build(world) -> void:
	var before: int = world.decoration_count
	var count: int = 12 if world.low_detail else 32
	for i in range(count):
		var d: float = (float(i) + 0.35) * world.length / float(count)
		if world.in_gap(d) or world.ramp_height(d) > 0.0:
			continue
		if world.track_id == "bergwelt" and world._is_bridge(d):
			continue
		if world.track_id == "sonnenhafen" and world._is_bridge(d):
			continue
		var kind: String = KINDS[i % KINDS.size()]
		if world.track_id == "zauberwald" and kind == "pit":
			kind = "bench"
		if world.track_id == "holo_city" and kind == "planter":
			kind = "waylight"
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var at: Vector3 = world.position_at(
			d, side * (14.0 if kind in ["pit", "tribune"] else 11.8)
		)
		var radius: float = 4.2 if kind in ["pit", "tribune"] else 1.8
		# Nearby parallel course sections are included in this clearance check.
		if world._near_road(at, ROAD_CLEARANCE + radius):
			continue
		at.y = world.position_at(d).y - 0.12
		if world.track_id in ["sonnenhafen", "zauberwald", "holo_city"]:
			at.y = world._ground_height(at.x, at.z)
			if at.y < -2.0:
				continue
		var basis: Basis = world.frame(d)
		basis = Basis(Vector3.UP, basis.get_euler().y)
		add_prop(world, kind, at, basis)
	world.set_meta("fleet_dressing_detail_count", world.decoration_count - before)


static func add_prop(world, kind: String, at: Vector3, basis: Basis = Basis.IDENTITY) -> void:
	match kind:
		"pit":
			for x in [-2.1, 2.1]:
				for z in [-2.4, 2.4]:
					_put(
						world, "box", at, basis, Vector3(x, 1.6, z), Vector3(0.18, 3.2, 0.18), NAVY
					)
			_put(world, "box", at, basis, Vector3(0, 3.23, 0), Vector3(4.7, 0.25, 5.4), WHITE)
			_put(
				world,
				"box",
				at,
				basis,
				Vector3(0, 3.08, -2.6),
				Vector3(4.1, 0.07, 0.07),
				CYAN,
				true
			)
			_put(world, "box", at, basis, Vector3(-1.8, 0.70, 1.4), Vector3(0.62, 1.4, 0.75), NAVY)
			for drawer in range(4):
				_put(
					world,
					"box",
					at,
					basis,
					Vector3(-1.79, 0.22 + drawer * 0.30, 0.995),
					Vector3(0.47, 0.06, 0.035),
					CYAN
				)
			for side in [-1.0, 1.0]:
				_put(
					world,
					"box",
					at,
					basis,
					Vector3(side * 1.45, 2.70, 0.2),
					Vector3(0.75, 0.16, 0.20),
					NAVY
				)
				_put(
					world,
					"cylinder",
					at,
					basis,
					Vector3(side * 1.10, 2.35, 0.2),
					Vector3(0.13, 0.7, 0.13),
					WHITE
				)
		"tribune":
			for row in range(3):
				var y: float = 0.35 + row * 0.48
				var z: float = -1.0 + row * 0.90
				_put(world, "box", at, basis, Vector3(0, y, z), Vector3(5.3, 0.13, 0.52), WOOD)
				for side in [-1.0, 1.0]:
					_put(
						world,
						"box",
						at,
						basis,
						Vector3(side * 2.35, y * 0.5, z),
						Vector3(0.12, y, 0.15),
						NAVY
					)
			for side in [-1.0, 1.0]:
				_put(
					world,
					"box",
					at,
					basis,
					Vector3(side * 2.7, 1.6, 0.4),
					Vector3(0.13, 3.2, 0.13),
					NAVY
				)
			_put(
				world,
				"roof",
				at,
				basis,
				Vector3(0, 3.28, 0.4),
				Vector3(5.8, 0.4, 3.4),
				Color("8c9bdd")
			)
			_put(
				world,
				"box",
				at,
				basis,
				Vector3(0, 2.98, -1.28),
				Vector3(5.55, 0.06, 0.07),
				CYAN,
				true
			)
		"planter":
			_put(world, "box", at, basis, Vector3(0, 0.3, 0), Vector3(1.8, 0.6, 0.75), WHITE)
			_put(world, "box", at, basis, Vector3(0, 0.62, 0), Vector3(1.65, 0.07, 0.66), WOOD)
			for i in range(5):
				var x: float = (float(i) - 2.0) * 0.30
				_put(
					world, "crown", at, basis, Vector3(x, 0.84, 0), Vector3(0.30, 0.24, 0.30), GREEN
				)
				_put(world, "flower", at, basis, Vector3(x, 1.03, 0), Vector3.ONE * 0.40, FLOWER)
		"bench":
			for slat in range(4):
				_put(
					world,
					"box",
					at,
					basis,
					Vector3(0, 0.58, -0.23 + slat * 0.15),
					Vector3(1.8, 0.06, 0.115),
					WOOD
				)
			for side in [-1.0, 1.0]:
				_put(
					world,
					"box",
					at,
					basis,
					Vector3(side * 0.64, 0.27, 0),
					Vector3(0.12, 0.54, 0.44),
					NAVY
				)
			for slat in range(3):
				_put(
					world,
					"box",
					at,
					basis,
					Vector3(0, 0.82 + slat * 0.16, 0.32),
					Vector3(1.8, 0.11, 0.07),
					WOOD
				)
		"waylight":
			_put(world, "cylinder", at, basis, Vector3(0, 1.7, 0), Vector3(0.10, 3.4, 0.10), NAVY)
			_put(world, "box", at, basis, Vector3(0, 3.36, 0), Vector3(0.72, 0.12, 0.72), WHITE)
			_put(
				world, "box", at, basis, Vector3(0, 3.22, 0), Vector3(0.42, 0.18, 0.42), CYAN, true
			)
			_put(world, "roof", at, basis, Vector3(0, 3.58, 0), Vector3(0.84, 0.32, 0.84), NAVY)
		"crystal":
			_put(world, "rock", at, basis, Vector3(0, 0.10, 0), Vector3(1.5, 0.4, 1.3), NAVY)
			for i in range(5):
				var a: float = float(i) * TAU / 5.0
				var h: float = 1.1 + float(i % 3) * 0.38
				var p := Vector3(cos(a) * 0.36, h * 0.48, sin(a) * 0.36)
				_put(
					world,
					"crystal",
					at,
					basis,
					p,
					Vector3(0.38, h, 0.38),
					CYAN if i % 2 == 0 else Color("ad96ee"),
					true
				)


static func _put(
	world,
	shape: String,
	at: Vector3,
	basis: Basis,
	local: Vector3,
	size: Vector3,
	color: Color,
	glow: bool = false
) -> void:
	world._prop(shape, at + basis * local, size, color, basis, glow)
