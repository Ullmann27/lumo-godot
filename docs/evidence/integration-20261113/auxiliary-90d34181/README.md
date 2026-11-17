# Native 90d34181: dreizehn zusätzliche CI-Läufe

Exakte veröffentlichte Quelle: `90d34181409c15d1b1ad3a6a9643539453155c1d`,
Tree `9b407d61633a6421dc47b6858e6a6fb3fa60bea5`, PR160, Versuch1.
Raw-Ref, PR, Commit, vollständige Run-/Job-/Stepdaten und alle vierzehn
Originaljoblogs sind unverändert gesichert. Nextgen43483977169 und
Graphics43483977529 gehören ausdrücklich nicht zu dieser Abnahme.

## Ergebnis und konkrete Einschränkung

Alle dreizehn GitHub-Workflows und vierzehn Jobs endeten mit `success`.
Die 158 Originalsteps enthalten 156 Erfolge und zwei erwartete gegenseitige
Matrix-Skips im getrennten Bauwelt-/Precision-Workflow.

**Das ist keine vollständige fachliche Abnahme.** Der Kart-Geometriejob
`132087436119` in Run `43483977367` enthält tatsächliche Parse-/Compilefehler,
obwohl außerdem sein bisheriger Erfolgstext ausgegeben wurde und GitHub den
Job erfolgreich markiert. Der Fachnachweis ist deshalb ungültig.

Das vollständige Log steht in `job-132087436119.log.gz`. Seine dekomprimierten
20.329 Originalbytes haben SHA256
`1732e99646acb4cf6b18dcb7e9a1408843425474b36109e3ad3badb60c70192e`.
Die unveränderten API-Jobdaten stehen in `jobs-43483977367.json.gz`.

## Belegte Ursache

Der Job checkt tatsächlich den PR-Mergecommit
`40ae7b7d0768a30e9c4ae76c1c3c55901d29dfab` aus. Das originale Git-Commit-JSON
belegt denselben Tree `9b407d61633a6421dc47b6858e6a6fb3fa60bea5` wie der
veröffentlichte Head. Der Checkout deaktiviert Sparse-Checkout ausdrücklich.

Die beiden gemeldeten Posequellen sind im vollständigen Tree vorhanden:

- `lumo_platform_pose.gd`: Blob `f2085dc82b9840077e631f586a4f4fb5159d7c08`;
- `lumo_teacher_pose.gd`: Blob `5d3a1ae763e84cb09276cafe9ba5f9541bf49447`.

Erst die anschließend manuell erzeugte kleine `kart-check`-Fixture lässt diese
Dateien aus. Die Platform-Pose benötigt zusätzlich die ebenfalls vorhandene
`lumo_body_space_pose.gd`, Blob `2b0c2f5b379535cbc4e54c9c1badca72c0f1bc19`.

Die Fehlerprüfung steht als negiertes `! grep` innerhalb des Shellblocks.
Darauf folgt noch die positive Suche nach dem Geometry-Erfolgstext. Der
negative Fund beendet den Block nicht; die letzte positive Suche ergibt Exit0.
Diese konkrete Reihenfolge verdeckt die echten Fehler. Daraus wird keine
pauschale Aussage über andere Workflows mit negierten Bedingungen abgeleitet.

Der bestehende Workflowblob ist
`f7313f0d6506deaa0d7ed546099209ea05b21d00`. Die gesicherte Quelle und der
vorhandene strenge ProbeRunner stehen neben den Originallogs. Eine Reparatur
wird in einer separaten Arbeitskopie vorbereitet; sie verändert diesen
Originalrun, dessen Quelle oder sein Ergebnis nicht.

## Andere aktuelle Befunde

Die übrigen dreizehn Joblogs enthalten keine tatsächliche SCRIPT-ERROR-,
ERROR:- oder ObjectDB-Exitfehlerzeile. Ihre Originalmarker und vollständigen
Stepzustände stehen in `verification-summary.json`; bloß im Shellskript
gedruckte Marker werden nicht als tatsächlich ausgeführte Prüfergebnisse gezählt.
Die beiden abschließend geprüften Stage2-/Stuntläufe sind erfolgreich beendet.

Die aktuelle direkte Bauwelt-QA meldet tatsächlich VillageEconomy337,
VillageScene222 und BuildNextgen71. Die separate Lifecycle-Probe bestätigt
JSON-Reload sowie vier echte 1280×720-Aufnahmen. Das sind aktuelle
90d-/treegleiche Merge-Ergebnisse, keine umetikettierten cce-Nachweise und
keine zusätzliche manuelle Bildsichtung.

## Korrektur des früheren cce-Handoffs

`historical-cce/` enthält den nachträglich gelesenen unveränderten Originaljob
`132054800257` aus Run `43474541227` sowie dessen bereits gesicherte
Jobmetadaten. Sein wirklicher PR-Mergecheckout ist
`dd021859aece3c79bf2e79cd701e3687863003c6`, Tree
`8409dc27958dc102d7fc84b413f28642782668aa`, treegleich zu cce.

**Derselbe Parse-/Compilefehler und derselbe positive Text stehen schon in
diesem historischen Original.** Der Workflow ist bytegleich zum aktuellen
90d-Workflow. Der frühere Bericht beweist dreizehn GitHub-SUCCESS-Zustände;
ein sauberer Kart-Geometrie-Fachpass lässt sich daraus nicht ableiten.

Der damalige Originalpack bleibt unverändert, Manifest-SHA256
`59ae219c6da3f2ad3a81ddf4edb9012fbab4932b1798b50f4c612759f0f39157`.
`historical-cce/correction.json` hält diese gezielte fachliche Korrektur fest.
Es wurde kein historischer Lauf wiederholt und kein historisches Ergebnis
oder Originalprotokoll nachträglich geändert.

## Speicherung

Alle `.gz`-Dateien sind verlustfrei mit festem gzip-Zeitstempel komprimiert.
Das Manifest bindet sowohl gespeicherte als auch dekomprimierte Originalbytes.
Die JSON-Zusammenfassung ist eine gesonderte Analyse; sie ersetzt keine
Originalantwort und unterscheidet GitHub-Erfolg ausdrücklich vom ungültigen
fachlichen Geometrienachweis.
