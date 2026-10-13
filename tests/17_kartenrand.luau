-- Map border: invisible walls on all four sides, a safety floor below, grass surface just under the asphalt
M.log = function() end
lade("gen", Q.gen)()
M.laufen(3)
local function pruefe(name, ok) print((ok and "OK  " or "FAIL") .. " " .. name) if not ok then error("check failed: " .. name) end end
local rand = workspace.Karte:FindFirstChild("Kartenrand")
pruefe("border folder exists", rand ~= nil)
local waende, boden = {}, nil
for _, t in rand:GetChildren() do
	if t.Name == "Wand" then table.insert(waende, t) end
	if t.Name == "Sicherheitsboden" then boden = t end
end
pruefe("4 walls", #waende == 4)
local seiten = {}
for _, w in waende do
	pruefe("wall anchored and invisible", w.Anchored and w.Transparency == 1 and w.CanCollide ~= false)
	pruefe("wall high enough", w.Size.Y >= 300 and w.Position.Y - w.Size.Y / 2 < -5)
	if math.abs(w.Position.X) > 800 then seiten["x" .. math.sign(w.Position.X)] = true end
	if math.abs(w.Position.Z) > 800 then seiten["z" .. math.sign(w.Position.Z)] = true end
end
pruefe("walls on all four sides", seiten["x1"] and seiten["x-1"] and seiten["z1"] and seiten["z-1"])
pruefe("safety floor under the whole map", boden and boden.Anchored and boden.Size.X >= 1700 and boden.Size.Z >= 1700 and boden.Position.Y < -5)
pruefe("grass surface below the asphalt", string.find(Q.gen, "local GRAS_Y = -4", 1, true) ~= nil)
print("map border ok")
