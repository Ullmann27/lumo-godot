extends SceneTree
## Die Quizshow darf niemanden einsperren: Ohne bestätigte Runde (Verbindung zur App
## fehlt oder antwortet nicht) führen "Zurück" nach kurzer Wartezeit und die
## Zurück-Geste sofort in die App. Mit Runde bleibt der gesicherte Ausstieg unverändert.
const SCENE: String = "res://scenes/games/quiz_studio.tscn"
var checks: int = 0
var failures: Array[String] = []


## Host, der wie ein Gerät ohne Spielrunde antwortet: kein Spielstand, aber Rückweg.
class SilentHost:
	extends RefCounted
	var returns: Array[String] = []
	var accept: bool = true

	func getTableState() -> String:
		return "{}"

	func submitTableAction(_payload: String) -> bool:
		return false

	func returnToApp(destination: String, payload: String) -> bool:
		returns.append(destination + "|" + payload)
		return accept


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures.append(text)
		print("[QuizEscape] FAIL ", text)


func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame


func _open(host: RefCounted) -> Node:
	root.get_node("HostBridge")._options = {"game": "quiz", "tableToken": "", "displayDensity": 1.0}
	var table: Node = load(SCENE).instantiate()
	table._host = host
	root.add_child(table)
	await _frames(6)
	return table


func _run() -> void:
	# 1. Wartezeit: erst gesperrt, dann offener Notausgang über den Knopf.
	var host := SilentHost.new()
	var table: Node = await _open(host)
	_check(not table._authority_ready or table._state.is_empty(), "ohne Spielstand gibt es keine Runde")
	_check(table.return_button.disabled, "Zurück ist in den ersten Sekunden noch gesperrt")
	_check(str(table.progress.text).contains("wird geprüft"), "anfangs steht die Prüfmeldung")
	table.return_button.pressed.emit()
	_check(host.returns.is_empty(), "vor Ablauf der Wartezeit geht niemand ungewollt hinaus")
	table._track_escape(table.ESCAPE_AFTER_SECONDS + 0.1)
	await _frames(2)
	_check(table._escape_open, "nach der Wartezeit öffnet sich der Notausgang")
	_check(not table.return_button.disabled, "Zurück ist jetzt bedienbar")
	_check(str(table.status.text).contains("Zurück"), "der Text sagt, was zu tun ist")
	table.return_button.pressed.emit()
	await _frames(2)
	_check(host.returns.size() == 1 and host.returns[0] == "games|", "Zurück ruft genau einmal den Rückweg zur Spielewelt")
	_check(table._closed, "nach bestätigtem Rückweg ist das Studio geschlossen")
	table.return_button.pressed.emit()
	_check(host.returns.size() == 1, "ein zweiter Tipp löst keinen zweiten Rückweg aus")
	table.queue_free()
	await _frames(3)

	# 2. Zurück-Geste: sofort, ohne Wartezeit.
	host = SilentHost.new()
	table = await _open(host)
	table.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await _frames(2)
	_check(host.returns.size() == 1 and host.returns[0] == "games|", "die Zurück-Geste führt ohne Runde sofort hinaus")
	_check(table._closed, "Studio nach der Zurück-Geste geschlossen")
	table.queue_free()
	await _frames(3)

	# 3. Lehnt die App den Rückweg ab, bleibt der Knopf bedienbar (erneut versuchen).
	host = SilentHost.new()
	host.accept = false
	table = await _open(host)
	table._track_escape(table.ESCAPE_AFTER_SECONDS + 0.1)
	table.return_button.pressed.emit()
	await _frames(2)
	_check(not table._closed and not table.return_button.disabled, "abgelehnter Rückweg sperrt nichts")
	host.accept = true
	table.return_button.pressed.emit()
	_check(table._closed and host.returns.size() == 2, "zweiter Versuch gelingt")
	table.queue_free()
	await _frames(3)

	root.get_node("HostBridge")._options = {}
	var sound: Node = root.get_node_or_null("GameSoundscape")
	if sound != null and sound.has_method("release_audio"):
		sound.release_audio()
	await create_timer(0.4).timeout
	print(
		JSON.stringify(
			{
				"test": "quiz_studio_escape",
				"status": "PASS" if failures.is_empty() else "FAIL",
				"checks": checks,
				"failures": failures
			}
		)
	)
	quit(0 if failures.is_empty() else 1)
