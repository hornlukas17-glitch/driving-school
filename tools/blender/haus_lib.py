# Gemeinsame Bausteine fuer die Haeuser (Blender). Wird als Text "haus_lib" in Blender abgelegt
# und von jedem Haus-Skript mit exec() geladen. Masse in Studs, Z oben, Vorderseite = -Y.
import bpy, bmesh, math
from mathutils import Matrix, Vector, Euler

FARBEN = {
    "Wand": (0.93, 0.87, 0.74), "Wand2": (0.62, 0.42, 0.30), "Sockel": (0.42, 0.41, 0.40),
    "Dach": (0.42, 0.12, 0.09), "Rahmen": (0.96, 0.96, 0.94), "Glas": (0.08, 0.13, 0.19),
    "Tuer": (0.30, 0.16, 0.08), "Laden": (0.22, 0.36, 0.30), "Metall": (0.26, 0.27, 0.29),
    "Ziegel": (0.50, 0.23, 0.16), "Stein": (0.68, 0.66, 0.62), "Holz": (0.55, 0.38, 0.22),
    "Dunkel": (0.12, 0.12, 0.13), "Pflanze": (0.22, 0.40, 0.16),
}
RAUH = {"Glas": 0.08, "Metall": 0.4, "Rahmen": 0.45, "Dunkel": 0.5}
METALL = {"Glas": 0.2, "Metall": 0.6}


def mat(name):
    m = bpy.data.materials.get("H_" + name) or bpy.data.materials.new("H_" + name)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    c = FARBEN[name]
    b.inputs["Base Color"].default_value = (*c, 1)
    b.inputs["Roughness"].default_value = RAUH.get(name, 0.85)
    b.inputs["Metallic"].default_value = METALL.get(name, 0.0)
    m.diffuse_color = (*c, 1)
    return m


