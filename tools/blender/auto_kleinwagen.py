# Kleinwagen (eigenes Design, Fliessheck), 12 x 6.2 Studs wie Verkehr.ARTEN.kleinwagen.
# Braucht den Blender-Text "auto_lib" (tools/blender/auto_lib.py). Front = -Y, Boden z = 0.
import bpy, math
from mathutils import Vector
exec(bpy.data.texts["auto_lib"].as_string())

a = Auto("Auto_Kleinwagen", versatz=(0, -40, 0))
R, RS, SPUR = 1.2, 3.8, 2.55          # Radradius, halbe Achsweite (y), Radmitte (x)
BOGEN = R + 0.35                       # Radlauf-Radius


def unterkante(y, normal=0.62):
    """Unterkante der Karosserie: an den Raedern ein runder Radlauf."""
    for ym in (-RS, RS):
        d = abs(y - ym)
        if d < BOGEN:
            return max(normal, R + math.sqrt(BOGEN ** 2 - d ** 2))
    return normal


def stab(g, p, q, dicke, tiefe=None):
    p, q = Vector(p), Vector(q)
    d = q - p
    e = d.to_track_quat("Y", "Z").to_euler()
    a.box(g, (p + q) / 2, (dicke, d.length, tiefe or dicke), [math.degrees(w) for w in e])


# Karosserie: (y, halbe Breite, Oberkante) – Unterkante kommt aus unterkante()
OBEN = [(-6.0, 2.55, 2.85), (-5.85, 2.85, 3.05), (-5.4, 3.0, 3.2), (-4.0, 3.08, 3.33), (-2.0, 3.1, 3.45),
        (0.0, 3.1, 3.5), (3.0, 3.1, 3.52), (4.8, 3.06, 3.5), (5.5, 2.98, 3.42), (5.85, 2.8, 3.25), (6.0, 2.5, 3.0)]
ys = {y for y, _, _ in OBEN}
for ym in (-RS, RS):
    ys |= {ym + k * BOGEN / 6 for k in range(-6, 7)}          # Radlauf-Bogen
    ys |= {ym - BOGEN - 0.02, ym + BOGEN + 0.02}               # senkrechte Kante davor/dahinter


def zwischen(y, i):
    for (y0, *w0), (y1, *w1) in zip(OBEN, OBEN[1:]):
        if y0 <= y <= y1:
            t = (y - y0) / (y1 - y0)
            return w0[i] + t * (w1[i] - w0[i])
    return OBEN[-1][i + 1]


a.loft("Lack", [(y, zwischen(y, 0), unterkante(y), zwischen(y, 1)) for y in sorted(ys)], n_pkt=28, expo=4.5)
# dunkle Radhaeuser innen (sieht man durch den Radlauf)
for ym in (-RS, RS):
    a.loft("Schwarz", [(ym - BOGEN, 2.85, R - 0.2, R + BOGEN - 0.05), (ym + BOGEN, 2.85, R - 0.2, R + BOGEN - 0.05)], n_pkt=16, expo=6)
    for sx in (-1, 1):
        a.rad(sx * SPUR, ym, R, 1.0)

# Fahrgastzelle: Glas als durchgehender Koerper, Dach und Saeulen in Lack darueber
GLAS = [(-2.1, 2.85, 3.35), (-1.3, 2.78, 4.05), (-0.5, 2.7, 4.7), (0.2, 2.64, 5.05), (0.6, 2.62, 5.12),
        (3.6, 2.62, 5.12), (4.3, 2.64, 4.95), (5.0, 2.7, 4.35), (5.5, 2.78, 3.6)]
def glas_bei(y):
    for (y0, h0, z0), (y1, h1, z1) in zip(GLAS, GLAS[1:]):
        if y0 <= y <= y1:
            t = (y - y0) / (y1 - y0)
            return h0 + t * (h1 - h0), z0 + t * (z1 - z0)
    return GLAS[-1][1:]


