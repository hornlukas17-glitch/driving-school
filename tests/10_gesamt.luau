M.log = function(name, p, info) if name == "FireClient Fahrstunde" and type(info) == "table" and info.typ ~= "ziel" and info.typ ~= "xp" then print("  event:", info.typ, info.text or info.betrag or "", info.grund or "") end end
lade("gen", Q.gen)()
lade("inst", Q.inst)()
for _, s in game:GetService("ServerScriptService"):GetChildren() do if s:IsA("Script") then task.spawn(lade(s.Name, s.Source, { script = s })) end end
for _, s in workspace:GetDescendants() do if s:IsA("Script") then task.spawn(lade(s.Name, s.Source, { script = s })) end end
M.laufen(2)
local p = M.spielerErzeugen("Lukas")
local cl = game:GetService("StarterPlayer").StarterPlayerScripts.FuehrerscheinClient
task.spawn(lade("client", cl.Source, { script = cl }))
M.laufen(6)
local aktion = game.ReplicatedStorage.Fuehrerschein.Aktion
local function frage(was, e) return aktion.OnServerInvoke(p, was, e) end
local hum = p.Character.Humanoid
print("parking garage:", workspace.Karte.Gebaeude:FindFirstChild("Parkhaus") ~= nil, "service:", workspace.Karte.Service:FindFirstChild("Servicestation") ~= nil, "boards:", #workspace.Karte.Service.Bestenlisten:GetChildren())
frage("dev", { befehl = "lizenz" })
frage("adminGeld", 20000)
M.laufen(M.zeit() + 14)
frage("autoKaufen", "sport")
p.Character:PivotTo(CFrame.new(375, 3, -50))
print("get:", frage("autoHolen", { typ = "sport", farbe = 1 }).text)
local auto = workspace.Auto_Lukas
print("tank attr:", auto:GetAttribute("Tank"), "zustand:", auto:GetAttribute("Zustand"))
auto.Fahrersitz:Sit(hum)
-- drive 3 km (teleport steps of 40 studs)
local pos = auto.Chassis.Position
for i = 1, 300 do
	pos = pos + Vector3.new(0, 0, 0) + Vector3.new(i % 2 == 0 and 35 or -35, 0, 0)
	auto.Chassis.CFrame = CFrame.new(pos)
	M.laufen(M.zeit() + 0.12)
end
print("tank after driving:", auto:GetAttribute("Tank"))
-- crash
auto.Chassis.AssemblyLinearVelocity = Vector3.new(0, 0, 80)
M.laufen(M.zeit() + 0.15)
auto.Chassis.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
M.laufen(M.zeit() + 0.3)
print("condition after crash:", auto:GetAttribute("Zustand"))
-- refuel at the pump
local saeule
for _, t in workspace.Karte.Service.Servicestation:GetChildren() do if t:GetAttribute("Zapfsaeule") then saeule = t break end end
auto.Chassis.CFrame = CFrame.new(saeule.Position + Vector3.new(4, 0, 0))
saeule.ProximityPrompt.Triggered:Fire(p)
M.laufen(M.zeit() + 0.5)
print("tank after refuel:", auto:GetAttribute("Tank"))
-- workshop
local w = frage("werkstattInfo")
print("workshop cars:", #w.autos, "repair cost:", w.autos[1].reparatur)
print("repair:", frage("werkstatt", { art = "reparieren", typ = "sport" }).text)
print("insure:", frage("werkstatt", { art = "versichern", typ = "sport" }).text)
print("engine:", frage("werkstatt", { art = "motor", typ = "sport" }).text, "maxTempo:", auto:GetAttribute("MaxTempo"))
print("neon:", frage("werkstatt", { art = "neon", typ = "sport", wert = 2 }).text, "spoiler:", frage("werkstatt", { art = "spoiler", typ = "sport" }).text)
local tuning = 0
for _, t in auto:GetChildren() do if t.Name:sub(1, 7) == "Tuning_" then tuning += 1 end end
print("tuning parts:", tuning)
-- missions
local m = frage("missionen")
for _, x in m.liste do print("  mission:", x.text, x.stand, "/", x.ziel) end
-- withdrawal keeps the car, player becomes wanted
hum.SeatPart = auto.Fahrersitz
for i = 1, 6 do
	auto.Chassis.CFrame = CFrame.new(-345, 2, 5.5)
	auto.Chassis.AssemblyLinearVelocity = Vector3.new(-150, 0, 0)
	M.laufen(M.zeit() + 7)
	if not p:GetAttribute("Gesucht") == nil then break end
end
auto.Chassis.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
local a = frage("akte")
print("license:", a.fuehrerschein, "car still there:", workspace:FindFirstChild("Auto_Lukas") ~= nil, "wanted:", p:GetAttribute("Gesucht"))
M.laufen(M.zeit() + 30)
local antwort = frage("kontrolleAntwort", true)
print("police:", antwort.text or antwort.fehler)
M.laufen(M.zeit() + 3)
print("car towed:", workspace:FindFirstChild("Auto_Lukas") == nil, "wanted:", p:GetAttribute("Gesucht"))
-- taxi needs a license -> regain it
frage("dev", { befehl = "lizenz" })
M.laufen(M.zeit() + 14)
local letzteZiel
M.log = function(name, p2, info) if name == "FireClient Fahrstunde" and type(info) == "table" then if info.typ == "ziel" then letzteZiel = info elseif info.typ ~= "xp" then print("  event:", info.typ, info.text or info.betrag or "", info.grund or "") end end end
print("taxi:", frage("taxiStarten").text)
local taxi = workspace:FindFirstChild("Taxi_Lukas")
taxi.Fahrersitz:Sit(hum)
hum.SeatPart = taxi.Fahrersitz
M.laufen(M.zeit() + 6)
for i = 1, 3 do
	taxi.Chassis.CFrame = CFrame.new(letzteZiel.pos + Vector3.new(0, 2, 0))
	M.laufen(M.zeit() + 4)
	print("  phase text:", letzteZiel.text)
	taxi.Chassis.CFrame = CFrame.new(letzteZiel.pos + Vector3.new(0, 2, 0))
	M.laufen(M.zeit() + 1)
end
print("  ", letzteZiel.text)
print("money:", p:GetAttribute("Geld"), "errors", M.fehler or 0)
