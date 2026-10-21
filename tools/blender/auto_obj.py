"""
Die Auto-Bausteine aus auto_lib.py ohne Blender: dieselbe API (Auto.loft/box/zyl/rad/bauen), aber das Ergebnis
wird direkt als OBJ geschrieben (eine Gruppe je Material, wie bei den Häusern) und mit einem kleinen
Software-Renderer als PNG-Vorschau gezeichnet.

  python3 tools/blender/auto_obj.py auto_kleinwagen.py [auto_limousine.py ...]
      -> dist/mesh/autos/<Name>.obj + <Name>_vorschau.png + <Name>.json (Maße, Dreiecke)

Die Auto-Skripte laufen unverändert auch in Blender (dort mit auto_lib.py).
Achsen: Blender-Konvention (x quer, y längs mit Front = -Y, z oben). Für Roblox gilt (x, z, -y): Front = +Z,
wie bei den Häusern (nach_obj.py); NPC-Autos drehen beim Einbau um 180°, weil Verkehr.modell Front = -Z nutzt.
"""
import math, os, sys, json
import numpy as np

HIER = os.path.dirname(os.path.abspath(__file__))
WURZEL = os.path.dirname(os.path.dirname(HIER))
AUS = os.path.join(WURZEL, "dist", "mesh", "autos")

FARBEN = {
    "Lack": (0.55, 0.06, 0.07), "Glas": (0.04, 0.06, 0.08), "Schwarz": (0.03, 0.03, 0.035),
    "Reifen": (0.02, 0.02, 0.022), "Felge": (0.62, 0.63, 0.66), "Licht": (0.95, 0.95, 0.9),
    "Ruecklicht": (0.6, 0.03, 0.03), "Blinker": (0.9, 0.45, 0.05), "Chrom": (0.8, 0.8, 0.82),
    "Kennzeichen": (0.92, 0.92, 0.9), "Innen": (0.08, 0.08, 0.09), "Akzent": (0.85, 0.85, 0.85),
}
GLANZ = {"Lack": 0.6, "Glas": 0.9, "Chrom": 0.9, "Felge": 0.7, "Licht": 0.5, "Ruecklicht": 0.5}


# ---------- kleine Ersatzklassen für mathutils (nur was die Auto-Skripte brauchen) ----------
def _rot_xyz(e):
    ax, ay, az = e
    rx = np.array([[1, 0, 0], [0, math.cos(ax), -math.sin(ax)], [0, math.sin(ax), math.cos(ax)]])
    ry = np.array([[math.cos(ay), 0, math.sin(ay)], [0, 1, 0], [-math.sin(ay), 0, math.cos(ay)]])
    rz = np.array([[math.cos(az), -math.sin(az), 0], [math.sin(az), math.cos(az), 0], [0, 0, 1]])
    return rz @ ry @ rx


class _Euler(tuple):
    pass


class _Quat:
    def __init__(self, m): self.m = m

    def to_euler(self):
        m = self.m
        ay = math.asin(max(-1.0, min(1.0, -m[2, 0])))
        if abs(m[2, 0]) < 0.9999:
            ax = math.atan2(m[2, 1], m[2, 2]); az = math.atan2(m[1, 0], m[0, 0])
        else:
            ax = math.atan2(-m[1, 2], m[1, 1]); az = 0.0
        return _Euler((ax, ay, az))


class Vector(tuple):
    def __new__(cls, v): return tuple.__new__(cls, [float(a) for a in v])
    def __add__(self, o): return Vector(np.add(self, o))
    def __sub__(self, o): return Vector(np.subtract(self, o))
    def __truediv__(self, k): return Vector(np.divide(self, k))
    def __mul__(self, k): return Vector(np.multiply(self, k))
    @property
    def length(self): return float(np.linalg.norm(self))

    def to_track_quat(self, track="Y", up="Z"):
        y = np.array(self) / np.linalg.norm(self)
        z = np.array([0.0, 0.0, 1.0]) - y * y[2]
        if np.linalg.norm(z) < 1e-6: z = np.array([1.0, 0, 0])
        z /= np.linalg.norm(z)
        x = np.cross(y, z)
        return _Quat(np.column_stack([x, y, z]))


