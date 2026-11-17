extends SceneTree
## Memory table look capture and draw-call measurement per quality tier.
## Run under xvfb with gl_compatibility like CI. Presentation fixture only:
## synthetic public state, no Dart authority, no wallet, no device FPS claim.
## llvmpipe numbers are not device performance; draw calls/objects compare.
## Output: LUMO_MEMORY_CAPTURE_DIR (PNG per tier/profile + metrics.json).
const TABLE := "res://scripts/games/memory/memory_table.gd"
const TOKEN := "cccccccccccccccccccccccccccccccc"
const OWNER := "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
const LEVELS := ["leicht","mittel","schwer","knifflig","profi"]
const COUNTS := [8,12,16,20,24]
const MOTIFS := ["panda","giraffe","lumo","hase","pinguin","stern","laterne","truhe","note","fahne","pilz","stein"]
const PROFILES := [
	{"name":"landscape","size":Vector2i(1920,1080),"density":2.0,"insets":Rect2()},
	{"name":"phone","size":Vector2i(1080,2400),"density":2.625,"insets":Rect2(0,136,0,63)},
]

class Transport extends RefCounted:
	var state: Dictionary = {}
	func getTableState() -> String: return JSON.stringify(state)
	func submitTableAction(_payload: String) -> bool: return true
	func returnToApp(_destination: String,_payload: String) -> bool: return false

var output := ""
var revision := 1
var metrics := {}
var failed := false


func _initialize() -> void:
	output = OS.get_environment("LUMO_MEMORY_CAPTURE_DIR")
	call_deferred("_run")


func _state(level: String,revealed: int,matched_pairs: int) -> Dictionary:
	var count: int = COUNTS[LEVELS.find(level)]
	var cards := []
	for index in range(count):
		var pair := index/2
		var matched := pair < matched_pairs
		var face := matched or (index >= matched_pairs*2 and index < matched_pairs*2+revealed)
		cards.append({"index":index,"faceUp":face,"matched":matched,
			"motif":MOTIFS[pair % MOTIFS.size()] if face else null})
	revision += 1
	return {"schema":1,"game":"memory","token":TOKEN,"owner":OWNER,"roundId":("%032x" % (1000+COUNTS.find(count))),
		"revision":revision,"recordRevision":revision,"ack":0,"rejected":0,"paused":false,"exit":false,
		"reduceMotion":false,"rewarded":false,"difficulty":level,"pack":"alle","count":count,
		"cards":cards,"turn":"kind","phase":"select","kindPairs":matched_pairs,"lumoPairs":0,
		"kindMoves":matched_pairs,"kindStreak":matched_pairs,"line":"Super! Finde das nächste Paar.",
		"remainingMs":0,"complete":false,"stars":0,"canFlip":true,"best":{},"error":null}


func _frames(count: int) -> void:
	for index in range(count):
		await process_frame
		await RenderingServer.frame_post_draw


func _stats() -> Dictionary:
	return {
		"draw_calls":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"objects":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		"primitives":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
	}


func _profile(profile: Dictionary) -> void:
	root.size = profile.size
	root.get_node("HostBridge")._options = {"displayDensity":profile.density,"tableToken":TOKEN,"scene":"memory"}
	var mobile = root.get_node("MobileRuntime")
	mobile._android_safe_area_enabled = true
	mobile._safe_area_reader = func(_callback): return false
	mobile._safe_area_observation = {"window_size":profile.size,"view_size":Vector2(profile.size),
		"decor_size":Vector2(profile.size),"render_rect":Rect2(Vector2.ZERO,Vector2(profile.size)),
		"system_insets":profile.insets,"insets":profile.insets}
	mobile.safe_area_changed.emit()


func _snap(name: String) -> void:
	await _frames(3)
	var stats := _stats()
	var image := root.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(output.path_join(name+".png")) != OK:
		failed = true
		push_error("[MemoryCapture] no framebuffer for "+name)
	metrics[name] = stats
	print("[MemoryCapture] %s %s" % [name,JSON.stringify(stats)])


func _run() -> void:
	if output.is_empty():
		push_error("LUMO_MEMORY_CAPTURE_DIR is required")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var performance: Node = root.get_node("PerformanceManager")
	var original: int = int(performance.get("current_profile"))
	for tier in [0,2]:
		performance.call("set_profile",tier,false)
		var tier_name: String = ["low","medium","high"][tier]
		for profile in PROFILES:
			_profile(profile)
			var transport := Transport.new()
			transport.state = _state("profi",0,0)
			var table: Node = load(TABLE).new()
			table._host = transport
			root.add_child(table)
			await _frames(8)
			table._layout()
			await _frames(4)
			await _snap("memory-%s-%s-start" % [tier_name,profile.name])
			var play := _state("profi",2,3)
			transport.state = play
			table.apply_state(play)
			await _frames(50)
			await _snap("memory-%s-%s-play" % [tier_name,profile.name])
			table.queue_free()
			await _frames(4)
	performance.call("set_profile",original,false)
	var file := FileAccess.open(output.path_join("metrics.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics,"\t"))
	file.close()
	print("MEMORY_CAPTURE_%s" % ("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)
