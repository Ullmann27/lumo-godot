#!/usr/bin/env python3
"""Create evidence-grounded, directly downloadable PDF review volumes for Gemini Argon.
Reads immutable git checkouts; never modifies source files or exports secrets.
"""
import os, sys, re, io, json, math, hashlib, subprocess, unicodedata, textwrap
from pathlib import Path
from datetime import datetime
from PIL import Image
from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import A4
from reportlab.lib.colors import HexColor, Color
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.utils import ImageReader

BASE = Path(__file__).resolve().parents[2]
OUT = BASE / "argon-review"
OUT.mkdir(parents=True, exist_ok=True)
SOURCES = {"godot":BASE/"source_godot", "lernen":BASE/"source_lernen"}
REVISIONS = {"godot":"86b98c865b2d2cbc11aa2269a391b31f10d7fbff", "lernen":"90c239898c2f5fe7230dda05cb9e499069162208"}
EXTS = {".gd",".gdshader",".dart",".kt",".java",".js",".mjs",".ts",".tsx",".jsx",".py",".sh",".gradle",".kts",".yml",".yaml",".json",".xml",".toml",".tres",".tscn",".cfg",".properties",".pro"}
SKIP_SUFFIX = {".keystore",".jks",".p12",".pem",".key",".env",".p8",".pfx"}
SKIP_PARTS = {".git",".godot","build",".dart_tool",".gradle","node_modules","venv",".venv",".idea","generated"}
REDACT = re.compile(r"(?i)(private.?key|BEGIN [A-Z ]*PRIVATE KEY|token\s*[:=]\s*['\"][a-z0-9_-]{24,}|api.?key\s*[:=]\s*['\"][a-z0-9_-]{24,})")
REGULAR="/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
BOLD="/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
MONO="/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"
for name,pth in [("Lumo",REGULAR),("LumoBold",BOLD),("LumoMono",MONO)]:
    if os.path.exists(pth): pdfmetrics.registerFont(TTFont(name,pth))
FONT="Lumo" if os.path.exists(REGULAR) else "Helvetica"
BFONT="LumoBold" if os.path.exists(BOLD) else "Helvetica-Bold"
MFONT="LumoMono" if os.path.exists(MONO) else "Courier"
W,H=A4
NAVY=HexColor("#102441")
INK=HexColor("#223248")
BLUE=HexColor("#007DA5")
LIGHT=HexColor("#EDF4F8")
GREY=HexColor("#53657A")
TOP=H-45; BOTTOM=45
MAX_PAGES=230

def track(root):
    raw=subprocess.check_output(["git","ls-files","-z"],cwd=root)
    items=[]
    for p in raw.decode("utf-8","surrogateescape").split("\x00"):
        if not p: continue
        path=root/p
        if not path.is_file() or path.is_symlink(): continue
        try: data=path.read_bytes()
        except OSError: continue
        items.append({"path":p,"bytes":len(data),"sha256":hashlib.sha256(data).hexdigest()})
    return items

def files_for_code(root,manifest):
    files=[]
    for it in manifest:
        p=it["path"]; pp=Path(p); parts=set(pp.parts)
        if parts.intersection(SKIP_PARTS) or pp.suffix.lower() in SKIP_SUFFIX or pp.suffix.lower() not in EXTS: continue
        if p.endswith("gradle-wrapper.properties") or p.endswith("local.properties"): continue
        if it["bytes"]>650000:continue
        data=(root/p).read_bytes()
        if b"\0" in data:continue
        try:s=data.decode("utf-8")
        except UnicodeDecodeError:continue
        # Never export files with credential-like values. Do not alter source excerpts.
        if REDACT.search(s): continue
        files.append((it,s))
    def priority(it):
        p=it[0]["path"]
        base=0
        if it[0]["path"].startswith("assets/shaders/kart_"): base=-40
        elif "scripts/games/kart_" in p or "scripts/games/visual/kart_" in p: base=-35
        elif "scripts/tests/kart_" in p:base=-30
        elif p.startswith("lib/app/"):base=-38
        elif p.startswith("lib/features/learning/") or p.startswith("lib/features/games/"):base=-34
        elif p.startswith("lib/core/") or p.startswith("lib/domain/"):base=-28
        elif p.startswith("lib/"):base=-25
        elif "android/" in p:base=-22
        return (base,p)
    return sorted(files,key=priority)

