-- Game.client.luau
-- HUD: live cash, the pull reveal banner, and short notice toasts.
-- All game state is server-owned; this script only displays it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local CardData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CardData"))
local remotes = ReplicatedStorage:WaitForChild("BrainrotRemotes")
local noticeEvent = remotes:WaitForChild("Notice")
local revealEvent = remotes:WaitForChild("Reveal")
local rebirthEvent = remotes:WaitForChild("Rebirth")
local lockStateEvent = remotes:WaitForChild("LockState")
local adminCashEvent = remotes:WaitForChild("AdminCash")

local gui = Instance.new("ScreenGui")
gui.Name = "BrainrotHud"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function makeLabel(parent, name, position, size, text, textColor, backgroundColor, transparency)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Position = position
	label.Size = size
	label.Text = text
	label.TextColor3 = textColor
	label.BackgroundColor3 = backgroundColor
	label.BackgroundTransparency = transparency or 0
	label.BorderSizePixel = 0
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Parent = parent
	return label
end

-- Cash panel.
local cashPanel = Instance.new("Frame")
cashPanel.Name = "CashPanel"
cashPanel.Position = UDim2.new(0, 16, 0, 66)
cashPanel.Size = UDim2.new(0, 190, 0, 78)
cashPanel.BackgroundColor3 = Color3.fromRGB(24, 22, 44)
cashPanel.BorderSizePixel = 0
cashPanel.Parent = gui

local cashCorner = Instance.new("UICorner")
cashCorner.CornerRadius = UDim.new(0, 14)
cashCorner.Parent = cashPanel

local cashLabel = makeLabel(cashPanel, "Cash", UDim2.fromScale(0.06, 0.05), UDim2.fromScale(0.88, 0.36), "💰 $0", Color3.fromRGB(255, 224, 102), Color3.fromRGB(24, 22, 44), 1)
cashLabel.TextXAlignment = Enum.TextXAlignment.Left
cashLabel.TextScaled = false
cashLabel.TextSize = 20
local incomeLabel = makeLabel(cashPanel, "Income", UDim2.fromScale(0.06, 0.43), UDim2.fromScale(0.88, 0.26), "Placed cards earn every second", Color3.fromRGB(190, 200, 220), Color3.fromRGB(24, 22, 44), 1)
incomeLabel.TextXAlignment = Enum.TextXAlignment.Left
incomeLabel.TextScaled = false
incomeLabel.TextSize = 11
incomeLabel.TextWrapped = true
local rebirthLabel = makeLabel(cashPanel, "Rebirths", UDim2.fromScale(0.06, 0.71), UDim2.fromScale(0.88, 0.26), "⭐ Rebirths: 0 • Income x1.0", Color3.fromRGB(255, 190, 90), Color3.fromRGB(24, 22, 44), 1)
rebirthLabel.TextXAlignment = Enum.TextXAlignment.Left
rebirthLabel.TextScaled = false
rebirthLabel.TextSize = 11

-- Rebirth button: the server re-checks the cost, this only sends the ask.
local rebirthButton = Instance.new("TextButton")
rebirthButton.Name = "RebirthButton"
rebirthButton.Position = UDim2.new(0, 16, 0, 182)
rebirthButton.Size = UDim2.new(0, 190, 0, 38)
rebirthButton.BackgroundColor3 = Color3.fromRGB(70, 66, 96)
rebirthButton.BorderSizePixel = 0
rebirthButton.Text = "♻ REBIRTH"
rebirthButton.TextColor3 = Color3.fromRGB(255, 255, 255)
rebirthButton.Font = Enum.Font.FredokaOne
rebirthButton.TextScaled = false
rebirthButton.TextSize = 14
rebirthButton.Parent = gui

local rebirthButtonCorner = Instance.new("UICorner")
rebirthButtonCorner.CornerRadius = UDim.new(0, 12)
rebirthButtonCorner.Parent = rebirthButton

rebirthButton.Activated:Connect(function()
	rebirthEvent:FireServer()
end)

-- Owner-only admin cash button (bottom-right, above the hotbar): only the
-- place creator ever sees it, and the server verifies ownership again
-- before granting, so this check is purely cosmetic.
if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then
	local adminCashButton = Instance.new("TextButton")
	adminCashButton.Name = "AdminCashButton"
	adminCashButton.AnchorPoint = Vector2.new(1, 1)
	adminCashButton.Position = UDim2.new(1, -12, 1, -70)
	adminCashButton.Size = UDim2.new(0, 110, 0, 36)
	adminCashButton.BackgroundColor3 = Color3.fromRGB(24, 22, 44)
	adminCashButton.BorderSizePixel = 0
	adminCashButton.Text = "👑 +$10K"
	adminCashButton.TextColor3 = Color3.fromRGB(255, 224, 102)
	adminCashButton.Font = Enum.Font.FredokaOne
	adminCashButton.TextScaled = false
	adminCashButton.TextSize = 14
	adminCashButton.Parent = gui

	local adminCashButtonCorner = Instance.new("UICorner")
	adminCashButtonCorner.CornerRadius = UDim.new(0, 12)
	adminCashButtonCorner.Parent = adminCashButton

	adminCashButton.Activated:Connect(function()
		adminCashEvent:FireServer()
	end)
