-- Reasons to come back (server): daily login streak, playtime gifts, friends / group bonus,
-- achievements with tiers incl. license classes, optional Roblox badges.
--
-- Design notes (what keeps players):
--  * a reward is always "almost there": every list shows the next tiers, not just the next one
--  * daily streak bridges sessions (missing a day starts again at day 1)
--  * the first playtime gift comes after 10 minutes (Roblox pays creators for 10+ min sessions)
--  * playing with friends gives a bonus (friends bring friends)
-- All numbers can be changed here.
local Players = game:GetService("Players")
local BadgeService = game:GetService("BadgeService")

local Belohnungen = {}

-- 7-day calendar, starts again after day 7 (the streak counter keeps going)
Belohnungen.TAEGLICH = {
	{ geld = 150 }, { geld = 250 }, { geld = 350, xp = 50 }, { geld = 500 },
	{ geld = 650 }, { geld = 800, xp = 100 }, { geld = 2000, xp = 300, gross = true },
}

-- gifts for playing time on one day (minutes)
Belohnungen.SPIELZEIT = {
	{ min = 10, geld = 100 }, { min = 25, geld = 200 }, { min = 45, geld = 350 },
	{ min = 70, geld = 500, xp = 100 }, { min = 100, geld = 800, xp = 150 },
}

-- Roblox group: put the group ID here (0 = off). Members get a one-time gift.
Belohnungen.GRUPPE_ID = 0
Belohnungen.GRUPPE_GESCHENK = 1000

