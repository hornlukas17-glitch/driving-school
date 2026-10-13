"""Runde Karosserie für den Sportwagen "Velocity GT" (eigenes Design, keine echte Marke):
flacher, breiter Keil mit Mittelmotor-Proportionen, Kabine weit vorne, breite Hüften hinten.

Passt zu Auto.MODELLE.sport: Räder R = 1.3 bei x = ±3.3, z = ±5.0, Länge 15.5.
Aufruf:  python3 tools/mesh/sport.py  ->  dist/mesh/VelocityGT.obj, tools/mesh/sport_info.json, src/Karosserien.lua
"""
import math
from basis import Form, glatt, loft, sauber, zusammen, doppelseitig, dach_teil, saeulen_teil, verkleidung_teil, teil, erzeugen, linie

LH = 7.75              # halbe Länge
ACHSE = 5.0
RAD_R = 1.3
BOGEN_R = 1.75
DACH = 4.6
SITZ_Y = 1.25          # tiefer sitzen als im Block-Auto, damit das Dach flach sein kann


# ---------------- Unterteil ----------------
def halbbreite(z):
    u = abs(z) / LH
    n = 3.6 if z < 0 else 7.0                  # flache, breite Nase, kantiges Heck
    w = 3.72 + 0.2 * glatt((z + 1.0) / 6.0)    # nach hinten breiter
    a = w * max(0.0, 1 - u ** n) ** (1 / n)
    d = abs(z - ACHSE) / 2.4                   # kräftige Hüften über den Hinterrädern
    if d < 1:
        a += 0.14 * (1 - d * d) ** 2
    d = abs(z + ACHSE) / 2.0                   # leichte Kotflügel vorne
    if d < 1 and z > -LH + 0.6:
        a += 0.07 * (1 - d * d) ** 2
    return a


def bogen(z):
    """Höhe des Radhauses (nur außen, siehe Form.querschnitt_unten)"""
    for rz in (-ACHSE, ACHSE):
        dz = z - rz
        if abs(dz) < BOGEN_R:
            return 0.55 + 2.25 * math.sqrt(1 - (dz / BOGEN_R) ** 2)
    return 0


def boden(z):
    b = 0.55
    if z < -6.9:                               # Nase vorne leicht angehoben
        b = max(b, 0.55 + 0.3 * ((-6.9 - z) / (LH - 6.9)) ** 1.5)
    if z > 6.9:
        b = max(b, 0.55 + 0.45 * ((z - 6.9) / (LH - 6.9)) ** 1.5)
    return b


def oben(z):
    if z < -2.0:                               # Keil: Haube steigt von der flachen Nase zur Scheibe
        t = max(0.0, (z + LH) / (LH - 2.0))
        return 1.62 + 0.98 * t ** 0.55
    if z < 3.4:                                # Gürtellinie steigt zum Motor hin an
        return 2.58 + 0.47 * glatt((z + 2.0) / 5.4)
    if z < 7.0:                                # flaches Motordeck
        return 3.05
    return 3.05 - 0.25 * glatt((z - 7.0) / (LH - 7.0))


# ---------------- Kabine (Glas) ----------------
G_VON, G_BIS = -2.3, 6.7


def gh_unten(z):
    return oben(min(max(z, -2.25), 6.9)) - 0.05


def gh_oben(z):
    if z < 0.45:                               # sehr flache Frontscheibe
        t = (z - G_VON) / (0.45 - G_VON)
        return gh_unten(G_VON) + (DACH - gh_unten(G_VON)) * (1 - (1 - t) ** 1.7)
    if z <= 1.9:                               # kurzes Dach
        return DACH + 0.03 * math.sin(math.pi * (z - 0.45) / 1.45)
    t = (z - 1.9) / (G_BIS - 1.9)              # lange, flache Motorabdeckung
    return DACH - (DACH - gh_unten(G_BIS) - 0.04) * (1 - (1 - t) ** 1.25)


def gh_breite(z, y):
    unten = gh_unten(z)
    hoehe = (y - unten) / max(0.1, DACH - unten)
    w = 3.2 - 0.9 * max(0.0, hoehe) ** 1.15
    w *= 1 - 0.1 * glatt((z - 2.0) / 3.5)      # hinten schmaler (zwischen den Hüften)
    u = (z - (G_VON + G_BIS) / 2) / ((G_BIS - G_VON) / 2)
    return w * max(0.0, 1 - abs(u) ** 5) ** (1 / 5)


form = Form(halbbreite=halbbreite, boden=boden, oben=oben, gh_oben=gh_oben, gh_breite=gh_breite, gh_unten=gh_unten,
            g_von=G_VON, g_bis=G_BIS, lh=LH, n_unten=4.5, n_glas=5.0, bogen=bogen, kotfluegel=0.22)


def kante(z):
    """Oberkante der schwarzen Verkleidung: Schweller, Splitter vorne, Diffusor hinten"""
    k = 0.95
    if bogen(z) > 0:
        k = max(k, bogen(z) + 0.14)
    if z < -6.9:
        k = max(k, 0.95 + 0.2 * glatt((-6.9 - z) / 0.8))
    if z > 6.5:
        k = max(k, 0.95 + 0.6 * glatt((z - 6.5) / 1.0))
    return k