end

-- Base lock status chip (top-right): mirrors the server's lock state.
local lockChip = makeLabel(gui, "LockStatus", UDim2.new(1, -166, 0, 66), UDim2.new(0, 150, 0, 30),
	"🛡 Base lock ready", Color3.fromRGB(190, 225, 255), Color3.fromRGB(24, 22, 44), 0.15)
lockChip.TextScaled = false
lockChip.TextSize = 12
lockChip.TextWrapped = true

local lockChipCorner = Instance.new("UICorner")
lockChipCorner.CornerRadius = UDim.new(0, 12)
lockChipCorner.Parent = lockChip

local lockStateName = "ready"
local lockEndsAt = 0

lockStateEvent.OnClientEvent:Connect(function(stateName, endsAt)
	lockStateName = stateName
	lockEndsAt = endsAt or 0
end)

task.spawn(function()
	while true do
		local remaining = math.max(0, math.ceil(lockEndsAt - Workspace:GetServerTimeNow()))
		if lockStateName == "locked" then
			lockChip.Text = string.format("🔒 BASE LOCKED — %ds", remaining)
			lockChip.TextColor3 = Color3.fromRGB(255, 150, 150)
		elseif lockStateName == "cooldown" then
			lockChip.Text = string.format("⏳ Lock recharging — %ds", remaining)
			lockChip.TextColor3 = Color3.fromRGB(255, 220, 150)
		else
			lockChip.Text = "🛡 Base lock ready"
			lockChip.TextColor3 = Color3.fromRGB(190, 225, 255)
		end
		task.wait(0.25)
	end
end)

-- Objective strip.
local objective = makeLabel(gui, "Objective", UDim2.new(0.5, -180, 0, 16), UDim2.new(0, 360, 0, 32),
	"PULL  →  CARRY  →  PLACE  →  PROTECT", Color3.fromRGB(255, 255, 255), Color3.fromRGB(24, 22, 44), 0.25)
objective.TextScaled = false
objective.TextSize = 13

local objectiveCorner = Instance.new("UICorner")
objectiveCorner.CornerRadius = UDim.new(0, 12)
objectiveCorner.Parent = objective

-- Pull reveal banner.
local banner = Instance.new("Frame")
banner.Name = "RevealBanner"
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0, -170)
banner.Size = UDim2.new(0, 340, 0, 96)
banner.BackgroundColor3 = Color3.fromRGB(178, 190, 204)
banner.BorderSizePixel = 0
banner.Parent = gui

local bannerCorner = Instance.new("UICorner")
bannerCorner.CornerRadius = UDim.new(0, 18)
bannerCorner.Parent = banner

local bannerTitle = makeLabel(banner, "Title", UDim2.fromScale(0.05, 0.06), UDim2.fromScale(0.9, 0.3), "", Color3.fromRGB(255, 255, 255), Color3.fromRGB(0, 0, 0), 1)
bannerTitle.TextScaled = false
bannerTitle.TextSize = 24
local bannerCard = makeLabel(banner, "Card", UDim2.fromScale(0.05, 0.36), UDim2.fromScale(0.9, 0.36), "", Color3.fromRGB(255, 255, 255), Color3.fromRGB(0, 0, 0), 1)
local bannerStats = makeLabel(banner, "Stats", UDim2.fromScale(0.05, 0.74), UDim2.fromScale(0.9, 0.2), "", Color3.fromRGB(255, 255, 255), Color3.fromRGB(0, 0, 0), 1)

local bannerBusy = false
local function showReveal(cardId, pullerName, mutationId)
	local definition = CardData.CardsById[cardId]
	if not definition then
		return
	end
	while bannerBusy do
		task.wait(0.1)
	end
	bannerBusy = true
	local mutation = CardData.GetMutation(mutationId)
	local isMutated = mutationId ~= nil and mutationId ~= "None"
	local rarityColor = CardData.GetRarityColor(definition.Rarity)
	banner.BackgroundColor3 = mutation.Color or rarityColor
	bannerTitle.Text = string.format("%s pulled", pullerName)
	bannerCard.Text = string.format("%s  %s%s", definition.Symbol,
		CardData.DisplayName(definition, mutationId), isMutated and "!" or "")
	if isMutated then
		bannerStats.Text = string.format("%s %s  •  earns $%d/s (x%d mutation)",
			string.upper(mutation.Name), string.upper(definition.Rarity),
			CardData.GetEarnPerSecond(definition, mutationId), mutation.Multiplier)
	else
		bannerStats.Text = string.format("%s  •  earns $%d/s",
			string.upper(definition.Rarity), definition.EarnPerSecond)
	end

	banner.Position = UDim2.new(0.5, 0, 0, -170)
	local slideIn = TweenService:Create(banner, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, 120),
	})
	slideIn:Play()
	slideIn.Completed:Wait()
	task.wait(2.4)
	local slideOut = TweenService:Create(banner, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.new(0.5, 0, 0, -170),
	})
	slideOut:Play()
	slideOut.Completed:Wait()
	bannerBusy = false
