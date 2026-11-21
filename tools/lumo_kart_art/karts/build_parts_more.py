#!/usr/bin/env python3
"""Weitere Leistungsteile der Aurora-Karts und Werkstatt-Werkzeuge (Garage-Ausbau 21.11.).

Baut mit den Hilfen aus build_parts.py (Fasen, gewichtete Normalen, getrennte Materialien)
die Teile der neuen Steckplätze und die zusätzlichen Varianten der bisherigen:

  parts_engine.glb      Engine_Charger, Engine_Light, Engine_Hybrid        (engine_deck)
  parts_tires.glb       Tire_Slick, Tire_Soft                              (wheel_axis)
  parts_wing.glb        Wing_Flap, Wing_Fin                                (wing_deck)
  parts_booster.glb     Booster_Twin, Booster_Igniter, Booster_Cool        (booster_side)
  parts_suspension.glb  Damper_Offroad, Damper_Air                         (damper_upright)
  parts_steering.glb    Steer_Direct/Calm/Servo/Air/Track                  (front_axle)
  parts_brakes.glb      Brake_<X> (Sattel am Radträger) + Brake_<X>Disc (Scheibe am Rad)
  parts_gearbox.glb     Gear_Short/Long/Overdrive/Crawler/Locker           (rear_axle)
  parts_ballast.glb     Ballast_Front/Rear/Low/Heavy/Light                 (chassis)
  garage_tools.glb      Tool_Jack (Wagenheber), Tool_DynoRoller (Prüfstand-Rollen)

Koordinaten wie im Spiel (Godot, Meter, +Y oben, +Z hinten). Montagepunkte: front_axle /
rear_axle = Knoten FrontAxle / RearAxle der Karosserie (Comet-Maße; das Spiel streckt X auf
die Spurweite), chassis = Kart-Ursprung (Seitenteile auf Comet-Seitenwand x = 0.83, das Spiel
streckt X auf die Karosserie), Bremsen: Sattel am Radträger Steer_XX, Scheibe am Rad Wheel_XX
(beide +X = außen, links gespiegelt). Alles eigene Geometrie, keine fremden Vorlagen.

Aufruf: /home/user/tools/bpyenv/bin/python tools/lumo_kart_art/karts/build_parts_more.py
        [--groups=parts_engine,...] [--thumbs] [--only=Name,Name]
Die Teilebilder (thumbs/<Knoten>.png, Serie_<slot>.png für die neuen Steckplätze) nutzen
dieselbe Studio-Kamera wie build_parts.py.
"""
from __future__ import annotations

import importlib.util
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

HERE = Path(__file__).resolve().parent
_spec = importlib.util.spec_from_file_location("build_parts", HERE / "build_parts.py")
BP = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(BP)

g, lathe, prism, box, sweep, helix, oriented = BP.g, BP.lathe, BP.prism, BP.box, BP.sweep, BP.helix, BP.oriented
OUT = BP.OUT
BP.MOUNTS.update({
    "Steer": "front_axle",
    "Brake": "wheel_brake",
    "Gear": "rear_axle",
    "Ballast": "chassis",
    "Tool": "garage_floor",
})
TIRE_R = BP.TIRE_R


def mats():
    m = BP.mats()
    m.update({
        "white": BP.material("PartWhite", "f2f4f8", 0.1, 0.35),
        "orange": BP.material("PartOrange", "ff7a1a", 0.2, 0.4),
        "green": BP.material("PartGreen", "56ff8a", 0.0, 0.4, emission=2.6),
        "carbon": BP.material("PartCarbon", "20242c", 0.25, 0.22),
        "steel": BP.material("PartSteel", "8d96a3", 0.85, 0.32),
        "gold": BP.material("PartGold", "e3b23c", 0.9, 0.22),
    })
    return m


def root(name):
    return BP.root_node(name)


def place(obj, matrix):
    """Setzt ein (bereits gebautes) Objekt um einen Drehpunkt, z. B. eine hochgeklappte Klappe."""
    obj.matrix_parent_inverse = Matrix.Identity(4)
    obj.matrix_basis = matrix @ obj.matrix_basis
    return obj


def rot_about(pivot, axis, angle):
    p = g(pivot)
    return Matrix.Translation(p) @ Matrix.Rotation(angle, 4, g(axis)) @ Matrix.Translation(-p)


def stripes(prefix, origin, size, count, m, parent, axis="x"):
    """Gelb-schwarze Warnstreifen als kleine Kästen (Gewichte, Wagenheber)."""
    ox, oy, oz = origin
    sx, sy, sz = size
    for k in range(count):
        t = (k + 0.5) / count - 0.5
        if axis == "x":
            centre, piece = (ox + t * sx, oy, oz), (sx / count * 0.98, sy, sz)
        else:
            centre, piece = (ox, oy, oz + t * sz), (sx, sy, sz / count * 0.98)
        box("%s_%d" % (prefix, k), centre, piece, m["yellow"] if k % 2 == 0 else m["dark"], parent, 0.0)


def bolt(name, at, axis, m, parent, r=0.009):
    x, y, z = at
    if axis == "x":
        lathe(name, [(0.0, r), (0.006, r), (0.009, r * 0.6), (0.010, 0.0)], m["metal"], parent, "x", 12,
              Matrix.Translation(g((x, y, z))))
    elif axis == "-x":
        lathe(name, [(0.0, r), (-0.006, r), (-0.009, r * 0.6), (-0.010, 0.0)], m["metal"], parent, "x", 12,
              Matrix.Translation(g((x, y, z))))
    elif axis == "y":
        lathe(name, [(0.0, r), (0.006, r), (0.009, r * 0.6), (0.010, 0.0)], m["metal"], parent, "y", 12,
              Matrix.Translation(g((x, y, z))))
    else:
        lathe(name, [(0.0, r), (0.006, r), (0.009, r * 0.6), (0.010, 0.0)], m["metal"], parent, "z", 12,
              Matrix.Translation(g((x, y, z))))


def gear_wheel(name, x, radius, teeth, width, mat, parent, centre=(0.0, 0.0)):
    """Zahnrad in der Y-Z-Ebene bei x (Achse X)."""
    outline = []
    for k in range(teeth * 2):
        a = math.pi * k / teeth
        r = radius if k % 2 == 0 else radius * (1.0 - 0.12)
        for da in (-0.25, 0.25):
            aa = a + da * math.pi / teeth
            outline.append((centre[0] + math.cos(aa) * r, centre[1] + math.sin(aa) * r))
    return prism(name, outline, width, mat, parent, "x", x - width * 0.5, 0.002)


