"""
15-Sekunden-Trailer aus ECHTEN Spielszenen (Screenshots aus Roblox Studio, tools/werbung/gameplay/*.jpg).

  python3 tools/werbung/gameplay_trailer.py   ->  dist/werbung/trailer_gameplay_15s.mp4

Die Bilder sind echte Aufnahmen aus dem laufenden Spiel (Chaos-Events per Testmenü ausgelöst). Studio liefert nur
Einzelbilder, keine Videoaufnahme – deshalb schnelle Schnitte mit Zoom statt Live-Video. Für echtes Video: OBS (TRAILER.md).
Musik und Geräusche: selbst erzeugt + Hupen aus dist/sound.
"""
import math, os, random, subprocess, wave
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

from bilder import text_mit_rand, SCHRIFT, WURZEL

W, H, FPS, DAUER = 1920, 1080, 30, 15.0
SR = 44100
QUELLE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "gameplay")
AUS = os.path.join(WURZEL, "dist", "werbung")

# (start, ende, [bilder], text, farbe, geraeusch)
SCHNITTE = [
    (0.0, 1.7, ["fahren"], "JUST A NORMAL DRIVING LESSON...", (255, 255, 255), None),
    (1.7, 3.5, ["banane1", "banane2"], "...NOT!", (255, 212, 40), "rutschen"),
    (3.5, 5.2, ["enten1", "enten2"], "DUCKS!", (255, 230, 70), "Ente"),
    (5.2, 6.9, ["kuehe1", "kuehe2"], "COWS!", (255, 255, 255), "Clown"),
    (6.9, 8.8, ["ufo1", "ufo2"], "ALIENS?!", (150, 255, 160), "Lufthorn"),
    (8.8, 10.4, ["reifen1", "reifen2"], "GIANT TIRES!", (255, 120, 90), "Normal"),
    (10.4, 11.8, ["matsch"], "MUD EVERYWHERE!", (230, 170, 110), "Clown"),
    (11.8, 15.1, ["ende"], None, None, "Melodie"),
]

_bilder = {}


def bild_laden(name):
    if name not in _bilder:
        if name == "ende":
            _bilder[name] = Image.open(os.path.join(AUS, "titel_spiel.png")).convert("RGB").resize((W, H), Image.LANCZOS)
        else:
            b = Image.open(os.path.join(QUELLE, name + ".jpg")).convert("RGB")
            # Spielbild über die volle Breite, oben/unten Balken für die Schrift
            breite = W
            hoehe = int(b.size[1] * breite / b.size[0])
            b = b.resize((breite, hoehe), Image.LANCZOS).filter(ImageFilter.UnsharpMask(radius=2, percent=60, threshold=2))
            _bilder[name] = b
    return _bilder[name]


_texte = {}


