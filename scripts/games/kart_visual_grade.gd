class_name LumoKartVisualGrade
extends RefCounted
## Shared visual target derived from Heinz' 1280x720 racing references.
## Original Lumo art direction only: no third-party names, logos or geometry.

const CAMERA_DISTANCE_NEAR: float = 4.35
const CAMERA_DISTANCE_FAST: float = 4.8
const CAMERA_HEIGHT: float = 2.6
const CAMERA_LOOK_AHEAD: float = 7.6
const CAMERA_TARGET_HEIGHT: float = 1.12
const CAMERA_LERP: float = 7.4
const CAMERA_ROLL_MAX: float = 0.052
const BASE_FOV: float = 55.0
const SPEED_FOV: float = 60.0
const BOOST_FOV: float = 68.0
const FOV_LERP: float = 4.8


static func camera_distance(speed_ratio: float) -> float:
	return lerpf(CAMERA_DISTANCE_NEAR, CAMERA_DISTANCE_FAST, clampf(speed_ratio, 0.0, 1.0))


static func camera_fov(speed_ratio: float, boosting: bool, reduce_motion: bool) -> float:
	if reduce_motion:
		return BASE_FOV
	if boosting:
		return BOOST_FOV
	return lerpf(BASE_FOV, SPEED_FOV, clampf(speed_ratio, 0.0, 1.0))


static func environment_profile(track_id: String, low_detail: bool) -> Dictionary:
	var profile := {
		"glow": not low_detail,
		"glow_intensity": 0.72,
		"glow_bloom": 0.055,
		"glow_threshold": 0.88,
		"contrast": 1.08,
		"saturation": 1.08,
		"brightness": 1.0,
		"exposure": 1.00,
		"road_grade": 0.92 if not low_detail else 0.35,
		"road_gloss": 0.88 if not low_detail else 0.45,
		"edge_energy": 0.44 if not low_detail else 0.16,
	}
	match track_id:
		"sonnenhafen":
			profile.contrast = 1.08
			profile.saturation = 1.12
			profile.exposure = 1.03
			profile.glow_intensity = 0.62
		"zauberwald":
			profile.contrast = 1.10
			profile.saturation = 1.13
			profile.exposure = 0.97
			profile.glow_intensity = 0.76
		"bergwelt":
			profile.contrast = 1.12
			profile.saturation = 1.12
			profile.exposure = 1.05
			profile.glow_intensity = 0.92
			profile.glow_bloom = 0.075
			profile.edge_energy = 0.58 if not low_detail else 0.20
		"holo_city":
			profile.contrast = 1.14
			profile.saturation = 1.16
			profile.exposure = 0.96
			profile.glow_intensity = 1.02
			profile.glow_bloom = 0.085
			profile.edge_energy = 0.72 if not low_detail else 0.24
	return profile
