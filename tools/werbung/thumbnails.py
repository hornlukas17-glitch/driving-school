"""
Roblox-Thumbnails (1920x1080) aus ECHTEN Spielszenen (Studio-Aufnahmen vom 21.10., Rohbilder in tools/werbung/thumbs/).
Nur Zuschnitt, leichter Farb-Feinschliff und ein kleines Logo kommen dazu – keine erfundenen Inhalte.

  python3 tools/werbung/thumbnails.py   ->  dist/werbung/thumbnails/thumb_1_kuehe.png, thumb_2_ufo.png, thumb_3_banane.png
"""
import os
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

from bilder import text_mit_rand, banane, SCHRIFT, SCHRIFT2, WURZEL

HIER = os.path.dirname(os.path.abspath(__file__))
ROH = os.path.join(HIER, "thumbs")
AUS = os.path.join(WURZEL, "dist", "werbung", "thumbnails")
W, H = 1920, 1080

# name, Rohbild, Bildausschnitt-Mitte (0..1), Zoom (1 = ganze Höhe), Spruch, Farbe
BILDER = [
    ("thumb_1_kuehe", "roh_kuehe.jpg", (0.47, 0.52), 1.0, None, None),
    ("thumb_2_ufo", "roh_ufo.jpg", (0.50, 0.50), 1.0, None, None),
    ("thumb_3_banane", "roh_banane.jpg", (0.52, 0.52), 1.0, None, None),
]


def zuschnitt(img, mitte, zoom):
    w, h = img.size
    ch = h / zoom
    cw = ch * W / H
    cw = min(cw, w)
    ch = cw * H / W
    cx = min(max(mitte[0] * w, cw / 2), w - cw / 2)
    cy = min(max(mitte[1] * h, ch / 2), h - ch / 2)
    box = (int(cx - cw / 2), int(cy - ch / 2), int(cx + cw / 2), int(cy + ch / 2))
    out = img.crop(box).resize((W, H), Image.LANCZOS)
    out = out.filter(ImageFilter.UnsharpMask(radius=2, percent=70, threshold=2))
    out = ImageEnhance.Color(out).enhance(1.12)
    out = ImageEnhance.Contrast(out).enhance(1.05)
    return out.convert("RGBA")


def logo(img):
    """kleines Spiel-Logo unten links (Name + Banane), damit man das Spiel wiedererkennt"""
    d = ImageDraw.Draw(img)
    f1 = ImageFont.truetype(SCHRIFT, 64)
    x, y = 48, H - 70
    text_mit_rand(d, (x, y), "CRAZY DRIVING SCHOOL", f1, (255, 255, 255), breite=7, anker="lm")
    tb = d.textbbox((x, y), "CRAZY DRIVING SCHOOL", font=f1, anchor="lm")
    b = banane(46, 20)
    img.alpha_composite(b, (tb[2] + 6, y - b.size[1] // 2 - 4))
    return img


def main():
    os.makedirs(AUS, exist_ok=True)
    for name, roh, mitte, zoom, _, _ in BILDER:
        img = Image.open(os.path.join(ROH, roh)).convert("RGB")
        out = logo(zuschnitt(img, mitte, zoom))
        out.convert("RGB").save(os.path.join(AUS, name + ".png"), optimize=True)
        print(name, out.size)


if __name__ == "__main__":
    main()
