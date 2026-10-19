# Haus C "Cottage": kleiner, steiler Giebel zur Strasse, Holzveranda mit Gelaender, Blumenkaesten.
# Braucht den Blender-Text "haus_lib" (tools/blender/haus_lib.py).
import bpy, math
exec(bpy.data.texts["haus_lib"].as_string())
h = Haus("HausC", "Haus_C", versatz=(64, 0, 0))
B, T, H = 18.0, 14.0, 7.0
NEIG = math.radians(42)
TAN = math.tan(NEIG)
FIRST = H + (B / 2) * TAN
UEB = 0.9
# Sockel aus Naturstein, Waende, Eckleisten
h.box("Stein", (0, 0, 0.6), (B + 0.4, T + 0.4, 1.2))
for i in range(5):                                   # Steinfugen-Andeutung
    h.box("Sockel", (0, -T / 2 - 0.21, 0.25 + i * 0.24), (B + 0.4, 0.02, 0.04))
h.box("Wand", (0, 0, 1.2 + (H - 1.2) / 2), (B, T, H - 1.2))
for sx in (-1, 1):
    for sy in (-1, 1):
        h.box("Holz", (sx * (B / 2 - 0.05), sy * (T / 2 - 0.05), 1.2 + (H - 1.2) / 2), (0.45, 0.45, H - 1.2))
# Giebel vorne und hinten (Fachwerk-Andeutung vorne)
for sy in (-1, 1):
    y0 = sy * T / 2
    h.prisma_y("Wand", y0 - sy * 0.5, y0, [(-B / 2, H), (B / 2, H), (0, FIRST)])
h.box("Holz", (0, -T / 2 - 0.1, H + 0.15), (B, 0.25, 0.3))
for x in (-5.5, 5.5):
    hh = FIRST - H - abs(x) * TAN - 0.6
    h.box("Holz", (x, -T / 2 - 0.1, H + hh / 2 + 0.2), (0.3, 0.25, hh))
h.box("Holz", (0, -T / 2 - 0.1, (H + FIRST) / 2), (0.3, 0.25, FIRST - H - 0.4))
# Dach: First entlang Y, Flaechen nach links/rechts, mit Biberschwanz-Reihen
lang = (B / 2 + UEB) / math.cos(NEIG)
for sx in (-1, 1):
    d = (B / 2 + UEB) / 2
    h.box("Dach", (sx * d, 0, FIRST - d * TAN + 0.3), (lang, T + 2 * UEB, 0.4), (0, sx * math.degrees(NEIG), 0))
    n = 11
    for i in range(n):
        dd = (i + 0.55) / n * (B / 2 + UEB)
        h.box("Dach", (sx * dd, 0, FIRST - dd * TAN + 0.58), (lang / n * 0.98, T + 2 * UEB, 0.16), (0, sx * (math.degrees(NEIG) - 5), 0))
    ex = sx * (B / 2 + UEB - 0.05)
    ez = FIRST - (B / 2 + UEB) * TAN + 0.15
    h.zyl("Metall", (ex + sx * 0.3, -(T / 2 + UEB), ez - 0.25), (ex + sx * 0.3, T / 2 + UEB, ez - 0.25), 0.24)
    h.zyl("Metall", (ex + sx * 0.3, -(T / 2 + 0.3), ez - 0.3), (ex + sx * 0.3, -(T / 2 + 0.3), 0.4), 0.14)
    for sy in (-1, 1):   # Ortgangbretter
        h.box("Rahmen", (sx * d, sy * (T / 2 + UEB - 0.1), FIRST - d * TAN + 0.2), (lang, 0.22, 0.6), (0, sx * math.degrees(NEIG), 0))
