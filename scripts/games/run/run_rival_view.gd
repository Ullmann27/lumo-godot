extends Node3D
## How Fips looks while he races Lumo: the rigged squirrel of the roster (the
## same Fips as at the card table), running with his own sprint cycle
## (run_rival_gait.gd), tucked in the air over everything he hops, cheering at
## the finish when he was first, with a soft ground shadow and a small name tag.
## Purely visual; the race itself is run_rival.gd.

const ROSTER = preload("res://scripts/games/lumo_opponent_roster.gd")
const GAIT = preload("res://scripts/games/run/run_rival_gait.gd")
const MODEL_ID: String = "squirrel"
## Fips stands about 1.5 m tall next to Lumo (1.75 m at hero scale).
const MODEL_SCALE: float = 1.08
## Speed (m/s on screen) at which the sprint cycle plays at its own rate.
const CYCLE_SPEED: float = 13.0

var world
var rival
var model: Node3D
var player: AnimationPlayer
var skeleton: Skeleton3D
var tag: Label3D
var shadow: MeshInstance3D
var reduced_motion: bool = false
## How much faster than course time the run plays on screen.
var pace_scale: float = 1.0
var has_gait: bool = false
var _clip: String = ""
var _won: int = -1
var _lean: float = 0.0
var _previous: Vector3 = Vector3.ZERO


func setup(race_world, race_rival, lightweight: bool, calm: bool, scale_on_screen: float) -> bool:
	world = race_world
	rival = race_rival
	reduced_motion = calm
	pace_scale = scale_on_screen
	var path: String = ROSTER.racing_model_path(MODEL_ID, 2 if lightweight else 1)
	if path.is_empty() or not ResourceLoader.exists(path, "PackedScene"):
		push_warning("[LumoRun] rival model missing: " + MODEL_ID)
		return false
	model = (load(path) as PackedScene).instantiate() as Node3D
	model.name = "Fips"
	model.scale = Vector3.ONE * MODEL_SCALE
	add_child(model)
	for node in model.find_children("*", "Skeleton3D", true, false):
		skeleton = node
	for node in model.find_children("*", "AnimationPlayer", true, false):
		player = node
	if skeleton == null or player == null:
		return false
	has_gait = GAIT.new().build(player, skeleton)
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_build_shadow()
	_build_tag()
	_play("idle")
	follow(0.0, true)
	return true


func _build_shadow() -> void:
	shadow = MeshInstance3D.new()
	shadow.name = "GroundShadow"
	var disc := CylinderMesh.new()
	disc.top_radius = 0.42
	disc.bottom_radius = 0.42
	disc.height = 0.02
	disc.radial_segments = 20
	shadow.mesh = disc
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.0, 0.0, 0.0, 0.32)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow.material_override = material
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shadow.top_level = true
	add_child(shadow)


func _build_tag() -> void:
	tag = Label3D.new()
	tag.name = "NameTag"
	tag.text = str(rival.display_name)
	tag.font_size = 56
	tag.pixel_size = 0.005
	tag.outline_size = 12
	tag.modulate = Color("ffe1c4")
	tag.outline_modulate = Color("4a2412")
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.position = Vector3(0.0, 1.95, 0.0)
	add_child(tag)


func _play(clip: String, blend: float = 0.12) -> void:
	if player == null or clip == _clip:
		return
	var wanted: String = clip
	if clip != "idle" and not has_gait:
		wanted = "idle"
	elif clip != "idle":
		wanted = GAIT.clip(clip)
	if not player.has_animation(wanted):
		return
	_clip = clip
	player.play(wanted, blend)


## Places him on the way and picks his movement. `snap`: no smoothing.
func follow(delta: float, snap: bool = false) -> void:
	if rival == null or not rival.enabled():
		visible = false
		return
	visible = true
	var at: float = clampf(
		float(rival.s),
		float(world.s_min) if world.get("s_min") != null else 0.0,
		float(world.length)
	)
	var basis: Basis = world.frame(at)
	var feet: Vector3 = world.position_at(at, float(rival.lat)) + basis.y * float(rival.h)
	var moved: Vector3 = feet - _previous
	var lateral: float = 0.0 if snap or delta <= 0.0 else moved.dot(basis.x) / maxf(delta, 0.0001)
	_previous = feet
	_lean = lerpf(_lean, clampf(-lateral * 0.04, -0.25, 0.25), clampf(delta * 8.0, 0.0, 1.0))
	transform = Transform3D(basis * Basis(Vector3.FORWARD, _lean), feet)
	if is_instance_valid(shadow):
		var ground: Vector3 = (
			world.position_at(at, float(rival.lat)) + basis.y * (float(rival.h) - _hop_part())
		)
		shadow.global_transform = Transform3D(basis, ground + basis.y * 0.04)
		var height: float = _hop_part()
		shadow.scale = Vector3.ONE * clampf(1.0 - height * 0.12, 0.45, 1.0)
	var on_screen: float = float(rival.speed) * pace_scale
	if _won >= 0 and on_screen < 1.0:
		_play("cheer" if _won == 1 else "idle", 0.25)
	elif rival.hopping and _hop_part() > 0.25:
		_play("leap", 0.08)
	elif on_screen > 1.0:
		_play("run", 0.15)
	else:
		_play("idle", 0.25)
	if player != null:
		player.speed_scale = (clampf(on_screen / CYCLE_SPEED, 0.55, 1.5) if _clip == "run" else 1.0)
	tag.visible = not rival.finished or _won >= 0


func _hop_part() -> float:
	if not rival.hopping:
		return 0.0
	return maxf(0.0, float(rival.h) - float(rival._ground(rival.s)))


## The end of the race: `fips_first` makes him cheer once he stands still.
func finish(fips_first: bool) -> void:
	_won = 1 if fips_first else 0
	tag.text = (
		"%s – Erster!" % str(rival.display_name)
		if fips_first
		else "%s – knapp dahinter" % str(rival.display_name)
	)
