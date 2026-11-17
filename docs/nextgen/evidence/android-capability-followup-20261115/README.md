# Tatsächlich geroutete Stop-Aufrufe

Die Basiskorrektur `f521fc5887e98562ba89fbfeca3bb466031fdea0` erreicht die registrierten Android-Methoden über deren tatsächliche Capability-Auskunft. Der folgende gezielte Review fand zwei verbliebene direkte `has_method`-Guards in der von `scenes/learning/learning_world.tscn` tatsächlich verwendeten Unterklasse.

Producer `3bb511e5e7d87130a1efa4c4cf5eb6930e518db4` korrigiert ausschließlich diese beiden Aufrufe. Die erweiterte vorhandene Regression instanziiert die wirkliche PackedScene ohne Rendering/_ready, führt `segment_replaced` und `bind_interaction_context` aus und prüft partiellen JNI-Host, normale vorhandene Stopmethoden, fehlende Capability und Reentranz. Vorher scheiterten genau zwei der 43 Prüfungen; danach bestehen 43/43. Keine tatsächlich unbekannte Java-Methode wird geraten oder aufgerufen.

Originale RED-/GREEN-/Stylelogs und ihre Hashes liegen bei. Sie belegen den gerouteten Quellpfad und seine Abbruchregeln, keine Android-Audiowiedergabe, Grafikleistung oder APK-Freigabe. Der vollständige neue Androidbuild prüft den endgültigen nativen Pin erneut.
