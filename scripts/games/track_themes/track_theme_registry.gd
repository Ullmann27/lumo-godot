extends RefCounted
## World identity is explicit. Sonnenhafen keeps its existing authored detail.
const NATURE = preload("res://scripts/games/track_themes/nature_track_details.gd")
const SKY_FANTASY = preload("res://scripts/games/track_themes/sky_fantasy_track_details.gd")
const TECHNOLOGY = preload("res://scripts/games/track_themes/technology_track_details.gd")

const IDS: Array[String] = [
	"zauberwald",
	"bergwelt",
	"holo_city",
	"crystal_canyon",
	"jungle_temple",
	"candy_cloud",
	"volcano_night",
	"winter_sprint",
	"galaxy_ringway",
	"desert_drift",
	"learning_lab"
]


static func supports(track_id: String) -> bool:
	return track_id in IDS


static func build(world, at: Vector3, basis: Basis, large: bool, marker: bool) -> bool:
	match world.track_id:
		"zauberwald", "jungle_temple", "desert_drift":
			return NATURE.build(world, at, basis, large, marker)
		"bergwelt", "crystal_canyon", "candy_cloud", "winter_sprint":
			return SKY_FANTASY.build(world, at, basis, large, marker)
		"holo_city", "galaxy_ringway", "learning_lab", "volcano_night":
			return TECHNOLOGY.build(world, at, basis, large, marker)
		_:
			return false
