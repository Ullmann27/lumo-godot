# Kart 1937: gezielte Übernahme fehlender Reparaturen

Basis: `82b53fc02b9f2ad7e025433499c4c23f256fe734` (1936 verwendet weiterhin diesen Pin).

Übernommen, ohne alte Zweige zu mergen:
- `chatgpt/kart-brake-reverse-2026-10-07`, ursprüngliche Implementierung `d6ee23d`/`93f15fb`: Auto-Gas darf bewusstes Rückwärtsfahren nach dem Anhalten nicht blockieren. Die aktuelle Powertrain-, Strecken-, Rampen-, Profil- und Rig-Architektur bleibt erhalten. Explizites Gas verhindert versehentlichen Rückwärtsgang. Zwei getrennte emissive Bremslampen bleiben aus statischen/LOD-Batches heraus; keine neuen Lichtquellen, Effekte oder Materialallokationen je Frame.
- `codex/lumo-cup-finish-regression-2026-10-09`, `3f9ff57`: tatsächlichen Impuls und Rampen-/Bank-/Schienenkontakt beim Ausrollen erhalten, Zieleinlaufkamera vor sichtbaren Hindernissen halten, ruhige Bewegung ohne Kameraorbit. Ergebnis und Belohnung bleiben eingefroren.
- Ursprüngliche numerische Fixtures und echte Mehrfinger-Bremstaps mitgenommen.

Nachweise lokal: Bremsregression scheitert vor der Reparatur an Rückwärtsfahren mit Auto-Gas; nachher PASS. Originale 16 Zieleinlaufkontrollen: vorher 12 Fehler, nachher 0. Geometrie-/Farb-/Animations-/LOD-Vertrag und echte gleichzeitige Lenk-/Bremstaps bestehen. Fold-Garage muss mit echtem GL-Fenster geprüft werden; ein Headless-Lauf ohne Rendering ist kein Screenshot-/Scrollnachweis.

Diese lokalen Prüfungen sind kein APK- oder physischer Fold-Nachweis. Neue Android-1937-Abnahme und commitgebundene APK-/Screenshot-Provenienz folgen separat. Keine öffentliche Veröffentlichung.

## Aktueller Rig-/Zieleinlauf-Prüfaufbau

Stage2 zeigte mit der neuen Impuls-erhaltenden Zieleinlaufphysik einen inkonsistenten bisherigen Fixture: `speed=12` bei weiterhin `physical_velocity=0`. Das entspricht keiner laufenden Fahrt. Der Fixture setzt nun beide Größen konsistent. Keine Assertion oder Handabstandsgrenze wurde gelockert, kein Animationscode geändert. Echte Player-Factory-Prüfung nachher2069 Kontrollen/0 Fehler, maximaler Handabstand1,137mm. Der ursprüngliche Fehlbericht bleibt erhalten; der abgebrochene erste Flutter-Build hat keine fertige APK geliefert.
