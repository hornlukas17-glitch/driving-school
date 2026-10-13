--!nocheck
-- Minimal Roblox mock for running the generator / server / client scripts headless.
local M = {}
local uhr = 0
os.clock = function() return uhr end
local origTime = os.time
os.time = function() return 1760000000 + math.floor(uhr) end

-- ---------------- Vector3 ----------------
local V = {}
V.__index = function(t, k)
	if k == "Magnitude" then return math.sqrt(t.X*t.X + t.Y*t.Y + t.Z*t.Z) end
	if k == "Unit" then local m = math.sqrt(t.X*t.X + t.Y*t.Y + t.Z*t.Z); if m == 0 then return V.new(0,0,0) end return V.new(t.X/m, t.Y/m, t.Z/m) end
	return V[k]
end
function V.new(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0, __v = true }, V) end
V.__add = function(a, b) return V.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V.__sub = function(a, b) return V.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V.__mul = function(a, b)
	if type(a) == "number" then a, b = b, a end
	if type(b) == "number" then return V.new(a.X * b, a.Y * b, a.Z * b) end
	return V.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V.__div = function(a, b) if type(b) == "number" then return V.new(a.X / b, a.Y / b, a.Z / b) end return V.new(a.X/b.X, a.Y/b.Y, a.Z/b.Z) end
V.__unm = function(a) return V.new(-a.X, -a.Y, -a.Z) end
V.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
V.__tostring = function(a) return string.format("(%.2f, %.2f, %.2f)", a.X, a.Y, a.Z) end
function V.Dot(a, b) return a.X*b.X + a.Y*b.Y + a.Z*b.Z end
function V.Cross(a, b) return V.new(a.Y*b.Z - a.Z*b.Y, a.Z*b.X - a.X*b.Z, a.X*b.Y - a.Y*b.X) end
function V.Lerp(a, b, t) return a + (b - a) * t end
V.zero = V.new(0,0,0)
V.one = V.new(1,1,1)
Vector3 = V

-- ---------------- CFrame (rotation matrix rows) ----------------
local C = {}
local function cf(p, r) return setmetatable({ p = p, r = r }, C) end
local I3 = { 1,0,0, 0,1,0, 0,0,1 }
local function mm(a, b)
	local r = {}
	for i = 0, 2 do for j = 0, 2 do
		local s = 0
		for k = 0, 2 do s += a[i*3+k+1] * b[k*3+j+1] end
		r[i*3+j+1] = s
	end end
	return r
end
local function mv(a, v) return V.new(a[1]*v.X + a[2]*v.Y + a[3]*v.Z, a[4]*v.X + a[5]*v.Y + a[6]*v.Z, a[7]*v.X + a[8]*v.Y + a[9]*v.Z) end
local function tr(a) return { a[1],a[4],a[7], a[2],a[5],a[8], a[3],a[6],a[9] } end
C.__index = function(t, k)
	if k == "Position" then return t.p end
	if k == "X" then return t.p.X elseif k == "Y" then return t.p.Y elseif k == "Z" then return t.p.Z end
	if k == "LookVector" then return V.new(-t.r[3], -t.r[6], -t.r[9]) end
	if k == "RightVector" then return V.new(t.r[1], t.r[4], t.r[7]) end
	if k == "UpVector" then return V.new(t.r[2], t.r[5], t.r[8]) end
	if k == "Rotation" then return cf(V.new(0,0,0), t.r) end
	return C[k]
end
C.__mul = function(a, b)
	if getmetatable(b) == C then return cf(a.p + mv(a.r, b.p), mm(a.r, b.r)) end
	return a.p + mv(a.r, b)
end
C.__add = function(a, v) return cf(a.p + v, a.r) end
C.__sub = function(a, v) return cf(a.p - v, a.r) end
function C.new(x, y, z, ...)
	if x == nil then return cf(V.new(0,0,0), I3) end
	if type(x) == "table" and x.__v then
		if y then return C.lookAt(x, y) end
		return cf(x, I3)
	end
	local rest = { ... }
	if #rest == 9 then return cf(V.new(x,y,z), rest) end
	return cf(V.new(x, y, z), I3)
