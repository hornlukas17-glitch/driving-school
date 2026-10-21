-- v56 -> v57 (neue Autos im NPC-Verkehr). Vorher update_v56.lua. Danach OBJ importieren und studio/autos_einrichten.lua ausführen.
do
local function ersetze(src, alt, neu)
	local a, b = string.find(src, alt, 1, true)
	assert(a, "nicht gefunden: " .. alt:sub(1, 60))
	assert(not string.find(src, alt, b + 1, true), "mehrfach: " .. alt:sub(1, 60))
	return src:sub(1, a - 1) .. neu .. src:sub(b + 1)
end
local s = game.StarterPlayer.StarterPlayerScripts.FuehrerscheinClient
local src = s.Source
assert(#src == 193439, "Ausgangsstand passt nicht: " .. #src)
src = ersetze(src, [===[
local spieler = Players.LocalPlayer
print("[Driving School] client v56 loaded")
local ordner = RS:WaitForChild("Fuehrerschein")
]===], [===[
local spieler = Players.LocalPlayer
print("[Driving School] client v57 loaded")
local ordner = RS:WaitForChild("Fuehrerschein")
]===])
src = ersetze(src, [===[
do
	print("[Driving School] start screen v56 loading")
	local menue = Instance.new("ScreenGui")
]===], [===[
do
	print("[Driving School] start screen v57 loading")
	local menue = Instance.new("ScreenGui")
]===])
assert(#src == 193439, "Ergebnis-Länge falsch: " .. #src)
s.Source = src
print(s.Name .. ": " .. #src .. " Zeichen")
end

do
local function ersetze(src, alt, neu)
	local a, b = string.find(src, alt, 1, true)
	assert(a, "nicht gefunden: " .. alt:sub(1, 60))
	assert(not string.find(src, alt, b + 1, true), "mehrfach: " .. alt:sub(1, 60))
	return src:sub(1, a - 1) .. neu .. src:sub(b + 1)
end
local s = game.ReplicatedStorage.Fuehrerschein.Verkehr
local src = s.Source
assert(#src == 31369, "Ausgangsstand passt nicht: " .. #src)
src = ersetze(src, [===[

-- Builds a vehicle model (all parts anchored; it is moved as a whole). Front = -Z.
]===], [===[

-- v57: new car bodies made in Blender (tools/blender/auto_*.py -> OBJ -> Studio importer).
-- Templates live in ReplicatedStorage.Fuehrerschein.Autos (Kleinwagen, Limousine, SUV, Transporter, Lkw), each with a
-- tiny part "Anker" at the car's origin (ground, centre). Parts are named after their material group (Lack, Glas, ...).
-- Without templates the old block cars below are built (nothing breaks).
Verkehr.VORLAGEN_NAMEN = { kleinwagen = "Kleinwagen", limousine = "Limousine", suv = "SUV", transporter = "Transporter", lkw = "Lkw" }
local GRUPPEN = {
	Glas = { Color3.fromRGB(35, 45, 60), Enum.Material.Glass, 0.15 },
	Schwarz = { Color3.fromRGB(28, 28, 32), Enum.Material.SmoothPlastic },
	Reifen = { Color3.fromRGB(22, 22, 24), Enum.Material.SmoothPlastic },
	Felge = { Color3.fromRGB(175, 178, 185), Enum.Material.Metal },
	Chrom = { Color3.fromRGB(205, 205, 210), Enum.Material.Metal, 0.2 },
	Licht = { Color3.fromRGB(255, 250, 225), Enum.Material.Neon },
	Ruecklicht = { Color3.fromRGB(170, 15, 15), Enum.Material.Neon },
	Blinker = { Color3.fromRGB(240, 130, 20), Enum.Material.SmoothPlastic },
	Kennzeichen = { Color3.fromRGB(235, 235, 230), Enum.Material.SmoothPlastic },
	Innen = { Color3.fromRGB(25, 25, 28), Enum.Material.SmoothPlastic },
	Akzent = { Color3.fromRGB(235, 235, 235), Enum.Material.SmoothPlastic },
}
local function gruppeVon(name)
	local g = name:match("^(%a+)")
	return g
end
Verkehr.gruppeVon = gruppeVon

-- copies a template into a new model: origin = Anker, front turned to -Z, scaled to the given length
function Verkehr.ausVorlage(vorlage, laenge, farbe, akzent)
	local anker
	for _, t in vorlage:GetDescendants() do
		if t:IsA("BasePart") and gruppeVon(t.Name) == "Anker" then anker = t break end
	end
	if not anker then return nil end
	-- length of the template along its own Z (without the anchor) -> scale factor
	local minZ, maxZ, maxX, maxY = math.huge, -math.huge, 0, 0
	for _, t in vorlage:GetDescendants() do
		if t:IsA("BasePart") and t ~= anker then
			local p = anker.CFrame:PointToObjectSpace(t.Position)
			minZ, maxZ = math.min(minZ, p.Z - t.Size.Z / 2), math.max(maxZ, p.Z + t.Size.Z / 2)
			maxX, maxY = math.max(maxX, math.abs(p.X) + t.Size.X / 2), math.max(maxY, p.Y + t.Size.Y / 2)
		end
	end
	local faktor = (maxZ > minZ and laenge) and laenge / (maxZ - minZ) or 1
	if math.abs(faktor - 1) < 0.06 then faktor = 1 end
	local m = Instance.new("Model")
	local wurzel = Instance.new("Part")
	wurzel.Name = "Wurzel"
	wurzel.Size = Vector3.new(1, 1, 1)
	wurzel.Transparency = 1
	wurzel.Anchored = true
	wurzel.CanCollide = false
	wurzel.CanQuery = false
	wurzel.CanTouch = false
	wurzel.Parent = m
	m.PrimaryPart = wurzel
	-- invisible box you bump into (like the old block body), the mesh parts themselves don't collide
	local f0 = faktor
	local koerper = Instance.new("Part")
	koerper.Name = "Karosserie"
	koerper.Size = Vector3.new(maxX * 2 * 0.92, maxY * 0.55, (maxZ - minZ) * 0.95) * f0
	koerper.CFrame = CFrame.new(0, maxY * f0 * 0.38, 0)
	koerper.Transparency = 1
	koerper.Anchored = true
	koerper.CanCollide = true
	koerper.CanQuery = false
	koerper.CanTouch = false
	koerper.Parent = m
	local drehen = CFrame.Angles(0, math.pi, 0) -- OBJ front = +Z, traffic front = -Z
	for _, t in vorlage:GetDescendants() do
		if t:IsA("BasePart") and t ~= anker then
			local g = gruppeVon(t.Name)
			local c = t:Clone()
			c:ClearAllChildren()
			c.Name = g or t.Name
			local lokal = anker.CFrame:ToObjectSpace(t.CFrame)
			if faktor ~= 1 then
				lokal = CFrame.new(lokal.Position * faktor) * lokal.Rotation
				c.Size = t.Size * faktor
			end
			c.CFrame = drehen * lokal
			c.Anchored = true
			c.CanCollide = false
			c.CanQuery = false
			c.CanTouch = false
			c.CastShadow = g ~= "Glas" and g ~= "Licht" and g ~= "Ruecklicht" and g ~= "Chrom"
			local def = GRUPPEN[g]
			if g == "Lack" then
				c.Color = farbe
				local hell = 0.299 * farbe.R + 0.587 * farbe.G + 0.114 * farbe.B
				c.Material = hell > 0.72 and Enum.Material.SmoothPlastic or Enum.Material.Metal
				c.Reflectance = 0.05
			elseif g == "Akzent" and akzent then
				c.Color = akzent
				c.Material = Enum.Material.SmoothPlastic
			elseif def then
				c.Color = def[1]
				c.Material = def[2]
				c.Reflectance = def[3] or 0
			end
			c.Parent = m
		end
	end
	return m
end

-- Builds a vehicle model (all parts anchored; it is moved as a whole). Front = -Z.
]===])
src = ersetze(src, [===[
	local farbe = FARBEN[(farbIndex - 1) % #FARBEN + 1]
	local m = Instance.new("Model")
]===], [===[
	local farbe = FARBEN[(farbIndex - 1) % #FARBEN + 1]
	do
		local autos = script.Parent:FindFirstChild("Autos")
		local vorlage = autos and Verkehr.VORLAGEN_NAMEN[art] and autos:FindFirstChild(Verkehr.VORLAGEN_NAMEN[art])
		if vorlage then
			local akzent = (art == "lkw" or art == "transporter") and FARBEN[((firmaIndex or 1) + 2) % #FARBEN + 1] or nil
			local m = Verkehr.ausVorlage(vorlage, ARTEN[art].laenge, farbe, akzent)
			if m then
				m.Name = "NPC_" .. art
				return m
			end
		end
	end
	local m = Instance.new("Model")
]===])
assert(#src == 36115, "Ergebnis-Länge falsch: " .. #src)
s.Source = src
print(s.Name .. ": " .. #src .. " Zeichen")
end
print("v57 eingespielt")
