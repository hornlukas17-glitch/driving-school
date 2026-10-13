"""Runde Karosserie für die Limousine "Executive" (eigenes Design, keine echte Marke):
sportliche Oberklasse-Limousine mit flacher, breiter Front, langer Haube, vier Türen, fließendem Dach,
kurzem Heck mit angedeuteter Abrisskante, Diffusor und vier Endrohren.

Neu gegenüber den älteren Autos: echter Auto-Querschnitt (unten eingezogen, Schulter, runde Oberkante)
und Lichter/Grill/Lüftungen als Flächen, die der Karosserie folgen (statt aufgesetzter Klötze).

Passt zu Auto.MODELLE.limousine: Räder R = 1.35 bei x = ±3.3, z = ±5.6, Länge 17.
Aufruf:  python3 tools/mesh/limousine.py  ->  dist/mesh/Executive.obj, tools/mesh/limousine_info.json, src/Karosserien.lua
"""
import math
from basis import (Form, glatt, loft, sauber, zusammen, doppelseitig, dach_teil, saeulen_teil, verkleidung_teil,
                   teil, erzeugen, linie, profil, flaeche, spiegel)

LH = 8.5
ACHSE = 5.6
RAD_R = 1.35
BOGEN_R = 1.85
DACH = 5.55
SITZ_Y = 1.45


def halbbreite(z):
    u = abs(z) / LH
    n = 5.0 if z < 0 else 6.0
    a = 3.9 * max(0.0, 1 - u ** n) ** (1 / n)
    for rz in (-ACHSE, ACHSE):                   # leicht ausgestellte Radläufe
        d = abs(z - rz) / 2.6
        if d < 1 and abs(z) < LH - 0.5:
            a += 0.08 * (1 - d * d) ** 2
    return a


def bogen(z):
    for rz in (-ACHSE, ACHSE):
        dz = z - rz
        if abs(dz) < BOGEN_R:
            return 0.75 + 2.25 * math.sqrt(1 - (dz / BOGEN_R) ** 2)
    return 0


def boden(z):
    b = 0.75
    if z < -7.6:
        b = max(b, 0.75 + 0.35 * ((-7.6 - z) / (LH - 7.6)) ** 1.5)
    if z > 7.4:
        b = max(b, 0.75 + 0.45 * ((z - 7.4) / (LH - 7.4)) ** 1.5)
    return b


def oben(z):
    if z < -2.5:                                 # lange Haube, vorn schräg abfallende Front
        t = max(0.0, (z + LH) / (LH - 2.5))
        h = 3.05 + 0.32 * t
        return h - 0.6 * glatt((-7.7 - z) / 0.8)
    if z < 5.2:                                  # Gürtellinie steigt leicht nach hinten
        return 3.37 + 0.25 * glatt((z + 2.5) / 7.7)
    if z < 7.9:                                  # Kofferraum mit angedeuteter Abrisskante
        return 3.62 + 0.14 * glatt((z - 5.6) / 2.3)
    return 3.76 - 0.45 * glatt((z - 7.9) / (LH - 7.9))


G_VON, G_BIS = -2.65, 6.0


def gh_unten(z):
    return oben(min(max(z, -2.6), 5.95)) - 0.05


def gh_oben(z):
    if z < -0.2:                                 # flache Frontscheibe
        t = (z - G_VON) / (-0.2 - G_VON)
        return gh_unten(G_VON) + (DACH - gh_unten(G_VON)) * (1 - (1 - t) ** 1.7)
    if z <= 2.6:                                 # Dach, leicht gewölbt
        return DACH + 0.04 * math.sin(math.pi * (z + 0.2) / 2.8)
    t = (z - 2.6) / (G_BIS - 2.6)                # lang auslaufende Heckscheibe
    return DACH - (DACH - gh_unten(G_BIS) - 0.04) * t ** 1.3


def gh_breite(z, y):
    unten = gh_unten(z)
    hoehe = (y - unten) / max(0.1, DACH - unten)
    w = 3.32 - 0.78 * max(0.0, hoehe) ** 1.25
    u = (z - (G_VON + G_BIS) / 2) / ((G_BIS - G_VON) / 2)
    return w * max(0.0, 1 - abs(u) ** 6) ** (1 / 6)


