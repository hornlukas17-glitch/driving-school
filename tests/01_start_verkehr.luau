-- Generator + installer + server + client start, NPC traffic
local t0 = os.clock()
M.log = function() end
local ok, e = pcall(lade("gen", Q.gen))
print("generator:", ok, e)
M.laufen(1)
print("instances:", M.anzahl())
local karte = workspace:FindFirstChild("Karte")
print("Karte children:", karte and #karte:GetChildren())
lade("inst", Q.inst)()
local SSS = game:GetService("ServerScriptService")
-- start all server scripts
local function starte(s)
	task.spawn(lade(s:GetFullName(), s.Source, { script = s }))
end
for _, s in workspace:GetDescendants() do if s:IsA("Script") then starte(s) end end
for _, s in SSS:GetChildren() do if s:IsA("Script") then starte(s) end end
M.laufen(2)
local p = M.spielerErzeugen("Lukas")
M.istServer = false
local cl = game:GetService("StarterPlayer").StarterPlayerScripts.FuehrerscheinClient
task.spawn(lade("client", cl.Source, { script = cl }))
M.laufen(8)
print("fehler bisher:", M.fehler or 0)
print("NPC folder:", workspace:FindFirstChild("NPC_Verkehr") and #workspace.NPC_Verkehr:GetChildren())
print("geld attr:", p:GetAttribute("Geld"))
local V = require(game.ReplicatedStorage.Fuehrerschein.Verkehr)
