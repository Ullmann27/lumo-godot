extends SceneTree
## Rendert Lumos Bewegungsbilder für die Lern-App aus dem echten geriggten
## 3D-Modell (Lumo-Learning: gleicher Fuchs, gleiche 65 Originalknochen plus
## Ohrknochen, echte Mundformen). Jede Bewegung wird Feld für Feld in
## doppelter Größe vor durchsichtigem Grund gerendert; das Packskript
## tools/lumo_actor/pack_lumo_actor.py rechnet herunter und baut die Streifen.
##
## Aufruf (Renderer nötig):
##   xvfb-run -a -s '-screen 0 2560x2560x24' godot --path . \
##     --rendering-method gl_compatibility --audio-driver Dummy \
##     --script res://scripts/tests/lumo_actor_capture.gd -- <ausgabe> [bewegung,...]
## Bewegungen: idle run point talk listen think cheer comfort wave (oder survey).
## Das Modell und seine Texturen bleiben unverändert; Posen entstehen zur
## Laufzeit auf dem Skelett.

const MODEL := "res://assets/lumo_next/character/Lumo-Learning.glb"
const PLATFORM_POSE = preload("res://scripts/characters/lumo/lumo_platform_pose.gd")
## Wie im Jump & Run (scripts/games/run/run_actor.gd).
const RUN_STYLE := {"limb_gain": 1.35, "bounce_gain": 2.2, "run_floor": 1.0, "response": 55.0}
const SUPERSAMPLE := 2
const FRAME := 384
## Pixel je Meter im fertigen Feld (Lumo misst mit Ohren 1,70 m -> ~300 px).
const PX_PER_M := 176.0
## Fußpunkt im fertigen Feld.
const ANCHOR := Vector2(192.0, 352.0)
const PITCH_DEG := 5.0
const ALL_CLIPS: Array[String] = [
	"idle", "run", "point", "talk", "listen", "think", "cheer", "comfort", "wave"
]
const LID_STAGES: Array[String] = ["Quarter", "Half", "ThreeQuarter", "Close"]

var viewport: SubViewport
var camera: Camera3D
var holder: Node3D
var visual: Node3D
var skeleton: Skeleton3D
var player: AnimationPlayer
var shapes: Dictionary = {}
var lid_meshes: Array[MeshInstance3D] = []
var saved: Dictionary = {}
var out_dir: String = ""
var size_px: int = FRAME * SUPERSAMPLE


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("[LumoActor] Renderer nötig (xvfb + gl_compatibility)")
		quit(1)
		return
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("[LumoActor] Ausgabeordner fehlt")
		quit(1)
		return
	out_dir = args[0]
	var wanted: Array[String] = []
	if args.size() > 1:
		for part in args[1].split(",", false):
			wanted.append(part.strip_edges())
	else:
		wanted = ALL_CLIPS.duplicate()
	DirAccess.make_dir_recursive_absolute(out_dir)
	if not _build_stage():
		quit(1)
		return
	for clip in wanted:
		var ok: bool = await call(&"_clip_" + clip)
		if not ok:
			push_error("[LumoActor] Bewegung fehlgeschlagen: " + clip)
			quit(1)
			return
	print("[LumoActor] PASS ", ", ".join(wanted))
	quit(0)


# --- Bühne -------------------------------------------------------------------


