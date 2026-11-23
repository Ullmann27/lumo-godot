# Lumo Kart – Online-Rennen mit Freunden

## Tatsächlicher Ablauf

1. Das Kind öffnet **Spielen → Lumo Kart → Online-Rennen**.
2. Beim ersten Mal wählt es einen eigenen festen Spielernamen, beispielsweise `Alina_04`. Der Name des Lernprofils wird nicht übernommen.
3. Unter **Freund hinzufügen** gibt es den Spielernamen des anderen Kindes ein. Das andere Kind erhält eine **Freundschaftsanfrage** und nimmt sie ausdrücklich an.
4. Die bestätigte Freundschaft erscheint auf beiden Geräten. Die Liste zeigt **online** oder **offline**.
5. Ein online angezeigter Freund kann separat **zum Rennen eingeladen** werden. Nach Annahme sehen beide den Rennraum. Erst wenn beide bereit sind und dieselbe Strecke geladen haben, gibt der Server die gemeinsame Startzeit vor.
6. Beide fahren ihr eigenes Kart mit ihrer vorhandenen Bauteilauswahl. Das andere Kart steht als sichtbarer Fahrer mit Namen in derselben 3D-Welt. Die obere Anzeige zeigt die tatsächliche Position **1/2 oder 2/2**; Name und Abstand des anderen Fahrers stehen darunter.
7. Der Server bestätigt Zieleinläufe und sendet beiden dasselbe Ergebnis. Nach einem Verbindungsabbruch wird kein KI-Gegner als vermeintlich echter Freund eingesetzt.

Der Modus verwendet die bestehende Zwei-Runden-Fahrphysik. Die entfernten Karts werden mit Quaternionen interpoliert; sie bleiben auch in Loopings korrekt orientiert. Die Karts berühren einander nicht physisch. Renn-Items werden zwischen Online-Fahrern derzeit nicht synchronisiert. Es ist ein gemeinsames Live-Rennen ohne Ranglisten- oder serverseitige Vollsimulation, kein Datei-Geistervergleich.

## Identität und gespeicherte Daten

Der Gerätezugang basiert auf einem zufälligen 256-Bit-Schlüssel. Dieser wird lokal **pro stabilem childKey** getrennt gespeichert. Der childKey wird nur zur lokalen Dateinamensbildung gehasht und niemals an den Server geschickt. Der öffentliche Spielername enthält keine Gerätekennung.

- Lokal: `user://lumo_kart_online_identity_<childhash>.cfg` und eine getrennte Freundelisten-Kopie.
- Der Identitätsschlüssel darf nicht in Spielstandsicherungen, Diagnoselogs oder freigegebene Dateien gelangen.
- Serverseitig: SHA-256-Kennung des Schlüssels, fester Spielername, bestätigte Freundschaften, offene Freundschaftsanfragen.
- Keine E-Mail-Adresse, kein Geburtstag, kein Lernprofilname und kein Chat.
- Der Server speichert niemals den Klartext-Geräteschlüssel. Die Anmeldung überträgt ihn ausschließlich über WSS.
- Namensreservierungen sind durch einen transaktionalen, nicht zwischen Groß- und Kleinschreibung unterscheidenden Unique-Index geschützt.
- Freundschaftsanfragen bleiben bis zur Annahme, Ablehnung oder 14 Tagen Ablaufzeit bestehen. Freundschaften sind dauerhaft.
- Die lokale Freundeliste zeigt nach einer getrennten Verbindung keine veralteten Online-Markierungen.
- Das Gerät bewahrt den Zugang; eine Wiederherstellung eines verlorenen Geräteschlüssels durch E-Mail oder Passwort ist in diesem Modus nicht implementiert.

## Hosting

**Ein flüchtiger kostenloser Relay reicht für dauerhaft reservierte Namen nicht aus.** Der mitgelieferte Dienst verwendet SQLite auf einem langlebigen Datenträger, eine Instanz und TLS am vorgeschalteten Webserver.

`render.yaml` bereitet einen Webdienst mit einem persistenten Datenträger vor. Der dort gewählte Plan und Datenträger sind vor einer tatsächlichen Erstellung vom Eigentümer freizugeben. Es wurde kein Servername und keine WSS-Adresse erfunden oder als aktiv vorbelegt.

Konfiguration:

| Variable | Zweck |
|---|---|
| `HOST` | Lokal standardmäßig `127.0.0.1`; Hosting setzt `0.0.0.0`. |
| `PORT` | Standard 8765 oder vom Host vorgegeben. |
| `LUMO_DATABASE_PATH` | Dauerhafter SQLite-Pfad; bei Render `/var/data/lumo/lumo-kart.sqlite3`. |

