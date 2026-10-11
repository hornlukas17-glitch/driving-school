"""Erzeugt die runde Karosserie für den SUV "Ranger X" (eigenes Design, keine echte Marke) als OBJ für Roblox.

Koordinaten wie im Spiel: x = rechts, y = hoch (0 = Boden), z = nach hinten (das Auto fährt Richtung -z).
Passt zu Auto.MODELLE.suv: Räder R = 1.6 bei x = ±3.4, z = ±5.6, Länge 17.5.

Aufruf:  python3 tools/mesh/suv.py   ->  dist/mesh/RangerX.obj + tools/mesh/suv_info.json
"""
import math, json, os
import numpy as np

HIER = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HIER))

N_RING = 44            # Punkte pro Querschnitt
LH = 8.75              # halbe Länge
ACHSE = 5.6
RAD_R = 1.6
BOGEN_R = 2.15         # Radlauf (Radius in z-Richtung)
GURT = 4.78            # Gürtellinie vorne (Unterkante Fenster)
DACH = 7.35


def glatt(t):
    t = min(max(t, 0.0), 1.0)
    return t * t * (3 - 2 * t)


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


def querschnitt_unten(z, n_exp=7.0, skala=1.0, y_max=None):
    a = halbbreite(z) * skala
    b, t = boden(z), oben(z)
    yc, h = (b + t) / 2, (t - b) / 2
    pts = []
    for i in range(N_RING):
        w = 2 * math.pi * i / N_RING
        c, s = math.cos(w), math.sin(w)
        x = a * math.copysign(abs(c) ** (2 / n_exp), c)
        y = yc + h * math.copysign(abs(s) ** (2 / n_exp), s)
        if y_max is not None and y > y_max:
            y = y_max
        pts.append((x, y, z))
    return pts


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


def querschnitt_glas(z, n_exp=7.0):
    unten = oben(min(max(z, -3.35), 7.3)) - 0.05
    t = gh_oben(z)
    pts = []
    for i in range(N_RING):
        w = 2 * math.pi * i / N_RING
        c, s = math.cos(w), math.sin(w)
        yy = math.copysign(abs(s) ** (2 / n_exp), s)
        y = (unten + t) / 2 + (t - unten) / 2 * yy
        a = gh_breite(z, y)
        x = a * math.copysign(abs(c) ** (2 / n_exp), c)
        pts.append((x, y, z))
    return pts


def loft(querschnitt, z0, z1, n):
    zs = [z0 + (z1 - z0) * (0.5 - 0.5 * math.cos(math.pi * i / (n - 1))) for i in range(n)]
    ringe = [querschnitt(z) for z in zs]
    verts, faces = [], []
    for ring in ringe:
        verts.extend(ring)
    for r in range(n - 1):
        for i in range(N_RING):
            a = r * N_RING + i
            b = r * N_RING + (i + 1) % N_RING
            c = (r + 1) * N_RING + (i + 1) % N_RING
            d = (r + 1) * N_RING + i
            faces.append((a, b, c))
            faces.append((a, c, d))
    for r, umdrehen in ((0, True), (n - 1, False)):
        ring = ringe[r]
        mx = sum(p[0] for p in ring) / N_RING
        my = sum(p[1] for p in ring) / N_RING
        verts.append((mx, my, ring[0][2]))
        m = len(verts) - 1
        for i in range(N_RING):
            a = r * N_RING + i
            b = r * N_RING + (i + 1) % N_RING
            faces.append((m, b, a) if umdrehen else (m, a, b))
    return verts, faces


def ausrichten(verts, faces):
    """jedes Dreieck nach außen drehen (weg von der Mittellinie des Querschnitts)"""
    v = np.array(verts)
    neu = []
    for f in faces:
        p = v[list(f)]
        n = np.cross(p[1] - p[0], p[2] - p[0])
        m = p.mean(axis=0)
        nahe = v[np.abs(v[:, 2] - m[2]) < 0.3]
        zentrum = np.array([0.0, nahe[:, 1].mean() if len(nahe) else m[1], m[2]])
        if np.dot(n, m - zentrum) < 0:
            f = (f[0], f[2], f[1])
        neu.append(f)
    return neu


