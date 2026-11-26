"""Render the original Lumo Kart band arrangements, including a score for each Parcours.
All instruments are synthesized here. No soundfonts, samples or network access.
Requires NumPy, SciPy and FFmpeg. Run from any directory with optional score IDs.
"""
from collections import namedtuple
from pathlib import Path
from functools import lru_cache
import argparse
import hashlib
import json
import math
import subprocess
import numpy as np
from scipy.signal import butter, sosfilt

OUT = Path(__file__).resolve().parents[2] / "assets/audio/kart"
SR = 32000
BAR_COUNT = 32
Score = namedtuple("Score", "title bpm key mode chords melody timbre rhythm")
IONIAN = [0, 2, 4, 5, 7, 9, 11]
DORIAN = [0, 2, 3, 5, 7, 9, 10]
MINOR = [0, 2, 3, 5, 7, 8, 10]
LYDIAN = [0, 2, 4, 6, 7, 9, 11]
# Scale-degree hooks, bar progressions and grooves are written independently.
SCORES = {
    "garage": Score("Späte Runde", 94, 48, DORIAN, [0,3,1,4,0,5,3,4], [2,4,3,1,0,2,5,4], "keys", "pocket"),
    "sonnenhafen": Score("Am Kai", 111, 50, IONIAN, [0,3,4,1,5,3,1,4], [4,2,1,2,0,5,3,1], "guitar", "samba"),
    "zauberwald": Score("Unter den Wurzeln", 102, 48, DORIAN, [0,3,0,1,2,6,3,4], [0,2,3,1,4,3,2,0], "reed", "shuffle"),
    "bergwelt": Score("Aufwind", 119, 51, LYDIAN, [0,1,5,4,0,5,1,4], [0,4,6,5,3,4,1,2], "bow", "glide"),
    "holo_city": Score("Lichtverkehr", 122, 46, MINOR, [0,5,2,6,3,0,5,4], [4,3,0,2,5,4,2,1], "analog", "motor"),
    "winter_sprint": Score("Kufen auf Glas", 113, 49, DORIAN, [0,2,5,3,1,5,4,0], [2,5,4,1,3,2,0,1], "keys", "glide"),
    "volcano_night": Score("Unter dem Basalt", 118, 44, MINOR, [0,0,5,3,6,3,4,4], [0,0,3,2,4,3,1,0], "brass", "breaks"),
    "crystal_canyon": Score("Echo am Stein", 108, 47, DORIAN, [0,2,4,1,0,6,3,4], [4,1,3,5,2,0,2,4], "mallet", "shuffle"),
    "jungle_temple": Score("Wurzelpfad", 116, 46, DORIAN, [0,3,2,6,0,2,3,1], [2,0,3,4,1,0,4,2], "wood", "samba"),
    "candy_cloud": Score("Luftpost", 110, 50, IONIAN, [0,2,5,3,1,3,5,4], [2,4,1,3,5,2,4,0], "pluck", "pocket"),
    "galaxy_ringway": Score("Blaue Umlaufbahn", 105, 45, LYDIAN, [0,2,1,3,5,1,4,0], [3,6,4,2,1,5,2,0], "analog", "glide"),
    "desert_drift": Score("Staub und Saiten", 116, 45, MINOR, [0,6,5,4,0,3,5,4], [4,3,1,0,2,5,1,0], "guitar", "shuffle"),
    "learning_lab": Score("Taktlabor", 117, 48, LYDIAN, [1,0,1,4,5,3,1,0], [1,4,2,0,3,1,5,4], "wood", "breaks"),
    "riesengarten_2400": Score("Morgentau", 106, 52, IONIAN, [0,3,1,4,5,2,3,0], [2,3,4,2,0,5,4,1], "reed", "pocket"),
    "windwerk_3000": Score("Wind in den Speichen", 120, 48, DORIAN, [0,3,5,4,0,2,3,6], [4,0,2,3,5,3,1,0], "brass", "motor"),
    "wolkenwerkstatt": Score("Fracht am Himmel", 112, 50, LYDIAN, [0,4,1,5,3,0,2,1], [0,3,4,6,2,1,4,3], "pluck", "glide"),
    "eisturm": Score("Die gläserne Wendel", 114, 47, MINOR, [0,5,1,4,2,6,3,0], [2,4,6,4,3,1,0,2], "mallet", "motor"),
    "dschungeltempel": Score("Lianenhalle", 110, 49, DORIAN, [0,3,4,0,5,2,3,4], [0,2,4,1,3,5,2,1], "wood", "samba"),
    # Signatur-Strecken (Team B1, 26.11.2026).
    "vulkanexpress_3100": Score("Feuerinsel-Express", 128, 47, DORIAN, [0,5,3,4,0,2,5,4], [4,2,4,5,3,1,2,0], "guitar", "motor"),
    "wolkensturm_3300": Score("Über den Wolken", 132, 50, LYDIAN, [0,4,5,1,0,3,4,6], [2,4,6,4,5,3,1,4], "analog", "glide"),
    "kristallflut_2800": Score("Lied der Tiefe", 114, 49, IONIAN, [0,5,3,4,1,5,3,6], [4,6,5,2,3,1,0,2], "mallet", "samba"),
}
PATTERNS = {
    "pocket": ([0,1.75,2.5], [0,.75,2.5,3.25], [.50,1.25,2.75], .075),
    "samba": ([0,1.5,2,3.5], [0,1.5,2.75], [.0,.75,1.5,2.75], .018),
    "motor": ([0,1,2,3], [0,.75,1.5,2.5,3.5], [.5,1.75,2.5,3.5], .0),
    "glide": ([0,2,3.5], [0,1.5,2.75], [.0,1.5,2.5], .025),
    "shuffle": ([0,1.66,2.66], [0,1.66,2.66,3.66], [.0,.66,2,2.66], .11),
    "breaks": ([0,1.5,2.75,3.5], [0,.75,1.5,2.75], [.25,1.75,2.5,3.25], .037),
}
def tone(degree, score):
    octave, index = divmod(degree, 7)
    return score.key + score.mode[index] + 12*octave


