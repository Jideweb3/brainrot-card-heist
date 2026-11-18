-- GameServer.luau
-- Owns the live game loop: bases, the card machine, carrying, placing,
-- earning, stealing, the bat, saving and respawns.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CardData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CardData"))
local WorldBuilder = require(script.Parent.WorldBuilder)
local DataService = require(script.Parent.DataService)
local RebirthService = require(script.Parent.RebirthService)
local BaseLockService = require(script.Parent.BaseLockService)
local ThiefEvent = require(script.Parent.ThiefEvent)

local GameServer = {}

local random = Random.new()
local world = nil
local remotes = nil
local baseOwners = {} -- [baseIndex] = Player
local started = false

local function fireNotice(player, text, kind)
	if remotes and player then
		remotes.Notice:FireClient(player, text, kind or "info")
	end
end

local function getHumanoid(player)
	local character = player and player.Character
	if not character then
		return nil
	end
	return character:FindFirstChildOfClass("Humanoid")
end

local function setWalkSpeed(player, speed)
	local humanoid = getHumanoid(player)
	if humanoid then
		humanoid.WalkSpeed = speed
	end
end

local function buildCardFace(body, definition, mutationId)
	local mutation = CardData.GetMutation(mutationId)
	local rarityColor = CardData.GetRarityColor(definition.Rarity)
	local faceColor = mutation.Color or rarityColor

	local face = Instance.new("SurfaceGui")
	face.Name = "CardFace"
	face.Face = Enum.NormalId.Front
	face.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	face.PixelsPerStud = 55
	face.Parent = body

	local background = Instance.new("Frame")
	background.Name = "Background"
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = faceColor
	background.BorderSizePixel = 0
	background.Parent = face

	local symbol = Instance.new("TextLabel")
	symbol.Name = "Symbol"
	symbol.Position = UDim2.fromScale(0.08, 0.05)
	symbol.Size = UDim2.fromScale(0.84, 0.42)
	symbol.BackgroundTransparency = 1
	symbol.Text = definition.Symbol
	symbol.TextScaled = true
	symbol.Font = Enum.Font.FredokaOne
	symbol.Parent = background

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "CardName"
	nameLabel.Position = UDim2.fromScale(0.06, 0.5)
	nameLabel.Size = UDim2.fromScale(0.88, 0.25)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = CardData.DisplayName(definition, mutationId)
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.Parent = background

	local stats = Instance.new("TextLabel")
	stats.Name = "Stats"
	stats.Position = UDim2.fromScale(0.06, 0.76)
	stats.Size = UDim2.fromScale(0.88, 0.18)
	stats.BackgroundTransparency = 1
	stats.Text = string.format("%s  •  $%d/s", string.upper(definition.Rarity), CardData.GetEarnPerSecond(definition, mutationId))
	stats.TextColor3 = Color3.fromRGB(255, 255, 255)
	stats.TextScaled = true
	stats.Font = Enum.Font.FredokaOne
	stats.Parent = background

	local back = Instance.new("SurfaceGui")
	back.Name = "CardBack"
	back.Face = Enum.NormalId.Back
	back.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	back.PixelsPerStud = 55
	back.Parent = body

	local backLabel = Instance.new("TextLabel")
	backLabel.Size = UDim2.fromScale(1, 1)
	backLabel.BackgroundColor3 = Color3.fromRGB(24, 22, 44)
	backLabel.BorderSizePixel = 0
	backLabel.Text = "🃏\nBRAINROT\nCARD HEIST"
	backLabel.TextColor3 = Color3.fromRGB(255, 220, 92)
	backLabel.TextScaled = true
	backLabel.Font = Enum.Font.FredokaOne
	backLabel.Parent = back

	if definition.ImageId and definition.ImageId > 0 then
		local decal = Instance.new("Decal")
		decal.Name = "CardArt"
		decal.Texture = "rbxassetid://" .. definition.ImageId
		decal.Face = Enum.NormalId.Front
		decal.Parent = body
	end
end

local function setModelPhysics(model, anchored)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = anchored
			descendant.CanCollide = false
			descendant.Massless = true
		end
	end
	local body = model.PrimaryPart
	if body then
		body.Anchored = anchored
		body.CanCollide = false
	end
end

