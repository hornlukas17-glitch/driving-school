"""Baut ein Blender-Hausskript (haus_a.py / haus_b.py) als Roblox-Teile nach (Luau-Code fuer Studio).

python3 tools/blender/nach_roblox.py haus_b.py <x> <z> <gier_grad> <name>  >  ausgabe.lua

Laeuft ohne Blender: bpy/bmesh werden durch Attrappen ersetzt, die Skripte sammeln nur ihre Grundformen.
Koordinaten: Blender (x, y, z), Z oben, Front -Y  ->  Roblox (x, z, -y), Front +Z (wie die Haeuser im Generator).
"""
import sys, os, math, types
from unittest import mock
import numpy as np

HIER = os.path.dirname(os.path.abspath(__file__))


class Vec(tuple):
    def __new__(cls, v): return tuple.__new__(cls, [float(a) for a in v])


def lade(skript):
    mu = types.ModuleType("mathutils")
    mu.Vector, mu.Euler, mu.Matrix = Vec, (lambda v: tuple(float(a) for a in v)), mock.MagicMock()
    sys.modules["mathutils"] = mu
    sys.modules["bpy"] = mock.MagicMock()
    sys.modules["bmesh"] = mock.MagicMock()
    lib = open(os.path.join(HIER, "haus_lib.py")).read()
    src = open(os.path.join(HIER, skript)).read()
    src = src.replace('exec(bpy.data.texts["haus_lib"].as_string())', lib)
    for ende in ("\nbauen()", "\nresult = h.bauen()"):
        if ende in src:
            src = src[:src.index(ende)]
    ns = {}
    exec(compile(src, skript, "exec"), ns)
    if "h" in ns and hasattr(ns["h"], "G"):
        return ns["h"].G
    return ns["G"]


def rot_xyz(e):
    ax, ay, az = e
    rx = np.array([[1, 0, 0], [0, math.cos(ax), -math.sin(ax)], [0, math.sin(ax), math.cos(ax)]])
    ry = np.array([[math.cos(ay), 0, math.sin(ay)], [0, 1, 0], [-math.sin(ay), 0, math.cos(ay)]])
    rz = np.array([[math.cos(az), -math.sin(az), 0], [math.sin(az), math.cos(az), 0], [0, 0, 1]])
    return rz @ ry @ rx          # Blender XYZ-Euler


P = np.array([[1, 0, 0], [0, 0, 1], [0, -1, 0]], float)   # Blender -> Roblox


def teile(G):
    out = []   # (gruppe, form, pos(3), rot 3x3, size(3))
    for g, liste in G.items():
        for t in liste:
            if t[0] == "box":
                _, m, s, e = t
                R = P @ rot_xyz(e) @ P.T
                out.append((g, "Block", P @ np.array(m), R, (s[0], s[2], s[1])))
            elif t[0] == "zyl":
                _, a, b, r, n = t
                a, b = P @ np.array(a), P @ np.array(b)
                d = b - a
                L = np.linalg.norm(d)
                x = d / L
                hilf = np.array([0, 1, 0]) if abs(x[1]) < 0.9 else np.array([1, 0, 0])
                z = np.cross(x, hilf); z /= np.linalg.norm(z)
                y = np.cross(z, x)
                out.append((g, "Cylinder", (a + b) / 2, np.column_stack([x, y, z]), (L, 2 * r, 2 * r)))
            elif t[0] in ("giebel", "px", "py"):
                if t[0] == "giebel":
                    _, a0, a1, pts = t
                    pts3 = lambda q, u, v: (q, u, v)
                    achse = 0
                elif t[0] == "px":
                    _, a0, a1, pts = t
                    pts3 = lambda q, u, v: (q, u, v)
                    achse = 0
                else:
                    _, a0, a1, pts = t
                    pts3 = lambda q, u, v: (u, q, v)
                    achse = 1
                assert len(pts) == 3, "nur Dreiecke"
                mitte_q = (a0 + a1) / 2
                dicke = abs(a1 - a0)
                V = [np.array(pts3(mitte_q, u, v), float) for u, v in pts]
                # Hoehe vom laengsten Seiten-Gegenpunkt -> zwei rechtwinklige Dreiecke
                seiten = [(0, 1, 2), (1, 2, 0), (2, 0, 1)]
                i, j, k = max(seiten, key=lambda s: np.linalg.norm(V[s[1]] - V[s[0]]))
                A, Bp, C = V[i], V[j], V[k]
                basis = Bp - A
                f = np.dot(C - A, basis) / np.dot(basis, basis)
                Fuss = A + f * basis
                for Ecke in (A, Bp):
                    # rechter Winkel bei Fuss, Ecke = Basisende, C = Spitze
                    yv = C - Fuss; hy = np.linalg.norm(yv)
                    zv = Fuss - Ecke; hz = np.linalg.norm(zv)
                    if hy < 1e-6 or hz < 1e-6:
                        continue
                    yv, zv = yv / hy, zv / hz
                    xv = np.cross(yv, zv)
                    mitte = Ecke + (Fuss - Ecke) / 2 + (C - Fuss) / 2
                    Rb = np.column_stack([xv, yv, zv])
                    out.append((g, "Wedge", P @ mitte, P @ Rb, (dicke, hy, hz)))
    return out