class Haus:
    def __init__(self, name, sammlung, versatz=(0, 0, 0)):
        self.name, self.G = name, {}
        self.col = bpy.data.collections.get(sammlung) or bpy.data.collections.new(sammlung)
        if self.col.name not in bpy.context.scene.collection.children:
            bpy.context.scene.collection.children.link(self.col)
        for o in list(self.col.objects):
            bpy.data.objects.remove(o, do_unlink=True)
        self.versatz = Vector(versatz)

    # ---- Grundformen ----
    def box(self, g, mitte, gr, dreh=(0, 0, 0)):
        self.G.setdefault(g, []).append(("box", Vector(mitte), Vector(gr), Euler([math.radians(a) for a in dreh])))

    def prisma_x(self, g, x0, x1, pts_yz):
        # Polygon in der Y/Z-Ebene, von x0 bis x1 (Giebel, Dachkoerper)
        self.G.setdefault(g, []).append(("px", x0, x1, pts_yz))

    def prisma_y(self, g, y0, y1, pts_xz):
        self.G.setdefault(g, []).append(("py", y0, y1, pts_xz))

    def zyl(self, g, a, b, r, n=10):
        self.G.setdefault(g, []).append(("zyl", Vector(a), Vector(b), r, n))

    def walm(self, g, b, t, z0, hoehe, first_laenge, dicke=0.4):
        # Walmdach: Grundriss b x t auf Hoehe z0, First der Laenge first_laenge entlang X
        self.G.setdefault(g, []).append(("walm", b, t, z0, hoehe, first_laenge, dicke))

    # ---- Bauteile ----
    def fenster(self, x, z, w, h, seite, B, T, laeden=False, sprossen=True, rahmen="Rahmen", bank=True):
        achse, s = seite
        def p(u, v, tiefe):
            return (u, s * (T / 2 + tiefe), v) if achse == "y" else (s * (B / 2 + tiefe), u, v)
        def gr(gw, gh, gd):
            return (gw, gd, gh) if achse == "y" else (gd, gw, gh)
        self.box("Glas", p(x, z, 0.02), gr(w - 0.3, h - 0.3, 0.1))
        f = 0.28
        self.box(rahmen, p(x, z + h / 2, 0.12), gr(w + 0.2, f, 0.3))
        self.box(rahmen, p(x, z - h / 2, 0.12), gr(w + 0.2, f, 0.3))
        self.box(rahmen, p(x - w / 2, z, 0.12), gr(f, h, 0.3))
        self.box(rahmen, p(x + w / 2, z, 0.12), gr(f, h, 0.3))
        if sprossen:
            self.box(rahmen, p(x, z, 0.1), gr(0.14, h, 0.16))
            self.box(rahmen, p(x, z + h * 0.12, 0.1), gr(w, 0.14, 0.16))
        if bank:
            self.box("Stein", p(x, z - h / 2 - 0.25, 0.3), gr(w + 0.7, 0.22, 0.6))
        if laeden:
            for su in (-1, 1):
                lx = x + su * (w / 2 + 0.85)
                self.box("Laden", p(lx, z, 0.18), gr(1.45, h + 0.2, 0.18))
                for k in range(6):
                    self.box("Laden", p(lx, z - h / 2 + 0.45 + k * (h - 0.6) / 5, 0.3), gr(1.25, 0.12, 0.1))

    def tuer(self, x, y_wand, breite=3.4, hoehe=6.8, unten=1.0, farbe="Tuer", rahmen="Rahmen"):
        ty = y_wand
        zc = unten + hoehe / 2
        self.box(farbe, (x, ty - 0.08, zc), (breite, 0.2, hoehe))
        for k in range(3):
            self.box(farbe, (x, ty - 0.2, unten + 1.0 + k * (hoehe - 2.2) / 2.2 * 0.95), (breite - 1.0, 0.08, 1.4))
        self.box(rahmen, (x, ty - 0.18, unten + hoehe + 0.2), (breite + 0.8, 0.35, 0.4))
        for sx in (-1, 1):
            self.box(rahmen, (x + sx * (breite / 2 + 0.2), ty - 0.18, zc), (0.4, 0.35, hoehe + 0.4))
        self.box("Metall", (x + breite / 2 - 0.55, ty - 0.35, unten + hoehe * 0.48), (0.15, 0.15, 0.9))

    # ---- Ausgabe ----
    def bauen(self):
        objekte = []
        for g, teile in self.G.items():
            bm = bmesh.new()
            for t in teile:
                if t[0] == "box":
                    _, m, s, e = t
                    r = bmesh.ops.create_cube(bm, size=1.0)
                    M = Matrix.Translation(m) @ e.to_matrix().to_4x4() @ Matrix.Diagonal((*s, 1))
                    bmesh.ops.transform(bm, matrix=M, verts=r["verts"])
                elif t[0] in ("px", "py"):
                    _, a0, a1, pts = t
                    if t[0] == "px":
                        a = [bm.verts.new((a0, u, v)) for u, v in pts]
                        b = [bm.verts.new((a1, u, v)) for u, v in pts]
                    else:
                        a = [bm.verts.new((u, a0, v)) for u, v in pts]
                        b = [bm.verts.new((u, a1, v)) for u, v in pts]
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
                elif t[0] == "walm":
                    _, B, T, z0, hh, fl, dk = t
                    unten = [(-B / 2, -T / 2, z0), (B / 2, -T / 2, z0), (B / 2, T / 2, z0), (-B / 2, T / 2, z0)]
                    oben = [(-fl / 2, 0, z0 + hh), (fl / 2, 0, z0 + hh)]
                    v = [bm.verts.new(p) for p in unten] + [bm.verts.new(p) for p in oben]
                    bm.faces.new((v[0], v[1], v[5], v[4]))      # vorne
                    bm.faces.new((v[2], v[3], v[4], v[5]))      # hinten
                    bm.faces.new((v[1], v[2], v[5]))            # rechts
                    bm.faces.new((v[3], v[0], v[4]))            # links
                    bm.faces.new((v[3], v[2], v[1], v[0]))      # Boden
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
            me = bpy.data.meshes.new(self.name + "_" + g)
            bm.to_mesh(me); bm.free()
            ob = bpy.data.objects.new(self.name + "_" + g, me)
            ob.data.materials.append(mat(g))
            ob.location = self.versatz
            self.col.objects.link(ob)
            objekte.append(ob)
        return {"objekte": len(objekte), "flaechen": sum(len(o.data.polygons) for o in objekte)}


VORNE, HINTEN, LINKS, RECHTS = ("y", -1), ("y", 1), ("x", -1), ("x", 1)
