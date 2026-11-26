extends RefCounted
## Was jede Strecke an Kleinigkeiten bekommt. Ein Cluster ist eine Liste aus
## [Kleinteil, Versatz längs (m), Versatz quer (m), Platzbedarf-Radius (m)].
## Bodenarten: "terrain" = Geländehöhe der Welt, "road" = auf Fahrbahnhöhe
## neben der Strecke (Bankett/Plattform), "plane" = feste Grundebene.

const PIT: Array = [["toolbox", 0.0, 0.0, 0.6], ["tire_stack", 2.0, 0.3, 0.5], ["jerrycan", -1.2, 0.4, 0.3]]
const TIRES: Array = [["tire_stack", 0.0, 0.0, 0.5], ["tire_stack", 1.0, 0.2, 0.5], ["tire_stack", 0.5, 1.0, 0.5], ["pylon", -2.0, -0.6, 0.3], ["pylon", 3.0, -0.6, 0.3]]
const HAY: Array = [["hay_bale", 0.0, 0.0, 1.0], ["hay_bale", 0.0, 1.0, 1.0], ["pylon", 2.4, -0.5, 0.3]]
const STREET: Array = [["bench", 0.0, 0.4, 0.9], ["bin", 1.5, 0.3, 0.35], ["planter", -2.1, 0.5, 0.8], ["bicycle", 3.0, 0.9, 0.7]]
const CORNER: Array = [["mailbox", 0.0, 0.0, 0.3], ["hydrant", 1.4, -0.3, 0.3], ["bin", -1.2, 0.2, 0.35]]
const HARBOUR_QUAY: Array = [["bollard", 0.0, 0.0, 0.3], ["bollard", 3.0, 0.0, 0.3], ["lifebuoy_stand", 1.5, 0.6, 0.5], ["crate_stack", -2.5, 1.5, 0.9]]
const HARBOUR_BOXES: Array = [["container", 0.0, 3.5, 3.2], ["crate", 4.0, 0.8, 0.5], ["jerrycan", 4.6, 0.2, 0.3]]
const FOREST: Array = [["mushroom_cluster", 0.0, 0.0, 0.7], ["fern", 1.4, 0.7, 0.8], ["stump", -1.6, 1.0, 0.5], ["fern", -0.5, 1.8, 0.8]]
const GLADE: Array = [["glow_mushrooms", 0.0, 0.0, 0.6], ["fern", 1.2, 0.8, 0.8], ["bush_round", -1.5, 1.4, 0.9]]
const WINTER: Array = [["snowman", 0.0, 1.0, 0.6], ["sled", 1.8, 0.3, 0.8], ["ski_rack", -2.2, 1.2, 0.9]]
const CITY: Array = [["holo_kiosk", 0.0, 1.0, 1.0], ["bin", 1.6, 0.2, 0.35], ["bench", -2.0, 0.5, 0.9]]
const NEON: Array = [["neon_arrow", 0.0, 0.0, 0.8], ["pylon", 1.4, -0.4, 0.3], ["pylon", -1.4, -0.4, 0.3]]
const DESERT: Array = [["cactus", 0.0, 1.0, 0.8], ["tumbleweed", 2.0, 0.0, 0.5], ["hay_bale", -2.4, 0.6, 1.0]]
const CANYON: Array = [["mine_cart", 0.0, 0.5, 0.9], ["crate_stack", 2.4, 0.8, 0.9], ["pylon", -1.6, -0.4, 0.3]]
const CANDY: Array = [["lollipop", 0.0, 0.8, 0.6], ["lollipop", 1.6, 1.6, 0.6], ["bush_round", -1.6, 0.6, 0.9]]
const VOLCANO: Array = [["lava_warning", 0.0, 0.0, 0.5], ["tire_stack", 1.5, 0.4, 0.5], ["crate", -1.4, 0.4, 0.5]]
const GALAXY: Array = [["satellite_dish", 0.0, 1.0, 0.9], ["drone", 1.6, 0.0, 0.5], ["pylon", -1.4, -0.4, 0.3]]
const LAB: Array = [["abacus", 0.0, 0.8, 1.0], ["crate", 2.0, 0.4, 0.5], ["planter", -2.2, 0.6, 0.8]]
const JUNGLE: Array = [["fern", 0.0, 0.0, 0.8], ["mushroom_cluster", 1.4, 0.6, 0.7], ["stump", -1.2, 0.8, 0.5], ["bush_round", 0.3, 1.8, 0.9]]

