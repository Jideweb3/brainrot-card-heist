-- ConveyorService.luau
-- The card belt: fresh cards ride a straight conveyor across the north
-- side of the plaza, each with its price floating over it. Walk up,
-- hold the prompt, pay, and the card lands on your back like a machine
-- pull — carry it home and place it. A card nobody buys rides into the
-- return box at the end of the belt and is gone.
-- All card bookkeeping stays in GameServer; this module works through
-- the hooks it is given, the same pattern as ThiefEvent.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CardData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CardData"))

local ConveyorService = {}
ConveyorService.Speed = 7 -- studs per second
ConveyorService.MaxCards = 8
ConveyorService.SpawnGap = 14 -- studs of clear belt needed at the start
ConveyorService.SpawnInterval = 2.8

local random = Random.new()
local hooks = nil
local entries = {} -- { Model, Distance, Price, Definition, MutationId }

local function beltCFrame(belt, distance)
	local length = (belt.EndPosition - belt.StartPosition).Magnitude
	local t = math.clamp(distance / length, 0, 1)
	local position = belt.StartPosition:Lerp(belt.EndPosition, t)
	-- The card's centre rides 2.5 studs over the deck (half the card's
	-- height); unrotated, so its face looks south toward the plaza for
	-- the whole ride.
	return CFrame.new(position + Vector3.new(0, 2.5, 0))
end

local function setTagStat(model, text, color)
	local body = model and model.PrimaryPart
	local tag = body and body:FindFirstChild("CardTag")
	local stat = tag and tag:FindFirstChild("TagStat")
	if stat then
		stat.Text = text
		if color then
			stat.TextColor3 = color
		end
	end
end

local function earnTagText(definition, mutationId)
	return CardData.FormatMoney(CardData.GetEarnPerSecond(definition, mutationId)) .. "/s"
end

local function removeEntry(entry)
	for index, candidate in ipairs(entries) do
		if candidate == entry then
			table.remove(entries, index)
			return
		end
	end
end

local function tryBuy(player, entry)
	if not entry.Model or not entry.Model.Parent then
		return
	end
	local session = hooks.GetSession(player)
	if not session then
		return
	end
	if session.CarryingModel then
		hooks.FireNotice(player, "Your hands are full — place that card first.", "warn")
		return
	end
	if session.Cash < entry.Price then
		hooks.FireNotice(player, string.format("That card costs %s — your placed cards earn every second.",
			CardData.FormatMoney(entry.Price)), "bad")
		return
	end

	hooks.AddCash(session, -entry.Price)
	removeEntry(entry)
	setTagStat(entry.Model, earnTagText(entry.Definition, entry.MutationId), Color3.fromRGB(255, 224, 102))
	if hooks.AttachCard(session, entry.Model) then
		hooks.FireNotice(player, string.format("Bought %s for %s! Carry it home!",
			CardData.DisplayName(entry.Definition, entry.MutationId),
			CardData.FormatMoney(entry.Price)), "good")
	else
		-- No character to carry it right now: refund in full and drop
		-- the card loose at the belt, free for anyone to pick up.
		hooks.AddCash(session, entry.Price)
		local body = entry.Model.PrimaryPart
		local prompt = body and body:FindFirstChild("CardPrompt")
		if prompt then
			prompt.ActionText = "Pick Up"
			prompt.ObjectText = entry.Definition.Name
		end
		if body then
			hooks.DropCardLoose(entry.Model, body.Position)
		end
		hooks.FireNotice(player, "The card slipped off the belt — grab it!", "warn")
	end
end

local function spawnCard(belt)
	local definition = CardData.Roll(random)
	local mutationId = CardData.RollMutation(random)
	local model = hooks.CreateCardModel(definition, 0, mutationId)
	model:SetAttribute("State", "Belt")
	local price = CardData.GetBeltPrice(definition, mutationId)
	local entry = {
		Model = model,
		Distance = 0,
		Price = price,
		Definition = definition,
		MutationId = mutationId,
	}
	model:PivotTo(beltCFrame(belt, 0))
	setTagStat(model, "BUY " .. CardData.FormatMoney(price), Color3.fromRGB(120, 255, 170))
	local body = model.PrimaryPart
	local prompt = body and body:FindFirstChild("CardPrompt")
	if prompt then
		prompt.ActionText = "Buy Card"
		prompt.ObjectText = string.format("%s — %s",
			CardData.DisplayName(definition, mutationId), CardData.FormatMoney(price))
		prompt.HoldDuration = 0.3
		prompt.Enabled = true
		prompt.Triggered:Connect(function(player)
			tryBuy(player, entry)
		end)
	end
	table.insert(entries, entry)
end

-- hooks: {
--   World,                                    -- WorldBuilder.Build result (uses .Belt)
--   CreateCardModel(definition, ownerUserId, mutationId) -> Model,
--   AttachCard(session, model) -> boolean,
--   DropCardLoose(model, position),
--   FireNotice(player, text, kind),
--   GetSession(player) -> session?,
--   AddCash(session, amount),
-- }
function ConveyorService.Init(serviceHooks)
	hooks = serviceHooks
	local belt = hooks.World and hooks.World.Belt
	if not belt then
		warn("[BrainrotCardHeist] Conveyor has no belt to run on.")
		return
	end
	local length = (belt.EndPosition - belt.StartPosition).Magnitude

	-- The ride: advance every belt card; one that reaches the return
	-- box is destroyed, and any entry whose model vanished or left the
	-- belt (bought, dropped) prunes itself here.
	task.spawn(function()
		while true do
			local dt = task.wait(0.05)
			for index = #entries, 1, -1 do
				local entry = entries[index]
				if not entry.Model or not entry.Model.Parent
					or entry.Model:GetAttribute("State") ~= "Belt" then
					table.remove(entries, index)
				else
					entry.Distance += ConveyorService.Speed * dt
					if entry.Distance >= length then
						entry.Model:Destroy()
						table.remove(entries, index)
					else
						entry.Model:PivotTo(beltCFrame(belt, entry.Distance))
					end
				end
			end
		end
	end)

	-- The feeder: keep the belt stocked while the start is clear.
	task.spawn(function()
		while true do
			task.wait(ConveyorService.SpawnInterval)
			if #entries < ConveyorService.MaxCards then
				local clear = true
				for _, entry in ipairs(entries) do
					if entry.Distance < ConveyorService.SpawnGap then
						clear = false
						break
					end
				end
				if clear then
					local ok, err = pcall(spawnCard, belt)
					if not ok then
						warn("[BrainrotCardHeist] Belt spawn failed: " .. tostring(err))
					end
				end
			end
		end
	end)
end

return ConveyorService
