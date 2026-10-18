"""
TikTok-/Shorts-Video (hochkant 1080x1920, ~16 s, OHNE Ton) aus echten Spielszenen.

  python3 tools/werbung/tiktok.py   ->  dist/werbung/tiktok_crazy_driving_school.mp4

Quellen: Studio-Screenshots (tools/werbung/gameplay/*.jpg) und die zusammengesetzten Szenen (kacheln/*.json).
Große Schrift, weil viele TikTok ohne Ton schauen. Text bleibt in der sicheren Zone
(oben ~200 px und unten ~420 px sowie rechts ~140 px verdeckt TikTok mit Buttons/Beschreibung).
"""
import math, os, random, subprocess
import numpy as np
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

from bilder import text_mit_rand, banane, SCHRIFT, SCHRIFT2, WURZEL
from kachel import zusammensetzen
import json

W, H, FPS = 1080, 1920, 30
HIER = os.path.dirname(os.path.abspath(__file__))
AUS = os.path.join(WURZEL, "dist", "werbung")
SICHER_X = 470  # Mitte der Textzone (rechts sitzen die TikTok-Knöpfe)


def ease(t):
    t = min(max(t, 0), 1)
    return t * t * (3 - 2 * t)


def ease_back(t):
    t = min(max(t, 0), 1)
    c = 1.70158
    return 1 + (c + 1) * (t - 1) ** 3 + c * (t - 1) ** 2


_cache = {}


def szene(name):
    """zusammengesetzte Studio-Szene 1920x1080 (echte Aufnahmen)"""
    if name not in _cache:
        b = json.load(open(os.path.join(HIER, "kacheln", name + ".json")))
        img = zusammensetzen(b, os.path.join(HIER, "kacheln")).convert("RGB")
        img = ImageEnhance.Color(img).enhance(1.18)
        _cache[name] = img
    return _cache[name]


def screenshot(name):
    if name not in _cache:
        img = Image.open(os.path.join(HIER, "gameplay", name + ".jpg")).convert("RGB")
        _cache[name] = ImageEnhance.Color(img).enhance(1.12)
    return _cache[name]


def hochkant_aus_szene(img, mitte_x, zoom=1.0):
    """schneidet aus einer 1920x1080-Szene einen Hochkant-Streifen und skaliert ihn auf 1080x1920"""
    sh = 1080 / zoom
    sw = sh * W / H
    x0 = min(max(mitte_x - sw / 2, 0), img.size[0] - sw)
    y0 = (1080 - sh) / 2
    return img.resize((W, H), Image.BICUBIC, box=(x0, y0, x0 + sw, y0 + sh))


