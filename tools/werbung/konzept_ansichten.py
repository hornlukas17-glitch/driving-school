"""
Konzept-Mockups für Version 2: Fahrer-Sicht und Fahrlehrer-(Beifahrer-)Sicht.
Grundlage ist eine echte Studio-Aufnahme (gameplay/fahren.jpg); die neue Oberfläche ist darübergezeichnet.

  python3 tools/werbung/konzept_ansichten.py  ->  dist/werbung/konzept_fahrer.png, konzept_fahrlehrer.png
"""
import math, os
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

from bilder import text_mit_rand, banane, kuh, SCHRIFT, SCHRIFT2, WURZEL

HIER = os.path.dirname(os.path.abspath(__file__))
AUS = os.path.join(WURZEL, "dist", "werbung")
W, H = 1920, 1080
DUNKEL = (20, 24, 34)
GELB = (255, 205, 40)
GRUEN = (60, 200, 100)
ROT = (225, 55, 60)


def f(gr, fett=True):
    return ImageFont.truetype(SCHRIFT2 if fett else SCHRIFT2, gr)


def fi(gr):
    return ImageFont.truetype(SCHRIFT, gr)


def spielbild():
    b = Image.open(os.path.join(HIER, "gameplay", "fahren.jpg")).convert("RGB")
    b = b.crop((200, 0, 980, 440)).resize((W, H), Image.LANCZOS)  # ohne Minimap
    b = ImageEnhance.Color(b).enhance(1.12).filter(ImageFilter.UnsharpMask(2, 60, 2))
    return b.convert("RGBA")