local function detachWelds(model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("WeldConstraint") and descendant.Name == "CarryWeld" then
			descendant:Destroy()
		end
	end
end

local function updateStandPrompt(base, stand)
	local ownerPlayer = baseOwners[base.Index]
	local ownerSession = ownerPlayer and DataService.GetSession(ownerPlayer)
	local entry = ownerSession and ownerSession.PlacedCards[tostring(stand.Index)]
	if entry then
		local cardId, mutationId = CardData.ParsePlacedEntry(entry)
		local definition = cardId and CardData.CardsById[cardId]
		if definition then
			stand.Prompt.ObjectText = string.format("%s • $%d/s",
				CardData.DisplayName(definition, mutationId),
				CardData.GetEarnPerSecond(definition, mutationId))
		end
		stand.Prompt.ActionText = "Take / Steal"
		stand.Prompt.HoldDuration = CardData.StealHoldSeconds
	elseif ownerSession and stand.Index > RebirthService.GetActiveStands(ownerSession) then
		stand.Prompt.ObjectText = "🔒 Locked Stand"
		stand.Prompt.ActionText = "Rebirth to Unlock"
		stand.Prompt.HoldDuration = 0.25
	else
		stand.Prompt.ObjectText = "Empty Card Stand"
		stand.Prompt.ActionText = "Place Card"
		stand.Prompt.HoldDuration = 0.25
	end
end

local function attachCardToPlayer(session, model)
	local player = session.Player
	local character = player.Character
	if not character then
		return false
	end
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local body = model and model.PrimaryPart
	if not torso or not body then
		return false
	end

	detachWelds(model)
	setModelPhysics(model, false)
	model:PivotTo(torso.CFrame * CFrame.new(0, 0.9, 1.18) * CFrame.Angles(0, math.pi, 0))

	local weld = Instance.new("WeldConstraint")
	weld.Name = "CarryWeld"
	weld.Part0 = torso
	weld.Part1 = body
	weld.Parent = body

	model:SetAttribute("State", "Carried")
	model:SetAttribute("OwnerUserId", session.UserId)
	local prompt = body:FindFirstChild("CardPrompt")
	if prompt then
		prompt.Enabled = false
	end

	session.CarryingCardId = model:GetAttribute("CardId")
	session.CarryingMutationId = model:GetAttribute("MutationId") or "None"
	session.CarryingModel = model
	setWalkSpeed(player, CardData.CarryWalkSpeed)
	return true
end

local function dropCarriedCard(session, cframe)
	local model = session.CarryingModel
	if not model then
		return nil
	end
	session.CarryingCardId = nil
	session.CarryingMutationId = nil
	session.CarryingModel = nil
	detachWelds(model)
	setModelPhysics(model, true)
	local body = model.PrimaryPart
	if body then
		model:PivotTo(cframe)
		local prompt = body:FindFirstChild("CardPrompt")
		if prompt then
			prompt.Enabled = true
		end
	end
	model:SetAttribute("State", "Loose")
	setWalkSpeed(session.Player, CardData.NormalWalkSpeed)
	return model
end

local function handleLooseCardPrompt(player, model)
	if not model or not model.Parent then
		return
	end
	if model:GetAttribute("State") ~= "Loose" then
		return
	end
	local session = DataService.GetSession(player)
	if not session then
		return
	end
	if session.CarryingModel then
		fireNotice(player, "Your hands are full — place that card first.", "warn")
		return
	end
	if attachCardToPlayer(session, model) then
		local definition = CardData.CardsById[model:GetAttribute("CardId")]
		local displayName = definition and CardData.DisplayName(definition, model:GetAttribute("MutationId")) or "a card"
		fireNotice(player, "Card on your back! Carry it to your base — follow your colour beam — and use a stand.", "good")
	end
end

local function createCardModel(definition, ownerUserId, mutationId)
	mutationId = mutationId or "None"
	local mutation = CardData.GetMutation(mutationId)

	local model = Instance.new("Model")
	model.Name = "Card_" .. definition.Id
	model:SetAttribute("CardId", definition.Id)
	model:SetAttribute("MutationId", mutationId)
	model:SetAttribute("OwnerUserId", ownerUserId or 0)
	model:SetAttribute("State", "Revealing")
	model.Parent = world.ActiveCards

	local rarityColor = CardData.GetRarityColor(definition.Rarity)
	local glowColor = mutation.GlowColor or CardData.GetRarityGlowColor(definition.Rarity)
	-- The card's neon trim and rarity beam use a dimmed copy of the glow
	-- colour: full-strength neon was far too shiny on a phone. CardData's
	-- colours themselves stay untouched (they also drive the UI), so the
	-- dimming happens here, at build time.
	local dimGlowColor = Color3.new(glowColor.R * 0.55, glowColor.G * 0.55, glowColor.B * 0.55)

	local body = Instance.new("Part")
	body.Name = "CardBody"
	body.Size = Vector3.new(3.6, 5, 0.28)
	body.Color = mutation.Color or rarityColor
	body.Material = mutationId == "Diamond" and Enum.Material.Glass or Enum.Material.SmoothPlastic
	body.Anchored = true
	body.CanCollide = false
	body.Parent = model
	model.PrimaryPart = body

	if mutationId == "Gold" then
		local sparkles = Instance.new("Sparkles")
		sparkles.Name = "MutationSparkles"
		sparkles.SparkleColor = mutation.GlowColor
		sparkles.Parent = body
	end

	local trim = Instance.new("Part")
	trim.Name = "GlowTrim"
	trim.Size = Vector3.new(3.95, 5.35, 0.14)
	trim.Color = dimGlowColor
	trim.Material = Enum.Material.Neon
	trim.Anchored = true
	trim.CanCollide = false
	trim.CFrame = CFrame.new(0, 0, 0.1)
	trim.Parent = model
	-- Keep the trim centred on the body wherever the model is moved.
	local trimWeld = Instance.new("WeldConstraint")
	trimWeld.Name = "TrimWeld"
	trimWeld.Part0 = body
	trimWeld.Part1 = trim
	trimWeld.Parent = trim

	buildCardFace(body, definition, mutationId)

	local attachment0 = Instance.new("Attachment")
	attachment0.Name = "BeamBottom"
	attachment0.Position = Vector3.new(0, -2.5, 0)
	attachment0.Parent = body
	local attachment1 = Instance.new("Attachment")
	attachment1.Name = "BeamTop"
	attachment1.Position = Vector3.new(0, 8, 0)
	attachment1.Parent = body
	local beam = Instance.new("Beam")
	beam.Name = "RarityBeam"
	beam.Attachment0 = attachment0
	beam.Attachment1 = attachment1
	beam.Width0 = 1.15
	beam.Width1 = 0.35
	beam.Color = ColorSequence.new(dimGlowColor)
	beam.Transparency = NumberSequence.new(0.35)
	beam.FaceCamera = true
	beam.Parent = body

	local light = Instance.new("PointLight")
	light.Name = "RarityGlow"
	light.Color = glowColor
	light.Range = 11
	light.Brightness = 0.7
	light.Parent = body

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CardPrompt"
	prompt.ActionText = "Pick Up"
	prompt.ObjectText = definition.Name
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = body
	prompt.Triggered:Connect(function(player)
		handleLooseCardPrompt(player, model)
	end)

	return model
end

local function removeCardFromStand(ownerSession, base, stand)
	local cardId = ownerSession.PlacedCards[tostring(stand.Index)]
	if not cardId then
		return nil
	end
	local model = ownerSession.PlacedModels[stand.Index]
	ownerSession.PlacedCards[tostring(stand.Index)] = nil
	ownerSession.PlacedModels[stand.Index] = nil
	DataService.RefreshLeaderstats(ownerSession)
	updateStandPrompt(base, stand)
	return model
end

local function placeCardOnStand(session, base, stand)
	local model = session.CarryingModel
	if not model then
		return false
	end
	local cardId = model:GetAttribute("CardId")
	local mutationId = model:GetAttribute("MutationId") or "None"
	session.CarryingCardId = nil
	session.CarryingMutationId = nil
	session.CarryingModel = nil
	detachWelds(model)
	setModelPhysics(model, true)
	local body = model.PrimaryPart
	if body then
		model:PivotTo(stand.SlotCFrame)
	end
	model:SetAttribute("State", "Placed")
	model:SetAttribute("PlacedCFrame", stand.SlotCFrame)
	session.PlacedCards[tostring(stand.Index)] = CardData.MakePlacedEntry(cardId, mutationId)
	session.PlacedModels[stand.Index] = model
	setWalkSpeed(session.Player, CardData.NormalWalkSpeed)
	DataService.RefreshLeaderstats(session)
	updateStandPrompt(base, stand)
	local definition = CardData.CardsById[cardId]
	fireNotice(session.Player, string.format("Placed %s — earning $%d every second.",
		CardData.DisplayName(definition, mutationId),
		CardData.GetEarnPerSecond(definition, mutationId)), "good")
	return true
end

local function handleStandPrompt(player, base, stand)
	local session = DataService.GetSession(player)
	if not session then
		return
	end
	local ownerPlayer = baseOwners[base.Index]
	if not ownerPlayer then
		fireNotice(player, "This base has no owner yet.", "warn")
		return
	end
	local ownerSession = DataService.GetSession(ownerPlayer)
	if not ownerSession then
		return
	end

	local occupiedEntry = ownerSession.PlacedCards[tostring(stand.Index)]
	if occupiedEntry then
		local cardId, mutationId = CardData.ParsePlacedEntry(occupiedEntry)
		local definition = cardId and CardData.CardsById[cardId]
		local displayName = definition and CardData.DisplayName(definition, mutationId) or "a card"
		if ownerPlayer == player then
			if session.CarryingModel then
				fireNotice(player, "Your hands are full — place that card on an empty stand.", "warn")
				return
			end
			local model = removeCardFromStand(ownerSession, base, stand)
			if model and attachCardToPlayer(session, model) then
				fireNotice(player, "Took " .. displayName .. " back off the stand.", "info")
			end
		else
			if BaseLockService.IsLocked(base.Index) then
				fireNotice(player, "🛡 This base is LOCKED — its shield blocks stealing. Try again when it drops.", "bad")
				fireNotice(ownerPlayer, "Your shield just blocked a steal attempt!", "good")
				return
			end
			if session.CarryingModel then
				fireNotice(player, "You can't steal while carrying a card.", "warn")
				return
			end
			local model = removeCardFromStand(ownerSession, base, stand)
			if model and attachCardToPlayer(session, model) then
				fireNotice(player, "STOLEN! You grabbed " .. displayName .. " — run it home!", "good")
				fireNotice(ownerPlayer, displayName .. " was stolen from your base!", "bad")
			end
		end
		return
	end

	-- Empty stand: only its owner may place, and only while carrying.
	if ownerPlayer ~= player then
		fireNotice(player, "This isn't your base. Your stands are at your named base.", "warn")
		return
	end
	if stand.Index > RebirthService.GetActiveStands(session) then
		fireNotice(player, string.format("🔒 Stand %d is locked — rebirth to unlock more stands.", stand.Index), "warn")
		return
	end
	if not session.CarryingModel then
		fireNotice(player, "Pull a card at the machine first, then carry it here.", "info")
		return
	end
	placeCardOnStand(session, base, stand)
end

local function handleMachinePrompt(player)
	local session = DataService.GetSession(player)
	if not session then
		return
	end
	local now = os.clock()
	if now - session.LastPullAt < 1.5 then
		return
	end
	session.LastPullAt = now

	if session.CarryingModel then
		fireNotice(player, "You're already carrying a card — place it or lose it trying.", "warn")
		return
	end
	if session.Cash < CardData.PullCost then
		fireNotice(player, string.format("You need $%d for a pull. Your placed cards earn every second.", CardData.PullCost), "bad")
		return
	end

	DataService.AddCash(session, -CardData.PullCost)
	local definition = CardData.Roll(random)
	local mutationId = CardData.RollMutation(random)
	local model = createCardModel(definition, session.UserId, mutationId)
	local body = model.PrimaryPart
	model:PivotTo(world.Machine.OutputCFrame)

	if remotes then
		remotes.Reveal:FireAllClients(definition.Id, player.DisplayName, mutationId)
	end

	task.spawn(function()
		-- Flip the card out of the machine, then hand it over.
		for step = 1, 14 do
			if not model.Parent or not body.Parent then
				return
			end
			model:PivotTo(world.Machine.OutputCFrame * CFrame.Angles((step / 14) * math.pi * 2, 0, 0))
			task.wait(0.03)
		end
		model:PivotTo(world.Machine.OutputCFrame)
		if session.CarryingModel or not player.Parent then
			model:SetAttribute("State", "Loose")
			local prompt = body:FindFirstChild("CardPrompt")
			if prompt then
				prompt.Enabled = true
			end
			return
		end
		if not attachCardToPlayer(session, model) then
			model:SetAttribute("State", "Loose")
			local prompt = body:FindFirstChild("CardPrompt")
			if prompt then
				prompt.Enabled = true
			end
		end
	end)
end

local function tryBatSwing(attacker)
	local session = DataService.GetSession(attacker)
	if not session then
		return
	end
	local now = os.clock()
	if now - session.LastBatAt < CardData.BatCooldownSeconds then
		return
	end
	session.LastBatAt = now

	local character = attacker.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local look = root.CFrame.LookVector

	for _, victim in ipairs(Players:GetPlayers()) do
		if victim ~= attacker then
			local victimSession = DataService.GetSession(victim)
			local victimRoot = victim.Character and victim.Character:FindFirstChild("HumanoidRootPart")
			if victimSession and victimSession.CarryingModel and victimRoot then
				local offset = victimRoot.Position - root.Position
				local distance = offset.Magnitude
				if distance <= CardData.BatRange and (distance < 2 or offset.Unit:Dot(look) > 0.1) then
					local dropPosition = Vector3.new(victimRoot.Position.X, 3.3, victimRoot.Position.Z)
					local _, yaw = victimRoot.CFrame:ToOrientation()
					dropCarriedCard(victimSession, CFrame.new(dropPosition) * CFrame.Angles(0, yaw, 0))
					fireNotice(victim, "WHACK! Your card was knocked loose!", "bad")
					fireNotice(attacker, "You knocked their card loose — grab it!", "good")
					setWalkSpeed(victim, 6)
					task.delay(1, function()
						local current = DataService.GetSession(victim)
						if current and not current.CarryingModel then
							setWalkSpeed(victim, CardData.NormalWalkSpeed)
						end
					end)
					return
				end
			end
		end
	end

	-- No player was in range: the thief is a valid bat target too.
	ThiefEvent.OnBatSwing(attacker)
end

local function giveBat(player)
	local backpack = player:WaitForChild("Backpack", 5)
	if not backpack or backpack:FindFirstChild("CardBat") then
		return
	end
	local tool = Instance.new("Tool")
	tool.Name = "CardBat"
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ToolTip = "Knock a carried card loose"

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.55, 3.8, 0.55)
	handle.Color = Color3.fromRGB(255, 170, 40)
	handle.Material = Enum.Material.Wood
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	tool.Activated:Connect(function()
		tryBatSwing(player)
	end)
	tool.Parent = backpack