end
function C.lookAt(eye, target, up)
	up = up or V.new(0, 1, 0)
	local f = (target - eye)
	if f.Magnitude < 1e-9 then return cf(eye, I3) end
	f = f.Unit
	local r = f:Cross(up)
	if r.Magnitude < 1e-6 then r = f:Cross(V.new(0,0,1)) end
	r = r.Unit
	local u = r:Cross(f)
	return cf(eye, { r.X, u.X, -f.X, r.Y, u.Y, -f.Y, r.Z, u.Z, -f.Z })
end
local function rx(a) local c, s = math.cos(a), math.sin(a) return { 1,0,0, 0,c,-s, 0,s,c } end
local function ry(a) local c, s = math.cos(a), math.sin(a) return { c,0,s, 0,1,0, -s,0,c } end
local function rz(a) local c, s = math.cos(a), math.sin(a) return { c,-s,0, s,c,0, 0,0,1 } end
function C.Angles(x, y, z) return cf(V.new(0,0,0), mm(mm(rx(x), ry(y)), rz(z))) end
C.fromEulerAnglesXYZ = C.Angles
function C.fromOrientation(x, y, z) return cf(V.new(0,0,0), mm(mm(ry(y), rx(x)), rz(z))) end
function C.Inverse(a) local ri = tr(a.r) return cf(-mv(ri, a.p), ri) end
function C.PointToObjectSpace(a, v) return mv(tr(a.r), v - a.p) end
function C.PointToWorldSpace(a, v) return a.p + mv(a.r, v) end
function C.VectorToObjectSpace(a, v) return mv(tr(a.r), v) end
function C.VectorToWorldSpace(a, v) return mv(a.r, v) end
function C.ToObjectSpace(a, b) return C.Inverse(a) * b end
function C.ToWorldSpace(a, b) return a * b end
function C.Lerp(a, b, t) return cf(a.p:Lerp(b.p, t), t < 0.5 and a.r or b.r) end
function C.ToOrientation(a)
	local r = a.r
	local x = math.asin(math.clamp(-r[6], -1, 1))
	local y = math.atan2(r[3], r[9])
	local z = math.atan2(r[4], r[5])
	return x, y, z
end
function C.GetComponents(a) return a.p.X, a.p.Y, a.p.Z, table.unpack(a.r) end
C.identity = cf(V.new(0,0,0), I3)
CFrame = C

-- ---------------- misc datatypes ----------------
local function stubType(name)
	local T = {}
	T.__index = T
	T.__tostring = function() return name end
	setmetatable(T, { __index = function(_, k) return function(...) return setmetatable({ args = { ... } }, T) end end })
	return T
end
Color3 = {}
local C3 = {}
C3.__index = C3
function Color3.new(r, g, b) return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, C3) end
function Color3.fromRGB(r, g, b) return Color3.new((r or 0) / 255, (g or 0) / 255, (b or 0) / 255) end
function Color3.fromHSV(h, s, v) return Color3.new(v, v, v) end
function C3.Lerp(a, b, t) return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t) end
C3.__eq = function(a, b) return a.R == b.R and a.G == b.G and a.B == b.B end
UDim2 = stubType("UDim2"); UDim = stubType("UDim"); Vector2 = stubType("Vector2")
UDim2.new = function(xs, xo, ys, yo) return { X = { Scale = xs or 0, Offset = xo or 0 }, Y = { Scale = ys or 0, Offset = yo or 0 } } end
UDim2.fromScale = function(x, y) return UDim2.new(x, 0, y, 0) end; UDim2.fromOffset = function(x, y) return UDim2.new(0, x, 0, y) end
UDim.new = function(...) return { ... } end
Vector2.new = function(x, y) return { X = x, Y = y } end
NumberSequence = { new = function(...) return { ... } end }
NumberSequenceKeypoint = { new = function(...) return { ... } end }
ColorSequence = { new = function(...) return { ... } end }
ColorSequenceKeypoint = { new = function(...) return { ... } end }
NumberRange = { new = function(...) return { ... } end }
TweenInfo = { new = function(...) return { ... } end }
PhysicalProperties = { new = function(...) return { ... } end }
BrickColor = { new = function(...) return { ... } end }
RaycastParams = { new = function() return {} end }
Font = { new = function(...) return { ... } end, fromEnum = function(...) return {} end }
Random = { new = function(seed)
	local r = {}
	function r:NextNumber(a, b) a = a or 0; b = b or 1 return a + math.random() * (b - a) end
	function r:NextInteger(a, b) return math.random(a, b) end
	return r
end }
Region3 = { new = function(a, b) return { a, b } end }
local enumMeta
enumMeta = {
	__index = function(t, k)
		local v = setmetatable({ Name = k, __pfad = rawget(t, "__pfad") .. "." .. k }, enumMeta)
		rawset(t, k, v)
		return v
	end,
	__tostring = function(t) return rawget(t, "__pfad") end,
}
Enum = setmetatable({ __pfad = "Enum" }, enumMeta)
warn = warn or function(...) print("WARN:", ...) end
typeof = function(v)
	if type(v) == "table" then
		if v.__v then return "Vector3" end
		if getmetatable(v) == C then return "CFrame" end
		if v.__klasse then return "Instance" end
	end
	return type(v)