form = Form(halbbreite=halbbreite, boden=boden, oben=oben, gh_oben=gh_oben, gh_breite=gh_breite, gh_unten=gh_unten,
            g_von=G_VON, g_bis=G_BIS, lh=LH, n_unten=4.5, n_glas=5.0, bogen=bogen, kotfluegel=0.12, bogen_innen=0.5,
            profil=profil(einzug=0.13, schulter=0.58, oben=0.1))


def kante(z):
    k = 1.15                                     # schmaler schwarzer Schweller
    if bogen(z) > 0:
        k = max(k, bogen(z) + 0.1)
    if z < -7.6:
        k = max(k, 1.15 + 0.12 * glatt((-7.6 - z) / 0.7))
    if z > 7.3:
        k = max(k, 1.15 + 0.3 * glatt((z - 7.3) / 0.9))
    return k


def flaechen():
    """Lichter, Grill und Lüftungen als Flächen auf der Karosserie: {name: (verts, faces, {n, a})}"""
    m = {}
    def paar(name, teilname, art, seite, ecken, **kw):
        rechts = flaeche(form, seite, ecken, **kw)
        m[name + "R"] = (*rechts, {"n": teilname.replace("#", "R"), "a": art})
        m[name + "L"] = (*spiegel(rechts), {"n": teilname.replace("#", "L"), "a": art})
    def mitte(name, teilname, art, seite, ecken, **kw):
        m[name] = (*flaeche(form, seite, ecken, **kw), {"n": teilname, "a": art})
    # vorn: schmale, nach außen ansteigende Scheinwerfer mit Leuchtleiste, eigener breiter Grill
    paar("LichtV", "Scheinwerfer", "scheinwerfer", "vorne", [(1.7, 2.7), (3.2, 2.62), (3.25, 2.88), (1.62, 2.96)], n_u=12, n_v=3)
    paar("LeisteV", "Tagfahrlicht", "neon_weiss", "vorne", [(1.72, 2.6), (3.2, 2.52), (3.2, 2.57), (1.72, 2.65)], n_u=10, n_v=1, abstand=0.045)
    paar("BlinkV", "Blinker#", "blinker", "vorne", [(3.28, 2.62), (3.48, 2.6), (3.48, 2.82), (3.3, 2.86)], n_u=3, n_v=2, abstand=0.035)
    mitte("Grill", "Kuehlergrill", "grill", "vorne", [(-1.45, 2.02), (1.45, 2.02), (1.25, 2.62), (-1.25, 2.62)], n_u=16, n_v=3)
    mitte("Einlass", "Lufteinlass", "grill", "vorne", [(-2.35, 0.98), (2.35, 0.98), (2.2, 1.36), (-2.2, 1.36)], n_u=16, n_v=2)
    paar("Eckeinlass", "Seiteneinlass", "glanzschwarz", "vorne", [(2.55, 1.05), (3.15, 1.05), (3.05, 1.9), (2.62, 1.95)], n_u=4, n_v=4)
    # hinten: flache, umlaufende Rückleuchten, Blende dazwischen, Diffusor
    paar("LichtH", "Ruecklicht", "neon_rot", "hinten", [(1.55, 2.92), (3.2, 2.98), (3.22, 3.2), (1.5, 3.16)], n_u=12, n_v=3)
    paar("BlinkH", "Blinker#", "blinker", "hinten", [(1.05, 2.93), (1.5, 2.93), (1.5, 3.14), (1.05, 3.12)], n_u=3, n_v=2)
    mitte("Blende", "Heckblende", "glanzschwarz", "hinten", [(-0.98, 2.95), (0.98, 2.95), (0.98, 3.11), (-0.98, 3.11)], n_u=8, n_v=1)
    mitte("Diffusor", "Diffusor", "carbon", "hinten", [(-2.5, 0.95), (2.5, 0.95), (2.5, 1.45), (-2.5, 1.45)], n_u=16, n_v=2)
    # Seite: Kieme hinter dem Vorderrad, bündige Türgriffe
    paar("Kieme", "Kieme", "glanzschwarz", "seite", [(-3.3, 2.2), (-2.65, 2.25), (-2.7, 2.52), (-3.35, 2.47)], n_u=4, n_v=2)
    for i, z0 in enumerate((-1.25, 2.35)):
        paar(f"Griff{i}", "Griff", "chrom", "seite", [(z0, 3.12), (z0 + 0.7, 3.12), (z0 + 0.7, 3.24), (z0, 3.24)], n_u=3, n_v=1, abstand=0.035)
    return m


