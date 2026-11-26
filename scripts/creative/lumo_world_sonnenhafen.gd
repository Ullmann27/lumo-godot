extends Node3D
## Sonnenhafen: the harbour town region of LUMO World.
## Builds the town (lumo_world_sonnenhafen_town.gd), its residents
## (lumo_world_npc_crowd.gd) and runs the region's missions with the same
## World mission model as the open-world chapter (lumo_world_quests.gd), plus
## the shop (Hafenkrämer, trading with shells), the Kontor delivery board, the
## fish crates and the harbour learning round through the existing Lumo
## World learning bridge. All residents are local computer figures.

const LAYOUT = preload("res://scripts/creative/lumo_world_sonnenhafen_layout.gd")
const TOWN = preload("res://scripts/creative/lumo_world_sonnenhafen_town.gd")
const CROWD = preload("res://scripts/creative/lumo_world_npc_crowd.gd")
const BRAIN = preload("res://scripts/creative/lumo_world_npc_brain.gd")
const QUESTS = preload("res://scripts/creative/lumo_world_quests.gd")
const DIALOG = preload("res://scripts/creative/lumo_world_dialog.gd")
const VILLAGE = preload("res://scripts/creative/build_village_art.gd")
const KIT = preload("res://scripts/creative/creative_kit.gd")
const CONTENT_PATH := "res://assets/creative/lumo_world/sonnenhafen/sonnenhafen_quests.json"
const VERSION := 1
const DAY_SECONDS := 720.0
const START_SHELLS := 4
const MAX_SHELLS := 999
const TALK_REACH := 3.4
const TRADE_REACH := 3.2
const CRATE_REACH := 4.5
const FISH_CRATES := 3
const ITEMS := {
	"seil": {"title": "Seil", "buy": 3, "sell": 1},
	"laternenglas": {"title": "Laternenglas", "buy": 6, "sell": 3},
	"broetchen": {"title": "Brötchen", "buy": 2, "sell": 1},
	"muschelkette": {"title": "Muschelkette", "buy": 5, "sell": 2},
	"kompass": {"title": "Kompass", "buy": 9, "sell": 4},
	"fisch": {"title": "Fisch", "buy": 3, "sell": 2},
	"abzeichen": {"title": "Leuchtturm-Abzeichen", "buy": 0, "sell": 0}
}
const ORDERS: Array[Dictionary] = [
	{
		"to": "ole",
		"goods": "drei Dochte",
		"address": "An: Ole Löwenzahn, Leuchtturm am Ende der Mole.",
		"reward": 4,
		"color": "d94a3d"
	},
	{
		"to": "mila",
		"goods": "einen Sack Mehl",
		"address": "An: Mila Sanddorn, Bäckerin. Meist am Brotstand auf dem Hafenmarkt.",
		"reward": 3,
		"color": "e0a030"
	},
	{
		"to": "theo",
		"goods": "Kakaobohnen",
		"address": "An: Theo Tide, Café Kompass in der Laternengasse.",
		"reward": 3,
		"color": "8a5a33"
	},
	{
		"to": "nora",
		"goods": "eine Rolle Garn",
		"address": "An: Nora Netz, Netzflickerin bei den Netzgestellen am Kai.",
		"reward": 3,
		"color": "3f9a5a"
	},
	{
		"to": "jonte",
		"goods": "blaue Bootsfarbe",
		"address": "An: Jonte Krabbe, Fischer am Fischerpier.",
		"reward": 4,
		"color": "2f7fb5"
	},
	{
		"to": "lotte",
		"goods": "buntes Glas",
		"address": "An: Lotte Laterne, Laternenwerkstatt in der Laternengasse.",
		"reward": 3,
		"color": "b388ff"
	},
	{
		"to": "paul",
		"goods": "Segeltuch",
		"address": "An: Paul Seestern, Segelmacherei in der Laternengasse.",
		"reward": 3,
		"color": "fbf6ea"
	},
	{
		"to": "wilma",
		"goods": "einen Blumentopf",
		"address": "An: Wilma Welle. Sie sitzt gern auf der Bank am Kanal.",
		"reward": 2,
		"color": "f78fb3"
	}
]
const LESSON_SETS := [
	[[3, 2], [4, 3], [5, 4]],
	[[12, 8], [27, 5], [36, 14]],
	[[124, 35], [278, 112], [416, 84]],
	[[1250, 750], [2480, 520], [3760, 1240]]
]

var world: Node3D
var layout
var town: Node3D
var crowd: Node3D
var model
var save_valid := true
var wallet := START_SHELLS
var inventory: Dictionary = {}
var rewarded: Array[String] = []
var fish_crates := 0
var carrying: Dictionary = {}
var delivery_index := 0
var deliveries_done := 0
var pending_lesson: Dictionary = {}
var clock := 0.0
var hour := BRAIN.DAY_START
var evening := 0.0
var evening_applied := -1.0
var observe_clock := 0.0
var inside := ""
var carried_crate: MeshInstance3D
var quest_marker: MeshInstance3D
var runner = null
var dialog_figure := ""
var dialog_mission := ""
var dialog_step := ""
var lesson_index := 0
var lesson_correct := 0
var daylight: Dictionary = {}
var tracked_delivery := false
var was_in_region := false


## Ground rectangles that the mainland tree scatter keeps free.
static func clear_areas() -> Array[Rect2]:
	var plan = LAYOUT.new()
	return plan.clear_areas() if plan.ready() else []


