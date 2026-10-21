-- NPC traffic: cars, SUVs, vans and trucks driving on lanes through the map.
-- The SERVER decides where every vehicle is (it keeps right, follows curves and roundabouts,
-- stops at red lights and STOP signs, keeps its distance and brakes for pedestrians and players).
-- Every PLAYER draws the vehicles on their own computer, so they move perfectly smoothly.
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Verkehr = {}
Verkehr.POLIZEI = false -- v52: no police cars in the traffic (Lukas)

local SPUR = 5.5          -- lane offset from the road centre
local SPUR_AUTOBAHN = 10  -- lane offset on the highway
local RING = 23           -- radius of the lane in a roundabout
local HZ = -520

-- ---------------------------------------------------------------
-- Routes: centre-line nodes. k = true marks a roundabout centre.
-- ---------------------------------------------------------------
local function n(x, z, k) return { x = x, z = z, k = k } end
local ROUTEN = {
	-- big loop: country roads, city, highway
	{ n(-780, 0, true), n(780, 0), n(780, HZ), n(-780, HZ) },
	-- the same loop the other way round
	{ n(-780, 0, true), n(-780, HZ), n(780, HZ), n(780, 0) },
	-- south loop with three roundabouts
	{ n(-780, 0, true), n(-780, 600, true), n(0, 600, true), n(780, 600, true), n(780, 0) },
	{ n(-780, 0, true), n(780, 0), n(780, 600, true), n(0, 600, true), n(-780, 600, true) },
	-- city blocks with traffic lights
	{ n(-104, -104), n(104, -104), n(104, 104), n(-104, 104) },
	{ n(-104, -104), n(-104, 104), n(104, 104), n(104, -104) },
	-- the two gated communities (30 km/h, right before left, YIELD and STOP)
	{ n(500, 40), n(700, 40), n(700, 208), n(500, 208) },
	{ n(500, -40), n(500, -208), n(700, -208), n(700, -40) },
}
local ANZAHL = { 5, 5, 3, 3, 3, 3, 2, 2 }
Verkehr.ROUTEN = ROUTEN

local function rechtsVon(d)
	return Vector3.new(-d.Z, 0, d.X)
end
local function flach(v)
	return Vector3.new(v.X, 0, v.Z)
end

-- Intersection of two lines (point + direction) in the XZ plane
local function schnitt(p1, d1, p2, d2)
	local nenner = d1.X * d2.Z - d1.Z * d2.X
	if math.abs(nenner) < 1e-6 then return nil end
	local t = ((p2.X - p1.X) * d2.Z - (p2.Z - p1.Z) * d2.X) / nenner
	return p1 + d1 * t
end

local function winkelVon(v)
	return math.atan2(v.Z, v.X)
end

