local events = {}
M.log = function(name, p, info) if name == "FireClient Fahrstunde" and type(info) == "table" and info.typ ~= "ziel" then print("  event:", info.typ, info.text or info.betrag or "", info.grund or "") end end
lade("gen", Q.gen)()
M.laufen(1)
lade("inst", Q.inst)()
local SSS = game:GetService("ServerScriptService")
for _, s in workspace:GetDescendants() do if s:IsA("Script") then task.spawn(lade(s.Name, s.Source, { script = s })) end end
for _, s in SSS:GetChildren() do if s:IsA("Script") then task.spawn(lade(s.Name, s.Source, { script = s })) end end
M.laufen(2)
local p = M.spielerErzeugen("Lukas")
local cl = game:GetService("StarterPlayer").StarterPlayerScripts.FuehrerscheinClient
task.spawn(lade("client", cl.Source, { script = cl }))
M.laufen(6)
local aktion = game.ReplicatedStorage.Fuehrerschein.Aktion
local function frage(was, e) return aktion.OnServerInvoke(p, was, e) end
local ah = workspace.Karte.Vorstadt.Autohaus
local function pruefe(name, ok) print((ok and "OK  " or "FAIL") .. " " .. name) if not ok then error("check failed: " .. name) end end
-- showroom: only two platforms (exclusive car first), green buy zone, Marco and Sophie
local podeste, autos = 0, 0
for _, x in ah:GetChildren() do
	if x.Name == "Podest" then podeste += 1 end
	if x.Name:sub(1, 12) == "Ausstellung_" then autos += 1 end
end
pruefe("2 podiums, 2 showroom cars", podeste == 2 and autos == 2)
pruefe("exclusive car on a podium", ah:FindFirstChild("Ausstellung_gs_night") ~= nil)
pruefe("green buy zone", ah:FindFirstChild("Kaufzone") ~= nil)
pruefe("Marco and Sophie", ah:FindFirstChild("Verkaeufer") ~= nil and ah:FindFirstChild("Verkaeuferin") ~= nil)
-- walking into the green zone opens the catalogue
pruefe("catalogue closed at the start", p.PlayerGui:FindFirstChild("Autohaus") == nil)
p.Character:PivotTo(ah.Kaufzone.CFrame + Vector3.new(0, 3, 0))
M.laufen(M.zeit() + 1)
pruefe("green zone opens the catalogue", p.PlayerGui:FindFirstChild("Autohaus") ~= nil)
p.PlayerGui.Autohaus:Destroy()
M.laufen(M.zeit() + 1)
pruefe("does not re-open while standing in it", p.PlayerGui:FindFirstChild("Autohaus") == nil)
print("buy no money:", frage("autoKaufen", "suv").fehler)
for i = 1, 100 do frage("dev", { befehl = "geld" }) end
M.laufen(M.zeit() + 1)
print("get w/o license:", frage("autoHolen", { typ = "suv" }).fehler)
for _, t in { "suv", "sport", "renn" } do print("buy", t, frage("autoKaufen", t).text ~= nil) end
print("money:", p:GetAttribute("Geld"))
frage("dev", { befehl = "lizenz" })
M.laufen(M.zeit() + 15)
-- player stands near the dealership
p.Character:PivotTo(CFrame.new(60, 3, -376))
for _, t in { "suv", "sport", "renn" } do
	local r = frage("autoHolen", { typ = t, farbe = 3 })
	local a = workspace:FindFirstChild("Auto_Lukas")
	print("get", t, r.text or r.fehler, a and tostring(a.Chassis.Position), a and a:GetAttribute("MaxTempo"))
end
local a = workspace.Auto_Lukas
a.Fahrersitz:Sit(p.Character.Humanoid)
M.laufen(M.zeit() + 1)
-- the showroom prompt opens the dialog in the client
ah.Podest.ProximityPrompt.Triggered:Fire(p)
M.laufen(M.zeit() + 1)
print("dialog title:", p.PlayerGui.LicenseGUI.Enabled)
print("park away:", frage("autoWeg").text, workspace:FindFirstChild("Auto_Lukas") == nil)
print("errors", M.fehler or 0)
