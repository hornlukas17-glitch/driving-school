"""v2: Teile getrennt reduzieren (Ränder bleiben gleich -> keine Risse, saubere Kanten Glas/Lack),
Beschriftung stärker geglättet, Fransen unten abgeschnitten, Lichter direkt Teil der Oberfläche."""
import numpy as np, fast_simplification as fs, sys, json, os
from scipy import sparse
from scipy.sparse.csgraph import connected_components
d=np.load("roh.npz"); V0,F0=d["V"],d["F"]; L0=np.load("L.npy"); S=np.load("sicht2.npy")
R=1.4; SK=R/0.153; DX=0.0415; Y0=-0.2746
def spiel(P): return np.stack([-P[:,2]*SK,(P[:,1]-Y0)*SK,(P[:,0]+DX)*SK],1)
F=F0[S]; L=L0[S].copy()
u,inv=np.unique(F,return_inverse=True); V=spiel(V0[u]); F=inv.reshape(-1,3)
# Fransen unten weg
cy=V[F].mean(1)[:,1]
F=F[cy>0.55]; L=L[cy>0.55]
# lose Splitter (kleine Inseln) weg
def adj_faces(F,nv):
    E=np.sort(np.concatenate([F[:,[0,1]],F[:,[1,2]],F[:,[2,0]]]),1)
    fid=np.tile(np.arange(len(F)),3); key=E[:,0]*nv+E[:,1]
    o=np.argsort(key); key=key[o]; fid=fid[o]
    g=np.where(key[1:]==key[:-1])[0]
    return sparse.coo_matrix((np.ones(len(g)*2),(np.r_[fid[g],fid[g+1]],np.r_[fid[g+1],fid[g]])),shape=(len(F),len(F))).tocsr()
A=adj_faces(F,len(V))
n,comp=connected_components(A,directed=False)
gross=np.bincount(comp)
keep=gross[comp]>=300
print("Inseln",n,"entfernt",(~keep).sum())
F=F[keep]; L=L[keep]; A=adj_faces(F,len(V))
# schwarze Zonen aus der Form: Frontgrill/Lippe, Diffusor, Schweller zwischen den Rädern
cg=V[F].mean(1)
zone=((cg[:,2]<-7.3)&(cg[:,1]<1.55)&(L<=1))|((cg[:,2]>8.3)&(cg[:,1]<1.35)&(L<=1))|((np.abs(cg[:,0])>2.9)&(cg[:,1]<0.95)&(np.abs(cg[:,2])<3.2)&(L<=1))
print("schwarze Zonen",zone.sum())
# Beschriftung glätten (Lichter schützen: dürfen nur schrumpfen/wachsen unter sich)
for _ in range(15):
    M=np.zeros((len(F),7))
    for k in range(7): M[:,k]=A@(L==k).astype(float)
    M[np.arange(len(F)),L]+=1.1
    L=M.argmax(1)
# kleine Beschriftungs-Inseln an Nachbarn angleichen
for k,grenze in ((0,150),(1,25),(2,150)):
    m=L==k
    sub=A[m][:,m]
    nc,cc=connected_components(sub,directed=False)
    klein=np.bincount(cc)[cc]<grenze
    idx=np.where(m)[0][klein]
    if len(idx):
        M=np.zeros((len(idx),7))
        for j in range(7): M[:,j]=A[idx]@(L==j).astype(float)
        M[:,k]=-1
        L[idx]=M.argmax(1)
    print("Label",k,"Inseln",nc,"angeglichen",len(idx))
