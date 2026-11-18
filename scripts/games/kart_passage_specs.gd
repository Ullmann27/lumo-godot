extends RefCounted
## Entwurfswerte der LUMO-Passagen je Strecke (Meter auf der fertig geglätteten Fahrbahn).
## Logik: kart_passages.gd. Aufbau und Bewegung: kart_passage_art.gd.

## Entwurf je Strecke. "bridge": schmales Deck ohne Planke über einer Lücke, davor ebener,
## griffiger Vorplatz voller Breite. "swing": bewegtes Hindernis mit Wartelinie.
const SPECS: Dictionary = {
	"winter_sprint":
	[
		{
			"kind": "bridge",
			"id": "eisbruecke",
			"name": "Gletscher-Eisbrücke",
			"theme": "ice",
			"plaza_start": 80.0,
			"deck_start": 100.0,
			"deck_end": 124.0,
			"exit_end": 165.0,
			"deck_width": 3.6,
			"respawn": 90.0,
			"sign": "EISBRÜCKE\nLangsam ausrichten",
			"approach_text": "Eisbrücke! Bremsen, ausrichten, langsam hinüber.",
		},
	],
}
