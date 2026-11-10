extends "res://scripts/games/kart_world.gd"
## Frozen APK2013 forest generator to verify unchanged random sequence and scenery.


func _forest() -> void:
	for i in range(250 if not low_detail else 145):
		var p := Vector3(_rng.randf_range(-93, 93), 0, _rng.randf_range(-84, 84))
		if Vector2(p.x / 94.0, p.z / 85.0).length() > 1.0 or _near_road(p, 9.8):
			continue
		p.y = _ground_height(p.x, p.z)
		_tree(p, _rng.randf_range(1.4, 2.8), _rng)
		if i % 4 == 0:
			_mushroom(p + Vector3(2, 0, 1), _rng.randf_range(0.9, 1.8))
		if i % 2 == 0:
			_prop("crown", p + Vector3(1, 0.25, 1), Vector3(1.5, 0.6, 1.3), Color("397964"))
			_prop("fir", p + Vector3(-1, 0.05, -1), Vector3(0.8, 0.5, 0.8), Color("75a783"))
		if i % 6 == 0:
			_flower_patch(p + Vector3(-2, 0, 1), Color("aac8ec"), 6)
	for i in range(28):
		var d: float = float(i) * length / 28.0
		var p: Vector3 = position_at(d, 8.0 if i % 2 == 0 else -8.0)
		p.y = _ground_height(p.x, p.z)
		_mushroom(p, 0.65 + float(i % 3) * 0.20)
		_prop(
			"crystal",
			p + Vector3(1, 0, 1),
			Vector3(0.4, 0.6, 0.4),
			Color("83d4d7"),
			Basis.IDENTITY,
			true
		)
	for i in range(40):
		var d: float = _rng.randf_range(0, length)
		var p: Vector3 = (
			position_at(d, _rng.randf_range(-14, 14)) + Vector3.UP * _rng.randf_range(2.5, 6.0)
		)
		_prop("ball", p, Vector3.ONE * 0.065, Color("e1f0a3"), Basis.IDENTITY, true)
	_forest_reference_dressing()
	_arch(length * 0.63, "LICHTERHAIN", Color("b2dcdf"))
