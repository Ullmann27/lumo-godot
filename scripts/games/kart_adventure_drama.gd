extends RefCounted
## Abenteuer-Dramaturgie je Strecke („jede Strecke ein wildes Abenteuer“, Heinz 17.11.2026).
## Reine Daten: Akte mit Höhepunkt, Hindernisse, Gefahren-/Sprung-Bauteil-PLATZHALTER,
## Turbo-Felder und Item-Ringe als Anteil der Runde (0 … 1).
##
## Zuständigkeit (Abstimmung 17.11.2026):
## - Menü/Strecken-Bot (dieser Code): Streckenführung, Dramaturgie, Deko, Licht, Lesbarkeit,
##   Platzierung von Hindernissen, Item-Ringen, Turbo-Feldern und Bauteil-Markern.
## - Lumo · Design (lumo-2040/kart-*): baut die Gefahren- und Sprung-BAUTEILE selbst
##   (Lava-Spalt, Wasserfurt, bewegliche Fallen, Rampen, Loop-Anschlüsse). Hier stehen nur
##   benannte Marker3D-Platzhalter; Loop- und Rampengeometrie wird nicht angefasst.
## - Gameplay-Bot (lumo-kart/gameplay-*): Items und Fahrphysik. Hindernisse nutzen nur die
##   bestehende Schnittstelle world.action_obstacles (Treffer = 12 % Tempo, kein Ausfall).
##
## Fairness: Jeder Abschnitt lässt mindestens eine 4 m breite freie Spur. Vor jedem Bauteil
## steht ein Warnschild; Hindernisse sind so groß gezeichnet wie ihre Trefferzone.

## Bauteil-IDs, die Lumo · Design liefert (Schnittstelle, siehe docs/kart/abenteuer-strecken-20261117.md).
const BAUTEILE: Dictionary = {
	"gefahr_lavaspalt": "Lava-Spalt (quer, mit Brücke/Sprung, fair breite Spur)",
	"gefahr_wasserfurt": "Wasserfurt (flaches Wasser, bremst leicht, Spritz-Effekt)",
	"gefahr_pendel": "Bewegliche Falle: schwingendes Pendel/Liane im Takt",
	"gefahr_rollfelsen": "Bewegliche Falle: rollender Felsen quer, mit Pause",
	"gefahr_eisrutsche": "Glatteis-Abschnitt (weniger Grip, deutlich markiert)",
	"gefahr_meteor": "Meteor-Einschläge mit Schattenkreis-Vorwarnung",
	"gefahr_sandwirbel": "Sandwirbel, der seitlich schiebt",
	"gefahr_geysir": "Dampf-/Lava-Geysir im Takt",
	"sprung_rampe": "Sprungrampe auf der Hauptspur (Anschluss nahtlos an Straße)",
	"abkuerzung_risiko": "Abkürzung mit Risiko (schmal, offene Kante, schneller)",
}

