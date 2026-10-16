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
local Chaos = require(script:WaitForChild("Chaos"))
local Party = require(script:WaitForChild("Party"))
local Hupen = require(ordner:WaitForChild("Hupen"))
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
		-- v31: best stars per lesson (key = lesson number as text), onboarding steps already reported
		sterne = {}, funnel = {},
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

-- Onboarding funnel for the Roblox creator dashboard (Analytics -> Funnels): shows where new players stop.
-- Every step is reported once per player; only works in the published game (in Studio it is just skipped).
local AnalyticsService = game:GetService("AnalyticsService")
local FUNNEL = {
	"Joined", "Sat in the first lesson car", "First lesson done", "Third lesson done", "All lessons done",
	"Theory test passed", "Driver's license", "First own car", "First job done",
}
local function funnel(p, schritt)
	local d = daten[p]
	if not d or not FUNNEL[schritt] then return end
	d.funnel = d.funnel or {}
	local key = tostring(schritt)
	if d.funnel[key] then return end
	d.funnel[key] = true
	pcall(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(p, schritt, FUNNEL[schritt])
	end)
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
	funnel(p, 1)
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
	if stil ~= "uniform" and not fest.uniform then
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
	Chaos.reaktion(p, st, erfolg and "ende_gut" or "ende_schlecht")
	Chaos.ende(st)
	if st.party then
		-- party test: the race decides (no stars, no license)
		if p.Parent then fahrEvent:FireClient(p, { typ = "ende", erfolg = erfolg, text = text, fehler = st.fehler, party = true }) end
		Party.fertig(p, st, erfolg)
		task.delay(erfolg and 4 or 1, function()
			aussteigen(st.sitz)
			if st.model then st.model:Destroy() end
		end)
		return
	end
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
		if not st.lkw then funnel(p, 7) end
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
	end
	local sterne, besser, bisher
	if erfolg and d and not st.pruefung then
		local neu = st.nr > d.fahrstunden
		d.fahrstunden = math.max(d.fahrstunden, st.nr)
		-- 1-3 stars: 0 mistakes = 3, up to 2 mistakes = 2, otherwise 1. Better than before = bonus coins.
		sterne = st.fehler == 0 and 3 or (st.fehler <= 2 and 2 or 1)
		d.sterne = d.sterne or {}
		local key = tostring(st.nr)
		bisher = d.sterne[key] or 0
		besser = sterne > bisher
		if besser then d.sterne[key] = sterne end
		geaendert(p)
		if neu then geldGeben(p, 25, "Lesson complete") end
		if besser and bisher > 0 then geldGeben(p, (sterne - bisher) * 30, "More stars") end
		if neu or besser then
			xpGeben(p, st.fehler == 0 and 80 or 50, st.fehler == 0 and "Perfect lesson!" or "Lesson complete")
		else
			xpGeben(p, 20, "Lesson repeated")
		end
		if st.fehler == 0 then Missionen.fortschritt(p, "perfekt", 1) end
		if st.nr == 1 then funnel(p, 3) end
		if st.nr == 3 then funnel(p, 4) end
		if d.fahrstunden >= #LEKTIONEN then funnel(p, 5) end
	end
	if p.Parent and not (st.pruefung and erfolg) then
		-- what to do next (shown in the result window)
		local weiter
		if d and erfolg and not st.pruefung then
			if d.fahrstunden < #LEKTIONEN then
				weiter = d.theorie and "Talk to Anna for your next lesson." or "Next: your next lesson with Anna – or the theory lesson at the whiteboard in the classroom."
			elseif not d.theorie then
				weiter = "All lessons done! Now the theory: whiteboard in the classroom, then the test at an exam desk."
			elseif not d.fuehrerschein then
				weiter = "You're ready for the driving test – talk to Anna!"
			end
		end
		fahrEvent:FireClient(p, { typ = "ende", erfolg = erfolg, text = text, fehler = st.fehler, nr = st.nr, gesamt = #LEKTIONEN, pruefung = st.pruefung,
			sterne = sterne, besser = besser and bisher and bisher > 0, weiter = weiter })
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
		sprecher = st.pruefung and "Examiner" or (st.chaos and st.chaos.lehrer.name) or "Instructor",
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
	Chaos.losgehen(st)
	fahrEvent:FireClient(p, info)
end

