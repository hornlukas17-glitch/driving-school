-- Spawn in front of the door, compact HUD bar, Anna: car/truck choice then the full checklist, NPCs with clothes
M.log = function() end
lade("gen", Q.gen)()
M.laufen(1)
lade("inst", Q.inst)()
local SSS = game:GetService("ServerScriptService")
for _, s in workspace:GetDescendants() do if s:IsA("Script") then task.spawn(lade(s.Name, s.Source, { script = s })) end end
for _, s in SSS:GetChildren() do if s:IsA("Script") then task.spawn(lade(s.Name, s.Source, { script = s })) end end
M.laufen(2)
local function pruefe(name, ok) print((ok and "OK  " or "FAIL") .. " " .. name) if not ok then error("check failed: " .. name) end end

-- 1) spawn outside, in front of the entrance, looking at the door
local fs = workspace.Karte.Vorstadt.Fahrschule
local tuer = fs.Tuer
local sp = workspace.FahrschulSpawn
local abstand = sp.Position - tuer.Position
pruefe("spawn in front of the door (outside)", abstand.Z < -5 and abstand.Z > -12 and math.abs(abstand.X) < 1)
pruefe("spawn looks at the door", sp.CFrame.LookVector.Z > 0.9)

-- 2) NPCs get clothes, hair and a face
local mitKleidung, gesamt = 0, 0
for _, d in M.npcBeschreibungen or {} do
	gesamt += 1
	if d.Head and d.Head ~= 0 then mitKleidung += 1 end
end
pruefe("NPCs were created", gesamt > 5)
pruefe("every NPC has a face/head", mitKleidung == gesamt)

-- 3) compact HUD bar
local p = M.spielerErzeugen("Lukas")
local cl = game:GetService("StarterPlayer").StarterPlayerScripts.FuehrerscheinClient
task.spawn(lade("client", cl.Source, { script = cl }))
M.laufen(M.zeit() + 3)
local kg = p.PlayerGui.CameraToggle
local leiste = kg.Klappe.Leiste
pruefe("menu button", kg:FindFirstChild("Menue") ~= nil)
pruefe("menu closed at the start", kg.Klappe.Size.X.Offset == 0)
kg.Menue.MouseButton1Click:Fire()
pruefe("menu opens", kg.Klappe.Size.X.Offset > 300)
leiste.Daily.MouseButton1Click:Fire()
M.laufen(M.zeit() + 1)
pruefe("menu folds up after choosing", kg.Klappe.Size.X.Offset == 0)
local namen = {}
for _, k in leiste:GetChildren() do if k.ClassName == "TextButton" then namen[k.Name] = k end end
for _, n in { "Shop", "Rewards", "Daily", "My Cars", "Record", "1st (V)", "Settings" } do
	pruefe("bar has " .. n, namen[n] ~= nil or (n == "1st (V)" and leiste:FindFirstChild("1st (V)") ~= nil))
end

-- 4) Anna: first choose the class, then the checklist
local anna = fs:FindFirstChild("Rezeptionistin")
pruefe("Anna exists", anna ~= nil)
anna.HumanoidRootPart.ProximityPrompt.Triggered:Fire(p)
M.laufen(M.zeit() + 1)
local gui = p.PlayerGui.LicenseGUI
local function knopf(text)
	for _, k in gui:GetDescendants() do if k.ClassName == "TextButton" and k.Text:find(text, 1, true) then return k end end
end
local function inhalt()
	for _, k in gui:GetDescendants() do if k.ClassName == "TextLabel" and #k.Text > 40 then return k.Text end end
	return ""
end
pruefe("choice: car", knopf("Car license (B)") ~= nil)
pruefe("choice: truck", knopf("Truck license (C)") ~= nil)
knopf("Car license (B)").MouseButton1Click:Fire()
M.laufen(M.zeit() + 1)
local t = inhalt()
pruefe("car checklist: lessons + driving test, theory only optional (v50)", t:find("1.", 1, true) and t:find("2.", 1, true) and not t:find("3.", 1, true) and t:find("Driving test", 1, true) and t:find("Optional: theory", 1, true) and not t:find("whiteboard", 1, true))
pruefe("next step marked", t:find("👉", 1, true) ~= nil)
-- v31: no sign-up step any more, the first lesson can start right away (signs you up)
pruefe("start lesson button", knopf("Start lesson 1") ~= nil)
knopf("Start lesson 1").MouseButton1Click:Fire()
M.laufen(M.zeit() + 1)
pruefe("lesson started, signed up", game.ReplicatedStorage.Fuehrerschein.Aktion.OnServerInvoke(p, "status").status.angemeldet == true)
game.ReplicatedStorage.Fuehrerschein.Aktion.OnServerInvoke(p, "fahrstundeAbbrechen")
M.laufen(M.zeit() + 2)
game.ReplicatedStorage.Fuehrerschein.Oeffnen.OnClientEvent:Fire("dialog")
M.laufen(M.zeit() + 1)
knopf("Truck license (C)").MouseButton1Click:Fire()
M.laufen(M.zeit() + 1)
t = inhalt()
pruefe("truck checklist", t:find("Car license (B) first", 1, true) and t:find("Parcel Express", 1, true))
print("spawn, hud and anna ok")
