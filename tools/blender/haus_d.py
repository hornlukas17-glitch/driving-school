# Haus D "Stadthaus": schmal, 3 Geschosse, Klinker-Erdgeschoss mit Erker, Balkone mit Staebchengelaender,
# steiles Satteldach mit Gauben. Braucht den Blender-Text "haus_lib" (tools/blender/haus_lib.py).
import bpy, math
exec(bpy.data.texts["haus_lib"].as_string())
h = Haus("HausD", "Haus_D", versatz=(96, 0, 0))
B, T = 16.0, 14.0
E = 5.0                      # Geschosshoehe
H = 0.8 + 3 * E              # Traufe
NEIG = math.radians(45)
TAN = math.tan(NEIG)
FIRST = H + (T / 2) * TAN
UEB = 0.8
# Erdgeschoss Klinker, darueber Putz (terrakotta), Gesimse
h.box("Sockel", (0, 0, 0.4), (B + 0.3, T + 0.3, 0.8))
h.box("Ziegel", (0, 0, 0.8 + E / 2), (B, T, E))
h.box("Wand2", (0, 0, 0.8 + E + E), (B, T, 2 * E))
for z in (0.8 + E, 0.8 + 2 * E):
    h.box("Rahmen", (0, 0, z), (B + 0.35, T + 0.35, 0.35))
h.box("Rahmen", (0, 0, H - 0.2), (B + 0.5, T + 0.5, 0.5))
for k in range(int(B / 1.0)):              # Zahnfries unter der Traufe
    h.box("Rahmen", (-B / 2 + 0.5 + k * 1.0, -T / 2 - 0.15, H - 0.65), (0.45, 0.3, 0.35))
for sx in (-1, 1):                          # Eckquader im Putz
    for k in range(10):
        z = 0.8 + E + 0.5 + k * 1.0
        w = 0.9 if k % 2 else 0.6
        h.box("Rahmen", (sx * (B / 2 - w / 2 + 0.05), -T / 2 - 0.05, z), (w, 0.15, 0.85))
# Giebel + Dach (First entlang X)
for sx in (-1, 1):
    h.prisma_x("Wand2", sx * (B / 2 - 0.5), sx * B / 2, [(-T / 2, H), (T / 2, H), (0, FIRST)])
lang = (T / 2 + UEB) / math.cos(NEIG)
for sy in (-1, 1):
    d = (T / 2 + UEB) / 2
    h.box("Dach", (0, sy * d, FIRST - d * TAN + 0.3), (B + 2 * UEB, lang, 0.4), (-sy * math.degrees(NEIG), 0, 0))
    for i in range(13):
        dd = (i + 0.55) / 13 * (T / 2 + UEB)
        h.box("Dach", (0, sy * dd, FIRST - dd * TAN + 0.58), (B + 2 * UEB, lang / 13 * 0.98, 0.16), (-sy * (math.degrees(NEIG) - 5), 0, 0))
    ez = FIRST - (T / 2 + UEB) * TAN + 0.15
    h.zyl("Metall", (-(B / 2 + UEB), sy * (T / 2 + UEB + 0.25), ez - 0.25), (B / 2 + UEB, sy * (T / 2 + UEB + 0.25), ez - 0.25), 0.24)
h.zyl("Metall", (B / 2 + 0.4, -(T / 2 + UEB + 0.25), H - 0.2), (B / 2 + 0.4, -(T / 2 + 0.35), H - 0.8), 0.14)
h.zyl("Metall", (B / 2 + 0.4, -(T / 2 + 0.35), H - 0.8), (B / 2 + 0.4, -(T / 2 + 0.35), 0.4), 0.14)
h.box("Dach", (0, 0, FIRST + 0.6), (B + 2 * UEB, 0.8, 0.4))
# zwei Gauben vorne
for gx in (-3.8, 3.8):
    gy = -T / 2 + 2.3
    gz = H + 2.3 * TAN
    h.box("Wand2", (gx, gy - 0.6, gz + 1.0), (3.2, 2.6, 2.6))
    h.prisma_y("Dach", gy - 2.1, gy + 1.5, [(gx - 2.0, gz + 2.3), (gx + 2.0, gz + 2.3), (gx, gz + 3.6)])
    h.fenster(gx, gz + 1.0, 2.0, 1.8, ("y", -1), B, 2 * (1.9 - gy), sprossen=True, bank=False)
