extends RefCounted
## LUMO-Passagen von Wolkensturm (reine Daten, gelesen von kart_passage_specs.gd).
## Skyway-Gabel: Rivalen wählen die Öffnung, die ihnen näher ist (links Lobby mit Turbo,
## rechts breite Außenbahn). Lufttaxi-Kreuzung: Das Taxi schwebt nur während der roten
## Phase über eine Hälfte; die andere bleibt frei. Seite wechselt jede Runde (alternate).
## Wartezone, Rettungspunkt und Band liegen im selben Checkpoint-Abschnitt (2906–3322 m).
const SPECS: Array = [
	{
		"kind": "flow",
		"id": "gabel",
		"name": "Skyway-Gabel",
		"theme": "signature",
		"zone_start": 2292.0,
		"zone_end": 2434.0,
		"narrow_width": 8.0,
		"arches":
		[
			[2314.0, -1.0],
			[2336.0, -1.0],
			[2358.0, -1.0],
			[2380.0, -1.0],
			[2402.0, -1.0],
			[2424.0, -1.0]
		],
		"sign": "SKYWAY-GABEL\nLinks Lobby mit Turbo – rechts breit",
		"approach_text":
		"Die Skyway-Gabel! Links durch die Lobby mit Turbo – rechts die breite Außenbahn.",
	},
	{
		"kind": "gate",
		"id": "lufttaxi",
		"name": "Lufttaxi-Kreuzung",
		"theme": "signature",
		"object": "robot",
		"cue": "robot_beep",
		"effect": "bump",
		"alternate": true,
		"wait_start": 2968.0,
		"wait_line": 2996.0,
		"plane": 3004.0,
		"respawn": 2976.0,
		"lat_min": -6.6,
		"lat_max": -0.8,
		"open": 4.2,
		"warn": 1.6,
		"closed": 2.2,
		"band": 2.5,
		"offset": 1.1,
		"sign": "LUFTTAXI\nBlinkt es: andere Seite",
		"approach_text":
		"Lufttaxi-Kreuzung! Blinkt die Linie, schwebt gleich ein Taxi vorbei – nimm die freie Seite.",
		"warn_text": "Piep-piep! Das Lufttaxi kommt – fahr auf die freie Seite oder warte kurz.",
		"go_text": "Taxi ist weg – weiter!",
		"hit_text": "Huch, das Lufttaxi hat dich angestupst! Bei Rot die freie Seite nehmen.",
	},
]
