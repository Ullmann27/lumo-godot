extends RefCounted
## Ehrlicher Sternenpfad für das Kart-Hauptmenü.
## Alle Werte leiten sich ausschließlich aus echten, gespeicherten Sternen und den
## bestehenden Freischalt-Schwellen in kart_catalog.gd / kart_fleet.gd ab.
## Es gibt keine erfundenen XP, keine Kaufwährung und keinen Premium-Pass.
const CATALOG = preload("res://scripts/games/kart_catalog.gd")
## Eine Fahrer-Stufe je 10 echte Sterne. Start ehrlich bei Stufe 1 mit 0 Sternen.
const STARS_PER_LEVEL := 10
## Wochen-Abenteuer: feste, nachvollziehbare Rotation über vorhandene Strecken.
const WEEKLY_TRACKS: Array[String] = [
	"volcano_night", "jungle_emerald_3600", "desert_drift", "sonnenhafen",
	"winter_sprint", "galaxy_ringway", "crystal_canyon", "zauberwald",
]


static func level(stars: int) -> int:
	return 1 + maxi(stars, 0) / STARS_PER_LEVEL


static func level_progress(stars: int) -> Vector2i:
	## x = Sterne innerhalb der aktuellen Stufe, y = Sterne bis zur nächsten Stufe.
	var safe := maxi(stars, 0)
	return Vector2i(safe % STARS_PER_LEVEL, STARS_PER_LEVEL)


static func milestones() -> Array[Dictionary]:
	## Echte Freischaltungen (Fahrer und Karts) mit ihrer Sternschwelle, aufsteigend.
	var result: Array[Dictionary] = []
	for driver in CATALOG.DRIVERS:
		if int(driver.get("unlock", 0)) > 0:
			result.append({"kind": "Fahrer", "id": str(driver.id), "name": str(driver.name), "stars": int(driver.unlock)})
	for kart in CATALOG.KARTS:
		if int(kart.get("unlock", 0)) > 0:
			result.append({"kind": "Kart", "id": str(kart.id), "name": str(kart.name), "stars": int(kart.unlock)})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.stars) < int(b.stars) or (int(a.stars) == int(b.stars) and str(a.id) < str(b.id)))
	return result


static func next_milestone(stars: int) -> Dictionary:
	for entry in milestones():
		if int(entry.stars) > stars:
			return entry
	return {}


static func path_progress(stars: int) -> Vector2i:
	## x = echte Sterne, y = Schwelle der nächsten Freischaltung (oder letzte, wenn alles frei).
	var all := milestones()
	if all.is_empty():
		return Vector2i(maxi(stars, 0), maxi(stars, 1))
	var goal := next_milestone(stars)
	if goal.is_empty():
		var last := int(all[-1].stars)
		return Vector2i(last, last)
	return Vector2i(maxi(stars, 0), int(goal.stars))


static func unlocked_count(stars: int) -> int:
	var count := 0
	for entry in milestones():
		if stars >= int(entry.stars):
			count += 1
	return count


static func weekly_track(available: Array, unix_time: float = -1.0) -> String:
	## ISO-ähnliche Wochennummer seit 1970 (Montag-Start), deterministisch und offline.
	var now := Time.get_unix_time_from_system() if unix_time < 0.0 else unix_time
	var week := int(floor((now / 86400.0 + 3.0) / 7.0))
	var pool: Array[String] = []
	for id in WEEKLY_TRACKS:
		if id in available:
			pool.append(id)
	if pool.is_empty():
		return ""
	return pool[posmod(week, pool.size())]
