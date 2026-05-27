## PerformanceManager (Autoload als 'PerformanceManager').
##
## Erkennt Plattform und setzt ein Quality-Profil das die teuren Effekte
## (Glow / Volumetric Fog / SSAO / Schatten / MSAA / TAA) gemeinsam
## hoch- oder runterschaltet. Andere Knoten koennen jederzeit
## `PerformanceManager.set_profile(Profile.LOW)` rufen.
##
## Schaltbare Schalter wirken auf:
##   - das aktive WorldEnvironment.environment (env-Felder direkt mutieren)
##   - viewport.use_taa / msaa_3d
##   - directional_shadow_size (via ProjectSettings override)
extends Node

enum Profile { LOW, MEDIUM, HIGH }

const _PROFILE_NAMES: Dictionary = {
	Profile.LOW: "low",
	Profile.MEDIUM: "medium",
	Profile.HIGH: "high",
}

var current_profile: Profile = Profile.MEDIUM
var platform: String = ""


func _ready() -> void:
	platform = OS.get_name()
	EventBus.platform_detected.emit(platform)
	print("[Perf] platform_detected:%s" % platform)
	# Default-Profil je Plattform:
	#   Android / Web -> MEDIUM (konservativ)
	#   Linux / macOS / Windows -> HIGH (Desktop)
	var auto_profile: Profile = Profile.MEDIUM
	match platform:
		"Linux", "macOS", "Windows":
			auto_profile = Profile.HIGH
		"Android", "iOS", "Web":
			auto_profile = Profile.MEDIUM
		_:
			auto_profile = Profile.MEDIUM
	# Warte einen Frame damit der erste WorldEnvironment im Tree ist.
	await get_tree().process_frame
	set_profile(auto_profile)


## Setzt das Quality-Profil und applied alle Schalter.
func set_profile(profile: Profile) -> void:
	current_profile = profile
	var name: String = _PROFILE_NAMES.get(profile, "medium")
	print("[Perf] quality_profile:%s" % name)
	_apply_environment(profile)
	_apply_viewport(profile)
	EventBus.quality_profile_changed.emit(name)


func get_profile_name() -> String:
	return _PROFILE_NAMES.get(current_profile, "medium")


## Sucht das erste WorldEnvironment im aktuellen Tree und mutiert dessen
## Environment-Resource. Falls keins vorhanden: stiller no-op.
func _apply_environment(profile: Profile) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var root: Node = tree.current_scene
	if root == null:
		return
	var env_node: WorldEnvironment = _find_world_environment(root)
	if env_node == null or env_node.environment == null:
		return
	var env: Environment = env_node.environment
	match profile:
		Profile.LOW:
			env.glow_enabled = false
			env.fog_enabled = false
			env.volumetric_fog_enabled = false
			env.ssao_enabled = false
			env.ssil_enabled = false
		Profile.MEDIUM:
			env.glow_enabled = true
			env.fog_enabled = true
			env.volumetric_fog_enabled = false
			env.ssao_enabled = false
		Profile.HIGH:
			env.glow_enabled = true
			env.fog_enabled = true
			env.volumetric_fog_enabled = true
			env.ssao_enabled = true


func _apply_viewport(profile: Profile) -> void:
	var vp: Viewport = get_viewport()
	if vp == null:
		return
	match profile:
		Profile.LOW:
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.use_taa = false
		Profile.MEDIUM:
			vp.msaa_3d = Viewport.MSAA_2X
			vp.use_taa = false
		Profile.HIGH:
			vp.msaa_3d = Viewport.MSAA_4X
			vp.use_taa = true


## Rekursive Tree-Suche fuer WorldEnvironment - meistens an der Wurzel.
func _find_world_environment(node: Node) -> WorldEnvironment:
	if node is WorldEnvironment:
		return node
	for child in node.get_children():
		var found: WorldEnvironment = _find_world_environment(child)
		if found != null:
			return found
	return null
