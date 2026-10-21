"""v62: Prüft, dass in allen Auto-OBJ (dist/mesh/autos) jede geschlossene Teilform nach außen zeigt.
Roblox zeichnet nur Vorderseiten – nach innen gedrehte Flächen lassen Autos hohl/durchsichtig wirken."""
import glob, sys
import numpy as np

fehler = 0
for pfad in sorted(glob.glob("dist/mesh/autos/*.obj")):
    V, F = [], []
    for z in open(pfad):
        p = z.split()
        if p and p[0] == "v": V.append([float(x) for x in p[1:4]])
        elif p and p[0] == "f": F.append([int(x.split("/")[0]) - 1 for x in p[1:]])
    P = np.array(V)
    eltern = list(range(len(V)))
    def w(i):
        while eltern[i] != i:
            eltern[i] = eltern[eltern[i]]; i = eltern[i]
        return i
    for f in F:
        for i in f[1:]:
            a, b = w(f[0]), w(i)
            if a != b: eltern[a] = b
    vol = {}
    for f in F:
        s = sum(np.dot(P[f[0]], np.cross(P[f[k]], P[f[k + 1]])) for k in range(1, len(f) - 1))
        vol[w(f[0])] = vol.get(w(f[0]), 0.0) + s
    innen = sum(1 for v in vol.values() if v < -1e-6)
    if innen:
        print(f"  ✗ {pfad}: {innen}/{len(vol)} Teilformen zeigen nach innen (tools/blender/auto_obj.py neu laufen lassen)")
        fehler = 1
print("  ✓ Auto-OBJ zeigen nach außen" if not fehler else "", end="\n" if not fehler else "")
sys.exit(fehler)
