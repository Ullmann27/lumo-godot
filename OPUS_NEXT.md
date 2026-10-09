# Wiederherstellung 2 · aktueller Stand 2026-10-09 · NOT FINISHED

Aktueller dauerhafter Recovery-Checkpoint ist Godot
`4b63ec27cb423e600c3ded182f57a795dc357579`, Tree
`6d9369acf169e22a9dae69a398ffd0ce5ad00e64` (frisch lokal geprüft).
Produktdatei `kart_island.gd` ist SHA256
`7247dd551b900194936d60d31e4436d0e2a9dc74fb4c91e2306d94f6d8689c8c`.
Die neu implementierte Continuity-Probe umfasst **104** zusätzliche Bedingungen;
der aufgerufene Lifecycle-Helper umfasst **10** getrennte Zustandsbedingungen.
48 Continuity- und26 CompleteFlow-assert-Callsites des frischen c95-Originals
sind statisch unverändert erhalten; diese Zahlen sind keine instrumentierten
Einzeltest-Ausführungszahlen. Die App-Inventur bleibt bei22 Probeentrypoints.

Der zweite Scratchverlust hat die dortigen aktuellen7247-Outputs erneut
entfernt. Der beobachtete104+10-GL-Lauf hatte sämtliche funktionalen Bedingungen
GREEN, scheiterte jedoch strikt an14 Texture-Leaks beim Engine-Ende: **GPU FAIL**.
Diese verlorenen Dateien dürfen nicht als aktuell vorhanden oder erneut gehasht
behauptet werden. Neuaufnahme und Userdaten liegen jetzt ausschließlich unter
`/tmp/lumo1906-recovery2`; Code wurde aus dem aktuellen GitHub-Checkpoint
wiederhergestellt, nicht aus alten Berichten neu erfunden.

Frische neue Teilnachweise nach dem zweiten Verlust: regulärer Headless-Coldimport
EngineExit0 ohne ERROR; unveränderter fb78-Lifecycle-Helper funktional10/0, aber
erneut14 Texture-Leaks und striktesFAIL. Vier isolierte Texture-Kontrollen
(Konstruktion, tatsächliche Regeneration,3D-Normalmap, bytegleiche ImageTexture)
schließen ohne Enginefehler. Das belegt bislang keinen allgemeinen NoiseTexture-
oder Materialbindungsfehler. Helper-Cleanup bleibt ein kleiner reversibler
Versuch; Produkt-Texture-/Physics-/Kamera-Code wurde dafür nicht verändert.
Der nur lokal rekonstruierte Helper23688 ist **DRAFT / NOT ACCEPTED**.

Frühere sporadische ACK-Save-Fehler im Workspace sind unverklärt; der vor dem
zweiten Verlust beobachtete einzelne isolierte/tmp-FullFlow-PASS ist kein
verfügbarer neuer Dateinachweis. Vollständiger neuer104+10-GL-Abschluss, zwei
unveränderte/tmp-FullFlow-Abschlüsse, aktueller Time29-Nachweis und unabhängige
Native22-CI bleiben Integrationsgates. Keine Assertions, ACK-Gates oder
strict-Engineerrorprüfungen abschwächen. APK/SDK-Integration, Android/API35/36,
physische Fold-Prüfung und Geräteperformance bleiben **NOT FINISHED / NOT EXECUTED**.
Keine Android-Wallet- oder60-FPS-Zusage aus den nativen Testhost-Fixtures ableiten.

## HISTORICAL / LOST ORIGINAL · frühere103/a6f171-Übergabe

Der folgende vorherige Text bleibt unverändert als historische Übergabe.
Die ursprünglichen a6f171-/a2605686-Testbytes wurden nach dem ersten Verlust
nicht wiederhergestellt; die damaligen Dateipfade und Screenshots sind kein
neuer Nachweis aktuell vorhandener Originaldateien.

