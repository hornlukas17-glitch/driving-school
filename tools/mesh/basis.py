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
        self.profil = None          # Breitenfaktor je Höhe (0 = unten, 1 = oben): Einzug unten, Schulter, runde Oberkante
        self.__dict__.update(kw)

    def faktor(self, y, b, t):
        if not self.profil or t <= b:
            return 1.0
        return self.profil(min(max((y - b) / (t - b), 0.0), 1.0))

    # ---------- Querschnitte ----------
    def querschnitt_unten(self, z, skala=1.0, y_max=None):
        a = self.halbbreite(z) * skala
        b, t = self.boden(z), self.oben(z)
        yc, h = (b + t) / 2, (t - b) / 2
        pts = []
        for i in range(N_RING):
            w = 2 * math.pi * i / N_RING
            c, s = math.cos(w), math.sin(w)
            y = yc + h * math.copysign(abs(s) ** (2 / self.n_unten), s)
            x = a * self.faktor(y, b, t) * math.copysign(abs(c) ** (2 / self.n_unten), c)
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
        if abs(y - yc) > h:
            return False
        return abs(x / (a * self.faktor(y, b, t))) ** self.n_unten + abs((y - yc) / h) ** self.n_unten <= 1

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


def profil(einzug=0.1, schulter=0.62, oben=0.08):
    """typischer Auto-Querschnitt: unten eingezogen, an der Schulter am breitesten, oben schmaler"""
    def f(yn):
        if yn < schulter:
            return 1 - einzug * ((schulter - yn) / schulter) ** 2
        return 1 - oben * ((yn - schulter) / (1 - schulter)) ** 1.6
    return f


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
        # an den Enden flach auslaufen lassen, sonst sieht man die Stirnkante als Zacke im Seitenfenster
        f = glatt((z - z0) / 0.7) * glatt((z1 - z) / 0.7)
        d = 0.06 + (dicke - 0.06) * f
        aus = []
        for x, y, zz in form.querschnitt_glas(z):
            yy = max(y, t - d)
            alt = form.gh_breite(z, y)
            xx = x / alt * form.gh_breite(z, yy) if alt > 1e-6 else 0.0
            aus.append((xx * (1 + 0.02 * f), yy + 0.005 + 0.025 * f, zz))
        return aus
    return loft(qs, z0, z1, n)


def saeulen_teil(form, bereiche):
    """Säulen in Wagenfarbe: Streifen der Fensterform (nur die Seiten), minimal größer"""
    def qs(z):
        ring = form.querschnitt_glas(z)
        breite = max(abs(p[0]) for p in ring) or 1
        unten = form.gh_unten(z) - 0.1
        # nur die Seitenstreifen; die Mitte verschwindet ganz unter dem Glas im Unterteil
        # (sonst sieht man sie in Roblox durch das durchsichtige Glas als Deckel)
        return [(x * 1.014, y if abs(x) > 0.72 * breite else unten, zz) for x, y, zz in ring]
    return zusammen(*[loft(qs, z0, z1, n) for z0, z1, n in bereiche])


def verkleidung_teil(form, kante, skala=1.022, n=120):
    def qs(z):
        return form.querschnitt_unten(z, skala=skala, y_max=kante(z))
    return loft(qs, -form.lh * 1.004, form.lh * 1.004, n)


