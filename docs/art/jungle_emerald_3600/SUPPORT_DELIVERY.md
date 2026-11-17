# Dschungelherz – Detail V2: dichterer Blender-Ausbau

## Tatsächlicher Stand

**34 neue Einzelassets, 98 neue GLBs und 23 bearbeitbare Blender-Dateien** ergänzen die unverändert erhaltene V1-Lieferung. Drei in Blender ausgearbeitete Landschaftsausschnitte enthalten zusammen **1.972 Platzierungen**. Ein separater, standardmäßig ausgeschalteter Dekorationsadapter enthält **1.443 Platzierungen entlang der gesampelten Hauptteamroute**. Diese Zahlen beschreiben unterschiedliche Lieferungen und werden nicht zu einer angeblich fertig ausgestatteten Gesamtstrecke addiert.

Die Arbeit erfolgte mit genau den drei Produktionsagents Vegetation, Bauwerke/Landschaft und Audio/Atmosphäre; keine weiteren Agents wurden gestartet. Der Koordinator prüfte die gemeinsame Lieferung unabhängig und betrachtete alle 26 endgültigen Vergleichsbilder.

**Technische Paket- und Importprüfung bestanden. Künstlerische Referenzabnahme und physische Android-Abnahme bleiben offen.** Die Landschaft ist sichtbar stilisiert und erreicht die durchgehende Ausarbeitung und Lichtwirkung der vorgegebenen Referenz noch nicht. Die Lieferung ist ein geprüfter Asset- und Landschaftsausbau, keine fertig integrierte, freigegebene 3.600-m-Rennstrecke.

## Verifizierte Dateien