# Aktuelle Runden-Speicherung für1906 · 9. Oktober2026

Zuerst [das geprüfte Lap-Session-Paket](docs/LAP_SESSION_2026-10-09.md) lesen.
BASE ist exaktc95fc489219223e3d66e8ed1a7a4dbe933b05f08; RESULT/PIN am
frischen tatsächlichenBranch-HEAD prüfen. Tatsächlich gefahreneLap2-Reopen
verlor zuvorMesshistorie/Startzeit, finishedReopen die sichtbare besteRunde;
öffentlicheGesamtzeit und UI hatten unterschiedlichePräzision.
Identische103er-Probe BASE51PASS/52FAIL → Kandidat103PASS/0FAIL, strictX11/GL;
alle97Timingbedingungen bleiben, sechsneueResultUI-Bedingungen bestätigen
sofortversteckte/deaktivierteFahrcontrols, konsistenteResultatüberschrift und
beobachtete0km/h fürfertigeResultate sofort/nächsterTick. DieHUDkorrektur
ändert ausschließlichdreiTextanzeigen; roheGeschwindigkeit/Physikbleiben.
CompleteFlow erhält allealtenGates/Assertions/fünfPNGs und ergänzt echteLap2-
und finishedReopen mit sechstemPNG. Ergebnis-ID/ACK/eineBelohnung bleiben.
UnveränderteZeitprobe29PASS;22 App-Proben bleiben22. NeueAPK-/Android-
Abnahme noch ausstehend; **VISUAL_GAP / NOT FINISHED**. Main/Releases unverändert.
Die frühere97GREEN-Evidenz vor tiefem Snapshot ist EVIDENCE_BLOCKED;
ausschließlich finale Snapshot-RED/GREEN-Belege verwenden. Identischefinale
Probea6f171 aufechtemc95 liegt `base-speed-full/`, finaler7e600-GREEN unter
`speed-gl-final/`; CompleteFlow `speed-gl-complete-flow/` zeigt tatsächlich
01:22.983/00:41.183 und0km/h. Finale5Dateien vorIntegrationexaktprüfen.

Die folgendeZeitformat-/1905-Übergabe bleibt historischerNachweis.

# Aktuelle Ergebniszeit-Korrektur für1906 · 8. Oktober2026

Zuerst [die geprüfte kleine Zeitformat-Korrektur](docs/TIME_FORMAT_2026-10-08.md)
lesen. BASE ist exaktad3ee9c9a1e2cfa60a6d2fe4970181b3150a1a1b;
aktuellen RESULT/PIN am frischen Branch-HEAD prüfen. Beobachteter1905-Fail:
sichtbare beste Runde40.000 statt tatsächlicher41.000 Sekunden. Neue feste
29er-Zeitprobe BASE21PASS/8FAIL → Korrektur29PASS/0FAIL. Tatsächlicher
CompleteFlow zeigt nun41.000 und erhält16Gates, Resume, ACK und eineBelohnung.
Die bisherigen21Proben/37Modalchecks bleiben, App ergänzt Prüfung22 und
braucht neueAPK1906. NeueAPK-/Android-Abnahme noch ausstehend;
**VISUAL_GAP / NOT FINISHED**. Main undReleases bleiben unverändert.

Die folgende1905-Übergabe bleibt der vorherige unveränderte Buildnachweis.

# Aktueller integrierter Grafik-/Runtime-Kandidat1905 · 8. Oktober2026

Zuerst [die aktuelle1905-Übergabe](docs/INTEGRATED_GRAPHICS_RUNTIME_1905_2026-10-08.md)
lesen. Aktiver Integrationsbranch/PR29 verbindet die bewiesene37er-Modalfixture
mit selektiven Referenzgrafikverbesserungen aus PR30. ScopedModalrouting,
Fahrphysik, Kamera, Kontakte und vollständige Kontinuität bleiben erhalten.
Die App pinnt den frischen tatsächlichenHEAD fürAPK1905; alte1904-APK-/Android-
Ergebnisse gelten nicht automatisch fürdiesenStand. LokaleskombiniertesGL:
37PASS/sechsDrags/14echtePNG. Vollständige neueAPK/Android-Abnahmeausstehend.
**VISUAL_GAP / NOT FINISHED**. Main undReleases bleiben unverändert.

