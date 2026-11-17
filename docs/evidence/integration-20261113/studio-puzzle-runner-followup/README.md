# Standalone-Studio: veröffentlichte Puzzle-Gates anschließen

Der am 13.11.2026 um 18:09:46 UTC veröffentlichte Producer-Commit 796b2818ff729dc5389a92f8bf1f7fd7e6b6d93e (Tree ffd943c83079c5957514934ad7077f32e743fe68, Parent ab9237025e5e5a30a168c4d1fbbd0a24a82690b6) ergänzt den separaten Studio-Runner. Produkt und GDScript-Probe bleiben unverändert. Die exakten beiden veröffentlichten Quellblobs sowie die unveränderte GitHub-Commitantwort liegen unter producer/. Dies ist kein weiterer Produktfix.

## Anschluss auf unserer bestehenden Integration

Die veröffentlichte Orchestrierung wird auf dem lokalen Basiscommit 108dc8969cdd6e0f69a307f755bb2512cb2c6722 / Tree 07591ef728f12a665ab226a74778535f05583d1d erhalten: Puzzle-Lifecycle headless mit 180 Sekunden, tatsächlich gerendert mit 600 Sekunden und --capture. LUMO_PUZZLE_MENU_EVIDENCE_DIR ist gesetzt; headless und gerenderte Ausgaben haben getrennte Verzeichnisse. Alle neun alten Studio-Aufrufe, Marker und Budgets bleiben erhalten; der Runner verlangt elf Prüfpaar-Ergebnisse.

Der bestehende 24er-Studio-Rasterhelper bleibt unverändert. Der bereits vorhandene strikte Puzzle-Helper verlangt zusätzlich sechs exakt benannte Raster in 960×540 und 640×360, einschließlich vollständiger Dekodierung und sichtbarer nicht einfarbiger Pixel. Die beiden Manifeste bleiben bewusst getrennt: renderer-images.json (24) und puzzle-menu-images.json (6). Der alte Producer-Heredoc wird nicht wieder eingeführt.

Präzise Validierungsgrenze: Der Native-24er-Helper prüft Anzahl, PNG-Signatur, IHDR-Mindestgröße und Hashes; die vollständige Dekodierung dieser 24 Dateien erfolgt im bestehenden Host-Verifier. Der zusätzliche Native-6er-Puzzle-Helper dekodiert bereits vollständig. Diese bestehenden Helper wurden nicht geändert.

## Gezielter Vorher-/Nachher-Nachweis

Die drei neuen Tests liefen zunächst gegen den unveränderten Studio-Runner: drei Methoden, sieben konkrete Assertion-Fehler, Exit 1. Nachgewiesen wurden die fehlenden zwei Aufrufe und die unzulässige Annahme fehlender, umbenannter, abgeschnittener, einfarbiger oder falsch dimensionierter Puzzle-Raster sowie eines nativen Fehlers nach PASS bei Prozess-Exit 0.

Nach dem Anschluss lief genau die bestehende Runner-Suite, ergänzt um diese drei Methoden: 18 Tests bestanden, 0 Skips, Exit 0. Das unveränderte Testfile ist über identische Hashes zwischen Rot- und Grünlauf gebunden. Der Grünlauf verwendete 48,871 Sekunden laut unittest; vollständige unbearbeitete Ausgabe liegt in green-runner.log.gz. Bash-Syntaxprüfung und git diff --check bestanden ebenfalls.

Befehl: python3 -m unittest discover -s tools/tests -p test_nextgen_runner.py -v

Die Tests führen die tatsächlichen kopierten Shell-Runner und Python-Validatoren mit ausdrücklich synthetischem Engine-/PNG-Input aus. Diese Fixtures sind keine echten Spielszenen oder Rendererbilder. Es wurden keine Godot-, Renderer-, Android- oder früheren Gesamtprüfungen wiederholt.

## Quellen und Grenzen

13 Dateien wurden um die Läufe gebunden; ihre Hashes waren innerhalb jedes einzelnen Laufs stabil. Ausschließlich tools/validate_studio.sh und tools/tests/test_nextgen_runner.py wurden durch diesen Anschluss implementiert. Native-Nextgen43 und die Host43-Verifier-/Recorder-/Vertragstestdateien blieben bytegleich. Eine parallele Änderung des zusätzlich beobachteten Host-Grafik-Vertragstests zwischen den Ausgangs- und späteren Momentaufnahmen wird im Manifest ausdrücklich separat ausgewiesen; sie gehört nicht zu diesem Patch und nicht zu den vom Native-Test ausgeführten Quellen.

before/ und after/ enthalten die exakten beiden Integrationsdateien, implementation.patch.gz deren vollständiges Delta. Alle komprimierten Dateien besitzen leeren gzip-Dateinamen, mtime=0 und geprüften bytegleichen Roundtrip. Manifest und SHA256SUMS dokumentieren Original- und Speicherhashes.

Die veröffentlichten Producer-Belege beschreiben eigene lokale Läufe auf modifiziertem ab923-Stand. Sie werden nicht als unsere neue gemeinsame CI-Abnahme übernommen. Die vollständige CI muss auf dem von Root anschließend gesicherten kombinierten Stand laufen. Kein Receipt, Pin, Commit, Index oder Ref wurde durch diesen Auftrag geändert.
