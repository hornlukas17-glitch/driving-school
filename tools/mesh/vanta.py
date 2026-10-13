"""Karosserie für die Sportlimousine "Vanta GS" (eigenes Design von Lukas, mit Meshy erzeugt).

Grundlage ist Lukas' Meshy-Modell (1,45 Mio. Dreiecke mit Textur). Die Aufbereitung steht in
tools/mesh/meshy/ (Räder entfernen, Innenraum weg, nach Texturfarben in Lack/Verkleidung/Glas/Lichter
trennen, Oberfläche glätten, auf 50k Dreiecke reduzieren, ins Spiel-Maß skalieren) und landet in
tools/mesh/vanta_teile.npz. Dieses Skript ergänzt Radhäuser und schreibt OBJ + Karosserien.lua.

Passt zu Auto.MODELLE.gs: Räder R = 1.4 bei x = ±3.0, z = ±5.14, Länge 17.4.
Aufruf:  python3 tools/mesh/vanta.py  ->  dist/mesh/VantaGS.obj, tools/mesh/gs_info.json, src/Karosserien.lua
"""
import json, math, os
import numpy as np
from basis import erzeugen, doppelseitig

HIER = os.path.dirname(os.path.abspath(__file__))
RAD_R = 1.4
SPUR = 3.0
ACHSE = 5.14
SITZ_Y = 1.3

d = np.load(os.path.join(HIER, "vanta_teile.npz"))
meta = json.loads(str(d["meta"]))
namen = sorted({k[:-2] for k in d.files if k.endswith("_V")})


def holen(name):
    return d[name + "_V"].astype(float), d[name + "_F"].astype(int)


def teil_von(V, F, maske):
    Fm = F[maske]
    u, inv = np.unique(Fm, return_inverse=True)
    return V[u], inv.reshape(-1, 3)


def liste(V, F):
    return [tuple(map(float, p)) for p in V], [tuple(map(int, f)) for f in F]


meshes = {}
# Lack in zwei Teile (Roblox: max. 20000 Dreiecke je MeshPart)
V, F = holen("Karosserie")
dachV, dachF = holen("Dach")              # die paar Lackflächen ganz oben (Dachkante) gehören dazu
F = np.concatenate([F, dachF + len(V)])
V = np.concatenate([V, dachV])
fz = V[F].mean(1)[:, 2]
vorne = fz < np.median(fz)
meshes["Karosserie"] = liste(*teil_von(V, F, vorne))
meshes["Heckpartie"] = liste(*teil_von(V, F, ~vorne))   # ohne "a": wird wie Karosserie lackiert (mit Schatten)
meshes["Verkleidung"] = liste(*holen("Verkleidung"))
meshes["Glas"] = liste(*holen("Glas"))
for name in namen:
    if name in meta:
        meshes[name] = (*liste(*holen(name)), meta[name])


def radhaus(z0):
    """schwarze Radhausschale, damit man nach dem Entfernen der Meshy-Räder nicht durchs Auto schaut"""
    r, x0, x1 = 1.72, 1.15, 3.45
    verts, faces = [], []
    n = 24
    for i in range(n + 1):
        w = math.radians(-20 + 220 * i / n)
        y, z = RAD_R + r * math.sin(w), z0 - r * math.cos(w)
        verts += [(x0, y, z), (x1, y, z)]
    for i in range(n):
        a, b = 2 * i, 2 * i + 2
        faces += [(a, b, a + 1), (b, b + 1, a + 1)]
    v2 = [(-x, y, z) for x, y, z in verts]
    f2 = [(a + len(verts), c + len(verts), b + len(verts)) for a, b, c in faces]
    return doppelseitig(verts + v2, faces + f2)


rv, rf = [], []
for z0 in (-ACHSE, ACHSE):
    v, f = radhaus(z0)
    rf += [(a + len(rv), b + len(rv), c + len(rv)) for a, b, c in f]
    rv += list(v)
meshes["Radhaus"] = (rv, rf, {"n": "Radhaus", "a": "schwarz"})

# Kennzeichen, Spoiler-Platz, Kollision aus der echten Form
alle = np.concatenate([holen("Karosserie")[0], holen("Verkleidung")[0]])
def front_z(y):
    m = (np.abs(alle[:, 0]) < 0.6) & (np.abs(alle[:, 1] - y) < 0.2)
    return float(alle[m, 2].min())
def heck_z(y):
    m = (np.abs(alle[:, 0]) < 0.6) & (np.abs(alle[:, 1] - y) < 0.2)
    return float(alle[m, 2].max())
def deck_y(z):
    m = (np.abs(alle[:, 0]) < 0.6) & (np.abs(alle[:, 2] - z) < 0.25)
    return float(alle[m, 1].max())

kennz = {"vorne": [1.45, round(front_z(1.45) - 0.06, 3)], "hinten": [2.05, round(heck_z(2.05) + 0.08, 3)]}
spoiler = [round(deck_y(7.6) + 0.5, 3), 7.6, 0.4]
kollision = [{"g": [6.6, 0.4, 15.6], "p": [0, 2 * RAD_R + 0.3, 0.3]}, {"g": [5.6, 1.3, 7.0], "p": [0, 4.2, 1.0]}]

erzeugen("gs", "VantaGS", "Vanta GS sport sedan body", (RAD_R, SPUR, ACHSE), meshes, [], kollision, kennz, spoiler,
         sitz_y=SITZ_Y, armaturen_z=-2.0)
