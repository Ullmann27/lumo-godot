# LUMO KART – Referenznahes Designpaket, Fortsetzung

Stand: 20. Oktober 2026. Branch: design/lumo-kart-premium-ui-implementation-20261020. Draft PR: https://github.com/Ullmann27/lumo-godot/pull/111

## Verbindlicher Befund
Die real gerenderten Godot-Screenshots sind weiterhin NICHT ähnlich genug zur freigegebenen hochformatigen Lumo-Kart-Sonnenhafen-Referenz. Das bisherige Menü ist ein fünfstufiger technischer Konfigurator. Weitere Farben und Schlagschatten allein lösen das Problem nicht.

## In ChatGPT tatsächlich erzeugte weiterverwendbare Dateien
- LUMO_KART_REFERENZNAHE_GRAFIK_VORARBEIT.zip: Originalreferenz (941x1672), bedienbare HTML-Stilprobe, 9 aus Originalreferenz zugeschnittene WebP-Bilder, Origin-/SHA256-Manifest und Anleitungen.
- Neu darin: assets/cinematic_hero.webp, sunset_world.webp, kart_logo_art.webp, grand_prix_art.webp, time_trial_art.webp, sonnenhafen_art.webp, garage_art.webp, settings_art.webp, lumo_avatar.webp.
- Die einzelnen PNG/WebP-Originalbytes liegen noch **NICHT in diesem GitHub-Branch**. Sie müssen aus dem Chat-ZIP tatsächlich übernommen und nach Asset-Policy versioniert werden. Diese Erklärung nicht mit einem erfolgreichen GitHub-Upload verwechseln.
- Die HTML-Probe kann lokal geöffnet werden. Buttons wählen dort Zustände; ein tatsächlicher Godot-Start ist noch nicht verbunden.

## Nächste echte technische Umsetzung
1. Bildpaket aus Chat-ZIP nach geprüfter Herkunft in assets/kart/landing/ importieren. Bildzitate bleiben in docs; die Grafiken dienen dem dekorativen Bühnenbereich, NICHT als gesamte klickbare Oberfläche oder hartcodierte Sterne/Werte.
2. Eigene Intro-/Start-CanvasLayer am tatsächlichen Godot-Kart-Einstieg erstellen. Das große grafische Lumo-Kart-Motiv und Sonnenhafen soll sichtbar sein, bevor die schon vorhandene 5-Schritt-Garage erreicht wird.
3. Native Touch-/Focus-gerechte Controls für die Kart-Routen: Grand Prix/Sternen-Cup -> vorhandener Setup-/Cup-Modus, Zeitrennen -> vorhandener Time-Trial, Sonnenhafen -> existierende Streckenauswahl, Garage -> bestehende Garage; Einstellungen nur zu real implementierter Seite. Niemals noch fehlende Online-/Freundesfunktionen vortäuschen.
4. Immer auf dieselbe originale animierte Fuchs-/Kart-Szene mit blauem Fliegerbrillenmodell achten, nicht ein Kind oder einen anderen Cartoonfuchs verwenden. Das hochauflösende Reference-Hero kann als dekorative Kunstfigur dienen, solange das Menü keine echte 3D-Funktion vortäuscht.
5. Responsive Portrait/Landscape/Fold, 48dp-Touchflächen, Texte dynamisch. Render- und CI-Screenshots der neuen Landing unbedingt gegen Originalvorlage vergleichen; erst nach wirklichem visuellen Review Erfolg melden.
6. Nach jedem Arbeitsschritt committen, Screenshot-Artefakte und QA-Status abspeichern. Main nicht überschreiben.

## Bisher tatsächlich getesteter Bestand
GDScript-Garagen-Politur und Godot-Startbild-Aufnahmen wurden im GitHub-Workflow 'Lumo Next Gen visual smoke and real Kart screenshots' erfolgreich ausgeführt, vor dieser Asset-Landing-Erweiterung. Erfolgreiche CI ist KEIN Beweis für Referenzähnlichkeit. Keine behauptete App-/APK-Auslieferung.