def schild(img, txt, xy, farbe=(255, 255, 255), hg=(20, 16, 35, 200)):
    d = ImageDraw.Draw(img)
    bb = d.textbbox((0, 0), txt, font=f(30))
    w, h = bb[2] - bb[0] + 44, bb[3] - bb[1] + 26
    d.rounded_rectangle((xy[0], xy[1], xy[0] + w, xy[1] + h), radius=h // 2, fill=hg)
    d.text((xy[0] + w / 2, xy[1] + h / 2), txt, font=f(30), fill=farbe, anchor="mm")


def pfeil_links(d, cx, cy, s, farbe):
    d.polygon([(cx - s, cy), (cx - s * 0.1, cy - s * 0.75), (cx - s * 0.1, cy - s * 0.3), (cx + s, cy - s * 0.3),
               (cx + s, cy + s * 0.3), (cx - s * 0.1, cy + s * 0.3), (cx - s * 0.1, cy + s * 0.75)], fill=farbe, outline=(20, 16, 35), width=8)


def fahrer():
    img = spielbild()
    # Reste der alten Anweisungs-Box verwischen
    rest = img.crop((0, 0, 1480, 270)).filter(ImageFilter.GaussianBlur(18))
    img.paste(rest, (0, 0))
    # neue Ansage-Leiste vom Fahrlehrer
    o = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(o)
    d.rounded_rectangle((470, 26, 1450, 250), radius=36, fill=(20, 24, 34, 235), outline=(255, 255, 255, 60), width=3)
    img.alpha_composite(o)
    d = ImageDraw.Draw(img)
    pfeil_links(d, 650, 138, 80, GELB)
    text_mit_rand(d, (1040, 112), "LEFT!", fi(120), GELB, breite=8)
    d.text((1040, 205), "Max (Instructor)  ·  in 40 m", font=f(34), fill=(220, 225, 235), anchor="mm")
    # Lautsprecher-Symbol (Ansage wird auch gesprochen)
    d.polygon([(1340, 120), (1360, 120), (1385, 98), (1385, 178), (1360, 156), (1340, 156)], fill=(255, 255, 255))
    for r in (22, 40):
        d.arc((1385 - r, 138 - r, 1385 + r, 138 + r), -45, 45, fill=(255, 255, 255), width=5)
    # Gefahren-Ruf
    o = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    od = ImageDraw.Draw(o)
    od.rounded_rectangle((1210, 300, 1720, 420), radius=30, fill=(225, 55, 60, 235), outline=(20, 16, 35), width=6)
    img.alpha_composite(o)
    img.alpha_composite(banane(46, -20), (1228, 318))
    d = ImageDraw.Draw(img)
    text_mit_rand(d, (1500, 360), "BANANA AHEAD!", fi(52), (255, 255, 255), breite=5)
    # Hinweis: keine Karte
    schild(img, "No map, no route – trust your instructor!", (40, 990))
    # Rollen-Etikett
    d.rounded_rectangle((40, 40, 400, 120), radius=22, fill=(40, 120, 220), outline=(20, 16, 35), width=5)
    d.text((220, 80), "DRIVER VIEW", font=fi(44), fill=(255, 255, 255), anchor="mm")
    return img.convert("RGB")


def karte(w, h):
    """Draufsicht-Karte auf dem Tablet (eigene, schematische Zeichnung der Strecke)"""
    k = Image.new("RGBA", (w, h), (92, 160, 80, 255))
    d = ImageDraw.Draw(k)
    # Häuser
    for (x, y) in [(40, 40), (40, 330), (420, 40), (420, 330), (40, 560), (420, 560), (720, 40), (720, 330)]:
        d.rounded_rectangle((x, y, x + 170, y + 150), radius=10, fill=(235, 230, 220), outline=(150, 140, 130), width=3)
        d.polygon([(x, y), (x + 170, y), (x + 85, y - 0)], fill=(190, 80, 60))
    # Straßen
    strasse = (70, 72, 80)
    d.rectangle((250, 0, 380, h), fill=strasse)          # Hauptstraße (wir fahren nach oben)
    d.rectangle((0, 250, w, 300), fill=strasse)            # Querstraße
    d.rectangle((0, 510, w, 545), fill=strasse)
    for y in range(0, h, 60):
        d.rectangle((312, y, 318, y + 30), fill=(240, 240, 240))
    # Route: geradeaus, dann links in die Querstraße
    pts = [(345, h - 20), (345, 275), (300, 275), (20, 275)]
    d.line(pts, fill=(60, 230, 255), width=18, joint="curve")
    d.line(pts, fill=(255, 255, 255), width=5, joint="curve")
    # Zieltor
    d.rectangle((20, 252, 34, 298), fill=(60, 255, 120))
    # Gefahren mit Vorwarnung
    k.alpha_composite(banane(26, 10), (318, 400))
    kk = kuh(40)
    k.alpha_composite(kk, (110, 210))
    # Unser Auto
    d.rounded_rectangle((327, 600, 363, 660), radius=8, fill=(255, 255, 255), outline=(20, 16, 35), width=4)
    d.polygon([(345, 585), (333, 603), (357, 603)], fill=GELB)
    return k


def fahrlehrer():
    hg = spielbild().convert("RGB").filter(ImageFilter.GaussianBlur(14))
    hg = ImageEnhance.Brightness(hg).enhance(0.55).convert("RGBA")
    img = hg
    d = ImageDraw.Draw(img)
    # Tablet
    tx0, ty0, tx1, ty1 = 360, 110, 1560, 830
    sch = Image.new("L", (W, H), 0)
    ImageDraw.Draw(sch).rounded_rectangle((tx0 + 18, ty0 + 24, tx1 + 18, ty1 + 24), radius=48, fill=170)
    sch = sch.filter(ImageFilter.GaussianBlur(22))
    schwarz = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    schwarz.putalpha(sch)
    img.alpha_composite(schwarz)
    d.rounded_rectangle((tx0, ty0, tx1, ty1), radius=48, fill=(28, 30, 38), outline=(10, 10, 14), width=6)
    mx0, my0, mx1, my1 = tx0 + 36, ty0 + 36, tx1 - 36, ty1 - 36
    k = karte(mx1 - mx0 - 360, my1 - my0)
    maske = Image.new("L", k.size, 0)
    ImageDraw.Draw(maske).rounded_rectangle((0, 0, k.size[0], k.size[1]), radius=26, fill=255)
    img.paste(k, (mx0, my0), maske)
    # Seitenleiste im Tablet: nächste Anweisung + Gefahren
    sx = mx0 + k.size[0] + 24
    d = ImageDraw.Draw(img)
    d.text((sx, my0 + 6), "NEXT", font=f(28), fill=(160, 170, 190))
    pfeil_links(d, sx + 80, my0 + 110, 56, GELB)
    d.text((sx + 160, my0 + 88), "Left", font=fi(52), fill=(255, 255, 255))
    d.text((sx + 162, my0 + 150), "in 40 m", font=f(30), fill=(200, 205, 215))
    d.text((sx, my0 + 230), "INCOMING", font=f(28), fill=(160, 170, 190))
    y = my0 + 275
    for txt, farbe, sek in (("Banana peel", GELB, "3 s"), ("Cow on road", (255, 255, 255), "8 s")):
        d.rounded_rectangle((sx, y, sx + 320, y + 70), radius=18, fill=(45, 48, 60))
        d.text((sx + 22, y + 35), txt, font=f(30), fill=farbe, anchor="lm")
        d.text((sx + 300, y + 35), sek, font=fi(32), fill=(255, 120, 110), anchor="rm")
        y += 86
    d.text((sx, my1 - 70), "Driver: Leo", font=f(28), fill=(160, 170, 190))
    d.text((sx, my1 - 34), "Mistakes 1  ·  01:12", font=f(28), fill=(220, 225, 235))
    # Schnelltasten unten
    knoepfe = [("LEFT", GELB, "Q"), ("STRAIGHT", (255, 255, 255), "W"), ("RIGHT", GELB, "E"),
               ("BRAKE!", ROT, "S"), ("BANANA!", GELB, "1"), ("COW!", (255, 255, 255), "2")]
    bw, bh, gap = 250, 120, 22
    x = (W - (len(knoepfe) * bw + (len(knoepfe) - 1) * gap)) / 2
    for txt, farbe, taste in knoepfe:
        d.rounded_rectangle((x, 880, x + bw, 880 + bh), radius=30, fill=DUNKEL, outline=farbe, width=6)
        d.text((x + bw / 2, 930), txt, font=fi(46), fill=farbe, anchor="mm")
        d.text((x + bw / 2, 982), taste, font=f(24), fill=(160, 170, 190), anchor="mm")
        x += bw + gap
    # Rollen-Etikett
    d.rounded_rectangle((40, 40, 520, 120), radius=22, fill=(225, 55, 60), outline=(20, 16, 35), width=5)
    d.text((280, 80), "INSTRUCTOR VIEW", font=fi(44), fill=(255, 255, 255), anchor="mm")
    schild(img, "Only you see the route – call it out!", (1180, 52))
    return img.convert("RGB")


def main():
    os.makedirs(AUS, exist_ok=True)
    fahrer().save(os.path.join(AUS, "konzept_fahrer.png"))
    fahrlehrer().save(os.path.join(AUS, "konzept_fahrlehrer.png"))
    print("gespeichert")


if __name__ == "__main__":
    main()