func setup(owner_world: Node3D, saved: Variant = {}) -> bool:
	world = owner_world
	name = "Sonnenhafen"
	layout = LAYOUT.new()
	if not layout.ready():
		push_error("[Sonnenhafen] layout invalid: " + ", ".join(layout.errors))
		save_valid = false
		return false
	var raw = JSON.parse_string(FileAccess.get_file_as_string(CONTENT_PATH))
	model = QUESTS.new(raw)
	if not model.ready():
		push_error("[Sonnenhafen] missions invalid: " + ", ".join(model.errors))
		save_valid = false
		return false
	town = TOWN.new()
	add_child(town)
	town.setup(world, layout)
	crowd = CROWD.new()
	add_child(crowd)
	var people: Variant = saved.get("people", {}) if saved is Dictionary else {}
	var crowd_ok: bool = crowd.setup(
		world, town, layout, {"people": people if people is Dictionary else {}}
	)
	save_valid = restore(saved) and crowd_ok
	_capture_daylight()
	_build_markers()
	_sync_figures()
	return save_valid


func unlocked() -> bool:
	return save_valid and is_instance_valid(world) and not bool(world.get("save_blocked"))


func region_contains(at: Vector3) -> bool:
	return at.z < -97.0 and at.x > 60.0 and at.x < 282.0


# --- Save ------------------------------------------------------------------------


func to_data() -> Dictionary:
	var stock: Dictionary = {}
	for item in inventory:
		if int(inventory[item]) > 0:
			stock[str(item)] = int(inventory[item])
	var carry_data := {}
	if not carrying.is_empty():
		carry_data = {"kind": str(carrying.kind), "order": int(carrying.get("order", -1))}
	return {
		"version": VERSION,
		"quests": model.to_data(),
		"wallet": wallet,
		"inventory": stock,
		"rewarded": rewarded.duplicate(),
		"fishCrates": fish_crates,
		"carry": carry_data,
		"deliveryIndex": delivery_index,
		"deliveriesDone": deliveries_done,
		"pendingLesson": pending_lesson.duplicate(true),
		"people": crowd.to_data().people if is_instance_valid(crowd) else {}
	}


## An older World save has no "sonnenhafen" section: the region starts fresh.
## A damaged section is rejected as a whole and kept unchanged by the World.
func restore(raw: Variant) -> bool:
	if not raw is Dictionary:
		return false
	if raw.is_empty():
		return model.restore({})
	if raw.get("version") != VERSION:
		return false
	for field in ["wallet", "fishCrates", "deliveryIndex", "deliveriesDone"]:
		var value = raw.get(field, 0)
		if (
			typeof(value) not in [TYPE_INT, TYPE_FLOAT]
			or not is_finite(float(value))
			or float(value) != floorf(float(value))
			or float(value) < 0
		):
			return false
	if int(raw.get("wallet", 0)) > MAX_SHELLS or int(raw.get("fishCrates", 0)) > FISH_CRATES:
		return false
	var stock = raw.get("inventory", {})
	if not stock is Dictionary:
		return false
	for item in stock:
		var count = stock[item]
		if (
			not ITEMS.has(str(item))
			or typeof(count) not in [TYPE_INT, TYPE_FLOAT]
			or float(count) < 0
			or float(count) > 99
			or float(count) != floorf(float(count))
		):
			return false
	var done = raw.get("rewarded", [])
	if not done is Array:
		return false
	for mission_id in done:
		if not mission_id is String or model.mission(mission_id).is_empty():
			return false
	var carry = raw.get("carry", {})
	if (
		not carry is Dictionary
		or (not carry.is_empty() and str(carry.get("kind", "")) not in ["fish", "delivery"])
	):
		return false
	var lesson = raw.get("pendingLesson", {})
	if not lesson is Dictionary:
		return false
	if not lesson.is_empty() and not _valid_request(lesson):
		return false
	if not model.restore(raw.get("quests", {})):
		return false
	for mission_id in done:
		if model.state(str(mission_id)) != "done":
			return false
	wallet = int(raw.get("wallet", START_SHELLS))
	inventory.clear()
	for item in stock:
		inventory[str(item)] = int(stock[item])
	rewarded.clear()
	for mission_id in done:
		rewarded.append(str(mission_id))
	fish_crates = int(raw.get("fishCrates", 0))
	delivery_index = int(raw.get("deliveryIndex", 0))
	deliveries_done = int(raw.get("deliveriesDone", 0))
	carrying = {}
	if not carry.is_empty():
		carrying = {"kind": str(carry.kind), "order": int(carry.get("order", -1))}
	pending_lesson = lesson.duplicate(true)
	return true


static func _valid_request(lesson: Dictionary) -> bool:
	var pattern := RegEx.new()
	pattern.compile("^[A-Za-z0-9_.:-]{8,160}$")
	if (
		lesson.get("version") != 1
		or lesson.get("id") != "school_numbers"
		or lesson.get("subject") != "Mathematik"
	):
		return false
	if lesson.get("returnGame") != "world" or not lesson.get("requestId") is String:
		return false
	if pattern.search(str(lesson.requestId)) == null:
		return false
	var grade = lesson.get("grade")
	return (
		typeof(grade) in [TYPE_INT, TYPE_FLOAT]
		and float(grade) == floorf(float(grade))
		and int(grade) in [1, 2, 3, 4]
	)


# --- Per frame -----------------------------------------------------------------------


