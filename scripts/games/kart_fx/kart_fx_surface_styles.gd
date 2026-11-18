extends RefCounted
## What a tyre leaves behind on each road surface (LumoKartRoadSurfaces styles).
##   mark      colour + opacity of brake/drift marks (mark_kind: 0 rubber, 1 glow)
##   smoke     tyre smoke / dust colour (alpha = density)
##   debris    small bits thrown up (pebbles, leaves, snow clumps) and their kind
##   trail     loose surfaces throw a plume behind the kart even when cruising
##   embers    lava: glowing bits rise from the tyres
##   loop      rolling sound under the tyres ("" = none)

const SURFACES = preload("res://scripts/games/kart_road_surfaces.gd")

const ASPHALT := {
	"name": "asphalt", "mark": Color(0.04, 0.04, 0.05, 0.82), "mark_kind": 0,
	"smoke": Color(0.86, 0.87, 0.9, 0.55), "debris": Color(0.12, 0.12, 0.13, 1.0), "debris_kind": 1,
	"debris_rate": 0.0, "trail": 0.0, "embers": false, "loop": "", "dust_scale": 0.8,
}

const STYLES := {
	SURFACES.ASPHALT: ASPHALT,
	SURFACES.FOREST_PATH: {
		"name": "forest", "mark": Color(0.2, 0.12, 0.06, 0.6), "mark_kind": 0,
		"smoke": Color(0.62, 0.48, 0.32, 0.5), "debris": Color(0.42, 0.62, 0.2, 1.0), "debris_kind": 2,
		"debris_rate": 1.0, "trail": 0.45, "embers": false, "loop": "gravel", "dust_scale": 1.1,
	},
	SURFACES.STONE_SLABS: {
		"name": "stone", "mark": Color(0.16, 0.15, 0.17, 0.5), "mark_kind": 0,
		"smoke": Color(0.82, 0.8, 0.76, 0.45), "debris": Color(0.55, 0.53, 0.5, 1.0), "debris_kind": 1,
		"debris_rate": 0.5, "trail": 0.1, "embers": false, "loop": "", "dust_scale": 0.9,
	},
	SURFACES.SAND: {
		"name": "sand", "mark": Color(0.48, 0.32, 0.15, 0.75), "mark_kind": 0,
		"smoke": Color(0.96, 0.84, 0.62, 0.72), "debris": Color(0.78, 0.6, 0.36, 1.0), "debris_kind": 1,
		"debris_rate": 1.2, "trail": 1.0, "embers": false, "loop": "gravel", "dust_scale": 1.6,
	},
	SURFACES.SNOW_ICE: {
		"name": "snow", "mark": Color(0.55, 0.68, 0.86, 0.6), "mark_kind": 0,
		"smoke": Color(0.97, 0.99, 1.0, 0.7), "debris": Color(0.95, 0.98, 1.0, 1.0), "debris_kind": 1,
		"debris_rate": 1.2, "trail": 0.85, "embers": false, "loop": "snow", "dust_scale": 1.4,
	},
	SURFACES.BASALT_LAVA: {
		"name": "lava", "mark": Color(0.04, 0.03, 0.03, 0.62), "mark_kind": 0,
		"smoke": Color(0.38, 0.33, 0.33, 0.55), "debris": Color(0.16, 0.12, 0.12, 1.0), "debris_kind": 1,
		"debris_rate": 0.6, "trail": 0.25, "embers": true, "loop": "", "dust_scale": 1.0,
	},
	SURFACES.STAR_GLASS: {
		"name": "starglass", "mark": Color(0.5, 0.82, 1.0, 0.55), "mark_kind": 1,
		"smoke": Color(0.7, 0.82, 1.0, 0.4), "debris": Color(0.8, 0.9, 1.0, 1.0), "debris_kind": 1,
		"debris_rate": 0.2, "trail": 0.15, "embers": false, "loop": "", "dust_scale": 0.9,
	},
	SURFACES.LAB_TILES: {
		"name": "tiles", "mark": Color(0.18, 0.2, 0.24, 0.45), "mark_kind": 0,
		"smoke": Color(0.9, 0.93, 0.97, 0.45), "debris": Color(0.3, 0.32, 0.36, 1.0), "debris_kind": 1,
		"debris_rate": 0.0, "trail": 0.0, "embers": false, "loop": "", "dust_scale": 0.8,
	},
}


static func for_track(track_id: String) -> Dictionary:
	var entry: Dictionary = SURFACES.surface(track_id)
	if entry.is_empty():
		return ASPHALT
	return STYLES.get(int(entry.style), ASPHALT)
