# Dschungelherz – geprüfte Unterstützungspakete

## Erste Lieferung: Paket D, Version 1.0.0

Dieses Dokument ist der explizite Übergabepunkt zwischen Unterstützungs- und Hauptteam. Es ersetzt keine automatische Kommunikation zwischen Chats.

**Hauptteam-Basis:** `feature/lumo-jungle-emerald-3600-20261115-a298`, gelesen bei `36a2a240d3f21b3943ab123b30408735fb7b9298`.

**Download:** [Dschungelherz_Paket_D_Audio_v1.0.0.zip](https://chatgpt.com/library?file_id=libfile_fde3_f-aead65a54498819193a0df47fe6426d2_6ebd937ff63881919793f20afab4b8a6&account_id=personal)

Der Download gehört zum ChatGPT-Konto des Auftraggebers. Er ist kein öffentlich freigegebener Asset-Host.

- Archiv: 141.628.487 Bytes.
- SHA256: `1af6a299ee5b48308d1f6e11a44e1841618fd0617e0a16e19ed6e96ba4402d6a`.
- Lokaler Quellcommit: `f56066c015db18b9cdd8296d3282ec77b5efd107`.
- Quellzweig: `art/jungle-emerald-support-20261115-1a6e`.
- Der Quellcommit ist derzeit noch nicht auf GitHub gepusht: Der lokale HTTPS-Git-Zugang besitzt keinen Schreiblogin. Ein vollständiges Git-Bundle wird mit der Gesamtübergabe geliefert. Dieser Handoff-Zweig enthält zunächst ausschließlich die Übergabedokumentation.

## Tatsächlicher Audioinhalt

18 originale Audioassets: 3 Musikfassungen, 10 mono Umgebungsloops, 3 einzelne Vogelrufe und 2 Rennsignale. Enthalten sind 18 PCM24-WAV-Master, OGG/WAV-Runtime-Dateien, 3 MIDI-Partituren, 3 JSON-Partituren und die vollständigen lokalen Python-Synthesequellen. Keine fremden Samples, Soundfonts oder Spielmelodien.

Musik: 112 BPM, 4/4, 64 Takte, 44.100 Hz, exakt 6.048.000 Frames / 137,142857142857 Sekunden. Schleife [0, 6.048.000), alle drei Varianten auf derselben Zeitbasis. Umgebungsloops: jeweils 24 Sekunden, mono.

Nach dem Entpacken liegen die Dateien an den dokumentierten Repository-Pfaden:

- Runtime: `assets/kart/jungle_emerald_3600/audio/`
- Master und Partituren: `art/jungle_emerald_3600/audio/`
- Anleitung: `docs/art/jungle_emerald_3600/audio/README.md`
- Prüfungen: `evidence/jungle_emerald_3600/audio/`

Der optionale `jungle_audio_palette.gd` lädt die neuen Dateien ohne Änderungen an bestehenden Kart-Audio-Allowlisten. Die vorhandenen Hauptteam-Dateien `scripts/games/kart_jungle_audio.gd` und `assets/audio/kart/jungle_emerald_3600/` werden von dieser Lieferung nicht überschrieben.

## Nachgewiesene Prüfungen und Grenze

Alle 18 Runtime-Dateien vollständig mit FFmpeg decodiert; Master- und Runtime-Hashes gebunden. Alle 18 in Godot 4.6.3 importiert und per Playback/Mix/Seek geprüft: 13 Schleifen laufen über ihre Grenze, 5 Einzelsignale stoppen. Kein Clipping; exakte Framezahl.

**Subjektives Anhören ist noch offen.** In der Produktionsumgebung war kein Audioausgang verfügbar; der Godot-Test benutzt den Dummy-Audiotreiber. Technische Dekodierung wird ausdrücklich nicht als Hörabnahme ausgegeben.

## Bauwerkabgleich in Arbeit

Die veröffentlichte Mittellinie verwendet 14 m Normalbreite, bis16 m am Tempel und18 m an Start/Ziel. Entsprechend werden vor der Erstübergabe Hafenbogen20 m, Tempeltor18 m und die Brücken16 m lichte Breite erhalten. Fünf Portalvorschläge wurden bereits gegen die echte Kurve vermessen; gerade Brücken mit nur14 m Deklaration benötigen wegen der Krümmung Seitenreserve. Die endgültige Streckenplatzierung, Bankung und Physikkollision bleiben beim Hauptteam.

Pakete A–C und die gemeinsamen Blender-/Godot-Prüfansichten werden hier nach Abschluss ergänzt. Bestehende Strecken und der produktive Main-Branch bleiben unverändert.