func _build_stage() -> bool:
	root.size = Vector2i(256, 256)
	viewport = SubViewport.new()
	viewport.size = Vector2i(size_px, size_px)
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_8X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.own_world_3d = true
	root.add_child(viewport)
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("dfe6f2")
	env.ambient_light_energy = 0.62
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.04
	env_node.environment = env
	viewport.add_child(env_node)
	# Warmes Hauptlicht von vorn links oben.
	var key := DirectionalLight3D.new()
	key.light_color = Color("fff0d8")
	key.light_energy = 1.35
	key.rotation_degrees = Vector3(-38.0, -32.0, 0.0)
	viewport.add_child(key)
	# Weiche Aufhellung von rechts.
	var fill := DirectionalLight3D.new()
	fill.light_color = Color("e4ecff")
	fill.light_energy = 0.35
	fill.rotation_degrees = Vector3(-12.0, 48.0, 0.0)
	viewport.add_child(fill)
	# Kühles Kantenlicht von hinten.
	var rim := DirectionalLight3D.new()
	rim.light_color = Color("a9d4ff")
	rim.light_energy = 1.25
	rim.rotation_degrees = Vector3(-22.0, 165.0, 0.0)
	viewport.add_child(rim)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = float(FRAME) / PX_PER_M
	camera.near = 0.1
	camera.far = 40.0
	viewport.add_child(camera)
	camera.rotation_degrees = Vector3(-PITCH_DEG, 0.0, 0.0)
	var basis := camera.global_basis
	var dx := (ANCHOR.x - FRAME * 0.5) / PX_PER_M
	var dy := -(ANCHOR.y - FRAME * 0.5) / PX_PER_M
	camera.position = -dx * basis.x - dy * basis.y + basis.z * 12.0
	camera.current = true
	holder = Node3D.new()
	viewport.add_child(holder)
	var packed := load(MODEL) as PackedScene
	if packed == null:
		push_error("[LumoActor] Modell fehlt: " + MODEL)
		return false
	visual = packed.instantiate() as Node3D
	holder.add_child(visual)
	for node in visual.find_children("*", "Skeleton3D", true, false):
		skeleton = node
	for node in visual.find_children("*", "AnimationPlayer", true, false):
		player = node
	if skeleton == null or player == null:
		push_error("[LumoActor] Skelett oder Animationen fehlen")
		return false
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for node in visual.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh == null:
			continue
		if str(mesh_node.name) == "LumoEyelids":
			lid_meshes.append(mesh_node)
		for index in range(mesh_node.mesh.get_blend_shape_count()):
			var name := str(mesh_node.mesh.get_blend_shape_name(index))
			if not shapes.has(name):
				shapes[name] = []
			shapes[name].append([mesh_node, index])
	var projected := camera.unproject_position(Vector3.ZERO) / float(SUPERSAMPLE)
	print("[LumoActor] anchor projected ", projected, " soll ", ANCHOR)
	return true


# --- Werkzeuge ----------------------------------------------------------------


func _bone(name: String) -> int:
	return skeleton.find_bone(name)


func _restore() -> void:
	for index in saved:
		skeleton.set_bone_pose_rotation(int(index), saved[index])
	saved.clear()
	skeleton.force_update_all_bone_transforms()


func _save(index: int) -> void:
	if not saved.has(index):
		saved[index] = skeleton.get_bone_pose_rotation(index)


## Tastet einen vorhandenen Animationsclip zur Zeit t ab.
func _sample(clip: String, t: float) -> void:
	_restore()
	if player.current_animation != clip:
		player.play(clip, 0.0)
	player.seek(clamp(t, 0.0, player.get_animation(clip).length), true)
	skeleton.force_update_all_bone_transforms()


## Dreht einen Knochen um eine Achse im Körperraum der Figur (wie lumo_teacher_pose).
func _body_rot(name: String, rotation: Quaternion) -> void:
	var index := _bone(name)
	if index < 0:
		return
	_save(index)
	var body := visual.global_basis.orthonormalized().get_rotation_quaternion()
	var bone_world := (
		(skeleton.global_basis * skeleton.get_bone_global_pose(index).basis)
		. orthonormalized()
		. get_rotation_quaternion()
	)
	var local_delta := bone_world.inverse() * body * rotation * body.inverse() * bone_world
	skeleton.set_bone_pose_rotation(
		index, (skeleton.get_bone_pose_rotation(index) * local_delta).normalized()
	)
	skeleton.force_update_all_bone_transforms()


func _world_pos(index: int) -> Vector3:
	return skeleton.to_global(skeleton.get_bone_global_pose(index).origin)


func _rotate_toward(index: int, current: Vector3, desired: Vector3, weight: float) -> void:
	if current.length_squared() < 1e-8 or desired.length_squared() < 1e-8:
		return
	var world_delta := Quaternion(current.normalized(), desired.normalized())
	world_delta = Quaternion.IDENTITY.slerp(world_delta, clampf(weight, 0.0, 1.0))
	var world_rotation := (
		(skeleton.global_basis * skeleton.get_bone_global_pose(index).basis)
		. orthonormalized()
		. get_rotation_quaternion()
	)
	_save(index)
	var local_delta := world_rotation.inverse() * world_delta * world_rotation
	skeleton.set_bone_pose_rotation(
		index, (skeleton.get_bone_pose_rotation(index) * local_delta).normalized()
	)
	skeleton.force_update_all_bone_transforms()


