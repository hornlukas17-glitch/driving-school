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
