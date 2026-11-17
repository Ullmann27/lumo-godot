# Lumo Kart – Strecken-Bauteile (Schnittstelle)

Stand: 17.11.2026, Branch `lumo-2040/kart-20261117` (Draft-PR #196). Zuständig: Kart-Strang „Bauteile“.
Streckenführung, Dramaturgie, Deko, Licht und Menü liegen bei `lumo-kart/menu-strecken-20261117`;
dieser Branch setzt nur **Marker-Knoten**. Die Bauteile hier erzeugen Geometrie, Kontakt und Warnsignale.

Statusspalte: **fertig** = im Branch, mit Regressionstest.

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

Skript: `scripts/games/track_pieces/kart_track_pieces.gd` (`TRACK_PIECES` in `kart_world.gd`).
Drei gleichwertige Quellen, in dieser Reihenfolge zusammengeführt:

1. **Marker-Knoten** `PieceMarker_<typ>_<n>` (`<n>` ab 1, je Typ fortlaufend) als Kinder eines `Node3D`
   namens `TrackPieceMarkers` unter der Kart-Welt. `KartWorld.build()` liest sie **vor** dem Neuaufbau
   (`collect_markers`). Die Transform ist nur Orientierung für Editor und Review; maßgeblich sind die Metadaten.
2. Streckendefinition: Key `"track_pieces"` (Array von Dictionaries) im Rückgabewert von `TRACKS.definition(id)`
   – der einfachste Weg für prozedurale Strecken.
3. Welt-Meta `"track_piece_markers"` (gleiches Format), vor `world.build()` gesetzt.

Metadaten der Marker-Knoten:

| Meta-Key | Typ | Pflicht | Bedeutung |
|---|---|---|---|
| `piece_distance` | float | ja | Streckenmeter des Bauteil-Anfangs |
| `piece_lane` | float | nein (0) | Spurversatz |
| `piece_params` | Dictionary | nein | typ-spezifische Parameter (unten) |

Dictionary-Format (Quelle 2 und 3): `{"type": "gap_ramp"|"narrow"|"hazard_zone", "distance": m, "lane": m, "params": {...}}`.

Der Einbau prüft Überlappung mit Start/Ziel, Tunnel, Sprung, Loop, Action-Parcours und anderen Bauteilen
(inkl. 32 m Warnvorlauf) und überspringt kollidierende Marker mit `push_warning("[TrackPieces] …")`.
Freie Stelle finden: `TRACK_PIECES.free_distance(world, wunsch_m, länge_m)` (−1 = kein Platz).
Geplante Bauteile: `TRACK_PIECES.pieces_of(world)` (Welt-Meta `"track_pieces"`).

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

### 3.2 `gap_ramp` – Rampe über eine echte Lücke (**fertig**)
Parameter (Standard): `ramp_length` 12, `height` 2,6, `gap_length` 10, `landing_length` 18, `gravity` 14.
Wird als Präzisions-Schanze in `world.action.kickers` eingetragen (`track_piece: true`): echte Straßenlücke
(`in_gap`), Flug nach `kart_precision_jump.gd` (Tempo-Hinweis = Flug), Landezone mit Markierungen,
Wolkenrettung bei zu kurzem Sprung, Rivalen fliegen `rival_speed` (Mitte der Landezone).
Geometrie: `STUNT.build_precision_ramp` (Deck/Körper/Wände, Fuß bündig +0,02 m). Warnschild „SPRUNG!“ 32 m davor.
Länge inkl. Landezone: `ramp_length + gap_length + landing_length`.

### 3.3 `narrow` – Engstelle mit echten Wänden (**fertig**)
Parameter (Standard): `length` 26, `open_width` 6,0 (Minimum 5,0), `taper` 8 (weicher Einzug, Smoothstep).
Symmetrisch zur Mittellinie: `world.wall_lateral_at()` liefert in der Engstelle `open_width/2`, dadurch gilt die
Wand für Spieler und Rivalen physikalisch. Optik: weiße Blöcke mit roter Leuchtkante, gelb-schwarze Kante,
Boden-Chevrons 18 m davor, Schild „ENGSTELLE – Mitte halten“ 32 m davor.

### 3.4 `hazard_zone` – Lava- bzw. Eiszone (**fertig**)
Parameter (Standard): `length` 36, `width` 4,2 (max. 60 % der Straßenbreite), `kind` = `lava` | `ice`; `lane` vom Marker
(wird so geklemmt, dass die Zone auf der Straße bleibt). Es bleibt immer eine sichere Spur frei.
- `lava`: Tempo wird weich (9 m/s²) auf 62 % des Eintrittstempos begrenzt, nie gestoppt; Schutzschild hebt das auf.
- `ice`: nur 18 % Grip pro Tick, das Kart rutscht weiter. Hinweistext im HUD-Meldungsfeld.
Optik: eigene Fläche (Lava glühend, Eis glänzend), gestreifter Leuchtrand, Schild 32 m davor. Rivalen: unbeeinflusst
(offen, siehe PR).

### 3.5 Sprungschanzen des Action-Parcours (**fertig**, Anschluss-Fix)
`scripts/games/track_pieces/kart_ramp_piece.gd`: `RAMP.build(world, start, length, height, half_width, colors)`
→ ein geschlossener, entlang der Straße (Kurve + Banking) gezogener Keil, 1 Mesh = 1 Draw Call. Profil = Kontaktprofil
`kicker_height()`. Ersetzt die bisherigen 1-m-Box-Stufen in `kart_action_course._build_kicker`.

## 4. Beispiel

```gdscript
# In einer Streckendefinition (kart_tracks.gd / kart_expansion_tracks.gd):
"track_pieces": [
	{"type": "gap_ramp", "distance": 420.0, "params": {"gap_length": 9.0}},
	{"type": "narrow", "distance": 780.0, "params": {"open_width": 6.5}},
	{"type": "hazard_zone", "distance": 1120.0, "lane": 2.6, "params": {"kind": "lava"}},
]
```
Als Knoten (Editor): `KartWorld/TrackPieceMarkers/PieceMarker_hazard_zone_1` mit
`piece_distance = 1120.0`, `piece_lane = 2.6`, `piece_params = {"kind": "ice"}`.

## 5. Nachweis
- `scripts/tests/kart_loop_seam_regression.gd`: misst Spalt, Versatz, Knick, Banking, Breite, Reihen-Schritt und
  Abstand auf-/absteigende Bahn an allen Loops (Sonnenhafen, Candy Cloud, Vulkannacht, Galaxie-Ring).
- `scripts/tests/kart_track_pieces_regression.gd`: echtes Rennen (Zauberwald) mit allen Bauteilen über Marker.
- `scripts/tests/kart_track_seam_capture.gd`: echte OpenGL-Nahaufnahmen aller Übergänge (`LUMO_CAPTURE_DIR`).