end

-- ---------------- scheduler ----------------
local wartend = {} -- { zeit, co, args }
local function planen(zeit, co, ...)
	table.insert(wartend, { zeit = zeit, co = co, args = table.pack(...) })
end
local function fortsetzen(co, ...)
	local ok, e = coroutine.resume(co, ...)
	if not ok then
		M.fehler = (M.fehler or 0) + 1
		print("ERROR: " .. tostring(e))
		print(debug.traceback(co))
	end
end
task = {}
function task.spawn(f, ...)
	local co = type(f) == "thread" and f or coroutine.create(f)
	fortsetzen(co, ...)
	return co
end
function task.defer(f, ...)
	local co = coroutine.create(f)
	planen(uhr, co, ...)
	return co
end
function task.delay(t, f, ...)
	local co = coroutine.create(f)
	planen(uhr + (t or 0), co, ...)
	return co
end
function task.wait(t)
	local co = coroutine.running()
	planen(uhr + (t or 0.03), co)
	coroutine.yield()
	return t or 0.03
end
function task.cancel() end
wait = task.wait
spawn = task.spawn
delay = task.delay

-- ---------------- signals ----------------
local function signal()
	local s = { verbindungen = {} }
	function s:Connect(f)
		local v = { f = f, an = true }
		function v:Disconnect() v.an = false end
		v.Connected = true
		table.insert(s.verbindungen, v)
		return v
	end
	s.Once = s.Connect
	function s:Fire(...)
		for _, v in table.clone(s.verbindungen) do
			if v.an then task.spawn(v.f, ...) end
		end
	end
	function s:Wait()
		local co = coroutine.running()
		local v
		v = s:Connect(function(...) v:Disconnect() fortsetzen(co, ...) end)
		return coroutine.yield()
	end
	return s
end
M.signal = signal

-- ---------------- Instances ----------------
local IST = {
	BasePart = { Part = 1, WedgePart = 1, Seat = 1, VehicleSeat = 1, MeshPart = 1, TrussPart = 1, CornerWedgePart = 1, SpawnLocation = 1, UnionOperation = 1 },
	GuiObject = { Frame = 1, TextLabel = 1, TextButton = 1, ImageLabel = 1, ImageButton = 1, ScrollingFrame = 1, ViewportFrame = 1, CanvasGroup = 1, TextBox = 1 },
	LuaSourceContainer = { Script = 1, LocalScript = 1, ModuleScript = 1 },
	Constraint = { HingeConstraint = 1, WeldConstraint = 1 },
	Light = { SpotLight = 1, PointLight = 1, SurfaceLight = 1 },
}
local Inst = {}
local alleInstanzen = 0
local function istPart(k) return IST.BasePart[k] ~= nil end

local methoden = {}
local function neueInstanz(klasse)
	alleInstanzen += 1
	local o = { __klasse = klasse, __kinder = {}, __attr = {}, __props = { Name = klasse }, __signale = {}, __attrSignale = {} }
	return setmetatable(o, Inst)
end
M.anzahl = function() return alleInstanzen end

local function propSignal(o, name)
	o.__signale[name] = o.__signale[name] or signal()
	return o.__signale[name]
