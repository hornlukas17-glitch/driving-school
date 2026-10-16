-- Daily missions (3 new ones every day) and the leaderboards in the city park.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local Missionen = {}

Missionen.ARTEN = {
	{ id = "lieferung", text = "Deliver %d packages or pizzas", ziele = { 4, 6, 8 }, geld = 250, xp = 80 },
	{ id = "jobs", text = "Finish %d delivery or taxi jobs", ziele = { 1, 2, 3 }, geld = 300, xp = 100 },
	{ id = "km", text = "Drive %d km in your own car", ziele = { 2, 3, 5 }, geld = 200, xp = 80 },
	{ id = "kontrolle", text = "Pass a police check without a fine", ziele = { 1 }, geld = 150, xp = 60 },
	{ id = "tanken", text = "Refuel your car at a gas station", ziele = { 1 }, geld = 100, xp = 40 },
	{ id = "perfekt", text = "Finish a lesson or test without mistakes", ziele = { 1 }, geld = 200, xp = 80 },
	{ id = "taxi", text = "Drive %d taxi passengers", ziele = { 2, 3, 4 }, geld = 250, xp = 90 },
	{ id = "ausweichen", text = "Dodge %d chaos events (cows, ducks, bananas …)", ziele = { 2, 3, 5 }, geld = 250, xp = 90 },
	{ id = "banane", text = "Spin out on a banana peel", ziele = { 1 }, geld = 150, xp = 50 },
}
Missionen.PRO_TAG = 3

local ctx

local function heute()
	return os.date("!%Y-%m-%d")
end

