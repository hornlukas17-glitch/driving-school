-- Own cars: fuel, damage, repairs, insurance and tuning (server).
-- All prices and values can be changed here.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Pflege = {}

Pflege.TANKPREIS = 1.5                 -- coins per % of fuel
Pflege.REICHWEITE = {                  -- km per full tank
	kleinwagen = 10, suv = 7, limousine = 9, sport = 7, renn = 5, supersport = 6,
}
Pflege.PANNENHILFE = { preis = 120, prozent = 15 } -- roadside fuel delivery
Pflege.ABSCHLEPPEN = 200                -- broken car is towed to the garage
Pflege.VERSICHERUNG = 0.08             -- insurance: one-time price = 8 % of the car price
Pflege.VERSICHERT_ANTEIL = 0.3         -- with insurance you pay only 30 % of a repair
Pflege.MOTOR = { 0.12, 0.25, 0.45 }    -- engine stage 1/2/3 costs this share of the car price
Pflege.SPOILER = 300
Pflege.NEON = 400
Pflege.FELGEN = 150
Pflege.NEON_FARBEN = { Color3.fromRGB(40, 120, 255), Color3.fromRGB(255, 40, 60), Color3.fromRGB(40, 255, 120), Color3.fromRGB(190, 60, 255), Color3.fromRGB(255, 120, 200) }
Pflege.FELGEN_FARBEN = { Color3.fromRGB(200, 200, 205), Color3.fromRGB(25, 25, 28), Color3.fromRGB(220, 180, 60), Color3.fromRGB(200, 30, 35), Color3.fromRGB(245, 245, 245) }

local ctx

function Pflege.daten(d, typ)
	d.autoDaten = d.autoDaten or {}
	local a = d.autoDaten[typ]
	if not a then
		a = { tank = 100, zustand = 100, versichert = false, motor = 0, spoiler = false, neon = 0, felgen = 1 }
		d.autoDaten[typ] = a
	end
	return a
end

local function reparaturProProzent(typ)
	local preis = ctx.Auto.MODELLE[typ] and ctx.Auto.MODELLE[typ].preis or 3000
	return math.max(2, math.floor(preis * 0.0008))
end

function Pflege.reparaturKosten(d, typ)
	local a = Pflege.daten(d, typ)
	local kosten = math.ceil((100 - a.zustand) * reparaturProProzent(typ))
	if a.versichert then kosten = math.ceil(kosten * Pflege.VERSICHERT_ANTEIL) end
	return kosten
end

-- extra parts for tuning (welded to the chassis, removed and rebuilt on every change)
local function tuningTeil(modell, chassis, name, groesse, lage, farbe, material)
	local t = Instance.new("Part")
	t.Name = "Tuning_" .. name
	t.Size = groesse
	t.CFrame = lage
	t.Color = farbe
	t.Material = material or Enum.Material.SmoothPlastic
	t.CanCollide = false
	t.Massless = true
	t.CastShadow = false
	t.Parent = modell
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = chassis, t
	w.Parent = t
	return t
end

