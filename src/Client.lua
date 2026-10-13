-- Driver's license system (player): dialogs, theory lesson, theory test and driving lesson HUD.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local spieler = Players.LocalPlayer
print("[Driving School] client v{VERSION} loaded")
local ordner = RS:WaitForChild("Fuehrerschein")
local aktion = ordner:WaitForChild("Aktion")
local oeffnen = ordner:WaitForChild("Oeffnen")
local fahrEvent = ordner:WaitForChild("Fahrstunde")
local blinkerEvent = ordner:WaitForChild("Blinker")
local Regeln = require(ordner:WaitForChild("Verkehrsregeln"))
local Verkehr = require(ordner:WaitForChild("Verkehr"))

local BLAU = Color3.fromRGB(30, 90, 180)
local GRUEN = Color3.fromRGB(40, 150, 70)
local GRAU = Color3.fromRGB(70, 75, 85)
local ROT = Color3.fromRGB(200, 50, 50)

-- Theory lesson slides
local FOLIEN = {
	{ "Welcome to Driving School!", "Here is how you get your license:\n\n1. Theory lesson (these slides)\n2. Theory test at an exam desk: 20 questions, at least 85 % correct (17 of 20)\n3. Five driving lessons with your instructor\n4. Practical driving test\n\nOnly with a license can you buy and drive your own cars." },
	{ "Basics", "• We drive on the <b>right</b> side of the road.\n• Always wear your <b>seatbelt</b>.\n• No phone in your hand while driving.\n• Never drink and drive.\n• Signal <b>early</b> before turning or changing lanes." },
	{ "Speed Limits", "• Residential areas: <b>30 km/h</b>\n• City: <b>50 km/h</b>\n• Country roads: <b>100 km/h</b>\n• Highway: <b>130 km/h</b>\n\nYour speedometer shows the current limit while driving. In rain or at night, drive slower." },
	{ "Traffic Lights & Signs", "• <b>Red</b>: stop before the white stop line.\n• <b>Yellow</b>: stop if you can do it safely.\n• <b>Green</b>: go, but let pedestrians cross when turning.\n• <b>STOP</b> sign: complete stop, then give way.\n• <b>YIELD</b> sign (red triangle, point down): slow down, let the main road go first.\n• <b>Yellow diamond</b>: you are on the main road and have priority.\n• <b>No signs</b> at a junction: <b>right before left</b> – approach slowly!" },
	{ "Right of Way & Pedestrians", "• When turning left, oncoming traffic goes first.\n• At <b>crosswalks</b>, pedestrians have priority.\n• Emergency vehicles with lights and siren: make way.\n• Children near the road: slow down and be ready to brake.\n• Keep a <b>2-second</b> gap to the car in front." },
	{ "Roundabout, Highway & Parking", "• <b>Roundabout</b>: traffic inside has priority. Signal when leaving.\n• <b>Highway</b>: keep right, overtake on the left, never turn around.\n• Merge by matching the speed of traffic.\n• No parking in front of hydrants or on crosswalks.\n• Use hazard lights if your car breaks down." },
}

-- ---------------------------------------------------------------
-- Dialog window
-- ---------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "LicenseGUI"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.DisplayOrder = 5
gui.Parent = spieler:WaitForChild("PlayerGui")

local rahmen = Instance.new("Frame")
rahmen.AnchorPoint = Vector2.new(0.5, 0.5)
rahmen.Position = UDim2.fromScale(0.5, 0.5)
rahmen.Size = UDim2.fromScale(0.92, 0.85)
rahmen.BackgroundColor3 = Color3.fromRGB(25, 30, 40)
rahmen.Parent = gui
local grenze = Instance.new("UISizeConstraint")
grenze.MaxSize = Vector2.new(620, 470)
grenze.Parent = rahmen
Instance.new("UICorner", rahmen).CornerRadius = UDim.new(0, 12)
local rand = Instance.new("UIPadding")
for _, seite in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do
	rand[seite] = UDim.new(0, 16)
end
rand.Parent = rahmen

local titel = Instance.new("TextLabel")
titel.BackgroundTransparency = 1
titel.Size = UDim2.new(1, -40, 0, 34)
titel.Font = Enum.Font.GothamBlack
titel.TextSize = 22
titel.TextColor3 = Color3.new(1, 1, 1)
titel.TextXAlignment = Enum.TextXAlignment.Left
titel.TextTruncate = Enum.TextTruncate.AtEnd
titel.Parent = rahmen

local zu = Instance.new("TextButton")
zu.Size = UDim2.fromOffset(32, 32)
zu.Position = UDim2.new(1, -32, 0, 0)
zu.Text = "X"
zu.Font = Enum.Font.GothamBold
zu.TextSize = 18
zu.TextColor3 = Color3.new(1, 1, 1)
zu.BackgroundColor3 = ROT
zu.Parent = rahmen
Instance.new("UICorner", zu)

local text = Instance.new("TextLabel")
text.BackgroundTransparency = 1
text.Position = UDim2.fromOffset(0, 44)
text.Size = UDim2.new(1, 0, 1, -44 - 150)
text.Font = Enum.Font.Gotham
text.TextSize = 18
text.TextColor3 = Color3.fromRGB(225, 230, 240)
text.TextWrapped = true
text.RichText = true
text.TextXAlignment = Enum.TextXAlignment.Left
text.TextYAlignment = Enum.TextYAlignment.Top
text.Parent = rahmen

local knoepfe = Instance.new("Frame")
knoepfe.BackgroundTransparency = 1
knoepfe.Position = UDim2.new(0, 0, 1, -142)
knoepfe.Size = UDim2.new(1, 0, 0, 142)
knoepfe.Parent = rahmen
local liste = Instance.new("UIListLayout")
liste.Padding = UDim.new(0, 6)
liste.VerticalAlignment = Enum.VerticalAlignment.Bottom
liste.SortOrder = Enum.SortOrder.LayoutOrder
liste.Parent = knoepfe

local modus = nil -- what the window currently shows

local function schliessen()
	gui.Enabled = false
	modus = nil
end
zu.MouseButton1Click:Connect(schliessen)

local function zeige(t, inhalt, buttons, neuerModus)
	titel.Text = t
	text.Text = inhalt
	for _, k in knoepfe:GetChildren() do
		if k:IsA("TextButton") then k:Destroy() end
	end
	for i, b in buttons or {} do
		local k = Instance.new("TextButton")
		k.LayoutOrder = i
		k.Size = UDim2.new(1, 0, 0, 40)
		k.BackgroundColor3 = b.farbe or BLAU
		k.Text = b.text
		k.Font = Enum.Font.GothamBold
		k.TextSize = 16
		k.TextWrapped = true
		k.TextColor3 = Color3.new(1, 1, 1)
		k.Parent = knoepfe
		Instance.new("UICorner", k)
		k.MouseButton1Click:Connect(b.klick)
	end
	modus = neuerModus
	gui.Enabled = true
end

local function frage(was, eingabe)
	local ok, r = pcall(function()
		return aktion:InvokeServer(was, eingabe)
	end)
	if not ok or type(r) ~= "table" then
		return { fehler = "Could not reach the server." }
	end
	return r
end

local function hinweis(meldung)
	zeige("Note", meldung, { { text = "Close", farbe = GRAU, klick = schliessen } }, "hinweis")
end

local function fortschritt(r)
	local s = r.status
	local function zeile(erledigt, t)
		return (erledigt and "✅ " or "⬜ ") .. t
	end
	return table.concat({
		zeile(s.angemeldet, "Signed up"),
		zeile(s.unterricht, "Theory lesson"),
		zeile(s.theorie, "Theory test"),
		zeile(s.fahrstunden >= r.anzahlLektionen, ("Driving lessons (%d/%d)"):format(s.fahrstunden, r.anzahlLektionen)),
		zeile(s.fuehrerschein, "Practical driving test"),
		zeile(s.lkwFuehrerschein, "Truck license (optional)"),
	}, "\n")
end

-- ---------------------------------------------------------------
-- Receptionist dialog
-- ---------------------------------------------------------------
local dialog, unterricht, pruefungsplatz

function dialog()
	local r = frage("status")
	if r.fehler then hinweis(r.fehler) return end
	local s = r.status
	local name = "Anna – Reception"
	local unten = "\n\n<font size=\"15\" color=\"#9aa4b5\">" .. fortschritt(r) .. "</font>"
	local tschuess = { text = "Bye!", farbe = GRAU, klick = schliessen }

	if r.lektionLaeuft then
		zeige(name, (r.lkwLaeuft and "Your truck test is in progress. The truck is waiting at the Parcel Express depot." or "Your driving lesson is in progress. Your car and instructor are waiting on the parking lot outside.") .. unten, {
			{ text = "Cancel the lesson", farbe = ROT, klick = function()
				frage("fahrstundeAbbrechen")
				schliessen()
			end },
			tschuess,
		}, "dialog")
	elseif s.entzogen and not s.nachschulung then
		zeige(name, ("Oh no... your driver's license was <b>withdrawn</b> because you collected too many penalty points. 😟\n\nTo get it back you need:\n1. the <b>retraining course</b> (%d coins)\n2. a new <b>practical driving test</b>"):format(500) .. unten, {
			{ text = "Book the retraining course (500 coins)", farbe = GRUEN, klick = function()
				local a = frage("nachschulung")
				if a.fehler then hinweis(a.fehler) return end
				local seiten = {
					{ "Retraining course", "Speeding is the most common cause of accidents.\n\n• Always watch the speed limit sign on your speedometer.\n• Speed cameras measure in <b>both directions</b>.\n• Every offence brings <b>penalty points</b>; at <b>8 points</b> the license is gone again." },
					{ "Retraining course", "• Red light = stop. Always.\n• Stop for the police when they signal you.\n• Points expire over time if you drive safely.\n\nNow book your new driving test with Anna!" },
				}
				local i = 1
				local function seite()
					zeige(seiten[i][1], seiten[i][2], { { text = i < #seiten and "Next" or "Finish the course", farbe = GRUEN, klick = function()
						if i < #seiten then i += 1 seite() else dialog() end
					end } }, "unterricht")
				end
				seite()
			end },
			tschuess,
		}, "dialog")
	elseif not s.angemeldet then
		zeige(name, "Hi, welcome to the driving school! 😊\nWould you like to sign up for your driver's license?" .. unten, {
			{ text = "Yes, sign me up!", farbe = GRUEN, klick = function()
				local a = frage("anmelden")
				if a.fehler then hinweis(a.fehler) else dialog() end
			end },
			{ text = "Just looking around", farbe = GRAU, klick = schliessen },
		}, "dialog")
	elseif not s.unterricht then
		zeige(name, "You're signed up! First step: the <b>theory lesson</b>.\nGo into the classroom on the left and press E at the <b>whiteboard</b>." .. unten, { tschuess }, "dialog")
	elseif not s.theorie then
		zeige(name, "Great, you attended the lesson! Now take a seat at one of the <b>exam desks</b> in the classroom to start your theory test.\nYou need at least 17 of 20 correct answers." .. unten, { tschuess }, "dialog")
	elseif r.naechste then
		zeige(name, ("Your next driving lesson:\n<b>%s</b>\n\nYour instructor Mike will be waiting in the car on the parking lot."):format(r.naechste) .. unten, {
			{ text = "Start the lesson", farbe = GRUEN, klick = function()
				local a = frage("fahrstundeStarten")
				if a.fehler then
					hinweis(a.fehler)
				else
					zeige(name, a.text, { { text = "Okay!", farbe = GRUEN, klick = schliessen } }, "dialog")
				end
			end },
			{ text = "Not now", farbe = GRAU, klick = schliessen },
		}, "dialog")
	else
		if s.fuehrerschein and s.lkwFuehrerschein then
			zeige(name, "You have both licenses: car (B) and truck (C)! 🎉\n\nTruck drivers are needed at the <b>Parcel Express</b> depot south of the neighbourhood. Talk to Tom, the dispatcher, to earn coins by delivering packages." .. unten, { tschuess }, "dialog")
		elseif s.fuehrerschein then
			zeige(name, "Congratulations on your driver's license! 🎉\n\nWant to drive big trucks? Take the <b>truck driving test (class C)</b>. The truck waits at the Parcel Express depot, south of the neighbourhood. Max 3 mistakes. With the truck license you can work as a delivery driver!" .. unten, {
				{ text = "Start the truck test", farbe = GRUEN, klick = function()
					local a = frage("lkwPruefungStarten")
					if a.fehler then
						hinweis(a.fehler)
					else
						zeige(name, a.text, { { text = "Let's go!", farbe = GRUEN, klick = schliessen } }, "dialog")
					end
				end },
				{ text = "Not now", farbe = GRAU, klick = schliessen },
			}, "dialog")
		else
			zeige(name, "You have completed all driving lessons! Now it's time for the <b>practical driving test</b>.\n\nYour examiner Mr. Becker rides in the back, Mike sits next to you. The route is random and you may make <b>at most 3 mistakes</b>. Hitting a pedestrian counts as 3!" .. unten, {
				{ text = "Start the driving test", farbe = GRUEN, klick = function()
					local a = frage("pruefungStarten")
					if a.fehler then
						hinweis(a.fehler)
					else
						zeige(name, a.text, { { text = "Let's go!", farbe = GRUEN, klick = schliessen } }, "dialog")
					end
				end },
				{ text = "Not now", farbe = GRAU, klick = schliessen },
			}, "dialog")
		end
	end
end