-- the same 3 missions for a player all day (depends on the date and the player)
local function neueListe(p)
	local tag = heute()
	local zahl = 0
	for i = 1, #tag do zahl += string.byte(tag, i) * i end
	local zufall = Random.new(zahl * 7919 + p.UserId)
	local arten = table.clone(Missionen.ARTEN)
	local liste = {}
	for _ = 1, Missionen.PRO_TAG do
		local art = table.remove(arten, zufall:NextInteger(1, #arten))
		table.insert(liste, { id = art.id, ziel = art.ziele[zufall:NextInteger(1, #art.ziele)], stand = 0, fertig = false })
	end
	return { tag = tag, liste = liste }
end

local function aktuell(p)
	local d = ctx and ctx.daten[p] -- nil while the server is still starting up
	if not d then return nil end
	d = ctx.daten[p]
	if not d then return nil end
	if not d.missionen or d.missionen.tag ~= heute() then
		d.missionen = neueListe(p)
	end
	return d.missionen
end

local function art(id)
	for _, a in Missionen.ARTEN do
		if a.id == id then return a end
	end
end

function Missionen.fortschritt(p, id, menge)
	local m = aktuell(p)
	if not m then return end
	for _, mission in m.liste do
		if mission.id == id and not mission.fertig then
			mission.stand = math.min(mission.ziel, mission.stand + (menge or 1))
			if mission.stand >= mission.ziel then
				mission.fertig = true
				local a = art(id)
				ctx.geldGeben(p, a.geld, "Daily mission")
				ctx.xpGeben(p, a.xp, "Daily mission")
				ctx.fahrEvent:FireClient(p, { typ = "mission", text = a.text:format(mission.ziel) })
			end
		end
	end
end

function Missionen.status(p)
	local m = aktuell(p)
	if not m then return { fehler = "Still loading – try again in a moment.", liste = {} } end
	local liste = {}
	for _, mission in m.liste do
		local a = art(mission.id)
		table.insert(liste, { text = a.text:format(mission.ziel), stand = mission.stand, ziel = mission.ziel, fertig = mission.fertig, geld = a.geld, xp = a.xp })
	end
	return { liste = liste }
end

-- ---------------------------------------------------------------
-- Leaderboards (saved for all servers; in Studio without API access only online players)
-- ---------------------------------------------------------------
local LISTEN = {
	Level = { titel = "⭐ TOP LEVEL", wert = function(d) return math.floor(d.xp or 0) end, format = function(w) return ("Lv %d"):format(math.floor(math.sqrt(w / 150)) + 1) end },
	Km = { titel = "🛣 MOST KM DRIVEN", wert = function(d) return math.floor((d.kmGesamt or 0) * 10) end, format = function(w) return ("%.1f km"):format(w / 10) end },
	Perfekt = { titel = "🏆 PERFECT TESTS", wert = function(d) return math.floor(d.perfekt or 0) end, format = function(w) return ("%d ×"):format(w) end },
}

function Missionen.starten(c)
	ctx = c
	local stores = {}
	for name in LISTEN do
		local ok, store = pcall(function() return DataStoreService:GetOrderedDataStore("Rangliste_" .. name) end)
		if ok then stores[name] = store end
	end
	local namen = {}
	local function nameVon(id)
		if namen[id] then return namen[id] end
		local ok, n = pcall(function() return Players:GetNameFromUserIdAsync(id) end)
		namen[id] = ok and n or ("Player " .. id)
		return namen[id]
	end

	local function tafeln()
		local t = {}
		local park = workspace:FindFirstChild("Karte") and workspace.Karte:FindFirstChild("Service")
		local m = park and park:FindFirstChild("Bestenlisten")
		if m then
			for _, teil in m:GetChildren() do
				if teil:GetAttribute("Liste") then t[teil:GetAttribute("Liste")] = teil end
			end
		end
		return t
	end

	local function zeichnen(tafel, titel, zeilen)
		local g = tafel:FindFirstChild("Anzeige")
		if not g then
			g = Instance.new("SurfaceGui")
			g.Name = "Anzeige"
			g.Face = Enum.NormalId.Front
			g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			g.PixelsPerStud = 30
			g.Parent = tafel
		end
		g:ClearAllChildren()
		local kopf = Instance.new("TextLabel")
		kopf.Size = UDim2.new(1, 0, 0.14, 0)
		kopf.BackgroundColor3 = Color3.fromRGB(200, 30, 40)
		kopf.Font = Enum.Font.GothamBlack
		kopf.TextScaled = true
		kopf.TextColor3 = Color3.new(1, 1, 1)
		kopf.Text = titel
		kopf.Parent = g
		for i, z in zeilen do
			local l = Instance.new("TextLabel")
			l.Position = UDim2.new(0.04, 0, 0.15 + (i - 1) * 0.083, 0)
			l.Size = UDim2.new(0.92, 0, 0.075, 0)
			l.BackgroundTransparency = 1
			l.Font = i <= 3 and Enum.Font.GothamBlack or Enum.Font.GothamBold
			l.TextScaled = true
			l.TextXAlignment = Enum.TextXAlignment.Left
			l.TextColor3 = i == 1 and Color3.fromRGB(255, 215, 80) or (i == 2 and Color3.fromRGB(220, 220, 230) or (i == 3 and Color3.fromRGB(230, 160, 100) or Color3.new(1, 1, 1)))
			l.Text = ("%d. %s  –  %s"):format(i, z[1], z[2])
			l.Parent = g
		end
	end

	task.spawn(function()
		task.wait(10)
		while true do
			-- save the scores of everybody online
			for _, p in Players:GetPlayers() do
				local d = ctx.daten[p]
				if d then
					for name, liste in LISTEN do
						if stores[name] then
							pcall(function() stores[name]:SetAsync(tostring(p.UserId), liste.wert(d)) end)
						end
					end
				end
			end
			-- read the top 10 and show them on the boards
			local t = tafeln()
			for name, liste in LISTEN do
				local zeilen = {}
				local ok = stores[name] and pcall(function()
					local seite = stores[name]:GetSortedAsync(false, 10):GetCurrentPage()
					for _, eintrag in seite do
						table.insert(zeilen, { nameVon(tonumber(eintrag.key)), liste.format(eintrag.value) })
					end
				end)
				if not ok or #zeilen == 0 then
					-- fallback: players on this server
					local online = {}
					for _, p in Players:GetPlayers() do
						local d = ctx.daten[p]
						if d then table.insert(online, { p.DisplayName, liste.wert(d) }) end
					end
					table.sort(online, function(a, b) return a[2] > b[2] end)
					zeilen = {}
					for i = 1, math.min(10, #online) do
						table.insert(zeilen, { online[i][1], liste.format(online[i][2]) })
					end
				end
				if t[name] then zeichnen(t[name], liste.titel, zeilen) end
			end
			task.wait(120)
		end
	end)
end

return Missionen