@lru_cache(maxsize=1024)
def note(kind, pitch, duration):
    seconds = duration / 1000
    t = np.arange(round(SR*(seconds+.11)), dtype=np.float64)/SR
    f = 440 * 2 ** ((pitch-69)/12)
    phase = 2*np.pi*f*t
    if kind == "bass":
        voice = np.sin(phase) + .47*np.sin(2*phase)*np.exp(-t*4) + .15*np.sin(3*phase)
        decay, attack = 1.8,.012
    elif kind in ("guitar","wood","pluck","mallet","keys"):
        ratio = {"guitar":2.00,"wood":1.49,"pluck":2.99,"mallet":2.62,"keys":1.00}[kind]
        voice = np.sin(phase+(.7 if kind=="keys" else 1.2)*np.sin(phase*ratio)*np.exp(-5*t))
        voice += .21*np.sin(phase*2.003) + .09*np.sin(phase*3.001)*np.exp(-3*t)
        decay,attack = (2.6 if kind in ("keys","guitar") else 4.0),.006
    else:
        partials = {"bow":[1,.45,.26,.11,.08],"analog":[1,.40,.18,.13,.06],
                    "brass":[1,.57,.30,.14,.06],"reed":[1,.12,.39,.045,.11],"pad":[1,.28,.14,.08,.04]}[kind]
        vib = .042*np.sin(2*np.pi*4.9*t)*np.minimum(t/.22,1)
        voice = sum(a*np.sin(h*(phase+vib)) for h,a in enumerate(partials,1))
        decay,attack = (.36,.071) if kind=="pad" else (.84,.037)
    env = (1-np.exp(-t/attack))*np.exp(-decay*t)*np.exp(-np.maximum(t-seconds,0)/.024)
    return (voice*env).astype('float32')


def drums(rng):
    t = np.arange(round(SR*.48))/SR
    noise = rng.normal(0,.72,len(t))
    kick = np.sin(2*np.pi*(49*t+2.9*(1-np.exp(-32*t))))*np.exp(-t*11)
    snare = sosfilt(butter(2,[470,3700],fs=SR,btype='bandpass',output='sos'),noise)*np.exp(-t*23)
    snare += .30*np.sin(2*np.pi*170*t)*np.exp(-t*29)
    hat = sosfilt(butter(2,[2300,5900],fs=SR,btype='bandpass',output='sos'),noise)*np.exp(-t*57)
    tom = np.sin(2*np.pi*(104*t+1.1*(1-np.exp(-22*t))))*np.exp(-t*14)
    return [v.astype('float32') for v in (kick,snare,hat,tom)]


