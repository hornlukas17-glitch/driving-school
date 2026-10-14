-- Engine sounds for all vehicles (client only – pure sound, the driving itself is not touched).
-- Every car type has its own engine voice, made with tools/sound/motoren.py: three seamless loops
-- (idle / low / high rpm) that are cross-faded and sped up with a virtual rpm + gearbox, plus a start
-- sound when someone gets in. Voices whose files are not uploaded yet (id 0) use Roblox's free engine
-- loop as a stand-in, tuned per car.
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local DATEN = require(script.Parent:WaitForChild("Motorklaenge"))

local Motorsound = {}
Motorsound.DATEN = DATEN
Motorsound.ERSATZ_ID = 80317022777602 -- "Car-Engine-Loop" (Roblox, free to use)

-- which voice each vehicle uses: laut = volume, ton = pitch, ersatzTon = pitch of the stand-in loop
local PROFILE = {
	fahrschule = { stimme = "Fahrschule", laut = 0.85, ersatzTon = 1.0 },
	kleinwagen = { stimme = "Zipster", laut = 0.8, ersatzTon = 1.25 },
	suv = { stimme = "Ranger", laut = 0.95, ersatzTon = 0.8 },
	limousine = { stimme = "Executive", laut = 0.75, ersatzTon = 0.72 },
	sport = { stimme = "Velocity", laut = 1.0, ersatzTon = 1.12 },
	gs = { stimme = "Vanta", laut = 1.0, ersatzTon = 0.95 },
	gs_night = { stimme = "VantaNight", laut = 1.15, ersatzTon = 0.88 },
	track = { stimme = "Striker", laut = 1.1, ersatzTon = 1.3 },
	renn = { stimme = "Apex", laut = 1.2, ersatzTon = 1.42 },
	supersport = { stimme = "Nova", laut = 1.15, ersatzTon = 1.2 },
	lkw1 = { stimme = "Lkw", laut = 1.0, ton = 1.08, ersatzTon = 0.62 },
	lkw2 = { stimme = "Lkw", laut = 1.1, ton = 1.0, ersatzTon = 0.56 },
	lkw3 = { stimme = "Lkw", laut = 1.2, ton = 0.92, ersatzTon = 0.5 },
	-- NPC traffic (quieter, only the nearest few)
	npc_kleinwagen = { stimme = "Zipster", laut = 0.45, ersatzTon = 1.25 },
	npc_limousine = { stimme = "Fahrschule", laut = 0.45, ton = 0.94, ersatzTon = 0.95 },
	npc_suv = { stimme = "Ranger", laut = 0.5, ersatzTon = 0.8 },
	npc_polizei = { stimme = "Fahrschule", laut = 0.5, ton = 1.06, ersatzTon = 1.05 },
	npc_transporter = { stimme = "Transporter", laut = 0.55, ersatzTon = 0.7 },
	npc_lkw = { stimme = "Lkw", laut = 0.7, ersatzTon = 0.55 },
}
Motorsound.PROFILE = PROFILE

local HOERWEITE = 200        -- studs: further away, a car gets no sound objects at all
local NPC_HOERWEITE = 75

-- which profile a vehicle model uses
function Motorsound.profilName(m)
	local typ = m:GetAttribute("Typ")
	if typ and PROFILE[typ] then return typ end
	if m:GetAttribute("Lkw") then return "lkw" .. math.clamp(m:GetAttribute("Stufe") or 1, 1, 3) end
	return "fahrschule"
end

-- are all files of this voice uploaded?
function Motorsound.eigeneDateien(stimme)
	local d = DATEN[stimme]
	if not d then return false end
	for _, l in d.loops do
		if not l.id or l.id == 0 then return false end
	end
	return true
end

-- ---------------------------------------------------------------
-- Virtual gearbox: rpm from speed and throttle (same model as the preview in motoren.py)
-- ---------------------------------------------------------------
local function gangHoechst(vMax, gang, gaenge)
	return vMax * 1.05 * (gang / gaenge) ^ 0.7
end

