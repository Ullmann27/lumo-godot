# Lumo Kart – reale Referenzassets und visuelle Integration (20. Oktober 2026)

## Tatsächlich im GitHub-Branch vorhanden
Die **neun** WebP-Dateien dieses Ordners sind aus der vom Nutzer gelieferten Lumo-Kart-Sonnenhafen-Bildreferenz (864 × 1536) zugeschnitten, weich an den Rändern maskiert und als von Godot 4.6.3 importierbare Original-Illustrationsschichten committtet. Quellen sind eigene/bereitgestellte Lumo-Designs, keine Mario-Kart-Assets.

- cinematic_hero.webp: Original-Fuchs mit Fliegerbrille, blauem Kart und Szene, dekorativer Bühnenbereich
- kart_logo_art.webp: originale LUMO-KART-Markenillustration
- sunset_world.webp: aus scenery-only Bildausschnitt erweiterter und weichgezeichneter Sonnenhafen-Hintergrund
- grand_prix_art.webp; time_trial_art.webp: obere beiden echten Modus-Illustrationen
- sonnenhafen_art.webp; garage_art.webp; settings_art.webp: untere Illustrationsreihe
- lumo_avatar.webp: Fuchs-Bilddetail, für dynamischen Status/Avatar optional vorbereitet

## Reale Godot-Verwendung
- scripts/games/kart_reference_landing.gd: neun Texturen als einzelne TextureRect-Layer; Schaltflächen als native Godot-Button-Controls, Fokus-/Touchbereiche, dynamischer Sternestand
- scripts/games/kart_island.gd: der tatsächliche Runtime-Einstieg zeigt die Referenz-Startseite oberhalb des vorhandenen fünfstufigen Konfigurators; Modus-/Strecken-/Garage-/Start-Aktionen werden an echte bestehende Methoden weitergeleitet
- scripts/tests/kart_reference_landing_visual.gd und scripts/tests/kart_reference_host_visual.gd: echte Szenen- und Einbindungstests einschließlich Render-Screenshots
- .github/workflows/lumo-nextgen-design-smoke.yml: Godot-Import, konkrete Karten-/Hosttests, Bildnachweise als Workflow-Artefakt

## Fachliche Grenzen
Die Quelldatei ist ein gerendertes Kompositionsbild: Die Zuschnitte enthalten stellenweise Umgebung oder eingebrannte Bildtexte und sind **keine präzisen objektbasierten 3D-Rekonstruktionen**. Native Buttons, Texte und echte Star-/Spielwerte bleiben von Bildern getrennt. Das Godot-Fahrzeugmodell, 3D-Rennstrecken und Rennphysik werden hier nicht durch eine bloße Illustration ersetzt. Eine spätere AAA-3D-Rekonstruktion des Fox/Car/Kulisse darf auf diesen Assets aufbauen.

## Status
Grafikdateien: COMMITTED. Godot-Wiring: COMMITTED. Referenznähe auf physischer Android-Hardware: NICHT BESTÄTIGT. Gegenüber der Originalref als eigenständiges responsive Querformat/Handyformat zu prüfen. Ein erfolgreicher CI-Test ist nicht automatisch ein AAA-Fidelity-Nachweis.
