extends RefCounted
## Deterministic village-defence rules for the Bauwelt strategy layer.
##
## Lumo's robo squads and buildings defend four approach lanes (north, east,
## south, west) against the cheeky hare bandits. Four unit roles counter each
## other in a cycle: spear beats rider, rider beats archer, archer beats
## knight, knight beats spear. Hares never destroy anything: a breach makes
## them occupy buildings (flag changes, production pauses) until a squad
## chases them off again.
##
## Difficulty is a step function of `level` (chapter progress plus defended
## waves). It never reacts to the current lead of the child inside a battle.

const LANES: Array[String] = ["north", "east", "south", "west"]
const LANE_TITLES := {"north": "Norden", "east": "Osten", "south": "Süden", "west": "Westen"}
const ROLES: Array[String] = ["speer", "bogen", "ritter", "reiter"]
const BEATS := {"speer": "reiter", "reiter": "bogen", "bogen": "ritter", "ritter": "speer"}
const ADVANTAGE := 1.5
const DISADVANTAGE := 0.7
const MAX_TICKS := 60
const MAX_LEVEL := 22
const MAX_WALL := 3
const MAX_TOWERS := 3
const MAX_SQUAD := 60

const UNITS := {
	"speer": {
		"title": "Speer-Robo", "enemy": "Hasen-Speerträger", "hp": 10.0, "atk": 3.0,
		"ranged": false, "cost": {"wood": 2, "coins": 1}
	},
	"bogen": {
		"title": "Bogen-Robo", "enemy": "Hasen-Schleuderer", "hp": 7.0, "atk": 2.6,
		"ranged": true, "cost": {"wood": 3, "stone": 1}
	},
	"ritter": {
		"title": "Schild-Ritter", "enemy": "Hasen-Schildträger", "hp": 15.0, "atk": 2.6,
		"ranged": false, "cost": {"stone": 3, "coins": 1}
	},
	"reiter": {
		"title": "Roller-Reiter", "enemy": "Hasen-Hoppelreiter", "hp": 11.0, "atk": 3.6,
		"ranged": false, "cost": {"wood": 2, "coins": 3}
	},
}

const STRUCTURES := {
	"wall": {"title": "Mauer", "hp": 24.0, "cost": {"stone": 4, "wood": 1}},
	"tower": {"title": "Wachturm", "damage": 3.2, "cost": {"stone": 3, "wood": 3}},
	"gate": {"title": "Tor", "hp": 16.0, "cost": {"wood": 4, "stone": 2}},
	"watchpost": {"title": "Wachposten", "tower_bonus": 0.2, "cost": {"wood": 3, "coins": 2}},
}


## Difficulty step: chapter (1..12) plus defended waves (up to ten more).
## It only changes between battles, never during one.
static func level_for(chapter: int, waves_won: int) -> int:
	return clampi(clampi(chapter, 1, 12) + clampi(waves_won, 0, MAX_LEVEL - 12), 1, MAX_LEVEL)


static func multiplier(attacker: String, defender: String) -> float:
	if BEATS.get(attacker, "") == defender:
		return ADVANTAGE
	if BEATS.get(defender, "") == attacker:
		return DISADVANTAGE
	return 1.0


static func counter_of(role: String) -> String:
	for candidate in BEATS:
		if BEATS[candidate] == role:
			return candidate
	return "speer"


## Empty, valid defence layout.
static func empty_defense() -> Dictionary:
	var lanes := {}
	for lane in LANES:
		lanes[lane] = {"wall": 0, "towers": 0, "gate": false, "squad": _empty_squad()}
	return {"lanes": lanes, "watchpost": false}


static func _empty_squad() -> Dictionary:
	var squad := {}
	for role in ROLES:
		squad[role] = 0
	return squad


static func valid_defense(defense: Variant) -> bool:
	if not defense is Dictionary or not defense.get("lanes") is Dictionary:
		return false
	if not defense.get("watchpost") is bool:
		return false
	if defense.lanes.size() != LANES.size():
		return false
	for lane in LANES:
		var data: Variant = defense.lanes.get(lane)
		if not data is Dictionary or not data.get("squad") is Dictionary:
			return false
		if not _int_in(data.get("wall"), 0, MAX_WALL) or not _int_in(data.get("towers"), 0, MAX_TOWERS):
			return false
		if not data.get("gate") is bool:
			return false
		if data.squad.size() != ROLES.size():
			return false
		for role in ROLES:
			if not _int_in(data.squad.get(role), 0, MAX_SQUAD):
				return false
	return true


static func _int_in(value: Variant, low: int, high: int) -> bool:
	if not (value is int or value is float):
		return false
	return float(value) == floor(float(value)) and int(value) >= low and int(value) <= high