function Motorsound.drehzahl(st, d, tempo, gas, vMax)
	local leer, mx, n = d.leerlauf, d.max, d.gaenge
	local gasAbs = math.min(1, math.abs(gas))
	if tempo < 0.5 then
		st.gang = 1
		return leer + gasAbs * (mx * 0.62 - leer) -- revving while standing
	end
	local vorher = st.gang or 1
	st.gang = vorher
	local hochBei = mx * (0.55 + 0.33 * gasAbs)
	while st.gang < n and tempo / gangHoechst(vMax, st.gang, n) * mx > hochBei do st.gang += 1 end
	while st.gang > 1 and tempo / gangHoechst(vMax, st.gang, n) * mx < mx * 0.28 do st.gang -= 1 end
	if st.gang > vorher then st.schaltBis = os.clock() + 0.18 end -- short throttle cut while shifting
	local r = tempo / gangHoechst(vMax, st.gang, n) * mx
	if st.gang == 1 then r = math.max(r, leer + gasAbs * leer * 1.2) end -- clutch slips when pulling away
	return math.clamp(r, leer, mx)
end

-- equal-power cross-fade between the three loops (in log rpm)
function Motorsound.gewichte(r, refs)
	if r <= refs[1] then return 1, 0, 0 end
	if r >= refs[3] then return 0, 0, 1 end
	local i = r < refs[2] and 1 or 2
	local t = math.log(r / refs[i]) / math.log(refs[i + 1] / refs[i])
	local a, b = math.cos(t * math.pi / 2), math.sin(t * math.pi / 2)
	if i == 1 then return a, b, 0 end
	return 0, a, b
end

-- ---------------------------------------------------------------
-- Sound objects
-- ---------------------------------------------------------------
local function neuerSound(teil, id, laeuft)
	local s = Instance.new("Sound")
	s.Name = "Motor"
	s.SoundId = "rbxassetid://" .. tostring(id)
	s.Looped = laeuft ~= false
	s.Volume = 0
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 10
	s.RollOffMaxDistance = HOERWEITE
	local eq = Instance.new("EqualizerSoundEffect")
	eq.LowGain, eq.MidGain, eq.HighGain = 0, 0, 0
	eq.Parent = s
	s.Parent = teil
	return s, eq
end

local function soundsBauen(st, teil, nurNiedrig)
	local p = PROFILE[st.profil] or PROFILE.fahrschule
	local d = DATEN[p.stimme]
	st.loops = {}
	if d and Motorsound.eigeneDateien(p.stimme) then
		st.eigen = true
		for i, l in d.loops do
			if not nurNiedrig or i == 2 then
				local s, eq = neuerSound(teil, l.id)
				st.loops[i] = { sound = s, eq = eq, ref = l.ref }
			end
		end
	else
		st.eigen = false
		local s, eq = neuerSound(teil, Motorsound.ERSATZ_ID)
		st.loops[1] = { sound = s, eq = eq }
	end
	for _, l in st.loops do l.sound:Play() end
end

local function soundsWeg(st)
	if st.loops then
		for _, l in st.loops do l.sound:Destroy() end
	end
	st.loops = nil
	if st.startSound then st.startSound:Destroy() st.startSound = nil end
end

-- sets speed and volume of a car's loops
local function klangSetzen(st, rpm, last, lautstaerke)
	local p = PROFILE[st.profil] or PROFILE.fahrschule
	local d = DATEN[p.stimme]
	local ton = p.ton or 1
	local hoch = -9 + 9 * last          -- off the gas the engine sounds duller
	if st.eigen then
		local refs = { d.loops[1].ref, d.loops[2].ref, d.loops[3].ref }
		local g = { Motorsound.gewichte(rpm, refs) }
		for i, l in st.loops do
			l.sound.PlaybackSpeed = rpm / l.ref * ton
			l.sound.Volume = lautstaerke * (st.nurNiedrig and 1 or g[i])
			l.eq.HighGain = hoch
		end
	else
		local l = st.loops[1]
		local anteil = (rpm - d.leerlauf) / (d.max - d.leerlauf)
		l.sound.PlaybackSpeed = (p.ersatzTon or 1) * (0.62 + 1.1 * anteil)
		l.sound.Volume = lautstaerke
		l.eq.HighGain = hoch
	end
end

-- ---------------------------------------------------------------
-- Player-driven vehicles (driving school car, trucks, own cars, job cars)
-- ---------------------------------------------------------------
local fahrzeuge = {}   -- [model] = state
Motorsound.fahrzeuge = fahrzeuge

