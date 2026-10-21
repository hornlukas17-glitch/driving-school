-- v60: 💥 ragdoll crashes (fly out of the car, damage, back into the seat) + sabotage shop (send chaos to other drivers).
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
local aktion = game.ReplicatedStorage.Fuehrerschein.Aktion
local function frage(wer, was, e) return aktion.OnServerInvoke(wer, was, e) end
local function letztes(wer, typ, pruef)
	for i = #events, 1, -1 do
		local x = events[i]
		if x.p == wer and x.info.typ == typ and (not pruef or pruef(x.info)) then return x.info end
	end
end
local Chaos = require(SSS.FuehrerscheinServer.Chaos)
local Spass = require(SSS.FuehrerscheinServer.Spass)

local a = M.spielerErzeugen("Lukas", 5001)
local b = M.spielerErzeugen("Fabi", 5002)
local c = M.spielerErzeugen("Mia", 5003)
M.laufen(M.zeit() + 3)

-- ---------- ragdoll ----------
-- Lukas does a Blind Drive with Fabi (passenger) -> both fly out at a crash
frage(a, "blindStarten")
local auto = workspace:FindFirstChild("Fahrschulauto_Lukas")
local sitz = auto:FindFirstChildWhichIsA("VehicleSeat")
local bf = auto:FindFirstChild("Beifahrersitz")
sitz:Sit(a.Character.Humanoid)
bf.Copilot.Triggered:Fire(b)
M.laufen(M.zeit() + 4)
pruefe("both in the car", sitz.Occupant == a.Character.Humanoid and bf.Occupant == b.Character.Humanoid)
pruefe("not standing in the car: no crash", frage(c, "crash", { von = 90, nach = 0 }).ok == false)
pruefe("small speed drop is no crash", frage(a, "crash", { von = 40, nach = 10 }).ok == false)
pruefe("braking from 60 to 40 is no crash", frage(a, "crash", { von = 60, nach = 40 }).ok == false)
local r = frage(a, "crash", { von = 90, nach = 5 })
pruefe("hard crash accepted, damage " .. tostring(r.schaden), r.ok == true and r.schaden >= Spass.SCHADEN_MIN and r.schaden <= Spass.SCHADEN_MAX)
pruefe("driver out of the seat", sitz.Occupant == nil and a.Character.Humanoid.SeatPart == nil)
pruefe("passenger flew out too", bf.Occupant == nil)
pruefe("seats locked while flying (no instant re-sit)", sitz.Disabled == true and bf.Disabled == true)
pruefe("driver lost health", a.Character.Humanoid.Health == 100 - r.schaden)
pruefe("passenger less damage", b.Character.Humanoid.Health > a.Character.Humanoid.Health and b.Character.Humanoid.Health < 100)
pruefe("client gets the ragdoll push", letztes(a, "ragdoll", function(i) return typeof(i.stoss) == "Vector3" and i.stoss.Y > 0 end) ~= nil)
pruefe("YEET banner", letztes(a, "chaos", function(i) return i.text:find("flew out") ~= nil end) ~= nil)
pruefe("second crash right away is ignored", frage(a, "crash", { von = 90, nach = 5 }).ok == false)
M.laufen(M.zeit() + Spass.RAGDOLL_ZEIT + 1)
pruefe("driver back in the seat", sitz.Occupant == a.Character.Humanoid)
pruefe("passenger back in the seat", bf.Occupant == b.Character.Humanoid)
pruefe("seats unlocked again", not sitz.Disabled and not bf.Disabled)
pruefe("lesson still running", Chaos.ctx.lektionen[a] ~= nil)
M.laufen(M.zeit() + 5)
pruefe("Fabi is still the co-pilot after the crash", Chaos.ctx.lektionen[a].blind.copilot == b and letztes(b, "ende") == nil)
-- a crash never kills
a.Character.Humanoid.Health = 9
M.laufen(M.zeit() + Spass.CRASH_PAUSE + 1)
frage(a, "crash", { von = 130, nach = 0 })
pruefe("never below " .. Spass.HP_MIN .. " HP", a.Character.Humanoid.Health == Spass.HP_MIN)
M.laufen(M.zeit() + Spass.RAGDOLL_ZEIT + 1)

-- ---------- sabotage ----------
local d = Chaos.ctx.daten
d[c].geld = 1000
local liste = frage(c, "sabotageListe")
local gefunden
for _, z in liste.ziele do if z.id == a.UserId then gefunden = z end end
pruefe("driving Lukas is in Mia's list (" .. tostring(gefunden and gefunden.wo) .. ")", gefunden ~= nil and gefunden.wo == "Blind Drive")
local istB = false
for _, z in liste.ziele do if z.id == b.UserId then istB = true end end
pruefe("the co-pilot (not driving) is not in the list", not istB)
pruefe("can't sabotage yourself", frage(a, "sabotage", { ziel = a.UserId, art = "kuehe" }).fehler ~= nil)
pruefe("unknown event refused", frage(c, "sabotage", { ziel = a.UserId, art = "atombombe" }).fehler ~= nil)
d[c].geld = 50
pruefe("not enough coins", frage(c, "sabotage", { ziel = a.UserId, art = "kuehe" }).fehler:find("coins") ~= nil)
d[c].geld = 1000
local st = Chaos.ctx.lektionen[a]
if st.chaos.event then st.chaos.event = nil end
local s1 = frage(c, "sabotage", { ziel = a.UserId, art = "kuehe" })
pruefe("sabotage sent: " .. tostring(s1.text or s1.fehler), s1.ok == true)
pruefe("coins paid", d[c].geld == 1000 - 150)
pruefe("cows on the road for Lukas", st.chaos.event ~= nil and st.chaos.event.art == "kuehe" and st.chaos.event.sabotage ~= nil)
pruefe("Lukas is told who did it", letztes(a, "chaos", function(i) return i.titel == "💥 SABOTAGE!" and i.text:find("Mia") ~= nil end) ~= nil)
pruefe("same target right away: wait", frage(c, "sabotage", { ziel = a.UserId, art = "banane" }).fehler ~= nil)
-- the victim survives (event over, not hit) -> bonus
local geldA = d[a].geld
local e = st.chaos.event
e.naechster = 10
local Chaos_eventEnde
for _ = 1, 1 do
	-- drive past: event ends as "vorbei" through the normal tick (car far behind the event)
	e.mitte = st.chassis.Position - st.chassis.CFrame.LookVector * 40
	Chaos.tick(a, st, st.chassis.Position, 20, -8.8, 8.8, 4.2)
end
pruefe("survived: +" .. Spass.BONUS .. " coins for Lukas", d[a].geld >= geldA + Spass.BONUS)
pruefe("Mia hears it was dodged", letztes(c, "chaos", function(i) return i.titel:find("DODGED") ~= nil end) ~= nil)

-- protected: first lesson and settings switch
local p4 = M.spielerErzeugen("Ben", 5004)
M.laufen(M.zeit() + 3)
frage(p4, "fahrstundeStarten")
M.laufen(M.zeit() + 1)
pruefe("lesson 1 is protected", frage(c, "sabotage", { ziel = p4.UserId, art = "banane" }).fehler:find("first lesson") ~= nil)
d[a].einstellungen = { sabotageAus = true }
M.laufen(M.zeit() + Spass.ZIEL_PAUSE + 1)
pruefe("switched off = protected", frage(c, "sabotage", { ziel = a.UserId, art = "banane" }).fehler:find("switched off") ~= nil)
print("ragdoll + sabotage ok")
