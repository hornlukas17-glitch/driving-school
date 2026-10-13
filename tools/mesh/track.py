"""Runde Karosserie für das Track-Coupé "Striker TR" (eigenes Design, keine echte Marke):
Frontmotor-Rennsport-Coupé mit langer Haube, weit hinten sitzender Kabine, breiten Radläufen,
kurzem Heck mit Abrisskante und großem Heckflügel auf Schwanenhals-Stützen.

Passt zu Auto.MODELLE.track: Räder R = 1.35 bei x = ±3.45, z = ±5.3, Länge 16.5.
Aufruf:  python3 tools/mesh/track.py  ->  dist/mesh/StrikerTR.obj, tools/mesh/track_info.json, src/Karosserien.lua
"""
import math
from basis import Form, glatt, loft, sauber, zusammen, doppelseitig, dach_teil, saeulen_teil, verkleidung_teil, teil, erzeugen, linie, profil, flaechen_paar, flaeche_mitte

LH = 8.25
ACHSE = 5.3
RAD_R = 1.35
BOGEN_R = 1.8
DACH = 4.75
SITZ_Y = 1.3


def halbbreite(z):
    u = abs(z) / LH
    n = 4.5 if z < 0 else 8.0                  # breite, stumpfe Nase, kantiges Heck
    a = 3.8 * max(0.0, 1 - u ** n) ** (1 / n)
    for rz, plus in ((-ACHSE, 0.18), (ACHSE, 0.24)):   # ausgestellte Radläufe (Rennsport)
        d = abs(z - rz) / 2.5
        if d < 1 and abs(z) < LH - 0.4:
            a += plus * (1 - d * d) ** 2
    return a


def bogen(z):
    for rz in (-ACHSE, ACHSE):
        dz = z - rz
        if abs(dz) < BOGEN_R:
            return 0.6 + 2.3 * math.sqrt(1 - (dz / BOGEN_R) ** 2)
    return 0


def boden(z):
    b = 0.6
    if z < -7.4:
        b = max(b, 0.6 + 0.25 * ((-7.4 - z) / (LH - 7.4)) ** 1.5)
    if z > 7.4:
        b = max(b, 0.6 + 0.5 * ((z - 7.4) / (LH - 7.4)) ** 1.5)
    return b


def oben(z):
    if z < -1.3:                               # lange, leicht steigende Haube
        t = max(0.0, (z + LH) / (LH - 1.3))
        return 1.98 + 0.6 * t ** 0.55
    if z < 4.6:                                # Gürtellinie
        return 2.58 + 0.24 * glatt((z + 1.3) / 5.9)
    if z < 7.9:                                # kurzes Deck, hinten zur Abrisskante hoch
        return 2.82 + 0.22 * glatt((z - 6.2) / 1.7)
    return 3.04 - 0.3 * glatt((z - 7.9) / (LH - 7.9))


G_VON, G_BIS = -1.45, 5.3


def gh_unten(z):
    return oben(min(max(z, -1.4), 5.25)) - 0.05


def gh_oben(z):
    if z < 0.9:                                # Frontscheibe
        t = (z - G_VON) / (0.9 - G_VON)
        return gh_unten(G_VON) + (DACH - gh_unten(G_VON)) * (1 - (1 - t) ** 1.7)
    if z <= 2.5:                               # kurzes, flaches Dach
        return DACH + 0.02 * math.sin(math.pi * (z - 0.9) / 1.6)
    t = (z - 2.5) / (G_BIS - 2.5)              # Heckscheibe zum Deck
    return DACH - (DACH - gh_unten(G_BIS) - 0.04) * t ** 1.3


def gh_breite(z, y):
    unten = gh_unten(z)
    hoehe = (y - unten) / max(0.1, DACH - unten)
    w = 3.28 - 0.85 * max(0.0, hoehe) ** 1.2
    u = (z - (G_VON + G_BIS) / 2) / ((G_BIS - G_VON) / 2)
    return w * max(0.0, 1 - abs(u) ** 5) ** (1 / 5)


