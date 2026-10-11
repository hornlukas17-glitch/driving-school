"""Generates a smooth compact premium sedan body (A3-sedan-like proportions, no logos) (lower body, greenhouse glass, roof) as OBJ for Roblox.
Car coordinates: x = right, y = up, z = backwards (the car drives towards -z).
Dimensions match the hinge chassis in Auto.lua (wheels r=1.3 at x=+-3.2, z=+-4.8).
"""
import math, json
import numpy as np

N_SLICE = 72          # slices along the car
N_RING = 48           # points around a cross-section
LAENGE = 8.0          # half length (bumper to bumper = 16.0, about 4.50 m)
RAD_Z = 4.8           # axle position
ARCH_R = 1.8          # wheel arch radius (plan) / height above ground clearance

def smooth(t):
    t = min(max(t, 0.0), 1.0)
    return t * t * (3 - 2 * t)

# ---------------- lower body ----------------
def halbbreite(z):
    u = abs(z) / LAENGE
    vorne = z < 0
    n = 6.0 if vorne else 9.0           # fairly square nose, very square hatchback tail
    return 3.58 * max(0.0, 1 - u ** n) ** (1 / n)

def boden(z):
    b = 1.0
    for rz in (-RAD_Z, RAD_Z):
        dz = z - rz
        if abs(dz) < ARCH_R:
            b = max(b, 1.0 + 1.85 * math.sqrt(1 - (dz / ARCH_R) ** 2))
    if abs(z) > 6.6:
        b = max(b, 1.0 + 0.55 * ((abs(z) - 6.6) / (LAENGE - 6.6)) ** 2)
    return b

def oben(z):
    if z < -2.7:                         # hood, falling gently towards a blunt nose
        t = (-2.7 - z) / (LAENGE - 2.7)
        return 3.42 - 0.5 * t ** 1.8
    if z <= 5.2:                         # long, straight shoulder line
        return 3.42 + 0.06 * smooth((z + 2.7) / 7.9)
    t = (z - 5.2) / (LAENGE - 5.2)     # short trunk deck with a lip, then a vertical tail
    return 3.48 + 0.1 * smooth(t / 0.75) - 0.75 * smooth((t - 0.8) / 0.2) ** 1.2

def querschnitt_unten(z, n_exp=5.0):
    a = halbbreite(z)
    b, t = boden(z), oben(z)
    yc, h = (b + t) / 2, (t - b) / 2
    pts = []
    for i in range(N_RING):
        w = 2 * math.pi * i / N_RING
        c, s = math.cos(w), math.sin(w)
        x = a * math.copysign(abs(c) ** (2 / n_exp), c)
        y = yc + h * math.copysign(abs(s) ** (2 / n_exp), s)
        pts.append((x, y, z))
    return pts

# ---------------- greenhouse (glass) and roof ----------------
G_VON, G_BIS = -2.75, 5.45
DACH = 5.85
def gh_oben(z):
    if z < -0.2:                         # windshield, slightly curved
        t = (z - G_VON) / (-0.2 - G_VON)
        return 3.42 + (DACH - 3.42) * (1 - (1 - t) ** 1.7)
    if z <= 2.3:                         # roof arc
        return DACH + 0.05 * math.sin(math.pi * (z + 0.2) / 2.5)
    t = (z - 2.3) / (G_BIS - 2.3)        # long, flat rear window down to the trunk
    return DACH - (DACH - 3.5) * t ** 1.15

def gh_breite(z, y):
    # tumblehome: narrower towards the roof, rounded ends
    basis = 3.3
    hoehe = (y - 3.36) / (DACH - 3.36)
    w = basis - 0.55 * max(0.0, hoehe) ** 1.3
    u = (z - (G_VON + G_BIS) / 2) / ((G_BIS - G_VON) / 2)
    return w * max(0.0, 1 - abs(u) ** 8) ** (1 / 8)

def querschnitt_glas(z, unten=3.36, n_exp=6.0):
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

def loft(querschnitt, z0, z1, n=N_SLICE, ende_spitz=True):
    zs = [z0 + (z1 - z0) * (0.5 - 0.5 * math.cos(math.pi * i / (n - 1))) for i in range(n)]  # denser at the ends
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
    # caps (fan around the ring centre)
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
    """make every triangle face outwards (away from the shape's local centre line)"""
    v = np.array(verts)
    neu = []
    for f in faces:
        p = v[list(f)]
        n = np.cross(p[1] - p[0], p[2] - p[0])
        m = p.mean(axis=0)
        mitte = np.array([0.0, m[1] if False else 0, m[2]])
        # centre of the cross-section at this z
        nahe = v[np.abs(v[:, 2] - m[2]) < 0.3]
        zentrum = np.array([0.0, nahe[:, 1].mean(), m[2]]) if len(nahe) else np.array([0, m[1], m[2]])
        if np.dot(n, m - zentrum) < 0:
            f = (f[0], f[2], f[1])
        neu.append(f)
    return neu

