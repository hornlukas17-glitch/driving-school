-- Driving School: Update auf v36 (neues Fahrschulauto) – in die Studio-Befehlszeile einfügen, Enter.
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
	s.Source = s.Source:gsub("client v%d+ loaded", "client v36 loaded"):gsub("start screen v%d+ loading", "start screen v36 loading")
end)
print(table.concat(ergebnis, "\n"))
