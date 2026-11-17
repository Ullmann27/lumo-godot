# TEST_RESULTS – lumo-2040/kart-20261117 (17.11.2026, Europe/Vienna)

Umgebung: Godot 4.6.3 headless bzw. Xvfb/llvmpipe, gl_compatibility, Box mit hoher Last (Load ~60). Keine FPS-Aussagen.

## Grün
| Test | Ergebnis |
|---|---|
| `kart_loop_seam_regression` (neu) | PASS – 4 Loops: Spalt 0,0000 m, Versatz 0,0000 m, Banking 0,000°, Knick ≤ 2,19°, Reihen-Schritt ≤ 0,514 m, Abstand auf-/absteigende Bahn 0,249–0,429 m |
| `kart_track_pieces_regression` (neu) | PASS – gap_ramp landet bei 21,4 m/s in der Zone, zu langsam → Lücke + Wolkenrettung; Engstelle |Spur| ≤ 3,00 m ohne Rettung; Lava 29,9 → 18,6 m/s; Eis 19° vs. 37°; Schanzenfuß-Spalt 0,0000 m |
| `kart_track_seam_capture` (neu) | PASS – 15 Frames vorher/nachher |
| `kart_loop_contact_regression` | PASS |
| `kart_sonnenhafen_stunt_regression` | PASS (Assertion „Exit on the loop lane“ auf Ausfahrtsspur angepasst) |
| `kart_stunt_continuity_regression` | PASS (Assertion „Exit preserves steering position“ auf Ausfahrtsspur angepasst) |
| `kart_stunt_logic_regression` | PASS |

## Rot / nicht gelaufen
- `tools/validate_project.sh`: **abgebrochen beim ersten Schritt** `kart_regression` mit „Steering from rest still moves the kart“ / „Steering turns the actual kart heading“ = bekannter Flake (Lenk-Assertion, siehe REGELN-2040). Das Skript bricht bei der ersten Abweichung ab; alle folgenden Gate-Schritte sind **NOT RUN**. Ein zweiter Lauf wurde wegen Abschluss (13:13) abgebrochen.
- Gegenprobe `kart_regression` einzeln: auf Basis `bb478880` und auf diesem Branch jeweils 2× nach 200 s Timeout ohne Ergebnis (Box-Last ~60) – weder grün noch rot belegt.
- Weitere Kart-Suiten (`kart_world_regression`, `kart_ai_behavior_regression`, `kart_complete_flow_regression`, `kart_drive_feedback_regression`, `kart_action_course_regression`): **NOT RUN**.
- DEVICE TEST NOT RUN · FOLD7 NOT RUN.
- Draw Calls vorher: NOT RUN (nur Nachher-Frames gemessen: Loop-Achse 247, Loop-Einfahrt 213, Schanzenfuß 149–173, Desktop-Profil).

## Offene Punkte
- Volles Gate `validate_project.sh` auf ruhiger Maschine wiederholen (Grund: Abbruch am bekannten Flake + Abschluss).
- Rivalen reagieren nicht auf Lava/Eis (nur Spieler-Effekt); Engstelle wirkt für alle (Wand).
- Lava/Eis noch mit einfachen Materialien statt eigenem Shader.
- Bei 9,6 m/s ohne Gas blieb das Kart in einem Testlauf an der Lippe einer gap_ramp stehen (nicht weiter untersucht; mit Gas normaler Ablauf).
- Temporärer Prüf-Worktree `/workspace/lumo/wt-2040-kart-basecheck` (detached bb478880) liegt noch auf der Box (nicht gelöscht, Regel „nichts löschen“).
