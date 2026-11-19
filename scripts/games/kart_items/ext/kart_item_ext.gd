# gdlint: disable=max-public-methods
extends Node3D
## Wirt der erweiterten Lumo-Kart-Items (Donnerstern, Frostkristall, Feuermeteor,
## Sternenfestung, Wirbelwind; Welle 2 hängt sich hier ebenso ein).
## Keine zweite Item-Engine: Ziehen, Halten, Item-Knopf, Speichern des gehaltenen Items,
## Sternenschild, Schonzeit und HUD bleiben in kart_island.gd / kart_item_*. Dieser Knoten
## hängt unter race_root, bekommt pro Physiktakt tick() und beantwortet die kleinen
## Einhängepunkte (Tempo-, Lenk- und Haftungsfaktor, Spurversatz der KI, Warnung, Speichern).
##
## Gemeinsame Regeln für jeden neuen Treffer (resolve()):
##  1. Schild (Sternenschild, Sternenfestung, Nordlicht) wehrt ab -> sichtbare Abwehr.
##  2. Schonzeit (dieselbe wie bei Raketen, _lock_rules().grace) -> kein zweiter Treffer.
##  3. Treffer setzt die Schonzeit. Rivalen greifen das Kind höchstens alle
##     CHILD_ATTACK_GAP Sekunden mit einem neuen Item an (keine Dauerbeschuss-Ketten).
##  4. Seitliche Wirkungen (Frost, Wirbel) nur in einem sicheren Korridor: nie auf
##     Brückendeck, an offener Kante, auf Rampe/Sprung, in Passagen-Zonen, im Looping
##     oder in der Luft (safe_at()).

const REGISTRY = preload("res://scripts/games/kart_items/ext/kart_item_ext_registry.gd")
const FX = preload("res://scripts/games/kart_items/ext/kart_item_ext_fx.gd")
const CATALOG = preload("res://scripts/games/kart_items/kart_item_catalog.gd")
const PASSAGES = preload("res://scripts/games/kart_passages.gd")
const PLAYER: int = -1
const SAVE_VERSION: int = 1
## Mindestabstand (s) zwischen zwei Rivalen-Angriffen mit neuen Items auf das Kind.
const CHILD_ATTACK_GAP := {"gemuetlich": 9.0, "normal": 6.0, "profi": 4.0}
## Sicherer Korridor: so weit vor/hinter dem Ziel wird die Strecke geprüft (m).
const SAFE_BEHIND: float = 6.0
const SAFE_AHEAD: float = 30.0
const SAFE_STEP: float = 4.0
## Abstand der Kartmitte zur Planke, den ein seitlicher Stoß nie unterschreitet (m).
const CORRIDOR_MARGIN: float = 1.15

var race
var effects: Dictionary = {}
## key -> [{kind, left, total, speed, turn, grip}] (Tempo-/Lenk-/Haftungsfaktoren).
var mods: Dictionary = {}
## key -> [{left, total, amount, done}] laufende seitliche Versätze.
var pushes: Dictionary = {}
var child_attack_cooldown: float = 0.0
var reduced_motion: bool = false
var quality: String = "medium"
var stats: Dictionary = {
	"hits": 0, "blocked": 0, "grace": 0, "player_uses": 0, "rival_uses": 0, "unsafe_skips": 0
}
var _warning_cooldown: float = 0.0


func setup(owner_race) -> void:
	race = owner_race
	name = "KartItemExt"
	for behaviour in REGISTRY.behaviours():
		var script: Script = REGISTRY.script_for(behaviour)
		if script == null:
			push_warning("Lumo-Kart: Verhaltensdatei fehlt für " + str(behaviour))
			continue
		var effect = script.new()
		effect.setup(self, behaviour)
		effects[behaviour] = effect


static func handles(behaviour: String) -> bool:
	return REGISTRY.has_behaviour(behaviour)


func effect(behaviour: String):
	return effects.get(behaviour)


func ready_for_race() -> bool:
	return (
		race != null
		and is_instance_valid(race.player)
		and is_instance_valid(race.world)
		and race.mode != "arena"
	)


# --- Einhängepunkte ---------------------------------------------------------------------


func player_use(item_id: String, row: Dictionary) -> bool:
	var effect_node = effects.get(str(row.get("behaviour", "")))
	if effect_node == null or not ready_for_race():
		return false
	var used: bool = effect_node.use(PLAYER, item_id, row)
	if used:
		stats.player_uses += 1
		effect_node.stats.used += 1
	return used


