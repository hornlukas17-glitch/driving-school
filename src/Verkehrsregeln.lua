-- Shared traffic rules (used by server and client): speed limit zones, roundabouts and route gates.
local Regeln = {}

Regeln.HZ = -520 -- highway
Regeln.KREISEL = {
	Vector3.new(0, 0, 600), Vector3.new(-780, 0, 0), Vector3.new(-780, 0, 600), Vector3.new(780, 0, 600),
}

-- residential streets outside the city (same list as in the map generator): 30 km/h
Regeln.WOHNSTRASSEN = {
	{ -324, -208, -720, -208 }, { -720, -208, -720, -460 }, { -720, -460, 780, -460 },
	{ 208, -324, 208, -460 }, { -208, -324, -208, -460 }, { 324, -208, 412, -208 },
	{ -324, 208, -720, 208 }, { -720, 208, -720, 460 }, { -720, 460, -60, 460 },
	{ -208, 324, -208, 460 }, { 208, 324, 208, 460 }, { 60, 460, 400, 460 },
	{ -324, -104, -720, -104 }, { -720, -104, -720, -208 }, { -324, 104, -720, 104 }, { -720, 104, -720, 208 },
	{ 324, -104, 412, -104 },
	{ -720, -333, -208, -333 }, { -720, 333, -208, 333 }, { 208, -333, 780, -333 }, { 208, 333, 400, 333 },
	{ 0, -540, 0, -700 }, { -720, -700, 720, -700 }, { -400, -700, -400, -580 }, { 400, -700, 400, -580 },
}
local function inWohnstrasse(x, z)
	for _, w in Regeln.WOHNSTRASSEN do
		local x1, x2 = math.min(w[1], w[3]) - 11, math.max(w[1], w[3]) + 11
		local z1, z2 = math.min(w[2], w[4]) - 11, math.max(w[2], w[4]) + 11
		if x >= x1 and x <= x2 and z >= z1 and z <= z2 then return true end
	end
	return false
end

-- pizzeria parking lot (manoeuvring, no turn-signal check)
function Regeln.imPizzeria(pos)
	return pos.X > 345 and pos.X < 405 and pos.Z > 8 and pos.Z < 90
end

-- construction sites: lower speed limit
Regeln.BAUSTELLEN = {
	{ x1 = -800, x2 = -760, z1 = 335, z2 = 465, limit = 30, name = "Construction site" },
	{ x1 = 120, x2 = 330, z1 = -545, z2 = -495, limit = 80, name = "Construction site" },
}

function Regeln.tempolimit(pos)
	local x, z = pos.X, pos.Z
	for _, b in Regeln.BAUSTELLEN do
		if x >= b.x1 and x <= b.x2 and z >= b.z1 and z <= b.z2 then
			return b.limit, b.name
		end
	end
	if math.abs(x) <= 330 and math.abs(z) <= 330 then
		return 50, "City"
	end
	if math.abs(z - Regeln.HZ) <= 24 then
		return 130, "Highway"
	end
	if x >= 405 and x <= 765 and math.abs(z) <= 290 and math.abs(z) > 12 then
		return 30, "Residential area"
	end
	if inWohnstrasse(x, z) and math.abs(z) > 11 then
		return 30, "Residential area"
	end
	return 100, "Country road"
end

-- truck depot yard and its driveway (manoeuvring, no turn-signal check)
function Regeln.imDepot(pos)
	return pos.X > 462 and pos.X < 738 and pos.Z > 292 and pos.Z < 445
end

function Regeln.imKreisel(pos, radius)
	for _, k in Regeln.KREISEL do
		if (Vector3.new(pos.X, 0, pos.Z) - k).Magnitude < (radius or 75) then return true end
	end
	return false
end

local function rechtsVon(d)
	return Vector3.new(-d.Z, 0, d.X)
end

-- Has the car reached / driven through the gate?
function Regeln.durchTor(pos, torPos, dir, breite, radius)
	local rel = Vector3.new(pos.X - torPos.X, 0, pos.Z - torPos.Z)
	if rel.Magnitude < radius then return true end
	return math.abs(rel:Dot(dir)) < 6 and math.abs(rel:Dot(rechtsVon(dir))) < breite / 2 + 5
end

-- Where the green gate for waypoint i stands: after a turn it is on the new road in the
-- right lane, on a straight it is across the right lane. Returns position, direction, width, radius.
function Regeln.tor(punkte, i, startPos)
	local wp = punkte[i]
	local p = Vector3.new(wp.x, 0, wp.z)
	local vorher = punkte[i - 1]
	local von = vorher and Vector3.new(vorher.x, 0, vorher.z) or (startPos and Vector3.new(startPos.X, 0, startPos.Z)) or (p + Vector3.new(0, 0, 10))
	local rein = p - von
	rein = rein.Magnitude > 0.5 and rein.Unit or Vector3.new(0, 0, -1)
	local danach = punkte[i + 1]
	if wp.parken or wp.stopp then
		return p, rein, wp.breite or 26, wp.r or 16
	end
	if wp.breite then -- points that already lie in a lane (highway)
		return p, rein, wp.breite, wp.r or 16
	end
	if wp.r and wp.r <= 12 then -- points on the ring of a roundabout
		local raus = danach and (Vector3.new(danach.x, 0, danach.z) - p) or rein
		raus = raus.Magnitude > 0.5 and raus.Unit or rein
		return p, raus, 14, wp.r
	end
	if danach and not (danach.r and danach.r <= 12) then
		local raus = Vector3.new(danach.x, 0, danach.z) - p
		raus = raus.Magnitude > 0.5 and raus.Unit or rein
		if rein:Dot(raus) < math.cos(math.rad(30)) then
			-- a turn: the gate stands on the new road, in the right lane
			local vor = (wp.r and wp.r >= 18) and 32 or 18      -- wide junctions (highway) need more room
			if danach.breite then
				return p + raus * vor + rechtsVon(raus) * 10, raus, 20, 12 -- onto the highway: right lane
			end
			return p + raus * vor + rechtsVon(raus) * 5.5, raus, 14, 11
		end
	end
	return p + rechtsVon(rein) * 5.5, rein, 14, wp.r or 13
end

return Regeln
