import os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FS = os.path.join(ROOT, "src")
V = open(os.path.join(ROOT, "VERSION")).read().strip()
DIST = os.path.join(ROOT, "dist")
os.makedirs(DIST, exist_ok=True)
for alt in os.listdir(DIST):
    if os.path.isfile(os.path.join(DIST, alt)):  # alte Installer weg, dist/mesh bleibt
        os.remove(os.path.join(DIST, alt))
def src(n):
    s = open(os.path.join(FS, n)).read().replace("v{VERSION}", "v" + V)
    assert "]=====]" not in s
    return s
out = ('''-- =====================================================================
--  DRIVER'S LICENSE SYSTEM v{V}
--  (receptionist, theory test, 5 driving lessons, driving test, truck license,
--   truck jobs with levels, pizza job, villas, car dealership, police, speed cameras + penalty points, day/night + weather, XP, Drive Coins, NPC traffic)
--  Run once in the command bar (no test may be running).
--  The map from stadt_generator.lua must exist first.
--  Running it again replaces the old version.
-- =====================================================================
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local SPS = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")

for _, alt in { RS:FindFirstChild("Fuehrerschein"), SSS:FindFirstChild("FuehrerscheinServer"), SPS:FindFirstChild("FuehrerscheinClient") } do
	if alt then alt:Destroy() end
end

local function neu(klasse, name, eltern, quelle)
	local o = Instance.new(klasse)
	o.Name = name
	if quelle then o.Source = quelle end
	o.Parent = eltern
	return o
end

local ordner = neu("Folder", "Fuehrerschein", RS)
neu("RemoteFunction", "Aktion", ordner)
neu("RemoteEvent", "Oeffnen", ordner)
neu("RemoteEvent", "Fahrstunde", ordner)
neu("RemoteEvent", "Blinker", ordner)
neu("RemoteEvent", "VerkehrDaten", ordner)
neu("ModuleScript", "Verkehrsregeln", ordner, [=====[
''' + src("Verkehrsregeln.lua") + ''']=====])
neu("ModuleScript", "Verkehr", ordner, [=====[
''' + src("Verkehr.lua") + ''']=====])
neu("ModuleScript", "Motorklaenge", ordner, [=====[
''' + src("Motorklaenge.lua") + ''']=====])
neu("ModuleScript", "Motorsound", ordner, [=====[
''' + src("Motorsound.lua") + ''']=====])
neu("ModuleScript", "Hupen", ordner, [=====[
''' + src("Hupen.lua") + ''']=====])
neu("ModuleScript", "BetaClient", ordner, [=====[
''' + src("BetaClient.lua") + ''']=====])
neu("ModuleScript", "SpassClient", ordner, [=====[
''' + src("SpassClient.lua") + ''']=====])
neu("ModuleScript", "LeisteStil", ordner, [=====[
''' + src("LeisteStil.lua") + ''']=====])

local server = Instance.new("Script")
server.Name = "FuehrerscheinServer"
server.Source = [=====[
''' + src("Server.lua") + ''']=====]
neu("ModuleScript", "Fragen", server, [=====[
''' + src("Fragen.lua") + ''']=====])
neu("ModuleScript", "Auto", server, [=====[
''' + src("Auto.lua") + ''']=====])
neu("ModuleScript", "Fahrstunden", server, [=====[
''' + src("Fahrstunden.lua") + ''']=====])
neu("ModuleScript", "Strafen", server, [=====[
''' + src("Strafen.lua") + ''']=====])
neu("ModuleScript", "Umwelt", server, [=====[
''' + src("Umwelt.lua") + ''']=====])
neu("ModuleScript", "Fahrzeugpflege", server, [=====[
''' + src("Fahrzeugpflege.lua") + ''']=====])
neu("ModuleScript", "Missionen", server, [=====[
''' + src("Missionen.lua") + ''']=====])
neu("ModuleScript", "Shop", server, [=====[
''' + src("Shop.lua") + ''']=====])
neu("ModuleScript", "Belohnungen", server, [=====[
''' + src("Belohnungen.lua") + ''']=====])
neu("ModuleScript", "Chaos", server, [=====[
''' + src("Chaos.lua") + ''']=====])
neu("ModuleScript", "Party", server, [=====[
''' + src("Party.lua") + ''']=====])
neu("ModuleScript", "Beta", server, [=====[
''' + src("Beta.lua") + ''']=====])
neu("ModuleScript", "Zonen", server, [=====[
''' + src("Zonen.lua") + ''']=====])
neu("ModuleScript", "Spass", server, [=====[
''' + src("Spass.lua") + ''']=====])
neu("ModuleScript", "Karosserien", server, [=====[
''' + src("Karosserien.lua") + ''']=====])
server.Parent = SSS

neu("LocalScript", "FuehrerscheinClient", SPS, [=====[
''' + src("Client.lua") + ''']=====])

-- Allow zooming into first person
local SP = game:GetService("StarterPlayer")
SP.CameraMinZoomDistance = 0.5
SP.CameraMaxZoomDistance = 60

print("License system v{V} installed. Press F5 to test.")
''').replace("{V}", V)
open(os.path.join(DIST, "fuehrerschein_installer.lua"), "w").write(out)
print(len(out), "bytes")


