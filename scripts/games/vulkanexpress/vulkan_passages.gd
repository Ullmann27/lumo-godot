extends RefCounted
## LUMO-Passagen des Vulkanexpress (reine Daten, gelesen von kart_passage_specs.gd).
## Meter auf der fertigen Fahrbahn (vulkan_course.gd). Abzweige als "flow" mit Bögen:
## Rivalen wählen die Öffnung, die ihnen näher ist (kart_passages.rival_control), die
## Trennwand selbst ist Fahrautorität in kart_signature_tracks.resolve_motion.
## Dampfgeysire: angekündigtes Querband, das jede Runde die Seite wechselt; die andere
## Hälfte bleibt immer frei. Glühende Risse (Orange) kündigen den Dampfstoß 1,6 s vorher an.
## Wartezone, Rettungspunkt und Band liegen im selben Checkpoint-Abschnitt (1969–2363 m).
const SPECS: Array = [
	{
		"kind": "flow",
		"id": "kristallgarten",
		"name": "Kristallgarten",
		"theme": "signature",
		"zone_start": 1140.0,
		"zone_end": 1272.0,
		"narrow_width": 8.0,
		"arches":
		[[1162.0, 1.0], [1182.0, 1.0], [1202.0, 1.0], [1222.0, 1.0], [1242.0, 1.0], [1262.0, 1.0]],
		"sign": "KRISTALLGARTEN\nRechts eng mit Turbo – links breit",
		"approach_text":
		"Der Kristallgarten! Rechts der enge Kristallpfad mit Turbo – links die breite Bahn.",
	},
	{
		"kind": "flow",
		"id": "hoehle",
		"name": "Vulkanhöhle",
		"theme": "signature",
		"zone_start": 1934.0,
		"zone_end": 2066.0,
		"narrow_width": 7.5,
		"arches":
		[
			[1956.0, -1.0],
			[1976.0, -1.0],
			[1996.0, -1.0],
			[2016.0, -1.0],
			[2036.0, -1.0],
			[2056.0, -1.0]
		],
		"sign": "VULKANHÖHLE\nLinks Lavafall-Galerie – rechts breit",
		"approach_text":
		"Ab in die Vulkanhöhle! Links die Lavafall-Galerie mit Turbo, rechts der breite Weg.",
	},
	{
		"kind": "gate",
		"id": "dampfgeysire",
		"name": "Dampfgeysire",
		"theme": "signature",
		"object": "lava",
		"cue": "lava_hiss",
		"effect": "bump",
		"alternate": true,
		"wait_start": 2200.0,
		"wait_line": 2228.0,
		"plane": 2236.0,
		"respawn": 2208.0,
		"lat_min": -6.6,
		"lat_max": -0.8,
		"open": 4.2,
		"warn": 1.6,
		"closed": 2.2,
		"band": 2.5,
		"offset": 0.6,
		"sign": "DAMPFGEYSIRE\nGlüht es orange: andere Seite",
		"approach_text":
		"Dampfgeysire! Wo der Boden orange glüht, zischt gleich Dampf – die andere Seite ist frei.",
		"warn_text":
		"Es glüht! Gleich zischt der Geysir – fahr auf die freie Seite oder warte kurz.",
		"go_text": "Dampf ist weg – weiter!",
		"hit_text": "Pfff! Der Dampf hat dich angestupst. Beim Glühen die andere Seite nehmen.",
	},
]