func tick(at: Vector3, driving: bool, delta: float) -> void:
	if not unlocked() or bool(world.get("paused")):
		return
	var step := clampf(delta, 0.0, 0.1)
	var routines = world.open_world.routines if is_instance_valid(world.get("open_world")) else null
	if routines != null and routines.get("elapsed") != null:
		clock = float(routines.elapsed) * (DAY_SECONDS / (180.0 * 4.0))
	else:
		clock = fposmod(clock + step, DAY_SECONDS)
	hour = BRAIN.hour_of(clock, DAY_SECONDS)
	var in_region := region_contains(at)
	if in_region != was_in_region:
		was_in_region = in_region
		world._update_mission()
		if in_region:
			world.status_label.text = "Willkommen in Sonnenhafen! Die Bewohner sind Computerfiguren dieser Welt."
	crowd.tick(step, hour, at, driving)
	_sync_figures()
	inside = town.update_focus(at)
	town.tick(step, evening)
	_update_daylight(step)
	_update_crate()
	var target := tracked_route()
	if is_instance_valid(quest_marker):
		quest_marker.visible = not target.is_empty()
		if quest_marker.visible:
			quest_marker.position = target.at + Vector3.UP * 4.3
			if not bool(world.get("reduced_motion")):
				quest_marker.rotate_y(step * 0.9)
	observe_clock += step
	if observe_clock >= 0.25:
		observe_clock = 0.0
		var events: Array[Dictionary] = model.observe(at, driving)
		if not events.is_empty():
			_report(events)


func _sync_figures() -> void:
	for entry in model.content.figures:
		var live: Vector3 = crowd.position_of(str(entry.id))
		if live.is_finite():
			entry["position"] = live


## Evening light: the sun lowers and warms, windows and lamps glow.
func _capture_daylight() -> void:
	var sun := world.get_node_or_null("Sun") as DirectionalLight3D
	var environment := world.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if sun == null or environment == null or environment.environment == null:
		return
	var env := environment.environment
	daylight = {
		"sun": sun,
		"env": env,
		"rotation": sun.rotation_degrees,
		"color": sun.light_color,
		"energy": sun.light_energy,
		"ambient": env.ambient_light_energy,
		"ambient_color": env.ambient_light_color
	}
	var sky := env.sky.sky_material as ProceduralSkyMaterial if env.sky != null else null
	if sky != null:
		daylight["sky"] = sky
		daylight["top"] = sky.sky_top_color
		daylight["horizon"] = sky.sky_horizon_color


static func evening_target(at_hour: float) -> float:
	return smoothstep(17.6, 19.8, at_hour) * 0.92


func _update_daylight(step: float) -> void:
	var target := evening_target(hour)
	# A new day after the wrap brightens over a few seconds (sunrise).
	evening = move_toward(evening, target, step * (0.35 if target < evening else 0.08))
	if daylight.is_empty() or absf(evening - evening_applied) < 0.004:
		return
	evening_applied = evening
	var sun: DirectionalLight3D = daylight.sun
	sun.light_color = (daylight.color as Color).lerp(Color("ff9a5a"), evening)
	sun.light_energy = lerpf(float(daylight.energy), float(daylight.energy) * 0.38, evening)
	var rotation: Vector3 = daylight.rotation
	sun.rotation_degrees = Vector3(
		lerpf(rotation.x, -12.0, evening), rotation.y + evening * 40.0, rotation.z
	)
	var env: Environment = daylight.env
	env.ambient_light_energy = lerpf(
		float(daylight.ambient), float(daylight.ambient) * 0.55, evening
	)
	env.ambient_light_color = (daylight.ambient_color as Color).lerp(Color("6b5a9a"), evening * 0.6)
	if daylight.has("sky"):
		var sky: ProceduralSkyMaterial = daylight.sky
		sky.sky_top_color = (daylight.top as Color).lerp(Color("3a2f6e"), evening)
		sky.sky_horizon_color = (daylight.horizon as Color).lerp(Color("f2a06a"), evening)
	VILLAGE.material().set_shader_parameter("night", clampf((evening - 0.25) / 0.6, 0.0, 1.0))


func _build_markers() -> void:
	quest_marker = MeshInstance3D.new()
	quest_marker.name = "SonnenhafenQuestMarker"
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * 0.7
	quest_marker.mesh = mesh
	quest_marker.material_override = world.kit.material(Color("ffd27a"), true)
	quest_marker.rotation = Vector3(PI * 0.25, 0, PI * 0.25)
	quest_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(quest_marker)
	quest_marker.hide()
	carried_crate = MeshInstance3D.new()
	carried_crate.name = "CarriedCrate"
	var crate := BoxMesh.new()
	crate.size = Vector3(0.8, 0.6, 0.6)
	carried_crate.mesh = crate
	carried_crate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(carried_crate)
	carried_crate.hide()


func _update_crate() -> void:
	carried_crate.visible = not carrying.is_empty() and not bool(world.get("driving"))
	if carried_crate.visible:
		carried_crate.position = world.player.position + Vector3.UP * 3.05
		carried_crate.rotation.y = world.fox.rotation.y
		var color := (
			Color("c9a46a")
			if str(carrying.kind) == "fish"
			else Color(str(ORDERS[_order_index()].color))
		)
		if not carried_crate.has_meta("color") or carried_crate.get_meta("color") != color:
			carried_crate.set_meta("color", color)
			carried_crate.material_override = world.kit.material(color)


func _order_index() -> int:
	return posmod(int(carrying.get("order", delivery_index)), ORDERS.size())


# --- Interaction ---------------------------------------------------------------------


## Text for the World's action button when Sonnenhafen offers something here,
## or "" when nothing is in reach.
func action_label(at: Vector3) -> String:
	if not unlocked() or bool(world.get("driving")) or not region_contains(at):
		return ""
	if _near_spot(at, "fish_hall", CRATE_REACH + 2.0) and str(carrying.get("kind", "")) == "fish":
		return "Kiste abstellen"
	if _fish_step_active() and carrying.is_empty() and _near_spot(at, "pier_west_end", CRATE_REACH):
		return "Kiste nehmen"
	if not crowd.nearest(at, TALK_REACH).is_empty():
		return "Ansprechen"
	if _near_spot(at, "trade_spot_shop", TRADE_REACH):
		return "Handeln"
	if _near_spot(at, "kontor_board", TRADE_REACH):
		return "Lieferbrett"
	return ""


