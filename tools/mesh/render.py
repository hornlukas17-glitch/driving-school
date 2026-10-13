"""Vorschau einer OBJ-Karosserie (kleiner Software-Renderer mit Tiefenpuffer).

python3 render.py <obj> <info.json> <png> [farbe=r,g,b]
Räder, Lichter und Anbauteile werden wie im Spiel als einfache Formen dazugezeichnet.
"""
import sys, json
import numpy as np
from PIL import Image

obj, info_pfad, png = sys.argv[1:4]
KFARBE = tuple(float(x) for x in (sys.argv[4] if len(sys.argv) > 4 else "0.12,0.25,0.2").split(","))

# ---------- Geometrie sammeln: (Dreiecke Nx3x3, Farbe, Glanz, Transparenz) ----------
teile = []
objs = {}; cur = None; V = []
for line in open(obj):
    if line.startswith("o "): cur = line.split()[1]; objs[cur] = []
    elif line.startswith("v "): V.append([float(x) for x in line.split()[1:]])
    elif line.startswith("f "): objs[cur].append([int(x) - 1 for x in line.split()[1:]])
V = np.array(V)
INFO = json.load(open(info_pfad))
R, SPUR, ACHSE = INFO["rad"]
ART = {"lack": (KFARBE, 0.5), "chrom": ((0.75, 0.75, 0.78), 0.9), "alu": ((0.66, 0.66, 0.69), 0.9),
       "schwarz": ((0.03, 0.03, 0.035), 0.2), "carbon": ((0.09, 0.09, 0.1), 0.4), "grill": ((0.07, 0.07, 0.08), 0.3),
       "scheinwerfer": ((0.95, 0.97, 1.0), 1), "neon_weiss": ((0.95, 0.95, 0.95), 1), "neon_rot": ((0.75, 0.04, 0.04), 0.8),
       "blinker": ((0.6, 0.38, 0.14), 0.5), "fuge": ((0.02, 0.02, 0.025), 0.1), "glanzschwarz": ((0.02, 0.02, 0.025), 0.9),
       "rueckglas": ((0.35, 0.02, 0.03), 0.9)}
FARBEN = {"Karosserie": (KFARBE, 0.5), "Heckpartie": (KFARBE, 0.5), "Dach": (KFARBE, 0.5), "Verkleidung": ((0.06, 0.06, 0.065), 0.1), "Glas": ((0.05, 0.07, 0.1), 0.5)}
for name, f in objs.items():
    art = INFO["mesh"].get(name, {}).get("a")
    farbe, glanz = ART[art] if art in ART else FARBEN.get(name, ((0.5, 0.5, 0.5), 0.5))
    teile.append((V[np.array(f)], farbe, glanz))



def box(mitte, groesse, farbe, glanz=0.2, dreh=None):
    sx, sy, sz = (g / 2 for g in groesse)
    e = np.array([[a * sx, b * sy, c * sz] for a in (-1, 1) for b in (-1, 1) for c in (-1, 1)])
    if dreh is not None: e = e @ dreh.T
    e += np.array(mitte)
    q = [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]
    tri = [[e[a], e[b], e[c]] for a, b, c, d in q] + [[e[a], e[c], e[d]] for a, b, c, d in q]
    teile.append((np.array(tri), farbe, glanz))


def zylinder(mitte, radius, breite, farbe, glanz=0.1, n=36):
    x0, y0, z0 = mitte
    w = np.linspace(0, 2 * np.pi, n + 1)
    tri = []
    for i in range(n):
        a, b = w[i], w[i + 1]
        p = [(y0 + radius * np.sin(a), z0 + radius * np.cos(a)), (y0 + radius * np.sin(b), z0 + radius * np.cos(b))]
        l, r = x0 - breite / 2, x0 + breite / 2
        tri += [[(l, *p[0]), (r, *p[0]), (r, *p[1])], [(l, *p[0]), (r, *p[1]), (l, *p[1])]]
        tri += [[(r, y0, z0), (r, *p[1]), (r, *p[0])], [(l, y0, z0), (l, *p[0]), (l, *p[1])]]
    teile.append((np.array(tri, dtype=float), farbe, glanz))




def drehung(r):
    ax, ay, az = (np.radians(v) for v in r)
    rx = np.array([[1, 0, 0], [0, np.cos(ax), -np.sin(ax)], [0, np.sin(ax), np.cos(ax)]])
    ry = np.array([[np.cos(ay), 0, np.sin(ay)], [0, 1, 0], [-np.sin(ay), 0, np.cos(ay)]])
    rz = np.array([[np.cos(az), -np.sin(az), 0], [np.sin(az), np.cos(az), 0], [0, 0, 1]])
    return rx @ ry @ rz


for s in (-1, 1):
    for rz in (-ACHSE, ACHSE):
        zylinder((s * SPUR, R, rz), R, 1.3, (0.04, 0.04, 0.04), 0.05)
        zylinder((s * (SPUR + 0.03), R, rz), R * 0.66, 1.32, (0.72, 0.73, 0.76), 0.9)
        zylinder((s * (SPUR + 0.04), R, rz), R * 0.2, 1.34, (0.2, 0.2, 0.22), 0.5)
