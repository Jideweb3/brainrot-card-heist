-- Shop.client.luau
-- The luck shop: a SHOP button under the CARDS button opens a panel of
-- luck boosts. Buying fires the BuyLuck remote; the server checks the
-- price, starts the clock and answers with a notice. While a boost runs,
-- the Income feed carries the live multiplier and seconds left, and the
-- SHOP button itself becomes the countdown.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CardData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CardData"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("BrainrotRemotes")
local buyLuckEvent = remotes:WaitForChild("BuyLuck")
local incomeEvent = remotes:WaitForChild("Income")

local FONT = Enum.Font.FredokaOne
local PANEL = Color3.fromRGB(24, 22, 44)
local GREEN = Color3.fromRGB(46, 160, 90)
local GREEN_DARK = Color3.fromRGB(32, 110, 64)
local GOLD = Color3.fromRGB(255, 190, 55)

local gui = Instance.new("ScreenGui")
gui.Name = "BrainrotShopGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 6
gui.Parent = playerGui

local function makeButton(parent, name, position, size, text, color)
	local button = Instance.new("TextButton")
	button.Name = name
	button.AnchorPoint = Vector2.new(1, 0)
	button.Position = position
	button.Size = size
	button.BackgroundColor3 = color
	button.BorderSizePixel = 0
	button.Font = FONT
	button.Text = text
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextScaled = true
	button.AutoButtonColor = true
	button.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = button
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = 22
	constraint.MinTextSize = 10
	constraint.Parent = button
	return button
end

local shopButton = makeButton(gui, "ShopButton",
	UDim2.new(1, -18, 0, 132), UDim2.fromOffset(228, 56), "🛒 LUCK SHOP", GREEN)

-- Panel -------------------------------------------------------------------

local panel = Instance.new("Frame")
panel.Name = "ShopPanel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(540, 470)
panel.BackgroundColor3 = PANEL
panel.BackgroundTransparency = 0.04
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui
local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 16)
panelCorner.Parent = panel
local panelStroke = Instance.new("UIStroke")
panelStroke.Color = GREEN
panelStroke.Thickness = 2
panelStroke.Parent = panel

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Position = UDim2.fromOffset(24, 14)
title.Size = UDim2.new(1, -100, 0, 36)
title.BackgroundTransparency = 1
title.Font = FONT
title.Text = "🍀 LUCK SHOP"
title.TextColor3 = GOLD
title.TextSize = 28
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = panel

local subtitle = Instance.new("TextLabel")
subtitle.Name = "Subtitle"
subtitle.Position = UDim2.fromOffset(24, 52)
subtitle.Size = UDim2.new(1, -48, 0, 24)
subtitle.BackgroundTransparency = 1
subtitle.Font = Enum.Font.Gotham
subtitle.Text = "Luck makes Epic, Legendary, Mythic and Secret cards far more likely at the machine."
subtitle.TextColor3 = Color3.fromRGB(190, 200, 220)
subtitle.TextSize = 14
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.TextWrapped = true
subtitle.Parent = panel

local closeButton = makeButton(panel, "CloseButton",
	UDim2.new(1, -14, 0, 12), UDim2.fromOffset(40, 40), "✕", Color3.fromRGB(150, 60, 70))
closeButton.AnchorPoint = Vector2.new(1, 0)

