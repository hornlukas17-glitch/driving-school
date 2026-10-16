"""
Werbebilder fürs Spiel (Icon 512x512 und Thumbnail 1920x1080), komplett selbst gezeichnet.

  python3 tools/werbung/bilder.py   ->  dist/werbung/icon.png, dist/werbung/thumbnail.png

Das Auto kommt aus dem Karosserie-Renderer (tools/mesh/render.py, Fahrschulwagen.obj muss in dist/mesh liegen:
python3 tools/mesh/fahrschulwagen.py). Alles andere (Straße, Bananen, Enten, UFO, Schrift) zeichnet dieses Skript.
"""
import math, os, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

WURZEL = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
AUS = os.path.join(WURZEL, "dist", "werbung")
SCHRIFT = "/usr/share/fonts/truetype/google-fonts/Poppins-BoldItalic.ttf"
SCHRIFT2 = "/usr/share/fonts/truetype/google-fonts/Poppins-Bold.ttf"


_RENDERER = {}


def auto_rendern(azim, elev, B, H, abstand=30, farbe="0.96,0.96,0.97"):
    """rendert den Fahrschulwagen mit dem Karosserie-Renderer und gibt ein RGBA-Bild (Hintergrund transparent) zurück"""
    import sys
    ns = _RENDERER.get(farbe)
    if ns is None:
        quelle = open(os.path.join(WURZEL, "tools", "mesh", "render.py")).read()
        quelle = quelle.split("ansichten = [")[0]  # nur die Funktionen, nicht das Speichern
        alt = sys.argv
        sys.argv = ["render.py", os.path.join(WURZEL, "dist", "mesh", "Fahrschulwagen.obj"),
                    os.path.join(WURZEL, "tools", "mesh", "fahrschule_info.json"), "-", farbe]
        ns = {"__name__": "render"}
        exec(compile(quelle, "render.py", "exec"), ns)
        sys.argv = alt
        _RENDERER[farbe] = ns
    bild = ns["rendern"](azim, elev, B=B, H=H, abstand=abstand)
    hinter = (np.ones((H, B, 3)) * np.linspace(0.93, 0.8, H)[:, None, None] * 255).astype(np.uint8)
    maske = (np.abs(bild.astype(int) - hinter.astype(int)).sum(2) > 0).astype(np.uint8) * 255
    rgba = np.dstack([bild, maske])
    img = Image.fromarray(rgba, "RGBA")
    return img.crop(img.getbbox())


def text_mit_rand(d, pos, text, schrift, farbe, rand=(25, 20, 40), breite=8, anker="mm", schatten=True):
    x, y = pos
    if schatten:
        d.text((x + breite * 0.6, y + breite * 0.9), text, font=schrift, fill=(0, 0, 0, 120), anchor=anker,
               stroke_width=breite, stroke_fill=(0, 0, 0, 120))
    d.text((x, y), text, font=schrift, fill=farbe, anchor=anker, stroke_width=breite, stroke_fill=rand)


