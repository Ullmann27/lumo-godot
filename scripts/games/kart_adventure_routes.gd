extends RefCounted
## Eleven individually authored extended circuits. Sonnenhafen is deliberately absent.
## These are source control points for the existing road, collision and checkpoint curve.

const IDS: Array[String] = ["zauberwald", "bergwelt", "holo_city", "crystal_canyon", "jungle_temple", "candy_cloud", "volcano_night", "winter_sprint", "galaxy_ringway", "desert_drift", "learning_lab"]

static func supports(track_id: String) -> bool:
	return track_id in IDS

static func profile(track_id: String) -> Dictionary:
	match track_id:
		"zauberwald":
			return {"name": "Wurzelbibliothek", "theme": "forest", "covered_type": "hillside", "entry_index": 11, "exit_index": 15, "floor_target": 4.0}
		"bergwelt":
			return {"name": "Kristallwolken-Galerie", "theme": "sky", "covered_type": "cloud_gallery", "entry_index": 12, "exit_index": 15, "floor_target": 18.0}
		"holo_city":
			return {"name": "Aurora-Metro", "theme": "city", "covered_type": "city_gallery", "entry_index": 3, "exit_index": 6, "floor_target": 9.0}
		"crystal_canyon":
			return {"name": "Amethyst-Tiefengrotte", "theme": "crystal", "covered_type": "hillside", "entry_index": 2, "exit_index": 5, "floor_target": 3.0}
		"jungle_temple":
			return {"name": "Versunkene Tempelhalle", "theme": "jungle", "covered_type": "hillside", "entry_index": 12, "exit_index": 15, "floor_target": 3.0}
		"candy_cloud":
			return {"name": "Zuckerbäcker-Galerie", "theme": "candy", "covered_type": "cloud_gallery", "entry_index": 12, "exit_index": 15, "floor_target": 12.0}
		"volcano_night":
			return {"name": "Basalt-Glutstollen", "theme": "volcano", "covered_type": "hillside", "entry_index": 2, "exit_index": 5, "floor_target": 4.0}
		"winter_sprint":
			return {"name": "Gletscher-Kristallhöhle", "theme": "winter", "covered_type": "hillside", "entry_index": 2, "exit_index": 5, "floor_target": 3.0}
		"galaxy_ringway":
			return {"name": "Sternen-Observatorium", "theme": "galaxy", "covered_type": "orbital_gallery", "entry_index": 11, "exit_index": 14, "floor_target": 18.0}
		"desert_drift":
			return {"name": "Oasen-Katakomben", "theme": "desert", "covered_type": "hillside", "entry_index": 11, "exit_index": 14, "floor_target": 3.0}
		"learning_lab":
			return {"name": "Entdecker-Kernlabor", "theme": "lab", "covered_type": "laboratory_gallery", "entry_index": 10, "exit_index": 13, "floor_target": 6.0}
	return {}