# --------------------------------------------------------------------- Motor (engine_deck)
def engine_charger(m):
    r = root("Engine_Charger")
    box("ChargerBlock", (0, 0.05, 0.10), (0.26, 0.10, 0.22), m["dark"], r, 0.012)
    box("ChargerPlate", (0, 0.105, 0.11), (0.22, 0.012, 0.18), m["paint"], r, 0.004)
    # Großer runder Lader oben: Schnecke, Ansaugtrichter zur Seite, Hitzering.
    at = Matrix.Translation(g((0.0, 0.19, 0.07)))
    lathe("ChargerSnail", [(-0.040, 0.0), (-0.040, 0.078), (-0.030, 0.088), (0.030, 0.088), (0.040, 0.078),
                           (0.040, 0.0)], m["metal"], r, "x", 48, at)
    lathe("ChargerHeat", [(-0.050, 0.070), (-0.040, 0.070), (-0.040, 0.0), (-0.050, 0.0)], m["heat"], r, "x", 40, at)
    lathe("ChargerInlet", [(0.040, 0.058), (0.075, 0.062), (0.075, 0.048), (0.040, 0.044)], m["dark"], r, "x", 40,
          at, cap=False)
    lathe("ChargerWheel", [(0.045, 0.044), (0.060, 0.030), (0.062, 0.0)], m["cool"], r, "x", 28, at)
    sweep("ChargerPipe", [(0.0, 0.25, 0.10), (0.0, 0.26, 0.16), (0.0, 0.20, 0.22), (0.0, 0.13, 0.24)], 0.024,
          m["metal"], r, 14)
    box("ChargerCooler", (0, 0.07, 0.245), (0.22, 0.09, 0.03), m["dark"], r, 0.004)
    for k in range(6):
        box("ChargerFin_%d" % k, (0, 0.035 + k * 0.014, 0.262), (0.21, 0.004, 0.006), m["metal"], r, 0.0)
    return r


def engine_light(m):
    r = root("Engine_Light")
    box("LightBlock", (0, 0.035, 0.10), (0.18, 0.07, 0.16), m["carbon"], r, 0.008)
    # Offener Rohrrahmen statt Haube: man sieht, wie wenig dran ist.
    corners = [(-0.12, 0.0), (0.12, 0.0), (0.12, 0.20), (-0.12, 0.20)]
    for k, (x, z) in enumerate(corners):
        sweep("LightPost_%d" % k, [(x, 0.0, z), (x, 0.14, z)], 0.008, m["metal"], r, 8)
    for k in range(4):
        a, b = corners[k], corners[(k + 1) % 4]
        sweep("LightRail_%d" % k, [(a[0], 0.14, a[1]), (b[0], 0.14, b[1])], 0.008, m["metal"], r, 8)
        sweep("LightCross_%d" % k, [(a[0], 0.0, a[1]), (b[0], 0.14, b[1])], 0.006, m["paint"], r, 6)
    box("LightPlate", (0, 0.074, 0.10), (0.16, 0.008, 0.14), m["paint"], r, 0.003)
    for i in range(3):
        for j in range(3):
            lathe("LightHole_%d_%d" % (i, j), [(0.0, 0.014), (0.003, 0.014), (0.003, 0.0)], m["dark"], r, "y", 16,
                  Matrix.Translation(g((-0.05 + i * 0.05, 0.078, 0.05 + j * 0.05))))
    lathe("LightIntake", [(0.08, 0.020), (0.13, 0.026), (0.135, 0.020), (0.10, 0.014)], m["metal"], r, "y", 24,
          Matrix.Translation(g((0.0, 0.0, 0.03))))
    lathe("LightGlow", [(0.09, 0.014), (0.128, 0.020), (0.128, 0.0)], m["glow"], r, "y", 16,
          Matrix.Translation(g((0.0, 0.0, 0.03))))
    return r


def engine_hybrid(m):
    r = root("Engine_Hybrid")
    box("HybridBlock", (0, 0.045, 0.12), (0.26, 0.09, 0.20), m["dark"], r, 0.01)
    box("HybridPack", (0, 0.125, 0.07), (0.22, 0.07, 0.14), m["blue"], r, 0.012)
    for i in range(3):
        for j in range(2):
            box("HybridCell_%d_%d" % (i, j), (-0.07 + i * 0.07, 0.163, 0.035 + j * 0.07), (0.05, 0.008, 0.05),
                m["green"], r, 0.002)
    for side in (-1, 1):
        sweep("HybridCable_%d" % side, [(side * 0.11, 0.13, 0.02), (side * 0.15, 0.12, 0.08),
                                        (side * 0.15, 0.08, 0.16), (side * 0.12, 0.06, 0.20)], 0.009,
              m["orange"], r, 8)
    at = Matrix.Translation(g((0.0, 0.07, 0.24)))
    lathe("HybridMotor", [(-0.11, 0.0), (-0.11, 0.05), (-0.10, 0.056), (0.10, 0.056), (0.11, 0.05), (0.11, 0.0)],
          m["metal"], r, "x", 32, at)
    for k, x in enumerate((-0.06, 0.0, 0.06)):
        lathe("HybridRing_%d" % k, [(x - 0.008, 0.058), (x + 0.008, 0.058), (x + 0.008, 0.050), (x - 0.008, 0.050)],
              m["orange"], r, "x", 32, at, cap=False)
    return r


# --------------------------------------------------------------------- Reifen (wheel_axis)
def tire_slick(m):
    r = root("Tire_Slick")
    BP.tire_shell("SlickShell", TIRE_R + 0.004, 0.182, m["rubber"], r)
    for side in (-1, 1):
        BP.sidewall_ring("SlickLine_%d" % side, side * 0.199, 0.300, 0.307, m["white"], r)
        for k in range(4):
            a0 = math.tau * k / 4 + 0.3
            pts = [(side * 0.204, math.cos(a0 + d) * 0.318, math.sin(a0 + d) * 0.318) for d in (0.0, 0.12, 0.24, 0.36)]
            sweep("SlickMark_%d_%d" % (side, k), pts, 0.006, m["white"], r, 6)
    return r


def tire_soft(m):
    r = root("Tire_Soft")
    BP.tire_shell("SoftShell", TIRE_R + 0.006, 0.172, m["rubber"], r)
    for k, x in enumerate((-0.09, -0.03, 0.03, 0.09)):
        lathe("SoftGroove_%d" % k, [(x - 0.004, TIRE_R + 0.0075), (x + 0.004, TIRE_R + 0.0075),
                                    (x + 0.004, TIRE_R + 0.002), (x - 0.004, TIRE_R + 0.002)], m["dark"], r, "x", 72,
              cap=False)
    for side in (-1, 1):
        BP.sidewall_ring("SoftRing_%d" % side, side * 0.197, 0.282, 0.302, m["red"], r)
    return r


