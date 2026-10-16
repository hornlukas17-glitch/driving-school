-- Chaos driving school: crazy instructors with speech bubbles and chaos events (cows, ducks, banana, UFO, gags).
-- Events must never touch the car: no mistakes, no physics, everything anchored and without collision.
local events = {}
M.log = function(name, p, info)
	if name == "FireClient Fahrstunde" and type(info) == "table" then
		table.insert(events, info)
		if info.typ == "chaos" or info.typ == "geld" or info.typ == "start" then
			print("  event:", info.typ, info.titel or info.sprecher or "", info.text or info.grund or "", info.betrag or "")
		end
	end
end
lade("gen", Q.gen)()
M.laufen(1)
lade("inst", Q.inst)()
local SSS = game:GetService("ServerScriptService")
for _, s in workspace:GetDescendants() do if s:IsA("Script") then task.spawn(lade(s.Name, s.Source, { script = s })) end end
for _, s in SSS:GetChildren() do if s:IsA("Script") then task.spawn(lade(s.Name, s.Source, { script = s })) end end
M.laufen(2)
require(game.ReplicatedStorage.Fuehrerschein.Verkehr).fahrzeuge = {}
local p = M.spielerErzeugen("Lukas")
local cl = game:GetService("StarterPlayer").StarterPlayerScripts.FuehrerscheinClient
task.spawn(lade("client", cl.Source, { script = cl }))
M.laufen(3)
local menue = p.PlayerGui:FindFirstChild("Startbildschirm")
for _, k in menue:GetChildren() do if k.Text == "PLAY" then k.Activated:Fire() end end
M.laufen(M.zeit() + 5)
local function pruefe(name, ok) print((ok and "OK  " or "FAIL") .. " " .. name) if not ok then error("check failed: " .. name) end end
local aktion = game.ReplicatedStorage.Fuehrerschein.Aktion
local function frage(was, e) return aktion.OnServerInvoke(p, was, e) end
local hum = p.Character.Humanoid
local Chaos = require(SSS.FuehrerscheinServer.Chaos)
local function letztes(typ)
	for i = #events, 1, -1 do if events[i].typ == typ then return events[i] end end
end

-- 1) a lesson gets a random crazy instructor
local r = frage("dev", { befehl = "lektion", nr = 1 })
M.laufen(M.zeit() + 2) -- the first drive from PLAY is replaced, its car disappears
local auto = workspace:FindFirstChild("Fahrschulauto_Lukas")
auto.Fahrersitz:Sit(hum)
M.laufen(M.zeit() + 8)
local st = Chaos.ctx.lektionen[p]
pruefe("lesson has a persona", st and st.chaos and st.chaos.lehrer and st.chaos.lehrer.name ~= nil)
local name = st.chaos.lehrer.name
print("instructor:", name)
pruefe("start message names the instructor", letztes("start").sprecher == name)
local figur = auto:FindFirstChild("Fahrlehrer")
pruefe("instructor sits in the car with the persona name", figur and figur:FindFirstChildOfClass("Humanoid").DisplayName == name .. " (Instructor)")
local blase = figur.Head:FindFirstChild("Sprechblase")
pruefe("speech bubble with a start line", blase ~= nil and table.find(st.chaos.lehrer.start, blase.Text.Text) ~= nil)
pruefe("gate messages use the persona name", letztes("ziel").sprecher == name)
print("  says:", blase.Text.Text)
for _, l in Chaos.LEHRER do
	for _, pool in { "start", "fehler", "unfall", "lob", "leerlauf", "event", "ende_gut", "ende_schlecht" } do
		pruefe(l.name .. " has " .. pool .. " lines", #l[pool] > 0)
	end
	pruefe(l.name .. " has a gag", l.gag.titel and l.gag.text and l.gag.sagt)
end

-- put the car on the motorway, driving west (-X), nothing else around
local chassis = st.chassis
local y = chassis.Position.Y
local function setzen(x, z)
	chassis.CFrame = CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(90), 0)
	chassis.AssemblyLinearVelocity = Vector3.new(-20, 0, 0)