local rows = {}
for index, product in ipairs(CardData.LuckProducts) do
	local row = Instance.new("Frame")
	row.Name = "Row_" .. product.Id
	row.Position = UDim2.fromOffset(24, 92 + (index - 1) * 76)
	row.Size = UDim2.new(1, -48, 0, 64)
	row.BackgroundColor3 = Color3.fromRGB(34, 32, 58)
	row.BorderSizePixel = 0
	row.Parent = panel
	local rowCorner = Instance.new("UICorner")
	rowCorner.CornerRadius = UDim.new(0, 12)
	rowCorner.Parent = row

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "ProductName"
	nameLabel.Position = UDim2.fromOffset(16, 6)
	nameLabel.Size = UDim2.new(1, -190, 0, 30)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = FONT
	nameLabel.Text = product.Symbol .. " " .. product.Name
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextSize = 21
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = row

	local blurbLabel = Instance.new("TextLabel")
	blurbLabel.Name = "ProductBlurb"
	blurbLabel.Position = UDim2.fromOffset(16, 36)
	blurbLabel.Size = UDim2.new(1, -190, 0, 22)
	blurbLabel.BackgroundTransparency = 1
	blurbLabel.Font = Enum.Font.GothamBold
	blurbLabel.Text = product.Blurb
	blurbLabel.TextColor3 = GOLD
	blurbLabel.TextSize = 15
	blurbLabel.TextXAlignment = Enum.TextXAlignment.Left
	blurbLabel.Parent = row

	local buyButton = makeButton(row, "BuyButton",
		UDim2.new(1, -12, 0.5, 0), UDim2.fromOffset(150, 42),
		"BUY " .. CardData.FormatMoney(product.Price), GREEN)
	buyButton.AnchorPoint = Vector2.new(1, 0.5)
	buyButton.MouseButton1Click:Connect(function()
		buyLuckEvent:FireServer(product.Id)
	end)
	rows[product.Id] = buyButton
end

local cashLabel = Instance.new("TextLabel")
cashLabel.Name = "CashLine"
cashLabel.Position = UDim2.fromOffset(24, 404)
cashLabel.Size = UDim2.new(1, -48, 0, 26)
cashLabel.BackgroundTransparency = 1
cashLabel.Font = Enum.Font.GothamBold
cashLabel.Text = ""
cashLabel.TextColor3 = Color3.fromRGB(190, 200, 220)
cashLabel.TextSize = 16
cashLabel.TextXAlignment = Enum.TextXAlignment.Left
cashLabel.Parent = panel

local activeLabel = Instance.new("TextLabel")
activeLabel.Name = "ActiveLine"
activeLabel.Position = UDim2.fromOffset(24, 430)
activeLabel.Size = UDim2.new(1, -48, 0, 26)
activeLabel.BackgroundTransparency = 1
activeLabel.Font = Enum.Font.GothamBold
activeLabel.Text = ""
activeLabel.TextColor3 = GOLD
activeLabel.TextSize = 16
activeLabel.TextXAlignment = Enum.TextXAlignment.Left
activeLabel.Parent = panel

-- Live state ---------------------------------------------------------------

local leaderstats = player:WaitForChild("leaderstats")
local cashValue = leaderstats:WaitForChild("Cash")

local function refreshCashLine()
	cashLabel.Text = "Your cash: " .. CardData.FormatMoney(cashValue.Value)
	for _, product in ipairs(CardData.LuckProducts) do
		local button = rows[product.Id]
		if button then
			button.BackgroundColor3 = cashValue.Value >= product.Price and GREEN or GREEN_DARK
		end
	end
end
cashValue.Changed:Connect(refreshCashLine)
refreshCashLine()

local luckMultiplier = 1
local luckSecondsLeft = 0

local function formatClock(seconds)
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function refreshLuckLine()
	if luckSecondsLeft > 0 and luckMultiplier > 1 then
		local text = string.format("🍀 x%.1f luck • %s left", luckMultiplier, formatClock(luckSecondsLeft))
		shopButton.Text = "🛒 " .. text
		activeLabel.Text = "Active now: " .. text
	else
		shopButton.Text = "🛒 LUCK SHOP"
		activeLabel.Text = "No luck boost running — the machine is at base odds."
	end
end
refreshLuckLine()

incomeEvent.OnClientEvent:Connect(function(_perSecond, newMultiplier, newSecondsLeft)
	luckMultiplier = newMultiplier or 1
	luckSecondsLeft = newSecondsLeft or 0
	refreshLuckLine()
end)

shopButton.MouseButton1Click:Connect(function()
	panel.Visible = not panel.Visible
	if panel.Visible then
		refreshCashLine()
		refreshLuckLine()
	end
end)
closeButton.MouseButton1Click:Connect(function()
	panel.Visible = false
end)