const TRACKS: Dictionary = {
	"volcano_night": {
		"title": "Flucht vom Glutberg",
		"story": "Nachts aus dem Basaltdorf, über Lava-Spalten, durch den Glutstollen bis zur Turbo-Brücke.",
		"glow": Color("ff7a2e"), "decor": "volcano",
		"acts": [
			[0.06, "Akt 1: Basaltdorf"], [0.30, "Akt 2: Lava-Spalten"],
			[0.55, "Höhepunkt: Feuerbrücke"], [0.80, "Finale: Turbo-Abfahrt"],
		],
		"climax": [0.55, 0.68],
		"beats": [
			[0.20, "rocks", -1], [0.25, "bauteil", 1, "gefahr_geysir"],
			[0.33, "bauteil", 0, "gefahr_lavaspalt"], [0.38, "slalom", 0],
			[0.47, "bauteil", 1, "abkuerzung_risiko"], [0.58, "bauteil", 0, "gefahr_rollfelsen"],
			[0.62, "rocks", 1], [0.77, "bauteil", 0, "sprung_rampe"], [0.90, "rocks", -1],
		],
		"boosts": [0.15, 0.44, 0.84],
		"items": [[0.11, -2.7], [0.27, 2.7], [0.41, 0.0], [0.52, -2.7], [0.66, 2.7], [0.81, 0.0], [0.93, 2.7]],
	},
	"winter_sprint": {
		"title": "Gletscher-Abenteuer",
		"story": "Durch den Tannenwald, über den knirschenden Eissee, durch die Kristallhöhle zur Sternenrampe.",
		"glow": Color("8fe3ff"), "decor": "winter",
		"acts": [
			[0.06, "Akt 1: Tannenwald"], [0.30, "Akt 2: Eissee"],
			[0.60, "Höhepunkt: Lawinenrinne"], [0.82, "Finale: Sternenrampe"],
		],
		"climax": [0.58, 0.70],
		"beats": [
			[0.19, "slalom", 0], [0.31, "bauteil", 0, "gefahr_eisrutsche"],
			[0.40, "rocks", 1], [0.47, "bauteil", -1, "abkuerzung_risiko"],
			[0.60, "bauteil", 0, "gefahr_rollfelsen"], [0.64, "rocks", -1],
			[0.80, "bauteil", 0, "sprung_rampe"], [0.90, "slalom", 0],
		],
		"boosts": [0.15, 0.52, 0.86],
		"items": [[0.10, 2.7], [0.24, -2.7], [0.36, 0.0], [0.50, 2.7], [0.68, -2.7], [0.78, 0.0], [0.94, -2.7]],
	},
	"galaxy_ringway": {
		"title": "Sternenjagd im Ringway",
		"story": "Start an der Raumstation, durch das Asteroidenfeld, über den Meteorschauer zum Planetenring.",
		"glow": Color("b58bff"), "decor": "galaxy",
		"acts": [
			[0.06, "Akt 1: Raumstation"], [0.28, "Akt 2: Asteroidenfeld"],
			[0.50, "Höhepunkt: Meteorschauer"], [0.86, "Finale: Planetenring"],
		],
		"climax": [0.48, 0.62],
		"beats": [
			[0.20, "rocks", 1], [0.29, "slalom", 0], [0.36, "rocks", -1],
			[0.44, "bauteil", 1, "abkuerzung_risiko"], [0.52, "bauteil", 0, "gefahr_meteor"],
			[0.60, "rocks", 1], [0.88, "bauteil", 0, "sprung_rampe"],
		],
		"boosts": [0.15, 0.40, 0.66],
		"items": [[0.10, 0.0], [0.24, 2.7], [0.33, -2.7], [0.47, 0.0], [0.57, -2.7], [0.68, 2.7], [0.92, 0.0]],
	},
	"desert_drift": {
		"title": "Sturm über den Dünen",
		"story": "Vom Karawanenmarkt durch die Felsschlucht, mitten durch den Sandsturm zur Oasen-Furt.",
		"glow": Color("ffc35a"), "decor": "desert",
		"acts": [
			[0.06, "Akt 1: Karawanenmarkt"], [0.26, "Akt 2: Felsschlucht"],
			[0.55, "Höhepunkt: Sandsturm"], [0.78, "Finale: Oasen-Furt"],
		],
		"climax": [0.55, 0.68],
		"beats": [
			[0.18, "rocks", -1], [0.27, "slalom", 0], [0.35, "bauteil", 1, "abkuerzung_risiko"],
			[0.57, "bauteil", 0, "gefahr_sandwirbel"], [0.63, "rocks", 1],
			[0.72, "bauteil", 0, "sprung_rampe"], [0.79, "bauteil", 0, "gefahr_wasserfurt"],
			[0.91, "rocks", 1],
		],
		"boosts": [0.13, 0.46, 0.86],
		"items": [[0.10, 2.7], [0.22, -2.7], [0.31, 0.0], [0.45, 2.7], [0.60, -2.7], [0.70, 0.0], [0.88, -2.7]],
	},
	"jungle_temple": {
		"title": "Wilde Fahrt durch den Dschungel",
		"story": "Durch Lianen-Vorhänge, über die Wasserfurt, durch die versunkene Tempelhalle zur Seilbrücke.",
		"glow": Color("7cf2a6"), "decor": "jungle",
		"acts": [
			[0.06, "Akt 1: Lianenpfad"], [0.30, "Akt 2: Flussfurt"],
			[0.60, "Höhepunkt: Tempelhalle"], [0.82, "Finale: Seilbrücke"],
		],
		"climax": [0.66, 0.78],
		"beats": [
			[0.16, "lianen", 0], [0.22, "rocks", 1], [0.30, "bauteil", 0, "gefahr_wasserfurt"],
			[0.36, "lianen", 0], [0.44, "bauteil", -1, "abkuerzung_risiko"],
			[0.69, "bauteil", 0, "gefahr_pendel"], [0.74, "rocks", -1],
			[0.84, "bauteil", 0, "sprung_rampe"], [0.91, "lianen", 0],
		],
		"boosts": [0.12, 0.52, 0.88],
		"items": [[0.09, -2.7], [0.20, 2.7], [0.33, 0.0], [0.41, -2.7], [0.56, 2.7], [0.71, 0.0], [0.86, -2.7], [0.95, 2.7]],
	},
	"jungle_emerald_3600": {
		"title": "Expedition Dschungelherz",
		"story": "Vom Flusshafen über Wasserfall und Wurzelgrotte bis zur Kronenbrücke: die große Dschungel-Expedition.",
		"glow": Color("9dff7a"), "decor": "jungle",
		"acts": [
			[0.05, "Akt 1: Flusshafen"], [0.25, "Akt 2: Wasserfall"],
			[0.50, "Akt 3: Wurzelgrotte"], [0.72, "Höhepunkt: Kronenbrücke"],
		],
		"climax": [0.72, 0.82],
		"beats": [
			[0.10, "lianen", 0], [0.17, "rocks", -1], [0.27, "bauteil", 0, "gefahr_wasserfurt"],
			[0.34, "lianen", 0], [0.42, "bauteil", 1, "abkuerzung_risiko"], [0.52, "rocks", 1],
			[0.58, "bauteil", 0, "gefahr_pendel"], [0.66, "lianen", 0],
			[0.74, "bauteil", 0, "gefahr_rollfelsen"], [0.90, "rocks", -1],
		],
		# Vorhandene, bewährte Dschungelherz-Werte (unverändert übernommen).
		"boosts": [0.12, 0.42, 0.74],
		"items": [
			[0.045, -3.0], [0.13, 3.0], [0.21, 0.0], [0.29, -3.0],
			[0.365, 2.7], [0.455, 0.0], [0.535, -2.7], [0.63, 0.0],
			[0.705, 2.7], [0.795, -3.0], [0.875, 0.0], [0.95, 3.0],
		],
	},
	"sonnenhafen": {
		"title": "Grand Prix am Sonnenhafen",
		"story": "Von der Tribüne über die Klippen, durch den Hafen und über die lange Brücke zum großen Stunt.",
		"glow": Color("63dce9"), "decor": "harbor", "no_obstacles": true,
		"acts": [
			[0.06, "Akt 1: Tribüne"], [0.28, "Akt 2: Klippenstraße"],
			[0.52, "Höhepunkt: Hafen-Stunt"], [0.80, "Finale: Lange Brücke"],
		],
		"climax": [0.50, 0.60],
		"beats": [[0.34, "bauteil", 1, "abkuerzung_risiko"], [0.70, "bauteil", 0, "gefahr_wasserfurt"]],
	},
}

## Allgemeine Werte für Strecken ohne eigene Dramaturgie (bisheriges Verhalten).
const DEFAULT_BOOSTS: Array[float] = [0.12, 0.42, 0.74]
const DEFAULT_ITEMS: Array = [[0.18, -2.7], [0.34, 2.7], [0.53, 0.0], [0.69, -2.7], [0.86, 2.7]]


static func has(track_id: String) -> bool:
	return TRACKS.has(track_id)


static func profile(track_id: String) -> Dictionary:
	return TRACKS.get(track_id, {})


static func turbo_fractions(track_id: String) -> Array:
	return profile(track_id).get("boosts", DEFAULT_BOOSTS)


static func item_layout(track_id: String) -> Array:
	return profile(track_id).get("items", DEFAULT_ITEMS)
