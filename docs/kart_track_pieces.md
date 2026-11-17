# Lumo Kart – Strecken-Bauteile (Schnittstelle)

Stand: 17.11.2026, Branch `lumo-2040/kart-20261117` (Draft-PR #196). Zuständig: Kart-Strang „Bauteile“.
Streckenführung, Dramaturgie, Deko, Licht und Menü liegen bei `lumo-kart/menu-strecken-20261117`;
dieser Branch setzt nur **Marker-Knoten**. Die Bauteile hier erzeugen Geometrie, Kontakt und Warnsignale.

Statusspalte: **fertig** = im Branch, getestet; **in Arbeit** = Schnittstelle fest, Implementierung folgt in diesem PR.

## 1. Grundprinzip: alles in Streckenmetern

Jedes Bauteil wird über die Mittellinie der Straße platziert, nie über freie Weltkoordinaten:

| Größe | Bedeutung | Quelle |
|---|---|---|
| `distance` | Streckenmeter (0 … `world.length`) des Bauteil-Anfangs | Marker |
| `lane` | Spurversatz in m, + = rechts in Fahrtrichtung, 0 = Mitte | Marker |
| Breite | `world.road_width` (Standard 10,8 m), Leitplanke bei ±`world.RAIL_LATERAL` (6,05 m) | Welt |
| Banking | `world.frame(distance)` (Rollwinkel bis ±0,14 rad), wird übernommen | Welt |
| Lage | `world.position_at(distance, lane)` | Welt |

Damit sitzen Anschlüsse exakt auf der Fahrbahn: Am Ein- und Ausgang ist jeder Vertex der Bauteil-Fahrfläche
der Straßenpunkt mit gleichem Spurversatz, angehoben um `DECK_LIFT` = 0,012 m (kein Z-Fighting, keine sichtbare Stufe).

**Ein-/Ausgangs-Transform** eines Bauteils = `world.reset_transform(distance, lane)` am Eingang bzw.
`world.reset_transform(distance + länge, exit_lane)` am Ausgang (Basis = Straßenrahmen inkl. Banking).

## 2. Platzierung per Marker-Knoten

Namenskonvention: **`PieceMarker_<typ>_<n>`** (`<n>` ab 1, je Typ fortlaufend), Kinder eines `Node3D`
namens `TrackPieceMarkers` unter der Kart-Welt (`KartWorld`). Die Transform des Markers ist nur Orientierung
für Editor und Review; maßgeblich sind die Metadaten:

| Meta-Key | Typ | Pflicht | Bedeutung |
|---|---|---|---|
| `piece_distance` | float | ja | Streckenmeter des Bauteil-Anfangs |
| `piece_lane` | float | nein (0) | Spurversatz |
| `piece_params` | Dictionary | nein | typ-spezifische Parameter (unten) |

Gleichwertig ohne Knoten: `world.set_meta("track_piece_markers", [{"type": "...", "distance": ..., "lane": ..., "params": {...}}])`.

Der Einbau prüft Überlappung mit Start/Ziel, Tunneln, Loop und anderen Bauteilen (dieselben Sperrzonen wie
`kart_action_course.gd`, `CLEARANCE` 14 m) und überspringt kollidierende Marker mit einer Warnung im Log.

## 3. Bauteile

### 3.1 `loop` – befahrbarer 360°-Looping (**fertig**)
Skript: `scripts/games/kart_physical_loop.gd` (Kontakt + Geometrie aus derselben Kurve).

| Parameter (`world.loop_layout` / `piece_params`) | Standard | Bedeutung |
|---|---|---|
| `start` / `piece_distance` | – | Streckenmeter der Einfahrtslippe |
| `lane` | – | Einfahrtsspur |
| `exit_shift` | 0,0 | Spurversatz Einfahrt → Ausfahrt. Muss ≥ 2·`deck_half_width` + 0,3 sein, sonst kreuzen sich auf- und absteigende Bahn |
| `deck_half_width` | 1,2 | halbe Fahrflächenbreite |
| `radius` | 6,5 | Loop-Radius |
| `lateral_limit` | 0,7 | Lenkspielraum im Loop (wird weich eingeregelt, kein Sprung) |
| `lane_tolerance` | 0,9 | max. Abstand zur Einfahrtsspur für die Einfahrt |
| `min_entry_speed` | 16 | darunter keine Einfahrt |
| `fail_lane` | `lane` | Rückfallspur bei zu wenig Schwung |

Geometrie: `LOOP.build_track(world, layout, style)` → `{deck, walls, spine}` (3 Meshes = 3 Draw Calls).
Vor der Einfahrt und hinter der Ausfahrt liegt je eine 6-m-Anschlussplatte (`APRON_M`) bündig auf der Straße,
die Seitenwände wachsen darauf aus 0 m Höhe heraus. Material: Shader `kart_stunt_loop.gdshader`,
`style`-Keys `deck_color`, `chevron_color`, `edge_color`, `wall_color`, `wall_glow`, `spine_color`, `chevron_spacing`.
Ausfahrtsspur: `LOOP.exit_lane(layout)`. Messwerte: `LOOP.deck_rows(world, layout)`.

Beispiel (Erweiterungsstrecken, rechte Straßenhälfte, Einfahrt außen, Ausfahrt innen):
```gdscript
world.loop_layout = {"start": world.length * 0.72, "lane": 4.0, "exit_shift": -2.75,
	"deck_half_width": 1.2, "lateral_limit": 0.3, "lane_tolerance": 1.3}
```

### 3.2 `gap_ramp` – Rampe über eine echte Lücke (**in Arbeit**)
Parameter: `ramp_length` (m), `height` (m), `gap_length` (m), `landing_length` (m), `half_width` (m, ≤ halbe Straßenbreite).
Anschluss: Rampenfuß bündig (`DECK_LIFT`), Landezone mit grünem Start- und orangem Endbalken, Warnschild 40 m davor.
Flugmodell: `kart_precision_jump.gd` (gleiche Zahlen für Hinweis und Flug), Wolkenrettung bei Absturz.

### 3.3 `narrow` – Engstelle mit Warnmarkierung (**in Arbeit**)
Parameter: `length` (m), `open_width` (m, ≥ 5,0 für Kinder), `side` (−1 links, +1 rechts, 0 beidseitig).
Gelb-schwarze Schraffur am Einzug, Leuchtpfeile, Warnschild 30 m davor.

### 3.4 `roller` – rollende Hindernisse (**in Arbeit**)
Parameter: `count`, `period` (s), `amplitude` (m quer zur Fahrbahn), `theme` (Kugel/Fass/Schneeball).
Deterministisch über die Rennzeit (Speicherstände bleiben gültig), Treffer = kurzes Abbremsen, kein Ausscheiden.

### 3.5 `hazard_zone` – Lava- bzw. Eiszone (**in Arbeit**)
Parameter: `length` (m), `lane`, `width` (m), `kind` = `lava` (Tempo-Bremse, Glut-Rand) | `ice` (weniger Grip).
Farbiger Rand + Schild davor; nie über die volle Breite (es bleibt immer eine sichere Spur).

## 4. Nachweis
- `scripts/tests/kart_loop_seam_regression.gd`: misst Spalt, Versatz, Knick, Banking, Breite, Reihen-Schritt und
  Abstand auf-/absteigende Bahn an allen Loops (Sonnenhafen, Candy Cloud, Vulkannacht, Galaxie-Ring).
- `scripts/tests/kart_track_seam_capture.gd`: echte OpenGL-Nahaufnahmen aller Übergänge (`LUMO_CAPTURE_DIR`).
