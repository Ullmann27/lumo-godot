## FlutterBridge - öffnet die echte Lumo-Lernen Flutter-App aus Godot.
##
## Architektur (Heinz 2026-06-03 Mega-Prompt): Godot ist der 3D-Erlebnis-
## Einstieg, die Flutter-App ist das eigentliche Lernsystem. Wenn der Nutzer
## im Godot-Hub auf "Lernen" tippt, wird die Flutter-App per Android-Deep-Link
## geöffnet.
##
## Mechanik:
##   - Android: OS.shell_open("lumolernen://open?section=...") -> Android
##     löst den Intent über den Intent-Filter der Flutter-App auf.
##   - Wenn die Flutter-App nicht installiert ist (kein Resolver): shell_open
##     gibt einen Fehlercode zurück -> wir liefern false -> Aufrufer zeigt
##     einen freundlichen Hinweis + fällt auf die interne Lese-Welt zurück.
##   - Andere Plattformen (Web/Linux Desktop): kein Deep-Link möglich ->
##     immer false -> interner Fallback.
##
## Flutter-Seite: AndroidManifest.xml der Lumo-Lernen-App registriert einen
## intent-filter für scheme "lumolernen". Package: dev.ullmann.lumo
class_name FlutterBridge
extends RefCounted

## Deep-Link-Schema das die Flutter-App via intent-filter beansprucht.
const SCHEME: String = "lumolernen"

## Android-Package der Flutter-Lern-App (Doku/Referenz - die Bridge selbst
## löst über das SCHEME auf, nicht über das Package, daher nur informativ).
## Verifiziert via aapt an Release build-215: dev.ullmann.lumo.lumo_lernen
const FLUTTER_PACKAGE: String = "dev.ullmann.lumo.lumo_lernen"


## Versucht die Flutter-Lern-App zu öffnen, optional mit Ziel-Bereich.
##   section: "learn" | "cards" | "reading" | "" (offen am Home)
## Rückgabe: true wenn der Open-Intent abgesetzt werden konnte, sonst false.
static func launch_learning_app(section: String = "") -> bool:
	# Nur auf Android sinnvoll - Deep-Link zwischen Apps.
	if OS.get_name() != "Android":
		print("[FlutterBridge] not Android (%s) - cannot deep-link" % OS.get_name())
		return false
	var uri: String = "%s://open" % SCHEME
	if section != "":
		uri += "?section=" + section.uri_encode()
	var err: int = OS.shell_open(uri)
	var ok: bool = err == OK
	print("[FlutterBridge] shell_open(%s) -> err:%d ok:%s" % [uri, err, str(ok)])
	return ok