form = Form(halbbreite=halbbreite, boden=boden, oben=oben, gh_oben=gh_oben, gh_breite=gh_breite, gh_unten=gh_unten,
            g_von=G_VON, g_bis=G_BIS, lh=LH, n_unten=5.0, n_glas=5.0, bogen=bogen, kotfluegel=0.2, bogen_innen=0.38,
            profil=profil(einzug=0.1, schulter=0.55, oben=0.12))


def kante(z):
    k = 1.05                                   # Schweller
    if bogen(z) > 0:
        k = max(k, bogen(z) + 0.14)
    if z < -7.6:                               # Frontsplitter-Bereich
        k = max(k, 1.05 + 0.15 * glatt((-7.6 - z) / 0.6))
    if z > 7.0:                                # Diffusor
        k = max(k, 1.05 + 0.55 * glatt((z - 7.0) / 1.0))
    return k


def flaechen():
    m = {}
    flaechen_paar(m, form, "LichtV", "Scheinwerfer", "scheinwerfer", "vorne", [(1.95, 1.64), (3.05, 1.58), (3.1, 1.76), (1.9, 1.84)], n_u=12, n_v=3)
    flaechen_paar(m, form, "LeisteV", "Tagfahrlicht", "neon_weiss", "vorne", [(1.98, 1.55), (3.05, 1.5), (3.05, 1.54), (1.98, 1.59)], n_u=10, n_v=1, abstand=0.045)
    flaechen_paar(m, form, "BlinkV", "Blinker#", "blinker", "vorne", [(3.12, 1.56), (3.4, 1.53), (3.4, 1.7), (3.14, 1.74)], n_u=3, n_v=2)
    flaeche_mitte(m, form, "Grill", "Kuehlergrill", "grill", "vorne", [(-2.15, 0.98), (2.15, 0.98), (2.0, 1.5), (-2.0, 1.5)], n_u=16, n_v=2)
    flaechen_paar(m, form, "Eckeinlass", "Lufteinlass", "grill", "vorne", [(2.45, 0.95), (3.1, 0.95), (3.05, 1.38), (2.5, 1.42)], n_u=4, n_v=3)
    flaeche_mitte(m, form, "Band", "Ruecklichtband", "neon_rot", "hinten", [(-2.2, 2.57), (2.2, 2.57), (2.2, 2.65), (-2.2, 2.65)], n_u=14, n_v=1)
    flaechen_paar(m, form, "LichtH", "Ruecklicht", "neon_rot", "hinten", [(2.25, 2.48), (3.1, 2.48), (3.1, 2.7), (2.25, 2.7)], n_u=6, n_v=2)
    flaechen_paar(m, form, "BlinkH", "Blinker#", "blinker", "hinten", [(2.3, 2.3), (2.9, 2.3), (2.9, 2.42), (2.3, 2.42)], n_u=4, n_v=1)
    flaeche_mitte(m, form, "Gitter", "Heckgitter", "grill", "hinten", [(-2.2, 1.75), (2.2, 1.75), (2.2, 2.15), (-2.2, 2.15)], n_u=14, n_v=2)
    return m


