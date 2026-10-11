-- Traffic offences: speed cameras, red lights, fines, penalty points, license withdrawal
-- and the personal traffic record. All values can be changed here.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Strafen = {}

Strafen.PUNKTE_LIMIT = 8             -- from this many points the license is withdrawn
Strafen.NACHSCHULUNG_PREIS = 500     -- retraining course after a withdrawal
Strafen.TOLERANZ = 3                 -- km/h tolerance of the speed cameras
Strafen.PUNKT_VERFALL = 45 * 60      -- one point expires after this much time online (seconds)
-- speeding: over the limit by up to "bis" km/h -> fine and points
Strafen.TEMPO = {
	{ bis = 10, geld = 30, punkte = 0 },
	{ bis = 20, geld = 80, punkte = 1 },
	{ bis = 30, geld = 150, punkte = 1 },
	{ bis = 40, geld = 250, punkte = 2 },
	{ bis = math.huge, geld = 400, punkte = 2 },
}
Strafen.ROTLICHT = { geld = 90, punkte = 1 }
Strafen.FLUCHT = { geld = 250, punkte = 2 }

local ctx -- shared things from the main server script (data, money, events, ...)

function Strafen.tempoStrafe(zuSchnell)
	for _, stufe in Strafen.TEMPO do
		if zuSchnell <= stufe.bis then return stufe.geld, stufe.punkte end
	end
	local letzte = Strafen.TEMPO[#Strafen.TEMPO]
	return letzte.geld, letzte.punkte
end

-- takes the license away (all classes) until the retraining course and a new driving test
function Strafen.entziehen(p)
	local d = ctx.daten[p]
	if not d or not d.fuehrerschein then return end
	d.fuehrerschein = false
	d.entzogen = true
	d.nachschulung = false
	if d.lkwFuehrerschein then
		d.lkwFuehrerschein = false
		d.lkwGesperrt = true -- class C comes back automatically with the new class B
	end
	table.insert(d.historie, 1, { t = os.time(), text = "LICENSE WITHDRAWN (" .. d.punkte .. " points)", geld = 0, punkte = 0 })
	d.punkte = 0
	ctx.geaendert(p)
	ctx.lizenzEntfernen(p)
	-- you keep your car - but if you keep driving, the police is looking for you
	ctx.fahrEvent:FireClient(p, { typ = "entzug", limit = Strafen.PUNKTE_LIMIT, preis = Strafen.NACHSCHULUNG_PREIS })
end

-- one entry in the traffic record: fine, points, maybe withdrawal
function Strafen.eintrag(p, text, geld, punkte)
	local d = ctx.daten[p]
	if not d then return end
	d.historie = d.historie or {}
	d.punkte = (d.punkte or 0) + (punkte or 0)
	table.insert(d.historie, 1, { t = os.time(), text = text, geld = geld or 0, punkte = punkte or 0 })
	while #d.historie > 40 do table.remove(d.historie) end
	if (geld or 0) > 0 then
		ctx.geldGeben(p, -geld, text)
	else
		ctx.geaendert(p)
	end
	if (punkte or 0) > 0 then
		ctx.fahrEvent:FireClient(p, { typ = "punkte", punkte = d.punkte, limit = Strafen.PUNKTE_LIMIT, plus = punkte, text = text })
	end
	if d.fuehrerschein and d.punkte >= Strafen.PUNKTE_LIMIT then
		Strafen.entziehen(p)
	end
end

function Strafen.akte(p)
	local d = ctx.daten[p]
	return {
		punkte = d.punkte or 0, limit = Strafen.PUNKTE_LIMIT, fuehrerschein = d.fuehrerschein, entzogen = d.entzogen,
		nachschulung = d.nachschulung, lkw = d.lkwFuehrerschein, historie = d.historie or {}, preis = Strafen.NACHSCHULUNG_PREIS,
		naechsterVerfall = (d.punkte or 0) > 0 and math.max(0, Strafen.PUNKT_VERFALL - (d.punkteZeit or 0)) or nil,
	}
end

function Strafen.nachschulungBuchen(p)
	local d = ctx.daten[p]
	if not d.entzogen then return { fehler = "Your license is not withdrawn." } end
	if d.nachschulung then return { fehler = "You already did the retraining course. Now book the driving test with Anna." } end
	if d.geld < Strafen.NACHSCHULUNG_PREIS then
		return { fehler = ("The retraining course costs %d coins. You have %d."):format(Strafen.NACHSCHULUNG_PREIS, d.geld) }
	end
	ctx.geldGeben(p, -Strafen.NACHSCHULUNG_PREIS, "Retraining course")
	d.nachschulung = true
	table.insert(d.historie, 1, { t = os.time(), text = "Retraining course completed", geld = Strafen.NACHSCHULUNG_PREIS, punkte = 0 })
	ctx.geaendert(p)
	return { ok = true }
end

function Strafen.starten(c)
	ctx = c
	local karte = workspace:WaitForChild("Karte")
	local blitzerOrdner = karte:FindFirstChild("Blitzer")
	local ampeln = karte:FindFirstChild("Ampeln")
	local zuletzt = {}   -- [player][camera] = time of the last flash
	local letztePos = {} -- [player] = last position (red light check)

	local function blitzen(kamera)
		local b = kamera:FindFirstChild("Blitz")
		if not b then return end
		b.Color = Color3.new(1, 1, 1)
		b.Material = Enum.Material.Neon
		local licht = b:FindFirstChildOfClass("PointLight") or Instance.new("PointLight")
		licht.Range = 30
		licht.Brightness = 6
		licht.Enabled = true
		licht.Parent = b
		task.delay(0.18, function()
			b.Color = Color3.fromRGB(60, 60, 60)
			b.Material = Enum.Material.SmoothPlastic
			licht.Enabled = false
		end)
	end

	local takt, minuteTakt = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		takt += dt
		minuteTakt += dt
		if minuteTakt >= 60 then
			-- old points expire while you play
			minuteTakt = 0
			for _, p in Players:GetPlayers() do
				local d = ctx.daten[p]
				if d and (d.punkte or 0) > 0 then
					d.punkteZeit = (d.punkteZeit or 0) + 60
					if d.punkteZeit >= Strafen.PUNKT_VERFALL then
						d.punkteZeit = 0
						d.punkte -= 1
						table.insert(d.historie, 1, { t = os.time(), text = "1 point expired", geld = 0, punkte = -1 })
						ctx.geaendert(p)
					end
				end
			end
		end
		if takt < 0.1 then return end
		takt = 0
		for _, p in Players:GetPlayers() do
			local d = ctx.daten[p]
			local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
			local sitz = hum and hum.SeatPart
			local modell = sitz and sitz:IsA("VehicleSeat") and sitz.Parent
			local chassis = modell and modell:FindFirstChild("Chassis")
			if not (d and chassis) then
				letztePos[p] = nil
				continue
			end
			local pos = Vector3.new(chassis.Position.X, 0, chassis.Position.Z)
			local tempo = chassis.AssemblyLinearVelocity.Magnitude
			local lektion = ctx.lektionen[p]
			zuletzt[p] = zuletzt[p] or {}

			-- speed cameras (measure both directions)
			if blitzerOrdner then
				for _, kamera in blitzerOrdner:GetChildren() do
					local punkt = kamera:GetAttribute("Messpunkt")
					if punkt and (pos - punkt).Magnitude < 14 and os.clock() - (zuletzt[p][kamera] or 0) > 6 then
						local limit = ctx.Regeln.tempolimit(punkt)
						if tempo > limit + Strafen.TOLERANZ then
							zuletzt[p][kamera] = os.clock()
							blitzen(kamera)
							local zuSchnell = math.floor(tempo - limit)
							if lektion then
								ctx.warnung(p, lektion, ("📸 Speed camera! %d km/h in a %d zone."):format(math.floor(tempo), limit))
								ctx.fahrEvent:FireClient(p, { typ = "blitz" })
							else
								local geld, punkte = Strafen.tempoStrafe(zuSchnell)
								ctx.fahrEvent:FireClient(p, { typ = "blitz", text = ("📸 %d km/h in a %d zone: -%d coins%s"):format(math.floor(tempo), limit, geld, punkte > 0 and (", +" .. punkte .. " point" .. (punkte > 1 and "s" or "")) or "") })
								Strafen.eintrag(p, ("Speed camera: %d km/h in a %d zone"):format(math.floor(tempo), limit), geld, punkte)
							end
						end
					end
				end
			end

			-- red lights (lessons check this themselves)
			local vorher = letztePos[p]
			if vorher and not lektion and ampeln then
				for _, ampel in ampeln:GetChildren() do
					if ampel:GetAttribute("Phase") == "Rot" then
						local L = ampel:GetAttribute("Haltelinie")
						local richtung = ampel:GetAttribute("Anfahrt")
						local rechts = ampel:GetAttribute("Rechts")
						if L and richtung and rechts and (pos - L).Magnitude < 30 then
							local a = (vorher - L):Dot(richtung)
							local b = (pos - L):Dot(richtung)
							if a > 0 and b <= 0 and math.abs((pos - L):Dot(rechts)) < 7 then
								ctx.fahrEvent:FireClient(p, { typ = "blitz", text = ("🚦 Red light! -%d coins, +%d point"):format(Strafen.ROTLICHT.geld, Strafen.ROTLICHT.punkte) })
								Strafen.eintrag(p, "Drove through a red light", Strafen.ROTLICHT.geld, Strafen.ROTLICHT.punkte)
							end
						end
					end
				end
			end
			letztePos[p] = pos
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		zuletzt[p] = nil
		letztePos[p] = nil
	end)
end

return Strafen