def anbauteile():
    def hinten(x, y, tiefe): return [x, y, form.heck_z(x, y) + tiefe / 2 - 0.04]
    def seite(y, z, breite): return [form.seite_x(y, z) + breite / 2 - 0.02, y, z]
    def plus(p, dx=0, dy=0, dz=0): return [p[0] + dx, p[1] + dy, p[2] + dz]
    sp = seite(3.22, -1.95, 0.2)
    t = [
        teil("Spiegel", "lack", (0.62, 0.4, 0.8), plus(sp, dx=0.45, dy=0.24), True),
        teil("Spiegelfuss", "glanzschwarz", (0.5, 0.12, 0.35), plus(sp, dx=0.1, dy=0.08, dz=0.1), True),
        teil("Frontlippe", "carbon", (5.6, 0.06, 0.4), [0, 0.9, form.front_z(0, 1.0) + 0.1]),
    ]
    for x in (1.7, 2.22):                        # vier runde Endrohre
        t.append(teil("Auspuff", "chrom", (0.5, 0.4, 0.4), plus(hinten(x, 1.2, 0.5), dz=-0.08), True, zylinder=True))
    # Chrom-Fensterlinie entlang der Gürtellinie
    t += linie("Fensterleiste", [[form.seite_x(gh_unten(z) - 0.02, z) + 0.01, gh_unten(z) - 0.02, z]
                                 for z in (-2.3, -1.0, 0.5, 2.0, 3.5, 4.7)], art="chrom", dicke=0.05, spiegeln=True)
    # Fugen: Türen, Haube, Kofferraum
    for z0, ys in ((-2.4, (1.45, 2.1, 2.75, 3.32)), (1.2, (1.3, 2.0, 2.7, 3.4)), (4.1, (3.05, 3.3, 3.5))):
        t += linie("Fuge", [[form.seite_x(y, z0) + 0.005, y, z0] for y in ys], spiegeln=True)
    t += linie("Fuge", [[2.55, form.oben_y(2.55, z) + 0.008, z] for z in (-7.55, -6.3, -5.0, -3.7, -2.65)], spiegeln=True)
    t += linie("Fuge", [[x, form.oben_y(x, 5.45) + 0.008, 5.45] for x in (-2.45, -1.2, 0, 1.2, 2.45)])
    deck = oben(7.0)
    kennz = {"vorne": [1.68, form.front_z(0, 1.68) - 0.06], "hinten": [2.2, form.heck_z(0, 2.2) + 0.08]}
    return t, kennz, [deck + 1.0, 7.0, 0.45]


if __name__ == "__main__":
    meshes = {
        "Karosserie": sauber(loft(form.querschnitt_unten, -LH, LH, 120)),
        "Verkleidung": sauber(verkleidung_teil(form, kante, skala=1.015)),
        "Glas": doppelseitig(*sauber(loft(form.querschnitt_glas, G_VON, G_BIS, 64))),
        "Dach": sauber(zusammen(dach_teil(form, 0.0, 3.0, dicke=0.3, n=26), saeulen_teil(form, ((0.55, 0.95, 4), (4.3, 5.8, 10))))),
    }
    meshes.update(flaechen())
    anbau, kennz, spoiler = anbauteile()
    kollision = [{"g": [7.2, 0.4, 16.0], "p": [0, 2 * RAD_R + 0.3, 0]}, {"g": [6.0, 1.6, 7.5], "p": [0, 4.4, 1.2]}]
    erzeugen("limousine", "Executive", "Executive sedan body", (RAD_R, 3.3, ACHSE), meshes, anbau, kollision, kennz, spoiler,
             sitz_y=SITZ_Y, armaturen_z=-1.6)