end

Inst.__index = function(o, k)
	local m = methoden[k]
	if m then return m end
	local props = rawget(o, "__props")
	local v = props[k]
	if v ~= nil then return v end
	if k == "ClassName" then return o.__klasse end
	if k == "Parent" then return nil end
	if istPart(o.__klasse) then
		if k == "CFrame" then return C.new() end
		if k == "Position" then return (props.CFrame or C.new()).Position end
		if k == "Size" then return V.new(4, 1, 2) end
		if k == "Orientation" then return V.new(0,0,0) end
		if k == "AssemblyLinearVelocity" or k == "AssemblyAngularVelocity" or k == "Velocity" then return V.new(0,0,0) end
		if k == "AssemblyMass" or k == "Mass" then return 10 end
		if k == "Transparency" then return 0 end
		if k == "Anchored" then return false end
	end
	if k == "Rotation" and not istPart(o.__klasse) then return 0 end
	if k == "Position" and not istPart(o.__klasse) then return UDim2.new(0, 0, 0, 0) end
	if k == "Changed" then return propSignal(o, "__changed") end
	-- children by name
	for _, kind in o.__kinder do
		if kind.Name == k then return kind end
	end
	-- known signals
	if k:match("^%u") and (k:match("ed$") or k:match("Added$") or k:match("Removing$") or k == "Heartbeat" or k == "RenderStepped" or k == "Stepped" or k == "Activated" or k == "Triggered" or k == "MouseButton1Click" or k == "OnClientEvent" or k == "OnServerEvent" or k == "InputBegan" or k == "InputEnded" or k == "Seated" or k == "MoveToFinished" or k == "Equipped" or k == "Unequipped" or k == "Touched" or k == "PromptTriggered") then
		local s = signal()
		props[k] = s
		return s
	end
	return nil
end
Inst.__newindex = function(o, k, v)
	local props = rawget(o, "__props")
	if k == "Parent" then
		local alt = props.Parent
		if alt == v then return end
		if alt then
			local kinder = alt.__kinder
			for i, kind in kinder do if kind == o then table.remove(kinder, i) break end end
		end
		props.Parent = v
		if v then
			table.insert(v.__kinder, o)
			local cs = rawget(v.__props, "ChildAdded")
			if cs then cs:Fire(o) end
			local a = v
			while a do
				local ds = rawget(a.__props, "DescendantAdded")
				if ds then ds:Fire(o) end
				a = a.__props.Parent
			end
		end
		return
	end
	if istPart(o.__klasse) and k == "Position" then
		local alt = props.CFrame or C.new()
		props.CFrame = cf(v, alt.r)
		return
	end
	if k == "PrimaryPart" or k == "Source" then props[k] = v return end
	if k == "Shape" and v == nil then error("Shape nil") end
	local alt = props[k]
	props[k] = v
	if alt ~= v then
		local s = rawget(o, "__signale")[k]
		if s then s:Fire() end
	end
end
Inst.__tostring = function(o) return o.Name end

function methoden.IsA(o, k)
	if o.__klasse == k or k == "Instance" then return true end
	local g = IST[k]
	if g and g[o.__klasse] then return true end
	if k == "PVInstance" and (istPart(o.__klasse) or o.__klasse == "Model") then return true end
	if k == "GuiBase2d" or k == "LayerCollector" then return o.__klasse == "ScreenGui" or o.__klasse == "SurfaceGui" or o.__klasse == "BillboardGui" end
	return false
end
function methoden.GetChildren(o) return table.clone(o.__kinder) end
function methoden.GetDescendants(o)
	local l = {}
	local function rek(x) for _, k in x.__kinder do table.insert(l, k) rek(k) end end
	rek(o)
	return l
end
function methoden.FindFirstChild(o, name, rek)
	for _, k in o.__kinder do if k.Name == name then return k end end
	if rek then for _, k in o.__kinder do local f = k:FindFirstChild(name, true) if f then return f end end end
	return nil
end
function methoden.FindFirstChildOfClass(o, kl)
	for _, k in o.__kinder do if k.__klasse == kl then return k end end
	return nil
