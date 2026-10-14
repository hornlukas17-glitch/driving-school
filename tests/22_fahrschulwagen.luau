-- New driving school car body (Lukas' model "Fahrschulwagen"): only the looks change.
-- Chassis, wheels, hinges, seats, attributes and colliding parts must stay exactly the same.
M.log = function() end
lade("gen", Q.gen)()
M.laufen(1)
lade("inst", Q.inst)()
local SSS = game:GetService("ServerScriptService")
for _, s in workspace:GetDescendants() do if s:IsA("Script") then task.spawn(lade(s.Name, s.Source, { script = s })) end end
for _, s in SSS:GetChildren() do if s:IsA("Script") then task.spawn(lade(s.Name, s.Source, { script = s })) end end
M.laufen(2)
local function pruefe(name, ok) print((ok and "OK  " or "FAIL") .. " " .. name) if not ok then error("check failed: " .. name) end end
local Auto = require(SSS.FuehrerscheinServer.Auto)
local K = require(SSS.FuehrerscheinServer.Karosserien).fahrschule
pruefe("body definition exists", K ~= nil and K.vorlage == "Fahrschulwagen" and K.dachschild ~= nil)
pruefe("wheels of the body match the driving school car", K.mesh.Radhaus ~= nil)

local function physik(m)
	-- everything that matters for driving: chassis, wheels, knuckles, hinges, seats, colliding parts, attributes
	local t = {}
	local basis = m.Chassis.CFrame
	for _, x in m:GetDescendants() do
		if x:IsA("BasePart") and (x.CanCollide or not x.Massless or x:IsA("Seat") or x:IsA("VehicleSeat")) then
			local rel = basis:ToObjectSpace(x.CFrame)
			table.insert(t, ("%s %s %s %.2f,%.2f,%.2f"):format(x.ClassName, x.Name, tostring(x.Size), rel.X, rel.Y, rel.Z))
		elseif x:IsA("HingeConstraint") then
			table.insert(t, ("Hinge %s %s %s"):format(x.Name, tostring(x.ActuatorType), tostring(x.Attachment0 and x.Attachment0.CFrame.Position)))
		end
	end
	for name, wert in m:GetAttributes() do table.insert(t, "attr " .. name .. "=" .. tostring(wert)) end
	table.sort(t)
	return table.concat(t, "\n")
end
local function sichtbar(m, name)
	local n = 0
	for _, x in m:GetChildren() do
		if x.Name == name and x:IsA("BasePart") and x.Transparency < 0.5 then n += 1 end
	end
	return n
end

-- 1) without the imported model: the old block car
local alt = Auto.bauen(CFrame.new(0, 0.2, -700), Color3.fromRGB(200, 30, 35))
alt.Parent = workspace
pruefe("block body without the model", alt:FindFirstChild("Motorhaube") ~= nil and alt:FindFirstChild("Karosserie") == nil)

-- 2) imported model in ServerStorage (like the 3D importer makes it)
local vorlage = Instance.new("Model")
vorlage.Name = "Fahrschulwagen"
for n in K.mesh do
	local mp = Instance.new("MeshPart")
	mp.Name = n
	mp.Parent = vorlage
end
vorlage.Parent = game:GetService("ServerStorage")
local neu = Auto.bauen(CFrame.new(0, 0.2, -700), Color3.fromRGB(200, 30, 35))
neu.Parent = workspace
pruefe("new body: mesh parts", neu:FindFirstChild("Karosserie") ~= nil and neu:FindFirstChild("Rund_Glas") ~= nil)
pruefe("driving school is white", neu.Karosserie.Color == Color3.fromRGB(242, 243, 246))
pruefe("red and blue stripes", sichtbar(neu, "Streifen") == 4)
pruefe("headlights (light switch works on them)", neu:FindFirstChild("Scheinwerfer") ~= nil and neu.Scheinwerfer:FindFirstChildOfClass("SpotLight") ~= nil)
pruefe("indicators on the new body (front, rear, mirror)", sichtbar(neu, "BlinkerL") == 3 and sichtbar(neu, "BlinkerR") == 3)
pruefe("old look gone", neu:FindFirstChild("Motorhaube") == nil and neu:FindFirstChild("Spiegel") == nil and neu:FindFirstChild("Tuerfuge") == nil)
pruefe("old colliding parts stay (invisible)", neu:FindFirstChild("Haube") ~= nil and neu.Haube.Transparency == 1 and neu.Haube.CanCollide == true)
pruefe("trunk lid kept for the pizza job", neu:FindFirstChild("Kofferraumdeckel") ~= nil and neu.Kofferraumdeckel.Transparency == 1)
pruefe("interior stays", sichtbar(neu, "Lenkrad") == 1 and sichtbar(neu, "Armaturenbrett") == 1)
local rel = neu.Chassis.CFrame:ToObjectSpace(neu.Dachschild.CFrame)
pruefe("roof sign sits where the model had it", math.abs(rel.Z - K.dachschild.z) < 0.01 and math.abs(neu.Dachschild.Size.X - K.dachschild.breite) < 0.01)
local text = neu.Dachschild:FindFirstChildOfClass("SurfaceGui"):FindFirstChildOfClass("TextLabel").Text
pruefe("roof sign says DRIVING SCHOOL", text == "DRIVING SCHOOL")
local plates = 0
for _, x in neu:GetChildren() do
	if x.Name == "Kennzeichen" then
		local r = neu.Chassis.CFrame:ToObjectSpace(x.CFrame)
		local soll = r.Z < 0 and K.kennzeichen.vorne or K.kennzeichen.hinten
		if math.abs(r.Z - soll[2]) < 0.01 then plates += 1 end
	end
end
pruefe("number plates on the new bumpers", plates == 2)
pruefe("driving stays exactly the same (chassis, wheels, hinges, seats, colliders, attributes)", physik(neu) == physik(alt))
local teile = 0
for _, x in neu:GetDescendants() do if x:IsA("BasePart") then teile += 1 end end
print("parts in the new car:", teile)

-- 3) pizza car: same body, its own colour and sign, no driving school stripes
local pizza = Auto.bauen(CFrame.new(30, 0.2, -700), Color3.fromRGB(200, 40, 30), "PIZZA RAPIDO")
pruefe("pizza car keeps its colour", pizza.Karosserie.Color == Color3.fromRGB(200, 40, 30))
pruefe("pizza car without stripes", sichtbar(pizza, "Streifen") == 0)
pruefe("pizza sign text", pizza.Dachschild:FindFirstChildOfClass("SurfaceGui"):FindFirstChildOfClass("TextLabel").Text == "PIZZA RAPIDO")
vorlage:Destroy()
print("driving school car ok")
