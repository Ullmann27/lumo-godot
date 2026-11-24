extends RefCounted
## „Lumo-Geist“: die beste Fahrt einer Kart-Strecke als kleine, geprüfte Datei.
##
## Aufbau (little endian; die App liest denselben Kopf in lib/features/kart_friends/):
##   "LGST" · Format (u8) · 6 kurze Texte (u8-Länge + UTF-8): Strecke, Strecken-Version,
##   Fahrer, Kart, Stufe, Vorname · Zeit in ms (u32) · Bildanzahl (u16) · Startzeit in ms (u16)
##   · Ursprung (3 × f32) · Länge der Nutzdaten (u32) · Nutzdaten (zlib/Deflate)
##   · Prüfsumme (die ersten 8 Byte von SHA-256 über alles davor).
## Nutzdaten spaltenweise: Zeitabstand ms (u16), Positions-Delta in cm (3 × s16),
## Winkel-Delta in 1/65536 Umdrehung (3 × s16), Lenkung (s8), Tempo in cm/s (s16).
## Eine fremde Datei kann hier nie etwas anderes tun als abgelehnt werden: alles wird vor
## dem Gebrauch geprüft, nichts davon wird gespeichert oder ausgeführt.

const MAGIC: PackedByteArray = [76, 71, 83, 84]  # "LGST"
const FORMAT: int = 1
const MAX_FILE_BYTES: int = 65536
const MAX_FRAMES: int = 15000
const MIN_FRAMES: int = 2
const MIN_TIME_MS: int = 5000
const MAX_TIME_MS: int = 1200000
const MAX_COORD_M: float = 5000.0
const BYTES_PER_FRAME: int = 17
const CHECKSUM_BYTES: int = 8
const TEXT_PREFIX: String = "LUMOGEIST1:"
const MAX_NAME_CHARS: int = 16
const ID_PATTERN: String = "^[a-z0-9_]{1,40}$"
const VERSION_PATTERN: String = "^[a-z0-9_:.-]{1,48}$"
const ANGLE_UNITS: float = 65536.0 / TAU

## Freundliche Meldungen je Ablehnungsgrund (für Kind und Eltern).
const MESSAGES: Dictionary = {
	"empty": "Die Datei ist leer.",
	"too_large": "Diese Datei ist zu groß für einen Lumo-Geist.",
	"not_ghost": "Das ist kein Lumo-Geist.",
	"newer_format": "Dieser Geist kommt aus einer neueren Lumo-Version. Bitte Lumo aktualisieren.",
	"damaged": "Der Geist ist beschädigt angekommen. Bitte lass ihn dir noch einmal schicken.",
	"unknown_track": "Diese Strecke gibt es in deinem Lumo nicht.",
	"old_track":
	(
		"Der Geist ist auf einer früheren Fassung dieser Strecke gefahren. "
		+ "Bitte deinen Freund, die Strecke neu zu fahren."
	),
	"no_ride": "Es gibt noch keine gültige Fahrt zum Verschicken."
}


static func message(code: String) -> String:
	return str(MESSAGES.get(code, MESSAGES.damaged))


## Nur Buchstaben, Leerzeichen, Bindestrich und Apostroph; höchstens 16 Zeichen.
## Leere oder unpassende Namen werden zu „Freund“.
static func clean_name(raw: String) -> String:
	var out := ""
	for i in range(raw.length()):
		var c: String = raw[i]
		var code: int = c.unicode_at(0)
		var letter: bool = c.to_lower() != c.to_upper() or (code >= 0xC0 and code <= 0x24F)
		if letter or c in [" ", "-", "'"]:
			out += c
		if out.length() >= MAX_NAME_CHARS:
			break
	out = out.strip_edges()
	while out.contains("  "):
		out = out.replace("  ", " ")
	return out if not out.is_empty() else "Freund"


