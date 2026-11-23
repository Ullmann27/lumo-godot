# Gemeinsame World-Integration für Kandidat 2071

Stand: 23. November 2026. Dieser Stand vereint Hauptteam-Korrekturen aus `90648b0639391c88d3c2da0e3f235d30f725256d` mit dem geprüften Supportstand `93557b3ca206916a39fdeaa6ae6ce05442b08846`.

Der erste Integrationsschritt enthielt drei additive Konflikte in `lumo_world.gd` betreffen Preloads, Zustandsfelder und Initialisierung. Beide Funktionsumfänge bleiben erhalten: Kamerafreihaltung, tatsächliche HUD-Mindestgrößen und Schulzugang des Hauptteams sowie Karte, Freundepost, dauerhafte Ampel und Speicherfehlerbehandlung von Team B.

Der Editor importiert Ressourcen jetzt nacheinander. Das ist eine gezielte Maßnahme nach dem tatsächlichen SIGABRT im APK-Lauf 45181487984. Der vollständige [lokale Mechanismus- und Fontnachweis](team-b-evidence/import-serial-validation.json) benennt seine Grenzen ausdrücklich. Der SIGABRT wurde im kleinen Font-Testprojekt nicht reproduziert; vollständiger Import, Export, neue Sichtprüfung und Android-Prüfung bleiben ausstehend.

Der Folgeschritt übernimmt die unveränderten Authoring-Transformationen für Headless-Abfragen, eine echte Prüfung der Renderer-Puffer und den Platzbedarf des World-Joysticks. Sein einzelner Layout-Hunk wurde konfliktfrei übernommen; alle übrigen World-Methoden bleiben bytegenau erhalten.

Eine neue tatsächliche World-HUD-Regression des Hauptteams gehört zu den folgenden Prüfungen. Die Originalaufnahmeorte bleiben erhalten. Dieser Integrationscommit ist keine visuelle oder Android-Freigabe. Main bleibt unverändert.
