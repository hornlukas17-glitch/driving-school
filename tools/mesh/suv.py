"""Runde Karosserie für den SUV "Ranger X" (eigenes Design, keine echte Marke).

Passt zu Auto.MODELLE.suv: Räder R = 1.6 bei x = ±3.4, z = ±5.6, Länge 17.5.
Aufruf:  python3 tools/mesh/suv.py  ->  dist/mesh/RangerX.obj, tools/mesh/suv_info.json, src/Karosserien.lua
"""
import math
from basis import Form, glatt, loft, sauber, zusammen, doppelseitig, dach_teil, saeulen_teil, verkleidung_teil, teil, erzeugen, linie

LH = 8.75              # halbe Länge
ACHSE = 5.6
RAD_R = 1.6
BOGEN_R = 2.15         # Radlauf (Radius in z-Richtung)
GURT = 4.78            # Gürtellinie vorne (Unterkante Fenster)
DACH = 7.35


# ---------------- Unterteil ----------------
def halbbreite(z):
    u = abs(z) / LH
    n = 9.0 if z < 0 else 12.0          # kantige Front, fast eckiges Heck
    a = 3.82 * max(0.0, 1 - u ** n) ** (1 / n)
    # leicht ausgestellte Kotflügel über den Rädern
    for rz in (-ACHSE, ACHSE):
        d = abs(z - rz) / 2.6
        if d < 1:
            a += 0.08 * (1 - d * d) ** 2 * (1 if abs(z) < LH - 0.4 else 0)
    return a


def boden(z):
    b = 1.15
    for rz in (-ACHSE, ACHSE):
        dz = z - rz
        if abs(dz) < BOGEN_R:
            b = max(b, 1.15 + 2.45 * math.sqrt(1 - (dz / BOGEN_R) ** 2))
    if abs(z) > 7.75:                    # Böschungswinkel vorne/hinten
        b = max(b, 1.15 + 0.7 * ((abs(z) - 7.75) / (LH - 7.75)) ** 1.6)
    return b


def oben(z):
    if z < -3.35:                        # lange, fast flache Motorhaube, vorne rund abfallend
        t = (-3.35 - z) / (LH - 3.35)
        h = GURT - 0.12 * t ** 1.5
        return h - 0.3 * glatt((t - 0.93) / 0.07) ** 1.3
    if z <= 7.3:                         # Gürtellinie steigt nach hinten leicht an
        return GURT + 0.14 * glatt((z + 3.35) / 10.65)
    t = (z - 7.3) / (LH - 7.3)           # Heckklappe, oben gerundet
    return GURT + 0.14 - 0.3 * glatt(t) ** 1.4


# ---------------- Fenster (Glas) und Dach ----------------
G_VON, G_BIS = -3.3, 8.45


def gh_oben(z):
    if z < -0.95:                        # Frontscheibe, recht steil
        t = (z - G_VON) / (-0.95 - G_VON)
        return GURT + (DACH - GURT) * (1 - (1 - t) ** 1.8)
    if z <= 6.3:                         # langes Dach, fällt nach hinten leicht ab
        return DACH + 0.04 * math.sin(math.pi * (z + 0.95) / 7.25) - 0.18 * glatt((z + 0.95) / 7.25)
    t = (z - 6.3) / (G_BIS - 6.3)        # Heckscheibe, leicht geneigt
    return DACH - 0.18 - (DACH - 0.18 - (GURT + 0.3)) * t ** 1.6


def gh_breite(z, y):
    unten = oben(min(max(z, -3.35), 7.3)) - 0.05
    hoehe = (y - unten) / max(0.1, DACH - unten)
    w = 3.66 - 0.55 * max(0.0, hoehe) ** 1.3
    u = (z - (G_VON + G_BIS) / 2) / ((G_BIS - G_VON) / 2)
    return w * max(0.0, 1 - abs(u) ** 9) ** (1 / 9)


def gh_unten(z):
    return oben(min(max(z, -3.35), 7.3)) - 0.05


form = Form(halbbreite=halbbreite, boden=boden, oben=oben, gh_oben=gh_oben, gh_breite=gh_breite, gh_unten=gh_unten,
            g_von=G_VON, g_bis=G_BIS, lh=LH, n_unten=7.0, n_glas=7.0)


def kante(z):
    """Oberkante der schwarzen Verkleidung"""
    k = 1.85                                         # Schweller
    for rz in (-ACHSE, ACHSE):                       # breiter Rand um die Radläufe
        if abs(z - rz) < BOGEN_R + 0.35:
            k = max(k, boden(z) + 0.32)
    if z < -7.2:                                     # Frontschürze
        k = max(k, 1.85 + 0.55 * glatt((-7.2 - z) / 0.9))
    if z > 7.3:                                      # Heckschürze
        k = max(k, 1.85 + 0.45 * glatt((z - 7.3) / 0.8))
    return k


