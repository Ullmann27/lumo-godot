# Dschungelherz – Unterstützungspakete A–D

## Tatsächlicher Lieferstand

**81 3D-Assetkennungen, 206 GLB-Dateien, 41 bearbeitbare Blender-Dateien und 18 Audio-Assets sind produziert und technisch geprüft.** Genau drei Produktionsagents bearbeiteten Vegetation, Bauwerke/Landschaft und Audio; der Koordinator prüfte die gemeinsame Lieferung unabhängig.

**Technische Paketprüfung bestanden. Künstlerische Endabnahme, subjektive Hörabnahme und Android-Zielgeräteabnahme sind offen.** Die Modelle sind sichtbar stilisierter und einfacher als die vorgegebene Referenz. Eine fertig integrierte Rennstrecke oder ein erreichtes AAA-Niveau wird nicht behauptet.

Geprüfter Hauptteamzweig: `feature/lumo-jungle-emerald-3600-20261115-a298`, zuletzt erneut bestätigt bei `36a2a240d3f21b3943ab123b30408735fb7b9298`. Die tatsächliche Kursquelle wurde gelesen und in Godot vermessen. Fahrphysik, Mittellinie, Checkpoints, bestehende Strecken und globales App-Projekt bleiben unverändert.

Dieser PR ist der ausdrücklich angelegte gemeinsame Übergabepunkt. Er enthält **Übergabedokumentation**, die Binärdateien stehen in den folgenden Archiven und im Git-Bundle. Die Downloads gehören zum ChatGPT-Konto des Auftraggebers; sie sind kein öffentlicher Asset-Host.

## Downloads