def entartete_weg(verts, faces):
    v = np.array(verts)
    aus = []
    for f in faces:
        p = v[list(f)]
        if np.linalg.norm(np.cross(p[1] - p[0], p[2] - p[0])) > 1e-7:
            aus.append(f)
    return aus


def dach_teil():
    """Dachhaut: oberer Teil der Fensterform, minimal größer, sitzt auf dem Glas"""
    def qs(z):
        t = gh_oben(z)
        aus = []
        for x, y, zz in querschnitt_glas(z):
            yy = max(y, t - 0.42)
            alt = gh_breite(z, y)
            xx = x / alt * gh_breite(z, yy) if alt > 1e-6 else 0.0
            aus.append((xx * 1.02, yy + 0.03, zz))
        return aus
    return loft(qs, -1.1, 6.6, 36)


def saeulen_teil():
    """B-, C- und D-Säule in Wagenfarbe: Streifen der Fensterform, minimal größer"""
    def qs(z):
        ring = querschnitt_glas(z)
        breite = max(abs(p[0]) for p in ring) or 1
        # nur die Seiten: die Mitte (Dach/Heckscheibe) liegt versteckt unter dem Glas
        return [(x * 1.014, y if abs(x) > 0.72 * breite else y - 0.35, zz) for x, y, zz in ring]
    teile = [loft(qs, z0, z1, n) for z0, z1, n in ((0.85, 1.3, 4), (4.15, 4.5, 4), (6.55, 7.9, 10))]
    verts, faces = [], []
    for v, f in teile:
        basis = len(verts)
        verts += v
        faces += [(a + basis, b + basis, c + basis) for a, b, c in f]
    return verts, faces


def verkleidung_teil():
    """schwarze Kunststoffverkleidung: Schweller, Radlaufbögen und untere Stoßfänger"""
    def kante(z):
        k = 1.85                                         # Schweller
        for rz in (-ACHSE, ACHSE):                       # breiter Rand um die Radläufe
            dz = abs(z - rz)
            if dz < BOGEN_R + 0.35:
                k = max(k, boden(z) + 0.32 + 0.0 * dz)
        if z < -7.2:                                     # Frontschürze
            k = max(k, 1.85 + 0.55 * glatt((-7.2 - z) / 0.9))
        if z > 7.3:                                      # Heckschürze
            k = max(k, 1.85 + 0.45 * glatt((z - 7.3) / 0.8))
        return k

    def qs(z):
        return querschnitt_unten(z, skala=1.022, y_max=kante(z))
    return loft(qs, -LH * 1.004, LH * 1.004, 120)


def schreiben(pfad, teile):
    zeilen = ["# Ranger X SUV body - own design, generated for Roblox (import with the 3D Importer)"]
    basis = 1
    for name, (verts, faces) in teile:
        zeilen.append(f"o {name}")
        for x, y, z in verts:
            zeilen.append(f"v {x:.4f} {y:.4f} {z:.4f}")
        for a, b, c in faces:
            zeilen.append(f"f {a + basis} {b + basis} {c + basis}")
        basis += len(verts)
    os.makedirs(os.path.dirname(pfad), exist_ok=True)
    open(pfad, "w").write("\n".join(zeilen) + "\n")


def doppelseitig(verts, faces):
    return verts, faces + [(a, c, b) for a, b, c in faces]


# ---------------- Positionen für Lichter und Details ----------------
def innen_unten(x, y, z):
    a = halbbreite(z)
    b, t = boden(z), oben(z)
    if a <= 0 or t <= b:
        return False
    yc, h = (b + t) / 2, (t - b) / 2
    return abs(x / a) ** 7 + abs((y - yc) / h) ** 7 <= 1