func _near_spot(at: Vector3, spot_id: String, reach: float) -> bool:
	var spot: Vector3
	if spot_id == "trade_spot_shop":
		var room: Dictionary = layout.data.interiors.hafenkraemer
		spot = Vector3(float(room.trade_spot[0]), 0, float(room.trade_spot[1]))
	else:
		spot = layout.spot(spot_id)
	return spot.is_finite() and Vector2(at.x - spot.x, at.z - spot.z).length() <= reach


func _fish_step_active() -> bool:
	return str(model.current_step("frischer_fang").get("id", "")) == "carry_crates"


func interact(at: Vector3) -> bool:
	match action_label(at):
		"Kiste abstellen":
			_drop_fish()
		"Kiste nehmen":
			carrying = {"kind": "fish"}
			_commit(
				(
					"Du trägst eine Fischkiste. Bring sie in die Fischhalle (%d/%d)."
					% [fish_crates, FISH_CRATES]
				)
			)
		"Ansprechen":
			_talk(crowd.nearest(at, TALK_REACH))
		"Handeln":
			open_shop()
		"Lieferbrett":
			open_board()
		_:
			return false
	return true


func _drop_fish() -> void:
	carrying = {}
	fish_crates = mini(FISH_CRATES, fish_crates + 1)
	world.fox.gesture("celebrate")
	if fish_crates >= FISH_CRATES:
		_report(_event_results("fish_crates_done"))
	else:
		_commit(
			(
				"Kiste abgestellt: %d von %d. Hol die nächste am Fischerpier."
				% [fish_crates, FISH_CRATES]
			)
		)


func _event_results(event_id: String) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for result in model.notify_event(event_id):
		results.append(
			{
				"type": "step",
				"mission": str(result.mission),
				"step": result.step,
				"cards": result.cards,
				"done": result.done
			}
		)
	return results


func _commit(message: String) -> void:
	world._update_mission()
	world.status_label.text = message
	if not world._save():
		world.status_label.text = (
			message + " Speichern ist noch nicht möglich; wir versuchen es gleich erneut."
		)


## Mission events: messages, rewards for finished missions (exactly once),
## memories of the residents who were helped, and new figure cards.
func _report(events: Array[Dictionary]) -> void:
	var messages: Array[String] = []
	var cards: Array[String] = []
	for event in events:
		if str(event.get("type", "")) == "discovered":
			messages.append(
				"Neuer Ort in Sonnenhafen: " + str(model.place(str(event.place)).title) + "."
			)
			continue
		var mission_id := str(event.mission)
		var mission: Dictionary = model.mission(mission_id)
		if bool(event.done):
			messages.append(str(mission.title) + ": Auftrag geschafft! " + _grant(mission_id))
		else:
			messages.append(
				(
					str(mission.title)
					+ ": Gut gemacht! Weiter: "
					+ str(model.current_step(mission_id).get("lead", ""))
				)
			)
		for card_id in event.get("cards", []):
			cards.append(str(card_id))
	_commit(" ".join(messages))
	if not cards.is_empty():
		_show_cards(cards)


func _grant(mission_id: String) -> String:
	if mission_id in rewarded:
		return ""
	rewarded.append(mission_id)
	var mission: Dictionary = model.mission(mission_id)
	var reward: Dictionary = mission.get("reward", {})
	var shells := int(reward.get("shells", 0))
	wallet = mini(MAX_SHELLS, wallet + shells)
	var parts: Array[String] = []
	if shells > 0:
		parts.append("+%d Muscheln" % shells)
	var items: Dictionary = reward.get("items", {})
	for item in items:
		inventory[str(item)] = mini(99, int(inventory.get(str(item), 0)) + int(items[item]))
		parts.append(
			"+%d %s" % [int(items[item]), str(ITEMS.get(str(item), {}).get("title", item))]
		)
	var giver := str(mission.get("giver", ""))
	var brain = crowd.brain_of(giver)
	if brain != null:
		brain.remember("helped", brain.first_name(), str(mission.title))
	world.fox.gesture("celebrate")
	if is_instance_valid(world.get("wonder")):
		world.wonder.celebrate(world.player.position + Vector3.UP * 1.6)
	return "Belohnung: " + ", ".join(parts) + "." if not parts.is_empty() else ""


# --- Conversations ---------------------------------------------------------------------


func _talk(figure_id: String) -> void:
	if figure_id.is_empty():
		return
	dialog_figure = figure_id
	var brain = crowd.brain_of(figure_id)
	if brain != null:
		brain.remember("met")
	var steps: Array[Dictionary] = model.steps_for_figure(figure_id)
	if not steps.is_empty():
		dialog_mission = str(steps[0].mission)
		dialog_step = str(steps[0].step.id)
		runner = DIALOG.new(
			model.dialog(str(steps[0].step.dialog)), int(world.grade), model.cards()
		)
	else:
		dialog_mission = ""
		dialog_step = ""
		runner = DIALOG.new(smalltalk_tree(figure_id), int(world.grade), [])
	_render()


func _home_place(address: String) -> String:
	if address.ends_with("canal") or address.contains("_canal:"):
		return "an der Kanalpromenade"
	if address.contains("_quay:"):
		return "am Kai"
	if address.contains("_lane:"):
		return "in der Laternengasse"
	return "in Sonnenhafen"