MAT = {
    "Wand": ("Plaster", (234, 224, 200)), "Wand2": ("Plaster", (158, 107, 77)), "Sockel": ("Concrete", (107, 105, 102)),
    "Dach": ("ClayRoofTiles", (120, 52, 40)), "Rahmen": ("SmoothPlastic", (238, 236, 230)), "Glas": ("SmoothPlastic", (38, 46, 54)),
    "Tuer": ("Wood", (92, 56, 34)), "Laden": ("Wood", (62, 92, 78)), "Metall": ("Metal", (70, 72, 76)),
    "Ziegel": ("Brick", (128, 62, 44)), "Stein": ("Concrete", (178, 174, 166)), "Holz": ("WoodPlanks", (150, 106, 66)),
    "Dunkel": ("Metal", (36, 37, 40)), "Pflanze": ("Grass", (66, 104, 44)),
}


def luau(G, x, z, gier, name):
    zeilen = []
    for g, form, pos, R, s in teile(G):
        r = R.flatten()
        f = lambda v: ("%.3f" % v).rstrip("0").rstrip(".") or "0"
        kurz = {"Block": "B", "Cylinder": "C", "Wedge": "W"}[form]
        rot = "" if np.allclose(R, np.eye(3), atol=1e-4) else "," + ",".join(("%.4f" % v).rstrip("0").rstrip(".") for v in r)
        zeilen.append('{"%s","%s",%s,%s,%s,%s,%s,%s%s}' % (g, kurz, f(pos[0]), f(pos[1]), f(pos[2]), f(s[0]), f(s[1]), f(s[2]), rot))
    mats = ",".join('%s={"%s",%d,%d,%d}' % (k, m, *c) for k, (m, c) in MAT.items())
    return f"""-- {name}: aus Blender ({len(zeilen)} Teile)
local MAT = {{{mats}}}
local T = {{
{(","+chr(10)).join(zeilen)}
}}
local ordner = workspace:FindFirstChild("Musterhaeuser") or Instance.new("Folder")
ordner.Name = "Musterhaeuser"
ordner.Parent = workspace
local alt = ordner:FindFirstChild("{name}")
if alt then alt:Destroy() end
local m = Instance.new("Model")
m.Name = "{name}"
local basis = CFrame.new({x}, 0, {z}) * CFrame.Angles(0, math.rad({gier}), 0)
for _, t in T do
	local p = t[2] == "W" and Instance.new("WedgePart") or Instance.new("Part")
	if t[2] == "C" then p.Shape = Enum.PartType.Cylinder end
	p.Anchored = true
	p.Size = Vector3.new(t[6], t[7], t[8])
	local lokal = t[9] and CFrame.new(t[3], t[4], t[5], t[9], t[10], t[11], t[12], t[13], t[14], t[15], t[16], t[17]) or CFrame.new(t[3], t[4], t[5])
	p.CFrame = basis * lokal
	local mt = MAT[t[1]]
	p.Material = Enum.Material[mt[1]]
	p.Color = Color3.fromRGB(mt[2], mt[3], mt[4])
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	if t[1] == "Glas" then p.Reflectance = 0.12 end
	local klein = p.Size.X < 1.2 or p.Size.Y < 1.2 or p.Size.Z < 1.2
	p.CanCollide = not klein
	p.CastShadow = not (p.Size.X < 0.5 and p.Size.Z < 0.5)
	p.Name = t[1]
	p.Parent = m
end
m.Parent = ordner
return "{name}: " .. #m:GetChildren() .. " Teile"
"""


if __name__ == "__main__":
    skript, x, z, gier, name = sys.argv[1:6]
    print(luau(lade(skript), float(x), float(z), float(gier), name))
