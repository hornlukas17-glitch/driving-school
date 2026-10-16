"""
Titelbild + 3 Bilder aus ECHTEN Studio-Aufnahmen (zusammengesetzt mit kachel.py, Rohbilder in tools/werbung/kacheln/).
Nur Schrift und ein leichter Farb-Feinschliff kommen dazu.

  python3 tools/werbung/spielbilder.py   ->  dist/werbung/titel_spiel.png, bild_1_aliens.png, bild_2_party.png, bild_3_chaos.png
"""
import os
from PIL import Image, ImageDraw, ImageEnhance, ImageFont, ImageFilter

from bilder import text_mit_rand, banane, SCHRIFT, SCHRIFT2, WURZEL
from kachel import zusammensetzen
import json

HIER = os.path.dirname(os.path.abspath(__file__))
KACHELN = os.path.join(HIER, "kacheln")
AUS = os.path.join(WURZEL, "dist", "werbung")


def roh(name):
    b = json.load(open(os.path.join(KACHELN, name + ".json")))
    img = zusammensetzen(b, KACHELN).convert("RGB")
    img = ImageEnhance.Color(img).enhance(1.18)
    img = ImageEnhance.Contrast(img).enhance(1.06)
    return img.convert("RGBA")


def verlauf(img, oben=True, staerke=150, hoehe=0.38):
    W, H = img.size
    v = Image.new("L", (1, 256))
    for y in range(256):
        v.putpixel((0, y), int(staerke * (1 - y / 255) ** 1.6))
    v = v.resize((W, int(H * hoehe)))
    schwarz = Image.new("RGBA", v.size, (10, 8, 25, 255))
    schwarz.putalpha(v if oben else v.transpose(Image.FLIP_TOP_BOTTOM))
    img.alpha_composite(schwarz, (0, 0 if oben else H - v.size[1]))


def band(img, text, mitte, farbe=(220, 40, 60), groesse=64, winkel=3):
    f = ImageFont.truetype(SCHRIFT, groesse)
    d0 = ImageDraw.Draw(Image.new("RGBA", (1, 1)))
    bb = d0.textbbox((0, 0), text, font=f)
    w, h = bb[2] - bb[0] + 70, bb[3] - bb[1] + 44
    b = Image.new("RGBA", (w + 16, h + 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(b)
    d.rounded_rectangle((8, 8, w + 8, h + 8), radius=22, fill=farbe, outline=(25, 20, 40), width=7)
    d.text((w / 2 + 8, h / 2 + 10), text, font=f, fill=(255, 255, 255), anchor="mm", stroke_width=3, stroke_fill=(25, 20, 40))
    b = b.rotate(winkel, expand=True, resample=Image.BICUBIC)
    img.alpha_composite(b, (int(mitte[0] - b.size[0] / 2), int(mitte[1] - b.size[1] / 2)))


def titelbild():
    img = roh("titel")
    verlauf(img, True, 170, 0.45)
    d = ImageDraw.Draw(img)
    band(img, "CRAZY", (430, 95), groesse=92, winkel=4)
    img.alpha_composite(banane(64, -30), (650, 30))
    gross = ImageFont.truetype(SCHRIFT, 150)
    text_mit_rand(d, (430, 240), "DRIVING", gross, (255, 255, 255), breite=11)
    text_mit_rand(d, (430, 380), "SCHOOL", gross, (255, 212, 40), breite=11)
    return img.convert("RGB")


def endbild(name, titel, unter, farbe, band_farbe):
    img = roh(name)
    verlauf(img, True, 165, 0.36)
    verlauf(img, False, 140, 0.22)
    d = ImageDraw.Draw(img)
    text_mit_rand(d, (960, 120), titel, ImageFont.truetype(SCHRIFT, 130), farbe, breite=10)
    band(img, unter, (960, 990), farbe=band_farbe, groesse=52, winkel=-2)
    return img.convert("RGB")


def main():
    os.makedirs(AUS, exist_ok=True)
    titelbild().save(os.path.join(AUS, "titel_spiel.png"))
    endbild("ufo", "BEAMED UP BY ALIENS!", "Drive through the beam for a bonus", (150, 255, 160), (40, 150, 80)).save(os.path.join(AUS, "bild_1_aliens.png"))
    endbild("party", "PARTY TEST FOR 4", "Race your friends – first to park wins!", (255, 212, 40), (220, 40, 60)).save(os.path.join(AUS, "bild_2_party.png"))
    endbild("kuehe", "CHAOS IN EVERY LESSON", "Cows · chickens · giant tires · bananas", (255, 255, 255), (40, 100, 220)).save(os.path.join(AUS, "bild_3_chaos.png"))
    print("gespeichert in", AUS)


if __name__ == "__main__":
    main()