end

local function onCharacterAdded(player, character)
	local session = DataService.GetSession(player)
	if not session then
		return
	end
	local root = character:WaitForChild("HumanoidRootPart", 5)
	local humanoid = character:WaitForChild("Humanoid", 5)
	if root and session.BaseIndex then
		local base = world.Bases[session.BaseIndex]
		if base then
			character:PivotTo(base.SpawnCFrame)
		end
	end
	if humanoid then
		humanoid.WalkSpeed = session.CarryingModel and CardData.CarryWalkSpeed or CardData.NormalWalkSpeed
		humanoid.Died:Connect(function()
			local current = DataService.GetSession(player)
			if current and current.CarryingModel and root then
				local _, yaw = root.CFrame:ToOrientation()
				dropCarriedCard(current, CFrame.new(root.Position.X, 3.3, root.Position.Z) * CFrame.Angles(0, yaw, 0))
			end
		end)
	end
	giveBat(player)
end

local function assignBase(player, session)
	for baseIndex = 1, #world.Bases do
		if not baseOwners[baseIndex] then
			baseOwners[baseIndex] = player
			session.BaseIndex = baseIndex
			local base = world.Bases[baseIndex]
			local shortName = string.sub(player.DisplayName, 1, 18)
			base.SignLabel.Text = string.upper(shortName) .. "'S BASE"
			if base.BannerLabel then
				base.BannerLabel.Text = string.upper(shortName) .. "'S BASE"
			end
			return base
		end
	end
	return nil
