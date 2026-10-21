-- v64: new menu bar look: light tiles + yellow edge, 60 px buttons, picture icons (where an ID is set),
-- Blind/Party hidden (green zones), camera button only on touch devices, fold-out width = visible buttons only
M.log = function() end
lade("gen", Q.gen)()
M.laufen(1)
lade("inst", Q.inst)()
local SSS = game:GetService("ServerScriptService")
for _, s in workspace:GetDescendants() do if s:IsA("Script") then task.spawn(lade(s.Name, s.Source, { script = s })) end end
for _, s in SSS:GetChildren() do if s:IsA("Script") then task.spawn(lade(s.Name, s.Source, { script = s })) end end
M.laufen(2)
local function pruefe(name, ok) print((ok and "OK  " or "FAIL") .. " " .. name) if not ok then error("check failed: " .. name) end end
local Stil = require(game.ReplicatedStorage.Fuehrerschein.LeisteStil)
Stil.BILDER.Shop = 123456 -- pretend Lukas uploaded the cart
local p = M.spielerErzeugen("Lukas")
local cl = game:GetService("StarterPlayer").StarterPlayerScripts.FuehrerscheinClient
task.spawn(lade("client", cl.Source, { script = cl }))
M.laufen(M.zeit() + 4)

local gui = p.PlayerGui.CameraToggle
local leiste = gui.Klappe.Leiste
local sichtbar, versteckt = {}, {}
for _, k in leiste:GetChildren() do
	if k:IsA("TextButton") then
		if k.Visible ~= false then sichtbar[k.Name] = k else versteckt[k.Name] = k end
	end
end
for _, n in { "Shop", "Rewards", "Daily", "My Cars", "Record", "Settings", "Sabotage" } do
	pruefe("visible: " .. n, sichtbar[n] ~= nil)
end
pruefe("Blind hidden (green zone)", versteckt.Blind ~= nil)
pruefe("Party hidden (green zone)", versteckt.Party ~= nil)
pruefe("camera button hidden on PC (key V)", versteckt["1st (V)"] ~= nil)

local shop = sichtbar.Shop
pruefe("bigger tiles", shop.Size.X.Offset == Stil.GROESSE and shop.Size.Y.Offset == Stil.GROESSE)
pruefe("light tile", shop.BackgroundTransparency == 0 and shop:FindFirstChildOfClass("UIGradient") ~= nil)
local strokes = 0
for _, x in shop:GetChildren() do if x:IsA("UIStroke") then strokes += 1 end end
pruefe("exactly one (yellow) edge", strokes == 1 and shop.Rahmen.Color.R > 0.9)
pruefe("picture icon used for the shop", shop:FindFirstChild("IconBild") ~= nil and shop.IconBild.Image == "rbxassetid://123456" and shop.Icon.Visible == false)
pruefe("emoji stays where no picture exists", sichtbar.Settings:FindFirstChild("IconBild") == nil and sichtbar.Settings.Icon.Visible ~= false)
pruefe("dark label on the light tile", shop.Beschriftung.TextColor3.R < 0.2)

-- fold-out: open = width of the visible buttons only, closed = 0
_G.MenueSetzen(true)
M.laufen(M.zeit() + 1)
local n = 0
for _ in sichtbar do n += 1 end
local soll = n * Stil.GROESSE + (n - 1) * 5 + 4
pruefe(("open menu width %d = %d visible buttons"):format(gui.Klappe.Size.X.Offset, n), math.abs(gui.Klappe.Size.X.Offset - soll) <= 1)
pruefe("menu height fits the tiles", gui.Klappe.Size.Y.Offset >= Stil.GROESSE)
_G.MenueSetzen(false)
M.laufen(M.zeit() + 1)
pruefe("closed menu", gui.Klappe.Size.X.Offset == 0)

-- phone: camera button shows
local UIS = game:GetService("UserInputService")
UIS.TouchEnabled, UIS.KeyboardEnabled = true, false
local k = Instance.new("TextButton")
k.Name = "1st (V)"
Stil.knopf(k)
pruefe("camera button visible on a phone", k.Visible ~= false)
print("menu bar ok")
