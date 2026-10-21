# Gemeinsamer Bauplan für die Alltagsautos (eigene Designs). Läuft in Blender (Text "auto_pkw", nach "auto_lib")
# und ohne Blender über auto_obj.py. Ein Auto = Profil-Listen + ein paar Zahlen, siehe pkw(a, P).
import math


def _zwischen(liste, y, i):
    for (y0, *w0), (y1, *w1) in zip(liste, liste[1:]):
        if y0 <= y <= y1:
            t = (y - y0) / (y1 - y0) if y1 != y0 else 0
            return w0[i] + t * (w1[i] - w0[i])
    return liste[0][i + 1] if y < liste[0][0] else liste[-1][i + 1]


def pkw(a, P):
    R, SPUR, RB = P["R"], P["spur"], P.get("radbreite", 1.0)
    ACHSEN = P["achsen"]
    BOGEN = R + P.get("bogen", 0.35)
    ZU = P.get("zu", 0.62)
    OBEN = P["oben"]          # (y, halbe Breite, Oberkante) von vorne (-y) nach hinten
    vorne, hinten = OBEN[0][0], OBEN[-1][0]

    def unterkante(y):
        for ym in ACHSEN:
            d = abs(y - ym)
            if d < BOGEN:
                return max(ZU, R + math.sqrt(BOGEN ** 2 - d ** 2))
        return ZU

    ys = {y for y, _, _ in OBEN}
    for ym in ACHSEN:
        ys |= {ym + k * BOGEN / 6 for k in range(-6, 7)}
        ys |= {ym - BOGEN - 0.02, ym + BOGEN + 0.02}
    ys = sorted(y for y in ys if vorne <= y <= hinten)
    a.loft("Lack", [(y, _zwischen(OBEN, y, 0), unterkante(y), _zwischen(OBEN, y, 1)) for y in ys], n_pkt=28, expo=P.get("expo", 4.5))
    for ym in ACHSEN:
        hw = _zwischen(OBEN, ym, 0) - 0.25
        a.loft("Schwarz", [(ym - BOGEN, hw, R - 0.2, R + BOGEN - 0.05), (ym + BOGEN, hw, R - 0.2, R + BOGEN - 0.05)], n_pkt=16, expo=6)
        for sx in (-1, 1):
            a.rad(sx * SPUR, ym, R, RB)

    # Kabine: Lack-Körper, Glasstücke darüber, Dach als Deckel
    GLAS = P["glas"]          # (y, halbe Breite, Oberkante)
    gu = P["glas_unten"]
    def glas_bei(y): return _zwischen(GLAS, y, 0), _zwischen(GLAS, y, 1)
    a.loft("Lack", [(y, hw, gu, zo) for y, hw, zo in GLAS], n_pkt=24, expo=P.get("glas_expo", 5))
    for y0, y1 in P["fenster"]:
        stuecke = [y0] + [y for y, _, _ in GLAS if y0 < y < y1] + [y1]
        a.loft("Glas", [(y, glas_bei(y)[0] + 0.04, gu + 0.08, glas_bei(y)[1] + 0.03) for y in stuecke], n_pkt=24, expo=P.get("glas_expo", 5))
    dach = P["dach"]
    a.loft("Lack", [(y, glas_bei(y)[0] + 0.06, glas_bei(y)[1] - 0.4, glas_bei(y)[1] + 0.06) for y in dach], n_pkt=24, expo=P.get("glas_expo", 5))

    # Seiten: Fensterleiste, Türfugen, Griffe, Spiegel
    for sx in (-1, 1):
        hwg = _zwischen(OBEN, 0, 0)
        gz = gu + 0.15
        a.box("Schwarz", (sx * (hwg - 0.05), (GLAS[0][0] + GLAS[-1][0]) / 2, gz), (0.08, GLAS[-1][0] - GLAS[0][0], 0.12))
        for y in P["fugen"]:
            a.box("Schwarz", (sx * (_zwischen(OBEN, y, 0) + 0.015), y, (unterkante(y) + gu) / 2 + 0.2), (0.03, 0.05, gu - unterkante(y) - 0.4))
        for y in P["griffe"]:
            a.box("Chrom", (sx * (_zwischen(OBEN, y, 0) + 0.03), y, gu - 0.5), (0.06, 0.6, 0.14))
        sy = P["spiegel_y"]
        hs = _zwischen(OBEN, sy, 0)
        a.box("Lack", (sx * (hs + 0.25), sy, gu + 0.35), (0.55, 0.45, 0.38))
        a.box("Glas", (sx * (hs + 0.3), sy + 0.23, gu + 0.35), (0.45, 0.04, 0.3))

    # Front: Scheinwerfer, Blinker, Grill, Stoßfänger, Kennzeichen
    hv = OBEN[0][1]
    zl = P.get("licht_z", OBEN[0][2] - 0.35)
    for sx in (-1, 1):
        a.box("Licht", (sx * (hv - 0.6), vorne + 0.05, zl), (1.15, 0.3, 0.45), (0, 0, -sx * 8))
        a.box("Blinker", (sx * (hv - 0.02), vorne + 0.25, zl), (0.22, 0.3, 0.38), (0, 0, -sx * 30))
        a.box("Ruecklicht", (sx * (OBEN[-1][1] - 0.45), hinten - 0.15, P.get("rueck_z", OBEN[-1][2] - 0.3)), (0.9, 0.3, 0.6), (0, 0, sx * 10))
    a.box("Schwarz", (0, vorne - 0.02, zl - 0.85), (min(2.8, hv * 1.1), 0.2, 0.55))
    for k in range(4):
        a.box("Chrom", (0, vorne - 0.1, zl - 1.05 + k * 0.13), (min(2.6, hv), 0.04, 0.04))
    a.box("Schwarz", (0, vorne + 0.1, ZU + 0.15), (hv * 2 - 0.4, 0.3, 0.32))
    a.box("Schwarz", (0, hinten - 0.1, ZU + 0.18), (OBEN[-1][1] * 2 - 0.4, 0.3, 0.35))
    for y, d in ((vorne - 0.13, -1), (hinten + 0.08, 1)):
        z = zl - 0.45 if d < 0 else P.get("rueck_z", OBEN[-1][2] - 0.3) - 1.0
        a.box("Kennzeichen", (0, y, z), (1.9, 0.05, 0.45))
        a.box("Schwarz", (0, y + d * 0.02, z), (2.0, 0.03, 0.55))
    if P.get("extra"):
        P["extra"](a, P)
