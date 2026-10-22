"""
TikTok-Clip (9:16, ~20 s) aus Lukas' echter Spielaufnahme (Xbox Game Bar, 1920x1080, ohne Ton).

  python3 tools/werbung/tiktok_clip.py <aufnahme.mp4>   ->  dist/werbung/tiktok_crazy_driving_school.mp4

- Hochkant-Ausschnitt um das Auto; oben wird die Anweisungsbox/Warnzeile weggeschnitten (HUD),
  Tacho/Minimap/Menü liegen ohnehin außerhalb des Ausschnitts.
- v2 (Lukas): oben eine klare, feste Leiste mit unseren Texten (keine Unschärfe, keine Animation); die Chaos-Banner
  des Spiels bleiben darunter gut lesbar sichtbar. Keine Musik, keine künstlichen Effekte – nur Motor + Hupe
  aus dem Spiel (die Aufnahme selbst hat keinen Ton). Hook ohne die Fahrlehrerin, die aus dem Heck ragt.
"""
import os, subprocess, sys, wave
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

WURZEL = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
AUS = os.path.join(WURZEL, "dist", "werbung")
W, H, FPS, SR = 1080, 1920, 30, 44100
SCHRIFT = "/usr/share/fonts/opentype/inter/InterDisplay-Black.otf"
EMOJI = "/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf"
LEISTE = 260                                     # feste Textleiste oben (Ausgabe-Pixel)
CROP_W, CROP_H, CROP_Y = 608, 935, 112           # Ausschnitt -> 1080x1660 unter der Leiste, oben ohne HUD
VIDEO_H = H - LEISTE
MAUS = (1014, 632, 34, 40)                       # Mauszeiger steht in der Aufnahme fest hier -> wegretuschieren

# (Start in der Aufnahme, Ende, Ausschnitt-Mitte x, Untertitel-Nr.)
SCHNITTE = [
    (82.8, 84.6, 880, 0),     # rausgeflogen -> Mauer (ab 82.8: Fahrlehrerin nicht mehr im Bild)
    (74.0, 76.2, 960, 1),
    (100.2, 103.3, 960, 2),
    (4.9, 8.3, 960, 3),
    (42.6, 45.4, 960, 4),     # endet, bevor die Fahrlehrerin unter dem Auto steht
]
UNTERTITEL = [
    [("THIS DRIVING SCHOOL", "w"), ("IS ILLEGAL", "y"), ("😭", "e")],
    [("IT STARTS LIKE A", "w"), ("NORMAL LESSON…", "y")],
    [("…THEN THIS", "w"), ("HAPPENS", "y"), ("🍌", "e")],
    [("A CAR IN", "w"), ("MY LANE?!", "y"), ("😱", "e")],
    [("THEN THE", "w"), ("ALIENS CAME", "y"), ("👽", "e")],
]
ENDE = 3.0
LEISTE_FARBE = (16, 18, 30)
GELB, WEISS = (255, 205, 40), (255, 255, 255)


def emoji_bild(z, groesse):
    f = ImageFont.truetype(EMOJI, 109)
    im = Image.new("RGBA", (136, 128), (0, 0, 0, 0))
    ImageDraw.Draw(im).text((0, 0), z, font=f, embedded_color=True)
    im = im.crop(im.getbbox())
    return im.resize((int(im.width * groesse / im.height), groesse), Image.LANCZOS)


