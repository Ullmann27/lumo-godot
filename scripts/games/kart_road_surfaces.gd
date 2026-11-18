class_name LumoKartRoadSurfaces
extends RefCounted
## One road surface per course, so every track is recognisable by its ground
## alone. Styles are implemented in assets/shaders/kart_asphalt.gdshader.
## Courses without an entry keep the classic asphalt (Holo-City); Candy and
## Dschungelherz bring their own road shaders.

const ASPHALT: int = 0
const FOREST_PATH: int = 1
const STONE_SLABS: int = 2
const SAND: int = 3
const SNOW_ICE: int = 4
const BASALT_LAVA: int = 5
const STAR_GLASS: int = 6
const LAB_TILES: int = 7

## tint: main colour, detail: second colour of the style, marking: lane paint
## that stays readable on this ground, matte: asphalt only.
const SURFACES: Dictionary = {
	"sonnenhafen": {"style": ASPHALT, "tint": Color("4d525b"), "detail": Color("6b6f76"),
		"marking": Color("f5f7e9"), "matte": 0.6},
	"zauberwald": {"style": FOREST_PATH, "tint": Color("7a5a3c"), "detail": Color("3f7d3e"),
		"marking": Color("f3e7b8"), "matte": 1.0},
	"jungle_temple": {"style": STONE_SLABS, "tint": Color("9a9680"), "detail": Color("5f9a55"),
		"marking": Color("fff2c4"), "matte": 1.0},
	"bergwelt": {"style": STONE_SLABS, "tint": Color("7d84bd"), "detail": Color("c9d4ff"),
		"marking": Color("f4f6ff"), "matte": 1.0},
	"crystal_canyon": {"style": STONE_SLABS, "tint": Color("7566b3"), "detail": Color("c3b2ff"),
		"marking": Color("f4efff"), "matte": 1.0},
	"desert_drift": {"style": SAND, "tint": Color("d2a770"), "detail": Color("96703f"),
		"marking": Color("fff6dd"), "matte": 1.0},
	"winter_sprint": {"style": SNOW_ICE, "tint": Color("e3edf7"), "detail": Color("86bfee"),
		"marking": Color("2f5fae"), "matte": 1.0},
	"volcano_night": {"style": BASALT_LAVA, "tint": Color("46404a"), "detail": Color("ff7a1f"),
		"marking": Color("ffd9a0"), "matte": 1.0},
	"galaxy_ringway": {"style": STAR_GLASS, "tint": Color("2c2060"), "detail": Color("a6d4ff"),
		"marking": Color("dff1ff"), "matte": 1.0},
	"learning_lab": {"style": LAB_TILES, "tint": Color("cbd6e2"), "detail": Color("23b6e6"),
		"marking": Color("27407a"), "matte": 1.0},
}


static func has_surface(track_id: String) -> bool:
	return SURFACES.has(track_id)


static func surface(track_id: String) -> Dictionary:
	return SURFACES.get(track_id, {})


## Lane paint colour for [param track_id]; [param fallback] on classic asphalt.
static func marking(track_id: String, fallback: Color) -> Color:
	return surface(track_id).get("marking", fallback)


## Colour other road-coloured pieces (loops, ramps) should match.
static func tint(track_id: String, fallback: Color) -> Color:
	return surface(track_id).get("tint", fallback)


static func apply(material: ShaderMaterial, track_id: String) -> void:
	var entry: Dictionary = surface(track_id)
	if entry.is_empty():
		return
	material.set_shader_parameter("road_tint", entry.tint)
	material.set_shader_parameter("detail_tint", entry.detail)
	material.set_shader_parameter("surface_style", int(entry.style))
	material.set_shader_parameter("surface_matte", float(entry.matte))
