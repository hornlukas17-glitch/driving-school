"""Fahrschulwagen: Flächen nach Texturfarbe + Lage einteilen. Im Meshy-Modell ist vorne = -x, hinten = +x.
0 Lack, 1 Verkleidung (schwarz/grau), 2 Glas, 3 Scheinwerfer, 4 Rücklicht. Das Dachschild fliegt raus
(das Spiel baut ein eigenes mit lesbarer Schrift), die rot-blauen Streifen werden Lack (der Generator legt
saubere Streifen auf die Karosserie). Aufruf im Arbeitsordner: python3 b_klassen.py [vorschau.png]"""
import numpy as np, sys
from scipy import sparse
sys.path.insert(0, __import__("os").path.join(__import__("os").path.dirname(__import__("os").path.abspath(__file__)), "..", "meshy"))
from ras import rastern
d = np.load("roh.npz"); V, F = d["V"], d["F"]; C = np.load("C.npy")
sicht = np.load("sicht.npy"); rad = np.load("rad.npy")


def schneiden(V, F, felder, maske, wert, achse=0):
    """Dreiecke in 'maske', die die Ebene (achse) = wert kreuzen, an der Ebene teilen (gerade Kante statt Zacken).
    felder: Listen von Arrays je Fläche, die an die neuen Teil-Dreiecke vererbt werden."""
    V = list(map(tuple, V)); neuF = []; erbe = []
    cache = {}
    def schnitt(i, j):
        k = (min(i, j), max(i, j))
        if k not in cache:
            a, b = np.array(V[i]), np.array(V[j]); t = (wert - a[achse]) / (b[achse] - a[achse])
            cache[k] = len(V); V.append(tuple(a + t * (b - a)))
        return cache[k]
    for fi in np.where(maske)[0]:
        tri = F[fi]; s = [V[v][achse] > wert for v in tri]
        if all(s) or not any(s):
            continue
        # die einzelne Ecke auf ihrer Seite finden
        einzeln = [i for i in range(3) if s.count(s[i]) == 1][0]
        a, b, c = tri[einzeln], tri[(einzeln + 1) % 3], tri[(einzeln + 2) % 3]
        p, q = schnitt(a, b), schnitt(a, c)
        neuF += [(a, p, q), (p, b, c), (p, c, q)]
        erbe += [fi, fi, fi]
    if not neuF:
        return np.array(V), F, felder
    weg = np.zeros(len(F), bool); weg[np.unique(erbe)] = True
    F2 = np.concatenate([F[~weg], np.array(neuF)])
    felder = [np.concatenate([f[~weg], f[np.array(erbe)]]) for f in felder]
    return np.array(V), F2, felder


# untere Kante der Frontscheibe gerade schneiden (große Dreiecke liegen quer über der Kante)
_c = V[F].mean(1)
_fn = np.cross(V[F[:, 1]] - V[F[:, 0]], V[F[:, 2]] - V[F[:, 0]]); _fn /= np.linalg.norm(_fn, axis=1, keepdims=True) + 1e-12
KANTE_X = -0.403
bereich = (_fn[:, 1] > 0.2) & (np.abs(_c[:, 2]) < 0.34) & (_c[:, 1] > -0.02) & (_c[:, 1] < 0.2) & (np.abs(_c[:, 0] - KANTE_X) < 0.12)
alt = len(F)
V, F, (C, sicht, rad) = schneiden(V, F, [C, sicht, rad], bereich, KANTE_X)
print("Frontscheibe geschnitten:", len(F) - alt, "Dreiecke mehr")
# Kühlergrill oben und unten gerade schneiden
GRILL_OBEN, GRILL_UNTEN, GRILL_Z = -0.076, -0.122, 0.27
for wert in (GRILL_OBEN, GRILL_UNTEN):
    _c = V[F].mean(1)
    _fn = np.cross(V[F[:, 1]] - V[F[:, 0]], V[F[:, 2]] - V[F[:, 0]]); _fn /= np.linalg.norm(_fn, axis=1, keepdims=True) + 1e-12
    bereich = (_c[:, 0] < -0.78) & (_fn[:, 0] < -0.3) & (np.abs(_c[:, 2]) < GRILL_Z + 0.03) & (np.abs(_c[:, 1] - wert) < 0.05)
    V, F, (C, sicht, rad) = schneiden(V, F, [C, sicht, rad], bereich, wert, achse=1)
