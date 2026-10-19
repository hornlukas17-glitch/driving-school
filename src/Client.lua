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
local Motorsound = require(ordner:WaitForChild("Motorsound"))
local Hupen = require(ordner:WaitForChild("Hupen"))
Motorsound.starten() -- engine sounds for every car (pure sound, the driving is not touched)

local BLAU = Color3.fromRGB(30, 90, 180)
local GRUEN = Color3.fromRGB(40, 150, 70)
local GRAU = Color3.fromRGB(70, 75, 85)
local ROT = Color3.fromRGB(200, 50, 50)

-- Theory lesson slides
local FOLIEN = {
	{ "Welcome to Crazy Driving School!", "Here is how you get your license:\n\n1. Theory lesson (these slides)\n2. Theory test at an exam desk: 20 questions, at least 85 % correct (17 of 20)\n3. Five driving lessons with your instructor\n4. Practical driving test\n\nOnly with a license can you buy and drive your own cars." },
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
text.TextScaled = true -- long checklists shrink to fit, never bigger than 18
local textGrenze = Instance.new("UITextSizeConstraint")
textGrenze.MaxTextSize = 18
textGrenze.MinTextSize = 11
textGrenze.Parent = text
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

-- km/h -> mph in every text the player reads (setting "Speed unit"); speed limits are rounded to nice mph values
local GRENZEN = { [10] = true, [20] = true, [30] = true, [40] = true, [50] = true, [60] = true, [70] = true, [80] = true, [100] = true, [120] = true, [130] = true }
local function inMph(kmh, istGrenze)
	local m = kmh * 0.621
	if istGrenze then return math.floor(m / 5 + 0.5) * 5 end
	return math.floor(m + 0.5)
end
local function einh(t)
	if type(t) ~= "string" or not (_G.Einstellungen and _G.Einstellungen.mph) then return t end
	t = t:gsub("(%d+) km/h", function(n)
		n = tonumber(n)
		return inMph(n, GRENZEN[n]) .. " mph"
	end)
	t = t:gsub("in a (%d+) zone", function(n) return "in a " .. inMph(tonumber(n), true) .. " mph zone" end)
	return t
end
_G.EinheitText = einh

local function zeige(t, inhalt, buttons, neuerModus)
	titel.Text = t
	inhalt = einh(inhalt)
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

-- v51: right after joining the server is still loading the save game (in the live game that takes a moment)
-- and answers "still loading" – startup requests wait for it instead of giving up (max. ~60 s)
local function frageGeladen(was, eingabe)
	local r = frage(was, eingabe)
	for _ = 1, 30 do
		if not (r.fehler and (r.fehler:find("loading", 1, true) or r.fehler:find("reach the server", 1, true))) then break end
		task.wait(2)
		r = frage(was, eingabe)
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
		zeile(s.fahrstunden >= r.anzahlLektionen, ("Driving lessons (%d/%d)"):format(s.fahrstunden, r.anzahlLektionen)),
		zeile(s.fuehrerschein, "Driving test"),
		zeile(s.theorie, "Theory test (optional, bonus XP)"),
		zeile(s.lkwFuehrerschein, "Truck license (optional)"),
	}, "\n")
end

-- ---------------------------------------------------------------
-- Receptionist dialog
-- ---------------------------------------------------------------
local dialog, unterricht, pruefungsplatz, pkwMenue, lkwMenue

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
					{ "Retraining course", "• Red light = stop. Always.\n• Speed cameras are everywhere – watch the limit.\n• Points expire over time if you drive safely.\n\nNow book your new driving test with Anna!" },
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
	else
		-- first choose the license class, then Anna lists every step
		zeige(name, "Hi, welcome to the driving school! 😊\nWhich license are you interested in?", {
			{ text = "🚗  Car license (B)", farbe = GRUEN, klick = function() pkwMenue(r) end },
			{ text = "🚛  Truck license (C)", farbe = BLAU, klick = function() lkwMenue(r) end },
			tschuess,
		}, "dialog")
	end
end

-- numbered checklist: { done, text } -> "✅ 1. ..."
local function schritte(liste)
	local zeilen = {}
	local naechsterGefunden = false
	for i, sch in liste do
		local marke
		if sch[1] then
			marke = "✅"
		elseif not naechsterGefunden then
			marke = "👉"
			naechsterGefunden = true
		else
			marke = "⬜"
		end
		table.insert(zeilen, ("%s <b>%d.</b> %s"):format(marke, i, sch[2]))
	end
	return table.concat(zeilen, "\n")
end

function pkwMenue(r)
	local s = r.status
	local name = "Anna – Car license (B)"
	local zurueck = { text = "Back", farbe = GRAU, klick = dialog }
	local n = r.anzahlLektionen
	-- stars collected in the lessons (max. 3 per lesson)
	local summe = 0
	for i = 1, n do summe += (s.sterne and s.sterne[tostring(i)]) or 0 end
	local liste = "Here is everything you need to do:\n\n" .. schritte({
		{ s.fahrstunden >= n, ("Driving lessons (%d/%d)  ⭐ %d/%d"):format(math.min(s.fahrstunden, n), n, summe, n * 3) },
		{ s.fuehrerschein, "Driving test (max 3 mistakes)" },
	}) .. (s.theorie and "" or "\n<font size=\"15\" color=\"#9aa4b5\">Optional: theory test in the classroom for bonus XP.</font>") .. "\n\n"
	local knoepfe = {}
	local function lektionKnopf()
		table.insert(knoepfe, { text = ("Start lesson %d"):format(s.fahrstunden + 1), farbe = GRUEN, klick = function()
			local a = frage("fahrstundeStarten")
			if a.fehler then
				hinweis(a.fehler)
			else
				zeige(name, a.text, { { text = "Okay!", farbe = GRUEN, klick = schliessen } }, "dialog")
			end
		end })
	end
	local text
	if s.fahrstunden < n then
		text = r.naechste and ("Next lesson: <b>%s</b>\nYour instructor is waiting in the car on the parking lot. Who will it be this time?"):format(r.naechste) or ""
		lektionKnopf()
	elseif not s.fuehrerschein then
		text = "Your examiner Mr. Becker rides in the back, a (crazy) instructor sits next to you. The route is random – hitting a pedestrian counts as 3 mistakes!"
		table.insert(knoepfe, { text = "Start the driving test", farbe = GRUEN, klick = function()
			local a = frage("pruefungStarten")
			if a.fehler then
				hinweis(a.fehler)
			else
				zeige(name, a.text, { { text = "Let's go!", farbe = GRUEN, klick = schliessen } }, "dialog")
			end
		end })
	else
		text = "You have your car license! 🎉 Buy a car at the dealership or earn coins with taxi and pizza jobs."
	end
	-- replay finished lessons for more stars
	if s.fahrstunden > 0 and summe < s.fahrstunden * 3 then
		table.insert(knoepfe, { text = "⭐ Improve a lesson", farbe = BLAU, klick = function()
			local auswahl = {}
			for i = 1, math.min(s.fahrstunden, n) do
				local st = (s.sterne and s.sterne[tostring(i)]) or 0
				if st < 3 then
					table.insert(auswahl, { text = ("Lesson %d   %s%s"):format(i, string.rep("★", st), string.rep("☆", 3 - st)), farbe = GRAU, klick = function()
						local a = frage("fahrstundeWiederholen", i)
						if a.fehler then hinweis(a.fehler) else zeige(name, a.text, { { text = "Okay!", farbe = GRUEN, klick = schliessen } }, "dialog") end
					end })
				end
				if #auswahl >= 2 then break end -- the window has room for 3 buttons
			end
			table.insert(auswahl, { text = "Back", farbe = GRAU, klick = function() pkwMenue(r) end })
			zeige(name, "Repeat a lesson with 0 mistakes for 3 stars. Every extra star gives bonus coins!", auswahl, "dialog")
		end })
	end
	table.insert(knoepfe, zurueck)
	zeige(name, liste .. text, knoepfe, "dialog")
end

