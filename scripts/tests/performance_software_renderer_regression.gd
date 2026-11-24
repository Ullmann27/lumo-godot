extends SceneTree
## Phones without hardware graphics start with the light profile: the adapter
## names that count as "computed on the processor", and no false alarm for chips.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var PERFORMANCE: Node = root.get_node("PerformanceManager")
	for name in ["Android Emulator OpenGL ES Translator (Google SwiftShader)", "llvmpipe (LLVM 21.1.8, 256 bits)",
			"softpipe", "Google SwiftShader", "Software Rasterizer"]:
		if not PERFORMANCE.is_software_adapter(name):
			failures.append("nicht erkannt: " + name)
	for name in ["Adreno (TM) 830", "Mali-G715", "Xclipse 940", "Apple A17 GPU", "NVIDIA GeForce RTX 4070", ""]:
		if PERFORMANCE.is_software_adapter(name):
			failures.append("falscher Alarm: " + name)
	# On this desktop test machine the rule never applies.
	if PERFORMANCE.software_rendered_mobile():
		failures.append("Regel greift auf dem Desktop")
	if failures.is_empty():
		print("[PerfSoftware] PASS: 12 checks")
	else:
		print("[PerfSoftware] FAILED: ", failures)
	quit(0 if failures.is_empty() else 1)
