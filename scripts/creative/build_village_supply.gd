extends RefCounted
## Versorgungsrechnung der Dorfwelt (Teil 5 von Heinz' Auftrag vom 18.11.2026).
##
## Alle Zahlen kommen aus den echten Spielregeln (build_settlement_economy.gd):
##   - ein Bewohner isst 1 Nahrung pro Tag; eine Wache zählt als versorgter
##     Bewohner (wer rekrutiert wird, wechselt nur die Rolle),
##   - ein arbeitender Bauernhof erntet 5 Karotten mit genug Wasser (sonst 3),
##     +1 ab Region 1 und +2 mit dem Bewässerungsprojekt (also bis zu 8),
##   - Wohnraum: 2 Gründer + 4 je Wohnhaus,
##   - Wasser: 4 + 12 je Brunnen + 12 aus dem Bewässerungsprojekt,
##   - ein Hof, ein Haus oder ein Brunnen belegt einen Bauplatz.
## Entwurfsannahmen (offen ausgewiesen): 20 % Produktionsüberschuss,
## 25 % Zuschlag an Bauplätzen für Wege, Lager, Betriebe und Verteidigung.
## Reine Rechnung, kein Spielstand. Integer-Arithmetik: keine Rundungsfehler.
const ECONOMY = preload("res://scripts/creative/build_settlement_economy.gd")
## 20 % Überschuss = Faktor 12/10.
const SURPLUS_NUMERATOR := 12
const SURPLUS_DENOMINATOR := 10
## 25 % Zuschlag an Bauplätzen = Faktor 5/4.
const MARGIN_NUMERATOR := 5
const MARGIN_DENOMINATOR := 4
const FOOD_PER_PERSON := 1
const HOUSE_CAPACITY := 4
const FOUNDERS := 2
const WELL_WATER := 12
const BASE_WATER := 4
const IRRIGATION_WATER := 12
const SPACING := 5.3


static func _ceil_div(numerator: int, denominator: int) -> int:
	return (numerator + denominator - 1) / denominator if numerator > 0 else 0


## Tagesertrag eines arbeitenden Hofs nach den echten Regeln.
static func farm_yield(region: int, irrigation: bool, enough_water := true) -> int:
	return (5 if enough_water else 3) + (1 if region >= 1 else 0) + (2 if irrigation else 0)


## Benötigte Höfe = aufrunden((Zivil + Wachen) × 1,20 / Tagesertrag).
static func farms_needed(civilians: int, guards: int, daily_yield: int) -> int:
	var people := maxi(0, civilians) + maxi(0, guards)
	return _ceil_div(people * FOOD_PER_PERSON * SURPLUS_NUMERATOR, SURPLUS_DENOMINATOR * maxi(1, daily_yield))


static func houses_needed(people: int) -> int:
	return _ceil_div(maxi(0, people - FOUNDERS), HOUSE_CAPACITY)


static func wells_needed(people: int, irrigation: bool) -> int:
	return _ceil_div(maxi(0, people - BASE_WATER - (IRRIGATION_WATER if irrigation else 0)), WELL_WATER)


## Vollständiger Plan für eine Stadt: Höfe, Häuser, Brunnen, Bauplätze.
static func plan(civilians: int, guards: int, daily_yield: int, irrigation: bool) -> Dictionary:
	var people := maxi(0, civilians) + maxi(0, guards)
	var farms := farms_needed(civilians, guards, daily_yield)
	var houses := houses_needed(people)
	var wells := wells_needed(people, irrigation)
	var base := farms + houses + wells
	var cells := _ceil_div(base * MARGIN_NUMERATOR, MARGIN_DENOMINATOR)
	return {
		"civilians": civilians,
		"guards": guards,
		"people": people,
		"daily_yield": daily_yield,
		"farms": farms,
		"houses": houses,
		"wells": wells,
		"base_cells": base,
		"cells": cells,
		"farm_area_m2": snappedf(float(farms) * SPACING * SPACING, 0.01),
		"food_per_day": farms * daily_yield,
		"need_per_day": people * FOOD_PER_PERSON,
	}


## Kleinste quadratische Seitenlänge (in Zellen), die bei einem bebaubaren
## Anteil `share` (0..1) mindestens `cells` nutzbare Zellen enthält.
static func square_side_for(cells: int, share: float) -> int:
	var side := 1
	while float(side * side) * share < float(cells):
		side += 1
	return side


## Wie viele Tage reicht der Vorrat? Mit laufender Ernte (`production`) und
## ohne sie (eine ausgefallene Ernte nach der anderen). -1 = der Vorrat wächst.
static func reserve(stock: int, production: int, need: int) -> Dictionary:
	var safe_need := maxi(1, need)
	var without_harvest := maxi(0, stock) / safe_need
	var balance := production - need
	var with_harvest := -1 if balance >= 0 else maxi(0, stock) / -balance
	return {"stock": stock, "production": production, "need": need, "balance": balance,
		"days_without_harvest": without_harvest, "days": with_harvest}


## Kindgerechter Satz mit echten Zahlen, z. B. „Dein Vorrat reicht noch 4 Tage.“
static func reserve_text(info: Dictionary) -> String:
	var days_text := func(days: int) -> String: return "1 Tag" if days == 1 else "%d Tage" % days
	if int(info.need) <= 0:
		return "Niemand braucht gerade Essen."
	if int(info.days) >= 0:
		return "Dein Vorrat reicht noch %s. Baue mehr Bauernhöfe!" % days_text.call(int(info.days))
	if int(info.days_without_harvest) == 0:
		return "Die Ernte reicht, aber dein Lager ist leer. Eine schlechte Ernte wird knapp."
	return "Dein Vorrat reicht noch %s, auch wenn eine Ernte ausfällt." % days_text.call(
		int(info.days_without_harvest)
	)


## Erwartete Tagesernte des Spielerdorfs aus den echten Regeln (ohne Brot).
static func expected_harvest(model, town: Dictionary) -> int:
	var enough_water: bool = ECONOMY.water_capacity(model, town) >= int(town.population)
	var irrigation := bool(town.get("city_projects", {}).get("irrigation", false))
	return model._working(town, "farm") * farm_yield(int(town.region), irrigation, enough_water)


static func town_reserve(model, town: Dictionary) -> Dictionary:
	return reserve(int(town.resources.food), expected_harvest(model, town), int(town.population))
