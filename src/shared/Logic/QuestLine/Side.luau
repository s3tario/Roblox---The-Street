--!strict
-- QuestLine/Side (owned by `tutorial`): side-quest progress, PURE. State lives in data.campus.quests:
-- { [questId] = { n = progress, done = unix time?, seen = { [key] = true } } }.
--
--   Side.matches(on, event) -> (boolean, key?)    does this event advance a quest? key = the unique thing counted
--                                                 (a talk quest counts each NPC once)
--   Side.apply(quests, defs, event, now) -> { SideDef }   advances every matching open quest; returns the newly
--                                                 completed ones (the caller pays their rewards)
--   Side.progress(quests, def) -> (n, done)
--   Side.view(quests, defs, phase?) -> { Row }    Row = { id, title, desc, phase, n, goal, done, reward }
--   Side.rewardText(reward) -> string             "60 XP + $150"
-- Events: { kind = "task", taskId, quality } | { kind = "talk", npcId } | { kind = "outfit", level }
--   | { kind = "deal" } | { kind = "trade", pnl? } | { kind = "review", band }

local Quests = require(script.Parent.Parent.Parent.Config.Quests)
local Format = require(script.Parent.Parent.Parent.Util.Format)

export type SideDef = Quests.SideDef
export type Row = {
	id: string,
	title: string,
	desc: string,
	phase: string,
	n: number,
	goal: number,
	done: boolean,
	reward: string,
}

local Side = {}

local function num(x: any, default: number): number
	if type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge then
		return x
	end
	return default
end

function Side.matches(on: { [string]: any }, event: { [string]: any }): (boolean, string?)
	if type(on) ~= "table" or type(event) ~= "table" or on.kind ~= event.kind then
		return false, nil
	end
	local kind = on.kind
	if kind == "task" then
		if event.taskId ~= on.taskId then
			return false, nil
		end
		if on.minQuality and num(event.quality, 0) < on.minQuality then
			return false, nil
		end
		return true, nil
	elseif kind == "talk" then
		if type(on.npcs) ~= "table" or table.find(on.npcs, event.npcId) == nil then
			return false, nil
		end
		return true, tostring(event.npcId)
	elseif kind == "outfit" then
		return num(event.level, 0) >= num(on.level, 99), nil
	elseif kind == "trade" then
		if on.profitable and num(event.pnl, 0) <= 0 then
			return false, nil
		end
		return true, nil
	elseif kind == "review" then
		return on.band == nil or event.band == on.band, nil
	elseif kind == "deal" then
		return true, nil
	end
	return false, nil
end

local function stateOf(quests: { [string]: any }, id: string): { [string]: any }
	local s = quests[id]
	if type(s) ~= "table" then
		s = { n = 0, seen = {} }
		quests[id] = s
	end
	if type(s.seen) ~= "table" then
		s.seen = {}
	end
	s.n = math.max(0, math.floor(num(s.n, 0)))
	return s
end

function Side.progress(quests: { [string]: any }, def: SideDef): (number, boolean)
	local s = quests[def.id]
	if type(s) ~= "table" then
		return 0, false
	end
	local done = type(s.done) == "number" and s.done > 0
	return math.min(def.goal, math.floor(num(s.n, 0))), done
end

function Side.apply(quests: { [string]: any }, defs: { SideDef }, event: { [string]: any }, now: number): { SideDef }
	local finished: { SideDef } = {}
	for _, def in defs do
		local ok, key = Side.matches(def.on, event)
		if ok then
			local s = stateOf(quests, def.id)
			if not (type(s.done) == "number" and s.done > 0) then
				if key then
					if s.seen[key] ~= true then
						s.seen[key] = true
						s.n += 1
					end
				elseif def.on.kind == "outfit" then
					s.n = def.goal
				else
					s.n += 1
				end
				if s.n >= def.goal then
					s.n = def.goal
					s.done = now
					table.insert(finished, def)
				end
			end
		end
	end
	return finished
end

function Side.rewardText(reward: { xp: number?, cash: number? }): string
	local parts: { string } = {}
	if reward.xp and reward.xp > 0 then
		table.insert(parts, Quests.text("reward_xp", { xp = Format.commas(reward.xp) }))
	end
	if reward.cash and reward.cash > 0 then
		table.insert(parts, Quests.text("reward_cash", { cash = Format.money(reward.cash) }))
	end
	return table.concat(parts, Quests.text("reward_join"))
end

function Side.view(quests: { [string]: any }, defs: { SideDef }, phase: string?): { Row }
	local rows: { Row } = {}
	for _, def in defs do
		if phase == nil or def.phase == phase then
			local n, done = Side.progress(quests, def)
			table.insert(rows, {
				id = def.id,
				title = def.title,
				desc = def.desc,
				phase = def.phase,
				n = n,
				goal = def.goal,
				done = done,
				reward = Side.rewardText(def.reward),
			})
		end
	end
	return rows
end

return Side
