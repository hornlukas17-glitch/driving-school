-- Driving School: Update auf v30 (Studio-Befehlszeile: alles einfuegen, Enter druecken)
-- Spielt Client, Verkehr, Auto und Karosserien (Night-Edition-Heck) ein und stellt Streaming/Detailstufen ein.
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
schritt("Client", function()
local s = game.StarterPlayer.StarterPlayerScripts.FuehrerscheinClient
local src = s.Source
assert(#src == 145568, "Ausgangsstand passt nicht: " .. #src)
src = ersetze(src, [===[
	end)
	RunService.RenderStepped:Connect(function()
]===], [===[
	end)
	local hbVorher
	RunService.RenderStepped:Connect(function()
]===])
src = ersetze(src, [===[
	RunService.RenderStepped:Connect(function()
		hb.BackgroundColor3 = _G.Handbremse and Color3.fromRGB(200, 50, 50) or Color3.fromRGB(25, 30, 40)
]===], [===[
	RunService.RenderStepped:Connect(function()
		if _G.Handbremse == hbVorher then return end
		hbVorher = _G.Handbremse
		hb.BackgroundColor3 = _G.Handbremse and Color3.fromRGB(200, 50, 50) or Color3.fromRGB(25, 30, 40)
]===])
src = ersetze(src, [===[

RunService.RenderStepped:Connect(function()
]===], [===[

local naechsteHud = 0
RunService.RenderStepped:Connect(function()
]===])
src = ersetze(src, [===[
RunService.RenderStepped:Connect(function()
	if warnText.Visible and os.clock() > warnBis then
]===], [===[
RunService.RenderStepped:Connect(function()
	-- 20 updates per second are plenty for text and buttons (saves time on phones)
	local jetztHud = os.clock()
	if jetztHud < naechsteHud then return end
	naechsteHud = jetztHud + 0.05
	if warnText.Visible and os.clock() > warnBis then
]===])
src = ersetze(src, [===[
	k.BackgroundColor3 = farbe or Color3.fromRGB(25, 30, 40)
	k.BackgroundTransparency = 0.15
	k.Text = ""
]===], [===[
	k.BackgroundColor3 = farbe or Color3.fromRGB(25, 30, 40)
	k.BackgroundTransparency = 0.12
	k.AutoButtonColor = false
	k.Text = ""
]===])
src = ersetze(src, [===[
	k.Parent = leiste
	Instance.new("UICorner", k).CornerRadius = UDim.new(0, 10)
	local bild = Instance.new("TextLabel")
]===], [===[
	k.Parent = leiste
	Instance.new("UICorner", k).CornerRadius = UDim.new(0, 12)
	-- thin light edge and a soft top-to-bottom shade: looks like a real app button
	local rand = Instance.new("UIStroke")
	rand.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	rand.Color = Color3.new(1, 1, 1)
	rand.Transparency = 0.82
	rand.Thickness = 1
	rand.Parent = k
	local verlauf = Instance.new("UIGradient")
	verlauf.Rotation = 90
	verlauf.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(175, 180, 195))
	verlauf.Parent = k
	k.MouseEnter:Connect(function() rand.Transparency = 0.45 end)
	k.MouseLeave:Connect(function() rand.Transparency = 0.82 end)
	local bild = Instance.new("TextLabel")
]===])
src = ersetze(src, [===[
	bild.Font = Enum.Font.GothamBold
	bild.TextSize = 21
	bild.TextColor3 = Color3.new(1, 1, 1)
]===], [===[
	bild.Font = Enum.Font.GothamBold
	bild.TextSize = 22
	bild.TextColor3 = Color3.new(1, 1, 1)
]===])
src = ersetze(src, [===[
end
local menueKnopf = leistenKnopf("☰", "Menu", 0)
menueKnopf.Name = "Menue"
]===], [===[
end
local menueKnopf = leistenKnopf("", "Menu", 0, Color3.fromRGB(30, 95, 190))
menueKnopf.Name = "Menue"
]===])
src = ersetze(src, [===[
menueKnopf.Parent = kameraGui
-- red dot on the menu button while rewards are waiting and the menu is closed
]===], [===[
menueKnopf.Parent = kameraGui
-- drawn menu symbol (three rounded bars) instead of the "☰" character, which some phones can't show;
-- it turns into an X when the menu is open
local symbol = Instance.new("Frame")
symbol.Name = "Symbol"
symbol.AnchorPoint = Vector2.new(0.5, 0)
symbol.Position = UDim2.new(0.5, 0, 0, 8)
symbol.Size = UDim2.fromOffset(22, 17)
symbol.BackgroundTransparency = 1
symbol.Parent = menueKnopf
local SYMBOL_Y = { 1.5, 8.5, 15.5 }
local striche = {}
for i, y in SYMBOL_Y do
	local b = Instance.new("Frame")
	b.Name = "Strich" .. i
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.Position = UDim2.new(0.5, 0, 0, y)
	b.Size = UDim2.fromOffset(22, 3)
	b.BackgroundColor3 = Color3.new(1, 1, 1)
	b.BorderSizePixel = 0
	b.Parent = symbol
	Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
	striche[i] = b
end
local function symbolSetzen(offen)
	local TS = game:GetService("TweenService")
	local info = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TS:Create(striche[1], info, { Position = UDim2.new(0.5, 0, 0, offen and 8.5 or SYMBOL_Y[1]), Rotation = offen and 45 or 0 }):Play()
	TS:Create(striche[3], info, { Position = UDim2.new(0.5, 0, 0, offen and 8.5 or SYMBOL_Y[3]), Rotation = offen and -45 or 0 }):Play()
	TS:Create(striche[2], info, { BackgroundTransparency = offen and 1 or 0, Size = UDim2.fromOffset(offen and 4 or 22, 3) }):Play()
end
-- red dot on the menu button while rewards are waiting and the menu is closed
]===])
src = ersetze(src, [===[
	game:GetService("TweenService"):Create(klappe, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(breite, 48) }):Play()
	menueKnopf.Icon.Text = offen and "✕" or "☰"
	menueKnopf.Beschriftung.Text = offen and "Close" or "Menu"
]===], [===[
	game:GetService("TweenService"):Create(klappe, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(breite, 48) }):Play()
	symbolSetzen(offen)
	menueKnopf.Beschriftung.Text = offen and "Close" or "Menu"
]===])
src = ersetze(src, [===[
	abstandText.Parent = halter

	RunService.RenderStepped:Connect(function()
		if not mmGui.Enabled then return end
]===], [===[
	abstandText.Parent = halter

	local naechsteKarte = 0
	RunService.RenderStepped:Connect(function()
		if not mmGui.Enabled then return end
]===])
src = ersetze(src, [===[
		if not mmGui.Enabled then return end
		local char = spieler.Character
]===], [===[
		if not mmGui.Enabled then return end
		-- the minimap is a 3D view of its own: redraw it at most 30 times a second (12 in performance mode)
		local jetzt = os.clock()
		if jetzt < naechsteKarte then return end
		naechsteKarte = jetzt + (_G.Sparmodus and 1 / 12 or 1 / 30)
		local char = spieler.Character
]===])
src = ersetze(src, [===[
	local SYMBOL = { Clear = "☀", Rain = "🌧", Fog = "🌫" }
	RunService.RenderStepped:Connect(function()
]===], [===[
	local SYMBOL = { Clear = "☀", Rain = "🌧", Fog = "🌫" }
	local naechsteUhr = 0
	RunService.RenderStepped:Connect(function()
]===])
src = ersetze(src, [===[
	RunService.RenderStepped:Connect(function()
		local zeit = ordner:GetAttribute("Uhrzeit") or 12
]===], [===[
	RunService.RenderStepped:Connect(function()
		if os.clock() < naechsteUhr then return end
		naechsteUhr = os.clock() + 0.5
		local zeit = ordner:GetAttribute("Uhrzeit") or 12
]===])
src = ersetze(src, [===[
		regen.CFrame = CFrame.new(kam.CFrame.Position + Vector3.new(0, 35, 0))
		tropfen.Rate = (ordner:GetAttribute("Wetter") == "Rain") and 900 or 0
	end)
]===], [===[
		regen.CFrame = CFrame.new(kam.CFrame.Position + Vector3.new(0, 35, 0))
		tropfen.Rate = (ordner:GetAttribute("Wetter") == "Rain") and (_G.Sparmodus and 250 or 900) or 0
	end)
]===])
src = ersetze(src, [===[
	Instance.new("UICorner", badge).CornerRadius = UDim.new(1, 0)
	RunService.RenderStepped:Connect(function()
]===], [===[
	Instance.new("UICorner", badge).CornerRadius = UDim.new(1, 0)
	local naechsterBlick = 0
	RunService.RenderStepped:Connect(function()
]===])
src = ersetze(src, [===[
	RunService.RenderStepped:Connect(function()
		gesuchtGui.Enabled = spieler:GetAttribute("Gesucht") == true
]===], [===[
	RunService.RenderStepped:Connect(function()
		if os.clock() < naechsterBlick then return end
		naechsterBlick = os.clock() + 0.1
		gesuchtGui.Enabled = spieler:GetAttribute("Gesucht") == true
]===])
src = ersetze(src, [===[
-- ---------------------------------------------------------------
-- NPC traffic: the server sends where the vehicles are, we draw them here
]===], [===[
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

	-- thousands of building windows use the Glass material; in Fast mode they become plain shiny plastic
	local fenster = {}
	local function fensterSetzen(x)
		x.Material = _G.Sparmodus and Enum.Material.SmoothPlastic or Enum.Material.Glass
	end
	_G.SparmodusSetzen = function(an)
		local vorher = _G.Sparmodus
		_G.Sparmodus = an == true
		Verkehr.sparmodus = _G.Sparmodus
		for _, e in Lighting:GetChildren() do
			if e:IsA("SunRaysEffect") or e:IsA("DepthOfFieldEffect") or e:IsA("BloomEffect") then
				e.Enabled = not _G.Sparmodus
			end
		end
		if vorher ~= _G.Sparmodus then
			for x in fenster do fensterSetzen(x) end
		end
	end
	task.spawn(function()
		local karte = workspace:WaitForChild("Karte")
		local function merken(x)
			if x:IsA("BasePart") and (x.Name == "Fenster" or x.Name == "Scheiben") and x.Material == Enum.Material.Glass then
				fenster[x] = true
				if _G.Sparmodus then fensterSetzen(x) end
			end
		end
		for i, x in karte:GetDescendants() do
			merken(x)
			if i % 4000 == 0 then task.wait() end
		end
		karte.DescendantAdded:Connect(merken)
		karte.DescendantRemoving:Connect(function(x) fenster[x] = nil end)
	end)
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
]===])
src = ersetze(src, [===[
-- ---------------------------------------------------------------
_G.Einstellungen = { minimap = true, mph = false, grosseAnzeige = false, ersteP = false }

]===], [===[
-- ---------------------------------------------------------------
_G.Einstellungen = { minimap = true, mph = false, grosseAnzeige = false, ersteP = false, sparmodus = false, sparmodusGewaehlt = false }
_G.SparmodusAuto() -- phones / tablets: performance mode until the saved settings say otherwise

]===])
src = ersetze(src, [===[
	local e = _G.Einstellungen
	if _G.MinimapGui then _G.MinimapGui.Enabled = e.minimap end
]===], [===[
	local e = _G.Einstellungen
	if _G.SparmodusSetzen then _G.SparmodusSetzen(e.sparmodus) end
	if _G.MinimapGui then _G.MinimapGui.Enabled = e.minimap end
]===])
src = ersetze(src, [===[
einstellRahmen.Position = UDim2.fromScale(0.5, 0.5)
einstellRahmen.Size = UDim2.fromOffset(380, 330)
einstellRahmen.BackgroundColor3 = Color3.fromRGB(25, 30, 40)
]===], [===[
einstellRahmen.Position = UDim2.fromScale(0.5, 0.5)
einstellRahmen.Size = UDim2.fromOffset(380, 384)
einstellRahmen.BackgroundColor3 = Color3.fromRGB(25, 30, 40)
]===])
src = ersetze(src, [===[
	{ "ersteP", "Start in first person", "On", "Off" },
}
]===], [===[
	{ "ersteP", "Start in first person", "On", "Off" },
	{ "sparmodus", "Graphics", "⚡ Fast", "Best" },
}
]===])
src = ersetze(src, [===[
		_G.Einstellungen[o[1]] = not _G.Einstellungen[o[1]]
		for schl, ok in optionKnoepfe do
]===], [===[
		_G.Einstellungen[o[1]] = not _G.Einstellungen[o[1]]
		if o[1] == "sparmodus" then _G.Einstellungen.sparmodusGewaehlt = true end
		for schl, ok in optionKnoepfe do
]===])
src = ersetze(src, [===[
-- small gear button to open the settings at any time
local zahnrad = leistenKnopf("⚙", "Settings", 7)
zahnrad.MouseButton1Click:Connect(function()
]===], [===[
-- small gear button to open the settings at any time
local zahnrad = leistenKnopf("⚙️", "Settings", 7)
zahnrad.MouseButton1Click:Connect(function()
]===])
src = ersetze(src, [===[
		end
		knoepfeAktualisieren()
]===], [===[
		end
		if _G.SparmodusAuto then _G.SparmodusAuto() end
		knoepfeAktualisieren()
]===])
assert(#src == 154345, "Ergebnis-Länge falsch: " .. #src)
s.Source = src
end)

schritt("Verkehr", function()
local s = game.ReplicatedStorage.Fuehrerschein.Verkehr
local src = s.Source
assert(#src == 30065, "Ausgangsstand passt nicht: " .. #src)
src = ersetze(src, [===[

	local takt = 0
]===], [===[

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
]===])
src = ersetze(src, [===[
			liste = hindernisse()
		end
]===], [===[
			liste = hindernisse()
		end
		for _, a in ampelDaten do
			a.phase = a.inst:GetAttribute("Phase")
		end
]===])
src = ersetze(src, [===[
			-- traffic lights: stop before the line when it is not green
			for _, ampel in ampeln:GetChildren() do
				local L = ampel:GetAttribute("Haltelinie")
				local d = ampel:GetAttribute("Anfahrt")
				if L and d and ampel:GetAttribute("Phase") ~= "Gruen" and d:Dot(f.dir) < -0.7 then
					local rel = L - f.pos
]===], [===[
			-- traffic lights: stop before the line when it is not green
			for _, a in ampelDaten do
				local L, d = a.L, a.d
				if a.phase ~= "Gruen" and d:Dot(f.dir) < -0.7 then
					local rel = L - f.pos
]===])
src = ersetze(src, [===[
						-- yellow and already very close: drive on
						if not (ampel:GetAttribute("Phase") == "Gelb" and vor < f.v * f.v / 60) then
							ziel = math.min(ziel, bremsTempo(vor - 1.5))
]===], [===[
						-- yellow and already very close: drive on
						if not (a.phase == "Gelb" and vor < f.v * f.v / 60) then
							ziel = math.min(ziel, bremsTempo(vor - 1.5))
]===])
src = ersetze(src, [===[
			-- STOP signs: stand still for a moment, then go
			if stopps then
				for _, schild in stopps:GetChildren() do
					local L = schild:GetAttribute("Haltelinie")
					local d = schild:GetAttribute("Anfahrt")
					if L and d and d:Dot(f.dir) < -0.7 and not f.gehaltenAn[schild] then
						local rel = L - f.pos
]===], [===[
			-- STOP signs: stand still for a moment, then go
			do
				for _, sd in schildDaten do
					local schild, L, d = sd.inst, sd.L, sd.d
					if d:Dot(f.dir) < -0.7 and not f.gehaltenAn[schild] then
						local rel = L - f.pos
]===])
src = ersetze(src, [===[
						local vor = rel:Dot(f.dir) - f.laenge / 2
						local vorfahrtGewaehren = schild:GetAttribute("Typ") == "Vorfahrt gewaehren"
						if vorfahrtGewaehren and vor > -1 and vor < f.weit and math.abs(rel:Dot(rechtsVon(f.dir))) < 5 then
]===], [===[
						local vor = rel:Dot(f.dir) - f.laenge / 2
						local vorfahrtGewaehren = sd.gewaehren
						if vorfahrtGewaehren and vor > -1 and vor < f.weit and math.abs(rel:Dot(rechtsVon(f.dir))) < 5 then
]===])
src = ersetze(src, [===[
	local hoch = Vector3.new(0, 0.2, 0)
	RunService.RenderStepped:Connect(function(dt)
]===], [===[
	local hoch = Vector3.new(0, 0.2, 0)
	local bild = 0
	RunService.RenderStepped:Connect(function(dt)
]===])
src = ersetze(src, [===[
		dt = math.min(dt, 0.1)
		for _, a in autos do
]===], [===[
		dt = math.min(dt, 0.1)
		bild += 1
		local kam = workspace.CurrentCamera
		local auge = kam and kam.CFrame and kam.CFrame.Position or Vector3.zero
		for _, a in autos do
]===])
src = ersetze(src, [===[
			local pos = Verkehr.ort(a.spur, a.s)
			local _, blick = Verkehr.ort(a.spur, a.s + 3)
			a.modell:PivotTo(CFrame.lookAt(pos + hoch, pos + hoch + blick))
			if #a.blaulicht > 0 then
				Verkehr.blaulichtZeigen(a.blaulicht, event.Parent:GetAttribute("Blaulicht_" .. a.nr) == true)
			end
]===], [===[
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
]===])
assert(#src == 31268, "Ergebnis-Länge falsch: " .. #src)
s.Source = src
end)

schritt("Auto", function()
local s = game.ServerScriptService.FuehrerscheinServer.Auto
local src = s.Source
local start = #src
src = ersetze(src, [===[
		beschreibung = "Exclusive: midnight black, gold rims, purple underglow. 195 km/h.",
		festeFarbe = Color3.fromRGB(18, 16, 24), tuning = { felgen = 3, neon = 4 },
		R = 1.4, spur = 3.0, achse = 5.14, laenge = 17.4, breite = 7.0,
]===], [===[
		beschreibung = "Exclusive: midnight black, gold rims, purple underglow. 195 km/h.",
		festeFarbe = Color3.fromRGB(18, 16, 24), tuning = { felgen = 3, neon = 4 }, nachtDetails = true,
		R = 1.4, spur = 3.0, achse = 5.14, laenge = 17.4, breite = 7.0,
]===])
src = ersetze(src, [===[
	glanzschwarz = { farbe = Color3.fromRGB(10, 10, 12), mat = Enum.Material.SmoothPlastic, glanz = 0.35 },
}
]===], [===[
	glanzschwarz = { farbe = Color3.fromRGB(10, 10, 12), mat = Enum.Material.SmoothPlastic, glanz = 0.35 },
	neon_lila = { farbe = Color3.fromRGB(150, 70, 255), mat = Enum.Material.Neon },
	rueckglas = { farbe = Color3.fromRGB(110, 8, 12), mat = Enum.Material.SmoothPlastic, glanz = 0.3 },
}
]===])
src = ersetze(src, [===[
		end
		-- lights, grille, mirrors ... (positions come from the generator)
		for _, t in rundDef.anbau do
			local art = ANBAU_ART[t.a] or ANBAU_ART.schwarz
]===], [===[
		end
		-- lights, grille, mirrors ... (positions come from the generator);
		-- special editions also get their extra parts (Night Edition: detailed rear light)
		local zusatz = rundDef.anbau
		if D.nachtDetails and rundDef.nacht then
			zusatz = table.clone(rundDef.anbau)
			for _, t in rundDef.nacht do table.insert(zusatz, t) end
		end
		for _, t in zusatz do
			local art = ANBAU_ART[t.a] or ANBAU_ART.schwarz
]===])
assert(#src - start == 462, "Delta falsch: " .. (#src - start))
s.Source = src
end)

schritt("Karosserien (Night Edition)", function()
local s = game.ServerScriptService.FuehrerscheinServer.Karosserien
local src = s.Source
if string.find(src, "nacht = {", 1, true) then return end
local a = assert(string.find(src, "\tgs = {", 1, true), "gs-Eintrag fehlt")
local k = assert(string.find(src, "\t\tkollision = {", a, true), "kollision im gs-Eintrag fehlt")
s.Source = src:sub(1, k - 1) .. [==[
		nacht = {
			{ n = "Segment", a = "fuge", g = { 0.028, 0.141, 0.03 }, p = { -2.25, 3.14, 8.363 }, s = false, r = { 0, -30.61, 0 } },
			{ n = "Segment", a = "fuge", g = { 0.028, 0.152, 0.03 }, p = { -1.95, 3.186, 8.476 }, s = false, r = { 0, -22.64, 0 } },
			{ n = "Segment", a = "fuge", g = { 0.028, 0.159, 0.03 }, p = { -1.65, 3.219, 8.549 }, s = false, r = { 0, -15.05, 0 } },
			{ n = "Segment", a = "fuge", g = { 0.028, 0.162, 0.03 }, p = { -1.35, 3.242, 8.617 }, s = false, r = { 0, -13.04, 0 } },
			{ n = "Segment", a = "fuge", g = { 0.028, 0.163, 0.03 }, p = { -1.05, 3.258, 8.662 }, s = false, r = { 0, -7.48, 0 } },
			{ n = "Segment", a = "fuge", g = { 0.028, 0.163, 0.03 }, p = { -0.75, 3.269, 8.691 }, s = false, r = { 0, -7.28, 0 } },
			{ n = "Segment", a = "fuge", g = { 0.028, 0.162, 0.03 }, p = { -0.45, 3.275, 8.724 }, s = false, r = { 0, -4.86, 0 } },
			{ n = "Segment", a = "fuge", g = { 0.028, 0.161, 0.03 }, p = { -0.15, 3.279, 8.734 }, s = false, r = { 0, 0.14, 0 } },
			{ n = "Segment", a = "fuge", g = { 0.028, 0.16, 0.03 }, p = { 0.15, 3.281, 8.736 }, s = false, r = { 0, 0.33, 0 } },
			{ n = "Segment", a = "fuge", g = { 0.028, 0.16, 0.03 }, p = { 0.45, 3.279, 8.715 }, s = false, r = { 0, 7.1, 0 } },
			{ n = "Segment", a = "fuge", g = { 0.028, 0.161, 0.03 }, p = { 0.75, 3.275, 8.677 }, s = false, r = { 0, 6.08, 0 } },
			{ n = "Segment", a = "fuge", g = { 0.028, 0.162, 0.03 }, p = { 1.05, 3.266, 8.655 }, s = false, r = { 0, 5.81, 0 } },
			{ n = "Segment", a = "fuge", g = { 0.028, 0.163, 0.03 }, p = { 1.35, 3.252, 8.616 }, s = false, r = { 0, 11.52, 0 } },
			{ n = "Segment", a = "fuge", g = { 0.028, 0.163, 0.03 }, p = { 1.65, 3.23, 8.559 }, s = false, r = { 0, 16.08, 0 } },
			{ n = "Segment", a = "fuge", g = { 0.028, 0.162, 0.03 }, p = { 1.95, 3.197, 8.47 }, s = false, r = { 0, 25.72, 0 } },
			{ n = "Segment", a = "fuge", g = { 0.028, 0.158, 0.03 }, p = { 2.25, 3.15, 8.348 }, s = false, r = { 0, 30.56, 0 } },
			{ n = "Lichtrahmen", a = "glanzschwarz", g = { 0.06, 0.06, 0.345 }, p = { -2.375, 3.242, 8.126 }, s = false, d = { 0.8782, 0.2015, 0.4338 } },
			{ n = "Lichtrahmen", a = "glanzschwarz", g = { 0.06, 0.06, 0.342 }, p = { -2.125, 3.293, 8.248 }, s = false, d = { 0.888, 0.156, 0.4325 } },
			{ n = "Lichtrahmen", a = "glanzschwarz", g = { 0.06, 0.06, 0.337 }, p = { -1.875, 3.331, 8.367 }, s = false, d = { 0.9024, 0.119, 0.4142 } },
			{ n = "Lichtrahmen", a = "glanzschwarz", g = { 0.06, 0.06, 0.324 }, p = { -1.625, 3.36, 8.466 }, s = false, d = { 0.9452, 0.0916, 0.3134 } },
			{ n = "Lichtrahmen", a = "glanzschwarz", g = { 0.06, 0.06, 0.318 }, p = { -1.375, 3.381, 8.537 }, s = false, d = { 0.9699, 0.0675, 0.2341 } },
			{ n = "Lichtrahmen", a = "glanzschwarz", g = { 0.06, 0.06, 0.314 }, p = { -1.125, 3.396, 8.59 }, s = false, d = { 0.9826, 0.048, 0.1796 } },
			{ n = "Lichtrahmen", a = "glanzschwarz", g = { 0.06, 0.06, 0.313 }, p = { -0.875, 3.406, 8.632 }, s = false, d = { 0.9878, 0.0329, 0.1523 } },
			{ n = "Lichtrahmen", a = "glanzschwarz", g = { 0.06, 0.06, 0.311 }, p = { -0.625, 3.413, 8.662 }, s = false, d = { 0.996, 0.0218, 0.0865 } },
			{ n = "Lichtrahmen", a = "glanzschwarz", g = { 0.06, 0.06, 0.31 }, p = { -0.375, 3.417, 8.672 }, s = false, d = { 0.9999, 0.0134, -0.0089 } },
			{ n = "Lichtrahmen", a = "glanzschwarz", g = { 0.06, 0.06, 0.311 }, p = { -0.125, 3.42, 8.662 }, s = false, d = { 0.9972, 0.0068, -0.075 } },
			{ n = "Lichtrahmen", a = "glanzschwarz", g = { 0.06, 0.06, 0.31 }, p = { 0.125, 3.421, 8.652 }, s = false, d = { 1, 0.0007, 0.001 } },
			{ n = "Lichtrahmen", a = "glanzschwarz", g = { 0.06, 0.06, 0.31 }, p = { 0.375, 3.42, 8.66 }, s = false, d = { 0.9984, -0.0059, 0.0568 } },
			{ n = "Lichtrahmen", a = "glanzschwarz", g = { 0.06, 0.06, 0.31 }, p = { 0.625, 3.417, 8.66 }, s = false, d = { 0.9986, -0.0143, -0.0506 } },
			{ n = "Lichtrahmen", a = "glanzschwarz", g = { 0.06, 0.06, 0.313 }, p = { 0.875, 3.412, 8.636 }, s = false, d = { 0.989, -0.0253, -0.1457 } },
			{ n = "Lichtrahmen", a = "glanzschwarz", g = { 0.06, 0.06, 0.315 }, p = { 1.125, 3.404, 8.593 }, s = false, d = { 0.9808, -0.0402, -0.1907 } },
			{ n = "Lichtrahmen", a = "glanzschwarz", g = { 0.06, 0.06, 0.317 }, p = { 1.375, 3.391, 8.539 }, s = false, d = { 0.9715, -0.0599, -0.2293 } },
			{ n = "Lichtrahmen", a = "glanzschwarz", g = { 0.06, 0.06, 0.323 }, p = { 1.625, 3.372, 8.47 }, s = false, d = { 0.9497, -0.0842, -0.3015 } },
			{ n = "Lichtrahmen", a = "glanzschwarz", g = { 0.06, 0.06, 0.332 }, p = { 1.875, 3.346, 8.379 }, s = false, d = { 0.9187, -0.1134, -0.3783 } },
			{ n = "Lichtrahmen", a = "glanzschwarz", g = { 0.06, 0.06, 0.347 }, p = { 2.125, 3.31, 8.26 }, s = false, d = { 0.8703, -0.1452, -0.4706 } },
			{ n = "Lichtrahmen", a = "glanzschwarz", g = { 0.06, 0.06, 0.351 }, p = { 2.375, 3.261, 8.122 }, s = false, d = { 0.8578, -0.189, -0.4779 } },
			{ n = "Lichtrahmen", a = "glanzschwarz", g = { 0.06, 0.06, 0.349 }, p = { -2.375, 2.988, 8.268 }, s = false, d = { 0.8663, 0.1495, 0.4766 } },
			{ n = "Lichtrahmen", a = "glanzschwarz", g = { 0.06, 0.06, 0.334 }, p = { -2.125, 3.027, 8.391 }, s = false, d = { 0.9117, 0.1244, 0.3916 } },
			{ n = "Lichtrahmen", a = "glanzschwarz", g = { 0.06, 0.06, 0.328 }, p = { -1.875, 3.057, 8.49 }, s = false, d = { 0.9343, 0.0996, 0.3423 } },
			{ n = "Lichtrahmen", a = "glanzschwarz", g = { 0.06, 0.06, 0.324 }, p = { -1.625, 3.081, 8.578 }, s = false, d = { 0.946, 0.0779, 0.3148 } },
			{ n = "Lichtrahmen", a = "glanzschwarz", g = { 0.06, 0.06, 0.317 }, p = { -1.375, 3.099, 8.647 }, s = false, d = { 0.9745, 0.0612, 0.2157 } },
			{ n = "Lichtrahmen", a = "glanzschwarz", g = { 0.06, 0.06, 0.313 }, p = { -1.125, 3.113, 8.693 }, s = false, d = { 0.9883, 0.0467, 0.1452 } },
			{ n = "Lichtrahmen", a = "glanzschwarz", g = { 0.06, 0.06, 0.313 }, p = { -0.875, 3.123, 8.729 }, s = false, d = { 0.9894, 0.0346, 0.1411 } },
			{ n = "Lichtrahmen", a = "glanzschwarz", g = { 0.06, 0.06, 0.311 }, p = { -0.625, 3.13, 8.759 }, s = false, d = { 0.9951, 0.0249, 0.0956 } },
			{ n = "Lichtrahmen", a = "glanzschwarz", g = { 0.06, 0.06, 0.31 }, p = { -0.375, 3.136, 8.779 }, s = false, d = { 0.9981, 0.0166, 0.0589 } },
			{ n = "Lichtrahmen", a = "glanzschwarz", g = { 0.06, 0.06, 0.31 }, p = { -0.125, 3.139, 8.788 }, s = false, d = { 0.9998, 0.0091, 0.017 } },
			{ n = "Lichtrahmen", a = "glanzschwarz", g = { 0.06, 0.06, 0.31 }, p = { 0.125, 3.14, 8.789 }, s = false, d = { 0.9999, 0.0015, -0.0131 } },
			{ n = "Lichtrahmen", a = "glanzschwarz", g = { 0.06, 0.06, 0.31 }, p = { 0.375, 3.14, 8.783 }, s = false, d = { 0.9994, -0.0068, -0.0344 } },
			{ n = "Lichtrahmen", a = "glanzschwarz", g = { 0.06, 0.06, 0.311 }, p = { 0.625, 3.137, 8.769 }, s = false, d = { 0.9972, -0.0166, -0.0725 } },
			{ n = "Lichtrahmen", a = "glanzschwarz", g = { 0.06, 0.06, 0.312 }, p = { 0.875, 3.131, 8.744 }, s = false, d = { 0.991, -0.0286, -0.1311 } },
			{ n = "Lichtrahmen", a = "glanzschwarz", g = { 0.06, 0.06, 0.313 }, p = { 1.125, 3.122, 8.708 }, s = false, d = { 0.9873, -0.0437, -0.1527 } },
			{ n = "Lichtrahmen", a = "glanzschwarz", g = { 0.06, 0.06, 0.318 }, p = { 1.375, 3.108, 8.657 }, s = false, d = { 0.9679, -0.0616, -0.2435 } },
			{ n = "Lichtrahmen", a = "glanzschwarz", g = { 0.06, 0.06, 0.326 }, p = { 1.625, 3.089, 8.582 }, s = false, d = { 0.9413, -0.0826, -0.3273 } },
			{ n = "Lichtrahmen", a = "glanzschwarz", g = { 0.06, 0.06, 0.328 }, p = { 1.875, 3.064, 8.493 }, s = false, d = { 0.9342, -0.1096, -0.3396 } },
			{ n = "Lichtrahmen", a = "glanzschwarz", g = { 0.06, 0.06, 0.334 }, p = { 2.125, 3.03, 8.395 }, s = false, d = { 0.9128, -0.1399, -0.3837 } },
			{ n = "Lichtrahmen", a = "glanzschwarz", g = { 0.06, 0.06, 0.35 }, p = { 2.375, 2.986, 8.273 }, s = false, d = { 0.8614, -0.1691, -0.479 } },
			{ n = "Nachtlinie", a = "neon_lila", g = { 0.045, 0.045, 0.318 }, p = { -2.125, 2.902, 8.406 }, s = false, d = { 0.9157, 0.1249, 0.3821 } },
			{ n = "Nachtlinie", a = "neon_lila", g = { 0.045, 0.045, 0.314 }, p = { -1.875, 2.932, 8.506 }, s = false, d = { 0.9295, 0.0991, 0.3553 } },
			{ n = "Nachtlinie", a = "neon_lila", g = { 0.045, 0.045, 0.296 }, p = { -1.625, 2.956, 8.56 }, s = false, d = { 0.9951, 0.0819, 0.0552 } },
			{ n = "Nachtlinie", a = "neon_lila", g = { 0.045, 0.045, 0.303 }, p = { -1.375, 2.974, 8.537 }, s = false, d = { 0.97, 0.0609, -0.2351 } },
			{ n = "Nachtlinie", a = "neon_lila", g = { 0.045, 0.045, 0.297 }, p = { -1.125, 2.988, 8.522 }, s = false, d = { 0.9915, 0.0469, 0.121 } },
			{ n = "Nachtlinie", a = "neon_lila", g = { 0.045, 0.045, 0.296 }, p = { -0.875, 2.998, 8.549 }, s = false, d = { 0.9953, 0.0348, 0.0899 } },
			{ n = "Nachtlinie", a = "neon_lila", g = { 0.045, 0.045, 0.296 }, p = { -0.625, 3.005, 8.57 }, s = false, d = { 0.9966, 0.0249, 0.078 } },
			{ n = "Nachtlinie", a = "neon_lila", g = { 0.045, 0.045, 0.295 }, p = { -0.375, 3.011, 8.583 }, s = false, d = { 0.9994, 0.0166, 0.0313 } },
			{ n = "Nachtlinie", a = "neon_lila", g = { 0.045, 0.045, 0.295 }, p = { -0.125, 3.014, 8.59 }, s = false, d = { 0.9997, 0.0091, 0.0223 } },
			{ n = "Nachtlinie", a = "neon_lila", g = { 0.045, 0.045, 0.295 }, p = { 0.125, 3.015, 8.59 }, s = false, d = { 0.9997, 0.0015, -0.0225 } },
			{ n = "Nachtlinie", a = "neon_lila", g = { 0.045, 0.045, 0.295 }, p = { 0.375, 3.015, 8.583 }, s = false, d = { 0.9994, -0.0068, -0.0345 } },
			{ n = "Nachtlinie", a = "neon_lila", g = { 0.045, 0.045, 0.296 }, p = { 0.625, 3.012, 8.57 }, s = false, d = { 0.9976, -0.0166, -0.0672 } },
			{ n = "Nachtlinie", a = "neon_lila", g = { 0.045, 0.045, 0.296 }, p = { 0.875, 3.006, 8.549 }, s = false, d = { 0.9942, -0.0287, -0.1032 } },
			{ n = "Nachtlinie", a = "neon_lila", g = { 0.045, 0.045, 0.297 }, p = { 1.125, 2.997, 8.522 }, s = false, d = { 0.9929, -0.044, -0.1101 } },
			{ n = "Nachtlinie", a = "neon_lila", g = { 0.045, 0.045, 0.305 }, p = { 1.375, 2.983, 8.543 }, s = false, d = { 0.9622, -0.0612, 0.2655 } },
			{ n = "Nachtlinie", a = "neon_lila", g = { 0.045, 0.045, 0.297 }, p = { 1.625, 2.964, 8.567 }, s = false, d = { 0.993, -0.0871, -0.0797 } },
			{ n = "Nachtlinie", a = "neon_lila", g = { 0.045, 0.045, 0.314 }, p = { 1.875, 2.939, 8.51 }, s = false, d = { 0.9294, -0.1091, -0.3525 } },
			{ n = "Nachtlinie", a = "neon_lila", g = { 0.045, 0.045, 0.318 }, p = { 2.125, 2.905, 8.411 }, s = false, d = { 0.9157, -0.1403, -0.3766 } },
			{ n = "Ruecklicht", a = "neon_rot", g = { 0.085, 0.085, 0.237 }, p = { -2.62, 2.875, 8.136 }, s = false, d = { 0, -0.9875, 0.1578 } },
			{ n = "Ruecklicht", a = "neon_rot", g = { 0.085, 0.085, 0.235 }, p = { -2.62, 2.725, 8.153 }, s = false, d = { 0, -0.9973, 0.0739 } },
			{ n = "Ruecklicht", a = "neon_rot", g = { 0.085, 0.085, 0.235 }, p = { -2.62, 2.575, 8.158 }, s = false, d = { 0, -0.9999, -0.0165 } },
			{ n = "Ruecklicht", a = "neon_rot", g = { 0.085, 0.085, 0.237 }, p = { 2.62, 2.875, 8.14 }, s = false, d = { 0, -0.9875, 0.1577 } },
			{ n = "Ruecklicht", a = "neon_rot", g = { 0.085, 0.085, 0.235 }, p = { 2.62, 2.725, 8.156 }, s = false, d = { 0, -0.9984, 0.0557 } },
			{ n = "Ruecklicht", a = "neon_rot", g = { 0.085, 0.085, 0.235 }, p = { 2.62, 2.575, 8.161 }, s = false, d = { 0, -0.9999, 0.0106 } },
			{ n = "Rueckstrahler", a = "rueckglas", g = { 0.55, 0.1, 0.04 }, p = { -2.85, 1.55, 8.227 }, s = false, r = { 0, -49.15, 0 } },
			{ n = "Endrohr", a = "alu", g = { 0.5, 0.34, 0.34 }, p = { -1.95, 1.28, 8.378 }, s = false, f = "zyl" },
			{ n = "Endrohr_Innen", a = "fuge", g = { 0.52, 0.24, 0.24 }, p = { -1.95, 1.28, 8.378 }, s = false, f = "zyl" },
			{ n = "Rueckstrahler", a = "rueckglas", g = { 0.55, 0.1, 0.04 }, p = { 2.85, 1.55, 8.248 }, s = false, r = { 0, 49.29, 0 } },
			{ n = "Endrohr", a = "alu", g = { 0.5, 0.34, 0.34 }, p = { 1.95, 1.28, 8.373 }, s = false, f = "zyl" },
			{ n = "Endrohr_Innen", a = "fuge", g = { 0.52, 0.24, 0.24 }, p = { 1.95, 1.28, 8.373 }, s = false, f = "zyl" },
			{ n = "Diffusor", a = "glanzschwarz", g = { 0.05, 0.24, 0.42 }, p = { -1.2, 1.14, 8.83 }, s = false },
			{ n = "Diffusor", a = "glanzschwarz", g = { 0.05, 0.24, 0.42 }, p = { -0.6, 1.14, 8.617 }, s = false },
			{ n = "Diffusor", a = "glanzschwarz", g = { 0.05, 0.24, 0.42 }, p = { 0, 1.14, -8.14 }, s = false },
			{ n = "Diffusor", a = "glanzschwarz", g = { 0.05, 0.24, 0.42 }, p = { 0.6, 1.14, 8.619 }, s = false },
			{ n = "Diffusor", a = "glanzschwarz", g = { 0.05, 0.24, 0.42 }, p = { 1.2, 1.14, 8.8 }, s = false },
		},
]==] .. src:sub(k)
end)

schritt("Streaming + Detailstufen", function()
workspace.StreamingEnabled = true
workspace.StreamingTargetRadius = 640
workspace.StreamingMinRadius = 160
local n = 0
for _, m in workspace.Karte:GetDescendants() do
	if m:IsA("Model") and #m:GetDescendants() >= 12 then
		if pcall(function() m.LevelOfDetail = Enum.ModelLevelOfDetail.StreamingMesh end) then n += 1 end
	end
end
assert(n > 0, "Detailstufen liessen sich nicht setzen")
end)
print(table.concat(ergebnis, "\n"))
print("Fertig - jetzt File -> Save (Strg+S)")