def superellipse(n_pkt, hw, zu, zo, expo):
    zc, hh = (zu + zo) / 2, (zo - zu) / 2
    pts = []
    for i in range(n_pkt):
        t = 2 * math.pi * i / n_pkt
        c, s = math.cos(t), math.sin(t)
        pts.append((hw * math.copysign(abs(c) ** (2 / expo), c), zc + hh * math.copysign(abs(s) ** (2 / expo), s)))
    return pts


class Auto:
    """wie auto_lib.Auto, aber ohne Blender. detail < 1 spart Dreiecke (Ringpunkte, Radsegmente)."""
    detail = 1.0

    def __init__(self, name, versatz=(0, 0, 0)):
        self.name = name
        self.g = {}  # gruppe -> (verts list, faces list)

    def _grp(self, g):
        if g not in self.g: self.g[g] = ([], [])
        return self.g[g]

    def _n(self, n, mindest=6):
        return max(mindest, int(round(n * Auto.detail / 2)) * 2)

    def loft(self, g, schnitte, n_pkt=20, expo=4.0, glatt=True, kappen=True):
        V, F = self._grp(g)
        n = self._n(n_pkt, 8)
        ringe = []
        for s in schnitte:
            y, hw, zu, zo = s[:4]
            e = s[4] if len(s) > 4 else expo
            ring = []
            for x, z in superellipse(n, hw, zu, zo, e):
                V.append((x, y, z)); ring.append(len(V) - 1)
            ringe.append(ring)
        for a, b in zip(ringe, ringe[1:]):
            for i in range(n):
                j = (i + 1) % n
                F.append((a[i], a[j], b[j], b[i]))
        if kappen:
            F.append(tuple(ringe[0][::-1]))
            F.append(tuple(ringe[-1]))

    def box(self, g, mitte, gr, dreh=(0, 0, 0), glatt=False):
        V, F = self._grp(g)
        R = _rot_xyz([math.radians(a) for a in dreh])
        o = len(V)
        for a in (-0.5, 0.5):
            for b in (-0.5, 0.5):
                for c in (-0.5, 0.5):
                    p = R @ np.array([a * gr[0], b * gr[1], c * gr[2]]) + np.array(mitte, float)
                    V.append(tuple(p))
        idx = lambda a, b, c: o + a * 4 + b * 2 + c
        for f in [(0, 0, 0, 0, 1, 0, 0, 1, 1, 0, 0, 1), ]:
            pass
        F += [(idx(0, 0, 0), idx(0, 0, 1), idx(0, 1, 1), idx(0, 1, 0)), (idx(1, 0, 0), idx(1, 1, 0), idx(1, 1, 1), idx(1, 0, 1)),
              (idx(0, 0, 0), idx(1, 0, 0), idx(1, 0, 1), idx(0, 0, 1)), (idx(0, 1, 0), idx(0, 1, 1), idx(1, 1, 1), idx(1, 1, 0)),
              (idx(0, 0, 0), idx(0, 1, 0), idx(1, 1, 0), idx(1, 0, 0)), (idx(0, 0, 1), idx(1, 0, 1), idx(1, 1, 1), idx(0, 1, 1))]

    def zyl(self, g, mitte, r, breite, n=20, achse="x", glatt=True):
        V, F = self._grp(g)
        n = self._n(n, 8)
        o = len(V)
        for seite in (-0.5, 0.5):
            for i in range(n):
                t = 2 * math.pi * i / n
                u, v = r * math.cos(t), r * math.sin(t)
                if achse == "x": p = (seite * breite, u, v)
                elif achse == "y": p = (u, seite * breite, v)
                else: p = (u, v, seite * breite)
                V.append(tuple(np.add(p, mitte)))
        for i in range(n):
            j = (i + 1) % n
            F.append((o + i, o + j, o + n + j, o + n + i))
        F.append(tuple(o + i for i in range(n))[::-1])
        F.append(tuple(o + n + i for i in range(n)))

    def rad(self, x, y, r, breite, speichen=5):
        s = 1 if x > 0 else -1
        self.zyl("Reifen", (x, y, r), r, breite, n=24)
        self.zyl("Felge", (x + s * (breite * 0.5 + 0.02), y, r), r * 0.62, 0.06, n=20)
        if Auto.detail >= 0.75:
            self.zyl("Schwarz", (x + s * (breite * 0.5 + 0.04), y, r), r * 0.5, 0.04, n=20)
            for k in range(speichen):
                self.box("Felge", (x + s * (breite * 0.5 + 0.06), y, r), (0.05, r * 0.95, 0.2), (360 * k / speichen, 0, 0))
        self.zyl("Chrom", (x + s * (breite * 0.5 + 0.08), y, r), r * 0.14, 0.05, n=12)

    def radkasten(self, x_seite, y, r):
        self.zyl("Schwarz", (x_seite, y, r), r + 0.3, 0.06, n=24, glatt=False)

    # ---------- Ausgabe ----------
    def dreiecke(self):
        return sum(sum(len(f) - 2 for f in F) for V, F in self.g.values())

    def bauen(self):
        return {"objekte": len(self.g), "dreiecke": self.dreiecke()}

    def obj_schreiben(self, pfad):
        """Roblox-Achsen (x, z, -y): Front +Z; Boden y = 0; plus Anker-Würfel im Ursprung (für die Ausrichtung)."""
        zeilen = ["# " + self.name + " (tools/blender/auto_obj.py)"]
        basis = 1
        for g, (V, F) in list(self.g.items()) + [("Anker", ([(-.05, -.05, -.05), (.05, -.05, -.05), (.05, .05, -.05), (-.05, .05, -.05),
                                                             (-.05, -.05, .05), (.05, -.05, .05), (.05, .05, .05), (-.05, .05, .05)],
                                                            [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]))]:
            zeilen.append(f"o {g}")
            zeilen.append(f"g {g}")
            for x, y, z in V:
                zeilen.append(f"v {x:.4f} {z:.4f} {-y:.4f}")
            for f in F:
                zeilen.append("f " + " ".join(str(basis + i) for i in f))
            basis += len(V)
        open(pfad, "w").write("\n".join(zeilen) + "\n")

    def rendern(self, pfad, lack=(0.55, 0.06, 0.07), groesse=(900, 560), azim=-35, elev=16):
        from PIL import Image
        W, H = groesse
        tris, farben = [], []
        for g, (V, F) in self.g.items():
            V = np.array(V)
            c = np.array(lack if g == "Lack" else FARBEN.get(g, (0.5, 0.5, 0.5)))
            for f in F:
                for k in range(1, len(f) - 1):
                    tris.append(V[[f[0], f[k], f[k + 1]]]); farben.append((c, GLANZ.get(g, 0.2)))
        T = np.array(tris)
        a, e = math.radians(azim), math.radians(elev)
        # Kamera: Blick zur Mitte, Front (-Y) schräg vorne links
        R = np.array([[math.cos(a), -math.sin(a), 0], [math.sin(a), math.cos(a), 0], [0, 0, 1]])
        Re = np.array([[1, 0, 0], [0, math.cos(e), -math.sin(e)], [0, math.sin(e), math.cos(e)]])
        P = T @ (Re @ R).T  # x rechts, y Tiefe, z oben
        mitte = (P.reshape(-1, 3).max(0) + P.reshape(-1, 3).min(0)) / 2
        P = P - mitte
        span = max(np.ptp(P[..., 0]), np.ptp(P[..., 2]) * W / H) * 1.12
        sx = (P[..., 0] / span + 0.5) * W
        sy = (0.5 - P[..., 2] / span * W / H) * H
        tiefe = P[..., 1]
        bild = np.ones((H, W, 3)) * np.array([0.93, 0.94, 0.96])
        zbuf = np.full((H, W), np.inf)
        licht = np.array([-0.4, -0.5, 0.75]); licht /= np.linalg.norm(licht)
        normalen = np.cross(T[:, 1] - T[:, 0], T[:, 2] - T[:, 0])
        nl = np.linalg.norm(normalen, axis=1); nl[nl == 0] = 1
        normalen /= nl[:, None]
        blick = (Re @ R).T @ np.array([0, -1, 0])  # Blickrichtung in Weltkoordinaten (zur Kamera hin)
        for i in range(len(T)):
            n = normalen[i]
            if n @ blick < 0: n = -n
            hell = 0.35 + 0.65 * max(0.0, n @ licht)
            c, gl = farben[i]
            farbe = np.clip(c * hell + gl * 0.25 * max(0.0, n @ licht) ** 8, 0, 1)
            xs, ys, zs = sx[i], sy[i], tiefe[i]
            x0, x1 = int(max(0, xs.min())), int(min(W - 1, xs.max() + 1))
            y0, y1 = int(max(0, ys.min())), int(min(H - 1, ys.max() + 1))
            if x1 <= x0 or y1 <= y0: continue
            gx, gy = np.meshgrid(np.arange(x0, x1) + 0.5, np.arange(y0, y1) + 0.5)
            d = (ys[1] - ys[2]) * (xs[0] - xs[2]) + (xs[2] - xs[1]) * (ys[0] - ys[2])
            if abs(d) < 1e-9: continue
            l0 = ((ys[1] - ys[2]) * (gx - xs[2]) + (xs[2] - xs[1]) * (gy - ys[2])) / d
            l1 = ((ys[2] - ys[0]) * (gx - xs[2]) + (xs[0] - xs[2]) * (gy - ys[2])) / d
            l2 = 1 - l0 - l1
            drin = (l0 >= -1e-6) & (l1 >= -1e-6) & (l2 >= -1e-6)
            z = l0 * zs[0] + l1 * zs[1] + l2 * zs[2]
            sub = zbuf[y0:y1, x0:x1]
            neu = drin & (z < sub)
            sub[neu] = z[neu]
            bild[y0:y1, x0:x1][neu] = farbe
        Image.fromarray((bild * 255).astype(np.uint8)).save(pfad)


def laden(skript, detail=1.0):
    Auto.detail = detail
    src = open(os.path.join(HIER, skript)).read()
    src = src.replace('exec(bpy.data.texts["auto_lib"].as_string())', "")
    src = src.replace('exec(bpy.data.texts["auto_pkw"].as_string())', open(os.path.join(HIER, "auto_pkw.py")).read().replace("import math", ""))
    src = src.replace("import bpy, math", "import math").replace("from mathutils import Vector", "")
    ns = {"Auto": Auto, "Vector": Vector, "math": math, "superellipse": superellipse}
    exec(compile(src, skript, "exec"), ns)
    return ns["a"]


if __name__ == "__main__":
    os.makedirs(AUS, exist_ok=True)
    for skript in sys.argv[1:]:
        # Vorschau in voller Detailstufe, OBJ fürs Spiel in halber (NPC-Verkehr + ~200 Parkautos, Handys!)
        a = laden(skript, 1.0)
        name = a.name.replace("Auto_", "")
        a.rendern(os.path.join(AUS, name + "_vorschau.png"))
        a = laden(skript, 0.5)
        a.obj_schreiben(os.path.join(AUS, name + ".obj"))
        print(name, a.dreiecke(), "Dreiecke im OBJ")
