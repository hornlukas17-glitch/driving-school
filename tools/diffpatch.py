# python3 diffpatch.py <alt-datei> <neu-datei> <modulpfad> <ausgabe>
import sys, difflib
alt=open(sys.argv[1]).read(); neu=open(sys.argv[2]).read(); modul=sys.argv[3]
A=alt.splitlines(True); B=neu.splitlines(True)
paare=[]
aktuell=alt
for tag,i1,i2,j1,j2 in difflib.SequenceMatcher(None,A,B,autojunk=False).get_opcodes():
    if tag=="equal": continue
    c=1
    while True:
        a="".join(A[max(0,i1-c):i2+c]); b="".join(A[max(0,i1-c):i1])+"".join(B[j1:j2])+"".join(A[i2:i2+c])
        if aktuell.count(a)==1: break   # eindeutig im schon teilweise geänderten Text
        c+=1
    aktuell=aktuell.replace(a,b,1)
    paare.append((a,b))
assert aktuell==neu, "Patch ergibt nicht die neue Datei"
def L(x):
    n=3
    while "]"+"="*n+"]" in x: n+=1
    return "["+"="*n+"[\n" + x + "]"+"="*n+"]"   # Lua überspringt den ersten Zeilenumbruch nach [==[
lu=['local function ersetze(src, alt, neu)','\tlocal a, b = string.find(src, alt, 1, true)','\tassert(a, "nicht gefunden: " .. alt:sub(1, 60))','\tassert(not string.find(src, alt, b + 1, true), "mehrfach: " .. alt:sub(1, 60))','\treturn src:sub(1, a - 1) .. neu .. src:sub(b + 1)','end',
f'local s = {modul}','local src = s.Source', f'assert(#src == {len(alt.encode())}, "Ausgangsstand passt nicht: " .. #src)']
for a,b in paare: lu.append("src = ersetze(src, "+L(a)+", "+L(b)+")")
lu += [f'assert(#src == {len(neu.encode())}, "Ergebnis-Länge falsch: " .. #src)','s.Source = src','return s.Name .. ": " .. #src .. " Zeichen"']
open(sys.argv[4],"w").write("\n".join(lu))
print(len(paare),"Paare", len("\n".join(lu)),"Zeichen")