## Conversation for a resident without a pending mission step: who they are
## (honestly a computer figure), their day, interests, friends and memories.
func smalltalk_tree(figure_id: String) -> Dictionary:
	var brain = crowd.brain_of(figure_id)
	var profile: Dictionary = brain.profile
	var greeting: String = brain.memory_line()
	if greeting.is_empty():
		var greetings: Array = profile.get("greetings", ["Hallo, Lumo!"])
		greeting = str(greetings[posmod(int(clock), greetings.size())])
	var day: Array[String] = ["So sieht mein Tag aus:"]
	for phase in BRAIN.PHASES:
		var titles: Array[String] = []
		for entry in profile.get("schedule", {}).get(phase, []):
			titles.append(str(entry.activity))
		day.append("%s: %s." % [phase, ", ".join(titles.slice(0, 2))])
	var friends: Array[String] = []
	for other in profile.get("relations", {}):
		var other_brain = crowd.brain_of(str(other))
		if other_brain != null:
			friends.append(
				(
					"%s (%s)"
					% [other_brain.first_name(), str(profile.relations[other].get("kind", ""))]
				)
			)
	var interests: Array = profile.get("interests", [])
	return {
		"start": "hello",
		"nodes":
		{
			"hello":
			{
				"text": greeting + "\nGerade: " + brain.status_text() + ".",
				"choices":
				[
					{"label": "Wer bist du?", "next": "who"},
					{"label": "Wie sieht dein Tag aus?", "next": "day"},
					{"label": "Was magst du?", "next": "likes"},
					{"label": "Tschüss!", "action": "close"}
				]
			},
			"who":
			{
				"text":
				(
					"Ich bin %s, %s. Ich wohne %s und bin %s. Ich bin eine Computerfigur dieser Welt – keine echte Person und kein Online-Mitspieler."
					% [
						str(profile.name),
						str(profile.role),
						_home_place(str(profile.get("home", ""))),
						str(profile.get("traits", ""))
					]
				),
				"choices":
				[
					{"label": "Wen kennst du hier?", "next": "friends"},
					{"label": "Zurück", "next": "hello"}
				]
			},
			"friends":
			{
				"text":
				(
					"Meine Leute in Sonnenhafen: "
					+ (", ".join(friends) if not friends.is_empty() else "fast alle!")
					+ "."
				),
				"choices": [{"label": "Zurück", "next": "hello"}]
			},
			"day":
			{
				"text": "\n".join(day) + "\nDu kannst mich jederzeit ansprechen.",
				"choices": [{"label": "Zurück", "next": "hello"}]
			},
			"likes":
			{
				"text": "Ich interessiere mich für " + ", ".join(interests) + ".",
				"choices":
				[
					{"label": "Zurück", "next": "hello"},
					{"label": "Weiter erkunden", "action": "close"}
				]
			}
		}
	}


func _render() -> void:
	var view: Dictionary = runner.view()
	if view.is_empty():
		_end_conversation()
		return
	var brain = crowd.brain_of(dialog_figure)
	var title := "%s · Computerfigur" % str(brain.profile.name)
	if not dialog_mission.is_empty():
		title = "%s · %s" % [str(brain.profile.name), str(model.mission(dialog_mission).title)]
	world._open_dialog(title, str(view.text))
	world.modal.set_meta("sonnenhafen_dialog", str(view.id))
	for choice in view.choices:
		var button: Button = KIT.button(
			str(choice.label), _choose.bind(int(choice.index)), 200, Color("1b7d63")
		)
		button.name = "HarbourChoice_%d" % int(choice.index)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		world.modal_box.add_child(button)
	_extra_buttons()


func _extra_buttons() -> void:
	var order: Dictionary = (
		ORDERS[_order_index()] if str(carrying.get("kind", "")) == "delivery" else {}
	)
	if not order.is_empty() and str(order.to) == dialog_figure:
		var hand := KIT.button(
			"Lieferung übergeben: " + str(order.goods), _hand_over, 200, Color("b8762a")
		)
		hand.name = "HarbourHandOver"
		world.modal_box.add_child(hand)
	elif not order.is_empty():
		world.modal_box.add_child(
			KIT.label(
				(
					"Diese Kiste ist nicht für mich. Lies den Lieferzettel noch einmal: "
					+ str(order.address)
				),
				16
			)
		)
	if (
		dialog_figure == "greta"
		and str(model.current_step("waren_berechnen").get("id", "")) == "world_school"
	):
		var school := KIT.button(
			"Lernrunde in Lumos Weltschule", start_lesson, 200, Color("1b7d63")
		)
		school.name = "HarbourLesson"
		world.modal_box.add_child(school)
	if dialog_figure == "greta" and _shop_open():
		world.modal_box.add_child(KIT.button("Handeln", open_shop, 200, Color("6652b8")))
	if dialog_mission.is_empty() and not model.steps_for_figure(dialog_figure).is_empty():
		world.modal_box.add_child(KIT.button("Zum Auftrag", _resume_mission, 200, Color("1b7d63")))


func _resume_mission() -> void:
	_talk(dialog_figure)


func _choose(index: int) -> void:
	if runner == null:
		return
	match runner.choose(index):
		"next":
			_render()
		"close":
			_end_conversation()
		"complete":
			if dialog_mission.is_empty():
				_end_conversation()
				return
			var mission_id := dialog_mission
			var result: Dictionary = model.complete(
				mission_id, dialog_step, world.player.position, bool(world.driving)
			)
			_end_conversation()
			if not bool(result.ok):
				world.status_label.text = "Komm noch etwas näher und sprich in Ruhe mit der Figur."
				return
			world.fox.gesture("celebrate")
			var events: Array[Dictionary] = [
				{"type": "step", "mission": mission_id, "cards": result.cards, "done": result.done}
			]
			_report(events)


func _end_conversation() -> void:
	runner = null
	dialog_mission = ""
	dialog_step = ""
	if world.modal.has_meta("sonnenhafen_dialog"):
		world.modal.remove_meta("sonnenhafen_dialog")
	world._close_dialog()


