extends SceneTree
## Compare the loops that Godot actually sends to the two motor players.
const VOICE = preload("res://scripts/games/kart_fx/kart_motor_voice.gd")
const PARTS = preload("res://scripts/games/kart_part_catalog.gd")
const TUNING = preload("res://scripts/games/kart_tuning.gd")


func _initialize() -> void:
	_verify.call_deferred()


func _verify() -> void:
	var mount := Node.new()
	root.add_child(mount)
	var voice = VOICE.new(mount, false)
	var ok := true
	for slot in ["engine", "exhaust"]:
		var references: Dictionary = {}
		var options: Array = PARTS.options(slot) if slot == "engine" else TUNING.EXHAUSTS
		for option in options:
			voice.configure("comet", {slot: option.id})
			var waveform: PackedByteArray = voice.body.stream.data
			for other in references:
				var difference := 0.0
				var energy := 0.0
				var ref: PackedByteArray = references[other]
				for i in range(0, waveform.size(), 2):
					var a := float(waveform.decode_s16(i))
					var b := float(ref.decode_s16(i))
					difference += (a - b) * (a - b)
					energy += a * a + b * b
				if energy <= 0.0 or sqrt(difference / maxf(energy, 1.0)) < .04:
					push_error("Motor loops too similar: %s %s / %s" % [slot, option.id, other])
					ok = false
			references[option.id] = waveform
		print("[WorkshopMotorVoices] ", slot, ": ", references.size(), " PCM loops compared")
	voice.stop()
	mount.queue_free()
	await process_frame
	if ok:
		print("[WorkshopMotorVoices] PASS")
	quit(0 if ok else 1)
