-- CardDex.client.luau  (ROUND-6 PREP — not yet in the entry tree)
-- A full-screen card collection page: every card in the game with its face,
-- rarity and earn rate, plus the mutation ladder. Built entirely from
-- CardData, so it can never drift from the game's real numbers.
-- Toggle: the CARDS button (bottom-left, under Rebirth) or the B key.
-- Drop-in: place at entry/src/client/CardDex.client.luau, rojo build, publish.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local CardData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CardData"))

local gui = Instance.new("ScreenGui")
gui.Name = "CardDexGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 5
gui.Parent = player:WaitForChild("PlayerGui")

local DARK = Color3.fromRGB(24, 22, 44)

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

local function label(parent, name, position, size, text, color, sizePx, wrapped)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Position = position
	l.Size = size
	l.Text = text
	l.TextColor3 = color
	l.BackgroundTransparency = 1
	l.BorderSizePixel = 0
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = false
	l.TextSize = sizePx
	l.TextWrapped = wrapped or false
	l.Parent = parent
	return l
end

-- Toggle button, under the HUD's Rebirth button.
local toggle = Instance.new("TextButton")
toggle.Name = "DexButton"
toggle.Position = UDim2.new(0, 18, 0, 278)
toggle.Size = UDim2.new(0, 308, 0, 56)
toggle.BackgroundColor3 = Color3.fromRGB(46, 110, 200)
toggle.BorderSizePixel = 0
toggle.Text = "🃏 CARD COLLECTION [B]"
toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
toggle.Font = Enum.Font.FredokaOne
toggle.TextScaled = false
toggle.TextSize = 20
toggle.Parent = gui
corner(toggle, 12)

-- The panel.
local panel = Instance.new("Frame")
panel.Name = "DexPanel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.52)
panel.Size = UDim2.fromScale(0.88, 0.8)
panel.BackgroundColor3 = DARK
panel.BackgroundTransparency = 0.04
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui
corner(panel, 18)

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(255, 224, 102)
stroke.Thickness = 2
stroke.Parent = panel

local title = label(panel, "Title", UDim2.fromScale(0.03, 0.015), UDim2.fromScale(0.94, 0.07),
	"🃏 CARD COLLECTION — 18 CARDS • 6 RARITIES", Color3.fromRGB(255, 224, 102), 22)
title.TextXAlignment = Enum.TextXAlignment.Left

local grid = Instance.new("ScrollingFrame")
grid.Name = "Grid"
grid.Position = UDim2.fromScale(0.02, 0.1)
grid.Size = UDim2.fromScale(0.96, 0.76)
grid.BackgroundTransparency = 1
grid.BorderSizePixel = 0
grid.ScrollBarThickness = 6
grid.CanvasSize = UDim2.new(0, 0, 0, 0)
grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
grid.Parent = panel

local layout = Instance.new("UIGridLayout")
layout.CellSize = UDim2.new(0, 128, 0, 158)
layout.CellPadding = UDim2.new(0, 8, 0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = grid

local mutations = label(panel, "Mutations", UDim2.fromScale(0.03, 0.885), UDim2.fromScale(0.94, 0.09),
	"MUTATIONS ON EVERY PULL:  GOLD ×2  •  DIAMOND ×3  •  RAINBOW ×5",
	Color3.fromRGB(255, 190, 90), 16)
mutations.TextXAlignment = Enum.TextXAlignment.Left

-- One tile per card, in CardData order (Common first, Secret last).
for index, definition in ipairs(CardData.Cards) do
	local rarityColor = CardData.GetRarityColor(definition.Rarity)
	local tile = Instance.new("Frame")
	tile.Name = "Tile_" .. definition.Id
	tile.LayoutOrder = index
	tile.BackgroundColor3 = Color3.fromRGB(38, 35, 66)
	tile.BorderSizePixel = 0
	tile.Parent = grid
	corner(tile, 12)

	local tileStroke = Instance.new("UIStroke")
	tileStroke.Color = rarityColor
	tileStroke.Thickness = 2
	tileStroke.Parent = tile

	local face = Instance.new("ImageLabel")
	face.Name = "Face"
	face.AnchorPoint = Vector2.new(0.5, 0)
	face.Position = UDim2.new(0.5, 0, 0, 6)
	face.Size = UDim2.new(0, 74, 0, 74)
	face.BackgroundTransparency = 1
	face.Image = definition.ImageId > 0 and ("rbxassetid://" .. definition.ImageId) or ""
	face.ScaleType = Enum.ScaleType.Fit
	face.Parent = tile

	local name = label(tile, "Name", UDim2.new(0, 4, 0, 82), UDim2.new(1, -8, 0, 30),
		definition.Symbol .. " " .. definition.Name, Color3.fromRGB(255, 255, 255), 11, true)
	name.TextYAlignment = Enum.TextYAlignment.Top

	local rarity = label(tile, "Rarity", UDim2.new(0, 4, 0, 112), UDim2.new(1, -8, 0, 16),
		string.upper(definition.Rarity), rarityColor, 12)
	rarity.TextXAlignment = Enum.TextXAlignment.Center
	name.TextXAlignment = Enum.TextXAlignment.Center

	local earn = label(tile, "Earn", UDim2.new(0, 4, 0, 130), UDim2.new(1, -8, 0, 20),
		CardData.FormatMoney(definition.EarnPerSecond) .. "/s", Color3.fromRGB(255, 224, 102), 14)
	earn.TextXAlignment = Enum.TextXAlignment.Center
end

local function setOpen(open)
	panel.Visible = open
end

toggle.Activated:Connect(function()
	setOpen(not panel.Visible)
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.B then
		setOpen(not panel.Visible)
	end
end)