for t in INFO["anbau"]:
    farbe, glanz = ART.get(t["a"], ART["schwarz"])
    for s in ((-1, 1) if t["s"] else (1,)):
        r = t.get("r")
        if t.get("d"):
            z = np.array([s * t["d"][0], t["d"][1], t["d"][2]], float)
            x = np.cross([0, 1, 0], z) if abs(z[1]) < 0.99 else np.cross([1, 0, 0], z)
            x /= np.linalg.norm(x); y = np.cross(z, x)
            box((s * t["p"][0], t["p"][1], t["p"][2]), t["g"], farbe, glanz, np.column_stack([x, y, z]))
        else:
            box((s * t["p"][0], t["p"][1], t["p"][2]), t["g"], farbe, glanz, drehung((r[0], s * r[1], s * r[2])) if r else None)
for ende in ("vorne", "hinten"):
    y, z = INFO["kennzeichen"][ende]
    box((0, y, z), (2.6, 0.7, 0.1), (0.95, 0.95, 0.95), 0.1)


# ---------- Renderer ----------
def rendern(azim, elev, B=900, H=520, abstand=34.0, fov=34):
    a, e = np.radians(azim), np.radians(elev)
    ziel = np.array([0, 3.4, 0])
    auge = ziel + abstand * np.array([np.sin(a) * np.cos(e), np.sin(e), -np.cos(a) * np.cos(e)])
    vorw = ziel - auge; vorw /= np.linalg.norm(vorw)
    rechts = np.cross(vorw, [0, 1, 0]); rechts /= np.linalg.norm(rechts)
    hoch = np.cross(rechts, vorw)
    f = (H / 2) / np.tan(np.radians(fov / 2))
    bild = np.ones((H, B, 3)) * np.linspace(0.93, 0.8, H)[:, None, None]
    tiefe = np.full((H, B), np.inf)
    sonne = np.array([0.45, 0.8, -0.35]); sonne /= np.linalg.norm(sonne)
    # Boden-Schatten
    for x in range(B):
        pass
    for tri, farbe, glanz in teile:
        rel = tri - auge
        cx = rel @ rechts; cy = rel @ hoch; cz = rel @ vorw
        n = np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0])
        n /= np.linalg.norm(n, axis=1, keepdims=True) + 1e-12
        mitte = tri.mean(axis=1)
        zum_auge = auge - mitte; zum_auge /= np.linalg.norm(zum_auge, axis=1, keepdims=True)
        n = np.where(((n * zum_auge).sum(1) < 0)[:, None], -n, n)       # beidseitig beleuchten
        diff = np.clip(n @ sonne, 0, 1)
        halb = sonne[None, :] + zum_auge; halb /= np.linalg.norm(halb, axis=1, keepdims=True)
        spec = np.clip((n * halb).sum(1), 0, 1) ** 40 * glanz
        himmel = np.clip(n[:, 1], 0, 1) * 0.25 * glanz
        col = np.array(farbe)[None, :] * (0.28 + 0.72 * diff[:, None]) + (spec + himmel)[:, None] * 0.9
        col = np.clip(col, 0, 1)
        sx = B / 2 + f * cx / cz; sy = H / 2 - f * cy / cz
        for i in range(len(tri)):
            if (cz[i] <= 0.1).any(): continue
            xs, ys, zs = sx[i], sy[i], cz[i]
            x0, x1 = int(max(0, np.floor(xs.min()))), int(min(B - 1, np.ceil(xs.max())))
            y0, y1 = int(max(0, np.floor(ys.min()))), int(min(H - 1, np.ceil(ys.max())))
            if x0 > x1 or y0 > y1: continue
            gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
            d = (ys[1] - ys[2]) * (xs[0] - xs[2]) + (xs[2] - xs[1]) * (ys[0] - ys[2])
            if abs(d) < 1e-9: continue
            w0 = ((ys[1] - ys[2]) * (gx - xs[2]) + (xs[2] - xs[1]) * (gy - ys[2])) / d
            w1 = ((ys[2] - ys[0]) * (gx - xs[2]) + (xs[0] - xs[2]) * (gy - ys[2])) / d
            w2 = 1 - w0 - w1
            innen = (w0 >= -1e-4) & (w1 >= -1e-4) & (w2 >= -1e-4)
            if not innen.any(): continue
            z = 1 / (w0 / zs[0] + w1 / zs[1] + w2 / zs[2])
            ausschnitt = tiefe[y0:y1 + 1, x0:x1 + 1]
            besser = innen & (z < ausschnitt)
            ausschnitt[besser] = z[besser]
            bild[y0:y1 + 1, x0:x1 + 1][besser] = col[i]
    return (bild * 255).astype(np.uint8)


ansichten = [(-35, 12), (-90, 3), (145, 14), (0, 6)]
bilder = [rendern(a, e) for a, e in ansichten]
oben = np.concatenate(bilder[:2], axis=1); unten = np.concatenate(bilder[2:], axis=1)
Image.fromarray(np.concatenate([oben, unten], axis=0)).save(png)
print("gespeichert", png)
