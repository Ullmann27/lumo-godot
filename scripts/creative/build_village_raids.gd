extends RefCounted
## Dorfwelt Teil 3 – Angriffe mit Sinn und Verteidigung (reine Regeln, keine Szene).
##
## Jeder Angriff hat einen erkennbaren GRUND aus dem echten Spielstand und eine
## VORWARNUNG von mehreren Dorftagen:
##   - Räuber Krummzahn will das volle Kornlager (Essen ≥ ROBBER_FOOD),
##   - ein verärgerter Nachbar will seine Rohstoffquelle zurück,
##   - Funkel, der kleine Drache, wird vom Münzschatz angelockt (Münzen ≥ DRAGON_COINS).
## Verteidigen ist Planen: Mauer, Türme, Tor/Zugbrücke, Graben, Netzfallen,
## Wachen und Bündnispartner. Jeder Gegner reagiert anders darauf (der Drache
## fliegt über Mauern). Die Auswertung ist deterministisch (Seed + Tag).
## Kindgerecht: niemand wird verletzt – Angreifer purzeln und laufen weg,
## Gebäude werden „beschädigt“ (keine Arbeit bis zur Reparatur). Verlieren ist
## nie das Ende: reparieren, Vorräte zurückholen, Lumo macht Mut.
## Zeit läuft nur mit „Nächster Tag“ des Kindes – nie, wenn die App zu ist.
const STATE = preload("res://scripts/creative/build_settlement_state.gd")
const NEIGHBORS = preload("res://scripts/creative/build_village_neighbors.gd")
const GUARDS = preload("res://scripts/creative/build_village_guards.gd")
const VERSION := 1
## Keine Angriffe in den ersten Tagen und nicht vor Kapitel 3 (Index 2).
const FIRST_DAY := 8
const FIRST_CHAPTER := 2
const WARNING_DAYS := 3
const COOLDOWN := 8
const ROBBER_FOOD := 30
const DRAGON_COINS := 40
## Höchstens dieser Anteil eines Vorrats kann bei einer Niederlage verloren gehen.
const MAX_LOSS_SHARE := 0.3
const RECOVER_SHARE := 0.7
const EXPEDITION_DAYS := 2
const MAX_LEVEL := 12
## Schutzbauten: Stufe, Kosten je Stufe, Freischaltung über Ansehen (Wappen).
const PARTS := {
	"wall": {"title": "Mauer", "max": 3, "costs": [{"wood": 12}, {"stone": 16, "wood": 4}, {"stone": 24, "coins": 4}],
		"fame": [0, 1, 3], "names": ["Holzpalisade", "Steinmauer", "Hohe Burgmauer"]},
	"tower": {"title": "Wachturm", "max": 4, "costs": [{"stone": 8, "wood": 6}], "fame": [0, 0, 1, 2], "names": ["Wachturm"]},
	"gate": {"title": "Tor", "max": 2, "costs": [{"wood": 8, "stone": 4}, {"wood": 10, "stone": 8, "coins": 3}],
		"fame": [0, 2], "names": ["Tor", "Zugbrücke"], "needs": "wall"},
	"ditch": {"title": "Graben", "max": 1, "costs": [{"stone": 10, "food": 6}], "fame": [1], "names": ["Wassergraben"]},
	"trap": {"title": "Netzfalle", "max": 6, "costs": [{"wood": 3, "food": 2}], "fame": [0, 0, 0, 1, 1, 2], "names": ["Netzfalle"]},
}
## Wirkung je Stufe gegen die drei Gegner (Punkte). Der Drache fliegt: Mauer,
## Tor und Graben helfen kaum; Türme (Wasserspritzen) und Wachen sehr.
const UNIT := {"wall": 7.0, "tower": 5.0, "gate": 4.0, "ditch": 7.0, "trap": 2.5, "guard": 2.0, "ally": 12.0}
const THREATS := {
	"raeuber": {
		"title": "Räuberbande von Krummzahn", "leader": "Krummzahn", "animal": "raccoon",
		"target": "food", "base": 10.0, "step": 4.5,
		"weights": {"wall": 1.0, "tower": 0.8, "gate": 0.8, "ditch": 1.0, "trap": 1.6, "guard": 1.2, "ally": 1.0},
		"advice": "Mauer, Netzfallen und Wachen halten die Räuber auf.",
	},
	"rivale": {
		"title": "Belagerung", "leader": "", "animal": "",
		"target": "source", "base": 14.0, "step": 4.5,
		"weights": {"wall": 1.3, "tower": 1.0, "gate": 1.3, "ditch": 1.2, "trap": 0.5, "guard": 1.0, "ally": 1.2},
		"advice": "Mauer, Tor und Graben helfen. Oder du verhandelst mit einem Geschenk.",
	},
	"drache": {
		"title": "Funkel, der kleine Drache", "leader": "Funkel", "animal": "dragon",
		"target": "coins", "base": 12.0, "step": 4.5,
		"weights": {"wall": 0.15, "tower": 1.6, "gate": 0.0, "ditch": 0.0, "trap": 0.9, "guard": 1.1, "ally": 1.0},
		"advice": "Funkel fliegt über Mauern. Türme mit Wasserspritzen und Wachen helfen.",
	},
}
## Wo die Gegner wohnen (Weltkoordinaten x/z): Lager und Höhle sind sichtbar.
const ROBBER_CAMP := Vector2(-178.0, 78.0)
const DRAGON_NEST := Vector2(-196.0, -86.0)