local function sitzVon(m)
	local s = m:FindFirstChild("Fahrersitz")
	if s and s:IsA("VehicleSeat") then return s end
	return m:FindFirstChildWhichIsA("VehicleSeat", true)
end

local function suchen()
	for _, m in workspace:GetChildren() do
		if m:IsA("Model") and m:GetAttribute("MaxTempo") and not fahrzeuge[m] then
			fahrzeuge[m] = { modell = m, profil = Motorsound.profilName(m), rpm = 0, gang = 1, last = 0, fade = 0, laeuft = false }
		end
	end
	for m, st in fahrzeuge do
		if not m.Parent then
			soundsWeg(st)
			fahrzeuge[m] = nil
		end
	end
end

local function eigenerHumanoid()
	local c = Players.LocalPlayer and Players.LocalPlayer.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end

local function fahrzeugeAktualisieren(dt, auge)
	local meinHum = eigenerHumanoid()
	local aktiv, grenze = 0, _G.Sparmodus and 3 or 8
	local jetzt = os.clock()
	-- closest first, the own car always
	local liste = {}
	for m, st in fahrzeuge do
		st.chassis = st.chassis and st.chassis.Parent and st.chassis or m:FindFirstChild("Chassis")
		st.sitz = st.sitz and st.sitz.Parent and st.sitz or sitzVon(m)
		if st.chassis and st.sitz then
			st.abstand = (st.chassis.Position - auge).Magnitude
			st.meins = meinHum ~= nil and st.sitz.Occupant == meinHum
			table.insert(liste, st)
		end
	end
	table.sort(liste, function(a, b)
		if a.meins ~= b.meins then return a.meins end
		return a.abstand < b.abstand
	end)
	for _, st in liste do
		local d = DATEN[(PROFILE[st.profil] or PROFILE.fahrschule).stimme]
		local laeuft = st.sitz.Occupant ~= nil
		if laeuft and not st.laeuft then
			st.anSeit = jetzt
			st.rpm = d.leerlauf
			st.startGespielt = false
		end
		st.laeuft = laeuft
		-- fade in after the start sound, fade out when the driver gets out
		local zielFade = laeuft and 1 or 0
		local warten = (laeuft and st.anSeit and jetzt - st.anSeit < 0.8) and 0 or 1
		st.fade += (zielFade * warten - st.fade) * math.min(1, dt * (laeuft and 3 or 1.6))
		local hoerbar = (laeuft or st.fade > 0.01) and (st.meins or st.abstand < HOERWEITE) and aktiv < grenze
		if hoerbar then
			aktiv += 1
			if not st.loops then soundsBauen(st, st.chassis) end
			-- start sound once, if this voice has one and we are close
			if laeuft and not st.startGespielt then
				st.startGespielt = true
				if d.start and d.start ~= 0 and Motorsound.eigeneDateien((PROFILE[st.profil] or PROFILE.fahrschule).stimme) and jetzt - (st.anSeit or 0) < 0.5 then
					local s = neuerSound(st.chassis, d.start, false)
					s.Volume = 0.8 * (PROFILE[st.profil] or PROFILE.fahrschule).laut
					s:Play()
					st.startSound = s
					task.delay(3, function() if st.startSound == s then s:Destroy() st.startSound = nil end end)
				end
			end
			-- speed, throttle and load
			local v = st.chassis.AssemblyLinearVelocity
			local tempo = v:Dot(st.chassis.CFrame.LookVector)
			local betrag = Vector3.new(v.X, 0, v.Z).Magnitude
			local gas
			if st.meins then
				gas = st.sitz.ThrottleFloat or 0
				if _G.TouchGas and _G.TouchGas ~= 0 then gas = _G.TouchGas end
			else
				-- other players: guess the throttle from the acceleration
				local beschl = (betrag - (st.vorTempo or betrag)) / math.max(dt, 1 / 240)
				st.beschl = (st.beschl or 0) + (beschl - (st.beschl or 0)) * math.min(1, dt * 5)
				gas = math.clamp(st.beschl / 8, 0, 1)
				if betrag > 1 then gas = math.max(gas, 0.25) end
			end
			st.vorTempo = betrag
			local last
			if gas > 0 and tempo > -1.5 then last = gas
			elseif gas < 0 and tempo < 1.5 then last = -gas -- reversing
			else last = 0 end
			if st.schaltBis and jetzt < st.schaltBis then last = 0.15 end
			if not laeuft then last = 0 end
			st.last += (last - st.last) * math.min(1, dt * 8)
			local ziel = laeuft and Motorsound.drehzahl(st, d, betrag, gas, st.modell:GetAttribute("MaxTempo") or 130) or d.leerlauf * 0.6
			st.rpm += (ziel - st.rpm) * math.min(1, dt * (ziel > st.rpm and 9 or 6))
			local p = PROFILE[st.profil] or PROFILE.fahrschule
			local laut = p.laut * 0.75 * (0.55 + 0.45 * st.last) * (0.75 + 0.25 * math.min(1, st.rpm / d.max)) * st.fade
			klangSetzen(st, st.rpm, st.last, laut)
		elseif st.loops then
			soundsWeg(st)
		end
	end
