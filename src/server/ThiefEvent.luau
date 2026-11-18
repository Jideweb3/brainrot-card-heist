-- ThiefEvent.luau
-- The hazard: every few minutes a thief NPC storms the plaza, dashes to an
-- occupied base and tries to grab a placed card. A locked base turns it
-- away, a bat hit makes it drop everything and flee spinning, and if it
-- reaches the plaza edge with a card, that card is gone for good.
-- All card bookkeeping stays in GameServer; this module works through the
-- hooks it is given so the two never reach into each other.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CardData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CardData"))

local ThiefEvent = {}
ThiefEvent.EventSeconds = 45
ThiefEvent.MinWaitSeconds = 240 -- 4 minutes between storms
ThiefEvent.MaxWaitSeconds = 360 -- 6 minutes
ThiefEvent.FirstWaitSeconds = 90 -- the first storm comes sooner, so a fresh server shows one
ThiefEvent.GrabSeconds = 3
ThiefEvent.Speed = 15

local random = Random.new()
local hooks = nil
local active = nil -- { Model, Root, StolenModel, StolenOwner, Fled }

local function buildThief()
	local model = Instance.new("Model")
	model.Name = "CardThief"

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.Parent = model
	model.PrimaryPart = root

	local function limb(name, size, offset, color, material)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Color = color
		part.Material = material or Enum.Material.SmoothPlastic
		part.Anchored = false
		part.CanCollide = false
		part.Massless = true
		part.CFrame = CFrame.new(offset)
		part.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
		return part
	end

	limb("Torso", Vector3.new(2.2, 2.4, 1.1), Vector3.new(0, 0.2, 0), Color3.fromRGB(28, 28, 36))
	limb("Stripe", Vector3.new(2.3, 0.55, 1.2), Vector3.new(0, 0.55, 0), Color3.fromRGB(240, 240, 240))
	limb("ArmL", Vector3.new(0.7, 2, 0.7), Vector3.new(-1.5, 0.1, 0), Color3.fromRGB(28, 28, 36))
	limb("ArmR", Vector3.new(0.7, 2, 0.7), Vector3.new(1.5, 0.1, 0), Color3.fromRGB(28, 28, 36))
	limb("LegL", Vector3.new(0.8, 1.8, 0.8), Vector3.new(-0.55, -2, 0), Color3.fromRGB(52, 52, 66))
	limb("LegR", Vector3.new(0.8, 1.8, 0.8), Vector3.new(0.55, -2, 0), Color3.fromRGB(52, 52, 66))
	local head = limb("Head", Vector3.new(1.3, 1.3, 1.3), Vector3.new(0, 2.05, 0), Color3.fromRGB(255, 204, 153))
	limb("Mask", Vector3.new(1.4, 0.45, 1.4), Vector3.new(0, 2.18, 0), Color3.fromRGB(10, 10, 14))
	limb("Cap", Vector3.new(1.5, 0.4, 1.5), Vector3.new(0, 2.85, 0), Color3.fromRGB(230, 50, 60))
	limb("SwagSack", Vector3.new(1.6, 1.8, 1), Vector3.new(0, 0.45, 0.95), Color3.fromRGB(150, 110, 60), Enum.Material.Fabric)

	local tag = Instance.new("BillboardGui")
	tag.Name = "ThiefTag"
	tag.Size = UDim2.fromScale(7, 1.8)
	tag.StudsOffset = Vector3.new(0, 1.6, 0)
	tag.AlwaysOnTop = true
	tag.Parent = head

	local tagLabel = Instance.new("TextLabel")
	tagLabel.Name = "Label"
	tagLabel.Size = UDim2.fromScale(1, 1)
	tagLabel.BackgroundTransparency = 1
	tagLabel.Text = "🦝 THIEF!"
	tagLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
	tagLabel.TextScaled = true
	tagLabel.Font = Enum.Font.FredokaOne
	tagLabel.Parent = tag

	return model, root
end