def anbauteile():
    def vorne(x, y, tiefe): return [x, y, form.front_z(x, y) - tiefe / 2 + 0.04]
    def hinten(x, y, tiefe): return [x, y, form.heck_z(x, y) + tiefe / 2 - 0.04]
    def seite(y, z, breite): return [form.seite_x(y, z) + breite / 2 - 0.02, y, z]
    def plus(p, dx=0, dy=0, dz=0): return [p[0] + dx, p[1] + dy, p[2] + dz]
    sw = vorne(2.35, 4.2, 0.3)
    grill = vorne(0, 3.65, 0.2)
    luft = vorne(0, 2.05, 0.1)
    nebel = vorne(2.85, 2.2, 0.1)
    rl = hinten(2.45, 4.45, 0.25)
    band = hinten(0, 4.5, 0.08)
    auspuff = hinten(2.3, 1.75, 0.5)
    sp = seite(4.7, -2.85, 0.3)
    reling = [gh_breite(2.6, DACH - 0.3) * 0.88, gh_oben(2.6) + 0.1, 2.6]
    ds = [0, gh_oben(6.3) + 0.08, 6.55]
    bl = [0, gh_oben(6.4) + 0.05, 6.4]
    t = [
        teil("Kuehlergrill", "grill", (3.6, 0.95, 0.15), plus(grill, dz=0.02)),
        teil("Grillchrom", "chrom", (3.7, 0.08, 0.1), plus(grill, dy=0.5, dz=-0.04)),
        teil("Lufteinlass", "grill", (4.2, 0.5, 0.08), luft),
        teil("Unterfahrschutz", "chrom", (3.2, 0.18, 0.1), plus(luft, dy=-0.45, dz=-0.04)),
        teil("Scheinwerferrahmen", "schwarz", (1.7, 0.44, 0.12), plus(sw, dz=0.1), True),
        teil("Scheinwerfer", "scheinwerfer", (1.5, 0.3, 0.2), plus(sw, dz=0.06), True),
        teil("Tagfahrlicht", "neon_weiss", (1.5, 0.06, 0.08), plus(sw, dy=-0.22, dz=0.02), True),
        teil("Blinker", "blinker", (0.3, 0.3, 0.2), plus(sw, dx=0.9, dz=0.12), True),
        teil("Nebelscheinwerfer", "neon_weiss", (0.7, 0.16, 0.08), nebel, True),
        teil("Ruecklicht", "neon_rot", (1.3, 0.3, 0.2), plus(rl, dz=-0.04), True),
        teil("Blinker", "blinker", (0.3, 0.3, 0.2), plus(rl, dx=0.75, dz=-0.06), True),
        teil("Auspuff", "chrom", (0.7, 0.3, 0.3), plus(auspuff, dz=-0.15), True),
        teil("Spiegel", "lack", (0.7, 0.5, 0.8), plus(sp, dx=0.45, dy=0.15), True),
        teil("Spiegelfuss", "schwarz", (0.5, 0.15, 0.4), plus(sp, dx=0.1, dz=0.1), True),
        teil("Griff", "chrom", (0.08, 0.14, 0.75), plus(seite(4.4, 0.0, 0.12), dx=0.04), True),
        teil("Griff", "chrom", (0.08, 0.14, 0.75), plus(seite(4.45, 3.4, 0.12), dx=0.04), True),
        teil("Zierleiste", "chrom", (0.05, 0.08, 6.5), plus(seite(2.0, 0.6, 0.06), dx=0.04), True),
        teil("Dachreling", "alu", (0.16, 0.14, 6.2), reling, True),
        teil("Ruecklichtband", "neon_rot", (2.4, 0.1, 0.08), band),
        teil("Dachspoiler", "lack", (5.4, 0.12, 0.6), ds),
        teil("Bremslicht_oben", "neon_rot", (1.2, 0.08, 0.1), plus(bl, dy=0.08, dz=0.25)),
    ]
    # Fugen: drei Türkanten je Seite und die Haube
    for z0 in (-2.95, 1.05, 3.3):
        t += linie("Fuge", [[form.seite_x(y, z0) + 0.005, y, z0] for y in (2.0, 2.9, 3.8, 4.6)], spiegeln=True)
    t += linie("Fuge", [[2.95, form.oben_y(2.95, z) + 0.008, z] for z in (-8.4, -7.0, -5.5, -4.0, -3.45)], spiegeln=True)
    kennz = {"vorne": [2.75, form.front_z(0, 2.75) - 0.05 + 0.04 - 0.08], "hinten": [3.45, form.heck_z(0, 3.45) + 0.05 - 0.04 + 0.08]}
    return t, kennz, [ds[1] + 0.15, ds[2] + 0.3]


if __name__ == "__main__":
    meshes = {
        "Karosserie": sauber(loft(form.querschnitt_unten, -LH, LH, 96)),
        "Verkleidung": sauber(verkleidung_teil(form, kante)),
        "Glas": doppelseitig(*sauber(loft(form.querschnitt_glas, G_VON, G_BIS, 60))),
        "Dach": sauber(zusammen(dach_teil(form, -0.75, 6.6), saeulen_teil(form, ((0.85, 1.3, 4), (4.15, 4.5, 4), (6.55, 7.9, 10))))),
    }
    anbau, kennz, spoiler = anbauteile()
    kollision = [{"g": [7.4, 1.3, 16.5], "p": [0, 2 * RAD_R + 0.95, 0]}, {"g": [6.6, 2.4, 10], "p": [0, 6.0, 2.4]}]
    erzeugen("suv", "RangerX", "Ranger X SUV body", (RAD_R, 3.4, ACHSE), meshes, anbau, kollision, kennz, spoiler)
