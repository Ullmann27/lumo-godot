extends RefCounted
## Spielbare Einführung: Lumo erklärt jedes Spiel in vier Schritten an einer
## echten kleinen Runde. Die Runde läuft über den normalen Regelkern mit festem
## Startwert; sie wird weder gespeichert noch gewertet.
##
## Schritt-Felder:
##   text  – was Lumo sagt
##   wait  – "tap" (Weiter-Knopf), "play" (Kind legt/fragt), "select" (Kind
##           wählt eine Karte), "done" (letzter Schritt, startet die Partie)
##   when  – "now" oder "turn" (erst zeigen, wenn das Kind am Zug ist)
##   focus – was hervorgehoben wird: "trump", "hand", "table", "seats", ""

const SESSION = preload("res://scripts/games/cards/cards_session.gd")
const DECK = preload("res://scripts/games/cards/rules/star_deck.gd")

## Feste Startwerte; `ready()` prüft, dass sie die Lernsituation hergeben.
const SEEDS := {"stich": 23, "leiter": 9, "quartett": 9}
const PLAYERS := 4

const STEPS := {
	"stich": [
		{"text": "Beim Sternenstich legt jeder reihum eine Karte in die Mitte. Die höchste Karte gewinnt alle – das ist ein Stich.", "wait": "tap", "when": "now", "focus": "table"},
		{"text": "Die aufgedeckte Karte am Stapel zeigt die Trumpffarbe. Ein Trumpf schlägt jede andere Farbe.", "wait": "tap", "when": "now", "focus": "trump"},
		{"text": "Jetzt du! Du musst dieselbe Farbe legen wie die erste Karte. Tippe eine leuchtende Karte an und dann noch einmal.", "wait": "play", "when": "turn", "focus": "hand"},
		{"text": "Super! Wer den Stich gewinnt, spielt als Nächstes aus. Wer am Ende die meisten Stiche hat, gewinnt die Runde.", "wait": "done", "when": "now", "focus": ""},
	],
	"leiter": [
		{"text": "Bei der Sternenleiter bekommt jede Farbe eine eigene Leiter. Jede Leiter beginnt mit der 5.", "wait": "tap", "when": "now", "focus": "table"},
		{"text": "Du hast eine 5! Tippe sie an und dann noch einmal, um sie in die Mitte zu legen.", "wait": "play", "when": "turn", "focus": "hand"},
		{"text": "An eine Leiter passt nur die Nachbarzahl: unter die 5 kommt die 4, darüber die 6. Lege eine leuchtende Karte – oder setze aus, wenn keine passt.", "wait": "play", "when": "turn", "focus": "hand"},
		{"text": "Genau so! Wer zuerst alle Karten los ist, gewinnt die Runde.", "wait": "done", "when": "now", "focus": ""},
	],
	"quartett": [
		{"text": "Beim Lumo-Quartett sammelst du vier Karten mit dem gleichen Wert. Das ist ein Quartett.", "wait": "tap", "when": "now", "focus": "hand"},
		{"text": "Tippe eine Karte an, von der du noch mehr haben möchtest.", "wait": "select", "when": "turn", "focus": "hand"},
		{"text": "Und jetzt tippe den Mitspieler an, den du danach fragen willst.", "wait": "play", "when": "turn", "focus": "seats"},
		{"text": "Hat er die Karte, bekommst du sie und darfst noch einmal fragen. Sonst ziehst du eine Karte vom Stapel.", "wait": "done", "when": "now", "focus": ""},
	],
}


static func steps(game: String) -> Array:
	return STEPS.get(game, []).duplicate(true)


## Die Übungsrunde zum Spiel.
static func demo(game: String) -> RefCounted:
	var rules := SESSION.create_rules(game)
	if rules == null:
		return null
	rules.setup({"players": PLAYERS, "rounds": 1, "seed": int(SEEDS[game]), "difficulty": 0,
		"result_id": "", "seats": ["squirrel", "owl", "turtle"]})
	return rules


## Passt der Startwert noch zur Erklärung? Leerer Text heißt ja.
static func ready(game: String) -> String:
	var rules := demo(game)
	if rules == null:
		return "kein Regelkern"
	match game:
		"stich":
			# Ein Mitspieler spielt aus; das Kind muss bedienen können, hat aber auch andere Farben.
			if rules.current() == 0:
				return "Kind spielt aus"
			var guard := 0
			while rules.current() != 0 and guard < 8:
				rules.play(rules.current(), SESSION.ai_move(rules, rules.current()))
				guard += 1
			var legal: Array = rules.legal_moves(0)
			if legal.is_empty() or legal.size() >= rules.s.r.hands[0].size():
				return "kein Bedienzwang sichtbar"
			if legal.size() < 2:
				return "nur eine Karte spielbar"
		"leiter":
			if rules.current() != 0:
				return "Kind beginnt nicht"
			var fives := 0
			for card: int in rules.s.r.hands[0]:
				if DECK.rank(card) == 5:
					fives += 1
			if fives < 1:
				return "Kind hat keine 5"
		"quartett":
			if rules.current() != 0:
				return "Kind beginnt nicht"
			if rules.legal_moves(0).size() < 3:
				return "zu wenig Auswahl"
	return ""