-- achievements: wert(d) = current value, stufen = goals with rewards, badge = Roblox badge ID for the last tier (0 = none)
Belohnungen.ERFOLGE = {
	{ id = "klasseB", kategorie = "license", icon = "🪪", name = "Class B – Car", text = "Pass the driving test",
		wert = function(d) return d.fuehrerschein and 1 or 0 end, stufen = { { 1, 500, 100 } }, badge = 0 },
	{ id = "klasseC", kategorie = "license", icon = "🚚", name = "Class C – Truck", text = "Pass the truck test",
		wert = function(d) return d.lkwFuehrerschein and 1 or 0 end, stufen = { { 1, 1000, 200 } }, badge = 0 },
	{ id = "klasseCE", kategorie = "license", icon = "🚛", name = "Class CE – Heavy load", text = "Unlock the Mega Truck (15 truck jobs)",
		wert = function(d) return d.lkwFahrten or 0 end, stufen = { { 5, 500, 100 }, { 15, 2000, 400 } }, badge = 0 },
	{ id = "taxi", kategorie = "license", icon = "🚕", name = "Taxi license", text = "Drive taxi passengers",
		wert = function(d) return d.taxiFahrten or 0 end, stufen = { { 10, 400, 80 }, { 50, 1500, 250 }, { 200, 5000, 600 } }, badge = 0 },
	{ id = "lieferungen", kategorie = "jobs", icon = "📦", name = "Delivery hero", text = "Deliver packages and pizzas",
		wert = function(d) return d.lieferungen or 0 end, stufen = { { 10, 300, 60 }, { 50, 1000, 200 }, { 200, 4000, 500 }, { 1000, 15000, 1500 } }, badge = 0 },
	{ id = "km", kategorie = "driving", icon = "🛣", name = "Road trip", text = "Drive kilometers in your own cars",
		wert = function(d) return math.floor(d.kmGesamt or 0) end, stufen = { { 10, 300, 60 }, { 50, 1200, 200 }, { 250, 5000, 600 }, { 1000, 20000, 2000 } }, badge = 0 },
	{ id = "perfekt", kategorie = "driving", icon = "🏆", name = "Perfect driver", text = "Lessons or tests without a single mistake",
		wert = function(d) return d.perfekt or 0 end, stufen = { { 1, 200, 50 }, { 5, 800, 150 }, { 25, 3000, 400 }, { 100, 10000, 1200 } }, badge = 0 },
	{ id = "autos", kategorie = "collection", icon = "🚗", name = "Car collector", text = "Own different cars",
		wert = function(d) return #(d.autos or {}) end, stufen = { { 1, 300, 50 }, { 3, 1500, 200 }, { 5, 5000, 500 }, { 8, 15000, 1500 } }, badge = 0 },
	{ id = "level", kategorie = "collection", icon = "⭐", name = "Experienced", text = "Reach a level",
		wert = function(d) return math.floor(math.sqrt((d.xp or 0) / 150)) + 1 end, stufen = { { 5, 500, 0 }, { 10, 1500, 0 }, { 20, 5000, 0 }, { 40, 20000, 0 } }, badge = 0 },
	{ id = "serie", kategorie = "loyal", icon = "🔥", name = "Loyal driver", text = "Daily reward streak (days in a row)",
		wert = function(d) return d.login and d.login.beste or 0 end, stufen = { { 3, 500, 50 }, { 7, 1500, 150 }, { 14, 4000, 400 }, { 30, 12000, 1000 } }, badge = 0 },
	{ id = "freunde", kategorie = "loyal", icon = "🤝", name = "Better together", text = "Minutes played with a friend on the server",
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
		wert = function(d) local n = 0 for _ in d.villen or {} do n += 1 end return n end, stufen = { { 1, 2000, 300 } }, badge = 0 },
}

local ctx
local freundeCache = {} -- ["a:b"] = true/false

local function heute() return os.date("!%Y-%m-%d") end
local function gestern() return os.date("!%Y-%m-%d", os.time() - 86400) end

local function login(d)
	d.login = d.login or { letzte = "", serie = 0, beste = 0 }
	return d.login
end
local function spielzeit(d)
	if not d.spielzeit or d.spielzeit.tag ~= heute() then
		d.spielzeit = { tag = heute(), sek = 0, abgeholt = {} }
	end
	return d.spielzeit
end

-- next daily reward: which day of the calendar and is it ready?
local function taeglichInfo(d)
	local l = login(d)
	local bereit = l.letzte ~= heute()
	local serie = bereit and (l.letzte == gestern() and l.serie + 1 or 1) or l.serie
	local tagNr = (serie - 1) % #Belohnungen.TAEGLICH + 1
	return { bereit = bereit, serie = serie, tag = tagNr, verloren = bereit and l.serie > 0 and l.letzte ~= gestern() }
end

local function erfolgStand(d, e)
	d.erfolge = d.erfolge or {}
	local abgeholt = d.erfolge[e.id] or 0      -- how many tiers were claimed
	return e.wert(d), abgeholt
end

-- number of rewards that can be claimed right now (red dot on the button)
function Belohnungen.offen(p)
	local d = ctx.daten[p]
	if not d then return 0 end
	local n = taeglichInfo(d).bereit and 1 or 0
	local sz = spielzeit(d)
	for i, s in Belohnungen.SPIELZEIT do
		if sz.sek >= s.min * 60 and not sz.abgeholt[i] then n += 1 end
	end
	if Belohnungen.GRUPPE_ID ~= 0 and not d.gruppeGeschenk and p:GetAttribute("InGruppe") then n += 1 end
	for _, e in Belohnungen.ERFOLGE do
		local wert, abgeholt = erfolgStand(d, e)
		local stufe = e.stufen[abgeholt + 1]
		if stufe and wert >= stufe[1] then n += 1 end
	end
	return n
end

local function markieren(p)
	p:SetAttribute("BelohnungenOffen", Belohnungen.offen(p))
end
Belohnungen.markieren = markieren

function Belohnungen.status(p)
	if not ctx then return { fehler = "Still loading – try again in a moment." } end
	local d = ctx.daten[p]
	local t = taeglichInfo(d)
	local sz = spielzeit(d)
	local geschenke = {}
	for i, s in Belohnungen.SPIELZEIT do
		table.insert(geschenke, { nr = i, min = s.min, geld = s.geld, xp = s.xp, abgeholt = sz.abgeholt[i] == true, bereit = sz.sek >= s.min * 60 })
	end
	local erfolge = {}
	for _, e in Belohnungen.ERFOLGE do
		local wert, abgeholt = erfolgStand(d, e)
		local stufen = {}
		for i, s in e.stufen do
			table.insert(stufen, { ziel = s[1], geld = s[2], xp = s[3], abgeholt = i <= abgeholt })
		end
		table.insert(erfolge, { id = e.id, kategorie = e.kategorie, icon = e.icon, name = e.name, text = e.text, wert = wert, stufen = stufen, abgeholt = abgeholt })
	end
	return {
		taeglich = { liste = Belohnungen.TAEGLICH, bereit = t.bereit, serie = t.serie, tag = t.tag, verloren = t.verloren, beste = login(d).beste },
		spielzeit = { sek = sz.sek, geschenke = geschenke },
		erfolge = erfolge,
		gruppe = Belohnungen.GRUPPE_ID ~= 0 and { id = Belohnungen.GRUPPE_ID, geschenk = Belohnungen.GRUPPE_GESCHENK, drin = p:GetAttribute("InGruppe") == true, abgeholt = d.gruppeGeschenk == true } or nil,
		freunde = p:GetAttribute("FreundeBonus") == true,
		geld = d.geld,
	}
end

local function geben(p, geld, xp, grund)
	if geld and geld > 0 then ctx.geldGeben(p, geld, grund) end
	if xp and xp > 0 then ctx.xpGeben(p, xp, grund) end
end

function Belohnungen.abholen(p, eingabe)
	if not ctx then return { fehler = "Still loading – try again in a moment." } end
	local d = ctx.daten[p]
	if type(eingabe) ~= "table" then return { fehler = "?" } end
	local text
	if eingabe.art == "taeglich" then
		local t = taeglichInfo(d)
		if not t.bereit then return { fehler = "You already got today's reward. Come back tomorrow!" } end
		local l = login(d)
		l.serie, l.letzte = t.serie, heute()
		l.beste = math.max(l.beste or 0, l.serie)
		local b = Belohnungen.TAEGLICH[t.tag]
		geben(p, b.geld, b.xp, ("Daily reward – day %d"):format(t.tag))
		text = ("🔥 Day %d in a row! Come back tomorrow for day %d."):format(t.serie, t.tag % #Belohnungen.TAEGLICH + 1)
	elseif eingabe.art == "spielzeit" then
		local nr = tonumber(eingabe.nr)
		local s = nr and Belohnungen.SPIELZEIT[nr]
		local sz = spielzeit(d)
		if not s then return { fehler = "?" } end
		if sz.abgeholt[nr] then return { fehler = "Already claimed." } end
		if sz.sek < s.min * 60 then return { fehler = ("Play %d more minutes for this gift."):format(math.ceil((s.min * 60 - sz.sek) / 60)) } end
		sz.abgeholt[nr] = true
		geben(p, s.geld, s.xp, ("Playtime gift (%d min)"):format(s.min))
		text = "🎁 Playtime gift claimed!"
	elseif eingabe.art == "erfolg" then
		local e
		for _, x in Belohnungen.ERFOLGE do if x.id == eingabe.id then e = x end end
		if not e then return { fehler = "?" } end
		local wert, abgeholt = erfolgStand(d, e)
		local s = e.stufen[abgeholt + 1]
		if not s then return { fehler = "All tiers done!" } end
		if wert < s[1] then return { fehler = "Not reached yet." } end
		d.erfolge[e.id] = abgeholt + 1
		geben(p, s[2], s[3], e.icon .. " " .. e.name)
		if abgeholt + 1 == #e.stufen and e.badge ~= 0 then
			pcall(function() BadgeService:AwardBadge(p.UserId, e.badge) end)
		end
		text = ("%s %s – tier %d reached!"):format(e.icon, e.name, abgeholt + 1)
	elseif eingabe.art == "gruppe" then
		if Belohnungen.GRUPPE_ID == 0 or d.gruppeGeschenk then return { fehler = "Not available." } end
		if not p:GetAttribute("InGruppe") then return { fehler = "Join our Roblox group first, then rejoin the game." } end
		d.gruppeGeschenk = true
		geben(p, Belohnungen.GRUPPE_GESCHENK, 0, "Group gift")
		text = "👥 Thanks for joining the group!"
	else
		return { fehler = "?" }
	end
	ctx.geaendert(p)
	markieren(p)
	return { text = text, status = Belohnungen.status(p) }
end

-- friends on the same server -> bonus for both
local function freunde(a, b)
	local k = a.UserId < b.UserId and (a.UserId .. ":" .. b.UserId) or (b.UserId .. ":" .. a.UserId)
	if freundeCache[k] == nil then
		local ok, ja = pcall(function() return a:IsFriendsWith(b.UserId) end)
		freundeCache[k] = ok and ja == true
	end
	return freundeCache[k]
end
local function freundeNeu()
	local alle = Players:GetPlayers()
	for _, p in alle do
		local hat = false
		for _, q in alle do
			if q ~= p and freunde(p, q) then hat = true break end
		end
		if (p:GetAttribute("FreundeBonus") == true) ~= hat then
			p:SetAttribute("FreundeBonus", hat or nil)
			if hat then ctx.fahrEvent:FireClient(p, { typ = "belohnung", text = "🤝 A friend is here: +10 % coins and XP while you play together!" }) end
			if ctx.Shop then ctx.Shop.attribute(p) end
		end
	end
end
Belohnungen.freundeNeu = freundeNeu

function Belohnungen.spielerDa(p)
	if Belohnungen.GRUPPE_ID ~= 0 then
		local ok, drin = pcall(function() return p:IsInGroup(Belohnungen.GRUPPE_ID) end)
		p:SetAttribute("InGruppe", ok and drin or nil)
	end
	for _ = 1, 40 do
		if ctx.daten[p] then break end
		task.wait(0.25)
	end
	if not ctx.daten[p] then return end
	freundeNeu()
	markieren(p)
	-- daily reward waiting -> the client opens the rewards window
	if taeglichInfo(ctx.daten[p]).bereit then
		ctx.fahrEvent:FireClient(p, { typ = "taeglich" })
	end
end

-- called every few seconds for every player: playtime, friend minutes, "reward ready" messages
function Belohnungen.takt(p, sekunden)
	local d = ctx.daten[p]
	if not d then return end
	local sz = spielzeit(d)
	local vorher = sz.sek
	sz.sek += sekunden
	if p:GetAttribute("FreundeBonus") then d.freundeSek = (d.freundeSek or 0) + sekunden end
	for _, s in Belohnungen.SPIELZEIT do
		if vorher < s.min * 60 and sz.sek >= s.min * 60 then
			ctx.fahrEvent:FireClient(p, { typ = "belohnung", text = ("🎁 Playtime gift ready (%d min)! Open 🎁 Rewards."):format(s.min) })
		end
	end
	local alt = p:GetAttribute("BelohnungenOffen") or 0
	local neu = Belohnungen.offen(p)
	if neu > alt then
		-- a new achievement tier is ready?
		for _, e in Belohnungen.ERFOLGE do
			local wert, abgeholt = erfolgStand(d, e)
			local s = e.stufen[abgeholt + 1]
			local gemeldet = d.erfolgGemeldet or {}
			d.erfolgGemeldet = gemeldet
			if s and wert >= s[1] and gemeldet[e.id] ~= abgeholt + 1 then
				gemeldet[e.id] = abgeholt + 1
				ctx.fahrEvent:FireClient(p, { typ = "belohnung", text = ("%s Achievement ready: %s (tier %d)"):format(e.icon, e.name, abgeholt + 1) })
			end
		end
	end
	p:SetAttribute("BelohnungenOffen", neu)
end

function Belohnungen.starten(c)
	ctx = c
	Players.PlayerAdded:Connect(function(p) task.spawn(Belohnungen.spielerDa, p) end)
	for _, p in Players:GetPlayers() do task.spawn(Belohnungen.spielerDa, p) end
	Players.PlayerRemoving:Connect(function()
		task.defer(freundeNeu)
	end)
	task.spawn(function()
		while true do
			task.wait(10)
			for _, p in Players:GetPlayers() do
				Belohnungen.takt(p, 10)
			end
		end
	end)
end

return Belohnungen
