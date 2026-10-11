-- Time of day and weather (server). One in-game day lasts 24 real minutes.
-- Weather changes every few minutes: clear, rain or fog. Rain makes the roads slippery
-- (the driving script reads the "Wetter" attribute), fog and night reduce the view.
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local Umwelt = {}
Umwelt.MINUTEN_PRO_TAG = 24
Umwelt.WETTER = {
	{ name = "Clear", chance = 0.6, dauer = { 240, 420 } },
	{ name = "Rain", chance = 0.25, dauer = { 150, 300 } },
	{ name = "Fog", chance = 0.15, dauer = { 120, 240 } },
}

function Umwelt.starten(ordner)
	Lighting.ClockTime = 9
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmo.Parent = Lighting
	local wolken = workspace.Terrain:FindFirstChildOfClass("Clouds")
	local basis = { dichte = atmo.Density or 0.3, dunst = atmo.Haze or 0, bedeckt = wolken and wolken.Cover or 0.5 }
	atmo.Density, atmo.Haze = basis.dichte, basis.dunst
	if wolken then wolken.Cover = basis.bedeckt end
	Lighting.Brightness = Lighting.Brightness or 2

	local wetter = "Clear"
	local function setzen(name)
		wetter = name
		ordner:SetAttribute("Wetter", name)
	end
	setzen("Clear")

	-- smooth fading between the weather looks
	local ziel = { dichte = basis.dichte, dunst = basis.dunst, bedeckt = basis.bedeckt }
	RunService.Heartbeat:Connect(function(dt)
		Lighting.ClockTime = (Lighting.ClockTime + dt * 24 / (Umwelt.MINUTEN_PRO_TAG * 60)) % 24
		ordner:SetAttribute("Uhrzeit", Lighting.ClockTime)
		if wetter == "Rain" then
			ziel = { dichte = 0.45, dunst = 2.5, bedeckt = 0.95 }
		elseif wetter == "Fog" then
			ziel = { dichte = 0.7, dunst = 4, bedeckt = 0.8 }
		else
			ziel = basis
		end
		local f = math.min(1, dt * 0.3)
		atmo.Density += (ziel.dichte - atmo.Density) * f
		atmo.Haze += (ziel.dunst - atmo.Haze) * f
		if wolken then wolken.Cover += (ziel.bedeckt - wolken.Cover) * f end
		-- a bit darker in bad weather
		local hell = (wetter == "Clear") and 2 or 1.4
		Lighting.Brightness += (hell - Lighting.Brightness) * f
	end)

	task.spawn(function()
		while true do
			local wurf, summe, wahl = math.random(), 0, Umwelt.WETTER[1]
			for _, w in Umwelt.WETTER do
				summe += w.chance
				if wurf <= summe then wahl = w break end
			end
			setzen(wahl.name)
			task.wait(math.random(wahl.dauer[1], wahl.dauer[2]))
		end
	end)
end

return Umwelt