-- ---------------------------------------------------------------
-- Theory lesson at the whiteboard
-- ---------------------------------------------------------------
function unterricht()
	local r = frage("status")
	if r.fehler then hinweis(r.fehler) return end
	if not r.status.angemeldet then
		hinweis("Please sign up at the reception first. Anna is waiting at the front desk.")
		return
	end
	local i = 1
	local function folie()
		local f = FOLIEN[i]
		local buttons = {}
		if i < #FOLIEN then
			table.insert(buttons, { text = ("Next (%d/%d)"):format(i, #FOLIEN), klick = function()
				i += 1
				folie()
			end })
		else
			table.insert(buttons, { text = "Finish the lesson", farbe = GRUEN, klick = function()
				local a = frage("unterrichtFertig")
				if a.fehler then
					hinweis(a.fehler)
				else
					zeige("Lesson complete!", "Well done! Now sit down at one of the <b>exam desks</b> in this room to start your theory test.", {
						{ text = "Close", farbe = GRAU, klick = schliessen },
					}, "hinweis")
				end
			end })
		end
		if i > 1 then
			table.insert(buttons, { text = "Back", farbe = GRAU, klick = function()
				i -= 1
				folie()
			end })
		end
		zeige(f[1], f[2], buttons, "unterricht")
	end
	folie()
end

-- ---------------------------------------------------------------
-- Theory test at an exam desk
-- ---------------------------------------------------------------
local function pruefung()
	local r = frage("pruefungStart")
	if r.fehler then hinweis(r.fehler) return end
	local fragen = r.fragen
	local antworten = {}
	local n = 1
	local function abgeben()
		local e = frage("pruefungAbgeben", antworten)
		if e.fehler then hinweis(e.fehler) return end
		local prozent = math.floor(e.punkte / e.gesamt * 100 + 0.5)
		if e.bestanden then
			zeige("Passed! 🎉", ("You answered <b>%d of %d</b> questions correctly (%d %%).\n\nNext step: book your first driving lesson with Anna at the reception."):format(e.punkte, e.gesamt, prozent), {
				{ text = "Close", farbe = GRUEN, klick = schliessen },
			}, "hinweis")
		else
			zeige("Not passed", ("You answered %d of %d correctly (%d %%).\nYou need at least <b>%d</b>.\n\nReview the lesson at the whiteboard. You can try again in %d seconds."):format(e.punkte, e.gesamt, prozent, e.mindest, e.wartezeit), {
				{ text = "Close", farbe = GRAU, klick = schliessen },
			}, "hinweis")
		end
	end
	local function frageZeigen()
		local f = fragen[n]
		local buttons = {}
		for i, antwort in f.antworten do
			table.insert(buttons, { text = antwort, klick = function()
				if modus ~= "pruefung" then return end
				antworten[n] = i
				n += 1
				if n > #fragen then abgeben() else frageZeigen() end
			end })
		end
		zeige(("Theory test – question %d/%d"):format(n, #fragen), f.frage, buttons, "pruefung")
	end
	frageZeigen()
end

function pruefungsplatz()
	local r = frage("status")
	if r.fehler then hinweis(r.fehler) return end
	local s = r.status
	if s.theorie then
		hinweis("You have already passed the theory test. Talk to Anna at the reception to book a driving lesson.")
	elseif not s.unterricht then
		hinweis("Please attend the theory lesson at the whiteboard first (press E at the whiteboard).")
	else
		zeige("Exam desk", "Ready for your theory test?\n\n• 20 questions\n• at least 17 correct (85 %)\n• if you stand up, the test is cancelled", {
			{ text = "Start the test", farbe = GRUEN, klick = pruefung },
			{ text = "Not yet", farbe = GRAU, klick = schliessen },
		}, "platz")
	end
end

-- ---------------------------------------------------------------
-- Dispatcher at the Parcel Express depot (truck job)
-- ---------------------------------------------------------------
local function starten(name, was, eingabe)
	local a = frage(was, eingabe)
	if a.fehler then
		hinweis(a.fehler)
	else
		zeige(name, a.text, { { text = "Let's go!", farbe = GRUEN, klick = schliessen } }, "dialog")
	end
end

local function laufenderJob(name)
	zeige(name, "You're on a delivery job! Follow the green line on your minimap. At each customer: stop, get out, take the goods from the back of your vehicle and hand them over.", {
		{ text = "Cancel the job", farbe = ROT, klick = function()
			frage("jobAbbrechen")
			schliessen()
		end },
		{ text = "Bye!", farbe = GRAU, klick = schliessen },
	}, "dialog")
end

local function jobDialog()
	local r = frage("status")
	if r.fehler then hinweis(r.fehler) return end
	local s = r.status
	local name = "Tom – Parcel Express"
	local tschuess = { text = "Bye!", farbe = GRAU, klick = schliessen }
	if r.jobLaeuft then
		laufenderJob(name)
	elseif not s.lkwFuehrerschein then
		zeige(name, "Hey! We always need delivery drivers. 🚚\n\nBut you need a <b>truck license (class C)</b> to drive our trucks. " .. (s.fuehrerschein and "Ask Anna at the driving school about the truck test!" or "First get your car license at the driving school, then the truck license."), { tschuess }, "dialog")
	else
		local j = r.jobs
		local zeilen, knoepfe = {}, {}
		local naechste
		for _, st in j.stufen do
			if st.frei then
				table.insert(zeilen, ("✅ <b>%s</b> – %s: %d stops, %d coins each + %d bonus"):format(st.name, st.ware, st.pakete, st.lohn, st.bonus))
				table.insert(knoepfe, 1, { text = ("Drive the %s (%d coins per stop)"):format(st.name, st.lohn), farbe = GRUEN, klick = function() starten(name, "jobStarten", st.nr) end })
			else
				naechste = naechste or st
				table.insert(zeilen, ("🔒 <b>%s</b> – unlocks after %d jobs"):format(st.name, st.ab))
			end
		end
		local fortschritt = naechste and ("\nJobs done: <b>%d</b> – %d more until the %s."):format(j.fahrten, naechste.ab - j.fahrten, naechste.name)
			or ("\nJobs done: <b>%d</b> – you drive our biggest truck! 🏆"):format(j.fahrten)
		zeige(name, "Ready to work? Hand every delivery to the customer yourself.\n\n" .. table.concat(zeilen, "\n") .. "\n" .. fortschritt, knoepfe, "dialog")
	end
end

local function pizzaDialog()
	local r = frage("status")
	if r.fehler then hinweis(r.fehler) return end
	local s = r.status
	local name = "Luigi – Pizza Rapido"
	if r.jobLaeuft then
		laufenderJob(name)
	elseif not s.fuehrerschein then
		zeige(name, "Ciao! 🍕 I need drivers for my pizzas!\n\nBut you need a <b>driver's license (class B)</b> first. Go to the driving school next door!", { { text = "Bye!", farbe = GRAU, klick = schliessen } }, "dialog")
	else
		local p = r.jobs.pizza
		zeige(name, ("Ciao! 🍕 Hot pizzas are waiting!\n\nDeliver <b>%d pizzas</b> to customers in town and in the city.\n• <b>%d coins</b> per pizza\n• <b>%d coins</b> bonus when the car is back\n\nPizzas delivered so far: %d jobs"):format(p.pakete, p.lohn, p.bonus, r.jobs.pizzaFahrten), {
			{ text = "Start delivering", farbe = GRUEN, klick = function() starten(name, "pizzaStarten") end },
			{ text = "Not now", farbe = GRAU, klick = schliessen },
		}, "dialog")
	end
end

local function villaDialog(v)
	local titelName = "🏡 " .. v.name
	if v.gehoert then
		zeige(titelName, "This is <b>your villa</b>! Only you (and other owners) can open the front door. Make yourself at home.", { { text = "Close", farbe = GRAU, klick = schliessen } }, "dialog")
		return
	end
	local besitzer = (#v.besitzer > 0) and ("\n\nCurrent residents on this server: " .. table.concat(v.besitzer, ", ")) or ""
	local knoepfe = {}
	if v.geld >= v.preis then
		table.insert(knoepfe, { text = ("Buy for %d coins"):format(v.preis), farbe = GRUEN, klick = function()
			local a = frage("villaKaufen", v.id)
			if a.fehler then hinweis(a.fehler) else zeige(titelName, a.text, { { text = "Awesome!", farbe = GRUEN, klick = schliessen } }, "dialog") end
		end })
	end
	table.insert(knoepfe, { text = "Not now", farbe = GRAU, klick = schliessen })
	zeige(titelName, ("A modern villa with pool, terrace, open kitchen, living room and bedroom.\n\nPrice: <b>%d coins</b>\nYour coins: <b>%d</b>%s%s"):format(v.preis, v.geld,
		v.geld < v.preis and ("\n\nYou still need %d coins. Earn them with the delivery jobs!"):format(v.preis - v.geld) or "", besitzer), knoepfe, "dialog")
end

-- Car dealership: list of all cars with a buy button each
local autohausGui
local function autohausDialog(info)
	if autohausGui then autohausGui:Destroy() end
	autohausGui = Instance.new("ScreenGui")
	autohausGui.Name = "Autohaus"
	autohausGui.ResetOnSpawn = false
	autohausGui.DisplayOrder = 12
	autohausGui.Parent = spieler.PlayerGui
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(520, 470)
	panel.BackgroundColor3 = Color3.fromRGB(22, 24, 30)
	panel.Parent = autohausGui
	Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 14)
	local skalierung = Instance.new("UISizeConstraint")
	skalierung.MaxSize = Vector2.new(520, 470)
	skalierung.Parent = panel
	local streifen = Instance.new("Frame")
	streifen.Size = UDim2.new(1, 0, 0, 56)
	streifen.BackgroundColor3 = Color3.fromRGB(200, 30, 40)
	streifen.Parent = panel
	Instance.new("UICorner", streifen).CornerRadius = UDim.new(0, 14)
	local titel2 = Instance.new("TextLabel")
	titel2.Position = UDim2.fromOffset(18, 6)
	titel2.Size = UDim2.new(1, -80, 0, 28)
	titel2.BackgroundTransparency = 1
	titel2.Font = Enum.Font.GothamBlack
	titel2.TextSize = 24
	titel2.TextColor3 = Color3.new(1, 1, 1)
	titel2.TextXAlignment = Enum.TextXAlignment.Left
	titel2.Text = "VELOCITY MOTORS"
	titel2.Parent = streifen
	local unter = Instance.new("TextLabel")
	unter.Position = UDim2.fromOffset(18, 32)
	unter.Size = UDim2.new(1, -80, 0, 18)
	unter.BackgroundTransparency = 1
	unter.Font = Enum.Font.GothamMedium
	unter.TextSize = 13
	unter.TextColor3 = Color3.fromRGB(255, 220, 220)
	unter.TextXAlignment = Enum.TextXAlignment.Left
	unter.Text = ("Your coins: %d  ·  You need a driver's license (B) to drive"):format(info.geld)
	unter.Parent = streifen
	local zu4 = Instance.new("TextButton")
	zu4.Position = UDim2.new(1, -44, 0, 13)
	zu4.Size = UDim2.fromOffset(30, 30)
	zu4.BackgroundColor3 = Color3.fromRGB(40, 20, 20)
	zu4.Text = "X"
	zu4.Font = Enum.Font.GothamBold
	zu4.TextSize = 16
	zu4.TextColor3 = Color3.new(1, 1, 1)
	zu4.Parent = streifen
	Instance.new("UICorner", zu4)
	zu4.MouseButton1Click:Connect(function() autohausGui:Destroy() autohausGui = nil end)
	local liste3 = Instance.new("ScrollingFrame")
	liste3.Position = UDim2.fromOffset(14, 66)
	liste3.Size = UDim2.new(1, -28, 1, -80)
	liste3.BackgroundTransparency = 1
	liste3.BorderSizePixel = 0
	liste3.ScrollBarThickness = 6
	liste3.AutomaticCanvasSize = Enum.AutomaticSize.Y
	liste3.CanvasSize = UDim2.new()
	liste3.Parent = panel
	local l3 = Instance.new("UIListLayout")
	l3.Padding = UDim.new(0, 8)
	l3.SortOrder = Enum.SortOrder.LayoutOrder
	l3.Parent = liste3
	for i, a in info.katalog do
		local karte2 = Instance.new("Frame")
		karte2.LayoutOrder = i
		karte2.Size = UDim2.new(1, -10, 0, 62)
		karte2.BackgroundColor3 = info.auswahl == a.typ and Color3.fromRGB(55, 40, 45) or Color3.fromRGB(34, 38, 48)
		karte2.Parent = liste3
		Instance.new("UICorner", karte2)
		local n = Instance.new("TextLabel")
		n.Position = UDim2.fromOffset(12, 6)
		n.Size = UDim2.new(1, -170, 0, 22)
		n.BackgroundTransparency = 1
		n.Font = Enum.Font.GothamBlack
		n.TextSize = 17
		n.TextColor3 = Color3.new(1, 1, 1)
		n.TextXAlignment = Enum.TextXAlignment.Left
		n.Text = ("%s  ·  %s"):format(a.name, a.art)
		n.Parent = karte2
		local d2 = Instance.new("TextLabel")
		d2.Position = UDim2.fromOffset(12, 28)
		d2.Size = UDim2.new(1, -170, 0, 30)
		d2.BackgroundTransparency = 1
		d2.Font = Enum.Font.Gotham
		d2.TextSize = 12
		d2.TextWrapped = true
		d2.TextColor3 = Color3.fromRGB(180, 185, 195)
		d2.TextXAlignment = Enum.TextXAlignment.Left
		d2.TextYAlignment = Enum.TextYAlignment.Top
		d2.Text = ("%d km/h  ·  %s"):format(a.tempo, a.beschreibung or "")
		d2.Parent = karte2
		local k = Instance.new("TextButton")
		k.AnchorPoint = Vector2.new(1, 0.5)
		k.Position = UDim2.new(1, -10, 0.5, 0)
		k.Size = UDim2.fromOffset(140, 38)
		k.Font = Enum.Font.GothamBlack
		k.TextSize = 14
		k.TextColor3 = Color3.new(1, 1, 1)
		k.Parent = karte2
		Instance.new("UICorner", k)
		if a.gehoert then
			k.Text = "OWNED ✓"
			k.BackgroundColor3 = Color3.fromRGB(50, 90, 60)
		elseif a.pass then
			-- exclusive car: comes with a game pass from the shop
			k.Text = "🌙 EXCLUSIVE"
			k.BackgroundColor3 = Color3.fromRGB(110, 60, 200)
			k.MouseButton1Click:Connect(function()
				if autohausGui then autohausGui:Destroy() autohausGui = nil end
				if _G.ShopOeffnen then _G.ShopOeffnen() end
			end)
		else
			local leisten = info.geld >= a.preis
			k.Text = ("🪙 %d"):format(a.preis)
			k.BackgroundColor3 = leisten and GRUEN or GRAU
			k.MouseButton1Click:Connect(function()
				if not leisten then
					hinweis(("You need %d more coins for the %s. Earn them with the delivery jobs!"):format(a.preis - info.geld, a.name))
					return
				end
				local r = frage("autoKaufen", a.typ)
				if autohausGui then autohausGui:Destroy() autohausGui = nil end
				if r.fehler then hinweis(r.fehler) else zeige("🚗 " .. a.name, r.text, { { text = "Awesome!", farbe = GRUEN, klick = schliessen } }, "dialog") end
			end)
		end
	end
end

local function kontrolleDialog(info)
	local name = "👮 Police Officer"
	local anfang = info.grund == "anhalten" and ("Good day. You were driving <b>%d km/h too fast</b>.\nYour driver's license, please."):format(info.zuSchnell or 0)
		or "Good day, this is a routine traffic check.\nYour driver's license, please."
	zeige(name, anfang, {
		{ text = "Show driver's license", farbe = BLAU, klick = function()
			local a = frage("kontrolleAntwort", true)
			if a.fehler then hinweis(a.fehler) return end
			zeige(name, a.text, { { text = "Goodbye!", farbe = (a.strafe or 0) > 0 and ROT or GRUEN, klick = schliessen } }, "hinweis")
		end },
		{ text = "Refuse", farbe = GRAU, klick = function()
			local a = frage("kontrolleAntwort", false)
			if a.fehler then hinweis(a.fehler) return end
			zeige(name, a.text, { { text = "Okay...", farbe = ROT, klick = schliessen } }, "hinweis")
		end },
	}, "kontrolle")
end

oeffnen.OnClientEvent:Connect(function(was, info)
	if was == "job" then
		jobDialog()
	elseif was == "pizza" then
		pizzaDialog()
	elseif was == "villa" then
		villaDialog(info)
	elseif was == "kontrolle" then
		kontrolleDialog(info)
	elseif was == "werkstatt" then
		if _G.WerkstattOeffnen then _G.WerkstattOeffnen() end
	elseif was == "taxi" then
		local r = frage("status")
		if r.fehler then hinweis(r.fehler) return end
		if r.jobLaeuft then
			zeige("🚕 Taxi stand", "You are already on a job. Finish or cancel it first.", { { text = "Okay", farbe = GRAU, klick = schliessen } }, "dialog")
		elseif not r.status.fuehrerschein then
			zeige("🚕 Taxi stand", "You need a valid driver's license (class B) to drive a taxi.", { { text = "Okay", farbe = GRAU, klick = schliessen } }, "dialog")
		else
			zeige("🚕 Taxi stand", "Drive <b>3 passengers</b> from their door to where they want to go.\n\n• The fare depends on the distance\n• Fast and smooth rides get a <b>tip</b>\n• 60 coins bonus when the taxi is back at the stand", {
				{ text = "Start the taxi shift", farbe = GRUEN, klick = function()
					local a = frage("taxiStarten")
					if a.fehler then hinweis(a.fehler) else zeige("🚕 Taxi stand", a.text, { { text = "Let's go!", farbe = GRUEN, klick = schliessen } }, "dialog") end
				end },
				{ text = "Not now", farbe = GRAU, klick = schliessen },
			}, "dialog")
		end
	elseif was == "autohaus" then
		autohausDialog(info)
	elseif was == "dialog" then
		dialog()
	elseif was == "unterricht" then
		unterricht()
	elseif was == "pruefungsplatz" then
		pruefungsplatz()
	elseif was == "aufgestanden" then
		if modus == "pruefung" then
			hinweis("You stood up, so the test was cancelled. Sit down again to restart it.")
		elseif modus == "platz" then
			schliessen()
		end
	end
end)

-- ---------------------------------------------------------------
-- Driving lesson HUD
-- ---------------------------------------------------------------
local hud = Instance.new("ScreenGui")
hud.Name = "LessonHUD"
hud.ResetOnSpawn = false
hud.Enabled = false
hud.IgnoreGuiInset = true -- allows the instruction box to sit right at the top
hud.Parent = spieler.PlayerGui

local anweisung = Instance.new("Frame")
anweisung.AnchorPoint = Vector2.new(0.5, 0)
anweisung.Position = UDim2.new(0.5, 0, 0, 6)
anweisung.Size = UDim2.new(0.7, 0, 0, 58)
anweisung.BackgroundColor3 = Color3.fromRGB(25, 30, 40)
anweisung.BackgroundTransparency = 0.1
anweisung.Parent = hud
local ag = Instance.new("UISizeConstraint")
ag.MaxSize = Vector2.new(470, 58)
ag.Parent = anweisung
Instance.new("UICorner", anweisung).CornerRadius = UDim.new(0, 10)

local lektionTitel = Instance.new("TextLabel")
lektionTitel.BackgroundTransparency = 1
lektionTitel.Position = UDim2.fromOffset(10, 4)
lektionTitel.Size = UDim2.new(1, -20, 0, 14)
lektionTitel.Font = Enum.Font.GothamBold
lektionTitel.TextSize = 11
lektionTitel.TextColor3 = Color3.fromRGB(150, 180, 230)
lektionTitel.TextXAlignment = Enum.TextXAlignment.Left
lektionTitel.Parent = anweisung

local anweisungText = Instance.new("TextLabel")
anweisungText.BackgroundTransparency = 1
anweisungText.Position = UDim2.fromOffset(10, 19)
anweisungText.Size = UDim2.new(1, -20, 1, -22)
anweisungText.Font = Enum.Font.GothamMedium
anweisungText.TextSize = 14
anweisungText.TextWrapped = true
anweisungText.TextColor3 = Color3.new(1, 1, 1)
anweisungText.TextXAlignment = Enum.TextXAlignment.Left
anweisungText.TextYAlignment = Enum.TextYAlignment.Top
anweisungText.Parent = anweisung

local warnText = Instance.new("TextLabel")
warnText.AnchorPoint = Vector2.new(0.5, 0)
warnText.Position = UDim2.new(0.5, 0, 0, 70)
warnText.Size = UDim2.new(0.7, 0, 0, 28)
warnText.BackgroundColor3 = ROT
warnText.Font = Enum.Font.GothamBold
warnText.TextSize = 14
warnText.TextColor3 = Color3.new(1, 1, 1)
warnText.Visible = false
warnText.Parent = hud
Instance.new("UICorner", warnText)
local wg = Instance.new("UISizeConstraint")
wg.MaxSize = Vector2.new(440, 28)
wg.Parent = warnText

local tacho = Instance.new("Frame")
tacho.AnchorPoint = Vector2.new(1, 1)
tacho.Position = UDim2.new(1, -16, 1, -16)
tacho.Size = UDim2.fromOffset(170, 110)
tacho.BackgroundColor3 = Color3.fromRGB(25, 30, 40)
tacho.BackgroundTransparency = 0.1
tacho.Parent = hud
Instance.new("UICorner", tacho).CornerRadius = UDim.new(0, 10)

local tempoText = Instance.new("TextLabel")
tempoText.BackgroundTransparency = 1
tempoText.Position = UDim2.fromOffset(10, 8)
tempoText.Size = UDim2.fromOffset(95, 50)
tempoText.Font = Enum.Font.GothamBlack
tempoText.TextSize = 40
tempoText.TextColor3 = Color3.new(1, 1, 1)
tempoText.Text = "0"
tempoText.Parent = tacho

local einheit = Instance.new("TextLabel")
einheit.BackgroundTransparency = 1
einheit.Position = UDim2.fromOffset(10, 56)
einheit.Size = UDim2.fromOffset(95, 16)
einheit.Font = Enum.Font.Gotham
einheit.TextSize = 13
einheit.TextColor3 = Color3.fromRGB(180, 185, 195)
einheit.Text = "km/h"
einheit.Parent = tacho

local schild = Instance.new("TextLabel")
schild.Position = UDim2.fromOffset(112, 12)
schild.Size = UDim2.fromOffset(48, 48)
schild.BackgroundColor3 = Color3.new(1, 1, 1)
schild.Font = Enum.Font.GothamBlack
schild.TextSize = 18
schild.TextColor3 = Color3.new(0, 0, 0)
schild.Text = "50"
schild.Parent = tacho
Instance.new("UICorner", schild).CornerRadius = UDim.new(1, 0)
local schildRand = Instance.new("UIStroke")
schildRand.Color = ROT
schildRand.Thickness = 5
schildRand.Parent = schild

local fehlerText = Instance.new("TextLabel")
fehlerText.BackgroundTransparency = 1
fehlerText.Position = UDim2.fromOffset(10, 80)
fehlerText.Size = UDim2.new(1, -20, 0, 20)
fehlerText.Font = Enum.Font.GothamBold
fehlerText.TextSize = 14
fehlerText.TextColor3 = Color3.fromRGB(255, 200, 120)
fehlerText.TextXAlignment = Enum.TextXAlignment.Left
fehlerText.Text = "Mistakes: 0"
fehlerText.Parent = tacho

-- Indicator buttons above the speedometer (also work on phones)
local blinkerModus = "aus"
local blinkLeiste = Instance.new("Frame")
blinkLeiste.AnchorPoint = Vector2.new(1, 1)
blinkLeiste.Position = UDim2.new(1, -16, 1, -132)
blinkLeiste.Size = UDim2.fromOffset(170, 36)
blinkLeiste.BackgroundTransparency = 1
blinkLeiste.Parent = hud
local blinkLayout = Instance.new("UIListLayout")
blinkLayout.FillDirection = Enum.FillDirection.Horizontal
blinkLayout.Padding = UDim.new(0, 6)
blinkLayout.Parent = blinkLeiste
local blinkKnoepfe = {}
local function blinkerSetzen(modus)
	if blinkerModus == modus then modus = "aus" end
	blinkerModus = modus
	blinkerEvent:FireServer(modus)
end
for i, b in { { "links", "◀ Y" }, { "warn", "⚠ X" }, { "rechts", "C ▶" } } do
	local k = Instance.new("TextButton")
	k.LayoutOrder = i
	k.Size = UDim2.fromOffset(52, 36)
	k.BackgroundColor3 = Color3.fromRGB(25, 30, 40)
	k.BackgroundTransparency = 0.1
	k.Font = Enum.Font.GothamBold
	k.TextSize = 14
	k.TextColor3 = Color3.new(1, 1, 1)
	k.Text = b[2]
	k.Parent = blinkLeiste
	Instance.new("UICorner", k)
	k.MouseButton1Click:Connect(function() blinkerSetzen(b[1]) end)
	blinkKnoepfe[b[1]] = k
end

-- second row (also for phones): headlights and handbrake
do
	local reihe2 = Instance.new("Frame")
	reihe2.AnchorPoint = Vector2.new(1, 1)
	reihe2.Position = UDim2.new(1, -16, 1, -174)
	reihe2.Size = UDim2.fromOffset(170, 36)
	reihe2.BackgroundTransparency = 1
	reihe2.Parent = hud
	local l2 = Instance.new("UIListLayout")
	l2.FillDirection = Enum.FillDirection.Horizontal
	l2.HorizontalAlignment = Enum.HorizontalAlignment.Right
	l2.Padding = UDim.new(0, 6)
	l2.Parent = reihe2
	local function knopf(text, breite)
		local k = Instance.new("TextButton")
		k.Size = UDim2.fromOffset(breite, 36)
		k.BackgroundColor3 = Color3.fromRGB(25, 30, 40)
		k.BackgroundTransparency = 0.1
		k.Font = Enum.Font.GothamBold
		k.TextSize = 14
		k.TextColor3 = Color3.new(1, 1, 1)
		k.Text = text
		k.Parent = reihe2
		Instance.new("UICorner", k)
		return k
	end
	local licht = knopf("💡 L", 52)
	licht.MouseButton1Click:Connect(function() blinkerEvent:FireServer("licht") end)
	local hb = knopf("Handbrake ⇧", 110)
	hb.InputBegan:Connect(function(e)
		if e.UserInputType == Enum.UserInputType.Touch or e.UserInputType == Enum.UserInputType.MouseButton1 then _G.Handbremse = true end
	end)
	hb.InputEnded:Connect(function(e)
		if e.UserInputType == Enum.UserInputType.Touch or e.UserInputType == Enum.UserInputType.MouseButton1 then _G.Handbremse = false end
	end)
	RunService.RenderStepped:Connect(function()
		hb.BackgroundColor3 = _G.Handbremse and Color3.fromRGB(200, 50, 50) or Color3.fromRGB(25, 30, 40)
	end)
end

-- Markers in the world (only visible to this player): green gates across the road + parking bays
local marker, parkMarker = nil, {}
local hausMarkerWeg
local function markerWeg()
	if marker then marker:Destroy() marker = nil end
	if hausMarkerWeg then hausMarkerWeg() end
	for _, m in parkMarker do m:Destroy() end
	parkMarker = {}
end
local function torTeil(eltern, name, groesse, cf, transparenz)
	local t = Instance.new("Part")
	t.Name = name
	t.Size = groesse
	t.CFrame = cf
	t.Anchored = true
	t.CanCollide = false
	t.CanQuery = false
	t.CanTouch = false
	t.CastShadow = false
	t.Material = Enum.Material.Neon
	t.Color = Color3.fromRGB(60, 255, 120)
	t.Transparency = transparenz
	t.Parent = eltern
	return t
end
local hausMarker = nil
local function markerSetzen(pos, richtung, breite)
	markerWeg()
	richtung = richtung and Vector3.new(richtung.X, 0, richtung.Z) or Vector3.new(0, 0, -1)
	if richtung.Magnitude < 0.1 then richtung = Vector3.new(0, 0, -1) end
	richtung = richtung.Unit
	local hoehe = 9
	local basis = CFrame.lookAt(Vector3.new(pos.X, 0.3, pos.Z), Vector3.new(pos.X, 0.3, pos.Z) + richtung)
	marker = Instance.new("Model")
	marker.Name = "Zieltor"
	for _, seite in { -1, 1 } do
		torTeil(marker, "Pfosten", Vector3.new(0.8, hoehe, 0.8), basis * CFrame.new(seite * breite / 2, hoehe / 2, 0), 0.15)
	end
	torTeil(marker, "Balken", Vector3.new(breite + 0.8, 0.8, 0.8), basis * CFrame.new(0, hoehe, 0), 0.15)
	torTeil(marker, "Vorhang", Vector3.new(breite, hoehe, 0.2), basis * CFrame.new(0, hoehe / 2, 0), 0.8)
	marker.Parent = workspace
end

-- floating package sign above the house you deliver to
function hausMarkerWeg()
	if hausMarker then hausMarker:Destroy() hausMarker = nil end
end
local function hausMarkerSetzen(pos, symbol)
	hausMarkerWeg()
	local anker = Instance.new("Part")
	anker.Name = "Lieferziel"
	anker.Anchored = true
	anker.CanCollide = false
	anker.CanQuery = false
	anker.CanTouch = false
	anker.Transparency = 1
	anker.Size = Vector3.new(1, 1, 1)
	anker.Position = pos + Vector3.new(0, 22, 0)
	anker.Parent = workspace
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(70, 70)
	bb.AlwaysOnTop = true
	bb.Parent = anker
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundColor3 = Color3.fromRGB(230, 120, 30)
	l.Text = symbol or "📦"
	l.TextScaled = true
	l.Font = Enum.Font.GothamBlack
	l.Parent = bb
	Instance.new("UICorner", l).CornerRadius = UDim.new(1, 0)
	local rand = Instance.new("UIStroke")
	rand.Color = Color3.new(1, 1, 1)
	rand.Thickness = 3
	rand.Parent = l
	hausMarker = anker
end

local warnBis = 0
local function warnen(t, farbe)
	warnText.Text = t
	warnText.BackgroundColor3 = farbe or ROT
	warnText.Visible = true
	warnBis = os.clock() + 3.5
end

local fehlerGrenze = nil
local lektionAktiv = false
local function hudAus()
	lektionAktiv = false
	hud.Enabled = false
	blinkerModus = "aus"
	if _G.MinimapRoute then _G.MinimapRoute(nil) end
	markerWeg()
end
fahrEvent.OnClientEvent:Connect(function(info)
	if info.typ == "blinker" then
		blinkerModus = info.modus
	elseif info.typ == "start" then
		blinkerModus = "aus"
		lektionAktiv = true
		hud.Enabled = true
		fehlerGrenze = info.grenze
		lektionTitel.Text = info.titel
		anweisungText.Text = (info.sprecher or "Instructor") .. ": " .. info.text
		fehlerText.Text = info.status or ("Mistakes: 0/%d"):format(fehlerGrenze or 9)
		schliessen()
	elseif info.typ == "ziel" then
		lektionAktiv = true
		hud.Enabled = true
		anweisungText.Text = (info.sprecher or "Instructor") .. ": " .. info.text
		lektionTitel.Text = lektionTitel.Text:gsub("  %(.*%)$", "") .. ("  (%d/%d)"):format(info.nr, info.gesamt)
		if info.status then fehlerText.Text = info.status end
		markerWeg()
		if info.pos then
			markerSetzen(info.pos, info.richtung, info.breite or 26)
		end
		if info.haus then hausMarkerSetzen(info.haus, info.symbol) end
		if _G.MinimapRoute then _G.MinimapRoute(info.route, info.nr) end
		for _, b in info.park or {} do
			local pm = Instance.new("Part")
			pm.Name = "Parkmarker"
			pm.Size = Vector3.new(b.groesse.X - 0.6, 0.2, b.groesse.Z)
			pm.CFrame = b.cf + Vector3.new(0, 0.5, 0)
			pm.Anchored = true
			pm.CanCollide = false
			pm.CanQuery = false
			pm.CanTouch = false
			pm.CastShadow = false
			pm.Material = Enum.Material.Neon
			pm.Color = Color3.fromRGB(60, 160, 255)
			pm.Transparency = 0.6
			pm.Parent = workspace
			table.insert(parkMarker, pm)
		end
	elseif info.typ == "weg" then
		-- show the way to a vehicle on the minimap
		if _G.MinimapRoute then _G.MinimapRoute({ { info.pos.X, info.pos.Z } }, 1) end
	elseif info.typ == "warnung" then
		warnen(info.text)
		fehlerText.Text = ("Mistakes: %d/%d"):format(info.fehler, info.grenze or fehlerGrenze or 9)
	elseif info.typ == "hinweis" then
		warnen(info.text, info.farbe == "gruen" and GRUEN or Color3.fromRGB(200, 140, 30))
	elseif info.typ == "polizei" then
		if _G.PolizeiBanner then _G.PolizeiBanner(info.phase, info.text) end
	elseif info.typ == "blitz" then
		if _G.Blitz then _G.Blitz(info.text) end
	elseif info.typ == "punkte" then
		warnen(("⚠ +%d penalty point%s – now %d/%d"):format(info.plus, info.plus > 1 and "s" or "", info.punkte, info.limit), Color3.fromRGB(200, 120, 20))
	elseif info.typ == "entzug" then
		zeige("⛔ License withdrawn", ("You reached <b>%d penalty points</b>. Your driver's license (and truck license) has been withdrawn.\n\nYou may not drive your own cars or do driving jobs until you get it back:\n1. Retraining course with Anna (%d coins)\n2. New practical driving test"):format(info.limit, info.preis), {
			{ text = "Okay", farbe = ROT, klick = schliessen },
		}, "hinweis")
	elseif info.typ == "mission" then
		warnen("🎯 Daily mission complete: " .. (info.text or ""), GRUEN)
	elseif info.typ == "xp" then
		if _G.XpAnzeigen then _G.XpAnzeigen(info.menge, info.grund, info.level, info.aufstieg) end
	elseif info.typ == "geld" then
		if _G.GeldAnzeigen then _G.GeldAnzeigen(info.betrag, info.grund) end
	elseif info.typ == "bestanden" then
		hudAus()
		if _G.Cutscene then task.spawn(_G.Cutscene, info) end
	elseif info.typ == "jobende" then
		hudAus()
		zeige(info.erfolg and "Job complete! 📦" or "Job ended", info.text .. ("\n\nPackages delivered: <b>%d</b>\nEarned: <b>%d coins</b>"):format(info.geliefert or 0, info.verdient or 0)
			.. (info.erfolg and "\n\nTalk to Tom at the depot for the next job." or ""), {
			{ text = "Close", farbe = info.erfolg and GRUEN or GRAU, klick = schliessen },
		}, "hinweis")
	elseif info.typ == "ende" then
		hudAus()
		local titelText = info.erfolg and ("Lesson %d/%d complete! 🎉"):format(info.nr, info.gesamt) or (info.pruefung and "Driving test failed" or "Lesson ended")
		zeige(titelText, info.text .. ("\n\nMistakes: %d"):format(info.fehler or 0) .. (info.erfolg and "\n\nTalk to Anna at the reception for your next lesson." or ""), {
			{ text = "Close", farbe = info.erfolg and GRUEN or GRAU, klick = schliessen },
		}, "hinweis")
	end
end)

RunService.RenderStepped:Connect(function()
	if warnText.Visible and os.clock() > warnBis then
		warnText.Visible = false
	end
	-- free driving (own car): speedometer and indicator buttons without the instruction box
	if not lektionAktiv then
		local h = spieler.Character and spieler.Character:FindFirstChildOfClass("Humanoid")
		local s2 = h and h.SeatPart
		local faehrt = s2 ~= nil and s2:IsA("VehicleSeat") and s2.Parent ~= nil and s2.Parent:GetAttribute("MaxTempo") ~= nil
		hud.Enabled = faehrt or warnText.Visible
		anweisung.Visible = false
		if faehrt then
			local m2 = s2.Parent
			local tank, zustand = m2:GetAttribute("Tank"), m2:GetAttribute("Zustand")
			if tank then
				fehlerText.Text = ("⛽ %d%%   🔧 %d%%   Pts %d/8"):format(tank, zustand or 100, spieler:GetAttribute("Punkte") or 0)
				fehlerText.TextColor3 = (tank < 15 or (zustand or 100) < 30) and Color3.fromRGB(255, 110, 90) or Color3.fromRGB(255, 200, 120)
			else
				fehlerText.Text = ("Points: %d/8"):format(spieler:GetAttribute("Punkte") or 0)
			end
		end
	else
		anweisung.Visible = true
	end
	if not hud.Enabled then return end
	local char = spieler.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local sitz = hum and hum.SeatPart
	local an = (os.clock() % 0.8) < 0.4
	for modus, k in blinkKnoepfe do
		local aktiv = blinkerModus == "warn" or blinkerModus == modus
		k.BackgroundColor3 = (aktiv and an) and Color3.fromRGB(255, 165, 30) or Color3.fromRGB(25, 30, 40)
	end
	if sitz and sitz:IsA("VehicleSeat") then
		local tempo = math.floor(sitz.AssemblyLinearVelocity.Magnitude + 0.5)
		local limit = Regeln.tempolimit(sitz.Position)
		tempoText.TextColor3 = tempo > limit + 3 and ROT or Color3.new(1, 1, 1)
		if _G.Einstellungen and _G.Einstellungen.mph then
			tempoText.Text = tostring(math.floor(tempo * 0.621 + 0.5))
			schild.Text = tostring(math.floor(limit * 0.621 / 5 + 0.5) * 5)
			einheit.Text = "mph"
		else
			tempoText.Text = tostring(tempo)
			schild.Text = tostring(limit)
			einheit.Text = "km/h"
		end
		tacho.Visible = true
	else
		tacho.Visible = false
	end
end)

-- ---------------------------------------------------------------
-- Car control (runs on the driver's computer = direct, responsive steering)
-- ---------------------------------------------------------------
local fahrVerbindung
local function fahrenStoppen()
	if fahrVerbindung then
		fahrVerbindung:Disconnect()
		fahrVerbindung = nil
	end
end

local function fahrenStarten(sitz, hum)
	fahrenStoppen()
	local modell = sitz.Parent
	local chassis = modell and modell:FindFirstChild("Chassis")
	if not chassis then return end
	local motoren, servos = {}, {}
	for _, h in chassis:GetChildren() do
		if h:IsA("HingeConstraint") then
			if h.ActuatorType == Enum.ActuatorType.Motor then
				table.insert(motoren, h)
			else
				table.insert(servos, h)
			end
		end
	end
	local function wert(name, standard)
		local v = modell:GetAttribute(name)
		if v == nil then return standard end
		return v
	end
	local lenkGlatt = 0

	fahrVerbindung = RunService.Heartbeat:Connect(function(dt)
		if hum.SeatPart ~= sitz or not chassis.Parent then
			fahrenStoppen()
			return
		end
		local radius = wert("Radius", 1.3)
		local maxTempo = wert("MaxTempo", 130)
		local bremse = wert("Bremse", 14000)
		local gas, lenk = sitz.ThrottleFloat, sitz.SteerFloat
		lenkGlatt += (lenk - lenkGlatt) * math.min(1, dt * 14)

		local cf = chassis.CFrame
		local v = chassis.AssemblyLinearVelocity
		local tempo = v:Dot(cf.LookVector) -- forward = positive

		-- engine and brakes
		local ziel, moment = 0, 300
		if gas ~= 0 then
			if tempo * gas < -1.5 then
				ziel, moment = 0, bremse                      -- pressing against the direction = brake
			else
				local grenze = gas > 0 and maxTempo or maxTempo * 0.25
				ziel, moment = gas * grenze / radius, wert("Antrieb", 4500)
			end
		elseif math.abs(tempo) < 1 then
			moment = bremse                                     -- hold the car when standing
		end
		if modell:GetAttribute("Gesperrt") then
			ziel, moment = 0, bremse
		end
		if _G.Handbremse then
			ziel, moment = 0, bremse * 1.5 -- handbrake locks the rear wheels
		end
		for _, mo in motoren do
			mo.AngularVelocity = -ziel * wert("RICHTUNG", 1)
			mo.MotorMaxTorque = moment
		end

		-- steering: less angle at higher speed
		local maxWinkel = wert("Lenkwinkel", 34)
		local winkel = math.clamp(maxWinkel - math.abs(tempo) * 0.18, 8, maxWinkel)
		local einschlag = lenkGlatt * winkel
		for _, se in servos do
			se.TargetAngle = -einschlag -- wheels turn visibly
		end
		-- direct steering: the car turns exactly as fast as a real car with this
		-- steering angle would (speed x tan(angle) / wheelbase), no floaty delay
		local zielDrehung = -tempo * math.tan(math.rad(einschlag)) / wert("Radstand", 9.6)
		local w0 = chassis.AssemblyAngularVelocity
		local neu = w0.Y + (zielDrehung - w0.Y) * math.min(1, wert("Lenkdirekt", 14) * dt)
		chassis.AssemblyAngularVelocity = Vector3.new(w0.X, neu, w0.Z)

		-- grip (no sliding sideways), downforce and roll/pitch damping
		local masse = chassis.AssemblyMass
		local quer = v:Dot(cf.RightVector)
		-- rain makes the road slippery, the handbrake lets the rear slide (drift)
		local griff = wert("Grip", 14) * (ordner:GetAttribute("Wetter") == "Rain" and 0.7 or 1) * (_G.Handbremse and 0.35 or 1)
		chassis:ApplyImpulse(-cf.RightVector * quer * masse * math.min(1, griff * dt))
		chassis:ApplyImpulse(-cf.UpVector * masse * wert("Anpressdruck", 60) * dt)
		local w = chassis.AssemblyAngularVelocity
		local rollen = w:Dot(cf.LookVector)
		local nicken = w:Dot(cf.RightVector)
		chassis:ApplyAngularImpulse((-cf.LookVector * rollen - cf.RightVector * nicken) * masse * 8 * math.min(1, 6 * dt))
	end)
end

local function figurEinrichten(figur)
	local hum = figur:WaitForChild("Humanoid")
	hum.Seated:Connect(function(sitzt, sitz)
		if sitzt and sitz and sitz:IsA("VehicleSeat") and sitz.Parent and sitz.Parent:GetAttribute("MaxTempo") then
			fahrenStarten(sitz, hum)
		else
			fahrenStoppen()
		end
	end)
end
if spieler.Character then task.spawn(figurEinrichten, spieler.Character) end
spieler.CharacterAdded:Connect(figurEinrichten)

-- ---------------------------------------------------------------
-- First person / third person (key V or the button)
-- ---------------------------------------------------------------
local UIS = game:GetService("UserInputService")
local kameraGui = Instance.new("ScreenGui")
kameraGui.Name = "CameraToggle"
kameraGui.ResetOnSpawn = false
kameraGui.Parent = spieler.PlayerGui
local kameraKnopf = Instance.new("TextButton")
kameraKnopf.Position = UDim2.new(0, 12, 0, 64)
kameraKnopf.Size = UDim2.fromOffset(150, 32)
kameraKnopf.BackgroundColor3 = Color3.fromRGB(25, 30, 40)
kameraKnopf.BackgroundTransparency = 0.2
kameraKnopf.Font = Enum.Font.GothamBold
kameraKnopf.TextSize = 14
kameraKnopf.TextColor3 = Color3.new(1, 1, 1)
kameraKnopf.Text = "1st person (V)"
kameraKnopf.Parent = kameraGui
Instance.new("UICorner", kameraKnopf)

local ersteP = false
local function perspektive(an)
	ersteP = an
	if an then
		spieler.CameraMode = Enum.CameraMode.LockFirstPerson
		kameraKnopf.Text = "3rd person (V)"
	else
		spieler.CameraMode = Enum.CameraMode.Classic
		spieler.CameraMinZoomDistance = 12 -- jump out of first person ...
		task.delay(0.15, function()
			spieler.CameraMinZoomDistance = 0.5 -- ... but still allow zooming in with the mouse wheel
		end)
		kameraKnopf.Text = "1st person (V)"
	end
end
kameraKnopf.MouseButton1Click:Connect(function()
	perspektive(not ersteP)
end)
UIS.InputBegan:Connect(function(eingabe, verarbeitet)
	if verarbeitet then return end
	if eingabe.KeyCode == Enum.KeyCode.V then
		perspektive(not ersteP)
	end
end)

-- ---------------------------------------------------------------
-- Test menu (only visible in Roblox Studio)
-- ---------------------------------------------------------------
if RunService:IsStudio() then
	local devGui = Instance.new("ScreenGui")
	devGui.Name = "TestMenu"
	devGui.ResetOnSpawn = false
	devGui.Parent = spieler.PlayerGui
	local leiste = Instance.new("Frame")
	leiste.AnchorPoint = Vector2.new(0, 0)
	leiste.Position = UDim2.new(0, 12, 0, 140)
	leiste.Size = UDim2.fromOffset(150, 0)
	leiste.AutomaticSize = Enum.AutomaticSize.Y
	leiste.BackgroundColor3 = Color3.fromRGB(60, 20, 20)
	leiste.BackgroundTransparency = 0.15
	leiste.Parent = devGui
	Instance.new("UICorner", leiste)
	local polster = Instance.new("UIPadding")
	for _, seite in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do
		polster[seite] = UDim.new(0, 6)
	end
	polster.Parent = leiste
	local ll = Instance.new("UIListLayout")
	ll.Padding = UDim.new(0, 4)
	ll.SortOrder = Enum.SortOrder.LayoutOrder
	ll.Parent = leiste
	local ueberschrift = Instance.new("TextLabel")
	ueberschrift.Size = UDim2.new(1, 0, 0, 18)
	ueberschrift.BackgroundTransparency = 1
	ueberschrift.Font = Enum.Font.GothamBlack
	ueberschrift.TextSize = 13
	ueberschrift.TextColor3 = Color3.fromRGB(255, 200, 200)
	ueberschrift.Text = "TEST MENU (Studio)"
	ueberschrift.Parent = leiste
	local function devKnopf(reihenfolge, beschriftung, befehl, nr)
		local k = Instance.new("TextButton")
		k.LayoutOrder = reihenfolge
		k.Size = UDim2.new(1, 0, 0, 26)
		k.BackgroundColor3 = Color3.fromRGB(110, 40, 40)
		k.Font = Enum.Font.GothamBold
		k.TextSize = 13
		k.TextColor3 = Color3.new(1, 1, 1)
		k.Text = beschriftung
		k.Parent = leiste
		Instance.new("UICorner", k)
		k.MouseButton1Click:Connect(function()
			local r = frage("dev", { befehl = befehl, nr = nr })
			hinweis(r.fehler or r.text or "Done.")
		end)
	end
	devKnopf(1, "Skip theory", "theorie")
	for nr = 1, 5 do
		devKnopf(1 + nr, "Start lesson " .. nr, "lektion", nr)
	end
	devKnopf(7, "Start driving test", "pruefung")
	devKnopf(8, "Get license (cutscene)", "lizenz")
	devKnopf(9, "Start truck test", "lkw")
	devKnopf(10, "Get truck license", "lkwlizenz")
	devKnopf(11, "+500 coins", "geld")
	devKnopf(12, "Reset progress", "reset")
end

-- Admin money buttons (only visible for the owner of the game; the server checks it again)
do
	local adminGui
	local function adminZeigen()
		if adminGui or not spieler:GetAttribute("Admin") then return end
		adminGui = Instance.new("ScreenGui")
		adminGui.Name = "Admin"
		adminGui.ResetOnSpawn = false
		adminGui.IgnoreGuiInset = true
		adminGui.DisplayOrder = 8
		adminGui.Parent = spieler.PlayerGui
		local leiste2 = Instance.new("Frame")
		leiste2.AnchorPoint = Vector2.new(1, 0)
		leiste2.Position = UDim2.new(1, -16, 0, 122)
		leiste2.Size = UDim2.fromOffset(0, 30)
		leiste2.AutomaticSize = Enum.AutomaticSize.X
		leiste2.BackgroundTransparency = 1
		leiste2.Parent = adminGui
		local reihe2 = Instance.new("UIListLayout")
		reihe2.FillDirection = Enum.FillDirection.Horizontal
		reihe2.HorizontalAlignment = Enum.HorizontalAlignment.Right
		reihe2.Padding = UDim.new(0, 6)
		reihe2.SortOrder = Enum.SortOrder.LayoutOrder
		reihe2.Parent = leiste2
		for i, k in { { "+10K", 10000 }, { "+100K", 100000 }, { "0", -1 } } do
			local b = Instance.new("TextButton")
			b.LayoutOrder = i
			b.Size = UDim2.fromOffset(i == 3 and 34 or 64, 30)
			b.BackgroundColor3 = i == 3 and Color3.fromRGB(120, 40, 40) or Color3.fromRGB(150, 110, 20)
			b.BackgroundTransparency = 0.1
			b.Font = Enum.Font.GothamBlack
			b.TextSize = 13
			b.TextColor3 = Color3.new(1, 1, 1)
			b.Text = i == 3 and "0" or ("💰 " .. k[1])
			b.Parent = leiste2
			Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
			b.MouseButton1Click:Connect(function()
				local r = frage("adminGeld", k[2])
				if r.fehler then hinweis(r.fehler) end
			end)
		end
	end
	adminZeigen()
	spieler:GetAttributeChangedSignal("Admin"):Connect(adminZeigen)
end

-- Handbrake is released when Shift is let go
UIS.InputEnded:Connect(function(eingabe)
	if eingabe.KeyCode == Enum.KeyCode.LeftShift or eingabe.KeyCode == Enum.KeyCode.RightShift then
		_G.Handbremse = false
	end
end)

-- Indicator keys on PC: Y (or Z on US keyboards) = left, C = right, X = hazard lights
UIS.InputBegan:Connect(function(eingabe, verarbeitet)
	if verarbeitet then return end
	local hum = spieler.Character and spieler.Character:FindFirstChildOfClass("Humanoid")
	local sitz = hum and hum.SeatPart
	if not (sitz and sitz:IsA("VehicleSeat") and sitz.Parent and sitz.Parent:GetAttribute("Fahrschulauto")) then return end
	local taste = eingabe.KeyCode
	if taste == Enum.KeyCode.L then
		blinkerEvent:FireServer("licht")
	elseif taste == Enum.KeyCode.LeftShift or taste == Enum.KeyCode.RightShift then
		_G.Handbremse = true
	elseif taste == Enum.KeyCode.Y or taste == Enum.KeyCode.Z then
		blinkerSetzen("links")
	elseif taste == Enum.KeyCode.C then
		blinkerSetzen("rechts")
	elseif taste == Enum.KeyCode.X then
		blinkerSetzen("warn")
	end
end)

-- ---------------------------------------------------------------
-- Minimap (bottom left): a small 3D view from above inside a ViewportFrame.
-- A ViewportFrame always stays inside its own box, so the map can never cover the screen.
-- It turns with you like a navigation system and shows the lesson route.
-- ---------------------------------------------------------------
do
	local GROESSE = 190        -- diameter in pixels
	local SICHT = 300          -- studs visible from top to bottom
	local STUD_METER = 0.28
	local FARBEN = {
		strasse = Color3.fromRGB(62, 66, 74),
		kreis = Color3.fromRGB(62, 66, 74),
		gehweg = Color3.fromRGB(176, 176, 172),
		haus = Color3.fromRGB(222, 212, 192),
		schule = Color3.fromRGB(60, 125, 230),
		insel = Color3.fromRGB(96, 150, 78),
	}
	local HOEHE = { strasse = 0, kreis = 0, gehweg = 0.3, insel = 0.5, haus = 1.5, schule = 2 }

	local mmGui = Instance.new("ScreenGui")
	mmGui.Name = "Minimap"
	mmGui.ResetOnSpawn = false
	mmGui.Parent = spieler.PlayerGui
	_G.MinimapGui = mmGui

	local halter = Instance.new("Frame")
	halter.AnchorPoint = Vector2.new(0, 1)
	halter.Position = UDim2.new(0, 14, 1, -14)
	halter.Size = UDim2.fromOffset(GROESSE, GROESSE + 22)
	halter.BackgroundTransparency = 1
	halter.Parent = mmGui

	local schatten = Instance.new("Frame")
	schatten.Position = UDim2.fromOffset(3, 4)
	schatten.Size = UDim2.fromOffset(GROESSE, GROESSE)
	schatten.BackgroundColor3 = Color3.new(0, 0, 0)
	schatten.BackgroundTransparency = 0.6
	schatten.Parent = halter
	Instance.new("UICorner", schatten).CornerRadius = UDim.new(1, 0)

	local rund = Instance.new("CanvasGroup") -- makes the corners round
	rund.Size = UDim2.fromOffset(GROESSE, GROESSE)
	rund.BackgroundTransparency = 1
	rund.Parent = halter
	Instance.new("UICorner", rund).CornerRadius = UDim.new(1, 0)

	local vf = Instance.new("ViewportFrame")
	vf.Size = UDim2.fromScale(1, 1)
	vf.BackgroundColor3 = Color3.fromRGB(104, 148, 80)
	vf.Ambient = Color3.fromRGB(190, 190, 190)
	vf.LightColor = Color3.fromRGB(255, 255, 255)
	vf.LightDirection = Vector3.new(-0.3, -1, -0.2)
	vf.Parent = rund
	Instance.new("UICorner", vf).CornerRadius = UDim.new(1, 0)
	local kamera = Instance.new("Camera")
	kamera.FieldOfView = 30
	kamera.Parent = vf
	vf.CurrentCamera = kamera
	local hoehe = (SICHT / 2) / math.tan(math.rad(kamera.FieldOfView / 2))

	local ring = Instance.new("Frame")
	ring.Size = UDim2.fromOffset(GROESSE, GROESSE)
	ring.BackgroundTransparency = 1
	ring.ZIndex = 20
	ring.Parent = halter
	Instance.new("UICorner", ring).CornerRadius = UDim.new(1, 0)
	local ringLinie = Instance.new("UIStroke")
	ringLinie.Color = Color3.fromRGB(28, 32, 42)
	ringLinie.Thickness = 4
	ringLinie.Parent = ring

	local function kartenTeil(groesse, cf, farbe, form)
		local t = Instance.new("Part")
		t.Anchored = true
		t.Size = groesse
		t.CFrame = cf
		t.Color = farbe
		t.Material = Enum.Material.SmoothPlastic
		if form then t.Shape = form end
		t.Parent = vf
		return t
	end

	task.spawn(function()
		local r = frage("kartendaten")
		if not r.daten then return end
		for _, e in r.daten do
			local typ, x, z, sx, sz = e[1], e[2], e[3], e[4], e[5]
			local h = HOEHE[typ] or 0
			if typ == "kreis" or typ == "insel" then
				kartenTeil(Vector3.new(0.5, sx, sx), CFrame.new(x, h, z) * CFrame.Angles(0, 0, math.rad(90)), FARBEN[typ], Enum.PartType.Cylinder)
			else
				kartenTeil(Vector3.new(sx, 0.5 + h, sz), CFrame.new(x, (0.5 + h) / 2, z), FARBEN[typ] or FARBEN.strasse)
			end
		end
	end)

	local routenOrdner = Instance.new("Folder")
	routenOrdner.Parent = vf
	local function balken(x1, z1, x2, z2, dicke, farbe, y)
		local a, b = Vector3.new(x1, y, z1), Vector3.new(x2, y, z2)
		local laenge = (b - a).Magnitude
		if laenge < 0.1 then return end
		local t = kartenTeil(Vector3.new(dicke, 0.4, laenge + dicke), CFrame.lookAt((a + b) / 2, b), farbe)
		t.Parent = routenOrdner
		return t
	end

	local route, routeNr = nil, 1
	local zuMir
	_G.MinimapRoute = function(neueRoute, nr)
		routenOrdner:ClearAllChildren()
		zuMir = nil
		route, routeNr = neueRoute, nr or 1
		if not route then return end
		for i = math.max(routeNr, 1), #route - 1 do
			balken(route[i][1], route[i][2], route[i + 1][1], route[i + 1][2], 7, Color3.fromRGB(40, 150, 255), 4)
		end
		local ziel = route[routeNr]
		if ziel then
			local punkt = kartenTeil(Vector3.new(0.5, 14, 14), CFrame.new(ziel[1], 5, ziel[2]) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(60, 255, 120), Enum.PartType.Cylinder)
			punkt.Parent = routenOrdner
		end
	end

	-- player arrow in the middle (always points up, the map turns underneath)
	local pfeil = Instance.new("TextLabel")
	pfeil.AnchorPoint = Vector2.new(0.5, 0.5)
	pfeil.Position = UDim2.fromScale(0.5, 0.5)
	pfeil.Size = UDim2.fromOffset(22, 22)
	pfeil.BackgroundTransparency = 1
	pfeil.Text = "▲"
	pfeil.TextScaled = true
	pfeil.Font = Enum.Font.GothamBlack
	pfeil.TextColor3 = Color3.fromRGB(255, 215, 50)
	pfeil.TextStrokeColor3 = Color3.fromRGB(30, 30, 30)
	pfeil.TextStrokeTransparency = 0
	pfeil.ZIndex = 15
	pfeil.Parent = halter
	pfeil.Position = UDim2.fromOffset(GROESSE / 2, GROESSE / 2)

	local nord = Instance.new("TextLabel")
	nord.AnchorPoint = Vector2.new(0.5, 0.5)
	nord.Size = UDim2.fromOffset(18, 18)
	nord.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
	nord.Text = "N"
	nord.Font = Enum.Font.GothamBlack
	nord.TextSize = 11
	nord.TextColor3 = Color3.new(1, 1, 1)
	nord.ZIndex = 21
	nord.Parent = halter
	Instance.new("UICorner", nord).CornerRadius = UDim.new(1, 0)

	local abstandText = Instance.new("TextLabel")
	abstandText.Position = UDim2.fromOffset(0, GROESSE + 4)
	abstandText.Size = UDim2.fromOffset(GROESSE, 18)
	abstandText.BackgroundTransparency = 1
	abstandText.Font = Enum.Font.GothamBold
	abstandText.TextSize = 13
	abstandText.TextColor3 = Color3.new(1, 1, 1)
	abstandText.TextStrokeTransparency = 0.4
	abstandText.Text = ""
	abstandText.Parent = halter

	RunService.RenderStepped:Connect(function()
		if not mmGui.Enabled then return end
		local char = spieler.Character
		local wurzel = char and char:FindFirstChild("HumanoidRootPart")
		if not wurzel then return end
		local hum = char:FindFirstChildOfClass("Humanoid")
		local bezug = (hum and hum.SeatPart) or wurzel
		local pos = bezug.Position
		local blick = bezug.CFrame.LookVector
		local vorne = Vector3.new(blick.X, 0, blick.Z)
		if vorne.Magnitude < 0.01 then vorne = Vector3.new(0, 0, -1) end
		vorne = vorne.Unit
		local boden = Vector3.new(pos.X, 0, pos.Z)
		-- camera above the player, "up" on the screen = driving direction
		kamera.CFrame = CFrame.lookAt(boden + Vector3.new(0, hoehe, 0), boden, vorne)
		local richtung = math.atan2(vorne.X, -vorne.Z)
		local r = GROESSE / 2 - 11
		nord.Position = UDim2.fromOffset(GROESSE / 2 + math.sin(-richtung) * r, GROESSE / 2 - math.cos(-richtung) * r)

		if route and route[routeNr] then
			local zx, zz = route[routeNr][1], route[routeNr][2]
			local a, b = Vector3.new(pos.X, 4.5, pos.Z), Vector3.new(zx, 4.5, zz)
			local laenge = (b - a).Magnitude
			if laenge > 0.5 then
				if not zuMir or not zuMir.Parent then
					zuMir = balken(pos.X, pos.Z, zx, zz, 4, Color3.fromRGB(60, 255, 120), 4.5)
				else
					zuMir.Size = Vector3.new(4, 0.4, laenge + 4)
					zuMir.CFrame = CFrame.lookAt((a + b) / 2, b)
				end
			end
			local meter = math.floor(math.sqrt((zx - pos.X) ^ 2 + (zz - pos.Z) ^ 2) * STUD_METER / 5 + 0.5) * 5
			abstandText.Text = ("Next: %d m"):format(meter)
		else
			abstandText.Text = ""
		end
	end)
end

-- ---------------------------------------------------------------
-- Driver's license card (shown in the cutscene and when you hold the item)
-- ---------------------------------------------------------------
local TweenService = game:GetService("TweenService")

local function fuehrerscheinKarte(eltern, info)
	local karte = Instance.new("Frame")
	karte.Name = "Fuehrerschein"
	karte.AnchorPoint = Vector2.new(0.5, 0.5)
	karte.Position = UDim2.fromScale(0.5, 0.5)
	karte.Size = UDim2.fromOffset(440, 340)
	karte.BackgroundColor3 = Color3.new(1, 1, 1)
	karte.Parent = eltern
	Instance.new("UICorner", karte).CornerRadius = UDim.new(0, 16)
	local verlauf = Instance.new("UIGradient")
	verlauf.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(246, 210, 222)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(236, 228, 245)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 225, 245)),
	})
	verlauf.Rotation = 25
	verlauf.Parent = karte
	local rand = Instance.new("UIStroke")
	rand.Color = Color3.fromRGB(170, 140, 170)
	rand.Thickness = 2
	rand.Parent = karte
	local skala = Instance.new("UIScale")
	skala.Parent = karte

	local function text(t, x, y, b, h, groesse, schrift, farbe, rechts)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromOffset(x, y)
		l.Size = UDim2.fromOffset(b, h)
		l.Text = t
		l.TextSize = groesse
		l.Font = schrift or Enum.Font.GothamBold
		l.TextColor3 = farbe or Color3.fromRGB(45, 40, 70)
		l.TextXAlignment = rechts and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left
		l.TextTruncate = Enum.TextTruncate.AtEnd
		l.Parent = karte
		return l
	end
	-- header band
	local band = Instance.new("Frame")
	band.Size = UDim2.new(1, 0, 0, 46)
	band.BackgroundColor3 = Color3.fromRGB(40, 70, 150)
	band.Parent = karte
	Instance.new("UICorner", band).CornerRadius = UDim.new(0, 16)
	local bandUnten = Instance.new("Frame")
	bandUnten.Position = UDim2.new(0, 0, 1, -16)
	bandUnten.Size = UDim2.new(1, 0, 0, 16)
	bandUnten.BackgroundColor3 = band.BackgroundColor3
	bandUnten.BorderSizePixel = 0
	bandUnten.Parent = band
	text("DRIVER'S LICENSE", 18, 6, 300, 22, 20, Enum.Font.GothamBlack, Color3.new(1, 1, 1)).ZIndex = 2
	text("DRIVING SCHOOL", 18, 26, 300, 14, 11, Enum.Font.GothamBold, Color3.fromRGB(200, 215, 255)).ZIndex = 2
	local klassenText = (info.klassen or "B"):gsub(" ", " · ")
	local klasse = text(klassenText, 260, 6, 164, 36, 30, Enum.Font.GothamBlack, Color3.fromRGB(255, 215, 80), true)
	klasse.ZIndex = 2

	-- photo of the player's avatar
	local foto = Instance.new("ImageLabel")
	foto.Position = UDim2.fromOffset(18, 62)
	foto.Size = UDim2.fromOffset(120, 150)
	foto.BackgroundColor3 = Color3.fromRGB(210, 220, 235)
	foto.ScaleType = Enum.ScaleType.Crop
	foto.Parent = karte
	Instance.new("UICorner", foto).CornerRadius = UDim.new(0, 8)
	task.spawn(function()
		local ok, bild = pcall(function()
			return Players:GetUserThumbnailAsync(info.userId or spieler.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size180x180)
		end)
		if ok and foto.Parent then foto.Image = bild end
	end)

	local y = 62
	for _, zeile in {
		{ "1. NAME", info.name or spieler.DisplayName },
		{ "2. USER", "@" .. (info.benutzer or spieler.Name) },
		{ "3. ISSUED", info.datum or "-" },
		{ "4. LICENSE NO.", info.nummer or "-" },
	} do
		text(zeile[1], 156, y, 260, 13, 11, Enum.Font.GothamBold, Color3.fromRGB(120, 100, 140))
		text(zeile[2], 156, y + 13, 270, 20, 17, Enum.Font.GothamBold)
		y += 37
	end
	text(info.name or spieler.DisplayName, 156, 214, 260, 34, 26, Enum.Font.IndieFlower, Color3.fromRGB(30, 50, 120)) -- signature
	local linie = Instance.new("Frame")
	linie.Position = UDim2.fromOffset(156, 246)
	linie.Size = UDim2.fromOffset(240, 1)
	linie.BackgroundColor3 = Color3.fromRGB(150, 130, 160)
	linie.BorderSizePixel = 0
	linie.Parent = karte
	text("Signature", 18, 222, 120, 14, 11, Enum.Font.Gotham, Color3.fromRGB(120, 100, 140))

	-- 9. license classes: which licenses you have and how many
	local KLASSEN = {
		{ "B", "🚗", "Car", info.datum },
		{ "C", "🚚", "Truck", info.lkwDatum },
	}
	local besitzt = 0
	for _, k in KLASSEN do
		if (info.klassen or "B"):find(k[1], 1, true) then besitzt += 1 end
	end
	text(("9. LICENSE CLASSES  –  %d of %d"):format(besitzt, #KLASSEN), 18, 262, 400, 14, 11, Enum.Font.GothamBold, Color3.fromRGB(120, 100, 140))
	for i, k in KLASSEN do
		local hat = (info.klassen or "B"):find(k[1], 1, true) ~= nil
		local feld = Instance.new("Frame")
		feld.Position = UDim2.fromOffset(18 + (i - 1) * 206, 280)
		feld.Size = UDim2.fromOffset(198, 44)
		feld.BackgroundColor3 = hat and Color3.fromRGB(40, 70, 150) or Color3.fromRGB(215, 210, 222)
		feld.Parent = karte
		Instance.new("UICorner", feld).CornerRadius = UDim.new(0, 8)
		local function zeile(t, x, y, b, h, groesse, schrift, farbe)
			local l = Instance.new("TextLabel")
			l.BackgroundTransparency = 1
			l.Position = UDim2.fromOffset(x, y)
			l.Size = UDim2.fromOffset(b, h)
			l.Text = t
			l.TextSize = groesse
			l.Font = schrift
			l.TextColor3 = farbe
			l.TextXAlignment = Enum.TextXAlignment.Left
			l.Parent = feld
		end
		local hell = hat and Color3.new(1, 1, 1) or Color3.fromRGB(150, 140, 160)
		zeile(k[2], 8, 6, 32, 32, 24, Enum.Font.GothamBold, hell)
		zeile(k[1], 44, 4, 30, 36, 28, Enum.Font.GothamBlack, hat and Color3.fromRGB(255, 215, 80) or hell)
		zeile(k[3], 80, 5, 110, 18, 15, Enum.Font.GothamBold, hell)
		zeile(hat and ("since " .. ((k[4] and k[4] ~= "") and k[4] or "-")) or "not yet", 80, 23, 110, 16, 12, Enum.Font.Gotham, hell)
	end
	-- shiny hologram
	local holo = Instance.new("Frame")
	holo.Position = UDim2.fromOffset(380, 210)
	holo.Size = UDim2.fromOffset(42, 42)
	holo.BackgroundColor3 = Color3.new(1, 1, 1)
	holo.Parent = karte
	Instance.new("UICorner", holo).CornerRadius = UDim.new(1, 0)
	local hv = Instance.new("UIGradient")
	hv.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 180, 220)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(180, 240, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 240, 170)),
	})
	hv.Parent = holo
	task.spawn(function()
		while holo.Parent do
			hv.Rotation = (hv.Rotation + 3) % 360
			task.wait(0.03)
		end
	end)
	return karte, skala
