class_name LumoKartTracks
extends RefCounted
## Original course designs. Distances and heights are metres in the shared world.

const IDS: Array[String] = ["sonnenhafen", "zauberwald", "bergwelt", "holo_city"]


static func definition(id: String) -> Dictionary:
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
				"id": id, "name": "Wolkenpass", "subtitle": "Gipfel, Schluchten und Wolkenbrücken",
				"accent": Color("9cdcff"), "asphalt": Color("53687b"),
				"sky": Color("378dcc"), "horizon": Color("d9edf2"), "fog": Color("c3dcec"),
				"sun": Color("fff0d6"), "ground": Color("738c84"), "seed": 63181,
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
				"id": "sonnenhafen", "name": "Sonnenhafen", "subtitle": "Eine Runde entlang der goldenen Küste",
				"accent": Color("77dbe0"), "asphalt": Color("3d556b"),
				"sky": Color("197acb"), "horizon": Color("83c8ee"), "fog": Color("afd8e7"),
				"sun": Color("ffe5bc"), "ground": Color("7caa69"), "seed": 109021,
				"points": PackedVector3Array([
					Vector3(0, 1.6, 54), Vector3(36, 1.9, 50), Vector3(66, 2.8, 25),
					Vector3(58, 7.2, -4), Vector3(75, 9.2, -32), Vector3(39, 8.0, -64),
					Vector3(5, 3.2, -53), Vector3(-27, 2.3, -63), Vector3(-64, 3.4, -37),
					Vector3(-43, 4.1, -9), Vector3(-67, 7.4, 15), Vector3(-42, 6.1, 45),
					Vector3(-19, 2.8, 59)
				])
			}
