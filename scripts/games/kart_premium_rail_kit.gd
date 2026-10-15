extends RefCounted
## Reusable, curve-following, premium rail visual kit.
## This script affects *only* geometry/lighting, never wall positions, kart
## physics, open-edge action sections, checkpoint positions or AI steering.
## Every section uses the already-sampled world.position_at/frame transforms,
## then the existing 48-metre spatial MultiMesh batching and visibility LOD.

const ICE_CYAN := Color("5ee8ff")
const SUNSET_GOLD := Color("ffda77")
const DEEP_BLUE := Color("0b294d")
const TITANIUM := Color("9ac1db")


static func build_segment(world, index: int, distance: float, step: float, side: float, basis: Basis) -> void:
	var at: Vector3 = world.position_at(distance, side * world.RAIL_LATERAL)
	var upper := TITANIUM
	var lower := DEEP_BLUE
	var accent := ICE_CYAN
	match world.track_id:
		"sonnenhafen":
			upper = Color("e8f4ff") if index % 6 < 3 else Color("268ec7")
			lower = Color("16355b")
		"zauberwald":
			upper = Color("d9f2e7")
			lower = Color("366b78")
			accent = Color("93ffc4")
		"bergwelt":
			upper = Color("f1f4ff") if index % 6 >= 3 else Color("3573ef")
			lower = Color("1d3a9a")
			accent = SUNSET_GOLD
		"volcano_night":
			upper = Color("b6a0ae")
			lower = Color("493d55")
			accent = Color("ff9346")
		"holo_city":
			upper = Color("90edff")
			lower = Color("224f7c")
		"candy_cloud":
			upper = Color("fff2fb")
			lower = Color("b078ad")
			accent = Color("e99cfa")
		"desert_drift":
			upper = Color("f7d6b1")
			lower = Color("704d49")
			accent = Color("77f1e7")

	# Explicitly bevelled eight-edge beam; joins overlap by 8 cm so adjacent
	# samples follow the existing smooth course without visually open seams.
	var span: float = step + 0.08
	world._prop("premium_rail", at + basis.y * 0.97, Vector3(0.22, 0.22, span), upper, basis)
	world._prop("premium_rail", at + basis.y * 0.55, Vector3(0.14, 0.15, span), lower, basis)

	# Inward face is the one most visible to the kart's chase camera.
	# Keep glowing accents visually thin and not electrically distracting.
	if not world.low_detail:
		var inward: Vector3 = -basis.x * side
		world._prop("box", at + basis.y * 1.055 + inward * 0.117,
			Vector3(0.025, 0.028, span), accent, basis, true)
		if index % 4 == 0:
			world._prop("box", at + basis.y * 0.70 + inward * 0.088,
				Vector3(0.035, 0.050, 0.13), SUNSET_GOLD, basis)

	# Posts are NOT colliders: the same existing wall collision stays in
	# kart_island.gd / world.WALL_LATERAL. Fewer posts in low detail.
	if index % (4 if world.low_detail else 3) == 0:
		world._prop("box", at + basis.y * 0.52,
			Vector3(0.16, 1.06, 0.18), Color("607f99"), basis)
		if not world.low_detail and index % 6 == 0:
			world._prop("ball", at + basis.y * 1.14,
				Vector3.ONE * 0.105, SUNSET_GOLD, basis, true)
