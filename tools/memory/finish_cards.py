"""Frame the Memory miniatures and deliver identical 768 × 1008 card faces.

python tools/memory/finish_cards.py /tmp/memory-sculptures [--flutter ../lumo-lernen]
"""
import argparse
import math
from pathlib import Path

from PIL import Image, ImageColor, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
W,H = 768,1008
DECK = {
    'panda': ('Panda', '295448','b4d29b','386b61', 'bamboo'),
    'giraffe': ('Giraffe','95512c','f9d69a','c58e53','sun'),
    'lumo': ('Lumo','32508a','b5dbef','608ebb','star'),
    'hase': ('Hase','685180','ddc9da','977a9a','leaf'),
    'pinguin': ('Pinguin','345d7a','bee6ec','6099b0','snow'),
    'stern': ('Sternchen','393d79','b6b6ee','636da5','star'),
    'laterne': ('Laterne','374d6a','a7cbd1','58949a','star'),
    'truhe': ('Schatztruhe','306f77','add6c0','70a798','wave'),
    'note': ('Notenfreund','6b4779','e1c9dd','a47ca1','wave'),
    'fahne': ('Sternenfahne','3e6480','c8dde7','80aabe','star'),
    'pilz': ('Pilz','5b6944','dfdfb0','8fa86d','leaf'),
    'stein': ('Stachelstein','4e4b78','d1cce1','9185b1','snow'),
}


def rgb(h):
    return ImageColor.getrgb('#'+h)


def ink_mix(a,b,f):
    return tuple(round(x+(y-x)*f) for x,y in zip(a,b))


def glyph(d,x,y,r,kind,col):
    if kind=='wave':
        d.arc((x-r,y-r,x+r,y+r),15,165,fill=col,width=3)
        d.arc((x-r,y-r*.55,x+r,y+r*1.45),15,165,fill=col,width=3)
    elif kind in ('leaf','bamboo'):
        d.polygon([(x-r,y+r*.55),(x-r*.4,y-r*.29),(x+r,y-r*.6),(x+r*.5,y+r*.21)],fill=col)
        d.line((x-r,y+r*.58,x+r,y-r*.6),fill=col,width=2)
    elif kind in ('snow','star'):
        d.polygon([(x,y-r),(x+r*.22,y-r*.22),(x+r,y),(x+r*.22,y+r*.22),
                   (x,y+r),(x-r*.22,y+r*.22),(x-r,y),(x-r*.22,y-r*.22)],fill=col)
    else:
        d.ellipse((x-r*.64,y-r*.64,x+r*.64,y+r*.64),outline=col,width=3)
        for i in range(8):
            a=i*math.tau/8
            d.line((x+r*.8*math.cos(a),y+r*.8*math.sin(a),x+r*math.cos(a),y+r*math.sin(a)),fill=col,width=2)


def make_card(kind, source):
    title,base,light,mid,pattern=DECK[kind]
    base,light,mid=rgb(base),rgb(light),rgb(mid)
    paper=(247,231,192); foil=(227,193,127)
    im=Image.new('RGB',(W,H),base)
    d=ImageDraw.Draw(im)
    for y in range(H):
        d.line((0,y,W,y),fill=ink_mix(base,mid,.30*(1-y/H)))
    # Printed keylines and a silk-screen field round the ceramic centrepiece.
    for margin,color,weight in [(11,foil,4),(22,paper,2),(40,ink_mix(paper,base,.40),2)]:
        d.rounded_rectangle((margin,margin,W-1-margin,H-1-margin),radius=49-margin*.4,outline=color,width=weight)
    d.rounded_rectangle((52,147,W-52,H-68),radius=179,fill=mid,outline=foil,width=4)
    mask=Image.new('L',(W,H));ImageDraw.Draw(mask).rounded_rectangle((59,154,W-59,H-76),radius=170,fill=255)
    field=Image.new('RGB',(W,H));draw=ImageDraw.Draw(field)
    for y in range(H):
        draw.line((0,y,W,y),fill=ink_mix(light,mid,min(1,abs(y-440)/850)))
    for r in range(245,482,19):
        draw.ellipse((W/2-r,510-r,W/2+r,510+r),outline=ink_mix(light,mid,.46),width=2)
    for i in range(24):
        a=math.tau*i/24
        x,y=384+math.sin(a)*277,521+math.cos(a)*346
        glyph(draw,x,y,9,pattern,ink_mix(mid,light,.20))
    im.paste(field,(0,0),mask);d=ImageDraw.Draw(im)
    font=ImageFont.truetype(str(ROOT/'assets/fonts/Nunito-Black.ttf'),62)
    txt=title.upper()
    d.text((W/2,88),txt,font=font,anchor='mm',fill=paper,stroke_width=1,stroke_fill=paper)
    for x in (36,W-36):glyph(d,x,88,7,'star',foil)
    sculpture=Image.open(source).convert('RGBA')
    bounds=sculpture.getchannel('A').point(lambda v: 255 if v>24 else 0).getbbox()
    if not bounds:raise ValueError(f'{kind} has no rendered surface')
    sculpture=sculpture.crop(bounds)
    sculpture.thumbnail((566,650),Image.Resampling.LANCZOS)
    x=(W-sculpture.width)//2; y=523-sculpture.height//2
    sh=Image.new('RGBA',im.size)
    sh.paste((31,34,39,155),(x+7,y+20,x+7+sculpture.width,y+20+sculpture.height),sculpture.getchannel('A'))
    out=Image.alpha_composite(im.convert('RGBA'),sh.filter(ImageFilter.GaussianBlur(10)))
    out.alpha_composite(sculpture,(x,y))
    return out.convert('RGB')


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('source',type=Path)
    parser.add_argument('--flutter',type=Path)
    args=parser.parse_args()
    folders=[ROOT/'assets/games/memory/collection']
    if args.flutter:folders.append(args.flutter/'assets/lumo_design/memory/collection')
    for folder in folders:folder.mkdir(exist_ok=True,parents=True)
    for name in DECK:
        card=make_card(name,args.source/(name+'.png'))
        for folder in folders:card.save(folder/(name+'.webp'),'WEBP',quality=92,method=6)
