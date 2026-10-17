# Lumo Kart – Entwicklungsübergabe 17. Oktober 2026

## Unveränderter Release-Anker
- Flutter / integrierte Lern-App: `0.12.63+1975` – erfolgreich gebaute ARM64-APK (Lumo Lernen Kart). **APK 1975 NICHT überschreiben**, vor neuer Android-Integration eine separat gepinnte und geprüfte Release-Version bauen.
- Vor Arbeitsbeginn geprüfter Godot-Kern: `a17b06c4719cc94c94bdf97afb3b6862cd049323`, Starttor fußbündig im Gelände (Godot PR #94). Alte Lernmodule, Profile, Saves, Voice, Spielmechanik und die 8 Renn-Checkpoints bleiben erhalten.

## Neue Godot-Erweiterungen (drei aufeinander gestapelte, isolierte PRs)

### PR #95 – Sonnenhafen-Dunkelfahrt
- Branch `chatgpt/lumo-darkride-first-playable-2026-10-17`
- 69–80 % der 1.851,68-m-Strecke = rund 203,69 m Dunkeltunnel mit echter Hüllgeometrie, LED-Rippen, Kristall-MultiMeshes und dunklem Boden-Overlay.
- Nur visuell; Fahrbahnberechnung `sample_road()`, Spline, Leitplanken und Kollisionen unverändert.
- Shader hat bereits eine zweite, deutlich besser lesbare kühles-Cyan/Violett-Iteration.
- **Godot 4.6.3 / High & Low LOD + drei 1280×720-Kamerarenders PASS:** [CI #39060860886](https://github.com/Ullmann27/lumo-godot/actions/runs/39060860886). [Echte 3 Bilder](https://github.com/Ullmann27/lumo-godot/actions/runs/39060860886/artifacts/12111835318).
- Einschränkung: atmosphärisch, aber noch keine AAA-Normalmaps, keine echten begehbaren Sicherheits-/Wasserereignisse oder physischer Fold7-FPS-Test.

### PR #96 – kontrollierte 3D-Fabrik
- Branch `chatgpt/lumo-ai-3d-factory-first-slice-2026-10-17`, gestapelt auf #95.
- `tools/ai3d_factory.py`: standardbibliotheksbasierte JSON→echte glTF-2-GLB-Pipeline mit validierten Seeds, Größen, Dreiecklimits, PBR-Material, UVs, Normalen und exakt prüfbaren Binärhashes. KEIN externes KI-Modell wird angebunden, die KI kann später die JSON-Spezifikationen vorschlagen; keine unbewiesenen KI-Generationsclaims.
- Generiertes Original: `sonnenhafen_biolum_cavern_crystals.glb`, **35.328 Byte / 324 Dreiecke / zwei Materialien / SHA-256 b2ca1afb33585486649f4432977c44a49f1c4413976281e9e3b9a2c3d5f35bcb**.
- **8 Unittests / realer Godot 4.6.3 Import / drei echte 1280×720-Renderansichten PASS:** [CI #39061229473](https://github.com/Ullmann27/lumo-godot/actions/runs/39061229473). [GLB, Manifest und Bilder](https://github.com/Ullmann27/lumo-godot/actions/runs/39061229473/artifacts/12111781015).
- Einschränkung: Fabrik-GLB wird bisher als Build-Artefakt erzeugt und ist nicht in APK 1975 oder produktiver Streckenszene eingebettet. Visuelle Qualität derzeit kontrollierter stilisierter Prototyp.

### PR #97 – reaktives Rennereignis
- Branch `chatgpt/lumo-darkride-lap-reactive-neon-2026-10-17`, gestapelt auf #96.
- `kart_darkride_event_director.gd` auf tatsächliche gefahrene Strecke und zweite Runde (warn → 2.4s energy surge → fade). Integration in vorhandenes `kart_island.gd` beim World-Build und im Game-Tick, Material-Uniforms/Neonemission, reduzierte Animation bei `reduced_motion`.
- Keine neue Kollision, kein neues Savegame-Feld, keine Rennphysikänderung; reines visuelles Ereignis.
- **Neon-Event-Regression plus echter rundenabhängiger GPU-Bildvergleich PASS:** [CI #39061641996](https://github.com/Ullmann27/lumo-godot/actions/runs/39061641996). [2 Originalscreenshots](https://github.com/Ullmann27/lumo-godot/actions/runs/39061641996/artifacts/12111561722).
- Stage-2-Gesamt-CI des finalen #97 HEAD kontrollieren, bevor APK-Pinning oder PR-Merge erwogen wird.

### PR #98 – kinderfreundliche 3D-Kristall-Energieexplosion
- Branch `chatgpt/lumo-darkride-cartoon-burst-vfx-2026-10-17`, folgt isoliert auf #97.
- `kart_darkride_cartoon_burst.gd`: drei opake Neon-Torus-Ringe (im Mobile-Low-Detail zwei), mit deterministischer Expansion, reduzierter Bewegung und automatischer Deaktivierung nach 1,5 Sekunden. Die schon existierende Lap-2-Eventsteuerung löst den Effekt genau einmal aus.
- Keine physischen Kollisionen, keine transparenten GPUParticles, keine Savegame-/Checkpointveränderung.
- **Tatsächliche Godot-4.6.3-Regression + echter Renderbild-Pixeldifferenztest: PASS** [CI #39062165270](https://github.com/Ullmann27/lumo-godot/actions/runs/39062165270); [vorher/nachher Bildartefakt](https://github.com/Ullmann27/lumo-godot/actions/runs/39062165270/artifacts/12112021594). Keine reale Fold7-FPS-Prüfung oder neue APK.
- Stage-2-Gesamt-Test auf PR #98 muss vor Android-Pinning abschließend überprüft werden.

## Priorisierte Folgeaufgaben
1. **CI-Freeze:** Für #97 alle einschlägigen Laufresultate prüfen. Fehler anhand Logs reparieren, ohne Tests auszuschalten. Nachweis für alte B3-/B6-Baseline-Workflows separat behandeln; diese konnten vor diesem Auftrag an historischen Checkout-Imports abbrechen.
2. **Art-Pass:** Aus den drei Darkride-Ansichten reale Defizite ableiten, Tunnel-/Felsoberflächen strukturieren, Kristallcluster mehrfach maßstäblich am Streckenrand integrieren; Shader/Farbe vorher/nachher als echte Godot-Bilder vergleichen. Sichtfreiheit, Bodenhaftung, Streckenlänge und 8 Checkpoints müssen unverändert bleiben.
3. **Ereignisse:** Modulare VFX-Emitter (kleine kinderfreundliche Funken/Wasserfontänen) mit eindeutiger Phasenmaschine und Low/High-LOD; keine dynamische gefährliche Geometrie ohne KI-/Spielphysikfreigabe. Für eine bewegte Brücke müssen Ausweichspur und echte Kollisionsprüfungen zuerst existieren.
4. **Generative 3D-Pipeline:** Erst stabilisierte glTF-/Godot-Render-Provenienz, dann Blender-headless optional und Vision-Critic; nur bounded JSON-Parameter erlauben, keine unbeschränkte lokale/Cloud-Codeausführung aus KI-Antworten.
5. **Release:** Nur nach vollständig grünen Quell-/APK-Checks neuen 1976-Kandidaten in `Ullmann27/lumo-lernen` pinnen, wenn gewünscht; die APK 1975 als unveränderte funktionierende Basis erhalten. Messung 60 FPS auf echtem Fold7 bislang OFFEN.

## Anweisungen für autonomes Weiterarbeiten
- Aktuellen GitHub-Head immer live lesen, nicht alten SHA blind überarbeiten.
- Jeden PR auf isoliertem Branch belassen und mit echter Godot-Engine, Screenshot und Regression belegen.
- Keine erfundenen Render-Ergebnisse oder behauptete Android-Geräte-Messungen.
- Bei einem Fehler ausführlichen Original-Log filtern, Ursache minimal beheben, exakt denselben geänderten HEAD testen.

## QA-Freeze und visuelle Weiterentwicklung, 17.10.2026
- GitHub-Live-Heads #95: `605f5b5a784f0af41ab80d6a37997475d0c5acac`; #96: `59b1154e4c9ffa30c4b6c2938e963ddbdd201320`; #97: `b70c623d7dfed57e0ff3fbeb7b5812f8f228292d`; #98: `aff8dd367f271b654d24db28a2a686b9e5acb626`. Workflow-Runs auf den exakten Heads: 16/2/4/2 erfolgreich. #98 Event `39062332478`, Stage-2 `39062332562` jeweils grün.
- #99, Commit `25f5453ffc3b6ba03360345c4b0f561cb57c40e4`: Darkride-QA `39066957827` und Stage-2 `39066957824` grün. Original-Joblogs: Godot 4.6.3, acht unveränderte Checkpoints, null zusätzliche Kollisionen, 5.505 geänderte Rasterproben im Mineral-A/B-Vergleich. Bildartefakt: `12114065879`. Stage-2: 225 StartHero-Checks ohne Fehler.
- Nächster gestapelter Branch: `chatgpt/lumo-darkride-road-guidance-2026-10-17`, auf #99. Visuelles Upgrade: statische cyan-/bernsteinfarbene Schulter-Markierungen auf bestehendem Straßen-Shader, keine zusätzlichen Meshes, keine zeitabhängige Animation, keine Kollisions- oder Physikänderung. Der Godot-Capture soll die echten 1280×720-Bilder `deep_neon_guide_off.png` und `deep_neon_guide_on.png` am selben Kamerastandpunkt erzeugen und die Straßenpixel quantitativ vergleichen. **Dieser neue Head gilt erst nach seinen eigenen grünen CI-Läufen als verifiziert.**
- Releaseanker Flutter `0.12.63+1975`, Lern-App, Kinderprofile, Voice, Savegames, Checkpoints und Rennphysik bleiben unverändert. Kein Fold7-FPS-Nachweis und keine neue APK.