# Kabine in Lack (wird zu Saeulen + Dach), Scheiben als leicht groessere Glasstuecke darueber
a.loft("Lack", [(y, hw, 3.2, zo) for y, hw, zo in GLAS], n_pkt=24, expo=5)
for y0, y1 in ((-2.1, 1.6), (2.1, 3.7), (4.45, 5.5)):          # Front+vorne, hinten, Heckscheibe
    stuecke = [y0] + [y for y, _, _ in GLAS if y0 < y < y1] + [y1]
    a.loft("Glas", [(y, glas_bei(y)[0] + 0.04, 3.28, glas_bei(y)[1] + 0.03) for y in stuecke], n_pkt=24, expo=5)
dach = [0.45, 0.6, 1.6, 2.6, 3.6, 4.0, 4.4]                  # Dach folgt der Kabine, deckt die Glasoberkanten
a.loft("Lack", [(y, glas_bei(y)[0] + 0.06, glas_bei(y)[1] - 0.4, glas_bei(y)[1] + 0.06) for y in dach], n_pkt=24, expo=5)
for sx in (-1, 1):
    stab("Schwarz", (sx * 3.03, -2.0, 3.4), (sx * 3.03, 5.3, 3.4), 0.08, 0.12)       # Fensterleiste
    # Tuerfugen + Griffe
    for y in (-1.95, 1.75, 4.55):
        a.box("Schwarz", (sx * 3.115, y, 2.2), (0.03, 0.05, 2.2))
    for y in (1.05, 3.85):
        a.box("Chrom", (sx * 3.13, y, 2.95), (0.06, 0.6, 0.14))
    # Seitenspiegel
    a.box("Lack", (sx * 3.35, -1.55, 3.72), (0.55, 0.45, 0.38))
    a.box("Schwarz", (sx * 3.1, -1.45, 3.6), (0.3, 0.2, 0.15))
    a.box("Glas", (sx * 3.4, -1.32, 3.72), (0.45, 0.04, 0.3))
    # Scheinwerfer, Blinker, Ruecklichter
    a.box("Licht", (sx * 1.95, -5.95, 2.5), (1.25, 0.3, 0.5), (0, 0, -sx * 8), glatt=True)
    a.box("Blinker", (sx * 2.55, -5.75, 2.5), (0.25, 0.3, 0.42), (0, 0, -sx * 30))
    a.box("Ruecklicht", (sx * 2.15, 5.84, 2.75), (0.95, 0.3, 0.7), (0, 0, sx * 10), glatt=True)
    a.box("Licht", (sx * 2.15, 5.9, 2.42), (0.5, 0.25, 0.16), (0, 0, sx * 10))
    a.box("Schwarz", (sx * 2.3, -5.95, 0.95), (0.7, 0.2, 0.25))             # Nebelscheinwerfer-Mulde
# Front: Grill, Stossfaenger, Kennzeichen
a.box("Schwarz", (0, -6.02, 1.55), (2.8, 0.2, 0.55), glatt=True)
for k in range(4):
    a.box("Chrom", (0, -6.1, 1.35 + k * 0.13), (2.6, 0.04, 0.04))
a.box("Schwarz", (0, -5.9, 0.75), (4.6, 0.3, 0.32))
a.box("Kennzeichen", (0, -6.13, 2.05), (1.9, 0.05, 0.45))
a.box("Schwarz", (0, -6.15, 2.05), (2.0, 0.03, 0.55))
# Heck: Klappe, Kennzeichen, Stossfaenger, Spoiler
a.box("Schwarz", (0, 5.9, 0.8), (4.6, 0.3, 0.35))
a.box("Kennzeichen", (0, 6.08, 1.75), (1.9, 0.05, 0.45))
a.box("Schwarz", (0, 6.1, 1.75), (2.0, 0.03, 0.55))
a.box("Lack", (0, 4.5, 5.0), (4.7, 0.45, 0.1), (8, 0, 0))     # Dachspoiler
a.box("Ruecklicht", (0, 4.73, 4.97), (1.2, 0.05, 0.06))
a.box("Chrom", (0, 6.02, 2.35), (1.0, 0.05, 0.12))
result = a.bauen()
