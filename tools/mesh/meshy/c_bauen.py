"""v3: Teile getrennt reduzieren (Ränder bleiben gleich -> keine Risse, saubere Kanten Glas/Lack),
Beschriftung stärker geglättet, Fransen unten abgeschnitten, mehr Dreiecke + Normalen (glatte Flächen),
Lichtbänder vorne/hinten als durchgehende, saubere Leuchtleisten (Verlauf aus den Lichtflächen des Modells)."""
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
fn=np.cross(V[F[:,1]]-V[F[:,0]],V[F[:,2]]-V[F[:,0]]); fn/=np.linalg.norm(fn,axis=1,keepdims=True)+1e-12
vorne=(cg[:,2]<-7.0)&(cg[:,1]<1.55)&(fn[:,2]<-0.35)&(L<=1)        # nur nach vorn zeigende Flächen (nicht um die Ecke)
for _ in range(4):                                                  # Zone glätten
    vorne=((A@vorne.astype(float)+1.2*vorne)/(np.asarray(A.sum(1)).ravel()+1.2)>0.5)&(cg[:,2]<-6.8)&(L<=1)
ecke=(np.abs(cg[:,0])>2.25)&(cg[:,2]<-6.75)&(cg[:,1]<2.05)&(L<=1)     # untere Frontecken komplett schwarz (Meshy-Lamellen dort zackig)
zone=ecke|vorne|((cg[:,2]>8.3)&(cg[:,1]<1.35)&(L<=1))|((np.abs(cg[:,0])>2.9)&(cg[:,1]<0.95)&(np.abs(cg[:,2])<3.2)&(L<=1))
print("schwarze Zonen",zone.sum())
LICHT_PUNKTE={lab:cg[L==lab] for lab in (3,4,5,6)}
# Beschriftung glätten
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
L[(L>=3)&(L<=6)]=1          # unter den Leuchtleisten: schwarzes Gehäuse
# Taubin-Glättung (offene Ränder fest)
u,inv=np.unique(F,return_inverse=True); V=V[u]; F=inv.reshape(-1,3)
E=np.sort(np.concatenate([F[:,[0,1]],F[:,[1,2]],F[:,[2,0]]]),1)
k_=E[:,0]*len(V)+E[:,1]; uk,cnt=np.unique(k_,return_counts=True)
rand=np.zeros(len(V),bool); be=uk[cnt==1]; rand[be//len(V)]=True; rand[be%len(V)]=True
Av=sparse.coo_matrix((np.ones(len(E)*2),(np.r_[E[:,0],E[:,1]],np.r_[E[:,1],E[:,0]])),shape=(len(V),len(V))).tocsr(); Av.data[:]=1
deg=np.asarray(Av.sum(1)).ravel(); frei=(~rand)[:,None]
for it in range(30):
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
Vr,Fr=fs.simplify(Vr,Fr,target_count=72000,agg=4,preserve_border=True)
print("Lack+Verkleidung",len(Fr))
baum=cKDTree(cen[rest]); Lr_alt=L[rest]
_,nn=baum.query(Vr[Fr].mean(1),k=9)
Lr=(Lr_alt[nn]==1).mean(1)>0.5           # True = Verkleidung
Ar=adj_faces(Fr,len(Vr))
for _ in range(6):
    anteil=(Ar@Lr.astype(float)+1.5*Lr)/(np.asarray(Ar.sum(1)).ravel()+1.5)
    Lr=anteil>0.5
# Sprenkel weg: kleine Inseln in Lack bzw. Schwarz umdrehen
for wert,grenze in ((True,40),(False,40)):
    m=Lr==wert
    nc,cc=connected_components(Ar[m][:,m],directed=False)
    klein=np.bincount(cc)[cc]<grenze
    Lr[np.where(m)[0][klein]]=not wert
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
aufteilen(~Lr,["Karosserie","Heckpartie","Mittelteil","Lack4","Lack5"][:lackteile])
# schwarze Zonen getrennt reduziert und an die Verkleidung gehängt
Vz,Fz=reduziere(*teil(L==7),9000); print("Zonen",len(Fz))
Fr=np.concatenate([Fr,Fz+len(Vr)]); Vr=np.concatenate([Vr,Vz]); Lr=np.r_[Lr,np.ones(len(Fz),bool)]; cr=Vr[Fr].mean(1)
trimteile=int(np.ceil(Lr.sum()/19000))
aufteilen(Lr,["Verkleidung","Verkleidung2","Verkleidung3"][:trimteile],{"n":"Verkleidung2","a":"schwarz"})
Vg,Fg=reduziere(*teil(L==2),7000); meshes["Glas"]=(Vg,Fg); print("Glas",len(Fg))
# ---- Normalen: über alle Teile gemeinsam (gleiche Normale an Teilgrenzen -> keine sichtbaren Nähte) ----
schluessel={}
summe=[]
def key(P): return [tuple(r) for r in np.round(P,3)]
alle=[k for k in meshes if not (k.startswith("Licht") or k.startswith("Blink"))]
acc={}
for k2 in alle:
    Vx,Fx=meshes[k2][0],meshes[k2][1]
    fn=np.cross(Vx[Fx[:,1]]-Vx[Fx[:,0]],Vx[Fx[:,2]]-Vx[Fx[:,0]])
    Nv=np.zeros_like(Vx)
    for j in range(3): np.add.at(Nv,Fx[:,j],fn)
    for kk,nv in zip(key(Vx),Nv):
        acc[kk]=acc.get(kk,0)+nv
NORMALEN={}
for k2 in alle:
    Vx=meshes[k2][0]
    Nx=np.array([acc[kk] for kk in key(Vx)])
    NORMALEN[k2]=Nx/(np.linalg.norm(Nx,axis=1,keepdims=True)+1e-12)
# ---- Leuchtleisten: durchgehende Bänder entlang der Lichtlinie des Modells ----
def bandkurve(p, vorne):
    xm=np.percentile(np.abs(p[:,0]),99)
    xs=np.arange(-xm,xm+1e-6,0.08)
    ys=[];zs=[];ok=[]
    for x in xs:
        q=p[np.abs(p[:,0]-x)<0.07]
        if len(q)<2: ys.append(np.nan); zs.append(np.nan); continue
        ys.append(np.median(q[:,1])); zs.append(np.percentile(q[:,2],15 if vorne else 85))
    ys=np.array(ys); zs=np.array(zs)
    gut=~np.isnan(ys)
    ys=np.interp(xs,xs[gut],ys[gut]); zs=np.interp(xs,xs[gut],zs[gut])
    ys=(ys+ys[::-1])/2; zs=(zs+zs[::-1])/2                     # symmetrisch
    k=np.ones(7)/7
    for _ in range(3):
        ys=np.convolve(np.pad(ys,3,mode="edge"),k,"valid"); zs=np.convolve(np.pad(zs,3,mode="edge"),k,"valid")
    return np.stack([xs,ys,zs],1)
KV=np.concatenate([meshes[k][0] for k in alle]); KN=np.concatenate([NORMALEN[k] for k in alle])
kbaum=cKDTree(KV)
def anlegen(C):
    """Kurvenpunkte auf die Karosserie legen: Mittel der nächsten Oberflächenpunkte + deren Normale"""
    _,nn=kbaum.query(C,k=16)
    P=KV[nn].mean(1); N=KN[nn].mean(1); N/=np.linalg.norm(N,axis=1,keepdims=True)
    k=np.ones(5)/5
    for _ in range(2):
        P=np.stack([np.convolve(np.pad(P[:,i],2,mode="edge"),k,"valid") for i in range(3)],1)
        N=np.stack([np.convolve(np.pad(N[:,i],2,mode="edge"),k,"valid") for i in range(3)],1)
    N/=np.linalg.norm(N,axis=1,keepdims=True)
    return P,N
def band(PN, vorne, h, t, von, bis):
    """flache Leuchtleiste, die auf der Karosserie aufliegt (Tiefe t nach außen, Höhe h)"""
    P,N=PN[0][von:bis+1],PN[1][von:bis+1]
    up=np.array([0.,1.,0.])
    U=up-(N@up)[:,None]*N; U/=np.linalg.norm(U,axis=1,keepdims=True)
    M=P+N*(t/2-0.02)                                             # leicht eingelassen, damit keine Lücke bleibt
    ecken=[(+1,+1),(+1,-1),(-1,-1),(-1,+1)]
    Vb=np.concatenate([M+a*U*h/2+b*N*t/2 for a,b in ecken],0)   # Block je Ecke
    n=len(P); Fb=[]
    for e in range(4):
        e2=(e+1)%4
        for i in range(n-1):
            a0,a1,b0,b1=e*n+i,e*n+i+1,e2*n+i,e2*n+i+1
            Fb+=[(a0,b0,a1),(a1,b0,b1)]
    for i in (0,n-1):
        q=[e*n+i for e in range(4)]
        Fb+=[(q[0],q[1],q[2]),(q[0],q[2],q[3])] if i==0 else [(q[0],q[2],q[1]),(q[0],q[3],q[2])]
    return Vb,np.array(Fb)
for vorne,pkt,name,nm,a,h,t,grenze in ((True,np.concatenate([LICHT_PUNKTE[3][LICHT_PUNKTE[3][:,1]>2.0],LICHT_PUNKTE[5][LICHT_PUNKTE[5][:,1]>2.0]]),"V","Scheinwerfer","scheinwerfer",0.13,0.1,2.8),
                                        (False,np.concatenate([LICHT_PUNKTE[4],LICHT_PUNKTE[6]]),"H","Ruecklicht","neon_rot",0.2,0.1,2.45)):
    C=bandkurve(pkt,vorne)
    PN=anlegen(C)
    xs=C[:,0]; mitte=np.argmin(np.abs(xs)); li=np.where(xs<=-grenze)[0][-1]; re=np.where(xs>=grenze)[0][0]
    for teilname,von,bis,meta_ in (("BlinkL",0,li,{"n":"BlinkerL","a":"blinker"}),("LichtL",li,mitte,{"n":nm,"a":a}),
                                    ("LichtR",mitte,re,{"n":nm,"a":a}),("BlinkR",re,len(C)-1,{"n":"BlinkerR","a":"blinker"})):
        Vb,Fb=band(PN,vorne,h,t,von,bis)
        nn=teilname[:-1]+name+teilname[-1]          # z. B. LichtVL, BlinkHR
        meshes[nn]=(Vb,Fb,meta_)
        print(nn,len(Fb),"x",round(xs[von],2),"..",round(xs[bis],2))
out={}; meta={}
for k2,v in meshes.items():
    out[k2+"_V"]=v[0].astype(np.float32); out[k2+"_F"]=v[1].astype(np.int32)
    if k2 in NORMALEN: out[k2+"_N"]=NORMALEN[k2].astype(np.float32)
    if len(v)>2 and v[2]: meta[k2]=v[2]
out["Dach_V"]=np.zeros((0,3),np.float32); out["Dach_F"]=np.zeros((0,3),np.int32)
out["meta"]=np.array(json.dumps(meta))
np.savez_compressed(sys.argv[1] if len(sys.argv)>1 else os.path.join(os.path.dirname(os.path.abspath(__file__)),"..","vanta_teile.npz"),**out)