h.box("Ziegel", (4.5, 1.5, FIRST - 0.5), (1.6, 2.4, 5.0))
h.box("Stein", (4.5, 1.5, FIRST + 2.1), (2.0, 2.8, 0.3))
# Erker im Erdgeschoss links (dreiseitig)
ex, ew, et = -4.0, 5.0, 1.4
ey = -T / 2 - et / 2
h.box("Ziegel", (ex, ey, 1.6), (ew, et, 1.6))
h.box("Glas", (ex, ey - et / 2 + 0.05, 3.9), (ew - 0.4, 0.1, 3.0))
for xx in (ex - ew / 2 + 0.1, ex - 0.8, ex + 0.8, ex + ew / 2 - 0.1):
    h.box("Rahmen", (xx, ey - et / 2 + 0.1, 3.9), (0.25, 0.2, 3.0))
for sx in (-1, 1):
    h.box("Glas", (ex + sx * (ew / 2 - 0.05), ey, 3.9), (0.1, et - 0.3, 3.0))
h.box("Rahmen", (ex, ey, 5.55), (ew + 0.3, et + 0.3, 0.3))
h.box("Dach", (ex, ey - 0.1, 5.8), (ew + 0.4, et + 0.5, 0.2), (8, 0, 0))
# Fenster OG + Balkone vorne
for x in (-4.0, 4.0):
    h.fenster(x, 0.8 + E + 2.6, 2.4, 3.6, VORNE, B, T)
    h.fenster(x, 0.8 + 2 * E + 2.6, 2.4, 3.6, VORNE, B, T)
for z0 in (0.8 + E, 0.8 + 2 * E):          # Balkon mittig mit Glastuer
    h.box("Glas", (0, -T / 2 - 0.02, z0 + 1.9), (2.4, 0.1, 3.6))
    h.box("Rahmen", (0, -T / 2 - 0.1, z0 + 3.8), (2.8, 0.25, 0.25))
    for sx in (-1, 1):
        h.box("Rahmen", (sx * 1.3, -T / 2 - 0.1, z0 + 1.9), (0.25, 0.25, 3.8))
    by = -T / 2 - 1.0
    h.box("Stein", (0, by, z0 - 0.05), (4.6, 2.0, 0.3))
    h.box("Metall", (0, by - 0.95, z0 + 1.2), (4.6, 0.1, 0.1))
    for sx in (-1, 1):
        h.box("Metall", (sx * 2.25, by, z0 + 1.2), (0.1, 2.0, 0.1))
    for k in range(17):
        h.box("Metall", (-2.2 + k * 0.275, by - 0.95, z0 + 0.65), (0.05, 0.05, 1.0))
    for sx in (-1, 1):
        for k in range(7):
            h.box("Metall", (sx * 2.25, by - 0.9 + k * 0.28, z0 + 0.65), (0.05, 0.05, 1.0))
    h.box("Pflanze", (1.6, by - 0.4, z0 + 0.5), (0.7, 0.7, 0.7), (0, 0, 30))
# Haustuer rechts mit Oberlicht und Stufen
h.tuer(4.0, -T / 2, breite=2.8, hoehe=4.2, unten=0.8, farbe="Tuer", rahmen="Rahmen")
h.box("Glas", (4.0, -T / 2 - 0.2, 5.35), (2.6, 0.06, 0.6))
h.box("Stein", (4.0, -T / 2 - 0.9, 0.55), (3.6, 1.8, 0.5))
h.box("Metall", (2.2, -T / 2 - 0.2, 3.5), (0.5, 0.15, 0.7))     # Klingelschild
# Seiten und hinten
for s in (LINKS, RECHTS):
    for u in (-3.5, 3.5):
        for z in (0.8 + E + 2.6, 0.8 + 2 * E + 2.6):
            h.fenster(u, z, 2.0, 3.2, s, B, T)
for x in (-4.5, 0, 4.5):
    for z in (0.8 + 2.6, 0.8 + E + 2.6, 0.8 + 2 * E + 2.6):
        h.fenster(x, z, 2.2, 3.2, HINTEN, B, T)
result = h.bauen()
