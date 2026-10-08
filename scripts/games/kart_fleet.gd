extends RefCounted
## Six original body designs share the proven animated chassis and Lumo driver.
## Profiles change authored geometry and road behaviour; reference art is separate.

const IDS: Array[String] = [
	"gecko_velo", "boru_rally", "nala_comet", "noa_tide", "iva_aurora", "zuri_volt"
]
const PROFILES: Dictionary = {
	"gecko_velo":
	{"paint": "a9dd37", "width": 0.93, "nose": 0.78, "height": 0.91, "wing": 1.24, "wing_y": 0.95},
	"boru_rally":
	{"paint": "cc7d3f", "width": 1.08, "nose": 1.10, "height": 1.14, "wing": 1.42, "wing_y": 1.03},
	"nala_comet":
	{"paint": "ef7968", "width": 0.98, "nose": 0.94, "height": 1.02, "wing": 1.38, "wing_y": 0.96},
	"noa_tide":
	{"paint": "478de1", "width": 1.02, "nose": 1.08, "height": 0.96, "wing": 1.50, "wing_y": 0.88},
	"iva_aurora":
	{"paint": "a0a6e9", "width": 0.96, "nose": 0.82, "height": 0.93, "wing": 1.60, "wing_y": 1.02},
	"zuri_volt":
	{"paint": "efc044", "width": 1.04, "nose": 1.16, "height": 1.04, "wing": 1.46, "wing_y": 0.98}
}
const CATALOG: Array[Dictionary] = [
	{
		"id": "gecko_velo",
		"name": "Gecko Velo",
		"tag": "FLINK DURCH KURVEN",
		"description": "Schmale Nase, flinke Lenkung und schneller Antritt.",
		"speed": 1.02,
		"turn": 1.08,
		"accel": 1.08,
		"unlock": 0
	},
	{
		"id": "boru_rally",
		"name": "Boru Rally",
		"tag": "KRAFTVOLLER ANTRITT",
		"description": "Rallye-Bügel, breite Schultern und kräftige Beschleunigung.",
		"speed": 0.96,
		"turn": 0.99,
		"accel": 1.20,
		"unlock": 4
	},
	{
		"id": "nala_comet",
		"name": "Nala Comet",
		"tag": "SPORTLICH UND WENDIG",
		"description": "Geschwungene Heckflossen und ein ausgewogener Sprint.",
		"speed": 1.06,
		"turn": 1.03,
		"accel": 1.04,
		"unlock": 10
	},
	{
		"id": "noa_tide",
		"name": "Noa Tide",
		"tag": "SANFTE WELLENLINIEN",
		"description": "Runde Bugform und besonders angenehme Lenkung.",
		"speed": 1.00,
		"turn": 1.12,
		"accel": 1.10,
		"unlock": 12
	},
	{
		"id": "iva_aurora",
		"name": "Iva Aurora",
		"tag": "LEICHTER AEROFLÜGEL",
		"description": "Federflossen, eine schlanke Nase und Tempo auf Geraden.",
		"speed": 1.08,
		"turn": 1.06,
		"accel": 0.97,
		"unlock": 16
	},
	{
		"id": "zuri_volt",
		"name": "Zuri Volt",
		"tag": "ELEKTRISCHER ANTRITT",
		"description": "Wabengrill, Lichtfühler und ein lebhafter Start.",
		"speed": 1.04,
		"turn": 1.02,
		"accel": 1.15,
		"unlock": 20
	}
]


static func profile(id: String) -> Dictionary:
	return PROFILES.get(id, {}).duplicate()


static func shell(id: String) -> Array[Vector4]:
	var info: Dictionary = profile(id)
	var n: float = float(info.get("nose", 1.0))
	var h: float = float(info.get("height", 1.0))
	return [
		Vector4(-1.16, 0.015, 0.018, 0.50),
		Vector4(-1.07, 0.24 * n, 0.065 * h, 0.51),
		Vector4(-0.81, 0.45 * n, 0.17 * h, 0.52),
		Vector4(-0.48, 0.58, 0.20 * h, 0.50),
		Vector4(0.06, 0.61, 0.14, 0.45),
		Vector4(0.55, 0.61, 0.15, 0.46),
		Vector4(0.91, 0.48, 0.15 * h, 0.49),
		Vector4(1.05, 0.20, 0.065, 0.50),
		Vector4(1.08, 0.01, 0.015, 0.50)
	]