function lkwMenue(r)
	local s = r.status
	local name = "Anna – Truck license (C)"
	local zurueck = { text = "Back", farbe = GRAU, klick = dialog }
	local fahrten = s.lkwFahrten or 0
	local liste = "Here is everything you need to do:\n\n" .. schritte({
		{ s.fuehrerschein, "Car license (B) first" },
		{ s.lkwFuehrerschein, "Truck test at the <b>Parcel Express</b> depot (max 3 mistakes)" },
		{ fahrten >= 15, ("Deliver packages for Tom – class CE / Mega Truck after 15 jobs (%d/15)"):format(math.min(fahrten, 15)) },
	}) .. "\n\n"
	if not s.fuehrerschein then
		zeige(name, liste .. "You need your <b>car license</b> before you can drive trucks.", {
			{ text = "Show the car license steps", farbe = GRUEN, klick = function() pkwMenue(r) end },
			zurueck,
		}, "dialog")
	elseif not s.lkwFuehrerschein then
		zeige(name, liste .. "The truck waits at the Parcel Express depot, south of the neighbourhood.", {
			{ text = "Start the truck test", farbe = GRUEN, klick = function()
				local a = frage("lkwPruefungStarten")
				if a.fehler then
					hinweis(a.fehler)
				else
					zeige(name, a.text, { { text = "Let's go!", farbe = GRUEN, klick = schliessen } }, "dialog")
				end
			end },
			zurueck,
		}, "dialog")
	else
		zeige(name, liste .. "You have the truck license! 🎉 Talk to <b>Tom</b>, the dispatcher at the depot, to earn coins with deliveries.", { zurueck, { text = "Thanks!", farbe = GRUEN, klick = schliessen } }, "dialog")
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
			zeige("Passed! 🎉", ("You answered <b>%d of %d</b> questions correctly (%d %%).\n\n+80 XP bonus! Talk to Anna at the reception for your next driving lesson."):format(e.punkte, e.gesamt, prozent), {
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
		hinweis("You have already passed the theory test. Talk to Anna at the reception for your next driving lesson.")
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
		d2.Text = einh(("%d km/h  ·  %s"):format(a.tempo, a.beschreibung or ""))
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
anweisung.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
anweisung.BackgroundTransparency = 0.08
anweisung.Parent = hud
do
	-- yellow accent on the left + thin light border (same look as the speedometer)
	local akzent = Instance.new("Frame")
	akzent.Size = UDim2.new(0, 5, 1, -12)
	akzent.Position = UDim2.fromOffset(0, 6)
	akzent.BackgroundColor3 = Color3.fromRGB(255, 205, 40)
	akzent.BorderSizePixel = 0
	akzent.Parent = anweisung
	Instance.new("UICorner", akzent).CornerRadius = UDim.new(1, 0)
	local r = Instance.new("UIStroke")
	r.Color = Color3.new(1, 1, 1)
	r.Transparency = 0.82
	r.Thickness = 1.5
	r.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	r.Parent = anweisung
end
local ag = Instance.new("UISizeConstraint")
ag.MaxSize = Vector2.new(470, 58)
ag.Parent = anweisung
Instance.new("UICorner", anweisung).CornerRadius = UDim.new(0, 10)

local lektionTitel = Instance.new("TextLabel")
lektionTitel.BackgroundTransparency = 1
lektionTitel.Position = UDim2.fromOffset(14, 4)
lektionTitel.Size = UDim2.new(1, -20, 0, 14)
lektionTitel.Font = Enum.Font.GothamBold
lektionTitel.TextSize = 11
lektionTitel.TextColor3 = Color3.fromRGB(255, 205, 40)
lektionTitel.TextXAlignment = Enum.TextXAlignment.Left
lektionTitel.Parent = anweisung

local anweisungText = Instance.new("TextLabel")
anweisungText.BackgroundTransparency = 1
anweisungText.Position = UDim2.fromOffset(14, 19)
anweisungText.Size = UDim2.new(1, -24, 1, -22)
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

-- ---------------------------------------------------------------
-- Cockpit (bottom right): round speedometer with a ring of lights, speed limit sign,
-- status chip below, indicator / light / handbrake buttons above. Scales down on small screens.
-- ---------------------------------------------------------------
local DUNKEL_HUD = Color3.fromRGB(20, 24, 34)
local function rand(o, transparenz, dicke)
	local r = Instance.new("UIStroke")
	r.Color = Color3.new(1, 1, 1)
	r.Transparency = transparenz or 0.82
	r.Thickness = dicke or 1.5
	r.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	r.Parent = o
	return r
end
local cockpit = Instance.new("Frame")
cockpit.Name = "Cockpit"
cockpit.AnchorPoint = Vector2.new(1, 1)
cockpit.Position = UDim2.new(1, -16, 1, -16)
cockpit.Size = UDim2.fromOffset(180, 262)
cockpit.BackgroundTransparency = 1
cockpit.Parent = hud
local cockpitSkala = Instance.new("UIScale")
cockpitSkala.Parent = cockpit
local function cockpitPassen()
	local kamera = workspace.CurrentCamera
	local gr = kamera and kamera.ViewportSize
	local h = (gr and gr.Y > 0) and gr.Y or 700
	cockpitSkala.Scale = math.clamp(h / 640, 0.72, 1.1)
end
cockpitPassen()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(cockpitPassen)

local tacho = Instance.new("Frame")
tacho.Name = "Tacho"
tacho.Position = UDim2.fromOffset(0, 88)
tacho.Size = UDim2.fromOffset(180, 174)
tacho.BackgroundTransparency = 1
tacho.Parent = cockpit

local scheibe = Instance.new("Frame")
scheibe.Name = "Scheibe"
scheibe.AnchorPoint = Vector2.new(0.5, 0)
scheibe.Position = UDim2.new(0.5, 0, 0, 0)
scheibe.Size = UDim2.fromOffset(150, 150)
scheibe.BackgroundColor3 = DUNKEL_HUD
scheibe.BackgroundTransparency = 0.08
scheibe.Parent = tacho
Instance.new("UICorner", scheibe).CornerRadius = UDim.new(1, 0)
rand(scheibe, 0.8, 2)
do
	local v = Instance.new("UIGradient")
	v.Rotation = 90
	v.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 175, 190))
	v.Parent = scheibe
end

-- ring of lights: 27 segments over 270°, gap at the bottom
local RING_N, RING_R = 27, 62
local ringTeile = {}
for i = 1, RING_N do
	local w = math.rad(135 + (i - 0.5) * 270 / RING_N)
	local t = Instance.new("Frame")
	t.AnchorPoint = Vector2.new(0.5, 0.5)
	t.Position = UDim2.fromOffset(75 + math.cos(w) * RING_R, 75 + math.sin(w) * RING_R)
	t.Size = UDim2.fromOffset(4, 12)
	t.Rotation = math.deg(w) + 90
	t.BorderSizePixel = 0
	t.BackgroundColor3 = Color3.fromRGB(70, 76, 92)
	t.Parent = scheibe
	Instance.new("UICorner", t).CornerRadius = UDim.new(1, 0)
	ringTeile[i] = t
end
local grenzMarke = Instance.new("Frame")
grenzMarke.Name = "Grenze"
grenzMarke.AnchorPoint = Vector2.new(0.5, 0.5)
grenzMarke.Size = UDim2.fromOffset(4, 22)
grenzMarke.BorderSizePixel = 0
grenzMarke.BackgroundColor3 = Color3.fromRGB(255, 70, 70)
grenzMarke.ZIndex = 2
grenzMarke.Parent = scheibe
Instance.new("UICorner", grenzMarke).CornerRadius = UDim.new(1, 0)

local tempoText = Instance.new("TextLabel")
tempoText.AnchorPoint = Vector2.new(0.5, 0.5)
tempoText.BackgroundTransparency = 1
tempoText.Position = UDim2.fromOffset(75, 70)
tempoText.Size = UDim2.fromOffset(110, 52)
tempoText.Font = Enum.Font.GothamBlack
tempoText.TextSize = 50
tempoText.TextColor3 = Color3.new(1, 1, 1)
tempoText.Text = "0"
tempoText.ZIndex = 2
tempoText.Parent = scheibe

-- unit: tap to switch km/h <-> mph
local einheit = Instance.new("TextButton")
einheit.AnchorPoint = Vector2.new(0.5, 0)
einheit.Position = UDim2.fromOffset(75, 98)
einheit.Size = UDim2.fromOffset(70, 22)
einheit.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
einheit.BackgroundTransparency = 0.88
einheit.AutoButtonColor = true
einheit.Font = Enum.Font.GothamBold
einheit.TextSize = 13
einheit.TextColor3 = Color3.fromRGB(200, 205, 215)
einheit.Text = "km/h"
einheit.ZIndex = 2
einheit.Parent = scheibe
Instance.new("UICorner", einheit).CornerRadius = UDim.new(1, 0)
einheit.MouseButton1Click:Connect(function()
	if not _G.Einstellungen then return end
	_G.Einstellungen.mph = not _G.Einstellungen.mph
	task.spawn(frage, "einstellungen", _G.Einstellungen)
end)

-- speed limit sign, top right of the dial
local schild = Instance.new("TextLabel")
schild.Name = "Tempolimit"
schild.AnchorPoint = Vector2.new(0.5, 0.5)
schild.Position = UDim2.fromOffset(152, 18)
schild.Size = UDim2.fromOffset(46, 46)
schild.BackgroundColor3 = Color3.new(1, 1, 1)
schild.Font = Enum.Font.GothamBlack
schild.TextSize = 19
schild.TextColor3 = Color3.new(0, 0, 0)
schild.Text = "50"
schild.ZIndex = 3
schild.Parent = tacho
Instance.new("UICorner", schild).CornerRadius = UDim.new(1, 0)
local schildRand = Instance.new("UIStroke")
schildRand.Color = ROT
schildRand.Thickness = 5
schildRand.Parent = schild

-- status chip below the dial (mistakes in a lesson, fuel / condition / points in your own car)
local fehlerText = Instance.new("TextLabel")
fehlerText.AnchorPoint = Vector2.new(0.5, 1)
fehlerText.Position = UDim2.new(0.5, 0, 1, 0)
fehlerText.Size = UDim2.fromOffset(180, 26)
fehlerText.BackgroundColor3 = DUNKEL_HUD
fehlerText.BackgroundTransparency = 0.08
fehlerText.Font = Enum.Font.GothamBold
fehlerText.TextSize = 13
fehlerText.TextColor3 = Color3.fromRGB(255, 205, 120)
fehlerText.Text = "Mistakes: 0"
fehlerText.Parent = tacho
Instance.new("UICorner", fehlerText).CornerRadius = UDim.new(1, 0)
rand(fehlerText)

-- buttons above the dial (also for phones): indicators, hazard lights, headlights, handbrake
local function rundKnopf(eltern, text, breite)
	local k = Instance.new("TextButton")
	k.Size = UDim2.fromOffset(breite, 38)
	k.BackgroundColor3 = DUNKEL_HUD
	k.BackgroundTransparency = 0.08
	k.AutoButtonColor = false
	k.Font = Enum.Font.GothamBold
	k.TextSize = 14
	k.TextColor3 = Color3.new(1, 1, 1)
	k.Text = text
	k.Parent = eltern
	Instance.new("UICorner", k).CornerRadius = UDim.new(1, 0)
	rand(k)
	return k
end
local blinkerModus = "aus"
local blinkLeiste = Instance.new("Frame")
blinkLeiste.Position = UDim2.fromOffset(0, 44)
blinkLeiste.Size = UDim2.fromOffset(180, 38)
blinkLeiste.BackgroundTransparency = 1
blinkLeiste.Parent = cockpit
local blinkLayout = Instance.new("UIListLayout")
blinkLayout.FillDirection = Enum.FillDirection.Horizontal
blinkLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
blinkLayout.Padding = UDim.new(0, 6)
blinkLayout.Parent = blinkLeiste
local blinkKnoepfe = {}
local function blinkerSetzen(modus)
	if blinkerModus == modus then modus = "aus" end
	blinkerModus = modus
	blinkerEvent:FireServer(modus)
end
for i, b in { { "links", "◀ Y" }, { "warn", "⚠ X" }, { "rechts", "C ▶" } } do
	local k = rundKnopf(blinkLeiste, b[2], 56)
	k.LayoutOrder = i
	k.MouseButton1Click:Connect(function() blinkerSetzen(b[1]) end)
	blinkKnoepfe[b[1]] = k
end

do
	local reihe2 = Instance.new("Frame")
	reihe2.Size = UDim2.fromOffset(180, 38)
	reihe2.BackgroundTransparency = 1
	reihe2.Parent = cockpit
	local l2 = Instance.new("UIListLayout")
	l2.FillDirection = Enum.FillDirection.Horizontal
	l2.HorizontalAlignment = Enum.HorizontalAlignment.Center
	l2.Padding = UDim.new(0, 6)
	l2.Parent = reihe2
	local licht = rundKnopf(reihe2, "💡 L", 56)
	licht.MouseButton1Click:Connect(function() blinkerEvent:FireServer("licht") end)
	local hb = rundKnopf(reihe2, "Handbrake ⇧", 118)
	hb.InputBegan:Connect(function(e)
		if e.UserInputType == Enum.UserInputType.Touch or e.UserInputType == Enum.UserInputType.MouseButton1 then _G.Handbremse = true end
	end)
	hb.InputEnded:Connect(function(e)
		if e.UserInputType == Enum.UserInputType.Touch or e.UserInputType == Enum.UserInputType.MouseButton1 then _G.Handbremse = false end
	end)
	local hbVorher
	RunService.RenderStepped:Connect(function()
		if _G.Handbremse == hbVorher then return end
		hbVorher = _G.Handbremse
		hb.BackgroundColor3 = _G.Handbremse and Color3.fromRGB(200, 50, 50) or DUNKEL_HUD
	end)
end

