M.log = function() end
lade("gen", Q.gen)()
lade("inst", Q.inst)()
for _, s in game:GetService("ServerScriptService"):GetChildren() do if s:IsA("Script") then task.spawn(lade(s.Name, s.Source, { script = s })) end end
for _, s in workspace:GetDescendants() do if s:IsA("Script") then task.spawn(lade(s.Name, s.Source, { script = s })) end end
M.laufen(2)
local p = M.spielerErzeugen("Lukas")
local cl = game:GetService("StarterPlayer").StarterPlayerScripts.FuehrerscheinClient
task.spawn(lade("client", cl.Source, { script = cl }))
M.laufen(6)
local menue = p.PlayerGui:FindFirstChild("Startbildschirm")
for _, k in menue:GetChildren() do if k.Text == "PLAY" then k.Activated:Fire() end end
M.laufen(M.zeit() + 5)
print("admin attr:", p:GetAttribute("Admin"), "gui:", p.PlayerGui:FindFirstChild("Admin") and p.PlayerGui.Admin.Enabled)
for _, b in p.PlayerGui.Admin:GetDescendants() do if b.ClassName == "TextButton" and b.Text:find("100K") then b.MouseButton1Click:Fire() end end
M.laufen(M.zeit() + 1)
print("money:", p:GetAttribute("Geld"))
for _, b in p.PlayerGui.Admin:GetDescendants() do if b.ClassName == "TextButton" and b.Text == "0" then b.MouseButton1Click:Fire() end end
M.laufen(M.zeit() + 1)
print("money after reset:", p:GetAttribute("Geld"), "errors", M.fehler or 0)
