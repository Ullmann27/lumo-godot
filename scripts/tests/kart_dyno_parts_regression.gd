extends SceneTree
## Leistungsteile auf dem Prüfstand: jede Variante hat mindestens einen gemessenen Vorteil
## und einen gemessenen Nachteil gegenüber Serie (nie nur „besser“), Serie ist bitgleich zum
## alten Fahrverhalten, die angezeigten Werte kommen aus kart_dyno.measure().
## Kopflos: godot --headless --path . --script res://scripts/tests/kart_dyno_parts_regression.gd
const FLEET = preload("res://scripts/games/kart_fleet.gd")
const CATALOG = preload("res://scripts/games/kart_part_catalog.gd")
const DYNO = preload("res://scripts/games/kart_dyno.gd")
const POWERTRAIN = preload("res://scripts/games/kart_powertrain.gd")
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		print("[KartDynoParts] FAIL: ", label)


func _run() -> void:
	var base: Dictionary = FLEET.multipliers(FLEET.base_stats("comet"), FLEET.entry("comet").traits)
	var serie: Dictionary = CATALOG.apply(base, {})
	_check(serie == base, "Serie ändert keinen Fahrfaktor")
	_check(is_equal_approx(POWERTRAIN.boost_scale(base), 1.42), "Turbo-Aufschlag wie bisher")
	_check(
		is_equal_approx(POWERTRAIN.turn_rate(base, 30.0, false, false), 1.42 * 2.0),
		"Lenkrate Serie wie bisher"
	)
	_check(
		is_equal_approx(POWERTRAIN.turn_rate(base, 30.0, true, true), (1.42 + 0.35) * 2.0 * 0.35),
		"Lenkrate Drift in der Luft wie bisher"
	)
	_check(is_equal_approx(POWERTRAIN.grip_rate(base, true), 6.2), "Drift-Haftung wie bisher")
	_check(is_equal_approx(POWERTRAIN.grip_rate(base, false), 18.0), "Haftung wie bisher")
	_check(is_equal_approx(POWERTRAIN.landing_settle(base, 9.0), 0.225), "Landung wie bisher")
	var before: Dictionary = DYNO.measure(base)
	print("[KartDynoParts] serie ", _fmt(before))
	for slot in CATALOG.SLOTS:
		var options: Array[Dictionary] = CATALOG.options(slot)
		_check(options.size() >= 6, "%s: Serie + mindestens fünf Varianten" % slot)
		var free := 0
		for entry in options:
			if int(entry.cost) == 0:
				free += 1
			if str(entry.id) == "serie":
				continue
			var after: Dictionary = DYNO.measure(CATALOG.apply(base, {slot: str(entry.id)}))
			var plus := 0
			var minus := 0
			var shown_plus := 0
			var shown_minus := 0
			var shown: Array[String] = DYNO.display_metrics(
				CATALOG.SLOT_METRICS[slot], before, after
			)
			for metric in DYNO.METRICS:
				var v: int = DYNO.verdict(metric, float(before[metric]), float(after[metric]))
				plus += 1 if v > 0 else 0
				minus += 1 if v < 0 else 0
				if v > 0 and shown.has(metric):
					shown_plus += 1
				if v < 0 and shown.has(metric):
					shown_minus += 1
			print("[KartDynoParts] %s/%s %s" % [slot, entry.id, _fmt(after)])
			_check(
				plus >= 1 and minus >= 1, "%s/%s: Vorteil und Nachteil gemessen" % [slot, entry.id]
			)
			_check(
				shown_plus >= 1 and shown_minus >= 1,
				"%s/%s: Vorteil und Nachteil stehen in der Prüfstand-Anzeige" % [slot, entry.id]
			)
		_check(free == 3, "%s: Serie, bisherige freie Variante und neues Evolution-Teil frei" % slot)
	# Rounding and physical limits can differ between chassis. Check every
	# purchasable mechanical part against its own stock vehicle.
	for kart_id in FLEET.ids():
		var factory: Dictionary = FLEET.multipliers(FLEET.base_stats(kart_id), FLEET.entry(kart_id).traits)
		var stock := DYNO.measure(factory)
		for slot in CATALOG.SLOTS:
			for part in CATALOG.options(slot):
				if part.id == "serie":
					continue
				var proposed := DYNO.measure(CATALOG.apply(factory, {slot: part.id}))
				var gain := false
				for metric in DYNO.display_metrics(CATALOG.SLOT_METRICS[slot], stock, proposed):
					gain = gain or DYNO.verdict(metric, stock[metric], proposed[metric]) > 0
				_check(gain, "%s/%s/%s: sichtbarer Fahrvorteil zur Serie" % [kart_id, slot, part.id])
	_finish()


func _fmt(values: Dictionary) -> String:
	var parts: PackedStringArray = []
	for metric in DYNO.METRICS:
		parts.append("%s=%s" % [metric, DYNO.format_value(metric, float(values[metric]))])
	return " ".join(parts)


func _finish() -> void:
	if failures.is_empty():
		print("[KartDynoParts] PASS %d checks" % checks)
	else:
		print("[KartDynoParts] FAIL %d of %d checks" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