# --------------------------------------------------------------------- Flügel (wing_deck)
def wing_flap(m):
    r = root("Wing_Flap")
    BP.wing_plane("FlapMain", 0.82, 0.19, 0.045, 0.27, 0.0, m["paint"], r)
    flap = BP.wing_plane("FlapBlade", 0.78, 0.12, 0.028, 0.33, 0.10, m["dark"], r)
    place(flap, rot_about((0, 0.33, 0.05), (1, 0, 0), math.radians(38)))
    for side in (-1, 1):
        prism("FlapEndplate_%d" % side, [(0.18, -0.15), (0.20, 0.20), (0.46, 0.22), (0.44, -0.08)], 0.014,
              m["dark"], r, "x", side * 0.415 - 0.007, 0.004)
        box("FlapEndStripe_%d" % side, (side * 0.424, 0.42, 0.03), (0.004, 0.03, 0.22), m["red"], r, 0.0)
        sweep("FlapStrut_%d" % side, [(side * 0.15, 0.0, 0.02), (side * 0.15, 0.27, 0.0)], 0.016, m["metal"], r)
        sweep("FlapActuator_%d" % side, [(side * 0.24, 0.29, -0.02), (side * 0.24, 0.40, 0.07)], 0.009,
              m["metal"], r, 8)
        lathe("FlapCylinder_%d" % side, [(0.0, 0.016), (0.07, 0.016), (0.07, 0.0)], m["red"], r, "y", 16,
              oriented((side * 0.24, 0.29, -0.02), (side * 0.24, 0.40, 0.07)))
    return r


def wing_fin(m):
    r = root("Wing_Fin")
    BP.wing_plane("FinLow", 0.70, 0.14, 0.028, 0.16, 0.04, m["dark"], r, camber=0.15)
    # Hohe Haifischflosse in der Mitte: hält das Heck im Drift ruhig.
    outline = [(0.0, -0.14), (0.0, 0.30), (0.05, 0.33), (0.36, 0.14), (0.38, 0.04), (0.14, -0.10)]
    prism("FinBlade", outline, 0.018, m["paint"], r, "x", -0.009, 0.005)
    sweep("FinEdge", [(0.0, 0.05, -0.12), (0.0, 0.21, -0.02), (0.0, 0.37, 0.04)], 0.008, m["cool"], r, 8)
    for side in (-1, 1):
        prism("FinSide_%d" % side, [(0.10, -0.04), (0.12, 0.10), (0.24, 0.12), (0.22, -0.02)], 0.01, m["metal"],
              r, "x", side * 0.35 - 0.005, 0.003)
        sweep("FinStrut_%d" % side, [(side * 0.12, 0.0, 0.03), (side * 0.12, 0.16, 0.04)], 0.014, m["metal"], r)
    return r


# --------------------------------------------------------------------- Turbo (booster_side)
def booster_twin(m):
    r = root("Booster_Twin")
    for k, y in enumerate((0.034, -0.034)):
        at = Matrix.Translation(g((0.0, y, 0.0)))
        lathe("TwinTank_%d" % k, [(-0.15, 0.0), (-0.14, 0.024), (-0.12, 0.032), (0.11, 0.032), (0.13, 0.026),
                                  (0.15, 0.0)], m["metal"], r, "z", 28, at)
        for j, z in enumerate((-0.07, 0.04)):
            lathe("TwinBand_%d_%d" % (k, j), [(z - 0.01, 0.034), (z + 0.01, 0.034), (z + 0.01, 0.028),
                                              (z - 0.01, 0.028)], m["red"], r, "z", 28, at, cap=False)
    box("TwinJoin", (0.0, 0.0, 0.15), (0.05, 0.11, 0.04), m["dark"], r, 0.006)
    lathe("TwinNozzle", [(0.16, 0.030), (0.21, 0.040), (0.21, 0.030), (0.17, 0.022)], m["metal"], r, "z", 28,
          cap=False)
    lathe("TwinGlow", [(0.17, 0.024), (0.20, 0.030), (0.20, 0.0)], m["glow"], r, "z", 20)
    box("TwinCradle", (-0.02, -0.075, 0.0), (0.05, 0.02, 0.24), m["dark"], r, 0.005)
    return r


def booster_igniter(m):
    r = root("Booster_Igniter")
    lathe("IgniterBody", [(-0.10, 0.0), (-0.09, 0.034), (-0.07, 0.042), (0.08, 0.042), (0.10, 0.034), (0.11, 0.0)],
          m["red"], r, "z", 32)
    for k, z in enumerate((-0.05, -0.015, 0.02, 0.055)):
        at = Matrix.Translation(g((0.0, 0.040, z)))
        lathe("IgniterPlug_%d" % k, [(0.0, 0.010), (0.022, 0.010), (0.024, 0.006), (0.040, 0.005), (0.042, 0.0)],
              m["white"], r, "y", 12, at)
        lathe("IgniterTip_%d" % k, [(0.040, 0.004), (0.052, 0.004), (0.054, 0.0)], m["metal"], r, "y", 10, at)
    sweep("IgniterCoil", helix((0.0, 0.0, -0.08), (0.0, 0.0, 0.09), 0.047, 5, 12), 0.005, m["glow"], r, 6,
          closed_ends=True)
    lathe("IgniterCap", [(0.10, 0.036), (0.13, 0.030), (0.13, 0.0)], m["metal"], r, "z", 28)
    box("IgniterBracket", (-0.02, -0.055, 0.0), (0.05, 0.03, 0.16), m["dark"], r, 0.005)
    return r


def booster_cool(m):
    r = root("Booster_Cool")
    box("CoolCore", (0.0, 0.0, 0.0), (0.05, 0.11, 0.22), m["dark"], r, 0.006)
    for k in range(9):
        box("CoolFin_%d" % k, (0.027, -0.045 + k * 0.011, 0.0), (0.006, 0.004, 0.20), m["metal"], r, 0.0)
    box("CoolGlow", (0.031, 0.0, 0.0), (0.002, 0.09, 0.18), m["cool"], r, 0.0)
    for side in (-1, 1):
        sweep("CoolPipe_%d" % side, [(0.0, side * 0.05, side * 0.11), (0.0, side * 0.07, side * 0.15),
                                     (-0.02, side * 0.06, side * 0.19)], 0.014, m["blue"], r, 10)
    box("CoolBracket", (-0.03, -0.065, 0.0), (0.03, 0.02, 0.18), m["dark"], r, 0.004)
    return r


