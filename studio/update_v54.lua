-- v51 -> v54 in einem Rutsch: v52 (Polizei aus) + v54 (Streaming-Fix, Beta-Module, Fahrlehrer-Modus, Codes, Einladen).
-- In Studio im EDIT-Modus in die Befehlszeile einfügen und Enter. Danach speichern (Strg+S) und veröffentlichen.
-- (Am 19.10. per MCP schon eingespielt – nur für einen frischen v51-Place nötig.)
-- v51 -> v52 (keine Polizei). In Studio im EDIT-Modus in die Befehlszeile einfügen und Enter.
do
local function ersetze(src, alt, neu)
	local a, b = string.find(src, alt, 1, true)
	assert(a, "nicht gefunden: " .. alt:sub(1, 60))
	assert(not string.find(src, alt, b + 1, true), "mehrfach: " .. alt:sub(1, 60))
	return src:sub(1, a - 1) .. neu .. src:sub(b + 1)
end
local s = game.ServerScriptService.FuehrerscheinServer
local src = s.Source
assert(#src == 138618, "Ausgangsstand passt nicht: " .. #src)
src = ersetze(src, [===[
-- Police: traffic checkpoints (for you and the NPC traffic) and patrol cars that stop speeders
-- ---------------------------------------------------------------
]===], [===[
-- Police: traffic checkpoints (for you and the NPC traffic) and patrol cars that stop speeders
-- v52: switched OFF (Lukas: no police in the game). Speed cameras, fines and points stay (Strafen.lua).
-- Set POLIZEI_AKTIV = true (and Verkehr.POLIZEI = true) to bring it back.
-- ---------------------------------------------------------------
]===])
src = ersetze(src, [===[
-- ---------------------------------------------------------------
local KONTROLL_PUNKTE = {
]===], [===[
-- ---------------------------------------------------------------
local POLIZEI_AKTIV = false
local KONTROLL_PUNKTE = {
]===])
src = ersetze(src, [===[
task.spawn(function()
	task.wait(45)
]===], [===[
task.spawn(function()
	if not POLIZEI_AKTIV then return end
	task.wait(45)
]===])
src = ersetze(src, [===[
RunService.Heartbeat:Connect(function(dt)
	polizeiTakt += dt
]===], [===[
RunService.Heartbeat:Connect(function(dt)
	if not POLIZEI_AKTIV then return end
	polizeiTakt += dt
]===])
assert(#src == 138902, "Ergebnis-Länge falsch: " .. #src)
s.Source = src
print(s.Name .. ": " .. #src .. " Zeichen")
end
do
local function ersetze(src, alt, neu)
	local a, b = string.find(src, alt, 1, true)
	assert(a, "nicht gefunden: " .. alt:sub(1, 60))
	assert(not string.find(src, alt, b + 1, true), "mehrfach: " .. alt:sub(1, 60))
	return src:sub(1, a - 1) .. neu .. src:sub(b + 1)
end
local s = game.StarterPlayer.StarterPlayerScripts.FuehrerscheinClient
local src = s.Source
assert(#src == 190443, "Ausgangsstand passt nicht: " .. #src)
src = ersetze(src, [===[
local spieler = Players.LocalPlayer
print("[Driving School] client v51 loaded")
local ordner = RS:WaitForChild("Fuehrerschein")
]===], [===[
local spieler = Players.LocalPlayer
print("[Driving School] client v52 loaded")
local ordner = RS:WaitForChild("Fuehrerschein")
]===])
src = ersetze(src, [===[
					{ "Retraining course", "Speeding is the most common cause of accidents.\n\n• Always watch the speed limit sign on your speedometer.\n• Speed cameras measure in <b>both directions</b>.\n• Every offence brings <b>penalty points</b>; at <b>8 points</b> the license is gone again." },
					{ "Retraining course", "• Red light = stop. Always.\n• Stop for the police when they signal you.\n• Points expire over time if you drive safely.\n\nNow book your new driving test with Anna!" },
				}
]===], [===[
					{ "Retraining course", "Speeding is the most common cause of accidents.\n\n• Always watch the speed limit sign on your speedometer.\n• Speed cameras measure in <b>both directions</b>.\n• Every offence brings <b>penalty points</b>; at <b>8 points</b> the license is gone again." },
					{ "Retraining course", "• Red light = stop. Always.\n• Speed cameras are everywhere – watch the limit.\n• Points expire over time if you drive safely.\n\nNow book your new driving test with Anna!" },
				}
]===])
src = ersetze(src, [===[
do
	print("[Driving School] start screen v51 loading")
	local menue = Instance.new("ScreenGui")
]===], [===[
do
	print("[Driving School] start screen v52 loading")
	local menue = Instance.new("ScreenGui")
]===])
assert(#src == 190451, "Ergebnis-Länge falsch: " .. #src)
s.Source = src
print(s.Name .. ": " .. #src .. " Zeichen")
end
do
local function ersetze(src, alt, neu)
	local a, b = string.find(src, alt, 1, true)
	assert(a, "nicht gefunden: " .. alt:sub(1, 60))
	assert(not string.find(src, alt, b + 1, true), "mehrfach: " .. alt:sub(1, 60))
	return src:sub(1, a - 1) .. neu .. src:sub(b + 1)
end
local s = game.ReplicatedStorage.Fuehrerschein.Verkehr
local src = s.Source
assert(#src == 31268, "Ausgangsstand passt nicht: " .. #src)
src = ersetze(src, [===[
local Verkehr = {}

]===], [===[
local Verkehr = {}
Verkehr.POLIZEI = false -- v52: no police cars in the traffic (Lukas)

]===])
src = ersetze(src, [===[
			end
			if i == 1 and (r == 1 or r == 4) then art = "polizei" end -- two patrol cars
			local f = {
]===], [===[
			end
			if Verkehr.POLIZEI and i == 1 and (r == 1 or r == 4) then art = "polizei" end -- two patrol cars (v52: off)
			local f = {
]===])
assert(#src == 31369, "Ergebnis-Länge falsch: " .. #src)
s.Source = src
print(s.Name .. ": " .. #src .. " Zeichen")
end
do
local function ersetze(src, alt, neu)
	local a, b = string.find(src, alt, 1, true)
	assert(a, "nicht gefunden: " .. alt:sub(1, 60))
	assert(not string.find(src, alt, b + 1, true), "mehrfach: " .. alt:sub(1, 60))
	return src:sub(1, a - 1) .. neu .. src:sub(b + 1)
end
local s = game.ServerScriptService.FuehrerscheinServer.Missionen
local src = s.Source
assert(#src == 7433, "Ausgangsstand passt nicht: " .. #src)
src = ersetze(src, [===[
	{ id = "km", text = "Drive %d km in your own car", ziele = { 2, 3, 5 }, geld = 200, xp = 80 },
	{ id = "kontrolle", text = "Pass a police check without a fine", ziele = { 1 }, geld = 150, xp = 60 },
	{ id = "tanken", text = "Refuel your car at a gas station", ziele = { 1 }, geld = 100, xp = 40 },
]===], [===[
	{ id = "km", text = "Drive %d km in your own car", ziele = { 2, 3, 5 }, geld = 200, xp = 80 },
	{ id = "tanken", text = "Refuel your car at a gas station", ziele = { 1 }, geld = 100, xp = 40 },
]===])
src = ersetze(src, [===[

local function aktuell(p)
]===], [===[

local function art(id)
	for _, a in Missionen.ARTEN do
		if a.id == id then return a end
	end
end

local function aktuell(p)
]===])
src = ersetze(src, [===[
	end
	return d.missionen
]===], [===[
	end
	-- v52: a mission type was removed (police check) -> today's list gets rolled again
	for _, m in d.missionen.liste do
		if not art(m.id) then d.missionen = neueListe(p) break end
	end
	return d.missionen
]===])
src = ersetze(src, [===[
	return d.missionen
end

local function art(id)
	for _, a in Missionen.ARTEN do
		if a.id == id then return a end
	end
end
]===], [===[
	return d.missionen
end
]===])
assert(#src == 7514, "Ergebnis-Länge falsch: " .. #src)
s.Source = src
print(s.Name .. ": " .. #src .. " Zeichen")
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
assert(#src == 138902, "Ausgangsstand passt nicht: " .. #src)
src = ersetze(src, [===[
local Party = require(script:WaitForChild("Party"))
local Hupen = require(ordner:WaitForChild("Hupen"))
]===], [===[
local Party = require(script:WaitForChild("Party"))
local Beta = require(script:WaitForChild("Beta"))
local Hupen = require(ordner:WaitForChild("Hupen"))
]===])
src = ersetze(src, [===[
		sterne = {}, funnel = {},
	}
]===], [===[
		sterne = {}, funnel = {},
		-- v54: funnel v2, used promo codes, invited by (UserId), rewarded invites, driving ratings from friends
		funnel2 = {}, codes = {}, geworbenVon = 0, werbungen = 0, bewertung = { summe = 0, anzahl = 0 },
	}
]===])
src = ersetze(src, [===[

-- Onboarding funnel for the Roblox creator dashboard (Analytics -> Funnels): shows where new players stop.
-- Every step is reported once per player; only works in the published game (in Studio it is just skipped).
local AnalyticsService = game:GetService("AnalyticsService")
local FUNNEL = {
	"Joined", "Sat in the first lesson car", "First lesson done", "Third lesson done", "All lessons done",
	"Theory test passed", "Driver's license", "First own car", "First job done",
}
]===], [===[

-- Onboarding funnel (v54: new step list in Beta.lua). The old step numbers used in this file are mapped here;
-- steps that are no longer part of the main path (theory is optional, jobs) are custom events instead.
local FUNNEL_ALT = {
	[1] = "Joined", [2] = "Sat in the first lesson car", [3] = "First lesson done", [4] = "Third lesson done",
	[5] = "All lessons done", [7] = "Driver's license", [8] = "First own car",
}
]===])
src = ersetze(src, [===[
}
local function funnel(p, schritt)
]===], [===[
}
local EREIGNIS_ALT = { [6] = "Theory test passed", [9] = "First job done" }
local function funnel(p, schritt)
]===])
src = ersetze(src, [===[
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
]===], [===[
local function funnel(p, schritt)
	if FUNNEL_ALT[schritt] then
		Beta.funnel(p, FUNNEL_ALT[schritt])
	elseif EREIGNIS_ALT[schritt] then
		local d = daten[p]
		if not d then return end
		d.funnel2 = d.funnel2 or {}
		local key = "e" .. schritt
		if d.funnel2[key] then return end
		d.funnel2[key] = true
		Beta.ereignis(p, EREIGNIS_ALT[schritt])
	end
end
]===])
src = ersetze(src, [===[
	fahrEvent:FireClient(p, { typ = "geld", betrag = betrag, grund = grund })
end

local fuehrerscheinGeben -- defined further down
]===], [===[
	fahrEvent:FireClient(p, { typ = "geld", betrag = betrag, grund = grund })
end
Beta.starten({ daten = daten, geldGeben = geldGeben, xpGeben = xpGeben, geaendert = geaendert, fahrEvent = fahrEvent, Chaos = Chaos })

local fuehrerscheinGeben -- defined further down
]===])
src = ersetze(src, [===[
	p:SetAttribute("Admin", istAdmin(p) or nil)
	daten[p] = laden(p)
	funnel(p, 1)
]===], [===[
	p:SetAttribute("Admin", istAdmin(p) or nil)
	local d = laden(p)
	daten[p] = d
	funnel(p, 1)
]===])
src = ersetze(src, [===[
	funnel(p, 1)
	anzeigen(p)
]===], [===[
	funnel(p, 1)
	-- brand-new player (nothing saved yet)? then a friend's invite gives both a reward
	Beta.beigetreten(p, (d.xp or 0) == 0 and (d.fahrstunden or 0) == 0 and not d.angemeldet and not d.fuehrerschein)
	anzeigen(p)
]===])
src = ersetze(src, [===[
				st.stoppHinweis = false
				Chaos.reaktion(p, st, "lob")
]===], [===[
				st.stoppHinweis = false
				if st.nr == 1 and not st.pruefung then Beta.funnel(p, "First checkpoint passed") end
				Chaos.reaktion(p, st, "lob")
]===])
src = ersetze(src, [===[

	elseif was == "fahrstundeAbbrechen" then
]===], [===[

	-- v54 beta tools (checked in Beta.lua)
	elseif was == "code" then
		return Beta.code(p, eingabe)
	elseif was == "kartenGeladen" then
		return Beta.kartenGeladen(p, eingabe)
	elseif was == "eingeladen" then
		return Beta.eingeladen(p)
	elseif was == "kommando" then
		return Beta.kommando(p, eingabe)
	elseif was == "bewerten" then
		return Beta.bewerten(p, eingabe)

	elseif was == "fahrstundeAbbrechen" then
]===])
src = ersetze(src, [===[
Chaos.starten({ fahrEvent = fahrEvent, geldGeben = geldGeben, lektionen = lektionen, jobs = jobs, privatAutos = privatAutos,
	daten = daten, geaendert = geaendert, Shop = Shop, Missionen = Missionen, Hupen = Hupen })
Party.starten({ fahrEvent = fahrEvent, geldGeben = geldGeben, xpGeben = xpGeben, Chaos = Chaos,
]===], [===[
Chaos.starten({ fahrEvent = fahrEvent, geldGeben = geldGeben, lektionen = lektionen, jobs = jobs, privatAutos = privatAutos,
	daten = daten, geaendert = geaendert, Shop = Shop, Missionen = Missionen, Hupen = Hupen,
	onEvent = function(p) Beta.funnel(p, "First chaos event") end })
Party.starten({ fahrEvent = fahrEvent, geldGeben = geldGeben, xpGeben = xpGeben, Chaos = Chaos,
]===])
assert(#src == 140079, "Ergebnis-Länge falsch: " .. #src)
s.Source = src
print(s.Name .. ": " .. #src .. " Zeichen")
end

do
local function ersetze(src, alt, neu)
	local a, b = string.find(src, alt, 1, true)
	assert(a, "nicht gefunden: " .. alt:sub(1, 60))
	assert(not string.find(src, alt, b + 1, true), "mehrfach: " .. alt:sub(1, 60))
	return src:sub(1, a - 1) .. neu .. src:sub(b + 1)
end
local s = game.StarterPlayer.StarterPlayerScripts.FuehrerscheinClient
local src = s.Source
assert(#src == 190451, "Ausgangsstand passt nicht: " .. #src)
src = ersetze(src, [===[
local spieler = Players.LocalPlayer
print("[Driving School] client v52 loaded")
local ordner = RS:WaitForChild("Fuehrerschein")
]===], [===[
local spieler = Players.LocalPlayer
print("[Driving School] client v54 loaded")
local ordner = RS:WaitForChild("Fuehrerschein")
]===])
src = ersetze(src, [===[

-- 📯 somebody honked: sound from the car + a "HONK!" bubble over it for everybody nearby
]===], [===[

-- v54 beta: invite friends, report "map loaded", 🧑‍🏫 instructor mode light (own module: this script is near Roblox' 200,000-character limit)
local BetaClient = require(ordner:WaitForChild("BetaClient")).starten({
	spieler = spieler, frage = frage, warnen = warnen, GRUEN = GRUEN, BLAU = BLAU,
})

-- 📯 somebody honked: sound from the car + a "HONK!" bubble over it for everybody nearby
]===])
src = ersetze(src, [===[
		chaosBanner(info)
	elseif info.typ == "hupe" then
]===], [===[
		chaosBanner(info)
	elseif info.typ == "kommando" then
		BetaClient.kommandoZeigen(info)
	elseif info.typ == "hupe" then
]===])
src = ersetze(src, [===[
		end
		zeige(titelText, info.text .. ("\n\nMistakes: %d"):format(info.fehler or 0) .. sterneText .. (info.erfolg and ("\n\n" .. (info.weiter or "Talk to Anna at the reception for your next lesson.")) or ""), knoepfe, "hinweis")
	end
]===], [===[
		end
		-- v54: funny "certificate" title – made for screenshots
		local f = info.fehler or 0
		local titel = (not info.erfolg and f >= 10) and "💥 Licensed Menace"
			or (not info.erfolg) and "🚧 Danger to Society (in training)"
			or f == 0 and "😇 Certified Road Angel"
			or f <= 2 and "🚗 Mostly Harmless"
			or f <= 5 and "🍌 Professional Banana Dodger"
			or "🐄 Cow Whisperer"
		local zeugnis = ("\n\n<font size=\"13\" color=\"#9aa4b5\">OFFICIAL RESULT FOR %s</font>\n<font size=\"22\" color=\"#ffd23c\"><b>%s</b></font>"):format(spieler.DisplayName:upper(), titel)
		zeige(titelText, info.text .. ("\n\nMistakes: %d"):format(f) .. sterneText .. zeugnis .. (info.erfolg and ("\n\n" .. (info.weiter or "Talk to Anna at the reception for your next lesson.")) or ""), knoepfe, "hinweis")
	end
]===])
src = ersetze(src, [===[
	local lampen = {}
	local karte = workspace:WaitForChild("Karte")
	local function merken(x)
		if x:IsA("PointLight") and x.Parent and x.Parent.Name == "Leuchte" then lampen[x] = true end
	end
	for _, x in karte:GetDescendants() do merken(x) end
	karte.DescendantAdded:Connect(merken)
	karte.DescendantRemoving:Connect(function(x) lampen[x] = nil end)
	task.spawn(function()
]===], [===[
	local lampen = {}
	task.spawn(function()
		-- never block the rest of the client: with streaming the map may arrive late
		local karte = workspace:WaitForChild("Karte", 60)
		if not karte then return end
		local function merken(x)
			if x:IsA("PointLight") and x.Parent and x.Parent.Name == "Leuchte" then lampen[x] = true end
		end
		for i, x in karte:GetDescendants() do
			merken(x)
			if i % 4000 == 0 then task.wait() end
		end
		karte.DescendantAdded:Connect(merken)
		karte.DescendantRemoving:Connect(function(x) lampen[x] = nil end)
	end)
	task.spawn(function()
]===])
src = ersetze(src, [===[
einstellRahmen.Position = UDim2.fromScale(0.5, 0.5)
einstellRahmen.Size = UDim2.fromOffset(380, 484)
einstellRahmen.BackgroundColor3 = Color3.fromRGB(25, 30, 40)
]===], [===[
einstellRahmen.Position = UDim2.fromScale(0.5, 0.5)
einstellRahmen.Size = UDim2.fromOffset(380, 534)
einstellRahmen.BackgroundColor3 = Color3.fromRGB(25, 30, 40)
]===])
src = ersetze(src, [===[
	hupeAbspielen(hrp, neu) -- preview
	task.spawn(frage, "einstellungen", _G.Einstellungen)
end)
local function knoepfeAktualisieren()
]===], [===[
	hupeAbspielen(hrp, neu) -- preview
	task.spawn(frage, "einstellungen", _G.Einstellungen)
end)
-- 🎟️ promo codes (v54): checked on the server, each code once per player
local codeFeld = Instance.new("TextBox")
codeFeld.Position = UDim2.fromOffset(20, 60 + (#OPTIONEN + 1) * 50)
codeFeld.Size = UDim2.fromOffset(200, 32)
codeFeld.BackgroundColor3 = Color3.fromRGB(45, 52, 66)
codeFeld.Font = Enum.Font.GothamBold
codeFeld.TextSize = 15
codeFeld.TextColor3 = Color3.new(1, 1, 1)
codeFeld.PlaceholderText = "🎟️ Enter code"
codeFeld.PlaceholderColor3 = Color3.fromRGB(150, 158, 175)
codeFeld.Text = ""
codeFeld.ClearTextOnFocus = false
codeFeld.Parent = einstellRahmen
Instance.new("UICorner", codeFeld)
local codeKnopf = Instance.new("TextButton")
codeKnopf.Position = UDim2.fromOffset(230, 60 + (#OPTIONEN + 1) * 50)
codeKnopf.Size = UDim2.fromOffset(130, 32)
codeKnopf.Font = Enum.Font.GothamBold
codeKnopf.TextSize = 15
codeKnopf.TextColor3 = Color3.new(1, 1, 1)
codeKnopf.BackgroundColor3 = GRUEN
codeKnopf.Text = "Redeem"
codeKnopf.Parent = einstellRahmen
Instance.new("UICorner", codeKnopf)
codeKnopf.MouseButton1Click:Connect(function()
	local text = codeFeld.Text
	if text == "" then return end
	local r = frage("code", text)
	if r.fehler then
		warnen("🎟️ " .. r.fehler, Color3.fromRGB(200, 140, 30))
	else
		codeFeld.Text = ""
		warnen("🎟️ " .. (r.text or "Code redeemed!"), GRUEN)
	end
end)
local function knoepfeAktualisieren()
]===])
src = ersetze(src, [===[
		table.insert(zeilen, (spieler:GetAttribute("FreundeBonus") and "🤝 Friend online: +10 % ✓" or "🤝 Play with a friend: +10 %"))
		table.insert(zeilen, ((spieler:GetAttribute("BoostBis") or 0) > os.time() and ("⚡ 2x boost: %d min left"):format(math.ceil(((spieler:GetAttribute("BoostBis") or 0) - os.time()) / 60)) or "⚡ 2x boost: <font color=\"#8a90a0\">off</font>"))
]===], [===[
		table.insert(zeilen, (spieler:GetAttribute("FreundeBonus") and "🤝 Friend online: +10 % ✓" or "🤝 Play with a friend: +10 %"))
		table.insert(zeilen, "📨 New friend joins via invite: <b>+750</b> for both")
		table.insert(zeilen, ((spieler:GetAttribute("BoostBis") or 0) > os.time() and ("⚡ 2x boost: %d min left"):format(math.ceil(((spieler:GetAttribute("BoostBis") or 0) - os.time()) / 60)) or "⚡ 2x boost: <font color=\"#8a90a0\">off</font>"))
]===])
src = ersetze(src, [===[
		taste(k3, "📨 INVITE FRIENDS", BLAU, { 0.6, 0 }, { 0, 56 }, { 0.4, -12 }, { 0, 32 }, function()
			pcall(function() SocialService:PromptGameInvite(spieler) end)
		end)
]===], [===[
		taste(k3, "📨 INVITE FRIENDS", BLAU, { 0.6, 0 }, { 0, 56 }, { 0.4, -12 }, { 0, 32 }, function()
			if _G.FreundeEinladen then _G.FreundeEinladen() end
		end)
]===])
src = ersetze(src, [===[
do
	print("[Driving School] start screen v52 loading")
	local menue = Instance.new("ScreenGui")
]===], [===[
do
	print("[Driving School] start screen v54 loading")
	local menue = Instance.new("ScreenGui")
]===])
assert(#src == 192997, "Ergebnis-Länge falsch: " .. #src)
s.Source = src
print(s.Name .. ": " .. #src .. " Zeichen")
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
assert(#src == 51423, "Ausgangsstand passt nicht: " .. #src)
src = ersetze(src, [===[
	statistik(p, "arten", art)
	if ev.ohneObjekt then
]===], [===[
	statistik(p, "arten", art)
	if ctx and ctx.onEvent then pcall(ctx.onEvent, p) end -- analytics funnel (v54)
	if ev.ohneObjekt then
]===])
assert(#src == 51504, "Ergebnis-Länge falsch: " .. #src)
s.Source = src
print(s.Name .. ": " .. #src .. " Zeichen")
end

do
local S = game.ServerScriptService.FuehrerscheinServer
local m = S:FindFirstChild("Beta") or Instance.new("ModuleScript")
m.Name = "Beta"
m.Source = [===[
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
]===]
m.Parent = S
print("Beta: " .. #m.Source .. " Zeichen")
end

do
local S = game.ReplicatedStorage.Fuehrerschein
local m = S:FindFirstChild("BetaClient") or Instance.new("ModuleScript")
m.Name = "BetaClient"
m.Source = [===[
-- v54 beta (client): invite friends, report "map loaded", 🧑‍🏫 instructor mode light.
-- Required by FuehrerscheinClient (kept separate because that script is close to Roblox' 200,000-character limit).
local Players = game:GetService("Players")
local BetaClient = {}

function BetaClient.starten(k)
	local spieler, frage, warnen, GRUEN, BLAU = k.spieler, k.frage, k.warnen, k.GRUEN, k.BLAU
	-- 📨 invite friends (Roblox checks if this account may send invites; the server rewards new friends who join)
	_G.FreundeEinladen = function()
		local Social = game:GetService("SocialService")
		local okKann, kann = pcall(function() return Social:CanSendGameInviteAsync(spieler) end)
		if not okKann or not kann then
			warnen("📨 Invites are not available for your account right now.", Color3.fromRGB(200, 140, 30))
			return
		end
		local ok = pcall(function()
			local opt = Instance.new("ExperienceInviteOptions")
			opt.PromptMessage = "Survive the chaos with me in Crazy Driving School!"
			opt.LaunchData = "invite"
			Social:PromptGameInvite(spieler, opt)
		end)
		if not ok then pcall(function() Social:PromptGameInvite(spieler) end) end
		task.spawn(frage, "eingeladen")
	end

	-- 🗺️ analytics: how long until the map around the player has arrived (streaming)
	task.spawn(function()
		local start = os.clock()
		local char = spieler.Character or spieler.CharacterAdded:Wait()
		local hrp = char:WaitForChild("HumanoidRootPart", 60)
		local karte = workspace:WaitForChild("Karte", 60)
		if not hrp or not karte then return end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { karte }
		for _ = 1, 300 do -- max ~5 minutes
			local hrp2 = spieler.Character and spieler.Character:FindFirstChild("HumanoidRootPart")
			if hrp2 and workspace:Raycast(hrp2.Position + Vector3.new(0, 4, 0), Vector3.new(0, -60, 0), params) then
				frage("kartenGeladen", os.clock() - start)
				return
			end
			task.wait(1)
		end
	end)

	-- 🧑‍🏫 the driver sees the commands of a friend riding along: big text at the top
	local kommandoGui = Instance.new("ScreenGui")
	kommandoGui.Name = "FahrlehrerKommando"
	kommandoGui.ResetOnSpawn = false
	kommandoGui.DisplayOrder = 6
	kommandoGui.Parent = spieler.PlayerGui
	local kommandoText = Instance.new("TextLabel")
	kommandoText.AnchorPoint = Vector2.new(0.5, 0)
	kommandoText.Position = UDim2.new(0.5, 0, 0.12, 0)
	kommandoText.Size = UDim2.new(0.6, 0, 0, 70)
	kommandoText.BackgroundTransparency = 1
	kommandoText.Font = Enum.Font.FredokaOne
	kommandoText.TextScaled = true
	kommandoText.TextStrokeTransparency = 0
	kommandoText.Visible = false
	kommandoText.Parent = kommandoGui
	local kommandoVon = Instance.new("TextLabel")
	kommandoVon.AnchorPoint = Vector2.new(0.5, 0)
	kommandoVon.Position = UDim2.new(0.5, 0, 1, 0)
	kommandoVon.Size = UDim2.new(1, 0, 0, 22)
	kommandoVon.BackgroundTransparency = 1
	kommandoVon.Font = Enum.Font.GothamBold
	kommandoVon.TextSize = 18
	kommandoVon.TextColor3 = Color3.fromRGB(230, 235, 245)
	kommandoVon.TextStrokeTransparency = 0.3
	kommandoVon.Parent = kommandoText
	local kommandoSkala = Instance.new("UIScale")
	kommandoSkala.Parent = kommandoText
	local KOMMANDO_FARBEN = { gelb = Color3.fromRGB(255, 210, 40), rot = Color3.fromRGB(255, 80, 80), gruen = Color3.fromRGB(90, 235, 110) }
	local kommandoNr = 0
	local function kommandoZeigen(info)
		kommandoNr += 1
		local nr = kommandoNr
		kommandoText.Text = info.text or ""
		kommandoText.TextColor3 = KOMMANDO_FARBEN[info.farbe] or KOMMANDO_FARBEN.gelb
		kommandoVon.Text = (info.von or "Your friend") .. " (Instructor)"
		kommandoText.Visible = true
		kommandoSkala.Scale = 0.5
		game:GetService("TweenService"):Create(kommandoSkala, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		task.delay(1.8, function()
			if kommandoNr == nr then kommandoText.Visible = false end
		end)
	end

	-- 🧑‍🏫 the friend riding along gets the instructor panel (buttons + keys 1-6, rating with stars)
	do
		local UISF = game:GetService("UserInputService")
		local KNOEPFE = {
			{ "links", "⬅ LEFT", Color3.fromRGB(230, 170, 30) },
			{ "gerade", "⬆ STRAIGHT", Color3.fromRGB(230, 170, 30) },
			{ "rechts", "RIGHT ➡", Color3.fromRGB(230, 170, 30) },
			{ "stopp", "✋ STOP", Color3.fromRGB(200, 60, 60) },
			{ "langsam", "🐢 SLOW", Color3.fromRGB(200, 60, 60) },
			{ "super", "👍 NICE", GRUEN },
		}
		local gui = Instance.new("ScreenGui")
		gui.Name = "Fahrlehrer"
		gui.ResetOnSpawn = false
		gui.Enabled = false
		gui.Parent = spieler.PlayerGui
		local rahmen = Instance.new("Frame")
		rahmen.AnchorPoint = Vector2.new(0.5, 1)
		rahmen.Position = UDim2.new(0.5, 0, 1, -12)
		rahmen.Size = UDim2.fromOffset(6 * 74 + 12, 104)
		rahmen.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
		rahmen.BackgroundTransparency = 0.15
		rahmen.Parent = gui
		Instance.new("UICorner", rahmen).CornerRadius = UDim.new(0, 14)
		local skala = Instance.new("UIScale")
		skala.Parent = rahmen
		local titel = Instance.new("TextLabel")
		titel.Position = UDim2.fromOffset(12, 4)
		titel.Size = UDim2.new(1, -150, 0, 26)
		titel.BackgroundTransparency = 1
		titel.Font = Enum.Font.GothamBlack
		titel.TextSize = 15
		titel.TextColor3 = Color3.fromRGB(255, 210, 40)
		titel.TextXAlignment = Enum.TextXAlignment.Left
		titel.Text = "🧑‍🏫 YOU'RE THE INSTRUCTOR"
		titel.Parent = rahmen
		local function senden(art)
			task.spawn(function()
				local r = frage("kommando", art)
				if r.fehler then warnen(r.fehler, Color3.fromRGB(200, 140, 30)) end
			end)
		end
		for i, k in KNOEPFE do
			local b = Instance.new("TextButton")
			b.Position = UDim2.fromOffset(6 + (i - 1) * 74 + 4, 36)
			b.Size = UDim2.fromOffset(66, 58)
			b.BackgroundColor3 = k[3]
			b.Font = Enum.Font.GothamBlack
			b.TextSize = 13
			b.TextWrapped = true
			b.TextColor3 = Color3.new(1, 1, 1)
			b.Text = k[2] .. "\n" .. i
			b.Parent = rahmen
			Instance.new("UICorner", b)
			b.Activated:Connect(function() senden(k[1]) end)
		end
		-- ⭐ rating: 5 star buttons that appear above the panel
		local sterneRahmen = Instance.new("Frame")
		sterneRahmen.AnchorPoint = Vector2.new(1, 1)
		sterneRahmen.Position = UDim2.new(1, -8, 0, -6)
		sterneRahmen.Size = UDim2.fromOffset(5 * 44 + 8, 50)
		sterneRahmen.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
		sterneRahmen.Visible = false
		sterneRahmen.Parent = rahmen
		Instance.new("UICorner", sterneRahmen).CornerRadius = UDim.new(0, 12)
		for n = 1, 5 do
			local st = Instance.new("TextButton")
			st.Position = UDim2.fromOffset(4 + (n - 1) * 44, 4)
			st.Size = UDim2.fromOffset(42, 42)
			st.BackgroundTransparency = 1
			st.Font = Enum.Font.GothamBlack
			st.TextSize = 30
			st.TextColor3 = Color3.fromRGB(255, 210, 40)
			st.Text = "★"
			st.Parent = sterneRahmen
			st.Activated:Connect(function()
				sterneRahmen.Visible = false
				local r = frage("bewerten", n)
				warnen((r.fehler or r.text or ""), r.fehler and Color3.fromRGB(200, 140, 30) or GRUEN)
			end)
		end
		local bewerten = Instance.new("TextButton")
		bewerten.AnchorPoint = Vector2.new(1, 0)
		bewerten.Position = UDim2.new(1, -10, 0, 5)
		bewerten.Size = UDim2.fromOffset(130, 26)
		bewerten.BackgroundColor3 = BLAU
		bewerten.Font = Enum.Font.GothamBold
		bewerten.TextSize = 13
		bewerten.TextColor3 = Color3.new(1, 1, 1)
		bewerten.Text = "⭐ Rate driver"
		bewerten.Parent = rahmen
		Instance.new("UICorner", bewerten)
		bewerten.Activated:Connect(function() sterneRahmen.Visible = not sterneRahmen.Visible end)

		-- am I riding along in a car that another player drives?
		local function fahrtMit()
			local hum = spieler.Character and spieler.Character:FindFirstChildOfClass("Humanoid")
			local s = hum and hum.SeatPart
			if not s or s:IsA("VehicleSeat") then return false end
			local m = s.Parent
			while m and m ~= workspace do
				if m:IsA("Model") then
					for _, v in m:GetDescendants() do
						if v:IsA("VehicleSeat") and v.Occupant then
							local fp = Players:GetPlayerFromCharacter(v.Occupant.Parent)
							if fp and fp ~= spieler then return true end
						end
					end
				end
				m = m.Parent
			end
			return false
		end
		local TASTEN = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six }
		UISF.InputBegan:Connect(function(eingabe, verarbeitet)
			if verarbeitet or not gui.Enabled then return end
			local i = table.find(TASTEN, eingabe.KeyCode)
			if i then senden(KNOEPFE[i][1]) end
		end)
		task.spawn(function()
			local vorher = false
			while true do
				local jetzt = fahrtMit()
				if jetzt ~= vorher then
					vorher = jetzt
					gui.Enabled = jetzt
					sterneRahmen.Visible = false
					if jetzt then
						warnen("🧑‍🏫 You're the instructor! Tell your friend where to drive (1-6).", GRUEN)
					end
				end
				if jetzt then
					local kam = workspace.CurrentCamera
					local breite = kam and kam.ViewportSize.X or 1000
					skala.Scale = math.clamp((breite - 20) / (6 * 74 + 12), 0.6, 1)
				end
				task.wait(0.5)
			end
		end)
	end
	BetaClient.kommandoZeigen = kommandoZeigen
	return BetaClient
end

return BetaClient
]===]
m.Parent = S
print("BetaClient: " .. #m.Source .. " Zeichen")
end

do
-- v54: Karte laedt im veroeffentlichten Spiel nicht -> Streaming nach Roblox-Empfehlung, keine vereinfachten Detailstufen.
-- In Studio (Edit-Modus) in die Befehlszeile oder per MCP. Mehrfach ausfuehrbar, Strg+Z macht es rueckgaengig.
local CHS = game:GetService("ChangeHistoryService")
CHS:SetWaypoint("Vor Streaming-Fix")
local bericht = {}
for eig, wert in {
	StreamingEnabled = true,
	StreamingTargetRadius = 1024,
	StreamingMinRadius = 64,
	StreamingIntegrityMode = Enum.StreamingIntegrityMode.PauseOutsideLoadedArea,
	StreamOutBehavior = Enum.StreamOutBehavior.Opportunistic,
} do
	local ok = pcall(function() workspace[eig] = wert end)
	table.insert(bericht, eig .. (ok and " gesetzt" or " NICHT setzbar -> bitte im Eigenschaften-Fenster von Workspace setzen: " .. tostring(wert)))
end
local vorher, n = {}, 0
for _, m in workspace:GetDescendants() do
	if m:IsA("Model") then
		local k = tostring(m.LevelOfDetail)
		vorher[k] = (vorher[k] or 0) + 1
		if m.LevelOfDetail ~= Enum.ModelLevelOfDetail.Disabled then
			m.LevelOfDetail = Enum.ModelLevelOfDetail.Disabled
			n += 1
		end
	end
end
local s = {}
for k, v in vorher do table.insert(s, k .. "=" .. v) end
table.insert(bericht, "Detailstufen vorher: " .. table.concat(s, ", ") .. " -> " .. n .. " auf Disabled")
CHS:SetWaypoint("Streaming-Fix")
print(table.concat(bericht, "\n"))

end

print("v54 eingespielt – jetzt speichern (Strg+S) und veröffentlichen")