end

-- ---------------------------------------------------------------
-- NPC traffic: only the nearest few vehicles get an engine sound
-- ---------------------------------------------------------------
local npcAutos = nil
local npcStatus = {}
local naechsteNpcWahl = 0

function Motorsound.verkehr(autos)
	npcAutos = autos
end

local function npcAktualisieren(dt, auge)
	if not npcAutos then return end
	local jetzt = os.clock()
	if jetzt >= naechsteNpcWahl then
		naechsteNpcWahl = jetzt + 0.3
		local kandidaten = {}
		for _, a in npcAutos do
			local w = a.modell and a.modell:FindFirstChild("Wurzel")
			if w then
				local abstand = (w.Position - auge).Magnitude
				if abstand < NPC_HOERWEITE then table.insert(kandidaten, { a = a, w = w, abstand = abstand }) end
			end
		end
		table.sort(kandidaten, function(x, y) return x.abstand < y.abstand end)
		local gewaehlt = {}
		for i = 1, math.min(#kandidaten, _G.Sparmodus and 2 or 5) do
			gewaehlt[kandidaten[i].a] = kandidaten[i].w
		end
		for a, st in npcStatus do
			if not gewaehlt[a] then
				soundsWeg(st)
				npcStatus[a] = nil
			end
		end
		for a, w in gewaehlt do
			if not npcStatus[a] then
				local art = (a.modell.Name:match("^NPC_(.+)$")) or "limousine"
				local st = { profil = PROFILE["npc_" .. art] and ("npc_" .. art) or "npc_limousine", gang = 1, rpm = 0, last = 0, nurNiedrig = true }
				soundsBauen(st, w, true)
				npcStatus[a] = st
			end
		end
	end
	for a, st in npcStatus do
		local d = DATEN[PROFILE[st.profil].stimme]
		local v = a.v or 0
		local beschl = (v - (st.vorV or v)) / math.max(dt, 1 / 240)
		st.vorV = v
		local gas = beschl > 0.3 and 0.7 or (v > 1 and 0.25 or 0)
		st.last += (gas - st.last) * math.min(1, dt * 4)
		local ziel = Motorsound.drehzahl(st, d, v, gas, 90)
		if st.rpm == 0 then st.rpm = ziel end
		st.rpm += (ziel - st.rpm) * math.min(1, dt * 6)
		klangSetzen(st, st.rpm, st.last, PROFILE[st.profil].laut * 0.7 * (0.6 + 0.4 * st.last))
	end
end

-- ---------------------------------------------------------------
function Motorsound.starten()
	if Motorsound.gestartet then return end
	Motorsound.gestartet = true
	local naechsteSuche = 0
	RunService.Heartbeat:Connect(function(dt)
		dt = math.min(dt, 0.1)
		if os.clock() >= naechsteSuche then
			naechsteSuche = os.clock() + 0.5
			suchen()
		end
		local kam = workspace.CurrentCamera
		local auge = kam and kam.CFrame and kam.CFrame.Position or Vector3.zero
		fahrzeugeAktualisieren(dt, auge)
		npcAktualisieren(dt, auge)
	end)
end

return Motorsound
