import numpy as np, glob, sys
from PIL import Image
d=np.load("roh.npz"); V,VT,F,FT=d["V"],d["VT"],d["F"],d["FT"]
tex=np.asarray(Image.open(glob.glob((sys.argv[1] if len(sys.argv)>1 else "entpackt/")+"*/*.png")[0]).convert("RGB")).astype(np.float32)/255
H,W,_=tex.shape
uv=VT[FT].mean(1)
# mehrere Stichproben je Fläche (Ecken + Mitte) für stabilere Farbe
cols=[]
for w in ([1/3,1/3,1/3],[.6,.2,.2],[.2,.6,.2],[.2,.2,.6]):
    p=(VT[FT]*np.array(w)[None,:,None]).sum(1)
    x=np.clip((p[:,0]*W).astype(int),0,W-1); y=np.clip(((1-p[:,1])*H).astype(int),0,H-1)
    cols.append(tex[y,x])
C=np.mean(cols,0)
np.save("C.npy",C)
print(C.mean(0))
