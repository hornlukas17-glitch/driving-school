-- v51: too many mistakes in a normal lesson no longer stop it (and the car no longer vanishes under you).
-- The finished route just does not count; the car stays while you sit in it; "Try again" starts the same lesson.
local letzteZiel, ende, hinweise = nil, nil, {}
M.log = function(name, p, info)
	if name == "FireClient Fahrstunde" and type(info) == "table" then
		if info.typ == "ziel" then letzteZiel = info end
		if info.typ == "ende" then ende = info end
		if info.typ == "hinweis" then table.insert(hinweise, info.text) end
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
local Chaos = require(SSS.FuehrerscheinServer.Chaos)
local function pruefe(name, ok) print((ok and "OK  " or "FAIL") .. " " .. name) if not ok then error("check failed: " .. name) end end
local p = M.spielerErzeugen("Lukas")
M.laufen(M.zeit() + 3)
local aktion = game.ReplicatedStorage.Fuehrerschein.Aktion
local function frage(was, e) return aktion.OnServerInvoke(p, was, e) end
local hum = p.Character.Humanoid

local r = frage("fahrstundeStarten")
pruefe("lesson 1 started: " .. tostring(r.text or r.fehler), r.text ~= nil)
local auto = workspace:FindFirstChild("Fahrschulauto_Lukas")
auto.Fahrersitz:Sit(hum)
M.laufen(M.zeit() + 8)
local st = Chaos.ctx.lektionen[p]
pruefe("lesson state", st ~= nil and st.erlaubt == 9)

-- 12 mistakes: the lesson keeps running, the car stays

st.fehler = 12
pruefe("still running with 12 mistakes", Chaos.ctx.lektionen[p] == st and auto.Parent ~= nil)

-- finish the route
local chassis = auto.Chassis
for _ = 1, 80 do
	M.laufen(M.zeit() + 0.5)
	if ende then break end
	local z = letzteZiel
	if z and z.park then
		chassis.CFrame = z.park[1].cf + Vector3.new(0, 2, 0)
	elseif z and z.pos then
		chassis.CFrame = CFrame.lookAt(z.pos + Vector3.new(0, 2, 0), z.pos + Vector3.new(0, 2, 0) + z.richtung)
	end
end
pruefe("route finished -> result", ende ~= nil)
pruefe("too many mistakes: does not count", ende.erfolg == false and (ende.text or ""):find("does not count", 1, true) ~= nil)
pruefe("lesson not counted", frage("status").status.fahrstunden == 0)
M.laufen(M.zeit() + 5)
pruefe("car stays while you sit in it", auto.Parent ~= nil)

-- Try again: same lesson, the old car is removed, a new one waits
ende = nil
r = frage("nochmal")
pruefe("try again: " .. tostring(r.text or r.fehler), r.text ~= nil)
pruefe("old car removed", auto.Parent == nil)
local neu = workspace:FindFirstChild("Fahrschulauto_Lukas")
pruefe("new car for lesson 1", neu ~= nil and Chaos.ctx.lektionen[p] ~= nil and Chaos.ctx.lektionen[p].nr == 1)

-- failed and get out: car is removed shortly after
frage("fahrstundeAbbrechen")
M.laufen(M.zeit() + 3)
pruefe("cancel without sitting: car gone", workspace:FindFirstChild("Fahrschulauto_Lukas") == nil)
print("errors", M.fehler or 0)
print("keep car ok")