end

-- Holding the license item in your hand shows the card
do
	local ansicht = Instance.new("ScreenGui")
	ansicht.Name = "LizenzAnsicht"
	ansicht.ResetOnSpawn = false
	ansicht.Enabled = false
	ansicht.DisplayOrder = 20
	ansicht.Parent = spieler.PlayerGui
	local aktuelleKarte
	local verbunden = {}
	local function verbinden(tool)
		if verbunden[tool] or not tool:IsA("Tool") or not tool:GetAttribute("Fuehrerschein") then return end
		verbunden[tool] = true
		tool.Equipped:Connect(function()
			if aktuelleKarte then aktuelleKarte:Destroy() end
			local karte, skala = fuehrerscheinKarte(ansicht, {
				name = tool:GetAttribute("Name"), benutzer = tool:GetAttribute("Benutzer"),
				datum = tool:GetAttribute("Datum"), nummer = tool:GetAttribute("Nummer"), userId = spieler.UserId,
				klassen = tool:GetAttribute("Klassen"), lkwDatum = tool:GetAttribute("LkwDatum"),
			})
			karte.Position = UDim2.new(0.5, 0, 1, -190)
			skala.Scale = 0.2
			aktuelleKarte = karte
			ansicht.Enabled = true
			TweenService:Create(skala, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 0.85 }):Play()
		end)
		tool.Unequipped:Connect(function()
			ansicht.Enabled = false
			if aktuelleKarte then aktuelleKarte:Destroy() aktuelleKarte = nil end
		end)
	end
	local function beobachten(behaelter)
		for _, t in behaelter:GetChildren() do verbinden(t) end
		behaelter.ChildAdded:Connect(verbinden)
	end
	beobachten(spieler:WaitForChild("Backpack"))
	spieler.CharacterAdded:Connect(function(figur)
		beobachten(figur)
		task.defer(function() beobachten(spieler:WaitForChild("Backpack")) end)
	end)
	if spieler.Character then beobachten(spieler.Character) end
