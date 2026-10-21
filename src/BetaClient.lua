-- v54 beta (client): invite friends, report "map loaded", 🧑‍🏫 instructor mode light.
-- Required by FuehrerscheinClient (kept separate because that script is close to Roblox' 200,000-character limit).
local Players = game:GetService("Players")
local BetaClient = {}

function BetaClient.starten(k)
	local spieler, frage, warnen, GRUEN, BLAU = k.spieler, k.frage, k.warnen, k.GRUEN, k.BLAU
	-- 📨 invite friends (Roblox checks if this account may send invites; the server rewards new friends who join)
	_G.FreundeEinladen = function()
		local Social = game:GetService("SocialService")
		local okKann, kann = pcall(function() return Social:CanSendGameInviteAsync(spieler) end)
		if not okKann or not kann then
			warnen("📨 Invites are not available for your account right now.", Color3.fromRGB(200, 140, 30))
			return
		end
		local ok = pcall(function()
			local opt = Instance.new("ExperienceInviteOptions")
			opt.PromptMessage = "Survive the chaos with me in Crazy Driving School!"
			opt.LaunchData = "invite"
			Social:PromptGameInvite(spieler, opt)
		end)
		if not ok then pcall(function() Social:PromptGameInvite(spieler) end) end
		task.spawn(frage, "eingeladen")
	end

	-- 🗺️ analytics: how long until the map around the player has arrived (streaming)
	task.spawn(function()
		local start = os.clock()
		local char = spieler.Character or spieler.CharacterAdded:Wait()
		local hrp = char:WaitForChild("HumanoidRootPart", 60)
		local karte = workspace:WaitForChild("Karte", 60)
		if not hrp or not karte then return end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { karte }
		for _ = 1, 300 do -- max ~5 minutes
			local hrp2 = spieler.Character and spieler.Character:FindFirstChild("HumanoidRootPart")
			if hrp2 and workspace:Raycast(hrp2.Position + Vector3.new(0, 4, 0), Vector3.new(0, -60, 0), params) then
				frage("kartenGeladen", os.clock() - start)
				return
			end
			task.wait(1)
		end
	end)

	-- 🧑‍🏫 the driver sees the commands of a friend riding along: big text at the top
	local kommandoGui = Instance.new("ScreenGui")
	kommandoGui.Name = "FahrlehrerKommando"
	kommandoGui.ResetOnSpawn = false
	kommandoGui.DisplayOrder = 6
	kommandoGui.Parent = spieler.PlayerGui
	local kommandoText = Instance.new("TextLabel")
	kommandoText.AnchorPoint = Vector2.new(0.5, 0)
	kommandoText.Position = UDim2.new(0.5, 0, 0.12, 0)
	kommandoText.Size = UDim2.new(0.6, 0, 0, 70)
	kommandoText.BackgroundTransparency = 1
	kommandoText.Font = Enum.Font.FredokaOne
	kommandoText.TextScaled = true
	kommandoText.TextStrokeTransparency = 0
	kommandoText.Visible = false
	kommandoText.Parent = kommandoGui
	local kommandoVon = Instance.new("TextLabel")
	kommandoVon.AnchorPoint = Vector2.new(0.5, 0)
	kommandoVon.Position = UDim2.new(0.5, 0, 1, 0)
	kommandoVon.Size = UDim2.new(1, 0, 0, 22)
	kommandoVon.BackgroundTransparency = 1
	kommandoVon.Font = Enum.Font.GothamBold
	kommandoVon.TextSize = 18
	kommandoVon.TextColor3 = Color3.fromRGB(230, 235, 245)
	kommandoVon.TextStrokeTransparency = 0.3
	kommandoVon.Parent = kommandoText
	local kommandoSkala = Instance.new("UIScale")
	kommandoSkala.Parent = kommandoText
	local KOMMANDO_FARBEN = { gelb = Color3.fromRGB(255, 210, 40), rot = Color3.fromRGB(255, 80, 80), gruen = Color3.fromRGB(90, 235, 110) }
	local kommandoNr = 0
	local function kommandoZeigen(info)
		kommandoNr += 1
		local nr = kommandoNr
		kommandoText.Text = info.text or ""
		kommandoText.TextColor3 = KOMMANDO_FARBEN[info.farbe] or KOMMANDO_FARBEN.gelb
		kommandoVon.Text = (info.von or "Your friend") .. " (Instructor)"
		kommandoText.Visible = true
		kommandoSkala.Scale = 0.5
		game:GetService("TweenService"):Create(kommandoSkala, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		task.delay(1.8, function()
			if kommandoNr == nr then kommandoText.Visible = false end
		end)
	end

	-- 🧑‍🏫 the friend riding along gets the instructor panel (buttons + keys 1-6, rating with stars)
	do
		local UISF = game:GetService("UserInputService")
		local KNOEPFE = {
			{ "links", "⬅ LEFT", Color3.fromRGB(230, 170, 30) },
			{ "gerade", "⬆ STRAIGHT", Color3.fromRGB(230, 170, 30) },
			{ "rechts", "RIGHT ➡", Color3.fromRGB(230, 170, 30) },
			{ "stopp", "✋ STOP", Color3.fromRGB(200, 60, 60) },
			{ "langsam", "🐢 SLOW", Color3.fromRGB(200, 60, 60) },
			{ "super", "👍 NICE", GRUEN },
		}
		local gui = Instance.new("ScreenGui")
		gui.Name = "Fahrlehrer"
		gui.ResetOnSpawn = false
		gui.Enabled = false
		gui.Parent = spieler.PlayerGui
		local rahmen = Instance.new("Frame")
		rahmen.AnchorPoint = Vector2.new(0.5, 1)
		rahmen.Position = UDim2.new(0.5, 0, 1, -12)
		rahmen.Size = UDim2.fromOffset(6 * 74 + 12, 104)
		rahmen.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
		rahmen.BackgroundTransparency = 0.15
		rahmen.Parent = gui
		Instance.new("UICorner", rahmen).CornerRadius = UDim.new(0, 14)
		local skala = Instance.new("UIScale")
		skala.Parent = rahmen
		local titel = Instance.new("TextLabel")
		titel.Position = UDim2.fromOffset(12, 4)
		titel.Size = UDim2.new(1, -150, 0, 26)
		titel.BackgroundTransparency = 1
		titel.Font = Enum.Font.GothamBlack
		titel.TextSize = 15
		titel.TextColor3 = Color3.fromRGB(255, 210, 40)
		titel.TextXAlignment = Enum.TextXAlignment.Left
		titel.Text = "🧑‍🏫 YOU'RE THE INSTRUCTOR"
		titel.Parent = rahmen
		local function senden(art)
			task.spawn(function()
				local r = frage("kommando", art)
				if r.fehler then warnen(r.fehler, Color3.fromRGB(200, 140, 30)) end
			end)
		end
		for i, k in KNOEPFE do
			local b = Instance.new("TextButton")
			b.Position = UDim2.fromOffset(6 + (i - 1) * 74 + 4, 36)
			b.Size = UDim2.fromOffset(66, 58)
			b.BackgroundColor3 = k[3]
			b.Font = Enum.Font.GothamBlack
			b.TextSize = 13
			b.TextWrapped = true
			b.TextColor3 = Color3.new(1, 1, 1)
			b.Text = k[2] .. "\n" .. i
			b.Parent = rahmen
			Instance.new("UICorner", b)
			b.Activated:Connect(function() senden(k[1]) end)
		end
		-- ⭐ rating: 5 star buttons that appear above the panel
		local sterneRahmen = Instance.new("Frame")
		sterneRahmen.AnchorPoint = Vector2.new(1, 1)
		sterneRahmen.Position = UDim2.new(1, -8, 0, -6)
		sterneRahmen.Size = UDim2.fromOffset(5 * 44 + 8, 50)
		sterneRahmen.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
		sterneRahmen.Visible = false
		sterneRahmen.Parent = rahmen
		Instance.new("UICorner", sterneRahmen).CornerRadius = UDim.new(0, 12)
		for n = 1, 5 do
			local st = Instance.new("TextButton")
			st.Position = UDim2.fromOffset(4 + (n - 1) * 44, 4)
			st.Size = UDim2.fromOffset(42, 42)
			st.BackgroundTransparency = 1
			st.Font = Enum.Font.GothamBlack
			st.TextSize = 30
			st.TextColor3 = Color3.fromRGB(255, 210, 40)
			st.Text = "★"
			st.Parent = sterneRahmen
			st.Activated:Connect(function()
				sterneRahmen.Visible = false
				local r = frage("bewerten", n)
				warnen((r.fehler or r.text or ""), r.fehler and Color3.fromRGB(200, 140, 30) or GRUEN)
			end)
		end
		local bewerten = Instance.new("TextButton")
		bewerten.AnchorPoint = Vector2.new(1, 0)
		bewerten.Position = UDim2.new(1, -10, 0, 5)
		bewerten.Size = UDim2.fromOffset(130, 26)
		bewerten.BackgroundColor3 = BLAU
		bewerten.Font = Enum.Font.GothamBold
		bewerten.TextSize = 13
		bewerten.TextColor3 = Color3.new(1, 1, 1)
		bewerten.Text = "⭐ Rate driver"
		bewerten.Parent = rahmen
		Instance.new("UICorner", bewerten)
		bewerten.Activated:Connect(function() sterneRahmen.Visible = not sterneRahmen.Visible end)

		-- am I riding along in a car that another player drives?
		local function fahrtMit()
			local hum = spieler.Character and spieler.Character:FindFirstChildOfClass("Humanoid")
			local s = hum and hum.SeatPart
			if not s or s:IsA("VehicleSeat") then return false end
			local m = s.Parent
			while m and m ~= workspace do
				if m:IsA("Model") then
					for _, v in m:GetDescendants() do
						if v:IsA("VehicleSeat") and v.Occupant then
							local fp = Players:GetPlayerFromCharacter(v.Occupant.Parent)
							if fp and fp ~= spieler then return true end
						end
					end
				end
				m = m.Parent
			end
			return false
		end
		local TASTEN = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six }
		UISF.InputBegan:Connect(function(eingabe, verarbeitet)
			if verarbeitet or not gui.Enabled then return end
			local i = table.find(TASTEN, eingabe.KeyCode)
			if i then senden(KNOEPFE[i][1]) end
		end)
		task.spawn(function()
			local vorher = false
			while true do
				local jetzt = fahrtMit()
				if jetzt ~= vorher then
					vorher = jetzt
					gui.Enabled = jetzt
					sterneRahmen.Visible = false
					if jetzt then
						warnen("🧑‍🏫 You're the instructor! Tell your friend where to drive (1-6).", GRUEN)
					end
				end
				if jetzt then
					local kam = workspace.CurrentCamera
					local breite = kam and kam.ViewportSize.X or 1000
					skala.Scale = math.clamp((breite - 20) / (6 * 74 + 12), 0.6, 1)
				end
				task.wait(0.5)
			end
		end)
	end
	BetaClient.kommandoZeigen = kommandoZeigen

	-- 🙈 Blind Drive (v55): the co-pilot sees gate + route + distance, the driver sees nothing but the road
	local coGui = Instance.new("ScreenGui")
	coGui.Name = "Copilot"
	coGui.ResetOnSpawn = false
	coGui.Enabled = false
	coGui.Parent = spieler.PlayerGui
	local coBox = Instance.new("Frame")
	coBox.AnchorPoint = Vector2.new(0.5, 0)
	coBox.Position = UDim2.new(0.5, 0, 0, 8)
	coBox.Size = UDim2.fromOffset(460, 92)
	coBox.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
	coBox.BackgroundTransparency = 0.1
	coBox.Parent = coGui
	Instance.new("UICorner", coBox).CornerRadius = UDim.new(0, 12)
	local coSkala = Instance.new("UIScale")
	coSkala.Parent = coBox
	local function zeile(y, h, groesse, farbe, font)
		local t = Instance.new("TextLabel")
		t.Position = UDim2.fromOffset(14, y)
		t.Size = UDim2.new(1, -28, 0, h)
		t.BackgroundTransparency = 1
		t.Font = font or Enum.Font.GothamBold
		t.TextSize = groesse
		t.TextColor3 = farbe
		t.TextXAlignment = Enum.TextXAlignment.Left
		t.TextWrapped = true
		t.RichText = true
		t.Parent = coBox
		return t
	end
	local coTitel = zeile(6, 18, 13, Color3.fromRGB(255, 210, 40), Enum.Font.GothamBlack)
	local coText = zeile(26, 40, 16, Color3.new(1, 1, 1))
	local coWeite = zeile(66, 20, 15, Color3.fromRGB(120, 230, 140), Enum.Font.GothamBlack)
	local coZiel, coNr = nil, 0
	local function copilotAus()
		coGui.Enabled = false
		coZiel = nil
	end
	task.spawn(function()
		while true do
			if coGui.Enabled and coZiel then
				local hrp = spieler.Character and spieler.Character:FindFirstChild("HumanoidRootPart")
				if hrp then
					local m = Vector3.new(coZiel.X - hrp.Position.X, 0, coZiel.Z - hrp.Position.Z).Magnitude
					coWeite.Text = m < 25 and "➡ NOW!" or ("Next gate in %d m"):format(math.floor(m / 5 + 0.5) * 5)
				end
				local kam = workspace.CurrentCamera
				coSkala.Scale = math.clamp(((kam and kam.ViewportSize.X or 1000) - 20) / 460, 0.6, 1)
			end
			task.wait(0.2)
		end
	end)

	function BetaClient.event(info)
		if info.typ == "ziel" and info.copilot then
			k.markerWeg()
			if info.pos then k.markerSetzen(info.pos, info.richtung, info.breite or 26) end
			if _G.MinimapRoute then _G.MinimapRoute(info.route, info.nr) end
			coZiel, coNr = info.pos, info.nr
			coTitel.Text = ("🗺 CO-PILOT  ·  %s can't see the route  ·  %d/%d"):format(info.fahrer or "Your driver", info.nr or 0, info.gesamt or 0)
			coText.Text = "Tell them: <b>" .. k.einh(info.text or "") .. "</b>"
			coGui.Enabled = true
			return true
		elseif info.typ == "ziel" and info.blind then
			k.lektion(true)
			k.hud.Enabled = true
			k.anweisungText.Text = (info.sprecher or "Co-pilot") .. ": " .. (info.text or "")
			k.lektionTitel.Text = "🙈 BLIND DRIVE  (" .. (info.nr or 0) .. "/" .. (info.gesamt or 0) .. ")"
			k.markerWeg()
			if _G.MinimapRoute then _G.MinimapRoute(nil) end
			return true
		elseif info.typ == "ende" and info.blind then
			k.hudAus()
			copilotAus()
			if info.abbruch then
				warnen("🗺 You left the car – your friend drives on alone.", Color3.fromRGB(200, 140, 30))
				return true
			end
			local zeit = ("%d:%02d"):format(math.floor((info.sek or 0) / 60), (info.sek or 0) % 60)
			local text = ("<font size=\"26\" color=\"#ffd23c\"><b>%s</b></font>\n\n🙈 Driver: <b>%s</b>   🗺 Co-pilot: <b>%s</b>\nMistakes: <b>%d</b>   ·   Time: <b>%s</b>%s"):format(
				info.titel or "", info.fahrer or "?", info.copilotName or "–", info.fehler or 0, zeit,
				(info.geld or 0) > 0 and ("\n\n+%d coins each"):format(info.geld) or "")
			local knoepfe = { { text = "Close", farbe = GRUEN, klick = k.schliessen } }
			if not info.copilot then
				table.insert(knoepfe, 1, { text = "🔁 Again", farbe = BLAU, klick = function() BetaClient.blindKnopf() end })
			end
			k.zeige(info.erfolg and "🙈 BLIND DRIVE DONE!" or "🙈 Blind Drive ended", text, knoepfe, "hinweis")
			return true
		end
		return false
	end

	function BetaClient.blindKnopf()
		local r = frage("blindStarten")
		if r.fehler then
			warnen(r.fehler, Color3.fromRGB(200, 140, 30))
		else
			k.zeige("🙈 Blind Drive", (r.text or "") .. "\n\n<b>How it works:</b> you drive, but you can't see the route. Your friend sits next to you (\"Be the co-pilot\" at the passenger door), sees the map and tells you where to go.", {
				{ text = "Let's go!", farbe = GRUEN, klick = k.schliessen },
			}, "dialog")
		end
	end
	return BetaClient
end

return BetaClient