def front_z(x, y):
    for z in np.arange(-LH, 0, 0.005):
        if innen_unten(x, y, z):
            return float(z)


def heck_z(x, y):
    for z in np.arange(LH, 0, -0.005):
        if innen_unten(x, y, z):
            return float(z)


def seite_x(y, z):
    for x in np.arange(4.2, 0, -0.005):
        if innen_unten(x, y, z):
            return float(x)


def positionen():
    pos = {}
    def vorne(name, x, y, tiefe):
        pos[name] = [x, y, round(front_z(x, y) - tiefe / 2 + 0.04, 3)]
    def hinten(name, x, y, tiefe):
        pos[name] = [x, y, round(heck_z(x, y) + tiefe / 2 - 0.04, 3)]
    def seite(name, y, z, breite):
        pos[name] = [round(seite_x(y, z) + breite / 2 - 0.02, 3), y, z]
    vorne("Scheinwerfer", 2.35, 4.2, 0.3)       # schmale, breite Scheinwerfer
    vorne("Kuehlergrill", 0, 3.65, 0.2)
    vorne("Lufteinlass", 0, 2.05, 0.1)
    vorne("Nebel", 2.85, 2.2, 0.1)
    vorne("KennzeichenVorne", 0, 2.75, 0.1)
    hinten("Ruecklicht", 2.45, 4.45, 0.25)
    hinten("Lichtband", 0, 4.5, 0.08)
    hinten("KennzeichenHinten", 0, 3.45, 0.1)
    hinten("Auspuff", 2.3, 1.75, 0.5)
    seite("Griff1", 4.4, 0.0, 0.12)
    seite("Griff2", 4.45, 3.4, 0.12)
    seite("Spiegel", 4.7, -2.85, 0.3)
    seite("Chromleiste", 2.0, 0.6, 0.06)
    pos["DrittesBremslicht"] = [0, round(gh_oben(6.4) + 0.05, 3), 6.4]
    pos["Dachspoiler"] = [0, round(gh_oben(6.3) + 0.08, 3), 6.55]
    pos["Dachreling"] = [round(gh_breite(2.6, DACH - 0.3) * 0.88, 3), round(gh_oben(2.6) + 0.1, 3), 2.6]
    return pos


if __name__ == "__main__":
    unten = loft(querschnitt_unten, -LH, LH, 96)
    unten = (unten[0], entartete_weg(unten[0], ausrichten(*unten)))
    verkl = verkleidung_teil()
    verkl = (verkl[0], entartete_weg(verkl[0], ausrichten(*verkl)))
    glas = loft(querschnitt_glas, G_VON, G_BIS, 60)
    glas = (glas[0], entartete_weg(glas[0], ausrichten(*glas)))
    dach = dach_teil()
    dach = (dach[0], ausrichten(*dach))
    saeulen = saeulen_teil()
    saeulen = (saeulen[0], ausrichten(*saeulen))
    basis = len(dach[0])
    dach = (dach[0] + saeulen[0], entartete_weg(dach[0] + saeulen[0], dach[1] + [(a + basis, b + basis, c + basis) for a, b, c in saeulen[1]]))
    teile = [
        ("Karosserie", unten),
        ("Verkleidung", verkl),
        ("Glas", doppelseitig(*glas)),
        ("Dach", dach),
    ]
    schreiben(os.path.join(ROOT, "dist", "mesh", "RangerX.obj"), teile)
    info = {}
    for name, (verts, faces) in teile:
        v = np.array(verts)
        lo, hi = v.min(axis=0), v.max(axis=0)
        info[name] = {"groesse": (hi - lo).round(4).tolist(), "mitte": ((hi + lo) / 2).round(4).tolist(), "dreiecke": len(faces)}
    info["positionen"] = positionen()
    json.dump(info, open(os.path.join(HIER, "suv_info.json"), "w"), indent=1)
    print(json.dumps({k: (v if k == "positionen" else v["dreiecke"]) for k, v in info.items()}, indent=1))
