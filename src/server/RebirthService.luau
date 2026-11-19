-- RebirthService.luau
-- The progression ladder's big reset: trade your cash and placed cards for
-- a permanent income multiplier and one more stand slot, at a price that
-- doubles every time. Triggered from the base rebirth pad or the HUD
-- button; all state lives on the DataService session and persists.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CardData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CardData"))
local DataService = require(script.Parent.DataService)

local RebirthService = {}

local hooks = nil

-- hooks: {
--   FireNotice(player, text, kind),
--   ClearCards(player, session),        -- destroys carried + placed card models
--   RefreshBase(player, session),       -- stand prompts + lock tags for the base
--   Save(player, session),
-- }
function RebirthService.Init(serviceHooks)
	hooks = serviceHooks
end

function RebirthService.GetCost(session)
	return CardData.GetRebirthCost(session.Rebirths)
end

function RebirthService.GetIncomeMultiplier(session)
	return CardData.GetIncomeMultiplier(session.Rebirths)
end

function RebirthService.GetActiveStands(session)
	return CardData.GetActiveStands(session.Rebirths)
end

function RebirthService.TryRebirth(player)
	if not hooks then
		return false
	end
	local session = DataService.GetSession(player)
	if not session then
		return false
	end

	local cost = RebirthService.GetCost(session)
	if session.Cash < cost then
		hooks.FireNotice(player, string.format(
			"Rebirth costs %s — you have %s. Placed cards keep earning!",
			CardData.FormatMoney(cost), CardData.FormatMoney(session.Cash)), "bad")
		return false
	end

	-- The reset: cards and cash go, rebirth count and its perks stay.
	hooks.ClearCards(player, session)
	session.Rebirths += 1
	DataService.SetCash(session, CardData.StartingCash)
	session.IncomeCarry = 0
	DataService.RefreshLeaderstats(session)
	hooks.RefreshBase(player, session)
	hooks.Save(player, session)

	local multiplier = RebirthService.GetIncomeMultiplier(session)
	hooks.FireNotice(player, string.format(
		"♻ REBIRTH %d! Income is now x%.1f and stand %d is unlocked.",
		session.Rebirths, multiplier, RebirthService.GetActiveStands(session)), "good")
	return true
end

return RebirthService
