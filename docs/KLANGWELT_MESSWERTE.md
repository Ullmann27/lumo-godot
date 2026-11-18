# Klangwelt – Messwerte

Automatisch erzeugt von `tools/art/generate_klangwelt_audio.py` aus den dekodierten OGG-Dateien.
**Nichts davon wurde abgehört** – alle Angaben sind Messungen (ffmpeg `ebur128`/`volumedetect`,
numpy-Auswertung). Abtastrate 32 kHz: Energie über 16 kHz ist technisch ausgeschlossen; gemessen
wird der Anteil über 15 kHz. Schleifenpunkt: `Sprung` = größte Sample-Differenz zwischen letztem
und erstem Sample, `p99` = 99. Perzentil aller Nachbar-Differenzen im Stück (Sprung/p99 < 1 heißt:
der Übergang ist glatter als 99 % des Materials), `RMS±20ms` = Pegel rund um den Übergang relativ
zum Gesamtpegel (≈1 = kein Loch und kein Knall).

## Musik

| Datei | Tonart | Tempo/Takt | Länge s | KB | kbit/s | LUFS | True Peak dBFS | DC | >15 kHz | Sprung/p99 | RMS±20ms |
|---|---|---|---|---|---|---|---|---|---|---|---|
| lumo_theme.ogg | F-Dur | 96 BPM 4/4 | 40.0 | 446 | 91 | -16.3 | -5.0 | 1.5e-06 | 2.2e-08 | 0.16 | 0.82 |
| hub.ogg | C-Dur | 112 BPM 4/4 | 68.6 | 822 | 98 | -16.5 | -2.3 | 1.4e-05 | 1.5e-07 | 0.20 | 1.22 |
| cards.ogg | B-Dur | 100 BPM 4/4 | 57.6 | 635 | 90 | -16.5 | -2.3 | 1.1e-05 | 1.3e-07 | 0.15 | 1.24 |
| memory.ogg | G-Dur | 76 BPM 4/4 | 50.5 | 407 | 66 | -16.7 | -4.4 | 8.2e-06 | 2.3e-11 | 0.45 | 0.95 |
| connect_four.ogg | D-Dur | 116 BPM 4/4 | 57.9 | 671 | 95 | -16.5 | -3.8 | 7.7e-06 | 2.3e-08 | 0.07 | 0.87 |
| quiz.ogg | Es-Dur | 120 BPM 4/4 | 64.0 | 745 | 95 | -16.8 | -3.3 | 5.4e-06 | 2.1e-07 | 0.24 | 1.01 |
| treasure.ogg | D-Dorisch | 96 BPM 4/4 | 80.0 | 860 | 88 | -16.3 | -1.7 | 2.0e-06 | 7.5e-09 | 0.47 | 0.85 |
| puzzle.ogg | E-Dur | 84 BPM 3/4 | 51.4 | 540 | 86 | -16.3 | -5.0 | 2.7e-06 | 2.2e-10 | 0.34 | 0.98 |
| build.ogg | G-Dur | 108 BPM 4/4 | 62.2 | 724 | 95 | -16.9 | -2.0 | 4.4e-05 | 1.1e-07 | 0.18 | 1.13 |
| settlement_day.ogg | D-Dur | 180 BPM 6/8 | 64.0 | 735 | 94 | -16.6 | -1.5 | 2.6e-05 | 1.2e-07 | 0.38 | 1.22 |
| settlement_evening.ogg | D-Dur | 72 BPM 4/4 | 53.3 | 527 | 81 | -16.6 | -5.8 | 2.1e-06 | 1.1e-11 | 0.15 | 0.73 |
| learning.ogg | F-Dur | 88 BPM 4/4 | 65.5 | 632 | 79 | -16.7 | -1.4 | 4.2e-05 | 1.4e-10 | 0.23 | 1.28 |
| quiz_tension.ogg | Es-Dur | 120 BPM 4/4 | 64.0 | 614 | 79 | -20.0 | -7.0 | 6.8e-06 | 4.9e-07 | 0.60 | 1.48 |
| treasure_discovery.ogg | D-Dorisch | 96 BPM 4/4 | 80.0 | 929 | 95 | -17.6 | -6.2 | 7.4e-06 | 1.8e-07 | 0.10 | 1.06 |

## Atmosphären

