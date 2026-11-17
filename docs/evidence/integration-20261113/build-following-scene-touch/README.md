# Build: Touch in der Folgeszene

## Ergebnis und Änderung

Die **Desktop-Testvorbedingung wurde korrigiert**. Die Produktdatei `scripts/creative/build_world.gd` ist unverändert. Die abschließende Probe besteht lokal **1.637 Headless-Assertions** über den unveränderten strengen Python-Runner; keine Fehler- oder Leakmeldung. Es gibt noch keinen gerenderten Green-Nachweis dieses Patches.

Geändert ist ausschließlich `scripts/tests/build_dialog_density_regression.gd`. Bei ursprünglich nativen Subwindows und realer Unterstützung für native Subwindows sowie Mouse-Warp wird vor dem abschließenden Touch der tatsächliche Desktopzeiger in die Zielschaltfläche geführt. Der tatsächliche Hover genau dieser Schaltfläche ist jetzt zusätzlich Pflicht. Danach laufen unverändert `_tap` → `InputEventScreenTouch` → `Button.pressed`. Die Popup-Freigabe, Wiederherstellung der Fensterpolitik, Trefferflächen und Eingabehelfer bleiben erhalten. Kein direktes Auslösen eines Signals, keine längere Probe-Deadline, keine Fehlerausnahme.

## Originalfehler

GitHub-Run **43444649016**, Job **131950806346**, auf Head `cf039ad8c834522f355b858e3bee1e201e397da4` und Tree `4fdbcbfcf069c6790e17101a09d4fb3f2955c2e2`. Headless war vollständig grün. Im echten X11/llvmpipe-Renderer scheiterte nach dem zweiten Profil (`1080×2400`, Dichte `2.625`) der Touch auf den Testknopf der Folgeszene, nachdem die ursprüngliche Fensterpolitik `false` erfolgreich wiederhergestellt und sämtliche eingebetteten Dialoge entfernt worden waren. Kein Timeout. Vier von acht geforderten PNG existierten.

Ungekürzte GitHub-Metadaten stehen in `original/`, der vollständige Original-Joblog und der vollständige fehlerhafte Renderlog liegen gzip-komprimiert daneben. Die unveränderten Source-Stamps und das originale `results.tsv` stehen in `original/source/`. Der originale ZIP-Digest lautet `9c6ddde95423630d63d8c609797175cf3b0e861f03bafbc58db54be71676b1b4` für Artifact **14048220569**. Das ZIP selbst wurde separat gegen den GitHub-Digest verifiziert und wird hier nicht dupliziert. Die Run-Metadaten sind ein früher unveränderter Snapshot des laufenden Runs, kein behaupteter Gesamtabschluss.

## Quellbegründung

`engine-sources.json` nennt die primären Godot-4.6.3-URLs und SHA256 der vollständig abgerufenen Quelltexte. `Viewport::_update_mouse_over` verlangt bei nativen Fenstern den Betriebssystemzustand des betretenen Fensters; bei eingebetteten Fenstern verwendet es die Ereigniskoordinaten direkt. `BaseButton::on_action_event` beginnt einen Mouse-Press nur bei Hover. Ein eingespeister ScreenTouch positioniert den echten Desktopzeiger nicht. Nach dem Verkleinern des Fensters kann dieser außerhalb bleiben, obwohl die injizierten Touchkoordinaten korrekt sind.

Die Zuordnung des beobachteten Fehlers zu dieser fehlenden Vorbedingung ist quellenbasiert. Der neue Renderer-Lauf muss die Diagnose zusätzlich mit den protokollierten tatsächlichen Vorher-/Nachher-Zeigerzuständen und bestandenem Hover-/Touch-Nachweis bestätigen. Vollständige fremde Engine-Quelldateien sind nicht Teil dieses Pakets.

## Lokaler Nachweis und offene Abnahme

Geprüft wurde lokaler Head `97b91e312eb982ab1fe9083b7415d11085385235`, Tree `79a9d0c98c4b6cd359cbd1531abfe1eefc663ac8`, plus exakt `repair.patch`, mit Godot `4.6.3.stable.official.7d41c59c4`. Getrennte XDG-Verzeichnisse und unveränderte 600-Sekunden-Deadline. `headless.log` ist vollständig. `validation.json` enthält Quellblobs, SHA256 und den Exitcode. Die Before-/After-Manifeste umfassen 2.242 Dateien; während des abschließenden Tests wurde keine davon verändert.

Der neue Desktop-Warp-Zweig wird headless nicht ausgeführt. Der vorhandene lokale Xorg/Dummy-Treiber konnte keine lokalen Sockets anlegen; der originale Fehler ist dokumentiert. **Ein frischer gerenderter Lauf muss zwingend den echten Hover, den unveränderten ScreenTouch/PRESSED-Nachweis und alle acht originalen Build-PNG liefern.** Bis dahin bestätigt dieses Paket keine abgeschlossene native Gesamtfreigabe und keinen neuen Host-Pin.
