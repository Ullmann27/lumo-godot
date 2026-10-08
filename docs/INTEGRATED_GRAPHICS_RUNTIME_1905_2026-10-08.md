# Integrierte Grafik und Runtime1905 · 8. Oktober2026

Status: **VISUAL_GAP / NOT FINISHED**. Dieses kleine Anschluss-Paket ist nativ
geprüft; die neue exakte Android-APK und ihre API35/36-Prüfungen sind noch offen.
Main und Releases bleiben unverändert.

## Exakte Quellen und erhaltene Arbeit

- Produkt-BASE: `6873c0723d6e6c0587cdf06d990cb6c49502a33a`.
- Separat veröffentlichte Fixture-Reparatur:
  `35cc13765e88aa47285a4c081a4e6144d37c8d51`, Tree
  `79f9ab4c88d4543415e2b74330e1c3dedbd8eb05`.
- Selektiv verwendeter eigener Grafikstand aus PR30:
  `7ded3f51cffc265e790d4f1a4c2e91e6d38407eb`.
- Aktiver RESULT: frischer HEAD von
  `codex/lumo-integrated-runtime-2026-10-08` / PR29; die App pinnt anschließend
  genau diesen Commit in `config/godot-source.json` für1905.
- Native Laufzeit: offizielle Godot4.6.3 `7d41c59c4`, echtes X11/Mesa
  OpenGLCompatibility; DummyAudio. Android nutzt den vorhandenen expliziten
  Compatibility-Start der eingebetteten Activity.

Lenkrad-/Ärmelkontakt, vorhandene Fahrphysik, Kontinuität von Items/Gegnern,
Checkpoints, Respawn, Kamera und Saveformat bleiben erhalten. Das bestehende
Modalrouting bleibt auf direkte Buttons des scrollbaren Inhalts begrenzt;
feste Footer und andere Buttons behalten ihre bisherigen Filter. Die engere
76-Zeilen-Pausenprobe und das globale PASS-Routing von PR30 ersetzen diese
Architektur und den vollständigen Modalvertrag nicht.

## Sichtbare Anpassung

Acht Grafikdateien aus dem geprüften PR30 werden mit ihren Abhängigkeiten
übernommen: kontinuierliche orange/weiße Schwanzoberfläche, feinere
Fellsträhnen, braune radiale Iris und Kopf-/Ohrenpigmentierung; kompakte
Comet-Heckeinheit mit eingelassenen Boostöffnungen, Cyanleuchten/Felgenringen,
Hauben-L und dunklerem Lack/Speichen; gemeinsam genutzte mipgemappte
Terrainkörnung. Andere Welten behalten ihre Identität. Es wird kein fremdes
Modell, Shadercode, Markencharakter oder Spielwelt kopiert.

Die Farbmengenprobe zählt jedes gepackte Vertex genau einmal. Positions-,
Dreiecks-, Farbtoleranz-, Normalen-, Kontakt- und Materialbudget-Grenzen bleiben.
Der alte Matcher bestand in unserer Headless-Variante ebenfalls; daraus wird
kein erfundener BASE-RED abgeleitet. Das beobachtete neue Rendering und der
strengere Mengenvergleich sind getrennte Nachweise.

## Tatsächlich ausgeführte Prüfungen

- Original553-Zeilen-Modalprobe auf unverändertem6873 mit öffentlich
  gespeichertem manuellem Gas: strikt RED,26PASS/1FAIL. Blindes Umschalten
  aktiviert Auto-Gas, blendet GAS aus und verursacht den bekannten CI-Fail.
- Reparierte Fixture wählt den nötigen Modus aus der sichtbaren Gas-Beschriftung
  mit realen Taps. Alle35 ursprünglichen Anforderungen bleiben plus zwei
  Modus-Vorbedingungen: gespeichertes false und true jeweils37PASS,
  sechs echte Button-Drags,14PNG, keine Enginefehler/Leaks. Test-SHA256:
  `694dcd935bd7e765d2d4f3726eaf6e48698947bbba8b18395502da5d7486e8e6`.
- Kombinierter Grafikstand: derselbe vollständige echte GL-Test37PASS,
  sechs Drags/14PNG/engine+strikterWrapper Exit0, alle852 Quellfile-Hashes
  vor/nach identisch. Zwei Runden/16Gates, Ergebnis/+3nativeSterne und
  öffentliche neue Garage; native Sterne sind kein Android-Walletnachweis.
