-- v45: friends ride along, horn (+ Funny Horn Pack), Worst Drivers leaderboard, party test for up to 4, more gags.
local events, alle = {}, {}
M.log = function(name, p, info)
	if name == "FireClient Fahrstunde" and type(info) == "table" then
		table.insert(events, { p = p, info = info })
		if info.typ == "chaos" or info.typ == "party" then print("  ->", p and p.Name, info.typ, info.phase or "", info.titel, info.text or "") end
	elseif name == "FireAllClients Fahrstunde" and type(info) == "table" then
		table.insert(alle, info)
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
local Party = require(SSS.FuehrerscheinServer.Party)
local Hupen = require(game.ReplicatedStorage.Fuehrerschein.Hupen)
local aktion = game.ReplicatedStorage.Fuehrerschein.Aktion
local p = M.spielerErzeugen("Lukas")
local p2 = M.spielerErzeugen("Fabi")
local p3 = M.spielerErzeugen("Mia")
M.laufen(M.zeit() + 3)
local function frage(wer, was, e) return aktion.OnServerInvoke(wer, was, e) end
local function letztes(wer, typ, pruef)
	for i = #events, 1, -1 do
		local x = events[i]
		if x.p == wer and x.info.typ == typ and (not pruef or pruef(x.info)) then return x.info end
	end
end
local d = Chaos.ctx.daten

-- 1) more gags: every instructor has at least 3
for _, l in Chaos.LEHRER do
	pruefe("3+ gags for " .. l.name, l.gags ~= nil and #l.gags >= 3)
end

-- 2) friends ride along in your own car
frage(p, "dev", { befehl = "lizenz" })
for _ = 1, 30 do frage(p, "dev", { befehl = "geld" }) end
frage(p, "autoKaufen", "kleinwagen")
frage(p, "autoHolen", { typ = "kleinwagen" })
M.laufen(M.zeit() + 1)
local auto = workspace:FindFirstChild("Auto_Lukas")
local sitz = auto:FindFirstChildWhichIsA("VehicleSeat")
sitz:Sit(p.Character.Humanoid)
M.laufen(M.zeit() + 0.5)
local beifahrer = auto:FindFirstChild("Beifahrersitz")
local prompt = beifahrer and beifahrer:FindFirstChild("Mitfahren")
pruefe("own car has a 'Ride along' prompt", prompt ~= nil and prompt.ActionText == "Ride along")
prompt.Triggered:Fire(p) -- the owner can't ride along in his own car
pruefe("owner is not seated as passenger", beifahrer.Occupant == nil)
prompt.Triggered:Fire(p2)
M.laufen(M.zeit() + 0.3)
pruefe("Fabi rides along", beifahrer.Occupant == p2.Character.Humanoid)
pruefe("Fabi gets the ride-along banner", letztes(p2, "chaos", function(i) return i.titel:find("RIDING ALONG") ~= nil end) ~= nil)
pruefe("Lukas sees that Fabi got in", letztes(p, "chaos", function(i) return i.titel:find("FABI") ~= nil end) ~= nil)
local f, faehrt = Chaos.autoVon(p2)
pruefe("passenger belongs to Lukas' car", f ~= nil and f.p == p and not faehrt)

-- passengers see the chaos banners of the driver and get dodge coins too
local a = Chaos.ctx.privatAutos[p]
local y = a.chassis.Position.Y
a.chassis.CFrame = CFrame.new(200, y, -520) * CFrame.Angles(0, math.rad(90), 0)
M.laufen(M.zeit() + 0.3)
pruefe("Lukas' car has chaos state", a.chaos ~= nil)
a.chaos.naechstesEvent = math.huge
local vorher = #events
Chaos.eventStarten(p, a, "enten")
M.laufen(M.zeit() + 0.1)
local kopie = false
for i = vorher + 1, #events do
	if events[i].p == p2 and events[i].info.typ == "chaos" then kopie = true end
end
pruefe("passenger gets the driver's chaos banner", kopie)
Chaos.ende(a)
a.chaos.naechstesEvent = math.huge

