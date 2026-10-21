-- v55: 🙈 Blind Drive – the driver can't see the route, a friend in the passenger seat (co-pilot) navigates.
local events = {}
M.log = function(name, p, info)
	if name == "FireClient Fahrstunde" and type(info) == "table" then table.insert(events, { p = p, info = info }) end
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
local Beta = require(SSS.FuehrerscheinServer.Beta)
local aktion = game.ReplicatedStorage.Fuehrerschein.Aktion
local function frage(wer, was, e) return aktion.OnServerInvoke(wer, was, e) end
local function letztes(wer, typ, pruef)
	for i = #events, 1, -1 do
		local x = events[i]
		if x.p == wer and x.info.typ == typ and (not pruef or pruef(x.info)) then return x.info end
	end
end

local p = M.spielerErzeugen("Lukas", 2001)
local p2 = M.spielerErzeugen("Fabi", 2002)
local p3 = M.spielerErzeugen("Mia", 2003)
M.laufen(M.zeit() + 3)

-- 1) start: no requirements (a brand-new player can do it), car with a co-pilot seat
local r = frage(p, "blindStarten")
pruefe("blind drive starts: " .. tostring(r.text or r.fehler), r.text ~= nil and r.text:find("Blind") ~= nil)
pruefe("second start refused while running", frage(p, "blindStarten").fehler ~= nil)
local auto = workspace:FindFirstChild("Fahrschulauto_Lukas")
pruefe("car spawned", auto ~= nil)
local beifahrer = auto:FindFirstChild("Beifahrersitz")
local prompt = beifahrer and beifahrer:FindFirstChild("Copilot")
pruefe("passenger seat has 'Be the co-pilot'", prompt ~= nil and prompt.ActionText == "Be the co-pilot")
pruefe("instructor NPC is not in the passenger seat", beifahrer.Occupant == nil)

-- 2) driver alone: the route does not start
local sitz = auto:FindFirstChildWhichIsA("VehicleSeat")
sitz:Sit(p.Character.Humanoid)
M.laufen(M.zeit() + 8)
pruefe("no gate without co-pilot", letztes(p, "ziel") == nil)
pruefe("driver is told to find a co-pilot", letztes(p, "hinweis", function(i) return i.text:find("co%-pilot") ~= nil end) ~= nil)

-- 3) the driver himself can't be the co-pilot; a friend can
prompt.Triggered:Fire(p)
pruefe("driver can't be his own co-pilot", beifahrer.Occupant == nil)
prompt.Triggered:Fire(p2)
M.laufen(M.zeit() + 5)
pruefe("Fabi sits as co-pilot", beifahrer.Occupant == p2.Character.Humanoid)
local zc = letztes(p2, "ziel")
pruefe("co-pilot gets the gate with position + route", zc ~= nil and zc.copilot == true and zc.pos ~= nil and zc.route ~= nil and zc.fahrer == "Lukas")
local zf = letztes(p, "ziel")
pruefe("driver gets NO position / route", zf ~= nil and zf.blind == true and zf.pos == nil and zf.route == nil)
pruefe("driver start says Blind Drive", letztes(p, "start", function(i) return i.titel:find("BLIND") ~= nil end) ~= nil)
-- the co-pilot can use the instructor buttons in this car
pruefe("co-pilot commands reach the driver", frage(p2, "kommando", "links").ok == true and letztes(p, "kommando") ~= nil)
-- a third player can't take the occupied seat
prompt.Triggered:Fire(p3)
pruefe("Mia can't sit on an occupied co-pilot seat", beifahrer.Occupant == p2.Character.Humanoid)

-- 4) co-pilot leaves: the driver sees the route again (no team rating)
local vorher = #events
p2.Character.Humanoid.SeatPart = nil
beifahrer.Occupant = nil
M.laufen(M.zeit() + 1)
local wieder
for i = vorher + 1, #events do
	if events[i].p == p and events[i].info.typ == "ziel" and events[i].info.pos then wieder = events[i].info end
end
pruefe("driver sees the gate again after the co-pilot left", wieder ~= nil)
pruefe("co-pilot gets the 'left' end", letztes(p2, "ende", function(i) return i.blind and i.abbruch end) ~= nil)

-- 5) end: both get the blind result (cancelled = no coins)
frage(p, "fahrstundeAbbrechen")
M.laufen(M.zeit() + 1)
local e = letztes(p, "ende", function(i) return i.blind end)
pruefe("driver gets the blind result", e ~= nil and e.erfolg == false and e.titel ~= nil)

-- 6) team rating
pruefe("0 mistakes = DREAM TEAM", Beta.blindWertung(0, true, true).titel:find("DREAM") ~= nil)
pruefe("5 mistakes = couples therapy", Beta.blindWertung(5, true, true).titel:find("THERAPY") ~= nil)
pruefe("20 mistakes = divorce", Beta.blindWertung(20, true, true).titel:find("DIVORCE") ~= nil)
pruefe("not finished = no coins", Beta.blindWertung(0, false, true).geld == 0)
pruefe("without co-pilot only a few coins", Beta.blindWertung(0, true, false).geld < Beta.blindWertung(0, true, true).geld)
-- 7) 🎲 Find a partner (v56): two players without a friend get matched
local p4 = M.spielerErzeugen("Ben", 2004)
M.laufen(M.zeit() + 3)
local a = frage(p3, "blindPartner")
pruefe("first player waits: " .. tostring(a.text), a.warten == true)
pruefe("others are told someone needs a partner", letztes(p4, "chaos", function(i) return i.titel:find("PARTNER WANTED") ~= nil end) ~= nil)
pruefe("tap again = leave the search", frage(p3, "blindPartner").aus == true)
frage(p3, "blindPartner")
local b = frage(p4, "blindPartner")
pruefe("second player gets matched: " .. tostring(b.text or b.fehler), b.gefunden == true)
M.laufen(M.zeit() + 5)
local auto2 = workspace:FindFirstChild("Fahrschulauto_Mia")
local sitz2 = auto2 and auto2:FindFirstChildWhichIsA("VehicleSeat")
local bf2 = auto2 and auto2:FindFirstChild("Beifahrersitz")
pruefe("waiting player drives", sitz2 ~= nil and sitz2.Occupant == p3.Character.Humanoid)
pruefe("new player is the co-pilot", bf2 ~= nil and bf2.Occupant == p4.Character.Humanoid)
pruefe("co-pilot gets the route", letztes(p4, "ziel", function(i) return i.copilot == true end) ~= nil)
pruefe("driver gets no route", letztes(p3, "ziel", function(i) return i.blind == true and i.pos == nil end) ~= nil)
pruefe("busy players can't search", frage(p3, "blindPartner").fehler ~= nil)
-- 8) wrong way (v56): driving away from the gate -> hint for both
local chassis = auto2:FindFirstChild("Chassis", true) or sitz2
M.laufen(M.zeit() + 1)
local c0 = chassis.CFrame
for i = 1, 6 do
	auto2:PivotTo(c0 + Vector3.new(0, 0, i * 40))
	M.laufen(M.zeit() + 0.5)
	auto2:PivotTo(c0 - Vector3.new(0, 0, i * 40))
	M.laufen(M.zeit() + 0.5)
end
pruefe("driver gets WRONG WAY", letztes(p3, "chaos", function(i) return i.titel:find("WRONG WAY") ~= nil end) ~= nil)
pruefe("co-pilot gets WRONG WAY", letztes(p4, "chaos", function(i) return i.titel:find("WRONG WAY") ~= nil end) ~= nil)
print("blind drive ok")