var world_seed := 20261118
var parts: Dictionary = {"wall": 0, "tower": 0, "gate": 0, "ditch": 0, "trap": 0}
var guards := 0
## Wachen-Verbände (build_village_guards.gd): Summe der Größen == guards.
var units: Array = []
## Ausbildungsstätten der Truppenarten (Schießplatz, Kaserne, Stall).
var troop_sites: Dictionary = {}
var fame := 0
var next_check := FIRST_DAY
## Angekündigter Angriff oder leer: {threat, by, reason, announce_day, arrive_day, level, ally, source}
var pending: Dictionary = {}
## Letzte Auswertung (für die Szene und den Bericht).
var last_result: Dictionary = {}
## Von Räubern/Drachen mitgenommene Vorräte, die man zurückholen kann.
var stash: Dictionary = {}
## Laufende Unternehmung: {kind, return_day, guards, ...}
var expedition: Dictionary = {}
var defended := 0
var lost := 0
var faced: Dictionary = {}
var chronicle: Array = []


static func part_name(kind: String, level: int) -> String:
	var names: Array = PARTS[kind].names
	return str(names[clampi(level - 1, 0, names.size() - 1)])


func level_for(threat: String) -> int:
	return clampi(1 + int(faced.get(threat, 0)) + defended / 3, 1, MAX_LEVEL)


## Cost of the next stage of a part (empty when maxed).
func next_cost(kind: String) -> Dictionary:
	if not PARTS.has(kind) or int(parts[kind]) >= int(PARTS[kind].max):
		return {}
	var costs: Array = PARTS[kind].costs
	return (costs[mini(int(parts[kind]), costs.size() - 1)] as Dictionary).duplicate()


func build_error(kind: String, model) -> String:
	if not PARTS.has(kind):
		return "Diesen Schutzbau gibt es nicht."
	var spec: Dictionary = PARTS[kind]
	var stage := int(parts[kind])
	if stage >= int(spec.max):
		return "%s ist schon fertig ausgebaut." % str(spec.title)
	if spec.has("needs") and int(parts[str(spec.needs)]) == 0:
		return "Ein Tor braucht zuerst eine Mauer."
	var needed := int((spec.fame as Array)[stage])
	if fame < needed:
		return "Dafür brauchst du %d Wappen. Wehre Angriffe ab!" % needed
	if not model._affords(model._player, next_cost(kind)):
		return "Dafür reicht dein Vorrat noch nicht."
	return ""


## Pays with the same pantry rules as every other exchange (no free stock).
func build(kind: String, model) -> String:
	var error := build_error(kind, model)
	if not error.is_empty():
		return error
	if not model.exchange(next_cost(kind), {}):
		return model.last_error
	parts[kind] = int(parts[kind]) + 1
	return ""


## Guards are residents with a helmet: at most half the population, 1 coin each.
func max_guards(model) -> int:
	return int(model._player.population) / 2


func train_guard(model) -> String:
	if guards >= max_guards(model):
		return "Mehr Wachen hat dein Dorf noch nicht. Es braucht mehr Bewohner."
	if not expedition.is_empty():
		return "Die Wachen sind gerade unterwegs."
	if not model.exchange({"coins": 1}, {}):
		return "Eine Wache braucht 1 Münze für Helm und Schild."
	guards += 1
	GUARDS.reconcile(self)
	return ""


