--!strict
-- WardrobeService: one player character's Career Look state machine (RUNTIME ONLY, server).
--
-- A character starts "native" (as Roblox loaded it). The first pass captures its HumanoidDescription, then brings it
-- to what the data asks for: "career" (standardized body + fitted layers, Look.luau) or "avatar" (the captured
-- description, "Wear my avatar"). Passes are serialized by `busy`; a request during a pass marks it `dirty` and the
-- running pass loops once more with the latest data. If something rebuilds the body parts later, the layers are
-- rebuilt on the new parts. Nothing here trusts a character to survive a yield: every step re-checks.
--
--   Character.new(player, character, source) -> State     source(player) -> Want? (nil until the profile loads)
--   Character.apply(cs) -> boolean                        run passes until the look matches the data (yields)
--   Character.refresh(cs)                                 re-dress now when possible, else start a pass
--   Character.alive(cs) -> boolean                        the player's current, living character
--   Character.drop(cs)                                    disconnect and forget (respawn, leave)

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Wardrobe = require(Shared.Assets.Wardrobe)
local Fit = require(Shared.Assets.Wardrobe.Fit)
local Look = require(script.Parent.Look)

local Character = {}

export type Mode = "native" | "career" | "avatar"
-- What the data asks for right now.
export type Want = { wearAvatar: boolean, equipped: { [string]: string }, logo: Look.Logo? }
export type Source = (player: Player) -> Want?
export type State = {
	player: Player,
	character: Model,
	source: Source,
	original: HumanoidDescription?,
	mode: Mode,
	busy: boolean,
	dirty: boolean,
	parts: { [string]: BasePart },
	conns: { RBXScriptConnection },
	repairQueued: boolean,
	dead: boolean,
}

local MAX_PASSES = 5

function Character.alive(cs: State): boolean
	return not cs.dead and Look.current(cs.player, cs.character)
end

function Character.drop(cs: State)
	if cs.dead then
		return
	end
	cs.dead = true
	for _, c in cs.conns do
		c:Disconnect()
	end
	table.clear(cs.conns)
	local original = cs.original
	cs.original = nil
	if original then
		original:Destroy()
	end
end

-- Puts the wanted look on a standardized character (synchronous).
local function dress(cs: State, want: Want?)
	if cs.mode ~= "career" or not Character.alive(cs) then
		return
	end
	local w = want or cs.source(cs.player)
	if not w or not Character.alive(cs) then
		return
	end
	Look.dress(cs.character, w.equipped, Look.skinOf(cs.original), w.logo)
	cs.parts = Wardrobe.bodyParts(cs.character)
end

-- One pass: brings the character to the mode the data asks for, then dresses it. May yield.
local function step(cs: State)
	local want = cs.source(cs.player)
	if not want then
		return
	end
	if not cs.character:IsDescendantOf(workspace) then
		return -- ApplyDescription needs a parented character; the spawn flow runs a pass once it is
	end
	if not cs.original and cs.mode == "native" then
		-- remember the avatar exactly as Roblox loaded it, before the first change. This is the ONLY place that
		-- captures it: passes are serialized, so a capture can never see the standardized body.
		local captured = Look.capture(cs.player, cs.character, 10)
		if not Character.alive(cs) then
			if captured then
				captured:Destroy()
			end
			return
		end
		cs.original = captured
	end
	if want.wearAvatar then
		if cs.mode == "career" then
			if not cs.original then
				cs.original = Look.fetch(cs.player)
				if not Character.alive(cs) then
					return
				end
			end
			Look.restore(cs.character, cs.original)
		end
		cs.mode = "avatar"
		return
	end
	if cs.mode ~= "career" then
		local ok = Look.standardize(cs.character, cs.original)
		if not Character.alive(cs) then
			return
		end
		if not ok then
			-- not an R15 rig (or ApplyDescription is unavailable): still dress what we can
			warn("[WardrobeService] couldn't standardize " .. cs.player.Name .. "'s body; dressing as is")
		end
		cs.mode = "career"
	end
	-- the data may have changed while standardizing: dress with the latest
	dress(cs, nil)
end

function Character.apply(cs: State): boolean
	if not Character.alive(cs) then
		return false
	end
	if cs.busy then
		cs.dirty = true -- the running pass picks the latest data up
		return true
	end
	cs.busy = true
	local ok, err = pcall(function()
		local passes = 0
		repeat
			cs.dirty = false
			step(cs)
			passes += 1
		until not cs.dirty or not Character.alive(cs) or passes >= MAX_PASSES
	end)
	cs.busy = false
	if not ok then
		warn("[WardrobeService] ApplyLook failed for " .. cs.player.Name .. ": " .. tostring(err))
		return false
	end
	return true
end

function Character.refresh(cs: State)
	if not Character.alive(cs) then
		return
	end
	if cs.busy then
		cs.dirty = true
		return
	end
	local want = cs.source(cs.player)
	if not want then
		return
	end
	if cs.mode == "career" and not want.wearAvatar then
		local ok, err = pcall(function()
			dress(cs, want)
		end)
		if not ok then
			warn("[WardrobeService] dress failed for " .. cs.player.Name .. ": " .. tostring(err))
		end
	else
		task.spawn(Character.apply, cs)
	end
end

-- Something replaced a body part (a script applying a description, a scale change): rebuild the layers on the new
-- parts. Our own standardize runs inside a pass (busy), and the parts snapshot taken after dressing filters out the
-- (deferred) ChildAdded events it caused.
local function onChildAdded(cs: State, child: Instance)
	if cs.dead or cs.mode ~= "career" or not child:IsA("BasePart") or not Fit.BODY_SET[child.Name] then
		return
	end
	if cs.parts[child.Name] == child or cs.repairQueued then
		return
	end
	cs.repairQueued = true
	task.delay(0.3, function()
		cs.repairQueued = false
		if not Character.alive(cs) then
			return
		end
		for name, p in Wardrobe.bodyParts(cs.character) do
			if cs.parts[name] ~= p then
				Character.refresh(cs)
				return
			end
		end
	end)
end

function Character.new(player: Player, character: Model, source: Source): State
	local cs: State = {
		player = player,
		character = character,
		source = source,
		original = nil,
		mode = "native",
		busy = false,
		dirty = false,
		parts = {},
		conns = {},
		repairQueued = false,
		dead = false,
	}
	table.insert(
		cs.conns,
		character.ChildAdded:Connect(function(child)
			onChildAdded(cs, child)
		end)
	)
	table.insert(
		cs.conns,
		character.Destroying:Connect(function()
			Character.drop(cs)
		end)
	)
	return cs
end

return Character
