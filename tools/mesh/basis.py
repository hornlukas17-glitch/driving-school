"""Gemeinsame Werkzeuge für die Karosserie-Generatoren (suv.py, sport.py, ...).

Ein Auto besteht aus vier Meshes:
  Karosserie  – Unterteil in Wagenfarbe (Querschnitte entlang z, Superellipsen)
  Verkleidung – schwarzer Kunststoff unten (Schweller, Radläufe, Schürzen)
  Glas        – Fensterbereich
  Dach        – Dachhaut + Säulen in Wagenfarbe
und einer Liste Anbauteile (Lichter, Spiegel, Grill ...), die das Spiel als normale Parts baut.

Koordinaten wie im Spiel: x = rechts, y = hoch (0 = Boden), z = nach hinten (Fahrtrichtung -z).
"""
import math, json, os
import numpy as np

HIER = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HIER))
N_RING = 44


def glatt(t):
    t = min(max(t, 0.0), 1.0)
    return t * t * (3 - 2 * t)


class Form:
    """Alle Formfunktionen eines Autos. Pflicht: halbbreite, boden, oben, gh_oben, gh_breite, gh_unten,
    g_von, g_bis, lh (halbe Länge). Optional: n_unten, n_glas (Eckigkeit der Querschnitte)."""

    def __init__(self, **kw):
        self.n_unten = 7.0
        self.n_glas = 7.0
        self.kotfluegel = 0.3
        self.bogen_innen = 0.45
        self.__dict__.update(kw)

    # ---------- Querschnitte ----------
    def querschnitt_unten(self, z, skala=1.0, y_max=None):
        a = self.halbbreite(z) * skala
        b, t = self.boden(z), self.oben(z)
        yc, h = (b + t) / 2, (t - b) / 2
        pts = []
        for i in range(N_RING):
            w = 2 * math.pi * i / N_RING
            c, s = math.cos(w), math.sin(w)
            x = a * math.copysign(abs(c) ** (2 / self.n_unten), c)
            y = yc + h * math.copysign(abs(s) ** (2 / self.n_unten), s)
            hb = self.bogen(z) if hasattr(self, "bogen") else 0
            if hb > 0:
                # Radhaus nur außen: unten hochziehen, oben ein Kotflügel über dem Rad; die Mitte bleibt flach
                w = glatt((abs(x) / max(a, 1e-6) - self.bogen_innen) / 0.3)
                if s < 0 or y < hb:
                    y += w * max(0.0, hb - y)
                if s >= 0:
                    y += w * max(0.0, hb + self.kotfluegel - y)
            if y_max is not None and y > y_max:
                y = y_max
            pts.append((x, y, z))
        return pts

    def querschnitt_glas(self, z):
        unten = self.gh_unten(z)
        t = self.gh_oben(z)
        pts = []
        for i in range(N_RING):
            w = 2 * math.pi * i / N_RING
            c, s = math.cos(w), math.sin(w)
            yy = math.copysign(abs(s) ** (2 / self.n_glas), s)
            y = (unten + t) / 2 + (t - unten) / 2 * yy
            a = self.gh_breite(z, y)
            x = a * math.copysign(abs(c) ** (2 / self.n_glas), c)
            pts.append((x, y, z))
        return pts

    # ---------- Oberfläche abtasten (für Positionen der Anbauteile) ----------
    def innen_unten(self, x, y, z):
        a = self.halbbreite(z)
        b, t = self.boden(z), self.oben(z)
        if a <= 0 or t <= b:
            return False
        yc, h = (b + t) / 2, (t - b) / 2
        return abs(x / a) ** self.n_unten + abs((y - yc) / h) ** self.n_unten <= 1

    def front_z(self, x, y):
        for z in np.arange(-self.lh, 0, 0.005):
            if self.innen_unten(x, y, z):
                return float(z)
        raise ValueError(f"vorne nichts bei x={x} y={y}")

    def heck_z(self, x, y):
        for z in np.arange(self.lh, 0, -0.005):
            if self.innen_unten(x, y, z):
                return float(z)
        raise ValueError(f"hinten nichts bei x={x} y={y}")

    def seite_x(self, y, z):
        for x in np.arange(5, 0, -0.005):
            if self.innen_unten(x, y, z):
                return float(x)
        raise ValueError(f"seitlich nichts bei y={y} z={z}")

    def oben_y(self, x, z):
        for y in np.arange(8, 0, -0.005):
            if self.innen_unten(x, y, z):
                return float(y)
        raise ValueError(f"oben nichts bei x={x} z={z}")


