-- v54 beta tools: promo codes, onboarding funnel v2, friend invite reward, instructor mode light (commands + rating).
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

local p = M.spielerErzeugen("Lukas", 1001)
M.laufen(M.zeit() + 3)
local d = frage(p, "status").status

-- 1) funnel v2: "Joined" is reported once, in the new field (the old d.funnel stays untouched)
pruefe("funnel2 has 'Joined'", d.funnel2 and d.funnel2["1"] == true)
pruefe("same step not twice", Beta.funnel(p, "Joined") == false)
pruefe("unknown step ignored", Beta.funnel(p, "Nonsense") == false)
frage(p, "kartenGeladen", 4.2)
pruefe("map loaded step", d.funnel2["2"] == true)

-- 2) promo codes: case-insensitive, once per player, unknown/odd input refused
local geld = d.geld
local r = frage(p, "code", " beta ")
pruefe("code BETA works: " .. tostring(r.text or r.fehler), r.text ~= nil and d.geld == geld + 1000)
M.laufen(M.zeit() + 2.5)
r = frage(p, "code", "BETA")
pruefe("code only once: " .. tostring(r.fehler), r.fehler ~= nil and d.geld == geld + 1000)
M.laufen(M.zeit() + 2.5)
r = frage(p, "code", "NOPE")
pruefe("unknown code refused", r.fehler ~= nil)
M.laufen(M.zeit() + 2.5)
pruefe("non-string input refused", frage(p, "code", { 1, 2 }).fehler ~= nil)
pruefe("very long input refused", frage(p, "code", string.rep("A", 200)).fehler ~= nil)

-- 3) friend invite: a NEW player who joins via Lukas' invite -> both +750 coins, only once
local geldL = d.geld
local p2 = M.spielerErzeugen("Fabi", 1002, { ReferredByPlayerId = 1001 })
M.laufen(M.zeit() + 3)
local d2 = frage(p2, "status").status
pruefe("new friend got the welcome gift", d2.geworbenVon == 1001 and d2.geld >= 100 + Beta.WERBUNG_BONUS)
pruefe("inviter got the reward", d.geld == geldL + Beta.WERBUNG_BONUS and d.werbungen == 1)
pruefe("inviter sees the banner", letztes(p, "chaos", function(i) return i.titel:find("FABI") ~= nil end) ~= nil)
-- referring yourself does nothing
local p3 = M.spielerErzeugen("Mia", 1003, { ReferredByPlayerId = 1003 })
M.laufen(M.zeit() + 3)
pruefe("self-referral ignored", frage(p3, "status").status.geworbenVon == 0)

-- 4) instructor mode light
pruefe("command without riding along is refused", frage(p2, "kommando", "links").fehler ~= nil)
pruefe("unknown command refused", frage(p2, "kommando", "explode").fehler ~= nil)
pruefe("rating without riding along refused", frage(p2, "bewerten", 5).fehler ~= nil)
frage(p, "dev", { befehl = "lizenz" })
for _ = 1, 30 do frage(p, "dev", { befehl = "geld" }) end
frage(p, "autoKaufen", "kleinwagen")
frage(p, "autoHolen", { typ = "kleinwagen" })
M.laufen(M.zeit() + 1)
local auto = workspace:FindFirstChild("Auto_Lukas")
auto:FindFirstChildWhichIsA("VehicleSeat"):Sit(p.Character.Humanoid)
M.laufen(M.zeit() + 0.5)
local beifahrer = auto:FindFirstChild("Beifahrersitz")
beifahrer:FindFirstChild("Mitfahren").Triggered:Fire(p2)
M.laufen(M.zeit() + 0.3)
pruefe("Fabi rides along", Beta.fahrerVon(p2) == p)
pruefe("the driver himself is no instructor", Beta.fahrerVon(p) == nil)
r = frage(p2, "kommando", "links")
pruefe("command accepted", r.ok == true)
local k = letztes(p, "kommando")
pruefe("driver sees LEFT from Fabi", k ~= nil and k.text:find("LEFT") ~= nil and k.von == "Fabi")
r = frage(p2, "kommando", "rechts")
pruefe("too fast: ignored, no error", r.ok == true and r.zuSchnell == true)
r = frage(p2, "bewerten", 5)
pruefe("rating needs 3 commands first", r.fehler ~= nil)
for _, art in { "gerade", "stopp" } do
	M.laufen(M.zeit() + 1)
	frage(p2, "kommando", art)
end
pruefe("rating with 0 or 6 stars refused", frage(p2, "bewerten", 0).fehler ~= nil and frage(p2, "bewerten", 6).fehler ~= nil)
local geldFahrer = d.geld
r = frage(p2, "bewerten", 4)
pruefe("rating accepted: " .. tostring(r.text or r.fehler), r.text ~= nil)
pruefe("driver gets coins for 4 stars", d.geld > geldFahrer and d.bewertung.anzahl == 1 and d.bewertung.summe == 4)
pruefe("second rating right away needs new commands", frage(p2, "bewerten", 5).fehler ~= nil)
print("beta tools ok")
