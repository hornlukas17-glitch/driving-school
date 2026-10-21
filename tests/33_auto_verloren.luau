-- v59: "car despawns right at the start": new cars never spawn into a car that is still standing in the bay,
-- full bays give a clear message, and a lost car ends the lesson WITH a message (before: silently).
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
local Chaos = require(SSS.FuehrerscheinServer.Chaos)
local function pruefe(name, ok) print((ok and "OK  " or "FAIL") .. " " .. name) if not ok then error("check failed: " .. name) end end
local aktion = game.ReplicatedStorage.Fuehrerschein.Aktion
local function frage(wer, was, e) return aktion.OnServerInvoke(wer, was, e) end
local function letztes(wer, typ)
	for i = #events, 1, -1 do if events[i].p == wer and events[i].info.typ == typ then return events[i].info end end
end

local a = M.spielerErzeugen("Lukas", 4001)
local b = M.spielerErzeugen("Fabi", 4002)
M.laufen(M.zeit() + 3)

-- 1) Lukas' lesson fails while he sits in the car -> the car stays in its bay
pruefe("lesson A started", frage(a, "fahrstundeStarten").text ~= nil)
local autoA = workspace:FindFirstChild("Fahrschulauto_Lukas")
autoA.Fahrersitz:Sit(a.Character.Humanoid)
M.laufen(M.zeit() + 6)
local posA = autoA:GetPivot().Position
frage(a, "fahrstundeAbbrechen")
M.laufen(M.zeit() + 2)
pruefe("A's car is still there (rest car)", autoA.Parent ~= nil and Chaos.ctx.lektionen[a] == nil)

-- 2) Fabi starts: his car must NOT be put into Lukas' car
pruefe("lesson B started", frage(b, "fahrstundeStarten").text ~= nil)
local autoB = workspace:FindFirstChild("Fahrschulauto_Fabi")
local abstand = (autoB:GetPivot().Position - posA).Magnitude
pruefe(("B's car in another bay (%.1f studs away)"):format(abstand), abstand > 6)

-- 3) the car gets lost (e.g. flung away / destroyed) -> lesson ends with a message
autoB.Fahrersitz:Sit(b.Character.Humanoid)
M.laufen(M.zeit() + 3)
autoB:Destroy()
M.laufen(M.zeit() + 2)
pruefe("lesson B ended", Chaos.ctx.lektionen[b] == nil)
local e = letztes(b, "ende")
pruefe("player is told what happened", e ~= nil and e.erfolg == false and e.text:find("car got lost") ~= nil)
pruefe("try again works", frage(b, "nochmal").fehler == nil)
print("car lost ok")
