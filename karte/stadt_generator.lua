-- =====================================================================
--  KARTEN-GENERATOR  (einmal in der Befehlsleiste ausfuehren)
--  Baut: Stadt mit Fenstern/Tueren, Zebrastreifen, Ampeln (funktionieren),
--  Laternen, Muelleimer, Hydranten, Park, Landstrasse, zwei ummauerte
--  Wohnsiedlungen mit begehbarer Driving School (Tuer mit E),
--  Schnellstrasse, Wiese und Baeume.
--  Erneut ausfuehren = alte Karte wird geloescht und neu gebaut.
-- =====================================================================

-- ---------- Aufraeumen ----------
for _, name in { "Karte", "Stadt", "Baseplate" } do
	local alt = workspace:FindFirstChild(name)
	if alt then alt:Destroy() end
end
local SSS = game:GetService("ServerScriptService")
for _, name in { "AmpelSteuerung", "FahrschulTuer" } do
	local altSkript = SSS:FindFirstChild(name)
	if altSkript then altSkript:Destroy() end
end

-- ---------- Einstellungen ----------
local KARTE = 850            -- Karte geht von -850 bis +850
local GRID = 6               -- Haeuserbloecke pro Seite
local BLOCK = 80             -- Groesse eines Blocks
local STR = 24               -- Strassenbreite in der Stadt
local ABST = BLOCK + STR
local GESAMT = GRID * ABST + STR
local START = -GESAMT / 2    -- Stadtrand (-324)
local Y_STRASSE = 0.2        -- Oberkante Asphalt
local Y_GEHWEG = 1.2         -- Oberkante Gehweg
local Y_MARK = 0.27          -- Hoehe Fahrbahnmarkierung (knapp ueber dem Asphalt)
local HZ = -520              -- Lage der Schnellstrasse
local HB = 40                -- Breite der Schnellstrasse

local V = Vector3.new
local RGB = Color3.fromRGB
local M = Enum.Material

local ASPHALT = RGB(45, 45, 48)
local WEISS = RGB(235, 235, 235)
local GEHWEG = RGB(165, 165, 165)
local GLAS = RGB(80, 120, 160)
local METALL = RGB(60, 62, 66)

local FASSADEN = {
	RGB(225, 215, 195), RGB(200, 120, 90), RGB(170, 190, 175), RGB(235, 225, 160),
	RGB(160, 185, 210), RGB(130, 135, 145), RGB(240, 240, 235), RGB(165, 80, 65),
	RGB(210, 170, 130), RGB(110, 130, 150), RGB(190, 160, 190), RGB(150, 170, 120),
}
local MATS = { M.Concrete, M.Brick, M.SmoothPlastic, M.Concrete }
local HAUSFARBEN = { RGB(245, 235, 210), RGB(240, 240, 240), RGB(220, 230, 240), RGB(250, 225, 200), RGB(225, 240, 215) }
local DACHFARBEN = { RGB(150, 60, 45), RGB(70, 70, 75), RGB(120, 75, 55) }

-- ---------- Grundstruktur ----------
local karte = Instance.new("Model")
karte.Name = "Karte"

