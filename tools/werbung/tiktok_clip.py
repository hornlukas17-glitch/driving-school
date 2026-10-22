"""
TikTok-Clip (9:16, ~20 s) aus Lukas' echter Spielaufnahme (Xbox Game Bar, 1920x1080, ohne Ton).

  python3 tools/werbung/tiktok_clip.py <aufnahme.mp4>   ->  dist/werbung/tiktok_crazy_driving_school.mp4

- Hochkant-Ausschnitt um das Auto; oben wird die Anweisungsbox/Warnzeile weggeschnitten (HUD),
  Tacho/Minimap/Menü liegen ohnehin außerhalb des Ausschnitts.
- Die Chaos-Banner des Spiels liegen im oberen Drittel: dort liegt ein weich verlaufender Unschärfe-Streifen,
  darauf unsere eigenen Untertitel (Hook am Anfang, Spielname + "Can YOU pass?" am Ende).
- Die Aufnahme hat keinen Ton: Musik, Motor und Effekte werden hier erzeugt (Effekte leiser als die Musik).
"""
import os, subprocess, sys, wave
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

WURZEL = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
AUS = os.path.join(WURZEL, "dist", "werbung")
W, H, FPS, SR = 1080, 1920, 30, 44100
SCHRIFT = "/usr/share/fonts/opentype/inter/InterDisplay-Black.otf"
EMOJI = "/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf"
CROP_W, CROP_H, CROP_Y = 546, 970, 110          # 9:16 aus 1920x1080, oben ohne HUD
BAND = (150, 560)                                # Untertitel-/Unschärfe-Streifen (Ausgabe-Pixel)

# (Start in der Aufnahme, Ende, Ausschnitt-Mitte x, Untertitel-Nr.)
SCHNITTE = [
    (80.6, 82.3, 960, 0),
    (83.0, 84.6, 930, 0),
    (74.0, 76.2, 960, 1),
    (100.2, 103.3, 960, 2),
    (4.9, 8.3, 960, 3),
    (42.6, 47.0, 960, 4),
]
UNTERTITEL = [
    [("THIS DRIVING SCHOOL", "w"), ("IS ILLEGAL", "y"), ("😭", "e")],
    [("IT STARTS LIKE A", "w"), ("NORMAL LESSON…", "y")],
    [("…THEN THIS", "w"), ("HAPPENS", "y"), ("🍌", "e")],
    [("WRONG-WAY", "y"), ("DRIVER?!", "w"), ("😱", "e")],
    [("ALIENS?!", "y"), ("👽", "e")],
]
ENDE = 3.4
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


def band_maske():
    h = BAND[1] - BAND[0]
    y = np.arange(h)
    a = np.clip(np.minimum(y, h - 1 - y) / 70.0, 0, 1)
    return Image.fromarray((np.tile(a[:, None], (1, W)) * 255).astype(np.uint8), "L")