-- applies fuel, condition and tuning to a spawned car
function Pflege.anwenden(modell, typ, a, nurWerte)
	local chassis = modell:FindFirstChild("Chassis")
	local basis = ctx.Auto.MODELLE[typ] and ctx.Auto.MODELLE[typ].werte
	if not chassis or not basis then return end
	local stufe = a.motor or 0
	modell:SetAttribute("MaxTempo", math.floor(basis.MaxTempo * (1 + 0.07 * stufe) * (a.zustand < 30 and 0.6 or 1)))
	modell:SetAttribute("Antrieb", math.floor(basis.Antrieb * (1 + 0.12 * stufe)))
	modell:SetAttribute("Tank", math.floor(a.tank))
	modell:SetAttribute("Zustand", math.floor(a.zustand))
	modell:SetAttribute("Gesperrt", (a.tank <= 0 or a.zustand <= 0) or nil)
	modell:SetAttribute("Motorstufe", stufe)
	if nurWerte then return end

	for _, t in modell:GetChildren() do
		if t.Name:sub(1, 7) == "Tuning_" then t:Destroy() end
	end
	local laenge = modell:GetAttribute("Laenge") or 15
	local karosserie = modell:FindFirstChild("Karosserie")
	local oben = karosserie and (karosserie.Position.Y + karosserie.Size.Y / 2 - chassis.Position.Y) or 2
	local cf = chassis.CFrame
	if a.spoiler then
		tuningTeil(modell, chassis, "Spoiler", Vector3.new(6, 0.2, 1.4), cf * CFrame.new(0, oben + 1.1, laenge / 2 - 1.2) * CFrame.Angles(math.rad(6), 0, 0), Color3.fromRGB(25, 25, 28))
		for _, s in { -1, 1 } do
			tuningTeil(modell, chassis, "Spoilerstuetze", Vector3.new(0.25, 1.1, 0.6), cf * CFrame.new(s * 2.2, oben + 0.55, laenge / 2 - 1.2), Color3.fromRGB(25, 25, 28))
		end
	end
	if (a.neon or 0) > 0 then
		local farbe = Pflege.NEON_FARBEN[a.neon] or Pflege.NEON_FARBEN[1]
		for _, s in { -1, 1 } do
			local n = tuningTeil(modell, chassis, "Neon", Vector3.new(0.3, 0.15, laenge - 4), cf * CFrame.new(s * 2.4, -0.3, 0), farbe, Enum.Material.Neon)
			local licht = Instance.new("PointLight")
			licht.Color = farbe
			licht.Range = 10
			licht.Brightness = 2
			licht.Parent = n
		end
	end
	local felge = Pflege.FELGEN_FARBEN[a.felgen or 1]
	if felge then
		for _, t in modell:GetChildren() do
			if t.Name == "Felge" then t.Color = felge end
		end
	end
	-- smoke from the engine when the car is badly damaged
	if a.zustand < 50 then
		local rauch = tuningTeil(modell, chassis, "Rauch", Vector3.new(1, 1, 1), cf * CFrame.new(0, oben + 0.5, -laenge / 2 + 2), Color3.new(0, 0, 0))
		rauch.Transparency = 1
		local smoke = Instance.new("Smoke")
		smoke.Color = a.zustand < 25 and Color3.fromRGB(40, 40, 40) or Color3.fromRGB(170, 170, 170)
		smoke.Size = 2
		smoke.RiseVelocity = 4
		smoke.Opacity = a.zustand < 25 and 0.5 or 0.25
		smoke.Parent = rauch
	end
end

-- workshop data for the client
function Pflege.werkstattInfo(p)
	local d = ctx.daten[p]
	local liste = {}
	for _, typ in ctx.Auto.MODELL_REIHENFOLGE do
		if table.find(d.autos or {}, typ) then
			local a = Pflege.daten(d, typ)
			local m = ctx.Auto.MODELLE[typ]
			table.insert(liste, {
				typ = typ, name = m.name, zustand = math.floor(a.zustand), tank = math.floor(a.tank), versichert = a.versichert,
				reparatur = Pflege.reparaturKosten(d, typ), versicherung = math.floor(m.preis * Pflege.VERSICHERUNG),
				motor = a.motor or 0, motorPreis = a.motor < 3 and math.floor(m.preis * Pflege.MOTOR[a.motor + 1]) or nil,
				spoiler = a.spoiler, neon = a.neon or 0, felgen = a.felgen or 1,
			})
		end
	end
	return { autos = liste, geld = d.geld, preise = { spoiler = Pflege.SPOILER, neon = Pflege.NEON, felgen = Pflege.FELGEN } }
end

local function aktivesAuto(p, typ)
	local a = ctx.privatAutos[p]
	if a and a.typ == typ and a.model and a.model.Parent then return a.model end
	return nil
end

