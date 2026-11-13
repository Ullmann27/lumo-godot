# Verlustfreier Transport des ursprünglichen Auxiliary-Checkpoints

`original-evidence.tar.gz` enthält alle 45 ursprünglichen Dateien des fertig
geprüften Checkpoints, einschließlich seines unveränderten Manifests. Die
Originale sind unter ihren relativen Namen im Archiv erhalten. Das separat
versionierte ursprüngliche README und Manifest beschreiben weiterhin diese
entpackten Pfade; `tar -xzf original-evidence.tar.gz -C <leeres-Verzeichnis>`
stellt sie wieder her.

Archiv: 535.888 Bytes, SHA256
`502b63c1aaa7fbc2b780d939dc7143cfcf3cfe0e23d03e92194902d635aaaebc`.
Jedes Archivmitglied wurde nach erneutem Lesen byteweise gegen die ursprüngliche
Datei verglichen. `archive-manifest.json` bindet Namen, Größen und SHA256 aller
Mitglieder. Das ursprüngliche Manifest bleibt
`cb9cd641d54d01f99f64e0ce5c11d195a10b9eeab9f1a0a36a0930106801757c`.

Die Dateien innerhalb des Originalpacks behalten ihre Verlustfrei-gzip-Bindung.
Deren Manifest führt jeweils gespeicherte und unkomprimierte Originalhashes.
Der Container normalisiert keine Protokollzeile und erzeugt keinen zusätzlichen
Test- oder Workflowerfolg. Die beobachteten grünen API-Zustände und der ungültige
Kart-Geometrie-Fachnachweis bleiben ausdrücklich getrennt. Die historische
cce-Korrektur ist enthalten; dessen früherer Pack bleibt unverändert.
