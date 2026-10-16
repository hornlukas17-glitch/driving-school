-- Driving School: Update auf v37 (Chaos-Fahrschule, enthält auch v36 = neues Fahrschulauto) – in die Studio-Befehlszeile einfügen, Enter.
-- Geht von v35 oder v36 aus; schon erledigte Schritte werden übersprungen.
-- Danach: dist/mesh/Fahrschulwagen.obj mit dem 3D-Importer importieren, Modell "Fahrschulwagen" in den ServerStorage.
local function ersetze(src, alt, neu)
	local a, b = string.find(src, alt, 1, true)
	assert(a, "nicht gefunden: " .. alt:sub(1, 60))
	assert(not string.find(src, alt, b + 1, true), "mehrfach: " .. alt:sub(1, 60))
	return src:sub(1, a - 1) .. neu .. src:sub(b + 1)
end
local ergebnis = {}
local function schritt(name, f)
	local ok, fehler = pcall(f)
	table.insert(ergebnis, (ok and "OK     " or "FEHLER ") .. name .. (ok and "" or (": " .. tostring(fehler))))
end
schritt("Auto (neue Karosserie fuers Fahrschulauto)", function()
local s = game.ServerScriptService.FuehrerscheinServer.Auto
if string.find(s.Source, "function Auto.rundeKarosserie", 1, true) then return end
local src = s.Source
local start = #src
src = ersetze(src, [===[

local R = 1.3        -- wheel radius
]===], [===[

-- New driving school body (Lukas' own design, tools/mesh/fahrschulwagen.py -> dist/mesh/Fahrschulwagen.obj).
-- If the imported model "Fahrschulwagen" is in ServerStorage, the lesson car (and the pizza car) look like it.
-- Only the looks change: chassis, wheels, seats and the colliding parts stay exactly the same.
local NEU_SICHTBAR = {} -- block parts that stay visible inside the new body
for _, n in { "Armaturenbrett", "Tacho", "Lenkrad", "Display", "Schalthebel", "Sitzflaeche", "Rueckenlehne", "Kopfstuetze",
	"Ruecksitzbank", "Ruecksitzlehne", "Mittelkonsole", "Dachschild", "Kennzeichen" } do
	NEU_SICHTBAR[n] = true
end
local NEU_BEHALTEN = { Kofferraumdeckel = true } -- invisible, but other code uses it (pizza job: goods at the back)
local FAHRSCHUL_WEISS = Color3.fromRGB(242, 243, 246)

local R = 1.3        -- wheel radius
]===])
src = ersetze(src, [===[
function Auto.bauen(cf, farbe, dachText)
	local vorlage = game:GetService("ServerStorage"):FindFirstChild("Limousine")
	local rund = vorlage ~= nil
]===], [===[
function Auto.bauen(cf, farbe, dachText)
	local SS = game:GetService("ServerStorage")
	local neuDef = Auto.KAROSSERIEN and Auto.KAROSSERIEN.fahrschule
	local neuVorlage = neuDef and SS:FindFirstChild(neuDef.vorlage)
	if neuVorlage and not Auto.meshTeil(neuVorlage, "Karosserie") then neuVorlage = nil end
	local neu = neuVorlage ~= nil
	if neu and not dachText then farbe = FAHRSCHUL_WEISS end -- driving school livery: white with red/blue stripes
	local vorlage = not neu and SS:FindFirstChild("Limousine") or nil
	local rund = vorlage ~= nil
]===])
src = ersetze(src, [===[
	-- body part welded to the chassis; kollision = can hit walls (only parts above the wheels)
	local function k(name, gr, lage, f, mat, opt)
]===], [===[
	-- body part welded to the chassis; kollision = can hit walls (only parts above the wheels)
	local versteckt = {} -- block parts the new body replaces
	local function k(name, gr, lage, f, mat, opt)
]===])
src = ersetze(src, [===[
		w.Part1 = p
		w.Parent = p
		return p
	end
]===], [===[
		w.Part1 = p
		w.Parent = p
		if neu and not opt.sichtbar and not NEU_SICHTBAR[name] then versteckt[p] = true end
		return p
	end
]===])
src = ersetze(src, [===[
	for _, seite in { { -7.83, Enum.NormalId.Front }, { 7.83, Enum.NormalId.Back } } do
		local schild = k("Kennzeichen", V3(2.6, 0.75, 0.08), ort(seite[1] < 0 and "KennzeichenVorne" or "KennzeichenHinten", 1, 0, 1.85, seite[1]), Color3.new(1, 1, 1), nil, { schatten = false })
		local g = Instance.new("SurfaceGui")
]===], [===[
	for _, seite in { { -7.83, Enum.NormalId.Front }, { 7.83, Enum.NormalId.Back } } do
		local lage = ort(seite[1] < 0 and "KennzeichenVorne" or "KennzeichenHinten", 1, 0, 1.85, seite[1])
		if neu and neuDef.kennzeichen then
			local kz = neuDef.kennzeichen[seite[1] < 0 and "vorne" or "hinten"]
			lage = at(0, kz[1], kz[2])
		end
		local schild = k("Kennzeichen", V3(2.6, 0.75, 0.08), lage, Color3.new(1, 1, 1), nil, { schatten = false })
		local g = Instance.new("SurfaceGui")
]===])
src = ersetze(src, [===[
	-- ---------- roof sign "STUDENT DRIVER" ----------
	local dach = k("Dachschild", V3(3.8, 1.3, 0.9), at(0, 6.7, 1.4), Color3.fromRGB(245, 205, 40))
	for _, gesicht in { Enum.NormalId.Front, Enum.NormalId.Back } do
]===], [===[
	-- ---------- roof sign "STUDENT DRIVER" ----------
	local ds = neu and neuDef.dachschild
	local dach
	if ds then
		-- on the new roof exactly where Lukas' model has its sign: white box, blue panel, white letters
		dach = k("Dachschild", V3(ds.breite, 1.15, ds.tiefe), at(0, ds.y + 0.575, ds.z), dachText and Color3.fromRGB(245, 205, 40) or Color3.fromRGB(245, 246, 248))
	else
		dach = k("Dachschild", V3(3.8, 1.3, 0.9), at(0, 6.7, 1.4), Color3.fromRGB(245, 205, 40))
	end
	for _, gesicht in { Enum.NormalId.Front, Enum.NormalId.Back } do
]===])
src = ersetze(src, [===[
		l.TextScaled = true
		l.TextColor3 = Color3.fromRGB(20, 20, 20)
		l.Parent = g
	end

	-- ---------- round body from the 3D model ----------
]===], [===[
		l.TextScaled = true
		l.TextColor3 = Color3.fromRGB(20, 20, 20)
		l.Parent = g
		if ds and not dachText then
			g.PixelsPerStud = 60
			g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			l.Text = "DRIVING SCHOOL"
			l.TextColor3 = Color3.new(1, 1, 1)
			l.BackgroundTransparency = 0
			l.BackgroundColor3 = Color3.fromRGB(25, 60, 170)
			l.AnchorPoint = Vector2.new(0.5, 0.5)
			l.Position = UDim2.fromScale(0.5, 0.5)
			l.Size = UDim2.fromScale(0.94, 0.78)
			Instance.new("UICorner", l).CornerRadius = UDim.new(0.15, 0)
			local rand = Instance.new("UIPadding")
			rand.PaddingTop, rand.PaddingBottom = UDim.new(0.12, 0), UDim.new(0.12, 0)
			rand.Parent = l
		end
	end

	-- ---------- round body from the 3D model ----------
]===])
src = ersetze(src, [===[
				local w = Instance.new("WeldConstraint")
				w.Part0, w.Part1 = chassis, mp
				w.Parent = mp
			end
		end
	end
]===], [===[
				local w = Instance.new("WeldConstraint")
				w.Part0, w.Part1 = chassis, mp
				w.Parent = mp
			end
		end
	end

	-- ---------- new driving school body (Lukas' model) ----------
	if neu then
		Auto.rundeKarosserie(m, chassis, cf, neuDef, neuVorlage, farbe, function(name, gr, lage, f, mat, opt)
			opt = opt or {}
			opt.sichtbar = true
			return k(name, gr, lage, f, mat, opt)
		end, neuDef.anbau, dachText and { streifen_blau = true, streifen_rot = true } or nil)
		-- old block body: parts that only looked go away; colliding ones stay invisible (crashes feel the same)
		for p in versteckt do
			if p.CanCollide or NEU_BEHALTEN[p.Name] then
				p.Transparency = 1
				p.CastShadow = false
				for _, kind in p:GetChildren() do
					if not kind:IsA("WeldConstraint") then kind:Destroy() end
				end
			else
				p:Destroy()
			end
		end
	end
]===])
src = ersetze(src, [===[
	rueckglas = { farbe = Color3.fromRGB(110, 8, 12), mat = Enum.Material.SmoothPlastic, glanz = 0.3 },
}
]===], [===[
	rueckglas = { farbe = Color3.fromRGB(110, 8, 12), mat = Enum.Material.SmoothPlastic, glanz = 0.3 },
	streifen_blau = { farbe = Color3.fromRGB(25, 60, 170), mat = Enum.Material.SmoothPlastic, glanz = 0.05 },
	streifen_rot = { farbe = Color3.fromRGB(200, 25, 32), mat = Enum.Material.SmoothPlastic, glanz = 0.05 },
}
]===])
src = ersetze(src, [===[
	streifen_rot = { farbe = Color3.fromRGB(200, 25, 32), mat = Enum.Material.SmoothPlastic, glanz = 0.05 },
}

local function meshTeil(vorlage, name)
]===], [===[
	streifen_rot = { farbe = Color3.fromRGB(200, 25, 32), mat = Enum.Material.SmoothPlastic, glanz = 0.05 },
}
Auto.KAROSSERIEN = KAROSSERIEN

local function meshTeil(vorlage, name)
]===])
src = ersetze(src, [===[
		end
	end
end

]===], [===[
		end
	end
end

-- Round body from the imported 3D model: mesh parts (body, glass, lights, livery ...) and the generated
-- attachments (indicators, seams, plates ...). k = the caller's part factory (welds to the chassis).
-- ohne = arts to leave out (e.g. the driving school stripes on the pizza car).
function Auto.rundeKarosserie(m, chassis, cf, rundDef, rundVorlage, farbe, k, zusatz, ohne)
	ohne = ohne or {}
	local function at(x, y, z) return cf * CFrame.new(x, y, z) end
	local function v3(t) return V3(t[1], t[2], t[3]) end
	local drehung = rundDef.drehung or Auto.MESH_DREHUNG
	if rundDef.autodrehung then drehung = Auto.drehungErkennen(rundDef, rundVorlage) or drehung end
	for name, d in rundDef.mesh do
		local quelle = not (d.a and ohne[d.a]) and meshTeil(rundVorlage, name)
		if quelle then
			local mp = quelle:Clone()
			mp.Name = name == "Karosserie" and "Karosserie" or ("Rund_" .. name)
			mp.Anchored = false
			mp.CanCollide = false
			mp.CanTouch = false
			mp.Massless = true
			mp.Size = v3(d.groesse)
			mp.CFrame = at(d.mitte[1], d.mitte[2], d.mitte[3]) * CFrame.Angles(0, math.rad(drehung), 0)
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
					licht.Face = (drehung % 360 == 180) and Enum.NormalId.Back or Enum.NormalId.Front
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
	for _, t in zusatz do
		if ohne[t.a] then continue end
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
end
Auto.meshTeil = meshTeil

-- Does the 3D importer hand us the body turned around? Compare where the part that sits furthest to the front
-- or back (e.g. the headlights) lies relative to the body in the imported model and in the generator data.
local drehungCache = setmetatable({}, { __mode = "k" })
function Auto.drehungErkennen(rundDef, vorlage)
	if drehungCache[vorlage] then return drehungCache[vorlage] end
	local basis = meshTeil(vorlage, "Karosserie")
	local kd = rundDef.mesh.Karosserie
	if not basis or not kd then return nil end
	local bester, abstand = nil, 0
	for name, d in rundDef.mesh do
		local dz = d.mitte[3] - kd.mitte[3]
		if name ~= "Karosserie" and math.abs(dz) > abstand and meshTeil(vorlage, name) then bester, abstand = name, math.abs(dz) end
	end
	if not bester or abstand < 1 then return nil end
	local soll = rundDef.mesh[bester].mitte[3] - kd.mitte[3]
	local ist = basis.CFrame:PointToObjectSpace(meshTeil(vorlage, bester).Position).Z
	local ergebnis = (soll * ist < 0) and 180 or 0
	drehungCache[vorlage] = ergebnis
	return ergebnis
end

]===])
src = ersetze(src, [===[
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
		-- lights, grille, mirrors ... (positions come from the generator);
]===], [===[
		end
		-- lights, grille, mirrors ... (positions come from the generator);
]===])
src = ersetze(src, [===[
		end
		for _, t in zusatz do
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
]===], [===[
		end
		Auto.rundeKarosserie(m, chassis, cf, rundDef, rundVorlage, farbe, k, zusatz)
		if rundDef.spoiler then
]===])
assert(#src - start == 5216, "Delta falsch: " .. (#src - start))
s.Source = src
end)
schritt("Karosserien (Eintrag fahrschule)", function()
	local s = game.ServerScriptService.FuehrerscheinServer.Karosserien
	local src = s.Source
	if string.find(src, "\tfahrschule = {", 1, true) then return end
	local ende = assert(string.find(src, "\n}%s*$"), "Ende der Tabelle nicht gefunden")
	s.Source = src:sub(1, ende) .. [=====[
	fahrschule = {
		vorlage = "Fahrschulwagen",
		mesh = {
			Glas = { groesse = { 7.0507, 2.2561, 10.6513 }, mitte = { -0.0041, 4.8071, 1.7671 } },
			Heckpartie = { groesse = { 7.0896, 5.1011, 7.8364 }, mitte = { 0.0008, 3.4147, 3.4722 } },
			Karosserie = { groesse = { 8.2565, 5.1872, 8.6913 }, mitte = { -0.0002, 3.2614, -3.6055 } },
			LichtH = { groesse = { 6.6918, 1.2096, 1.1444 }, mitte = { -0.0002, 3.6299, 6.3954 }, n = "Ruecklicht", a = "neon_rot" },
			LichtV = { groesse = { 6.4881, 0.6581, 0.7978 }, mitte = { 0.0027, 2.8561, -7.0416 }, n = "Scheinwerfer", a = "scheinwerfer" },
			Verkleidung = { groesse = { 8.2572, 4.868, 15.2704 }, mitte = { 0.0001, 3.0987, -0.2985 } },
			Radhaus = { groesse = { 6.9, 2.1741, 12.8386 }, mitte = { 0, 1.833, 0 }, n = "Radhaus", a = "schwarz" },
			StreifenBlau = { groesse = { 7.1361, 1.6821, 9.2038 }, mitte = { 0, 2.6808, 1.6018 }, n = "Streifen", a = "streifen_blau" },
			StreifenRot = { groesse = { 7.0554, 1.6581, 9.0042 }, mitte = { 0, 3.2696, 1.5018 }, n = "Streifen", a = "streifen_rot" },
			HaubeRot = { groesse = { 0.4013, 3.3908, 4.019 }, mitte = { -1.1507, 2.5792, -5.3607 }, n = "Streifen", a = "streifen_rot" },
			HaubeBlau = { groesse = { 0.4013, 3.4083, 4.0186 }, mitte = { -0.6205, 2.588, -5.3608 }, n = "Streifen", a = "streifen_blau" },
		},
		anbau = {
			{ n = "Blinker", a = "blinker", g = { 0.38, 0.22, 0.1 }, p = { 3.047, 2.623, -6.914 }, s = true },
			{ n = "Blinker", a = "blinker", g = { 0.4, 0.2, 0.1 }, p = { 1.389, 3.494, 6.91 }, s = true },
			{ n = "Blinker", a = "blinker", g = { 0.45, 0.08, 0.08 }, p = { 3.879, 3.752, -2.61 }, s = true },
		},
		kollision = {
			{ g = { 7, 0.5, 15 }, p = { 0, 2.95, -0.2 } },
			{ g = { 6, 1.4, 7.5 }, p = { 0, 4.4, 0.8 } },
		},
		dachschild = { z = 2.068, tiefe = 0.991, breite = 5.071, y = 5.935 },
		autodrehung = true,
		kennzeichen = { vorne = { 1.55, -7.952 }, hinten = { 2.55, 7.449 } },
		spoiler = { 6.235, 5.6, 0.4 },
	},]=====] .. src:sub(ende + 1)
end)
schritt("Client (Versionsnummer)", function()
	local s = game.StarterPlayer.StarterPlayerScripts.FuehrerscheinClient
	if string.find(s.Source, "_G.ChaosBanner = chaosBanner", 1, true) then return end -- already v37
	s.Source = s.Source:gsub("client v%d+ loaded", "client v36 loaded"):gsub("start screen v%d+ loading", "start screen v36 loading")
end)