## Defence points against one threat. Guards on an expedition do not count.
func defense_points(threat: String, ally := false) -> float:
	var weights: Dictionary = THREATS[threat].weights
	var total := 0.0
	for kind in parts:
		total += float(parts[kind]) * float(UNIT[kind]) * float(weights[kind])
	# Soldaten zählen nach Art, Aufstellung und Schutzbauten (build_village_troops.gd).
	total += GUARDS.defense(self, threat)
	if ally:
		total += UNIT.ally * float(weights.ally)
	return total


func attack_points(threat: String, level: int) -> float:
	return float(THREATS[threat].base) + float(THREATS[threat].step) * float(level - 1)


## Seeded ±10 % per day and threat: the same save always plays out the same.
func _variance(day: int, threat: String) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world_seed, day, threat])
	return 0.9 + rng.randf() * 0.2


func _note(day: int, text: String) -> void:
	chronicle.append("Tag %d: %s" % [day, text])
	if chronicle.size() > 40:
		chronicle = chronicle.slice(-40)


## Which threat has a real reason right now? Priority: angry neighbour,
## robbers (food), dragon (coins); the last attacker gets a rest when another
## one also has a reason.
func reasons(model, neighbors) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var town: Dictionary = model._player
	if neighbors != null:
		for key in NEIGHBORS.SOURCES:
			if str(neighbors.sources.get(key, "")) != "player":
				continue
			for entry in NEIGHBORS.NEIGHBORS:
				if str(entry.wants) == key and int(neighbors.reputation[entry.id]) <= -1:
					result.append({"threat": "rivale", "by": str(entry.id), "source": key,
						"reason": "%s will die %s zurück." % [str(entry.name), str(NEIGHBORS.SOURCES[key].title)]})
	if int(town.resources.food) >= ROBBER_FOOD:
		result.append({"threat": "raeuber", "by": "krummzahn",
			"reason": "Krummzahn hat dein volles Kornlager gesehen: %d Essen!" % int(town.resources.food)})
	if int(town.resources.coins) >= DRAGON_COINS:
		result.append({"threat": "drache", "by": "funkel",
			"reason": "Funkel glitzert es in den Augen: %d Münzen in deinem Dorf!" % int(town.resources.coins)})
	return result


## One village day (called after the child's own day and the neighbours).
## Resolves an arriving attack, brings expeditions home, announces new ones.
func advance_day(model, neighbors, chapter_index: int, tutorial_done := true) -> Dictionary:
	var day := int(model.day)
	var report := {}
	if not expedition.is_empty() and day >= int(expedition.return_day):
		report["expedition"] = _finish_expedition(model, day)
	if not pending.is_empty() and day >= int(pending.arrive_day):
		report["raid"] = resolve(model, neighbors)
		return report
	if not pending.is_empty() or day < next_check or chapter_index < FIRST_CHAPTER or not tutorial_done:
		return report
	var options := reasons(model, neighbors)
	if options.is_empty():
		return report
	var choice: Dictionary = options[0]
	if options.size() > 1 and str(choice.threat) == str(last_result.get("threat", "")):
		choice = options[1]
	pending = choice.duplicate()
	pending["announce_day"] = day
	pending["arrive_day"] = day + WARNING_DAYS
	pending["level"] = level_for(str(choice.threat))
	pending["ally"] = ""
	_note(day, "Warnung: " + str(choice.reason))
	report["warning"] = pending.duplicate()
	return report


func threat_title(info: Dictionary) -> String:
	if str(info.get("threat", "")) == "rivale":
		var spec := NEIGHBORS.spec(str(info.get("by", "")))
		return "%s aus %s" % [str(spec.get("name", "Ein Nachbar")), str(spec.get("town", ""))]
	return str(THREATS[str(info.threat)].title)


## Lumo's forecast: real points, as a simple picture (shields vs. attackers).
func forecast() -> Dictionary:
	if pending.is_empty():
		return {}
	var threat := str(pending.threat)
	var ally_called := not str(pending.get("ally", "")).is_empty()
	var need := attack_points(threat, int(pending.level))
	var have := defense_points(threat, ally_called)
	return {"threat": threat, "need": need, "have": have, "ready": have >= need * 1.1,
		"close": have >= need * 0.6, "advice": str(THREATS[threat].advice)}


