-- v47: new cockpit HUD (round speedometer), km/h <-> mph everywhere, arrow to the lesson car
M.log = function() end
lade("gen", Q.gen)()
M.laufen(1)
lade("inst", Q.inst)()
local SSS = game:GetService("ServerScriptService")
for _, s in workspace:GetDescendants() do if s:IsA("Script") then task.spawn(lade(s.Name, s.Source, { script = s })) end end
for _, s in SSS:GetChildren() do if s:IsA("Script") then task.spawn(lade(s.Name, s.Source, { script = s })) end end
M.laufen(2)
local function pruefe(name, ok) print((ok and "OK  " or "FAIL") .. " " .. name) if not ok then error("check failed: " .. name) end end
local aktion = game.ReplicatedStorage.Fuehrerschein.Aktion
local p = M.spielerErzeugen("Lukas")
local cl = game:GetService("StarterPlayer").StarterPlayerScripts.FuehrerscheinClient
task.spawn(lade("client", cl.Source, { script = cl }))
M.laufen(M.zeit() + 3)

-- 1) cockpit
local hud = p.PlayerGui.LessonHUD
local cockpit = hud:FindFirstChild("Cockpit")
pruefe("cockpit frame", cockpit ~= nil)
local scheibe = cockpit.Tacho.Scheibe
local ringe = 0
for _, k in scheibe:GetChildren() do
	if k:IsA("Frame") and k.Name ~= "Grenze" then ringe += 1 end
end
pruefe("ring of 27 lights", ringe == 27)
pruefe("speed limit sign", cockpit.Tacho:FindFirstChild("Tempolimit") ~= nil)

-- 2) units
local einh = _G.EinheitText
pruefe("unit helper", einh ~= nil)
_G.Einstellungen.mph = false
pruefe("km/h stays km/h", einh("Too fast! The limit here is 50 km/h.") == "Too fast! The limit here is 50 km/h.")
_G.Einstellungen.mph = true
pruefe("limit 50 km/h -> 30 mph", einh("Too fast! The limit here is 50 km/h.") == "Too fast! The limit here is 30 mph.")
pruefe("130 -> 80 mph", einh("Speed limit 130 km/h.") == "Speed limit 80 mph.")
pruefe("speed camera text", einh("📸 Speed camera! 74 km/h in a 50 zone.") == "📸 Speed camera! 46 mph in a 30 mph zone.")
pruefe("30 -> 20 mph", einh("Residential area, 30 km/h.") == "Residential area, 20 mph.")
_G.Einstellungen.mph = false

-- 3) arrow to the lesson car
aktion.OnServerInvoke(p, "fahrstundeStarten")
M.laufen(M.zeit() + 2)
pruefe("lesson car exists", workspace:FindFirstChild("Fahrschulauto_Lukas") ~= nil)
local ordner = workspace:FindFirstChild("AutoPfeil")
local bb = ordner and ordner:FindFirstChild("AutoPfeil")
pruefe("bouncing arrow over the car", bb ~= nil and bb.Adornee ~= nil and bb.Adornee.Name == "Fahrersitz")
local beam = ordner and ordner:FindFirstChildWhichIsA("Beam")
pruefe("green line to the car", beam ~= nil and beam.Attachment1 ~= nil)
workspace.Fahrschulauto_Lukas.Fahrersitz:Sit(p.Character.Humanoid)
M.laufen(M.zeit() + 1)
pruefe("arrow gone once you sit in the car", ordner:FindFirstChild("AutoPfeil") == nil and ordner:FindFirstChildWhichIsA("Beam") == nil)
print("OK  all v47 checks done")
