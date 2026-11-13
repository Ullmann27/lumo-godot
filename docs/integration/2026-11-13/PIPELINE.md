# LUMO: aktiver Native-Integrationspunkt

Dieses Team übernimmt ausschließlich bestehende fertige Entwicklungen und repariert konkrete Anschlüsse. Der Besitzer hat geplante Aufgaben ausdrücklich abgelehnt; die Zusammenarbeit läuft nur in der aktiven Sitzung. Die irrtümlich angelegte Folgeprüfung ist deaktiviert.

Gemeinsamer Ablauf und Quellenwarteschlange: [Flutter PR #465](https://github.com/Ullmann27/lumo-lernen/pull/465) und `docs/integration/2026-11-13/PIPELINE.md` auf dessen Integrationszweig `integration/lumo-connections-20261113`. Native-Basis bleibt `ada5ed81ad62339f15289da62670c0a4f9f7f2b9`; dieser Dokumentationscheckpoint verändert keine Produktdatei oder bestehende Bildfreigabe.

Die tatsächliche Altzweigprüfung steht in `godot_inventory.md`. 30 ältere/relevante PR-Heads wurden verglichen; 17 sind vollständige Vorfahren, weitere Gameplay-Teile bereits selektiv verbunden. Ein noch offener alter PR allein rechtfertigt keinen Rückimport.

Neue Studio-Nativebeiträge müssen mit der Host-Lieferung gemeinsam geprüft werden. Host-Checkpoint `a8e09123805b2bf30706c8dd1914b928ae6b24ca` benötigt die neue `equal_sharing`-Route. Der bisherige Native-Pin implementiert diese Route noch nicht. Eine neue Native-SHA wird erst nach Prüfung von tatsächlichen Renderer-/Gameplaybelegen und Host-Vertrag angeschlossen; bestehende Belege dürfen nicht umetikettiert werden.

Studio und Grafik entwickeln auf ihren eigenen Zweigen weiter. Fertige SHAs, Dateiumfang und ausgeführte Prüfungen werden über die jeweiligen PRs und den verlinkten Sammelpunkt übergeben. Fremde uncommittete Arbeitsbäume, laufende APK-Abnahmen und Main werden nicht verändert. Jeder neue Checkpoint ist von einer tatsächlichen Produkt-, Android- oder Geräteabnahme zu unterscheiden.
