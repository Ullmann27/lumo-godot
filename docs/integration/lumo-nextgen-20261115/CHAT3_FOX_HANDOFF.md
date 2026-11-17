# Übergabe Chat 3 · Original-LUMO, Blender-Rig und räumliche Lernwelt

Arbeitszweig: \`feature/lumo-nextgen-fox-20261115\`, Start exakt vom bis dahin vom App-Host angepinnten Godot-Commit \`d38967f6d39bc20188afe525b0af122d80634029\`. Das v1-Protokoll liegt im App-Repository unter [PROTOCOL_V1.md](https://github.com/Ullmann27/lumo-lernen/blob/integration/lumo-learning-nextgen-20261115/docs/integration/lumo-nextgen-20261115/PROTOCOL_V1.md) und ist Grundlage jeder Änderung.

## Eigene Dateien
- \`scripts/characters/lumo/**\`, \`scenes/characters/lumo/**\`, neue Blender-Quellen und GLB unter einem klar begrenzten \`assets/learning_nextgen/**\`-Bereich, \`scripts/learning/**\` und \`scenes/learning/**\` soweit Darstellung/Mimik/Objekt-Gesten betroffen sind.
- Neue native Test- und Renderproben, ausschließlich Lern-/Fuchsbereich: \`scripts/tests/learning_nextgen_*.gd\`, \`tools/learning_nextgen/**\`.
- Nicht anfassen: \`scripts/games/kart_*\`, Kart-Strecken, Dschungel-Lanes, Wagen/Renn-Physik, Belohnungshost, speicherführende Projektteile.

## Verbindlich
1. Den **vorhandenen Originalfuchs** verwenden; aktuelles \`scripts/learning/learning_world.gd\` erzeugt bereits \`lumo_rigged_actor.gd\` und kennt \`set_teaching_target\`, \`teacher_react\`, \`apply_speech_sample\`. Erhalte diese produktiven Schnittstellen. Blender-Rig/Morphs, Augen, Kopf-/Pfotenbewegungen, Lippen-/Kieferbewegung und visuell plastische Materialien dürfen die Identität nicht austauschen.
2. Drei gemeinsame Referenzszenen: 8+5: Zehnerfeld 8 plus 5, zwei ins Feld, drei übrig; „Warum zuerst zwei?“ mit genauem Blick-/Pfotenobjekt; „Ba–na–ne“ synchrones Silbenzeigen; sichtbare Mustereinheit ohne vorzeitige Ergebnisvergabe. Größere Lernabdeckung erst nach stabiler erster Verbindung.
3. Jedes interaktive Objekt erhält stabile lokale Objekt-IDs, gekoppelte Geste/Blick, nicht nur Koordinaten. Ruhiger Modus und mind. 48dp in der Host-UI; UI safe areas/Portrait/Fold.
4. Nur wirkliche \`audio.status playing && audible\` darf den Mund bewegen; Stop/Taskwechsel/Background sofort neutrales Rig und keine laufenden Tweens. Kein gefälschtes Phonem-Timing.
5. Godot-4.6.3 Import plus tatsächliche Android-sichtbare Probe, Renderbilder und gemessene FPS mit konkretem Gerät. Blender-Stills separat ausweisen.

## Übergabe an Chat 1
GLB/BLEND-Quellen, Szenen, Import-Hashes, IDs und API, SHA der eigenen Änderungen, Render-/Tests mit Umgebung, fehlende Asset-Probleme. App-Pin auf diesen Native-Commit **erst nach** Host-/Godot-Abnahmetests durch Integrationschat. Keine autonomen Aussagen über unsichtbare Chat-Arbeit, kein Merge \`main\`.