L[zone]=7
# Taubin-Glättung (offene Ränder fest)
u,inv=np.unique(F,return_inverse=True); V=V[u]; F=inv.reshape(-1,3)
E=np.sort(np.concatenate([F[:,[0,1]],F[:,[1,2]],F[:,[2,0]]]),1)
k_=E[:,0]*len(V)+E[:,1]; uk,cnt=np.unique(k_,return_counts=True)
rand=np.zeros(len(V),bool); be=uk[cnt==1]; rand[be//len(V)]=True; rand[be%len(V)]=True
Av=sparse.coo_matrix((np.ones(len(E)*2),(np.r_[E[:,0],E[:,1]],np.r_[E[:,1],E[:,0]])),shape=(len(V),len(V))).tocsr(); Av.data[:]=1
deg=np.asarray(Av.sum(1)).ravel(); frei=(~rand)[:,None]
for it in range(12):
    for lam in (0.5,-0.53):
        V=np.where(frei,V+lam*((Av@V)/deg[:,None]-V),V)
cen=V[F].mean(1)
def teil(maske):
    Fm=F[maske]; uu,ii=np.unique(Fm,return_inverse=True); return V[uu],ii.reshape(-1,3)
def reduziere(Vx,Fx,ziel):
    if len(Fx)<=ziel: return Vx,Fx
    Vd,Fd=fs.simplify(Vx,Fx,target_count=ziel,agg=5,preserve_border=True)
    return Vd,Fd
meshes={}
from scipy.spatial import cKDTree
# Lack + Verkleidung zusammen reduzieren (nur Glas-/Licht-/offene Ränder bleiben fest), dann neu beschriften
rest=(L==0)|(L==1)
Vr,Fr=teil(rest)
Vr,Fr=fs.simplify(Vr,Fr,target_count=44000,agg=5,preserve_border=True)
print("Lack+Verkleidung",len(Fr))
baum=cKDTree(cen[rest]); Lr_alt=L[rest]
_,nn=baum.query(Vr[Fr].mean(1),k=9)
Lr=(Lr_alt[nn]==1).mean(1)>0.5           # True = Verkleidung
Ar=adj_faces(Fr,len(Vr))
for _ in range(3):
    anteil=(Ar@Lr.astype(float)+1.5*Lr)/(np.asarray(Ar.sum(1)).ravel()+1.5)
    Lr=anteil>0.5
cr=Vr[Fr].mean(1)
def stueck(Vx,Fx,m):
    Fm=Fx[m]; uu,ii=np.unique(Fm,return_inverse=True); return Vx[uu],ii.reshape(-1,3)
def aufteilen(maske, namen, meta=None):
    z=cr[maske,2]; gr=np.quantile(z,np.linspace(0,1,len(namen)+1)); gr[0]-=1; gr[-1]+=1
    for i,name in enumerate(namen):
        m=maske&(cr[:,2]>gr[i])&(cr[:,2]<=gr[i+1])
        Vx,Fx=stueck(Vr,Fr,m)
        assert len(Fx)<=20000,(name,len(Fx))
        meshes[name]=(Vx,Fx,meta) if meta and i>0 else (Vx,Fx)
        print(name,len(Fx))
lackteile=int(np.ceil((~Lr).sum()/19000)); trimteile=int(np.ceil(Lr.sum()/19000))
aufteilen(~Lr,["Karosserie","Heckpartie","Mittelteil"][:lackteile])
# schwarze Zonen getrennt reduziert und an die Verkleidung gehängt
Vz,Fz=reduziere(*teil(L==7),9000); print("Zonen",len(Fz))
Fr=np.concatenate([Fr,Fz+len(Vr)]); Vr=np.concatenate([Vr,Vz]); Lr=np.r_[Lr,np.ones(len(Fz),bool)]; cr=Vr[Fr].mean(1)
trimteile=int(np.ceil(Lr.sum()/19000))
aufteilen(Lr,["Verkleidung","Verkleidung2"][:trimteile],{"n":"Verkleidung2","a":"schwarz"})
Vg,Fg=reduziere(*teil(L==2),7000); meshes["Glas"]=(Vg,Fg); print("Glas",len(Fg))
for lab,name,nm,a in ((3,"LichtV","Scheinwerfer","scheinwerfer"),(5,"BlinkV","Blinker#","blinker"),(4,"LichtH","Ruecklicht","neon_rot"),(6,"BlinkH","Blinker#","blinker")):
    for s,seite in ((1,"R"),(-1,"L")):
        m=(L==lab)&((np.sign(cen[:,0])==s)|((cen[:,0]==0)&(s>0)))
        if not m.any(): continue
        Vx,Fx=reduziere(*teil(m),3000)
        meshes[name+seite]=(Vx,Fx,{"n":nm.replace("#",seite),"a":a})
        print(name+seite,len(Fx))
out={}; meta={}
for k2,v in meshes.items():
    out[k2+"_V"]=v[0].astype(np.float32); out[k2+"_F"]=v[1].astype(np.int32)
    if len(v)>2 and v[2]: meta[k2]=v[2]
out["Dach_V"]=np.zeros((0,3),np.float32); out["Dach_F"]=np.zeros((0,3),np.int32)
out["meta"]=np.array(json.dumps(meta))
np.savez_compressed(sys.argv[1] if len(sys.argv)>1 else os.path.join(os.path.dirname(os.path.abspath(__file__)),"..","vanta_teile.npz"),**out)
