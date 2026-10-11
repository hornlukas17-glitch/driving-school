local letzte = {}
M.log = function(name, p, info) if name == "FireClient Fahrstunde" and type(info) == "table" and info.typ ~= "ziel" then print("  event:", info.typ, info.text or info.betrag or info.menge or "", info.grund or "") end end
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
frage("dev", { befehl = "lizenz" })
frage("adminGeld", 20000)
M.laufen(M.zeit() + 14)
print("buy zipster:", frage("autoKaufen", "kleinwagen").text ~= nil)
p.Character:PivotTo(CFrame.new(360, 3, 30))
print("get:", frage("autoHolen", { typ = "kleinwagen", farbe = 2 }).text)
local auto = workspace.Auto_Lukas
print("plate:", auto:GetAttribute("Kennzeichen"))
auto.Fahrersitz:Sit(p.Character.Humanoid)
p.Character.Humanoid.SeatPart = auto.Fahrersitz
-- drive through the speed camera on the country road at 95 km/h (limit 50? -> check)
local function blitzer(n)
	for i = 1, n do
		if not auto.Parent or not auto:FindFirstChild("Chassis") then return end
		auto.Chassis.CFrame = CFrame.new(365 + (i % 2) * 40, 2, 5.5)
		auto.Chassis.AssemblyLinearVelocity = Vector3.new(-140, 0, 0)
		M.laufen(M.zeit() + 0.3)
		auto.Chassis.CFrame = CFrame.new(365, 2, 5.5)
		M.laufen(M.zeit() + 7)
	end
end
blitzer(1)
local a = frage("akte")
print("points:", a.punkte, "history:", a.historie[1] and a.historie[1].text, "money", p:GetAttribute("Geld"))
blitzer(4)
a = frage("akte")
print("after more: points", a.punkte, "license", a.fuehrerschein, "withdrawn", a.entzogen, "car gone", workspace:FindFirstChild("Auto_Lukas") == nil)
print("get car w/o license:", frage("autoHolen", { typ = "kleinwagen" }).fehler)
print("exam before course:", frage("pruefungStarten").fehler)
print("course:", frage("nachschulung").ok)
M.laufen(M.zeit() + 1)
print("exam:", frage("pruefungStarten").text ~= nil)
-- level / weather attributes
print("level:", p:GetAttribute("Level"), "xp:", p:GetAttribute("XP"), "weather:", game.ReplicatedStorage.Fuehrerschein:GetAttribute("Wetter"), "time:", math.floor(game.ReplicatedStorage.Fuehrerschein:GetAttribute("Uhrzeit") or -1))
print("showroom:", #workspace.Karte.Vorstadt.Autohaus:GetChildren(), workspace.Karte.Vorstadt.Autohaus:FindFirstChild("Ausstellung_supersport") ~= nil)
print("errors", M.fehler or 0)
