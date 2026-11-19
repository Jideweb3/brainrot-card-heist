-- DataService.luau
-- Session state, leaderstats and guarded DataStore persistence.
-- Studio and place tests never touch the live DataStore: loading returns
-- starter data and saving is a no-op there.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CardData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CardData"))

local DataService = {}
DataService.Sessions = {}

local store = nil
if not RunService:IsStudio() then
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(CardData.SaveDataStoreName)
	end)
	if ok then
		store = result
	else
		warn("[BrainrotCardHeist] DataStore unavailable: " .. tostring(result))
	end
end

function DataService.CreateSession(player)
	local session = {
		Player = player,
		UserId = player.UserId,
		Cash = CardData.StartingCash,
		Rebirths = 0,
		BaseIndex = nil,
		CarryingCardId = nil,
		CarryingMutationId = nil,
		CarryingModel = nil,
		PlacedCards = {}, -- [standIndex as string] = placed entry ("cardId" or "cardId|MutationId")
		PlacedModels = {}, -- [standIndex] = Model (runtime only)
		IncomeCarry = 0, -- fractional income owed by the rebirth multiplier (runtime only)
		LuckMultiplier = 1, -- shop-bought pull luck (runtime only)
		LuckEndsAt = 0, -- os.clock() moment the luck runs out (runtime only)
		Loaded = false,
		LastPullAt = 0,
		LastBatAt = 0,
		CharacterConnection = nil,
	}
	DataService.Sessions[player] = session
	return session
end

function DataService.GetSession(player)
	return DataService.Sessions[player]
end

function DataService.AttachLeaderstats(player, session)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = session.Cash
	cash.Parent = leaderstats

	local cards = Instance.new("IntValue")
	cards.Name = "Cards"
	cards.Value = 0
	cards.Parent = leaderstats

	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Value = session.Rebirths
	rebirths.Parent = leaderstats

	leaderstats.Parent = player
	session.Leaderstats = leaderstats
	session.CashValue = cash
	session.CardsValue = cards
	session.RebirthsValue = rebirths
	DataService.RefreshLeaderstats(session)
end

function DataService.RefreshLeaderstats(session)
	if session.CashValue then
		session.CashValue.Value = math.floor(session.Cash)
	end
	if session.CardsValue then
		local count = 0
		for _ in pairs(session.PlacedCards) do
			count += 1
		end
		session.CardsValue.Value = count
	end
	if session.RebirthsValue then
		session.RebirthsValue.Value = session.Rebirths
	end
end

function DataService.SetCash(session, amount)
	session.Cash = math.max(0, math.floor(amount))
	DataService.RefreshLeaderstats(session)
end

function DataService.AddCash(session, amount)
	DataService.SetCash(session, session.Cash + amount)
end

function DataService.Load(player, session)
	if store then
		local ok, data = pcall(function()
			return store:GetAsync("Player_" .. player.UserId)
		end)
		if ok and type(data) == "table" then
			if type(data.Cash) == "number" then
				session.Cash = math.max(0, math.floor(data.Cash))
			end
			if type(data.Rebirths) == "number" then
				session.Rebirths = math.max(0, math.floor(data.Rebirths))
			end
			if type(data.PlacedCards) == "table" then
				for standKey, entry in pairs(data.PlacedCards) do
					local standIndex = tonumber(standKey)
					local cardId, mutationId = CardData.ParsePlacedEntry(entry)
					if standIndex and standIndex >= 1 and standIndex <= CardData.MaxStandsPerBase and cardId and CardData.CardsById[cardId] then
						session.PlacedCards[tostring(standIndex)] = CardData.MakePlacedEntry(cardId, mutationId)
					end
				end
			end
		elseif not ok then
			warn("[BrainrotCardHeist] Load failed for " .. player.Name .. ": " .. tostring(data))
		end
	end
	session.Loaded = true
	DataService.RefreshLeaderstats(session)
end

function DataService.Save(player, session)
	if not store or not session or not session.Loaded then
		return true
	end
	local placed = {}
	for standKey, entry in pairs(session.PlacedCards) do
		placed[tostring(standKey)] = entry
	end
	local ok, err = pcall(function()
		store:SetAsync("Player_" .. player.UserId, {
			Cash = math.floor(session.Cash),
			Rebirths = session.Rebirths,
			PlacedCards = placed,
			Version = 2,
		})
	end)
	if not ok then
		warn("[BrainrotCardHeist] Save failed for " .. player.Name .. ": " .. tostring(err))
	end
	return ok
end

function DataService.RemoveSession(player)
	local session = DataService.Sessions[player]
	DataService.Sessions[player] = nil
	return session
end

function DataService.SaveAll()
	for player, session in pairs(DataService.Sessions) do
		DataService.Save(player, session)
	end
end

-- Kept as an explicit player lookup for modules that receive a character or
-- user id from an instance attribute rather than a Player object.
function DataService.GetPlayerByUserId(userId)
	return Players:GetPlayerByUserId(userId)
end

return DataService
