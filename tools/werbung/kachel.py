"""
Setzt mehrere Studio-Screenshots (gleiche Kameraposition, kleines Sichtfeld, verschiedene Blickrichtungen) zu einem
großen, scharfen Bild zusammen (Studio-Viewport ist nur ~1076x440, Roblox-Bilder sollen 1920x1080 haben).

  python3 tools/werbung/kachel.py <beschreibung.json> <ausgabe.png>

beschreibung.json: { "pos": [x,y,z], "blick": [x,y,z], "fov": 40, "breite": 1920, "hoehe": 1080,
                     "kachel_fov": 16, "kacheln": [ { "blick": [x,y,z], "bild": "pfad.jpg" }, ... ] }
Projektion wie in Roblox: FieldOfView = vertikales Sichtfeld, Kamera per CFrame.lookAt (Welt-Oben = +Y).
"""
import json, sys, os
import numpy as np
from PIL import Image


def basis(pos, blick):
    f = np.array(blick, float) - np.array(pos, float)
    f /= np.linalg.norm(f)
    r = np.cross(f, [0, 1, 0]); r /= np.linalg.norm(r)
    u = np.cross(r, f)
    return r, u, f


def zusammensetzen(b, wurzel="."):
    pos = np.array(b["pos"], float)
    W, H = b.get("breite", 1920), b.get("hoehe", 1080)
    r, u, f = basis(pos, b["blick"])
    th = np.tan(np.radians(b["fov"]) / 2)
    xs = (2 * (np.arange(W) + 0.5) / W - 1) * th * W / H
    ys = (1 - 2 * (np.arange(H) + 0.5) / H) * th
    X, Y = np.meshgrid(xs, ys)
    d = X[..., None] * r + Y[..., None] * u + f  # Strahlen in Weltkoordinaten
    summe = np.zeros((H, W, 3)); gewicht = np.zeros((H, W))
    for k in b["kacheln"]:
        img = np.asarray(Image.open(os.path.join(wurzel, k["bild"])).convert("RGB"), float)
        h, w = img.shape[:2]
        kr, ku, kf = basis(pos, k["blick"])
        kt = np.tan(np.radians(b["kachel_fov"]) / 2)
        z = d @ kf
        nx = (d @ kr) / z / (kt * w / h)
        ny = (d @ ku) / z / kt
        ok = (z > 0) & (np.abs(nx) < 1) & (np.abs(ny) < 1)
        px = (nx + 1) / 2 * w - 0.5
        py = (1 - ny) / 2 * h - 0.5
        # bilinear
        x0 = np.clip(np.floor(px).astype(int), 0, w - 2); y0 = np.clip(np.floor(py).astype(int), 0, h - 2)
        fx = np.clip(px - x0, 0, 1)[..., None]; fy = np.clip(py - y0, 0, 1)[..., None]
        farbe = (img[y0, x0] * (1 - fx) * (1 - fy) + img[y0, x0 + 1] * fx * (1 - fy)
                 + img[y0 + 1, x0] * (1 - fx) * fy + img[y0 + 1, x0 + 1] * fx * fy)
        # weiches Überblenden zum Rand hin
        g = np.clip((1 - np.abs(nx)) / 0.12, 0, 1) * np.clip((1 - np.abs(ny)) / 0.12, 0, 1)
        g = np.where(ok, g, 0)
        summe += farbe * g[..., None]
        gewicht += g
    luecke = gewicht < 1e-6
    bild = summe / np.maximum(gewicht, 1e-6)[..., None]
    if luecke.any():
        print("Achtung: Lücken", luecke.sum(), "Pixel")
    return Image.fromarray(np.clip(bild, 0, 255).astype(np.uint8))


if __name__ == "__main__":
    b = json.load(open(sys.argv[1]))
    zusammensetzen(b, os.path.dirname(os.path.abspath(sys.argv[1]))).save(sys.argv[2])
    print("gespeichert", sys.argv[2])