# ---------------- Mesh-Bau ----------------
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


def sauber(teil):
    verts, faces = teil
    faces = ausrichten(verts, faces)
    v = np.array(verts)
    aus = [f for f in faces if np.linalg.norm(np.cross(v[f[1]] - v[f[0]], v[f[2]] - v[f[0]])) > 1e-7]
    return verts, aus


def zusammen(*teile):
    verts, faces = [], []
    for v, f in teile:
        basis = len(verts)
        verts = verts + list(v)
        faces = faces + [(a + basis, b + basis, c + basis) for a, b, c in f]
    return verts, faces


def doppelseitig(verts, faces):
    return verts, faces + [(a, c, b) for a, b, c in faces]


def dach_teil(form, z0, z1, dicke=0.42, n=36):
    """Dachhaut: oberer Teil der Fensterform, minimal größer, sitzt auf dem Glas"""
    def qs(z):
        t = form.gh_oben(z)
        aus = []
        for x, y, zz in form.querschnitt_glas(z):
            yy = max(y, t - dicke)
            alt = form.gh_breite(z, y)
            xx = x / alt * form.gh_breite(z, yy) if alt > 1e-6 else 0.0
            aus.append((xx * 1.02, yy + 0.03, zz))
        return aus
    return loft(qs, z0, z1, n)


def saeulen_teil(form, bereiche):
    """Säulen in Wagenfarbe: Streifen der Fensterform (nur die Seiten), minimal größer"""
    def qs(z):
        ring = form.querschnitt_glas(z)
        breite = max(abs(p[0]) for p in ring) or 1
        return [(x * 1.014, y if abs(x) > 0.72 * breite else y - 0.35, zz) for x, y, zz in ring]
    return zusammen(*[loft(qs, z0, z1, n) for z0, z1, n in bereiche])


def verkleidung_teil(form, kante, skala=1.022, n=120):
    def qs(z):
        return form.querschnitt_unten(z, skala=skala, y_max=kante(z))
    return loft(qs, -form.lh * 1.004, form.lh * 1.004, n)


def schreiben(pfad, titel, teile):
    # eigene Gruppe + eigenes Material je Teil, damit der Roblox-Importer getrennte MeshParts anlegt
    mtl = os.path.splitext(os.path.basename(pfad))[0] + ".mtl"
    zeilen = [f"# {titel} - own design, generated for Roblox (import with the 3D Importer)", f"mtllib {mtl}"]
    farben = {"Karosserie": "0.8 0.1 0.1", "Dach": "0.8 0.1 0.1", "Verkleidung": "0.1 0.1 0.1", "Glas": "0.2 0.25 0.3"}
    mtl_zeilen = []
    for name, _ in teile:
        mtl_zeilen += [f"newmtl {name}", f"Kd {farben.get(name, '0.5 0.5 0.5')}", "d 1.0", ""]
    os.makedirs(os.path.dirname(pfad), exist_ok=True)
    open(os.path.join(os.path.dirname(pfad), mtl), "w").write("\n".join(mtl_zeilen))
    basis = 1
    for name, (verts, faces) in teile:
        zeilen.append(f"o {name}")
        zeilen.append(f"g {name}")
        zeilen.append(f"usemtl {name}")
        for x, y, z in verts:
            zeilen.append(f"v {x:.4f} {y:.4f} {z:.4f}")
        for a, b, c in faces:
            zeilen.append(f"f {a + basis} {b + basis} {c + basis}")
        basis += len(verts)
    os.makedirs(os.path.dirname(pfad), exist_ok=True)
    open(pfad, "w").write("\n".join(zeilen) + "\n")


