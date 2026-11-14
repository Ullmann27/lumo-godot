extends RefCounted
## One native entrance per playable Godot world. Flutter host game tiles remain
## independent and retain their original routing, saves and child identities.
const ENTRIES: Array[Dictionary] = [
	{"destination": "kart", "title": "LUMO KART", "subtitle": "Sonnenhafen-Cup", "accent": "ffc94a", "featured": true},
	{"destination": "settlement", "title": "DORF & WIRTSCHAFT", "subtitle": "Dein lebendiges Dorf", "accent": "91efbd", "featured": false},
	{"destination": "jump", "title": "WOLKENINSELN", "subtitle": "Hüpfen & Entdecken", "accent": "53ddfd", "featured": false},
	{"destination": "puzzle", "title": "PUZZLE-ATELIER", "subtitle": "Bilder zum Leben erwecken", "accent": "c4a7ff", "featured": false},
	{"destination": "treasure", "title": "SCHATZSUCHE", "subtitle": "Das Inselgeheimnis", "accent": "ffd18d", "featured": false},
	{"destination": "rhythm", "title": "RHYTHM PARTY", "subtitle": "Spielen zum Beat", "accent": "ff9fd2", "featured": false},
	{"destination": "build", "title": "BAUWELT", "subtitle": "Bauen & Gestalten", "accent": "88eeb2", "featured": false},
	{"destination": "stars", "title": "STERNENJAGD", "subtitle": "Sterne entdecken", "accent": "b99bff", "featured": false},
]


static func launch_options_for(
	destination: String, original: Dictionary, grade: int, subject: String
) -> Dictionary:
	var known := false
	for portal in ENTRIES:
		if portal.destination == destination:
			known = true
			break
	if not known:
		return {}
	var options: Dictionary = original.duplicate(true)
	options["grade"] = clampi(grade, 1, 4)
	options["subject"] = "Deutsch" if subject == "Deutsch" else "Mathematik"
	if destination == "settlement":
		options["settlementMode"] = "settlement"
		options["livingVillage"] = true
	return options