-- Walk the thief root toward a target, bobbing as it goes. Returns false
-- when the thief was batted (Fled) or the model vanished mid-walk.
local function moveToward(targetPosition, deadline)
	local thief = active
	if not thief or not thief.Root.Parent then
		return false
	end
	local root = thief.Root
	while not thief.Fled and root.Parent and os.clock() < deadline do
		local position = root.Position
		local flatTarget = Vector3.new(targetPosition.X, position.Y, targetPosition.Z)
		local offset = flatTarget - position
		if offset.Magnitude < 2.2 then
			return true
		end
		local dt = task.wait()
		local step = math.min(offset.Magnitude, ThiefEvent.Speed * dt)
		local newPosition = position + offset.Unit * step
		local t = os.clock()
		local bob = math.abs(math.sin(t * 11)) * 0.28
		local rock = math.sin(t * 11) * 0.07
		root.CFrame = CFrame.lookAt(
			Vector3.new(newPosition.X, 3 + bob, newPosition.Z),
			Vector3.new(targetPosition.X, 3, targetPosition.Z)
		) * CFrame.Angles(0, 0, rock)
		if thief.StolenModel and thief.StolenModel.PrimaryPart then
			thief.StolenModel:PivotTo(root.CFrame
				* CFrame.new(0, 1.4, 2.1)
				* CFrame.Angles(0, math.pi, 0))
		end
	end
	return false
end

local function spinAndDespawn()
	local thief = active
	if not thief then
		return
	end
	local root = thief.Root
	if root and root.Parent then
		local start = root.CFrame
		for step = 1, 10 do
			if not root.Parent then
				break
			end
			local spin = (step / 10) * math.pi * 4
			local sink = (step / 10) * 1.6
			root.CFrame = (start - Vector3.new(0, sink, 0)) * CFrame.Angles(0, spin, 0)
			task.wait(0.045)
		end
	end
	if thief.Model then
		thief.Model:Destroy()
	end
end

local function targetStillValid(baseIndex, standIndex)
	for _, target in ipairs(hooks.GetTargets()) do
		if target.BaseIndex == baseIndex and target.StandIndex == standIndex then
			return true
		end
	end
	return false
end

local function runEvent()
	if active then
		return
	end
	local world = hooks.World
	local model, root = buildThief()
	root.CFrame = CFrame.new(26, 3, 26)
	model.Parent = world.World
	active = { Model = model, Root = root, StolenModel = nil, StolenOwner = nil, Fled = false }

	hooks.FireNoticeAll("🦝 A THIEF is loose! Protect your cards — bat it or lock your base!", "bad")
	local deadline = os.clock() + ThiefEvent.EventSeconds
	local escaped = false

	while not active.Fled and os.clock() < deadline and root.Parent do
		-- Pick a random occupied, unlocked base, so the storm does not
		-- always fall on the same player.
		local candidates = {}
		for _, target in ipairs(hooks.GetTargets()) do
			if not hooks.IsLocked(target.BaseIndex) then
				table.insert(candidates, target)
			end
		end
		local chosen = #candidates > 0 and candidates[random:NextInteger(1, #candidates)] or nil
		if not chosen then
			-- Nothing stealable: prowl the plaza, then give up.
			local prowl = Vector3.new(random:NextInteger(-40, 40), 3, random:NextInteger(-40, 40))
			moveToward(prowl, math.min(deadline, os.clock() + 6))
			if #hooks.GetTargets() == 0 then
				break
			end
			continue
		end

		local base = world.Bases[chosen.BaseIndex]
		local stand = base and base.Stands[chosen.StandIndex]
		if not stand then
			break
		end
		local slotPosition = stand.SlotCFrame.Position
		local toCentre = Vector3.new(-slotPosition.X, 0, -slotPosition.Z)
		local grabPosition = slotPosition + (toCentre.Magnitude > 0 and toCentre.Unit * 4.5 or Vector3.zero)
		if not moveToward(grabPosition, deadline) then
			break
		end
		if active.Fled or os.clock() >= deadline then
			break
		end

		-- Grab channel: 3 shaky seconds. A lock going up or the card
		-- vanishing under its hands aborts the grab.
		local grabEnd = os.clock() + ThiefEvent.GrabSeconds
		local aborted = false
		while os.clock() < grabEnd do
			if active.Fled or not root.Parent then
				aborted = true
				break
			end
			if hooks.IsLocked(chosen.BaseIndex) or not targetStillValid(chosen.BaseIndex, chosen.StandIndex) then
				aborted = true
				break
			end
			root.CFrame = root.CFrame * CFrame.Angles(0, math.sin(os.clock() * 30) * 0.03, 0)
			task.wait(0.1)
		end
		if aborted or active.Fled then
			continue
		end

		local stolenModel, ownerPlayer, displayName = hooks.StealPlacedCard(chosen.BaseIndex, chosen.StandIndex)
		if not stolenModel then
			continue
		end
		active.StolenModel = stolenModel
		active.StolenOwner = ownerPlayer
		if ownerPlayer then
			hooks.FireNotice(ownerPlayer, "🦝 The THIEF grabbed your " .. displayName .. "! Bat it before it escapes!", "bad")
		end

		-- Dash for the plaza edge, straight out past the robbed base.
		local basePosition = base.CFrame.Position
		local escapePosition = Vector3.new(basePosition.X, 3, basePosition.Z)
		if escapePosition.Magnitude > 0 then
			escapePosition = escapePosition.Unit * 104
		end
		if moveToward(escapePosition, deadline) and not active.Fled then
			escaped = true
			stolenModel:Destroy()
			active.StolenModel = nil
			if ownerPlayer then
				hooks.FireNotice(ownerPlayer, "The thief ESCAPED with your " .. displayName .. "! It's gone.", "bad")
			end
			hooks.FireNoticeAll("🦝 The thief got away with a card!", "bad")
		end
		break
	end

	if active and active.StolenModel then
		-- Time ran out mid-escape: the card drops where the thief stands.
		hooks.DropCardLoose(active.StolenModel, root.Position)
		active.StolenModel = nil
	end
	spinAndDespawn()
	active = nil
	if not escaped then
		hooks.FireNoticeAll("The thief is gone… for now.", "info")
	end
