-- Driving School v43 -> v44 (Chaos überall, Spaß-Shop, Fixes). In die Studio-Befehlszeile (Spiel gestoppt), Enter.
local function ck(x) local h = 0 for i = 1, #x do h = (h * 31 + string.byte(x, i)) % 4294967296 end return h end
local erg = {}
local function schritt(name, f)
	local ok, fehler = pcall(f)
	table.insert(erg, (ok and "OK     " or "FEHLER ") .. name .. (ok and "" or (": " .. tostring(fehler))))
end
schritt("Server", function()
local function ersetze(src, alt, neu)
	local a, b = string.find(src, alt, 1, true)
	assert(a, "nicht gefunden: " .. alt:sub(1, 60))
	assert(not string.find(src, alt, b + 1, true), "mehrfach: " .. alt:sub(1, 60))
	return src:sub(1, a - 1) .. neu .. src:sub(b + 1)
end
local s = game.ServerScriptService.FuehrerscheinServer
local src = s.Source
if ck(src) == 2308566906 then return end -- schon v44
assert(#src == 132773, "Ausgangsstand passt nicht: " .. #src)
src = ersetze(src, [===[
local TAXI_MITTE = Vector3.new(374, 0, -50)
local service = workspace.Karte:WaitForChild("Service", 10)
local servicestation = service and service:FindFirstChild("Servicestation")
]===], [===[
local TAXI_MITTE = Vector3.new(374, 0, -50)
local service = workspace.Karte:FindFirstChild("Service") -- (WaitForChild blocked the start for 10 s on maps without it)
local servicestation = service and service:FindFirstChild("Servicestation")
]===])
src = ersetze(src, [===[
		return Shop.status(p)
	elseif was == "belohnungen" then
]===], [===[
		return Shop.status(p)
	elseif was == "bananeWerfen" then
		return Chaos.bananeWerfen(p)
	elseif was == "belohnungen" then
]===])
src = ersetze(src, [===[
Missionen.starten({ daten = daten, geldGeben = geldGeben, xpGeben = xpGeben, fahrEvent = fahrEvent })
Shop.starten({ daten = daten, geldGeben = geldGeben, fahrEvent = fahrEvent, geaendert = geaendert, speichernSofort = speichern, Auto = Auto, Pflege = Pflege })
Chaos.starten({ fahrEvent = fahrEvent, geldGeben = geldGeben, lektionen = lektionen })
Belohnungen.starten({ daten = daten, geldGeben = geldGeben, xpGeben = xpGeben, fahrEvent = fahrEvent, geaendert = geaendert, Shop = Shop })
]===], [===[
Missionen.starten({ daten = daten, geldGeben = geldGeben, xpGeben = xpGeben, fahrEvent = fahrEvent })
Shop.starten({ daten = daten, geldGeben = geldGeben, fahrEvent = fahrEvent, geaendert = geaendert, speichernSofort = speichern, Auto = Auto, Pflege = Pflege, Chaos = Chaos })
Chaos.starten({ fahrEvent = fahrEvent, geldGeben = geldGeben, lektionen = lektionen, jobs = jobs, privatAutos = privatAutos,
	daten = daten, geaendert = geaendert, Shop = Shop, Missionen = Missionen })
Belohnungen.starten({ daten = daten, geldGeben = geldGeben, xpGeben = xpGeben, fahrEvent = fahrEvent, geaendert = geaendert, Shop = Shop })
]===])
assert(#src == 133031, "Ergebnis-Länge falsch: " .. #src)
s.Source = src
assert(ck(src) == 2308566906, "Prüfsumme falsch")
end)
schritt("Chaos", function()
local function ersetze(src, alt, neu)
	local a, b = string.find(src, alt, 1, true)
	assert(a, "nicht gefunden: " .. alt:sub(1, 60))
	assert(not string.find(src, alt, b + 1, true), "mehrfach: " .. alt:sub(1, 60))
	return src:sub(1, a - 1) .. neu .. src:sub(b + 1)
end
local s = game.ServerScriptService.FuehrerscheinServer.Chaos
local src = s.Source
if ck(src) == 907086320 then return end -- schon v44
assert(#src == 37484, "Ausgangsstand passt nicht: " .. #src)
src = ersetze(src, [===[
local RunService = game:GetService("RunService")

]===], [===[
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

]===])
src = ersetze(src, [===[

local zuletztLehrer = {} -- player -> last persona id (so you get a different one next time)
]===], [===[

-- chaos statistics for achievements (saved in the player data, field "chaos" – new field, default empty)
local function statistik(p, feld, schluessel)
	local d = ctx and ctx.daten and ctx.daten[p]
	if not d then return end
	d.chaos = d.chaos or {}
	local c = d.chaos
	if schluessel then
		c[feld] = c[feld] or {}
		c[feld][schluessel] = true
	else
		c[feld] = (c[feld] or 0) + 1
	end
	if ctx.geaendert then ctx.geaendert(p) end
end
Chaos.statistik = statistik
local function mission(p, id)
	if ctx and ctx.Missionen then ctx.Missionen.fortschritt(p, id, 1) end
end

local zuletztLehrer = {} -- player -> last persona id (so you get a different one next time)
]===])
src = ersetze(src, [===[
	if not c then return nil end
	local zeile = text or (c.lehrer[art] and zufall(c.lehrer[art]))
	if not zeile then return nil end
]===], [===[
	if not c then return nil end
	local zeile = text or (art and c.lehrer[art] and zufall(c.lehrer[art]))
	if not zeile then return nil end
]===])
src = ersetze(src, [===[
function Chaos.neu(p, st)
	st.chaos = {
]===], [===[
function Chaos.neu(p, st)
	local l = Chaos.lehrerWaehlen(p)
	statistik(p, "lehrer", l.id)
	st.chaos = {
]===])
src = ersetze(src, [===[
	st.chaos = {
		lehrer = Chaos.lehrerWaehlen(p),
		naechstesEvent = nil,     -- set when the first gate is sent
]===], [===[
	st.chaos = {
		lehrer = l,
		naechstesEvent = nil,     -- set when the first gate is sent
]===])
src = ersetze(src, [===[
	art = art or wuerfeln(st)
	local ev = EVENTS[art]
]===], [===[
	art = art or wuerfeln(st)
	if art == "gag" and not c.lehrer.gag then art = "banane" end -- no instructor in your own car
	local ev = EVENTS[art]
]===])
src = ersetze(src, [===[
	c.anzahl += 1
	if ev.ohneObjekt then
]===], [===[
	c.anzahl += 1
	statistik(p, "arten", art)
	if ev.ohneObjekt then
]===])
src = ersetze(src, [===[
	c.event = nil
	c.naechstesEvent = os.clock() + math.random(30, 45)
	if e.modell then
]===], [===[
	c.event = nil
	c.naechstesEvent = os.clock() + (c.frei and math.random(60, 90) or math.random(30, 45))
	if e.modell then
]===])
src = ersetze(src, [===[
		ctx.geldGeben(p, BONUS, texte[e.art] or "Dodged!")
		banner(p, "✨ NICE DODGE!", texte[e.art] or "Dodged!", "gruen")
]===], [===[
		ctx.geldGeben(p, BONUS, texte[e.art] or "Dodged!")
		statistik(p, "ausgewichen")
		mission(p, "ausweichen")
		banner(p, "✨ NICE DODGE!", texte[e.art] or "Dodged!", "gruen")
]===])
src = ersetze(src, [===[
						c.schonzeit = os.clock() + 4 -- a crash while spinning on the banana is not your fault
					end
]===], [===[
						c.schonzeit = os.clock() + 4 -- a crash while spinning on the banana is not your fault
						statistik(p, "banane")
						mission(p, "banane")
					end
]===])
src = ersetze(src, [===[
			ctx.geldGeben(p, BONUS_UFO, "Alien bonus!")
			banner(p, "👽 BEAMED UP!", "The aliens are taking you for a ride!", "gruen", { entfuehren = true })
]===], [===[
			ctx.geldGeben(p, BONUS_UFO, "Alien bonus!")
			statistik(p, "ufo")
			banner(p, "👽 BEAMED UP!", "The aliens are taking you for a ride!", "gruen", { entfuehren = true })
]===])
src = ersetze(src, [===[
	-- instructor chatter
	if jetzt > c.naechstesGerede then
		c.naechstesGerede = jetzt + math.random(16, 26)
]===], [===[
	-- instructor chatter
	if c.lehrer.leerlauf and jetzt > c.naechstesGerede then
		c.naechstesGerede = jetzt + math.random(16, 26)
]===])
src = ersetze(src, [===[
	if c.naechstesEvent and jetzt > c.naechstesEvent and tempo > 10 and not st.parkPhase then
		local wp = st.lektion.punkte[st.index]
		if wp and not wp.parken then
			Chaos.eventStarten(p, st)
]===], [===[
	if c.naechstesEvent and jetzt > c.naechstesEvent and tempo > 10 and not st.parkPhase then
		local wp = st.lektion and st.lektion.punkte[st.index]
		if not st.lektion or (wp and not wp.parken) then
			Chaos.eventStarten(p, st)
]===])
src = ersetze(src, [===[

function Chaos.starten(k)
]===], [===[

-- ---------------------------------------------------------------
-- Every car with a driver (lessons, jobs, own cars)
-- ---------------------------------------------------------------
local function fahrzeuge()
	local liste = {}
	local function dazu(chassis, sitz, st)
		if chassis and chassis.Parent and sitz and sitz.Occupant then
			local f = Players:GetPlayerFromCharacter(sitz.Occupant.Parent)
			if f then table.insert(liste, { p = f, chassis = chassis, st = st }) end
		end
	end
	for _, st in ctx.lektionen do dazu(st.chassis, st.sitz, st) end
	for _, j in ctx.jobs or {} do dazu(j.chassis, j.sitz, j) end
	for _, a in ctx.privatAutos or {} do dazu(a.chassis, a.sitz, a) end
	return liste
end
Chaos.fahrzeuge = fahrzeuge

local function flach(v)
	local f = Vector3.new(v.X, 0, v.Z)
	return f.Magnitude > 0.01 and f.Unit or Vector3.new(0, 0, -1)
end

local function anAlle(titel, text, farbe)
	for _, sp in Players:GetPlayers() do
		ctx.fahrEvent:FireClient(sp, { typ = "chaos", titel = titel, text = text, farbe = farbe })
	end
end

-- ---------------------------------------------------------------
-- Chaos in your own car (after the license): an event every 1 – 1.5 minutes, no instructor
-- ---------------------------------------------------------------
local function freiTick()
	for p, a in ctx.privatAutos or {} do
		local fahrer = a.sitz and a.sitz.Occupant
		local wer = fahrer and Players:GetPlayerFromCharacter(fahrer.Parent)
		if wer == p and a.chassis and a.chassis.Parent then
			if not a.chaos then
				a.chaos = { lehrer = {}, frei = true, naechstesEvent = os.clock() + math.random(40, 60),
					naechstesGerede = math.huge, zuletztGesagt = 0, anzahl = 0 }
			end
			local d = ctx.daten[p]
			if not (d and d.einstellungen and d.einstellungen.chaosAus) then
				Chaos.tick(p, a, a.chassis.Position, a.chassis.AssemblyLinearVelocity.Magnitude, -8.8, 8.8, 4.2)
			end
		elseif a.chaos and a.chaos.event then
			Chaos.ende(a) -- left the car: the event disappears
			a.chaos.naechstesEvent = os.clock() + 60
		end
	end
end
Chaos.freiTick = freiTick

-- ---------------------------------------------------------------
-- Banana peels thrown by players (Banana Launcher pass, Banana Rain product)
-- ---------------------------------------------------------------
local bananenOrdner = Instance.new("Folder")
bananenOrdner.Name = "Bananen"
bananenOrdner.Parent = ordner
local schalen = {}       -- { m, pos, besitzer, zeit }
local letzterWurf = {}
Chaos.WURF_PAUSE = 5     -- seconds between two throws
Chaos.SCHALEN_MAX = 5    -- peels per player on the map at the same time
Chaos.schalen = schalen

local function schaleLegen(besitzer, pos, ohneLimit, ersatzY)
	local y = Chaos.bodenHoehe(pos) or ersatzY
	if not y then return nil end
	local b = banane()
	b.Name = "Wurfbanane"
	b:PivotTo(CFrame.new(pos.X, y, pos.Z) * CFrame.Angles(0, math.random() * 6.28, 0))
	b.Parent = bananenOrdner
	local s = { m = b, pos = Vector3.new(pos.X, y, pos.Z), besitzer = besitzer, zeit = os.clock() }
	table.insert(schalen, s)
	if not ohneLimit then
		local meine = {}
		for _, x in schalen do if x.besitzer == besitzer then table.insert(meine, x) end end
		while #meine > Chaos.SCHALEN_MAX do
			local alt = table.remove(meine, 1)
			alt.m:Destroy()
			table.remove(schalen, table.find(schalen, alt))
		end
	end
	return s
end
Chaos.schaleLegen = schaleLegen

function Chaos.bananeWerfen(p)
	if not (ctx.Shop and ctx.Shop.hat(p, "banane")) then
		return { fehler = "🍌 Get the Banana Launcher in the 🛒 Shop to drop banana peels behind your car!" }
	end
	local rest = Chaos.WURF_PAUSE - (os.clock() - (letzterWurf[p] or -99))
	if rest > 0 then return { fehler = ("🍌 Reloading… %d s"):format(math.ceil(rest)) } end
	local f
	for _, x in fahrzeuge() do if x.p == p then f = x end end
	if not f then return { fehler = "Get in a car first, then drop banana peels behind you!" } end
	local cf = f.chassis.CFrame
	if not schaleLegen(p, cf.Position - flach(cf.LookVector) * 12, false, cf.Position.Y - 2) then return { fehler = "No road behind you." } end
	letzterWurf[p] = os.clock()
	return { text = "🍌 Banana peel dropped! Who will slip on it?" }
end

local function schalenTick()
	if #schalen == 0 then return end
	local jetzt = os.clock()
	local liste = fahrzeuge()
	for i = #schalen, 1, -1 do
		local s = schalen[i]
		local weg = jetzt - s.zeit > 45 or not s.m.Parent
		if not weg then
			for _, f in liste do
				local pos = f.chassis.Position
				local nah = Vector3.new(pos.X - s.pos.X, 0, pos.Z - s.pos.Z).Magnitude
				local eigeneFrisch = f.p == s.besitzer and jetzt - s.zeit < 2.5
				if nah < 4.5 and math.abs(pos.Y - s.pos.Y) < 8 and not eigeneFrisch then
					weg = true
					local selbst = f.p == s.besitzer or not s.besitzer.Parent
					ctx.fahrEvent:FireClient(f.p, { typ = "chaos", titel = "🍌 SLIIIP!", farbe = "rot", wackeln = true,
						text = selbst and "Whoops, a banana peel!" or (s.besitzer.DisplayName .. " got you with a banana!"),
						rutschen = math.random() < 0.5 and -1 or 1 })
					if f.st and f.st.chaos then f.st.chaos.schonzeit = jetzt + 4 end
					statistik(f.p, "banane")
					mission(f.p, "banane")
					if not selbst then
						statistik(s.besitzer, "treffer")
						ctx.fahrEvent:FireClient(s.besitzer, { typ = "chaos", titel = "🍌 GOTCHA!", farbe = "gruen",
							text = f.p.DisplayName .. " slipped on your banana!" })
					end
					break
				end
			end
		end
		if weg then
			s.m:Destroy()
			table.remove(schalen, i)
		end
	end
end
Chaos.schalenTick = schalenTick

-- ---------------------------------------------------------------
-- Server-wide fun (developer products)
-- ---------------------------------------------------------------
-- 👽 Alien Invasion: a UFO beams up every driver on the server
function Chaos.alleEntfuehren(kaeufer)
	anAlle("👽 ALIEN INVASION!", kaeufer.DisplayName .. " called the aliens – every driver gets beamed up!", "lila")
	for _, f in fahrzeuge() do
		task.spawn(function()
			local u = ufo()
			u.Parent = ordner
			local y0 = Chaos.bodenHoehe(f.chassis.Position) or (f.chassis.Position.Y - 2)
			ctx.fahrEvent:FireClient(f.p, { typ = "chaos", titel = "👽 BEAMED UP!", text = "Thanks, " .. kaeufer.DisplayName .. "! Enjoy the ride!",
				farbe = "gruen", entfuehren = true })
			if f.st and f.st.chaos then f.st.chaos.schonzeit = os.clock() + 8 end
			statistik(f.p, "ufo")
			local start = os.clock()
			while os.clock() - start < 8.5 and f.chassis.Parent do
				local t = os.clock() - start
				local pos = f.chassis.Position
				local hoch = math.max(pos.Y + 12, y0 + 28)
				if t > 6.5 then hoch += (t - 6.5) ^ 2 * 25 end -- flies away
				u:PivotTo(CFrame.new(pos.X, hoch, pos.Z) * CFrame.Angles(0, t * 1.5, 0))
				task.wait()
			end
			u:Destroy()
		end)
	end
end

-- 🍌 Banana Rain: banana peels drop in front of every driver
function Chaos.bananenRegen(kaeufer)
	anAlle("🍌 BANANA RAIN!", kaeufer.DisplayName .. " made it rain banana peels – drive carefully!", "gelb")
	for _, f in fahrzeuge() do
		local cf = f.chassis.CFrame
		local vor = flach(cf.LookVector)
		local rechts = Vector3.new(-vor.Z, 0, vor.X)
		for k = 1, 4 do
			local pos = cf.Position + vor * (30 + k * 16) + rechts * ((math.random() - 0.5) * 7)
			local s = schaleLegen(kaeufer, pos, true, cf.Position.Y - 2)
			if s then
				-- falls down from the sky
				local ziel = s.m:GetPivot()
				s.m:PivotTo(ziel + Vector3.new(0, 25, 0))
				task.spawn(function()
					for i = 1, 20 do
						if not s.m.Parent then return end
						s.m:PivotTo(ziel + Vector3.new(0, 25 * (1 - i / 20) ^ 2, 0))
						task.wait(0.03)
					end
				end)
			end
		end
	end
end

function Chaos.starten(k)
]===])
src = ersetze(src, [===[
	RunService.Heartbeat:Connect(function()
		for _, st in ctx.lektionen do
			local e = st.chaos and st.chaos.event
			if e and e.modell and e.modell.Parent then
				Chaos.bewegen(e, os.clock() - e.start)
			end
]===], [===[
	RunService.Heartbeat:Connect(function()
		for _, liste in { ctx.lektionen, ctx.privatAutos or {} } do
			for _, st in liste do
				local e = st.chaos and st.chaos.event
				if e and e.modell and e.modell.Parent then
					Chaos.bewegen(e, os.clock() - e.start)
				end
			end
]===])
src = ersetze(src, [===[
				end
			end
		end
	end)
]===], [===[
				end
			end
		end
	end)
	-- own cars and thrown banana peels: checked 10 times per second
	task.spawn(function()
		while true do
			task.wait(0.1)
			local ok, fehler = pcall(freiTick)
			if not ok then warn("Chaos (own car): " .. tostring(fehler)) end
			ok, fehler = pcall(schalenTick)
			if not ok then warn("Chaos (bananas): " .. tostring(fehler)) end
		end
	end)
]===])
assert(#src == 46554, "Ergebnis-Länge falsch: " .. #src)
s.Source = src
assert(ck(src) == 907086320, "Prüfsumme falsch")
end)
schritt("Shop", function()
local function ersetze(src, alt, neu)
	local a, b = string.find(src, alt, 1, true)
	assert(a, "nicht gefunden: " .. alt:sub(1, 60))
	assert(not string.find(src, alt, b + 1, true), "mehrfach: " .. alt:sub(1, 60))
	return src:sub(1, a - 1) .. neu .. src:sub(b + 1)
end
local s = game.ServerScriptService.FuehrerscheinServer.Shop
local src = s.Source
if ck(src) == 722858140 then return end -- schon v44
assert(#src == 11368, "Ausgangsstand passt nicht: " .. #src)
src = ersetze(src, [===[
		text = "6 exclusive paint colors for all your cars." },
}
]===], [===[
		text = "6 exclusive paint colors for all your cars." },
	{ key = "banane", id = 0, preis = 149, icon = "🍌", name = "Banana Launcher",
		text = "Press B (or the 🍌 button) while driving to drop banana peels behind your car. Watch your friends spin out!" },
}
]===])
src = ersetze(src, [===[
	{ key = "boost", id = 0, preis = 79, name = "2x Coins – 30 min", boost = 30, text = "Double coins for 30 minutes of play." },
	{ key = "coins1", id = 0, preis = 49, name = "2,500 coins", geld = 2500 },
]===], [===[
	{ key = "boost", id = 0, preis = 79, name = "2x Coins – 30 min", boost = 30, text = "Double coins for 30 minutes of play." },
	{ key = "ufo", id = 0, preis = 49, name = "👽 Alien Invasion", chaos = "ufo", tag = "FUN",
		text = "A UFO beams up EVERY driver on the server – with your name on it!" },
	{ key = "bananen", id = 0, preis = 29, name = "🍌 Banana Rain", chaos = "bananen", tag = "FUN",
		text = "Banana peels rain down in front of every driver on the server!" },
	{ key = "coins1", id = 0, preis = 49, name = "2,500 coins", geld = 2500 },
]===])
src = ersetze(src, [===[
	p:SetAttribute("VIP", Shop.hat(p, "vip") or nil)
	p:SetAttribute("BoostBis", ctx.daten[p] and ctx.daten[p].boostBis or nil)
]===], [===[
	p:SetAttribute("VIP", Shop.hat(p, "vip") or nil)
	p:SetAttribute("BananenWerfer", Shop.hat(p, "banane") or nil)
	p:SetAttribute("BoostBis", ctx.daten[p] and ctx.daten[p].boostBis or nil)
]===])
src = ersetze(src, [===[
		if not (pr.einmal and d.starterGekauft) then
			table.insert(produkte, { key = pr.key, id = pr.id, name = pr.name, text = pr.text, tag = pr.tag, geld = pr.geld,
				preis = preise[pr.id] or pr.preis, bereit = pr.id ~= 0, einmal = pr.einmal })
]===], [===[
		if not (pr.einmal and d.starterGekauft) then
			table.insert(produkte, { key = pr.key, id = pr.id, name = pr.name, text = pr.text, tag = pr.tag, geld = pr.geld, spass = pr.chaos ~= nil,
				preis = preise[pr.id] or pr.preis, bereit = pr.id ~= 0, einmal = pr.einmal })
]===])
src = ersetze(src, [===[
	if pr.einmal then d.starterGekauft = true end
	attribute(p)
]===], [===[
	if pr.einmal then d.starterGekauft = true end
	if pr.chaos and ctx.Chaos then
		if pr.chaos == "ufo" then ctx.Chaos.alleEntfuehren(p) else ctx.Chaos.bananenRegen(p) end
	end
	attribute(p)
]===])
assert(#src == 12141, "Ergebnis-Länge falsch: " .. #src)
s.Source = src
assert(ck(src) == 722858140, "Prüfsumme falsch")
end)
schritt("Missionen", function()
local function ersetze(src, alt, neu)
	local a, b = string.find(src, alt, 1, true)
	assert(a, "nicht gefunden: " .. alt:sub(1, 60))
	assert(not string.find(src, alt, b + 1, true), "mehrfach: " .. alt:sub(1, 60))
	return src:sub(1, a - 1) .. neu .. src:sub(b + 1)
end
local s = game.ServerScriptService.FuehrerscheinServer.Missionen
local src = s.Source
if ck(src) == 2074962222 then return end -- schon v44
assert(#src == 6846, "Ausgangsstand passt nicht: " .. #src)
src = ersetze(src, [===[
	{ id = "taxi", text = "Drive %d taxi passengers", ziele = { 2, 3, 4 }, geld = 250, xp = 90 },
}
]===], [===[
	{ id = "taxi", text = "Drive %d taxi passengers", ziele = { 2, 3, 4 }, geld = 250, xp = 90 },
	{ id = "ausweichen", text = "Dodge %d chaos events (cows, ducks, bananas …)", ziele = { 2, 3, 5 }, geld = 250, xp = 90 },
	{ id = "banane", text = "Spin out on a banana peel", ziele = { 1 }, geld = 150, xp = 50 },
}
]===])
src = ersetze(src, [===[
local function aktuell(p)
	local d = ctx.daten[p]
	if not d then return nil end
]===], [===[
local function aktuell(p)
	local d = ctx and ctx.daten[p] -- nil while the server is still starting up
	if not d then return nil end
	d = ctx.daten[p]
	if not d then return nil end
]===])
src = ersetze(src, [===[
	local m = aktuell(p)
	local liste = {}
]===], [===[
	local m = aktuell(p)
	if not m then return { fehler = "Still loading – try again in a moment.", liste = {} } end
	local liste = {}
]===])
assert(#src == 7258, "Ergebnis-Länge falsch: " .. #src)
s.Source = src
assert(ck(src) == 2074962222, "Prüfsumme falsch")
end)
schritt("Belohnungen", function()
local function ersetze(src, alt, neu)
	local a, b = string.find(src, alt, 1, true)
	assert(a, "nicht gefunden: " .. alt:sub(1, 60))
	assert(not string.find(src, alt, b + 1, true), "mehrfach: " .. alt:sub(1, 60))
	return src:sub(1, a - 1) .. neu .. src:sub(b + 1)
end
local s = game.ServerScriptService.FuehrerscheinServer.Belohnungen
local src = s.Source
if ck(src) == 1667856021 then return end -- schon v44
assert(#src == 13338, "Ausgangsstand passt nicht: " .. #src)
src = ersetze(src, [===[
		wert = function(d) return math.floor((d.freundeSek or 0) / 60) end, stufen = { { 10, 500, 100 }, { 60, 2000, 300 }, { 300, 6000, 800 } }, badge = 0 },
	{ id = "villa", kategorie = "collection", icon = "🏡", name = "Home owner", text = "Buy a villa",
]===], [===[
		wert = function(d) return math.floor((d.freundeSek or 0) / 60) end, stufen = { { 10, 500, 100 }, { 60, 2000, 300 }, { 300, 6000, 800 } }, badge = 0 },
	{ id = "lehrer", kategorie = "chaos", icon = "🎭", name = "Crazy crew", text = "Drive with different crazy instructors",
		wert = function(d) local n = 0 for _ in (d.chaos and d.chaos.lehrer) or {} do n += 1 end return n end, stufen = { { 3, 300, 60 }, { 5, 1000, 200 } }, badge = 0 },
	{ id = "chaosArten", kategorie = "chaos", icon = "🌪", name = "Chaos collector", text = "Experience different chaos events",
		wert = function(d) local n = 0 for _ in (d.chaos and d.chaos.arten) or {} do n += 1 end return n end, stufen = { { 4, 400, 80 }, { 8, 1500, 250 } }, badge = 0 },
	{ id = "ausweichen", kategorie = "chaos", icon = "🦆", name = "Dodge master", text = "Dodge chaos events",
		wert = function(d) return (d.chaos and d.chaos.ausgewichen) or 0 end, stufen = { { 5, 300, 60 }, { 25, 1200, 200 }, { 100, 5000, 600 } }, badge = 0 },
	{ id = "ufo", kategorie = "chaos", icon = "👽", name = "Frequent flyer", text = "Get beamed up by a UFO",
		wert = function(d) return (d.chaos and d.chaos.ufo) or 0 end, stufen = { { 1, 300, 60 }, { 10, 1500, 250 } }, badge = 0 },
	{ id = "bananen", kategorie = "chaos", icon = "🍌", name = "Banana sniper", text = "Other players slip on your banana peels",
		wert = function(d) return (d.chaos and d.chaos.treffer) or 0 end, stufen = { { 1, 200, 50 }, { 10, 1000, 200 }, { 50, 4000, 500 } }, badge = 0 },
	{ id = "villa", kategorie = "collection", icon = "🏡", name = "Home owner", text = "Buy a villa",
]===])
assert(#src == 14693, "Ergebnis-Länge falsch: " .. #src)
s.Source = src
assert(ck(src) == 1667856021, "Prüfsumme falsch")
end)
schritt("Client", function()
local function ersetze(src, alt, neu)
	local a, b = string.find(src, alt, 1, true)
	assert(a, "nicht gefunden: " .. alt:sub(1, 60))
	assert(not string.find(src, alt, b + 1, true), "mehrfach: " .. alt:sub(1, 60))
	return src:sub(1, a - 1) .. neu .. src:sub(b + 1)
end
local s = game.StarterPlayer.StarterPlayerScripts.FuehrerscheinClient
local src = s.Source
if ck(src) == 1627187900 then return end -- schon v44
assert(#src == 168043, "Ausgangsstand passt nicht: " .. #src)
src = ersetze(src, [===[
local spieler = Players.LocalPlayer
print("[Driving School] client v43 loaded")
local ordner = RS:WaitForChild("Fuehrerschein")
]===], [===[
local spieler = Players.LocalPlayer
print("[Driving School] client v44 loaded")
local ordner = RS:WaitForChild("Fuehrerschein")
]===])
src = ersetze(src, [===[
_G.ChaosBanner = chaosBanner

]===], [===[
_G.ChaosBanner = chaosBanner

-- 🍌 Banana Launcher (game pass): B or the banana button drops a peel behind your car
do
	local UISB = game:GetService("UserInputService")
	local knopfGui = Instance.new("ScreenGui")
	knopfGui.Name = "BananenKnopf"
	knopfGui.ResetOnSpawn = false
	knopfGui.Parent = spieler.PlayerGui
	local knopf = Instance.new("TextButton")
	knopf.AnchorPoint = Vector2.new(1, 0.5)
	knopf.Position = UDim2.new(1, -16, 0.42, 0)
	knopf.Size = UDim2.fromOffset(64, 64)
	knopf.BackgroundColor3 = Color3.fromRGB(255, 205, 40)
	knopf.Text = "🍌"
	knopf.TextScaled = true
	knopf.Visible = false
	knopf.Parent = knopfGui
	Instance.new("UICorner", knopf).CornerRadius = UDim.new(1, 0)
	local taste = Instance.new("TextLabel")
	taste.AnchorPoint = Vector2.new(0.5, 0)
	taste.Position = UDim2.new(0.5, 0, 1, 2)
	taste.Size = UDim2.fromOffset(64, 16)
	taste.BackgroundTransparency = 1
	taste.Font = Enum.Font.GothamBold
	taste.TextSize = 12
	taste.TextColor3 = Color3.new(1, 1, 1)
	taste.TextStrokeTransparency = 0.3
	taste.Text = "B"
	taste.Parent = knopf
	local function werfen()
		local r = frage("bananeWerfen")
		if r and (r.fehler or r.text) then warnen(r.fehler or r.text, r.fehler and Color3.fromRGB(200, 140, 30) or GRUEN) end
	end
	knopf.Activated:Connect(werfen)
	local function imAuto()
		local hum = spieler.Character and spieler.Character:FindFirstChildOfClass("Humanoid")
		return hum and hum.SeatPart and hum.SeatPart:IsA("VehicleSeat")
	end
	UISB.InputBegan:Connect(function(eingabe, verarbeitet)
		if verarbeitet or eingabe.KeyCode ~= Enum.KeyCode.B then return end
		if imAuto() then werfen() end
	end)
	task.spawn(function()
		while true do
			knopf.Visible = imAuto() == true and spieler:GetAttribute("BananenWerfer") == true
			task.wait(0.5)
		end
	end)
end

]===])
src = ersetze(src, [===[
		end
		ueberschrift(liste, "🪙 COINS & BOOSTS", weiter())
]===], [===[
		end
		ueberschrift(liste, "🤪 CHAOS FUN – for the whole server", weiter())
		for _, pr in info.produkte do
			if pr.spass then
				local k = karte(liste, 72, Color3.fromRGB(70, 40, 95), weiter())
				label(k, pr.name .. (pr.tag and ("   <font color=\"#ffcf4a\" size=\"12\">" .. pr.tag .. "</font>") or ""), 16, nil, { 0, 14 }, { 0, 6 }, { 1, -170 }, { 0, 24 }, true)
				label(k, pr.text or "", 12, HELL, { 0, 14 }, { 0, 32 }, { 1, -170 }, { 0, 34 })
				taste(k, preisText(pr), GRUEN, { 1, -146 }, { 0.5, -18 }, { 0, 134 }, { 0, 36 }, function() kaufen("produkt", pr) end)
			end
		end
		ueberschrift(liste, "🪙 COINS & BOOSTS", weiter())
]===])
src = ersetze(src, [===[
		for _, pr in info.produkte do
			if not pr.einmal then
				local k = karte(liste, 56, nil, weiter())
]===], [===[
		for _, pr in info.produkte do
			if not pr.einmal and not pr.spass then
				local k = karte(liste, 56, nil, weiter())
]===])
src = ersetze(src, [===[
				local k = karte(liste, 56, nil, weiter())
				label(k, (pr.geld and "🪙 " or "⚡ ") .. pr.name .. (pr.tag and ("   <font color=\"#ffcf4a\" size=\"12\">" .. pr.tag .. "</font>") or ""), 16, nil, { 0, 14 }, { 0, 0 }, { 1, -170 }, { 1, 0 }, true)
				taste(k, preisText(pr), GRUEN, { 1, -146 }, { 0.5, -18 }, { 0, 134 }, { 0, 36 }, function() kaufen("produkt", pr) end)
]===], [===[
				local k = karte(liste, 56, nil, weiter())
				label(k, (pr.spass and "" or pr.geld and "🪙 " or "⚡ ") .. pr.name .. (pr.tag and ("   <font color=\"#ffcf4a\" size=\"12\">" .. pr.tag .. "</font>") or ""), 16, nil, { 0, 14 }, { 0, 0 }, { 1, -170 }, { 1, 0 }, true)
				taste(k, preisText(pr), GRUEN, { 1, -146 }, { 0.5, -18 }, { 0, 134 }, { 0, 36 }, function() kaufen("produkt", pr) end)
]===])
src = ersetze(src, [===[
do
	print("[Driving School] start screen v43 loading")
	local menue = Instance.new("ScreenGui")
]===], [===[
do
	print("[Driving School] start screen v44 loading")
	local menue = Instance.new("ScreenGui")
]===])
assert(#src == 170425, "Ergebnis-Länge falsch: " .. #src)
s.Source = src
assert(ck(src) == 1627187900, "Prüfsumme falsch")
end)
print(table.concat(erg, "\n"))
