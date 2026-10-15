--!strict
-- Deterministic 32-bit hashing for numbers and strings. Same inputs give the same output on
-- every server, every client, and in Lune.

local Hash = {}

local FNV_OFFSET = 2166136261
local FNV_PRIME = 16777619

-- 32-bit multiply (wraps like C's uint32_t multiply).
local function imul(a: number, b: number): number
	local ah, al = bit32.rshift(a, 16), bit32.band(a, 0xFFFF)
	local bh, bl = bit32.rshift(b, 16), bit32.band(b, 0xFFFF)
	local high = bit32.band(ah * bl + al * bh, 0xFFFF)
	return bit32.band(al * bl + bit32.lshift(high, 16), 0xFFFFFFFF)
end
Hash.imul = imul

local function fmix32(h: number): number
	h = bit32.bxor(h, bit32.rshift(h, 16))
	h = imul(h, 0x85EBCA6B)
	h = bit32.bxor(h, bit32.rshift(h, 13))
	h = imul(h, 0xC2B2AE35)
	h = bit32.bxor(h, bit32.rshift(h, 16))
	return h
end
Hash.fmix32 = fmix32

local function feedString(h: number, s: string): number
	for i = 1, #s do
		h = imul(bit32.bxor(h, string.byte(s, i)), FNV_PRIME)
	end
	return h
end

local function encode(v: any): string
	local t = type(v)
	if t == "number" then
		if v == math.floor(v) and math.abs(v) < 2 ^ 53 then
			return string.format("%d", v)
		end
		return string.format("%.17g", v)
	elseif t == "string" then
		return v
	elseif t == "boolean" then
		return v and "T" or "F"
	elseif t == "nil" then
		return "~"
	end
	error("Hash: unsupported type " .. t)
end

-- Hash any number of numbers/strings/booleans into a uint32.
function Hash.u32(...: any): number
	local h = FNV_OFFSET
	local n = select("#", ...)
	for i = 1, n do
		h = feedString(h, encode((select(i, ...))))
		h = imul(bit32.bxor(h, 0x1F), FNV_PRIME) -- separator so ("ab","c") ~= ("a","bc")
	end
	return fmix32(h)
end

-- Hash into [0, 1).
function Hash.unit(...: any): number
	return Hash.u32(...) / 4294967296
end

-- Hash into a standard normal sample (Box-Muller on two derived uniforms).
function Hash.normal(...: any): number
	local h1 = Hash.u32(...)
	local h2 = fmix32(bit32.bxor(h1, 0x9E3779B9))
	local u1 = (h1 + 1) / 4294967297
	local u2 = h2 / 4294967296
	return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
end

return Hash
