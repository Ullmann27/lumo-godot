# Vollstaendiger Pausehintergrund bei Safe Insets

Status: SCOPED SOURCE / LINUX GL PASS / ANDROID NOT EXECUTED / VISUAL_GAP / NOT FINISHED.
BASE: 3f9ff57b15e27b373e4baf696c43af3fa0ef9ca0.
Branch: codex/lumo-modal-viewport-repair-2026-10-09; RESULT ist dessen frischer Head.

## Belegtes Problem und kleine Korrektur

Die echten eigenen APK-1908-Aufnahmen von Android35 und36 zeigen am inneren
Display helle, ungedimmte Randstreifen im Pausemenue. Der voll verankerte
modal_backdrop ist Kind von RaceSafeArea und erbt deshalb dessen Safe Insets.
Vier kompensierende Offset-Zeilen in _apply_safe_area erweitern ausschliesslich
den Hintergrund auf den gesamten Viewport. Dialog/HUD behalten ihre Insets;
Hierarchie, Farbe, Filter, Sichtbarkeit und vorhandene Touch-Routen bleiben.
Keine Aenderung an Fahrphysik, Kamera, Fahrzeug, Ergebnis oder Belohnung.

## Nachweis und Grenzen

Identische neue 40er-Probe: BASE30 PASS/10 FAIL, Kandidat40 PASS/0 FAIL. Die zehn
BASE-Fehler sind ausschliesslich Viewportabdeckung und Randpixel. Fuenf echte
Linux-X11/Software-GL-Groessen-/Insets-/Motionfaelle pruefen Cover -> innen ->
Cover -> Telefon -> reduzierte Bewegung. Insets sind ausdruecklich synthetische
physische Fixtures; normale Engine-Physik und reale ScreenTouch-Ereignisse laufen.
Die zehn echten World-Pause-PNGs werden vor der getrennt beschrifteten weissen
Alpha-Kalibrierung aufgenommen. Kalibrierbilder sind kein Gameplay-Nachweis.
Alle 74 neuen Touchrows sowie Safe-/Dialog-/Footergeometrie sind im Paar exakt
gleich. Maximale Kantenabweichung0.00024414px bei unveraendertem0.5px-Limit.
Die acht Kalibrierpixel gehen von255 aufRGB[140,143,148]; Farbe/Filter unveraendert.

Die urspruengliche Modal37-Probe bleibt bytegleich und besteht37/37 mit sechs
echten Buttondrags,106 Touch/Drag-Ereignissen und14 echten PNGs. Strict Engine0,
keine SCRIPT ERROR/ERROR/Leaks, Quellen vor/nach unveraendert, eigene Prozesse
beendet. Sieben manipulierte Readerfaelle abgewiesen. Root hat echten
BASE/Kandidaten-Innenbildvergleich und den Vier-Zeilen-Diff selbst geprueft.

Proof-only ZIP:29575287B/52Mitglieder/SHA256
769a01348abd3cbc081b53924820beb7b957102caba781af1a7cfc687a6ba9a1.
Kandidaten-Core SHA256:
75ee58658c634574dd13bf200a64084de5a80a6a07242137cd591e96e0ce360f.
Git-Quellpaket ist getrennt; keine Konzeptbilder, keine GPU/FPS-Zusage.

## Integration und offene Runtime

Claim: Core::_apply_safe_area, neue kart_modal_backdrop_regression.gd und diese
Uebergabe/OPUS-Praefix. Aktive 3f9-Ref und App2b60/Pin/APK1908 bleiben unveraendert.
Vor Integration neue erste aktive Speicherung und Actionvarianten getrennt
pruefen; ihre freien Funktionen beruehren diese Offset-Zeilen nicht.
Danach selektiv graften, strikte App-Sourcebindings auf tatsaechliche neue Bytes
retargeten und alle bisherigen Native24/GL17, Profile24 und Finish16 erhalten.

Eigene1908-APK ist gebaut/binaer-nativ bestaetigt, aber Run37892031317 scheiterte
aufAPI35 und36 am originalen1200-Sekunden-Alarm im weiterfahrenden Rennen.
Finish/ACK/Belohnung/finale Rueckkehr wurden nicht erreicht. Dieser Fix loest
diesen Timeout nicht. Neue exakte APK mit dieser Korrektur, Androidgroessenwechsel,
physisches Fold, Zielgeraete-Framezeiten und Referenzbewegung: NOT EXECUTED.

Quelle: offizielle Godot4.6 Control-Dokumentation, offsets relativ zu den
Parent-Ankern: https://docs.godotengine.org/en/4.6/classes/class_control.html .
Eigene vorhandene Implementierung angepasst; kein fremder Code/keine neue
Runtime-Abhaengigkeit. Main/Releases und fremde Claims bleiben unveraendert.