end
setzen(200, -520)
st.chaos.naechstesEvent = math.huge
M.laufen(M.zeit() + 0.5)
local physikVorher = {}
for _, x in auto:GetDescendants() do if x:IsA("BasePart") then physikVorher[x] = tostring(x.Anchored) .. tostring(x.CanCollide) .. tostring(x.Size) end end

local function alleTeileHarmlos(m)
	for _, x in m:GetDescendants() do
		if x:IsA("BasePart") and (not x.Anchored or x.CanCollide or x.CanTouch or x.CanQuery) then return false end
	end
	return true
end
local function fahren(vonX, bisX, z)
	for x = vonX, bisX, -2 do
		setzen(x, z)
		M.laufen(M.zeit() + 0.11)
	end
end

-- 2) cows: drive right through them -> hit, banner, shake, instructor screams, NO mistakes
local fehlerVorher = st.fehler
local geldVorher = p:GetAttribute("Geld")
local e = Chaos.eventStarten(p, st, "kuehe")
pruefe("cow event spawned", e ~= nil and #e.tiere == 3 and e.modell.Parent == Chaos.ordner)
pruefe("cow banner", letztes("chaos").titel:find("COWS") ~= nil)
pruefe("cows are anchored and never collide", alleTeileHarmlos(e.modell))
local kuh1 = e.tiere[1].m
local vorher = kuh1:GetPivot().Position
M.laufen(M.zeit() + 1)
pruefe("cows walk across the road", (kuh1:GetPivot().Position - vorher).Magnitude > 1.5)
-- drive straight through the cow lane (cows walk towards z > -520 side? use the first cow's position)
local kz = e.tiere[1].m:GetPivot().Position.Z
fahren(200 - 2, 100, kz)
pruefe("hit a cow", e.getroffen)
local b = letztes("chaos")
pruefe("hit banner with camera shake", b.farbe == "rot" and b.wackeln == true)
pruefe("instructor reacts to the crash", table.find(st.chaos.lehrer.unfall, blase.Text.Text) ~= nil)
pruefe("chaos events never count as mistakes", st.fehler == fehlerVorher)
pruefe("no coins for hitting", p:GetAttribute("Geld") == geldVorher)
fahren(100, 60, kz)
pruefe("event over after passing", st.chaos.event == nil)

-- 3) ducks: go around them (other lane) -> dodge bonus
setzen(200, -520)
M.laufen(M.zeit() + 0.3)
e = Chaos.eventStarten(p, st, "enten")
pruefe("duck family spawned (mum + 5 babies)", #e.tiere == 6 and alleTeileHarmlos(e.modell))
fahren(198, 100, -545)  -- 25 studs to the side
pruefe("ducks not hit", not e.getroffen)
local g = letztes("geld")
pruefe("dodge bonus paid", g and g.grund == "The ducks made it!" and p:GetAttribute("Geld") > geldVorher)
pruefe("praise from the instructor", table.find(st.chaos.lehrer.lob, blase.Text.Text) ~= nil)

-- 4) banana peel: hit it
setzen(200, -520)
M.laufen(M.zeit() + 0.3)
e = Chaos.eventStarten(p, st, "banane")
local bz = e.tiere[1].m:GetPivot().Position.Z
fahren(198, 100, bz)
pruefe("banana slip", e.getroffen and letztes("chaos").titel:find("SLI") ~= nil)
pruefe("still no mistakes", st.fehler == fehlerVorher)
pruefe("banana makes the car spin (client)", letztes("chaos").rutschen ~= nil and _G.Rutschen ~= nil)
pruefe("crashes while spinning on the banana don't count", Chaos.schonzeit(st))
-- test menu command starts a chosen event (Studio only)
local rc = frage("dev", { befehl = "chaos", art = "kuehe" })
pruefe("dev command starts an event", rc.text == "Chaos event: kuehe" and st.chaos.event and st.chaos.event.art == "kuehe")
Chaos.eventStarten(p, st, "kuehe") -- (no second event while one runs)
st.chaos.event.modell:Destroy()
st.chaos.event = nil

-- new events: chickens, shopping cart, giant tire, mud puddle, clown camera
local function neuesEvent(art)
	setzen(200, -520)
	M.laufen(M.zeit() + 0.3)
	local ev = Chaos.eventStarten(p, st, art)
	pruefe(art .. " spawned and harmless", ev ~= nil and alleTeileHarmlos(ev.modell))
	return ev
end
e = neuesEvent("huehner")
pruefe("5 chickens", #e.tiere == 5)
M.laufen(M.zeit() + 0.5)
local h1 = e.tiere[1]
fahren(198, 90, h1.m:GetPivot().Position.Z)
print("  chickens hit:", e.getroffen)
e = neuesEvent("wagen")
local wz = e.tiere[1].m:GetPivot().Position.Z
fahren(198, 90, -545)
pruefe("shopping cart dodged", not e.getroffen and letztes("geld").grund == "Dodged the shopping cart!")
e = neuesEvent("reifen")
local r0 = e.tiere[1].m:GetPivot().Position
M.laufen(M.zeit() + 1)
pruefe("giant tire rolls towards the car", e.tiere[1].m:GetPivot().Position.X > r0.X + 5)
fahren(198, 90, e.tiere[1].m:GetPivot().Position.Z)
pruefe("giant tire hit", e.getroffen and letztes("chaos").titel:find("BOOOING") ~= nil)
e = neuesEvent("pfuetze")
local pz, flecken = e.tiere[1].m:GetPivot().Position.Z, 0
for x = 198, 90, -2 do
	setzen(x, pz)
	M.laufen(M.zeit() + 0.11)
	if e.getroffen and flecken == 0 then flecken = #p.PlayerGui.ChaosBanner:GetChildren() - 1 end
end
pruefe("mud splash on the screen", e.getroffen and letztes("chaos").matsch == true and flecken >= 5)
local geld3 = p:GetAttribute("Geld")
e = neuesEvent("clown")
fahren(198, 90, -520)
pruefe("clown photo: flash + coins", e.geblitzt and letztes("chaos").blitz == true and p:GetAttribute("Geld") > geld3)

-- 5) UFO: drive through the beam -> alien bonus
setzen(200, -520)
M.laufen(M.zeit() + 0.3)
local geld2 = p:GetAttribute("Geld")
e = Chaos.eventStarten(p, st, "ufo")
pruefe("UFO is harmless", alleTeileHarmlos(e.modell))
fahren(198, 90, e.mitte.Z)
pruefe("drove through the beam", e.durchStrahl)
pruefe("alien bonus", p:GetAttribute("Geld") > geld2 and letztes("chaos").titel:find("BEAMED") ~= nil)

-- 6) gag: banner + instructor line, no objects
Chaos.eventStarten(p, st, "gag")
pruefe("gag banner", letztes("chaos").farbe == "lila" and blase.Text.Text == st.chaos.lehrer.gag.sagt)

