-- 🟢 Start zones (v58): two green areas in front of the driving school. Walk in, wait for other players, go!
--   🙈 BLIND DRIVE – starts as soon as 2 players stand in it (who came first drives).
--   🏁 PARTY TEST  – from 2 players a countdown runs (full with 4 = starts right away).
-- The sign above each zone shows how many players are waiting.
local Players = game:GetService("Players")

local Zonen = {}
Zonen.RADIUS = 5
Zonen.TAKT = 0.3
Zonen.PARTY_COUNTDOWN = 15
Zonen.PARTY_VOLL = 3       -- seconds left when the party zone is full

local ctx
local zonen = {}           -- [1] = blind, [2] = party
Zonen.liste = function() return zonen end

local GRUEN = Color3.fromRGB(60, 255, 120)

local function teil(name, groesse, cf, farbe, material, form, eltern)
	local t = Instance.new("Part")
	t.Name = name
	t.Size = groesse
	t.CFrame = cf
	t.Color = farbe
	t.Material = material
	t.Shape = form or Enum.PartType.Block
	t.Anchored = true
	t.CanCollide = false
	t.CanQuery = false
	t.CanTouch = false
	t.CastShadow = false
	t.Parent = eltern
	return t
end

local function zoneBauen(ordner, name, pos, titel, farbeTitel)
	local m = Instance.new("Model")
	m.Name = name
	local boden = teil("Flaeche", Vector3.new(0.1, Zonen.RADIUS * 2, Zonen.RADIUS * 2),
		CFrame.new(pos + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, 0, math.rad(90)), GRUEN, Enum.Material.Neon, Enum.PartType.Cylinder, m)
	boden.Transparency = 0.15
	local licht = teil("Licht", Vector3.new(6, Zonen.RADIUS * 2, Zonen.RADIUS * 2),
		CFrame.new(pos + Vector3.new(0, 3.1, 0)) * CFrame.Angles(0, 0, math.rad(90)), GRUEN, Enum.Material.Neon, Enum.PartType.Cylinder, m)
	licht.Transparency = 0.88
	local anker = teil("Schild", Vector3.new(1, 1, 1), CFrame.new(pos + Vector3.new(0, 8.5, 0)), GRUEN, Enum.Material.SmoothPlastic, nil, m)
	anker.Transparency = 1
	local g = Instance.new("BillboardGui")
	g.Name = "Anzeige"
	g.Size = UDim2.fromScale(12, 4.6) -- in studs: shrinks with distance, the two signs never overlap
	g.MaxDistance = 160
	g.LightInfluence = 0
	g.Parent = anker
	local kopf = Instance.new("TextLabel")
	kopf.Name = "Titel"
	kopf.Size = UDim2.new(1, 0, 0.45, 0)
	kopf.BackgroundTransparency = 1
	kopf.Font = Enum.Font.FredokaOne
	kopf.TextScaled = true
	kopf.TextColor3 = farbeTitel
	kopf.TextStrokeTransparency = 0
	kopf.Text = titel
	kopf.Parent = g
	local zahl = Instance.new("TextLabel")
	zahl.Name = "Status"
	zahl.Position = UDim2.fromScale(0, 0.45)
	zahl.Size = UDim2.new(1, 0, 0.32, 0)
	zahl.BackgroundTransparency = 1
	zahl.Font = Enum.Font.FredokaOne
	zahl.TextScaled = true
	zahl.TextColor3 = Color3.new(1, 1, 1)
	zahl.TextStrokeTransparency = 0
	zahl.Parent = g
	local info = zahl:Clone()
	info.Name = "Info"
	info.Position = UDim2.fromScale(0, 0.77)
	info.Size = UDim2.new(1, 0, 0.23, 0)
	info.Font = Enum.Font.GothamBold
	info.TextColor3 = Color3.fromRGB(220, 230, 225)
	info.Parent = g
	m.Parent = ordner
	return { model = m, pos = pos, status = zahl, info = info, drin = {}, sperre = {} }
end

local function setzen(z, status, info)
	if z.status.Text ~= status then z.status.Text = status end
	if z.info.Text ~= info then z.info.Text = info end
end

-- player stands on the zone, on foot, and is free
local function stehtDrin(z, p)
	local ch = p.Character
	local hum = ch and ch:FindFirstChildOfClass("Humanoid")
	local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
	if not hum or not hrp or hum.Health <= 0 or hum.SeatPart then return false end
	local d = hrp.Position - z.pos
	if math.abs(d.Y) > 7 or Vector3.new(d.X, 0, d.Z).Magnitude > Zonen.RADIUS + 0.5 then return false end
	return not ctx.beschaeftigt(p)
end

-- keeps z.drin in arrival order; new players get a short hint
local function aktualisieren(z, hinweis)
	for i = #z.drin, 1, -1 do
		if not z.drin[i].Parent or not stehtDrin(z, z.drin[i]) then table.remove(z.drin, i) end
	end
	for _, p in Players:GetPlayers() do
		local gesperrt = z.sperre[p] and os.clock() < z.sperre[p]
		if not gesperrt and not table.find(z.drin, p) and stehtDrin(z, p) then
			table.insert(z.drin, p)
			ctx.fahrEvent:FireClient(p, { typ = "hinweis", text = hinweis, farbe = "gruen" })
		end
	end
