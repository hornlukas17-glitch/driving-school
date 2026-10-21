-- v55 -> v56 (Partner finden, Wrong Way, Kühe zuerst). In Studio im EDIT-Modus in die Befehlszeile oder per MCP.
game:GetService("ChangeHistoryService"):SetWaypoint("Vor v56")
do
local function ersetze(src, alt, neu)
	local a, b = string.find(src, alt, 1, true)
	assert(a, "nicht gefunden: " .. alt:sub(1, 60))
	assert(not string.find(src, alt, b + 1, true), "mehrfach: " .. alt:sub(1, 60))
	return src:sub(1, a - 1) .. neu .. src:sub(b + 1)
end
local s = game.ServerScriptService.FuehrerscheinServer
local src = s.Source
assert(#src == 145138, "Ausgangsstand passt nicht: " .. #src)
src = ersetze(src, [===[
		local sek = st.blind.start and math.floor(os.clock() - st.blind.start) or 0
		local team = Beta.blindWertung(st.fehler, erfolg, co ~= nil)
		local info = { typ = "ende", blind = true, erfolg = erfolg, text = text, fehler = st.fehler, sek = sek, titel = team.titel,
			geld = team.geld, fahrer = p.DisplayName, copilotName = co and co.DisplayName }
]===], [===[
		local sek = st.blind.start and math.floor(os.clock() - st.blind.start) or 0
		local falsch = st.blind.falsch or 0
		local team = Beta.blindWertung(st.fehler + falsch, erfolg, co ~= nil)
		local info = { typ = "ende", blind = true, erfolg = erfolg, text = text, fehler = st.fehler, falsch = falsch, sek = sek, titel = team.titel,
			geld = team.geld, fahrer = p.DisplayName, copilotName = co and co.DisplayName }
]===])
src = ersetze(src, [===[
	pp.Parent = sitz
	pp.Triggered:Connect(function(wer)
		if wer == fahrer or sitz.Occupant or not modell.Parent or lektionen[fahrer] ~= st then return end
		if lektionen[wer] or jobs[wer] then
]===], [===[
	pp.Parent = sitz
	-- also used by "Find a partner" (v56): puts a player into the co-pilot seat from anywhere
	st.copilotEinsetzen = function(wer, vonWeitWeg)
		if wer == fahrer or sitz.Occupant or not modell.Parent or lektionen[fahrer] ~= st then return false end
		if lektionen[wer] or jobs[wer] then
]===])
src = ersetze(src, [===[
		if wer == fahrer or sitz.Occupant or not modell.Parent or lektionen[fahrer] ~= st then return false end
		if lektionen[wer] or jobs[wer] then
			fahrEvent:FireClient(wer, { typ = "hinweis", text = "Finish your own lesson or job first." })
			return
		end
		local hum = wer.Character and wer.Character:FindFirstChildOfClass("Humanoid")
		if not hum or hum.SeatPart then return end
]===], [===[
		if wer == fahrer or sitz.Occupant or not modell.Parent or lektionen[fahrer] ~= st then return false end
		if lektionen[wer] or jobs[wer] then
			fahrEvent:FireClient(wer, { typ = "hinweis", text = "Finish your own lesson or job first." })
			return false
		end
		local hum = wer.Character and wer.Character:FindFirstChildOfClass("Humanoid")
		if not hum or hum.SeatPart then return end
]===])
src = ersetze(src, [===[
		end
		local hum = wer.Character and wer.Character:FindFirstChildOfClass("Humanoid")
		if not hum or hum.SeatPart then return end
		sitz:Sit(hum)
		st.blind.copilot = wer
]===], [===[
		end
		local hum = wer.Character and wer.Character:FindFirstChildOfClass("Humanoid")
		if not hum or (hum.SeatPart and not vonWeitWeg) then return false end
		if hum.SeatPart then hum.Sit = false end
		sitz:Sit(hum)
		st.blind.copilot = wer
]===])
src = ersetze(src, [===[
		if fh and Players:GetPlayerFromCharacter(fh.Parent) == fahrer then st.losfahren() end
	end)
	sitz:GetPropertyChangedSignal("Occupant"):Connect(function()
]===], [===[
		if fh and Players:GetPlayerFromCharacter(fh.Parent) == fahrer then st.losfahren() end
		return true
	end
	pp.Triggered:Connect(function(wer) st.copilotEinsetzen(wer) end)
	sitz:GetPropertyChangedSignal("Occupant"):Connect(function()
]===])
src = ersetze(src, [===[
		local amTor = st.tor and Regeln.durchTor(pos, st.tor.pos, st.tor.dir, st.tor.breite, st.tor.r)
		if wp.parken then
]===], [===[
		local amTor = st.tor and Regeln.durchTor(pos, st.tor.pos, st.tor.dir, st.tor.breite, st.tor.r)
		if st.blind and st.tor and st.zielAktiv then
			-- 🙈 Blind Drive (v56): driving away from the next gate = wrong way (hint for both; counts for the team rating)
			local zumTor = (Vector3.new(st.tor.pos.X, pos.Y, st.tor.pos.Z) - pos).Magnitude
			if st.blind.torNr ~= st.index then st.blind.torNr, st.blind.naechst = st.index, zumTor end
			st.blind.naechst = math.min(st.blind.naechst, zumTor)
			if zumTor > st.blind.naechst + 70 and os.clock() - (st.blind.falschZeit or 0) > 10 then
				st.blind.falschZeit, st.blind.naechst = os.clock(), zumTor
				st.blind.falsch = (st.blind.falsch or 0) + 1
				local info = { typ = "chaos", titel = "🔄 WRONG WAY!", text = "You're driving away from the next gate – turn around!", farbe = "rot" }
				fahrEvent:FireClient(p, info)
				local co = st.blind.copilot
				if co and co.Parent then fahrEvent:FireClient(co, info) end
			end
		end
		if wp.parken then
]===])
src = ersetze(src, [===[
-- ---------------------------------------------------------------
aktion.OnServerInvoke = function(p, was, eingabe)
]===], [===[
-- ---------------------------------------------------------------
-- 🎲 Blind Drive "Find a partner" (v56): two players without a friend get matched on the server.
-- The one who waited longer drives, the other one becomes the co-pilot. Both are put into the car.
local blindWarte = {}   -- { { p = player, seit = clock } }
local blindAufruf = -math.huge
local BLIND_WARTEZEIT = 180
local function blindPartnerSuchen(p)
	for i = #blindWarte, 1, -1 do
		local w = blindWarte[i]
		if not w.p.Parent or os.clock() - w.seit > BLIND_WARTEZEIT or lektionen[w.p] or jobs[w.p] then table.remove(blindWarte, i) end
	end
	for i, w in blindWarte do
		if w.p == p then
			table.remove(blindWarte, i)
			return { text = "You left the partner search.", aus = true }
		end
	end
	if lektionen[p] or jobs[p] then return { fehler = "Finish your lesson or job first." } end
	local partner = blindWarte[1]
	if not partner then
		table.insert(blindWarte, { p = p, seit = os.clock() })
		if os.clock() - blindAufruf > 30 then
			blindAufruf = os.clock()
			for _, sp in Players:GetPlayers() do
				if sp ~= p then
					fahrEvent:FireClient(sp, { typ = "chaos", titel = "🙈 BLIND DRIVE PARTNER WANTED", text = p.DisplayName .. " needs a co-pilot – tap 🙈 Blind → Find a partner!", farbe = "lila" })
				end
			end
		end
		Beta.ereignis(p, "Blind partner search")
		return { text = "Looking for a partner… As soon as another player taps \"Find a partner\", you both get put into the car. Tap again to stop searching.", warten = true }
	end
	table.remove(blindWarte, 1)
	local fahrer = partner.p
	local r = lektionStarten(fahrer, "blind")
	if r.fehler then return { fehler = "Your partner can't start right now – try again." } end
	local st = lektionen[fahrer]
	-- co-pilot first, then the driver: the route starts as soon as the driver sits
	if not (st.copilotEinsetzen and st.copilotEinsetzen(p, true)) then
		lektionBeenden(fahrer, false, "Blind Drive cancelled (the partner could not get in).")
		return { fehler = "Could not put you into the car – try again." }
	end
	local hf = fahrer.Character and fahrer.Character:FindFirstChildOfClass("Humanoid")
	if hf then
		if hf.SeatPart then hf.Sit = false end
		st.sitz:Sit(hf)
	end
	fahrEvent:FireClient(fahrer, { typ = "chaos", titel = "🎲 PARTNER FOUND!", text = p.DisplayName .. " is your co-pilot. You drive – listen to them!", farbe = "gruen" })
	Beta.ereignis(p, "Blind partner matched")
	return { text = ("Partner found! You're %s's co-pilot – tell them where to drive."):format(fahrer.DisplayName), gefunden = true }
end
Beta.blindWarteliste = function() return blindWarte end

aktion.OnServerInvoke = function(p, was, eingabe)
]===])
src = ersetze(src, [===[
		return lektionStarten(p, "blind")

]===], [===[
		return lektionStarten(p, "blind")
	elseif was == "blindPartner" then
		return blindPartnerSuchen(p)

]===])
assert(#src == 148989, "Ergebnis-Länge falsch: " .. #src)
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
assert(#src == 193439, "Ausgangsstand passt nicht: " .. #src)
src = ersetze(src, [===[
local spieler = Players.LocalPlayer
print("[Driving School] client v55 loaded")
local ordner = RS:WaitForChild("Fuehrerschein")
]===], [===[
local spieler = Players.LocalPlayer
print("[Driving School] client v56 loaded")
local ordner = RS:WaitForChild("Fuehrerschein")
]===])
src = ersetze(src, [===[
do
	print("[Driving School] start screen v55 loading")
	local menue = Instance.new("ScreenGui")
]===], [===[
do
	print("[Driving School] start screen v56 loading")
	local menue = Instance.new("ScreenGui")
]===])
assert(#src == 193439, "Ergebnis-Länge falsch: " .. #src)
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
assert(#src == 51504, "Ausgangsstand passt nicht: " .. #src)
src = ersetze(src, [===[
	if not c or c.event then return nil end
	art = art or wuerfeln(st)
]===], [===[
	if not c or c.event then return nil end
	-- v56: the very first event of lesson 1 is always the cows – the funniest "what is going on?!" moment for new players
	if not art and st.nr == 1 and c.anzahl == 0 and not c.frei and EVENTS.kuehe then art = "kuehe" end
	art = art or wuerfeln(st)
]===])
assert(#src == 51726, "Ergebnis-Länge falsch: " .. #src)
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
local s = game.ServerScriptService.FuehrerscheinServer.Beta
local src = s.Source
assert(#src == 9289, "Ausgangsstand passt nicht: " .. #src)
src = ersetze(src, [===[
Beta.KOMMANDOS = {
	links = { "⬅ LEFT!", "gelb" },
	gerade = { "⬆ STRAIGHT ON!", "gelb" },
	rechts = { "RIGHT! ➡", "gelb" },
	stopp = { "✋ STOP!", "rot" },
]===], [===[
Beta.KOMMANDOS = {
	links = { "◀ LEFT!", "gelb" },
	gerade = { "▲ STRAIGHT ON!", "gelb" },
	rechts = { "RIGHT! ▶", "gelb" },
	stopp = { "✋ STOP!", "rot" },
]===])
assert(#src == 9289, "Ergebnis-Länge falsch: " .. #src)
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
local s = game.ReplicatedStorage.Fuehrerschein.BetaClient
local src = s.Source
assert(#src == 13556, "Ausgangsstand passt nicht: " .. #src)
src = ersetze(src, [===[
		local KNOEPFE = {
			{ "links", "⬅ LEFT", Color3.fromRGB(230, 170, 30) },
			{ "gerade", "⬆ STRAIGHT", Color3.fromRGB(230, 170, 30) },
			{ "rechts", "RIGHT ➡", Color3.fromRGB(230, 170, 30) },
			{ "stopp", "✋ STOP", Color3.fromRGB(200, 60, 60) },
]===], [===[
		local KNOEPFE = {
			{ "links", "◀ LEFT", Color3.fromRGB(230, 170, 30) },
			{ "gerade", "▲ STRAIGHT", Color3.fromRGB(230, 170, 30) },
			{ "rechts", "RIGHT ▶", Color3.fromRGB(230, 170, 30) },
			{ "stopp", "✋ STOP", Color3.fromRGB(200, 60, 60) },
]===])
src = ersetze(src, [===[
					local m = Vector3.new(coZiel.X - hrp.Position.X, 0, coZiel.Z - hrp.Position.Z).Magnitude
					coWeite.Text = m < 25 and "➡ NOW!" or ("Next gate in %d m"):format(math.floor(m / 5 + 0.5) * 5)
				end
]===], [===[
					local m = Vector3.new(coZiel.X - hrp.Position.X, 0, coZiel.Z - hrp.Position.Z).Magnitude
					coWeite.Text = m < 25 and "▶ NOW!" or ("Next gate in %d m"):format(math.floor(m / 5 + 0.5) * 5)
				end
]===])
src = ersetze(src, [===[
			local zeit = ("%d:%02d"):format(math.floor((info.sek or 0) / 60), (info.sek or 0) % 60)
			local text = ("<font size=\"26\" color=\"#ffd23c\"><b>%s</b></font>\n\n🙈 Driver: <b>%s</b>   🗺 Co-pilot: <b>%s</b>\nMistakes: <b>%d</b>   ·   Time: <b>%s</b>%s"):format(
				info.titel or "", info.fahrer or "?", info.copilotName or "–", info.fehler or 0, zeit,
				(info.geld or 0) > 0 and ("\n\n+%d coins each"):format(info.geld) or "")
]===], [===[
			local zeit = ("%d:%02d"):format(math.floor((info.sek or 0) / 60), (info.sek or 0) % 60)
			local text = ("<font size=\"26\" color=\"#ffd23c\"><b>%s</b></font>\n\n🙈 Driver: <b>%s</b>   🗺 Co-pilot: <b>%s</b>\nMistakes: <b>%d</b>   ·   Wrong ways: <b>%d</b>   ·   Time: <b>%s</b>%s"):format(
				info.titel or "", info.fahrer or "?", info.copilotName or "–", info.fehler or 0, info.falsch or 0, zeit,
				(info.geld or 0) > 0 and ("\n\n+%d coins each"):format(info.geld) or "")
]===])
src = ersetze(src, [===[

	function BetaClient.blindKnopf()
		local r = frage("blindStarten")
]===], [===[

	local function mitFreund()
		local r = frage("blindStarten")
]===])
src = ersetze(src, [===[
		else
			k.zeige("🙈 Blind Drive", (r.text or "") .. "\n\n<b>How it works:</b> you drive, but you can't see the route. Your friend sits next to you (\"Be the co-pilot\" at the passenger door), sees the map and tells you where to go.", {
				{ text = "Let's go!", farbe = GRUEN, klick = k.schliessen },
]===], [===[
		else
			k.zeige("🙈 Blind Drive", (r.text or "") .. "\n\nYour friend: walk to the passenger door and press <b>\"Be the co-pilot\"</b>.", {
				{ text = "Let's go!", farbe = GRUEN, klick = k.schliessen },
]===])
src = ersetze(src, [===[
		end
	end
]===], [===[
		end
	end
	local function partnerSuchen()
		local r = frage("blindPartner")
		if r.fehler then
			warnen(r.fehler, Color3.fromRGB(200, 140, 30))
		else
			k.schliessen()
			warnen("🎲 " .. (r.text or ""), r.aus and Color3.fromRGB(200, 140, 30) or GRUEN)
		end
	end
	function BetaClient.blindKnopf()
		k.zeige("🙈 Blind Drive",
			"<b>One drives, one navigates.</b>\nThe driver can't see the route – the co-pilot sees the map and tells them where to go.\n\n"
				.. "👥 <b>With a friend:</b> you drive, your friend sits next to you.\n🎲 <b>Find a partner:</b> we match you with another player on this server.", {
				{ text = "👥 With a friend", farbe = GRUEN, klick = mitFreund },
				{ text = "🎲 Find a partner", farbe = BLAU, klick = partnerSuchen },
				{ text = "Close", farbe = Color3.fromRGB(70, 75, 85), klick = k.schliessen },
			}, "dialog")
	end
]===])
assert(#src == 14361, "Ergebnis-Länge falsch: " .. #src)
s.Source = src
print(s.Name .. ": " .. #src .. " Zeichen")
end
game:GetService("ChangeHistoryService"):SetWaypoint("v56")
print("v56 eingespielt – speichern (Strg+S) und veröffentlichen")