## frames: wie kart_records.recording – [zeit_s, Vector3 pos, Vector3 rot, lenkung, tempo].
## meta: track, track_version, driver, kart, difficulty, name, time (Sekunden).
## Ergebnis: {"ok": true, "bytes": PackedByteArray} oder {"ok": false, "error": code}.
static func encode(frames: Array, meta: Dictionary) -> Dictionary:
	if frames.size() < MIN_FRAMES or frames.size() > MAX_FRAMES:
		return {"ok": false, "error": "no_ride"}
	var time_ms: int = roundi(float(meta.get("time", 0.0)) * 1000.0)
	if time_ms < MIN_TIME_MS or time_ms > MAX_TIME_MS:
		return {"ok": false, "error": "no_ride"}
	var texts: Array[String] = [
		str(meta.get("track", "")),
		str(meta.get("track_version", "")),
		str(meta.get("driver", "")),
		str(meta.get("kart", "")),
		str(meta.get("difficulty", "")),
	]
	for i in range(texts.size()):
		if not _matches(texts[i], VERSION_PATTERN if i == 1 else ID_PATTERN):
			return {"ok": false, "error": "no_ride"}
	var count: int = frames.size()
	var payload := PackedByteArray()
	payload.resize(count * BYTES_PER_FRAME)
	var first: Array = frames[0]
	var origin: Vector3 = first[1]
	var first_ms: int = roundi(float(first[0]) * 1000.0)
	if first_ms < 0 or first_ms > 65535 or not origin.is_finite():
		return {"ok": false, "error": "no_ride"}
	var prev_ms: int = first_ms
	var prev_q := Vector3i.ZERO
	var prev_r := Vector3i.ZERO
	for i in range(count):
		var frame: Variant = frames[i]
		if not frame is Array or (frame as Array).size() != 5:
			return {"ok": false, "error": "no_ride"}
		var pos: Variant = frame[1]
		var rot: Variant = frame[2]
		if not pos is Vector3 or not rot is Vector3:
			return {"ok": false, "error": "no_ride"}
		if not (pos as Vector3).is_finite() or not (rot as Vector3).is_finite():
			return {"ok": false, "error": "no_ride"}
		var ms: int = roundi(float(frame[0]) * 1000.0)
		var dt: int = ms - prev_ms if i > 0 else 0
		if (i > 0 and dt <= 0) or dt > 65535:
			return {"ok": false, "error": "no_ride"}
		var q := _quantize_position((pos as Vector3) - origin)
		var r := _quantize_rotation(rot as Vector3)
		var dq: Vector3i = q - prev_q
		var dr := Vector3i(
			_wrap16(r.x - prev_r.x), _wrap16(r.y - prev_r.y), _wrap16(r.z - prev_r.z)
		)
		if not _fits16(dq.x) or not _fits16(dq.y) or not _fits16(dq.z):
			return {"ok": false, "error": "no_ride"}
		payload.encode_u16(i * 2, dt)
		payload.encode_s16(count * 2 + i * 2, dq.x)
		payload.encode_s16(count * 4 + i * 2, dq.y)
		payload.encode_s16(count * 6 + i * 2, dq.z)
		payload.encode_s16(count * 8 + i * 2, dr.x)
		payload.encode_s16(count * 10 + i * 2, dr.y)
		payload.encode_s16(count * 12 + i * 2, dr.z)
		payload.encode_s8(count * 14 + i, clampi(roundi(float(frame[3]) * 127.0), -127, 127))
		payload.encode_s16(
			count * 15 + i * 2, clampi(roundi(float(frame[4]) * 100.0), -32767, 32767)
		)
		prev_ms = ms
		prev_q = q
		prev_r = r
	if prev_ms > time_ms + 1000:
		return {"ok": false, "error": "no_ride"}
	var packed: PackedByteArray = payload.compress(FileAccess.COMPRESSION_DEFLATE)
	var out := StreamPeerBuffer.new()
	out.big_endian = false
	out.put_data(MAGIC)
	out.put_u8(FORMAT)
	for text in texts:
		_put_text(out, text)
	_put_text(out, clean_name(str(meta.get("name", ""))))
	out.put_u32(time_ms)
	out.put_u16(count)
	out.put_u16(first_ms)
	out.put_float(origin.x)
	out.put_float(origin.y)
	out.put_float(origin.z)
	out.put_u32(packed.size())
	out.put_data(packed)
	var body: PackedByteArray = out.data_array
	var bytes: PackedByteArray = body + _checksum(body)
	if bytes.size() > MAX_FILE_BYTES:
		return {"ok": false, "error": "too_large"}
	return {"ok": true, "bytes": bytes}


