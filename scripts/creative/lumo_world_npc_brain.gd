extends RefCounted
## Daily life of one computer-controlled resident (utility AI on a small state
## machine). The brain decides WHAT a resident does and WHERE; the crowd node
## moves the body along the navigation mesh and reports arrival. Everything is
## local and deterministic per resident id: no network, no cloud model.
##
## States: IDLE (doing an activity at a spot), WALK (on the way), TALK (chat with
## another resident), GREET (short reaction to Lumo), HOME (inside the house).
## Needs: social rises while alone; recently used spots lose appeal, so nobody
## stands still all day or repeats the same walk forever.

enum State { IDLE, WALK, TALK, GREET, HOME }

const PHASES: Array[String] = ["Morgen", "Mittag", "Nachmittag", "Abend"]
const DAY_START := 8.0
const DAY_END := 22.0
const HOME_HOUR := 20.0
const MEMORY_LIMIT := 8
const RECENT_LIMIT := 4
const GREET_RANGE := 4.5
const GREET_COOLDOWN := 22.0
const CHAT_RANGE := 30.0
const STATE_NAMES := ["Arbeitet", "Unterwegs", "Im Gespräch", "Grüßt", "Zu Hause"]

var id := ""
var profile: Dictionary = {}
var state := State.IDLE
var spot := ""
var activity := ""
var timer := 0.0
var social := 0.3
var recent: Array[String] = []
var memory: Array[Dictionary] = []
var affinity: Dictionary = {}
var partner := ""
var talk_lines: Array[String] = []
var bubble := ""
var bubble_timer := 0.0
var greet_cooldown := 0.0
var resume_state := State.IDLE
var resume_timer := 0.0
var plans_made := 0
var rng := RandomNumberGenerator.new()


func _init(entry: Dictionary = {}) -> void:
	profile = entry
	id = str(entry.get("id", ""))
	rng.seed = id.hash() & 0x7fffffff
	social = 0.2 + rng.randf() * 0.3
	for other in entry.get("relations", {}):
		affinity[str(other)] = clampf(float(entry.relations[other].get("affinity", 0.5)), 0.0, 1.0)


static func hour_of(elapsed: float, day_seconds: float) -> float:
	var t := fposmod(elapsed, day_seconds) / day_seconds
	return DAY_START + t * (DAY_END - DAY_START)


static func phase_of(hour: float) -> int:
	return clampi(int((hour - DAY_START) / ((DAY_END - DAY_START) / 4.0)), 0, 3)


func first_name() -> String:
	return str(profile.get("name", id)).split(" ")[0]


func personality(trait_name: String) -> float:
	return float(profile.get("personality", {}).get(trait_name, 0.5))


func is_busy() -> bool:
	return state in [State.TALK, State.GREET]


func awake(hour: float) -> bool:
	return state != State.HOME and hour < DAY_END


## Next plan from the schedule of the current phase. friends_near lists ids of
## residents that are close, awake and free right now.
func plan(hour: float, friends_near: Array = [], distance_of: Callable = Callable()) -> Dictionary:
	plans_made += 1
	var phase := phase_of(hour)
	if hour >= HOME_HOUR - float(profile.get("home_early", 0.0)):
		return {"kind": "home", "spot": "home", "title": "Feierabend zu Hause", "duration": 0.0}
	var entries: Array = profile.get("schedule", {}).get(PHASES[phase], [])
	var best := {}
	var best_score := -1.0
	for entry in entries:
		var spot_id := str(entry.get("spot", ""))
		var score := float(entry.get("weight", 1.0))
		var trait_name := str(entry.get("trait", ""))
		if not trait_name.is_empty():
			score *= 0.6 + personality(trait_name)
		if spot_id == spot:
			# A new activity always takes the resident somewhere else.
			score *= 0.0 if entries.size() > 1 else 0.2
		elif spot_id in recent:
			score *= 0.55
		if distance_of.is_valid():
			# Nearby tasks are preferred; far errands still happen sometimes.
			score *= clampf(1.25 - float(distance_of.call(spot_id)) / 110.0, 0.35, 1.25)
		score += rng.randf() * 0.45
		if score > best_score:
			best_score = score
			best = entry
	for friend in friends_near:
		var bond := float(affinity.get(str(friend), 0.0))
		if bond < 0.35:
			continue
		var score := 2.4 * social * bond * (0.6 + personality("social"))
		if score > best_score:
			best_score = score
			best = {"chat": str(friend)}
	if best.has("chat"):
		return {
			"kind": "chat",
			"partner": str(best.chat),
			"title": "Plaudern",
			"duration": 9.0 + rng.randf() * 5.0
		}
	if best.is_empty():
		return {"kind": "activity", "spot": "home", "title": "Kurz nach Hause", "duration": 12.0}
	var low := float(best.get("min", 18.0))
	var high := float(best.get("max", 40.0))
	var duration := lerpf(low, high, rng.randf()) * (0.85 + personality("calm") * 0.4)
	return {
		"kind": "activity",
		"spot": str(best.spot),
		"title": str(best.get("activity", "")),
		"duration": duration
	}


