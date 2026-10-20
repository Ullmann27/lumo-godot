# AGENTS.md – Lumo Kart / Godot · Cloud-Checkpoint-Pflicht

**Auftrag:** Schütze bereits erstellte Lumo-Kart-3D-Grafik, Original-Fuchs, Fahrzeugmodelle, Szenen und Menügestaltung beim Codex-/Astra-Nutzungslimit.

## Vor Änderungen
1. \`git status --short --branch\`, \`git log -1 --oneline\` und bereits vorhandene lokale Änderungen überprüfen. NIEMALS alte Cloud-Dateien durch blindes Checkout, \`git reset --hard\` oder \`git clean -fd\` löschen.
2. Falls Vorarbeiten lokal liegen, sie als Erstes sicher versionieren. \`python3 tools/lumo_autosave.py check\` kontrolliert den Stand und die Filterung.
3. Bei GitHub-Schreibzugang den Watcher im Hintergrund starten:
   \`\`\`bash
   nohup python3 -u tools/lumo_autosave.py watch --interval 120 > /tmp/lumo-kart-autosave.log 2>&1 < /dev/null &
   \`\`\`
4. **Zusätzlich nach jedem kleinen funktionalen 3D-/UI-Patch, vor Render-/Build-Schritten und mindestens alle fünf Minuten** explizit \`python3 tools/lumo_autosave.py once\` ausführen. Den letzten \`[LUMO-CHECKPOINT] REMOTE SAVED\`-Branch + SHA dokumentieren. \`LOCAL SAVED\` alleine reicht nicht.

## Design- und Integrationsgrenzen
- Source of truth für die aktuellen Grafiken: \`assets/kart/landing/\`, \`scripts/games/kart_reference_landing.gd\`, \`kart_garage_menu.gd\`, \`kart_island.gd\`; aktueller Feature-PR #111. Vor Änderung gegen aktuellen Head vergleichen.
- Der originale orange-weiße Fuchs mit blauer Fliegerbrille bleibt. Kein Umbau auf fremde Marken-/Mario-Kart-Assets. Rennphysik/Spielstände/Android-Kopplung bleiben unberührt, sofern Auftrag ausschließlich visuell ist.
- \`main\` schützen, keine Force-Pushes, keine auto-merges, kein Release ohne Freigabe. Kein Geheimnis/Signaturschlüssel in GitHub.
- Autosave ist nur eine **Best-Effort Cloud-Prozesssicherung**: ein suspendierter Workspace kann den Watcher beenden; explizite häufige Remote-Commits bleiben Pflicht.
- \`[skip ci]\`-Zwischenstände sind keine bestandenen Tests. Vor dem Draft-PR einen abschließenden Commit ohne Skip-Marker und echte Godot-Render-Screenshots/Testprotokolle liefern.

## Bei Wiederaufnahme
1. Cloud-Task noch offen: lokale Dateien zuerst prüfen und retten.
2. Sonst jüngsten auf GitHub gesicherten \`checkpoint/lumo-cloud-...\`-Branch verwenden und dort weiterarbeiten.
3. Wenn kein Remote-Commit der letzten Cloud-Runde existiert, kann der Code nicht aus GitHub rekonstruiert werden, ohne seine ursprüngliche Sitzung oder separat archivierte Dateien zu erreichen.

Details: https://github.com/Ullmann27/lumo-lernen/pull/394
