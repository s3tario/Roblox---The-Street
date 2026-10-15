--!strict
-- Seeded, deterministic random number generator (sfc32, seeded with splitmix32).
-- Use this everywhere instead of math.random / Random so results reproduce in tests and on every server.

local Hash = require(script.Parent.Hash)

export type Rng = {
	next: (self: Rng) -> number,
	int: (self: Rng, lo: number, hi: number) -> number,
	range: (self: Rng, lo: number, hi: number) -> number,
	normal: (self: Rng, mean: number?, sd: number?) -> number,
	chance: (self: Rng, p: number) -> boolean,
	pick: <T>(self: Rng, list: { T }) -> T,
	weighted: <T>(self: Rng, entries: { { any } }) -> T,
	shuffle: <T>(self: Rng, list: { T }) -> { T },
	clone: (self: Rng) -> Rng,
	state: (self: Rng) -> { number },
	_a: number,
	_b: number,
	_c: number,
	_d: number,
}

local Rng = {}
Rng.__index = Rng

local function splitmix32(x: number): (number, number)
	x = bit32.band(x + 0x9E3779B9, 0xFFFFFFFF)
	local z = x
	z = Hash.imul(bit32.bxor(z, bit32.rshift(z, 16)), 0x85EBCA6B)
	z = Hash.imul(bit32.bxor(z, bit32.rshift(z, 13)), 0xC2B2AE35)
	z = bit32.bxor(z, bit32.rshift(z, 16))
	return z, x
end

-- seed: any number or string (strings are hashed).
function Rng.new(seed: any): Rng
	local s = if type(seed) == "number"
			and seed == math.floor(seed)
			and seed >= 0
			and seed < 4294967296
		then seed
		else Hash.u32(seed)
	local self = setmetatable({}, Rng) :: any
	local a, b, c, d
	a, s = splitmix32(s)
	b, s = splitmix32(s)
	c, s = splitmix32(s)
	d, s = splitmix32(s)
	self._a, self._b, self._c, self._d = a, b, c, d
	for _ = 1, 12 do
		self:next()
	end
	return self
end

-- Restore from :state() output.
function Rng.fromState(st: { number }): Rng
	local self = setmetatable({}, Rng) :: any
	self._a, self._b, self._c, self._d = st[1], st[2], st[3], st[4]
	return self
end

function Rng.state(self: Rng): { number }
	return { self._a, self._b, self._c, self._d }
end

-- Uniform in [0, 1).
function Rng.next(self: Rng): number
	local a, b, c, d = self._a, self._b, self._c, self._d
	local t = bit32.band(bit32.band(a + b, 0xFFFFFFFF) + d, 0xFFFFFFFF)
	d = bit32.band(d + 1, 0xFFFFFFFF)
	a = bit32.bxor(b, bit32.rshift(b, 9))
	b = bit32.band(c + bit32.lshift(c, 3), 0xFFFFFFFF)
	c = bit32.bor(bit32.lshift(c, 21), bit32.rshift(c, 11))
	c = bit32.band(c + t, 0xFFFFFFFF)
	self._a, self._b, self._c, self._d = a, b, c, d
	return t / 4294967296
end

-- Integer in [lo, hi] inclusive.
function Rng.int(self: Rng, lo: number, hi: number): number
	if hi < lo then
		lo, hi = hi, lo
	end
	return lo + math.floor(self:next() * (hi - lo + 1))
end

-- Real in [lo, hi).
function Rng.range(self: Rng, lo: number, hi: number): number
	return lo + self:next() * (hi - lo)
end

function Rng.normal(self: Rng, mean: number?, sd: number?): number
	local u1 = 1 - self:next() -- (0, 1]
	local u2 = self:next()
	local z = math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
	return (mean or 0) + z * (sd or 1)
end

function Rng.chance(self: Rng, p: number): boolean
	return self:next() < p
end

function Rng.pick<T>(self: Rng, list: { T }): T
	assert(#list > 0, "Rng:pick on empty list")
	return list[self:int(1, #list)]
end

-- entries = { {item, weight}, ... }
function Rng.weighted<T>(self: Rng, entries: { { any } }): T
	local total = 0
	for _, e in entries do
		total += e[2]
	end
	assert(total > 0, "Rng:weighted needs positive total weight")
	local r = self:next() * total
	for _, e in entries do
		r -= e[2]
		if r < 0 then
			return e[1]
		end
	end
	return entries[#entries][1]
end

-- Returns a new shuffled copy.
function Rng.shuffle<T>(self: Rng, list: { T }): { T }
	local out = table.clone(list)
	for i = #out, 2, -1 do
		local j = self:int(1, i)
		out[i], out[j] = out[j], out[i]
	end
	return out
end

function Rng.clone(self: Rng): Rng
	return Rng.fromState(self:state())
end

return Rng
