"""Schreibt die Blender-Haeuser als OBJ fuer den Roblox-3D-Importer (ohne Blender).

python3 tools/blender/nach_obj.py  ->  dist/mesh/haeuser/Haus_A.obj ... Haus_D.obj

Ein Objekt je Material-Gruppe (Wand, Dach, Rahmen ...), damit das Spiel Farben pro Haus variieren kann.
Koordinaten schon in Roblox-Achsen (Y oben, Front +Z). Ein winziger Wuerfel "Anker" liegt genau im
Haus-Ursprung (Bodenmitte), daran richtet das Einbau-Skript das importierte Modell aus.
"""
import os, sys, math
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import nach_roblox as nr

WURZEL = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
AUS = os.path.join(WURZEL, "dist", "mesh", "haeuser")


def ecken_box(s):
    x, y, z = (v / 2 for v in s)
    v = [(a * x, b * y, c * z) for a in (-1, 1) for b in (-1, 1) for c in (-1, 1)]
    f = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    return v, f


def ecken_keil(s):
    # Roblox-WedgePart: Rueckwand +Z voll, Schraege von oben-hinten nach unten-vorne
    x, y, z = (v / 2 for v in s)
    v = [(-x, -y, -z), (x, -y, -z), (-x, -y, z), (x, -y, z), (-x, y, z), (x, y, z)]
    f = [(0, 2, 3, 1), (2, 4, 5, 3), (0, 1, 5, 4), (0, 4, 2), (1, 3, 5)]
    return v, f


def ecken_zyl(s, n=10):
    L, d = s[0] / 2, s[1] / 2
    v, f = [], []
    for i in range(n):
        w = 2 * math.pi * i / n
        v += [(-L, d * math.cos(w), d * math.sin(w)), (L, d * math.cos(w), d * math.sin(w))]
    for i in range(n):
        j = (i + 1) % n
        f.append((2 * i, 2 * j, 2 * j + 1, 2 * i + 1))
    f.append(tuple(2 * i for i in range(n))[::-1])
    f.append(tuple(2 * i + 1 for i in range(n)))
    return v, f


def nach_aussen(welt, f):
    # MeshParts sind einseitig: jede Flaeche muss nach aussen zeigen (vom Schwerpunkt weg)
    P = np.array(welt)
    mitte = P.mean(axis=0)
    neu = []
    for fl in f:
        a, b, c = P[fl[0]], P[fl[1]], P[fl[2]]
        n = np.cross(b - a, c - a)
        if np.dot(n, P[list(fl)].mean(axis=0) - mitte) < 0:
            fl = tuple(reversed(fl))
        neu.append(fl)
    return welt, neu


def schreiben(skript, name):
    G = nr.lade(skript)
    gruppen = {}
    for g, form, pos, R, s in nr.teile(G):
        v, f = {"Block": ecken_box, "Wedge": ecken_keil, "Cylinder": ecken_zyl}[form](s)
        welt = [tuple(np.array(pos) + R @ np.array(p)) for p in v]
        gruppen.setdefault(g, []).append(nach_aussen(welt, f))
    gruppen["Anker"] = [nach_aussen(*ecken_box((0.2, 0.2, 0.2)))]
    os.makedirs(AUS, exist_ok=True)
    pfad = os.path.join(AUS, name + ".obj")
    n_v, tris = 0, 0
    with open(pfad, "w") as o:
        o.write(f"# {name} - Crazy Driving School, eigenes Design\n")
        for g, teile in gruppen.items():
            o.write(f"o {g}\ng {g}\n")
            for welt, f in teile:
                for p in welt:
                    o.write("v %.4f %.4f %.4f\n" % p)
                for fl in f:
                    o.write("f " + " ".join(str(n_v + i + 1) for i in fl) + "\n")
                    tris += len(fl) - 2
                n_v += len(welt)
    return pfad, tris


if __name__ == "__main__":
    for k in "abcd":
        p, t = schreiben(f"haus_{k}.py", f"Haus_{k.upper()}")
        print(p, t, "Dreiecke")
