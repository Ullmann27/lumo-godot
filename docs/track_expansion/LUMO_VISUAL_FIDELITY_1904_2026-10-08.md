# Lumo · visuelle Iteration für APK1904

Entwicklungsbranch `codex/lumo-visual-fidelity-2026-10-08`, auf dem vollständig integrierten Godot-Stand `18238d48f96b76c4175b705a9bf05e82e339bdd0`. App-Basis: `3e1d0eb3c08cb2472b12f08eeae11bb663af62c0`. Die PRs 216/29 bleiben die Basis; dieser Branch ersetzt keinen fremden Stand.

## Konkrete Korrekturen

- API 36 von APK1903: Vier dokumentierte Wischgesten über den Ton-Button änderten den Scrollstand nicht. Der native Button blockierte die Ereignisweitergabe. Die Pausenbuttons verwenden jetzt `MOUSE_FILTER_PASS`; der ScrollContainer unterbricht einen Buttondruck bei einer Wischbewegung. Der neue Fenstertest liefert echte Touch-/Drag-Ereignisse, schreibt keinen Scrollstand und prüft unveränderten Ton, echten Scrollfortschritt, weiterhin pausiertes Rennen und einen normalen Gas-Tap.
- Lumo: braune radiale Iris, feinere kurze Fellsträhnen, dunklere Ohrspitzen. Eine gemeinsame orange/weiße Schwanzoberfläche beseitigt die überlappenden Farbschalen. Der Schwanz läuft weiterhin durch die rechte freie Cockpitöffnung. Augen, Ohren, Kopf, Brille und Anzug bleiben echte bewegliche Geometrie.
- Comet: dunklere Lackreflexe/Felgenspeichen, breitere Cyanringe, Cyanfrontleuchten, L auf der Haube, kompakte eingelassene Turboöffnungen, geschütztes Heckaggregat und seitliche Lichtgehäuse. Der hohe separate Heckflügel entfällt beim Referenz-Comet. Andere Flottenmodelle behalten ihre Auspuff-/Flügelvarianten.
- Sonnenhafen: gemeinsame nahtlose Materialkörnung im Küstengelände im hohen Detailmodus. Kein weiterer Geometrie- oder Transparenzpass; der leichte Modus behält seinen bisherigen Materialweg.
- Farbprüfung: Jede gepackte Farbprobe darf nur eine ursprüngliche Probe erfüllen. Doppelte Zählung ähnlicher Irisfarben ist behoben; Farb-/Positions-/Dreieckszahlen und Materialbudget bleiben streng geprüft. Farbige ursprüngliche Meshes haben einen eigenen Vertexfarben-Materialzustand, damit sie nicht mit unbemalten weißen Teilen im unabhängigen Referenzmodell verwechselt werden.

## Lokal tatsächlich geprüft

Godot 4.6.3, echter X11-Fensterbackend, OpenGLCompatibility, Mesa-Software-Renderer. Geometrie-/Farb-/LOD-Test, neun Kartdetaildesigns mit höchstens 61 Oberflächen, 11700 Lenkradkontaktmessungen (größte Abweichung0,2777mm), verbundene Arme/Handschuhe, echter Pausenswipe, Fold-/Pausenlayout, acht Countdown-Pause-Fälle, vier Modellansichten, neun Kamera-/Geschwindigkeitsfälle mit vollständigem Kart und 3 % Rand, Hafen-Geometrie sowie vollständiger nativer Ablauf mit 16 Toren, gespeicherter Fortsetzung, Ergebnis, ACK und genau einer Belohnung bestanden. Eine zuvor aufgezeichnete Drei-Welten-Fahrt benutzte echte GAS-/Analog-/SPEED-Ereignisse; die CI muss diese auf dem finalen Pin wiederholen.

## Noch offen

Die Android-APK1904 muss auf dem exakten neuen Pin gebaut und vollständig auf API 35/36 gespielt werden. Die Fehlbelege von APK1903 bleiben FAIL: API 35 verlor die ADB-Verbindung zwischen zwei Proben; API 36 scheiterte am wirkungslosen Pausenswipe. Die App ergänzt eine eng begrenzte Wiederverbindung ausschließlich für den exakt bereits verifizierten einzelnen Emulator. Dies ersetzt keine Spiel-/Belohnungsprüfung.

Die Figur ist weiter eine prozedural aufgebaute Laufzeitfigur und kein fertiges, referenzidentisches Produktionsmodell. Fellvolumen, Wangenform, Gesamtproportionen, Karosseriefacetten und finale Beleuchtung sind weiter mit den zehn Originalreferenzen abzugleichen. Echte physische Samsung-/Fold-Hinge-Tests und CPU-/GPU-Frametimes wurden nicht ausgeführt; keine 60-FPS-Abnahme behaupten. Kein Merge nach main, kein Release. Weiterarbeit nach dem ersten tatsächlichen roten CI-Schritt; keine Prüfgrenzen lockern und keine Spielstände oder Belohnungen injizieren.