-- speedometer drawing (called 20 times per second by the HUD loop)
local function tachoZeichnen(tempo, limit, maxTempo)
	local mph = _G.Einstellungen and _G.Einstellungen.mph
	local skala = math.max(60, math.ceil(maxTempo * 1.1 / 20) * 20)
	local anteil = math.clamp(tempo / skala, 0, 1)
	local an = math.floor(anteil * RING_N + 0.5)
	local zuSchnell = tempo > limit + 3
	for i, t in ringTeile do
		if i <= an then
			local f = (i - 1) / (RING_N - 1)
			t.BackgroundColor3 = zuSchnell and Color3.fromRGB(255, 70, 70)
				or (f < 0.5 and Color3.fromRGB(80, 230, 120):Lerp(Color3.fromRGB(255, 215, 50), f * 2) or Color3.fromRGB(255, 215, 50):Lerp(Color3.fromRGB(255, 140, 40), (f - 0.5) * 2))
		else
			t.BackgroundColor3 = Color3.fromRGB(70, 76, 92)
		end
	end
	local w = math.rad(135 + math.clamp(limit / skala, 0, 1) * 270)
	grenzMarke.Position = UDim2.fromOffset(75 + math.cos(w) * RING_R, 75 + math.sin(w) * RING_R)
	grenzMarke.Rotation = math.deg(w) + 90
	tempoText.TextColor3 = zuSchnell and Color3.fromRGB(255, 90, 90) or Color3.new(1, 1, 1)
	if mph then
		tempoText.Text = tostring(inMph(tempo))
		schild.Text = tostring(inMph(limit, true))
		einheit.Text = "mph ⇄"
	else
		tempoText.Text = tostring(tempo)
		schild.Text = tostring(limit)
		einheit.Text = "km/h ⇄"
	end
	-- the sign pulses when you are too fast
	schildRand.Thickness = zuSchnell and (5 + math.abs(math.sin(os.clock() * 8)) * 3) or 5
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
	t = einh(t)
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
-- Chaos events: big banner in the middle of the screen (+ a little camera shake when you hit something)
local chaosGui = Instance.new("ScreenGui")
chaosGui.Name = "ChaosBanner"
chaosGui.ResetOnSpawn = false
chaosGui.IgnoreGuiInset = true
chaosGui.DisplayOrder = 5
chaosGui.Parent = spieler.PlayerGui
local chaosBox = Instance.new("Frame")
chaosBox.Name = "Box"
chaosBox.AnchorPoint = Vector2.new(0.5, 0.5)
chaosBox.Position = UDim2.fromScale(0.5, 0.27)
chaosBox.Size = UDim2.new(0.8, 0, 0, 96)
chaosBox.BackgroundTransparency = 1
chaosBox.Visible = false
chaosBox.Parent = chaosGui
local chaosGroesse = Instance.new("UISizeConstraint")
chaosGroesse.MaxSize = Vector2.new(620, 96)
chaosGroesse.Parent = chaosBox
local chaosSkala = Instance.new("UIScale")
chaosSkala.Parent = chaosBox
local chaosTitel = Instance.new("TextLabel")
chaosTitel.Name = "Titel"
chaosTitel.Size = UDim2.new(1, 0, 0, 58)
chaosTitel.BackgroundTransparency = 1
chaosTitel.Font = Enum.Font.FredokaOne
chaosTitel.TextScaled = true
chaosTitel.TextColor3 = Color3.fromRGB(255, 255, 255)
chaosTitel.TextStrokeTransparency = 0
chaosTitel.TextStrokeColor3 = Color3.fromRGB(20, 20, 30)
chaosTitel.Parent = chaosBox
local chaosText = Instance.new("TextLabel")
chaosText.Name = "Text"
chaosText.Position = UDim2.new(0, 0, 0, 60)
chaosText.Size = UDim2.new(1, 0, 0, 30)
chaosText.BackgroundTransparency = 1
chaosText.Font = Enum.Font.GothamBold
chaosText.TextScaled = true
chaosText.TextColor3 = Color3.fromRGB(255, 255, 255)
chaosText.TextStrokeTransparency = 0.2
chaosText.Parent = chaosBox
local CHAOS_FARBEN = {
	gelb = Color3.fromRGB(255, 210, 40), rot = Color3.fromRGB(255, 70, 70),
	gruen = Color3.fromRGB(90, 235, 110), lila = Color3.fromRGB(205, 120, 255),
}
local chaosNr = 0
local function chaosBanner(info)
	chaosNr += 1
	local nr = chaosNr
	chaosTitel.Text = info.titel or ""
	chaosTitel.TextColor3 = CHAOS_FARBEN[info.farbe] or CHAOS_FARBEN.gelb
	chaosText.Text = info.text or ""
	chaosBox.Visible = true
	chaosSkala.Scale = 0.4
	game:GetService("TweenService"):Create(chaosSkala, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(3.2, function()
		if chaosNr == nr then chaosBox.Visible = false end
	end)
	if info.rutschen then
		-- banana peel: the car spins at least half a turn (only this event; normal driving stays exactly the same)
		_G.Rutschen = { start = os.clock(), richtung = info.rutschen, gedreht = 0 }
	end
	if info.entfuehren then
		-- UFO beam: the car is pulled up into the air and put down again
		_G.Entfuehrung = { start = os.clock() }
	end
	if info.matsch then
		-- mud puddle: brown splats on the screen that drip away
		for i = 1, 9 do
			local f = Instance.new("Frame")
			local g = math.random(90, 200)
			f.Size = UDim2.fromOffset(g, g * (0.7 + math.random() * 0.5))
			f.AnchorPoint = Vector2.new(0.5, 0.5)
			local fx, fy = 0.1 + math.random() * 0.8, 0.15 + math.random() * 0.7
			f.Position = UDim2.fromScale(fx, fy)
			f.BackgroundColor3 = Color3.fromRGB(math.random(80, 110), math.random(55, 70), 30)
			f.BackgroundTransparency = 0.05
			f.BorderSizePixel = 0
			f.Parent = chaosGui
			Instance.new("UICorner", f).CornerRadius = UDim.new(1, 0)
			local TS = game:GetService("TweenService")
			task.delay(1.2 + math.random() * 0.8, function()
				TS:Create(f, TweenInfo.new(1.6), { BackgroundTransparency = 1, Position = UDim2.new(fx, 0, fy, 60) }):Play()
				task.delay(1.7, function() f:Destroy() end)
			end)
		end
	end
	if info.blitz then
		-- camera flash
		local f = Instance.new("Frame")
		f.Size = UDim2.fromScale(1, 1)
		f.BackgroundColor3 = Color3.new(1, 1, 1)
		f.BackgroundTransparency = 0
		f.BorderSizePixel = 0
		f.Parent = chaosGui
		game:GetService("TweenService"):Create(f, TweenInfo.new(0.7), { BackgroundTransparency = 1 }):Play()
		task.delay(0.8, function() f:Destroy() end)
	end
	if info.wackeln then
		-- camera shake only (CameraOffset), the car itself is not touched
		task.spawn(function()
			local hum = spieler.Character and spieler.Character:FindFirstChildOfClass("Humanoid")
			if not hum then return end
			local ende = os.clock() + 0.8
			while os.clock() < ende do
				local s = (ende - os.clock()) * 0.9
				hum.CameraOffset = Vector3.new((math.random() - 0.5) * s, (math.random() - 0.5) * s, 0)
				task.wait(0.03)
			end
			hum.CameraOffset = Vector3.new()
		end)
	end
end
_G.ChaosBanner = chaosBanner

-- 🍌 Banana Launcher (game pass): B or the banana button drops a peel behind your car
do
	local UISB = game:GetService("UserInputService")
	local knopfGui = Instance.new("ScreenGui")
	knopfGui.Name = "BananenKnopf"
	knopfGui.ResetOnSpawn = false
	knopfGui.Parent = spieler.PlayerGui
	local knopf = Instance.new("TextButton")
	knopf.AnchorPoint = Vector2.new(1, 0.5)
	knopf.Position = UDim2.new(1, -16, 0.3, 0) -- above the handbrake / indicator buttons
	knopf.Size = UDim2.fromOffset(64, 64)
	knopf.BackgroundColor3 = Color3.fromRGB(255, 205, 40)
	knopf.Text = "🍌"
	knopf.TextScaled = true
	knopf.Visible = false
	knopf.Parent = knopfGui
	Instance.new("UICorner", knopf).CornerRadius = UDim.new(1, 0)
	local taste = Instance.new("TextLabel")
	taste.AnchorPoint = Vector2.new(0.5, 0)
	taste.Position = UDim2.new(0.5, 0, 1, 2)
	taste.Size = UDim2.fromOffset(64, 16)
	taste.BackgroundTransparency = 1
	taste.Font = Enum.Font.GothamBold
	taste.TextSize = 12
	taste.TextColor3 = Color3.new(1, 1, 1)
	taste.TextStrokeTransparency = 0.3
	taste.Text = "B"
	taste.Parent = knopf
	local function werfen()
		local r = frage("bananeWerfen")
		if r and (r.fehler or r.text) then warnen(r.fehler or r.text, r.fehler and Color3.fromRGB(200, 140, 30) or GRUEN) end
	end
	knopf.Activated:Connect(werfen)
	local function imAuto()
		-- driver or passenger (friends riding along can throw too)
		local hum = spieler.Character and spieler.Character:FindFirstChildOfClass("Humanoid")
		return hum ~= nil and hum.SeatPart ~= nil
	end
	UISB.InputBegan:Connect(function(eingabe, verarbeitet)
		if verarbeitet or eingabe.KeyCode ~= Enum.KeyCode.B then return end
		if imAuto() then werfen() end
	end)
	task.spawn(function()
		while true do
			knopf.Visible = imAuto() == true and spieler:GetAttribute("BananenWerfer") == true
			task.wait(0.5)
		end
	end)
end

-- 📯 Horn: H or the horn button in any car (driver or passenger). Everybody nearby hears it.
local function hupeDef(key)
	for _, h in Hupen do
		if h.key == key then return h end
	end
	return Hupen[1]
end
local function hupeAbspielen(teil, def)
	if not def or def.id == 0 or not teil then return end
	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://" .. def.id
	s.Volume = 0.9
	s.RollOffMaxDistance = 220
	s.Parent = teil
	s:Play()
	task.delay(4, function() s:Destroy() end)
end
_G.HupeAbspielen = hupeAbspielen
do
	local UISH = game:GetService("UserInputService")
	local hupGui = Instance.new("ScreenGui")
	hupGui.Name = "HupenKnopf"
	hupGui.ResetOnSpawn = false
	hupGui.Parent = spieler.PlayerGui
	local knopf = Instance.new("TextButton")
	knopf.AnchorPoint = Vector2.new(1, 0.5)
	knopf.Position = UDim2.new(1, -16, 0.3, -76) -- above the banana button
	knopf.Size = UDim2.fromOffset(56, 56)
	knopf.BackgroundColor3 = Color3.fromRGB(240, 120, 40)
	knopf.Text = "📯"
	knopf.TextScaled = true
	knopf.Visible = false
	knopf.Parent = hupGui
	Instance.new("UICorner", knopf).CornerRadius = UDim.new(1, 0)
	local taste = Instance.new("TextLabel")
	taste.AnchorPoint = Vector2.new(0.5, 0)
	taste.Position = UDim2.new(0.5, 0, 1, 1)
	taste.Size = UDim2.fromOffset(56, 14)
	taste.BackgroundTransparency = 1
	taste.Font = Enum.Font.GothamBold
	taste.TextSize = 12
	taste.TextColor3 = Color3.new(1, 1, 1)
	taste.TextStrokeTransparency = 0.3
	taste.Text = "H"
	taste.Parent = knopf
	local zuletzt = 0
	local function hupen()
		if os.clock() - zuletzt < 0.8 then return end
		zuletzt = os.clock()
		task.spawn(function()
			local r = frage("hupen")
			if r and r.fehler then warnen(r.fehler, Color3.fromRGB(200, 140, 30)) end
		end)
	end
	knopf.Activated:Connect(hupen)
	local function sitzt()
		local hum = spieler.Character and spieler.Character:FindFirstChildOfClass("Humanoid")
		local s = hum and hum.SeatPart
		return s ~= nil and s:FindFirstAncestorOfClass("Model") ~= nil and s:FindFirstAncestorOfClass("Model"):FindFirstChild("Chassis", true) ~= nil
	end
	UISH.InputBegan:Connect(function(eingabe, verarbeitet)
		if verarbeitet or eingabe.KeyCode ~= Enum.KeyCode.H then return end
		if sitzt() then hupen() end
	end)
	task.spawn(function()
		while true do
			knopf.Visible = sitzt()
			task.wait(0.5)
		end
	end)
end

-- ---------------------------------------------------------------
-- v54 beta: invite friends, report "map loaded", 🧑‍🏫 instructor mode light
-- ---------------------------------------------------------------
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

-- 📯 somebody honked: sound from the car + a "HONK!" bubble over it for everybody nearby
local function hupeZeigen(info)
	local m = info.modell
	if not (m and m.Parent) then return end
	local teil = m:FindFirstChild("Chassis", true) or m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart", true)
	if not teil then return end
	local kamera = workspace.CurrentCamera
	if kamera and (kamera.CFrame.Position - teil.Position).Magnitude > 260 then return end
	local def = hupeDef(info.art)
	hupeAbspielen(teil, def)
	local bb = Instance.new("BillboardGui")
	bb.Name = "Hupe"
	bb.Size = UDim2.fromOffset(170, 40)
	bb.StudsOffset = Vector3.new(0, 6, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 160
	bb.Adornee = teil
	bb.Parent = spieler.PlayerGui
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = Color3.fromRGB(255, 230, 60)
	t.TextStrokeTransparency = 0
	t.Text = def and def.text or "📯 HONK!"
	t.Parent = bb
	local skala = Instance.new("UIScale")
	skala.Scale = 0.3
	skala.Parent = t
	game:GetService("TweenService"):Create(skala, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(1.3, function() bb:Destroy() end)
end

fahrEvent.OnClientEvent:Connect(function(info)
	if info.typ == "chaos" then
		chaosBanner(info)
	elseif info.typ == "kommando" then
		kommandoZeigen(info)
	elseif info.typ == "hupe" then
		hupeZeigen(info)
	elseif info.typ == "party" then
		if _G.PartyEvent then _G.PartyEvent(info) end
	elseif info.typ == "blinker" then
		blinkerModus = info.modus
	elseif info.typ == "start" then
		blinkerModus = "aus"
		lektionAktiv = true
		hud.Enabled = true
		fehlerGrenze = info.grenze
		lektionTitel.Text = info.titel
		anweisungText.Text = (info.sprecher or "Instructor") .. ": " .. einh(info.text)
		fehlerText.Text = info.status or ("Mistakes: 0/%d"):format(fehlerGrenze or 9)
		schliessen()
	elseif info.typ == "ziel" then
		lektionAktiv = true
		hud.Enabled = true
		anweisungText.Text = (info.sprecher or "Instructor") .. ": " .. einh(info.text)
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
	elseif info.typ == "ende" and info.party then
		-- party test: the results window comes when everybody is done
		hudAus()
		chaosBanner({ titel = info.erfolg and "🏁 PARKED!" or "🏁 OUT OF THE RACE", text = info.erfolg and ("Mistakes: %d (+%d s). Waiting for the others …"):format(info.fehler or 0, (info.fehler or 0) * 5) or (info.text or ""), farbe = info.erfolg and "gruen" or "rot" })
	elseif info.typ == "ende" then
		hudAus()
		local titelText = info.erfolg and ("Lesson %d/%d complete! 🎉"):format(info.nr, info.gesamt) or (info.pruefung and "Driving test failed" or "Lesson ended")
		-- stars: 0 mistakes = 3, up to 2 = 2, otherwise 1 (replay the lesson at Anna's for more)
		local sterneText = ""
		if info.sterne then
			sterneText = "\n\n<font size=\"30\" color=\"#ffd23c\">" .. string.rep("★", info.sterne) .. "</font><font size=\"30\" color=\"#5a6070\">" .. string.rep("★", 3 - info.sterne) .. "</font>"
			if info.besser then sterneText ..= "\n<b>New best!</b> Bonus coins for the extra stars." end
			if info.sterne < 3 then sterneText ..= "\n<font size=\"14\" color=\"#9aa4b5\">0 mistakes = 3 stars. You can repeat lessons with Anna.</font>" end
		end
		local knoepfe = { { text = "Close", farbe = info.erfolg and GRUEN or GRAU, klick = schliessen } }
		if not info.erfolg then
			-- v51: start the same lesson / test again right away (new car on the parking lot)
			table.insert(knoepfe, 1, { text = "🔁 Try again", farbe = GRUEN, klick = function()
				local a = frage("nochmal")
				if a.fehler then hinweis(a.fehler) else zeige("Try again", a.text, { { text = "Let's go!", farbe = GRUEN, klick = schliessen } }, "dialog") end
			end })
		end
		-- v54: funny "certificate" title – made for screenshots
		local f = info.fehler or 0
		local titel = (not info.erfolg and f >= 10) and "💥 Licensed Menace"
			or (not info.erfolg) and "🚧 Danger to Society (in training)"
			or f == 0 and "😇 Certified Road Angel"
			or f <= 2 and "🚗 Mostly Harmless"
			or f <= 5 and "🍌 Professional Banana Dodger"
			or "🐄 Cow Whisperer"
		local zeugnis = ("\n\n<font size=\"13\" color=\"#9aa4b5\">OFFICIAL RESULT FOR %s</font>\n<font size=\"22\" color=\"#ffd23c\"><b>%s</b></font>"):format(spieler.DisplayName:upper(), titel)
		zeige(titelText, info.text .. ("\n\nMistakes: %d"):format(f) .. sterneText .. zeugnis .. (info.erfolg and ("\n\n" .. (info.weiter or "Talk to Anna at the reception for your next lesson.")) or ""), knoepfe, "hinweis")
	end
end)

local naechsteHud = 0
RunService.RenderStepped:Connect(function()
	-- 20 updates per second are plenty for text and buttons (saves time on phones)
	local jetztHud = os.clock()
	if jetztHud < naechsteHud then return end
	naechsteHud = jetztHud + 0.05
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
		k.BackgroundColor3 = (aktiv and an) and Color3.fromRGB(255, 165, 30) or DUNKEL_HUD
	end
	if sitz and sitz:IsA("VehicleSeat") then
		local tempo = math.floor(sitz.AssemblyLinearVelocity.Magnitude + 0.5)
		local limit = Regeln.tempolimit(sitz.Position)
		tachoZeichnen(tempo, limit, (sitz.Parent and sitz.Parent:GetAttribute("MaxTempo")) or 130)
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
		-- touch pedals (phones/tablets) only replace the input, the car drives exactly the same
		if _G.TouchGas and _G.TouchGas ~= 0 then gas = _G.TouchGas end
		if _G.TouchLenk and _G.TouchLenk ~= 0 then lenk = _G.TouchLenk end
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
		-- banana peel (chaos event): a short spin with almost no grip, then normal again
		local rutsch = _G.Rutschen
		local rutschFaktor, drehSofort = 1, false
		if rutsch then
			local jetztR = os.clock()
			if not rutsch.fertig then
				-- spin until at least 200 degrees (or 2.5 s, e.g. when the car hits a wall)
				rutsch.gedreht += math.abs(chassis.AssemblyAngularVelocity.Y) * dt
				if rutsch.gedreht >= math.rad(200) or jetztR - rutsch.start > 2.5 then rutsch.fertig = jetztR end
				zielDrehung = rutsch.richtung * 5
				rutschFaktor = 0.06
				drehSofort = true -- the tyres must not stop the spin
			else
				-- 0.5 s to get the grip back, then everything is normal again
				local f = (jetztR - rutsch.fertig) / 0.5
				if f >= 1 then
					_G.Rutschen = nil
				else
					zielDrehung = rutsch.richtung * 5 * (1 - f) + zielDrehung * f
					rutschFaktor = 0.06 + 0.94 * f * f
					drehSofort = true
				end
			end
		end
		local w0 = chassis.AssemblyAngularVelocity
		local neu = w0.Y + (zielDrehung - w0.Y) * (drehSofort and 1 or math.min(1, wert("Lenkdirekt", 14) * dt))
		chassis.AssemblyAngularVelocity = Vector3.new(w0.X, neu, w0.Z)

		-- UFO beam (chaos event): up into the air, slowly turning, then gently down again
		local ent = _G.Entfuehrung
		if ent then
			local el = os.clock() - ent.start
			if el > 5.4 then
				_G.Entfuehrung = nil
			else
				local hoch = el < 2.7 and 9 or -9
				chassis.AssemblyLinearVelocity = Vector3.new(v.X * 0.9, hoch, v.Z * 0.9)
				chassis.AssemblyAngularVelocity = Vector3.new(0, 1.4, 0)
				return -- no grip or downforce while flying
			end
		end

		-- grip (no sliding sideways), downforce and roll/pitch damping
		local masse = chassis.AssemblyMass
		local quer = v:Dot(cf.RightVector)
		-- rain makes the road slippery, the handbrake lets the rear slide (drift)
		local griff = wert("Grip", 14) * (ordner:GetAttribute("Wetter") == "Rain" and 0.7 or 1) * (_G.Handbremse and 0.35 or 1) * rutschFaktor
		chassis:ApplyImpulse(-cf.RightVector * quer * masse * math.min(1, griff * dt))
		chassis:ApplyImpulse(-cf.UpVector * masse * wert("Anpressdruck", 60) * dt)
		local w = chassis.AssemblyAngularVelocity
		local rollen = w:Dot(cf.LookVector)
		local nicken = w:Dot(cf.RightVector)
		chassis:ApplyAngularImpulse((-cf.LookVector * rollen - cf.RightVector * nicken) * masse * 8 * math.min(1, 6 * dt))
	end)
end

-- ---------------------------------------------------------------
-- Arrow to your driving school car (first time on the server, and whenever you're out of it):
-- bouncing arrow over the car, a glowing line from you to the driver's door, and an arrow at the
-- screen edge when the car is behind you
-- ---------------------------------------------------------------
do
	local pfeilGui = Instance.new("ScreenGui")
	pfeilGui.Name = "AutoPfeil"
	pfeilGui.ResetOnSpawn = false
	pfeilGui.IgnoreGuiInset = true
	pfeilGui.Parent = spieler:WaitForChild("PlayerGui")
	local rand = Instance.new("TextLabel")
	rand.Name = "Randpfeil"
	rand.AnchorPoint = Vector2.new(0.5, 0.5)
	rand.Size = UDim2.fromOffset(64, 64)
	rand.BackgroundColor3 = Color3.fromRGB(40, 170, 80)
	rand.Font = Enum.Font.GothamBlack
	rand.TextSize = 34
	rand.TextColor3 = Color3.new(1, 1, 1)
	rand.Text = "▶"
	rand.Visible = false
	rand.Parent = pfeilGui
	Instance.new("UICorner", rand).CornerRadius = UDim.new(1, 0)
	local rs = Instance.new("UIStroke")
	rs.Color = Color3.new(1, 1, 1)
	rs.Thickness = 3
	rs.Parent = rand

	local ordnerP = Instance.new("Folder")
	ordnerP.Name = "AutoPfeil"
	local bb, beam, a0, a1, auto
	local function weg()
		if bb then bb:Destroy() bb = nil end
		if beam then beam:Destroy() beam = nil end
		if a0 then a0:Destroy() a0 = nil end
		if a1 then a1:Destroy() a1 = nil end
		auto = nil
		rand.Visible = false
	end
	local function bauen(m, tuer)
		weg()
		auto = m
		ordnerP.Parent = workspace
		bb = Instance.new("BillboardGui")
		bb.Name = "AutoPfeil"
		bb.Size = UDim2.fromOffset(150, 120)
		bb.StudsOffset = Vector3.new(0, 10, 0)
		bb.AlwaysOnTop = true
		bb.LightInfluence = 0
		bb.Adornee = tuer
		bb.Parent = ordnerP
		local schrift = Instance.new("TextLabel")
		schrift.Size = UDim2.new(1, 0, 0, 30)
		schrift.BackgroundColor3 = Color3.fromRGB(40, 170, 80)
		schrift.Font = Enum.Font.GothamBlack
		schrift.TextSize = 17
		schrift.TextColor3 = Color3.new(1, 1, 1)
		schrift.Text = "YOUR CAR · E"
		schrift.Parent = bb
		Instance.new("UICorner", schrift).CornerRadius = UDim.new(1, 0)
		local pfeil = Instance.new("TextLabel")
		pfeil.Name = "Pfeil"
		pfeil.Position = UDim2.fromOffset(0, 30)
		pfeil.Size = UDim2.new(1, 0, 0, 90)
		pfeil.BackgroundTransparency = 1
		pfeil.Font = Enum.Font.GothamBlack
		pfeil.TextSize = 80
		pfeil.TextColor3 = Color3.fromRGB(70, 235, 110)
		pfeil.TextStrokeTransparency = 0
		pfeil.Text = "▼"
		pfeil.Parent = bb
		a1 = Instance.new("Attachment")
		a1.Name = "AutoPfeilZiel"
		a1.Parent = tuer
	end
	local naechste = 0
	RunService.RenderStepped:Connect(function()
		local jetzt = os.clock()
		if bb then bb.StudsOffset = Vector3.new(0, 9.5 + math.abs(math.sin(jetzt * 3)) * 2, 0) end
		if beam then beam.Transparency = NumberSequence.new(0.25 + math.abs(math.sin(jetzt * 4)) * 0.35) end
		if jetzt >= naechste then
			naechste = jetzt + 0.3
			local m = workspace:FindFirstChild("Fahrschulauto_" .. spieler.Name) or workspace:FindFirstChild("Fahrschul_Lkw_" .. spieler.Name)
			local tuer = m and (m:FindFirstChild("Fahrersitz") or m:FindFirstChildWhichIsA("VehicleSeat", true))
			local hum = spieler.Character and spieler.Character:FindFirstChildOfClass("Humanoid")
			local wurzel = spieler.Character and spieler.Character:FindFirstChild("HumanoidRootPart")
			local drin = hum and tuer and hum.SeatPart == tuer
			-- your own car: no "Ride along" for yourself (only friends see it)
			local eigen = m and m:FindFirstChild("Mitfahren", true)
			if eigen and eigen.Enabled then eigen.Enabled = false end
			if not (m and tuer and wurzel) or drin then
				if auto then weg() end
			else
				if auto ~= m then bauen(m, tuer) end
				if not a0 or a0.Parent ~= wurzel then
					if a0 then a0:Destroy() end
					a0 = Instance.new("Attachment")
					a0.Name = "AutoPfeilStart"
					a0.Position = Vector3.new(0, -2.5, 0)
					a0.Parent = wurzel
					if beam then beam:Destroy() end
					beam = Instance.new("Beam")
					beam.Attachment0, beam.Attachment1 = a0, a1
					beam.Color = ColorSequence.new(Color3.fromRGB(70, 235, 110))
					beam.LightEmission = 1
					beam.LightInfluence = 0
					beam.Width0, beam.Width1 = 0.9, 0.9
					beam.FaceCamera = true
					beam.Segments = 12
					beam.CurveSize0, beam.CurveSize1 = 4, -4
					beam.Parent = ordnerP
				end
				-- line only while you're further away than a few steps
				beam.Enabled = (wurzel.Position - tuer.Position).Magnitude > 9
			end
		end
		-- arrow at the screen edge when the car is not on screen
		if auto and a1 and a1.Parent then
			local kamera = workspace.CurrentCamera
			local p, sichtbar = kamera:WorldToViewportPoint(a1.WorldPosition)
			local gr = kamera.ViewportSize
			if not (p and gr) then return end
			if sichtbar and p.X > 0 and p.X < gr.X and p.Y > 0 and p.Y < gr.Y then
				rand.Visible = false
			else
				local mitte = gr / 2
				local richtung = Vector2.new(p.X, p.Y) - mitte
				if p.Z < 0 then richtung = -richtung end
				if richtung.Magnitude < 1 then richtung = Vector2.new(0, 1) end
				richtung = richtung.Unit
				local rx, ry = gr.X / 2 - 50, gr.Y / 2 - 50
				local k = math.min(rx / math.max(math.abs(richtung.X), 1e-3), ry / math.max(math.abs(richtung.Y), 1e-3))
				local pos = mitte + richtung * k
				rand.Position = UDim2.fromOffset(pos.X, pos.Y)
				rand.Rotation = math.deg(math.atan2(richtung.Y, richtung.X))
				rand.Visible = true
			end
		end
	end)
end

-- ---------------------------------------------------------------
-- Phones and tablets: gas / brake pedals and steering buttons while driving
-- ---------------------------------------------------------------
do
	local UISP = game:GetService("UserInputService")
	local pedale = Instance.new("ScreenGui")
	pedale.Name = "Pedale"
	pedale.ResetOnSpawn = false
	pedale.Enabled = false
	pedale.DisplayOrder = 4
	pedale.Parent = spieler:WaitForChild("PlayerGui")
	_G.TouchGas, _G.TouchLenk = 0, 0
	local gedrueckt, knoepfe = {}, {}
	local function neu()
		_G.TouchGas = (gedrueckt.gas and 1 or 0) - (gedrueckt.bremse and 1 or 0)
		_G.TouchLenk = (gedrueckt.rechts and 1 or 0) - (gedrueckt.links and 1 or 0)
		for name, k in knoepfe do
			k.BackgroundTransparency = gedrueckt[name] and 0.05 or 0.35
		end
	end
	local function taste(name, text, anker, pos, groesse, farbe)
		local k = Instance.new("TextButton")
		k.Name = name
		k.AnchorPoint = anker
		k.Position = pos
		k.Size = groesse
		k.BackgroundColor3 = farbe
		k.BackgroundTransparency = 0.35
		k.AutoButtonColor = false
		k.Font = Enum.Font.GothamBlack
		k.TextScaled = true
		k.TextColor3 = Color3.new(1, 1, 1)
		k.Text = text
		k.Parent = pedale
		Instance.new("UICorner", k).CornerRadius = UDim.new(0, 16)
		local pad = Instance.new("UIPadding")
		pad.PaddingTop, pad.PaddingBottom, pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 14), UDim.new(0, 14), UDim.new(0, 10), UDim.new(0, 10)
		pad.Parent = k
		k.InputBegan:Connect(function(e)
			if e.UserInputType == Enum.UserInputType.Touch or e.UserInputType == Enum.UserInputType.MouseButton1 then gedrueckt[name] = true neu() end
		end)
		k.InputEnded:Connect(function(e)
			if e.UserInputType == Enum.UserInputType.Touch or e.UserInputType == Enum.UserInputType.MouseButton1 then gedrueckt[name] = nil neu() end
		end)
		knoepfe[name] = k
	end
	local DUNKEL = Color3.fromRGB(25, 30, 40)
	taste("links", "◀", Vector2.new(0, 1), UDim2.new(0, 16, 1, -16), UDim2.fromOffset(96, 96), DUNKEL)
	taste("rechts", "▶", Vector2.new(0, 1), UDim2.new(0, 122, 1, -16), UDim2.fromOffset(96, 96), DUNKEL)
	-- right side, left of the speedometer column
	taste("gas", "GAS", Vector2.new(1, 1), UDim2.new(1, -200, 1, -16), UDim2.fromOffset(88, 128), Color3.fromRGB(40, 150, 70))
	taste("bremse", "BRAKE", Vector2.new(1, 1), UDim2.new(1, -296, 1, -16), UDim2.fromOffset(88, 88), Color3.fromRGB(190, 45, 45))
	-- only on touch screens and only while driving
	local naechstePruefung = 0
	RunService.Heartbeat:Connect(function()
		if os.clock() < naechstePruefung then return end
		naechstePruefung = os.clock() + 0.25
		local hum = spieler.Character and spieler.Character:FindFirstChildOfClass("Humanoid")
		local sitz = hum and hum.SeatPart
		local faehrt = sitz ~= nil and sitz:IsA("VehicleSeat") and sitz.Parent ~= nil and sitz.Parent:GetAttribute("MaxTempo") ~= nil
		local an = UISP.TouchEnabled == true and faehrt
		if pedale.Enabled ~= an then
			pedale.Enabled = an
			if not an then
				gedrueckt = {}
				neu()
			end
		end
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
-- fold-out menu top left: only the "Menu" button is visible, the other buttons slide out next to it
local klappe = Instance.new("Frame")
klappe.Name = "Klappe"
klappe.BackgroundTransparency = 1
klappe.ClipsDescendants = true
klappe.Position = UDim2.new(0, 12 + 52 + 6, 0, 60)
klappe.Size = UDim2.fromOffset(0, 48)
klappe.Parent = kameraGui
local leiste = Instance.new("Frame")
leiste.Name = "Leiste"
leiste.BackgroundTransparency = 1
leiste.Size = UDim2.fromOffset(0, 48)
leiste.AutomaticSize = Enum.AutomaticSize.X
leiste.Parent = klappe
local leistenLayout = Instance.new("UIListLayout")
leistenLayout.FillDirection = Enum.FillDirection.Horizontal
leistenLayout.Padding = UDim.new(0, 5)
leistenLayout.SortOrder = Enum.SortOrder.LayoutOrder
leistenLayout.Parent = leiste
local function leistenKnopf(icon, text, reihenfolge, farbe)
	local k = Instance.new("TextButton")
	k.Name = text
	k.LayoutOrder = reihenfolge
	k.Size = UDim2.fromOffset(52, 48)
	k.BackgroundColor3 = farbe or Color3.fromRGB(25, 30, 40)
	k.BackgroundTransparency = 0.12
	k.AutoButtonColor = false
	k.Text = ""
	k.Parent = leiste
	Instance.new("UICorner", k).CornerRadius = UDim.new(0, 12)
	-- thin light edge and a soft top-to-bottom shade: looks like a real app button
	local rand = Instance.new("UIStroke")
	rand.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	rand.Color = Color3.new(1, 1, 1)
	rand.Transparency = 0.82
	rand.Thickness = 1
	rand.Parent = k
	local verlauf = Instance.new("UIGradient")
	verlauf.Rotation = 90
	verlauf.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(175, 180, 195))
	verlauf.Parent = k
	k.MouseEnter:Connect(function() rand.Transparency = 0.45 end)
	k.MouseLeave:Connect(function() rand.Transparency = 0.82 end)
	local bild = Instance.new("TextLabel")
	bild.Name = "Icon"
	bild.BackgroundTransparency = 1
	bild.Position = UDim2.fromOffset(0, 3)
	bild.Size = UDim2.new(1, 0, 0, 26)
	bild.Font = Enum.Font.GothamBold
	bild.TextSize = 22
	bild.TextColor3 = Color3.new(1, 1, 1)
	bild.Text = icon
	bild.Parent = k
	local name = Instance.new("TextLabel")
	name.Name = "Beschriftung"
	name.BackgroundTransparency = 1
	name.Position = UDim2.new(0, 0, 1, -17)
	name.Size = UDim2.new(1, 0, 0, 14)
	name.Font = Enum.Font.GothamBold
	name.TextSize = 10
	name.TextColor3 = Color3.fromRGB(225, 230, 240)
	name.Text = text
	name.Parent = k
	return k
end
local menueKnopf = leistenKnopf("", "Menu", 0, Color3.fromRGB(30, 95, 190))
menueKnopf.Name = "Menue"
menueKnopf.Position = UDim2.new(0, 12, 0, 60)
menueKnopf.Parent = kameraGui
-- drawn menu symbol (three rounded bars) instead of the "☰" character, which some phones can't show;
-- it turns into an X when the menu is open
local symbol = Instance.new("Frame")
symbol.Name = "Symbol"
symbol.AnchorPoint = Vector2.new(0.5, 0)
symbol.Position = UDim2.new(0.5, 0, 0, 8)
symbol.Size = UDim2.fromOffset(22, 17)
symbol.BackgroundTransparency = 1
symbol.Parent = menueKnopf
local SYMBOL_Y = { 1.5, 8.5, 15.5 }
local striche = {}
for i, y in SYMBOL_Y do
	local b = Instance.new("Frame")
	b.Name = "Strich" .. i
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.Position = UDim2.new(0.5, 0, 0, y)
	b.Size = UDim2.fromOffset(22, 3)
	b.BackgroundColor3 = Color3.new(1, 1, 1)
	b.BorderSizePixel = 0
	b.Parent = symbol
	Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
	striche[i] = b
end
local function symbolSetzen(offen)
	local TS = game:GetService("TweenService")
	local info = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TS:Create(striche[1], info, { Position = UDim2.new(0.5, 0, 0, offen and 8.5 or SYMBOL_Y[1]), Rotation = offen and 45 or 0 }):Play()
	TS:Create(striche[3], info, { Position = UDim2.new(0.5, 0, 0, offen and 8.5 or SYMBOL_Y[3]), Rotation = offen and -45 or 0 }):Play()
	TS:Create(striche[2], info, { BackgroundTransparency = offen and 1 or 0, Size = UDim2.fromOffset(offen and 4 or 22, 3) }):Play()
end
-- red dot on the menu button while rewards are waiting and the menu is closed
local menuePunkt = Instance.new("TextLabel")
menuePunkt.Name = "Punkt"
menuePunkt.AnchorPoint = Vector2.new(0.5, 0.5)
menuePunkt.Position = UDim2.new(1, -2, 0, 2)
menuePunkt.Size = UDim2.fromOffset(20, 20)
menuePunkt.BackgroundColor3 = Color3.fromRGB(230, 40, 50)
menuePunkt.Font = Enum.Font.GothamBlack
menuePunkt.TextSize = 12
menuePunkt.TextColor3 = Color3.new(1, 1, 1)
menuePunkt.Visible = false
menuePunkt.Parent = menueKnopf
Instance.new("UICorner", menuePunkt).CornerRadius = UDim.new(1, 0)
local menueOffen = false
local function menuePunktNeu()
	local n = spieler:GetAttribute("BelohnungenOffen") or 0
	menuePunkt.Visible = n > 0 and not menueOffen
	menuePunkt.Text = tostring(n)
end
local function menueSetzen(offen)
	menueOffen = offen
	local n = 0
	for _, k in leiste:GetChildren() do
		if k:IsA("TextButton") then n += 1 end
	end
	local breite = offen and (n * 52 + math.max(0, n - 1) * 5) or 0
	game:GetService("TweenService"):Create(klappe, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(breite, 48) }):Play()
	symbolSetzen(offen)
	menueKnopf.Beschriftung.Text = offen and "Close" or "Menu"
	menuePunktNeu()
end
_G.MenueSetzen = menueSetzen
menueKnopf.MouseButton1Click:Connect(function() menueSetzen(not menueOffen) end)
spieler:GetAttributeChangedSignal("BelohnungenOffen"):Connect(menuePunktNeu)
-- after choosing something the menu folds up again (not for the camera button)
leiste.ChildAdded:Connect(function(k)
	if k:IsA("TextButton") and k.Name ~= "1st (V)" then
		k.MouseButton1Click:Connect(function() menueSetzen(false) end)
	end
end)
local kameraKnopf = leistenKnopf("🎥", "1st (V)", 6)

local ersteP = false
local function perspektive(an)
	ersteP = an
	if an then
		spieler.CameraMode = Enum.CameraMode.LockFirstPerson
		kameraKnopf.Beschriftung.Text = "3rd (V)"
	else
		spieler.CameraMode = Enum.CameraMode.Classic
		spieler.CameraMinZoomDistance = 12 -- jump out of first person ...
		task.delay(0.15, function()
			spieler.CameraMinZoomDistance = 0.5 -- ... but still allow zooming in with the mouse wheel
		end)
		kameraKnopf.Beschriftung.Text = "1st (V)"
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
	leiste.Position = UDim2.new(0, 74, 0, 6) -- right of the game's Menu button, at the top
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
	local ueberschrift = Instance.new("TextButton") -- click = fold in / out
	ueberschrift.Name = "Kopf"
	ueberschrift.AutoButtonColor = false
	ueberschrift.Size = UDim2.new(1, 0, 0, 18)
	ueberschrift.BackgroundTransparency = 1
	ueberschrift.Font = Enum.Font.GothamBlack
	ueberschrift.TextSize = 13
	ueberschrift.TextColor3 = Color3.fromRGB(255, 200, 200)
	ueberschrift.Text = "TEST MENU ▲"
	ueberschrift.Parent = leiste
	local function devKnopf(reihenfolge, beschriftung, befehl, nr, art, eltern)
		local k = Instance.new("TextButton")
		k.LayoutOrder = reihenfolge
		k.Size = UDim2.new(1, 0, 0, 24)
		k.BackgroundColor3 = Color3.fromRGB(110, 40, 40)
		k.Font = Enum.Font.GothamBold
		k.TextSize = 13
		k.TextColor3 = Color3.new(1, 1, 1)
		k.Text = beschriftung
		k.Parent = eltern or leiste
		Instance.new("UICorner", k)
		k.MouseButton1Click:Connect(function()
			local r = frage("dev", { befehl = befehl, nr = nr, art = art })
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
	-- chaos events on demand (during a lesson, they appear in front of the car) – second column
	local chaosLeiste = leiste:Clone()
	for _, x in chaosLeiste:GetChildren() do
		if x:IsA("TextButton") and x.Name ~= "Kopf" then x:Destroy() end
	end
	chaosLeiste.Position = UDim2.new(0, 230, 0, 6)
	chaosLeiste.Parent = devGui
	-- both columns fold in and out with a click on their title
	local function klappen(spalte, titel)
		local kopf = spalte:FindFirstChild("Kopf")
		local offen = true
		kopf.Text = titel .. " ▲"
		kopf.MouseButton1Click:Connect(function()
			offen = not offen
			kopf.Text = titel .. (offen and " ▲" or " ▼")
			for _, x in spalte:GetChildren() do
				if x:IsA("TextButton") and x ~= kopf then x.Visible = offen end
			end
		end)
	end
	for i, ev in { { "🍌 Banana", "banane" }, { "🦆 Ducks", "enten" }, { "🐄 Cows", "kuehe" }, { "🐔 Chickens", "huehner" },
		{ "⭕ Giant tire", "reifen" }, { "🟤 Mud", "pfuetze" }, { "🤡 Clown camera", "clown" }, { "👽 UFO", "ufo" }, { "🎲 Random event", nil } } do
		devKnopf(20 + i, ev[1], "chaos", nil, ev[2], chaosLeiste)
	end
	klappen(leiste, "TEST MENU")
	klappen(chaosLeiste, "CHAOS EVENTS")
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
		-- v51: wait until the save game is loaded (the server answers "still loading" before)
		local r = frageGeladen("kartendaten")
		if not r.daten then warn("[Driving School] minimap: no map data") return end
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

	local naechsteKarte = 0
	RunService.RenderStepped:Connect(function()
		if not mmGui.Enabled then return end
		-- the minimap is a 3D view of its own: redraw it at most 30 times a second (12 in performance mode)
		local jetzt = os.clock()
		if jetzt < naechsteKarte then return end
		naechsteKarte = jetzt + (_G.Sparmodus and 1 / 12 or 1 / 30)
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
	untertitel.Text = info.lkw and "Your instructor: Your license now also shows class C. Go and earn some coins!" or "Your instructor: Great job! Here is your driver's license."
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
	local naechsteUhr = 0
	RunService.RenderStepped:Connect(function()
		if os.clock() < naechsteUhr then return end
		naechsteUhr = os.clock() + 0.5
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
		tropfen.Rate = (ordner:GetAttribute("Wetter") == "Rain") and (_G.Sparmodus and 250 or 900) or 0
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
	local akteKnopf = leistenKnopf("📋", "Record", 5)
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
	local mKnopf = leistenKnopf("🎯", "Daily", 3)
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
	local naechsterBlick = 0
	RunService.RenderStepped:Connect(function()
		if os.clock() < naechsterBlick then return end
		naechsterBlick = os.clock() + 0.1
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
-- Phones, tablets and weak PCs
-- * big windows are scaled down so they fit on small screens
-- * street lamps only light up at night and near the camera
-- * performance mode ("Graphics: Fast" in the settings): no sun rays / depth of field / bloom,
--   less rain, far NPC cars and the minimap are updated less often.
--   It switches on by itself on phones/tablets and when the frame rate stays low.
-- ---------------------------------------------------------------
do
	local Lighting = game:GetService("Lighting")
	local GuiService = game:GetService("GuiService")
	local UIS = game:GetService("UserInputService")

	-- thousands of building windows use the Glass material; in Fast mode they become plain shiny plastic
	local fenster = {}
	local function fensterSetzen(x)
		x.Material = _G.Sparmodus and Enum.Material.SmoothPlastic or Enum.Material.Glass
	end
	_G.SparmodusSetzen = function(an)
		local vorher = _G.Sparmodus
		_G.Sparmodus = an == true
		Verkehr.sparmodus = _G.Sparmodus
		for _, e in Lighting:GetChildren() do
			if e:IsA("SunRaysEffect") or e:IsA("DepthOfFieldEffect") or e:IsA("BloomEffect") then
				e.Enabled = not _G.Sparmodus
			end
		end
		if vorher ~= _G.Sparmodus then
			for x in fenster do fensterSetzen(x) end
		end
	end
	task.spawn(function()
		local karte = workspace:WaitForChild("Karte")
		local function merken(x)
			if x:IsA("BasePart") and (x.Name == "Fenster" or x.Name == "Scheiben") and x.Material == Enum.Material.Glass then
				fenster[x] = true
				if _G.Sparmodus then fensterSetzen(x) end
			end
		end
		for i, x in karte:GetDescendants() do
			merken(x)
			if i % 4000 == 0 then task.wait() end
		end
		karte.DescendantAdded:Connect(merken)
		karte.DescendantRemoving:Connect(function(x) fenster[x] = nil end)
	end)
	local function nurTouch()
		return UIS.TouchEnabled == true and UIS.KeyboardEnabled ~= true
	end
	-- not chosen by the player yet: phones and tablets start in performance mode
	_G.SparmodusAuto = function()
		local e = _G.Einstellungen
		if e and not e.sparmodusGewaehlt then
			e.sparmodus = nurTouch()
		end
		_G.SparmodusSetzen(e and e.sparmodus)
	end
	_G.SparmodusAuto()

	-- frame rate watch: stays below 30 fps for 10 seconds -> performance mode (only if the player didn't choose).
	-- Only counts while the game window has focus: in the background (alt-tab, Studio behind another app)
	-- the frame rate drops on purpose and says nothing about the device.
	local bilder, langsam = 0, 0
	local imFokus, fokusGewechselt = true, false
	UIS.WindowFocusReleased:Connect(function() imFokus, fokusGewechselt = false, true end)
	UIS.WindowFocused:Connect(function() imFokus, fokusGewechselt = true, true end)
	RunService.RenderStepped:Connect(function() bilder += 1 end)
	task.spawn(function()
		while true do
			bilder = 0
			fokusGewechselt = false
			task.wait(5)
			local fps = bilder / 5
			local e = _G.Einstellungen
			if not imFokus or fokusGewechselt then
				langsam = 0
			elseif _G.ImSpiel and e and not e.sparmodusGewaehlt and not e.sparmodus then
				langsam = fps < 30 and langsam + 1 or 0
				if langsam >= 2 then
					e.sparmodus = true
					_G.SparmodusSetzen(true)
					warnen("⚡ Performance mode switched on (Settings → Graphics)", Color3.fromRGB(40, 150, 70))
				end
			end
		end
	end)

	-- street lamps: light only at night and near the camera (hundreds of lights cost a lot)
	local lampen = {}
	task.spawn(function()
		-- never block the rest of the client: with streaming the map may arrive late
		local karte = workspace:WaitForChild("Karte", 60)
		if not karte then return end
		local function merken(x)
			if x:IsA("PointLight") and x.Parent and x.Parent.Name == "Leuchte" then lampen[x] = true end
		end
		for i, x in karte:GetDescendants() do
			merken(x)
			if i % 4000 == 0 then task.wait() end
		end
		karte.DescendantAdded:Connect(merken)
		karte.DescendantRemoving:Connect(function(x) lampen[x] = nil end)
	end)
	task.spawn(function()
		while true do
			local zeit = ordner:GetAttribute("Uhrzeit") or 12
			local nacht = zeit < 6.8 or zeit > 18.2 or ordner:GetAttribute("Wetter") == "Fog"
			local kam = workspace.CurrentCamera
			local auge = kam and kam.CFrame and kam.CFrame.Position or Vector3.zero
			local reichweite = _G.Sparmodus and 150 or 420
			for licht in lampen do
				local teil = licht.Parent
				if teil and teil:IsA("BasePart") then
					local an = nacht and Vector3.new(teil.Position.X - auge.X, 0, teil.Position.Z - auge.Z).Magnitude < reichweite
					if licht.Enabled ~= an then licht.Enabled = an end
				end
			end
			task.wait(1.5)
		end
	end)

	-- big fixed-size windows: scale down on small screens (phones in landscape are only ~350 px high)
	local function einpassen(panel)
		if not panel:IsA("GuiObject") or panel.AnchorPoint ~= Vector2.new(0.5, 0.5) then return end
		if panel.Size.X.Scale ~= 0 or panel.Size.Y.Scale ~= 0 or panel.Size.Y.Offset < 200 then return end
		for _, k in panel:GetChildren() do
			if k:IsA("UIScale") and k.Name ~= "Einpassen" then return end -- has its own pop animation
		end
		local kam = workspace.CurrentCamera
		local vp = kam and kam.ViewportSize
		if not vp or vp.X < 10 then return end
		local okInset, oben = pcall(function() return GuiService:GetGuiInset() end)
		local obenY = (okInset and oben and oben.Y) or 36
		local faktor = math.min(1, (vp.X - 20) / panel.Size.X.Offset, (vp.Y - obenY - 16) / panel.Size.Y.Offset)
		local s = panel:FindFirstChild("Einpassen")
		if faktor >= 0.999 then
			if s then s:Destroy() end
			return
		end
		s = s or Instance.new("UIScale")
		s.Name = "Einpassen"
		s.Scale = math.max(0.45, faktor)
		s.Parent = panel
	end
	local function guiPruefen(g)
		if not g:IsA("ScreenGui") then return end
		for _, k in g:GetChildren() do einpassen(k) end
		g.ChildAdded:Connect(function(k) task.defer(einpassen, k) end)
	end
	local pg = spieler:WaitForChild("PlayerGui")
	for _, g in pg:GetChildren() do guiPruefen(g) end
	pg.ChildAdded:Connect(function(g) task.defer(guiPruefen, g) end)
	local kam = workspace.CurrentCamera
	if kam then
		kam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			for _, g in pg:GetChildren() do
				if g:IsA("ScreenGui") then
					for _, k in g:GetChildren() do einpassen(k) end
				end
			end
		end)
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
			Motorsound.verkehr(Verkehr.anzeigen(r.liste, event))
			return
		end
		task.wait(2)
	end
	warn("[Driving School] NPC traffic not available")
end)

-- ---------------------------------------------------------------
-- 🏁 Party test: up to 4 friends drive the same route, first to park wins
-- ---------------------------------------------------------------
do
	local partyKnopf = leistenKnopf("🏁", "Party", 8, Color3.fromRGB(200, 90, 30))
	partyKnopf.MouseButton1Click:Connect(function()
		local r = frage("partyBeitreten")
		if r and (r.fehler or r.text) then warnen(r.fehler or r.text, r.fehler and Color3.fromRGB(200, 140, 30) or GRUEN) end
	end)
	_G.PartyEvent = function(info)
		if info.phase == "ergebnis" then
			local zeilen = {}
			local medaille = { "🥇", "🥈", "🥉", "4." }
			for _, e in info.liste or {} do
				local zeit = e.zeit and ("%.1f s"):format(e.zeit) or "did not finish"
				table.insert(zeilen, ("%s  <b>%s</b>  –  %s%s"):format(medaille[e.platz] or (e.platz .. "."), e.name, zeit,
					(e.preis or 0) > 0 and ("   <font color=\"#ffd23c\">+%d 🪙</font>"):format(e.preis) or ""))
			end
			zeige("🏁 PARTY TEST RESULTS", table.concat(zeilen, "\n") .. "\n\n<font size=\"14\" color=\"#9aa4b5\">Time + 5 s per mistake. Press 🏁 Party for a rematch!</font>", {
				{ text = "Close", farbe = GRUEN, klick = schliessen },
			}, "hinweis")
		else
			chaosBanner({ titel = info.titel, text = info.text, farbe = (info.phase == "abbruch") and "rot" or (info.phase == "sieger" and "gelb" or "gruen") })
		end
	end
end

-- ---------------------------------------------------------------
-- Settings (saved on the server) and the start screen
-- ---------------------------------------------------------------
_G.Einstellungen = { minimap = true, mph = false, grosseAnzeige = false, ersteP = false, sparmodus = false, sparmodusGewaehlt = false, chaosAus = false, hupe = "normal" }
_G.SparmodusAuto() -- phones / tablets: performance mode until the saved settings say otherwise

local function einstellungenAnwenden()
	local e = _G.Einstellungen
	if _G.SparmodusSetzen then _G.SparmodusSetzen(e.sparmodus) end
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
einstellRahmen.Size = UDim2.fromOffset(380, 534)
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
	{ "sparmodus", "Graphics", "⚡ Fast", "Best" },
	{ "chaosAus", "Chaos in your own car", "Off", "On" }, -- lessons always have chaos
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
		if o[1] == "sparmodus" then _G.Einstellungen.sparmodusGewaehlt = true end
		for schl, ok in optionKnoepfe do
			local wert = _G.Einstellungen[schl]
			ok.knopf.Text = wert and ok.an or ok.aus
			ok.knopf.BackgroundColor3 = wert and GRUEN or GRAU
		end
		einstellungenAnwenden()
		task.spawn(frage, "einstellungen", _G.Einstellungen)
	end)
end
-- 📯 horn choice: cycles through the horns you own (Funny Horn Pack unlocks the crazy ones)
local hupZeile = Instance.new("TextLabel")
hupZeile.Position = UDim2.fromOffset(20, 56 + #OPTIONEN * 50)
hupZeile.Size = UDim2.fromOffset(200, 40)
hupZeile.BackgroundTransparency = 1
hupZeile.Font = Enum.Font.GothamBold
hupZeile.TextSize = 16
hupZeile.TextColor3 = Color3.fromRGB(220, 225, 235)
hupZeile.TextXAlignment = Enum.TextXAlignment.Left
hupZeile.Text = "Horn (H)"
hupZeile.Parent = einstellRahmen
local hupKnopf = Instance.new("TextButton")
hupKnopf.Position = UDim2.fromOffset(230, 60 + #OPTIONEN * 50)
hupKnopf.Size = UDim2.fromOffset(130, 32)
hupKnopf.Font = Enum.Font.GothamBold
hupKnopf.TextSize = 15
hupKnopf.TextColor3 = Color3.new(1, 1, 1)
hupKnopf.BackgroundColor3 = Color3.fromRGB(240, 120, 40)
hupKnopf.Parent = einstellRahmen
Instance.new("UICorner", hupKnopf)
local function hupKnopfText()
	hupKnopf.Text = "📯 " .. hupeDef(_G.Einstellungen.hupe).name
end
hupKnopf.MouseButton1Click:Connect(function()
	local frei = {}
	for _, h in Hupen do
		if not h.pass or spieler:GetAttribute("HupenPack") then table.insert(frei, h) end
	end
	if #frei <= 1 then
		warnen("📯 Get the Funny Horn Pack in the 🛒 Shop: clown, duck, air horn and fanfare!", Color3.fromRGB(200, 140, 30))
		return
	end
	local i = 1
	for k, h in frei do
		if h.key == _G.Einstellungen.hupe then i = k end
	end
	local neu = frei[i % #frei + 1]
	_G.Einstellungen.hupe = neu.key
	hupKnopfText()
	local hrp = spieler.Character and spieler.Character:FindFirstChild("HumanoidRootPart")
	hupeAbspielen(hrp, neu) -- preview
	task.spawn(frage, "einstellungen", _G.Einstellungen)
end)
-- 🎟️ promo codes (v54): checked on the server, each code once per player
local codeFeld = Instance.new("TextBox")
codeFeld.Position = UDim2.fromOffset(20, 60 + (#OPTIONEN + 1) * 50)
codeFeld.Size = UDim2.fromOffset(200, 32)
codeFeld.BackgroundColor3 = Color3.fromRGB(45, 52, 66)
codeFeld.Font = Enum.Font.GothamBold
codeFeld.TextSize = 15
codeFeld.TextColor3 = Color3.new(1, 1, 1)
codeFeld.PlaceholderText = "🎟️ Enter code"
codeFeld.PlaceholderColor3 = Color3.fromRGB(150, 158, 175)
codeFeld.Text = ""
codeFeld.ClearTextOnFocus = false
codeFeld.Parent = einstellRahmen
Instance.new("UICorner", codeFeld)
local codeKnopf = Instance.new("TextButton")
codeKnopf.Position = UDim2.fromOffset(230, 60 + (#OPTIONEN + 1) * 50)
codeKnopf.Size = UDim2.fromOffset(130, 32)
codeKnopf.Font = Enum.Font.GothamBold
codeKnopf.TextSize = 15
codeKnopf.TextColor3 = Color3.new(1, 1, 1)
codeKnopf.BackgroundColor3 = GRUEN
codeKnopf.Text = "Redeem"
codeKnopf.Parent = einstellRahmen
Instance.new("UICorner", codeKnopf)
codeKnopf.MouseButton1Click:Connect(function()
	local text = codeFeld.Text
	if text == "" then return end
	local r = frage("code", text)
	if r.fehler then
		warnen("🎟️ " .. r.fehler, Color3.fromRGB(200, 140, 30))
	else
		codeFeld.Text = ""
		warnen("🎟️ " .. (r.text or "Code redeemed!"), GRUEN)
	end
end)
local function knoepfeAktualisieren()
	for schl, ok in optionKnoepfe do
		local wert = _G.Einstellungen[schl]
		ok.knopf.Text = wert and ok.an or ok.aus
		ok.knopf.BackgroundColor3 = wert and GRUEN or GRAU
	end
	hupKnopfText()
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
local zahnrad = leistenKnopf("⚙️", "Settings", 7)
zahnrad.MouseButton1Click:Connect(function()
	knoepfeAktualisieren()
	einstellGui.Enabled = true
end)

-- "My Cars": get one of your bought cars to the nearest parking spot
do
	local autoKnopf = leistenKnopf("🚗", "My Cars", 4)

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
				zeile.Text = einh(("   %s  ·  %d km/h  ·  %.1f km driven     ▶ Get it"):format(a.name, a.tempo, (r.km and r.km[a.typ]) or 0))
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
		table.insert(zeilen, "📨 New friend joins via invite: <b>+750</b> for both")
		table.insert(zeilen, ((spieler:GetAttribute("BoostBis") or 0) > os.time() and ("⚡ 2x boost: %d min left"):format(math.ceil(((spieler:GetAttribute("BoostBis") or 0) - os.time()) / 60)) or "⚡ 2x boost: <font color=\"#8a90a0\">off</font>"))
		label(k3, table.concat(zeilen, "\n"), 13, nil, { 0, 12 }, { 0, 8 }, { 0.6, -12 }, { 1, -16 }, true)
		label(k3, ("Coins  <b>x%.1f</b>\nXP  <b>x%.1f</b>"):format(spieler:GetAttribute("GeldFaktor") or 1, spieler:GetAttribute("XpFaktor") or 1), 16, GOLD, { 0.6, 0 }, { 0, 8 }, { 0.4, -12 }, { 0, 44 }, 2, Enum.TextXAlignment.Right)
		taste(k3, "📨 INVITE FRIENDS", BLAU, { 0.6, 0 }, { 0, 56 }, { 0.4, -12 }, { 0, 32 }, function()
			if _G.FreundeEinladen then _G.FreundeEinladen() end
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
		ueberschrift(liste, "🤪 CHAOS FUN – for the whole server", weiter())
		for _, pr in info.produkte do
			if pr.spass then
				local k = karte(liste, 72, Color3.fromRGB(70, 40, 95), weiter())
				label(k, pr.name .. (pr.tag and ("   <font color=\"#ffcf4a\" size=\"12\">" .. pr.tag .. "</font>") or ""), 16, nil, { 0, 14 }, { 0, 6 }, { 1, -170 }, { 0, 24 }, true)
				label(k, pr.text or "", 12, HELL, { 0, 14 }, { 0, 32 }, { 1, -170 }, { 0, 34 })
				taste(k, preisText(pr), GRUEN, { 1, -146 }, { 0.5, -18 }, { 0, 134 }, { 0, 36 }, function() kaufen("produkt", pr) end)
			end
		end
		ueberschrift(liste, "🪙 COINS & BOOSTS", weiter())
		for _, pr in info.produkte do
			if not pr.einmal and not pr.spass then
				local k = karte(liste, 56, nil, weiter())
				label(k, (pr.spass and "" or pr.geld and "🪙 " or "⚡ ") .. pr.name .. (pr.tag and ("   <font color=\"#ffcf4a\" size=\"12\">" .. pr.tag .. "</font>") or ""), 16, nil, { 0, 14 }, { 0, 0 }, { 1, -170 }, { 1, 0 }, true)
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
	local bKnopf = leistenKnopf("🎁", "Rewards", 2)
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
	local sKnopf = leistenKnopf("🛒", "Shop", 1, Color3.fromRGB(110, 60, 200))
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
		end
	end)
	-- daily reward waiting: open the rewards window once the player is in the game (after PLAY)
	task.spawn(function()
		while not _G.ImSpiel do task.wait(0.5) end
		task.wait(2)
		-- brand-new players first drive (the rewards wait in the menu, red dot)
		local st = frage("status")
		if st.status and (not st.status.angemeldet or st.lektionLaeuft) then return end
		local r = frage("belohnungen")
		if r.taeglich and r.taeglich.bereit and not spieler.PlayerGui:FindFirstChild("Belohnungen") then
			belohnungZeigen(r)
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

	-- everything is stacked from the middle of the screen with fixed gaps, so nothing overlaps on low screens (phones)
	local function label(t, y, groesse, schrift, farbe)
		local l = Instance.new("TextLabel")
		l.Position = UDim2.new(0.07, 0, 0.5, y)
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
	local titel = label("CRAZY DRIVING SCHOOL 🍌", -150, 54, Enum.Font.GothamBlack, Color3.new(1, 1, 1))
	titel.TextScaled = true -- long name: shrinks on small screens instead of running off
	local maxTitel = Instance.new("UITextSizeConstraint")
	maxTitel.MaxTextSize = 54
	maxTitel.Parent = titel
	label("Get your license. Survive the chaos.", -86, 22, Enum.Font.GothamMedium, Color3.fromRGB(255, 215, 80))
	-- test phase: small BETA badge (set SPIEL_PHASE = nil when the game is finished)
	local SPIEL_PHASE = "BETA"
	if SPIEL_PHASE then
		local b = Instance.new("TextLabel")
		b.AnchorPoint = Vector2.new(0, 1)
		b.Position = UDim2.new(0.07, 0, 0.5, -152)
		b.Size = UDim2.fromOffset(64, 22)
		b.BackgroundColor3 = Color3.fromRGB(220, 40, 60)
		b.Font = Enum.Font.GothamBlack
		b.TextSize = 14
		b.TextColor3 = Color3.new(1, 1, 1)
		b.Text = SPIEL_PHASE
		b.Parent = menue
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
	end

	local function grosserKnopf(t, y, farbe)
		local k = Instance.new("TextButton")
		k.Position = UDim2.new(0.07, 0, 0.5, y)
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
	local spielen = grosserKnopf("PLAY", -30, GRUEN)
	local einst = grosserKnopf("SETTINGS", 38, Color3.fromRGB(60, 70, 90))

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

		-- brand-new player: no reading first – the first (short) lesson starts right away
		task.spawn(function()
			local r = frageGeladen("status")
			if r.fehler or not r.status or r.status.angemeldet or r.status.fahrstunden > 0 or r.lektionLaeuft then return end
			local a = frage("ersteFahrt")
			if a.fehler then return end
			zeige("Welcome to Crazy Driving School! 🍌", "Let's drive right away!\n\nYour (slightly crazy) instructor is waiting in the car on the parking lot right in front of you. Walk to the <b>driver's door</b> and press <b>E</b> (on a phone: tap the button) to get in.\n\n<font size=\"15\" color=\"#9aa4b5\">No theory needed – Anna at the reception shows you every step.</font>", {
				{ text = "Let's go!", farbe = GRUEN, klick = schliessen },
			}, "dialog")
		end)
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

	-- load the saved settings (v51: wait for the save game – otherwise saved settings were lost)
	task.spawn(function()
		local r = frageGeladen("status")
		if r.status and type(r.status.einstellungen) == "table" then
			for k, v in r.status.einstellungen do
				if _G.Einstellungen[k] ~= nil and type(v) == type(_G.Einstellungen[k]) then _G.Einstellungen[k] = v end
			end
		end
		if _G.SparmodusAuto then _G.SparmodusAuto() end
		knoepfeAktualisieren()
	end)
	print("[Driving School] start screen ready")
end
