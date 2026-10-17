class_name LumoKartTracks
extends RefCounted
## Original course designs. Distances and heights are metres in the shared world.

const EXPANSION = preload("res://scripts/games/kart_expansion_tracks.gd")
const HARBOR_LONG = preload("res://scripts/games/kart_sonnenhafen_long_course.gd")
static var IDS: Array[String] = _all_ids()

static func _all_ids() -> Array[String]:
	var result: Array[String] = ["sonnenhafen", "zauberwald", "bergwelt", "holo_city"]
	result.append_array(EXPANSION.IDS)
	result.make_read_only()
	return result


static func definition(id: String) -> Dictionary:
	if id in EXPANSION.IDS:
		return EXPANSION.definition(id)
	match id:
		"zauberwald":
			return {
				"id": id, "name": "Zauberwald", "subtitle": "Lichter zwischen den Baumkronen",
				"accent": Color("7debd8"), "asphalt": Color("202937"),
				"sky": Color("172a48"), "horizon": Color("538b95"), "fog": Color("315c68"),
				"sun": Color("ffe0b0"), "ground": Color("244b48"), "seed": 24019,
				"points": PackedVector3Array([
					Vector3(0, 1.4, 60), Vector3(35, 2.0, 48), Vector3(64, 5.0, 24),
					Vector3(46, 8.5, -8), Vector3(60, 6.2, -42), Vector3(26, 2.0, -66),
					Vector3(-10, 3.5, -55), Vector3(-47, 6.0, -64), Vector3(-73, 8.0, -27),
					Vector3(-44, 5.2, -3), Vector3(-60, 2.2, 27), Vector3(-27, 1.5, 53)
				])
			}
		"bergwelt":
			return {
				# Himmelsinseln Sprint (reference k07): road carried by floating islands at night.
				"id": id, "name": "Himmelsinseln", "subtitle": "Hoch hinaus. Gemeinsam weiter!",
				"accent": Color("4fe6ff"), "asphalt": Color("20283d"),
				"sky": Color("0b1a4a"), "horizon": Color("3b3f9a"), "fog": Color("3a4c98"),
				"sun": Color("c3d0ff"), "ground": Color("4f9a44"), "seed": 63181,
				"points": PackedVector3Array([
					Vector3(0, 4, 65), Vector3(43, 6, 55), Vector3(71, 12, 26),
					Vector3(51, 17, -2), Vector3(75, 20, -38), Vector3(36, 21, -65),
					Vector3(3, 17, -45), Vector3(-27, 13, -66), Vector3(-67, 9, -36),
					Vector3(-54, 13, -5), Vector3(-73, 16, 25), Vector3(-38, 8, 54)
				])
			}
		"holo_city":
			return {
				"id": id, "name": "Hologramm-City", "subtitle": "Über den Dächern der Zukunft",
				"accent": Color("6ee4f4"), "asphalt": Color("172235"),
				"sky": Color("080f30"), "horizon": Color("334f82"), "fog": Color("253f70"),
				"sun": Color("b5d8ff"), "ground": Color("11263b"), "seed": 8073,
				"points": PackedVector3Array([
					Vector3(0, 9, 64), Vector3(45, 9, 57), Vector3(74, 13, 32),
					Vector3(76, 20, -5), Vector3(48, 23, -24), Vector3(63, 19, -58),
					Vector3(24, 12, -75), Vector3(-12, 11, -59), Vector3(-54, 16, -69),
					Vector3(-79, 22, -25), Vector3(-55, 18, 4), Vector3(-76, 11, 34),
					Vector3(-39, 9, 64)
				])
			}
		_:
			return {
				"id": "sonnenhafen",
				"name": "Sonnenhafen",
				"subtitle": "Grand Prix zwischen Klippen, Hafen und Wasserfall",
				"accent": Color("63dce9"), "asphalt": Color("242d38"),
				"sky": Color("276ba0"), "horizon": Color("e7a976"), "fog": Color("d9b18b"),
				"sun": Color("ffe5bc"), "ground": Color("7caa69"), "seed": 109021,
				# Experimental B2 circuit: 23 independently authored coastal control points.
				# Keep the prior 1972 route immutable on its pinned SHA.
				"points": HARBOR_LONG.points()
			}
