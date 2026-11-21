extends SceneTree
## Lumo-Geist: Rundlauf bitgenau, gleiche Fahrlinie, strenge Ablehnung fremder Dateien.

const CODEC = preload("res://scripts/games/kart_friends/kart_ghost_codec.gd")

var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		print("[KartGhostCodec] FAIL: ", label)


## Fahrt um eine große, hügelige Acht, 0,08-s-Takt wie kart_records.capture.
static func drive(seconds: float) -> Array:
	var frames: Array = []
	var t: float = 0.0
	var step: int = 0
	while t <= seconds:
		var a: float = t * 0.11
		var pos := Vector3(
			sin(a) * 140.0 + 12.3456, 2.0 + sin(a * 3.0) * 3.5, sin(a * 2.0) * 70.0 - 33.21
		)
		var heading: float = atan2(cos(a) * 140.0, cos(a * 2.0) * 140.0)
		frames.append(
			[
				t,
				pos,
				Vector3(sin(a * 5.0) * 0.12, heading, cos(a * 7.0) * 0.05),
				sin(a * 9.0),
				24.0 + sin(a) * 6.0
			]
		)
		step += 1
		# leicht unregelmäßig wie echte Bildzeiten
		t += 0.08 + (0.004 if step % 3 == 0 else 0.0)
	return frames


static func meta(time: float) -> Dictionary:
	return {
		"track": "sonnenhafen",
		"track_version": "p1:0123456789",
		"driver": "fox",
		"kart": "comet",
		"difficulty": "gemuetlich",
		"name": "Mia",
		"time": time
	}