-- 3) horn: everybody nearby gets it, normal horn without pass
local n = #alle
local r = frage(p, "hupen")
pruefe("honk works", r ~= nil and not r.fehler)
local h = alle[#alle]
pruefe("honk goes to every client with the car", #alle == n + 1 and h.typ == "hupe" and h.modell == auto and h.art == "normal")
frage(p, "hupen")
pruefe("horn cooldown", #alle == n + 1)
M.laufen(M.zeit() + 1)
frage(p2, "hupen")
pruefe("passenger can honk too", alle[#alle].modell == auto and #alle == n + 2)
-- crazy horn without the pass -> normal horn
frage(p, "einstellungen", { hupe = "ente" })
M.laufen(M.zeit() + 1)
frage(p, "hupen")
pruefe("duck horn needs the pass", alle[#alle].art == "normal")
frage(p, "dev", { befehl = "kauf", key = "hupen" })
pruefe("horn pack sets the attribute", p:GetAttribute("HupenPack") == true)
M.laufen(M.zeit() + 1)
frage(p, "hupen")
pruefe("duck horn with the pass", alle[#alle].art == "ente")
pruefe("5 horns, 4 in the pack", #Hupen == 5 and Hupen[1].pass == nil and Hupen[2].pass == "hupen")
local imShop = false
for _, pass in frage(p, "shop").passes do if pass.key == "hupen" then imShop = true end end
pruefe("Funny Horn Pack in the shop", imShop)
pruefe("not in a car: no honk", frage(p3, "hupen").fehler ~= nil)

-- 4) passengers can throw bananas (with the pass)
frage(p2, "dev", { befehl = "kauf", key = "banane" })
r = frage(p2, "bananeWerfen")
pruefe("passenger throws a banana", r.text ~= nil and #Chaos.schalen >= 1)
for _, s in Chaos.schalen do s.m:Destroy() end
table.clear(Chaos.schalen)

-- 5) Worst Drivers: crash points
local punkte = (d[p].chaos and d[p].chaos.punkte) or 0
Chaos.crashPunkte(p, 2)
pruefe("crash points are counted", d[p].chaos.punkte == punkte + 2)
local tafel
for _, t in workspace.Karte.Service.Bestenlisten:GetChildren() do
	if t:GetAttribute("Liste") == "Chaos" then tafel = t end
end
pruefe("4th leaderboard 'Chaos' in the park", tafel ~= nil)
M.laufen(M.zeit() + 12)
local anzeige = tafel:FindFirstChild("Anzeige")
local titel = false
for _, l in anzeige and anzeige:GetChildren() or {} do
	if l:IsA("TextLabel") and l.Text:find("WORST DRIVERS") then titel = true end
end
pruefe("Worst Drivers board is drawn", titel)

-- everybody out of the car for the party
beifahrer.Occupant = nil
p2.Character.Humanoid.SeatPart = nil
sitz.Occupant = nil
p.Character.Humanoid.SeatPart = nil
M.laufen(M.zeit() + 1)

-- 6) party test
r = frage(p, "partyBeitreten")
pruefe("Lukas opens a party", r.text ~= nil and r.text:find("You're in") ~= nil)
pruefe("everybody gets the invitation", letztes(p3, "party", function(i) return i.phase == "lobby" and i.text:find("Lukas") ~= nil end) ~= nil)
pruefe("Fabi joins", frage(p2, "partyBeitreten").text ~= nil)
pruefe("Mia joins", frage(p3, "partyBeitreten").text ~= nil)
local lobby = Party.zustand()
pruefe("3 in the lobby", lobby and #lobby.spieler == 3)
M.laufen(M.zeit() + Party.WARTEN + 1)
local _, rennen = Party.zustand()
pruefe("race started with 3 drivers", rennen ~= nil and #rennen.spieler == 3)
local L = Chaos.ctx.lektionen
pruefe("everybody has a party car on the same route", L[p] and L[p2] and L[p3] and L[p].party == rennen and L[p].lektion == L[p2].lektion and L[p2].lektion == L[p3].lektion)
pruefe("party: no mistake limit, fast chaos", L[p].erlaubt == 99 and L[p].chaos.schnell == true)
pruefe("GO banner", letztes(p2, "party", function(i) return i.phase == "start" end) ~= nil)
pruefe("joining during the race is not possible", frage(p, "partyBeitreten").fehler ~= nil)
-- a friend can ride along on the back seat of a lesson car
local hinten = L[p].model:FindFirstChild("Ruecksitz")
local mitfahrPP = hinten and hinten:FindFirstChild("Mitfahren")
pruefe("lesson car: ride along on the back seat", hinten and hinten:FindFirstChild("Mitfahren") ~= nil)
L[p].model.Fahrersitz:Sit(p.Character.Humanoid)
M.laufen(M.zeit() + 7)
L[p].chassis.CFrame = L[p].chassis.CFrame + Vector3.new(0, 0, -80)
M.laufen(M.zeit() + 0.5)
pruefe("ride along prompt gone after leaving the parking lot", L[p].mitfahrPP == nil and mitfahrPP.Parent == nil)

-- results: Fabi parks first with 2 mistakes (+10 s), Lukas second without mistakes, Mia gives up
local geld = { [p] = d[p].geld, [p2] = d[p2].geld, [p3] = d[p3].geld }
M.laufen(M.zeit() + 20)
L[p2].fehler = 2
local stFabi, stLukas, stMia = L[p2], L[p], L[p3]
-- (end lessons through the server's own end function: success = parked)
local beenden = Party.fertig
-- simulate parking: call the same path lektionBeenden uses
Chaos.ctx.lektionen[p2] = nil
beenden(p2, stFabi, true)
M.laufen(M.zeit() + 3)
Chaos.ctx.lektionen[p] = nil
beenden(p, stLukas, true)
pruefe("PARKED banner for the others", letztes(p3, "party", function(i) return i.phase == "ziel" and i.titel:find("FABI") ~= nil end) ~= nil)
Chaos.ctx.lektionen[p3] = nil
beenden(p3, stMia, false)
M.laufen(M.zeit() + 0.5)
local erg = letztes(p, "party", function(i) return i.phase == "ergebnis" end)
pruefe("results window", erg ~= nil and #erg.liste == 3)
print("  results:", erg.liste[1].name, erg.liste[1].zeit, erg.liste[2].name, erg.liste[2].zeit, erg.liste[3].name)
pruefe("Lukas wins (Fabi +10 s for 2 mistakes)", erg.liste[1].name == p.DisplayName and erg.liste[2].name == p2.DisplayName)
pruefe("Mia did not finish", erg.liste[3].zeit == nil and erg.liste[3].preis == 0)
pruefe("prize money", d[p].geld > geld[p] and d[p2].geld > geld[p2])
pruefe("win counted for the achievement", d[p].chaos.partySiege == 1)
pruefe("crown over the winner", p.Character.Head:FindFirstChild("PartyKrone") ~= nil)
pruefe("everybody hears who won", letztes(p3, "party", function(i) return i.phase == "sieger" end) ~= nil)
local _, nachher = Party.zustand()
pruefe("race is over", nachher == nil)
local b = frage(p, "belohnungen")
local gefunden
for _, e in b.erfolge or {} do if e.id == "party" then gefunden = e end end
pruefe("Party champion achievement", gefunden ~= nil and gefunden.wert == 1)

-- 7) solo party in Studio, time runs out -> the lesson is cancelled through the server's end function
M.laufen(M.zeit() + 5)
pruefe("new party", frage(p, "partyBeitreten").text ~= nil)
M.laufen(M.zeit() + Party.WARTEN + 1)
pruefe("solo race (Studio)", Chaos.ctx.lektionen[p] ~= nil and Chaos.ctx.lektionen[p].party ~= nil)
M.laufen(M.zeit() + Party.ZEIT + 1)
pruefe("time up: lesson ended", Chaos.ctx.lektionen[p] == nil)
pruefe("party end event for the client", letztes(p, "ende", function(i) return i.party == true and i.erfolg == false end) ~= nil)
local e2 = letztes(p, "party", function(i) return i.phase == "ergebnis" end)
pruefe("solo result: did not finish", e2 ~= nil and #e2.liste == 1 and e2.liste[1].zeit == nil)
print("OK  all v45 checks done")
