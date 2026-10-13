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
