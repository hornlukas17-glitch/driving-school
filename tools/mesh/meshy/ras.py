import numpy as np
def rastern(V,F,col,az,el,W=1600,H=700,s=780,mitte=(0,0,0),ids=False,bg=0.85):
    """z-Buffer per adaptiver Punktabtastung. col: Nx3 (pro Fläche). gibt Bild (und Flächen-ID-Bild) zurück"""
    tri=V[F]-np.array(mitte)
    a,e=np.radians(az),np.radians(el)
    dd=np.array([np.cos(e)*np.cos(a), np.sin(e), np.cos(e)*np.sin(a)])
    r=np.cross([0,1,0],dd); r/=np.linalg.norm(r); h=np.cross(dd,r)
    px=np.stack([W/2+(tri@r)*s, H/2-(tri@h)*s],-1)   # N,3,2
    t=tri@dd
    e1=px[:,1]-px[:,0]; e2=px[:,2]-px[:,0]; ar=np.abs(e1[:,0]*e2[:,1]-e1[:,1]*e2[:,0])/2
    n=np.ceil(ar*3).astype(np.int64)+2
    zb=np.full(H*W,-1e9); out=np.full((H*W,3),bg); idimg=np.full(H*W,-1)
    rng=np.random.default_rng(0)
    # in Blöcken, damit der Speicher reicht
    reihe=np.arange(len(F))
    start=0
    cs=np.cumsum(n)
    while start<len(F):
        end=np.searchsorted(cs, cs[start]-n[start]+6_000_000, side="right"); end=max(end,start+1)
        fi=np.repeat(reihe[start:end], n[start:end])
        u=rng.random(len(fi)); v=rng.random(len(fi)); m=u+v>1; u[m]=1-u[m]; v[m]=1-v[m]
        P=px[fi,0]*(1-u-v)[:,None]+px[fi,1]*u[:,None]+px[fi,2]*v[:,None]
        T=t[fi,0]*(1-u-v)+t[fi,1]*u+t[fi,2]*v
        ix=P[:,0].astype(int); iy=P[:,1].astype(int)
        ok=(ix>=0)&(ix<W)&(iy>=0)&(iy<H)
        k=iy[ok]*W+ix[ok]; T=T[ok]; fi=fi[ok]
        o=np.lexsort((T,k)); k,T,fi=k[o],T[o],fi[o]
        last=np.r_[k[1:]!=k[:-1],True]; k,T,fi=k[last],T[last],fi[last]
        b=T>zb[k]; zb[k[b]]=T[b]; idimg[k[b]]=fi[b]
        start=end
    hit=idimg>=0
    tri2=tri
    nrm=np.cross(tri2[:,1]-tri2[:,0],tri2[:,2]-tri2[:,0]); nrm/=np.linalg.norm(nrm,axis=1,keepdims=True)+1e-12
    L=np.array([.3,.8,.5]); L/=np.linalg.norm(L)
    nn=np.where(((nrm@dd)<0)[:,None],-nrm,nrm); hell=0.45+0.55*np.clip(nn@L,0,1)
    out[hit]=np.clip(col[idimg[hit]]*hell[idimg[hit],None],0,1)
    img=(out.reshape(H,W,3)*255).astype(np.uint8)
    if ids == "tiefe":
        cen=tri.mean(1); cx=(W/2+(cen@r)*s).astype(int); cy=(H/2-(cen@h)*s).astype(int); ct=cen@dd
        ok=(cx>=0)&(cx<W)&(cy>=0)&(cy<H)
        sicht=np.zeros(len(F),bool)
        # Nachbarpixel mitnehmen (Kanten)
        best=np.full(len(F),-1e9)
        for ox in (-1,0,1):
            for oy in (-1,0,1):
                k=np.clip(cy+oy,0,H-1)*W+np.clip(cx+ox,0,W-1)
                best=np.maximum(best,np.where(zb[k]>-1e8,zb[k],1e9))
        sicht=ok&(ct>=best-0.004)
        return sicht
    return (img, idimg.reshape(H,W)) if ids else img
