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
## ULTRA: zusaetzliche Stufe ueber HIGH fuer sehr starke Geraete, nur manuell
## wählbar. Das Profil-Enum bleibt HIGH für Welten mit drei Detailstufen.
## Kart-Kulisse und Fahreffekte verwenden den separaten Ultra-Schalter.
var ultra_enabled: bool = false
# Opt-in Godot desktop sessions. Neither mode is persisted to a child's settings.
var desktop_presentation := ""



## Names of graphics adapters that compute the picture on the processor.
const SOFTWARE_ADAPTER_WORDS: Array[String] = ["swiftshader", "llvmpipe", "softpipe", "software rasterizer", "android emulator"]


static func is_software_adapter(adapter_name: String) -> bool:
	var lower := adapter_name.to_lower()
	for word in SOFTWARE_ADAPTER_WORDS:
		if lower.contains(word):
			return true
	return false


## True on a phone or tablet without hardware graphics (see is_software_adapter).
static func software_rendered_mobile() -> bool:
	if not (OS.has_feature("android") or OS.has_feature("ios")):
		return false
	return is_software_adapter(RenderingServer.get_video_adapter_name())


func _ready() -> void:
	platform = OS.get_name()
	EventBus.platform_detected.emit(platform)
	print("[Perf] platform_detected:%s" % platform)
	# Default-Profil je Plattform; persistierte Wahl gewinnt wenn vorhanden.
	var auto_choice: String = "high" if platform in ["Linux", "macOS", "Windows"] else "medium"
	var store: Node = get_node_or_null("/root/SettingsStore")
	if store != null:
		var stored: String = str(store.call("get_graphics_choice"))
		if stored.is_empty():
			stored = str(store.call("get_profile"))
		if stored in LumoQuality.GRAPHICS_CHOICES:
			auto_choice = stored
	# A phone whose pictures are computed by the processor (an emulator, or a
	# device without a usable graphics chip) starts with the light profile.
	if software_rendered_mobile():
		auto_choice = "low"
		print("[Perf] software_renderer_on_mobile: light profile")
	desktop_presentation = _desktop_mode(OS.get_cmdline_user_args())
	if not desktop_presentation.is_empty():
		auto_choice = "ultra"
	# SettingsStore loads before this autoload. Apply once before game scenes
	# can request their own profile, then apply it to each newly entered scene.
	get_tree().scene_changed.connect(_on_scene_changed)
	set_graphics_choice(auto_choice, false)


func _desktop_mode(arguments: PackedStringArray) -> String:
	if DisplayServer.get_name() == "headless" or OS.get_name() not in ["Linux", "Windows", "macOS"]:
		return ""
	if RenderingServer.get_current_rendering_method() != "forward_plus":
		return ""
	for argument in arguments:
		if argument in ["--lumo-render=desktop-ultra", "--lumo-render=cinematic"]:
			return argument.get_slice("=", 1)
	return ""


## Setzt das Quality-Profil und applied alle Schalter.
## persist=true: schreibt nach user://settings.cfg (default true)
func set_profile(profile: Profile, persist: bool = true) -> void:
	if persist:
		set_graphics_choice(_PROFILE_NAMES.get(profile, "medium"), true)
		return
	_apply_profile(profile)


func set_graphics_choice(name: String, persist: bool = true) -> void:
	if name not in LumoQuality.GRAPHICS_CHOICES:
		return
	var index: int = LumoQuality.TIERS.find(LumoQuality.base_tier(name))
	ultra_enabled = name == "ultra"
	_apply_profile(index as Profile)
	if persist:
		var store: Node = get_node_or_null("/root/SettingsStore")
		if store != null:
			store.call("set_graphics_choice", name)


func get_graphics_choice() -> String:
	return "ultra" if is_ultra() else get_profile_name()


func _apply_profile(profile: Profile) -> void:
	current_profile = profile
	var name: String = _PROFILE_NAMES.get(profile, "medium")
	print("[Perf] quality_profile:%s" % name)
	_apply_environment(profile)
	_apply_viewport(profile)
	EventBus.quality_profile_changed.emit(name)


## Schaltet die ULTRA-Kulisse (volle Dichte, 8 Lichter, weite Sicht) an/aus.
## Wirkt nur zusammen mit HIGH; set_ultra(true) hebt das Profil daher auf HIGH.
func set_ultra(enabled: bool) -> void:
	ultra_enabled = enabled
	if enabled and current_profile != Profile.HIGH:
		set_profile(Profile.HIGH, false)
	print("[Perf] ultra_scenery:%s" % ("on" if is_ultra() else "off"))


func is_ultra() -> bool:
	return ultra_enabled and current_profile == Profile.HIGH


func get_profile_name() -> String:
	return _PROFILE_NAMES.get(current_profile, "medium")


func _on_scene_changed() -> void:
	# The previous WorldEnvironment was freed with the old scene.
	_apply_environment(current_profile)


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
	if not desktop_presentation.is_empty():
		# SSR complements authored probes. Indirect light is reserved for capture.
		env.ssr_enabled = profile == Profile.HIGH
		env.ssil_enabled = profile == Profile.HIGH and desktop_presentation == "cinematic"
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
			# Match the renderer/platform gate used by KartEnvironmentPolish.
			var supports_advanced_effects := (
				RenderingServer.get_current_rendering_method() == "forward_plus"
				and not OS.has_feature("mobile")
			)
			env.volumetric_fog_enabled = supports_advanced_effects
			env.ssao_enabled = supports_advanced_effects


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
			vp.use_taa = RenderingServer.get_current_rendering_method() == "forward_plus"


## Empfohlene Anzahl Sterne im MultiMesh-Sternenfeld je Profil.
func get_star_count() -> int:
	match current_profile:
		Profile.LOW:
			return 12
		Profile.MEDIUM:
			return 40
		Profile.HIGH:
			return 80
	return 40


## Empfohlene Anzahl Billboard-Decorations (Kristalle/Buecher) je Profil.
func get_billboard_count() -> int:
	match current_profile:
		Profile.LOW:
			return 0
		Profile.MEDIUM:
			return 3
		Profile.HIGH:
			return 6
	return 3


## Portal-Emission-Multiplier je Profil (Glow regelbar).
func get_portal_emission_multiplier() -> float:
	match current_profile:
		Profile.LOW:
			return 0.5
		Profile.MEDIUM:
			return 1.0
		Profile.HIGH:
			return 1.4
	return 1.0


## Rekursive Tree-Suche fuer WorldEnvironment - meistens an der Wurzel.
func _find_world_environment(node: Node) -> WorldEnvironment:
	if node is WorldEnvironment:
		return node
	for child in node.get_children():
		var found: WorldEnvironment = _find_world_environment(child)
		if found != null:
			return found
	return null