## Zwei-Glieder-Ausrichtung des Arms auf einen Punkt in Körperkoordinaten.
## pole (Körperraum) gibt die Richtung vor, in die der Ellbogen ausweicht.
func _aim_arm(side: String, target_body: Vector3, weight: float, straight: float, pole: Vector3) -> void:
	var upper := _bone("UpperArm" + side)
	var fore := _bone("Forearm" + side)
	var wrist_i := _bone("Wrist" + side)
	var hand_i := _bone("Hand" + side)
	var at := visual.to_global(target_body)
	var shoulder := _world_pos(upper)
	var elbow := _world_pos(fore)
	var wrist := _world_pos(wrist_i)
	var l1 := shoulder.distance_to(elbow)
	var l2 := elbow.distance_to(wrist)
	var dist := shoulder.distance_to(at)
	if dist < 0.05:
		return
	var direction := (at - shoulder) / dist
	var reach := clampf(dist, absf(l1 - l2) + 0.001, (l1 + l2) * straight)
	var along := (l1 * l1 - l2 * l2 + reach * reach) / (2.0 * reach)
	var bend := sqrt(maxf(0.0, l1 * l1 - along * along))
	var pole_world := visual.global_basis.orthonormalized() * pole
	var bend_dir := pole_world - direction * pole_world.dot(direction)
	if bend_dir.length_squared() < 0.001:
		bend_dir = direction.cross(visual.global_basis.x)
	bend_dir = bend_dir.normalized()
	var want_elbow := shoulder + direction * along + bend_dir * bend
	var want_wrist := shoulder + direction * reach
	_rotate_toward(upper, elbow - shoulder, want_elbow - shoulder, weight)
	elbow = _world_pos(fore)
	wrist = _world_pos(wrist_i)
	_rotate_toward(fore, wrist - elbow, want_wrist - elbow, weight)
	wrist = _world_pos(wrist_i)
	var hand := _world_pos(hand_i)
	_rotate_toward(wrist_i, hand - wrist, at - wrist, weight)


func _rotate_world(index: int, world_delta: Quaternion) -> void:
	var world_rotation := (
		(skeleton.global_basis * skeleton.get_bone_global_pose(index).basis)
		. orthonormalized()
		. get_rotation_quaternion()
	)
	_save(index)
	var local_delta := world_rotation.inverse() * world_delta * world_rotation
	skeleton.set_bone_pose_rotation(
		index, (skeleton.get_bone_pose_rotation(index) * local_delta).normalized()
	)
	skeleton.force_update_all_bone_transforms()


## Fingerketten der linken/rechten Hand (Basis..Spitze). Gemessen am Skelett:
## die erste Kette ist der Daumen, die letzte der Zeigefinger.
const FINGERS := {
	".L": {"thumb": [52, 51, 50], "curl": [[56, 55, 54], [60, 59, 58]], "index": 64},
	".R": {"thumb": [36, 35, 34], "curl": [[40, 39, 38], [44, 43, 42]], "index": 48},
}


## Krümmt Mittel-/Ringfinger zur Handfläche und legt den Daumen an.
func _curl_fingers(side: String, amount: float) -> void:
	if amount <= 0.001:
		return
	var spec: Dictionary = FINGERS[side]
	var hand := _world_pos(_bone("Hand" + side))
	var index_base := _world_pos(_bone("Finger_%03d" % int(spec.index)))
	var outer_base := _world_pos(_bone("Finger_%03d" % int(spec.curl[1][0])))
	var across := (outer_base - index_base).normalized()
	var along := (index_base - hand).normalized()
	var normal := along.cross(across).normalized()
	var thumb_tip := _world_pos(_bone("Finger_%03d" % (int(spec.thumb[0]) - 3)))
	var palm := 1.0 if (thumb_tip - hand).dot(normal) > 0.0 else -1.0
	for chain in spec.curl:
		for joint in chain:
			var index := _bone("Finger_%03d" % int(joint))
			var tip := _world_pos(_bone("Finger_%03d" % (int(chain[0]) - 3)))
			var pivot := _world_pos(index)
			var angle := 0.62 * amount
			var probe := Quaternion(across, angle) * (tip - pivot)
			if (probe - (tip - pivot)).dot(normal) * palm < 0.0:
				angle = -angle
			_rotate_world(index, Quaternion(across, angle))
	var thumb_index := _bone("Finger_%03d" % int(spec.thumb[0]))
	var thumb_pivot := _world_pos(thumb_index)
	var toward := (index_base + (outer_base - index_base) * 0.5 + along * 0.03 + normal * palm * 0.02) - thumb_pivot
	_rotate_toward(thumb_index, thumb_tip - thumb_pivot, toward, 0.7 * amount)


