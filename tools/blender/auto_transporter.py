# Transporter (eigenes Design, Kastenwagen), 17 x 7.2 Studs wie Verkehr.ARTEN.transporter. Front = -Y.
import bpy, math
exec(bpy.data.texts["auto_lib"].as_string())
exec(bpy.data.texts["auto_pkw"].as_string())
a = Auto("Auto_Transporter", versatz=(48, -40, 0))


def extra(a, P):
    for sx in (-1, 1):
        a.box("Akzent", (sx * 3.6, 2.6, 4.7), (0.05, 9.5, 0.7))              # Firmenstreifen
        a.box("Schwarz", (sx * 3.62, 2.4, 5.3), (0.03, 0.06, 3.3))           # Schiebetür hinten
        a.box("Schwarz", (sx * 3.62, 4.9, 6.9), (0.04, 5.0, 0.05))           # Schiene
    a.box("Schwarz", (0, 8.56, 5.3), (0.05, 0.05, 3.4))                       # Hecktüren-Fuge
    for sx in (-1, 1):
        a.box("Chrom", (sx * 0.35, 8.58, 4.8), (0.12, 0.05, 0.6))


pkw(a, {
    "R": 1.35, "spur": 2.95, "radbreite": 1.1, "achsen": (-5.3, 5.6), "zu": 0.8,
    "oben": [(-8.5, 3.1, 3.2), (-8.3, 3.4, 3.5), (-7.4, 3.55, 3.7), (-6.4, 3.6, 3.8), (8.3, 3.6, 3.8), (8.5, 3.5, 3.6)],
    "glas": [(-6.5, 3.5, 3.75), (-5.4, 3.5, 5.6), (-4.6, 3.55, 6.9), (-3.8, 3.55, 7.2), (8.3, 3.55, 7.2), (8.55, 3.5, 7.0)],
    "glas_unten": 3.6, "fenster": [(-6.5, -3.4)],
    "dach": [-4.0, -3.8, 0.0, 4.0, 8.3, 8.5], "fugen": [-3.3, 8.0], "griffe": [-2.7], "spiegel_y": -5.6,
    "expo": 7, "glas_expo": 9, "licht_z": 2.9, "rueck_z": 3.4, "extra": extra,
})
result = a.bauen()
