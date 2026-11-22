"""A festival windsock shaped like a whale, with a wicker basket and pilot goggles."""
from math import cos, sin, tau, pi


def ellipsoid(builder, centre, radii, material):
    segments = (32, 20, 12)[builder.level]
    bands = (16, 10, 7)[builder.level]
    cx, cy, cz = centre
    rx, ry, rz = radii
    rings = []
    for row in range(1, bands):
        phi = pi * row / bands
        for j in range(segments):
            theta = tau * j / segments
            rings.append((cx + rx*cos(phi), cy + ry*sin(phi)*cos(theta), cz + rz*sin(phi)*sin(theta)))
    faces = [(row*segments+j, row*segments+(j+1)%segments,
              (row+1)*segments+(j+1)%segments, (row+1)*segments+j)
             for row in range(bands-2) for j in range(segments)]
    right, left = len(rings), len(rings)+1
    rings.extend([(cx+rx,cy,cz), (cx-rx,cy,cz)])
    for j in range(segments):
        after = (j+1)%segments
        faces.extend([(right,after,j), (left,(bands-2)*segments+j,(bands-2)*segments+after)])
    builder.solid(rings, faces, material)


def whale(b):
    # Lobed, stitched envelope. The belly overlaps the main envelope along a
    # narrow waterline, like the pale second fabric of a sewn parade balloon.
    ellipsoid(b, (0,3.9,0), (3.55,1.77,1.47), "lagoon")
    ellipsoid(b, (.38,3.37,0), (3.10,1.25,1.42), "cream")
    b.face([(-2.55,4.25),(-3.62,4.50),(-4.39,5.27),(-4.09,4.05),
            (-4.43,3.55),(-3.55,3.74),(-2.60,3.60)],0,.62,"lagoon")
    b.face([(-4.04,4.14),(-4.61,5.18),(-5.22,5.49),(-5.07,4.65),(-4.57,4.13),
            (-5.11,3.94),(-5.40,3.45),(-4.50,3.53)],0,.27,"coral")
    for side in (-1,1):
        b.face([(.24,3.55),(-.62,3.37),(-1.82,2.78),(-1.77,2.51),
                (-1.16,2.64),(-.13,2.96)],side*1.33,.25,"lagoon")
        z = side*1.16
        b.dial((1.75,4.12,z),.61,.40,.22,"gold",40)
        ellipsoid(b,(1.79,4.12,z+side*.11),(.37,.40,.11),"dark")
        if b.level<2:
            ellipsoid(b,(1.91,4.27,z+side*.23),(.096,.096,.027),"light")
            b.beam((2.25,3.66,side*1.14),(2.64,3.57,side*.93),.07,.065,"wood")
            b.beam((2.64,3.57,side*.93),(2.98,3.64,side*.75),.07,.065,"wood")
        for x in (-.96,1.03):
            b.beam((x,2.62,side*.86),(x*.69,1.08,side*.61),.056,.06,"gold")
    b.profile([(.12,.48),(.35,.78),(.94,.85),(1.04,.88)],"wood",n=32)
    for y in ([.34,.54,.74,.96] if b.level==0 else [.41,.95]):
        b.profile([(y,.85),(y+.035,.86)],"gold",n=26)
    # Soft paired fabric spouts make the silhouette recognisable from a distance.
    for side in (-1,1):
        b.beam((.69,5.47,0),(.53+side*.30,6.10,side*.23),.12,.10,"cream")
        ellipsoid(b,(.45+side*.48,6.12,side*.26),(.35,.17,.19),"cream")
