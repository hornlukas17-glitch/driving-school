-- v50 -> v51 (Auto bleibt bei Fehlern, Try again, Minimap). In Studio im EDIT-Modus in die Befehlszeile einfügen und Enter.
do
local function ersetze(src, alt, neu)
	local a, b = string.find(src, alt, 1, true)
	assert(a, "nicht gefunden: " .. alt:sub(1, 60))
	assert(not string.find(src, alt, b + 1, true), "mehrfach: " .. alt:sub(1, 60))
	return src:sub(1, a - 1) .. neu .. src:sub(b + 1)
end
local s = game.ServerScriptService.FuehrerscheinServer
local src = s.Source
assert(#src == 136434, "Ausgangsstand passt nicht: " .. #src)
src = ersetze(src, [===[

local function lektionBeenden(p, erfolg, text)
]===], [===[

-- v51: after a failed lesson the car does NOT vanish under you: it stays until you get out
-- (or 45 s, or you start the next lesson / leave the game). "Try again" restarts the same lesson.
local restAutos = {}     -- [player] = car of the finished lesson that is still standing there
local letzteLektion = {} -- [player] = { art = "pruefung"/"lkw"/"lektion"/"wiederholen", nr = n }
local function restAutoWeg(p)
	local m = restAutos[p]
	restAutos[p] = nil
	if m and m.Parent then m:Destroy() end
end

local function lektionBeenden(p, erfolg, text)
]===])
src = ersetze(src, [===[
	lektionen[p] = nil
	Chaos.reaktion(p, st, erfolg and "ende_gut" or "ende_schlecht")
]===], [===[
	lektionen[p] = nil
	-- v51: normal lessons are never stopped by mistakes; with too many the finished route just does not count
	if erfolg and not st.pruefung and not st.party and st.fehler > st.erlaubt then
		erfolg = false
		text = ("You finished the route, but with %d mistakes (max. %d) this lesson does not count. Try again!"):format(st.fehler, st.erlaubt)
		xpGeben(p, 10, "Route finished")
	end
	Chaos.reaktion(p, st, erfolg and "ende_gut" or "ende_schlecht")
]===])
src = ersetze(src, [===[
	end
	local warten = 1
	if erfolg then warten = st.pruefung and 13 or 4 end
	task.delay(warten, function()
		aussteigen(st.sitz)
		if st.model then st.model:Destroy() end
	end)
]===], [===[
	end
	if erfolg then
		task.delay(st.pruefung and 13 or 4, function()
			aussteigen(st.sitz)
			if st.model then st.model:Destroy() end
		end)
		return
	end
	-- failed: keep the car while the player still sits in it
	local m = st.model
	if not (m and m.Parent) then return end
	local hum = st.sitz and st.sitz.Occupant
	if not hum or not p.Parent then
		task.delay(1, function() if m.Parent then m:Destroy() end end)
		return
	end
	restAutoWeg(p)
	restAutos[p] = m
	st.sitz:GetPropertyChangedSignal("Occupant"):Connect(function()
		if not st.sitz.Occupant and restAutos[p] == m then
			task.delay(3, function() if restAutos[p] == m then restAutoWeg(p) end end)
		end
	end)
]===])
src = ersetze(src, [===[
		end
	end)
end

]===], [===[
		end
	end)
	task.delay(45, function() if restAutos[p] == m then restAutoWeg(p) end end)
end

]===])
src = ersetze(src, [===[
		if st.pruefung then
			lektionBeenden(p, false, ("You made %d mistakes, but only %d are allowed. You failed the driving test. Talk to Anna to try again."):format(st.fehler, st.erlaubt))
		else
			lektionBeenden(p, false, ("You made %d mistakes, so this lesson does not count. Talk to Anna at the reception and try it again."):format(st.fehler))
		end
]===], [===[
		if st.pruefung then
			lektionBeenden(p, false, ("You made %d mistakes, but only %d are allowed. You failed the driving test – try again!"):format(st.fehler, st.erlaubt))
		elseif not st.party and not st.zuVieleGesagt then
			-- v51: no stop in normal lessons – just say it once, the route goes on
			st.zuVieleGesagt = true
			fahrEvent:FireClient(p, { typ = "hinweis", text = ("%d mistakes – this lesson won't count any more. Finish the route anyway, then try again!"):format(st.fehler) })
		end
]===])
src = ersetze(src, [===[
	end
	-- v50: the theory is optional (bonus XP). The car driving test needs all driving lessons (checked here on the server).
]===], [===[
	end
	restAutoWeg(p)
	-- v50: the theory is optional (bonus XP). The car driving test needs all driving lessons (checked here on the server).
]===])
src = ersetze(src, [===[
	lektionen[p] = st

]===], [===[
	lektionen[p] = st
	letzteLektion[p] = { art = art or "lektion", nr = art == "wiederholen" and wiederholNr or nil }

]===])
src = ersetze(src, [===[

	elseif was == "ersteFahrt" then
]===], [===[

	elseif was == "nochmal" then
		-- v51: "Try again" in the result window: the same lesson / test again
		local l = letzteLektion[p]
		if not l or l.art == "party" then return { fehler = "Talk to Anna at the reception." } end
		if l.art == "wiederholen" then return lektionStarten(p, "wiederholen", l.nr) end
		if l.art == "pruefung" or l.art == "lkw" then return lektionStarten(p, l.art) end
		return lektionStarten(p)

	elseif was == "ersteFahrt" then
]===])
src = ersetze(src, [===[
	lektionen[p] = nil
	local job = jobs[p]
]===], [===[
	lektionen[p] = nil
	restAutoWeg(p)
	letzteLektion[p] = nil
	local job = jobs[p]
]===])
assert(#src == 138618, "Ergebnis-Länge falsch: " .. #src)
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
assert(#src == 189322, "Ausgangsstand passt nicht: " .. #src)
src = ersetze(src, [===[
local spieler = Players.LocalPlayer
print("[Driving School] client v50 loaded")
local ordner = RS:WaitForChild("Fuehrerschein")
]===], [===[
local spieler = Players.LocalPlayer
print("[Driving School] client v51 loaded")
local ordner = RS:WaitForChild("Fuehrerschein")
]===])
src = ersetze(src, [===[
		return { fehler = "Could not reach the server." }
	end
]===], [===[
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
]===])
src = ersetze(src, [===[
		end
		zeige(titelText, info.text .. ("\n\nMistakes: %d"):format(info.fehler or 0) .. sterneText .. (info.erfolg and ("\n\n" .. (info.weiter or "Talk to Anna at the reception for your next lesson.")) or ""), {
			{ text = "Close", farbe = info.erfolg and GRUEN or GRAU, klick = schliessen },
		}, "hinweis")
	end
]===], [===[
		end
		local knoepfe = { { text = "Close", farbe = info.erfolg and GRUEN or GRAU, klick = schliessen } }
		if not info.erfolg then
			-- v51: start the same lesson / test again right away (new car on the parking lot)
			table.insert(knoepfe, 1, { text = "🔁 Try again", farbe = GRUEN, klick = function()
				local a = frage("nochmal")
				if a.fehler then hinweis(a.fehler) else zeige("Try again", a.text, { { text = "Let's go!", farbe = GRUEN, klick = schliessen } }, "dialog") end
			end })
		end
		zeige(titelText, info.text .. ("\n\nMistakes: %d"):format(info.fehler or 0) .. sterneText .. (info.erfolg and ("\n\n" .. (info.weiter or "Talk to Anna at the reception for your next lesson.")) or ""), knoepfe, "hinweis")
	end
]===])
src = ersetze(src, [===[
	task.spawn(function()
		local r = frage("kartendaten")
		if not r.daten then return end
		for _, e in r.daten do
]===], [===[
	task.spawn(function()
		-- v51: wait until the save game is loaded (the server answers "still loading" before)
		local r = frageGeladen("kartendaten")
		if not r.daten then warn("[Driving School] minimap: no map data") return end
		for _, e in r.daten do
]===])
src = ersetze(src, [===[
do
	print("[Driving School] start screen v50 loading")
	local menue = Instance.new("ScreenGui")
]===], [===[
do
	print("[Driving School] start screen v51 loading")
	local menue = Instance.new("ScreenGui")
]===])
src = ersetze(src, [===[
		task.spawn(function()
			local r = frage("status")
			if r.fehler or not r.status or r.status.angemeldet or r.status.fahrstunden > 0 or r.lektionLaeuft then return end
]===], [===[
		task.spawn(function()
			local r = frageGeladen("status")
			if r.fehler or not r.status or r.status.angemeldet or r.status.fahrstunden > 0 or r.lektionLaeuft then return end
]===])
src = ersetze(src, [===[

	-- load the saved settings
	task.spawn(function()
]===], [===[

	-- load the saved settings (v51: wait for the save game – otherwise saved settings were lost)
	task.spawn(function()
]===])
src = ersetze(src, [===[
	task.spawn(function()
		local r = frage("status")
		if r.status and type(r.status.einstellungen) == "table" then
]===], [===[
	task.spawn(function()
		local r = frageGeladen("status")
		if r.status and type(r.status.einstellungen) == "table" then
]===])
assert(#src == 190443, "Ergebnis-Länge falsch: " .. #src)
s.Source = src
print(s.Name .. ": " .. #src .. " Zeichen")
end
print("v51 eingespielt – jetzt speichern (Strg+S) und veröffentlichen")
