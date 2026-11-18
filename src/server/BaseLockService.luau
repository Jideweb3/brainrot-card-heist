-- BaseLockService.luau
-- The defence half of stealing: a base owner can raise a shield dome over
-- their base for 60 seconds. While it is up, every steal attempt on that
-- base's cards fails — players and the thief alike. Free to use, then a
-- 90-second cooldown once the shield drops.

local Workspace = game:GetService("Workspace")

local DataService = require(script.Parent.DataService)

local BaseLockService = {}
BaseLockService.LockSeconds = 60
BaseLockService.CooldownSeconds = 90

local hooks = nil
local world = nil
local states = {} -- [baseIndex] = { LockedUntil = 0, CooldownUntil = 0, Generation = 0 }

local function now()
	return Workspace:GetServerTimeNow()
end

local function getState(baseIndex)
	local state = states[baseIndex]
	if not state then
		state = { LockedUntil = 0, CooldownUntil = 0, Generation = 0 }
		states[baseIndex] = state
	end
	return state
end

-- hooks: {
--   FireNotice(player, text, kind),
--   FireLockState(player, stateName, endsAt),  -- stateName: locked/cooldown/ready
--   GetBaseOwner(baseIndex) -> Player?,
-- }
function BaseLockService.Init(serviceWorld, serviceHooks)
	world = serviceWorld
	hooks = serviceHooks
	for _, base in ipairs(world.Bases) do
		getState(base.Index)
	end
end

function BaseLockService.IsLocked(baseIndex)
	local state = states[baseIndex]
	return state ~= nil and now() < state.LockedUntil
end

function BaseLockService.Describe(baseIndex)
	local state = getState(baseIndex)
	local t = now()
	if t < state.LockedUntil then
		return "locked", state.LockedUntil
	elseif t < state.CooldownUntil then
		return "cooldown", state.CooldownUntil
	end
	return "ready", 0
end

function BaseLockService.SendState(player, baseIndex)
	if not hooks or not player then
		return
	end
	local name, endsAt = BaseLockService.Describe(baseIndex)
	hooks.FireLockState(player, name, endsAt)
end

local function setVisuals(base, locked)
	if base.ShieldDome then
		base.ShieldDome.Transparency = locked and 0.55 or 1
	end
	if base.LockSignGui then
		base.LockSignGui.Enabled = locked
	end
end

function BaseLockService.TryLock(player, base)
	if not hooks or not world then
		return false
	end
	local session = DataService.GetSession(player)
	if not session or session.BaseIndex ~= base.Index then
		hooks.FireNotice(player, "Only the base owner can lock this base.", "warn")
		return false
	end

	local state = getState(base.Index)
	local t = now()
	if t < state.LockedUntil then
		hooks.FireNotice(player, string.format("Already locked — %ds of shield left.", math.ceil(state.LockedUntil - t)), "info")
		return false
	end
	if t < state.CooldownUntil then
		hooks.FireNotice(player, string.format("Lock is recharging — %ds to go.", math.ceil(state.CooldownUntil - t)), "warn")
		return false
	end

	state.LockedUntil = t + BaseLockService.LockSeconds
	state.CooldownUntil = state.LockedUntil + BaseLockService.CooldownSeconds
	state.Generation += 1
	local generation = state.Generation

	setVisuals(base, true)
	BaseLockService.SendState(player, base.Index)
	hooks.FireNotice(player, "🛡 Base LOCKED for 60 seconds — nobody can steal from you.", "good")

	task.delay(BaseLockService.LockSeconds, function()
		if getState(base.Index).Generation ~= generation then
			return -- cleared or re-locked since; the newer timer owns the visuals
		end
		setVisuals(base, false)
		local owner = hooks.GetBaseOwner(base.Index)
		if owner then
			BaseLockService.SendState(owner, base.Index)
			hooks.FireNotice(owner, "Your base shield dropped. Lock recharges in 90s.", "warn")
		end
	end)
	task.delay(BaseLockService.LockSeconds + BaseLockService.CooldownSeconds, function()
		if getState(base.Index).Generation ~= generation then
			return
		end
		local owner = hooks.GetBaseOwner(base.Index)
		if owner then
			BaseLockService.SendState(owner, base.Index)
			hooks.FireNotice(owner, "🛡 Base lock is ready again.", "info")
		end
	end)
	return true
end

-- Reset a base when its owner leaves: shield down, timers wiped.
function BaseLockService.ClearBase(baseIndex)
	local state = getState(baseIndex)
	state.LockedUntil = 0
	state.CooldownUntil = 0
	state.Generation += 1
	if world then
		local base = world.Bases[baseIndex]
		if base then
			setVisuals(base, false)
		end
	end
end

return BaseLockService
