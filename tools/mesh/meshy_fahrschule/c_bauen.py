"""Fahrschulwagen: aus den eingeteilten Meshy-Flächen die Spielteile bauen -> tools/mesh/fahrschule_teile.npz

- ins Spielmaß: Achsabstand wie beim bisherigen Fahrschulauto (9,6 Studs), Radmitte auf R = 1,3, vorne = -z
- Fransen unten und lose Splitter weg, Beschriftung glätten
- Lack + Verkleidung gemeinsam reduzieren (Ränder zu Glas/Lichtern bleiben fest), Glas und Lichter getrennt
- Normalen mit Knickwinkel: glatte Flächen, aber die Kanten des Low-Poly-Stils bleiben scharf
Aufruf im Arbeitsordner (nach a_sicht.py und b_klassen.py): python3 c_bauen.py
"""
import json, os, sys
import numpy as np
import fast_simplification as fs
from scipy import sparse
from scipy.sparse.csgraph import connected_components
from scipy.spatial import cKDTree

HIER = os.path.dirname(os.path.abspath(__file__))
d = np.load("geschnitten.npz"); V0, F0 = d["V"], d["F"]      # aus b_klassen.py (Frontscheibenkante geschnitten)
L0 = np.load("L.npy"); S = np.load("sicht2.npy"); FEST0 = np.load("fest.npy")
SK = 9.6 / (0.630 + 0.561)          # Achsen im Modell bei x = -0.561 (vorne) und 0.630 (hinten)
XM = (0.630 - 0.561) / 2
Y0 = -0.273 - 1.3 / SK              # Radmitte (y = -0.273) liegt im Spiel auf 1.3


def spiel(P):
    return np.stack([-P[:, 2] * SK, (P[:, 1] - Y0) * SK, (P[:, 0] - XM) * SK], 1)


F = F0[S]; L = L0[S].copy(); FEST = FEST0[S]
u, inv = np.unique(F, return_inverse=True); V = spiel(V0[u]); F = inv.reshape(-1, 3)
cy = V[F].mean(1)[:, 1]
F = F[cy > 0.62]; L = L[cy > 0.62]; FEST = FEST[cy > 0.62]           # Reifenreste und Fransen unten weg


def adj_faces(F, nv):
    E = np.sort(np.concatenate([F[:, [0, 1]], F[:, [1, 2]], F[:, [2, 0]]]), 1)
    fid = np.tile(np.arange(len(F)), 3); key = E[:, 0] * nv + E[:, 1]
    o = np.argsort(key); key = key[o]; fid = fid[o]
    g = np.where(key[1:] == key[:-1])[0]
    return sparse.coo_matrix((np.ones(len(g) * 2), (np.r_[fid[g], fid[g + 1]], np.r_[fid[g + 1], fid[g]])), shape=(len(F), len(F))).tocsr()


A = adj_faces(F, len(V))
n, comp = connected_components(A, directed=False)
keep = np.bincount(comp)[comp] >= 300
print("Inseln", n, "entfernt", (~keep).sum())
F = F[keep]; L = L[keep]; FEST = FEST[keep]; A = adj_faces(F, len(V))
L_fest = L.copy()
for _ in range(12):
    M = np.zeros((len(F), 5))
    for k in range(5): M[:, k] = A @ (L == k).astype(float)
    M[np.arange(len(F)), L] += 1.1
    L = M.argmax(1)
    L[FEST] = L_fest[FEST]
for k, grenze in ((0, 120), (1, 25), (2, 120)):
    m = L == k
    nc, cc = connected_components(A[m][:, m], directed=False)
    idx = np.where(m)[0][np.bincount(cc)[cc] < grenze]
    if len(idx):
        M = np.zeros((len(idx), 5))
        for j in range(5): M[:, j] = A[idx] @ (L == j).astype(float)
        M[:, k] = -1
        L[idx] = M.argmax(1)
    L[FEST] = L_fest[FEST]
    print("Label", k, "Inseln", nc, "angeglichen", len(idx))
u, inv = np.unique(F, return_inverse=True); V = V[u]; F = inv.reshape(-1, 3)
cen = V[F].mean(1)


def teil(maske):
    Fm = F[maske]; uu, ii = np.unique(Fm, return_inverse=True)
    return V[uu], ii.reshape(-1, 3)


def reduziere(Vx, Fx, ziel):
    if len(Fx) <= ziel:
        return Vx, Fx
    return fs.simplify(Vx, Fx, target_count=ziel, agg=5, preserve_border=True)


