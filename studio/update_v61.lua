-- v60 -> v61: Zonen in der Parkplatzmitte, KI-Beifahrer, Bot-Gegner, VIP-Name, Geisterfahrer + Fahrlehrer-Streiche.
-- Im EDIT-Modus in die Befehlszeile oder per MCP. Bricht ab (assert), wenn ein Ausgangsstand nicht passt.
local log = {}
game:GetService("ChangeHistoryService"):SetWaypoint("Vor v61")
do
local function ersetze(src, alt, neu)
	local a, b = string.find(src, alt, 1, true)
	assert(a, "nicht gefunden: " .. alt:sub(1, 60))
	assert(not string.find(src, alt, b + 1, true), "mehrfach: " .. alt:sub(1, 60))
	return src:sub(1, a - 1) .. neu .. src:sub(b + 1)
end
local s = game.ServerScriptService.FuehrerscheinServer.Zonen
local src = s.Source
assert(#src == 8148, "Ausgangsstand passt nicht: " .. #src)
src = ersetze(src, [===[
--   🙈 BLIND DRIVE – starts as soon as 2 players stand in it (who came first drives).
--   🏁 PARTY TEST  – from 2 players a countdown runs (full with 4 = starts right away).
-- The sign above each zone shows how many players are waiting.
]===], [===[
--   🙈 BLIND DRIVE – starts as soon as 2 players stand in it (who came first drives).
--   🏁 PARTY TEST  – from 1 player a countdown runs, bots fill free spots (full with 4 = starts right away).
--   v61: alone in the Blind Drive zone for 15 s -> AI co-pilot "Robo-Rita".
-- The sign above each zone shows how many players are waiting.
]===])
src = ersetze(src, [===[
Zonen.PARTY_VOLL = 3       -- seconds left when the party zone is full

]===], [===[
Zonen.PARTY_VOLL = 3       -- seconds left when the party zone is full
Zonen.KI_WARTEN = 15       -- v61: alone in the Blind Drive zone this long -> the AI co-pilot takes over

]===])
src = ersetze(src, [===[
	m.Parent = ordner
	return { model = m, pos = pos, status = zahl, info = info, drin = {}, sperre = {} }
end
]===], [===[
	m.Parent = ordner
	return { model = m, pos = pos, status = zahl, info = info, drin = {}, sperre = {}, seit = {} }
end
]===])
src = ersetze(src, [===[
	for i = #z.drin, 1, -1 do
		if not z.drin[i].Parent or not stehtDrin(z, z.drin[i]) then table.remove(z.drin, i) end
	end
]===], [===[
	for i = #z.drin, 1, -1 do
		if not z.drin[i].Parent or not stehtDrin(z, z.drin[i]) then z.seit[z.drin[i]] = nil table.remove(z.drin, i) end
	end
]===])
src = ersetze(src, [===[
			table.insert(z.drin, p)
			ctx.fahrEvent:FireClient(p, { typ = "hinweis", text = hinweis, farbe = "gruen" })
]===], [===[
			table.insert(z.drin, p)
			z.seit[p] = os.clock()
			ctx.fahrEvent:FireClient(p, { typ = "hinweis", text = hinweis, farbe = "gruen" })
]===])
src = ersetze(src, [===[
	if blind then
		aktualisieren(blind, "🙈 Blind Drive: waiting for a second player – bring a friend or wait here!")
		while #blind.drin >= 2 do
]===], [===[
	if blind then
		aktualisieren(blind, ("🙈 Blind Drive: waiting for a second player – or the AI co-pilot takes over in %d s!"):format(Zonen.KI_WARTEN))
		while #blind.drin >= 2 do
]===])
src = ersetze(src, [===[
		end
		if #blind.drin == 1 then
			setzen(blind, "1/2 PLAYERS", "Waiting for a partner…")
]===], [===[
		end
		-- v61: nobody else came -> drive with the AI co-pilot
		if #blind.drin == 1 and ctx.blindKI then
			local fahrer = blind.drin[1]
			local rest = math.ceil((blind.seit[fahrer] or os.clock()) + Zonen.KI_WARTEN - os.clock())
			if rest <= 0 then
				table.remove(blind.drin, 1)
				blind.seit[fahrer] = nil
				blind.gestartet = (blind.gestartet or 0) + 1
				task.spawn(function()
					local r = ctx.blindKI(fahrer)
					if r and r.fehler then
						blind.sperre[fahrer] = os.clock() + 6
						ctx.fahrEvent:FireClient(fahrer, { typ = "hinweis", text = r.fehler })
					elseif ctx.Beta then
						ctx.Beta.ereignis(fahrer, "Zone blind drive AI")
					end
				end)
			else
				setzen(blind, "1/2 PLAYERS", ("🤖 AI co-pilot in %d s"):format(rest))
			end
		elseif #blind.drin == 1 then
			setzen(blind, "1/2 PLAYERS", "Waiting for a partner…")
]===])
src = ersetze(src, [===[
	if party then
		aktualisieren(party, "🏁 Party test: the race starts when 2–4 players stand here!")
		local Party = ctx.Party
]===], [===[
	if party then
		aktualisieren(party, "🏁 Party test: race starts soon – bots fill the free spots!")
		local Party = ctx.Party
]===])
src = ersetze(src, [===[
		local n = #party.drin
		local mindest = Party.minimum()
		if rennen then
]===], [===[
		local n = #party.drin
		local mindest = 1 -- v61: free spots are filled with bots
		if rennen then
]===])
src = ersetze(src, [===[
			local rest = math.max(0, math.ceil(party.ende - jetzt))
			setzen(party, ("%d/%d PLAYERS"):format(math.min(n, Party.MAX), Party.MAX), ("Starts in %d s!"):format(rest))
			if jetzt >= party.ende then
]===], [===[
			local rest = math.max(0, math.ceil(party.ende - jetzt))
			setzen(party, ("%d/%d PLAYERS"):format(math.min(n, Party.MAX), Party.MAX), n < Party.MAX and ("Starts in %d s · 🤖 bots fill up"):format(rest) or ("Starts in %d s!"):format(rest))
			if jetzt >= party.ende then
]===])
src = ersetze(src, [===[
				party.gestartet = (party.gestartet or 0) + 1
				local r = Party.mitSpielern(liste)
				for _, sp in liste do
]===], [===[
				party.gestartet = (party.gestartet or 0) + 1
				local r = Party.mitSpielern(liste, Party.MAX - #liste)
				for _, sp in liste do
]===])
src = ersetze(src, [===[
	ordner.Parent = workspace
	-- left and right of the entrance, between the door and the first parking bays
	local function bodenBei(lokal)
]===], [===[
	ordner.Parent = workspace
	-- v61: in the middle of the parking lot (the lane between the two rows of bays)
	local function bodenBei(lokal)
]===])
src = ersetze(src, [===[
	end
	zonen[1] = zoneBauen(ordner, "BlindDrive", bodenBei(Vector3.new(-10, 0, -2)), "🙈 BLIND DRIVE", Color3.fromRGB(255, 210, 60))
	zonen[2] = zoneBauen(ordner, "PartyTest", bodenBei(Vector3.new(10, 0, -2)), "🏁 PARTY TEST", Color3.fromRGB(120, 220, 255))
	Zonen.tick()
]===], [===[
	end
	zonen[1] = zoneBauen(ordner, "BlindDrive", bodenBei(Vector3.new(-9, 0, 11)), "🙈 BLIND DRIVE", Color3.fromRGB(255, 210, 60))
	zonen[2] = zoneBauen(ordner, "PartyTest", bodenBei(Vector3.new(9, 0, 11)), "🏁 PARTY TEST", Color3.fromRGB(120, 220, 255))
	Zonen.tick()
]===])
assert(#src == 9328, "Ergebnis-Länge falsch: " .. #src)
s.Source = src
table.insert(log, s.Name .. ': ' .. #src)
end
do
local function ersetze(src, alt, neu)
	local a, b = string.find(src, alt, 1, true)
	assert(a, "nicht gefunden: " .. alt:sub(1, 60))
	assert(not string.find(src, alt, b + 1, true), "mehrfach: " .. alt:sub(1, 60))
	return src:sub(1, a - 1) .. neu .. src:sub(b + 1)
end
local s = game.ServerScriptService.FuehrerscheinServer.Party
local src = s.Source
assert(#src == 7760, "Ausgangsstand passt nicht: " .. #src)
src = ersetze(src, [===[
Party.MIN = 2              -- players needed (1 in Studio for testing)

]===], [===[
Party.MIN = 2              -- players needed (1 in Studio for testing)
-- 🤖 bots (v61): fill free spots in the green party zone. They race "virtually": a time from the route length,
-- live messages ("Turbo Tina is halfway!", "TURBO TINA PARKED!") and a place in the results. No car on the road.
Party.BOTS = { "Turbo Tina", "Crash Carl", "Granny Gear", "Drift Dora", "Speedy Sam", "Honk Hank" }
Party.BOT_TEMPO = { 24, 34 }   -- studs/s on average (incl. turns, traffic lights)
Party.START = Vector3.new(550, 0, 60)

]===])
src = ersetze(src, [===[

starten = function()
	local l = lobby
]===], [===[

local function routeLaenge(lektion)
	local laenge, vorher = 0, Party.START
	for _, wp in lektion and lektion.punkte or {} do
		local x, z = wp.x or (wp.pos and wp.pos.X), wp.z or (wp.pos and wp.pos.Z)
		if x and z then
			local jetzt = Vector3.new(x, 0, z)
			laenge += (jetzt - vorher).Magnitude
			vorher = jetzt
		end
	end
	return math.max(laenge, 300)
end
Party.routeLaenge = routeLaenge

local function botsStarten(r, anzahl)
	r.bots = {}
	if anzahl <= 0 then return end
	local namen = table.clone(Party.BOTS)
	local laenge = routeLaenge(r.lektion)
	for _ = 1, anzahl do
		local name = "🤖 " .. table.remove(namen, math.random(#namen))
		local tempo = Party.BOT_TEMPO[1] + math.random() * (Party.BOT_TEMPO[2] - Party.BOT_TEMPO[1])
		local fehler = math.random(0, 3)
		local roh = laenge / tempo
		local bot = { name = name, roh = roh, fehler = fehler, zeit = roh + fehler * Party.STRAFE }
		table.insert(r.bots, bot)
		task.delay(roh * 0.5, function()
			if rennen == r then anTeilnehmer(r.spieler, { typ = "party", phase = "bot", titel = name:upper() .. " IS HALFWAY!", text = "Hurry up!" }) end
		end)
		task.delay(roh, function()
			if rennen == r then
				bot.angekommen = true
				anTeilnehmer(r.spieler, { typ = "party", phase = "ziel", titel = ("🏁 %s PARKED!"):format(name:upper()), text = ("%.1f s + %d mistake(s)"):format(roh, fehler) })
			end
		end)
	end
end

starten = function(bots)
	local l = lobby
]===])
src = ersetze(src, [===[
	end
	if #dabei < minimum() then
		anTeilnehmer(dabei, { typ = "party", phase = "abbruch", titel = "🏁 NOT ENOUGH DRIVERS",
]===], [===[
	end
	if #dabei < (bots and bots > 0 and 1 or minimum()) then
		anTeilnehmer(dabei, { typ = "party", phase = "abbruch", titel = "🏁 NOT ENOUGH DRIVERS",
]===])
src = ersetze(src, [===[
	if #r.spieler == 0 then rennen = nil return end
	anTeilnehmer(r.spieler, { typ = "party", phase = "start", titel = "🏁 GO GO GO!",
]===], [===[
	if #r.spieler == 0 then rennen = nil return end
	botsStarten(r, math.min(bots or 0, Party.MAX - #r.spieler))
	anTeilnehmer(r.spieler, { typ = "party", phase = "start", titel = "🏁 GO GO GO!",
]===])
src = ersetze(src, [===[
-- green party zone: these players start right now (joins an open 🏁 lobby if there is one)
function Party.mitSpielern(liste)
	if rennen then return nil end
]===], [===[
-- green party zone: these players start right now (joins an open 🏁 lobby if there is one)
function Party.mitSpielern(liste, bots)
	if rennen then return nil end
]===])
src = ersetze(src, [===[
	end
	starten()
	local r = rennen
]===], [===[
	end
	starten(bots)
	local r = rennen
]===])
src = ersetze(src, [===[
	end
	table.sort(r.ergebnisse, function(a, b)
]===], [===[
	end
	for _, b in r.bots or {} do
		table.insert(r.ergebnisse, { bot = true, name = b.name, roh = b.roh, fehler = b.fehler, zeit = b.zeit, ziel = true })
	end
	table.sort(r.ergebnisse, function(a, b)
]===])
src = ersetze(src, [===[
	for i, e in r.ergebnisse do
		local preis = e.ziel and Party.PREISE[i] or 0
		if preis > 0 and e.p.Parent then ctx.geldGeben(e.p, preis, ("Party test – place %d"):format(i)) end
		if e.p.Parent then ctx.xpGeben(e.p, e.ziel and 60 or 20, "Party test") end
		table.insert(liste, { platz = i, name = e.name, zeit = e.ziel and e.zeit or nil, fehler = e.fehler, preis = preis })
]===], [===[
	for i, e in r.ergebnisse do
		local preis = (e.ziel and not e.bot) and Party.PREISE[i] or 0
		if e.p and e.p.Parent then
			if preis > 0 then ctx.geldGeben(e.p, preis, ("Party test – place %d"):format(i)) end
			ctx.xpGeben(e.p, e.ziel and 60 or 20, "Party test")
		end
		table.insert(liste, { platz = i, name = e.name, zeit = e.ziel and e.zeit or nil, fehler = e.fehler, preis = preis })
]===])
src = ersetze(src, [===[
	local sieger = r.ergebnisse[1]
	if sieger and sieger.ziel and #r.ergebnisse >= 2 and sieger.p.Parent then
		if ctx.Chaos then ctx.Chaos.statistik(sieger.p, "partySiege") end
]===], [===[
	local sieger = r.ergebnisse[1]
	if sieger and sieger.ziel and not sieger.bot and #r.ergebnisse >= 2 and sieger.p.Parent then
		if ctx.Chaos then ctx.Chaos.statistik(sieger.p, "partySiege") end
]===])
src = ersetze(src, [===[
	anTeilnehmer(r.spieler, { typ = "party", phase = "ergebnis", titel = "🏁 PARTY TEST RESULTS", liste = liste })
	if sieger and sieger.ziel then
		anAlle({ typ = "party", phase = "sieger", titel = "👑 " .. sieger.name:upper() .. " WINS!",
]===], [===[
	anTeilnehmer(r.spieler, { typ = "party", phase = "ergebnis", titel = "🏁 PARTY TEST RESULTS", liste = liste })
	if sieger and sieger.bot then
		anTeilnehmer(r.spieler, { typ = "party", phase = "sieger", titel = "🤖 " .. sieger.name:gsub("🤖 ", ""):upper() .. " WINS!", text = "Beaten by a bot! Try again in the green zone." })
	elseif sieger and sieger.ziel then
		anAlle({ typ = "party", phase = "sieger", titel = "👑 " .. sieger.name:upper() .. " WINS!",
]===])
assert(#src == 10106, "Ergebnis-Länge falsch: " .. #src)
s.Source = src
table.insert(log, s.Name .. ': ' .. #src)
end
do
local function ersetze(src, alt, neu)
	local a, b = string.find(src, alt, 1, true)
	assert(a, "nicht gefunden: " .. alt:sub(1, 60))
	assert(not string.find(src, alt, b + 1, true), "mehrfach: " .. alt:sub(1, 60))
	return src:sub(1, a - 1) .. neu .. src:sub(b + 1)
end
local s = game.ServerScriptService.FuehrerscheinServer
local src = s.Source
assert(#src == 152167, "Ausgangsstand passt nicht: " .. #src)
src = ersetze(src, [===[
		local falsch = st.blind.falsch or 0
		local team = Beta.blindWertung(st.fehler + falsch, erfolg, co ~= nil)
		local info = { typ = "ende", blind = true, erfolg = erfolg, text = text, fehler = st.fehler, falsch = falsch, sek = sek, titel = team.titel,
]===], [===[
		local falsch = st.blind.falsch or 0
		local team = Beta.blindWertung(st.fehler + falsch, erfolg, co ~= nil or st.blind.ki ~= nil)
		if not co and st.blind.ki then team.geld = math.floor(team.geld / 2) end -- with the AI: half the coins (a friend is more fun)
		local info = { typ = "ende", blind = true, erfolg = erfolg, text = text, fehler = st.fehler, falsch = falsch, sek = sek, titel = team.titel,
]===])
src = ersetze(src, [===[
		local info = { typ = "ende", blind = true, erfolg = erfolg, text = text, fehler = st.fehler, falsch = falsch, sek = sek, titel = team.titel,
			geld = team.geld, fahrer = p.DisplayName, copilotName = co and co.DisplayName }
		for _, wer in { p, co } do
]===], [===[
		local info = { typ = "ende", blind = true, erfolg = erfolg, text = text, fehler = st.fehler, falsch = falsch, sek = sek, titel = team.titel,
			geld = team.geld, fahrer = p.DisplayName, copilotName = co and co.DisplayName or (st.blind.ki and "🤖 " .. Beta.KI_NAME) }
		for _, wer in { p, co } do
]===])
src = ersetze(src, [===[
		fahrEvent:FireClient(p, { typ = "ziel", blind = true, nr = info.nr, gesamt = info.gesamt, text = ("🙈 Listen to %s!"):format(co.DisplayName), sprecher = "Co-pilot" })
		return
]===], [===[
		fahrEvent:FireClient(p, { typ = "ziel", blind = true, nr = info.nr, gesamt = info.gesamt, text = ("🙈 Listen to %s!"):format(co.DisplayName), sprecher = "Co-pilot" })
		return
	end
	if st.blind and st.blind.ki then
		-- 🤖 AI co-pilot (v61): the driver still sees no route, the AI calls the directions (Beta.kiNavi)
		st.blind.ki.zeit = 0
		fahrEvent:FireClient(p, { typ = "ziel", blind = true, nr = info.nr, gesamt = info.gesamt, text = ("🤖 Listen to %s!"):format(Beta.KI_NAME), sprecher = "AI co-pilot" })
		return
]===])
src = ersetze(src, [===[
			titel, sprecher = "🙈 BLIND DRIVE", "Co-pilot"
			text = ("You can't see the route – %s can! Listen and drive."):format(st.blind.copilot.DisplayName)
		end
]===], [===[
			titel, sprecher = "🙈 BLIND DRIVE", "Co-pilot"
			text = ("You can't see the route – %s can! Listen and drive."):format(st.blind.copilot and st.blind.copilot.DisplayName or ("🤖 " .. Beta.KI_NAME))
		end
]===])
src = ersetze(src, [===[
			if not st.gestartet then
				if st.blind and not st.blind.copilot then
					fahrEvent:FireClient(p, { typ = "hinweis", text = "🙈 Blind Drive: you need a co-pilot! A friend sits in your passenger seat (\"Be the co-pilot\")." })
]===], [===[
			if not st.gestartet then
				if st.blind and not st.blind.copilot and not st.blind.ki then
					fahrEvent:FireClient(p, { typ = "hinweis", text = "🙈 Blind Drive: you need a co-pilot! A friend sits in your passenger seat (\"Be the co-pilot\")." })
]===])
src = ersetze(src, [===[
		local amTor = st.tor and Regeln.durchTor(pos, st.tor.pos, st.tor.dir, st.tor.breite, st.tor.r)
		if st.blind and st.tor and st.zielAktiv then
]===], [===[
		local amTor = st.tor and Regeln.durchTor(pos, st.tor.pos, st.tor.dir, st.tor.breite, st.tor.r)
		if st.blind and st.blind.ki and not st.blind.copilot then Beta.kiNavi(p, st) end
		if st.blind and st.tor and st.zielAktiv then
]===])
src = ersetze(src, [===[
end
local blindAufruf = -math.huge
]===], [===[
end
-- 🤖 Blind Drive with the AI co-pilot (v61): for players without a partner
local function blindKIStarten(p)
	local r = lektionStarten(p, "blind")
	if r.fehler then return r end
	local st = lektionen[p]
	st.blind.ki = { zeit = 0 }
	local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		if hum.SeatPart then hum.Sit = false end
		st.sitz:Sit(hum)
	end
	fahrEvent:FireClient(p, { typ = "chaos", titel = "🤖 AI CO-PILOT!", text = ("%s navigates – you only see the road. Listen to the commands!"):format(Beta.KI_NAME), farbe = "lila" })
	return { text = ("🤖 Blind Drive with %s! You can't see the route – follow the commands."):format(Beta.KI_NAME) }
end
local blindAufruf = -math.huge
]===])
src = ersetze(src, [===[
		return blindPartnerSuchen(p)
	elseif was == "crash" then
]===], [===[
		return blindPartnerSuchen(p)
	elseif was == "blindKI" then
		return blindKIStarten(p)
	elseif was == "crash" then
]===])
src = ersetze(src, [===[
	beschaeftigt = function(p) return lektionen[p] ~= nil or jobs[p] ~= nil end,
	blindPaar = blindPaarStarten,
	spawn = workspace:FindFirstChild("FahrschulSpawn"),
]===], [===[
	beschaeftigt = function(p) return lektionen[p] ~= nil or jobs[p] ~= nil end,
	blindPaar = blindPaarStarten, blindKI = blindKIStarten,
	spawn = workspace:FindFirstChild("FahrschulSpawn"),
]===])
assert(#src == 153642, "Ergebnis-Länge falsch: " .. #src)
s.Source = src
table.insert(log, s.Name .. ': ' .. #src)
end
do
local function ersetze(src, alt, neu)
	local a, b = string.find(src, alt, 1, true)
	assert(a, "nicht gefunden: " .. alt:sub(1, 60))
	assert(not string.find(src, alt, b + 1, true), "mehrfach: " .. alt:sub(1, 60))
	return src:sub(1, a - 1) .. neu .. src:sub(b + 1)
end
local s = game.ServerScriptService.FuehrerscheinServer.Beta
local src = s.Source
assert(#src == 9289, "Ausgangsstand passt nicht: " .. #src)
src = ersetze(src, [===[

function Beta.starten(k)
]===], [===[

-- 🤖 AI co-pilot for Blind Drive (v61): looks at the next gate and calls the direction like a friend would.
-- It only knows where the gate is, not the roads – "STRAIGHT ON" until close, then the turn.
Beta.KI_NAME = "Robo-Rita"
Beta.KI_TAKT = 1.3      -- seconds between two checks
Beta.KI_WIEDERHOLEN = 5 -- the same command again after this many seconds
function Beta.kiRichtung(cf, ziel, parken)
	local rel = cf:PointToObjectSpace(Vector3.new(ziel.X, cf.Position.Y, ziel.Z))
	local dist = Vector3.new(rel.X, 0, rel.Z).Magnitude
	local winkel = math.deg(math.atan2(rel.X, -rel.Z)) -- 0 = straight ahead (front = -Z), + = right
	if parken and dist < 30 then return "stopp" end
	if math.abs(winkel) > 100 then return winkel > 0 and "rechts" or "links" end -- behind us: turn around
	if dist > 70 and math.abs(winkel) < 60 then return "gerade" end
	if winkel > 25 then return "rechts" end
	if winkel < -25 then return "links" end
	return "gerade"
end
function Beta.kiNavi(p, st)
	local ki = st.blind and st.blind.ki
	if not ki or not st.tor or not st.zielAktiv or not st.chassis then return end
	local jetzt = os.clock()
	if jetzt - (ki.check or 0) < Beta.KI_TAKT then return end
	ki.check = jetzt
	local wp = st.lektion and st.lektion.punkte and st.lektion.punkte[st.index]
	local art = Beta.kiRichtung(st.chassis.CFrame, st.tor.pos, wp and wp.parken)
	if art == ki.letzt and jetzt - (ki.zeit or 0) < Beta.KI_WIEDERHOLEN then return end
	ki.letzt, ki.zeit = art, jetzt
	local def = Beta.KOMMANDOS[art]
	ctx.fahrEvent:FireClient(p, { typ = "kommando", art = art, text = def[1], farbe = def[2], von = "🤖 " .. Beta.KI_NAME })
end

function Beta.starten(k)
]===])
assert(#src == 10926, "Ergebnis-Länge falsch: " .. #src)
s.Source = src
table.insert(log, s.Name .. ': ' .. #src)
end
do
local function ersetze(src, alt, neu)
	local a, b = string.find(src, alt, 1, true)
	assert(a, "nicht gefunden: " .. alt:sub(1, 60))
	assert(not string.find(src, alt, b + 1, true), "mehrfach: " .. alt:sub(1, 60))
	return src:sub(1, a - 1) .. neu .. src:sub(b + 1)
end
local s = game.ServerScriptService.FuehrerscheinServer.Chaos
local src = s.Source
assert(#src == 53460, "Ausgangsstand passt nicht: " .. #src)
src = ersetze(src, [===[

EVENTS.gag = {
]===], [===[

-- 🚗 v61: wrong-way driver – a car comes at you in your lane, horn and flashing lights. A ghost: it drives through you.
local function geisterAuto()
	local m
	local vorlagen = game:GetService("ReplicatedStorage"):FindFirstChild("Fuehrerschein")
	vorlagen = vorlagen and vorlagen:FindFirstChild("Autos")
	local v = vorlagen and (vorlagen:FindFirstChild("Limousine") or vorlagen:FindFirstChild("Kleinwagen"))
	if v then
		local ok, Verkehr = pcall(require, game:GetService("ReplicatedStorage").Fuehrerschein.Verkehr)
		if ok and Verkehr.ausVorlage then m = Verkehr.ausVorlage(v, 14.5, Color3.fromRGB(150, 20, 25), nil) end
	end
	if m then
		for _, t in m:GetDescendants() do
			if t:IsA("BasePart") then t.CanCollide, t.CanQuery, t.CanTouch = false, false, false end
		end
		m.Name = "Geisterfahrer"
		return m
	end
	-- no templates (tests, old place): a simple block car
	m = modell("Geisterfahrer")
	block(m, "Lack", Vector3.new(6.4, 2.6, 14), Color3.fromRGB(150, 20, 25), CFrame.new(0, 2.2, 0))
	block(m, "Glas", Vector3.new(5.6, 1.8, 6.5), Color3.fromRGB(35, 45, 60), CFrame.new(0, 4.3, 0.8))
	block(m, "Licht", Vector3.new(1.2, 0.5, 0.2), Color3.fromRGB(255, 250, 225), CFrame.new(-2.2, 2.6, -7.05), Enum.Material.Neon)
	block(m, "Licht", Vector3.new(1.2, 0.5, 0.2), Color3.fromRGB(255, 250, 225), CFrame.new(2.2, 2.6, -7.05), Enum.Material.Neon)
	return m
end

EVENTS.geisterfahrer = {
	gewicht = 2,
	banner = { titel = "🚗 WRONG-WAY DRIVER!", text = "A car is coming at you in YOUR lane – swerve!" },
	aufbauen = function(e)
		local a = geisterAuto()
		a.Parent = e.modell
		local lichter = {}
		for _, t in a:GetDescendants() do
			if t:IsA("BasePart") and t.Name == "Licht" then table.insert(lichter, t) end
		end
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(150, 44)
		bb.StudsOffset = Vector3.new(0, 7, 0)
		bb.AlwaysOnTop = true
		bb.MaxDistance = 160
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Text = "HONK HONK!"
		t.TextColor3 = Color3.fromRGB(255, 220, 60)
		t.TextStrokeTransparency = 0
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.Parent = bb
		bb.Parent = a.PrimaryPart or a:FindFirstChildWhichIsA("BasePart")
		local tier = { m = a, seite = 0, vor = -45, r = 4.2, phase = 0, geist = true }
		tier.bewege = function(tier_, zeit)
			tier_.aktSeite = tier_.seite + math.sin(zeit * 1.7) * 0.8 -- wobbles a bit
			tier_.aktVor = tier_.vor + zeit * 17 -- comes at the car
			tier_.m:PivotTo(bodenCF(e, tier_.aktSeite, tier_.aktVor, 0) * CFrame.Angles(0, math.pi, 0))
			local an = math.floor(zeit * 4) % 2 == 0 -- flashing lights
			for _, l in lichter do l.Material = an and Enum.Material.Neon or Enum.Material.SmoothPlastic end
		end
		e.tiere = { tier }
	end,
	tempo = 0,
}

-- 😈 v61: the instructor sabotages you (only looks: coffee on the windscreen, selfie flash, hands over your eyes,
-- wrong directions). Nothing touches the car.
Chaos.STREICHE = {
	{ titel = "☕ OOPS, COFFEE!", text = "%s spilled coffee all over the windscreen!", sagt = "Wipers! WHERE ARE THE WIPERS?!", extra = { matsch = true } },
	{ titel = "📸 SELFIE TIME!", text = "%s takes a selfie with flash – you're blinded!", sagt = "Say CHEESE! ...oops, too bright?", extra = { blitz = true } },
	{ titel = "🙈 GUESS WHO?", text = "%s covers your eyes for a second!", sagt = "Guess who! Hehe... keep driving!", extra = { dunkel = 1.2 } },
	{ titel = "😜 WRONG WAY... JUST KIDDING!", text = "%s shouts the wrong direction on purpose!", sagt = "LEFT! No, RIGHT! No... just kidding!", falsch = true },
}
EVENTS.streich = {
	gewicht = 2,
	ohneObjekt = true,
	streich = true,
}

EVENTS.gag = {
]===])
src = ersetze(src, [===[
	art = art or wuerfeln(st)
	if art == "gag" and not c.lehrer.gags then art = "banane" end -- no instructor in your own car
	local ev = EVENTS[art]
]===], [===[
	art = art or wuerfeln(st)
	if (art == "gag" or art == "streich") and not c.lehrer.gags then art = "banane" end -- no instructor in your own car
	if art == "streich" and st.blind then art = "gag" end -- Blind Drive: no fake directions on top of the co-pilot's
	local ev = EVENTS[art]
]===])
src = ersetze(src, [===[
	if ctx and ctx.onEvent then pcall(ctx.onEvent, p) end -- analytics funnel (v54)
	if ev.ohneObjekt then
]===], [===[
	if ctx and ctx.onEvent then pcall(ctx.onEvent, p) end -- analytics funnel (v54)
	if ev.streich then
		local s = zufall(Chaos.STREICHE)
		banner(p, s.titel, s.text:format(c.lehrer.name or "Your instructor"), "rot", s.extra)
		Chaos.sagen(st, nil, s.sagt)
		if s.falsch then
			-- a fake command, then the instructor laughs
			local falsch = math.random() < 0.5 and { "◀ LEFT!", "links" } or { "RIGHT! ▶", "rechts" }
			ctx.fahrEvent:FireClient(p, { typ = "kommando", art = falsch[2], text = falsch[1], farbe = "gelb", von = c.lehrer.name or "Instructor" })
		end
		c.naechstesEvent = os.clock() + math.random(28, 40)
		return { art = art }
	end
	if ev.ohneObjekt then
]===])
src = ersetze(src, [===[
	elseif not e.getroffen and e.naechster < 40 then
		local texte = { kuehe = "Dodged the cows!", enten = "The ducks made it!", banane = "Dodged the banana!",
			huehner = "All chickens survived!", wagen = "Dodged the shopping cart!", reifen = "Dodged the giant tire!", pfuetze = "Stayed clean!" }
]===], [===[
	elseif not e.getroffen and e.naechster < 40 then
		local texte = { kuehe = "Dodged the cows!", enten = "The ducks made it!", banane = "Dodged the banana!", geisterfahrer = "Dodged the wrong-way driver!",
			huehner = "All chickens survived!", wagen = "Dodged the shopping cart!", reifen = "Dodged the giant tire!", pfuetze = "Stayed clean!" }
]===])
src = ersetze(src, [===[
					local was = { kuehe = { "💥 MOOOO!", "You bumped a cow. It's fine... probably." },
						enten = { "🦆 QUAAACK!", "A duck went flying! It's okay, ducks can fly." },
]===], [===[
					local was = { kuehe = { "💥 MOOOO!", "You bumped a cow. It's fine... probably." },
						geisterfahrer = { "👻 IT WENT RIGHT THROUGH YOU!", "A GHOST driver! Spooky... but that counts as a crash." },
						enten = { "🦆 QUAAACK!", "A duck went flying! It's okay, ducks can fly." },
]===])
assert(#src == 58014, "Ergebnis-Länge falsch: " .. #src)
s.Source = src
table.insert(log, s.Name .. ': ' .. #src)
end
do
local function ersetze(src, alt, neu)
	local a, b = string.find(src, alt, 1, true)
	assert(a, "nicht gefunden: " .. alt:sub(1, 60))
	assert(not string.find(src, alt, b + 1, true), "mehrfach: " .. alt:sub(1, 60))
	return src:sub(1, a - 1) .. neu .. src:sub(b + 1)
end
local s = game.ServerScriptService.FuehrerscheinServer.Shop
local src = s.Source
assert(#src == 12513, "Ausgangsstand passt nicht: " .. #src)
src = ersetze(src, [===[

-- golden tag above VIP players
local function vipSchild(p)
]===], [===[

-- VIP name tag (v61): the others see the name in gold with a small "VIP" next to it; you don't see your own tag
local function vipSchild(p)
]===])
src = ersetze(src, [===[
	local kopf = figur and figur:FindFirstChild("Head")
	if not kopf then return end
]===], [===[
	local kopf = figur and figur:FindFirstChild("Head")
	local hum = figur and figur:FindFirstChildOfClass("Humanoid")
	if not kopf then return end
]===])
src = ersetze(src, [===[
	if alt then return end
	local g = Instance.new("BillboardGui")
]===], [===[
	if alt then return end
	-- the normal Roblox name is replaced by the golden one
	if hum then hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
	local g = Instance.new("BillboardGui")
]===])
src = ersetze(src, [===[
	g.Name = "VipSchild"
	g.Size = UDim2.fromOffset(70, 24)
	g.StudsOffset = Vector3.new(0, 2.6, 0)
	g.AlwaysOnTop = false
]===], [===[
	g.Name = "VipSchild"
	g.Size = UDim2.fromOffset(200, 26)
	g.StudsOffset = Vector3.new(0, 2.3, 0)
	g.AlwaysOnTop = false
]===])
src = ersetze(src, [===[
	g.AlwaysOnTop = false
	g.MaxDistance = 80
	g.Parent = kopf
]===], [===[
	g.AlwaysOnTop = false
	g.MaxDistance = 100
	g.PlayerToHideFrom = p
	g.Parent = kopf
]===])
src = ersetze(src, [===[
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundColor3 = Color3.fromRGB(40, 32, 10)
	t.BackgroundTransparency = 0.25
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.TextColor3 = Color3.fromRGB(255, 210, 70)
]===], [===[
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBold
	t.TextSize = 18
	t.RichText = true
	t.TextColor3 = Color3.fromRGB(255, 210, 70)
]===])
src = ersetze(src, [===[
	t.TextColor3 = Color3.fromRGB(255, 210, 70)
	t.Text = "👑 VIP"
	t.Parent = g
]===], [===[
	t.TextColor3 = Color3.fromRGB(255, 210, 70)
	t.TextStrokeTransparency = 0.3
	t.Text = ('%s <font size="11" color="#FFE9A8"><b>VIP</b></font>'):format(p.DisplayName:gsub("[<>&]", ""))
	t.Parent = g
]===])
src = ersetze(src, [===[
	t.Parent = g
	Instance.new("UICorner", t)
end
]===], [===[
	t.Parent = g
end
]===])
assert(#src == 12872, "Ergebnis-Länge falsch: " .. #src)
s.Source = src
table.insert(log, s.Name .. ': ' .. #src)
end
do
local function ersetze(src, alt, neu)
	local a, b = string.find(src, alt, 1, true)
	assert(a, "nicht gefunden: " .. alt:sub(1, 60))
	assert(not string.find(src, alt, b + 1, true), "mehrfach: " .. alt:sub(1, 60))
	return src:sub(1, a - 1) .. neu .. src:sub(b + 1)
end
local s = game.ReplicatedStorage.Fuehrerschein.BetaClient
local src = s.Source
assert(#src == 14361, "Ausgangsstand passt nicht: " .. #src)
src = ersetze(src, [===[
			"<b>One drives, one navigates.</b>\nThe driver can't see the route – the co-pilot sees the map and tells them where to go.\n\n"
				.. "👥 <b>With a friend:</b> you drive, your friend sits next to you.\n🎲 <b>Find a partner:</b> we match you with another player on this server.", {
				{ text = "👥 With a friend", farbe = GRUEN, klick = mitFreund },
]===], [===[
			"<b>One drives, one navigates.</b>\nThe driver can't see the route – the co-pilot sees the map and tells them where to go.\n\n"
				.. "👥 <b>With a friend:</b> you drive, your friend sits next to you.\n🎲 <b>Find a partner:</b> we match you with another player on this server.\n🤖 <b>AI co-pilot:</b> Robo-Rita calls the directions.", {
				{ text = "👥 With a friend", farbe = GRUEN, klick = mitFreund },
]===])
src = ersetze(src, [===[
				{ text = "🎲 Find a partner", farbe = BLAU, klick = partnerSuchen },
				{ text = "Close", farbe = Color3.fromRGB(70, 75, 85), klick = k.schliessen },
]===], [===[
				{ text = "🎲 Find a partner", farbe = BLAU, klick = partnerSuchen },
				{ text = "🤖 With the AI co-pilot", farbe = Color3.fromRGB(150, 60, 170), klick = function()
					local r = frage("blindKI")
					if r.fehler then warnen(r.fehler, Color3.fromRGB(200, 140, 30)) else k.schliessen() warnen(r.text or "", GRUEN) end
				end },
				{ text = "Close", farbe = Color3.fromRGB(70, 75, 85), klick = k.schliessen },
]===])
assert(#src == 14682, "Ergebnis-Länge falsch: " .. #src)
s.Source = src
table.insert(log, s.Name .. ': ' .. #src)
end
do
local function ersetze(src, alt, neu)
	local a, b = string.find(src, alt, 1, true)
	assert(a, "nicht gefunden: " .. alt:sub(1, 60))
	assert(not string.find(src, alt, b + 1, true), "mehrfach: " .. alt:sub(1, 60))
	return src:sub(1, a - 1) .. neu .. src:sub(b + 1)
end
local s = game.ReplicatedStorage.Fuehrerschein.SpassClient
local src = s.Source
assert(#src == 5868, "Ausgangsstand passt nicht: " .. #src)
src = ersetze(src, [===[
	-- the server threw us out of the car: go limp, fly, get up again
	game:GetService("ReplicatedStorage"):WaitForChild("Fuehrerschein"):WaitForChild("Fahrstunde").OnClientEvent:Connect(function(info)
]===], [===[
	-- the server threw us out of the car: go limp, fly, get up again
	-- 🙈 v61 instructor prank "hands over your eyes": the screen goes dark for a moment
	local dunkelGui = Instance.new("ScreenGui")
	dunkelGui.Name = "Augen"
	dunkelGui.IgnoreGuiInset = true
	dunkelGui.ResetOnSpawn = false
	dunkelGui.DisplayOrder = 40
	dunkelGui.Parent = spieler:WaitForChild("PlayerGui")
	game:GetService("ReplicatedStorage"):WaitForChild("Fuehrerschein"):WaitForChild("Fahrstunde").OnClientEvent:Connect(function(info)
		if type(info) ~= "table" or info.typ ~= "chaos" or not info.dunkel then return end
		local f = Instance.new("Frame")
		f.Size = UDim2.fromScale(1, 1)
		f.BackgroundColor3 = Color3.fromRGB(20, 12, 8)
		f.BackgroundTransparency = 0.05
		f.BorderSizePixel = 0
		f.Parent = dunkelGui
		task.delay(tonumber(info.dunkel) or 1.2, function()
			game:GetService("TweenService"):Create(f, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
			task.delay(0.6, function() f:Destroy() end)
		end)
	end)

	game:GetService("ReplicatedStorage"):WaitForChild("Fuehrerschein"):WaitForChild("Fahrstunde").OnClientEvent:Connect(function(info)
]===])
assert(#src == 6808, "Ergebnis-Länge falsch: " .. #src)
s.Source = src
table.insert(log, s.Name .. ': ' .. #src)
end
do
local s = game.StarterPlayer.StarterPlayerScripts.FuehrerscheinClient
local src = s.Source
src = src:gsub("client v60 loaded", "client v61 loaded"):gsub("start screen v60 loading", "start screen v61 loading")
s.Source = src
table.insert(log, "Client: " .. #src)
end
do -- Nachtrag: Kommandos unter die Chaos-Banner (überlappten im Studio-Test), mehrfach ausführbar
local s = game.ReplicatedStorage.Fuehrerschein.BetaClient
s.Source = s.Source:gsub("	kommandoText.Position = UDim2.new%(0.5, 0, 0.12, 0%)\n", "	kommandoText.Position = UDim2.new(0.5, 0, 0.4, 0) -- v61: below the chaos banners (they overlapped)\n")
table.insert(log, "BetaClient: " .. #s.Source .. " (soll 14731)")
end
game:GetService("ChangeHistoryService"):SetWaypoint("v61")
print(table.concat(log, " | "))
return table.concat(log, " | ")
