-- Robux shop: game passes, coin packs, 2x coin boosts, starter pack, VIP / Premium bonus (server).
--
-- SET UP (Creator Dashboard -> your experience -> Monetization):
--   1. Create the game passes and developer products below with the same names.
--   2. Copy each ID into "id" here. id = 0 means "not set up yet": the button shows "soon".
--   The Robux price shown in the game is read from Roblox, so you only change prices in the dashboard.
-- In Roblox Studio purchases are free test purchases, nobody pays anything there.
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

local Shop = {}

-- one-time purchases (keep forever)
Shop.PASSES = {
	{ key = "vip", id = 0, preis = 399, icon = "👑", name = "VIP",
		text = "2x coins from every job and reward, golden VIP tag, 2 VIP paint colors." },
	{ key = "xp2", id = 0, preis = 249, icon = "⚡", name = "2x XP",
		text = "Level up twice as fast – unlock the big trucks and cars sooner." },
	{ key = "nacht", id = 0, preis = 699, icon = "🌙", name = "Vanta GS Night Edition",
		text = "Exclusive car: midnight black, gold rims, purple underglow, 195 km/h. Only with this pass." },
	{ key = "garage", id = 0, preis = 199, icon = "🎨", name = "Paint Studio",
		text = "6 exclusive paint colors for all your cars." },
	{ key = "banane", id = 0, preis = 149, icon = "🍌", name = "Banana Launcher",
		text = "Press B (or the 🍌 button) while driving to drop banana peels behind your car. Watch your friends spin out!" },
	{ key = "hupen", id = 0, preis = 99, icon = "📯", name = "Funny Horn Pack",
		text = "4 crazy horns for every car: clown, duck, air horn and fanfare. Press H to honk – everybody hears it!" },
}

-- can be bought again and again (except the starter pack)
Shop.PRODUKTE = {
	{ key = "starter", id = 0, preis = 99, name = "Starter Pack", geld = 7500, boost = 30, einmal = true,
		text = "7,500 coins + 30 min 2x coins. Only once per player!" },
	{ key = "boost", id = 0, preis = 79, name = "2x Coins – 30 min", boost = 30, text = "Double coins for 30 minutes of play." },
	{ key = "ufo", id = 0, preis = 49, name = "👽 Alien Invasion", chaos = "ufo", tag = "FUN",
		text = "A UFO beams up EVERY driver on the server – with your name on it!" },
	{ key = "bananen", id = 0, preis = 29, name = "🍌 Banana Rain", chaos = "bananen", tag = "FUN",
		text = "Banana peels rain down in front of every driver on the server!" },
	{ key = "coins1", id = 0, preis = 49, name = "2,500 coins", geld = 2500 },
	{ key = "coins2", id = 0, preis = 179, name = "10,000 coins", geld = 10000 },
	{ key = "coins3", id = 0, preis = 449, name = "30,000 coins", geld = 30000, tag = "POPULAR" },
	{ key = "coins4", id = 0, preis = 1199, name = "100,000 coins", geld = 100000, tag = "BEST VALUE" },
}

-- bonus shares on earned coins / XP (purchases and admin money never get a bonus)
Shop.BONUS = { vip = 1.0, boost = 1.0, xp2 = 1.0, premium = 0.1, freunde = 0.1 }

-- exclusive paint colors (index 9 and up in the color list of "My Cars")
Shop.FARBEN = {
	{ name = "VIP Gold", farbe = Color3.fromRGB(212, 168, 60), passes = { "vip", "garage" } },
	{ name = "Pearl White", farbe = Color3.fromRGB(236, 232, 222), passes = { "vip", "garage" } },
	{ name = "Midnight Purple", farbe = Color3.fromRGB(45, 25, 80), passes = { "garage" } },
	{ name = "Racing Green", farbe = Color3.fromRGB(20, 70, 45), passes = { "garage" } },
	{ name = "Candy Red", farbe = Color3.fromRGB(150, 10, 25), passes = { "garage" } },
	{ name = "Ice Blue", farbe = Color3.fromRGB(150, 200, 235), passes = { "garage" } },
}

local ctx
local besitz = {}   -- [player] = { key = true } (from Roblox, cached)
local preise = {}   -- [id] = real Robux price from Roblox

local function passNach(feld, wert)
	for _, p in Shop.PASSES do if p[feld] == wert then return p end end
end
local function produktNach(feld, wert)
	for _, p in Shop.PRODUKTE do if p[feld] == wert then return p end end
end

function Shop.hat(p, key)
	if besitz[p] and besitz[p][key] then return true end
	local d = ctx and ctx.daten[p]
	return d ~= nil and d.passes ~= nil and d.passes[key] == true -- test grants in Studio
end

function Shop.premium(p)
	local ok, typ = pcall(function() return p.MembershipType end)
	return ok and typ == Enum.MembershipType.Premium
