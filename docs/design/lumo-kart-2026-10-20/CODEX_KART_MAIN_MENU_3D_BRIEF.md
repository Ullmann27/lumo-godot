# LUMO KART – KONKRETER GODOT-4.6.3-GRAFIK- UND MENÜ-UMBAU (20.10.2026)

**Verbindlicher Gesamtauftrag:** https://github.com/Ullmann27/lumo-lernen/blob/design/lumo-nextgen-visual-brief-20261020/docs/design/lumo-nextgen-2026-10-20/CODEX_GRAPHIC_3D_MASTER_BRIEF.md

## Fokus
Ausschließlich **real gerendertes, tatsächlich bedienbares** Lumo-Kart-Hauptmenü und zusammenhängende 3D/2.5D-Präsentation aktualisieren. Existierende Spielphysik, Runden, Strecke Sonnenhafen, Fahrzeugauswahl, Speicherstände, Gegner, Android-Build und Godot/Flutter-Integration nicht umschreiben. Nicht im Hauptbranch direkt arbeiten. Beachte aktuelle offengehaltene PRs; insbesondere #108 ist gegen einen anderen Arbeitszweig gestapelt. Keine unbekannten Änderungen still überschreiben.

## Visuelle Referenz
Bildtitel aus der aktuellen Lumo-Serie: **„Lumo Kart Neon Rennspaß am Sonnenhafen“**. Lumo ist der originale orange-weiße Fuchs mit blauer Fliegerbrille, dunkelblauer cyanleuchtender Jacke und großem Schwanz – **kein Junge**. Er sitzt im bestehenden eigenständigen Lumo-Kart mit dunkelblau/goldener Karosserie und cyanfarbenen Leuchtakzenten. Sonnenhafen als Abendkulisse (Wasser, Brücken, Hafen, warme Lichter, sternige Nacht, Rennstrecke, gezielte Geschwindigkeitslinien) – nur eigene Assets aus dem Projekt. Schwere Grafikeffekte nur im High-Profil.

## Live-Menü-Aufbau – UI echten Controls zuordnen
- Top-Branding: LUMO KART / Statuszeile, live echtes Profil falls Spielintegration so existiert.
- Visuelle Hauptbühne: echter Lumo + eigenes Kart; stabiler Kamerawinkel (nahe 3/4 Vorderansicht), sauber beleuchtetes PBR/Toon-Kartmaterial; keine permanent aktive Fullscreen-Particles.
- Primär: großer goldener „Start“-Button, der an bereits implementierten Quick Start/Lauf führt; falls kein solcher Launcher existiert, sinnvoll auf aktuellen Startfluss routen.
- Sekundär: Grand Prix, Zeitrennen, Sonnenhafen, Garage, Einstellungen. An nur wirklich vorhandene Modi verbinden, fehlende Funktionen verständlich deaktivieren.
- Tertiär: nur existierende Rangliste/Trophäen/Belohnungen/Freunde, keine erfundenen Onlinefunktionen.
- Eindeutige Rück- und Android-Back-Aktion, klare Markierung bei Fokus/Tap, keine overlapping Hitboxes, keine verdeckten Dialoge.
- Landscape zuerst (Handy + Fold), falls echtes Kart-Menü Portrait unterstützt auch das testen, SafeAreas/Insets, 48dp äquivalente Touchziele, Textscale, low motion.
- Szene über Godot Control-Container, Theme, NinePatchRect/StyleBox/TextureRect/Label/Button aufbauen. Bilder sind **dekorative Assets**, niemals baked-in klickbarer Text/Screenshot.

## Technische Arbeitsfolge
1. project.godot, MainScene, real verwendeten Menu-Script, Resource-Pfade, Theme und Kamera feststellen. Bildschirmfoto IST aufnehmen.
2. Verifizierte Originalfigur und Kart-Abmessungen prüfen, vorhandene Textur-/Modell-Assets wiederverwenden.
3. Design-Token-Parität zur Flutter-Lern-App schaffen: Navy, Cyan, Warmgold, Materialroughness, OuterGlow nur bedarfsweise.
4. Reales Menü an der wirklichen Einstiegsszene überarbeiten; jede Aktion verbinden.
5. Hintergrund mit echten/lizenzierten Sonnenhafen-Assets, Low-End-Fallback rendern; Qualität LOW/MED/HIGH testen.
6. Headless Scene-Checks, Godot 4.6.3 Projektstart, GUI-/Input-Checks, dokumentierte Screenshots (vorher/nachher), Speicher-/Framezeitmessungen soweit möglich.
7. Alle Patches/Assets auf GitHub-Arbeitszweig committen, Draft-PR eröffnen, niemals main force-pushen.
8. Anschließend **optional** 5s-Intro: Lumo-Kart fliegt von links nach rechts (oder umgekehrt) durch Szene, Sterne ziehen nach, LUMO KART Logo erscheint, freundliches „Lernen mit Spaß!“ nur mit tatsächlich verfügbarer freigegebener Audioressource, sonst stumme Titelanimation. Tap-to-skip, reduced motion, Übergang ohne schwarzen Frame ins Menü, effiziente Tween/AnimationPlayer-Implementierung. Keine Pflicht, wenn Menüqualität/Tests dadurch leiden.

## WICHTIGE STOPPREGELN
- Niemals das ursprüngliche brand-true Fuchsmodell durch einen anderen generierten Charakter ersetzen.
- Kein Mario-/Nintendo-IP, keine Darstellung eines nicht vorhandenen Online-Modus.
- Kein neuer Motor, kein Gameplay-Scope-Creep, kein blindes Godot/Flutter-Pin-Update.
- Ständige Sicherung: docs/design/lumo-kart-2026-10-20/STATUS.md + CONTINUE.md, pro Paket committen, exakte Branch/HEAD/Tests/Screens nennen.
- „100% fertig“ nur nach echtem Godot-Menü-Screenshot, funktionsfähiger Menüführung und dokumentiertem Build/QA.

## Akzeptanz
Echte Godot-Menüszene zeigt den richtigen Fuchs mit Kart in der eigenen Sonnenhafen-Ästhetik, große lesbare Tasten mit realer Funktion, Responsive Landscape, Low-End-Fallback, nachweisbare Performance/Tests, Stand auf GitHub, weiterführbarer Branch/PR. Der Stil muss erkennbar zur bestehenden Lumo-Lern-App gehören, und der Weg aus Flutter in Kart darf nicht brechen.