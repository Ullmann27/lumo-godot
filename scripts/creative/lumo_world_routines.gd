extends RefCounted
## A small local routine for each existing World figure. The four day phases
## advance only while this World is being played, never during a dialog/pause.
## They are presentation state for this visit, not a school record or a deadline.
## No conversation in this module awards learning progress, cards, stars or XP.

const PHASE_SECONDS := 180.0
const PHASES: Array[String] = ["Morgen", "Mittag", "Nachmittag", "Abend"]
const WALK_SPEED := 0.65
const MAX_STEP := 0.1
const MAX_WANDER := 1.2
const TALK_BUFFER := 5.0
const DRIVE_BUFFER := 7.0
const LOCAL_POINTS: Array[Vector3] = [
	Vector3.ZERO, Vector3(0.9, 0, 0), Vector3(0.5, 0, 0.7),
	Vector3.ZERO, Vector3(-0.8, 0, 0.5), Vector3(-0.8, 0, 0)
]
const IDS: Array[String] = ["owl", "cat", "rabbit", "otter", "frog", "turtle", "badger", "squirrel", "lion"]
const PROFILES := {
	"owl": {
		"interest": "Ich mag Geschichten über das Meer und finde gern heraus, was ein Satz genau bedeutet.",
		"activities": ["Bücher sortieren", "Eine Geschichte vorlesen", "Lesenden helfen", "Bücher zurückstellen"],
		"details": ["Ich ordne die Bücher, damit du dein Lieblingsbuch findest.", "Ich suche eine ruhige Geschichte zum Vorlesen aus.", "Ich helfe beim Lesen. Wir dürfen ein Wort auch mehrmals anschauen.", "Ich stelle die ausgeliehenen Geschichten zurück ins Regal."],
		"gesture": "point_portal", "learning": "In unserer Flaschenpost-Mission liest du Wörter und Nachrichten. Wir suchen gemeinsam die wichtigen Hinweise."
	},
	"cat": {
		"interest": "Ich mag Kartenspiele, bei denen alle die Regeln verstehen und jeder einmal drankommt.",
		"activities": ["Spiele vorbereiten", "Regeln erklären", "Eine Runde begleiten", "Karten aufräumen"],
		"details": ["Ich lege die Karten für unsere nächste Runde bereit.", "Ich erkläre die Spielregeln mit einem Beispiel.", "Ich achte darauf, dass auch neue Mitspielende dazugehören.", "Ich sortiere die Karten. Morgen können wir wieder zusammen spielen."],
		"gesture": "card_play", "learning": "Im Kartenclub übst du, zuzuhören und freundlich miteinander umzugehen. Die Karte der Schildkröte zeigt dir den Weg in die Mission."
	},
	"rabbit": {
		"interest": "Ich probiere gern Kartentricks. Wenn etwas noch nicht klappt, möchte ich es in Ruhe noch einmal versuchen.",
		"activities": ["Einen Trick üben", "Mit Freunden spielen", "Einen neuen Versuch machen", "Eine Lieblingsrunde erzählen"],
		"details": ["Ich übe einen kleinen Trick, Schritt für Schritt.", "Ich spiele mit den anderen. Gewinnen ist nicht alles.", "Ich probiere einen anderen Weg, wenn mein erster Versuch nicht klappt.", "Ich erzähle, was heute gut geklappt hat und wobei ich Hilfe möchte."],
		"gesture": "agree_nod", "learning": "Unsere Kartenclub-Mission fragt, welche Worte nach einer Niederlage helfen. Du darfst überlegen, wie du dich selbst fühlen würdest."
	},
	"otter": {
		"interest": "Ich mag Werkzeuge und finde gern heraus, warum sich ein Rad leicht oder schwer dreht.",
		"activities": ["Reifen prüfen", "Werkzeuge ordnen", "Karts vorbereiten", "Die Werkstatt aufräumen"],
		"details": ["Ich prüfe die Reifen, bevor ein Kart losfährt.", "Jedes Werkzeug bekommt einen festen Platz.", "Ich schaue mir Reifen und Lenkung noch einmal an.", "Ich lege die Werkzeuge zurück, damit wir sie morgen wiederfinden."],
		"gesture": "point_portal", "learning": "Als Kart-Kurier bringst du Körbe zum Bauernhof. Dort rechnest du mit dem Dachs passend zu deiner Schulstufe."
	},
	"frog": {
		"interest": "Ich erkunde gern Wege und erkläre anderen, wie sie sicher an ihr Ziel kommen.",
		"activities": ["Wege prüfen", "Eine Route zeigen", "Am Kart-Treff helfen", "Die letzte Runde planen"],
		"details": ["Ich schaue, ob auf den Wegen genug Platz ist.", "Ich zeige eine Route mit gut erkennbaren Orten.", "Ich erinnere alle: langsam fahren, wenn jemand auf dem Weg ist.", "Ich überlege, welche Wege wir morgen erkunden können."],
		"gesture": "point_portal", "learning": "In der Kart-Kurier-Mission findest du den Bauernhof und den Rückweg. Die Weltkarte und markante Orte helfen dir."
	},
	"turtle": {
		"interest": "Ich beobachte gern das Wasser und lese Nachrichten, die mit den Booten ankommen.",
		"activities": ["Am Hafen nachsehen", "Nachrichten lesen", "Auf ein Boot warten", "Den Steg prüfen"],
		"details": ["Ich schaue nach, ob ein Boot oder eine Flaschenpost angekommen ist.", "Ich lese eine Nachricht ganz in Ruhe.", "Ich warte geduldig. Du kannst jederzeit mit mir sprechen.", "Ich sehe noch einmal nach dem Steg, bevor der Tag zu Ende geht."],
		"gesture": "agree_nod", "learning": "Bei der Flaschenpost liest du selbst. Wenn ein Wort schwierig ist, schauen wir auf seine Laute und den Zusammenhang."
	},
	"badger": {
		"interest": "Ich pflanze gern und rechne aus, wie viele Körbe wir für unsere Ernte brauchen.",
		"activities": ["Die Ernte prüfen", "Körbe zählen", "Lieferungen vorbereiten", "Werkzeug verstauen"],
		"details": ["Ich schaue, was auf dem Feld schon reif ist.", "Ich zähle die Körbe für unsere Äpfel.", "Ich bereite die Ernte für unsere Nachbarn vor.", "Ich verstaue das Werkzeug und plane den nächsten Tag."],
		"gesture": "point_portal", "learning": "Beim Kart-Kurier rechnest du mit Körben und Äpfeln. Du kannst jede Menge in kleine Gruppen aufteilen."
	},
	"squirrel": {
		"interest": "Ich sammle gern Äpfel und suche verschiedene Wege, eine Menge zu zählen.",
		"activities": ["Äpfel ansehen", "Die Ernte zählen", "Kisten für den Markt füllen", "Leere Körbe sammeln"],
		"details": ["Ich schaue nach den Äpfeln am Baum.", "Ich zähle langsam und prüfe, ob ich einen Apfel übersehen habe.", "Ich fülle die Kisten für den Markt.", "Ich sammle die leeren Körbe für morgen."],
		"gesture": "agree_nod", "learning": "In der Mission Äpfel für den Markt rechnest du selbst. Es gibt passende Aufgaben für alle vier Schulstufen."
	},
	"lion": {
		"interest": "Ich teile gern Vorräte gerecht und möchte wissen, was meine Nachbarn brauchen.",
		"activities": ["Den Markt vorbereiten", "Obst verteilen", "Vorräte zählen", "Den Markt aufräumen"],
		"details": ["Ich bereite den Markt für unsere Nachbarn vor.", "Ich überlege, wie wir das Obst gerecht verteilen.", "Ich zähle, was noch da ist und was wir morgen brauchen.", "Ich räume auf und stelle die Körbe zurück."],
		"gesture": "point_portal", "learning": "Für unseren Markt holst du Äpfel vom Bauernhof. Beim Eichhörnchen übst du das Rechnen an einer echten Aufgabe."
	}
}

