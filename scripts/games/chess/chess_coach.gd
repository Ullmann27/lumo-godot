extends RefCounted
## Lumo als Schachlehrer: erklärt Züge in einem kurzen Kindersatz, warnt
## freundlich vor Fehlern, gibt Tipps und lobt Versuche.
##
## Sätze bleiben kurz (höchstens zwölf Wörter) und ohne Fachwörter, die das
## Kind nicht kennt. Alles hier liest nur das Brett; es ändert nichts.

const RULES = preload("res://scripts/games/chess/chess_rules.gd")
const AI = preload("res://scripts/games/chess/chess_ai.gd")

const NAME := ["", "Bauer", "Springer", "Läufer", "Turm", "Dame", "König"]
const NAME_ACC := ["", "Bauern", "Springer", "Läufer", "Turm", "Dame", "König"]
const FEMININE := [false, false, false, false, false, true, false]
const VALUE := [0, 1, 3, 3, 5, 9, 100]

const PRAISE := [
	"Gut gemacht!", "Toller Zug!", "Super, du denkst mit!", "Das war mutig!",
	"Prima, weiter so!", "Klasse ausprobiert!",
]
const COMFORT := [
	"Kein Problem, Fehler gehören zum Lernen.", "Macht nichts – probier es nochmal.",
	"Auch Profis übersehen mal etwas.",
]


static func piece_name(t: int) -> String:
	return NAME[t]


## „mein Turm“ / „meine Dame“ / „dein Läufer“ / „deine Dame“.
static func owned(t: int, mine: bool) -> String:
	var stem := "mein" if mine else "dein"
	return "%s%s %s" % [stem, "e" if FEMININE[t] else "", NAME[t]]


## Akkusativ: „meinen Turm“ / „deine Dame“.
static func owned_acc(t: int, mine: bool) -> String:
	var stem := "mein" if mine else "dein"
	return "%s%s %s" % [stem, "e" if FEMININE[t] else "en", NAME_ACC[t]]


static func capitalize_first(s: String) -> String:
	return s.substr(0, 1).to_upper() + s.substr(1) if not s.is_empty() else s


static func word_count(sentence: String) -> int:
	return sentence.replace("–", " ").split(" ", false).size()


## Kleinster Wert einer Figur von `by`, die `sq` angreift (0 = keine).
static func cheapest_attacker(g: RefCounted, sq: int, by: int) -> int:
	var best := 0
	for from in 64:
		var p: int = g.board[from]
		if p == 0 or (p >> 3) != by:
			continue
		if g.attacks_from(from).has(sq):
			var v: int = VALUE[p & 7]
			if best == 0 or v < best:
				best = v
	return best


## Steht die Figur auf `sq` ungeschützt oder gegen eine billigere Figur?
static func is_hanging(g: RefCounted, sq: int) -> bool:
	var p: int = g.board[sq]
	if p == 0 or (p & 7) == RULES.KING:
		return false
	var c := p >> 3
	var attacker := cheapest_attacker(g, sq, c ^ 1)
	if attacker == 0:
		return false
	if attacker < VALUE[p & 7]:
		return true
	return not g.is_attacked(sq, c)


static func hanging_squares(g: RefCounted, color: int) -> Array[int]:
	var out: Array[int] = []
	for sq in 64:
		var p: int = g.board[sq]
		if p != 0 and (p >> 3) == color and is_hanging(g, sq):
			out.append(sq)
	return out


## Gefahr für die Seite am Zug (nach Lumos Zug): die wertvollste bedrohte
## Figur. {} wenn nichts in Gefahr ist, sonst {"square", "text"}.
static func danger(g: RefCounted) -> Dictionary:
	var worst := -1
	var worst_value := 0
	for sq: int in hanging_squares(g, g.side):
		var v: int = VALUE[g.board[sq] & 7]
		if v > worst_value:
			worst_value = v
			worst = sq
	if worst < 0 or worst_value < 3:
		return {}
	var t: int = g.board[worst] & 7
	var name := capitalize_first(owned(t, false))
	return {"square": worst, "text": "%s ist bedroht – magst du %s retten?" % [name, "sie" if FEMININE[t] else "ihn"]}