- Geometrie/Farben/LOD: alle fünf Fahrer PASS. Fox137768→135744 Nahvertices,
  17284→18038 Fernvertices;61Oberflächen. Neun Fahrzeugdesigns:
  Reifentopologie, Normalen, Kontakt, LOD und Materialgrenzen PASS.
- Projektvalidator117PASS/7bestehendeWARN/0FAIL. GanzeLintbasis404Probleme,
  kombiniert391; keine neuen.46bereits unformatierteDateien bleiben.
  NeuerFinish/Fur/Farbentest und Modalprobe einzeln Lint/FormatPASS.

Zwei lokale Coldimports mit stdout-PIPE stürzten vor der GL-Ausführung ab;
auch unveränderterBASE reproduziertSIGSEGV. DerselbeBASE mit regulärer
Logdatei importiert vollständig, ebenso der kombinierte Stand. Alle Fehlläufe
bleiben erhalten; keine CSV/Assets/Settings wurden entfernt oder Tests
abgeschwächt. Das beobachtete Werkzeugverhalten ist kein Grafik-Produktfehler.

Vier vorbereitende Rohlogs der Fixture haben später jeweils75Bytes Exit-/Cleanup-
Suffix verloren; UrsacheUNKNOWN, ursprüngliche Vollbytes nicht erhalten.
Ihr historischer Byteaudit bleibtFAIL. Beide37er-Kernläufe und der originale
Verhaltens-RED sind bytegleich geprüft, ebenso42PNG. Eine neue versiegelte
Dateiabgabe dokumentiert aktuelleBytes und diese Grenze ausdrücklich.

## APK-/Androidstand und nächste Integration

EigeneApp1be/Godot6873 Actions37833588822:14nativePASS/1ModalFAIL/6SKIPPED,
KEINEAPK, AndroidSKIPPED. Getrennter Grafikstand App4973346/Godot7ded3f5 hat
APK0.12.2+1904 wirklich gebaut:201690522Bytes, SHA256
`68cab1b45a6ea9172c647c56cbf67bd28f647ba815a23ef97b6beb6191de4c25`.
DessenAPI35 hat nach unabhängiger Rohdaten-/Videoauswertung zwei Runden,
Ergebnis, ACK, genau einmal3Sterne/0XP, Offline-Recovery, Replay und sichtbare
Flutter-Rückkehr. SeinAPI36 bleibtFAIL wegen einer zusätzlichen übergroßen
Raw-OCR-Fußzeilenbox. Diese alten Ergebnisse werden nicht auf1905 übertragen.

Die App verbindet den exakten neuenPin mit fail-closed Quellscan, gleicher
begrenzter Root-/Vorlaufidentitätsprüfung, konservativ korrigiertem OCR-Leser
und neuer frischer Flutter-Rückkehrprüfung. Erst danach vollständigen1905-Bau,
APK/PCK/Manifest/Signatur/ABI und alleAndroidjobs separat prüfen.

Offen: referenznahe Gesichts-/Schnauzenform, Stoffwirkung, Garagenbeleuchtung,
Sonnenhafen-Licht/Materialtiefe, Iris-FernLOD, akustische Abnahme und neue Stimme.
PhysischesFold, AndroidOS-Mehrfingerlatenz und ZielgeräteCPU/GPU/p95/Speicher/Soak
sind NOT EXECUTED. Keine60FPS-Zusage. YouTube lieferte bislang keine dekodierten
Referenzframes; Bewegungsparität ist nicht behauptet.

## Quellen und Anpassung

Verbindlich sind Heinz' Originalbilder in der App unter
`docs/design_targets/2026-10-08-kart-fahrzeuge/`. Eigene prozedurale Meshes und
Materiale bleiben die Produktionsarchitektur. OffizielleGodot4.6-Dokumentation:
[ArrayMesh](https://docs.godotengine.org/en/4.6/classes/class_arraymesh.html),
[StandardMaterial3D](https://docs.godotengine.org/en/4.6/classes/class_standardmaterial3d.html),
[ScrollContainer](https://docs.godotengine.org/en/4.6/classes/class_scrollcontainer.html).
ExakteMIT-Enginequelle
[ScrollContainer](https://github.com/godotengine/godot/blob/7d41c59c4/scene/gui/scroll_container.cpp)
und[Viewport](https://github.com/godotengine/godot/blob/7d41c59c4/scene/main/viewport.cpp):
eigenes bestehendesControlrouting; kein externer Implementierungscode übernommen.