def anbauteile():
    def vorne(x, y, tiefe): return [x, y, form.front_z(x, y) - tiefe / 2 + 0.04]
    def hinten(x, y, tiefe): return [x, y, form.heck_z(x, y) + tiefe / 2 - 0.04]
    def seite(y, z, breite): return [form.seite_x(y, z) + breite / 2 - 0.02, y, z]
    def plus(p, dx=0, dy=0, dz=0): return [p[0] + dx, p[1] + dy, p[2] + dz]
    sw = vorne(2.55, 1.78, 0.22)
    deck = oben(7.0)
    t = [
        # Front: schmale, schräge Scheinwerfer, zweigeteilter Grill, Kennzeichen in der Mitte
        teil("Frontsplitter", "carbon", (6.4, 0.07, 0.5), plus(vorne(0, 0.8, 0.1), dy=-0.14, dz=0.14)),
        teil("Haubenschlitz", "grill", (0.9, 0.03, 1.3), [0.95, form.oben_y(0.95, -4.6) + 0.02, -4.6], True, (-math.degrees(math.atan2(form.oben_y(0.95, -4.0) - form.oben_y(0.95, -5.2), 1.2)), 0, 0)),
        # Seite: Kiemen hinter dem Vorderrad, Spiegel
        teil("Spiegel", "lack", (0.6, 0.38, 0.75), plus(seite(2.5, -0.7, 0.2), dx=0.42, dy=0.2), True),
        teil("Spiegelfuss", "schwarz", (0.45, 0.12, 0.3), plus(seite(2.5, -0.7, 0.2), dx=0.08, dy=0.05, dz=0.1), True),
    ]
    for i, z in enumerate((-3.05, -2.75, -2.45)):
        t.append(teil("Kieme", "schwarz", (0.05, 0.12, 0.85), plus(seite(1.95 - i * 0.02, z, 0.05), dx=-0.01), True, (0, 0, 0)))
    t += [
        # Heck: durchgehendes Lichtband, Diffusor mit Finnen, vier Endrohre, großer Flügel
        teil("Diffusor", "carbon", (5.2, 0.07, 1.0), [0, 1.0, 7.65]),
        teil("Auspuff", "chrom", (0.45, 0.34, 0.34), plus(hinten(0.5, 1.38, 0.4), dz=-0.06), True, zylinder=True),
        teil("Auspuff", "chrom", (0.45, 0.34, 0.34), plus(hinten(1.05, 1.38, 0.4), dz=-0.06), True, zylinder=True),
        teil("Fluegel", "carbon", (6.8, 0.12, 1.35), [0, deck + 1.4, 7.05], False, (-7, 0, 0)),
        teil("Fluegelendplatte", "lack", (0.08, 0.85, 1.6), [3.42, deck + 1.3, 7.05], True),
        teil("Fluegelstuetze", "carbon", (0.12, 1.25, 0.35), [1.35, deck + 0.75, 7.25], True, (12, 0, 0)),
    ]
    for x in (0.5, 1.5):
        t.append(teil("Diffusorfinne", "carbon", (0.06, 0.4, 0.95), [x, 1.2, 7.65], True))
    # Fugen: Türen, Haube
    for z0 in (-1.35, 2.55):
        t += linie("Fuge", [[form.seite_x(y, z0) + 0.005, y, z0] for y in (1.15, 1.6, 2.05, 2.48)], spiegeln=True)
    t += linie("Fuge", [[2.25, form.oben_y(2.25, z) + 0.008, z] for z in (-7.55, -6.5, -5.0, -3.5, -1.9)], spiegeln=True)
    kennz = {"vorne": [1.25, form.front_z(0, 1.25) - 0.06], "hinten": [2.05, form.heck_z(0, 2.05) + 0.08]}
    # Tuning-Spoiler: Gurney-Element über dem Flügel
    return t, kennz, [deck + 1.75, 6.75, 0.3]


if __name__ == "__main__":
    meshes = {
        "Karosserie": sauber(loft(form.querschnitt_unten, -LH, LH, 112)),
        "Verkleidung": sauber(verkleidung_teil(form, kante, skala=1.02)),
        "Glas": doppelseitig(*sauber(loft(form.querschnitt_glas, G_VON, G_BIS, 56))),
        "Dach": sauber(zusammen(dach_teil(form, 0.95, 2.75, dicke=0.3, n=22), saeulen_teil(form, ((2.6, 5.0, 12),)))),
    }
    meshes.update(flaechen())
    anbau, kennz, spoiler = anbauteile()
    kollision = [{"g": [7.6, 0.35, 15.5], "p": [0, 2 * RAD_R + 0.25, 0]}, {"g": [5.6, 1.4, 5.0], "p": [0, 3.9, 1.0]}]
    erzeugen("track", "StrikerTR", "Striker TR track car body", (RAD_R, 3.45, ACHSE), meshes, anbau, kollision, kennz, spoiler,
             sitz_y=SITZ_Y, armaturen_z=-0.4)