Endpunkte:

- `GET /health`: technische Bereitschaft, keine Spieler- oder Schlüsseldaten.
- `GET /ws`: WebSocket-Verbindung; die App akzeptiert für Internetverbindungen ausschließlich **wss://…/ws**.
- Unverschlüsseltes `ws://127.0.0.1:PORT/ws` ist nur im ausdrücklich aktivierten lokalen QA-Modus zugelassen.

Start lokal:

```sh
python -m pip install -r server/kart_online/requirements.txt
LUMO_DATABASE_PATH=/absoluter/persistenter/pfad/lumo.sqlite3 python server/kart_online/relay.py
```

Der Docker-Dienst läuft ohne Root-Rechte. Ein benannter oder explizit verwalteter Datenträger muss unter `/data` eingebunden werden. SQLite-Sicherungen sind mit der SQLite-Backup-API oder bei vollständig beendetem Dienst einschließlich abgeschlossener WAL-Übernahme anzufertigen; das Kopieren einer laufenden einzelnen Datenbankdatei reicht nicht.

## App-Verkabelung

Startoptionen:

- `friendsOnline: true`: separate Elternfreigabe. Eine WLAN-Freigabe erlaubt nicht automatisch Internet-Rennen.
- `kartOnlineEndpoint: "wss://…/ws"`: tatsächlicher bereitgestellter Server.
- `childKey`: vorhandener lokaler, stabiler Profilbezug.

Ein leerer Endpunkt zeigt den Einrichtungsstatus und baut keine Verbindung auf. Vorhandene WLAN-Räume und Datei-Geisterduelle bleiben erhalten.

Die zentrale Integration liegt in `scripts/games/kart_friends/kart_friend_duel.gd`. `kart_online_race.gd` nutzt dessen bestehende Aufbau-, Tick-, Ziel- und Ergebnis-Hooks. Die Fahrphysik und die Werteberechnung kommen weiterhin aus den normalen Kart-Modulen.

## Transport und Grenzen

- Zwei Teilnehmer pro Raum, maximal 256 Verbindungen; acht gleichzeitig pro tatsächlichem Transport-Absender.
- Absender hinter einer gemeinsamen Reverse-Proxy-Adresse teilen dieses Transportlimit; vor größeren Nutzerzahlen ist die vorgeschaltete Ratenbegrenzung mit einem vertrauenswürdig konfigurierten Proxy abzustimmen.
- 4 KiB maximale Nachricht, 20 Positionspakete pro Sekunde im Client, serverseitige Raten- und Zahlenprüfungen.
- Zufällige, nicht erratbare Einladungs- und Raumkennungen.
- Beidseitig bestätigte Freundschaft ist Voraussetzung für eine Renn-Einladung.
- Abgelaufene oder fremde Einladungen lassen sich nicht annehmen.
- Strecken-Version, Länge und Rundenzahl müssen vor dem gemeinsamen Start übereinstimmen.
- Reihenfolge, Positions-/Quaterniongrenzen, Fortschritt und Checkpoints werden überprüft; die Zielzeit kommt vom Server.
- Die lokale Pause friert die gemeinsame Online-Uhr nicht ein.
- Der Server übernimmt weder vom Client geschickte Fahrfaktoren noch Belohnungen.
- WebSocket verwendet TCP: stark schwankende Verbindungen können trotz Interpolation merkliche Verzögerung erzeugen. Die Architektur behauptet keine vollständige serverseitige Anti-Cheat-Physik.

## Verifikation

Python-Protokolltests mit echten unabhängigen WebSocket-Verbindungen:

```sh
python -m unittest discover -s server/kart_online -p test_relay.py -v
```

Zwei separate echte Godot-Prozesse, separater Relay-Prozess, anschließend vollständiger Relay-Neustart gegen dieselbe Datenbank und erneutes Rennen:

```sh
python scripts/tests/kart_online_two_process.py --godot /pfad/zu/godot --output /pfad/zu/pruefbelegen
```

Die originale Ausgabe jedes Clients und Servers wird erhalten. Die Ergebnisdatei benennt ausdrücklich **lokales WebSocket**, getrennte Prozesse und Datenbankpersistenz. Dieser Nachweis ersetzt weder ein bereitgestelltes Internet-Endpunkt-Testpaar noch zwei physische Android-Geräte.

Offizielle API-Grundlage: [Godot 4.6 WebSocketPeer](https://docs.godotengine.org/en/4.6/classes/class_websocketpeer.html).
