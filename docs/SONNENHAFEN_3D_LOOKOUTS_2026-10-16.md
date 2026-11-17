# Sonnenhafen – eigene 3D-Aussichtstürme, 16. Oktober 2026
Drei echte Godot-3D-Aussichtstürme stehen in Sonnenhafen außerhalb des Rennkorridors.
Alle Säulen, Träger, Beobachtungsplattformen und beleuchteten Ringe sind echte 3D-Geometrie;
geometrische Primitive werden durch die bestehende MultiMesh-GPU-Batch-Pipeline verarbeitet.
Kein Meshy, keine Fremdassets, keine 2D-Emojis. Die niedrige Detailstufe reduziert Partikelringe,
kleine Stege und Lampen, erhält aber die Silhouette. Keine Änderungen an Fahrphysik, Kurven,
Kontrollpunkten, Kameras, Tracklänge, Profilen oder Android-ABI.
Test: scripts/tests/kart_sonnenhafen_lookouts_regression.gd.
Dies ist ein erster neuer Landschafts-Baustein, noch kein kompletter Mario-Kart-Qualitätsnachweis.
