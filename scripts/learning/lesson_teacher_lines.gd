extends RefCounted
## Spoken and printed demonstrations use the current material after one move.
## Each move is also available to the child independently on the board.
static func show_move(activity, grade: int) -> String:
	var count: int = activity.placed.size()
	match activity.kind:
		"syllables":
			var syllable: String = activity.syllables[count - 1]
			return "Hör mal, %s! Ich lege die Silbe an Platz %d." % [syllable, count]
		"equal_groups":
			var group: int = (count - 1) / activity.b + 1
			return "Mein Würfel kommt in Gruppe %d. Jede Gruppe soll gleich viele Würfel haben, nämlich %d." % [group, activity.b]
		"equal_sharing":
			var group: int = (count - 1) % activity.b + 1
			return "Gruppe %d bekommt einen Würfel. So bleibt das Verteilen gerecht." % group
		"fraction_parts":
			var filled: int = activity.initial_count() + count
			return "Jetzt sind %d von %d Teilen markiert." % [filled, activity.b] if grade <= 2 else (
				"Mit diesem Teil steigt der Zähler auf %d. Der Nenner bleibt %d, weil die Teile gleich groß bleiben." % [filled, activity.b])
		"bridge_hundred":
			var before: int = activity.a + 10 * (count - 1)
			return "Mein Streifen zählt zehn. Aus %d wird %d." % [before, before + 10] if grade <= 2 else (
				"Ich ergänze einen Zehner. %d + 10 = %d. Die Einerstelle bleibt gleich." % [before, before + 10])
		"subtract_ten":
			return "Ich nehme einen Würfel weg. Jetzt liegen noch %d im Feld." % (activity.a - count)
		"bridge_ten", "addition":
			var filled: int = activity.a + count
			if grade == 1:
				return "Ich lege einen Würfel dazu. Wir zählen von %d weiter auf %d." % [filled - 1, filled]
			if grade == 2 and filled == 9:
				return "Jetzt liegen neun Würfel. Nur ein Platz ist noch frei."
			if grade == 2 and filled < 10:
				return "Jetzt liegen %d. Bis zur vollen Zehnerreihe fehlen noch %d." % [filled, 10 - filled]
			if filled >= 10:
				return "Die Zehn ist voll." if filled == 10 else "Die erste Reihe ist voll. Ein Zehner und %d Einer ergeben %d." % [filled - 10, filled]
			return "Die Menge wächst um eins, also %d + 1 = %d." % [filled - 1, filled]
	return activity.explanation()