function Pflege.werkstatt(p, eingabe)
	local d = ctx.daten[p]
	if type(eingabe) ~= "table" then return { fehler = "?" } end
	local typ = eingabe.typ
	if not table.find(d.autos or {}, typ) then return { fehler = "You don't own this car." } end
	local m = ctx.Auto.MODELLE[typ]
	local a = Pflege.daten(d, typ)
	local preis, text
	if eingabe.art == "reparieren" then
		if a.zustand >= 100 then return { fehler = "This car is already in perfect condition." } end
		preis = Pflege.reparaturKosten(d, typ)
		text = m.name .. " repaired"
	elseif eingabe.art == "versichern" then
		if a.versichert then return { fehler = "This car is already insured." } end
		preis = math.floor(m.preis * Pflege.VERSICHERUNG)
		text = "Insurance for the " .. m.name
	elseif eingabe.art == "motor" then
		if a.motor >= 3 then return { fehler = "The engine is already at the highest stage." } end
		preis = math.floor(m.preis * Pflege.MOTOR[a.motor + 1])
		text = ("Engine stage %d for the %s"):format(a.motor + 1, m.name)
	elseif eingabe.art == "spoiler" then
		preis = a.spoiler and 0 or Pflege.SPOILER
		text = a.spoiler and "Spoiler removed" or "Spoiler for the " .. m.name
	elseif eingabe.art == "neon" then
		local farbe = math.clamp(math.floor(tonumber(eingabe.wert) or 0), 0, #Pflege.NEON_FARBEN)
		preis = (farbe == 0 or a.neon > 0) and 0 or Pflege.NEON
		if a.neon > 0 and farbe > 0 then preis = 100 end -- changing the color
		text = farbe == 0 and "Neon removed" or "Neon underglow"
		eingabe.neonFarbe = farbe
	elseif eingabe.art == "felgen" then
		local farbe = math.clamp(math.floor(tonumber(eingabe.wert) or 1), 1, #Pflege.FELGEN_FARBEN)
		preis = Pflege.FELGEN
		text = "New rim color"
		eingabe.felgenFarbe = farbe
	else
		return { fehler = "Unknown service." }
	end
	if d.geld < preis then
		return { fehler = ("That costs %d coins, you have %d."):format(preis, d.geld) }
	end
	if eingabe.art == "reparieren" then a.zustand = 100
	elseif eingabe.art == "versichern" then a.versichert = true
	elseif eingabe.art == "motor" then a.motor += 1
	elseif eingabe.art == "spoiler" then a.spoiler = not a.spoiler
	elseif eingabe.art == "neon" then a.neon = eingabe.neonFarbe
	elseif eingabe.art == "felgen" then a.felgen = eingabe.felgenFarbe end
	if preis > 0 then
		ctx.geldGeben(p, -preis, text)
	else
		ctx.geaendert(p)
	end
	local modell = aktivesAuto(p, typ)
	if modell then Pflege.anwenden(modell, typ, a) end
	return { text = text .. "! 🔧", info = Pflege.werkstattInfo(p) }
end

-- roadside help: some fuel brought to you, or a tow to the garage when the car is broken
function Pflege.pannenhilfe(p)
	local d = ctx.daten[p]
	local auto = ctx.privatAutos[p]
	if not auto then return { fehler = "Get one of your cars first." } end
	local a = Pflege.daten(d, auto.typ)
	if a.zustand <= 0 then
		if d.geld < Pflege.ABSCHLEPPEN then return { fehler = ("Towing costs %d coins."):format(Pflege.ABSCHLEPPEN) } end
		ctx.geldGeben(p, -Pflege.ABSCHLEPPEN, "Car towed to the garage")
		ctx.autoWeg(p)
		return { text = "Your car was towed to Ben's Garage at the service station. Repair it there before you drive again." }
	end
	if a.tank >= 50 then return { fehler = "Your tank is still at least half full – drive to a gas station." } end
	if d.geld < Pflege.PANNENHILFE.preis then return { fehler = ("Roadside help costs %d coins."):format(Pflege.PANNENHILFE.preis) } end
	ctx.geldGeben(p, -Pflege.PANNENHILFE.preis, "Roadside help")
	a.tank = math.min(100, a.tank + Pflege.PANNENHILFE.prozent)
	Pflege.anwenden(auto.model, auto.typ, a)
	return { text = ("A service van brought you %d %% fuel. Drive to the next gas station! ⛽"):format(Pflege.PANNENHILFE.prozent) }
end

function Pflege.starten(c)
	ctx = c
	local service = workspace:WaitForChild("Karte"):WaitForChild("Service", 10)

	-- fuel pumps
	if service then
		for _, saeule in service:GetDescendants() do
			if saeule:IsA("BasePart") and saeule:GetAttribute("Zapfsaeule") then
				local pp = Instance.new("ProximityPrompt")
				pp.ActionText = "Refuel"
				pp.ObjectText = "Fuel pump"
				pp.HoldDuration = 0.8
				pp.MaxActivationDistance = 12
				pp.RequiresLineOfSight = false
				pp.Parent = saeule
				pp.Triggered:Connect(function(p)
					local d = ctx.daten[p]
					local auto = ctx.privatAutos[p]
					if not d or not auto or not auto.chassis.Parent or (auto.chassis.Position - saeule.Position).Magnitude > 20 then
						ctx.fahrEvent:FireClient(p, { typ = "hinweis", text = "Park your own car right next to the pump first." })
						return
					end
					local a = Pflege.daten(d, auto.typ)
					local fehlt = 100 - a.tank
					if fehlt < 1 then
						ctx.fahrEvent:FireClient(p, { typ = "hinweis", text = "Your tank is already full." })
						return
					end
					local menge = math.min(fehlt, math.floor(d.geld / Pflege.TANKPREIS))
					if menge < 1 then
						ctx.fahrEvent:FireClient(p, { typ = "hinweis", text = "Not enough coins to refuel." })
						return
					end
					local preis = math.ceil(menge * Pflege.TANKPREIS)
					a.tank += menge
					ctx.geldGeben(p, -preis, ("Refueled %d %%"):format(math.floor(menge)))
					Pflege.anwenden(auto.model, auto.typ, a, true)
					if ctx.mission then ctx.mission(p, "tanken", 1) end
				end)
			end
		end
	end

	-- fuel use and crash damage of the own cars
	local letzte = {}  -- [player] = { pos, vel, hinweisTank, hinweisKaputt }
	local takt = 0
	RunService.Heartbeat:Connect(function(dt)
		takt += dt
		if takt < 0.1 then return end
		local schritt = takt
		takt = 0
		for p, auto in ctx.privatAutos do
			local d = ctx.daten[p]
			local chassis = auto.chassis
			if not d or not chassis or not chassis.Parent then
				letzte[p] = nil
				continue
			end
			local a = Pflege.daten(d, auto.typ)
			local l = letzte[p]
			local v = chassis.AssemblyLinearVelocity
			if not l or l.modell ~= auto.model then
				l = { pos = chassis.Position, vel = v, modell = auto.model }
				letzte[p] = l
			end
			-- fuel: per driven km
			local weg = (chassis.Position - l.pos).Magnitude
			l.pos = chassis.Position
			local geaendert, schadenNeu = false, false
			if weg < 50 and weg > 0.05 and a.tank > 0 then
				local km = weg * 0.28 / 1000
				a.tank = math.max(0, a.tank - km / (Pflege.REICHWEITE[auto.typ] or 8) * 100)
				geaendert = math.floor(a.tank) ~= auto.model:GetAttribute("Tank")
				if a.tank <= 0 then
					ctx.fahrEvent:FireClient(p, { typ = "hinweis", text = "⛽ Out of fuel! Use roadside help in 🚗 My Cars." })
				elseif a.tank < 15 and not l.hinweisTank then
					l.hinweisTank = true
					ctx.fahrEvent:FireClient(p, { typ = "hinweis", text = "⛽ Fuel is low! Drive to a gas station." })
				end
			end
			-- crash: a sudden change of speed that braking cannot cause
			local stoss = (v - l.vel).Magnitude / math.max(schritt, 0.05) * 0.1
			l.vel = v
			if stoss > 30 and a.zustand > 0 then
				local schaden = math.min(60, (stoss - 25) * 1.2)
				a.zustand = math.max(0, a.zustand - schaden)
				geaendert, schadenNeu = true, true
				ctx.fahrEvent:FireClient(p, { typ = "hinweis", text = a.zustand <= 0 and "💥 Your car is broken! Use 🚗 My Cars to call the tow truck." or ("💥 Crash! Car condition: %d %%"):format(math.floor(a.zustand)) })
				if ctx.unfall then ctx.unfall(p) end
			end
			if geaendert then Pflege.anwenden(auto.model, auto.typ, a, not schadenNeu) end
		end
	end)
	Players.PlayerRemoving:Connect(function(p) letzte[p] = nil end)
end

return Pflege