def breitbild_hochkant(img, zoom=1.0, y_mitte=1000):
    """Querformat-Screenshot mittig auf unscharfem Hintergrund (typischer Hochkant-Look)"""
    hg = img.resize((int(H * img.size[0] / img.size[1]), H), Image.BILINEAR)
    x0 = (hg.size[0] - W) // 2
    hg = hg.crop((x0, 0, x0 + W, H)).filter(ImageFilter.GaussianBlur(28))
    hg = ImageEnhance.Brightness(hg).enhance(0.55)
    breite = int(W * 1.85 * zoom)  # etwas breiter als der Bildschirm: Ränder (Minimap/Tacho) werden abgeschnitten
    hoehe = int(img.size[1] * breite / img.size[0])
    vorne = img.resize((breite, hoehe), Image.LANCZOS)
    out = hg.copy()
    out.paste(vorne, ((W - breite) // 2, int(y_mitte - hoehe / 2)))
    return out


_texte = {}


def text(txt, groesse, farbe=(255, 255, 255), rand=(20, 16, 35)):
    key = (txt, groesse, farbe, rand)
    if key not in _texte:
        f = ImageFont.truetype(SCHRIFT, groesse)
        zeilen = txt.split("\n")
        d0 = ImageDraw.Draw(Image.new("RGBA", (1, 1)))
        breiten = [d0.textbbox((0, 0), z, font=f, stroke_width=groesse // 10)[2] for z in zeilen]
        w = max(breiten) + groesse
        zh = int(groesse * 1.12)
        h = zh * len(zeilen) + groesse // 2
        img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        for i, z in enumerate(zeilen):
            text_mit_rand(d, (w / 2, groesse * 0.6 + i * zh + groesse * 0.1), z, f, farbe, rand=rand, breite=max(5, groesse // 10))
        _texte[key] = img
    return _texte[key]


def setzen(img, sprite, cx, cy, s=1.0, winkel=0):
    if s <= 0.01:
        return
    sp = sprite if abs(s - 1) < 0.01 else sprite.resize((max(1, int(sprite.size[0] * s)), max(1, int(sprite.size[1] * s))), Image.BILINEAR)
    if winkel:
        sp = sp.rotate(winkel, expand=True, resample=Image.BILINEAR)
    img.alpha_composite(sp, (int(cx - sp.size[0] / 2), int(cy - sp.size[1] / 2)))


def pop(img, txt, t, t0, cy, groesse=110, farbe=(255, 255, 255), winkel=-3, cx=SICHER_X):
    if t >= t0:
        setzen(img, text(txt, groesse, farbe), cx, cy, ease_back((t - t0) / 0.28), winkel)


def chip(img, txt, t, t0, cy, farbe=(220, 40, 60), groesse=54, cx=SICHER_X, winkel=2):
    if t < t0:
        return
    f = ImageFont.truetype(SCHRIFT, groesse)
    d0 = ImageDraw.Draw(Image.new("RGBA", (1, 1)))
    bb = d0.textbbox((0, 0), txt, font=f)
    w, h = bb[2] - bb[0] + 60, bb[3] - bb[1] + 40
    c = Image.new("RGBA", (w + 14, h + 14), (0, 0, 0, 0))
    d = ImageDraw.Draw(c)
    d.rounded_rectangle((7, 7, w + 7, h + 7), radius=24, fill=farbe, outline=(20, 16, 35), width=6)
    d.text((w / 2 + 7, h / 2 + 9), txt, font=f, fill=(255, 255, 255), anchor="mm", stroke_width=3, stroke_fill=(20, 16, 35))
    setzen(img, c, cx, cy, ease_back((t - t0) / 0.25), winkel)


def wackel(t, t0, staerke=24, dauer=0.45):
    if t0 <= t < t0 + dauer:
        k = (1 - (t - t0) / dauer) * staerke
        r = random.Random(int(t * 1000))
        return int(r.uniform(-k, k)), int(r.uniform(-k, k))
    return 0, 0


def verschieben(img, dx, dy):
    if dx == 0 and dy == 0:
        return img
    out = Image.new(img.mode, img.size)
    out.paste(img, (dx, dy))
    return out


def fortschritt(img, t, dauer):
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, int(W * t / dauer), 10), fill=(255, 212, 40, 255))


# ------------------------------------------------------------------ Szenen (Start, Ende, Funktion)
def s_hook(t):
    # 0 – 2.2 s: echte Szene (Kühe, Hühner, Reifen ums Fahrschulauto), Text sofort da
    lt = t
    img = hochkant_aus_szene(szene("kuehe"), 980 - lt * 40, 1.0 + lt * 0.05).convert("RGBA")
    setzen(img, text("POV:", 120, (255, 212, 40)), SICHER_X, 330, ease_back(lt / 0.2), -4)
    setzen(img, text("your driving test\nis on Roblox...", 92), SICHER_X, 520, ease_back((lt - 0.15) / 0.25), -3)
    if lt > 1.1:
        setzen(img, text("...and it's\nCOMPLETE CHAOS", 100, (255, 90, 90)), SICHER_X, 1300, ease_back((lt - 1.1) / 0.25), 3)
    return img


def s_banane(t):
    # 2.2 – 4.6
    lt = t - 2.2
    bild = "banane1" if lt < 1.0 else "banane2"
    img = breitbild_hochkant(screenshot(bild), 1.0 + lt * 0.06).convert("RGBA")
    dx, dy = wackel(t, 3.2)
    img = verschieben(img, dx, dy)
    pop(img, "BANANA PEEL", t, 2.25, 430, 120, (255, 212, 40))
    if lt >= 1.0:
        pop(img, "= SPIN OUT!", t, 3.2, 1500, 120, (255, 255, 255), 4)
    return img


def s_enten(t):
    # 4.6 – 6.6
    lt = t - 4.6
    bild = "enten1" if lt < 0.9 else "enten2"
    img = breitbild_hochkant(screenshot(bild), 1.0 + lt * 0.05).convert("RGBA")
    pop(img, "DUCKS\nCROSSING", t, 4.65, 430, 120, (255, 230, 70))
    if lt >= 0.9:
        pop(img, "QUAAACK!", t, 5.5, 1500, 130, (255, 255, 255), 4)
    return img


def s_ufo(t):
    # 6.6 – 9.0: echte Szene, Kamera fährt am Strahl hoch
    lt = t - 6.6
    img = hochkant_aus_szene(szene("ufo"), 980, 1.15 - lt * 0.06).convert("RGBA")
    dx, dy = wackel(t, 6.6, 10, 0.3)
    img = verschieben(img, dx, dy)
    pop(img, "ALIENS\nSTEAL YOUR CAR", t, 6.7, 380, 104, (150, 255, 160))
    chip(img, "drive into the beam = bonus", t, 7.6, 1440, (40, 150, 80), 46)
    return img


def s_reifen(t):
    # 9.0 – 10.6
    lt = t - 9.0
    bild = "reifen1" if lt < 0.75 else "reifen2"
    img = breitbild_hochkant(screenshot(bild), 1.0 + lt * 0.06).convert("RGBA")
    dx, dy = wackel(t, 9.75)
    img = verschieben(img, dx, dy)
    pop(img, "GIANT TIRES", t, 9.05, 430, 120, (255, 140, 90))
    if lt >= 0.75:
        pop(img, "BOING!", t, 9.75, 1500, 140, (255, 255, 255), 5)
    return img


def s_party(t):
    # 10.6 – 13.2: echte Szene, Schwenk über die 4 Autos
    lt = t - 10.6
    img = hochkant_aus_szene(szene("party"), 520 + lt * 330, 1.05).convert("RGBA")
    pop(img, "RACE YOUR\nFRIENDS", t, 10.65, 380, 116, (255, 212, 40))
    chip(img, "Party test for 4 players", t, 11.4, 1440, (220, 40, 60), 48)
    return img


def s_ende(t):
    # 13.2 – 16.5: echtes Titelbild-Motiv
    lt = t - 13.2
    img = hochkant_aus_szene(szene("titel"), 1040, 1.0 + lt * 0.03).convert("RGBA")
    # dunkler Verlauf oben für die Schrift
    v = Image.new("L", (1, 256))
    for y in range(256):
        v.putpixel((0, y), int(190 * (1 - y / 255) ** 1.4))
    v = v.resize((W, 1000))
    s = Image.new("RGBA", (W, 1000), (12, 8, 30, 255))
    s.putalpha(v)
    img.alpha_composite(s, (0, 0))
    setzen(img, text("CRAZY", 150, (255, 255, 255), (200, 30, 50)), SICHER_X + 20, 330, ease_back(lt / 0.25), -5)
    setzen(img, text("DRIVING\nSCHOOL", 150, (255, 212, 40)), SICHER_X + 20, 560, ease_back((lt - 0.12) / 0.25), -3)
    if lt > 0.2:
        setzen(img, banane(80, -30), 860, 270, ease_back((lt - 0.2) / 0.3))
    chip(img, "FREE on Roblox", t, 13.8, 1240, (40, 170, 80), 70, SICHER_X, -2)
    if lt > 1.3:
        puls = 1 + 0.04 * math.sin(lt * 7)
        setzen(img, text("search: Crazy Driving School", 56), SICHER_X, 1390, ease_back((lt - 1.3) / 0.25) * puls, 0)
    return img


SZENEN = [(0, 2.2, s_hook), (2.2, 4.6, s_banane), (4.6, 6.6, s_enten), (6.6, 9.0, s_ufo),
          (9.0, 10.6, s_reifen), (10.6, 13.2, s_party), (13.2, 16.5, s_ende)]
DAUER = 16.5


def bild(t):
    for a, b, f in SZENEN:
        if a <= t < b:
            img = f(t)
            if a > 0 and t - a < 0.07:  # kurzer weißer Blitz beim Schnitt
                img.alpha_composite(Image.new("RGBA", (W, H), (255, 255, 255, int(200 * (1 - (t - a) / 0.07)))))
            fortschritt(img, t, DAUER)
            return img.convert("RGB")
    return Image.new("RGB", (W, H))


def main():
    os.makedirs(AUS, exist_ok=True)
    vorschau = os.environ.get("VORSCHAU")
    if vorschau:
        for z in vorschau.split(","):
            bild(float(z)).save(os.path.join(AUS, f"tt_{z}.png"))
        return
    ziel = os.path.join(AUS, "tiktok_crazy_driving_school.mp4")
    proc = subprocess.Popen(["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}",
                             "-r", str(FPS), "-i", "-", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "19",
                             "-preset", "medium", "-movflags", "+faststart", "-an", ziel], stdin=subprocess.PIPE)
    for i in range(int(DAUER * FPS)):
        proc.stdin.write(bild(i / FPS).tobytes())
    proc.stdin.close()
    proc.wait()
    print("gespeichert:", ziel)


if __name__ == "__main__":
    main()
