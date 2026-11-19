extends SceneTree
## Lektion „Das schnelle Matt“ (aus delivery/lumo-schach-2048-20261118 übernommen):
## jeder Schritt lösbar, nur die genannte Figur zählt, der letzte Zug ist Matt.
## Aufruf: godot --headless --path . --script res://scripts/tests/chess_school_schaefer_regression.gd

const SCHOOL = preload("res://scripts/games/chess/chess_school.gd")
const RULES = preload("res://scripts/games/chess/chess_rules.gd")

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("[ChessSchaefer] " + text)


func _move(step: Dictionary, uci: String) -> bool:
	var g: RefCounted = SCHOOL.make_rules(str(step.fen))
	var m: int = g.move_from_uci(uci)
	return m != 0 and SCHOOL.move_ok(step, g, m)


func _run() -> void:
	var lesson: Dictionary = SCHOOL.lesson("schaefer")
	_check(not lesson.is_empty(), "Lektion vorhanden")
	_check(SCHOOL.PATH.has(["lesson", "schaefer"]), "Lektion im Lernweg")
	_check(SCHOOL.PATH.back() == ["lesson", "schaefer"], "Lektion am Ende: kein Kind verliert Fortschritt")
	var steps: Array = lesson.get("steps", [])
	_check(steps.size() == 6, "sechs Schritte")
	for step: Dictionary in steps:
		var g: RefCounted = SCHOOL.make_rules(str(step.fen))
		_check(g.get_fen().split(" ")[0] == str(step.fen).split(" ")[0], "Stellung lesbar: " + str(step.fen))
		_check(str(step.say).split(" ", false).size() <= 12, "höchstens zwölf Wörter: " + str(step.say))
		if str(step.type) == "move":
			_check(not SCHOOL.solution(step).is_empty(), "Schritt lösbar: " + str(step.say))
	_check(_move(steps[0], "e2e4"), "e2-e4 löst Schritt 1")
	_check(not _move(steps[0], "d2d4"), "anderer Bauer zählt nicht")
	_check(_move(steps[1], "f1c4"), "Läufer nach c4")
	_check(not _move(steps[1], "c2c4"), "Bauer nach c4 zählt nicht")
	_check(_move(steps[2], "d1h5"), "Dame nach h5")
	_check(_move(steps[4], "h5f7"), "Dame schlägt f7 mit Matt")
	_check(not _move(steps[4], "c4f7"), "Läuferschlag auf f7 ist kein Matt")
	var final: RefCounted = SCHOOL.make_rules(str(steps[5].fen))
	_check(final.in_check() and not final.has_legal_move(), "Schlussbild ist Matt")
	print("[ChessSchaefer] %s checks=%d failures=%d" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