func _show_cards(card_ids: Array[String]) -> void:
	var names: Array[String] = []
	for card_id in card_ids:
		names.append(str(model.figure(str(model.card(card_id).figure)).name))
	world._open_dialog(
		"Neue Figurenkarte!", "In deinem Sonnenhafen-Album: " + ", ".join(names) + "."
	)
	for card_id in card_ids:
		world.modal_box.add_child(card_panel(card_id, true))
	world.modal_box.add_child(
		KIT.button("Weiter erkunden", world._close_dialog, 180, Color("1b7d63"))
	)


func card_panel(card_id: String, owned: bool) -> PanelContainer:
	var card: Dictionary = model.card(card_id)
	var entry: Dictionary = model.figure(str(card.figure))
	var panel := PanelContainer.new()
	panel.name = "HarbourCard_" + card_id
	panel.custom_minimum_size = Vector2(150, 120)
	panel.add_theme_stylebox_override(
		"panel",
		KIT.tinted_panel(
			Color("2a3d52") if owned else Color("1a2b38"),
			Color("ffd27a") if owned else Color("3d5566"),
			14
		)
	)
	var box := VBoxContainer.new()
	panel.add_child(box)
	box.add_child(KIT.label(str(entry.name) if owned else "???", 18))
	var lines: Array = (
		["Computerfigur · " + str(entry.role), "Stärke: " + str(card.power), str(card.trait)]
		if owned
		else ["Noch nicht gesammelt"]
	)
	for line in lines:
		var text := KIT.label(str(line), 14)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size.x = 132
		box.add_child(text)
	return panel


# --- Shop ---------------------------------------------------------------------------------


func _shop_open() -> bool:
	var keeper: Vector3 = crowd.position_of("greta")
	var room: Rect2 = layout.interior_rects.get("hafenkraemer", Rect2())
	return keeper.is_finite() and room.has_point(Vector2(keeper.x, keeper.z))


func open_shop(message := "") -> void:
	runner = null
	if not _shop_open():
		var brain = crowd.brain_of("greta")
		(
			world
			. _open_dialog(
				"Hafenkrämer",
				(
					"Greta ist gerade nicht im Laden (%s). Sie kommt bald zurück. Auf der Weltkarte siehst du, wo sie ist."
					% (brain.status_text() if brain != null else "unterwegs")
				)
			)
		)
		world.modal_box.add_child(
			KIT.button("Weiter erkunden", world._close_dialog, 180, Color("1b7d63"))
		)
		return
	var body := (
		"Du hast %d Muscheln. Muscheln sind Spielmünzen dieser Welt, kein echtes Geld." % wallet
	)
	if not message.is_empty():
		body = message + "\n" + body
	world._open_dialog("Hafenkrämer · Greta", body)
	world.modal.set_meta("sonnenhafen_shop", true)
	world.modal_box.add_child(KIT.label("Kaufen", 20))
	for item in ["seil", "laternenglas", "broetchen", "muschelkette", "kompass", "fisch"]:
		var info: Dictionary = ITEMS[item]
		var button: Button = KIT.button(
			"%s · %d Muscheln" % [str(info.title), int(info.buy)],
			buy.bind(item),
			200,
			Color("1b7d63")
		)
		button.name = "Buy_" + item
		button.disabled = wallet < int(info.buy)
		world.modal_box.add_child(button)
	var sellable := false
	for item in inventory:
		var info: Dictionary = ITEMS.get(str(item), {})
		if int(inventory[item]) <= 0 or int(info.get("sell", 0)) <= 0:
			continue
		if not sellable:
			world.modal_box.add_child(KIT.label("Verkaufen", 20))
			sellable = true
		var button: Button = KIT.button(
			(
				"%s (%d im Korb) · bekommst %d"
				% [str(info.title), int(inventory[item]), int(info.sell)]
			),
			sell.bind(str(item)),
			200,
			Color("6652b8")
		)
		button.name = "Sell_" + str(item)
		world.modal_box.add_child(button)
	world.modal_box.add_child(KIT.label("Dein Hafenkorb: " + basket_text(), 16))
	world.modal_box.add_child(KIT.button("Fertig", _close_shop, 160))


func _close_shop() -> void:
	if world.modal.has_meta("sonnenhafen_shop"):
		world.modal.remove_meta("sonnenhafen_shop")
	world._close_dialog()


func basket_text() -> String:
	var parts: Array[String] = []
	for item in ITEMS:
		if int(inventory.get(item, 0)) > 0:
			parts.append("%d × %s" % [int(inventory[item]), str(ITEMS[item].title)])
	return ", ".join(parts) if not parts.is_empty() else "noch leer"


## Buying is only possible with enough shells; the calculation is shown.
func buy(item: String) -> bool:
	var info: Dictionary = ITEMS.get(item, {})
	var price := int(info.get("buy", 0))
	if price <= 0 or wallet < price or not _shop_open():
		return false
	var before := wallet
	wallet -= price
	inventory[item] = mini(99, int(inventory.get(item, 0)) + 1)
	var brain = crowd.brain_of("greta")
	if brain != null:
		brain.remember("traded", "Greta")
	var results := _event_results("bought_" + item)
	_save_quietly()
	open_shop("Gekauft: %s. %d − %d = %d Muscheln." % [str(info.title), before, price, wallet])
	if not results.is_empty():
		_report(results)
		open_shop("Gekauft: %s. %d − %d = %d Muscheln." % [str(info.title), before, price, wallet])
	return true


func sell(item: String) -> bool:
	var info: Dictionary = ITEMS.get(item, {})
	var price := int(info.get("sell", 0))
	if price <= 0 or int(inventory.get(item, 0)) <= 0 or not _shop_open():
		return false
	var before := wallet
	inventory[item] = int(inventory[item]) - 1
	wallet = mini(MAX_SHELLS, wallet + price)
	_save_quietly()
	open_shop("Verkauft: %s. %d + %d = %d Muscheln." % [str(info.title), before, price, wallet])
	return true