# --------------------------------------------------------------------- Fahrwerk (damper_upright)
def damper_offroad(m):
    r = root("Damper_Offroad")
    BP.damper_body("Offroad", m, r, 0.032, m["red"])
    low, high = Vector(BP.DAMPER_LOW), Vector(BP.DAMPER_HIGH)
    sweep("OffroadCoil", helix(tuple(low + (high - low) * 0.08), tuple(high), 0.050, 5.5), 0.011, m["orange"], r, 8)
    # Ausgleichsbehälter neben dem Dämpfer (Huckepack) mit Schlauch.
    side = Vector((0.0, 0.0, 0.065))
    a, b = low + (high - low) * 0.45 + side, low + (high - low) * 0.95 + side
    lathe("OffroadReservoir", [(0.0, 0.0), (0.0, 0.022), ((b - a).length, 0.022), ((b - a).length, 0.0)], m["gold"],
          r, "y", 16, oriented(tuple(a), tuple(b)))
    sweep("OffroadHose", [tuple(high + Vector((0.0, -0.02, 0.0))), tuple(high + Vector((0.0, -0.01, 0.04))),
                          tuple(b)], 0.006, m["dark"], r, 6)
    return r


def damper_air(m):
    r = root("Damper_Air")
    low, high = Vector(BP.DAMPER_LOW), Vector(BP.DAMPER_HIGH)
    length = (high - low).length
    xf = oriented(BP.DAMPER_LOW, BP.DAMPER_HIGH)
    lathe("AirRod", [(0.0, 0.012), (length * 0.4, 0.012), (length * 0.4, 0.0)], m["metal"], r, "y", 16, xf)
    # Gefalteter Luftbalg: abwechselnd dick und schmal.
    profile = [(length * 0.30, 0.0)]
    for k in range(9):
        t = length * (0.30 + 0.07 * k)
        profile.append((t, 0.050 if k % 2 == 0 else 0.038))
    profile.append((length * 0.92, 0.0))
    lathe("AirBellow", profile, m["rubber"], r, "y", 32, xf)
    lathe("AirCap", [(length * 0.90, 0.046), (length * 1.02, 0.046), (length * 1.02, 0.0)], m["metal"], r, "y", 24,
          xf)
    lathe("AirBase", [(length * 0.26, 0.042), (length * 0.32, 0.042), (length * 0.32, 0.0)], m["blue"], r, "y", 24,
          xf)
    sweep("AirLine", [tuple(high + Vector((0.0, 0.02, 0.0))), tuple(high + Vector((0.05, 0.05, 0.03))),
                      tuple(high + Vector((0.10, 0.03, 0.05)))], 0.006, m["cool"], r, 6)
    return r


# --------------------------------------------------------------------- Lenkung (front_axle)
RACK_Y = -0.015
RACK_Z = 0.075
WHEEL_END = 0.575


def steering_base(prefix, m, r, rack_mat, rod_mat, rod_r=0.011):
    lathe(prefix + "Rack", [(-0.24, 0.0), (-0.24, 0.024), (0.24, 0.024), (0.24, 0.0)], rack_mat, r, "x", 24,
          Matrix.Translation(g((0.0, RACK_Y, RACK_Z))))
    for side in (-1, 1):
        boot = [(side * 0.24, 0.0)]
        for k in range(6):
            boot.append((side * (0.24 + 0.012 * k), 0.022 if k % 2 == 0 else 0.016))
        boot.append((side * 0.31, 0.0))
        if side < 0:
            boot.reverse()
        lathe(prefix + "Boot_%d" % side, boot, m["rubber"], r, "x", 20,
              Matrix.Translation(g((0.0, RACK_Y, RACK_Z))))
        sweep(prefix + "Rod_%d" % side, [(side * 0.30, RACK_Y, RACK_Z), (side * WHEEL_END, RACK_Y + 0.02, RACK_Z + 0.03)],
              rod_r, rod_mat, r, 10)
        lathe(prefix + "Ball_%d" % side, [(-0.018, 0.0), (-0.012, 0.016), (0.012, 0.016), (0.018, 0.0)], m["metal"],
              r, "x", 16, Matrix.Translation(g((side * WHEEL_END, RACK_Y + 0.02, RACK_Z + 0.03))))


def steer_direct(m):
    r = root("Steer_Direct")
    steering_base("Direct", m, r, m["red"], m["red"], 0.014)
    box("DirectBox", (0.0, RACK_Y + 0.045, RACK_Z), (0.12, 0.07, 0.07), m["red"], r, 0.008)
    lathe("DirectPinion", [(0.0, 0.022), (0.10, 0.018), (0.10, 0.0)], m["metal"], r, "y", 16,
          Matrix.Translation(g((0.0, RACK_Y + 0.08, RACK_Z))))
    for side in (-1, 1):
        box("DirectArrow_%d" % side, (side * 0.045, RACK_Y + 0.081, RACK_Z), (0.018, 0.003, 0.05), m["yellow"], r, 0.0)
    return r


def steer_calm(m):
    r = root("Steer_Calm")
    steering_base("Calm", m, r, m["blue"], m["metal"])
    # Lenkungsdämpfer: langer Zylinder vor der Zahnstange.
    lathe("CalmDamper", [(-0.28, 0.0), (-0.28, 0.022), (0.12, 0.022), (0.12, 0.0)], m["blue"], r, "x", 20,
          Matrix.Translation(g((0.0, RACK_Y - 0.04, RACK_Z - 0.07))))
    lathe("CalmPiston", [(0.12, 0.009), (0.42, 0.009), (0.42, 0.0)], m["metal"], r, "x", 12,
          Matrix.Translation(g((0.0, RACK_Y - 0.04, RACK_Z - 0.07))))
    for k, x in enumerate((-0.20, 0.0)):
        lathe("CalmRing_%d" % k, [(x - 0.006, 0.024), (x + 0.006, 0.024), (x + 0.006, 0.020), (x - 0.006, 0.020)],
              m["white"], r, "x", 20, Matrix.Translation(g((0.0, RACK_Y - 0.04, RACK_Z - 0.07))), cap=False)
    return r


def steer_servo(m):
    r = root("Steer_Servo")
    steering_base("Servo", m, r, m["dark"], m["metal"])
    at = Matrix.Translation(g((0.13, RACK_Y + 0.055, RACK_Z + 0.02)))
    lathe("ServoMotor", [(-0.07, 0.0), (-0.07, 0.042), (0.06, 0.042), (0.07, 0.035), (0.07, 0.0)], m["metal"], r,
          "z", 28, at)
    for k in range(5):
        z = -0.055 + k * 0.025
        lathe("ServoFin_%d" % k, [(z - 0.004, 0.050), (z + 0.004, 0.050), (z + 0.004, 0.040), (z - 0.004, 0.040)],
              m["dark"], r, "z", 28, at, cap=False)
    lathe("ServoCap", [(0.07, 0.030), (0.08, 0.026), (0.08, 0.0)], m["glow"], r, "z", 20, at)
    sweep("ServoCable", [(0.13, RACK_Y + 0.08, RACK_Z + 0.09), (0.08, RACK_Y + 0.11, RACK_Z + 0.14),
                         (0.02, RACK_Y + 0.09, RACK_Z + 0.18)], 0.007, m["orange"], r, 8)
    return r


