extends RefCounted
## Lumo Kart: racing skill, never a hidden random item table.
## A single pure deterministic scoring policy serves the human racer and
## opponents. No rewards depend on place: leaders and newcomers are equal.
const BOOST: String = "boost"
const PHASE_SHIELD: String = "shield"
const GRAVITY_PULSE: String = "pulse"

const BRONZE_THRESHOLD: float = 0.0
const SILVER_THRESHOLD: float = 0.55
const GOLD_THRESHOLD: float = 0.79
const MIN_PICKUP_SPEED: float = 6.5


static func award(
	speed: float,
	course_speed: float,
	lateral_error: float,
	drift_charge: float,
	hit_recently: bool
) -> Dictionary:
	# The reference speed is the kart's own tuned target, not a fixed speed
	# favouring expensive/fast karts. Driving near the ring's ideal line is
	# the biggest contributor; controlled drift and speed are both rewarded.
	var pace: float = clampf(maxf(speed, 0.0) / maxf(course_speed, 1.0), 0.0, 1.0)
	var line: float = 1.0 - clampf(absf(lateral_error) / 2.3, 0.0, 1.0)
	var drift: float = clampf(drift_charge / 1.5, 0.0, 1.0)
	var score: float = clampf(line * 0.47 + pace * 0.38 + drift * 0.15, 0.0, 1.0)
	if hit_recently:
		score = minf(score, 0.28)
	var tier: int = 0
	var reward: String = BOOST
	if score >= GOLD_THRESHOLD:
		tier = 2
		reward = GRAVITY_PULSE
	elif score >= SILVER_THRESHOLD:
		tier = 1
		reward = PHASE_SHIELD
	return {"item": reward, "tier": tier, "score": snappedf(score, 0.001)}


static func ring_colour(tier: int) -> Color:
	match tier:
		2:
			return Color("f8c85d")
		1:
			return Color("ad9cff")
		_:
			return Color("53e8ef")


static func build_ring(parent: Node3D, transform: Transform3D) -> Node3D:
	# Collision-free, reusable low-poly torus; no raycasts, bodies or bones.
	# Unlike a mystery cube the player sees a stable ring from far away.
	var root := Node3D.new()
	root.name = "SkillResonanceRing"
	root.transform = transform
	parent.add_child(root)
	var ring := MeshInstance3D.new()
	ring.name = "ResonanceHalo"
	var mesh := TorusMesh.new()
	mesh.inner_radius = 1.85
	mesh.outer_radius = 2.06
	mesh.rings = 24
	mesh.ring_segments = 7
	ring.mesh = mesh
	ring.rotation.x = PI / 2.0
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("3aeeff")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = Color("1bb7ff")
	material.emission_energy_multiplier = 1.9
	material.metallic = 0.0
	material.roughness = 0.5
	ring.material_override = material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	root.set_meta("lumo_racing_pickup", "skill_resonance")
	return root
