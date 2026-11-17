extends RefCounted
## Original deterministic charts. Timing is seconds, independent of rendering FPS.
const SONGS = [
	{"id": "sternentanz", "name": "Sternentanz", "bpm": 96, "root": 60},
	{"id": "wolkenwalzer", "name": "Wolkenwalzer", "bpm": 108, "root": 65},
	{"id": "funkelreise", "name": "Funkelreise", "bpm": 120, "root": 67},
	{"id": "mondfunkeln", "name": "Mondfunkeln", "bpm": 88, "root": 57}
]
# Each original song has an identifiable phrase. Difficulty changes spacing,
# never the amount of rewards available; every chart contains forty notes.
const PHRASES = [
	{"lanes": [0, 1, 2, 3, 1, 0, 2, 2, 1, 3], "gaps": [1, 1, 1, 1, 2, 1, 1, 2, 1, 1]},
	{"lanes": [0, 1, 2, 1, 2, 3, 2, 1, 0, 1], "gaps": [1, 1, 2, 1, 2, 2, 1, 2, 2, 1]},
	{"lanes": [3, 1, 2, 0, 2, 3, 1, 0, 2, 1], "gaps": [1, 2, 1, 1, 2, 1, 2, 2, 1, 1]},
	{"lanes": [1, 1, 2, 2, 3, 2, 0, 3, 2, 0], "gaps": [2, 1, 2, 1, 2, 2, 1, 2, 1, 2]}
]
const DIFFICULTY_NAMES := ["Entdecken", "Abenteuer", "Sternen-Profi"]
const COMBO_MILESTONES: Array[int] = [5, 10, 20]
const COMBO_BONUS_POINTS := {5: 10, 10: 25, 20: 50}
const COMBO_CHEERS := {
	5: "Combo 5! Super!",
	10: "Combo 10! Fantastisch!",
	20: "Combo 20! Sternenparty!"
}
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
var combo_bonus: float = 0
var last_cheer: int = 0
var judgement: String = "Mach dich bereit!"
var held: Dictionary = {}
var song: Dictionary


func setup(song_index: int, difficulty: int = 0) -> void:
	song_index = posmod(song_index, SONGS.size())
	song = SONGS[song_index]
	notes.clear()
	time = -2.5
	score = 0
	maximum = 0
	hits = 0
	misses = 0
	combo = 0
	best_combo = 0
	combo_bonus = 0
	last_cheer = 0
	held.clear()
	window = [0.28, 0.22, 0.17][clampi(difficulty, 0, 2)]
	var beat: float = 60.0 / float(song.bpm)
	var phrase: Dictionary = PHRASES[posmod(song_index, SONGS.size())]
	var spacing: float = [2.0, 1.5, 1.0][clampi(difficulty, 0, 2)]
	var next_beat := 4.0
	for i in range(40):
		var kind := "tap"
		if i % 10 == 4:
			kind = "hold"
		if i % 10 == 7:
			kind = "slide"
		if i % 10 == 9:
			kind = "star"
		var lane: int = int(phrase.lanes[i % 10])
		# Alternating phrases answer each other without changing the familiar
		# first phrase or requiring a swipe across all four touch targets.
		if song_index != 0 and i / 10 % 2 == 1:
			lane = 3 - lane
		var gap: float = float(phrase.gaps[i % 10]) * spacing
		var length: float = beat * minf(1.0, gap * 0.55) if kind in ["hold", "slide"] else 0
		notes.append(
			{
				"time": next_beat * beat,
				"lane": lane,
				"target": lane + 1 if lane < 3 else lane - 1,
				"kind": kind,
				"length": length,
				"state": 0,
				"quality": 0.0
			}
		)
		maximum += 200 if kind == "star" else 100
		next_beat += gap
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
	if lane < 0 or lane >= 4:
		return false
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
	last_cheer = 0
	if COMBO_BONUS_POINTS.has(combo):
		last_cheer = combo
		combo_bonus += float(COMBO_BONUS_POINTS[combo])
		judgement = str(COMBO_CHEERS[combo])
	else:
		judgement = "Perfekt!" if quality >= 0.99 else "Gut getroffen!"


func _miss(note: Dictionary) -> void:
	note.state = 3
	misses += 1
	combo = 0
	last_cheer = 0
	judgement = "Beim nächsten Ton klappt es!"


func accuracy() -> float:
	return 0 if maximum == 0 else score / maximum


func stars() -> int:
	if hits == 0:
		return 0
	return 3 if accuracy() >= 0.82 else (2 if accuracy() >= 0.50 else 1)


func total_score() -> int:
	return int(score + combo_bonus)


func combo_xp() -> int:
	if best_combo >= 20:
		return 6
	if best_combo >= 10:
		return 4
	if best_combo >= 5:
		return 2
	return 0


func reward_xp() -> int:
	return 12 + stars() * 4 + combo_xp()
