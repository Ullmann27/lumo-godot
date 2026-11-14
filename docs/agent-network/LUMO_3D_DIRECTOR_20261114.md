# LUMO 3D Director – Native-Handoff (2026-11-14)

Quellstand bei Erstellung: 993c145304c3e5f8aa947e1c7a949a8ef8685415. Flutter-Koordinator: https://github.com/Ullmann27/lumo-lernen/pull/487 ; Lernstand: https://github.com/Ullmann27/lumo-lernen/pull/484 .

Drei fachlich getrennte Arbeitspakete mit bis zu zwei Unterauftragnehmern je Paket:
1. **Lernwelt**: Gelernte Kompetenz aus Flutter als JSON-serialisierten Aufgabenvertrag empfangen, generisch richtige 3D-Objektaktion darstellen, exakt dieselbe Aufgabe bewerten (nur Flutter ist Bewertungseigentümer), Spielrunde rückführbar.
2. **Figuren/Studio**: Animationen, Kamera, Materialität, Licht, Originalfiguren, GPU-Budget. Render Originalbilder mit SHA auf dem **wirklich integrierten Quellstand**, visuelle Referenz beurteilen.
3. **Spiele**: Lumo Kart/World-Menü, bauliche 3D-Umwelt, echte KI, Bauwirtschaft, Karten-/Rätselspiele. Kinderbedienung unter 48dp nicht akzeptieren.

Harte Gates: alte Spielsaves nicht zerstören, native Projekt/Godot 4.6.3 importiert fehlerfrei, Headless + gerenderte CI, echte Interaktion Touch/Scroll, 48dp, Erklärschritte sichtbar, keine fremde Nintendo-IP, gesicherte PRs statt main, kein autonomes Play-Publishing. Auf echte API-35-/36-/37-Kompatibilität nur dort verweisen, wo Logs das belegen.

3 Leitung + 9 Spezialisten + 18 Implementierer/Reviewer sind eine **begrenzt geplante Organisation**, keine 30 gestarteten Coding-Agents. Aktive Sessions nur mit nachweisbarem Runtime-Start zählen.