end

-- Called by GameServer whenever a player swings the bat: a hit in range
-- makes the thief drop its loot and flee. Returns true when it connected.
function ThiefEvent.OnBatSwing(attacker)
	if not active or active.Fled or not active.Root.Parent then
		return false
	end
	local character = attacker.Character
	local attackerRoot = character and character:FindFirstChild("HumanoidRootPart")
	if not attackerRoot then
		return false
	end
	if (attackerRoot.Position - active.Root.Position).Magnitude > CardData.BatRange + 1.5 then
		return false
	end

	active.Fled = true
	if active.StolenModel then
		hooks.DropCardLoose(active.StolenModel, active.Root.Position)
		active.StolenModel = nil
		if active.StolenOwner then
			hooks.FireNotice(active.StolenOwner, "Your card was knocked out of the thief's sack!", "good")
		end
	end
	hooks.FireNotice(attacker, "WHACK! You batted the thief away!", "good")
	return true
end

function ThiefEvent.IsActive()
	return active ~= nil
end

-- hooks: {
--   World,                                    -- WorldBuilder.Build result
--   FireNotice(player, text, kind),
--   FireNoticeAll(text, kind),
--   IsLocked(baseIndex) -> boolean,
--   GetTargets() -> { { BaseIndex, StandIndex }, ... } for stands holding a card,
--   StealPlacedCard(baseIndex, standIndex) -> model?, ownerPlayer?, displayName?,
--   DropCardLoose(model, position),
-- }
function ThiefEvent.Init(serviceHooks)
	hooks = serviceHooks
	task.spawn(function()
		task.wait(ThiefEvent.FirstWaitSeconds)
		while true do
			local ok, err = pcall(runEvent)
			if not ok then
				warn("[BrainrotCardHeist] Thief event failed: " .. tostring(err))
				if active then
					if active.Model then
						active.Model:Destroy()
					end
					active = nil
				end
			end
			task.wait(random:NextInteger(ThiefEvent.MinWaitSeconds, ThiefEvent.MaxWaitSeconds))
		end
	end)
end

return ThiefEvent