def textbild(text, groesse, farbe):
    key = (text, groesse, farbe)
    if key not in _texte:
        f = ImageFont.truetype(SCHRIFT, groesse)
        d0 = ImageDraw.Draw(Image.new("RGBA", (1, 1)))
        bb = d0.textbbox((0, 0), text, font=f, stroke_width=groesse // 12)
        w, h = bb[2] - bb[0] + groesse, bb[3] - bb[1] + groesse
        img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        text_mit_rand(ImageDraw.Draw(img), (w / 2, h / 2), text, f, farbe, breite=max(4, groesse // 12))
        _texte[key] = img
    return _texte[key]


def ease_back(t):
    t = min(max(t, 0), 1)
    c = 1.70158
    return 1 + (c + 1) * (t - 1) ** 3 + c * (t - 1) ** 2


def setzen(img, sprite, cx, cy, s, winkel=0):
    if s <= 0.01:
        return
    sp = sprite.resize((max(1, int(sprite.size[0] * s)), max(1, int(sprite.size[1] * s))), Image.BILINEAR)
    if winkel:
        sp = sp.rotate(winkel, expand=True, resample=Image.BILINEAR)
    img.alpha_composite(sp, (int(cx - sp.size[0] / 2), int(cy - sp.size[1] / 2)))


def hintergrund():
    img = Image.new("RGBA", (W, H))
    d = ImageDraw.Draw(img)
    for y in range(H):
        t = y / H
        d.line([(0, y), (W, y)], fill=(int(30 + 20 * t), int(22 + 10 * t), int(60 + 30 * t)))
    return img


HINTER = hintergrund()


def frame(t):
    for start, ende, namen, text, farbe, _ in SCHNITTE:
        if start <= t < ende:
            lt = t - start
            dauer = ende - start
            if namen[0] == "ende":
                b = bild_laden("ende")
                z = 1.0 + 0.03 * lt
                k = b.resize((int(W * z), int(H * z)), Image.BILINEAR)
                img = k.crop(((k.size[0] - W) // 2, (k.size[1] - H) // 2, (k.size[0] - W) // 2 + W, (k.size[1] - H) // 2 + H)).convert("RGBA")
                if lt > 0.6:
                    knopf = Image.new("RGBA", (640, 150), (0, 0, 0, 0))
                    dk = ImageDraw.Draw(knopf)
                    dk.rounded_rectangle((6, 6, 634, 144), radius=36, fill=(40, 170, 80), outline=(25, 20, 40), width=8)
                    dk.text((320, 78), "PLAY NOW!", font=ImageFont.truetype(SCHRIFT, 86), fill=(255, 255, 255), anchor="mm",
                            stroke_width=4, stroke_fill=(25, 20, 40))
                    setzen(img, knopf, 1480, 250, ease_back((lt - 0.6) / 0.3) * (1 + 0.05 * math.sin(lt * 7)), -3)
            else:
                # bei zwei Bildern: Schnitt in der Mitte (Aufprall)
                idx = 0 if len(namen) == 1 or lt < dauer * 0.5 else 1
                b = bild_laden(namen[idx])
                z = 1.0 + 0.07 * (lt / dauer)
                bw, bh = int(b.size[0] * z), int(b.size[1] * z)
                k = b.resize((bw, bh), Image.BILINEAR)
                img = HINTER.copy()
                # Wackeln nach dem Schnitt
                wx = wy = 0
                if idx == 1:
                    k2 = lt - dauer * 0.5
                    if k2 < 0.35:
                        r = random.Random(int(t * 100))
                        s = (1 - k2 / 0.35) * 16
                        wx, wy = r.uniform(-s, s), r.uniform(-s, s)
                y0 = (H - bh) // 2 + 40
                img.paste(k, (int((W - bw) / 2 + wx), int(y0 + wy)))
                if text:
                    groesse = 120 if len(text) < 18 else 84
                    setzen(img, textbild(text, groesse, farbe), W / 2, 110, ease_back(lt / 0.25), -3 if idx == 0 else 3)
                d = ImageDraw.Draw(img)
                d.text((W - 24, H - 18), "real gameplay", font=ImageFont.truetype(SCHRIFT, 26), fill=(255, 255, 255, 160), anchor="rd")
            # weißer Blitz bei jedem Schnitt
            blitz = None
            if start > 0 and lt < 0.08:
                blitz = 1 - lt / 0.08
            if len(namen) == 2 and 0 <= lt - dauer * 0.5 < 0.06:
                blitz = 0.7
            if blitz:
                img.alpha_composite(Image.new("RGBA", (W, H), (255, 255, 255, int(255 * blitz))))
            if t > DAUER - 0.4:
                img.alpha_composite(Image.new("RGBA", (W, H), (0, 0, 0, int(255 * (t - (DAUER - 0.4)) / 0.4))))
            return img.convert("RGB")
    return Image.new("RGB", (W, H))


def wav_laden(name):
    with wave.open(os.path.join(WURZEL, "dist", "sound", name + ".wav")) as w:
        return np.frombuffer(w.readframes(w.getnframes()), np.int16).astype(np.float32) / 32768


def ton():
    n = int(SR * DAUER)
    mix = np.zeros(n, np.float32)

    def dazu(x, t, laut=1.0):
        a = int(t * SR)
        b = min(n, a + len(x))
        if a < n:
            mix[a:b] += x[: b - a] * laut

    tt = lambda d: np.arange(int(SR * d)) / SR
    rnd = np.random.default_rng(2)
    from scipy.signal import butter, lfilter
    # entspannter Lo-Fi-Beat (eigene Akkordfolge): weiche E-Piano-Akkorde, sanfter Kick, Rimshot, leise Hi-Hats, Knistern
    takt = 60 / 88
    AKKORDE = [  # Fmaj7, Em7, Dm7, Cmaj7 (eigene Folge, je 4 Schläge)
        (174.61, 220.0, 261.63, 329.63), (164.81, 196.0, 246.94, 293.66),
        (146.83, 174.61, 220.0, 261.63), (130.81, 164.81, 196.0, 246.94)]
    BASS = [87.31, 82.41, 73.42, 65.41]

    def epiano(f, d):
        t = tt(d)
        huelle = np.minimum(1, t / 0.015) * np.exp(-t * 1.1)
        ton = sum(g * np.sin(2 * np.pi * f * k * (1 + 0.0015 * np.sin(2 * np.pi * 5 * t)) * t) for k, g in ((1, 1), (2, 0.25), (3, 0.08)))
        return ton * huelle

    t = tt(0.4)
    kick = np.sin(2 * np.pi * (48 + 60 * np.exp(-t * 25)) * t) * np.exp(-t * 7)
    t = tt(0.08)
    bb, aa = butter(2, [900 / (SR / 2), 2500 / (SR / 2)], "band")
    rim = lfilter(bb, aa, rnd.standard_normal(len(t))) * np.exp(-t * 45) * 2.2
    t = tt(0.04)
    hb, ha = butter(2, 6000 / (SR / 2), "high")
    hat = lfilter(hb, ha, rnd.standard_normal(len(t))) * np.exp(-t * 110)
    zeit, schlag = 0.0, 0
    while zeit < DAUER:
        takt_nr = schlag // 4
        im_takt = schlag % 4
        if im_takt == 0:
            akk = AKKORDE[takt_nr % 4]
            for i, f in enumerate(akk):
                dazu(epiano(f, takt * 4.2), zeit + i * 0.012, 0.16)  # leicht gebrochen gespielt
            t = tt(takt * 3.8)
            dazu(np.sin(2 * np.pi * BASS[takt_nr % 4] * t) * np.minimum(1, t / 0.02) * np.exp(-t * 0.6), zeit, 0.45)
        if zeit >= 1.7:
            if im_takt in (0, 2):
                dazu(kick, zeit, 0.55)
            if im_takt in (1, 3):
                dazu(rim, zeit, 0.25)
        dazu(hat, zeit, 0.08)
        dazu(hat, zeit + takt * 0.58, 0.06)  # leicht geswingt
        schlag += 1
        zeit += takt
    # Platten-Knistern
    kn = np.zeros(n, np.float32)
    idx = rnd.integers(0, n, int(DAUER * 18))
    kn[idx] = rnd.uniform(-0.6, 0.6, len(idx))
    mix += lfilter(*butter(2, 3000 / (SR / 2), "high")[::1], kn) * 0.05
    from scipy.signal import butter, lfilter
    for start, ende, namen, _, _, g in SCHNITTE:
        tz = start + ((ende - start) * 0.5 if len(namen) == 2 else 0.05)
        if g == "rutschen":
            t = tt(1.2)
            bb, aa = butter(2, [1800 / (SR / 2), 4200 / (SR / 2)], "band")
            dazu(lfilter(bb, aa, rnd.standard_normal(len(t)) * np.exp(-t * 1.6)) * 2.5, tz, 0.3)
        elif g:
            dazu(wav_laden("DS_Hupe_" + g), tz, 0.32)
    ende = int((DAUER - 0.6) * SR)
    mix[ende:] *= np.linspace(1, 0, n - ende)
    mix = mix / (np.max(np.abs(mix)) + 1e-9) * 0.85
    pfad = os.path.join(AUS, "gameplay_ton.wav")
    with wave.open(pfad, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((mix * 32767).astype(np.int16).tobytes())
    return pfad


def main():
    os.makedirs(AUS, exist_ok=True)
    vorschau = os.environ.get("VORSCHAU")
    if vorschau:
        for z in vorschau.split(","):
            frame(float(z)).save(os.path.join(AUS, f"gp_vorschau_{z}.png"))
        return
    tonpfad = ton()
    ziel = os.path.join(AUS, "trailer_gameplay_15s.mp4")
    proc = subprocess.Popen(["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}",
                             "-r", str(FPS), "-i", "-", "-i", tonpfad, "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "19",
                             "-preset", "medium", "-c:a", "aac", "-b:a", "160k", "-shortest", ziel], stdin=subprocess.PIPE)
    for i in range(int(DAUER * FPS)):
        proc.stdin.write(frame(i / FPS).tobytes())
    proc.stdin.close()
    proc.wait()
    os.remove(tonpfad)
    print("gespeichert:", ziel)


if __name__ == "__main__":
    main()
