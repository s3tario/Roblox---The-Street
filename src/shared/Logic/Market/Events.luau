--!strict
-- Market event overlays (owned by `market`; design v3 §10, spec §8). PURE: each overlay shapes the price path through
-- impulses (log moves spread over open ticks, optionally persisting into fair value) and volatility multipliers.
-- Logic/Market/Model runs them; MarketService:TriggerEvent(id, params) starts one. Only one runs at a time, but its
-- impulses (a meme stock's fade, a flash crash's recovery) may outlive it.
--
--   crash         index -15..-25% over ~3 min (params.depth), half of it persists: a slow, partial recovery
--   boom          index +10..+20% over ~4 min (params.depth), half persists
--   flash_crash   index -6..-9% in ~40 s (params.depth), 70% recovered by the end of the session
--   meme_rally    one ticker (params.ticker) +30..+80% (params.size) in ~3 min, fading over two market days
--   rate_shock    sectors move by size x rateSens (params.size 0.04..0.07): banks and real estate hit hardest
--   earnings_frenzy  three companies (params.tickers) report at the next close with 1.6x surprises
--   crazy_day     volatility x3 for one market day
--   fed_day       a rate decision params.decisionTick open ticks in (default 45): a +-1.5..3% jump with sector tilts
--   holiday       the exchange is closed for params.duration seconds (default one market day)
--
--   Events.get(id) -> Def?      Events.vol(state, ev) -> (marketMult, { [ticker] = mult }?)

local Types = require(script.Parent.Types)
local Schedule = require(script.Parent.Schedule)
local Tickers = require(script.Parent.Parent.Parent.Config.Tickers)
local Time = require(script.Parent.Parent.Parent.Util.Time)

type State = Types.State
type EventState = Types.EventState
type Kit = Types.Kit

export type Def = {
	id: string,
	closes: boolean,
	openTicks: number?,
	start: (state: State, ev: EventState, kit: Kit) -> (),
	tick: ((state: State, ev: EventState, kit: Kit) -> ())?,
	vol: ((state: State, ev: EventState) -> (number, { [string]: number }?))?,
}

local Events = {}

Events.IDS = Tickers.EVENT_IDS
Events.FRENZY_MULT = 1.6
Events.FRENZY_COUNT = 3

local OPEN_TICKS = Schedule.OPEN_TICKS

local function param(ev: EventState, key: string, lo: number, hi: number, default: number): number
	local v = ev.params[key]
	if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then
		return math.clamp(v, lo, hi)
	end
	return default
end

local defs: { [string]: Def } = {}

defs.crash = {
	id = "crash",
	closes = false,
	openTicks = OPEN_TICKS,
	start = function(state: State, ev: EventState, kit: Kit)
		local depth = param(ev, "depth", 0.05, 0.4, state.rng:range(0.15, 0.25))
		local fall = math.floor(param(ev, "ticks", 30, 140, 90))
		ev.data.depth = depth
		ev.data.fall = fall
		kit.impulse("market", nil, math.log(1 - depth), fall, { fvShare = 0.5, noMR = true })
	end,
	vol = function(_state: State, ev: EventState): (number, { [string]: number }?)
		return if ev.ticks <= (ev.data.fall or 90) then 1.8 else 1.3, nil
	end,
}

defs.boom = {
	id = "boom",
	closes = false,
	openTicks = OPEN_TICKS,
	start = function(state: State, ev: EventState, kit: Kit)
		local depth = param(ev, "depth", 0.03, 0.4, state.rng:range(0.1, 0.2))
		local rise = math.floor(param(ev, "ticks", 30, 140, 120))
		ev.data.depth = depth
		ev.data.rise = rise
		kit.impulse("market", nil, math.log(1 + depth), rise, { fvShare = 0.5, noMR = true })
	end,
	vol = function(): (number, { [string]: number }?)
		return 1.3, nil
	end,
}

