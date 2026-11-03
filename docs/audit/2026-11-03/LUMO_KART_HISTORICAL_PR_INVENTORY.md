# Lumo Kart – historische GitHub-PR-Inventur

Stand: 03.11.2026. Datengrundlage: GitHub Pull Request REST-API, Seiten 1–2, alle offenen und geschlossenen PRs, vom ersten bis zum neuesten. Vollständige **Metadateninventur**, keine Behauptung, dass sämtliche 110 PRs auf Quellcodeebene einzeln verifiziert oder integriert wurden. Basis der aktuell veröffentlichten 2004-APK: Godot `3689307a6392fd5756bc87ba0e36f3bef9df71e3`. Änderungen aus dem experimentellen PR #121 sind noch keine Veröffentlichung.

## Zusammenfassung

- 110 PRs von Nummer 1 bis 121 (fehlende Nummern sind Issues oder nicht vorhandene PRs).
- 13 gemergte PRs, 96 offene PRs, 1 geschlossen und ungemergt.
- **Befund aus Code-Vergleich:** PR #51 (65-Knochen Lumo und neun Clips) ist Vorfahr des 2004-Pins, die Technik ist enthalten, aber es existiert kein vollwertiger Foot-contact-Walk-Clip. PR #68 Bauwelt divergiere vom 2004-Pin: es existieren neun eigenständige Nachfolge-Commits; die Bauwelt-Zweige sind nicht blind zu mergen. PR #69 sowie PR #71 sind Vorfahren und deshalb teilweise integriert. PR #96 Asset-Fabrik ist Vorfahr, im aktuellen Quellstand bereits vorhanden. PR #111 moderne Kart-UI ist divergiert (34 Commits voraus, 246 zurück), deshalb muss die UI anhand einzelner Dateien verglichen statt durch ungeschützten Merge übernommen werden.
- **Akute P0:** Stunt-Schanze und 360°-Looping funktional richtig positionieren, echte speed-only Ballistik, Fehlversuche, Tempoanzeige. PR #121 experimentell umgesetzt; verbindliche Live-QA noch ausstehend, altes Release unverändert.
- **P1:** PBR-Asphalt und Laufstrecke durchgehend gleiche Designgrammatik, zusätzliche Mehrstufen-Licht- und Umgebungsqualität mit mobilem LOD; alte PRs #74, #71, #89, #92 und #111 gezielt prüfen.
- **P1:** Lumo-Rig: separate Lauf-/Fußkontaktanimation via 65-Bone-Skeleton, nicht nur `walk_loop`-Tween/gleitende Translation; Alt-PRs #51/#52 und Modell `Lumo-Animated-Mobile.glb` bewahren.
- **P1:** Bauwelt #68/#69/#81 echte Einzelobjekte, Kollisionen, Bau-/Speichermodus und Vorher/Nachher-Renderbilder auditieren; existierende Mechanik nicht als AAA-fertig deklarieren.
- **P2:** historische Menu-, High-End-Assets, Dunkelfahrt und Überraschungen; PRs #95–#116 gezielt per Quell-/Render-Diff vergleichen. Keine ungeprüften fremden 3D-Assets übernehmen.

## Alle Pull Requests

