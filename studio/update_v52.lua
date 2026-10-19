-- v51 -> v52 (keine Polizei). In Studio im EDIT-Modus in die Befehlszeile einfügen und Enter.
do
local function ersetze(src, alt, neu)
	local a, b = string.find(src, alt, 1, true)
	assert(a, "nicht gefunden: " .. alt:sub(1, 60))
	assert(not string.find(src, alt, b + 1, true), "mehrfach: " .. alt:sub(1, 60))
	return src:sub(1, a - 1) .. neu .. src:sub(b + 1)
end
local s = game.ServerScriptService.FuehrerscheinServer
local src = s.Source
assert(#src == 138618, "Ausgangsstand passt nicht: " .. #src)
src = ersetze(src, [===[
-- Police: traffic checkpoints (for you and the NPC traffic) and patrol cars that stop speeders
-- ---------------------------------------------------------------
]===], [===[
-- Police: traffic checkpoints (for you and the NPC traffic) and patrol cars that stop speeders
-- v52: switched OFF (Lukas: no police in the game). Speed cameras, fines and points stay (Strafen.lua).
-- Set POLIZEI_AKTIV = true (and Verkehr.POLIZEI = true) to bring it back.
-- ---------------------------------------------------------------
]===])
src = ersetze(src, [===[
-- ---------------------------------------------------------------
local KONTROLL_PUNKTE = {
]===], [===[
-- ---------------------------------------------------------------
local POLIZEI_AKTIV = false
local KONTROLL_PUNKTE = {
]===])
src = ersetze(src, [===[
task.spawn(function()
	task.wait(45)
]===], [===[
task.spawn(function()
	if not POLIZEI_AKTIV then return end
	task.wait(45)
]===])
src = ersetze(src, [===[
RunService.Heartbeat:Connect(function(dt)
	polizeiTakt += dt
]===], [===[
RunService.Heartbeat:Connect(function(dt)
	if not POLIZEI_AKTIV then return end
	polizeiTakt += dt
]===])
assert(#src == 138902, "Ergebnis-Länge falsch: " .. #src)
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
assert(#src == 190443, "Ausgangsstand passt nicht: " .. #src)
src = ersetze(src, [===[
local spieler = Players.LocalPlayer
print("[Driving School] client v51 loaded")
local ordner = RS:WaitForChild("Fuehrerschein")
]===], [===[
local spieler = Players.LocalPlayer
print("[Driving School] client v52 loaded")
local ordner = RS:WaitForChild("Fuehrerschein")
]===])
src = ersetze(src, [===[
					{ "Retraining course", "Speeding is the most common cause of accidents.\n\n• Always watch the speed limit sign on your speedometer.\n• Speed cameras measure in <b>both directions</b>.\n• Every offence brings <b>penalty points</b>; at <b>8 points</b> the license is gone again." },
					{ "Retraining course", "• Red light = stop. Always.\n• Stop for the police when they signal you.\n• Points expire over time if you drive safely.\n\nNow book your new driving test with Anna!" },
				}
]===], [===[
					{ "Retraining course", "Speeding is the most common cause of accidents.\n\n• Always watch the speed limit sign on your speedometer.\n• Speed cameras measure in <b>both directions</b>.\n• Every offence brings <b>penalty points</b>; at <b>8 points</b> the license is gone again." },
					{ "Retraining course", "• Red light = stop. Always.\n• Speed cameras are everywhere – watch the limit.\n• Points expire over time if you drive safely.\n\nNow book your new driving test with Anna!" },
				}
]===])
src = ersetze(src, [===[
do
	print("[Driving School] start screen v51 loading")
	local menue = Instance.new("ScreenGui")
]===], [===[
do
	print("[Driving School] start screen v52 loading")
	local menue = Instance.new("ScreenGui")
]===])
assert(#src == 190451, "Ergebnis-Länge falsch: " .. #src)
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
local s = game.ReplicatedStorage.Fuehrerschein.Verkehr
local src = s.Source
assert(#src == 31268, "Ausgangsstand passt nicht: " .. #src)
src = ersetze(src, [===[
local Verkehr = {}

]===], [===[
local Verkehr = {}
Verkehr.POLIZEI = false -- v52: no police cars in the traffic (Lukas)

]===])
src = ersetze(src, [===[
			end
			if i == 1 and (r == 1 or r == 4) then art = "polizei" end -- two patrol cars
			local f = {
]===], [===[
			end
			if Verkehr.POLIZEI and i == 1 and (r == 1 or r == 4) then art = "polizei" end -- two patrol cars (v52: off)
			local f = {
]===])
assert(#src == 31369, "Ergebnis-Länge falsch: " .. #src)
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
local s = game.ServerScriptService.FuehrerscheinServer.Missionen
local src = s.Source
assert(#src == 7433, "Ausgangsstand passt nicht: " .. #src)
src = ersetze(src, [===[
	{ id = "km", text = "Drive %d km in your own car", ziele = { 2, 3, 5 }, geld = 200, xp = 80 },
	{ id = "kontrolle", text = "Pass a police check without a fine", ziele = { 1 }, geld = 150, xp = 60 },
	{ id = "tanken", text = "Refuel your car at a gas station", ziele = { 1 }, geld = 100, xp = 40 },
]===], [===[
	{ id = "km", text = "Drive %d km in your own car", ziele = { 2, 3, 5 }, geld = 200, xp = 80 },
	{ id = "tanken", text = "Refuel your car at a gas station", ziele = { 1 }, geld = 100, xp = 40 },
]===])
src = ersetze(src, [===[

local function aktuell(p)
]===], [===[

local function art(id)
	for _, a in Missionen.ARTEN do
		if a.id == id then return a end
	end
end

local function aktuell(p)
]===])
src = ersetze(src, [===[
	end
	return d.missionen
]===], [===[
	end
	-- v52: a mission type was removed (police check) -> today's list gets rolled again
	for _, m in d.missionen.liste do
		if not art(m.id) then d.missionen = neueListe(p) break end
	end
	return d.missionen
]===])
src = ersetze(src, [===[
	return d.missionen
end

local function art(id)
	for _, a in Missionen.ARTEN do
		if a.id == id then return a end
	end
end
]===], [===[
	return d.missionen
end
]===])
assert(#src == 7514, "Ergebnis-Länge falsch: " .. #src)
s.Source = src
print(s.Name .. ": " .. #src .. " Zeichen")
end
print("v52 eingespielt – jetzt speichern (Strg+S) und veröffentlichen")