def paragraph(c,t,x,y,maxw,fontsize=9,leading=13,font=FONT,color=INK):
    c.setFont(font,fontsize);c.setFillColor(color)
    lines=[]
    for line in t.split("\n"):
        if not line:lines.append("");continue
        items=line.split(" ")
        cur=""
        for word in items:
            trial=(cur+" "+word).strip()
            if pdfmetrics.stringWidth(trial,font,fontsize)>maxw and cur:
                lines.append(cur);cur=word
            else:cur=trial
        lines.append(cur)
    for line in lines:
        if y<65: c.showPage(); y=TOP
        c.drawString(x,y,line[:400]);y-=leading
    return y

def pagehead(c, label, page, detail=""):
    c.setFillColor(NAVY);c.rect(0,H-36,W,36,fill=1,stroke=0)
    c.setFont(BFONT,9);c.setFillColor(HexColor("#FFFFFF"))
    c.drawString(32,H-24,label[:85])
    c.setStrokeColor(HexColor("#D6E1EA"));c.line(30,36,W-30,36)
    c.setFont(FONT,7);c.setFillColor(GREY)
    c.drawString(30,23,"Argon / Gemini - Lumo Lernen + Lumo Kart - 15.10.2026")
    c.drawRightString(W-30,23, "%s | S. %d" % (detail,page))

def imagepage(c,root,rel,label,page):
    p=root/rel
    if not p.is_file(): return page
    try:
        im=Image.open(p)
        im.thumbnail((1550,1700))
        if im.mode not in ("RGB","L"):im=im.convert("RGB")
        c.setFillColor(HexColor("#F9FBFE"));c.rect(0,0,W,H,fill=1,stroke=0)
        pagehead(c,"BILDBELEG - "+label,page)
        px=34;py=120;maxw=W-68;maxh=H-195
        scale=min(maxw/im.width,maxh/im.height)
        dw=im.width*scale;dh=im.height*scale
        c.drawImage(ImageReader(im),(W-dw)/2,py+(maxh-dh)/2,dw,dh)
        paragraph(c,"Originaldatei im Repository: "+rel,32,103,W-64,7.2,10,font=FONT,color=GREY)
        c.showPage()
        return page+1
    except Exception as exc:
        print("Could not render",p,exc,file=sys.stderr)
        return page