## Erklärt einen Zug in einem Satz. `g` ist die Stellung VOR dem Zug.
## `mine` = true, wenn Lumo selbst gezogen hat („ich“), sonst für das Kind.
static func explain(g: RefCounted, m: int, mine: bool = true) -> String:
	var from := RULES.move_from(m)
	var to := RULES.move_to(m)
	var flags := RULES.move_flags(m)
	var piece: int = g.board[from]
	var t := piece & 7
	var us := piece >> 3
	var victim: int = g.board[to] & 7
	if flags & RULES.F_EP:
		victim = RULES.PAWN
	var was_hanging := is_hanging(g, from)
	var was_attacked: bool = g.is_attacked(from, us ^ 1)
	var before_hanging := hanging_squares(g, us ^ 1)
	g.make_move(m)
	var mate: bool = g.in_check() and not g.has_legal_move()
	var check: bool = g.in_check()
	var targets: Array[int] = []
	for sq: int in g.attacks_from(to):
		var q: int = g.board[sq]
		if q != 0 and (q >> 3) != us and (q & 7) != RULES.KING:
			if VALUE[q & 7] > VALUE[t] or not g.is_attacked(sq, us ^ 1):
				targets.append(q & 7)
	var safe_now := not is_hanging(g, to)
	g.unmake_move()
	var who := "Ich" if mine else "Du"
	if mate:
		return "Schachmatt! Der König kann nicht mehr fliehen." if mine else "Schachmatt! Du hast gewonnen!"
	if flags & RULES.F_PROMO:
		return "%s Bauer ist ganz hinten angekommen und wird stärker!" % ("Mein" if mine else "Dein")
	if flags & RULES.F_CASTLE:
		return "%s bringe meinen König hinter die Bauern in Sicherheit." % who if mine \
			else "Du bringst deinen König in Sicherheit. Klug!"
	if victim != 0:
		var acc := owned_acc(victim, not mine)
		if before_hanging.has(to):
			return "%s %s %s – niemand hat ihn beschützt." % [who, "nehme" if mine else "nimmst", acc] \
				if not FEMININE[victim] else "%s %s %s – niemand hat sie beschützt." % [who, "nehme" if mine else "nimmst", acc]
		return "%s %s %s." % [who, "schlage" if mine else "schlägst", acc]
	if check:
		return "Schach! Der König muss sich jetzt retten."
	if was_hanging and safe_now:
		return "%s war in Gefahr. Darum ist %s weggelaufen." % [
			capitalize_first(owned(t, mine)), "sie" if FEMININE[t] else "er"]
	if targets.size() >= 2:
		return "%s greift zwei Figuren auf einmal an – eine Gabel!" % capitalize_first(owned(t, mine))
	if targets.size() == 1:
		return "Jetzt greift %s %s an." % [owned(t, mine), owned_acc(targets[0], not mine)]
	var home_rank := 0 if us == RULES.WHITE else 7
	if (t == RULES.KNIGHT or t == RULES.BISHOP) and (from >> 3) == home_rank:
		return "%s kommt heraus und hilft in der Mitte." % capitalize_first(owned(t, mine))
	if t == RULES.PAWN and (to & 7) in [2, 3, 4, 5]:
		return "%s Bauer erobert Platz in der Mitte." % ("Mein" if mine else "Dein")
	if t == RULES.PAWN:
		return "%s Bauer läuft ein Feld weiter nach vorne." % ("Mein" if mine else "Dein")
	if was_attacked and safe_now:
		return "%s steht jetzt sicherer." % capitalize_first(owned(t, mine))
	return "%s %s auf ein besseres Feld." % [
		who, ("stelle " + owned_acc(t, true)) if mine else ("stellst " + owned_acc(t, false))]


