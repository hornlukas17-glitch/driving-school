-- Tauscht alle Haeuser der Wohngebiete gegen die neuen Haustypen (Blender -> OBJ -> 3D-Importer).
-- Voraussetzung: die vier importierten Modelle Haus_A..Haus_D liegen im Workspace oder in ServerStorage.Haustypen.
-- v59: dreht jedes neue Haus so, dass seine Tuer dort ist, wo die alte Tuer war (Importer-Drehung egal).
-- ERST auf wenigen Haeusern testen. Mehrfach ausfuehrbar. Rueckweg: ServerStorage.Haeuser_Alt (alte Teile je Haus) bzw. Strg+Z.
local CHS = game:GetService("ChangeHistoryService")
local SS = game:GetService("ServerStorage")
local RGB = Color3.fromRGB
CHS:SetWaypoint("Vor Haeuser tauschen")

-- 1) Vorlagen einsammeln
local typen = SS:FindFirstChild("Haustypen") or Instance.new("Folder")
typen.Name = "Haustypen"
typen.Parent = SS
for _, n in { "Haus_A", "Haus_B", "Haus_C", "Haus_D" } do
	local m = workspace:FindFirstChild(n)
	if m and m:IsA("Model") then m.Parent = typen end
end
local VORLAGEN = {}
for _, n in { "Haus_A", "Haus_B", "Haus_C", "Haus_D" } do
	local m = typen:FindFirstChild(n)
	assert(m, n .. " fehlt - bitte die OBJ-Datei importieren")
	local anker
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d.Name:find("Anker") then anker = d end
	end
	assert(anker, n .. ": Teil 'Anker' fehlt")
	-- Richtung zur Haustuer (waagerecht, im Vorlagen-Raum): der 3D-Importer kann die Modelle drehen (bei den Autos: Front -Z)
	local tuerRichtung
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d.Name:match("^Tuer") then
			local lok = CFrame.new(anker.Position):PointToObjectSpace(d.Position)
			tuerRichtung = Vector3.new(lok.X, 0, lok.Z)
			if tuerRichtung.Magnitude > 0.5 then tuerRichtung = tuerRichtung.Unit else tuerRichtung = nil end
			break
		end
	end
	table.insert(VORLAGEN, { name = n, modell = m, ursprung = CFrame.new(anker.Position), tuer = tuerRichtung })
end

-- 2) Musterhaeuser von vorhin zuruecknehmen (alte Teile wieder einsetzen)
local muster = workspace:FindFirstChild("Musterhaeuser")
if muster then muster:Destroy() end
local lager = SS:FindFirstChild("Musterhaus_Original")
if lager then
	for _, ablage in lager:GetChildren() do
		local x, z = ablage.Name:match("^(-?[%d%.]+)_(-?[%d%.]+)$")
		if not x then x, z = ablage.Name, "632" end
		x, z = tonumber(x), tonumber(z)
		local ziel
		for _, h in workspace.Karte.Vororte:GetChildren() do
			if h.Name == "Haus" and not h:FindFirstChild("Koerper") then
				local w = h:FindFirstChild("Weg")
				if w and math.abs(w.Position.X - x) < 12 and math.abs(w.Position.Z - z) < 16 then ziel = h end
			end
		end
		if ziel then
			for _, t in ablage:GetChildren() do t.Parent = ziel end
		end
	end
	lager:Destroy()
end

-- 3) Farben und Materialien je Gruppe (Wand/Dach je Haus zufaellig aus einer warmen Palette)
local WAND = { RGB(234, 224, 200), RGB(236, 233, 226), RGB(204, 198, 188), RGB(232, 210, 186), RGB(216, 201, 174), RGB(198, 176, 150) }
local WAND2 = { RGB(158, 107, 77), RGB(176, 128, 104), RGB(140, 96, 74), RGB(186, 152, 118) }
local DACH = { RGB(120, 52, 40), RGB(70, 70, 75), RGB(110, 74, 54), RGB(138, 66, 46) }
local LADEN = { RGB(62, 92, 78), RGB(52, 70, 96), RGB(110, 60, 52), RGB(90, 90, 86) }
local MAT = {
	Wand = { "Plaster" }, Wand2 = { "Plaster" }, Sockel = { "Concrete", RGB(107, 105, 102) },
	Dach = { "ClayRoofTiles" }, Rahmen = { "SmoothPlastic", RGB(238, 236, 230) }, Glas = { "SmoothPlastic", RGB(38, 46, 54) },
	Tuer = { "Wood", RGB(92, 56, 34) }, Laden = { "Wood" }, Metall = { "Metal", RGB(70, 72, 76) },
	Ziegel = { "Brick", RGB(128, 62, 44) }, Stein = { "Concrete", RGB(178, 174, 166) }, Holz = { "WoodPlanks", RGB(150, 106, 66) },
	Dunkel = { "Metal", RGB(36, 37, 40) }, Pflanze = { "Grass", RGB(66, 104, 44) },
}
local function gruppe(name)
	if MAT[name] then return name end
	local g = name:match("^(%a+%d?)")       -- Importer haengt evtl. Nummern an ("Wand_1", "Dach.001")
	if g and MAT[g] then return g end
	g = name:match("^(%a+)")
	return g and MAT[g] and g or nil
