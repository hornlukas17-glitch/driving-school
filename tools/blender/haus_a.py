# Haus A "Classic" fuer Crazy Driving School – laeuft in Blender (MCP execute_blender_code).
# Masse in Studs (1 Blender-Einheit = 1 Stud). Blender: Z oben, Vorderseite (Haustuer) = -Y.
# Grundflaeche wie im Spiel: Koerper 20 x 16, Wand 12 hoch (2 Stockwerke). Eigenes Design.
import bpy, bmesh, math
from mathutils import Matrix, Vector, Euler

NAME = "HausA"
col = bpy.data.collections.get("Haus_A") or bpy.data.collections.new("Haus_A")
if col.name not in bpy.context.scene.collection.children:
    bpy.context.scene.collection.children.link(col)
for o in list(col.objects):
    bpy.data.objects.remove(o, do_unlink=True)
if "Cube" in bpy.data.objects:          # Standard-Wuerfel nur ausblenden
    bpy.data.objects["Cube"].hide_set(True)
    bpy.data.objects["Cube"].hide_render = True

FARBEN = {
    "Wand": (0.93, 0.87, 0.74), "Sockel": (0.42, 0.41, 0.40), "Dach": (0.42, 0.12, 0.09),
    "Rahmen": (0.96, 0.96, 0.94), "Glas": (0.08, 0.13, 0.19), "Tuer": (0.30, 0.16, 0.08),
    "Laden": (0.22, 0.36, 0.30), "Metall": (0.26, 0.27, 0.29), "Ziegel": (0.50, 0.23, 0.16),
    "Stein": (0.68, 0.66, 0.62),
}

def mat(name):
    m = bpy.data.materials.get("H_" + name) or bpy.data.materials.new("H_" + name)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    c = FARBEN[name]
    b.inputs["Base Color"].default_value = (*c, 1)
    b.inputs["Roughness"].default_value = {"Glas": 0.08, "Metall": 0.4, "Rahmen": 0.45}.get(name, 0.85)
    b.inputs["Metallic"].default_value = {"Glas": 0.2, "Metall": 0.6}.get(name, 0.0)
    m.diffuse_color = (*c, 1)
    return m

G = {}
def box(g, mitte, gr, dreh=(0, 0, 0)):
    G.setdefault(g, []).append(("box", Vector(mitte), Vector(gr), Euler([math.radians(a) for a in dreh])))
def giebel(g, x0, x1, pts_yz):
    G.setdefault(g, []).append(("giebel", x0, x1, pts_yz))
def zyl(g, a, b, r, n=10):
    G.setdefault(g, []).append(("zyl", Vector(a), Vector(b), r, n))

def bauen():
    for g, teile in G.items():
        bm = bmesh.new()
        for t in teile:
            if t[0] == "box":
                _, m, s, e = t
                r = bmesh.ops.create_cube(bm, size=1.0)
                M = Matrix.Translation(m) @ e.to_matrix().to_4x4() @ Matrix.Diagonal((*s, 1))
                bmesh.ops.transform(bm, matrix=M, verts=r["verts"])
            elif t[0] == "giebel":
                _, x0, x1, pts = t
                a = [bm.verts.new((x0, y, z)) for y, z in pts]
                b = [bm.verts.new((x1, y, z)) for y, z in pts]
                bm.faces.new(a); bm.faces.new(b[::-1])
                for i in range(len(pts)):
                    j = (i + 1) % len(pts)
                    bm.faces.new((a[i], b[i], b[j], a[j]))
            elif t[0] == "zyl":
                _, a, b, rad, n = t
                d = b - a
                r = bmesh.ops.create_cone(bm, cap_ends=True, segments=n, radius1=rad, radius2=rad, depth=d.length)
                rot = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix().to_4x4()
                bmesh.ops.transform(bm, matrix=Matrix.Translation((a + b) / 2) @ rot, verts=r["verts"])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        me = bpy.data.meshes.new(NAME + "_" + g)
        bm.to_mesh(me); bm.free()
        ob = bpy.data.objects.new(NAME + "_" + g, me)
        ob.data.materials.append(mat(g))
        col.objects.link(ob)

