-- Driving School v47 -> v48: "Ride along" verschwindet, sobald das Fahrstunden-Auto den Parkplatz verlässt,
-- und der Fahrer selbst sieht es gar nicht. In die Studio-Befehlszeile (Spiel gestoppt), Enter. Mehrfach ausführbar.
local erg = {}
local function ersetze(s, name, alt, neu)
	local src = s.Source
	if string.find(src, neu, 1, true) then table.insert(erg, "OK (schon drin) " .. name) return end
	local a, b = string.find(src, alt, 1, true)
	if not a then table.insert(erg, "FEHLER " .. name .. ": Stelle nicht gefunden") return end
	assert(not string.find(src, alt, b + 1, true), "mehrfach: " .. name)
	s.Source = src:sub(1, a - 1) .. neu .. src:sub(b + 1)
	table.insert(erg, "OK " .. name)
end
local server = game.ServerScriptService.FuehrerscheinServer
local client = game.StarterPlayer.StarterPlayerScripts.FuehrerscheinClient
ersetze(server, "Server: Prompt merken", [===[
		mitfahrPrompt(p, ruecksitz, modell)
	end]===], [===[
		st.mitfahrPP = mitfahrPrompt(p, ruecksitz, modell)
	end]===])
ersetze(server, "Server: Prompt weg nach Parkplatz", [===[
		local pos = st.chassis.Position
		local tempo = st.chassis.AssemblyLinearVelocity.Magnitude
]===], [===[
		local pos = st.chassis.Position
		local tempo = st.chassis.AssemblyLinearVelocity.Magnitude
		-- "Ride along" only on the driving school parking lot: gone once the car has left it
		if st.mitfahrPP and st.startPos and (pos - st.startPos).Magnitude > 45 then
			st.mitfahrPP:Destroy()
			st.mitfahrPP = nil
		end
]===])
ersetze(client, "Client: eigenes Auto ohne Ride along", [===[
			local drin = hum and tuer and hum.SeatPart == tuer
]===], [===[
			local drin = hum and tuer and hum.SeatPart == tuer
			-- your own car: no "Ride along" for yourself (only friends see it)
			local eigen = m and m:FindFirstChild("Mitfahren", true)
			if eigen and eigen.Enabled then eigen.Enabled = false end
]===])
for _, s in { server, client } do
	s.Source = s.Source:gsub("v47 loaded", "v48 loaded"):gsub("start screen v47", "start screen v48")
end
print(table.concat(erg, "\n"))
