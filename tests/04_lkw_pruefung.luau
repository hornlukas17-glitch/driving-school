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
require(game.ReplicatedStorage.Fuehrerschein.Verkehr).fahrzeuge = {}
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

-- 1) truck test
print("== truck test")
print(frage("dev", { befehl = "lizenz" }).text)
M.laufen(M.zeit() + 14)
local r = frage("dev", { befehl = "lkw" })
print("start:", r.text or r.fehler)
local lkw = workspace:FindFirstChild("Fahrschul_Lkw_Lukas")
print("truck model:", lkw ~= nil, lkw and lkw:GetAttribute("MaxTempo"))
lkw.Fahrersitz:Sit(hum)
M.laufen(M.zeit() + 8)
print("first gate:", letzteZiel and tostring(letzteZiel.pos), letzteZiel and letzteZiel.text)
local fertig = fahreRoute(lkw, 60)
M.laufen(M.zeit() + 15)
print("truck test finished:", fertig, "LKW license:", p:GetAttribute("LkwFuehrerschein"), "money:", p:GetAttribute("Geld"))
hum.SeatPart = nil

-- 2) delivery job
print("== job")
letzteZiel = nil
r = frage("jobStarten")
print("job:", r.text or r.fehler)
local job = workspace:FindFirstChild("Paket_Lkw_Lukas")
job.Fahrersitz:Sit(hum)
M.laufen(M.zeit() + 6)
for paket = 1, 3 do
	local z = letzteZiel
	print("  drive to", tostring(z.pos), z.text, z.status)
	job.Chassis.CFrame = CFrame.new(z.pos + Vector3.new(0, 2, 0))
	M.laufen(M.zeit() + 1)
	print("  after stop:", letzteZiel.text)
	-- get out
	job.Fahrersitz.Occupant = nil
	hum.SeatPart = nil
	M.laufen(M.zeit() + 1)
	-- try to deliver without a package
	local kunde = workspace:FindFirstChild("Kunde")
	print("  customer there:", kunde ~= nil)
	kunde.HumanoidRootPart.ProximityPrompt.Triggered:Fire(p)
	M.laufen(M.zeit() + 0.5)
	-- take package from the rear door
	local pp = job.Heckklappe.ProximityPrompt
	print("  rear prompt enabled:", pp.Enabled)
	pp.Triggered:Fire(p)
	M.laufen(M.zeit() + 0.5)
	print("  package in hand:", p.Character:FindFirstChild("Package") ~= nil)
	kunde.HumanoidRootPart.ProximityPrompt.Triggered:Fire(p)
	M.laufen(M.zeit() + 0.5)
	print("  money:", p:GetAttribute("Geld"), "package gone:", p.Character:FindFirstChild("Package") == nil)
	job.Fahrersitz:Sit(hum)
	M.laufen(M.zeit() + 3)
end
print("  phase text:", letzteZiel.text)
fertig = fahreRoute(job, 10)
M.laufen(M.zeit() + 5)
print("job done:", fertig, "money:", p:GetAttribute("Geld"))
print("errors", M.fehler or 0)