end

local function restorePlacedCards(session, base)
	if not base then
		return
	end
	for standKey, entry in pairs(session.PlacedCards) do
		local standIndex = tonumber(standKey)
		local stand = standIndex and base.Stands[standIndex]
		local cardId, mutationId = CardData.ParsePlacedEntry(entry)
		local definition = cardId and CardData.CardsById[cardId]
		if stand and definition then
			local model = createCardModel(definition, session.UserId, mutationId)
			setModelPhysics(model, true)
			local body = model.PrimaryPart
			if body then
				model:PivotTo(stand.SlotCFrame)
			end
			model:SetAttribute("State", "Placed")
			model:SetAttribute("PlacedCFrame", stand.SlotCFrame)
			session.PlacedModels[standIndex] = model
			updateStandPrompt(base, stand)
		end
	end
end

local function fireNoticeAll(text, kind)
	for _, player in ipairs(Players:GetPlayers()) do
		fireNotice(player, text, kind)
	end
end

-- Sync a base's stand lock tags and rebirth pad text with its owner's
-- progression. Called on assignment, after a rebirth, and when a base frees.
local function refreshBaseStands(base, ownerSession)
	local activeStands = ownerSession and RebirthService.GetActiveStands(ownerSession) or CardData.StartingStands
	for _, stand in ipairs(base.Stands) do
		if stand.LockGui then
			stand.LockGui.Enabled = stand.Index > activeStands
		end
		updateStandPrompt(base, stand)
	end
	if base.RebirthPrompt then
		if ownerSession then
			base.RebirthPrompt.ObjectText = string.format("Rebirth — $%d for x%.1f income",
				RebirthService.GetCost(ownerSession),
				CardData.GetIncomeMultiplier(ownerSession.Rebirths + 1))
		else
			base.RebirthPrompt.ObjectText = "Rebirth Pad"
		end
	end
