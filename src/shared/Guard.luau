--!strict
-- Validation for values arriving from the client. Every function returns the validated value,
-- or nil if invalid. Pattern:
--   local qty = Guard.int(rawQty, 1, 100000); if not qty then return end

local Guard = {}

local function finite(x: any): boolean
	return type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge
end

function Guard.num(x: any, lo: number?, hi: number?): number?
	if not finite(x) then
		return nil
	end
	if lo and x < lo then
		return nil
	end
	if hi and x > hi then
		return nil
	end
	return x
end

function Guard.int(x: any, lo: number?, hi: number?): number?
	local n = Guard.num(x, lo, hi)
	if n == nil or n ~= math.floor(n) then
		return nil
	end
	return n
end

function Guard.bool(x: any): boolean?
	if type(x) == "boolean" then
		return x
	end
	return nil
end

function Guard.str(x: any, maxLen: number?): string?
	if type(x) ~= "string" then
		return nil
	end
	if #x > (maxLen or 200) then
		return nil
	end
	if utf8.len(x) == nil then
		return nil
	end
	return x
end

-- Identifier: letters, digits, underscore, dash, colon; 1-64 chars.
function Guard.id(x: any): string?
	if type(x) ~= "string" or #x == 0 or #x > 64 then
		return nil
	end
	if string.find(x, "^[%w_%-:]+$") == nil then
		return nil
	end
	return x
end

-- set may be a list {"a","b"} or a map {a = true}.
function Guard.oneOf(x: any, set: { [any]: any }): any
	if x == nil then
		return nil
	end
	if set[x] ~= nil and type(x) ~= "number" then
		return x
	end
	for _, v in ipairs(set) do
		if v == x then
			return x
		end
	end
	return nil
end

-- Plain table (no metatable) with at most maxKeys entries and limited nesting depth.
function Guard.map(x: any, maxKeys: number?, maxDepth: number?): { [any]: any }?
	if type(x) ~= "table" or getmetatable(x) ~= nil then
		return nil
	end
	local limit = maxKeys or 64
	local depthLimit = maxDepth or 3
	local total = 0
	local function walk(t: any, depth: number): boolean
		if depth > depthLimit then
			return false
		end
		for k, v in t do
			total += 1
			if total > limit then
				return false
			end
			local kt = type(k)
			if kt ~= "string" and kt ~= "number" then
				return false
			end
			if kt == "number" and not finite(k) then
				return false
			end
			local vt = type(v)
			if vt == "table" then
				if getmetatable(v) ~= nil or not walk(v, depth + 1) then
					return false
				end
			elseif vt == "number" then
				if not finite(v) then
					return false
				end
			elseif vt == "string" then
				if #v > 500 then
					return false
				end
			elseif vt ~= "boolean" then
				return false
			end
		end
		return true
	end
	if not walk(x, 1) then
		return nil
	end
	return x
end

-- Array of up to maxLen elements, each passing elemGuard (if given).
function Guard.list(x: any, maxLen: number?, elemGuard: ((any) -> any)?): { any }?
	local t = Guard.map(x, maxLen or 64)
	if t == nil then
		return nil
	end
	local n = #t
	for k in t do
		if type(k) ~= "number" or k < 1 or k > n or k ~= math.floor(k) then
			return nil
		end
	end
	if elemGuard then
		for i = 1, n do
			if elemGuard(t[i]) == nil then
				return nil
			end
		end
	end
	return t
end

return Guard