const THEMES: Dictionary = {
	# Signatur-Strecke Vulkanexpress (Team B1): Basaltbankett, keine Pfützen, kein Luftschiff.
	"vulkanexpress_3100": {
		"ground": "road", "road_wear": ["crack", "tar", "patch"], "edge": "sand",
		"edge_tint": Color(0.32, 0.28, 0.28, 0.9), "clusters": [VOLCANO, PIT, TIRES],
		"brands": ["lavalolli", "raketenroller", "sternenbrause"], "lantern": "lamp_post_small",
		"airship": false, "flock": "gull_flock", "flock_height": 16.0,
		"string_colors": [Color("ffb04a"), Color("ff6a2a"), Color("ffe38a")],
	},
	# Signatur-Strecke Wolkensturm: Skyway-Bankett, Neon, Drohnen, Luftschiff.
	"wolkensturm_3300": {
		"ground": "road", "road_wear": ["patch", "manhole"], "clusters": [CITY, NEON, TIRES],
		"brands": ["wolkenwerk", "funkelfunk", "pixelpost"], "flock": "drone", "flock_scale": 1.6,
		"lantern": "neon_arrow", "airship_color": Color("5ff0ff"), "airship_height": 40.0,
		"string_colors": [Color("5ff0ff"), Color("ff4fd8"), Color("fff3b0")],
	},
	# Signatur-Strecke Kristallflut: Hafen und Küste ohne Pfützen auf dem Steinbelag.
	"kristallflut_2800": {
		"ground": "road", "road_wear": ["crack", "patch"], "edge": "sand",
		"edge_tint": Color(1, 1, 1, 0.8), "clusters": [HARBOUR_QUAY, HARBOUR_BOXES, TIRES],
		"brands": ["milos_muscheln", "sternenbrause", "kometen_kakao"], "flock": "gull_flock",
		"flock_height": 12.0, "lantern": "buoy", "airship_color": Color("3fd8d0"),
	},
	"sonnenhafen": {
		"ground": "terrain", "min_ground": -1.5,
		"road_wear": ["patch", "manhole", "puddle", "oil", "tar", "crack", "patch", "manhole"],
		"edge": "sand", "edge_tint": Color(1, 1, 1, 0.85),
		"clusters": [HARBOUR_QUAY, HARBOUR_BOXES, STREET, CORNER, TIRES, HAY, PIT],
		"brands": ["milos_muscheln", "sternenbrause", "fuchsflitzer", "kometen_kakao", "wolkenwerk", "nova_nudeln"],
		"flock": "gull_flock", "flock_height": 11.0,
		"lantern": "buoy", "airship_color": Color("ff8a3d"),
		"sky_tint": Color(0.62, 0.8, 0.98),
	},
	"zauberwald": {
		"ground": "terrain",
		"road_wear": ["puddle", "crack", "patch", "puddle", "tar"],
		"edge": "leaves", "edge_tint": Color(1, 1, 1, 0.95),
		"clusters": [FOREST, GLADE, HAY, TIRES, FOREST],
		# Dense woodland leaves short clearings. Check both safe shoulders for
		# spectators and give the roadside kit more chances to use those gaps.
		"cluster_spacing": 0.72, "search_both_shoulders": true,
		"facade_bottom": ["moss"],
		"brands": ["gluehwurm", "mondmilch", "fuchsflitzer", "blitzbeere"],
		"flock": "gull_flock", "flock_tint": Color(1.0, 0.75, 0.9), "flock_scale": 0.5, "flock_height": 6.0,
		"lantern": "firefly_lantern", "airship": false,
		"string_colors": [Color("c8ffb0"), Color("ffe38a"), Color("8fe9ff")],
		"sky_tint": Color(0.5, 0.75, 0.6),
	},
	"bergwelt": {
		"ground": "road",
		"road_wear": ["crack", "patch", "tar"],
		"clusters": [TIRES, HAY, STREET],
		"brands": ["wolkenwerk", "sternenbrause", "funkelfunk"],
		"flock": "gull_flock", "flock_height": 14.0,
		"lantern": "lamp_post_small", "airship_height": 30.0,
	},
	"holo_city": {
		"ground": "road",
		"road_wear": ["manhole", "patch", "oil", "puddle", "tar", "manhole"],
		"clusters": [CITY, NEON, CORNER, TIRES],
		"facade_top": ["streak", "grime", "crack"], "facade_bottom": ["grime"],
		"brands": ["pixelpost", "funkelfunk", "raketenroller", "mondmilch", "nova_nudeln"],
		"flock": "drone", "flock_height": 12.0, "flock_scale": 2.0,
		"lantern": "neon_arrow", "airship_color": Color("ff3b8a"),
		"road_tint": Color(0.6, 0.7, 1.6), "pad_color": Color("2b2f46"), "pad_trim": Color("ff3b8a"), "plane_y": -1.2,
		"railside": ["pylon", "neon_arrow"],
		"string_colors": [Color("ff3b8a"), Color("6fd3ff"), Color("b06cff")],
		"sky_tint": Color(0.55, 0.45, 0.95),
	},
	"crystal_canyon": {
		"ground": "road", "road_wear": ["crack", "patch", "oil", "tar"], "edge": "sand", "edge_tint": Color(0.85, 0.8, 1.0, 0.8),
		"clusters": [CANYON, TIRES, PIT], "brands": ["drehwurm", "sternenbrause", "fuchsflitzer"],
		"lantern": "lamp_post_small",
	},
	"jungle_temple": {
		"ground": "road", "road_wear": ["puddle", "crack", "patch"], "edge": "leaves",
		"clusters": [JUNGLE, HAY, TIRES], "brands": ["blitzbeere", "gluehwurm", "nova_nudeln"],
		"flock": "gull_flock", "flock_tint": Color(0.6, 1.0, 0.6), "flock_scale": 0.7,
		"lantern": "firefly_lantern", "airship": false,
	},
	"candy_cloud": {
		"ground": "road", "road_wear": ["patch", "crack"],
		"clusters": [CANDY, TIRES, HAY], "brands": ["kometen_kakao", "blitzbeere", "drehwurm", "lumo_kart"],
		"flock": "gull_flock", "flock_tint": Color(1.0, 0.7, 0.9), "lantern": "lamp_post_small",
		"airship_color": Color("ff6f91"), "pennant_colors": [Color("ff6f91"), Color("fff1a8"), Color("b06cff")],
	},
	"volcano_night": {
		"ground": "road", "road_wear": ["crack", "oil", "patch", "tar"], "edge": "sand", "edge_tint": Color(0.45, 0.4, 0.4, 0.9),
		"clusters": [VOLCANO, TIRES, PIT], "brands": ["lavalolli", "mondmilch", "raketenroller"],
		"lantern": "lamp_post_small", "airship": false,
		"string_colors": [Color("ffb04a"), Color("ff6a2a"), Color("ffe38a")],
	},
	"winter_sprint": {
		"ground": "road", "road_wear": ["crack", "patch", "puddle"], "edge": "snow", "edge_tint": Color(1, 1, 1, 0.95),
		"clusters": [WINTER, TIRES, HAY], "brands": ["schneeflocke", "kometen_kakao", "mondmilch"],
		"lantern": "lamp_post_small", "airship_color": Color("3fb7e8"),
		"facade_bottom": ["grime"],
	},
	"galaxy_ringway": {
		"ground": "road", "road_wear": ["crack", "patch"],
		"clusters": [GALAXY, NEON, TIRES], "brands": ["pixelpost", "funkelfunk", "sternenbrause"],
		"flock": "drone", "flock_scale": 2.0, "lantern": "neon_arrow", "airship": false,
		"string_colors": [Color("9fe6ff"), Color("b06cff"), Color("ffd98a")],
	},
	"desert_drift": {
		"ground": "road", "road_wear": ["crack", "patch", "tar", "oil"], "edge": "sand",
		"clusters": [DESERT, TIRES, HAY], "brands": ["sandschaufel", "blitzbeere", "raketenroller"],
		"flock": "gull_flock", "flock_tint": Color(0.55, 0.45, 0.4), "lantern": "lamp_post_small",
	},
	"learning_lab": {
		"ground": "road", "road_wear": ["patch", "crack", "manhole"],
		"clusters": [LAB, TIRES, STREET], "brands": ["zahlenzauber", "pixelpost", "funkelfunk"],
		"flock": "drone", "flock_scale": 1.6, "lantern": "lamp_post_small", "airship_color": Color("7ed957"),
	},
	"jungle_emerald_3600": {
		"ground": "road", "road_wear": ["puddle", "crack", "patch", "puddle"], "edge": "leaves",
		"clusters": [JUNGLE, HAY, TIRES, JUNGLE], "brands": ["blitzbeere", "gluehwurm", "milos_muscheln"],
		"flock": "gull_flock", "flock_tint": Color(0.7, 1.0, 0.6), "flock_scale": 0.7,
		"lantern": "firefly_lantern", "airship": false,
		"sky_tint": Color(0.55, 0.75, 0.6),
	},
}


static func theme(track_id: String) -> Dictionary:
	return THEMES.get(track_id, THEMES.sonnenhafen)
