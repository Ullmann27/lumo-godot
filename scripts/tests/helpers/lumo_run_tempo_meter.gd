extends RefCounted
## Measures the tempo of the Dschungelherz path from its plan: how much free
## run-up (in seconds on screen) a child has before each obstacle at a given
## speed. Obstacles closer together than GROUP_GAP metres count as one group
## (for example the stones in one stream); the time that matters is the free
## stretch before a group, from the end of whatever came before.

## About one held jump at Lumo's pace: obstacles this close form one sequence
## (a slalom, a log and a crab) that the child sees and plays as one.
const GROUP_GAP: float = 7.5


## Obstacles of the plan as [s0, s1, kind], sorted along the path.
static func obstacles(plan, gaps: Array) -> Array:
	var items: Array = []
	for gap in gaps:
		items.append([gap.x, gap.y, "hole"])
	for hurdle in plan.hurdles:
		items.append([float(hurdle.s) - 0.4, float(hurdle.s) + 0.4, "log"])
	for blocker in plan.blockers:
		items.append(
			[
				float(blocker.s) - float(blocker.radius),
				float(blocker.s) + float(blocker.radius),
				"rock"
			]
		)
	for enemy in plan.enemies:
		var span: float = absf(float(enemy.get("span", 0.0)))
		items.append(
			[
				float(enemy.s) - span - float(enemy.radius),
				float(enemy.s) + float(enemy.radius),
				str(enemy.kind)
			]
		)
	items = items.filter(
		func(item) -> bool:
			return float(item[0]) > float(plan.intro_end) and float(item[1]) < float(plan.finish_s)
	)
	items.sort_custom(func(a, b) -> bool: return float(a[0]) < float(b[0]))
	return items


## Free run-up before every group in metres: [[s, metres, kind], ...]
static func run_ups(items: Array, start: float) -> Array:
	var result: Array = []
	var end: float = start
	var index: int = 0
	while index < items.size():
		var group_start: float = float(items[index][0])
		var group_end: float = float(items[index][1])
		var kind: String = str(items[index][2])
		index += 1
		while index < items.size() and float(items[index][0]) - group_end < GROUP_GAP:
			group_end = maxf(group_end, float(items[index][1]))
			index += 1
		result.append([group_start, maxf(0.0, group_start - end), kind])
		end = maxf(end, group_end)
	return result


## Seconds on screen for each run-up at `speed` (m/s on screen): min, 10 % and median.
static func summary(ups: Array, speed: float) -> Dictionary:
	var times: Array[float] = []
	var lowest: Array = []
	for up in ups:
		times.append(float(up[1]) / speed)
	times.sort()
	for up in ups:
		if float(up[1]) / speed <= times[0] + 0.0001:
			lowest = up
	return {
		"min": times[0],
		"p10": times[int(times.size() * 0.1)],
		"median": times[times.size() / 2],
		"count": times.size(),
		"where": lowest,
	}