def flaeche(form, seite, ecken, n_u=12, n_v=4, abstand=0.03, tiefe=0.06):
    """dünne Fläche, die der Karosserie folgt (Scheinwerfer, Grill, Rückleuchte, Lüftung ...).
    seite: 'vorne'/'hinten' (Ecken als (x, y)), 'oben' (x, z), 'seite' (z, y); Ecken im Uhrzeigersinn egal.
    Liefert ein geschlossenes, flaches Teil (rechte Seite, x > 0)."""
    (a0, a1), (b0, b1), (c0, c1), (d0, d1) = ecken
    raus = {"vorne": (0, 0, -1), "hinten": (0, 0, 1), "oben": (0, 1, 0), "seite": (1, 0, 0)}[seite]

    def punkt(u, v, versatz):
        p = (1 - u) * (1 - v) * a0 + u * (1 - v) * b0 + u * v * c0 + (1 - u) * v * d0
        q = (1 - u) * (1 - v) * a1 + u * (1 - v) * b1 + u * v * c1 + (1 - u) * v * d1
        for _ in range(60):                      # Punkt neben der Karosserie: ein Stück nach innen rücken
            try:
                return senkrecht(p, q, versatz)
            except ValueError:
                if seite in ("vorne", "hinten", "oben"):
                    p -= math.copysign(0.03, p)
                else:
                    q -= 0.03
        return senkrecht(p, q, versatz)

    def senkrecht(p, q, versatz):
        """Punkt auf der Oberfläche, senkrecht zur Oberfläche verschoben (auch an schrägen Stellen sichtbar)"""
        s0 = np.array(roh(p, q, 0.0))
        e = 0.04
        try:
            su = np.array(roh(p + e, q, 0.0)) - np.array(roh(p - e, q, 0.0))
            sv = np.array(roh(p, q + e, 0.0)) - np.array(roh(p, q - e, 0.0))
            n = np.cross(su, sv)
            n /= np.linalg.norm(n) + 1e-12
            if np.dot(n, raus) < 0:
                n = -n
        except ValueError:
            n = np.array(raus, float)
        return tuple(s0 + n * versatz)

    def roh(p, q, versatz):
        if seite == "vorne":
            return (p, q, form.front_z(p, q) - versatz)
        if seite == "hinten":
            return (p, q, form.heck_z(p, q) + versatz)
        if seite == "oben":
            return (p, form.oben_y(p, q) + versatz, q)
        return (form.seite_x(q, p) + versatz, q, p)

    verts, faces = [], []
    for versatz in (abstand, -tiefe):
        for j in range(n_v + 1):
            for i in range(n_u + 1):
                verts.append(punkt(i / n_u, j / n_v, versatz))
    k = (n_u + 1) * (n_v + 1)
    idx = lambda i, j, lage=0: lage * k + j * (n_u + 1) + i
    for lage in (0, 1):
        for j in range(n_v):
            for i in range(n_u):
                faces += [(idx(i, j, lage), idx(i + 1, j, lage), idx(i + 1, j + 1, lage)),
                          (idx(i, j, lage), idx(i + 1, j + 1, lage), idx(i, j + 1, lage))]
    rand = [(i, 0) for i in range(n_u)] + [(n_u, j) for j in range(n_v)] + [(i, n_v) for i in range(n_u, 0, -1)] + [(0, j) for j in range(n_v, 0, -1)]
    for (i, j), (i2, j2) in zip(rand, rand[1:] + rand[:1]):
        faces += [(idx(i, j), idx(i2, j2), idx(i2, j2, 1)), (idx(i, j), idx(i2, j2, 1), idx(i, j, 1))]
    # außen nach außen drehen: außen = Richtung 'raus', innen umgekehrt, Rand weg von der Mitte
    v = np.array(verts)
    mitte = v.mean(axis=0)
    r = np.array(raus, float)
    neu = []
    for f in faces:
        pa, pb, pc = v[list(f)]
        n = np.cross(pb - pa, pc - pa)
        if np.linalg.norm(n) < 1e-9:
            continue
        m = (pa + pb + pc) / 3
        if all(x >= k for x in f):
            soll = -r
        elif all(x < k for x in f):
            soll = r
        else:
            soll = (m - mitte) - r * np.dot(m - mitte, r)
        neu.append(f if np.dot(n, soll) >= 0 else (f[0], f[2], f[1]))
    return verts, neu


def flaechen_paar(m, form, name, teilname, art, seite, ecken, **kw):
    """Fläche rechts + gespiegelt links. '#' im Teilnamen wird zu R/L (z. B. Blinker#)."""
    rechts = flaeche(form, seite, ecken, **kw)
    m[name + "R"] = (*rechts, {"n": teilname.replace("#", "R"), "a": art})
    m[name + "L"] = (*spiegel(rechts), {"n": teilname.replace("#", "L"), "a": art})


def flaeche_mitte(m, form, name, teilname, art, seite, ecken, **kw):
    m[name] = (*flaeche(form, seite, ecken, **kw), {"n": teilname, "a": art})


def spiegel(teil):
    verts, faces = teil
    return [(-x, y, z) for x, y, z in verts], [(a, c, b) for a, b, c in faces]


def schreiben(pfad, titel, teile, normalen=None):
    normalen = normalen or {}
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
    nbasis = 1
    for name, (verts, faces) in teile:
        zeilen.append(f"o {name}")
        zeilen.append(f"g {name}")
        zeilen.append(f"usemtl {name}")
        for x, y, z in verts:
            zeilen.append(f"v {x:.4f} {y:.4f} {z:.4f}")
        if name in normalen:                    # glatte Schattierung (gemeinsame Normalen an Teilgrenzen)
            for x, y, z in normalen[name]:
                zeilen.append(f"vn {x:.4f} {y:.4f} {z:.4f}")
            for a, b, c in faces:
                zeilen.append(f"f {a + basis}//{a + nbasis} {b + basis}//{b + nbasis} {c + basis}//{c + nbasis}")
            nbasis += len(verts)
        else:
            for a, b, c in faces:
                zeilen.append(f"f {a + basis} {b + basis} {c + basis}")
        basis += len(verts)
    os.makedirs(os.path.dirname(pfad), exist_ok=True)
    open(pfad, "w").write("\n".join(zeilen) + "\n")