func _shape(name: String, value: float) -> void:
	if not shapes.has(name):
		return
	for entry in shapes[name]:
		(entry[0] as MeshInstance3D).set_blend_shape_value(int(entry[1]), value)


func _clear_face() -> void:
	for name in shapes:
		_shape(name, 0.0)
	for mesh_node in lid_meshes:
		mesh_node.visible = false


## 0 = offen, 1 = zu. Vier gekrümmte Lidstufen wie lumo_facial_pose.
func _blink(value: float) -> void:
	for side in ["Left", "Right"]:
		for stage in range(4):
			var weight := maxf(0.0, 1.0 - absf(value * 4.0 - float(stage + 1)))
			_shape("Blink" + side + LID_STAGES[stage], weight)
	for mesh_node in lid_meshes:
		mesh_node.visible = value > 0.002


## Lidschlag-Kurve: schnell zu (2 Felder), etwas langsamer auf.
static func _blink_curve(frame: int, start: int) -> float:
	var curve := [0.55, 1.0, 0.7, 0.3]
	var k := frame - start
	return curve[k] if k >= 0 and k < curve.size() else 0.0


## Drehung um die Hochachse durch den Fußpunkt; lean neigt nach vorn.
func _set_yaw(degrees: float, lean: float = 0.0, lift: float = 0.0) -> void:
	holder.basis = Basis(Vector3.UP, deg_to_rad(degrees)) * Basis(Vector3.RIGHT, lean)
	holder.position = Vector3(0.0, lift, 0.0)


func _save_frame(clip: String, index: int) -> bool:
	for _i in range(2):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	var folder := out_dir.path_join(clip)
	DirAccess.make_dir_recursive_absolute(folder)
	return image.save_png(folder.path_join("f_%03d.png" % index)) == OK