def steer_air(m):
    r = root("Steer_Air")
    steering_base("Air", m, r, m["dark"], m["metal"])
    # Kleine Flugruder (Canards) an beiden Seiten der Nase: lenken in der Luft mit.
    for side in (-1, 1):
        fin = BP.wing_plane("AirCanard_%d" % side, 0.16, 0.12, 0.018, 0.20, -0.30, m["paint"], r, camber=0.2)
        place(fin, Matrix.Translation(g((side * 0.36, 0.0, 0.0))) @ rot_about((0, 0.20, -0.30), (0, 0, 1),
                                                                             side * math.radians(-12)))
        box("AirCanardTip_%d" % side, (side * 0.445, 0.20 - side * side * 0.0, -0.30), (0.006, 0.05, 0.10),
            m["cool"], r, 0.0)
        sweep("AirCanardStay_%d" % side, [(side * 0.30, 0.15, -0.30), (side * 0.36, 0.20, -0.30)], 0.008,
              m["metal"], r, 8)
    return r


def steer_track(m):
    r = root("Steer_Track")
    steering_base("Track", m, r, m["yellow"], m["metal"])
    # Stabilisator: gelber U-Bügel quer vor der Achse, Koppelstangen zu den Spurstangen.
    sweep("TrackBar", [(-0.50, RACK_Y - 0.03, RACK_Z - 0.02), (-0.42, RACK_Y - 0.06, RACK_Z - 0.10),
                       (0.42, RACK_Y - 0.06, RACK_Z - 0.10), (0.50, RACK_Y - 0.03, RACK_Z - 0.02)], 0.013,
          m["yellow"], r, 12)
    for side in (-1, 1):
        sweep("TrackLink_%d" % side, [(side * 0.50, RACK_Y - 0.03, RACK_Z - 0.02),
                                      (side * 0.50, RACK_Y + 0.02, RACK_Z + 0.025)], 0.007, m["metal"], r, 8)
        box("TrackClamp_%d" % side, (side * 0.30, RACK_Y - 0.06, RACK_Z - 0.10), (0.04, 0.035, 0.035), m["dark"], r,
            0.004)
    return r


# --------------------------------------------------------------------- Bremse (wheel_brake)
DISC_X = 0.085


def disc(name, radius, inner, mat, parent, thick=0.014):
    return lathe(name, [(DISC_X - thick * 0.5, inner), (DISC_X - thick * 0.5, radius), (DISC_X + thick * 0.5, radius),
                        (DISC_X + thick * 0.5, inner)], mat, parent, "x", 48, cap=False)


def hat(name, mat, parent):
    return lathe(name, [(DISC_X - 0.004, 0.064), (DISC_X + 0.018, 0.064), (DISC_X + 0.020, 0.040),
                        (DISC_X + 0.020, 0.0)], mat, parent, "x", 32)


def caliper(prefix, m, parent, mat, radius=0.165, span=0.62, centre=0.75, thick=0.030):
    pts = []
    for k in range(7):
        a = centre - span * 0.5 + span * k / 6
        pts.append((DISC_X, math.cos(a) * radius, math.sin(a) * radius))
    sweep(prefix + "Body", pts, thick, mat, parent, 12)
    mid = centre
    box(prefix + "Face", (DISC_X + 0.034, math.cos(mid) * radius, math.sin(mid) * radius), (0.008, 0.05, 0.05),
        m["white"], parent, 0.003)
    for k in (0, 6):
        bolt(prefix + "Bolt_%d" % k, (DISC_X + 0.030, pts[k][1], pts[k][2]), "x", m, parent, 0.008)


def brake_sport(m):
    d = root("Brake_SportDisc")
    disc("SportRotor", 0.178, 0.064, m["steel"], d, 0.018)
    hat("SportHat", m["dark"], d)
    for k in range(16):
        a = math.tau * k / 16
        rr = 0.105 + 0.045 * (k % 2)
        lathe("SportDrill_%d" % k, [(DISC_X + 0.0095, 0.007), (DISC_X + 0.0100, 0.007), (DISC_X + 0.0100, 0.0)],
              m["dark"], d, "x", 10, Matrix.Translation(g((0.0, math.cos(a) * rr, math.sin(a) * rr))))
    c = root("Brake_Sport")
    caliper("Sport", m, c, m["red"], 0.170, 0.80, 0.75, 0.036)
    return [c, d]


def brake_light(m):
    d = root("Brake_LightDisc")
    disc("LightRotor", 0.150, 0.064, m["metal"], d, 0.010)
    hat("LightHat", m["gold"], d)
    for k in range(8):
        a = math.tau * k / 8
        sweep("LightSlot_%d" % k, [(DISC_X + 0.0055, math.cos(a) * 0.09, math.sin(a) * 0.09),
                                   (DISC_X + 0.0055, math.cos(a + 0.35) * 0.135, math.sin(a + 0.35) * 0.135)],
              0.004, m["dark"], d, 6)
    c = root("Brake_Light")
    caliper("Light", m, c, m["yellow"], 0.145, 0.42, 0.75, 0.022)
    return [c, d]


def brake_drift(m):
    d = root("Brake_DriftDisc")
    disc("DriftRotor", 0.165, 0.064, m["steel"], d, 0.014)
    hat("DriftHat", m["blue"], d)
    c = root("Brake_Drift")
    caliper("Drift", m, c, m["blue"], 0.160, 0.55, 0.70, 0.028)
    # Zweiter, kleiner Sattel unten: die Handbremse fürs Eindriften.
    caliper("DriftHand", m, c, m["cool"], 0.150, 0.30, 2.35, 0.020)
    return [c, d]


def brake_regen(m):
    d = root("Brake_RegenDisc")
    disc("RegenRotor", 0.165, 0.064, m["steel"], d, 0.014)
    hat("RegenHat", m["dark"], d)
    lathe("RegenCoil", [(DISC_X + 0.008, 0.112), (DISC_X + 0.012, 0.112), (DISC_X + 0.012, 0.124),
                        (DISC_X + 0.008, 0.124)], m["green"], d, "x", 48, cap=False)
    c = root("Brake_Regen")
    caliper("Regen", m, c, m["steel"], 0.162, 0.60, 0.75, 0.030)
    lathe("RegenBox", [(-0.02, 0.0), (-0.02, 0.026), (0.02, 0.026), (0.02, 0.0)], m["green"], c, "x", 16,
          Matrix.Translation(g((DISC_X + 0.02, math.cos(1.4) * 0.17, math.sin(1.4) * 0.17))))
    return [c, d]


