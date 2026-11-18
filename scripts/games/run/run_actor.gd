extends Node3D
## Lumo as seen in the run: the original rigged fox, leaning into turns, rolling
## in a dash, squashing on landings, with a soft ground shadow that makes jump
## height readable from behind. Purely visual; motion comes from run_player.gd.

const ORIGINAL_LUMO = preload("res://scripts/characters/lumo/lumo_rigged_actor.gd")
const FALLBACK = preload("res://scenes/characters/lumo/lumo_character.tscn")
const TUNING = preload("res://scripts/games/run/run_tuning.gd")
const MESHES = preload("res://scripts/games/run/jungle/run_jungle_meshes.gd")
const SHADERS = preload("res://scripts/games/run/jungle/run_jungle_shaders.gd")
## Height of the fox's skeleton in the kart worlds (hero scale).
const BONE_SPAN: float = 1.75
const BODY_CENTRE: float = 0.9
## Leg cadence relative to true ground contact: the stride follows the ground
## speed linearly, geared down so the legs stay readable at 13 m/s and more.
const CADENCE_GEAR: float = 0.5
## A runner's gait instead of the calm exploring walk: always the sprint clip,
## wider stride, higher knees, stronger arm swing and hip bob, pose follows quickly.
const RUN_STYLE := {"limb_gain": 1.35, "bounce_gain": 2.2, "run_floor": 1.0, "response": 55.0}

var rig
var pivot: Node3D
var shadow: MeshInstance3D
var reduced_motion: bool = false
var uses_original: bool = false
var _lean: float = 0.0
var _pitch: float = 0.0
var _squash: float = 0.0
var _roll: float = 0.0
var _blink: float = 0.0
var _celebrating: bool = false
var _flip: float = 0.0
var cart: MeshInstance3D


func setup(calm: bool) -> void:
	reduced_motion = calm
	pivot = Node3D.new()
	pivot.name = "Pivot"
	pivot.position.y = BODY_CENTRE
	add_child(pivot)
	var candidate = ORIGINAL_LUMO.new()
	candidate.name = "OriginalLumo"
	pivot.add_child(candidate)
	if candidate.is_usable() and _fit(candidate):
		rig = candidate
		uses_original = true
		rig.set_reduced_motion(calm)
		rig.set_platform_style(RUN_STYLE)
	else:
		pivot.remove_child(candidate)
		candidate.queue_free()
		var simple: Node3D = FALLBACK.instantiate()
		simple.scale = Vector3.ONE * 0.95
		simple.rotation.y = PI
		simple.position.y = -BODY_CENTRE + 0.3
		pivot.add_child(simple)
	shadow = MeshInstance3D.new()
	shadow.name = "GroundShadow"
	var disc := CylinderMesh.new()
	disc.top_radius = 0.62
	disc.bottom_radius = 0.62
	disc.height = 0.02
	disc.radial_segments = 20
	disc.rings = 1
	shadow.mesh = disc
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.02, 0.04, 0.1, 0.42)
	shadow.material_override = material
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shadow.top_level = true
	add_child(shadow)
	cart = MeshInstance3D.new()
	cart.name = "MineCart"
	cart.mesh = MESHES.cart()
	cart.material_override = SHADERS.material(SHADERS.SOLID)
	cart.rotation.y = PI
	cart.visible = false
	add_child(cart)


## Scales the original rig from its real skeleton, feet on the actor's origin.
func _fit(candidate: Node3D) -> bool:
	var skeleton: Skeleton3D = candidate.skeleton
	if skeleton == null or skeleton.get_bone_count() != 65:
		return false
	var lowest: float = INF
	var highest: float = -INF
	for bone in range(skeleton.get_bone_count()):
		var rest: Vector3 = skeleton.get_bone_global_rest(bone).origin
		if not rest.is_finite():
			return false
		lowest = minf(lowest, rest.y)
		highest = maxf(highest, rest.y)
	var span: float = highest - lowest
	if span <= 0.2 or span > 15.0:
		return false
	var scaled: float = clampf(BONE_SPAN / span, 0.08, 4.0)
	candidate.scale = Vector3.ONE * scaled
	candidate.rotation.y = PI
	candidate.position.y = -BODY_CENTRE - lowest * scaled
	return true