## Strenge Prüfung. Ergebnis {"ok": true, "meta": {...}, "frames": [...]} oder
## {"ok": false, "error": code, "message": text}. Wirft nie, verändert nichts.
static func decode(bytes: PackedByteArray) -> Dictionary:
	if bytes.is_empty():
		return _fail("empty")
	if bytes.size() > MAX_FILE_BYTES:
		return _fail("too_large")
	if bytes.size() < 4 or bytes.slice(0, 4) != MAGIC:
		return _fail("not_ghost")
	if bytes.size() < 4 + 1 + 6 + 4 + 2 + 2 + 12 + 4 + CHECKSUM_BYTES:
		return _fail("damaged")
	if bytes[4] > FORMAT:
		return _fail("newer_format")
	if bytes[4] != FORMAT:
		return _fail("damaged")
	var body: PackedByteArray = bytes.slice(0, bytes.size() - CHECKSUM_BYTES)
	if _checksum(body) != bytes.slice(bytes.size() - CHECKSUM_BYTES):
		return _fail("damaged")
	var reader := {"data": body, "at": 5}
	var texts: Array[String] = []
	for i in range(6):
		var text: Variant = _get_text(reader)
		if text == null:
			return _fail("damaged")
		texts.append(str(text))
	for i in range(5):
		if not _matches(texts[i], VERSION_PATTERN if i == 1 else ID_PATTERN):
			return _fail("damaged")
	if texts[5] != clean_name(texts[5]):
		return _fail("damaged")
	if int(reader.at) + 4 + 2 + 2 + 12 + 4 > body.size():
		return _fail("damaged")
	var time_ms: int = body.decode_u32(reader.at)
	var count: int = body.decode_u16(reader.at + 4)
	var first_ms: int = body.decode_u16(reader.at + 6)
	var origin := Vector3(
		body.decode_float(reader.at + 8),
		body.decode_float(reader.at + 12),
		body.decode_float(reader.at + 16)
	)
	var packed_size: int = body.decode_u32(reader.at + 20)
	var start: int = int(reader.at) + 24
	if time_ms < MIN_TIME_MS or time_ms > MAX_TIME_MS or count < MIN_FRAMES or count > MAX_FRAMES:
		return _fail("damaged")
	if (
		not origin.is_finite()
		or absf(origin.x) > MAX_COORD_M
		or absf(origin.y) > MAX_COORD_M
		or absf(origin.z) > MAX_COORD_M
	):
		return _fail("damaged")
	if packed_size <= 0 or start + packed_size != body.size():
		return _fail("damaged")
	var expected: int = count * BYTES_PER_FRAME
	var payload: PackedByteArray = body.slice(start).decompress(
		expected, FileAccess.COMPRESSION_DEFLATE
	)
	if payload.size() != expected:
		return _fail("damaged")
	# Zurückverdichten muss genau dieselben Bytes ergeben: so gibt es zu einem Geist
	# genau eine gültige Datei (keine angehängten oder versteckten Daten im Deflate-Strom).
	if payload.compress(FileAccess.COMPRESSION_DEFLATE) != body.slice(start):
		return _fail("damaged")
	var frames: Array = []
	var ms: int = first_ms
	var q := Vector3i.ZERO
	var r := Vector3i.ZERO
	for i in range(count):
		var dt: int = payload.decode_u16(i * 2)
		if (i == 0 and dt != 0) or (i > 0 and dt <= 0):
			return _fail("damaged")
		ms += dt
		q += Vector3i(
			payload.decode_s16(count * 2 + i * 2),
			payload.decode_s16(count * 4 + i * 2),
			payload.decode_s16(count * 6 + i * 2)
		)
		r = Vector3i(
			_wrap16(r.x + payload.decode_s16(count * 8 + i * 2)),
			_wrap16(r.y + payload.decode_s16(count * 10 + i * 2)),
			_wrap16(r.z + payload.decode_s16(count * 12 + i * 2))
		)
		var steer: int = payload.decode_s8(count * 14 + i)
		if steer < -127:
			return _fail("damaged")
		var pos: Vector3 = origin + Vector3(q) * 0.01
		if absf(pos.x) > MAX_COORD_M or absf(pos.y) > MAX_COORD_M or absf(pos.z) > MAX_COORD_M:
			return _fail("damaged")
		var rot := Vector3(r) / ANGLE_UNITS
		frames.append(
			[ms / 1000.0, pos, rot, steer / 127.0, payload.decode_s16(count * 15 + i * 2) / 100.0]
		)
	if ms > time_ms + 1000:
		return _fail("damaged")
	return {
		"ok": true,
		"frames": frames,
		"meta":
		{
			"track": texts[0],
			"track_version": texts[1],
			"driver": texts[2],
			"kart": texts[3],
			"difficulty": texts[4],
			"name": texts[5],
			"time": time_ms / 1000.0,
			"time_ms": time_ms,
			"frame_count": count,
		}
	}