end

function Zonen.tick()
	local blind, party = zonen[1], zonen[2]
	if blind then
		aktualisieren(blind, "🙈 Blind Drive: waiting for a second player – bring a friend or wait here!")
		while #blind.drin >= 2 do
			local fahrer = table.remove(blind.drin, 1)
			local copilot = table.remove(blind.drin, 1)
			blind.gestartet = (blind.gestartet or 0) + 1
			task.spawn(function()
				local ok, fehler = ctx.blindPaar(fahrer, copilot)
				if ok then
					if ctx.Beta then ctx.Beta.ereignis(fahrer, "Zone blind drive") ctx.Beta.ereignis(copilot, "Zone blind drive") end
				else
					-- short pause, otherwise both would be retried (and told) every few frames
					for _, sp in { fahrer, copilot } do
						blind.sperre[sp] = os.clock() + 6
						if sp.Parent then ctx.fahrEvent:FireClient(sp, { typ = "hinweis", text = fehler or "Could not start – try again." }) end
					end
				end
			end)
		end
		if #blind.drin == 1 then
			setzen(blind, "1/2 PLAYERS", "Waiting for a partner…")
		else
			setzen(blind, "0/2 PLAYERS", "One drives, one navigates")
		end
	end
	if party then
		aktualisieren(party, "🏁 Party test: the race starts when 2–4 players stand here!")
		local Party = ctx.Party
		local _, rennen = Party.zustand()
		local n = #party.drin
		local mindest = Party.minimum()
		if rennen then
			party.ende = nil
			setzen(party, ("%d/%d PLAYERS"):format(math.min(n, Party.MAX), Party.MAX), "A race is running – next one soon!")
		elseif n >= mindest then
			local jetzt = os.clock()
			if not party.ende then party.ende = jetzt + Zonen.PARTY_COUNTDOWN end
			if n >= Party.MAX then party.ende = math.min(party.ende, jetzt + Zonen.PARTY_VOLL) end
			local rest = math.max(0, math.ceil(party.ende - jetzt))
			setzen(party, ("%d/%d PLAYERS"):format(math.min(n, Party.MAX), Party.MAX), ("Starts in %d s!"):format(rest))
			if jetzt >= party.ende then
				party.ende = nil
				local liste = {}
				for i = 1, math.min(n, Party.MAX) do liste[i] = party.drin[i] end
				for _ = 1, #liste do table.remove(party.drin, 1) end
				party.gestartet = (party.gestartet or 0) + 1
				local r = Party.mitSpielern(liste)
				for _, sp in liste do
					if not (r and table.find(r.spieler, sp)) then party.sperre[sp] = os.clock() + 6 end
				end
				if r and ctx.Beta then
					for _, sp in r.spieler do ctx.Beta.ereignis(sp, "Zone party test") end
				end
			end
		else
			party.ende = nil
			setzen(party, ("%d/%d PLAYERS"):format(n, Party.MAX), n == 0 and "Race your friends!" or "Waiting for more players…")
		end
	end
end

function Zonen.starten(c)
	ctx = c
	Players.PlayerRemoving:Connect(function(p)
		for _, z in zonen do z.sperre[p] = nil end
	end)
	local spawn = c.spawn
	if not spawn then
		warn("[Driving School] FahrschulSpawn missing – no start zones")
		return
	end
	local alt = workspace:FindFirstChild("Startzonen")
	if alt then alt:Destroy() end
	local ordner = Instance.new("Folder")
	ordner.Name = "Startzonen"
	ordner.Parent = workspace
	-- left and right of the entrance, between the door and the first parking bays
	local function bodenBei(lokal)
		local p = (spawn.CFrame * CFrame.new(lokal)).Position
		local par = RaycastParams.new()
		par.FilterType = Enum.RaycastFilterType.Include
		par.FilterDescendantsInstances = { workspace:FindFirstChild("Karte") or workspace, workspace.Terrain }
		local hit = workspace:Raycast(Vector3.new(p.X, spawn.Position.Y + 8, p.Z), Vector3.new(0, -30, 0), par)
		return Vector3.new(p.X, hit and hit.Position.Y or spawn.Position.Y - 0.5, p.Z)
	end
	zonen[1] = zoneBauen(ordner, "BlindDrive", bodenBei(Vector3.new(-10, 0, -2)), "🙈 BLIND DRIVE", Color3.fromRGB(255, 210, 60))
	zonen[2] = zoneBauen(ordner, "PartyTest", bodenBei(Vector3.new(10, 0, -2)), "🏁 PARTY TEST", Color3.fromRGB(120, 220, 255))
	Zonen.tick()
	task.spawn(function()
		while ordner.Parent do
			task.wait(Zonen.TAKT)
			local ok, err = pcall(Zonen.tick)
			if not ok then warn("[Driving School] Startzonen: " .. tostring(err)) end
		end
	end)
end

return Zonen
