--!strict
-- Display formatting helpers.

local Format = {}

-- 1234567.8 -> "1,234,568" (decimals optional)
function Format.commas(n: number, decimals: number?): string
	local d = decimals or 0
	local neg = n < 0
	local s = string.format("%." .. d .. "f", math.abs(n))
	local intPart, frac = string.match(s, "^(%d+)(%.?%d*)$")
	local int: string = intPart or s
	local out = string.reverse((string.gsub(string.reverse(int), "(%d%d%d)", "%1,")))
	if string.sub(out, 1, 1) == "," then
		out = string.sub(out, 2)
	end
	return (if neg then "-" else "") .. out .. (frac or "")
end

-- 1234.5 -> "$1,235"; money(12.345, 2) -> "$12.35"
function Format.money(n: number, decimals: number?): string
	local s = Format.commas(math.abs(n), decimals)
	return (if n < 0 then "-$" else "$") .. s
end

-- 1250000 -> "$1.25M"
function Format.compactMoney(n: number): string
	local a = math.abs(n)
	local sign = if n < 0 then "-$" else "$"
	if a >= 1e12 then
		return sign .. string.format("%.2fT", a / 1e12)
	elseif a >= 1e9 then
		return sign .. string.format("%.2fB", a / 1e9)
	elseif a >= 1e6 then
		return sign .. string.format("%.2fM", a / 1e6)
	elseif a >= 1e4 then
		return sign .. string.format("%.1fK", a / 1e3)
	end
	return sign .. Format.commas(a)
end

-- 0.0321 -> "+3.21%" (ratio input). signed defaults to true.
function Format.pct(ratio: number, decimals: number?, signed: boolean?): string
	local d = decimals or 2
	local v = ratio * 100
	local s = string.format("%." .. d .. "f%%", v)
	if signed ~= false and v > 0 then
		s = "+" .. s
	end
	return s
end

function Format.signed(n: number, decimals: number?): string
	local s = string.format("%." .. (decimals or 0) .. "f", n)
	if n > 0 then
		s = "+" .. s
	end
	return s
end

-- 245 -> "4:05", 3725 -> "1:02:05"
function Format.clock(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	local h = s // 3600
	local m = (s % 3600) // 60
	local sec = s % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, sec)
	end
	return string.format("%d:%02d", m, sec)
end

-- 5400 -> "1h 30m", 90 -> "1m 30s"
function Format.duration(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	local h = s // 3600
	local m = (s % 3600) // 60
	local sec = s % 60
	if h > 0 then
		return string.format("%dh %02dm", h, m)
	elseif m > 0 then
		return string.format("%dm %02ds", m, sec)
	end
	return string.format("%ds", sec)
end

function Format.price(n: number): string
	return string.format("%.2f", n)
end

return Format
