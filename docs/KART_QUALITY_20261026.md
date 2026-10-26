# Kart-Qualitätsrunde, 26. Oktober 2026

## Gesicherte Basis und Umfang

Arbeitsbranch: `sol/kart-quality-20261026`, Basis `494416b` (Nextgen-Audit).
Er enthält den aktuell verwendeten App-Pin
`4d0fd40fdf188be6ca86057596c7b51f41701fa3` und Landing-Fit `3a31426`.
Der Rival-Branch `66b280a` enthält `6fa6fe6` und stammt ebenfalls von
`3a31426`, enthält aber den Hub-Fix `4d0fd40` nicht. Er wird hier **nicht**
übernommen: diese Abschlussrunde behebt ausschließlich nachgewiesene Fehler.
Godot: `4.6.3.stable.official.7d41c59c4`. Flutter/Pindatei bleiben unberührt.

## Bestandsaufnahme

- Sonnenhafen: prozedurale Küstenstrecke mit Hafen, Aquarium, Pavillons,
  Aussichtstürmen, Viadukt, langer Brücke, Küstenszenen und animiertem Kran.
  Die zentrale Road-Projektion berücksichtigt Y für übereinanderliegende Wege.
  Dekoration wird räumlich in MultiMeshes gebündelt; LOW reduziert Details.
- Kristalltunnel: Teil von Sonnenhafen bei 69–80 % der Runde, kein separates
  Rennen. `kart_sonnenhafen_darkride.gd` erzeugt Schale, Fahrbahnlicht,
  Neonrippen und Kristalle. Der Event-Director steuert die zweite Runde,
  unterdrückt Bewegungen bei reduzierten Animationen und bereinigt Rebinds.
- Figuren/Fahrzeuge: eigene Flotte und Tierfahrer, Lumo-Farben Orange,
  blaue Brille, Navy-Jacke im Kart-System; animierter GLB-Lumo nur am
  tatsächlichen Spielerkart. Garage, Rivalen und Geister haben getrennte
  prozedurale Darstellungen. Distanz-LOD verwendet Hysterese.
- Garage: echtes Premium-Landing mit fünf Setupschritten, Live-Vorschau,
  Tuning, gespeichertem Fortschritt und Einbettung in den Host.
- Items/Effekte: Boost, Schild, Impuls; Gegnerimpuls mit Vorwarnung und
  Ausweich-/Schildfenster. Kameralokale Speed-Streaks deaktivieren sich
  bei reduzierter Bewegung. Tunnel-/Wasser-/Materialshader haben LOW-Pfade.
- Physik: gemeinsamer Antrieb für Rennen/Werkstatt, Leitplankenbegrenzung,
  Driftstufen, Pedale/Rückwärtsfahrt, Sprünge, Checkpoints und Respawn.
  Bestehende Physikregression fährt tatsächlich gegen die Leitplanken.
- Kamera: Chase, geschwindigkeitsabhängiger Abstand/FOV, Neigung,
  Resize-FOV-Kompensation und separate Loop-/Zielkamera. Nachgewiesener
  Ansatzpunkt: lineares `min(1, delta * rate)` springt bei 250 ms komplett
  zum Ziel; Loop-Zweig beachtet `snap` nicht.

Diese Quelleninventur ist keine visuelle Android-Abnahme oder vollständige
Qualitätsfreigabe. Gerätelauf, Fold, Ton und gemessene 60 FPS bleiben offen.

## Kleiner Reparaturplan

1. Neue echte Engine-Regression für Chase-Position/FOV bei 30/60/120 Hz,
   250-ms-Hitch, Nullschritt, reduzierte Bewegung und Loop-`snap` schreiben.
2. RED am unveränderten Basiscode festhalten.
3. Ausschließlich Kameradämpfung zeitunabhängig machen und explizites
   Loop-`snap` beachten; Bildgestaltung, Physik, Gegner und Items erhalten.
4. GREEN sowie vorhandene Physik-, Bridge-, Landing-/Kamera-/Tunnelprüfungen
   ausführen; reale Renderprüfung soweit lokal verfügbar.
5. Ergebnisse/Begrenzungen ergänzen, kleine Commits pushen, Draft-PR und
   genaue SHA-Übergabe liefern. Kein Merge, Release oder Flutter-Pinwechsel.

## Prüfstand

Wird mit tatsächlichen Befunden ergänzt. Erstimport auf Godot 4.6.3: Exit 0,
keine `ERROR:`-/`SCRIPT ERROR`-Meldungen im Importlog.
