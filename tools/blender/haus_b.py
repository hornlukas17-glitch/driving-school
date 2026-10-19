# Haus B "Modern": Flachdach, auskragendes Obergeschoss mit Holzlatten, Dachterrasse mit Glasgelaender.
# Braucht den Blender-Text "haus_lib" (tools/blender/haus_lib.py). Grundflaeche 20 x 16 wie im Spiel.
import bpy
exec(bpy.data.texts["haus_lib"].as_string())
h = Haus("HausB", "Haus_B", versatz=(32, 0, 0))
B, T = 20.0, 16.0
h.box("Stein", (0, 0, 0.3), (B + 0.3, T + 0.3, 0.6))
h.box("Wand", (0, 0, 0.6 + 3.1), (B, T, 6.2))
OX, OB, OT = -2.5, 15.0, 17.5            # Obergeschoss, vorne 1,5 auskragend
oy = -(OT - T) / 2
h.box("Wand", (OX, oy, 6.8 + 2.8), (OB, OT, 5.6))
h.box("Dunkel", (OX, oy, 6.75), (OB + 0.1, OT + 0.1, 0.12))
fy = oy - OT / 2
FB0, FB1 = OX - 4.6, OX + 4.6           # Fensterband in der Holzfront
for i in range(29):
    x = OX - OB / 2 + 0.25 + i * (OB - 0.5) / 28
    if FB0 - 0.2 < x < FB1 + 0.2:
        for z0, z1 in ((7.0, 8.2), (11.0, 12.3)):
            h.box("Holz", (x, fy - 0.12, (z0 + z1) / 2), (0.32, 0.22, z1 - z0))
    else:
        h.box("Holz", (x, fy - 0.12, 9.6), (0.32, 0.22, 5.4))
h.box("Dunkel", (OX, fy - 0.02, 9.6), (OB, 0.05, 5.4))
h.fenster(OX, 9.6, FB1 - FB0, 2.6, ("y", -1), B, -2 * fy + 0.1, sprossen=False, rahmen="Dunkel", bank=False)

def attika(cx, cy, b, t, z):
    for sx in (-1, 1):
        h.box("Wand", (cx + sx * (b / 2 - 0.25), cy, z + 0.5), (0.5, t, 1.0))
        h.box("Metall", (cx + sx * (b / 2 - 0.25), cy, z + 1.05), (0.7, t + 0.2, 0.1))
    for sy in (-1, 1):
        h.box("Wand", (cx, cy + sy * (t / 2 - 0.25), z + 0.5), (b, 0.5, 1.0))
        h.box("Metall", (cx, cy + sy * (t / 2 - 0.25), z + 1.05), (b + 0.2, 0.7, 0.1))
    h.box("Dunkel", (cx, cy, z + 0.1), (b - 0.6, t - 0.6, 0.2))
attika(OX, oy, OB, OT, 12.4)
tx0, tx1 = OX + OB / 2, B / 2          # Dachterrasse
tb = tx1 - tx0
h.box("Stein", ((tx0 + tx1) / 2, 0, 6.85), (tb, T, 0.1))
for sy in (-1, 1):
    h.box("Glas", ((tx0 + tx1) / 2, sy * (T / 2 - 0.15), 7.6), (tb, 0.08, 1.4))
    h.box("Metall", ((tx0 + tx1) / 2, sy * (T / 2 - 0.15), 8.33), (tb, 0.18, 0.08))
h.box("Glas", (tx1 - 0.15, 0, 7.6), (0.08, T, 1.4))
h.box("Metall", (tx1 - 0.15, 0, 8.33), (0.18, T, 0.08))

def gross(x, z, w, hh, seite, b=B, t=T):
    h.fenster(x, z, w, hh, seite, b, t, sprossen=False, rahmen="Dunkel", bank=False)
gross(-4.5, 3.4, 8.0, 4.6, VORNE)
for x in (-6, 0, 6):
    gross(x, 3.4, 3.6, 4.2, HINTEN)
for x in (-7, 2):
    gross(x, 9.6, 3.6, 3.0, HINTEN, t=T)
for s in (LINKS, RECHTS):
    gross(-3, 3.4, 4.5, 3.0, s)
    gross(4, 3.4, 2.4, 3.0, s)
h.fenster(-3, 9.6, 4.5, 2.4, LINKS, B, T, sprossen=False, rahmen="Dunkel", bank=False)
h.tuer(5.2, -T / 2, breite=3.0, hoehe=6.4, unten=0.6, farbe="Holz", rahmen="Dunkel")
h.box("Dunkel", (5.6, -T / 2 - 1.2, 7.5), (5.8, 2.6, 0.25))
h.box("Glas", (7.6, -T / 2 - 0.05, 3.6), (1.0, 0.08, 6.0))
h.box("Metall", (3.2, -T / 2 - 0.12, 5.6), (0.7, 0.06, 0.9))
h.box("Rahmen", (3.2, -T / 2 - 0.16, 4.6), (0.35, 0.1, 0.35))
for x in (-8.0, -1.0):                  # Pflanzkuebel mit Graesern
    h.box("Stein", (x, -T / 2 - 1.2, 0.6), (3.4, 1.2, 1.2))
    h.box("Dunkel", (x, -T / 2 - 1.2, 1.18), (3.1, 0.9, 0.06))
    for k in range(9):
        h.box("Pflanze", (x - 1.3 + k * 0.33, -T / 2 - 1.2 + (0.2 if k % 2 else -0.2), 1.9), (0.12, 0.12, 1.4 + 0.3 * (k % 3)), ((k % 3 - 1) * 12, (k % 2 - 0.5) * 16, 0))
h.zyl("Metall", (B / 2 + 0.2, T / 2 - 0.4, 6.9), (B / 2 + 0.2, T / 2 - 0.4, 0.3), 0.14)
result = h.bauen()