def master(g_manifest,l_manifest,g_files,l_files):
    filename=OUT/"Lumo_Argon_Gemini_Masterauftrag_20261015.pdf"
    c=canvas.Canvas(str(filename),pagesize=A4,pageCompression=1)
    page=1
    c.setFillColor(NAVY);c.rect(0,0,W,H,fill=1,stroke=0)
    c.setFillColor(HexColor("#FFFFFF"));c.setFont(BFONT,23)
    c.drawString(42,H-150,"LUMO LERNEN")
    c.setFillColor(HexColor("#5FDCF3"));c.drawString(42,H-187,"+ LUMO KART")
    c.setFillColor(HexColor("#FFFFFF"));c.setFont(BFONT,14)
    c.drawString(42,H-250,"MASTER-REVIEW FÜR ARGON / GEMINI")
    c.setFont(FONT,11)
    for i,line in enumerate(["Unabhängige Architektur-, Code-, Grafik- und Integrationsexpertise",
                              "Originalquellcode wird in separaten PDF-Bänden vollständig",
                              "dateiweise und unverändert abgedruckt (soweit Exportliste).",
                              "Keine Inhalte aus Device AI Continuum."]):
        c.drawString(42,H-298-i*22,line)
    c.setFont(FONT,9)
    c.drawString(42,100,"Quellstände 15. Oktober 2026 | Git-SHA fixiert")
    c.showPage();page+=1

    sections=[
    ("AUFTRAG UND VERBINDLICHE IDENTITÄT",[
    "Argon: Sie erhalten einen aktuellen, auf feste Commits bezogenen Quellcodeauszug aus zwei echten, eigenständigen Git-Repositories und historische sowie reale Projektbilder. Behandeln Sie dieses Paket wie den Code-Review eines anspruchsvollen Studios. Das Ziel ist NICHT bloß eine Konzeptantwort.",
    "Lumo Lernen ist die primäre Android-/Flutter-Lern-App mit Mathe, Deutsch, Englisch, Nachhilfe, verständlichen Erklärungen, Belohnungen, Eltern-/Kinder-Schutz und einem eigenständigen freundlichen Fuchsbegleiter. Lumo Kart ist das angeschlossene Godot-3D-Rennspiel und kann zusätzlich eigenständig ausgeliefert werden.",
    "Designregel: Die vorhandene Fuchs-Markenidentität erhalten. Referenzbilder nicht als Beweis dafür behandeln, dass die APK heute bereits so aussieht. Kein Mario-Kart-Code, keine geschützten Figuren, Strecken oder Musik übernehmen.",
    "Ihre Aufgabe: maximal konkrete Verbesserungsvorschläge; kritische Fehler und unverdrahtete Komponenten identifizieren; Implementierungsvorschlag mit exakten Dateipfaden, vollständigen Ersatzdateien, testbaren Akzeptanzkriterien, Priorität, Aufwand und Risiken."
    ]),
    ("VERIFIZIERTE REPOSITORY-GRUNDLAGE",[
    "Godot: https://github.com/Ullmann27/lumo-godot ; Entwickler-Commit: "+REVISIONS["godot"]+" ; letzter Grafik-Folgebranch: chatgpt/sonnenhafen-water-visual-qa-2026-10-15 ; PR #72: https://github.com/Ullmann27/lumo-godot/pull/72",
    "Flutter: https://github.com/Ullmann27/lumo-lernen ; Stand main: "+REVISIONS["lernen"],
    "Datei-Inventar aus git ls-files (je Snapshot): Godot "+str(len(g_manifest))+" Gesamtdateien, "+str(len(g_files))+" ausgewählte komplette überprüfbare Quell-/Konfigurationsdateien; Flutter "+str(len(l_manifest))+" Gesamtdateien, "+str(len(l_files))+" vollständige Code- und Konfigurationsdateien.",
    "Jede Quelldatei der Code-Bände besitzt Dateipfad, Byteanzahl, SHA-256 und vollständigen lesbaren UTF-8-Text. Nicht enthalten sind Binärdateien, große oder ausdrücklich sensible Dateien, oder explizit gesperrte Geheimniskandidaten. Das Inventar enthält alle Git-Dateien mit Hash, nicht deren Binärinhalt.",
    "Unbedingt vor Vorschlägen prüfen, ob zwischen den Repositories schon ein nativer Game-Bridge-Vertrag, ein sauberer Startflow, ein Gradle-Build oder persistente gemeinsame Progress-Schnittstellen existieren."
    ]),
    ("BEKANNTER AKTUELLER TESTBLOCKER",[
    "GitHub Actions des Grafik-Folgebranches: https://github.com/Ullmann27/lumo-godot/actions/runs/38793723752 - bei diesem geprüften Lauf ist 'Import all Godot assets and validate shader syntax' erfolgreich, aber der neue testbasierte Schritt 'Verify full and low water in real Sonnenhafen and forest' fehlgeschlagen.",
    "Der Log nennt scripts/tests/kart_sonnenhafen_water_regression.gd Zeilen 21 und 46: 'Invalid call. Nonexistent float constructor.' Ein Fehler im Test bei einem möglichen null/Variant-Rückgabewert ist naheliegend, aber Ursache und korrekte Reparatur müssen Sie nachstellen. Der Job lief bis zum Timeout; Renderer- und Screenshot-Schritte wurden übersprungen.",
    "Frage: Wie reparieren Sie Test- und Materialannahmen fachlich korrekt, ohne kritische Assertions aufzuweichen? Kontrollieren Sie Godot 4.6.3 API-Verhalten von ShaderMaterial.get_shader_parameter() unter headless.",
    "Ältere Integrations-CI für Premium-Schienen und 12 Bauwelt-Props war erfolgreich: https://github.com/Ullmann27/lumo-godot/actions/runs/38746659569 . Ein erfolgreicher Godot-Import ersetzt keine Android-GPU- und Gameplay-Verifikation."
    ]),
    ("01 - ARCHITEKTUR / INTEGRATION",[
    "Durchlaufen Sie alle Startpunkte von Flutter lib/app/app_shell.dart und lib/core/embedded_game_service.dart bis zu Godot Projekt/Android-Package, Scene-Loader, Rücknavigation, Pause, Resume, Spieldaten, Profil und Lernfortschritt. Ermitteln Sie tote Routen, ungenutzte Services, doppelten Zustand, stille Fehler und eventuell nur simulierte Funktionen.",
    "Schlagen Sie ein einziges kohärentes Zustands- und Navigationsmodell vor, das die Lern-App als Hauptprodukt priorisiert und Lumo Kart als Spielmodus, inklusive optional separater Kart-App, integriert. Keine doppelten IDs oder unkontrollierten Datensynchronisierungen.",
    "Legen Sie konkrete Integrations- und End-to-End-Tests für Fold, Querformat, Anwendungswechsel, Resume/Cold Start und Offline-Modus vor."
    ]),
    ("02 - KINDGERECHTE LERN-APP",[
    "Beurteilen Sie altersgerechte didaktische Lernpfade für Mathematik, Deutsch, Englisch, Lesen, Schreiben und Nachhilfe. Suchen Sie nach falschem Feedback, Aufgabenwiederholungen, doppelten Aufgabensätzen, inadäquater Schwierigkeit und irreführendem Fortschritt.",
    "Wie verbessert man Lernziel-Transparenz, hinweisgestütztes Entdecken, adaptives Tempo, Lesehilfen, Sprachanleitung, Belohnungen und Elternübersicht, ohne die App zu überladen?",
    "Prüfen Sie echte Funktionsverbindungen zu Lumo-Tutor, Companion, Speech, Audio, Fortschrittsspeichern und adaptivem Lernen. Keine pauschale Behauptung, dass ein Produkt intelligent sei, nur weil Klassen so heißen."
    ]),
    ("03 - LUMOS FIGUR, ANIMATION, STIMME",[
    "Die Figur auf den Master-, Orthografie- und Mimikblättern ist die visuelle Referenz. Wie erreicht man mit den vorhandenen Meshes/Rigs, Animationen und Materialien in Flutter und Godot ein konsistentes Lumo-Gesicht, erkennbare Augen, Schnauze, Ohren, Brille, Farben und Körperproportionen?",
    "Finden Sie für die aktuelle Android-Laufzeit die konkrete Pipeline von GLB/Rig über AnimationTree/Blend-Space bis Kamera, Materials, LOD und Lip-Sync. Prüfen Sie, welche Assets wirklich geladen und welche nur abgelegt werden.",
    "Wie kann die Stimme natürlich, freundlich, kindgerecht und cartoon-typisch klingen, ohne kindische Unverständlichkeit, übertriebene Betonung oder irreführende Aussagen? Vorschlag für robuste TTS-Sprache/Prosodie/Fallbacks."
    ]),
    ("04 - KART-RENNER, STRECKEN, MATERIALIEN",[
    "Prüfen Sie jedes vorhandene Kart-Shaderfile, die Materialbindung in kart_world.gd, Sternen-/Neonwelt, Asphalt, Küstenwasser, Wasserfall, Beleuchtung, Bloom, Transparenzen, LoD, GPU-Batches, Kollisionen und Messbarkeit der Performance.",
    "Vergleichen Sie echte Godot-Screenshots mit den vorgesehenen Referenzillustrationen, jeweils separat dokumentiert. Liefern Sie eine Asset-Gap-Liste mit markanten visuellen Abweichungen, relevanter Spielansicht und Priorität.",
    "Wie werden Sonnenhafen, Zauberwald, Kristallwelt, Wolkeninseln, Stadt, Vulkan und weitere geplante Welten detailreicher, ohne auf typischen Android-GPUs instabil zu werden?"
    ]),
    ("05 - FAHRGEFÜHL / GAMEPLAY / STRECKENDESIGN",[
    "Bewerten Sie Steuerkurve, Driften, Kamera, Kart-Masse, Boost, Items, Gegner-KI, Rennstart, Zielmoment, Wiederholungswert, Schadensfall- und Restart-Verhalten. Prüfen Sie echte Eingabelatenz, Kamera-Ruckler und Fold-Touch-Zonen.",
    "Wie entsteht hohes, eigenständiges Arcade-Fahrgefühl auf Niveau führender Genre-Spiele, ohne Inhalte anderer Spiele zu kopieren? Geben Sie konkrete Parameter, Module und Tests.",
    "Schlagen Sie einen nachvollziehbaren Vergleich vor: reale Messläufe über 60 Sekunden, Touch-Interaktionen, Rennabschluss und messbare FPS-/Frame-Pacing-Ziele."
    ]),
    ("06 - 3D-BAUWELT UND ASSET-PIPELINE",[
    "12 neue prozedurale Bauwelt-Objekte sind im Integrations-Commit enthalten. Prüfen Sie Baukatalog, Placement, Snap/Rotation, Kollisionslogik, Undo, Persistenz, Asset-Namen, Speicherformate und Verlust bestehender Objekte bei Migration.",
    "Erarbeiten Sie realistische, mobile-geeignete Modelle mit sauberer Materialvorlage und GLB-Import-Prozess. Jede neue Grafik muss eine echte Engine-Ressource sein, kein bloßes Photoshop-Mockup."
    ]),
    ("07 - ANDROID/FOLD, SICHERHEIT UND RELEASE",[
    "Prüfen Sie Gradle/Flutter-Godot-Anbindung, arm64, Signatur, Paketname, Android 16, Fold-Resize, Cutouts, Orientierungswechsel, Back-Navigation, Audio-Unterbrechungen, Abbruch, OOM, Pause/Resume und Eingabefokus.",
    "Definieren Sie ein Release-Gate: reproduzierbarer Build, signierte APK, hash, Installationsprüfung, Cold-Start, 10-Minuten-Test, echte PNG-Screenshots aus dem Gameplay, Absturzfreiheit und überprüfbarer Versionsstand.",
    "Kinder- und Privatsphärenschutz: kein Hintergrundtracking, keine ungefragten Mikrofonmitschnitte, sicheres Benutzerprofil und nachvollziehbare Freigaben."
    ]),
    ("08 - VORGABEN FÜR ARGONS AUSGABE",[
    "Beginnen Sie mit einer ehrlichen 15-Punkte-Diagnose: BELEGT IM CODE / VERMUTUNG / NOCH NICHT GEPRÜFT. Geben Sie konkrete Fundstellen (Datei und Funktion) an.",
    "Erstellen Sie eine nummerierte Prioritätenmatrix: Fehler/Schaden, sichtbarer Nutzen, Umsetzungsaufwand, Kompatibilitätsrisiko, Android-Leistung, Testnachweis.",
    "Liefern Sie Ihre stärksten 10 Verbesserungen als vollständige, kompiliertaugliche neue oder ersetzte Quelldateien (nicht nur Pseudocode oder Diffs). Geben Sie für jede Änderung Installationsort, Testbefehl, erwartete Ergebnisse, Side Effects und Rollback an.",
    "Arbeiten Sie in kleinen messbaren Wellen mit verifizierten Akzeptanzkriterien. Wenn der Kontext nicht für den gesamten Code reicht, benennen Sie exakt, welche PDF-Quelle/Datei fehlt und erfinden Sie keinen Zustand.",
    "Geben Sie konkrete Asset- und Bildgestaltungsvorgaben: Figur, Kart, Straße, Wasser, Landschaft, UI, Strecken, LOD, Shader und Animation. Jede Grafikidee muss auf die vorhandene Pipeline zurückgeführt werden.",
    "Nach Abschluss: halten Sie eine technische Übergabe bereit, mit der ein anderer Entwickler die Änderungen ohne Raten integrieren und alle Prüfungen wiederholen kann."
    ])
    ]
    for heading,paras in sections:
        pagehead(c,heading,page,"MASTER")
        y=TOP-26
        c.setFont(BFONT,15);c.setFillColor(NAVY);c.drawString(32,y,heading);y-=28
        for p in paras:
            y=paragraph(c,p,32,y,W-64,9.2,14)
            y-=16
            if y<96:
                c.showPage();page+=1;pagehead(c,heading+" (Fortsetzung)",page,"MASTER");y=TOP-20
        c.showPage();page+=1
    visual=[
      ("Godot / echte Laufzeit",SOURCES["godot"],"docs/qa/visual/kart-aaa/2026-10-10/m2-layout/after/driver-1280x720.png"),
      ("Godot / Menü nach Entwicklung",SOURCES["godot"],"docs/qa/visual/kart-aaa/2026-10-10/m1/after/menu-1280x720.png"),
      ("Godot / nachher-vorher Vergleich",SOURCES["godot"],"docs/design/2026-10-11-next-level-menu/evidence/Lumo-Kart-Vorher-Originalreferenz-Nachher.png"),
      ("Godot / Lumo-Modellreferenz",SOURCES["godot"],"assets/characters/lumo/reference/01_master_character_sheet.png"),
      ("Godot / orthografisches Referenzblatt",SOURCES["godot"],"assets/characters/lumo/reference/02_orthographic_model_sheet.png"),
      ("Godot / echte Fahrergesten",SOURCES["godot"],"docs/design/2026-10-11-astra-animation-quality/after/gesture/kart-three-quarter.png"),
      ("Godot / Animation im Rennen",SOURCES["godot"],"docs/design/2026-10-10-animation/qa/kart-runtime/seated.png"),
      ("Godot / Sonnenhafen UI-Vergleich",SOURCES["godot"],"docs/qa/visual/kart-aaa/2026-10-10/m1/vergleich-640x360.png"),
      ("Godot / Kristall-Canyon Referenz",SOURCES["godot"],"docs/design_targets/2026-10-05-tracks/Track_02_crystal_canyon_dash/track_02_hero_original.png"),
      ("Godot / Hafenwelten Referenz",SOURCES["godot"],"docs/design_targets/2026-10-05-tracks/Track_04_aqua_harbor_rush/track_04_hero_original.png"),
      ("Godot / Fahrzeugdesign Referenz",SOURCES["godot"],"docs/design_targets/2026-10-08-kart-fahrzeuge/01_lumo_kart_blatt_a.png"),
      ("Flutter / Lumo-Logo und Charakter",SOURCES["lernen"],"assets/images/lumo_fox.png"),
      ("Flutter / Kart-Cover",SOURCES["lernen"],"assets/images/lumo_kart_cover.png"),
    ]
    for label,root,rel in visual:
        page=imagepage(c,root,rel,label,page)
    pagehead(c,"DATEIABDECKUNG UND GRENZEN",page,"MASTER")
    y=TOP-24
    for heading,body in [
        ("Keine Geheimnisse / Schutz","In PDF-Bänden werden nur explizit freigegebene, decodierbare UTF-8-Quell- und Konfigurationsdateien abgedruckt. Geheimnisträchtige Dateitypen und erkannte Schlüsseltexte werden ausgeschlossen. Das bedeutet: nicht jede Git-Datei ist Bestandteil des Code-Bands."),
        ("Keine fiktive APK","Die Quellcode-PDF und ihre Bildbelege sind eine Entwicklungs-/Review-Übergabe, keine Aussage, dass diese Bildqualität bereits auf Samsung Fold Android 16 erreicht ist."),
        ("Code-Inventar","Das separate maschinenlesbare Inventar mit SHA-256 deckt alle getrackten Dateien beider Repositories ab. Quellcode-PDFs enthalten die Inhalte der jeweiligen ausgewählten Dateien VOLLSTÄNDIG, ohne Ellipsen."),
        ("Dokumentationsstand","Aktuell bekannte Projektdateien werden aus genau den beiden oben genannten Commits gelesen; Änderungen nach 15.10.2026 sind nicht enthalten.")
    ]:
        c.setFont(BFONT,10);c.setFillColor(NAVY);c.drawString(32,y,heading);y-=20
        y=paragraph(c,body,32,y,W-64,9.2,14);y-=22
    c.showPage()
    c.save()
    return filename