def segmente_schneiden(quelle, tmp):
    teile = []
    for i, (a, b, xm, _) in enumerate(SCHNITTE):
        x = int(min(max(xm - CROP_W // 2, 0), 1920 - CROP_W))
        p = os.path.join(tmp, f"seg{i}_{a}_{b}_{x}.mp4")
        teile.append(p)
        if os.path.exists(p):
            continue
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-ss", str(a), "-t", str(b - a), "-i", quelle,
                        "-vf", f"crop={CROP_W}:{CROP_H}:{x}:{CROP_Y},scale={W}:{H}:flags=lanczos,fps={FPS},setsar=1",
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
    maske = band_maske()

    def untertitel_bei(t):
        u_start = None
        for a, b, u in starts:
            if a <= t < b:
                # Startzeit des Untertitels = erster Schnitt mit dieser Nummer
                u_start = min(x for x, _, uu in starts if uu == u)
                return u, t - u_start
        return None, 0

    dec = subprocess.Popen(["ffmpeg", "-v", "error", "-i", basis, "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], stdout=subprocess.PIPE)
    roh = os.path.join(tmp, "bild.mp4")
    enc = subprocess.Popen(["ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-",
                            "-c:v", "libx264", "-crf", "16", "-preset", "slow", "-pix_fmt", "yuv420p", roh], stdin=subprocess.PIPE)
    n_clip = int(round(clip_dauer * FPS))
    letztes = None
    schnitt_zeiten = [a for a, _, _ in starts[1:]]
    for i in range(int(round(dauer * FPS))):
        t = i / FPS
        if i < n_clip:
            buf = dec.stdout.read(W * H * 3)
            if len(buf) == W * H * 3:
                letztes = Image.frombuffer("RGB", (W, H), buf)
            img = letztes.convert("RGBA")
            # Unschärfe-Streifen über den Spiel-Bannern
            band = img.crop((0, BAND[0], W, BAND[1])).filter(ImageFilter.GaussianBlur(26))
            band = Image.blend(band, Image.new("RGBA", band.size, (14, 16, 30, 255)), 0.35)
            img.paste(band, (0, BAND[0]), maske)
            u, tu = untertitel_bei(t)
            if u is not None:
                s = sprites[u]
                k = ease_pop(tu)
                sp = s.resize((max(1, int(s.width * k)), max(1, int(s.height * k))), Image.LANCZOS)
                img.alpha_composite(sp, ((W - sp.width) // 2, (BAND[0] + BAND[1]) // 2 - sp.height // 2))
            # kurzer Weißblitz bei jedem Schnitt (außer innerhalb des Hooks)
            for z in schnitt_zeiten[1:]:
                if 0 <= t - z < 0.1:
                    img.alpha_composite(Image.new("RGBA", (W, H), (255, 255, 255, int(140 * (1 - (t - z) / 0.1)))))
        else:
            te = t - clip_dauer
            if te < 1 / FPS:
                end_bg = endkarte(letztes)
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
    from scipy.signal import butter, lfilter
    n = int(SR * dauer)
    musik = np.zeros(n, np.float32)
    fx = np.zeros(n, np.float32)
    rnd = np.random.default_rng(7)
    tt = lambda d: np.arange(int(SR * d)) / SR

    def dazu(spur, x, t, laut=1.0):
        a = int(t * SR)
        b = min(n, a + len(x))
        if 0 <= a < n:
            spur[a:b] += x[: b - a] * laut

    # flotter, eigener Beat (124 BPM): Kick auf jeden Schlag, Clap auf 2/4, Offbeat-Hats, Bass, Akkord-Stabs
    takt = 60 / 124
    t = tt(0.35)
    kick = np.sin(2 * np.pi * (50 + 90 * np.exp(-t * 30)) * t) * np.exp(-t * 9)
    t = tt(0.18)
    clap = lfilter(*butter(2, [1000 / (SR / 2), 3500 / (SR / 2)], "band"), rnd.standard_normal(len(t))) * np.exp(-t * 22) * 1.8
    t = tt(0.05)
    hat = lfilter(*butter(2, 7000 / (SR / 2), "high"), rnd.standard_normal(len(t))) * np.exp(-t * 90)
    AKK = [(220.0, 277.18, 329.63), (196.0, 246.94, 293.66), (174.61, 220.0, 261.63), (196.0, 246.94, 329.63)]  # A, G, F, G(sus)
    BASS = [55.0, 49.0, 43.65, 49.0]

    def stab(fs, d):
        t = tt(d)
        h = np.minimum(1, t / 0.005) * np.exp(-t * 6)
        return sum(np.sign(np.sin(2 * np.pi * f * t)) * 0.25 + np.sin(2 * np.pi * f * 2 * t) * 0.3 for f in fs) * h

    zeit, s = 0.0, 0
    musik_ende = dauer
    while zeit < musik_ende:
        tn, im = s // 4, s % 4
        akk = AKK[tn % 4]
        dazu(musik, kick, zeit, 0.7)
        if im in (1, 3):
            dazu(musik, clap, zeit, 0.35)
        dazu(musik, hat, zeit + takt / 2, 0.12)
        t = tt(takt * 0.9)
        dazu(musik, np.sin(2 * np.pi * BASS[tn % 4] * t) * np.minimum(1, t / 0.01) * np.exp(-t * 2.5), zeit + takt / 2, 0.45)
        if im in (0, 2):
            dazu(musik, lfilter(*butter(2, 2500 / (SR / 2)), stab(akk, takt * 0.45)), zeit, 0.12)
        s += 1
        zeit += takt

    # Motor unter den Fahrszenen (leise), Effekte an den passenden Stellen
    motor = wav("DS_Fahrschule_Niedrig")
    for a, b, u in starts:
        stueck = np.resize(motor, int((b - a) * SR)) * np.minimum(1, np.arange(int((b - a) * SR)) / (0.08 * SR))
        dazu(fx, stueck, a, 0.10)
    a0 = {u: a for a, _, u in reversed(starts)}
    # Hook: Aufprall + "Woosh" beim Rausfliegen
    t = tt(0.5)
    dazu(fx, np.sin(2 * np.pi * (70 + 40 * np.exp(-t * 20)) * t) * np.exp(-t * 10), a0[0] + 1.75, 0.5)
    t = tt(0.6)
    dazu(fx, lfilter(*butter(2, [400 / (SR / 2), 2400 / (SR / 2)], "band"), rnd.standard_normal(len(t))) * np.sin(np.pi * t / 0.6), a0[0] + 0.9, 0.35)
    # Banane: Rutsch-Quietschen
    t = tt(1.4)
    quietsch = np.sin(2 * np.pi * (900 + 250 * np.sin(2 * np.pi * 3 * t)) * t) * 0.4 + lfilter(*butter(2, [1800 / (SR / 2), 4200 / (SR / 2)], "band"), rnd.standard_normal(len(t))) * 1.5
    dazu(fx, quietsch * np.exp(-t * 1.5), a0[2] + 0.8, 0.22)
    # Geisterfahrer: Lufthorn
    dazu(fx, wav("DS_Hupe_Lufthorn"), a0[3] + 0.2, 0.35)
    dazu(fx, wav("DS_Hupe_Lufthorn"), a0[3] + 1.9, 0.35)
    # UFO: schwebender Sci-Fi-Ton
    t = tt(3.5)
    ufo = np.sin(2 * np.pi * (300 + 200 * np.sin(2 * np.pi * 0.8 * t) + 30 * np.sin(2 * np.pi * 9 * t)) * t) * np.minimum(1, t / 0.3) * np.minimum(1, (3.5 - t) / 0.4)
    dazu(fx, ufo, a0[4] + 0.6, 0.18)
    # Endkarte: Melodie-Hupe
    dazu(fx, wav("DS_Hupe_Melodie"), dauer - ENDE + 0.1, 0.3)

    mix = musik / (np.max(np.abs(musik)) + 1e-9) * 0.6 + fx
    ende = int((dauer - 0.5) * SR)
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
