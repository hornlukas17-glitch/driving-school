-- v61: zones in the middle of the parking lot, 🤖 AI co-pilot (Blind Drive), 🤖 bot racers (party test),
-- VIP name tag (golden, hidden from yourself), 🚗 wrong-way driver + 😈 instructor pranks.
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
local Zonen = require(SSS.FuehrerscheinServer.Zonen)
local Party = require(SSS.FuehrerscheinServer.Party)
local Beta = require(SSS.FuehrerscheinServer.Beta)
local Chaos = require(SSS.FuehrerscheinServer.Chaos)
local Shop = require(SSS.FuehrerscheinServer.Shop)

-- 1) zones in the lane of the parking lot (behind the spawn, between the two rows of bays)
local spawn = workspace.FahrschulSpawn
local blind, party = Zonen.liste()[1], Zonen.liste()[2]
local lok = spawn.CFrame:PointToObjectSpace(blind.pos)
pruefe(("blind zone in the middle of the lot (%.0f, %.0f)"):format(lok.X, lok.Z), math.abs(lok.Z - 11) < 1 and math.abs(math.abs(lok.X) - 9) < 1)

-- 2) AI direction math: gate ahead / right / left / behind / parking
local cf = CFrame.new(0, 0, 0) -- front = -Z
pruefe("gate far ahead -> straight", Beta.kiRichtung(cf, Vector3.new(0, 0, -200)) == "gerade")
pruefe("gate near on the right -> right", Beta.kiRichtung(cf, Vector3.new(40, 0, -30)) == "rechts")
pruefe("gate near on the left -> left", Beta.kiRichtung(cf, Vector3.new(-40, 0, -30)) == "links")
pruefe("far ahead but slightly right -> still straight", Beta.kiRichtung(cf, Vector3.new(60, 0, -200)) == "gerade")
pruefe("parking bay close -> stop", Beta.kiRichtung(cf, Vector3.new(0, 0, -20), true) == "stopp")

-- 3) alone in the blind zone -> AI co-pilot after the wait
local a = M.spielerErzeugen("Lukas", 6001)
local b = M.spielerErzeugen("Mia", 6002)
local c = M.spielerErzeugen("Ben", 6003)
M.laufen(M.zeit() + 3)
a.Character:PivotTo(CFrame.new(blind.pos + Vector3.new(0, 3, 0)))
M.laufen(M.zeit() + 2)
pruefe("sign counts down to the AI: " .. blind.info.Text, blind.info.Text:find("AI co%-pilot in") ~= nil)
M.laufen(M.zeit() + Zonen.KI_WARTEN + 2)
local st = Chaos.ctx.lektionen[a]
pruefe("blind drive with AI started", st ~= nil and st.blind ~= nil and st.blind.ki ~= nil)
local auto = workspace:FindFirstChild("Fahrschulauto_Lukas")
pruefe("driver put into the car", auto and auto:FindFirstChildWhichIsA("VehicleSeat").Occupant == a.Character.Humanoid)
M.laufen(M.zeit() + 6)
pruefe("route started without a human co-pilot", st.gestartet == true and st.zielAktiv == true)
local z = letztes(a, "ziel")
pruefe("driver gets no route, only 'listen to Robo-Rita'", z ~= nil and z.pos == nil and z.text:find("Robo%-Rita") ~= nil)
M.laufen(M.zeit() + 3)
local k = letztes(a, "kommando")
pruefe("AI calls a direction: " .. tostring(k and k.text), k ~= nil and k.von:find("Robo%-Rita") ~= nil)
-- the AI co-pilot also works from the menu
pruefe("menu: AI co-pilot", frage(b, "blindKI").text ~= nil and Chaos.ctx.lektionen[b].blind.ki ~= nil)