| Datei | Inhalt | Länge s | KB | kbit/s | LUFS | True Peak dBFS | DC | >15 kHz | Sprung/p99 | RMS±20ms |
|---|---|---|---|---|---|---|---|---|---|---|
| playroom.ogg | Spielzimmer: Uhr tickt, Holz knarzt leise, Wind am Fenster | 48.0 | 308 | 53 | -27.3 | -6.4 | 1.2e-06 | 2.4e-10 | 0.06 | 1.57 |
| island.ogg | Insel: Brandung, Möwen, Blätterrauschen | 48.0 | 307 | 52 | -27.8 | -8.1 | 3.0e-05 | 8.0e-10 | 0.58 | 1.22 |
| island_waterfall.ogg | Wasserfall in der Nähe (Schicht, lauter beim Näherkommen) | 30.0 | 200 | 55 | -23.9 | -10.3 | 3.5e-05 | 2.1e-09 | 0.27 | 1.03 |
| village_day.ogg | Dorf am Tag: Vögel, Bach, Hämmern und Sägen, wortloses Gemurmel | 60.0 | 381 | 52 | -27.0 | -9.3 | 2.4e-06 | 6.1e-10 | 0.58 | 1.41 |
| village_evening.ogg | Dorf am Abend: Grillen, leiser Bach, Abendwind | 48.0 | 309 | 53 | -27.0 | -11.4 | 3.3e-08 | 3.6e-10 | 0.14 | 0.82 |
| stage.ogg | Bühne: erwartungsvolles Publikumsraunen | 40.0 | 249 | 51 | -27.3 | -11.4 | 2.9e-07 | 1.5e-10 | 0.47 | 0.85 |
| studio.ogg | Quiz-Studio: Studiopublikum, leises Raunen | 40.0 | 250 | 51 | -27.4 | -11.0 | 1.1e-05 | 8.5e-12 | 0.08 | 1.11 |

## Töne

| Name | Varianten | Länge s (max) | KB gesamt | Spitze dBFS (max) | DC (max) |
|---|---|---|---|---|---|
| ui_click | 4 | 0.06 | 16 | -9.0 | 6.1e-04 |
| ui_confirm | 3 | 0.60 | 17 | -2.9 | 1.6e-05 |
| ui_cancel | 2 | 0.45 | 9 | -3.2 | 2.2e-05 |
| ui_back | 2 | 0.16 | 8 | -2.9 | 3.0e-05 |
| portal_tap | 2 | 1.10 | 23 | -2.9 | 1.8e-05 |
| card_next | 3 | 0.30 | 16 | -2.7 | 4.9e-06 |
| star_collected | 4 | 0.90 | 37 | -2.7 | 5.6e-06 |
| celebrate | 2 | 1.80 | 29 | -2.8 | 2.3e-05 |
| card_deal | 4 | 0.11 | 17 | -8.1 | 6.0e-05 |
| card_play | 4 | 0.17 | 18 | -3.0 | 1.7e-04 |
| card_draw | 3 | 0.18 | 14 | -2.7 | 4.8e-06 |
| card_select | 3 | 0.33 | 13 | -8.5 | 1.3e-05 |
| card_refuse | 2 | 0.50 | 9 | -3.0 | 2.0e-04 |
| card_pass | 2 | 0.25 | 10 | -3.5 | 6.1e-06 |
| card_shuffle | 2 | 0.95 | 22 | -3.4 | 6.0e-06 |
| card_flip | 3 | 0.15 | 14 | -2.7 | 5.8e-05 |
| trick_win | 2 | 0.75 | 13 | -2.8 | 1.4e-06 |
| quartet | 1 | 1.50 | 13 | -2.8 | 7.9e-07 |
| round_win | 1 | 1.60 | 12 | -3.1 | 2.3e-05 |
| turn_ping | 2 | 0.90 | 12 | -6.7 | 2.5e-06 |
| piece_drop | 4 | 0.45 | 25 | -3.0 | 3.8e-05 |
| pair_found | 2 | 0.90 | 18 | -2.7 | 6.8e-06 |
| pair_miss | 2 | 0.73 | 10 | -3.0 | 8.0e-05 |
| answer_correct | 3 | 1.20 | 31 | -2.9 | 4.0e-06 |
| answer_wrong | 2 | 0.90 | 11 | -2.9 | 4.4e-05 |
| coin | 4 | 0.70 | 27 | -2.8 | 1.4e-05 |
| count_tick | 4 | 0.25 | 17 | -8.8 | 2.1e-05 |
| build_place | 4 | 0.45 | 18 | -2.9 | 2.4e-04 |
| build_remove | 3 | 0.40 | 18 | -2.5 | 2.3e-04 |
| level_up | 1 | 2.20 | 17 | -2.9 | 4.1e-05 |
| treasure_found | 1 | 2.60 | 22 | -2.8 | 9.8e-06 |
| puzzle_snap | 3 | 0.45 | 16 | -3.1 | 7.5e-05 |
| dig | 3 | 0.32 | 21 | -3.1 | 3.2e-04 |
| applause | 2 | 3.20 | 49 | -6.5 | 1.9e-06 |
| crowd_ooh | 1 | 1.40 | 7 | -8.1 | 7.5e-07 |
| lumo_jingle | 1 | 6.00 | 40 | -3.0 | 4.8e-06 |
| whoosh | 2 | 0.45 | 13 | -7.8 | 2.4e-06 |

**Gesamtgröße:** 12.29 MB in 114 Dateien; größte Einzeldatei 0.95 MB.
