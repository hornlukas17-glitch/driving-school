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
from basis import erzeugen, doppelseitig, linie, teil

HIER = os.path.dirname(os.path.abspath(__file__))
RAD_R = 1.4
SPUR = 3.0
ACHSE = 5.14
SITZ_Y = 0.55          # tief, sonst schaut der Kopf durchs flache Dach (in Studio gemessen)

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
normalen = {}
# Teile kommen fertig aufgeteilt aus meshy/c_bauen.py (je max. 20000 Dreiecke):
# Karosserie/Heckpartie(/Mittelteil) = Lack, Verkleidung(2) = schwarz, Glas, Lichter mit Teilnamen
for name in namen:
    V, F = holen(name)
    if len(F) == 0:
        continue
    if name in meta:
        meshes[name] = (*liste(V, F), meta[name])
    else:
        meshes[name] = liste(V, F)
    if name + "_N" in d.files:
        normalen[name] = d[name + "_N"].astype(float)


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
alle = np.concatenate([holen(n)[0] for n in namen if n.startswith(("Karosserie", "Heckpartie", "Mittelteil", "Lack", "Verkleidung"))])
def front_z(y):
    m = (np.abs(alle[:, 0]) < 0.6) & (np.abs(alle[:, 1] - y) < 0.2)
    return float(alle[m, 2].min())
def heck_z(y):
    m = (np.abs(alle[:, 0]) < 0.6) & (np.abs(alle[:, 1] - y) < 0.2)
    return float(alle[m, 2].max())
def deck_y(z):
    m = (np.abs(alle[:, 0]) < 0.6) & (np.abs(alle[:, 2] - z) < 0.25)
    return float(alle[m, 1].max())

# ---- Seitendetails: Türfugen, Griffe, Fensterleiste (auf die echte Oberfläche gelegt) ----
TRI = np.concatenate([holen(n)[0][holen(n)[1]] for n in namen if n.startswith(("Karosserie", "Heckpartie", "Mittelteil", "Lack", "Verkleidung"))])


def seite_x(y, z):
    """äußerste Karosseriefläche rechts bei (y, z): Strahl von außen in -x-Richtung"""
    o = np.array([6.0, y, z]); r = np.array([-1.0, 0, 0])
    e1 = TRI[:, 1] - TRI[:, 0]; e2 = TRI[:, 2] - TRI[:, 0]
    pv = np.cross(r, e2); det = (e1 * pv).sum(1)
    ok = np.abs(det) > 1e-9
    inv = np.where(ok, 1 / np.where(ok, det, 1), 0)
    tv = o - TRI[:, 0]; u = (tv * pv).sum(1) * inv
    qv = np.cross(tv, e1); v = (qv @ r) * inv; t = (qv * e2).sum(1) * inv
    hit = ok & (u >= 0) & (v >= 0) & (u + v <= 1) & (t > 0)
    return float(6.0 - t[hit].min()) if hit.any() else None


details = []
GURT = {-2.7: 3.25, 0.9: 3.38, 4.05: 3.5}              # Unterkante der Seitenscheibe an den Türkanten
for z0, oben in GURT.items():                            # Türkanten (vorne, Mitte, hinten)
    pkt = [[seite_x(y, z0) + 0.006, y, z0] for y in np.linspace(1.05, oben - 0.05, 6) if seite_x(y, z0)]
    details += linie("Fuge", pkt, spiegeln=True)
for z1, z2 in ((-2.6, 0.8), (1.0, 3.95)):                # Unterkante der Türen am Schweller
    pkt = [[seite_x(1.05, z) + 0.006, 1.05, z] for z in np.linspace(z1, z2, 5) if seite_x(1.05, z)]
    details += linie("Fuge", pkt, spiegeln=True)
for zg in (-0.1, 3.2):                                   # bündige Griffe
    y = 2.95
    details.append(teil("Griff", "glanzschwarz", (0.06, 0.12, 0.75), [seite_x(y, zg) + 0.02, y, zg], True))
# Fensterleiste entlang der Gürtellinie
gurt = [(-2.4, 3.3), (-1.0, 3.34), (0.5, 3.4), (2.0, 3.46), (3.5, 3.52), (4.6, 3.6)]
details += linie("Fensterleiste", [[seite_x(y, z) + 0.01, y, z] for z, y in gurt if seite_x(y, z)], art="chrom", dicke=0.05, spiegeln=True)
print("Seitendetails", len(details))

kennz = {"vorne": [1.45, round(front_z(1.45) - 0.06, 3)], "hinten": [2.05, round(heck_z(2.05) + 0.08, 3)]}
spoiler = [round(deck_y(7.6) + 0.5, 3), 7.6, 0.4]
kollision = [{"g": [6.6, 0.4, 15.6], "p": [0, 2 * RAD_R + 0.3, 0.3]}, {"g": [5.6, 1.3, 7.0], "p": [0, 4.2, 1.0]}]

erzeugen("gs", "VantaGS", "Vanta GS sport sedan body", (RAD_R, SPUR, ACHSE), meshes, details, kollision, kennz, spoiler,
         sitz_y=SITZ_Y, armaturen_z=-2.0, drehung=180, sitz_x=0.85, normalen=normalen)   # Studio liest dieses OBJ gedreht ein (in Studio geprüft)
