extends RefCounted
## Angriffsskala: Begegnungen wachsen mit der Stadt (Anschlussauftrag Teil 6 und
## Nachtrag „echte Soldaten“). Reine Regeln ohne Szene und ohne Dorf-Oberfläche,
## damit ein späteres eigenes Strategiespiel sie weiterverwenden kann.
##
## Einordnung in die übrigen Regeln:
## - Stufe (build_village_raids.gd level_for) und Bild der Stufe
##   (build_village_schedule.gd stage: Gruppengröße ODER weitere Richtung – je
##   Stufe genau eine Eigenschaft) bleiben, wie sie sind.
## - Kleine Dörfer (bis BASE_PEOPLE · Gruppe/4 Angreifer, also bis etwa 60
##   Bewohner) rechnen wie bisher: eine Gruppe aus einer Richtung, und bis
##   GUARDS.SMALL_FORCE Wachen zählt jede wie die frühere einfache Wache. So bleibt
##   die erste Begegnung mit wenigen Wachen schaffbar.
## - Größere Städte locken ein Heer an, das mit den Bewohnern wächst: je
##   Bewohner ATTACK_SHARE Angreifer (bei Gruppe 4), jeder so stark wie ein
##   einfacher Soldat (POINTS_PER_ATTACKER). Eine gut vorbereitete Stadt – etwa
##   jeder achte Bewohner Soldat der passenden Art am richtigen Tor, dazu eine
##   Mauer – gewinnt knapp; ohne Verteidigung verliert sie. 1.000 Soldaten
##   wehren deshalb nicht mehr alles ab.
## - Ab der Stufe mit zwei Richtungen teilt sich ein großes Heer auf die Tore auf:
##   Verbände an einem Tor zählen nur dort, die Reserve in der Stadtmitte wird
##   geteilt. Entscheidend ist das schwächste Tor (Aufstellung zählt).
## - Wer verliert, verliert höchstens Vorräte und beschädigte Gebäude; nie die
##   Grundversorgung (raids.safe_farms) – das regelt build_village_raids.gd.
const SCHEDULE = preload("res://scripts/creative/build_village_schedule.gd")
const ATTACK_SHARE := 0.2
const BASE_PEOPLE := 12
const POINTS_PER_ATTACKER := 2.5
## Reihenfolge weiterer Richtungen: zuerst die Gegenseite, dann die Flanken.
const OPPOSITE := {"sued": "nord", "nord": "sued", "ost": "west", "west": "ost"}
const FLANKS := {
	"sued": ["west", "ost"],
	"nord": ["ost", "west"],
	"ost": ["sued", "nord"],
	"west": ["nord", "sued"]
}


## Heer einer Begegnung aus Bewohnerzahl und Stufe (wird bei der Ankündigung
## festgehalten, damit Vorhersage und Auswertung dieselben Zahlen nutzen).
static func army(population: int, level: int) -> Dictionary:
	var stage: Dictionary = SCHEDULE.stage(level)
	var grow := float(stage.group) / 4.0
	var people := roundi(float(maxi(0, population)) * ATTACK_SHARE * grow)
	var free := roundi(float(BASE_PEOPLE) * grow)
	var extra := maxi(0, people - free)
	return {
		"people": people if extra > 0 else int(stage.group),
		"extra": extra,
		"sides": int(stage.sides) if extra > 0 else 1,
		"group": int(stage.group),
	}


## Zusätzliche Angriffspunkte über die Grundstärke der Stufe hinaus.
static func extra_points(info: Dictionary) -> float:
	return float(info.get("extra", 0)) * POINTS_PER_ATTACKER


## Tore, an denen das Heer ankommt (erste = Hauptrichtung).
static func sides(primary: String, count: int) -> Array[String]:
	var result: Array[String] = [primary]
	var order: Array = [str(OPPOSITE.get(primary, "nord"))]
	order.append_array(FLANKS.get(primary, ["west", "ost"]))
	for side in order:
		if result.size() >= count:
			break
		result.append(str(side))
	return result


## Ein Satz für das Kind: wie viele kommen, von wo.
static func army_text(info: Dictionary, side_titles: Array) -> String:
	var people := int(info.get("people", 0))
	if side_titles.size() <= 1:
		return "Etwa %d Angreifer kommen zum %s." % [people, ", ".join(side_titles)]
	return (
		"Etwa %d Angreifer teilen sich auf: %s. Jedes dieser Tore braucht eigene Verbände."
		% [people, ", ".join(side_titles)]
	)
