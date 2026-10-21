-- v60 Nachtrag: Modul "Spass" (Ragdoll + Sabotage) auf den getesteten Stand setzen. Mehrfach ausführbar.
-- In Studio im EDIT-Modus (nicht während Play) in die Befehlszeile (Ansicht -> Befehlszeile) einfügen und Enter.
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
		if m:IsA("Motor6D") and m.Name ~= "Root" and m.Name ~= "RootJoint" and m.Name ~= "Neck" and m.Part0 and m.Part1 then
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
	-- newer avatars (Roblox "avatar joint upgrade"): AnimationConstraint drives each joint, a BallSocketConstraint is
	-- already there – switching the AnimationConstraint off makes the limb go limp
	local animiert = {}
	for _, j in char:GetDescendants() do
		if j:IsA("AnimationConstraint") and j.Name ~= "Root" and j.Name ~= "Neck" and j.Enabled then
			j.Enabled = false
			table.insert(animiert, j)
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
		for _, j in animiert do if j.Parent then j.Enabled = true end end
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
	-- a loose neck kills a Roblox character (RequiresNeck) – the neck stays stiff and the check is off while flying
	local halsPflicht = hum.RequiresNeck
	hum.RequiresNeck = false
	local zurueck = ragdollAn(char)
	event(p, { typ = "ragdoll", dauer = Spass.RAGDOLL_ZEIT, stoss = stoss, schaden = schaden, sitz = sitz })
	event(p, { typ = "chaos", titel = titel, text = ("You flew out of the car! -%d HP"):format(schaden), farbe = "rot" })
	task.delay(Spass.RAGDOLL_ZEIT + 0.2, function()
		zurueck()
		if hum.Parent then hum.RequiresNeck = halsPflicht end
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
	-- first collect who sits where (locking a seat throws its occupant out right away)
	local sitze, insassen, erledigt = {}, {}, {}
	for _, s in modell and modell:GetDescendants() or { sitz } do
		if s:IsA("Seat") or s:IsA("VehicleSeat") then
			table.insert(sitze, s)
			local wer = s.Occupant and Players:GetPlayerFromCharacter(s.Occupant.Parent)
			if wer and not erledigt[wer] then
				erledigt[wer] = true
				table.insert(insassen, { p = wer, sitz = s })
			end
		end
	end
	-- mark them first: seats that watch for "player got out" must know it's only a ragdoll
	for _, x in insassen do
		if x.p.Character then x.p.Character:SetAttribute("Ragdoll", true) end
	end
	-- lock ALL seats of the car while people fly around: otherwise Roblox sits a limp body down on any seat it touches
	local gesperrt = {}
	for _, s in sitze do
		if s.Disabled ~= true then
			s.Disabled = true
			table.insert(gesperrt, s)
		end
	end
	task.delay(Spass.RAGDOLL_ZEIT + 0.1, function()
		for _, s in gesperrt do if s.Parent then s.Disabled = false end end
	end)
	for _, x in insassen do
		rauswerfen(x.p, x.sitz, stoss + Vector3.new(math.random(-6, 6), 0, math.random(-6, 6)), x.p == p and schaden or math.ceil(schaden * 0.6), titel)
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
game:GetService("ChangeHistoryService"):SetWaypoint("Spass v60")
print("Spass: " .. #m.Source .. " Zeichen (soll 12669)")