meshes = {}
# Lack und Verkleidung getrennt reduzieren: die gemeinsame Kante bleibt fest -> gerade Kanten, keine Risse
Vl_, Fl_ = reduziere(*teil(L == 0), 38000)
Vv_, Fv_ = reduziere(*teil(L == 1), 18000)
Vr = np.concatenate([Vl_, Vv_]); Fr = np.concatenate([Fl_, Fv_ + len(Vl_)])
Lr = np.r_[np.zeros(len(Fl_), bool), np.ones(len(Fv_), bool)]       # True = Verkleidung
print("Lack", len(Fl_), "Verkleidung", len(Fv_))
Ar = adj_faces(Fr, len(Vr))
cr = Vr[Fr].mean(1)
def stueck(Vx, Fx, m):
    Fm = Fx[m]; uu, ii = np.unique(Fm, return_inverse=True)
    return Vx[uu], ii.reshape(-1, 3)


def aufteilen(maske, namen, meta=None):
    zz = cr[maske, 2]; gr = np.quantile(zz, np.linspace(0, 1, len(namen) + 1)); gr[0] -= 1; gr[-1] += 1
    for i, name in enumerate(namen):
        m = maske & (cr[:, 2] > gr[i]) & (cr[:, 2] <= gr[i + 1])
        Vx, Fx = stueck(Vr, Fr, m)
        assert len(Fx) <= 20000, (name, len(Fx))
        meshes[name] = (Vx, Fx, meta) if meta and i > 0 else (Vx, Fx)
        print(name, len(Fx))


aufteilen(~Lr, ["Karosserie", "Heckpartie", "Mittelteil", "Lack4"][:int(np.ceil((~Lr).sum() / 19000))])
aufteilen(Lr, ["Verkleidung", "Verkleidung2"][:int(np.ceil(Lr.sum() / 19000))], {"n": "Verkleidung2", "a": "schwarz"})
Vg, Fg = reduziere(*teil(L == 2), 9000); meshes["Glas"] = (Vg, Fg); print("Glas", len(Fg))
Vl, Fl = reduziere(*teil(L == 3), 2500); meshes["LichtV"] = (Vl, Fl, {"n": "Scheinwerfer", "a": "scheinwerfer"}); print("LichtV", len(Fl))
Vl, Fl = reduziere(*teil(L == 4), 2500); meshes["LichtH"] = (Vl, Fl, {"n": "Ruecklicht", "a": "neon_rot"}); print("LichtH", len(Fl))


# ---- Normalen mit Knickwinkel (35°): jede Ecke mittelt nur über Flächen, die ähnlich stehen ----
def knick_normalen(Vx, Fx, grad=35):
    fn = np.cross(Vx[Fx[:, 1]] - Vx[Fx[:, 0]], Vx[Fx[:, 2]] - Vx[Fx[:, 0]])
    fl = np.linalg.norm(fn, axis=1, keepdims=True) + 1e-12
    fe = fn / fl
    # Flächen je Ecke
    ecken = Fx.ravel(); flaeche = np.repeat(np.arange(len(Fx)), 3)
    o = np.argsort(ecken); ecken_s = ecken[o]; flaeche_s = flaeche[o]
    start = np.searchsorted(ecken_s, np.arange(len(Vx))); ende = np.searchsorted(ecken_s, np.arange(len(Vx)), side="right")
    cosg = np.cos(np.radians(grad))
    NV, NN, NF = [], [], np.zeros_like(Fx)
    index = {}
    for fi in range(len(Fx)):
        for j in range(3):
            v = Fx[fi, j]
            nachbarn = flaeche_s[start[v]:ende[v]]
            gut = nachbarn[(fe[nachbarn] @ fe[fi]) > cosg]
            nrm = fn[gut].sum(0); nrm /= np.linalg.norm(nrm) + 1e-12
            k = (v, tuple(np.round(nrm, 2)))
            if k not in index:
                index[k] = len(NV); NV.append(Vx[v]); NN.append(nrm)
            NF[fi, j] = index[k]
    return np.array(NV), NF, np.array(NN)


out = {}; meta = {}
for name, m in meshes.items():
    Vx, Fx, Nx = knick_normalen(m[0], m[1])
    out[name + "_V"] = Vx.astype(np.float32); out[name + "_F"] = Fx.astype(np.int32); out[name + "_N"] = Nx.astype(np.float32)
    if len(m) > 2 and m[2]:
        meta[name] = m[2]
    print("Normalen", name, len(m[0]), "->", len(Vx), "Ecken")
sch = np.load("schild.npy")            # Fußabdruck des Meshy-Dachschilds -> Platz für das Spiel-Schild
masse = {"schild": {"z0": round(float((sch[0] - XM) * SK), 3), "z1": round(float((sch[1] - XM) * SK), 3),
                    "breite": round(float(2 * sch[2] * SK), 3), "dach_y": round(float((0.302 - Y0) * SK), 3)},
         "SK": SK}
out["meta"] = np.array(json.dumps(meta)); out["masse"] = np.array(json.dumps(masse))
ziel = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HIER, "..", "fahrschule_teile.npz")
np.savez_compressed(ziel, **out)
print("gespeichert", ziel, masse)
