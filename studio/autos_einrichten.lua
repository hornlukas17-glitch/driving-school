-- v57: neue Autos (Blender -> OBJ) einrichten und die ~200 Klotz-Parkautos austauschen.
-- Voraussetzung: Lukas hat dist/mesh/autos/Kleinwagen.obj, Limousine.obj, SUV.obj, Transporter.obj, Lkw.obj
-- mit dem 3D-Importer importiert (liegen dann als Modelle im Workspace, Namen wie die Dateien).
-- Mehrfach ausführbar. Rückweg: Strg+Z oder ServerStorage.Parkautos_Alt.
local CHS = game:GetService("ChangeHistoryService")
local SS = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")
CHS:SetWaypoint("Vor Autos einrichten")
local bericht = {}
local NAMEN = { "Kleinwagen", "Limousine", "SUV", "Transporter", "Lkw" }

-- 0) mehrfach importierte Modelle in den ServerStorage (nichts löschen), je Name bleibt eins
local dup = SS:FindFirstChild("Autos_Duplikate") or Instance.new("Folder")
dup.Name = "Autos_Duplikate"
dup.Parent = SS
local gesehen, verschoben = {}, 0
for _, m in workspace:GetChildren() do
	if m:IsA("Model") and table.find(NAMEN, m.Name) then
		if gesehen[m.Name] then m.Parent = dup verschoben += 1 else gesehen[m.Name] = true end
	end
end
table.insert(bericht, "Duplikate nach ServerStorage.Autos_Duplikate: " .. verschoben)

-- 1) Vorlagen nach ReplicatedStorage.Fuehrerschein.Autos (der Client baut daraus den NPC-Verkehr)
local ordner = RS.Fuehrerschein:FindFirstChild("Autos") or Instance.new("Folder")
ordner.Name = "Autos"
ordner.Parent = RS.Fuehrerschein
for _, n in NAMEN do
	local m = workspace:FindFirstChild(n) or workspace:FindFirstChild(n .. "_obj")
	if m and m:IsA("Model") then
		local alt = ordner:FindFirstChild(n)
		if alt then alt:Destroy() end
		m.Name = n
		m.Parent = ordner
	end
	local v = ordner:FindFirstChild(n)
	if v then
		local teile, anker = 0, false
		for _, t in v:GetDescendants() do
			if t:IsA("BasePart") then
				teile += 1
				t.Anchored = true
				t.CanCollide = false
				t.CanQuery = false
				t.CanTouch = false
				if t.Name:match("^Anker") then anker = true t.Transparency = 1 end
				pcall(function() t.RenderFidelity = Enum.RenderFidelity.Automatic end)
				pcall(function() t.CollisionFidelity = Enum.CollisionFidelity.Box end)
			end
		end
		table.insert(bericht, ("%s: %d Teile%s"):format(n, teile, anker and "" or " – ACHTUNG: Teil 'Anker' fehlt"))
	else
		table.insert(bericht, n .. ": fehlt (OBJ noch nicht importiert?)")
	end
end

-- 2) Parkautos tauschen (Kleinwagen / Limousine / SUV, fest nach Position gewählt)
local Verkehr = require(RS.Fuehrerschein.Verkehr)
local alt = SS:FindFirstChild("Parkautos_Alt") or Instance.new("Folder")
alt.Name = "Parkautos_Alt"
alt.Parent = SS
local PKW = {}
for _, n in { "Kleinwagen", "Limousine", "SUV" } do
	if ordner:FindFirstChild(n) then table.insert(PKW, ordner[n]) end
end
local LAENGE = { Kleinwagen = 12, Limousine = 14.5, SUV = 15 }
local getauscht, schon = 0, 0
if #PKW > 0 then
	local liste = {}
	for _, m in workspace.Karte:GetDescendants() do
		if m:IsA("Model") and m.Name == "ParkendesAuto" then table.insert(liste, m) end
	end
	for i, m in liste do
		if m:FindFirstChild("NeuesAuto") then schon += 1 continue end
		local k = m:FindFirstChild("Karosserie")
		if not k then continue end
		local basis = k.CFrame * CFrame.new(0, -2.5, 0)
		local seed = math.floor(basis.Position.X * 3.7 + basis.Position.Z * 5.3) % 997
		local v = PKW[seed % #PKW + 1]
		local neu = Verkehr.ausVorlage(v, LAENGE[v.Name], k.Color, nil)
		if neu then
			neu.Name = "NeuesAuto"
			neu:PivotTo(basis)
			local sicher = Instance.new("Model")
			sicher.Name = ("%d,%d"):format(math.floor(basis.Position.X), math.floor(basis.Position.Z))
			for _, t in m:GetChildren() do
				if t:IsA("BasePart") then t.Parent = sicher end
			end
			sicher.Parent = alt
			neu.Parent = m
			getauscht += 1
		end
		if i % 25 == 0 then task.wait() end
	end
end
table.insert(bericht, ("Parkautos: %d getauscht, %d waren schon neu"):format(getauscht, schon))
CHS:SetWaypoint("Autos eingerichtet")
print(table.concat(bericht, "\n"))
return table.concat(bericht, "\n")
