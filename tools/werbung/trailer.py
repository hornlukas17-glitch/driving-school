"""
Trailer "Crazy Driving School" (32 s, 1920x1080, 30 fps) – komplett selbst gezeichnet und vertont.

  python3 tools/werbung/trailer.py   ->  dist/werbung/trailer.mp4

Bilder: Auto aus dem Karosserie-Renderer (dist/mesh/Fahrschulwagen.obj), alles andere aus tools/werbung/bilder.py.
Ton: eigene Musik (Beat + Bass, hier synthetisiert) und die Hupen aus dist/sound (tools/sound/hupen.py).
Echte Spielszenen gibt es nicht – für einen Trailer mit echtem Gameplay siehe TRAILER.md (Aufnahme mit OBS).
"""
import math, os, random, subprocess, wave
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

import bilder as B_
from bilder import banane, ente, ufo, kuh, strasse, skaliert, text_mit_rand, SCHRIFT, SCHRIFT2, WURZEL

W, H, FPS, DAUER = 1920, 1080, 30, 32.0
AUS = os.path.join(WURZEL, "dist", "werbung")
SR = 44100


# ---------------------------------------------------------------- Hilfen
def ease_back(t):
    t = min(max(t, 0), 1)
    c = 1.70158
    return 1 + (c + 1) * (t - 1) ** 3 + c * (t - 1) ** 2


def ease(t):
    t = min(max(t, 0), 1)
    return t * t * (3 - 2 * t)


def mitte_setzen(img, sprite, cx, cy, skala=1.0, winkel=0.0):
    if skala <= 0.01:
        return
    s = sprite
    if abs(skala - 1) > 0.01:
        s = s.resize((max(1, int(s.size[0] * skala)), max(1, int(s.size[1] * skala))), Image.BILINEAR)
    if abs(winkel) > 0.1:
        s = s.rotate(winkel, expand=True, resample=Image.BILINEAR)
    img.alpha_composite(s, (int(cx - s.size[0] / 2), int(cy - s.size[1] / 2)))


_text_cache = {}


