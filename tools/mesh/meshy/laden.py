import numpy as np, sys, glob
D=sys.argv[1] if len(sys.argv)>1 else "entpackt/"   # Ordner mit der entpackten Meshy-ZIP
obj=glob.glob(D+"*/*.obj")[0]
v=[];vt=[];fv=[];ft=[]
with open(obj) as f:
    for l in f:
        if l.startswith("v "): v.append(l[2:])
        elif l.startswith("vt "): vt.append(l[3:])
        elif l.startswith("f "):
            a=l[2:].split()
            fv.append(" ".join(x.split("/")[0] for x in a)); ft.append(" ".join(x.split("/")[1] for x in a))
V=np.array(" ".join(v).split(),float).reshape(-1,3)
VT=np.array(" ".join(vt).split(),float).reshape(-1,2)
F=np.array(" ".join(fv).split(),np.int64).reshape(-1,3)-1
FT=np.array(" ".join(ft).split(),np.int64).reshape(-1,3)-1
np.savez("roh.npz",V=V,VT=VT,F=F,FT=FT)
print(V.shape,VT.shape,F.shape)