static func points(track_id: String) -> PackedVector3Array:
	match track_id:
		"zauberwald":
			return PackedVector3Array([
				Vector3(0.00, 8.0, 271.06),
				Vector3(88.09, 10.0, 293.65),
				Vector3(169.41, 14.0, 268.80),
				Vector3(237.18, 20.0, 212.33),
				Vector3(293.65, 24.0, 146.82),
				Vector3(338.82, 22.0, 62.12),
				Vector3(310.59, 16.0, -16.94),
				Vector3(350.12, 12.0, -107.29),
				Vector3(304.94, 18.0, -203.29),
				Vector3(231.53, 24.0, -271.06),
				Vector3(135.53, 27.0, -293.65),
				Vector3(45.18, 21.0, -242.82), # Tunnel entrance: actual descent continues inside the hill.
				Vector3(-33.88, 5.0, -276.71),
				Vector3(-129.88, 4.0, -304.94),
				Vector3(-220.24, 4.0, -259.77),
				Vector3(-288.00, 20.0, -186.35), # Tunnel exit: the road climbs back into daylight.
				Vector3(-316.24, 27.0, -90.35),
				Vector3(-265.41, 18.0, -11.29),
				Vector3(-304.94, 12.0, 84.71),
				Vector3(-265.41, 7.0, 180.71),
				Vector3(-192.00, 10.0, 248.47),
				Vector3(-112.94, 16.0, 214.59),
				Vector3(-62.12, 9.0, 259.77),
			])
		"bergwelt":
			return PackedVector3Array([
				Vector3(0.00, 20.0, 244.96),
				Vector3(70.64, 20.0, 273.44),
				Vector3(148.11, 24.0, 250.65),
				Vector3(222.17, 30.0, 198.24),
				Vector3(268.88, 34.0, 119.63),
				Vector3(227.87, 32.0, 56.97),
				Vector3(280.27, 26.0, -20.51),
				Vector3(282.55, 22.0, -107.10),
				Vector3(205.08, 28.0, -166.34),
				Vector3(161.78, 34.0, -242.68),
				Vector3(66.08, 31.0, -275.72),
				Vector3(-9.11, 41.0, -227.87),
				Vector3(-79.75, 35.0, -264.32), # Tunnel entrance: actual descent continues inside the hill.
				Vector3(-164.06, 19.0, -219.89),
				Vector3(-240.40, 18.0, -156.09),
				Vector3(-275.72, 34.0, -70.64), # Tunnel exit: the road climbs back into daylight.
				Vector3(-229.00, 41.0, -1.14),
				Vector3(-266.60, 28.0, 82.03),
				Vector3(-234.70, 22.0, 162.92),
				Vector3(-166.34, 17.0, 216.47),
				Vector3(-97.98, 20.0, 182.29),
				Vector3(-47.85, 21.0, 232.42),
			])
		"holo_city":
			return PackedVector3Array([
				Vector3(0.00, 8.0, 265.88),
				Vector3(97.49, 10.0, 280.28),
				Vector3(190.55, 32.0, 261.45),
				Vector3(272.52, 26.0, 216.03), # Tunnel entrance: actual descent continues inside the hill.
				Vector3(323.48, 10.0, 138.48),
				Vector3(296.90, 9.0, 63.15),
				Vector3(336.78, 25.0, -9.97), # Tunnel exit: the road climbs back into daylight.
				Vector3(337.89, 32.0, -111.89),
				Vector3(276.96, 18.0, -186.11),
				Vector3(216.03, 24.0, -254.80),
				Vector3(120.75, 21.0, -285.82),
				Vector3(29.91, 15.0, -258.12),
				Vector3(-50.96, 10.0, -294.68),
				Vector3(-147.34, 7.0, -270.31),
				Vector3(-238.18, 13.0, -234.86),
				Vector3(-298.00, 18.0, -169.50),
				Vector3(-336.78, 23.0, -79.76),
				Vector3(-301.33, 18.0, 4.43),
				Vector3(-333.46, 12.0, 90.84),
				Vector3(-273.63, 7.0, 181.68),
				Vector3(-193.87, 10.0, 234.86),
				Vector3(-113.00, 16.0, 193.87),
				Vector3(-57.61, 9.0, 244.83),
			])
		"crystal_canyon":
			return PackedVector3Array([
				Vector3(0.00, 8.0, 277.20),
				Vector3(84.41, 26.0, 300.01),
				Vector3(172.25, 20.0, 270.35), # Tunnel entrance: actual descent continues inside the hill.
				Vector3(250.96, 4.0, 206.47),
				Vector3(308.00, 3.0, 118.64),
				Vector3(274.92, 19.0, 36.50), # Tunnel exit: the road climbs back into daylight.
				Vector3(326.25, 26.0, -41.07),
				Vector3(331.95, 12.0, -134.61),
				Vector3(253.24, 18.0, -201.91),
				Vector3(190.50, 24.0, -272.63),
				Vector3(93.54, 21.0, -300.01),
				Vector3(12.55, 15.0, -254.38),
				Vector3(-74.15, 10.0, -302.29),
				Vector3(-164.26, 7.0, -281.76),
				Vector3(-248.68, 13.0, -217.88),
				Vector3(-304.57, 18.0, -136.89),
				Vector3(-269.21, 23.0, -52.47),
				Vector3(-333.09, 18.0, 28.52),
				Vector3(-314.84, 12.0, 117.50),
				Vector3(-240.69, 7.0, 185.94),
				Vector3(-174.53, 10.0, 255.52),
				Vector3(-93.54, 16.0, 223.58),
				Vector3(-47.91, 9.0, 261.23),
			])
		"jungle_temple":
			return PackedVector3Array([
				Vector3(0.00, 8.0, 288.34),
				Vector3(92.27, 10.0, 313.71),
				Vector3(181.08, 14.0, 271.04),
				Vector3(236.44, 20.0, 193.76),
				Vector3(309.10, 24.0, 154.55),
				Vector3(341.39, 22.0, 71.51),
				Vector3(294.11, 16.0, -4.61),
				Vector3(336.78, 12.0, -87.66),
				Vector3(302.18, 18.0, -184.54),
				Vector3(222.60, 24.0, -234.13),
				Vector3(163.78, 21.0, -309.10),
				Vector3(77.28, 26.0, -322.94),
				Vector3(1.15, 20.0, -267.58), # Tunnel entrance: actual descent continues inside the hill.
				Vector3(-84.20, 4.0, -299.87),
				Vector3(-169.54, 3.0, -267.58),
				Vector3(-235.29, 19.0, -198.38), # Tunnel exit: the road climbs back into daylight.
				Vector3(-320.63, 26.0, -160.32),
				Vector3(-347.16, 18.0, -72.66),
				Vector3(-289.49, 12.0, 3.46),
				Vector3(-326.40, 7.0, 94.58),
				Vector3(-268.73, 10.0, 176.46),
				Vector3(-181.08, 16.0, 216.83),
				Vector3(-111.88, 11.0, 284.88),
				Vector3(-48.44, 9.0, 258.35),
			])
		"candy_cloud":
			return PackedVector3Array([
				Vector3(0.00, 20.0, 275.52),
				Vector3(83.32, 20.0, 311.08),
				Vector3(167.76, 24.0, 286.63),
				Vector3(236.64, 30.0, 225.53),
				Vector3(305.52, 34.0, 163.32),
				Vector3(336.63, 32.0, 77.77),
				Vector3(288.86, 26.0, 5.55),
				Vector3(341.07, 22.0, -75.55),
				Vector3(315.52, 28.0, -166.65),
				Vector3(246.64, 34.0, -228.86),
				Vector3(157.76, 31.0, -255.53),
				Vector3(98.88, 35.0, -311.08),
				Vector3(8.89, 29.0, -331.07), # Tunnel entrance: actual descent continues inside the hill.
				Vector3(-64.44, 13.0, -274.41),
				Vector3(-155.54, 12.0, -299.97),
				Vector3(-237.75, 28.0, -244.42), # Tunnel exit: the road climbs back into daylight.
				Vector3(-288.86, 35.0, -164.43),
				Vector3(-261.08, 28.0, -86.66),
				Vector3(-328.85, 22.0, -6.67),
				Vector3(-311.08, 17.0, 87.77),
				Vector3(-247.75, 20.0, 162.20),
				Vector3(-169.98, 26.0, 188.87),
				Vector3(-103.32, 21.0, 261.08),
				Vector3(-45.55, 21.0, 242.20),
			])
		"volcano_night":
			return PackedVector3Array([
				Vector3(0.00, 8.0, 284.59),
				Vector3(88.09, 27.0, 313.96),
				Vector3(177.31, 21.0, 283.46), # Tunnel entrance: actual descent continues inside the hill.
				Vector3(251.84, 5.0, 217.96),
				Vector3(311.70, 4.0, 133.26),
				Vector3(280.08, 20.0, 48.56), # Tunnel exit: the road climbs back into daylight.
				Vector3(341.06, 27.0, -29.36),
				Vector3(327.51, 12.0, -124.23),
				Vector3(257.49, 18.0, -193.12),
				Vector3(223.61, 24.0, -281.21),
				Vector3(134.39, 21.0, -320.73),
				Vector3(51.95, 15.0, -274.43),
				Vector3(-29.36, 10.0, -313.96),
				Vector3(-125.36, 7.0, -300.40),
				Vector3(-201.02, 13.0, -240.55),
				Vector3(-283.46, 18.0, -203.28),
				Vector3(-329.77, 23.0, -117.45),
				Vector3(-286.85, 18.0, -35.01),
				Vector3(-330.90, 12.0, 48.56),
				Vector3(-301.53, 7.0, 140.04),
				Vector3(-229.26, 10.0, 204.41),
				Vector3(-144.56, 16.0, 233.77),
				Vector3(-76.80, 11.0, 284.59),
				Vector3(-31.62, 9.0, 250.71),
			])
		"winter_sprint":
			return PackedVector3Array([
				Vector3(0.00, 8.0, 294.99),
				Vector3(89.73, 26.0, 317.42),
				Vector3(178.34, 20.0, 279.29), # Tunnel entrance: actual descent continues inside the hill.
				Vector3(241.15, 4.0, 204.14),
				Vector3(310.69, 3.0, 164.88),
				Vector3(338.73, 19.0, 77.39), # Tunnel exit: the road climbs back into daylight.
				Vector3(298.35, 26.0, 1.12),
				Vector3(346.58, 12.0, -79.64),
				Vector3(311.81, 18.0, -167.12),
				Vector3(228.81, 24.0, -213.11),
				Vector3(182.83, 21.0, -297.23),
				Vector3(90.85, 15.0, -327.52),
				Vector3(5.61, 10.0, -282.65),
				Vector3(-81.88, 7.0, -312.94),
				Vector3(-167.12, 13.0, -266.95),
				Vector3(-241.15, 18.0, -224.33),
				Vector3(-303.96, 23.0, -146.93),
				Vector3(-271.44, 18.0, -62.81),
				Vector3(-327.52, 12.0, 15.70),
				Vector3(-303.96, 7.0, 107.68),
				Vector3(-235.54, 10.0, 177.22),
				Vector3(-157.03, 16.0, 222.08),
				Vector3(-87.49, 11.0, 283.77),
				Vector3(-33.65, 9.0, 256.85),
			])
		"galaxy_ringway":
			return PackedVector3Array([
				Vector3(0.00, 20.0, 305.94),
				Vector3(94.75, 20.0, 326.48),
				Vector3(186.07, 24.0, 280.82),
				Vector3(250.00, 30.0, 206.62),
				Vector3(318.49, 34.0, 144.98),
				Vector3(348.17, 32.0, 55.94),
				Vector3(303.65, 26.0, -19.41),
				Vector3(348.17, 22.0, -100.46),
				Vector3(310.50, 28.0, -187.21),
				Vector3(232.88, 34.0, -248.86),
				Vector3(144.98, 41.0, -271.69),
				Vector3(70.78, 35.0, -328.77), # Tunnel entrance: actual descent continues inside the hill.
				Vector3(-21.69, 19.0, -327.63),
				Vector3(-93.61, 18.0, -269.41),
				Vector3(-180.37, 34.0, -297.95), # Tunnel exit: the road climbs back into daylight.
				Vector3(-256.85, 41.0, -236.30),
				Vector3(-305.94, 33.0, -154.11),
				Vector3(-271.69, 28.0, -77.63),
				Vector3(-335.62, 22.0, 4.57),
				Vector3(-309.36, 17.0, 98.17),
				Vector3(-242.01, 20.0, 167.81),
				Vector3(-159.82, 26.0, 206.62),
				Vector3(-91.32, 21.0, 275.11),
				Vector3(-31.96, 21.0, 257.99),
			])
		"desert_drift":
			return PackedVector3Array([
				Vector3(0.00, 8.0, 271.90),
				Vector3(89.89, 10.0, 304.08),
				Vector3(177.57, 14.0, 278.56),
				Vector3(244.15, 20.0, 216.41),
				Vector3(324.06, 24.0, 174.24),
				Vector3(360.68, 22.0, 93.22),
				Vector3(312.96, 16.0, 13.32),
				Vector3(357.35, 12.0, -67.70),
				Vector3(324.06, 18.0, -158.70),
				Vector3(240.82, 24.0, -205.31),
				Vector3(197.54, 26.0, -282.99),
				Vector3(106.54, 20.0, -315.18), # Tunnel entrance: actual descent continues inside the hill.
				Vector3(19.98, 4.0, -278.56),
				Vector3(-71.03, 3.0, -316.29),
				Vector3(-158.70, 19.0, -280.77), # Tunnel exit: the road climbs back into daylight.
				Vector3(-229.72, 26.0, -217.52),
				Vector3(-309.63, 23.0, -176.46),
				Vector3(-347.36, 18.0, -93.22),
				Vector3(-302.97, 12.0, -11.10),
				Vector3(-337.37, 7.0, 72.14),
				Vector3(-295.20, 10.0, 160.92),
				Vector3(-215.30, 16.0, 215.30),
				Vector3(-127.62, 11.0, 235.27),
				Vector3(-55.49, 9.0, 274.12),
			])
		"learning_lab":
			return PackedVector3Array([
				Vector3(0.00, 8.0, 286.24),
				Vector3(89.45, 10.0, 314.20),
				Vector3(180.02, 14.0, 275.06),
				Vector3(243.75, 20.0, 202.38),
				Vector3(310.84, 24.0, 147.59),
				Vector3(337.68, 22.0, 60.38),
				Vector3(295.19, 16.0, -17.89),
				Vector3(338.80, 12.0, -98.40),
				Vector3(305.25, 18.0, -184.49),
				Vector3(228.10, 29.0, -241.52),
				Vector3(142.00, 23.0, -276.18), # Tunnel entrance: actual descent continues inside the hill.
				Vector3(68.21, 7.0, -326.50),
				Vector3(-23.48, 6.0, -306.37),
				Vector3(-93.92, 22.0, -253.82), # Tunnel exit: the road climbs back into daylight.
				Vector3(-182.26, 29.0, -285.13),
				Vector3(-256.05, 18.0, -224.75),
				Vector3(-306.37, 23.0, -143.12),
				Vector3(-273.94, 18.0, -64.85),
				Vector3(-326.50, 12.0, 12.30),
				Vector3(-303.02, 7.0, 105.11),
				Vector3(-231.45, 10.0, 174.43),
				Vector3(-154.30, 16.0, 211.33),
				Vector3(-86.10, 11.0, 276.18),
				Vector3(-32.43, 9.0, 251.58),
			])
	return PackedVector3Array()
