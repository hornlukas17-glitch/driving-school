# Bausteine fuer die Alltagsautos (NPC-Verkehr + geparkte Autos). Laeuft in Blender (Text "auto_lib").
# Masse in Studs. Blender: Z oben, Fahrzeugfront = -Y, Mitte der Hinterachse/Vorderachse auf y = +-radstand/2.
import bpy, bmesh, math
from mathutils import Matrix, Vector, Euler

FARBEN = {
    "Lack": (0.55, 0.06, 0.07), "Glas": (0.04, 0.06, 0.08), "Schwarz": (0.03, 0.03, 0.035),
    "Reifen": (0.02, 0.02, 0.022), "Felge": (0.62, 0.63, 0.66), "Licht": (0.95, 0.95, 0.9),
    "Ruecklicht": (0.6, 0.03, 0.03), "Blinker": (0.9, 0.45, 0.05), "Chrom": (0.8, 0.8, 0.82),
    "Kennzeichen": (0.92, 0.92, 0.9), "Innen": (0.08, 0.08, 0.09),
}
RAUH = {"Lack": 0.25, "Glas": 0.05, "Chrom": 0.15, "Felge": 0.3, "Licht": 0.1, "Ruecklicht": 0.2}
MET = {"Lack": 0.4, "Chrom": 1.0, "Felge": 0.9}


def mat(name):
    m = bpy.data.materials.get("A_" + name) or bpy.data.materials.new("A_" + name)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    c = FARBEN[name]
    b.inputs["Base Color"].default_value = (*c, 1)
    b.inputs["Roughness"].default_value = RAUH.get(name, 0.6)
    b.inputs["Metallic"].default_value = MET.get(name, 0.0)
    m.diffuse_color = (*c, 1)
    return m


def superellipse(n_pkt, hw, zu, zo, expo):
    """Querschnitt als Superellipse: hw = halbe Breite, zu/zo = unten/oben. Gibt Punkte (x, z) zurueck."""
    zc, hh = (zu + zo) / 2, (zo - zu) / 2
    pts = []
    for i in range(n_pkt):
        t = 2 * math.pi * i / n_pkt
        c, s = math.cos(t), math.sin(t)
        x = hw * math.copysign(abs(c) ** (2 / expo), c)
        z = zc + hh * math.copysign(abs(s) ** (2 / expo), s)
        pts.append((x, z))
    return pts


class Auto:
    def __init__(self, name, versatz=(0, 0, 0)):
        self.name = name
        self.col = bpy.data.collections.get(name) or bpy.data.collections.new(name)
        if self.col.name not in bpy.context.scene.collection.children:
            bpy.context.scene.collection.children.link(self.col)
        for o in list(self.col.objects):
            bpy.data.objects.remove(o, do_unlink=True)
        self.bm = {}
        self.versatz = Vector(versatz)

    def _bm(self, g):
        if g not in self.bm:
            self.bm[g] = bmesh.new()
        return self.bm[g]

    def loft(self, g, schnitte, n_pkt=20, expo=4.0, glatt=True, kappen=True):
        """schnitte: Liste (y, halbe_breite, z_unten, z_oben[, expo]) von vorne nach hinten."""
        bm = self._bm(g)
        ringe = []
        for s in schnitte:
            y, hw, zu, zo = s[:4]
            e = s[4] if len(s) > 4 else expo
            ringe.append([bm.verts.new((x, y, z)) for x, z in superellipse(n_pkt, hw, zu, zo, e)])
        neue = []
        for a, b in zip(ringe, ringe[1:]):
            for i in range(n_pkt):
                j = (i + 1) % n_pkt
                neue.append(bm.faces.new((a[i], a[j], b[j], b[i])))
        if kappen:
            neue.append(bm.faces.new(ringe[0][::-1]))
            neue.append(bm.faces.new(ringe[-1]))
        for f in neue:
            f.smooth = glatt
        return neue

    def box(self, g, mitte, gr, dreh=(0, 0, 0), glatt=False):
        bm = self._bm(g)
        r = bmesh.ops.create_cube(bm, size=1.0)
        e = Euler([math.radians(a) for a in dreh])
        M = Matrix.Translation(Vector(mitte)) @ e.to_matrix().to_4x4() @ Matrix.Diagonal((*gr, 1))
        bmesh.ops.transform(bm, matrix=M, verts=r["verts"])
        for f in {f for v in r["verts"] for f in v.link_faces}:
            f.smooth = glatt

    def zyl(self, g, mitte, r, breite, n=20, achse="x", glatt=True):
        bm = self._bm(g)
        res = bmesh.ops.create_cone(bm, cap_ends=True, segments=n, radius1=r, radius2=r, depth=breite)
        rot = {"x": Matrix.Rotation(math.radians(90), 4, "Y"), "y": Matrix.Rotation(math.radians(90), 4, "X")}.get(achse, Matrix.Identity(4))
        bmesh.ops.transform(bm, matrix=Matrix.Translation(Vector(mitte)) @ rot, verts=res["verts"])
        for f in {f for v in res["verts"] for f in v.link_faces}:
            f.smooth = glatt and len(f.verts) == 4

    def rad(self, x, y, r, breite, speichen=5):
        """Reifen + Felge + Speichen; x = Mitte des Rades (Seite ueber das Vorzeichen)."""
        s = 1 if x > 0 else -1
        self.zyl("Reifen", (x, y, r), r, breite, n=24)
        self.zyl("Reifen", (x + s * breite * 0.5, y, r), r * 0.82, 0.08, n=24)   # Flanke
        self.zyl("Felge", (x + s * (breite * 0.5 + 0.02), y, r), r * 0.62, 0.06, n=20)
        self.zyl("Schwarz", (x + s * (breite * 0.5 + 0.04), y, r), r * 0.5, 0.04, n=20)
        for k in range(speichen):
            w = 360 * k / speichen
            self.box("Felge", (x + s * (breite * 0.5 + 0.06), y, r), (0.05, r * 0.95, 0.2), (w, 0, 0))
        self.zyl("Chrom", (x + s * (breite * 0.5 + 0.08), y, r), r * 0.14, 0.05, n=12)

    def radkasten(self, x_seite, y, r):
        """dunkler Radkasten auf beiden Seiten (zylindrische Aussparung)."""
        self.zyl("Schwarz", (x_seite, y, r), r + 0.3, 0.06, n=24, glatt=False)

    def bauen(self):
        objs = []
        for g, bm in self.bm.items():
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
            me = bpy.data.meshes.new(self.name + "_" + g)
            bm.to_mesh(me)
            bm.free()
            ob = bpy.data.objects.new(self.name + "_" + g, me)
            ob.data.materials.append(mat(g))
            ob.location = self.versatz
            self.col.objects.link(ob)
            objs.append(ob)
        return {"objekte": len(objs), "dreiecke": sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs)}
