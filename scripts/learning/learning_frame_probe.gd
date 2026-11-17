extends RefCounted
## Read-only observations of the actual learning scene's process frames.
## This probe never changes rendering quality, animation or the frame limit.

const WINDOW_USEC := 5000000
const MAX_SAMPLES := 8192
var _last_usec: int = 0
var _start_usec: int = 0
var _window_index: int = 0
var _kind: String = ""
var _frames := PackedFloat64Array()
var _process := PackedFloat64Array()
var _draw_calls: float = 0.0
var _primitives: float = 0.0
var _render_objects: float = 0.0
var _objects: float = 0.0
var _nodes: float = 0.0
var _fox_samples: int = 0
var _playing_samples: int = 0
var _audible_samples: int = 0
var _effects_samples: int = 0
var _combined_samples: int = 0
var _ambience: Node3D
var _effect_time: float = -1.0


func reset() -> void:
	_last_usec = 0
	_start_usec = 0
	_frames.clear()
	_process.clear()
	_draw_calls = 0.0
	_primitives = 0.0
	_render_objects = 0.0
	_objects = 0.0
	_nodes = 0.0
	_fox_samples = 0
	_playing_samples = 0
	_audible_samples = 0
	_effects_samples = 0
	_combined_samples = 0
	_effect_time = -1.0


func sample(
	world: Node3D, kind: String, reduced_motion: bool, playing: bool, audible: bool
) -> void:
	var now := Time.get_ticks_usec()
	if kind != _kind:
		reset()
		_kind = kind
	var effects := _effects_active(world)
	if _last_usec == 0:
		_last_usec = now
		_start_usec = now
		return
	var interval_ms := float(now - _last_usec) / 1000.0
	_last_usec = now
	if interval_ms <= 0.0:
		return
	_frames.append(interval_ms)
	_process.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	_draw_calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	_primitives += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	_render_objects += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	_objects += Performance.get_monitor(Performance.OBJECT_COUNT)
	_nodes += Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var usable: bool = is_instance_valid(world.fox) and world.fox.is_usable()
	_fox_samples += int(usable)
	_playing_samples += int(playing)
	_audible_samples += int(playing and audible)
	_effects_samples += int(effects)
	_combined_samples += int(playing and audible and usable and effects)
	if now - _start_usec >= WINDOW_USEC:
		_emit_window(now, reduced_motion)
	elif _frames.size() >= MAX_SAMPLES:
		# A bounded diagnostic may discard an incomplete pathological window;
		# it must never fabricate intervals or grow without a limit.
		reset()


func _effects_active(world: Node3D) -> bool:
	if not is_instance_valid(_ambience):
		_ambience = world.get_node_or_null("LearningGardenAtelier/LumoDreamAmbience") as Node3D
	if not is_instance_valid(_ambience) or not _ambience.has_method("render_state"):
		_effect_time = -1.0
		return false
	var state: Dictionary = _ambience.render_state()
	var current: float = state.get("animation_time", 0.0)
	var advanced := _effect_time >= 0.0 and current > _effect_time
	_effect_time = current
	return (
		advanced
		and _ambience.is_visible_in_tree()
		and _ambience.is_processing()
		and not state.get("reduced_motion", true)
		and int(state.get("motes", 0)) + int(state.get("butterflies", 0)) > 0
	)


func _emit_window(now: int, reduced_motion: bool) -> void:
	var count := _frames.size()
	var slow := 0
	for interval in _frames:
		if interval > 16.7:
			slow += 1
	var frame_stats := statistics(_frames)
	frame_stats["over_16_7_count"] = slow
	frame_stats["over_16_7_fraction"] = float(slow) / count
	var process_stats := statistics(_process)
	_window_index += 1
	var packet := {
		"schema": "lumo.learning.perf",
		"version": 1,
		"kind": _kind,
		"platform": OS.get_name(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"display_driver": DisplayServer.get_name(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"reduced_motion": reduced_motion,
		"window_index": _window_index,
		"window_ms": float(now - _start_usec) / 1000.0,
		"sample_count": count,
		"frame_ms": frame_stats,
		"process_ms":
		{"mean": process_stats.mean, "p95": process_stats.p95, "max": process_stats.max},
		"render":
		{
			"draw_calls_mean": _draw_calls / count,
			"primitives_mean": _primitives / count,
			"render_objects_mean": _render_objects / count,
			"objects_mean": _objects / count,
			"nodes_mean": _nodes / count,
		},
		"fox_usable_samples": _fox_samples,
		"speech_playing_samples": _playing_samples,
		"speech_playing_audible_samples": _audible_samples,
		"effects_active_samples": _effects_samples,
		"speech_fox_effects_samples": _combined_samples,
	}
	print("LUMO_LEARNING_PERF " + JSON.stringify(packet))
	reset()
	_last_usec = now
	_start_usec = now


static func statistics(values: PackedFloat64Array) -> Dictionary:
	if values.is_empty():
		return {"mean": 0.0, "p50": 0.0, "p95": 0.0, "p99": 0.0, "max": 0.0}
	var ordered := values.duplicate()
	ordered.sort()
	var total := 0.0
	for value in ordered:
		total += value
	return {
		"mean": total / ordered.size(),
		"p50": ordered[maxi(0, ceili(ordered.size() * 0.50) - 1)],
		"p95": ordered[maxi(0, ceili(ordered.size() * 0.95) - 1)],
		"p99": ordered[maxi(0, ceili(ordered.size() * 0.99) - 1)],
		"max": ordered[-1],
	}
