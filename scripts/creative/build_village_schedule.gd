extends RefCounted
## Dorfwelt – Zeitplan der Herausforderungen (reine Regeln, keine Szene).
##
## Erst eine friedliche Aufbauphase. Die erste kleine Herausforderung kommt
## frühestens an Tag FIRST_DAY UND erst, wenn das Kind
##   1. Haus und Hof verstanden hat (beide gebaut, Einführung erledigt/übersprungen),
##   2. eine funktionierende Versorgung hat (SUPPLY_DAYS Tage ohne Hunger,
##      ein arbeitender Hof deckt den Bedarf),
##   3. den Bereich „Schützen“ kennengelernt hat (einmal geöffnet).
## Wer länger braucht, behält die Zeit: es zählt kein Kalender, nur diese
## Bedingungen und die selbst ausgelösten Tage („Nächster Tag“). Bei geschlossener
## App vergeht kein Tag. Angekündigt wird mindestens MIN_NOTICE Tage vorher.
## Nach einer Niederlage folgt eine Erholungsphase (RECOVERY_DAYS ohne neue
## Ankündigung, Stufe bleibt gleich). Ein Kalender sorgt dafür, dass zwei
## Systeme (Besuche von Räubern/Drachen, Konflikte mit Nachbarstädten,
## Hasenwellen) nie am selben Tag ankommen.
const VERSION := 1
const FIRST_DAY := 8
const MIN_NOTICE := 2
const SUPPLY_DAYS := 2
const RECOVERY_DAYS := 6
## Systeme im Kalender. „besuch“ = Räuber/Drache, „konflikt“ = Nachbarstadt,
## „hasen“ = Hasenwellen der Mauer-Verteidigung.
const SYSTEMS := ["besuch", "konflikt", "hasen"]

## Tage in Folge ohne Hunger mit arbeitendem Hof.
var supply_streak := 0
## Hat das Kind den Bereich „Schützen“ geöffnet?
var defense_seen := false
## Erster Tag, an dem nach einer Niederlage wieder angekündigt werden darf.
var recover_until := 0
## Ankunftstag -> System (nur zukünftige und heutige Einträge werden gehalten).
var calendar: Dictionary = {}
var defeats := 0


static func system_for(threat: String) -> String:
	return "konflikt" if threat == "rivale" else "besuch"


## Wird nach jedem echten Tageswechsel gerufen (report = model.next_day()).
func after_day(model, report: Dictionary) -> void:
	var own: Dictionary = report.get("player", {})
	var town: Dictionary = model._player
	var farms := int(model._working(town, "farm")) if model.has_method("_working") else int(model._count(town, "farm"))
	var fed := int(own.get("food_shortfall", 1)) == 0
	var produced := int((own.get("produced", {}) as Dictionary).get("food", 0))
	var needed := int(own.get("food_needed", int(town.population)))
	if fed and farms > 0 and produced >= needed:
		supply_streak += 1
	elif not fed:
		supply_streak = 0
	var today := int(model.day)
	for day in calendar.keys():
		if int(day) < today:
			calendar.erase(day)


func house_and_farm(model) -> bool:
	var town: Dictionary = model._player
	return int(model._count(town, "house")) > 0 and int(model._count(town, "farm")) > 0


func supply_ok() -> bool:
	return supply_streak >= SUPPLY_DAYS


## Fehlende Bedingungen als kurze Liste (für Lumo und Tests).
func missing(model, tutorial_done: bool) -> Array[String]:
	var result: Array[String] = []
	if int(model.day) < FIRST_DAY:
		result.append("ruhe")
	if not house_and_farm(model) or not tutorial_done:
		result.append("haus_hof")
	if not supply_ok():
		result.append("versorgung")
	if not defense_seen:
		result.append("schutz")
	if int(model.day) < recover_until:
		result.append("erholung")
	return result


func may_announce(model, tutorial_done: bool) -> bool:
	return missing(model, tutorial_done).is_empty()


func day_free(day: int, system: String) -> bool:
	return not calendar.has(day) or str(calendar[day]) == system


## Nächster Ankunftstag ab `earliest`, an dem kein anderes System kommt.
func free_day(earliest: int, system: String) -> int:
	var day := earliest
	while not day_free(day, system):
		day += 1
	return day


func claim(day: int, system: String) -> bool:
	if not day_free(day, system):
		return false
	calendar[day] = system
	return true


func release(day: int) -> void:
	calendar.erase(day)


## Ausgang einer Herausforderung. Nach einer Niederlage: Erholungsphase.
func record_outcome(day: int, outcome: String) -> void:
	release(day)
	if outcome in ["knapp", "verloren"]:
		defeats += 1
		recover_until = maxi(recover_until, day + RECOVERY_DAYS)


## Eine Eigenschaft je Stufe: abwechselnd wächst die Gruppe oder es kommt
## eine weitere Ankunftsrichtung dazu – nie beides auf einmal.
static func stage(level: int) -> Dictionary:
	var step := maxi(0, level - 1)
	var sides := mini(4, 1 + step / 2)
	var group := 4 + (step + 1) / 2 + maxi(0, step / 2 - 3)
	return {"level": maxi(1, level), "group": group, "sides": sides}