def textzeile(text, groesse, farbe, rand=14):
    f = ImageFont.truetype(SCHRIFT, groesse)
    l, t, r, b = f.getbbox(text, stroke_width=rand)
    im = Image.new("RGBA", (r - l + 20, b - t + 20), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # weicher Schatten, dann Text mit dickem dunklem Rand
    sch = Image.new("RGBA", im.size, (0, 0, 0, 0))
    ImageDraw.Draw(sch).text((10 - l + 6, 10 - t + 8), text, font=f, fill=(0, 0, 0, 170), stroke_width=rand, stroke_fill=(0, 0, 0, 170))
    im.alpha_composite(sch.filter(ImageFilter.GaussianBlur(6)))
    d.text((10 - l, 10 - t), text, font=f, fill=farbe, stroke_width=rand, stroke_fill=(22, 20, 34))
    return im


def block(zeilen, max_breite=980):
    """Untertitel-Block: Textzeilen untereinander, Emoji hinter der letzten Textzeile."""
    teile = []
    for text, art in zeilen:
        if art == "e":
            teile.append(("e", emoji_bild(text, 120)))
        else:
            g = 112
            while True:
                im = textzeile(text, g, GELB if art == "y" else WEISS)
                if im.width <= max_breite or g < 60:
                    break
                g -= 6
            teile.append(("t", im))
    reihen = []
    for art, im in teile:
        if art == "e" and reihen and reihen[-1][-1].width + im.width + 10 <= max_breite:
            reihen[-1].append(im)
        else:
            reihen.append([im])
    breite = max(sum(i.width for i in r) + 10 * (len(r) - 1) for r in reihen)
    hoehe = sum(max(i.height for i in r) for r in reihen) - 18 * (len(reihen) - 1)
    out = Image.new("RGBA", (breite, hoehe), (0, 0, 0, 0))
    y = 0
    for r in reihen:
        rh = max(i.height for i in r)
        x = (breite - (sum(i.width for i in r) + 10 * (len(r) - 1))) // 2
        for i in r:
            out.alpha_composite(i, (x, y + (rh - i.height) // 2))
            x += i.width + 10
        y += rh - 18
    return out


def ease_pop(t):
    """0 -> 1.12 -> 1 in 0.22 s (kleiner Überschwinger)."""
    if t >= 0.22:
        return 1.0
    x = t / 0.22
    return 1.12 * (1 - (1 - x) ** 3) - 0.12 * max(0, x - 0.7) / 0.3


def segmente_schneiden(quelle, tmp):
    teile = []
    for i, (a, b, xm, _) in enumerate(SCHNITTE):
        x = int(min(max(xm - CROP_W // 2, 0), 1920 - CROP_W))
        p = os.path.join(tmp, f"seg{i}_{a}_{b}_{x}_{CROP_W}x{CROP_H}_m.mp4")
        teile.append(p)
        if os.path.exists(p):
            continue
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-ss", str(a), "-t", str(b - a), "-i", quelle,
                        "-vf", f"delogo=x={MAUS[0]}:y={MAUS[1]}:w={MAUS[2]}:h={MAUS[3]},crop={CROP_W}:{CROP_H}:{x}:{CROP_Y},scale={W}:{VIDEO_H}:flags=lanczos,fps={FPS},setsar=1",
                        "-an", "-c:v", "libx264", "-crf", "12", "-preset", "fast", p], check=True)
    liste = os.path.join(tmp, "liste.txt")
    open(liste, "w").write("".join(f"file '{p}'\n" for p in teile))
    basis = os.path.join(tmp, "basis.mp4")
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", liste, "-c", "copy", basis], check=True)
    return basis


def endkarte(letztes):
    bg = letztes.filter(ImageFilter.GaussianBlur(18))
    bg = Image.blend(bg, Image.new("RGB", bg.size, (14, 18, 34)), 0.45).convert("RGBA")
    return bg


def main():
    quelle = sys.argv[1]
    tmp = os.path.join(AUS, "_tiktok_tmp")
    os.makedirs(tmp, exist_ok=True)
    basis = segmente_schneiden(quelle, tmp)
    # Zeitachse: wann beginnt welcher Untertitel
    starts, t = [], 0.0
    for a, b, _, u in SCHNITTE:
        starts.append((t, t + (b - a), u))
        t += b - a
    clip_dauer = t
    dauer = clip_dauer + ENDE
    sprites = [block(z) for z in UNTERTITEL]
    titel = block([("CRAZY", "w"), ("DRIVING SCHOOL", "y"), ("🍌", "e")])
    frage = block([("CAN YOU PASS?", "w")], 900)
    play = textzeile("PLAY NOW ON ROBLOX", 64, (22, 20, 34), rand=0)

    def untertitel_bei(t):
        u_start = None
        for a, b, u in starts:
            if a <= t < b:
                # Startzeit des Untertitels = erster Schnitt mit dieser Nummer
                u_start = min(x for x, _, uu in starts if uu == u)
                return u, t - u_start
        return None, 0

    dec = subprocess.Popen(["ffmpeg", "-v", "error", "-i", basis, "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], stdout=subprocess.PIPE)
    # Untertitel einmal passend für die Leiste skalieren (max. 92 % der Leistenhöhe, 94 % der Breite)
    def einpassen(sp):
        k = min(1.0, LEISTE * 0.92 / sp.height, W * 0.94 / sp.width)
        return sp.resize((int(sp.width * k), int(sp.height * k)), Image.LANCZOS)
    leisten_text = [einpassen(sp) for sp in sprites]
    roh = os.path.join(tmp, "bild.mp4")
    enc = subprocess.Popen(["ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-",
                            "-c:v", "libx264", "-crf", "16", "-preset", "slow", "-pix_fmt", "yuv420p", roh], stdin=subprocess.PIPE)
    n_clip = int(round(clip_dauer * FPS))
    letztes = None
    for i in range(int(round(dauer * FPS))):
        t = i / FPS
        if i < n_clip:
            buf = dec.stdout.read(W * VIDEO_H * 3)
            if len(buf) == W * VIDEO_H * 3:
                letztes = Image.frombuffer("RGB", (W, VIDEO_H), buf)
            img = Image.new("RGBA", (W, H), LEISTE_FARBE + (255,))
            img.paste(letztes, (0, LEISTE))
            u, _ = untertitel_bei(t)
            if u is not None:
                sp = leisten_text[u]
                img.alpha_composite(sp, ((W - sp.width) // 2, (LEISTE - sp.height) // 2))
        else:
            te = t - clip_dauer
            if te < 1 / FPS:
                voll = Image.new("RGB", (W, H), LEISTE_FARBE)
                voll.paste(letztes.resize((int(W * H / VIDEO_H), H)), (-(int(W * H / VIDEO_H) - W) // 2, 0))
                end_bg = endkarte(voll)
            img = end_bg.copy()
            k = ease_pop(te)
            sp = titel.resize((max(1, int(titel.width * k)), max(1, int(titel.height * k))), Image.LANCZOS)
            img.alpha_composite(sp, ((W - sp.width) // 2, 560 - sp.height // 2))
            if te > 0.5:
                k2 = ease_pop(te - 0.5)
                sp2 = frage.resize((max(1, int(frage.width * k2)), max(1, int(frage.height * k2))), Image.LANCZOS)
                img.alpha_composite(sp2, ((W - sp2.width) // 2, 900 - sp2.height // 2))
            if te > 1.0:
                # gelber Knopf "PLAY NOW ON ROBLOX", pulsiert leicht
                puls = 1 + 0.04 * np.sin((te - 1.0) * 7)
                bw, bh = int((play.width + 90) * puls), int((play.height + 50) * puls)
                knopf = Image.new("RGBA", (bw, bh), (0, 0, 0, 0))
                ImageDraw.Draw(knopf).rounded_rectangle((0, 0, bw - 1, bh - 1), radius=bh // 2, fill=GELB, outline=(22, 20, 34), width=8)
                pl = play.resize((int(play.width * puls), int(play.height * puls)), Image.LANCZOS)
                knopf.alpha_composite(pl, ((bw - pl.width) // 2, (bh - pl.height) // 2))
                img.alpha_composite(knopf, ((W - bw) // 2, 1180))
            if te > ENDE - 0.35:
                img.alpha_composite(Image.new("RGBA", (W, H), (0, 0, 0, int(255 * (te - (ENDE - 0.35)) / 0.35))))
        enc.stdin.write(img.convert("RGB").tobytes())
    enc.stdin.close()
    enc.wait()
    dec.kill()
    ton = ton_bauen(dauer, starts, os.path.join(tmp, "ton.wav"))
    ziel = os.path.join(AUS, "tiktok_crazy_driving_school.mp4")
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", roh, "-i", ton, "-c:v", "copy", "-c:a", "aac", "-b:a", "192k",
                    "-shortest", "-movflags", "+faststart", ziel], check=True)
    print(ziel, f"{dauer:.1f} s")


def wav(name):
    with wave.open(os.path.join(WURZEL, "dist", "sound", name + ".wav")) as w:
        x = np.frombuffer(w.readframes(w.getnframes()), np.int16).astype(np.float32) / 32768
        if w.getnchannels() == 2:
            x = x.reshape(-1, 2).mean(1)
        if w.getframerate() != SR:
            x = np.interp(np.arange(0, len(x), w.getframerate() / SR), np.arange(len(x)), x)
        return x


def ton_bauen(dauer, starts, pfad):
    """Nur Spielklänge: Motor-Schleife des Fahrschulautos + Lufthorn beim Geisterfahrer. Keine Musik, keine
    künstlichen Effekte (v2, Lukas). Weiche Übergänge an den Schnitten, damit nichts knackt."""
    n = int(SR * dauer)
    mix = np.zeros(n, np.float32)

    def dazu(x, t, laut=1.0):
        a = int(t * SR)
        b = min(n, a + len(x))
        if 0 <= a < n:
            mix[a:b] += x[: b - a] * laut

    motor = wav("DS_Fahrschule_Niedrig")
    blende = int(0.06 * SR)
    for a, b, u in starts:
        m = int((b - a) * SR)
        start = int((a * 7.3 % 1) * len(motor)) % len(motor)   # jede Szene an anderer Stelle der Schleife
        stueck = np.roll(np.resize(motor, m + len(motor)), -start)[:m].copy()
        huelle = np.ones(m, np.float32)
        huelle[:blende] = np.linspace(0, 1, blende)
        huelle[-blende:] = np.linspace(1, 0, blende)
        dazu(stueck * huelle, a, 0.55)
    a0 = {u: a for a, _, u in reversed(starts)}
    horn = wav("DS_Hupe_Lufthorn")
    dazu(horn, a0[3] + 0.15, 0.8)
    dazu(horn, a0[3] + 1.75, 0.8)
    # Endkarte: Motor klingt aus
    m = int(1.2 * SR)
    dazu(np.resize(motor, m) * np.linspace(1, 0, m), dauer - ENDE, 0.4)
    ende = int((dauer - 0.4) * SR)
    mix[ende:] *= np.linspace(1, 0, n - ende)
    mix = mix / (np.max(np.abs(mix)) + 1e-9) * 0.89
    with wave.open(pfad, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((mix * 32767).astype(np.int16).tobytes())
    return pfad


if __name__ == "__main__":
    main()