func rival_use(index: int, item_id: String, context: Dictionary) -> bool:
	var row: Dictionary = CATALOG.entry(item_id)
	var effect_node = effects.get(str(row.get("behaviour", "")))
	if effect_node == null or not ready_for_race():
		return false
	if not effect_node.rival_wants(index, item_id, context):
		return false
	if not effect_node.use(index, item_id, row):
		return false
	stats.rival_uses += 1
	effect_node.stats.used += 1
	return true


func tick(delta: float) -> void:
	if not ready_for_race():
		return
	reduced_motion = bool(race.reduced_motion)
	quality = str(race.graphics_profile)
	child_attack_cooldown = maxf(0.0, child_attack_cooldown - delta)
	_warning_cooldown = maxf(0.0, _warning_cooldown - delta)
	_age_mods(delta)
	_apply_pushes(delta)
	for behaviour in effects:
		effects[behaviour].tick(delta)


func speed_factor(key: int) -> float:
	return _factor(key, "speed")


func turn_factor(key: int) -> float:
	return _factor(key, "turn")


func grip_factor(key: int) -> float:
	return _factor(key, "grip")


## Spurversatz für die KI (Ausweichen vor Meteor und Glutfeld).
func rival_lane_bias(index: int) -> float:
	var bias: float = 0.0
	for behaviour in effects:
		if effects[behaviour].has_method("lane_bias"):
			bias += float(effects[behaviour].lane_bias(index))
	return clampf(bias, -2.5, 2.5)


func incoming_for(key: int) -> float:
	var best: float = INF
	for behaviour in effects:
		best = minf(best, float(effects[behaviour].incoming(key)))
	return best


## 0..1 für die vorhandene Warnanzeige (roter Pfeil + Warnton) des Kindes.
func player_warning() -> float:
	var seconds: float = incoming_for(PLAYER)
	if seconds == INF:
		return 0.0
	return clampf(1.4 - seconds * 0.5, 0.35, 1.0)


## Gesamtdauer des aktuellen Schildes für den Restzeit-Ring im HUD.
func shield_total(key: int) -> float:
	var fortress = effects.get("fortress")
	if fortress != null and fortress.has_method("total_for"):
		return float(fortress.total_for(key))
	return 6.0


func save_state() -> Dictionary:
	var saved_effects: Dictionary = {}
	for behaviour in effects:
		saved_effects[behaviour] = effects[behaviour].save()
	return {
		"version": SAVE_VERSION,
		"mods": mods.duplicate(true),
		"pushes": pushes.duplicate(true),
		"child_attack_cooldown": child_attack_cooldown,
		"effects": saved_effects,
	}


func restore_state(data: Variant) -> void:
	clear()
	if not data is Dictionary or int(data.get("version", 0)) != SAVE_VERSION:
		return
	var cooldown: Variant = data.get("child_attack_cooldown", 0.0)
	child_attack_cooldown = (
		clampf(float(cooldown), 0.0, 12.0) if typeof(cooldown) in [TYPE_INT, TYPE_FLOAT] else 0.0
	)
	for source in [[data.get("mods", {}), mods], [data.get("pushes", {}), pushes]]:
		if not source[0] is Dictionary:
			continue
		for key in source[0]:
			if typeof(key) != TYPE_INT or not _valid_key(int(key)) or not source[0][key] is Array:
				continue
			var kept: Array = []
			for entry in source[0][key]:
				if (
					entry is Dictionary
					and typeof(entry.get("left")) in [TYPE_INT, TYPE_FLOAT]
					and float(entry.left) > 0.0
				):
					kept.append(entry)
			if not kept.is_empty():
				source[1][int(key)] = kept
	var saved_effects: Variant = data.get("effects", {})
	if saved_effects is Dictionary:
		for behaviour in effects:
			effects[behaviour].restore(saved_effects.get(behaviour, []))


func clear() -> void:
	mods.clear()
	pushes.clear()
	child_attack_cooldown = 0.0
	for behaviour in effects:
		effects[behaviour].clear()


# --- Wirkung (Tempo, Lenkung, seitlicher Versatz) --------------------------------------