def anbauteile():
    def vorne(x, y, tiefe): return [x, y, form.front_z(x, y) - tiefe / 2 + 0.04]
    def hinten(x, y, tiefe): return [x, y, form.heck_z(x, y) + tiefe / 2 - 0.04]
    def seite(y, z, breite): return [form.seite_x(y, z) + breite / 2 - 0.02, y, z]
    def plus(p, dx=0, dy=0, dz=0): return [p[0] + dx, p[1] + dy, p[2] + dz]
    sw = vorne(2.35, 1.62, 0.25)               # schmale Scheinwerfer oben an den Ecken der Nase
    rl = hinten(2.3, 2.55, 0.15)
    sp = seite(2.42, -1.3, 0.2)
    luft_seite = seite(1.75, 3.15, 0.12)
    deck_z = 7.05
    t = [
        # vorne
        teil("Scheinwerfer", "scheinwerfer", (1.35, 0.16, 0.25), plus(sw, dz=0.05), True, (0, -14, 0)),
        teil("Tagfahrlicht", "neon_weiss", (1.25, 0.05, 0.08), plus(sw, dy=-0.15, dz=0.06), True, (0, -14, 0)),
        teil("Blinker", "blinker", (0.3, 0.14, 0.2), plus(sw, dx=0.75, dz=0.25), True, (0, -14, 0)),
        teil("Lufteinlass", "grill", (3.4, 0.42, 0.1), vorne(0, 0.88, 0.1)),
        teil("Lufteinlass", "grill", (0.95, 0.5, 0.1), vorne(2.55, 0.95, 0.1), True, (0, -20, 0)),
        teil("Frontsplitter", "carbon", (5.8, 0.07, 0.45), plus(vorne(0, 0.72, 0.1), dy=-0.12, dz=0.12)),
        teil("Haubenkante", "schwarz", (2.2, 0.04, 0.6), [0, form.oben_y(0, -5.2) + 0.01, -5.2], False, (-11, 0, 0)),
        # Seite
        teil("Spiegel", "lack", (0.55, 0.38, 0.75), plus(sp, dx=0.42, dy=0.18), True),
        teil("Spiegelfuss", "schwarz", (0.45, 0.12, 0.3), plus(sp, dx=0.08, dy=0.05, dz=0.1), True),
        teil("Seitenlufteinlass", "grill", (0.06, 0.8, 1.6), plus(luft_seite, dx=-0.05), True, (0, 6, 0)),
        # hinten
        teil("Ruecklicht", "neon_rot", (1.6, 0.13, 0.15), plus(rl, dz=-0.02), True),
        teil("Ruecklichtband", "neon_rot", (1.6, 0.06, 0.08), hinten(0, 2.55, 0.08)),
        teil("Blinker", "blinker", (0.3, 0.13, 0.15), plus(rl, dx=0.95, dz=-0.04), True),
        teil("Heckgitter", "schwarz", (5.2, 0.55, 0.08), hinten(0, 1.95, 0.08)),
        teil("Auspuff", "chrom", (0.5, 0.32, 0.4), plus(hinten(0.45, 1.25, 0.4), dz=-0.05), True),
        teil("Diffusor", "carbon", (4.6, 0.08, 0.9), [0, 0.98, 7.2]),
        teil("Abrisskante", "lack", (5.8, 0.1, 0.65), [0, oben(deck_z) + 0.05, deck_z + 0.2], False, (-9, 0, 0)),
        teil("Motorgitter", "schwarz", (2.6, 0.04, 1.6), [0, gh_oben(5.3) + 0.02, 5.3], False, (-12, 0, 0)),
    ]
    for z0 in (-1.95, 1.9):
        t += linie("Fuge", [[form.seite_x(y, z0) + 0.005, y, z0] for y in (1.0, 1.5, 2.0, 2.42)], spiegeln=True)
    t += linie("Fuge", [[2.0, form.oben_y(2.0, z) + 0.008, z] for z in (-7.1, -6.0, -4.5, -3.0, -2.4)], spiegeln=True)
    kennz = {"vorne": [1.42, form.front_z(0, 1.42) - 0.06], "hinten": [1.95 + 0.0, form.heck_z(0, 1.95) + 0.08]}
    # Heckflügel aus dem Tuning: über dem Motordeck
    return t, kennz, [oben(6.6) + 0.95, 6.6, 0.9]


if __name__ == "__main__":
    meshes = {
        "Karosserie": sauber(loft(form.querschnitt_unten, -LH, LH, 110)),
        "Verkleidung": sauber(verkleidung_teil(form, kante, skala=1.02)),
        "Glas": doppelseitig(*sauber(loft(form.querschnitt_glas, G_VON, G_BIS, 60))),
        "Dach": sauber(zusammen(dach_teil(form, 0.5, 2.5, dicke=0.3, n=24), saeulen_teil(form, ((2.35, 6.5, 14),)))),
    }
    anbau, kennz, spoiler = anbauteile()
    kollision = [{"g": [7.2, 0.35, 14.5], "p": [0, 2 * RAD_R + 0.25, 0]}, {"g": [5.4, 1.3, 5.6], "p": [0, 3.75, 0.9]}]
    erzeugen("sport", "VelocityGT", "Velocity GT sports car body", (RAD_R, 3.3, ACHSE), meshes, anbau, kollision, kennz, spoiler, sitz_y=SITZ_Y, armaturen_z=-0.9)