-- 4) party zone: one player + bots
c.Character:PivotTo(CFrame.new(party.pos + Vector3.new(0, 3, 0)))
M.laufen(M.zeit() + 2)
pruefe("party countdown with one player: " .. party.info.Text, party.info.Text:find("bots") ~= nil)
M.laufen(M.zeit() + Zonen.PARTY_COUNTDOWN + 2)
local _, rennen = Party.zustand()
pruefe("race started with 3 bots", rennen ~= nil and #rennen.spieler == 1 and #rennen.bots == 3)
pruefe("bot times are sensible", rennen.bots[1].zeit > 20 and rennen.bots[1].zeit < 600)
-- Ben finishes (parks) -> results with bots, prizes only for humans
local stc = Chaos.ctx.lektionen[c]
Party.fertig(c, stc, true)
local erg = letztes(c, "party", function(i) return i.phase == "ergebnis" end)
pruefe("results list has 4 entries", erg ~= nil and #erg.liste == 4)
local botPreis = false
for _, e in erg.liste do if e.name:find("🤖") and (e.preis or 0) > 0 then botPreis = true end end
pruefe("bots never get coins", not botPreis)

-- 5) VIP tag: golden name, hidden from the VIP himself
pruefe("test purchase VIP", Shop.testKauf(a, "vip").text ~= nil)
local kopf = a.Character.Head
local schild = kopf:FindFirstChild("VipSchild")
pruefe("VIP tag exists", schild ~= nil)
pruefe("VIP tag hidden from the VIP", schild.PlayerToHideFrom == a)
local txt = schild:FindFirstChildWhichIsA("TextLabel")
pruefe("VIP tag: name in gold + small VIP", txt.Text:find("Lukas") ~= nil and txt.Text:find("VIP") ~= nil and txt.TextColor3.R > 0.9)
pruefe("normal Roblox name hidden (replaced by the gold one)", a.Character.Humanoid.DisplayDistanceType == Enum.HumanoidDisplayDistanceType.None)

-- 6) wrong-way driver: built, comes towards the car
local stb = Chaos.ctx.lektionen[b]
local fb = workspace:FindFirstChild("Fahrschulauto_Mia")
fb:FindFirstChildWhichIsA("VehicleSeat"):Sit(b.Character.Humanoid)
M.laufen(M.zeit() + 8)
if stb.chaos.event then stb.chaos.event = nil end
local e = Chaos.eventStarten(b, stb, "geisterfahrer")
pruefe("wrong-way driver event started", e ~= nil and e.art == "geisterfahrer")
local m = e.tiere[1].m
local vorher = (e.mitte - m:GetPivot().Position).Magnitude
Chaos.bewegen(e, 0.5)
local v1 = e.tiere[1].aktVor
Chaos.bewegen(e, 1.5)
pruefe("it drives towards the car", e.tiere[1].aktVor > v1)
local kollidiert = false
for _, t in m:GetDescendants() do if t:IsA("BasePart") and t.CanCollide then kollidiert = true end end
pruefe("the ghost car never collides (driving feel stays)", not kollidiert)

-- 7) instructor prank (normal lesson): banner + sometimes a fake command
local d = M.spielerErzeugen("Ole", 6004)
M.laufen(M.zeit() + 3)
frage(d, "fahrstundeStarten")
local fd = workspace:FindFirstChild("Fahrschulauto_Ole")
fd:FindFirstChildWhichIsA("VehicleSeat"):Sit(d.Character.Humanoid)
M.laufen(M.zeit() + 8)
local std = Chaos.ctx.lektionen[d]
if std.chaos.event then std.chaos.event = nil end
local r = Chaos.eventStarten(d, std, "streich")
local ban = letztes(d, "chaos", function(i) return i.farbe == "rot" end)
pruefe("prank banner: " .. tostring(ban and ban.titel), r ~= nil and r.art == "streich" and ban ~= nil)
-- prank never in Blind Drive (would mess with the co-pilot's directions)
if stb.chaos.event then stb.chaos.event = nil end
local r2 = Chaos.eventStarten(b, stb, "streich")
pruefe("no fake directions in Blind Drive", r2 ~= nil and r2.art ~= "streich")
print("ai + vip + pranks ok")