## How strong a lane looks to the hare scouts (used by the wave AI).
static func lane_strength(defense: Dictionary, lane: String) -> float:
	var data: Dictionary = defense.lanes[lane]
	var score := float(data.wall) * STRUCTURES.wall.hp + (STRUCTURES.gate.hp if data.gate and int(data.wall) > 0 else 0.0)
	score += float(data.towers) * STRUCTURES.tower.damage * 8.0
	for role in ROLES:
		score += float(data.squad[role]) * UNITS[role].hp * 0.5 + float(data.squad[role]) * UNITS[role].atk * 3.0
	return score


## Total unit budget of a wave. Strictly increasing step per level.
static func wave_budget(level: int) -> int:
	var step := clampi(level, 1, MAX_LEVEL)
	return 4 + step * 3 + (step * step) / 10


static func enemy_toughness(level: int) -> float:
	return 1.0 + 0.03 * float(clampi(level, 1, MAX_LEVEL) - 1)


static func lanes_attacked(level: int) -> int:
	return 1 if level <= 2 else (2 if level <= 6 else 3)


## The hare plan: scout every lane, hit the weakest hardest and pick the role
## that counters what defends there. Deterministic for a given input.
static func plan_wave(level: int, defense: Dictionary) -> Dictionary:
	var order: Array = LANES.duplicate()
	order.sort_custom(func(a, b):
		var sa := lane_strength(defense, a)
		var sb := lane_strength(defense, b)
		return sa < sb if not is_equal_approx(sa, sb) else LANES.find(a) < LANES.find(b))
	var budget := wave_budget(level)
	var shares: Array = [[1.0], [0.65, 0.35], [0.55, 0.28, 0.17]][lanes_attacked(level) - 1]
	var groups := {}
	var assigned := 0
	for index in range(shares.size()):
		var lane: String = order[index]
		var count := int(round(budget * float(shares[index]))) if index < shares.size() - 1 else budget - assigned
		assigned += count
		groups[lane] = _composition(level, defense.lanes[lane].squad, count)
	return {
		"level": level,
		"main_lane": order[0],
		"groups": groups,
		"toughness": enemy_toughness(level),
		"budget": budget,
	}


static func _composition(level: int, squad: Dictionary, count: int) -> Dictionary:
	var result := _empty_squad()
	if count <= 0:
		return result
	if level <= 2:
		result.speer = count - count / 3
		result.bogen = count / 3
		return result
	# Counter the strongest defending role; keep a mixed rest from level 5 on.
	var strongest := "speer"
	var best := -1
	for role in ROLES:
		if int(squad[role]) > best:
			best = int(squad[role])
			strongest = role
	var counter := counter_of(strongest) if best > 0 else "reiter"
	var focused := count if level < 5 else int(round(count * 0.6))
	result[counter] += focused
	var rest := count - focused
	var cycle := ["speer", "bogen", "ritter", "reiter"]
	var index := 0
	while rest > 0:
		result[cycle[index % 4]] += 1
		rest -= 1
		index += 1
	return result


static func _groups(squad: Dictionary, toughness: float) -> Array:
	var result: Array = []
	for role in ROLES:
		var count := int(squad.get(role, 0))
		if count > 0:
			var hp: float = UNITS[role].hp * toughness
			result.append({"role": role, "hp": hp, "pool": hp * count, "atk": UNITS[role].atk * toughness})
	return result


static func _alive(groups: Array) -> int:
	var total := 0
	for group in groups:
		total += _count(group)
	return total


static func _count(group: Dictionary) -> int:
	return int(ceil(maxf(0.0, group.pool) / group.hp - 0.0001)) if group.pool > 0.0 else 0


## Damage a side deals: every group targets the enemy group it counters best.
static func _strike(attackers: Array, targets: Array, ranged_only: bool) -> Array:
	var damage: Array = []
	for _target in targets:
		damage.append(0.0)
	if targets.is_empty():
		return damage
	for group in attackers:
		var count := _count(group)
		if count == 0 or (ranged_only and not UNITS[group.role].ranged):
			continue
		var best := -1
		var best_score := -1.0
		for index in range(targets.size()):
			if _count(targets[index]) == 0:
				continue
			var score := multiplier(group.role, targets[index].role)
			if score > best_score:
				best_score = score
				best = index
		if best >= 0:
			damage[best] += count * float(group.atk) * best_score
	return damage


static func _apply(groups: Array, damage: Array) -> void:
	for index in range(groups.size()):
		groups[index].pool = maxf(0.0, groups[index].pool - damage[index])


