# Treasure: gezielter Laufzeitnachweis vom 14. November 2026

**Ergebnis:** Der neue Regressionstest reproduziert den HUD-Fehler auf der unveränderten Treasure-Produktion aus Native `504c8ba7`. Mit dem engen Port besteht derselbe Test. Beide lokalen X11-Aufnahmeversuche endeten mit SIGKILL, bevor ein PNG entstand. Dieser Ordner enthält keine visuelle, Android- oder vollständige 52-Modus-Freigabe.

## Quellen und aktueller Integrationsstand

Baseline: `504c8ba70d02702cbccc370d0d96c36a292c5d27`.
Isolierter Zweidateien-Checkpoint: `a8e730ee8f9a9943ebd8b2d55544cc63c27af72c`.
Parallel erschien Native `0e26153f0e58cc05739e72923b4c563a4cf380b8`, ebenfalls direkt auf dieser Baseline.

Live-GitHub-Lesezugriffe und ein unabhängiger Nachreview bestätigten identische Dateien:

| Datei | Grüne Testquelle und aktueller 0e26153f-Blob |
| --- | --- |
| scripts/creative/treasure_world.gd | aae80484834823c8cf063df6bfb2607313f39ef7 |
| scripts/tests/treasure_title_contrast_regression.gd | 73939c37e38bdbaca77220f79227e3dcde26e59c |

Der gezielte Source-Review ist auf diese beiden Dateien übertragbar. Der gesamte 0e26153f-Tree wurde hier nicht ausgeführt. Seine zusätzlichen Settlement-, Nachweis- und Verifieränderungen werden dadurch nicht zertifiziert.

Upstream enthält bereits die genaue Erweiterung auf zehn Profil-/Startzustände, fünf Treasure-PNGs und insgesamt 17 Studio2020-Raster. Verifier `b60c3360730f0db73f91324cbaed3a8806fd141e` prüft außerdem die Safe-Area-Grenzen sämtlicher HUD-Rechtecke. Deshalb wird kein paralleler Produktions- oder Verifierpatch zusätzlich eingebaut.

## Tatsächlich ausgeführte Läufe

Engine: `4.6.3.stable.official.7d41c59c4`.

| Lauf | Ergebnis | Dauer |
| --- | --- | ---: |
| Alte Produktion, neuer Test, headless | Exit 1; 3.221 Checks, 40 Fehler | 17,87 s |
| Portierte Produktion, derselbe Test, headless | Exit 0; 3.341 Checks, 0 Fehler | 19,47 s |
| X11/Mesa llvmpipe, Standardkonfiguration | Godot-Exit −9; kein PNG | 7,95 s |
| X11/Mesa llvmpipe, LP_NUM_THREADS=2 | Godot-Exit −9; kein PNG | 64,51 s |

Der negative Kontrolllauf ist eine echte Produktregression; Import- oder Setupfehler wurden nicht als Red-Nachweis verwendet. Der grüne Lauf prüft fünf Profile jeweils frisch und wiederhergestellt, tatsächliche ScreenTouch-Ereignisse, Clipping, projizierte Geometrie, Kontrast und Fortschrittsinvarianten.

Die unveränderten Godot-Logs, Prozessberichte und Headless-JSON-Berichte liegen neben diesem Dokument. Die Berichte bestätigen für Produktion und Test identische SHA-256-Werte vor und nach jedem Lauf. `source-identity.json` bindet die Quellidentitäten.

Beide X11-Läufe starteten den echten OpenGL-Software-Renderer. Vor SIGKILL meldeten sie keinen SCRIPT ERROR, aber auch keinen vollständigen PASS. Im zweiten Versuch wurden maximal 924.216 KiB Child-RSS beobachtet. Die Ursache des SIGKILL ist damit nicht abschließend bewiesen; diese Zahl allein ist kein Kernel-OOM-Nachweis.

[LP_NUM_THREADS](https://docs.mesa3d.org/envvars.html#envvar-LP_NUM_THREADS) begrenzt laut Mesa-Dokumentation die Software-Renderthreads. Die Einstellung änderte keine Produktionsdatei und deaktivierte keine Rasterisierung. Die fehlgeschlagenen Originalversuche wurden erhalten.

## Review und verbleibende Abnahme

`independent-review.md` dokumentiert den unabhängigen Source- und Provenienzreview. Alle 52 Gate-Aufrufe bleiben statisch erhalten; hier wurde kein tatsächlicher 52-Modus-PASS erzeugt.

Offen bleiben für den zusammengeführten Kandidaten die fünf frischen Original-PNGs mit visueller Prüfung, die vollständigen Native-Gates und die anschließenden Android-/Geräteprüfungen. Der verfügbare CI-Runner soll diese Belege erzeugen. Hier wurden keine Hostpins, Freigabelisten, Main-Branches oder Play-Veröffentlichungen geändert.

Der Evidenzcommit ergänzt ausschließlich diesen Dokumentordner auf dem aktuellen Native-Tree. `manifest.json` bindet alle übrigen Dateien des Ordners über SHA-256.
