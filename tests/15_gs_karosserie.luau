-- Sport sedan "Vanta GS" (Lukas' Meshy model): outdoor podium, block body without model, round body with light bar meshes, indicators, light switch, spoiler tuning
M.log = function() end
lade("gen", Q.gen)()
M.laufen(1)
lade("inst", Q.inst)()
local SSS = game:GetService("ServerScriptService")
for _, s in workspace:GetDescendants() do if s:IsA("Script") then task.spawn(lade(s.Name, s.Source, { script = s })) end end
for _, s in SSS:GetChildren() do if s:IsA("Script") then task.spawn(lade(s.Name, s.Source, { script = s })) end end
M.laufen(2)
local p = M.spielerErzeugen("Lukas")
local cl = game:GetService("StarterPlayer").StarterPlayerScripts.FuehrerscheinClient
task.spawn(lade("client", cl.Source, { script = cl }))
M.laufen(6)
local aktion = game.ReplicatedStorage.Fuehrerschein.Aktion
local function frage(was, e) return aktion.OnServerInvoke(p, was, e) end
local function pruefe(name, ok) print((ok and "OK  " or "FAIL") .. " " .. name) if not ok then error("check failed: " .. name) end end
frage("dev", { befehl = "lizenz" })
frage("adminGeld", 20000)
frage("adminGeld", 20000)
M.laufen(M.zeit() + 15)
pruefe("showroom podium", workspace.Karte.Vorstadt.Autohaus:FindFirstChild("Ausstellung_gs") ~= nil)
local kauf = frage("autoKaufen", "gs")
print("buy:", kauf and (kauf.text or kauf.fehler))
p.Character:PivotTo(CFrame.new(60, 3, -376))

-- 1) without the imported model: block body as before
local r = frage("autoHolen", { typ = "gs", farbe = 2 })
local a = workspace:FindFirstChild("Auto_Lukas")
pruefe("block gs built", a ~= nil and a:FindFirstChild("Seitenscheiben") ~= nil and a:FindFirstChild("Rund_Glas") == nil)
frage("autoWeg")
M.laufen(M.zeit() + 1)

-- 2) imported model "RangerX" in ServerStorage (like the 3D importer makes it)
local K = require(game.ServerScriptService.FuehrerscheinServer.Karosserien).gs
local vorlage = Instance.new("Model")
vorlage.Name = "VantaGS"
local namen = {}
for n in K.mesh do table.insert(namen, n) end
for _, n in namen do
	local mp = Instance.new("MeshPart")
	mp.Name = n
	mp.Parent = vorlage
end
vorlage.Parent = game:GetService("ServerStorage")
r = frage("autoHolen", { typ = "gs", farbe = 2 })
local n = 0 for _, x in workspace:GetChildren() do if x.Name == "Auto_Lukas" then n += 1 a = x end end
print("cars:", n)
pruefe("round gs built: " .. tostring(r.text or r.fehler), a ~= nil)
local zahl = function(name) local n = 0 for _, t in a:GetChildren() do if t.Name == name then n += 1 end end return n end
for _, t in a:GetChildren() do if t.ClassName == "MeshPart" or t.Name:find("Rund") or t.Name == "Karosserie" then print("  part", t.Name, t.ClassName) end end
pruefe("mesh parts", a:FindFirstChild("Karosserie").ClassName == "MeshPart" and a:FindFirstChild("Rund_Glas") ~= nil and a:FindFirstChild("Rund_Verkleidung") ~= nil and a:FindFirstChild("Rund_Heckpartie") ~= nil and a:FindFirstChild("Radhaus") ~= nil)
pruefe("no block windows", a:FindFirstChild("Seitenscheiben") == nil)
local function mesh(name) local n = 0 for _, t in a:GetChildren() do if t.Name == name and t.ClassName == "MeshPart" then n += 1 end end return n end
pruefe("surface headlights", mesh("Scheinwerfer") == 2 and a:FindFirstChild("Scheinwerfer"):FindFirstChildOfClass("SpotLight") ~= nil)
local spot = a:FindFirstChild("Scheinwerfer"):FindFirstChildOfClass("SpotLight")
local sw = a:FindFirstChild("Scheinwerfer")
local vorwaerts = sw.CFrame:VectorToWorldSpace(spot.Face == Enum.NormalId.Back and Vector3.new(0, 0, 1) or Vector3.new(0, 0, -1))
pruefe("headlights shine forward", vorwaerts:Dot(a.Chassis.CFrame.LookVector) > 0.9)
pruefe("surface tail lights", mesh("Ruecklicht") == 2)
pruefe("surface indicators", mesh("BlinkerL") == 2 and mesh("BlinkerR") == 2)
pruefe("spoke rims", zahl("Felge") >= 4 * 10 and zahl("Bremssattel") == 4)
local K = require(game.ServerScriptService.FuehrerscheinServer.Karosserien).gs
local g = K.mesh.Karosserie.groesse
pruefe("body size", (a.Karosserie.Size - Vector3.new(g[1], g[2], g[3])).Magnitude < 0.01)
local rel = a.Chassis.CFrame:PointToObjectSpace(a.Fahrersitz.Position)
pruefe("low seat", math.abs(rel.Y - (K.sitzY - 1.4)) < 0.01)
local arm = a.Chassis.CFrame:PointToObjectSpace(a.Armaturenbrett.Position)
pruefe("dashboard behind the windshield", math.abs(arm.Z - K.armaturenZ) < 0.01)
pruefe("headlights with light", zahl("Scheinwerfer") == 2 and a.Scheinwerfer:FindFirstChildOfClass("SpotLight") ~= nil)
pruefe("indicators", zahl("BlinkerL") == 2 and zahl("BlinkerR") == 2)
pruefe("tail lights", zahl("Ruecklicht") == 2)
pruefe("colliders", zahl("Kollision") == 2)
pruefe("plates", zahl("Kennzeichen") == 2)
pruefe("wheels", zahl("Rad") == 4)
pruefe("seat", a:FindFirstChild("Fahrersitz") ~= nil)
-- mesh parts must not collide (the wheels may never hit the body)
for _, t in a:GetChildren() do
	if t:IsA("MeshPart") then pruefe("no collision " .. t.Name, t.CanCollide == false and t.Massless == true) end
end
-- light switch and indicators work
a.Fahrersitz:Sit(p.Character.Humanoid)
M.laufen(M.zeit() + 1)
game.ReplicatedStorage.Fuehrerschein.Blinker.OnServerEvent:Fire(p, "licht")
M.laufen(M.zeit() + 0.5)
pruefe("lights off", a.Scheinwerfer:FindFirstChildOfClass("SpotLight").Enabled == false)
game.ReplicatedStorage.Fuehrerschein.Blinker.OnServerEvent:Fire(p, "links")
M.laufen(M.zeit() + 1)
pruefe("indicator set", a:GetAttribute("Blinker") == "links")
-- spoiler tuning sits on the roof
local t = frage("werkstatt", { art = "spoiler", typ = "gs" })
M.laufen(M.zeit() + 1)
local auto = workspace:FindFirstChild("Auto_Lukas")
local sp = auto and auto:FindFirstChild("Tuning_Spoiler")
print("tuning:", t and (t.text or t.fehler))
if sp then
	rel = auto.Chassis.CFrame:PointToObjectSpace(sp.Position)
	print("spoiler rel", rel)
	pruefe("trunk wing", rel.Y > 2.5 and rel.Z > 6)
	local n = 0 for _, x in auto:GetChildren() do if x.Name == "Tuning_Spoilerstuetze" then n += 1 end end
	pruefe("wing supports", n == 2)
end
print("done")
