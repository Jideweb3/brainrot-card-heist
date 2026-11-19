-- CardData.luau
-- The single source of truth for every card in Brainrot Card Heist.
-- ImageId values are the IMAGE asset ids behind the uploaded card-face
-- decals (a Decal's Texture and an ImageLabel both take the image id
-- directly). The first decal batch stored blank images, so every face was
-- re-uploaded on 2026-11-19 and these ids point at the verified pictures.
-- The illustrated SurfaceGui face still renders underneath as a fallback.

local CardData = {}

CardData.StartingCash = 250000
CardData.PullCost = 20000
CardData.MaxStandsPerBase = 8 -- physical stand positions built at every base
CardData.StartingStands = 6 -- stands usable before any rebirth (+1 per rebirth)
CardData.RebirthBaseCost = 500000 -- doubles with every rebirth
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
	card("tung_tung_sahur", "Tung Tung Sahur", "Common", 5000, 160, "🪵", 132252717047468),
	card("pudding_pigeon", "Pudding Pigeon", "Common", 10000, 130, "🕊️", 123815915093709),
	card("boneca_ambalabu", "Boneca Ambalabu", "Common", 10000, 140, "🐸", 128064126574855),
	card("lirili_larila", "Lirili Larila", "Common", 15000, 120, "🐘", 108483752320186),
	card("noodle_narwhal", "Noodle Narwhal", "Common", 20000, 100, "🍜", 94930411195202),

	card("disco_donut_deer", "Disco Donut Deer", "Rare", 35000, 70, "🍩", 79416168766739),
	card("chimpanzini_bananini", "Chimpanzini Bananini", "Rare", 30000, 75, "🍌", 94383215664898),
	card("bombardiro_crocodilo", "Bombardiro Crocodilo", "Rare", 40000, 65, "🐊", 87530254191723),
	card("bubble_butler", "Bubble Butler", "Rare", 45000, 55, "🫧", 106160357859055),

	card("cappuccino_assassino", "Cappuccino Assassino", "Epic", 90000, 35, "☕", 115057826790577),
	card("turbo_toaster_tiger", "Turbo Toaster Tiger", "Epic", 100000, 32, "🐯", 101825622281452),
	card("ballerina_cappuccina", "Ballerina Cappuccina", "Epic", 110000, 30, "🩰", 130915619468520),

	card("tralalero_tralala", "Tralalero Tralala", "Legendary", 250000, 16, "🦈", 138408680857327),
	card("moonlight_muffin_moose", "Moonlight Muffin Moose", "Legendary", 290000, 13, "🫎", 91057651035183),

	card("galaxy_gelato_giraffe", "Galaxy Gelato Giraffe", "Mythic", 700000, 5, "🦒", 84178604678239),
	card("crystal_croissant_crab", "Crystal Croissant Crab", "Mythic", 600000, 4, "🦀", 94259503030223),

	card("void_velvet_velociraptor", "Void Velvet Velociraptor", "Secret", 1750000, 1, "🦖", 79759084853193),
	card("golden_gondola_goose", "Golden Gondola Goose", "Secret", 1500000, 1, "🪿", 140127134931142),
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

-- Compact money text for every screen and label: $999, $12.5K, $2.5M,
-- $1.25B. The game's economy runs in thousands and millions now, and a
-- raw 7-digit number reads as noise in a screenshot.
function CardData.FormatMoney(amount)
	local value = math.floor(math.abs(amount))
	if value < 1000 then
		return "$" .. value
	end
	local function compact(divisor, suffix)
		local text = string.format("%.2f", value / divisor)
		text = string.gsub(text, "(%.%d-)0+$", "%1")
		text = string.gsub(text, "%.$", "")
		return "$" .. text .. suffix
	end
	if value < 1000000 then
		return compact(1000, "K")
	elseif value < 1000000000 then
		return compact(1000000, "M")
	end
	return compact(1000000000, "B")
end

-- What a card costs on the conveyor belt: a flat 12 seconds of its own
-- earning power (mutation included), so even the first belt card of the
-- day sits inside a new player's reach.
function CardData.GetBeltPrice(definition, mutationId)
	return CardData.GetEarnPerSecond(definition, mutationId) * 12
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

-- The luck shop's catalog: cash buys a timed multiplier on the machine's
-- pull odds. Luck fattens the weights of Epic-and-better cards only;
-- Commons and Rares keep their base weights, so a lucky pull visibly
-- shifts the mix instead of just renaming the same odds.
CardData.LuckProducts = {
	{ Id = "luck_1", Name = "Lucky Charm", Symbol = "\u{1F340}", Multiplier = 1.5, DurationSeconds = 300, Price = 2000000, Blurb = "x1.5 luck \u{2022} 5 min" },
	{ Id = "luck_2", Name = "Fortune Potion", Symbol = "\u{1F9EA}", Multiplier = 2, DurationSeconds = 300, Price = 10000000, Blurb = "x2 luck \u{2022} 5 min" },
	{ Id = "luck_3", Name = "Jackpot Juice", Symbol = "\u{1F3B0}", Multiplier = 3, DurationSeconds = 600, Price = 40000000, Blurb = "x3 luck \u{2022} 10 min" },
	{ Id = "luck_4", Name = "MEGA LUCK", Symbol = "\u{1F48E}", Multiplier = 5, DurationSeconds = 180, Price = 100000000, Blurb = "x5 luck \u{2022} 3 min" },
}

CardData.LuckProductsById = {}
for _, product in ipairs(CardData.LuckProducts) do
	CardData.LuckProductsById[product.Id] = product
end

-- Weighted pull with a luck multiplier applied to Epic-and-better cards.
function CardData.RollWithLuck(random, luckMultiplier)
	if not luckMultiplier or luckMultiplier <= 1 then
		return CardData.Roll(random)
	end
	local epicOrder = CardData.Rarities.Epic.Order
	local total = 0
	for _, definition in ipairs(CardData.Cards) do
		local weight = definition.PullWeight
		if CardData.Rarities[definition.Rarity].Order >= epicOrder then
			weight *= luckMultiplier
		end
		total += weight
	end
	local roll = random:NextNumber() * total
	local cumulative = 0
	for _, definition in ipairs(CardData.Cards) do
		local weight = definition.PullWeight
		if CardData.Rarities[definition.Rarity].Order >= epicOrder then
			weight *= luckMultiplier
		end
		cumulative += weight
		if roll <= cumulative then
			return definition
		end
	end
	return CardData.Cards[#CardData.Cards]
end

return CardData
