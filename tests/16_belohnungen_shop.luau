-- Rewards and shop: daily streak, playtime gifts, achievements, VIP multiplier, starter pack,
-- developer product receipts (no double delivery), exclusive car and paint colors
M.log = function() end
lade("gen", Q.gen)()
M.laufen(1)
lade("inst", Q.inst)()
local SSS = game:GetService("ServerScriptService")
for _, s in workspace:GetDescendants() do if s:IsA("Script") then task.spawn(lade(s.Name, s.Source, { script = s })) end end
for _, s in SSS:GetChildren() do if s:IsA("Script") then task.spawn(lade(s.Name, s.Source, { script = s })) end end
M.laufen(2)
local p = M.spielerErzeugen("Lukas")
local cl = game:GetService("StarterPlayer").StarterPlayerScripts.FuehrerscheinClient
task.spawn(lade("client", cl.Source, { script = cl }))
M.laufen(8)
local aktion = game.ReplicatedStorage.Fuehrerschein.Aktion
local function frage(was, e) return aktion.OnServerInvoke(p, was, e) end
local function pruefe(name, ok) print((ok and "OK  " or "FAIL") .. " " .. name) if not ok then error("check failed: " .. name) end end
local function geld() return p:GetAttribute("Geld") end

-- daily reward
local b = frage("belohnungen")
pruefe("daily reward ready", b.taeglich.bereit == true and b.taeglich.tag == 1)
pruefe("red dot", (p:GetAttribute("BelohnungenOffen") or 0) >= 1)
local vorher = geld()
local r = frage("belohnungAbholen", { art = "taeglich" })
pruefe("daily claimed: " .. tostring(r.text or r.fehler), r.text ~= nil and geld() == vorher + 150)
pruefe("only once a day", frage("belohnungAbholen", { art = "taeglich" }).fehler ~= nil)
frage("dev", { befehl = "neuerTag" })
vorher = geld()
r = frage("belohnungAbholen", { art = "taeglich" })
pruefe("day 2 in a row", r.status.taeglich.serie == 2 and geld() == vorher + 250)

-- playtime gifts
pruefe("gift not yet", frage("belohnungAbholen", { art = "spielzeit", nr = 1 }).fehler ~= nil)
frage("dev", { befehl = "spielzeit", min = 11 })
vorher = geld()
r = frage("belohnungAbholen", { art = "spielzeit", nr = 1 })
pruefe("10 min gift", r.text ~= nil and geld() == vorher + 100)
pruefe("25 min gift not yet", frage("belohnungAbholen", { art = "spielzeit", nr = 2 }).fehler ~= nil)

-- achievements: driver's license class B
frage("dev", { befehl = "lizenz" })
vorher = geld()
r = frage("belohnungAbholen", { art = "erfolg", id = "klasseB" })
pruefe("class B achievement", r.text ~= nil and geld() == vorher + 500)
pruefe("class B only once", frage("belohnungAbholen", { art = "erfolg", id = "klasseB" }).fehler ~= nil)
local km
for _, e in frage("belohnungen").erfolge do if e.id == "km" then km = e end end
pruefe("tiers shown ahead", km and #km.stufen == 4 and km.abgeholt == 0)

-- shop status
local s = frage("shop")
pruefe("shop lists passes and products", #s.passes == 4 and #s.produkte >= 6 and s.geldFaktor == 1)

-- VIP: earned coins x2, admin money not
r = frage("dev", { befehl = "kauf", key = "vip" })
pruefe("vip test pass: " .. tostring(r.text), p:GetAttribute("VIP") == true and p:GetAttribute("GeldFaktor") == 2)
frage("dev", { befehl = "spielzeit", min = 20 })
vorher = geld()
frage("belohnungAbholen", { art = "spielzeit", nr = 2 })
pruefe("vip doubles earned coins", geld() == vorher + 400)
vorher = geld()
frage("adminGeld", 1000)
pruefe("no bonus on admin money", geld() == vorher + 1000)

-- starter pack (developer product, test purchase)
vorher = geld()
frage("dev", { befehl = "kauf", key = "starter" })
pruefe("starter pack coins without bonus", geld() == vorher + 7500)
pruefe("boost running", (p:GetAttribute("BoostBis") or 0) > os.time() and p:GetAttribute("GeldFaktor") == 3)
local nochDa = false
for _, pr in frage("shop").produkte do if pr.key == "starter" then nochDa = true end end
pruefe("starter pack only once", not nochDa)

-- real receipt: delivered exactly once
local Shop = require(SSS.FuehrerscheinServer.Shop)
for _, pr in Shop.PRODUKTE do if pr.key == "coins1" then pr.id = 4242 end end
local MS = game:GetService("MarketplaceService")
vorher = geld()
local e1 = MS.ProcessReceipt({ PlayerId = p.UserId, ProductId = 4242, PurchaseId = "kauf-1" })
local e2 = MS.ProcessReceipt({ PlayerId = p.UserId, ProductId = 4242, PurchaseId = "kauf-1" })
pruefe("receipt granted once", e1 == Enum.ProductPurchaseDecision.PurchaseGranted and e2 == Enum.ProductPurchaseDecision.PurchaseGranted and geld() == vorher + 2500)
pruefe("unknown product not granted", MS.ProcessReceipt({ PlayerId = p.UserId, ProductId = 999, PurchaseId = "kauf-2" }) == Enum.ProductPurchaseDecision.NotProcessedYet)

-- exclusive car
r = frage("autoKaufen", "gs_night")
pruefe("exclusive car needs the pass", r.fehler ~= nil)
frage("dev", { befehl = "kauf", key = "nacht" })
local besitzt = false
for _, a in frage("meineAutos").katalog do if a.typ == "gs_night" and a.gehoert then besitzt = true end end
pruefe("pass puts the car into the garage", besitzt)
p.Character:PivotTo(CFrame.new(60, 3, -376))
r = frage("autoHolen", { typ = "gs_night", farbe = 1 })
local auto = workspace:FindFirstChild("Auto_Lukas")
pruefe("night edition built: " .. tostring(r.text or r.fehler), auto ~= nil and auto:GetAttribute("MaxTempo") == 195)
local neon = false
for _, t in auto:GetChildren() do if t.Name == "Tuning_Neon" then neon = true end end
pruefe("night edition has underglow", neon)
frage("autoWeg")
M.laufen(M.zeit() + 1)

-- exclusive paint colors: VIP has gold (9), Paint Studio needed for purple (11)
frage("autoKaufen", "kleinwagen")
r = frage("autoHolen", { typ = "kleinwagen", farbe = 9 })
pruefe("VIP gold color works", r.text ~= nil)
frage("autoWeg")
M.laufen(M.zeit() + 1)
r = frage("autoHolen", { typ = "kleinwagen", farbe = 11 })
pruefe("purple needs Paint Studio", r.fehler ~= nil)
frage("dev", { befehl = "kauf", key = "garage" })
r = frage("autoHolen", { typ = "kleinwagen", farbe = 11 })
pruefe("purple with Paint Studio", r.text ~= nil)

-- client windows open without errors
local gui = p.PlayerGui
_G.BelohnungenOeffnen()
_G.ShopOeffnen()
pruefe("windows", gui:FindFirstChild("Belohnungen") ~= nil and gui:FindFirstChild("Shop") ~= nil)
print("done")