local function warnung(p, st, text, punkte)
	if Chaos.schonzeit(st) then
		-- spinning on a banana peel: turns, speed or bumps right now are not your fault
		st.drehSumme = 0
		return
	end
	st.fehler += punkte or 1
	st.letzteWarnung = os.clock()
	fahrEvent:FireClient(p, { typ = "warnung", text = text, fehler = st.fehler, grenze = st.erlaubt })
	Chaos.reaktion(p, st, (punkte or 1) >= 3 and "unfall" or "fehler")
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
local function mitfahrer(modell, name, anzeige, haut, oberteil, hose, platz, stil)
	task.spawn(function()
		local figur, hum = npc(name, anzeige, haut, oberteil, hose, stil or "uniform")
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

-- 👥 friends ride along: "Ride along" on a free passenger seat (everybody except the driver/owner)
local function mitfahrPrompt(besitzer, sitz, modell)
	local pp = Instance.new("ProximityPrompt")
	pp.Name = "Mitfahren"
	pp.ActionText = "Ride along"
	pp.ObjectText = besitzer.DisplayName .. "'s car"
	pp.HoldDuration = 0
	pp.MaxActivationDistance = 12
	pp.RequiresLineOfSight = false
	pp.Parent = sitz
	pp.Triggered:Connect(function(wer)
		if wer == besitzer or sitz.Occupant or not modell.Parent then return end
		if lektionen[wer] or jobs[wer] then
			fahrEvent:FireClient(wer, { typ = "hinweis", text = "Finish your own lesson or job first." })
			return
		end
		local hum = wer.Character and wer.Character:FindFirstChildOfClass("Humanoid")
		if not hum or hum.SeatPart then return end
		sitz:Sit(hum)
		fahrEvent:FireClient(wer, { typ = "chaos", titel = "👥 RIDING ALONG!", text = ("You're in %s's car! H = honk, 🍌 = throw bananas. Jump to get out."):format(besitzer.DisplayName), farbe = "gruen" })
		if besitzer.Parent then
			fahrEvent:FireClient(besitzer, { typ = "chaos", titel = "👥 " .. wer.DisplayName:upper() .. " GOT IN!", text = "Your friend is riding along – you both get the dodge coins!", farbe = "gruen" })
		end
	end)
	sitz:GetPropertyChangedSignal("Occupant"):Connect(function()
		pp.Enabled = sitz.Occupant == nil
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

local function lektionStarten(p, art, wiederholNr, party)
	local d = daten[p]
	local pruefung = art == "pruefung" or art == "lkw"
	local lkw = art == "lkw"
	if lektionen[p] then
		return { fehler = "You already have a lesson in progress." }
	end
	if jobs[p] then
		return { fehler = "Finish or cancel your delivery job first." }
	end
	-- v31: drive first, theory later. Lessons are open right away; the theory test is needed for the driving test.
	if not d then
		return { fehler = "Still loading – try again in a moment." }
	end
	if pruefung and not d.theorie then
		return { fehler = "You need to pass the theory test first: theory lesson at the whiteboard, then the test at an exam desk (classroom)." }
	end
	if not d.angemeldet then
		d.angemeldet = true
		geaendert(p)
	end
	local nr, lektion
	if art == "party" then
		-- 🏁 party test: everybody drives the same exam route, no requirements
		nr = 0
		lektion = party.lektion
	elseif art == "wiederholen" then
		-- replay a finished lesson to get more stars
		nr = math.floor(tonumber(wiederholNr) or 0)
		lektion = LEKTIONEN[nr]
		if not lektion or nr > d.fahrstunden then
			return { fehler = "You can only repeat lessons you have already finished." }
		end
	elseif lkw then
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
		pruefung = pruefung, lkw = lkw, erlaubt = pruefung and 3 or (MAX_FEHLER - 1), wiederholung = art == "wiederholen",
		party = party,
	}
	if party then st.erlaubt = 99 end
	lektionen[p] = st

	-- Instructor in the passenger seat (a random crazy one, see Chaos.lua), examiner in the back (or in the middle of the truck cab)
	local lehrer = Chaos.neu(p, st)
	mitfahrer(modell, "Fahrlehrer", lehrer.name .. " (Instructor)", lehrer.haut, lehrer.oberteil, lehrer.hose, beifahrer, { uniform = true, frau = lehrer.frau == true })
	if pruefung then
		mitfahrer(modell, "Pruefer", "Mr. Becker (Examiner)", Color3.fromRGB(225, 185, 150), Color3.fromRGB(45, 50, 65), Color3.fromRGB(45, 50, 65), ruecksitz)
	end

	einsteigPrompt(p, sitz, lkw and "Driving school truck" or (party and "Party car" or "Driving school car"))
	if not pruefung and ruecksitz then
		-- friends can ride along on the back seat (not in the driving test – the examiner sits there)
		st.mitfahrPP = mitfahrPrompt(p, ruecksitz, modell)
	end
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
				if st.nr == 1 and not pruefung then funnel(p, 2) end
				fahrEvent:FireClient(p, { typ = "start", titel = party and "🏁 PARTY TEST" or lektion.titel, text = party and "Same route for everybody – first to park wins! Each mistake = +5 s. Watch out for chaos!" or lektion.intro, sprecher = pruefung and "Examiner" or lehrer.name, grenze = st.erlaubt, lehrer = lehrer.name })
				task.delay(1.5, function()
					if lektionen[p] == st then Chaos.sagen(st, "start") end
				end)
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
	elseif party then
		return { text = "Party test! Your car is waiting on the driving school parking lot – press E at the driver's door. GO GO GO!" }
	elseif pruefung then
		return { text = "Your driving test starts now! Your instructor and the examiner Mr. Becker are waiting in the car on the parking lot. Press E at the driver's door to get in." }
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
			Chaos.ende(st)
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
		-- "Ride along" only on the driving school parking lot: gone once the car has left it
		if st.mitfahrPP and st.startPos and (pos - st.startPos).Magnitude > 45 then
			st.mitfahrPP:Destroy()
			st.mitfahrPP = nil
		end

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
					Chaos.crashPunkte(p, 2)
					warnung(p, st, "You hit a pedestrian! (+3 mistakes)", 3)
					if lektionen[p] ~= st then break end
				end
			end
		end
		if lektionen[p] ~= st then continue end

		-- Crashing into another car of the NPC traffic costs 3 points
		if Verkehr.fahrzeuge and os.clock() - st.letzterUnfall > 5 and not Chaos.schonzeit(st) then
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
						Chaos.crashPunkte(p, 2)
						warnung(p, st, "You crashed into another vehicle! (+3 mistakes)", 3)
						break
					end
				end
			end
		end
		if lektionen[p] ~= st then continue end

		-- Chaos: instructor chatter and random events (cows, ducks, banana, UFO) – never touches the car physics
		Chaos.tick(p, st, pos, tempo, vorneZ, hintenZ, halbB)

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
				Chaos.reaktion(p, st, "lob")
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
local service = workspace.Karte:FindFirstChild("Service") -- (WaitForChild blocked the start for 10 s on maps without it)
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
		funnel(p, 9)
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
	funnel(p, 8)
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
	local modell, sitz, beifahrerSitz, chassis = Auto.bauenPrivat(bester, typ, farbe, kennzeichen)
	modell.Name = "Auto_" .. p.Name
	modell.Parent = workspace
	local a = { model = modell, sitz = sitz, chassis = chassis, blinkTeile = blinkTeileSuchen(modell), typ = typ, letztePos = chassis.Position }
	Pflege.anwenden(modell, typ, Pflege.daten(d, typ))
	privatAutos[p] = a
	einsteigPrompt(p, sitz, Auto.MODELLE[typ].name)
	if beifahrerSitz then mitfahrPrompt(p, beifahrerSitz, modell) end
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
			funnel(p, 6)
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
	elseif was == "bananeWerfen" then
		return Chaos.bananeWerfen(p)
	elseif was == "hupen" then
		return Chaos.hupen(p)
	elseif was == "partyBeitreten" then
		return Party.beitreten(p)
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

	elseif was == "fahrstundeWiederholen" then
		return lektionStarten(p, "wiederholen", eingabe)

	elseif was == "ersteFahrt" then
		-- brand-new player pressed PLAY: sign up and go straight into the first (short) lesson
		if d.angemeldet or d.fahrstunden > 0 or d.fuehrerschein or lektionen[p] then
			return { fehler = "not new" }
		end
		d.angemeldet = true
		geaendert(p)
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
		if befehl == "chaos" then
			-- start one chaos event in the running lesson (e.g. { befehl = "chaos", art = "banane" })
			local st = lektionen[p]
			if not st or not st.chaos then return { fehler = "Start a lesson first." } end
			local alt = st.chaos.event
			if alt then
				if alt.modell then alt.modell:Destroy() end
				st.chaos.event = nil
			end
			local art = type(eingabe.art) == "string" and Chaos.EVENTS[eingabe.art] and eingabe.art or nil
			local e = Chaos.eventStarten(p, st, art)
			return e and { text = "Chaos event: " .. tostring(e.art) } or { fehler = "Could not start (drive a bit faster / on a road)." }
		elseif befehl == "theorie" then
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
			if lektionen[p] then lektionBeenden(p, false, "Lesson cancelled (test menu).") end
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
Shop.starten({ daten = daten, geldGeben = geldGeben, fahrEvent = fahrEvent, geaendert = geaendert, speichernSofort = speichern, Auto = Auto, Pflege = Pflege, Chaos = Chaos })
Chaos.starten({ fahrEvent = fahrEvent, geldGeben = geldGeben, lektionen = lektionen, jobs = jobs, privatAutos = privatAutos,
	daten = daten, geaendert = geaendert, Shop = Shop, Missionen = Missionen, Hupen = Hupen })
Party.starten({ fahrEvent = fahrEvent, geldGeben = geldGeben, xpGeben = xpGeben, Chaos = Chaos,
	beschaeftigt = function(p) return lektionen[p] ~= nil or jobs[p] ~= nil end,
	zufallsRoute = function() return LEKTIONEN.PRUEFUNGEN[math.random(#LEKTIONEN.PRUEFUNGEN)] end,
	lektionStarten = function(p, art, nr, party) return lektionStarten(p, art, nr, party) end,
	lektionAbbrechen = function(p, text) if lektionen[p] then lektionBeenden(p, false, text) end end,
})
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
