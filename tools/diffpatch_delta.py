# python3 diffpatch.py <alt-datei> <neu-datei> <modulpfad> <ausgabe>
import sys, difflib
alt=open(sys.argv[1]).read(); neu=open(sys.argv[2]).read(); modul=sys.argv[3]
A=alt.splitlines(True); B=neu.splitlines(True)
paare=[]
cur=list(A)   # aktueller Stand (vorherige Änderungen schon eingebaut), damit jeder Suchtext eindeutig UND vorhanden ist
off=0
for tag,i1,i2,j1,j2 in difflib.SequenceMatcher(None,A,B,autojunk=False).get_opcodes():
    if tag=="equal": continue
    s1,s2=i1+off,i2+off
    text="".join(cur)
    c=1
    while True:
        a="".join(cur[max(0,s1-c):s2+c]); b="".join(cur[max(0,s1-c):s1])+"".join(B[j1:j2])+"".join(cur[s2:s2+c])
        if a and text.count(a)==1: break
        assert c<len(cur), "kein eindeutiger Suchtext gefunden"
        c+=1
    paare.append((a,b))
    cur[s1:s2]=B[j1:j2]
    off+=(j2-j1)-(i2-i1)
assert "".join(cur)==neu, "Patch ergibt nicht die neue Datei"
def L(x):
    n=3
    while "]"+"="*n+"]" in x: n+=1
    return "["+"="*n+"[\n" + x + "]"+"="*n+"]"   # Lua überspringt den ersten Zeilenumbruch nach [==[
lu=['local function ersetze(src, alt, neu)','\tlocal a, b = string.find(src, alt, 1, true)','\tassert(a, "nicht gefunden: " .. alt:sub(1, 60))','\tassert(not string.find(src, alt, b + 1, true), "mehrfach: " .. alt:sub(1, 60))','\treturn src:sub(1, a - 1) .. neu .. src:sub(b + 1)','end',
f'local s = {modul}','local src = s.Source', 'local start = #src']
for a,b in paare: lu.append("src = ersetze(src, "+L(a)+", "+L(b)+")")
lu += [f'assert(#src - start == {len(neu.encode())-len(alt.encode())}, "Delta falsch: " .. (#src - start))','s.Source = src','return s.Name .. ": " .. #src .. " Zeichen"']
open(sys.argv[4],"w").write("\n".join(lu))
print(len(paare),"Paare", len("\n".join(lu)),"Zeichen")