-- Builds the driven polyline (lane, curves, roundabouts) for a loop of nodes
function Verkehr.spur(knoten)
	local anzahl = #knoten
	local punkte = {}
	local function P(i)
		local k = knoten[(i - 1) % anzahl + 1]
		return Vector3.new(k.x, 0, k.z), k.k
	end
	local function abschnitt(i) -- segment from node i to node i+1
		local a = P(i)
		local b = P(i + 1)
		local d = (b - a).Unit
		local aufAutobahn = math.abs(a.Z - HZ) < 1 and math.abs(b.Z - HZ) < 1
		local versatz = aufAutobahn and SPUR_AUTOBAHN or SPUR
		return a + rechtsVon(d) * versatz, d
	end
	for i = 1, anzahl do
		local c, istKreisel = P(i)
		local pIn, dIn = abschnitt(i - 1)
		local pOut, dOut = abschnitt(i)
		if istKreisel then
			-- drive around the island: angle decreases (right-hand traffic)
			local aRein = winkelVon(-dIn) - math.rad(14)
			local aRaus = winkelVon(dOut) + math.rad(14)
			while aRaus > aRein do aRaus -= 2 * math.pi end
			while aRein - aRaus > 2 * math.pi do aRaus += 2 * math.pi end
			local schritte = math.max(4, math.floor((aRein - aRaus) / math.rad(12)))
			for s = 0, schritte do
				local a = aRein + (aRaus - aRein) * s / schritte
				table.insert(punkte, c + Vector3.new(math.cos(a), 0, math.sin(a)) * RING)
			end
		else
			local ecke = schnitt(pIn, dIn, pOut, dOut)
			if not ecke or dIn:Dot(dOut) > 0.98 then
				table.insert(punkte, pOut)
			else
				-- rounded corner (quadratic curve around the corner point)
				local r = 9
				local a, b = ecke - dIn * r, ecke + dOut * r
				for s = 0, 6 do
					local t = s / 6
					table.insert(punkte, a * (1 - t) ^ 2 + ecke * 2 * (1 - t) * t + b * t ^ 2)
				end
			end
		end
	end
	-- cumulative distances
	local laengen, gesamt = { 0 }, 0
	for i = 2, #punkte + 1 do
		local a = punkte[i - 1]
		local b = punkte[(i - 1) % #punkte + 1]
		gesamt += (b - a).Magnitude
		laengen[i] = gesamt
	end
	return { punkte = punkte, laengen = laengen, gesamt = gesamt }
end

-- Position and direction at distance s along the lane
function Verkehr.ort(spur, s)
	s = s % spur.gesamt
	local p, l = spur.punkte, spur.laengen
	local lo, hi = 1, #p
	while lo < hi do
		local mitte = (lo + hi + 1) // 2
		if l[mitte] <= s then lo = mitte else hi = mitte - 1 end
	end
	local a = p[lo]
	local b = p[lo % #p + 1]
	local t = (s - l[lo]) / math.max(l[lo + 1] - l[lo], 1e-6)
	local d = b - a
	return a + d * t, (d.Magnitude > 1e-6) and d.Unit or Vector3.new(0, 0, -1)
end

-- ---------------------------------------------------------------
-- Vehicle types: length, width, top speed (km/h), share on country roads / in the city
-- ---------------------------------------------------------------
local ARTEN = {
	kleinwagen = { laenge = 12, breite = 6.2, max = 75, land = 0.22, stadt = 0.3 },
	limousine = { laenge = 14.5, breite = 6.8, max = 80, land = 0.25, stadt = 0.3 },
	suv = { laenge = 15, breite = 7.2, max = 78, land = 0.2, stadt = 0.25 },
	transporter = { laenge = 17, breite = 7.2, max = 70, land = 0.15, stadt = 0.15 },
	lkw = { laenge = 26, breite = 8.4, max = 62, land = 0.18, stadt = 0 },
	polizei = { laenge = 14.5, breite = 6.8, max = 85, land = 0, stadt = 0 },
}
local ART_LISTE = { "kleinwagen", "limousine", "suv", "transporter", "lkw" }
Verkehr.ARTEN = ARTEN

local FARBEN = {
	Color3.fromRGB(200, 30, 35), Color3.fromRGB(30, 80, 170), Color3.fromRGB(235, 235, 235), Color3.fromRGB(25, 25, 28),
	Color3.fromRGB(160, 165, 170), Color3.fromRGB(40, 120, 70), Color3.fromRGB(240, 190, 40), Color3.fromRGB(230, 110, 30),
	Color3.fromRGB(110, 40, 120), Color3.fromRGB(90, 160, 210), Color3.fromRGB(120, 20, 30), Color3.fromRGB(60, 65, 75),
	Color3.fromRGB(245, 140, 160), Color3.fromRGB(150, 110, 70), Color3.fromRGB(20, 140, 150), Color3.fromRGB(190, 210, 60),
}
local FIRMEN = { "FRESH FOODS", "BUILDMAX", "CITY MOVERS", "SUNNY DAIRY", "TECHSHIP", "GREEN GROCER", "COOL DRINKS" }

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
function Verkehr.modell(art, farbIndex, firmaIndex)
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
	m.Name = "NPC_" .. art
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
	local function teil(name, gr, x, y, z, f, mat, form, transparenz, kollision)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = gr
		p.CFrame = CFrame.new(x, y, z)
		p.Color = f
		p.Material = mat or Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Transparency = transparenz or 0
		p.Anchored = true
		p.CanCollide = kollision == true
		p.CanQuery = false
		p.CanTouch = false
		if form then p.Shape = form end
		if f == farbe and p.Material == Enum.Material.SmoothPlastic then
			-- metallic paint like the player cars (very light colours stay plastic)
			if 0.299 * f.R + 0.587 * f.G + 0.114 * f.B > 0.72 then p.Reflectance = 0.06 else p.Material = Enum.Material.Metal p.Reflectance = 0.05 end
		end
		p.Parent = m
		return p
	end
	local function keil(name, gr, cf, f, mat, transparenz)
		local w = Instance.new("WedgePart")
		w.Name = name
		w.Size = gr
		w.CFrame = cf
		w.Color = f
		w.Material = mat or Enum.Material.SmoothPlastic
		w.Transparency = transparenz or 0
		w.Anchored = true
		w.CanCollide = false
		w.CanQuery = false
		w.CanTouch = false
		w.Parent = m
		return w
	end
	local function rad(x, z, r)
		local w = teil("Rad", Vector3.new(1.1, r * 2, r * 2), x, r, z, Color3.fromRGB(25, 25, 25), nil, Enum.PartType.Cylinder)
		w.CFrame = CFrame.new(x, r, z)
		teil("Felge", Vector3.new(1.16, r * 1.15, r * 1.15), x, r, z, Color3.fromRGB(190, 190, 195), Enum.Material.Metal, Enum.PartType.Cylinder)
	end
	local function lichter(breite, y, vorne, hinten, gross)
		for _, s in { -1, 1 } do
			teil("Licht", Vector3.new(gross or 1.4, 0.45, 0.2), s * (breite / 2 - 1.1), y, vorne - 0.05, Color3.fromRGB(255, 250, 225), Enum.Material.Neon)
			teil("Ruecklicht", Vector3.new(gross or 1.4, 0.45, 0.2), s * (breite / 2 - 1.1), y, hinten + 0.05, Color3.fromRGB(170, 15, 15), Enum.Material.Neon)
		end
	end
	local glas = Color3.fromRGB(35, 45, 60)
	local schwarz = Color3.fromRGB(28, 28, 32)
	local d = ARTEN[art]
	local L, B = d.laenge, d.breite

	local polizei = art == "polizei"
	if polizei then farbe = Color3.fromRGB(245, 245, 245) end
	if art == "kleinwagen" or art == "limousine" or art == "suv" or polizei then
		local hoch = art == "suv" and 1.0 or 0
		local r = art == "suv" and 1.45 or 1.2
		local unten = r + 0.4
		-- lower body
		teil("Karosserie", Vector3.new(B, 2.0 + hoch, L - 1), 0, unten + (2.0 + hoch) / 2, 0, farbe, nil, nil, nil, true)
		teil("Stossstange", Vector3.new(B - 0.4, 1.0, 0.6), 0, unten + 0.3, -L / 2 + 0.3, schwarz)
		teil("Stossstange", Vector3.new(B - 0.4, 1.0, 0.6), 0, unten + 0.3, L / 2 - 0.3, schwarz)
		-- cabin with sloped windows
		local kabineL = art == "kleinwagen" and 6.5 or (art == "suv" and 8.5 or 7)
		local kabineZ = art == "kleinwagen" and 1.2 or (art == "suv" and 1.4 or 0.8)
		local oben = unten + 2.0 + hoch
		local kh = 2.1
		teil("Kabine", Vector3.new(B - 0.8, kh, kabineL), 0, oben + kh / 2, kabineZ, farbe)
		teil("Scheiben", Vector3.new(B - 0.7, kh - 0.5, kabineL - 0.4), 0, oben + kh / 2 - 0.05, kabineZ, glas, Enum.Material.Glass, nil, 0.2)
		keil("Frontscheibe", Vector3.new(B - 0.8, kh, 2.2), CFrame.new(0, oben + kh / 2, kabineZ - kabineL / 2 - 1.1), glas, Enum.Material.Glass, 0.2)
		local heckLang = art == "limousine" and 1.8 or 0.6
		keil("Heckscheibe", Vector3.new(B - 0.8, kh, heckLang), CFrame.new(0, oben + kh / 2, kabineZ + kabineL / 2 + heckLang / 2) * CFrame.Angles(0, math.pi, 0), glas, Enum.Material.Glass, 0.2)
		teil("Dach", Vector3.new(B - 0.9, 0.25, kabineL - 0.4), 0, oben + kh + 0.1, kabineZ, farbe)
		if art == "suv" then
			for _, s in { -1, 1 } do
				teil("Dachreling", Vector3.new(0.25, 0.25, kabineL - 1), s * (B / 2 - 0.9), oben + kh + 0.35, kabineZ, schwarz)
			end
		end
		local achse = L / 2 - (art == "kleinwagen" and 2.2 or 2.8)
		for _, s in { -1, 1 } do
			rad(s * (B / 2 - 0.4), -achse, r)
			rad(s * (B / 2 - 0.4), achse, r)
			teil("Spiegel", Vector3.new(0.6, 0.5, 0.6), s * (B / 2 + 0.2), oben + 0.4, kabineZ - kabineL / 2 - 0.3, farbe)
		end
		lichter(B, unten + 1.2 + hoch * 0.5, -L / 2 + 0.5, L / 2 - 0.5)
		teil("Kennzeichen", Vector3.new(2.2, 0.6, 0.1), 0, unten + 0.9, L / 2 - 0.45, Color3.new(1, 1, 1))
		if polizei then
			-- blue stripe, "POLICE" on the sides and a light bar on the roof
			local streifen = teil("Streifen", Vector3.new(B + 0.05, 0.7, L - 1.5), 0, unten + 1.1, 0, Color3.fromRGB(20, 60, 160))
			for _, seite in { Enum.NormalId.Left, Enum.NormalId.Right } do
				local g = Instance.new("SurfaceGui")
				g.Face = seite
				g.Parent = streifen
				local l = Instance.new("TextLabel")
				l.Size = UDim2.fromScale(1, 1)
				l.BackgroundTransparency = 1
				l.Text = "POLICE"
				l.Font = Enum.Font.GothamBlack
				l.TextScaled = true
				l.TextColor3 = Color3.new(1, 1, 1)
				l.Parent = g
			end
			local dachY = unten + 2.0 + 2.1 + 0.45
			teil("Lichtbalken", Vector3.new(4.6, 0.4, 1.2), 0, dachY, 0.8 - 1.5, Color3.fromRGB(40, 40, 45))
			local blau = teil("Blaulicht", Vector3.new(1.8, 0.5, 1.0), -1.2, dachY + 0.35, 0.8 - 1.5, Color3.fromRGB(20, 40, 120), Enum.Material.SmoothPlastic)
			blau:SetAttribute("Farbe", "blau")
			local rot = teil("Blaulicht", Vector3.new(1.8, 0.5, 1.0), 1.2, dachY + 0.35, 0.8 - 1.5, Color3.fromRGB(120, 20, 20), Enum.Material.SmoothPlastic)
			rot:SetAttribute("Farbe", "rot")
		end
	elseif art == "transporter" then
		teil("Karosserie", Vector3.new(B, 6.6, L - 4.5), 0, 4.6, 2.0, farbe, nil, nil, nil, true)
		teil("Front", Vector3.new(B, 3.4, 4.2), 0, 2.9, -L / 2 + 2.3, farbe, nil, nil, nil, true)
		keil("Frontscheibe", Vector3.new(B - 0.4, 3.1, 2.0), CFrame.new(0, 6.2, -L / 2 + 3.2), glas, Enum.Material.Glass, 0.15)
		teil("Stossstange", Vector3.new(B - 0.2, 1.0, 0.6), 0, 1.6, -L / 2 + 0.3, schwarz)
		for _, s in { -1, 1 } do
			teil("Seitenfenster", Vector3.new(0.1, 2.2, 2.2), s * (B / 2 + 0.03), 6.2, -L / 2 + 5.4, glas, Enum.Material.Glass, nil, 0.15)
			rad(s * (B / 2 - 0.4), -L / 2 + 3.4, 1.35)
			rad(s * (B / 2 - 0.4), L / 2 - 3.2, 1.35)
		end
		lichter(B, 3.4, -L / 2 + 0.2, L / 2 - 0.25)
	else -- box truck
		local kabine = teil("Fahrerhaus", Vector3.new(B - 0.2, 7.6, 6), 0, 5.4, -L / 2 + 3.2, farbe, nil, nil, nil, true)
		kabine.Reflectance = 0.1
		teil("Frontscheibe", Vector3.new(B - 0.8, 2.8, 0.2), 0, 7.2, -L / 2 + 0.15, glas, Enum.Material.Glass, nil, 0.15)
		teil("Grill", Vector3.new(B - 2.5, 1.6, 0.2), 0, 3.4, -L / 2 + 0.15, schwarz)
		teil("Rahmen", Vector3.new(B - 2.4, 1, L - 2), 0, 2.0, 0, schwarz)
		local kofferFarbe = ((firmaIndex or 1) % 2 == 0) and Color3.fromRGB(240, 240, 240) or farbe:Lerp(Color3.new(1, 1, 1), 0.75)
		local koffer = teil("Koffer", Vector3.new(B, 9, L - 7.5), 0, 7.1, 3.5, kofferFarbe, nil, nil, nil, true)
		local firma = FIRMEN[((firmaIndex or 1) - 1) % #FIRMEN + 1]
		for _, seite in { Enum.NormalId.Left, Enum.NormalId.Right } do
			local g = Instance.new("SurfaceGui")
			g.Face = seite
			g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			g.PixelsPerStud = 20
			g.Parent = koffer
			local l = Instance.new("TextLabel")
			l.Size = UDim2.fromScale(1, 0.4)
			l.Position = UDim2.fromScale(0, 0.3)
			l.BackgroundTransparency = 1
			l.Text = firma
			l.Font = Enum.Font.GothamBlack
			l.TextScaled = true
			l.TextColor3 = farbe:Lerp(Color3.new(0, 0, 0), 0.2)
			l.Parent = g
		end
		for _, s in { -1, 1 } do
			rad(s * (B / 2 - 0.5), -L / 2 + 3.4, 1.7)
			rad(s * (B / 2 - 0.5), L / 2 - 6.0, 1.7)
			rad(s * (B / 2 - 0.5), L / 2 - 2.4, 1.7)
			teil("Spiegel", Vector3.new(0.3, 1.6, 0.8), s * (B / 2 + 0.6), 7.0, -L / 2 + 1.0, schwarz)
		end
		lichter(B, 3.2, -L / 2 + 0.2, L / 2 - 0.25, 1.6)
	end
	return m
end

-- ---------------------------------------------------------------
-- SERVER: simulation (positions only, no models)
-- ---------------------------------------------------------------
function Verkehr.starten(optionen)
	optionen = optionen or {}
	local karte = workspace:WaitForChild("Karte")
	local ampeln = karte:WaitForChild("Ampeln")
	local stopps = karte:FindFirstChild("Stoppschilder")
	local Regeln = optionen.regeln
	local zufall = Random.new()

	local fahrzeuge = {}
	for r, knoten in ROUTEN do
		local spur = Verkehr.spur(knoten)
		local menge = ANZAHL[r] or 2
		local stadt = r >= 5
		for i = 1, menge do
			-- weighted random vehicle type
			local wurf, summe, art = zufall:NextNumber(), 0, "limousine"
			local gesamt = 0
			for _, a in ART_LISTE do gesamt += stadt and ARTEN[a].stadt or ARTEN[a].land end
			for _, a in ART_LISTE do
				summe += (stadt and ARTEN[a].stadt or ARTEN[a].land) / gesamt
				if wurf <= summe then art = a break end
			end
			if Verkehr.POLIZEI and i == 1 and (r == 1 or r == 4) then art = "polizei" end -- two patrol cars (v52: off)
			local f = {
				nr = #fahrzeuge + 1, route = r, spur = spur, art = art,
				farbe = zufall:NextInteger(1, #FARBEN), firma = zufall:NextInteger(1, #FIRMEN),
				s = 0, v = 0,
				laenge = ARTEN[art].laenge, breite = ARTEN[art].breite, max = ARTEN[art].max,
				gehaltenAn = {}, stehtSeit = nil, blockiertSeit = nil, geistBis = 0,
				kontrolle = {}, -- [checkpoint id] = "ja" / "nein" / "fertig"
			}
			-- start position: spread along the route, never on top of another vehicle
			for versuch = 1, 30 do
				f.s = (spur.gesamt * (i - 1) / menge + r * 157 + zufall:NextNumber(0, 40) + (versuch - 1) * 37) % spur.gesamt
				f.pos, f.dir = Verkehr.ort(spur, f.s)
				local frei = true
				for _, o in fahrzeuge do
					if (o.pos - f.pos).Magnitude < (o.laenge + f.laenge) / 2 + 12 then frei = false break end
				end
				if frei and not (Regeln and Regeln.imKreisel(f.pos, 60)) then break end
			end
			table.insert(fahrzeuge, f)
		end
	end
	Verkehr.fahrzeuge = fahrzeuge

	-- list for the players' computers (what to draw)
	function Verkehr.liste()
		local l = {}
		for _, f in fahrzeuge do
			table.insert(l, { f.route, f.art, f.farbe, f.firma, f.s })
		end
		return l
	end

	-- obstacles: other NPC vehicles, player cars, characters and pedestrians
	local function hindernisse()
		local liste = {}
		for _, f in fahrzeuge do
			table.insert(liste, { eigen = f, halb = f.laenge / 2, breite = f.breite })
		end
		for _, p in Players:GetPlayers() do
			local char = p.Character
			local wurzel = char and char:FindFirstChild("HumanoidRootPart")
			if wurzel then
				local hum = char:FindFirstChildOfClass("Humanoid")
				local sitz = hum and hum.SeatPart
				local auto = sitz and sitz.Parent and sitz.Parent:FindFirstChild("Chassis")
				local halb = auto and (sitz.Parent:GetAttribute("Laenge") or 17) / 2 or 1.5
				table.insert(liste, { pos = flach((auto or wurzel).Position), halb = halb, breite = auto and 8 or 2.5 })
			end
		end
		-- parked lesson cars and job trucks nobody sits in
		for _, m in (optionen.fahrzeuge and optionen.fahrzeuge() or {}) do
			local c = m:FindFirstChild("Chassis")
			if c then table.insert(liste, { pos = flach(c.Position), halb = (m:GetAttribute("Laenge") or 17) / 2, breite = 8 }) end
		end
		for _, extra in (optionen.weitere and optionen.weitere() or {}) do
			table.insert(liste, extra)
		end
		return liste
	end

	-- points along each vehicle's own lane ahead (also works in curves and roundabouts)
	-- how far a vehicle looks ahead: more at higher speed (it needs room to brake)
	local function reichweite(f)
		return 35 + f.v * f.v / 40
	end
	-- the highest speed from which the vehicle can still stop within "abstand"
	local function bremsTempo(abstand)
		return math.sqrt(2 * 22 * math.max(0, abstand))
	end
	local function probenBerechnen(f)
		f.probePos = f.probePos or {}
		f.probeD = f.probeD or {}
		f.weit = reichweite(f)
		local i = 0
		local start = f.laenge / 2 - 2
		for d = start, start + f.weit, 4.5 do
			i += 1
			f.probePos[i] = Verkehr.ort(f.spur, f.s + d)
			f.probeD[i] = d
		end
		f.probenAnzahl = i
	end

	-- distance along f's lane to position p (nil = not in f's way)
	local function aufPfad(f, p, radius)
		if (p - f.pos).Magnitude > f.weit + f.laenge then return nil end
		for k = 1, f.probenAnzahl do
			if (p - f.probePos[k]).Magnitude < radius then return f.probeD[k] end
		end
		return nil
	end

	local function haltBei(f, liste)
		-- returns the free distance ahead (math.huge = free) and whether an NPC vehicle blocks
		local frei, durchNpc = math.huge, false
		local geist = os.clock() < f.geistBis
		for _, h in liste do
			local o = h.eigen
			if o ~= f and not (o and geist and o.spur ~= f.spur) then
				if o and o.spur == f.spur then
					-- same route: exact distance along the lane
					local ds = (o.s - f.s) % f.spur.gesamt
					if ds < f.weit + f.laenge then
						local luecke = ds - f.laenge / 2 - o.laenge / 2
						if luecke < frei then frei, durchNpc = luecke, true end
					end
				else
					local hp = o and o.pos or h.pos
					local radius = f.breite / 2 + (h.breite or 2) / 2 + 0.8
					local d = aufPfad(f, hp, radius)
					if d then
						local luecke = d - f.laenge / 2 - (o and o.laenge / 2 or h.halb or 2)
						local warten = true
						if o and f.nr < o.nr and (luecke > 6 or (f.v < 0.5 and o.v < 0.5)) and aufPfad(o, f.pos, radius) then
							warten = false -- both want the same spot: the lower number goes first
						end
						if warten and luecke < frei then frei, durchNpc = luecke, o ~= nil end
					end
				end
			end
		end
		return frei, durchNpc
	end

	-- roundabout centres (from the routes)
	local kreisel = {}
	for _, knoten in ROUTEN do
		for _, k in knoten do
			if k.k then
				local c = Vector3.new(k.x, 0, k.z)
				local neu = true
				for _, vorhanden in kreisel do
					if (vorhanden - c).Magnitude < 1 then neu = false end
				end
				if neu then table.insert(kreisel, c) end
			end
		end
	end

	-- give way when entering a roundabout: wait at the line while someone drives past inside
	local function kreiselWarten(f)
		for _, c in kreisel do
			local zuMitte = c - f.pos
			local d = zuMitte.Magnitude
			local front = d - f.laenge / 2 -- distance of the front bumper from the centre
			if front > RING + 7 and front < RING + 40 and zuMitte.Unit:Dot(f.dir) > 0.6 then
				local einfahrt = c - zuMitte.Unit * RING
				for _, o in fahrzeuge do
					if o ~= f and (o.pos - c).Magnitude < RING + 6 and (o.pos - einfahrt).Magnitude < 26 + o.laenge / 2 then
						return front - (RING + 10) -- distance to the give-way line
					end
				end
			end
		end
		return nil
	end

	-- speed limit for curves ahead (brake early enough)
	local function kurvenTempo(f)
		local _, d1 = Verkehr.ort(f.spur, f.s + 6)
		local _, d2 = Verkehr.ort(f.spur, f.s + 22)
		if d1:Dot(d2) < math.cos(math.rad(25)) then return 18 end
		local _, d3 = Verkehr.ort(f.spur, f.s + 50)
		if d1:Dot(d3) < math.cos(math.rad(35)) then return 32 end
		return math.huge
	end
	-- junctions without signs: right before left
	local rvl = {}
	local rvlOrdner = karte:FindFirstChild("RechtsVorLinks")
	if rvlOrdner then
		for _, k in rvlOrdner:GetChildren() do
			table.insert(rvl, Vector3.new(k.Position.X, 0, k.Position.Z))
		end
	end
	local function rvlTempo(f)
		for _, c in rvl do
			local rel = c - f.pos
			local vor = rel:Dot(f.dir) - f.laenge / 2 -- distance of the front bumper to the junction centre
			if vor > -4 and vor < 40 and math.abs(rel:Dot(rechtsVon(f.dir))) < 9 then
				local grenze = 16 + math.max(0, vor - 12) * 0.8 -- approach slowly
				-- someone coming from the right? then wait before the junction
				local rechts = rechtsVon(f.dir)
				for _, o in fahrzeuge do
					if o ~= f then
						local orel = o.pos - c
						local zuMitte = -orel
						if orel:Dot(rechts) > 4 and orel.Magnitude < 32 and math.abs(o.dir:Dot(f.dir)) < 0.4
							and zuMitte.Magnitude > 0.1 and zuMitte.Unit:Dot(o.dir) > 0.5 then
							grenze = math.min(grenze, bremsTempo(vor - 10))
						end
					end
				end
				return grenze
			end
		end
		return math.huge
	end

	-- police checkpoint: some vehicles are waved over and stopped for a moment
	local function kontrolleTempo(f)
		local k = optionen.kontrolle and optionen.kontrolle()
		if not k or f.art == "polizei" then return math.huge end
		if k.dir:Dot(f.dir) < 0.8 then return math.huge end
		local rel = k.pos - f.pos
		if math.abs(rel:Dot(rechtsVon(f.dir))) > 4 then return math.huge end
		local vor = rel:Dot(f.dir) - f.laenge / 2
		if vor < -3 or vor > f.weit then return math.huge end
		local zustand = f.kontrolle[k.id]
		if zustand == nil then
			zustand = (math.random() < (f.art == "lkw" and 0.6 or 0.35)) and "ja" or "nein"
			f.kontrolle[k.id] = zustand
		end
		if zustand == "ja" then
			if f.v < 0.5 and vor < 4 then
				f.kontrolleSeit = f.kontrolleSeit or os.clock()
				if os.clock() - f.kontrolleSeit > 8 then
					f.kontrolle[k.id] = "fertig"
					f.kontrolleSeit = nil
				end
			end
			return bremsTempo(vor - 1)
		end
		return 25 -- slow down while passing the police
	end

	local function kreiselTempo(f)
		local grenze = math.huge
		for _, c in kreisel do
			local d = (c - f.pos).Magnitude
			if d < 120 then grenze = math.min(grenze, 18 + math.max(0, d - 34) * 0.7) end
		end
		return grenze
	end

	-- traffic lights and signs never move: read their positions once (saves thousands of
	-- attribute reads per second on the server); only the light phase is read every step
	local ampelDaten, schildDaten = {}, {}
	local function zeichenLesen()
		ampelDaten, schildDaten = {}, {}
		for _, ampel in ampeln:GetChildren() do
			local L, d = ampel:GetAttribute("Haltelinie"), ampel:GetAttribute("Anfahrt")
			if L and d then table.insert(ampelDaten, { inst = ampel, L = L, d = d }) end
		end
		if stopps then
			for _, schild in stopps:GetChildren() do
				local L, d = schild:GetAttribute("Haltelinie"), schild:GetAttribute("Anfahrt")
				if L and d then
					table.insert(schildDaten, { inst = schild, L = L, d = d, gewaehren = schild:GetAttribute("Typ") == "Vorfahrt gewaehren" })
				end
			end
		end
	end
	zeichenLesen()
	ampeln.ChildAdded:Connect(function() task.defer(zeichenLesen) end)

	local takt = 0
	local liste = {}
	local function schritt(dt)
		dt = math.min(dt, 0.1)
		takt += dt
		if takt > 0.2 then
			takt = 0
			liste = hindernisse()
		end
		for _, a in ampelDaten do
			a.phase = a.inst:GetAttribute("Phase")
		end
		for _, f in fahrzeuge do
			probenBerechnen(f)
		end
		for _, f in fahrzeuge do
			local limit = Regeln and Regeln.tempolimit(f.pos) or 50
			local ziel = math.min(limit * 0.8, f.max)
			ziel = math.min(ziel, kurvenTempo(f), kreiselTempo(f))

			ziel = math.min(ziel, rvlTempo(f), kontrolleTempo(f))

			-- roundabout: give way to traffic inside
			local wartelinie = kreiselWarten(f)
			if wartelinie then
				ziel = math.min(ziel, bremsTempo(wartelinie))
			end

			-- keep distance
			local frei, durchNpc = haltBei(f, liste)
			if frei < math.huge then
				ziel = math.min(ziel, bremsTempo(frei - 5))
			end
			-- safety net: stuck behind other NPC vehicles for a long time -> squeeze through
			if durchNpc and f.v < 0.5 then
				f.blockiertSeit = f.blockiertSeit or os.clock()
				if os.clock() - f.blockiertSeit > 25 then
					f.geistBis = os.clock() + 3
					f.blockiertSeit = nil
				end
			else
				f.blockiertSeit = nil
			end

			-- traffic lights: stop before the line when it is not green
			for _, a in ampelDaten do
				local L, d = a.L, a.d
				if a.phase ~= "Gruen" and d:Dot(f.dir) < -0.7 then
					local rel = L - f.pos
					local vor = rel:Dot(f.dir) - f.laenge / 2
					if vor > -1 and vor < f.weit and math.abs(rel:Dot(rechtsVon(f.dir))) < 5 then
						-- yellow and already very close: drive on
						if not (a.phase == "Gelb" and vor < f.v * f.v / 60) then
							ziel = math.min(ziel, bremsTempo(vor - 1.5))
						end
					end
				end
			end
			-- STOP signs: stand still for a moment, then go
			do
				for _, sd in schildDaten do
					local schild, L, d = sd.inst, sd.L, sd.d
					if d:Dot(f.dir) < -0.7 and not f.gehaltenAn[schild] then
						local rel = L - f.pos
						local vor = rel:Dot(f.dir) - f.laenge / 2
						local vorfahrtGewaehren = sd.gewaehren
						if vorfahrtGewaehren and vor > -1 and vor < f.weit and math.abs(rel:Dot(rechtsVon(f.dir))) < 5 then
							ziel = math.min(ziel, math.sqrt(12 * 12 + 44 * math.max(0, vor - 1))) -- slow down, no full stop
						elseif vor > -1 and vor < f.weit and math.abs(rel:Dot(rechtsVon(f.dir))) < 5 then
							ziel = math.min(ziel, bremsTempo(vor - 1))
							if f.v < 0.5 and vor < 3 then
								f.stehtSeit = f.stehtSeit or os.clock()
								if os.clock() - f.stehtSeit > 1.5 then
									f.gehaltenAn[schild] = true
									f.stehtSeit = nil
									task.delay(10, function() f.gehaltenAn[schild] = nil end)
								end
							end
						end
					end
				end
			end

			-- accelerate gently, brake firmly
			local dv = ziel - f.v
			f.v = math.max(0, f.v + math.clamp(dv, -40 * dt, 9 * dt))
			f.s = (f.s + f.v * dt) % f.spur.gesamt
			local pos = Verkehr.ort(f.spur, f.s)
			local _, blick = Verkehr.ort(f.spur, f.s + 3)
			f.pos, f.dir = pos, blick
		end
	end
	Verkehr.schritt = schritt

	-- send the positions to all players 10 times per second
	-- (the simulation runs 20 times per second, that is plenty and saves server time)
	local sendeTakt, simTakt = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		simTakt += dt
		if simTakt >= 0.05 then
			schritt(simTakt)
			simTakt = 0
		end
		sendeTakt += dt
		if optionen.event and sendeTakt >= 0.1 then
			sendeTakt = 0
			local daten = table.create(#fahrzeuge * 2)
			for _, f in fahrzeuge do
				table.insert(daten, math.floor(f.s * 10 + 0.5) / 10)
				table.insert(daten, math.floor(f.v * 10 + 0.5) / 10)
			end
			optionen.event:FireAllClients(daten)
		end
	end)
	return fahrzeuge
end

-- ---------------------------------------------------------------
-- CLIENT: draws the vehicles and moves them smoothly between the server updates
-- ---------------------------------------------------------------
-- flashing blue / red lights of police cars (an = switched on)
function Verkehr.blaulichtZeigen(teile, an)
	local takt = math.floor(os.clock() * 6) % 2 == 0
	for _, t in teile do
		local blau = t:GetAttribute("Farbe") == "blau"
		local leuchtet = an and (blau == takt)
		if blau then
			t.Color = leuchtet and Color3.fromRGB(60, 120, 255) or Color3.fromRGB(20, 40, 120)
		else
			t.Color = leuchtet and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(120, 20, 20)
		end
		t.Material = leuchtet and Enum.Material.Neon or Enum.Material.SmoothPlastic
	end
end

function Verkehr.anzeigen(liste, event)
	local ordner = Instance.new("Folder")
	ordner.Name = "NPC_Verkehr"
	ordner.Parent = workspace
	local spuren = {}
	local autos = {}
	for i, e in liste do
		local route, art, farbe, firma, s = e[1], e[2], e[3], e[4], e[5]
		spuren[route] = spuren[route] or Verkehr.spur(ROUTEN[route])
		local m = Verkehr.modell(art, farbe, firma)
		m.Parent = ordner
		local lichter, blaulicht = {}, {}
		for _, t in m:GetChildren() do
			if t.Name == "Ruecklicht" then table.insert(lichter, t) end
			if t.Name == "Blaulicht" then table.insert(blaulicht, t) end
		end
		autos[i] = { modell = m, spur = spuren[route], s = s, v = 0, fehl = 0, lichter = lichter, bremst = false, blaulicht = blaulicht, nr = i }
	end
	event.OnClientEvent:Connect(function(daten)
		for i, a in autos do
			local s, v = daten[i * 2 - 1], daten[i * 2]
			if s then
				local g = a.spur.gesamt
				local diff = (s - a.s + g / 2) % g - g / 2
				if math.abs(diff) > 40 then
					a.s, a.fehl = s, 0 -- too far off: jump
				else
					a.fehl = diff
				end
				local bremst = v < a.v - 0.3 or v < 0.5
				if bremst ~= a.bremst then
					a.bremst = bremst
					for _, l in a.lichter do
						l.Color = bremst and Color3.fromRGB(255, 30, 30) or Color3.fromRGB(170, 15, 15)
					end
				end
				a.v = v
			end
		end
	end)
	local hoch = Vector3.new(0, 0.2, 0)
	local bild = 0
	RunService.RenderStepped:Connect(function(dt)
		dt = math.min(dt, 0.1)
		bild += 1
		local kam = workspace.CurrentCamera
		local auge = kam and kam.CFrame and kam.CFrame.Position or Vector3.zero
		for _, a in autos do
			local korrektur = a.fehl * math.min(1, dt * 4)
			a.fehl -= korrektur
			a.s = (a.s + a.v * dt + korrektur) % a.spur.gesamt
			local pos = Verkehr.ort(a.spur, a.s)
			-- far away vehicles are moved less often (saves a lot on phones and weak PCs, nobody sees it)
			local weit = Vector3.new(pos.X - auge.X, 0, pos.Z - auge.Z).Magnitude
			local takt = weit > 500 and 8 or (weit > 220 and 3 or 1)
			if Verkehr.sparmodus and weit > 120 then takt *= 2 end
			if takt == 1 or (bild + a.nr) % takt == 0 then
				local _, blick = Verkehr.ort(a.spur, a.s + 3)
				a.modell:PivotTo(CFrame.lookAt(pos + hoch, pos + hoch + blick))
				if #a.blaulicht > 0 then
					Verkehr.blaulichtZeigen(a.blaulicht, event.Parent:GetAttribute("Blaulicht_" .. a.nr) == true)
				end
			end
		end
	end)
	return autos
end

return Verkehr
