--!strict
-- Economy/Wallet: cash maths (PURE: no services, no clocks, no Instances; unit-tested in tests/shop).
--
--   Wallet.normalize(raw) -> Wallet                 repairs a loaded data.wallet in place (or builds a new one)
--   Wallet.validAmount(x) -> number?                a finite, positive number (nil otherwise)
--   Wallet.clampMult(x, range, default) -> number   sanitizes one multiplier
--   Wallet.kindOf(kind) -> (kindId, KindRule)       unknown or nil kinds fall back to Shop.economy.defaultKind
--   Wallet.multiplier(kind, mults) -> number        product of the multipliers that kind receives
--   Wallet.creditAmount(amount, kind, mults) -> number   whole dollars to credit (0 when invalid), capped
--   Wallet.credit(w, amount, source, now) -> number      adds an already-multiplied amount, returns the credit
--   Wallet.spend(w, amount, source, now) -> boolean      all or nothing; never below 0
--   Wallet.charge(w, amount, source, now) -> number      living costs: takes what's there, never below 0
-- mults = { event = salaryMult, daily = DailyService money boost, income = ProfileService:GetIncomeMult }

local Shop = require(script.Parent.Parent.Parent.Config.Shop)

export type Entry = { at: number, delta: number, source: string }
export type Wallet = {
	cash: number,
	earned: number,
	spent: number,
	living: number,
	recent: { Entry },
}
export type Mults = { event: number?, daily: number?, income: number? }

local Wallet = {}

local E = Shop.economy

local function finite(x: any): boolean
	return type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge
end

local function whole(x: any, default: number): number
	if not finite(x) then
		return default
	end
	return math.max(0, math.floor(x + 0.5))
end

function Wallet.normalize(raw: any): Wallet
	local w: any = if type(raw) == "table" then raw else {}
	w.cash = whole(w.cash, 0)
	w.earned = whole(w.earned, 0)
	w.spent = whole(w.spent, 0)
	w.living = whole(w.living, 0)
	local recent: { Entry } = {}
	if type(w.recent) == "table" then
		for _, e in w.recent do
			if type(e) == "table" and finite(e.delta) and finite(e.at) then
				table.insert(recent, {
					at = math.floor(e.at),
					delta = math.floor(e.delta + 0.5),
					source = if type(e.source) == "string" then string.sub(e.source, 1, 40) else "",
				})
			end
		end
	end
	while #recent > E.recent do
		table.remove(recent, 1)
	end
	w.recent = recent
	return w :: Wallet
end

function Wallet.validAmount(x: any): number?
	if not finite(x) or x <= 0 then
		return nil
	end
	return x
end

function Wallet.clampMult(x: any, range: { number }, default: number): number
	if not finite(x) or x <= 0 then
		return default
	end
	return math.clamp(x, range[1], range[2])
end

function Wallet.kindOf(kind: any): (string, Shop.KindRule)
	local id = if type(kind) == "string" and E.kinds[kind] then kind else E.defaultKind
	return id, E.kinds[id]
end

function Wallet.multiplier(kind: any, mults: Mults?): number
	local _, rule = Wallet.kindOf(kind)
	local m: Mults = mults or {}
	local total = 1
	if rule.event then
		total *= Wallet.clampMult(m.event, E.eventMult, 1)
	end
	if rule.daily then
		total *= Wallet.clampMult(m.daily, E.dailyMult, 1)
	end
	if rule.income then
		total *= Wallet.clampMult(m.income, E.incomeMult, 1)
	end
	return total
end

function Wallet.creditAmount(amount: any, kind: any, mults: Mults?): number
	local a = Wallet.validAmount(amount)
	if not a then
		return 0
	end
	local credit = math.floor(a * Wallet.multiplier(kind, mults) + 0.5)
	return math.clamp(credit, 0, E.maxCredit)
end

local function push(w: Wallet, delta: number, source: any, now: number)
	table.insert(w.recent, {
		at = math.floor(if finite(now) then now else 0),
		delta = delta,
		source = if type(source) == "string" then string.sub(source, 1, 40) else "",
	})
	while #w.recent > E.recent do
		table.remove(w.recent, 1)
	end
end

function Wallet.credit(w: Wallet, amount: number, source: any, now: number): number
	local credit = whole(amount, 0)
	if credit <= 0 then
		return 0
	end
	credit = math.min(credit, E.maxCredit)
	w.cash += credit
	w.earned += credit
	push(w, credit, source, now)
	return credit
end

function Wallet.spend(w: Wallet, amount: any, source: any, now: number): boolean
	if not finite(amount) or amount < 0 or amount > E.maxSpend then
		return false
	end
	local cost = math.floor(amount + 0.5)
	if cost == 0 then
		return true
	end
	if w.cash < cost then
		return false
	end
	w.cash -= cost
	w.spent += cost
	push(w, -cost, source, now)
	return true
end

function Wallet.charge(w: Wallet, amount: any, source: any, now: number): number
	if not finite(amount) or amount <= 0 then
		return 0
	end
	local cost = math.min(math.floor(amount + 0.5), E.maxLiving)
	local taken = math.clamp(cost, 0, w.cash)
	if taken <= 0 then
		return 0
	end
	w.cash -= taken
	w.living += taken
	push(w, -taken, source, now)
	return taken
end

return Wallet