def banane(groesse, winkel=0):
    """Banane (eigene einfache Form): gelbe Sichel mit dunklen Enden"""
    s = groesse
    img = Image.new("RGBA", (s * 2, s * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rand = (110, 70, 10)
    aussen, innen = [], []
    for t in np.linspace(0, 1, 30):
        a = math.radians(200 + 140 * t)
        dicke = 0.08 + 0.22 * math.sin(t * math.pi)
        aussen.append((s + math.cos(a) * s * 0.9, s * 0.55 + math.sin(a) * -s * 0.9 * -1 + s * 0.5))
        innen.append((s + math.cos(a) * s * (0.9 - dicke), s * 0.55 + math.sin(a) * -s * (0.9 - dicke) * -1 + s * 0.5))
    # Sichel nach unten gewölbt
    aussen = [(x, 2 * s - y) for x, y in aussen]
    innen = [(x, 2 * s - y) for x, y in innen]
    d.polygon(aussen + innen[::-1], fill=(255, 215, 40), outline=rand)
    d.line(aussen, fill=rand, width=max(3, s // 18))
    d.line(innen, fill=rand, width=max(3, s // 18))
    # Lichtkante
    licht = [(x * 0.5 + xi * 0.5, y * 0.5 + yi * 0.5) for (x, y), (xi, yi) in zip(aussen[5:-5], innen[5:-5])]
    d.line(licht, fill=(255, 245, 160), width=max(2, s // 14))
    for p in (aussen[0], aussen[-1]):
        d.ellipse((p[0] - s * 0.07, p[1] - s * 0.07, p[0] + s * 0.07, p[1] + s * 0.07), fill=(80, 50, 15))
    img = img.crop(img.getbbox())
    return img.rotate(winkel, resample=Image.BICUBIC, expand=True)


def ente(groesse):
    s = groesse
    img = Image.new("RGBA", (s * 2, s * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rand = (90, 60, 10)
    d.ellipse((s * 0.2, s * 0.8, s * 1.7, s * 1.7), fill=(255, 220, 50), outline=rand, width=4)          # Körper
    d.polygon([(s * 0.25, s * 1.0), (s * 0.0, s * 0.85), (s * 0.3, s * 1.25)], fill=(255, 210, 40), outline=rand)  # Schwanz
    d.ellipse((s * 1.05, s * 0.25, s * 1.75, s * 0.95), fill=(255, 225, 60), outline=rand, width=4)     # Kopf
    d.polygon([(s * 1.68, s * 0.55), (s * 2.0, s * 0.62), (s * 1.68, s * 0.75)], fill=(255, 130, 20), outline=rand)  # Schnabel
    d.ellipse((s * 1.42, s * 0.45, s * 1.56, s * 0.59), fill=(20, 20, 20))
    d.ellipse((s * 1.46, s * 0.47, s * 1.5, s * 0.51), fill=(255, 255, 255))
    d.chord((s * 0.6, s * 0.95, s * 1.3, s * 1.45), 200, 340, fill=(240, 200, 30), outline=rand)     # Flügel
    return img


def ufo(breite):
    w = breite
    img = Image.new("RGBA", (w, int(w * 1.6)), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # Strahl
    strahl = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ds = ImageDraw.Draw(strahl)
    ds.polygon([(w * 0.38, w * 0.38), (w * 0.62, w * 0.38), (w * 0.95, w * 1.6), (w * 0.05, w * 1.6)], fill=(140, 255, 160, 95))
    strahl = strahl.filter(ImageFilter.GaussianBlur(w / 40))
    img.alpha_composite(strahl)
    d.ellipse((w * 0.3, w * 0.02, w * 0.7, w * 0.36), fill=(150, 230, 255), outline=(30, 50, 70), width=5)   # Kuppel
    d.ellipse((w * 0.02, w * 0.2, w * 0.98, w * 0.46), fill=(150, 160, 175), outline=(30, 35, 45), width=6)  # Scheibe
    d.ellipse((w * 0.12, w * 0.24, w * 0.88, w * 0.36), fill=(190, 200, 210))
    for i in range(7):
        x = w * (0.14 + i * 0.12)
        d.ellipse((x - w * 0.025, w * 0.36, x + w * 0.025, w * 0.41), fill=(120, 255, 140))
    return img


def kuh(groesse):
    s = groesse
    img = Image.new("RGBA", (int(s * 2.2), int(s * 1.6)), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rand = (30, 30, 30)
    for x in (0.45, 0.7, 1.4, 1.65):
        d.rectangle((s * x, s * 0.95, s * (x + 0.14), s * 1.5), fill=(245, 245, 245), outline=rand, width=3)
    d.rounded_rectangle((s * 0.3, s * 0.35, s * 1.9, s * 1.1), radius=int(s * 0.25), fill=(250, 250, 250), outline=rand, width=4)
    d.ellipse((s * 0.6, s * 0.45, s * 1.0, s * 0.8), fill=(35, 35, 35))
    d.ellipse((s * 1.3, s * 0.65, s * 1.6, s * 0.95), fill=(35, 35, 35))
    d.rounded_rectangle((s * 1.75, s * 0.1, s * 2.2, s * 0.6), radius=int(s * 0.15), fill=(250, 250, 250), outline=rand, width=4)
    d.rounded_rectangle((s * 1.95, s * 0.38, s * 2.2, s * 0.6), radius=int(s * 0.08), fill=(255, 170, 180), outline=rand, width=3)
    d.ellipse((s * 1.85, s * 0.2, s * 1.95, s * 0.3), fill=(20, 20, 20))
    return img


def strasse(B, H, horizont):
    """Himmel, Gras und eine Straße in Perspektive"""
    img = Image.new("RGBA", (B, H))
    d = ImageDraw.Draw(img)
    for y in range(horizont):
        t = y / horizont
        d.line([(0, y), (B, y)], fill=(int(70 + 110 * t), int(150 + 80 * t), int(245 - 10 * t)))
    for y in range(horizont, H):
        t = (y - horizont) / (H - horizont)
        d.line([(0, y), (B, y)], fill=(int(80 + 30 * t), int(170 + 30 * t), int(70 + 20 * t)))
    # Wolken
    rnd = random.Random(4)
    for _ in range(7):
        cx, cy = rnd.randint(0, B), rnd.randint(int(horizont * 0.1), int(horizont * 0.7))
        for k in range(5):
            r = rnd.randint(int(B * 0.025), int(B * 0.05))
            d.ellipse((cx + k * r * 0.8 - r, cy - r * (0.6 + 0.4 * (k % 2)), cx + k * r * 0.8 + r, cy + r * 0.6), fill=(255, 255, 255, 235))
    # Straße: Fluchtpunkt in der Mitte des Horizonts
    fx = B * 0.5
    unten_l, unten_r = -B * 0.25, B * 1.25
    d.polygon([(fx - B * 0.03, horizont), (fx + B * 0.03, horizont), (unten_r, H), (unten_l, H)], fill=(70, 72, 78))
    # Bordsteine
    for seite in (-1, 1):
        oben = fx + seite * B * 0.03
        u = unten_r if seite > 0 else unten_l
        d.line([(oben, horizont), (u, H)], fill=(225, 225, 220), width=int(B * 0.012))
    # Mittellinie gestrichelt
    for i in range(14):
        t0, t1 = (i / 14) ** 2, ((i + 0.5) / 14) ** 2
        y0, y1 = horizont + (H - horizont) * t0, horizont + (H - horizont) * t1
        w0, w1 = 2 + 22 * t0 * B / 1920, 2 + 22 * t1 * B / 1920
        d.polygon([(fx - w0, y0), (fx + w0, y0), (fx + w1, y1), (fx - w1, y1)], fill=(250, 250, 250))
    return img


def schatten(img, auto, pos, staerke=0.55):
    w, h = auto.size
    sw, sh = int(w * 0.95), int(h * 0.22)
    maske = Image.new("L", (sw + 200, sh + 200), 0)
    ImageDraw.Draw(maske).ellipse((100, 100, 100 + sw, 100 + sh), fill=int(255 * staerke))
    maske = maske.filter(ImageFilter.GaussianBlur(30))
    schwarz = Image.new("RGBA", maske.size, (0, 0, 0, 255))
    schwarz.putalpha(maske)
    img.alpha_composite(schwarz, (int(pos[0] + w * 0.025 - 100), int(pos[1] + h - sh * 0.75 - 100)))


def skaliert(bild, breite):
    h = int(bild.size[1] * breite / bild.size[0])
    return bild.resize((breite, h), Image.LANCZOS)


def sprechblase(img, xy, text, schrift, rechts_unten=True):
    d = ImageDraw.Draw(img)
    x, y = xy
    bbox = d.textbbox((0, 0), text, font=schrift)
    w, h = bbox[2] - bbox[0] + 60, bbox[3] - bbox[1] + 44
    d.rounded_rectangle((x, y, x + w, y + h), radius=28, fill=(255, 255, 255), outline=(25, 25, 35), width=6)
    sx = x + w * 0.25
    d.polygon([(sx, y + h - 3), (sx + 40, y + h - 3), (sx - 10, y + h + 50)], fill=(255, 255, 255), outline=(25, 25, 35))
    d.line([(sx + 3, y + h - 3), (sx + 37, y + h - 3)], fill=(255, 255, 255), width=8)
    d.text((x + w / 2, y + h / 2), text, font=schrift, fill=(25, 25, 35), anchor="mm")


def titel(img, pos, f):
    """Spielname "CRAZY / DRIVING / SCHOOL" mit Banane, oben-mittig an pos (x = Mitte, y = Oberkante), f = Größe"""
    x, y = pos
    d = ImageDraw.Draw(img)
    # "CRAZY" auf einem schrägen roten Band
    band = Image.new("RGBA", (int(560 * f), int(150 * f)), (0, 0, 0, 0))
    db = ImageDraw.Draw(band)
    db.rounded_rectangle((8 * f, 8 * f, band.size[0] - 8 * f, band.size[1] - 8 * f), radius=int(26 * f), fill=(220, 40, 60), outline=(25, 20, 40), width=max(3, int(8 * f)))
    db.text((band.size[0] / 2, band.size[1] / 2 + 4 * f), "CRAZY", font=ImageFont.truetype(SCHRIFT, int(118 * f)), fill=(255, 255, 255), anchor="mm",
            stroke_width=max(2, int(5 * f)), stroke_fill=(25, 20, 40))
    band = band.rotate(4, expand=True, resample=Image.BICUBIC)
    img.alpha_composite(band, (int(x - band.size[0] / 2), int(y + 10 * f)))
    b = banane(int(70 * f), -30)
    img.alpha_composite(b, (int(x + band.size[0] / 2 - 30 * f), int(y + 20 * f)))
    gross = ImageFont.truetype(SCHRIFT, int(150 * f))
    text_mit_rand(d, (x, y + 245 * f), "DRIVING", gross, (255, 255, 255), breite=max(3, int(11 * f)))
    text_mit_rand(d, (x, y + 385 * f), "SCHOOL", gross, (255, 212, 40), breite=max(3, int(11 * f)))


def thumbnail(auto):
    B, H = 1920, 1080
    img = strasse(B, H, 470)
    # UFO mit Kuh im Strahl (oben rechts)
    u = ufo(420)
    img.alpha_composite(u, (1440, 20))
    img.alpha_composite(kuh(110).rotate(-15, expand=True, resample=Image.BICUBIC), (1540, 300))
    # Enten über die Straße
    for i, x in enumerate((640, 760, 860)):
        e = ente(70 if i == 0 else 48)
        img.alpha_composite(e, (x, 470 - e.size[1] // 2 + 20))
    # Auto (dreht sich auf der Banane)
    a = skaliert(auto, 860).rotate(6, expand=True, resample=Image.BICUBIC)
    pos = (520, 990 - a.size[1])
    schatten(img, a, pos)
    img.alpha_composite(a, pos)
    # Bananen auf der Straße
    for (x, y, g, w) in ((300, 900, 90, 20), (1500, 900, 100, -25)):
        b = banane(g, w)
        img.alpha_composite(b, (x - b.size[0] // 2, y - b.size[1] // 2))
    # Rutsch-Striche
    d = ImageDraw.Draw(img)
    for k in range(3):
        d.arc((150 + k * 30, 640 + k * 25, 700 + k * 30, 1150 + k * 25), 200, 260, fill=(255, 255, 255), width=10)
    # Sprechblase des Fahrlehrers
    sprechblase(img, (1060, 380), "BANANA!!! BRAKE!", ImageFont.truetype(SCHRIFT2, 52))
    # Titel
    titel(img, (560, 0), 1.0)
    klein = ImageFont.truetype(SCHRIFT2, 46)
    d = ImageDraw.Draw(img)
    # Leiste unten
    leiste = "CRAZY INSTRUCTORS  •  BANANAS  •  UFOs  •  PLAY WITH FRIENDS"
    d.rounded_rectangle((0, 1000, B, H), radius=0, fill=(25, 20, 40, 220))
    d.text((B / 2, 1040), leiste, font=klein, fill=(255, 255, 255), anchor="mm")
    return img.convert("RGB")


def icon(auto):
    S = 1024  # doppelt so groß zeichnen, am Ende verkleinern (glatte Kanten)
    img = Image.new("RGBA", (S, S))
    d = ImageDraw.Draw(img)
    for y in range(S):
        t = y / S
        d.line([(0, y), (S, y)], fill=(int(255 - 40 * t), int(200 - 120 * t), int(40 + 30 * t)))
    # Strahlen
    mitte = (S / 2, S * 0.58)
    for i in range(16):
        a0, a1 = i * 2 * math.pi / 16, (i + 0.5) * 2 * math.pi / 16
        d.polygon([mitte, (mitte[0] + math.cos(a0) * S, mitte[1] + math.sin(a0) * S),
                   (mitte[0] + math.cos(a1) * S, mitte[1] + math.sin(a1) * S)], fill=(255, 230, 90, 90))
    a = skaliert(auto, 820).rotate(8, expand=True, resample=Image.BICUBIC)
    pos = (S // 2 - a.size[0] // 2, S - a.size[1] - 10)
    schatten(img, a, pos, 0.45)
    img.alpha_composite(a, pos)
    d = ImageDraw.Draw(img)
    titel(img, (S / 2, -20), 1.12)
    return img.resize((512, 512), Image.LANCZOS).convert("RGB")


def main():
    os.makedirs(AUS, exist_ok=True)
    auto = auto_rendern(-38, 14, 1600, 940, abstand=26)
    thumbnail(auto).save(os.path.join(AUS, "thumbnail.png"))
    icon(auto).save(os.path.join(AUS, "icon.png"))
    print("gespeichert:", os.path.join(AUS, "thumbnail.png"), os.path.join(AUS, "icon.png"))


if __name__ == "__main__":
    main()