end

-- Rebirth hook: every card the player owns — carried or placed — is removed.
local function clearAllCards(player, session)
	if session.CarryingModel then
		local model = session.CarryingModel
		session.CarryingCardId = nil
		session.CarryingMutationId = nil
		session.CarryingModel = nil
		model:Destroy()
		setWalkSpeed(player, CardData.NormalWalkSpeed)
	end
	for standIndex, model in pairs(session.PlacedModels) do
		if model then
			model:Destroy()
		end
		session.PlacedModels[standIndex] = nil
	end
	for standKey in pairs(session.PlacedCards) do
		session.PlacedCards[standKey] = nil
	end
	session.IncomeCarry = 0
	DataService.RefreshLeaderstats(session)
end

-- Thief hooks: GameServer stays the only module that mutates card ownership.
local function getThiefTargets()
	local targets = {}
	for baseIndex, ownerPlayer in pairs(baseOwners) do
		local ownerSession = DataService.GetSession(ownerPlayer)
		if ownerSession then
			for standKey in pairs(ownerSession.PlacedCards) do
				local standIndex = tonumber(standKey)
				if standIndex then
					table.insert(targets, { BaseIndex = baseIndex, StandIndex = standIndex })
				end
			end
		end
	end
	table.sort(targets, function(a, b)
		if a.BaseIndex ~= b.BaseIndex then
			return a.BaseIndex < b.BaseIndex
		end
		return a.StandIndex < b.StandIndex
	end)
	return targets