# ---------------- Anbauteile ----------------
# art: lack (Wagenfarbe), chrom, alu, schwarz, carbon, grill, scheinwerfer (mit Licht), neon_weiss, neon_rot, blinker
def teil(name, art, groesse, pos, spiegeln=False, dreh=None):
    t = {"n": name, "a": art, "g": [round(v, 3) for v in groesse], "p": [round(v, 3) for v in pos], "s": spiegeln}
    if dreh:
        t["r"] = [round(v, 2) for v in dreh]
    return t


def erzeugen(typ, vorlage, titel, rad, meshes, anbau, kollision, kennzeichen, spoiler, sitz_y=None, armaturen_z=None):
    """meshes: {"Karosserie": (verts, faces), ...}; rad = (R, spur, achse)"""
    for name, m in meshes.items():
        assert len(m[1]) <= 20000, f"{name} hat {len(m[1])} Dreiecke (Roblox-Limit 20000)"
    schreiben(os.path.join(ROOT, "dist", "mesh", vorlage + ".obj"), titel, list(meshes.items()))
    info = {"typ": typ, "vorlage": vorlage, "rad": list(rad), "mesh": {}, "anbau": anbau,
            "kollision": kollision, "kennzeichen": kennzeichen, "spoiler": spoiler}
    if sitz_y is not None:
        info["sitzY"] = sitz_y
    if armaturen_z is not None:
        info["armaturenZ"] = armaturen_z
    for name, (verts, faces) in meshes.items():
        v = np.array(verts)
        lo, hi = v.min(axis=0), v.max(axis=0)
        info["mesh"][name] = {"groesse": (hi - lo).round(4).tolist(), "mitte": ((hi + lo) / 2).round(4).tolist(), "dreiecke": len(faces)}
    json.dump(info, open(os.path.join(HIER, typ + "_info.json"), "w"), indent=1)
    exportieren()
    print(typ, {k: v["dreiecke"] for k, v in info["mesh"].items()}, len(anbau), "Anbauteile")
    return info


def lua_wert(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(round(float(v), 4)).rstrip("0").rstrip(".") if isinstance(v, float) else str(v)
    if isinstance(v, str):
        return '"' + v + '"'
    if isinstance(v, list):
        return "{ " + ", ".join(lua_wert(x) for x in v) + " }"
    if isinstance(v, dict):
        return "{ " + ", ".join(f"{k} = {lua_wert(x)}" for k, x in v.items()) + " }"
    raise TypeError(v)


def exportieren():
    """alle *_info.json -> src/Karosserien.lua (wird vom Spiel gelesen)"""
    zeilen = ["-- GENERATED by tools/mesh/*.py - do not edit by hand.",
              "-- Round bodies for the private cars. Import dist/mesh/<vorlage>.obj with the 3D Importer",
              "-- and put the model (named like <vorlage>) into ServerStorage; then the car uses it.",
              "return {"]
    for datei in sorted(os.listdir(HIER)):
        if not datei.endswith("_info.json"):
            continue
        d = json.load(open(os.path.join(HIER, datei)))
        if "typ" not in d:
            continue
        zeilen.append(f"\t{d['typ']} = {{")
        zeilen.append(f"\t\tvorlage = {lua_wert(d['vorlage'])},")
        for feld in ("sitzY", "armaturenZ"):
            if feld in d:
                zeilen.append(f"\t\t{feld} = {lua_wert(d[feld])},")
        zeilen.append("\t\tmesh = {")
        for name, m in d["mesh"].items():
            zeilen.append(f"\t\t\t{name} = {{ groesse = {lua_wert(m['groesse'])}, mitte = {lua_wert(m['mitte'])} }},")
        zeilen.append("\t\t},")
        zeilen.append("\t\tanbau = {")
        for t in d["anbau"]:
            zeilen.append(f"\t\t\t{lua_wert(t)},")
        zeilen.append("\t\t},")
        zeilen.append("\t\tkollision = {")
        for k in d["kollision"]:
            zeilen.append(f"\t\t\t{lua_wert(k)},")
        zeilen.append("\t\t},")
        zeilen.append(f"\t\tkennzeichen = {lua_wert(d['kennzeichen'])},")
        zeilen.append(f"\t\tspoiler = {lua_wert(d['spoiler'])},")
        zeilen.append("\t},")
    zeilen.append("}")
    open(os.path.join(ROOT, "src", "Karosserien.lua"), "w").write("\n".join(zeilen) + "\n")
