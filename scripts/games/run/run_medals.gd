extends RefCounted
## The medal of a finished Lumo-Lauf race. One rule for every world:
##   Bronze  reached the finish
##   Silber  reached the finish before Fips
##   Gold    before Fips and without a single bump or fall (no stumble)
## Only a finished run gives a medal; a paused, abandoned or interrupted run
## changes nothing. The best medal per child and course is kept with the best
## results (run_session.gd, run_records.cfg) and shown in the course choice.

const TUNING = preload("res://scripts/games/run/run_tuning.gd")
const IDS: Array[String] = ["", "bronze", "silver", "gold"]
const TITLES: Array[String] = ["Keine Medaille", "Bronze", "Silber", "Gold"]
const COLOURS: Array[Color] = [Color("8a95a8"), Color("d98a4e"), Color("d8e2ee"), Color("ffcf3a")]
const RIMS: Array[Color] = [Color("4d5666"), Color("8a4a1f"), Color("8b97a8"), Color("b8860b")]


static func medal_for(finished: bool, before_rival: bool, stumbles: int) -> int:
	if not finished:
		return TUNING.MEDAL_NONE
	if not before_rival:
		return TUNING.MEDAL_BRONZE
	return TUNING.MEDAL_GOLD if stumbles == 0 else TUNING.MEDAL_SILVER


static func id_of(medal: int) -> String:
	return IDS[clampi(medal, 0, 3)]


static func title(medal: int) -> String:
	return TITLES[clampi(medal, 0, 3)]


static func colour(medal: int) -> Color:
	return COLOURS[clampi(medal, 0, 3)]


## The rule in the child's words, as shown under the result.
static func rule_text(rival_name: String) -> String:
	var fips: String = rival_name if not rival_name.is_empty() else "dem Rivalen"
	return "Bronze: im Ziel · Silber: vor %s · Gold: vor %s und ohne Sturz" % [fips, fips]


## "2,4" for 2.43 seconds.
static func seconds_text(seconds: float) -> String:
	return ("%.1f" % seconds).replace(".", ",")


## A round medal with its ribbon, centred at `centre`.
static func draw(canvas: CanvasItem, centre: Vector2, radius: float, medal: int) -> void:
	var index: int = clampi(medal, 0, 3)
	var ribbon := Color("2f6fdc") if index > 0 else Color("4d5666")
	for side in [-1.0, 1.0]:
		(
			canvas
			. draw_colored_polygon(
				PackedVector2Array(
					[
						centre + Vector2(side * radius * 0.15, -radius * 0.6),
						centre + Vector2(side * radius * 0.95, -radius * 2.0),
						centre + Vector2(side * radius * 0.35, -radius * 2.0),
						centre + Vector2(-side * radius * 0.25, -radius * 0.6),
					]
				),
				ribbon.darkened(0.2 if side > 0.0 else 0.0)
			)
		)
	canvas.draw_circle(centre, radius, RIMS[index])
	canvas.draw_circle(centre, radius * 0.82, COLOURS[index])
	canvas.draw_circle(
		centre + Vector2(-radius * 0.25, -radius * 0.25), radius * 0.22, Color(1, 1, 1, 0.35)
	)
	if index > 0:
		var points := PackedVector2Array()
		for step in range(10):
			var angle: float = -PI * 0.5 + TAU * float(step) / 10.0
			var reach: float = radius * (0.5 if step % 2 == 0 else 0.22)
			points.append(centre + Vector2(cos(angle), sin(angle)) * reach)
		canvas.draw_colored_polygon(points, RIMS[index])
