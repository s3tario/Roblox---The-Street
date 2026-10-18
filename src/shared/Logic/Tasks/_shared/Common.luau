--!strict
-- Shared helpers for work task modules (owned by `work`; contracts §8). PURE: no services, no clocks, no Instances.
--
-- Context
--   Common.ctx(raw) -> Ctx         normalizes the ctx a module receives (every field has a safe default), so
--                                  modules work with the full WorkService ctx, careerPath's re-entry ctx or {}
--   Common.tier(ctx) -> 1 | 2 | 3  difficulty band: easy (< 0.34), medium (< 0.67), hard
--   Common.scaled(ctx, lo, hi) -> integer   lo at difficulty 0 .. hi at difficulty 1 (rounded)
--   Common.hints(ctx, lines) -> { string }? the first ctx.hints lines (nil when the player gets none)
-- Numbers
--   Common.num(x, default) -> number        finite number or default
--   Common.round(x, step?) -> number        nearest multiple of step (default 1)
--   Common.clamp(x, lo, hi) -> number
-- Text
--   Common.fill(template, vars) -> string   "{name}" substitution
--   Common.pct(ratio, decimals?) -> "12.5%"   Common.mult(x) -> "8.4x"   Common.money(m, unit?) -> "$1,240M"
--   Common.commas(n, decimals?) -> "1,240"
-- Lists
--   Common.pickN(rng, list, n) -> { T }     n distinct picks (shuffled copy)
--   Common.has(list, value) -> boolean

local Rng = require(script.Parent.Parent.Parent.Parent.Util.Rng)
local Format = require(script.Parent.Parent.Parent.Parent.Util.Format)

export type Ctx = {
	level: number,
	rank: number,
	track: string?,
	student: boolean,
	stats: { [string]: number },
	ovr: number,
	difficulty: number,
	facts: { [string]: any }?,
	now: number,
	hints: number,
	toleranceMult: number,
	charismaBonus: number,
	offer: { [string]: any }?,
	companyName: string?,
	firstName: string?,
}

local Common = {}

function Common.num(x: any, default: number): number
	if type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge then
		return x
	end
	return default
end

function Common.clamp(x: number, lo: number, hi: number): number
	if x ~= x then
		return lo
	end
	return if x < lo then lo elseif x > hi then hi else x
end

function Common.round(x: number, step: number?): number
	local s = step or 1
	if s <= 0 then
		return x
	end
	return math.floor(x / s + 0.5) * s
end

function Common.ctx(raw: any): Ctx
	local c = if type(raw) == "table" then raw else {}
	local stats: { [string]: number } = {}
	if type(c.stats) == "table" then
		for k, v in c.stats do
			if type(k) == "string" and type(v) == "number" and v == v then
				stats[k] = v
			end
		end
	end
	return {
		level = math.max(1, math.floor(Common.num(c.level, 1))),
		rank = math.max(0, math.floor(Common.num(c.rank, 0))),
		track = if type(c.track) == "string" and c.track ~= "" then c.track else nil,
		student = c.student == true or Common.num(c.rank, 0) <= 0,
		stats = stats,
		ovr = Common.num(c.ovr, 40),
		difficulty = Common.clamp(Common.num(c.difficulty, 0.3), 0, 1),
		facts = if type(c.facts) == "table" then c.facts else nil,
		now = Common.num(c.now, 0),
		hints = math.floor(Common.clamp(Common.num(c.hints, 0), 0, 3)),
		toleranceMult = Common.clamp(Common.num(c.toleranceMult, 1), 1, 1.5),
		charismaBonus = Common.clamp(Common.num(c.charismaBonus, 0), 0, 8),
		offer = if type(c.offer) == "table" then c.offer else nil,
		companyName = if type(c.companyName) == "string" and c.companyName ~= "" then c.companyName else nil,
		firstName = if type(c.firstName) == "string" and c.firstName ~= "" then c.firstName else nil,
	}
end

function Common.tier(ctx: Ctx): number
	if ctx.difficulty < 0.34 then
		return 1
	elseif ctx.difficulty < 0.67 then
		return 2
	end
	return 3
end

function Common.scaled(ctx: Ctx, lo: number, hi: number): number
	return math.floor(lo + (hi - lo) * ctx.difficulty + 0.5)
end

function Common.hints(ctx: Ctx, lines: { string }): { string }?
	if ctx.hints <= 0 or #lines == 0 then
		return nil
	end
	local out: { string } = {}
	for i = 1, math.min(ctx.hints, #lines) do
		table.insert(out, lines[i])
	end
	return out
end

function Common.fill(template: string, vars: { [string]: any }): string
	return (string.gsub(template, "{([%w_]+)}", function(key: string): string
		local v = vars[key]
		if v == nil then
			return "{" .. key .. "}"
		end
		return tostring(v)
	end))
end

function Common.commas(n: number, decimals: number?): string
	return Format.commas(n, decimals)
end

function Common.pct(ratio: number, decimals: number?): string
	return string.format("%." .. tostring(decimals or 1) .. "f%%", ratio * 100)
end

function Common.mult(x: number, decimals: number?): string
	return string.format("%." .. tostring(decimals or 1) .. "fx", x)
end

-- Millions by default: money(1240) -> "$1,240M"; money(12.5, "B", 1) -> "$12.5B"
function Common.money(m: number, unit: string?, decimals: number?): string
	local s = Format.commas(math.abs(m), decimals or 0)
	return (if m < 0 then "-$" else "$") .. s .. (unit or "M")
end

function Common.pickN<T>(rng: Rng.Rng, list: { T }, n: number): { T }
	local shuffled = rng:shuffle(list)
	local out: { T } = {}
	for i = 1, math.min(n, #shuffled) do
		table.insert(out, shuffled[i])
	end
	return out
end

function Common.has(list: { any }, value: any): boolean
	return table.find(list, value) ~= nil
end

return Common