def write_code_volume(project, root, files, manifest):
    outputs=[]
    volume=1; page=0; c=None; filename=None
    def begin():
        nonlocal volume,page,c,filename
        filename=OUT/f"Lumo_Argon_Originalcode_{'Godot' if project=='godot' else 'Flutter'}_Band_{volume:02d}.pdf"
        c=canvas.Canvas(str(filename),pagesize=A4,pageCompression=1)
        page=1
        pagehead(c,project.upper()+" - ORIGINALQUELLCODE",page,"CODE")
        y=H-110
        c.setFillColor(NAVY);c.setFont(BFONT,16)
        c.drawString(33,y,"VOLLSTÄNDIGE DATEIINHALTE / BAND %02d"%volume)
        y-=29
        for txt in [
            "Repository: Ullmann27/"+("lumo-godot" if project=="godot" else "lumo-lernen"),
            "Geprüfter Commit: "+REVISIONS[project],
            "Exakte Dateien und SHA-256 stehen jeweils vor dem gesamten Quelltext.",
            "Umgebrochene Druckzeilen sind weiterhin derselbe Original-UTF-8-Code.",
            "Keine Tokens, Signierschlüssel oder Binärdateien. Keine Auslassung innerhalb einer exportierten Datei."
        ]: y=paragraph(c,txt,33,y,W-65,8.5,12)
        c.showPage();page+=1
    def finish():
        nonlocal c,volume
        c.save();outputs.append(filename);volume+=1
    begin()
    m=0
    for item,body in files:
        m+=1
        path=item["path"]
        # Start a new volume between files, never in the middle of a file.
        # Soft cap; large single file can overflow to next pages.
        if page>=MAX_PAGES:
            finish();begin()
        y=TOP-18
        pagehead(c,project.upper()+" - ORIGINALQUELLCODE",page,"CODE")
        c.setFont(BFONT,10);c.setFillColor(BLUE)
        c.drawString(31,y, ("DATEI %d/%d - "%(m,len(files))) + path[:88]); y-=15
        c.setFont(FONT,7);c.setFillColor(GREY)
        c.drawString(31,y,"Bytes: %d | SHA-256: %s"%(item["bytes"],item["sha256"]));y-=19
        linecount=0
        for i,raw_line in enumerate(body.splitlines(),1):
            # Preserve original in file, display wrapped 128-column code with source line numbers.
            txt=raw_line.expandtabs(4)
            pieces=textwrap.wrap(txt,width=126,expand_tabs=False,replace_whitespace=False,drop_whitespace=False,break_long_words=True,break_on_hyphens=False) or [""]
            for j,segment in enumerate(pieces):
                if y<56:
                    c.showPage();page+=1;pagehead(c,project.upper()+" - "+path[-72:],page,"CODE");y=TOP-17
                c.setFont(MFONT,5.85);c.setFillColor(INK)
                lineno=("%5d | "%i) if j==0 else ("      | ")
                # Drawstring handles most Unicode; unsupported glyphs remain in hash-verified source.
                c.drawString(31,y,lineno+segment)
                y-=8.15
                linecount+=1
        if y<80:
            c.showPage();page+=1;pagehead(c,project.upper()+" - QUELLCODE",page,"CODE");y=TOP-18
        c.setFont(FONT,7);c.setFillColor(GREY)
        c.drawString(31,y-8,"ENDE DATEI / %d Originalzeilen / %d Druckzeilen"%(len(body.splitlines()),linecount))
        c.showPage();page+=1
    finish()
    return outputs