# ---------------- Masse ----------------
B, T, H = 20.0, 16.0, 12.0
NEIG = math.radians(35)
TAN = math.tan(NEIG)
FIRST = H + (T / 2) * TAN
UEB = 1.1

# Sockel, Waende, Gesimse, Eckleisten
box("Sockel", (0, 0, 0.5), (B + 0.5, T + 0.5, 1.0))
box("Wand", (0, 0, 1 + (H - 1) / 2), (B, T, H - 1))
box("Rahmen", (0, 0, 6.3), (B + 0.3, T + 0.3, 0.35))
box("Rahmen", (0, 0, H - 0.15), (B + 0.4, T + 0.4, 0.4))
for sx in (-1, 1):
    for sy in (-1, 1):
        box("Rahmen", (sx * (B / 2 - 0.05), sy * (T / 2 - 0.05), 1 + (H - 1) / 2), (0.55, 0.55, H - 1))
# Giebeldreiecke
for sx in (-1, 1):
    giebel("Wand", sx * (B / 2 - 0.5), sx * B / 2, [(-T / 2, H), (T / 2, H), (0, FIRST)])

# Dach: Platte + 12 Ziegelreihen je Seite, Traufbrett, Rinne, Fallrohre
lang = (T / 2 + UEB) / math.cos(NEIG)
for sy in (-1, 1):
    d = (T / 2 + UEB) / 2
    box("Dach", (0, sy * d, FIRST - d * TAN + 0.3), (B + 2 * UEB, lang, 0.4), (-sy * math.degrees(NEIG), 0, 0))
    n = 12
    for i in range(n):
        dd = (i + 0.55) / n * (T / 2 + UEB)
        box("Dach", (0, sy * dd, FIRST - dd * TAN + 0.58), (B + 2 * UEB, lang / n * 0.98, 0.16),
            (-sy * (math.degrees(NEIG) - 5), 0, 0))
    ey = sy * (T / 2 + UEB - 0.05)
    ez = FIRST - (T / 2 + UEB) * TAN + 0.15
    box("Rahmen", (0, ey, ez), (B + 2 * UEB, 0.22, 0.55))
    zyl("Metall", (-(B / 2 + UEB), ey + sy * 0.32, ez - 0.25), (B / 2 + UEB, ey + sy * 0.32, ez - 0.25), 0.26)
    for sx in (-1, 1):
        x = sx * (B / 2 + 0.45)
        zyl("Metall", (x, ey + sy * 0.32, ez - 0.3), (x, sy * (T / 2 + 0.3), ez - 1.3), 0.15)
        zyl("Metall", (x, sy * (T / 2 + 0.3), ez - 1.3), (x, sy * (T / 2 + 0.3), 0.4), 0.15)
box("Dach", (0, 0, FIRST + 0.62), (B + 2 * UEB, 0.8, 0.4))          # Firstkappe
for sx in (-1, 1):                                                  # Ortgangbretter
    for sy in (-1, 1):
        d = (T / 2 + UEB) / 2
        box("Rahmen", (sx * (B / 2 + UEB - 0.1), sy * d, FIRST - d * TAN + 0.2), (0.22, lang, 0.65), (-sy * math.degrees(NEIG), 0, 0))
# Schornstein mit Kappe
box("Ziegel", (5.5, 2.6, FIRST - 0.2), (1.8, 1.8, 6.4))
box("Stein", (5.5, 2.6, FIRST + 3.05), (2.3, 2.3, 0.35))

