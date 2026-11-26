extends RefCounted
## LUMO-Passagen der Kristallflut (reine Daten, gelesen von kart_passage_specs.gd).
## Zwei Abkürzungen als "flow" mit Bögen (Rivalen wählen die nähere Öffnung) und der
## Fontänenplatz: eine Wasserwand steigt im Takt auf einer Hälfte auf (blinkt vorher), die
## andere bleibt frei; jede Runde wechselt die Seite. Wartezone, Rettungspunkt und Band liegen
## im selben Checkpoint-Abschnitt (1763–2116 m).
const SPECS: Array = [
	{
		"kind": "flow",
		"id": "saeulengang",
		"name": "Säulengang",
		"theme": "signature",
		"zone_start": 1236.0,
		"zone_end": 1348.0,
		"narrow_width": 8.0,
		"arches":
		[
			[1236.0, -1.0],
			[1256.0, -1.0],
			[1276.0, -1.0],
			[1296.0, -1.0],
			[1316.0, -1.0],
			[1336.0, -1.0]
		],
		"sign": "SÄULENGANG\nLinks durch die Ruinen – rechts breit",
		"approach_text":
		"Die Ruineninsel! Links durch den Säulengang mit Turbo – rechts der breite Weg.",
	},
	{
		"kind": "flow",
		"id": "klippenweg",
		"name": "Klippen-Abkürzung",
		"theme": "signature",
		"zone_start": 2100.0,
		"zone_end": 2268.0,
		"narrow_width": 8.0,
		"arches":
		[
			[2100.0, 1.0],
			[2124.0, 1.0],
			[2148.0, 1.0],
			[2172.0, 1.0],
			[2196.0, 1.0],
			[2220.0, 1.0],
			[2244.0, 1.0],
			[2262.0, 1.0]
		],
		"sign": "KLIPPENWEG\nRechts am Meer mit Turbo – links breit",
		"approach_text":
		"Klippen-Abkürzung! Rechts am Meer entlang mit Turbo – links die breite Straße.",
	},
	{
		"kind": "gate",
		"id": "fontaenen",
		"name": "Fontänenplatz",
		"theme": "signature",
		"object": "light",
		"cue": "switch_chime",
		"effect": "bump",
		"alternate": true,
		"wait_start": 1888.0,
		"wait_line": 1916.0,
		"plane": 1924.0,
		"respawn": 1896.0,
		"lat_min": -6.6,
		"lat_max": -0.8,
		"open": 4.2,
		"warn": 1.6,
		"closed": 2.2,
		"band": 2.5,
		"offset": 0.3,
		"sign": "FONTÄNEN\nBlubbert es: andere Seite",
		"approach_text":
		"Der Fontänenplatz! Wo es blubbert, schießt gleich eine Wasserwand hoch – nimm die freie Seite.",
		"warn_text":
		"Blubb-blubb! Gleich spritzt die Fontäne – fahr auf die freie Seite oder warte kurz.",
		"go_text": "Wasser ist unten – weiter!",
		"hit_text":
		"Platsch! Die Fontäne hat dich nass gemacht. Beim Blubbern die andere Seite nehmen.",
	},
]