func _write_meta(clip: String, data: Dictionary) -> void:
	data["supersample"] = SUPERSAMPLE
	data["px_per_m"] = PX_PER_M
	data["anchor"] = [ANCHOR.x, ANCHOR.y]
	var file := FileAccess.open(out_dir.path_join(clip).path_join("meta.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "  "))
	file.close()


# --- Übersicht vorhandener Clips ---------------------------------------------


func _clip_survey() -> bool:
	var clips := [
		"idle", "idle_breathe", "point", "point_portal", "explain", "listening", "thinking",
		"celebrate", "celebrate_step", "encourage", "agree_nod", "nod", "greeting",
		"greeting_wave", "farewell", "answer", "unsure",
	]
	var index := 0
	for clip in clips:
		var length: float = player.get_animation(clip).length
		for k in range(6):
			_clear_face()
			_set_yaw(40.0)
			_sample(clip, length * float(k) / 5.0)
			if not await _save_frame("survey", index):
				return false
			index += 1
	_write_meta("survey", {"clips": clips, "per_clip": 6})
	return true


# --- Bewegungen -----------------------------------------------------------------

## Blickwinkel: 3/4 nach rechts für ruhige Bewegungen, fast seitlich beim Laufen.
const FACE_YAW := 30.0
const RUN_YAW := 72.0
const POINT_YAW := 58.0
const RUN_LEAN := 0.05
const FEET: Array[String] = ["Foot.L", "Foot.R", "Toe.L", "Toe.R", "ToeTip.L", "ToeTip.R"]


## Tiefster Fußknochen in Weltkoordinaten (Bezug für Bodenkontakt).
func _foot_floor() -> float:
	var low := INF
	for name in FEET:
		low = minf(low, _world_pos(_bone(name)).y)
	return low


static func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


## Gemeinsame lebendige Zugaben: Schweif wiegt, Ohren zucken leicht.
func _alive(phase: float, tail_gain: float = 1.0) -> void:
	var tail := ["TailBase", "Tail1", "Tail2", "Tail3"]
	for k in range(tail.size()):
		_body_rot(tail[k], Quaternion(Vector3.UP, sin(phase - float(k) * 0.7) * 0.06 * tail_gain))


## Kopf/Nacken im Körperraum drehen: yaw (links/rechts), pitch (+ = nicken), roll.
func _look(yaw: float, pitch: float, roll: float = 0.0) -> void:
	_body_rot("Neck", Quaternion(Vector3.UP, yaw * 0.4) * Quaternion(Vector3.RIGHT, pitch * 0.4))
	_body_rot(
		"Head",
		Quaternion(Vector3.UP, yaw * 0.6) * Quaternion(Vector3.RIGHT, pitch * 0.6)
		* Quaternion(Vector3.BACK, roll)
	)


func _body_point(bone: String) -> Vector3:
	return visual.to_local(_world_pos(_bone(bone)))


## Ein Punkt am Kopf (in Ruhelage-Modellkoordinaten gemessen), wie er sich mit
## dem aktuell gedrehten Kopf mitbewegt – in Körperkoordinaten.
func _head_point(rest_point: Vector3) -> Vector3:
	var head := _bone("Head")
	var moved := (
		skeleton.get_bone_global_pose(head) * skeleton.get_bone_global_rest(head).affine_inverse()
	)
	return visual.to_local(skeleton.to_global(moved * rest_point))


func _clip_idle() -> bool:
	var frames := 24
	var length: float = player.get_animation("idle").length
	for i in range(frames):
		var u := float(i) / float(frames)
		_clear_face()
		_set_yaw(FACE_YAW)
		_sample("idle", u * length)
		_alive(u * TAU)
		_shape("Smile", 0.22)
		_blink(_blink_curve(i, 15))
		if not await _save_frame("idle", i):
			return false
	_write_meta("idle", {"frames": frames, "fps": 12, "loop": true, "yaw": FACE_YAW})
	return true


func _clip_run() -> bool:
	var frames := 16
	var fps := 20.0
	_clear_face()
	_set_yaw(RUN_YAW, RUN_LEAN)
	_sample("idle", 0.0)
	var ground := _foot_floor()
	var pose = PLATFORM_POSE.new()
	if not pose.bind(skeleton):
		return false
	pose.set_style(RUN_STYLE)
	var stride: float = pose.body_space.stride_metres(1.0)
	var speed: float = stride * fps / float(frames)
	var velocity := Vector3(0.0, 0.0, speed)
	for _k in range(frames * 4):
		pose.advance(velocity, true, 1.0 / fps)
	for i in range(frames):
		pose.advance(velocity, true, 1.0 / fps)
		# Der Stützfuß darf nie unter den Boden sinken (Höhe wie im Stand).
		_set_yaw(RUN_YAW, RUN_LEAN)
		var low := _foot_floor()
		_set_yaw(RUN_YAW, RUN_LEAN, maxf(0.0, ground - low))
		_clear_face()
		_shape("Smile", 0.35)
		_shape("AA", 0.12)
		if not await _save_frame("run", i):
			return false
	pose.stop()
	var stride_px: float = stride * sin(deg_to_rad(RUN_YAW)) * PX_PER_M
	_write_meta("run", {
		"frames": frames, "fps": int(fps), "loop": true, "yaw": RUN_YAW,
		"stride_px": snappedf(stride_px, 0.1), "stride_m": stride,
	})
	return true


## Zeitpunkt, an dem die Hand im Clip am höchsten ist (erste 97 %).
func _peak_time(clip: String, hand: String) -> float:
	var length: float = player.get_animation(clip).length
	var best := -INF
	var heights: Array[float] = []
	var t := 0.0
	while t <= length:
		_sample(clip, t)
		var y := _world_pos(_bone(hand)).y
		heights.append(y)
		best = maxf(best, y)
		t += 1.0 / 60.0
	var floor_y := heights[0]
	for k in range(heights.size()):
		if heights[k] >= floor_y + (best - floor_y) * 0.97:
			return float(k) / 60.0
	return length * 0.5


func _clip_point() -> bool:
	var frames := 8
	_set_yaw(FACE_YAW)
	var peak := _peak_time("point", "Hand.L")
	print("[LumoActor] point peak ", peak)
	for i in range(frames):
		var u := float(i) / float(frames - 1)
		var e := _ease(u)
		_clear_face()
		_set_yaw(lerpf(FACE_YAW, POINT_YAW, e))
		_sample("point", peak * e)
		# Ausgestreckter Arm schräg nach vorn oben (vorn = Blickrichtung = rechts im Bild).
		var shoulder := _body_point("UpperArm.L")
		var aim := shoulder + Vector3(0.05, 0.55, 0.83).normalized() * 0.9
		_aim_arm(".L", aim, e, 0.99, Vector3(0.3, -1.0, -0.2))
		# Zeigefinger bleibt gestreckt, Mittel-/Ringfinger und Daumen krümmen sich.
		_curl_fingers(".L", e)
		_look(0.0, -0.12 * e)
		_shape("Smile", 0.3 + 0.2 * e)
		_shape("LookUp", 0.5 * e)
		_alive(u * PI, 0.5)
		if not await _save_frame("point", i):
			return false
	_write_meta("point", {"frames": frames, "fps": 12, "loop": false, "yaw": POINT_YAW})
	return true


## Mundbilder eines kurzen Satzes (natürlicher Wechsel, kurze Pausen).
const TALK_MOUTH := [
	["MBP", 0.7], ["AA", 0.75], ["L", 0.5], ["OH", 0.7], ["EE", 0.55], ["", 0.0],
	["AA", 0.85], ["TH", 0.45], ["OU", 0.6], ["MBP", 0.6], ["EE", 0.7], ["AA", 0.6],
	["FV", 0.5], ["OH", 0.55], ["", 0.0], ["", 0.0],
]


func _clip_talk() -> bool:
	var frames := 16
	var length: float = player.get_animation("idle").length
	for i in range(frames):
		var u := float(i) / float(frames)
		var phase := u * TAU
		_clear_face()
		_set_yaw(FACE_YAW)
		_sample("idle", u * length)
		_look(-0.30, sin(phase * 2.0) * 0.05 - 0.02, sin(phase) * 0.04)
		var chest := _body_point("Chest")
		var hand := chest + Vector3(-0.24, -0.10 + 0.05 * sin(phase * 2.0 + 0.6), 0.32 + 0.03 * cos(phase))
		_aim_arm(".R", hand, 0.9, 0.95, Vector3(-0.6, -1.0, -0.2))
		_alive(phase, 0.7)
		var mouth: Array = TALK_MOUTH[i]
		if not str(mouth[0]).is_empty():
			_shape(str(mouth[0]), minf(1.0, float(mouth[1]) * 1.25))
		_shape("Smile", 0.18)
		_blink(_blink_curve(i, 9))
		if not await _save_frame("talk", i):
			return false
	_write_meta("talk", {"frames": frames, "fps": 12, "loop": true, "yaw": FACE_YAW})
	return true


func _clip_listen() -> bool:
	var frames := 16
	var length: float = player.get_animation("idle").length
	for i in range(frames):
		var u := float(i) / float(frames)
		var phase := u * TAU
		_clear_face()
		_set_yaw(FACE_YAW)
		_sample("idle", u * length)
		_look(-0.18, -0.03, -0.17 + 0.03 * sin(phase))
		_body_rot("Ear.R", Quaternion(Vector3.UP, -0.25 + 0.12 * sin(phase * 2.0)))
		# Hohle Hand seitlich am Kopf, auf Augenhöhe hinter dem rechten Ohr.
		var cup := _head_point(Vector3(-0.24, 1.31, 0.0))
		_aim_arm(".R", cup, 0.95, 0.95, Vector3(-1.0, -0.8, 0.0))
		_alive(phase, 0.6)
		_shape("Smile", 0.25)
		_shape("LookRight", 0.25)
		_blink(_blink_curve(i, 11))
		if not await _save_frame("listen", i):
			return false
	_write_meta("listen", {"frames": frames, "fps": 12, "loop": true, "yaw": FACE_YAW})
	return true


func _clip_think() -> bool:
	var frames := 16
	var peak := _peak_time("thinking", "Hand.R")
	print("[LumoActor] thinking peak ", peak)
	for i in range(frames):
		var u := float(i) / float(frames)
		var phase := u * TAU
		_clear_face()
		_set_yaw(FACE_YAW)
		_sample("thinking", peak + 0.12 * sin(phase))
		_look(-0.12, -0.16 + 0.03 * sin(phase), 0.08)
		# Pfote ans Kinn (Kinn des Modells in Ruhelage), Kinn wandert mit dem Kopf.
		var chin := _head_point(Vector3(0.0, 1.13, 0.24 + 0.015 * sin(phase * 2.0)))
		_aim_arm(".R", chin + Vector3(-0.02, -0.04, 0.03), 1.0, 0.95, Vector3(-0.4, -1.0, 0.1))
		_alive(phase, 0.8)
		_shape("LookUp", 0.8)
		_shape("LookRight", 0.3)
		_blink(_blink_curve(i, 4))
		if not await _save_frame("think", i):
			return false
	_write_meta("think", {"frames": frames, "fps": 12, "loop": true, "yaw": FACE_YAW})
	return true


## Einmalige Clips aus vorhandenen Animationen, 12 fps über die ganze Länge.
func _oneshot(name: String, clip: String, smile: float, hop: float, blink_at: int) -> bool:
	var length: float = player.get_animation(clip).length
	var frames := int(round(length * 12.0)) + 1
	for i in range(frames):
		var t := minf(float(i) / 12.0, length)
		var u := t / length
		_clear_face()
		var lift := 0.0
		if hop > 0.0 and u > 0.18 and u < 0.62:
			var k := (u - 0.18) / 0.44
			lift = hop * 4.0 * k * (1.0 - k)
		_set_yaw(FACE_YAW, 0.0, lift)
		_sample(clip, t)
		_alive(u * TAU, 1.2 if hop > 0.0 else 0.7)
		_shape("Smile", smile)
		if hop > 0.0:
			_shape("AA", 0.55 * sin(clampf(u * 1.6, 0.0, 1.0) * PI))
		_blink(_blink_curve(i, blink_at))
		if not await _save_frame(name, i):
			return false
	_write_meta(name, {"frames": frames, "fps": 12, "loop": false, "yaw": FACE_YAW, "source": clip})
	return true


func _clip_cheer() -> bool:
	return await _oneshot("cheer", "celebrate", 0.7, 0.2, -10)


## Freundliches Nicken mit offener Hand nach vorn: „macht nichts, nochmal“.
func _clip_comfort() -> bool:
	var length: float = player.get_animation("agree_nod").length
	var frames := int(round(length * 12.0)) + 1
	for i in range(frames):
		var t := minf(float(i) / 12.0, length)
		var u := t / length
		var reach := _ease(u / 0.25) * (1.0 - _ease((u - 0.75) / 0.25))
		_clear_face()
		_set_yaw(FACE_YAW)
		_sample("agree_nod", t)
		_look(-0.22 * reach, 0.10 * sin(u * TAU * 2.0) * reach, 0.12 * reach)
		var chest := _body_point("Chest")
		_aim_arm(".R", chest + Vector3(-0.26, -0.28, 0.30), reach, 0.95, Vector3(-1.0, -0.5, -0.3))
		_alive(u * TAU, 0.8)
		_shape("Smile", 0.65)
		# Freundlich zusammengekniffene Augen beim Nicken.
		_blink(maxf(_blink_curve(i, 15), 0.3 * reach))
		if not await _save_frame("comfort", i):
			return false
	_write_meta("comfort", {"frames": frames, "fps": 12, "loop": false, "yaw": FACE_YAW})
	return true


## Winkt mit dem rechten (kameranahen) Arm, Hand deutlich neben dem Kopf.
func _clip_wave() -> bool:
	var frames := 24
	var length: float = player.get_animation("idle").length
	for i in range(frames):
		var u := float(i) / float(frames - 1)
		var raise := _ease(u / 0.2) * (1.0 - _ease((u - 0.8) / 0.2))
		var swing := sin((u - 0.2) / 0.6 * TAU * 2.0) if u > 0.2 and u < 0.8 else 0.0
		_clear_face()
		_set_yaw(FACE_YAW)
		_sample("idle", u * length * 0.5)
		_look(-0.25 * raise, -0.04 * raise, -0.10 * raise)
		var shoulder := _body_point("UpperArm.R")
		var hand := shoulder + Vector3(-0.30 + 0.08 * swing, 0.36, 0.14)
		_aim_arm(".R", hand, raise, 0.97, Vector3(-0.6, -1.0, 0.2))
		_alive(u * TAU * 2.0, 1.0)
		_shape("Smile", 0.75)
		_shape("AA", 0.35 * raise)
		_blink(_blink_curve(i, 19))
		if not await _save_frame("wave", i):
			return false
	_write_meta("wave", {"frames": frames, "fps": 12, "loop": false, "yaw": FACE_YAW})
	return true
