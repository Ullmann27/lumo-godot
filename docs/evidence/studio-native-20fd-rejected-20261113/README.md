# Native20fd: abgeschlossener, verworfener Gesamtlauf

Run43520242403, Attempt1, Source20fd2880494c10f8f7d3a266956995e97f9011df.

Sechs der acht Pflichtjobs sind erfolgreich. `new-worlds` scheitert an zwei historischen Orchestrierungs-Fixtures; `bundle-evidence` und die zusätzliche Archivierung werden korrekt übersprungen. Die vollständige unveränderte Fehlermeldung steht in `new-worlds-original-job.log`. Kein Retry, kein Produktpatch, keine Branch-/Receipt-/Pinänderung durch diesen Prüfschritt.

Der tatsächlich erfolgreiche Studiojob liefert ein getrenntes Original-Teilarchiv. Dessen48.295.636Bytes stimmen mit dem GitHub-Digest überein; ZIP-CRC,37PNG,3Cards-Rohlayouts und der Mobile-Report mit15Touchflächen wurden geprüft. Die16Studio-Gates sind PASS. Die Bilder wurden von diesem Agenten nicht visuell freigegeben; Root/B erhalten die Originalpfade für eine getrennte technische Sichtung.

Die ursprüngliche ZIP bleibt unter `/workspace/scratch/5987865ae883/qa/studio-20fd-original.zip`. Ausgewählte Originale liegen unter `studio-partial/selected-originals/`; das Inventar bindet jeden PNG-/Sidecarhash und den tatsächlichen Artefaktpfad. Das kuratierte Uploadmanifest enthält bewusst nur Metadaten, Originalfehlerlog, Quellenbindung und Inventar, keine zweite ZIP-Kopie. Ein neuer Native-Commit benötigt neue CI-Belege.