# ---------------- Anbauteile ----------------
# art: lack (Wagenfarbe), chrom, alu, schwarz, carbon, grill, scheinwerfer (mit Licht), neon_weiss, neon_rot, blinker
def teil(name, art, groesse, pos, spiegeln=False, dreh=None, zylinder=False):
    """zylinder=True: runde Form, Achse entlang z (Endrohre); groesse = (Länge, Durchmesser, Durchmesser)"""
    t = {"n": name, "a": art, "g": [round(v, 3) for v in groesse], "p": [round(v, 3) for v in pos], "s": spiegeln}
    if dreh:
        t["r"] = [round(v, 2) for v in dreh]
    if zylinder:
        t["f"] = "zyl"
    return t


def linie(name, punkte, art="fuge", dicke=0.035, spiegeln=False):
    """schmale Linie entlang mehrerer Punkte (z. B. Tür- und Haubenfugen): ein Teil je Abschnitt.
    'd' ist die Richtung des Abschnitts; das Spiel dreht das Teil mit CFrame.lookAt danach aus."""
    teile = []
    for a, b in zip(punkte, punkte[1:]):
        d = [b[i] - a[i] for i in range(3)]
        laenge = math.sqrt(sum(v * v for v in d))
        if laenge < 1e-6:
            continue
        mitte = [(a[i] + b[i]) / 2 for i in range(3)]
        t = teil(name, art, (dicke, dicke, laenge + dicke), mitte, spiegeln)
        t["d"] = [round(v / laenge, 4) for v in d]
        teile.append(t)
    return teile


def erzeugen(typ, vorlage, titel, rad, meshes, anbau, kollision, kennzeichen, spoiler, sitz_y=None, armaturen_z=None, drehung=None, sitz_x=None, normalen=None, nacht=None):
    """meshes: {"Karosserie": (verts, faces), ...}; rad = (R, spur, achse)"""
    for name, m in meshes.items():
        assert len(m[1]) <= 20000, f"{name} hat {len(m[1])} Dreiecke (Roblox-Limit 20000)"
    schreiben(os.path.join(ROOT, "dist", "mesh", vorlage + ".obj"), titel, [(k, (m[0], m[1])) for k, m in meshes.items()], normalen)
    info = {"typ": typ, "vorlage": vorlage, "rad": list(rad), "mesh": {}, "anbau": anbau,
            "kollision": kollision, "kennzeichen": kennzeichen, "spoiler": spoiler}
    if sitz_y is not None:
        info["sitzY"] = sitz_y
    if armaturen_z is not None:
        info["armaturenZ"] = armaturen_z
    if sitz_x is not None:                      # Sitzabstand zur Mitte (Standard 1.5)
        info["sitzX"] = sitz_x
    if drehung is not None:                     # Grad um die Hochachse, falls der Importer das Modell verkehrt herum einliest
        info["drehung"] = drehung
    if nacht:                                   # Zusatzteile nur für die Sonderedition (Auto.MODELLE[...].nachtDetails)
        info["nacht"] = nacht
    for name, m in meshes.items():
        verts, faces = m[0], m[1]
        v = np.array(verts)
        lo, hi = v.min(axis=0), v.max(axis=0)
        info["mesh"][name] = {"groesse": (hi - lo).round(4).tolist(), "mitte": ((hi + lo) / 2).round(4).tolist(), "dreiecke": len(faces)}
        if len(m) > 2:
            info["mesh"][name].update(m[2])     # {"n": Teilname im Spiel, "a": Art/Farbe}
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
        for feld in ("sitzY", "sitzX", "armaturenZ", "drehung"):
            if feld in d:
                zeilen.append(f"\t\t{feld} = {lua_wert(d[feld])},")
        zeilen.append("\t\tmesh = {")
        for name, m in d["mesh"].items():
            extra = "".join(f", {k} = {lua_wert(m[k])}" for k in ("n", "a") if k in m)
            zeilen.append(f"\t\t\t{name} = {{ groesse = {lua_wert(m['groesse'])}, mitte = {lua_wert(m['mitte'])}{extra} }},")
        zeilen.append("\t\t},")
        zeilen.append("\t\tanbau = {")
        for t in d["anbau"]:
            zeilen.append(f"\t\t\t{lua_wert(t)},")
        zeilen.append("\t\t},")
        if d.get("nacht"):
            zeilen.append("\t\tnacht = {")
            for t in d["nacht"]:
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