## Eine zeitlich begrenzte, sanft ausklingende Wirkung. Gleiche Art ersetzt sich (kein Stapeln).
func add_mod(
	key: int, kind: String, seconds: float, speed: float = 1.0, turn: float = 1.0, grip: float = 1.0
) -> void:
	var list: Array = mods.get(key, [])
	list = list.filter(func(entry: Dictionary) -> bool: return str(entry.kind) != kind)
	list.append(
		{
			"kind": kind,
			"left": seconds,
			"total": maxf(0.05, seconds),
			"speed": speed,
			"turn": turn,
			"grip": grip
		}
	)
	mods[key] = list


func mod_left(key: int, kind: String) -> float:
	for entry in mods.get(key, []):
		if str(entry.kind) == kind:
			return float(entry.left)
	return 0.0


func mod_total(key: int, kind: String) -> float:
	for entry in mods.get(key, []):
		if str(entry.kind) == kind:
			return float(entry.total)
	return 0.0


func _factor(key: int, field: String) -> float:
	var factor: float = 1.0
	for entry in mods.get(key, []):
		var t: float = 1.0 - float(entry.left) / float(entry.total)
		# Volle Wirkung im ersten Drittel, dann weich zurück auf 1 (kein hartes Ende).
		var weight: float = 1.0 - smoothstep(0.33, 1.0, t)
		factor *= lerpf(1.0, float(entry.get(field, 1.0)), weight)
	return factor


func _age_mods(delta: float) -> void:
	for key in mods.keys():
		var kept: Array = []
		for entry in mods[key]:
			entry.left = float(entry.left) - delta
			if float(entry.left) > 0.0:
				kept.append(entry)
		if kept.is_empty():
			mods.erase(key)
		else:
			mods[key] = kept


## Seitlicher Versatz um `metres` (Vorzeichen = Richtung) über `seconds`, nur im sicheren
## Korridor. Gibt den tatsächlich erlaubten Versatz zurück (0 = unterdrückt).
func push(key: int, metres: float, seconds: float) -> float:
	if not safe_at(progress(key), key):
		stats.unsafe_skips += 1
		return 0.0
	var allowed: float = clamp_push(key, metres)
	if absf(allowed) < 0.05:
		return 0.0
	var list: Array = pushes.get(key, [])
	list.append({"left": seconds, "total": maxf(0.05, seconds), "amount": allowed, "done": 0.0})
	pushes[key] = list
	return allowed


func clamp_push(key: int, metres: float) -> float:
	var at: float = fposmod(progress(key), track_length())
	var wall: float = float(race._wall_lateral_at(at)) - CORRIDOR_MARGIN
	var now: float = lateral(key)
	return clampf(now + metres, -wall, wall) - now


func _apply_pushes(delta: float) -> void:
	for key in pushes.keys():
		var kept: Array = []
		var node: Node3D = kart(int(key))
		for entry in pushes[key]:
			entry.left = float(entry.left) - delta
			var t: float = clampf(1.0 - float(entry.left) / float(entry.total), 0.0, 1.0)
			var target: float = float(entry.amount) * smoothstep(0.0, 1.0, t)
			var step: float = target - float(entry.done)
			# Unterwegs wird nachgeprüft: wird es unsicher, endet der Versatz sofort.
			if not safe_at(progress(int(key)), int(key)):
				step = 0.0
				entry.left = 0.0
			step = clamp_push(int(key), step)
			if is_instance_valid(node) and absf(step) > 0.0:
				node.global_position += track_basis(progress(int(key))).x.normalized() * step
				if int(key) >= 0 and int(key) < race.opponent_lanes.size():
					race.opponent_lanes[int(key)] = float(race.opponent_lanes[int(key)]) + step
				else:
					race.lane = float(race.lane) + step
			entry.done = float(entry.done) + step
			if float(entry.left) > 0.0:
				kept.append(entry)
		if kept.is_empty():
			pushes.erase(key)
		else:
			pushes[key] = kept


# --- Treffer-Auflösung (Schild, Schonzeit, Rückmeldung) --------------------------------


