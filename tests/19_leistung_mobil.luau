-- Performance / mobile: performance mode switch, far NPC cars updated less often, lamps only at night,
-- big windows scaled down on a phone-sized screen
M.log = function() end
lade("gen", Q.gen)()
M.laufen(1)
lade("inst", Q.inst)()
local SSS = game:GetService("ServerScriptService")
for _, s in workspace:GetDescendants() do if s:IsA("Script") then task.spawn(lade(s.Name, s.Source, { script = s })) end end
for _, s in SSS:GetChildren() do if s:IsA("Script") then task.spawn(lade(s.Name, s.Source, { script = s })) end end
M.laufen(2)
local function pruefe(name, ok) print((ok and "OK  " or "FAIL") .. " " .. name) if not ok then error("check failed: " .. name) end end
local p = M.spielerErzeugen("Lukas")
-- phone-sized screen in landscape
workspace.CurrentCamera.ViewportSize = Vector2.new(780, 360)
local cl = game:GetService("StarterPlayer").StarterPlayerScripts.FuehrerscheinClient
task.spawn(lade("client", cl.Source, { script = cl }))
M.laufen(M.zeit() + 4)
local L = game:GetService("Lighting")

-- 1) performance mode on/off
pruefe("PC starts with the best graphics", _G.Sparmodus == false)
_G.SparmodusSetzen(true)
local aus = true
for _, e in L:GetChildren() do
	if (e:IsA("SunRaysEffect") or e:IsA("DepthOfFieldEffect") or e:IsA("BloomEffect")) and e.Enabled ~= false then aus = false end
end
pruefe("performance mode turns off the heavy effects", aus)
local V = require(game.ReplicatedStorage.Fuehrerschein.Verkehr)
pruefe("traffic knows about performance mode", V.sparmodus == true)
_G.SparmodusSetzen(false)
pruefe("best graphics again", V.sparmodus == false)

-- 2) settings have the Graphics switch
local e = p.PlayerGui.Einstellungen
local gefunden = false
for _, x in e:GetDescendants() do if x.ClassName == "TextLabel" and x.Text == "Graphics" then gefunden = true end end
pruefe("settings: Graphics option", gefunden)

-- 3) street lamps: off during the day
L.ClockTime = 12
game.ReplicatedStorage.Fuehrerschein:SetAttribute("Wetter", "Clear") -- fog would switch the lamps on
M.laufen(M.zeit() + 3)
local an, gesamt = 0, 0
for _, x in workspace.Karte:GetDescendants() do
	if x:IsA("PointLight") and x.Parent.Name == "Leuchte" then
		gesamt += 1
		if x.Enabled ~= false then an += 1 end
	end
end
pruefe("there are street lamps", gesamt > 100)
pruefe("lamps are off at noon", an == 0)
L.ClockTime = 22
-- press PLAY so the start screen camera is gone, then stand in the city
local menue = p.PlayerGui:FindFirstChild("Startbildschirm")
if menue then for _, k in menue:GetChildren() do if k.Text == "PLAY" then k.Activated:Fire() end end end
M.laufen(M.zeit() + 5)
workspace.CurrentCamera.CFrame = CFrame.new(0, 20, 0)
M.laufen(M.zeit() + 3)
an = 0
for _, x in workspace.Karte:GetDescendants() do
	if x:IsA("PointLight") and x.Parent.Name == "Leuchte" and x.Enabled ~= false then an += 1 end
end
pruefe("some lamps on at night (near the camera)", an > 0 and an < gesamt)

-- 4) big windows on phones: UDim2/Vector2 are only stubs in the mock, so the scaling itself is checked in Studio
--    (Device emulator). Here: opening the dealership with the fitting code active must not break anything.
game.ReplicatedStorage.Fuehrerschein.Oeffnen.OnClientEvent:Fire("autohaus", { katalog = {}, geld = 0 })
M.laufen(M.zeit() + 1)
pruefe("dealership window opens", p.PlayerGui:FindFirstChild("Autohaus") ~= nil)
print("performance ok")
