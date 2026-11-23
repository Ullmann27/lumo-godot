# Gemeinsame World-Integration für Kandidat 2071

Stand: 23. November 2026. Dieser Stand vereint Hauptteam-Korrekturen aus `f4bbcd988f1c5bc694a5d098aff196c8f2e2c198` mit dem geprüften Supportstand `93557b3ca206916a39fdeaa6ae6ce05442b08846`.

Die drei additiven Konflikte in `lumo_world.gd` betreffen Preloads, Zustandsfelder und Initialisierung. Beide Funktionsumfänge bleiben erhalten: Kamerafreihaltung, tatsächliche HUD-Mindestgrößen und Schulzugang des Hauptteams sowie Karte, Freundepost, dauerhafte Ampel und Speicherfehlerbehandlung von Team B.

Der Editor importiert Ressourcen jetzt nacheinander. Das ist eine gezielte Maßnahme nach dem tatsächlichen SIGABRT im APK-Lauf 45181487984. Der vollständige [lokale Mechanismus- und Fontnachweis](team-b-evidence/import-serial-validation.json) benennt seine Grenzen ausdrücklich. Der SIGABRT wurde im kleinen Font-Testprojekt nicht reproduziert; vollständiger Import, Export, neue Sichtprüfung und Android-Prüfung bleiben ausstehend.

Eine neue tatsächliche World-HUD-Regression des Hauptteams gehört zu den folgenden Prüfungen. Die Originalaufnahmeorte bleiben erhalten. Dieser Integrationscommit ist keine visuelle oder Android-Freigabe. Main bleibt unverändert.
