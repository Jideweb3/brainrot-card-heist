-- CardData.luau
-- The single source of truth for every card in Brainrot Card Heist.
-- ImageId values are the uploaded Decal asset ids for the card faces; the
-- illustrated SurfaceGui face still renders underneath as a fallback.

local CardData = {}

CardData.StartingCash = 250
CardData.PullCost = 100
CardData.MaxStandsPerBase = 8 -- physical stand positions built at every base
CardData.StartingStands = 6 -- stands usable before any rebirth (+1 per rebirth)
CardData.RebirthBaseCost = 2500 -- doubles with every rebirth
CardData.RebirthIncomeBonus = 0.5 -- +50% income per rebirth, permanent
CardData.CarryWalkSpeed = 11
CardData.NormalWalkSpeed = 16
CardData.StealHoldSeconds = 2
CardData.BatCooldownSeconds = 0.45
CardData.BatRange = 9
CardData.SaveDataStoreName = "BrainrotCardHeist_v1"

CardData.Rarities = {
	Common = {
		Order = 1,
		Color = Color3.fromRGB(178, 190, 204),
		GlowColor = Color3.fromRGB(225, 235, 245),
	},
	Rare = {
		Order = 2,
		Color = Color3.fromRGB(52, 126, 246),
		GlowColor = Color3.fromRGB(105, 180, 255),
	},
	Epic = {
		Order = 3,
		Color = Color3.fromRGB(163, 73, 255),
		GlowColor = Color3.fromRGB(211, 132, 255),
	},
	Legendary = {
		Order = 4,
		Color = Color3.fromRGB(255, 176, 0),
		GlowColor = Color3.fromRGB(255, 220, 92),
	},
	Mythic = {
		Order = 5,
		Color = Color3.fromRGB(0, 214, 190),
		GlowColor = Color3.fromRGB(94, 255, 230),
	},
	Secret = {
		Order = 6,
		Color = Color3.fromRGB(38, 28, 66),
		GlowColor = Color3.fromRGB(178, 102, 255),
	},
}

local function card(id, name, rarity, earnPerSecond, pullWeight, symbol, imageId)
	return {
		Id = id,
		Name = name,
		Rarity = rarity,
		EarnPerSecond = earnPerSecond,
		PullWeight = pullWeight,
		Symbol = symbol,
		ImageId = imageId or 0,
	}
end

CardData.Cards = {
	card("tung_tung_sahur", "Tung Tung Sahur", "Common", 1, 160, "🪵", 100075106752000),
	card("pudding_pigeon", "Pudding Pigeon", "Common", 2, 130, "🕊️", 91074752847770),
	card("boneca_ambalabu", "Boneca Ambalabu", "Common", 2, 140, "🐸", 70386959170704),
	card("lirili_larila", "Lirili Larila", "Common", 3, 120, "🐘", 121766391083083),
	card("noodle_narwhal", "Noodle Narwhal", "Common", 4, 100, "🍜", 106791232734309),

	card("disco_donut_deer", "Disco Donut Deer", "Rare", 7, 70, "🍩", 113439948148765),
	card("chimpanzini_bananini", "Chimpanzini Bananini", "Rare", 6, 75, "🍌", 103092376576962),
	card("bombardiro_crocodilo", "Bombardiro Crocodilo", "Rare", 8, 65, "🐊", 79867200908467),
	card("bubble_butler", "Bubble Butler", "Rare", 9, 55, "🫧", 91933916664165),

	card("cappuccino_assassino", "Cappuccino Assassino", "Epic", 18, 35, "☕", 126776689315043),
	card("turbo_toaster_tiger", "Turbo Toaster Tiger", "Epic", 20, 32, "🐯", 71196465510372),
	card("ballerina_cappuccina", "Ballerina Cappuccina", "Epic", 22, 30, "🩰", 85629952357027),

	card("tralalero_tralala", "Tralalero Tralala", "Legendary", 50, 16, "🦈", 80468572654906),
	card("moonlight_muffin_moose", "Moonlight Muffin Moose", "Legendary", 58, 13, "🫎", 135787293315198),

	card("galaxy_gelato_giraffe", "Galaxy Gelato Giraffe", "Mythic", 140, 5, "🦒", 102090914648871),
	card("crystal_croissant_crab", "Crystal Croissant Crab", "Mythic", 120, 4, "🦀", 70606780279871),

	card("void_velvet_velociraptor", "Void Velvet Velociraptor", "Secret", 350, 1, "🦖", 137658996081590),
	card("golden_gondola_goose", "Golden Gondola Goose", "Secret", 300, 1, "🪿", 76041997477067),
}

CardData.CardsById = {}
CardData.TotalPullWeight = 0

