extends RefCounted
## Original deterministic charts. Timing is seconds, independent of rendering FPS.
const SONGS = [
	{"id": "sternentanz", "name": "Sternentanz", "bpm": 96, "root": 60},
	{"id": "wolkenwalzer", "name": "Wolkenwalzer", "bpm": 108, "root": 65},
	{"id": "funkelreise", "name": "Funkelreise", "bpm": 120, "root": 67}
]
var notes: Array[Dictionary] = []
var time: float = -2.5
var duration: float = 0
var window: float = 0.24
var score: float = 0
var maximum: float = 0
var hits: int = 0
var misses: int = 0
var combo: int = 0
var best_combo: int = 0
var judgement: String = "Mach dich bereit!"
var held: Dictionary = {}
var song: Dictionary


func setup(song_index: int, difficulty: int = 0) -> void:
	song = SONGS[posmod(song_index, SONGS.size())]
	notes.clear()
	time = -2.5
	score = 0
	maximum = 0
	hits = 0
	misses = 0
	combo = 0
	best_combo = 0
	held.clear()
	window = [0.28, 0.22, 0.17][clampi(difficulty, 0, 2)]
	var beat: float = 60.0 / float(song.bpm)
	for i in range(40):
		var kind := "tap"
		if i % 10 == 4:
			kind = "hold"
		if i % 10 == 7:
			kind = "slide"
		if i % 10 == 9:
			kind = "star"
		var lane: int = [0, 1, 2, 3, 1, 0, 2, 2, 1, 3][i % 10]
		var length: float = beat * 0.85 if kind in ["hold", "slide"] else 0
		notes.append(
			{
				"time": 1.5 + i * beat * 1.35,
				"lane": lane,
				"target": posmod(lane + 1, 4),
				"kind": kind,
				"length": length,
				"state": 0,
				"quality": 0.0
			}
		)
		maximum += 200 if kind == "star" else 100
	duration = float(notes[-1].time) + 2.5


func advance(delta: float) -> void:
	time += maxf(0, delta)
	for note in notes:
		if int(note.state) == 0 and time > float(note.time) + window:
			_miss(note)
		elif int(note.state) == 1 and time >= float(note.time) + float(note.length):
			if held.has(int(note.lane)):
				_complete(note, float(note.quality))
			else:
				_miss(note)
		elif int(note.state) == 4 and time > float(note.time) + float(note.length) + window:
			_miss(note)


func press(lane: int) -> bool:
	held[lane] = true
	# The target of a slide is evaluated before a new note on the same lane.
	for note in notes:
		if int(note.state) == 4 and int(note.target) == lane:
			var error := absf(time - float(note.time) - float(note.length))
			if error <= window:
				_complete(note, minf(float(note.quality), _quality(error)))
				return true
	var nearest: Dictionary = {}
	var best: float = window + 0.001
	for note in notes:
		if int(note.state) != 0 or int(note.lane) != lane:
			continue
		var error := absf(time - float(note.time))
		if error < best:
			nearest = note
			best = error
	if nearest.is_empty():
		return false
	nearest.quality = _quality(best)
	if nearest.kind == "hold":
		nearest.state = 1
		judgement = "Halten …"
	elif nearest.kind == "slide":
		nearest.state = 4
		judgement = "Zur nächsten Spur!"
	else:
		_complete(nearest, float(nearest.quality))
	return true


func release(lane: int) -> void:
	held.erase(lane)
	for note in notes:
		if int(note.state) == 1 and int(note.lane) == lane:
			if time >= float(note.time) + float(note.length) - window * 0.55:
				_complete(note, float(note.quality))
			else:
				_miss(note)


func _quality(error: float) -> float:
	return 1.0 if error <= window * 0.38 else 0.7


func _complete(note: Dictionary, quality: float) -> void:
	note.state = 2
	score += quality * (200 if note.kind == "star" else 100)
	hits += 1
	combo += 1
	best_combo = maxi(best_combo, combo)
	judgement = "Perfekt!" if quality >= 0.99 else "Gut getroffen!"


func _miss(note: Dictionary) -> void:
	note.state = 3
	misses += 1
	combo = 0
	judgement = "Beim nächsten Ton klappt es!"


func accuracy() -> float:
	return 0 if maximum == 0 else score / maximum


func stars() -> int:
	if hits == 0:
		return 0
	return 3 if accuracy() >= 0.82 else (2 if accuracy() >= 0.50 else 1)
