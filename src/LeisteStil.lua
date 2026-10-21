-- 🎨 Menu bar style (v64): light tiles so Lukas' dark-navy icons stay readable, yellow edge, bigger buttons,
-- picture icons instead of emoji where we have them, fewer buttons (Blind/Party now start in the green zones).
-- Required by FuehrerscheinClient (that script is close to Roblox' 200,000-character limit).
local UIS = game:GetService("UserInputService")
local LeisteStil = {}

LeisteStil.GROESSE = 60
-- picture icons (upload in Studio: Asset Manager -> Images, then paste the number). 0 = the emoji stays.
LeisteStil.BILDER = {
	Shop = 0,
	Rewards = 0,
	Daily = 0,
	["My Cars"] = 0,
}
-- these start in the green zones on the parking lot now -> not needed in the bar
LeisteStil.VERSTECKT = { Blind = true, Party = true }
-- first/third person: PC players have the V key, only touch devices need the button
LeisteStil.NUR_TOUCH = { ["1st (V)"] = true }

local KACHEL_OBEN = Color3.fromRGB(252, 249, 240)
local KACHEL_UNTEN = Color3.fromRGB(222, 215, 198)
local NAVY = Color3.fromRGB(22, 28, 46)
local GELB = Color3.fromRGB(255, 200, 60)

function LeisteStil.nurTouch()
	return UIS.TouchEnabled and not UIS.KeyboardEnabled
end

local function rahmen(k, farbe)
	for _, s in k:GetChildren() do
		if s:IsA("UIStroke") then s:Destroy() end
	end
	local r = Instance.new("UIStroke")
	r.Name = "Rahmen"
	r.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	r.Color = farbe
	r.Thickness = 2
	r.Parent = k
	k.MouseEnter:Connect(function() r.Thickness = 3 end)
	k.MouseLeave:Connect(function() r.Thickness = 2 end)
	return r
end

local function verlauf(k, oben, unten)
	local v = k:FindFirstChildOfClass("UIGradient") or Instance.new("UIGradient")
	v.Rotation = 90
	v.Color = ColorSequence.new(oben, unten)
	v.Parent = k
end

-- one tile of the bar (called for every button, also ones added later)
function LeisteStil.knopf(k)
	if not k:IsA("TextButton") or k:GetAttribute("Gestylt") then return end
	k:SetAttribute("Gestylt", true)
	if LeisteStil.VERSTECKT[k.Name] or (LeisteStil.NUR_TOUCH[k.Name] and not LeisteStil.nurTouch()) then
		k.Visible = false
		return
	end
	local g = LeisteStil.GROESSE
	k.Size = UDim2.fromOffset(g, g)
	k.BackgroundColor3 = Color3.new(1, 1, 1)
	k.BackgroundTransparency = 0
	verlauf(k, KACHEL_OBEN, KACHEL_UNTEN)
	rahmen(k, GELB)
	local ecke = k:FindFirstChildOfClass("UICorner")
	if ecke then ecke.CornerRadius = UDim.new(0, 14) end
	local icon = k:FindFirstChild("Icon")
	local id = LeisteStil.BILDER[k.Name]
	if icon and id and id ~= 0 then
		icon.Visible = false
		local b = Instance.new("ImageLabel")
		b.Name = "IconBild"
		b.AnchorPoint = Vector2.new(0.5, 0)
		b.Position = UDim2.new(0.5, 0, 0, 3)
		b.Size = UDim2.fromOffset(40, 40)
		b.BackgroundTransparency = 1
		b.ScaleType = Enum.ScaleType.Fit
		b.Image = "rbxassetid://" .. tostring(id)
		b.Parent = k
	elseif icon then
		icon.Position = UDim2.fromOffset(0, 5)
		icon.Size = UDim2.new(1, 0, 0, 34)
		icon.TextSize = 28
	end
	local name = k:FindFirstChild("Beschriftung")
	if name then
		name.Position = UDim2.new(0, 0, 1, -16)
		name.Size = UDim2.new(1, 0, 0, 13)
		name.Font = Enum.Font.GothamBlack
		name.TextSize = 10
		name.TextColor3 = NAVY
	end
end

-- t = { leiste, klappe, menueKnopf }
function LeisteStil.anwenden(t)
	local g = LeisteStil.GROESSE
	local m = t.menueKnopf
	m.Size = UDim2.fromOffset(g, g)
	m.BackgroundColor3 = NAVY
	m.BackgroundTransparency = 0.02
	verlauf(m, Color3.new(1, 1, 1), Color3.fromRGB(150, 160, 185))
	rahmen(m, GELB)
	local ecke = m:FindFirstChildOfClass("UICorner")
	if ecke then ecke.CornerRadius = UDim.new(0, 14) end
	local symbol = m:FindFirstChild("Symbol")
	if symbol then symbol.Position = UDim2.new(0.5, 0, 0, 13) end
	local name = m:FindFirstChild("Beschriftung")
	if name then
		name.Position = UDim2.new(0, 0, 1, -16)
		name.Font = Enum.Font.GothamBlack
		name.TextColor3 = GELB
	end
	t.klappe.Position = UDim2.new(0, 12 + g + 4, 0, 58) -- tiles sit 2 px inside -> line up with the menu button
	t.klappe.Size = UDim2.fromOffset(t.klappe.Size.X.Offset, g + 4)
	t.leiste.Size = UDim2.fromOffset(0, g + 4)
	t.leiste.Position = UDim2.fromOffset(2, 2) -- room for the thicker hover edge (the fold-out clips)
	for _, k in t.leiste:GetChildren() do LeisteStil.knopf(k) end
	-- buttons are parented before their icon/label exist -> style them a moment later
	t.leiste.ChildAdded:Connect(function(k) task.defer(LeisteStil.knopf, k) end)
end

return LeisteStil
