-- New start: PLAY -> straight into the short first lesson (no theory first), stars per lesson,
-- replaying lessons, theory only needed for the driving test, onboarding funnel steps
local letzteZiel, ende = nil, nil
M.log = function(name, p, info)
	if name == "FireClient Fahrstunde" and type(info) == "table" then
		if info.typ == "ziel" then letzteZiel = info end
		if info.typ == "ende" then ende = info end
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
local p = M.spielerErzeugen("Lukas")
local cl = game:GetService("StarterPlayer").StarterPlayerScripts.FuehrerscheinClient
task.spawn(lade("client", cl.Source, { script = cl }))
M.laufen(M.zeit() + 3)
local aktion = game.ReplicatedStorage.Fuehrerschein.Aktion
local function frage(was, e) return aktion.OnServerInvoke(p, was, e) end
local hum = p.Character.Humanoid

pruefe("new player is not signed up yet", frage("status").status.angemeldet == false)
-- 1) press PLAY: the first lesson starts by itself, welcome window
local menue = p.PlayerGui:FindFirstChild("Startbildschirm")
for _, k in menue:GetChildren() do if k.Text == "PLAY" then k.Activated:Fire() end end
M.laufen(M.zeit() + 8)
local st = frage("status")
pruefe("signed up automatically", st.status.angemeldet == true)
pruefe("first lesson is running", st.lektionLaeuft == true)
local auto = workspace:FindFirstChild("Fahrschulauto_Lukas")
pruefe("lesson car waits on the parking lot", auto ~= nil)
local willkommen = false
for _, x in p.PlayerGui.LicenseGUI:GetDescendants() do
	if x.ClassName == "TextLabel" and x.Text:find("Welcome to Crazy Driving School", 1, true) then willkommen = true end
end
pruefe("welcome window", willkommen)
pruefe("no second first drive", frage("ersteFahrt").fehler ~= nil)

-- 2) drive the first lesson (short loop around the block)
local function fahreRoute(modell, maxSchritte)
	local chassis = modell.Chassis
	for _ = 1, maxSchritte do
		M.laufen(M.zeit() + 0.5)
		if not modell.Parent then return true end
		local z = letzteZiel
		if z and z.park then
			chassis.CFrame = z.park[1].cf + Vector3.new(0, 2, 0)
		elseif z and z.pos then
			chassis.CFrame = CFrame.lookAt(z.pos + Vector3.new(0, 2, 0), z.pos + Vector3.new(0, 2, 0) + z.richtung)
		end
	end
	return false
end
auto.Fahrersitz:Sit(hum)
M.laufen(M.zeit() + 8)
pruefe("first lesson finished", fahreRoute(auto, 60))
hum.SeatPart = nil
M.laufen(M.zeit() + 6)
st = frage("status")
pruefe("1 lesson done", st.status.fahrstunden == 1)
pruefe("stars saved", (st.status.sterne["1"] or 0) >= 1)
pruefe("result shows stars and the next step", ende and ende.sterne ~= nil and ende.weiter ~= nil)
pruefe("first lesson is short", #require(game.ServerScriptService.FuehrerscheinServer.Fahrstunden)[1].punkte <= 8)

-- 3) next lesson works without theory, the driving test does not
local r = frage("fahrstundeStarten")
pruefe("lesson 2 without theory: " .. tostring(r.text or r.fehler), r.text ~= nil)
frage("fahrstundeAbbrechen")
M.laufen(M.zeit() + 3)
pruefe("driving test needs the theory", (frage("pruefungStarten").fehler or ""):find("theory", 1, true) ~= nil)

-- 4) replay lesson 1 for more stars, not lessons you haven't done
pruefe("cannot replay lesson 3", frage("fahrstundeWiederholen", 3).fehler ~= nil)
r = frage("fahrstundeWiederholen", 1)
pruefe("replay lesson 1: " .. tostring(r.text or r.fehler), r.text ~= nil)
frage("fahrstundeAbbrechen")
M.laufen(M.zeit() + 3)

-- 5) Anna: lessons first, theory later; stars shown
local dialogEvent = game.ReplicatedStorage.Fuehrerschein.Oeffnen
dialogEvent.OnClientEvent:Fire("dialog")
M.laufen(M.zeit() + 1)
local gui = p.PlayerGui.LicenseGUI
local function knopf(text)
	for _, k in gui:GetDescendants() do if k.ClassName == "TextButton" and k.Text:find(text, 1, true) then return k end end
end
knopf("Car license (B)").MouseButton1Click:Fire()
M.laufen(M.zeit() + 1)
local t = ""
for _, x in gui:GetDescendants() do if x.ClassName == "TextLabel" and #x.Text > 40 then t = x.Text end end
local a, b = t:find("Driving lessons", 1, true), t:find("Theory lesson", 1, true)
pruefe("checklist: lessons before theory", a ~= nil and b ~= nil and a < b)
pruefe("checklist shows stars", t:find("⭐", 1, true) ~= nil)
local besteSterne = frage("status").status.sterne["1"]
pruefe("improve button only while stars are missing", (knopf("Improve a lesson") ~= nil) == (besteSterne < 3))

-- 6) onboarding funnel steps were recorded once
local f = frage("status").status.funnel
pruefe("funnel: joined, in the car, first lesson", f["1"] and f["2"] and f["3"])
print("start flow ok")
