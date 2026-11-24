# Nativer Mustervertrag v1

Dieser begrenzte Fachzustand erweitert `scripts/learning/learning_activity.gd`.
Die Szene und ihre Darstellung gehören zur getrennten Chat-3-Integration.
Der Zustand schreibt keine Sterne, Aufgabenresultate, Profile oder Lernstände.
Eine richtige Bestätigung beendet nur die lokale Erklärung; die Flutter-Aufgabe
bleibt Antwort- und Bewertungsautorität.

## Payload

```json
{
  "kind": "pattern",
  "sequence": ["Kreis", "Dreieck", "Kreis", "Dreieck", "Kreis"],
  "choices": ["Dreieck", "Stern", "Kreis"],
  "period": 2
}
```

- `sequence`: 4–12 sichtbare Token-Strings.
- `choices`: 2–6 eindeutige Token-Strings.
- Tokens: 1–24 Unicode-Codepoints, keine führenden/nachfolgenden Leerzeichen,
  keine C0-/C1-Steuerzeichen und keine Zeilen-/Absatzseparatoren U+2028/U+2029.
  Es findet keine stillschweigende Kürzung, Konvertierung oder Normalisierung statt.
- `period`: ganzzahlig 1–4, exakt die kleinste nachweisbare Wiederholungsgruppe.
  Zwei vollständige Gruppen müssen sichtbar sein; ein zusätzlicher Gruppenanfang
  ist erlaubt. `A B A B A` hat Periode 2 und setzt mit `B` fort.
- Das nächste Token `sequence[sequence.length % period]` muss in `choices`
  enthalten sein. Dart prüft dieses Ergebnis zusätzlich gegen die vorhandene
  korrekte Antwort der tatsächlichen Aufgabe.
- Unbekannte, nichtperiodische oder unzureichend belegte Folgen werden abgelehnt;
  es wird keine beliebige Regel oder Ersatzaufgabe erfunden.

## Öffentliche Schnittstelle

| Element | Bedeutung |
|---|---|
| `pattern_sequence`, `pattern_choices`, `pattern_period` | geprüfte aktuelle Darstellung; vom Consumer nur lesen |
| `pattern_candidate` | gewählter Index, anfangs `-1` |
| `pattern_attempts` | lokale ausdrückliche Bestätigungen, keine Aufgabenwertung |
| `pattern_hint_level` | 0–3, vor und nach einer falschen Antwort nutzbar |
| `pattern_complete` / `is_complete()` | nur bestätigter lokaler Erfolg |
| `pattern_group()` | Kopie der kleinsten Gruppe für die Hervorhebung |
| `select_pattern_candidate(index)` | Auswahl/Vorschlag ohne Prüfung; ungültige Indizes verändern nichts |
| `confirm_pattern_candidate()` | nur neue Bestätigung prüft deterministisch; gibt bei neuem Erfolg `true` zurück |
| `clear_pattern_candidate()` | verwirft den unbestätigten/fehlgeschlagenen Vorschlag bei Stopp |
| `pattern_hint()` | erhöht bis Stufe 3 und gibt den Hinweistext zurück; wählt/bestätigt keine Antwort |
| `explanation()` | aktueller Hinweis, Vorschlag oder Rückmeldung als lesbarer Text |
| `reset()` | gleiche Frage, alle Vorschläge/Versuche/Hinweise zurückgesetzt |

Doppelte Bestätigung ohne geänderte Auswahl gibt `false` zurück und erzeugt
keinen weiteren Versuch. Erneutes Auswählen desselben Vorschlags öffnet eine
bereits erfolgte Bestätigung nicht erneut. Nach Korrektur zu einem anderen
Vorschlag kann ausdrücklich erneut geprüft werden. `place()` ist für Muster
gesperrt. `token_count()` liefert die Auswahlanzahl; `goal_count()` ist 1.

Bei einer neuen Konfiguration werden Definition und Vorschlag atomar ersetzt.
Eine fehlerhafte Konfiguration lässt `kind=invalid` und leere Musterfelder
zurück. Quellen-Arrays und die von `pattern_group()` gelieferte Gruppe können
den behaltenen Fachzustand nicht indirekt verändern.

## Darstellung und Integration

Chat 3 registriert jedes tatsächlich dargestellte Folgenglied als
`pattern_item_00`, `pattern_item_01` usw. Hinweise heben zuerst die kleinste
Gruppe, danach die erste und zweite Gruppe und schließlich die entsprechende
Gruppenposition hervor. Die Antwort bleibt eine ausdrückliche Kindhandlung.
Der neue gemeinsame Umschlag `lumo.learning.interaction` v1 bleibt der äußere
Besitzer-/Abbruchvertrag. Dieses Fachmodell führt keine zweite Sitzungshoheit ein.

## Gezielte Prüfung

`scripts/tests/learning_pattern_regression.gd` prüft die produktive Fachlogik
mit nativen JSON-Zahlen, allen binären Folgen von 4 bis 12 Zeichen und allen
deklarierten Perioden 1–4 gegen eine unabhängige Wiederholungs-Konstruktion.
Hinweise, unbestätigte Korrektur, Fehlantwort, Doppelcallback, Stopp, Neustart,
Aufgabenwechsel, Unicode und fehlerhafte Payloads sind eigene Verhaltensfälle.
Diese Headless-Prüfung belegt keine Android-Ausführung oder visuelle Abnahme.
