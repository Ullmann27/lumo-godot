# Fold-Garage und echte kreative GLB-Objekte

Basis PR57 /853175c6. Auswahlbuttons leiten echte Touch-Drags an den ScrollContainer weiter; Scrollbeginn bricht eine Auswahl ab. Kartspalten richten sich nach der verfügbaren dp-Breite. Titel/gesperrte Hinweise können keine benachbarten Karten verdecken.

Lokaler echter Godot4.6.3/Compatibility-GL-Window-Lauf:96 erfolgreiche Prüfungen über dieselbe laufende Garage bei904x2316/2.5,2176x1812/2.25,2316x904/2.5 und1812x2176/2.25. Tatsächliche InputEventScreenTouch/Drag, Fahrerwechsel, Kart-/Welt-Scroll und selektierte neue Karten; keine direkten Scroll-Offsets. Der gesicherte Vorher-Lauf scheiterte mit scroll0. Reale weitere kurze Drags holen nach einem Zwischenzeilen-Stopp eine vollständig sichtbare Karte; die Assertions bleiben vollständig.

Blender4.3 erzeugt editierbare Laterne/Truhe, echte UVs, lokale Holztextur und drei PBR-Materialien jeGLB. Die Modelle sind mit952 beziehungsweise2376 Dreiecken begrenzt, zu je einerMesh-Instanz zusammengefasst und in Bauwelt/Schatzsuche tatsächlich eingebunden. Lampen-Bauteil-ID, Grundfläche, Position und0.5x2x0.5-Collider bleiben erhalten; der GLB-/Bauteil-Save-Test und vier Szenen-Smoketests bestehen. Keine Meshy-Zahlung, neueProviderjobs oder fremdeAssets. Lumo, Animationen und Lizenzen aus PR57 bleiben erhalten.

Bilder zeigen echte Godot-GL-Runtimeaufnahmen; die Schatzplatz-Kamera nutzt eine isolierte Standortfixture, keinen behaupteten vollständigen Spielabschluss. Nicht physischerFold, nicht gemesseneAndroidFPS. Separate CI prüft die vorhandenen realen Spielzustands-/Save- und Menüabläufe. Die spätere Flutter-APK muss diese exakte neueGodotRevision verwenden.
