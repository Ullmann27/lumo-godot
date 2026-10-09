# Neu aufgebaute Lap-Regressionen nach Workspaceverlust

Der Produktcode wurde bytegenau wiederhergestellt: `kart_island.gd` SHA256
`7e600e57bcd2c7783da04caca22be4b51004d375e984aabe3b386861ffc1a6db`.
Der persistierte Wiederherstellungsstand ist `09b5a25e1b26666d7db7f257d3224856fc2b0b9b`,
Tree `322b23407ce619b6bd413f29d27ebd64838a970a`; alle857 getrackten Dateien
wurden nach Gitblob, Bytezahl und Modus geprüft. BASE bleibt `c95fc489…`.

Die beiden früheren Testdateien mit Hashes `a6f171…` und `a2605686…` wurden
nicht wiedergefunden. Die jetzigen Ergänzungen sind neue Implementierungen
auf den frisch aus c95 gelesenen Originalproben. Sie übernehmen keinen alten
Test-, PNG- oder Runtime-Abschluss. Die früheren Übergaben bleiben historische
Beschreibungen und sind kein neuer Nachweis vorhandener Belegdateien.

Continuity behält die48 tatsächlich vorhandenen ursprünglichen Assertions und ergänzt103 neue
Wertebedingungen: echtes Fahren durch16 Tore, Pause/Grafikwechsel/NEW-instance
Reopen in Runde2, beide Rundenintervalle, öffentliche und sichtbare Zeiten,
fertiges Ergebnis erneut öffnen, sofortige HUD-Zustände und genau ein ACK/
Host-Reward.20 zugewiesene ConfigFile-Paare, Versionsmigration, durable unbekannte
Teilmessung und bekannte/ungültige Payloadbestwerte bleiben eigene Zustandsfixtures.
`kart_lap_session_fixtures.gd` enthält ausschließlich diese neuen Testfixtures;
seine Hashbindung steht zusätzlich im JSON. Es ist kein weiterer Probeentrypoint.

CompleteFlow behält26 tatsächlich vorhandene ursprüngliche Assertions, den ursprünglichen Gate4-Resume
und die fünf alten PNG-Rollen. Neu sind Touch-Pause/Save/Reopen an Gate12 sowie
fertiges Ergebnis-Reopen vor ACK und `06-reopened-result.png`. Kontrolliert
werden tatsächlicher ResultStats-/HUD-Text, versteckte/deaktivierte Fahrcontrols,
angezeigte0km/h bei fertigem Rennen, unveränderte öffentliche Ergebnis-ID,
integer solved0 und genau ein Testhost-Reward. Das ist kein Android-Walletbeweis.

Die historische45/21-Zählung war unvollständig. Der frisch gelesene c95-Stand
(Gitblobs `7a391c8…` und `23b4402…`) enthält48/26 vollständige assert-Aufrufe;
sie werden als geordnete AST-Unterfolge ohne Positionsmetadaten geprüft.

Der neue Coldimport mit offizieller Godot4.6.3 ist geschlossen ohne Enginefehler.
Weitere Abnahme folgt auf identischen neuen Probe-Dateien: c95-BASE RED,
wiederhergestellter Produktcode GREEN, strict GL und neue echte Runtime-PNGs.
Bis diese Läufe tatsächlich geschlossen sind: **DRAFT / NOT FINISHED**.
APK1906, Android/API35/36, physisches Fold und Geräteperformance sind hier
**NOT EXECUTED**. Alle22 App-Probeentrypoints bleiben erforderlich.
