# Lumo: gemeinsame Gegenspieler aus Originalreferenzen

Stand: 10. Oktober 2026. Diese vorbereitete Erweiterung ordnet fünf neue Gegnerreferenzen dem vorhandenen Godot-/Flutter-Projekt zu; sie ist keine neue App und keine bereits abgeschlossene 3D-Modellintegration.

## Verbindlicher Umfang

| Identität | Originaldatei | Geometrieeingabe | Materialeingabe |
|---|---|---|---|
| Löwe | `50835.jpeg` | einzelne neutrale Frontansicht | einzelne große Figur |
| Eule | `50839.jpeg` | einzelne neutrale Frontansicht | einzelne große Figur |
| Hase / bestehende Nova-ID | `50838.jpeg` | einzelne neutrale Frontansicht | einzelne große Figur |
| Eichhörnchen | `50837.jpeg` | große Figur mit vollständig sichtbarem Schweif | dieselbe große Figur |
| Schildkröte | `50836.jpeg` | große Figur mit sichtbarem Panzer | dieselbe große Figur |

`49717.jpeg` ist eine zusätzliche Strecken-/Lichtreferenz mit Lumo, kein sechster Gegner. Der vorhandene Meshy-Lumo wird nicht erneut erzeugt; kein vollständiger Kontaktbogen und keine Strecke werden als einzelner Charakter an Image-to-3D übergeben.

Unveränderte Originale und rein zugeschnittene Eingaben liegen unter `assets/characters/rivals/reference/`. Die kleineren neutralen Frontansichten werden nicht als hochauflösende Originale ausgegeben; die großen Ansichten stehen für die Material- und Detailabnahme zur Verfügung.

## Bereits implementierte Technik

- **Ein Gegnerkatalog:** `assets/characters/rivals/roster.json` ist die gemeinsame Identitätsdefinition für Kart, Lumo Cards und Vier gewinnt. Flutter enthält eine bytegleiche Kopie unter `assets/rivals/roster.json`.
- **Godot:** `lumo_opponent_roster.gd` liefert lesegeschützte Definitionen und deterministische, duplikatfreie Rotationen. Das bestehende Rennen verwendet die Referenzgegner nur, wenn alle fünf ausdrücklich als laufzeitbereit markiert sind und ihre Modelle tatsächlich existieren.
- **Bestandsschutz:** Aktuell sind sämtliche Modelle `runtimeReady: false`; die bisherigen fünf Renngegner bleiben aktiv. Ungeprüfte statische Meshes werden nicht als animierte Fahrer ausgegeben.
- **Flutter:** Der lokale Parser und AssetBundle-Lader sind registriert und getestet. Die vorhandenen Karten-/Vier-gewinnt-Regeln, Sprache, Bot-Timer, Spielerkennungen, Lernstände und Belohnungen bleiben unverändert.
- **Keine erfundenen Gegner:** Lernübungen und Spiele ohne vorhandene Gegner bekommen durch diese Erweiterung keine neuen Kampf- oder Konkurrenzfunktionen.
- **Upload-Umweg:** `tools/meshy_file_input_bridge.mjs` übergibt geprüfte echte Bildbytes an das normale Browser-Dateifeld. Der im ersten Lumo-Auftrag nachgewiesene 0-Byte-Transfer wird so vermieden, ohne interne APIs oder Zugangsdaten auszulesen.
- **Wiederverwendeter Lumo:** Unter `existing-lumo/` liegt der bereits erzeugte, geprüfte Original-/30k-Prototyp einschließlich editierbarer Blender-Datei und Lizenzhinweis. Dafür wurde kein neuer Auftrag gestartet; das vorhandene Modell dient als technische Pipeline- und Familienreferenz.
- **APK-Größe:** Die Original-/Eingabereferenzen sind in allen Godot-Exportpresets ausgeschlossen; Quelldateien und Nachweise unter `docs/` bleiben ebenfalls außerhalb der exportierten App.

## Neue Generierung ist noch nicht gestartet

Für diesen neuen Satz wurden noch keine Bilder an Meshy übertragen und keine neuen Meshy-Credits verbraucht. Die bisherige Einzelfreigabe galt ausdrücklich nur dem ersten Lumo-Prototypen; für fünf weitere öffentliche Modelle wird deshalb eine gemeinsame, konkret begrenzte Freigabe eingeholt.

Vorgesehen sind höchstens fünf Meshy-6-Lite-Geometrieaufträge und fünf zugehörige erste Texturierungen. Die Gesamtschranke beträgt höchstens 100 vorhandene Meshy-Credits, sofern die Oberfläche weiterhin höchstens 10 Credits je Teilauftrag verlangt; bei einem höheren Preis wird nicht automatisch fortgefahren.

Es werden kein Abo, keine zusätzlichen Credits, keine Premium-Pose, keine Modellvarianten, kein externes Rigging und keine zusätzlichen Bildgenerierungen gekauft oder gestartet. Free-Modelle unterliegen der vorgesehenen CC-BY-4.0-Lizenz; Meshy-6-Lite-Downloads sind im Free-Tarif enthalten ([Meshy Free Plan](https://help.meshy.ai/en/articles/15696428-what-is-included-on-the-free-plan)).

## Prüfungen und Bildnachweise

Die Gegnerkatalog-Regression prüft 103 Eigenschaften, einschließlich der fünf Identitäten, ihrer Referenzdateien, gemeinsamer Spielzuordnung und deterministischer Rotation. Zusätzlich bestanden vier Flutter-Katalogtests, 37 bestehende Cards-/Vier-gewinnt-Regeltests, zwei Tests des Upload-Umwegs, die gezielte Flutter-Analyse und die bestehende Kart-Physikregression.

`lumo_rival_lineup_capture.gd` rendert die tatsächlich verwendeten Produktfahrzeuge in einer isolierten Godot-Szene. Die Vorher-Aufnahme zeigt die bestehenden Modelle; sie ist weder ein synthetischer Grafikentwurf noch ein Screenshot einer neuen Android-APK.

## Noch notwendige Umsetzung

Nach der Batch-Freigabe folgen die echten Modelle, Downloads und Prüfsummen, lokal abgeleitete LODs und echte Vorher-/Nachher-Aufnahmen. Erst anschließend werden die Fahrer-Sitzpose, Hand-/Lenkradkontakt, Blickrichtung, Kopfbewegung und Renderqualität gegen die jeweiligen Originale überprüft.

Die Kart-Integration muss das bestehende Animation-/Steuerungssystem erhalten. Ein statischer Meshy-Export ohne Rig darf diese Funktionen nicht ersetzen; die Dateiexistenz allein ist keine Abnahme.

Für die 2D-Spiele werden echte gerenderte Ansichten derselben 3D-Modelle als lokale Porträts wiederverwendet. Neue Stimmen, zusätzliche KI-Backends oder neue Verarbeitung von Kinderinhalten sind hierfür nicht erforderlich.