func _save_quietly() -> void:
	world._update_mission()
	world._save()


# --- Kontor deliveries ---------------------------------------------------------------------


func open_board(message := "") -> void:
	runner = null
	var body := (
		"Lieferaufträge von Hinnerk. Lies den Zettel genau und bring die Kiste zur richtigen Person. Erledigt: %d."
		% deliveries_done
	)
	if not message.is_empty():
		body = message + "\n" + body
	world._open_dialog("Lieferbrett im Kontor", body)
	if not carrying.is_empty():
		var current: String = (
			"eine Fischkiste" if str(carrying.kind) == "fish" else str(ORDERS[_order_index()].goods)
		)
		world.modal_box.add_child(
			KIT.label(
				"Du trägst schon %s. Erst abliefern, dann den nächsten Auftrag nehmen." % current,
				17
			)
		)
		if str(carrying.kind) == "delivery":
			var order: Dictionary = ORDERS[_order_index()]
			world.modal_box.add_child(KIT.label("Lieferzettel: " + str(order.address), 17))
			world.modal_box.add_child(
				KIT.button("Ziel auf der Karte verfolgen", _track_delivery, 200, Color("1b7d63"))
			)
			world.modal_box.add_child(KIT.button("Kiste zurückstellen", _cancel_delivery, 200))
	else:
		for offset in range(3):
			var index := posmod(delivery_index + offset, ORDERS.size())
			var order: Dictionary = ORDERS[index]
			var slip := KIT.label(
				(
					"Zettel %d: %s. %s Lohn: %d Muscheln."
					% [
						offset + 1,
						str(order.goods).capitalize(),
						str(order.address),
						int(order.reward)
					]
				),
				16
			)
			slip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			world.modal_box.add_child(slip)
			var take: Button = KIT.button(
				"Auftrag %d nehmen" % (offset + 1), take_order.bind(index), 200, Color("b8762a")
			)
			take.name = "TakeOrder_%d" % offset
			world.modal_box.add_child(take)
	world.modal_box.add_child(KIT.button("Fertig", world._close_dialog, 160))


func take_order(index: int) -> bool:
	if not carrying.is_empty():
		return false
	carrying = {"kind": "delivery", "order": posmod(index, ORDERS.size())}
	tracked_delivery = true
	world._close_dialog()
	var order: Dictionary = ORDERS[_order_index()]
	_commit("Lieferung: %s. %s" % [str(order.goods), str(order.address)])
	return true


func _track_delivery() -> void:
	tracked_delivery = true
	world._close_dialog()


func _cancel_delivery() -> void:
	carrying = {}
	tracked_delivery = false
	world._close_dialog()
	_commit("Die Kiste steht wieder im Kontor. Du kannst jederzeit einen neuen Auftrag nehmen.")


func _hand_over() -> void:
	if str(carrying.get("kind", "")) != "delivery":
		return
	var index := _order_index()
	var order: Dictionary = ORDERS[index]
	if str(order.to) != dialog_figure:
		return
	carrying = {}
	tracked_delivery = false
	wallet = mini(MAX_SHELLS, wallet + int(order.reward))
	deliveries_done += 1
	delivery_index = posmod(index + 1, ORDERS.size())
	var brain = crowd.brain_of(dialog_figure)
	if brain != null:
		brain.remember("delivered", brain.first_name(), str(order.goods))
		brain.say("Danke für die Lieferung!", 3.0)
	_end_conversation()
	world.fox.gesture("celebrate")
	var results := _event_results("delivery_done")
	var message := (
		"Geliefert: %s an %s. +%d Muscheln (jetzt %d)."
		% [str(order.goods), brain.first_name() if brain != null else "", int(order.reward), wallet]
	)
	if results.is_empty():
		_commit(message)
	else:
		world.status_label.text = message
		_report(results)


# --- Learning round ------------------------------------------------------------------------------


## Uses the existing Lumo World learning bridge: the app runs three assessed
## tasks in "Lumos Weltschule" and returns a receipt with this request id.
func start_lesson() -> void:
	if str(model.current_step("waren_berechnen").get("id", "")) != "world_school":
		return
	var grade := clampi(int(world.grade), 1, 4)
	if pending_lesson.is_empty() or int(pending_lesson.get("grade", 0)) != grade:
		pending_lesson = {
			"version": 1,
			"id": "school_numbers",
			"requestId": "harbour_" + str(HostBridge.new_result_id()),
			"subject": "Mathematik",
			"grade": grade,
			"returnGame": "world"
		}
	if not world._save():
		world.status_label.text = "Die Lernrunde konnte noch nicht gespeichert werden. Bitte versuche es erneut."
		return
	if HostBridge.is_embedded():
		if not HostBridge.return_to_app("learn", {"worldMission": pending_lesson.duplicate(true)}):
			world.status_label.text = "Die Weltschule ist bereit. Der Wechsel zur Lernrunde hat noch nicht geklappt."
		return
	lesson_index = 0
	lesson_correct = 0
	_show_lesson_task()


func _show_lesson_task() -> void:
	runner = null
	var grade := clampi(int(world.grade), 1, 4)
	var terms: Array = LESSON_SETS[grade - 1][lesson_index]
	world._open_dialog(
		"Lumos Weltschule · Aufgabe %d von 3" % (lesson_index + 1),
		"Wie viel ist %d + %d?" % [terms[0], terms[1]]
	)
	var answer: int = int(terms[0]) + int(terms[1])
	for value in [answer - 1, answer, answer + 1]:
		world.modal_box.add_child(
			KIT.button(str(value), _lesson_answer.bind(int(value), answer), 160)
		)
	world.modal_box.add_child(KIT.button("Später weitermachen", world._close_dialog, 160))


