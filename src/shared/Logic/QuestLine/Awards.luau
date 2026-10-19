--!strict
-- QuestLine/Awards (owned by `tutorial`): achievement rules, PURE. AchievementService turns other features' signals
-- into events; this module bumps the permanent counters (data.achievementProgress) and says which achievements a
-- new event unlocks (Config/Achievements filters).
--
--   Awards.counters(event) -> { string }        counter keys an event bumps: its kind, plus "review:<band>",
--                                               "trade:win" (pnl > 0) and "talk:<npcId>"
--   Awards.bump(progress, event)                increments those counters
--   Awards.matches(def, event, progress) -> boolean
--   Awards.process(defs, unlocked, progress, event) -> { id }   bumps, then returns the newly unlocked ids (in
--                                               list order; the caller stamps data.achievements)
--   Awards.check(defs, unlocked, progress, event) -> { id }     the same without bumping (catch-up on load from
--                                               the current state)
--   Awards.count(unlocked) -> number
--   Awards.isPlayerTrade(trade) -> boolean       a fill the player caused (a trade, a paper trade, their own stop or
--                                               take-profit), not a flatten on leave, a restore, a wipe or a rebirth
-- Event fields by kind: life_roll {rarities, schoolRarity, gpa} | task {taskId, quality} | exchange | talk {npcId}
--   | offer {held} | hired {source, companyType, companyId} | step {step} | trade {pnl?} | promotion {rank}
--   | review {band} | status {from, to} | lifeline | comeback | plaque | project {projectId, closed}
--   | outfit {level, required?} | level {level}

local Rarity = require(script.Parent.Parent.Parent.Config.Rarity)

export type Def = { id: string, on: { [string]: any }, [string]: any }

local Awards = {}

local function num(x: any, default: number): number
	if type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge then
		return x
	end
	return default
end

function Awards.counters(event: { [string]: any }): { string }
	local kind = tostring(event.kind)
	local out = { kind }
	if kind == "review" and type(event.band) == "string" then
		table.insert(out, "review:" .. event.band)
	elseif kind == "trade" and num(event.pnl, 0) > 0 then
		table.insert(out, "trade:win")
	elseif kind == "talk" and type(event.npcId) == "string" then
		table.insert(out, "talk:" .. event.npcId)
	end
	return out
end

function Awards.bump(progress: { [string]: any }, event: { [string]: any })
	for _, key in Awards.counters(event) do
		progress[key] = math.floor(num(progress[key], 0)) + 1
	end
end

local function hasRarity(event: { [string]: any }, rarity: string): boolean
	local list = event.rarities
	if type(list) ~= "table" then
		return false
	end
	for _, r in list do
		if r == rarity then
			return true
		end
	end
	return false
end

function Awards.matches(def: Def, event: { [string]: any }, progress: { [string]: any }): boolean
	local on = def.on
	if type(on) ~= "table" or on.kind ~= event.kind then
		return false
	end
	for key, want in on do
		if key == "kind" or key == "counter" then
			continue
		elseif key == "count" then
			if num(progress[on.counter or on.kind], 0) < num(want, math.huge) then
				return false
			end
		elseif key == "minQuality" then
			if num(event.quality, -1) < want then
				return false
			end
		elseif key == "band" or key == "source" or key == "companyType" or key == "step" or key == "projectId" then
			if event[key] ~= want then
				return false
			end
		elseif key == "closed" then
			if (event.closed == true) ~= (want == true) then
				return false
			end
		elseif key == "rarity" then
			if not hasRarity(event, want) then
				return false
			end
		elseif key == "schoolAtLeast" then
			if type(event.schoolRarity) ~= "string" or Rarity.order(event.schoolRarity) < Rarity.order(want) then
				return false
			end
		elseif key == "gpaAtLeast" then
			if num(event.gpa, 0) + 1e-9 < want then
				return false
			end
		elseif key == "pnlAtLeast" then
			if num(event.pnl, -math.huge) < want then
				return false
			end
		elseif key == "rankAtLeast" then
			if num(event.rank, 0) < want then
				return false
			end
		elseif key == "levelAtLeast" or key == "outfitLevel" then
			if num(event.level, 0) < want then
				return false
			end
		elseif key == "meetsFirm" then
			local required = event.required
			local ok = type(required) == "number" and num(event.level, 0) >= required
			if ok ~= (want == true) then
				return false
			end
		elseif key == "from" or key == "to" then
			if event[key] ~= want then
				return false
			end
		elseif key == "held" then
			if num(event.held, 0) < want then
				return false
			end
		elseif key == "all" then
			if type(want) ~= "table" then
				return false
			end
			for _, npcId in want do
				if num(progress["talk:" .. tostring(npcId)], 0) < 1 then
					return false
				end
			end
		else
			return false -- unknown filters never unlock anything
		end
	end
	return true
end

function Awards.check(
	defs: { Def },
	unlocked: { [string]: any },
	progress: { [string]: any },
	event: { [string]: any }
): { string }
	local out: { string } = {}
	for _, def in defs do
		if unlocked[def.id] == nil and Awards.matches(def, event, progress) then
			table.insert(out, def.id)
		end
	end
	return out
end

function Awards.process(
	defs: { Def },
	unlocked: { [string]: any },
	progress: { [string]: any },
	event: { [string]: any }
): { string }
	Awards.bump(progress, event)
	return Awards.check(defs, unlocked, progress, event)
end

Awards.PLAYER_TRADES = { trade = true, paper = true, stop = true, take = true } :: { [string]: boolean }

function Awards.isPlayerTrade(trade: any): boolean
	if type(trade) ~= "table" then
		return false
	end
	local kind = trade.kind
	return kind == nil or Awards.PLAYER_TRADES[kind] == true
end

function Awards.count(unlocked: { [string]: any }?): number
	local n = 0
	if type(unlocked) == "table" then
		for _, v in unlocked do
			if v ~= nil and v ~= false then
				n += 1
			end
		end
	end
	return n
end

return Awards
