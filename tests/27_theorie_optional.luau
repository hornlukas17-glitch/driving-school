-- v50: the theory test is optional. A player with all driving lessons but WITHOUT theory may take the driving test;
-- a player without all lessons may not (checked on the server, so a hacked client can't skip lessons).
lade("gen", Q.gen)()
M.laufen(1)
lade("inst", Q.inst)()
local SSS = game:GetService("ServerScriptService")
for _, s in workspace:GetDescendants() do if s:IsA("Script") then task.spawn(lade(s.Name, s.Source, { script = s })) end end
for _, s in SSS:GetChildren() do if s:IsA("Script") then task.spawn(lade(s.Name, s.Source, { script = s })) end end
M.laufen(2)
require(game.ReplicatedStorage.Fuehrerschein.Verkehr).fahrzeuge = {}
local function pruefe(name, ok) print((ok and "OK  " or "FAIL") .. " " .. name) if not ok then error("check failed: " .. name) end end
local anzahl = #require(SSS.FuehrerscheinServer.Fahrstunden)

-- saved player: all lessons done, theory never done
local ds = game:GetService("DataStoreService"):GetDataStore("Fuehrerschein_v1")
ds:SetAsync("spieler_12345", { angemeldet = true, fahrstunden = anzahl, theorie = false, unterricht = false })
local p = M.spielerErzeugen("Lukas")
M.laufen(M.zeit() + 3)
local aktion = game.ReplicatedStorage.Fuehrerschein.Aktion
local function frage(was, e) return aktion.OnServerInvoke(p, was, e) end

local s = frage("status").status
pruefe("loaded: all lessons, no theory", s.fahrstunden == anzahl and s.theorie == false)
local r = frage("pruefungStarten")
pruefe("driving test without theory: " .. tostring(r.text or r.fehler), r.text ~= nil)
pruefe("examiner car spawned", workspace:FindFirstChild("Fahrschulauto_Lukas") ~= nil)
frage("fahrstundeAbbrechen")
M.laufen(M.zeit() + 3)

-- with one lesson missing the server refuses (even if the client asks directly)
ds:SetAsync("spieler_12345", nil)
local d = frage("status").status
d.fahrstunden = anzahl - 1 -- status returns the live table on the server in the mock
r = frage("pruefungStarten")
pruefe("driving test needs all lessons: " .. tostring(r.fehler), r.fehler ~= nil and r.fehler:find("lessons", 1, true) ~= nil)
-- a truck test is not affected by the lesson rule (it needs the car license, checked elsewhere)
print("theory optional ok")
