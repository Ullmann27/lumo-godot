extends RefCounted
## Catalogue of the Lumo-Lauf courses. Every course is one pass along an existing
## Lumo Kart world; only names, colours and prop looks are defined here.

const COURSES: Array[Dictionary] = [
	{
		"id": "dschungelherz",
		"track": "jungle_emerald_3600",
		"name": "Dschungelherz",
		"kicker": "Lang & wild",
		"length": "3,6 km",
		"description":
		"Durch Riesenwurzeln, Grotten und über die Kronenbrücke – die längste Strecke.",
		"accent": Color("48d6a0"),
		"emblem": "leaf",
		"theme": "jungle",
		"seed": 71103,
	},
	{
		"id": "zauberwald",
		"track": "zauberwald",
		"name": "Zauberwald",
		"kicker": "Leuchtend & geheimnisvoll",
		"length": "2,0 km",
		"description":
		"Glühende Pilze, der Feensee-Tunnel und die Wurzelbibliothek bei Nacht.",
		"accent": Color("9c8cff"),
		"emblem": "tree",
		"theme": "forest",
		"seed": 24611,
	},
	{
		"id": "sonnenhafen",
		"track": "sonnenhafen",
		"name": "Sonnenhafen",
		"kicker": "Sonnig & schnell",
		"length": "1,9 km",
		"description":
		"An der Küste entlang, durch den Looping und mit dem großen Sprung übers Wasser.",
		"accent": Color("ffb648"),
		"emblem": "sun",
		"theme": "harbour",
		"seed": 55027,
	},
]

## Look of the run props per world. One geometry set, three clearly different skins.
const THEMES: Dictionary = {
	"jungle":
	{
		"hurdle": Color("8a5a34"),
		"hurdle_trim": Color("ffd75e"),
		"rock": Color("6f7f6a"),
		"rock_top": Color("4fae5f"),
		"crate": Color("b9824a"),
		"crate_trim": Color("ffe9a8"),
		"water": Color("2fd0c8"),
		"water_edge": Color("e9f7d2"),
		"pad": Color("ff7f50"),
		"pad_trim": Color("fff3c4"),
		"boost": Color("ffe45c"),
		"platform": Color("5cbf62"),
		"platform_side": Color("7a5232"),
		"flag": Color("2f8dff"),
		"roller": Color("7d8794"),
	},
	"forest":
	{
		"hurdle": Color("4a3a78"),
		"hurdle_trim": Color("7dffe6"),
		"rock": Color("5d4fa8"),
		"rock_top": Color("b9a6ff"),
		"crate": Color("3f5f8f"),
		"crate_trim": Color("9df3ff"),
		"water": Color("7a5cff"),
		"water_edge": Color("d8ccff"),
		"pad": Color("42e0c0"),
		"pad_trim": Color("f0fff9"),
		"boost": Color("8dfff0"),
		"platform": Color("5a6fd6"),
		"platform_side": Color("2c2f66"),
		"flag": Color("ff7ad9"),
		"roller": Color("6c63b8"),
	},
	"harbour":
	{
		"hurdle": Color("f4f1e8"),
		"hurdle_trim": Color("ff5b4a"),
		"rock": Color("d9793a"),
		"rock_top": Color("ffd08a"),
		"crate": Color("c79a5a"),
		"crate_trim": Color("2f6fb5"),
		"water": Color("35b8f2"),
		"water_edge": Color("fff7df"),
		"pad": Color("ff5b6e"),
		"pad_trim": Color("fff7df"),
		"boost": Color("ffd23a"),
		"platform": Color("f6d48a"),
		"platform_side": Color("9c6a3c"),
		"flag": Color("ff8a2a"),
		"roller": Color("8b97a8"),
	},
}


static func count() -> int:
	return COURSES.size()


static func course(index: int) -> Dictionary:
	return COURSES[clampi(index, 0, COURSES.size() - 1)]


static func index_of(id: String) -> int:
	for index in range(COURSES.size()):
		if str(COURSES[index].id) == id:
			return index
	return -1


static func theme(index: int) -> Dictionary:
	return THEMES[str(course(index).theme)]
