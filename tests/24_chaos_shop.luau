-- Chaos v44: chaos in your own car, Banana Launcher pass, server-wide fun products, chaos missions + achievements.
local events = {}
M.log = function(name, p, info)
	if name == "FireClient Fahrstunde" and type(info) == "table" then
		table.insert(events, { p = p, info = info })
		if info.typ == "chaos" then print("  ->", p and p.Name, info.titel, info.text or "") end
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
local function pruefe(name, ok) print((ok and "OK  " or "FAIL") .. " " .. name) if not ok then error("check failed: " .. name) end end
local Chaos = require(SSS.FuehrerscheinServer.Chaos)
local aktion = game.ReplicatedStorage.Fuehrerschein.Aktion
local p = M.spielerErzeugen("Lukas")
local p2 = M.spielerErzeugen("Fabi")
M.laufen(M.zeit() + 3)
local function frage(wer, was, e) return aktion.OnServerInvoke(wer, was, e) end
local function letztes(wer, pruef)
	for i = #events, 1, -1 do
		local x = events[i]
		if x.p == wer and x.info.typ == "chaos" and (not pruef or pruef(x.info)) then return x.info end
	end
end

-- 1) Lukas: license, own car, sit in it
frage(p, "dev", { befehl = "lizenz" })
for _ = 1, 30 do frage(p, "dev", { befehl = "geld" }) end
print(frage(p, "autoKaufen", "kleinwagen").text)
print(frage(p, "autoHolen", { typ = "kleinwagen" }).text)
M.laufen(M.zeit() + 1)
local auto = workspace:FindFirstChild("Auto_Lukas")
pruefe("own car is there", auto ~= nil)
local sitz = auto:FindFirstChildWhichIsA("VehicleSeat")
sitz:Sit(p.Character.Humanoid)
M.laufen(M.zeit() + 1)
local a = Chaos.ctx.privatAutos[p]
local chassis = a.chassis
local y = chassis.Position.Y
local function setzen(ch, x, z)
	ch.CFrame = CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(90), 0)
	ch.AssemblyLinearVelocity = Vector3.new(-20, 0, 0)
end
setzen(chassis, 200, -520)
M.laufen(M.zeit() + 0.5)
pruefe("own car gets chaos state (no instructor)", a.chaos ~= nil and a.chaos.frei and next(a.chaos.lehrer) == nil)
a.chaos.naechstesEvent = os.clock() - 1
setzen(chassis, 200, -520)
M.laufen(M.zeit() + 0.4)
pruefe("chaos event while driving your own car", a.chaos.event ~= nil and a.chaos.event.art ~= "gag")
print("  own car event:", a.chaos.event.art)
Chaos.ende(a)
a.chaos.naechstesEvent = math.huge

-- 2) Banana Launcher
local r = frage(p, "bananeWerfen")
pruefe("no pass: hint to the shop", r.fehler and r.fehler:find("Shop") ~= nil)
frage(p, "dev", { befehl = "kauf", key = "banane" })
pruefe("pass sets the attribute for the button", p:GetAttribute("BananenWerfer") == true)
setzen(chassis, 300, -520)
M.laufen(M.zeit() + 0.2)
r = frage(p, "bananeWerfen")
pruefe("banana dropped", r.text ~= nil and #Chaos.schalen == 1)
local schale = Chaos.schalen[1]
pruefe("banana lies behind the car", schale.pos.X > 300)
r = frage(p, "bananeWerfen")
pruefe("cooldown", r.fehler and r.fehler:find("Reloading") ~= nil)
-- 3) Fabi drives over it (lesson car) -> spins, Lukas gets a GOTCHA
frage(p2, "dev", { befehl = "lektion", nr = 1 })
M.laufen(M.zeit() + 2)
local auto2 = workspace:FindFirstChild("Fahrschulauto_Fabi")
auto2.Fahrersitz:Sit(p2.Character.Humanoid)
M.laufen(M.zeit() + 1)
local st2 = Chaos.ctx.lektionen[p2]
st2.chaos.naechstesEvent = math.huge
st2.chassis.CFrame = CFrame.new(schale.pos.X + 30, y, schale.pos.Z)
M.laufen(M.zeit() + 0.3)
st2.chassis.CFrame = CFrame.new(schale.pos.X, y, schale.pos.Z)
M.laufen(M.zeit() + 0.3)
local glatt = letztes(p2, function(i) return i.rutschen ~= nil end)
pruefe("Fabi slips on Lukas' banana", glatt ~= nil and glatt.text:find("Lukas") ~= nil)
pruefe("Lukas gets a GOTCHA", letztes(p, function(i) return i.titel:find("GOTCHA") ~= nil end) ~= nil)
pruefe("no mistakes for Fabi while spinning", Chaos.schonzeit(st2))
pruefe("peel is gone", #Chaos.schalen == 0)
local d = Chaos.ctx.daten
pruefe("statistics: hit + slipped", d[p].chaos.treffer == 1 and d[p2].chaos.banane == 1)

-- 4) server-wide products
local vorher = #events
frage(p, "dev", { befehl = "kauf", key = "ufo" })
M.laufen(M.zeit() + 0.5)
local beamLukas = letztes(p, function(i) return i.entfuehren end)
local beamFabi = letztes(p2, function(i) return i.entfuehren end)
pruefe("Alien Invasion beams up every driver", beamLukas ~= nil and beamFabi ~= nil)
pruefe("everybody sees who called the aliens", letztes(p2, function(i) return i.titel:find("INVASION") ~= nil and i.text:find("Lukas") ~= nil end) ~= nil)
M.laufen(M.zeit() + 10)
pruefe("UFOs gone again", #Chaos.ordner:GetChildren() <= 2)
frage(p, "dev", { befehl = "kauf", key = "bananen" })
M.laufen(M.zeit() + 1)
pruefe("Banana Rain: 4 peels in front of each driver", #Chaos.schalen == 8)
pruefe("everybody gets the banner", letztes(p2, function(i) return i.titel:find("BANANA RAIN") ~= nil end) ~= nil)

-- 5) missions + achievements know the chaos
local Missionen = require(SSS.FuehrerscheinServer.Missionen)
local ids = {}
for _, m in Missionen.ARTEN do ids[m.id] = true end
pruefe("chaos missions exist", ids.ausweichen and ids.banane)
local b = frage(p2, "belohnungen")
local gefunden = {}
for _, e in b.erfolge or {} do gefunden[e.id] = e.wert end
pruefe("chaos achievements", gefunden.lehrer == 1 and gefunden.chaosArten ~= nil and gefunden.bananen ~= nil)
pruefe("shop shows the fun products and the pass", (function()
	local s = frage(p, "shop")
	local fun, pass = 0, false
	for _, pr in s.produkte do if pr.spass then fun += 1 end end
	for _, ps in s.passes do if ps.key == "banane" and ps.hat then pass = true end end
	return fun == 2 and pass
end)())
print("chaos shop ok")
