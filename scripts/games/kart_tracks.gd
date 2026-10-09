class_name LumoKartTracks
extends RefCounted
## Original course designs. Distances and heights are metres in the shared world.

const EXPANSION = preload("res://scripts/games/kart_expansion_tracks.gd")
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
				"accent": Color("a6e9d0"), "asphalt": Color("374b5c"),
				"sky": Color("243c73"), "horizon": Color("a3c7d1"), "fog": Color("90b9c3"),
				"sun": Color("e2e9ff"), "ground": Color("244b48"), "seed": 24019,
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
				"accent": Color("4fe6ff"), "asphalt": Color("2b3550"),
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
				"accent": Color("6ee4f4"), "asphalt": Color("152d49"),
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
				"accent": Color("77dbe0"), "asphalt": Color("3d556b"),
				"sky": Color("197acb"), "horizon": Color("83c8ee"), "fog": Color("afd8e7"),
				"sun": Color("ffe5bc"), "ground": Color("7caa69"), "seed": 109021,
				# Long-form coastal circuit: stadium straight -> uphill cliff S -> high hairpin ->
				# harbour descent -> bridge approach -> waterfront sweep -> final technical bends.
				"points": PackedVector3Array([
					Vector3(0, 1.8, 72),
					Vector3(42, 2.2, 69),
					Vector3(77, 3.8, 49),
					Vector3(94, 7.0, 19),
					Vector3(78, 12.5, -8),
					Vector3(94, 15.5, -43),
					Vector3(67, 13.0, -78),
					Vector3(31, 8.0, -91),
					Vector3(2, 5.5, -70),
					Vector3(-24, 7.0, -86),
					Vector3(-61, 10.0, -77),
					Vector3(-89, 14.5, -48),
					Vector3(-84, 18.0, -13),
					Vector3(-55, 19.0, 12),
					Vector3(-78, 13.0, 43),
					Vector3(-50, 7.5, 70),
					Vector3(-18, 3.2, 80)
				])
			}