# ---------------- Fenster ----------------
def fenster(x, z, w, h, seite, laeden=False, sprossen=True):
    """seite: (achse, vorzeichen) -> Wand bei y=+-T/2 (achse 'y') oder x=+-B/2 (achse 'x')"""
    achse, s = seite
    def p(u, v, tiefe):       # u = entlang der Wand, v = Hoehe, tiefe = nach aussen
        if achse == "y":
            return (u, s * (T / 2 + tiefe), v)
        return (s * (B / 2 + tiefe), u, v)
    def g(gw, gh, gd):
        return (gw, gd, gh) if achse == "y" else (gd, gw, gh)
    box("Glas", p(x, z, 0.02), g(w - 0.3, h - 0.3, 0.1))
    f = 0.28
    box("Rahmen", p(x, z + h / 2, 0.12), g(w + 0.2, f, 0.3))
    box("Rahmen", p(x, z - h / 2, 0.12), g(w + 0.2, f, 0.3))
    box("Rahmen", p(x - w / 2, z, 0.12), g(f, h, 0.3))
    box("Rahmen", p(x + w / 2, z, 0.12), g(f, h, 0.3))
    if sprossen:
        box("Rahmen", p(x, z, 0.1), g(0.14, h, 0.16))
        box("Rahmen", p(x, z + h * 0.12, 0.1), g(w, 0.14, 0.16))
    box("Stein", p(x, z - h / 2 - 0.25, 0.3), g(w + 0.7, 0.22, 0.6))      # Fensterbank
    box("Rahmen", p(x, z + h / 2 + 0.3, 0.12), g(w + 0.6, 0.35, 0.25))   # Sturz
    if laeden:
        for su in (-1, 1):
            lx = x + su * (w / 2 + 0.85)
            box("Laden", p(lx, z, 0.18), g(1.45, h + 0.2, 0.18))
            for k in range(6):
                box("Laden", p(lx, z - h / 2 + 0.45 + k * (h - 0.6) / 5, 0.3), g(1.25, 0.12, 0.1))

VORNE, HINTEN, LINKS, RECHTS = ("y", -1), ("y", 1), ("x", -1), ("x", 1)
for x in (-6.3, 6.3):
    fenster(x, 3.9, 3.4, 3.6, VORNE, laeden=True)
for x in (-6.3, 0, 6.3):
    fenster(x, 9.2, 3.0, 3.2, VORNE, laeden=(x != 0))
for x in (-6, 0, 6):
    fenster(x, 3.9, 3.2, 3.4, HINTEN)
    fenster(x, 9.2, 3.0, 3.2, HINTEN)
for s in (LINKS, RECHTS):
    for u in (-4, 4):
        fenster(u, 3.9, 3.0, 3.4, s)
        fenster(u, 9.2, 2.8, 3.0, s)
    fenster(0, H + 2.4, 1.8, 1.8, s, sprossen=True)   # kleines Giebelfenster

# ---------------- Haustuer mit Vordach und Stufen ----------------
ty = -T / 2
box("Tuer", (0, ty - 0.08, 4.4), (3.4, 0.2, 6.8))
for k in range(3):                                   # Kassetten
    box("Tuer", (0, ty - 0.2, 2.0 + k * 2.0), (2.4, 0.08, 1.5))
box("Glas", (0, ty - 0.2, 7.2), (2.4, 0.06, 0.9))     # Oberlicht
box("Rahmen", (0, ty - 0.18, 7.95), (4.2, 0.35, 0.4))
for sx in (-1, 1):
    box("Rahmen", (sx * 1.9, ty - 0.18, 4.4), (0.4, 0.35, 7.2))
box("Metall", (1.15, ty - 0.35, 4.3), (0.15, 0.15, 0.9))   # Griff
# Vordach auf Konsolen
box("Rahmen", (0, ty - 1.1, 8.75), (5.6, 2.4, 0.3), (8, 0, 0))
box("Dach", (0, ty - 1.1, 8.98), (5.8, 2.5, 0.18), (8, 0, 0))
for sx in (-1, 1):
    box("Rahmen", (sx * 2.4, ty - 0.55, 8.1), (0.3, 1.1, 0.3), (45, 0, 0))
# Stufen + Aussenlampe
box("Stein", (0, ty - 1.4, 0.75), (5.0, 2.6, 0.5))
box("Stein", (0, ty - 1.0, 1.1), (4.4, 1.8, 0.3))
for sx in (-1, 1):
    box("Metall", (sx * 2.7, ty - 0.25, 6.2), (0.5, 0.4, 0.8))

bauen()
alle = [o for o in col.objects]
tris = sum(len(o.data.polygons) for o in alle)
result = {"objekte": [o.name for o in alle], "flaechen": tris, "first": round(FIRST, 2)}
