# Lkw (eigenes Design, Koffer-Lkw), 26 x 8.4 Studs wie Verkehr.ARTEN.lkw. Front = -Y.
import bpy, math
exec(bpy.data.texts["auto_lib"].as_string())
exec(bpy.data.texts["auto_pkw"].as_string())
a = Auto("Auto_Lkw", versatz=(64, -40, 0))


def extra(a, P):
    # Kofferaufbau mit Kante, Streifen, Hecktüren und Unterfahrschutz
    a.box("Akzent", (0, 3.4, 7.9), (8.3, 19.0, 9.0))
    a.box("Schwarz", (0, 3.4, 3.35), (8.0, 19.0, 0.3))
    for sx in (-1, 1):
        a.box("Lack", (sx * 4.17, 3.4, 5.6), (0.05, 18.4, 1.0))
        a.box("Schwarz", (sx * 3.9, 3.0, 1.6), (0.15, 8.0, 0.8))             # Seitenschutz
        a.box("Schwarz", (sx * 3.1, -4.6, 1.8), (1.4, 1.6, 1.2))             # Tank / Kasten
    a.box("Schwarz", (0, 12.92, 7.9), (0.05, 0.05, 8.6))
    for sx in (-1, 1):
        a.box("Chrom", (sx * 0.4, 12.95, 6.5), (0.12, 0.05, 1.6))
    a.box("Schwarz", (0, 12.95, 1.4), (7.0, 0.3, 0.3))
    a.box("Lack", (0, -9.4, 10.45), (8.0, 3.0, 0.8), (6, 0, 0))              # Dachspoiler über dem Fahrerhaus


pkw(a, {
    "R": 1.8, "spur": 3.35, "radbreite": 1.5, "achsen": (-8.5, 6.4, 9.9), "zu": 1.1, "bogen": 0.35,
    "oben": [(-13.0, 4.0, 3.9), (-12.85, 4.15, 4.2), (-12.4, 4.2, 4.3), (-7.0, 4.2, 4.3), (-6.8, 3.9, 3.3), (13.0, 3.9, 3.3)],
    "glas": [(-12.85, 4.05, 4.2), (-12.6, 4.08, 7.5), (-12.3, 4.1, 9.5), (-11.6, 4.1, 10.0), (-7.2, 4.1, 10.0), (-7.0, 4.05, 9.8)],
    "glas_unten": 4.0, "fenster": [(-12.85, -11.4), (-10.9, -9.2)],
    "dach": [-11.9, -11.6, -9.0, -7.2, -7.0], "fugen": [-9.0], "griffe": [-9.6], "spiegel_y": -11.9,
    "expo": 8, "glas_expo": 10, "licht_z": 3.0, "rueck_z": 3.0, "extra": extra,
})
result = a.bauen()
