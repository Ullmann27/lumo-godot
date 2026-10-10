extends SceneTree

const AUDIO = preload("res://scripts/systems/audio_manager.gd")


func _initialize() -> void:
	var audio = AUDIO.new()
	var reference := {
		"voice": "Sulafat",
		"model": "gemini-2.5-pro-preview-tts",
		"profile": "lumo-sulafat-reference-v1"
	}
	assert(audio._manifest_matches_reference(reference))
	assert(not audio._manifest_matches_reference({"voice": "Sulafat"}))
	assert(not audio._manifest_matches_reference(null))
	var wrong_model := reference.duplicate()
	wrong_model["model"] = "gemini-3.1-flash-tts-preview"
	assert(not audio._manifest_matches_reference(wrong_model))
	var wrong_voice := reference.duplicate()
	wrong_voice["voice"] = "Android"
	assert(not audio._manifest_matches_reference(wrong_voice))
	assert(audio._valid_voice_key("letters/a"))
	assert(audio._valid_voice_key("words/apfel"))
	assert(not audio._valid_voice_key("../legacy"))
	assert(not audio._valid_voice_key("letters/a.wav"))
	assert(not audio._valid_voice_key("letters/aa"))
	audio.free()
	print("LUMO_VOICE_REFERENCE_REGRESSION_OK")
	quit(0)