defs.flash_crash = {
	id = "flash_crash",
	closes = false,
	openTicks = OPEN_TICKS,
	start = function(state: State, ev: EventState, kit: Kit)
		local depth = param(ev, "depth", 0.02, 0.2, state.rng:range(0.06, 0.09))
		local fall = 20
		local recover = OPEN_TICKS - fall
		ev.data.depth = depth
		ev.data.fall = fall
		local drop = math.log(1 - depth)
		kit.impulse("market", nil, drop, fall, { fvShare = 0, noMR = true })
		kit.impulse("market", nil, -0.7 * drop, recover, { fvShare = 0, noMR = true, delay = fall })
	end,
	vol = function(_state: State, ev: EventState): (number, { [string]: number }?)
		return if ev.ticks <= (ev.data.fall or 20) then 2.5 else 1.5, nil
	end,
}

local function memeTicker(state: State, ev: EventState): string
	local wanted = ev.params.ticker
	if type(wanted) == "string" and state.byId[wanted] then
		return wanted
	end
	local pool: { string } = {}
	for _, ts in state.tickers do
		if ts.def.memeable then
			table.insert(pool, ts.id)
		end
	end
	if #pool == 0 then
		return state.tickers[1].id
	end
	return state.rng:pick(pool)
end

defs.meme_rally = {
	id = "meme_rally",
	closes = false,
	openTicks = OPEN_TICKS,
	start = function(state: State, ev: EventState, kit: Kit)
		local id = memeTicker(state, ev)
		local size = param(ev, "size", 0.1, 1.5, state.rng:range(0.3, 0.8))
		local rise = 90
		local fade = 2 * OPEN_TICKS
		ev.data.ticker = id
		ev.data.name = state.byId[id].def.name
		ev.data.size = size
		local up = math.log(1 + size)
		kit.impulse("ticker", id, up, rise, { fvShare = 0, noMR = true })
		kit.impulse("ticker", id, -0.85 * up, fade, { fvShare = 0, noMR = true, delay = rise })
	end,
	vol = function(_state: State, ev: EventState): (number, { [string]: number }?)
		local id = ev.data.ticker
		if type(id) == "string" then
			return 1, { [id] = 3 }
		end
		return 1, nil
	end,
}

defs.rate_shock = {
	id = "rate_shock",
	closes = false,
	openTicks = OPEN_TICKS,
	start = function(state: State, ev: EventState, kit: Kit)
		local size = param(ev, "size", 0.01, 0.15, state.rng:range(0.04, 0.07))
		ev.data.size = size
		for id, sector in Tickers.sectors do
			local move = 1 + size * sector.rateSens
			if move > 0 then
				kit.impulse("sector", id, math.log(move), 60, { fvShare = 0.6, noMR = true })
			end
		end
	end,
	vol = function(_state: State, ev: EventState): (number, { [string]: number }?)
		return if ev.ticks <= 60 then 1.6 else 1.2, nil
	end,
}

defs.earnings_frenzy = {
	id = "earnings_frenzy",
	closes = false,
	openTicks = OPEN_TICKS,
	start = function(state: State, ev: EventState, _kit: Kit)
		local target = if state.phase == "open" and state.closedDay ~= state.day then state.day else state.day + 1
		local chosen: { string } = {}
		local wanted = ev.params.tickers
		if type(wanted) == "table" then
			for _, id in wanted :: { any } do
				if type(id) == "string" and state.byId[id] and not table.find(chosen, id) then
					table.insert(chosen, id)
				end
			end
		end
		local pool: { string } = {}
		for _, ts in state.tickers do
			if ts.next.day ~= target and not table.find(chosen, ts.id) then
				table.insert(pool, ts.id)
			end
		end
		pool = state.rng:shuffle(pool)
		while #chosen < Events.FRENZY_COUNT and #pool > 0 do
			table.insert(chosen, table.remove(pool, 1) :: string)
		end
		local names: { string } = {}
		for _, id in chosen do
			local e = state.byId[id].next
			e.day = target
			e.published = true
			e.frenzy = true
			table.insert(names, id)
		end
		ev.data.tickers = chosen
		ev.data.list = table.concat(names, ", ")
		ev.data.day = target
		-- runs until that day's close
		if target == state.day then
			ev.openTicks = math.max(1, OPEN_TICKS - math.max(0, state.k + 1))
		else
			ev.openTicks = OPEN_TICKS
		end
	end,
	vol = function(): (number, { [string]: number }?)
		return 1.3, nil
	end,
}