end

-- 4) alle Haeuser durchgehen
local alt = SS:FindFirstChild("Haeuser_Alt") or Instance.new("Folder")
alt.Name = "Haeuser_Alt"
alt.Parent = SS
local WEG = { Dach = true, Giebel = true, Tuer = true, Fenster = true }
local n, uebersprungen, gedreht, ohneTuer = 0, 0, {}, 0
local letzter = {}
local haeuser = {}
for _, h in workspace.Karte:GetDescendants() do
	if h:IsA("Model") and h.Name == "Haus" and h:FindFirstChild("Koerper") then table.insert(haeuser, h) end
end
for i, h in haeuser do
	if h:FindFirstChild("NeuesHaus") then uebersprungen += 1 continue end
	local k = h.Koerper
	-- Typ aus der Position (immer gleich), nicht zweimal derselbe direkt nebeneinander in einer Reihe
	local seed = math.floor(k.Position.X * 7.31 + k.Position.Z * 3.17) % 9973
	local r = Random.new(seed)
	local reihe = h.Parent.Name .. math.floor(k.Position.Z / 30)
	local wahl
	repeat wahl = r:NextInteger(1, #VORLAGEN) until wahl ~= letzter[reihe] or #VORLAGEN == 1
	letzter[reihe] = wahl
	local v = VORLAGEN[wahl]
	local basis = k.CFrame * CFrame.new(0, -k.Size.Y / 2, 0)
	-- leicht versetzt nach hinten/vorne, damit die Reihe nicht wie kopiert aussieht
	basis = basis * CFrame.new(0, 0, r:NextNumber(-1.2, 0.6))
	-- Tuer des neuen Hauses dorthin drehen, wo die Tuer des alten Hauses war (zur Strasse)
	local dreh = CFrame.new()
	local alteTuer = h:FindFirstChild("Tuer")
	if v.tuer and alteTuer then
		local lok = k.CFrame:PointToObjectSpace(alteTuer.Position)
		local soll = Vector3.new(lok.X, 0, lok.Z)
		if soll.Magnitude > 0.5 then
			local winkel = math.atan2(soll.X, soll.Z) - math.atan2(v.tuer.X, v.tuer.Z)
			local grad = math.floor(math.deg(winkel) % 360 / 90 + 0.5) % 4 * 90 -- Haeuser stehen rechtwinklig
			dreh = CFrame.Angles(0, math.rad(grad), 0)
			gedreht[grad] = (gedreht[grad] or 0) + 1
		end
	else
		ohneTuer += 1
	end
	local neu = Instance.new("Model")
	neu.Name = "NeuesHaus"
	local farben = { Wand = WAND[r:NextInteger(1, #WAND)], Wand2 = WAND2[r:NextInteger(1, #WAND2)], Dach = DACH[r:NextInteger(1, #DACH)], Laden = LADEN[r:NextInteger(1, #LADEN)] }
	for _, t in v.modell:GetDescendants() do
		if t:IsA("BasePart") and not t.Name:find("Anker") then
			local c = t:Clone()
			c.Anchored = true
			c.CanCollide = false
			c.CanQuery = false
			c.CanTouch = false
			c.CFrame = basis * dreh * v.ursprung:ToObjectSpace(t.CFrame)
			local g = gruppe(t.Name)
			local m = g and MAT[g]
			if m then
				pcall(function() c.Material = Enum.Material[m[1]] end)
				c.Color = farben[g] or m[2] or c.Color
				if g == "Dach" and c.Color == DACH[2] then pcall(function() c.Material = Enum.Material.RoofShingles end) end
				if g == "Glas" then c.Reflectance = 0.12 end
				c.CastShadow = g ~= "Pflanze" and g ~= "Glas"
			end
			c.Parent = neu
		end
	end
	-- alte sichtbare Teile sichern, Koerper bleibt unsichtbar als Kollision (und fuer die Minimap)
	local sicher = Instance.new("Model")
	sicher.Name = h:GetFullName() .. "@" .. math.floor(k.Position.X) .. "," .. math.floor(k.Position.Z)
	for _, t in h:GetChildren() do
		if t:IsA("BasePart") and WEG[t.Name] then t.Parent = sicher end
	end
	sicher.Parent = alt
	k.Transparency = 1
	k.CastShadow = false
	neu:SetAttribute("Typ", v.name)
	neu.Parent = h
	n += 1
	if i % 25 == 0 then task.wait() end
end
CHS:SetWaypoint("Haeuser getauscht")
local dreh = {}
for grad, anzahl in gedreht do table.insert(dreh, grad .. "°: " .. anzahl) end
return ("%d Haeuser getauscht, %d waren schon neu | Drehung %s | ohne Tuer-Erkennung %d"):format(n, uebersprungen, table.concat(dreh, ", "), ohneTuer)
