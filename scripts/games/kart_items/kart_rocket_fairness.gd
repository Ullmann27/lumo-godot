extends RefCounted
## Faire Sternraketen: häufiger, aber nie in Ketten. Ergänzt die bestehende Schonzeit
## (player_grace_time / opponent_grace_times nach jedem Treffer) um
##  - Startschutz: in den ersten START_PROTECT_S Sekunden zielt kein Rivale auf das Kind;
##  - Rettungsschutz: nach jedem Rücksetzer/jeder Rettung RESET_PROTECT_S Sekunden;
##  - Trefferpause: nach jedem Treffer aufs Kind AFTER_HIT_PROTECT_S keine neue Erfassung
##    und kein weiterer Treffer (Querschläger zerplatzen harmlos);
##  - Verfolger-Limit: höchstens MAX_CHASERS_ON_CHILD Salve(n) gleichzeitig auf dem Weg
##    zum Kind, und nur ein Rivale erfasst das Kind zur selben Zeit;
##  - keine Treffer an Sturzstellen: Rampen, Looping, Sprunglücken, offene Kanten,
##    Spalt-Schanzen (kart_track_thrills.gd), Eisbrücke/Lianenaffe/Lavapuls-Passagen –
##    dort zerplatzt ein Geschoss harmlos.
## Gilt für Treffer auf das Kind und auf Rivalen gleichermaßen (Sturzstellen).

const ZONES = preload("res://scripts/games/kart_items/kart_item_zones.gd")
const START_PROTECT_S: float = 8.0
const RESET_PROTECT_S: float = 4.0
## Nach jedem Treffer aufs Kind (Rakete, Funkenkugel, Impuls …) erfasst es
## AFTER_HIT_PROTECT_S lang kein Rivale: Treffer kommen nie Schlag auf Schlag.
const AFTER_HIT_PROTECT_S: float = 12.0
const MAX_CHASERS_ON_CHILD: int = 1
const DANGER_KINDS: Array[String] = [
	"start_finish",
	"ramp",
	"loop",
	"jump",
	"leap",
	"open_edge",
	"passage_bridge",
	"passage_swing",
	"passage_gate",
]

var _resets_seen: int = 0
var _protect_until: float = 0.0
var _hit_protect_until: float = 0.0
var _last_spin: float = 0.0
var _world_id: int = 0
var _danger: Array[Dictionary] = []


func reset() -> void:
	_resets_seen = 0
	_protect_until = 0.0
	_hit_protect_until = 0.0
	_last_spin = 0.0
	_world_id = 0
	_danger.clear()


## Jedes Bild: Rücksetzer und Treffer (neue Drehung des Kinds) erkennen, Schutz starten.
func observe(reset_count: int, elapsed: float, player_spin: float = 0.0) -> void:
	if player_spin > _last_spin + 0.01:
		_hit_protect_until = elapsed + AFTER_HIT_PROTECT_S
	_last_spin = player_spin
	if reset_count != _resets_seen:
		if reset_count > _resets_seen:
			_protect_until = elapsed + RESET_PROTECT_S
		_resets_seen = reset_count


func _areas(world) -> Array[Dictionary]:
	if not is_instance_valid(world):
		return []
	if world.get_instance_id() != _world_id:
		_world_id = world.get_instance_id()
		_danger.clear()
		for area in ZONES.hazards(world):
			if str(area.kind) in DANGER_KINDS:
				# Der eigentliche Gefahrenbereich, ohne den langen Prismen-Anlauf.
				var trimmed: Dictionary = area.duplicate()
				trimmed.start = (
					float(area.start) + (35.0 if str(area.kind) != "open_edge" else 30.0)
				)
				if str(area.kind) == "start_finish":
					trimmed.start = -12.0
					trimmed.end = 12.0
				_danger.append(trimmed)
	return _danger


## Gefahrenstelle (Sturzstelle) an dieser Streckendistanz, "" = sicher.
func danger_at(world, distance: float) -> String:
	if not is_instance_valid(world):
		return ""
	var d: float = fposmod(distance, float(world.length))
	for area in _areas(world):
		if ZONES._inside(d, area, float(world.length)):
			return str(area.kind)
	return ""


## Darf Rivale `shooter` jetzt eine Erfassung auf das Kind beginnen/halten?
func child_targetable(game, shooter: int) -> bool:
	return child_block_reason(game, shooter).is_empty()


func child_block_reason(game, shooter: int) -> String:
	var reason: String = ""
	if float(game.elapsed) < START_PROTECT_S:
		reason = "start"
	elif float(game.elapsed) < _protect_until:
		reason = "rescue"
	elif float(game.player_grace_time) > 0.0:
		reason = "grace"
	elif float(game.elapsed) < _hit_protect_until:
		reason = "after_hit"
	elif incoming_salvos_on_child(game) >= MAX_CHASERS_ON_CHILD:
		reason = "chasers"
	else:
		for j in range(game.opponent_lock_targets.size()):
			if j != shooter and int(game.opponent_lock_targets[j]) == -1:
				reason = "other_lock"
		var danger: String = danger_at(game.world, float(game.distance))
		if reason.is_empty() and not danger.is_empty():
			reason = "danger_" + danger
	return reason


## Treffer der erweiterten Items (Blitz, Frost, Meteor …) drehen das Kind nicht: sie starten
## die Trefferpause ausdrücklich (Hook items-neu, gleiche Regel wie für Raketen).
func note_child_hit(elapsed: float) -> void:
	_hit_protect_until = maxf(_hit_protect_until, elapsed + AFTER_HIT_PROTECT_S)


## Wie viele Salven (Paare je Schütze) gerade auf das Kind fliegen.
static func incoming_salvos_on_child(game) -> int:
	if not is_instance_valid(game.item_runtime):
		return 0
	var owners: Dictionary = {}
	# Hook items-neu: ein laufender Angriff eines erweiterten Items zählt wie eine Salve.
	var ext = game.get("item_ext")
	if is_instance_valid(ext) and float(ext.incoming_for(-1)) < INF:
		owners["item_ext"] = true
	for entry in game.item_runtime.projectiles:
		if int(entry.get("target", -99)) == -1 and int(entry.get("owner", -99)) != -1:
			owners["%d_%d" % [int(entry.owner), int(entry.get("pair", 0))]] = true
	return owners.size()


## Ein Treffer am Ziel wird nur ausgeführt, wenn es nicht an einer Sturzstelle fährt.
## Für das Kind zusätzlich: nicht im Start-/Rettungsschutz und höchstens ein Treffer je
## AFTER_HIT_PROTECT_S – auch Geschosse, die eigentlich einem Rivalen galten oder ohne
## Ziel unterwegs sind (Funkenkugel), zerplatzen dann harmlos.
func hit_allowed(game, target: int) -> bool:
	var at: float = float(game.distance)
	if target >= 0:
		if target >= game.opponent_distances.size():
			return true
		at = float(game.opponent_distances[target])
	elif target == -1:
		var now: float = float(game.elapsed)
		if now < START_PROTECT_S or now < _protect_until or now < _hit_protect_until:
			return false
	return danger_at(game.world, at).is_empty()
