-- v57: NPC cars from imported templates (ReplicatedStorage.Fuehrerschein.Autos), fallback = old block cars.
lade("gen", Q.gen)()
M.laufen(1)
lade("inst", Q.inst)()
M.laufen(1)
local function pruefe(name, ok) print((ok and "OK  " or "FAIL") .. " " .. name) if not ok then error("check failed: " .. name) end end
local RS = game.ReplicatedStorage
local Verkehr = require(RS.Fuehrerschein.Verkehr)

-- without templates: old block car (has the usual body + lights)
local alt = Verkehr.modell("limousine", 1, 1)
pruefe("fallback block car", alt:FindFirstChild("Karosserie") ~= nil and alt:FindFirstChild("Ruecklicht") ~= nil)

-- a small fake template like the importer makes it: front = +Z, origin = part "Anker", half size (scaled up later)
local ordner = Instance.new("Folder") ordner.Name = "Autos" ordner.Parent = RS.Fuehrerschein
local v = Instance.new("Model") v.Name = "Limousine" v.Parent = ordner
local function teil(name, pos, gr)
	local p = Instance.new("Part") p.Name = name p.Size = gr p.CFrame = CFrame.new(pos) p.Parent = v return p
end
local versatz = Vector3.new(100, 0, 50) -- the importer may put it anywhere
teil("Anker", versatz, Vector3.new(0.1, 0.1, 0.1))
teil("Lack", versatz + Vector3.new(0, 1.2, 0), Vector3.new(3.4, 1.6, 7.25))
teil("Glas", versatz + Vector3.new(0, 2.2, 0.3), Vector3.new(3, 1, 3))
teil("Licht.001", versatz + Vector3.new(1, 1.2, 3.6), Vector3.new(0.5, 0.2, 0.1))
teil("Ruecklicht", versatz + Vector3.new(1, 1.2, -3.6), Vector3.new(0.5, 0.2, 0.1))

local m = Verkehr.modell("limousine", 2, 1)
pruefe("model from the template", m:FindFirstChild("Lack") ~= nil and m:FindFirstChild("Wurzel") ~= nil and m.PrimaryPart ~= nil)
local licht, rueck = m:FindFirstChild("Licht"), m:FindFirstChild("Ruecklicht")
pruefe("group names cleaned (Licht.001 -> Licht)", licht ~= nil and rueck ~= nil)
pruefe("front turned to -Z (headlight in front)", licht.Position.Z < 0 and rueck.Position.Z > 0)
local lack = m:FindFirstChild("Lack")
pruefe("scaled to 14.5 studs length", math.abs(lack.Size.Z - 14.5) < 0.6)
pruefe("origin on the anchor (not at the importer's position)", math.abs(lack.Position.X) < 0.01 and math.abs(lack.Position.Y - 2.4) < 0.2)
pruefe("headlight is neon", licht.Material == Enum.Material.Neon)
pruefe("mesh parts don't collide, invisible body does", not lack.CanCollide and m:FindFirstChild("Karosserie").CanCollide and m:FindFirstChild("Karosserie").Transparency == 1)
pruefe("art without template stays a block car", Verkehr.modell("kleinwagen", 1, 1):FindFirstChild("Lack") == nil)
-- like Studio's importer: front already at -Z (indicators there) -> not turned again
local v2 = v:Clone() v2.Name = "SUV" v2.Parent = ordner
for _, x in v2:GetChildren() do
	if x.Name == "Licht.001" then x.CFrame = CFrame.new(versatz + Vector3.new(1, 1.2, -3.6)) end
	if x.Name == "Ruecklicht" then x.CFrame = CFrame.new(versatz + Vector3.new(1, 1.2, 3.6)) end
end
local b = Instance.new("Part") b.Name = "Blinker" b.Size = Vector3.new(0.2, 0.2, 0.1) b.CFrame = CFrame.new(versatz + Vector3.new(1.6, 1.2, -3.55)) b.Parent = v2
local m2 = Verkehr.modell("suv", 1, 1)
pruefe("importer orientation detected via indicators (front stays -Z)", m2:FindFirstChild("Licht").Position.Z < 0 and m2:FindFirstChild("Blinker").Position.Z < 0)
print("templates ok")