def brake_abs(m):
    d = root("Brake_AbsDisc")
    disc("AbsRotor", 0.160, 0.064, m["metal"], d, 0.014)
    hat("AbsHat", m["dark"], d)
    for k in range(24):
        a = math.tau * k / 24
        box("AbsTooth_%d" % k, (DISC_X - 0.012, math.cos(a) * 0.075, math.sin(a) * 0.075), (0.010, 0.010, 0.010),
            m["dark"], d, 0.0)
    c = root("Brake_Abs")
    caliper("Abs", m, c, m["white"], 0.158, 0.55, 0.75, 0.028)
    lathe("AbsSensor", [(0.0, 0.010), (0.04, 0.010), (0.04, 0.0)], m["cool"], c, "x", 12,
          Matrix.Translation(g((DISC_X - 0.06, math.cos(2.0) * 0.08, math.sin(2.0) * 0.08))))
    return [c, d]


# --------------------------------------------------------------------- Getriebe (rear_axle)
def gear_base(prefix, m, r, housing):
    lathe(prefix + "Housing", [(-0.09, 0.0), (-0.09, 0.055), (-0.06, 0.075), (0.06, 0.075), (0.09, 0.055),
                               (0.09, 0.0)], housing, r, "x", 32)
    for side in (-1, 1):
        sweep(prefix + "Shaft_%d" % side, [(side * 0.09, 0.0, 0.0), (side * 0.56, 0.0, 0.0)], 0.017, m["metal"], r,
              12)
        for k, x in enumerate((0.13, 0.50)):
            boot = [(-0.03, 0.0), (-0.03, 0.020), (-0.015, 0.030), (0.0, 0.022), (0.015, 0.030), (0.03, 0.020),
                    (0.03, 0.0)]
            lathe(prefix + "Boot_%d_%d" % (side, k), boot, m["rubber"], r, "x", 18,
                  Matrix.Translation(g((side * x, 0.0, 0.0))))


def gear_short(m):
    r = root("Gear_Short")
    gear_base("Short", m, r, m["dark"])
    gear_wheel("ShortSprocket", 0.31, 0.13, 30, 0.012, m["red"], r)
    lathe("ShortHub", [(0.29, 0.0), (0.29, 0.04), (0.33, 0.04), (0.33, 0.0)], m["metal"], r, "x", 24)
    return r


def gear_long(m):
    r = root("Gear_Long")
    gear_base("Long", m, r, m["blue"])
    gear_wheel("LongSprocket", 0.31, 0.068, 14, 0.012, m["metal"], r)
    lathe("LongHub", [(0.29, 0.0), (0.29, 0.03), (0.33, 0.03), (0.33, 0.0)], m["blue"], r, "x", 24)
    return r


def gear_overdrive(m):
    r = root("Gear_Overdrive")
    gear_base("Over", m, r, m["dark"])
    gear_wheel("OverSprocket", 0.31, 0.10, 22, 0.012, m["metal"], r)
    lathe("OverRing", [(0.29, 0.060), (0.33, 0.060), (0.33, 0.052), (0.29, 0.052)], m["glow"], r, "x", 32,
          cap=False)
    # Zusatzgang als leuchtende Trommel neben dem Gehäuse.
    lathe("OverDrum", [(-0.20, 0.0), (-0.20, 0.05), (-0.11, 0.05), (-0.11, 0.0)], m["heat"], r, "x", 28)
    lathe("OverDrumGlow", [(-0.165, 0.052), (-0.145, 0.052), (-0.145, 0.046), (-0.165, 0.046)], m["glow"], r, "x",
          28, cap=False)
    return r


def gear_crawler(m):
    r = root("Gear_Crawler")
    gear_base("Crawl", m, r, m["steel"])
    box("CrawlBlock", (0.0, 0.08, 0.0), (0.16, 0.06, 0.14), m["steel"], r, 0.01)
    gear_wheel("CrawlBig", 0.31, 0.12, 28, 0.012, m["green"], r)
    gear_wheel("CrawlSmall", -0.31, 0.06, 12, 0.012, m["green"], r)
    for k, x in enumerate((-0.31, 0.31)):
        lathe("CrawlHub_%d" % k, [(x - 0.02, 0.0), (x - 0.02, 0.03), (x + 0.02, 0.03), (x + 0.02, 0.0)], m["dark"],
              r, "x", 20)
    return r


def gear_locker(m):
    r = root("Gear_Locker")
    gear_base("Lock", m, r, m["dark"])
    for side in (-1, 1):
        lathe("LockRing_%d" % side, [(side * 0.06 - 0.012, 0.082), (side * 0.06 + 0.012, 0.082),
                                     (side * 0.06 + 0.012, 0.070), (side * 0.06 - 0.012, 0.070)], m["yellow"], r,
              "x", 32, cap=False)
    for k in range(8):
        a = math.tau * k / 8
        box("LockPin_%d" % k, (0.0, math.cos(a) * 0.078, math.sin(a) * 0.078), (0.05, 0.012, 0.012), m["metal"], r,
            0.002)
    gear_wheel("LockSprocket", 0.31, 0.09, 20, 0.012, m["yellow"], r)
    return r


# --------------------------------------------------------------------- Gewicht (chassis)
SIDE_X = 0.835


def weight_block(prefix, centre, size, m, parent):
    box(prefix, centre, size, m["steel"], parent, 0.01)
    cx, cy, cz = centre
    sx, sy, sz = size
    stripes(prefix + "Stripe", (cx, cy + sy * 0.5 + 0.002, cz), (sx * 0.9, 0.004, sz * 0.35), 6, m, parent)
    for k, dx in enumerate((-0.35, 0.35)):
        bolt(prefix + "Bolt_%d" % k, (cx + dx * sx, cy + sy * 0.5, cz + sz * 0.3), "y", m, parent, 0.010)


def ballast_front(m):
    r = root("Ballast_Front")
    for side in (-1, 1):
        weight_block("FrontWeight_%d" % side, (side * 0.40, 0.31, -1.04), (0.14, 0.09, 0.15), m, r)
        sweep("FrontStay_%d" % side, [(side * 0.40, 0.27, -0.97), (side * 0.30, 0.30, -0.88)], 0.010, m["metal"], r,
              8)
    return r


def ballast_rear(m):
    r = root("Ballast_Rear")
    for side in (-1, 1):
        weight_block("RearWeight_%d" % side, (side * 0.30, 0.30, 1.17), (0.15, 0.10, 0.10), m, r)
        box("RearHanger_%d" % side, (side * 0.30, 0.25, 1.17), (0.05, 0.05, 0.12), m["dark"], r, 0.004)
    return r


