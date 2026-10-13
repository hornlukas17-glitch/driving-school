import numpy as np, sys
from scipy import sparse
d=np.load("roh.npz"); V,F=d["V"],d["F"]; C=np.load("C.npy")
sicht=np.load("sicht.npy"); rad=np.load("rad.npy")
c=V[F].mean(1); lum=C.mean(1); r,g,b=C.T
# Kanten-Nachbarschaft
E=np.sort(np.concatenate([F[:,[0,1]],F[:,[1,2]],F[:,[2,0]]]),1)
fid=np.tile(np.arange(len(F)),3)
key=E[:,0]*len(V)+E[:,1]
o=np.argsort(key); key=key[o]; fid=fid[o]
gleich=np.where(key[1:]==key[:-1])[0]
A=sparse.coo_matrix((np.ones(len(gleich)*2),(np.r_[fid[gleich],fid[gleich+1]],np.r_[fid[gleich+1],fid[gleich]])),shape=(len(F),len(F))).tocsr()
sparse.save_npz("adj.npz",A)
# Löcher schließen
for _ in range(3):
    n=A@sicht.astype(float)
    sicht=sicht|((~rad)&(n>=2))
print("sichtbar",sicht.sum())
np.save("sicht2.npy",sicht)
L=np.zeros(len(F),int)        # 0 Lack
dunkel=lum<0.13
L[dunkel]=1                   # Verkleidung
glas=dunkel&(c[:,1]>0.03)&(np.abs(c[:,2])<0.335)&(c[:,0]>-0.42)&(c[:,0]<0.75)
L[glas]=2
x,y,z=c[:,0],c[:,1],np.abs(c[:,2])
belt=0.093+(x+0.244)*(0.042/0.768)
top=np.where(x>0.366,0.223-(x-0.366)*(0.085/0.171),1)
seitglas=(x>-0.30)&(x<0.54)&(y>belt-0.003)&(y<top)&(z>0.25)&(z<0.335)
spiegel=(x<-0.12)&(y<0.125)&(z>0.315)
L[seitglas&~spiegel]=2
rot=(r>0.3)&(r>1.8*g)&(r>1.8*b)&(c[:,0]>0.6)
L[rot]=4
weiss=(lum>0.5)&(c[:,0]<-0.7)&(np.abs(r-b)<0.15)
L[weiss]=3
L[(L==3)&(np.abs(c[:,2])>0.31)]=5
L[(L==4)&(np.abs(c[:,2])>0.29)]=6
# Glätten: Mehrheitsentscheid unter Nachbarn (3 Runden)
for _ in range(8):
    M=np.zeros((len(F),7))
    for k in range(7): M[:,k]=A@(L==k).astype(float)
    M[np.arange(len(F)),L]+=1.2
    L=M.argmax(1)
for k in range(7): print(k,(sicht&(L==k)).sum())
np.save("L.npy",L)
PAL=np.array([[0.55,0.6,0.68],[0.08,0.08,0.09],[0.1,0.2,0.45],[1,1,0.8],[0.9,0.05,0.05],[1,0.6,0],[1,0.8,0.1]])
np.save("Lfarbe.npy",PAL[L])