defs.crazy_day = {
	id = "crazy_day",
	closes = false,
	openTicks = OPEN_TICKS,
	start = function(_state: State, ev: EventState, _kit: Kit)
		ev.data.mult = param(ev, "mult", 1.5, 5, 3)
	end,
	vol = function(_state: State, ev: EventState): (number, { [string]: number }?)
		return ev.data.mult or 3, nil
	end,
}

defs.fed_day = {
	id = "fed_day",
	closes = false,
	openTicks = OPEN_TICKS,
	start = function(_state: State, ev: EventState, _kit: Kit)
		ev.data.decisionTick = math.floor(param(ev, "decisionTick", 5, OPEN_TICKS - 10, 45))
		ev.data.decided = false
	end,
	tick = function(state: State, ev: EventState, kit: Kit)
		if ev.data.decided or ev.ticks < ev.data.decisionTick then
			return
		end
		ev.data.decided = true
		local u = state.rng:next()
		local forced = ev.params.outcome
		local outcome: string = if forced == "hike"
				or forced == "cut"
				or forced == "hold"
			then forced
			elseif u < 0.4 then "hike"
			elseif u < 0.7 then "cut"
			else "hold"
		local size: number
		local dir: number
		if outcome == "hold" then
			size = state.rng:range(0.002, 0.006)
			dir = if state.rng:next() < 0.5 then -1 else 1
		else
			size = state.rng:range(0.015, 0.03)
			dir = if outcome == "hike" then -1 else 1
		end
		ev.data.outcome = outcome
		kit.impulse("market", nil, math.log(1 + dir * size), 5, { fvShare = 0.7 })
		if outcome ~= "hold" then
			local rates = if outcome == "hike" then 1 else -1
			for id, sector in Tickers.sectors do
				local move = 1 + rates * 0.012 * sector.rateSens
				if move > 0 then
					kit.impulse("sector", id, math.log(move), 5, { fvShare = 0.7 })
				end
			end
		end
		local move = (if dir > 0 then "rally " else "fall ") .. string.format("%.1f%%", size * 100)
		local kind = if outcome == "hike" then "fed_hike" elseif outcome == "cut" then "fed_cut" else "fed_hold"
		kit.news(kind, { move = move }, if outcome == "hike" then "bad" elseif outcome == "cut" then "good" else "info")
	end,
	vol = function(_state: State, ev: EventState): (number, { [string]: number }?)
		local d = ev.data.decisionTick or 45
		if ev.ticks < d then
			return 1.6, nil
		elseif ev.ticks < d + 15 then
			return 2.8, nil
		end
		return 1.3, nil
	end,
}

defs.holiday = {
	id = "holiday",
	closes = true,
	openTicks = nil,
	start = function(_state: State, ev: EventState, kit: Kit)
		local duration = param(ev, "duration", 30, 6 * Time.DAY_LEN, Time.DAY_LEN)
		ev.data.duration = duration
		ev.endsAt = kit.now + duration
	end,
}

Events.defs = defs

function Events.get(id: any): Def?
	if type(id) ~= "string" then
		return nil
	end
	return defs[id]
end

function Events.vol(state: State, ev: EventState?): (number, { [string]: number }?)
	if not ev then
		return 1, nil
	end
	local def = defs[ev.id]
	if not def or not def.vol then
		return 1, nil
	end
	return def.vol(state, ev)
end

return Events
