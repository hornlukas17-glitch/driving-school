-- 🏁 Party driving test: up to 4 players race the same exam route with extra chaos.
-- Somebody opens a party with the 🏁 button, everybody can join for 25 seconds, then: GO!
-- Every player drives their own driving school car. Each mistake = +5 seconds. First to park wins.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Party = {}
Party.MAX = 4
Party.WARTEN = 25          -- seconds to join
Party.ZEIT = 300           -- max race time
Party.STRAFE = 5           -- seconds per mistake
Party.PREISE = { 500, 250, 120, 60 }
Party.MIN = 2              -- players needed (1 in Studio for testing)

local ctx
local lobby     -- { spieler = {}, ende = clock, offen = player }
local rennen    -- { spieler = {}, start = clock, ergebnisse = {}, lektion = {} }
Party.zustand = function() return lobby, rennen end

local function an(p, info)
	if p.Parent then ctx.fahrEvent:FireClient(p, info) end
end
local function anAlle(info)
	for _, sp in Players:GetPlayers() do an(sp, info) end
end
local function anTeilnehmer(liste, info)
	for _, sp in liste do an(sp, info) end
end

local function minimum()
	return RunService:IsStudio() and 1 or Party.MIN
end

local starten -- forward

function Party.beitreten(p)
	if rennen and table.find(rennen.spieler, p) then return { fehler = "You are already in the party race!" } end
	if rennen then return { fehler = "A party race is running right now – the next one can start in a moment!" } end
	if ctx.beschaeftigt(p) then return { fehler = "Finish your lesson or job first." } end
	if not lobby then
		lobby = { spieler = {}, ende = os.clock() + Party.WARTEN, offen = p }
		anAlle({ typ = "party", phase = "lobby", titel = "🏁 PARTY TEST!",
			text = p.DisplayName .. " opened a party driving test – press 🏁 Party to join! (" .. Party.WARTEN .. " s)" })
		local diese = lobby
		task.delay(Party.WARTEN, function()
			if lobby == diese then starten() end
		end)
	end
	if table.find(lobby.spieler, p) then
		return { text = ("You're in! The race starts in %d s."):format(math.ceil(lobby.ende - os.clock())) }
	end
	if #lobby.spieler >= Party.MAX then return { fehler = "The party is full (4 players). Wait for the next one!" } end
	table.insert(lobby.spieler, p)
	local namen = {}
	for _, sp in lobby.spieler do table.insert(namen, sp.DisplayName) end
	anTeilnehmer(lobby.spieler, { typ = "party", phase = "beitritt", titel = ("🏁 %d/%d IN THE PARTY"):format(#lobby.spieler, Party.MAX),
		text = table.concat(namen, ", ") })
	return { text = ("You're in! The race starts in %d s – invite your friends!"):format(math.ceil(lobby.ende - os.clock())) }
end

starten = function()
	local l = lobby
	lobby = nil
	if not l then return end
	local dabei = {}
	for _, sp in l.spieler do
		if sp.Parent and not ctx.beschaeftigt(sp) then table.insert(dabei, sp) end
	end
	if #dabei < minimum() then
		anTeilnehmer(dabei, { typ = "party", phase = "abbruch", titel = "🏁 NOT ENOUGH DRIVERS",
			text = "Nobody else joined. Invite a friend and try again!" })
		return
	end
	local r = { spieler = {}, start = os.clock(), ergebnisse = {}, lektion = ctx.zufallsRoute() }
	rennen = r
	for _, sp in dabei do
		local ok = ctx.lektionStarten(sp, "party", nil, r)
		if ok and not ok.fehler then table.insert(r.spieler, sp) end
	end
	if #r.spieler == 0 then rennen = nil return end
	anTeilnehmer(r.spieler, { typ = "party", phase = "start", titel = "🏁 GO GO GO!",
		text = ("Get in your car! First to park wins. Each mistake = +%d s."):format(Party.STRAFE) })
	task.delay(Party.ZEIT, function()
		if rennen == r then Party.abschluss() end
	end)
end
Party.jetztStarten = function() starten() end -- (tests)

-- a lesson of the race ended (parked = erfolg, or cancelled / left the car)
function Party.fertig(p, st, erfolg)
	local r = rennen
	if not r or st.party ~= r then return end
	for _, e in r.ergebnisse do if e.p == p then return end end
	local zeit = os.clock() - r.start
	table.insert(r.ergebnisse, { p = p, name = p.DisplayName, roh = zeit, fehler = st.fehler, zeit = zeit + st.fehler * Party.STRAFE, ziel = erfolg })
	if erfolg then
		local platz = 0
		for _, e in r.ergebnisse do if e.ziel then platz += 1 end end
		anTeilnehmer(r.spieler, { typ = "party", phase = "ziel", titel = ("🏁 %s PARKED!"):format(p.DisplayName:upper()),
			text = ("%.1f s + %d mistake(s)"):format(zeit, st.fehler) })
	end
	if #r.ergebnisse >= #r.spieler then Party.abschluss() end
end

function Party.abschluss()
	local r = rennen
	if not r then return end
	rennen = nil
	-- whoever is still driving is out
	for _, sp in r.spieler do
		local fertig = false
		for _, e in r.ergebnisse do if e.p == sp then fertig = true end end
		if not fertig then
			table.insert(r.ergebnisse, { p = sp, name = sp.DisplayName, fehler = 0, zeit = math.huge, ziel = false })
			ctx.lektionAbbrechen(sp, "Time is up!")
		end
	end
	table.sort(r.ergebnisse, function(a, b)
		if a.ziel ~= b.ziel then return a.ziel end
		return a.zeit < b.zeit
	end)
	local liste = {}
	for i, e in r.ergebnisse do
		local preis = e.ziel and Party.PREISE[i] or 0
		if preis > 0 and e.p.Parent then ctx.geldGeben(e.p, preis, ("Party test – place %d"):format(i)) end
		if e.p.Parent then ctx.xpGeben(e.p, e.ziel and 60 or 20, "Party test") end
		table.insert(liste, { platz = i, name = e.name, zeit = e.ziel and e.zeit or nil, fehler = e.fehler, preis = preis })
	end
	local sieger = r.ergebnisse[1]
	if sieger and sieger.ziel and #r.ergebnisse >= 2 and sieger.p.Parent then
		if ctx.Chaos then ctx.Chaos.statistik(sieger.p, "partySiege") end
		Party.krone(sieger.p)
	end
	anTeilnehmer(r.spieler, { typ = "party", phase = "ergebnis", titel = "🏁 PARTY TEST RESULTS", liste = liste })
	if sieger and sieger.ziel then
		anAlle({ typ = "party", phase = "sieger", titel = "👑 " .. sieger.name:upper() .. " WINS!",
			text = ("won the party driving test (%d drivers)"):format(#r.ergebnisse) })
	end
end

-- 👑 crown over the winner's head for 10 minutes
function Party.krone(p)
	local kopf = p.Character and p.Character:FindFirstChild("Head")
	if not kopf then return end
	local alt = kopf:FindFirstChild("PartyKrone")
	if alt then alt:Destroy() end
	local g = Instance.new("BillboardGui")
	g.Name = "PartyKrone"
	g.Size = UDim2.fromOffset(120, 34)
	g.StudsOffset = Vector3.new(0, 3.4, 0)
	g.MaxDistance = 120
	g.Parent = kopf
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = "👑 PARTY CHAMP"
	t.TextScaled = true
	t.Font = Enum.Font.FredokaOne
	t.TextColor3 = Color3.fromRGB(255, 215, 60)
	t.TextStrokeTransparency = 0
	t.Parent = g
	task.delay(600, function() if g.Parent then g:Destroy() end end)
end

function Party.starten(c)
	ctx = c
	Players.PlayerRemoving:Connect(function(p)
		if lobby then
			local i = table.find(lobby.spieler, p)
			if i then table.remove(lobby.spieler, i) end
		end
		local r = rennen
		if r and table.find(r.spieler, p) then
			for _, e in r.ergebnisse do if e.p == p then return end end
			table.insert(r.ergebnisse, { p = p, name = p.DisplayName, fehler = 0, zeit = math.huge, ziel = false })
			if #r.ergebnisse >= #r.spieler then task.defer(Party.abschluss) end
		end
	end)
end

return Party