for _, definition in ipairs(CardData.Cards) do
	assert(CardData.CardsById[definition.Id] == nil, "Duplicate card id: " .. definition.Id)
	assert(CardData.Rarities[definition.Rarity] ~= nil, "Unknown rarity: " .. definition.Rarity)
	CardData.CardsById[definition.Id] = definition
	CardData.TotalPullWeight += definition.PullWeight
end

-- Mutations: a second roll on every machine pull. A mutation renames and
-- re-tints the card and multiplies what it earns, everywhere it is paid.
CardData.Mutations = {
	None = {
		Order = 0,
		Name = "None",
		Prefix = "",
		Multiplier = 1,
		Weight = 82,
		Color = nil, -- falls back to the rarity colour
		GlowColor = nil,
	},
	Gold = {
		Order = 1,
		Name = "Gold",
		Prefix = "Gold",
		Multiplier = 2,
		Weight = 10,
		Color = Color3.fromRGB(255, 190, 55),
		GlowColor = Color3.fromRGB(255, 222, 110),
	},
	Diamond = {
		Order = 2,
		Name = "Diamond",
		Prefix = "Diamond",
		Multiplier = 3,
		Weight = 5,
		Color = Color3.fromRGB(150, 225, 255),
		GlowColor = Color3.fromRGB(195, 246, 255),
	},
	Rainbow = {
		Order = 3,
		Name = "Rainbow",
		Prefix = "Rainbow",
		Multiplier = 5,
		Weight = 3,
		Color = Color3.fromRGB(205, 120, 255),
		GlowColor = Color3.fromRGB(255, 255, 255),
	},
}

CardData.TotalMutationWeight = 0
for _, mutation in pairs(CardData.Mutations) do
	CardData.TotalMutationWeight += mutation.Weight
end

function CardData.GetMutation(mutationId)
	if type(mutationId) == "string" and CardData.Mutations[mutationId] then
		return CardData.Mutations[mutationId]
	end
	return CardData.Mutations.None
end

function CardData.RollMutation(random)
	local roll = random:NextInteger(1, CardData.TotalMutationWeight)
	local ordered = { "Gold", "Diamond", "Rainbow", "None" }
	local cumulative = 0
	for _, mutationId in ipairs(ordered) do
		cumulative += CardData.Mutations[mutationId].Weight
		if roll <= cumulative then
			return mutationId
		end
	end
	return "None"
end

function CardData.GetEarnPerSecond(definition, mutationId)
	return definition.EarnPerSecond * CardData.GetMutation(mutationId).Multiplier
end

function CardData.DisplayName(definition, mutationId)
	local mutation = CardData.GetMutation(mutationId)
	if mutation.Prefix ~= "" then
		return mutation.Prefix .. " " .. definition.Name
	end
	return definition.Name
end

-- Placed cards persist as one string per stand: the bare card id for an
-- unmutated card (the phase-1 save shape, still readable), or
-- "cardId|MutationId" when a mutation is attached.
function CardData.MakePlacedEntry(cardId, mutationId)
	if mutationId and mutationId ~= "None" and CardData.Mutations[mutationId] then
		return cardId .. "|" .. mutationId
	end
	return cardId
end

function CardData.ParsePlacedEntry(entry)
	if type(entry) ~= "string" then
		return nil, "None"
	end
	local cardId, mutationId = string.match(entry, "^([^|]+)|([^|]+)$")
	if cardId then
		if CardData.Mutations[mutationId] and mutationId ~= "None" then
			return cardId, mutationId
		end
		return cardId, "None"
	end
	return entry, "None"
end

-- Rebirth maths, shared by the server, the thief's maths-free existence and
-- the client HUD so every screen quotes the same numbers.
function CardData.GetRebirthCost(rebirths)
	return math.floor(CardData.RebirthBaseCost * (2 ^ math.max(0, rebirths)))
end

function CardData.GetIncomeMultiplier(rebirths)
	return 1 + CardData.RebirthIncomeBonus * math.max(0, rebirths)
end

function CardData.GetActiveStands(rebirths)
	return math.min(CardData.MaxStandsPerBase, CardData.StartingStands + math.max(0, rebirths))
end

function CardData.GetRarityColor(rarity)
	local rarityData = CardData.Rarities[rarity]
	if rarityData then
		return rarityData.Color
	end
	return Color3.fromRGB(255, 255, 255)
end

function CardData.GetRarityGlowColor(rarity)
	local rarityData = CardData.Rarities[rarity]
	if rarityData then
		return rarityData.GlowColor
	end
	return Color3.fromRGB(255, 255, 255)
end

-- Weighted pull used by the machine. Random is injected by the server caller
-- in production code paths that need a reproducible test seed.
function CardData.Roll(random)
	local roll = random:NextInteger(1, CardData.TotalPullWeight)
	local cumulative = 0
	for _, definition in ipairs(CardData.Cards) do
		cumulative += definition.PullWeight
		if roll <= cumulative then
			return definition
		end
	end
	return CardData.Cards[#CardData.Cards]
end

return CardData
