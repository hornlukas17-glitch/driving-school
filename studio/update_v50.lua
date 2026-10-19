-- v49 -> v50 (Theorie optional). In Studio im EDIT-Modus (nicht Play) in die Befehlszeile einfügen und Enter.
-- Prüft den Ausgangsstand; bricht ab, wenn etwas nicht passt.
do
local function ersetze(src, alt, neu)
	local a, b = string.find(src, alt, 1, true)
	assert(a, "nicht gefunden: " .. alt:sub(1, 60))
	assert(not string.find(src, alt, b + 1, true), "mehrfach: " .. alt:sub(1, 60))
	return src:sub(1, a - 1) .. neu .. src:sub(b + 1)
end
local s = game.ServerScriptService.FuehrerscheinServer
local src = s.Source
assert(#src == 136613, "Ausgangsstand passt nicht: " .. #src)
src = ersetze(src, [===[
			if d.fahrstunden < #LEKTIONEN then
				weiter = d.theorie and "Talk to Anna for your next lesson." or "Next: your next lesson with Anna – or the theory lesson at the whiteboard in the classroom."
			elseif not d.theorie then
				weiter = "All lessons done! Now the theory: whiteboard in the classroom, then the test at an exam desk."
			elseif not d.fuehrerschein then
]===], [===[
			if d.fahrstunden < #LEKTIONEN then
				weiter = "Talk to Anna for your next lesson."
			elseif not d.fuehrerschein then
]===])
src = ersetze(src, [===[
	end
	-- v31: drive first, theory later. Lessons are open right away; the theory test is needed for the driving test.
	if not d then
]===], [===[
	end
	-- v50: the theory is optional (bonus XP). The car driving test needs all driving lessons (checked here on the server).
	if not d then
]===])
src = ersetze(src, [===[
	end
	if pruefung and not d.theorie then
		return { fehler = "You need to pass the theory test first: theory lesson at the whiteboard, then the test at an exam desk (classroom)." }
	end
]===], [===[
	end
	if pruefung and not lkw and not d.fuehrerschein and not d.entzogen and d.fahrstunden < #LEKTIONEN then
		return { fehler = ("Finish all driving lessons first (%d/%d) – talk to Anna at the reception."):format(d.fahrstunden, #LEKTIONEN) }
	end
]===])
assert(#src == 136434, "Ergebnis-Länge falsch: " .. #src)
s.Source = src
print(s.Name .. ": " .. #src .. " Zeichen")
end
do
local function ersetze(src, alt, neu)
	local a, b = string.find(src, alt, 1, true)
	assert(a, "nicht gefunden: " .. alt:sub(1, 60))
	assert(not string.find(src, alt, b + 1, true), "mehrfach: " .. alt:sub(1, 60))
	return src:sub(1, a - 1) .. neu .. src:sub(b + 1)
end
local s = game.StarterPlayer.StarterPlayerScripts.FuehrerscheinClient
local src = s.Source
assert(#src == 189810, "Ausgangsstand passt nicht: " .. #src)
src = ersetze(src, [===[
local spieler = Players.LocalPlayer
print("[Driving School] client v48 loaded")
local ordner = RS:WaitForChild("Fuehrerschein")
]===], [===[
local spieler = Players.LocalPlayer
print("[Driving School] client v50 loaded")
local ordner = RS:WaitForChild("Fuehrerschein")
]===])
src = ersetze(src, [===[
		zeile(s.fahrstunden >= r.anzahlLektionen, ("Driving lessons (%d/%d)"):format(s.fahrstunden, r.anzahlLektionen)),
		zeile(s.unterricht, "Theory lesson"),
		zeile(s.theorie, "Theory test"),
		zeile(s.fuehrerschein, "Practical driving test"),
		zeile(s.lkwFuehrerschein, "Truck license (optional)"),
]===], [===[
		zeile(s.fahrstunden >= r.anzahlLektionen, ("Driving lessons (%d/%d)"):format(s.fahrstunden, r.anzahlLektionen)),
		zeile(s.fuehrerschein, "Driving test"),
		zeile(s.theorie, "Theory test (optional, bonus XP)"),
		zeile(s.lkwFuehrerschein, "Truck license (optional)"),
]===])
src = ersetze(src, [===[
		{ s.fahrstunden >= n, ("Driving lessons (%d/%d)  ⭐ %d/%d"):format(math.min(s.fahrstunden, n), n, summe, n * 3) },
		{ s.unterricht, "Theory lesson at the <b>whiteboard</b> (classroom)" },
		{ s.theorie, "Theory test at an <b>exam desk</b> (17 of 20 correct)" },
		{ s.fuehrerschein, "Practical driving test (max 3 mistakes)" },
	}) .. "\n\n"
	local knoepfe = {}
]===], [===[
		{ s.fahrstunden >= n, ("Driving lessons (%d/%d)  ⭐ %d/%d"):format(math.min(s.fahrstunden, n), n, summe, n * 3) },
		{ s.fuehrerschein, "Driving test (max 3 mistakes)" },
	}) .. (s.theorie and "" or "\n<font size=\"15\" color=\"#9aa4b5\">Optional: theory test in the classroom for bonus XP.</font>") .. "\n\n"
	local knoepfe = {}
]===])
src = ersetze(src, [===[
		text = r.naechste and ("Next lesson: <b>%s</b>\nYour instructor is waiting in the car on the parking lot. Who will it be this time?"):format(r.naechste) or ""
		if not s.unterricht then text ..= "\n<font size=\"15\" color=\"#9aa4b5\">You can do the theory (classroom) any time in between.</font>" end
		lektionKnopf()
]===], [===[
		text = r.naechste and ("Next lesson: <b>%s</b>\nYour instructor is waiting in the car on the parking lot. Who will it be this time?"):format(r.naechste) or ""
		lektionKnopf()
]===])
src = ersetze(src, [===[
		lektionKnopf()
	elseif not s.unterricht then
		text = "All lessons done – great! Now the theory: go into the classroom on the left and press E at the <b>whiteboard</b>."
	elseif not s.theorie then
		text = "Next: sit down at one of the <b>exam desks</b> in the classroom to start your theory test."
	elseif not s.fuehrerschein then
]===], [===[
		lektionKnopf()
	elseif not s.fuehrerschein then
]===])
src = ersetze(src, [===[
		if e.bestanden then
			zeige("Passed! 🎉", ("You answered <b>%d of %d</b> questions correctly (%d %%).\n\nNext step: book your first driving lesson with Anna at the reception."):format(e.punkte, e.gesamt, prozent), {
				{ text = "Close", farbe = GRUEN, klick = schliessen },
]===], [===[
		if e.bestanden then
			zeige("Passed! 🎉", ("You answered <b>%d of %d</b> questions correctly (%d %%).\n\n+80 XP bonus! Talk to Anna at the reception for your next driving lesson."):format(e.punkte, e.gesamt, prozent), {
				{ text = "Close", farbe = GRUEN, klick = schliessen },
]===])
src = ersetze(src, [===[
	if s.theorie then
		hinweis("You have already passed the theory test. Talk to Anna at the reception to book a driving lesson.")
	elseif not s.unterricht then
]===], [===[
	if s.theorie then
		hinweis("You have already passed the theory test. Talk to Anna at the reception for your next driving lesson.")
	elseif not s.unterricht then
]===])
src = ersetze(src, [===[
do
	print("[Driving School] start screen v48 loading")
	local menue = Instance.new("ScreenGui")
]===], [===[
do
	print("[Driving School] start screen v50 loading")
	local menue = Instance.new("ScreenGui")
]===])
src = ersetze(src, [===[
			if a.fehler then return end
			zeige("Welcome to Crazy Driving School! 🍌", "Let's drive right away!\n\nYour (slightly crazy) instructor is waiting in the car on the parking lot right in front of you. Walk to the <b>driver's door</b> and press <b>E</b> (on a phone: tap the button) to get in.\n\n<font size=\"15\" color=\"#9aa4b5\">The theory comes later – Anna at the reception shows you every step.</font>", {
				{ text = "Let's go!", farbe = GRUEN, klick = schliessen },
]===], [===[
			if a.fehler then return end
			zeige("Welcome to Crazy Driving School! 🍌", "Let's drive right away!\n\nYour (slightly crazy) instructor is waiting in the car on the parking lot right in front of you. Walk to the <b>driver's door</b> and press <b>E</b> (on a phone: tap the button) to get in.\n\n<font size=\"15\" color=\"#9aa4b5\">No theory needed – Anna at the reception shows you every step.</font>", {
				{ text = "Let's go!", farbe = GRUEN, klick = schliessen },
]===])
assert(#src == 189322, "Ergebnis-Länge falsch: " .. #src)
s.Source = src
print(s.Name .. ": " .. #src .. " Zeichen")
end
print("v50 eingespielt – jetzt speichern (Strg+S) und veröffentlichen")