end

revealEvent.OnClientEvent:Connect(function(cardId, pullerName, mutationId)
	task.spawn(showReveal, cardId, pullerName, mutationId)
end)

-- Notice toast.
local toast = makeLabel(gui, "Toast", UDim2.new(0.5, -160, 1, -86), UDim2.new(0, 320, 0, 40), "", Color3.fromRGB(255, 255, 255), Color3.fromRGB(24, 22, 44), 0.15)
toast.TextScaled = false
toast.TextSize = 13
toast.TextWrapped = true
toast.TextTransparency = 1
toast.BackgroundTransparency = 1

local toastCorner = Instance.new("UICorner")
toastCorner.CornerRadius = UDim.new(0, 12)
toastCorner.Parent = toast

local toastToken = 0
local kindColors = {
	info = Color3.fromRGB(255, 255, 255),
	good = Color3.fromRGB(120, 255, 170),
	warn = Color3.fromRGB(255, 220, 92),
	bad = Color3.fromRGB(255, 120, 120),
}

noticeEvent.OnClientEvent:Connect(function(text, kind)
	toastToken += 1
	local myToken = toastToken
	toast.Text = text
	toast.TextColor3 = kindColors[kind] or kindColors.info
	TweenService:Create(toast, TweenInfo.new(0.2), { TextTransparency = 0, BackgroundTransparency = 0.15 }):Play()
	task.delay(3.2, function()
		if toastToken == myToken then
			TweenService:Create(toast, TweenInfo.new(0.35), { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
		end
	end)
end)

-- Cash, cards and rebirths follow leaderstats.
local function bindCash()
	local leaderstats = player:WaitForChild("leaderstats")
	local cash = leaderstats:WaitForChild("Cash")
	local cards = leaderstats:WaitForChild("Cards")
	local rebirths = leaderstats:WaitForChild("Rebirths")
	local function refresh()
		cashLabel.Text = string.format("💰 $%d", cash.Value)
		local placed = cards.Value
		incomeLabel.Text = placed > 0 and string.format("%d card%s placed — earning every second", placed, placed == 1 and "" or "s") or "No cards placed yet"
		local rebirthCount = rebirths.Value
		rebirthLabel.Text = string.format("⭐ Rebirths: %d • Income x%.1f", rebirthCount, CardData.GetIncomeMultiplier(rebirthCount))
		local cost = CardData.GetRebirthCost(rebirthCount)
		rebirthButton.Text = string.format("♻ REBIRTH — $%d", cost)
		rebirthButton.BackgroundColor3 = cash.Value >= cost
			and Color3.fromRGB(46, 160, 90)
			or Color3.fromRGB(70, 66, 96)
	end
	cash.Changed:Connect(refresh)
	cards.Changed:Connect(refresh)
	rebirths.Changed:Connect(refresh)
	refresh()
end

task.spawn(bindCash)

-- Laser door pass: every base doorway is blocked by an invisible wall with
-- red laser bars. For the base's owner only, this client drops the wall
-- (collision is checked locally for your own character) and paints the bars
-- green, so home is the one door that opens for you. The wall and bars are
-- static, so this runs once once the world and the sign are in.
task.spawn(function()
	pcall(function()
		local worldFolder = Workspace:WaitForChild("BrainrotCardHeist", 15)
		if not worldFolder then
			return
		end
		local myName = string.upper(player.DisplayName)
		for _ = 1, 30 do
			for baseIndex = 1, 8 do
				local base = worldFolder:FindFirstChild("Base" .. baseIndex)
				local sign = base and base:FindFirstChild("OwnerSign")
				local face = sign and sign:FindFirstChild("TextFace")
				local label = face and face:FindFirstChild("Label")
				if label and string.find(string.upper(label.Text), myName, 1, true) then
					local laserWall = base:FindFirstChild("LaserWall")
					if laserWall then
						laserWall.CanCollide = false
					end
					for _, child in ipairs(base:GetChildren()) do
						if child.Name == "LaserBar" then
							child.Color = Color3.fromRGB(33, 140, 66)
						end
					end
					return
				end
			end
			task.wait(0.5)
		end
	end)
end)
