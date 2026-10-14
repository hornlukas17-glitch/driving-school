-- Engine sounds: every car type has its own voice, rpm follows speed with a virtual gearbox,
-- start / stop with the driver, stand-in sound until the own files are uploaded, NPC traffic sounds
M.log = function() end
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
-- press PLAY so the start screen camera stops moving
local menue = p.PlayerGui:FindFirstChild("Startbildschirm")
if menue then for _, k in menue:GetChildren() do if k.Text == "PLAY" then k.Activated:Fire() end end end
M.laufen(M.zeit() + 5)
local MS = require(game.ReplicatedStorage.Fuehrerschein.Motorsound)
local A = game.ReplicatedStorage.Fuehrerschein.Aktion

-- 1) every car type has a profile and an engine voice with three loops
local Auto = require(SSS.FuehrerscheinServer.Auto)
for typ in Auto.MODELLE do
	local prof = MS.PROFILE[typ]
	pruefe("profile for " .. typ, prof ~= nil and MS.DATEN[prof.stimme] ~= nil and #MS.DATEN[prof.stimme].loops == 3)
end
local stimmen = {}
for _, typ in Auto.MODELL_REIHENFOLGE do stimmen[MS.PROFILE[typ].stimme] = true end
local anzahl = 0
for _ in stimmen do anzahl += 1 end
pruefe("each dealership car sounds different (own voice)", anzahl == #Auto.MODELL_REIHENFOLGE)
for _, n in { "lkw1", "lkw2", "lkw3", "fahrschule", "npc_kleinwagen", "npc_lkw", "npc_transporter" } do
	pruefe("profile " .. n, MS.PROFILE[n] ~= nil)
end

-- 2) virtual gearbox
local d = MS.DATEN.Fahrschule
local st = { gang = 1 }
local r0 = MS.drehzahl(st, d, 0, 0, 130)
pruefe("idle when standing", math.abs(r0 - d.leerlauf) < 1)
pruefe("revving in place with gas", MS.drehzahl(st, d, 0, 1, 130) > d.leerlauf * 3)
local vorher, schaltungen, maxR = 0, 0, 0
st = { gang = 1 }
for v = 1, 130 do
	local g = st.gang
	local r = MS.drehzahl(st, d, v, 1, 130)
	if st.gang > g then schaltungen += 1 end
	maxR = math.max(maxR, r)
end
pruefe("shifts up through the gears", schaltungen >= d.gaenge - 2 and st.gang <= d.gaenge)
pruefe("never above the red line", maxR <= d.max)
local a, b, c = MS.gewichte(1500, { 800, 2000, 4200 })
pruefe("loops cross-fade with equal power", math.abs(a * a + b * b + c * c - 1) < 1e-6 and a > 0 and b > 0 and c == 0)

-- 3) own car: engine starts when you sit in, stand-in sound while the files are not uploaded
A.OnServerInvoke(p, "dev", { befehl = "lizenz" })
A.OnServerInvoke(p, "adminGeld", 50000)
A.OnServerInvoke(p, "autoKaufen", "sport")
p.Character:PivotTo(CFrame.new(60, 3, -376))
A.OnServerInvoke(p, "autoHolen", { typ = "sport" })
M.laufen(M.zeit() + 1)
local auto = workspace:FindFirstChild("Auto_Lukas")
pruefe("own car", auto ~= nil)
pruefe("car profile from its type", MS.profilName(auto) == "sport")
workspace.CurrentCamera.CFrame = CFrame.new(auto.Chassis.Position + Vector3.new(0, 5, 15))
M.laufen(M.zeit() + 1)
local function motorSounds(m)
	local t = {}
	for _, x in m.Chassis:GetChildren() do if x.Name == "Motor" then table.insert(t, x) end end
	return t
end
pruefe("silent while nobody sits in", #motorSounds(auto) == 0)
auto.Fahrersitz:Sit(p.Character.Humanoid)
M.laufen(M.zeit() + 2)
local s = motorSounds(auto)
pruefe("engine runs when the driver sits in", #s == 1 and s[1].IsPlaying == true and s[1].Looped == true)
pruefe("stand-in sound until own files are uploaded", s[1].SoundId == "rbxassetid://" .. MS.ERSATZ_ID)
pruefe("audible", s[1].Volume > 0.05)
local leerlaufTon = s[1].PlaybackSpeed
auto.Chassis.AssemblyLinearVelocity = auto.Chassis.CFrame.LookVector * 60
auto.Fahrersitz.ThrottleFloat = 1
M.laufen(M.zeit() + 2)
pruefe("higher rpm when driving fast", s[1].PlaybackSpeed > leerlaufTon * 1.3)
-- get out: the engine fades out and the sound objects are removed
auto.Fahrersitz.Occupant = nil
p.Character.Humanoid.SeatPart = nil
auto.Chassis.AssemblyLinearVelocity = Vector3.zero
auto.Fahrersitz.ThrottleFloat = 0
M.laufen(M.zeit() + 5)
pruefe("engine off after getting out", #motorSounds(auto) == 0)

-- 4) with own uploaded files: three loops + start sound
local G = MS.DATEN.Velocity
local alt = { G.loops[1].id, G.loops[2].id, G.loops[3].id, G.start }
G.loops[1].id, G.loops[2].id, G.loops[3].id, G.start = 101, 102, 103, 104
auto.Fahrersitz:Sit(p.Character.Humanoid)
M.laufen(M.zeit() + 0.3)
local alle = motorSounds(auto)
local ids = {}
for _, x in alle do ids[x.SoundId] = x end
pruefe("three loops of its own voice", ids["rbxassetid://101"] and ids["rbxassetid://102"] and ids["rbxassetid://103"] and true or false)
pruefe("start sound plays once", ids["rbxassetid://104"] ~= nil and ids["rbxassetid://104"].Looped == false)
M.laufen(M.zeit() + 2)
pruefe("idle loop is the loudest at idle", ids["rbxassetid://101"].Volume > ids["rbxassetid://103"].Volume)
auto.Chassis.AssemblyLinearVelocity = auto.Chassis.CFrame.LookVector * 150
M.laufen(M.zeit() + 3)
pruefe("high loop takes over at high rpm", ids["rbxassetid://103"].Volume > ids["rbxassetid://101"].Volume)
G.loops[1].id, G.loops[2].id, G.loops[3].id, G.start = alt[1], alt[2], alt[3], alt[4]

-- 5) NPC traffic: only near vehicles get a (quiet) engine sound
local nah = Instance.new("Model") nah.Name = "NPC_lkw"
local w1 = Instance.new("Part") w1.Name = "Wurzel" w1.CFrame = CFrame.new(workspace.CurrentCamera.CFrame.Position + Vector3.new(10, 0, 0)) w1.Parent = nah
nah.Parent = workspace
local weit = Instance.new("Model") weit.Name = "NPC_kleinwagen"
local w2 = Instance.new("Part") w2.Name = "Wurzel" w2.CFrame = CFrame.new(workspace.CurrentCamera.CFrame.Position + Vector3.new(400, 0, 0)) w2.Parent = weit
weit.Parent = workspace
MS.verkehr({ { modell = nah, v = 30 }, { modell = weit, v = 30 } })
M.laufen(M.zeit() + 1)
local function hat(w) for _, x in w:GetChildren() do if x.Name == "Motor" then return x end end return nil end
pruefe("near NPC truck has an engine sound", hat(w1) ~= nil and hat(w1).Volume > 0)
pruefe("far NPC car is silent", hat(w2) == nil)
print("engine sounds ok")
