-- Driving School v43 (Rest): Chaos-Events landen auf der Straße. Spiel stoppen, in die Studio-Befehlszeile einfügen, Enter.
if string.find(game.ServerScriptService.FuehrerscheinServer.Chaos.Source, "local function istStrasse", 1, true) then print("schon drin") return end
local function ersetze(src, alt, neu)
	local a, b = string.find(src, alt, 1, true)
	assert(a, "nicht gefunden: " .. alt:sub(1, 60))
	assert(not string.find(src, alt, b + 1, true), "mehrfach: " .. alt:sub(1, 60))
	return src:sub(1, a - 1) .. neu .. src:sub(b + 1)
end
local s = game.ServerScriptService.FuehrerscheinServer.Chaos
local src = s.Source
assert(#src == 36260, "Ausgangsstand passt nicht: " .. #src)
src = ersetze(src, [===[
	end)
	if ok and treffer then return treffer.Position.Y end
	return nil
]===], [===[
	end)
	if ok and treffer then return treffer.Position.Y, treffer.Instance end
	return nil
]===])
src = ersetze(src, [===[
	return nil
end
]===], [===[
	return nil
end

-- is this part a road (not a pavement, lawn or roof)?
local function istStrasse(teil)
	local strassen = workspace:FindFirstChild("Karte") and workspace.Karte:FindFirstChild("Strassen")
	if not strassen or not teil then return true end -- map without a road folder (tests): accept
	return teil:IsDescendantOf(strassen) and not teil.Name:lower():find("geh") and not teil.Name:lower():find("bord")
end
]===])
src = ersetze(src, [===[
	local mitte = st.chassis.Position + vor * abstand
	local y = boden(st, mitte)
	local yAuto = boden(st, st.chassis.Position)
]===], [===[
	local mitte = st.chassis.Position + vor * abstand
	-- the next green gate stands on the road in the right lane: use it when it is ahead and not too far
	if st.tor and st.tor.pos then
		local zumTor = Vector3.new(st.tor.pos.X - st.chassis.Position.X, 0, st.tor.pos.Z - st.chassis.Position.Z)
		if zumTor.Magnitude > 45 and zumTor.Magnitude < abstand + 40 and zumTor.Unit:Dot(vor) > 0.85 then
			mitte = st.chassis.Position + zumTor
			vor = zumTor.Unit
		end
	end
	local y, teil = boden(st, mitte)
	if not istStrasse(teil) then
		-- not on the road (pavement, grass): look a bit to the left and right
		local rechts = Vector3.new(-vor.Z, 0, vor.X)
		for _, versatz in { -5, 5, -9, 9 } do
			local y2, teil2 = boden(st, mitte + rechts * versatz)
			if y2 and istStrasse(teil2) then mitte, y, teil = mitte + rechts * versatz, y2, teil2 break end
		end
	end
	local yAuto = boden(st, st.chassis.Position)
]===])
src = ersetze(src, [===[
	local yAuto = boden(st, st.chassis.Position)
	if y and yAuto and math.abs(y - yAuto) > 4 then
		-- not a road ahead (roof, wall, hill): try again a bit later
		c.anzahl -= 1
]===], [===[
	local yAuto = boden(st, st.chassis.Position)
	if (y and yAuto and math.abs(y - yAuto) > 4) or not istStrasse(teil) then
		-- no road ahead (roof, wall, hill, lawn): try again a bit later
		c.anzahl -= 1
]===])
assert(#src == 37484, "Ergebnis-Länge falsch: " .. #src)
s.Source = src
print("v43 eingespielt: Events landen jetzt auf der Straße")