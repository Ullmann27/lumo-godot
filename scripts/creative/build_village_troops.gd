extends RefCounted
## Truppenarten, Ausbildungsstätten und Begegnungsauflösung (Nachtrag von Heinz
## vom 18.11.2026: echte Soldaten, Menschen, mittelalterlich – ohne Blut;
## Besiegte ziehen sich zurück oder geben auf).
##
## Reine Regeln ohne Szene und ohne Dorf-Oberfläche: Eingaben sind einfache
## Daten (Verbände als Wörterbücher, Schutzbauten als Stufen). Ein späteres
## eigenes Strategiespiel kann diese Datei unverändert weiterverwenden.
##
## Vier Arten mit klaren Stärken und Gegenstücken:
##   Schildwache  hält Tor und Mauer          – stark gegen Belagerer
##   Bogenschütze schießt von Turm und Mauer   – stark gegen Flieger
##   Speerträger  stellt sich Reitern entgegen – stark gegen Reiterangriffe
##   Reiter       schnell, fängt Plünderer ab  – stark gegen Plünderer
## Aufstellung zählt: Wer am angegriffenen Tor steht, zählt voll; die Reserve
## in der Stadtmitte kommt etwas später (80 %); andere Tore helfen kaum (30 %).
## Mauern stärken Schildwachen, Türme Bogenschützen, Gräben bremsen Reiter.
const KINDS := ["schild", "bogen", "speer", "reiter"]
const TYPES := {
	"schild": {
		"title": "Schildwache", "plural": "Schildwachen", "icon": "🛡",
		"cost": {"coins": 1}, "upkeep": 0, "site": "",
		"strength": 2.5,
		"why": "Schildwachen halten Tor und Mauer: Gegen Belagerer sind sie am stärksten.",
	},
	"bogen": {
		"title": "Bogenschütze", "plural": "Bogenschützen", "icon": "🏹",
		"cost": {"coins": 1, "wood": 2}, "upkeep": 0, "site": "schiessplatz",
		"strength": 2.5,
		"why": "Bogenschützen treffen auch Flieger und sind auf Türmen noch besser.",
	},
	"speer": {
		"title": "Speerträger", "plural": "Speerträger", "icon": "🔱",
		"cost": {"coins": 1, "wood": 1, "stone": 1}, "upkeep": 0, "site": "kaserne",
		"strength": 2.6,
		"why": "Speerträger stellen sich Reitern und Sturmangriffen entgegen.",
	},
	"reiter": {
		"title": "Reiter", "plural": "Reiter", "icon": "🐎",
		"cost": {"coins": 3, "food": 3}, "upkeep": 1, "site": "stall",
		"strength": 2.8,
		"why": "Reiter sind schnell und fangen Plünderer ab. Ihr Pferd frisst jeden Tag 1 Essen mit.",
	},
}
## Ausbildungsstätten: einmal bauen, dann kann die Art ausgebildet werden.
const SITES := {
	"schiessplatz": {"title": "Schießplatz", "cost": {"wood": 20, "stone": 6}, "for": "bogen"},
	"kaserne": {"title": "Kaserne", "cost": {"wood": 16, "stone": 16, "coins": 6}, "for": "speer"},
	"stall": {"title": "Stall", "cost": {"wood": 24, "stone": 8, "food": 20}, "for": "reiter"},
}
## Wer greift an? Drei Angreiferarten mit Gegenstücken (Faktor je Truppenart).
const ATTACKERS := {
	"pluenderer": {
		"title": "Plünderer", "factors": {"schild": 0.8, "bogen": 1.0, "speer": 1.0, "reiter": 1.7},
		"best": "reiter",
	},
	"belagerer": {
		"title": "Belagerer mit Reitern", "factors": {"schild": 1.4, "bogen": 1.1, "speer": 1.5, "reiter": 0.8},
		"best": "speer",
	},
	"flieger": {
		"title": "Flieger", "factors": {"schild": 0.5, "bogen": 1.8, "speer": 0.6, "reiter": 0.5},
		"best": "bogen",
	},
}
const SIDE_WEIGHT := {"same": 1.0, "mitte": 0.8, "other": 0.3}


static func title(kind: String, count := 2) -> String:
	if not TYPES.has(kind):
		return "Wache"
	return str(TYPES[kind].title) if count == 1 else str(TYPES[kind].plural)


static func cost(kind: String, count: int) -> Dictionary:
	var total := {}
	var unit: Dictionary = TYPES.get(kind, TYPES.schild).cost
	for resource in unit:
		total[resource] = int(unit[resource]) * count
	return total


## Zusätzliches Essen pro Tag (Pferde), über den Bewohnerbedarf hinaus.
static func upkeep(units: Array) -> int:
	var total := 0
	for unit in units:
		total += int(TYPES.get(str(unit.get("type", "schild")), TYPES.schild).upkeep) * int(unit.get("size", 0))
	return total


static func site_needed(kind: String) -> String:
	return str(TYPES.get(kind, TYPES.schild).site)


## Wie stark ist ein Verband gegen diese Angreifer an diesem Tor?
## parts: Stufen der Schutzbauten {"wall", "tower", "ditch", ...}.
static func unit_points(unit: Dictionary, attacker: String, side: String, parts: Dictionary) -> float:
	var kind := str(unit.get("type", "schild"))
	var spec: Dictionary = TYPES.get(kind, TYPES.schild)
	var factor := float((ATTACKERS.get(attacker, ATTACKERS.pluenderer).factors as Dictionary).get(kind, 1.0))
	var post := str(unit.get("post", "mitte"))
	var place := float(SIDE_WEIGHT.same if post == side else (SIDE_WEIGHT.mitte if post == "mitte" else SIDE_WEIGHT.other))
	var cover := 1.0
	if kind == "schild":
		cover += 0.1 * float(parts.get("wall", 0)) + 0.1 * float(parts.get("gate", 0))
	elif kind == "bogen":
		cover += 0.15 * float(parts.get("tower", 0))
	elif kind == "speer":
		cover += 0.1 * float(parts.get("ditch", 0))
	return float(unit.get("size", 0)) * float(spec.strength) * factor * place * cover


static func points(units: Array, attacker: String, side: String, parts: Dictionary) -> float:
	var total := 0.0
	for unit in units:
		total += unit_points(unit, attacker, side, parts)
	return total


## Ein Satz für das Kind: wer kommt, von wo, und welche Truppe hilft.
static func advice(attacker: String, side_title: String) -> String:
	var spec: Dictionary = ATTACKERS.get(attacker, ATTACKERS.pluenderer)
	var best := str(spec.best)
	return "%s kommen zum %s. Am besten helfen %s dort: %s" % [
		str(spec.title), side_title, str(TYPES[best].plural), str(TYPES[best].why)]


## Kindgerechter Ausgang ohne Gewalt: Angreifer ziehen sich zurück oder geben auf.
static func outcome_text(won: bool, attacker: String) -> String:
	var who := str(ATTACKERS.get(attacker, ATTACKERS.pluenderer).title)
	if won:
		return "Die %s sehen die Aufstellung, geben auf und ziehen ab." % who
	return "Die %s kommen durch. Deine Truppen ziehen sich geordnet zurück; niemand wird verletzt." % who
