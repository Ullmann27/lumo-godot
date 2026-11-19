# Zweig-Inventur Godot – 19.11.2026

Grundlage: gemeinsame Linie `origin/repair/lumo-quiz-run-kart-20261119` (`1c9211e`).
Arbeitszweig: `agent/inventur-godot`. Stand: **in Arbeit** (wird laufend fortgeschrieben).

Verfahren: Für jeden der 117 Zweige mit Inhaltsrest (aus `godot_inhalt.tsv`) wird jede
Datei, die der Zweig seit seiner Abzweigung von der Linie geändert hat, mit der Linie
verglichen:
- **gleich**: Linie hat denselben Inhalt.
- **überholt (Fassung auf Linie gewesen)**: genau dieser Dateiinhalt (Blob) kam in der
  Geschichte der Linie vor und wurde dort später weiterentwickelt oder bewusst entfernt.
- **neu**: dieser Inhalt war nie auf der Linie → Einzelprüfung.

(Tabellen folgen.)