var elapsed := 0.0


static func safe_delta(delta: float) -> float:
	return clampf(delta, 0.0, MAX_STEP) if is_finite(delta) else 0.0


func advance(delta: float, paused := false) -> void:
	if not paused:
		elapsed = fposmod(elapsed + safe_delta(delta), PHASE_SECONDS * PHASES.size())


func phase_index() -> int:
	return clampi(int(elapsed / PHASE_SECONDS), 0, PHASES.size() - 1)


func activity(figure_id: String) -> Dictionary:
	if not PROFILES.has(figure_id):
		return {}
	var profile: Dictionary = PROFILES[figure_id]
	var phase := phase_index()
	return {
		"phase": PHASES[phase], "title": str(profile.activities[phase]),
		"detail": str(profile.details[phase]), "interest": str(profile.interest),
		"gesture": str(profile.gesture), "learning": str(profile.learning)
	}


func day_description(figure_id: String) -> String:
	if not PROFILES.has(figure_id):
		return ""
	var lines: Array[String] = ["Das ist mein Tag in dieser Spielwelt:"]
	var profile: Dictionary = PROFILES[figure_id]
	for index in range(PHASES.size()):
		lines.append("%s: %s." % [PHASES[index], str(profile.activities[index])])
	lines.append("Du kannst mich jederzeit ansprechen. Es gibt keine Wartezeit für deinen Auftrag.")
	return "\n".join(lines)


## A real authored walking clip is mandatory. Kart seated/idle gestures must
## never be used to slide a sitting figure across the floor.
static func walk_clip(player: AnimationPlayer) -> String:
	if not is_instance_valid(player):
		return ""
	for clip in player.get_animation_list():
		if str(clip).get_file().to_lower() not in ["walk", "walking", "walk_forward"]:
			continue
		var animation := player.get_animation(clip)
		if animation != null and is_finite(animation.length) and animation.length > 0.0:
			return str(clip)
	return ""


func candidate(figure_id: String, home: Vector3, current: Vector3,
		observer: Vector3, delta: float, walking_available: bool,
		driving := false, reduced_motion := false, paused := false) -> Vector3:
	var step := safe_delta(delta)
	if paused or reduced_motion or not walking_available or step <= 0.0 or not PROFILES.has(figure_id):
		return current
	if not home.is_finite() or not current.is_finite() or not observer.is_finite():
		return current
	var distance := Vector2(current.x - observer.x, current.z - observer.z).length()
	if distance <= (DRIVE_BUFFER if driving else TALK_BUFFER):
		return current
	var identity := IDS.find(figure_id)
	# These are short local paths, not unverified travel through buildings.
	var point_index := posmod(int(elapsed / 18.0) + identity, LOCAL_POINTS.size())
	var target: Vector3 = home + LOCAL_POINTS[point_index]
	if Vector2(current.x - home.x, current.z - home.z).length() > MAX_WANDER:
		target = home
	return current.move_toward(target, WALK_SPEED * step)
