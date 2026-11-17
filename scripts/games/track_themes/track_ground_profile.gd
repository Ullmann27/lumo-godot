extends RefCounted
## Shared expansion surface height; only ordinary ground themes anchor details here.

const GROUNDED_DETAIL_TRACKS: Array[String] = [
	"crystal_canyon",
	"jungle_temple",
	"winter_sprint",
	"desert_drift",
	"learning_lab",
]


static func surface_height(track_id: String) -> float:
	return -12.0 if track_id in ["candy_cloud", "galaxy_ringway"] else -2.0


static func supports_grounded_details(track_id: String) -> bool:
	return track_id in GROUNDED_DETAIL_TRACKS