static func decorate(kart, body: Node3D, paint: Color, id: String) -> void:
	if not PROFILES.has(id):
		return
	body.set_meta("fleet_design", id)
	for side in [-1.0, 1.0]:
		match id:
			"gecko_velo":
				_fin(kart, body, Vector3(side * 0.36, 0.85, 0.48), side, paint, 0.38)
				kart._ellipsoid(
					body,
					Vector3(side * 0.29, 0.64, -0.93),
					Vector3(0.10, 0.07, 0.08),
					kart.INK,
					0.2,
					0.35
				)
				kart._ellipsoid(
					body,
					Vector3(side * 0.29, 0.64, -1.00),
					Vector3(0.064, 0.044, 0.023),
					kart.WHITE,
					0.18,
					0.27
				)
			"boru_rally":
				var lamp: MeshInstance3D = kart._ring(
					body, Vector3(side * 0.28, 0.78, -0.94), 0.070, 0.095, kart.CHROME, 0.75
				)
				lamp.rotation.x = PI / 2.0
				kart._ellipsoid(
					body,
					Vector3(side * 0.28, 0.78, -0.945),
					Vector3(0.071, 0.071, 0.024),
					kart.WHITE,
					0.18,
					0.27
				)
				_ribbon(
					kart,
					body,
					[
						Vector3(side * 0.52, 0.52, -1.08),
						Vector3(side * 0.57, 0.60, -1.13),
						Vector3(0, 0.60, -1.13)
					],
					0.036,
					kart.CHROME,
					0.75
				)
			"nala_comet":
				_fin(kart, body, Vector3(side * 0.40, 0.78, 0.48), side, paint, 0.32)
				for stripe in range(3):
					kart._box(
						body,
						Vector3(side * 0.406, 0.86 + stripe * 0.06, 0.485),
						Vector3(0.034, 0.025, 0.16),
						kart.WHITE,
						0.18
					)
			"noa_tide":
				_ribbon(
					kart,
					body,
					[
						Vector3(side * 0.20, 0.75, -0.94),
						Vector3(side * 0.33, 0.73, -0.78),
						Vector3(side * 0.40, 0.70, -0.55)
					],
					0.036,
					kart.WHITE,
					0.18
				)
				_ribbon(
					kart,
					body,
					[
						Vector3(side * 0.63, 0.60, -0.20),
						Vector3(side * 0.66, 0.67, 0.10),
						Vector3(side * 0.60, 0.61, 0.48)
					],
					0.022,
					kart.ICE,
					0.15,
					0.9
				)
			"iva_aurora":
				for feather in range(3):
					_fin(
						kart,
						body,
						Vector3(side * (0.48 + feather * 0.055), 0.55, 0.16 + feather * 0.10),
						side,
						kart.WHITE,
						0.19 - feather * 0.03
					)
				_ribbon(
					kart,
					body,
					[
						Vector3(side * 0.12, 0.79, -0.75),
						Vector3(side * 0.27, 0.77, -0.65),
						Vector3(side * 0.38, 0.70, -0.53)
					],
					0.019,
					paint,
					0.42
				)
			"zuri_volt":
				kart._rod(
					body,
					Vector3(side * 0.34, 0.90, 0.38),
					Vector3(side * 0.42, 1.21, 0.46),
					0.017,
					kart.INK,
					0.2
				)
				kart._ellipsoid(
					body,
					Vector3(side * 0.42, 1.22, 0.46),
					Vector3(0.047, 0.047, 0.047),
					kart.ICE,
					0.15,
					0.5
				)
	if id == "boru_rally":
		_ribbon(
			kart,
			body,
			[
				Vector3(-0.40, 0.66, 0.49),
				Vector3(-0.40, 1.25, 0.49),
				Vector3(-0.26, 1.40, 0.49),
				Vector3(0.26, 1.40, 0.49),
				Vector3(0.40, 1.25, 0.49),
				Vector3(0.40, 0.66, 0.49)
			],
			0.041,
			kart.CHROME,
			0.75
		)
	if id == "zuri_volt":
		for cell in range(7):
			var x: float = (float(cell % 4) - 1.5) * 0.12
			var y: float = 0.56 + floorf(float(cell) / 4.0) * 0.10
			var points: Array[Vector3] = []
			for corner in range(7):
				var a: float = float(corner) * TAU / 6.0
				points.append(Vector3(x + cos(a) * 0.061, y + sin(a) * 0.061, -1.085))
			_ribbon(kart, body, points, 0.009, kart.CHROME, 0.75)


static func _fin(kart, body: Node3D, at: Vector3, side: float, paint: Color, height: float) -> void:
	var rings: Array[Vector4] = [
		Vector4(0, 0.025, 0.16, 0),
		Vector4(height * 0.38, 0.035, 0.13, 0.03),
		Vector4(height * 0.85, 0.024, 0.065, 0.09),
		Vector4(height, 0.003, 0.008, 0.12)
	]
	var fin: MeshInstance3D = kart._mesh(
		body, kart._loft(rings, true, 16, 3), at, paint, 0.42, 0.24
	)
	fin.rotation.z = -side * 0.18


static func _ribbon(
	kart,
	body: Node3D,
	points: Array[Vector3],
	width: float,
	color: Color,
	metal: float = 0.0,
	glow: float = 0.0
) -> void:
	kart._ribbon(body, points, width, color, metal, glow)
