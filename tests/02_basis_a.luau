M.log = function() end
lade("gen", Q.gen)()
M.laufen(1)
lade("inst", Q.inst)()
local SSS = game:GetService("ServerScriptService")
for _, s in workspace:GetDescendants() do if s:IsA("Script") then task.spawn(lade(s.Name, s.Source, { script = s })) end end
for _, s in SSS:GetChildren() do if s:IsA("Script") then task.spawn(lade(s.Name, s.Source, { script = s })) end end
M.laufen(2)
local V = require(game.ReplicatedStorage.Fuehrerschein.Verkehr)
local fz = V.fahrzeuge
print("vehicles", #fz)
local weg, stand, maxStand = {}, {}, {}
for i, f in fz do weg[i] = 0; stand[i] = 0; maxStand[i] = 0 end
local ueberlapp = 0
local beispiele = {}
local T = 400
local schritt = 1/30
local n = 0
while M.zeit() < T do
	local vorher = {}
	for i, f in fz do vorher[i] = f.s end
	M.laufen(M.zeit() + 0.5, schritt)
	for i, f in fz do
		local d = (f.s - vorher[i]) % f.spur.gesamt
		weg[i] += d
		if d < 0.1 then stand[i] += 0.5; maxStand[i] = math.max(maxStand[i], stand[i]) else stand[i] = 0 end
	end
	-- overlaps between NPC vehicles
	for i = 1, #fz do for j = i + 1, #fz do
		local a, b = fz[i], fz[j]
		local rel = b.pos - a.pos
		if rel.Magnitude < (a.laenge + b.laenge) / 2 then
			local r = Vector3.new(-a.dir.Z, 0, a.dir.X)
			if math.abs(rel:Dot(a.dir)) < (a.laenge + b.laenge) / 2 - 1 and math.abs(rel:Dot(r)) < (a.breite + b.breite) / 2 - 1 then
				ueberlapp += 1
				if #beispiele < 8 then table.insert(beispiele, string.format("t=%.0f %d(%s r%d) %d(%s r%d) at %s", M.zeit(), i, a.art, a.route, j, b.art, b.route, tostring(a.pos))) end
			end
		end
	end end
end
for i, f in fz do
	print(string.format("%2d r%d %-11s km=%5.0f  maxStand=%3.0fs  v=%.1f pos=%s", i, f.route, f.art, weg[i], maxStand[i], f.v, tostring(f.pos)))
end
print("overlaps", ueberlapp)
for _, b in beispiele do print(b) end
print("errors", M.fehler or 0)
