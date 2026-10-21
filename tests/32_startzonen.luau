-- v58: 🟢 two green start zones in front of the driving school (Blind Drive 2 players, Party test 2–4 players).
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
local function letztes(wer, typ, pruef)
	for i = #events, 1, -1 do
		local x = events[i]
		if x.p == wer and x.info.typ == typ and (not pruef or pruef(x.info)) then return x.info end
	end
end
local Zonen = require(SSS.FuehrerscheinServer.Zonen)
local Party = require(SSS.FuehrerscheinServer.Party)

local ordner = workspace:FindFirstChild("Startzonen")
pruefe("zones built", ordner ~= nil and ordner:FindFirstChild("BlindDrive") ~= nil and ordner:FindFirstChild("PartyTest") ~= nil)
local blind, party = Zonen.liste()[1], Zonen.liste()[2]
pruefe("sign shows 0/2", blind.status.Text == "0/2 PLAYERS")
pruefe("party sign shows 0/4", party.status.Text == "0/4 PLAYERS")
local spawn = workspace.FahrschulSpawn
pruefe("zones close to the spawn, not on top of it", (blind.pos - spawn.Position).Magnitude < 16 and (blind.pos - spawn.Position).Magnitude > 7)

local a = M.spielerErzeugen("Lukas", 3001)
local b = M.spielerErzeugen("Fabi", 3002)
local c = M.spielerErzeugen("Mia", 3003)
M.laufen(M.zeit() + 3)
local function stellen(p, z, dx)
	p.Character:PivotTo(CFrame.new(z.pos + Vector3.new(dx or 0, 3, 0)))
end
local function weg(p) p.Character:PivotTo(CFrame.new(spawn.Position + Vector3.new(0, 3, 30))) end

-- 1) one player in the blind zone: waits, sign 1/2, hint
stellen(a, blind)
M.laufen(M.zeit() + 1)
pruefe("sign shows 1/2", blind.status.Text == "1/2 PLAYERS")
pruefe("player gets a waiting hint", letztes(a, "hinweis", function(i) return i.text:find("second player") ~= nil end) ~= nil)
pruefe("nothing started alone", workspace:FindFirstChild("Fahrschulauto_Lukas") == nil)
-- leaving the zone -> 0/2
weg(a)
M.laufen(M.zeit() + 1)
pruefe("leaving: back to 0/2", blind.status.Text == "0/2 PLAYERS")

-- 2) two players: the first one drives, the second one is co-pilot, both in the car
stellen(a, blind, -1)
M.laufen(M.zeit() + 1)
stellen(b, blind, 1)
M.laufen(M.zeit() + 5)
local auto = workspace:FindFirstChild("Fahrschulauto_Lukas")
pruefe("blind drive started for the first player", auto ~= nil)
local sitz = auto and auto:FindFirstChildWhichIsA("VehicleSeat")
local bf = auto and auto:FindFirstChild("Beifahrersitz")
pruefe("first player drives", sitz ~= nil and sitz.Occupant == a.Character.Humanoid)
pruefe("second player is co-pilot", bf ~= nil and bf.Occupant == b.Character.Humanoid)
pruefe("co-pilot is told", letztes(b, "chaos", function(i) return i.titel:find("CO%-PILOT") ~= nil end) ~= nil)
pruefe("zone empty again", blind.status.Text == "0/2 PLAYERS" and #blind.drin == 0)

-- 3) busy players (in a lesson) don't count
local zahlVorher = #blind.drin
stellen(a, blind)
M.laufen(M.zeit() + 1)
pruefe("busy / seated player not counted", #blind.drin == zahlVorher)

-- 4) party zone: 1 player is enough in Studio/mock (minimum 1) -> countdown -> race starts, player in the car
pruefe("party minimum in studio = 1", Party.minimum() == 1)
stellen(c, party)
M.laufen(M.zeit() + 1)
pruefe("party sign 1/4 with countdown: " .. party.info.Text, party.status.Text == "1/4 PLAYERS" and party.info.Text:find("Starts in") ~= nil)
weg(c)
M.laufen(M.zeit() + 1)
pruefe("leaving stops the countdown", party.ende == nil)
stellen(c, party)
M.laufen(M.zeit() + Zonen.PARTY_COUNTDOWN + 3)
local _, rennen = Party.zustand()
pruefe("party race started", rennen ~= nil and table.find(rennen.spieler, c) ~= nil)
local auto3 = workspace:FindFirstChild("Fahrschulauto_Mia")
local sitz3 = auto3 and auto3:FindFirstChildWhichIsA("VehicleSeat")
pruefe("party driver sits in the car", sitz3 ~= nil and sitz3.Occupant == c.Character.Humanoid)
pruefe("while racing the sign says so", party.info.Text:find("running") ~= nil)
print("start zones ok")