schritt("Chaos (neues Modul)", function()
	local server = game.ServerScriptService.FuehrerscheinServer
	local m = server:FindFirstChild("Chaos") or Instance.new("ModuleScript")
	m.Name = "Chaos"
	m.Source = [=====[
-- Chaos Driving School: crazy instructors and random chaos events during lessons.
-- IMPORTANT: nothing here touches the car physics. All event objects are anchored,
-- never collide and are only checked by distance (same box test as for pedestrians).
local RunService = game:GetService("RunService")

local Chaos = {}
local ctx -- { fahrEvent, geldGeben }

local BONUS = 15        -- coins for dodging an event
local BONUS_UFO = 25    -- coins for driving through the UFO beam
Chaos.BONUS, Chaos.BONUS_UFO = BONUS, BONUS_UFO

-- ---------------------------------------------------------------
-- Instructor personalities (a random one per lesson)
-- ---------------------------------------------------------------
Chaos.LEHRER = {
	{
		id = "pete", name = "Panic Pete",
		haut = Color3.fromRGB(235, 195, 160), oberteil = Color3.fromRGB(245, 200, 40), hose = Color3.fromRGB(70, 70, 90),
		start = { "Oh no, oh no, a REAL car?! Okay. Breathe, Pete. BREATHE.", "I wore three seatbelts today. Just in case.", "Please drive slowly. Like, snail slowly. Like, parked." },
		fehler = { "AAAAH! WHY?!", "My heart! My poor heart!", "I KNEW this would happen!", "I'm calling my mom!" },
		unfall = { "AAAAAAAAAAAAH!!!", "WE'RE ALL GONNA... oh. We're fine.", "I SAW MY WHOLE LIFE! It was boring!" },
		lob = { "You... did it? WE'RE ALIVE!", "Okay that was good. I'm still shaking.", "No screaming needed! A new record!" },
		leerlauf = { "Is that a bird? IS IT GOING TO HIT US?", "Do you smell that? Is the car on fire? No? Okay.", "Can we go slower? Can we go backwards?", "I'm fine. Everything is fine. *sweats*" },
		event = { "WHAT IS THAT?!", "THIS IS NOT IN THE TEXTBOOK!", "I KNEW TODAY WAS CURSED!" },
		gag = { titel = "🛍️ PANIC ATTACK", text = "Panic Pete is breathing into a paper bag.", sagt = "*huff* *puff* I'm okay... *huff*" },
		ende_gut = { "We survived! I'm going to lie down now." },
		ende_schlecht = { "I need a vacation. A LONG one." },
	},
	{
		id = "sam", name = "Sleepy Sam",
		haut = Color3.fromRGB(200, 150, 110), oberteil = Color3.fromRGB(110, 150, 220), hose = Color3.fromRGB(110, 150, 220),
		start = { "*yawn* ...wake me up when we're there. Zzz", "Hi... I'm Sam... I worked the night shift... Zzz", "Just follow the gates... I'll be... right... Zzz" },
		fehler = { "Hm? Wha... did we crash? No? Zzz", "Five more minutes, mom...", "*snort* ...I saw nothing." },
		unfall = { "HUH?! I'm awake! I'm awake!", "WHO TURNED ON THE EARTHQUAKE?!", "...was that my alarm clock?" },
		lob = { "Nice... *snore*", "Smooth... like a pillow...", "Good... job... Zzz" },
		leerlauf = { "Zzzzz...", "*snoooooore*", "Mmm... pancakes...", "*mumbles* ...no, the purple llama..." },
		event = { "...is that real or am I dreaming?", "Zzz... wait, WHAT?", "I dreamed about this once." },
		gag = { titel = "🥞 SLEEP TALKING", text = "Sleepy Sam is ordering pancakes in his sleep.", sagt = "Twelve pancakes... extra syrup... Zzz" },
		ende_gut = { "Are we there? Great. *yawn* Good night." },
		ende_schlecht = { "Let's try again... after my nap." },
	},
	{
		id = "gerti", name = "Grandma Gerti", frau = true,
		haut = Color3.fromRGB(240, 205, 180), oberteil = Color3.fromRGB(150, 90, 170), hose = Color3.fromRGB(90, 70, 110),
		start = { "Hello sweetie! In my day we drove tractors to school. Uphill. Both ways!", "Oh, what a lovely car! Buckle up, dear.", "Have a cookie before we start, sweetie! 🍪" },
		fehler = { "Oh dear, oh dear!", "Even my cat drives better, sweetie.", "Tsk tsk tsk. Your grandpa would be shocked." },
		unfall = { "Goodness gracious! My knitting!", "Oh my! My teeth flew out!", "Sweetie, that was a CAR, not a cookie!" },
		lob = { "Wonderful, dear! Have a cookie! 🍪", "So proud of you, sweetie!", "Lovely! Just like my late husband Herbert." },
		leerlauf = { "Did I ever tell you about my cat, Mr. Whiskers?", "You look hungry. Eat something!", "Back in 1962 there were no traffic lights. Only vibes.", "Is it cold in here? Take my scarf, dear." },
		event = { "Oh look, how lovely!", "Goodness! I have never seen that before. Well, once. In 1974.", "Careful, sweetie!" },
		gag = { titel = "🧶 KNITTING TIME", text = "Grandma Gerti is knitting a cover for your steering wheel.", sagt = "Hold still, dear, I need to measure your hands!" },
		ende_gut = { "Well done, sweetie! Cookies for everyone!" },
		ende_schlecht = { "Oh dear. Let's have some tea and try again." },
	},
	{
		id = "kevin", name = "Coach Kevin",
		haut = Color3.fromRGB(180, 125, 90), oberteil = Color3.fromRGB(210, 40, 40), hose = Color3.fromRGB(30, 30, 35),
		start = { "LET'S GOOO! Today we drive like CHAMPIONS! 💪", "Did you stretch? NO? We drive anyway! LET'S GO!", "Gas pedal day! Never skip gas pedal day!" },
		fehler = { "THAT'S A REP! Do it again, but CORRECTLY!", "Pain is temporary, mistakes are FOREVER!", "DROP AND GIVE ME TWENTY! ...after the lesson." },
		unfall = { "NO PAIN NO GAIN! ...that was a lot of pain.", "THAT'S what I call a full body workout!", "OOF! My protein shake!" },
		lob = { "BEAST MODE!", "YEAAAH! High five! ✋", "THAT'S MY CHAMPION!" },
		leerlauf = { "Steering wheel curls! 1... 2... 3...", "Hydrate or die-drate!", "Feel the burn! The tire burn!", "You know what's heavy? This car. Respect." },
		event = { "OBSTACLE COURSE! LET'S GO!", "THIS IS YOUR TRAINING, ROOKIE!", "Dodge it like a dodgeball CHAMPION!" },
		gag = { titel = "🥤 PROTEIN SPILL", text = "Coach Kevin spilled his protein shake all over the dashboard.", sagt = "NOOO! That was my post-workout shake!" },
		ende_gut = { "CHAMPION! Now go drink some water!" },
		ende_schlecht = { "Champions fall. Champions get up. TRY AGAIN!" },
	},
	{
		id = "dina", name = "DJ Dina", frau = true,
		haut = Color3.fromRGB(160, 110, 80), oberteil = Color3.fromRGB(240, 70, 170), hose = Color3.fromRGB(40, 40, 60),
		start = { "Yo yo yo! Welcome to the DJ Dina driving show! 🎧", "Turn up the bass and let's ROLL!", "Today's playlist: 100% BANGERS. Let's go!" },
		fehler = { "*record scratch* 💿", "Ooh, wrong note!", "That move was off the beat!" },
		unfall = { "BASS DROP! ...on the car.", "That's the loudest track I ever heard!", "Remix! Remix! No wait, that's just a crash." },
		lob = { "That turn was a BANGER!", "Smooth like jazz! 🎷", "The crowd goes WILD!" },
		leerlauf = { "Untz untz untz untz...", "This street needs more bass.", "Next song is dedicated to that traffic light!", "🎵 Drive, drive, drive your car... 🎵" },
		event = { "Shout-out to the obstacle on the road!", "Plot twist! Drop the beat!", "Okay, THIS is a new track!" },
		gag = { titel = "🔊 VOLUME 200%", text = "DJ Dina turned the radio up to 200 percent.", sagt = "CAN YOU HEAR ME?! THE BASS IS PERFECT!" },
		ende_gut = { "Show's over! Give it up for my driver! 👏" },
		ende_schlecht = { "Wrong track. Let's play it again!" },
	},
}

local function zufall(t) return t[math.random(#t)] end
Chaos.zufall = zufall

local zuletztLehrer = {} -- player -> last persona id (so you get a different one next time)
function Chaos.lehrerWaehlen(p)
	local auswahl = {}
	for _, l in Chaos.LEHRER do
		if l.id ~= zuletztLehrer[p] then table.insert(auswahl, l) end
	end
	local l = zufall(auswahl)
	zuletztLehrer[p] = l.id
	return l
end

-- ---------------------------------------------------------------
-- Speech bubble over the instructor's head (everyone can see it)
-- ---------------------------------------------------------------
local function blase(st)
	local figur = st.model and st.model:FindFirstChild("Fahrlehrer")
	local kopf = figur and figur:FindFirstChild("Head")
	if not kopf then return nil end
	local bb = kopf:FindFirstChild("Sprechblase")
	if not bb then
		bb = Instance.new("BillboardGui")
		bb.Name = "Sprechblase"
		bb.Size = UDim2.fromOffset(250, 74)
		bb.StudsOffset = Vector3.new(0, 3.2, 0)
		bb.AlwaysOnTop = true
		bb.MaxDistance = 90
		bb.LightInfluence = 0
		local t = Instance.new("TextLabel")
		t.Name = "Text"
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		t.TextColor3 = Color3.fromRGB(25, 25, 35)
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.TextWrapped = true
		t.Parent = bb
		local ecke = Instance.new("UICorner")
		ecke.CornerRadius = UDim.new(0, 14)
		ecke.Parent = t
		local rand = Instance.new("UIStroke")
		rand.Thickness = 2
		rand.Color = Color3.fromRGB(25, 25, 35)
		rand.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		rand.Parent = t
		local pad = Instance.new("UIPadding")
		for _, s in { "PaddingLeft", "PaddingRight", "PaddingTop", "PaddingBottom" } do pad[s] = UDim.new(0, 8) end
		pad.Parent = t
		bb.Parent = kopf
	end
	return bb
end

-- say a line; art = name of a line pool or a fixed text
function Chaos.sagen(st, art, text)
	local c = st.chaos
	if not c then return nil end
	local zeile = text or (c.lehrer[art] and zufall(c.lehrer[art]))
	if not zeile then return nil end
	c.zuletztGesagt = os.clock()
	c.letzteZeile = zeile
	local bb = blase(st)
	if bb then
		bb.Text.Text = zeile
		bb.Enabled = true
		local nr = (c.blasenNr or 0) + 1
		c.blasenNr = nr
		task.delay(math.clamp(#zeile / 14, 3, 6), function()
			if c.blasenNr == nr and bb.Parent then bb.Enabled = false end
		end)
	end
	return zeile
end

function Chaos.reaktion(p, st, art)
	local c = st.chaos
	if not c then return end
	-- don't talk over yourself (but crashes and endings always get a reaction)
	if art == "lob" and os.clock() - (c.zuletztGesagt or 0) < 4 then return end
	if art == "lob" and math.random() < 0.4 then return end
	Chaos.sagen(st, art)
end

-- called when a lesson is created
function Chaos.neu(p, st)
	st.chaos = {
		lehrer = Chaos.lehrerWaehlen(p),
		naechstesEvent = nil,     -- set when the first gate is sent
		naechstesGerede = os.clock() + 14,
		zuletztGesagt = 0,
		event = nil,
		anzahl = 0,
	}
	return st.chaos.lehrer
end

-- ---------------------------------------------------------------
-- Building the event objects (anchored, no collision)
-- ---------------------------------------------------------------
local ordner = Instance.new("Folder")
ordner.Name = "Chaos"
ordner.Parent = workspace
Chaos.ordner = ordner

local function block(m, name, groesse, farbe, cf, material, form)
	local t = Instance.new("Part")
	t.Name = name
	t.Size = groesse
	t.Color = farbe
	t.CFrame = cf
	t.Material = material or Enum.Material.SmoothPlastic
	if form then t.Shape = form end
	t.Anchored = true
	t.CanCollide = false
	t.CanQuery = false
	t.CanTouch = false
	t.CastShadow = false
	t.Massless = true
	t.TopSurface = Enum.SurfaceType.Smooth
	t.BottomSurface = Enum.SurfaceType.Smooth
	t.Parent = m
	return t
end

local function modell(name)
	-- invisible root on the ground = pivot of the model
	local m = Instance.new("Model")
	m.Name = name
	local w = Instance.new("Part")
	w.Name = "Wurzel"
	w.Size = Vector3.new(0.2, 0.2, 0.2)
	w.Transparency = 1
	w.Anchored, w.CanCollide, w.CanQuery, w.CanTouch, w.Massless = true, false, false, false, true
	w.CFrame = CFrame.new()
	w.Parent = m
	m.PrimaryPart = w
	return m
end

local WEISS, SCHWARZ = Color3.fromRGB(245, 245, 240), Color3.fromRGB(30, 30, 30)
-- cow, built around (0,0,0) = ground under the body, looking along -Z
local function kuh()
	local m = modell("Kuh")
	block(m, "Koerper", Vector3.new(2.4, 2.2, 4.2), WEISS, CFrame.new(0, 3.1, 0))
	block(m, "Fleck", Vector3.new(2.5, 1.2, 1.3), SCHWARZ, CFrame.new(0, 3.5, 0.6))
	block(m, "Fleck", Vector3.new(1.3, 1.0, 1.0), SCHWARZ, CFrame.new(0.6, 2.7, -1.2))
	block(m, "Kopf", Vector3.new(1.6, 1.6, 1.7), WEISS, CFrame.new(0, 3.9, -2.6))
	block(m, "Maul", Vector3.new(1.5, 0.8, 0.5), Color3.fromRGB(240, 160, 170), CFrame.new(0, 3.4, -3.5))
	for _, x in { -0.55, 0.55 } do
		block(m, "Auge", Vector3.new(0.25, 0.3, 0.1), SCHWARZ, CFrame.new(x * 0.8, 4.2, -3.46))
		block(m, "Horn", Vector3.new(0.25, 0.6, 0.25), Color3.fromRGB(235, 225, 190), CFrame.new(x * 1.1, 4.9, -2.4))
		block(m, "Ohr", Vector3.new(0.6, 0.3, 0.4), WEISS, CFrame.new(x * 1.6, 4.3, -2.3))
	end
	for _, x in { -0.8, 0.8 } do
		for _, z in { -1.5, 1.5 } do
			block(m, "Bein", Vector3.new(0.6, 2.0, 0.6), WEISS, CFrame.new(x, 1.0, z))
		end
	end
	block(m, "Schwanz", Vector3.new(0.2, 1.6, 0.2), WEISS, CFrame.new(0, 2.8, 2.2))
	return m
end

local function ente(mama)
	local s = mama and 1 or 0.55
	local farbe = mama and Color3.fromRGB(240, 240, 235) or Color3.fromRGB(255, 220, 60)
	local m = modell("Ente")
	block(m, "Koerper", Vector3.new(1.0, 0.9, 1.5) * s, farbe, CFrame.new(0, 0.55 * s, 0))
	block(m, "Kopf", Vector3.new(0.7, 0.7, 0.7) * s, farbe, CFrame.new(0, 1.25 * s, -0.55 * s))
	block(m, "Schnabel", Vector3.new(0.4, 0.2, 0.45) * s, Color3.fromRGB(255, 140, 20), CFrame.new(0, 1.15 * s, -1.05 * s))
	return m
end

local function banane()
	local m = modell("Bananenschale")
	local gelb = Color3.fromRGB(255, 215, 40)
	local mitte = block(m, "Mitte", Vector3.new(0.9, 0.35, 0.9), gelb, CFrame.new(0, 0.2, 0))
	for i = 0, 2 do
		local w = math.rad(i * 120 + 20)
		block(m, "Lasche", Vector3.new(0.5, 0.15, 1.6), gelb, CFrame.Angles(0, w, 0) * CFrame.new(0, 0.1, -1.0))
	end
	block(m, "Stiel", Vector3.new(0.2, 0.5, 0.2), Color3.fromRGB(90, 70, 30), CFrame.new(0, 0.55, 0))
	-- a big floating banana sign so you see it in time
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(60, 60)
	bb.StudsOffset = Vector3.new(0, 4, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 120
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = "🍌"
	t.TextScaled = true
	t.Parent = bb
	bb.Parent = mitte
	return m
end

local function ufo()
	local m = modell("Ufo")
	block(m, "Scheibe", Vector3.new(2.2, 16, 16), Color3.fromRGB(170, 175, 190), CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Metal, Enum.PartType.Cylinder)
	block(m, "Kuppel", Vector3.new(7, 7, 7), Color3.fromRGB(120, 230, 255), CFrame.new(0, 1.6, 0), Enum.Material.Glass, Enum.PartType.Ball).Transparency = 0.35
	block(m, "Alien", Vector3.new(1.6, 2.2, 1.6), Color3.fromRGB(90, 220, 90), CFrame.new(0, 2.2, 0), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	for i = 0, 7 do
		local w = math.rad(i * 45)
		block(m, "Licht", Vector3.new(0.8, 0.8, 0.8), i % 2 == 0 and Color3.fromRGB(255, 80, 200) or Color3.fromRGB(80, 255, 120),
			CFrame.new(math.cos(w) * 7.2, -0.3, math.sin(w) * 7.2), Enum.Material.Neon, Enum.PartType.Ball)
	end
	local strahl = block(m, "Strahl", Vector3.new(26, 11, 11), Color3.fromRGB(140, 255, 160), CFrame.new(0, -14, 0) * CFrame.Angles(0, 0, math.rad(90)), Enum.Material.Neon, Enum.PartType.Cylinder)
	strahl.Transparency = 0.7
	local licht = Instance.new("PointLight")
	licht.Color = Color3.fromRGB(140, 255, 160)
	licht.Range = 30
	licht.Brightness = 2
	licht.Parent = strahl
	return m
end

-- ---------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------
-- Each event: aufbauen(e) builds objects and sets e.punkte(e) -> { {pos, r, obj} };
-- bewegen(e, t) animates; ankuendigung = banner shown when it appears.
local EVENTS = {}

local function bodenCF(e, seite, vor, hoehe)
	-- point on the ground in the event frame: seite = right, vor = towards the car's driving direction
	return e.basis * CFrame.new(seite, hoehe or 0, vor)
end

EVENTS.kuehe = {
	gewicht = 3,
	banner = { titel = "🐄 COWS ON THE ROAD!", text = "Stop or drive around them!" },
	aufbauen = function(e)
		e.tiere = {}
		local start = { { -7, 0 }, { -11.5, 4.5 }, { -15.5, -3.5 } }
		for i, s in start do
			local k = kuh()
			k.Parent = e.modell
			table.insert(e.tiere, { m = k, seite = s[1], vor = s[2], r = 2.4, phase = i })
		end
		-- "MOO!" over the first cow
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(110, 44)
		bb.StudsOffset = Vector3.new(0, 6.5, 0)
		bb.AlwaysOnTop = true
		bb.MaxDistance = 120
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Text = "MOOO!"
		t.TextColor3 = Color3.fromRGB(255, 255, 255)
		t.TextStrokeTransparency = 0
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.Parent = bb
		bb.Parent = e.tiere[1].m.Kopf
	end,
	tempo = 2.6,
}

EVENTS.enten = {
	gewicht = 3,
	banner = { titel = "🦆 DUCK FAMILY CROSSING!", text = "Let them cross – don't squash the babies!" },
	aufbauen = function(e)
		e.tiere = {}
		for i = 0, 5 do
			local d = ente(i == 0)
			d.Parent = e.modell
			table.insert(e.tiere, { m = d, seite = -3 - i * 2.2, vor = 0, r = i == 0 and 1.0 or 0.7, phase = i, ente = true })
		end
	end,
	tempo = 2.0,
}

EVENTS.banane = {
	gewicht = 3,
	banner = { titel = "🍌 BANANA PEEL AHEAD!", text = "Swerve around it!" },
	aufbauen = function(e)
		local b = banane()
		b.Parent = e.modell
		local seite = (math.random() - 0.5) * 3
		b:PivotTo(bodenCF(e, seite, 0))
		e.tiere = { { m = b, seite = seite, vor = 0, r = 1.0, fest = true } }
	end,
	tempo = 0,
}

EVENTS.ufo = {
	gewicht = 2,
	banner = { titel = "👽 UFO SIGHTING!", text = "Drive through the green beam for an alien bonus!" },
	aufbauen = function(e)
		local u = ufo()
		u.Parent = e.modell
		e.ufo = u
		local k = kuh()
		k.Parent = e.modell
		e.ufoKuh = k
		e.tiere = {}
		e.strahlR = 5.5
	end,
	tempo = 0,
}

EVENTS.gag = {
	gewicht = 2,
	ohneObjekt = true,
}

local function wuerfeln(st)
	local summe = 0
	for _, ev in EVENTS do summe += ev.gewicht end
	local x = math.random() * summe
	for name, ev in EVENTS do
		x -= ev.gewicht
		if x <= 0 then return name end
	end
	return "kuehe"
end
Chaos.EVENTS = EVENTS

local function banner(p, titel, text, farbe, extra)
	local info = { typ = "chaos", titel = titel, text = text, farbe = farbe }
	for k, v in extra or {} do info[k] = v end
	ctx.fahrEvent:FireClient(p, info)
end

local function boden(st, punkt)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { st.model, ordner }
	local ok, treffer = pcall(function()
		return workspace:Raycast(punkt + Vector3.new(0, 25, 0), Vector3.new(0, -60, 0), params)
	end)
	if ok and treffer then return treffer.Position.Y end
	return nil
end

-- start an event in front of the car (art = event name, optional for tests)
function Chaos.eventStarten(p, st, art)
	local c = st.chaos
	if not c or c.event then return nil end
	art = art or wuerfeln(st)
	local ev = EVENTS[art]
	c.anzahl += 1
	if ev.ohneObjekt then
		local g = c.lehrer.gag
		banner(p, g.titel, g.text, "lila")
		Chaos.sagen(st, nil, g.sagt)
		c.naechstesEvent = os.clock() + math.random(28, 40)
		return { art = art }
	end
	local cf = st.chassis.CFrame
	local vor = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
	if vor.Magnitude < 0.1 then return nil end
	vor = vor.Unit
	local abstand = art == "ufo" and 70 or 60
	local mitte = st.chassis.Position + vor * abstand
	local y = boden(st, mitte)
	local yAuto = boden(st, st.chassis.Position)
	if y and yAuto and math.abs(y - yAuto) > 4 then
		-- not a road ahead (roof, wall, hill): try again a bit later
		c.anzahl -= 1
		c.naechstesEvent = os.clock() + 3
		return nil
	end
	y = y or (st.chassis.Position.Y - 2.2)
	mitte = Vector3.new(mitte.X, y, mitte.Z)
	-- event frame looks in the driving direction: +X = right side of the road, +Z = towards the car
	local e = {
		art = art, ev = ev, start = os.clock(), basis = CFrame.lookAt(mitte, mitte + vor),
		mitte = mitte, naechster = math.huge, getroffen = false, durchStrahl = false,
	}
	e.modell = Instance.new("Model")
	e.modell.Name = "Chaos_" .. art .. "_" .. p.Name
	ev.aufbauen(e)
	e.modell.Parent = ordner
	c.event = e
	Chaos.bewegen(e, 0)
	banner(p, ev.banner.titel, ev.banner.text, "gelb")
	task.delay(0.6, function()
		if st.chaos == c and c.event == e then Chaos.sagen(st, "event") end
	end)
	return e
end

-- animation of one event (t = seconds since start)
function Chaos.bewegen(e, t)
	local ev = e.ev
	for _, tier in e.tiere or {} do
		if tier.fliegt then
			-- hit: flies away spinning (only looks, nothing physical)
			local ft = t - tier.fliegt
			local cf = bodenCF(e, tier.seite + ft * 6, tier.vor + ft * 4, ft * 14 - ft * ft * 2)
			tier.m:PivotTo(cf * CFrame.Angles(ft * 7, ft * 5, ft * 3))
			if ft > 3 then tier.m.Parent = nil end
		elseif not tier.fest then
			local seite = tier.seite + t * ev.tempo
			tier.aktSeite = seite
			local hopp = math.abs(math.sin(t * 7 + tier.phase)) * (tier.ente and 0.25 or 0.15)
			-- walk across the road towards +X (the car's right)
			tier.m:PivotTo(bodenCF(e, seite, tier.vor, hopp) * CFrame.Angles(0, math.rad(-90), 0))
		else
			tier.aktSeite = tier.seite
		end
	end
	if e.ufo then
		local schweben = math.sin(t * 2) * 0.6
		local hoch = 26
		if t > 16 then hoch += (t - 16) ^ 2 * 8 end -- flies away
		e.ufo:PivotTo(e.basis * CFrame.new(0, hoch + schweben, 0) * CFrame.Angles(0, t * 1.5, 0))
		local kuhHoehe = math.min(t * 1.6, hoch - 3)
		if t > 16 then e.ufoKuh.Parent = nil
		else e.ufoKuh:PivotTo(e.basis * CFrame.new(0, kuhHoehe, 0) * CFrame.Angles(t * 0.8, t * 1.3, 0)) end
	end
end

-- points that count as "hit" for the car box
local function trefferPunkte(e)
	local liste = {}
	for _, tier in e.tiere or {} do
		if not tier.fliegt and tier.m.Parent then
			local p = bodenCF(e, tier.aktSeite or tier.seite, tier.vor, 0).Position
			table.insert(liste, { pos = p, r = tier.r, tier = tier })
		end
	end
	return liste
end

local function eventEnde(p, st, e, grund)
	local c = st.chaos
	c.event = nil
	c.naechstesEvent = os.clock() + math.random(30, 45)
	if e.modell then
		local m = e.modell
		task.delay(e.art == "ufo" and 0 or 4, function() m:Destroy() end)
	end
	if grund ~= "vorbei" then return end
	if e.art == "ufo" then
		if e.durchStrahl then
			ctx.geldGeben(p, BONUS_UFO, "Alien bonus!")
			banner(p, "👽 BEAMED!", "The aliens liked your car. Alien bonus!", "gruen")
			Chaos.sagen(st, "lob")
		end
	elseif not e.getroffen and e.naechster < 40 then
		local texte = { kuehe = "Dodged the cows!", enten = "The ducks made it!", banane = "Dodged the banana!" }
		ctx.geldGeben(p, BONUS, texte[e.art] or "Dodged!")
		banner(p, "✨ NICE DODGE!", texte[e.art] or "Dodged!", "gruen")
		Chaos.sagen(st, "lob")
	end
end

-- called every 0.1 s from the lesson loop (only while a gate is active and the player sits in the car)
function Chaos.tick(p, st, pos, tempo, vorneZ, hintenZ, halbB)
	local c = st.chaos
	if not c then return end
	local jetzt = os.clock()
	local e = c.event
	if e then
		if e.modell and not e.modell.Parent then c.event = nil return end
		local t = jetzt - e.start
		local d = Vector3.new(e.mitte.X - pos.X, 0, e.mitte.Z - pos.Z).Magnitude
		e.naechster = math.min(e.naechster, d)
		local cf = st.chassis.CFrame
		-- hit test: same box as for pedestrians
		if not e.getroffen then
			for _, pt in trefferPunkte(e) do
				local lp = cf:PointToObjectSpace(pt.pos)
				if math.abs(lp.X) < halbB + pt.r and lp.Z > vorneZ - pt.r and lp.Z < hintenZ + pt.r and lp.Y > -4 and lp.Y < 8 then
					e.getroffen = true
					if not pt.tier.fest then pt.tier.fliegt = t end
					local was = { kuehe = { "💥 MOOOO!", "You bumped a cow. It's fine... probably." },
						enten = { "🦆 QUAAACK!", "A duck went flying! It's okay, ducks can fly." },
						banane = { "🍌 SLIIIP!", "You drove over the banana peel! Whoooa!" } }
					local w = was[e.art] or { "💥 BONK!", "" }
					banner(p, w[1], w[2], "rot", { wackeln = true })
					Chaos.sagen(st, "unfall")
					break
				end
			end
		end
		if e.ufo and not e.durchStrahl and t < 16 and d < e.strahlR then
			e.durchStrahl = true
		end
		-- over when the car has passed it, after a while, or when the car is far away
		local lokal = cf:PointToObjectSpace(e.mitte)
		local vorbei = lokal.Z > hintenZ + 12 and e.naechster < 40
		if vorbei or t > 30 or (t > 8 and d > 160) then
			eventEnde(p, st, e, vorbei and "vorbei" or "weg")
		end
		return
	end
	-- instructor chatter
	if jetzt > c.naechstesGerede then
		c.naechstesGerede = jetzt + math.random(16, 26)
		if jetzt - c.zuletztGesagt > 5 then Chaos.sagen(st, "leerlauf") end
	end
	-- new event: not while parking, only when driving
	if c.naechstesEvent and jetzt > c.naechstesEvent and tempo > 10 and not st.parkPhase then
		local wp = st.lektion.punkte[st.index]
		if wp and not wp.parken then
			Chaos.eventStarten(p, st)
		else
			c.naechstesEvent = jetzt + 5
		end
	end
end

-- the first gate was sent: chaos may start soon
function Chaos.losgehen(st)
	local c = st.chaos
	if c and not c.naechstesEvent then c.naechstesEvent = os.clock() + math.random(14, 22) end
end

-- lesson over: remove everything
function Chaos.ende(st)
	local c = st.chaos
	if not c then return end
	if c.event and c.event.modell then c.event.modell:Destroy() end
	c.event = nil
	c.naechstesEvent = nil
end

function Chaos.starten(k)
	ctx = k
	Chaos.ctx = k
	RunService.Heartbeat:Connect(function()
		for _, st in ctx.lektionen do
			local e = st.chaos and st.chaos.event
			if e and e.modell and e.modell.Parent then
				Chaos.bewegen(e, os.clock() - e.start)
			end
		end
	end)
end

return Chaos
]=====]
	m.Parent = server
end)

schritt("Server (Chaos eingebaut)", function()
	if string.find(game.ServerScriptService.FuehrerscheinServer.Source, [==[require(script:WaitForChild("Chaos"))]==], 1, true) then return end
local function ersetze(src, alt, neu)
	local a, b = string.find(src, alt, 1, true)
	assert(a, "nicht gefunden: " .. alt:sub(1, 60))
	assert(not string.find(src, alt, b + 1, true), "mehrfach: " .. alt:sub(1, 60))
	return src:sub(1, a - 1) .. neu .. src:sub(b + 1)
end
local s = game.ServerScriptService.FuehrerscheinServer
local src = s.Source
assert(#src == 131155, "Ausgangsstand passt nicht: " .. #src)
src = ersetze(src, [===[
local Belohnungen = require(script:WaitForChild("Belohnungen"))
local Verkehr = require(ordner:WaitForChild("Verkehr"))
]===], [===[
local Belohnungen = require(script:WaitForChild("Belohnungen"))
local Chaos = require(script:WaitForChild("Chaos"))
local Verkehr = require(ordner:WaitForChild("Verkehr"))
]===])
src = ersetze(src, [===[
	local k = fest.kopf or zufall(frau and NPC_LOOK.koepfeFrau or NPC_LOOK.koepfeMann)
	if stil ~= "uniform" then
		desc.Shirt = fest.shirt or zufall(NPC_LOOK.shirts)
]===], [===[
	local k = fest.kopf or zufall(frau and NPC_LOOK.koepfeFrau or NPC_LOOK.koepfeMann)
	if stil ~= "uniform" and not fest.uniform then
		desc.Shirt = fest.shirt or zufall(NPC_LOOK.shirts)
]===])
src = ersetze(src, [===[
	lektionen[p] = nil
	local d = daten[p]
]===], [===[
	lektionen[p] = nil
	Chaos.reaktion(p, st, erfolg and "ende_gut" or "ende_schlecht")
	Chaos.ende(st)
	local d = daten[p]
]===])
src = ersetze(src, [===[
		gesamt = #st.lektion.punkte,
		sprecher = st.pruefung and "Examiner" or "Instructor",
	}
]===], [===[
		gesamt = #st.lektion.punkte,
		sprecher = st.pruefung and "Examiner" or (st.chaos and st.chaos.lehrer.name) or "Instructor",
	}
]===])
src = ersetze(src, [===[
	st.zielAktiv = true
	fahrEvent:FireClient(p, info)
]===], [===[
	st.zielAktiv = true
	Chaos.losgehen(st)
	fahrEvent:FireClient(p, info)
]===])
src = ersetze(src, [===[
	fahrEvent:FireClient(p, { typ = "warnung", text = text, fehler = st.fehler, grenze = st.erlaubt })
	if st.fehler > st.erlaubt then
]===], [===[
	fahrEvent:FireClient(p, { typ = "warnung", text = text, fehler = st.fehler, grenze = st.erlaubt })
	Chaos.reaktion(p, st, (punkte or 1) >= 3 and "unfall" or "fehler")
	if st.fehler > st.erlaubt then
]===])
src = ersetze(src, [===[
-- Instructor / examiner sitting in a vehicle
local function mitfahrer(modell, name, anzeige, haut, oberteil, hose, platz)
	task.spawn(function()
]===], [===[
-- Instructor / examiner sitting in a vehicle
local function mitfahrer(modell, name, anzeige, haut, oberteil, hose, platz, stil)
	task.spawn(function()
]===])
src = ersetze(src, [===[
	task.spawn(function()
		local figur, hum = npc(name, anzeige, haut, oberteil, hose, "uniform")
		if not figur or not modell.Parent then return end
]===], [===[
	task.spawn(function()
		local figur, hum = npc(name, anzeige, haut, oberteil, hose, stil or "uniform")
		if not figur or not modell.Parent then return end
]===])
src = ersetze(src, [===[

	-- Instructor in the passenger seat, examiner in the back (or in the middle of the truck cab)
	mitfahrer(modell, "Fahrlehrer", "Mike (Instructor)", Color3.fromRGB(205, 160, 125), Color3.fromRGB(255, 255, 255), Color3.fromRGB(60, 60, 70), beifahrer)
	if pruefung then
]===], [===[

	-- Instructor in the passenger seat (a random crazy one, see Chaos.lua), examiner in the back (or in the middle of the truck cab)
	local lehrer = Chaos.neu(p, st)
	mitfahrer(modell, "Fahrlehrer", lehrer.name .. " (Instructor)", lehrer.haut, lehrer.oberteil, lehrer.hose, beifahrer, { uniform = true, frau = lehrer.frau == true })
	if pruefung then
]===])
src = ersetze(src, [===[
				if st.nr == 1 and not pruefung then funnel(p, 2) end
				fahrEvent:FireClient(p, { typ = "start", titel = lektion.titel, text = lektion.intro, sprecher = pruefung and "Examiner" or "Instructor", grenze = st.erlaubt })
				task.delay(6, function()
]===], [===[
				if st.nr == 1 and not pruefung then funnel(p, 2) end
				fahrEvent:FireClient(p, { typ = "start", titel = lektion.titel, text = lektion.intro, sprecher = pruefung and "Examiner" or lehrer.name, grenze = st.erlaubt, lehrer = lehrer.name })
				task.delay(1.5, function()
					if lektionen[p] == st then Chaos.sagen(st, "start") end
				end)
				task.delay(6, function()
]===])
src = ersetze(src, [===[
	elseif pruefung then
		return { text = "Your driving test starts now! Mike and your examiner Mr. Becker are waiting in the car on the parking lot. Press E at the driver's door to get in." }
	end
]===], [===[
	elseif pruefung then
		return { text = "Your driving test starts now! Your instructor and the examiner Mr. Becker are waiting in the car on the parking lot. Press E at the driver's door to get in." }
	end
]===])
src = ersetze(src, [===[
			lektionen[p] = nil
			if st.model then st.model:Destroy() end
]===], [===[
			lektionen[p] = nil
			Chaos.ende(st)
			if st.model then st.model:Destroy() end
]===])
src = ersetze(src, [===[
		end
		if lektionen[p] ~= st then continue end

		-- Speeding (more than 8 over the limit for 1.5 s)
]===], [===[
		end
		if lektionen[p] ~= st then continue end

		-- Chaos: instructor chatter and random events (cows, ducks, banana, UFO) – never touches the car physics
		Chaos.tick(p, st, pos, tempo, vorneZ, hintenZ, halbB)

		-- Speeding (more than 8 over the limit for 1.5 s)
]===])
src = ersetze(src, [===[
				st.stoppHinweis = false
				if st.index > #st.lektion.punkte then
]===], [===[
				st.stoppHinweis = false
				Chaos.reaktion(p, st, "lob")
				if st.index > #st.lektion.punkte then
]===])
src = ersetze(src, [===[
Shop.starten({ daten = daten, geldGeben = geldGeben, fahrEvent = fahrEvent, geaendert = geaendert, speichernSofort = speichern, Auto = Auto, Pflege = Pflege })
Belohnungen.starten({ daten = daten, geldGeben = geldGeben, xpGeben = xpGeben, fahrEvent = fahrEvent, geaendert = geaendert, Shop = Shop })
]===], [===[
Shop.starten({ daten = daten, geldGeben = geldGeben, fahrEvent = fahrEvent, geaendert = geaendert, speichernSofort = speichern, Auto = Auto, Pflege = Pflege })
Chaos.starten({ fahrEvent = fahrEvent, geldGeben = geldGeben, lektionen = lektionen })
Belohnungen.starten({ daten = daten, geldGeben = geldGeben, xpGeben = xpGeben, fahrEvent = fahrEvent, geaendert = geaendert, Shop = Shop })
]===])
assert(#src == 131968, "Ergebnis-Länge falsch: " .. #src)
s.Source = src
return s.Name .. ": " .. #src .. " Zeichen"
end)

schritt("Fahrstunden (ohne Mike)", function()
	if string.find(game.ServerScriptService.FuehrerscheinServer.Fahrstunden.Source, [==[intro = "A short first drive]==], 1, true) then return end
local function ersetze(src, alt, neu)
	local a, b = string.find(src, alt, 1, true)
	assert(a, "nicht gefunden: " .. alt:sub(1, 60))
	assert(not string.find(src, alt, b + 1, true), "mehrfach: " .. alt:sub(1, 60))
	return src:sub(1, a - 1) .. neu .. src:sub(b + 1)
end
local s = game.ServerScriptService.FuehrerscheinServer.Fahrstunden
local src = s.Source
assert(#src == 10637, "Ausgangsstand passt nicht: " .. #src)
src = ersetze(src, [===[
		titel = "Lesson 1: First Drive",
		intro = "Hi, I'm Mike! A short first drive around the block. W/S = gas and brake, A/D = steering (on a phone: the pedals on the screen). Just drive through the green gates!",
		punkte = {
]===], [===[
		titel = "Lesson 1: First Drive",
		intro = "A short first drive around the block. W/S = gas and brake, A/D = steering (on a phone: the pedals on the screen). Just drive through the green gates!",
		punkte = {
]===])
assert(#src == 10623, "Ergebnis-Länge falsch: " .. #src)
s.Source = src
return s.Name .. ": " .. #src .. " Zeichen"
end)

schritt("Client (Chaos-Banner, v37)", function()
	if string.find(game.StarterPlayer.StarterPlayerScripts.FuehrerscheinClient.Source, [==[_G.ChaosBanner = chaosBanner]==], 1, true) then return end
local function ersetze(src, alt, neu)
	local a, b = string.find(src, alt, 1, true)
	assert(a, "nicht gefunden: " .. alt:sub(1, 60))
	assert(not string.find(src, alt, b + 1, true), "mehrfach: " .. alt:sub(1, 60))
	return src:sub(1, a - 1) .. neu .. src:sub(b + 1)
end
local s = game.StarterPlayer.StarterPlayerScripts.FuehrerscheinClient
local src = s.Source
assert(#src == 160660, "Ausgangsstand passt nicht: " .. #src)
src = ersetze(src, [===[
local spieler = Players.LocalPlayer
print("[Driving School] client v36 loaded")
local ordner = RS:WaitForChild("Fuehrerschein")
]===], [===[
local spieler = Players.LocalPlayer
print("[Driving School] client v37 loaded")
local ordner = RS:WaitForChild("Fuehrerschein")
]===])
src = ersetze(src, [===[
	local liste = "Here is everything you need to do:\n\n" .. schritte({
		{ s.fahrstunden >= n, ("Driving lessons with Mike (%d/%d)  ⭐ %d/%d"):format(math.min(s.fahrstunden, n), n, summe, n * 3) },
		{ s.unterricht, "Theory lesson at the <b>whiteboard</b> (classroom)" },
]===], [===[
	local liste = "Here is everything you need to do:\n\n" .. schritte({
		{ s.fahrstunden >= n, ("Driving lessons (%d/%d)  ⭐ %d/%d"):format(math.min(s.fahrstunden, n), n, summe, n * 3) },
		{ s.unterricht, "Theory lesson at the <b>whiteboard</b> (classroom)" },
]===])
src = ersetze(src, [===[
	if s.fahrstunden < n then
		text = r.naechste and ("Next lesson: <b>%s</b>\nMike is waiting in the car on the parking lot."):format(r.naechste) or ""
		if not s.unterricht then text ..= "\n<font size=\"15\" color=\"#9aa4b5\">You can do the theory (classroom) any time in between.</font>" end
]===], [===[
	if s.fahrstunden < n then
		text = r.naechste and ("Next lesson: <b>%s</b>\nYour instructor is waiting in the car on the parking lot. Who will it be this time?"):format(r.naechste) or ""
		if not s.unterricht then text ..= "\n<font size=\"15\" color=\"#9aa4b5\">You can do the theory (classroom) any time in between.</font>" end
]===])
src = ersetze(src, [===[
	elseif not s.fuehrerschein then
		text = "Your examiner Mr. Becker rides in the back, Mike sits next to you. The route is random – hitting a pedestrian counts as 3 mistakes!"
		table.insert(knoepfe, { text = "Start the driving test", farbe = GRUEN, klick = function()
]===], [===[
	elseif not s.fuehrerschein then
		text = "Your examiner Mr. Becker rides in the back, a (crazy) instructor sits next to you. The route is random – hitting a pedestrian counts as 3 mistakes!"
		table.insert(knoepfe, { text = "Start the driving test", farbe = GRUEN, klick = function()
]===])
src = ersetze(src, [===[
end
fahrEvent.OnClientEvent:Connect(function(info)
]===], [===[
end
-- Chaos events: big banner in the middle of the screen (+ a little camera shake when you hit something)
local chaosGui = Instance.new("ScreenGui")
chaosGui.Name = "ChaosBanner"
chaosGui.ResetOnSpawn = false
chaosGui.IgnoreGuiInset = true
chaosGui.DisplayOrder = 5
chaosGui.Parent = spieler.PlayerGui
local chaosBox = Instance.new("Frame")
chaosBox.Name = "Box"
chaosBox.AnchorPoint = Vector2.new(0.5, 0.5)
chaosBox.Position = UDim2.fromScale(0.5, 0.27)
chaosBox.Size = UDim2.new(0.8, 0, 0, 96)
chaosBox.BackgroundTransparency = 1
chaosBox.Visible = false
chaosBox.Parent = chaosGui
local chaosGroesse = Instance.new("UISizeConstraint")
chaosGroesse.MaxSize = Vector2.new(620, 96)
chaosGroesse.Parent = chaosBox
local chaosSkala = Instance.new("UIScale")
chaosSkala.Parent = chaosBox
local chaosTitel = Instance.new("TextLabel")
chaosTitel.Name = "Titel"
chaosTitel.Size = UDim2.new(1, 0, 0, 58)
chaosTitel.BackgroundTransparency = 1
chaosTitel.Font = Enum.Font.FredokaOne
chaosTitel.TextScaled = true
chaosTitel.TextColor3 = Color3.fromRGB(255, 255, 255)
chaosTitel.TextStrokeTransparency = 0
chaosTitel.TextStrokeColor3 = Color3.fromRGB(20, 20, 30)
chaosTitel.Parent = chaosBox
local chaosText = Instance.new("TextLabel")
chaosText.Name = "Text"
chaosText.Position = UDim2.new(0, 0, 0, 60)
chaosText.Size = UDim2.new(1, 0, 0, 30)
chaosText.BackgroundTransparency = 1
chaosText.Font = Enum.Font.GothamBold
chaosText.TextScaled = true
chaosText.TextColor3 = Color3.fromRGB(255, 255, 255)
chaosText.TextStrokeTransparency = 0.2
chaosText.Parent = chaosBox
local CHAOS_FARBEN = {
	gelb = Color3.fromRGB(255, 210, 40), rot = Color3.fromRGB(255, 70, 70),
	gruen = Color3.fromRGB(90, 235, 110), lila = Color3.fromRGB(205, 120, 255),
}
local chaosNr = 0
local function chaosBanner(info)
	chaosNr += 1
	local nr = chaosNr
	chaosTitel.Text = info.titel or ""
	chaosTitel.TextColor3 = CHAOS_FARBEN[info.farbe] or CHAOS_FARBEN.gelb
	chaosText.Text = info.text or ""
	chaosBox.Visible = true
	chaosSkala.Scale = 0.4
	game:GetService("TweenService"):Create(chaosSkala, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(3.2, function()
		if chaosNr == nr then chaosBox.Visible = false end
	end)
	if info.wackeln then
		-- camera shake only (CameraOffset), the car itself is not touched
		task.spawn(function()
			local hum = spieler.Character and spieler.Character:FindFirstChildOfClass("Humanoid")
			if not hum then return end
			local ende = os.clock() + 0.8
			while os.clock() < ende do
				local s = (ende - os.clock()) * 0.9
				hum.CameraOffset = Vector3.new((math.random() - 0.5) * s, (math.random() - 0.5) * s, 0)
				task.wait(0.03)
			end
			hum.CameraOffset = Vector3.new()
		end)
	end
end
_G.ChaosBanner = chaosBanner

fahrEvent.OnClientEvent:Connect(function(info)
]===])
src = ersetze(src, [===[
fahrEvent.OnClientEvent:Connect(function(info)
	if info.typ == "blinker" then
		blinkerModus = info.modus
]===], [===[
fahrEvent.OnClientEvent:Connect(function(info)
	if info.typ == "chaos" then
		chaosBanner(info)
	elseif info.typ == "blinker" then
		blinkerModus = info.modus
]===])
src = ersetze(src, [===[
	task.wait(3.2)
	untertitel.Text = info.lkw and "Mike (Instructor): Your license now also shows class C. Go and earn some coins!" or "Mike (Instructor): Great job! Here is your driver's license."
	task.wait(3.3)
]===], [===[
	task.wait(3.2)
	untertitel.Text = info.lkw and "Your instructor: Your license now also shows class C. Go and earn some coins!" or "Your instructor: Great job! Here is your driver's license."
	task.wait(3.3)
]===])
src = ersetze(src, [===[
do
	print("[Driving School] start screen v36 loading")
	local menue = Instance.new("ScreenGui")
]===], [===[
do
	print("[Driving School] start screen v37 loading")
	local menue = Instance.new("ScreenGui")
]===])
src = ersetze(src, [===[
			if a.fehler then return end
			zeige("Welcome to Driving School! 🚗", "Let's drive right away!\n\nYour instructor <b>Mike</b> is waiting in the car on the parking lot right in front of you. Walk to the <b>driver's door</b> and press <b>E</b> (on a phone: tap the button) to get in.\n\n<font size=\"15\" color=\"#9aa4b5\">The theory comes later – Anna at the reception shows you every step.</font>", {
				{ text = "Let's go!", farbe = GRUEN, klick = schliessen },
]===], [===[
			if a.fehler then return end
			zeige("Welcome to Driving School! 🚗", "Let's drive right away!\n\nYour (slightly crazy) instructor is waiting in the car on the parking lot right in front of you. Walk to the <b>driver's door</b> and press <b>E</b> (on a phone: tap the button) to get in.\n\n<font size=\"15\" color=\"#9aa4b5\">The theory comes later – Anna at the reception shows you every step.</font>", {
				{ text = "Let's go!", farbe = GRUEN, klick = schliessen },
]===])
assert(#src == 163531, "Ergebnis-Länge falsch: " .. #src)
s.Source = src
return s.Name .. ": " .. #src .. " Zeichen"
end)

print(table.concat(ergebnis, "\n"))