# ---------------------------------------------------------------------
# .rbxmx model file: drag into Studio, then run the short mover line
# ---------------------------------------------------------------------
import html
ref = [0]
def item(klasse, name, kinder=(), quelle=None, disabled=None):
    ref[0] += 1
    props = f'<string name="Name">{html.escape(name)}</string>'
    if quelle is not None:
        assert "]]>" not in quelle
        props += f'<ProtectedString name="Source"><![CDATA[{quelle}]]></ProtectedString>'
    if disabled is not None:
        props += f'<bool name="Disabled">{"true" if disabled else "false"}</bool>'
    return f'<Item class="{klasse}" referent="RBX{ref[0]}"><Properties>{props}</Properties>' + "".join(kinder) + '</Item>'
rs = item("Folder", "Fuehrerschein", [
    item("RemoteFunction", "Aktion"), item("RemoteEvent", "Oeffnen"), item("RemoteEvent", "Fahrstunde"),
    item("RemoteEvent", "Blinker"), item("RemoteEvent", "VerkehrDaten"),
    item("ModuleScript", "Verkehrsregeln", quelle=src("Verkehrsregeln.lua")),
    item("ModuleScript", "Verkehr", quelle=src("Verkehr.lua")),
    item("ModuleScript", "Motorklaenge", quelle=src("Motorklaenge.lua")),
    item("ModuleScript", "Motorsound", quelle=src("Motorsound.lua")),
    item("ModuleScript", "Hupen", quelle=src("Hupen.lua")),
    item("ModuleScript", "BetaClient", quelle=src("BetaClient.lua")),
    item("ModuleScript", "SpassClient", quelle=src("SpassClient.lua")),
    item("ModuleScript", "LeisteStil", quelle=src("LeisteStil.lua")),
])
server = item("Script", "FuehrerscheinServer", [
    item("ModuleScript", n, quelle=src(n + ".lua")) for n in ["Fragen", "Auto", "Fahrstunden", "Strafen", "Umwelt", "Fahrzeugpflege", "Missionen", "Shop", "Belohnungen", "Chaos", "Party", "Beta", "Zonen", "Spass", "Karosserien"]
], quelle=src("Server.lua"), disabled=True)
client = item("LocalScript", "FuehrerscheinClient", quelle=src("Client.lua"))
modell = item("Folder", "DrivingSchoolInstall", [rs, server, client])
xml = ('<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
       'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">' + modell + '</roblox>')
open(os.path.join(DIST, f"DrivingSchool_v{V}.rbxmx"), "w").write(xml)
print("rbxmx", len(xml), "bytes")