def compose(id, sc):
    beat = 60/sc.bpm
    count = round(4*BAR_COUNT*beat*SR)
    mix = np.zeros((count,2),dtype='float32')
    rng = np.random.default_rng(int.from_bytes(hashlib.sha256(id.encode()).digest()[:4],"little"))
    kick, snare, hat, tom = drums(rng)
    kicks,bass_ticks,lead_ticks,swing = PATTERNS[sc.rhythm]
    def add(sound, at, amp, pan=0):
        start = round(at*beat*SR)%count
        n = min(len(sound),count-start)
        for channel,gain in enumerate((np.sqrt((1-pan)/2),np.sqrt((1+pan)/2))):
            mix[start:start+n,channel] += amp*gain*sound[:n]
            if n < len(sound):
                mix[:len(sound)-n,channel] += amp*gain*sound[n:]
    for bar in range(BAR_COUNT):
        at, chord = 4*bar, sc.chords[bar%8]
        lift = 8 <= bar < 16 or bar >= 24
        bridge = 16 <= bar < 20
        for tick in (kicks if not bridge else [0,2.75]):
            add(kick,at+tick,.56 if id=="garage" else .66)
        for tick in ([1,3] if not bridge else [3]):
            add(snare,at+tick,.39 if lift else .30,-.07)
        for eighth in range(8):
            if bridge and eighth%2: continue
            add(hat,at+.5*eighth+(swing if eighth%2 else 0),(.21 if eighth%2 else .13)*rng.uniform(.82,1.05),.38)
        if bar%8==7:
            for i in range(3): add(tom,at+3.25+i*.25,.15+i*.03,-.3+i*.22)
        for i,tick in enumerate(bass_ticks):
            degree = chord + ([0,0,4,6,4][i] if bar%2 or lift else 0)
            pitch=tone(degree,sc)
            while pitch>50: pitch-=12
            if pitch<32: pitch+=12
            add(note("bass",pitch,round(beat*(.91 if i==0 else .45)*1000)),at+tick,.49 if i==0 else .38)
        # Seventh/added-ninth voicings, deliberately below a bright toy-synth register.
        voicing=sorted([tone(chord+d,sc) for d in (2,4,6,8)])
        for i,pitch in enumerate(voicing):
            while pitch>67: pitch-=12
            for tick in ([0] if bridge else [.5,2.25] if sc.rhythm in ("pocket","samba") else [0,2.5]):
                add(note("pad" if bridge or lift else "keys",pitch,round(beat*(2.8 if bridge else .84)*1000)),
                    at+tick+i*.008,.115,[-.57,.38,-.24,.62][i])
        if bridge or bar in (3,7,29): continue
        for i,tick in enumerate(lead_ticks):
            if (bar%4==1 and i==1) or (not lift and i==len(lead_ticks)-1):continue
            degree = sc.melody[(bar*2+i+(2 if bar>=24 else 0))%8]
            pitch = tone(degree,sc)+(12 if sc.key<48 and lift else 0)
            if lift and i==1 and bar%4==2:pitch+=5
            pitch = min(pitch,68)
            dur = round(beat*(.72 if i==0 else .42 if i%2 else .61)*1000)
            phrase=note(sc.timbre,pitch,dur)
            add(phrase,at+tick,.30 if lift else .25,.12)
            add(phrase,at+tick+.75,.042,-.53)
    # Circular short room reflections preserve the groove across the loop.
    dry=mix.copy()
    for k,delay in enumerate((.033,.061,.107)):
        mix += np.roll(dry[:,::-1],round(SR*delay),axis=0)*(.060/(k+1))
    mix=np.tanh(mix*1.15)
    return mix*(.78/max(np.max(np.abs(mix)),.01))


def main():
    cli=argparse.ArgumentParser();cli.add_argument('ids',nargs='*');args=cli.parse_args()
    manifest_path=OUT/'manifest.json'
    manifest=json.loads(manifest_path.read_text())
    entries={row['file']:row for row in manifest['assets']}
    for id in args.ids or SCORES:
        sc=SCORES[id]; audio=compose(id,sc)
        name=id+'.ogg'; path=OUT/name
        subprocess.run(['ffmpeg','-v','error','-y','-f','f32le','-ar',str(SR),'-ac','2','-i','pipe:0',
                        '-c:a','libvorbis','-q:a','3','-fflags','+bitexact','-flags:a','+bitexact',
                        '-metadata','title='+sc.title,str(path)],input=audio.astype('<f4').tobytes(),check=True)
        raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(path),'-f','f32le','-ac','2','-'])
        decoded=np.frombuffer(raw,dtype='<f4').reshape(-1,2)
        stats=subprocess.run(['ffmpeg','-hide_banner','-i',str(path),'-af','ebur128','-f','null','-'],
                             capture_output=True,check=True).stderr.decode()
        import re
        loudness=float(re.findall(r'I:\s*(-?\d+\.\d+) LUFS',stats)[-1])
        entries[name]=dict(file=name,bars=BAR_COUNT,bpm=sc.bpm,description=sc.title,lead=sc.timbre,
                generator='tools/art/compose_track_scores.py',seconds=round(len(decoded)/SR,4),sample_rate=SR,
                channels=2,lufs=loudness,peak_dbfs=round(20*math.log10(np.max(np.abs(decoded))),2),
                seam_delta=round(float(np.max(np.abs(decoded[-1]-decoded[0]))),5),loop=True,
                bytes=path.stat().st_size,sha256=hashlib.sha256(path.read_bytes()).hexdigest())
        print(id,sc.title,entries[name]['lufs'],flush=True)
    manifest['assets']=list(entries.values())
    manifest['music_generator']='tools/art/compose_track_scores.py'
    manifest_path.write_text(json.dumps(manifest,indent=2)+'\n')


if __name__=='__main__':
    main()