end
function methoden.FindFirstChildWhichIsA(o, kl, rek)
	for _, k in o.__kinder do if k:IsA(kl) then return k end end
	if rek then for _, k in o.__kinder do local f = k:FindFirstChildWhichIsA(kl, true) if f then return f end end end
end
function methoden.FindFirstAncestorOfClass(o, kl)
	local p = o.Parent
	while p do if p.__klasse == kl then return p end p = p.Parent end
end
function methoden.FindFirstAncestor(o, n)
	local p = o.Parent
	while p do if p.Name == n then return p end p = p.Parent end
end
function methoden.IsDescendantOf(o, x)
	local p = o.Parent
	while p do if p == x then return true end p = p.Parent end
	return false
end
function methoden.WaitForChild(o, name, timeout)
	local f = o:FindFirstChild(name)
	if f then return f end
	local t0 = uhr
	while uhr - t0 < (timeout or 6) do
		task.wait(0.1)
		f = o:FindFirstChild(name)
		if f then return f end
	end
	if not timeout then print("WARN: infinite yield possible on " .. o:GetFullName() .. ":WaitForChild(" .. name .. ")") end
	return nil
end
function methoden.GetFullName(o)
	local n = o.Name
	local p = o.Parent
	while p do n = p.Name .. "." .. n p = p.Parent end
	return n
end
function methoden.Destroy(o)
	o.Parent = nil
	rawset(o, "__zerstoert", true)
	for _, k in table.clone(o.__kinder) do k:Destroy() end
end
methoden.Remove = methoden.Destroy
function methoden.ClearAllChildren(o) for _, k in table.clone(o.__kinder) do k:Destroy() end end
function methoden.Clone(o)
	local n = neueInstanz(o.__klasse)
	for k, v in o.__props do if k ~= "Parent" then n.__props[k] = v end end
	for k, v in o.__attr do n.__attr[k] = v end
	for _, k in o.__kinder do k:Clone().Parent = n end
	return n
end
function methoden.SetAttribute(o, k, v)
	assert(type(k) == "string", "attribute name")
	local tv = type(v)
	if not (v == nil or tv == "string" or tv == "number" or tv == "boolean" or typeof(v) == "Vector3" or typeof(v) == "CFrame" or getmetatable(v) == C3) then
		error("SetAttribute: unsupported type for " .. k .. ": " .. tv)
	end
	o.__attr[k] = v
	local s = o.__attrSignale[k]
	if s then s:Fire() end
end
function methoden.GetAttribute(o, k) return o.__attr[k] end
function methoden.GetAttributes(o) return table.clone(o.__attr) end
function methoden.GetAttributeChangedSignal(o, k)
	o.__attrSignale[k] = o.__attrSignale[k] or signal()
	return o.__attrSignale[k]
end
function methoden.GetPropertyChangedSignal(o, k) return propSignal(o, k) end
-- models / parts
local function teileVon(o)
	local l = {}
	if istPart(o.__klasse) then table.insert(l, o) end
	for _, d in o:GetDescendants() do if istPart(d.__klasse) then table.insert(l, d) end end
	return l
end
function methoden.GetPivot(o)
	if istPart(o.__klasse) then return o.CFrame end
	if o.PrimaryPart then return o.PrimaryPart.CFrame end
	local t = teileVon(o)
	if #t > 0 then return cf(t[1].Position, I3) end
	return C.new()
end
function methoden.PivotTo(o, ziel)
	assert(getmetatable(ziel) == C, "PivotTo needs a CFrame")
	local alt = o:GetPivot()
	local delta = ziel * alt:Inverse()
	for _, t in teileVon(o) do
		t.__props.CFrame = delta * (t.__props.CFrame or C.new())
	end
end
function methoden.SetPrimaryPartCFrame(o, z) o:PivotTo(z) end
function methoden.GetBoundingBox(o) return o:GetPivot(), V.new(10, 10, 10) end
function methoden.GetExtentsSize(o) return V.new(10, 10, 10) end
function methoden.ScaleTo() end
-- noop-ish methods
for _, n in { "SetNetworkOwner", "SetNetworkOwnershipAuto", "ApplyImpulse", "ApplyAngularImpulse", "SetStateEnabled", "MoveTo", "BreakJoints", "MakeJoints",
	"FillBlock", "FillCylinder", "FillBall", "FillRegion", "SetMaterialColor", "Clear", "Play", "Stop", "Cancel", "Pause", "AddTag", "RemoveTag", "Disable", "Enable", "UnequipTools",
	"BindToClose", "SetCore", "SetCoreGuiEnabled", "ReplaceMaterial", "Chat", "TakeDamage" } do
	methoden[n] = function() end