def main():
    all_man={}
    all_codes={}
    for project,root in SOURCES.items():
        if not (root/".git").exists():raise SystemExit(f"Missing checkout: {root}")
        rev=subprocess.check_output(["git","rev-parse","HEAD"],cwd=root,text=True).strip()
        if rev!=REVISIONS[project]:raise SystemExit(f"REF MISMATCH for {project}: {rev}")
        all_man[project]=track(root)
        all_codes[project]=files_for_code(root,all_man[project])
        print(project,"tracked",len(all_man[project]),"exported",len(all_codes[project]))
    (OUT/"Lumo_Argon_Dateiindex_SHA256.json").write_text(
        json.dumps({"snapshots":REVISIONS,"all_tracked":all_man,"exported_source":{
            name:[x[0] for x in files] for name,files in all_codes.items()
        }},ensure_ascii=False,indent=1),encoding="utf-8")
    produced=[master(all_man["godot"],all_man["lernen"],all_codes["godot"],all_codes["lernen"])]
    for project in ("godot","lernen"):
        produced.extend(write_code_volume(project,SOURCES[project],all_codes[project],all_man[project]))
    # One-file first-contact packet: actual screenshots, task, complete first
    # source volume from each repository. All remaining volumes remain available.
    from pypdf import PdfReader, PdfWriter
    combo = OUT / "Lumo_Argon_Gesamtpaket_Bilder_Originalcode_20261015.pdf"
    writer = PdfWriter()
    selected = [produced[0],
        OUT / "Lumo_Argon_Originalcode_Godot_Band_01.pdf",
        OUT / "Lumo_Argon_Originalcode_Flutter_Band_01.pdf"]
    counts = []
    for src in selected:
        reader = PdfReader(str(src))
        counts.append((src.name,len(reader.pages)))
        writer.append(reader)
    with combo.open("wb") as stream: writer.write(stream)
    produced.append(combo)
    print("Combined Argon packet:", json.dumps(counts,ensure_ascii=False),
          "total_pages",sum(n for _,n in counts))
    print(json.dumps({"files":[{"name":x.name,"bytes":x.stat().st_size} for x in produced]},ensure_ascii=False))
if __name__=="__main__": main()