end

-- ---------------------------------------------------------------
-- Cutscene after passing the driving test
-- ---------------------------------------------------------------
_G.Cutscene = function(info)
	local kamera = workspace.CurrentCamera
	local char = spieler.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local sitz = hum and hum.SeatPart
	local fokus = (sitz and sitz.Parent and sitz.Parent:FindFirstChild("Chassis")) or (char and char:FindFirstChild("HumanoidRootPart"))
	if not fokus then return end
	local fokusCF = fokus.CFrame

	local cg = Instance.new("ScreenGui")
	cg.Name = "Cutscene"
	cg.IgnoreGuiInset = true
	cg.DisplayOrder = 50
	cg.ResetOnSpawn = false
	cg.Parent = spieler.PlayerGui
	-- cinematic black bars
	local balken = {}
	for _, oben in { true, false } do
		local b = Instance.new("Frame")
		b.AnchorPoint = Vector2.new(0, oben and 0 or 1)
		b.Position = UDim2.fromScale(0, oben and 0 or 1)
		b.Size = UDim2.new(1, 0, 0, 0)
		b.BackgroundColor3 = Color3.new(0, 0, 0)
		b.BorderSizePixel = 0
		b.Parent = cg
		table.insert(balken, b)
		TweenService:Create(b, TweenInfo.new(0.8), { Size = UDim2.new(1, 0, 0.12, 0) }):Play()
	end
	local untertitel = Instance.new("TextLabel")
	untertitel.AnchorPoint = Vector2.new(0.5, 1)
	untertitel.Position = UDim2.new(0.5, 0, 0.86, 0)
	untertitel.Size = UDim2.new(0.8, 0, 0, 40)
	untertitel.BackgroundTransparency = 1
	untertitel.Font = Enum.Font.GothamBold
	untertitel.TextSize = 22
	untertitel.TextColor3 = Color3.new(1, 1, 1)
	untertitel.TextStrokeTransparency = 0.3
	untertitel.Text = info.lkw and "Mr. Becker (Examiner): Congratulations, you passed your truck driving test!" or "Mr. Becker (Examiner): Congratulations, you passed your driving test!"
	untertitel.Parent = cg
	local schwarz = Instance.new("Frame")
	schwarz.Size = UDim2.fromScale(1, 1)
	schwarz.BackgroundColor3 = Color3.new(0, 0, 0)
	schwarz.BackgroundTransparency = 1
	schwarz.ZIndex = 5
	schwarz.Parent = cg

	-- camera slowly circles the car
	kamera.CameraType = Enum.CameraType.Scriptable
	local start = os.clock()
	local dauer = 6.5
	local fahrt = RunService.RenderStepped:Connect(function()
		local t = math.min((os.clock() - start) / dauer, 1)
		local winkel = math.rad(-35 + 110 * t)
		local ziel = fokusCF.Position + Vector3.new(0, 2.5, 0)
		local weit = info.lkw and 1.7 or 1
		local auge = (fokusCF * CFrame.Angles(0, winkel, 0) * CFrame.new(0, (3.5 - t) * weit, (-15 + 3 * t) * weit)).Position
		kamera.CFrame = CFrame.lookAt(auge, ziel)
	end)
	task.wait(3.2)
	untertitel.Text = info.lkw and "Mike (Instructor): Your license now also shows class C. Go and earn some coins!" or "Mike (Instructor): Great job! Here is your driver's license."
	task.wait(3.3)
	fahrt:Disconnect()
	TweenService:Create(schwarz, TweenInfo.new(0.6), { BackgroundTransparency = 0.25 }):Play()
	untertitel.Text = ""
	task.wait(0.6)

	-- the license card flies in
	local karte, skala = fuehrerscheinKarte(cg, info)
	karte.ZIndex = 10
	for _, k in karte:GetDescendants() do
		if k:IsA("GuiObject") then k.ZIndex = 10 end
	end
	skala.Scale = 0.1
	karte.Rotation = -25
	TweenService:Create(skala, TweenInfo.new(0.7, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(karte, TweenInfo.new(0.7, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Rotation = 0 }):Play()
	local glueck = Instance.new("TextLabel")
	glueck.AnchorPoint = Vector2.new(0.5, 1)
	glueck.Position = UDim2.new(0.5, 0, 0.5, -185)
	glueck.Size = UDim2.new(0.9, 0, 0, 50)
	glueck.BackgroundTransparency = 1
	glueck.Font = Enum.Font.GothamBlack
	glueck.TextSize = 40
	glueck.TextColor3 = Color3.fromRGB(255, 215, 80)
	glueck.TextStrokeTransparency = 0.2
	glueck.Text = "CONGRATULATIONS!"
	glueck.ZIndex = 11
	glueck.Parent = cg
	local hinweisText = Instance.new("TextLabel")
	hinweisText.AnchorPoint = Vector2.new(0.5, 0)
	hinweisText.Position = UDim2.new(0.5, 0, 0.5, 182)
	hinweisText.Size = UDim2.new(0.9, 0, 0, 24)
	hinweisText.BackgroundTransparency = 1
	hinweisText.Font = Enum.Font.GothamBold
	hinweisText.TextSize = 18
	hinweisText.TextColor3 = Color3.new(1, 1, 1)
	hinweisText.Text = info.lkw and "Class C added! Find work at the Parcel Express depot." or "Your driver's license has been added to your inventory."
	hinweisText.ZIndex = 11
	hinweisText.Parent = cg
	-- confetti
	local farben = { Color3.fromRGB(255, 90, 90), Color3.fromRGB(90, 200, 255), Color3.fromRGB(255, 220, 80), Color3.fromRGB(120, 230, 120), Color3.fromRGB(220, 130, 255) }
	for i = 1, 60 do
		local c = Instance.new("Frame")
		c.Size = UDim2.fromOffset(math.random(6, 12), math.random(10, 18))
		c.Position = UDim2.new(math.random(), 0, -0.05, 0)
		c.Rotation = math.random(0, 360)
		c.BackgroundColor3 = farben[math.random(#farben)]
		c.BorderSizePixel = 0
		c.ZIndex = 12
		c.Parent = cg
		TweenService:Create(c, TweenInfo.new(math.random(25, 45) / 10, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(c.Position.X.Scale + (math.random() - 0.5) * 0.2, 0, 1.1, 0),
			Rotation = c.Rotation + math.random(-360, 360),
		}):Play()
	end

	local knopf = Instance.new("TextButton")
	knopf.AnchorPoint = Vector2.new(0.5, 0)
	knopf.Position = UDim2.new(0.5, 0, 0.5, 214)
	knopf.Size = UDim2.fromOffset(200, 44)
	knopf.BackgroundColor3 = GRUEN
	knopf.Font = Enum.Font.GothamBlack
	knopf.TextSize = 20
	knopf.TextColor3 = Color3.new(1, 1, 1)
	knopf.Text = "Awesome!"
	knopf.ZIndex = 13
	knopf.Parent = cg
	Instance.new("UICorner", knopf)
	local fertig = false
	knopf.MouseButton1Click:Connect(function() fertig = true end)
	local t0 = os.clock()
	while not fertig and os.clock() - t0 < 20 do task.wait(0.1) end

	kamera.CameraType = Enum.CameraType.Custom
	if hum then kamera.CameraSubject = hum end
	TweenService:Create(schwarz, TweenInfo.new(0.4), { BackgroundTransparency = 0 }):Play()
	task.wait(0.4)
	cg:Destroy()
end

-- ---------------------------------------------------------------
-- Money: "Drive Coins" – small display top right with the coin logo (a golden steering wheel)
-- ---------------------------------------------------------------
do
	local geldGui = Instance.new("ScreenGui")
	geldGui.Name = "Geld"
	geldGui.ResetOnSpawn = false
	geldGui.IgnoreGuiInset = true
	geldGui.DisplayOrder = 8
	geldGui.Parent = spieler.PlayerGui

	local pille = Instance.new("Frame")
	pille.AnchorPoint = Vector2.new(1, 0)
	pille.Position = UDim2.new(1, -16, 0, 12)
	pille.Size = UDim2.fromOffset(0, 38)
	pille.AutomaticSize = Enum.AutomaticSize.X
	pille.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
	pille.BackgroundTransparency = 0.25
	pille.Parent = geldGui
	Instance.new("UICorner", pille).CornerRadius = UDim.new(1, 0)
	local pillenRand = Instance.new("UIStroke")
	pillenRand.Color = Color3.fromRGB(255, 205, 70)
	pillenRand.Transparency = 0.7
	pillenRand.Thickness = 1.5
	pillenRand.Parent = pille
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 5), UDim.new(0, 14)
	pad.Parent = pille
	local reihe = Instance.new("UIListLayout")
	reihe.FillDirection = Enum.FillDirection.Horizontal
	reihe.VerticalAlignment = Enum.VerticalAlignment.Center
	reihe.Padding = UDim.new(0, 8)
	reihe.SortOrder = Enum.SortOrder.LayoutOrder
	reihe.Parent = pille
	local skala = Instance.new("UIScale")
	skala.Parent = pille

	-- the coin: gold with a steering wheel in the middle
	local function rund(eltern, groesse, farbe)
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(0.5, 0.5)
		f.Size = UDim2.fromOffset(groesse, groesse)
		f.BackgroundColor3 = farbe or Color3.new(1, 1, 1)
		f.BorderSizePixel = 0
		f.Parent = eltern
		Instance.new("UICorner", f).CornerRadius = UDim.new(1, 0)
		return f
	end
	local GOLD_DUNKEL = Color3.fromRGB(150, 95, 10)
	local muenze = rund(pille, 30, Color3.new(1, 1, 1))
	muenze.LayoutOrder = 1
	local glanz = Instance.new("UIGradient")
	glanz.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 236, 140)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(250, 196, 50)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(215, 145, 20)),
	})
	glanz.Rotation = 45
	glanz.Parent = muenze
	local muenzRand = Instance.new("UIStroke")
	muenzRand.Color = Color3.fromRGB(185, 120, 15)
	muenzRand.Thickness = 2
	muenzRand.Parent = muenze
	local lenkrad = rund(muenze, 19, Color3.new(1, 1, 1))
	lenkrad.BackgroundTransparency = 1
	local kranz = Instance.new("UIStroke")
	kranz.Color = GOLD_DUNKEL
	kranz.Thickness = 2.6
	kranz.Parent = lenkrad
	rund(muenze, 7, GOLD_DUNKEL)
	local function speiche(x, y, b, h)
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.new(0.5, x, 0.5, y)
		f.Size = UDim2.fromOffset(b, h)
		f.BackgroundColor3 = GOLD_DUNKEL
		f.BorderSizePixel = 0
		f.Parent = muenze
	end
	speiche(-5.5, 0, 6, 3)  -- left spoke
	speiche(5.5, 0, 6, 3)   -- right spoke
	speiche(0, 5, 3, 6)     -- lower spoke

	local zahl = Instance.new("TextLabel")
	zahl.LayoutOrder = 2
	zahl.BackgroundTransparency = 1
	zahl.Size = UDim2.fromOffset(0, 30)
	zahl.AutomaticSize = Enum.AutomaticSize.X
	zahl.Font = Enum.Font.GothamBlack
	zahl.TextSize = 20
	zahl.TextColor3 = Color3.new(1, 1, 1)
	zahl.Text = "0"
	zahl.Parent = pille

	local function format(n)
		local t = tostring(math.floor(n))
		while true do
			local neu, k = t:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
			t = neu
			if k == 0 then break end
		end
		return t
	end

	local angezeigt = spieler:GetAttribute("Geld") or 0
	zahl.Text = format(angezeigt)
	local zaehler
	local function aktualisieren()
		local ziel = spieler:GetAttribute("Geld") or 0
		local start, t0 = angezeigt, os.clock()
		if zaehler then zaehler:Disconnect() end
		zaehler = RunService.RenderStepped:Connect(function()
			local t = math.min((os.clock() - t0) / 0.8, 1)
			angezeigt = start + (ziel - start) * (1 - (1 - t) ^ 3)
			zahl.Text = format(angezeigt + 0.5)
			if t >= 1 and zaehler then
				zaehler:Disconnect()
				zaehler = nil
				angezeigt = ziel
			end
		end)
	end
	spieler:GetAttributeChangedSignal("Geld"):Connect(aktualisieren)

	-- "+150  Package delivered" floats out under the display
	_G.GeldAnzeigen = function(betrag, grund)
		skala.Scale = 1.15
		TweenService:Create(skala, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		local plus = Instance.new("TextLabel")
		plus.AnchorPoint = Vector2.new(1, 0)
		plus.Position = UDim2.new(1, -20, 0, 54)
		plus.Size = UDim2.fromOffset(300, 22)
		plus.BackgroundTransparency = 1
		plus.Font = Enum.Font.GothamBlack
		plus.TextSize = 18
		plus.TextXAlignment = Enum.TextXAlignment.Right
		plus.TextColor3 = betrag >= 0 and Color3.fromRGB(110, 235, 120) or Color3.fromRGB(255, 110, 110)
		plus.TextStrokeTransparency = 0.5
		plus.Text = (betrag >= 0 and "+" or "") .. format(betrag) .. (grund and ("  " .. grund) or "")
		plus.Parent = geldGui
		TweenService:Create(plus, TweenInfo.new(2.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(1, -20, 0, 84), TextTransparency = 1, TextStrokeTransparency = 1,
		}):Play()
		task.delay(2.3, function() plus:Destroy() end)
	end
end

-- ---------------------------------------------------------------
-- Level (XP), clock + weather (top right, under the money), speed camera flash,
-- rain effect and the personal traffic record
-- ---------------------------------------------------------------
do
	local infoGui = Instance.new("ScreenGui")
	infoGui.Name = "Info"
	infoGui.ResetOnSpawn = false
	infoGui.IgnoreGuiInset = true
	infoGui.DisplayOrder = 8
	infoGui.Parent = spieler.PlayerGui
	local function pille(y, breite)
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(1, 0)
		f.Position = UDim2.new(1, -16, 0, y)
		f.Size = UDim2.fromOffset(breite, 26)
		f.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
		f.BackgroundTransparency = 0.25
		f.Parent = infoGui
		Instance.new("UICorner", f).CornerRadius = UDim.new(1, 0)
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.GothamBold
		t.TextSize = 13
		t.TextColor3 = Color3.new(1, 1, 1)
		t.Parent = f
		return f, t
	end
	-- level with a thin progress bar
	local levelPille, levelText = pille(56, 130)
	local balkenHinten = Instance.new("Frame")
	balkenHinten.Position = UDim2.new(0, 12, 1, -5)
	balkenHinten.Size = UDim2.new(1, -24, 0, 3)
	balkenHinten.BackgroundColor3 = Color3.fromRGB(60, 65, 80)
	balkenHinten.BorderSizePixel = 0
	balkenHinten.Parent = levelPille
	local balken = Instance.new("Frame")
	balken.Size = UDim2.fromScale(0, 1)
	balken.BackgroundColor3 = Color3.fromRGB(120, 200, 255)
	balken.BorderSizePixel = 0
	balken.Parent = balkenHinten
	local function levelAktualisieren()
		local xp = spieler:GetAttribute("XP") or 0
		local level = spieler:GetAttribute("Level") or 1
		local von, bis = 150 * (level - 1) ^ 2, 150 * level ^ 2
		levelText.Text = ("⭐ Level %d"):format(level)
		balken.Size = UDim2.fromScale(math.clamp((xp - von) / math.max(1, bis - von), 0, 1), 1)
	end
	levelAktualisieren()
	spieler:GetAttributeChangedSignal("XP"):Connect(levelAktualisieren)

	-- clock and weather
	local _, uhrText = pille(88, 130)
	local SYMBOL = { Clear = "☀", Rain = "🌧", Fog = "🌫" }
	RunService.RenderStepped:Connect(function()
		local zeit = ordner:GetAttribute("Uhrzeit") or 12
		local wetter = ordner:GetAttribute("Wetter") or "Clear"
		local symbol = (wetter == "Clear" and (zeit < 6 or zeit > 20)) and "🌙" or SYMBOL[wetter] or "☀"
		uhrText.Text = ("%s %02d:%02d  %s"):format(symbol, math.floor(zeit), math.floor((zeit % 1) * 60), wetter)
	end)

	-- XP toast
	_G.XpAnzeigen = function(menge, grund, level, aufstieg)
		local t = Instance.new("TextLabel")
		t.AnchorPoint = Vector2.new(1, 0)
		t.Position = UDim2.new(1, -150, 0, 58)
		t.Size = UDim2.fromOffset(260, 22)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.GothamBlack
		t.TextSize = 16
		t.TextXAlignment = Enum.TextXAlignment.Right
		t.TextColor3 = Color3.fromRGB(120, 200, 255)
		t.TextStrokeTransparency = 0.5
		t.Text = ("+%d XP  %s"):format(menge, grund or "")
		t.Parent = infoGui
		TweenService:Create(t, TweenInfo.new(2.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(1, -150, 0, 30), TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		task.delay(2.3, function() t:Destroy() end)
		if aufstieg then
			local gross = Instance.new("TextLabel")
			gross.AnchorPoint = Vector2.new(0.5, 0.5)
			gross.Position = UDim2.fromScale(0.5, 0.32)
			gross.Size = UDim2.fromOffset(500, 60)
			gross.BackgroundTransparency = 1
			gross.Font = Enum.Font.GothamBlack
			gross.TextSize = 46
			gross.TextColor3 = Color3.fromRGB(255, 215, 80)
			gross.TextStrokeTransparency = 0.2
			gross.Text = ("⭐ LEVEL %d! ⭐"):format(level)
			gross.Parent = infoGui
			local sk = Instance.new("UIScale")
			sk.Scale = 0.3
			sk.Parent = gross
			TweenService:Create(sk, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			task.delay(2.5, function()
				TweenService:Create(gross, TweenInfo.new(0.6), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
				task.delay(0.7, function() gross:Destroy() end)
			end)
		end
	end

	-- speed camera: white flash over the screen + message
	local blitzRahmen = Instance.new("Frame")
	blitzRahmen.Size = UDim2.fromScale(1, 1)
	blitzRahmen.BackgroundColor3 = Color3.new(1, 1, 1)
	blitzRahmen.BackgroundTransparency = 1
	blitzRahmen.ZIndex = 50
	blitzRahmen.Parent = infoGui
	_G.Blitz = function(text)
		blitzRahmen.BackgroundTransparency = 0.15
		TweenService:Create(blitzRahmen, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
		if text then warnen(text, Color3.fromRGB(200, 60, 40)) end
	end

	-- rain around the camera (only on this player's screen)
	local regen = Instance.new("Part")
	regen.Name = "Regen"
	regen.Anchored = true
	regen.CanCollide = false
	regen.CanQuery = false
	regen.CanTouch = false
	regen.Transparency = 1
	regen.Size = Vector3.new(90, 1, 90)
	regen.Parent = workspace
	local tropfen = Instance.new("ParticleEmitter")
	tropfen.Color = ColorSequence.new(Color3.fromRGB(190, 205, 225))
	tropfen.LightEmission = 0.2
	tropfen.Transparency = NumberSequence.new(0.35)
	tropfen.Size = NumberSequence.new(0.12)
	tropfen.Squash = NumberSequence.new(-3.5) -- long thin streaks
	tropfen.Orientation = Enum.ParticleOrientation.VelocityParallel
	tropfen.EmissionDirection = Enum.NormalId.Bottom
	tropfen.Speed = NumberRange.new(70, 85)
	tropfen.Lifetime = NumberRange.new(0.6, 0.8)
	tropfen.Rate = 0
	tropfen.Parent = regen
	RunService.RenderStepped:Connect(function()
		local kam = workspace.CurrentCamera
		if not kam or not kam.CFrame then return end
		regen.CFrame = CFrame.new(kam.CFrame.Position + Vector3.new(0, 35, 0))
		tropfen.Rate = (ordner:GetAttribute("Wetter") == "Rain") and 900 or 0
	end)

	-- personal traffic record (license, points, history)
	local akteGui = Instance.new("ScreenGui")
	akteGui.Name = "Verkehrsakte"
	akteGui.ResetOnSpawn = false
	akteGui.Enabled = false
	akteGui.DisplayOrder = 12
	akteGui.Parent = spieler.PlayerGui
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(420, 420)
	panel.BackgroundColor3 = Color3.fromRGB(25, 30, 40)
	panel.Parent = akteGui
	Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 14)
	local kopf = Instance.new("TextLabel")
	kopf.Position = UDim2.fromOffset(18, 12)
	kopf.Size = UDim2.new(1, -70, 0, 30)
	kopf.BackgroundTransparency = 1
	kopf.Font = Enum.Font.GothamBlack
	kopf.TextSize = 22
	kopf.TextColor3 = Color3.new(1, 1, 1)
	kopf.TextXAlignment = Enum.TextXAlignment.Left
	kopf.Text = "TRAFFIC RECORD"
	kopf.Parent = panel
	local zu3 = Instance.new("TextButton")
	zu3.Position = UDim2.new(1, -44, 0, 12)
	zu3.Size = UDim2.fromOffset(30, 30)
	zu3.BackgroundColor3 = ROT
	zu3.Text = "X"
	zu3.Font = Enum.Font.GothamBold
	zu3.TextSize = 16
	zu3.TextColor3 = Color3.new(1, 1, 1)
	zu3.Parent = panel
	Instance.new("UICorner", zu3)
	zu3.MouseButton1Click:Connect(function() akteGui.Enabled = false end)
	local status = Instance.new("TextLabel")
	status.Position = UDim2.fromOffset(18, 48)
	status.Size = UDim2.new(1, -36, 0, 40)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.GothamBold
	status.TextSize = 15
	status.RichText = true
	status.TextWrapped = true
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.TextColor3 = Color3.new(1, 1, 1)
	status.Parent = panel
	-- points bar: 8 boxes
	local punkteReihe = Instance.new("Frame")
	punkteReihe.Position = UDim2.fromOffset(18, 94)
	punkteReihe.Size = UDim2.new(1, -36, 0, 22)
	punkteReihe.BackgroundTransparency = 1
	punkteReihe.Parent = panel
	local pl = Instance.new("UIListLayout")
	pl.FillDirection = Enum.FillDirection.Horizontal
	pl.Padding = UDim.new(0, 5)
	pl.Parent = punkteReihe
	local punktKaesten = {}
	for i = 1, 8 do
		local k = Instance.new("Frame")
		k.Size = UDim2.fromOffset(40, 22)
		k.BackgroundColor3 = Color3.fromRGB(55, 60, 75)
		k.Parent = punkteReihe
		Instance.new("UICorner", k)
		punktKaesten[i] = k
	end
	local punkteText = Instance.new("TextLabel")
	punkteText.Position = UDim2.fromOffset(18, 120)
	punkteText.Size = UDim2.new(1, -36, 0, 18)
	punkteText.BackgroundTransparency = 1
	punkteText.Font = Enum.Font.Gotham
	punkteText.TextSize = 13
	punkteText.TextXAlignment = Enum.TextXAlignment.Left
	punkteText.TextColor3 = Color3.fromRGB(180, 185, 195)
	punkteText.Parent = panel
	local verlauf = Instance.new("ScrollingFrame")
	verlauf.Position = UDim2.fromOffset(18, 146)
	verlauf.Size = UDim2.new(1, -36, 1, -162)
	verlauf.BackgroundColor3 = Color3.fromRGB(18, 22, 30)
	verlauf.BorderSizePixel = 0
	verlauf.ScrollBarThickness = 6
	verlauf.AutomaticCanvasSize = Enum.AutomaticSize.Y
	verlauf.CanvasSize = UDim2.new()
	verlauf.Parent = panel
	Instance.new("UICorner", verlauf)
	local vl = Instance.new("UIListLayout")
	vl.Padding = UDim.new(0, 2)
	vl.Parent = verlauf

	local function akteFuellen()
		local r = frage("akte")
		if r.fehler then hinweis(r.fehler) return false end
		local zustand
		if r.fuehrerschein then
			zustand = "<font color=\"#6fdc80\">VALID</font>  –  classes " .. (r.lkw and "B, C" or "B")
		elseif r.entzogen then
			zustand = "<font color=\"#ff6b6b\">WITHDRAWN</font>  –  " .. (r.nachschulung and "retraining done, book the driving test" or "talk to Anna (retraining course)")
		else
			zustand = "<font color=\"#c0c4cc\">NO LICENSE YET</font>"
		end
		status.Text = ("License: %s\nLevel %d  ·  %d XP"):format(zustand, r.level or 1, r.xp or 0)
		for i, k in punktKaesten do
			k.BackgroundColor3 = i <= r.punkte and (r.punkte >= 6 and Color3.fromRGB(220, 60, 60) or Color3.fromRGB(240, 170, 40)) or Color3.fromRGB(55, 60, 75)
		end
		punkteText.Text = ("Penalty points: %d of %d%s"):format(r.punkte, r.limit, r.naechsterVerfall and ("  ·  next point expires in %d min"):format(math.ceil(r.naechsterVerfall / 60)) or "")
		for _, k in verlauf:GetChildren() do
			if k:IsA("TextLabel") then k:Destroy() end
		end
		if #r.historie == 0 then
			local leer = Instance.new("TextLabel")
			leer.Size = UDim2.new(1, -8, 0, 40)
			leer.BackgroundTransparency = 1
			leer.Font = Enum.Font.Gotham
			leer.TextSize = 14
			leer.TextColor3 = Color3.fromRGB(150, 220, 160)
			leer.Text = "No entries – a clean record! 👍"
			leer.Parent = verlauf
		end
		for i, e in r.historie do
			local z = Instance.new("TextLabel")
			z.LayoutOrder = i
			z.Size = UDim2.new(1, -8, 0, 34)
			z.BackgroundTransparency = 1
			z.Font = Enum.Font.Gotham
			z.TextSize = 13
			z.RichText = true
			z.TextWrapped = true
			z.TextXAlignment = Enum.TextXAlignment.Left
			z.TextColor3 = Color3.fromRGB(225, 228, 235)
			local zusatz = {}
			if (e.geld or 0) > 0 then table.insert(zusatz, "-" .. e.geld .. " coins") end
			if (e.punkte or 0) > 0 then table.insert(zusatz, "+" .. e.punkte .. " pts") end
			if (e.punkte or 0) < 0 then table.insert(zusatz, e.punkte .. " pt") end
			z.Text = ("  <font color=\"#8a93a6\">%s</font>  %s  <b>%s</b>"):format(os.date("%d.%m. %H:%M", e.t or 0), e.text or "", table.concat(zusatz, ", "))
			z.Parent = verlauf
		end
		return true
	end
	local akteKnopf = Instance.new("TextButton")
	akteKnopf.Position = UDim2.new(0, 12, 0, 100)
	akteKnopf.Size = UDim2.fromOffset(110, 32)
	akteKnopf.BackgroundColor3 = Color3.fromRGB(25, 30, 40)
	akteKnopf.BackgroundTransparency = 0.2
	akteKnopf.Font = Enum.Font.GothamBold
	akteKnopf.TextSize = 14
	akteKnopf.TextColor3 = Color3.new(1, 1, 1)
	akteKnopf.Text = "📋 Record"
	akteKnopf.Parent = kameraGui
	Instance.new("UICorner", akteKnopf)
	akteKnopf.MouseButton1Click:Connect(function()
		if akteGui.Enabled then akteGui.Enabled = false return end
		if akteFuellen() then akteGui.Enabled = true end
	end)
end

-- ---------------------------------------------------------------
-- Ben's Garage (repair, insurance, tuning), daily missions and the WANTED badge
-- ---------------------------------------------------------------
do
	local function fenster(name, titelText, breite, hoehe, farbe)
		local g = Instance.new("ScreenGui")
		g.Name = name
		g.ResetOnSpawn = false
		g.DisplayOrder = 12
		g.Parent = spieler.PlayerGui
		local panel = Instance.new("Frame")
		panel.AnchorPoint = Vector2.new(0.5, 0.5)
		panel.Position = UDim2.fromScale(0.5, 0.5)
		panel.Size = UDim2.fromOffset(breite, hoehe)
		panel.BackgroundColor3 = Color3.fromRGB(22, 24, 30)
		panel.Parent = g
		Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 14)
		local kopf = Instance.new("Frame")
		kopf.Size = UDim2.new(1, 0, 0, 48)
		kopf.BackgroundColor3 = farbe
		kopf.Parent = panel
		Instance.new("UICorner", kopf).CornerRadius = UDim.new(0, 14)
		local t = Instance.new("TextLabel")
		t.Position = UDim2.fromOffset(16, 0)
		t.Size = UDim2.new(1, -70, 1, 0)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.GothamBlack
		t.TextSize = 20
		t.TextColor3 = Color3.new(1, 1, 1)
		t.TextXAlignment = Enum.TextXAlignment.Left
		t.Text = titelText
		t.Parent = kopf
		local zu5 = Instance.new("TextButton")
		zu5.Position = UDim2.new(1, -42, 0, 9)
		zu5.Size = UDim2.fromOffset(30, 30)
		zu5.BackgroundColor3 = Color3.fromRGB(40, 20, 20)
		zu5.Text = "X"
		zu5.Font = Enum.Font.GothamBold
		zu5.TextSize = 16
		zu5.TextColor3 = Color3.new(1, 1, 1)
		zu5.Parent = kopf
		Instance.new("UICorner", zu5)
		zu5.MouseButton1Click:Connect(function() g:Destroy() end)
		local liste = Instance.new("ScrollingFrame")
		liste.Position = UDim2.fromOffset(12, 58)
		liste.Size = UDim2.new(1, -24, 1, -70)
		liste.BackgroundTransparency = 1
		liste.BorderSizePixel = 0
		liste.ScrollBarThickness = 6
		liste.AutomaticCanvasSize = Enum.AutomaticSize.Y
		liste.CanvasSize = UDim2.new()
		liste.Parent = panel
		local l = Instance.new("UIListLayout")
		l.Padding = UDim.new(0, 8)
		l.SortOrder = Enum.SortOrder.LayoutOrder
		l.Parent = liste
		return g, liste
	end
	local function knopf(eltern, text, farbe, x, y, b, klick)
		local k = Instance.new("TextButton")
		k.Position = UDim2.fromOffset(x, y)
		k.Size = UDim2.fromOffset(b, 28)
		k.BackgroundColor3 = farbe
		k.Font = Enum.Font.GothamBold
		k.TextSize = 12
		k.TextColor3 = Color3.new(1, 1, 1)
		k.Text = text
		k.Parent = eltern
		Instance.new("UICorner", k)
		if klick then k.MouseButton1Click:Connect(klick) end
		return k
	end

	local werkstattGui
	local NEON = { Color3.fromRGB(40, 120, 255), Color3.fromRGB(255, 40, 60), Color3.fromRGB(40, 255, 120), Color3.fromRGB(190, 60, 255), Color3.fromRGB(255, 120, 200) }
	local FELGEN = { Color3.fromRGB(200, 200, 205), Color3.fromRGB(25, 25, 28), Color3.fromRGB(220, 180, 60), Color3.fromRGB(200, 30, 35), Color3.fromRGB(245, 245, 245) }
	local function werkstattZeigen(info)
		if werkstattGui then werkstattGui:Destroy() end
		local liste
		werkstattGui, liste = fenster("Werkstatt", ("🔧 BEN'S GARAGE   ·   %d coins"):format(info.geld), 520, 470, Color3.fromRGB(230, 120, 30))
		if #info.autos == 0 then
			local leer = Instance.new("TextLabel")
			leer.Size = UDim2.new(1, -10, 0, 60)
			leer.BackgroundTransparency = 1
			leer.Font = Enum.Font.Gotham
			leer.TextSize = 15
			leer.TextWrapped = true
			leer.TextColor3 = Color3.new(1, 1, 1)
			leer.Text = "You don't own a car yet. Buy one at Velocity Motors and come back for repairs and tuning!"
			leer.Parent = liste
			return
		end
		local function machen(art, typ, wert)
			local r = frage("werkstatt", { art = art, typ = typ, wert = wert })
			if r.fehler then hinweis(r.fehler) return end
			warnen(r.text, GRUEN)
			werkstattZeigen(r.info)
		end
		for i, a in info.autos do
			local karte = Instance.new("Frame")
			karte.LayoutOrder = i
			karte.Size = UDim2.new(1, -10, 0, 150)
			karte.BackgroundColor3 = Color3.fromRGB(34, 38, 48)
			karte.Parent = liste
			Instance.new("UICorner", karte)
			local n = Instance.new("TextLabel")
			n.Position = UDim2.fromOffset(12, 6)
			n.Size = UDim2.new(1, -24, 0, 22)
			n.BackgroundTransparency = 1
			n.Font = Enum.Font.GothamBlack
			n.TextSize = 16
			n.TextColor3 = Color3.new(1, 1, 1)
			n.TextXAlignment = Enum.TextXAlignment.Left
			n.RichText = true
			n.Text = ("%s   <font size=\"13\" color=\"#aab2c2\">🔧 %d %%  ·  ⛽ %d %%  ·  %s  ·  Engine %d/3</font>"):format(a.name, a.zustand, a.tank, a.versichert and "insured ✓" or "not insured", a.motor)
			n.Parent = karte
			-- row 1: repair, insurance, engine
			knopf(karte, a.zustand >= 100 and "Condition 100 % ✓" or ("Repair – %d"):format(a.reparatur), a.zustand >= 100 and GRAU or GRUEN, 12, 34, 150, function() machen("reparieren", a.typ) end)
			knopf(karte, a.versichert and "Insured ✓" or ("Insurance – %d"):format(a.versicherung), a.versichert and GRAU or BLAU, 170, 34, 150, function() machen("versichern", a.typ) end)
			knopf(karte, a.motorPreis and ("Engine +1 – %d"):format(a.motorPreis) or "Engine MAX", a.motorPreis and Color3.fromRGB(170, 60, 40) or GRAU, 328, 34, 150, function() machen("motor", a.typ) end)
			-- row 2: spoiler and neon
			knopf(karte, a.spoiler and "Remove spoiler" or ("Spoiler – %d"):format(info.preise.spoiler), Color3.fromRGB(60, 65, 80), 12, 70, 150, function() machen("spoiler", a.typ) end)
			local neonText = Instance.new("TextLabel")
			neonText.Position = UDim2.fromOffset(170, 70)
			neonText.Size = UDim2.fromOffset(70, 28)
			neonText.BackgroundTransparency = 1
			neonText.Font = Enum.Font.GothamBold
			neonText.TextSize = 12
			neonText.TextColor3 = Color3.fromRGB(200, 205, 215)
			neonText.Text = ("Neon %d"):format(a.neon > 0 and 100 or info.preise.neon)
			neonText.Parent = karte
			for j, f in NEON do
				local b = knopf(karte, "", f, 238 + (j - 1) * 34, 70, 28, function() machen("neon", a.typ, j) end)
				if a.neon == j then
					local r = Instance.new("UIStroke")
					r.Color = Color3.new(1, 1, 1)
					r.Thickness = 2
					r.Parent = b
				end
			end
			knopf(karte, "off", GRAU, 410, 70, 36, function() machen("neon", a.typ, 0) end)
			-- row 3: rims
			local felgenText = Instance.new("TextLabel")
			felgenText.Position = UDim2.fromOffset(12, 106)
			felgenText.Size = UDim2.fromOffset(110, 28)
			felgenText.BackgroundTransparency = 1
			felgenText.Font = Enum.Font.GothamBold
			felgenText.TextSize = 12
			felgenText.TextColor3 = Color3.fromRGB(200, 205, 215)
			felgenText.Text = ("Rim color – %d"):format(info.preise.felgen)
			felgenText.Parent = karte
			for j, f in FELGEN do
				local b = knopf(karte, "", f, 130 + (j - 1) * 34, 106, 28, function() machen("felgen", a.typ, j) end)
				if a.felgen == j then
					local r = Instance.new("UIStroke")
					r.Color = Color3.fromRGB(255, 200, 60)
					r.Thickness = 2
					r.Parent = b
				end
			end
		end
	end
	_G.WerkstattOeffnen = function()
		local r = frage("werkstattInfo")
		if r.fehler then hinweis(r.fehler) return end
		werkstattZeigen(r)
	end

	-- daily missions
	local missionGui
	local mKnopf = Instance.new("TextButton")
	mKnopf.Position = UDim2.new(0, 128, 0, 100)
	mKnopf.Size = UDim2.fromOffset(110, 32)
	mKnopf.BackgroundColor3 = Color3.fromRGB(25, 30, 40)
	mKnopf.BackgroundTransparency = 0.2
	mKnopf.Font = Enum.Font.GothamBold
	mKnopf.TextSize = 14
	mKnopf.TextColor3 = Color3.new(1, 1, 1)
	mKnopf.Text = "🎯 Daily"
	mKnopf.Parent = kameraGui
	Instance.new("UICorner", mKnopf)
	mKnopf.MouseButton1Click:Connect(function()
		if missionGui then missionGui:Destroy() missionGui = nil return end
		local r = frage("missionen")
		if r.fehler then hinweis(r.fehler) return end
		local liste
		missionGui, liste = fenster("Missionen", "🎯 DAILY MISSIONS", 420, 330, Color3.fromRGB(40, 120, 200))
		for i, m in r.liste do
			local z = Instance.new("Frame")
			z.LayoutOrder = i
			z.Size = UDim2.new(1, -10, 0, 72)
			z.BackgroundColor3 = m.fertig and Color3.fromRGB(35, 70, 45) or Color3.fromRGB(34, 38, 48)
			z.Parent = liste
			Instance.new("UICorner", z)
			local t = Instance.new("TextLabel")
			t.Position = UDim2.fromOffset(12, 6)
			t.Size = UDim2.new(1, -24, 0, 22)
			t.BackgroundTransparency = 1
			t.Font = Enum.Font.GothamBold
			t.TextSize = 15
			t.TextColor3 = Color3.new(1, 1, 1)
			t.TextXAlignment = Enum.TextXAlignment.Left
			t.Text = (m.fertig and "✅ " or "") .. m.text
			t.Parent = z
			local hinten = Instance.new("Frame")
			hinten.Position = UDim2.fromOffset(12, 34)
			hinten.Size = UDim2.new(1, -24, 0, 10)
			hinten.BackgroundColor3 = Color3.fromRGB(55, 60, 75)
			hinten.Parent = z
			Instance.new("UICorner", hinten)
			local balken = Instance.new("Frame")
			balken.Size = UDim2.fromScale(math.clamp(m.stand / m.ziel, 0, 1), 1)
			balken.BackgroundColor3 = m.fertig and GRUEN or Color3.fromRGB(80, 160, 255)
			balken.Parent = hinten
			Instance.new("UICorner", balken)
			local b = Instance.new("TextLabel")
			b.Position = UDim2.fromOffset(12, 48)
			b.Size = UDim2.new(1, -24, 0, 18)
			b.BackgroundTransparency = 1
			b.Font = Enum.Font.Gotham
			b.TextSize = 12
			b.TextColor3 = Color3.fromRGB(190, 195, 205)
			b.TextXAlignment = Enum.TextXAlignment.Left
			b.Text = ("%s / %s   ·   Reward: %d coins + %d XP"):format(m.stand % 1 == 0 and tostring(m.stand) or ("%.1f"):format(m.stand), tostring(m.ziel), m.geld, m.xp)
			b.Parent = z
		end
	end)

	-- WANTED badge (driving without a valid license)
	local gesuchtGui = Instance.new("ScreenGui")
	gesuchtGui.Name = "Gesucht"
	gesuchtGui.ResetOnSpawn = false
	gesuchtGui.IgnoreGuiInset = true
	gesuchtGui.DisplayOrder = 9
	gesuchtGui.Enabled = false
	gesuchtGui.Parent = spieler.PlayerGui
	local badge = Instance.new("TextLabel")
	badge.AnchorPoint = Vector2.new(1, 0)
	badge.Position = UDim2.new(1, -16, 0, 160)
	badge.Size = UDim2.fromOffset(130, 30)
	badge.Font = Enum.Font.GothamBlack
	badge.TextSize = 15
	badge.TextColor3 = Color3.new(1, 1, 1)
	badge.Text = "🚨 WANTED"
	badge.Parent = gesuchtGui
	Instance.new("UICorner", badge).CornerRadius = UDim.new(1, 0)
	RunService.RenderStepped:Connect(function()
		gesuchtGui.Enabled = spieler:GetAttribute("Gesucht") == true
		if gesuchtGui.Enabled then
			badge.BackgroundColor3 = math.floor(os.clock() * 3) % 2 == 0 and Color3.fromRGB(200, 30, 40) or Color3.fromRGB(30, 60, 190)
		end
	end)
end

-- ---------------------------------------------------------------
-- Police banner (flashes red / blue while the police wants you to stop)
-- ---------------------------------------------------------------
do
	local pg = Instance.new("ScreenGui")
	pg.Name = "Polizei"
	pg.ResetOnSpawn = false
	pg.IgnoreGuiInset = true
	pg.DisplayOrder = 9
	pg.Enabled = false
	pg.Parent = spieler.PlayerGui
	local banner = Instance.new("TextLabel")
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 106)
	banner.Size = UDim2.new(0.8, 0, 0, 40)
	banner.Font = Enum.Font.GothamBlack
	banner.TextSize = 17
	banner.TextWrapped = true
	banner.TextColor3 = Color3.new(1, 1, 1)
	banner.Parent = pg
	Instance.new("UICorner", banner)
	local grenzeB = Instance.new("UISizeConstraint")
	grenzeB.MaxSize = Vector2.new(560, 40)
	grenzeB.Parent = banner
	local verbindung
	_G.PolizeiBanner = function(phase, text)
		if phase == "ende" then
			pg.Enabled = false
			if verbindung then verbindung:Disconnect() verbindung = nil end
			return
		end
		banner.Text = text or "POLICE"
		pg.Enabled = true
		if not verbindung then
			verbindung = RunService.RenderStepped:Connect(function()
				local blau = math.floor(os.clock() * 4) % 2 == 0
				banner.BackgroundColor3 = blau and Color3.fromRGB(30, 70, 200) or Color3.fromRGB(200, 30, 40)
			end)
		end
	end
end

-- ---------------------------------------------------------------
-- NPC traffic: the server sends where the vehicles are, we draw them here
-- ---------------------------------------------------------------
task.spawn(function()
	local event = ordner:WaitForChild("VerkehrDaten", 20)
	if not event then return end
	for _ = 1, 15 do
		local r = frage("verkehr")
		if r.liste then
			Verkehr.anzeigen(r.liste, event)
			return
		end
		task.wait(2)
	end
	warn("[Driving School] NPC traffic not available")
end)

-- ---------------------------------------------------------------
-- Settings (saved on the server) and the start screen
-- ---------------------------------------------------------------
_G.Einstellungen = { minimap = true, mph = false, grosseAnzeige = false, ersteP = false }

local function einstellungenAnwenden()
	local e = _G.Einstellungen
	if _G.MinimapGui then _G.MinimapGui.Enabled = e.minimap end
	if e.grosseAnzeige then
		anweisung.Size = UDim2.new(0.85, 0, 0, 84)
		ag.MaxSize = Vector2.new(620, 84)
		anweisungText.TextSize = 18
	else
		anweisung.Size = UDim2.new(0.7, 0, 0, 58)
		ag.MaxSize = Vector2.new(470, 58)
		anweisungText.TextSize = 14
	end
end

local einstellGui = Instance.new("ScreenGui")
einstellGui.Name = "Einstellungen"
einstellGui.ResetOnSpawn = false
einstellGui.Enabled = false
einstellGui.DisplayOrder = 110
einstellGui.IgnoreGuiInset = true
einstellGui.Parent = spieler.PlayerGui
local einstellRahmen = Instance.new("Frame")
einstellRahmen.AnchorPoint = Vector2.new(0.5, 0.5)
einstellRahmen.Position = UDim2.fromScale(0.5, 0.5)
einstellRahmen.Size = UDim2.fromOffset(380, 330)
einstellRahmen.BackgroundColor3 = Color3.fromRGB(25, 30, 40)
einstellRahmen.Parent = einstellGui
Instance.new("UICorner", einstellRahmen).CornerRadius = UDim.new(0, 14)
local eTitel = Instance.new("TextLabel")
eTitel.Position = UDim2.fromOffset(20, 14)
eTitel.Size = UDim2.new(1, -40, 0, 30)
eTitel.BackgroundTransparency = 1
eTitel.Font = Enum.Font.GothamBlack
eTitel.TextSize = 24
eTitel.TextColor3 = Color3.new(1, 1, 1)
eTitel.TextXAlignment = Enum.TextXAlignment.Left
eTitel.Text = "SETTINGS"
eTitel.Parent = einstellRahmen

local OPTIONEN = {
	{ "minimap", "Minimap", "On", "Off" },
	{ "mph", "Speed unit", "mph", "km/h" },
	{ "grosseAnzeige", "Instruction box", "Large", "Small" },
	{ "ersteP", "Start in first person", "On", "Off" },
}
local optionKnoepfe = {}
for i, o in OPTIONEN do
	local zeile = Instance.new("TextLabel")
	zeile.Position = UDim2.fromOffset(20, 56 + (i - 1) * 50)
	zeile.Size = UDim2.fromOffset(200, 40)
	zeile.BackgroundTransparency = 1
	zeile.Font = Enum.Font.GothamBold
	zeile.TextSize = 16
	zeile.TextColor3 = Color3.fromRGB(220, 225, 235)
	zeile.TextXAlignment = Enum.TextXAlignment.Left
	zeile.Text = o[2]
	zeile.Parent = einstellRahmen
	local k = Instance.new("TextButton")
	k.Position = UDim2.fromOffset(230, 60 + (i - 1) * 50)
	k.Size = UDim2.fromOffset(130, 32)
	k.Font = Enum.Font.GothamBold
	k.TextSize = 15
	k.TextColor3 = Color3.new(1, 1, 1)
	k.Parent = einstellRahmen
	Instance.new("UICorner", k)
	optionKnoepfe[o[1]] = { knopf = k, an = o[3], aus = o[4] }
	k.MouseButton1Click:Connect(function()
		_G.Einstellungen[o[1]] = not _G.Einstellungen[o[1]]
		for schl, ok in optionKnoepfe do
			local wert = _G.Einstellungen[schl]
			ok.knopf.Text = wert and ok.an or ok.aus
			ok.knopf.BackgroundColor3 = wert and GRUEN or GRAU
		end
		einstellungenAnwenden()
		task.spawn(frage, "einstellungen", _G.Einstellungen)
	end)
end
local function knoepfeAktualisieren()
	for schl, ok in optionKnoepfe do
		local wert = _G.Einstellungen[schl]
		ok.knopf.Text = wert and ok.an or ok.aus
		ok.knopf.BackgroundColor3 = wert and GRUEN or GRAU
	end
end
local eZurueck = Instance.new("TextButton")
eZurueck.AnchorPoint = Vector2.new(0.5, 1)
eZurueck.Position = UDim2.new(0.5, 0, 1, -16)
eZurueck.Size = UDim2.fromOffset(200, 40)
eZurueck.BackgroundColor3 = BLAU
eZurueck.Font = Enum.Font.GothamBlack
eZurueck.TextSize = 18
eZurueck.TextColor3 = Color3.new(1, 1, 1)
eZurueck.Text = "Back"
eZurueck.Parent = einstellRahmen
Instance.new("UICorner", eZurueck)
eZurueck.MouseButton1Click:Connect(function()
	einstellGui.Enabled = false
end)

-- small gear button to open the settings at any time
local zahnrad = Instance.new("TextButton")
zahnrad.Position = UDim2.new(0, 170, 0, 64)
zahnrad.Size = UDim2.fromOffset(110, 32)
zahnrad.BackgroundColor3 = Color3.fromRGB(25, 30, 40)
zahnrad.BackgroundTransparency = 0.2
zahnrad.Font = Enum.Font.GothamBold
zahnrad.TextSize = 14
zahnrad.TextColor3 = Color3.new(1, 1, 1)
zahnrad.Text = "⚙ Settings"
zahnrad.Parent = kameraGui
Instance.new("UICorner", zahnrad)
zahnrad.MouseButton1Click:Connect(function()
	knoepfeAktualisieren()
	einstellGui.Enabled = true
end)

-- "My Cars": get one of your bought cars to the nearest parking spot
do
	local autoKnopf = Instance.new("TextButton")
	autoKnopf.Position = UDim2.new(0, 286, 0, 64)
	autoKnopf.Size = UDim2.fromOffset(110, 32)
	autoKnopf.BackgroundColor3 = Color3.fromRGB(25, 30, 40)
	autoKnopf.BackgroundTransparency = 0.2
	autoKnopf.Font = Enum.Font.GothamBold
	autoKnopf.TextSize = 14
	autoKnopf.TextColor3 = Color3.new(1, 1, 1)
	autoKnopf.Text = "🚗 My Cars"
	autoKnopf.Parent = kameraGui
	Instance.new("UICorner", autoKnopf)

	local FARBEN = {
		Color3.fromRGB(200, 25, 30), Color3.fromRGB(25, 70, 170), Color3.fromRGB(240, 240, 240), Color3.fromRGB(20, 20, 24),
		Color3.fromRGB(150, 155, 160), Color3.fromRGB(245, 190, 30), Color3.fromRGB(30, 130, 70), Color3.fromRGB(240, 110, 20),
		-- exclusive colors (VIP / Paint Studio, same order as Shop.FARBEN on the server)
		Color3.fromRGB(212, 168, 60), Color3.fromRGB(236, 232, 222), Color3.fromRGB(45, 25, 80),
		Color3.fromRGB(20, 70, 45), Color3.fromRGB(150, 10, 25), Color3.fromRGB(150, 200, 235),
	}
	local gewaehlt = 1
	local ag2 = Instance.new("ScreenGui")
	ag2.Name = "MeineAutos"
	ag2.ResetOnSpawn = false
	ag2.Enabled = false
	ag2.DisplayOrder = 12
	ag2.Parent = spieler.PlayerGui
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(380, 412)
	panel.BackgroundColor3 = Color3.fromRGB(25, 30, 40)
	panel.Parent = ag2
	Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 14)
	local kopf = Instance.new("TextLabel")
	kopf.Position = UDim2.fromOffset(18, 12)
	kopf.Size = UDim2.new(1, -70, 0, 30)
	kopf.BackgroundTransparency = 1
	kopf.Font = Enum.Font.GothamBlack
	kopf.TextSize = 22
	kopf.TextColor3 = Color3.new(1, 1, 1)
	kopf.TextXAlignment = Enum.TextXAlignment.Left
	kopf.Text = "MY CARS"
	kopf.Parent = panel
	local zu2 = Instance.new("TextButton")
	zu2.Position = UDim2.new(1, -44, 0, 12)
	zu2.Size = UDim2.fromOffset(30, 30)
	zu2.BackgroundColor3 = ROT
	zu2.Text = "X"
	zu2.Font = Enum.Font.GothamBold
	zu2.TextSize = 16
	zu2.TextColor3 = Color3.new(1, 1, 1)
	zu2.Parent = panel
	Instance.new("UICorner", zu2)
	zu2.MouseButton1Click:Connect(function() ag2.Enabled = false end)
	local liste2 = Instance.new("ScrollingFrame")
	liste2.Position = UDim2.fromOffset(18, 52)
	liste2.Size = UDim2.new(1, -36, 0, 200)
	liste2.BackgroundTransparency = 1
	liste2.BorderSizePixel = 0
	liste2.ScrollBarThickness = 6
	liste2.AutomaticCanvasSize = Enum.AutomaticSize.Y
	liste2.CanvasSize = UDim2.new()
	liste2.Parent = panel
	local ll2 = Instance.new("UIListLayout")
	ll2.Padding = UDim.new(0, 6)
	ll2.Parent = liste2
	local farbText = Instance.new("TextLabel")
	farbText.Position = UDim2.fromOffset(18, 258)
	farbText.Size = UDim2.new(1, -36, 0, 18)
	farbText.BackgroundTransparency = 1
	farbText.Font = Enum.Font.GothamBold
	farbText.TextSize = 13
	farbText.TextColor3 = Color3.fromRGB(180, 185, 195)
	farbText.TextXAlignment = Enum.TextXAlignment.Left
	farbText.Text = "Paint color   (✦ = exclusive: VIP / Paint Studio)"
	farbText.Parent = panel
	local swatches = {}
	for i, f in FARBEN do
		local b = Instance.new("TextButton")
		local exklusiv = i > 8
		b.Position = UDim2.fromOffset(18 + ((i - 1) % 8) * 42, exklusiv and 320 or 280)
		b.Size = UDim2.fromOffset(34, 34)
		b.BackgroundColor3 = f
		b.Text = exklusiv and "✦" or ""
		b.TextColor3 = Color3.fromRGB(255, 215, 90)
		b.TextSize = 14
		b.Font = Enum.Font.GothamBlack
		b.Parent = panel
		Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
		local rand2 = Instance.new("UIStroke")
		rand2.Color = Color3.new(1, 1, 1)
		rand2.Thickness = i == gewaehlt and 3 or 0
		rand2.Parent = b
		swatches[i] = rand2
		b.MouseButton1Click:Connect(function()
			gewaehlt = i
			for j, r in swatches do r.Thickness = j == i and 3 or 0 end
		end)
	end
	local wegKnopf = Instance.new("TextButton")
	wegKnopf.Position = UDim2.new(0, 18, 1, -44)
	wegKnopf.Size = UDim2.new(0.5, -22, 0, 32)
	local hilfeKnopf = Instance.new("TextButton")
	hilfeKnopf.Position = UDim2.new(0.5, 4, 1, -44)
	hilfeKnopf.Size = UDim2.new(0.5, -22, 0, 32)
	hilfeKnopf.BackgroundColor3 = Color3.fromRGB(200, 120, 30)
	hilfeKnopf.Font = Enum.Font.GothamBold
	hilfeKnopf.TextSize = 13
	hilfeKnopf.TextColor3 = Color3.new(1, 1, 1)
	hilfeKnopf.Text = "🛠 Roadside help"
	hilfeKnopf.Parent = panel
	Instance.new("UICorner", hilfeKnopf)
	hilfeKnopf.MouseButton1Click:Connect(function()
		local r = frage("pannenhilfe")
		ag2.Enabled = false
		hinweis(r.fehler or r.text)
	end)
	wegKnopf.BackgroundColor3 = GRAU
	wegKnopf.Font = Enum.Font.GothamBold
	wegKnopf.TextSize = 14
	wegKnopf.TextColor3 = Color3.new(1, 1, 1)
	wegKnopf.Text = "Park my car away"
	wegKnopf.Parent = panel
	Instance.new("UICorner", wegKnopf)
	wegKnopf.MouseButton1Click:Connect(function()
		local r = frage("autoWeg")
		ag2.Enabled = false
		hinweis(r.fehler or r.text)
	end)

	local function fuellen()
		for _, k in liste2:GetChildren() do
			if k:IsA("GuiObject") then k:Destroy() end
		end
		local r = frage("meineAutos")
		if r.fehler then hinweis(r.fehler) return false end
		local eigene = 0
		for _, a in r.katalog do
			if a.gehoert then
				eigene += 1
				local zeile = Instance.new("TextButton")
				zeile.Size = UDim2.new(1, 0, 0, 46)
				zeile.BackgroundColor3 = Color3.fromRGB(40, 48, 62)
				zeile.Font = Enum.Font.GothamBold
				zeile.TextSize = 15
				zeile.TextColor3 = Color3.new(1, 1, 1)
				zeile.TextXAlignment = Enum.TextXAlignment.Left
				zeile.Text = ("   %s  ·  %d km/h  ·  %.1f km driven     ▶ Get it"):format(a.name, a.tempo, (r.km and r.km[a.typ]) or 0)
				zeile.Parent = liste2
				Instance.new("UICorner", zeile)
				zeile.MouseButton1Click:Connect(function()
					local h = frage("autoHolen", { typ = a.typ, farbe = gewaehlt })
					ag2.Enabled = false
					hinweis(h.fehler or h.text)
				end)
			end
		end
		if eigene == 0 then
			local leer = Instance.new("TextLabel")
			leer.Size = UDim2.new(1, 0, 0, 90)
			leer.BackgroundTransparency = 1
			leer.Font = Enum.Font.Gotham
			leer.TextSize = 15
			leer.TextWrapped = true
			leer.TextColor3 = Color3.fromRGB(200, 205, 215)
			leer.Text = "You don't own a car yet. Visit Velocity Motors next to the highway access road north of the city!"
			leer.Parent = liste2
		end
		return true
	end
	autoKnopf.MouseButton1Click:Connect(function()
		if ag2.Enabled then ag2.Enabled = false return end
		if fuellen() then ag2.Enabled = true end
	end)
end

-- ---------------------------------------------------------------
-- Rewards (daily streak, playtime gifts, achievements, bonuses) and the Robux shop
-- ---------------------------------------------------------------
do
	local MarketplaceService = game:GetService("MarketplaceService")
	local SocialService = game:GetService("SocialService")
	local GOLD = Color3.fromRGB(245, 185, 40)
	local LILA = Color3.fromRGB(130, 70, 230)
	local KARTE = Color3.fromRGB(34, 38, 48)
	local HELL = Color3.fromRGB(190, 195, 205)

	local function zahlFormat(n)
		local t = tostring(math.floor(n or 0))
		while true do
			local neu, k = t:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
			t = neu
			if k == 0 then break end
		end
		return t
	end
	local function label(eltern, t, groesse, farbe, x, y, w, h, fett, ausrichtung)
		local l = Instance.new("TextLabel")
		l.Position = UDim2.new(x[1], x[2], y[1], y[2])
		l.Size = UDim2.new(w[1], w[2], h[1], h[2])
		l.BackgroundTransparency = 1
		l.Font = fett == 2 and Enum.Font.GothamBlack or (fett and Enum.Font.GothamBold or Enum.Font.Gotham)
		l.TextSize = groesse
		l.TextColor3 = farbe or Color3.new(1, 1, 1)
		l.TextXAlignment = ausrichtung or Enum.TextXAlignment.Left
		l.TextWrapped = true
		l.RichText = true
		l.Text = t
		l.Parent = eltern
		return l
	end
	local function taste(eltern, t, farbe, x, y, w, h, klick)
		local k = Instance.new("TextButton")
		k.Position = UDim2.new(x[1], x[2], y[1], y[2])
		k.Size = UDim2.new(w[1], w[2], h[1], h[2])
		k.BackgroundColor3 = farbe
		k.Font = Enum.Font.GothamBlack
		k.TextSize = 13
		k.TextColor3 = Color3.new(1, 1, 1)
		k.Text = t
		k.AutoButtonColor = true
		k.Parent = eltern
		Instance.new("UICorner", k)
		if klick then k.MouseButton1Click:Connect(klick) end
		return k
	end
	local function karte(eltern, hoehe, farbe, nr)
		local f = Instance.new("Frame")
		f.LayoutOrder = nr or 0
		f.Size = UDim2.new(1, -8, 0, hoehe)
		f.BackgroundColor3 = farbe or KARTE
		f.Parent = eltern
		Instance.new("UICorner", f).CornerRadius = UDim.new(0, 10)
		return f
	end
	local function balken(eltern, anteil, farbe, x, y, w)
		local hinten = Instance.new("Frame")
		hinten.Position = UDim2.new(x[1], x[2], y[1], y[2])
		hinten.Size = UDim2.new(w[1], w[2], 0, 8)
		hinten.BackgroundColor3 = Color3.fromRGB(55, 60, 75)
		hinten.Parent = eltern
		Instance.new("UICorner", hinten)
		local vorn = Instance.new("Frame")
		vorn.Size = UDim2.fromScale(math.clamp(anteil, 0, 1), 1)
		vorn.BackgroundColor3 = farbe
		vorn.Parent = hinten
		Instance.new("UICorner", vorn)
	end
	-- window that fits on phones too
	local function fenster(name, titel, farbe)
		local alt = spieler.PlayerGui:FindFirstChild(name)
		if alt then alt:Destroy() end
		local g = Instance.new("ScreenGui")
		g.Name = name
		g.ResetOnSpawn = false
		g.DisplayOrder = 14
		g.Parent = spieler.PlayerGui
		local panel = Instance.new("Frame")
		panel.AnchorPoint = Vector2.new(0.5, 0.5)
		panel.Position = UDim2.fromScale(0.5, 0.5)
		panel.Size = UDim2.fromScale(0.94, 0.86)
		panel.BackgroundColor3 = Color3.fromRGB(22, 24, 30)
		panel.Parent = g
		Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 14)
		local grenze = Instance.new("UISizeConstraint")
		grenze.MaxSize = Vector2.new(580, 560)
		grenze.Parent = panel
		local kopf = Instance.new("Frame")
		kopf.Size = UDim2.new(1, 0, 0, 50)
		kopf.BackgroundColor3 = farbe
		kopf.Parent = panel
		Instance.new("UICorner", kopf).CornerRadius = UDim.new(0, 14)
		local verlauf = Instance.new("UIGradient")
		verlauf.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170))
		verlauf.Rotation = 90
		verlauf.Parent = kopf
		label(kopf, titel, 20, nil, { 0, 16 }, { 0, 0 }, { 1, -70 }, { 1, 0 }, 2)
		taste(kopf, "X", Color3.fromRGB(40, 20, 20), { 1, -44 }, { 0, 10 }, { 0, 32 }, { 0, 30 }, function() g:Destroy() end)
		local liste = Instance.new("ScrollingFrame")
		liste.Position = UDim2.fromOffset(12, 60)
		liste.Size = UDim2.new(1, -24, 1, -70)
		liste.BackgroundTransparency = 1
		liste.BorderSizePixel = 0
		liste.ScrollBarThickness = 6
		liste.AutomaticCanvasSize = Enum.AutomaticSize.Y
		liste.CanvasSize = UDim2.new()
		liste.Parent = panel
		local l = Instance.new("UIListLayout")
		l.Padding = UDim.new(0, 10)
		l.SortOrder = Enum.SortOrder.LayoutOrder
		l.Parent = liste
		return g, liste
	end
	local function ueberschrift(liste, t, nr)
		local f = Instance.new("Frame")
		f.LayoutOrder = nr
		f.Size = UDim2.new(1, -8, 0, 24)
		f.BackgroundTransparency = 1
		f.Parent = liste
		label(f, t, 15, GOLD, { 0, 4 }, { 0, 0 }, { 1, -8 }, { 1, 0 }, 2)
	end

	-- ---------- rewards window ----------
	local belohnungZeigen
	local function abholen(eingabe)
		local r = frage("belohnungAbholen", eingabe)
		if r.fehler then hinweis(r.fehler) return end
		warnen(r.text, Color3.fromRGB(190, 130, 20))
		belohnungZeigen(r.status)
	end
	belohnungZeigen = function(info)
		local _, liste = fenster("Belohnungen", "🎁 REWARDS", Color3.fromRGB(200, 120, 30))
		local nr = 0
		local function weiter() nr += 1 return nr end
		-- daily streak
		local t = info.taeglich
		ueberschrift(liste, ("🔥 DAILY STREAK  ·  %d day%s in a row"):format(t.bereit and math.max(t.serie - 1, 0) or t.serie, (t.bereit and t.serie - 1 or t.serie) == 1 and "" or "s"), weiter())
		local k = karte(liste, 150, nil, weiter())
		for i, b in t.liste do
			local feld = Instance.new("Frame")
			feld.Position = UDim2.new((i - 1) / 7, 4, 0, 8)
			feld.Size = UDim2.new(1 / 7, -8, 0, 78)
			local heute = i == t.tag
			local erledigt = (t.bereit and i < t.tag) or (not t.bereit and i <= t.tag)
			feld.BackgroundColor3 = heute and (t.bereit and Color3.fromRGB(120, 85, 15) or Color3.fromRGB(35, 80, 50)) or (erledigt and Color3.fromRGB(35, 70, 45) or Color3.fromRGB(45, 50, 62))
			feld.Parent = k
			Instance.new("UICorner", feld)
			if heute and t.bereit then
				local r = Instance.new("UIStroke")
				r.Color = GOLD
				r.Thickness = 2
				r.Parent = feld
			end
			label(feld, "Day " .. i, 11, HELL, { 0, 0 }, { 0, 4 }, { 1, 0 }, { 0, 14 }, true, Enum.TextXAlignment.Center)
			label(feld, (b.gross and "🎁" or (erledigt and "✅" or "🪙")), 20, nil, { 0, 0 }, { 0, 20 }, { 1, 0 }, { 0, 26 }, nil, Enum.TextXAlignment.Center)
			label(feld, zahlFormat(b.geld) .. (b.xp and ("\n+" .. b.xp .. " XP") or ""), 11, Color3.new(1, 1, 1), { 0, 0 }, { 0, 46 }, { 1, 0 }, { 0, 30 }, true, Enum.TextXAlignment.Center)
		end
		if t.bereit then
			taste(k, ("CLAIM DAY %d"):format(t.tag), GRUEN, { 0, 12 }, { 0, 96 }, { 1, -24 }, { 0, 40 }, function() abholen({ art = "taeglich" }) end)
		else
			label(k, "✅ Claimed today – come back tomorrow to keep your streak! Day 7 is a big chest.", 13, HELL, { 0, 12 }, { 0, 96 }, { 1, -24 }, { 0, 40 }, true, Enum.TextXAlignment.Center)
		end
		if t.verloren then
			label(k, "Streak ended – start again today!", 11, Color3.fromRGB(255, 140, 120), { 0, 12 }, { 0, 84 }, { 1, -24 }, { 0, 12 }, true, Enum.TextXAlignment.Center)
		end
		-- playtime gifts
		local sz = info.spielzeit
		ueberschrift(liste, ("⏱ PLAYTIME GIFTS TODAY  ·  %d min played"):format(math.floor(sz.sek / 60)), weiter())
		local k2 = karte(liste, 118, nil, weiter())
		for i, g in sz.geschenke do
			local feld = Instance.new("Frame")
			feld.Position = UDim2.new((i - 1) / #sz.geschenke, 4, 0, 8)
			feld.Size = UDim2.new(1 / #sz.geschenke, -8, 1, -16)
			feld.BackgroundColor3 = g.abgeholt and Color3.fromRGB(35, 70, 45) or Color3.fromRGB(45, 50, 62)
			feld.Parent = k2
			Instance.new("UICorner", feld)
			label(feld, g.min .. " min", 12, HELL, { 0, 0 }, { 0, 4 }, { 1, 0 }, { 0, 16 }, true, Enum.TextXAlignment.Center)
			label(feld, "🪙 " .. zahlFormat(g.geld) .. (g.xp and ("\n+" .. g.xp .. " XP") or ""), 12, nil, { 0, 0 }, { 0, 22 }, { 1, 0 }, { 0, 30 }, true, Enum.TextXAlignment.Center)
			if g.abgeholt then
				label(feld, "✅", 18, nil, { 0, 0 }, { 1, -36 }, { 1, 0 }, { 0, 30 }, nil, Enum.TextXAlignment.Center)
			elseif g.bereit then
				taste(feld, "CLAIM", GRUEN, { 0, 6 }, { 1, -36 }, { 1, -12 }, { 0, 28 }, function() abholen({ art = "spielzeit", nr = g.nr }) end)
			else
				balken(feld, sz.sek / (g.min * 60), Color3.fromRGB(80, 160, 255), { 0, 8 }, { 1, -22 }, { 1, -16 })
			end
		end
		-- bonuses
		ueberschrift(liste, "🚀 YOUR BONUSES", weiter())
		local k3 = karte(liste, 96, nil, weiter())
		local zeilen = {}
		table.insert(zeilen, (spieler:GetAttribute("VIP") and "👑 VIP: 2x coins ✓" or "👑 VIP: <font color=\"#8a90a0\">not active</font>"))
		table.insert(zeilen, (spieler:GetAttribute("FreundeBonus") and "🤝 Friend online: +10 % ✓" or "🤝 Play with a friend: +10 %"))
		table.insert(zeilen, ((spieler:GetAttribute("BoostBis") or 0) > os.time() and ("⚡ 2x boost: %d min left"):format(math.ceil(((spieler:GetAttribute("BoostBis") or 0) - os.time()) / 60)) or "⚡ 2x boost: <font color=\"#8a90a0\">off</font>"))
		label(k3, table.concat(zeilen, "\n"), 13, nil, { 0, 12 }, { 0, 8 }, { 0.6, -12 }, { 1, -16 }, true)
		label(k3, ("Coins  <b>x%.1f</b>\nXP  <b>x%.1f</b>"):format(spieler:GetAttribute("GeldFaktor") or 1, spieler:GetAttribute("XpFaktor") or 1), 16, GOLD, { 0.6, 0 }, { 0, 8 }, { 0.4, -12 }, { 0, 44 }, 2, Enum.TextXAlignment.Right)
		taste(k3, "📨 INVITE FRIENDS", BLAU, { 0.6, 0 }, { 0, 56 }, { 0.4, -12 }, { 0, 32 }, function()
			pcall(function() SocialService:PromptGameInvite(spieler) end)
		end)
		if info.gruppe and not info.gruppe.abgeholt then
			local kg = karte(liste, 50, Color3.fromRGB(40, 45, 70), weiter())
			label(kg, ("👥 Join our Roblox group: <b>%s coins</b> gift"):format(zahlFormat(info.gruppe.geschenk)), 14, nil, { 0, 12 }, { 0, 0 }, { 0.65, 0 }, { 1, 0 }, true)
			taste(kg, info.gruppe.drin and "CLAIM" or "How?", info.gruppe.drin and GRUEN or GRAU, { 0.68, 0 }, { 0, 9 }, { 0.32, -12 }, { 0, 32 }, function()
				if info.gruppe.drin then abholen({ art = "gruppe" }) else hinweis("Search our group on Roblox (see the game page), join it and rejoin the game.") end
			end)
		end
		-- achievements
		ueberschrift(liste, "🏆 ACHIEVEMENTS & LICENSE CLASSES", weiter())
		table.sort(info.erfolge, function(a, b)
			local function ber(e) local s = e.stufen[e.abgeholt + 1] return s and e.wert >= s.ziel and 0 or (s and 1 or 2) end
			local ra, rb = ber(a), ber(b)
			if ra ~= rb then return ra < rb end
			return false
		end)
		for _, e in info.erfolge do
			local naechste = e.stufen[e.abgeholt + 1]
			local fertig = naechste == nil
			local bereit = naechste and e.wert >= naechste.ziel
			local ke = karte(liste, 78, bereit and Color3.fromRGB(70, 55, 20) or (fertig and Color3.fromRGB(35, 60, 45) or KARTE), weiter())
			label(ke, e.icon, 28, nil, { 0, 8 }, { 0, 0 }, { 0, 40 }, { 1, 0 }, nil, Enum.TextXAlignment.Center)
			label(ke, ("<b>%s</b>  <font color=\"#8a90a0\">%s</font>"):format(e.name, #e.stufen > 1 and ("tier %d/%d"):format(e.abgeholt, #e.stufen) or ""), 14, nil, { 0, 54 }, { 0, 6 }, { 1, -190 }, { 0, 18 })
			label(ke, e.text, 12, HELL, { 0, 54 }, { 0, 24 }, { 1, -190 }, { 0, 16 })
			if fertig then
				label(ke, "✅ Completed!", 13, Color3.fromRGB(120, 220, 140), { 0, 54 }, { 0, 46 }, { 1, -190 }, { 0, 18 }, true)
			else
				balken(ke, e.wert / naechste.ziel, bereit and GOLD or Color3.fromRGB(80, 160, 255), { 0, 54 }, { 0, 48 }, { 1, -190 })
				-- show this tier and the next ones (something to look forward to)
				local vorschau = {}
				for i = e.abgeholt + 1, math.min(#e.stufen, e.abgeholt + 3) do
					local s = e.stufen[i]
					table.insert(vorschau, ("%s: %s🪙%s"):format(zahlFormat(s.ziel), zahlFormat(s.geld), s.xp > 0 and (" +" .. s.xp .. "XP") or ""))
				end
				label(ke, ("%s / %s   ·   %s"):format(zahlFormat(math.min(e.wert, naechste.ziel)), zahlFormat(naechste.ziel), table.concat(vorschau, "  →  ")), 11, HELL, { 0, 54 }, { 0, 58 }, { 1, -70 }, { 0, 16 })
				if bereit then
					taste(ke, "CLAIM", GRUEN, { 1, -122 }, { 0, 12 }, { 0, 110 }, { 0, 34 }, function() abholen({ art = "erfolg", id = e.id }) end)
				else
					label(ke, ("🪙 %s"):format(zahlFormat(naechste.geld)), 14, GOLD, { 1, -130 }, { 0, 14 }, { 0, 118 }, { 0, 30 }, 2, Enum.TextXAlignment.Right)
				end
			end
		end
	end
	local function belohnungenOeffnen()
		local r = frage("belohnungen")
		if r.fehler then hinweis(r.fehler) return end
		belohnungZeigen(r)
	end
	_G.BelohnungenOeffnen = belohnungenOeffnen

	-- ---------- shop window ----------
	local shopZeigen
	local function kaufen(art, eintrag)
		if eintrag.bereit then
			if art == "pass" then
				MarketplaceService:PromptGamePassPurchase(spieler, eintrag.id)
			else
				MarketplaceService:PromptProductPurchase(spieler, eintrag.id)
			end
		elseif RunService:IsStudio() then
			-- not set up yet: free test purchase in Studio
			local r = frage("dev", { befehl = "kauf", key = eintrag.key })
			warnen(r.fehler or r.text, GRUEN)
			task.wait(0.3)
			local s = frage("shop")
			if not s.fehler then shopZeigen(s) end
		else
			hinweis("Coming soon!")
		end
	end
	shopZeigen = function(info)
		local _, liste = fenster("Shop", "🛒 SHOP", Color3.fromRGB(110, 60, 200))
		local nr = 0
		local function weiter() nr += 1 return nr end
		local kopf = karte(liste, 56, nil, weiter())
		label(kopf, ("🪙 <b>%s</b> coins"):format(zahlFormat(info.geld)), 18, nil, { 0, 14 }, { 0, 0 }, { 0.5, 0 }, { 1, 0 })
		label(kopf, ("Coins x%.1f  ·  XP x%.1f%s"):format(info.geldFaktor, info.xpFaktor, info.boost > 0 and ("  ·  ⚡ %d min"):format(math.ceil(info.boost / 60)) or ""), 13, GOLD, { 0.45, 0 }, { 0, 0 }, { 0.55, -14 }, { 1, 0 }, true, Enum.TextXAlignment.Right)
		local studio = RunService:IsStudio()
		local function preisText(e)
			if e.hat then return "OWNED ✓" end
			if e.bereit then return "R$ " .. e.preis end
			return studio and ("TEST · R$ " .. e.preis) or "SOON"
		end
		-- starter pack first (best offer for new players)
		for _, pr in info.produkte do
			if pr.einmal then
				local k = karte(liste, 96, LILA, weiter())
				local v = Instance.new("UIGradient")
				v.Color = ColorSequence.new(Color3.fromRGB(150, 90, 255), Color3.fromRGB(240, 120, 60))
				v.Parent = k
				label(k, "⭐ " .. pr.name:upper() .. "  <font size=\"12\">ONLY ONCE</font>", 18, nil, { 0, 14 }, { 0, 8 }, { 1, -170 }, { 0, 24 }, 2)
				label(k, pr.text, 13, nil, { 0, 14 }, { 0, 36 }, { 1, -170 }, { 0, 50 }, true)
				taste(k, preisText(pr), GRUEN, { 1, -150 }, { 0.5, -22 }, { 0, 136 }, { 0, 44 }, function() kaufen("produkt", pr) end)
			end
		end
		ueberschrift(liste, "🎟 GAME PASSES – keep forever", weiter())
		for _, pass in info.passes do
			local k = karte(liste, 84, pass.hat and Color3.fromRGB(35, 60, 45) or KARTE, weiter())
			label(k, pass.icon, 34, nil, { 0, 6 }, { 0, 0 }, { 0, 56 }, { 1, 0 }, nil, Enum.TextXAlignment.Center)
			label(k, pass.name, 16, nil, { 0, 66 }, { 0, 8 }, { 1, -220 }, { 0, 20 }, 2)
			label(k, pass.text, 12, HELL, { 0, 66 }, { 0, 30 }, { 1, -220 }, { 0, 48 })
			local b = taste(k, preisText(pass), pass.hat and GRAU or GRUEN, { 1, -146 }, { 0.5, -20 }, { 0, 134 }, { 0, 40 }, function()
				if not pass.hat then kaufen("pass", pass) end
			end)
			b.AutoButtonColor = not pass.hat
		end
		ueberschrift(liste, "🪙 COINS & BOOSTS", weiter())
		for _, pr in info.produkte do
			if not pr.einmal then
				local k = karte(liste, 56, nil, weiter())
				label(k, (pr.geld and "🪙 " or "⚡ ") .. pr.name .. (pr.tag and ("   <font color=\"#ffcf4a\" size=\"12\">" .. pr.tag .. "</font>") or ""), 16, nil, { 0, 14 }, { 0, 0 }, { 1, -170 }, { 1, 0 }, true)
				taste(k, preisText(pr), GRUEN, { 1, -146 }, { 0.5, -18 }, { 0, 134 }, { 0, 36 }, function() kaufen("produkt", pr) end)
			end
		end
		local fuss = karte(liste, 40, Color3.fromRGB(28, 30, 38), weiter())
		label(fuss, "Everything in the game can also be earned by playing. Purchases support the developer ❤", 11, HELL, { 0, 12 }, { 0, 0 }, { 1, -24 }, { 1, 0 }, nil, Enum.TextXAlignment.Center)
	end
	local function shopOeffnen()
		local r = frage("shop")
		if r.fehler then hinweis(r.fehler) return end
		shopZeigen(r)
	end
	_G.ShopOeffnen = shopOeffnen
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(_, _, gekauft)
		if gekauft then task.wait(1.5) if spieler.PlayerGui:FindFirstChild("Shop") then shopOeffnen() end end
	end)
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(_, _, gekauft)
		if gekauft then task.wait(2) if spieler.PlayerGui:FindFirstChild("Shop") then shopOeffnen() end end
	end)

	-- ---------- buttons top left ----------
	local function hudKnopf(text, x, farbe)
		local k = Instance.new("TextButton")
		k.Position = UDim2.new(0, x, 0, 100)
		k.Size = UDim2.fromOffset(110, 32)
		k.BackgroundColor3 = farbe or Color3.fromRGB(25, 30, 40)
		k.BackgroundTransparency = 0.15
		k.Font = Enum.Font.GothamBold
		k.TextSize = 14
		k.TextColor3 = Color3.new(1, 1, 1)
		k.Text = text
		k.Parent = kameraGui
		Instance.new("UICorner", k)
		return k
	end
	local bKnopf = hudKnopf("🎁 Rewards", 244)
	local punkt = Instance.new("TextLabel")
	punkt.AnchorPoint = Vector2.new(0.5, 0.5)
	punkt.Position = UDim2.new(1, -2, 0, 2)
	punkt.Size = UDim2.fromOffset(20, 20)
	punkt.BackgroundColor3 = Color3.fromRGB(230, 40, 50)
	punkt.Font = Enum.Font.GothamBlack
	punkt.TextSize = 12
	punkt.TextColor3 = Color3.new(1, 1, 1)
	punkt.Visible = false
	punkt.Parent = bKnopf
	Instance.new("UICorner", punkt).CornerRadius = UDim.new(1, 0)
	local function punktNeu()
		local n = spieler:GetAttribute("BelohnungenOffen") or 0
		punkt.Visible = n > 0
		punkt.Text = tostring(n)
	end
	spieler:GetAttributeChangedSignal("BelohnungenOffen"):Connect(punktNeu)
	punktNeu()
	bKnopf.MouseButton1Click:Connect(function()
		local g = spieler.PlayerGui:FindFirstChild("Belohnungen")
		if g then g:Destroy() return end
		belohnungenOeffnen()
	end)
	local sKnopf = hudKnopf("🛒 Shop", 360, Color3.fromRGB(110, 60, 200))
	sKnopf.MouseButton1Click:Connect(function()
		local g = spieler.PlayerGui:FindFirstChild("Shop")
		if g then g:Destroy() return end
		shopOeffnen()
	end)

	-- coin multiplier next to the money display (e.g. "x2.1  ⚡12:30")
	task.spawn(function()
		local geldGui = spieler.PlayerGui:WaitForChild("Geld", 10)
		local pille = geldGui and geldGui:FindFirstChildOfClass("Frame")
		if not pille then return end
		local faktor = Instance.new("TextButton")
		faktor.LayoutOrder = 3
		faktor.BackgroundColor3 = Color3.fromRGB(110, 60, 200)
		faktor.Size = UDim2.fromOffset(0, 26)
		faktor.AutomaticSize = Enum.AutomaticSize.X
		faktor.Font = Enum.Font.GothamBlack
		faktor.TextSize = 13
		faktor.TextColor3 = Color3.new(1, 1, 1)
		faktor.Text = "+"
		faktor.Parent = pille
		Instance.new("UICorner", faktor).CornerRadius = UDim.new(1, 0)
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 9), UDim.new(0, 9)
		pad.Parent = faktor
		faktor.MouseButton1Click:Connect(shopOeffnen)
		while true do
			local f = spieler:GetAttribute("GeldFaktor") or 1
			local rest = (spieler:GetAttribute("BoostBis") or 0) - os.time()
			local t = f > 1.01 and ("x%.1f"):format(f) or "+"
			if rest > 0 then t ..= ("  ⚡%d:%02d"):format(rest // 60, rest % 60) end
			faktor.Text = t
			faktor.BackgroundColor3 = f > 1.01 and Color3.fromRGB(190, 130, 20) or Color3.fromRGB(110, 60, 200)
			task.wait(1)
		end
	end)

	-- VIP tag in the chat
	pcall(function()
		local TextChatService = game:GetService("TextChatService")
		TextChatService.OnIncomingMessage = function(nachricht)
			local quelle = nachricht.TextSource
			local p = quelle and Players:GetPlayerByUserId(quelle.UserId)
			if p and p:GetAttribute("VIP") then
				local props = Instance.new("TextChatMessageProperties")
				props.PrefixText = "<font color=\"#FFD24A\">[👑 VIP]</font> " .. nachricht.PrefixText
				return props
			end
		end
	end)

	-- messages from the server
	fahrEvent.OnClientEvent:Connect(function(info)
		if info.typ == "belohnung" then
			warnen(info.text, Color3.fromRGB(190, 130, 20))
		elseif info.typ == "taeglich" then
			-- daily reward waiting: open the rewards window once the player is in the game
			task.spawn(function()
				while not _G.ImSpiel do task.wait(0.5) end
				task.wait(1.5)
				belohnungenOeffnen()
			end)
		end
	end)
end

-- Start screen
do
	print("[Driving School] start screen v{VERSION} loading")
	local menue = Instance.new("ScreenGui")
	menue.Name = "Startbildschirm"
	menue.IgnoreGuiInset = true
	menue.ResetOnSpawn = false
	menue.DisplayOrder = 100
	menue.Parent = spieler.PlayerGui

	local seite = Instance.new("Frame")
	seite.Size = UDim2.fromScale(0.55, 1)
	seite.BackgroundColor3 = Color3.new(0, 0, 0)
	seite.BorderSizePixel = 0
	seite.Parent = menue
	local sv = Instance.new("UIGradient")
	sv.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) })
	sv.Parent = seite

	local function label(t, y, groesse, schrift, farbe)
		local l = Instance.new("TextLabel")
		l.Position = UDim2.new(0.07, 0, y, 0)
		l.Size = UDim2.new(0.6, 0, 0, groesse + 8)
		l.BackgroundTransparency = 1
		l.Font = schrift
		l.TextSize = groesse
		l.TextColor3 = farbe
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.Text = t
		l.Parent = menue
		return l
	end
	label("DRIVING SCHOOL", 0.24, 54, Enum.Font.GothamBlack, Color3.new(1, 1, 1))
	label("Get your license. Hit the road.", 0.33, 22, Enum.Font.GothamMedium, Color3.fromRGB(255, 215, 80))

	local function grosserKnopf(t, y, farbe)
		local k = Instance.new("TextButton")
		k.Position = UDim2.new(0.07, 0, y, 0)
		k.Size = UDim2.fromOffset(260, 56)
		k.BackgroundColor3 = farbe
		k.Font = Enum.Font.GothamBlack
		k.TextSize = 24
		k.TextColor3 = Color3.new(1, 1, 1)
		k.Text = t
		k.ZIndex = 5
		k.Parent = menue
		Instance.new("UICorner", k).CornerRadius = UDim.new(0, 12)
		return k
	end
	local spielen = grosserKnopf("PLAY", 0.5, GRUEN)
	local einst = grosserKnopf("SETTINGS", 0.6, Color3.fromRGB(60, 70, 90))

	-- these are filled in further down (nothing below may block the buttons)
	local kamera = workspace.CurrentCamera
	local WOLKEN_HOEHE = 420
	local wolken, wolkenTeile, flug, steuerung = nil, {}, nil, nil
	local gestartet = false

	local andere = { "Minimap", "CameraToggle", "TestMenu", "Geld", "Admin", "Info" }
	local function andereZeigen(an)
		for _, n in andere do
			local g = spieler.PlayerGui:FindFirstChild(n)
			if g then g.Enabled = an end
		end
		if an then pcall(einstellungenAnwenden) end
	end

	einst.Activated:Connect(function()
		knoepfeAktualisieren()
		einstellGui.Enabled = true
	end)

	spielen.Activated:Connect(function()
		if gestartet then return end
		gestartet = true
		_G.ImSpiel = true
		print("[Driving School] PLAY pressed")
		menue:Destroy()                    -- the menu disappears right away
		einstellGui.Enabled = false
		if flug then flug:Disconnect() end

		-- fly down through the clouds to the character
		local ok, fehler = pcall(function()
			local char = spieler.Character or spieler.CharacterAdded:Wait()
			local wurzel = char:WaitForChild("HumanoidRootPart", 10)
			if not wurzel then return end
			local start = kamera.CFrame
			local dauer = 3.2
			local t0 = os.clock()
			while true do
				local t = math.min((os.clock() - t0) / dauer, 1)
				local weich = 1 - (1 - t) ^ 3
				local ziel = CFrame.lookAt((wurzel.CFrame * CFrame.new(0, 5, 14)).Position, wurzel.Position + Vector3.new(0, 2, 0))
				kamera.CameraType = Enum.CameraType.Scriptable
				kamera.CFrame = start:Lerp(ziel, weich)
				local nebel = math.clamp((kamera.CFrame.Position.Y - 80) / (WOLKEN_HOEHE - 80), 0, 1)
				for _, w in wolkenTeile do
					w.Transparency = 1 - 0.92 * nebel
				end
				if t >= 1 then break end
				RunService.RenderStepped:Wait()
			end
		end)
		if not ok then warn("[Driving School] camera flight failed: " .. tostring(fehler)) end
		if wolken then wolken:Destroy() end

		pcall(function()
			local char = spieler.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			kamera.CameraType = Enum.CameraType.Custom
			if hum then kamera.CameraSubject = hum end
		end)
		if steuerung then pcall(function() steuerung:Enable() end) end
		andereZeigen(true)
		if _G.Einstellungen.ersteP then pcall(perspektive, true) end
	end)

	-- hide the other buttons while the menu is open
	task.defer(andereZeigen, false)

	-- block walking while in the menu (never wait forever for the PlayerModule)
	task.spawn(function()
		local skripte = spieler:WaitForChild("PlayerScripts", 5)
		local modul = skripte and skripte:WaitForChild("PlayerModule", 5)
		if modul and not gestartet then
			pcall(function()
				steuerung = require(modul):GetControls()
				steuerung:Disable()
			end)
		end
	end)

	-- above the clouds: a sea of cloud puffs (only on this player's screen)
	pcall(function()
		wolken = Instance.new("Folder")
		wolken.Name = "Menuewolken"
		local zufall = Random.new(7)
		for _ = 1, 140 do
			local mittelpunkt = Vector3.new(zufall:NextNumber(-900, 900), WOLKEN_HOEHE + zufall:NextNumber(-12, 12), zufall:NextNumber(-900, 900))
			for _ = 1, zufall:NextInteger(3, 6) do
				local r = zufall:NextNumber(45, 110)
				local puff = Instance.new("Part")
				puff.Shape = Enum.PartType.Ball
				puff.Size = Vector3.new(r, r, r)
				puff.Position = mittelpunkt + Vector3.new(zufall:NextNumber(-60, 60), zufall:NextNumber(-10, 12), zufall:NextNumber(-60, 60))
				puff.Anchored = true
				puff.CanCollide = false
				puff.CanQuery = false
				puff.CanTouch = false
				puff.CastShadow = false
				puff.Material = Enum.Material.SmoothPlastic
				puff.Color = Color3.fromRGB(255, 255, 255)
				puff.Transparency = 0.08
				puff.Parent = wolken
				table.insert(wolkenTeile, puff)
			end
		end
		wolken.Parent = workspace
	end)
	if gestartet and wolken then wolken:Destroy() end

	local himmelStart = os.clock()
	if not gestartet then
		flug = RunService.RenderStepped:Connect(function()
			local t = os.clock() - himmelStart
			local auge = Vector3.new(-300 + t * 6, WOLKEN_HOEHE + 75, 200)
			kamera.CameraType = Enum.CameraType.Scriptable
			kamera.CFrame = CFrame.lookAt(auge, auge + Vector3.new(1, -0.18, -0.35))
		end)
	end

	-- load the saved settings
	task.spawn(function()
		local r = frage("status")
		if r.status and type(r.status.einstellungen) == "table" then
			for k, v in r.status.einstellungen do
				if _G.Einstellungen[k] ~= nil and type(v) == "boolean" then _G.Einstellungen[k] = v end
			end
		end
		knoepfeAktualisieren()
	end)
	print("[Driving School] start screen ready")
end