end
function methoden.GetNetworkOwner() return nil end
-- monetization / social (tests can set M.passes[id] = true)
M.passes = {}
M.kaeufe = {}
function methoden.UserOwnsGamePassAsync(o, userId, id) return M.passes[id] == true end
function methoden.PromptGamePassPurchase(o, p, id) table.insert(M.kaeufe, { "pass", id }) end
function methoden.PromptProductPurchase(o, p, id) table.insert(M.kaeufe, { "produkt", id }) end
function methoden.PromptPremiumPurchase() end
function methoden.IsFriendsWith(o, id) return M.freunde and M.freunde[id] == true or false end
function methoden.IsInGroup(o, id) return M.gruppe == id end
function methoden.PromptGameInvite() table.insert(M.kaeufe, { "einladung" }) end
function methoden.CanSendGameInviteAsync() return true end
function methoden.AwardBadge(o, userId, id) table.insert(M.kaeufe, { "badge", id }) return true end
function methoden.UserHasBadgeAsync() return false end
function methoden.HasTag() return false end
function methoden.EquipTool(o, t) local c = o.Parent t.Parent = c end
function methoden.Sit(seat, hum)
	seat.Occupant = hum
	hum.SeatPart = seat
	local w = neueInstanz("Weld") w.Name = "SeatWeld" w.Parent = seat
end
function methoden.LoadAnimation(o, a)
	local spur = neueInstanz("AnimationTrack")
	return spur
end
function methoden.IsStudio() return true end
function methoden.IsServer() return M.istServer end
function methoden.IsClient() return not M.istServer end
function methoden.GetService(o, n)
	return M.dienst(n)
end
-- remotes
function methoden.FireClient(o, p, ...)
	M.log("FireClient " .. o.Name, p, ...)
	local s = rawget(o.__props, "OnClientEvent")
	if s then s:Fire(...) end
end
function methoden.FireAllClients(o, ...)
	M.log("FireAllClients " .. o.Name, nil, ...)
	local s = rawget(o.__props, "OnClientEvent")
	if s then s:Fire(...) end
end
function methoden.FireServer(o, ...)
	local s = rawget(o.__props, "OnServerEvent")
	if s then s:Fire(M.spieler, ...) end
end
function methoden.InvokeServer(o, ...)
	local f = o.__props.OnServerInvoke
	if f then return f(M.spieler, ...) end
end
function methoden.Raycast() return nil end
function methoden.GetPartBoundsInBox() return {} end
function methoden.GetPartBoundsInRadius() return {} end
function methoden.BulkMoveTo(ws, teile, cfs) for i, t in teile do t.CFrame = cfs[i] end end

Instance = {}
function Instance.new(klasse, eltern)
	local o = neueInstanz(klasse)
	if klasse == "Humanoid" then
		o.__props.HipHeight = 2
		o.__props.WalkSpeed = 16
	end
	if klasse == "Animator" then end
	if eltern then o.Parent = eltern end
	return o
end