end

local function stealPlacedCardForThief(baseIndex, standIndex)
	if BaseLockService.IsLocked(baseIndex) then
		return nil
	end
	local ownerPlayer = baseOwners[baseIndex]
	local ownerSession = ownerPlayer and DataService.GetSession(ownerPlayer)
	local base = world and world.Bases[baseIndex]
	local stand = base and base.Stands[standIndex]
	if not ownerSession or not stand then
		return nil
	end
	local entry = ownerSession.PlacedCards[tostring(standIndex)]
	if not entry then
		return nil
	end
	local cardId, mutationId = CardData.ParsePlacedEntry(entry)
	local definition = cardId and CardData.CardsById[cardId]
	local model = removeCardFromStand(ownerSession, base, stand)
	if not model then
		return nil
	end
	return model, ownerPlayer, definition and CardData.DisplayName(definition, mutationId) or "a card"
end

local function dropCardLoose(model, position)
	if not model or not model.Parent then
		return
	end
	detachWelds(model)
	setModelPhysics(model, true)
	local body = model.PrimaryPart
	if body then
		model:PivotTo(CFrame.new(Vector3.new(position.X, 3.3, position.Z))
			* CFrame.Angles(0, random:NextNumber(0, math.pi * 2), 0))
		local prompt = body:FindFirstChild("CardPrompt")
		if prompt then
			prompt.Enabled = true
		end
	end
	model:SetAttribute("State", "Loose")
end

local function setupPlayer(player)
	if DataService.GetSession(player) then
		return
	end
	local session = DataService.CreateSession(player)
	DataService.AttachLeaderstats(player, session)
	local base = assignBase(player, session)
	DataService.Load(player, session)
	restorePlacedCards(session, base)
	if base then
		refreshBaseStands(base, session)
		BaseLockService.SendState(player, base.Index)
	end

	session.CharacterConnection = player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	else
		player:LoadCharacter()
	end

	fireNotice(player, "Pull a card at the machine, carry it home, place it, protect it.", "info")
end