| PR | Status | Titel | Quellzweig |
|---:|---|---|---|
| [#1](https://github.com/Ullmann27/lumo-godot/pull/1) | merged | Lumos 3D-Abenteuer: Insel-Cup und Wolkeninseln | `codex/lumo-island-cup-2026-10-02` |
| [#2](https://github.com/Ullmann27/lumo-godot/pull/2) | merged | Lumo: Sonnenhafen-Kartspiel mit Neon-Stick und sicherer Mobilbedienung | `codex/lumo-kart-sunharbor-2026-10-02` |
| [#3](https://github.com/Ullmann27/lumo-godot/pull/3) | merged | Embed Kart with durable JNI results and visible compact pause navigation | `codex/lumo-unified-kart-2026-10-03` |
| [#4](https://github.com/Ullmann27/lumo-godot/pull/4) | open | Lumo Kart: freie Fahrt, vier Welten und vollständige Rennmodi | `codex/lumo-holographic-kart-2026-10-03` |
| [#5](https://github.com/Ullmann27/lumo-godot/pull/5) | merged | chore(agents): split Kart implementation and review by model | `chatgpt/lumo-agent-squad-2026-10-04` |
| [#9](https://github.com/Ullmann27/lumo-godot/pull/9) | merged | chore(lumo): add explicit Copilot Pro fallback agents for 3D work | `chatgpt/lumo-pro-agent-fallbacks-2026-10-05` |
| [#13](https://github.com/Ullmann27/lumo-godot/pull/13) | open | Opus-Übergabe: fehlende Kart-Geometrie reparieren und Fahrzeugtest absichern | `codex/opus-vehicle-regression-fix` |
| [#14](https://github.com/Ullmann27/lumo-godot/pull/14) | open | Lumo Kart: zehn Streckenpakete hochladen, ehrlich prüfen und Erweiterung an Copilot übergeben | `codex/track-reference-import-2026-10-05` |
| [#15](https://github.com/Ullmann27/lumo-godot/pull/15) | closed | [WIP] Upload ten track packages for Lumo Kart and hand off to Copilot | `copilot/lumo-kart-upload-streckenpakete` |
| [#17](https://github.com/Ullmann27/lumo-godot/pull/17) | merged | Lumo Kart Umsetzung: Turbo-Fix, Fold-Pass und Streckenausbau weiterführen | `copilot/lumo-kart-upload-streckenpakete` |
| [#18](https://github.com/Ullmann27/lumo-godot/pull/18) | open | Lumo Kart Stage 2: längere Himmelsinseln, Sternentor, sichere Respawns und Mystery Items | `chatgpt/kart-himmelsinseln-stage2-2026-10-05` |
| [#20](https://github.com/Ullmann27/lumo-godot/pull/20) | merged | Lumo Kart Developer Packs: reproduzierbare ZIPs für 4 Streckenwelten | `chatgpt/kart-developer-packs-zip-2026-10-06` |
| [#21](https://github.com/Ullmann27/lumo-godot/pull/21) | open | Lumo Kart: sichtbare Rivalen-Items und faire Lichtimpuls-Vorwarnung | `chatgpt/kart-rival-feedback-2026-10-07` |
| [#22](https://github.com/Ullmann27/lumo-godot/pull/22) | open | Lumo Kart: Video-Referenzgrade für echte Chase-Kamera und Runtime-Grafik | `chatgpt/kart-video-visual-grade-2026-10-07` |
| [#23](https://github.com/Ullmann27/lumo-godot/pull/23) | open | feat: four creative games, twelve circuits and verified compact Android controls | `chatgpt/lumo-complete-games-2026-10-07` |
| [#24](https://github.com/Ullmann27/lumo-godot/pull/24) | open | Lumo Kart: größere Fold-Steuerung und eigene Action-Buttons | `chatgpt/fold-kart-controls-2026-10-07` |
| [#25](https://github.com/Ullmann27/lumo-godot/pull/25) | open | Lumo Kart: modern garage, app typography and richer racing worlds | `chatgpt/kart-video-quality-2026-10-07` |
| [#26](https://github.com/Ullmann27/lumo-godot/pull/26) | open | Kart: lesbare deaktivierte Aktionen und geprüfte Item-/Fold-Bedienung | `chatgpt/repair-opus-handoff-2026-10-07` |
| [#27](https://github.com/Ullmann27/lumo-godot/pull/27) | open | Lumo Kart: Referenz-Fuchs, Glassteuerung, nähere Rennkamera und Streckendetails | `codex/lumo-reference-design-2026-10-08` |
| [#28](https://github.com/Ullmann27/lumo-godot/pull/28) | open | Keep Kart items, reset physics and Lumo arm contact consistent through the full race | `codex/lumo-race-continuity-2026-10-08` |
| [#29](https://github.com/Ullmann27/lumo-godot/pull/29) | open | Lumo-Identität, Kart-Touch und korrekte native Ergebniszeiten | `codex/lumo-integrated-runtime-2026-10-08` |
| [#30](https://github.com/Ullmann27/lumo-godot/pull/30) | open | Pauseneinstellungen mit Touch scrollen und Lumos Referenzkart verfeinern | `codex/lumo-visual-fidelity-2026-10-08` |
| [#31](https://github.com/Ullmann27/lumo-godot/pull/31) | merged | Integrate14 karts, profile budget and measured physical finish and harbor lighting | `codex/lumo-lap-session-recovery-2026-10-09` |
| [#32](https://github.com/Ullmann27/lumo-godot/pull/32) | merged | Sonnenhafen-Aquarium und Werkstatt-Prüfstand – Claude-Fortsetzung | `codex/lumo-action-workshop-2026-10-09` |
| [#33](https://github.com/Ullmann27/lumo-godot/pull/33) | open | Erste aktive Rennspeicherung und vollständiger Pause-Hintergrund | `codex/lumo-modal-viewport-repair-2026-10-09` |
| [#34](https://github.com/Ullmann27/lumo-godot/pull/34) | open | Fix Cup regression: allow finish coasting, freeze race rewards and standings | `codex/lumo-cup-finish-regression-2026-10-09` |
| [#35](https://github.com/Ullmann27/lumo-godot/pull/35) | open | APK 1909 foundation: save first active second and cover Fold pause viewport | `codex/lumo-1909-snapshot-backdrop-2026-10-09` |
| [#36](https://github.com/Ullmann27/lumo-godot/pull/36) | open | Lumo Kart Einstieg: echte Spielbilder statt Schwarz und blauer Nunito-Header | `codex/lumo-game-entry-brand-2026-10-09` |
| [#37](https://github.com/Ullmann27/lumo-godot/pull/37) | merged | Claudes Kart-Runtime bewahren: blauer Lumo-Kart-Spieleinstieg | `codex/lumo-claude-game-entry-2026-10-09` |
| [#38](https://github.com/Ullmann27/lumo-godot/pull/38) | open | Lumo Kart: realistische Gesichtsvorschau, Studio-Licht und echte 3D-Screenshots | `chatgpt/lumo-face-showroom-2026-10-09` |
| [#39](https://github.com/Ullmann27/lumo-godot/pull/39) | open | Lumo-Fuchs: kleinere echte 3D-Augen und vier Perspektiven zur visuellen Prüfung | `chatgpt/lumo-fox-eye-proportions-2026-10-09` |
| [#40](https://github.com/Ullmann27/lumo-godot/pull/40) | open | Lumo 3D: flachere natürliche Augenhöhlen und weniger hervorstehende Pupillen | `chatgpt/lumo-sculpted-eye-sockets-2026-10-09` |
| [#41](https://github.com/Ullmann27/lumo-godot/pull/41) | open | Lumo Kart: offenes Original-Lächeln und natürlich gestellte 3D-Ohren | `chatgpt/lumo-fox-expressive-face-2026-10-09` |
| [#42](https://github.com/Ullmann27/lumo-godot/pull/42) | open | Lumo: echte Gesichtskorrektur, spielbarer Start und Sonnenhafen-Aquarium | `chatgpt/lumo-character-production-2026-10-09` |
| [#43](https://github.com/Ullmann27/lumo-godot/pull/43) | open | Lumo 1920: zusammenhängende helle Wangen am bestehenden Fahrer | `codex/lumo-face-continuation-2026-10-10` |
| [#44](https://github.com/Ullmann27/lumo-godot/pull/44) | open | Lumo Kart: echtes Premium-Hauptmenü mit drehbarem 3D-Lumo und Referenz-Look | `codex/lumo-kart-premium-menu-2026-10-10` |
| [#45](https://github.com/Ullmann27/lumo-godot/pull/45) | open | Lumo Kart: Referenzmenü vollständig sichtbar und überprüfbar | `codex/lumo-kart-reference-final-2026-10-10` |
| [#46](https://github.com/Ullmann27/lumo-godot/pull/46) | open | Lumo Kart: additive Next-Gen visual layer mit sicheren Android-Fallbacks | `codex/lumo-aaa-safe-visuals-2026-10-10` |
| [#47](https://github.com/Ullmann27/lumo-godot/pull/47) | open | Lumo Kart: Renderer-Lifetime, echte Live-Vergleiche und kompakte Hero-Ansicht | `computer/lumo-kart-aaa-2026-10-10` |
| [#48](https://github.com/Ullmann27/lumo-godot/pull/48) | open | Block eSpeak recordings; replace all 52 Godot letter/word voices with Sulafat | `chatgpt/sulafat-godot-audio-2026-10-10` |
| [#49](https://github.com/Ullmann27/lumo-godot/pull/49) | open | Grafik-Grundgerüst: bestehendes Modell, Blender-Roundtrip und exakte Referenzübergabe | `computer/lumo-visual-foundation-2026-10-10` |
| [#50](https://github.com/Ullmann27/lumo-godot/pull/50) | open | Lumo-Gegenspieler: Originalreferenzen, gemeinsamer Katalog und sichere Integrationsvorbereitung | `computer/lumo-rival-reference-2026-10-10` |
| [#51](https://github.com/Ullmann27/lumo-godot/pull/51) | open | Lumo Animation Phase 1: existing 65-bone character, nine clips and isolated Kart test | `computer/lumo-character-animation-2026-10-10` |
| [#52](https://github.com/Ullmann27/lumo-godot/pull/52) | open | Lumo Kart: existing animated Lumo connected to the production race | `computer/lumo-kart-animation-integration-2026-10-10` |
| [#53](https://github.com/Ullmann27/lumo-godot/pull/53) | open | Lumo Kart: Referenzbuttons, Lumo-Kart-Schriftzug, echte Fold-dp-Größen und animiertes Menü | `computer/lumo-kart-production-menu-2026-10-10` |
| [#54](https://github.com/Ullmann27/lumo-godot/pull/54) | open | Lumo Kart: echter Ladefortschritt, animierter Einstieg und sicherer Menüübergang | `computer/lumo-kart-real-loading-2026-10-11` |
| [#55](https://github.com/Ullmann27/lumo-godot/pull/55) | open | Stage 2: Sky-Fixture-Leck reparieren und grüne Fehlerlogs verhindern | `computer/lumo-kart-stage2-fixture-cleanup-2026-10-11` |
| [#56](https://github.com/Ullmann27/lumo-godot/pull/56) | open | Next Level: randfreies Fold-Menü, echte 3D-Bühne und sichere Kamera | `computer/lumo-next-level-menu-2026-10-11` |
| [#57](https://github.com/Ullmann27/lumo-godot/pull/57) | open | fix(lumo): stabiler Lenkradkontakt beim Nicken mit visuellen Nachweisen | `astra/lumo-animation-quality-2026-10-11` |
| [#58](https://github.com/Ullmann27/lumo-godot/pull/58) | open | fix: Fold-Garage per Touch bedienen und kreative GLB-Objekte integrieren | `sol/lumo-kart-fold-games-2026-10-12` |
| [#59](https://github.com/Ullmann27/lumo-godot/pull/59) | open | 1936 salvage: Sulafat Godot audio | `chatgpt/sulafat-godot-audio-2026-10-10` |
| [#60](https://github.com/Ullmann27/lumo-godot/pull/60) | open | 1936 salvage: expressive Lumo face line | `chatgpt/lumo-fox-expressive-face-2026-10-09` |
| [#61](https://github.com/Ullmann27/lumo-godot/pull/61) | open | 1936 salvage: race finish and snapshot fixes | `codex/lumo-cup-finish-regression-2026-10-09` |
| [#62](https://github.com/Ullmann27/lumo-godot/pull/62) | open | 1936 salvage: visual fidelity and reference kart | `codex/lumo-visual-fidelity-2026-10-08` |
| [#63](https://github.com/Ullmann27/lumo-godot/pull/63) | open | 1936 salvage: creative games touch labels | `chatgpt/lumo-complete-games-2026-10-07` |
| [#64](https://github.com/Ullmann27/lumo-godot/pull/64) | open | 1936 salvage: premium Kart menu branch | `codex/lumo-kart-premium-menu-2026-10-10` |
| [#65](https://github.com/Ullmann27/lumo-godot/pull/65) | open | Kart1937: fehlende Rückwärts- und Zieleinlaufreparaturen integrieren | `sol/lumo-1937-kart-quality-2026-10-12` |
| [#66](https://github.com/Ullmann27/lumo-godot/pull/66) | open | Sonnenhafen: echte Wellenpavillons mit Blender-Quelle, PBR und mobilen LODs | `sol/lumo-harbor-pavilions-1939-2026-10-14` |
| [#67](https://github.com/Ullmann27/lumo-godot/pull/67) | open | feat(kart): premium curved PBR guardrails on the exact Lumo APK source pin | `chatgpt/lumo-railkit-first-track-2026-10-15` |
| [#68](https://github.com/Ullmann27/lumo-godot/pull/68) | open | feat(bauwelt): twelve real modular 3D build objects with native QA | `chatgpt/lumo-bauwelt-12-procedural-assets-2026-10-15` |
| [#69](https://github.com/Ullmann27/lumo-godot/pull/69) | open | feat(integration): premium Kart rails + 12 Bauwelt 3D objects on verified pin | `chatgpt/lumo-kart-bauwelt-integrated-2026-10-15` |
| [#70](https://github.com/Ullmann27/lumo-godot/pull/70) | open | Enlarge real 3D Kart track previews on Fold screens | `chatgpt/lumo-kart-larger-world-preview-2026-10-15` |
| [#71](https://github.com/Ullmann27/lumo-godot/pull/71) | open | Lumo Kart: cinematic environment, adaptive terrain foundation and cruising exhaust | `chatgpt/lumo-gemini-visual-implementation-2026-10-15` |
| [#72](https://github.com/Ullmann27/lumo-godot/pull/72) | open | Lumo Kart: Sonnenhafen water shader polish + real visual QA | `chatgpt/sonnenhafen-water-visual-qa-2026-10-15` |
| [#73](https://github.com/Ullmann27/lumo-godot/pull/73) | open | Godot 4.6.3: retry transient Android logcat timeouts without masking crashes | `chatgpt/kart-android-adb-resilience-2026-10-16` |
| [#74](https://github.com/Ullmann27/lumo-godot/pull/74) | open | Lumo Kart: physically richer asphalt with mobile LOD and six real before/after renders | `chatgpt/kart-asphalt-material-polish-2026-10-16` |
| [#75](https://github.com/Ullmann27/lumo-godot/pull/75) | merged | Integrate current verified Kart graphics and historical Astra/Opus gameplay into main | `chatgpt/kart-asphalt-material-polish-2026-10-16` |
| [#76](https://github.com/Ullmann27/lumo-godot/pull/76) | open | Sonnenhafen: drei neue echte 3D-Aussichtstürme mit Cyan-Licht, GPU-Batching und Low-End-LOD | `chatgpt/sonnenhafen-lookout-3d-landmarks-2026-10-16` |
| [#77](https://github.com/Ullmann27/lumo-godot/pull/77) | open | Lumo Kart 1957: Android muss eine echte gestartete Rennwelt nachweisen | `chatgpt/kart-android-real-race-gate-1957-2026-10-16` |
| [#78](https://github.com/Ullmann27/lumo-godot/pull/78) | open | Sonnenhafen: Containerterminal mit Ship-to-Shore-Portalkran (echte 3D-Geometrie, Vorher/Nachher-Render) | `claude/sonnenhafen-harbor-crane-2026-10-17` |
| [#79](https://github.com/Ullmann27/lumo-godot/pull/79) | merged | Sonnenhafen AAA-Fortsetzung: animierter Container-Hub mit vier mitlaufenden Seilen | `chatgpt/sonnenhafen-animated-crane-hoist-2026-10-17` |
| [#80](https://github.com/Ullmann27/lumo-godot/pull/80) | merged | Lumo Kart Sonnenhafen: echte Kontaktwirkung und Wellblech ohne Gameplay-Eingriff | `chatgpt/sonnenhafen-grounding-corrugation-2026-10-17` |
| [#81](https://github.com/Ullmann27/lumo-godot/pull/81) | open | Bauwelt QA: originale Premiumobjekte in echter Spielszene mit Save/Reload rendern | `chatgpt/lumo-1971-bauwelt-originals-runtime-evidence-2026-10-17` |
| [#82](https://github.com/Ullmann27/lumo-godot/pull/82) | open | QA: verify Argon 4 coordinates against real Lumo 1971 track source | `chatgpt/lumo-argon-coordinate-audit-2026-10-17` |
| [#83](https://github.com/Ullmann27/lumo-godot/pull/83) | open | Experimental: make road projection height-aware for genuine 3D crossings | `chatgpt/lumo-multilevel-road-projection-2026-10-17` |
| [#84](https://github.com/Ullmann27/lumo-godot/pull/84) | open | Milestone A: vertical-frame stability plus real AI, collision and respawn tests | `chatgpt/lumo-milestone-a-drive-guards-2026-10-17` |
| [#86](https://github.com/Ullmann27/lumo-godot/pull/86) | open | Meilenstein B1: Sonnenhafen-Küstenviadukte mit echter 3D-Geometrie und Renderbeweis | `chatgpt/lumo-b-sonnenhafen-viaduct-2026-10-17` |
| [#88](https://github.com/Ullmann27/lumo-godot/pull/88) | open | B2 Experiment: Sonnenhafen 1,85 km – neue 23-Punkte-Strecke mit Godot-Geometriebeweis | `chatgpt/lumo-b2-sonnenhafen-long-course-2026-10-17` |
| [#89](https://github.com/Ullmann27/lumo-godot/pull/89) | open | B3: 5 originale Sonnenhafen-3D-Hero-Landmarken mit echten Godot-Renderbeweisen | `chatgpt/lumo-b3-long-coast-hero-scenes-2026-10-17` |
| [#90](https://github.com/Ullmann27/lumo-godot/pull/90) | open | B4: exact k-d spatial index accelerates 1.85-km terrain and scenery queries | `chatgpt/lumo-b4-road-nearest-kd-2026-10-17` |
| [#91](https://github.com/Ullmann27/lumo-godot/pull/91) | open | B5: Küstenschaum an reale 1,85-km-Sonnenhafen-Inselgrenzen binden | `chatgpt/lumo-b5-true-coastal-foam-2026-10-17` |
| [#92](https://github.com/Ullmann27/lumo-godot/pull/92) | open | B6: remove giant mountains and legacy rocks intruding into 1.85-km Sonnenhafen road | `chatgpt/lumo-b6-clear-sonnenhafen-road-2026-10-17` |
| [#93](https://github.com/Ullmann27/lumo-godot/pull/93) | open | Lumo Kart: Farbkorrektur & überprüfbarer GLB-Gate-Import | `chatgpt/lumo-meshy-start-finish-gate-2026-10-17` |
| [#94](https://github.com/Ullmann27/lumo-godot/pull/94) | open | Lumo Kart: Einfahrtstor bündig im Gelände verankern und Materialschärfe verbessern | `chatgpt/lumo-gate-terrain-flush-detail-2026-10-17` |
| [#95](https://github.com/Ullmann27/lumo-godot/pull/95) | open | Lumo Kart: erste befahrbare Sonnenhafen-Dunkelfahrt mit Neon-Kristalltunnel und echtem Render-QA | `chatgpt/lumo-darkride-first-playable-2026-10-17` |
| [#96](https://github.com/Ullmann27/lumo-godot/pull/96) | open | Lumo Kart: eigenständige 3D-Asset-Fabrik mit strengem JSON-Vertrag, GLB-Export und Vision-Renderbeweisen | `chatgpt/lumo-ai-3d-factory-first-slice-2026-10-17` |
| [#97](https://github.com/Ullmann27/lumo-godot/pull/97) | open | Lumo Kart: rundenabhängiger Neon-Energieschub mit echten GPU-Vorher/Nachher-Bildern | `chatgpt/lumo-darkride-lap-reactive-neon-2026-10-17` |
| [#98](https://github.com/Ullmann27/lumo-godot/pull/98) | open | Lumo Kart: kinderfreundlicher Kristall-Schockwellen-Effekt zur Dunkelfahrt | `chatgpt/lumo-darkride-cartoon-burst-vfx-2026-10-17` |
| [#99](https://github.com/Ullmann27/lumo-godot/pull/99) | open | Mineral cave art pass | `chatgpt/lumo-darkride-mineral-strata-artpass-2026-10-17` |
| [#100](https://github.com/Ullmann27/lumo-godot/pull/100) | open | Lumo Kart: laufende Dunkelfahrt-Effekte bei ruhiger Bewegung und Tunnelverlassen sicher beenden | `chatgpt/lumo-darkride-reduced-motion-state-guard-2026-10-18` |
| [#101](https://github.com/Ullmann27/lumo-godot/pull/101) | open | Lumo 1977: echte Kristallhöhle, mobile 3D-Produktion und kontrollierte Lichtanimation | `codex/lumo-1977-cavern-production-2026-10-18` |
| [#102](https://github.com/Ullmann27/lumo-godot/pull/102) | open | Lumo 1977: reales Zweirundenrennen mit strikter Save/Resume-Toleranz und GPU-Nachweis | `chatgpt/lumo-1977-full-race-resume-precision-2026-10-18` |
| [#103](https://github.com/Ullmann27/lumo-godot/pull/103) | open | Lumo Kart: keine Zufalls-Itemwürfel – echte Resonanzringe für Fahrkönnen und Taktik | `chatgpt/lumo-racing-skill-resonance-gates-2026-10-18` |
| [#104](https://github.com/Ullmann27/lumo-godot/pull/104) | open | Sonnenhafen Cinema-Rock: eigenständiges warm-kühles Toon-Material, echter Godot-Render und Low-End-Schutz | `chatgpt/lumo-sonnenhafen-cinema-rock-material-2026-10-18` |
| [#105](https://github.com/Ullmann27/lumo-godot/pull/105) | open | Lumo Kart: Cinema-Höhle, originale 3D-Mineralien und Hafenveredelung prüfen | `codex/sonnenhafen-tactile-cinema-2026-10-18` |
| [#106](https://github.com/Ullmann27/lumo-godot/pull/106) | open | Lumo Kart: gespeicherte Grafikprofile und Qualitätsprofile nach Szenenwechsel wiederherstellen | `chatgpt/kart-quality-profile-autoload-fix-2026-10-18` |
| [#107](https://github.com/Ullmann27/lumo-godot/pull/107) | open | Kart: räumliche Startampel mit wiederverwendeten Materialien | `codex/kart-start-light-polish-2026-10-19` |
| [#108](https://github.com/Ullmann27/lumo-godot/pull/108) | open | Kart: realen Szenenwechsel und Grafikprofil im Godot-Lauf prüfen | `chatgpt/kart-1986-real-scene-quality-regression-2026-10-19` |
| [#110](https://github.com/Ullmann27/lumo-godot/pull/110) | open | Designvorgabe: Lumo Kart – neues spielbares 3D-Hauptmenü | `design/lumo-kart-ui-brief-20261020` |
| [#111](https://github.com/Ullmann27/lumo-godot/pull/111) | open | Lumo Kart Next Gen: echte Premium-Spieleauswahl, 3D-Fuchs und Garagen-Politur | `design/lumo-kart-premium-ui-implementation-20261020` |
| [#112](https://github.com/Ullmann27/lumo-godot/pull/112) | open | Lumo Kart: Astra/Codex-Wiederaufnahme durch sichere automatische GitHub-Checkpoints | `ops/lumo-kart-cloud-checkpoint-protection-20261020` |
| [#113](https://github.com/Ullmann27/lumo-godot/pull/113) | open | Integrate Astra cinematic Lumo Kart menu into latest verified 3D gameplay | `integration/astra-kart-landing-on-verified-gameplay-20261021` |
| [#114](https://github.com/Ullmann27/lumo-godot/pull/114) | open | SOL-Fortsetzung: echtes Kart-Menü auf Smartphone, Fold und Querformat reparieren | `chatgpt/lumo-sol-portrait-menu-recovery-20261021` |
| [#115](https://github.com/Ullmann27/lumo-godot/pull/115) | open | Sonnenhafen: echter Panorama-Flug über neuer Rampe mit getrenntem Physikprofil | `feat/sonnenhafen-long-flight-20261028` |
| [#116](https://github.com/Ullmann27/lumo-godot/pull/116) | open | Sonnenhafen-Kristallhöhle: echtes Wasser und Fantasy-Lava mit mobilem Shader | `feat/sonnenhafen-water-lava-cave-20261028` |
| [#117](https://github.com/Ullmann27/lumo-godot/pull/117) | open | Integration: Sonnenhafen-Panoramaflug + Wasser/Lava-Kristallhöhle für nächsten Haupt-App-Build | `integration/lumo-kart-2000-sonnenhafen-flight-cave-20261028` |
| [#118](https://github.com/Ullmann27/lumo-godot/pull/118) | open | Sonnenhafen aus Vogelperspektive: echte 3D-Streckenübersicht, Flug und Landung im Godot-Test | `qa/sonnenhafen-2003-aerial-flight-captures-20261029` |
| [#119](https://github.com/Ullmann27/lumo-godot/pull/119) | open | Sonnenhafen 2027: Opus-Looping, Stunt-Schanze und Tunnelportal integrieren | `integration/sonnenhafen-2027-stunts-20261030` |
| [#120](https://github.com/Ullmann27/lumo-godot/pull/120) | open | Sonnenhafen Stunt: echten Resonanz-Regressionfehler diagnostizieren und beheben | `repair/lumo-kart-2027-pickup-continuity-20261030` |
| [#121](https://github.com/Ullmann27/lumo-godot/pull/121) | open | Sonnenhafen: sinnvoller Hauptstrecken-Loop, hochwertige Aero-Schanze und echter Geschwindigkeits-Sprung | `feat/sonnenhafen-physics-ramp-mainline-loop-20261103` |
