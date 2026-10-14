"""Karosserie fürs Fahrschulauto "Fahrschulwagen" (eigenes Design von Lukas, mit Meshy erzeugt).

Grundlage: Lukas' Meshy-Modell (kompakter Fünftürer mit Dachschild und rot-blauen Streifen).
Aufbereitung in tools/mesh/meshy_fahrschule/ (Räder, Innenraum und Dachschild weg, Lack/Verkleidung/Glas/
Lichter trennen, gerade Scheibenkanten, ins Spielmaß) -> tools/mesh/fahrschule_teile.npz.
Dieses Skript ergänzt Radhäuser, die Fahrschul-Streifen (rot/blau, auf die Karosserie gelegt), Blinker,
Kennzeichen-Plätze und den Platz fürs Dachschild und schreibt OBJ + Karosserien.lua.

Passt exakt zum bisherigen Fahrschulauto (Auto.bauen): Räder R = 1.3 bei x = ±3.2, z = ±4.8 –
das Fahrverhalten bleibt gleich, nur die Optik wechselt.
Aufruf:  python3 tools/mesh/fahrschulwagen.py  ->  dist/mesh/Fahrschulwagen.obj, tools/mesh/fahrschule_info.json, src/Karosserien.lua
"""
import json, math, os
import numpy as np
from basis import erzeugen, doppelseitig, teil

HIER = os.path.dirname(os.path.abspath(__file__))
RAD_R, SPUR, ACHSE = 1.3, 3.2, 4.8

d = np.load(os.path.join(HIER, "fahrschule_teile.npz"))
meta = json.loads(str(d["meta"])); masse = json.loads(str(d["masse"]))
namen = sorted({k[:-2] for k in d.files if k.endswith("_V")})


def holen(name):
    return d[name + "_V"].astype(float), d[name + "_F"].astype(int)


def liste(V, F):
    return [tuple(map(float, p)) for p in V], [tuple(map(int, f)) for f in F]


meshes, normalen = {}, {}
for name in namen:
    V, F = holen(name)
    if len(F) == 0:
        continue
    meshes[name] = (*liste(V, F), meta[name]) if name in meta else liste(V, F)
    if name + "_N" in d.files:
        normalen[name] = d[name + "_N"].astype(float)


# ---- Radhäuser: schwarze Schalen, damit man ohne die Meshy-Räder nicht durchs Auto schaut ----
def radhaus(z0):
    r, x0, x1 = 1.62, 1.55, 3.45
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

# ---- Strahlen auf die echte Oberfläche (Lack + Verkleidung) ----
KOERPER = [n for n in namen if n.startswith(("Karosserie", "Heckpartie", "Mittelteil", "Lack", "Verkleidung"))]
TRI = np.concatenate([holen(n)[0][holen(n)[1]] for n in KOERPER])
E1 = TRI[:, 1] - TRI[:, 0]; E2 = TRI[:, 2] - TRI[:, 0]
FN = np.cross(E1, E2); FN /= np.linalg.norm(FN, axis=1, keepdims=True) + 1e-12


def strahl(o, r):
    """nächster Treffer von o in Richtung r -> (Punkt, Normale zum Strahl hin) oder None"""
    o = np.asarray(o, float); r = np.asarray(r, float)
    pv = np.cross(r, E2); det = (E1 * pv).sum(1)
    ok = np.abs(det) > 1e-9
    inv = np.where(ok, 1 / np.where(ok, det, 1), 0)
    tv = o - TRI[:, 0]; u = (tv * pv).sum(1) * inv
    qv = np.cross(tv, E1); v = (qv @ r) * inv; t = (qv * E2).sum(1) * inv
    hit = ok & (u >= 0) & (v >= 0) & (u + v <= 1) & (t > 0)
    if not hit.any():
        return None
    i = np.where(hit)[0][np.argmin(t[hit])]
    n = FN[i] if FN[i] @ r < 0 else -FN[i]
    return o + t[i] * r, n


# ---- Fahrschul-Streifen: rot über blau, steigen nach hinten an (wie in Lukas' Modell) ----
ABSTAND = 0.025      # über der Oberfläche, damit nichts flimmert


def band_seite(z_von, z_bis, y_mitte, hoehe):
    """Band auf der rechten Seite (x > 0): Gitter aus Strahlen von außen; y_mitte(z) = Mittellinie"""
    zs = np.arange(z_von, z_bis + 1e-6, 0.2)
    reihen = np.linspace(-hoehe / 2, hoehe / 2, 4)
    gitter = []
    for z in zs:
        spalte = []
        for dy in reihen:
            h = strahl((7.0, y_mitte(z) + dy, z), (-1.0, 0, 0))
            spalte.append(None if h is None else h[0] + h[1] * ABSTAND)
        gitter.append(spalte)
    return flaeche_aus_gitter(gitter)


def band_haube(x_von, x_bis, z_von, z_bis):
    zs = np.arange(z_von, z_bis + 1e-6, 0.2)
    xs = np.linspace(x_von, x_bis, 4)
    gitter = []
    for z in zs:
        spalte = []
        for x in xs:
            h = strahl((x, 9.0, z), (0, -1.0, 0))
            spalte.append(None if h is None else h[0] + h[1] * ABSTAND)
        gitter.append(spalte)
    return flaeche_aus_gitter(gitter)


def flaeche_aus_gitter(gitter):
    verts, faces, idx = [], [], {}
    for i, spalte in enumerate(gitter):
        for j, p in enumerate(spalte):
            if p is not None:
                idx[(i, j)] = len(verts); verts.append(tuple(map(float, p)))
    for i in range(len(gitter) - 1):
        for j in range(len(gitter[0]) - 1):
            q = [(i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1)]
            if all(k in idx for k in q):
                a, b, c, e = (idx[k] for k in q)
                faces += [(a, b, c), (a, c, e)]
    return verts, faces