end

function Shop.boostRest(p)
	local d = ctx and ctx.daten[p]
	return d and math.max(0, (d.boostBis or 0) - os.time()) or 0
end

-- multiplier for earned coins / XP
function Shop.faktor(p, art)
	local f = 1
	if art == "geld" then
		if Shop.hat(p, "vip") then f += Shop.BONUS.vip end
		if Shop.boostRest(p) > 0 then f += Shop.BONUS.boost end
	else
		if Shop.hat(p, "xp2") then f += Shop.BONUS.xp2 end
	end
	if Shop.premium(p) then f += Shop.BONUS.premium end
	if p:GetAttribute("FreundeBonus") then f += Shop.BONUS.freunde end
	return f
end

function Shop.farbeErlaubt(p, nr)
	if nr <= 8 then return true end
	local f = Shop.FARBEN[nr - 8]
	if not f then return false end
	for _, key in f.passes do
		if Shop.hat(p, key) then return true end
	end
	return false
end

local function attribute(p)
	p:SetAttribute("VIP", Shop.hat(p, "vip") or nil)
	p:SetAttribute("BananenWerfer", Shop.hat(p, "banane") or nil)
	p:SetAttribute("HupenPack", Shop.hat(p, "hupen") or nil)
	p:SetAttribute("BoostBis", ctx.daten[p] and ctx.daten[p].boostBis or nil)
	p:SetAttribute("GeldFaktor", Shop.faktor(p, "geld"))
	p:SetAttribute("XpFaktor", Shop.faktor(p, "xp"))
end
Shop.attribute = attribute

-- golden tag above VIP players
local function vipSchild(p)
	local figur = p.Character
	local kopf = figur and figur:FindFirstChild("Head")
	if not kopf then return end
	local alt = kopf:FindFirstChild("VipSchild")
	if not Shop.hat(p, "vip") then
		if alt then alt:Destroy() end
		return
	end
	if alt then return end
	local g = Instance.new("BillboardGui")
	g.Name = "VipSchild"
	g.Size = UDim2.fromOffset(70, 24)
	g.StudsOffset = Vector3.new(0, 2.6, 0)
	g.AlwaysOnTop = false
	g.MaxDistance = 80
	g.Parent = kopf
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundColor3 = Color3.fromRGB(40, 32, 10)
	t.BackgroundTransparency = 0.25
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.TextColor3 = Color3.fromRGB(255, 210, 70)
	t.Text = "👑 VIP"
	t.Parent = g
	Instance.new("UICorner", t)
end

local function besitzLaden(p)
	besitz[p] = besitz[p] or {}
	for _, pass in Shop.PASSES do
		if pass.id ~= 0 then
			local ok, hat = pcall(function() return MarketplaceService:UserOwnsGamePassAsync(p.UserId, pass.id) end)
			if ok and hat then besitz[p][pass.key] = true end
		end
	end
end

-- the car that comes with a pass is added to the garage automatically
local function passAutos(p)
	local d = ctx.daten[p]
	if not d then return end
	for typ, m in ctx.Auto.MODELLE do
		if m.pass and Shop.hat(p, m.pass) and not table.find(d.autos or {}, typ) then
			d.autos = d.autos or {}
			table.insert(d.autos, typ)
			if m.tuning then
				local a = ctx.Pflege.daten(d, typ)
				for k, v in m.tuning do a[k] = v end
			end
			ctx.geaendert(p)
			ctx.fahrEvent:FireClient(p, { typ = "belohnung", text = ("🌙 The %s is in your garage! Get it with 🚗 My Cars."):format(m.name) })
		end
	end
end
Shop.passAutos = passAutos

function Shop.spielerDa(p)
	besitzLaden(p)
	local function warten()
		for _ = 1, 40 do
			if ctx.daten[p] then return true end
			task.wait(0.25)
		end
	end
	if not warten() then return end
	attribute(p)
	passAutos(p)
	if p.Character then vipSchild(p) end
	p.CharacterAdded:Connect(function()
		task.wait(1)
		vipSchild(p)
	end)
end

-- shop window data for the client
function Shop.status(p)
	if not ctx then return { fehler = "The shop is still loading – try again in a moment." } end
	local d = ctx.daten[p]
	local passes, produkte = {}, {}
	for _, pass in Shop.PASSES do
		table.insert(passes, { key = pass.key, id = pass.id, icon = pass.icon, name = pass.name, text = pass.text,
			preis = preise[pass.id] or pass.preis, hat = Shop.hat(p, pass.key), bereit = pass.id ~= 0 })
	end
	for _, pr in Shop.PRODUKTE do
		if not (pr.einmal and d.starterGekauft) then
			table.insert(produkte, { key = pr.key, id = pr.id, name = pr.name, text = pr.text, tag = pr.tag, geld = pr.geld, spass = pr.chaos ~= nil,
				preis = preise[pr.id] or pr.preis, bereit = pr.id ~= 0, einmal = pr.einmal })
		end
	end
	return {
		passes = passes, produkte = produkte, geld = d.geld, boost = Shop.boostRest(p), premium = Shop.premium(p),
		freunde = p:GetAttribute("FreundeBonus") == true, geldFaktor = Shop.faktor(p, "geld"), xpFaktor = Shop.faktor(p, "xp"),
		bonus = Shop.BONUS,
	}