c = V[F].mean(1); lum = C.mean(1); r, g, b = C.T
x, y, z = c[:, 0], c[:, 1], np.abs(c[:, 2])
fn = np.cross(V[F[:, 1]] - V[F[:, 0]], V[F[:, 2]] - V[F[:, 0]]); fn /= np.linalg.norm(fn, axis=1, keepdims=True) + 1e-12
E = np.sort(np.concatenate([F[:, [0, 1]], F[:, [1, 2]], F[:, [2, 0]]]), 1)
fid = np.tile(np.arange(len(F)), 3); key = E[:, 0] * len(V) + E[:, 1]
o = np.argsort(key); key = key[o]; fid = fid[o]
gl = np.where(key[1:] == key[:-1])[0]
A = sparse.coo_matrix((np.ones(len(gl) * 2), (np.r_[fid[gl], fid[gl + 1]], np.r_[fid[gl + 1], fid[gl]])), shape=(len(F), len(F))).tocsr()
sparse.save_npz("adj.npz", A)
for _ in range(3):
    n = A @ sicht.astype(float)
    sicht = sicht | ((~rad) & (n >= 2))
# Dachschild weg (Fußabdruck merken: das Spiel setzt sein Schild genau darauf)
schild = (y > 0.302) & (x > 0.12) & (x < 0.48) & (z < 0.33)
print("Dachschild", (schild & sicht).sum(), "x", x[schild].min().round(3), x[schild].max().round(3), "|z|<", z[schild].max().round(3))
np.save("schild.npy", np.array([x[schild].min(), x[schild].max(), z[schild].max(), y[schild].max()]))
sicht = sicht & ~schild
np.save("sicht2.npy", sicht)
L = np.zeros(len(F), int)
dunkel = lum < 0.2
L[dunkel] = 1
L[dunkel & (y > 0.03) & (x > -0.43) & (x < 0.9) & (z < 0.43)] = 2
sw = (x < -0.80) & (y > -0.12) & (y < 0.06) & (z > 0.17) & (lum > 0.25) & (lum < 0.7) & (np.abs(r - b) < 0.12)
L[sw] = 3
rot = (r > 0.35) & (r > 1.8 * g) & (r > 1.8 * b)
L[rot & (x > 0.78)] = 4
grau = (lum >= 0.2) & (lum < 0.5) & (np.abs(r - b) < 0.08) & ~sw
L[grau & (y < -0.12)] = 1
for _ in range(6):
    M = np.zeros((len(F), 5))
    for k in range(5): M[:, k] = A @ (L == k).astype(float)
    M[np.arange(len(F)), L] += 1.2
    L = M.argmax(1)
# erst nach dem Glätten: Scheibenkanten aus der Geometrie (die Textur hat dort Zacken).
# 'fest' = diese Flächen glättet c_bauen.py nicht mehr um.
fest = np.zeros(len(F), bool)
gurt = 0.062 + 0.07 * (x + 0.4)
oben = np.minimum(0.255, 0.15 + (x + 0.33) * 0.5)
seite = (np.abs(fn[:, 2]) > 0.55) & (z > 0.28) & (z < 0.43)
m = seite & (x > -0.36) & (x < 0.62) & (y > gurt) & (y < oben)
L[m] = 2; fest |= m
m = (fn[:, 1] > 0.2) & (z < 0.33) & (x > KANTE_X) & (x < -0.09) & (y > 0.06)
L[m] = 2; fest |= m
m = (fn[:, 1] > 0.2) & (z < 0.33) & (x <= KANTE_X) & (y > -0.05) & (L != 3)
L[m] = 0; fest |= m & (x > KANTE_X - 0.06)
m = (x < -0.78) & (fn[:, 0] < -0.3) & (z < GRILL_Z) & (y > GRILL_UNTEN) & (y < GRILL_OBEN) & (L != 3)
L[m] = 1; fest |= m                                    # Kühlergrill ganz schwarz (Textur hat weiße Zacken)
m = (x < -0.78) & (fn[:, 0] < -0.3) & (z < GRILL_Z) & (y >= GRILL_OBEN) & (y < GRILL_OBEN + 0.03) & (L == 1)
L[m] = 0; fest |= m                                    # direkt darüber: Lack (gerade Oberkante)
np.save("fest.npy", fest)
for k in range(5): print("Klasse", k, (sicht & (L == k)).sum())
np.save("L.npy", L)
np.savez("geschnitten.npz", V=V, F=F)
if len(sys.argv) > 1:
    from PIL import Image
    PAL = np.array([[0.92, 0.93, 0.95], [0.08, 0.08, 0.09], [0.15, 0.35, 0.7], [1, 1, 0.6], [0.9, 0.05, 0.05]])
    idx = np.where(sicht)[0]
    bilder = [Image.fromarray(rastern(V, F[idx], PAL[L[idx]], az, el, W=900, H=520, s=430, bg=0.75)) for az, el in [(180, 8), (0, 8), (90, 10), (-35, 25)]]
    blatt = Image.new("RGB", (1800, 1040))
    for i, bb in enumerate(bilder): blatt.paste(bb, ((i % 2) * 900, (i // 2) * 520))
    blatt.save(sys.argv[1])