## Resolve one lane. Returns survivors on both sides and whether hares broke through.
static func resolve_lane(lane_defense: Dictionary, attackers_squad: Dictionary, toughness: float, watchpost: bool) -> Dictionary:
	var attackers := _groups(attackers_squad, toughness)
	var defenders := _groups(lane_defense.squad, 1.0)
	var wall := float(lane_defense.wall) * STRUCTURES.wall.hp
	if int(lane_defense.wall) > 0 and lane_defense.gate:
		wall += STRUCTURES.gate.hp
	var tower_damage := float(lane_defense.towers) * STRUCTURES.tower.damage
	if watchpost:
		tower_damage *= 1.0 + STRUCTURES.watchpost.tower_bonus
	var ticks := 0
	while ticks < MAX_TICKS and _alive(attackers) > 0:
		ticks += 1
		# Towers and archers shoot first; the wall keeps melee apart.
		var volley: Array = _strike(defenders, attackers, wall > 0.0)
		for index in range(attackers.size()):
			if _count(attackers[index]) > 0 and tower_damage > 0.0:
				volley[index] += tower_damage
				break
		var counter_attack: Array = _strike(attackers, defenders, false)
		_apply(attackers, volley)
		if wall > 0.0:
			var total := 0.0
			for value in counter_attack:
				total += value
			wall = maxf(0.0, wall - total)
		else:
			_apply(defenders, counter_attack)
		if _alive(defenders) == 0 and wall <= 0.0 and tower_damage <= 0.0:
			break
	var survivors := _empty_squad()
	for group in attackers:
		survivors[group.role] = _count(group)
	var defenders_left := _empty_squad()
	for group in defenders:
		defenders_left[group.role] = _count(group)
	var breached := _alive(attackers) > 0 and _alive(defenders) == 0 and wall <= 0.0
	# A stalemate at the time limit counts for the defenders: hares give up.
	return {
		"breached": breached,
		"attackers_left": survivors if breached else _empty_squad(),
		"defenders_left": defenders_left,
		"wall_left": wall,
		"ticks": ticks,
	}


## Resolve a full wave. `buildings` maps building keys to lanes; breached
## lanes see buildings occupied (never destroyed).
static func resolve_wave(defense: Dictionary, wave: Dictionary, buildings: Dictionary) -> Dictionary:
	var lanes := {}
	var captured := {}
	for lane in wave.groups:
		var outcome := resolve_lane(defense.lanes[lane], wave.groups[lane], float(wave.toughness), bool(defense.watchpost))
		lanes[lane] = outcome
		if not outcome.breached:
			continue
		var raiders := 0
		for role in ROLES:
			raiders += int(outcome.attackers_left[role])
		var keys: Array = []
		for key in buildings:
			if buildings[key] == lane:
				keys.append(key)
		keys.sort()
		var take := mini(keys.size(), int(ceil(raiders / 2.0)))
		for index in range(take):
			captured[keys[index]] = _share(outcome.attackers_left, index, take)
	return {"won": captured.is_empty() and not _any_breach(lanes), "lanes": lanes, "captured": captured}


static func _any_breach(lanes: Dictionary) -> bool:
	for lane in lanes:
		if lanes[lane].breached:
			return true
	return false


static func _share(squad: Dictionary, index: int, parts: int) -> Dictionary:
	var result := _empty_squad()
	for role in ROLES:
		var total := int(squad[role])
		result[role] = total / parts + (1 if index < total % parts else 0)
	var any := false
	for role in ROLES:
		any = any or result[role] > 0
	if not any:
		result.speer = 1
	return result


## Chase occupying hares out of a building. Nothing is destroyed either way.
static func recapture(occupants: Dictionary, squad: Dictionary, level: int) -> Dictionary:
	var lane := {"wall": 0, "towers": 0, "gate": false, "squad": squad}
	var outcome := resolve_lane(lane, occupants, enemy_toughness(level), false)
	return {"freed": not outcome.breached, "squad_left": outcome.defenders_left}


## A solid but not maximal layout a child can reach at this level: walls,
## a tower per lane, a gate and mixed squads that cover each other's weakness.
static func reference_defense(level: int) -> Dictionary:
	var defense := empty_defense()
	var step := clampi(level, 1, MAX_LEVEL)
	defense.watchpost = step >= 3
	for lane in LANES:
		var data: Dictionary = defense.lanes[lane]
		data.wall = mini(MAX_WALL, 1 + step / 5)
		data.towers = mini(MAX_TOWERS, 1 + step / 7)
		data.gate = step >= 2
		var each := 1 + int(ceil(wave_budget(step) * 0.16))
		for role in ROLES:
			data.squad[role] = mini(MAX_SQUAD, each)
	return defense


static func squad_cost(squad: Dictionary) -> Dictionary:
	var total := {}
	for role in ROLES:
		for resource in UNITS[role].cost:
			total[resource] = int(total.get(resource, 0)) + int(UNITS[role].cost[resource]) * int(squad.get(role, 0))
	return total