local function ordner(name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = karte
	return f
end
local fBoden = ordner("Boden")
local fStrassen = ordner("Strassen")
local fMark = ordner("Markierungen")
local fGebaeude = ordner("Gebaeude")
local fAmpeln = ordner("Ampeln")
local fStopp = ordner("Stoppschilder")
local fDeko = ordner("Deko")
local fVorstadt = ordner("Vorstadt")
local fBaeume = ordner("Baeume")

local anzahl = 0

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
	anzahl += 1
	return p
end

local function modell(name, parent)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function dunkler(c, f)
	return c:Lerp(Color3.new(0, 0, 0), f or 0.35)
end

local function zufall(liste)
	return liste[math.random(1, #liste)]
end

-- Hilfen fuer Mittelpunkte
local function strassenMitte(k) return START + STR / 2 + k * ABST end   -- -312 ... 312
local function blockMitte(i) return START + STR + BLOCK / 2 + i * ABST end -- -260 ... 260

-- ---------- Strassen & Markierungen ----------
local belegt = {} -- Strassenflaechen, damit keine Baeume darauf wachsen
local function strasse(name, x1, z1, x2, z2, breite)
	local sx = (x1 == x2) and breite or math.abs(x2 - x1)
	local sz = (z1 == z2) and breite or math.abs(z2 - z1)
	local mx, mz = (x1 + x2) / 2, (z1 + z2) / 2
	table.insert(belegt, { mx - sx / 2, mx + sx / 2, mz - sz / 2, mz + sz / 2 })
	teil(name, V(sx, 1, sz), V((x1 + x2) / 2, Y_STRASSE - 0.5, (z1 + z2) / 2), ASPHALT, M.Asphalt, fStrassen)
end

local function linie(x, z, sx, sz, farbe)
	teil("Markierung", V(sx, 0.06, sz), V(x, Y_MARK, z), farbe or WEISS, M.SmoothPlastic, fMark, true)
end

local function gestrichelt(x1, z1, x2, z2, strich, luecke)
	local senkrecht = (x1 == x2)
	local laenge = senkrecht and math.abs(z2 - z1) or math.abs(x2 - x1)
	local schritt = strich + luecke
	local n = math.floor((laenge + luecke) / schritt)
	if n < 1 then return end
	local rest = laenge - (n * schritt - luecke)
	for k = 0, n - 1 do
		local t = rest / 2 + strich / 2 + k * schritt
		if senkrecht then
			linie(x1, math.min(z1, z2) + t, 0.5, strich)
		else
			linie(math.min(x1, x2) + t, z1, strich, 0.5)
		end
	end
end

-- Wiese ueber die ganze Karte
teil("Wiese", V(KARTE * 2, 1, KARTE * 2), V(0, -0.5, 0), RGB(90, 150, 70), M.Grass, fBoden)

-- Asphalt der Stadt
teil("Stadtasphalt", V(GESAMT, 1, GESAMT), V(0, Y_STRASSE - 0.5, 0), ASPHALT, M.Asphalt, fStrassen)

-- Mittellinien in der Stadt
for k = 0, GRID do
	local s = strassenMitte(k)
	for m = 0, GRID - 1 do
		local a = strassenMitte(m) + 22
		local b = strassenMitte(m + 1) - 22
		gestrichelt(a, s, b, s, 6, 6)   -- Strasse in X-Richtung
		gestrichelt(s, a, s, b, 6, 6)   -- Strasse in Z-Richtung
	end
end

local RICHTUNGEN = { V(1, 0, 0), V(-1, 0, 0), V(0, 0, 1), V(0, 0, -1) }

-- Zebrastreifen an allen inneren Kreuzungen
for a = 1, GRID - 1 do
	for b = 1, GRID - 1 do
		local cx, cz = strassenMitte(a), strassenMitte(b)
		for _, d in RICHTUNGEN do
			for o = -10, 10, 4 do
				if d.X ~= 0 then
					linie(cx + d.X * 15.5, cz + o, 6, 2)
				else
					linie(cx + o, cz + d.Z * 15.5, 2, 6)
				end
			end
		end
	end
end

-- ---------- Ampeln ----------
local AUS = RGB(30, 30, 30)

local function ampel(cx, cz, d)
	local rechts = V(d.Z, 0, -d.X)          -- rechte Seite des ankommenden Autos
	local basis = V(cx, 0, cz) + d * 14 + rechts * 14
	local m = Instance.new("Model")
	m.Name = "Ampel"
	m:SetAttribute("Richtung", d.X ~= 0 and "EW" or "NS")
	m:SetAttribute("Phase", "Rot")
	teil("Mast", V(0.8, 13, 0.8), basis + V(0, Y_GEHWEG + 6.5, 0), METALL, M.Metal, m)
	local kopfPos = basis + V(0, Y_GEHWEG + 11, 0)
	local kopf = CFrame.lookAt(kopfPos, kopfPos + d)
	teil("Gehaeuse", V(2.2, 6.6, 1.4), kopf, RGB(20, 20, 20), M.SmoothPlastic, m)
	for _, lampe in { { "Rot", 2.1 }, { "Gelb", 0 }, { "Gruen", -2.1 } } do
		local l = teil(lampe[1], V(1.6, 1.6, 1.6), kopf * CFrame.new(0, lampe[2], -0.6), AUS, M.SmoothPlastic, m, true)
		l.Shape = Enum.PartType.Ball
	end
	m.Parent = fAmpeln
	-- Haltelinie auf der rechten Fahrspur
	local hl = V(cx, 0, cz) + d * 20.5 + rechts * 6
	m:SetAttribute("Haltelinie", hl)
	m:SetAttribute("Anfahrt", d)
	m:SetAttribute("Rechts", rechts)
	if d.X ~= 0 then
		linie(hl.X, hl.Z, 1, 11)
	else
		linie(hl.X, hl.Z, 11, 1)
	end
end

for a = 2, 4 do
	for b = 2, 4 do
		for _, d in RICHTUNGEN do
			ampel(strassenMitte(a), strassenMitte(b), d)
		end
	end
end

-- ---------- Verkehrszeichen: STOP, Vorfahrt gewaehren, Vorfahrtstrasse ----------
-- cx/cz = Kreuzungsmitte, d = Richtung, aus der die Autos kommen
local fRvL = ordner("RechtsVorLinks") -- Kreuzungen ohne Schilder (rechts vor links)

-- gleichschenkliges Dreieck aus zwei Keilen in der Schildebene (Spitze oben), Vorderseite = +X
local function dreieck(m, cfMitte, breite, hoehe, farbe, vor)
	for _, s in { 1, -1 } do
		local lage = cfMitte * CFrame.new(vor or 0, 0, -s * breite / 4)
		if s == -1 then lage = lage * CFrame.Angles(0, math.pi, 0) end
		local w = teil("Schild", V(0.1, hoehe, breite / 2), lage, farbe, M.SmoothPlastic, m, true, "WedgePart")
		w.CastShadow = false
	end
end

local function zeichen(art, cx, cz, d, schildVor, schildSeite, linieVor, spurMitte, spurBreite, bodenY)
	local rechts = V(d.Z, 0, -d.X)
	local m = Instance.new("Model")
	m.Name = (art == "stop" and "Stoppschild") or (art == "vorfahrtGewaehren" and "VorfahrtGewaehren") or "Vorfahrtstrasse"
	local fuss = V(cx, 0, cz) + d * schildVor + rechts * schildSeite
	teil("Pfosten", V(0.4, 7, 0.4), fuss + V(0, bodenY + 3.5, 0), RGB(170, 170, 175), M.Metal, m)
	local mitte = fuss + V(0, bodenY + 7.6, 0)
	local cf = CFrame.lookAt(mitte, mitte + d) * CFrame.Angles(0, math.rad(90), 0) -- Schildseite (+X) zeigt zu den Autos
	local hl = V(cx, 0, cz) + d * linieVor + rechts * spurMitte

	if art == "stop" then
		m:SetAttribute("Typ", "Stop")
		-- Achteck aus vier gedrehten Rechtecken (weisser Rand dahinter)
		local schild
		for i, winkel in { 0, 45, 90, 135 } do
			local dreh = CFrame.Angles(math.rad(winkel), 0, 0)
			local r = teil("Rand", V(0.12, 3.5 * 0.4142, 3.5), cf * dreh, RGB(255, 255, 255), M.SmoothPlastic, m)
			r.CastShadow = false
			local t = teil("Schild", V(0.16, 3.1 * 0.4142, 3.1), cf * CFrame.new(0.04, 0, 0) * dreh, RGB(195, 20, 25), M.SmoothPlastic, m)
			t.Reflectance = 0.1
			if i == 1 then schild = t end
		end
		teil("Rueckseite", V(0.1, 2.6, 2.6), cf * CFrame.new(-0.1, 0, 0), RGB(150, 150, 155), M.Metal, m)
		local g = Instance.new("SurfaceGui")
		g.Face = Enum.NormalId.Right
		g.Parent = schild
		local l = Instance.new("TextLabel")
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Position = UDim2.fromScale(0.5, 0.5)
		l.Size = UDim2.fromScale(0.85, 0.85)
		l.BackgroundTransparency = 1
		l.Text = "STOP"
		l.Font = Enum.Font.GothamBlack
		l.TextScaled = true
		l.TextColor3 = RGB(255, 255, 255)
		l.Parent = g
		if d.X ~= 0 then linie(hl.X, hl.Z, 1, spurBreite) else linie(hl.X, hl.Z, spurBreite, 1) end
	elseif art == "vorfahrtGewaehren" then
		m:SetAttribute("Typ", "Vorfahrt gewaehren")
		-- rotes Dreieck mit der Spitze nach unten, innen weiss
		local unten = cf * CFrame.Angles(math.pi, 0, 0)
		dreieck(m, unten, 3.8, 3.3, RGB(195, 20, 25), 0)
		dreieck(m, unten * CFrame.new(0, -0.175, 0), 2.6, 2.25, RGB(255, 255, 255), 0.06)
		-- Wartelinie: unterbrochene breite Linie
		local quer = V(-rechts.X, 0, -rechts.Z)
		for k = -2, 2 do
			local p = hl + rechts * (k * spurBreite / 5)
			if d.X ~= 0 then linie(p.X, p.Z, 0.9, spurBreite / 5 * 0.55) else linie(p.X, p.Z, spurBreite / 5 * 0.55, 0.9) end
		end
	else
		-- Vorfahrtstrasse: gelbe Raute mit weissem Rand
		local raute = cf * CFrame.Angles(math.rad(45), 0, 0)
		teil("Rand", V(0.1, 2.5, 2.5), raute, RGB(255, 255, 255), M.SmoothPlastic, m, true)
		teil("Schild", V(0.14, 1.7, 1.7), raute * CFrame.new(0.03, 0, 0), RGB(250, 195, 20), M.SmoothPlastic, m, true)
		teil("Rueckseite", V(0.08, 2.0, 2.0), raute * CFrame.new(-0.07, 0, 0), RGB(150, 150, 155), M.Metal, m, true)
	end
	if art ~= "vorfahrt" then
		m:SetAttribute("Haltelinie", hl)
		m:SetAttribute("Anfahrt", d)
		m:SetAttribute("Rechts", rechts)
	end
	m.Parent = fStopp
end

local function stoppschild(cx, cz, d, ...)
	zeichen("stop", cx, cz, d, ...)
end

-- Kreuzung ohne Schilder: rechts vor links
local function rechtsVorLinks(cx, cz)
	local k = teil("Kreuzung", V(2, 1, 2), V(cx, 0.2, cz), RGB(255, 255, 255), M.SmoothPlastic, fRvL, true)
	k.Transparency = 1
	k.CanQuery = false
	k.CanTouch = false
end

-- ---------- Blitzer (Radarfallen) ----------
-- messen in beide Richtungen am Messpunkt (Strassenmitte); der Server prueft das Tempo
local fBlitzer = ordner("Blitzer")
local function blitzer(mx, mz, seite, halb, bodenY)
	local m = Instance.new("Model")
	m.Name = "Blitzer"
	m:SetAttribute("Messpunkt", V(mx, 0, mz))
	local fuss = V(mx, 0, mz) + seite * (halb + 2.5)
	local blick = -seite -- the camera looks across the road
	teil("Pfosten", V(0.7, 7, 0.7), fuss + V(0, bodenY + 3.5, 0), RGB(140, 140, 145), M.Metal, m)
	local kopf = CFrame.lookAt(fuss + V(0, bodenY + 8, 0), fuss + V(0, bodenY + 8, 0) + blick)
	teil("Gehaeuse", V(1.8, 3.4, 2.4), kopf, RGB(210, 210, 215), M.Metal, m)
	teil("Streifen", V(1.85, 0.5, 2.45), kopf * CFrame.new(0, 1.2, 0), RGB(230, 120, 20), M.SmoothPlastic, m, true)
	local linse = teil("Linse", V(1.2, 1.2, 0.2), kopf * CFrame.new(0, -0.5, -1.25), RGB(20, 20, 25), M.Glass, m, true)
	linse.Reflectance = 0.4
	teil("Blitz", V(1.2, 0.8, 0.2), kopf * CFrame.new(0, 0.7, -1.25), RGB(60, 60, 60), M.SmoothPlastic, m, true)
	m.Parent = fBlitzer
end
blitzer(-345, 0, V(0, 0, -1), 10, 0)             -- Landstrasse West vor der Stadt
blitzer(0, -160, V(1, 0, 0), 12, Y_GEHWEG)       -- Stadt, Nord-Sued-Achse
blitzer(-300, HZ, V(0, 0, 1), HB / 2, 0)         -- Schnellstrasse
blitzer(321, 600, V(0, 0, -1), 10, 0)            -- Suedring
blitzer(-510, -208, V(0, 0, 1), 9, 0)            -- 30er Wohnstrasse
blitzer(-780, -250, V(1, 0, 0), 10, 0)           -- Westzufahrt

-- Stadt: Kreuzungen ohne Ampel -> gemischt: STOP, Vorfahrt gewaehren oder rechts vor links.
-- Bei STOP und Vorfahrt gewaehren hat die Ost-West-Strasse Vorfahrt (gelbe Raute).
for a = 1, GRID - 1 do
	for b = 1, GRID - 1 do
		local mitAmpel = a >= 2 and a <= 4 and b >= 2 and b <= 4
		if not mitAmpel then
			local art
			if a == 5 and b == 2 then
				art = "stop"                                   -- Fahrstunde 1 haelt hier
			elseif b == 3 then
				art = (a == 1) and "vorfahrtGewaehren" or "stop" -- Kreuzungen mit der Landstrasse
			else
				art = ({ "stop", "vorfahrtGewaehren", "rvl" })[(a * 2 + b) % 3 + 1]
			end
			local cx, cz = strassenMitte(a), strassenMitte(b)
			if art == "rvl" then
				rechtsVorLinks(cx, cz)
			else
				for _, d in { V(0, 0, 1), V(0, 0, -1) } do
					zeichen(art, cx, cz, d, 15, 14, 20.5, 6, 11, Y_GEHWEG)
				end
				for _, d in { V(1, 0, 0), V(-1, 0, 0) } do
					zeichen("vorfahrt", cx, cz, d, 15, 14, 20.5, 6, 11, Y_GEHWEG)
				end
			end
		end
	end
end

-- ---------- Stadtmoebel ----------
local function laterne(x, z, n, bodenY)
	local m = modell("Laterne", fDeko)
	local y = bodenY or Y_GEHWEG
	teil("Mast", V(0.6, 14, 0.6), V(x, y + 7, z), METALL, M.Metal, m)
	local armGr = (n.X ~= 0) and V(4, 0.4, 0.4) or V(0.4, 0.4, 4)
	teil("Arm", armGr, V(x, y + 13.6, z) + n * 2, METALL, M.Metal, m)
	local kopf = teil("Leuchte", V(2.2, 0.6, 2.2), V(x, y + 13.1, z) + n * 3.8, RGB(255, 230, 170), M.Neon, m, true)
	local licht = Instance.new("PointLight")
	licht.Range = 24
	licht.Brightness = 1.2
	licht.Color = RGB(255, 220, 160)
	licht.Shadows = false
	licht.Parent = kopf
end

local function muelleimer(x, z)
	local m = modell("Muelleimer", fDeko)
	teil("Behaelter", V(1.6, 2.6, 1.6), V(x, Y_GEHWEG + 1.3, z), RGB(60, 90, 60), M.Metal, m)
	teil("Deckel", V(1.8, 0.3, 1.8), V(x, Y_GEHWEG + 2.75, z), RGB(40, 40, 40), M.Metal, m)
end

local function hydrant(x, z)
	local m = modell("Hydrant", fDeko)
	local rot = RGB(200, 30, 30)
	teil("Koerper", V(1, 2.4, 1), V(x, Y_GEHWEG + 1.2, z), rot, M.Metal, m)
	teil("Kappe", V(1.3, 0.5, 1.3), V(x, Y_GEHWEG + 2.65, z), rot, M.Metal, m)
	teil("Anschluss", V(2, 0.5, 0.5), V(x, Y_GEHWEG + 1.7, z), RGB(180, 180, 180), M.Metal, m)
end

local function baum(x, z, parent, bodenY)
	local m = modell("Baum", parent or fBaeume)
	local y = bodenY or 0
	local h = math.random(7, 10)
	teil("Stamm", V(1.8, h * 0.6, 1.8), V(x, y + h * 0.3, z), RGB(95, 66, 42), M.Wood, m)
	teil("Stamm", V(1.2, h * 0.5, 1.2), V(x, y + h * 0.75, z), RGB(105, 74, 48), M.Wood, m)
	local r = math.random(9, 13)
	local gruen = RGB(math.random(45, 75), math.random(115, 150), math.random(35, 55))
	local mitte = V(x, y + h + r * 0.25, z)
	local krone = teil("Krone", V(r, r * 0.9, r), mitte, gruen, M.Grass, m)
	krone.Shape = Enum.PartType.Ball
	-- weitere Blaetterbuesche fuer eine unregelmaessige, volle Krone
	for i = 1, 3 do
		local w = math.rad(i * 120 + math.random(-25, 25))
		local rr = r * (0.55 + math.random() * 0.2)
		local versatz = V(math.cos(w) * r * 0.35, (math.random() - 0.3) * r * 0.35, math.sin(w) * r * 0.35)
		local f = gruen:Lerp(RGB(90, 160, 60), math.random() * 0.35)
		local busch = teil("Krone", V(rr, rr, rr), mitte + versatz, f, M.Grass, m, true)
		busch.Shape = Enum.PartType.Ball
	end
end

-- ---------- Gebaeude ----------
local function fenster(parent, x, y, z, breite, hoehe, entlangX)
	local gr = entlangX and V(breite, hoehe, 0.4) or V(0.4, hoehe, breite)
	local f = teil("Fenster", gr, V(x, y, z), RGB(70, 105, 140), M.Glass, parent, true)
	f.Reflectance = 0.35
end

local function gebaeude(bx, bz, sx, sz, cx, cz)
	local m = modell("Gebaeude", fGebaeude)
	local dist = math.sqrt(cx * cx + cz * cz)
	local maxE = math.max(3, math.floor(15 - dist / 30))
	local etagen = math.random(math.max(2, math.floor(maxE * 0.5)), maxE)
	local H = etagen * 12
	local farbe = zufall(FASSADEN)
	teil("Koerper", V(32, H, 32), V(bx, Y_GEHWEG + H / 2, bz), farbe, zufall(MATS), m)
	teil("Dachrand", V(33, 1, 33), V(bx, Y_GEHWEG + H + 0.5, bz), dunkler(farbe, 0.45), M.Concrete, m)

	local fx = bx + sx * 16.1   -- Fassade zur Strasse (X-Seite)
	local fz = bz + sz * 16.1   -- Fassade zur Strasse (Z-Seite)
	m:SetAttribute("Eingang", V(fx, Y_GEHWEG, bz)) -- fuer Lieferkunden in der Stadt
	m:SetAttribute("Raus", V(sx, 0, 0))
	for f = 0, etagen - 1 do
		local y0 = Y_GEHWEG + f * 12
		if f == 0 then
			-- Eingang: Hochhaus = Glastuer, sonst Holztuer
			if etagen >= 8 then
				local t = teil("Eingang", V(0.6, 9, 8), V(fx, y0 + 4.5, bz), RGB(30, 40, 50), M.Glass, m)
				t.Transparency = 0.2
				teil("Vordach", V(4, 0.5, 12), V(bx + sx * 18, y0 + 10.2, bz), METALL, M.Metal, m)
			else
				teil("Tuer", V(0.6, 8.5, 5), V(fx, y0 + 4.25, bz), dunkler(farbe, 0.6), M.Wood, m)
				teil("Vordach", V(3, 0.5, 8), V(bx + sx * 17.5, y0 + 9.6, bz), dunkler(farbe, 0.3), M.SmoothPlastic, m)
			end
			for _, o in { -11, 11 } do
				fenster(m, fx, y0 + 5, bz + o, 6, 7, false)
			end
			for _, o in { -10, 0, 10 } do
				fenster(m, bx + o, y0 + 5, fz, 7, 7, true)
			end
		else
			for _, o in { -10, 0, 10 } do
				fenster(m, fx, y0 + 6, bz + o, 7, 6, false)
				fenster(m, bx + o, y0 + 6, fz, 7, 6, true)
			end
		end
	end
end

-- ---------- Parkhaus (zwei Ebenen, Rampe, Einfahrt von Sueden) ----------
local function parkhaus(cx, cz)
	local m = modell("Parkhaus", fGebaeude)
	local BETON = RGB(175, 175, 172)
	local Y0 = Y_GEHWEG
	local DECK = Y0 + 10
	-- obere Ebene: Nordteil ganz, Suedteil ohne die Rampenspur (x +22..+34)
	teil("Parkdeck", V(70, 1, 30), V(cx - 1, DECK - 0.5, cz - 21), BETON, M.Concrete, m)
	teil("Parkdeck", V(56, 1, 42), V(cx - 8, DECK - 0.5, cz + 15), BETON, M.Concrete, m)
	-- Rampe von der Einfahrt (Sueden, unten) nach Norden hoch aufs Deck
	local laenge = 40
	local winkel = math.atan2(DECK - Y0, laenge)
	local rampe = teil("Rampe", V(12, 1, laenge / math.cos(winkel)), CFrame.new(cx + 28, (Y0 + DECK) / 2 - 0.5, cz + 14) * CFrame.Angles(winkel, 0, 0), BETON, M.Concrete, m)
	rampe.Material = M.Concrete
	-- Stuetzen
	for x = -32, 16, 16 do
		for z = -32, 32, 16 do
			teil("Stuetze", V(1.5, DECK - Y0 - 1, 1.5), V(cx + x, Y0 + (DECK - Y0 - 1) / 2, cz + z), RGB(140, 140, 138), M.Concrete, m)
		end
	end
	-- Gelaender oben (mit Luecke fuer die Rampe)
	teil("Gelaender", V(70, 3, 1), V(cx - 1, DECK + 1.5, cz - 36), RGB(200, 200, 198), M.Concrete, m)
	teil("Gelaender", V(1, 3, 72), V(cx - 36, DECK + 1.5, cz), RGB(200, 200, 198), M.Concrete, m)
	teil("Gelaender", V(1, 3, 30), V(cx + 34, DECK + 1.5, cz - 21), RGB(200, 200, 198), M.Concrete, m)
	teil("Gelaender", V(56, 3, 1), V(cx - 8, DECK + 1.5, cz + 36), RGB(200, 200, 198), M.Concrete, m)
	teil("Gelaender", V(1, 3, 42), V(cx + 20, DECK + 1.5, cz + 15), RGB(200, 200, 198), M.Concrete, m)
	-- Parkplatzlinien (oben und unten)
	for _, y in { Y0 + 0.05, DECK + 0.05 } do
		for x = -30, 10, 10 do
			teil("Linie", V(0.4, 0.06, 14), V(cx + x, y, cz - 26), WEISS, M.SmoothPlastic, m, true)
			teil("Linie", V(0.4, 0.06, 14), V(cx + x, y, cz + 22), WEISS, M.SmoothPlastic, m, true)
		end
	end
	-- Einfahrtsrampe vom Strassenniveau auf den Gehweg (Bordstein)
	local apron = teil("Einfahrtskeil", V(12, Y0 - Y_STRASSE, 5), CFrame.new(cx + 28, (Y0 + Y_STRASSE) / 2, cz + 42.5) * CFrame.Angles(0, math.pi, 0), BETON, M.Concrete, m, false, "WedgePart")
	apron.Name = "Einfahrtskeil"
	-- Schild
	local schild = teil("Parkhausschild", V(14, 4, 0.5), V(cx + 28, DECK + 5, cz + 38), RGB(30, 80, 170), M.SmoothPlastic, m)
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Back
	g.Parent = schild
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Text = "P  PARKING"
	l.Font = Enum.Font.GothamBlack
	l.TextScaled = true
	l.TextColor3 = RGB(255, 255, 255)
	l.Parent = g
	-- Lampen unter dem Deck
	for x = -24, 8, 16 do
		local lampe = teil("Deckenlampe", V(3, 0.3, 1), V(cx + x, DECK - 1.15, cz), RGB(255, 250, 235), M.Neon, m, true)
		local licht = Instance.new("PointLight")
		licht.Range = 18
		licht.Parent = lampe
	end
end

-- ---------- Bloecke ----------
for i = 0, GRID - 1 do
	for j = 0, GRID - 1 do
		local cx, cz = blockMitte(i), blockMitte(j)
		local istPark = (i == 1 and j == 4)
		local istParkhaus = (i == 4 and j == 1)

		teil("Gehweg", V(BLOCK, 1, BLOCK), V(cx, Y_GEHWEG - 0.5, cz), GEHWEG, M.Concrete, fStrassen)

		if istParkhaus then
			parkhaus(cx, cz)
		elseif istPark then
			teil("Parkwiese", V(BLOCK - 8, 0.2, BLOCK - 8), V(cx, Y_GEHWEG + 0.1, cz), RGB(95, 160, 75), M.Grass, fBoden)
			for _ = 1, 8 do
				baum(cx + math.random(-28, 28), cz + math.random(-28, 28), fBaeume, Y_GEHWEG + 0.2)
			end
		else
			for bi = 0, 1 do
				for bj = 0, 1 do
					local sx = (bi == 0) and -1 or 1
					local sz = (bj == 0) and -1 or 1
					gebaeude(cx - 18 + bi * 36, cz - 18 + bj * 36, sx, sz, cx, cz)
				end
			end
		end

		-- Laternen: 2 pro Seite
		for _, o in { -28, 28 } do
			laterne(cx + 38, cz + o, V(1, 0, 0))
			laterne(cx - 38, cz + o, V(-1, 0, 0))
			if not (istParkhaus and o > 0) then laterne(cx + o, cz + 38, V(0, 0, 1)) end -- keep the garage entrance free
			laterne(cx + o, cz - 38, V(0, 0, -1))
		end
		muelleimer(cx - 37.5, cz + 10)
		muelleimer(cx + 10, cz - 37.5)
		hydrant(cx + 37.5, cz + 8)
	end
end

-- ---------- Landstrasse, Schnellstrasse, Zufahrten ----------
local STADTRAND = -START

-- Landstrasse von der Stadt zur Vorstadt
strasse("Landstrasse", STADTRAND, 0, 790, 0, 20)
gestrichelt(STADTRAND, 0, 770, 0, 6, 6)

-- Schnellstrasse
strasse("Schnellstrasse", -KARTE, HZ, KARTE, HZ, HB)
linie(0, HZ - 0.6, KARTE * 2, 0.4)
linie(0, HZ + 0.6, KARTE * 2, 0.4)
linie(0, HZ - 18.5, KARTE * 2, 0.5)
linie(0, HZ + 18.5, KARTE * 2, 0.5)
gestrichelt(-KARTE, HZ - 10, KARTE, HZ - 10, 12, 18)
gestrichelt(-KARTE, HZ + 10, KARTE, HZ + 10, 12, 18)

local function leitplanke(x1, x2, z)
	teil("Leitplanke", V(x2 - x1, 1, 0.5), V((x1 + x2) / 2, 1.2, z), RGB(190, 190, 195), M.Metal, fStrassen)
end
leitplanke(-KARTE, KARTE, HZ - 20.5)
leitplanke(-KARTE, -792, HZ + 20.5)
leitplanke(-768, -12, HZ + 20.5)
leitplanke(12, 768, HZ + 20.5)
leitplanke(792, KARTE, HZ + 20.5)

-- Zufahrt Stadt -> Schnellstrasse
strasse("Zufahrt_Stadt", 0, HZ + HB / 2, 0, START, 20)
gestrichelt(0, HZ + HB / 2, 0, START, 6, 6)
-- Ostzufahrt: Schnellstrasse -> Vorstadt -> Suedring
strasse("Ostzufahrt", 780, HZ + HB / 2, 780, 610, 20)
gestrichelt(780, HZ + HB / 2, 780, -14, 6, 6)
gestrichelt(780, 14, 780, 560, 6, 6)
-- Westzufahrt: Schnellstrasse -> Suedring
strasse("Westzufahrt", -780, HZ + HB / 2, -780, 610, 20)
gestrichelt(-780, HZ + HB / 2, -780, -40, 6, 6)
gestrichelt(-780, 40, -780, 560, 6, 6)
-- Landstrasse West: Stadt -> Westzufahrt
strasse("Landstrasse_West", -790, 0, START, 0, 20)
gestrichelt(-740, 0, START, 0, 6, 6)
-- Suedring und Suedzufahrt der Stadt
strasse("Suedring", -790, 600, 790, 600, 20)
gestrichelt(-740, 600, -40, 600, 6, 6)
gestrichelt(40, 600, 740, 600, 6, 6)
strasse("Suedzufahrt", 0, STADTRAND, 0, 590, 20)
gestrichelt(0, STADTRAND, 0, 562, 6, 6)

-- Kreisverkehre: Mitte und die Richtungen, aus denen Strassen kommen
local function kreisverkehr(cx, cz, zufahrten)
	local kreis = teil("Kreisverkehr", V(1, 66, 66), CFrame.new(cx, Y_STRASSE - 0.49, cz) * CFrame.Angles(0, 0, math.rad(90)), ASPHALT, M.Asphalt, fStrassen)
	kreis.Shape = Enum.PartType.Cylinder
	local insel = teil("Kreisinsel", V(1.2, 28, 28), CFrame.new(cx, 0.2, cz) * CFrame.Angles(0, 0, math.rad(90)), RGB(95, 160, 75), M.Grass, fStrassen)
	insel.Shape = Enum.PartType.Cylinder
	local bord = teil("Bordstein", V(1.1, 29.5, 29.5), CFrame.new(cx, 0.15, cz) * CFrame.Angles(0, 0, math.rad(90)), RGB(200, 200, 200), M.Concrete, fStrassen)
	bord.Shape = Enum.PartType.Cylinder
	baum(cx, cz, fStrassen, 0.8)
	-- Wartelinien an den Einfahrten (auf der rechten Spur der ankommenden Autos)
	for _, d in zufahrten do
		local rechts = V(d.Z, 0, -d.X)
		local p = V(cx, 0, cz) + d * 34 + rechts * 5
		if d.X ~= 0 then linie(p.X, p.Z, 0.8, 9) else linie(p.X, p.Z, 9, 0.8) end
	end
	table.insert(belegt, { cx - 40, cx + 40, cz - 40, cz + 40 })
end
local NORD, SUED, OST, WEST = V(0, 0, -1), V(0, 0, 1), V(1, 0, 0), V(-1, 0, 0)
kreisverkehr(0, 600, { NORD, WEST, OST })        -- Suedring / Suedzufahrt
kreisverkehr(-780, 0, { NORD, SUED, OST })       -- Westzufahrt / Landstrasse West
kreisverkehr(-780, 600, { NORD, OST })           -- Ecke Westzufahrt / Suedring
kreisverkehr(780, 600, { NORD, WEST })           -- Ecke Ostzufahrt / Suedring
local KV = V(0, 0, 600)
-- Ringstrassen um die Siedlungen
strasse("Siedlungsring_West", 420, -284, 420, 284, 16)
strasse("Siedlungsring_Nord", 412, -276, 790, -276, 16)
strasse("Siedlungsring_Sued", 412, 276, 790, 276, 16)

-- ---------- Wohnsiedlungen (Gated Communities) ----------
-- Zwei ummauerte Siedlungen links und rechts der Landstrasse, mit
-- eigenem Strassenraster und Toren auf allen Seiten.
local SX1, SX2 = 440, 760                  -- Mauer West / Ost
local SZ1, SZ2 = 12, 256                   -- Mauer vorne / hinten (Betrag)
local QUER = { 40, 96, 152, 208 }          -- Querstrassen (Z-Betrag)
local SB = 20                              -- Strassenbreite in den Siedlungen
local LAENGS = { 500, 600, 700 }           -- Laengsstrassen (X)
local REIHEN = { { 68, -1 }, { 124, 1 }, { 180, -1 }, { 236, -1 } } -- Hausreihe {Z-Betrag, Blickrichtung}
local SPALTEN = { 465, 531, 569, 631, 669, 735 }
local FX, FZ = 550, 110                    -- Fahrschule Mitte
local FW, FD, FH = 64, 40, 30              -- Fahrschule Breite, Tiefe, Hoehe

local WAND = RGB(215, 200, 175)

-- geparktes Auto (nur Deko), lokale Lage cf, Front = -Z
local AUTOFARBEN_DEKO = { RGB(200, 30, 35), RGB(30, 80, 170), RGB(235, 235, 235), RGB(25, 25, 28), RGB(160, 165, 170), RGB(40, 120, 70), RGB(240, 190, 40) }
local function parkAuto(cf, parent)
	local m = modell("ParkendesAuto", parent)
	local f = zufall(AUTOFARBEN_DEKO)
	local glas = RGB(35, 45, 60)
	teil("Karosserie", V(6.4, 2.2, 13.5), cf * CFrame.new(0, 2.5, 0), f, M.SmoothPlastic, m).Reflectance = 0.12
	teil("Kabine", V(5.8, 2.0, 7), cf * CFrame.new(0, 4.6, 0.8), f, M.SmoothPlastic, m)
	teil("Scheiben", V(5.9, 1.5, 7.1), cf * CFrame.new(0, 4.6, 0.8), glas, M.Glass, m, true)
	for _, sx in { -3, 3 } do
		for _, sz in { -4.4, 4.4 } do
			local r = teil("Rad", V(1, 2.4, 2.4), cf * CFrame.new(sx, 1.2, sz), RGB(25, 25, 25), M.SmoothPlastic, m, true)
			r.Shape = Enum.PartType.Cylinder
		end
		teil("Licht", V(1.3, 0.4, 0.2), cf * CFrame.new(sx * 0.75, 3.0, -6.8), RGB(255, 250, 225), M.Neon, m, true)
		teil("Ruecklicht", V(1.3, 0.4, 0.2), cf * CFrame.new(sx * 0.75, 3.0, 6.8), RGB(160, 15, 15), M.Neon, m, true)
	end
end

-- Haus in lokalen Koordinaten, Vorderseite = lokal +Z
-- strasse = Abstand der Strassenmitte (dann gibt es Einfahrt + Garage), halb = halbe Strassenbreite
local function haus(x, z, gierung, parent, strasse, halb)
	local m = modell("Haus", parent)
	local basis = CFrame.new(x, 0, z) * CFrame.Angles(0, gierung, 0)
	local wand = zufall(HAUSFARBEN)
	local dach = zufall(DACHFARBEN)
	local function t(name, gr, lokal, farbe, mat, klasse, keineKol)
		return teil(name, gr, basis * lokal, farbe, mat, m, keineKol, klasse)
	end
	t("Koerper", V(20, 12, 16), CFrame.new(0, 6, 0), wand, M.SmoothPlastic)
	for _, s in { 1, -1 } do
		t("Dach", V(22, 0.8, 10.2), CFrame.new(0, 14.6, s * 4) * CFrame.Angles(math.rad(30 * s), 0, 0), dach, M.Slate)
		for _, ex in { -9.6, 9.6 } do
			local lage = CFrame.new(ex, 14.31, s * 4)
			if s == 1 then lage = lage * CFrame.Angles(0, math.pi, 0) end
			t("Giebel", V(0.8, 4.62, 8), lage, wand, M.SmoothPlastic, "WedgePart")
		end
	end
	t("Tuer", V(4, 8, 0.4), CFrame.new(0, 4, 8.1), RGB(110, 70, 45), M.Wood)
	for _, o in { -6, 6 } do
		local f = t("Fenster", V(4, 4, 0.4), CFrame.new(o, 6.5, 8.1), GLAS, M.SmoothPlastic, nil, true)
		f.Reflectance = 0.25
	end
	if strasse then
		-- paved path from the front door to the street
		local wegLaenge = strasse - (halb or 10) - 8.2
		t("Weg", V(3.6, 1, wegLaenge), CFrame.new(0, -0.3, 8.2 + wegLaenge / 2), RGB(200, 192, 178), M.Cobblestone)
	else
		t("Weg", V(4, 1, 9), CFrame.new(0, -0.3, 12.5), RGB(200, 192, 178), M.Cobblestone)
	end
	local HECKE = RGB(55, 110, 45)
	t("Hecke", V(34, 2.5, 1.5), CFrame.new(0, 1.25, -17), HECKE, M.Grass, nil, true)
	t("Hecke", V(1.5, 2.5, 34), CFrame.new(-17, 1.25, 0), HECKE, M.Grass, nil, true)
	t("Hecke", V(1.5, 2.5, 34), CFrame.new(17, 1.25, 0), HECKE, M.Grass, nil, true)
	if strasse then
		-- Garage neben dem Haus und eine Einfahrt bis zur Strasse
		t("Garage", V(6, 8, 11), CFrame.new(13.2, 4, -0.5), wand, M.SmoothPlastic)
		t("Garagendach", V(6.6, 0.6, 11.6), CFrame.new(13.2, 8.3, -0.5), dach, M.Slate)
		t("Garagentor", V(5, 6.5, 0.3), CFrame.new(13.2, 3.3, 5.05), RGB(225, 225, 225), M.DiamondPlate)
		-- asphalt driveway from the garage door to the street, with kerbs on both sides
		local laenge = strasse - (halb or 10) - 5.2
		t("Einfahrt", V(7, 1, laenge), CFrame.new(13.2, -0.3, 5.2 + laenge / 2), RGB(58, 58, 62), M.Asphalt)
		for _, kx in { 9.5, 16.9 } do
			t("Randstein", V(0.4, 0.5, laenge), CFrame.new(kx, 0.2, 5.2 + laenge / 2), RGB(190, 190, 185), M.Concrete, nil, true)
		end
		t("Briefkasten", V(0.8, 1.2, 0.6), CFrame.new(3, 3, strasse - (halb or 10) - 1.5), RGB(30, 70, 150), M.Metal)
		t("Pfosten", V(0.3, 2.5, 0.3), CFrame.new(3, 1.25, strasse - (halb or 10) - 1.5), RGB(90, 90, 95), M.Metal)
		if math.random() < 0.5 then
			parkAuto(basis * CFrame.new(13.2, 0.2, 13), m)
		end
		m:SetAttribute("Strasse", (basis * CFrame.new(0, 0, strasse)).Position)
	end
	local lx, lz = math.random(-10, 10), -12
	local c, s = math.cos(gierung), math.sin(gierung)
	baum(x + lx * c + lz * s, z - lx * s + lz * c, m, 0)
end

local function mauer(x1, z1, x2, z2, parent)
	local sx = (x1 == x2) and 1.5 or math.abs(x2 - x1)
	local sz = (z1 == z2) and 1.5 or math.abs(z2 - z1)
	teil("Mauer", V(sx, 6, sz), V((x1 + x2) / 2, 3, (z1 + z2) / 2), WAND, M.Brick, parent)
end

-- Mauer mit Toren an den angegebenen Stellen
local function mauerMitToren(entlangX, fest, von, bis, tore, parent)
	local function seg(a, b)
		if b - a < 0.5 then return end
		if entlangX then mauer(a, fest, b, fest, parent) else mauer(fest, a, fest, b, parent) end
	end
	local function pfeiler(p)
		local pos = entlangX and V(p, 4.5, fest) or V(fest, 4.5, p)
		teil("Torpfeiler", V(2.5, 9, 2.5), pos, RGB(180, 165, 140), M.Brick, parent)
	end
	table.sort(tore)
	local a = von
	for _, t in tore do
		seg(a, t - SB / 2 - 1)
		pfeiler(t - SB / 2 - 1)
		pfeiler(t + SB / 2 + 1)
		a = t + SB / 2 + 1
	end
	seg(a, bis)
end

local function siedlung(sg) -- sg = 1 (Sueden) oder -1 (Norden)
	local f = modell(sg == 1 and "Siedlung_Sued" or "Siedlung_Nord", fVorstadt)
	local mitFahrschule = (sg == 1)

	-- Querstrassen (laufen in X-Richtung, bis zu den Ringstrassen)
	for _, q in QUER do
		local z = q * sg
		if mitFahrschule and q == 96 then
			strasse("Querstrasse", 428, z, 500, z, SB)
			strasse("Querstrasse", 600, z, 770, z, SB)
		else
			strasse("Querstrasse", 428, z, 770, z, SB)
		end
	end
	-- Laengsstrassen (laufen in Z-Richtung, von der Landstrasse bis zum Ring)
	for _, x in LAENGS do
		strasse("Laengsstrasse", x, 10 * sg, x, 276 * sg, SB)
	end

	-- Mauer mit Toren an jeder Strasse
	local zTore = {}
	for _, q in QUER do table.insert(zTore, q * sg) end
	local zVon, zBis = math.min(SZ1 * sg, SZ2 * sg), math.max(SZ1 * sg, SZ2 * sg)
	mauerMitToren(true, SZ1 * sg, SX1, SX2, { 500, 600, 700 }, f)
	mauerMitToren(true, SZ2 * sg, SX1, SX2, { 500, 600, 700 }, f)
	mauerMitToren(false, SX1, zVon, zBis, zTore, f)
	mauerMitToren(false, SX2, zVon, zBis, zTore, f)

	-- Pfoertnerhaus mit Schranke am Haupttor (x = 700)
	teil("Schranke", V(0.6, 12, 0.6), V(690.5, 7, (SZ1 + 0.8) * sg), RGB(220, 40, 40), M.SmoothPlastic, f, true)
	teil("Pfoertnerhaus", V(8, 8, 8), V(722, 4, 22 * sg), RGB(240, 240, 235), M.SmoothPlastic, f)
	teil("Pfoertnerdach", V(9, 0.6, 9), V(722, 8.3, 22 * sg), RGB(70, 70, 75), M.Slate, f)

	-- Baeume im Gruenstreifen hinter der Mauer
	for x = 455, 745, 25 do
		local frei = true
		for _, l in LAENGS do
			if math.abs(x - l) < 15 then frei = false end
		end
		if math.abs(x - 722) < 10 then frei = false end
		if frei then baum(x, 21 * sg, f, 0) end
	end

	-- Vorfahrtsregeln in der Siedlung: meistens rechts vor links (30er-Zone),
	-- an Querstrasse 96 Vorfahrt gewaehren, an Querstrasse 208 STOP; Ausfahrt auf die Landstrasse: STOP
	local REGEL = { [40] = "rvl", [96] = "vorfahrtGewaehren", [152] = "rvl", [208] = "stop" }
	for _, x in LAENGS do
		for _, q in QUER do
			local art = REGEL[q] or "rvl"
			if art == "rvl" then
				rechtsVorLinks(x, q * sg)
			else
				local function setzen(was, d)
					local rechts = V(d.Z, 0, -d.X)
					local sx, sz = x + d.X * 13 + rechts.X * 12.5, q * sg + d.Z * 13 + rechts.Z * 12.5
					local amParkplatz = mitFahrschule and sx > 504 and sx < 596 and sz < 150
					if not amParkplatz then
						zeichen(was, x, q * sg, d, 13, 12.5, 12, 5, 9, 0)
					end
				end
				for _, d in { V(0, 0, 1), V(0, 0, -1) } do setzen(art, d) end
				for _, d in { V(1, 0, 0), V(-1, 0, 0) } do setzen("vorfahrt", d) end
			end
		end
		-- Ausfahrt auf die Landstrasse
		stoppschild(x, 0, V(0, 0, sg), 16, 13, 13, 5, 9, 0)
	end

	-- Laternen zwischen den Grundstuecken
	for _, q in QUER do
		for _, x in { 550, 650 } do
			if not (mitFahrschule and x == 550 and q == 96) then
				laterne(x, (q + SB / 2 + 1.5) * sg, V(0, 0, -sg), 0)
			end
		end
	end

	-- Haeuser: jede Reihe liegt zwischen zwei Strassen
	for _, reihe in REIHEN do
		local zb, blick = reihe[1], reihe[2]
		for _, x in SPALTEN do
			local fahrschulPlatz = mitFahrschule and x > 506 and x < 594 and zb < 152
			if not fahrschulPlatz then
				local z = zb * sg
				-- blick = -1: zur Strasse Richtung Landstrasse, 1: weg davon
				local nachPlus = (blick * sg) > 0
				local gierung = nachPlus and 0 or math.pi
				haus(x, z, gierung, f)
			end
		end
	end
end

siedlung(1)
siedlung(-1)

-- ---------- Wohngebiete ausserhalb der Stadt (Haeuser entlang der Strassen) ----------
local fVororte = ordner("Vororte")
local function hausReihe(achseX, fest, von, bis, abstand, seiten)
	-- achseX = Strasse laeuft in X-Richtung (z = fest), sonst in Z-Richtung (x = fest)
	for pos = von, bis, 42 do
		for _, seite in seiten do
			local x, z, gierung
			if achseX then
				x, z = pos, fest + seite * abstand
				gierung = seite < 0 and 0 or math.pi            -- Vorderseite zur Strasse
			else
				x, z = fest + seite * abstand, pos
				gierung = seite < 0 and math.pi / 2 or -math.pi / 2
			end
			haus(x, z, gierung, fVororte, abstand, 10)
			table.insert(belegt, { x - 18, x + 18, z - 18, z + 18 })
		end
	end
end
local BEIDE = { -1, 1 }
hausReihe(true, 0, -720, -380, 32, BEIDE)          -- Landstrasse West
hausReihe(false, 0, 380, 548, 32, BEIDE)           -- Suedzufahrt
hausReihe(true, 600, -720, -90, 32, BEIDE)         -- Suedring West
hausReihe(true, 600, 90, 720, 32, BEIDE)           -- Suedring Ost
hausReihe(false, -780, -470, -60, 32, { 1 })       -- Westzufahrt (Ostseite)
hausReihe(false, -780, 102, 548, 32, { 1 })
hausReihe(false, 780, -470, -60, 32, { 1 })        -- Ostzufahrt (Ostseite)
hausReihe(false, 780, 60, 548, 32, { 1 })
hausReihe(false, 780, 320, 548, 32, { -1 })        -- Ostzufahrt (Westseite, neben dem Depot)

-- ---------- LKW-Depot "Parcel Express" (suedlich der Siedlung) ----------
local fDepot = modell("Depot", fVorstadt)
strasse("Depotzufahrt", 600, 284, 600, 332, 20)
teil("Depothof", V(260, 1, 112), V(600, Y_STRASSE - 0.5, 386), RGB(55, 57, 62), M.Asphalt, fDepot)
table.insert(belegt, { 465, 735, 325, 480 })
-- Lagerhalle mit Toren
local HALLE = RGB(150, 165, 185)
teil("Lagerhalle", V(240, 22, 30), V(600, 11, 457), HALLE, M.Metal, fDepot)
teil("Hallendach", V(242, 1, 32), V(600, 22.5, 457), RGB(90, 95, 105), M.Metal, fDepot)
for x = 500, 700, 40 do
	teil("Rolltor", V(14, 12, 0.4), V(x, 6.2, 441.8), RGB(200, 200, 205), M.DiamondPlate, fDepot)
	teil("Rampe", V(16, 1.2, 4), V(x, 0.6, 440), RGB(120, 120, 125), M.Concrete, fDepot)
end
local depotSchild = teil("Depotschild", V(70, 7, 0.6), V(600, 17, 441.6), RGB(230, 120, 30), M.SmoothPlastic, fDepot)
do
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 30
	g.Parent = depotSchild
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Text = "PARCEL EXPRESS"
	l.Font = Enum.Font.GothamBlack
	l.TextScaled = true
	l.TextColor3 = RGB(255, 255, 255)
	l.Parent = g
end
-- Paketstapel als Deko
for i = 0, 5 do
	local px = 660 + (i % 3) * 4
	local pz = 430 - math.floor(i / 3) * 4
	teil("Paket", V(3, 2.4, 3), V(px, 1.4, pz), RGB(185, 140, 90), M.Cardboard, fDepot)
	teil("Paket", V(2.6, 2, 2.6), V(px, 3.6, pz), RGB(170, 125, 80), M.Cardboard, fDepot)
end
-- LKW-Buchten (Fahrzeug schaut nach Norden zur Ausfahrt)
local lkwBuchten = Instance.new("Folder")
lkwBuchten.Name = "LkwBuchten"
lkwBuchten.Parent = fDepot
for i = 0, 4 do
	local x = 495 + i * 14
	local b = teil("LkwBucht", V(13, 1, 30), CFrame.new(x, Y_STRASSE, 405), RGB(255, 255, 0), M.SmoothPlastic, lkwBuchten, true)
	b.Transparency = 1
	b.CanTouch = false
	b.CanQuery = false
	linie(x - 7, 405, 0.5, 30, RGB(240, 200, 40))
end
linie(495 + 5 * 14 - 7, 405, 0.5, 30, RGB(240, 200, 40))
-- Platz fuer den Disponenten vor der Halle
local disponent = teil("DisponentPlatz", V(2, 1, 2), CFrame.new(650, 0.7, 436), RGB(255, 0, 0), M.SmoothPlastic, fDepot, true)
disponent.Transparency = 1
disponent.CanQuery = false
disponent.CanTouch = false

-- ---------- Neue Wohnstrassen mit Haeusern (fuellt die gruenen Flaechen) ----------
-- Gleiche Liste steht in Verkehrsregeln (30-Zone)
local WOHNSTRASSEN = {
	{ -324, -208, -720, -208 }, { -720, -208, -720, -460 }, { -720, -460, 780, -460 },
	{ 208, -324, 208, -460 }, { -208, -324, -208, -460 }, { 324, -208, 412, -208 },
	{ -324, 208, -720, 208 }, { -720, 208, -720, 460 }, { -720, 460, -60, 460 },
	{ -208, 324, -208, 460 }, { 208, 324, 208, 460 }, { 60, 460, 400, 460 },
	{ -324, -104, -720, -104 }, { -720, -104, -720, -208 }, { -324, 104, -720, 104 }, { -720, 104, -720, 208 },
	{ 324, -104, 412, -104 },
	{ -720, -333, -208, -333 }, { -720, 333, -208, 333 }, { 208, -333, 780, -333 }, { 208, 333, 400, 333 },
	{ 0, -540, 0, -700 }, { -720, -700, 720, -700 }, { -400, -700, -400, -580 }, { 400, -700, 400, -580 },
}
local WB = 18 -- Breite der Wohnstrassen
for _, w in WOHNSTRASSEN do
	local x1, z1, x2, z2 = w[1], w[2], w[3], w[4]
	if x1 == x2 then
		strasse("Wohnstrasse", x1, math.min(z1, z2) - WB / 2, x2, math.max(z1, z2) + WB / 2, WB)
	else
		strasse("Wohnstrasse", math.min(x1, x2) - WB / 2, z1, math.max(x1, x2) + WB / 2, z2, WB)
	end
end

local function frei(x1, x2, z1, z2)
	if x2 > -STADTRAND - 16 and x1 < STADTRAND + 16 and z2 > -STADTRAND - 16 and z1 < STADTRAND + 16 then return false end
	if x2 > 400 and x1 < 800 and z2 > -300 and z1 < 300 then return false end
	if math.abs(x1) > KARTE - 5 or math.abs(x2) > KARTE - 5 or math.abs(z1) > KARTE - 5 or math.abs(z2) > KARTE - 5 then return false end
	for _, b in belegt do
		if x1 < b[2] and x2 > b[1] and z1 < b[4] and z2 > b[3] then return false end
	end
	return true
end

-- ---------- Villen (begehbar, eingerichtet, mit Ingame-Geld kaufbar) ----------
local fVillen = ordner("Villen")
local VILLEN = {
	{ id = "Villa1", name = "Villa Sunrise", preis = 5000, x = -440, z = 415, g = 0, farbe = RGB(245, 243, 238) },
	{ id = "Villa2", name = "Villa Lakeside", preis = 9000, x = -620, z = 415, g = 0, farbe = RGB(232, 226, 214) },
	{ id = "Villa3", name = "Villa Palm", preis = 15000, x = -440, z = 505, g = math.pi, farbe = RGB(240, 240, 245) },
	{ id = "Villa4", name = "Villa Royal", preis = 25000, x = -620, z = 505, g = math.pi, farbe = RGB(60, 62, 70) },
}
local function villa(v)
	local m = modell(v.id, fVillen)
	m:SetAttribute("Villa", true)
	m:SetAttribute("VillaName", v.name)
	m:SetAttribute("Preis", v.preis)
	local basis = CFrame.new(v.x, 0, v.z) * CFrame.Angles(0, v.g, 0)
	local function t(name, gr, x, y, z, farbe, mat, keineKol, klasse)
		return teil(name, gr, basis * CFrame.new(x, y, z), farbe, mat or M.SmoothPlastic, m, keineKol, klasse)
	end
	local wand = v.farbe
	local dunkel = (v.farbe.R + v.farbe.G + v.farbe.B) < 1
	local akzent = dunkel and RGB(200, 170, 110) or RGB(70, 72, 78)
	local holz = RGB(150, 110, 75)
	local H = 13
	-- Sockel, Boden, Decke
	t("Sockel", V(52, 0.6, 42), 0, 0.3, 0, RGB(200, 198, 192), M.Concrete)
	t("Boden", V(48, 0.2, 38), 0, 0.7, 0, RGB(185, 150, 110), M.WoodPlanks)
	t("Dach", V(54, 1, 44), 0, H + 0.6, 0, akzent, M.Concrete)
	t("Dachkante", V(54.4, 0.3, 44.4), 0, H + 1.2, 0, wand, M.SmoothPlastic)
	t("Decke", V(48, 0.3, 38), 0, H - 0.1, 0, RGB(245, 245, 245), M.SmoothPlastic, true)
	-- Aussenwaende
	t("Wand", V(1, H, 40), -24, H / 2 + 0.6, 0, wand)
	t("Wand", V(1, H, 40), 24, H / 2 + 0.6, 0, wand)
	t("Wand", V(10, H, 1), -19, H / 2 + 0.6, -19.5, wand)                -- hinten links
	t("Wand", V(32, H, 1), 8, H / 2 + 0.6, -19.5, wand)                  -- hinten rechts
	t("Sturz", V(6, 3.5, 1), -11, H - 1.15, -19.5, wand)                 -- ueber der Terrassentuer
	t("Wand", V(14, H, 1), -17, H / 2 + 0.6, 19.5, wand)                 -- vorne links
	t("Sturz", V(6, 3.8, 1), -7, H - 1.3, 19.5, wand)                    -- ueber der Haustuer
	local tuer = t("VillaTuer", V(6, 9.2, 0.6), -7, 5.2, 19.5, holz, M.Wood)
	tuer:SetAttribute("VillaId", v.id)
	t("Griff", V(0.3, 1.2, 0.3), -5, 5, 19.9, RGB(200, 200, 205), M.Metal, true)
	local glas = t("Glasfront", V(27.5, 11, 0.4), 10, 6.6, 19.5, RGB(150, 185, 210), M.Glass)
	glas.Transparency = 0.5
	glas.Reflectance = 0.2
	t("Rahmen", V(28, 1, 1), 10, 1.1, 19.5, akzent, M.Metal)
	t("Rahmen", V(28, 1, 1), 10, H + 0.1, 19.5, akzent, M.Metal)
	for _, x in { -3.5, 5, 15, 23.5 } do t("Rahmen", V(0.6, H, 1), x, H / 2 + 0.6, 19.5, akzent, M.Metal) end
	for _, z in { -10, 6 } do
		local f = t("Fenster", V(0.4, 7, 9), -24, 7, z, RGB(150, 185, 210), M.Glass, true)
		f.Transparency = 0.4
	end
	-- Innenwaende: Schlafzimmer hinten rechts
	t("Innenwand", V(1, H - 0.4, 16), 4, H / 2 + 0.5, -11, RGB(240, 238, 232))
	t("Innenwand", V(20, H - 0.4, 1), 14, H / 2 + 0.5, 2, RGB(240, 238, 232))
	-- Deckenlampen
	for _, p in { { -14, -8 }, { -14, 10 }, { 14, 10 }, { 14, -9 } } do
		local l = t("Lampe", V(3, 0.3, 3), p[1], H - 0.4, p[2], RGB(255, 245, 220), M.Neon, true)
		local licht = Instance.new("PointLight")
		licht.Range = 22
		licht.Brightness = 0.9
		licht.Color = RGB(255, 235, 200)
		licht.Shadows = false
		licht.Parent = l
	end
	-- Wohnzimmer: Sofa, Tisch, Teppich, TV, Regal, Esstisch
	local stoff = RGB(120, 125, 135)
	t("Teppich", V(16, 0.1, 12), -14, 0.85, -6, RGB(200, 190, 170), M.Fabric, true)
	t("Sofa", V(13, 1.6, 4), -14, 1.6, -1, stoff, M.Fabric)
	t("Sofalehne", V(13, 2.6, 1.2), -14, 2.4, 0.6, stoff, M.Fabric)
	t("Sofa", V(4, 1.6, 8), -22, 1.6, -5, stoff, M.Fabric)
	t("Couchtisch", V(6, 1.2, 4), -14, 1.4, -7, RGB(60, 45, 35), M.Wood)
	t("Lowboard", V(12, 2, 2.5), -14, 1.8, -17.6, RGB(40, 40, 45), M.Wood)
	local tv = t("Fernseher", V(10, 5.6, 0.4), -14, 6.4, -18.7, RGB(15, 15, 18), M.Glass)
	tv.Reflectance = 0.3
	t("Regal", V(2, 9, 8), -22.8, 5.2, 12, holz, M.Wood)
	for i = 0, 2 do t("Buecher", V(1.6, 1.4, 6), -22.6, 2.8 + i * 2.6, 12, ({ RGB(160, 50, 50), RGB(50, 80, 140), RGB(60, 120, 70) })[i + 1], M.SmoothPlastic, true) end
	t("Esstisch", V(9, 0.5, 5), -11, 3.4, 12, holz, M.Wood)
	for _, sx in { -3.5, 3.5 } do for _, sz in { -2, 2 } do t("Tischbein", V(0.4, 2.6, 0.4), -11 + sx, 2, 12 + sz, RGB(40, 40, 45), M.Metal, true) end end
	for _, sx in { -2.5, 2.5 } do
		for _, sz in { -3.8, 3.8 } do
			t("Stuhl", V(2, 0.4, 2), -11 + sx, 2.2, 12 + sz, RGB(240, 240, 240), M.SmoothPlastic)
			t("Lehne", V(2, 2.4, 0.3), -11 + sx, 3.4, 12 + sz + (sz > 0 and 1 or -1), RGB(240, 240, 240), M.SmoothPlastic, true)
		end
	end
	t("Pflanze", V(2, 2.4, 2), -2, 1.9, 17, RGB(120, 90, 70), M.Concrete)
	local blatt = t("Blaetter", V(4, 4, 4), -2, 4.5, 17, RGB(60, 130, 60), M.Grass, true)
	blatt.Shape = Enum.PartType.Ball
	-- Kueche vorne rechts
	t("Arbeitsplatte", V(3, 3.6, 14), 22, 2.5, 11, RGB(235, 235, 235), M.Marble)
	t("Kochfeld", V(2.2, 0.1, 3), 22, 4.35, 9, RGB(20, 20, 20), M.Glass, true)
	t("Spuele", V(2, 0.1, 2.5), 22, 4.35, 14, RGB(180, 180, 185), M.Metal, true)
	t("Kuehlschrank", V(3.5, 8, 3.5), 21.8, 4.7, 4.3, RGB(200, 202, 205), M.Metal)
	t("Kochinsel", V(8, 3.6, 4), 12, 2.5, 10, RGB(60, 60, 65), M.Wood)
	t("Inselplatte", V(8.4, 0.3, 4.4), 12, 4.45, 10, RGB(240, 240, 240), M.Marble)
	for _, sx in { -2.5, 2.5 } do t("Barhocker", V(1.6, 3.2, 1.6), 12 + sx, 2.3, 13.5, RGB(40, 40, 45), M.Metal) end
	-- Schlafzimmer
	t("Bett", V(9, 1.6, 11), 15, 1.6, -12, RGB(80, 60, 45), M.Wood)
	t("Matratze", V(8.6, 0.9, 10.4), 15, 2.8, -12, RGB(245, 245, 245), M.Fabric)
	t("Bettdecke", V(8.8, 0.3, 6), 15, 3.35, -10, RGB(70, 100, 150), M.Fabric, true)
	t("Kopfteil", V(9.4, 4.5, 0.6), 15, 3.1, -17.9, RGB(80, 60, 45), M.Wood)
	for _, sx in { -2.2, 2.2 } do t("Kissen", V(3.2, 0.8, 1.6), 15 + sx, 3.5, -16.4, RGB(255, 255, 255), M.Fabric, true) end
	for _, sx in { -6.5, 6.5 } do t("Nachttisch", V(2.4, 2.4, 2.4), 15 + sx, 1.9, -16.5, holz, M.Wood) end
	t("Kleiderschrank", V(2.6, 9.5, 10), 22.4, 5.4, -8, RGB(235, 230, 220), M.Wood)
	-- Terrasse und Pool hinten
	t("Terrasse", V(48, 0.4, 8), 0, 0.4, -24, RGB(170, 140, 110), M.WoodPlanks)
	t("Poolrand", V(30, 0.8, 14), -4, 0.4, -36, RGB(235, 235, 230), M.Concrete)
	local wasser = t("Wasser", V(27, 0.3, 11), -4, 0.75, -36, RGB(60, 170, 220), M.Glass, true)
	wasser.Transparency = 0.25
	for _, sx in { 16, 20 } do
		t("Liege", V(2.5, 0.6, 7), sx, 1, -34, RGB(250, 250, 250), M.Fabric)
		t("Liegelehne", V(2.5, 2, 0.5), sx, 1.8, -37.3, RGB(250, 250, 250), M.Fabric, true)
	end
	-- Einfahrt, Hecke, Briefkasten
	t("Einfahrt", V(9, 1, 15), 17, -0.3, 28.5, RGB(58, 58, 62), M.Asphalt)
	for _, kx in { 12.3, 21.7 } do t("Randstein", V(0.4, 0.5, 15), kx, 0.2, 28.5, RGB(190, 190, 185), M.Concrete, true) end
	t("Weg", V(4, 1, 15), -7, -0.3, 28.5, RGB(200, 192, 178), M.Cobblestone)
	m:SetAttribute("Stellplatz", CFrame.lookAt((basis * CFrame.new(17, 0, 28)).Position, (basis * CFrame.new(17, 0, 40)).Position))
	local HECKE = RGB(55, 110, 45)
	t("Hecke", V(62, 3, 1.5), 0, 1.5, -44, HECKE, M.Grass, true)
	t("Hecke", V(1.5, 3, 78), -31, 1.5, -5, HECKE, M.Grass, true)
	t("Hecke", V(1.5, 3, 78), 31, 1.5, -5, HECKE, M.Grass, true)
	-- Verkaufsschild an der Strasse
	t("Schildpfosten", V(0.4, 6, 0.4), -22, 3, 32, RGB(90, 90, 95), M.Metal)
	local schild = t("Verkaufsschild", V(7, 4, 0.3), -22, 6.5, 32, RGB(250, 250, 250), M.SmoothPlastic)
	for _, seite in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local g = Instance.new("SurfaceGui")
		g.Face = seite
		g.Name = "Text"
		g.Parent = schild
		local l = Instance.new("TextLabel")
		l.Name = "Zeile"
		l.Size = UDim2.fromScale(1, 1)
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.GothamBlack
		l.TextScaled = true
		l.TextColor3 = RGB(180, 30, 30)
		l.Text = "FOR SALE\n" .. v.name .. "\n" .. v.preis .. " coins"
		l.Parent = g
	end
	m:SetAttribute("Eingang", (basis * CFrame.new(-7, 0, 23)).Position)
	local x0, z0 = v.x, v.z
	table.insert(belegt, { x0 - 34, x0 + 34, z0 - 46, z0 + 46 })
end
for _, v in VILLEN do villa(v) end

-- ---------- Pizzeria "Pizza Rapido" (an der Landstrasse zwischen Stadt und Siedlung) ----------
local fPizza = modell("Pizzeria", fVorstadt)
do
	local PX = 375
	teil("Pizzaparkplatz", V(52, 1, 80), V(PX, Y_STRASSE - 0.5, 49), ASPHALT, M.Asphalt, fPizza)
	teil("Pizzeriaboden", V(42, 1, 22), V(PX, 0.6, 101), RGB(200, 195, 185), M.Concrete, fPizza)
	local rot, weiss = RGB(190, 40, 35), RGB(245, 240, 230)
	teil("Pizzeriawand", V(40, 11, 1), V(PX, 6.6, 111), weiss, M.Brick, fPizza)
	teil("Pizzeriawand", V(1, 11, 20), V(PX - 20, 6.6, 101), weiss, M.Brick, fPizza)
	teil("Pizzeriawand", V(1, 11, 20), V(PX + 20, 6.6, 101), weiss, M.Brick, fPizza)
	teil("Pizzeriawand", V(14, 11, 1), V(PX - 13, 6.6, 91), weiss, M.Brick, fPizza)
	teil("Pizzeriawand", V(14, 11, 1), V(PX + 13, 6.6, 91), weiss, M.Brick, fPizza)
	teil("Pizzeriawand", V(12, 3, 1), V(PX, 10.6, 91), weiss, M.Brick, fPizza)
	teil("Pizzeriadach", V(44, 1, 24), V(PX, 12.6, 101), rot, M.SmoothPlastic, fPizza)
	for i = 0, 5 do
		teil("Markise", V(7, 0.4, 4), V(PX - 17.5 + i * 7, 10, 88.5) , (i % 2 == 0) and rot or weiss, M.Fabric, fPizza, true)
	end
	teil("Theke", V(14, 3.6, 3), V(PX, 2.9, 104), RGB(120, 80, 50), M.Wood, fPizza)
	local ofen = teil("Pizzaofen", V(8, 6, 5), V(PX + 12, 3.6, 107), RGB(170, 90, 60), M.Brick, fPizza)
	local glut = teil("Glut", V(3, 1.5, 0.3), V(PX + 12, 2.6, 104.4), RGB(255, 120, 30), M.Neon, fPizza, true)
	local feuer = Instance.new("PointLight")
	feuer.Color = RGB(255, 140, 60)
	feuer.Range = 14
	feuer.Parent = glut
	local schild = teil("Pizzaschild", V(30, 4.5, 0.6), V(PX, 15.3, 90.6), rot, M.SmoothPlastic, fPizza)
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Front
	g.Parent = schild
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Text = "🍕 PIZZA RAPIDO"
	l.Font = Enum.Font.GothamBlack
	l.TextScaled = true
	l.TextColor3 = RGB(255, 255, 255)
	l.Parent = g
	for i = 0, 1 do
		teil("Tischchen", V(4, 0.4, 4), V(PX - 14 + i * 28, 3.2, 84), weiss, M.SmoothPlastic, fPizza)
		teil("Tischbein", V(0.5, 3, 0.5), V(PX - 14 + i * 28, 1.5, 84), RGB(40, 40, 45), M.Metal, fPizza)
	end
	-- Parkbuchten fuer die Lieferautos (Auto schaut nach Norden zur Landstrasse)
	local buchten = Instance.new("Folder")
	buchten.Name = "PizzaBuchten"
	buchten.Parent = fPizza
	for i = 0, 2 do
		local x = PX - 14 + i * 14
		local b = teil("PizzaBucht", V(10, 1, 18), CFrame.new(x, Y_STRASSE, 62), RGB(255, 255, 0), M.SmoothPlastic, buchten, true)
		b.Transparency = 1
		b.CanQuery = false
		b.CanTouch = false
		linie(x - 6, 62, 0.4, 18)
		linie(x + 6, 62, 0.4, 18)
	end
	local platz = teil("PizzaPlatz", V(2, 1, 2), CFrame.new(PX - 5, 0.7, 87), RGB(255, 0, 0), M.SmoothPlastic, fPizza, true)
	platz.Transparency = 1
	platz.CanQuery = false
	platz.CanTouch = false
	table.insert(belegt, { PX - 28, PX + 28, 8, 114 })
end

-- ---------- Autohaus "Velocity Motors" (an der Zufahrt zur Schnellstrasse, noerdlich der Stadt) ----------
do
	local fAH = modell("Autohaus", fVorstadt)
	local AX, AZ = 85, -376
	teil("Autohausplatz", V(140, 1, 68), V(80, Y_STRASSE - 0.5, AZ), RGB(52, 52, 56), M.Asphalt, fAH)
	-- Showroom (Glas rundum, Eingang zur Strasse = Westen)
	local SX, SB, ST = 122, 52, 56
	teil("Showroomboden", V(SB, 1, ST), V(SX, 0.1, AZ), RGB(235, 235, 238), M.Marble, fAH)
	teil("Showroomdach", V(SB + 4, 1.2, ST + 4), V(SX, 15.1, AZ), RGB(35, 37, 42), M.Metal, fAH)
	teil("Dachblende", V(0.6, 2.2, ST + 4), V(SX - SB / 2 - 2, 14.3, AZ), RGB(200, 30, 40), M.SmoothPlastic, fAH)
	local function glas(gr, pos)
		local g = teil("Glaswand", gr, pos, RGB(160, 195, 220), M.Glass, fAH)
		g.Transparency = 0.6
		g.Reflectance = 0.25
		return g
	end
	glas(V(0.5, 14, 22), V(SX - SB / 2, 7.6, AZ - 17))
	glas(V(0.5, 14, 22), V(SX - SB / 2, 7.6, AZ + 17))
	teil("Eingangssturz", V(0.8, 3, 12), V(SX - SB / 2, 13.1, AZ), RGB(35, 37, 42), M.Metal, fAH)
	glas(V(SB, 14, 0.5), V(SX, 7.6, AZ - ST / 2))
	glas(V(SB, 14, 0.5), V(SX, 7.6, AZ + ST / 2))
	local rueck = teil("Rueckwand", V(1, 14, ST), V(SX + SB / 2, 7.6, AZ), RGB(245, 245, 245), M.SmoothPlastic, fAH)
	for _, s in { -1, 1 } do
		for _, dz in { -ST / 2, ST / 2 } do
			teil("Stuetze", V(1, 14, 1), V(SX + s * SB / 2, 7.6, AZ + dz), RGB(35, 37, 42), M.Metal, fAH)
		end
	end
	-- Schriftzug an der Front und an der Rueckwand innen
	local function schrift(teilchen, gesicht, text, farbe)
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
	local front = teil("Autohausschild", V(0.4, 3.5, 34), V(SX - SB / 2 - 2.4, 18, AZ), RGB(200, 30, 40), M.SmoothPlastic, fAH)
	schrift(front, Enum.NormalId.Left, "VELOCITY MOTORS", RGB(255, 255, 255))
	local innen = teil("Wandlogo", V(0.2, 4, 26), V(SX + SB / 2 - 0.6, 9, AZ), RGB(200, 30, 40), M.SmoothPlastic, fAH, true)
	schrift(innen, Enum.NormalId.Left, "VELOCITY MOTORS", RGB(255, 255, 255))
	-- Strassenschild
	teil("Schildmast", V(1, 16, 1), V(16, 8, AZ - 30), RGB(60, 62, 66), M.Metal, fAH)
	local pylon = teil("Autohauspylon", V(1, 6, 12), V(16, 17, AZ - 30), RGB(200, 30, 40), M.SmoothPlastic, fAH)
	schrift(pylon, Enum.NormalId.Left, "VELOCITY\nMOTORS", RGB(255, 255, 255))
	schrift(pylon, Enum.NormalId.Right, "VELOCITY\nMOTORS", RGB(255, 255, 255))
	-- Ausstellungsplaetze (die Autos stellt das Spiel darauf)
	for _, a in { { "kleinwagen", SX - 14, AZ - 18 }, { "suv", SX - 14, AZ }, { "limousine", SX - 14, AZ + 18 },
		{ "sport", SX + 4, AZ - 18 }, { "renn", SX + 4, AZ }, { "supersport", SX + 4, AZ + 18 } } do
		local podest = teil("Podest", V(1, 16, 16), CFrame.new(a[2], 0.85, a[3]) * CFrame.Angles(0, 0, math.rad(90)), RGB(30, 30, 34), M.SmoothPlastic, fAH)
		podest.Shape = Enum.PartType.Cylinder
		local ring = teil("Podestlicht", V(1.02, 16.4, 16.4), CFrame.new(a[2], 0.8, a[3]) * CFrame.Angles(0, 0, math.rad(90)), RGB(255, 60, 70), M.Neon, fAH, true)
		ring.Shape = Enum.PartType.Cylinder
		local platz = teil("Ausstellungsplatz", V(2, 1, 2), CFrame.new(a[2], 1.35, a[3]) * CFrame.Angles(0, math.rad(-120), 0), RGB(255, 0, 0), M.SmoothPlastic, fAH, true)
		platz.Transparency = 1
		platz.CanQuery = false
		platz:SetAttribute("Typ", a[1])
		local spot = Instance.new("PointLight")
		spot.Range = 18
		spot.Brightness = 1
		spot.Parent = teil("Spot", V(2, 0.4, 2), V(a[2], 14.2, a[3]), RGB(255, 250, 235), M.Neon, fAH, true)
	end
	-- Verkaufstresen und Verkaeufer
	teil("Tresen", V(3, 3.6, 9), V(SX + 18, 2.4, AZ - 16), RGB(240, 240, 240), M.SmoothPlastic, fAH)
	teil("Tresenplatte", V(3.4, 0.3, 9.4), V(SX + 18, 4.35, AZ - 16), RGB(200, 30, 40), M.SmoothPlastic, fAH)
	local vk = teil("VerkaeuferPlatz", V(2, 1, 2), CFrame.new(SX + 21.5, 0.7, AZ - 16), RGB(255, 0, 0), M.SmoothPlastic, fAH, true)
	vk.Transparency = 1
	vk.CanQuery = false
	for _, z in { -6, 6 } do
		teil("Sessel", V(3, 2, 3), V(SX + 21, 1.6, AZ + z + 14), RGB(60, 60, 65), M.Fabric, fAH)
	end
	-- Abholplaetze fuer gekaufte Autos (Auto schaut zur Strasse)
	local buchten = Instance.new("Folder")
	buchten.Name = "AutohausBuchten"
	buchten.Parent = fAH
	for _, z in { -404, -392, -360, -348 } do
		local pos = V(42, Y_STRASSE, z)
		local b = teil("Abholplatz", V(10, 1, 18), CFrame.lookAt(pos, pos + V(-1, 0, 0)), RGB(255, 255, 0), M.SmoothPlastic, buchten, true)
		b.Transparency = 1
		b.CanQuery = false
		b.CanTouch = false
		linie(42, z - 6, 18, 0.4)
		linie(42, z + 6, 18, 0.4)
	end
	-- Fahnen
	for i = 0, 3 do
		local fx, fz = 14, AZ + 6 + i * 7
		teil("Fahnenmast", V(0.4, 14, 0.4), V(fx, 7, fz), RGB(200, 200, 205), M.Metal, fAH)
		teil("Fahne", V(0.1, 3, 4.5), V(fx, 12, fz + 2.3), (i % 2 == 0) and RGB(200, 30, 40) or RGB(255, 255, 255), M.Fabric, fAH, true)
	end
	table.insert(belegt, { 6, 152, -414, -338 })
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

-- ---------- Baustellen (Tempo 30 / 80) ----------
local function baustelle(name, x1, z1, x2, z2, kegelVon, kegelBis, kegelLinie, entlangX)
	local m = modell(name, fService)
	-- Bauzaun-Gelaende mit Bagger, Sandhaufen und Container
	local mx, mz = (x1 + x2) / 2, (z1 + z2) / 2
	teil("Baustellenboden", V(math.abs(x2 - x1), 0.4, math.abs(z2 - z1)), V(mx, 0.1, mz), RGB(150, 120, 85), M.Ground, m)
	local sand = teil("Sandhaufen", V(8, 10, 10), CFrame.new(mx - 6, 0.5, mz) * CFrame.Angles(0, 0, math.rad(90)), RGB(215, 190, 130), M.Sand, m)
	sand.Shape = Enum.PartType.Cylinder
	sand.Size = V(4, 12, 12)
	teil("Container", V(6, 6, 14), V(mx + 8, 3, mz - 4), RGB(220, 120, 30), M.Metal, m)
	-- Bagger
	local gelb = RGB(245, 190, 30)
	teil("Baggerkette", V(8, 2, 3), V(mx + 4, 1.2, mz + 8), RGB(40, 40, 40), M.Metal, m)
	teil("Baggerkette", V(8, 2, 3), V(mx + 4, 1.2, mz + 14), RGB(40, 40, 40), M.Metal, m)
	teil("Baggerkoerper", V(7, 4, 8), V(mx + 4, 4.2, mz + 11), gelb, M.SmoothPlastic, m)
	teil("Baggerkabine", V(3.5, 3.5, 4), V(mx + 2.5, 7.9, mz + 9.5), gelb, M.SmoothPlastic, m)
	teil("Baggerarm", V(1.2, 1.2, 10), CFrame.new(mx + 6, 8, mz + 5) * CFrame.Angles(math.rad(25), 0, 0), gelb, M.SmoothPlastic, m)
	teil("Baggerschaufel", V(3, 2, 2), V(mx + 6, 4, mz - 0.5), RGB(60, 60, 60), M.Metal, m)
	-- Leitkegel und Warnlichter am Strassenrand
	for pos = kegelVon, kegelBis, 8 do
		local x, z = entlangX and pos or kegelLinie, entlangX and kegelLinie or pos
		local kegel = teil("Leitkegel", V(1.2, 2.2, 1.2), V(x, 1.3, z), RGB(255, 110, 20), M.SmoothPlastic, m, true)
		local streifen = teil("Kegelstreifen", V(1.25, 0.4, 1.25), V(x, 1.7, z), RGB(255, 255, 255), M.SmoothPlastic, m, true)
		if (pos - kegelVon) % 24 == 0 then
			local warn = teil("Warnlicht", V(0.8, 0.8, 0.8), V(x, 2.8, z), RGB(255, 170, 0), M.Neon, m, true)
			warn.Shape = Enum.PartType.Ball
		end
	end
	-- Absperrbaken (rot-weiss)
	for i = 0, 3 do
		local x, z = entlangX and (kegelVon + i * 4) or (kegelLinie), entlangX and (kegelLinie) or (kegelVon + i * 4)
		teil("Bake", V(entlangX and 3 or 0.4, 1.4, entlangX and 0.4 or 3), V(x, 2, z), (i % 2 == 0) and RGB(220, 30, 30) or RGB(250, 250, 250), M.SmoothPlastic, m, true)
	end
	m:SetAttribute("Baustelle", true)
end
-- an der Westzufahrt (Westseite), Tempo 30
baustelle("BaustelleWest", -846, 360, -800, 440, 352, 448, -790.5, false)
table.insert(belegt, { -848, -790, 350, 450 })
-- an der Schnellstrasse (Suedseite), Tempo 80
baustelle("BaustelleAutobahn", 150, -495, 300, -472, 140, 310, -499, true)
table.insert(belegt, { 140, 310, -500, -470 })

-- ---------- Bestenlisten im Stadtpark ----------
do
	local m = modell("Bestenlisten", fService)
	local px, pz = blockMitte(1), blockMitte(4) -- Stadtpark
	for i, info in { { "Level", -16 }, { "Km", 0 }, { "Perfekt", 16 } } do
		local x = px + info[2]
		teil("Tafelfuss", V(1, 5, 1), V(x, Y_GEHWEG + 2.5, pz + 30), RGB(60, 62, 66), M.Metal, m)
		local tafel = teil("Bestenliste", V(14, 12, 0.6), V(x, Y_GEHWEG + 10, pz + 30), RGB(20, 24, 32), M.SmoothPlastic, m)
		tafel:SetAttribute("Liste", info[1])
	end
end

-- Haeuser entlang der neuen Wohnstrassen (nur wo Platz ist)
for _, w in WOHNSTRASSEN do
	local x1, z1, x2, z2 = w[1], w[2], w[3], w[4]
	local entlangX = z1 == z2
	local a, b = entlangX and math.min(x1, x2) or math.min(z1, z2), entlangX and math.max(x1, x2) or math.max(z1, z2)
	for pos = a + 30, b - 30, 40 do
		for _, seite in { -1, 1 } do
			local x, z, gierung
			if entlangX then
				x, z = pos, z1 + seite * 27
				gierung = seite < 0 and 0 or math.pi
			else
				x, z = x1 + seite * 27, pos
				gierung = seite < 0 and math.pi / 2 or -math.pi / 2
			end
			if frei(x - 17.5, x + 17.5, z - 17.5, z + 17.5) then
				haus(x, z, gierung, fVororte, 27, WB / 2)
				table.insert(belegt, { x - 17.5, x + 17.5, z - 17.5, z + 17.5 })
			end
		end
	end
	-- Laternen
	for pos = a + 20, b - 20, 80 do
		local lx, lz = entlangX and pos or x1 + WB / 2 + 1, entlangX and z1 + WB / 2 + 1 or pos
		if frei(lx - 1, lx + 1, lz - 1, lz + 1) then
			laterne(lx, lz, entlangX and V(0, 0, -1) or V(-1, 0, 0), 0)
		end
	end
end

-- ---------- Fahrschule (begehbar) ----------
local fs = modell("Fahrschule", fVorstadt)
local WEISSWAND = RGB(245, 245, 240)
local BLAU = RGB(30, 90, 180)
local vorneZ = FZ - FD / 2       -- Vorderwand (zur Landstrasse)
local hintenZ = FZ + FD / 2
local TUER_B, TUER_H = 10, 11

teil("Boden", V(FW, 0.4, FD), V(FX, 0.2, FZ), RGB(200, 195, 185), M.WoodPlanks, fs)
teil("Rueckwand", V(FW, FH, 1), V(FX, FH / 2, hintenZ - 0.5), WEISSWAND, M.SmoothPlastic, fs)
teil("Seitenwand", V(1, FH, FD), V(FX - FW / 2 + 0.5, FH / 2, FZ), WEISSWAND, M.SmoothPlastic, fs)
teil("Seitenwand", V(1, FH, FD), V(FX + FW / 2 - 0.5, FH / 2, FZ), WEISSWAND, M.SmoothPlastic, fs)
-- Vorderwand mit Tuer- und Fensteroeffnungen (Fenster sind durchsichtig)
local TUER_OEFF = { -TUER_B / 2, TUER_B / 2 }
local UNTEN = { { -27.5, -20.5 }, { -17.5, -10.5 }, { 10.5, 17.5 }, { 20.5, 27.5 } }
local OBEN = { { -27.5, -20.5 }, { -15.5, -8.5 }, { -3.5, 3.5 }, { 8.5, 15.5 }, { 20.5, 27.5 } }
local function wandBand(y0, y1, oeffnungen)
	table.sort(oeffnungen, function(a, b) return a[1] < b[1] end)
	local a = -FW / 2
	local function seg(x0, x1)
		if x1 - x0 < 0.1 then return end
		teil("Vorderwand", V(x1 - x0, y1 - y0, 1), V(FX + (x0 + x1) / 2, (y0 + y1) / 2, vorneZ + 0.5), WEISSWAND, M.SmoothPlastic, fs)
	end
	for _, o in oeffnungen do
		seg(a, o[1])
		a = o[2]
	end
	seg(a, FW / 2)
end
local unten = { TUER_OEFF }
for _, o in UNTEN do table.insert(unten, o) end
wandBand(0, 3.5, { TUER_OEFF })
wandBand(3.5, 9.5, unten)
wandBand(9.5, TUER_H, { TUER_OEFF })
wandBand(TUER_H, 19, {})
wandBand(19, 25, table.clone(OBEN))
wandBand(25, FH, {})
local function scheibe(o, y0, y1)
	local g = teil("Fensterglas", V(o[2] - o[1], y1 - y0, 0.3), V(FX + (o[1] + o[2]) / 2, (y0 + y1) / 2, vorneZ + 0.5), RGB(170, 210, 235), M.Glass, fs)
	g.Transparency = 0.6
end
for _, o in UNTEN do scheibe(o, 3.5, 9.5) end
for _, o in OBEN do scheibe(o, 19, 25) end
-- Zwischendecke und Dach
teil("Dach", V(FW + 1, 1, FD + 1), V(FX, FH + 0.5, FZ), RGB(120, 120, 125), M.Concrete, fs)
-- Blaue Zierstreifen aussen
teil("Streifen", V(FW + 0.6, 1.5, 0.3), V(FX, 15, vorneZ - 0.15), BLAU, M.SmoothPlastic, fs, true)
teil("Streifen", V(FW + 0.6, 1.5, 0.3), V(FX, 15, hintenZ + 0.15), BLAU, M.SmoothPlastic, fs, true)
teil("Streifen", V(0.3, 1.5, FD), V(FX - FW / 2 - 0.15, 15, FZ), BLAU, M.SmoothPlastic, fs, true)
teil("Streifen", V(0.3, 1.5, FD), V(FX + FW / 2 + 0.15, 15, FZ), BLAU, M.SmoothPlastic, fs, true)
-- Schild "DRIVING SCHOOL"
local schild = teil("Schild", V(44, 6, 0.8), V(FX, FH + 4, vorneZ + 0.6), BLAU, M.SmoothPlastic, fs)
local gui = Instance.new("SurfaceGui")
gui.Face = Enum.NormalId.Front
gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
gui.PixelsPerStud = 40
gui.Parent = schild
local text = Instance.new("TextLabel")
text.Size = UDim2.fromScale(1, 1)
text.BackgroundColor3 = BLAU
text.TextColor3 = RGB(255, 255, 255)
text.Text = "DRIVING SCHOOL"
text.Font = Enum.Font.GothamBlack
text.TextScaled = true
text.Parent = gui

-- ---------- Inneneinrichtung ----------
-- Koordinaten relativ zur Gebaeudemitte: lx (-31..31), lz (-19 vorne .. 19 hinten)
local OG = 15.5 -- Fussboden Obergeschoss
local function innen(name, gr, lx, y, lz, farbe, mat, keineKol)
	return teil(name, gr, V(FX + lx, y, FZ + lz), farbe, mat or M.SmoothPlastic, fs, keineKol)
end
local function schildText(part, gesicht, text, hinten, vorne, strich)
	local g = Instance.new("SurfaceGui")
	g.Face = gesicht
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 40
	g.Parent = part
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundColor3 = hinten
	l.TextColor3 = vorne
	l.Text = text
	l.Font = Enum.Font.GothamBold
	l.TextScaled = true
	l.Parent = g
	if strich then
		local s = Instance.new("UIStroke")
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Color = strich
		s.Thickness = 12
		s.Parent = l
	end
end
local HOLZ = RGB(150, 105, 70)
local HELLHOLZ = RGB(205, 170, 125)
local SCHWARZ = RGB(25, 25, 28)
local GRAU = RGB(120, 125, 130)
local WEISS2 = RGB(240, 240, 240)

local function stuhl(lx, y, lz, blick) -- blick: 1 = schaut nach +Z, -1 = nach -Z
	innen("Stuhl", V(2.2, 0.5, 2.2), lx, y + 1.6, lz, BLAU, M.Fabric)
	innen("Stuhlbein", V(0.4, 1.4, 0.4), lx, y + 0.7, lz, SCHWARZ, M.Metal)
	innen("Lehne", V(2.2, 2.4, 0.3), lx, y + 3, lz - blick * 1, BLAU, M.Fabric)
end
local function pflanze(lx, y, lz, gross)
	local s = gross and 1.5 or 1
	innen("Topf", V(1.6 * s, 1.6 * s, 1.6 * s), lx, y + 0.8 * s, lz, RGB(170, 90, 60), M.Concrete)
	local b = innen("Blaetter", V(3 * s, 3.4 * s, 3 * s), lx, y + 3 * s, lz, RGB(60, 140, 60), M.Grass)
	b.Shape = Enum.PartType.Ball
end
local function bildschirm(lx, y, lz)
	innen("Monitor", V(2.6, 1.7, 0.2), lx, y + 1.25, lz, SCHWARZ, M.SmoothPlastic)
	innen("Monitorfuss", V(0.4, 0.4, 0.8), lx, y + 0.2, lz, SCHWARZ, M.Metal)
	local bild = innen("Bild", V(2.3, 1.4, 0.05), lx, y + 1.25, lz - 0.12, RGB(70, 140, 220), M.Neon, true)
	bild.Transparency = 0.2
	innen("Tastatur", V(2.2, 0.15, 0.8), lx, y + 0.08, lz - 1.1, SCHWARZ, M.SmoothPlastic, true)
end
local function deckenpanel(lx, y, lz)
	local p = innen("Deckenpanel", V(6, 0.2, 3), lx, y, lz, RGB(255, 252, 240), M.Neon, true)
	local l = Instance.new("PointLight")
	l.Range = 22
	l.Brightness = 0.9
	l.Shadows = false
	l.Parent = p
end

-- Boeden: Fliesen im Empfang, Teppich im Theorieraum
innen("Fliesen", V(38.6, 0.1, 37.8), 11.7, 0.45, 0, RGB(225, 222, 215), M.Marble, true)
innen("Teppich", V(22.6, 0.1, 37.8), -19.7, 0.45, 0, RGB(70, 85, 110), M.Fabric, true)

-- Zwischendecke mit Loch fuer die Treppe (rechts hinten)
innen("Zwischendecke", V(55.5, 1, 38), -3.25, 15, 0, WEISSWAND, M.SmoothPlastic)
innen("Zwischendecke", V(6.5, 1, 16), 27.75, 15, -11, WEISSWAND, M.SmoothPlastic)
innen("Bodenbelag_OG", V(55.5, 0.1, 38), -3.25, 15.55, 0, RGB(185, 160, 120), M.WoodPlanks, true)

-- Treppe ins Obergeschoss
for k = 1, 14 do
	local oben = 0.4 + k * (OG - 0.4) / 14
	innen("Stufe", V(5, oben, 1.4), 27.5, oben / 2, -2 + (k - 0.5) * 1.4, RGB(170, 170, 175), M.Concrete)
end
innen("Handlauf", V(0.3, 0.3, 20), 24.8, 9.5, 7.5, GRAU, M.Metal)
innen("Gelaender", V(0.4, 3, 15), 24.3, OG + 1.5, 4.5, GRAU, M.Metal)
innen("Gelaender", V(6.5, 3, 0.4), 27.75, OG + 1.5, -3.2, GRAU, M.Metal)

-- Trennwand zum Theorieraum (mit Durchgang)
innen("Trennwand", V(0.6, 14.1, 27), -8, 7.45, -5.5, WEISSWAND, M.SmoothPlastic)
innen("Trennwand", V(0.6, 14.1, 5), -8, 7.45, 16.5, WEISSWAND, M.SmoothPlastic)
innen("Trennwand", V(0.6, 5.1, 6), -8, 11.95, 11, WEISSWAND, M.SmoothPlastic)
local raumschild = innen("Schild", V(0.2, 1.2, 5), -7.6, 10.4, 11, BLAU, M.SmoothPlastic, true)
schildText(raumschild, Enum.NormalId.Right, "CLASSROOM", BLAU, RGB(255, 255, 255))

-- Empfang: L-foermige Theke, Rueckwand mit Logo
innen("Theke", V(14, 4, 2.5), 4, 2.4, 6, HELLHOLZ, M.Wood)
innen("Theke", V(2.5, 4, 6), 12.25, 2.4, 8.5, HELLHOLZ, M.Wood)
innen("Thekenplatte", V(14.6, 0.4, 3), 4, 4.6, 6, RGB(50, 50, 55), M.Granite)
innen("Thekenplatte", V(3, 0.4, 6.6), 12.25, 4.6, 8.5, RGB(50, 50, 55), M.Granite)
innen("Thekenblende", V(14, 1.2, 0.2), 4, 3.2, 4.65, BLAU, M.SmoothPlastic, true)
bildschirm(0, 4.8, 6.8)
bildschirm(7, 4.8, 6.8)
innen("Drucker", V(2.4, 1.2, 2), 12.25, 5.4, 10.5, RGB(200, 200, 205), M.SmoothPlastic)
innen("Klingel", V(0.6, 0.3, 0.6), 9.5, 4.95, 5.4, RGB(200, 180, 60), M.Metal, true)
local logo = innen("Logowand", V(20, 6, 0.3), 4, 8, 18.75, BLAU, M.SmoothPlastic)
schildText(logo, Enum.NormalId.Front, "DRIVING SCHOOL\nReception", BLAU, RGB(255, 255, 255))

-- Prospektstaender neben der Tuer
innen("Prospektstaender", V(3, 5, 0.6), 8, 2.9, -17.5, GRAU, M.Metal)
for i, farbe in { RGB(220, 60, 60), RGB(60, 120, 220), RGB(240, 200, 60) } do
	innen("Prospekt", V(0.8, 1.1, 0.1), 8 - 1.8 + i * 0.9, 3.8, -17.85, farbe, M.SmoothPlastic, true)
end

-- Wartebereich: zwei Sofas, Teppich, Couchtisch, Wasserspender, Kaffeemaschine
innen("Wartezonen_Teppich", V(16, 0.1, 10), 18, 0.5, -12, RGB(160, 60, 50), M.Fabric, true)
innen("Sofa", V(10, 1.8, 3.5), 18, 1.3, -14.5, RGB(70, 70, 80), M.Fabric)
innen("Sofalehne", V(10, 3, 1), 18, 2.9, -16.6, RGB(70, 70, 80), M.Fabric)
innen("Sofa", V(3.5, 1.8, 8), 25.5, 1.3, -10, RGB(70, 70, 80), M.Fabric)
innen("Sofalehne", V(1, 3, 8), 27.6, 2.9, -10, RGB(70, 70, 80), M.Fabric)
innen("Couchtisch", V(5, 1.4, 3), 18, 1.1, -9.5, HELLHOLZ, M.Wood)
innen("Magazin", V(1.4, 0.1, 2), 17, 1.85, -9.5, RGB(220, 70, 70), M.SmoothPlastic, true)
innen("Magazin", V(1.4, 0.1, 2), 19, 1.85, -9.3, RGB(70, 120, 220), M.SmoothPlastic, true)
innen("Wasserspender", V(1.8, 4, 1.8), 29.5, 2.4, -5, WEISS2, M.SmoothPlastic)
local flasche = innen("Wasserflasche", V(1.4, 1.8, 1.4), 29.5, 5.3, -5, RGB(120, 180, 240), M.Glass)
flasche.Transparency = 0.3
innen("Kaffeetheke", V(4, 3.5, 2), 16, 2.15, 17.6, HOLZ, M.Wood)
innen("Kaffeemaschine", V(1.6, 2, 1.4), 15, 4.9, 17.6, SCHWARZ, M.Metal)
innen("Becher", V(0.5, 0.6, 0.5), 17, 4.2, 17.4, WEISS2, M.SmoothPlastic, true)
innen("Muelleimer", V(1.4, 2.2, 1.4), 11.5, 1.5, -17.5, GRAU, M.Metal)
pflanze(29.5, 0.4, -17.5, true)
pflanze(-5.5, 0.4, 17.5, true)

-- Infotafel und Verkehrsschild-Poster an der Trennwand (Seite Empfang)
local info = innen("Infotafel", V(0.2, 5, 7), -7.6, 7.5, -12, RGB(190, 150, 100), M.Wood, true)
schildText(info, Enum.NormalId.Right, "OPENING HOURS\nMon–Fri 8–18\nSat 9–14", RGB(190, 150, 100), RGB(30, 30, 30))
local p1 = innen("Poster", V(0.2, 4, 4), -7.6, 7.5, -3, RGB(200, 30, 30), M.SmoothPlastic, true)
schildText(p1, Enum.NormalId.Right, "STOP", RGB(200, 30, 30), RGB(255, 255, 255))
local p2 = innen("Poster", V(0.2, 4, 4), -7.6, 7.5, 3, RGB(255, 255, 255), M.SmoothPlastic, true)
schildText(p2, Enum.NormalId.Right, "50", RGB(255, 255, 255), RGB(20, 20, 20), RGB(200, 30, 30))

-- Theorieraum: 6 Pruefungsplaetze mit Bildschirm und Sitz, Lehrerpult, Tafel
for _, lz in { -13, -5, 3 } do
	for _, lx in { -26, -15.5 } do
		innen("Pruefungstisch", V(6, 0.4, 2.8), lx, 3.2, lz, HELLHOLZ, M.Wood)
		innen("Tischbein", V(0.4, 2.8, 2.4), lx - 2.7, 1.8, lz, GRAU, M.Metal)
		innen("Tischbein", V(0.4, 2.8, 2.4), lx + 2.7, 1.8, lz, GRAU, M.Metal)
		innen("Sichtschutz", V(6, 2, 0.2), lx, 4.4, lz + 1.3, RGB(200, 205, 215), M.SmoothPlastic)
		bildschirm(lx, 3.4, lz + 0.6)
		local sitz = teil("Pruefungsplatz", V(2.2, 0.6, 2.2), CFrame.new(FX + lx, 1.6, FZ + lz - 2.4) * CFrame.Angles(0, math.pi, 0), BLAU, M.Fabric, fs, false, "Seat")
		sitz:SetAttribute("Pruefungsplatz", true)
		innen("Lehne", V(2.2, 2.4, 0.3), lx, 3, lz - 3.5, BLAU, M.Fabric)
		innen("Stuhlbein", V(0.4, 1.0, 0.4), lx, 0.8, lz - 2.4, SCHWARZ, M.Metal)
	end
end
innen("Lehrerpult", V(8, 3, 3), -20, 1.9, 12, HOLZ, M.Wood)
innen("Laptop", V(2, 0.15, 1.4), -21, 3.5, 12, RGB(180, 180, 185), M.Metal, true)
stuhl(-20, 0.4, 14.6, -1)
local tafel = innen("Tafel", V(16, 6, 0.3), -19.5, 8, 18.85, RGB(250, 250, 250))
schildText(tafel, Enum.NormalId.Front, "THEORY LESSON\nPress E to start", RGB(250, 250, 250), RGB(30, 30, 30))
-- Buecherregal an der Seitenwand
innen("Regal", V(1.5, 8, 10), -30, 4.4, 10, HOLZ, M.Wood)
for reihe = 0, 2 do
	for i = 0, 7 do
		local farbe = ({ RGB(180, 50, 50), RGB(50, 90, 170), RGB(60, 140, 70), RGB(220, 180, 60) })[(i + reihe) % 4 + 1]
		innen("Buch", V(1, 1.6, 0.9), -29.6, 1.6 + reihe * 2.6, 6 + i * 1.1, farbe, M.SmoothPlastic, true)
	end
end
-- Schild-Poster an der linken Wand
for i, s in { { "YIELD", RGB(255, 255, 255), RGB(200, 30, 30) }, { "30", RGB(255, 255, 255), RGB(20, 20, 20) }, { "NO PARKING", RGB(40, 80, 170), RGB(255, 255, 255) } } do
	local pp = innen("Poster", V(0.2, 3.6, 3.6), -30.85, 8, -14 + i * 5, s[2], M.SmoothPlastic, true)
	schildText(pp, Enum.NormalId.Right, s[1], s[2], s[3], RGB(200, 30, 30))
end

-- Deckenleuchten Erdgeschoss
for _, lx in { -20, 2, 18 } do
	for _, lz in { -10, 8 } do
		deckenpanel(lx, 14.35, lz)
	end
end

-- Obergeschoss: Bueros mit Glaswand, Schreibtische, Aktenschraenke, Besprechung
for _, lx in { -24, -12, 0, 12 } do
	innen("Schreibtisch", V(6, 0.4, 3), lx, OG + 3, -12, WEISS2)
	innen("Tischbein", V(5.6, 2.6, 0.3), lx, OG + 1.4, -10.7, GRAU, M.Metal)
	bildschirm(lx, OG + 3.2, -12.5)
	stuhl(lx, OG, -9.3, -1)
end
local glas = innen("Glaswand", V(0.3, 13, 16), -2, OG + 6.6, 10.5, RGB(190, 220, 240), M.Glass)
glas.Transparency = 0.6
for _, lx in { -28, -24.5, -21 } do
	innen("Aktenschrank", V(3, 8, 2), lx, OG + 4, 17.5, GRAU, M.Metal)
end
innen("Besprechungstisch", V(10, 0.4, 5), -14, OG + 3, 6, HELLHOLZ, M.Wood)
innen("Tischfuss", V(1, 2.6, 1), -14, OG + 1.4, 6, GRAU, M.Metal)
for _, o in { -3, 3 } do
	stuhl(-14 + o, OG, 2.2, 1)
	stuhl(-14 + o, OG, 9.8, -1)
end
innen("Chefschreibtisch", V(8, 0.4, 4), 10, OG + 3, 12, HOLZ, M.Wood)
innen("Tischfuss", V(7.6, 2.6, 0.3), 10, OG + 1.4, 13.8, HOLZ, M.Wood)
bildschirm(10, OG + 3.2, 12.5)
stuhl(10, OG, 15.5, -1)
pflanze(20, OG, 17, true)
pflanze(-29, OG, -16, true)
for _, lx in { -20, 2, 18 } do
	for _, lz in { -10, 8 } do
		deckenpanel(lx, FH - 0.65, lz)
	end
end

-- Tuer, die sich mit E oeffnet
local tuer = teil("Tuer", V(TUER_B - 0.2, TUER_H - 0.2, 0.6), V(FX, 0.4 + (TUER_H - 0.2) / 2, vorneZ + 0.5), RGB(30, 40, 50), M.Glass, fs)
tuer.Transparency = 0.3
local prompt = Instance.new("ProximityPrompt")
prompt.ActionText = "Open"
prompt.ObjectText = "Door"
prompt.KeyboardKeyCode = Enum.KeyCode.E
prompt.MaxActivationDistance = 10
prompt.RequiresLineOfSight = false
prompt.HoldDuration = 0
prompt.Parent = tuer
local tuerSkript = Instance.new("Script")
tuerSkript.Name = "FahrschulTuer"
tuerSkript.Source = [==[
-- Oeffnet und schliesst die Fahrschultuer per E (ProximityPrompt)
local TweenService = game:GetService("TweenService")
local tuer = workspace:WaitForChild("Karte"):WaitForChild("Vorstadt"):WaitForChild("Fahrschule"):WaitForChild("Tuer")
local prompt = tuer:WaitForChild("ProximityPrompt")

local zu = tuer.CFrame
local breite = tuer.Size.X
local scharnier = zu * CFrame.new(-breite / 2, 0, 0)
local offen = scharnier * CFrame.Angles(0, math.rad(-90), 0) * CFrame.new(breite / 2, 0, 0)
local info = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local istOffen = false

prompt.Triggered:Connect(function()
	istOffen = not istOffen
	prompt.ActionText = istOffen and "Close" or "Open"
	TweenService:Create(tuer, info, { CFrame = istOffen and offen or zu }):Play()
end)

print("Fahrschultuer bereit")
]==]
tuerSkript.Parent = SSS

-- Parkplatz vor der Fahrschule (zwischen Querstrasse und Eingang)
local parkVon = 50
local PARK_B = 80   -- volle Blockbreite zwischen den Strassen
teil("Parkplatz", V(PARK_B, 1, vorneZ - parkVon), V(FX, Y_STRASSE - 0.5, (parkVon + vorneZ) / 2), ASPHALT, M.Asphalt, fs)
-- zwei Reihen Parkbuchten (10 breit); vor der Tuer bleibt ein Gehweg frei
local buchtOrdner = Instance.new("Folder")
buchtOrdner.Name = "Parkbuchten"
buchtOrdner.Parent = fs
local function bucht(x, z, uebung)
	local b = teil("Parkbucht", V(10, 1, 12), CFrame.new(x, Y_STRASSE, z), RGB(255, 255, 0), M.SmoothPlastic, buchtOrdner, true)
	b.Transparency = 1
	b.CanTouch = false
	b.CanQuery = false
	b:SetAttribute("Reihe", z < (parkVon + vorneZ) / 2 and "vorne" or "hinten")
	if uebung then b:SetAttribute("Uebung", true) end
end
local vorneReihe, hintenReihe = parkVon + 7, vorneZ - 7
for x = FX - 35, FX + 35, 10 do
	linie(x, vorneReihe, 0.4, 12)
	if math.abs(x - FX) > 6 then
		linie(x, hintenReihe, 0.4, 12)
	end
end
for x = FX - 30, FX + 30, 10 do
	bucht(x, vorneReihe, x == FX - 30)       -- die linke vordere Bucht ist die Uebungsbucht
	if math.abs(x - FX) > 11 then
		bucht(x, hintenReihe)
	end
end

-- ---------- Baeume auf der Wiese ----------
local function istFrei(x, z)
	if math.abs(x) < STADTRAND + 20 and math.abs(z) < STADTRAND + 20 then return false end -- Stadt
	if math.abs(z - HZ) < 32 then return false end                                       -- Schnellstrasse
	if x > 400 and x < 800 and math.abs(z) < 300 then return false end                   -- Siedlungen
	for _, r in belegt do                                                                -- alle Strassen
		if x > r[1] - 10 and x < r[2] + 10 and z > r[3] - 10 and z < r[4] + 10 then return false end
	end
	return true
end

local gesetzt, versuche = 0, 0
while gesetzt < 350 and versuche < 6000 do
	versuche += 1
	local x = math.random(-KARTE + 10, KARTE - 10)
	local z = math.random(-KARTE + 10, KARTE - 10)
	if istFrei(x, z) then
		baum(x, z)
		gesetzt += 1
	end
end

-- ---------- Spawn vor der Fahrschule (unsichtbar) ----------
for _, sp in workspace:GetDescendants() do
	if sp:IsA("SpawnLocation") then sp:Destroy() end
end
local spawn = Instance.new("SpawnLocation")
spawn.Name = "FahrschulSpawn"
spawn.Anchored = true
spawn.Enabled = true
spawn.Neutral = true
spawn.Duration = 0
spawn.Transparency = 1
spawn.CanCollide = false
spawn.Size = V(6, 1, 6)
spawn.CFrame = CFrame.new(FX, 0.7, vorneZ - 6)
spawn.Parent = workspace
for _, d in spawn:GetChildren() do
	if d:IsA("Decal") then d:Destroy() end
end

karte.Parent = workspace

-- ---------- Ampel-Steuerung (laeuft im Spiel) ----------
local steuerung = Instance.new("Script")
steuerung.Name = "AmpelSteuerung"
steuerung.Source = [==[
-- Schaltet alle Ampeln. NS = Nord-Sued, EW = Ost-West.
local ordner = workspace:WaitForChild("Karte"):WaitForChild("Ampeln")

local FARBEN = {
	Rot = Color3.fromRGB(255, 40, 40),
	Gelb = Color3.fromRGB(255, 190, 0),
	Gruen = Color3.fromRGB(40, 255, 80),
}
local AUS = Color3.fromRGB(30, 30, 30)

local function setze(richtung, phase, rot, gelb, gruen)
	local an = { Rot = rot, Gelb = gelb, Gruen = gruen }
	for _, ampel in ordner:GetChildren() do
		if ampel:GetAttribute("Richtung") == richtung then
			ampel:SetAttribute("Phase", phase)
			for name, leuchtet in an do
				local lampe = ampel:FindFirstChild(name)
				if lampe then
					lampe.Color = leuchtet and FARBEN[name] or AUS
					lampe.Material = leuchtet and Enum.Material.Neon or Enum.Material.SmoothPlastic
				end
			end
		end
	end
end

local GRUEN_ZEIT = 12

setze("EW", "Rot", true, false, false)
while true do
	setze("NS", "RotGelb", true, true, false)  task.wait(1.5)
	setze("NS", "Gruen", false, false, true)   task.wait(GRUEN_ZEIT)
	setze("NS", "Gelb", false, true, false)    task.wait(3)
	setze("NS", "Rot", true, false, false)     task.wait(2)
	setze("EW", "RotGelb", true, true, false)  task.wait(1.5)
	setze("EW", "Gruen", false, false, true)   task.wait(GRUEN_ZEIT)
	setze("EW", "Gelb", false, true, false)    task.wait(3)
	setze("EW", "Rot", true, false, false)     task.wait(2)
end
]==]
steuerung.Parent = SSS

-- =====================================================================
--  GRAFIK: Licht, Atmosphaere, Nachbearbeitung, Gelaende mit Grashalmen
-- =====================================================================
local Lighting = game:GetService("Lighting")
pcall(function() Lighting.Technology = Enum.Technology.Future end) -- beste Licht- und Schattenqualitaet
Lighting.GlobalShadows = true
Lighting.Brightness = 3
Lighting.ClockTime = 14.5
Lighting.GeographicLatitude = 48
Lighting.Ambient = RGB(70, 70, 80)
Lighting.OutdoorAmbient = RGB(120, 125, 135)
Lighting.EnvironmentDiffuseScale = 1
Lighting.EnvironmentSpecularScale = 1
Lighting.ShadowSoftness = 0.15
Lighting.ExposureCompensation = 0

for _, alt in Lighting:GetChildren() do
	if alt:IsA("PostEffect") or alt:IsA("Atmosphere") or alt:IsA("Sky") then alt:Destroy() end
end
local atmo = Instance.new("Atmosphere")
atmo.Density = 0.28
atmo.Offset = 0.2
atmo.Color = RGB(200, 210, 225)
atmo.Decay = RGB(110, 120, 140)
atmo.Glare = 0.15
atmo.Haze = 1.2
atmo.Parent = Lighting
local himmel = Instance.new("Sky")
himmel.SunAngularSize = 14
himmel.Parent = Lighting
local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.5
bloom.Size = 24
bloom.Threshold = 1.6
bloom.Parent = Lighting
local farbe = Instance.new("ColorCorrectionEffect")
farbe.Saturation = 0.12
farbe.Contrast = 0.08
farbe.Brightness = 0.02
farbe.TintColor = RGB(255, 250, 242)
farbe.Parent = Lighting
local strahlen = Instance.new("SunRaysEffect")
strahlen.Intensity = 0.04
strahlen.Spread = 0.6
strahlen.Parent = Lighting
local tiefe = Instance.new("DepthOfFieldEffect")
tiefe.FarIntensity = 0.12
tiefe.FocusDistance = 250
tiefe.InFocusRadius = 200
tiefe.NearIntensity = 0
tiefe.Parent = Lighting

-- Gelaende: echtes Gras mit Halmen statt einer flachen Platte
local gelaende = workspace.Terrain
gelaende:Clear()
local wiese = fBoden:FindFirstChild("Wiese")
if wiese then wiese:Destroy() end
-- Grasoberflaeche endet bei y = 0, knapp unter dem Asphalt (0.2): Autos rollen auf der Fahrbahn
local GRAS_Y = -4
gelaende:FillBlock(CFrame.new(0, GRAS_Y, 0), V(KARTE * 2, 4, KARTE * 2), M.Grass)
pcall(function() gelaende.Decoration = true end)
gelaende:SetMaterialColor(M.Grass, RGB(95, 140, 65))
-- unter Strassen, Gehwegen und Parkplaetzen das Gelaende ganz entfernen: so kann weder Gras
-- durch den Asphalt wachsen noch die Gelaendeoberflaeche ueber Fahrbahn und Markierungen ragen
local function unterGras(teilchen)
	local cf, gr = teilchen.CFrame, teilchen.Size
	if teilchen.Shape == Enum.PartType.Cylinder then
		gelaende:FillCylinder(CFrame.new(cf.Position.X, GRAS_Y, cf.Position.Z), 4, gr.Y / 2, M.Air)
	else
		gelaende:FillBlock(CFrame.new(cf.Position.X, GRAS_Y, cf.Position.Z) * cf.Rotation, V(gr.X, 4, gr.Z), M.Air)
	end
end
for _, t in fStrassen:GetDescendants() do
	if t:IsA("BasePart") and t.Position.Y < 2 and (t.Size.X > 8 or t.Size.Z > 8) then
		unterGras(t)
	end
end
for _, name in { "Parkplatz", "Boden", "Depothof", "Pizzaparkplatz", "Sockel", "Einfahrt", "Weg", "Autohausplatz", "Tankstellenplatz", "Baustellenboden" } do
	for _, t in karte:GetDescendants() do
		if t.Name == name and t:IsA("BasePart") then unterGras(t) end
	end
end
for _, t in fVorstadt:GetDescendants() do
	if t.Name == "Querstrasse" or t.Name == "Laengsstrasse" or t.Name == "Siedlungsstrasse" then unterGras(t) end
end
-- Loecher schliessen: das Ausschneiden laesst an Teilkanten schmale Spalten ohne Boden zurueck.
-- Jede 4er-Voxelspalte, unter der weder ein Teil noch Gelaende liegt, wird wieder mit Gras gefuellt.
task.spawn(function() -- laeuft im Hintergrund, damit Studio nicht einfriert
	task.wait(1)
	local lochStrahl = RaycastParams.new()
	lochStrahl.FilterType = Enum.RaycastFilterType.Exclude
	lochStrahl.FilterDescendantsInstances = { karte:FindFirstChild("Kartenrand") } -- Sicherheitsboden zaehlt nicht als Boden
	local loecher = 0
	local ECKEN = { V(0, 0, 0), V(1.5, 0, 1.5), V(-1.5, 0, -1.5), V(1.5, 0, -1.5), V(-1.5, 0, 1.5) }
	for cx = -KARTE, KARTE, 4 do -- -850 liegt auf der Voxelmitte (4k+2)
		for cz = -KARTE, KARTE, 4 do
			for _, o in ECKEN do
				if not workspace:Raycast(V(cx, 60, cz) + o, V(0, -80, 0), lochStrahl) then
					gelaende:FillBlock(CFrame.new(cx, GRAS_Y, cz), V(4, 4, 4), M.Grass)
					loecher += 1
					break
				end
			end
		end
		if cx % 40 == 30 then task.wait() end
	end
	print("Gelaendeloecher geschlossen: " .. loecher)
end)
-- unsichtbarer Kartenrand und ein Sicherheitsboden: niemand faellt oder fliegt aus der Karte
local rand = Instance.new("Folder")
rand.Name = "Kartenrand"
rand.Parent = karte
local function randTeil(name, gr, pos)
	local p = Instance.new("Part")
	p.Name, p.Size, p.Position = name, gr, pos
	p.Anchored, p.Transparency, p.CastShadow = true, 1, false
	p.Parent = rand
end
randTeil("Wand", V(4, 400, KARTE * 2 + 8), V(KARTE + 2, 180, 0))
randTeil("Wand", V(4, 400, KARTE * 2 + 8), V(-KARTE - 2, 180, 0))
randTeil("Wand", V(KARTE * 2 + 8, 400, 4), V(0, 180, KARTE + 2))
randTeil("Wand", V(KARTE * 2 + 8, 400, 4), V(0, 180, -KARTE - 2))
randTeil("Sicherheitsboden", V(KARTE * 2 + 4, 2, KARTE * 2 + 4), V(0, -9, 0))

local wolken = gelaende:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
wolken.Cover = 0.55
wolken.Density = 0.7
wolken.Parent = gelaende

print("Karte fertig! Teile: " .. anzahl)