Die folgendenÜbergaben sindhistorisch; ihreSHAs/Testzahlen ersetzen keinen
frischenHEAD-/Pin-/APK-Provenienznachweis.

# Aktuelle Fortsetzung: Kart-Modal-Touch · 8. Oktober 2026

Zuerst [das neue geprüfte Modal-Touch-Paket](docs/MODAL_TOUCH_2026-10-08.md)
lesen. Aktiver Integrationsbranch/PR29 baut auf Godot18238d48 auf; App-PR216
bereitet den exakten neuen Pin und APK1904 vor. Die tatsächlich gebaute1903
ist byteweise geprüft, aber beide vollständigen Android-Kartläufe bleiben FAIL.
Die neue native Touch-Regressionsprobe besteht 35 Prüfungen/sechs Drags/14 PNGs;
derselbe Test reproduziert auf unverändertem BASE den echten Scrollfehler.
Neue Android-/APK-Abnahme separat am aktuellen Lauf belegen.
**VISUAL_GAP / NOT FINISHED**; keine Referenzgleichheit oder Geräte-FPS behaupten.

Die folgende ältere Übergabe bleibt Kontext; ihre SHAs und Integrationsschritte
sind keine aktuellen Heads.

## Direkte Übergabe an Claude Opus 5.5 · 8. Oktober 2026

Lies zuerst [die vollständige aktuelle Übergabe](docs/HANDOFF_CODEX_TO_OPUS_2026-10-08.md).
Sie enthält Änderungen an App, Lumo, Karts, Steuerung, Kamera und allen zwölf
Rennwelten, echte Prüfbelege, laufende Builds und konkrete nächste Arbeitsschritte.

## Aktuelle Koordination

- App: Referenz-/Kamerastand PR 214 auf `codex/lumo-reference-app-2026-10-08`
  und zusätzliche Runtimearbeit PR 215 auf `codex/lumo-runtime-apk-2026-10-08`.
- Godot: Referenz-/Kamerastand PR 27 auf `codex/lumo-reference-design-2026-10-08`
  und zusätzliche Speicher-/Kontaktarbeit PR 28 auf `codex/lumo-race-continuity-2026-10-08`.
- Die Paare sind noch nicht vollständig integriert. Frische Heads, Claims und
  deren Übergaben lesen. Meine letzte Kamerakorrektur in `30dc99b` / App `84ce0e3`
  mit der zusätzlichen Runtimearbeit verbinden; keinen fremden Pin überschreiben.
- APK `0.12.0+1900` hat alle sieben Jobs in Actions 37784807913 bestanden.
  Sie enthält die letzte Kamerakorrektur noch nicht. Neue 1901-Kandidaten sind
  separat zu prüfen; ein späterer kombinierter Build sollte mindestens 1902 sein.
- Referenzgleiche Produktionsmodelle, Tonabnahme, physisches Fold und belastbare
  60 FPS bleiben offen. Echte Screenshots und Clips statt Konzeptbilder als
  Runtime-Beleg liefern. Rennen enthalten keine Lernfragen/Antwort-Turbos.

Der vollständige Produktauftrag `docs/OPUS_ENTWICKLUNGSAUFTRAG.md` liegt in der
Lern-App; seine historischen Basis-SHAs nicht als heutige Heads übernehmen.
Die [alte Startanweisung](docs/OPUS_NEXT_ARCHIV_2026-10-07.md) bleibt als Archiv.
Diese Übergabe startet keine weitere KI-Sitzung automatisch.
