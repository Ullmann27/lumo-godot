# LUMO IMPLEMENTATION INTAKE – Puzzle

Status: IN_ARBEIT / NOT FINISHED. Keine Freischaltung, keine APK, kein Geräte-FPS-Nachweis.

## Gesicherte Ausgangspunkte

- Flutter main: `90c239898c2f5fe7230dda05cb9e499069162208`.
- Godot main: `ee4d932e59cf304c3ff249631a1f8133dbba2079`.
- Godot BASE: PR #18, `89325ecf80106a02d4c74a33ccd704e5240ff3d6`.
- Eigener Branch: `chatgpt/puzzle-3d-core-2026-10-07`.
- Eigener Claim: lumo-lernen #170, Kommentar `6034452881`.
- Keine AGENTS.md im vollständig gelesenen Git-Baum. CODEX_START, CLAUDE,
  Agent-Lanes, #170/#6-Claims und offene PRs gelesen.
- Aktive Flutter-Eltern-/Spielewelt-Politur, Integration, Cards und Kart #21
  werden nicht verändert. Ausschließlich neue Puzzle-Pfade.

## Referenzen tatsächlich angesehen

Kanonisch: `Ullmann27/lumo-lernen@90c2398`,
`docs/lumo_game_specs/2026-10-05/04_puzzle/`.
Originalkopien in `references/` sind unverändert, keine Runtime-Kulissen:

| Datei | SHA-256 |
| --- | --- |
| puzzle_board.webp | cdd24b96b07dbaa2909704ba06531ceb46fe58fd6f48d2909c080f2b305b49d3 |
| puzzle_key_art.webp | 5ec855d118eb77e8f984f641d9c51b1b54081d53d2c2433a3fe8ded7208090da |

## Spielstatus / Reihenfolge

Memory und Cards existieren in Flutter; Jump & Run und Kart haben vorhandene
Godot-Szenen. Keine Fertig-Abnahme dieser anderen Spiele in dieser Sitzung.
Puzzle, Rhythm Party, Schatzsuche und Bauwelt sind laut aktuellem Nutzerauftrag
in Flutter gesperrt. Der gelesene Godot-Quellbaum enthält keine Puzzle-Runtime.
Begonnen wird nur Puzzle; die übrigen gesperrten Spiele folgen nach diesem
Kernablauf, ohne dekorative Kachel-Freischaltung.

## Top-10-Lücken vor Implementierung

1. Kein produktionsfähiges geriggtes Lumo-GLB, Skeleton oder Skinned Mesh.
2. Kein Puzzle-Kernablauf oder einzelne räumliche Puzzleteile.
3. Keine Touch-Drag-/Hover-/Snap-Regression für Puzzle.
4. Keine Schwierigkeiten 12/24/48/96. Die Tafel hat vier, nicht drei Stufen.
5. Keine Hint-/Ergebnis-/Sternenbehandlung für Puzzle.
6. Keine profilgebundene Runden-Wiederaufnahme nach Prozessende.
7. Keine ausreichenden separaten Motivtexturen. Kleine Board-Thumbnails
   sind zu niedrig aufgelöst, um als saubere Spieltexturen zu gelten.
8. Keine vollständige räumliche Mondlicht-Schloss-/Wasserfall-Szene.
9. Keine Kandidaten-Runtime-Bilder neben exakten Referenzen.
10. Keine physische Android-Mobile/Compatibility-, Temperatur- oder Fold-Messung.

## Verbindliche Gates

`BLOCKED_3D_ASSET / BLOCKED_3D_CHARACTER_ASSET`: benötigt wird der orange Fuchs
aus Puzzle-Board/Key Art mit weißer Schnauze/Brust/Schwanzspitze, großen braunen
Augen, cyan Halstuch mit Stern und dunklem Schulterrucksack. glTF 2.0/GLB,
eingebettete Materialien, Skeleton + Skinned Mesh; Clips idle, blink, look,
puzzle_pick, puzzle_place, point, celebrate; Schwanz-/Ohren-/Halstuchbewegung,
saubere Übergänge. Keine Fremdmarke, keine Sprite- oder Primitiv-Fuchs-Freigabe.

Godot und Rigging-Tools waren zu Sitzungsbeginn nicht installiert. Eine
verifizierte Godot-4.6.3-Installation wird vorbereitet. Kein vorhandenes
Modellierungs-/Rigging-Werkzeug oder fertiges Charaktermodell wird behauptet.

Neue Puzzle-Rundensnapshots sind kein zweites Wallet-/Unlock-System. Sterne
bleiben vor dem Host-/Profil-Handoff ein lokales Rundenergebnis; sie werden
nicht eigenmächtig der Flutter-Wallet gutgeschrieben. Kachel bleibt gesperrt.

Android-Geräte-Framezeiten, Mobile-vs-Compatibility auf demselben Gerät,
Fold-Wechsel, thermische Anpassung und installierter App-Icon-Test:
NOT EXECUTED in dieser Runde. Keine 60-FPS- oder APK-Aussage.