## Applies a plan; the crowd resolves the spot to a world position.
func begin(plan_data: Dictionary) -> void:
	match str(plan_data.get("kind", "")):
		"chat":
			partner = str(plan_data.partner)
			activity = "Plaudert mit " + str(plan_data.get("partner_name", partner))
			spot = ""
			state = State.WALK
			timer = float(plan_data.duration)
		_:
			if not spot.is_empty():
				recent.push_front(spot)
				if recent.size() > RECENT_LIMIT:
					recent.pop_back()
			spot = str(plan_data.spot)
			activity = str(plan_data.title)
			timer = float(plan_data.duration)
			partner = ""
			state = State.WALK


## Small working walk inside the current spot (fetching, carrying, looking),
## so a long activity is never spent standing on one point.
func shuffle() -> bool:
	if state != State.IDLE or spot == "home" or timer < 5.0:
		return false
	state = State.WALK
	return true


func arrived() -> void:
	if state != State.WALK:
		return
	if spot == "home" and activity == "Feierabend zu Hause":
		state = State.HOME
		say("Gute Nacht!", 2.0)
		return
	state = State.TALK if not partner.is_empty() else State.IDLE


## Advances timers. Returns true when the resident needs a new plan.
func tick(delta: float, hour: float) -> bool:
	var step := clampf(delta, 0.0, 0.25)
	greet_cooldown = maxf(0.0, greet_cooldown - step)
	if bubble_timer > 0.0:
		bubble_timer -= step
		if bubble_timer <= 0.0:
			bubble = ""
	var home_hour := HOME_HOUR - float(profile.get("home_early", 0.0))
	var needs_plan := false
	if state in [State.IDLE, State.WALK, State.TALK] and hour >= home_hour and spot != "home":
		# Evening: end the current activity and head home.
		partner = ""
		talk_lines.clear()
		return true
	match state:
		State.HOME:
			if hour < HOME_HOUR - 0.5 and hour >= DAY_START:
				state = State.IDLE
				spot = "home"
				timer = 0.0
				needs_plan = true
		State.GREET:
			resume_timer -= step
			if resume_timer <= 0.0:
				state = resume_state
		State.TALK:
			social = maxf(0.0, social - step * 0.08)
			timer -= step
			if timer <= 0.0:
				partner = ""
				talk_lines.clear()
				needs_plan = true
		State.IDLE:
			social = minf(1.0, social + step * 0.012 * (0.5 + personality("social")))
			timer -= step
			needs_plan = timer <= 0.0
		State.WALK:
			social = minf(1.0, social + step * 0.006)
	return needs_plan


## Short reaction when Lumo comes close. Returns the greeting or "".
func greet(lumo_known: bool) -> String:
	if state in [State.HOME, State.TALK, State.GREET] or greet_cooldown > 0.0:
		return ""
	resume_state = state
	resume_timer = 2.6
	state = State.GREET
	greet_cooldown = GREET_COOLDOWN
	var line := memory_line()
	if line.is_empty():
		var greetings: Array = profile.get("greetings", ["Hallo, Lumo!"])
		line = str(greetings[rng.randi_range(0, greetings.size() - 1)])
		if not lumo_known:
			line = "Hallo! Ich bin %s. %s" % [first_name(), line]
	say(line, 3.4)
	return line