## Was hat sich gegenüber der vorigen Stufe geändert? (für Lumos Ankündigung)
static func stage_change(level: int) -> String:
	if level <= 1:
		return "Eine kleine Gruppe aus einer Richtung."
	var now := stage(level)
	var before := stage(level - 1)
	if int(now.sides) > int(before.sides):
		return "Diesmal kommen sie aus %d Richtungen." % int(now.sides)
	return "Diesmal ist die Gruppe größer: %d statt %d." % [int(now.group), int(before.group)]


## Name der Truppenart, die gegen diesen Angreifer hilft. Solange es nur eine
## Art gibt: „Wache/Wachen“. Sobald die Regeln Truppenarten kennen, liefern sie
## `troop_for_threat(threat) -> {"one": "Speerträger", "many": "Speerträger"}`.
static func troop_word(raids, threat: String) -> Dictionary:
	if raids.has_method("troop_for_threat"):
		var named: Variant = raids.troop_for_threat(threat)
		if named is Dictionary and named.has("one") and named.has("many"):
			return named
	return {"one": "Wache", "many": "Wachen"}


## Die eine einfache Handlung, die jetzt hilft (echte Zahlen aus dem Plan).
static func simple_help(raids, model) -> String:
	if raids.pending.is_empty():
		return ""
	var view: Dictionary = raids.forecast()
	if bool(view.ready):
		return "Dein Schutz reicht schon. Du kannst ruhig weiterbauen."
	var threat := str(raids.pending.threat)
	var target := float(view.need) * 1.1
	var gap := target - float(view.have)
	var per_guard: float = float(raids.UNIT.guard) * float(raids.THREATS[threat].weights.guard)
	# Neue Wachen stehen als Schildwachen in der Stadtmitte und zählen dort nicht voll
	# (Aufstellung, build_village_guards.gd): mit dem echten Wert je Wache rechnen.
	if int(raids.guards) > 0:
		per_guard = minf(per_guard, raids.GUARDS.defense(raids, threat) / float(raids.guards))
	else:
		per_guard *= 0.5
	var guards_needed := int(ceil(gap / maxf(0.1, per_guard)))
	var free_guards: int = raids.max_guards(model) - int(raids.guards)
	var troop := troop_word(raids, threat)
	if guards_needed <= free_guards:
		return "Bilde %d %s aus (je 1 Münze). Dann reicht dein Schutz." % [guards_needed, str(troop.one if guards_needed == 1 else troop.many)]
	if threat != "drache" and int(raids.parts.wall) == 0:
		return "Baue eine Holzpalisade (12 Holz) und bilde %s aus." % str(troop.many)
	if threat == "drache":
		return "Baue einen Wachturm mit Wasserspritze (8 Stein, 6 Holz)."
	return "Baue Netzfallen (3 Holz, 2 Essen) und bilde %s aus." % str(troop.many)


func snapshot() -> Dictionary:
	var days: Dictionary = {}
	for day in calendar:
		days[str(day)] = str(calendar[day])
	return {"version": VERSION, "supply": supply_streak, "defense_seen": defense_seen,
		"recover_until": recover_until, "calendar": days, "defeats": defeats}


## Alte Spielstände haben keinen Zeitplan: Versorgung und „Schützen“ werden
## aus dem echten Stand geschätzt, damit ein großes Dorf nicht neu anfängt.
static func restore(raw: Variant, model = null, raids = null):
	var result = load("res://scripts/creative/build_village_schedule.gd").new()
	if raw is Dictionary and raw.get("version") == VERSION:
		result.supply_streak = clampi(int(raw.get("supply", 0)), 0, 9999)
		result.defense_seen = bool(raw.get("defense_seen", false))
		result.recover_until = clampi(int(raw.get("recover_until", 0)), 0, 99999)
		result.defeats = maxi(0, int(raw.get("defeats", 0)))
		var days: Variant = raw.get("calendar", {})
		if days is Dictionary:
			for key in days:
				if str(days[key]) in SYSTEMS and str(key).is_valid_int():
					result.calendar[int(key)] = str(days[key])
		return result
	if model != null:
		var town: Dictionary = model._player
		if int(model._count(town, "farm")) > 0 and int(town.get("food_shortfall", 0)) == 0 and int(model.day) > 2:
			result.supply_streak = SUPPLY_DAYS
	if raids != null:
		# Wer schon Angriffe erlebt, Schutz gebaut oder Wachen hat, kennt „Schützen“.
		var built := 0
		for kind in raids.parts:
			built += int(raids.parts[kind])
		result.defense_seen = built > 0 or int(raids.guards) > 0 or int(raids.defended) + int(raids.lost) > 0 or not raids.pending.is_empty()
		if not raids.pending.is_empty():
			result.calendar[int(raids.pending.get("arrive_day", 0))] = system_for(str(raids.pending.threat))
	return result