def dach_teil(glas_verts):
    """roof panel: the upper skin of the greenhouse, slightly bigger so it sits on the glass"""
    def qs(z):
        t = gh_oben(z)
        aus = []
        for x, y, zz in querschnitt_glas(z):
            yy = max(y, t - 0.38)
            breite_alt = gh_breite(z, y)
            xx = x / breite_alt * gh_breite(z, yy) if breite_alt > 1e-6 else 0.0
            aus.append((xx * 1.015, yy + 0.025, zz))
        return aus
    return loft(qs, 0.0, 2.6, n=30)

def schreiben(pfad, teile):
    zeilen = ["# Driving school sedan body - generated for Roblox (import with the 3D Importer)"]
    basis = 1
    for name, (verts, faces) in teile:
        zeilen.append(f"o {name}")
        for x, y, z in verts:
            zeilen.append(f"v {x:.4f} {y:.4f} {z:.4f}")
        for a, b, c in faces:
            zeilen.append(f"f {a + basis} {b + basis} {c + basis}")
        basis += len(verts)
    open(pfad, "w").write("\n".join(zeilen) + "\n")

def doppelseitig(verts, faces):
    return verts, faces + [(a, c, b) for a, b, c in faces]

if __name__ == "__main__":
    unten = loft(querschnitt_unten, -LAENGE, LAENGE)
    unten = (unten[0], ausrichten(*unten))
    glas = loft(querschnitt_glas, G_VON, G_BIS, n=56)
    glas = (glas[0], ausrichten(*glas))
    dach = dach_teil(glas[0])
    dach = (dach[0], ausrichten(*dach))
    teile = [
        ("Karosserie", doppelseitig(*unten)),
        ("Glas", doppelseitig(*glas)),
        ("Dach", dach),
    ]
    schreiben("/home/claude/mesh/fahrschulauto.obj", teile)
    info = {}
    for name, (verts, faces) in teile:
        v = np.array(verts)
        lo, hi = v.min(axis=0), v.max(axis=0)
        info[name] = {"groesse": (hi - lo).round(4).tolist(), "mitte": ((hi + lo) / 2).round(4).tolist(), "dreiecke": len(faces)}
    json.dump(info, open("/home/claude/mesh/info.json", "w"), indent=1)
    print(json.dumps(info, indent=1))


# ---------------- positions for lights and details on the surface ----------------
def innen_unten(x, y, z, n_exp=5.0):
    a = halbbreite(z)
    b, t = boden(z), oben(z)
    if a <= 0 or t <= b:
        return False
    yc, h = (b + t) / 2, (t - b) / 2
    return abs(x / a) ** n_exp + abs((y - yc) / h) ** n_exp <= 1

def front_z(x, y):
    for z in np.arange(-LAENGE, 0, 0.005):
        if innen_unten(x, y, z): return float(z)
    return None

def heck_z(x, y):
    for z in np.arange(LAENGE, 0, -0.005):
        if innen_unten(x, y, z): return float(z)
    return None

def seite_x(y, z):
    for x in np.arange(3.6, 0, -0.005):
        if innen_unten(x, y, z): return float(x)
    return None

def positionen():
    pos = {}
    def vorne(name, x, y, tiefe=0.12):
        z = front_z(x, y); pos[name] = [x, y, round(z - tiefe / 2 + 0.03, 3)]
    def hinten(name, x, y, tiefe=0.12):
        z = heck_z(x, y); pos[name] = [x, y, round(z + tiefe / 2 - 0.03, 3)]
    def seite(name, y, z, breite=0.1):
        x = seite_x(y, z); pos[name] = [round(x + breite / 2 - 0.02, 3), y, z]
    vorne("Scheinwerfer", 2.4, 2.75, 0.3)
    vorne("Tagfahrlicht", 2.4, 2.5, 0.06)
    vorne("BlinkerVorne", 3.05, 2.6, 0.3)
    vorne("Nebelscheinwerfer", 2.6, 1.45, 0.08)
    vorne("Kuehlergrill", 0, 2.0, 0.2)
    vorne("Lufteinlass", 0, 1.35, 0.06)
    vorne("KennzeichenVorne", 0, 1.95, 0.08)
    hinten("Ruecklicht", 2.3, 3.2, 0.3)
    hinten("BlinkerHinten", 3.0, 3.2, 0.1)
    hinten("Reflektor", 2.7, 1.55, 0.05)
    hinten("KennzeichenHinten", 0, 2.45, 0.08)
    hinten("Auspuff", 2.2, 1.3, 0.5)
    seite("Griff1", 3.15, 0.2, 0.1)
    seite("Griff2", 3.15, 3.0, 0.1)
    seite("Spiegelfuss", 3.4, -2.25, 0.4)
    seite("Zierleiste", 3.42, 1.4, 0.06)
    seite("Schulterlinie", 3.1, 1.2, 0.06)
    pos["DrittesBremslicht"] = [0, round(gh_oben(2.45) - 0.1, 3), 2.45]   # top of the rear window
    pos["Heckspoiler"] = [0, round(oben(7.25) + 0.06, 3), 7.25]           # small lip on the trunk
    return pos

if __name__ == "__main__":
    p = positionen()
    info = json.load(open("/home/claude/mesh/info.json"))
    info["positionen"] = p
    json.dump(info, open("/home/claude/mesh/info.json", "w"), indent=1)
    print(json.dumps(p))
