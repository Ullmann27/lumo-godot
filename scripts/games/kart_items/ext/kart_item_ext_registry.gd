extends RefCounted
## Verzeichnis der erweiterten Item-Verhalten (Welle 1, vorbereitet für Welle 2).
## Ein neues Item = eine Zeile in assets/kart/items/kart_items.json mit einem der
## Verhalten unten + eine Verhaltensdatei in effects/ + ein Icon unter
## assets/kart/hud/items/icon_<id>.webp + (optional) Töne in SOUNDS.
## Die Verhaltensdatei erbt kart_item_ext_effect.gd; die alte Item-Engine
## (kart_item_runtime.gd, kart_island.gd) bleibt unverändert die Grundlage.

const EFFECT_DIR := "res://scripts/games/kart_items/ext/effects/"
## Verhalten -> Verhaltensdatei (ohne Pfad und Endung).
const BEHAVIOURS: Dictionary = {
	"lightning_strike": "thunder_star",
	"frost_capsule": "frost_crystal",
	"fire_meteor": "fire_meteor",
	"fortress": "star_fortress",
	"whirlwind": "whirlwind",
	"gravity_wave": "gravity_wave",
	"star_decoy": "star_decoy",
	"turbo_xl": "turbo_xl",
}
## Original-Töne (tools/art/generate_kart_item_ext_audio.py) in assets/audio/kart/items/.
const SOUNDS: Array[String] = [
	"ext_warning",
	"thunder_charge",
	"thunder_strike",
	"frost_launch",
	"frost_hit",
	"frost_melt",
	"meteor_launch",
	"meteor_hit",
	"ember_hiss",
	"fortress_up",
	"fortress_end",
	"whirl_go",
	"whirl_hit",
	"gravity_wave",
	"decoy_up",
	"decoy_pop",
	"turbo_xl",
]
const ICON_DIR := "res://assets/kart/hud/items/"


static func has_behaviour(behaviour: String) -> bool:
	return BEHAVIOURS.has(behaviour)


static func behaviours() -> Array:
	return BEHAVIOURS.keys()


static func script_for(behaviour: String) -> Script:
	if not BEHAVIOURS.has(behaviour):
		return null
	var path: String = EFFECT_DIR + str(BEHAVIOURS[behaviour]) + ".gd"
	return load(path) as Script if ResourceLoader.exists(path) else null


static func icon_path(item_id: String) -> String:
	return ICON_DIR + "icon_" + item_id + ".webp"


static func has_sound(kind: String) -> bool:
	return SOUNDS.has(kind)
