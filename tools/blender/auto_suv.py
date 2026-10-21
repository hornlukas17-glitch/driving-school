# SUV (eigenes Design), 15 x 7.2 Studs wie Verkehr.ARTEN.suv. Hoch, große Räder, Dachreling. Front = -Y.
import bpy, math
exec(bpy.data.texts["auto_lib"].as_string())
exec(bpy.data.texts["auto_pkw"].as_string())
a = Auto("Auto_SUV", versatz=(32, -40, 0))


def extra(a, P):
    for sx in (-1, 1):
        a.box("Schwarz", (sx * 2.7, 2.6, 6.35), (0.18, 8.2, 0.16))           # Dachreling
        for y in (-1.2, 2.6, 6.4):
            a.box("Schwarz", (sx * 2.7, y, 6.2), (0.18, 0.3, 0.3))
        a.box("Schwarz", (sx * 3.62, 0.0, 1.35), (0.08, 5.2, 0.5))           # Kunststoff-Beplankung
    a.box("Akzent", (0, -7.55, 1.25), (3.2, 0.12, 0.35))                     # Unterfahrschutz vorne
    a.box("Akzent", (0, 7.55, 1.3), (3.2, 0.12, 0.35))
    a.zyl("Schwarz", (0, 7.65, 3.0), 1.1, 0.35, n=20, achse="y")             # Reserverad hinten
    a.zyl("Felge", (0, 7.85, 3.0), 0.6, 0.06, n=16, achse="y")


pkw(a, {
    "R": 1.5, "spur": 2.95, "radbreite": 1.2, "achsen": (-4.6, 4.6), "zu": 1.0, "bogen": 0.4,
    "oben": [(-7.5, 3.1, 3.4), (-7.3, 3.4, 3.7), (-6.6, 3.55, 3.95), (-4.0, 3.6, 4.1), (0.0, 3.6, 4.2),
             (5.5, 3.6, 4.2), (7.0, 3.55, 4.15), (7.4, 3.4, 4.0), (7.5, 3.2, 3.7)],
    "glas": [(-3.2, 3.35, 4.1), (-2.0, 3.25, 5.0), (-1.2, 3.2, 5.9), (-0.4, 3.15, 6.1), (5.6, 3.15, 6.1),
             (6.6, 3.2, 5.9), (7.15, 3.3, 4.6)],
    "glas_unten": 4.0, "fenster": [(-3.2, 1.2), (1.5, 4.4), (4.7, 6.2), (6.3, 7.15)],
    "dach": [-0.5, -0.2, 1.0, 3.0, 5.0, 5.8, 6.5], "fugen": [-3.0, 1.3, 4.5], "griffe": [0.6, 3.7], "spiegel_y": -2.6,
    "expo": 6, "glas_expo": 7, "extra": extra,
})
result = a.bauen()