end

-- what a developer product gives (also used by the Studio test command)
local function gewaehren(p, pr)
	local d = ctx.daten[p]
	if pr.geld then ctx.geldGeben(p, pr.geld, pr.name, true) end
	if pr.boost then
		d.boostBis = math.max(os.time(), d.boostBis or 0) + pr.boost * 60
	end
	if pr.einmal then d.starterGekauft = true end
	if pr.chaos and ctx.Chaos then
		if pr.chaos == "ufo" then ctx.Chaos.alleEntfuehren(p) else ctx.Chaos.bananenRegen(p) end
	end
	attribute(p)
	ctx.geaendert(p)
	ctx.fahrEvent:FireClient(p, { typ = "belohnung", text = "🛒 Thank you! " .. pr.name .. " received." })
end
Shop.gewaehren = gewaehren

function Shop.testKauf(p, key)
	if not RunService:IsStudio() then return { fehler = "Only in Studio." } end
	local pass = passNach("key", key)
	if pass then
		local d = ctx.daten[p]
		d.passes = d.passes or {}
		d.passes[key] = not d.passes[key] or nil
		attribute(p)
		vipSchild(p)
		passAutos(p)
		ctx.geaendert(p)
		return { text = ("Test: pass %s %s."):format(pass.name, d.passes[key] and "ON" or "OFF") }
	end
	local pr = produktNach("key", key)
	if pr then
		gewaehren(p, pr)
		return { text = "Test purchase: " .. pr.name }
	end
	return { fehler = "Unknown item." }
end

function Shop.starten(c)
	ctx = c
	-- real Robux prices from Roblox (so the shop always shows the price you set in the dashboard)
	task.spawn(function()
		for _, liste in { { Shop.PASSES, Enum.InfoType.GamePass }, { Shop.PRODUKTE, Enum.InfoType.Product } } do
			for _, e in liste[1] do
				if e.id ~= 0 then
					local ok, info = pcall(function() return MarketplaceService:GetProductInfo(e.id, liste[2]) end)
					if ok and type(info) == "table" and info.PriceInRobux then preise[e.id] = info.PriceInRobux end
				end
			end
		end
	end)

	-- developer products: must be safe against double delivery (Roblox may call this again)
	MarketplaceService.ProcessReceipt = function(info)
		local p = Players:GetPlayerByUserId(info.PlayerId)
		local d = p and ctx.daten[p]
		if not d then return Enum.ProductPurchaseDecision.NotProcessedYet end
		d.kaeufe = d.kaeufe or {}
		if table.find(d.kaeufe, info.PurchaseId) then return Enum.ProductPurchaseDecision.PurchaseGranted end
		local pr = produktNach("id", info.ProductId)
		if not pr then
			warn("Shop: unknown product " .. tostring(info.ProductId))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		table.insert(d.kaeufe, info.PurchaseId)
		while #d.kaeufe > 100 do table.remove(d.kaeufe, 1) end
		gewaehren(p, pr)
		if not ctx.speichernSofort(p) then
			-- the coins are in the game already; the next regular save (or leaving) stores them
			warn("Shop: purchase granted, saving right now failed (will be saved later)")
		end
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(p, id, gekauft)
		if not gekauft then return end
		local pass = passNach("id", id)
		if not pass then return end
		besitz[p] = besitz[p] or {}
		besitz[p][pass.key] = true
		attribute(p)
		vipSchild(p)
		passAutos(p)
		ctx.fahrEvent:FireClient(p, { typ = "belohnung", text = ("%s %s unlocked – thank you!"):format(pass.icon, pass.name) })
	end)

	Players.PlayerMembershipChanged:Connect(function(p)
		if ctx.daten[p] then attribute(p) end
	end)

	-- boost timer runs out -> update the multipliers shown in the game
	task.spawn(function()
		while true do
			task.wait(15)
			for _, p in Players:GetPlayers() do
				if ctx.daten[p] then attribute(p) end
			end
		end
	end)

	Players.PlayerAdded:Connect(function(p) task.spawn(Shop.spielerDa, p) end)
	for _, p in Players:GetPlayers() do task.spawn(Shop.spielerDa, p) end
	Players.PlayerRemoving:Connect(function(p) besitz[p] = nil end)
end

return Shop