## Prüft einen Zug des Kindes, bevor er gilt. {} wenn alles gut ist, sonst
## {"square": Feld, "text": freundliche Warnung, "kind": "mate"/"hang"}.
static func warning(g: RefCounted, m: int) -> Dictionary:
	var us: int = g.side
	var before := hanging_squares(g, us)
	g.make_move(m)
	var result := {}
	# Könnte der Gegner dann sofort mattsetzen?
	for reply: int in g.legal_moves():
		g.make_move(reply)
		var mated: bool = g.in_check() and not g.has_legal_move()
		g.unmake_move()
		if mated:
			result = {"square": g.king_sq[us], "kind": "mate",
				"text": "Vorsicht, dann wäre dein König gefangen! Magst du nochmal schauen?"}
			break
	if result.is_empty():
		var victim_cap: int = 0
		# Was der Zug selbst geschlagen hat, gleicht ein Risiko aus.
		var to := RULES.move_to(m)
		var undo_info: int = int(g.undo_stack[g.undo_stack.size() - 2]) & 15
		victim_cap = VALUE[undo_info & 7] if undo_info != 0 else 0
		var worst := -1
		var worst_value := 0
		for sq: int in hanging_squares(g, us):
			var v: int = VALUE[g.board[sq] & 7]
			if before.has(sq) and sq != to:
				continue
			if v > worst_value:
				worst_value = v
				worst = sq
		if worst >= 0 and worst_value > victim_cap:
			var t: int = g.board[worst] & 7
			result = {"square": worst, "kind": "hang",
				"text": "Schau, %s wäre dann in Gefahr. Magst du nochmal überlegen?" % owned(t, false)}
	g.unmake_move()
	return result


## Tipp für die Seite am Zug: eine gute Idee aus kurzer Suche (Coroutine).
static func hint(g: RefCounted, seed_value: int = 1) -> Dictionary:
	var ai := AI.new(seed_value)
	var r: Dictionary = await ai.think(g, 2, {"budget_ms": 700})
	var m: int = r.move
	if m < 0:
		return {}
	return {"move": m, "from": RULES.move_from(m), "to": RULES.move_to(m),
		"text": hint_text(g, m)}


static func hint_text(g: RefCounted, m: int) -> String:
	var t: int = g.board[RULES.move_from(m)] & 7
	var victim: int = g.board[RULES.move_to(m)] & 7
	if victim != 0:
		return "Schau mal: %s kann %s schlagen." % [owned(t, false), owned_acc(victim, true)]
	g.make_move(m)
	var check: bool = g.in_check()
	g.unmake_move()
	if check:
		return "Schau mal: %s kann Schach geben." % owned(t, false)
	return "Wie wäre es mit dein%s %s? Das leuchtende Feld ist gut." % [
		"er" if FEMININE[t] else "em", NAME_ACC[t] if t == RULES.PAWN else NAME[t]]


static func praise(rng: RandomNumberGenerator) -> String:
	return PRAISE[rng.randi_range(0, PRAISE.size() - 1)]


static func comfort(rng: RandomNumberGenerator) -> String:
	return COMFORT[rng.randi_range(0, COMFORT.size() - 1)]


## Kurzer Satz zum Spielende.
static func ending_text(status: String, child_won: bool) -> String:
	match status:
		"checkmate":
			return "Schachmatt! Du hast gewonnen – toll gespielt!" if child_won \
				else "Schachmatt. Das war spannend – noch eine Runde?"
		"stalemate":
			return "Patt! Keiner kann ziehen, also unentschieden."
		"draw_repetition":
			return "Dreimal dasselbe Bild – das ist unentschieden."
		"draw_fifty":
			return "Lange nichts passiert – das ist unentschieden."
		"draw_material":
			return "Keiner kann mehr Matt setzen – unentschieden."
	return ""
