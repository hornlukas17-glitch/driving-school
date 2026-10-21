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
		-- our own character is simulated here: stand up locally too (otherwise it sits right back down),
		-- lift it above the roof so it doesn't get stuck in the car, then go limp and fly
		local sitz = (typeof(info.sitz) == "Instance" and info.sitz) or hum.SeatPart
		local function aufstehen()
			local s = hum.SeatPart
			local w = s and s:FindFirstChild("SeatWeld")
			if w then w:Destroy() end
			hum.Sit = false
		end
		aufstehen()
		hum:ChangeState(Enum.HumanoidStateType.Physics)
		if sitz and sitz.Parent then hrp.CFrame = CFrame.new(sitz.Position + Vector3.new(0, 7, 0)) * hrp.CFrame.Rotation end
		-- while flying: never sit down again by touching a seat
		local bis = os.clock() + (info.dauer or 3)
		local wache
		wache = RunService.Heartbeat:Connect(function()
			if os.clock() > bis or not hum.Parent then wache:Disconnect() return end
			if hum.SeatPart then aufstehen() hum:ChangeState(Enum.HumanoidStateType.Physics) end
		end)
		if typeof(info.stoss) == "Vector3" then
			-- set over a few frames: right after standing up a single push gets lost (measured in Studio)
			task.spawn(function()
				local dreh = Vector3.new(math.random(-6, 6), math.random(-3, 3), math.random(-6, 6))
				for _ = 1, 4 do
					if not hrp.Parent then return end
					hrp.AssemblyLinearVelocity = info.stoss
					hrp.AssemblyAngularVelocity = dreh
					RunService.Heartbeat:Wait()
				end
			end)
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
