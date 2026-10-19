-- v54 Beta tools (server): onboarding funnel v2, custom analytics events, promo codes,
-- friend invites with a one-time reward, and the 🧑‍🏫 Instructor mode light
-- (a friend riding along gives LEFT / STRAIGHT / RIGHT commands and rates the driver with stars).
-- Everything the client sends is checked here: never trust the client.
local Players = game:GetService("Players")
local AnalyticsService = game:GetService("AnalyticsService")

local Beta = {}
local ctx

-- ---------------------------------------------------------------
-- Onboarding funnel (Creator Dashboard -> Analytics -> Funnels). Order matters, names are shown there.
-- New field d.funnel2 (the old d.funnel had a different step list).
-- ---------------------------------------------------------------
Beta.FUNNEL = {
	"Joined", "Map loaded", "Sat in the first lesson car", "First checkpoint passed", "First chaos event",
	"First lesson done", "Third lesson done", "All lessons done", "Driver's license", "First own car",
}
local FUNNEL_NR = {}
for i, n in Beta.FUNNEL do FUNNEL_NR[n] = i end

function Beta.funnel(p, name)
	local d = ctx and ctx.daten[p]
	local nr = FUNNEL_NR[name]
	if not d or not nr then return false end
	d.funnel2 = d.funnel2 or {}
	local key = tostring(nr)
	if d.funnel2[key] then return false end
	d.funnel2[key] = true
	pcall(function() AnalyticsService:LogOnboardingFunnelStepEvent(p, nr, name) end)
	return true
end

-- custom events (Analytics -> Custom events); value is optional
function Beta.ereignis(p, name, wert)
	pcall(function() AnalyticsService:LogCustomEvent(p, name, wert or 1) end)
end

-- the client reports when the map around the player has arrived (seconds since joining)
local geladenGemeldet = setmetatable({}, { __mode = "k" })
function Beta.kartenGeladen(p, sekunden)
	if geladenGemeldet[p] then return { ok = true } end
	geladenGemeldet[p] = true
	sekunden = math.clamp(math.floor(tonumber(sekunden) or 0), 0, 600)
	Beta.funnel(p, "Map loaded")
	Beta.ereignis(p, "Map load seconds", sekunden)
	return { ok = true }
end

-- ---------------------------------------------------------------
-- Promo codes (share them on TikTok / Discord / in the game description). Case does not matter.
-- Each code works once per player. Remove a code here to switch it off.
-- ---------------------------------------------------------------
Beta.CODES = {
	BETA = { geld = 1000, text = "Thanks for testing the beta! +1,000 coins" },
	BANANA = { geld = 500, xp = 100, text = "🍌 Slippery! +500 coins and +100 XP" },
	CHAOS = { geld = 750, text = "🐄 Moo! +750 coins" },
}
local codeZeit = setmetatable({}, { __mode = "k" })
function Beta.code(p, text)
	local d = ctx.daten[p]
	if not d then return { fehler = "Your data is still loading." } end
	if type(text) ~= "string" or #text > 24 then return { fehler = "That code doesn't exist." } end
	if os.clock() - (codeZeit[p] or -10) < 2 then return { fehler = "Slow down a little." } end
	codeZeit[p] = os.clock()
	local key = text:upper():gsub("%s", "")
	local c = Beta.CODES[key]
	if not c then return { fehler = "That code doesn't exist (or has expired)." } end
	d.codes = d.codes or {}
	if d.codes[key] then return { fehler = "You already used this code." } end
	d.codes[key] = true
	if c.geld then ctx.geldGeben(p, c.geld, "Code " .. key, true) end
	if c.xp then ctx.xpGeben(p, c.xp, "Code " .. key, true) end
	ctx.geaendert(p)
	Beta.ereignis(p, "Code redeemed")
	return { text = c.text }
end

-- ---------------------------------------------------------------
-- Friend invites: the inviter gets a reward when a NEW player joins through the invite (once per friend),
-- the new player gets a welcome gift. Roblox fills ReferredByPlayerId when someone joins via an invite.
-- ---------------------------------------------------------------
Beta.WERBUNG_BONUS = 750
Beta.WERBUNG_MAX = 20 -- rewarded invites per player in total