h.box("Dach", (0, 0, FIRST + 0.6), (0.8, T + 2 * UEB, 0.4))
h.box("Ziegel", (-4.5, 2.5, FIRST - 1), (1.6, 1.6, 6.5))
h.box("Stein", (-4.5, 2.5, FIRST + 2.35), (2.1, 2.1, 0.3))
# Fenster mit Blumenkaesten
def blumenkasten(x, z, w, seite):
    achse, s = seite
    y = s * (T / 2 + 0.55)
    if achse != "y":
        return
    h.box("Holz", (x, y, z), (w + 0.4, 0.8, 0.6))
    farben = ["Pflanze", "Laden", "Pflanze"]
    for k in range(int(w / 0.5)):
        h.box("Pflanze", (x - w / 2 + 0.3 + k * 0.5, y, z + 0.5 + 0.1 * (k % 2)), (0.45, 0.6, 0.5), (0, 0, 25 * k))
for x in (-5.0, 5.0):
    h.fenster(x, 4.0, 3.0, 3.0, VORNE, B, T, laeden=False)
    blumenkasten(x, 2.15, 3.0, VORNE)
h.fenster(0, H + 2.6, 2.2, 2.4, VORNE, B, T)                 # Giebelfenster
for x in (-5, 0, 5):
    h.fenster(x, 4.0, 2.6, 3.0, HINTEN, B, T)
for s in (LINKS, RECHTS):
    for u in (-3.5, 3.5):
        h.fenster(u, 4.0, 2.6, 3.0, s, B, T)
# Haustuer (gruen) mit Oberlicht
h.tuer(0, -T / 2, breite=3.0, hoehe=5.4, unten=1.2, farbe="Laden", rahmen="Rahmen")
# Veranda: Holzboden, Pfosten, Gelaender, Pultdach, Stufen
VT = 4.0
vy0, vy1 = -T / 2 - VT, -T / 2
vm = (vy0 + vy1) / 2
h.box("Holz", (0, vm, 1.0), (B - 1, VT, 0.3))
for k in range(9):
    h.box("Dunkel", (0, vy0 + 0.2 + k * VT / 9, 1.16), (B - 1.1, 0.03, 0.02))
for x in (-B / 2 + 0.8, -2.2, 2.2, B / 2 - 0.8):
    h.box("Rahmen", (x, vy0 + 0.3, 3.9), (0.4, 0.4, 5.6))
for sx in (-1, 1):                     # Gelaender links/rechts der Stufen
    x0, x1 = sx * 2.2, sx * (B / 2 - 0.8)
    xm, xl = (x0 + x1) / 2, abs(x1 - x0)
    h.box("Rahmen", (xm, vy0 + 0.3, 2.55), (xl, 0.2, 0.15))
    h.box("Rahmen", (xm, vy0 + 0.3, 1.35), (xl, 0.2, 0.12))
    for k in range(int(xl / 0.45)):
        h.box("Rahmen", (min(x0, x1) + 0.3 + k * 0.45, vy0 + 0.3, 1.95), (0.1, 0.1, 1.1))
    h.box("Rahmen", (sx * (B / 2 - 0.8), vm, 2.55), (0.2, VT, 0.15))
h.box("Rahmen", (0, vm, 6.7), (B, VT + 0.6, 0.25), (-10, 0, 0))
h.box("Dach", (0, vm - 0.05, 6.9), (B + 0.3, VT + 0.9, 0.15), (-10, 0, 0))
for k in range(2):
    h.box("Stein", (0, vy0 - 0.5 - k * 0.7, 0.75 - k * 0.35), (3.6, 0.8, 0.35))
# Bank und Laterne auf der Veranda
h.box("Holz", (-5, vm + 0.6, 1.75), (3.0, 0.9, 0.12))
h.box("Holz", (-5, vm + 1.0, 2.3), (3.0, 0.12, 1.0))
for x in (-6.3, -3.7):
    h.box("Dunkel", (x, vm + 0.6, 1.4), (0.15, 0.8, 0.6))
h.box("Metall", (2.6, -T / 2 - 0.25, 5.4), (0.45, 0.35, 0.7))
result = h.bauen()
