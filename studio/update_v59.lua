-- v58/v59 -> v59: Fahrschulauto verschwindet nicht mehr (Server), 2 Gags mehr je Fahrlehrer (Chaos), Versionsstrings.
-- Voraussetzung: Studio-Server = v58 (Startzonen). Im EDIT-Modus in die Befehlszeile oder per MCP.
do
local function ersetze(src, alt, neu)
	local a, b = string.find(src, alt, 1, true)
	assert(a, "nicht gefunden: " .. alt:sub(1, 60))
	assert(not string.find(src, alt, b + 1, true), "mehrfach: " .. alt:sub(1, 60))
	return src:sub(1, a - 1) .. neu .. src:sub(b + 1)
end
local s = game.ServerScriptService.FuehrerscheinServer
local src = s.Source
assert(#src == 150068, "Ausgangsstand passt nicht: " .. #src)
src = ersetze(src, [===[
		if a.chassis and a.chassis.Parent and (a.chassis.Position - b.Position).Magnitude < 8 then return false end
	end
	return true
end
]===], [===[
		if a.chassis and a.chassis.Parent and (a.chassis.Position - b.Position).Magnitude < 8 then return false end
	end
	-- v59: cars of failed lessons stay up to 45 s – never spawn a new car into them (it would be flung away)
	for _, m in restAutos do
		if m.Parent and (m:GetPivot().Position - b.Position).Magnitude < 8 then return false end
	end
	return true
end
]===])
src = ersetze(src, [===[
	end
	local b = buchtOrdner:GetChildren()[1]
	return CFrame.new(b.Position.X, b.Position.Y + 0.25, b.Position.Z - 1)
end
]===], [===[
	end
	return nil -- v59: all bays taken (before: first bay anyway -> two cars inside each other)
end
]===])
src = ersetze(src, [===[
		cf = freierStart()
		modell, sitz, beifahrer, chassis, ruecksitz = Auto.bauen(cf, AUTOFARBEN[math.random(#AUTOFARBEN)])
]===], [===[
		cf = freierStart()
		if not cf then
			return { fehler = "All driving school cars are out right now. Please try again in a moment." }
		end
		modell, sitz, beifahrer, chassis, ruecksitz = Auto.bauen(cf, AUTOFARBEN[math.random(#AUTOFARBEN)])
]===])
src = ersetze(src, [===[
	for p, st in lektionen do
		if not p.Parent or not st.model.Parent then
			lektionen[p] = nil
]===], [===[
	for p, st in lektionen do
		-- v59: the car is gone or fell off the map -> tell the player instead of ending silently (+ analytics)
		local weg = not st.model.Parent or not st.chassis or not st.chassis.Parent
		local gefallen = not weg and st.chassis.Position.Y < -60
		if not p.Parent or weg or gefallen then
			lektionen[p] = nil
]===])
src = ersetze(src, [===[
			if st.model then st.model:Destroy() end
			continue
]===], [===[
			if st.model then st.model:Destroy() end
			if st.party then Party.fertig(p, st, false) end -- the race must not wait for this car
			if p.Parent then
				local grund = gefallen and "fell" or "gone"
				Beta.ereignis(p, "Lesson car lost (" .. grund .. ")")
				fahrEvent:FireClient(p, { typ = "ende", erfolg = false, fehler = st.fehler, nr = st.nr, gesamt = #LEKTIONEN, pruefung = st.pruefung,
					text = "Oops – your car got lost! Nothing counts against you. Tap \"Try again\" for a new car." })
			end
			continue
]===])
assert(#src == 151104, "Ergebnis-Länge falsch: " .. #src)
s.Source = src
print(s.Name .. ': ' .. #src .. ' Zeichen')
end
do
local function ersetze(src, alt, neu)
	local a, b = string.find(src, alt, 1, true)
	assert(a, "nicht gefunden: " .. alt:sub(1, 60))
	assert(not string.find(src, alt, b + 1, true), "mehrfach: " .. alt:sub(1, 60))
	return src:sub(1, a - 1) .. neu .. src:sub(b + 1)
end
local s = game.ServerScriptService.FuehrerscheinServer.Chaos
local src = s.Source
assert(#src == 51726, "Ausgangsstand passt nicht: " .. #src)
src = ersetze(src, [===[
			{ titel = "📞 CALLING MOM", text = "Panic Pete is calling his mom to say goodbye.", sagt = "Mom? I love you. Tell the cat too." },
		},
]===], [===[
			{ titel = "📞 CALLING MOM", text = "Panic Pete is calling his mom to say goodbye.", sagt = "Mom? I love you. Tell the cat too." },
			{ titel = "🧯 FIRE DRILL", text = "Panic Pete is practising with a fire extinguisher. There is no fire.", sagt = "THERE COULD BE A FIRE! ANY SECOND!" },
			{ titel = "🗺️ ESCAPE PLAN", text = "Panic Pete drew an escape plan for the car. It has 14 exits.", sagt = "Exit 7 is the sunroof. Memorize it!" },
		},
]===])
src = ersetze(src, [===[
			{ titel = "🛏️ PILLOW FORT", text = "Sleepy Sam pulled a pillow out of nowhere.", sagt = "Always prepared... for a nap..." },
		},
]===], [===[
			{ titel = "🛏️ PILLOW FORT", text = "Sleepy Sam pulled a pillow out of nowhere.", sagt = "Always prepared... for a nap..." },
			{ titel = "🧸 TEDDY TIME", text = "Sleepy Sam is hugging a teddy bear and sucking his thumb.", sagt = "Mr. Fluffles says you drive nice... Zzz" },
			{ titel = "⏰ ALARM CLOCK", text = "Sleepy Sam's alarm clock goes off. He throws it out of the window.", sagt = "Not today, Satan... I mean, alarm..." },
		},
]===])
src = ersetze(src, [===[
			{ titel = "📸 FAMILY PHOTOS", text = "Grandma Gerti is showing you 300 photos of her cat.", sagt = "And this is Mr. Whiskers in 1998. Isn't he cute?" },
		},
]===], [===[
			{ titel = "📸 FAMILY PHOTOS", text = "Grandma Gerti is showing you 300 photos of her cat.", sagt = "And this is Mr. Whiskers in 1998. Isn't he cute?" },
			{ titel = "🧣 TOO COLD", text = "Grandma Gerti wrapped you in three scarves. You can barely see.", sagt = "There! Now you won't catch a cold, sweetie!" },
			{ titel = "🥧 PIE DELIVERY", text = "Grandma Gerti wants to stop at every house to deliver pie.", sagt = "Stop here, dear! Mrs. Miller LOVES my apple pie!" },
		},
]===])
src = ersetze(src, [===[
			{ titel = "📣 MOTIVATION", text = "Coach Kevin is screaming motivational quotes out of the window.", sagt = "YOU! PEDESTRIAN! YOU CAN DO IT!" },
		},
]===], [===[
			{ titel = "📣 MOTIVATION", text = "Coach Kevin is screaming motivational quotes out of the window.", sagt = "YOU! PEDESTRIAN! YOU CAN DO IT!" },
			{ titel = "🏋️ LEG DAY", text = "Coach Kevin brought dumbbells. They're on your feet now.", sagt = "Brake WITH RESISTANCE! Feel those calves!" },
			{ titel = "⏱️ STOPWATCH", text = "Coach Kevin is timing how fast you blink.", sagt = "0.3 seconds! WE CAN DO BETTER! AGAIN!" },
		},
]===])
src = ersetze(src, [===[
			{ titel = "🎤 KARAOKE", text = "DJ Dina wants you to sing along. Right now.", sagt = "One, two, three – SING IT WITH ME!" },
		},
]===], [===[
			{ titel = "🎤 KARAOKE", text = "DJ Dina wants you to sing along. Right now.", sagt = "One, two, three – SING IT WITH ME!" },
			{ titel = "📻 LIVE ON AIR", text = "DJ Dina is broadcasting your driving live on the radio.", sagt = "And our driver takes the turn… THE CROWD GOES WILD!" },
			{ titel = "🕺 DANCE BREAK", text = "DJ Dina declared a dance break. The whole car is shaking.", sagt = "Hands up! …no wait, hands on the wheel!" },
		},
]===])
assert(#src == 53281, "Ergebnis-Länge falsch: " .. #src)
s.Source = src
print(s.Name .. ': ' .. #src .. ' Zeichen')
end
do
local s = game.StarterPlayer.StarterPlayerScripts.FuehrerscheinClient
local src = s.Source
for _, v in { "v57", "v58" } do
	src = src:gsub("client " .. v .. " loaded", "client v59 loaded"):gsub("start screen " .. v .. " loading", "start screen v59 loading")
end
s.Source = src
print("Client: " .. #src .. " Zeichen (soll 193439)")
end
game:GetService("ChangeHistoryService"):SetWaypoint("v59")
print("v59 eingespielt – speichern (Strg+S) und veröffentlichen")