-- ---------------- services ----------------
local dienste = {}
local game = neueInstanz("DataModel")
game.Name = "game"
_G_game = game
M.game = game
function M.dienst(n)
	if dienste[n] then return dienste[n] end
	local d = neueInstanz(n)
	d.Name = n
	if n == "Workspace" then d.__props.Terrain = neueInstanz("Terrain") d.Terrain.Parent = d end
	if n == "Players" then
		function d.GetPlayers() local l = {} for _, k in d.__kinder do if k.__klasse == "Player" then table.insert(l, k) end end return l end
		function d.GetPlayerByUserId(_, id) for _, k in d.__kinder do if k.__klasse == "Player" and k.UserId == id then return k end end return nil end
		d.__props.GetPlayers = nil
		methoden.GetPlayers = function(x) local l = {} for _, k in x.__kinder do if k.__klasse == "Player" then table.insert(l, k) end end return l end
		methoden.GetPlayerFromCharacter = function(x, c) for _, p in x:GetPlayers() do if p.Character == c then return p end end return nil end
		methoden.CreateHumanoidModelFromDescription = function(x, desc, typ)
			if desc then M.npcBeschreibungen = M.npcBeschreibungen or {} table.insert(M.npcBeschreibungen, desc) end
			local m = neueInstanz("Model")
			local hum = neueInstanz("Humanoid") hum.__props.HipHeight = 2 hum.Parent = m
			local w = Instance.new("Part") w.Name = "HumanoidRootPart" w.Size = V.new(2, 2, 1) w.Parent = m
			local kopf = Instance.new("Part") kopf.Name = "Head" kopf.Size = V.new(1, 1, 1) kopf.Parent = m
			for _, n in { "LeftLowerLeg", "RightLowerLeg", "LeftFoot", "RightFoot", "UpperTorso" } do local t = Instance.new("Part") t.Name = n t.Parent = m end
			m.PrimaryPart = w
			return m
		end
		methoden.GetUserThumbnailAsync = function() return "rbxthumb://x", true end
	end
	if n == "DataStoreService" then
		methoden.GetDataStore = function()
			local speicher = {}
			return { GetAsync = function(_, k) return speicher[k] end, SetAsync = function(_, k, v) speicher[k] = v end, UpdateAsync = function(_, k, f) speicher[k] = f(speicher[k]) end }
		end
	end
	if n == "TweenService" then
		methoden.Create = function(_, obj, info, ziel)
			return { Play = function() for k, v in ziel do obj[k] = v end end, Cancel = function() end, Completed = signal() }
		end
	end
	if n == "Lighting" then end
	if n == "StarterPlayer" then
		local sps = neueInstanz("StarterPlayerScripts") sps.Name = "StarterPlayerScripts" sps.Parent = d
		local scs = neueInstanz("StarterCharacterScripts") scs.Name = "StarterCharacterScripts" scs.Parent = d
	end
	if n == "UserInputService" then d.__props.TouchEnabled = false end
	d.Parent = game
	dienste[n] = d
	return d
end
workspace = M.dienst("Workspace")
workspace.__props.CurrentCamera = Instance.new("Camera")
game.__props.Workspace = workspace
M.log = function() end

-- run the scheduler until virtual time t
function M.laufen(bis, schritt)
	schritt = schritt or 1 / 30
	local rs = M.dienst("RunService")
	while uhr < bis do
		uhr += schritt
		-- heartbeat
		local hb = rawget(rs.__props, "Heartbeat")
		if hb then hb:Fire(schritt) end
		local rsd = rawget(rs.__props, "RenderStepped")
		if rsd then rsd:Fire(schritt) end
		local runde = true
		while runde do
			runde = false
			table.sort(wartend, function(a, b) return a.zeit < b.zeit end)
			if wartend[1] and wartend[1].zeit <= uhr then
				local w = table.remove(wartend, 1)
				fortsetzen(w.co, table.unpack(w.args, 1, w.args.n))
				runde = true
			end
		end
	end
end
function M.zeit() return uhr end

function M.spielerErzeugen(name)
	local P = M.dienst("Players")
	local p = neueInstanz("Player")
	p.Name = name
	p.__props.DisplayName = name
	p.__props.UserId = 12345
	local bp = neueInstanz("Backpack") bp.Name = "Backpack" bp.Parent = p
	local sg = neueInstanz("StarterGear") sg.Name = "StarterGear" sg.Parent = p
	local pg = neueInstanz("PlayerGui") pg.Name = "PlayerGui" pg.Parent = p
	local ps = neueInstanz("PlayerScripts") ps.Name = "PlayerScripts" ps.Parent = p
	local char = M.dienst("Players"):CreateHumanoidModelFromDescription()
	char.Name = name
	char.Parent = workspace
	p.__props.Character = char
	p.Parent = P
	local s = rawget(P.__props, "PlayerAdded")
	if s then s:Fire(p) end
	M.spieler = p
	P.__props.LocalPlayer = p
	return p
end
return M