def textbild(text, groesse, farbe=(255, 255, 255), rand=(25, 20, 40)):
    key = (text, groesse, farbe, rand)
    if key not in _text_cache:
        f = ImageFont.truetype(SCHRIFT, groesse)
        d0 = ImageDraw.Draw(Image.new("RGBA", (1, 1)))
        bb = d0.textbbox((0, 0), text, font=f, stroke_width=groesse // 12)
        w, h = bb[2] - bb[0] + groesse, bb[3] - bb[1] + groesse
        img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        text_mit_rand(d, (w / 2, h / 2), text, f, farbe, rand=rand, breite=max(4, groesse // 12))
        _text_cache[key] = img
    return _text_cache[key]


def pop_text(img, text, t, t0, cx, cy, groesse=150, farbe=(255, 255, 255), winkel=-4, dauer=None):
    if t < t0 or (dauer and t > t0 + dauer):
        return
    s = ease_back((t - t0) / 0.3)
    mitte_setzen(img, textbild(text, groesse, farbe), cx, cy, s, winkel)


_blasen = {}


def blase(text, groesse=46):
    if text not in _blasen:
        f = ImageFont.truetype(SCHRIFT2, groesse)
        d0 = ImageDraw.Draw(Image.new("RGBA", (1, 1)))
        bb = d0.textbbox((0, 0), text, font=f)
        w, h = bb[2] - bb[0] + 60, bb[3] - bb[1] + 44
        img = Image.new("RGBA", (w + 20, h + 70), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        d.rounded_rectangle((6, 6, w + 6, h + 6), radius=26, fill=(255, 255, 255), outline=(25, 25, 35), width=6)
        sx = 6 + w * 0.25
        d.polygon([(sx, h + 3), (sx + 40, h + 3), (sx - 10, h + 60)], fill=(255, 255, 255), outline=(25, 25, 35))
        d.line([(sx + 3, h + 3), (sx + 37, h + 3)], fill=(255, 255, 255), width=8)
        d.text((6 + w / 2, 6 + h / 2), text, font=f, fill=(25, 25, 35), anchor="mm")
        _blasen[text] = img
    return _blasen[text]


def blase_zeigen(img, text, t, t0, x, y, dauer=2.0):
    if t0 <= t <= t0 + dauer:
        b = blase(text)
        s = ease_back((t - t0) / 0.25)
        mitte_setzen(img, b, x + b.size[0] / 2, y + b.size[1] / 2, s)


def wackeln(t, t0, staerke=18, dauer=0.6):
    if t0 <= t <= t0 + dauer:
        k = (1 - (t - t0) / dauer) * staerke
        r = random.Random(int(t * 100))
        return r.uniform(-k, k), r.uniform(-k, k)
    return 0, 0


# ---------------------------------------------------------------- Grafiken vorbereiten
print("Autos rendern …")
FRONT = B_.auto_rendern(-38, 14, 1000, 600, abstand=26)
DREH = [B_.auto_rendern(-38 + k * 30, 14, 1000, 600, abstand=26) for k in range(12)]
FARBEN = {"weiss": "0.96,0.96,0.97", "rot": "0.85,0.12,0.12", "blau": "0.15,0.35,0.85", "gelb": "0.95,0.72,0.08"}
SEITE = {}
for name, f in FARBEN.items():
    s = B_.auto_rendern(-90, 4, 1000, 600, abstand=26, farbe=f)
    SEITE[name] = s
# Fahrtrichtung der Seitenansicht: das Auto soll nach rechts fahren (Front rechts)
# (der Renderer schaut von links; falls die Front links ist, spiegeln)
SPIEGELN = os.environ.get("SPIEGELN", "1") == "1"
if SPIEGELN:
    SEITE = {k: v.transpose(Image.FLIP_LEFT_RIGHT) for k, v in SEITE.items()}

STRASSE = strasse(W, H, 470).convert("RGBA")


def seitenstrasse():
    img = Image.new("RGBA", (W, H))
    d = ImageDraw.Draw(img)
    for y in range(H):
        t = y / H
        d.line([(0, y), (W, y)], fill=(int(80 + 120 * t), int(160 + 70 * t), 250))
    r = random.Random(9)
    x = -40
    while x < W + 3000:
        bw, bh = r.randint(160, 300), r.randint(220, 480)
        farbe = r.choice([(232, 196, 160), (190, 205, 225), (240, 230, 200), (205, 170, 150), (175, 190, 175)])
        d.rectangle((x, 620 - bh, x + bw, 620), fill=farbe, outline=(60, 60, 70), width=4)
        for fy in range(620 - bh + 30, 600, 60):
            for fx in range(x + 20, x + bw - 40, 55):
                d.rectangle((fx, fy, fx + 32, fy + 36), fill=(120, 170, 220), outline=(60, 60, 70), width=2)
        x += bw + r.randint(10, 40)
    d.rectangle((0, 600, W, 640), fill=(200, 200, 195))
    d.rectangle((0, 640, W, 1080), fill=(70, 72, 78))
    return img


SEITE_BG = seitenstrasse()
ENDKARTE = Image.open(os.path.join(AUS, "thumbnail.png")).convert("RGBA")

r0 = random.Random(3)
MATSCH = []
for i in range(11):
    g = r0.randint(140, 320)
    m = Image.new("RGBA", (g, int(g * r0.uniform(0.7, 1.1))), (0, 0, 0, 0))
    dm = ImageDraw.Draw(m)
    farbe = (r0.randint(80, 110), r0.randint(55, 70), 30, 245)
    dm.ellipse((0, 0, m.size[0], m.size[1]), fill=farbe)
    for _ in range(5):
        a = r0.uniform(0, 2 * math.pi)
        rr = g * 0.12
        cx, cy = m.size[0] / 2 + math.cos(a) * g * 0.45, m.size[1] / 2 + math.sin(a) * g * 0.42
        dm.ellipse((cx - rr, cy - rr, cx + rr, cy + rr), fill=farbe)
    MATSCH.append((m, r0.uniform(0.08, 0.92) * W, r0.uniform(0.12, 0.8) * H, 14.0 + i * 0.07))

ENTE_GR, ENTE_KL = ente(80), ente(52)
BANANE = banane(80, 15)
UFO = ufo(520)
KUH = kuh(120)


def frontauto(img, cx, cy, breite, sprite=None, winkel=0):
    a = sprite or FRONT
    skala = breite / a.size[0]
    # Schatten
    sw, sh = int(breite * 0.9), int(breite * 0.15)
    sch = Image.new("L", (sw + 80, sh + 80), 0)
    ImageDraw.Draw(sch).ellipse((40, 40, 40 + sw, 40 + sh), fill=140)
    sch = sch.filter(ImageFilter.GaussianBlur(18))
    schwarz = Image.new("RGBA", sch.size, (0, 0, 0, 255))
    schwarz.putalpha(sch)
    hoehe = a.size[1] * skala
    img.alpha_composite(schwarz, (int(cx - sw / 2 - 40), int(cy + hoehe * 0.42 - sh / 2 - 40)))
    mitte_setzen(img, a, cx, cy, skala, winkel)


def untertitel(img, text, t, t0):
    if t < t0:
        return
    n = int((t - t0) * 28)
    sichtbar = text[:n]
    if not sichtbar:
        return
    d = ImageDraw.Draw(img)
    f = ImageFont.truetype(SCHRIFT, 70)
    text_mit_rand(d, (W / 2, 950), sichtbar, f, (255, 255, 255), breite=7)


# ---------------------------------------------------------------- Szenen
def szene_normal(t):
    img = STRASSE.copy()
    k = ease(t / 3.0)
    frontauto(img, W / 2 + 60, 560 + 150 * k, 300 + 520 * k)
    blase_zeigen(img, "Nice and easy...", t, 1.2, 1150, 260, 1.8)
    untertitel(img, "Just a normal driving lesson...", t, 0.3)
    return img


def szene_banane(t):
    # 3.0 - 6.5
    img = STRASSE.copy()
    lt = t - 3.0
    dx, dy = wackeln(t, 3.55, 22, 0.8)
    if lt < 0.5:
        frontauto(img, W / 2 + 60 + dx, 710 + dy, 820)
        mitte_setzen(img, BANANE, W / 2 + 40, 980 - lt * 120)
    else:
        k = min(1, (lt - 0.5) / 1.6)
        drehung = ease(k) * 1.15  # etwas mehr als eine ganze Drehung
        idx = int(drehung * 12) % 12
        frontauto(img, W / 2 + 60 + dx + k * 80, 710 + dy - math.sin(k * math.pi) * 40, 820, DREH[idx], math.sin(k * 6) * 6)
        if k < 1:
            d = ImageDraw.Draw(img)
            for j in range(3):
                d.arc((300 + j * 40, 640 + j * 30, 1500 + j * 40, 1240 + j * 30), 190, 250, fill=(255, 255, 255), width=12)
    blase_zeigen(img, "BANANA!!!", t, 3.45, 1250, 430, 2.4)
    pop_text(img, "...NOT!", t, 3.6, W / 2, 300, 230, (255, 212, 40), -6)
    return img


def szene_enten(t):
    # 6.5 - 9.5
    img = STRASSE.copy()
    lt = t - 6.5
    bremsen = lt > 0.5
    dx, dy = wackeln(t, 7.0, 10, 0.4)
    frontauto(img, W / 2 + 60 + dx, 720 + dy + (8 if bremsen and lt < 0.9 else 0), 760)
    for i in range(5):
        x = -300 + lt * 700 - i * 240
        hupf = abs(math.sin((lt * 6 + i) * 1.3)) * 18
        e = ENTE_GR if i == 0 else ENTE_KL
        mitte_setzen(img, e, x, 930 - hupf, 1.7)
    blase_zeigen(img, "QUACK?!", t, 7.1, 1250, 380, 2.0)
    pop_text(img, "DUCKS!", t, 7.0, 600, 250, 220, (255, 230, 70), 5)
    return img


def szene_ufo(t):
    # 9.5 - 13.5
    img = STRASSE.copy()
    lt = t - 9.5
    uy = -500 + 560 * ease(lt / 0.8)
    ux = W / 2 + 60 + math.sin(lt * 2) * 20
    # Kuh wird hochgezogen
    kuh_y = 900 - 650 * ease((lt - 0.8) / 1.2)
    auto_hoch = 380 * ease((lt - 2.0) / 1.5)
    strahl = lt > 0.8
    if strahl:
        st = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ImageDraw.Draw(st).polygon([(ux - 100, uy + 230), (ux + 100, uy + 230), (ux + 520, H), (ux - 520, H)], fill=(140, 255, 160, 90))
        img.alpha_composite(st.filter(ImageFilter.GaussianBlur(12)))
    frontauto(img, W / 2 + 60, 720 - auto_hoch, 700, None, math.sin(lt * 3) * 4 if auto_hoch > 1 else 0)
    if lt < 2.1:
        mitte_setzen(img, KUH, ux - 500 + 500 * ease((lt - 0.8) / 1.2), kuh_y, 1.2, -15 + lt * 40)
    mitte_setzen(img, UFO.crop((0, 0, UFO.size[0], int(UFO.size[0] * 0.5))), ux, uy + 130, 1.0)
    pop_text(img, "ALIENS?!", t, 10.4, 520, 560, 200, (150, 255, 160), -5)
    blase_zeigen(img, "Put us DOWN!", t, 11.6, 1250, 200, 1.9)
    return img


def szene_matsch(t):
    # 13.5 - 16.5
    img = STRASSE.copy()
    lt = t - 13.5
    dx, dy = wackeln(t, 14.0, 14, 0.5)
    frontauto(img, W / 2 + 60 + dx, 700 + dy, 820)
    pfuetze = Image.new("RGBA", (700, 160), (0, 0, 0, 0))
    ImageDraw.Draw(pfuetze).ellipse((0, 0, 700, 160), fill=(95, 65, 30, 230))
    if lt < 0.55:
        mitte_setzen(img, pfuetze, W / 2 + 40, 1000 - lt * 150)
    for m, x, y, t0 in MATSCH:
        if t >= t0:
            s = ease_back((t - t0) / 0.2)
            tropfen = max(0, t - t0 - 1.0) * 60
            mitte_setzen(img, m, x, y + tropfen, s)
    pop_text(img, "CRAZY INSTRUCTORS", t, 14.4, W / 2, 230, 150, (255, 255, 255), -3)
    blase_zeigen(img, "Who taught you to drive?!", t, 14.9, 1000, 380, 1.6)
    return img


def szene_freunde(t):
    # 16.5 - 20.5
    img = SEITE_BG.copy()
    lt = t - 16.5
    vorne = SEITE["weiss"]
    hinten = SEITE["rot"]
    x1 = 300 + lt * 260
    mitte_setzen(img, vorne, x1 + 520, 740, 0.85)
    # Banane fliegt nach hinten
    bx0 = x1 + 520 - 330
    if 0.9 < lt < 1.6:
        k = (lt - 0.9) / 0.7
        mitte_setzen(img, BANANE, bx0 - k * 380, 650 - math.sin(k * math.pi) * 200 + k * 90, 0.9, k * 400)
    elif lt >= 1.6:
        mitte_setzen(img, BANANE, bx0 - 380 - (lt - 1.6) * 0, 740, 0.9)
    # rotes Auto dahinter, rutscht ab 1.9
    x2 = x1 - 640
    if lt < 1.9:
        mitte_setzen(img, hinten, x2 + 520, 760, 0.75)
    else:
        k = min(1, (lt - 1.9) / 1.2)
        mitte_setzen(img, hinten, x2 + 520 + k * 120, 760 + math.sin(k * math.pi) * 30, 0.75, -ease(k) * 380)
    pop_text(img, "RIDE WITH FRIENDS", t, 16.7, W / 2, 200, 150, (255, 255, 255), -3)
    blase_zeigen(img, "GOTCHA!", t, 18.4, x1 + 650, 420, 2.0)
    return img


def szene_party(t):
    # 20.5 - 24.5
    img = SEITE_BG.copy()
    d = ImageDraw.Draw(img)
    lt = t - 20.5
    # Ziellinie
    for i in range(12):
        for j in range(2):  # (Ziellinie)
            farbe = (255, 255, 255) if (i + j) % 2 == 0 else (20, 20, 20)
            d.rectangle((1780 + j * 30, 640 + i * 37, 1810 + j * 30, 677 + i * 37), fill=farbe)
    reihen = [("blau", 690, 0.42, 0.88), ("gelb", 790, 0.47, 0.80), ("rot", 890, 0.52, 0.93), ("weiss", 1000, 0.57, 1.0)]
    start = 1.4
    for name, y, skala, tempo in reihen:
        if lt < start:
            x = 150
        else:
            x = 200 + (lt - start) ** 1.5 * 500 * tempo
        x = min(x, 1600 - (1 - tempo) * 900)
        mitte_setzen(img, SEITE[name], x, y, skala)
    for i, (txt, t0) in enumerate((("3", 0.0), ("2", 0.45), ("1", 0.9), ("GO!", 1.35))):
        if t0 <= lt < t0 + 0.45:
            pop_text(img, txt, lt, t0, W / 2, 420, 260, (255, 212, 40) if txt == "GO!" else (255, 255, 255), 0)
    pop_text(img, "PARTY TEST FOR 4", t, 20.5, W / 2, 170, 140, (255, 255, 255), -3)
    if lt > 3.1:
        pop_text(img, "WINNER!", lt, 3.1, 1500, 470, 120, (255, 212, 40), 6)
    return img


HUPEN_TEXTE = [("HONK!", 24.7, 300, 300), ("QUACK QUACK!", 25.2, 1150, 260), ("BWAAAAH!", 25.7, 260, 640),
               ("HONK HONK!", 26.2, 1250, 640), ("TA-TA-TA-TAAA!", 26.7, 700, 150)]


def szene_hupen(t):
    # 24.5 - 27.5
    img = STRASSE.copy()
    dx, dy = wackeln(t, 24.7, 6, 2.5)
    frontauto(img, W / 2 + 60 + dx, 720 + dy, 800)
    for text, t0, x, y in HUPEN_TEXTE:
        if t >= t0:
            mitte_setzen(img, textbild(text, 90, (255, 230, 60)), x + 200, y + 60, ease_back((t - t0) / 0.25), random.Random(t0).uniform(-10, 10))
    pop_text(img, "FUNNY HORNS", t, 24.5, W / 2, 950, 130, (255, 255, 255), 0)
    return img


def szene_ende(t):
    # 27.5 - 32
    lt = t - 27.5
    z = 1.0 + 0.04 * lt
    k = ENDKARTE.resize((int(W * z), int(H * z)), Image.BILINEAR)
    img = k.crop(((k.size[0] - W) // 2, (k.size[1] - H) // 2, (k.size[0] - W) // 2 + W, (k.size[1] - H) // 2 + H))
    if lt > 0.8:
        puls = 1 + 0.05 * math.sin(lt * 7)
        knopf = Image.new("RGBA", (620, 150), (0, 0, 0, 0))
        dk = ImageDraw.Draw(knopf)
        dk.rounded_rectangle((6, 6, 614, 144), radius=36, fill=(40, 170, 80), outline=(25, 20, 40), width=8)
        dk.text((310, 78), "PLAY NOW!", font=ImageFont.truetype(SCHRIFT, 86), fill=(255, 255, 255), anchor="mm",
                stroke_width=4, stroke_fill=(25, 20, 40))
        mitte_setzen(img, knopf, 1450, 820, ease_back((lt - 0.8) / 0.3) * puls, -3)
    return img


SZENEN = [(0, 3.0, szene_normal), (3.0, 6.5, szene_banane), (6.5, 9.5, szene_enten), (9.5, 13.5, szene_ufo),
          (13.5, 16.5, szene_matsch), (16.5, 20.5, szene_freunde), (20.5, 24.5, szene_party), (24.5, 27.5, szene_hupen),
          (27.5, 32.1, szene_ende)]


def bild(t):
    for a, b, f in SZENEN:
        if a <= t < b:
            img = f(t)
            # kurzer weißer Blitz beim Schnitt
            if t - a < 0.1 and a > 0:
                weiss = Image.new("RGBA", (W, H), (255, 255, 255, int(255 * (1 - (t - a) / 0.1))))
                img.alpha_composite(weiss)
            if t > DAUER - 0.5:
                schwarz = Image.new("RGBA", (W, H), (0, 0, 0, int(255 * (t - (DAUER - 0.5)) / 0.5)))
                img.alpha_composite(schwarz)
            return img.convert("RGB")


# ---------------------------------------------------------------- Ton
def wav_laden(name):
    p = os.path.join(WURZEL, "dist", "sound", name + ".wav")
    with wave.open(p) as w:
        x = np.frombuffer(w.readframes(w.getnframes()), np.int16).astype(np.float32) / 32768
    return x


def ton():
    n = int(SR * DAUER)
    mix = np.zeros(n, np.float32)

    def dazu(x, t, laut=1.0):
        a = int(t * SR)
        b = min(n, a + len(x))
        if a < n:
            mix[a:b] += x[: b - a] * laut

    bpm = 128
    takt = 60 / bpm
    tt = lambda d: np.arange(int(SR * d)) / SR
    # Schlagzeug
    t = tt(0.35)
    kick = np.sin(2 * np.pi * (50 + 120 * np.exp(-t * 30)) * t) * np.exp(-t * 9)
    t = tt(0.2)
    rnd = np.random.default_rng(1)
    snare = (rnd.standard_normal(len(t)) * 0.6 + np.sin(2 * np.pi * 190 * t) * 0.5) * np.exp(-t * 18)
    t = tt(0.05)
    hat = rnd.standard_normal(len(t)) * np.exp(-t * 90) * 0.35
    basslauf = [55.0, 55.0, 43.65, 43.65, 65.41, 65.41, 49.0, 49.0]  # A F C G (eigene Folge)
    schlag = 0
    zeit = 0.0
    while zeit < DAUER - 1.0:
        voll = 3.6 <= zeit < 27.4
        if voll:
            dazu(kick, zeit, 0.9)
            if schlag % 2 == 1:
                dazu(snare, zeit, 0.5)
        dazu(hat, zeit, 0.35 if voll else 0.2)
        dazu(hat, zeit + takt / 2, 0.25 if voll else 0.12)
        f = basslauf[(schlag // 2) % len(basslauf)]
        t = tt(takt * 0.9)
        b = (np.sign(np.sin(2 * np.pi * f * t)) * 0.3 + np.sin(2 * np.pi * f * t)) * np.exp(-t * 2.5)
        dazu(b, zeit, 0.35 if voll else 0.18)
        # Melodie (eigene, nur im vollen Teil)
        if voll and schlag % 4 == 0:
            for k2, mf in enumerate((440, 523.25, 659.25, 523.25)):
                t2 = tt(takt * 0.22)
                dazu(np.sign(np.sin(2 * np.pi * mf * t2)) * np.exp(-t2 * 12) * 0.12, zeit + k2 * takt / 4)
        schlag += 1
        zeit += takt
    # Effekte
    t = tt(1.4)
    rutsch = rnd.standard_normal(len(t)) * np.exp(-t * 1.5)
    from scipy.signal import butter, lfilter
    bb, aa = butter(2, [1800 / (SR / 2), 4200 / (SR / 2)], "band")
    dazu(lfilter(bb, aa, rutsch) * 2.5, 3.55, 0.8)
    t = tt(3.4)
    dazu(np.sin(2 * np.pi * (400 + 120 * np.sin(2 * np.pi * 4 * t)) * t) * 0.25 * np.minimum(1, t * 3), 9.7, 0.7)  # UFO
    hupe = {k: wav_laden("DS_Hupe_" + k) for k in ("Normal", "Clown", "Ente", "Lufthorn", "Melodie")}
    dazu(hupe["Ente"], 7.0, 0.8)
    dazu(hupe["Lufthorn"], 11.6, 0.6)
    dazu(hupe["Clown"], 14.0, 0.8)
    dazu(hupe["Normal"], 18.4, 0.7)
    for i, tz in enumerate((20.5, 20.95, 21.4)):
        t = tt(0.15)
        dazu(np.sin(2 * np.pi * 880 * t) * np.exp(-t * 10), tz, 0.5)
    t = tt(0.4)
    dazu(np.sin(2 * np.pi * 1760 * t) * np.exp(-t * 6), 21.85, 0.5)
    dazu(hupe["Melodie"], 23.6, 0.7)
    for name, tz in (("Normal", 24.7), ("Ente", 25.2), ("Lufthorn", 25.7), ("Clown", 26.2), ("Melodie", 26.7)):
        dazu(hupe[name], tz, 0.7)
    dazu(hupe["Lufthorn"], 27.55, 0.6)
    # Ausblenden + Normalisieren
    ende = int((DAUER - 1.0) * SR)
    mix[ende:] *= np.linspace(1, 0, n - ende)
    mix = np.tanh(mix / (np.max(np.abs(mix)) + 1e-9) * 1.4) * 0.9
    pfad = os.path.join(AUS, "trailer_ton.wav")
    with wave.open(pfad, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((mix * 32767).astype(np.int16).tobytes())
    return pfad


def main():
    os.makedirs(AUS, exist_ok=True)
    tonpfad = ton()
    ziel = os.path.join(AUS, "trailer.mp4")
    proc = subprocess.Popen(["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}",
                             "-r", str(FPS), "-i", "-", "-i", tonpfad, "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "20",
                             "-preset", "medium", "-c:a", "aac", "-b:a", "160k", "-shortest", ziel], stdin=subprocess.PIPE)
    anzahl = int(DAUER * FPS)
    vorschau = os.environ.get("VORSCHAU")  # z. B. VORSCHAU=4.2,10.8 speichert nur diese Bilder als PNG
    if vorschau:
        proc.stdin.close()
        proc.kill()
        for z in vorschau.split(","):
            bild(float(z)).save(os.path.join(AUS, f"vorschau_{z}.png"))
        return
    for i in range(anzahl):
        proc.stdin.write(bild(i / FPS).tobytes())
        if i % 150 == 0:
            print(f"  {i / FPS:.0f} s")
    proc.stdin.close()
    proc.wait()
    os.remove(tonpfad)
    print("gespeichert:", ziel)


if __name__ == "__main__":
    main()