## Places Lumo for this frame. `feet` is his world transform, `ground` the road
## point below him; `player` is the motion model.
func apply(feet: Transform3D, ground: Transform3D, player, delta: float, frozen: bool) -> void:
	global_transform = feet
	var above: float = maxf(0.0, feet.origin.y - ground.origin.y)
	shadow.global_transform = Transform3D(
		ground.basis.scaled_local(Vector3.ONE * clampf(1.0 - above * 0.09, 0.45, 1.0)),
		ground.origin + ground.basis.y * 0.05
	)
	shadow.visible = above < 9.0 and player.loop_u < 0.0 and not player.is_riding()
	cart.visible = player.in_cart
	if uses_original:
		rig.set_suspended(frozen)
	if frozen or _celebrating:
		return
	if _ride_pose(player, delta):
		return
	if player.land_impact > 0.0:
		_squash = clampf(player.land_impact / 14.0, 0.2, 0.7)
	_squash = maxf(0.0, _squash - delta * 4.5)
	var rolling: bool = player.dash_time > 0.0
	if rolling and not reduced_motion:
		_roll += delta * TAU / TUNING.DASH_SECONDS
	else:
		_roll = 0.0
	var steer: float = clampf(player.lat_v / TUNING.LATERAL_SPEED, -1.0, 1.0)
	var lean_target: float = -steer * 0.30
	var pitch_target: float = -0.05 - clampf(player.speed / TUNING.CRUISE, 0.0, 1.6) * 0.13
	if player.stumble_time > 0.0:
		pitch_target = -0.42
		lean_target += sin(player.stumble_time * 38.0) * 0.22
	if reduced_motion:
		lean_target *= 0.35
		pitch_target = -0.05
	_lean = lerpf(_lean, lean_target, 1.0 - exp(-12.0 * delta))
	_pitch = lerpf(_pitch, pitch_target, 1.0 - exp(-10.0 * delta))
	if player.tumble_time > 0.0 and not reduced_motion:
		# A somersault backwards after a bump.
		_flip = TAU * (1.0 - player.tumble_time / TUNING.TUMBLE_SECONDS)
	else:
		_flip = 0.0
	pivot.rotation = Vector3(_pitch - _roll + _flip, 0.0, _lean)
	var stretch: float = 0.0
	if not player.grounded and not reduced_motion:
		stretch = clampf(absf(player.vy) / 16.0, 0.0, 0.12)
	var tall: float = 1.0 + stretch - _squash * (0.0 if reduced_motion else 0.36)
	if rolling and not reduced_motion:
		tall *= 0.86
	var wide: float = 1.0 + (1.0 - tall) * 0.55
	if player.in_cart:
		# Crouched in the mine cart, ears in the wind.
		tall *= 0.78
		_pitch = -0.25
	pivot.scale = Vector3(wide, tall, wide)
	pivot.position.y = BODY_CENTRE * tall + (0.55 if player.in_cart else 0.0)
	# Blink while Lumo cannot be bumped again; calm mode shows it without flicker.
	if player.invulnerable > 0.0 and not reduced_motion:
		_blink += delta
		pivot.visible = fmod(_blink, 0.16) < 0.11
	else:
		_blink = 0.0
		pivot.visible = true
	if uses_original:
		var pace: float = player.speed * CADENCE_GEAR if player.grounded else 0.0
		rig.set_platform_motion(Vector3(0.0, player.vy, -pace), player.grounded, delta)


## Barrel, vine and zip line poses. True when the pose is handled here.
func _ride_pose(player, delta: float) -> bool:
	if not player.is_riding():
		pivot.visible = true if player.invulnerable <= 0.0 or reduced_motion else pivot.visible
		return false
	var kind: String = str(player.ride.kind)
	pivot.scale = Vector3.ONE
	pivot.position.y = BODY_CENTRE
	match kind:
		"barrel", "warp":
			# Inside the barrel until it fires, then a spinning flight.
			pivot.visible = player.ride_fired
			_roll += delta * TAU * 1.6 if not reduced_motion else 0.0
			pivot.rotation = Vector3(-_roll, 0.0, 0.0)
		"vine", "zip":
			pivot.visible = true
			var swing: float = clampf(player.speed / 14.0, -0.6, 0.6)
			pivot.rotation = Vector3(-0.15 - swing * 0.5, 0.0, 0.0)
			pivot.scale = Vector3(0.95, 1.08, 0.95)
	if uses_original:
		rig.set_platform_motion(Vector3(0.0, player.vy, -2.0), false, delta)
	return true


func greet() -> void:
	if uses_original:
		rig.play_behavior("greeting_wave")


func celebrate() -> void:
	_celebrating = true
	pivot.rotation = Vector3.ZERO
	pivot.scale = Vector3.ONE
	pivot.position.y = BODY_CENTRE
	pivot.visible = true
	if uses_original:
		rig.set_suspended(false)
		rig.play_behavior("celebrate")


func body_position() -> Vector3:
	return global_position + global_basis.y * BODY_CENTRE