## Textform für Nachrichten/QR: "LUMOGEIST1:" + Base64url ohne Auffüllzeichen.
static func to_text(bytes: PackedByteArray) -> String:
	var b64: String = Marshalls.raw_to_base64(bytes)
	return TEXT_PREFIX + b64.replace("+", "-").replace("/", "_").replace("=", "")


## Liest Datei-Bytes oder die Textform. Ungültiges ergibt ein leeres Array.
static func bytes_from_text(text: String) -> PackedByteArray:
	var t: String = text.strip_edges()
	if (
		not t.begins_with(TEXT_PREFIX)
		or t.length() > TEXT_PREFIX.length() + MAX_FILE_BYTES * 4 / 3 + 4
	):
		return PackedByteArray()
	var body: String = t.substr(TEXT_PREFIX.length())
	var regex := RegEx.create_from_string("^[A-Za-z0-9_-]+$")
	if regex.search(body) == null:
		return PackedByteArray()
	body = body.replace("-", "+").replace("_", "/")
	while body.length() % 4 != 0:
		body += "="
	return Marshalls.base64_to_raw(body)


## Strecken-Version: Passagen-Kennung plus Prüfsumme der Mittellinie. Wird eine Strecke
## umgebaut, ändert sich die Mittellinie und damit die Version – ohne Liste von Hand.
static func track_version(world: Object, track_id: String, track_length: float) -> String:
	var passages: Script = load("res://scripts/games/kart_passages.gd")
	var suffix: String = str(passages.ghost_suffix(track_id)).trim_prefix("_")
	var parts := PackedStringArray([str(roundi(track_length * 2.0))])
	if is_instance_valid(world) and world.has_method("reset_transform") and track_length > 0.0:
		for i in range(48):
			var origin: Vector3 = world.reset_transform(track_length * float(i) / 48.0, 0.0).origin
			parts.append(
				(
					"%d,%d,%d"
					% [roundi(origin.x * 2.0), roundi(origin.y * 2.0), roundi(origin.z * 2.0)]
				)
			)
	var digest: String = ",".join(parts).sha256_text().substr(0, 10)
	return ("%s:%s" % [suffix, digest]) if not suffix.is_empty() else ("v:" + digest)


static func _fail(code: String) -> Dictionary:
	return {"ok": false, "error": code, "message": message(code)}


static func _matches(text: String, pattern: String) -> bool:
	var regex := RegEx.create_from_string(pattern)
	return regex.search(text) != null


static func _quantize_position(p: Vector3) -> Vector3i:
	return Vector3i(roundi(p.x * 100.0), roundi(p.y * 100.0), roundi(p.z * 100.0))


static func _quantize_rotation(r: Vector3) -> Vector3i:
	return Vector3i(
		_wrap16(roundi(wrapf(r.x, -PI, PI) * ANGLE_UNITS)),
		_wrap16(roundi(wrapf(r.y, -PI, PI) * ANGLE_UNITS)),
		_wrap16(roundi(wrapf(r.z, -PI, PI) * ANGLE_UNITS))
	)


static func _wrap16(v: int) -> int:
	return ((v + 32768) % 65536 + 65536) % 65536 - 32768


static func _fits16(v: int) -> bool:
	return v >= -32768 and v <= 32767


static func _put_text(out: StreamPeerBuffer, text: String) -> void:
	var raw: PackedByteArray = text.to_utf8_buffer()
	if raw.size() > 64:
		raw = raw.slice(0, 64)
	out.put_u8(raw.size())
	out.put_data(raw)


static func _get_text(reader: Dictionary) -> Variant:
	var data: PackedByteArray = reader.data
	var at: int = reader.at
	if at >= data.size():
		return null
	var size: int = data[at]
	if size == 0 or size > 64 or at + 1 + size > data.size():
		return null
	var raw: PackedByteArray = data.slice(at + 1, at + 1 + size)
	var text: String = raw.get_string_from_utf8()
	if text.to_utf8_buffer() != raw:
		return null
	reader.at = at + 1 + size
	return text


static func _checksum(body: PackedByteArray) -> PackedByteArray:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(body)
	return ctx.finish().slice(0, CHECKSUM_BYTES)
