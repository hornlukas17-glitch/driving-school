-- Driving School: fehlende Servicestation (Tanken, Werkstatt, Taxistand) + Tankstelle West in die bestehende Karte bauen.
-- Teil aus karte/stadt_generator.lua, mit denselben Hilfsfunktionen.
local karte = workspace.Karte
if karte:FindFirstChild("Service") then print("Service gibt es schon") return end
local V = Vector3.new
local RGB = Color3.fromRGB
local M = Enum.Material
local Y_STRASSE = 0.2
local Y_MARK = 0.27
local ASPHALT = RGB(45, 45, 48)
local WEISS = RGB(235, 235, 235)
local belegt = {}
local function ordner(name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = karte
	return f
end
local fMark = karte:FindFirstChild("Markierungen") or ordner("Markierungen")
local function teil(name, groesse, lage, farbe, material, parent, keineKollision, klasse)
	local p = Instance.new(klasse or "Part")
	p.Name = name
	p.Anchored = true
	p.Size = groesse
	p.CFrame = (typeof(lage) == "Vector3") and CFrame.new(lage) or lage
	p.Color = farbe
	p.Material = material or M.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if keineKollision then
		p.CanCollide = false
		p.CastShadow = false
	end
	p.Parent = parent
	return p
end
local function modell(name, parent)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end
local function linie(x, z, sx, sz, farbe)
	teil("Markierung", V(sx, 0.06, sz), V(x, Y_MARK, z), farbe or WEISS, M.SmoothPlastic, fMark, true)
end
-- Bäume, die auf den neuen Flächen stehen, kommen weg
local weg = 0
for _, bereich in { { 330, 416, -100, -8 }, { -848, -790, -207, -113 } } do
	for _, b in (karte:FindFirstChild("Baeume") and karte.Baeume:GetChildren() or {}) do
		local p = b:GetPivot().Position
		if p.X > bereich[1] and p.X < bereich[2] and p.Z > bereich[3] and p.Z < bereich[4] then b:Destroy() weg += 1 end
	end
end
-- ---------- Tankstellen, Werkstatt und Taxistand ----------
local fService = ordner("Service")
local function schriftTeil(teilchen, gesicht, text, farbe)
	local g = Instance.new("SurfaceGui")
	g.Face = gesicht
	g.Parent = teilchen
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Text = text
	l.Font = Enum.Font.GothamBlack
	l.TextScaled = true
	l.TextColor3 = farbe
	l.Parent = g
end
-- Tankstelle: Dach auf Stuetzen, Zapfsaeulen (mitte = Mitte unter dem Dach)
local function tankstelle(m, mx, mz, saeulenX)
	teil("Tankdach", V(34, 1.2, 22), V(mx, 10.6, mz), RGB(240, 240, 240), M.SmoothPlastic, m)
	local blende = teil("Tankdachblende", V(34.4, 1.6, 22.4), V(mx, 9.9, mz), RGB(30, 110, 60), M.SmoothPlastic, m, true)
	blende.Transparency = 0
	for _, dx in { -15, 15 } do
		for _, dz in { -9, 9 } do
			teil("Tankstuetze", V(1, 10, 1), V(mx + dx, 5, mz + dz), RGB(220, 220, 220), M.Metal, m)
		end
	end
	for _, dx in { -15, 0, 15 } do
		local lampe = teil("Tanklicht", V(6, 0.3, 2), V(mx + dx, 9.85, mz), RGB(255, 250, 240), M.Neon, m, true)
		local licht = Instance.new("PointLight")
		licht.Range = 20
		licht.Brightness = 1.2
		licht.Parent = lampe
	end
	for _, sx in saeulenX do
		teil("Zapfinsel", V(3.5, 0.6, 12), V(mx + sx, 0.5, mz), RGB(200, 200, 200), M.Concrete, m)
		for _, dz in { -3, 3 } do
			local z = teil("Zapfsaeule", V(2, 4.4, 1.4), V(mx + sx, 3, mz + dz), RGB(30, 110, 60), M.SmoothPlastic, m)
			local anzeige = teil("Zapfanzeige", V(2.05, 1, 1.45), V(mx + sx, 4.2, mz + dz), RGB(20, 20, 25), M.Glass, m, true)
			schriftTeil(anzeige, Enum.NormalId.Left, "⛽ FUEL", RGB(120, 255, 140))
			schriftTeil(anzeige, Enum.NormalId.Right, "⛽ FUEL", RGB(120, 255, 140))
			z:SetAttribute("Zapfsaeule", true)
		end
	end
end

-- Servicestation an der Landstrasse (zwischen Stadt und Siedlung): Tanken, Werkstatt, Taxi
do
	local m = modell("Servicestation", fService)
	teil("Tankstellenplatz", V(76, 1, 86), V(374, Y_STRASSE - 0.5, -53), ASPHALT, M.Asphalt, m)
	tankstelle(m, 356, -40, { -6, 6 })
	-- Shop
	teil("Shop", V(18, 9, 12), V(357, 4.5, -84), RGB(245, 245, 240), M.SmoothPlastic, m)
	local shopglas = teil("Shopglas", V(16, 6, 0.3), V(357, 4, -77.9), RGB(150, 190, 215), M.Glass, m, true)
	shopglas.Transparency = 0.4
	local shopschild = teil("Shopschild", V(18, 2.4, 0.4), V(357, 10.2, -77.8), RGB(30, 110, 60), M.SmoothPlastic, m)
	schriftTeil(shopschild, Enum.NormalId.Back, "SHOP · SNACKS · COFFEE", RGB(255, 255, 255))
	-- Werkstatt mit zwei offenen Toren nach Sueden
	local WX, WZ = 396, -72
	teil("Werkstattboden", V(30, 0.4, 24), V(WX, 0.4, WZ), RGB(120, 122, 128), M.Concrete, m)
	teil("Werkstattwand", V(30, 12, 1), V(WX, 6, WZ - 12), RGB(70, 80, 95), M.Metal, m)
	teil("Werkstattwand", V(1, 12, 24), V(WX - 15, 6, WZ), RGB(70, 80, 95), M.Metal, m)
	teil("Werkstattwand", V(1, 12, 24), V(WX + 15, 6, WZ), RGB(70, 80, 95), M.Metal, m)
	teil("Werkstattwand", V(2, 12, 1), V(WX, 6, WZ + 12), RGB(70, 80, 95), M.Metal, m)
	teil("Werkstattdach", V(32, 1, 26), V(WX, 12.5, WZ), RGB(45, 50, 60), M.Metal, m)
	local wschild = teil("Werkstattschild", V(28, 3, 0.4), V(WX, 10.3, WZ + 12.6), RGB(230, 120, 30), M.SmoothPlastic, m)
	schriftTeil(wschild, Enum.NormalId.Back, "🔧 BEN'S GARAGE · REPAIR · TUNING", RGB(255, 255, 255))
	for _, dx in { -7.5, 7.5 } do
		teil("Hebebuehne", V(9, 0.4, 14), V(WX + dx, 0.8, WZ), RGB(200, 160, 30), M.Metal, m)
		teil("Hebesaeule", V(1, 6, 1), V(WX + dx - 5, 3, WZ - 6), RGB(200, 160, 30), M.Metal, m)
	end
	teil("Werkbank", V(10, 3.5, 2.5), V(WX - 7, 1.75, WZ - 10.5), RGB(150, 40, 40), M.Metal, m)
	teil("Reifenstapel", V(3, 4, 3), V(WX + 12, 2, WZ - 9), RGB(25, 25, 25), M.SmoothPlastic, m)
	local platz = teil("MechanikerPlatz", V(2, 1, 2), CFrame.new(WX - 10, 0.7, WZ + 15), RGB(255, 0, 0), M.SmoothPlastic, m, true)
	platz.Transparency = 1
	platz.CanQuery = false
	-- Taxistand
	local taxi = Instance.new("Folder")
	taxi.Name = "TaxiBuchten"
	taxi.Parent = m
	for i, x in { 383, 395, 407 } do
		local pos = V(x, Y_STRASSE, -28)
		local b = teil("Taxiplatz", V(10, 1, 18), CFrame.lookAt(pos, pos + V(0, 0, 1)), RGB(255, 255, 0), M.SmoothPlastic, taxi, true)
		b.Transparency = 1
		b.CanQuery = false
		b.CanTouch = false
		linie(x - 6, -28, 0.4, 18, RGB(250, 200, 30))
		if i == 3 then linie(x + 6, -28, 0.4, 18, RGB(250, 200, 30)) end
	end
	local taxischild = teil("Taxischild", V(1, 3, 6), V(377, 6.5, -42), RGB(250, 200, 30), M.SmoothPlastic, m)
	schriftTeil(taxischild, Enum.NormalId.Left, "🚕 TAXI", RGB(20, 20, 20))
	schriftTeil(taxischild, Enum.NormalId.Right, "🚕 TAXI", RGB(20, 20, 20))
	teil("Taxischildmast", V(0.5, 5, 0.5), V(377, 2.5, -42), RGB(90, 90, 95), M.Metal, m)
	taxischild:SetAttribute("TaxiStand", true)
	-- Preisschild an der Strasse
	teil("Preismast", V(1, 14, 1), V(340, 7, -14), RGB(60, 62, 66), M.Metal, m)
	local preis = teil("Preisschild", V(1, 6, 8), V(340, 15, -14), RGB(30, 110, 60), M.SmoothPlastic, m)
	schriftTeil(preis, Enum.NormalId.Left, "⛽ FUEL\n1.5 / %", RGB(255, 255, 255))
	schriftTeil(preis, Enum.NormalId.Right, "⛽ FUEL\n1.5 / %", RGB(255, 255, 255))
	table.insert(belegt, { 330, 416, -100, -8 })
end

-- zweite Tankstelle an der Westzufahrt
do
	local m = modell("TankstelleWest", fService)
	teil("Tankstellenplatz", V(54, 1, 90), V(-819, Y_STRASSE - 0.5, -160), ASPHALT, M.Asphalt, m)
	tankstelle(m, -817, -160, { -6, 6 })
	teil("Kiosk", V(10, 8, 10), V(-838, 4, -195), RGB(245, 245, 240), M.SmoothPlastic, m)
	local k = teil("Kioskschild", V(0.4, 2, 9), V(-832.8, 7, -195), RGB(30, 110, 60), M.SmoothPlastic, m)
	schriftTeil(k, Enum.NormalId.Right, "⛽ FUEL", RGB(255, 255, 255))
	table.insert(belegt, { -848, -790, -207, -113 })
end


print("Servicestation + Tankstelle West gebaut, Bäume entfernt: " .. weg)
