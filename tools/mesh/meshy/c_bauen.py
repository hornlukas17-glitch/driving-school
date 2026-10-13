import numpy as np, fast_simplification as fs, sys
from scipy import sparse
from scipy.spatial import cKDTree
d=np.load("roh.npz"); V0,F0=d["V"],d["F"]; L0=np.load("L.npy"); S=np.load("sicht2.npy")
R=1.4; SK=R/0.153; DX=0.0415; Y0=-0.2746
def spiel(P): return np.stack([-P[:,2]*SK,(P[:,1]-Y0)*SK,(P[:,0]+DX)*SK],1)
F=F0[S]; L=L0[S]
u,inv=np.unique(F,return_inverse=True); V=spiel(V0[u]); F=inv.reshape(-1,3)
print("Start",len(V),len(F))
# Rand (offene Kanten) festhalten, Rest Taubin-glätten
E=np.sort(np.concatenate([F[:,[0,1]],F[:,[1,2]],F[:,[2,0]]]),1)
k=E[:,0]*len(V)+E[:,1]; uk,cnt=np.unique(k,return_counts=True)
rand=np.zeros(len(V),bool); be=uk[cnt==1]; rand[be//len(V)]=True; rand[be%len(V)]=True
A=sparse.coo_matrix((np.ones(len(E)*2),(np.r_[E[:,0],E[:,1]],np.r_[E[:,1],E[:,0]])),shape=(len(V),len(V))).tocsr()
A.data[:]=1; deg=np.asarray(A.sum(1)).ravel()
frei=(~rand)[:,None]
for it in range(12):
    for lam in (0.5,-0.53):
        M=(A@V)/deg[:,None]
        V=np.where(frei,V+lam*(M-V),V)
np.savez("glatt.npz",V=V,F=F,L=L)
cen=V[F].mean(1); baum=cKDTree(cen)
def beschriften(Vd,Fd):
    _,nn=baum.query(Vd[Fd].mean(1),k=7)
    lab=L[nn]; return np.array([np.bincount(r,minlength=7).argmax() for r in lab])
Vd,Fd=fs.simplify(V,F,target_count=50000,agg=5)
print("dezimiert",len(Fd))
Ld=beschriften(Vd,Fd)
Ld[Ld>=3]=1
def teil(Vx,Fx,maske):
    Fm=Fx[maske]; uu,ii=np.unique(Fm,return_inverse=True); return Vx[uu],ii.reshape(-1,3)
meshes={}
lack=Ld==0
cy=Vd[Fd].mean(1)[:,1]
oben=lack&(cy>3.75)
meshes["Karosserie"]=teil(Vd,Fd,lack&~oben)
meshes["Dach"]=teil(Vd,Fd,oben)
meshes["Verkleidung"]=teil(Vd,Fd,Ld==1)
meshes["Glas"]=teil(Vd,Fd,Ld==2)
# Lichter aus dem feinen Netz, leicht nach außen versetzt
def vnormalen(Vx,Fx):
    n=np.cross(Vx[Fx[:,1]]-Vx[Fx[:,0]],Vx[Fx[:,2]]-Vx[Fx[:,0]])
    N=np.zeros_like(Vx)
    for j in range(3): np.add.at(N,Fx[:,j],n)
    return N/(np.linalg.norm(N,axis=1,keepdims=True)+1e-12)
cx=cen[:,0]
for lab,name,n,a in ((3,"LichtV","Scheinwerfer","scheinwerfer"),(5,"BlinkV","Blinker#","blinker"),(4,"LichtH","Ruecklicht","neon_rot"),(6,"BlinkH","Blinker#","blinker")):
    for s,seite in ((1,"R"),(-1,"L")):
        m=(L==lab)&(np.sign(cx)==s)
        if lab in (3,4): m=(L==lab)&((np.sign(cx)==s)|(np.abs(cx)<1e-6)&(s>0))
        Vl,Fl=teil(V,F,m)
        if len(Fl)>1500: Vl,Fl=fs.simplify(Vl,Fl,target_count=1500,agg=4)
        Nl=vnormalen(Vl,Fl)
        # Außenrichtung: weg vom Fahrzeugmittelpunkt (in Höhe der Lichter)
        mitte=np.array([0,Vl[:,1].mean(),0])
        aus=np.sign(((Vl-mitte)*Nl).sum(1))[:,None]
        Vl=Vl+Nl*aus*0.035
        meshes[name+seite]=(Vl,Fl,{"n":n.replace("#",seite),"a":a})
        print(name+seite,len(Fl))

for k2,v in meshes.items(): print(k2,len(v[1]))
# Ergebnis für tools/mesh/vanta.py
import json, os
out={}; meta={}
for k2,v in meshes.items():
    out[k2+"_V"]=v[0].astype(np.float32); out[k2+"_F"]=v[1].astype(np.int32)
    if len(v)>2: meta[k2]=v[2]
out["meta"]=np.array(json.dumps(meta))
np.savez_compressed(os.path.join(os.path.dirname(os.path.abspath(__file__)),"..","vanta_teile.npz"),**out)