def beidseitig(teil_rechts):
    """rechte Seite + gespiegelt links, Flächen nach außen gedreht"""
    v, f = teil_rechts
    # Ausrichtung prüfen: Normale soll nach außen (+x) zeigen
    if f:
        a, b, c = (np.array(v[i]) for i in f[0])
        if np.cross(b - a, c - a)[0] < 0:
            f = [(a, c, b) for a, b, c in f]
    v2 = [(-x, y, z) for x, y, z in v]
    f2 = [(a + len(v), c + len(v), b + len(v)) for a, b, c in f]
    return v + v2, f + f2


def nach_oben(teil_):
    v, f = teil_
    if f:
        a, b, c = (np.array(v[i]) for i in f[0])
        if np.cross(b - a, c - a)[1] < 0:
            f = [(a, c, b) for a, b, c in f]
    return v, f


blau_y = lambda z: 2.05 + 0.137 * (z + 3.0)
rot_y = lambda z: blau_y(z) + 0.6
meshes["StreifenBlau"] = (*beidseitig(band_seite(-3.0, 6.2, blau_y, 0.42)), {"n": "Streifen", "a": "streifen_blau"})
meshes["StreifenRot"] = (*beidseitig(band_seite(-3.0, 6.2, rot_y, 0.42)), {"n": "Streifen", "a": "streifen_rot"})
haube_hinten = (-0.403 - (0.630 - 0.561) / 2) * masse["SK"] + 0.25     # kurz vor der Frontscheibe
v1, f1 = nach_oben(band_haube(-1.35, -0.95, -7.35, haube_hinten))
v2, f2 = nach_oben(band_haube(-0.82, -0.42, -7.35, haube_hinten))
meshes["HaubeRot"] = (v1, f1, {"n": "Streifen", "a": "streifen_rot"})
meshes["HaubeBlau"] = (v2, f2, {"n": "Streifen", "a": "streifen_blau"})
for n in ("StreifenBlau", "StreifenRot", "HaubeRot", "HaubeBlau"):
    print(n, len(meshes[n][1]), "Dreiecke")

# ---- Anbauteile: Blinker vorne/hinten/Spiegel (das Spiel lässt sie bei Fahrstunden blinken) ----
anbau = []
LV = holen("LichtV")[0]; LH = holen("LichtH")[0]
aussen = LV[LV[:, 0] > 0]; p = aussen[np.argmax(aussen[:, 0])]
h = strahl((p[0] - 0.2, p[1] - 0.05, -9.0), (0, 0, 1.0))
anbau.append(teil("Blinker", "blinker", (0.38, 0.22, 0.1), [p[0] - 0.2, p[1] - 0.05, h[0][2] - 0.02 if h else p[2]], True))
rechts = LH[LH[:, 0] > 0]; p = rechts[np.argmin(rechts[:, 0])]         # innere Ecke des Rücklichts
y_b = float(np.median(rechts[:, 1]))
h = strahl((p[0] - 0.25, y_b, 9.0), (0, 0, -1.0))
anbau.append(teil("Blinker", "blinker", (0.4, 0.2, 0.1), [p[0] - 0.25, y_b, h[0][2] + 0.03 if h else p[2]], True))
# Spiegel: äußerster Punkt der Verkleidung/Karosserie oberhalb der Gürtellinie vorne
alle = np.concatenate([holen(n)[0] for n in KOERPER])
sp = alle[(alle[:, 1] > 3.6) & (alle[:, 2] < -1.0) & (alle[:, 0] > 0)]
sp = sp[np.argmax(sp[:, 0])]
anbau.append(teil("Blinker", "blinker", (0.45, 0.08, 0.08), [sp[0] - 0.25, sp[1] - 0.3, sp[2] - 0.05], True))
print("Spiegel bei", sp.round(2))


# ---- Kennzeichen, Kollision, Dachschild ----
def front_z(y):
    m = (np.abs(alle[:, 0]) < 0.6) & (np.abs(alle[:, 1] - y) < 0.2)
    return float(alle[m, 2].min())


def heck_z(y):
    m = (np.abs(alle[:, 0]) < 0.6) & (np.abs(alle[:, 1] - y) < 0.2)
    return float(alle[m, 2].max())


kennz = {"vorne": [1.55, round(front_z(1.55) - 0.06, 3)], "hinten": [2.55, round(heck_z(2.55) + 0.06, 3)]}
kollision = [{"g": [7.0, 0.5, 15.0], "p": [0, 2 * RAD_R + 0.35, -0.2]}, {"g": [6.0, 1.4, 7.5], "p": [0, 4.4, 0.8]}]
sch = masse["schild"]
dachschild = {"z": round((sch["z0"] + sch["z1"]) / 2, 3), "tiefe": round(sch["z1"] - sch["z0"] + 0.06, 3),
              "breite": round(sch["breite"] + 0.06, 3), "y": round(sch["dach_y"], 3)}
print("Dachschild", dachschild, "Kennzeichen", kennz)

erzeugen("fahrschule", "Fahrschulwagen", "Driving school car body", (RAD_R, SPUR, ACHSE), meshes, anbau, kollision, kennz,
         [round(sch["dach_y"] + 0.3, 3), 5.6, 0.4], normalen=normalen,
         extra={"dachschild": dachschild, "autodrehung": True})   # das Spiel erkennt selbst, ob der Importer das Modell gedreht hat
