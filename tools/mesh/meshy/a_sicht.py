import numpy as np, sys
sys.path.insert(0,".")
from ras import rastern
d=np.load("roh.npz"); V,F=d["V"],d["F"]; C=np.load("C.npy")
c=V[F].mean(1)
ACHS=[(-0.603,-0.1216),(0.520,-0.1216)]
rad=np.zeros(len(F),bool)
for ax,ay in ACHS:
    rad|=(np.hypot(c[:,0]-ax,c[:,1]-ay)<0.162)&(np.abs(c[:,2])>0.2)
print("Radflächen",rad.sum())
rest=np.where(~rad)[0]
sicht=np.zeros(len(F),bool)
dirs=[]
for el in (-60,-25,0,20,45,75):
    for az in range(0,360,30 if abs(el)<70 else 90):
        dirs.append((az,el))
dirs.append((0,90))
for i,(az,el) in enumerate(dirs):
    sv=rastern(V,F[rest],C[rest],az,el,W=1000,H=1000,s=480,ids="tiefe")
    sicht[rest[sv]]=True
    print(i,az,el,sicht.sum(),flush=True)
np.save("rad.npy",rad); np.save("sicht.npy",sicht)