local function onPlayerRemoving(player)
	local session = DataService.GetSession(player)
	if not session then
		return
	end
	DataService.Save(player, session)

	if world then
		for _, model in ipairs(world.ActiveCards:GetChildren()) do
			if model:GetAttribute("OwnerUserId") == player.UserId then
				model:Destroy()
			end
		end
	end
	if session.BaseIndex then
		baseOwners[session.BaseIndex] = nil
		BaseLockService.ClearBase(session.BaseIndex)
		local base = world and world.Bases[session.BaseIndex]
		if base then
			base.SignLabel.Text = "BASE " .. session.BaseIndex
			if base.BannerLabel then
				base.BannerLabel.Text = "BASE " .. session.BaseIndex
			end
			refreshBaseStands(base, nil)
		end
	end
	if session.CharacterConnection then
		session.CharacterConnection:Disconnect()
	end
	DataService.RemoveSession(player)
end

function GameServer.Start()
	if started then
		return
	end
	started = true

	world = WorldBuilder.Build(Workspace)

	remotes = Instance.new("Folder")
	remotes.Name = "BrainrotRemotes"
	local notice = Instance.new("RemoteEvent")
	notice.Name = "Notice"
	notice.Parent = remotes
	local reveal = Instance.new("RemoteEvent")
	reveal.Name = "Reveal"
	reveal.Parent = remotes
	local rebirthRemote = Instance.new("RemoteEvent")
	rebirthRemote.Name = "Rebirth"
	rebirthRemote.Parent = remotes
	local lockStateRemote = Instance.new("RemoteEvent")
	lockStateRemote.Name = "LockState"
	lockStateRemote.Parent = remotes
	local adminCashRemote = Instance.new("RemoteEvent")
	adminCashRemote.Name = "AdminCash"
	adminCashRemote.Parent = remotes
	remotes.Parent = ReplicatedStorage
	GameServer.Remotes = remotes

	rebirthRemote.OnServerEvent:Connect(function(player)
		RebirthService.TryRebirth(player)
	end)

	-- Owner-only testing grant: verified against the place creator here on
	-- the server, so a tampered client firing this gets nothing at all.
	adminCashRemote.OnServerEvent:Connect(function(player)
		if game.CreatorType ~= Enum.CreatorType.User or player.UserId ~= game.CreatorId then
			return
		end
		local session = DataService.GetSession(player)
		if not session then
			return
		end
		DataService.AddCash(session, 10000)
		fireNotice(player, "👑 Admin: +$10,000", "good")
	end)

	world.Machine.Prompt.Triggered:Connect(handleMachinePrompt)
	for _, base in ipairs(world.Bases) do
		for _, stand in ipairs(base.Stands) do
			stand.Prompt.Triggered:Connect(function(player)
				handleStandPrompt(player, base, stand)
			end)
		end
		base.RebirthPrompt.Triggered:Connect(function(player)
			local session = DataService.GetSession(player)
			if not session then
				return
			end
			if session.BaseIndex ~= base.Index then
				fireNotice(player, "This isn't your base — your rebirth pad is at your named base.", "warn")
				return
			end
			RebirthService.TryRebirth(player)
		end)
		base.LockPrompt.Triggered:Connect(function(player)
			BaseLockService.TryLock(player, base)
		end)
	end

	RebirthService.Init({
		FireNotice = fireNotice,
		ClearCards = clearAllCards,
		RefreshBase = function(player, session)
			local base = session.BaseIndex and world.Bases[session.BaseIndex]
			if base then
				refreshBaseStands(base, session)
			end
		end,
		Save = function(player, session)
			DataService.Save(player, session)
		end,
	})
	BaseLockService.Init(world, {
		FireNotice = fireNotice,
		FireLockState = function(player, stateName, endsAt)
			lockStateRemote:FireClient(player, stateName, endsAt)
		end,
		GetBaseOwner = function(baseIndex)
			return baseOwners[baseIndex]
		end,
	})
	ThiefEvent.Init({
		World = world,
		FireNotice = fireNotice,
		FireNoticeAll = fireNoticeAll,
		IsLocked = function(baseIndex)
			return BaseLockService.IsLocked(baseIndex)
		end,
		GetTargets = getThiefTargets,
		StealPlacedCard = stealPlacedCardForThief,
		DropCardLoose = dropCardLoose,
	})

	Players.PlayerAdded:Connect(setupPlayer)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(setupPlayer, player)
	end

	if not RunService:IsStudio() then
		game:BindToClose(function()
			DataService.SaveAll()
		end)
	end

	-- Earn tick: every second, placed cards pay their owners — mutation
	-- multipliers first, then the owner's permanent rebirth multiplier.
	-- The rebirth multiplier can be fractional (x1.5), so sub-dollar income
	-- is carried over instead of being rounded away each second.
	task.spawn(function()
		while true do
			task.wait(1)
			for _, session in pairs(DataService.Sessions) do
				local income = 0
				for _, entry in pairs(session.PlacedCards) do
					local cardId, mutationId = CardData.ParsePlacedEntry(entry)
					local definition = cardId and CardData.CardsById[cardId]
					if definition then
						income += CardData.GetEarnPerSecond(definition, mutationId)
					end
				end
				if income > 0 then
					session.IncomeCarry += income * RebirthService.GetIncomeMultiplier(session)
					local payout = math.floor(session.IncomeCarry)
					if payout > 0 then
						session.IncomeCarry -= payout
						DataService.AddCash(session, payout)
					end
				end
			end
		end
	end)

	-- Auto-place: walking up to one of your own empty stands with a card on
	-- your back places it — no prompt needed. Prompt placement proved
	-- unreliable for real players in live playtests (the owner pulled card
	-- after card and placed zero), so proximity does the placing; the stand
	-- prompt stays for taking cards back and for stealing.
	task.spawn(function()
		while true do
			task.wait(0.25)
			for _, player in ipairs(Players:GetPlayers()) do
				local session = DataService.GetSession(player)
				if session and session.CarryingModel and session.BaseIndex then
					local base = world.Bases[session.BaseIndex]
					local character = player.Character
					local root = character and character:FindFirstChild("HumanoidRootPart")
					if base and root then
						for _, stand in ipairs(base.Stands) do
							if stand.Index <= RebirthService.GetActiveStands(session)
								and not session.PlacedCards[tostring(stand.Index)]
								and (root.Position - stand.Pedestal.Position).Magnitude <= 5 then
								placeCardOnStand(session, base, stand)
								break
							end
						end
					end
				end
			end
		end
	end)

	-- Rainbow-mutated cards cycle their hue wherever they currently are:
	-- machine output, a player's back, a stand, or the ground.
	task.spawn(function()
		while true do
			task.wait(0.08)
			local rainbowColor = Color3.fromHSV((os.clock() * 0.35) % 1, 0.65, 1)
			for _, model in ipairs(world.ActiveCards:GetChildren()) do
				if model:GetAttribute("MutationId") == "Rainbow" then
					local body = model.PrimaryPart
					if body then
						body.Color = rainbowColor
						local trim = model:FindFirstChild("GlowTrim")
						if trim then
							-- The trim is neon, so it keeps the same 55%
							-- dimming as every other neon in the game.
							trim.Color = Color3.new(rainbowColor.R * 0.55, rainbowColor.G * 0.55, rainbowColor.B * 0.55)
						end
					end
				end
			end
		end
	end)

	-- Placed cards idle-bob so a full base reads alive in screenshots.
	task.spawn(function()
		while true do
			task.wait(0.1)
			local t = os.clock()
			for _, session in pairs(DataService.Sessions) do
				for standIndex, model in pairs(session.PlacedModels) do
					local body = model and model.PrimaryPart
					local placedCFrame = model and model:GetAttribute("PlacedCFrame")
					if body and placedCFrame then
						model:PivotTo(placedCFrame
							* CFrame.new(0, math.sin(t * 2 + standIndex * 1.7) * 0.12, 0)
							* CFrame.Angles(0, math.sin(t * 1.3 + standIndex) * 0.06, 0))
					end
				end
			end
		end
	end)

	-- The hero hologram above the machine slowly spins and bobs, so the
	-- centre of the map is alive in every screenshot.
	if world.HoloCard then
		local holoCard = world.HoloCard
		local holoHome = holoCard:GetPivot()
		task.spawn(function()
			while true do
				task.wait(0.05)
				local t = os.clock()
				holoCard:PivotTo(CFrame.new(holoHome.Position + Vector3.new(0, math.sin(t * 0.8) * 0.5, 0))
					* CFrame.Angles(0, t * 0.25, 0))
			end
		end)
	end

	-- Autosave outside Studio.
	task.spawn(function()
		while true do
			task.wait(60)
			DataService.SaveAll()
		end
	end)

	print("[BrainrotCardHeist] Server started: machine, 8 bases, " .. (#CardData.Cards) .. " cards.")
end

return GameServer
