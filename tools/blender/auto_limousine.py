# Limousine (eigenes Design, Stufenheck), 14.5 x 6.8 Studs wie Verkehr.ARTEN.limousine. Front = -Y, Boden z = 0.
import bpy, math
exec(bpy.data.texts["auto_lib"].as_string())
exec(bpy.data.texts["auto_pkw"].as_string())
a = Auto("Auto_Limousine", versatz=(16, -40, 0))


def extra(a, P):
    for sx in (-1, 1):
        a.box("Chrom", (sx * 3.42, 0.0, 1.25), (0.05, 5.2, 0.12))          # Chromleiste zwischen den Radläufen
    a.box("Chrom", (0, 7.2, 3.0), (3.6, 0.05, 0.1))                          # Heckleiste


pkw(a, {
    "R": 1.25, "spur": 2.8, "achsen": (-4.4, 4.4), "zu": 0.6,
    "oben": [(-7.25, 2.9, 2.9), (-7.05, 3.2, 3.1), (-6.4, 3.35, 3.25), (-4.0, 3.4, 3.4), (-2.0, 3.4, 3.5),
             (2.5, 3.4, 3.55), (5.5, 3.38, 3.6), (6.7, 3.3, 3.55), (7.1, 3.1, 3.4), (7.25, 2.85, 3.2)],
    "glas": [(-2.6, 3.1, 3.45), (-1.6, 3.0, 4.2), (-0.8, 2.92, 4.85), (0.0, 2.88, 5.05), (2.6, 2.88, 5.05),
             (3.6, 2.92, 4.7), (4.6, 3.0, 4.0), (5.2, 3.08, 3.55)],
    "glas_unten": 3.3, "fenster": [(-2.6, 1.0), (1.4, 3.2), (3.8, 5.2)],
    "dach": [-0.1, 0.2, 1.2, 2.2, 2.7, 3.2], "fugen": [-2.4, 1.2, 4.1], "griffe": [0.4, 3.0], "spiegel_y": -2.0,
    "extra": extra,
})
result = a.bauen()
