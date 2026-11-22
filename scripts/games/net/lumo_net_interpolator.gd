extends RefCounted
## Glättung der Fahrdaten EINES entfernten Fahrers (Kart, Parcours-Läufer …).
##
## Stützpunkte tragen die Rennzeit des Senders (k). Der Empfänger kennt den Zeitversatz nicht;
## er schätzt ihn robust aus dem kleinsten beobachteten Versatz der letzten Sekunden
## (Verzögerungen kommen nur hinzu, nie weg) plus einem Puffer, der sich nach dem gemessenen
## Zittern richtet. Die Wiedergabe-Uhr wird höchstens ±10 % schneller/langsamer nachgeführt;
## nur nach einer echten Pause (> 1 s Abweichung) rastet sie neu ein (`relocks` zählt das).
## Alles hängt nur an den übergebenen Uhren, nie an der Wanduhr → lastunabhängig testbar.

const WINDOW_S: float = 3.0
const MIN_BUFFER: float = 0.08
const MAX_BUFFER: float = 0.6
const MAX_RATE: float = 0.1
const RELOCK_S: float = 1.0
const MAX_EXTRAPOLATE: float = 0.25
const MAX_SAMPLES: int = 48
## Springt die Rohposition (Datenlücke, Wiedereinrasten), gleitet die Anzeige mit höchstens
## CATCH_UP_FACTOR × Tempo zusätzlich hinterher statt zu springen; ab SNAP_M wird gesetzt.
const CATCH_UP_FACTOR: float = 1.0
const SNAP_M: float = 60.0

## [{k, p: Vector3, yaw, v, r: Vector3, st}] aufsteigend nach k
## (r/st optional: Kart-Neigung und Lenkung).
var samples: Array = []
## Wiedergabe: gezeigte Rennzeit = lokale Uhr − offset.
var offset: float = INF
var target_offset: float = INF
var relocks: int = 0
## Zähler für Messungen: Bilder ohne neue Daten (vorausgeschätzt) und Aufhol-Gleitvorgänge.
var extrapolated_frames: int = 0
var glides: int = 0
var _arrivals: Array = []  # [[lokale Zeit, beobachteter Versatz]]
var _last_local: float = -INF
var _last_shown := Vector3.INF
var _error := Vector3.ZERO


## Sofort an die echte Position (z. B. nach einem Zurücksetzen auf die Strecke).
func snap() -> void:
	_error = Vector3.ZERO
	_last_shown = Vector3.INF


func clear() -> void:
	samples.clear()
	_arrivals.clear()
	offset = INF
	target_offset = INF
	_last_local = -INF
	snap()


## Neuer Stützpunkt (k = Rennzeit des Senders, local = eigene Uhr beim Empfang).
func push(
	k: float,
	local: float,
	position: Vector3,
	yaw: float,
	speed: float,
	rotation: Vector3 = Vector3.ZERO,
	steer: float = 0.0
) -> void:
	if not samples.is_empty() and k <= float(samples[-1].k):
		return  # veraltet oder doppelt (unzuverlässiger Kanal)
	samples.append({"k": k, "p": position, "yaw": yaw, "v": speed, "r": rotation, "st": steer})
	while samples.size() > MAX_SAMPLES:
		samples.pop_front()
	_arrivals.append([local, local - k])
	while not _arrivals.is_empty() and float(_arrivals[0][0]) < local - WINDOW_S:
		_arrivals.pop_front()
	var low: float = INF
	for entry in _arrivals:
		low = minf(low, float(entry[1]))
	var spread: Array[float] = []
	for entry in _arrivals:
		spread.append(float(entry[1]) - low)
	spread.sort()
	# Puffer = größtes Zittern der letzten Sekunden: lieber etwas später, dafür ohne Lücken.
	var jitter: float = spread[-1] if not spread.is_empty() else 0.0
	target_offset = low + clampf(jitter + 0.05, MIN_BUFFER, MAX_BUFFER)
	if offset == INF:
		offset = target_offset


## Gezeigter Zustand zur eigenen Uhr `local` ({} solange nichts da ist).
func sample(local: float) -> Dictionary:
	var dt: float = clampf(local - _last_local, 0.0, 0.5) if _last_local != -INF else 0.0
	var pose: Dictionary = _raw(local)
	if pose.is_empty():
		return pose
	var raw_p: Vector3 = pose.p
	var speed: float = absf(float(pose.v))
	if _last_shown != Vector3.INF:
		var expected: float = speed * dt * (1.0 + MAX_RATE) + 0.3
		var gap: Vector3 = _last_shown - (raw_p + _error)
		if gap.length() > SNAP_M:
			_error = Vector3.ZERO
			relocks += 1
		elif gap.length() > expected:
			glides += 1
			_error += gap  # weiter von der letzten Anzeige aus gleiten
	_error = _error.move_toward(Vector3.ZERO, (CATCH_UP_FACTOR * speed + 2.0) * dt)
	pose.p = raw_p + _error
	pose["smoothing"] = _error.length()
	if bool(pose.extrapolated):
		extrapolated_frames += 1
	_last_shown = pose.p
	return pose


func _raw(local: float) -> Dictionary:
	if samples.is_empty() or offset == INF:
		return {}
	var dt: float = clampf(local - _last_local, 0.0, 0.5) if _last_local != -INF else 0.0
	_last_local = local
	if absf(target_offset - offset) > RELOCK_S:
		offset = target_offset
		relocks += 1
	else:
		offset = move_toward(offset, target_offset, MAX_RATE * dt)
	var k: float = local - offset
	var first: Dictionary = samples[0]
	if k <= float(first.k):
		return _pose(first, float(first.k), false)
	for i in range(samples.size() - 1):
		var a: Dictionary = samples[i]
		var b: Dictionary = samples[i + 1]
		if k <= float(b.k):
			var blend: float = (k - float(a.k)) / maxf(0.0001, float(b.k) - float(a.k))
			return {
				"k": k,
				"p": (a.p as Vector3).lerp(b.p, blend),
				"yaw": lerp_angle(float(a.yaw), float(b.yaw), blend),
				"v": lerpf(float(a.v), float(b.v), blend),
				"r":
				Vector3(
					lerp_angle(a.r.x, b.r.x, blend),
					lerp_angle(a.r.y, b.r.y, blend),
					lerp_angle(a.r.z, b.r.z, blend)
				),
				"st": lerpf(float(a.st), float(b.st), blend),
				"extrapolated": false
			}
	# Neuere Daten fehlen: kurz in Fahrtrichtung weiter, dann stehen bleiben.
	var last: Dictionary = samples[-1]
	var ahead: float = clampf(k - float(last.k), 0.0, MAX_EXTRAPOLATE)
	var pose: Dictionary = _pose(last, float(last.k) + ahead, true)
	if samples.size() >= 2 and ahead > 0.0:
		var before: Dictionary = samples[-2]
		var span: float = maxf(0.0001, float(last.k) - float(before.k))
		var velocity: Vector3 = ((last.p as Vector3) - (before.p as Vector3)) / span
		pose.p = (last.p as Vector3) + velocity.limit_length(80.0) * ahead
	return pose


static func _pose(s: Dictionary, k: float, extrapolated: bool) -> Dictionary:
	return {
		"k": k, "p": s.p, "yaw": s.yaw, "v": s.v, "r": s.r, "st": s.st, "extrapolated": extrapolated
	}