def ballast_low(m):
    r = root("Ballast_Low")
    for side in (-1, 1):
        sweep("LowRail_%d" % side, [(side * (SIDE_X - 0.03), 0.11, -0.30), (side * (SIDE_X - 0.01), 0.10, -0.22),
                                    (side * (SIDE_X - 0.01), 0.10, 0.22), (side * (SIDE_X - 0.03), 0.11, 0.30)],
              0.028, m["blue"], r, 14)
        for k, z in enumerate((-0.12, 0.0, 0.12)):
            lathe("LowPuck_%d_%d" % (side, k), [(-0.03, 0.0), (-0.03, 0.040), (0.03, 0.040), (0.03, 0.0)],
                  m["steel"], r, "z", 20, Matrix.Translation(g((side * (SIDE_X - 0.01), 0.10, z))))
    box("LowPlate", (0.0, 0.07, 0.0), (1.2, 0.02, 0.5), m["carbon"], r, 0.006)
    return r


def ballast_heavy(m):
    r = root("Ballast_Heavy")
    for side in (-1, 1):
        box("HeavyPlate_%d" % side, (side * (SIDE_X + 0.02), 0.165, 0.0), (0.04, 0.13, 0.50), m["steel"], r, 0.012)
        stripes("HeavyStripe_%d" % side, (side * (SIDE_X + 0.042), 0.205, 0.0), (0.004, 0.03, 0.44), 8, m, r, "z")
        for k, z in enumerate((-0.2, -0.07, 0.07, 0.2)):
            bolt("HeavyBolt_%d_%d" % (side, k), (side * (SIDE_X + 0.04), 0.13, z), "x" if side > 0 else "-x", m, r,
                 0.011)
    return r


def ballast_light(m):
    r = root("Ballast_Light")
    for side in (-1, 1):
        box("LightPanel_%d" % side, (side * (SIDE_X + 0.008), 0.16, 0.0), (0.014, 0.10, 0.48), m["carbon"], r, 0.004)
        for k in range(7):
            z = -0.18 + k * 0.06
            lathe("LightDot_%d_%d" % (side, k), [(0.0, 0.016), (0.003, 0.016), (0.003, 0.0)], m["cool"], r, "x", 16,
                  Matrix.Translation(g((side * (SIDE_X + 0.016), 0.16, z))) @ (
                      Matrix.Scale(-1, 4, Vector((1, 0, 0))) if side < 0 else Matrix.Identity(4)))
        for k in range(3):
            z = 0.24 - k * 0.025
            sweep("LightChevron_%d_%d" % (side, k), [(side * (SIDE_X + 0.017), 0.19, z - 0.02),
                                                     (side * (SIDE_X + 0.017), 0.16, z),
                                                     (side * (SIDE_X + 0.017), 0.13, z - 0.02)], 0.004, m["white"],
                  r, 6)
    return r


# --------------------------------------------------------------------- Werkzeuge
def tool_jack(m):
    r = root("Tool_Jack")
    box("JackBase", (0.0, 0.015, 0.0), (0.16, 0.03, 0.30), m["red"], r, 0.006)
    box("JackPad", (0.0, 0.215, 0.0), (0.12, 0.02, 0.10), m["rubber"], r, 0.006)
    box("JackSaddle", (0.0, 0.195, 0.0), (0.10, 0.025, 0.14), m["red"], r, 0.006)
    # Scherenarme (Rauten) zwischen Fuß und Teller, Spindel mit Kurbel.
    for side in (-1, 1):
        pts = [(side * 0.05, 0.03, -0.11), (side * 0.05, 0.11, -0.02), (side * 0.05, 0.19, -0.11)]
        sweep("JackArmA_%d" % side, pts[:2], 0.010, m["steel"], r, 8)
        sweep("JackArmB_%d" % side, pts[1:], 0.010, m["steel"], r, 8)
        pts = [(side * 0.05, 0.03, 0.11), (side * 0.05, 0.11, 0.02), (side * 0.05, 0.19, 0.11)]
        sweep("JackArmC_%d" % side, pts[:2], 0.010, m["steel"], r, 8)
        sweep("JackArmD_%d" % side, pts[1:], 0.010, m["steel"], r, 8)
    sweep("JackScrew", [(0.0, 0.11, -0.16), (0.0, 0.11, 0.16)], 0.008, m["metal"], r, 10)
    sweep("JackCrank", [(0.0, 0.11, 0.16), (0.0, 0.11, 0.22), (0.07, 0.11, 0.24)], 0.008, m["dark"], r, 8)
    stripes("JackStripe", (0.0, 0.031, 0.0), (0.12, 0.003, 0.26), 6, m, r, "z")
    return r


def tool_dyno_roller(m):
    r = root("Tool_DynoRoller")
    box("DynoFrame", (0.0, -0.04, 0.0), (2.0, 0.06, 0.46), m["steel"], r, 0.012)
    for side in (-1, 1):
        box("DynoRail_%d" % side, (0.0, -0.005, side * 0.21), (2.0, 0.02, 0.04), m["yellow"], r, 0.004)
    for k, z in enumerate((-0.10, 0.10)):
        lathe("DynoRoller_%d" % k, [(-0.95, 0.0), (-0.95, 0.075), (0.95, 0.075), (0.95, 0.0)], m["metal"], r, "x",
              32, Matrix.Translation(g((0.0, -0.035, z))))
        for j, x in enumerate((-0.77, 0.77)):
            for q in range(6):
                xx = x - 0.15 + q * 0.06
                lathe("DynoGrip_%d_%d_%d" % (k, j, q), [(xx - 0.008, 0.077), (xx + 0.008, 0.077),
                                                         (xx + 0.008, 0.070), (xx - 0.008, 0.070)], m["dark"], r,
                      "x", 32, Matrix.Translation(g((0.0, -0.035, z))), cap=False)
    stripes("DynoStripe", (0.0, -0.009, 0.0), (1.9, 0.002, 0.06), 16, m, r)
    return r


BUILDERS = {
    "parts_engine": [engine_charger, engine_light, engine_hybrid],
    "parts_tires": [tire_slick, tire_soft],
    "parts_wing": [wing_flap, wing_fin],
    "parts_booster": [booster_twin, booster_igniter, booster_cool],
    "parts_suspension": [damper_offroad, damper_air],
    "parts_steering": [steer_direct, steer_calm, steer_servo, steer_air, steer_track],
    "parts_brakes": [brake_sport, brake_light, brake_drift, brake_regen, brake_abs],
    "parts_gearbox": [gear_short, gear_long, gear_overdrive, gear_crawler, gear_locker],
    "parts_ballast": [ballast_front, ballast_rear, ballast_low, ballast_heavy, ballast_light],
    "garage_tools": [tool_jack, tool_dyno_roller],
}