function Beta.beigetreten(p, neu)
	local d = ctx.daten[p]
	if not d then return end
	local ok, join = pcall(function() return p:GetJoinData() end)
	local von = ok and type(join) == "table" and tonumber(join.ReferredByPlayerId) or 0
	if not neu or von <= 0 or von == p.UserId or (d.geworbenVon or 0) ~= 0 then return end
	d.geworbenVon = von
	ctx.geldGeben(p, Beta.WERBUNG_BONUS, "Welcome gift from your friend", true)
	ctx.fahrEvent:FireClient(p, { typ = "chaos", titel = "🎁 WELCOME GIFT!", text = ("Your friend invited you: +%d coins!"):format(Beta.WERBUNG_BONUS), farbe = "gruen" })
	Beta.ereignis(p, "Joined from invite")
	local werber = Players:GetPlayerByUserId(von)
	local dw = werber and ctx.daten[werber]
	if dw and (dw.werbungen or 0) < Beta.WERBUNG_MAX then
		dw.werbungen = (dw.werbungen or 0) + 1
		ctx.geldGeben(werber, Beta.WERBUNG_BONUS, "Friend joined", true)
		ctx.fahrEvent:FireClient(werber, { typ = "chaos", titel = "🎉 " .. p.DisplayName:upper() .. " JOINED!", text = ("Thanks for the invite: +%d coins!"):format(Beta.WERBUNG_BONUS), farbe = "gruen" })
		ctx.geaendert(werber)
	end
	ctx.geaendert(p)
end

-- the client opened the invite window (counted for analytics only)
function Beta.eingeladen(p)
	Beta.ereignis(p, "Invite opened")
	return { ok = true }
end

-- ---------------------------------------------------------------
-- 🧑‍🏫 Instructor mode light: a friend riding along gives commands, the driver sees them big on screen.
-- Only fixed commands (no free text = nothing to moderate, works without chat).
-- ---------------------------------------------------------------
Beta.KOMMANDOS = {
	links = { "⬅ LEFT!", "gelb" },
	gerade = { "⬆ STRAIGHT ON!", "gelb" },
	rechts = { "RIGHT! ➡", "gelb" },
	stopp = { "✋ STOP!", "rot" },
	langsam = { "🐢 SLOW DOWN!", "rot" },
	super = { "👍 NICE DRIVING!", "gruen" },
}
Beta.PAUSE = 0.7         -- seconds between two commands of the same instructor
Beta.STERNE_GELD = 8     -- coins per star for the driver
Beta.MIN_KOMMANDOS = 3   -- commands needed before a rating gives coins (no farming in a parked car)

local letzteZeit = setmetatable({}, { __mode = "k" })
local kommandoZahl = setmetatable({}, { __mode = "k" }) -- [instructor] = commands since the last rating

-- returns the driver (a player) if p rides along in somebody else's car right now
local function fahrerVon(p)
	local f, faehrt = ctx.Chaos.autoVon(p)
	if not f or faehrt or not f.p or f.p == p or not f.p.Parent then return nil end
	local fahrerHum = f.p.Character and f.p.Character:FindFirstChildOfClass("Humanoid")
	local s = fahrerHum and fahrerHum.SeatPart
	if not (s and s:IsA("VehicleSeat") and f.model and s:IsDescendantOf(f.model)) then return nil end
	return f.p
end
Beta.fahrerVon = fahrerVon

function Beta.kommando(p, art)
	local def = type(art) == "string" and Beta.KOMMANDOS[art]
	if not def then return { fehler = "Unknown command." } end
	local fahrer = fahrerVon(p)
	if not fahrer then return { fehler = "Ride along in a friend's car to be the instructor!" } end
	if os.clock() - (letzteZeit[p] or -10) < Beta.PAUSE then return { ok = true, zuSchnell = true } end
	letzteZeit[p] = os.clock()
	kommandoZahl[p] = (kommandoZahl[p] or 0) + 1
	ctx.fahrEvent:FireClient(fahrer, { typ = "kommando", art = art, text = def[1], farbe = def[2], von = p.DisplayName })
	if kommandoZahl[p] == 1 then Beta.ereignis(p, "Instructor command") end
	return { ok = true }
end

function Beta.bewerten(p, sterne)
	sterne = math.floor(tonumber(sterne) or 0)
	if sterne < 1 or sterne > 5 then return { fehler = "Pick 1 to 5 stars." } end
	local fahrer = fahrerVon(p)
	if not fahrer then return { fehler = "You can only rate the driver while riding along." } end
	if (kommandoZahl[p] or 0) < Beta.MIN_KOMMANDOS then
		return { fehler = ("Give at least %d commands first – be a real instructor!"):format(Beta.MIN_KOMMANDOS) }
	end
	kommandoZahl[p] = 0
	local df = ctx.daten[fahrer]
	if df then
		df.bewertung = df.bewertung or { summe = 0, anzahl = 0 }
		df.bewertung.summe += sterne
		df.bewertung.anzahl += 1
	end
	ctx.geldGeben(fahrer, sterne * Beta.STERNE_GELD, "Rating from " .. p.DisplayName)
	ctx.fahrEvent:FireClient(fahrer, { typ = "chaos", titel = string.rep("⭐", sterne), text = ("%s rated your driving!"):format(p.DisplayName), farbe = sterne >= 3 and "gruen" or "rot" })
	Beta.ereignis(p, "Instructor rating", sterne)
	return { text = ("You gave %s %d star%s."):format(fahrer.DisplayName, sterne, sterne == 1 and "" or "s") }
end

function Beta.starten(k)
	ctx = k
end

return Beta