## Ask an allied neighbour (Freundschaft 3) for help with the announced attack.
func call_ally(id: String, neighbors) -> String:
	if pending.is_empty():
		return "Gerade kommt niemand."
	if neighbors == null or not neighbors.allied(id):
		return "Nur verbündete Nachbarn kommen zu Hilfe."
	if str(pending.get("by", "")) == id:
		return "Dieser Nachbar ist selbst der Angreifer."
	pending["ally"] = id
	return ""


## Rivals can be talked out of it: a gift of what they want ends the siege.
func negotiate(model, neighbors) -> String:
	if pending.is_empty() or str(pending.threat) != "rivale":
		return "Mit Räubern und Drachen kann man nicht verhandeln."
	var cost := negotiation_cost()
	if not model.exchange(cost, {}):
		return "Für das Friedensgeschenk fehlt noch etwas."
	var id := str(pending.by)
	neighbors.towns[id].exchange({}, cost)
	neighbors.reputation[id] = 0
	_note(int(model.day), "Frieden mit %s durch ein Geschenk." % str(NEIGHBORS.spec(id).name))
	last_result = {"threat": "rivale", "by": id, "outcome": "frieden", "day": int(model.day), "damaged": [], "loss": {}}
	pending = {}
	next_check = int(model.day) + COOLDOWN
	return ""


func negotiation_cost() -> Dictionary:
	if pending.is_empty() or str(pending.threat) != "rivale":
		return {}
	var resource := str(NEIGHBORS.SOURCES[str(pending.source)].resource)
	return {resource: 8, "food": 4}


## The attack arrives: compare plans, decide the outcome, apply gentle results.
func resolve(model, neighbors) -> Dictionary:
	var day := int(model.day)
	var threat := str(pending.threat)
	var level := int(pending.level)
	var ally := str(pending.get("ally", ""))
	var need := attack_points(threat, level) * _variance(day, threat)
	var have := defense_points(threat, not ally.is_empty())
	var ratio := have / maxf(1.0, need)
	var outcome := "abgewehrt" if ratio >= 1.0 else ("knapp" if ratio >= 0.6 else "verloren")
	var result := {"threat": threat, "by": str(pending.get("by", "")), "reason": str(pending.reason), "day": day,
		"level": level, "need": snappedf(need, 0.1), "have": snappedf(have, 0.1), "outcome": outcome, "ally": ally,
		"damaged": [], "loss": {}, "reward": {}, "used": parts.duplicate(), "guards": guards}
	faced[threat] = int(faced.get(threat, 0)) + 1
	if outcome == "abgewehrt":
		defended += 1
		fame += 1
		result.reward = _victory(model, neighbors, threat)
		_note(day, "%s purzelt davon! Abgewehrt." % threat_title(pending))
	else:
		lost += 1
		var count := 1 if outcome == "knapp" else 2
		result.damaged = _damage(model, threat, count)
		result.loss = _loss(model, neighbors, threat, 0.12 if outcome == "knapp" else MAX_LOSS_SHARE)
		_note(day, "%s war stärker. %d Gebäude beschädigt." % [threat_title(pending), result.damaged.size()])
	# Traps are refilled by the villagers; a lost gate fight needs a fix: nothing
	# is destroyed, only damaged buildings wait for repair.
	last_result = result
	pending = {}
	next_check = day + COOLDOWN
	return result


func _victory(model, neighbors, threat: String) -> Dictionary:
	var gift := {}
	match threat:
		"raeuber":
			gift = {"wood": 6, "coins": 2}
		"drache":
			gift = {"stone": 6}
		"rivale":
			gift = {"stone": 5}
			if neighbors != null:
				neighbors.reputation[str(pending.by)] = 0
	# Everyone is impressed: friendly neighbours like a brave village.
	if neighbors != null:
		for entry in NEIGHBORS.NEIGHBORS:
			if str(entry.id) != str(pending.get("by", "")) and int(neighbors.reputation[entry.id]) >= 0:
				neighbors.reputation[entry.id] = mini(NEIGHBORS.MAX_REPUTATION, int(neighbors.reputation[entry.id]) + 1)
	model.exchange({}, gift)
	return gift