def build(groups):
    BP.reset()
    m = mats()
    roots = {}
    for group in groups:
        made = []
        for fn in BUILDERS[group]:
            result = fn(m)
            made.extend(result if isinstance(result, list) else [result])
        roots[group] = made
    BP.apply_modifiers()
    return roots


def descendants(obj):
    out = [obj]
    for child in obj.children:
        out.extend(descendants(child))
    return out


def export(roots):
    OUT.mkdir(parents=True, exist_ok=True)
    for group, items in roots.items():
        bpy.ops.object.select_all(action="DESELECT")
        for item in items:
            for o in descendants(item):
                o.select_set(True)
        path = OUT / (group + ".glb")
        bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", export_apply=True, export_yup=True,
                                  export_extras=True, export_animations=False, use_selection=True)
        tris = {}
        for item in items:
            count = 0
            for o in descendants(item):
                if o.type == "MESH":
                    o.data.calc_loop_triangles()
                    count += len(o.data.loop_triangles)
            tris[item.name] = count
        print("[KartPartsMore] %s %.0f KB triangles %s" % (path.name, path.stat().st_size / 1024, tris))


# Studio-Kamera je Teileart: (Zielpunkt relativ zum Montagepunkt, Blickrichtung, Bildbreite m).
THUMB_CAMERA = dict(BP.THUMB_CAMERA)
THUMB_CAMERA.update({
    "steering": ((0.0, 0.02, 0.05), (0.55, 0.65, -1.0), 1.30),
    "brakes": ((0.08, 0.0, 0.0), (1.0, 0.30, -0.45), 0.46),
    "gearbox": ((0.0, 0.0, 0.0), (0.45, 0.55, 1.0), 1.30),
    "ballast": ((0.0, 0.25, 0.0), (1.0, 0.65, -0.55), 2.30),
})
THUMB_KIND = dict(BP.THUMB_KIND)
THUMB_KIND.update({"Steer": "steering", "Brake": "brakes", "Gear": "gearbox", "Ballast": "ballast"})
# Wo die Teile am Comet sitzen (Godot-Koordinaten), für die Bilder mit Karosserie.
MOUNT_AT = {
    "steering": (0.0, 0.35, -0.66),
    "gearbox": (0.0, 0.35, 0.66),
    "ballast": (0.0, 0.0, 0.0),
    "engine": (0.0, 0.64, 0.70),
    "wing": (0.0, 0.66, 1.00),
    "booster": (0.29, 0.68, 0.86),
}


def render_thumbs(roots):
    thumbs = OUT / "thumbs"
    thumbs.mkdir(parents=True, exist_ok=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 32
    scene.cycles.use_denoising = True
    scene.cycles.device = "CPU"
    scene.render.film_transparent = True
    scene.render.resolution_x = 256
    scene.render.resolution_y = 256
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    world = bpy.data.worlds.new("Studio")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.6, 0.7, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.8
    scene.world = world
    key = bpy.data.lights.new("Key", "AREA")
    key.energy = 60
    key.size = 0.8
    key_o = bpy.data.objects.new("Key", key)
    bpy.context.collection.objects.link(key_o)
    rim = bpy.data.lights.new("Rim", "AREA")
    rim.energy = 35
    rim.color = (1.0, 0.75, 0.5)
    rim_o = bpy.data.objects.new("Rim", rim)
    bpy.context.collection.objects.link(rim_o)
    cam = bpy.data.cameras.new("Cam")
    cam.type = "ORTHO"
    cam_o = bpy.data.objects.new("Cam", cam)
    bpy.context.collection.objects.link(cam_o)
    scene.camera = cam_o
    only = None
    for arg in sys.argv:
        if arg.startswith("--only="):
            only = arg[7:].split(",")
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(BP.ROOT / "assets/kart/production/karts/aurora_comet.glb"))
    kart_objects = [o for o in bpy.data.objects if o not in before]
    by_name = {o.name: o for o in kart_objects}
    wheel_fr = by_name["Wheel_FR"].matrix_world.translation.copy()
    every = [item for items in roots.values() for item in items]
    shots = [(item.name, item) for item in every if not item.name.endswith("Disc") and not item.name.startswith("Tool_")]
    for slot in ("steering", "brakes", "gearbox", "ballast"):
        shots.append(("Serie_" + slot, None))
    with_body = ("steering", "gearbox", "ballast")
    for name, item in shots:
        if only and name not in only:
            continue
        kind = THUMB_KIND.get(name.split("_")[0], name.split("_", 1)[-1])
        shown = []
        if item is not None:
            shown = [item]
            if kind == "brakes":
                shown.append(next(r for r in every if r.name == name + "Disc"))
        for other in every:
            other.location = (0, 0, 0)
            for o in descendants(other)[1:]:
                o.hide_render = other not in shown
        if kind in with_body:
            # Mit Karosserie: man sieht, wo das Teil am Kart sitzt.
            origin = g(MOUNT_AT[kind])
            for o in kart_objects:
                o.hide_render = False
        elif kind in ("brakes", "tires"):
            # Am echten Vorderrad (Bremse ohne Rad, damit Scheibe und Sattel frei liegen).
            origin = wheel_fr
            for o in kart_objects:
                o.hide_render = o.name != "Wheel_FR_Mesh" or (kind == "brakes" and item is not None)
        else:
            origin = Vector((0, 0, 0))
            for o in kart_objects:
                o.hide_render = True
        for part in shown:
            part.location = origin
        offset, view, scale = THUMB_CAMERA[kind]
        if item is not None and kind not in with_body and kind != "brakes":
            origin = Vector((0, 0, 0))
        target = origin + g(offset)
        cam.ortho_scale = scale
        cam_o.location = target + g(view).normalized() * 4.0
        cam_o.rotation_euler = (target - cam_o.location).to_track_quat("-Z", "Y").to_euler()
        key_o.location = target + g((0.8, 1.2, -0.6))
        key_o.rotation_euler = (target - key_o.location).to_track_quat("-Z", "Y").to_euler()
        rim_o.location = target + g((-0.6, 0.8, 0.9))
        rim_o.rotation_euler = (target - rim_o.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = str(thumbs / (name + ".png"))
        bpy.ops.render.render(write_still=True)
        print("[KartPartsMore] thumb", scene.render.filepath)


if __name__ == "__main__":
    groups = list(BUILDERS)
    for arg in sys.argv:
        if arg.startswith("--groups="):
            groups = arg[9:].split(",")
    built = build(groups)
    if "--no-export" not in sys.argv:
        export(built)
    if "--thumbs" in sys.argv:
        render_thumbs(built)
