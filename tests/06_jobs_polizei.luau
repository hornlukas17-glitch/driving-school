local letzteZiel, events = nil, {}
M.log = function(name, p, info)
	if name == "FireClient Fahrstunde" and type(info) == "table" then
		table.insert(events, info.typ)
		if info.typ == "ziel" then letzteZiel = info end
		if info.typ ~= "ziel" then print("  event:", info.typ, info.text or info.betrag or "", info.grund or "") end
	end
end
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
M.laufen(3)
-- press PLAY on the start screen
local menue = p.PlayerGui:FindFirstChild("Startbildschirm")
for _, k in menue:GetChildren() do if k.Text == "PLAY" then k.Activated:Fire() end end
M.laufen(M.zeit() + 5)
print("menu gone:", p.PlayerGui:FindFirstChild("Startbildschirm") == nil, "coins gui:", p.PlayerGui:FindFirstChild("Geld") and p.PlayerGui.Geld.Enabled)
local aktion = game.ReplicatedStorage.Fuehrerschein.Aktion
local function frage(was, e) return aktion.OnServerInvoke(p, was, e) end
local hum = p.Character.Humanoid

local zuletzt
local function fahreRoute(modell, maxSchritte)
	local chassis = modell.Chassis
	for i = 1, maxSchritte do
		M.laufen(M.zeit() + 0.5)
		if not modell.Parent then return true end
		local z = letzteZiel
		if z ~= zuletzt then print("   ziel", z and z.nr, z and tostring(z.pos), z and z.text) zuletzt = z end
		if z and z.park then
			-- park in the first bay
			local b = z.park[1]
			chassis.CFrame = b.cf + Vector3.new(0, 2, 0)
		elseif z and z.pos then
			chassis.CFrame = CFrame.lookAt(z.pos + Vector3.new(0, 2, 0), z.pos + Vector3.new(0, 2, 0) + z.richtung)
		end
	end
	return false
end

print(frage("dev", { befehl = "lizenz" }).text)
M.laufen(M.zeit() + 14)
print("== pizza")
local r = frage("pizzaStarten")
print("pizza:", r.text or r.fehler)
local auto = workspace:FindFirstChild("Pizza_Auto_Lukas")
auto.Fahrersitz:Sit(hum)
M.laufen(M.zeit() + 6)
for i = 1, 3 do
	local z = letzteZiel
	print("  drive to", tostring(z.pos), tostring(z.haus), z.status)
	auto.Chassis.CFrame = CFrame.new(z.pos + Vector3.new(0, 2, 0))
	M.laufen(M.zeit() + 1)
	auto.Fahrersitz.Occupant = nil
	hum.SeatPart = nil
	M.laufen(M.zeit() + 1)
	local kunde = workspace:FindFirstChild("Kunde")
	local pp = auto.Kofferraumdeckel.ProximityPrompt
	pp.Triggered:Fire(p)
	M.laufen(M.zeit() + 0.5)
	print("  pizza in hand:", p.Character:FindFirstChild("Pizza") ~= nil, "customer y:", kunde and math.floor(kunde.HumanoidRootPart.Position.Y * 10) / 10)
	kunde.HumanoidRootPart.ProximityPrompt.Triggered:Fire(p)
	M.laufen(M.zeit() + 0.5)
	print("  money:", p:GetAttribute("Geld"))
	auto.Fahrersitz:Sit(hum)
	M.laufen(M.zeit() + 3)
end
print("  ", letzteZiel.text)
print("pizza done:", fahreRoute(auto, 10), "money:", p:GetAttribute("Geld"))
hum.SeatPart = nil

print("== villa")
for i = 1, 10 do frage("dev", { befehl = "geld" }) end
M.laufen(M.zeit() + 2)
print("buy:", frage("villaKaufen", "Villa1").text, "money:", p:GetAttribute("Geld"))
local villa = workspace.Karte.Villen.Villa1
print("sign:", villa.Verkaufsschild:FindFirstChildOfClass("SurfaceGui"):FindFirstChildOfClass("TextLabel").Text)
villa.VillaTuer.ProximityPrompt.Triggered:Fire(p)
M.laufen(M.zeit() + 0.5)
print("door open:", villa.VillaTuer.CanCollide == false)
workspace.Karte.Villen.Villa2.VillaTuer.ProximityPrompt.Triggered:Fire(p)
M.laufen(M.zeit() + 6)

print("== v52: no police")
local r2 = frage("pizzaStarten")
local auto2 = workspace:FindFirstChild("Pizza_Auto_Lukas")
auto2.Fahrersitz:Sit(hum)
-- drive far too fast for a while: nobody stops you any more (speed cameras still work elsewhere)
auto2.Chassis.CFrame = CFrame.new(-345, 2, 5.5)
auto2.Chassis.AssemblyLinearVelocity = Vector3.new(-150, 0, 0)
M.laufen(M.zeit() + 240)
local V = require(game.ReplicatedStorage.Fuehrerschein.Verkehr)
local pol = 0
for _, f in V.fahrzeuge do if f.art == "polizei" then pol += 1 end end
local function check(name, ok) print((ok and "OK  " or "FAIL") .. " " .. name) if not ok then error("check failed: " .. name) end end
check("no police cars in the traffic", pol == 0)
check("no checkpoint was built", #workspace.Polizei:GetChildren() == 0)
check("no police stop", frage("kontrolleAntwort", true).fehler ~= nil)
check("pizza car still there", auto2.Parent ~= nil)
print("errors", M.fehler or 0)
