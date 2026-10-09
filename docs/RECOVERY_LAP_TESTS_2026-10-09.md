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

Continuity behält die48 tatsächlich vorhandenen ursprünglichen Assertions und ergänzt104 neue
Wertebedingungen: echtes Fahren durch16 Tore, Pause/Grafikwechsel/NEW-instance
Reopen in Runde2, beide Rundenintervalle, öffentliche und sichtbare Zeiten,
fertiges Ergebnis erneut öffnen, sofortige HUD-Zustände und genau ein ACK/
Host-Reward.20 zugewiesene ConfigFile-Paare (ein gültiges,19 ungültige), Versionsmigration, durable unbekannte
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
Frischer erster104er-BASElauf ergibt54PASS/50FAIL; identische finale
Abnahme folgt auf identischen neuen Probe-Dateien: c95-BASE RED,
wiederhergestellter Produktcode GREEN, strict GL und neue echte Runtime-PNGs.
Bis diese Läufe tatsächlich geschlossen sind: **DRAFT / NOT FINISHED**.
APK1906, Android/API35/36, physisches Fold und Geräteperformance sind hier
**NOT EXECUTED**. Alle22 App-Probeentrypoints bleiben erforderlich.

## Aktueller weiterer Rückkehr-Befund · DRAFT

Die ursprüngliche neue FullFlow-Probe zeigte einen tatsächlichen sporadischen
ACK-Save-Fehler. Zwei unveränderte Läufe scheiterten, ein unveränderter Lauf
bestand. Entfernen liefert Error0 und zunächst Datei-abwesend; die spätere
Wiederkehr des fertigen Dateikörpers ist durch externe Diagnose belegt, der
Schreibaufruf dieses sporadischen Falls noch nicht identifiziert. Die bisherigen
Fehler und Diagnosequellen bleiben getrennt von gültigen Runtime-Abschlüssen.

Ein separater normaler queue_free-Fall ist hingegen eindeutig: Die aktive
Szene schreibt nach akzeptiertem fertigem Return im _exit_tree denselben
Save erneut. Identische externe acht Zustandsbedingungen auf c95 und7e600
zeigen jeweils6PASS/2FAIL. Ein flüchtiger Instanzguard, erst nach akzeptiertem
completed/noncup/recoverable Hostreturn gesetzt, verhindert dies; Start und
gültige Restore setzen ihn zurück, er wird nicht serialisiert. Standalone
SceneRouter→GameHub zeigte denselben echten Fehler zusätzlich; dieser
bekannte lokale Rückweg setzt den Guard ebenfalls. Zehn identische externe
Bedingungen auf dem reparierten Stand sind10PASS/0FAIL, mit tatsächlich
ausgeführtem SceneRouterwechsel. Dies sind zugewiesene Zustandsfixtures,
kein neuer gefahrene-Runden-Nachweis.

Die dauerhafte Integration ruft kart_handoff_lifecycle_fixtures.gd aus dem
aktiven Continuity-Entrypoint nach dessen104er-JSON/Screenshot/Teardown und
vor seinem ursprünglichen PASS/quit auf. Eigenes exports/race-bridge/
handoff-lifecycle-evidence.json und10er-Marker; kein weiterer Entrypoint.
probe_sha256/probe_path binden Continuity, nicht den nicht aktiven
RaceBridge-Entrypoint (dieser bleibt bytegleich). Alle48/26 ursprünglichen
Assertion-Callsites bleiben; dies sind statische AST-Zahlen, keine behaupteten
instrumentierten Einzeltest-Ausführungszähler. Source-vs-Runtime-Neuabnahme
auf den folgenden Quellen bleibt PENDING, ebenso die Callerklärung des
sporadischen Touch-/ACK-Falls. Android/APK/Fold/Performance bleiben NOT EXECUTED.

| Aktueller Code | SHA256 |
|---|---|
| scripts/games/kart_island.gd | 7247dd551b900194936d60d31e4436d0e2a9dc74fb4c91e2306d94f6d8689c8c |
| scripts/tests/kart_race_continuity_regression.gd | f82c717207786cf666f66ff33dbbda5992e11b17623f5481ab58750dc263441f |
| scripts/tests/kart_lap_session_fixtures.gd | b9155b5ddb7332875d96a7785f0ea3fb7749a7670fac18562815f88bc88a2ff9 |
| scripts/tests/kart_complete_flow_regression.gd | efeb21871cf8be91e5bf74226d1e70e51f52729a8a3ed45a242984b0fb7990f5 |
| scripts/tests/kart_handoff_lifecycle_fixtures.gd | fb78dcba3a212ef8b540a2b125fe7baabe123d1f85975451ebaddde9a3d96cef |
