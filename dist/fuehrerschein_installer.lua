-- =====================================================================
--  DRIVER'S LICENSE SYSTEM v29
--  (receptionist, theory test, 5 driving lessons, driving test, truck license,
--   truck jobs with levels, pizza job, villas, car dealership, police, speed cameras + penalty points, day/night + weather, XP, Drive Coins, NPC traffic)
--  Run once in the command bar (no test may be running).
--  The map from stadt_generator.lua must exist first.
--  Running it again replaces the old version.
-- =====================================================================
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local SPS = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")

for _, alt in { RS:FindFirstChild("Fuehrerschein"), SSS:FindFirstChild("FuehrerscheinServer"), SPS:FindFirstChild("FuehrerscheinClient") } do
	if alt then alt:Destroy() end
end

local function neu(klasse, name, eltern, quelle)
	local o = Instance.new(klasse)
	o.Name = name
	if quelle then o.Source = quelle end
	o.Parent = eltern
	return o
end

local ordner = neu("Folder", "Fuehrerschein", RS)
neu("RemoteFunction", "Aktion", ordner)
neu("RemoteEvent", "Oeffnen", ordner)
neu("RemoteEvent", "Fahrstunde", ordner)
neu("RemoteEvent", "Blinker", ordner)
neu("RemoteEvent", "VerkehrDaten", ordner)
neu("ModuleScript", "Verkehrsregeln", ordner, [=====[
-- Shared traffic rules (used by server and client): speed limit zones, roundabouts and route gates.
local Regeln = {}

Regeln.HZ = -520 -- highway
Regeln.KREISEL = {
	Vector3.new(0, 0, 600), Vector3.new(-780, 0, 0), Vector3.new(-780, 0, 600), Vector3.new(780, 0, 600),
}

-- residential streets outside the city (same list as in the map generator): 30 km/h
Regeln.WOHNSTRASSEN = {
	{ -324, -208, -720, -208 }, { -720, -208, -720, -460 }, { -720, -460, 780, -460 },
	{ 208, -324, 208, -460 }, { -208, -324, -208, -460 }, { 324, -208, 412, -208 },
	{ -324, 208, -720, 208 }, { -720, 208, -720, 460 }, { -720, 460, -60, 460 },
	{ -208, 324, -208, 460 }, { 208, 324, 208, 460 }, { 60, 460, 400, 460 },
	{ -324, -104, -720, -104 }, { -720, -104, -720, -208 }, { -324, 104, -720, 104 }, { -720, 104, -720, 208 },
	{ 324, -104, 412, -104 },
	{ -720, -333, -208, -333 }, { -720, 333, -208, 333 }, { 208, -333, 780, -333 }, { 208, 333, 400, 333 },
	{ 0, -540, 0, -700 }, { -720, -700, 720, -700 }, { -400, -700, -400, -580 }, { 400, -700, 400, -580 },
}
local function inWohnstrasse(x, z)
	for _, w in Regeln.WOHNSTRASSEN do
		local x1, x2 = math.min(w[1], w[3]) - 11, math.max(w[1], w[3]) + 11
		local z1, z2 = math.min(w[2], w[4]) - 11, math.max(w[2], w[4]) + 11
		if x >= x1 and x <= x2 and z >= z1 and z <= z2 then return true end
	end
	return false
end

-- pizzeria parking lot (manoeuvring, no turn-signal check)
function Regeln.imPizzeria(pos)
	return pos.X > 345 and pos.X < 405 and pos.Z > 8 and pos.Z < 90
end

-- construction sites: lower speed limit
Regeln.BAUSTELLEN = {
	{ x1 = -800, x2 = -760, z1 = 335, z2 = 465, limit = 30, name = "Construction site" },
	{ x1 = 120, x2 = 330, z1 = -545, z2 = -495, limit = 80, name = "Construction site" },
}

function Regeln.tempolimit(pos)
	local x, z = pos.X, pos.Z
	for _, b in Regeln.BAUSTELLEN do
		if x >= b.x1 and x <= b.x2 and z >= b.z1 and z <= b.z2 then
			return b.limit, b.name
		end
	end
	if math.abs(x) <= 330 and math.abs(z) <= 330 then
		return 50, "City"
	end
	if math.abs(z - Regeln.HZ) <= 24 then
		return 130, "Highway"
	end
	if x >= 405 and x <= 765 and math.abs(z) <= 290 and math.abs(z) > 12 then
		return 30, "Residential area"
	end
	if inWohnstrasse(x, z) and math.abs(z) > 11 then
		return 30, "Residential area"
	end
	return 100, "Country road"
end

-- truck depot yard and its driveway (manoeuvring, no turn-signal check)
function Regeln.imDepot(pos)
	return pos.X > 462 and pos.X < 738 and pos.Z > 292 and pos.Z < 445
end

function Regeln.imKreisel(pos, radius)
	for _, k in Regeln.KREISEL do
		if (Vector3.new(pos.X, 0, pos.Z) - k).Magnitude < (radius or 75) then return true end
	end
	return false
end

local function rechtsVon(d)
	return Vector3.new(-d.Z, 0, d.X)
end

-- Has the car reached / driven through the gate?
function Regeln.durchTor(pos, torPos, dir, breite, radius)
	local rel = Vector3.new(pos.X - torPos.X, 0, pos.Z - torPos.Z)
	if rel.Magnitude < radius then return true end
	return math.abs(rel:Dot(dir)) < 6 and math.abs(rel:Dot(rechtsVon(dir))) < breite / 2 + 5
end

-- Where the green gate for waypoint i stands: after a turn it is on the new road in the
-- right lane, on a straight it is across the right lane. Returns position, direction, width, radius.
function Regeln.tor(punkte, i, startPos)
	local wp = punkte[i]
	local p = Vector3.new(wp.x, 0, wp.z)
	local vorher = punkte[i - 1]
	local von = vorher and Vector3.new(vorher.x, 0, vorher.z) or (startPos and Vector3.new(startPos.X, 0, startPos.Z)) or (p + Vector3.new(0, 0, 10))
	local rein = p - von
	rein = rein.Magnitude > 0.5 and rein.Unit or Vector3.new(0, 0, -1)
	local danach = punkte[i + 1]
	if wp.parken or wp.stopp then
		return p, rein, wp.breite or 26, wp.r or 16
	end
	if wp.breite then -- points that already lie in a lane (highway)
		return p, rein, wp.breite, wp.r or 16
	end
	if wp.r and wp.r <= 12 then -- points on the ring of a roundabout
		local raus = danach and (Vector3.new(danach.x, 0, danach.z) - p) or rein
		raus = raus.Magnitude > 0.5 and raus.Unit or rein
		return p, raus, 14, wp.r
	end
	if danach and not (danach.r and danach.r <= 12) then
		local raus = Vector3.new(danach.x, 0, danach.z) - p
		raus = raus.Magnitude > 0.5 and raus.Unit or rein
		if rein:Dot(raus) < math.cos(math.rad(30)) then
			-- a turn: the gate stands on the new road, in the right lane
			local vor = (wp.r and wp.r >= 18) and 32 or 18      -- wide junctions (highway) need more room
			if danach.breite then
				return p + raus * vor + rechtsVon(raus) * 10, raus, 20, 12 -- onto the highway: right lane
			end
			return p + raus * vor + rechtsVon(raus) * 5.5, raus, 14, 11
		end
	end
	return p + rechtsVon(rein) * 5.5, rein, 14, wp.r or 13
end

return Regeln
]=====])
neu("ModuleScript", "Verkehr", ordner, [=====[
-- NPC traffic: cars, SUVs, vans and trucks driving on lanes through the map.
-- The SERVER decides where every vehicle is (it keeps right, follows curves and roundabouts,
-- stops at red lights and STOP signs, keeps its distance and brakes for pedestrians and players).
-- Every PLAYER draws the vehicles on their own computer, so they move perfectly smoothly.
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Verkehr = {}

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

-- Builds a vehicle model (all parts anchored; it is moved as a whole). Front = -Z.
function Verkehr.modell(art, farbIndex, firmaIndex)
	local farbe = FARBEN[(farbIndex - 1) % #FARBEN + 1]
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
			if i == 1 and (r == 1 or r == 4) then art = "polizei" end -- two patrol cars
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

	local takt = 0
	local liste = {}
	local function schritt(dt)
		dt = math.min(dt, 0.1)
		takt += dt
		if takt > 0.2 then
			takt = 0
			liste = hindernisse()
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
			for _, ampel in ampeln:GetChildren() do
				local L = ampel:GetAttribute("Haltelinie")
				local d = ampel:GetAttribute("Anfahrt")
				if L and d and ampel:GetAttribute("Phase") ~= "Gruen" and d:Dot(f.dir) < -0.7 then
					local rel = L - f.pos
					local vor = rel:Dot(f.dir) - f.laenge / 2
					if vor > -1 and vor < f.weit and math.abs(rel:Dot(rechtsVon(f.dir))) < 5 then
						-- yellow and already very close: drive on
						if not (ampel:GetAttribute("Phase") == "Gelb" and vor < f.v * f.v / 60) then
							ziel = math.min(ziel, bremsTempo(vor - 1.5))
						end
					end
				end
			end
			-- STOP signs: stand still for a moment, then go
			if stopps then
				for _, schild in stopps:GetChildren() do
					local L = schild:GetAttribute("Haltelinie")
					local d = schild:GetAttribute("Anfahrt")
					if L and d and d:Dot(f.dir) < -0.7 and not f.gehaltenAn[schild] then
						local rel = L - f.pos
						local vor = rel:Dot(f.dir) - f.laenge / 2
						local vorfahrtGewaehren = schild:GetAttribute("Typ") == "Vorfahrt gewaehren"
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
]=====])

local server = Instance.new("Script")
server.Name = "FuehrerscheinServer"
server.Source = [=====[
-- Driver's license system (server): saving, receptionist, theory test, driving lessons,
-- practical driving test, pedestrians and the driver's license item.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ordner = RS:WaitForChild("Fuehrerschein")
local aktion = ordner:WaitForChild("Aktion")
local oeffnen = ordner:WaitForChild("Oeffnen")
local fahrEvent = ordner:WaitForChild("Fahrstunde")
local Regeln = require(ordner:WaitForChild("Verkehrsregeln"))
local FRAGEN = require(script:WaitForChild("Fragen"))
local Auto = require(script:WaitForChild("Auto"))
local LEKTIONEN = require(script:WaitForChild("Fahrstunden"))
local Strafen = require(script:WaitForChild("Strafen"))
local Umwelt = require(script:WaitForChild("Umwelt"))
local Pflege = require(script:WaitForChild("Fahrzeugpflege"))
local Missionen = require(script:WaitForChild("Missionen"))
local Shop = require(script:WaitForChild("Shop"))
local Belohnungen = require(script:WaitForChild("Belohnungen"))
local Verkehr = require(ordner:WaitForChild("Verkehr"))
local verkehrEvent = ordner:WaitForChild("VerkehrDaten")

local ANZAHL_FRAGEN = 20
local MINDEST_QUOTE = 0.85   -- 85 % = 17 of 20
local WARTEZEIT = 30         -- seconds before a new attempt
local AUTOFARBEN = { Color3.fromRGB(110, 20, 30), Color3.fromRGB(235, 235, 235), Color3.fromRGB(170, 175, 180), Color3.fromRGB(30, 50, 95) }

-- ---------------------------------------------------------------
-- Saving
-- ---------------------------------------------------------------
local store
local okStore, storeFehler = pcall(function()
	store = DataStoreService:GetDataStore("Fuehrerschein_v1")
end)
if not okStore then
	warn("License system: saving not available (" .. tostring(storeFehler) .. ")")
end

local daten = {}        -- [player] = progress
local pruefungen = {}   -- [player] = correct answers of the running test
local sperre = {}       -- [player] = time when a new attempt is allowed
local sitzend = {}      -- [player] = exam seat the player sits on
local lektionen = {}    -- [player] = running driving lesson

local function standard()
	return {
		angemeldet = false, unterricht = false, theorie = false, fahrstunden = 0, fuehrerschein = false,
		fuehrerscheinDatum = "", fuehrerscheinNr = "", einstellungen = {},
		geld = 100, lkwFuehrerschein = false, lkwDatum = "", lieferungen = 0,
		lkwFahrten = 0, pizzaFahrten = 0, villen = {}, autos = {},
		punkte = 0, historie = {}, entzogen = false, nachschulung = false, lkwGesperrt = false, punkteZeit = 0,
		xp = 0, autoKm = {}, autoDaten = {}, kmGesamt = 0, perfekt = 0,
		-- shop and rewards (v24)
		passes = {}, kaeufe = {}, boostBis = 0, starterGekauft = false, login = { letzte = "", serie = 0, beste = 0 },
		erfolge = {}, erfolgGemeldet = {}, taxiFahrten = 0, freundeSek = 0, gruppeGeschenk = false,
	}
end

local function laden(p)
	local d
	if store then
		local ok, ergebnis = pcall(function()
			return store:GetAsync("spieler_" .. p.UserId)
		end)
		if ok and type(ergebnis) == "table" then
			d = ergebnis
		elseif not ok then
			warn("License system: loading failed: " .. tostring(ergebnis))
		end
	end
	d = d or standard()
	for k, v in standard() do
		if d[k] == nil then d[k] = v end
	end
	return d
end

local function speichern(p)
	local d = daten[p]
	if not d or not store then return false end
	local ok, e = pcall(function()
		store:SetAsync("spieler_" .. p.UserId, d)
	end)
	if not ok then
		warn("License system: saving failed: " .. tostring(e))
	end
	return ok
end

local function anzeigen(p)
	local d = daten[p]
	if not d then return end
	p:SetAttribute("Fuehrerschein", d.fuehrerschein)
	p:SetAttribute("TheorieBestanden", d.theorie)
	p:SetAttribute("Fahrstunden", d.fahrstunden)
	p:SetAttribute("Geld", d.geld)
	p:SetAttribute("LkwFuehrerschein", d.lkwFuehrerschein)
	local ls = p:FindFirstChild("leaderstats")
	if not ls then
		ls = Instance.new("Folder")
		ls.Name = "leaderstats"
		ls.Parent = p
	end
	local wert = ls:FindFirstChild("License")
	if not wert then
		wert = Instance.new("StringValue")
		wert.Name = "License"
		wert.Parent = ls
	end
	local level = ls:FindFirstChild("Level")
	if not level then
		level = Instance.new("IntValue")
		level.Name = "Level"
		level.Parent = ls
	end
	level.Value = math.floor(math.sqrt((d.xp or 0) / 150)) + 1
	p:SetAttribute("XP", d.xp or 0)
	p:SetAttribute("Level", level.Value)
	p:SetAttribute("Punkte", d.punkte or 0)
	if d.fuehrerschein then
		wert.Value = "Yes"
	elseif d.entzogen then
		wert.Value = "Withdrawn"
	elseif d.fahrstunden > 0 then
		wert.Value = ("Lessons %d/%d"):format(d.fahrstunden, #LEKTIONEN)
	elseif d.theorie then
		wert.Value = "Theory ✓"
	else
		wert.Value = "No"
	end
end

local function geaendert(p)
	anzeigen(p)
	task.spawn(speichern, p)
end

-- XP and level: level = floor(sqrt(xp / 150)) + 1  (level 2 at 150 XP, level 5 at 2400 XP, ...)
local function levelVon(xp) return math.floor(math.sqrt(xp / 150)) + 1 end
local function xpGeben(p, menge, grund, ohneBonus)
	local d = daten[p]
	if not d or menge <= 0 then return end
	if not ohneBonus then menge = math.floor(menge * Shop.faktor(p, "xp") + 0.5) end -- 2x XP pass, Premium, friends
	local vorher = levelVon(d.xp or 0)
	d.xp = (d.xp or 0) + menge
	local nachher = levelVon(d.xp)
	anzeigen(p)
	task.spawn(speichern, p)
	fahrEvent:FireClient(p, { typ = "xp", menge = menge, grund = grund, level = nachher, aufstieg = nachher > vorher })
end

-- Money ("Drive Coins"): shown top right on the player's screen
local function geldGeben(p, betrag, grund, ohneBonus)
	local d = daten[p]
	if not d or betrag == 0 then return end
	-- earned coins get the bonus (VIP, 2x boost, Premium, friends); purchases and admin money don't
	if betrag > 0 and not ohneBonus then betrag = math.floor(betrag * Shop.faktor(p, "geld") + 0.5) end
	d.geld = math.max(0, d.geld + betrag)
	geaendert(p)
	fahrEvent:FireClient(p, { typ = "geld", betrag = betrag, grund = grund })
end

local fuehrerscheinGeben -- defined further down
-- Admin = the owner of the game (or anyone in Roblox Studio). Extra people: put their UserId here.
local ADMIN_IDS = {}
local function istAdmin(p)
	if RunService:IsStudio() then return true end
	if table.find(ADMIN_IDS, p.UserId) then return true end
	return game.CreatorType == Enum.CreatorType.User and p.UserId == game.CreatorId
end

local function spielerDa(p)
	p:SetAttribute("Admin", istAdmin(p) or nil)
	daten[p] = laden(p)
	anzeigen(p)
	if fuehrerscheinGeben then task.spawn(fuehrerscheinGeben, p) end
end
Players.PlayerAdded:Connect(spielerDa)
for _, p in Players:GetPlayers() do
	task.spawn(spielerDa, p)
end

-- ---------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------
local function mischen(t)
	for i = #t, 2, -1 do
		local j = math.random(1, i)
		t[i], t[j] = t[j], t[i]
	end
	return t
end

-- NPC looks: free items from the Roblox catalog (made by Roblox), so nobody walks around "naked".
-- Faces are Roblox's free dynamic heads; the mood animation gives them a friendly expression.
local NPC_LOOK = {
	shirts = { 607785314, 398633584, 144076358, 398635081, 398634295, 4047886060, 4047884046, 144076436, 382537702, 382537085, 382538295 },
	pants = { 398633812, 398635338, 398634487, 144076760, 382538503, 382537569, 382537950 },
	haareFrau = { 7193448258, 9244097555, 9244111257, 7193442167, 9174354743, 6993754725, 376526888, 9244148336 },
	haareMann = { 9243992729, 9244021842, 7193386173, 63690008, 3814474927, 376524487 },
	koepfeFrau = { { kopf = 10725626210, mood = 13692973305 } },
	koepfeMann = {
		{ kopf = 10725826963, mood = 10725833199 },
		{ kopf = 10723855306, mood = 10723858600 },
		{ kopf = 10687288296, mood = 10687293613 },
	},
	anzug = { shirt = 2511715512, pants = 2511715750 }, -- black business suit
}
local function zufall(t) return t[math.random(#t)] end
-- stil: nil = random casual clothes, "uniform" = keep the body colours (police, job givers) but add hair and face,
-- or a table { shirt, pants, haar, kopf, frau } for a fixed look (Anna, Marco)
local function npcAussehen(desc, stil)
	local fest = type(stil) == "table" and stil or {}
	local frau = fest.frau
	if frau == nil then frau = math.random() < 0.5 end
	local k = fest.kopf or zufall(frau and NPC_LOOK.koepfeFrau or NPC_LOOK.koepfeMann)
	if stil ~= "uniform" then
		desc.Shirt = fest.shirt or zufall(NPC_LOOK.shirts)
		desc.Pants = fest.pants or zufall(NPC_LOOK.pants)
	end
	desc.Head = k.kopf
	desc.MoodAnimation = k.mood
	if frau then desc.WidthScale, desc.BodyTypeScale, desc.ProportionScale = 0.85, 0.3, 0.5 end
	desc.HairAccessory = tostring(fest.haar or zufall(frau and NPC_LOOK.haareFrau or NPC_LOOK.haareMann))
end

local function npc(name, anzeigeName, haut, oberteil, hose, stil)
	local function beschreibung(mitKleidung)
		local desc = Instance.new("HumanoidDescription")
		desc.HeadColor = haut
		desc.LeftArmColor = haut
		desc.RightArmColor = haut
		desc.TorsoColor = oberteil
		desc.LeftLegColor = hose
		desc.RightLegColor = hose
		if mitKleidung then pcall(npcAussehen, desc, stil) end
		return desc
	end
	local ok, modell = pcall(function()
		return Players:CreateHumanoidModelFromDescription(beschreibung(true), Enum.HumanoidRigType.R15)
	end)
	if not ok or not modell then
		-- catalog not reachable: plain colours as before
		ok, modell = pcall(function()
			return Players:CreateHumanoidModelFromDescription(beschreibung(false), Enum.HumanoidRigType.R15)
		end)
	end
	if not ok or not modell then
		warn("License system: could not create NPC " .. name .. ": " .. tostring(modell))
		return nil
	end
	modell.Name = name
	local hum = modell:FindFirstChildOfClass("Humanoid")
	if hum then
		if not hum:FindFirstChildOfClass("Animator") then
			Instance.new("Animator").Parent = hum
		end
		hum.DisplayName = anzeigeName
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
		hum.NameDisplayDistance = 40
	end
	return modell, hum
end

-- Roblox's standard R15 animations (free to use in every game)
local ANIM = {
	stehen = "rbxassetid://507766388",
	gehen = "rbxassetid://507777826",
	sitzen = "rbxassetid://2506281703",
}
local function animation(hum, art)
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if not animator then return nil end
	local a = Instance.new("Animation")
	a.AnimationId = ANIM[art]
	local ok, spur = pcall(function() return animator:LoadAnimation(a) end)
	if not ok then return nil end
	spur.Looped = true
	return spur
end

-- ---------------------------------------------------------------
-- Driver's license item (shown in the inventory after passing)
-- ---------------------------------------------------------------
local LIZENZ_NAME = "Driver's License"
local function fuehrerscheinItem(p)
	local d = daten[p]
	local tool = Instance.new("Tool")
	tool.Name = LIZENZ_NAME
	tool.CanBeDropped = false
	tool.ToolTip = "Show your driver's license"
	tool:SetAttribute("Fuehrerschein", true)
	tool:SetAttribute("Name", p.DisplayName)
	tool:SetAttribute("Benutzer", p.Name)
	tool:SetAttribute("Datum", d.fuehrerscheinDatum)
	tool:SetAttribute("Nummer", d.fuehrerscheinNr)
	tool:SetAttribute("Klassen", d.lkwFuehrerschein and "B C" or "B")
	tool:SetAttribute("LkwDatum", d.lkwDatum or "")
	local karte = Instance.new("Part")
	karte.Name = "Handle"
	karte.Size = Vector3.new(1.4, 0.9, 0.06)
	karte.Color = Color3.fromRGB(235, 200, 215)
	karte.CanCollide = false
	karte.Massless = true
	karte.Parent = tool
	for _, seite in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local g = Instance.new("SurfaceGui")
		g.Face = seite
		g.Parent = karte
		local l = Instance.new("TextLabel")
		l.Size = UDim2.fromScale(1, 1)
		l.BackgroundTransparency = 1
		l.Text = "DRIVER'S LICENSE\n" .. p.DisplayName .. (d.lkwFuehrerschein and "\nB  C" or "")
		l.Font = Enum.Font.GothamBold
		l.TextScaled = true
		l.TextColor3 = Color3.fromRGB(40, 40, 60)
		l.Parent = g
	end
	return tool
end
function fuehrerscheinGeben(p)
	local d = daten[p]
	if not d or not d.fuehrerschein then return end
	local rucksack = p:WaitForChild("Backpack", 10)
	local ausruestung = p:WaitForChild("StarterGear", 10)
	for _, ort in { rucksack, ausruestung, p.Character } do
		local alt = ort and ort:FindFirstChild(LIZENZ_NAME)
		if alt then alt:Destroy() end
	end
	if rucksack then fuehrerscheinItem(p).Parent = rucksack end
	if ausruestung then fuehrerscheinItem(p).Parent = ausruestung end -- comes back after respawning
end
for _, p in Players:GetPlayers() do
	if daten[p] then task.spawn(fuehrerscheinGeben, p) end
end

-- ---------------------------------------------------------------
-- Driving school building: receptionist and exam seats
-- ---------------------------------------------------------------
local fahrschule = workspace:WaitForChild("Karte"):WaitForChild("Vorstadt"):WaitForChild("Fahrschule")
local buchtOrdner = fahrschule:WaitForChild("Parkbuchten")
local blinkerEvent = ordner:WaitForChild("Blinker")
local MAX_FEHLER = 10                       -- from 10 mistakes the lesson does not count
local depot = workspace.Karte.Vorstadt:WaitForChild("Depot")
local lkwBuchtOrdner = depot:WaitForChild("LkwBuchten")
local jobs = {}         -- [player] = running delivery job
local privatAutos = {}  -- [player] = own car from the dealership { model, sitz, chassis, blinkTeile }
local autoWeg           -- defined with the car dealership further down

-- All routes (NPC traffic, lessons, speed zones) use the generator's coordinates. If the "Karte" model was
-- moved in Studio, cars drive through walls -> say so loudly in the output.
do
	local land = workspace.Karte:FindFirstChild("Strassen") and workspace.Karte.Strassen:FindFirstChild("Landstrasse")
	if land and (Vector3.new(land.Position.X, 0, land.Position.Z) - Vector3.new(557, 0, 0)).Magnitude > 1 then
		warn(("[Driving School] The map (Karte) was moved by %s – move it back, otherwise NPC cars and lessons don't match the roads!"):format(
			tostring(Vector3.new(land.Position.X - 557, 0, land.Position.Z))))
	end
end

-- Spawn outside in front of the entrance, looking at the door (works however the building was moved in Studio)
do
	local tuer, theke
	for _, t in fahrschule:GetChildren() do
		if t:IsA("BasePart") then
			if t.Name == "Tuer" and (not tuer or t.Size.Magnitude > tuer.Size.Magnitude) then tuer = t end
			if t.Name == "Theke" and (not theke or t.Size.X > theke.Size.X) then theke = t end
		end
	end
	local spawnTeil = workspace:FindFirstChild("FahrschulSpawn")
	if tuer and spawnTeil then
		-- the door's thin side points outwards; outside = away from the reception desk
		local n = tuer.Size.X < tuer.Size.Z and tuer.CFrame.RightVector or tuer.CFrame.LookVector
		n = Vector3.new(n.X, 0, n.Z).Unit
		local innen = theke and theke.Position or fahrschule:GetPivot().Position
		if (innen - tuer.Position):Dot(n) > 0 then n = -n end
		spawnTeil.CanQuery = false
		local pos = tuer.Position + n * 9
		local boden = workspace:Raycast(Vector3.new(pos.X, tuer.Position.Y + 10, pos.Z), Vector3.new(0, -40, 0))
		local y = (boden and boden.Position.Y or 0.2) + 0.5
		pos = Vector3.new(pos.X, y, pos.Z)
		spawnTeil.CFrame = CFrame.lookAt(pos, pos - n)
	end
end

-- area of the driving school parking lot (no turn-signal check while manoeuvring)
local parkMin, parkMax = Vector3.new(math.huge, 0, math.huge), Vector3.new(-math.huge, 0, -math.huge)
for _, b in buchtOrdner:GetChildren() do
	parkMin = Vector3.new(math.min(parkMin.X, b.Position.X - 8), 0, math.min(parkMin.Z, b.Position.Z - 8))
	parkMax = Vector3.new(math.max(parkMax.X, b.Position.X + 8), 0, math.max(parkMax.Z, b.Position.Z + 8))
end
local function aufParkplatz(pos)
	-- the lot itself plus the street right in front of it (driving in and out)
	return (pos.X > parkMin.X - 12 and pos.X < parkMax.X + 12 and pos.Z > parkMin.Z - 24 and pos.Z < parkMax.Z) or Regeln.imDepot(pos) or Regeln.imPizzeria(pos)
end
local function parkbuchten(nurUebung, lkw)
	local liste = {}
	for _, b in (lkw and lkwBuchtOrdner or buchtOrdner):GetChildren() do
		if not nurUebung or b:GetAttribute("Uebung") then
			table.insert(liste, b)
		end
	end
	return liste
end
local ampelOrdner = workspace.Karte:WaitForChild("Ampeln")
local stoppOrdner = workspace.Karte:FindFirstChild("Stoppschilder")
local rvlOrdner = workspace.Karte:FindFirstChild("RechtsVorLinks")

-- is an NPC vehicle moving close to this point? (for the give-way rule)
local function npcInDerNaehe(punkt, radius)
	for _, f in Verkehr.fahrzeuge or {} do
		if f.v > 3 and Vector3.new(f.pos.X - punkt.X, 0, f.pos.Z - punkt.Z).Magnitude < radius then
			return true
		end
	end
	return false
end

-- Receptionist behind the counter
task.spawn(function()
	local theke
	for _, t in fahrschule:GetChildren() do
		if t.Name == "Theke" and t:IsA("BasePart") and t.Size.X > 10 then theke = t end
	end
	if not theke then
		warn("License system: counter (Theke) not found")
		return
	end
	local anna, hum = npc("Rezeptionistin", "Anna (Reception)", Color3.fromRGB(234, 192, 160), Color3.fromRGB(30, 90, 180), Color3.fromRGB(40, 40, 50),
		{ shirt = NPC_LOOK.anzug.shirt, pants = NPC_LOOK.anzug.pants, haar = 7193448258, kopf = NPC_LOOK.koepfeFrau[1], frau = true })
	if not anna then return end
	local wurzel = anna:WaitForChild("HumanoidRootPart")
	wurzel.Anchored = true
	local hoehe = 0.5 + hum.HipHeight + wurzel.Size.Y / 2
	local pos = Vector3.new(theke.Position.X, hoehe, theke.Position.Z + 3.5)
	anna:PivotTo(CFrame.lookAt(pos, pos + Vector3.new(0, 0, -1)))
	anna.Parent = fahrschule
	local idle = animation(hum, "stehen")
	if idle then idle:Play() end
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = "Talk"
	pp.ObjectText = "Anna (Reception)"
	pp.HoldDuration = 0
	pp.MaxActivationDistance = 10
	pp.RequiresLineOfSight = false
	pp.Parent = wurzel
	pp.Triggered:Connect(function(p)
		oeffnen:FireClient(p, "dialog")
	end)
end)

-- Whiteboard = theory lesson
do
	local tafel = fahrschule:WaitForChild("Tafel")
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = "Theory lesson"
	pp.ObjectText = "Whiteboard"
	pp.HoldDuration = 0
	pp.MaxActivationDistance = 12
	pp.RequiresLineOfSight = false
	pp.Parent = tafel
	pp.Triggered:Connect(function(p)
		oeffnen:FireClient(p, "unterricht")
	end)
end

-- Exam seats: sitting down opens the test, standing up cancels it
for _, sitz in fahrschule:GetDescendants() do
	if sitz:IsA("Seat") and sitz:GetAttribute("Pruefungsplatz") then
		sitz:GetPropertyChangedSignal("Occupant"):Connect(function()
			local hum = sitz.Occupant
			if hum then
				local p = Players:GetPlayerFromCharacter(hum.Parent)
				if p then
					sitzend[p] = sitz
					oeffnen:FireClient(p, "pruefungsplatz")
				end
			else
				for p, s in sitzend do
					if s == sitz then
						sitzend[p] = nil
						pruefungen[p] = nil
						oeffnen:FireClient(p, "aufgestanden")
					end
				end
			end
		end)
	end
end

local function sitztAmPlatz(p)
	local s = sitzend[p]
	return s ~= nil and s.Occupant ~= nil and p.Character ~= nil and s.Occupant.Parent == p.Character
end

-- ---------------------------------------------------------------
-- Driving lessons
-- ---------------------------------------------------------------
local function aussteigen(sitz)
	local w = sitz and sitz:FindFirstChild("SeatWeld")
	if w then w:Destroy() end
end

local function lektionBeenden(p, erfolg, text)
	local st = lektionen[p]
	if not st then return end
	lektionen[p] = nil
	local d = daten[p]
	if st.pruefung and erfolg and d then
		-- passed the driving test: license, cutscene, item
		if st.lkw then
			d.lkwFuehrerschein = true
			d.lkwDatum = os.date("!%d.%m.%Y")
		else
			d.fuehrerschein = true
			d.fuehrerscheinDatum = os.date("!%d.%m.%Y")
			d.fuehrerscheinNr = ("DS-%06d"):format(p.UserId % 1000000)
			if d.entzogen then
				-- license back after a withdrawal: clean record, class C returns too
				d.entzogen, d.nachschulung, d.punkte, d.punkteZeit = false, false, 0, 0
				if d.lkwGesperrt then d.lkwFuehrerschein, d.lkwGesperrt = true, false end
				table.insert(d.historie, 1, { t = os.time(), text = "License regained", geld = 0, punkte = 0 })
			end
		end
		xpGeben(p, st.fehler == 0 and 350 or 250, st.fehler == 0 and "Perfect driving test!" or "Driving test passed")
		if st.fehler == 0 then
			d.perfekt = (d.perfekt or 0) + 1
			Missionen.fortschritt(p, "perfekt", 1)
		end
		geaendert(p)
		task.spawn(fuehrerscheinGeben, p)
		if p.Parent then
			fahrEvent:FireClient(p, {
				typ = "bestanden", text = text, fehler = st.fehler, lkw = st.lkw,
				name = p.DisplayName, benutzer = p.Name, userId = p.UserId,
				datum = d.fuehrerscheinDatum, nummer = d.fuehrerscheinNr,
				klassen = d.lkwFuehrerschein and "B C" or "B", lkwDatum = d.lkwDatum,
			})
		end
		task.delay(12, geldGeben, p, 250, st.lkw and "Truck license" or "Driver's license")
	elseif erfolg and d then
		local neu = st.nr > d.fahrstunden
		d.fahrstunden = math.max(d.fahrstunden, st.nr)
		geaendert(p)
		if neu then geldGeben(p, 25, "Lesson complete") end
		xpGeben(p, st.fehler == 0 and 80 or 50, st.fehler == 0 and "Perfect lesson!" or "Lesson complete")
		if st.fehler == 0 then Missionen.fortschritt(p, "perfekt", 1) end
	end
	if p.Parent and not (st.pruefung and erfolg) then
		fahrEvent:FireClient(p, { typ = "ende", erfolg = erfolg, text = text, fehler = st.fehler, nr = st.nr, gesamt = #LEKTIONEN, pruefung = st.pruefung })
	end
	local warten = 1
	if erfolg then warten = st.pruefung and 13 or 4 end
	task.delay(warten, function()
		aussteigen(st.sitz)
		if st.model then st.model:Destroy() end
	end)
end

local function zielSenden(p, st)
	local wp = st.lektion.punkte[st.index]
	local info = {
		typ = "ziel",
		pos = Vector3.new(wp.x, 0, wp.z),
		text = wp.t,
		nr = st.index,
		gesamt = #st.lektion.punkte,
		sprecher = st.pruefung and "Examiner" or "Instructor",
	}
	-- the green gate: after a turn it stands on the new road in the right lane
	local torPos, torDir, breite, radius = Regeln.tor(st.lektion.punkte, st.index, st.startPos)
	st.tor = { pos = torPos, dir = torDir, breite = breite, r = radius }
	info.pos, info.richtung, info.breite = torPos, torDir, breite
	info.route = {}
	for _, punkt in st.lektion.punkte do
		table.insert(info.route, { punkt.x, punkt.z })
	end
	if wp.parken then
		info.park = {}
		for _, b in parkbuchten(wp.uebung, wp.lkw) do
			table.insert(info.park, { cf = b.CFrame, groesse = b.Size })
		end
	end
	st.zielAktiv = true
	fahrEvent:FireClient(p, info)
end

local function warnung(p, st, text, punkte)
	st.fehler += punkte or 1
	st.letzteWarnung = os.clock()
	fahrEvent:FireClient(p, { typ = "warnung", text = text, fehler = st.fehler, grenze = st.erlaubt })
	if st.fehler > st.erlaubt then
		if st.pruefung then
			lektionBeenden(p, false, ("You made %d mistakes, but only %d are allowed. You failed the driving test. Talk to Anna to try again."):format(st.fehler, st.erlaubt))
		else
			lektionBeenden(p, false, ("You made %d mistakes, so this lesson does not count. Talk to Anna at the reception and try it again."):format(st.fehler))
		end
	end
end

-- is a parking bay free (no lesson car or job truck standing in it)?
local function buchtFrei(b)
	for _, st in lektionen do
		if st.chassis and (st.chassis.Position - b.Position).Magnitude < 8 then return false end
	end
	for _, job in jobs do
		if job.chassis and (job.chassis.Position - b.Position).Magnitude < 8 then return false end
	end
	for _, a in privatAutos do
		if a.chassis and a.chassis.Parent and (a.chassis.Position - b.Position).Magnitude < 8 then return false end
	end
	return true
end

local function freierStart()
	-- a free bay in the back row (next to the building), otherwise the front row
	for _, reihe in { "hinten", "vorne" } do
		for _, b in buchtOrdner:GetChildren() do
			if b:GetAttribute("Reihe") == reihe and not b:GetAttribute("Uebung") and buchtFrei(b) then
				return CFrame.new(b.Position.X, b.Position.Y + 0.25, b.Position.Z - 1)
			end
		end
	end
	local b = buchtOrdner:GetChildren()[1]
	return CFrame.new(b.Position.X, b.Position.Y + 0.25, b.Position.Z - 1)
end

local function freieLkwBucht()
	local buchten = lkwBuchtOrdner:GetChildren()
	table.sort(buchten, function(x, y) return x.Position.X < y.Position.X end)
	for _, b in buchten do
		if buchtFrei(b) then
			return CFrame.new(b.Position.X, b.Position.Y + 0.25, b.Position.Z + 1) -- faces north to the exit
		end
	end
	return nil
end

-- Instructor / examiner sitting in a vehicle
local function mitfahrer(modell, name, anzeige, haut, oberteil, hose, platz)
	task.spawn(function()
		local figur, hum = npc(name, anzeige, haut, oberteil, hose, "uniform")
		if not figur or not modell.Parent then return end
		for _, teilchen in figur:GetDescendants() do
			if teilchen:IsA("BasePart") then
				teilchen.Massless = true
				teilchen.CanCollide = false
			end
		end
		figur:PivotTo(platz.CFrame + Vector3.new(0, 3, 0))
		figur.Parent = modell
		hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		platz:Sit(hum)
		local sitzt = animation(hum, "sitzen")
		if sitzt then sitzt:Play() end
	end)
end

-- "Get in" button that only works for one player
local function einsteigPrompt(p, sitz, objekt)
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = "Get in"
	pp.ObjectText = objekt
	pp.HoldDuration = 0
	pp.MaxActivationDistance = 12
	pp.RequiresLineOfSight = false
	pp.Parent = sitz
	pp.Triggered:Connect(function(wer)
		if wer ~= p or sitz.Occupant then return end
		local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		if hum then sitz:Sit(hum) end
	end)
	sitz:GetPropertyChangedSignal("Occupant"):Connect(function()
		pp.Enabled = sitz.Occupant == nil -- hide "Get in" while someone sits in the car
	end)
	return pp
end

local function blinkTeileSuchen(modell)
	local teile = { L = {}, R = {} }
	for _, t in modell:GetDescendants() do
		if t.Name == "BlinkerL" then table.insert(teile.L, t) end
		if t.Name == "BlinkerR" then table.insert(teile.R, t) end
	end
	return teile
end

local function lektionStarten(p, art)
	local d = daten[p]
	local pruefung = art == "pruefung" or art == "lkw"
	local lkw = art == "lkw"
	if lektionen[p] then
		return { fehler = "You already have a lesson in progress." }
	end
	if jobs[p] then
		return { fehler = "Finish or cancel your delivery job first." }
	end
	if not d.theorie then
		return { fehler = "You need to pass the theory test first." }
	end
	local nr, lektion
	if lkw then
		if not d.fuehrerschein then
			return { fehler = "You need a car driver's license (class B) first." }
		end
		if d.lkwFuehrerschein then
			return { fehler = "You already have your truck license!" }
		end
		nr = #LEKTIONEN + 2
		lektion = LEKTIONEN.LKW
	elseif pruefung then
		if d.fuehrerschein then
			return { fehler = "You already have your driver's license!" }
		end
		if d.entzogen and not d.nachschulung then
			return { fehler = "Your license was withdrawn. Do the retraining course with Anna first." }
		end
		if d.fahrstunden < #LEKTIONEN then
			return { fehler = "Please complete all driving lessons before the driving test." }
		end
		nr = #LEKTIONEN + 1
		lektion = LEKTIONEN.PRUEFUNGEN[math.random(#LEKTIONEN.PRUEFUNGEN)]
	else
		nr = d.fahrstunden + 1
		lektion = LEKTIONEN[nr]
		if not lektion then
			return { fehler = "You have already completed all driving lessons." }
		end
	end

	local modell, sitz, beifahrer, chassis, ruecksitz
	local cf
	if lkw then
		cf = freieLkwBucht()
		if not cf then
			return { fehler = "All truck bays at the depot are taken. Please try again in a moment." }
		end
		modell, sitz, beifahrer, chassis, ruecksitz = Auto.bauenLkw(cf, Color3.fromRGB(30, 90, 180), "DRIVING SCHOOL")
		modell.Name = "Fahrschul_Lkw_" .. p.Name
	else
		cf = freierStart()
		modell, sitz, beifahrer, chassis, ruecksitz = Auto.bauen(cf, AUTOFARBEN[math.random(#AUTOFARBEN)])
		modell.Name = "Fahrschulauto_" .. p.Name
	end
	modell.Parent = workspace

	local st = {
		nr = nr, lektion = lektion, index = 1, model = modell, sitz = sitz, chassis = chassis,
		fehler = 0, gestartet = false, zielAktiv = false, letzteWarnung = 0, letztePos = nil,
		parkPhase = false, ausgestiegenSeit = nil, stoppHinweis = false,
		startPos = cf.Position, blinker = "aus", blinkZeit = { links = -math.huge, rechts = -math.huge },
		drehSumme = 0, letzteRichtung = nil, geradeSeit = nil, abgebogen = nil,
		blinkTeile = blinkTeileSuchen(modell), letzterUnfall = 0,
		pruefung = pruefung, lkw = lkw, erlaubt = pruefung and 3 or (MAX_FEHLER - 1),
	}
	lektionen[p] = st

	-- Instructor in the passenger seat, examiner in the back (or in the middle of the truck cab)
	mitfahrer(modell, "Fahrlehrer", "Mike (Instructor)", Color3.fromRGB(205, 160, 125), Color3.fromRGB(255, 255, 255), Color3.fromRGB(60, 60, 70), beifahrer)
	if pruefung then
		mitfahrer(modell, "Pruefer", "Mr. Becker (Examiner)", Color3.fromRGB(225, 185, 150), Color3.fromRGB(45, 50, 65), Color3.fromRGB(45, 50, 65), ruecksitz)
	end

	einsteigPrompt(p, sitz, lkw and "Driving school truck" or "Driving school car")
	sitz:GetPropertyChangedSignal("Occupant"):Connect(function()
		if lektionen[p] ~= st then return end
		local hum = sitz.Occupant
		if hum then
			if Players:GetPlayerFromCharacter(hum.Parent) ~= p then
				aussteigen(sitz) -- only the student may drive
				return
			end
			st.ausgestiegenSeit = nil
			pcall(function() chassis:SetNetworkOwner(p) end)
			if not st.gestartet then
				st.gestartet = true
				fahrEvent:FireClient(p, { typ = "start", titel = lektion.titel, text = lektion.intro, sprecher = pruefung and "Examiner" or "Instructor", grenze = st.erlaubt })
				task.delay(6, function()
					if lektionen[p] == st then zielSenden(p, st) end
				end)
			end
		else
			st.ausgestiegenSeit = os.clock()
			fahrEvent:FireClient(p, { typ = "hinweis", text = "You left the vehicle! Get back in within 20 seconds, or the lesson ends." })
		end
	end)

	if lkw then
		fahrEvent:FireClient(p, { typ = "weg", pos = cf.Position })
		return { text = "Your truck test starts now! The driving school truck is waiting at the Parcel Express depot, south of the neighbourhood (follow the green line on your minimap). Press E at the driver's door to get in." }
	elseif pruefung then
		return { text = "Your driving test starts now! Mike and your examiner Mr. Becker are waiting in the car on the parking lot. Press E at the driver's door to get in." }
	end
	return { text = ("Your car for %s is waiting on the parking lot. Walk to the driver's door and press E to get in."):format(lektion.titel) }
end

-- ---------------------------------------------------------------
-- Pedestrians crossing at zebra crossings in the city
-- ---------------------------------------------------------------
local fussgaenger = {}
do
	local ordnerF = Instance.new("Folder")
	ordnerF.Name = "Fussgaenger"
	ordnerF.Parent = workspace
	-- intersections the lessons and tests drive through
	local kreuzungen = { { 104, 0 }, { -104, 0 }, { 208, -104 }, { 0, -104 }, { 0, 104 }, { 0, 208 } }
	local richtungen = { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) }
	local haut = { Color3.fromRGB(234, 192, 160), Color3.fromRGB(198, 145, 105), Color3.fromRGB(141, 94, 60), Color3.fromRGB(255, 220, 190) }
	local kleidung = { Color3.fromRGB(200, 60, 60), Color3.fromRGB(60, 110, 200), Color3.fromRGB(240, 200, 60), Color3.fromRGB(60, 160, 90), Color3.fromRGB(40, 40, 45), Color3.fromRGB(230, 230, 230) }
	local function autoInDerNaehe(punkt)
		for _, st in lektionen do
			if st.chassis and st.chassis.Parent then
				local abstand = (st.chassis.Position - punkt).Magnitude
				if abstand < 22 and st.chassis.AssemblyLinearVelocity.Magnitude > 6 then return true end
			end
		end
		return false
	end

	for i, k in kreuzungen do
		task.spawn(function()
			task.wait(i * 0.5)
			local d = richtungen[math.random(#richtungen)]
			local mitte = Vector3.new(k[1], 0, k[2]) + d * 15.5
			local quer = Vector3.new(math.abs(d.Z), 0, math.abs(d.X))
			local seiteA = mitte - quer * 15 + Vector3.new(0, 1.2, 0)
			local seiteB = mitte + quer * 15 + Vector3.new(0, 1.2, 0)
			local figur, hum = npc("Fussgaenger", "", haut[math.random(#haut)], kleidung[math.random(#kleidung)], kleidung[math.random(#kleidung)])
			if not figur then return end
			hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			hum.WalkSpeed = 5
			local wurzel = figur:WaitForChild("HumanoidRootPart")
			figur:PivotTo(CFrame.new(seiteA + Vector3.new(0, hum.HipHeight + wurzel.Size.Y / 2, 0)))
			figur.Parent = ordnerF
			pcall(function() wurzel:SetNetworkOwner(nil) end)
			local gehen = animation(hum, "gehen")
			local stehen = animation(hum, "stehen")
			if stehen then stehen:Play() end
			local f = { figur = figur, hum = hum, wurzel = wurzel, getroffen = -math.huge, liegt = false }
			table.insert(fussgaenger, f)

			local ziel, start = seiteB, seiteA
			while figur.Parent do
				task.wait(math.random(15, 40)) -- only now and then
				-- wait on the sidewalk while a car is approaching fast
				while autoInDerNaehe(mitte) or f.liegt do task.wait(0.5) end
				if stehen then stehen:Stop() end
				if gehen then gehen:Play() end
				hum:MoveTo(ziel)
				local fertig = false
				local verbindung = hum.MoveToFinished:Connect(function() fertig = true end)
				local t0 = os.clock()
				while not fertig and os.clock() - t0 < 12 do
					task.wait(0.2)
					if f.liegt then
						-- knocked over: wait, then stand up and keep walking
						if gehen then gehen:Stop() end
						task.wait(3)
						hum.PlatformStand = false
						f.liegt = false
						if gehen then gehen:Play() end
						hum:MoveTo(ziel)
					end
				end
				verbindung:Disconnect()
				if gehen then gehen:Stop() end
				if stehen then stehen:Play() end
				ziel, start = start, ziel
			end
		end)
	end
end

-- Residents walking around inside the two gated communities
do
	local ordnerF = workspace:FindFirstChild("Fussgaenger")
	local haut = { Color3.fromRGB(234, 192, 160), Color3.fromRGB(198, 145, 105), Color3.fromRGB(141, 94, 60), Color3.fromRGB(255, 220, 190) }
	local kleidung = { Color3.fromRGB(200, 60, 60), Color3.fromRGB(60, 110, 200), Color3.fromRGB(240, 200, 60), Color3.fromRGB(60, 160, 90), Color3.fromRGB(40, 40, 45), Color3.fromRGB(230, 230, 230), Color3.fromRGB(240, 150, 190) }
	local XS, QS = { 500, 600, 700 }, { 40, 96, 152, 208 }
	local function nachbarn(sg, xi, qi)
		local liste = {}
		for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			local nx, nq = xi + d[1], qi + d[2]
			if XS[nx] and QS[nq] then
				-- the street in front of the driving school is split (no way between 500 and 600 at 96)
				local gesperrt = sg == 1 and d[2] == 0 and QS[qi] == 96 and math.min(XS[xi], XS[nx]) == 500
				if not gesperrt then table.insert(liste, { nx, nq }) end
			end
		end
		return liste
	end
	for i = 1, 8 do
		task.spawn(function()
			task.wait(2 + i * 0.7)
			local sg = (i % 2 == 0) and 1 or -1
			local xi, qi = math.random(#XS), math.random(#QS)
			local figur, hum = npc("Bewohner", "", haut[math.random(#haut)], kleidung[math.random(#kleidung)], kleidung[math.random(#kleidung)])
			if not figur then return end
			hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			hum.WalkSpeed = 4 + math.random() * 2
			local wurzel = figur:WaitForChild("HumanoidRootPart")
			local start = Vector3.new(XS[xi] + 11, 0.2 + hum.HipHeight + wurzel.Size.Y / 2, QS[qi] * sg + 11)
			figur:PivotTo(CFrame.new(start))
			figur.Parent = ordnerF or workspace
			pcall(function() wurzel:SetNetworkOwner(nil) end)
			local gehen = animation(hum, "gehen")
			local stehen = animation(hum, "stehen")
			local f = { figur = figur, hum = hum, wurzel = wurzel, getroffen = -math.huge, liegt = false }
			table.insert(fussgaenger, f)
			local vorher
			while figur.Parent do
				local wahl = nachbarn(sg, xi, qi)
				if #wahl > 1 and vorher then
					for k, w in wahl do
						if w[1] == vorher[1] and w[2] == vorher[2] then table.remove(wahl, k) break end
					end
				end
				local n = wahl[math.random(#wahl)]
				local a = Vector3.new(XS[xi], 0, QS[qi] * sg)
				local b = Vector3.new(XS[n[1]], 0, QS[n[2]] * sg)
				local dir = (b - a).Unit
				local seite = Vector3.new(-dir.Z, 0, dir.X) * 11 -- walk along the right edge of the street
				local ziel = b - dir * 11 + seite + Vector3.new(0, wurzel.Position.Y, 0)
				if stehen then stehen:Stop() end
				if gehen then gehen:Play() end
				hum:MoveTo(ziel)
				local t0 = os.clock()
				while os.clock() - t0 < 25 and (Vector3.new(wurzel.Position.X, 0, wurzel.Position.Z) - Vector3.new(ziel.X, 0, ziel.Z)).Magnitude > 3 do
					task.wait(0.3)
					if f.liegt then
						if gehen then gehen:Stop() end
						task.wait(3)
						hum.PlatformStand = false
						f.liegt = false
						if gehen then gehen:Play() end
					end
					hum:MoveTo(ziel)
				end
				vorher = { xi, qi }
				xi, qi = n[1], n[2]
				if gehen then gehen:Stop() end
				if math.random() < 0.35 then
					if stehen then stehen:Play() end
					task.wait(math.random(3, 9)) -- stop for a chat
				end
			end
		end)
	end
end

local function fussgaengerUmwerfen(f, schub)
	f.liegt = true
	f.hum.PlatformStand = true
	f.wurzel:ApplyImpulse((schub + Vector3.new(0, 30, 0)) * f.wurzel.AssemblyMass)
end

-- Checks every 0.1 s: speed, red lights, waypoints
local takt = 0
RunService.Heartbeat:Connect(function(dt)
	takt += dt
	if takt < 0.1 then return end
	takt = 0
	for p, st in lektionen do
		if not p.Parent or not st.model.Parent then
			lektionen[p] = nil
			if st.model then st.model:Destroy() end
			continue
		end
		if st.ausgestiegenSeit and os.clock() - st.ausgestiegenSeit > 20 then
			lektionBeenden(p, false, "The lesson was cancelled because you left the car.")
			continue
		end
		if not st.zielAktiv or st.ausgestiegenSeit then continue end

		local pos = st.chassis.Position
		local tempo = st.chassis.AssemblyLinearVelocity.Magnitude

		-- vehicle outline around the chassis (front = -Z)
		local vorneZ, hintenZ, halbB = -8.8, 8.8, 4.2
		if st.lkw then
			vorneZ = st.model:GetAttribute("VorneZ") or -11
			hintenZ = st.model:GetAttribute("HintenZ") or 16
			halbB = 4.6
		end

		-- Pedestrians: touching one costs 3 points
		for _, f in fussgaenger do
			if f.wurzel.Parent and os.clock() - f.getroffen > 4 and (f.wurzel.Position - pos).Magnitude < 20 then
				local lp = st.chassis.CFrame:PointToObjectSpace(f.wurzel.Position)
				if math.abs(lp.X) < halbB and lp.Z > vorneZ and lp.Z < hintenZ and lp.Y > -2 and lp.Y < 8 then
					f.getroffen = os.clock()
					fussgaengerUmwerfen(f, st.chassis.AssemblyLinearVelocity * 0.6)
					warnung(p, st, "You hit a pedestrian! (+3 mistakes)", 3)
					if lektionen[p] ~= st then break end
				end
			end
		end
		if lektionen[p] ~= st then continue end

		-- Crashing into another car of the NPC traffic costs 3 points
		if Verkehr.fahrzeuge and os.clock() - st.letzterUnfall > 5 then
			local cfFlach = st.chassis.CFrame
			for _, f in Verkehr.fahrzeuge do
				local rel = Vector3.new(pos.X - f.pos.X, 0, pos.Z - f.pos.Z)
				if rel.Magnitude < 30 then
					-- check the four corners of our vehicle against the NPC vehicle's box
					local getroffen = false
					local rechts = Vector3.new(-f.dir.Z, 0, f.dir.X)
					for _, ecke in { { -halbB, vorneZ }, { halbB, vorneZ }, { -halbB, hintenZ }, { halbB, hintenZ }, { 0, vorneZ }, { 0, hintenZ } } do
						local w = cfFlach:PointToWorldSpace(Vector3.new(ecke[1], 0, ecke[2]))
						local r2 = Vector3.new(w.X - f.pos.X, 0, w.Z - f.pos.Z)
						if math.abs(r2:Dot(f.dir)) < f.laenge / 2 + 0.3 and math.abs(r2:Dot(rechts)) < f.breite / 2 + 0.3 then
							getroffen = true
							break
						end
					end
					if getroffen then
						st.letzterUnfall = os.clock()
						warnung(p, st, "You crashed into another vehicle! (+3 mistakes)", 3)
						break
					end
				end
			end
		end
		if lektionen[p] ~= st then continue end

		-- Speeding (more than 8 over the limit for 1.5 s)
		local limit = Regeln.tempolimit(pos)
		if tempo > limit + 8 then
			st.zuSchnellSeit = st.zuSchnellSeit or os.clock()
			if os.clock() - st.zuSchnellSeit > 1.5 and os.clock() - st.letzteWarnung > 6 then
				warnung(p, st, ("Too fast! The limit here is %d km/h."):format(limit))
			end
		else
			st.zuSchnellSeit = nil
		end

		-- Red light: crossing a stop line while the light is red
		if st.letztePos then
			for _, ampel in ampelOrdner:GetChildren() do
				if ampel:GetAttribute("Phase") == "Rot" then
					local L = ampel:GetAttribute("Haltelinie")
					local d = ampel:GetAttribute("Anfahrt")
					local re = ampel:GetAttribute("Rechts")
					if L and d and re then
						local vorher = (st.letztePos - L):Dot(d)
						local jetzt = (pos - L):Dot(d)
						if vorher > 0 and jetzt <= 0 and math.abs((pos - L):Dot(re)) < 7 then
							warnung(p, st, "You drove through a red light!")
						end
					end
				end
			end
		end
		-- STOP signs: you must have stood still shortly before the stop line
		if tempo < 1.5 then
			st.stillPos = pos
			st.stillZeit = os.clock()
		end
		if st.letztePos and stoppOrdner then
			for _, schild in stoppOrdner:GetChildren() do
				local L = schild:GetAttribute("Haltelinie")
				if L and (pos - L).Magnitude < 40 then
					local d = schild:GetAttribute("Anfahrt")
					local re = schild:GetAttribute("Rechts")
					local vorher = (st.letztePos - L):Dot(d)
					local jetzt = (pos - L):Dot(d)
					if vorher > 0 and jetzt <= 0 and math.abs((pos - L):Dot(re)) < 7 then
						if schild:GetAttribute("Typ") == "Vorfahrt gewaehren" then
							-- give way: slow down, and nobody on the main road may be close
							if tempo > 22 then
								warnung(p, st, "Too fast at the YIELD sign! Slow down and check for traffic.")
							elseif npcInDerNaehe(L, 40) then
								warnung(p, st, "You didn't give way to the traffic on the main road!")
							end
						else
							local gehalten = st.stillZeit and os.clock() - st.stillZeit < 6 and (st.stillPos - L).Magnitude < 25
							if not gehalten then
								warnung(p, st, "You didn't stop at the STOP sign!")
							end
						end
					end
				end
			end
		end
		-- Junctions without signs: right before left -> approach slowly
		if rvlOrdner then
			st.rvlDrin = st.rvlDrin or {}
			for _, k in rvlOrdner:GetChildren() do
				local abstand = Vector3.new(pos.X - k.Position.X, 0, pos.Z - k.Position.Z).Magnitude
				local drin = abstand < 11
				if drin and not st.rvlDrin[k] and not aufParkplatz(pos) then
					local c = Vector3.new(k.Position.X, 0, k.Position.Z)
					local blick = st.chassis.CFrame.LookVector
					local rechts = Vector3.new(-blick.Z, 0, blick.X)
					local vonRechts = false
					for _, o in Verkehr.fahrzeuge or {} do
						local orel = o.pos - c
						if o.v > 2 and orel.Magnitude < 35 and orel:Dot(rechts) > 4 and (-orel).Unit:Dot(o.dir) > 0.5 then
							vonRechts = true
						end
					end
					if vonRechts then
						warnung(p, st, "Right before left! You didn't give way to the vehicle from the right.")
					elseif tempo > 22 then
						warnung(p, st, "Right before left! Approach junctions without signs slowly (max. 20 km/h).")
					end
				end
				st.rvlDrin[k] = drin or nil
			end
		end
		st.letztePos = pos

		-- Turn signal: every turn of more than 55 degrees needs the matching indicator
		if st.blinker == "links" or st.blinker == "rechts" then
			st.blinkZeit[st.blinker] = os.clock()
		end
		local blick = st.chassis.CFrame.LookVector
		local richtung = math.atan2(-blick.X, -blick.Z)
		if aufParkplatz(pos) then
			-- manoeuvring on the driving school parking lot: no turn-signal check
			st.drehSumme = 0
			st.abgebogen = nil
		elseif st.letzteRichtung then
			local dr = (richtung - st.letzteRichtung + math.pi) % (2 * math.pi) - math.pi
			if tempo > 3 then st.drehSumme += dr end
			if math.abs(dr) < 0.012 then
				st.geradeSeit = st.geradeSeit or os.clock()
			else
				st.geradeSeit = nil
			end
			if st.geradeSeit and os.clock() - st.geradeSeit > 1.2 then
				-- turn finished: switch the indicator off like a real car
				if st.abgebogen then
					st.blinkZeit[st.abgebogen] = -math.huge -- the next turn needs a new signal
				end
				if st.abgebogen and st.blinker == st.abgebogen then
					st.blinker = "aus"
					st.model:SetAttribute("Blinker", nil)
					fahrEvent:FireClient(p, { typ = "blinker", modus = "aus" })
				end
				st.drehSumme = 0
				st.abgebogen = nil
			end
			if not st.abgebogen and math.abs(st.drehSumme) > math.rad(55) then
				local seite = st.drehSumme > 0 and "links" or "rechts"
				st.abgebogen = seite
				local ausgenommen = Regeln.imKreisel(pos) or aufParkplatz(pos)
				if not ausgenommen and os.clock() - st.blinkZeit[seite] > 5 then
					warnung(p, st, seite == "links" and "You turned left without signalling! (Y)" or "You turned right without signalling! (C)")
				end
			end
		end
		st.letzteRichtung = richtung
		if lektionen[p] ~= st then continue end -- lesson ended (too many mistakes)

		-- Waypoints
		local wp = st.lektion.punkte[st.index]
		local abstand = (Vector3.new(wp.x, pos.Y, wp.z) - pos).Magnitude
		local amTor = st.tor and Regeln.durchTor(pos, st.tor.pos, st.tor.dir, st.tor.breite, st.tor.r)
		if wp.parken then
			if not st.parkPhase and (abstand < (wp.r or 16) or amTor or (wp.lkw and Regeln.imDepot(pos) and pos.Z > 335)) then
				st.parkPhase = true
			end
			if st.parkPhase and tempo < 1.5 then
				for _, b in parkbuchten(wp.uebung, wp.lkw) do
					local lokal = b.CFrame:PointToObjectSpace(pos)
					local drin = math.abs(lokal.X) < b.Size.X / 2 - 1.8 and math.abs(lokal.Z) < b.Size.Z / 2 + 2.5
					local gerade = math.abs(st.chassis.CFrame.LookVector:Dot(b.CFrame.LookVector)) > 0.9
					if drin and gerade then
						local text
						if st.lkw then
							text = "Well parked! You passed the truck driving test!"
						elseif st.pruefung then
							text = "Well parked! You passed the driving test!"
						elseif st.nr >= #LEKTIONEN then
							text = "Perfectly parked! You have completed all driving lessons."
						elseif st.fehler == 0 then
							text = "Parked! Excellent, no mistakes. Lesson complete."
						else
							text = ("Parked! Lesson complete with %d mistake(s). Keep practising!"):format(st.fehler)
						end
						lektionBeenden(p, true, text)
						break
					end
				end
			end
		elseif amTor or (not st.tor and abstand < (wp.r or 14)) then
			if wp.stopp and tempo > 2 then
				if not st.stoppHinweis then
					st.stoppHinweis = true
					fahrEvent:FireClient(p, { typ = "hinweis", text = "Brake until the car stands still." })
				end
			else
				st.index += 1
				st.stoppHinweis = false
				if st.index > #st.lektion.punkte then
					local text = st.fehler == 0 and "Excellent, no mistakes! Lesson complete." or ("Lesson complete with %d mistake(s). Keep practising!"):format(st.fehler)
					lektionBeenden(p, true, text)
				else
					zielSenden(p, st)
				end
			end
		end
	end
end)

-- Indicators: the driver switches them, the server makes them blink for everyone
local BLINK_AN = Color3.fromRGB(255, 165, 30)
local BLINK_AUS = Color3.fromRGB(150, 95, 35)
blinkerEvent.OnServerEvent:Connect(function(p, modus)
	local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
	local sitz = hum and hum.SeatPart
	if not (sitz and sitz:IsA("VehicleSeat") and sitz.Parent and sitz.Parent:GetAttribute("Fahrschulauto")) then return end
	if modus == "licht" then
		-- headlights on / off (everybody sees it)
		local modell = sitz.Parent
		local an = modell:GetAttribute("LichtAus") == true
		modell:SetAttribute("LichtAus", not an or nil)
		for _, t in modell:GetDescendants() do
			if t:IsA("SpotLight") then t.Enabled = an end
			if t.Name == "Scheinwerfer" and t:IsA("BasePart") then
				t.Material = an and Enum.Material.Neon or Enum.Material.Glass
			end
		end
		return
	end
	if modus ~= "links" and modus ~= "rechts" and modus ~= "warn" and modus ~= "aus" then return end
	sitz.Parent:SetAttribute("Blinker", modus ~= "aus" and modus or nil)
	local st = lektionen[p]
	if st and st.model == sitz.Parent then
		st.blinker = modus
		for seite in st.blinkZeit do
			if seite ~= modus then st.blinkZeit[seite] = -math.huge end -- another switch position cancels the old signal
		end
		if modus == "links" or modus == "rechts" then
			st.blinkZeit[modus] = os.clock()
			st.abgebogen = nil -- a new indicator starts a new turn
			st.drehSumme = 0
		end
	end
end)

local blinkTakt, blinkPhase = 0, false
RunService.Heartbeat:Connect(function(dt)
	blinkTakt += dt
	if blinkTakt < 0.4 then return end
	blinkTakt = 0
	blinkPhase = not blinkPhase
	local alle = {}
	for _, st in lektionen do table.insert(alle, st) end
	for _, job in jobs do table.insert(alle, job) end
	for _, a in privatAutos do table.insert(alle, a) end
	for _, st in alle do
		if st.model and st.model.Parent and st.blinkTeile then
			local modus = st.model:GetAttribute("Blinker")
			for seite, teile in st.blinkTeile do
				local an = blinkPhase and (modus == "warn" or (modus == "links" and seite == "L") or (modus == "rechts" and seite == "R"))
				for _, t in teile do
					t.Color = an and BLINK_AN or BLINK_AUS
					t.Material = an and Enum.Material.Neon or Enum.Material.SmoothPlastic
				end
			end
		end
	end
end)

-- ---------------------------------------------------------------
-- Delivery jobs: trucks (Parcel Express, needs class C) and pizza (Pizza Rapido, needs class B).
-- At every customer: stop, get out, take the goods from the back of the vehicle
-- and hand them to the customer waiting at the door.
-- Trucks level up: after a number of finished jobs you get a bigger truck with more valuable goods.
-- ---------------------------------------------------------------
local LKW_STUFEN = {
	{ name = "Box Truck", ware = "Parcels", item = "Package", pakete = 3, lohn = 150, bonus = 100, ab = 0,
		farbe = Color3.fromRGB(190, 145, 95), groesse = Vector3.new(2.2, 1.7, 2.2) },
	{ name = "Heavy Truck", ware = "Electronics", item = "Electronics", pakete = 4, lohn = 230, bonus = 200, ab = 5,
		farbe = Color3.fromRGB(70, 90, 120), groesse = Vector3.new(2.6, 2.0, 1.6) },
	{ name = "Mega Truck", ware = "Designer furniture", item = "Furniture", pakete = 4, lohn = 360, bonus = 400, ab = 15,
		farbe = Color3.fromRGB(150, 110, 70), groesse = Vector3.new(3.0, 2.2, 2.0) },
}
local PIZZA = { name = "Delivery car", ware = "Pizza", item = "Pizza", pakete = 3, lohn = 60, bonus = 40 }
local TAXI = { name = "Taxi", ware = "Passengers", item = "Passenger", pakete = 3, lohn = 0, bonus = 60 }
local TAXI_EINFAHRT = Vector3.new(374, 0, -14)
local TAXI_MITTE = Vector3.new(374, 0, -50)
local service = workspace.Karte:WaitForChild("Service", 10)
local servicestation = service and service:FindFirstChild("Servicestation")
local taxiBuchtOrdner = servicestation and servicestation:FindFirstChild("TaxiBuchten")
local DEPOT_EINFAHRT = Vector3.new(600, 0, 300)
local DEPOT_MITTE = Vector3.new(600, 0, 386)
local PIZZA_EINFAHRT = Vector3.new(375, 0, 16)
local PIZZA_MITTE = Vector3.new(375, 0, 60)
local LKW_FARBE = Color3.fromRGB(230, 120, 30)
local PIZZA_FARBE = Color3.fromRGB(200, 35, 30)
local pizzeria = workspace.Karte.Vorstadt:WaitForChild("Pizzeria", 10)
local pizzaBuchtOrdner = pizzeria and pizzeria:WaitForChild("PizzaBuchten", 10)

local function lkwStufe(d)
	local stufe = 1
	for i, s in LKW_STUFEN do
		if (d.lkwFahrten or 0) >= s.ab then stufe = i end
	end
	return stufe
end

-- customers: houses outside the city ...
local function hausListe(mitte, radius)
	local liste = {}
	local vororte = workspace.Karte:FindFirstChild("Vororte")
	if not vororte then return liste end
	for _, haus in vororte:GetChildren() do
		local tuer = haus:FindFirstChild("Tuer")
		if haus:IsA("Model") and tuer and tuer:IsA("BasePart") then
			local vorne = -tuer.CFrame.LookVector
			vorne = Vector3.new(vorne.X, 0, vorne.Z)
			if vorne.Magnitude > 0.5 then
				vorne = vorne.Unit
				local tuerPos = Vector3.new(tuer.Position.X, 0, tuer.Position.Z)
				local strasse = haus:GetAttribute("Strasse")
				strasse = strasse and Vector3.new(strasse.X, 0, strasse.Z) or (tuerPos + vorne * 23.9)
				if (strasse - mitte).Magnitude < radius then
					table.insert(liste, { tuer = tuerPos, vorne = vorne, strasse = strasse, boden = 0.2 })
				end
			end
		end
	end
	return liste
end

-- ... and shops / flats in the city (customer waits on the sidewalk in front of the entrance)
local function stadtListe()
	local liste = {}
	local gebaeude = workspace.Karte:FindFirstChild("Gebaeude")
	if not gebaeude then return liste end
	for _, g in gebaeude:GetChildren() do
		local eingang, raus = g:GetAttribute("Eingang"), g:GetAttribute("Raus")
		if eingang and raus then
			local k = raus.X > 0 and math.ceil((eingang.X + 312) / 104) or math.floor((eingang.X + 312) / 104)
			local strassenX = -312 + 104 * math.clamp(k, 0, 6)
			table.insert(liste, {
				tuer = Vector3.new(eingang.X, 0, eingang.Z), vorne = raus,
				strasse = Vector3.new(strassenX, 0, eingang.Z), boden = eingang.Y, stadt = true,
			})
		end
	end
	return liste
end

local function kundenWaehlen(kandidaten, anzahl, start)
	mischen(kandidaten)
	local gewaehlt = {}
	for _, h in kandidaten do
		local weitWeg = true
		for _, g in gewaehlt do
			if (g.strasse - h.strasse).Magnitude < 70 then weitWeg = false end
		end
		if weitWeg then table.insert(gewaehlt, h) end
		if #gewaehlt >= anzahl then break end
	end
	-- always drive to the nearest customer next
	local sortiert, von = {}, start
	while #gewaehlt > 0 do
		local besteI, besteD = 1, math.huge
		for i, h in gewaehlt do
			local d = (h.strasse - von).Magnitude
			if d < besteD then besteI, besteD = i, d end
		end
		local h = table.remove(gewaehlt, besteI)
		table.insert(sortiert, h)
		von = h.strasse
	end
	return sortiert
end

local function wareTool(cfg)
	local tool = Instance.new("Tool")
	tool.Name = cfg.item
	tool.CanBeDropped = false
	tool.ToolTip = "Bring it to the customer at the door"
	tool:SetAttribute("Lieferung", true)
	local pizza = cfg.item == "Pizza"
	tool.Grip = pizza and CFrame.new(0, 0, -0.4) or CFrame.new(0, -0.2, 0.2)
	local karton = Instance.new("Part")
	karton.Name = "Handle"
	karton.Size = pizza and Vector3.new(2.4, 0.35, 2.4) or (cfg.groesse or Vector3.new(2.2, 1.7, 2.2))
	karton.Color = pizza and Color3.fromRGB(235, 225, 205) or (cfg.farbe or Color3.fromRGB(190, 145, 95))
	karton.Material = Enum.Material.Cardboard
	karton.CanCollide = false
	karton.Massless = true
	karton.Parent = tool
	local band = Instance.new("Part")
	band.Name = "Aufdruck"
	band.Size = pizza and Vector3.new(1.4, 0.37, 1.4) or Vector3.new(0.45, karton.Size.Y + 0.04, karton.Size.Z + 0.04)
	band.CFrame = karton.CFrame
	band.Color = pizza and Color3.fromRGB(200, 35, 30) or Color3.fromRGB(225, 200, 150)
	band.CanCollide = false
	band.Massless = true
	band.Parent = tool
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = karton, band
	w.Parent = band
	return tool
end

local function wareEntfernen(p)
	for _, ort in { p:FindFirstChild("Backpack"), p.Character } do
		if ort then
			for _, t in ort:GetChildren() do
				if t:IsA("Tool") and t:GetAttribute("Lieferung") then t:Destroy() end
			end
		end
	end
end

local function hatWare(p)
	local function suche(ort)
		if not ort then return false end
		for _, t in ort:GetChildren() do
			if t:IsA("Tool") and t:GetAttribute("Lieferung") then return true end
		end
		return false
	end
	return suche(p.Character), suche(p:FindFirstChild("Backpack"))
end

local function sprechblase(figur, text)
	local kopf = figur:FindFirstChild("Head")
	if not kopf then return end
	local alt = kopf:FindFirstChild("Sprechblase")
	if alt then alt:Destroy() end
	local bb = Instance.new("BillboardGui")
	bb.Name = "Sprechblase"
	bb.Size = UDim2.fromOffset(200, 46)
	bb.StudsOffset = Vector3.new(0, 2.6, 0)
	bb.MaxDistance = 70
	bb.Parent = kopf
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundColor3 = Color3.new(1, 1, 1)
	l.Font = Enum.Font.GothamBold
	l.TextScaled = true
	l.TextColor3 = Color3.fromRGB(30, 30, 40)
	l.Text = text
	l.Parent = bb
	Instance.new("UICorner", l)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 4), UDim.new(0, 4)
	pad.Parent = l
end

local function jobZiel(p, job)
	local cfg = job.cfg
	local info = {
		typ = "ziel", sprecher = job.art == "pizza" and "Luigi" or "Dispatcher", route = job.route,
		status = ("%s: %d/%d"):format(cfg.ware, job.geliefert, #job.stopps),
	}
	if job.art == "taxi" then
		info.sprecher = "Taxi dispatch"
		info.status = ("Passengers: %d/%d"):format(job.geliefert, #job.stopps)
	end
	if job.art == "taxi" and (job.phase == "fahren" or job.phase == "einsteigen" or job.phase == "fahrgast") then
		local h = job.stopps[job.index]
		local ziel = job.phase == "fahrgast" and h.ziel or h
		info.nr, info.gesamt = job.index, #job.stopps
		if job.phase ~= "einsteigen" then
			info.pos = ziel.strasse
			info.richtung = Vector3.new(-ziel.vorne.Z, 0, ziel.vorne.X)
			info.breite = ziel.stadt and 28 or 24
		end
		info.haus = ziel.tuer + Vector3.new(0, ziel.boden, 0)
		info.symbol = job.phase == "fahrgast" and "🏁" or "🙋"
		info.route = { { job.stopps[job.index].strasse.X, job.stopps[job.index].strasse.Z }, { h.ziel.strasse.X, h.ziel.strasse.Z } }
		info.nr = job.phase == "fahrgast" and 2 or 1
		info.gesamt = 2
		info.text = job.phase == "fahren" and ("Pick up the passenger waiting at the 🙋 marker and stop on the road. (%d/%d)"):format(job.index, #job.stopps)
			or job.phase == "einsteigen" and "Wait until the passenger has got in..."
			or "Drive your passenger to the 🏁 destination. Drive smoothly – fast and careful drivers get a tip!"
	elseif job.phase == "fahren" then
		local h = job.stopps[job.index]
		info.nr, info.gesamt = job.index, #job.stopps
		info.pos = h.strasse
		info.richtung = Vector3.new(-h.vorne.Z, 0, h.vorne.X) -- along the road
		info.breite = h.stadt and 28 or 24
		info.haus = h.tuer + Vector3.new(0, h.boden, 0)
		info.text = ("Drive to the customer (%s marker) and stop on the road in front. (%d/%d)"):format(job.art == "pizza" and "🍕" or "📦", job.index, #job.stopps)
	elseif job.phase == "abladen" then
		local h = job.stopps[job.index]
		info.nr, info.gesamt = job.index, #job.stopps
		info.haus = h.tuer + Vector3.new(0, h.boden, 0)
		info.text = ("Get out, take the %s from the back of the %s (E) and hand it to the customer at the door."):format(cfg.item:lower(), job.art == "pizza" and "car" or "truck")
	elseif job.phase == "zurueck" then
		info.nr, info.gesamt = #job.route, #job.route
		info.pos, info.richtung, info.breite = job.einfahrt, Vector3.new(0, 0, 1), 22
		info.text = job.art == "pizza" and "All pizzas delivered! Drive back to Pizza Rapido."
			or job.art == "taxi" and "Shift over! Drive the taxi back to the taxi stand at the service station."
			or "All deliveries done! Drive back to the Parcel Express depot."
	else -- parking
		info.nr, info.gesamt = #job.route, #job.route
		info.text = ("Park the %s in a free bay and stop completely."):format(job.art == "lkw" and "truck" or (job.art == "taxi" and "taxi" or "car"))
		info.park = {}
		for _, b in job.buchten:GetChildren() do
			table.insert(info.park, { cf = b.CFrame, groesse = b.Size })
		end
	end
	fahrEvent:FireClient(p, info)
end

local function kundeWeg(job)
	if job.kunde then
		local k = job.kunde
		job.kunde = nil
		task.delay(2.5, function() k:Destroy() end)
	end
end

local function jobBeenden(p, erfolg, text)
	local job = jobs[p]
	if not job then return end
	jobs[p] = nil
	if job.kunde then job.kunde:Destroy() job.kunde = nil end
	if job.fahrgast then job.fahrgast:Destroy() job.fahrgast = nil end
	if p.Parent then wareEntfernen(p) end
	local d = daten[p]
	local aufstieg
	if erfolg and d then
		geldGeben(p, job.cfg.bonus, "Job bonus")
		xpGeben(p, 40, "Job complete")
		Missionen.fortschritt(p, "jobs", 1)
		job.verdient += job.cfg.bonus
		if job.art == "lkw" then
			local vorher = lkwStufe(d)
			d.lkwFahrten = (d.lkwFahrten or 0) + 1
			local nachher = lkwStufe(d)
			if nachher > vorher then aufstieg = LKW_STUFEN[nachher] end
		else
			d.pizzaFahrten = (d.pizzaFahrten or 0) + 1
		end
		geaendert(p)
	end
	if p.Parent then
		local zusatz = aufstieg and ("\n\n⭐ LEVEL UP! You unlocked the <b>%s</b> (%s, %d coins per delivery)."):format(aufstieg.name, aufstieg.ware, aufstieg.lohn) or ""
		fahrEvent:FireClient(p, { typ = "jobende", erfolg = erfolg, text = text .. zusatz, verdient = job.verdient, geliefert = job.geliefert })
	end
	task.delay(erfolg and 3 or 0.5, function()
		aussteigen(job.sitz)
		if job.model then job.model:Destroy() end
	end)
end

local function wareAbgeben(p, job, h, wer)
	if wer ~= p or jobs[p] ~= job or job.phase ~= "abladen" or job.stopps[job.index] ~= h then return end
	local inHand, imRucksack = hatWare(p)
	if not inHand then
		local text = imRucksack and ("Hold the %s in your hand first (select it in your inventory)."):format(job.cfg.item:lower())
			or ("Take the %s from the back of your vehicle first (E at the back)."):format(job.cfg.item:lower())
		fahrEvent:FireClient(p, { typ = "hinweis", text = text })
		return
	end
	wareEntfernen(p)
	local d = daten[p]
	if d then d.lieferungen = (d.lieferungen or 0) + 1 end
	job.geliefert += 1
	job.verdient += job.cfg.lohn
	geldGeben(p, job.cfg.lohn, job.art == "pizza" and "Pizza delivered" or "Delivery complete")
	xpGeben(p, job.art == "pizza" and 15 or 25, "Delivery")
	Missionen.fortschritt(p, "lieferung", 1)
	if job.kunde then
		local danke = job.art == "pizza" and { "Mamma mia, smells great! 🍕", "Finally, I'm starving!", "Thanks, keep the change!" }
			or { "Thank you so much! 😊", "Perfect, just in time!", "Great, thanks a lot!" }
		sprechblase(job.kunde, danke[math.random(#danke)])
		kundeWeg(job)
	end
	job.klappe.Enabled = false
	job.index += 1
	job.phase = job.index > #job.stopps and "zurueck" or "fahren"
	jobZiel(p, job)
end

local function kundeErscheinen(p, job, h)
	local haut = { Color3.fromRGB(234, 192, 160), Color3.fromRGB(198, 145, 105), Color3.fromRGB(141, 94, 60), Color3.fromRGB(255, 220, 190) }
	local kleidung = { Color3.fromRGB(200, 60, 60), Color3.fromRGB(60, 110, 200), Color3.fromRGB(240, 200, 60), Color3.fromRGB(60, 160, 90), Color3.fromRGB(150, 80, 170) }
	local figur, hum = npc("Kunde", "Customer", haut[math.random(#haut)], kleidung[math.random(#kleidung)], Color3.fromRGB(50, 55, 70))
	if not figur then return end
	if jobs[p] ~= job then figur:Destroy() return end
	local wurzel = figur:WaitForChild("HumanoidRootPart")
	wurzel.Anchored = true
	local hoehe = h.boden + hum.HipHeight + wurzel.Size.Y / 2
	local stand = h.tuer + h.vorne * 2.4 + Vector3.new(0, hoehe, 0)
	figur:PivotTo(CFrame.lookAt(stand, stand + h.vorne))
	figur.Parent = workspace
	job.kunde = figur
	local idle = animation(hum, "stehen")
	if idle then idle:Play() end
	sprechblase(figur, job.art == "pizza" and "Is that my pizza? 🍕" or ("Is that my %s? 📦"):format(job.cfg.item:lower()))
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = "Hand over " .. job.cfg.item:lower()
	pp.ObjectText = "Customer"
	pp.HoldDuration = 0.3
	pp.MaxActivationDistance = 9
	pp.RequiresLineOfSight = false
	pp.Parent = wurzel
	pp.Triggered:Connect(function(wer)
		wareAbgeben(p, job, h, wer)
	end)
end

local function freiePizzaBucht()
	if not pizzaBuchtOrdner then return nil end
	for _, b in pizzaBuchtOrdner:GetChildren() do
		if buchtFrei(b) then
			return CFrame.new(b.Position.X, b.Position.Y + 0.25, b.Position.Z + 1)
		end
	end
	return nil
end

local function jobStarten(p, art, wunschStufe)
	local d = daten[p]
	if jobs[p] then return { fehler = "You already have a delivery job." } end
	if lektionen[p] then return { fehler = "Finish your driving lesson first." } end
	local cfg, stufe, modell, sitz, chassis, klappe, cf, stopps, buchten, einfahrt, beifahrer
	if art == "taxi" then
		if not d.fuehrerschein then
			return { fehler = "You need a driver's license (class B) to drive a taxi." }
		end
		cfg = TAXI
		for _, b in (taxiBuchtOrdner and taxiBuchtOrdner:GetChildren() or {}) do
			if buchtFrei(b) then cf = CFrame.new(b.Position + Vector3.new(0, 0.25, 0)) * b.CFrame.Rotation break end
		end
		if not cf then return { fehler = "All taxis are out. Please wait a moment." } end
		local kandidaten = hausListe(TAXI_MITTE, 700)
		for _, h in stadtListe() do table.insert(kandidaten, h) end
		stopps = kundenWaehlen(kandidaten, cfg.pakete, TAXI_EINFAHRT)
		-- every passenger wants to go somewhere else (at least 250 studs away)
		for _, h in stopps do
			mischen(kandidaten)
			for _, z in kandidaten do
				if (z.strasse - h.strasse).Magnitude > 250 and (z.strasse - h.strasse).Magnitude < 900 then h.ziel = z break end
			end
			h.ziel = h.ziel or kandidaten[1]
		end
		modell, sitz, beifahrer, chassis = Auto.bauenPrivat(cf, "limousine", Color3.fromRGB(250, 200, 30), "TAXI " .. (p.UserId % 900 + 100))
		modell.Name = "Taxi_" .. p.Name
		-- roof sign
		local schild = Instance.new("Part")
		schild.Name = "Taxischild"
		schild.Size = Vector3.new(2.6, 0.9, 1.2)
		schild.CFrame = chassis.CFrame * CFrame.new(0, 4.6, 0.8)
		schild.Color = Color3.fromRGB(255, 240, 160)
		schild.Material = Enum.Material.Neon
		schild.CanCollide = false
		schild.Massless = true
		schild.Parent = modell
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = chassis, schild
		w.Parent = schild
		for _, seite in { Enum.NormalId.Front, Enum.NormalId.Back } do
			local g = Instance.new("SurfaceGui")
			g.Face = seite
			g.Parent = schild
			local l = Instance.new("TextLabel")
			l.Size = UDim2.fromScale(1, 1)
			l.BackgroundTransparency = 1
			l.Text = "TAXI"
			l.Font = Enum.Font.GothamBlack
			l.TextScaled = true
			l.TextColor3 = Color3.fromRGB(20, 20, 20)
			l.Parent = g
		end
		klappe = chassis
		buchten, einfahrt = taxiBuchtOrdner, TAXI_EINFAHRT
	elseif art == "pizza" then
		if not d.fuehrerschein then
			return { fehler = "You need a driver's license (class B) to deliver pizza. Get it at the driving school!" }
		end
		cfg = PIZZA
		cf = freiePizzaBucht()
		if not cf then return { fehler = "All delivery cars are out. Please wait a moment." } end
		local kandidaten = hausListe(PIZZA_MITTE, 650)
		local stadt = stadtListe()
		mischen(stadt)
		for i = 1, math.min(#stadt, math.max(6, #kandidaten)) do table.insert(kandidaten, stadt[i]) end
		stopps = kundenWaehlen(kandidaten, cfg.pakete, PIZZA_EINFAHRT)
		modell, sitz, _, chassis = Auto.bauen(cf, PIZZA_FARBE, "🍕 PIZZA RAPIDO\nDELIVERY")
		modell.Name = "Pizza_Auto_" .. p.Name
		klappe = modell:FindFirstChild("Kofferraumdeckel") or chassis
		buchten, einfahrt = pizzaBuchtOrdner, PIZZA_EINFAHRT
	else
		if not d.lkwFuehrerschein then
			return { fehler = "You need a truck license (class C) for this job. Ask Anna at the driving school!" }
		end
		local maxStufe = lkwStufe(d)
		stufe = math.clamp(tonumber(wunschStufe) or maxStufe, 1, maxStufe)
		cfg = LKW_STUFEN[stufe]
		cf = freieLkwBucht()
		if not cf then return { fehler = "All truck bays are taken. Please wait a moment." } end
		stopps = kundenWaehlen(hausListe(DEPOT_MITTE, 800), cfg.pakete, DEPOT_EINFAHRT)
		modell, sitz, _, chassis, _, klappe = Auto.bauenLkw(cf, LKW_FARBE, "PARCEL EXPRESS", stufe)
		modell.Name = "Paket_Lkw_" .. p.Name
		buchten, einfahrt = lkwBuchtOrdner, DEPOT_EINFAHRT
	end
	if #stopps == 0 then
		modell:Destroy()
		return { fehler = "No customers found." }
	end
	modell.Parent = workspace

	local route = {}
	for _, h in stopps do table.insert(route, { h.strasse.X, h.strasse.Z }) end
	table.insert(route, { einfahrt.X, einfahrt.Z + 30 })
	local job = {
		art = art, stufe = stufe, cfg = cfg, model = modell, sitz = sitz, chassis = chassis, stopps = stopps, route = route,
		index = 1, phase = "fahren", geliefert = 0, verdient = 0, gestartet = false, buchten = buchten, einfahrt = einfahrt,
		blinkTeile = blinkTeileSuchen(modell), hinweisZeit = 0, beifahrer = beifahrer,
	}
	jobs[p] = job

	-- back of the vehicle: take the goods
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = "Take " .. cfg.item:lower()
	pp.ObjectText = art == "pizza" and "Delivery car" or cfg.name
	pp.HoldDuration = 0.4
	pp.MaxActivationDistance = 10
	pp.RequiresLineOfSight = false
	pp.Enabled = false
	pp.Parent = klappe
	job.klappe = pp
	pp.Triggered:Connect(function(wer)
		if wer ~= p or jobs[p] ~= job or job.phase ~= "abladen" then return end
		local inHand, imRucksack = hatWare(p)
		if inHand or imRucksack then return end
		local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		if not hum or hum.SeatPart then return end
		local tool = wareTool(cfg)
		tool.Parent = p:FindFirstChild("Backpack") or p.Character
		hum:EquipTool(tool)
		fahrEvent:FireClient(p, { typ = "hinweis", text = ("Now bring the %s to the customer at the door!"):format(cfg.item:lower()), farbe = "gruen" })
	end)

	einsteigPrompt(p, sitz, art == "pizza" and "Pizza delivery car" or cfg.name)
	sitz:GetPropertyChangedSignal("Occupant"):Connect(function()
		if jobs[p] ~= job then return end
		local hum = sitz.Occupant
		if not hum then return end
		if Players:GetPlayerFromCharacter(hum.Parent) ~= p then
			aussteigen(sitz)
			return
		end
		pcall(function() chassis:SetNetworkOwner(p) end)
		if not job.gestartet then
			job.gestartet = true
			fahrEvent:FireClient(p, {
				typ = "start", titel = art == "pizza" and "Pizza Rapido delivery" or (art == "taxi" and "Taxi shift" or ("Parcel Express – " .. cfg.name)), sprecher = art == "pizza" and "Luigi" or (art == "taxi" and "Taxi dispatch" or "Dispatcher"),
				text = art == "taxi" and ("Drive %d passengers. The fare depends on the distance, fast and smooth rides get a tip. %d coin bonus at the end."):format(#stopps, cfg.bonus)
					or ("Deliver %d × %s. You get %d coins each and a %d coin bonus when you bring the vehicle back."):format(#stopps, cfg.ware, cfg.lohn, cfg.bonus),
				status = ("%s: 0/%d"):format(cfg.ware, #stopps),
			})
			task.delay(4, function()
				if jobs[p] == job then jobZiel(p, job) end
			end)
		end
	end)
	fahrEvent:FireClient(p, { typ = "weg", pos = cf.Position })
	if art == "pizza" then
		return { text = ("Your delivery car is ready on the parking lot! %d pizzas are in the back. Press E at the driver's door to get in."):format(#stopps) }
	elseif art == "taxi" then
		return { text = ("Your taxi is waiting at the taxi stand. %d passengers are waiting for you today. Press E at the driver's door to get in."):format(#stopps) }
	end
	return { text = ("Your %s is ready in the bay! %d × %s are loaded. Press E at the driver's door to get in."):format(cfg.name, #stopps, cfg.ware) }
end

-- taxi: the passenger walks out, gets in next to you, and leaves at the destination
local function fahrgastEinsteigen(p, job, h)
	local haut = { Color3.fromRGB(234, 192, 160), Color3.fromRGB(198, 145, 105), Color3.fromRGB(141, 94, 60), Color3.fromRGB(255, 220, 190) }
	local kleidung = { Color3.fromRGB(200, 60, 60), Color3.fromRGB(60, 110, 200), Color3.fromRGB(240, 200, 60), Color3.fromRGB(60, 160, 90), Color3.fromRGB(40, 40, 45) }
	local figur, hum = npc("Fahrgast", "Passenger", haut[math.random(#haut)], kleidung[math.random(#kleidung)], kleidung[math.random(#kleidung)])
	if not figur then return end
	if jobs[p] ~= job then figur:Destroy() return end
	local wurzel = figur:WaitForChild("HumanoidRootPart")
	wurzel.Anchored = true
	local stand = h.tuer + h.vorne * 2.4 + Vector3.new(0, h.boden + hum.HipHeight + wurzel.Size.Y / 2, 0)
	figur:PivotTo(CFrame.lookAt(stand, stand + h.vorne))
	figur.Parent = workspace
	job.fahrgast = figur
	sprechblase(figur, "Taxi! 🙋")
	task.wait(2.5)
	if jobs[p] ~= job or not job.beifahrer or not job.beifahrer.Parent then figur:Destroy() return end
	for _, t in figur:GetDescendants() do
		if t:IsA("BasePart") then
			t.Massless = true
			t.CanCollide = false
		end
	end
	wurzel.Anchored = false
	figur:PivotTo(job.beifahrer.CFrame + Vector3.new(0, 3, 0))
	figur.Parent = job.model
	hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	job.beifahrer:Sit(hum)
	local sitzt = animation(hum, "sitzen")
	if sitzt then sitzt:Play() end
	local orte = { "the train station", "my office", "the city center", "my friend's house", "the gym", "home" }
	sprechblase(figur, "To " .. orte[math.random(#orte)] .. ", please!")
	job.phase = "fahrgast"
	job.fahrtStart = os.clock()
	jobZiel(p, job)
end

local function fahrgastAussteigen(p, job, h)
	local strecke = (h.strasse - h.ziel.strasse).Magnitude
	local fahrpreis = 30 + math.floor(strecke * 0.06)
	local ideal = strecke / 28 * 1.7 -- seconds a good driver needs
	local trinkgeld = (os.clock() - (job.fahrtStart or 0)) < ideal and math.floor(fahrpreis * 0.25) or 0
	job.geliefert += 1
	job.verdient += fahrpreis + trinkgeld
	geldGeben(p, fahrpreis + trinkgeld, trinkgeld > 0 and ("Taxi fare + %d tip"):format(trinkgeld) or "Taxi fare")
	xpGeben(p, 20, "Passenger delivered")
	if Missionen then Missionen.fortschritt(p, "taxi", 1) end
	if daten[p] then daten[p].taxiFahrten = (daten[p].taxiFahrten or 0) + 1 end
	local figur = job.fahrgast
	job.fahrgast = nil
	if figur then
		sprechblase(figur, trinkgeld > 0 and "Wow, that was quick! Keep the change 💛" or "Thanks for the ride!")
		aussteigen(job.beifahrer)
		task.delay(2.5, function() figur:Destroy() end)
	end
	job.index += 1
	job.phase = job.index > #job.stopps and "zurueck" or "fahren"
	jobZiel(p, job)
end

local function jobInfo(d)
	local stufen = {}
	for i, s in LKW_STUFEN do
		table.insert(stufen, { nr = i, name = s.name, ware = s.ware, pakete = s.pakete, lohn = s.lohn, bonus = s.bonus, ab = s.ab, frei = (d.lkwFahrten or 0) >= s.ab })
	end
	return { stufen = stufen, fahrten = d.lkwFahrten or 0, pizza = { pakete = PIZZA.pakete, lohn = PIZZA.lohn, bonus = PIZZA.bonus }, pizzaFahrten = d.pizzaFahrten or 0 }
end

-- checks the delivery jobs a few times per second
local jobTakt = 0
RunService.Heartbeat:Connect(function(dt)
	jobTakt += dt
	if jobTakt < 0.15 then return end
	jobTakt = 0
	for p, job in jobs do
		if not p.Parent or not job.model.Parent or not job.chassis.Parent then
			jobBeenden(p, false, "The job was cancelled.")
			continue
		end
		local pos = job.chassis.Position
		local tempo = job.chassis.AssemblyLinearVelocity.Magnitude
		local h = job.stopps[job.index]
		if job.art == "taxi" and (job.phase == "fahren" or job.phase == "fahrgast" or job.phase == "einsteigen") then
			if job.phase ~= "einsteigen" then
				local ziel = job.phase == "fahrgast" and h.ziel or h
				local abstand = Vector3.new(pos.X - ziel.strasse.X, 0, pos.Z - ziel.strasse.Z).Magnitude
				if abstand < 26 and tempo < 2 then
					if job.phase == "fahren" then
						job.phase = "einsteigen"
						jobZiel(p, job)
						task.spawn(fahrgastEinsteigen, p, job, h)
					else
						fahrgastAussteigen(p, job, h)
					end
				end
			end
			continue
		end
		if job.phase == "fahren" then
			local abstand = Vector3.new(pos.X - h.strasse.X, 0, pos.Z - h.strasse.Z).Magnitude
			if abstand < 26 then
				if tempo < 2 then
					job.phase = "abladen"
					job.klappe.Enabled = true
					task.spawn(kundeErscheinen, p, job, h)
					jobZiel(p, job)
				elseif os.clock() - job.hinweisZeit > 6 then
					job.hinweisZeit = os.clock()
					fahrEvent:FireClient(p, { typ = "hinweis", text = "Stop here.", farbe = "gruen" })
				end
			end
		elseif job.phase == "abladen" then
			-- drove away without delivering: back to driving
			local abstand = Vector3.new(pos.X - h.strasse.X, 0, pos.Z - h.strasse.Z).Magnitude
			if abstand > 40 then
				job.phase = "fahren"
				job.klappe.Enabled = false
				wareEntfernen(p)
				if job.kunde then job.kunde:Destroy() job.kunde = nil end
				jobZiel(p, job)
			end
		elseif job.phase == "zurueck" then
			local daheim
			if job.art == "pizza" then
				daheim = Regeln.imPizzeria(pos) and pos.Z > 30
			elseif job.art == "taxi" then
				daheim = pos.X > 336 and pos.X < 412 and pos.Z > -96 and pos.Z < -12
			else
				daheim = Regeln.imDepot(pos) and pos.Z > 335
			end
			if Regeln.durchTor(pos, job.einfahrt, Vector3.new(0, 0, 1), 22, 16) or daheim then
				job.phase = "parken"
				jobZiel(p, job)
			end
		elseif job.phase == "parken" and tempo < 1.5 then
			for _, b in job.buchten:GetChildren() do
				local lokal = b.CFrame:PointToObjectSpace(pos)
				local drin = math.abs(lokal.X) < b.Size.X / 2 - 1.5 and math.abs(lokal.Z) < b.Size.Z / 2 + 3
				local gerade = math.abs(job.chassis.CFrame.LookVector:Dot(b.CFrame.LookVector)) > 0.9
				if drin and gerade then
					jobBeenden(p, true, job.art == "pizza" and "Great work! All pizzas delivered and the car is back."
						or job.art == "taxi" and "Great shift! All passengers delivered and the taxi is back at the stand."
						or "Great work! All deliveries done and the truck is back in the depot.")
					break
				end
			end
		end
	end
end)

-- Job givers: Tom at the depot, Luigi at the pizzeria
local function jobGeber(platz, name, anzeige, oberteil, kappenFarbe, eltern, oeffnenArt, blick)
	local figur, hum = npc(name, anzeige, Color3.fromRGB(205, 160, 125), oberteil, Color3.fromRGB(45, 50, 65), "uniform")
	if not figur then return end
	local wurzel = figur:WaitForChild("HumanoidRootPart")
	wurzel.Anchored = true
	local stand = Vector3.new(platz.Position.X, 0.2 + hum.HipHeight + wurzel.Size.Y / 2, platz.Position.Z)
	figur:PivotTo(CFrame.lookAt(stand, stand + blick))
	figur.Parent = eltern
	local idle = animation(hum, "stehen")
	if idle then idle:Play() end
	local kopf = figur:FindFirstChild("Head")
	if kopf then
		local kappe = Instance.new("Part")
		kappe.Name = "Kappe"
		kappe.Shape = Enum.PartType.Cylinder
		kappe.Size = Vector3.new(0.5, 1.35, 1.35)
		kappe.Color = kappenFarbe
		kappe.CanCollide = false
		kappe.Massless = true
		kappe.CFrame = kopf.CFrame * CFrame.new(0, 0.55, 0) * CFrame.Angles(0, 0, math.rad(90))
		kappe.Parent = figur
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = kopf, kappe
		w.Parent = kappe
	end
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = "Talk"
	pp.ObjectText = anzeige
	pp.HoldDuration = 0
	pp.MaxActivationDistance = 10
	pp.RequiresLineOfSight = false
	pp.Parent = wurzel
	pp.Triggered:Connect(function(p)
		oeffnen:FireClient(p, oeffnenArt)
	end)
end
task.spawn(function()
	local platz = depot:WaitForChild("DisponentPlatz", 10)
	if platz then
		jobGeber(platz, "Disponent", "Tom (Dispatcher)", LKW_FARBE, LKW_FARBE, depot, "job", Vector3.new(0, 0, -1))
	else
		warn("License system: DisponentPlatz not found (run the new map generator)")
	end
end)
task.spawn(function()
	local platz = pizzeria and pizzeria:WaitForChild("PizzaPlatz", 10)
	if platz then
		jobGeber(platz, "Pizzabaecker", "Luigi (Pizza Rapido)", Color3.fromRGB(245, 245, 245), Color3.fromRGB(255, 255, 255), pizzeria, "pizza", Vector3.new(0, 0, -1))
	else
		warn("License system: PizzaPlatz not found (run the new map generator)")
	end
end)
-- Ben, the mechanic, and the taxi stand at the service station
task.spawn(function()
	local platz = servicestation and servicestation:FindFirstChild("MechanikerPlatz")
	if platz then
		jobGeber(platz, "Mechaniker", "Ben (Mechanic)", Color3.fromRGB(40, 60, 110), Color3.fromRGB(230, 120, 30), servicestation, "werkstatt", Vector3.new(0, 0, 1))
	end
	local schild = servicestation and servicestation:FindFirstChild("Taxischild")
	if schild then
		local pp = Instance.new("ProximityPrompt")
		pp.ActionText = "Drive a taxi"
		pp.ObjectText = "Taxi stand"
		pp.HoldDuration = 0
		pp.MaxActivationDistance = 12
		pp.RequiresLineOfSight = false
		pp.Parent = schild
		pp.Triggered:Connect(function(p) oeffnen:FireClient(p, "taxi") end)
	end
end)

-- ---------------------------------------------------------------
-- Villas: buy them with Drive Coins, only owners can open the front door
-- ---------------------------------------------------------------
local villenOrdner = workspace.Karte:FindFirstChild("Villen")
local villaSchilder = {}

local function villaBesitzer(id)
	local namen = {}
	for _, p in Players:GetPlayers() do
		local d = daten[p]
		if d and table.find(d.villen or {}, id) then table.insert(namen, p.DisplayName) end
	end
	return namen
end

local function villenSchilderAktualisieren()
	for id, schild in villaSchilder do
		local villa = schild:FindFirstAncestorOfClass("Model")
		local namen = villaBesitzer(id)
		local text
		if #namen > 0 then
			text = "HOME OF\n" .. table.concat(namen, " & ")
		else
			text = ("FOR SALE\n%s\n%d coins"):format(villa:GetAttribute("VillaName") or id, villa:GetAttribute("Preis") or 0)
		end
		for _, g in schild:GetChildren() do
			local l = g:IsA("SurfaceGui") and g:FindFirstChildOfClass("TextLabel")
			if l then
				l.Text = text
				l.TextColor3 = #namen > 0 and Color3.fromRGB(30, 110, 50) or Color3.fromRGB(180, 30, 30)
			end
		end
	end
end
Players.PlayerAdded:Connect(function() task.delay(3, villenSchilderAktualisieren) end)
Players.PlayerRemoving:Connect(function() task.defer(villenSchilderAktualisieren) end)

if villenOrdner then
	for _, villa in villenOrdner:GetChildren() do
		local id = villa.Name
		local schild = villa:FindFirstChild("Verkaufsschild")
		local tuer = villa:FindFirstChild("VillaTuer")
		if schild then
			villaSchilder[id] = schild
			local pp = Instance.new("ProximityPrompt")
			pp.ActionText = "View"
			pp.ObjectText = villa:GetAttribute("VillaName") or id
			pp.HoldDuration = 0
			pp.MaxActivationDistance = 12
			pp.RequiresLineOfSight = false
			pp.Parent = schild
			pp.Triggered:Connect(function(p)
				local d = daten[p]
				if not d then return end
				oeffnen:FireClient(p, "villa", {
					id = id, name = villa:GetAttribute("VillaName") or id, preis = villa:GetAttribute("Preis") or 0,
					geld = d.geld, gehoert = table.find(d.villen or {}, id) ~= nil, besitzer = villaBesitzer(id),
				})
			end)
		end
		if tuer then
			local pp = Instance.new("ProximityPrompt")
			pp.ActionText = "Open door"
			pp.ObjectText = villa:GetAttribute("VillaName") or id
			pp.HoldDuration = 0
			pp.MaxActivationDistance = 9
			pp.RequiresLineOfSight = false
			pp.Parent = tuer
			local offen = false
			pp.Triggered:Connect(function(p)
				local d = daten[p]
				if not d then return end
				if not table.find(d.villen or {}, id) then
					local namen = villaBesitzer(id)
					fahrEvent:FireClient(p, { typ = "hinweis", text = #namen > 0 and ("Locked. This is the home of %s."):format(table.concat(namen, " & ")) or "Locked. This villa is for sale – look at the sign by the street." })
					return
				end
				if offen then return end
				offen = true
				tuer.CanCollide = false
				tuer.Transparency = 0.75
				task.delay(5, function()
					tuer.CanCollide = true
					tuer.Transparency = 0
					offen = false
				end)
			end)
		end
	end
	villenSchilderAktualisieren()
end

local function villaKaufen(p, id)
	local d = daten[p]
	local villa = villenOrdner and villenOrdner:FindFirstChild(tostring(id))
	if not villa then return { fehler = "This villa does not exist." } end
	d.villen = d.villen or {}
	if table.find(d.villen, villa.Name) then return { fehler = "You already own this villa." } end
	local preis = villa:GetAttribute("Preis") or 0
	if d.geld < preis then
		return { fehler = ("You need %d coins, but you only have %d. Earn more with the delivery jobs!"):format(preis, d.geld) }
	end
	table.insert(d.villen, villa.Name)
	geldGeben(p, -preis, "Bought " .. (villa:GetAttribute("VillaName") or "a villa"))
	villenSchilderAktualisieren()
	return { text = ("Congratulations! %s is yours now. 🏡 Only you can open the front door."):format(villa:GetAttribute("VillaName") or "The villa") }
end

-- ---------------------------------------------------------------
-- Police: traffic checkpoints (for you and the NPC traffic) and patrol cars that stop speeders
-- ---------------------------------------------------------------
local KONTROLL_PUNKTE = {
	{ pos = Vector3.new(-450, 0, -5.5), dir = Vector3.new(-1, 0, 0) },   -- country road west
	{ pos = Vector3.new(-300, 0, 605.5), dir = Vector3.new(1, 0, 0) },   -- south ring
	{ pos = Vector3.new(785.5, 0, -250), dir = Vector3.new(0, 0, -1) },  -- east access road
	{ pos = Vector3.new(-785.5, 0, 300), dir = Vector3.new(0, 0, 1) },   -- west access road
	{ pos = Vector3.new(-5.5, 0, 450), dir = Vector3.new(0, 0, 1) },     -- south access to the city
	{ pos = Vector3.new(5.5, 0, -420), dir = Vector3.new(0, 0, -1) },    -- highway access road
}
local STRAFE_TEMPO = 80        -- speeding fine at a checkpoint
local STRAFE_ANHALTEN = 120    -- speeding fine when a patrol stops you
local STRAFE_FLUCHT = 250      -- driving away from the police
local aktuelleKontrolle = nil
local polizei = {}             -- [player] = running police stop
local polizeiPause = {}        -- [player] = no new stop before this time
local blaulichtModelle = {}    -- police models placed by the server (flashing)
local polizeiOrdner = Instance.new("Folder")
polizeiOrdner.Name = "Polizei"
polizeiOrdner.Parent = workspace

local function rechtsVon(d) return Vector3.new(-d.Z, 0, d.X) end
local function flach(v) return Vector3.new(v.X, 0, v.Z) end

local function polizist(cf, eltern)
	local figur, hum = npc("Polizist", "Police Officer", Color3.fromRGB(225, 185, 150), Color3.fromRGB(25, 45, 95), Color3.fromRGB(25, 30, 45), "uniform")
	if not figur then return nil end
	local wurzel = figur:WaitForChild("HumanoidRootPart")
	local kopf = figur:FindFirstChild("Head")
	if kopf then
		local muetze = Instance.new("Part")
		muetze.Name = "Muetze"
		muetze.Size = Vector3.new(1.3, 0.45, 1.4)
		muetze.Color = Color3.fromRGB(25, 45, 95)
		muetze.CanCollide = false
		muetze.Massless = true
		muetze.CFrame = kopf.CFrame * CFrame.new(0, 0.6, -0.05)
		muetze.Parent = figur
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = kopf, muetze
		w.Parent = muetze
	end
	local stand = cf.Position + Vector3.new(0, 0.2 + hum.HipHeight + wurzel.Size.Y / 2, 0)
	figur:PivotTo(CFrame.lookAt(stand, stand + cf.LookVector))
	figur.Parent = eltern
	return figur, hum, wurzel
end

local function polizeiAuto(cf, eltern)
	local m = Verkehr.modell("polizei", 1, 1)
	m:PivotTo(cf + Vector3.new(0, 0.2, 0))
	m.Parent = eltern
	local teile = {}
	for _, t in m:GetChildren() do
		if t.Name == "Blaulicht" then table.insert(teile, t) end
	end
	blaulichtModelle[m] = teile
	return m
end

local function kontrolleAufbauen(punkt, id)
	local k = { id = id, pos = punkt.pos, dir = punkt.dir, geprueft = {} }
	local m = Instance.new("Model")
	m.Name = "Verkehrskontrolle"
	m.Parent = polizeiOrdner
	k.modell = m
	local rechts = rechtsVon(punkt.dir)
	-- patrol car on the edge of the road just after the stop point
	local autoPos = punkt.pos + rechts * 5 + punkt.dir * 14
	polizeiAuto(CFrame.lookAt(autoPos, autoPos + punkt.dir), m)
	-- traffic cones before it
	for i = 1, 4 do
		local p = punkt.pos + rechts * 4.2 - punkt.dir * (4 + i * 7)
		local kegel = Instance.new("Part")
		kegel.Name = "Pylone"
		kegel.Size = Vector3.new(1.2, 2.2, 1.2)
		kegel.Color = Color3.fromRGB(255, 120, 20)
		kegel.Material = Enum.Material.SmoothPlastic
		kegel.Anchored = true
		kegel.CanCollide = false
		kegel.Position = p + Vector3.new(0, 1.3, 0)
		kegel.Parent = m
		local streifen = kegel:Clone()
		streifen.Size = Vector3.new(1.25, 0.4, 1.25)
		streifen.Color = Color3.new(1, 1, 1)
		streifen.Position = p + Vector3.new(0, 1.6, 0)
		streifen.Parent = m
	end
	-- officer on the edge of the lane, facing the oncoming traffic
	local stand = punkt.pos + rechts * 4.5 + punkt.dir * 2
	task.spawn(function()
		local figur, hum, wurzel = polizist(CFrame.lookAt(stand, stand - punkt.dir), m)
		if figur then
			wurzel.Anchored = true
			local idle = animation(hum, "stehen")
			if idle then idle:Play() end
		end
	end)
	return k
end

-- players driving without a valid license for this vehicle are wanted by the police
local function ohneFahrerlaubnis(p, modell)
	local d = daten[p]
	if not d or not modell then return false end
	local st = lektionen[p]
	if st and st.model == modell then return false end -- learner with instructor
	if modell:GetAttribute("Lkw") then return not d.lkwFuehrerschein end
	return not d.fuehrerschein
end
local function gesuchteSpieler()
	local liste = {}
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("Gesucht") then
			local w = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			if w then table.insert(liste, w.Position) end
		end
	end
	return liste
end

-- checkpoints come and go at random places (more often and close to you when you are wanted)
task.spawn(function()
	task.wait(45)
	local letzter
	local zaehler = 0
	while true do
		local nr
		local gesucht = gesuchteSpieler()
		if #gesucht > 0 then
			-- the checkpoint nearest to a wanted driver
			local besterAbstand = math.huge
			for i, punkt in KONTROLL_PUNKTE do
				for _, pos in gesucht do
					local a = (Vector3.new(pos.X, 0, pos.Z) - punkt.pos).Magnitude
					if a < besterAbstand then nr, besterAbstand = i, a end
				end
			end
		else
			repeat nr = math.random(#KONTROLL_PUNKTE) until nr ~= letzter or #KONTROLL_PUNKTE == 1
		end
		letzter = nr
		zaehler += 1
		aktuelleKontrolle = kontrolleAufbauen(KONTROLL_PUNKTE[nr], zaehler)
		task.wait(150)
		local k = aktuelleKontrolle
		aktuelleKontrolle = nil
		task.wait(20) -- let the last stops finish
		if k and k.modell then
			for m in blaulichtModelle do
				if m:IsDescendantOf(k.modell) then blaulichtModelle[m] = nil end
			end
			k.modell:Destroy()
		end
		task.wait(#gesuchteSpieler() > 0 and 15 or 70)
	end
end)

local function blaulichtNpc(f, an)
	if f then verkehrEvent.Parent:SetAttribute("Blaulicht_" .. f.nr, an or nil) end
end

local function polizeiEnde(p, st)
	if polizei[p] ~= st then return end
	polizei[p] = nil
	polizeiPause[p] = os.clock() + 45
	blaulichtNpc(st.f, false)
	if p.Parent then fahrEvent:FireClient(p, { typ = "polizei", phase = "ende" }) end
	if st.modell then
		local m = st.modell
		task.delay(6, function()
			blaulichtModelle[m:FindFirstChild("NPC_polizei") or m] = nil
			for x in blaulichtModelle do
				if x:IsDescendantOf(m) then blaulichtModelle[x] = nil end
			end
			m:Destroy()
		end)
	end
end

local function geflohen(p, st)
	Strafen.eintrag(p, "Fled from the police", Strafen.FLUCHT.geld, Strafen.FLUCHT.punkte)
	local lektion = lektionen[p]
	if lektion then warnung(p, lektion, "You didn't stop for the police! (+3 mistakes)", 3) end
	fahrEvent:FireClient(p, { typ = "hinweis", text = ("You didn't stop for the police! Fine: %d coins."):format(STRAFE_FLUCHT) })
	polizeiEnde(p, st)
end

local function gespraechStarten(p, st)
	st.phase = "gespraech"
	st.gespraechSeit = os.clock()
	oeffnen:FireClient(p, "kontrolle", { grund = st.art, zuSchnell = math.floor(st.zuSchnell or 0) })
end

-- the police officer checks the license (called when the player presses "Show license")
local function kontrolleAntwort(p, zeigen)
	local st = polizei[p]
	local d = daten[p]
	if not st or st.phase ~= "gespraech" or not d then return { fehler = "There is no police check right now." } end
	local zeilen, strafe = {}, 0
	local lektion = lektionen[p]
	local job = jobs[p]
	local fahrzeug = st.chassis and st.chassis.Parent
	if fahrzeug and ohneFahrerlaubnis(p, fahrzeug) then
		-- caught driving without a license: fine, the vehicle is towed away
		strafe += 450
		table.insert(zeilen, "You are driving <b>without a valid license</b>! Fine: 300 coins. Your vehicle is towed away (towing fee 150 coins).")
		task.delay(1.5, function()
			aussteigen(fahrzeug:FindFirstChildOfClass("VehicleSeat"))
			if jobs[p] and jobs[p].chassis == st.chassis then
				jobBeenden(p, false, "Your vehicle was towed away by the police.")
			elseif privatAutos[p] and privatAutos[p].chassis == st.chassis then
				autoWeg(p)
			end
		end)
	elseif not zeigen then
		strafe += 100
		table.insert(zeilen, "You refused to show your license. That's 100 coins.")
	elseif lektion then
		table.insert(zeilen, lektion.pruefung and "A test drive with the examiner? Everything in order – good luck!" or "A learner driver with the instructor – everything in order. Keep practising!")
	elseif job and job.art == "lkw" then
		table.insert(zeilen, "Class C for the truck – everything in order.")
	else
		table.insert(zeilen, "Class B – everything in order.")
	end
	local punkte = 0
	if (st.zuSchnell or 0) > 0 then
		local betrag, p2 = Strafen.tempoStrafe(st.zuSchnell)
		if st.art == "anhalten" then betrag = math.max(betrag, STRAFE_ANHALTEN) end
		strafe += betrag
		punkte += p2
		table.insert(zeilen, ("You were %d km/h too fast. Fine: %d coins%s."):format(math.floor(st.zuSchnell), betrag, p2 > 0 and (" and " .. p2 .. " point" .. (p2 > 1 and "s" or "")) or ""))
	end
	if strafe > 0 then
		Strafen.eintrag(p, st.art == "anhalten" and "Stopped by the police" or "Police checkpoint", strafe, punkte)
	else
		table.insert(zeilen, "Thank you, have a safe trip! 👮")
		xpGeben(p, 15, "Clean police check")
		Missionen.fortschritt(p, "kontrolle", 1)
	end
	task.delay(2, polizeiEnde, p, st)
	return { text = table.concat(zeilen, "\n\n"), strafe = strafe }
end

-- watches all players driving a vehicle
local polizeiTakt = 0
RunService.Heartbeat:Connect(function(dt)
	polizeiTakt += dt
	if polizeiTakt < 0.2 then return end
	polizeiTakt = 0
	for _, p in Players:GetPlayers() do
		local st = polizei[p]
		local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		local sitz = hum and hum.SeatPart
		local chassis = (st and st.chassis) or (sitz and sitz:IsA("VehicleSeat") and sitz.Parent and sitz.Parent:FindFirstChild("Chassis"))
		if not chassis or not chassis.Parent then
			if st then polizeiEnde(p, st) end
			p:SetAttribute("Gesucht", nil)
			p:SetAttribute("GesuchtSeit", nil)
			continue
		end
		local pos = flach(chassis.Position)
		local tempo = chassis.AssemblyLinearVelocity.Magnitude
		local limit = Regeln.tempolimit(pos)
		if tempo > limit + 15 then
			p:SetAttribute("ZuSchnellSeit", p:GetAttribute("ZuSchnellSeit") or os.clock())
		else
			p:SetAttribute("ZuSchnellSeit", nil)
		end
		local fahrzeug = chassis.Parent
		local istFahrer = sitz ~= nil and sitz.Parent == fahrzeug
		if istFahrer and ohneFahrerlaubnis(p, fahrzeug) then
			if not p:GetAttribute("Gesucht") then
				p:SetAttribute("Gesucht", true)
				p:SetAttribute("GesuchtSeit", os.clock())
				fahrEvent:FireClient(p, { typ = "hinweis", text = "🚨 You are driving without a valid license – the police is looking for you!" })
			end
		elseif not istFahrer or not ohneFahrerlaubnis(p, fahrzeug) then
			p:SetAttribute("Gesucht", nil)
			p:SetAttribute("GesuchtSeit", nil)
		end

		if not st then
			if os.clock() < (polizeiPause[p] or 0) then continue end
			local k = aktuelleKontrolle
			if k and not k.geprueft[p] then
				local rel = k.pos - pos
				local entlang = rel:Dot(k.dir)
				if entlang > 0 and entlang < 70 and math.abs(rel:Dot(rechtsVon(k.dir))) < 10 and chassis.CFrame.LookVector:Dot(k.dir) > 0.5 then
					k.geprueft[p] = true
					polizei[p] = { art = "kontrolle", k = k, chassis = chassis, start = os.clock(), zuSchnell = tempo > limit + 10 and (tempo - limit) or 0 }
					fahrEvent:FireClient(p, { typ = "polizei", phase = "halt", text = "🚓 POLICE CHECKPOINT ahead! Slow down and stop next to the officer." })
					continue
				end
			end
			-- wanted: patrols look for you everywhere (a patrol finds you after a short time)
			if p:GetAttribute("Gesucht") then
				local seitGesucht = p:GetAttribute("GesuchtSeit") or os.clock()
				local naechste, naechsteAbstand = nil, math.huge
				for _, f in Verkehr.fahrzeuge or {} do
					local a = (f.pos - pos).Magnitude
					if f.art == "polizei" and a < naechsteAbstand then naechste, naechsteAbstand = f, a end
				end
				if naechsteAbstand < 160 or os.clock() - seitGesucht > 50 then
					polizei[p] = { art = "anhalten", f = naechsteAbstand < 160 and naechste or nil, chassis = chassis, start = os.clock(), zuSchnell = tempo > limit + 10 and (tempo - limit) or 0, gesucht = true }
					blaulichtNpc(polizei[p].f, true)
					fahrEvent:FireClient(p, { typ = "polizei", phase = "anhalten", text = "🚨 POLICE! You are driving without a valid license. Pull over and stop!" })
					continue
				end
			end
			local seit = p:GetAttribute("ZuSchnellSeit")
			if seit and os.clock() - seit > 1.5 and Verkehr.fahrzeuge then
				for _, f in Verkehr.fahrzeuge do
					if f.art == "polizei" and (f.pos - pos).Magnitude < 90 then
						polizei[p] = { art = "anhalten", f = f, chassis = chassis, start = os.clock(), zuSchnell = tempo - limit }
						blaulichtNpc(f, true)
						fahrEvent:FireClient(p, { typ = "polizei", phase = "anhalten", text = ("🚨 POLICE! You were doing %d in a %d zone. Pull over to the right and stop!"):format(math.floor(tempo), limit) })
						break
					end
				end
			end
		elseif st.art == "kontrolle" and st.phase == nil then
			local rel = st.k.pos - pos
			local entlang = rel:Dot(st.k.dir)
			if tempo < 2 and math.abs(entlang) < 24 then
				gespraechStarten(p, st)
			elseif entlang < -25 then
				geflohen(p, st)
			elseif os.clock() - st.start > 60 then
				polizeiEnde(p, st)
			end
		elseif st.art == "anhalten" and st.phase == nil then
			if tempo < 2 then
				-- the patrol car parks behind you, the officer walks to your door
				st.phase = "kommt"
				local m = Instance.new("Model")
				m.Name = "Polizeikontrolle"
				m.Parent = polizeiOrdner
				st.modell = m
				local hinten = chassis.CFrame * CFrame.new(0, 0, (chassis.Parent:GetAttribute("HintenZ") or 8) + 11)
				local autoCf = CFrame.lookAt(flach(hinten.Position), flach(hinten.Position) + flach(chassis.CFrame.LookVector))
				polizeiAuto(autoCf, m)
				task.spawn(function()
					local start = (autoCf * CFrame.new(-5, 0, -2)).Position
					local figur, hum2, wurzel = polizist(CFrame.lookAt(start, start + autoCf.LookVector), m)
					if figur and hum2 then
						local animGehen = animation(hum2, "gehen")
						if animGehen then animGehen:Play() end
						local ziel = (chassis.CFrame * CFrame.new(-6.5, 0, -1)).Position
						hum2:MoveTo(Vector3.new(ziel.X, wurzel.Position.Y, ziel.Z))
						local t0 = os.clock()
						while os.clock() - t0 < 8 and (flach(wurzel.Position) - flach(ziel)).Magnitude > 3 do task.wait(0.2) end
						if animGehen then animGehen:Stop() end
						wurzel.Anchored = true
					end
					if polizei[p] == st then gespraechStarten(p, st) end
				end)
			elseif os.clock() - st.start > 25 then
				geflohen(p, st)
			end
		elseif st.phase == "gespraech" and os.clock() - st.gespraechSeit > 45 then
			kontrolleAntwort(p, false)
		end
	end
	-- flashing lights of the police cars placed by the server
	for _, teile in blaulichtModelle do
		Verkehr.blaulichtZeigen(teile, true)
	end
end)
Players.PlayerRemoving:Connect(function(p)
	local st = polizei[p]
	if st then polizeiEnde(p, st) end
	polizeiPause[p] = nil
end)

-- ---------------------------------------------------------------
-- Car dealership "Velocity Motors": buy cars, then get them anytime from "My Cars"
-- ---------------------------------------------------------------
local autohaus = workspace.Karte.Vorstadt:FindFirstChild("Autohaus")
local AUTOFARBEN_PRIVAT = {
	Color3.fromRGB(200, 25, 30), Color3.fromRGB(25, 70, 170), Color3.fromRGB(240, 240, 240), Color3.fromRGB(20, 20, 24),
	Color3.fromRGB(150, 155, 160), Color3.fromRGB(245, 190, 30), Color3.fromRGB(30, 130, 70), Color3.fromRGB(240, 110, 20),
}

local function katalog(d)
	local liste = {}
	for _, typ in Auto.MODELL_REIHENFOLGE do
		local m = Auto.MODELLE[typ]
		local pass = m.pass and Shop.PASSES and (function()
			for _, x in Shop.PASSES do if x.key == m.pass then return x end end
		end)()
		table.insert(liste, {
			typ = typ, name = m.name, art = m.art, preis = m.preis, beschreibung = m.beschreibung,
			tempo = m.werte.MaxTempo, gehoert = d and table.find(d.autos or {}, typ) ~= nil,
			pass = pass and { key = pass.key, id = pass.id, name = pass.name, preis = pass.preis, bereit = pass.id ~= 0 } or nil,
		})
	end
	return liste
end

local function autoKaufen(p, typ)
	local d = daten[p]
	local modell = Auto.MODELLE[typ]
	if not modell then return { fehler = "This car does not exist." } end
	d.autos = d.autos or {}
	if table.find(d.autos, typ) then return { fehler = "You already own the " .. modell.name .. "." } end
	if modell.pass and not Shop.hat(p, modell.pass) then
		return { fehler = ("The %s is exclusive – get it in the 🛒 Shop."):format(modell.name) }
	end
	if d.geld < modell.preis then
		return { fehler = ("The %s costs %d coins, you have %d. Earn more with the delivery jobs!"):format(modell.name, modell.preis, d.geld) }
	end
	table.insert(d.autos, typ)
	geldGeben(p, -modell.preis, "Bought the " .. modell.name)
	return { text = ("The %s is yours! 🔑\n\nGet it anytime with the <b>🚗 My Cars</b> button (top left). It appears on the nearest free parking spot."):format(modell.name) }
end

function autoWeg(p)
	local a = privatAutos[p]
	if not a then return end
	privatAutos[p] = nil
	aussteigen(a.sitz)
	if a.model then a.model:Destroy() end
end

-- free parking spots where a bought car can appear (nearest to the player)
local function stellplaetze(p)
	local liste = {}
	if autohaus and autohaus:FindFirstChild("AutohausBuchten") then
		for _, b in autohaus.AutohausBuchten:GetChildren() do
			table.insert(liste, CFrame.new(b.Position + Vector3.new(0, 0.25, 0)) * b.CFrame.Rotation)
		end
	end
	for _, b in buchtOrdner:GetChildren() do
		if not b:GetAttribute("Uebung") then
			table.insert(liste, CFrame.new(b.Position.X, b.Position.Y + 0.25, b.Position.Z - 1))
		end
	end
	if pizzaBuchtOrdner then
		for _, b in pizzaBuchtOrdner:GetChildren() do
			table.insert(liste, CFrame.new(b.Position.X, b.Position.Y + 0.25, b.Position.Z + 1))
		end
	end
	-- driveway of your own villa
	local d = daten[p]
	local villen = workspace.Karte:FindFirstChild("Villen")
	if villen and d then
		for _, id in d.villen or {} do
			local v = villen:FindFirstChild(id)
			local platz = v and v:GetAttribute("Stellplatz")
			if platz then table.insert(liste, platz + Vector3.new(0, 0.25, 0)) end
		end
	end
	return liste
end

local function platzFrei(cf)
	local pos = cf.Position
	local function nah(c) return c and c.Parent and (c.Position - pos).Magnitude < 9 end
	for _, st in lektionen do if nah(st.chassis) then return false end end
	for _, job in jobs do if nah(job.chassis) then return false end end
	for _, a in privatAutos do if nah(a.chassis) then return false end end
	for _, plr in Players:GetPlayers() do
		local w = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
		if w and (w.Position - pos).Magnitude < 5 then return false end
	end
	return true
end

local function autoHolen(p, eingabe)
	local d = daten[p]
	if type(eingabe) ~= "table" then return { fehler = "Unknown car." } end
	local typ = eingabe.typ
	if not Auto.MODELLE[typ] or not table.find(d.autos or {}, typ) then return { fehler = "You don't own this car." } end
	if Pflege.daten(d, typ).zustand <= 0 then
		return { fehler = "This car is broken. Repair it at Ben's Garage (service station) first." }
	end
	if not d.fuehrerschein then return { fehler = "You need a driver's license (class B) to drive your own car!" } end
	if lektionen[p] or jobs[p] then return { fehler = "Finish your lesson or job first." } end
	local wurzel = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	if not wurzel then return { fehler = "Your character is not there yet." } end
	autoWeg(p)
	local bester, besterAbstand = nil, math.huge
	for _, cf in stellplaetze(p) do
		local abstand = (cf.Position - wurzel.Position).Magnitude
		if abstand < besterAbstand and platzFrei(cf) then bester, besterAbstand = cf, abstand end
	end
	if not bester then return { fehler = "All parking spots are taken. Try again in a moment." } end
	local nr = math.floor(tonumber(eingabe.farbe) or 1)
	local farbe = AUTOFARBEN_PRIVAT[nr] or AUTOFARBEN_PRIVAT[1]
	if nr > #AUTOFARBEN_PRIVAT and Shop.FARBEN[nr - #AUTOFARBEN_PRIVAT] then
		if not Shop.farbeErlaubt(p, nr) then return { fehler = "This paint color is exclusive – unlock it in the 🛒 Shop (Paint Studio or VIP)." } end
		farbe = Shop.FARBEN[nr - #AUTOFARBEN_PRIVAT].farbe
	end
	if Auto.MODELLE[typ].festeFarbe then farbe = Auto.MODELLE[typ].festeFarbe end
	local kennzeichen = (p.Name:sub(1, 2):upper():gsub("[^%u]", "X")) .. "-" .. (p.UserId % 9000 + 1000)
	local modell, sitz, _, chassis = Auto.bauenPrivat(bester, typ, farbe, kennzeichen)
	modell.Name = "Auto_" .. p.Name
	modell.Parent = workspace
	local a = { model = modell, sitz = sitz, chassis = chassis, blinkTeile = blinkTeileSuchen(modell), typ = typ, letztePos = chassis.Position }
	Pflege.anwenden(modell, typ, Pflege.daten(d, typ))
	privatAutos[p] = a
	einsteigPrompt(p, sitz, Auto.MODELLE[typ].name)
	sitz:GetPropertyChangedSignal("Occupant"):Connect(function()
		local hum = sitz.Occupant
		if not hum then return end
		if Players:GetPlayerFromCharacter(hum.Parent) ~= p then
			aussteigen(sitz) -- only the owner drives, friends can sit next to you
			return
		end
		pcall(function() chassis:SetNetworkOwner(p) end)
	end)
	fahrEvent:FireClient(p, { typ = "weg", pos = bester.Position })
	local meter = math.floor(besterAbstand * 0.28 + 0.5)
	return { text = ("Your %s is waiting on the parking spot about %d m away (green line on the minimap)."):format(Auto.MODELLE[typ].name, meter) }
end

Players.PlayerRemoving:Connect(autoWeg)

-- Showroom: only these cars stand on the two platforms (best: the exclusive Robux cars)
local AUTOHAUS_PLATTFORMEN = { "gs_night", "supersport" }
local AUTOHAUS_FARBEN = {
	kleinwagen = Color3.fromRGB(90, 170, 220), suv = Color3.fromRGB(30, 130, 70), limousine = Color3.fromRGB(20, 20, 24),
	sport = Color3.fromRGB(200, 25, 30), renn = Color3.fromRGB(245, 190, 30), supersport = Color3.fromRGB(240, 110, 20),
	track = Color3.fromRGB(20, 90, 200), gs = Color3.fromRGB(78, 88, 102), gs_night = Color3.fromRGB(18, 16, 24),
}

-- show cars in the showroom (can't be driven), the buy zone and the sales team
task.spawn(function()
	if not autohaus then
		warn("License system: car dealership not found (run the new map generator)")
		return
	end
	-- Showroom: only two platforms with the exclusive cars. All other cars are bought in the
	-- green zone in front of the reception (or from Marco / Sophie).
	for _, t in autohaus:GetChildren() do
		if t.Name == "Podest" or t.Name == "Podestlicht" or t.Name == "Ausstellungsplatz" or t.Name == "Spot" or t.Name:sub(1, 12) == "Ausstellung_" then
			t:Destroy()
		end
	end
	local boden = autohaus:FindFirstChild("Showroomboden")
	local mitte = boden and boden.Position or Vector3.new(122, 0.1, -376)
	local bodenY = boden and (boden.Position.Y + boden.Size.Y / 2) or 0.6
	local function neu(name, gr, lage, farbe, mat, form)
		local p = Instance.new("Part")
		p.Name, p.Size, p.CFrame, p.Color, p.Material, p.Anchored = name, gr, lage, farbe, mat, true
		if form then p.Shape = form end
		p.Parent = autohaus
		return p
	end
	for i, typ in AUTOHAUS_PLATTFORMEN do
		local D = Auto.MODELLE[typ]
		if D then
			local pos = mitte + Vector3.new(-10, 0, i == 1 and -14 or 14)
			local exklusiv = D.pass ~= nil
			local podest = neu("Podest", Vector3.new(1.2, 18, 18), CFrame.new(pos.X, bodenY + 0.6, pos.Z) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(28, 28, 32), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
			podest.Reflectance = 0.15
			local ring = neu("Podestlicht", Vector3.new(1.22, 18.4, 18.4), CFrame.new(pos.X, bodenY + 0.55, pos.Z) * CFrame.Angles(0, 0, math.rad(90)), exklusiv and Color3.fromRGB(150, 70, 255) or Color3.fromRGB(255, 60, 70), Enum.Material.Neon, Enum.PartType.Cylinder)
			ring.CanCollide = false
			local spot = neu("Spot", Vector3.new(2, 0.4, 2), CFrame.new(pos.X, 14.2, pos.Z), Color3.fromRGB(255, 250, 235), Enum.Material.Neon)
			spot.CanCollide = false
			local licht = Instance.new("SpotLight")
			licht.Face = Enum.NormalId.Bottom
			licht.Range = 20
			licht.Angle = 70
			licht.Brightness = 3
			licht.Parent = spot
			-- the car stands on the podium, turned towards the entrance
			local oben = bodenY + 1.2
			local m = Auto.bauenPrivat(CFrame.new(pos.X, oben, pos.Z) * CFrame.Angles(0, math.rad(i == 1 and -60 or -120), 0), typ, D.festeFarbe or AUTOHAUS_FARBEN[typ])
			m.Name = "Ausstellung_" .. typ
			for _, t in m:GetDescendants() do
				if t:IsA("BasePart") then t.Anchored = true end
				if t:IsA("Seat") or t:IsA("VehicleSeat") then t.Disabled = true end
			end
			m.Parent = autohaus
			local schild = Instance.new("BillboardGui")
			schild.Size = UDim2.fromOffset(220, 54)
			schild.StudsOffsetWorldSpace = Vector3.new(0, 8.5, 0)
			schild.MaxDistance = 60
			schild.Parent = podest
			local l = Instance.new("TextLabel")
			l.Size = UDim2.fromScale(1, 1)
			l.BackgroundTransparency = 1
			l.Font = Enum.Font.GothamBlack
			l.TextScaled = true
			l.TextStrokeTransparency = 0.4
			l.TextColor3 = exklusiv and Color3.fromRGB(210, 170, 255) or Color3.new(1, 1, 1)
			l.Text = (exklusiv and "🌙 EXCLUSIVE\n" or "") .. D.name
			l.Parent = schild
			local pp = Instance.new("ProximityPrompt")
			pp.ActionText = exklusiv and "🌙 Exclusive – look" or ("Buy – %d coins"):format(D.preis)
			pp.ObjectText = D.name .. " (" .. D.art .. ")"
			pp.HoldDuration = 0
			pp.MaxActivationDistance = 16
			pp.RequiresLineOfSight = false
			pp.Parent = podest
			pp.Triggered:Connect(function(p)
				local d = daten[p]
				if d then oeffnen:FireClient(p, "autohaus", { katalog = katalog(d), geld = d.geld, auswahl = typ }) end
			end)
		end
	end

	-- green buy circle in front of the reception (same look as the lesson gates, just round):
	-- step in = the car catalogue opens
	local tresen = autohaus:FindFirstChild("Tresen")
	local zPos = tresen and Vector3.new(tresen.Position.X - tresen.Size.X / 2 - 5, bodenY, tresen.Position.Z) or Vector3.new(134, bodenY, -392)
	local RADIUS = 4.5
	local zone = neu("Kaufzone", Vector3.new(0.1, RADIUS * 2, RADIUS * 2), CFrame.new(zPos.X, bodenY + 0.06, zPos.Z) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(60, 255, 120), Enum.Material.Neon, Enum.PartType.Cylinder)
	zone.CanCollide = false
	zone.CanQuery = false
	zone.CanTouch = false
	zone.CastShadow = false
	zone.Transparency = 0.5
	local saeule = neu("Kaufzone_Licht", Vector3.new(7, RADIUS * 2, RADIUS * 2), CFrame.new(zPos.X, bodenY + 3.5, zPos.Z) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(60, 255, 120), Enum.Material.Neon, Enum.PartType.Cylinder)
	saeule.CanCollide = false
	saeule.CanQuery = false
	saeule.CanTouch = false
	saeule.CastShadow = false
	saeule.Transparency = 0.85
	local imBereich = {}
	task.spawn(function()
		while zone.Parent do
			task.wait(0.25)
			for _, p in Players:GetPlayers() do
				local w = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
				local abstand = w and Vector3.new(w.Position.X - zPos.X, 0, w.Position.Z - zPos.Z).Magnitude
				local drin = abstand ~= nil and abstand < RADIUS + 0.5 and w.Position.Y - bodenY < 8
				if drin and not imBereich[p] then
					local d = daten[p]
					if d then oeffnen:FireClient(p, "autohaus", { katalog = katalog(d), geld = d.geld }) end
				end
				imBereich[p] = drin or nil
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(p) imBereich[p] = nil end)

	-- sales team behind the reception: Marco and Sophie
	local platz = autohaus:FindFirstChild("VerkaeuferPlatz")
	if platz then
		local function verkaeufer(name, anzeige, haut, stil, versatz)
			local figur, hum = npc(name, anzeige, haut, Color3.fromRGB(30, 30, 35), Color3.fromRGB(30, 30, 35), stil)
			if not figur then return end
			local wurzel = figur:WaitForChild("HumanoidRootPart")
			wurzel.Anchored = true
			local stand = Vector3.new(platz.Position.X, 0.6 + hum.HipHeight + wurzel.Size.Y / 2, platz.Position.Z + versatz)
			figur:PivotTo(CFrame.lookAt(stand, stand + Vector3.new(-1, 0, 0)))
			figur.Parent = autohaus
			local idle = animation(hum, "stehen")
			if idle then idle:Play() end
			local pp = Instance.new("ProximityPrompt")
			pp.ActionText = "Buy a car"
			pp.ObjectText = anzeige
			pp.HoldDuration = 0
			pp.MaxActivationDistance = 10
			pp.RequiresLineOfSight = false
			pp.Parent = wurzel
			pp.Triggered:Connect(function(p)
				local d = daten[p]
				if d then oeffnen:FireClient(p, "autohaus", { katalog = katalog(d), geld = d.geld }) end
			end)
		end
		task.spawn(verkaeufer, "Verkaeufer", "Marco (Sales)", Color3.fromRGB(198, 145, 105),
			{ shirt = NPC_LOOK.anzug.shirt, pants = NPC_LOOK.anzug.pants, haar = 9244021842, kopf = NPC_LOOK.koepfeMann[1], frau = false }, -2.2)
		-- Sophie: grey suit with waistcoat, long blonde braid (looks different from Anna at the driving school)
		task.spawn(verkaeufer, "Verkaeuferin", "Sophie (Sales)", Color3.fromRGB(198, 145, 105),
			{ shirt = 6554200369, pants = 6555797786, haar = 9244148336, kopf = NPC_LOOK.koepfeFrau[1], frau = true }, 2.2)
	end
end)

-- NPC traffic (the server decides the positions, every player draws the vehicles)
task.spawn(function()
	local ok, fehler = pcall(Verkehr.starten, {
		regeln = Regeln,
		event = verkehrEvent,
		weitere = function()
			local liste = {}
			for _, f in fussgaenger do
				if f.wurzel.Parent then
					table.insert(liste, { pos = Vector3.new(f.wurzel.Position.X, 0, f.wurzel.Position.Z), halb = 1.5 })
				end
			end
			return liste
		end,
		kontrolle = function() return aktuelleKontrolle end,
		fahrzeuge = function()
			local liste = {}
			for _, st in lektionen do
				if st.model and st.model.Parent then table.insert(liste, st.model) end
			end
			for _, job in jobs do
				if job.model and job.model.Parent then table.insert(liste, job.model) end
			end
			for _, a in privatAutos do
				if a.model and a.model.Parent then table.insert(liste, a.model) end
			end
			return liste
		end,
	})
	if not ok then warn("License system: NPC traffic could not start: " .. tostring(fehler)) end
end)

-- Map data for the minimap (roads, sidewalks, buildings) - computed once on the server,
-- because with streaming a player's computer only has the nearby parts of the map
local kartenDaten
local function minimapDaten()
	if kartenDaten then return kartenDaten end
	kartenDaten = {}
	local function eintrag(t, typ)
		local _, gier = t.CFrame:ToOrientation()
		local sx, sz = t.Size.X, t.Size.Z
		if math.abs(math.sin(gier)) > 0.7 then sx, sz = sz, sx end
		table.insert(kartenDaten, { typ, math.floor(t.Position.X), math.floor(t.Position.Z), math.floor(sx + 0.5), math.floor(sz + 0.5) })
	end
	local karte = workspace.Karte
	for _, t in karte.Strassen:GetDescendants() do
		if t:IsA("BasePart") and t.Size.Y <= 1.5 and t.Position.Y < 2 and t.Name ~= "Leitplanke" then
			if t.Shape == Enum.PartType.Cylinder then
				table.insert(kartenDaten, { t.Name == "Kreisverkehr" and "kreis" or "insel", math.floor(t.Position.X), math.floor(t.Position.Z), math.floor(t.Size.Y), math.floor(t.Size.Y) })
			elseif t.Size.X > 6 or t.Size.Z > 6 then
				eintrag(t, t.Name == "Gehweg" and "gehweg" or "strasse")
			end
		end
	end
	for _, t in karte:GetDescendants() do
		if t:IsA("BasePart") and t.Name == "Koerper" then
			eintrag(t, "haus")
		elseif t:IsA("BasePart") and (t.Name == "Sockel" or t.Name == "Pizzeriaboden") then
			eintrag(t, "haus")
		elseif t:IsA("BasePart") and (t.Name == "Parkplatz" or t.Name == "Depothof" or t.Name == "Pizzaparkplatz") then
			eintrag(t, "strasse")
		elseif t:IsA("BasePart") and t.Name == "Lagerhalle" then
			eintrag(t, "haus")
		end
	end
	local boden = fahrschule:FindFirstChild("Boden")
	if boden then eintrag(boden, "schule") end
	return kartenDaten
end

-- ---------------------------------------------------------------
-- Requests from players
-- ---------------------------------------------------------------
aktion.OnServerInvoke = function(p, was, eingabe)
	local d = daten[p]
	if not d then
		return { fehler = "Your data is still loading. Please try again in a moment." }
	end

	if was == "status" then
		local naechste = LEKTIONEN[d.fahrstunden + 1]
		return {
			status = d,
			lektionLaeuft = lektionen[p] ~= nil,
			naechste = naechste and naechste.titel or nil,
			anzahlLektionen = #LEKTIONEN,
			sitzt = sitztAmPlatz(p),
			pruefungBereit = d.fahrstunden >= #LEKTIONEN and not d.fuehrerschein,
			lkwLaeuft = lektionen[p] ~= nil and lektionen[p].lkw == true,
			jobLaeuft = jobs[p] ~= nil,
			jobs = jobInfo(d),
		}

	elseif was == "anmelden" then
		d.angemeldet = true
		geaendert(p)
		return { status = d }

	elseif was == "unterrichtFertig" then
		if not d.angemeldet then
			return { fehler = "Please sign up at the reception first." }
		end
		d.unterricht = true
		geaendert(p)
		return { status = d }

	elseif was == "pruefungStart" then
		if not d.unterricht then
			return { fehler = "Please attend the theory lesson at the whiteboard first." }
		end
		if d.theorie then
			return { fehler = "You have already passed the theory test." }
		end
		if not sitztAmPlatz(p) then
			return { fehler = "Please sit down at an exam desk to start the test." }
		end
		if sperre[p] and os.clock() < sperre[p] then
			return { fehler = ("You can try again in %d seconds."):format(math.ceil(sperre[p] - os.clock())) }
		end
		local reihenfolge = {}
		for i = 1, #FRAGEN do reihenfolge[i] = i end
		mischen(reihenfolge)
		local liste, richtige = {}, {}
		for n = 1, math.min(ANZAHL_FRAGEN, #FRAGEN) do
			local f = FRAGEN[reihenfolge[n]]
			local pos = {}
			for i = 1, #f.a do pos[i] = i end
			mischen(pos)
			local antworten = {}
			for neu, alt in pos do
				antworten[neu] = f.a[alt]
				if alt == f.r then richtige[n] = neu end
			end
			liste[n] = { frage = f.q, antworten = antworten }
		end
		pruefungen[p] = richtige
		return { fragen = liste, mindest = math.ceil(#richtige * MINDEST_QUOTE) }

	elseif was == "pruefungAbgeben" then
		local richtige = pruefungen[p]
		if not richtige then
			return { fehler = "There is no test running (did you stand up?)." }
		end
		pruefungen[p] = nil
		if type(eingabe) ~= "table" then eingabe = {} end
		local punkte = 0
		for n, r in richtige do
			if eingabe[n] == r then punkte += 1 end
		end
		local bestanden = punkte / #richtige >= MINDEST_QUOTE
		if bestanden then
			xpGeben(p, 80, "Theory test passed")
			d.theorie = true
			geaendert(p)
		else
			sperre[p] = os.clock() + WARTEZEIT
		end
		return { punkte = punkte, gesamt = #richtige, bestanden = bestanden, mindest = math.ceil(#richtige * MINDEST_QUOTE), wartezeit = WARTEZEIT }

	elseif was == "pruefungStarten" then
		return lektionStarten(p, "pruefung")

	elseif was == "lkwPruefungStarten" then
		return lektionStarten(p, "lkw")

	elseif was == "jobStarten" then
		return jobStarten(p, "lkw", eingabe)

	elseif was == "pizzaStarten" then
		return jobStarten(p, "pizza")

	elseif was == "jobAbbrechen" then
		if jobs[p] then jobBeenden(p, false, "You cancelled the job. The truck was returned to the depot.") end
		return { ok = true }

	elseif was == "werkstattInfo" then
		return Pflege.werkstattInfo(p)

	elseif was == "werkstatt" then
		return Pflege.werkstatt(p, eingabe)

	elseif was == "pannenhilfe" then
		return Pflege.pannenhilfe(p)

	elseif was == "missionen" then
		return Missionen.status(p)
	elseif was == "shop" then
		return Shop.status(p)
	elseif was == "belohnungen" then
		return Belohnungen.status(p)
	elseif was == "belohnungAbholen" then
		return Belohnungen.abholen(p, eingabe)

	elseif was == "taxiStarten" then
		return jobStarten(p, "taxi")

	elseif was == "akte" then
		local a = Strafen.akte(p)
		a.xp, a.level = d.xp or 0, levelVon(d.xp or 0)
		a.naechstesLevelXp = 150 * a.level ^ 2
		a.dieseStufeXp = 150 * (a.level - 1) ^ 2
		return a

	elseif was == "nachschulung" then
		return Strafen.nachschulungBuchen(p)

	elseif was == "autoKaufen" then
		return autoKaufen(p, eingabe)

	elseif was == "meineAutos" then
		return { katalog = katalog(d), fuehrerschein = d.fuehrerschein, aktiv = privatAutos[p] ~= nil, km = d.autoKm or {} }

	elseif was == "autoHolen" then
		return autoHolen(p, eingabe)

	elseif was == "autoWeg" then
		autoWeg(p)
		return { text = "Your car was parked away." }

	elseif was == "villaKaufen" then
		return villaKaufen(p, eingabe)

	elseif was == "kontrolleAntwort" then
		return kontrolleAntwort(p, eingabe == true)

	elseif was == "verkehr" then
		return { liste = Verkehr.liste and Verkehr.liste() or nil }

	elseif was == "einstellungen" then
		if type(eingabe) == "table" then
			local sauber = {}
			for k, v in eingabe do
				if type(k) == "string" and #k < 30 and (type(v) == "boolean" or type(v) == "string" and #v < 30) then
					sauber[k] = v
				end
			end
			d.einstellungen = sauber
			task.spawn(speichern, p)
		end
		return { einstellungen = d.einstellungen }

	elseif was == "kartendaten" then
		return { daten = minimapDaten() }

	elseif was == "fahrstundeStarten" then
		return lektionStarten(p)

	elseif was == "adminGeld" then
		-- checked on the server: nobody else can use this, even with a hacked client
		if not istAdmin(p) then return { fehler = "Only the owner of the game can do this." } end
		local betrag = math.clamp(math.floor(tonumber(eingabe) or 0), -1000000, 1000000)
		if betrag < 0 then betrag = -d.geld end -- negative = back to 0 coins
		geldGeben(p, betrag, "Admin", true)
		return { text = ("You now have %d coins."):format(d.geld) }

	elseif was == "dev" then
		-- Test shortcuts, only work inside Roblox Studio
		if not RunService:IsStudio() then
			return { fehler = "Only available in Studio." }
		end
		local befehl = type(eingabe) == "table" and eingabe.befehl or nil
		if befehl == "theorie" then
			d.angemeldet, d.unterricht, d.theorie = true, true, true
			geaendert(p)
			return { text = "Theory skipped. Talk to Anna to start a driving lesson." }
		elseif befehl == "lektion" then
			local nr = math.clamp(tonumber(eingabe.nr) or 1, 1, #LEKTIONEN)
			if lektionen[p] then lektionBeenden(p, false, "Lesson cancelled (test menu).") end
			d.angemeldet, d.unterricht, d.theorie = true, true, true
			d.fahrstunden = nr - 1
			geaendert(p)
			return lektionStarten(p)
		elseif befehl == "pruefung" then
			if lektionen[p] then lektionBeenden(p, false, "Lesson cancelled (test menu).") end
			d.angemeldet, d.unterricht, d.theorie = true, true, true
			d.fahrstunden = #LEKTIONEN
			d.fuehrerschein = false
			geaendert(p)
			return lektionStarten(p, "pruefung")
		elseif befehl == "lizenz" then
			d.angemeldet, d.unterricht, d.theorie = true, true, true
			d.fahrstunden = #LEKTIONEN
			d.fuehrerschein = true
			d.fuehrerscheinDatum = os.date("!%d.%m.%Y")
			d.fuehrerscheinNr = ("DS-%06d"):format(p.UserId % 1000000)
			geaendert(p)
			task.spawn(fuehrerscheinGeben, p)
			fahrEvent:FireClient(p, {
				typ = "bestanden", text = "Test cutscene (test menu).", fehler = 0,
				klassen = d.lkwFuehrerschein and "B C" or "B", lkwDatum = d.lkwDatum,
				name = p.DisplayName, benutzer = p.Name, userId = p.UserId,
				datum = d.fuehrerscheinDatum, nummer = d.fuehrerscheinNr,
			})
			return { text = "License granted. Check your inventory." }
		elseif befehl == "lkw" or befehl == "lkwlizenz" then
			if lektionen[p] then lektionBeenden(p, false, "Lesson cancelled (test menu).") end
			if jobs[p] then jobBeenden(p, false, "Job cancelled (test menu).") end
			d.angemeldet, d.unterricht, d.theorie = true, true, true
			d.fahrstunden = #LEKTIONEN
			d.fuehrerschein = true
			if d.fuehrerscheinNr == "" then
				d.fuehrerscheinDatum = os.date("!%d.%m.%Y")
				d.fuehrerscheinNr = ("DS-%06d"):format(p.UserId % 1000000)
			end
			d.lkwFuehrerschein = befehl == "lkwlizenz"
			if d.lkwFuehrerschein then d.lkwDatum = os.date("!%d.%m.%Y") end
			geaendert(p)
			task.spawn(fuehrerscheinGeben, p)
			if befehl == "lkw" then return lektionStarten(p, "lkw") end
			return { text = "Car + truck license granted. Talk to Tom at the Parcel Express depot for a job." }
		elseif befehl == "geld" then
			geldGeben(p, 500, "Test money", true)
			return { text = "+500 coins." }
		elseif befehl == "kauf" then
			-- test purchase: pass on/off or developer product (free, Studio only)
			return Shop.testKauf(p, eingabe.key)
		elseif befehl == "spielzeit" then
			Belohnungen.takt(p, (tonumber(eingabe.min) or 10) * 60)
			return { text = "Playtime added." }
		elseif befehl == "neuerTag" then
			d.login = d.login or { letzte = "", serie = 0, beste = 0 }
			d.login.letzte = os.date("!%Y-%m-%d", os.time() - 86400)
			d.spielzeit = nil
			Belohnungen.markieren(p)
			return { text = "Next day simulated (daily reward ready)." }
		elseif befehl == "reset" then
			if lektionen[p] then lektionBeenden(p, false, "Lesson cancelled (test menu).") end
			if jobs[p] then jobBeenden(p, false, "Job cancelled (test menu).") end
			daten[p] = standard()
			sperre[p] = nil
			for _, ort in { p:FindFirstChild("Backpack"), p:FindFirstChild("StarterGear"), p.Character } do
				local alt = ort and ort:FindFirstChild(LIZENZ_NAME)
				if alt then alt:Destroy() end
			end
			anzeigen(p)
			task.spawn(speichern, p)
			return { text = "Progress reset." }
		end
		return { fehler = "Unknown test command." }

	elseif was == "fahrstundeAbbrechen" then
		if lektionen[p] then
			lektionBeenden(p, false, "Lesson cancelled.")
		end
		return { ok = true }
	end

	return { fehler = "Unknown request." }
end

-- ---------------------------------------------------------------
-- Leaving / shutdown
-- ---------------------------------------------------------------
Players.PlayerRemoving:Connect(function(p)
	speichern(p)
	local st = lektionen[p]
	if st and st.model then st.model:Destroy() end
	lektionen[p] = nil
	local job = jobs[p]
	if job then
		jobs[p] = nil
		if job.model then job.model:Destroy() end
		if job.kunde then job.kunde:Destroy() end
	end
	daten[p] = nil
	pruefungen[p] = nil
	sperre[p] = nil
	sitzend[p] = nil
end)

game:BindToClose(function()
	for _, p in Players:GetPlayers() do
		speichern(p)
	end
end)

-- ---------------------------------------------------------------
-- Separate systems: traffic offences (speed cameras, points) and time of day / weather
-- ---------------------------------------------------------------
Strafen.starten({
	daten = daten, lektionen = lektionen, Regeln = Regeln, fahrEvent = fahrEvent,
	geldGeben = geldGeben, geaendert = geaendert, warnung = warnung,
	lizenzEntfernen = function(p)
		for _, ort in { p:FindFirstChild("Backpack"), p:FindFirstChild("StarterGear"), p.Character } do
			local alt = ort and ort:FindFirstChild(LIZENZ_NAME)
			if alt then alt:Destroy() end
		end
	end,
	autoWeg = autoWeg,
	jobAbbrechen = function(p, text)
		if jobs[p] then jobBeenden(p, false, text) end
	end,
})
Umwelt.starten(ordner)
Pflege.starten({
	daten = daten, privatAutos = privatAutos, Auto = Auto, fahrEvent = fahrEvent,
	geldGeben = geldGeben, geaendert = geaendert, autoWeg = autoWeg, mission = Missionen.fortschritt,
})
Missionen.starten({ daten = daten, geldGeben = geldGeben, xpGeben = xpGeben, fahrEvent = fahrEvent })
Shop.starten({ daten = daten, geldGeben = geldGeben, fahrEvent = fahrEvent, geaendert = geaendert, speichernSofort = speichern, Auto = Auto, Pflege = Pflege })
Belohnungen.starten({ daten = daten, geldGeben = geldGeben, xpGeben = xpGeben, fahrEvent = fahrEvent, geaendert = geaendert, Shop = Shop })

-- odometer of the bought cars
task.spawn(function()
	while true do
		task.wait(1)
		for p, a in privatAutos do
			local d = daten[p]
			if d and a.chassis and a.chassis.Parent then
				local weg = (a.chassis.Position - a.letztePos).Magnitude
				a.letztePos = a.chassis.Position
				if weg < 300 then
					d.autoKm = d.autoKm or {}
					local km = weg * 0.28 / 1000
					d.autoKm[a.typ] = (d.autoKm[a.typ] or 0) + km
					d.kmGesamt = (d.kmGesamt or 0) + km
					Missionen.fortschritt(p, "km", km)
				end
			end
		end
	end
end)

print("License system ready" .. (store and "" or " (WITHOUT saving)"))
]=====]
neu("ModuleScript", "Fragen", server, [=====[
-- Question pool for the theory test (general road rules used in this game).
-- q = question, a = answers, r = number of the correct answer
return {
	{ q = "Which side of the road do you drive on in this game?", a = { "The right side", "The left side", "Whichever side is free" }, r = 1 },
	{ q = "What is the speed limit in the city unless signs say otherwise?", a = { "30 km/h", "50 km/h", "80 km/h" }, r = 2 },
	{ q = "What is the speed limit in residential areas?", a = { "30 km/h", "60 km/h", "100 km/h" }, r = 1 },
	{ q = "What is the speed limit on country roads?", a = { "70 km/h", "100 km/h", "130 km/h" }, r = 2 },
	{ q = "What is the speed limit on the highway?", a = { "100 km/h", "130 km/h", "There is no limit" }, r = 2 },
	{ q = "The traffic light turns yellow and you can stop safely. What do you do?", a = { "Stop", "Speed up to make it", "Honk and keep going" }, r = 1 },
	{ q = "Where do you stop at a red light?", a = { "Before the stop line", "In the middle of the intersection", "On the crosswalk" }, r = 1 },
	{ q = "What does a STOP sign require?", a = { "Come to a complete stop, then give way", "Just slow down", "You have the right of way" }, r = 1 },
	{ q = "You reach a junction without any signs or traffic lights. Who goes first?", a = { "The vehicle coming from the right", "The vehicle coming from the left", "The faster vehicle" }, r = 1 },
	{ q = "What does a yellow diamond sign mean?", a = { "You are on the main road and have priority", "Danger ahead", "End of the speed limit" }, r = 1 },
	{ q = "A red triangle with the point facing down means:", a = { "Give way to traffic on the main road", "You have priority", "No entry" }, r = 1 },
	{ q = "A pedestrian is waiting at a crosswalk. What do you do?", a = { "Stop and let them cross", "Honk so they wait", "Drive past quickly" }, r = 1 },
	{ q = "You turn at a green light and pedestrians are crossing that street. What do you do?", a = { "Let the pedestrians cross first", "Turn first, they can wait", "Honk at them" }, r = 1 },
	{ q = "You want to turn left and oncoming traffic goes straight. Who goes first?", a = { "The oncoming traffic", "You", "Whoever honks first" }, r = 1 },
	{ q = "Who has the right of way in a roundabout?", a = { "Traffic already in the roundabout", "Cars entering the roundabout", "The bigger vehicle" }, r = 1 },
	{ q = "When do you use your turn signal in a roundabout?", a = { "When leaving it", "Only when entering", "Never" }, r = 1 },
	{ q = "When should you use your turn signal?", a = { "Early, before turning or changing lanes", "After you have turned", "Only at night" }, r = 1 },
	{ q = "On the highway, on which side do you overtake?", a = { "On the left", "On the right", "Either side" }, r = 1 },
	{ q = "After overtaking on the highway, what do you do?", a = { "Move back to the right lane", "Stay in the left lane", "Slow down in the left lane" }, r = 1 },
	{ q = "Are you allowed to turn around on the highway?", a = { "No, never", "Yes, if there is little traffic", "Yes, at exits" }, r = 1 },
	{ q = "An ambulance with flashing lights and siren is behind you. What do you do?", a = { "Make way safely as fast as possible", "Keep driving normally", "Stop in the middle of the road" }, r = 1 },
	{ q = "What is a safe following distance in good conditions?", a = { "At least 2 seconds behind the car in front", "Half a car length", "As close as possible" }, r = 1 },
	{ q = "It is raining heavily. What changes?", a = { "Braking distance gets longer, so slow down", "Nothing changes", "You can brake later" }, r = 1 },
	{ q = "When must you switch on your headlights?", a = { "At night, at dusk and in poor visibility", "Only on the highway", "Never during the day" }, r = 1 },
	{ q = "May you use your phone in your hand while driving?", a = { "No, it is not allowed", "Yes, at low speed", "Yes, in the city" }, r = 1 },
	{ q = "Who must wear a seatbelt?", a = { "Everyone in the car", "Only the driver", "Only passengers in the front" }, r = 1 },
	{ q = "May you drive after drinking alcohol?", a = { "No, never drink and drive", "Yes, after one drink", "Yes, if you feel fine" }, r = 1 },
	{ q = "Children are playing near the road. What do you do?", a = { "Slow down and be ready to brake", "Honk to warn them", "Speed up to pass quickly" }, r = 1 },
	{ q = "Where are you NOT allowed to park?", a = { "In front of a fire hydrant", "In a marked parking bay", "In a parking lot" }, r = 1 },
	{ q = "Are you allowed to park on a crosswalk?", a = { "No", "Yes, for a short time", "Yes, with hazard lights on" }, r = 1 },
	{ q = "When should you use your hazard lights?", a = { "When your car breaks down or blocks the road", "When parking illegally", "When driving fast" }, r = 1 },
	{ q = "What should you do before changing lanes?", a = { "Check mirrors, signal and check your blind spot", "Just signal", "Change quickly without looking" }, r = 1 },
	{ q = "A traffic light is not working at an intersection. What applies?", a = { "Follow the traffic signs and drive carefully", "You always have the right of way", "Drive through at full speed" }, r = 1 },
	{ q = "You see a YIELD sign. What does it mean?", a = { "Let other traffic go first", "You must always stop completely", "Others must let you go" }, r = 1 },
	{ q = "What does a solid white line between lanes mean?", a = { "Do not cross it", "Cross it whenever you like", "Only trucks may cross" }, r = 1 },
	{ q = "You feel very tired while driving. What should you do?", a = { "Take a break at a safe place", "Open the window and keep going", "Drive faster to arrive sooner" }, r = 1 },
	{ q = "How do you enter the highway safely?", a = { "Match the speed of traffic and merge", "Stop at the end of the ramp", "Enter slowly in the left lane" }, r = 1 },
}
]=====])
neu("ModuleScript", "Auto", server, [=====[
-- Driving school car: a compact sedan with glass windows and an interior.
-- Physics: hinge wheels. The driving itself is controlled by the driver's client
-- (FuehrerscheinClient), which makes the car feel direct instead of floaty.
local Auto = {}

-- Car paint: metallic look (deep colour with a soft sheen). Very light colours stay plastic,
-- otherwise white turns grey. Only looks – no effect on driving.
function Auto.lack(p, farbe)
	local hell = 0.299 * farbe.R + 0.587 * farbe.G + 0.114 * farbe.B
	if hell > 0.72 then
		p.Material = Enum.Material.SmoothPlastic
		p.Reflectance = 0.06
	else
		p.Material = Enum.Material.Metal
		p.Reflectance = 0.05
	end
end

-- Driving feel (read by the driver's client). If the car drives backwards on W, set RICHTUNG = -1.
Auto.EINSTELLUNGEN = {
	RICHTUNG = 1,
	MaxTempo = 130,      -- top speed in studs/s (about km/h)
	Antrieb = 4500,      -- motor torque per rear wheel
	Bremse = 14000,      -- braking torque
	Lenkwinkel = 34,     -- max steering angle at low speed (degrees)
	Grip = 14,           -- how strongly sideways sliding is stopped (higher = more grip)
	Lenkdirekt = 14,     -- how directly the car follows the steering (higher = sharper)
	Anpressdruck = 60,   -- extra downforce, keeps the car planted
}

local function V3(x, y, z)
	return Vector3.new(x, y, z)
end

-- ---------------------------------------------------------------
-- Round body from the 3D model (fahrschulauto.obj): a compact premium sedan (A3-sedan-like proportions, no logos).
-- Import it with the 3D Importer, name the imported model "Limousine" and move it into
-- ServerStorage. If it is there, the car uses it automatically; otherwise the block body is used.
-- If the imported body faces backwards, set MESH_DREHUNG = 180.
-- ---------------------------------------------------------------
Auto.MESH_DREHUNG = 0
local MESH = {
	Karosserie = { groesse = Vector3.new(7.16, 2.58, 16.0), mitte = Vector3.new(0.0, 2.29, 0.0) },
	Glas = { groesse = Vector3.new(6.4776, 2.5399, 8.2), mitte = Vector3.new(0.0, 4.6299, 1.35) },
	Dach = { groesse = Vector3.new(5.8849, 0.5872, 2.6), mitte = Vector3.new(0.0, 5.6313, 1.3) },
}
-- where lights and details sit on the round body (x is mirrored for both sides)
local MESH_POS = {
	Scheinwerfer = { 2.4, 2.75, -7.945 },
	Tagfahrlicht = { 2.4, 2.5, -7.87 },
	BlinkerVorne = { 3.05, 2.6, -7.455 },
	Nebelscheinwerfer = { 2.6, 1.45, -7.63 },
	Kuehlergrill = { 0, 2.0, -8.065 },
	Lufteinlass = { 0, 1.35, -7.715 },
	KennzeichenVorne = { 0, 1.95, -8.005 },
	Ruecklicht = { 2.3, 3.2, 7.84 },
	BlinkerHinten = { 3.0, 3.2, 7.635 },
	Reflektor = { 2.7, 1.55, 7.8 },
	KennzeichenHinten = { 0, 2.45, 8.005 },
	Auspuff = { 2.2, 1.3, 7.79 },
	Griff1 = { 3.4, 3.15, 0.2 },
	Griff2 = { 3.43, 3.15, 3.0 },
	Spiegelfuss = { 2.35, 3.4, -2.25 },
	Zierleiste = { 2.36, 3.42, 1.4 },
	Schulterlinie = { 3.445, 3.1, 1.2 },
	DrittesBremslicht = { 0, 5.679, 2.45 },
	Heckspoiler = { 0, 3.64, 7.25 },
}
-- block parts that the round body replaces
local VERSTECKEN = {}
for _, n in { "Front", "Motorraum", "Haube", "Motorhaube", "Haubenlinie", "Heck", "Kofferraum_innen", "Kofferraum",
	"Kofferraumdeckel", "Spoilerkante", "Boden", "Ecke", "Seite", "Seite_oben", "Schweller", "Sicke", "Zierleiste",
	"Tuerfuge", "Stossstangenecke", "Stossstange_vorne", "Stossstange_hinten", "Bremslicht_oben", "Dach", "Dachkante",
	"Fensterrahmen", "A_Saeule", "C_Saeule", "B_Saeule", "Frontscheibe", "Heckscheibe", "Seitenscheibe", "Dreieck_vorne",
	"Dreieck_hinten", "Scheinwerferrahmen", "Ruecklicht_Seite", "Ruecklicht_Klappe", "Mittelkonsole", "Sitzflaeche",
	"Ruecksitzbank" } do
	VERSTECKEN[n] = true
end

local R = 1.3        -- wheel radius
local SPUR = 3.2     -- half track width
local ACHSE = 4.8    -- distance of the axles from the middle

local GLAS = Color3.fromRGB(150, 175, 195)
local SCHWARZ = Color3.fromRGB(22, 22, 25)
local INNEN = Color3.fromRGB(55, 55, 60)
local CHROM = Color3.fromRGB(200, 200, 205)

local function anhang(eltern, name, cf)
	local a = Instance.new("Attachment")
	a.Name = name
	a.CFrame = cf
	a.Parent = eltern
	return a
end

-- Hides the lower legs of everyone sitting (so they never poke through the floor), puts the
-- driver next to the door when getting out and holds the brakes when nobody drives.
function Auto.sitzeEinrichten(m, chassis, sitz, mitfahrSitze, aussteigOrt)
	local function beine(figur, verstecken)
		if not figur then return end
		for _, name in { "LeftLowerLeg", "RightLowerLeg", "LeftFoot", "RightFoot" } do
			local bein = figur:FindFirstChild(name)
			if bein and bein:IsA("BasePart") then
				bein.Transparency = verstecken and 1 or 0
			end
		end
	end
	for _, mitfahrSitz in mitfahrSitze do
		local letzter
		mitfahrSitz:GetPropertyChangedSignal("Occupant"):Connect(function()
			if mitfahrSitz.Occupant then
				letzter = mitfahrSitz.Occupant.Parent
				beine(letzter, true)
			else
				beine(letzter, false)
				letzter = nil
			end
		end)
	end
	local letzterFahrer
	sitz:GetPropertyChangedSignal("Occupant"):Connect(function()
		if sitz.Occupant then
			letzterFahrer = sitz.Occupant.Parent
			beine(letzterFahrer, true)
		else
			local figur = letzterFahrer
			letzterFahrer = nil
			beine(figur, false)
			if figur and figur.Parent and chassis.Parent then
				task.defer(function()
					figur:PivotTo(chassis.CFrame * aussteigOrt)
				end)
			end
			pcall(function() chassis:SetNetworkOwnershipAuto() end)
			for _, h in chassis:GetChildren() do
				if h:IsA("HingeConstraint") then
					if h.ActuatorType == Enum.ActuatorType.Motor then
						h.AngularVelocity = 0
						h.MotorMaxTorque = 60000
					else
						h.TargetAngle = 0
					end
				end
			end
		end
	end)
end

-- cf = position on the ground, the car faces cf.LookVector
function Auto.bauen(cf, farbe, dachText)
	local vorlage = game:GetService("ServerStorage"):FindFirstChild("Limousine")
	local rund = vorlage ~= nil
	local m = Instance.new("Model")
	m.Name = "Fahrschulauto"
	m:SetAttribute("Fahrschulauto", true)
	for name, wert in Auto.EINSTELLUNGEN do
		m:SetAttribute(name, wert)
	end
	m:SetAttribute("Radius", R)
	m:SetAttribute("Radstand", ACHSE * 2)
	m:SetAttribute("Laenge", 16)
	local function at(x, y, z) return cf * CFrame.new(x, y, z) end

	local chassis = Instance.new("Part")
	chassis.Name = "Chassis"
	chassis.Size = Vector3.new(6, 0.8, 12)
	chassis.CFrame = at(0, R, 0)
	chassis.Transparency = 1
	chassis.CanCollide = false
	chassis.CustomPhysicalProperties = PhysicalProperties.new(3, 0.3, 0, 1, 1)
	chassis.RootPriority = 10
	chassis.Parent = m
	m.PrimaryPart = chassis

	-- body part welded to the chassis; kollision = can hit walls (only parts above the wheels)
	local function k(name, gr, lage, f, mat, opt)
		opt = opt or {}
		if rund and VERSTECKEN[name] then
			opt.transparenz = 1
			opt.schatten = false
		end
		local p = Instance.new(opt.klasse or "Part")
		p.Name = name
		p.Size = gr
		p.CFrame = lage
		p.Color = f
		p.Material = mat or Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Massless = true
		p.CanCollide = opt.kollision == true
		p.CastShadow = opt.schatten ~= false
		p.Transparency = opt.transparenz or 0
		if opt.form then p.Shape = opt.form end
		if f == farbe and p.Material == Enum.Material.SmoothPlastic then
			Auto.lack(p, farbe)
		elseif f == CHROM then
			p.Reflectance = 0.35
		end
		p.Parent = m
		local w = Instance.new("WeldConstraint")
		w.Part0 = chassis
		w.Part1 = p
		w.Parent = p
		return p
	end
	-- position on the round body (if available), otherwise the block position
	local function ort(schluessel, s, x, y, z)
		local p = rund and MESH_POS[schluessel]
		if p then return at(s * p[1], p[2], p[3]) end
		return at(x, y, z)
	end
	local function glas(name, gr, lage, klasse)
		local g = k(name, gr, lage, GLAS, Enum.Material.Glass, { transparenz = 0.55, klasse = klasse, schatten = false })
		g.Reflectance = 0.25
		return g
	end

	-- ---------- body (forward = -Z) ----------
	-- Only looks: everything here is massless, so the driving feel stays exactly the same.
	local KANTE = farbe:Lerp(Color3.new(0, 0, 0), 0.25)
	local BLINK_AUS = Color3.fromRGB(150, 95, 35)
	local function zylinderHoch(name, radius, hoehe, x, y, z, f, mat)
		return k(name, V3(hoehe, radius * 2, radius * 2), at(x, y, z) * CFrame.Angles(0, 0, math.rad(90)), f, mat, { form = Enum.PartType.Cylinder })
	end
	local function zylinderLaengs(name, radius, laenge, x, y, z, f, mat, opt)
		opt = opt or {}
		opt.form = Enum.PartType.Cylinder
		return k(name, V3(laenge, radius * 2, radius * 2), at(x, y, z) * CFrame.Angles(0, math.rad(90), 0), f, mat, opt)
	end

	-- lower body with cut-outs for the wheel arches and rounded corners
	k("Front", V3(6, 1.8, 1.0), at(0, 1.9, -6.8), farbe)
	k("Motorraum", V3(3.2, 1.8, 3.0), at(0, 1.9, -4.8), farbe)
	k("Haube", V3(7, 0.6, 4.5), at(0, 3.1, -5.05), farbe, nil, { kollision = true })
	k("Motorhaube", V3(6.8, 0.25, 4.4), at(0, 3.45, -5.0) * CFrame.Angles(math.rad(-4), 0, 0), farbe)
	k("Haubenlinie", V3(0.08, 0.05, 4.2), at(-1.6, 3.6, -5.0) * CFrame.Angles(math.rad(-4), 0, 0), KANTE, nil, { schatten = false })
	k("Haubenlinie", V3(0.08, 0.05, 4.2), at(1.6, 3.6, -5.0) * CFrame.Angles(math.rad(-4), 0, 0), KANTE, nil, { schatten = false })
	k("Heck", V3(6, 1.8, 1.0), at(0, 1.9, 6.8), farbe)
	k("Kofferraum_innen", V3(3.2, 1.8, 3.0), at(0, 1.9, 4.8), farbe)
	k("Kofferraum", V3(7, 0.6, 2.0), at(0, 3.1, 6.3), farbe, nil, { kollision = true })
	k("Kofferraumdeckel", V3(6.8, 0.25, 2.1), at(0, 3.45, 6.35), farbe)
	k("Spoilerkante", V3(6.4, 0.15, 0.35), at(0, 3.63, 7.22), farbe)
	k("Boden", V3(6.3, 0.3, 8.1), at(0, 1.15, 1.25), INNEN)
	for _, s in { -1, 1 } do
		-- rounded corners (front and rear)
		zylinderHoch("Ecke", 0.5, 1.8, s * 3.0, 1.9, -6.8, farbe)
		zylinderHoch("Ecke", 0.5, 1.8, s * 3.0, 1.9, 6.8, farbe)
		k("Seite", V3(0.35, 1.8, 6.6), at(s * 3.325, 1.9, 0), farbe)
		k("Seite_oben", V3(0.35, 0.6, 8.1), at(s * 3.325, 3.1, 1.25), farbe, nil, { kollision = true })
		k("Schweller", V3(0.25, 0.35, 6.6), at(s * 3.5, 1.1, 0), SCHWARZ)
		k("Sicke", V3(0.05, 0.1, 13), at(s * 3.53, 2.8, 0), KANTE, nil, { schatten = false })       -- side crease
		k("Zierleiste", V3(0.06, 0.08, 7.8), at(s * 3.52, 3.42, 1.25), CHROM, Enum.Material.Metal, { schatten = false })
		-- doors: seams and handles
		for _, z in { -0.6, 2.4 } do
			k("Tuerfuge", V3(0.05, 2.3, 0.08), at(s * 3.51, 2.25, z), SCHWARZ, nil, { schatten = false })
		end
		for _, z in { 0.2, 3.2 } do
			k("Griff", V3(0.1, 0.18, 0.7), ort(z < 1 and "Griff1" or "Griff2", s, s * 3.55, 3.0, z), CHROM, Enum.Material.Metal, { schatten = false })
		end
		-- mirrors with indicator repeater
		local spx = rund and -0.65 or 0
		k("Spiegelarm", V3(0.4, 0.2, 0.3), at(s * (3.55 + spx), 3.6, -2.3), SCHWARZ)
		k("Spiegel", V3(0.7, 0.55, 0.7), at(s * (3.95 + spx), 3.75, -2.3), farbe)
		k("Spiegelglas", V3(0.55, 0.4, 0.05), at(s * (3.95 + spx), 3.75, -1.94), SCHWARZ, Enum.Material.Glass, { schatten = false })
		k(s < 0 and "BlinkerL" or "BlinkerR", V3(0.45, 0.1, 0.05), at(s * (3.95 + spx), 3.55, -2.66), BLINK_AUS, nil, { schatten = false })
		-- front lights: headlight, daytime light strip, indicator, fog light
		local lampe = k("Scheinwerfer", V3(rund and 1.6 or 1.9, rund and 0.32 or 0.45, 0.3), ort("Scheinwerfer", s, s * 2.45, 2.95, -7.32) * CFrame.Angles(0, 0, rund and math.rad(s * 8) or 0), Color3.fromRGB(225, 232, 240), Enum.Material.Glass, { schatten = false })
		lampe.Reflectance = 0.4
		local licht = Instance.new("SpotLight")
		licht.Face = Enum.NormalId.Front
		licht.Angle = 55
		licht.Range = 45
		licht.Brightness = 1.2
		licht.Color = Color3.fromRGB(255, 245, 225)
		licht.Shadows = false
		licht.Parent = lampe
		k("Scheinwerferrahmen", V3(2.1, 0.6, 0.2), at(s * 2.45, 2.95, -7.27), SCHWARZ, nil, { schatten = false })
		k("Tagfahrlicht", V3(rund and 1.5 or 1.6, 0.08, 0.05), ort("Tagfahrlicht", s, s * 2.45, 3.22, -7.48) * CFrame.Angles(0, 0, rund and math.rad(s * 8) or 0), Color3.fromRGB(255, 255, 255), Enum.Material.Neon, { schatten = false })
		k(s < 0 and "BlinkerL" or "BlinkerR", V3(0.5, 0.3, 0.3), ort("BlinkerVorne", s, s * 3.2, 2.6, -7.25), BLINK_AUS, nil, { schatten = false })
		k("Nebelscheinwerfer", V3(0.6, 0.3, 0.08), ort("Nebelscheinwerfer", s, s * 2.6, 1.35, -7.83), Color3.fromRGB(215, 222, 232), Enum.Material.Glass, { schatten = false })
		-- rear lights: L-shaped tail light, indicator, reflector
		k("Ruecklicht", V3(rund and 2.0 or 2.0, rund and 0.4 or 0.55, 0.3), ort("Ruecklicht", s, s * 2.45, 2.95, 7.32), Color3.fromRGB(170, 15, 15), Enum.Material.Neon, { schatten = false })
		k("Ruecklicht_Seite", V3(0.3, 0.55, 1.1), at(s * 3.45, 2.95, 6.8), Color3.fromRGB(170, 15, 15), Enum.Material.Neon, { schatten = false })
		k("Ruecklicht_Klappe", V3(2.0, 0.3, 0.1), at(s * 2.1, 3.35, 7.43), Color3.fromRGB(150, 15, 15), Enum.Material.Neon, { schatten = false })
		k(s < 0 and "BlinkerL" or "BlinkerR", V3(0.55, 0.25, 0.1), ort("BlinkerHinten", s, s * 3.0, 2.55, 7.48), BLINK_AUS, nil, { schatten = false })
		k("Reflektor", V3(0.8, 0.18, 0.05), ort("Reflektor", s, s * 2.7, 1.5, 7.82), Color3.fromRGB(150, 20, 20), nil, { schatten = false })
		-- bumper corners
		zylinderHoch("Stossstangenecke", 0.25, 1.0, s * 3.3, 1.5, -7.55, farbe)
		zylinderHoch("Stossstangenecke", 0.25, 1.0, s * 3.3, 1.5, 7.55, farbe)
	end
	-- bumpers, grille, number plates
	k("Stossstange_vorne", V3(6.6, 1.0, 0.5), at(0, 1.5, -7.55), farbe, nil, { kollision = true })
	k("Stossstange_hinten", V3(6.6, 1.0, 0.5), at(0, 1.5, 7.55), farbe, nil, { kollision = true })
	local grill = k("Kuehlergrill", V3(rund and 3.4 or 4.2, rund and 1.25 or 0.7, 0.2), ort("Kuehlergrill", 1, 0, 2.45, -7.35), SCHWARZ)
	if rund then grill.Material = Enum.Material.DiamondPlate grill.Color = Color3.fromRGB(28, 28, 32) end
	k("Grillchrom", V3(rund and 3.5 or 4.2, 0.1, 0.06), ort("Kuehlergrill", 1, 0, 2.45, -7.35) * CFrame.new(0, rund and 0.66 or 0.37, -0.11), CHROM, Enum.Material.Metal, { schatten = false })
	k("Lufteinlass", V3(rund and 2.6 or 3.6, 0.35, 0.06), ort("Lufteinlass", 1, 0, 1.2, -7.82), SCHWARZ, nil, { schatten = false })
	k("Bremslicht_oben", V3(1.4, 0.15, 0.1), at(0, 5.55, 3.25), Color3.fromRGB(170, 15, 15), Enum.Material.Neon, { schatten = false })
	zylinderLaengs("Auspuff", 0.18, 0.5, 2.3, rund and MESH_POS.Auspuff[2] or 1.05, rund and MESH_POS.Auspuff[3] or 7.75, CHROM, Enum.Material.Metal)
	for _, seite in { { -7.83, Enum.NormalId.Front }, { 7.83, Enum.NormalId.Back } } do
		local schild = k("Kennzeichen", V3(2.6, 0.75, 0.08), ort(seite[1] < 0 and "KennzeichenVorne" or "KennzeichenHinten", 1, 0, 1.85, seite[1]), Color3.new(1, 1, 1), nil, { schatten = false })
		local g = Instance.new("SurfaceGui")
		g.Face = seite[2]
		g.Parent = schild
		local l = Instance.new("TextLabel")
		l.Size = UDim2.fromScale(1, 1)
		l.BackgroundTransparency = 1
		l.Text = "DS 2026"
		l.Font = Enum.Font.GothamBold
		l.TextScaled = true
		l.TextColor3 = Color3.fromRGB(20, 20, 20)
		l.Parent = g
	end

	-- ---------- cabin: pillars, roof, glass ----------
	local SCHRAEG_V = math.rad(-43.8)  -- windshield angle
	local SCHRAEG_H = math.rad(43.7)   -- rear window angle
	glas("Frontscheibe", V3(6.3, 0.12, 3.32), at(0, 4.55, -1.6) * CFrame.Angles(SCHRAEG_V, 0, 0))
	glas("Heckscheibe", V3(6.3, 0.12, 3.04), at(0, 4.65, 4.3) * CFrame.Angles(SCHRAEG_H, 0, 0))
	k("Dach", V3(6.1, 0.35, 3.7), at(0, 5.85, 1.4), farbe, nil, { kollision = true })
	for _, s in { -1, 1 } do
		zylinderLaengs("Dachkante", 0.2, 3.7, s * 3.05, 5.82, 1.4, farbe)
		k("Fensterrahmen", V3(0.14, 0.14, 3.5), at(s * 3.25, 5.62, 1.4), SCHWARZ, nil, { schatten = false })
	end
	for _, s in { -1, 1 } do
		k("A_Saeule", V3(0.35, 0.35, 3.32), at(s * 3.2, 4.55, -1.6) * CFrame.Angles(SCHRAEG_V, 0, 0), farbe)
		k("C_Saeule", V3(0.35, 0.35, 3.04), at(s * 3.2, 4.65, 4.3) * CFrame.Angles(SCHRAEG_H, 0, 0), farbe)
		k("B_Saeule", V3(0.3, 2.3, 0.4), at(s * 3.25, 4.55, 1.0), SCHWARZ)
		glas("Seitenscheibe", V3(0.12, 2.3, 3.6), at(s * 3.28, 4.55, 1.4))
		glas("Dreieck_vorne", V3(0.12, 2.3, 2.4), at(s * 3.28, 4.55, -1.6), "WedgePart")
		glas("Dreieck_hinten", V3(0.12, 2.1, 2.2), at(s * 3.28, 4.45, 4.3) * CFrame.Angles(0, math.pi, 0), "WedgePart")
	end

	-- ---------- interior ----------
	k("Armaturenbrett", V3(6.2, 0.8, 1.2), at(0, 3.4, -2.3), INNEN)
	k("Tacho", V3(1.4, 0.5, 0.1), at(-1.5, 3.85, -1.75), SCHWARZ, Enum.Material.Neon, { schatten = false })
	k("Lenkrad", V3(0.15, 1.4, 1.4), at(-1.5, 3.85, -1.45) * CFrame.Angles(math.rad(-25), math.rad(90), 0), SCHWARZ, nil, { form = Enum.PartType.Cylinder })
	k("Mittelkonsole", V3(1.0, 1.0, 3.0), at(0, 1.8, -0.4), INNEN)
	k("Display", V3(1.2, 0.7, 0.08), at(0, 3.95, -1.72) * CFrame.Angles(math.rad(-15), 0, 0), Color3.fromRGB(40, 80, 140), Enum.Material.Neon, { schatten = false })
	k("Schalthebel", V3(0.2, 0.6, 0.2), at(0, 2.55, -0.9), SCHWARZ, nil, { schatten = false })
	for _, x in { -1.5, 1.5 } do
		k("Sitzflaeche", V3(2.2, 0.5, 2.2), at(x, 1.55, 0.6), INNEN, Enum.Material.Fabric)
		k("Rueckenlehne", V3(2.2, 2.6, 0.45), at(x, 2.9, 1.85) * CFrame.Angles(math.rad(-10), 0, 0), INNEN, Enum.Material.Fabric)
		k("Kopfstuetze", V3(1.3, 0.8, 0.4), at(x, 4.55, 2.15), INNEN, Enum.Material.Fabric)
	end
	k("Ruecksitzbank", V3(6, 0.5, 2.0), at(0, 1.55, 3.6), INNEN, Enum.Material.Fabric)
	k("Ruecksitzlehne", V3(6, 2.4, 0.45), at(0, 2.8, 4.7) * CFrame.Angles(math.rad(-12), 0, 0), INNEN, Enum.Material.Fabric)

	-- ---------- roof sign "STUDENT DRIVER" ----------
	local dach = k("Dachschild", V3(3.8, 1.3, 0.9), at(0, 6.7, 1.4), Color3.fromRGB(245, 205, 40))
	for _, gesicht in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local g = Instance.new("SurfaceGui")
		g.Face = gesicht
		g.Parent = dach
		local l = Instance.new("TextLabel")
		l.Size = UDim2.fromScale(1, 1)
		l.BackgroundTransparency = 1
		l.Text = dachText or "DRIVING SCHOOL\nSTUDENT DRIVER"
		l.Font = Enum.Font.GothamBlack
		l.TextScaled = true
		l.TextColor3 = Color3.fromRGB(20, 20, 20)
		l.Parent = g
	end

	-- ---------- round body from the 3D model ----------
	if rund then
		local KANTE_R = farbe:Lerp(Color3.new(0, 0, 0), 0.3)
		for _, s in { -1, 1 } do
			local sl = MESH_POS.Schulterlinie
			k("Schulterlinie", V3(0.05, 0.07, 10.5), at(s * sl[1], sl[2], sl[3]), KANTE_R, nil, { schatten = false })
			k("Grillrahmen", V3(0.08, 1.3, 0.08), ort("Kuehlergrill", 1, 0, 2.45, -7.35) * CFrame.new(s * 1.72, 0, -0.11), CHROM, Enum.Material.Metal, { schatten = false })
		end
		local hs, bl = MESH_POS.Heckspoiler, MESH_POS.DrittesBremslicht
		k("Heckspoiler", V3(5.2, 0.1, 0.5), at(hs[1], hs[2], hs[3]) * CFrame.Angles(math.rad(-6), 0, 0), farbe)
		k("Bremslicht_oben_rund", V3(1.4, 0.1, 0.12), at(bl[1], bl[2], bl[3]), Color3.fromRGB(170, 15, 15), Enum.Material.Neon, { schatten = false })
		local function suche(name)
			for _, t in vorlage:GetDescendants() do
				if t:IsA("MeshPart") and string.find(string.lower(t.Name), string.lower(name), 1, true) then
					return t
				end
			end
		end
		for name, d in MESH do
			local quelle = suche(name)
			if quelle then
				local mp = quelle:Clone()
				mp.Name = "Rund_" .. name
				mp.Anchored = false
				mp.CanCollide = false
				mp.CanTouch = false
				mp.Massless = true
				mp.Size = d.groesse
				mp.CFrame = at(d.mitte.X, d.mitte.Y, d.mitte.Z) * CFrame.Angles(0, math.rad(Auto.MESH_DREHUNG), 0)
				if name == "Glas" then
					mp.Color = GLAS
					mp.Material = Enum.Material.Glass
					mp.Transparency = 0.45
					mp.Reflectance = 0.3
					mp.CastShadow = false
				else
					mp.Color = farbe
					Auto.lack(mp, farbe)
					mp.Transparency = 0
				end
				for _, kind in mp:GetChildren() do
					if kind:IsA("SurfaceAppearance") or kind:IsA("Decal") or kind:IsA("Texture") then kind:Destroy() end
				end
				pcall(function() mp.TextureID = "" end)
				mp.Parent = m
				local w = Instance.new("WeldConstraint")
				w.Part0, w.Part1 = chassis, mp
				w.Parent = mp
			end
		end
	end

	-- ---------- seats (low enough that the character fits under the roof) ----------
	local sitz = Instance.new("VehicleSeat")
	sitz.Name = "Fahrersitz"
	sitz.Size = Vector3.new(2, 0.4, 2)
	sitz.CFrame = at(-1.5, 1.6, 0.5)
	sitz.Transparency = 1
	sitz.CanCollide = false
	sitz.Massless = true
	sitz.HeadsUpDisplay = false
	sitz.MaxSpeed = 0
	sitz.Torque = 0
	sitz.Parent = m
	local w1 = Instance.new("WeldConstraint")
	w1.Part0, w1.Part1 = chassis, sitz
	w1.Parent = sitz

	local beifahrer = Instance.new("Seat")
	beifahrer.Name = "Beifahrersitz"
	beifahrer.Size = Vector3.new(2, 0.4, 2)
	beifahrer.CFrame = at(1.5, 1.6, 0.5)
	beifahrer.Transparency = 1
	beifahrer.CanCollide = false
	beifahrer.Massless = true
	beifahrer.Parent = m
	local w2 = Instance.new("WeldConstraint")
	w2.Part0, w2.Part1 = chassis, beifahrer
	w2.Parent = beifahrer

	local ruecksitz = Instance.new("Seat") -- for the examiner in the driving test
	ruecksitz.Name = "Ruecksitz"
	ruecksitz.Size = Vector3.new(2, 0.4, 2)
	ruecksitz.CFrame = at(1.5, 1.6, 3.4)
	ruecksitz.Transparency = 1
	ruecksitz.CanCollide = false
	ruecksitz.Massless = true
	ruecksitz.Parent = m
	local w3 = Instance.new("WeldConstraint")
	w3.Part0, w3.Part1 = chassis, ruecksitz
	w3.Parent = ruecksitz

	-- ---------- wheels ----------
	local reifen = PhysicalProperties.new(0.9, 2, 0, 100, 1)
	local function rad(x, z)
		local r = Instance.new("Part")
		r.Name = "Rad"
		r.Shape = Enum.PartType.Cylinder
		r.Size = Vector3.new(1.1, 2 * R, 2 * R)
		r.CFrame = at(x, R, z)
		r.Color = SCHWARZ
		r.CustomPhysicalProperties = reifen
		r.Parent = m
		local felge = Instance.new("Part")
		felge.Name = "Felge"
		felge.Shape = Enum.PartType.Cylinder
		felge.Size = Vector3.new(1.14, R * 1.2, R * 1.2)
		felge.CFrame = r.CFrame
		felge.Color = CHROM
		felge.Material = Enum.Material.Metal
		felge.CanCollide = false
		felge.Massless = true
		felge.Parent = m
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = r, felge
		w.Parent = felge
		-- five spokes and a hub on the outside of the wheel
		local aussen = x < 0 and -1 or 1
		local function felgenteil(name, gr, lage, f)
			local t = Instance.new("Part")
			t.Name = name
			t.Size = gr
			t.CFrame = lage
			t.Color = f
			t.Material = Enum.Material.Metal
			t.CanCollide = false
			t.Massless = true
			t.CastShadow = false
			t.Parent = m
			local tw = Instance.new("WeldConstraint")
			tw.Part0, tw.Part1 = r, t
			tw.Parent = t
		end
		for i = 0, 4 do
			felgenteil("Speiche", Vector3.new(0.08, 0.28, R * 0.95), r.CFrame * CFrame.Angles(math.rad(i * 72), 0, 0) * CFrame.new(aussen * 0.6, 0, R * 0.42), Color3.fromRGB(150, 150, 155))
		end
		felgenteil("Nabe", Vector3.new(0.1, 0.45, 0.45), r.CFrame * CFrame.new(aussen * 0.62, 0, 0), Color3.fromRGB(60, 60, 65))
		return r
	end

	for _, s in { -1, 1 } do
		local seite = s < 0 and "L" or "R"
		-- rear wheel with motor
		local hinten = rad(s * SPUR, ACHSE)
		local motor = Instance.new("HingeConstraint")
		motor.Name = "Motor" .. seite
		motor.Attachment0 = anhang(chassis, "HintenA" .. seite, CFrame.new(s * SPUR, 0, ACHSE))
		motor.Attachment1 = anhang(hinten, "Achse", CFrame.new())
		motor.ActuatorType = Enum.ActuatorType.Motor
		motor.MotorMaxTorque = 20000   -- parked = brake
		motor.AngularVelocity = 0
		motor.Parent = chassis

		-- front wheel on a steering knuckle
		local kx = s * (SPUR - 0.6)
		local knoten = Instance.new("Part")
		knoten.Name = "Lenkknoten" .. seite
		knoten.Size = Vector3.new(0.8, 0.8, 0.8)
		knoten.CFrame = at(kx, R, -ACHSE)
		knoten.Transparency = 1
		knoten.CanCollide = false
		knoten.CustomPhysicalProperties = PhysicalProperties.new(4, 0.3, 0, 1, 1) -- not too light, so the front axle stays stiff
		knoten.Parent = m
		local hoch = CFrame.Angles(0, 0, math.rad(90)) -- hinge axis pointing up
		local servo = Instance.new("HingeConstraint")
		servo.Name = "Lenkung" .. seite
		servo.Attachment0 = anhang(chassis, "LenkungA" .. seite, CFrame.new(kx, 0, -ACHSE) * hoch)
		servo.Attachment1 = anhang(knoten, "LenkungB", hoch)
		servo.ActuatorType = Enum.ActuatorType.Servo
		servo.ServoMaxTorque = 200000
		servo.AngularSpeed = 12
		servo.TargetAngle = 0
		servo.Parent = chassis

		local vorne = rad(s * SPUR, -ACHSE)
		local frei = Instance.new("HingeConstraint")
		frei.Name = "Vorderrad" .. seite
		frei.Attachment0 = anhang(knoten, "RadA", CFrame.new(s * 0.6, 0, 0))
		frei.Attachment1 = anhang(vorne, "Achse", CFrame.new())
		frei.Parent = knoten
	end

	Auto.sitzeEinrichten(m, chassis, sitz, { beifahrer, ruecksitz }, CFrame.new(-6, 3, 0.5))

	return m, sitz, beifahrer, chassis, ruecksitz
end

-- ---------------------------------------------------------------
-- Truck (class C): cab with three seats and a box body with a rear door ("Heckklappe").
-- Same client-side driving as the car, just heavier, slower and with a longer wheelbase.
-- ---------------------------------------------------------------
-- Truck sizes (the delivery job unlocks bigger trucks). Trucks are slower and accelerate
-- much more gently than the car; the bigger the truck, the heavier and slower it gets.
Auto.LKW_STUFEN = {
	{ name = "Box Truck", koffer = 19, achse = 6, MaxTempo = 70, Antrieb = 6500, Bremse = 30000, Lenkwinkel = 38 },
	{ name = "Heavy Truck", koffer = 24, achse = 7.5, MaxTempo = 64, Antrieb = 8000, Bremse = 34000, Lenkwinkel = 36 },
	{ name = "Mega Truck", koffer = 29, achse = 9, MaxTempo = 58, Antrieb = 9500, Bremse = 38000, Lenkwinkel = 35 },
}
Auto.LKW_EINSTELLUNGEN = { RICHTUNG = 1, Grip = 14, Lenkdirekt = 9, Anpressdruck = 60 }

function Auto.bauenLkw(cf, farbe, aufschrift, stufe)
	local S = Auto.LKW_STUFEN[stufe or 1] or Auto.LKW_STUFEN[1]
	local RL = 1.8        -- wheel radius
	local SPUR_L = 3.5    -- half track width
	local A = S.achse     -- axles at -A (front) and +A (rear)
	local F = -A          -- front axle
	local K = S.koffer    -- length of the box body
	local R = F + 2.5 + K -- rear end of the truck
	local m = Instance.new("Model")
	m.Name = "Lkw"
	m:SetAttribute("Fahrschulauto", true) -- works with the indicators like the car
	m:SetAttribute("Lkw", true)
	m:SetAttribute("Stufe", stufe or 1)
	for name, wert in Auto.LKW_EINSTELLUNGEN do
		m:SetAttribute(name, wert)
	end
	for _, name in { "MaxTempo", "Antrieb", "Bremse", "Lenkwinkel" } do
		m:SetAttribute(name, S[name])
	end
	m:SetAttribute("Radius", RL)
	m:SetAttribute("Radstand", A * 2)
	m:SetAttribute("Laenge", R - (F - 4.6))
	m:SetAttribute("VorneZ", F - 4.6)
	m:SetAttribute("HintenZ", R)
	local function at(x, y, z) return cf * CFrame.new(x, y, z) end
	local function atK(x, y, z) return at(x, y, z + F + 6) end -- cab parts (designed for the front axle at -6)

	local chassis = Instance.new("Part")
	chassis.Name = "Chassis"
	chassis.Size = Vector3.new(6.5, 1, A * 2 + 6)
	chassis.CFrame = at(0, RL, 0)
	chassis.Transparency = 1
	chassis.CanCollide = false
	chassis.CustomPhysicalProperties = PhysicalProperties.new(3, 0.3, 0, 1, 1)
	chassis.RootPriority = 10
	chassis.Parent = m
	m.PrimaryPart = chassis

	local function k(name, gr, lage, f, mat, opt)
		opt = opt or {}
		local p = Instance.new(opt.klasse or "Part")
		p.Name = name
		p.Size = gr
		p.CFrame = lage
		p.Color = f
		p.Material = mat or Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Massless = true
		p.CanCollide = opt.kollision == true
		p.CastShadow = opt.schatten ~= false
		p.Transparency = opt.transparenz or 0
		if opt.form then p.Shape = opt.form end
		if f == farbe and p.Material == Enum.Material.SmoothPlastic then Auto.lack(p, farbe) end
		p.Parent = m
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = chassis, p
		w.Parent = p
		return p
	end
	local function glas(name, gr, lage)
		local g = k(name, gr, lage, GLAS, Enum.Material.Glass, { transparenz = 0.5, schatten = false })
		g.Reflectance = 0.25
		return g
	end
	local function schrift(teil, gesicht, t, farbeText)
		local g = Instance.new("SurfaceGui")
		g.Face = gesicht
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 25
		g.Parent = teil
		local l = Instance.new("TextLabel")
		l.Size = UDim2.fromScale(0.9, 0.4)
		l.Position = UDim2.fromScale(0.05, 0.3)
		l.BackgroundTransparency = 1
		l.Text = t
		l.Font = Enum.Font.GothamBlack
		l.TextScaled = true
		l.TextColor3 = farbeText
		l.Parent = g
	end
	local BLINK_AUS = Color3.fromRGB(150, 95, 35)

	-- ---------- cab (open inside, so you can look out in first person) ----------
	k("Kabinenboden", V3(8.2, 0.4, 6), atK(0, 3.6, -7.5), INNEN)
	k("Rueckwand", V3(8.2, 6.6, 0.4), atK(0, 7.1, -4.7), farbe)
	k("Kabinendach", V3(8.4, 0.5, 6.4), atK(0, 10.4, -7.5), farbe, nil, { kollision = true })
	k("Dachspoiler", V3(8.2, 1.6, 2.6), atK(0, 11.4, -5.9) * CFrame.Angles(math.rad(-12), 0, 0), farbe)
	k("Front", V3(8.2, 3.4, 0.4), atK(0, 5.3, -10.3), farbe, nil, { kollision = true })
	glas("Frontscheibe", V3(7.8, 3.4, 0.2), atK(0, 8.4, -10.3) * CFrame.Angles(math.rad(-6), 0, 0))
	k("Grill", V3(5.2, 2.2, 0.15), atK(0, 5.0, -10.55), SCHWARZ, Enum.Material.DiamondPlate)
	k("Stossstange", V3(8.4, 1.3, 0.7), atK(0, 2.7, -10.6), Color3.fromRGB(45, 45, 50), nil, { kollision = true })
	k("Firmenstreifen", V3(8.25, 0.5, 0.05), atK(0, 6.6, -10.53), Color3.fromRGB(255, 255, 255), nil, { schatten = false })
	if stufe and stufe >= 2 then
		-- bigger trucks: chrome bull bar and roof lights
		k("Rammschutz", V3(7.6, 0.3, 0.3), atK(0, 3.7, -10.95), CHROM, Enum.Material.Metal, { schatten = false })
		for i = -2, 2 do
			k("Dachlicht", V3(0.6, 0.35, 0.35), atK(i * 1.4, 10.8, -10.4), Color3.fromRGB(255, 190, 60), Enum.Material.Neon, { schatten = false })
		end
	end
	for _, s in { -1, 1 } do
		k("Kabinenseite", V3(0.4, 3.0, 6), atK(s * 4.0, 5.2, -7.5), farbe)
		glas("Seitenfenster", V3(0.2, 3.3, 4.2), atK(s * 4.0, 8.4, -8.4))
		k("Saeule", V3(0.4, 3.3, 1.8), atK(s * 4.0, 8.4, -5.4), farbe)
		k("Trittstufe", V3(0.8, 0.3, 1.6), atK(s * 4.1, 2.9, -7.6), SCHWARZ)
		k("Kotfluegel", V3(1.6, 0.4, 4.4), atK(s * 3.5, 4.0, -6), SCHWARZ)
		k("Spiegelarm", V3(0.8, 0.2, 0.2), atK(s * 4.5, 8.6, -9.6), SCHWARZ)
		k("Spiegel", V3(0.3, 1.8, 0.9), atK(s * 4.95, 8.3, -9.6), SCHWARZ)
		local lampe = k("Scheinwerfer", V3(1.6, 0.7, 0.2), atK(s * 3.0, 3.8, -10.55), Color3.fromRGB(230, 236, 245), Enum.Material.Neon, { schatten = false })
		local licht = Instance.new("SpotLight")
		licht.Face = Enum.NormalId.Front
		licht.Angle = 60
		licht.Range = 55
		licht.Brightness = 1.3
		licht.Color = Color3.fromRGB(255, 245, 225)
		licht.Shadows = false
		licht.Parent = lampe
		k(s < 0 and "BlinkerL" or "BlinkerR", V3(0.6, 0.5, 0.2), atK(s * 4.0, 3.8, -10.5), BLINK_AUS, nil, { schatten = false })
		k(s < 0 and "BlinkerL" or "BlinkerR", V3(0.15, 0.4, 0.8), atK(s * 4.22, 4.6, -9.2), BLINK_AUS, nil, { schatten = false })
	end
	-- inside
	k("Armaturenbrett", V3(7.6, 1.2, 1.2), atK(0, 6.2, -9.5), INNEN)
	k("Lenkrad", V3(0.15, 1.7, 1.7), atK(-2.2, 6.9, -8.8) * CFrame.Angles(math.rad(-35), math.rad(90), 0), SCHWARZ, nil, { form = Enum.PartType.Cylinder })
	k("Display", V3(1.1, 0.6, 0.08), atK(0, 6.95, -9.0) * CFrame.Angles(math.rad(-20), 0, 0), Color3.fromRGB(40, 80, 140), Enum.Material.Neon, { schatten = false })
	for _, x in { -2.4, 0, 2.4 } do
		k("Sitzflaeche", V3(2.0, 0.5, 2.0), atK(x, 4.1, -6.6), INNEN, Enum.Material.Fabric)
		k("Rueckenlehne", V3(2.0, 2.6, 0.4), atK(x, 5.5, -5.4) * CFrame.Angles(math.rad(-8), 0, 0), INNEN, Enum.Material.Fabric)
	end

	-- ---------- frame and box body ----------
	local rahmenVon, rahmenBis = F - 4, R - 0.5
	k("Rahmen", V3(5.6, 0.9, rahmenBis - rahmenVon), at(0, 2.6, (rahmenVon + rahmenBis) / 2), SCHWARZ)
	k("Tank", V3(3.2, 1.6, 1.6), at(-3.6, 2.9, F + 4.2) * CFrame.Angles(0, math.rad(90), 0), CHROM, Enum.Material.Metal, { form = Enum.PartType.Cylinder })
	local kofferMitte = F + 2.5 + K / 2
	local koffer = k("Koffer", V3(8.4, 8.6, K), at(0, 8.4, kofferMitte), Color3.fromRGB(245, 245, 245), nil, { kollision = true })
	for _, s in { -1, 1 } do
		k("Kofferleiste", V3(0.1, 0.7, K), at(s * 4.22, 4.6, kofferMitte), farbe, nil, { schatten = false })
		k("Kofferleiste", V3(0.1, 0.7, K), at(s * 4.22, 12.3, kofferMitte), farbe, nil, { schatten = false })
		k("Seitenschutz", V3(0.2, 1.0, 2 * A - 5), at(s * 4.0, 2.6, 0), Color3.fromRGB(170, 170, 175), Enum.Material.Metal)
	end
	if aufschrift then
		schrift(koffer, Enum.NormalId.Left, aufschrift, farbe)
		schrift(koffer, Enum.NormalId.Right, aufschrift, farbe)
	end
	local klappe = k("Heckklappe", V3(8.0, 8.2, 0.2), at(0, 8.4, R + 0.1), Color3.fromRGB(225, 225, 230), Enum.Material.DiamondPlate)
	for _, s in { -1, 1 } do
		k("Verschluss", V3(0.15, 7.6, 0.15), at(s * 1.2, 8.4, R + 0.25), Color3.fromRGB(120, 120, 125), Enum.Material.Metal, { schatten = false })
		k("Ruecklicht", V3(1.4, 0.6, 0.2), at(s * 3.3, 2.6, R - 0.5), Color3.fromRGB(170, 15, 15), Enum.Material.Neon, { schatten = false })
		k(s < 0 and "BlinkerL" or "BlinkerR", V3(0.8, 0.6, 0.2), at(s * 3.3, 3.3, R - 0.5), BLINK_AUS, nil, { schatten = false })
	end
	k("Unterfahrschutz", V3(7.6, 0.5, 0.4), at(0, 1.5, R - 0.6), Color3.fromRGB(170, 170, 175), Enum.Material.Metal)
	local schild = k("Kennzeichen", V3(2.6, 0.75, 0.08), at(0, 2.3, R - 0.35), Color3.new(1, 1, 1), nil, { schatten = false })
	schrift(schild, Enum.NormalId.Back, "PX 2026", Color3.fromRGB(20, 20, 20))
	m:SetAttribute("KlappeVersatz", R + 0.1)
	-- extra rear axles (only for looks)
	local extra = { A + 3.8 }
	if (stufe or 1) >= 3 then table.insert(extra, A + 7.6) end
	for _, z in extra do
		for _, s in { -1, 1 } do
			k("Rad", V3(1.3, RL * 2, RL * 2), at(s * SPUR_L, RL, z), SCHWARZ, nil, { form = Enum.PartType.Cylinder })
			k("Felge", V3(1.34, RL * 1.1, RL * 1.1), at(s * SPUR_L, RL, z), CHROM, Enum.Material.Metal, { form = Enum.PartType.Cylinder })
		end
	end

	-- ---------- seats: driver left, instructor right, examiner in the middle ----------
	local function sitzBauen(klasse, name, x)
		local s = Instance.new(klasse)
		s.Name = name
		s.Size = Vector3.new(2, 0.4, 2)
		s.CFrame = atK(x, 4.3, -6.6)
		s.Transparency = 1
		s.CanCollide = false
		s.Massless = true
		if klasse == "VehicleSeat" then
			s.HeadsUpDisplay = false
			s.MaxSpeed = 0
			s.Torque = 0
		end
		s.Parent = m
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = chassis, s
		w.Parent = s
		return s
	end
	local sitz = sitzBauen("VehicleSeat", "Fahrersitz", -2.4)
	local beifahrer = sitzBauen("Seat", "Beifahrersitz", 2.4)
	local mitte = sitzBauen("Seat", "Ruecksitz", 0)

	-- ---------- wheels (same hinge setup as the car) ----------
	local reifen = PhysicalProperties.new(0.9, 2, 0, 100, 1)
	local function rad(x, z)
		local r = Instance.new("Part")
		r.Name = "Rad"
		r.Shape = Enum.PartType.Cylinder
		r.Size = Vector3.new(1.3, 2 * RL, 2 * RL)
		r.CFrame = at(x, RL, z)
		r.Color = SCHWARZ
		r.CustomPhysicalProperties = reifen
		r.Parent = m
		local felge = Instance.new("Part")
		felge.Name = "Felge"
		felge.Shape = Enum.PartType.Cylinder
		felge.Size = Vector3.new(1.34, RL * 1.1, RL * 1.1)
		felge.CFrame = r.CFrame
		felge.Color = CHROM
		felge.Material = Enum.Material.Metal
		felge.CanCollide = false
		felge.Massless = true
		felge.Parent = m
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = r, felge
		w.Parent = felge
		return r
	end
	for _, s in { -1, 1 } do
		local seite = s < 0 and "L" or "R"
		local hinten = rad(s * SPUR_L, A)
		local motor = Instance.new("HingeConstraint")
		motor.Name = "Motor" .. seite
		motor.Attachment0 = anhang(chassis, "HintenA" .. seite, CFrame.new(s * SPUR_L, 0, A))
		motor.Attachment1 = anhang(hinten, "Achse", CFrame.new())
		motor.ActuatorType = Enum.ActuatorType.Motor
		motor.MotorMaxTorque = 60000
		motor.AngularVelocity = 0
		motor.Parent = chassis

		local kx = s * (SPUR_L - 0.7)
		local knoten = Instance.new("Part")
		knoten.Name = "Lenkknoten" .. seite
		knoten.Size = Vector3.new(0.8, 0.8, 0.8)
		knoten.CFrame = at(kx, RL, F)
		knoten.Transparency = 1
		knoten.CanCollide = false
		knoten.CustomPhysicalProperties = PhysicalProperties.new(6, 0.3, 0, 1, 1)
		knoten.Parent = m
		local hoch = CFrame.Angles(0, 0, math.rad(90))
		local servo = Instance.new("HingeConstraint")
		servo.Name = "Lenkung" .. seite
		servo.Attachment0 = anhang(chassis, "LenkungA" .. seite, CFrame.new(kx, 0, F) * hoch)
		servo.Attachment1 = anhang(knoten, "LenkungB", hoch)
		servo.ActuatorType = Enum.ActuatorType.Servo
		servo.ServoMaxTorque = 400000
		servo.AngularSpeed = 10
		servo.TargetAngle = 0
		servo.Parent = chassis

		local vorne = rad(s * SPUR_L, F)
		local frei = Instance.new("HingeConstraint")
		frei.Name = "Vorderrad" .. seite
		frei.Attachment0 = anhang(knoten, "RadA", CFrame.new(s * 0.7, 0, 0))
		frei.Attachment1 = anhang(vorne, "Achse", CFrame.new())
		frei.Parent = knoten
	end

	Auto.sitzeEinrichten(m, chassis, sitz, { beifahrer, mitte }, CFrame.new(-7.5, 2, F - 1))
	return m, sitz, beifahrer, chassis, mitte, klappe
end

-- ---------------------------------------------------------------
-- Cars from the dealership (Velocity Motors). Same client-side driving as the driving
-- school car (direct steering), only the power, top speed and grip differ.
-- ---------------------------------------------------------------
Auto.MODELLE = {
	kleinwagen = {
		name = "Zipster", art = "Small car", preis = 1500, beschreibung = "Small, cheap and nimble. Perfect first car.",
		R = 1.15, spur = 3.0, achse = 4.1, laenge = 12.5, breite = 6.6,
		werte = { MaxTempo = 105, Antrieb = 4200, Bremse = 13000, Lenkwinkel = 36, Grip = 14, Lenkdirekt = 15, Anpressdruck = 60 },
	},
	limousine = {
		name = "Executive", art = "Sedan", preis = 6000, beschreibung = "A long, comfortable business sedan with chrome details.",
		R = 1.35, spur = 3.3, achse = 5.6, laenge = 17, breite = 7.2,
		werte = { MaxTempo = 145, Antrieb = 5800, Bremse = 15000, Lenkwinkel = 33, Grip = 14, Lenkdirekt = 14, Anpressdruck = 65 },
	},
	supersport = {
		name = "Nova SS", art = "Supercar", preis = 60000, beschreibung = "The fastest road car in town. 225 km/h and blue underglow.",
		R = 1.25, spur = 3.5, achse = 5.2, laenge = 16.5, breite = 7.8,
		werte = { MaxTempo = 225, Antrieb = 10500, Bremse = 24000, Lenkwinkel = 31, Grip = 17, Lenkdirekt = 16, Anpressdruck = 90 },
	},
	suv = {
		name = "Ranger X", art = "SUV", preis = 3500, beschreibung = "Big, robust and comfortable. Sits high above the road.",
		R = 1.6, spur = 3.4, achse = 5.6, laenge = 17.5, breite = 7.4,
		werte = { MaxTempo = 120, Antrieb = 5200, Bremse = 15000, Lenkwinkel = 33, Grip = 13, Lenkdirekt = 13, Anpressdruck = 60 },
	},
	sport = {
		name = "Velocity GT", art = "Sports car", preis = 12000, beschreibung = "Low, fast and sharp. 170 km/h top speed.",
		R = 1.3, spur = 3.3, achse = 5.0, laenge = 15.5, breite = 7.2,
		werte = { MaxTempo = 170, Antrieb = 7200, Bremse = 18000, Lenkwinkel = 32, Grip = 16, Lenkdirekt = 15, Anpressdruck = 75 },
	},
	track = {
		name = "Striker TR", art = "Track car", preis = 22000, beschreibung = "A road-legal track coupe with a huge rear wing. 190 km/h top speed.",
		R = 1.35, spur = 3.45, achse = 5.3, laenge = 16.5, breite = 7.6,
		werte = { MaxTempo = 190, Antrieb = 8400, Bremse = 21000, Lenkwinkel = 31, Grip = 17, Lenkdirekt = 16, Anpressdruck = 88 },
	},
	gs = {
		name = "Vanta GS", art = "Sport sedan", preis = 16000, beschreibung = "A sleek four-door fastback with an LED light bar. 180 km/h top speed.",
		R = 1.4, spur = 3.0, achse = 5.14, laenge = 17.4, breite = 7.0,
		werte = { MaxTempo = 180, Antrieb = 7800, Bremse = 19000, Lenkwinkel = 32, Grip = 16, Lenkdirekt = 15, Anpressdruck = 80 },
	},
	-- exclusive (game pass "nacht" in Shop.lua): same body as the Vanta GS, own look and a bit more power
	gs_night = {
		name = "Vanta GS Night Edition", art = "Exclusive", preis = 0, wert = 20000, pass = "nacht", basis = "gs",
		beschreibung = "Exclusive: midnight black, gold rims, purple underglow. 195 km/h.",
		festeFarbe = Color3.fromRGB(18, 16, 24), tuning = { felgen = 3, neon = 4 },
		R = 1.4, spur = 3.0, achse = 5.14, laenge = 17.4, breite = 7.0,
		werte = { MaxTempo = 195, Antrieb = 8400, Bremse = 20000, Lenkwinkel = 32, Grip = 16, Lenkdirekt = 15, Anpressdruck = 82 },
	},
	renn = {
		name = "Apex R1", art = "Race car", preis = 35000, beschreibung = "A real race car with a huge rear wing. 210 km/h top speed.",
		R = 1.35, spur = 3.5, achse = 5.4, laenge = 17, breite = 7.8,
		werte = { MaxTempo = 210, Antrieb = 9500, Bremse = 22000, Lenkwinkel = 30, Grip = 18, Lenkdirekt = 16, Anpressdruck = 95 },
	},
}
Auto.MODELL_REIHENFOLGE = { "kleinwagen", "suv", "limousine", "sport", "gs", "track", "renn", "supersport", "gs_night" }

-- ---------------------------------------------------------------
-- Round bodies for private cars (own designs, made with tools/mesh/*.py -> dist/mesh/<vorlage>.obj).
-- Import the .obj with the 3D Importer and move the model (e.g. "RangerX") into ServerStorage.
-- If it is there, that car type uses it automatically; otherwise the block body is used.
-- ---------------------------------------------------------------
local KAROSSERIEN = require(script.Parent:WaitForChild("Karosserien"))
local ANBAU_ART = {
	lack = { mat = Enum.Material.SmoothPlastic },
	chrom = { farbe = CHROM, mat = Enum.Material.Metal },
	alu = { farbe = Color3.fromRGB(170, 170, 175), mat = Enum.Material.Metal },
	schwarz = { farbe = Color3.fromRGB(12, 12, 14), mat = Enum.Material.SmoothPlastic },
	carbon = { farbe = Color3.fromRGB(32, 32, 36), mat = Enum.Material.SmoothPlastic },
	grill = { farbe = Color3.fromRGB(25, 25, 28), mat = Enum.Material.DiamondPlate },
	scheinwerfer = { farbe = Color3.fromRGB(230, 236, 245), mat = Enum.Material.Neon },
	neon_weiss = { farbe = Color3.fromRGB(235, 235, 240), mat = Enum.Material.Neon },
	neon_rot = { farbe = Color3.fromRGB(170, 15, 15), mat = Enum.Material.Neon },
	blinker = { farbe = Color3.fromRGB(150, 95, 35), mat = Enum.Material.SmoothPlastic },
	fuge = { farbe = Color3.fromRGB(8, 8, 10), mat = Enum.Material.SmoothPlastic },
	glanzschwarz = { farbe = Color3.fromRGB(10, 10, 12), mat = Enum.Material.SmoothPlastic, glanz = 0.35 },
}

local function meshTeil(vorlage, name)
	for _, t in vorlage:GetDescendants() do
		if t:IsA("MeshPart") and t.Name == name then return t end
	end
	for _, t in vorlage:GetDescendants() do
		if t:IsA("MeshPart") and string.find(string.lower(t.Name), string.lower(name), 1, true) then
			return t
		end
	end
end

function Auto.bauenPrivat(cf, typ, farbe, kennzeichen)
	local D = Auto.MODELLE[typ] or Auto.MODELLE.suv
	local basis = D.basis or typ -- special editions use the body of their base car
	farbe = farbe or Color3.fromRGB(200, 30, 35)
	local R, SP, A = D.R, D.spur, D.achse
	local L, B = D.laenge, D.breite
	local m = Instance.new("Model")
	m.Name = "Privatauto"
	m:SetAttribute("Fahrschulauto", true) -- works with the indicators
	m:SetAttribute("Privat", true)
	m:SetAttribute("Typ", typ)
	m:SetAttribute("RICHTUNG", 1)
	for name, wert in D.werte do m:SetAttribute(name, wert) end
	m:SetAttribute("Radius", R)
	m:SetAttribute("Radstand", A * 2)
	m:SetAttribute("Laenge", L)
	local function at(x, y, z) return cf * CFrame.new(x, y, z) end

	local chassis = Instance.new("Part")
	chassis.Name = "Chassis"
	chassis.Size = Vector3.new(6, 0.8, 12)
	chassis.CFrame = at(0, R, 0)
	chassis.Transparency = 1
	chassis.CanCollide = false
	chassis.CustomPhysicalProperties = PhysicalProperties.new(3, 0.3, 0, 1, 1)
	chassis.RootPriority = 10
	chassis.Parent = m
	m.PrimaryPart = chassis

	local function k(name, gr, lage, f, mat, opt)
		opt = opt or {}
		local p = Instance.new(opt.klasse or "Part")
		p.Name = name
		p.Size = gr
		p.CFrame = lage
		p.Color = f
		p.Material = mat or Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Massless = true
		p.CanCollide = opt.kollision == true
		p.CastShadow = opt.schatten ~= false
		p.Transparency = opt.transparenz or 0
		if opt.form then p.Shape = opt.form end
		if f == farbe and p.Material == Enum.Material.SmoothPlastic then p.Reflectance = 0.15 end
		p.Parent = m
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = chassis, p
		w.Parent = p
		return p
	end
	local function glas(name, gr, lage, klasse)
		local g = k(name, gr, lage, GLAS, Enum.Material.Glass, { transparenz = 0.5, schatten = false, klasse = klasse })
		g.Reflectance = 0.3
		return g
	end
	local BLINK_AUS = Color3.fromRGB(150, 95, 35)
	local function lichter(y, vorne, hinten, abstand)
		for _, s in { -1, 1 } do
			local lampe = k("Scheinwerfer", V3(1.7, 0.45, 0.2), at(s * abstand, y, vorne), Color3.fromRGB(235, 240, 250), Enum.Material.Neon, { schatten = false })
			local licht = Instance.new("SpotLight")
			licht.Face = Enum.NormalId.Front
			licht.Angle = 55
			licht.Range = 50
			licht.Brightness = 1.2
			licht.Shadows = false
			licht.Parent = lampe
			k("Ruecklicht", V3(1.9, 0.4, 0.2), at(s * abstand, y + 0.2, hinten), Color3.fromRGB(180, 15, 15), Enum.Material.Neon, { schatten = false })
			k(s < 0 and "BlinkerL" or "BlinkerR", V3(0.5, 0.35, 0.22), at(s * (abstand + 1.2), y, vorne + 0.02), BLINK_AUS, nil, { schatten = false })
			k(s < 0 and "BlinkerL" or "BlinkerR", V3(0.5, 0.35, 0.22), at(s * (abstand + 1.2), y + 0.2, hinten - 0.02), BLINK_AUS, nil, { schatten = false })
		end
	end
	local KANTE = farbe:Lerp(Color3.new(0, 0, 0), 0.35)
	local sitzY = 1.6

	-- round body from the 3D model (only if the model was imported into ServerStorage)
	local rundDef = KAROSSERIEN[basis]
	local rundVorlage = rundDef and game:GetService("ServerStorage"):FindFirstChild(rundDef.vorlage)
	if rundVorlage and not meshTeil(rundVorlage, "Karosserie") then rundVorlage = nil end
	local function v3(t) return V3(t[1], t[2], t[3]) end
	local function rundBauen()
		if rundDef.sitzY then sitzY = rundDef.sitzY end
		-- invisible colliders (above the wheels, the wheels must never touch them)
		for _, kol in rundDef.kollision do
			k("Kollision", v3(kol.g), at(kol.p[1], kol.p[2], kol.p[3]), farbe, nil, { kollision = true, transparenz = 1, schatten = false })
		end
		for name, d in rundDef.mesh do
			local quelle = meshTeil(rundVorlage, name)
			if quelle then
				local mp = quelle:Clone()
				mp.Name = name == "Karosserie" and "Karosserie" or ("Rund_" .. name)
				mp.Anchored = false
				mp.CanCollide = false
				mp.CanTouch = false
				mp.Massless = true
				mp.Size = v3(d.groesse)
				mp.CFrame = at(d.mitte[1], d.mitte[2], d.mitte[3]) * CFrame.Angles(0, math.rad(rundDef.drehung or Auto.MESH_DREHUNG), 0)
				for _, kind in mp:GetChildren() do
					if kind:IsA("SurfaceAppearance") or kind:IsA("Decal") or kind:IsA("Texture") then kind:Destroy() end
				end
				pcall(function() mp.TextureID = "" end)
				if d.a then -- lights, grille, vents: surface pieces that follow the body
					local art = ANBAU_ART[d.a] or ANBAU_ART.schwarz
					mp.Name = d.n or name
					mp.Color = d.a == "lack" and farbe or art.farbe
					mp.Material = art.mat
					mp.Reflectance = art.glanz or 0
					mp.Transparency = 0
					mp.CastShadow = false
					if d.a == "scheinwerfer" then
						local licht = Instance.new("SpotLight")
						-- the mesh part may be turned around (drehung 180): then its front face points backwards
						licht.Face = ((rundDef.drehung or Auto.MESH_DREHUNG) % 360 == 180) and Enum.NormalId.Back or Enum.NormalId.Front
						licht.Angle = 55
						licht.Range = 50
						licht.Brightness = 1.2
						licht.Shadows = false
						licht.Parent = mp
					end
				elseif name == "Glas" then
					mp.Color = Color3.fromRGB(14, 17, 22) -- dark tinted glass, the cabin looks solid
					mp.Material = Enum.Material.Glass
					mp.Transparency = 0.12
					mp.Reflectance = 0.3
					mp.CastShadow = false
				elseif name == "Verkleidung" then
					mp.Color = Color3.fromRGB(28, 28, 31)
					mp.Material = Enum.Material.SmoothPlastic
					mp.Reflectance = 0
					mp.Transparency = 0
				else
					mp.Color = farbe
					Auto.lack(mp, farbe)
					mp.Transparency = 0
				end
				mp.Parent = m
				local w = Instance.new("WeldConstraint")
				w.Part0, w.Part1 = chassis, mp
				w.Parent = mp
			end
		end
		-- lights, grille, mirrors ... (positions come from the generator)
		for _, t in rundDef.anbau do
			local art = ANBAU_ART[t.a] or ANBAU_ART.schwarz
			for _, s in (t.s and { -1, 1 } or { 1 }) do
				local name = t.n
				if t.a == "blinker" then name = s < 0 and "BlinkerL" or "BlinkerR" end
				local lage = at(s * t.p[1], t.p[2], t.p[3])
				if t.r then lage *= CFrame.Angles(math.rad(t.r[1]), math.rad(s * t.r[2]), math.rad(s * t.r[3])) end
				if t.d then -- line along the body (panel gaps)
					local richtung = cf:VectorToWorldSpace(Vector3.new(s * t.d[1], t.d[2], t.d[3]))
					lage = CFrame.lookAt(lage.Position, lage.Position + richtung)
				end
				if t.f == "zyl" then lage *= CFrame.Angles(0, math.rad(90), 0) end -- round part along the car (exhausts)
				local teil = k(name, v3(t.g), lage, t.a == "lack" and farbe or art.farbe, art.mat, { schatten = t.a == "lack", form = t.f == "zyl" and Enum.PartType.Cylinder or nil })
				if t.a == "scheinwerfer" then
					local licht = Instance.new("SpotLight")
					licht.Face = Enum.NormalId.Front
					licht.Angle = 55
					licht.Range = 50
					licht.Brightness = 1.2
					licht.Shadows = false
					licht.Parent = teil
				end
			end
		end
		if rundDef.spoiler then
			m:SetAttribute("SpoilerAmDach", CFrame.new(0, rundDef.spoiler[1] - R, rundDef.spoiler[2])) -- relative to the chassis (spoiler tuning)
			if rundDef.spoiler[3] then m:SetAttribute("SpoilerStuetze", rundDef.spoiler[3]) end
		end
	end

	if basis == "kleinwagen" then
		sitzY = 1.7
		local unten = R + 0.35
		k("Karosserie", V3(B, 1.8, L - 0.6), at(0, unten + 0.9, 0), farbe)
		k("Kollision", V3(B, 0.8, L - 1), at(0, unten + 1.4, 0), farbe, nil, { kollision = true, transparenz = 1, schatten = false })
		k("Stossstange", V3(B - 0.2, 0.8, 0.5), at(0, unten + 0.3, -L / 2 + 0.2), SCHWARZ)
		k("Stossstange", V3(B - 0.2, 0.8, 0.5), at(0, unten + 0.3, L / 2 - 0.2), SCHWARZ)
		local oben = unten + 1.8
		k("Dach", V3(B - 0.7, 0.3, 6.6), at(0, oben + 2.2, 1.3), farbe, nil, { kollision = true })
		glas("Frontscheibe", V3(B - 0.8, 2.1, 1.8), at(0, oben + 1.05, -2.9), "WedgePart")
		glas("Seitenscheiben", V3(B - 0.6, 2.0, 6.4), at(0, oben + 1.05, 1.3))
		k("Heckklappe", V3(B - 0.7, 2.1, 0.4), at(0, oben + 1.05, L / 2 - 1.5), farbe)
		k("Dachspoiler", V3(B - 1, 0.2, 0.8), at(0, oben + 2.25, L / 2 - 1.6), SCHWARZ)
		lichter(unten + 1.1, -L / 2 + 0.3, L / 2 - 0.3, 2.3)
	elseif basis == "limousine" then
		if rundVorlage then
			rundBauen()
		else
		local unten = R + 0.25
		k("Karosserie", V3(B, 1.9, L - 0.8), at(0, unten + 0.95, 0), farbe)
		k("Kollision", V3(B, 0.6, L - 1), at(0, 2 * R + 0.45, 0), farbe, nil, { kollision = true, transparenz = 1, schatten = false })
		k("Kuehlergrill", V3(3.4, 1.0, 0.15), at(0, unten + 1.0, -L / 2 + 0.38), CHROM, Enum.Material.Metal)
		k("Stossstange", V3(B - 0.2, 0.7, 0.5), at(0, unten + 0.25, -L / 2 + 0.25), SCHWARZ)
		k("Stossstange", V3(B - 0.2, 0.7, 0.5), at(0, unten + 0.25, L / 2 - 0.25), SCHWARZ)
		local oben = unten + 1.9
		k("Dach", V3(B - 0.9, 0.3, 4.6), at(0, oben + 2.0, 0.8), farbe, nil, { kollision = true })
		glas("Frontscheibe", V3(B - 0.9, 1.9, 2.2), at(0, oben + 0.95, -2.6), "WedgePart")
		glas("Heckscheibe", V3(B - 0.9, 1.9, 2.4), at(0, oben + 0.95, 4.3) * CFrame.Angles(0, math.pi, 0), "WedgePart")
		glas("Seitenscheiben", V3(B - 0.8, 1.8, 4.6), at(0, oben + 0.95, 0.8))
		for _, s in { -1, 1 } do
			k("Zierleiste", V3(0.08, 0.12, L - 3), at(s * (B / 2 + 0.03), unten + 1.5, 0), CHROM, Enum.Material.Metal, { schatten = false })
		end
		lichter(unten + 1.2, -L / 2 + 0.4, L / 2 - 0.4, 2.6)
		end
	elseif basis == "supersport" then
		sitzY = 1.15
		local unten = R + 0.1
		k("Karosserie", V3(B, 1.45, L - 1), at(0, unten + 0.72, 0), farbe)
		k("Kollision", V3(B, 0.2, L - 1), at(0, 2 * R + 0.2, 0), farbe, nil, { kollision = true, transparenz = 1, schatten = false })
		k("Fronthaube", V3(B - 0.6, 0.6, 5), at(0, unten + 1.3, -L / 2 + 2.8) * CFrame.Angles(math.rad(-7), 0, 0), farbe)
		k("Frontsplitter", V3(B + 0.2, 0.15, 1.2), at(0, unten - 0.1, -L / 2 + 0.4), SCHWARZ)
		k("Motordeckel", V3(B - 1.6, 0.4, 4.5), at(0, unten + 1.6, 4.8), Color3.fromRGB(25, 25, 28))
		k("Heckfluegel", V3(B - 1, 0.18, 1.2), at(0, unten + 2.1, L / 2 - 0.8), SCHWARZ)
		k("Diffusor", V3(B - 1.4, 0.5, 0.8), at(0, unten + 0.15, L / 2 - 0.3), SCHWARZ)
		local kanzel = glas("Kanzel", V3(5.4, 1.5, 6), at(0, unten + 2.2, 0.5))
		kanzel.Color = Color3.fromRGB(25, 30, 40)
		kanzel.Transparency = 0.3
		glas("Frontscheibe", V3(5.2, 1.4, 2.2), at(0, unten + 2.15, -3.6), "WedgePart").Color = Color3.fromRGB(25, 30, 40)
		for _, s in { -1, 1 } do
			k("Lufteinlass", V3(0.2, 1.0, 2.6), at(s * (B / 2 + 0.02), unten + 0.9, 2.4), Color3.fromRGB(15, 15, 18))
			local glow = k("Unterbodenlicht", V3(0.3, 0.15, L - 4), at(s * (B / 2 - 1.2), unten - 0.2, 0), Color3.fromRGB(40, 120, 255), Enum.Material.Neon, { schatten = false })
			local licht = Instance.new("PointLight")
			licht.Color = Color3.fromRGB(40, 120, 255)
			licht.Range = 10
			licht.Brightness = 2
			licht.Parent = glow
		end
		lichter(unten + 0.9, -L / 2 + 0.5, L / 2 - 0.4, 2.6)
	elseif basis == "suv" then
		sitzY = 2.4
		if rundVorlage then
			rundBauen()
		else
			local unten = R + 0.5
			k("Karosserie", V3(B, 2.8, L - 1), at(0, unten + 1.4, 0), farbe)
			-- invisible collision box above the wheels (the wheels must never touch the body)
			k("Kollision", V3(B, 1.3, L - 1), at(0, 2 * R + 0.95, 0), farbe, nil, { kollision = true, transparenz = 1, schatten = false })
			k("Unterfahrschutz", V3(B - 1, 0.6, 1.2), at(0, unten + 0.1, -L / 2 + 0.6), Color3.fromRGB(150, 150, 155), Enum.Material.Metal)
			k("Stossstange", V3(B - 0.2, 1.1, 0.8), at(0, unten + 0.6, -L / 2 + 0.3), SCHWARZ)
			k("Stossstange", V3(B - 0.2, 1.1, 0.8), at(0, unten + 0.6, L / 2 - 0.3), SCHWARZ)
			k("Kuehlergrill", V3(4.2, 1.2, 0.15), at(0, unten + 1.9, -L / 2 + 0.45), Color3.fromRGB(40, 40, 45), Enum.Material.DiamondPlate)
			local oben = unten + 2.8
			k("Dach", V3(B - 0.6, 0.35, 8.8), at(0, oben + 2.75, 1.2), farbe, nil, { kollision = true })
			glas("Frontscheibe", V3(B - 0.8, 2.6, 1.6), at(0, oben + 1.3, -3.9), "WedgePart")
			glas("Seitenscheiben", V3(B - 0.5, 2.5, 8.6), at(0, oben + 1.3, 1.2))
			k("Heckteil", V3(B - 0.6, 2.6, 0.5), at(0, oben + 1.3, 5.6), farbe)
			for _, s in { -1, 1 } do
				k("Dachreling", V3(0.3, 0.3, 8), at(s * (B / 2 - 0.6), oben + 3.1, 1.2), Color3.fromRGB(170, 170, 175), Enum.Material.Metal)
				k("Saeule", V3(0.4, 2.6, 0.5), at(s * (B / 2 - 0.4), oben + 1.3, 0.2), farbe)
				k("Radlauf", V3(0.4, 1.0, 4.2), at(s * (B / 2 + 0.05), unten + 0.6, -A), SCHWARZ)
				k("Radlauf", V3(0.4, 1.0, 4.2), at(s * (B / 2 + 0.05), unten + 0.6, A), SCHWARZ)
				k("Trittbrett", V3(0.7, 0.25, 6), at(s * (B / 2 + 0.3), unten - 0.1, 0), Color3.fromRGB(60, 60, 65))
			end
			local reserve = k("Reserverad", V3(0.8, 2.6, 2.6), at(0, unten + 1.6, L / 2 + 0.2) * CFrame.Angles(0, math.rad(90), 0), SCHWARZ, nil, { form = Enum.PartType.Cylinder })
			reserve.CastShadow = false
			lichter(unten + 1.9, -L / 2 + 0.45, L / 2 - 0.45, 2.6)
		end
	elseif basis == "sport" then
		if rundVorlage then
			rundBauen()
		else
			local unten = R + 0.2
			k("Karosserie", V3(B, 1.5, L - 1), at(0, unten + 0.75, 0), farbe)
			k("Kollision", V3(B, 0.35, L - 1), at(0, 2 * R + 0.25, 0), farbe, nil, { kollision = true, transparenz = 1, schatten = false })
			k("Motorhaube", V3(B - 0.4, 0.8, 5.5), at(0, unten + 1.5 + 0.0, -L / 2 + 3.4) * CFrame.Angles(math.rad(-5), 0, 0), farbe)
			k("Frontlippe", V3(B, 0.25, 1.0), at(0, unten - 0.05, -L / 2 + 0.2), SCHWARZ)
			k("Heckdiffusor", V3(B - 1, 0.5, 0.8), at(0, unten + 0.1, L / 2 - 0.3), SCHWARZ)
			k("Lufteinlass", V3(3.6, 0.45, 0.1), at(0, unten + 0.5, -L / 2 + 0.5), Color3.fromRGB(20, 20, 22))
			local oben = unten + 1.5
			k("Dach", V3(B - 1.4, 0.3, 4.2), at(0, oben + 2.0, 1.2), farbe, nil, { kollision = true })
			glas("Frontscheibe", V3(B - 1.4, 1.9, 2.4), at(0, oben + 0.95, -2.1), "WedgePart")
			local heck = glas("Heckscheibe", V3(B - 1.4, 1.9, 3.2), at(0, oben + 0.95, 4.9) * CFrame.Angles(0, math.pi, 0), "WedgePart")
			heck.Color = Color3.fromRGB(30, 35, 45)
			glas("Seitenscheiben", V3(B - 1.3, 1.8, 4.2), at(0, oben + 0.95, 1.2))
			k("Heckspoiler", V3(B - 0.8, 0.2, 1.2), at(0, oben + 0.55, L / 2 - 0.8), SCHWARZ)
			for _, s in { -1, 1 } do
				k("Seitenschweller", V3(0.3, 0.4, L - 5), at(s * (B / 2 + 0.05), unten + 0.1, 0), SCHWARZ)
				k("Lufteinlass", V3(0.15, 0.8, 1.8), at(s * (B / 2 + 0.02), unten + 0.9, 2.2), Color3.fromRGB(20, 20, 22))
				k("Rennstreifen", V3(0.8, 0.05, L - 1), at(s * 0.8, unten + 1.52, 0), Color3.new(1, 1, 1), nil, { schatten = false })
				k("Auspuff", V3(0.6, 0.6, 0.6), at(s * 0.9, unten + 0.15, L / 2 - 0.05) * CFrame.Angles(0, math.rad(90), 0), CHROM, Enum.Material.Metal, { form = Enum.PartType.Cylinder })
			end
			lichter(unten + 1.0, -L / 2 + 0.45, L / 2 - 0.45, 2.5)
		end
	elseif basis == "track" then
		if rundVorlage then
			rundBauen()
		else
			-- simple block body until the round body (StrikerTR) is imported
			local unten = R + 0.15
			k("Karosserie", V3(B, 1.5, L - 1), at(0, unten + 0.75, 0), farbe)
			k("Kollision", V3(B, 0.35, L - 1), at(0, 2 * R + 0.25, 0), farbe, nil, { kollision = true, transparenz = 1, schatten = false })
			local oben = unten + 1.5
			k("Dach", V3(B - 1.6, 0.3, 3.6), at(0, oben + 1.8, 1.6), farbe, nil, { kollision = true })
			glas("Seitenscheiben", V3(B - 1.5, 1.6, 4.4), at(0, oben + 0.85, 1.4))
			k("Heckfluegel", V3(B - 0.6, 0.15, 1.3), at(0, oben + 1.4, L / 2 - 1.2), SCHWARZ)
			lichter(unten + 0.9, -L / 2 + 0.45, L / 2 - 0.45, 2.6)
		end
	elseif basis == "gs" then
		if rundVorlage then
			rundBauen()
		else
			-- simple block body until the round body (VantaGS) is imported
			sitzY = 1.3
			local unten = R + 0.1
			k("Karosserie", V3(B - 0.4, 1.7, L - 0.8), at(0, unten + 0.85, 0.3), farbe)
			k("Kollision", V3(B - 0.4, 0.4, L - 1.5), at(0, 2 * R + 0.3, 0.3), farbe, nil, { kollision = true, transparenz = 1, schatten = false })
			local oben = unten + 1.7
			k("Dach", V3(B - 1.6, 0.3, 4.4), at(0, oben + 1.6, 1.0), farbe, nil, { kollision = true })
			glas("Frontscheibe", V3(B - 1.6, 1.5, 2.6), at(0, oben + 0.75, -2.3), "WedgePart")
			glas("Seitenscheiben", V3(B - 1.5, 1.4, 4.4), at(0, oben + 0.75, 1.0))
			glas("Heckscheibe", V3(B - 1.6, 1.5, 3.8), at(0, oben + 0.75, 5.1) * CFrame.Angles(0, math.rad(180), 0), "WedgePart")
			lichter(unten + 1.0, -L / 2 + 0.6, L / 2 - 0.2, 2.4)
		end
	else -- race car
		sitzY = 1.2
		local unten = R + 0.05
		k("Karosserie", V3(B - 1.2, 1.2, L - 1), at(0, unten + 0.6, 0), farbe)
		k("Kollision", V3(B - 0.4, 0.3, L - 1), at(0, 2 * R + 0.2, 0), farbe, nil, { kollision = true, transparenz = 1, schatten = false })
		k("Nase", V3(B - 2.6, 0.7, 3), at(0, unten + 0.7, -L / 2 + 1.3) * CFrame.Angles(math.rad(-8), 0, 0), farbe)
		k("Frontsplitter", V3(B + 0.4, 0.15, 1.6), at(0, unten - 0.3, -L / 2 + 0.6), SCHWARZ)
		k("Diffusor", V3(B - 1.5, 0.6, 1.2), at(0, unten + 0.1, L / 2 - 0.4), SCHWARZ)
		for _, s in { -1, 1 } do
			k("Seitenkasten", V3(1.4, 1.1, 7), at(s * (B / 2 - 0.9), unten + 0.6, 1.2), farbe)
			k("Kuehleroeffnung", V3(1.2, 0.6, 0.1), at(s * (B / 2 - 0.9), unten + 0.7, -2.35), Color3.fromRGB(20, 20, 22))
			k("Kotfluegel", V3(1.4, 0.5, 3.6), at(s * SP, unten + 1.4, -A), farbe)
			k("Kotfluegel", V3(1.4, 0.5, 3.6), at(s * SP, unten + 1.4, A), farbe)
			k("Fluegelstuetze", V3(0.25, 2.6, 0.8), at(s * 1.8, unten + 2.3, L / 2 - 1.2), SCHWARZ)
			k("Endplatte", V3(0.15, 1.6, 2.4), at(s * (B / 2 - 0.2), unten + 3.4, L / 2 - 1.2), farbe)
		end
		local fluegel = k("Heckfluegel", V3(B - 0.3, 0.25, 2.2), at(0, unten + 3.7, L / 2 - 1.2) * CFrame.Angles(math.rad(8), 0, 0), SCHWARZ)
		fluegel.CastShadow = true
		local kanzel = glas("Kanzel", V3(3.6, 1.4, 4.6), at(0, unten + 1.9, 0.3))
		kanzel.Color = Color3.fromRGB(25, 30, 40)
		kanzel.Transparency = 0.35
		k("Airbox", V3(1.2, 1.2, 3), at(0, unten + 2.1, 3.6), farbe)
		k("Ueberrollbuegel", V3(3.4, 0.3, 0.3), at(0, unten + 2.65, 2.5), SCHWARZ)
		-- start number on both sides and the nose
		for _, ziel in { { "Seitenkasten", Enum.NormalId.Right }, { "Karosserie", Enum.NormalId.Top } } do
			for _, t in m:GetChildren() do
				if t.Name == ziel[1] then
					local g = Instance.new("SurfaceGui")
					g.Face = ziel[2]
					g.Parent = t
					local l = Instance.new("TextLabel")
					l.Size = UDim2.fromScale(1, 1)
					l.BackgroundTransparency = 1
					l.Text = "07"
					l.Font = Enum.Font.GothamBlack
					l.TextScaled = true
					l.TextColor3 = Color3.new(1, 1, 1)
					l.Parent = g
					break
				end
			end
		end
		lichter(unten + 0.7, -L / 2 + 0.6, L / 2 - 0.3, 2.3)
	end
	-- number plates front and back
	if kennzeichen then
		for _, ende in { { -L / 2 + 0.05, Enum.NormalId.Front }, { L / 2 - 0.05, Enum.NormalId.Back } } do
			local lage = at(0, R + 0.9, ende[1] + (ende[1] < 0 and -0.12 or 0.12))
			if rundVorlage then
				local q = rundDef.kennzeichen[ende[1] < 0 and "vorne" or "hinten"]
				lage = at(0, q[1], q[2])
			end
			local schild = k("Kennzeichen", V3(2.6, 0.7, 0.1), lage, Color3.new(1, 1, 1), nil, { schatten = false })
			local g = Instance.new("SurfaceGui")
			g.Face = ende[2]
			g.Parent = schild
			local streifen = Instance.new("Frame")
			streifen.Size = UDim2.fromScale(0.12, 1)
			streifen.BackgroundColor3 = Color3.fromRGB(20, 60, 170)
			streifen.BorderSizePixel = 0
			streifen.Parent = g
			local l = Instance.new("TextLabel")
			l.Position = UDim2.fromScale(0.14, 0)
			l.Size = UDim2.fromScale(0.84, 1)
			l.BackgroundTransparency = 1
			l.Text = kennzeichen
			l.Font = Enum.Font.GothamBold
			l.TextScaled = true
			l.TextColor3 = Color3.fromRGB(20, 20, 20)
			l.Parent = g
		end
		m:SetAttribute("Kennzeichen", kennzeichen)
	end

	-- dashboard and steering wheel (all cars)
	local armZ = rundVorlage and rundDef.armaturenZ or -1.9
	local sx = rundVorlage and rundDef.sitzX or 1.5 -- narrow bodies seat closer to the middle (arms stay inside the doors)
	k("Armaturenbrett", V3(5.6, 0.7, 1.0), at(0, sitzY + 1.6, armZ), INNEN)
	k("Lenkrad", V3(0.15, 1.3, 1.3), at(-sx, sitzY + 2.1, armZ + 0.5) * CFrame.Angles(math.rad(-25), math.rad(90), 0), SCHWARZ, nil, { form = Enum.PartType.Cylinder })
	for _, x in { -sx, sx } do
		k("Sitz", V3(2.1, 0.5, 2.1), at(x, sitzY - 0.1, 0.6), INNEN, Enum.Material.Fabric)
		k("Rueckenlehne", V3(2.1, 2.4, 0.4), at(x, sitzY + 1.1, 1.8) * CFrame.Angles(math.rad(-12), 0, 0), basis == "renn" and Color3.fromRGB(180, 30, 30) or INNEN, Enum.Material.Fabric)
		k("Kopfstuetze", V3(1.2, 0.7, 0.35), at(x, sitzY + 2.55, 2.05) * CFrame.Angles(math.rad(-12), 0, 0), INNEN, Enum.Material.Fabric)
	end
	-- a bit of interior that you can see through the windows
	k("Mittelkonsole", V3(0.8, 0.9, 2.6), at(0, sitzY + 0.35, armZ + 1.6), Color3.fromRGB(35, 35, 38))
	k("Tacho", V3(1.2, 0.45, 0.06), at(-sx, sitzY + 2.1, armZ + 0.3) * CFrame.Angles(math.rad(-25), 0, 0), Color3.fromRGB(60, 160, 255), Enum.Material.Neon, { schatten = false })

	-- seats
	local function sitzBauen(klasse, name, x)
		local s = Instance.new(klasse)
		s.Name = name
		s.Size = Vector3.new(2, 0.4, 2)
		s.CFrame = at(x, sitzY, 0.5)
		s.Transparency = 1
		s.CanCollide = false
		s.Massless = true
		if klasse == "VehicleSeat" then
			s.HeadsUpDisplay = false
			s.MaxSpeed = 0
			s.Torque = 0
		end
		s.Parent = m
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = chassis, s
		w.Parent = s
		return s
	end
	local sitz = sitzBauen("VehicleSeat", "Fahrersitz", -sx)
	local beifahrer = sitzBauen("Seat", "Beifahrersitz", sx)

	-- wheels (same hinge setup as the driving school car)
	local reifen = PhysicalProperties.new(0.9, 2, 0, 100, 1)
	local felgenFarbe = basis == "renn" and Color3.fromRGB(40, 40, 45) or (basis == "sport" and Color3.fromRGB(45, 45, 50) or (basis == "gs" and Color3.fromRGB(95, 97, 104) or CHROM))
	-- spoke rims and brake calipers: only looks, all massless and without collision (driving feel unchanged)
	local SPEICHEN = { kleinwagen = 4, suv = 6, limousine = 5, sport = 5, track = 5, gs = 10, renn = 6, supersport = 10 }
	local SATTEL_FARBE = {
		sport = Color3.fromRGB(235, 175, 20), renn = Color3.fromRGB(200, 25, 30), supersport = Color3.fromRGB(200, 25, 30),
		track = Color3.fromRGB(235, 95, 20), gs = Color3.fromRGB(240, 140, 25),
		suv = Color3.fromRGB(70, 70, 75), limousine = Color3.fromRGB(70, 70, 75), kleinwagen = Color3.fromRGB(70, 70, 75),
	}
	local function deko(name, gr, lage, farbeT, mat, an, form)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = gr
		p.CFrame = lage
		p.Color = farbeT
		p.Material = mat or Enum.Material.SmoothPlastic
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Massless = true
		p.CastShadow = false
		if form then p.Shape = form end
		p.Parent = m
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = an, p
		w.Parent = p
		return p
	end
	local function rad(x, z, halter)
		local r = Instance.new("Part")
		r.Name = "Rad"
		r.Shape = Enum.PartType.Cylinder
		r.Size = Vector3.new(basis == "suv" and 1.3 or 1.2, 2 * R, 2 * R)
		r.CFrame = at(x, R, z)
		r.Color = SCHWARZ
		r.CustomPhysicalProperties = reifen
		r.Parent = m
		-- outer side of the wheel (x points outwards)
		local aussen = math.sign(x)
		local hw = r.Size.X / 2
		local function schicht(dx) return r.CFrame * CFrame.new(aussen * (hw + dx), 0, 0) end
		local felgeR = R * 0.66
		deko("Felge", Vector3.new(0.04, felgeR * 2, felgeR * 2), schicht(0.02), felgenFarbe, Enum.Material.Metal, r, Enum.PartType.Cylinder)
		deko("Felgenbett", Vector3.new(0.04, felgeR * 1.8, felgeR * 1.8), schicht(0.04), Color3.fromRGB(18, 18, 20), nil, r, Enum.PartType.Cylinder)
		-- brake caliper: fixed to the chassis / steering knuckle, so it does not spin
		local sattelLage = schicht(0.07) * CFrame.Angles(math.rad(-40), 0, 0) * CFrame.new(0, felgeR * 0.55, 0)
		deko("Bremssattel", Vector3.new(0.05, felgeR * 0.32, felgeR * 0.75), sattelLage, SATTEL_FARBE[basis] or SATTEL_FARBE.suv, nil, halter)
		deko("Bremsscheibe", Vector3.new(0.03, felgeR * 1.45, felgeR * 1.45), schicht(0.055), Color3.fromRGB(95, 95, 100), Enum.Material.Metal, r, Enum.PartType.Cylinder)
		local n = SPEICHEN[basis] or 5
		for i = 1, n do
			local spoke = schicht(0.1) * CFrame.Angles(math.rad(360 / n * i), 0, 0) * CFrame.new(0, felgeR * 0.48, 0)
			deko("Felge", Vector3.new(0.05, felgeR * 0.9, n > 6 and 0.12 or 0.2), spoke, felgenFarbe, Enum.Material.Metal, r)
		end
		deko("Felge", Vector3.new(0.06, felgeR * 0.36, felgeR * 0.36), schicht(0.12), felgenFarbe, Enum.Material.Metal, r, Enum.PartType.Cylinder)
		deko("Radmutter", Vector3.new(0.04, felgeR * 0.14, felgeR * 0.14), schicht(0.16), Color3.fromRGB(30, 30, 33), Enum.Material.Metal, r, Enum.PartType.Cylinder)
		return r
	end
	for _, s in { -1, 1 } do
		local seite = s < 0 and "L" or "R"
		local hinten = rad(s * SP, A, chassis)
		local motor = Instance.new("HingeConstraint")
		motor.Name = "Motor" .. seite
		motor.Attachment0 = anhang(chassis, "HintenA" .. seite, CFrame.new(s * SP, 0, A))
		motor.Attachment1 = anhang(hinten, "Achse", CFrame.new())
		motor.ActuatorType = Enum.ActuatorType.Motor
		motor.MotorMaxTorque = 20000
		motor.AngularVelocity = 0
		motor.Parent = chassis

		local kx = s * (SP - 0.6)
		local knoten = Instance.new("Part")
		knoten.Name = "Lenkknoten" .. seite
		knoten.Size = Vector3.new(0.8, 0.8, 0.8)
		knoten.CFrame = at(kx, R, -A)
		knoten.Transparency = 1
		knoten.CanCollide = false
		knoten.CustomPhysicalProperties = PhysicalProperties.new(4, 0.3, 0, 1, 1)
		knoten.Parent = m
		local hoch = CFrame.Angles(0, 0, math.rad(90))
		local servo = Instance.new("HingeConstraint")
		servo.Name = "Lenkung" .. seite
		servo.Attachment0 = anhang(chassis, "LenkungA" .. seite, CFrame.new(kx, 0, -A) * hoch)
		servo.Attachment1 = anhang(knoten, "LenkungB", hoch)
		servo.ActuatorType = Enum.ActuatorType.Servo
		servo.ServoMaxTorque = 200000
		servo.AngularSpeed = 12
		servo.TargetAngle = 0
		servo.Parent = chassis

		local vorne = rad(s * SP, -A, knoten)
		local frei = Instance.new("HingeConstraint")
		frei.Name = "Vorderrad" .. seite
		frei.Attachment0 = anhang(knoten, "RadA", CFrame.new(s * 0.6, 0, 0))
		frei.Attachment1 = anhang(vorne, "Achse", CFrame.new())
		frei.Parent = knoten
	end

	Auto.sitzeEinrichten(m, chassis, sitz, { beifahrer }, CFrame.new(-6.5, 3, 0.5))
	return m, sitz, beifahrer, chassis
end

return Auto
]=====])
neu("ModuleScript", "Fahrstunden", server, [=====[
-- Driving lessons: each lesson is a route of waypoints with instructor instructions.
-- x/z = map position, r = radius to reach it, t = what the instructor says when this point is next.
local HZ = -520

local START = {
	{ x = 550, z = 40, t = "Drive out of the parking bay and onto the street. Signal right (C), then turn right." },
	{ x = 700, z = 40, t = "Junctions without signs: right before left, drive slowly! At the next intersection, turn left." },
	{ x = 700, z = 0, t = "STOP sign at the exit: stop completely, then turn left onto the country road." },
}
local HEIMWEG = {
	{ x = 700, z = 0, t = "Follow the country road. At the gate, turn right into the residential area." },
	{ x = 700, z = 40, t = "Residential area, 30 km/h. No signs here: right before left! Give way to the right, then turn right." },
	{ x = 550, z = 40, t = "Signal left (Y) and turn into the driving school parking lot." },
	{ x = 550, z = 48, r = 16, t = "Park the car in any free parking bay and stop completely.", parken = true },
}

local function route(...)
	local liste = {}
	for _, teil in { ... } do
		for _, p in teil do table.insert(liste, p) end
	end
	return liste
end

local LEKTIONEN = {
	{
		titel = "Lesson 1: Basics & Turning",
		intro = "Hi, I'm Mike! W/S = gas and brake, A/D = steering. Indicators: Y = left, C = right, X = hazard lights. Drive through the green gates. 10 mistakes and the lesson does not count!",
		punkte = route(START, {
			{ x = 330, z = 0, t = "Country road: 100 km/h. Drive towards the city." },
			{ x = 208, z = 0, t = "City limit: 50 km/h! Turn right at the next intersection." },
			{ x = 208, z = -104, t = "STOP sign ahead: stop completely, then turn left." },
			{ x = 104, z = -104, t = "Traffic light ahead. Turn left here." },
			{ x = 104, z = 0, t = "Turn left and leave the city again." },
			{ x = 330, z = 0, t = "Well done. Back to the country road." },
		}, HEIMWEG),
	},
	{
		titel = "Lesson 2: Traffic Lights & Right of Way",
		intro = "Today we drive through the city centre. Watch the traffic lights: stop at red before the white stop line!",
		punkte = route(START, {
			{ x = 330, z = 0, t = "Drive into the city." },
			{ x = 104, z = 0, t = "Traffic light ahead. Go straight on green." },
			{ x = 0, z = 0, t = "Keep going straight." },
			{ x = -104, z = 0, t = "Turn right at this traffic light." },
			{ x = -104, z = -104, t = "Turn right again." },
			{ x = 0, z = -104, t = "Straight on." },
			{ x = 104, z = -104, t = "Turn right at the traffic light." },
			{ x = 104, z = 0, t = "Turn left towards the country road." },
			{ x = 330, z = 0, t = "Great driving! Head back to the school." },
		}, HEIMWEG),
	},
	{
		titel = "Lesson 3: Country Road & Highway",
		intro = "Today we go on the highway. Merge carefully, keep right and only overtake on the left.",
		punkte = route({
			{ x = 550, z = 40, t = "Drive out of the parking bay. Signal right (C) and turn right." },
			{ x = 700, z = 40, t = "Turn left at the next intersection." },
			{ x = 700, z = 0, t = "STOP sign at the exit: stop, then turn right towards the highway." },
			{ x = 780, z = 0, t = "Turn left onto the highway access road." },
			{ x = 780, z = -300, t = "Country road: 100 km/h." },
			{ x = 780, z = HZ, r = 18, t = "Turn left onto the highway. Speed limit 130 km/h." },
			{ x = 450, z = HZ - 10, r = 16, breite = 22, t = "Stay in the right lane." },
			{ x = 100, z = HZ - 10, r = 16, breite = 22, t = "Take the next exit on the left into the city." },
			{ x = 0, z = HZ, r = 18, t = "Exit the highway here." },
			{ x = 0, z = -330, t = "City limit: slow down to 50 km/h." },
			{ x = 0, z = 0, t = "Turn left at the traffic light." },
			{ x = 330, z = 0, t = "Drive back to the driving school." },
		}, HEIMWEG),
	},
	{
		titel = "Lesson 4: Roundabout",
		intro = "Today we drive through a roundabout. Traffic inside has priority, and you signal when you leave.",
		punkte = route(START, {
			{ x = 330, z = 0, t = "Drive into the city." },
			{ x = 0, z = 0, t = "Turn left at this traffic light." },
			{ x = 0, z = 330, t = "Leave the city towards the roundabout." },
			{ x = 0, z = 560, t = "Roundabout ahead! Give way to traffic inside, then take the third exit." },
			{ x = -24, z = 600, r = 12, t = "Keep driving around." },
			{ x = 0, z = 624, r = 12, t = "Next exit is yours." },
			{ x = 24, z = 600, r = 12, t = "Signal right and leave the roundabout." },
			{ x = 300, z = 600, t = "Country road: 100 km/h." },
			{ x = 756, z = 600, r = 12, t = "Roundabout! Give way to traffic inside, then take the 3rd exit (north)." },
			{ x = 780, z = 624, r = 12, t = "Keep going around." },
			{ x = 804, z = 600, r = 12, t = "Next exit is yours." },
			{ x = 780, z = 576, r = 12, t = "Signal right and leave the roundabout to the north." },
			{ x = 780, z = 276, t = "Turn left at the next junction." },
			{ x = 700, z = 276, t = "Turn right into the residential area. 30 km/h!" },
			{ x = 700, z = 40, t = "Watch the signs: STOP, YIELD, and right before left where there are none. Turn left at the last intersection." },
			{ x = 550, z = 40, t = "Signal left (Y) and turn into the driving school parking lot." },
			{ x = 550, z = 48, r = 16, t = "Park the car in any free parking bay and stop completely.", parken = true },
		}),
	},
	{
		titel = "Lesson 5: Parking",
		intro = "Last lesson: we drive one round through the neighbourhood, then you park in the marked bay.",
		punkte = {
			{ x = 550, z = 40, t = "Drive out of the parking bay. Signal right (C) and turn right." },
			{ x = 600, z = 40, t = "Turn right at the next intersection." },
			{ x = 600, z = 152, t = "Turn right." },
			{ x = 500, z = 152, t = "Turn right." },
			{ x = 500, z = 40, t = "Turn right towards the parking lot." },
			{ x = 522, z = 40, r = 16, t = "Now park in the highlighted bay (front left). Stop completely inside it.", parken = true, uebung = true },
		},
	},
}

-- Practical driving test: one of these routes is picked at random.
-- The examiner gives the directions (no hints about mistakes!).
local function pruefung(titel, mitte, anfang, ende)
	local punkte = route(anfang or START, mitte, ende or HEIMWEG)
	return { titel = titel, intro = "Good luck! I'm your examiner. Follow my directions and drive safely. You may make at most 3 mistakes.", punkte = punkte }
end
LEKTIONEN.PRUEFUNGEN = {
	pruefung("Driving test: City", {
		{ x = 330, z = 0, t = "Drive towards the city." },
		{ x = 104, z = 0, t = "Go straight at the traffic light." },
		{ x = 0, z = 0, t = "Turn right at the next traffic light." },
		{ x = 0, z = -104, t = "Turn right." },
		{ x = 104, z = -104, t = "Turn right again." },
		{ x = 104, z = 0, t = "Turn left towards the country road." },
		{ x = 330, z = 0, t = "Drive back to the driving school." },
	}),
	pruefung("Driving test: Highway", {
		{ x = 780, z = 0, t = "Turn left onto the access road." },
		{ x = 780, z = -300, t = "Country road, 100 km/h." },
		{ x = 780, z = -520, r = 18, t = "Turn left onto the highway." },
		{ x = 300, z = -530, r = 16, breite = 22, t = "Keep right." },
		{ x = 0, z = -520, r = 18, t = "Take the exit on the left into the city." },
		{ x = 0, z = -330, t = "City limit, 50 km/h." },
		{ x = 0, z = 0, t = "Turn left at the traffic light." },
		{ x = 330, z = 0, t = "Drive back to the driving school." },
	}, {
		{ x = 550, z = 40, t = "Drive out of the parking bay and turn right." },
		{ x = 700, z = 40, t = "Turn left at the next intersection." },
		{ x = 700, z = 0, t = "STOP sign: stop, then turn right towards the highway." },
	}),
	pruefung("Driving test: Roundabout", {
		{ x = 330, z = 0, t = "Drive into the city." },
		{ x = 0, z = 0, t = "Turn left at the traffic light." },
		{ x = 0, z = 330, t = "Leave the city towards the roundabout." },
		{ x = 0, z = 560, t = "In the roundabout, take the second exit." },
		{ x = -24, z = 600, r = 12, t = "Keep going." },
		{ x = 0, z = 624, r = 12, t = "Next exit is yours." },
		{ x = 24, z = 600, r = 12, t = "Signal right and leave the roundabout." },
		{ x = 756, z = 600, r = 12, t = "Roundabout! Give way to traffic inside, then take the 3rd exit (north)." },
			{ x = 780, z = 624, r = 12, t = "Keep going around." },
			{ x = 804, z = 600, r = 12, t = "Next exit is yours." },
			{ x = 780, z = 576, r = 12, t = "Signal right and leave the roundabout to the north." },
		{ x = 780, z = 276, t = "Turn left at the next junction." },
		{ x = 700, z = 276, t = "Turn right into the residential area. 30 km/h!" },
		{ x = 700, z = 40, t = "Turn left at the next intersection." },
	}, nil, {
		{ x = 550, z = 40, t = "Signal left and turn into the driving school parking lot." },
		{ x = 550, z = 48, r = 16, t = "Park the car in any free parking bay and stop completely.", parken = true },
	}),
}

-- Truck test (class C): starts and ends at the Parcel Express depot
LEKTIONEN.LKW = {
	titel = "Truck driving test (Class C)",
	intro = "Welcome to your truck test! A truck is long and heavy: brake early, and take corners slowly and wide. You may make at most 3 mistakes.",
	punkte = {
		{ x = 600, z = 340, r = 16, t = "Drive out of the bay and leave the depot to the north." },
		{ x = 600, z = 276, t = "Signal right (C) and turn right onto the ring road. 30 km/h!" },
		{ x = 780, z = 276, t = "Signal left (Y) and turn left at the junction." },
		{ x = 780, z = 0, t = "Turn left onto the country road. Take the corner wide!" },
		{ x = 420, z = 0, t = "Signal left and turn left at the next junction." },
		{ x = 420, z = 276, t = "Turn left onto the ring road." },
		{ x = 600, z = 276, t = "Signal right and turn back into the depot." },
		{ x = 600, z = 350, r = 20, t = "Park the truck in a free bay and stop completely.", parken = true, lkw = true },
	},
}

return LEKTIONEN
]=====])
neu("ModuleScript", "Strafen", server, [=====[
-- Traffic offences: speed cameras, red lights, fines, penalty points, license withdrawal
-- and the personal traffic record. All values can be changed here.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Strafen = {}

Strafen.PUNKTE_LIMIT = 8             -- from this many points the license is withdrawn
Strafen.NACHSCHULUNG_PREIS = 500     -- retraining course after a withdrawal
Strafen.TOLERANZ = 3                 -- km/h tolerance of the speed cameras
Strafen.PUNKT_VERFALL = 45 * 60      -- one point expires after this much time online (seconds)
-- speeding: over the limit by up to "bis" km/h -> fine and points
Strafen.TEMPO = {
	{ bis = 10, geld = 30, punkte = 0 },
	{ bis = 20, geld = 80, punkte = 1 },
	{ bis = 30, geld = 150, punkte = 1 },
	{ bis = 40, geld = 250, punkte = 2 },
	{ bis = math.huge, geld = 400, punkte = 2 },
}
Strafen.ROTLICHT = { geld = 90, punkte = 1 }
Strafen.FLUCHT = { geld = 250, punkte = 2 }

local ctx -- shared things from the main server script (data, money, events, ...)

function Strafen.tempoStrafe(zuSchnell)
	for _, stufe in Strafen.TEMPO do
		if zuSchnell <= stufe.bis then return stufe.geld, stufe.punkte end
	end
	local letzte = Strafen.TEMPO[#Strafen.TEMPO]
	return letzte.geld, letzte.punkte
end

-- takes the license away (all classes) until the retraining course and a new driving test
function Strafen.entziehen(p)
	local d = ctx.daten[p]
	if not d or not d.fuehrerschein then return end
	d.fuehrerschein = false
	d.entzogen = true
	d.nachschulung = false
	if d.lkwFuehrerschein then
		d.lkwFuehrerschein = false
		d.lkwGesperrt = true -- class C comes back automatically with the new class B
	end
	table.insert(d.historie, 1, { t = os.time(), text = "LICENSE WITHDRAWN (" .. d.punkte .. " points)", geld = 0, punkte = 0 })
	d.punkte = 0
	ctx.geaendert(p)
	ctx.lizenzEntfernen(p)
	-- you keep your car - but if you keep driving, the police is looking for you
	ctx.fahrEvent:FireClient(p, { typ = "entzug", limit = Strafen.PUNKTE_LIMIT, preis = Strafen.NACHSCHULUNG_PREIS })
end

-- one entry in the traffic record: fine, points, maybe withdrawal
function Strafen.eintrag(p, text, geld, punkte)
	local d = ctx.daten[p]
	if not d then return end
	d.historie = d.historie or {}
	d.punkte = (d.punkte or 0) + (punkte or 0)
	table.insert(d.historie, 1, { t = os.time(), text = text, geld = geld or 0, punkte = punkte or 0 })
	while #d.historie > 40 do table.remove(d.historie) end
	if (geld or 0) > 0 then
		ctx.geldGeben(p, -geld, text)
	else
		ctx.geaendert(p)
	end
	if (punkte or 0) > 0 then
		ctx.fahrEvent:FireClient(p, { typ = "punkte", punkte = d.punkte, limit = Strafen.PUNKTE_LIMIT, plus = punkte, text = text })
	end
	if d.fuehrerschein and d.punkte >= Strafen.PUNKTE_LIMIT then
		Strafen.entziehen(p)
	end
end

function Strafen.akte(p)
	local d = ctx.daten[p]
	return {
		punkte = d.punkte or 0, limit = Strafen.PUNKTE_LIMIT, fuehrerschein = d.fuehrerschein, entzogen = d.entzogen,
		nachschulung = d.nachschulung, lkw = d.lkwFuehrerschein, historie = d.historie or {}, preis = Strafen.NACHSCHULUNG_PREIS,
		naechsterVerfall = (d.punkte or 0) > 0 and math.max(0, Strafen.PUNKT_VERFALL - (d.punkteZeit or 0)) or nil,
	}
end

function Strafen.nachschulungBuchen(p)
	local d = ctx.daten[p]
	if not d.entzogen then return { fehler = "Your license is not withdrawn." } end
	if d.nachschulung then return { fehler = "You already did the retraining course. Now book the driving test with Anna." } end
	if d.geld < Strafen.NACHSCHULUNG_PREIS then
		return { fehler = ("The retraining course costs %d coins. You have %d."):format(Strafen.NACHSCHULUNG_PREIS, d.geld) }
	end
	ctx.geldGeben(p, -Strafen.NACHSCHULUNG_PREIS, "Retraining course")
	d.nachschulung = true
	table.insert(d.historie, 1, { t = os.time(), text = "Retraining course completed", geld = Strafen.NACHSCHULUNG_PREIS, punkte = 0 })
	ctx.geaendert(p)
	return { ok = true }
end

function Strafen.starten(c)
	ctx = c
	local karte = workspace:WaitForChild("Karte")
	local blitzerOrdner = karte:FindFirstChild("Blitzer")
	local ampeln = karte:FindFirstChild("Ampeln")
	local zuletzt = {}   -- [player][camera] = time of the last flash
	local letztePos = {} -- [player] = last position (red light check)

	local function blitzen(kamera)
		local b = kamera:FindFirstChild("Blitz")
		if not b then return end
		b.Color = Color3.new(1, 1, 1)
		b.Material = Enum.Material.Neon
		local licht = b:FindFirstChildOfClass("PointLight") or Instance.new("PointLight")
		licht.Range = 30
		licht.Brightness = 6
		licht.Enabled = true
		licht.Parent = b
		task.delay(0.18, function()
			b.Color = Color3.fromRGB(60, 60, 60)
			b.Material = Enum.Material.SmoothPlastic
			licht.Enabled = false
		end)
	end

	local takt, minuteTakt = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		takt += dt
		minuteTakt += dt
		if minuteTakt >= 60 then
			-- old points expire while you play
			minuteTakt = 0
			for _, p in Players:GetPlayers() do
				local d = ctx.daten[p]
				if d and (d.punkte or 0) > 0 then
					d.punkteZeit = (d.punkteZeit or 0) + 60
					if d.punkteZeit >= Strafen.PUNKT_VERFALL then
						d.punkteZeit = 0
						d.punkte -= 1
						table.insert(d.historie, 1, { t = os.time(), text = "1 point expired", geld = 0, punkte = -1 })
						ctx.geaendert(p)
					end
				end
			end
		end
		if takt < 0.1 then return end
		takt = 0
		for _, p in Players:GetPlayers() do
			local d = ctx.daten[p]
			local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
			local sitz = hum and hum.SeatPart
			local modell = sitz and sitz:IsA("VehicleSeat") and sitz.Parent
			local chassis = modell and modell:FindFirstChild("Chassis")
			if not (d and chassis) then
				letztePos[p] = nil
				continue
			end
			local pos = Vector3.new(chassis.Position.X, 0, chassis.Position.Z)
			local tempo = chassis.AssemblyLinearVelocity.Magnitude
			local lektion = ctx.lektionen[p]
			zuletzt[p] = zuletzt[p] or {}

			-- speed cameras (measure both directions)
			if blitzerOrdner then
				for _, kamera in blitzerOrdner:GetChildren() do
					local punkt = kamera:GetAttribute("Messpunkt")
					if punkt and (pos - punkt).Magnitude < 14 and os.clock() - (zuletzt[p][kamera] or 0) > 6 then
						local limit = ctx.Regeln.tempolimit(punkt)
						if tempo > limit + Strafen.TOLERANZ then
							zuletzt[p][kamera] = os.clock()
							blitzen(kamera)
							local zuSchnell = math.floor(tempo - limit)
							if lektion then
								ctx.warnung(p, lektion, ("📸 Speed camera! %d km/h in a %d zone."):format(math.floor(tempo), limit))
								ctx.fahrEvent:FireClient(p, { typ = "blitz" })
							else
								local geld, punkte = Strafen.tempoStrafe(zuSchnell)
								ctx.fahrEvent:FireClient(p, { typ = "blitz", text = ("📸 %d km/h in a %d zone: -%d coins%s"):format(math.floor(tempo), limit, geld, punkte > 0 and (", +" .. punkte .. " point" .. (punkte > 1 and "s" or "")) or "") })
								Strafen.eintrag(p, ("Speed camera: %d km/h in a %d zone"):format(math.floor(tempo), limit), geld, punkte)
							end
						end
					end
				end
			end

			-- red lights (lessons check this themselves)
			local vorher = letztePos[p]
			if vorher and not lektion and ampeln then
				for _, ampel in ampeln:GetChildren() do
					if ampel:GetAttribute("Phase") == "Rot" then
						local L = ampel:GetAttribute("Haltelinie")
						local richtung = ampel:GetAttribute("Anfahrt")
						local rechts = ampel:GetAttribute("Rechts")
						if L and richtung and rechts and (pos - L).Magnitude < 30 then
							local a = (vorher - L):Dot(richtung)
							local b = (pos - L):Dot(richtung)
							if a > 0 and b <= 0 and math.abs((pos - L):Dot(rechts)) < 7 then
								ctx.fahrEvent:FireClient(p, { typ = "blitz", text = ("🚦 Red light! -%d coins, +%d point"):format(Strafen.ROTLICHT.geld, Strafen.ROTLICHT.punkte) })
								Strafen.eintrag(p, "Drove through a red light", Strafen.ROTLICHT.geld, Strafen.ROTLICHT.punkte)
							end
						end
					end
				end
			end
			letztePos[p] = pos
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		zuletzt[p] = nil
		letztePos[p] = nil
	end)
end

return Strafen
]=====])
neu("ModuleScript", "Umwelt", server, [=====[
-- Time of day and weather (server). One in-game day lasts 24 real minutes.
-- Weather changes every few minutes: clear, rain or fog. Rain makes the roads slippery
-- (the driving script reads the "Wetter" attribute), fog and night reduce the view.
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local Umwelt = {}
Umwelt.MINUTEN_PRO_TAG = 24
Umwelt.WETTER = {
	{ name = "Clear", chance = 0.6, dauer = { 240, 420 } },
	{ name = "Rain", chance = 0.25, dauer = { 150, 300 } },
	{ name = "Fog", chance = 0.15, dauer = { 120, 240 } },
}

function Umwelt.starten(ordner)
	Lighting.ClockTime = 9
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmo.Parent = Lighting
	-- clearer, richer look: less haze, deeper shadows, a bit more contrast and colour
	atmo.Density, atmo.Haze, atmo.Glare = 0.26, 0.6, 0.2
	Lighting.OutdoorAmbient = Color3.fromRGB(105, 110, 125)
	Lighting.Ambient = Color3.fromRGB(60, 62, 72)
	local farbe = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if farbe then farbe.Contrast, farbe.Saturation = 0.14, 0.2 end
	local wolken = workspace.Terrain:FindFirstChildOfClass("Clouds")
	local basis = { dichte = atmo.Density or 0.3, dunst = atmo.Haze or 0, bedeckt = wolken and wolken.Cover or 0.5 }
	atmo.Density, atmo.Haze = basis.dichte, basis.dunst
	if wolken then wolken.Cover = basis.bedeckt end
	Lighting.Brightness = Lighting.Brightness or 2

	local wetter = "Clear"
	local function setzen(name)
		wetter = name
		ordner:SetAttribute("Wetter", name)
	end
	setzen("Clear")

	-- smooth fading between the weather looks
	local ziel = { dichte = basis.dichte, dunst = basis.dunst, bedeckt = basis.bedeckt }
	RunService.Heartbeat:Connect(function(dt)
		Lighting.ClockTime = (Lighting.ClockTime + dt * 24 / (Umwelt.MINUTEN_PRO_TAG * 60)) % 24
		ordner:SetAttribute("Uhrzeit", Lighting.ClockTime)
		if wetter == "Rain" then
			ziel = { dichte = 0.45, dunst = 2.5, bedeckt = 0.95 }
		elseif wetter == "Fog" then
			ziel = { dichte = 0.7, dunst = 4, bedeckt = 0.8 }
		else
			ziel = basis
		end
		local f = math.min(1, dt * 0.3)
		atmo.Density += (ziel.dichte - atmo.Density) * f
		atmo.Haze += (ziel.dunst - atmo.Haze) * f
		if wolken then wolken.Cover += (ziel.bedeckt - wolken.Cover) * f end
		-- a bit darker in bad weather
		local hell = (wetter == "Clear") and 2 or 1.4
		Lighting.Brightness += (hell - Lighting.Brightness) * f
	end)

	task.spawn(function()
		while true do
			local wurf, summe, wahl = math.random(), 0, Umwelt.WETTER[1]
			for _, w in Umwelt.WETTER do
				summe += w.chance
				if wurf <= summe then wahl = w break end
			end
			setzen(wahl.name)
			task.wait(math.random(wahl.dauer[1], wahl.dauer[2]))
		end
	end)
end

return Umwelt
]=====])
neu("ModuleScript", "Fahrzeugpflege", server, [=====[
-- Own cars: fuel, damage, repairs, insurance and tuning (server).
-- All prices and values can be changed here.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Pflege = {}

Pflege.TANKPREIS = 1.5                 -- coins per % of fuel
Pflege.REICHWEITE = {                  -- km per full tank
	kleinwagen = 10, suv = 7, limousine = 9, sport = 7, track = 6, gs = 7, gs_night = 7, renn = 5, supersport = 6,
}
Pflege.PANNENHILFE = { preis = 120, prozent = 15 } -- roadside fuel delivery
Pflege.ABSCHLEPPEN = 200                -- broken car is towed to the garage
Pflege.VERSICHERUNG = 0.08             -- insurance: one-time price = 8 % of the car price
Pflege.VERSICHERT_ANTEIL = 0.3         -- with insurance you pay only 30 % of a repair
Pflege.MOTOR = { 0.12, 0.25, 0.45 }    -- engine stage 1/2/3 costs this share of the car price
Pflege.SPOILER = 300
Pflege.NEON = 400
Pflege.FELGEN = 150
Pflege.NEON_FARBEN = { Color3.fromRGB(40, 120, 255), Color3.fromRGB(255, 40, 60), Color3.fromRGB(40, 255, 120), Color3.fromRGB(190, 60, 255), Color3.fromRGB(255, 120, 200) }
Pflege.FELGEN_FARBEN = { Color3.fromRGB(200, 200, 205), Color3.fromRGB(25, 25, 28), Color3.fromRGB(220, 180, 60), Color3.fromRGB(200, 30, 35), Color3.fromRGB(245, 245, 245) }

local ctx

function Pflege.daten(d, typ)
	d.autoDaten = d.autoDaten or {}
	local a = d.autoDaten[typ]
	if not a then
		a = { tank = 100, zustand = 100, versichert = false, motor = 0, spoiler = false, neon = 0, felgen = 1 }
		d.autoDaten[typ] = a
	end
	return a
end

local function reparaturProProzent(typ)
	local preis = ctx.Auto.MODELLE[typ] and (ctx.Auto.MODELLE[typ].wert or ctx.Auto.MODELLE[typ].preis) or 3000
	return math.max(2, math.floor(preis * 0.0008))
end

function Pflege.reparaturKosten(d, typ)
	local a = Pflege.daten(d, typ)
	local kosten = math.ceil((100 - a.zustand) * reparaturProProzent(typ))
	if a.versichert then kosten = math.ceil(kosten * Pflege.VERSICHERT_ANTEIL) end
	return kosten
end

-- extra parts for tuning (welded to the chassis, removed and rebuilt on every change)
local function tuningTeil(modell, chassis, name, groesse, lage, farbe, material)
	local t = Instance.new("Part")
	t.Name = "Tuning_" .. name
	t.Size = groesse
	t.CFrame = lage
	t.Color = farbe
	t.Material = material or Enum.Material.SmoothPlastic
	t.CanCollide = false
	t.Massless = true
	t.CastShadow = false
	t.Parent = modell
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = chassis, t
	w.Parent = t
	return t
end

-- applies fuel, condition and tuning to a spawned car
function Pflege.anwenden(modell, typ, a, nurWerte)
	local chassis = modell:FindFirstChild("Chassis")
	local basis = ctx.Auto.MODELLE[typ] and ctx.Auto.MODELLE[typ].werte
	if not chassis or not basis then return end
	local stufe = a.motor or 0
	modell:SetAttribute("MaxTempo", math.floor(basis.MaxTempo * (1 + 0.07 * stufe) * (a.zustand < 30 and 0.6 or 1)))
	modell:SetAttribute("Antrieb", math.floor(basis.Antrieb * (1 + 0.12 * stufe)))
	modell:SetAttribute("Tank", math.floor(a.tank))
	modell:SetAttribute("Zustand", math.floor(a.zustand))
	modell:SetAttribute("Gesperrt", (a.tank <= 0 or a.zustand <= 0) or nil)
	modell:SetAttribute("Motorstufe", stufe)
	if nurWerte then return end

	for _, t in modell:GetChildren() do
		if t.Name:sub(1, 7) == "Tuning_" then t:Destroy() end
	end
	local laenge = modell:GetAttribute("Laenge") or 15
	local karosserie = modell:FindFirstChild("Karosserie")
	local oben = karosserie and (karosserie.Position.Y + karosserie.Size.Y / 2 - chassis.Position.Y) or 2
	local cf = chassis.CFrame
	if a.spoiler then
		local dachSpoiler = modell:GetAttribute("SpoilerAmDach")
		if dachSpoiler then
			-- SUV with round body: a bigger roof spoiler instead of a trunk wing
			tuningTeil(modell, chassis, "Spoiler", Vector3.new(6, 0.18, 1.2), cf * dachSpoiler * CFrame.Angles(math.rad(-8), 0, 0), Color3.fromRGB(25, 25, 28))
			local stuetze = modell:GetAttribute("SpoilerStuetze")
			if stuetze then -- wing on supports (sports car)
				for _, s in { -1, 1 } do
					tuningTeil(modell, chassis, "Spoilerstuetze", Vector3.new(0.2, stuetze, 0.5), cf * dachSpoiler * CFrame.new(s * 1.9, -stuetze / 2, 0), Color3.fromRGB(25, 25, 28))
				end
			end
		else
			tuningTeil(modell, chassis, "Spoiler", Vector3.new(6, 0.2, 1.4), cf * CFrame.new(0, oben + 1.1, laenge / 2 - 1.2) * CFrame.Angles(math.rad(6), 0, 0), Color3.fromRGB(25, 25, 28))
			for _, s in { -1, 1 } do
				tuningTeil(modell, chassis, "Spoilerstuetze", Vector3.new(0.25, 1.1, 0.6), cf * CFrame.new(s * 2.2, oben + 0.55, laenge / 2 - 1.2), Color3.fromRGB(25, 25, 28))
			end
		end
	end
	if (a.neon or 0) > 0 then
		local farbe = Pflege.NEON_FARBEN[a.neon] or Pflege.NEON_FARBEN[1]
		for _, s in { -1, 1 } do
			local n = tuningTeil(modell, chassis, "Neon", Vector3.new(0.3, 0.15, laenge - 4), cf * CFrame.new(s * 2.4, -0.3, 0), farbe, Enum.Material.Neon)
			local licht = Instance.new("PointLight")
			licht.Color = farbe
			licht.Range = 10
			licht.Brightness = 2
			licht.Parent = n
		end
	end
	local felge = Pflege.FELGEN_FARBEN[a.felgen or 1]
	if felge then
		for _, t in modell:GetChildren() do
			if t.Name == "Felge" then t.Color = felge end
		end
	end
	-- smoke from the engine when the car is badly damaged
	if a.zustand < 50 then
		local rauch = tuningTeil(modell, chassis, "Rauch", Vector3.new(1, 1, 1), cf * CFrame.new(0, oben + 0.5, -laenge / 2 + 2), Color3.new(0, 0, 0))
		rauch.Transparency = 1
		local smoke = Instance.new("Smoke")
		smoke.Color = a.zustand < 25 and Color3.fromRGB(40, 40, 40) or Color3.fromRGB(170, 170, 170)
		smoke.Size = 2
		smoke.RiseVelocity = 4
		smoke.Opacity = a.zustand < 25 and 0.5 or 0.25
		smoke.Parent = rauch
	end
end

-- workshop data for the client
function Pflege.werkstattInfo(p)
	local d = ctx.daten[p]
	local liste = {}
	for _, typ in ctx.Auto.MODELL_REIHENFOLGE do
		if table.find(d.autos or {}, typ) then
			local a = Pflege.daten(d, typ)
			local m = ctx.Auto.MODELLE[typ]
			table.insert(liste, {
				typ = typ, name = m.name, zustand = math.floor(a.zustand), tank = math.floor(a.tank), versichert = a.versichert,
				reparatur = Pflege.reparaturKosten(d, typ), versicherung = math.floor((m.wert or m.preis) * Pflege.VERSICHERUNG),
				motor = a.motor or 0, motorPreis = a.motor < 3 and math.floor((m.wert or m.preis) * Pflege.MOTOR[a.motor + 1]) or nil,
				spoiler = a.spoiler, neon = a.neon or 0, felgen = a.felgen or 1,
			})
		end
	end
	return { autos = liste, geld = d.geld, preise = { spoiler = Pflege.SPOILER, neon = Pflege.NEON, felgen = Pflege.FELGEN } }
end

local function aktivesAuto(p, typ)
	local a = ctx.privatAutos[p]
	if a and a.typ == typ and a.model and a.model.Parent then return a.model end
	return nil
end

function Pflege.werkstatt(p, eingabe)
	local d = ctx.daten[p]
	if type(eingabe) ~= "table" then return { fehler = "?" } end
	local typ = eingabe.typ
	if not table.find(d.autos or {}, typ) then return { fehler = "You don't own this car." } end
	local m = ctx.Auto.MODELLE[typ]
	local a = Pflege.daten(d, typ)
	local preis, text
	if eingabe.art == "reparieren" then
		if a.zustand >= 100 then return { fehler = "This car is already in perfect condition." } end
		preis = Pflege.reparaturKosten(d, typ)
		text = m.name .. " repaired"
	elseif eingabe.art == "versichern" then
		if a.versichert then return { fehler = "This car is already insured." } end
		preis = math.floor((m.wert or m.preis) * Pflege.VERSICHERUNG)
		text = "Insurance for the " .. m.name
	elseif eingabe.art == "motor" then
		if a.motor >= 3 then return { fehler = "The engine is already at the highest stage." } end
		preis = math.floor((m.wert or m.preis) * Pflege.MOTOR[a.motor + 1])
		text = ("Engine stage %d for the %s"):format(a.motor + 1, m.name)
	elseif eingabe.art == "spoiler" then
		preis = a.spoiler and 0 or Pflege.SPOILER
		text = a.spoiler and "Spoiler removed" or "Spoiler for the " .. m.name
	elseif eingabe.art == "neon" then
		local farbe = math.clamp(math.floor(tonumber(eingabe.wert) or 0), 0, #Pflege.NEON_FARBEN)
		preis = (farbe == 0 or a.neon > 0) and 0 or Pflege.NEON
		if a.neon > 0 and farbe > 0 then preis = 100 end -- changing the color
		text = farbe == 0 and "Neon removed" or "Neon underglow"
		eingabe.neonFarbe = farbe
	elseif eingabe.art == "felgen" then
		local farbe = math.clamp(math.floor(tonumber(eingabe.wert) or 1), 1, #Pflege.FELGEN_FARBEN)
		preis = Pflege.FELGEN
		text = "New rim color"
		eingabe.felgenFarbe = farbe
	else
		return { fehler = "Unknown service." }
	end
	if d.geld < preis then
		return { fehler = ("That costs %d coins, you have %d."):format(preis, d.geld) }
	end
	if eingabe.art == "reparieren" then a.zustand = 100
	elseif eingabe.art == "versichern" then a.versichert = true
	elseif eingabe.art == "motor" then a.motor += 1
	elseif eingabe.art == "spoiler" then a.spoiler = not a.spoiler
	elseif eingabe.art == "neon" then a.neon = eingabe.neonFarbe
	elseif eingabe.art == "felgen" then a.felgen = eingabe.felgenFarbe end
	if preis > 0 then
		ctx.geldGeben(p, -preis, text)
	else
		ctx.geaendert(p)
	end
	local modell = aktivesAuto(p, typ)
	if modell then Pflege.anwenden(modell, typ, a) end
	return { text = text .. "! 🔧", info = Pflege.werkstattInfo(p) }
end

-- roadside help: some fuel brought to you, or a tow to the garage when the car is broken
function Pflege.pannenhilfe(p)
	local d = ctx.daten[p]
	local auto = ctx.privatAutos[p]
	if not auto then return { fehler = "Get one of your cars first." } end
	local a = Pflege.daten(d, auto.typ)
	if a.zustand <= 0 then
		if d.geld < Pflege.ABSCHLEPPEN then return { fehler = ("Towing costs %d coins."):format(Pflege.ABSCHLEPPEN) } end
		ctx.geldGeben(p, -Pflege.ABSCHLEPPEN, "Car towed to the garage")
		ctx.autoWeg(p)
		return { text = "Your car was towed to Ben's Garage at the service station. Repair it there before you drive again." }
	end
	if a.tank >= 50 then return { fehler = "Your tank is still at least half full – drive to a gas station." } end
	if d.geld < Pflege.PANNENHILFE.preis then return { fehler = ("Roadside help costs %d coins."):format(Pflege.PANNENHILFE.preis) } end
	ctx.geldGeben(p, -Pflege.PANNENHILFE.preis, "Roadside help")
	a.tank = math.min(100, a.tank + Pflege.PANNENHILFE.prozent)
	Pflege.anwenden(auto.model, auto.typ, a)
	return { text = ("A service van brought you %d %% fuel. Drive to the next gas station! ⛽"):format(Pflege.PANNENHILFE.prozent) }
end

function Pflege.starten(c)
	ctx = c
	local service = workspace:WaitForChild("Karte"):WaitForChild("Service", 10)

	-- fuel pumps
	if service then
		for _, saeule in service:GetDescendants() do
			if saeule:IsA("BasePart") and saeule:GetAttribute("Zapfsaeule") then
				local pp = Instance.new("ProximityPrompt")
				pp.ActionText = "Refuel"
				pp.ObjectText = "Fuel pump"
				pp.HoldDuration = 0.8
				pp.MaxActivationDistance = 12
				pp.RequiresLineOfSight = false
				pp.Parent = saeule
				pp.Triggered:Connect(function(p)
					local d = ctx.daten[p]
					local auto = ctx.privatAutos[p]
					if not d or not auto or not auto.chassis.Parent or (auto.chassis.Position - saeule.Position).Magnitude > 20 then
						ctx.fahrEvent:FireClient(p, { typ = "hinweis", text = "Park your own car right next to the pump first." })
						return
					end
					local a = Pflege.daten(d, auto.typ)
					local fehlt = 100 - a.tank
					if fehlt < 1 then
						ctx.fahrEvent:FireClient(p, { typ = "hinweis", text = "Your tank is already full." })
						return
					end
					local menge = math.min(fehlt, math.floor(d.geld / Pflege.TANKPREIS))
					if menge < 1 then
						ctx.fahrEvent:FireClient(p, { typ = "hinweis", text = "Not enough coins to refuel." })
						return
					end
					local preis = math.ceil(menge * Pflege.TANKPREIS)
					a.tank += menge
					ctx.geldGeben(p, -preis, ("Refueled %d %%"):format(math.floor(menge)))
					Pflege.anwenden(auto.model, auto.typ, a, true)
					if ctx.mission then ctx.mission(p, "tanken", 1) end
				end)
			end
		end
	end

	-- fuel use and crash damage of the own cars
	local letzte = {}  -- [player] = { pos, vel, hinweisTank, hinweisKaputt }
	local takt = 0
	RunService.Heartbeat:Connect(function(dt)
		takt += dt
		if takt < 0.1 then return end
		local schritt = takt
		takt = 0
		for p, auto in ctx.privatAutos do
			local d = ctx.daten[p]
			local chassis = auto.chassis
			if not d or not chassis or not chassis.Parent then
				letzte[p] = nil
				continue
			end
			local a = Pflege.daten(d, auto.typ)
			local l = letzte[p]
			local v = chassis.AssemblyLinearVelocity
			if not l or l.modell ~= auto.model then
				l = { pos = chassis.Position, vel = v, modell = auto.model }
				letzte[p] = l
			end
			-- fuel: per driven km
			local weg = (chassis.Position - l.pos).Magnitude
			l.pos = chassis.Position
			local geaendert, schadenNeu = false, false
			if weg < 50 and weg > 0.05 and a.tank > 0 then
				local km = weg * 0.28 / 1000
				a.tank = math.max(0, a.tank - km / (Pflege.REICHWEITE[auto.typ] or 8) * 100)
				geaendert = math.floor(a.tank) ~= auto.model:GetAttribute("Tank")
				if a.tank <= 0 then
					ctx.fahrEvent:FireClient(p, { typ = "hinweis", text = "⛽ Out of fuel! Use roadside help in 🚗 My Cars." })
				elseif a.tank < 15 and not l.hinweisTank then
					l.hinweisTank = true
					ctx.fahrEvent:FireClient(p, { typ = "hinweis", text = "⛽ Fuel is low! Drive to a gas station." })
				end
			end
			-- crash: a sudden change of speed that braking cannot cause
			local stoss = (v - l.vel).Magnitude / math.max(schritt, 0.05) * 0.1
			l.vel = v
			if stoss > 30 and a.zustand > 0 then
				local schaden = math.min(60, (stoss - 25) * 1.2)
				a.zustand = math.max(0, a.zustand - schaden)
				geaendert, schadenNeu = true, true
				ctx.fahrEvent:FireClient(p, { typ = "hinweis", text = a.zustand <= 0 and "💥 Your car is broken! Use 🚗 My Cars to call the tow truck." or ("💥 Crash! Car condition: %d %%"):format(math.floor(a.zustand)) })
				if ctx.unfall then ctx.unfall(p) end
			end
			if geaendert then Pflege.anwenden(auto.model, auto.typ, a, not schadenNeu) end
		end
	end)
	Players.PlayerRemoving:Connect(function(p) letzte[p] = nil end)
end

return Pflege
]=====])
neu("ModuleScript", "Missionen", server, [=====[
-- Daily missions (3 new ones every day) and the leaderboards in the city park.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local Missionen = {}

Missionen.ARTEN = {
	{ id = "lieferung", text = "Deliver %d packages or pizzas", ziele = { 4, 6, 8 }, geld = 250, xp = 80 },
	{ id = "jobs", text = "Finish %d delivery or taxi jobs", ziele = { 1, 2, 3 }, geld = 300, xp = 100 },
	{ id = "km", text = "Drive %d km in your own car", ziele = { 2, 3, 5 }, geld = 200, xp = 80 },
	{ id = "kontrolle", text = "Pass a police check without a fine", ziele = { 1 }, geld = 150, xp = 60 },
	{ id = "tanken", text = "Refuel your car at a gas station", ziele = { 1 }, geld = 100, xp = 40 },
	{ id = "perfekt", text = "Finish a lesson or test without mistakes", ziele = { 1 }, geld = 200, xp = 80 },
	{ id = "taxi", text = "Drive %d taxi passengers", ziele = { 2, 3, 4 }, geld = 250, xp = 90 },
}
Missionen.PRO_TAG = 3

local ctx

local function heute()
	return os.date("!%Y-%m-%d")
end

-- the same 3 missions for a player all day (depends on the date and the player)
local function neueListe(p)
	local tag = heute()
	local zahl = 0
	for i = 1, #tag do zahl += string.byte(tag, i) * i end
	local zufall = Random.new(zahl * 7919 + p.UserId)
	local arten = table.clone(Missionen.ARTEN)
	local liste = {}
	for _ = 1, Missionen.PRO_TAG do
		local art = table.remove(arten, zufall:NextInteger(1, #arten))
		table.insert(liste, { id = art.id, ziel = art.ziele[zufall:NextInteger(1, #art.ziele)], stand = 0, fertig = false })
	end
	return { tag = tag, liste = liste }
end

local function aktuell(p)
	local d = ctx.daten[p]
	if not d then return nil end
	if not d.missionen or d.missionen.tag ~= heute() then
		d.missionen = neueListe(p)
	end
	return d.missionen
end

local function art(id)
	for _, a in Missionen.ARTEN do
		if a.id == id then return a end
	end
end

function Missionen.fortschritt(p, id, menge)
	local m = aktuell(p)
	if not m then return end
	for _, mission in m.liste do
		if mission.id == id and not mission.fertig then
			mission.stand = math.min(mission.ziel, mission.stand + (menge or 1))
			if mission.stand >= mission.ziel then
				mission.fertig = true
				local a = art(id)
				ctx.geldGeben(p, a.geld, "Daily mission")
				ctx.xpGeben(p, a.xp, "Daily mission")
				ctx.fahrEvent:FireClient(p, { typ = "mission", text = a.text:format(mission.ziel) })
			end
		end
	end
end

function Missionen.status(p)
	local m = aktuell(p)
	local liste = {}
	for _, mission in m.liste do
		local a = art(mission.id)
		table.insert(liste, { text = a.text:format(mission.ziel), stand = mission.stand, ziel = mission.ziel, fertig = mission.fertig, geld = a.geld, xp = a.xp })
	end
	return { liste = liste }
end

-- ---------------------------------------------------------------
-- Leaderboards (saved for all servers; in Studio without API access only online players)
-- ---------------------------------------------------------------
local LISTEN = {
	Level = { titel = "⭐ TOP LEVEL", wert = function(d) return math.floor(d.xp or 0) end, format = function(w) return ("Lv %d"):format(math.floor(math.sqrt(w / 150)) + 1) end },
	Km = { titel = "🛣 MOST KM DRIVEN", wert = function(d) return math.floor((d.kmGesamt or 0) * 10) end, format = function(w) return ("%.1f km"):format(w / 10) end },
	Perfekt = { titel = "🏆 PERFECT TESTS", wert = function(d) return math.floor(d.perfekt or 0) end, format = function(w) return ("%d ×"):format(w) end },
}

function Missionen.starten(c)
	ctx = c
	local stores = {}
	for name in LISTEN do
		local ok, store = pcall(function() return DataStoreService:GetOrderedDataStore("Rangliste_" .. name) end)
		if ok then stores[name] = store end
	end
	local namen = {}
	local function nameVon(id)
		if namen[id] then return namen[id] end
		local ok, n = pcall(function() return Players:GetNameFromUserIdAsync(id) end)
		namen[id] = ok and n or ("Player " .. id)
		return namen[id]
	end

	local function tafeln()
		local t = {}
		local park = workspace:FindFirstChild("Karte") and workspace.Karte:FindFirstChild("Service")
		local m = park and park:FindFirstChild("Bestenlisten")
		if m then
			for _, teil in m:GetChildren() do
				if teil:GetAttribute("Liste") then t[teil:GetAttribute("Liste")] = teil end
			end
		end
		return t
	end

	local function zeichnen(tafel, titel, zeilen)
		local g = tafel:FindFirstChild("Anzeige")
		if not g then
			g = Instance.new("SurfaceGui")
			g.Name = "Anzeige"
			g.Face = Enum.NormalId.Front
			g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			g.PixelsPerStud = 30
			g.Parent = tafel
		end
		g:ClearAllChildren()
		local kopf = Instance.new("TextLabel")
		kopf.Size = UDim2.new(1, 0, 0.14, 0)
		kopf.BackgroundColor3 = Color3.fromRGB(200, 30, 40)
		kopf.Font = Enum.Font.GothamBlack
		kopf.TextScaled = true
		kopf.TextColor3 = Color3.new(1, 1, 1)
		kopf.Text = titel
		kopf.Parent = g
		for i, z in zeilen do
			local l = Instance.new("TextLabel")
			l.Position = UDim2.new(0.04, 0, 0.15 + (i - 1) * 0.083, 0)
			l.Size = UDim2.new(0.92, 0, 0.075, 0)
			l.BackgroundTransparency = 1
			l.Font = i <= 3 and Enum.Font.GothamBlack or Enum.Font.GothamBold
			l.TextScaled = true
			l.TextXAlignment = Enum.TextXAlignment.Left
			l.TextColor3 = i == 1 and Color3.fromRGB(255, 215, 80) or (i == 2 and Color3.fromRGB(220, 220, 230) or (i == 3 and Color3.fromRGB(230, 160, 100) or Color3.new(1, 1, 1)))
			l.Text = ("%d. %s  –  %s"):format(i, z[1], z[2])
			l.Parent = g
		end
	end

	task.spawn(function()
		task.wait(10)
		while true do
			-- save the scores of everybody online
			for _, p in Players:GetPlayers() do
				local d = ctx.daten[p]
				if d then
					for name, liste in LISTEN do
						if stores[name] then
							pcall(function() stores[name]:SetAsync(tostring(p.UserId), liste.wert(d)) end)
						end
					end
				end
			end
			-- read the top 10 and show them on the boards
			local t = tafeln()
			for name, liste in LISTEN do
				local zeilen = {}
				local ok = stores[name] and pcall(function()
					local seite = stores[name]:GetSortedAsync(false, 10):GetCurrentPage()
					for _, eintrag in seite do
						table.insert(zeilen, { nameVon(tonumber(eintrag.key)), liste.format(eintrag.value) })
					end
				end)
				if not ok or #zeilen == 0 then
					-- fallback: players on this server
					local online = {}
					for _, p in Players:GetPlayers() do
						local d = ctx.daten[p]
						if d then table.insert(online, { p.DisplayName, liste.wert(d) }) end
					end
					table.sort(online, function(a, b) return a[2] > b[2] end)
					zeilen = {}
					for i = 1, math.min(10, #online) do
						table.insert(zeilen, { online[i][1], liste.format(online[i][2]) })
					end
				end
				if t[name] then zeichnen(t[name], liste.titel, zeilen) end
			end
			task.wait(120)
		end
	end)
end

return Missionen
]=====])
neu("ModuleScript", "Shop", server, [=====[
-- Robux shop: game passes, coin packs, 2x coin boosts, starter pack, VIP / Premium bonus (server).
--
-- SET UP (Creator Dashboard -> your experience -> Monetization):
--   1. Create the game passes and developer products below with the same names.
--   2. Copy each ID into "id" here. id = 0 means "not set up yet": the button shows "soon".
--   The Robux price shown in the game is read from Roblox, so you only change prices in the dashboard.
-- In Roblox Studio purchases are free test purchases, nobody pays anything there.
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

local Shop = {}

-- one-time purchases (keep forever)
Shop.PASSES = {
	{ key = "vip", id = 0, preis = 399, icon = "👑", name = "VIP",
		text = "2x coins from every job and reward, golden VIP tag, 2 VIP paint colors." },
	{ key = "xp2", id = 0, preis = 249, icon = "⚡", name = "2x XP",
		text = "Level up twice as fast – unlock the big trucks and cars sooner." },
	{ key = "nacht", id = 0, preis = 699, icon = "🌙", name = "Vanta GS Night Edition",
		text = "Exclusive car: midnight black, gold rims, purple underglow, 195 km/h. Only with this pass." },
	{ key = "garage", id = 0, preis = 199, icon = "🎨", name = "Paint Studio",
		text = "6 exclusive paint colors for all your cars." },
}

-- can be bought again and again (except the starter pack)
Shop.PRODUKTE = {
	{ key = "starter", id = 0, preis = 99, name = "Starter Pack", geld = 7500, boost = 30, einmal = true,
		text = "7,500 coins + 30 min 2x coins. Only once per player!" },
	{ key = "boost", id = 0, preis = 79, name = "2x Coins – 30 min", boost = 30, text = "Double coins for 30 minutes of play." },
	{ key = "coins1", id = 0, preis = 49, name = "2,500 coins", geld = 2500 },
	{ key = "coins2", id = 0, preis = 179, name = "10,000 coins", geld = 10000 },
	{ key = "coins3", id = 0, preis = 449, name = "30,000 coins", geld = 30000, tag = "POPULAR" },
	{ key = "coins4", id = 0, preis = 1199, name = "100,000 coins", geld = 100000, tag = "BEST VALUE" },
}

-- bonus shares on earned coins / XP (purchases and admin money never get a bonus)
Shop.BONUS = { vip = 1.0, boost = 1.0, xp2 = 1.0, premium = 0.1, freunde = 0.1 }

-- exclusive paint colors (index 9 and up in the color list of "My Cars")
Shop.FARBEN = {
	{ name = "VIP Gold", farbe = Color3.fromRGB(212, 168, 60), passes = { "vip", "garage" } },
	{ name = "Pearl White", farbe = Color3.fromRGB(236, 232, 222), passes = { "vip", "garage" } },
	{ name = "Midnight Purple", farbe = Color3.fromRGB(45, 25, 80), passes = { "garage" } },
	{ name = "Racing Green", farbe = Color3.fromRGB(20, 70, 45), passes = { "garage" } },
	{ name = "Candy Red", farbe = Color3.fromRGB(150, 10, 25), passes = { "garage" } },
	{ name = "Ice Blue", farbe = Color3.fromRGB(150, 200, 235), passes = { "garage" } },
}

local ctx
local besitz = {}   -- [player] = { key = true } (from Roblox, cached)
local preise = {}   -- [id] = real Robux price from Roblox

local function passNach(feld, wert)
	for _, p in Shop.PASSES do if p[feld] == wert then return p end end
end
local function produktNach(feld, wert)
	for _, p in Shop.PRODUKTE do if p[feld] == wert then return p end end
end

function Shop.hat(p, key)
	if besitz[p] and besitz[p][key] then return true end
	local d = ctx and ctx.daten[p]
	return d ~= nil and d.passes ~= nil and d.passes[key] == true -- test grants in Studio
end

function Shop.premium(p)
	local ok, typ = pcall(function() return p.MembershipType end)
	return ok and typ == Enum.MembershipType.Premium
end

function Shop.boostRest(p)
	local d = ctx and ctx.daten[p]
	return d and math.max(0, (d.boostBis or 0) - os.time()) or 0
end

-- multiplier for earned coins / XP
function Shop.faktor(p, art)
	local f = 1
	if art == "geld" then
		if Shop.hat(p, "vip") then f += Shop.BONUS.vip end
		if Shop.boostRest(p) > 0 then f += Shop.BONUS.boost end
	else
		if Shop.hat(p, "xp2") then f += Shop.BONUS.xp2 end
	end
	if Shop.premium(p) then f += Shop.BONUS.premium end
	if p:GetAttribute("FreundeBonus") then f += Shop.BONUS.freunde end
	return f
end

function Shop.farbeErlaubt(p, nr)
	if nr <= 8 then return true end
	local f = Shop.FARBEN[nr - 8]
	if not f then return false end
	for _, key in f.passes do
		if Shop.hat(p, key) then return true end
	end
	return false
end

local function attribute(p)
	p:SetAttribute("VIP", Shop.hat(p, "vip") or nil)
	p:SetAttribute("BoostBis", ctx.daten[p] and ctx.daten[p].boostBis or nil)
	p:SetAttribute("GeldFaktor", Shop.faktor(p, "geld"))
	p:SetAttribute("XpFaktor", Shop.faktor(p, "xp"))
end
Shop.attribute = attribute

-- golden tag above VIP players
local function vipSchild(p)
	local figur = p.Character
	local kopf = figur and figur:FindFirstChild("Head")
	if not kopf then return end
	local alt = kopf:FindFirstChild("VipSchild")
	if not Shop.hat(p, "vip") then
		if alt then alt:Destroy() end
		return
	end
	if alt then return end
	local g = Instance.new("BillboardGui")
	g.Name = "VipSchild"
	g.Size = UDim2.fromOffset(70, 24)
	g.StudsOffset = Vector3.new(0, 2.6, 0)
	g.AlwaysOnTop = false
	g.MaxDistance = 80
	g.Parent = kopf
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundColor3 = Color3.fromRGB(40, 32, 10)
	t.BackgroundTransparency = 0.25
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.TextColor3 = Color3.fromRGB(255, 210, 70)
	t.Text = "👑 VIP"
	t.Parent = g
	Instance.new("UICorner", t)
end

local function besitzLaden(p)
	besitz[p] = besitz[p] or {}
	for _, pass in Shop.PASSES do
		if pass.id ~= 0 then
			local ok, hat = pcall(function() return MarketplaceService:UserOwnsGamePassAsync(p.UserId, pass.id) end)
			if ok and hat then besitz[p][pass.key] = true end
		end
	end
end

-- the car that comes with a pass is added to the garage automatically
local function passAutos(p)
	local d = ctx.daten[p]
	if not d then return end
	for typ, m in ctx.Auto.MODELLE do
		if m.pass and Shop.hat(p, m.pass) and not table.find(d.autos or {}, typ) then
			d.autos = d.autos or {}
			table.insert(d.autos, typ)
			if m.tuning then
				local a = ctx.Pflege.daten(d, typ)
				for k, v in m.tuning do a[k] = v end
			end
			ctx.geaendert(p)
			ctx.fahrEvent:FireClient(p, { typ = "belohnung", text = ("🌙 The %s is in your garage! Get it with 🚗 My Cars."):format(m.name) })
		end
	end
end
Shop.passAutos = passAutos

function Shop.spielerDa(p)
	besitzLaden(p)
	local function warten()
		for _ = 1, 40 do
			if ctx.daten[p] then return true end
			task.wait(0.25)
		end
	end
	if not warten() then return end
	attribute(p)
	passAutos(p)
	if p.Character then vipSchild(p) end
	p.CharacterAdded:Connect(function()
		task.wait(1)
		vipSchild(p)
	end)
end

-- shop window data for the client
function Shop.status(p)
	if not ctx then return { fehler = "The shop is still loading – try again in a moment." } end
	local d = ctx.daten[p]
	local passes, produkte = {}, {}
	for _, pass in Shop.PASSES do
		table.insert(passes, { key = pass.key, id = pass.id, icon = pass.icon, name = pass.name, text = pass.text,
			preis = preise[pass.id] or pass.preis, hat = Shop.hat(p, pass.key), bereit = pass.id ~= 0 })
	end
	for _, pr in Shop.PRODUKTE do
		if not (pr.einmal and d.starterGekauft) then
			table.insert(produkte, { key = pr.key, id = pr.id, name = pr.name, text = pr.text, tag = pr.tag, geld = pr.geld,
				preis = preise[pr.id] or pr.preis, bereit = pr.id ~= 0, einmal = pr.einmal })
		end
	end
	return {
		passes = passes, produkte = produkte, geld = d.geld, boost = Shop.boostRest(p), premium = Shop.premium(p),
		freunde = p:GetAttribute("FreundeBonus") == true, geldFaktor = Shop.faktor(p, "geld"), xpFaktor = Shop.faktor(p, "xp"),
		bonus = Shop.BONUS,
	}
end

-- what a developer product gives (also used by the Studio test command)
local function gewaehren(p, pr)
	local d = ctx.daten[p]
	if pr.geld then ctx.geldGeben(p, pr.geld, pr.name, true) end
	if pr.boost then
		d.boostBis = math.max(os.time(), d.boostBis or 0) + pr.boost * 60
	end
	if pr.einmal then d.starterGekauft = true end
	attribute(p)
	ctx.geaendert(p)
	ctx.fahrEvent:FireClient(p, { typ = "belohnung", text = "🛒 Thank you! " .. pr.name .. " received." })
end
Shop.gewaehren = gewaehren

function Shop.testKauf(p, key)
	if not RunService:IsStudio() then return { fehler = "Only in Studio." } end
	local pass = passNach("key", key)
	if pass then
		local d = ctx.daten[p]
		d.passes = d.passes or {}
		d.passes[key] = not d.passes[key] or nil
		attribute(p)
		vipSchild(p)
		passAutos(p)
		ctx.geaendert(p)
		return { text = ("Test: pass %s %s."):format(pass.name, d.passes[key] and "ON" or "OFF") }
	end
	local pr = produktNach("key", key)
	if pr then
		gewaehren(p, pr)
		return { text = "Test purchase: " .. pr.name }
	end
	return { fehler = "Unknown item." }
end

function Shop.starten(c)
	ctx = c
	-- real Robux prices from Roblox (so the shop always shows the price you set in the dashboard)
	task.spawn(function()
		for _, liste in { { Shop.PASSES, Enum.InfoType.GamePass }, { Shop.PRODUKTE, Enum.InfoType.Product } } do
			for _, e in liste[1] do
				if e.id ~= 0 then
					local ok, info = pcall(function() return MarketplaceService:GetProductInfo(e.id, liste[2]) end)
					if ok and type(info) == "table" and info.PriceInRobux then preise[e.id] = info.PriceInRobux end
				end
			end
		end
	end)

	-- developer products: must be safe against double delivery (Roblox may call this again)
	MarketplaceService.ProcessReceipt = function(info)
		local p = Players:GetPlayerByUserId(info.PlayerId)
		local d = p and ctx.daten[p]
		if not d then return Enum.ProductPurchaseDecision.NotProcessedYet end
		d.kaeufe = d.kaeufe or {}
		if table.find(d.kaeufe, info.PurchaseId) then return Enum.ProductPurchaseDecision.PurchaseGranted end
		local pr = produktNach("id", info.ProductId)
		if not pr then
			warn("Shop: unknown product " .. tostring(info.ProductId))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		table.insert(d.kaeufe, info.PurchaseId)
		while #d.kaeufe > 100 do table.remove(d.kaeufe, 1) end
		gewaehren(p, pr)
		if not ctx.speichernSofort(p) then
			-- the coins are in the game already; the next regular save (or leaving) stores them
			warn("Shop: purchase granted, saving right now failed (will be saved later)")
		end
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(p, id, gekauft)
		if not gekauft then return end
		local pass = passNach("id", id)
		if not pass then return end
		besitz[p] = besitz[p] or {}
		besitz[p][pass.key] = true
		attribute(p)
		vipSchild(p)
		passAutos(p)
		ctx.fahrEvent:FireClient(p, { typ = "belohnung", text = ("%s %s unlocked – thank you!"):format(pass.icon, pass.name) })
	end)

	Players.PlayerMembershipChanged:Connect(function(p)
		if ctx.daten[p] then attribute(p) end
	end)

	-- boost timer runs out -> update the multipliers shown in the game
	task.spawn(function()
		while true do
			task.wait(15)
			for _, p in Players:GetPlayers() do
				if ctx.daten[p] then attribute(p) end
			end
		end
	end)

	Players.PlayerAdded:Connect(function(p) task.spawn(Shop.spielerDa, p) end)
	for _, p in Players:GetPlayers() do task.spawn(Shop.spielerDa, p) end
	Players.PlayerRemoving:Connect(function(p) besitz[p] = nil end)
end

return Shop
]=====])
neu("ModuleScript", "Belohnungen", server, [=====[
-- Reasons to come back (server): daily login streak, playtime gifts, friends / group bonus,
-- achievements with tiers incl. license classes, optional Roblox badges.
--
-- Design notes (what keeps players):
--  * a reward is always "almost there": every list shows the next tiers, not just the next one
--  * daily streak bridges sessions (missing a day starts again at day 1)
--  * the first playtime gift comes after 10 minutes (Roblox pays creators for 10+ min sessions)
--  * playing with friends gives a bonus (friends bring friends)
-- All numbers can be changed here.
local Players = game:GetService("Players")
local BadgeService = game:GetService("BadgeService")

local Belohnungen = {}

-- 7-day calendar, starts again after day 7 (the streak counter keeps going)
Belohnungen.TAEGLICH = {
	{ geld = 150 }, { geld = 250 }, { geld = 350, xp = 50 }, { geld = 500 },
	{ geld = 650 }, { geld = 800, xp = 100 }, { geld = 2000, xp = 300, gross = true },
}

-- gifts for playing time on one day (minutes)
Belohnungen.SPIELZEIT = {
	{ min = 10, geld = 100 }, { min = 25, geld = 200 }, { min = 45, geld = 350 },
	{ min = 70, geld = 500, xp = 100 }, { min = 100, geld = 800, xp = 150 },
}

-- Roblox group: put the group ID here (0 = off). Members get a one-time gift.
Belohnungen.GRUPPE_ID = 0
Belohnungen.GRUPPE_GESCHENK = 1000

-- achievements: wert(d) = current value, stufen = goals with rewards, badge = Roblox badge ID for the last tier (0 = none)
Belohnungen.ERFOLGE = {
	{ id = "klasseB", kategorie = "license", icon = "🪪", name = "Class B – Car", text = "Pass the driving test",
		wert = function(d) return d.fuehrerschein and 1 or 0 end, stufen = { { 1, 500, 100 } }, badge = 0 },
	{ id = "klasseC", kategorie = "license", icon = "🚚", name = "Class C – Truck", text = "Pass the truck test",
		wert = function(d) return d.lkwFuehrerschein and 1 or 0 end, stufen = { { 1, 1000, 200 } }, badge = 0 },
	{ id = "klasseCE", kategorie = "license", icon = "🚛", name = "Class CE – Heavy load", text = "Unlock the Mega Truck (15 truck jobs)",
		wert = function(d) return d.lkwFahrten or 0 end, stufen = { { 5, 500, 100 }, { 15, 2000, 400 } }, badge = 0 },
	{ id = "taxi", kategorie = "license", icon = "🚕", name = "Taxi license", text = "Drive taxi passengers",
		wert = function(d) return d.taxiFahrten or 0 end, stufen = { { 10, 400, 80 }, { 50, 1500, 250 }, { 200, 5000, 600 } }, badge = 0 },
	{ id = "lieferungen", kategorie = "jobs", icon = "📦", name = "Delivery hero", text = "Deliver packages and pizzas",
		wert = function(d) return d.lieferungen or 0 end, stufen = { { 10, 300, 60 }, { 50, 1000, 200 }, { 200, 4000, 500 }, { 1000, 15000, 1500 } }, badge = 0 },
	{ id = "km", kategorie = "driving", icon = "🛣", name = "Road trip", text = "Drive kilometers in your own cars",
		wert = function(d) return math.floor(d.kmGesamt or 0) end, stufen = { { 10, 300, 60 }, { 50, 1200, 200 }, { 250, 5000, 600 }, { 1000, 20000, 2000 } }, badge = 0 },
	{ id = "perfekt", kategorie = "driving", icon = "🏆", name = "Perfect driver", text = "Lessons or tests without a single mistake",
		wert = function(d) return d.perfekt or 0 end, stufen = { { 1, 200, 50 }, { 5, 800, 150 }, { 25, 3000, 400 }, { 100, 10000, 1200 } }, badge = 0 },
	{ id = "autos", kategorie = "collection", icon = "🚗", name = "Car collector", text = "Own different cars",
		wert = function(d) return #(d.autos or {}) end, stufen = { { 1, 300, 50 }, { 3, 1500, 200 }, { 5, 5000, 500 }, { 8, 15000, 1500 } }, badge = 0 },
	{ id = "level", kategorie = "collection", icon = "⭐", name = "Experienced", text = "Reach a level",
		wert = function(d) return math.floor(math.sqrt((d.xp or 0) / 150)) + 1 end, stufen = { { 5, 500, 0 }, { 10, 1500, 0 }, { 20, 5000, 0 }, { 40, 20000, 0 } }, badge = 0 },
	{ id = "serie", kategorie = "loyal", icon = "🔥", name = "Loyal driver", text = "Daily reward streak (days in a row)",
		wert = function(d) return d.login and d.login.beste or 0 end, stufen = { { 3, 500, 50 }, { 7, 1500, 150 }, { 14, 4000, 400 }, { 30, 12000, 1000 } }, badge = 0 },
	{ id = "freunde", kategorie = "loyal", icon = "🤝", name = "Better together", text = "Minutes played with a friend on the server",
		wert = function(d) return math.floor((d.freundeSek or 0) / 60) end, stufen = { { 10, 500, 100 }, { 60, 2000, 300 }, { 300, 6000, 800 } }, badge = 0 },
	{ id = "villa", kategorie = "collection", icon = "🏡", name = "Home owner", text = "Buy a villa",
		wert = function(d) local n = 0 for _ in d.villen or {} do n += 1 end return n end, stufen = { { 1, 2000, 300 } }, badge = 0 },
}

local ctx
local freundeCache = {} -- ["a:b"] = true/false

local function heute() return os.date("!%Y-%m-%d") end
local function gestern() return os.date("!%Y-%m-%d", os.time() - 86400) end

local function login(d)
	d.login = d.login or { letzte = "", serie = 0, beste = 0 }
	return d.login
end
local function spielzeit(d)
	if not d.spielzeit or d.spielzeit.tag ~= heute() then
		d.spielzeit = { tag = heute(), sek = 0, abgeholt = {} }
	end
	return d.spielzeit
end

-- next daily reward: which day of the calendar and is it ready?
local function taeglichInfo(d)
	local l = login(d)
	local bereit = l.letzte ~= heute()
	local serie = bereit and (l.letzte == gestern() and l.serie + 1 or 1) or l.serie
	local tagNr = (serie - 1) % #Belohnungen.TAEGLICH + 1
	return { bereit = bereit, serie = serie, tag = tagNr, verloren = bereit and l.serie > 0 and l.letzte ~= gestern() }
end

local function erfolgStand(d, e)
	d.erfolge = d.erfolge or {}
	local abgeholt = d.erfolge[e.id] or 0      -- how many tiers were claimed
	return e.wert(d), abgeholt
end

-- number of rewards that can be claimed right now (red dot on the button)
function Belohnungen.offen(p)
	local d = ctx.daten[p]
	if not d then return 0 end
	local n = taeglichInfo(d).bereit and 1 or 0
	local sz = spielzeit(d)
	for i, s in Belohnungen.SPIELZEIT do
		if sz.sek >= s.min * 60 and not sz.abgeholt[i] then n += 1 end
	end
	if Belohnungen.GRUPPE_ID ~= 0 and not d.gruppeGeschenk and p:GetAttribute("InGruppe") then n += 1 end
	for _, e in Belohnungen.ERFOLGE do
		local wert, abgeholt = erfolgStand(d, e)
		local stufe = e.stufen[abgeholt + 1]
		if stufe and wert >= stufe[1] then n += 1 end
	end
	return n
end

local function markieren(p)
	p:SetAttribute("BelohnungenOffen", Belohnungen.offen(p))
end
Belohnungen.markieren = markieren

function Belohnungen.status(p)
	if not ctx then return { fehler = "Still loading – try again in a moment." } end
	local d = ctx.daten[p]
	local t = taeglichInfo(d)
	local sz = spielzeit(d)
	local geschenke = {}
	for i, s in Belohnungen.SPIELZEIT do
		table.insert(geschenke, { nr = i, min = s.min, geld = s.geld, xp = s.xp, abgeholt = sz.abgeholt[i] == true, bereit = sz.sek >= s.min * 60 })
	end
	local erfolge = {}
	for _, e in Belohnungen.ERFOLGE do
		local wert, abgeholt = erfolgStand(d, e)
		local stufen = {}
		for i, s in e.stufen do
			table.insert(stufen, { ziel = s[1], geld = s[2], xp = s[3], abgeholt = i <= abgeholt })
		end
		table.insert(erfolge, { id = e.id, kategorie = e.kategorie, icon = e.icon, name = e.name, text = e.text, wert = wert, stufen = stufen, abgeholt = abgeholt })
	end
	return {
		taeglich = { liste = Belohnungen.TAEGLICH, bereit = t.bereit, serie = t.serie, tag = t.tag, verloren = t.verloren, beste = login(d).beste },
		spielzeit = { sek = sz.sek, geschenke = geschenke },
		erfolge = erfolge,
		gruppe = Belohnungen.GRUPPE_ID ~= 0 and { id = Belohnungen.GRUPPE_ID, geschenk = Belohnungen.GRUPPE_GESCHENK, drin = p:GetAttribute("InGruppe") == true, abgeholt = d.gruppeGeschenk == true } or nil,
		freunde = p:GetAttribute("FreundeBonus") == true,
		geld = d.geld,
	}
end

local function geben(p, geld, xp, grund)
	if geld and geld > 0 then ctx.geldGeben(p, geld, grund) end
	if xp and xp > 0 then ctx.xpGeben(p, xp, grund) end
end

function Belohnungen.abholen(p, eingabe)
	if not ctx then return { fehler = "Still loading – try again in a moment." } end
	local d = ctx.daten[p]
	if type(eingabe) ~= "table" then return { fehler = "?" } end
	local text
	if eingabe.art == "taeglich" then
		local t = taeglichInfo(d)
		if not t.bereit then return { fehler = "You already got today's reward. Come back tomorrow!" } end
		local l = login(d)
		l.serie, l.letzte = t.serie, heute()
		l.beste = math.max(l.beste or 0, l.serie)
		local b = Belohnungen.TAEGLICH[t.tag]
		geben(p, b.geld, b.xp, ("Daily reward – day %d"):format(t.tag))
		text = ("🔥 Day %d in a row! Come back tomorrow for day %d."):format(t.serie, t.tag % #Belohnungen.TAEGLICH + 1)
	elseif eingabe.art == "spielzeit" then
		local nr = tonumber(eingabe.nr)
		local s = nr and Belohnungen.SPIELZEIT[nr]
		local sz = spielzeit(d)
		if not s then return { fehler = "?" } end
		if sz.abgeholt[nr] then return { fehler = "Already claimed." } end
		if sz.sek < s.min * 60 then return { fehler = ("Play %d more minutes for this gift."):format(math.ceil((s.min * 60 - sz.sek) / 60)) } end
		sz.abgeholt[nr] = true
		geben(p, s.geld, s.xp, ("Playtime gift (%d min)"):format(s.min))
		text = "🎁 Playtime gift claimed!"
	elseif eingabe.art == "erfolg" then
		local e
		for _, x in Belohnungen.ERFOLGE do if x.id == eingabe.id then e = x end end
		if not e then return { fehler = "?" } end
		local wert, abgeholt = erfolgStand(d, e)
		local s = e.stufen[abgeholt + 1]
		if not s then return { fehler = "All tiers done!" } end
		if wert < s[1] then return { fehler = "Not reached yet." } end
		d.erfolge[e.id] = abgeholt + 1
		geben(p, s[2], s[3], e.icon .. " " .. e.name)
		if abgeholt + 1 == #e.stufen and e.badge ~= 0 then
			pcall(function() BadgeService:AwardBadge(p.UserId, e.badge) end)
		end
		text = ("%s %s – tier %d reached!"):format(e.icon, e.name, abgeholt + 1)
	elseif eingabe.art == "gruppe" then
		if Belohnungen.GRUPPE_ID == 0 or d.gruppeGeschenk then return { fehler = "Not available." } end
		if not p:GetAttribute("InGruppe") then return { fehler = "Join our Roblox group first, then rejoin the game." } end
		d.gruppeGeschenk = true
		geben(p, Belohnungen.GRUPPE_GESCHENK, 0, "Group gift")
		text = "👥 Thanks for joining the group!"
	else
		return { fehler = "?" }
	end
	ctx.geaendert(p)
	markieren(p)
	return { text = text, status = Belohnungen.status(p) }
end

-- friends on the same server -> bonus for both
local function freunde(a, b)
	local k = a.UserId < b.UserId and (a.UserId .. ":" .. b.UserId) or (b.UserId .. ":" .. a.UserId)
	if freundeCache[k] == nil then
		local ok, ja = pcall(function() return a:IsFriendsWith(b.UserId) end)
		freundeCache[k] = ok and ja == true
	end
	return freundeCache[k]
end
local function freundeNeu()
	local alle = Players:GetPlayers()
	for _, p in alle do
		local hat = false
		for _, q in alle do
			if q ~= p and freunde(p, q) then hat = true break end
		end
		if (p:GetAttribute("FreundeBonus") == true) ~= hat then
			p:SetAttribute("FreundeBonus", hat or nil)
			if hat then ctx.fahrEvent:FireClient(p, { typ = "belohnung", text = "🤝 A friend is here: +10 % coins and XP while you play together!" }) end
			if ctx.Shop then ctx.Shop.attribute(p) end
		end
	end
end
Belohnungen.freundeNeu = freundeNeu

function Belohnungen.spielerDa(p)
	if Belohnungen.GRUPPE_ID ~= 0 then
		local ok, drin = pcall(function() return p:IsInGroup(Belohnungen.GRUPPE_ID) end)
		p:SetAttribute("InGruppe", ok and drin or nil)
	end
	for _ = 1, 40 do
		if ctx.daten[p] then break end
		task.wait(0.25)
	end
	if not ctx.daten[p] then return end
	freundeNeu()
	markieren(p)
	-- daily reward waiting -> the client opens the rewards window
	if taeglichInfo(ctx.daten[p]).bereit then
		ctx.fahrEvent:FireClient(p, { typ = "taeglich" })
	end
end

-- called every few seconds for every player: playtime, friend minutes, "reward ready" messages
function Belohnungen.takt(p, sekunden)
	local d = ctx.daten[p]
	if not d then return end
	local sz = spielzeit(d)
	local vorher = sz.sek
	sz.sek += sekunden
	if p:GetAttribute("FreundeBonus") then d.freundeSek = (d.freundeSek or 0) + sekunden end
	for _, s in Belohnungen.SPIELZEIT do
		if vorher < s.min * 60 and sz.sek >= s.min * 60 then
			ctx.fahrEvent:FireClient(p, { typ = "belohnung", text = ("🎁 Playtime gift ready (%d min)! Open 🎁 Rewards."):format(s.min) })
		end
	end
	local alt = p:GetAttribute("BelohnungenOffen") or 0
	local neu = Belohnungen.offen(p)
	if neu > alt then
		-- a new achievement tier is ready?
		for _, e in Belohnungen.ERFOLGE do
			local wert, abgeholt = erfolgStand(d, e)
			local s = e.stufen[abgeholt + 1]
			local gemeldet = d.erfolgGemeldet or {}
			d.erfolgGemeldet = gemeldet
			if s and wert >= s[1] and gemeldet[e.id] ~= abgeholt + 1 then
				gemeldet[e.id] = abgeholt + 1
				ctx.fahrEvent:FireClient(p, { typ = "belohnung", text = ("%s Achievement ready: %s (tier %d)"):format(e.icon, e.name, abgeholt + 1) })
			end
		end
	end
	p:SetAttribute("BelohnungenOffen", neu)
end

function Belohnungen.starten(c)
	ctx = c
	Players.PlayerAdded:Connect(function(p) task.spawn(Belohnungen.spielerDa, p) end)
	for _, p in Players:GetPlayers() do task.spawn(Belohnungen.spielerDa, p) end
	Players.PlayerRemoving:Connect(function()
		task.defer(freundeNeu)
	end)
	task.spawn(function()
		while true do
			task.wait(10)
			for _, p in Players:GetPlayers() do
				Belohnungen.takt(p, 10)
			end
		end
	end)
end

return Belohnungen
]=====])
neu("ModuleScript", "Karosserien", server, [=====[
-- GENERATED by tools/mesh/*.py - do not edit by hand.
-- Round bodies for the private cars. Import dist/mesh/<vorlage>.obj with the 3D Importer
-- and put the model (named like <vorlage>) into ServerStorage; then the car uses it.
return {
	gs = {
		vorlage = "VantaGS",
		sitzY = 0.55,
		sitzX = 0.85,
		armaturenZ = -2,
		drehung = 180,
		mesh = {
			BlinkHL = { groesse = { 0.5524, 0.2467, 0.4799 }, mitte = { -2.701, 3.1016, 7.9864 }, n = "BlinkerL", a = "blinker" },
			BlinkHR = { groesse = { 0.4701, 0.2288, 0.4214 }, mitte = { 2.6988, 3.1193, 7.9868 }, n = "BlinkerR", a = "blinker" },
			BlinkVL = { groesse = { 0.3767, 0.1795, 0.3416 }, mitte = { -2.9922, 2.5034, -6.9528 }, n = "BlinkerL", a = "blinker" },
			BlinkVR = { groesse = { 0.3991, 0.1826, 0.3575 }, mitte = { 2.947, 2.5189, -6.9665 }, n = "BlinkerR", a = "blinker" },
			Glas = { groesse = { 6.1492, 1.7719, 10.2832 }, mitte = { 0.0027, 4.1297, 1.6394 } },
			Heckpartie = { groesse = { 7.1411, 3.2144, 6.3635 }, mitte = { 0.0007, 2.1201, -4.6047 } },
			Karosserie = { groesse = { 4.727, 2.1078, 0.6649 }, mitte = { 0.0115, 1.61, -7.9924 } },
			LichtHL = { groesse = { 2.5489, 0.4133, 0.6863 }, mitte = { -1.2671, 3.2109, 8.4094 }, n = "Ruecklicht", a = "neon_rot" },
			LichtHR = { groesse = { 2.5547, 0.4126, 0.6912 }, mitte = { 1.2847, 3.2112, 8.4058 }, n = "Ruecklicht", a = "neon_rot" },
			LichtVL = { groesse = { 2.8993, 0.3499, 1.1851 }, mitte = { -1.4433, 2.3994, -7.5993 }, n = "Scheinwerfer", a = "scheinwerfer" },
			LichtVR = { groesse = { 2.8279, 0.3572, 1.1588 }, mitte = { 1.42, 2.4077, -7.611 }, n = "Scheinwerfer", a = "scheinwerfer" },
			Mittelteil = { groesse = { 7.4932, 4.3711, 11.3167 }, mitte = { 0.0032, 2.7252, 3.4283 } },
			Verkleidung = { groesse = { 5.5159, 1.8268, 0.5559 }, mitte = { -0.0003, 1.4527, -8.0507 } },
			Verkleidung2 = { groesse = { 7.1161, 2.0658, 1.3215 }, mitte = { -0.0013, 1.5727, -7.3646 }, n = "Verkleidung2", a = "schwarz" },
			Verkleidung3 = { groesse = { 7.4877, 4.1019, 15.8159 }, mitte = { 0.0059, 2.5626, 1.1246 }, n = "Verkleidung2", a = "schwarz" },
			Radhaus = { groesse = { 6.9, 2.3083, 13.7185 }, mitte = { 0, 1.9659, 0 }, n = "Radhaus", a = "schwarz" },
		},
		anbau = {
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 0.466 }, p = { 3.289, 1.265, -2.7 }, s = true, d = { -0.0583, 0.9983, 0 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 0.465 }, p = { 3.282, 1.695, -2.7 }, s = true, d = { 0.0262, 0.9997, 0 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 0.465 }, p = { 3.285, 2.125, -2.7 }, s = true, d = { -0.0128, 0.9999, 0 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 0.467 }, p = { 3.263, 2.555, -2.7 }, s = true, d = { -0.0905, 0.9959, 0 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 0.513 }, p = { 3.139, 2.985, -2.7 }, s = true, d = { -0.4352, 0.9004, 0 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 0.491 }, p = { 3.23, 1.278, 0.9 }, s = true, d = { 0.0317, 0.9995, 0 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 0.491 }, p = { 3.243, 1.734, 0.9 }, s = true, d = { 0.0256, 0.9997, 0 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 0.492 }, p = { 3.266, 2.19, 0.9 }, s = true, d = { 0.077, 0.997, 0 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 0.492 }, p = { 3.266, 2.646, 0.9 }, s = true, d = { -0.0808, 0.9967, 0 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 0.561 }, p = { 3.116, 3.102, 0.9 }, s = true, d = { -0.4972, 0.8676, 0 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 0.559 }, p = { 3.43, 2.73, 4.05 }, s = true, d = { -0.4006, 0.9162, 0 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 0.658 }, p = { 3.126, 3.21, 4.05 }, s = true, d = { -0.6373, 0.7706, 0 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 0.885 }, p = { 3.294, 1.05, -2.175 }, s = true, d = { -0.0101, 0, 0.9999 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 0.885 }, p = { 3.277, 1.05, -1.325 }, s = true, d = { -0.0295, 0, 0.9996 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 0.885 }, p = { 3.255, 1.05, -0.475 }, s = true, d = { -0.0216, 0, 0.9998 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 0.885 }, p = { 3.236, 1.05, 0.375 }, s = true, d = { -0.0242, 0, 0.9997 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 0.773 }, p = { 3.221, 1.05, 1.369 }, s = true, d = { -0.0063, 0, 1 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 0.773 }, p = { 3.218, 1.05, 2.106 }, s = true, d = { -0.0019, 0, 1 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 0.781 }, p = { 3.273, 1.05, 2.844 }, s = true, d = { 0.1514, 0, 0.9885 } },
			{ n = "Griff", a = "glanzschwarz", g = { 0.06, 0.12, 0.75 }, p = { 3.222, 2.95, -0.1 }, s = true },
			{ n = "Griff", a = "glanzschwarz", g = { 0.06, 0.12, 0.75 }, p = { 3.287, 2.95, 3.2 }, s = true },
			{ n = "Fensterleiste", a = "chrom", g = { 0.05, 0.05, 1.451 }, p = { 2.908, 3.32, -1.7 }, s = true, d = { 0.0181, 0.0286, 0.9994 } },
			{ n = "Fensterleiste", a = "chrom", g = { 0.05, 0.05, 1.551 }, p = { 2.917, 3.37, -0.25 }, s = true, d = { -0.0051, 0.04, 0.9992 } },
			{ n = "Fensterleiste", a = "chrom", g = { 0.05, 0.05, 1.551 }, p = { 2.91, 3.43, 1.25 }, s = true, d = { -0.0041, 0.04, 0.9992 } },
			{ n = "Fensterleiste", a = "chrom", g = { 0.05, 0.05, 1.552 }, p = { 2.885, 3.49, 2.75 }, s = true, d = { -0.029, 0.04, 0.9988 } },
			{ n = "Fensterleiste", a = "chrom", g = { 0.05, 0.05, 1.158 }, p = { 2.809, 3.56, 4.05 }, s = true, d = { -0.0979, 0.0722, 0.9926 } },
		},
		kollision = {
			{ g = { 6.6, 0.4, 15.6 }, p = { 0, 3.1, 0.3 } },
			{ g = { 5.6, 1.3, 7 }, p = { 0, 4.2, 1 } },
		},
		kennzeichen = { vorne = { 1.45, -8.179 }, hinten = { 2.05, 9.167 } },
		spoiler = { 4.217, 7.6, 0.4 },
	},
	limousine = {
		vorlage = "Executive",
		sitzY = 1.45,
		armaturenZ = -1.6,
		mesh = {
			Karosserie = { groesse = { 7.8696, 3.0097, 17 }, mitte = { -0, 2.2549, 0 } },
			Verkleidung = { groesse = { 7.9875, 2.3486, 17.068 }, mitte = { -0, 1.9243, 0 } },
			Glas = { groesse = { 6.3973, 2.2752, 8.65 }, mitte = { 0, 4.4523, 1.675 } },
			Dach = { groesse = { 6.4854, 2.3134, 5.8 }, mitte = { 0, 4.4633, 2.9 } },
			LichtVR = { groesse = { 1.6458, 0.397, 1.7209 }, mitte = { 2.4403, 2.7833, -7.2928 }, n = "Scheinwerfer", a = "scheinwerfer" },
			LichtVL = { groesse = { 1.6458, 0.397, 1.7209 }, mitte = { -2.4403, 2.7833, -7.2928 }, n = "Scheinwerfer", a = "scheinwerfer" },
			LeisteVR = { groesse = { 1.52, 0.1848, 0.7394 }, mitte = { 2.4744, 2.5859, -7.874 }, n = "Tagfahrlicht", a = "neon_weiss" },
			LeisteVL = { groesse = { 1.52, 0.1848, 0.7394 }, mitte = { -2.4744, 2.5859, -7.874 }, n = "Tagfahrlicht", a = "neon_weiss" },
			BlinkVR = { groesse = { 0.2708, 0.3249, 1.4183 }, mitte = { 3.3719, 2.7281, -6.6028 }, n = "BlinkerR", a = "blinker" },
			BlinkVL = { groesse = { 0.2708, 0.3249, 1.4183 }, mitte = { -3.3719, 2.7281, -6.6028 }, n = "BlinkerL", a = "blinker" },
			Grill = { groesse = { 2.9, 0.6205, 0.3487 }, mitte = { 0, 2.3303, -8.3506 }, n = "Kuehlergrill", a = "grill" },
			Einlass = { groesse = { 4.7162, 0.4208, 0.6208 }, mitte = { 0, 1.1635, -8.2146 }, n = "Lufteinlass", a = "grill" },
			EckeinlassR = { groesse = { 0.6367, 0.9282, 1.5674 }, mitte = { 2.8454, 1.4876, -7.4974 }, n = "Seiteneinlass", a = "glanzschwarz" },
			EckeinlassL = { groesse = { 0.6367, 0.9282, 1.5674 }, mitte = { -2.8454, 1.4876, -7.4974 }, n = "Seiteneinlass", a = "glanzschwarz" },
			LichtHR = { groesse = { 1.746, 0.2974, 0.8899 }, mitte = { 2.3693, 3.0687, 8.0751 }, n = "Ruecklicht", a = "neon_rot" },
			LichtHL = { groesse = { 1.746, 0.2974, 0.8899 }, mitte = { -2.3693, 3.0687, 8.0751 }, n = "Ruecklicht", a = "neon_rot" },
			BlinkHR = { groesse = { 0.4519, 0.2137, 0.1044 }, mitte = { 1.2759, 3.0369, 8.4728 }, n = "BlinkerR", a = "blinker" },
			BlinkHL = { groesse = { 0.4519, 0.2137, 0.1044 }, mitte = { -1.2759, 3.0369, 8.4728 }, n = "BlinkerL", a = "blinker" },
			Blende = { groesse = { 1.96, 0.16, 0.09 }, mitte = { 0, 3.03, 8.48 }, n = "Heckblende", a = "glanzschwarz" },
			Diffusor = { groesse = { 5.0219, 0.5521, 0.9056 }, mitte = { 0, 1.1989, 8.0722 }, n = "Diffusor", a = "carbon" },
			KiemeR = { groesse = { 0.1332, 0.3289, 0.7 }, mitte = { 3.8584, 2.3645, -3 }, n = "Kieme", a = "glanzschwarz" },
			KiemeL = { groesse = { 0.1332, 0.3289, 0.7 }, mitte = { -3.8584, 2.3645, -3 }, n = "Kieme", a = "glanzschwarz" },
			Griff0R = { groesse = { 0.4246, 0.2088, 0.7029 }, mitte = { 3.148, 3.1696, -0.8994 }, n = "Griff", a = "chrom" },
			Griff0L = { groesse = { 0.4246, 0.2088, 0.7029 }, mitte = { -3.148, 3.1696, -0.8994 }, n = "Griff", a = "chrom" },
			Griff1R = { groesse = { 0.27, 0.1987, 0.7039 }, mitte = { 3.4475, 3.1717, 2.6999 }, n = "Griff", a = "chrom" },
			Griff1L = { groesse = { 0.27, 0.1987, 0.7039 }, mitte = { -3.4475, 3.1717, 2.6999 }, n = "Griff", a = "chrom" },
		},
		anbau = {
			{ n = "Spiegel", a = "lack", g = { 0.62, 0.4, 0.8 }, p = { 3.505, 3.46, -1.95 }, s = true },
			{ n = "Spiegelfuss", a = "glanzschwarz", g = { 0.5, 0.12, 0.35 }, p = { 3.155, 3.3, -1.85 }, s = true },
			{ n = "Frontlippe", a = "carbon", g = { 5.6, 0.06, 0.4 }, p = { 0, 0.9, -8.215 }, s = false },
			{ n = "Auspuff", a = "chrom", g = { 0.5, 0.4, 0.4 }, p = { 1.7, 1.2, 8.505 }, s = true, f = "zyl" },
			{ n = "Auspuff", a = "chrom", g = { 0.5, 0.4, 0.4 }, p = { 2.22, 1.2, 8.35 }, s = true, f = "zyl" },
			{ n = "Fensterleiste", a = "chrom", g = { 0.05, 0.05, 1.35 }, p = { 2.538, 3.313, -1.65 }, s = true, d = { -0.0038, 0.0187, 0.9998 } },
			{ n = "Fensterleiste", a = "chrom", g = { 0.05, 0.05, 1.551 }, p = { 2.53, 3.355, -0.25 }, s = true, d = { -0.0067, 0.0396, 0.9992 } },
			{ n = "Fensterleiste", a = "chrom", g = { 0.05, 0.05, 1.552 }, p = { 2.518, 3.42, 1.25 }, s = true, d = { -0.01, 0.048, 0.9988 } },
			{ n = "Fensterleiste", a = "chrom", g = { 0.05, 0.05, 1.551 }, p = { 2.505, 3.488, 2.75 }, s = true, d = { -0.0067, 0.0416, 0.9991 } },
			{ n = "Fensterleiste", a = "chrom", g = { 0.05, 0.05, 1.25 }, p = { 2.51, 3.533, 4.1 }, s = true, d = { 0.0167, 0.0234, 0.9996 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 0.707 }, p = { 3.81, 1.775, -2.4 }, s = true, d = { 0.253, 0.9675, 0 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 0.701 }, p = { 3.823, 2.425, -2.4 }, s = true, d = { -0.2177, 0.976, 0 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 1.537 }, p = { 3.055, 3.035, -2.4 }, s = true, d = { -0.9252, 0.3794, 0 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 0.789 }, p = { 3.74, 1.65, 1.2 }, s = true, d = { 0.3714, 0.9285, 0 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 0.737 }, p = { 3.853, 2.35, 1.2 }, s = true, d = { -0.0783, 0.9969, 0 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 1.416 }, p = { 3.23, 3.05, 1.2 }, s = true, d = { -0.8619, 0.507, 0 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 0.445 }, p = { 3.528, 3.175, 4.1 }, s = true, d = { -0.7926, 0.6097, 0 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 0.696 }, p = { 3.05, 3.4, 4.1 }, s = true, d = { -0.9531, 0.3026, 0 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 1.291 }, p = { 2.55, 3.031, -6.925 }, s = true, d = { 0, 0.0995, 0.995 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 1.337 }, p = { 2.55, 3.133, -5.65 }, s = true, d = { 0, 0.0614, 0.9981 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 1.337 }, p = { 2.55, 3.208, -4.35 }, s = true, d = { 0, 0.0538, 0.9986 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 1.086 }, p = { 2.55, 3.268, -3.175 }, s = true, d = { 0, 0.0476, 0.9989 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 1.286 }, p = { -1.825, 3.593, 5.45 }, s = false, d = { 0.9988, 0.0479, 0 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 1.235 }, p = { -0.6, 3.623, 5.45 }, s = false, d = { 1, 0, 0 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 1.235 }, p = { 0.6, 3.623, 5.45 }, s = false, d = { 1, 0, 0 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 1.286 }, p = { 1.825, 3.593, 5.45 }, s = false, d = { 0.9988, -0.0479, 0 } },
		},
		kollision = {
			{ g = { 7.2, 0.4, 16 }, p = { 0, 3, 0 } },
			{ g = { 6, 1.6, 7.5 }, p = { 0, 4.4, 1.2 } },
		},
		kennzeichen = { vorne = { 1.68, -8.555 }, hinten = { 2.2, 8.575 } },
		spoiler = { 4.7125, 7, 0.45 },
	},
	sport = {
		vorlage = "VelocityGT",
		sitzY = 1.25,
		armaturenZ = -0.9,
		mesh = {
			Karosserie = { groesse = { 8.0674, 2.5, 15.5 }, mitte = { -0, 1.8, 0 } },
			Verkleidung = { groesse = { 8.2289, 2.39, 15.562 }, mitte = { -0, 1.745, 0 } },
			Glas = { groesse = { 6.0368, 2.1035, 9 }, mitte = { 0, 3.5781, 2.2 } },
			Dach = { groesse = { 6.1209, 1.8062, 6 }, mitte = { -0, 3.7567, 3.5 } },
			LichtVR = { groesse = { 1.4333, 0.254, 1.3668 }, mitte = { 2.2825, 1.6129, -6.9549 }, n = "Scheinwerfer", a = "scheinwerfer" },
			LichtVL = { groesse = { 1.4333, 0.254, 1.3668 }, mitte = { -2.2825, 1.6129, -6.9549 }, n = "Scheinwerfer", a = "scheinwerfer" },
			LeisteVR = { groesse = { 1.3044, 0.1118, 1.1141 }, mitte = { 2.3344, 1.4688, -7.0956 }, n = "Tagfahrlicht", a = "neon_weiss" },
			LeisteVL = { groesse = { 1.3044, 0.1118, 1.1141 }, mitte = { -2.3344, 1.4688, -7.0956 }, n = "Tagfahrlicht", a = "neon_weiss" },
			BlinkVR = { groesse = { 0.3772, 0.225, 0.7551 }, mitte = { 3.139, 1.5642, -6.1472 }, n = "BlinkerR", a = "blinker" },
			BlinkVL = { groesse = { 0.3772, 0.225, 0.7551 }, mitte = { -3.139, 1.5642, -6.1472 }, n = "BlinkerL", a = "blinker" },
			Einlass = { groesse = { 3.5097, 0.4515, 0.5208 }, mitte = { 0, 0.898, -7.5146 }, n = "Lufteinlass", a = "grill" },
			EckeinlassR = { groesse = { 0.7799, 0.5782, 1.6645 }, mitte = { 2.5701, 1.0109, -6.5373 }, n = "Lufteinlass", a = "grill" },
			EckeinlassL = { groesse = { 0.7799, 0.5782, 1.6645 }, mitte = { -2.5701, 1.0109, -6.5373 }, n = "Lufteinlass", a = "grill" },
			SeitenEinlassR = { groesse = { 0.2319, 0.7644, 0.9054 }, mitte = { 3.8038, 1.6733, 2.7009 }, n = "Seitenlufteinlass", a = "grill" },
			SeitenEinlassL = { groesse = { 0.2319, 0.7644, 0.9054 }, mitte = { -3.8038, 1.6733, 2.7009 }, n = "Seitenlufteinlass", a = "grill" },
			LichtHR = { groesse = { 1.5709, 0.2006, 0.5968 }, mitte = { 2.3317, 2.5396, 7.4766 }, n = "Ruecklicht", a = "neon_rot" },
			LichtHL = { groesse = { 1.5709, 0.2006, 0.5968 }, mitte = { -2.3317, 2.5396, 7.4766 }, n = "Ruecklicht", a = "neon_rot" },
			BlinkHR = { groesse = { 0.3367, 0.2214, 0.6797 }, mitte = { 3.2545, 2.5297, 7.0357 }, n = "BlinkerR", a = "blinker" },
			BlinkHL = { groesse = { 0.3367, 0.2214, 0.6797 }, mitte = { -3.2545, 2.5297, 7.0357 }, n = "BlinkerL", a = "blinker" },
			Band = { groesse = { 3, 0.06, 0.09 }, mitte = { 0, 2.53, 7.73 }, n = "Ruecklichtband", a = "neon_rot" },
			Gitter = { groesse = { 5.011, 0.5019, 0.1395 }, mitte = { 0, 1.9509, 7.7052 }, n = "Heckgitter", a = "grill" },
		},
		anbau = {
			{ n = "Frontsplitter", a = "carbon", g = { 5.8, 0.07, 0.45 }, p = { 0, 0.6, -7.37 }, s = false },
			{ n = "Haubenkante", a = "schwarz", g = { 2.2, 0.04, 0.6 }, p = { 0, 2.255, -5.2 }, s = false, r = { -11, 0, 0 } },
			{ n = "Spiegel", a = "lack", g = { 0.55, 0.38, 0.75 }, p = { 3.52, 2.6, -1.3 }, s = true },
			{ n = "Spiegelfuss", a = "schwarz", g = { 0.45, 0.12, 0.3 }, p = { 3.18, 2.47, -1.2 }, s = true },
			{ n = "Auspuff", a = "chrom", g = { 0.5, 0.36, 0.36 }, p = { 0.45, 1.25, 7.855 }, s = true, f = "zyl" },
			{ n = "Diffusor", a = "carbon", g = { 4.6, 0.08, 0.9 }, p = { 0, 0.98, 7.2 }, s = false },
			{ n = "Abrisskante", a = "lack", g = { 5.8, 0.1, 0.65 }, p = { 0, 3.097, 7.25 }, s = false, r = { -9, 0, 0 } },
			{ n = "Motorgitter", a = "schwarz", g = { 2.6, 0.04, 1.6 }, p = { 0, 3.394, 5.3 }, s = false, r = { -12, 0, 0 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 0.566 }, p = { 3.615, 1.25, -1.95 }, s = true, d = { 0.3387, 0.9409, 0 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 0.544 }, p = { 3.658, 1.75, -1.95 }, s = true, d = { -0.1867, 0.9824, 0 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 0.817 }, p = { 3.28, 2.21, -1.95 }, s = true, d = { -0.8437, 0.5369, 0 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 0.59 }, p = { 3.665, 1.25, 1.9 }, s = true, d = { 0.4327, 0.9015, 0 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 0.535 }, p = { 3.795, 1.75, 1.9 }, s = true, d = { 0.04, 0.9992, 0 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 0.498 }, p = { 3.708, 2.21, 1.9 }, s = true, d = { -0.4211, 0.907, 0 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 1.168 }, p = { 2, 1.963, -6.55 }, s = true, d = { 0, 0.2384, 0.9712 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 1.551 }, p = { 2, 2.208, -5.25 }, s = true, d = { 0, 0.1451, 0.9894 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 1.544 }, p = { 2, 2.401, -3.75 }, s = true, d = { 0, 0.1093, 0.994 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 0.638 }, p = { 2, 2.513, -2.7 }, s = true, d = { 0, 0.0995, 0.995 } },
		},
		kollision = {
			{ g = { 7.2, 0.35, 14.5 }, p = { 0, 2.85, 0 } },
			{ g = { 5.4, 1.3, 5.6 }, p = { 0, 3.75, 0.9 } },
		},
		kennzeichen = { vorne = { 1.42, -7.805 }, hinten = { 1.95, 7.825 } },
		spoiler = { 4, 6.6, 0.9 },
	},
	suv = {
		vorlage = "RangerX",
		mesh = {
			Karosserie = { groesse = { 7.7737, 3.77, 17.5 }, mitte = { -0, 3.035, 0 } },
			Verkleidung = { groesse = { 7.9446, 2.7691, 17.57 }, mitte = { -0, 2.5346, 0 } },
			Glas = { groesse = { 7.1373, 2.6275, 11.75 }, mitte = { 0, 6.0438, 2.575 } },
			Dach = { groesse = { 7.2353, 2.7094, 8.65 }, mitte = { 0, 6.0329, 3.575 } },
			LichtVR = { groesse = { 1.6213, 0.4133, 0.6152 }, mitte = { 2.3579, 4.2139, -8.4674 }, n = "Scheinwerfer", a = "scheinwerfer" },
			LichtVL = { groesse = { 1.6213, 0.4133, 0.6152 }, mitte = { -2.3579, 4.2139, -8.4674 }, n = "Scheinwerfer", a = "scheinwerfer" },
			LeisteVR = { groesse = { 1.4719, 0.1265, 0.3061 }, mitte = { 2.386, 3.9368, -8.637 }, n = "Tagfahrlicht", a = "neon_weiss" },
			LeisteVL = { groesse = { 1.4719, 0.1265, 0.3061 }, mitte = { -2.386, 3.9368, -8.637 }, n = "Tagfahrlicht", a = "neon_weiss" },
			BlinkVR = { groesse = { 0.3333, 0.3826, 0.8471 }, mitte = { 3.3099, 4.1508, -8.0641 }, n = "BlinkerR", a = "blinker" },
			BlinkVL = { groesse = { 0.3333, 0.3826, 0.8471 }, mitte = { -3.3099, 4.1508, -8.0641 }, n = "BlinkerL", a = "blinker" },
			NebelR = { groesse = { 0.6231, 0.1985, 0.2984 }, mitte = { 2.7542, 2.2102, -8.6007 }, n = "Nebelscheinwerfer", a = "neon_weiss" },
			NebelL = { groesse = { 0.6231, 0.1985, 0.2984 }, mitte = { -2.7542, 2.2102, -8.6007 }, n = "Nebelscheinwerfer", a = "neon_weiss" },
			Grill = { groesse = { 3.1, 0.83, 0.09 }, mitte = { 0, 3.565, -8.73 }, n = "Kuehlergrill", a = "grill" },
			Grillleiste = { groesse = { 3.2, 0.09, 0.105 }, mitte = { 0, 4.025, -8.7375 }, n = "Grillchrom", a = "chrom" },
			Einlass = { groesse = { 4.4094, 0.4857, 0.1602 }, mitte = { 0, 2.0771, -8.6949 }, n = "Lufteinlass", a = "grill" },
			LichtHR = { groesse = { 1.617, 0.3616, 0.8824 }, mitte = { 2.3585, 4.4448, 8.3338 }, n = "Ruecklicht", a = "neon_rot" },
			LichtHL = { groesse = { 1.617, 0.3616, 0.8824 }, mitte = { -2.3585, 4.4448, 8.3338 }, n = "Ruecklicht", a = "neon_rot" },
			BlinkHR = { groesse = { 0.2965, 0.3624, 0.8543 }, mitte = { 3.2944, 4.4433, 8.0588 }, n = "BlinkerR", a = "blinker" },
			BlinkHL = { groesse = { 0.2965, 0.3624, 0.8543 }, mitte = { -3.2944, 4.4433, 8.0588 }, n = "BlinkerL", a = "blinker" },
			Band = { groesse = { 3, 0.08, 0.09 }, mitte = { 0, 4.44, 8.73 }, n = "Ruecklichtband", a = "neon_rot" },
		},
		anbau = {
			{ n = "Unterfahrschutz", a = "chrom", g = { 3.2, 0.18, 0.1 }, p = { 0, 1.6, -8.795 }, s = false },
			{ n = "Auspuff", a = "chrom", g = { 0.5, 0.36, 0.36 }, p = { 2.3, 1.75, 8.71 }, s = true, f = "zyl" },
			{ n = "Spiegel", a = "lack", g = { 0.7, 0.5, 0.8 }, p = { 3.3, 4.85, -2.85 }, s = true },
			{ n = "Spiegelfuss", a = "schwarz", g = { 0.5, 0.15, 0.4 }, p = { 2.95, 4.7, -2.75 }, s = true },
			{ n = "Griff", a = "chrom", g = { 0.08, 0.14, 0.75 }, p = { 3.56, 4.4, 0 }, s = true },
			{ n = "Griff", a = "chrom", g = { 0.08, 0.14, 0.75 }, p = { 3.575, 4.45, 3.4 }, s = true },
			{ n = "Zierleiste", a = "chrom", g = { 0.05, 0.08, 6.5 }, p = { 3.725, 2, 0.6 }, s = true },
			{ n = "Dachreling", a = "alu", g = { 0.16, 0.14, 6.2 }, p = { 2.81, 7.403, 2.6 }, s = true },
			{ n = "Dachspoiler", a = "lack", g = { 5.4, 0.12, 0.6 }, p = { 0, 7.25, 6.55 }, s = false },
			{ n = "Bremslicht_oben", a = "neon_rot", g = { 1.2, 0.08, 0.1 }, p = { 0, 7.285, 6.65 }, s = false },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 0.943 }, p = { 3.745, 2.45, -2.95 }, s = true, d = { 0.1322, 0.9912, 0 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 0.935 }, p = { 3.79, 3.35, -2.95 }, s = true, d = { -0.0333, 0.9994, 0 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 1.079 }, p = { 3.44, 4.2, -2.95 }, s = true, d = { -0.6421, 0.7666, 0 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 0.944 }, p = { 3.743, 2.45, 1.05 }, s = true, d = { 0.1376, 0.9905, 0 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 0.935 }, p = { 3.795, 3.35, 1.05 }, s = true, d = { -0.0222, 0.9998, 0 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 1.014 }, p = { 3.503, 4.2, 1.05 }, s = true, d = { -0.5769, 0.8168, 0 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 0.944 }, p = { 3.745, 2.45, 3.3 }, s = true, d = { 0.143, 0.9897, 0 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 0.935 }, p = { 3.803, 3.35, 3.3 }, s = true, d = { -0.0167, 0.9999, 0 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 0.976 }, p = { 3.548, 4.2, 3.3 }, s = true, d = { -0.5262, 0.8504, 0 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 1.457 }, p = { 2.95, 4.528, -7.7 }, s = true, d = { 0, 0.1758, 0.9844 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 1.536 }, p = { 2.95, 4.686, -6.25 }, s = true, d = { 0, 0.0433, 0.9991 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 1.535 }, p = { 2.95, 4.716, -4.75 }, s = true, d = { 0, -0.0033, 1 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 0.588 }, p = { 2.95, 4.683, -3.725 }, s = true, d = { 0, -0.1084, 0.9941 } },
		},
		kollision = {
			{ g = { 7.4, 1.3, 16.5 }, p = { 0, 4.15, 0 } },
			{ g = { 6.6, 2.4, 10 }, p = { 0, 6, 2.4 } },
		},
		kennzeichen = { vorne = { 2.75, -8.835 }, hinten = { 3.45, 8.835 } },
		spoiler = { 7.4, 6.85 },
	},
	track = {
		vorlage = "StrikerTR",
		sitzY = 1.3,
		armaturenZ = -0.4,
		mesh = {
			Karosserie = { groesse = { 8.0465, 2.4997, 16.5 }, mitte = { -0, 1.8499, 0 } },
			Verkleidung = { groesse = { 8.2088, 2.4396, 16.566 }, mitte = { -0, 1.8198, 0 } },
			Glas = { groesse = { 6.2607, 2.2446, 6.75 }, mitte = { 0, 3.6475, 1.925 } },
			Dach = { groesse = { 6.3482, 2.1939, 4.05 }, mitte = { 0, 3.7029, 2.975 } },
			LichtVR = { groesse = { 1.2384, 0.2834, 0.9677 }, mitte = { 2.5023, 1.7084, -7.6902 }, n = "Scheinwerfer", a = "scheinwerfer" },
			LichtVL = { groesse = { 1.2384, 0.2834, 0.9677 }, mitte = { -2.5023, 1.7084, -7.6902 }, n = "Scheinwerfer", a = "scheinwerfer" },
			LeisteVR = { groesse = { 1.1201, 0.0995, 0.7844 }, mitte = { 2.5255, 1.543, -7.7965 }, n = "Tagfahrlicht", a = "neon_weiss" },
			LeisteVL = { groesse = { 1.1201, 0.0995, 0.7844 }, mitte = { -2.5255, 1.543, -7.7965 }, n = "Tagfahrlicht", a = "neon_weiss" },
			BlinkVR = { groesse = { 0.3547, 0.2318, 0.6107 }, mitte = { 3.2492, 1.6376, -7.0514 }, n = "BlinkerR", a = "blinker" },
			BlinkVL = { groesse = { 0.3547, 0.2318, 0.6107 }, mitte = { -3.2492, 1.6376, -7.0514 }, n = "BlinkerL", a = "blinker" },
			Grill = { groesse = { 4.3219, 0.5343, 0.29 }, mitte = { 0, 1.2347, -8.13 }, n = "Kuehlergrill", a = "grill" },
			EckeinlassR = { groesse = { 0.6978, 0.4881, 0.8443 }, mitte = { 2.7721, 1.176, -7.554 }, n = "Lufteinlass", a = "grill" },
			EckeinlassL = { groesse = { 0.6978, 0.4881, 0.8443 }, mitte = { -2.7721, 1.176, -7.554 }, n = "Lufteinlass", a = "grill" },
			Band = { groesse = { 4.4107, 0.1075, 0.1579 }, mitte = { 0, 2.6095, 8.196 }, n = "Ruecklichtband", a = "neon_rot" },
			LichtHR = { groesse = { 0.8804, 0.2624, 0.7245 }, mitte = { 2.6798, 2.5901, 7.8823 }, n = "Ruecklicht", a = "neon_rot" },
			LichtHL = { groesse = { 0.8804, 0.2624, 0.7245 }, mitte = { -2.6798, 2.5901, 7.8823 }, n = "Ruecklicht", a = "neon_rot" },
			BlinkHR = { groesse = { 0.6189, 0.1386, 0.2377 }, mitte = { 2.6021, 2.3589, 8.136 }, n = "BlinkerR", a = "blinker" },
			BlinkHL = { groesse = { 0.6189, 0.1386, 0.2377 }, mitte = { -2.6021, 2.3589, 8.136 }, n = "BlinkerL", a = "blinker" },
			Gitter = { groesse = { 4.4037, 0.4, 0.0999 }, mitte = { 0, 1.95, 8.2251 }, n = "Heckgitter", a = "grill" },
		},
		anbau = {
			{ n = "Frontsplitter", a = "carbon", g = { 6.4, 0.07, 0.5 }, p = { 0, 0.66, -8 }, s = false },
			{ n = "Haubenschlitz", a = "grill", g = { 0.9, 0.03, 1.3 }, p = { 0.95, 2.42, -4.6 }, s = true, r = { -3.58, 0, 0 } },
			{ n = "Spiegel", a = "lack", g = { 0.6, 0.38, 0.75 }, p = { 3.29, 2.7, -0.7 }, s = true },
			{ n = "Spiegelfuss", a = "schwarz", g = { 0.45, 0.12, 0.3 }, p = { 2.95, 2.55, -0.6 }, s = true },
			{ n = "Kieme", a = "schwarz", g = { 0.05, 0.12, 0.85 }, p = { 3.69, 1.95, -3.05 }, s = true, r = { 0, 0, 0 } },
			{ n = "Kieme", a = "schwarz", g = { 0.05, 0.12, 0.85 }, p = { 3.705, 1.93, -2.75 }, s = true, r = { 0, 0, 0 } },
			{ n = "Kieme", a = "schwarz", g = { 0.05, 0.12, 0.85 }, p = { 3.72, 1.91, -2.45 }, s = true, r = { 0, 0, 0 } },
			{ n = "Diffusor", a = "carbon", g = { 5.2, 0.07, 1 }, p = { 0, 1, 7.65 }, s = false },
			{ n = "Auspuff", a = "chrom", g = { 0.45, 0.34, 0.34 }, p = { 0.5, 1.38, 8.345 }, s = true, f = "zyl" },
			{ n = "Auspuff", a = "chrom", g = { 0.45, 0.34, 0.34 }, p = { 1.05, 1.38, 8.345 }, s = true, f = "zyl" },
			{ n = "Fluegel", a = "carbon", g = { 6.8, 0.12, 1.35 }, p = { 0, 4.32, 7.05 }, s = false, r = { -7, 0, 0 } },
			{ n = "Fluegelendplatte", a = "lack", g = { 0.08, 0.85, 1.6 }, p = { 3.42, 4.22, 7.05 }, s = true },
			{ n = "Fluegelstuetze", a = "carbon", g = { 0.12, 1.25, 0.35 }, p = { 1.35, 3.67, 7.25 }, s = true, r = { 12, 0, 0 } },
			{ n = "Diffusorfinne", a = "carbon", g = { 0.06, 0.4, 0.95 }, p = { 0.5, 1.2, 7.65 }, s = true },
			{ n = "Diffusorfinne", a = "carbon", g = { 0.06, 0.4, 0.95 }, p = { 1.5, 1.2, 7.65 }, s = true },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 0.497 }, p = { 3.748, 1.375, -1.35 }, s = true, d = { 0.2272, 0.9738, 0 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 0.501 }, p = { 3.74, 1.825, -1.35 }, s = true, d = { -0.2577, 0.9662, 0 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 0.961 }, p = { 3.27, 2.265, -1.35 }, s = true, d = { -0.8856, 0.4644, 0 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 0.501 }, p = { 3.735, 1.375, 2.55 }, s = true, d = { 0.2577, 0.9662, 0 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 0.488 }, p = { 3.768, 1.825, 2.55 }, s = true, d = { -0.1213, 0.9926, 0 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 0.612 }, p = { 3.548, 2.265, 2.55 }, s = true, d = { -0.667, 0.745, 0 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 1.096 }, p = { 2.25, 2.156, -7.025 }, s = true, d = { 0, 0.146, 0.9893 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 1.54 }, p = { 2.25, 2.296, -5.75 }, s = true, d = { 0, 0.083, 0.9965 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 1.538 }, p = { 2.25, 2.403, -4.25 }, s = true, d = { 0, 0.0599, 0.9982 } },
			{ n = "Fuge", a = "fuge", g = { 0.035, 0.035, 1.637 }, p = { 2.25, 2.488, -2.7 }, s = true, d = { 0, 0.0499, 0.9988 } },
		},
		kollision = {
			{ g = { 7.6, 0.35, 15.5 }, p = { 0, 2.95, 0 } },
			{ g = { 5.6, 1.4, 5 }, p = { 0, 3.9, 1 } },
		},
		kennzeichen = { vorne = { 1.25, -8.305 }, hinten = { 2.05, 8.325 } },
		spoiler = { 4.6703, 6.75, 0.3 },
	},
}
]=====])
server.Parent = SSS

neu("LocalScript", "FuehrerscheinClient", SPS, [=====[
-- Driver's license system (player): dialogs, theory lesson, theory test and driving lesson HUD.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local spieler = Players.LocalPlayer
print("[Driving School] client v29 loaded")
local ordner = RS:WaitForChild("Fuehrerschein")
local aktion = ordner:WaitForChild("Aktion")
local oeffnen = ordner:WaitForChild("Oeffnen")
local fahrEvent = ordner:WaitForChild("Fahrstunde")
local blinkerEvent = ordner:WaitForChild("Blinker")
local Regeln = require(ordner:WaitForChild("Verkehrsregeln"))
local Verkehr = require(ordner:WaitForChild("Verkehr"))

local BLAU = Color3.fromRGB(30, 90, 180)
local GRUEN = Color3.fromRGB(40, 150, 70)
local GRAU = Color3.fromRGB(70, 75, 85)
local ROT = Color3.fromRGB(200, 50, 50)

-- Theory lesson slides
local FOLIEN = {
	{ "Welcome to Driving School!", "Here is how you get your license:\n\n1. Theory lesson (these slides)\n2. Theory test at an exam desk: 20 questions, at least 85 % correct (17 of 20)\n3. Five driving lessons with your instructor\n4. Practical driving test\n\nOnly with a license can you buy and drive your own cars." },
	{ "Basics", "• We drive on the <b>right</b> side of the road.\n• Always wear your <b>seatbelt</b>.\n• No phone in your hand while driving.\n• Never drink and drive.\n• Signal <b>early</b> before turning or changing lanes." },
	{ "Speed Limits", "• Residential areas: <b>30 km/h</b>\n• City: <b>50 km/h</b>\n• Country roads: <b>100 km/h</b>\n• Highway: <b>130 km/h</b>\n\nYour speedometer shows the current limit while driving. In rain or at night, drive slower." },
	{ "Traffic Lights & Signs", "• <b>Red</b>: stop before the white stop line.\n• <b>Yellow</b>: stop if you can do it safely.\n• <b>Green</b>: go, but let pedestrians cross when turning.\n• <b>STOP</b> sign: complete stop, then give way.\n• <b>YIELD</b> sign (red triangle, point down): slow down, let the main road go first.\n• <b>Yellow diamond</b>: you are on the main road and have priority.\n• <b>No signs</b> at a junction: <b>right before left</b> – approach slowly!" },
	{ "Right of Way & Pedestrians", "• When turning left, oncoming traffic goes first.\n• At <b>crosswalks</b>, pedestrians have priority.\n• Emergency vehicles with lights and siren: make way.\n• Children near the road: slow down and be ready to brake.\n• Keep a <b>2-second</b> gap to the car in front." },
	{ "Roundabout, Highway & Parking", "• <b>Roundabout</b>: traffic inside has priority. Signal when leaving.\n• <b>Highway</b>: keep right, overtake on the left, never turn around.\n• Merge by matching the speed of traffic.\n• No parking in front of hydrants or on crosswalks.\n• Use hazard lights if your car breaks down." },
}

-- ---------------------------------------------------------------
-- Dialog window
-- ---------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "LicenseGUI"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.DisplayOrder = 5
gui.Parent = spieler:WaitForChild("PlayerGui")

local rahmen = Instance.new("Frame")
rahmen.AnchorPoint = Vector2.new(0.5, 0.5)
rahmen.Position = UDim2.fromScale(0.5, 0.5)
rahmen.Size = UDim2.fromScale(0.92, 0.85)
rahmen.BackgroundColor3 = Color3.fromRGB(25, 30, 40)
rahmen.Parent = gui
local grenze = Instance.new("UISizeConstraint")
grenze.MaxSize = Vector2.new(620, 470)
grenze.Parent = rahmen
Instance.new("UICorner", rahmen).CornerRadius = UDim.new(0, 12)
local rand = Instance.new("UIPadding")
for _, seite in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do
	rand[seite] = UDim.new(0, 16)
end
rand.Parent = rahmen

local titel = Instance.new("TextLabel")
titel.BackgroundTransparency = 1
titel.Size = UDim2.new(1, -40, 0, 34)
titel.Font = Enum.Font.GothamBlack
titel.TextSize = 22
titel.TextColor3 = Color3.new(1, 1, 1)
titel.TextXAlignment = Enum.TextXAlignment.Left
titel.TextTruncate = Enum.TextTruncate.AtEnd
titel.Parent = rahmen

local zu = Instance.new("TextButton")
zu.Size = UDim2.fromOffset(32, 32)
zu.Position = UDim2.new(1, -32, 0, 0)
zu.Text = "X"
zu.Font = Enum.Font.GothamBold
zu.TextSize = 18
zu.TextColor3 = Color3.new(1, 1, 1)
zu.BackgroundColor3 = ROT
zu.Parent = rahmen
Instance.new("UICorner", zu)

local text = Instance.new("TextLabel")
text.BackgroundTransparency = 1
text.Position = UDim2.fromOffset(0, 44)
text.Size = UDim2.new(1, 0, 1, -44 - 150)
text.Font = Enum.Font.Gotham
text.TextSize = 18
text.TextColor3 = Color3.fromRGB(225, 230, 240)
text.TextWrapped = true
text.RichText = true
text.TextXAlignment = Enum.TextXAlignment.Left
text.TextYAlignment = Enum.TextYAlignment.Top
text.TextScaled = true -- long checklists shrink to fit, never bigger than 18
local textGrenze = Instance.new("UITextSizeConstraint")
textGrenze.MaxTextSize = 18
textGrenze.MinTextSize = 11
textGrenze.Parent = text
text.Parent = rahmen

local knoepfe = Instance.new("Frame")
knoepfe.BackgroundTransparency = 1
knoepfe.Position = UDim2.new(0, 0, 1, -142)
knoepfe.Size = UDim2.new(1, 0, 0, 142)
knoepfe.Parent = rahmen
local liste = Instance.new("UIListLayout")
liste.Padding = UDim.new(0, 6)
liste.VerticalAlignment = Enum.VerticalAlignment.Bottom
liste.SortOrder = Enum.SortOrder.LayoutOrder
liste.Parent = knoepfe

local modus = nil -- what the window currently shows

local function schliessen()
	gui.Enabled = false
	modus = nil
end
zu.MouseButton1Click:Connect(schliessen)

local function zeige(t, inhalt, buttons, neuerModus)
	titel.Text = t
	text.Text = inhalt
	for _, k in knoepfe:GetChildren() do
		if k:IsA("TextButton") then k:Destroy() end
	end
	for i, b in buttons or {} do
		local k = Instance.new("TextButton")
		k.LayoutOrder = i
		k.Size = UDim2.new(1, 0, 0, 40)
		k.BackgroundColor3 = b.farbe or BLAU
		k.Text = b.text
		k.Font = Enum.Font.GothamBold
		k.TextSize = 16
		k.TextWrapped = true
		k.TextColor3 = Color3.new(1, 1, 1)
		k.Parent = knoepfe
		Instance.new("UICorner", k)
		k.MouseButton1Click:Connect(b.klick)
	end
	modus = neuerModus
	gui.Enabled = true
end

local function frage(was, eingabe)
	local ok, r = pcall(function()
		return aktion:InvokeServer(was, eingabe)
	end)
	if not ok or type(r) ~= "table" then
		return { fehler = "Could not reach the server." }
	end
	return r
end

local function hinweis(meldung)
	zeige("Note", meldung, { { text = "Close", farbe = GRAU, klick = schliessen } }, "hinweis")
end

local function fortschritt(r)
	local s = r.status
	local function zeile(erledigt, t)
		return (erledigt and "✅ " or "⬜ ") .. t
	end
	return table.concat({
		zeile(s.angemeldet, "Signed up"),
		zeile(s.unterricht, "Theory lesson"),
		zeile(s.theorie, "Theory test"),
		zeile(s.fahrstunden >= r.anzahlLektionen, ("Driving lessons (%d/%d)"):format(s.fahrstunden, r.anzahlLektionen)),
		zeile(s.fuehrerschein, "Practical driving test"),
		zeile(s.lkwFuehrerschein, "Truck license (optional)"),
	}, "\n")
end

-- ---------------------------------------------------------------
-- Receptionist dialog
-- ---------------------------------------------------------------
local dialog, unterricht, pruefungsplatz, pkwMenue, lkwMenue

function dialog()
	local r = frage("status")
	if r.fehler then hinweis(r.fehler) return end
	local s = r.status
	local name = "Anna – Reception"
	local unten = "\n\n<font size=\"15\" color=\"#9aa4b5\">" .. fortschritt(r) .. "</font>"
	local tschuess = { text = "Bye!", farbe = GRAU, klick = schliessen }

	if r.lektionLaeuft then
		zeige(name, (r.lkwLaeuft and "Your truck test is in progress. The truck is waiting at the Parcel Express depot." or "Your driving lesson is in progress. Your car and instructor are waiting on the parking lot outside.") .. unten, {
			{ text = "Cancel the lesson", farbe = ROT, klick = function()
				frage("fahrstundeAbbrechen")
				schliessen()
			end },
			tschuess,
		}, "dialog")
	elseif s.entzogen and not s.nachschulung then
		zeige(name, ("Oh no... your driver's license was <b>withdrawn</b> because you collected too many penalty points. 😟\n\nTo get it back you need:\n1. the <b>retraining course</b> (%d coins)\n2. a new <b>practical driving test</b>"):format(500) .. unten, {
			{ text = "Book the retraining course (500 coins)", farbe = GRUEN, klick = function()
				local a = frage("nachschulung")
				if a.fehler then hinweis(a.fehler) return end
				local seiten = {
					{ "Retraining course", "Speeding is the most common cause of accidents.\n\n• Always watch the speed limit sign on your speedometer.\n• Speed cameras measure in <b>both directions</b>.\n• Every offence brings <b>penalty points</b>; at <b>8 points</b> the license is gone again." },
					{ "Retraining course", "• Red light = stop. Always.\n• Stop for the police when they signal you.\n• Points expire over time if you drive safely.\n\nNow book your new driving test with Anna!" },
				}
				local i = 1
				local function seite()
					zeige(seiten[i][1], seiten[i][2], { { text = i < #seiten and "Next" or "Finish the course", farbe = GRUEN, klick = function()
						if i < #seiten then i += 1 seite() else dialog() end
					end } }, "unterricht")
				end
				seite()
			end },
			tschuess,
		}, "dialog")
	else
		-- first choose the license class, then Anna lists every step
		zeige(name, "Hi, welcome to the driving school! 😊\nWhich license are you interested in?", {
			{ text = "🚗  Car license (B)", farbe = GRUEN, klick = function() pkwMenue(r) end },
			{ text = "🚛  Truck license (C)", farbe = BLAU, klick = function() lkwMenue(r) end },
			tschuess,
		}, "dialog")
	end
end

-- numbered checklist: { done, text } -> "✅ 1. ..."
local function schritte(liste)
	local zeilen = {}
	local naechsterGefunden = false
	for i, sch in liste do
		local marke
		if sch[1] then
			marke = "✅"
		elseif not naechsterGefunden then
			marke = "👉"
			naechsterGefunden = true
		else
			marke = "⬜"
		end
		table.insert(zeilen, ("%s <b>%d.</b> %s"):format(marke, i, sch[2]))
	end
	return table.concat(zeilen, "\n")
end

function pkwMenue(r)
	local s = r.status
	local name = "Anna – Car license (B)"
	local zurueck = { text = "Back", farbe = GRAU, klick = dialog }
	local liste = "Here is everything you need to do:\n\n" .. schritte({
		{ s.angemeldet, "Sign up here at the reception" },
		{ s.unterricht, "Theory lesson at the <b>whiteboard</b> (classroom)" },
		{ s.theorie, "Theory test at an <b>exam desk</b> (17 of 20 correct)" },
		{ s.fahrstunden >= r.anzahlLektionen, ("Driving lessons with Mike (%d/%d)"):format(math.min(s.fahrstunden, r.anzahlLektionen), r.anzahlLektionen) },
		{ s.fuehrerschein, "Practical driving test (max 3 mistakes)" },
	}) .. "\n\n"
	if not s.angemeldet then
		zeige(name, liste .. "Shall I sign you up?", {
			{ text = "Yes, sign me up!", farbe = GRUEN, klick = function()
				local a = frage("anmelden")
				if a.fehler then hinweis(a.fehler) return end
				local neu = frage("status")
				if not neu.fehler then pkwMenue(neu) end
			end },
			zurueck,
		}, "dialog")
	elseif not s.unterricht then
		zeige(name, liste .. "Next: go into the classroom on the left and press E at the <b>whiteboard</b>.", { zurueck, { text = "Okay!", farbe = GRUEN, klick = schliessen } }, "dialog")
	elseif not s.theorie then
		zeige(name, liste .. "Next: sit down at one of the <b>exam desks</b> in the classroom to start your theory test.", { zurueck, { text = "Okay!", farbe = GRUEN, klick = schliessen } }, "dialog")
	elseif r.naechste then
		zeige(name, liste .. ("Your next lesson: <b>%s</b>\nMike is waiting in the car on the parking lot."):format(r.naechste), {
			{ text = "Start the lesson", farbe = GRUEN, klick = function()
				local a = frage("fahrstundeStarten")
				if a.fehler then
					hinweis(a.fehler)
				else
					zeige(name, a.text, { { text = "Okay!", farbe = GRUEN, klick = schliessen } }, "dialog")
				end
			end },
			zurueck,
		}, "dialog")
	elseif not s.fuehrerschein then
		zeige(name, liste .. "Your examiner Mr. Becker rides in the back, Mike sits next to you. The route is random – hitting a pedestrian counts as 3 mistakes!", {
			{ text = "Start the driving test", farbe = GRUEN, klick = function()
				local a = frage("pruefungStarten")
				if a.fehler then
					hinweis(a.fehler)
				else
					zeige(name, a.text, { { text = "Let's go!", farbe = GRUEN, klick = schliessen } }, "dialog")
				end
			end },
			zurueck,
		}, "dialog")
	else
		zeige(name, liste .. "You have your car license! 🎉 Buy a car at the dealership or earn coins with taxi and pizza jobs.", { zurueck, { text = "Thanks!", farbe = GRUEN, klick = schliessen } }, "dialog")
	end
end

function lkwMenue(r)
	local s = r.status
	local name = "Anna – Truck license (C)"
	local zurueck = { text = "Back", farbe = GRAU, klick = dialog }
	local fahrten = s.lkwFahrten or 0
	local liste = "Here is everything you need to do:\n\n" .. schritte({
		{ s.fuehrerschein, "Car license (B) first" },
		{ s.lkwFuehrerschein, "Truck test at the <b>Parcel Express</b> depot (max 3 mistakes)" },
		{ fahrten >= 15, ("Deliver packages for Tom – class CE / Mega Truck after 15 jobs (%d/15)"):format(math.min(fahrten, 15)) },
	}) .. "\n\n"
	if not s.fuehrerschein then
		zeige(name, liste .. "You need your <b>car license</b> before you can drive trucks.", {
			{ text = "Show the car license steps", farbe = GRUEN, klick = function() pkwMenue(r) end },
			zurueck,
		}, "dialog")
	elseif not s.lkwFuehrerschein then
		zeige(name, liste .. "The truck waits at the Parcel Express depot, south of the neighbourhood.", {
			{ text = "Start the truck test", farbe = GRUEN, klick = function()
				local a = frage("lkwPruefungStarten")
				if a.fehler then
					hinweis(a.fehler)
				else
					zeige(name, a.text, { { text = "Let's go!", farbe = GRUEN, klick = schliessen } }, "dialog")
				end
			end },
			zurueck,
		}, "dialog")
	else
		zeige(name, liste .. "You have the truck license! 🎉 Talk to <b>Tom</b>, the dispatcher at the depot, to earn coins with deliveries.", { zurueck, { text = "Thanks!", farbe = GRUEN, klick = schliessen } }, "dialog")
	end
end

-- ---------------------------------------------------------------
-- Theory lesson at the whiteboard
-- ---------------------------------------------------------------
function unterricht()
	local r = frage("status")
	if r.fehler then hinweis(r.fehler) return end
	if not r.status.angemeldet then
		hinweis("Please sign up at the reception first. Anna is waiting at the front desk.")
		return
	end
	local i = 1
	local function folie()
		local f = FOLIEN[i]
		local buttons = {}
		if i < #FOLIEN then
			table.insert(buttons, { text = ("Next (%d/%d)"):format(i, #FOLIEN), klick = function()
				i += 1
				folie()
			end })
		else
			table.insert(buttons, { text = "Finish the lesson", farbe = GRUEN, klick = function()
				local a = frage("unterrichtFertig")
				if a.fehler then
					hinweis(a.fehler)
				else
					zeige("Lesson complete!", "Well done! Now sit down at one of the <b>exam desks</b> in this room to start your theory test.", {
						{ text = "Close", farbe = GRAU, klick = schliessen },
					}, "hinweis")
				end
			end })
		end
		if i > 1 then
			table.insert(buttons, { text = "Back", farbe = GRAU, klick = function()
				i -= 1
				folie()
			end })
		end
		zeige(f[1], f[2], buttons, "unterricht")
	end
	folie()
end

-- ---------------------------------------------------------------
-- Theory test at an exam desk
-- ---------------------------------------------------------------
local function pruefung()
	local r = frage("pruefungStart")
	if r.fehler then hinweis(r.fehler) return end
	local fragen = r.fragen
	local antworten = {}
	local n = 1
	local function abgeben()
		local e = frage("pruefungAbgeben", antworten)
		if e.fehler then hinweis(e.fehler) return end
		local prozent = math.floor(e.punkte / e.gesamt * 100 + 0.5)
		if e.bestanden then
			zeige("Passed! 🎉", ("You answered <b>%d of %d</b> questions correctly (%d %%).\n\nNext step: book your first driving lesson with Anna at the reception."):format(e.punkte, e.gesamt, prozent), {
				{ text = "Close", farbe = GRUEN, klick = schliessen },
			}, "hinweis")
		else
			zeige("Not passed", ("You answered %d of %d correctly (%d %%).\nYou need at least <b>%d</b>.\n\nReview the lesson at the whiteboard. You can try again in %d seconds."):format(e.punkte, e.gesamt, prozent, e.mindest, e.wartezeit), {
				{ text = "Close", farbe = GRAU, klick = schliessen },
			}, "hinweis")
		end
	end
	local function frageZeigen()
		local f = fragen[n]
		local buttons = {}
		for i, antwort in f.antworten do
			table.insert(buttons, { text = antwort, klick = function()
				if modus ~= "pruefung" then return end
				antworten[n] = i
				n += 1
				if n > #fragen then abgeben() else frageZeigen() end
			end })
		end
		zeige(("Theory test – question %d/%d"):format(n, #fragen), f.frage, buttons, "pruefung")
	end
	frageZeigen()
end

function pruefungsplatz()
	local r = frage("status")
	if r.fehler then hinweis(r.fehler) return end
	local s = r.status
	if s.theorie then
		hinweis("You have already passed the theory test. Talk to Anna at the reception to book a driving lesson.")
	elseif not s.unterricht then
		hinweis("Please attend the theory lesson at the whiteboard first (press E at the whiteboard).")
	else
		zeige("Exam desk", "Ready for your theory test?\n\n• 20 questions\n• at least 17 correct (85 %)\n• if you stand up, the test is cancelled", {
			{ text = "Start the test", farbe = GRUEN, klick = pruefung },
			{ text = "Not yet", farbe = GRAU, klick = schliessen },
		}, "platz")
	end
end

-- ---------------------------------------------------------------
-- Dispatcher at the Parcel Express depot (truck job)
-- ---------------------------------------------------------------
local function starten(name, was, eingabe)
	local a = frage(was, eingabe)
	if a.fehler then
		hinweis(a.fehler)
	else
		zeige(name, a.text, { { text = "Let's go!", farbe = GRUEN, klick = schliessen } }, "dialog")
	end
end

local function laufenderJob(name)
	zeige(name, "You're on a delivery job! Follow the green line on your minimap. At each customer: stop, get out, take the goods from the back of your vehicle and hand them over.", {
		{ text = "Cancel the job", farbe = ROT, klick = function()
			frage("jobAbbrechen")
			schliessen()
		end },
		{ text = "Bye!", farbe = GRAU, klick = schliessen },
	}, "dialog")
end

local function jobDialog()
	local r = frage("status")
	if r.fehler then hinweis(r.fehler) return end
	local s = r.status
	local name = "Tom – Parcel Express"
	local tschuess = { text = "Bye!", farbe = GRAU, klick = schliessen }
	if r.jobLaeuft then
		laufenderJob(name)
	elseif not s.lkwFuehrerschein then
		zeige(name, "Hey! We always need delivery drivers. 🚚\n\nBut you need a <b>truck license (class C)</b> to drive our trucks. " .. (s.fuehrerschein and "Ask Anna at the driving school about the truck test!" or "First get your car license at the driving school, then the truck license."), { tschuess }, "dialog")
	else
		local j = r.jobs
		local zeilen, knoepfe = {}, {}
		local naechste
		for _, st in j.stufen do
			if st.frei then
				table.insert(zeilen, ("✅ <b>%s</b> – %s: %d stops, %d coins each + %d bonus"):format(st.name, st.ware, st.pakete, st.lohn, st.bonus))
				table.insert(knoepfe, 1, { text = ("Drive the %s (%d coins per stop)"):format(st.name, st.lohn), farbe = GRUEN, klick = function() starten(name, "jobStarten", st.nr) end })
			else
				naechste = naechste or st
				table.insert(zeilen, ("🔒 <b>%s</b> – unlocks after %d jobs"):format(st.name, st.ab))
			end
		end
		local fortschritt = naechste and ("\nJobs done: <b>%d</b> – %d more until the %s."):format(j.fahrten, naechste.ab - j.fahrten, naechste.name)
			or ("\nJobs done: <b>%d</b> – you drive our biggest truck! 🏆"):format(j.fahrten)
		zeige(name, "Ready to work? Hand every delivery to the customer yourself.\n\n" .. table.concat(zeilen, "\n") .. "\n" .. fortschritt, knoepfe, "dialog")
	end
end

local function pizzaDialog()
	local r = frage("status")
	if r.fehler then hinweis(r.fehler) return end
	local s = r.status
	local name = "Luigi – Pizza Rapido"
	if r.jobLaeuft then
		laufenderJob(name)
	elseif not s.fuehrerschein then
		zeige(name, "Ciao! 🍕 I need drivers for my pizzas!\n\nBut you need a <b>driver's license (class B)</b> first. Go to the driving school next door!", { { text = "Bye!", farbe = GRAU, klick = schliessen } }, "dialog")
	else
		local p = r.jobs.pizza
		zeige(name, ("Ciao! 🍕 Hot pizzas are waiting!\n\nDeliver <b>%d pizzas</b> to customers in town and in the city.\n• <b>%d coins</b> per pizza\n• <b>%d coins</b> bonus when the car is back\n\nPizzas delivered so far: %d jobs"):format(p.pakete, p.lohn, p.bonus, r.jobs.pizzaFahrten), {
			{ text = "Start delivering", farbe = GRUEN, klick = function() starten(name, "pizzaStarten") end },
			{ text = "Not now", farbe = GRAU, klick = schliessen },
		}, "dialog")
	end
end

local function villaDialog(v)
	local titelName = "🏡 " .. v.name
	if v.gehoert then
		zeige(titelName, "This is <b>your villa</b>! Only you (and other owners) can open the front door. Make yourself at home.", { { text = "Close", farbe = GRAU, klick = schliessen } }, "dialog")
		return
	end
	local besitzer = (#v.besitzer > 0) and ("\n\nCurrent residents on this server: " .. table.concat(v.besitzer, ", ")) or ""
	local knoepfe = {}
	if v.geld >= v.preis then
		table.insert(knoepfe, { text = ("Buy for %d coins"):format(v.preis), farbe = GRUEN, klick = function()
			local a = frage("villaKaufen", v.id)
			if a.fehler then hinweis(a.fehler) else zeige(titelName, a.text, { { text = "Awesome!", farbe = GRUEN, klick = schliessen } }, "dialog") end
		end })
	end
	table.insert(knoepfe, { text = "Not now", farbe = GRAU, klick = schliessen })
	zeige(titelName, ("A modern villa with pool, terrace, open kitchen, living room and bedroom.\n\nPrice: <b>%d coins</b>\nYour coins: <b>%d</b>%s%s"):format(v.preis, v.geld,
		v.geld < v.preis and ("\n\nYou still need %d coins. Earn them with the delivery jobs!"):format(v.preis - v.geld) or "", besitzer), knoepfe, "dialog")
end

-- Car dealership: list of all cars with a buy button each
local autohausGui
local function autohausDialog(info)
	if autohausGui then autohausGui:Destroy() end
	autohausGui = Instance.new("ScreenGui")
	autohausGui.Name = "Autohaus"
	autohausGui.ResetOnSpawn = false
	autohausGui.DisplayOrder = 12
	autohausGui.Parent = spieler.PlayerGui
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(520, 470)
	panel.BackgroundColor3 = Color3.fromRGB(22, 24, 30)
	panel.Parent = autohausGui
	Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 14)
	local skalierung = Instance.new("UISizeConstraint")
	skalierung.MaxSize = Vector2.new(520, 470)
	skalierung.Parent = panel
	local streifen = Instance.new("Frame")
	streifen.Size = UDim2.new(1, 0, 0, 56)
	streifen.BackgroundColor3 = Color3.fromRGB(200, 30, 40)
	streifen.Parent = panel
	Instance.new("UICorner", streifen).CornerRadius = UDim.new(0, 14)
	local titel2 = Instance.new("TextLabel")
	titel2.Position = UDim2.fromOffset(18, 6)
	titel2.Size = UDim2.new(1, -80, 0, 28)
	titel2.BackgroundTransparency = 1
	titel2.Font = Enum.Font.GothamBlack
	titel2.TextSize = 24
	titel2.TextColor3 = Color3.new(1, 1, 1)
	titel2.TextXAlignment = Enum.TextXAlignment.Left
	titel2.Text = "VELOCITY MOTORS"
	titel2.Parent = streifen
	local unter = Instance.new("TextLabel")
	unter.Position = UDim2.fromOffset(18, 32)
	unter.Size = UDim2.new(1, -80, 0, 18)
	unter.BackgroundTransparency = 1
	unter.Font = Enum.Font.GothamMedium
	unter.TextSize = 13
	unter.TextColor3 = Color3.fromRGB(255, 220, 220)
	unter.TextXAlignment = Enum.TextXAlignment.Left
	unter.Text = ("Your coins: %d  ·  You need a driver's license (B) to drive"):format(info.geld)
	unter.Parent = streifen
	local zu4 = Instance.new("TextButton")
	zu4.Position = UDim2.new(1, -44, 0, 13)
	zu4.Size = UDim2.fromOffset(30, 30)
	zu4.BackgroundColor3 = Color3.fromRGB(40, 20, 20)
	zu4.Text = "X"
	zu4.Font = Enum.Font.GothamBold
	zu4.TextSize = 16
	zu4.TextColor3 = Color3.new(1, 1, 1)
	zu4.Parent = streifen
	Instance.new("UICorner", zu4)
	zu4.MouseButton1Click:Connect(function() autohausGui:Destroy() autohausGui = nil end)
	local liste3 = Instance.new("ScrollingFrame")
	liste3.Position = UDim2.fromOffset(14, 66)
	liste3.Size = UDim2.new(1, -28, 1, -80)
	liste3.BackgroundTransparency = 1
	liste3.BorderSizePixel = 0
	liste3.ScrollBarThickness = 6
	liste3.AutomaticCanvasSize = Enum.AutomaticSize.Y
	liste3.CanvasSize = UDim2.new()
	liste3.Parent = panel
	local l3 = Instance.new("UIListLayout")
	l3.Padding = UDim.new(0, 8)
	l3.SortOrder = Enum.SortOrder.LayoutOrder
	l3.Parent = liste3
	for i, a in info.katalog do
		local karte2 = Instance.new("Frame")
		karte2.LayoutOrder = i
		karte2.Size = UDim2.new(1, -10, 0, 62)
		karte2.BackgroundColor3 = info.auswahl == a.typ and Color3.fromRGB(55, 40, 45) or Color3.fromRGB(34, 38, 48)
		karte2.Parent = liste3
		Instance.new("UICorner", karte2)
		local n = Instance.new("TextLabel")
		n.Position = UDim2.fromOffset(12, 6)
		n.Size = UDim2.new(1, -170, 0, 22)
		n.BackgroundTransparency = 1
		n.Font = Enum.Font.GothamBlack
		n.TextSize = 17
		n.TextColor3 = Color3.new(1, 1, 1)
		n.TextXAlignment = Enum.TextXAlignment.Left
		n.Text = ("%s  ·  %s"):format(a.name, a.art)
		n.Parent = karte2
		local d2 = Instance.new("TextLabel")
		d2.Position = UDim2.fromOffset(12, 28)
		d2.Size = UDim2.new(1, -170, 0, 30)
		d2.BackgroundTransparency = 1
		d2.Font = Enum.Font.Gotham
		d2.TextSize = 12
		d2.TextWrapped = true
		d2.TextColor3 = Color3.fromRGB(180, 185, 195)
		d2.TextXAlignment = Enum.TextXAlignment.Left
		d2.TextYAlignment = Enum.TextYAlignment.Top
		d2.Text = ("%d km/h  ·  %s"):format(a.tempo, a.beschreibung or "")
		d2.Parent = karte2
		local k = Instance.new("TextButton")
		k.AnchorPoint = Vector2.new(1, 0.5)
		k.Position = UDim2.new(1, -10, 0.5, 0)
		k.Size = UDim2.fromOffset(140, 38)
		k.Font = Enum.Font.GothamBlack
		k.TextSize = 14
		k.TextColor3 = Color3.new(1, 1, 1)
		k.Parent = karte2
		Instance.new("UICorner", k)
		if a.gehoert then
			k.Text = "OWNED ✓"
			k.BackgroundColor3 = Color3.fromRGB(50, 90, 60)
		elseif a.pass then
			-- exclusive car: comes with a game pass from the shop
			k.Text = "🌙 EXCLUSIVE"
			k.BackgroundColor3 = Color3.fromRGB(110, 60, 200)
			k.MouseButton1Click:Connect(function()
				if autohausGui then autohausGui:Destroy() autohausGui = nil end
				if _G.ShopOeffnen then _G.ShopOeffnen() end
			end)
		else
			local leisten = info.geld >= a.preis
			k.Text = ("🪙 %d"):format(a.preis)
			k.BackgroundColor3 = leisten and GRUEN or GRAU
			k.MouseButton1Click:Connect(function()
				if not leisten then
					hinweis(("You need %d more coins for the %s. Earn them with the delivery jobs!"):format(a.preis - info.geld, a.name))
					return
				end
				local r = frage("autoKaufen", a.typ)
				if autohausGui then autohausGui:Destroy() autohausGui = nil end
				if r.fehler then hinweis(r.fehler) else zeige("🚗 " .. a.name, r.text, { { text = "Awesome!", farbe = GRUEN, klick = schliessen } }, "dialog") end
			end)
		end
	end
end

local function kontrolleDialog(info)
	local name = "👮 Police Officer"
	local anfang = info.grund == "anhalten" and ("Good day. You were driving <b>%d km/h too fast</b>.\nYour driver's license, please."):format(info.zuSchnell or 0)
		or "Good day, this is a routine traffic check.\nYour driver's license, please."
	zeige(name, anfang, {
		{ text = "Show driver's license", farbe = BLAU, klick = function()
			local a = frage("kontrolleAntwort", true)
			if a.fehler then hinweis(a.fehler) return end
			zeige(name, a.text, { { text = "Goodbye!", farbe = (a.strafe or 0) > 0 and ROT or GRUEN, klick = schliessen } }, "hinweis")
		end },
		{ text = "Refuse", farbe = GRAU, klick = function()
			local a = frage("kontrolleAntwort", false)
			if a.fehler then hinweis(a.fehler) return end
			zeige(name, a.text, { { text = "Okay...", farbe = ROT, klick = schliessen } }, "hinweis")
		end },
	}, "kontrolle")
end

oeffnen.OnClientEvent:Connect(function(was, info)
	if was == "job" then
		jobDialog()
	elseif was == "pizza" then
		pizzaDialog()
	elseif was == "villa" then
		villaDialog(info)
	elseif was == "kontrolle" then
		kontrolleDialog(info)
	elseif was == "werkstatt" then
		if _G.WerkstattOeffnen then _G.WerkstattOeffnen() end
	elseif was == "taxi" then
		local r = frage("status")
		if r.fehler then hinweis(r.fehler) return end
		if r.jobLaeuft then
			zeige("🚕 Taxi stand", "You are already on a job. Finish or cancel it first.", { { text = "Okay", farbe = GRAU, klick = schliessen } }, "dialog")
		elseif not r.status.fuehrerschein then
			zeige("🚕 Taxi stand", "You need a valid driver's license (class B) to drive a taxi.", { { text = "Okay", farbe = GRAU, klick = schliessen } }, "dialog")
		else
			zeige("🚕 Taxi stand", "Drive <b>3 passengers</b> from their door to where they want to go.\n\n• The fare depends on the distance\n• Fast and smooth rides get a <b>tip</b>\n• 60 coins bonus when the taxi is back at the stand", {
				{ text = "Start the taxi shift", farbe = GRUEN, klick = function()
					local a = frage("taxiStarten")
					if a.fehler then hinweis(a.fehler) else zeige("🚕 Taxi stand", a.text, { { text = "Let's go!", farbe = GRUEN, klick = schliessen } }, "dialog") end
				end },
				{ text = "Not now", farbe = GRAU, klick = schliessen },
			}, "dialog")
		end
	elseif was == "autohaus" then
		autohausDialog(info)
	elseif was == "dialog" then
		dialog()
	elseif was == "unterricht" then
		unterricht()
	elseif was == "pruefungsplatz" then
		pruefungsplatz()
	elseif was == "aufgestanden" then
		if modus == "pruefung" then
			hinweis("You stood up, so the test was cancelled. Sit down again to restart it.")
		elseif modus == "platz" then
			schliessen()
		end
	end
end)

-- ---------------------------------------------------------------
-- Driving lesson HUD
-- ---------------------------------------------------------------
local hud = Instance.new("ScreenGui")
hud.Name = "LessonHUD"
hud.ResetOnSpawn = false
hud.Enabled = false
hud.IgnoreGuiInset = true -- allows the instruction box to sit right at the top
hud.Parent = spieler.PlayerGui

local anweisung = Instance.new("Frame")
anweisung.AnchorPoint = Vector2.new(0.5, 0)
anweisung.Position = UDim2.new(0.5, 0, 0, 6)
anweisung.Size = UDim2.new(0.7, 0, 0, 58)
anweisung.BackgroundColor3 = Color3.fromRGB(25, 30, 40)
anweisung.BackgroundTransparency = 0.1
anweisung.Parent = hud
local ag = Instance.new("UISizeConstraint")
ag.MaxSize = Vector2.new(470, 58)
ag.Parent = anweisung
Instance.new("UICorner", anweisung).CornerRadius = UDim.new(0, 10)

local lektionTitel = Instance.new("TextLabel")
lektionTitel.BackgroundTransparency = 1
lektionTitel.Position = UDim2.fromOffset(10, 4)
lektionTitel.Size = UDim2.new(1, -20, 0, 14)
lektionTitel.Font = Enum.Font.GothamBold
lektionTitel.TextSize = 11
lektionTitel.TextColor3 = Color3.fromRGB(150, 180, 230)
lektionTitel.TextXAlignment = Enum.TextXAlignment.Left
lektionTitel.Parent = anweisung

local anweisungText = Instance.new("TextLabel")
anweisungText.BackgroundTransparency = 1
anweisungText.Position = UDim2.fromOffset(10, 19)
anweisungText.Size = UDim2.new(1, -20, 1, -22)
anweisungText.Font = Enum.Font.GothamMedium
anweisungText.TextSize = 14
anweisungText.TextWrapped = true
anweisungText.TextColor3 = Color3.new(1, 1, 1)
anweisungText.TextXAlignment = Enum.TextXAlignment.Left
anweisungText.TextYAlignment = Enum.TextYAlignment.Top
anweisungText.Parent = anweisung

local warnText = Instance.new("TextLabel")
warnText.AnchorPoint = Vector2.new(0.5, 0)
warnText.Position = UDim2.new(0.5, 0, 0, 70)
warnText.Size = UDim2.new(0.7, 0, 0, 28)
warnText.BackgroundColor3 = ROT
warnText.Font = Enum.Font.GothamBold
warnText.TextSize = 14
warnText.TextColor3 = Color3.new(1, 1, 1)
warnText.Visible = false
warnText.Parent = hud
Instance.new("UICorner", warnText)
local wg = Instance.new("UISizeConstraint")
wg.MaxSize = Vector2.new(440, 28)
wg.Parent = warnText

local tacho = Instance.new("Frame")
tacho.AnchorPoint = Vector2.new(1, 1)
tacho.Position = UDim2.new(1, -16, 1, -16)
tacho.Size = UDim2.fromOffset(170, 110)
tacho.BackgroundColor3 = Color3.fromRGB(25, 30, 40)
tacho.BackgroundTransparency = 0.1
tacho.Parent = hud
Instance.new("UICorner", tacho).CornerRadius = UDim.new(0, 10)

local tempoText = Instance.new("TextLabel")
tempoText.BackgroundTransparency = 1
tempoText.Position = UDim2.fromOffset(10, 8)
tempoText.Size = UDim2.fromOffset(95, 50)
tempoText.Font = Enum.Font.GothamBlack
tempoText.TextSize = 40
tempoText.TextColor3 = Color3.new(1, 1, 1)
tempoText.Text = "0"
tempoText.Parent = tacho

local einheit = Instance.new("TextLabel")
einheit.BackgroundTransparency = 1
einheit.Position = UDim2.fromOffset(10, 56)
einheit.Size = UDim2.fromOffset(95, 16)
einheit.Font = Enum.Font.Gotham
einheit.TextSize = 13
einheit.TextColor3 = Color3.fromRGB(180, 185, 195)
einheit.Text = "km/h"
einheit.Parent = tacho

local schild = Instance.new("TextLabel")
schild.Position = UDim2.fromOffset(112, 12)
schild.Size = UDim2.fromOffset(48, 48)
schild.BackgroundColor3 = Color3.new(1, 1, 1)
schild.Font = Enum.Font.GothamBlack
schild.TextSize = 18
schild.TextColor3 = Color3.new(0, 0, 0)
schild.Text = "50"
schild.Parent = tacho
Instance.new("UICorner", schild).CornerRadius = UDim.new(1, 0)
local schildRand = Instance.new("UIStroke")
schildRand.Color = ROT
schildRand.Thickness = 5
schildRand.Parent = schild

local fehlerText = Instance.new("TextLabel")
fehlerText.BackgroundTransparency = 1
fehlerText.Position = UDim2.fromOffset(10, 80)
fehlerText.Size = UDim2.new(1, -20, 0, 20)
fehlerText.Font = Enum.Font.GothamBold
fehlerText.TextSize = 14
fehlerText.TextColor3 = Color3.fromRGB(255, 200, 120)
fehlerText.TextXAlignment = Enum.TextXAlignment.Left
fehlerText.Text = "Mistakes: 0"
fehlerText.Parent = tacho

-- Indicator buttons above the speedometer (also work on phones)
local blinkerModus = "aus"
local blinkLeiste = Instance.new("Frame")
blinkLeiste.AnchorPoint = Vector2.new(1, 1)
blinkLeiste.Position = UDim2.new(1, -16, 1, -132)
blinkLeiste.Size = UDim2.fromOffset(170, 36)
blinkLeiste.BackgroundTransparency = 1
blinkLeiste.Parent = hud
local blinkLayout = Instance.new("UIListLayout")
blinkLayout.FillDirection = Enum.FillDirection.Horizontal
blinkLayout.Padding = UDim.new(0, 6)
blinkLayout.Parent = blinkLeiste
local blinkKnoepfe = {}
local function blinkerSetzen(modus)
	if blinkerModus == modus then modus = "aus" end
	blinkerModus = modus
	blinkerEvent:FireServer(modus)
end
for i, b in { { "links", "◀ Y" }, { "warn", "⚠ X" }, { "rechts", "C ▶" } } do
	local k = Instance.new("TextButton")
	k.LayoutOrder = i
	k.Size = UDim2.fromOffset(52, 36)
	k.BackgroundColor3 = Color3.fromRGB(25, 30, 40)
	k.BackgroundTransparency = 0.1
	k.Font = Enum.Font.GothamBold
	k.TextSize = 14
	k.TextColor3 = Color3.new(1, 1, 1)
	k.Text = b[2]
	k.Parent = blinkLeiste
	Instance.new("UICorner", k)
	k.MouseButton1Click:Connect(function() blinkerSetzen(b[1]) end)
	blinkKnoepfe[b[1]] = k
end

-- second row (also for phones): headlights and handbrake
do
	local reihe2 = Instance.new("Frame")
	reihe2.AnchorPoint = Vector2.new(1, 1)
	reihe2.Position = UDim2.new(1, -16, 1, -174)
	reihe2.Size = UDim2.fromOffset(170, 36)
	reihe2.BackgroundTransparency = 1
	reihe2.Parent = hud
	local l2 = Instance.new("UIListLayout")
	l2.FillDirection = Enum.FillDirection.Horizontal
	l2.HorizontalAlignment = Enum.HorizontalAlignment.Right
	l2.Padding = UDim.new(0, 6)
	l2.Parent = reihe2
	local function knopf(text, breite)
		local k = Instance.new("TextButton")
		k.Size = UDim2.fromOffset(breite, 36)
		k.BackgroundColor3 = Color3.fromRGB(25, 30, 40)
		k.BackgroundTransparency = 0.1
		k.Font = Enum.Font.GothamBold
		k.TextSize = 14
		k.TextColor3 = Color3.new(1, 1, 1)
		k.Text = text
		k.Parent = reihe2
		Instance.new("UICorner", k)
		return k
	end
	local licht = knopf("💡 L", 52)
	licht.MouseButton1Click:Connect(function() blinkerEvent:FireServer("licht") end)
	local hb = knopf("Handbrake ⇧", 110)
	hb.InputBegan:Connect(function(e)
		if e.UserInputType == Enum.UserInputType.Touch or e.UserInputType == Enum.UserInputType.MouseButton1 then _G.Handbremse = true end
	end)
	hb.InputEnded:Connect(function(e)
		if e.UserInputType == Enum.UserInputType.Touch or e.UserInputType == Enum.UserInputType.MouseButton1 then _G.Handbremse = false end
	end)
	RunService.RenderStepped:Connect(function()
		hb.BackgroundColor3 = _G.Handbremse and Color3.fromRGB(200, 50, 50) or Color3.fromRGB(25, 30, 40)
	end)
end

-- Markers in the world (only visible to this player): green gates across the road + parking bays
local marker, parkMarker = nil, {}
local hausMarkerWeg
local function markerWeg()
	if marker then marker:Destroy() marker = nil end
	if hausMarkerWeg then hausMarkerWeg() end
	for _, m in parkMarker do m:Destroy() end
	parkMarker = {}
end
local function torTeil(eltern, name, groesse, cf, transparenz)
	local t = Instance.new("Part")
	t.Name = name
	t.Size = groesse
	t.CFrame = cf
	t.Anchored = true
	t.CanCollide = false
	t.CanQuery = false
	t.CanTouch = false
	t.CastShadow = false
	t.Material = Enum.Material.Neon
	t.Color = Color3.fromRGB(60, 255, 120)
	t.Transparency = transparenz
	t.Parent = eltern
	return t
end
local hausMarker = nil
local function markerSetzen(pos, richtung, breite)
	markerWeg()
	richtung = richtung and Vector3.new(richtung.X, 0, richtung.Z) or Vector3.new(0, 0, -1)
	if richtung.Magnitude < 0.1 then richtung = Vector3.new(0, 0, -1) end
	richtung = richtung.Unit
	local hoehe = 9
	local basis = CFrame.lookAt(Vector3.new(pos.X, 0.3, pos.Z), Vector3.new(pos.X, 0.3, pos.Z) + richtung)
	marker = Instance.new("Model")
	marker.Name = "Zieltor"
	for _, seite in { -1, 1 } do
		torTeil(marker, "Pfosten", Vector3.new(0.8, hoehe, 0.8), basis * CFrame.new(seite * breite / 2, hoehe / 2, 0), 0.15)
	end
	torTeil(marker, "Balken", Vector3.new(breite + 0.8, 0.8, 0.8), basis * CFrame.new(0, hoehe, 0), 0.15)
	torTeil(marker, "Vorhang", Vector3.new(breite, hoehe, 0.2), basis * CFrame.new(0, hoehe / 2, 0), 0.8)
	marker.Parent = workspace
end

-- floating package sign above the house you deliver to
function hausMarkerWeg()
	if hausMarker then hausMarker:Destroy() hausMarker = nil end
end
local function hausMarkerSetzen(pos, symbol)
	hausMarkerWeg()
	local anker = Instance.new("Part")
	anker.Name = "Lieferziel"
	anker.Anchored = true
	anker.CanCollide = false
	anker.CanQuery = false
	anker.CanTouch = false
	anker.Transparency = 1
	anker.Size = Vector3.new(1, 1, 1)
	anker.Position = pos + Vector3.new(0, 22, 0)
	anker.Parent = workspace
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(70, 70)
	bb.AlwaysOnTop = true
	bb.Parent = anker
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundColor3 = Color3.fromRGB(230, 120, 30)
	l.Text = symbol or "📦"
	l.TextScaled = true
	l.Font = Enum.Font.GothamBlack
	l.Parent = bb
	Instance.new("UICorner", l).CornerRadius = UDim.new(1, 0)
	local rand = Instance.new("UIStroke")
	rand.Color = Color3.new(1, 1, 1)
	rand.Thickness = 3
	rand.Parent = l
	hausMarker = anker
end

local warnBis = 0
local function warnen(t, farbe)
	warnText.Text = t
	warnText.BackgroundColor3 = farbe or ROT
	warnText.Visible = true
	warnBis = os.clock() + 3.5
end

local fehlerGrenze = nil
local lektionAktiv = false
local function hudAus()
	lektionAktiv = false
	hud.Enabled = false
	blinkerModus = "aus"
	if _G.MinimapRoute then _G.MinimapRoute(nil) end
	markerWeg()
end
fahrEvent.OnClientEvent:Connect(function(info)
	if info.typ == "blinker" then
		blinkerModus = info.modus
	elseif info.typ == "start" then
		blinkerModus = "aus"
		lektionAktiv = true
		hud.Enabled = true
		fehlerGrenze = info.grenze
		lektionTitel.Text = info.titel
		anweisungText.Text = (info.sprecher or "Instructor") .. ": " .. info.text
		fehlerText.Text = info.status or ("Mistakes: 0/%d"):format(fehlerGrenze or 9)
		schliessen()
	elseif info.typ == "ziel" then
		lektionAktiv = true
		hud.Enabled = true
		anweisungText.Text = (info.sprecher or "Instructor") .. ": " .. info.text
		lektionTitel.Text = lektionTitel.Text:gsub("  %(.*%)$", "") .. ("  (%d/%d)"):format(info.nr, info.gesamt)
		if info.status then fehlerText.Text = info.status end
		markerWeg()
		if info.pos then
			markerSetzen(info.pos, info.richtung, info.breite or 26)
		end
		if info.haus then hausMarkerSetzen(info.haus, info.symbol) end
		if _G.MinimapRoute then _G.MinimapRoute(info.route, info.nr) end
		for _, b in info.park or {} do
			local pm = Instance.new("Part")
			pm.Name = "Parkmarker"
			pm.Size = Vector3.new(b.groesse.X - 0.6, 0.2, b.groesse.Z)
			pm.CFrame = b.cf + Vector3.new(0, 0.5, 0)
			pm.Anchored = true
			pm.CanCollide = false
			pm.CanQuery = false
			pm.CanTouch = false
			pm.CastShadow = false
			pm.Material = Enum.Material.Neon
			pm.Color = Color3.fromRGB(60, 160, 255)
			pm.Transparency = 0.6
			pm.Parent = workspace
			table.insert(parkMarker, pm)
		end
	elseif info.typ == "weg" then
		-- show the way to a vehicle on the minimap
		if _G.MinimapRoute then _G.MinimapRoute({ { info.pos.X, info.pos.Z } }, 1) end
	elseif info.typ == "warnung" then
		warnen(info.text)
		fehlerText.Text = ("Mistakes: %d/%d"):format(info.fehler, info.grenze or fehlerGrenze or 9)
	elseif info.typ == "hinweis" then
		warnen(info.text, info.farbe == "gruen" and GRUEN or Color3.fromRGB(200, 140, 30))
	elseif info.typ == "polizei" then
		if _G.PolizeiBanner then _G.PolizeiBanner(info.phase, info.text) end
	elseif info.typ == "blitz" then
		if _G.Blitz then _G.Blitz(info.text) end
	elseif info.typ == "punkte" then
		warnen(("⚠ +%d penalty point%s – now %d/%d"):format(info.plus, info.plus > 1 and "s" or "", info.punkte, info.limit), Color3.fromRGB(200, 120, 20))
	elseif info.typ == "entzug" then
		zeige("⛔ License withdrawn", ("You reached <b>%d penalty points</b>. Your driver's license (and truck license) has been withdrawn.\n\nYou may not drive your own cars or do driving jobs until you get it back:\n1. Retraining course with Anna (%d coins)\n2. New practical driving test"):format(info.limit, info.preis), {
			{ text = "Okay", farbe = ROT, klick = schliessen },
		}, "hinweis")
	elseif info.typ == "mission" then
		warnen("🎯 Daily mission complete: " .. (info.text or ""), GRUEN)
	elseif info.typ == "xp" then
		if _G.XpAnzeigen then _G.XpAnzeigen(info.menge, info.grund, info.level, info.aufstieg) end
	elseif info.typ == "geld" then
		if _G.GeldAnzeigen then _G.GeldAnzeigen(info.betrag, info.grund) end
	elseif info.typ == "bestanden" then
		hudAus()
		if _G.Cutscene then task.spawn(_G.Cutscene, info) end
	elseif info.typ == "jobende" then
		hudAus()
		zeige(info.erfolg and "Job complete! 📦" or "Job ended", info.text .. ("\n\nPackages delivered: <b>%d</b>\nEarned: <b>%d coins</b>"):format(info.geliefert or 0, info.verdient or 0)
			.. (info.erfolg and "\n\nTalk to Tom at the depot for the next job." or ""), {
			{ text = "Close", farbe = info.erfolg and GRUEN or GRAU, klick = schliessen },
		}, "hinweis")
	elseif info.typ == "ende" then
		hudAus()
		local titelText = info.erfolg and ("Lesson %d/%d complete! 🎉"):format(info.nr, info.gesamt) or (info.pruefung and "Driving test failed" or "Lesson ended")
		zeige(titelText, info.text .. ("\n\nMistakes: %d"):format(info.fehler or 0) .. (info.erfolg and "\n\nTalk to Anna at the reception for your next lesson." or ""), {
			{ text = "Close", farbe = info.erfolg and GRUEN or GRAU, klick = schliessen },
		}, "hinweis")
	end
end)

RunService.RenderStepped:Connect(function()
	if warnText.Visible and os.clock() > warnBis then
		warnText.Visible = false
	end
	-- free driving (own car): speedometer and indicator buttons without the instruction box
	if not lektionAktiv then
		local h = spieler.Character and spieler.Character:FindFirstChildOfClass("Humanoid")
		local s2 = h and h.SeatPart
		local faehrt = s2 ~= nil and s2:IsA("VehicleSeat") and s2.Parent ~= nil and s2.Parent:GetAttribute("MaxTempo") ~= nil
		hud.Enabled = faehrt or warnText.Visible
		anweisung.Visible = false
		if faehrt then
			local m2 = s2.Parent
			local tank, zustand = m2:GetAttribute("Tank"), m2:GetAttribute("Zustand")
			if tank then
				fehlerText.Text = ("⛽ %d%%   🔧 %d%%   Pts %d/8"):format(tank, zustand or 100, spieler:GetAttribute("Punkte") or 0)
				fehlerText.TextColor3 = (tank < 15 or (zustand or 100) < 30) and Color3.fromRGB(255, 110, 90) or Color3.fromRGB(255, 200, 120)
			else
				fehlerText.Text = ("Points: %d/8"):format(spieler:GetAttribute("Punkte") or 0)
			end
		end
	else
		anweisung.Visible = true
	end
	if not hud.Enabled then return end
	local char = spieler.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local sitz = hum and hum.SeatPart
	local an = (os.clock() % 0.8) < 0.4
	for modus, k in blinkKnoepfe do
		local aktiv = blinkerModus == "warn" or blinkerModus == modus
		k.BackgroundColor3 = (aktiv and an) and Color3.fromRGB(255, 165, 30) or Color3.fromRGB(25, 30, 40)
	end
	if sitz and sitz:IsA("VehicleSeat") then
		local tempo = math.floor(sitz.AssemblyLinearVelocity.Magnitude + 0.5)
		local limit = Regeln.tempolimit(sitz.Position)
		tempoText.TextColor3 = tempo > limit + 3 and ROT or Color3.new(1, 1, 1)
		if _G.Einstellungen and _G.Einstellungen.mph then
			tempoText.Text = tostring(math.floor(tempo * 0.621 + 0.5))
			schild.Text = tostring(math.floor(limit * 0.621 / 5 + 0.5) * 5)
			einheit.Text = "mph"
		else
			tempoText.Text = tostring(tempo)
			schild.Text = tostring(limit)
			einheit.Text = "km/h"
		end
		tacho.Visible = true
	else
		tacho.Visible = false
	end
end)

-- ---------------------------------------------------------------
-- Car control (runs on the driver's computer = direct, responsive steering)
-- ---------------------------------------------------------------
local fahrVerbindung
local function fahrenStoppen()
	if fahrVerbindung then
		fahrVerbindung:Disconnect()
		fahrVerbindung = nil
	end
end

local function fahrenStarten(sitz, hum)
	fahrenStoppen()
	local modell = sitz.Parent
	local chassis = modell and modell:FindFirstChild("Chassis")
	if not chassis then return end
	local motoren, servos = {}, {}
	for _, h in chassis:GetChildren() do
		if h:IsA("HingeConstraint") then
			if h.ActuatorType == Enum.ActuatorType.Motor then
				table.insert(motoren, h)
			else
				table.insert(servos, h)
			end
		end
	end
	local function wert(name, standard)
		local v = modell:GetAttribute(name)
		if v == nil then return standard end
		return v
	end
	local lenkGlatt = 0

	fahrVerbindung = RunService.Heartbeat:Connect(function(dt)
		if hum.SeatPart ~= sitz or not chassis.Parent then
			fahrenStoppen()
			return
		end
		local radius = wert("Radius", 1.3)
		local maxTempo = wert("MaxTempo", 130)
		local bremse = wert("Bremse", 14000)
		local gas, lenk = sitz.ThrottleFloat, sitz.SteerFloat
		lenkGlatt += (lenk - lenkGlatt) * math.min(1, dt * 14)

		local cf = chassis.CFrame
		local v = chassis.AssemblyLinearVelocity
		local tempo = v:Dot(cf.LookVector) -- forward = positive

		-- engine and brakes
		local ziel, moment = 0, 300
		if gas ~= 0 then
			if tempo * gas < -1.5 then
				ziel, moment = 0, bremse                      -- pressing against the direction = brake
			else
				local grenze = gas > 0 and maxTempo or maxTempo * 0.25
				ziel, moment = gas * grenze / radius, wert("Antrieb", 4500)
			end
		elseif math.abs(tempo) < 1 then
			moment = bremse                                     -- hold the car when standing
		end
		if modell:GetAttribute("Gesperrt") then
			ziel, moment = 0, bremse
		end
		if _G.Handbremse then
			ziel, moment = 0, bremse * 1.5 -- handbrake locks the rear wheels
		end
		for _, mo in motoren do
			mo.AngularVelocity = -ziel * wert("RICHTUNG", 1)
			mo.MotorMaxTorque = moment
		end

		-- steering: less angle at higher speed
		local maxWinkel = wert("Lenkwinkel", 34)
		local winkel = math.clamp(maxWinkel - math.abs(tempo) * 0.18, 8, maxWinkel)
		local einschlag = lenkGlatt * winkel
		for _, se in servos do
			se.TargetAngle = -einschlag -- wheels turn visibly
		end
		-- direct steering: the car turns exactly as fast as a real car with this
		-- steering angle would (speed x tan(angle) / wheelbase), no floaty delay
		local zielDrehung = -tempo * math.tan(math.rad(einschlag)) / wert("Radstand", 9.6)
		local w0 = chassis.AssemblyAngularVelocity
		local neu = w0.Y + (zielDrehung - w0.Y) * math.min(1, wert("Lenkdirekt", 14) * dt)
		chassis.AssemblyAngularVelocity = Vector3.new(w0.X, neu, w0.Z)

		-- grip (no sliding sideways), downforce and roll/pitch damping
		local masse = chassis.AssemblyMass
		local quer = v:Dot(cf.RightVector)
		-- rain makes the road slippery, the handbrake lets the rear slide (drift)
		local griff = wert("Grip", 14) * (ordner:GetAttribute("Wetter") == "Rain" and 0.7 or 1) * (_G.Handbremse and 0.35 or 1)
		chassis:ApplyImpulse(-cf.RightVector * quer * masse * math.min(1, griff * dt))
		chassis:ApplyImpulse(-cf.UpVector * masse * wert("Anpressdruck", 60) * dt)
		local w = chassis.AssemblyAngularVelocity
		local rollen = w:Dot(cf.LookVector)
		local nicken = w:Dot(cf.RightVector)
		chassis:ApplyAngularImpulse((-cf.LookVector * rollen - cf.RightVector * nicken) * masse * 8 * math.min(1, 6 * dt))
	end)
end

local function figurEinrichten(figur)
	local hum = figur:WaitForChild("Humanoid")
	hum.Seated:Connect(function(sitzt, sitz)
		if sitzt and sitz and sitz:IsA("VehicleSeat") and sitz.Parent and sitz.Parent:GetAttribute("MaxTempo") then
			fahrenStarten(sitz, hum)
		else
			fahrenStoppen()
		end
	end)
end
if spieler.Character then task.spawn(figurEinrichten, spieler.Character) end
spieler.CharacterAdded:Connect(figurEinrichten)

-- ---------------------------------------------------------------
-- First person / third person (key V or the button)
-- ---------------------------------------------------------------
local UIS = game:GetService("UserInputService")
local kameraGui = Instance.new("ScreenGui")
kameraGui.Name = "CameraToggle"
kameraGui.ResetOnSpawn = false
kameraGui.Parent = spieler.PlayerGui
-- fold-out menu top left: only the "Menu" button is visible, the other buttons slide out next to it
local klappe = Instance.new("Frame")
klappe.Name = "Klappe"
klappe.BackgroundTransparency = 1
klappe.ClipsDescendants = true
klappe.Position = UDim2.new(0, 12 + 52 + 6, 0, 60)
klappe.Size = UDim2.fromOffset(0, 48)
klappe.Parent = kameraGui
local leiste = Instance.new("Frame")
leiste.Name = "Leiste"
leiste.BackgroundTransparency = 1
leiste.Size = UDim2.fromOffset(0, 48)
leiste.AutomaticSize = Enum.AutomaticSize.X
leiste.Parent = klappe
local leistenLayout = Instance.new("UIListLayout")
leistenLayout.FillDirection = Enum.FillDirection.Horizontal
leistenLayout.Padding = UDim.new(0, 5)
leistenLayout.SortOrder = Enum.SortOrder.LayoutOrder
leistenLayout.Parent = leiste
local function leistenKnopf(icon, text, reihenfolge, farbe)
	local k = Instance.new("TextButton")
	k.Name = text
	k.LayoutOrder = reihenfolge
	k.Size = UDim2.fromOffset(52, 48)
	k.BackgroundColor3 = farbe or Color3.fromRGB(25, 30, 40)
	k.BackgroundTransparency = 0.15
	k.Text = ""
	k.Parent = leiste
	Instance.new("UICorner", k).CornerRadius = UDim.new(0, 10)
	local bild = Instance.new("TextLabel")
	bild.Name = "Icon"
	bild.BackgroundTransparency = 1
	bild.Position = UDim2.fromOffset(0, 3)
	bild.Size = UDim2.new(1, 0, 0, 26)
	bild.Font = Enum.Font.GothamBold
	bild.TextSize = 21
	bild.TextColor3 = Color3.new(1, 1, 1)
	bild.Text = icon
	bild.Parent = k
	local name = Instance.new("TextLabel")
	name.Name = "Beschriftung"
	name.BackgroundTransparency = 1
	name.Position = UDim2.new(0, 0, 1, -17)
	name.Size = UDim2.new(1, 0, 0, 14)
	name.Font = Enum.Font.GothamBold
	name.TextSize = 10
	name.TextColor3 = Color3.fromRGB(225, 230, 240)
	name.Text = text
	name.Parent = k
	return k
end
local menueKnopf = leistenKnopf("☰", "Menu", 0)
menueKnopf.Name = "Menue"
menueKnopf.Position = UDim2.new(0, 12, 0, 60)
menueKnopf.Parent = kameraGui
-- red dot on the menu button while rewards are waiting and the menu is closed
local menuePunkt = Instance.new("TextLabel")
menuePunkt.Name = "Punkt"
menuePunkt.AnchorPoint = Vector2.new(0.5, 0.5)
menuePunkt.Position = UDim2.new(1, -2, 0, 2)
menuePunkt.Size = UDim2.fromOffset(20, 20)
menuePunkt.BackgroundColor3 = Color3.fromRGB(230, 40, 50)
menuePunkt.Font = Enum.Font.GothamBlack
menuePunkt.TextSize = 12
menuePunkt.TextColor3 = Color3.new(1, 1, 1)
menuePunkt.Visible = false
menuePunkt.Parent = menueKnopf
Instance.new("UICorner", menuePunkt).CornerRadius = UDim.new(1, 0)
local menueOffen = false
local function menuePunktNeu()
	local n = spieler:GetAttribute("BelohnungenOffen") or 0
	menuePunkt.Visible = n > 0 and not menueOffen
	menuePunkt.Text = tostring(n)
end
local function menueSetzen(offen)
	menueOffen = offen
	local n = 0
	for _, k in leiste:GetChildren() do
		if k:IsA("TextButton") then n += 1 end
	end
	local breite = offen and (n * 52 + math.max(0, n - 1) * 5) or 0
	game:GetService("TweenService"):Create(klappe, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(breite, 48) }):Play()
	menueKnopf.Icon.Text = offen and "✕" or "☰"
	menueKnopf.Beschriftung.Text = offen and "Close" or "Menu"
	menuePunktNeu()
end
_G.MenueSetzen = menueSetzen
menueKnopf.MouseButton1Click:Connect(function() menueSetzen(not menueOffen) end)
spieler:GetAttributeChangedSignal("BelohnungenOffen"):Connect(menuePunktNeu)
-- after choosing something the menu folds up again (not for the camera button)
leiste.ChildAdded:Connect(function(k)
	if k:IsA("TextButton") and k.Name ~= "1st (V)" then
		k.MouseButton1Click:Connect(function() menueSetzen(false) end)
	end
end)
local kameraKnopf = leistenKnopf("🎥", "1st (V)", 6)

local ersteP = false
local function perspektive(an)
	ersteP = an
	if an then
		spieler.CameraMode = Enum.CameraMode.LockFirstPerson
		kameraKnopf.Beschriftung.Text = "3rd (V)"
	else
		spieler.CameraMode = Enum.CameraMode.Classic
		spieler.CameraMinZoomDistance = 12 -- jump out of first person ...
		task.delay(0.15, function()
			spieler.CameraMinZoomDistance = 0.5 -- ... but still allow zooming in with the mouse wheel
		end)
		kameraKnopf.Beschriftung.Text = "1st (V)"
	end
end
kameraKnopf.MouseButton1Click:Connect(function()
	perspektive(not ersteP)
end)
UIS.InputBegan:Connect(function(eingabe, verarbeitet)
	if verarbeitet then return end
	if eingabe.KeyCode == Enum.KeyCode.V then
		perspektive(not ersteP)
	end
end)

-- ---------------------------------------------------------------
-- Test menu (only visible in Roblox Studio)
-- ---------------------------------------------------------------
if RunService:IsStudio() then
	local devGui = Instance.new("ScreenGui")
	devGui.Name = "TestMenu"
	devGui.ResetOnSpawn = false
	devGui.Parent = spieler.PlayerGui
	local leiste = Instance.new("Frame")
	leiste.AnchorPoint = Vector2.new(0, 0)
	leiste.Position = UDim2.new(0, 12, 0, 140)
	leiste.Size = UDim2.fromOffset(150, 0)
	leiste.AutomaticSize = Enum.AutomaticSize.Y
	leiste.BackgroundColor3 = Color3.fromRGB(60, 20, 20)
	leiste.BackgroundTransparency = 0.15
	leiste.Parent = devGui
	Instance.new("UICorner", leiste)
	local polster = Instance.new("UIPadding")
	for _, seite in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do
		polster[seite] = UDim.new(0, 6)
	end
	polster.Parent = leiste
	local ll = Instance.new("UIListLayout")
	ll.Padding = UDim.new(0, 4)
	ll.SortOrder = Enum.SortOrder.LayoutOrder
	ll.Parent = leiste
	local ueberschrift = Instance.new("TextLabel")
	ueberschrift.Size = UDim2.new(1, 0, 0, 18)
	ueberschrift.BackgroundTransparency = 1
	ueberschrift.Font = Enum.Font.GothamBlack
	ueberschrift.TextSize = 13
	ueberschrift.TextColor3 = Color3.fromRGB(255, 200, 200)
	ueberschrift.Text = "TEST MENU (Studio)"
	ueberschrift.Parent = leiste
	local function devKnopf(reihenfolge, beschriftung, befehl, nr)
		local k = Instance.new("TextButton")
		k.LayoutOrder = reihenfolge
		k.Size = UDim2.new(1, 0, 0, 26)
		k.BackgroundColor3 = Color3.fromRGB(110, 40, 40)
		k.Font = Enum.Font.GothamBold
		k.TextSize = 13
		k.TextColor3 = Color3.new(1, 1, 1)
		k.Text = beschriftung
		k.Parent = leiste
		Instance.new("UICorner", k)
		k.MouseButton1Click:Connect(function()
			local r = frage("dev", { befehl = befehl, nr = nr })
			hinweis(r.fehler or r.text or "Done.")
		end)
	end
	devKnopf(1, "Skip theory", "theorie")
	for nr = 1, 5 do
		devKnopf(1 + nr, "Start lesson " .. nr, "lektion", nr)
	end
	devKnopf(7, "Start driving test", "pruefung")
	devKnopf(8, "Get license (cutscene)", "lizenz")
	devKnopf(9, "Start truck test", "lkw")
	devKnopf(10, "Get truck license", "lkwlizenz")
	devKnopf(11, "+500 coins", "geld")
	devKnopf(12, "Reset progress", "reset")
end

-- Admin money buttons (only visible for the owner of the game; the server checks it again)
do
	local adminGui
	local function adminZeigen()
		if adminGui or not spieler:GetAttribute("Admin") then return end
		adminGui = Instance.new("ScreenGui")
		adminGui.Name = "Admin"
		adminGui.ResetOnSpawn = false
		adminGui.IgnoreGuiInset = true
		adminGui.DisplayOrder = 8
		adminGui.Parent = spieler.PlayerGui
		local leiste2 = Instance.new("Frame")
		leiste2.AnchorPoint = Vector2.new(1, 0)
		leiste2.Position = UDim2.new(1, -16, 0, 122)
		leiste2.Size = UDim2.fromOffset(0, 30)
		leiste2.AutomaticSize = Enum.AutomaticSize.X
		leiste2.BackgroundTransparency = 1
		leiste2.Parent = adminGui
		local reihe2 = Instance.new("UIListLayout")
		reihe2.FillDirection = Enum.FillDirection.Horizontal
		reihe2.HorizontalAlignment = Enum.HorizontalAlignment.Right
		reihe2.Padding = UDim.new(0, 6)
		reihe2.SortOrder = Enum.SortOrder.LayoutOrder
		reihe2.Parent = leiste2
		for i, k in { { "+10K", 10000 }, { "+100K", 100000 }, { "0", -1 } } do
			local b = Instance.new("TextButton")
			b.LayoutOrder = i
			b.Size = UDim2.fromOffset(i == 3 and 34 or 64, 30)
			b.BackgroundColor3 = i == 3 and Color3.fromRGB(120, 40, 40) or Color3.fromRGB(150, 110, 20)
			b.BackgroundTransparency = 0.1
			b.Font = Enum.Font.GothamBlack
			b.TextSize = 13
			b.TextColor3 = Color3.new(1, 1, 1)
			b.Text = i == 3 and "0" or ("💰 " .. k[1])
			b.Parent = leiste2
			Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
			b.MouseButton1Click:Connect(function()
				local r = frage("adminGeld", k[2])
				if r.fehler then hinweis(r.fehler) end
			end)
		end
	end
	adminZeigen()
	spieler:GetAttributeChangedSignal("Admin"):Connect(adminZeigen)
end

-- Handbrake is released when Shift is let go
UIS.InputEnded:Connect(function(eingabe)
	if eingabe.KeyCode == Enum.KeyCode.LeftShift or eingabe.KeyCode == Enum.KeyCode.RightShift then
		_G.Handbremse = false
	end
end)

-- Indicator keys on PC: Y (or Z on US keyboards) = left, C = right, X = hazard lights
UIS.InputBegan:Connect(function(eingabe, verarbeitet)
	if verarbeitet then return end
	local hum = spieler.Character and spieler.Character:FindFirstChildOfClass("Humanoid")
	local sitz = hum and hum.SeatPart
	if not (sitz and sitz:IsA("VehicleSeat") and sitz.Parent and sitz.Parent:GetAttribute("Fahrschulauto")) then return end
	local taste = eingabe.KeyCode
	if taste == Enum.KeyCode.L then
		blinkerEvent:FireServer("licht")
	elseif taste == Enum.KeyCode.LeftShift or taste == Enum.KeyCode.RightShift then
		_G.Handbremse = true
	elseif taste == Enum.KeyCode.Y or taste == Enum.KeyCode.Z then
		blinkerSetzen("links")
	elseif taste == Enum.KeyCode.C then
		blinkerSetzen("rechts")
	elseif taste == Enum.KeyCode.X then
		blinkerSetzen("warn")
	end
end)

-- ---------------------------------------------------------------
-- Minimap (bottom left): a small 3D view from above inside a ViewportFrame.
-- A ViewportFrame always stays inside its own box, so the map can never cover the screen.
-- It turns with you like a navigation system and shows the lesson route.
-- ---------------------------------------------------------------
do
	local GROESSE = 190        -- diameter in pixels
	local SICHT = 300          -- studs visible from top to bottom
	local STUD_METER = 0.28
	local FARBEN = {
		strasse = Color3.fromRGB(62, 66, 74),
		kreis = Color3.fromRGB(62, 66, 74),
		gehweg = Color3.fromRGB(176, 176, 172),
		haus = Color3.fromRGB(222, 212, 192),
		schule = Color3.fromRGB(60, 125, 230),
		insel = Color3.fromRGB(96, 150, 78),
	}
	local HOEHE = { strasse = 0, kreis = 0, gehweg = 0.3, insel = 0.5, haus = 1.5, schule = 2 }

	local mmGui = Instance.new("ScreenGui")
	mmGui.Name = "Minimap"
	mmGui.ResetOnSpawn = false
	mmGui.Parent = spieler.PlayerGui
	_G.MinimapGui = mmGui

	local halter = Instance.new("Frame")
	halter.AnchorPoint = Vector2.new(0, 1)
	halter.Position = UDim2.new(0, 14, 1, -14)
	halter.Size = UDim2.fromOffset(GROESSE, GROESSE + 22)
	halter.BackgroundTransparency = 1
	halter.Parent = mmGui

	local schatten = Instance.new("Frame")
	schatten.Position = UDim2.fromOffset(3, 4)
	schatten.Size = UDim2.fromOffset(GROESSE, GROESSE)
	schatten.BackgroundColor3 = Color3.new(0, 0, 0)
	schatten.BackgroundTransparency = 0.6
	schatten.Parent = halter
	Instance.new("UICorner", schatten).CornerRadius = UDim.new(1, 0)

	local rund = Instance.new("CanvasGroup") -- makes the corners round
	rund.Size = UDim2.fromOffset(GROESSE, GROESSE)
	rund.BackgroundTransparency = 1
	rund.Parent = halter
	Instance.new("UICorner", rund).CornerRadius = UDim.new(1, 0)

	local vf = Instance.new("ViewportFrame")
	vf.Size = UDim2.fromScale(1, 1)
	vf.BackgroundColor3 = Color3.fromRGB(104, 148, 80)
	vf.Ambient = Color3.fromRGB(190, 190, 190)
	vf.LightColor = Color3.fromRGB(255, 255, 255)
	vf.LightDirection = Vector3.new(-0.3, -1, -0.2)
	vf.Parent = rund
	Instance.new("UICorner", vf).CornerRadius = UDim.new(1, 0)
	local kamera = Instance.new("Camera")
	kamera.FieldOfView = 30
	kamera.Parent = vf
	vf.CurrentCamera = kamera
	local hoehe = (SICHT / 2) / math.tan(math.rad(kamera.FieldOfView / 2))

	local ring = Instance.new("Frame")
	ring.Size = UDim2.fromOffset(GROESSE, GROESSE)
	ring.BackgroundTransparency = 1
	ring.ZIndex = 20
	ring.Parent = halter
	Instance.new("UICorner", ring).CornerRadius = UDim.new(1, 0)
	local ringLinie = Instance.new("UIStroke")
	ringLinie.Color = Color3.fromRGB(28, 32, 42)
	ringLinie.Thickness = 4
	ringLinie.Parent = ring

	local function kartenTeil(groesse, cf, farbe, form)
		local t = Instance.new("Part")
		t.Anchored = true
		t.Size = groesse
		t.CFrame = cf
		t.Color = farbe
		t.Material = Enum.Material.SmoothPlastic
		if form then t.Shape = form end
		t.Parent = vf
		return t
	end

	task.spawn(function()
		local r = frage("kartendaten")
		if not r.daten then return end
		for _, e in r.daten do
			local typ, x, z, sx, sz = e[1], e[2], e[3], e[4], e[5]
			local h = HOEHE[typ] or 0
			if typ == "kreis" or typ == "insel" then
				kartenTeil(Vector3.new(0.5, sx, sx), CFrame.new(x, h, z) * CFrame.Angles(0, 0, math.rad(90)), FARBEN[typ], Enum.PartType.Cylinder)
			else
				kartenTeil(Vector3.new(sx, 0.5 + h, sz), CFrame.new(x, (0.5 + h) / 2, z), FARBEN[typ] or FARBEN.strasse)
			end
		end
	end)

	local routenOrdner = Instance.new("Folder")
	routenOrdner.Parent = vf
	local function balken(x1, z1, x2, z2, dicke, farbe, y)
		local a, b = Vector3.new(x1, y, z1), Vector3.new(x2, y, z2)
		local laenge = (b - a).Magnitude
		if laenge < 0.1 then return end
		local t = kartenTeil(Vector3.new(dicke, 0.4, laenge + dicke), CFrame.lookAt((a + b) / 2, b), farbe)
		t.Parent = routenOrdner
		return t
	end

	local route, routeNr = nil, 1
	local zuMir
	_G.MinimapRoute = function(neueRoute, nr)
		routenOrdner:ClearAllChildren()
		zuMir = nil
		route, routeNr = neueRoute, nr or 1
		if not route then return end
		for i = math.max(routeNr, 1), #route - 1 do
			balken(route[i][1], route[i][2], route[i + 1][1], route[i + 1][2], 7, Color3.fromRGB(40, 150, 255), 4)
		end
		local ziel = route[routeNr]
		if ziel then
			local punkt = kartenTeil(Vector3.new(0.5, 14, 14), CFrame.new(ziel[1], 5, ziel[2]) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(60, 255, 120), Enum.PartType.Cylinder)
			punkt.Parent = routenOrdner
		end
	end

	-- player arrow in the middle (always points up, the map turns underneath)
	local pfeil = Instance.new("TextLabel")
	pfeil.AnchorPoint = Vector2.new(0.5, 0.5)
	pfeil.Position = UDim2.fromScale(0.5, 0.5)
	pfeil.Size = UDim2.fromOffset(22, 22)
	pfeil.BackgroundTransparency = 1
	pfeil.Text = "▲"
	pfeil.TextScaled = true
	pfeil.Font = Enum.Font.GothamBlack
	pfeil.TextColor3 = Color3.fromRGB(255, 215, 50)
	pfeil.TextStrokeColor3 = Color3.fromRGB(30, 30, 30)
	pfeil.TextStrokeTransparency = 0
	pfeil.ZIndex = 15
	pfeil.Parent = halter
	pfeil.Position = UDim2.fromOffset(GROESSE / 2, GROESSE / 2)

	local nord = Instance.new("TextLabel")
	nord.AnchorPoint = Vector2.new(0.5, 0.5)
	nord.Size = UDim2.fromOffset(18, 18)
	nord.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
	nord.Text = "N"
	nord.Font = Enum.Font.GothamBlack
	nord.TextSize = 11
	nord.TextColor3 = Color3.new(1, 1, 1)
	nord.ZIndex = 21
	nord.Parent = halter
	Instance.new("UICorner", nord).CornerRadius = UDim.new(1, 0)

	local abstandText = Instance.new("TextLabel")
	abstandText.Position = UDim2.fromOffset(0, GROESSE + 4)
	abstandText.Size = UDim2.fromOffset(GROESSE, 18)
	abstandText.BackgroundTransparency = 1
	abstandText.Font = Enum.Font.GothamBold
	abstandText.TextSize = 13
	abstandText.TextColor3 = Color3.new(1, 1, 1)
	abstandText.TextStrokeTransparency = 0.4
	abstandText.Text = ""
	abstandText.Parent = halter

	local naechsteKarte = 0
	RunService.RenderStepped:Connect(function()
		if not mmGui.Enabled then return end
		-- the minimap is a 3D view of its own: redraw it at most 30 times a second (12 in performance mode)
		local jetzt = os.clock()
		if jetzt < naechsteKarte then return end
		naechsteKarte = jetzt + (_G.Sparmodus and 1 / 12 or 1 / 30)
		local char = spieler.Character
		local wurzel = char and char:FindFirstChild("HumanoidRootPart")
		if not wurzel then return end
		local hum = char:FindFirstChildOfClass("Humanoid")
		local bezug = (hum and hum.SeatPart) or wurzel
		local pos = bezug.Position
		local blick = bezug.CFrame.LookVector
		local vorne = Vector3.new(blick.X, 0, blick.Z)
		if vorne.Magnitude < 0.01 then vorne = Vector3.new(0, 0, -1) end
		vorne = vorne.Unit
		local boden = Vector3.new(pos.X, 0, pos.Z)
		-- camera above the player, "up" on the screen = driving direction
		kamera.CFrame = CFrame.lookAt(boden + Vector3.new(0, hoehe, 0), boden, vorne)
		local richtung = math.atan2(vorne.X, -vorne.Z)
		local r = GROESSE / 2 - 11
		nord.Position = UDim2.fromOffset(GROESSE / 2 + math.sin(-richtung) * r, GROESSE / 2 - math.cos(-richtung) * r)

		if route and route[routeNr] then
			local zx, zz = route[routeNr][1], route[routeNr][2]
			local a, b = Vector3.new(pos.X, 4.5, pos.Z), Vector3.new(zx, 4.5, zz)
			local laenge = (b - a).Magnitude
			if laenge > 0.5 then
				if not zuMir or not zuMir.Parent then
					zuMir = balken(pos.X, pos.Z, zx, zz, 4, Color3.fromRGB(60, 255, 120), 4.5)
				else
					zuMir.Size = Vector3.new(4, 0.4, laenge + 4)
					zuMir.CFrame = CFrame.lookAt((a + b) / 2, b)
				end
			end
			local meter = math.floor(math.sqrt((zx - pos.X) ^ 2 + (zz - pos.Z) ^ 2) * STUD_METER / 5 + 0.5) * 5
			abstandText.Text = ("Next: %d m"):format(meter)
		else
			abstandText.Text = ""
		end
	end)
end

-- ---------------------------------------------------------------
-- Driver's license card (shown in the cutscene and when you hold the item)
-- ---------------------------------------------------------------
local TweenService = game:GetService("TweenService")

local function fuehrerscheinKarte(eltern, info)
	local karte = Instance.new("Frame")
	karte.Name = "Fuehrerschein"
	karte.AnchorPoint = Vector2.new(0.5, 0.5)
	karte.Position = UDim2.fromScale(0.5, 0.5)
	karte.Size = UDim2.fromOffset(440, 340)
	karte.BackgroundColor3 = Color3.new(1, 1, 1)
	karte.Parent = eltern
	Instance.new("UICorner", karte).CornerRadius = UDim.new(0, 16)
	local verlauf = Instance.new("UIGradient")
	verlauf.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(246, 210, 222)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(236, 228, 245)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 225, 245)),
	})
	verlauf.Rotation = 25
	verlauf.Parent = karte
	local rand = Instance.new("UIStroke")
	rand.Color = Color3.fromRGB(170, 140, 170)
	rand.Thickness = 2
	rand.Parent = karte
	local skala = Instance.new("UIScale")
	skala.Parent = karte

	local function text(t, x, y, b, h, groesse, schrift, farbe, rechts)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromOffset(x, y)
		l.Size = UDim2.fromOffset(b, h)
		l.Text = t
		l.TextSize = groesse
		l.Font = schrift or Enum.Font.GothamBold
		l.TextColor3 = farbe or Color3.fromRGB(45, 40, 70)
		l.TextXAlignment = rechts and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left
		l.TextTruncate = Enum.TextTruncate.AtEnd
		l.Parent = karte
		return l
	end
	-- header band
	local band = Instance.new("Frame")
	band.Size = UDim2.new(1, 0, 0, 46)
	band.BackgroundColor3 = Color3.fromRGB(40, 70, 150)
	band.Parent = karte
	Instance.new("UICorner", band).CornerRadius = UDim.new(0, 16)
	local bandUnten = Instance.new("Frame")
	bandUnten.Position = UDim2.new(0, 0, 1, -16)
	bandUnten.Size = UDim2.new(1, 0, 0, 16)
	bandUnten.BackgroundColor3 = band.BackgroundColor3
	bandUnten.BorderSizePixel = 0
	bandUnten.Parent = band
	text("DRIVER'S LICENSE", 18, 6, 300, 22, 20, Enum.Font.GothamBlack, Color3.new(1, 1, 1)).ZIndex = 2
	text("DRIVING SCHOOL", 18, 26, 300, 14, 11, Enum.Font.GothamBold, Color3.fromRGB(200, 215, 255)).ZIndex = 2
	local klassenText = (info.klassen or "B"):gsub(" ", " · ")
	local klasse = text(klassenText, 260, 6, 164, 36, 30, Enum.Font.GothamBlack, Color3.fromRGB(255, 215, 80), true)
	klasse.ZIndex = 2

	-- photo of the player's avatar
	local foto = Instance.new("ImageLabel")
	foto.Position = UDim2.fromOffset(18, 62)
	foto.Size = UDim2.fromOffset(120, 150)
	foto.BackgroundColor3 = Color3.fromRGB(210, 220, 235)
	foto.ScaleType = Enum.ScaleType.Crop
	foto.Parent = karte
	Instance.new("UICorner", foto).CornerRadius = UDim.new(0, 8)
	task.spawn(function()
		local ok, bild = pcall(function()
			return Players:GetUserThumbnailAsync(info.userId or spieler.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size180x180)
		end)
		if ok and foto.Parent then foto.Image = bild end
	end)

	local y = 62
	for _, zeile in {
		{ "1. NAME", info.name or spieler.DisplayName },
		{ "2. USER", "@" .. (info.benutzer or spieler.Name) },
		{ "3. ISSUED", info.datum or "-" },
		{ "4. LICENSE NO.", info.nummer or "-" },
	} do
		text(zeile[1], 156, y, 260, 13, 11, Enum.Font.GothamBold, Color3.fromRGB(120, 100, 140))
		text(zeile[2], 156, y + 13, 270, 20, 17, Enum.Font.GothamBold)
		y += 37
	end
	text(info.name or spieler.DisplayName, 156, 214, 260, 34, 26, Enum.Font.IndieFlower, Color3.fromRGB(30, 50, 120)) -- signature
	local linie = Instance.new("Frame")
	linie.Position = UDim2.fromOffset(156, 246)
	linie.Size = UDim2.fromOffset(240, 1)
	linie.BackgroundColor3 = Color3.fromRGB(150, 130, 160)
	linie.BorderSizePixel = 0
	linie.Parent = karte
	text("Signature", 18, 222, 120, 14, 11, Enum.Font.Gotham, Color3.fromRGB(120, 100, 140))

	-- 9. license classes: which licenses you have and how many
	local KLASSEN = {
		{ "B", "🚗", "Car", info.datum },
		{ "C", "🚚", "Truck", info.lkwDatum },
	}
	local besitzt = 0
	for _, k in KLASSEN do
		if (info.klassen or "B"):find(k[1], 1, true) then besitzt += 1 end
	end
	text(("9. LICENSE CLASSES  –  %d of %d"):format(besitzt, #KLASSEN), 18, 262, 400, 14, 11, Enum.Font.GothamBold, Color3.fromRGB(120, 100, 140))
	for i, k in KLASSEN do
		local hat = (info.klassen or "B"):find(k[1], 1, true) ~= nil
		local feld = Instance.new("Frame")
		feld.Position = UDim2.fromOffset(18 + (i - 1) * 206, 280)
		feld.Size = UDim2.fromOffset(198, 44)
		feld.BackgroundColor3 = hat and Color3.fromRGB(40, 70, 150) or Color3.fromRGB(215, 210, 222)
		feld.Parent = karte
		Instance.new("UICorner", feld).CornerRadius = UDim.new(0, 8)
		local function zeile(t, x, y, b, h, groesse, schrift, farbe)
			local l = Instance.new("TextLabel")
			l.BackgroundTransparency = 1
			l.Position = UDim2.fromOffset(x, y)
			l.Size = UDim2.fromOffset(b, h)
			l.Text = t
			l.TextSize = groesse
			l.Font = schrift
			l.TextColor3 = farbe
			l.TextXAlignment = Enum.TextXAlignment.Left
			l.Parent = feld
		end
		local hell = hat and Color3.new(1, 1, 1) or Color3.fromRGB(150, 140, 160)
		zeile(k[2], 8, 6, 32, 32, 24, Enum.Font.GothamBold, hell)
		zeile(k[1], 44, 4, 30, 36, 28, Enum.Font.GothamBlack, hat and Color3.fromRGB(255, 215, 80) or hell)
		zeile(k[3], 80, 5, 110, 18, 15, Enum.Font.GothamBold, hell)
		zeile(hat and ("since " .. ((k[4] and k[4] ~= "") and k[4] or "-")) or "not yet", 80, 23, 110, 16, 12, Enum.Font.Gotham, hell)
	end
	-- shiny hologram
	local holo = Instance.new("Frame")
	holo.Position = UDim2.fromOffset(380, 210)
	holo.Size = UDim2.fromOffset(42, 42)
	holo.BackgroundColor3 = Color3.new(1, 1, 1)
	holo.Parent = karte
	Instance.new("UICorner", holo).CornerRadius = UDim.new(1, 0)
	local hv = Instance.new("UIGradient")
	hv.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 180, 220)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(180, 240, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 240, 170)),
	})
	hv.Parent = holo
	task.spawn(function()
		while holo.Parent do
			hv.Rotation = (hv.Rotation + 3) % 360
			task.wait(0.03)
		end
	end)
	return karte, skala
end

-- Holding the license item in your hand shows the card
do
	local ansicht = Instance.new("ScreenGui")
	ansicht.Name = "LizenzAnsicht"
	ansicht.ResetOnSpawn = false
	ansicht.Enabled = false
	ansicht.DisplayOrder = 20
	ansicht.Parent = spieler.PlayerGui
	local aktuelleKarte
	local verbunden = {}
	local function verbinden(tool)
		if verbunden[tool] or not tool:IsA("Tool") or not tool:GetAttribute("Fuehrerschein") then return end
		verbunden[tool] = true
		tool.Equipped:Connect(function()
			if aktuelleKarte then aktuelleKarte:Destroy() end
			local karte, skala = fuehrerscheinKarte(ansicht, {
				name = tool:GetAttribute("Name"), benutzer = tool:GetAttribute("Benutzer"),
				datum = tool:GetAttribute("Datum"), nummer = tool:GetAttribute("Nummer"), userId = spieler.UserId,
				klassen = tool:GetAttribute("Klassen"), lkwDatum = tool:GetAttribute("LkwDatum"),
			})
			karte.Position = UDim2.new(0.5, 0, 1, -190)
			skala.Scale = 0.2
			aktuelleKarte = karte
			ansicht.Enabled = true
			TweenService:Create(skala, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 0.85 }):Play()
		end)
		tool.Unequipped:Connect(function()
			ansicht.Enabled = false
			if aktuelleKarte then aktuelleKarte:Destroy() aktuelleKarte = nil end
		end)
	end
	local function beobachten(behaelter)
		for _, t in behaelter:GetChildren() do verbinden(t) end
		behaelter.ChildAdded:Connect(verbinden)
	end
	beobachten(spieler:WaitForChild("Backpack"))
	spieler.CharacterAdded:Connect(function(figur)
		beobachten(figur)
		task.defer(function() beobachten(spieler:WaitForChild("Backpack")) end)
	end)
	if spieler.Character then beobachten(spieler.Character) end
end

-- ---------------------------------------------------------------
-- Cutscene after passing the driving test
-- ---------------------------------------------------------------
_G.Cutscene = function(info)
	local kamera = workspace.CurrentCamera
	local char = spieler.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local sitz = hum and hum.SeatPart
	local fokus = (sitz and sitz.Parent and sitz.Parent:FindFirstChild("Chassis")) or (char and char:FindFirstChild("HumanoidRootPart"))
	if not fokus then return end
	local fokusCF = fokus.CFrame

	local cg = Instance.new("ScreenGui")
	cg.Name = "Cutscene"
	cg.IgnoreGuiInset = true
	cg.DisplayOrder = 50
	cg.ResetOnSpawn = false
	cg.Parent = spieler.PlayerGui
	-- cinematic black bars
	local balken = {}
	for _, oben in { true, false } do
		local b = Instance.new("Frame")
		b.AnchorPoint = Vector2.new(0, oben and 0 or 1)
		b.Position = UDim2.fromScale(0, oben and 0 or 1)
		b.Size = UDim2.new(1, 0, 0, 0)
		b.BackgroundColor3 = Color3.new(0, 0, 0)
		b.BorderSizePixel = 0
		b.Parent = cg
		table.insert(balken, b)
		TweenService:Create(b, TweenInfo.new(0.8), { Size = UDim2.new(1, 0, 0.12, 0) }):Play()
	end
	local untertitel = Instance.new("TextLabel")
	untertitel.AnchorPoint = Vector2.new(0.5, 1)
	untertitel.Position = UDim2.new(0.5, 0, 0.86, 0)
	untertitel.Size = UDim2.new(0.8, 0, 0, 40)
	untertitel.BackgroundTransparency = 1
	untertitel.Font = Enum.Font.GothamBold
	untertitel.TextSize = 22
	untertitel.TextColor3 = Color3.new(1, 1, 1)
	untertitel.TextStrokeTransparency = 0.3
	untertitel.Text = info.lkw and "Mr. Becker (Examiner): Congratulations, you passed your truck driving test!" or "Mr. Becker (Examiner): Congratulations, you passed your driving test!"
	untertitel.Parent = cg
	local schwarz = Instance.new("Frame")
	schwarz.Size = UDim2.fromScale(1, 1)
	schwarz.BackgroundColor3 = Color3.new(0, 0, 0)
	schwarz.BackgroundTransparency = 1
	schwarz.ZIndex = 5
	schwarz.Parent = cg

	-- camera slowly circles the car
	kamera.CameraType = Enum.CameraType.Scriptable
	local start = os.clock()
	local dauer = 6.5
	local fahrt = RunService.RenderStepped:Connect(function()
		local t = math.min((os.clock() - start) / dauer, 1)
		local winkel = math.rad(-35 + 110 * t)
		local ziel = fokusCF.Position + Vector3.new(0, 2.5, 0)
		local weit = info.lkw and 1.7 or 1
		local auge = (fokusCF * CFrame.Angles(0, winkel, 0) * CFrame.new(0, (3.5 - t) * weit, (-15 + 3 * t) * weit)).Position
		kamera.CFrame = CFrame.lookAt(auge, ziel)
	end)
	task.wait(3.2)
	untertitel.Text = info.lkw and "Mike (Instructor): Your license now also shows class C. Go and earn some coins!" or "Mike (Instructor): Great job! Here is your driver's license."
	task.wait(3.3)
	fahrt:Disconnect()
	TweenService:Create(schwarz, TweenInfo.new(0.6), { BackgroundTransparency = 0.25 }):Play()
	untertitel.Text = ""
	task.wait(0.6)

	-- the license card flies in
	local karte, skala = fuehrerscheinKarte(cg, info)
	karte.ZIndex = 10
	for _, k in karte:GetDescendants() do
		if k:IsA("GuiObject") then k.ZIndex = 10 end
	end
	skala.Scale = 0.1
	karte.Rotation = -25
	TweenService:Create(skala, TweenInfo.new(0.7, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(karte, TweenInfo.new(0.7, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Rotation = 0 }):Play()
	local glueck = Instance.new("TextLabel")
	glueck.AnchorPoint = Vector2.new(0.5, 1)
	glueck.Position = UDim2.new(0.5, 0, 0.5, -185)
	glueck.Size = UDim2.new(0.9, 0, 0, 50)
	glueck.BackgroundTransparency = 1
	glueck.Font = Enum.Font.GothamBlack
	glueck.TextSize = 40
	glueck.TextColor3 = Color3.fromRGB(255, 215, 80)
	glueck.TextStrokeTransparency = 0.2
	glueck.Text = "CONGRATULATIONS!"
	glueck.ZIndex = 11
	glueck.Parent = cg
	local hinweisText = Instance.new("TextLabel")
	hinweisText.AnchorPoint = Vector2.new(0.5, 0)
	hinweisText.Position = UDim2.new(0.5, 0, 0.5, 182)
	hinweisText.Size = UDim2.new(0.9, 0, 0, 24)
	hinweisText.BackgroundTransparency = 1
	hinweisText.Font = Enum.Font.GothamBold
	hinweisText.TextSize = 18
	hinweisText.TextColor3 = Color3.new(1, 1, 1)
	hinweisText.Text = info.lkw and "Class C added! Find work at the Parcel Express depot." or "Your driver's license has been added to your inventory."
	hinweisText.ZIndex = 11
	hinweisText.Parent = cg
	-- confetti
	local farben = { Color3.fromRGB(255, 90, 90), Color3.fromRGB(90, 200, 255), Color3.fromRGB(255, 220, 80), Color3.fromRGB(120, 230, 120), Color3.fromRGB(220, 130, 255) }
	for i = 1, 60 do
		local c = Instance.new("Frame")
		c.Size = UDim2.fromOffset(math.random(6, 12), math.random(10, 18))
		c.Position = UDim2.new(math.random(), 0, -0.05, 0)
		c.Rotation = math.random(0, 360)
		c.BackgroundColor3 = farben[math.random(#farben)]
		c.BorderSizePixel = 0
		c.ZIndex = 12
		c.Parent = cg
		TweenService:Create(c, TweenInfo.new(math.random(25, 45) / 10, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(c.Position.X.Scale + (math.random() - 0.5) * 0.2, 0, 1.1, 0),
			Rotation = c.Rotation + math.random(-360, 360),
		}):Play()
	end

	local knopf = Instance.new("TextButton")
	knopf.AnchorPoint = Vector2.new(0.5, 0)
	knopf.Position = UDim2.new(0.5, 0, 0.5, 214)
	knopf.Size = UDim2.fromOffset(200, 44)
	knopf.BackgroundColor3 = GRUEN
	knopf.Font = Enum.Font.GothamBlack
	knopf.TextSize = 20
	knopf.TextColor3 = Color3.new(1, 1, 1)
	knopf.Text = "Awesome!"
	knopf.ZIndex = 13
	knopf.Parent = cg
	Instance.new("UICorner", knopf)
	local fertig = false
	knopf.MouseButton1Click:Connect(function() fertig = true end)
	local t0 = os.clock()
	while not fertig and os.clock() - t0 < 20 do task.wait(0.1) end

	kamera.CameraType = Enum.CameraType.Custom
	if hum then kamera.CameraSubject = hum end
	TweenService:Create(schwarz, TweenInfo.new(0.4), { BackgroundTransparency = 0 }):Play()
	task.wait(0.4)
	cg:Destroy()
end

-- ---------------------------------------------------------------
-- Money: "Drive Coins" – small display top right with the coin logo (a golden steering wheel)
-- ---------------------------------------------------------------
do
	local geldGui = Instance.new("ScreenGui")
	geldGui.Name = "Geld"
	geldGui.ResetOnSpawn = false
	geldGui.IgnoreGuiInset = true
	geldGui.DisplayOrder = 8
	geldGui.Parent = spieler.PlayerGui

	local pille = Instance.new("Frame")
	pille.AnchorPoint = Vector2.new(1, 0)
	pille.Position = UDim2.new(1, -16, 0, 12)
	pille.Size = UDim2.fromOffset(0, 38)
	pille.AutomaticSize = Enum.AutomaticSize.X
	pille.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
	pille.BackgroundTransparency = 0.25
	pille.Parent = geldGui
	Instance.new("UICorner", pille).CornerRadius = UDim.new(1, 0)
	local pillenRand = Instance.new("UIStroke")
	pillenRand.Color = Color3.fromRGB(255, 205, 70)
	pillenRand.Transparency = 0.7
	pillenRand.Thickness = 1.5
	pillenRand.Parent = pille
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 5), UDim.new(0, 14)
	pad.Parent = pille
	local reihe = Instance.new("UIListLayout")
	reihe.FillDirection = Enum.FillDirection.Horizontal
	reihe.VerticalAlignment = Enum.VerticalAlignment.Center
	reihe.Padding = UDim.new(0, 8)
	reihe.SortOrder = Enum.SortOrder.LayoutOrder
	reihe.Parent = pille
	local skala = Instance.new("UIScale")
	skala.Parent = pille

	-- the coin: gold with a steering wheel in the middle
	local function rund(eltern, groesse, farbe)
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(0.5, 0.5)
		f.Size = UDim2.fromOffset(groesse, groesse)
		f.BackgroundColor3 = farbe or Color3.new(1, 1, 1)
		f.BorderSizePixel = 0
		f.Parent = eltern
		Instance.new("UICorner", f).CornerRadius = UDim.new(1, 0)
		return f
	end
	local GOLD_DUNKEL = Color3.fromRGB(150, 95, 10)
	local muenze = rund(pille, 30, Color3.new(1, 1, 1))
	muenze.LayoutOrder = 1
	local glanz = Instance.new("UIGradient")
	glanz.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 236, 140)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(250, 196, 50)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(215, 145, 20)),
	})
	glanz.Rotation = 45
	glanz.Parent = muenze
	local muenzRand = Instance.new("UIStroke")
	muenzRand.Color = Color3.fromRGB(185, 120, 15)
	muenzRand.Thickness = 2
	muenzRand.Parent = muenze
	local lenkrad = rund(muenze, 19, Color3.new(1, 1, 1))
	lenkrad.BackgroundTransparency = 1
	local kranz = Instance.new("UIStroke")
	kranz.Color = GOLD_DUNKEL
	kranz.Thickness = 2.6
	kranz.Parent = lenkrad
	rund(muenze, 7, GOLD_DUNKEL)
	local function speiche(x, y, b, h)
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.new(0.5, x, 0.5, y)
		f.Size = UDim2.fromOffset(b, h)
		f.BackgroundColor3 = GOLD_DUNKEL
		f.BorderSizePixel = 0
		f.Parent = muenze
	end
	speiche(-5.5, 0, 6, 3)  -- left spoke
	speiche(5.5, 0, 6, 3)   -- right spoke
	speiche(0, 5, 3, 6)     -- lower spoke

	local zahl = Instance.new("TextLabel")
	zahl.LayoutOrder = 2
	zahl.BackgroundTransparency = 1
	zahl.Size = UDim2.fromOffset(0, 30)
	zahl.AutomaticSize = Enum.AutomaticSize.X
	zahl.Font = Enum.Font.GothamBlack
	zahl.TextSize = 20
	zahl.TextColor3 = Color3.new(1, 1, 1)
	zahl.Text = "0"
	zahl.Parent = pille

	local function format(n)
		local t = tostring(math.floor(n))
		while true do
			local neu, k = t:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
			t = neu
			if k == 0 then break end
		end
		return t
	end

	local angezeigt = spieler:GetAttribute("Geld") or 0
	zahl.Text = format(angezeigt)
	local zaehler
	local function aktualisieren()
		local ziel = spieler:GetAttribute("Geld") or 0
		local start, t0 = angezeigt, os.clock()
		if zaehler then zaehler:Disconnect() end
		zaehler = RunService.RenderStepped:Connect(function()
			local t = math.min((os.clock() - t0) / 0.8, 1)
			angezeigt = start + (ziel - start) * (1 - (1 - t) ^ 3)
			zahl.Text = format(angezeigt + 0.5)
			if t >= 1 and zaehler then
				zaehler:Disconnect()
				zaehler = nil
				angezeigt = ziel
			end
		end)
	end
	spieler:GetAttributeChangedSignal("Geld"):Connect(aktualisieren)

	-- "+150  Package delivered" floats out under the display
	_G.GeldAnzeigen = function(betrag, grund)
		skala.Scale = 1.15
		TweenService:Create(skala, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		local plus = Instance.new("TextLabel")
		plus.AnchorPoint = Vector2.new(1, 0)
		plus.Position = UDim2.new(1, -20, 0, 54)
		plus.Size = UDim2.fromOffset(300, 22)
		plus.BackgroundTransparency = 1
		plus.Font = Enum.Font.GothamBlack
		plus.TextSize = 18
		plus.TextXAlignment = Enum.TextXAlignment.Right
		plus.TextColor3 = betrag >= 0 and Color3.fromRGB(110, 235, 120) or Color3.fromRGB(255, 110, 110)
		plus.TextStrokeTransparency = 0.5
		plus.Text = (betrag >= 0 and "+" or "") .. format(betrag) .. (grund and ("  " .. grund) or "")
		plus.Parent = geldGui
		TweenService:Create(plus, TweenInfo.new(2.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(1, -20, 0, 84), TextTransparency = 1, TextStrokeTransparency = 1,
		}):Play()
		task.delay(2.3, function() plus:Destroy() end)
	end
end

-- ---------------------------------------------------------------
-- Level (XP), clock + weather (top right, under the money), speed camera flash,
-- rain effect and the personal traffic record
-- ---------------------------------------------------------------
do
	local infoGui = Instance.new("ScreenGui")
	infoGui.Name = "Info"
	infoGui.ResetOnSpawn = false
	infoGui.IgnoreGuiInset = true
	infoGui.DisplayOrder = 8
	infoGui.Parent = spieler.PlayerGui
	local function pille(y, breite)
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(1, 0)
		f.Position = UDim2.new(1, -16, 0, y)
		f.Size = UDim2.fromOffset(breite, 26)
		f.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
		f.BackgroundTransparency = 0.25
		f.Parent = infoGui
		Instance.new("UICorner", f).CornerRadius = UDim.new(1, 0)
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.GothamBold
		t.TextSize = 13
		t.TextColor3 = Color3.new(1, 1, 1)
		t.Parent = f
		return f, t
	end
	-- level with a thin progress bar
	local levelPille, levelText = pille(56, 130)
	local balkenHinten = Instance.new("Frame")
	balkenHinten.Position = UDim2.new(0, 12, 1, -5)
	balkenHinten.Size = UDim2.new(1, -24, 0, 3)
	balkenHinten.BackgroundColor3 = Color3.fromRGB(60, 65, 80)
	balkenHinten.BorderSizePixel = 0
	balkenHinten.Parent = levelPille
	local balken = Instance.new("Frame")
	balken.Size = UDim2.fromScale(0, 1)
	balken.BackgroundColor3 = Color3.fromRGB(120, 200, 255)
	balken.BorderSizePixel = 0
	balken.Parent = balkenHinten
	local function levelAktualisieren()
		local xp = spieler:GetAttribute("XP") or 0
		local level = spieler:GetAttribute("Level") or 1
		local von, bis = 150 * (level - 1) ^ 2, 150 * level ^ 2
		levelText.Text = ("⭐ Level %d"):format(level)
		balken.Size = UDim2.fromScale(math.clamp((xp - von) / math.max(1, bis - von), 0, 1), 1)
	end
	levelAktualisieren()
	spieler:GetAttributeChangedSignal("XP"):Connect(levelAktualisieren)

	-- clock and weather
	local _, uhrText = pille(88, 130)
	local SYMBOL = { Clear = "☀", Rain = "🌧", Fog = "🌫" }
	RunService.RenderStepped:Connect(function()
		local zeit = ordner:GetAttribute("Uhrzeit") or 12
		local wetter = ordner:GetAttribute("Wetter") or "Clear"
		local symbol = (wetter == "Clear" and (zeit < 6 or zeit > 20)) and "🌙" or SYMBOL[wetter] or "☀"
		uhrText.Text = ("%s %02d:%02d  %s"):format(symbol, math.floor(zeit), math.floor((zeit % 1) * 60), wetter)
	end)

	-- XP toast
	_G.XpAnzeigen = function(menge, grund, level, aufstieg)
		local t = Instance.new("TextLabel")
		t.AnchorPoint = Vector2.new(1, 0)
		t.Position = UDim2.new(1, -150, 0, 58)
		t.Size = UDim2.fromOffset(260, 22)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.GothamBlack
		t.TextSize = 16
		t.TextXAlignment = Enum.TextXAlignment.Right
		t.TextColor3 = Color3.fromRGB(120, 200, 255)
		t.TextStrokeTransparency = 0.5
		t.Text = ("+%d XP  %s"):format(menge, grund or "")
		t.Parent = infoGui
		TweenService:Create(t, TweenInfo.new(2.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(1, -150, 0, 30), TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		task.delay(2.3, function() t:Destroy() end)
		if aufstieg then
			local gross = Instance.new("TextLabel")
			gross.AnchorPoint = Vector2.new(0.5, 0.5)
			gross.Position = UDim2.fromScale(0.5, 0.32)
			gross.Size = UDim2.fromOffset(500, 60)
			gross.BackgroundTransparency = 1
			gross.Font = Enum.Font.GothamBlack
			gross.TextSize = 46
			gross.TextColor3 = Color3.fromRGB(255, 215, 80)
			gross.TextStrokeTransparency = 0.2
			gross.Text = ("⭐ LEVEL %d! ⭐"):format(level)
			gross.Parent = infoGui
			local sk = Instance.new("UIScale")
			sk.Scale = 0.3
			sk.Parent = gross
			TweenService:Create(sk, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			task.delay(2.5, function()
				TweenService:Create(gross, TweenInfo.new(0.6), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
				task.delay(0.7, function() gross:Destroy() end)
			end)
		end
	end

	-- speed camera: white flash over the screen + message
	local blitzRahmen = Instance.new("Frame")
	blitzRahmen.Size = UDim2.fromScale(1, 1)
	blitzRahmen.BackgroundColor3 = Color3.new(1, 1, 1)
	blitzRahmen.BackgroundTransparency = 1
	blitzRahmen.ZIndex = 50
	blitzRahmen.Parent = infoGui
	_G.Blitz = function(text)
		blitzRahmen.BackgroundTransparency = 0.15
		TweenService:Create(blitzRahmen, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
		if text then warnen(text, Color3.fromRGB(200, 60, 40)) end
	end

	-- rain around the camera (only on this player's screen)
	local regen = Instance.new("Part")
	regen.Name = "Regen"
	regen.Anchored = true
	regen.CanCollide = false
	regen.CanQuery = false
	regen.CanTouch = false
	regen.Transparency = 1
	regen.Size = Vector3.new(90, 1, 90)
	regen.Parent = workspace
	local tropfen = Instance.new("ParticleEmitter")
	tropfen.Color = ColorSequence.new(Color3.fromRGB(190, 205, 225))
	tropfen.LightEmission = 0.2
	tropfen.Transparency = NumberSequence.new(0.35)
	tropfen.Size = NumberSequence.new(0.12)
	tropfen.Squash = NumberSequence.new(-3.5) -- long thin streaks
	tropfen.Orientation = Enum.ParticleOrientation.VelocityParallel
	tropfen.EmissionDirection = Enum.NormalId.Bottom
	tropfen.Speed = NumberRange.new(70, 85)
	tropfen.Lifetime = NumberRange.new(0.6, 0.8)
	tropfen.Rate = 0
	tropfen.Parent = regen
	RunService.RenderStepped:Connect(function()
		local kam = workspace.CurrentCamera
		if not kam or not kam.CFrame then return end
		regen.CFrame = CFrame.new(kam.CFrame.Position + Vector3.new(0, 35, 0))
		tropfen.Rate = (ordner:GetAttribute("Wetter") == "Rain") and (_G.Sparmodus and 250 or 900) or 0
	end)

	-- personal traffic record (license, points, history)
	local akteGui = Instance.new("ScreenGui")
	akteGui.Name = "Verkehrsakte"
	akteGui.ResetOnSpawn = false
	akteGui.Enabled = false
	akteGui.DisplayOrder = 12
	akteGui.Parent = spieler.PlayerGui
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(420, 420)
	panel.BackgroundColor3 = Color3.fromRGB(25, 30, 40)
	panel.Parent = akteGui
	Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 14)
	local kopf = Instance.new("TextLabel")
	kopf.Position = UDim2.fromOffset(18, 12)
	kopf.Size = UDim2.new(1, -70, 0, 30)
	kopf.BackgroundTransparency = 1
	kopf.Font = Enum.Font.GothamBlack
	kopf.TextSize = 22
	kopf.TextColor3 = Color3.new(1, 1, 1)
	kopf.TextXAlignment = Enum.TextXAlignment.Left
	kopf.Text = "TRAFFIC RECORD"
	kopf.Parent = panel
	local zu3 = Instance.new("TextButton")
	zu3.Position = UDim2.new(1, -44, 0, 12)
	zu3.Size = UDim2.fromOffset(30, 30)
	zu3.BackgroundColor3 = ROT
	zu3.Text = "X"
	zu3.Font = Enum.Font.GothamBold
	zu3.TextSize = 16
	zu3.TextColor3 = Color3.new(1, 1, 1)
	zu3.Parent = panel
	Instance.new("UICorner", zu3)
	zu3.MouseButton1Click:Connect(function() akteGui.Enabled = false end)
	local status = Instance.new("TextLabel")
	status.Position = UDim2.fromOffset(18, 48)
	status.Size = UDim2.new(1, -36, 0, 40)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.GothamBold
	status.TextSize = 15
	status.RichText = true
	status.TextWrapped = true
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.TextColor3 = Color3.new(1, 1, 1)
	status.Parent = panel
	-- points bar: 8 boxes
	local punkteReihe = Instance.new("Frame")
	punkteReihe.Position = UDim2.fromOffset(18, 94)
	punkteReihe.Size = UDim2.new(1, -36, 0, 22)
	punkteReihe.BackgroundTransparency = 1
	punkteReihe.Parent = panel
	local pl = Instance.new("UIListLayout")
	pl.FillDirection = Enum.FillDirection.Horizontal
	pl.Padding = UDim.new(0, 5)
	pl.Parent = punkteReihe
	local punktKaesten = {}
	for i = 1, 8 do
		local k = Instance.new("Frame")
		k.Size = UDim2.fromOffset(40, 22)
		k.BackgroundColor3 = Color3.fromRGB(55, 60, 75)
		k.Parent = punkteReihe
		Instance.new("UICorner", k)
		punktKaesten[i] = k
	end
	local punkteText = Instance.new("TextLabel")
	punkteText.Position = UDim2.fromOffset(18, 120)
	punkteText.Size = UDim2.new(1, -36, 0, 18)
	punkteText.BackgroundTransparency = 1
	punkteText.Font = Enum.Font.Gotham
	punkteText.TextSize = 13
	punkteText.TextXAlignment = Enum.TextXAlignment.Left
	punkteText.TextColor3 = Color3.fromRGB(180, 185, 195)
	punkteText.Parent = panel
	local verlauf = Instance.new("ScrollingFrame")
	verlauf.Position = UDim2.fromOffset(18, 146)
	verlauf.Size = UDim2.new(1, -36, 1, -162)
	verlauf.BackgroundColor3 = Color3.fromRGB(18, 22, 30)
	verlauf.BorderSizePixel = 0
	verlauf.ScrollBarThickness = 6
	verlauf.AutomaticCanvasSize = Enum.AutomaticSize.Y
	verlauf.CanvasSize = UDim2.new()
	verlauf.Parent = panel
	Instance.new("UICorner", verlauf)
	local vl = Instance.new("UIListLayout")
	vl.Padding = UDim.new(0, 2)
	vl.Parent = verlauf

	local function akteFuellen()
		local r = frage("akte")
		if r.fehler then hinweis(r.fehler) return false end
		local zustand
		if r.fuehrerschein then
			zustand = "<font color=\"#6fdc80\">VALID</font>  –  classes " .. (r.lkw and "B, C" or "B")
		elseif r.entzogen then
			zustand = "<font color=\"#ff6b6b\">WITHDRAWN</font>  –  " .. (r.nachschulung and "retraining done, book the driving test" or "talk to Anna (retraining course)")
		else
			zustand = "<font color=\"#c0c4cc\">NO LICENSE YET</font>"
		end
		status.Text = ("License: %s\nLevel %d  ·  %d XP"):format(zustand, r.level or 1, r.xp or 0)
		for i, k in punktKaesten do
			k.BackgroundColor3 = i <= r.punkte and (r.punkte >= 6 and Color3.fromRGB(220, 60, 60) or Color3.fromRGB(240, 170, 40)) or Color3.fromRGB(55, 60, 75)
		end
		punkteText.Text = ("Penalty points: %d of %d%s"):format(r.punkte, r.limit, r.naechsterVerfall and ("  ·  next point expires in %d min"):format(math.ceil(r.naechsterVerfall / 60)) or "")
		for _, k in verlauf:GetChildren() do
			if k:IsA("TextLabel") then k:Destroy() end
		end
		if #r.historie == 0 then
			local leer = Instance.new("TextLabel")
			leer.Size = UDim2.new(1, -8, 0, 40)
			leer.BackgroundTransparency = 1
			leer.Font = Enum.Font.Gotham
			leer.TextSize = 14
			leer.TextColor3 = Color3.fromRGB(150, 220, 160)
			leer.Text = "No entries – a clean record! 👍"
			leer.Parent = verlauf
		end
		for i, e in r.historie do
			local z = Instance.new("TextLabel")
			z.LayoutOrder = i
			z.Size = UDim2.new(1, -8, 0, 34)
			z.BackgroundTransparency = 1
			z.Font = Enum.Font.Gotham
			z.TextSize = 13
			z.RichText = true
			z.TextWrapped = true
			z.TextXAlignment = Enum.TextXAlignment.Left
			z.TextColor3 = Color3.fromRGB(225, 228, 235)
			local zusatz = {}
			if (e.geld or 0) > 0 then table.insert(zusatz, "-" .. e.geld .. " coins") end
			if (e.punkte or 0) > 0 then table.insert(zusatz, "+" .. e.punkte .. " pts") end
			if (e.punkte or 0) < 0 then table.insert(zusatz, e.punkte .. " pt") end
			z.Text = ("  <font color=\"#8a93a6\">%s</font>  %s  <b>%s</b>"):format(os.date("%d.%m. %H:%M", e.t or 0), e.text or "", table.concat(zusatz, ", "))
			z.Parent = verlauf
		end
		return true
	end
	local akteKnopf = leistenKnopf("📋", "Record", 5)
	akteKnopf.MouseButton1Click:Connect(function()
		if akteGui.Enabled then akteGui.Enabled = false return end
		if akteFuellen() then akteGui.Enabled = true end
	end)
end

-- ---------------------------------------------------------------
-- Ben's Garage (repair, insurance, tuning), daily missions and the WANTED badge
-- ---------------------------------------------------------------
do
	local function fenster(name, titelText, breite, hoehe, farbe)
		local g = Instance.new("ScreenGui")
		g.Name = name
		g.ResetOnSpawn = false
		g.DisplayOrder = 12
		g.Parent = spieler.PlayerGui
		local panel = Instance.new("Frame")
		panel.AnchorPoint = Vector2.new(0.5, 0.5)
		panel.Position = UDim2.fromScale(0.5, 0.5)
		panel.Size = UDim2.fromOffset(breite, hoehe)
		panel.BackgroundColor3 = Color3.fromRGB(22, 24, 30)
		panel.Parent = g
		Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 14)
		local kopf = Instance.new("Frame")
		kopf.Size = UDim2.new(1, 0, 0, 48)
		kopf.BackgroundColor3 = farbe
		kopf.Parent = panel
		Instance.new("UICorner", kopf).CornerRadius = UDim.new(0, 14)
		local t = Instance.new("TextLabel")
		t.Position = UDim2.fromOffset(16, 0)
		t.Size = UDim2.new(1, -70, 1, 0)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.GothamBlack
		t.TextSize = 20
		t.TextColor3 = Color3.new(1, 1, 1)
		t.TextXAlignment = Enum.TextXAlignment.Left
		t.Text = titelText
		t.Parent = kopf
		local zu5 = Instance.new("TextButton")
		zu5.Position = UDim2.new(1, -42, 0, 9)
		zu5.Size = UDim2.fromOffset(30, 30)
		zu5.BackgroundColor3 = Color3.fromRGB(40, 20, 20)
		zu5.Text = "X"
		zu5.Font = Enum.Font.GothamBold
		zu5.TextSize = 16
		zu5.TextColor3 = Color3.new(1, 1, 1)
		zu5.Parent = kopf
		Instance.new("UICorner", zu5)
		zu5.MouseButton1Click:Connect(function() g:Destroy() end)
		local liste = Instance.new("ScrollingFrame")
		liste.Position = UDim2.fromOffset(12, 58)
		liste.Size = UDim2.new(1, -24, 1, -70)
		liste.BackgroundTransparency = 1
		liste.BorderSizePixel = 0
		liste.ScrollBarThickness = 6
		liste.AutomaticCanvasSize = Enum.AutomaticSize.Y
		liste.CanvasSize = UDim2.new()
		liste.Parent = panel
		local l = Instance.new("UIListLayout")
		l.Padding = UDim.new(0, 8)
		l.SortOrder = Enum.SortOrder.LayoutOrder
		l.Parent = liste
		return g, liste
	end
	local function knopf(eltern, text, farbe, x, y, b, klick)
		local k = Instance.new("TextButton")
		k.Position = UDim2.fromOffset(x, y)
		k.Size = UDim2.fromOffset(b, 28)
		k.BackgroundColor3 = farbe
		k.Font = Enum.Font.GothamBold
		k.TextSize = 12
		k.TextColor3 = Color3.new(1, 1, 1)
		k.Text = text
		k.Parent = eltern
		Instance.new("UICorner", k)
		if klick then k.MouseButton1Click:Connect(klick) end
		return k
	end

	local werkstattGui
	local NEON = { Color3.fromRGB(40, 120, 255), Color3.fromRGB(255, 40, 60), Color3.fromRGB(40, 255, 120), Color3.fromRGB(190, 60, 255), Color3.fromRGB(255, 120, 200) }
	local FELGEN = { Color3.fromRGB(200, 200, 205), Color3.fromRGB(25, 25, 28), Color3.fromRGB(220, 180, 60), Color3.fromRGB(200, 30, 35), Color3.fromRGB(245, 245, 245) }
	local function werkstattZeigen(info)
		if werkstattGui then werkstattGui:Destroy() end
		local liste
		werkstattGui, liste = fenster("Werkstatt", ("🔧 BEN'S GARAGE   ·   %d coins"):format(info.geld), 520, 470, Color3.fromRGB(230, 120, 30))
		if #info.autos == 0 then
			local leer = Instance.new("TextLabel")
			leer.Size = UDim2.new(1, -10, 0, 60)
			leer.BackgroundTransparency = 1
			leer.Font = Enum.Font.Gotham
			leer.TextSize = 15
			leer.TextWrapped = true
			leer.TextColor3 = Color3.new(1, 1, 1)
			leer.Text = "You don't own a car yet. Buy one at Velocity Motors and come back for repairs and tuning!"
			leer.Parent = liste
			return
		end
		local function machen(art, typ, wert)
			local r = frage("werkstatt", { art = art, typ = typ, wert = wert })
			if r.fehler then hinweis(r.fehler) return end
			warnen(r.text, GRUEN)
			werkstattZeigen(r.info)
		end
		for i, a in info.autos do
			local karte = Instance.new("Frame")
			karte.LayoutOrder = i
			karte.Size = UDim2.new(1, -10, 0, 150)
			karte.BackgroundColor3 = Color3.fromRGB(34, 38, 48)
			karte.Parent = liste
			Instance.new("UICorner", karte)
			local n = Instance.new("TextLabel")
			n.Position = UDim2.fromOffset(12, 6)
			n.Size = UDim2.new(1, -24, 0, 22)
			n.BackgroundTransparency = 1
			n.Font = Enum.Font.GothamBlack
			n.TextSize = 16
			n.TextColor3 = Color3.new(1, 1, 1)
			n.TextXAlignment = Enum.TextXAlignment.Left
			n.RichText = true
			n.Text = ("%s   <font size=\"13\" color=\"#aab2c2\">🔧 %d %%  ·  ⛽ %d %%  ·  %s  ·  Engine %d/3</font>"):format(a.name, a.zustand, a.tank, a.versichert and "insured ✓" or "not insured", a.motor)
			n.Parent = karte
			-- row 1: repair, insurance, engine
			knopf(karte, a.zustand >= 100 and "Condition 100 % ✓" or ("Repair – %d"):format(a.reparatur), a.zustand >= 100 and GRAU or GRUEN, 12, 34, 150, function() machen("reparieren", a.typ) end)
			knopf(karte, a.versichert and "Insured ✓" or ("Insurance – %d"):format(a.versicherung), a.versichert and GRAU or BLAU, 170, 34, 150, function() machen("versichern", a.typ) end)
			knopf(karte, a.motorPreis and ("Engine +1 – %d"):format(a.motorPreis) or "Engine MAX", a.motorPreis and Color3.fromRGB(170, 60, 40) or GRAU, 328, 34, 150, function() machen("motor", a.typ) end)
			-- row 2: spoiler and neon
			knopf(karte, a.spoiler and "Remove spoiler" or ("Spoiler – %d"):format(info.preise.spoiler), Color3.fromRGB(60, 65, 80), 12, 70, 150, function() machen("spoiler", a.typ) end)
			local neonText = Instance.new("TextLabel")
			neonText.Position = UDim2.fromOffset(170, 70)
			neonText.Size = UDim2.fromOffset(70, 28)
			neonText.BackgroundTransparency = 1
			neonText.Font = Enum.Font.GothamBold
			neonText.TextSize = 12
			neonText.TextColor3 = Color3.fromRGB(200, 205, 215)
			neonText.Text = ("Neon %d"):format(a.neon > 0 and 100 or info.preise.neon)
			neonText.Parent = karte
			for j, f in NEON do
				local b = knopf(karte, "", f, 238 + (j - 1) * 34, 70, 28, function() machen("neon", a.typ, j) end)
				if a.neon == j then
					local r = Instance.new("UIStroke")
					r.Color = Color3.new(1, 1, 1)
					r.Thickness = 2
					r.Parent = b
				end
			end
			knopf(karte, "off", GRAU, 410, 70, 36, function() machen("neon", a.typ, 0) end)
			-- row 3: rims
			local felgenText = Instance.new("TextLabel")
			felgenText.Position = UDim2.fromOffset(12, 106)
			felgenText.Size = UDim2.fromOffset(110, 28)
			felgenText.BackgroundTransparency = 1
			felgenText.Font = Enum.Font.GothamBold
			felgenText.TextSize = 12
			felgenText.TextColor3 = Color3.fromRGB(200, 205, 215)
			felgenText.Text = ("Rim color – %d"):format(info.preise.felgen)
			felgenText.Parent = karte
			for j, f in FELGEN do
				local b = knopf(karte, "", f, 130 + (j - 1) * 34, 106, 28, function() machen("felgen", a.typ, j) end)
				if a.felgen == j then
					local r = Instance.new("UIStroke")
					r.Color = Color3.fromRGB(255, 200, 60)
					r.Thickness = 2
					r.Parent = b
				end
			end
		end
	end
	_G.WerkstattOeffnen = function()
		local r = frage("werkstattInfo")
		if r.fehler then hinweis(r.fehler) return end
		werkstattZeigen(r)
	end

	-- daily missions
	local missionGui
	local mKnopf = leistenKnopf("🎯", "Daily", 3)
	mKnopf.MouseButton1Click:Connect(function()
		if missionGui then missionGui:Destroy() missionGui = nil return end
		local r = frage("missionen")
		if r.fehler then hinweis(r.fehler) return end
		local liste
		missionGui, liste = fenster("Missionen", "🎯 DAILY MISSIONS", 420, 330, Color3.fromRGB(40, 120, 200))
		for i, m in r.liste do
			local z = Instance.new("Frame")
			z.LayoutOrder = i
			z.Size = UDim2.new(1, -10, 0, 72)
			z.BackgroundColor3 = m.fertig and Color3.fromRGB(35, 70, 45) or Color3.fromRGB(34, 38, 48)
			z.Parent = liste
			Instance.new("UICorner", z)
			local t = Instance.new("TextLabel")
			t.Position = UDim2.fromOffset(12, 6)
			t.Size = UDim2.new(1, -24, 0, 22)
			t.BackgroundTransparency = 1
			t.Font = Enum.Font.GothamBold
			t.TextSize = 15
			t.TextColor3 = Color3.new(1, 1, 1)
			t.TextXAlignment = Enum.TextXAlignment.Left
			t.Text = (m.fertig and "✅ " or "") .. m.text
			t.Parent = z
			local hinten = Instance.new("Frame")
			hinten.Position = UDim2.fromOffset(12, 34)
			hinten.Size = UDim2.new(1, -24, 0, 10)
			hinten.BackgroundColor3 = Color3.fromRGB(55, 60, 75)
			hinten.Parent = z
			Instance.new("UICorner", hinten)
			local balken = Instance.new("Frame")
			balken.Size = UDim2.fromScale(math.clamp(m.stand / m.ziel, 0, 1), 1)
			balken.BackgroundColor3 = m.fertig and GRUEN or Color3.fromRGB(80, 160, 255)
			balken.Parent = hinten
			Instance.new("UICorner", balken)
			local b = Instance.new("TextLabel")
			b.Position = UDim2.fromOffset(12, 48)
			b.Size = UDim2.new(1, -24, 0, 18)
			b.BackgroundTransparency = 1
			b.Font = Enum.Font.Gotham
			b.TextSize = 12
			b.TextColor3 = Color3.fromRGB(190, 195, 205)
			b.TextXAlignment = Enum.TextXAlignment.Left
			b.Text = ("%s / %s   ·   Reward: %d coins + %d XP"):format(m.stand % 1 == 0 and tostring(m.stand) or ("%.1f"):format(m.stand), tostring(m.ziel), m.geld, m.xp)
			b.Parent = z
		end
	end)

	-- WANTED badge (driving without a valid license)
	local gesuchtGui = Instance.new("ScreenGui")
	gesuchtGui.Name = "Gesucht"
	gesuchtGui.ResetOnSpawn = false
	gesuchtGui.IgnoreGuiInset = true
	gesuchtGui.DisplayOrder = 9
	gesuchtGui.Enabled = false
	gesuchtGui.Parent = spieler.PlayerGui
	local badge = Instance.new("TextLabel")
	badge.AnchorPoint = Vector2.new(1, 0)
	badge.Position = UDim2.new(1, -16, 0, 160)
	badge.Size = UDim2.fromOffset(130, 30)
	badge.Font = Enum.Font.GothamBlack
	badge.TextSize = 15
	badge.TextColor3 = Color3.new(1, 1, 1)
	badge.Text = "🚨 WANTED"
	badge.Parent = gesuchtGui
	Instance.new("UICorner", badge).CornerRadius = UDim.new(1, 0)
	RunService.RenderStepped:Connect(function()
		gesuchtGui.Enabled = spieler:GetAttribute("Gesucht") == true
		if gesuchtGui.Enabled then
			badge.BackgroundColor3 = math.floor(os.clock() * 3) % 2 == 0 and Color3.fromRGB(200, 30, 40) or Color3.fromRGB(30, 60, 190)
		end
	end)
end

-- ---------------------------------------------------------------
-- Police banner (flashes red / blue while the police wants you to stop)
-- ---------------------------------------------------------------
do
	local pg = Instance.new("ScreenGui")
	pg.Name = "Polizei"
	pg.ResetOnSpawn = false
	pg.IgnoreGuiInset = true
	pg.DisplayOrder = 9
	pg.Enabled = false
	pg.Parent = spieler.PlayerGui
	local banner = Instance.new("TextLabel")
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 106)
	banner.Size = UDim2.new(0.8, 0, 0, 40)
	banner.Font = Enum.Font.GothamBlack
	banner.TextSize = 17
	banner.TextWrapped = true
	banner.TextColor3 = Color3.new(1, 1, 1)
	banner.Parent = pg
	Instance.new("UICorner", banner)
	local grenzeB = Instance.new("UISizeConstraint")
	grenzeB.MaxSize = Vector2.new(560, 40)
	grenzeB.Parent = banner
	local verbindung
	_G.PolizeiBanner = function(phase, text)
		if phase == "ende" then
			pg.Enabled = false
			if verbindung then verbindung:Disconnect() verbindung = nil end
			return
		end
		banner.Text = text or "POLICE"
		pg.Enabled = true
		if not verbindung then
			verbindung = RunService.RenderStepped:Connect(function()
				local blau = math.floor(os.clock() * 4) % 2 == 0
				banner.BackgroundColor3 = blau and Color3.fromRGB(30, 70, 200) or Color3.fromRGB(200, 30, 40)
			end)
		end
	end
end

-- ---------------------------------------------------------------
-- Phones, tablets and weak PCs
-- * big windows are scaled down so they fit on small screens
-- * street lamps only light up at night and near the camera
-- * performance mode ("Graphics: Fast" in the settings): no sun rays / depth of field / bloom,
--   less rain, far NPC cars and the minimap are updated less often.
--   It switches on by itself on phones/tablets and when the frame rate stays low.
-- ---------------------------------------------------------------
do
	local Lighting = game:GetService("Lighting")
	local GuiService = game:GetService("GuiService")
	local UIS = game:GetService("UserInputService")

	_G.SparmodusSetzen = function(an)
		_G.Sparmodus = an == true
		Verkehr.sparmodus = _G.Sparmodus
		for _, e in Lighting:GetChildren() do
			if e:IsA("SunRaysEffect") or e:IsA("DepthOfFieldEffect") or e:IsA("BloomEffect") then
				e.Enabled = not _G.Sparmodus
			end
		end
	end
	local function nurTouch()
		return UIS.TouchEnabled == true and UIS.KeyboardEnabled ~= true
	end
	-- not chosen by the player yet: phones and tablets start in performance mode
	_G.SparmodusAuto = function()
		local e = _G.Einstellungen
		if e and not e.sparmodusGewaehlt then
			e.sparmodus = nurTouch()
		end
		_G.SparmodusSetzen(e and e.sparmodus)
	end
	_G.SparmodusAuto()

	-- frame rate watch: stays below 30 fps for 10 seconds -> performance mode (only if the player didn't choose)
	local bilder, langsam = 0, 0
	RunService.RenderStepped:Connect(function() bilder += 1 end)
	task.spawn(function()
		while true do
			bilder = 0
			task.wait(5)
			local fps = bilder / 5
			local e = _G.Einstellungen
			if _G.ImSpiel and e and not e.sparmodusGewaehlt and not e.sparmodus then
				langsam = fps < 30 and langsam + 1 or 0
				if langsam >= 2 then
					e.sparmodus = true
					_G.SparmodusSetzen(true)
					warnen("⚡ Performance mode switched on (Settings → Graphics)", Color3.fromRGB(40, 150, 70))
				end
			end
		end
	end)

	-- street lamps: light only at night and near the camera (hundreds of lights cost a lot)
	local lampen = {}
	local karte = workspace:WaitForChild("Karte")
	local function merken(x)
		if x:IsA("PointLight") and x.Parent and x.Parent.Name == "Leuchte" then lampen[x] = true end
	end
	for _, x in karte:GetDescendants() do merken(x) end
	karte.DescendantAdded:Connect(merken)
	karte.DescendantRemoving:Connect(function(x) lampen[x] = nil end)
	task.spawn(function()
		while true do
			local zeit = ordner:GetAttribute("Uhrzeit") or 12
			local nacht = zeit < 6.8 or zeit > 18.2 or ordner:GetAttribute("Wetter") == "Fog"
			local kam = workspace.CurrentCamera
			local auge = kam and kam.CFrame and kam.CFrame.Position or Vector3.zero
			local reichweite = _G.Sparmodus and 150 or 420
			for licht in lampen do
				local teil = licht.Parent
				if teil and teil:IsA("BasePart") then
					local an = nacht and Vector3.new(teil.Position.X - auge.X, 0, teil.Position.Z - auge.Z).Magnitude < reichweite
					if licht.Enabled ~= an then licht.Enabled = an end
				end
			end
			task.wait(1.5)
		end
	end)

	-- big fixed-size windows: scale down on small screens (phones in landscape are only ~350 px high)
	local function einpassen(panel)
		if not panel:IsA("GuiObject") or panel.AnchorPoint ~= Vector2.new(0.5, 0.5) then return end
		if panel.Size.X.Scale ~= 0 or panel.Size.Y.Scale ~= 0 or panel.Size.Y.Offset < 200 then return end
		for _, k in panel:GetChildren() do
			if k:IsA("UIScale") and k.Name ~= "Einpassen" then return end -- has its own pop animation
		end
		local kam = workspace.CurrentCamera
		local vp = kam and kam.ViewportSize
		if not vp or vp.X < 10 then return end
		local okInset, oben = pcall(function() return GuiService:GetGuiInset() end)
		local obenY = (okInset and oben and oben.Y) or 36
		local faktor = math.min(1, (vp.X - 20) / panel.Size.X.Offset, (vp.Y - obenY - 16) / panel.Size.Y.Offset)
		local s = panel:FindFirstChild("Einpassen")
		if faktor >= 0.999 then
			if s then s:Destroy() end
			return
		end
		s = s or Instance.new("UIScale")
		s.Name = "Einpassen"
		s.Scale = math.max(0.45, faktor)
		s.Parent = panel
	end
	local function guiPruefen(g)
		if not g:IsA("ScreenGui") then return end
		for _, k in g:GetChildren() do einpassen(k) end
		g.ChildAdded:Connect(function(k) task.defer(einpassen, k) end)
	end
	local pg = spieler:WaitForChild("PlayerGui")
	for _, g in pg:GetChildren() do guiPruefen(g) end
	pg.ChildAdded:Connect(function(g) task.defer(guiPruefen, g) end)
	local kam = workspace.CurrentCamera
	if kam then
		kam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			for _, g in pg:GetChildren() do
				if g:IsA("ScreenGui") then
					for _, k in g:GetChildren() do einpassen(k) end
				end
			end
		end)
	end
end

-- ---------------------------------------------------------------
-- NPC traffic: the server sends where the vehicles are, we draw them here
-- ---------------------------------------------------------------
task.spawn(function()
	local event = ordner:WaitForChild("VerkehrDaten", 20)
	if not event then return end
	for _ = 1, 15 do
		local r = frage("verkehr")
		if r.liste then
			Verkehr.anzeigen(r.liste, event)
			return
		end
		task.wait(2)
	end
	warn("[Driving School] NPC traffic not available")
end)

-- ---------------------------------------------------------------
-- Settings (saved on the server) and the start screen
-- ---------------------------------------------------------------
_G.Einstellungen = { minimap = true, mph = false, grosseAnzeige = false, ersteP = false, sparmodus = false, sparmodusGewaehlt = false }
_G.SparmodusAuto() -- phones / tablets: performance mode until the saved settings say otherwise

local function einstellungenAnwenden()
	local e = _G.Einstellungen
	if _G.SparmodusSetzen then _G.SparmodusSetzen(e.sparmodus) end
	if _G.MinimapGui then _G.MinimapGui.Enabled = e.minimap end
	if e.grosseAnzeige then
		anweisung.Size = UDim2.new(0.85, 0, 0, 84)
		ag.MaxSize = Vector2.new(620, 84)
		anweisungText.TextSize = 18
	else
		anweisung.Size = UDim2.new(0.7, 0, 0, 58)
		ag.MaxSize = Vector2.new(470, 58)
		anweisungText.TextSize = 14
	end
end

local einstellGui = Instance.new("ScreenGui")
einstellGui.Name = "Einstellungen"
einstellGui.ResetOnSpawn = false
einstellGui.Enabled = false
einstellGui.DisplayOrder = 110
einstellGui.IgnoreGuiInset = true
einstellGui.Parent = spieler.PlayerGui
local einstellRahmen = Instance.new("Frame")
einstellRahmen.AnchorPoint = Vector2.new(0.5, 0.5)
einstellRahmen.Position = UDim2.fromScale(0.5, 0.5)
einstellRahmen.Size = UDim2.fromOffset(380, 384)
einstellRahmen.BackgroundColor3 = Color3.fromRGB(25, 30, 40)
einstellRahmen.Parent = einstellGui
Instance.new("UICorner", einstellRahmen).CornerRadius = UDim.new(0, 14)
local eTitel = Instance.new("TextLabel")
eTitel.Position = UDim2.fromOffset(20, 14)
eTitel.Size = UDim2.new(1, -40, 0, 30)
eTitel.BackgroundTransparency = 1
eTitel.Font = Enum.Font.GothamBlack
eTitel.TextSize = 24
eTitel.TextColor3 = Color3.new(1, 1, 1)
eTitel.TextXAlignment = Enum.TextXAlignment.Left
eTitel.Text = "SETTINGS"
eTitel.Parent = einstellRahmen

local OPTIONEN = {
	{ "minimap", "Minimap", "On", "Off" },
	{ "mph", "Speed unit", "mph", "km/h" },
	{ "grosseAnzeige", "Instruction box", "Large", "Small" },
	{ "ersteP", "Start in first person", "On", "Off" },
	{ "sparmodus", "Graphics", "⚡ Fast", "Best" },
}
local optionKnoepfe = {}
for i, o in OPTIONEN do
	local zeile = Instance.new("TextLabel")
	zeile.Position = UDim2.fromOffset(20, 56 + (i - 1) * 50)
	zeile.Size = UDim2.fromOffset(200, 40)
	zeile.BackgroundTransparency = 1
	zeile.Font = Enum.Font.GothamBold
	zeile.TextSize = 16
	zeile.TextColor3 = Color3.fromRGB(220, 225, 235)
	zeile.TextXAlignment = Enum.TextXAlignment.Left
	zeile.Text = o[2]
	zeile.Parent = einstellRahmen
	local k = Instance.new("TextButton")
	k.Position = UDim2.fromOffset(230, 60 + (i - 1) * 50)
	k.Size = UDim2.fromOffset(130, 32)
	k.Font = Enum.Font.GothamBold
	k.TextSize = 15
	k.TextColor3 = Color3.new(1, 1, 1)
	k.Parent = einstellRahmen
	Instance.new("UICorner", k)
	optionKnoepfe[o[1]] = { knopf = k, an = o[3], aus = o[4] }
	k.MouseButton1Click:Connect(function()
		_G.Einstellungen[o[1]] = not _G.Einstellungen[o[1]]
		if o[1] == "sparmodus" then _G.Einstellungen.sparmodusGewaehlt = true end
		for schl, ok in optionKnoepfe do
			local wert = _G.Einstellungen[schl]
			ok.knopf.Text = wert and ok.an or ok.aus
			ok.knopf.BackgroundColor3 = wert and GRUEN or GRAU
		end
		einstellungenAnwenden()
		task.spawn(frage, "einstellungen", _G.Einstellungen)
	end)
end
local function knoepfeAktualisieren()
	for schl, ok in optionKnoepfe do
		local wert = _G.Einstellungen[schl]
		ok.knopf.Text = wert and ok.an or ok.aus
		ok.knopf.BackgroundColor3 = wert and GRUEN or GRAU
	end
end
local eZurueck = Instance.new("TextButton")
eZurueck.AnchorPoint = Vector2.new(0.5, 1)
eZurueck.Position = UDim2.new(0.5, 0, 1, -16)
eZurueck.Size = UDim2.fromOffset(200, 40)
eZurueck.BackgroundColor3 = BLAU
eZurueck.Font = Enum.Font.GothamBlack
eZurueck.TextSize = 18
eZurueck.TextColor3 = Color3.new(1, 1, 1)
eZurueck.Text = "Back"
eZurueck.Parent = einstellRahmen
Instance.new("UICorner", eZurueck)
eZurueck.MouseButton1Click:Connect(function()
	einstellGui.Enabled = false
end)

-- small gear button to open the settings at any time
local zahnrad = leistenKnopf("⚙", "Settings", 7)
zahnrad.MouseButton1Click:Connect(function()
	knoepfeAktualisieren()
	einstellGui.Enabled = true
end)

-- "My Cars": get one of your bought cars to the nearest parking spot
do
	local autoKnopf = leistenKnopf("🚗", "My Cars", 4)

	local FARBEN = {
		Color3.fromRGB(200, 25, 30), Color3.fromRGB(25, 70, 170), Color3.fromRGB(240, 240, 240), Color3.fromRGB(20, 20, 24),
		Color3.fromRGB(150, 155, 160), Color3.fromRGB(245, 190, 30), Color3.fromRGB(30, 130, 70), Color3.fromRGB(240, 110, 20),
		-- exclusive colors (VIP / Paint Studio, same order as Shop.FARBEN on the server)
		Color3.fromRGB(212, 168, 60), Color3.fromRGB(236, 232, 222), Color3.fromRGB(45, 25, 80),
		Color3.fromRGB(20, 70, 45), Color3.fromRGB(150, 10, 25), Color3.fromRGB(150, 200, 235),
	}
	local gewaehlt = 1
	local ag2 = Instance.new("ScreenGui")
	ag2.Name = "MeineAutos"
	ag2.ResetOnSpawn = false
	ag2.Enabled = false
	ag2.DisplayOrder = 12
	ag2.Parent = spieler.PlayerGui
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(380, 412)
	panel.BackgroundColor3 = Color3.fromRGB(25, 30, 40)
	panel.Parent = ag2
	Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 14)
	local kopf = Instance.new("TextLabel")
	kopf.Position = UDim2.fromOffset(18, 12)
	kopf.Size = UDim2.new(1, -70, 0, 30)
	kopf.BackgroundTransparency = 1
	kopf.Font = Enum.Font.GothamBlack
	kopf.TextSize = 22
	kopf.TextColor3 = Color3.new(1, 1, 1)
	kopf.TextXAlignment = Enum.TextXAlignment.Left
	kopf.Text = "MY CARS"
	kopf.Parent = panel
	local zu2 = Instance.new("TextButton")
	zu2.Position = UDim2.new(1, -44, 0, 12)
	zu2.Size = UDim2.fromOffset(30, 30)
	zu2.BackgroundColor3 = ROT
	zu2.Text = "X"
	zu2.Font = Enum.Font.GothamBold
	zu2.TextSize = 16
	zu2.TextColor3 = Color3.new(1, 1, 1)
	zu2.Parent = panel
	Instance.new("UICorner", zu2)
	zu2.MouseButton1Click:Connect(function() ag2.Enabled = false end)
	local liste2 = Instance.new("ScrollingFrame")
	liste2.Position = UDim2.fromOffset(18, 52)
	liste2.Size = UDim2.new(1, -36, 0, 200)
	liste2.BackgroundTransparency = 1
	liste2.BorderSizePixel = 0
	liste2.ScrollBarThickness = 6
	liste2.AutomaticCanvasSize = Enum.AutomaticSize.Y
	liste2.CanvasSize = UDim2.new()
	liste2.Parent = panel
	local ll2 = Instance.new("UIListLayout")
	ll2.Padding = UDim.new(0, 6)
	ll2.Parent = liste2
	local farbText = Instance.new("TextLabel")
	farbText.Position = UDim2.fromOffset(18, 258)
	farbText.Size = UDim2.new(1, -36, 0, 18)
	farbText.BackgroundTransparency = 1
	farbText.Font = Enum.Font.GothamBold
	farbText.TextSize = 13
	farbText.TextColor3 = Color3.fromRGB(180, 185, 195)
	farbText.TextXAlignment = Enum.TextXAlignment.Left
	farbText.Text = "Paint color   (✦ = exclusive: VIP / Paint Studio)"
	farbText.Parent = panel
	local swatches = {}
	for i, f in FARBEN do
		local b = Instance.new("TextButton")
		local exklusiv = i > 8
		b.Position = UDim2.fromOffset(18 + ((i - 1) % 8) * 42, exklusiv and 320 or 280)
		b.Size = UDim2.fromOffset(34, 34)
		b.BackgroundColor3 = f
		b.Text = exklusiv and "✦" or ""
		b.TextColor3 = Color3.fromRGB(255, 215, 90)
		b.TextSize = 14
		b.Font = Enum.Font.GothamBlack
		b.Parent = panel
		Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
		local rand2 = Instance.new("UIStroke")
		rand2.Color = Color3.new(1, 1, 1)
		rand2.Thickness = i == gewaehlt and 3 or 0
		rand2.Parent = b
		swatches[i] = rand2
		b.MouseButton1Click:Connect(function()
			gewaehlt = i
			for j, r in swatches do r.Thickness = j == i and 3 or 0 end
		end)
	end
	local wegKnopf = Instance.new("TextButton")
	wegKnopf.Position = UDim2.new(0, 18, 1, -44)
	wegKnopf.Size = UDim2.new(0.5, -22, 0, 32)
	local hilfeKnopf = Instance.new("TextButton")
	hilfeKnopf.Position = UDim2.new(0.5, 4, 1, -44)
	hilfeKnopf.Size = UDim2.new(0.5, -22, 0, 32)
	hilfeKnopf.BackgroundColor3 = Color3.fromRGB(200, 120, 30)
	hilfeKnopf.Font = Enum.Font.GothamBold
	hilfeKnopf.TextSize = 13
	hilfeKnopf.TextColor3 = Color3.new(1, 1, 1)
	hilfeKnopf.Text = "🛠 Roadside help"
	hilfeKnopf.Parent = panel
	Instance.new("UICorner", hilfeKnopf)
	hilfeKnopf.MouseButton1Click:Connect(function()
		local r = frage("pannenhilfe")
		ag2.Enabled = false
		hinweis(r.fehler or r.text)
	end)
	wegKnopf.BackgroundColor3 = GRAU
	wegKnopf.Font = Enum.Font.GothamBold
	wegKnopf.TextSize = 14
	wegKnopf.TextColor3 = Color3.new(1, 1, 1)
	wegKnopf.Text = "Park my car away"
	wegKnopf.Parent = panel
	Instance.new("UICorner", wegKnopf)
	wegKnopf.MouseButton1Click:Connect(function()
		local r = frage("autoWeg")
		ag2.Enabled = false
		hinweis(r.fehler or r.text)
	end)

	local function fuellen()
		for _, k in liste2:GetChildren() do
			if k:IsA("GuiObject") then k:Destroy() end
		end
		local r = frage("meineAutos")
		if r.fehler then hinweis(r.fehler) return false end
		local eigene = 0
		for _, a in r.katalog do
			if a.gehoert then
				eigene += 1
				local zeile = Instance.new("TextButton")
				zeile.Size = UDim2.new(1, 0, 0, 46)
				zeile.BackgroundColor3 = Color3.fromRGB(40, 48, 62)
				zeile.Font = Enum.Font.GothamBold
				zeile.TextSize = 15
				zeile.TextColor3 = Color3.new(1, 1, 1)
				zeile.TextXAlignment = Enum.TextXAlignment.Left
				zeile.Text = ("   %s  ·  %d km/h  ·  %.1f km driven     ▶ Get it"):format(a.name, a.tempo, (r.km and r.km[a.typ]) or 0)
				zeile.Parent = liste2
				Instance.new("UICorner", zeile)
				zeile.MouseButton1Click:Connect(function()
					local h = frage("autoHolen", { typ = a.typ, farbe = gewaehlt })
					ag2.Enabled = false
					hinweis(h.fehler or h.text)
				end)
			end
		end
		if eigene == 0 then
			local leer = Instance.new("TextLabel")
			leer.Size = UDim2.new(1, 0, 0, 90)
			leer.BackgroundTransparency = 1
			leer.Font = Enum.Font.Gotham
			leer.TextSize = 15
			leer.TextWrapped = true
			leer.TextColor3 = Color3.fromRGB(200, 205, 215)
			leer.Text = "You don't own a car yet. Visit Velocity Motors next to the highway access road north of the city!"
			leer.Parent = liste2
		end
		return true
	end
	autoKnopf.MouseButton1Click:Connect(function()
		if ag2.Enabled then ag2.Enabled = false return end
		if fuellen() then ag2.Enabled = true end
	end)
end

-- ---------------------------------------------------------------
-- Rewards (daily streak, playtime gifts, achievements, bonuses) and the Robux shop
-- ---------------------------------------------------------------
do
	local MarketplaceService = game:GetService("MarketplaceService")
	local SocialService = game:GetService("SocialService")
	local GOLD = Color3.fromRGB(245, 185, 40)
	local LILA = Color3.fromRGB(130, 70, 230)
	local KARTE = Color3.fromRGB(34, 38, 48)
	local HELL = Color3.fromRGB(190, 195, 205)

	local function zahlFormat(n)
		local t = tostring(math.floor(n or 0))
		while true do
			local neu, k = t:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
			t = neu
			if k == 0 then break end
		end
		return t
	end
	local function label(eltern, t, groesse, farbe, x, y, w, h, fett, ausrichtung)
		local l = Instance.new("TextLabel")
		l.Position = UDim2.new(x[1], x[2], y[1], y[2])
		l.Size = UDim2.new(w[1], w[2], h[1], h[2])
		l.BackgroundTransparency = 1
		l.Font = fett == 2 and Enum.Font.GothamBlack or (fett and Enum.Font.GothamBold or Enum.Font.Gotham)
		l.TextSize = groesse
		l.TextColor3 = farbe or Color3.new(1, 1, 1)
		l.TextXAlignment = ausrichtung or Enum.TextXAlignment.Left
		l.TextWrapped = true
		l.RichText = true
		l.Text = t
		l.Parent = eltern
		return l
	end
	local function taste(eltern, t, farbe, x, y, w, h, klick)
		local k = Instance.new("TextButton")
		k.Position = UDim2.new(x[1], x[2], y[1], y[2])
		k.Size = UDim2.new(w[1], w[2], h[1], h[2])
		k.BackgroundColor3 = farbe
		k.Font = Enum.Font.GothamBlack
		k.TextSize = 13
		k.TextColor3 = Color3.new(1, 1, 1)
		k.Text = t
		k.AutoButtonColor = true
		k.Parent = eltern
		Instance.new("UICorner", k)
		if klick then k.MouseButton1Click:Connect(klick) end
		return k
	end
	local function karte(eltern, hoehe, farbe, nr)
		local f = Instance.new("Frame")
		f.LayoutOrder = nr or 0
		f.Size = UDim2.new(1, -8, 0, hoehe)
		f.BackgroundColor3 = farbe or KARTE
		f.Parent = eltern
		Instance.new("UICorner", f).CornerRadius = UDim.new(0, 10)
		return f
	end
	local function balken(eltern, anteil, farbe, x, y, w)
		local hinten = Instance.new("Frame")
		hinten.Position = UDim2.new(x[1], x[2], y[1], y[2])
		hinten.Size = UDim2.new(w[1], w[2], 0, 8)
		hinten.BackgroundColor3 = Color3.fromRGB(55, 60, 75)
		hinten.Parent = eltern
		Instance.new("UICorner", hinten)
		local vorn = Instance.new("Frame")
		vorn.Size = UDim2.fromScale(math.clamp(anteil, 0, 1), 1)
		vorn.BackgroundColor3 = farbe
		vorn.Parent = hinten
		Instance.new("UICorner", vorn)
	end
	-- window that fits on phones too
	local function fenster(name, titel, farbe)
		local alt = spieler.PlayerGui:FindFirstChild(name)
		if alt then alt:Destroy() end
		local g = Instance.new("ScreenGui")
		g.Name = name
		g.ResetOnSpawn = false
		g.DisplayOrder = 14
		g.Parent = spieler.PlayerGui
		local panel = Instance.new("Frame")
		panel.AnchorPoint = Vector2.new(0.5, 0.5)
		panel.Position = UDim2.fromScale(0.5, 0.5)
		panel.Size = UDim2.fromScale(0.94, 0.86)
		panel.BackgroundColor3 = Color3.fromRGB(22, 24, 30)
		panel.Parent = g
		Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 14)
		local grenze = Instance.new("UISizeConstraint")
		grenze.MaxSize = Vector2.new(580, 560)
		grenze.Parent = panel
		local kopf = Instance.new("Frame")
		kopf.Size = UDim2.new(1, 0, 0, 50)
		kopf.BackgroundColor3 = farbe
		kopf.Parent = panel
		Instance.new("UICorner", kopf).CornerRadius = UDim.new(0, 14)
		local verlauf = Instance.new("UIGradient")
		verlauf.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170))
		verlauf.Rotation = 90
		verlauf.Parent = kopf
		label(kopf, titel, 20, nil, { 0, 16 }, { 0, 0 }, { 1, -70 }, { 1, 0 }, 2)
		taste(kopf, "X", Color3.fromRGB(40, 20, 20), { 1, -44 }, { 0, 10 }, { 0, 32 }, { 0, 30 }, function() g:Destroy() end)
		local liste = Instance.new("ScrollingFrame")
		liste.Position = UDim2.fromOffset(12, 60)
		liste.Size = UDim2.new(1, -24, 1, -70)
		liste.BackgroundTransparency = 1
		liste.BorderSizePixel = 0
		liste.ScrollBarThickness = 6
		liste.AutomaticCanvasSize = Enum.AutomaticSize.Y
		liste.CanvasSize = UDim2.new()
		liste.Parent = panel
		local l = Instance.new("UIListLayout")
		l.Padding = UDim.new(0, 10)
		l.SortOrder = Enum.SortOrder.LayoutOrder
		l.Parent = liste
		return g, liste
	end
	local function ueberschrift(liste, t, nr)
		local f = Instance.new("Frame")
		f.LayoutOrder = nr
		f.Size = UDim2.new(1, -8, 0, 24)
		f.BackgroundTransparency = 1
		f.Parent = liste
		label(f, t, 15, GOLD, { 0, 4 }, { 0, 0 }, { 1, -8 }, { 1, 0 }, 2)
	end

	-- ---------- rewards window ----------
	local belohnungZeigen
	local function abholen(eingabe)
		local r = frage("belohnungAbholen", eingabe)
		if r.fehler then hinweis(r.fehler) return end
		warnen(r.text, Color3.fromRGB(190, 130, 20))
		belohnungZeigen(r.status)
	end
	belohnungZeigen = function(info)
		local _, liste = fenster("Belohnungen", "🎁 REWARDS", Color3.fromRGB(200, 120, 30))
		local nr = 0
		local function weiter() nr += 1 return nr end
		-- daily streak
		local t = info.taeglich
		ueberschrift(liste, ("🔥 DAILY STREAK  ·  %d day%s in a row"):format(t.bereit and math.max(t.serie - 1, 0) or t.serie, (t.bereit and t.serie - 1 or t.serie) == 1 and "" or "s"), weiter())
		local k = karte(liste, 150, nil, weiter())
		for i, b in t.liste do
			local feld = Instance.new("Frame")
			feld.Position = UDim2.new((i - 1) / 7, 4, 0, 8)
			feld.Size = UDim2.new(1 / 7, -8, 0, 78)
			local heute = i == t.tag
			local erledigt = (t.bereit and i < t.tag) or (not t.bereit and i <= t.tag)
			feld.BackgroundColor3 = heute and (t.bereit and Color3.fromRGB(120, 85, 15) or Color3.fromRGB(35, 80, 50)) or (erledigt and Color3.fromRGB(35, 70, 45) or Color3.fromRGB(45, 50, 62))
			feld.Parent = k
			Instance.new("UICorner", feld)
			if heute and t.bereit then
				local r = Instance.new("UIStroke")
				r.Color = GOLD
				r.Thickness = 2
				r.Parent = feld
			end
			label(feld, "Day " .. i, 11, HELL, { 0, 0 }, { 0, 4 }, { 1, 0 }, { 0, 14 }, true, Enum.TextXAlignment.Center)
			label(feld, (b.gross and "🎁" or (erledigt and "✅" or "🪙")), 20, nil, { 0, 0 }, { 0, 20 }, { 1, 0 }, { 0, 26 }, nil, Enum.TextXAlignment.Center)
			label(feld, zahlFormat(b.geld) .. (b.xp and ("\n+" .. b.xp .. " XP") or ""), 11, Color3.new(1, 1, 1), { 0, 0 }, { 0, 46 }, { 1, 0 }, { 0, 30 }, true, Enum.TextXAlignment.Center)
		end
		if t.bereit then
			taste(k, ("CLAIM DAY %d"):format(t.tag), GRUEN, { 0, 12 }, { 0, 96 }, { 1, -24 }, { 0, 40 }, function() abholen({ art = "taeglich" }) end)
		else
			label(k, "✅ Claimed today – come back tomorrow to keep your streak! Day 7 is a big chest.", 13, HELL, { 0, 12 }, { 0, 96 }, { 1, -24 }, { 0, 40 }, true, Enum.TextXAlignment.Center)
		end
		if t.verloren then
			label(k, "Streak ended – start again today!", 11, Color3.fromRGB(255, 140, 120), { 0, 12 }, { 0, 84 }, { 1, -24 }, { 0, 12 }, true, Enum.TextXAlignment.Center)
		end
		-- playtime gifts
		local sz = info.spielzeit
		ueberschrift(liste, ("⏱ PLAYTIME GIFTS TODAY  ·  %d min played"):format(math.floor(sz.sek / 60)), weiter())
		local k2 = karte(liste, 118, nil, weiter())
		for i, g in sz.geschenke do
			local feld = Instance.new("Frame")
			feld.Position = UDim2.new((i - 1) / #sz.geschenke, 4, 0, 8)
			feld.Size = UDim2.new(1 / #sz.geschenke, -8, 1, -16)
			feld.BackgroundColor3 = g.abgeholt and Color3.fromRGB(35, 70, 45) or Color3.fromRGB(45, 50, 62)
			feld.Parent = k2
			Instance.new("UICorner", feld)
			label(feld, g.min .. " min", 12, HELL, { 0, 0 }, { 0, 4 }, { 1, 0 }, { 0, 16 }, true, Enum.TextXAlignment.Center)
			label(feld, "🪙 " .. zahlFormat(g.geld) .. (g.xp and ("\n+" .. g.xp .. " XP") or ""), 12, nil, { 0, 0 }, { 0, 22 }, { 1, 0 }, { 0, 30 }, true, Enum.TextXAlignment.Center)
			if g.abgeholt then
				label(feld, "✅", 18, nil, { 0, 0 }, { 1, -36 }, { 1, 0 }, { 0, 30 }, nil, Enum.TextXAlignment.Center)
			elseif g.bereit then
				taste(feld, "CLAIM", GRUEN, { 0, 6 }, { 1, -36 }, { 1, -12 }, { 0, 28 }, function() abholen({ art = "spielzeit", nr = g.nr }) end)
			else
				balken(feld, sz.sek / (g.min * 60), Color3.fromRGB(80, 160, 255), { 0, 8 }, { 1, -22 }, { 1, -16 })
			end
		end
		-- bonuses
		ueberschrift(liste, "🚀 YOUR BONUSES", weiter())
		local k3 = karte(liste, 96, nil, weiter())
		local zeilen = {}
		table.insert(zeilen, (spieler:GetAttribute("VIP") and "👑 VIP: 2x coins ✓" or "👑 VIP: <font color=\"#8a90a0\">not active</font>"))
		table.insert(zeilen, (spieler:GetAttribute("FreundeBonus") and "🤝 Friend online: +10 % ✓" or "🤝 Play with a friend: +10 %"))
		table.insert(zeilen, ((spieler:GetAttribute("BoostBis") or 0) > os.time() and ("⚡ 2x boost: %d min left"):format(math.ceil(((spieler:GetAttribute("BoostBis") or 0) - os.time()) / 60)) or "⚡ 2x boost: <font color=\"#8a90a0\">off</font>"))
		label(k3, table.concat(zeilen, "\n"), 13, nil, { 0, 12 }, { 0, 8 }, { 0.6, -12 }, { 1, -16 }, true)
		label(k3, ("Coins  <b>x%.1f</b>\nXP  <b>x%.1f</b>"):format(spieler:GetAttribute("GeldFaktor") or 1, spieler:GetAttribute("XpFaktor") or 1), 16, GOLD, { 0.6, 0 }, { 0, 8 }, { 0.4, -12 }, { 0, 44 }, 2, Enum.TextXAlignment.Right)
		taste(k3, "📨 INVITE FRIENDS", BLAU, { 0.6, 0 }, { 0, 56 }, { 0.4, -12 }, { 0, 32 }, function()
			pcall(function() SocialService:PromptGameInvite(spieler) end)
		end)
		if info.gruppe and not info.gruppe.abgeholt then
			local kg = karte(liste, 50, Color3.fromRGB(40, 45, 70), weiter())
			label(kg, ("👥 Join our Roblox group: <b>%s coins</b> gift"):format(zahlFormat(info.gruppe.geschenk)), 14, nil, { 0, 12 }, { 0, 0 }, { 0.65, 0 }, { 1, 0 }, true)
			taste(kg, info.gruppe.drin and "CLAIM" or "How?", info.gruppe.drin and GRUEN or GRAU, { 0.68, 0 }, { 0, 9 }, { 0.32, -12 }, { 0, 32 }, function()
				if info.gruppe.drin then abholen({ art = "gruppe" }) else hinweis("Search our group on Roblox (see the game page), join it and rejoin the game.") end
			end)
		end
		-- achievements
		ueberschrift(liste, "🏆 ACHIEVEMENTS & LICENSE CLASSES", weiter())
		table.sort(info.erfolge, function(a, b)
			local function ber(e) local s = e.stufen[e.abgeholt + 1] return s and e.wert >= s.ziel and 0 or (s and 1 or 2) end
			local ra, rb = ber(a), ber(b)
			if ra ~= rb then return ra < rb end
			return false
		end)
		for _, e in info.erfolge do
			local naechste = e.stufen[e.abgeholt + 1]
			local fertig = naechste == nil
			local bereit = naechste and e.wert >= naechste.ziel
			local ke = karte(liste, 78, bereit and Color3.fromRGB(70, 55, 20) or (fertig and Color3.fromRGB(35, 60, 45) or KARTE), weiter())
			label(ke, e.icon, 28, nil, { 0, 8 }, { 0, 0 }, { 0, 40 }, { 1, 0 }, nil, Enum.TextXAlignment.Center)
			label(ke, ("<b>%s</b>  <font color=\"#8a90a0\">%s</font>"):format(e.name, #e.stufen > 1 and ("tier %d/%d"):format(e.abgeholt, #e.stufen) or ""), 14, nil, { 0, 54 }, { 0, 6 }, { 1, -190 }, { 0, 18 })
			label(ke, e.text, 12, HELL, { 0, 54 }, { 0, 24 }, { 1, -190 }, { 0, 16 })
			if fertig then
				label(ke, "✅ Completed!", 13, Color3.fromRGB(120, 220, 140), { 0, 54 }, { 0, 46 }, { 1, -190 }, { 0, 18 }, true)
			else
				balken(ke, e.wert / naechste.ziel, bereit and GOLD or Color3.fromRGB(80, 160, 255), { 0, 54 }, { 0, 48 }, { 1, -190 })
				-- show this tier and the next ones (something to look forward to)
				local vorschau = {}
				for i = e.abgeholt + 1, math.min(#e.stufen, e.abgeholt + 3) do
					local s = e.stufen[i]
					table.insert(vorschau, ("%s: %s🪙%s"):format(zahlFormat(s.ziel), zahlFormat(s.geld), s.xp > 0 and (" +" .. s.xp .. "XP") or ""))
				end
				label(ke, ("%s / %s   ·   %s"):format(zahlFormat(math.min(e.wert, naechste.ziel)), zahlFormat(naechste.ziel), table.concat(vorschau, "  →  ")), 11, HELL, { 0, 54 }, { 0, 58 }, { 1, -70 }, { 0, 16 })
				if bereit then
					taste(ke, "CLAIM", GRUEN, { 1, -122 }, { 0, 12 }, { 0, 110 }, { 0, 34 }, function() abholen({ art = "erfolg", id = e.id }) end)
				else
					label(ke, ("🪙 %s"):format(zahlFormat(naechste.geld)), 14, GOLD, { 1, -130 }, { 0, 14 }, { 0, 118 }, { 0, 30 }, 2, Enum.TextXAlignment.Right)
				end
			end
		end
	end
	local function belohnungenOeffnen()
		local r = frage("belohnungen")
		if r.fehler then hinweis(r.fehler) return end
		belohnungZeigen(r)
	end
	_G.BelohnungenOeffnen = belohnungenOeffnen

	-- ---------- shop window ----------
	local shopZeigen
	local function kaufen(art, eintrag)
		if eintrag.bereit then
			if art == "pass" then
				MarketplaceService:PromptGamePassPurchase(spieler, eintrag.id)
			else
				MarketplaceService:PromptProductPurchase(spieler, eintrag.id)
			end
		elseif RunService:IsStudio() then
			-- not set up yet: free test purchase in Studio
			local r = frage("dev", { befehl = "kauf", key = eintrag.key })
			warnen(r.fehler or r.text, GRUEN)
			task.wait(0.3)
			local s = frage("shop")
			if not s.fehler then shopZeigen(s) end
		else
			hinweis("Coming soon!")
		end
	end
	shopZeigen = function(info)
		local _, liste = fenster("Shop", "🛒 SHOP", Color3.fromRGB(110, 60, 200))
		local nr = 0
		local function weiter() nr += 1 return nr end
		local kopf = karte(liste, 56, nil, weiter())
		label(kopf, ("🪙 <b>%s</b> coins"):format(zahlFormat(info.geld)), 18, nil, { 0, 14 }, { 0, 0 }, { 0.5, 0 }, { 1, 0 })
		label(kopf, ("Coins x%.1f  ·  XP x%.1f%s"):format(info.geldFaktor, info.xpFaktor, info.boost > 0 and ("  ·  ⚡ %d min"):format(math.ceil(info.boost / 60)) or ""), 13, GOLD, { 0.45, 0 }, { 0, 0 }, { 0.55, -14 }, { 1, 0 }, true, Enum.TextXAlignment.Right)
		local studio = RunService:IsStudio()
		local function preisText(e)
			if e.hat then return "OWNED ✓" end
			if e.bereit then return "R$ " .. e.preis end
			return studio and ("TEST · R$ " .. e.preis) or "SOON"
		end
		-- starter pack first (best offer for new players)
		for _, pr in info.produkte do
			if pr.einmal then
				local k = karte(liste, 96, LILA, weiter())
				local v = Instance.new("UIGradient")
				v.Color = ColorSequence.new(Color3.fromRGB(150, 90, 255), Color3.fromRGB(240, 120, 60))
				v.Parent = k
				label(k, "⭐ " .. pr.name:upper() .. "  <font size=\"12\">ONLY ONCE</font>", 18, nil, { 0, 14 }, { 0, 8 }, { 1, -170 }, { 0, 24 }, 2)
				label(k, pr.text, 13, nil, { 0, 14 }, { 0, 36 }, { 1, -170 }, { 0, 50 }, true)
				taste(k, preisText(pr), GRUEN, { 1, -150 }, { 0.5, -22 }, { 0, 136 }, { 0, 44 }, function() kaufen("produkt", pr) end)
			end
		end
		ueberschrift(liste, "🎟 GAME PASSES – keep forever", weiter())
		for _, pass in info.passes do
			local k = karte(liste, 84, pass.hat and Color3.fromRGB(35, 60, 45) or KARTE, weiter())
			label(k, pass.icon, 34, nil, { 0, 6 }, { 0, 0 }, { 0, 56 }, { 1, 0 }, nil, Enum.TextXAlignment.Center)
			label(k, pass.name, 16, nil, { 0, 66 }, { 0, 8 }, { 1, -220 }, { 0, 20 }, 2)
			label(k, pass.text, 12, HELL, { 0, 66 }, { 0, 30 }, { 1, -220 }, { 0, 48 })
			local b = taste(k, preisText(pass), pass.hat and GRAU or GRUEN, { 1, -146 }, { 0.5, -20 }, { 0, 134 }, { 0, 40 }, function()
				if not pass.hat then kaufen("pass", pass) end
			end)
			b.AutoButtonColor = not pass.hat
		end
		ueberschrift(liste, "🪙 COINS & BOOSTS", weiter())
		for _, pr in info.produkte do
			if not pr.einmal then
				local k = karte(liste, 56, nil, weiter())
				label(k, (pr.geld and "🪙 " or "⚡ ") .. pr.name .. (pr.tag and ("   <font color=\"#ffcf4a\" size=\"12\">" .. pr.tag .. "</font>") or ""), 16, nil, { 0, 14 }, { 0, 0 }, { 1, -170 }, { 1, 0 }, true)
				taste(k, preisText(pr), GRUEN, { 1, -146 }, { 0.5, -18 }, { 0, 134 }, { 0, 36 }, function() kaufen("produkt", pr) end)
			end
		end
		local fuss = karte(liste, 40, Color3.fromRGB(28, 30, 38), weiter())
		label(fuss, "Everything in the game can also be earned by playing. Purchases support the developer ❤", 11, HELL, { 0, 12 }, { 0, 0 }, { 1, -24 }, { 1, 0 }, nil, Enum.TextXAlignment.Center)
	end
	local function shopOeffnen()
		local r = frage("shop")
		if r.fehler then hinweis(r.fehler) return end
		shopZeigen(r)
	end
	_G.ShopOeffnen = shopOeffnen
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(_, _, gekauft)
		if gekauft then task.wait(1.5) if spieler.PlayerGui:FindFirstChild("Shop") then shopOeffnen() end end
	end)
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(_, _, gekauft)
		if gekauft then task.wait(2) if spieler.PlayerGui:FindFirstChild("Shop") then shopOeffnen() end end
	end)

	-- ---------- buttons top left ----------
	local bKnopf = leistenKnopf("🎁", "Rewards", 2)
	local punkt = Instance.new("TextLabel")
	punkt.AnchorPoint = Vector2.new(0.5, 0.5)
	punkt.Position = UDim2.new(1, -2, 0, 2)
	punkt.Size = UDim2.fromOffset(20, 20)
	punkt.BackgroundColor3 = Color3.fromRGB(230, 40, 50)
	punkt.Font = Enum.Font.GothamBlack
	punkt.TextSize = 12
	punkt.TextColor3 = Color3.new(1, 1, 1)
	punkt.Visible = false
	punkt.Parent = bKnopf
	Instance.new("UICorner", punkt).CornerRadius = UDim.new(1, 0)
	local function punktNeu()
		local n = spieler:GetAttribute("BelohnungenOffen") or 0
		punkt.Visible = n > 0
		punkt.Text = tostring(n)
	end
	spieler:GetAttributeChangedSignal("BelohnungenOffen"):Connect(punktNeu)
	punktNeu()
	bKnopf.MouseButton1Click:Connect(function()
		local g = spieler.PlayerGui:FindFirstChild("Belohnungen")
		if g then g:Destroy() return end
		belohnungenOeffnen()
	end)
	local sKnopf = leistenKnopf("🛒", "Shop", 1, Color3.fromRGB(110, 60, 200))
	sKnopf.MouseButton1Click:Connect(function()
		local g = spieler.PlayerGui:FindFirstChild("Shop")
		if g then g:Destroy() return end
		shopOeffnen()
	end)

	-- coin multiplier next to the money display (e.g. "x2.1  ⚡12:30")
	task.spawn(function()
		local geldGui = spieler.PlayerGui:WaitForChild("Geld", 10)
		local pille = geldGui and geldGui:FindFirstChildOfClass("Frame")
		if not pille then return end
		local faktor = Instance.new("TextButton")
		faktor.LayoutOrder = 3
		faktor.BackgroundColor3 = Color3.fromRGB(110, 60, 200)
		faktor.Size = UDim2.fromOffset(0, 26)
		faktor.AutomaticSize = Enum.AutomaticSize.X
		faktor.Font = Enum.Font.GothamBlack
		faktor.TextSize = 13
		faktor.TextColor3 = Color3.new(1, 1, 1)
		faktor.Text = "+"
		faktor.Parent = pille
		Instance.new("UICorner", faktor).CornerRadius = UDim.new(1, 0)
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 9), UDim.new(0, 9)
		pad.Parent = faktor
		faktor.MouseButton1Click:Connect(shopOeffnen)
		while true do
			local f = spieler:GetAttribute("GeldFaktor") or 1
			local rest = (spieler:GetAttribute("BoostBis") or 0) - os.time()
			local t = f > 1.01 and ("x%.1f"):format(f) or "+"
			if rest > 0 then t ..= ("  ⚡%d:%02d"):format(rest // 60, rest % 60) end
			faktor.Text = t
			faktor.BackgroundColor3 = f > 1.01 and Color3.fromRGB(190, 130, 20) or Color3.fromRGB(110, 60, 200)
			task.wait(1)
		end
	end)

	-- VIP tag in the chat
	pcall(function()
		local TextChatService = game:GetService("TextChatService")
		TextChatService.OnIncomingMessage = function(nachricht)
			local quelle = nachricht.TextSource
			local p = quelle and Players:GetPlayerByUserId(quelle.UserId)
			if p and p:GetAttribute("VIP") then
				local props = Instance.new("TextChatMessageProperties")
				props.PrefixText = "<font color=\"#FFD24A\">[👑 VIP]</font> " .. nachricht.PrefixText
				return props
			end
		end
	end)

	-- messages from the server
	fahrEvent.OnClientEvent:Connect(function(info)
		if info.typ == "belohnung" then
			warnen(info.text, Color3.fromRGB(190, 130, 20))
		end
	end)
	-- daily reward waiting: open the rewards window once the player is in the game (after PLAY)
	task.spawn(function()
		while not _G.ImSpiel do task.wait(0.5) end
		task.wait(2)
		local r = frage("belohnungen")
		if r.taeglich and r.taeglich.bereit and not spieler.PlayerGui:FindFirstChild("Belohnungen") then
			belohnungZeigen(r)
		end
	end)
end

-- Start screen
do
	print("[Driving School] start screen v29 loading")
	local menue = Instance.new("ScreenGui")
	menue.Name = "Startbildschirm"
	menue.IgnoreGuiInset = true
	menue.ResetOnSpawn = false
	menue.DisplayOrder = 100
	menue.Parent = spieler.PlayerGui

	local seite = Instance.new("Frame")
	seite.Size = UDim2.fromScale(0.55, 1)
	seite.BackgroundColor3 = Color3.new(0, 0, 0)
	seite.BorderSizePixel = 0
	seite.Parent = menue
	local sv = Instance.new("UIGradient")
	sv.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) })
	sv.Parent = seite

	local function label(t, y, groesse, schrift, farbe)
		local l = Instance.new("TextLabel")
		l.Position = UDim2.new(0.07, 0, y, 0)
		l.Size = UDim2.new(0.6, 0, 0, groesse + 8)
		l.BackgroundTransparency = 1
		l.Font = schrift
		l.TextSize = groesse
		l.TextColor3 = farbe
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.Text = t
		l.Parent = menue
		return l
	end
	label("DRIVING SCHOOL", 0.24, 54, Enum.Font.GothamBlack, Color3.new(1, 1, 1))
	label("Get your license. Hit the road.", 0.33, 22, Enum.Font.GothamMedium, Color3.fromRGB(255, 215, 80))

	local function grosserKnopf(t, y, farbe)
		local k = Instance.new("TextButton")
		k.Position = UDim2.new(0.07, 0, y, 0)
		k.Size = UDim2.fromOffset(260, 56)
		k.BackgroundColor3 = farbe
		k.Font = Enum.Font.GothamBlack
		k.TextSize = 24
		k.TextColor3 = Color3.new(1, 1, 1)
		k.Text = t
		k.ZIndex = 5
		k.Parent = menue
		Instance.new("UICorner", k).CornerRadius = UDim.new(0, 12)
		return k
	end
	local spielen = grosserKnopf("PLAY", 0.5, GRUEN)
	local einst = grosserKnopf("SETTINGS", 0.6, Color3.fromRGB(60, 70, 90))

	-- these are filled in further down (nothing below may block the buttons)
	local kamera = workspace.CurrentCamera
	local WOLKEN_HOEHE = 420
	local wolken, wolkenTeile, flug, steuerung = nil, {}, nil, nil
	local gestartet = false

	local andere = { "Minimap", "CameraToggle", "TestMenu", "Geld", "Admin", "Info" }
	local function andereZeigen(an)
		for _, n in andere do
			local g = spieler.PlayerGui:FindFirstChild(n)
			if g then g.Enabled = an end
		end
		if an then pcall(einstellungenAnwenden) end
	end

	einst.Activated:Connect(function()
		knoepfeAktualisieren()
		einstellGui.Enabled = true
	end)

	spielen.Activated:Connect(function()
		if gestartet then return end
		gestartet = true
		_G.ImSpiel = true
		print("[Driving School] PLAY pressed")
		menue:Destroy()                    -- the menu disappears right away
		einstellGui.Enabled = false
		if flug then flug:Disconnect() end

		-- fly down through the clouds to the character
		local ok, fehler = pcall(function()
			local char = spieler.Character or spieler.CharacterAdded:Wait()
			local wurzel = char:WaitForChild("HumanoidRootPart", 10)
			if not wurzel then return end
			local start = kamera.CFrame
			local dauer = 3.2
			local t0 = os.clock()
			while true do
				local t = math.min((os.clock() - t0) / dauer, 1)
				local weich = 1 - (1 - t) ^ 3
				local ziel = CFrame.lookAt((wurzel.CFrame * CFrame.new(0, 5, 14)).Position, wurzel.Position + Vector3.new(0, 2, 0))
				kamera.CameraType = Enum.CameraType.Scriptable
				kamera.CFrame = start:Lerp(ziel, weich)
				local nebel = math.clamp((kamera.CFrame.Position.Y - 80) / (WOLKEN_HOEHE - 80), 0, 1)
				for _, w in wolkenTeile do
					w.Transparency = 1 - 0.92 * nebel
				end
				if t >= 1 then break end
				RunService.RenderStepped:Wait()
			end
		end)
		if not ok then warn("[Driving School] camera flight failed: " .. tostring(fehler)) end
		if wolken then wolken:Destroy() end

		pcall(function()
			local char = spieler.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			kamera.CameraType = Enum.CameraType.Custom
			if hum then kamera.CameraSubject = hum end
		end)
		if steuerung then pcall(function() steuerung:Enable() end) end
		andereZeigen(true)
		if _G.Einstellungen.ersteP then pcall(perspektive, true) end
	end)

	-- hide the other buttons while the menu is open
	task.defer(andereZeigen, false)

	-- block walking while in the menu (never wait forever for the PlayerModule)
	task.spawn(function()
		local skripte = spieler:WaitForChild("PlayerScripts", 5)
		local modul = skripte and skripte:WaitForChild("PlayerModule", 5)
		if modul and not gestartet then
			pcall(function()
				steuerung = require(modul):GetControls()
				steuerung:Disable()
			end)
		end
	end)

	-- above the clouds: a sea of cloud puffs (only on this player's screen)
	pcall(function()
		wolken = Instance.new("Folder")
		wolken.Name = "Menuewolken"
		local zufall = Random.new(7)
		for _ = 1, 140 do
			local mittelpunkt = Vector3.new(zufall:NextNumber(-900, 900), WOLKEN_HOEHE + zufall:NextNumber(-12, 12), zufall:NextNumber(-900, 900))
			for _ = 1, zufall:NextInteger(3, 6) do
				local r = zufall:NextNumber(45, 110)
				local puff = Instance.new("Part")
				puff.Shape = Enum.PartType.Ball
				puff.Size = Vector3.new(r, r, r)
				puff.Position = mittelpunkt + Vector3.new(zufall:NextNumber(-60, 60), zufall:NextNumber(-10, 12), zufall:NextNumber(-60, 60))
				puff.Anchored = true
				puff.CanCollide = false
				puff.CanQuery = false
				puff.CanTouch = false
				puff.CastShadow = false
				puff.Material = Enum.Material.SmoothPlastic
				puff.Color = Color3.fromRGB(255, 255, 255)
				puff.Transparency = 0.08
				puff.Parent = wolken
				table.insert(wolkenTeile, puff)
			end
		end
		wolken.Parent = workspace
	end)
	if gestartet and wolken then wolken:Destroy() end

	local himmelStart = os.clock()
	if not gestartet then
		flug = RunService.RenderStepped:Connect(function()
			local t = os.clock() - himmelStart
			local auge = Vector3.new(-300 + t * 6, WOLKEN_HOEHE + 75, 200)
			kamera.CameraType = Enum.CameraType.Scriptable
			kamera.CFrame = CFrame.lookAt(auge, auge + Vector3.new(1, -0.18, -0.35))
		end)
	end

	-- load the saved settings
	task.spawn(function()
		local r = frage("status")
		if r.status and type(r.status.einstellungen) == "table" then
			for k, v in r.status.einstellungen do
				if _G.Einstellungen[k] ~= nil and type(v) == "boolean" then _G.Einstellungen[k] = v end
			end
		end
		if _G.SparmodusAuto then _G.SparmodusAuto() end
		knoepfeAktualisieren()
	end)
	print("[Driving School] start screen ready")
end
]=====])

-- Allow zooming into first person
local SP = game:GetService("StarterPlayer")
SP.CameraMinZoomDistance = 0.5
SP.CameraMaxZoomDistance = 60

print("License system v29 installed. Press F5 to test.")
