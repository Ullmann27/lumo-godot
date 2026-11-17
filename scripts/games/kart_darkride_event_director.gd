extends RefCounted
## Lap-aware neon surge for Sonnenhafen's playable cave, non-destructive.
## Works from race progress; no extra physics, savegame state, new particles
## or frame-dependent randomness. Surges once per lap, starting on lap two.
signal darkride_phase_changed(phase: int)

enum Phase { OUTSIDE, ENTERING, CRUISING, WARNING, SURGE, EXITING }

const RIDE_PATH := "SonnenhafenBioluminescentDarkride"
const CARTOON_BURST = preload("res://scripts/games/kart_darkride_cartoon_burst.gd")
const BASE_SHADER_ENERGY: float = 1.10
const BASE_ARCH_ENERGY: float = 1.60
const NEON_SURGE_SECONDS: float = 2.4

var phase: int = Phase.OUTSIDE
var _tunnel: Node3D
var _burst
var _surface_materials: Array[ShaderMaterial] = []
var _rib_material: StandardMaterial3D
var _active_surge_seconds: float = -1.0
var _triggered_lap: int = -1
var _last_energy: float = -1.0
var _animation_time: float = 0.0


func bind_world(world) -> void:
	# A rebind must not leave the detached world at surge brightness.
	_apply_energy(BASE_SHADER_ENERGY, true)
	if is_instance_valid(_burst):
		_burst.get_parent().remove_child(_burst)
		_burst.queue_free()
	_burst = null
	_tunnel = null
	_surface_materials.clear()
	_rib_material = null
	_active_surge_seconds = -1.0
	_triggered_lap = -1
	_last_energy = -1.0
	_animation_time = 0.0
	_set_phase(Phase.OUTSIDE)
	if not is_instance_valid(world):
		return
	var found: Node = world.get_node_or_null(RIDE_PATH)
	if not found is Node3D:
		return
	_tunnel = found
	_burst = CARTOON_BURST.new()
	_burst.name = "LumoArcadeCrystalShockwave"
	_tunnel.add_child(_burst)
	_burst.setup(world, world.low_detail)
	for name in ["DarkrideRockAndCanopy", "DarkrideIlluminatedRoad"]:
		var mesh: MeshInstance3D = _tunnel.get_node_or_null(name)
		if mesh != null and mesh.material_override is ShaderMaterial:
			_surface_materials.append(mesh.material_override)
			mesh.material_override.set_shader_parameter("animation_time", 0.0)
	var ribs: MultiMeshInstance3D = _tunnel.get_node_or_null("DarkrideNeonArchRibs")
	if ribs != null and ribs.material_override is StandardMaterial3D:
		_rib_material = ribs.material_override
	var pools: MultiMeshInstance3D = _tunnel.get_node_or_null("CavernGeology/MineralWaterChannels")
	if pools != null and pools.material_override is ShaderMaterial:
		_surface_materials.append(pools.material_override)
	_apply_energy(BASE_SHADER_ENERGY, true)


func tick(
	absolute_distance: float, track_length: float, delta: float, reduced_motion: bool
) -> void:
	if not is_instance_valid(_tunnel) or track_length <= 1.0 or delta <= 0.0:
		return
	if not reduced_motion:
		_animation_time += delta
		for material in _surface_materials:
			material.set_shader_parameter("animation_time", _animation_time)
	var lap: int = floori(maxf(0.0, absolute_distance) / track_length)
	var fraction: float = fposmod(maxf(0.0, absolute_distance), track_length) / track_length
	# A respawn, lap jump or tunnel exit must not leave a running effect behind.
	# Do not clear _triggered_lap: revisiting the same lap must not duplicate VFX.
	if (
		_active_surge_seconds >= 0.0
		and (lap != _triggered_lap or fraction < 0.700 or fraction > 0.794)
	):
		_active_surge_seconds = -1.0
		if is_instance_valid(_burst):
			_burst.cancel()
	var next_phase: int = Phase.OUTSIDE
	if fraction >= 0.681 and fraction <= 0.809:
		if fraction < 0.700:
			next_phase = Phase.ENTERING
		elif fraction > 0.794:
			next_phase = Phase.EXITING
		else:
			next_phase = Phase.WARNING if lap >= 1 and fraction < 0.739 else Phase.CRUISING
			if fraction >= 0.739 and lap >= 1 and _triggered_lap != lap:
				_triggered_lap = lap
				_active_surge_seconds = 0.0
				if is_instance_valid(_burst):
					_burst.fire(reduced_motion)

	var surge: float = 0.0
	if _active_surge_seconds >= 0.0:
		_active_surge_seconds += delta
		var t: float = _active_surge_seconds
		if t >= NEON_SURGE_SECONDS:
			_active_surge_seconds = -1.0
		else:
			var onset: float = smoothstep(0.0, 0.34, t)
			var decay: float = 1.0 - smoothstep(0.72, NEON_SURGE_SECONDS, t)
			surge = onset * decay * (0.32 if reduced_motion else 1.0)
			if next_phase == Phase.CRUISING:
				next_phase = Phase.SURGE
	# Resolve once, after expiry: the timer cannot overwrite portal/outside phases.
	_set_phase(next_phase)

	var atmosphere: float = 0.0
	if phase != Phase.OUTSIDE:
		atmosphere = 0.08 if phase == Phase.ENTERING or phase == Phase.EXITING else 0.22
	_apply_energy(BASE_SHADER_ENERGY + atmosphere + surge * 0.95)
	if is_instance_valid(_burst):
		# Users may turn on reduced motion while the shockwave is in flight.
		_burst.set_reduced_motion(reduced_motion)
		_burst.advance(delta)


func _set_phase(next: int) -> void:
	if phase != next:
		phase = next
		darkride_phase_changed.emit(phase)


func _apply_energy(energy: float, force: bool = false) -> void:
	if not force and absf(energy - _last_energy) < 0.018:
		return
	_last_energy = energy
	for mat in _surface_materials:
		if is_instance_valid(mat):
			mat.set_shader_parameter("light_intensity", energy)
	if is_instance_valid(_rib_material):
		_rib_material.emission_energy_multiplier = (
			BASE_ARCH_ENERGY + maxf(energy - BASE_SHADER_ENERGY, 0.0) * 1.25
		)
