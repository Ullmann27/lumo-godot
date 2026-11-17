# Lumo 1957 — Meshy-Assetproduktion mit begrenztem Credit-Budget

Stand: 16. Oktober 2026. **Produktionsbrief, keine Behauptung, dass Credits ausgegeben oder neue Assets generiert wurden.**

## Vorhandene, nicht zu ersetzende Arbeit

- Das Godot-Projekt enthält bereits `assets/characters/lumo_animated/Lumo-Animated-Mobile.glb`, einen animierten, auf mobile Geräte optimierten **Lumo aus Meshy**. Laut `ATTRIBUTION.md`: 65 Knochen, neun animierte Clips, ca. 30.000 Dreiecke und 1024-Pixel-Texturen, CC BY 4.0. Der aktuelle Rig hat **keine Gesichts-Morphs, Mund-Viseme oder echte Lippensynchronität**.
- `scripts/characters/lumo/lumo_rigged_actor.gd` bindet das importierte GLB ein, stellt die neun Clips bereit und nimmt eine reale Audio-Hüllkurve entgegen. Eine Audio-Hüllkurve allein ist noch keine sichtbare Lippenbewegung.
- Verbindliche Bildreferenzen: `assets/characters/lumo/reference/01_master_character_sheet.png` und `02_orthographic_model_sheet.png`. Für Fahrzeuggestaltung zusätzlich die Lern-App-Dateien `assets/lumo_design/characters/kart_side.webp` und `assets/lumo_design/fox/fox_kart_wave.png`.
- **Kein neuer generischer Fuchs:** Neue Meshy-Arbeiten müssen der bestehenden Lumo-Gestaltung und dem vorhandenen Charakter entsprechen.

## Entscheidung bei angegebenen 300 Meshy-Credits (Kontostand nicht unabhängig geprüft)

**Zuerst Lumo Kart, dann das kurze Intro; keine redundante Neu-Generierung der Lumo-Hauptfigur.**

1. **Markantes Original-Lumo-Kart mit klaren Vorder-, Seiten- und Rückansichten**, gebackenem PBR-Look, getrennten Radbaugruppen und konsistenter Fahrer-Sitzgeometrie. Bevorzugt Image-to-3D anhand der vorhandenen Referenz, zunächst ein günstiger Prototyp.
2. **Sonnenhafen Startbogen plus charakteristische Streckenobjekte** für deutlich sichtbar veränderte Fahrumgebung: modernes Tor, thematischer Leuchtturm und sichere Begrenzungs-/Boost-Props. Nur geometrisch unabhängige Modelle; nicht ganze Rennstrecken als ein einziges Mesh generieren.
3. **Bewegter Lumo in der Lern-App** mit bereits bestehendem Rig, Idle/Winken/Jubeln. Für sichtbares Sprechen zuerst nachvollziehbare Mund-/Visem-Geometrie in Blender/Godot und eine tatsächlich synchronisierte Tonspur entwickeln; Meshy-Rigging allein erfüllt diese Anforderung nicht.
4. Ein 15–30-Sekunden-Erklärvideo erst produzieren, wenn die nutzbaren Animationen, reale Stimme, deutschsprachiges Skript und Lizenzlage geklärt sind. Film und Lip-Sync sind eigenständige Produktionsschritte.

## Credit- und Download-Grenzen — vor Start in der Web-App bestätigen

Quelle Meshy-Hilfe (Stand Oktober 2026):
- <https://help.meshy.ai/en/articles/10000507-how-many-credits-does-each-generation-task-cost> nennt **10 Credits für Meshy 6 Lite** Modellphase, **10 Credits für 2K/4K-Texturierung**, **0 Credits für Smart-Rig**, **20–330+ Credits für generierte Videos**. Die Preise beim konkreten Startknopf gelten.
- <https://help.meshy.ai/en/articles/15696428-what-is-included-on-the-free-plan> beschreibt aktuell **maximal 10 Downloads/Monat im Free-Plan, nur für Meshy-6-Lite-generierte Modelle**. Meshy 6 und Meshy 7 sind ohne Abo normalerweise **nicht exportierbar**, selbst wenn die Generierung mit Credits möglich ist.
- Kostenlose Assets unterliegen Meshys **CC BY 4.0** mit Namensnennung; die für das Projekt notwendige Attribution erhalten. Ein Credit-Paket ist **kein** Abonnement und hebt Downloadbeschränkungen nicht automatisch auf.
- Die behaupteten 300 Credits im Konto **müssen vor jeglicher Produktion visuell verifiziert** werden; keine automatischen Credit-Ausgaben ohne sichtbare Modell-, Kosten- und Lizenzkontrolle.
- Empfohlener Einstieg: eine einzige **Meshy-6-Lite**-Probe (10 + optional 10 Textur-Credits), **Download als GLB testen**, resultierende Geometrie in Godot 4.6.3 laden und auf echtem Android prüfen. Nur danach Credits auf weitere Assets verteilen.

## Formatrecht / Integration / Abnahme

- GLB/glTF 2.0 bevorzugen; maßstabsrichtige Achsen, separierbare Räder, niedrige Draw-Calls, saubere UV, keine eingebrannten Fremdlogos.
- Meshes mit mehreren LODs und komprimierten Texturen; Low-End-Geräte dürfen keine optisch schlechtere, unspielbare Version erhalten. GPU/FPS am Zielgerät messen, nicht 60 FPS behaupten.
- 3D-Projektelemente in einer separaten Szene importieren, Rückfall auf das bestehende Asset belassen; **keine** Trainer-, Journal- oder Kart-Gameplay-Funktionen entfernen.
- Vor Freigabe: Originalgrafik wiedererkennbar, GLB + Texturen in Godot importiert, Android-APK startet, **echtes Rennbild statt Garage**, und die Lizenzhinweise liegen bei.
- Nach erfolgreichem Test nur den getesteten, exakt gepinnten Godot-Commit in Lumo Lernen aufnehmen.

## Zugriff

Das vorhandene externe Browserprofil `Lumo – Meshy.ai 3D-Produktion` enthält nach aktuellem Browserstatus eine gespeicherte **Google-Anmeldung**, jedoch **keinen bestätigten Meshy-Login**. Ein separates Browser-Automatisierungs-Kontingent ist aktuell ausgeschöpft. Das ist **nicht** der Meshy-Creditstand. Für tatsächliche Kontointeraktion den Nutzer per gesicherter Profil-Einrichtung anmelden lassen oder die Cloud-Browser-Funktion von ChatGPT Work verwenden; keine Credentials im Chat sammeln.