## Damaged (never destroyed): buildings that matter to the attacker's goal first.
func _damage(model, threat: String, count: int) -> Array:
	var prefer: Array = {"raeuber": ["farm", "grain", "bakery"], "drache": ["market", "school"],
		"rivale": ["quarry", "lumber"]}[threat]
	var candidates: Array = []
	for building in model._player.buildings:
		var plot := int(building.plot)
		if model.damaged_plots.has(plot) or str(building.kind) == "house":
			continue
		var rank := prefer.find(str(building.kind))
		candidates.append([rank if rank >= 0 else 99, plot, str(building.kind)])
	candidates.sort()
	var result: Array = []
	for index in range(mini(count, candidates.size())):
		var plot: int = candidates[index][1]
		model.damaged_plots[plot] = true
		result.append({"plot": plot, "kind": candidates[index][2]})
	return result


func _loss(model, neighbors, threat: String, share: float) -> Dictionary:
	var town: Dictionary = model._player
	var loss := {}
	match threat:
		"raeuber":
			loss = {"food": int(floor(float(town.resources.food) * share))}
		"drache":
			loss = {"coins": mini(20, int(floor(float(town.resources.coins) * share)))}
		"rivale":
			var key := str(pending.source)
			if share >= MAX_LOSS_SHARE and neighbors != null:
				neighbors.sources[key] = str(pending.by)
				neighbors.reputation[str(pending.by)] = 0
				loss = {"source": key}
			else:
				var resource := str(NEIGHBORS.SOURCES[key].resource)
				loss = {resource: int(floor(float(town.resources[resource]) * share))}
	var take := {}
	for resource in loss:
		if resource in STATE.RESOURCES and int(loss[resource]) > 0:
			take[resource] = int(loss[resource])
	if not take.is_empty() and model.exchange(take, {}):
		if threat != "rivale":
			for resource in take:
				stash[resource] = int(stash.get(resource, 0)) + int(take[resource])
		elif neighbors != null:
			neighbors.towns[str(pending.by)].exchange({}, take)
	return loss


func damaged_count(model) -> int:
	return model.damaged_plots.size()


func repair_cost(model, plot: int) -> Dictionary:
	for building in model._player.buildings:
		if int(building.plot) == plot:
			var cost: Dictionary = model.building_cost(str(building.kind))
			var half := {}
			for resource in cost:
				if resource != "coins":
					half[resource] = maxi(1, int(cost[resource]) / 2)
			return half
	return {}


func repair(model, plot: int) -> String:
	if not model.damaged_plots.has(plot):
		return "Dieses Gebäude ist heil."
	if not model.exchange(repair_cost(model, plot), {}):
		return "Für die Reparatur fehlt noch Holz oder Stein."
	model.damaged_plots.erase(plot)
	return ""


## Unternehmungen ohne Gewalt: Kundschafter (Vorhersage) und Vorräte zurückholen
## (die Räuber werden ausgetrickst und laufen davon). Dauer in Dorftagen.
func expedition_error(kind: String, model) -> String:
	if not expedition.is_empty():
		return "Es ist schon jemand unterwegs."
	match kind:
		"kundschafter":
			if int(model._player.resources.food) < 2:
				return "Der Kundschafter braucht 2 Essen als Proviant."
		"zurueckholen":
			if stash.is_empty():
				return "Es gibt nichts zurückzuholen."
			if guards < 2:
				return "Dafür brauchst du mindestens 2 Wachen."
		_:
			return "Diese Unternehmung gibt es nicht."
	return ""


func start_expedition(kind: String, model) -> String:
	var error := expedition_error(kind, model)
	if not error.is_empty():
		return error
	var day := int(model.day)
	if kind == "kundschafter":
		model.exchange({"food": 2}, {})
		expedition = {"kind": kind, "return_day": day + 1, "guards": 0}
	else:
		expedition = {"kind": kind, "return_day": day + EXPEDITION_DAYS, "guards": mini(guards, 4)}
	return ""


func _finish_expedition(model, day: int) -> Dictionary:
	var kind := str(expedition.kind)
	var result := {"kind": kind}
	if kind == "kundschafter":
		var lines: Array[String] = []
		if not pending.is_empty():
			var view := forecast()
			lines.append("%s kommt in %d Tagen. %s" % [threat_title(pending), maxi(0, int(pending.arrive_day) - day),
				"Dein Schutz reicht!" if view.ready else ("Es wird knapp." if view.close else "Baue noch mehr Schutz!")])
		else:
			var food := int(model._player.resources.food)
			var coins := int(model._player.resources.coins)
			lines.append("Krummzahn schaut ab %d Essen. Du hast %d." % [ROBBER_FOOD, food])
			lines.append("Funkel kommt ab %d Münzen. Du hast %d." % [DRAGON_COINS, coins])
		result["lines"] = lines
	else:
		var back := {}
		for resource in stash:
			back[resource] = int(ceil(float(stash[resource]) * RECOVER_SHARE))
		model.exchange({}, back)
		stash = {}
		fame += 1
		result["back"] = back
		_note(day, "Die Wachen holen Vorräte zurück: Krummzahn läuft davon.")
	expedition = {}
	return result


