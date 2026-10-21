-- v59 -> v60: Ragdoll-Crashes + Sabotage-Shop (neue Module Spass, SpassClient). Im EDIT-Modus in die Befehlszeile oder per MCP.
local log = {}
game:GetService("ChangeHistoryService"):SetWaypoint("Vor v60")
do
local eltern = game.ServerScriptService.FuehrerscheinServer
local m = eltern:FindFirstChild("Spass") or Instance.new("ModuleScript")
m.Name = "Spass"
m.Source = [=====[
-- 💥 Fun module (v60): ragdoll crashes + sabotage shop.
--   Ragdoll: crash hard into something -> you (and your passengers) fly out of the car, take damage, and are put
--            back into your seat after a few seconds. The car and its driving feel stay exactly the same.
--   Sabotage: spend coins to send a chaos event (cows, banana, mud, clown, UFO) to another player who is driving.
--             Protected: lesson 1, driving tests, trucks, and everybody who switched "Others can sabotage you" off.
--             Survive it (don't hit it) = bonus coins for the victim.
local Players = game:GetService("Players")

local Spass = {}
Spass.SCHADEN_MIN, Spass.SCHADEN_MAX = 8, 45
Spass.HP_MIN = 5              -- a crash never kills you (kids' game); health comes back by itself
Spass.RAGDOLL_ZEIT = 3
Spass.CRASH_PAUSE = 5         -- seconds between two crashes of the same player
Spass.ZIEL_PAUSE = 20         -- seconds between two sabotages on the same target
Spass.SENDER_PAUSE = 8
Spass.MAX_PRO_FAHRT = 3
Spass.BONUS = 50              -- survived a sabotage
Spass.ARTEN = {
	{ art = "banane", name = "🍌 Banana Peel", preis = 100 },
	{ art = "pfuetze", name = "🟤 Mud Splash", preis = 120 },
	{ art = "kuehe", name = "🐄 Cow Stampede", preis = 150 },
	{ art = "clown", name = "🤡 Creepy Clown", preis = 200 },
	{ art = "ufo", name = "👽 UFO Abduction", preis = 300 },
}

local ctx
local letzterCrash = {}
local zielZeit = {}       -- [target] = clock of the last sabotage on them
local senderZeit = {}

local function event(p, info)
	if p and p.Parent then ctx.fahrEvent:FireClient(p, info) end
end

-- ---------------------------------------------------------------
-- Ragdoll
-- ---------------------------------------------------------------
local function ragdollAn(char)
	local gemacht = {}
	for _, m in char:GetDescendants() do
		if m:IsA("Motor6D") and m.Name ~= "Root" and m.Name ~= "RootJoint" and m.Part0 and m.Part1 then
			local a0 = Instance.new("Attachment")
			a0.Name = "RagdollA0"
			a0.CFrame = m.C0
			a0.Parent = m.Part0
			local a1 = Instance.new("Attachment")
			a1.Name = "RagdollA1"
			a1.CFrame = m.C1
			a1.Parent = m.Part1
			local b = Instance.new("BallSocketConstraint")
			b.Name = "RagdollGelenk"
			b.Attachment0, b.Attachment1 = a0, a1
			b.LimitsEnabled = true
			b.TwistLimitsEnabled = true
			b.UpperAngle = 50
			b.Parent = m.Part1
			m.Enabled = false
			table.insert(gemacht, { motor = m, teile = { a0, a1, b } })
		end
	end
	local kollision = {}
	for _, t in char:GetChildren() do
		if t:IsA("BasePart") and t.Name ~= "HumanoidRootPart" and not t.CanCollide then
			t.CanCollide = true
			table.insert(kollision, t)
		end
	end
	return function()
		for _, g in gemacht do
			for _, x in g.teile do x:Destroy() end
			if g.motor.Parent then g.motor.Enabled = true end
		end
		for _, t in kollision do if t.Parent then t.CanCollide = false end end
	end
end

-- throws one player out of their seat; back into the same seat after a few seconds
local function rauswerfen(p, sitz, stoss, schaden, titel)
	local char = p.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return end
	char:SetAttribute("Ragdoll", true) -- seats that watch for "player got out" wait for the ragdoll to end
	local weld = sitz:FindFirstChild("SeatWeld")
	if weld then weld:Destroy() end
	hum.Sit = false
	hum.Health = math.max(Spass.HP_MIN, hum.Health - schaden)
	local zurueck = ragdollAn(char)
	event(p, { typ = "ragdoll", dauer = Spass.RAGDOLL_ZEIT, stoss = stoss, schaden = schaden })
	event(p, { typ = "chaos", titel = titel, text = ("You flew out of the car! -%d HP"):format(schaden), farbe = "rot" })
	task.delay(Spass.RAGDOLL_ZEIT + 0.2, function()
		zurueck()
		task.delay(1, function() if char.Parent then char:SetAttribute("Ragdoll", nil) end end)
		if not (p.Parent and char.Parent and hum.Health > 0) then return end
		-- back into the seat (if it is still free and the car is not far away)
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if sitz.Parent and not sitz.Occupant and not hum.SeatPart and hrp and (hrp.Position - sitz.Position).Magnitude < 250 then
			sitz:Sit(hum)
		end
	end)
end

local TITEL = { "💥 YEEEEET!", "💥 OUCH!", "💥 FLYING LESSON!", "💥 WHOOPS!", "💥 AIRBAG? WHAT AIRBAG?" }

-- the client noticed a hard crash (big speed drop in a fraction of a second)
function Spass.crash(p, eingabe)
	local jetzt = os.clock()
	if letzterCrash[p] and jetzt - letzterCrash[p] < Spass.CRASH_PAUSE then return { ok = false } end
	local char = p.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local sitz = hum and hum.SeatPart
	if not (sitz and sitz:IsA("VehicleSeat")) then return { ok = false } end
	if type(eingabe) ~= "table" then return { ok = false } end
	local von = math.clamp(tonumber(eingabe.von) or 0, 0, 250)
	local nach = math.clamp(tonumber(eingabe.nach) or 0, 0, 250)
	if von < 45 or von - nach < 35 then return { ok = false } end
	local st = ctx.stVon and ctx.stVon(p)
	if st and ctx.schonzeit and ctx.schonzeit(st) then return { ok = false } end -- banana spin / UFO: not your fault
	letzterCrash[p] = jetzt
	local schaden = math.clamp(math.floor((von - nach - 25) * 0.9), Spass.SCHADEN_MIN, Spass.SCHADEN_MAX)
	local vor = sitz.CFrame.LookVector
	local stoss = vor * math.min(von * 0.55, 70) + Vector3.new(0, 28 + von * 0.12, 0)
	local titel = TITEL[math.random(#TITEL)]
	-- everybody (players) in the car flies out: driver and passengers
	local modell = sitz:FindFirstAncestorOfClass("Model")
	local erledigt = {}
	for _, s in modell and modell:GetDescendants() or { sitz } do
		if (s:IsA("Seat") or s:IsA("VehicleSeat")) and s.Occupant then
			local wer = Players:GetPlayerFromCharacter(s.Occupant.Parent)
			if wer and not erledigt[wer] then
				erledigt[wer] = true
				rauswerfen(wer, s, stoss + Vector3.new(math.random(-6, 6), 0, math.random(-6, 6)), wer == p and schaden or math.ceil(schaden * 0.6), titel)
			end
		end
	end
	if ctx.crashPunkte then ctx.crashPunkte(p, 3) end
	if ctx.ereignis then ctx.ereignis(p, "Ragdoll crash") end
	return { ok = true, schaden = schaden }
end

-- ---------------------------------------------------------------
-- Sabotage
-- ---------------------------------------------------------------
local function artDef(art)
	for _, a in Spass.ARTEN do if a.art == art then return a end end
end

-- can p sabotage ziel right now? -> state of the target or nil + reason
local function zielPruefen(p, ziel)
	if not ziel or not ziel.Parent or ziel == p then return nil, "That player is not here." end
	local d = ctx.daten[ziel]
	if d and d.einstellungen and d.einstellungen.sabotageAus then return nil, ziel.DisplayName .. " has sabotage switched off." end
	local st = ctx.lektionen[ziel]
	local wo = "Lesson"
	if st then
		if st.pruefung then return nil, ziel.DisplayName .. " is taking the driving test – not now!" end
		if st.lkw then return nil, ziel.DisplayName .. " is driving a truck – too dangerous!" end
		if st.blind then wo = "Blind Drive" elseif st.party then wo = "Party Test"
		elseif st.nr == 1 then return nil, ziel.DisplayName .. " is in the very first lesson – give them a chance!" end
	else
		local a = ctx.privatAutos and ctx.privatAutos[ziel]
		local fahrer = a and a.sitz and a.sitz.Occupant
		if not (a and a.chassis and a.chassis.Parent and fahrer and Players:GetPlayerFromCharacter(fahrer.Parent) == ziel) then
			return nil, ziel.DisplayName .. " is not driving right now."
		end
		if d and d.einstellungen and d.einstellungen.chaosAus then return nil, ziel.DisplayName .. " has chaos switched off." end
		st, wo = a, "Own car"
	end
	if not st.chaos or not st.chassis then return nil, ziel.DisplayName .. " can't be sabotaged right now." end
	return st, wo
end

function Spass.liste(p)
	local ziele = {}
	for _, sp in Players:GetPlayers() do
		if sp ~= p then
			local st, wo = zielPruefen(p, sp)
			if st then
				local warten = math.max(0, math.ceil((zielZeit[sp] or -math.huge) + Spass.ZIEL_PAUSE - os.clock()))
				table.insert(ziele, { id = sp.UserId, name = sp.DisplayName, wo = wo, warten = warten })
			end
		end
	end
	table.sort(ziele, function(a, b) return a.name < b.name end)
	local d = ctx.daten[p]
	return { ziele = ziele, arten = Spass.ARTEN, geld = d and d.geld or 0, bonus = Spass.BONUS }
end

function Spass.sabotieren(p, eingabe)
	if type(eingabe) ~= "table" then return { fehler = "Pick a player and a chaos event." } end
	local d = ctx.daten[p]
	if not d then return { fehler = "Still loading – try again in a moment." } end
	local def = artDef(eingabe.art)
	if not def then return { fehler = "Unknown chaos event." } end
	local ziel = Players:GetPlayerByUserId(tonumber(eingabe.ziel) or 0)
	local st, grund = zielPruefen(p, ziel)
	if not st then return { fehler = grund } end
	local jetzt = os.clock()
	if senderZeit[p] and jetzt - senderZeit[p] < Spass.SENDER_PAUSE then
		return { fehler = ("Recharging… wait %d s."):format(math.ceil(senderZeit[p] + Spass.SENDER_PAUSE - jetzt)) }
	end
	if zielZeit[ziel] and jetzt - zielZeit[ziel] < Spass.ZIEL_PAUSE then
		return { fehler = ("%s was just sabotaged – wait %d s."):format(ziel.DisplayName, math.ceil(zielZeit[ziel] + Spass.ZIEL_PAUSE - jetzt)) }
	end
	if (st.sabotagen or 0) >= Spass.MAX_PRO_FAHRT then return { fehler = ziel.DisplayName .. " has had enough chaos for this drive!" } end
	if st.chaos.event then return { fehler = ziel.DisplayName .. " is already in chaos – wait a moment!" } end
	if (d.geld or 0) < def.preis then return { fehler = ("You need %d coins for %s."):format(def.preis, def.name) } end
	-- pay first (no double spending), refund if the event can't be placed (no road ahead)
	ctx.geldGeben(p, -def.preis, "Sabotage: " .. def.name, true)
	local e = ctx.eventStarten(ziel, st, def.art)
	if not e then
		ctx.geldGeben(p, def.preis, "Sabotage refunded", true)
		return { fehler = ("No road in front of %s right now – try again in a moment (coins refunded)."):format(ziel.DisplayName) }
	end
	e.sabotage = { von = p, name = p.DisplayName }
	st.sabotagen = (st.sabotagen or 0) + 1
	senderZeit[p], zielZeit[ziel] = jetzt, jetzt
	event(ziel, { typ = "chaos", titel = "💥 SABOTAGE!", text = ("%s sent you %s! Dodge it for +%d coins!"):format(p.DisplayName, def.name, Spass.BONUS), farbe = "rot" })
	if ctx.ereignis then ctx.ereignis(p, "Sabotage sent") end
	return { text = ("💥 %s is on its way to %s!"):format(def.name, ziel.DisplayName), ok = true }
end

-- called by Chaos when a sabotage event is over without being hit
function Spass.ueberlebt(p, e)
	if not e.sabotage then return end
	ctx.geldGeben(p, Spass.BONUS, "Survived the sabotage!")
	event(p, { typ = "chaos", titel = "😎 SABOTAGE SURVIVED!", text = ("Nice try, %s! +%d coins"):format(e.sabotage.name, Spass.BONUS), farbe = "gruen" })
	event(e.sabotage.von, { typ = "chaos", titel = "😤 DODGED!", text = "Your sabotage was dodged!", farbe = "gelb" })
end

function Spass.starten(c)
	ctx = c
	Players.PlayerRemoving:Connect(function(p)
		letzterCrash[p], zielZeit[p], senderZeit[p] = nil, nil, nil
	end)
end

return Spass
]=====]
m.Parent = eltern
table.insert(log, "Spass: " .. #m.Source)
end
do
local eltern = game.ReplicatedStorage.Fuehrerschein
local m = eltern:FindFirstChild("SpassClient") or Instance.new("ModuleScript")
m.Name = "SpassClient"
m.Source = [=====[
-- 💥 Fun module, client part (v60): crash detection for ragdoll crashes + the sabotage menu.
-- Required by FuehrerscheinClient (that script is close to Roblox' 200,000-character limit).
-- Crash detection only READS the car's speed – the driving itself is not touched.
local RunService = game:GetService("RunService")
local SpassClient = {}

SpassClient.ABFALL = 40      -- km/h lost …
SpassClient.FENSTER = 0.25   -- … within this many seconds = crash (brakes can't do that)
SpassClient.MIN_TEMPO = 50   -- only from this speed on

function SpassClient.starten(k)
	local spieler, frage, warnen, zeige, schliessen = k.spieler, k.frage, k.warnen, k.zeige, k.schliessen
	local ROT, GRAU = Color3.fromRGB(200, 55, 55), Color3.fromRGB(70, 75, 85)

	-- 🚗💥 crash detection: big speed drop in a fraction of a second
	local verlauf = {}       -- { { t, tempo } }
	local sitzSeit, letzterSitz, gemeldet = 0, nil, 0
	RunService.Heartbeat:Connect(function()
		local hum = spieler.Character and spieler.Character:FindFirstChildOfClass("Humanoid")
		local sitz = hum and hum.SeatPart
		if not (sitz and sitz:IsA("VehicleSeat")) then
			letzterSitz = nil
			table.clear(verlauf)
			return
		end
		local jetzt = os.clock()
		if sitz ~= letzterSitz then letzterSitz, sitzSeit = sitz, jetzt table.clear(verlauf) end
		local v = sitz.AssemblyLinearVelocity
		local tempo = Vector3.new(v.X, 0, v.Z).Magnitude
		table.insert(verlauf, { jetzt, tempo })
		while verlauf[1] and jetzt - verlauf[1][1] > SpassClient.FENSTER do table.remove(verlauf, 1) end
		-- not your fault: banana spin, UFO, the first seconds after getting in
		if _G.Rutschen or _G.Entfuehrung or jetzt - sitzSeit < 3 or jetzt - gemeldet < 5 then return end
		local hoechst = 0
		for _, x in verlauf do hoechst = math.max(hoechst, x[2]) end
		if hoechst >= SpassClient.MIN_TEMPO and hoechst - tempo >= SpassClient.ABFALL then
			gemeldet = jetzt
			table.clear(verlauf)
			task.spawn(frage, "crash", { von = hoechst, nach = tempo })
		end
	end)

	-- the server threw us out of the car: go limp, fly, get up again
	game:GetService("ReplicatedStorage"):WaitForChild("Fuehrerschein"):WaitForChild("Fahrstunde").OnClientEvent:Connect(function(info)
		if type(info) ~= "table" or info.typ ~= "ragdoll" then return end
		local char = spieler.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not (hum and hrp) then return end
		hum:ChangeState(Enum.HumanoidStateType.Physics)
		if typeof(info.stoss) == "Vector3" then
			hrp.AssemblyLinearVelocity = info.stoss
			hrp.AssemblyAngularVelocity = Vector3.new(math.random(-6, 6), math.random(-3, 3), math.random(-6, 6))
		end
		task.delay(info.dauer or 3, function()
			if hum.Parent and hum.Health > 0 then hum:ChangeState(Enum.HumanoidStateType.GettingUp) end
		end)
	end)

	-- 💥 sabotage menu: pick a driving player, then a chaos event
	local zielMenue
	local function artenMenue(ziel, r)
		local knoepfe = {}
		for _, a in r.arten do
			table.insert(knoepfe, { text = ("%s · %d coins"):format(a.name, a.preis), farbe = (r.geld or 0) >= a.preis and ROT or GRAU, klick = function()
				local x = frage("sabotage", { ziel = ziel.id, art = a.art })
				schliessen()
				warnen(x.fehler or x.text or "", x.fehler and Color3.fromRGB(200, 140, 30) or ROT)
			end })
		end
		table.insert(knoepfe, { text = "◀ Back", farbe = GRAU, klick = zielMenue })
		zeige("💥 Sabotage " .. ziel.name, ("You have <b>%d coins</b>. Pick the chaos for %s (%s)!\nIf they dodge it, <i>they</i> get +%d coins."):format(
			r.geld or 0, ziel.name, ziel.wo, r.bonus or 0), knoepfe, "dialog")
	end
	zielMenue = function()
		local r = frage("sabotageListe")
		if r.fehler then warnen(r.fehler, Color3.fromRGB(200, 140, 30)) return end
		local knoepfe = {}
		for i, z in r.ziele or {} do
			if i > 4 then break end
			local text = ("🚗 %s · %s"):format(z.name, z.wo)
			if z.warten > 0 then text ..= (" (%d s)"):format(z.warten) end
			table.insert(knoepfe, { text = text, farbe = z.warten > 0 and GRAU or ROT, klick = function() artenMenue(z, r) end })
		end
		table.insert(knoepfe, { text = "Close", farbe = GRAU, klick = schliessen })
		local text = #(r.ziele or {}) == 0
			and "Nobody can be sabotaged right now.\nPlayers must be <b>driving</b> (not in lesson 1, the driving test or a truck) and have sabotage switched on."
			or "Send chaos to a player who is driving! 🐄🍌👽"
		zeige("💥 Sabotage", text, knoepfe, "dialog")
	end
	if k.knopf then k.knopf.MouseButton1Click:Connect(zielMenue) end
	return SpassClient
end

return SpassClient
]=====]
m.Parent = eltern
table.insert(log, "SpassClient: " .. #m.Source)
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
assert(#src == 151104, "Ausgangsstand passt nicht: " .. #src)
src = ersetze(src, [===[
local Zonen = require(script:WaitForChild("Zonen"))
local Hupen = require(ordner:WaitForChild("Hupen"))
]===], [===[
local Zonen = require(script:WaitForChild("Zonen"))
local Spass = require(script:WaitForChild("Spass"))
local Hupen = require(ordner:WaitForChild("Hupen"))
]===])
src = ersetze(src, [===[
	pp.Triggered:Connect(function(wer) st.copilotEinsetzen(wer) end)
	sitz:GetPropertyChangedSignal("Occupant"):Connect(function()
		pp.Enabled = sitz.Occupant == nil
]===], [===[
	pp.Triggered:Connect(function(wer) st.copilotEinsetzen(wer) end)
	local function copilotWeg()
		pp.Enabled = sitz.Occupant == nil
]===])
src = ersetze(src, [===[
		if sitz.Occupant == nil and st.blind.copilot and lektionen[fahrer] == st then
			-- the co-pilot got out: the driver sees the route again (no team rating)
]===], [===[
		if sitz.Occupant == nil and st.blind.copilot and lektionen[fahrer] == st then
			-- 💥 thrown out by a ragdoll crash (v60): comes back into the seat in a moment – check again then
			local co = st.blind.copilot
			if co.Character and co.Character:GetAttribute("Ragdoll") then task.delay(4, copilotWeg) return end
			-- the co-pilot got out: the driver sees the route again (no team rating)
]===])
src = ersetze(src, [===[
		end
	end)
	return pp
]===], [===[
		end
	end
	sitz:GetPropertyChangedSignal("Occupant"):Connect(copilotWeg)
	return pp
]===])
src = ersetze(src, [===[
		return blindPartnerSuchen(p)

]===], [===[
		return blindPartnerSuchen(p)
	elseif was == "crash" then
		return Spass.crash(p, eingabe)
	elseif was == "sabotageListe" then
		return Spass.liste(p)
	elseif was == "sabotage" then
		return Spass.sabotieren(p, eingabe)

]===])
src = ersetze(src, [===[
	daten = daten, geaendert = geaendert, Shop = Shop, Missionen = Missionen, Hupen = Hupen,
	onEvent = function(p) Beta.funnel(p, "First chaos event") end })
Party.starten({ fahrEvent = fahrEvent, geldGeben = geldGeben, xpGeben = xpGeben, Chaos = Chaos,
]===], [===[
	daten = daten, geaendert = geaendert, Shop = Shop, Missionen = Missionen, Hupen = Hupen,
	onEvent = function(p) Beta.funnel(p, "First chaos event") end,
	sabotageUeberlebt = function(p, e) Spass.ueberlebt(p, e) end })
Spass.starten({ fahrEvent = fahrEvent, daten = daten, lektionen = lektionen, privatAutos = privatAutos, geldGeben = geldGeben,
	eventStarten = Chaos.eventStarten, schonzeit = Chaos.schonzeit, crashPunkte = Chaos.crashPunkte, ereignis = Beta.ereignis,
	stVon = function(p) return lektionen[p] or privatAutos[p] end })
Party.starten({ fahrEvent = fahrEvent, geldGeben = geldGeben, xpGeben = xpGeben, Chaos = Chaos,
]===])
assert(#src == 151994, "Ergebnis-Länge falsch: " .. #src)
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
assert(#src == 53281, "Ausgangsstand passt nicht: " .. #src)
src = ersetze(src, [===[
	if grund ~= "vorbei" then return end
	if e.art == "ufo" then
]===], [===[
	if grund ~= "vorbei" then return end
	-- 💥 sabotage by another player (v60): not hit = bonus for the victim
	if e.sabotage and not e.getroffen and ctx.sabotageUeberlebt then pcall(ctx.sabotageUeberlebt, p, e) end
	if e.art == "ufo" then
]===])
assert(#src == 53460, "Ergebnis-Länge falsch: " .. #src)
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
local s = game.StarterPlayer.StarterPlayerScripts.FuehrerscheinClient
local src = s.Source
assert(#src == 193439, "Ausgangsstand passt nicht: " .. #src)
src = ersetze(src, [===[
local spieler = Players.LocalPlayer
print("[Driving School] client v59 loaded")
local ordner = RS:WaitForChild("Fuehrerschein")
]===], [===[
local spieler = Players.LocalPlayer
print("[Driving School] client v60 loaded")
local ordner = RS:WaitForChild("Fuehrerschein")
]===])
src = ersetze(src, [===[
	leistenKnopf("🙈", "Blind", 9, Color3.fromRGB(150, 60, 170)).MouseButton1Click:Connect(BetaClient.blindKnopf)
	local partyKnopf = leistenKnopf("🏁", "Party", 8, Color3.fromRGB(200, 90, 30))
]===], [===[
	leistenKnopf("🙈", "Blind", 9, Color3.fromRGB(150, 60, 170)).MouseButton1Click:Connect(BetaClient.blindKnopf)
	require(ordner:WaitForChild("SpassClient")).starten({ spieler = spieler, frage = frage, warnen = warnen, zeige = zeige, schliessen = schliessen,
		knopf = leistenKnopf("💥", "Sabotage", 10, Color3.fromRGB(200, 50, 50)) }) -- v60 ragdoll crashes + sabotage
	local partyKnopf = leistenKnopf("🏁", "Party", 8, Color3.fromRGB(200, 90, 30))
]===])
src = ersetze(src, [===[
-- ---------------------------------------------------------------
_G.Einstellungen = { minimap = true, mph = false, grosseAnzeige = false, ersteP = false, sparmodus = false, sparmodusGewaehlt = false, chaosAus = false, hupe = "normal" }
_G.SparmodusAuto() -- phones / tablets: performance mode until the saved settings say otherwise
]===], [===[
-- ---------------------------------------------------------------
_G.Einstellungen = { minimap = true, mph = false, grosseAnzeige = false, ersteP = false, sparmodus = false, sparmodusGewaehlt = false, chaosAus = false, sabotageAus = false, hupe = "normal" }
_G.SparmodusAuto() -- phones / tablets: performance mode until the saved settings say otherwise
]===])
src = ersetze(src, [===[
einstellRahmen.Position = UDim2.fromScale(0.5, 0.5)
einstellRahmen.Size = UDim2.fromOffset(380, 534)
einstellRahmen.BackgroundColor3 = Color3.fromRGB(25, 30, 40)
]===], [===[
einstellRahmen.Position = UDim2.fromScale(0.5, 0.5)
einstellRahmen.Size = UDim2.fromOffset(380, 584)
einstellRahmen.BackgroundColor3 = Color3.fromRGB(25, 30, 40)
]===])
src = ersetze(src, [===[
	{ "chaosAus", "Chaos in your own car", "Off", "On" }, -- lessons always have chaos
}
]===], [===[
	{ "chaosAus", "Chaos in your own car", "Off", "On" }, -- lessons always have chaos
	{ "sabotageAus", "Others can sabotage you", "Off", "On" },
}
]===])
src = ersetze(src, [===[
do
	print("[Driving School] start screen v59 loading")
	local menue = Instance.new("ScreenGui")
]===], [===[
do
	print("[Driving School] start screen v60 loading")
	local menue = Instance.new("ScreenGui")
]===])
assert(#src == 193779, "Ergebnis-Länge falsch: " .. #src)
s.Source = src
table.insert(log, s.Name .. ': ' .. #src)
end
game:GetService("ChangeHistoryService"):SetWaypoint("v60")
print(table.concat(log, " | "))
return table.concat(log, " | ")
