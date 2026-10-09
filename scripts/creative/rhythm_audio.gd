extends RefCounted


## Original synthesized C-major melody, bass and percussion. No external recordings.
static func create(song: Dictionary, duration: float) -> AudioStreamWAV:
	const RATE := 22050
	var count := int((duration + 1.0) * RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	var beat := 60.0 / float(song.bpm)
	var melody := [0, 4, 7, 12, 7, 4, 2, 5, 9, 12, 9, 5, 7, 11, 14, 11]
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
		var sample := clampi(roundi((tone + bass + kick) * 27000), -32768, 32767)
		data.encode_s16(i * 2, sample)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	return wav