-- 7) the car was never changed by any event
local gleich = true
for x, w in physikVorher do
	if tostring(x.Anchored) .. tostring(x.CanCollide) .. tostring(x.Size) ~= w then gleich = false print("changed:", x.Name) end
end
pruefe("car parts unchanged (driving feel stays the same)", gleich)

-- 8) events come by themselves while driving
st.chaos.naechstesEvent = os.clock() - 1
setzen(200, -520)
M.laufen(M.zeit() + 0.3)
pruefe("event starts by itself while driving", st.chaos.event ~= nil or letztes("chaos").farbe == "lila")
print("automatic event:", st.chaos.event and st.chaos.event.art or "gag")

-- 9) mistakes make the instructor react
local alt = blase.Text.Text
Chaos.reaktion(p, st, "fehler")
pruefe("mistake reaction", table.find(st.chaos.lehrer.fehler, blase.Text.Text) ~= nil)

-- 10) lesson ends -> everything cleaned up, next lesson has another instructor
hum.SeatPart = nil
auto.Fahrersitz.Occupant = nil
for _ = 1, 60 do
	M.laufen(M.zeit() + 0.5)
	if not Chaos.ctx.lektionen[p] then break end
end
M.laufen(M.zeit() + 6)
pruefe("lesson over", Chaos.ctx.lektionen[p] == nil)
pruefe("chaos objects removed", #Chaos.ordner:GetChildren() == 0)
local erster = name
local naechster = Chaos.lehrerWaehlen(p)
pruefe("next lesson gets another instructor", naechster.name ~= erster)
print("chaos ok")