## Called on both residents when a chat begins; lines alternate in bubbles.
func start_chat(other: RefCounted, speaks_first: bool) -> void:
	state = State.TALK
	partner = other.id
	talk_lines = chat_lines(other)
	if speaks_first and not talk_lines.is_empty():
		say(talk_lines[0], 3.2)
	affinity[other.id] = minf(1.0, float(affinity.get(other.id, 0.4)) + 0.02)
	# Residents tell each other what Lumo did: gossip spreads remembered help.
	for entry in other.memory:
		var who := str(entry.get("who", ""))
		if str(entry.get("event", "")) in ["helped", "delivered", "heard"] and not who.is_empty():
			if who != first_name() and not knows("heard", who) and not knows("helped"):
				remember("heard", who, str(entry.get("detail", "")))
				break


func chat_lines(other: RefCounted) -> Array[String]:
	var lines: Array[String] = []
	var topics: Array = profile.get("chat", [])
	if not topics.is_empty():
		lines.append(str(topics[rng.randi_range(0, topics.size() - 1)]))
	var relation: Dictionary = profile.get("relations", {}).get(other.id, {})
	if relation.has("line"):
		lines.append(str(relation.line))
	for entry in memory:
		if str(entry.get("event", "")) in ["helped", "delivered"]:
			lines.append("Lumo hat mir geholfen. %s" % str(entry.get("detail", "")))
			break
	if lines.is_empty():
		lines.append("Schönes Wetter heute am Hafen.")
	return lines


func say(text: String, seconds: float) -> void:
	bubble = text
	bubble_timer = seconds


func remember(event: String, who := "", detail := "") -> void:
	for entry in memory:
		if (
			str(entry.event) == event
			and str(entry.get("who", "")) == who
			and str(entry.get("detail", "")) == detail
		):
			return
	memory.push_front({"event": event, "who": who, "detail": detail})
	while memory.size() > MEMORY_LIMIT:
		memory.pop_back()


func knows(event: String, who := "") -> bool:
	for entry in memory:
		if str(entry.event) == event and (who.is_empty() or str(entry.get("who", "")) == who):
			return true
	return false


## A greeting that refers to something this resident actually remembers.
func memory_line() -> String:
	for entry in memory:
		match str(entry.event):
			"helped":
				return "Danke nochmal, Lumo! %s" % str(entry.get("detail", ""))
			"delivered":
				return "Deine Lieferung ist gut angekommen. Danke!"
			"traded":
				return "Schön, dass du wieder einkaufst, Lumo!"
			"heard":
				var who := str(entry.get("who", ""))
				if not who.is_empty() and who != first_name():
					return "Ich habe gehört, du hast %s geholfen. Toll!" % who
	return ""


func status_text() -> String:
	if state == State.WALK and not activity.is_empty():
		return "Unterwegs: " + activity
	if state == State.IDLE and not activity.is_empty():
		return activity
	return STATE_NAMES[state]


func to_data() -> Dictionary:
	var bonds: Dictionary = {}
	for other in affinity:
		bonds[str(other)] = snappedf(float(affinity[other]), 0.01)
	return {"memory": memory.duplicate(true), "affinity": bonds}


## Restores memory and relationships; invalid parts keep the authored defaults.
func restore(raw: Variant) -> bool:
	if not _valid_saved(raw):
		return false
	var checked: Array[Dictionary] = []
	for entry in raw.get("memory", []):
		checked.append(
			{
				"event": str(entry.event),
				"who": str(entry.get("who", "")).substr(0, 40),
				"detail": str(entry.get("detail", "")).substr(0, 120)
			}
		)
	memory = checked
	var saved_affinity: Dictionary = raw.get("affinity", {})
	for other in saved_affinity:
		if affinity.has(str(other)):
			affinity[str(other)] = clampf(float(saved_affinity[other]), 0.0, 1.0)
	return true


static func _valid_saved(raw: Variant) -> bool:
	if not raw is Dictionary:
		return false
	var saved_memory = raw.get("memory", [])
	var saved_affinity = raw.get("affinity", {})
	var valid: bool = saved_memory is Array and saved_memory.size() <= MEMORY_LIMIT
	valid = valid and saved_affinity is Dictionary
	if not valid:
		return false
	for entry in saved_memory:
		if not entry is Dictionary or not entry.get("event") is String:
			return false
		if str(entry.event) not in ["met", "helped", "delivered", "traded", "heard"]:
			return false
	for other in saved_affinity:
		var value = saved_affinity[other]
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)):
			return false
	return true
