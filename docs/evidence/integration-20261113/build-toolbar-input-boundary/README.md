# Build: Eingabegrenze der Werkzeugleiste

## Reparatur und Ergebnis

**Eine fehlende GUI-Eingabegrenze war die Ursache.** Der Produktdiff besteht aus genau zwei Zeilen in `scripts/creative/build_world.gd`: einem Kommentar und `scroll.mouse_filter = Control.MOUSE_FILTER_STOP` am bestehenden äußeren Toolbar-ScrollContainer. Kindbuttons bleiben PASS, horizontales Scrollen AUTO und vertikales DISABLED. Welt-Gesten, Grid, Transformregeln, Bauweltgröße, Kollision und Spielstände bleiben unverändert.

Die unveränderte BuildPlay-Probe besteht anschließend **62/62 Assertions**. Die vorhandene Dichte-/Touchprobe besteht **1.637/1.637 Assertions**. Beide liefen im originalen strengen Python-Runner mit getrennten XDG-Verzeichnissen und unveränderten 420-/600-Sekunden-Deadlines, ohne ERROR-, Parse- oder Leakmeldung. Die BuildPlay-Probe bleibt bytegleich `f7d87b2f103042bd82eeecddf956d8385a70d0a7`; keine Assertion wurde gestrichen oder gelockert.

## Original und lokale Red-Reproduktion

Der originale Core-Job **131950805762** aus Run **43444649016** auf Head `cf039ad8c834522f355b858e3bee1e201e397da4`, Tree `4fdbcbfcf069c6790e17101a09d4fb3f2955c2e2`, enthält **35 PASS / 2 FAIL**. Ausschließlich BuildPlay scheitert in beiden Modi an denselben vier fachlichen Erwartungen: reine Drehvorschau, exakte spätere Platzierung, tatsächliche Wandkollision und anschließendes Inspizieren der Wand. Der originale 24-PNG-Studio-Roster war PASS. Bundle und Archiv wurden korrekt übersprungen.

Ungekürzte Run-/Job-/Artifact- und Source-Metadaten, beide vollständigen Build-Fehlerlogs und der vollständige Core-Joblog gzip liegen in `original/`. Das extern erhaltene Original-ZIP **14048314783** hat SHA256 `79c4e14f10b05bb19c42f4ec43f519a04fcb37db5229d5eb434cde6b17d0421d`; Pfade, CRCs und Digest wurden geprüft. Das ZIP wird nicht in Git dupliziert.

`local-red.log` reproduziert exakt die vier Fehler am unveränderten Produkt. `diagnostics/observed-input-red.log` ergänzt nur beobachtende Signalausgaben. `diagnostics/touchscreen-red.log` reproduziert dieselbe Fehlfolge nochmals mit ausdrücklich aktivierter Android-artiger Touchfixture (`touchscreen=true`). Das ist tatsächlicher Godot-Input in einer Headlessfixture, kein physisches Androidgerät oder IPC-Nachweis. Alle Diagnoseänderungen sind als reproduzierbare Diffs gegen die unveränderte Probe enthalten.

## Gemessene Ursache und Gegenexperiment

Der Drehknopf liegt vollständig sichtbar bei `(326,88)` mit Größe `(99,48)` im Scrollbereich `(12,88;1256,56)`. Sein echtes `pressed`-Signal setzt korrekt `turn=1`, während das Stück noch ausgewählt ist. Anschließend fällt der rohe ScreenTouch-Release durch die PASS-Container in den Welt-Handler. Dieser committed das Stück sofort auf `(-31,0,-20)` und löscht die Auswahl. Die später vorgesehene Platzierung kann daher nicht mehr gelingen. Die folgende Geste dreht stattdessen die Kamera auf `orbit=-0.315`; Lumo läuft an der Wand vorbei, wodurch auch Kollision und Inspizieren scheitern.

Das kontrollierte Gegenexperiment änderte allein den äußeren Container von PASS(1) auf STOP(0), bei unverändertem PASS-Kindbutton. Nun bleibt die Drehung Vorschau; erst der vorgesehene Welt-Touch setzt das Stück auf `(-18,0,10), turn=1`. `orbit` bleibt `0`. Der echte Kollisionskörper stoppt bei `x=-12.29094`, und die Interaktion meldet `Mauer`. Alle 62 bisherigen Assertions bestehen. Vollständiger Gegenexperiment-Log und dessen reproduzierbarer Diff liegen unter `diagnostics/`. Es gab keine direkte Signalemission oder künstliche Rotation.

## Weshalb die Kombination den Fehler auslöste

Studio24fb setzt die Toolbar-Kindbuttons für die neue Wischbedienung auf PASS. Village7c erweitert die Bauwelt von `HALF=24` auf `HALF=128`. Der versehentliche Toolbar-Raycast auf `x=-31` war zuvor durch die Baugrenze ungültig, im kombinierten großen Gelände jedoch zulässig. Dadurch wurde der Eventdurchfall zum sofortigen gültigen Commit. Catalog, Explorer, Voxelstil, CreativeRuntime und BuildPlay-Probe sind in diesen Quellen bytegleich.

`source-provenance.json` nennt die exakten unveränderlichen Commits, Trees, Bounds und Blobs; Flutter-Integration hat diesen Herkunftsvertrag unabhängig read-only bestätigt. `engine-container-source.json` bindet die primäre Godot-4.6.3-Quelle mit SHA256: Container setzen standardmäßig PASS. Der äußere STOP schließt genau diese Lücke. PASS-Kindbuttons reichen weiterhin zum ScrollContainer weiter; die vorhandene `_input`-Freigabe bereits aufgenommener Weltobjekte bleibt vor der GUI unverändert.

## Quellen und noch offene Abnahme

Die finalen Läufe verwenden lokalen Head `97b91e312eb982ab1fe9083b7415d11085385235`, Tree `79a9d0c98c4b6cd359cbd1531abfe1eefc663ac8`, plus den aufgezeichneten Produktpatch und den zuvor getrennt dokumentierten Desktop-Folgeszenen-Testpatch. Alle 45 erfassten Build-/Creative-/Projekt-/Runnerquellen blieben während beider finaler Läufe unverändert. Parallel bearbeitete Kart-Tests und Legacy-Shellfilter sind ausdrücklich außerhalb dieses Build-Manifests. Quellblobs, Loghashes und Prüfgrenzen stehen in `validation.json` und den Before-/After-Manifeste.

Die von Root tatsächlich geöffneten Originalbilder `01_build_selection` und `03_build_walking` sind mit ihren Originalhashes benannt; große Bilder werden nicht kopiert. **Ein frischer gerenderter CI-Nachweis des abschließenden gemeinsamen Heads bleibt zwingend.** Dieses Paket behauptet keine neuen Rendererbilder und keine vollständige Native-/Hostfreigabe. Der ältere Pack `../build-following-scene-touch/` bleibt als historischer Nachweis des isolierten Desktop-Testfixes erhalten; dessen 1.637 Assertions wurden hier mit dem reparierten Produkt erneut bestanden.