## "blocked" | "grace" | "hit". Bei "hit" setzt der Aufrufer die eigentliche Wirkung.
func resolve(
	target: int, source: int, item_id: String, at: Vector3, block_text: String = "ABGEWEHRT!"
) -> String:
	if protected(target):
		stats.blocked += 1
		race._stat("blocked")
		if target == PLAYER:
			if is_instance_valid(race.shield_visual) and race.shield_visual.has_method("impact"):
				race.shield_visual.impact(at)
			say("%s – dein Schild hält!" % _item_name(item_id))
		elif target < race.opponent_item_fx.size():
			race.opponent_item_fx[target].shield_impact(at)
			if source == PLAYER:
				say("%s hat einen Schild – abgewehrt!" % race._rival_name(target))
		if target == PLAYER or source == PLAYER:
			race._popup(block_text, kart_top(target) + Vector3.UP * 1.0, Color("1aa3c4"))
			sound("shield_ping")
		return "blocked"
	if in_grace(target):
		stats.grace += 1
		return "grace"
	set_grace(target)
	stats.hits += 1
	if target == PLAYER:
		race._stat("player_hits_taken")
	if source == PLAYER and target >= 0:
		race._stat("player_hits_scored")
		race._popup(
			"TREFFER!",
			kart_top(target) + Vector3.UP * 1.1,
			Color(CATALOG.color(item_id)).darkened(0.1)
		)
		race.player.cheer_in_race(1.2)
		race._cheer_timer = 1.2
	elif target == PLAYER and source >= 0 and source < race.opponents.size():
		race.opponents[source].cheer_in_race(1.0)
	return "hit"


## Rivale greift das Kind an: merkt die Schonfrist für das Kind vor.
func note_attack(target: int) -> void:
	if target == PLAYER:
		child_attack_cooldown = float(CHILD_ATTACK_GAP.get(str(race.difficulty), 6.0))


func child_attackable() -> bool:
	return child_attack_cooldown <= 0.0 and not in_grace(PLAYER)


## Einmalige Warnzeile für das Kind (nicht jedes Bild neu).
func warn_player(text: String) -> void:
	if _warning_cooldown > 0.0:
		return
	_warning_cooldown = 1.0
	say(text)
	sound("ext_warning")


# --- Rennteilnehmer im Streckenraum -----------------------------------------------------


func racer_keys() -> Array[int]:
	var keys: Array[int] = [PLAYER]
	for i in range(race.opponents.size()):
		keys.append(i)
	return keys


func _valid_key(key: int) -> bool:
	return key == PLAYER or (key >= 0 and key < race.opponents.size())


func kart(key: int) -> Node3D:
	if key == PLAYER:
		return race.player
	if key >= 0 and key < race.opponents.size():
		return race.opponents[key]
	return null


func progress(key: int) -> float:
	return float(race.distance) if key == PLAYER else float(race.opponent_distances[key])


func lateral(key: int) -> float:
	return float(race.lane) if key == PLAYER else float(race.opponent_lanes[key])


func track_length() -> float:
	return maxf(1.0, float(race.track_length))


func protected(key: int) -> bool:
	if key == PLAYER:
		return float(race.shield_time) > 0.0 or float(race.aurora_time) > 0.0
	return (
		float(race.opponent_shield_times[key]) > 0.0 or float(race.opponent_aurora_times[key]) > 0.0
	)


func in_grace(key: int) -> bool:
	if key == PLAYER:
		return float(race.player_grace_time) > 0.0
	return key < race.opponent_grace_times.size() and float(race.opponent_grace_times[key]) > 0.0


func set_grace(key: int) -> void:
	var grace: float = float(race._lock_rules().grace)
	if key == PLAYER:
		race.player_grace_time = maxf(float(race.player_grace_time), grace)
	elif key < race.opponent_grace_times.size():
		race.opponent_grace_times[key] = maxf(float(race.opponent_grace_times[key]), grace)


func airborne(key: int) -> bool:
	if key == PLAYER:
		return bool(race.airborne) or bool(race.loop_state.active) or bool(race.open_edge_fall)
	var rival: Node3D = kart(key)
	if not is_instance_valid(rival):
		return true
	if rival.has_meta(&"lumo_physical_loop"):
		return true
	if rival.has_meta(&"lumo_ballistic_flight"):
		var state = rival.get_meta(&"lumo_ballistic_flight")
		return state != null and bool(state.active)
	return false


## Sichere Fahrbahn für seitliche Wirkungen und Glutfelder: kein Brückendeck (auch nicht kurz
## davor), keine offene Kante, keine Rampe/Sprung, keine Passagen-Zone, nicht in der Luft.
func safe_at(at_progress: float, key: int = -99) -> bool:
	if key != -99 and airborne(key):
		return false
	var world = race.world
	var d: float = -SAFE_BEHIND
	while d <= SAFE_AHEAD:
		var x: float = fposmod(at_progress + d, track_length())
		if PASSAGES.void_at(world, x) or not PASSAGES.zone_at(world, x).is_empty():
			return false
		if world.open_edge_side(x) != 0.0 or world.ramp_height(x) > 0.05:
			return false
		d += SAFE_STEP
	return not PASSAGES.keeps_clear(world, at_progress, 10.0)


