# Treasure- und Dorf-Runtime: enger Anschluss an 504c8ba

## Quellen und Umfang

Basis: `504c8ba70d02702cbccc370d0d96c36a292c5d27`, Tree `05ba53c02321da069007d5c4b045622f06cc9175`. Producer: `785413d395292a243eaa0a0748671eb15d3f80ff` (PR167, unmittelbarer Parent `acf51d3bd2997c4b731e9a48e1791e05e756a132`).

| Zielpfad | Git-Blob | Übernahme |
|---|---|---|
| `scripts/creative/treasure_world.gd` | `aae80484834823c8cf063df6bfb2607313f39ef7` | Exakter veröffentlichter Producer |
| `scripts/tests/treasure_title_contrast_regression.gd` | `73939c37e38bdbaca77220f79227e3dcde26e59c` | Exakter veröffentlichter Producer |
| `docs/studio-2020-visibility-corrections.md` | `2c55747e7fe45dec183b7de6170d020f630462ca` | Unveränderte historische Producer-Beschreibung |
| `scripts/creative/build_settlement_world.gd` | `dd1e7b0662f2d4325a6fa562e3a111ecbb31fd50` | Basisblob `3d41bc4ca305101699c0042c24dbd00dd606dc31` plus genau der Singular-Hunk in `_cost_text` |

Treasure-Produkt SHA256: `e68fc85498b76fb7b482417a1bf6b64410a53d2f018fec7771e263ea60fa5447`. Treasure-Probe SHA256: `ea6087ef56a96d585382f4228661d753121152aa249c4a5afdc99d2e946941ea`. Integrierte Settlement-Datei SHA256: `50938300e4d40c7ded1be66af6384359fc4d9d83fefff52c25ca1670be3661ec`.

Der kurze Querformat-Hinweis öffnet den vollständigen Text im vorhandenen scrollbaren Dialog; Meldungen halten die projizierte Figur und die Steuerflächen frei. Treasure behält 22 vorhandene Funktionen bytegleich; nur `_ui` und `_layout` ändern sich, `_show_clue` kommt hinzu. Settlement behält 49 von 50 Funktionen bytegleich; ausschließlich `_cost_text` beschriftet genau eine Münze im Singular. Die bereits integrierte Ressource Korn, Dorfökonomie, Regeln und Speicherpfade bleiben erhalten. Kein vollständiger Producer-Zweig wurde übernommen.

## Tatsächlich vor dem Umgebungsausfall ausgeführt

Engine: `4.6.3.stable.official.7d41c59c4`, Linux, Headless-Display, Dummy-Audio. Die getrennte Prüfkopie enthielt 1.243 gebundene produktive Assets, Szenen und Skripte des kombinierten Quellenstands. Import und jede Probe nutzten getrennte XDG-Kontexte. Der vollständige Editorimport endete nach 9,149 Sekunden mit Exit 0 und ohne Parse-/Script-/Enginefehler.

Alle folgenden Probes wurden mit dem bestehenden strengen `tools/run_godot_probe.py` seriell ausgeführt. Der Runner verlangt einen sauberen Exit und den spezifischen PASS-Marker und verwirft Engine-/Scriptfehler sowie Timeout.

| Tatsächliche Headless-Probe | Exit | Prüfschritte | Dauer |
|---|---:|---:|---:|
| `treasure_title_contrast_regression` | 0 | 3.341, keine Fehler | 19,547 s |
| `treasure_density_regression` | 0 | 1.085, keine Aufnahmen | 30,612 s |
| `treasure_exploration_regression` | 0 | 87 | 1,869 s |
| `build_settlement_play_regression` | 0 | 127 | 7,492 s |
| `build_village_scene_regression` | 0 | 222 | 5,446 s |

Damit bestanden fünf Probes mit insgesamt 4.862 einzelnen Prüfbedingungen. Dies sind keine 4.862 unabhängigen Spieletests. Die Altstandsfixture `scripts/tests/fixtures/treasure_title_86445.json` ist an Git-Blob `78afb5e77187170a345940059da450eed02530cf` aus 504c8ba gebunden. Der neue Test prüft außerdem echte Frischstarts, jeweils in fünf Formaten.

Eine Byteprüfung nach Import und dem ersten erfolgreichen Probeergebnis bestätigte alle 1.243 Eingangsdateien unverändert, sowohl im Integrationscheckout als auch in der tatsächlich ausgeführten Prüfkopie. Die zusätzliche Schlussprüfung nach allen fünf Probes sowie das abschließend geplante `git diff --check` wurden wegen des Umgebungsausfalls nicht mehr ausgeführt und werden nicht als bestanden behauptet.

## Protokollverfügbarkeit

**Vollständige Logs in ausgefallener Umgebung derzeit nicht abrufbar.** Sie waren vor dem Ausfall unter `/tmp/lumo-integration-909ddb52fe7b/godot-treasure-integration/` gespeichert. Die folgenden Hashes und die obigen Ergebnisse wurden vor dem Ausfall durch abgeschlossene Toolergebnisse bestätigt. Dieses Dokument bewahrt diese beobachteten Angaben, ersetzt jedoch keine erneut herunterladbaren Rohprotokolle.

| Ursprünglicher Log | Vor dem Ausfall ausgegebener SHA256 |
|---|---|
| `treasure_title_contrast_regression.log` | `97e761124ac19f9668b1ce415db837527641549c566f9834303103f16c4a6a8d` |
| `treasure_density_regression.log` | `1df99465018c0758f9c9a9d72ca4b1dc85a7cd2ef7dc901e8c778af25d4b3a2c` |
| `treasure_exploration_regression.log` | `02d20b766c253672fea75aa6cc8744460cb1134dd54beeb4d73fa6b743825b76` |
| `build_settlement_play_regression.log` | `bddad00b5183a4e10a69a2b12daefdf519c1f5daeb65a2912fb181d1f561bf9a` |
| `build_village_scene_regression.log` | `7cb4b2e5392d6965e929e1d2451e5feec14efb263edc7b715ae217a4d2279f36` |

## Weitere gemeinsame Abnahme

Dieser Commit ist ein enger Runtime-Checkpoint. Root ergänzt getrennt den bestehenden 52-Modi-Vertrag um das fünfte Treasure-Bild und die zehn Zustandsbeobachtungen. Die vier alten Dateinamen zeigen weiterhin den Altstand; `treasure-title-landscape-cutout.png` zeigt den Frischstart. Studio2020 verlangt damit 17 Bilder: acht Face, vier C4 und fünf Treasure. Alle bisherigen Face-/Movie-/C4- und Rasterpflichten bleiben erforderlich.

Hier wurden kein neuer Renderer-, Android-, APK-, physischer Geräte- oder FPS-Test und keine neue Bildfreigabe durchgeführt. Die Rendererbefunde im unverändert übernommenen Producer-Dokument bleiben dessen historische Nachweise. Neue gemeinsame Renderer-/Hostläufe und die Prüfung ihrer Originalbilder stehen aus. Main, Release-Pins und fremde Branches bleiben unverändert.
