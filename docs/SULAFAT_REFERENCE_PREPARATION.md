# Godot: sichere Sulafat-Referenzvorbereitung

Die aktuelle Kart- und Lernspielentwicklung bleibt erhalten. Die alte
Generation aus [PR 48](https://github.com/Ullmann27/lumo-godot/pull/48)
wird als Werkzeug wiederverwendet, nicht mitsamt dem veralteten Spielstand
auf die App übertragen.

## Änderungen

- Generator übernimmt dasselbe Referenzmodell wie die Original-Stimmprobe:
  `gemini-2.5-pro-preview-tts`, Sulafat, `lumo-sulafat-reference-v1`.
- Gültige WAV-Dateien und kleine Prüfreceipts bleiben in
  `.lumo-voice-staging/` erhalten. Bei einem Abbruch muss nicht wieder von
  Aufnahme 1 begonnen werden.
- Wiederverwendung verlangt identischen Text, Modell, Stimme, Profil und SHA-256.
- Komprimierte, stille, abgeschnittene oder falsch formatierte Daten werden
  nicht als PCM ausgegeben.
- Standardmäßig entsteht nur eine Hörvergleichs-Charge. `--publish` ersetzt
  die vollständige Bank erst nach Prüfung aller 52 Dateien.
- `--credential-proxy` unterstützt den sicheren Computer-Zugang ohne
  Schlüssel in Code oder Prozessargumenten. Ein serverseitiges `GEMINI_API_KEY`
  bleibt ebenfalls möglich; es wird niemals ausgegeben.
- Runtime prüft nicht nur Sulafat und Datei-SHA, sondern auch Referenzmodell
  und Profil. Alte Aufnahmen und anders deklarierte Modelle bleiben gesperrt.

## Offline-Prüfung

```sh
python3 -m unittest discover -s tools/tests -p test_sulafat_generator.py -v
godot --headless --path . --audio-driver Dummy \
  --script scripts/tests/lumo_voice_reference_regression.gd
```

Die Unit-Tests verwenden künstliche Audiodaten und keinen kostenpflichtigen
Provider. Es wurden in dieser Vorbereitung keine 52 Sulafat-Aufnahmen erzeugt.
Eine akustische Prüfung und die vollständige Aufnahmebank bleiben Release-Gates.