| Lieferung | Datei | Größe, dezimal |
|---|---|---:|
| A | [Dschungelherz_Paket_A_Vegetation_v1.0.0.zip](https://chatgpt.com/library?file_id=libfile_fde3_f-740d90fd699081919fb4fdf955848c3f_6ebd937ff63881919793f20afab4b8a6&account_id=personal) | 92.37 MB |
| B | [Dschungelherz_Paket_B_Wasserfall_Grotte_Bruecken_v1.0.1.zip](https://chatgpt.com/library?file_id=libfile_fde3_f-9f0090447ef48191a61ba587554ed785_6ebd937ff63881919793f20afab4b8a6&account_id=personal) | 43.52 MB |
| C | [Dschungelherz_Paket_C_Tempel_Hafen_Landschaft_v1.0.1.zip](https://chatgpt.com/library?file_id=libfile_fde3_f-38648f5bdf6081919e6996d45f464b5e_6ebd937ff63881919793f20afab4b8a6&account_id=personal) | 57.69 MB |
| D | [Dschungelherz_Paket_D_Audio_v1.0.0.zip](https://chatgpt.com/library?file_id=libfile_fde3_f-aead65a54498819193a0df47fe6426d2_6ebd937ff63881919793f20afab4b8a6&account_id=personal) | 141.63 MB |
| REVIEW | [Dschungelherz_Godot_Pruefszene_und_Belege_v1.0.1.zip](https://chatgpt.com/library?file_id=libfile_fde3_f-ff1bc53088348191a53cab214701af8f_6ebd937ff63881919793f20afab4b8a6&account_id=personal) | 168.70 MB |
| Git-Bundle | [Dschungelherz_Quellzweig_420ef173.bundle](https://chatgpt.com/library?file_id=libfile_fde3_f-6f4bcb81811c819195dc602249050f24_6ebd937ff63881919793f20afab4b8a6&account_id=personal) | 322.12 MB |

[Ausführliche Übergabe mit Pfaden, Maßen, Materialien und Integrationsanleitung](https://chatgpt.com/library?file_id=libfile_fde3_f-e7c09fed6478819192b1c4f4fd9eee1d_6ebd937ff63881919793f20afab4b8a6&account_id=personal) · [Godot-Windvorschau, 3 s](https://chatgpt.com/library?file_id=libfile_fde3_f-6f7810d43b408191a6c416e09665a7a7_6ebd937ff63881919793f20afab4b8a6&account_id=personal) · [Musikprobe, rund 26 s](https://chatgpt.com/library?file_id=libfile_fde3_f-db3fe11e0d788191be40ed6df1380551_6ebd937ff63881919793f20afab4b8a6&account_id=personal)

### SHA256 der tatsächlichen Dateien

- **A:** `33ce8408c4de4044a36e4cb8b34c64636710f02694dfbb03997dcae0a24303d0`
- **B:** `317bf23f7d50404404cf35759fd1c8ad385ccb95e13858532a74f4b4e886b683`
- **C:** `36c20ea8c5652bbe74d1e6ae542d4128f8e7d7005957b24eb5484969eaae81df`
- **D:** `1af6a299ee5b48308d1f6e11a44e1841618fd0617e0a16e19ed6e96ba4402d6a`
- **REVIEW:** `79c001c7a3a0b31befbf68e9feb5bfe6a697e59d52d09ee3a2c12c2bfd9bb5f5`
- **Git-Bundle:** `8a27858190e4ea6363fccdcd89c2cfa3ac1bbaafec1d7d481936ce29620279cc`

Die ZIPs wurden vollständig geprüft. Alle relativen Bildreferenzen sind im jeweiligen Paket enthalten; gemeinsame Runtime-Dateien der Pakete sind bytegleich. Das Git-Bundle besteht `git bundle verify`. Die Prüfszene wurde zusätzlich **frisch aus dem fertigen ZIP entpackt**, ohne vorhandenen Importcache in Godot importiert und mit 206 Modellen / 0 Fehlern instanziiert.

## Konkrete Commit-Stände

| Bestandteil | Commit |
|---|---|
| Ausgangscommit | `d38967f6d39bc20188afe525b0af122d80634029` |
| Früher Textur-/Quellcheckpoint | `dc7bd75b6539038cead79869458b5cbe58397d2b` |
| Paket D | `f56066c015db18b9cdd8296d3282ec77b5efd107` |
| Paket A | `ea40bfdf01a7a4ac0d839d90d7038456f502cf26` |
| Pakete B und C | `8ced603106186cad47cb258455c47ea49038e6ba` |
| Gemeinsame Godot-Abnahme, Register und Übergabe | `420ef173392ff891dc8b6d52834cf80f7c433fab` |

Quellzweig: `art/jungle-emerald-support-20261115-1a6e`.

Der lokale HTTPS-Git-Zugang besitzt keinen Schreiblogin. Deshalb wurde der Produktionszweig **nicht als erfolgreich gepusht gemeldet**; das verifizierte Git-Bundle überträgt seine exakten Commits. Es enthält ausschließlich die neue Commitfolge oberhalb des Ausgangscommits und benötigt diesen als Voraussetzung.

Nach Download des Bundles in den aktuellen Repositoryordner:

```bash
git fetch origin d38967f6d39bc20188afe525b0af122d80634029
git bundle verify ./Dschungelherz_Quellzweig_420ef173.bundle
git fetch ./Dschungelherz_Quellzweig_420ef173.bundle refs/heads/art/jungle-emerald-support-20261115-1a6e:refs/remotes/jungle-support/emerald-assets
git worktree add ../lumo-jungle-assets-review --detach refs/remotes/jungle-support/emerald-assets
```

Diese Befehle erzeugen einen getrennten Prüfcheckout. Es erfolgt kein Merge nach Main. Alternativ lassen sich die Paket-ZIPs unter Beibehaltung ihrer Pfade in einen eigenen Arbeitszweig entpacken.

## Paketinhalt

**A:** Zwei Hero-Bäume, fünf Waldbaumformen mit je drei Varianten, drei Palmenformen, zwei Bambusgruppen, 16 Unterwuchs-/Blütenobjekte und sechs Wurzel-/Lianenbauteile. Alle 44 Assets haben drei LODs. Vier Blenderdateien enthalten die 44 getrennten editierbaren SOURCE-Collections. Originale PBR-Texturen und ein optionaler Windshader sind enthalten.

**B:** Felsmassiv mit Durchfahrt, separat bearbeitbare Wasserfallflächen, Grotteneingang/-ausgang, kombinierbare Innenwände und Wurzelelemente, Bachrand, Minerale, Wegleuchte, Kronenbrücke, Anker und Übergang: 12 Kennungen, 24 GLBs, 12 Blenderdateien.

**C:** Tempeltor, zwei kleinere Bögen, Säule, Mauer, Treppe, Brunnen, Blatt-/Fuchsreliefs, Steinbrücke und Pfeiler, Flusssteine/Ufer/Terrasse/Kaskade sowie Hafenbogen, Steg, zwei Hüttenformen, Fahne, Korb, Kiste und Laterne: 25 Kennungen, 50 GLBs, 25 Blenderdateien.

**D:** Drei zusammengehörige Originalmusikfassungen, zehn Monoatmosphären, drei einzelne Vogelrufe und zwei Rennsignale. 18 PCM24-WAV-Master, Ogg/WAV-Runtime-Dateien, drei MIDI- und drei JSON-Partituren sowie vollständiger Python-Synthese-/Arrangementcode. Keine fremden Samples oder bekannte Spielmusik; Naturatmosphären sind Synthese, keine Feldaufnahmen.

Musik: **112 BPM, 4/4, 64 Takte, 44.100 Hz, 6.048.000 Frames / 137,142857 s**. Alle drei fertigen Mischungen verwenden dasselbe Zeitraster und Loopintervall **[0, 6.048.000)**. Die zehn Atmosphären dauern je 24 s. Die Dateien sind technisch geprüft, **nicht subjektiv hörabgenommen**.

## Pfade und Materialpipeline

- Runtime: `assets/kart/jungle_emerald_3600/{vegetation,structures,audio}/`
- Blender: `art/jungle_emerald_3600/blender/{vegetation,structures}/`
- Audiomaster/Partituren: `art/jungle_emerald_3600/audio/`
- Register aller Maße, LODs, Material-/Texturinformationen und Hashes: `docs/art/jungle_emerald_3600/ASSET_REGISTER.json` und `.csv`
- Paketumfang: `PACKAGE_A_MANIFEST.json`, `PACKAGE_B_MANIFEST.json`, `PACKAGE_C_MANIFEST.json` im selben Dokumentationsordner.
- Gemeinsame Abnahme: `evidence/jungle_emerald_3600/review/technical_gate.json`
- Sichtbefunde: `evidence/jungle_emerald_3600/review/coordinator_visual_review.json`
- Vollständige Anleitung: `docs/art/jungle_emerald_3600/HANDOFF.md`

**Relative `textures/gltf/`-Ordner zusammen mit den GLBs übernehmen.** B und C enthalten dieselben gemeinsamen Texturen. Ihr `structures/manifest.json` beschreibt den gesamten Katalog; das eindeutige jeweilige PACKAGE-Manifest beschreibt den tatsächlichen Archivinhalt. Gemeinsame Dateien sind bytegleich.

Blender 4.3.2, Godot 4.6.3; 1 Einheit = 1 m. Blender +Z oben / +Y vorwärts wird zu Godot +Y oben / −Z vorwärts. Keine zusätzliche Skalierung. Originale Albedo-, Normal- und Roughnesskarten übertragen die Materialwirkung; nicht exportierbare prozedurale Blenderaufbauten werden nicht als Engine-Shader ausgegeben.

## Verbindliche Bauwerksmaße, Version 1.0.1

Die veröffentlichte Hauptteamstrecke hat 14 m Normalbreite, bis 16 m am Fluss/Tempel und bis 18 m an Start/Ziel. Vor dieser finalen Übergabe wurden die betroffenen Bauwerke entsprechend verbreitert:

| Element | Freier Raum / Deck |
|---|---|
| Wasserfall/Grotte | 16 m breit × 8 m hoch |
| Tempeltor | 18 m breit × 8 m hoch |
| Hafenbogen | 20 m breit × 8 m hoch |
| Beide Brücken | 16 m lichte Breite, 16,4 m nominelles Deck |
| Anker/Übergänge | Passend zur verbreiterten Brücke |

Längssockets und Modullängen blieben gleich. Die Gesamtpakete B/C tragen Version 1.0.1; unveränderte Einzelassets behalten 1.0.0. `SocketIn` liegt bei (0,0,0), `SocketOut` bei (0,0,−Länge), Deckoberkante Y=0. Importierte Socketnamen können Blender-Suffixe tragen. Bei inneren Brückenverbindungen die dokumentierten ausgangsseitigen `JointOut__*`-Gruppen ausblenden.

Acht vorgeschlagene Einbaupositionen wurden gegen den echten Hauptteamkurs geprüft: **alle seitlichen Hüllräume bestehen**, kleinste abgetastete Seitenreserve **0,822070 m**. Das gibt flache Decks nicht automatisch für das bankende Höhenprofil frei. Endgültige Neigung, Geländeanschluss, Fahrfläche und Physikkollision bestimmt das Hauptteam.

Unsere alternative Audiosammlung überschreibt weder `scripts/games/kart_jungle_audio.gd` noch den bestehenden Hauptteam-Audiopfad `assets/audio/kart/jungle_emerald_3600/`. Die musikalische Auswahl und Bus-/Zonenintegration müssen bewusst erfolgen.

## Tatsächliche Prüfungen und offene Abnahmen

- 206 unabhängige GLB-Dateiprüfungen und 206 tatsächliche Godot-Imports: keine gemeldeten Fehler.
- 41 Blenderquellen wieder geöffnet; Texturabhängigkeiten vorhanden.
- 12.054 Längsstrahlen durch deklarierte Bauwerksdurchfahrten: keine Hindernistreffer.
- Zehn gerade Modulverbindungen: 0,0 m Socketabstand.
- 49 an Quellen gebundene Blender-Bilder und 36 tatsächliche Godot-Aufnahmen, Sonne/Schatten und mehrere Kameras.
- Finaler Prüfrenderer: **Mobile/Vulkan auf llvmpipe**, nicht eine physische Android-GPU. Windvideo: 72 feste Kameraframes bei 24 fps; keine gemessene Echtzeit-Framerate.
- Alle 18 Audioassets vollständig decodiert sowie im Godot-Mixer angespielt; 13 Loops über ihr Ende geführt und fünf Einmaleffekte beendet. Dummy-Audiotreiber, **keine subjektive Hörabnahme**.

**Offen bleiben:** das höhere künstlerische Referenzniveau, tatsächliches Anhören, Android-Framerate/Speicher/Flimmern/LOD-Wechsel sowie finale Streckenplatzierung, Wasserfall-VFX, Kollision und Audiointegration. Die stillen LOD-Vergleiche zeigen sichtbare Änderungen der Blattverteilung; nahtlose Übergänge wurden nicht behauptet. Eine Kenntnisnahme oder Übernahme durch das Hauptteam ist nicht bestätigt.

Die Lieferung besteht ausschließlich aus 573 neuen Dateien unter dem reservierten Namespace. Keine vorhandenen Spiel- oder Main-Dateien wurden verändert.