func _run() -> void:
	var frames: Array = drive(92.0)
	var time: float = float(frames[-1][0])
	var encoded: Dictionary = CODEC.encode(frames, meta(time))
	_check(bool(encoded.ok), "encode ok")
	var bytes: PackedByteArray = encoded.get("bytes", PackedByteArray())
	print(
		(
			"[KartGhostCodec] 92-s-Fahrt: %d Bilder -> %d Byte Datei, %d Zeichen Textform"
			% [frames.size(), bytes.size(), CODEC.to_text(bytes).length()]
		)
	)
	var decoded: Dictionary = CODEC.decode(bytes)
	_check(bool(decoded.ok), "decode ok")
	if not decoded.ok:
		_finish()
		return
	_check(
		str(decoded.meta.name) == "Mia" and str(decoded.meta.track) == "sonnenhafen", "Kopf gleich"
	)
	_check(int(decoded.meta.frame_count) == frames.size(), "Bildanzahl gleich")
	# Bitgenau: erneutes Verpacken des Gelesenen ergibt genau dieselben Bytes.
	var again: Dictionary = CODEC.encode(decoded.frames, decoded.meta)
	_check(bool(again.ok) and again.bytes == bytes, "Rundlauf bitgenau")
	# Dieselbe Linie: größte Abweichung Position/Winkel/Zeit.
	var max_pos: float = 0.0
	var max_rot: float = 0.0
	var max_t: float = 0.0
	for i in range(frames.size()):
		max_pos = maxf(max_pos, (frames[i][1] as Vector3).distance_to(decoded.frames[i][1]))
		var ra: Vector3 = frames[i][2]
		var rb: Vector3 = decoded.frames[i][2]
		max_rot = maxf(max_rot, absf(angle_difference(ra.y, rb.y)))
		max_t = maxf(max_t, absf(float(frames[i][0]) - float(decoded.frames[i][0])))
	print(
		(
			"[KartGhostCodec] Abweichung: Position %.4f m, Winkel %.5f rad, Zeit %.4f s"
			% [max_pos, max_rot, max_t]
		)
	)
	_check(max_pos < 0.01, "Fahrlinie < 1 cm")
	_check(max_rot < 0.001, "Winkel < 0,001 rad")
	_check(max_t < 0.001, "Zeit < 1 ms")
	_check(bytes.size() < 24000, "Datei unter 24 KB")
	# Textform hin und zurück.
	_check(CODEC.bytes_from_text(CODEC.to_text(bytes)) == bytes, "Textform Rundlauf")
	_check(
		CODEC.bytes_from_text("LUMOGEIST1:ab$c").is_empty(),
		"Textform mit fremden Zeichen abgelehnt"
	)
	_check(CODEC.bytes_from_text("hallo").is_empty(), "Text ohne Kennung abgelehnt")
	# Ablehnungen
	_expect(PackedByteArray(), "empty")
	var big := PackedByteArray()
	big.resize(CODEC.MAX_FILE_BYTES + 1)
	_expect(big, "too_large")
	_expect("PNG nicht wirklich".to_utf8_buffer(), "not_ghost")
	var newer: PackedByteArray = bytes.duplicate()
	newer[4] = 9
	_expect(newer, "newer_format")
	# Jedes einzelne gekippte Bit an 300 Stellen muss abgelehnt werden.
	var flipped_ok: int = 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 4711
	for n in range(300):
		var broken: PackedByteArray = bytes.duplicate()
		var at: int = rng.randi_range(0, broken.size() - 1)
		broken[at] = broken[at] ^ (1 << rng.randi_range(0, 7))
		if not bool(CODEC.decode(broken).ok):
			flipped_ok += 1
	_check(flipped_ok == 300, "300 gekippte Bits abgelehnt (%d)" % flipped_ok)
	# Abgeschnitten und verlängert.
	_expect(bytes.slice(0, bytes.size() - 1), "damaged")
	_expect(bytes.slice(0, 40), "damaged")
	_expect(bytes + PackedByteArray([0]), "damaged")
	# Zufallsmüll mit richtiger Kennung stürzt nie ab.
	var junk_rejected: int = 0
	for n in range(200):
		var junk := PackedByteArray([76, 71, 83, 84, 1])
		for k in range(rng.randi_range(0, 400)):
			junk.append(rng.randi_range(0, 255))
		if not bool(CODEC.decode(junk).ok):
			junk_rejected += 1
	_check(junk_rejected == 200, "200 Zufallsdateien abgelehnt")
	# Gültige Prüfsumme, aber unsinniger Inhalt (selbst gebaut): Name mit Steuerzeichen.
	var evil: Dictionary = meta(time)
	evil.track = "../../etc"
	_check(not bool(CODEC.encode(frames, evil).ok), "Streckenname mit Pfad wird nicht verpackt")
	_check(_resign_with_name(bytes, "Mi\na") != "ok", "Name mit Zeilenumbruch abgelehnt")
	_check(_resign_with_name(bytes, "Mia") == "ok", "Neu signierter gültiger Name angenommen")
	# Namensreinigung
	_check(CODEC.clean_name("  Jürgen-Ñoño  ") == "Jürgen-Ñoño", "Umlaute bleiben")
	_check(CODEC.clean_name("<script>") == "script", "Zeichen entfernt")
	_check(CODEC.clean_name("12345") == "Freund", "Leer wird Freund")
	_check(CODEC.clean_name("Maximilian Alexander").length() <= 16, "Name höchstens 16 Zeichen")
	# Zu kurze und zu lange Fahrten werden nicht verpackt.
	_check(not bool(CODEC.encode(frames.slice(0, 1), meta(time)).ok), "ein Bild ist keine Fahrt")
	_check(not bool(CODEC.encode(frames, meta(2.0)).ok), "Zeit passt nicht zu den Bildern")
	# Rückwärts laufende Zeit
	var bad_frames: Array = frames.duplicate(true)
	bad_frames[10][0] = bad_frames[9][0]
	_check(not bool(CODEC.encode(bad_frames, meta(time)).ok), "Zeit muss steigen")
	_finish()


func _expect(bytes: PackedByteArray, code: String) -> void:
	var result: Dictionary = CODEC.decode(bytes)
	_check(
		not bool(result.ok) and str(result.error) == code,
		"Ablehnung %s (bekam %s)" % [code, str(result.get("error", "ok"))]
	)
	_check(not str(result.get("message", "")).is_empty(), "Meldung für %s" % code)


## Baut die Datei mit anderem Namen neu (Prüfsumme korrekt), um die Inhaltsprüfung zu testen.
func _resign_with_name(bytes: PackedByteArray, name: String) -> String:
	var at: int = 5
	for i in range(5):
		at += 1 + bytes[at]
	var old_len: int = bytes[at]
	var raw: PackedByteArray = name.to_utf8_buffer()
	var body: PackedByteArray = bytes.slice(0, at) + PackedByteArray([raw.size()]) + raw
	body += bytes.slice(at + 1 + old_len, bytes.size() - CODEC.CHECKSUM_BYTES)
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(body)
	var result: Dictionary = CODEC.decode(body + ctx.finish().slice(0, CODEC.CHECKSUM_BYTES))
	return "ok" if result.ok else str(result.error)


func _finish() -> void:
	if failures.is_empty():
		print("[KartGhostCodec] PASS: %d Prüfungen" % checks)
		quit(0)
	else:
		print("[KartGhostCodec] FAIL: %d von %d Prüfungen" % [failures.size(), checks])
		quit(1)
