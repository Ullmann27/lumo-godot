extends RefCounted


## Original synthesized melodies, bass and beat-grid percussion. No recordings.
static func create(song: Dictionary, duration: float) -> AudioStreamWAV:
	const RATE := 22050
	var count := int((duration + 1.0) * RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	var beat := 60.0 / float(song.bpm)
	var melodies := {
		"sternentanz": [0, 4, 7, 12, 7, 4, 2, 5, 9, 12, 9, 5, 7, 11, 14, 11],
		"wolkenwalzer": [0, 4, 7, 4, 7, 12, 2, 5, 9, 5, 9, 14],
		"funkelreise": [12, 7, 9, 4, 7, 12, 5, 9, 2, 7, 4, 0],
		"mondfunkeln": [0, 0, 7, 7, 12, 9, 4, 11, 7, 2, 4, 0]
	}
	var melody: Array = melodies.get(str(song.id), melodies.sternentanz)
	for i in range(count):
		var t := float(i) / RATE
		var pulse := fmod(t, beat)
		var index := int(t / beat) % melody.size()
		var frequency := 440.0 * pow(2.0, (float(song.root) + melody[index] - 69.0) / 12.0)
		var envelope := minf(1, pulse / 0.008) * exp(-pulse * 5.5)
		var tone := (
			(sin(TAU * frequency * t) + 0.2 * sin(TAU * frequency * 2 * t)) * envelope * 0.22
		)
		var bass := sin(TAU * frequency * 0.25 * t) * exp(-pulse * 7) * 0.14
		var kick := (
			sin(TAU * (52 * pulse + 12 * (1.0 - exp(-pulse * 30)))) * exp(-pulse * 25) * 0.19
		)
		# The charts use this same half-beat lattice on every difficulty.
		var tick_phase := fmod(t, beat * 0.5)
		var tick := sin(TAU * 2400 * tick_phase) * exp(-tick_phase * 95) * 0.035
		var sample := clampi(roundi((tone + bass + kick + tick) * 27000), -32768, 32767)
		data.encode_s16(i * 2, sample)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	return wav