func _lesson_answer(value: int, expected: int) -> void:
	if value != expected:
		world.status_label.text = "Zerlege die Zahlen in passende Teile und rechne noch einmal in Ruhe."
		return
	lesson_correct += 1
	lesson_index += 1
	if lesson_index < 3:
		_show_lesson_task()
		return
	var receipt := {
		"version": 1,
		"requestId": str(pending_lesson.get("requestId", "")),
		"missionId": "school_numbers",
		"completed": true,
		"subject": "Mathematik",
		"grade": int(pending_lesson.get("grade", 0)),
		"returnGame": "world"
	}
	world._close_dialog()
	consume_learning_receipt(receipt)


## True when the returning receipt belongs to the harbour learning round.
func consume_learning_receipt(receipt: Variant) -> bool:
	if not unlocked() or pending_lesson.is_empty() or not receipt is Dictionary:
		return false
	if typeof(receipt.get("completed")) != TYPE_BOOL or receipt.get("completed") != true:
		return false
	if str(receipt.get("requestId", "")) != str(pending_lesson.get("requestId", "")):
		return false
	if receipt.get("missionId") != "school_numbers" or receipt.get("version") != 1:
		return false
	if receipt.get("subject") != "Mathematik" or receipt.get("returnGame") != "world":
		return false
	if receipt.get("grade") != pending_lesson.get("grade"):
		return false
	pending_lesson.clear()
	var results := _event_results("harbour_lesson_done")
	if results.is_empty():
		return false
	_report(results)
	return true


# --- Guidance, map, journal ---------------------------------------------------------------------


func tracked_route() -> Dictionary:
	if not unlocked():
		return {}
	if str(carrying.get("kind", "")) == "delivery" and tracked_delivery:
		var order: Dictionary = ORDERS[_order_index()]
		return {
			"id": "delivery:" + str(order.to),
			"at": crowd.position_of(str(order.to)),
			"title": "Lieferung",
			"lead": str(order.address)
		}
	if str(carrying.get("kind", "")) == "fish":
		return {
			"id": "fish_hall",
			"at": layout.spot("fish_hall"),
			"title": "Frischer Fang",
			"lead": "Bring die Kiste in die Fischhalle."
		}
	return model.tracked_target()


func hud_line() -> String:
	if not unlocked():
		return ""
	var done := 0
	for mission_id in model.mission_ids():
		if model.state(mission_id) == "done":
			done += 1
	var line := "⚓ Sonnenhafen %d/%d · %d Muscheln" % [done, model.mission_ids().size(), wallet]
	var target := tracked_route()
	if not target.is_empty():
		line += " · " + str(target.lead)
	return line


func follow(mission_id: String) -> void:
	if model.track(mission_id):
		world._close_dialog()
		_commit(
			(
				"Du verfolgst jetzt: "
				+ str(model.mission(mission_id).title)
				+ ". Der goldene Marker zeigt dir das Ziel."
			)
		)


func append_journal() -> void:
	if not is_instance_valid(world.modal_box):
		return
	var section := VBoxContainer.new()
	section.name = "SonnenhafenJournal"
	section.add_theme_constant_override("separation", 8)
	section.add_child(KIT.label("Sonnenhafen · %d Muscheln" % wallet, 20))
	for mission_id in model.mission_ids():
		var entry: Dictionary = model.mission(mission_id)
		var state: String = model.state(mission_id)
		var status := (
			"Geschafft"
			if state == "done"
			else (
				"Schritt %d/%d: %s"
				% [
					int(model.progress[mission_id]) + 1,
					entry.steps.size(),
					str(model.current_step(mission_id).lead)
				]
			)
		)
		var line := KIT.label("%s (%s)\n%s" % [str(entry.title), str(entry.subject), status], 16)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.name = "HarbourMission_" + mission_id
		section.add_child(line)
		if state != "done":
			var button: Button = KIT.button(
				"Wird verfolgt" if model.tracked == mission_id else "Verfolgen",
				follow.bind(mission_id),
				180
			)
			button.name = "HarbourFollow_" + mission_id
			button.disabled = model.tracked == mission_id
			section.add_child(button)
	section.add_child(KIT.label("Hafenkorb: " + basket_text(), 16))
	var album := HFlowContainer.new()
	album.add_theme_constant_override("h_separation", 10)
	album.add_theme_constant_override("v_separation", 10)
	for card in model.content.cards:
		album.add_child(card_panel(str(card.id), str(card.id) in model.cards()))
	section.add_child(album)
	world.modal_box.add_child(section)
	var count: int = world.modal_box.get_child_count()
	if count >= 2:
		world.modal_box.move_child(section, count - 2)


func map_places() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.append(
		{
			"id": "sonnenhafen",
			"title": "Sonnenhafen",
			"at": Vector3(173, 0, -150),
			"view": Rect2(60, -232, 230, 140)
		}
	)
	for place in model.content.places:
		var at: Vector3 = place.position
		result.append(
			{
				"id": "sh_" + str(place.id),
				"title": str(place.title),
				"at": at,
				"view": Rect2(at.x - 40, at.z - 30, 80, 60)
			}
		)
	return result


func map_paths() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for path in model.content.paths:
		var points: Array = path.points
		for index in range(points.size() - 1):
			result.append(
				{
					"from": Vector3(float(points[index][0]), 0, float(points[index][1])),
					"to": Vector3(float(points[index + 1][0]), 0, float(points[index + 1][1]))
				}
			)
	return result


func map_lands() -> Array[Rect2]:
	return [layout.platform(), Rect2(255, -225, 10, 50)]


func map_figures() -> Array[Dictionary]:
	return crowd.map_figures() if is_instance_valid(crowd) else []
