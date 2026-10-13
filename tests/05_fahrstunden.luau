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

for nr = 1, 6 do
	letzteZiel = nil
	local r = frage("dev", { befehl = "lektion", nr = nr })
	print("== lesson", nr, r.text or r.fehler)
	local auto = workspace:FindFirstChild("Fahrschulauto_Lukas")
	auto.Fahrersitz:Sit(hum)
	M.laufen(M.zeit() + 8)
	local ok = fahreRoute(auto, 60)
	hum.SeatPart = nil
	print("   finished:", ok, "lessons:", p:GetAttribute("Fahrstunden"), "money:", p:GetAttribute("Geld"))
	M.laufen(M.zeit() + 6)
end
local r = frage("dev", { befehl = "pruefung" })
print("== exam", r.text or r.fehler)
local auto = workspace:FindFirstChild("Fahrschulauto_Lukas")
auto.Fahrersitz:Sit(hum)
M.laufen(M.zeit() + 8)
print("   finished:", fahreRoute(auto, 60), "license:", p:GetAttribute("Fuehrerschein"))
hum.SeatPart = nil
M.laufen(M.zeit() + 15)
print("money", p:GetAttribute("Geld"), "errors", M.fehler or 0)