func snapshot(model = null) -> Dictionary:
	return {"version": VERSION, "seed": world_seed, "damaged": snapshot_damage(model) if model != null else [], "parts": parts.duplicate(), "guards": guards, "fame": fame,
		"next_check": next_check, "pending": pending.duplicate(true), "last": last_result.duplicate(true),
		"stash": stash.duplicate(), "expedition": expedition.duplicate(), "defended": defended, "lost": lost,
		"faced": faced.duplicate(), "log": chronicle.slice(-24), "units": GUARDS.snapshot(self),
		"troop_sites": troop_sites.duplicate()}


## Damaged plots live in the village model (production) but are saved here.
func snapshot_damage(model) -> Array:
	var plots: Array = model.damaged_plots.keys()
	plots.sort()
	return plots


## Old saves have no raid layer: fresh start (no attack before FIRST_DAY,
## chapter 3 and the end of the tutorial).
static func restore(raw: Variant, model = null):
	var result = load("res://scripts/creative/build_village_raids.gd").new()
	if model != null:
		result.next_check = maxi(FIRST_DAY, int(model.day) + 2)
	if not raw is Dictionary or raw.get("version") != VERSION:
		return result
	result.world_seed = int(raw.get("seed", result.world_seed))
	for kind in result.parts:
		result.parts[kind] = clampi(int(raw.get("parts", {}).get(kind, 0)), 0, int(PARTS[kind].max))
	result.guards = clampi(int(raw.get("guards", 0)), 0, 9999)
	GUARDS.restore(result, raw.get("units", []))
	var sites: Variant = raw.get("troop_sites", {})
	if sites is Dictionary:
		for key in sites:
			if GUARDS.TROOPS.SITES.has(str(key)) and sites[key] == true:
				result.troop_sites[str(key)] = true
	GUARDS.apply_upkeep(model, result)
	result.fame = clampi(int(raw.get("fame", 0)), 0, 9999)
	result.next_check = int(raw.get("next_check", FIRST_DAY))
	result.defended = maxi(0, int(raw.get("defended", 0)))
	result.lost = maxi(0, int(raw.get("lost", 0)))
	for key in raw.get("faced", {}):
		if THREATS.has(str(key)):
			result.faced[str(key)] = maxi(0, int(raw.faced[key]))
	var waiting: Variant = raw.get("pending", {})
	if waiting is Dictionary and THREATS.has(str(waiting.get("threat", ""))):
		result.pending = _ints(waiting)
	var previous: Variant = raw.get("last", {})
	if previous is Dictionary:
		result.last_result = _ints(previous)
	for resource in raw.get("stash", {}):
		if str(resource) in STATE.RESOURCES:
			result.stash[str(resource)] = maxi(0, int(raw.stash[resource]))
	var trip: Variant = raw.get("expedition", {})
	if trip is Dictionary and str(trip.get("kind", "")) in ["kundschafter", "zurueckholen"]:
		result.expedition = _ints(trip)
	for line in raw.get("log", []):
		result.chronicle.append(str(line))
	if model != null:
		for plot in raw.get("damaged", []):
			if int(plot) >= 0 and int(plot) < int(model._player.plots):
				model.damaged_plots[int(plot)] = true
	return result


## JSON turns whole numbers into floats; bring them back.
static func _ints(raw: Dictionary) -> Dictionary:
	var result := {}
	for key in raw:
		var value: Variant = raw[key]
		if str(key) in ["need", "have"]:
			# Strength values are fractions by nature; keep them as they were saved.
			result[key] = float(value)
		elif value is float and value == floor(value):
			result[key] = int(value)
		elif value is Dictionary:
			result[key] = _ints(value)
		elif value is Array:
			var items: Array = []
			for item in value:
				items.append(_ints(item) if item is Dictionary else (int(item) if item is float and item == floor(item) else item))
			result[key] = items
		else:
			result[key] = value
	return result