## Nächster gültiger Gegner vor (`ahead_max`) oder – falls keiner – hinter (`behind_max`)
## `owner`. Überspringt Ziele in Schonzeit; das Kind nur, wenn child_attackable().
func pick_target(
	owner: int, ahead_max: float, behind_max: float = 0.0, need_safe: bool = false
) -> int:
	var own: float = progress(owner)
	var best: int = -99
	var best_gap: float = INF
	for key in racer_keys():
		if key == owner or in_grace(key) or airborne(key):
			continue
		if key == PLAYER and owner != PLAYER and not child_attackable():
			continue
		var gap: float = progress(key) - own
		var score: float = gap if gap > 0.5 else (-gap + 1000.0)
		if gap > 0.5 and gap <= ahead_max or gap < -0.5 and -gap <= behind_max:
			if need_safe and not safe_at(progress(key), key):
				stats.unsafe_skips += 1
				continue
			if score < best_gap:
				best_gap = score
				best = key
	return best


func track_global(at_progress: float, at_lateral: float, lift: float = 0.0) -> Vector3:
	var frame: Transform3D = race._frame_at(fposmod(at_progress, track_length()), at_lateral)
	var world_frame: Transform3D = race.race_root.global_transform * frame
	return world_frame.origin + world_frame.basis.y.normalized() * lift


func track_basis(at_progress: float) -> Basis:
	return (
		(race.race_root.global_basis * race.world.frame(fposmod(at_progress, track_length())))
		. orthonormalized()
	)


func kart_top(key: int) -> Vector3:
	var node: Node3D = kart(key)
	if not is_instance_valid(node):
		return Vector3.ZERO
	return node.global_position + node.global_basis.y.normalized() * 1.25


func kart_centre(key: int) -> Vector3:
	var node: Node3D = kart(key)
	if not is_instance_valid(node):
		return Vector3.ZERO
	return node.global_position + node.global_basis.y.normalized() * 0.55


## Weltpunkte der vier Radnaben (echte Radknoten, sonst Kartmaße als Ersatz).
func wheel_points(key: int) -> Array[Vector3]:
	var node: Node3D = kart(key)
	var result: Array[Vector3] = []
	if not is_instance_valid(node):
		return result
	var pivots: Variant = node.get("wheel_pivots")
	if pivots is Array:
		for pivot in pivots:
			if is_instance_valid(pivot) and (pivot as Node3D).is_inside_tree():
				result.append((pivot as Node3D).global_position)
	if result.size() >= 4:
		return result.slice(0, 4)
	result.clear()
	for offset in [
		Vector3(-0.62, 0.28, -0.72),
		Vector3(0.62, 0.28, -0.72),
		Vector3(-0.62, 0.28, 0.78),
		Vector3(0.62, 0.28, 0.78)
	]:
		result.append(node.global_transform * offset)
	return result


func eye() -> Vector3:
	var camera: Camera3D = race.camera
	return (
		camera.global_position
		if is_instance_valid(camera) and camera.is_inside_tree()
		else Vector3.UP * 10.0
	)


## Partikelbudget je Grafikprofil; ruhige Bewegung halbiert.
func budget(amount: int) -> int:
	var scale: float = {"low": 0.4, "medium": 0.7, "high": 1.0}.get(quality, 0.7)
	return maxi(2, int(round(float(amount) * scale * (0.5 if reduced_motion else 1.0))))


## Streckenthema für Wirbel-Staub und Rauch.
func theme() -> String:
	var id: String = str(race.track_id)
	if "winter" in id or "berg" in id or "ice" in id or "eis" in id:
		return "snow"
	if "jungle" in id or "wald" in id or "forest" in id:
		return "leaves"
	if "volcano" in id or "lava" in id:
		return "embers"
	if "holo" in id or "galaxy" in id or "neon" in id:
		return "sparks"
	return "sand"


func involves_player(owner: int, target: int) -> bool:
	return owner == PLAYER or target == PLAYER


func sound(kind: String, pitch: float = 1.0) -> void:
	race._sound_effect(kind, pitch)


func say(text: String) -> void:
	if is_instance_valid(race.message):
		race.message.text = text


func _item_name(item_id: String) -> String:
	return str(CATALOG.entry(item_id).get("name", "Item"))