| Lieferung | Datei | Größe, dezimal |
|---|---|---:|
| Vollständige V2-Ergänzung | [Dschungelherz_Detail_V2_Vollstaendig_dc31bbe3cf0c.zip](https://chatgpt.com/library?file_id=libfile_fde3_f-fa1f587230b8819197e428b04a80cfdf_6ebd937ff63881919793f20afab4b8a6&account_id=personal) | 535,84 MB |
| Eigenständiges Godot-Prüfprojekt | [Dschungelherz_Detail_V2_Godot_dc31bbe3cf0c.zip](https://chatgpt.com/library?file_id=libfile_fde3_f-f7cd9c33e2888191863975caaf1bd3ca_6ebd937ff63881919793f20afab4b8a6&account_id=personal) | 200,32 MB |
| Inkrementeller Quellzweig | [Dschungelherz_Detail_V2_Quellzweig_dc31bbe3cf0c.bundle](https://chatgpt.com/library?file_id=libfile_fde3_f-10a3b112c76c8191a1542c5b5010b492_6ebd937ff63881919793f20afab4b8a6&account_id=personal) | 413,05 MB |
| Archiv-/Importbelege und Anleitung | [Dschungelherz_Detail_V2_Archiv_und_Importpruefung.zip](https://chatgpt.com/library?file_id=libfile_fde3_f-9ab3d663b758819181f49e3ae9e4d374_6ebd937ff63881919793f20afab4b8a6&account_id=personal) | 0,08 MB |
| Tatsächliche Wind-/Wasservorschau | [godot_wind_water_motion_v2.mp4](https://chatgpt.com/library?file_id=libfile_fde3_f-96ed4a4534188191a92d5d3acf378ae7_6ebd937ff63881919793f20afab4b8a6&account_id=personal) | 0,93 MB |

Das vollständige V2-Paket enthält alle neuen Blender-Quellen, Texturen, Exporte, Werkzeuge, Dokumente und Bildbelege sowie die benötigten V1-Runtime-Abhängigkeiten. Das kleinere Godot-Paket enthält die ausführbare Prüfszene mit allen 140 Modellabhängigkeiten; die Blender-Quellen und Bildgalerie liegen im vollständigen Paket. Die V1-Pakete A–D bleiben getrennt erhalten.

Alle ZIPs besitzen einen eigenen Wurzelordner. Separat entpacken; den enthaltenen `project.godot` nicht über die produktive Projektkonfiguration kopieren. Die Downloads sind Dateien des Auftraggebers und kein öffentlicher Asset-Host.

### Tatsächliche Prüfsummen

- Vollständiges V2-ZIP: `cd4a202a1fb06480f39d3119a42d9aa45e76128487ee7bdab99d4d4be726bb45`
- Godot-ZIP: `eb6a928c8f10605a97dd4d1f645a48b15b6ea266ced2cbdef83788623a2b953b`
- Git-Bundle: `bc35cda4cd980b15fb760f5bb9bba89d1e1a679336e64691b5777c502c27afcd`

Beide Hauptarchive wurden vollständig gelesen und auf CRC32, SHA256, sichere Pfade und vorhandene GLB-Texturreferenzen geprüft. Pro Archiv sind 140 GLBs und 872 lokale Bildverweise geschlossen vorhanden. Das vollständige Archiv enthält 982 Nutzdateien plus `DELIVERY.json`, das Godot-Archiv 550 Nutzdateien plus `DELIVERY.json`.

Das fertige Godot-ZIP wurde anschließend in ein neues Verzeichnis **ohne Importcache** entpackt. Tatsächlicher Editorimport und tatsächliche Instanziierung/Vermessung: **140 Modelle, 0 Fehler**. Die zu genau diesem ZIP gehörenden Logs und Prüfsummen liegen im kleinen Nachweispaket. `git bundle verify` bestätigt das Quell-Bundle.

## 1. Bäume und Pflanzen

Die 20 neuen Vegetationsassets umfassen zwei stark ausgearbeitete Hauptbäume (`je_hero_kapok_v2`, `je_hero_strangler_v2`), fünf Waldbaumformen mit je drei Varianten und drei neue Farnformen. Es gibt je drei explizite LODs, insgesamt 60 GLBs.

Die Hauptbäume besitzen große Brettwurzeln, Haupt- und Nebenäste, mehrere Kronenlagen, modellierte Blätter, Rindenstruktur, Moos und Aufsitzer. Die Nahvarianten haben jeweils ungefähr 175.000–179.000 Dreiecke und rund 7.800 Kronenblätter; Fernstufen sind separat geliefert. Die hohen Nahzahlen sind ein Geometrieinventar und keine Android-Budgetfreigabe. Originale Rindenkarten liegen mit 2.048 Pixeln, Blattkarten mit 1.024 und Mooskarten mit 512 Pixeln vor. Der optionale Windshader verwendet echte Vertexgewichte; Stämme bleiben stabil.

Quellen: `art/jungle_emerald_3600/detail_v2/vegetation/`. Runtime, Texturen und Wind: `assets/kart/jungle_emerald_3600/detail_v2/vegetation/`. Der V1-Bestand mit Palmen, Bambus, weiteren Pflanzen, Wurzeln und Lianen bleibt erhalten und wird teilweise wiederverwendet.

## 2. Landschaft und Bauwerke

Elf neue Architektur-/Landschaftsassets liefern Wasserfallmassiv, separate Wasserfallflächen, Grotteneingang, 8-m-Grottenmodul, großes Tempeltor, Felswand, gebrochene Tempelmauer, Moosfugen, Sandsteintrümmer, Wurzelmantel und Beckenrand. Je zwei LODs ergeben 22 GLBs und elf Blender-Quellen.

Drei Atmosphärebauteile ergänzen Laterne, kleine Leuchtpflanzengruppe und Reliefstein: sechs GLBs, drei Blender-Dateien. Die Laterne verwendet die dokumentierte Normalenreparatur 2.0.1; ihre Maße und Kennung wurden dabei nicht geändert. V1-Brücken, Hafen und weitere Landschaftsbauteile bleiben unverändert verfügbar.

| Ausschnitt | Stationen des Straßenkontexts | Ausgearbeiteter Kern | Platzierungen |
|---|---:|---:|---:|
| Smaragdschlucht | 980–1.260 m | 130 m | 528 |
| Tempelwald | 2.210–2.490 m | 130 m | 726 |
| Wurzelgrotte | 1.160–1.440 m | 130 m | 718 |

Diese Ausschnitte enthalten Gelände, Böschungen, Wurzelauflagen, Pflanzencluster, Steine, Blüten und Lichtpunkte. Zehn Szenengeometrien ergänzen die Einzelassets; die drei Szenendateien und drei verknüpften Bibliotheken gehören zusammen. Die sichtbare Straße ist Referenzgeometrie ohne endgültige Fahrbahnkollision.

Blender: `art/jungle_emerald_3600/detail_v2/scene/je_<layout>_landscape_v2.blend`. Das Layout und die Terrain-/Straßen-/Bodendetail-GLBs liegen unter `assets/kart/jungle_emerald_3600/detail_v2/scene/`. Die Bildgalerie liegt im vollständigen Paket unter `evidence/jungle_emerald_3600/detail_v2/scene/VIEW_GALLERY.html`.

## 3. Musik und Geräusche

V2 enthält keine neue Musikfassung. Die 18 originalen Audioassets aus Paket D bleiben bytegleich: drei 64-Takt-Musikvarianten bei 112 BPM, zehn Atmosphären, drei Vogelrufe und zwei Rennsignale. WAV-Master, MIDI-/JSON-Partituren und Synthese-/Arrangementquellen gehören weiterhin zum gesonderten V1-Audiopaket. Drei unveränderte OGG-Atmosphären sind als optionale Abhängigkeiten des V2-Dekorationsadapters enthalten.

Die bisherige technische Audioabnahme ersetzt keine subjektive Hörabnahme. Eine tatsächlich durchgeführte menschliche Hörprüfung wird weiterhin nicht behauptet.

## 4. Sichtprüfung, Renderer und Bewegung

Produktion: **Blender 4.3.2**, Prüfung: **Godot 4.6.3**, Maßstab **1 Einheit = 1 m**. Blender +Z oben/+Y vorwärts wird zu Godot +Y oben/−Z vorwärts. Die normale Rennkamera liegt 2,52 m über der Kursreferenz und nutzt 55° Sichtfeld.

13 tatsächliche Cycles-Ansichten und 13 tatsächliche Godot-Aufnahmen decken Rennkamera, Übersicht, Nahansicht und Schattenvergleich ab; die Grotte hat zusätzlich eine Innenansicht. Sie sind an die aktuellen Quellen, Layouts, GLBs und erfolgreich beendeten Rendererprozesse gebunden. Die Godot-Aufnahmen verwenden **Mobile/Vulkan auf llvmpipe**: Smaragd 1.280 × 720 Pixel, Tempel/Grotte 960 × 540 Pixel. Unterbrochene Versuche bleiben getrennt dokumentiert.

Die Wind-/Wasservorschau besteht aus 72 echten, unterschiedlichen Bildern, kodiert als drei Sekunden bei 24 fps. Der Koordinator betrachtete die Vergleichsframes 0, 35 und 71. Das ist eine Aufnahme mit kontrollierter Shader-Zeit und fester Kamera; **keine Messung der Echtzeit-Framerate und kein LOD-Fahrtest**.

Vorschauen: [Blender – Wasserfall](https://chatgpt.com/library?file_id=libfile_fde3_f-b65624381f1c81918eeb5aed15686db7_6ebd937ff63881919793f20afab4b8a6&account_id=personal) · [Blender – Tempelübersicht](https://chatgpt.com/library?file_id=libfile_fde3_f-2634fe7484e08191b8135f0d1b50cd89_6ebd937ff63881919793f20afab4b8a6&account_id=personal) · [Blender – Grotte](https://chatgpt.com/library?file_id=libfile_fde3_f-3a9e327559d88191860fec6e96a3ec72_6ebd937ff63881919793f20afab4b8a6&account_id=personal) · [Godot – Wasserfall](https://chatgpt.com/library?file_id=libfile_fde3_f-b0c37a326a3881918b7a6b7229134630_6ebd937ff63881919793f20afab4b8a6&account_id=personal).

## 5. Konkrete Commits und Integration

| Bestandteil | Commit |
|---|---|
| V1-Basis und Bundle-Voraussetzung | `420ef173392ff891dc8b6d52834cf80f7c433fab` |
| A2: Vegetation | `ab77b53bf5d5139ae5bc2fc295eb6cd711cf9ab4` |
| B2/C2: Architektur, Atmosphäre, Dekorationsadapter | `04acd7e2d723497ba91077bdb90cc6bb2fc68e8e` |
| Landschaften und geprüfte gemeinsame Ansichten | `35e7d3cf6e94b4506cacb3cb446a2288598e0790` |
| Vollständiger V2-Paket-/Bundle-HEAD | `dc31bbe3cf0c9f98f15c98822edc2d10668ac0b3` |

Quellzweig: `art/jungle-emerald-detail-v2-20261115-1a6e`. Die Binär-Produktionscommits werden über das Git-Bundle übergeben; sie werden nicht als erfolgreich auf GitHub gepusht ausgegeben. Der gemeinsame Draft-PR #186 enthält die Übergabedokumentation. Main bleibt unverändert.

Nach Einspielen der V1-Basis aus dem bereits gelieferten V1-Bundle:

```bash
git bundle verify ./Dschungelherz_Detail_V2_Quellzweig_dc31bbe3cf0c.bundle
git fetch ./Dschungelherz_Detail_V2_Quellzweig_dc31bbe3cf0c.bundle refs/heads/art/jungle-emerald-detail-v2-20261115-1a6e:refs/remotes/jungle-support/detail-v2
git worktree add ../lumo-jungle-detail-v2-review --detach refs/remotes/jungle-support/detail-v2
```

Die tatsächliche Hauptteamquelle ist an `36a2a240d3f21b3943ab123b30408735fb7b9298` auf `feature/lumo-jungle-emerald-3600-20261115-a298` gebunden. Der PR-Basisstand wurde vor der Übergabe erneut bestätigt. 1.801 echte Kurssamples ergeben 3.600,0503 m. Normale Straßenbreite 14 m, Fluss/Tempel 16 m, Start/Ziel 18 m. Wasserfall/Grotte haben 16 × 8 m freien Raum, das neue Tempeltor 18 × 8 m.

Vollständige Maße, Material-/Texturinformationen, Geometriezahlen, LODs, Quellpfade und Hashes: `docs/art/jungle_emerald_3600/detail_v2/ASSET_REGISTER_V2.json`. Anleitung: `INTEGRATION_V2.md`; Quellbindung: `RELEASE.json`; Sichturteil: `VISUAL_REVIEW_V2.md` im selben Ordner.

Der optionale Adapter unter `assets/kart/jungle_emerald_3600/detail_v2/dressing/` hält drei oder fünf 100-m-Abschnitte aktiv und ist zunächst ausgeschaltet. Er besitzt 175 tatsächliche Runtimekontrollen und einen Abgleich gegen sämtliche gesampelten Straßensegmente. Vor produktiver Verwendung muss der echte Gelände-Resolver angeschlossen werden. Die Standardhöhe aus der gebankten Straßenebene ist keine vollständige Geländeabnahme.

## 6. Konkret offene Punkte

- Das höhere künstlerische Referenzniveau, durchgehend ausgearbeiteter Fernbewuchs und finale Lichtgestaltung sind nicht abgenommen.
- Einpassen in das tatsächliche Gelände, endgültige Bankung, Fahrflächen/Kollision, Wasser-VFX, Audiozonen und App-Integration bleiben beim Hauptteam.
- Physische Android-Framezeiten, RAM/VRAM, transparente Sortierung, Texturflimmern und LOD-Wechsel während einer Fahrt fehlen. Keine 60-FPS-Freigabe.
- Die unveränderte V1-Audiolieferung benötigt weiterhin eine tatsächliche subjektive Hörabnahme.
- Die sechs neuen GDScript-Dateien bestehen Lint/Format; der Projektvalidator meldet 118 PASS. Die bytegleichen vorhandenen 553 Projektskripte besitzen weiterhin 2.838 Lint-Befunde und 360 Formatabweichungen. Eine projektweit grüne Codeprüfung wird nicht behauptet.
- Eine Kenntnisnahme oder Übernahme durch das Hauptteam ist nicht bestätigt. Der PR und die konkreten Dateien bilden den gemeinsamen Übergabepunkt.


---

# Erhaltene V1-Übergabe

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
