--!strict
-- JSON-safety check for saved deal state (owned by `projects`; contracts §9). PURE. DataStores store JSON: mixed or
-- sparse tables, non-finite numbers, metatables and invalid UTF-8 silently lose data or fail the save, so every
-- state ProjectService keeps in data.projects passes this first (Runs.start / Runs.act).
--
--   Plain.check(value) -> (ok, err?)   dense arrays or string-keyed maps, finite numbers, valid UTF-8, no metatables,
--                                      bounded size and depth

local Plain = {}

local MAX_NODES = 20000
local MAX_DEPTH = 14
local MAX_STRING = 4000

local function walk(v: any, depth: number, budget: { n: number }, path: string): (boolean, string?)
	budget.n += 1
	if budget.n > MAX_NODES then
		return false, "too large"
	end
	if depth > MAX_DEPTH then
		return false, "too deep at " .. path
	end
	local t = type(v)
	if t == "string" then
		if #v > MAX_STRING or utf8.len(v) == nil then
			return false, "bad string at " .. path
		end
		return true, nil
	elseif t == "number" then
		if v ~= v or v == math.huge or v == -math.huge then
			return false, "non-finite number at " .. path
		end
		return true, nil
	elseif t == "boolean" then
		return true, nil
	elseif t == "table" then
		if getmetatable(v) ~= nil then
			return false, "metatable at " .. path
		end
		local n = #v
		local count, numeric, stringy = 0, false, false
		for k, x in v do
			count += 1
			local kt = type(k)
			if kt == "number" then
				numeric = true
				if k ~= math.floor(k) or k < 1 or k > n then
					return false, "sparse array at " .. path
				end
			elseif kt == "string" then
				stringy = true
			else
				return false, "bad key type at " .. path
			end
			local ok, err = walk(x, depth + 1, budget, path .. "." .. tostring(k))
			if not ok then
				return false, err
			end
		end
		if numeric and stringy then
			return false, "mixed table at " .. path
		end
		if numeric and count ~= n then
			return false, "array with holes at " .. path
		end
		return true, nil
	end
	return false, "unsupported " .. t .. " at " .. path
end

function Plain.check(value: any): (boolean, string?)
	return walk(value, 1, { n = 0 }, "state")
end

return Plain
