--!strict
-- Table helpers used by data, config and logic code.

local TableUtil = {}

function TableUtil.deepCopy<T>(v: T): T
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in v :: any do
		out[TableUtil.deepCopy(k)] = TableUtil.deepCopy(x)
	end
	return out :: any
end

-- Fill missing keys in `target` from `template` (recursively). Never overwrites existing values,
-- and never descends into template arrays (an existing array is left as the player's data).
function TableUtil.deepFill(target: { [any]: any }, template: { [any]: any }): { [any]: any }
	for k, v in template do
		local cur = target[k]
		if cur == nil then
			target[k] = TableUtil.deepCopy(v)
		elseif type(cur) == "table" and type(v) == "table" and not TableUtil.isArray(v) then
			TableUtil.deepFill(cur, v)
		end
	end
	return target
end

function TableUtil.isArray(t: { [any]: any }): boolean
	local n = #t
	if n == 0 then
		return false
	end
	local count = 0
	for _ in t do
		count += 1
	end
	return count == n
end

function TableUtil.count(t: { [any]: any }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

function TableUtil.keys<K>(t: { [K]: any }): { K }
	local out = {}
	for k in t do
		table.insert(out, k)
	end
	return out
end

function TableUtil.sortedKeys(t: { [any]: any }): { any }
	local out = TableUtil.keys(t)
	table.sort(out, function(a, b)
		return tostring(a) < tostring(b)
	end)
	return out
end

function TableUtil.map<T, U>(list: { T }, fn: (T, number) -> U): { U }
	local out = table.create(#list)
	for i, v in list do
		out[i] = fn(v, i)
	end
	return out
end

function TableUtil.filter<T>(list: { T }, fn: (T, number) -> boolean): { T }
	local out = {}
	for i, v in list do
		if fn(v, i) then
			table.insert(out, v)
		end
	end
	return out
end

function TableUtil.sum(list: { number }): number
	local s = 0
	for _, v in list do
		s += v
	end
	return s
end

function TableUtil.deepEqual(a: any, b: any): boolean
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	for k, v in a do
		if not TableUtil.deepEqual(v, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end

-- Keep only the last `max` entries of an array (in place).
function TableUtil.trimFront(list: { any }, max: number)
	local extra = #list - max
	if extra > 0 then
		for _ = 1, extra do
			table.remove(list, 1)
		end
	end
end

function TableUtil.clamp(x: number, lo: number, hi: number): number
	return if x < lo then lo elseif x > hi then hi else x
end

function TableUtil.find<T>(list: { T }, pred: (T) -> boolean): T?
	for _, v in list do
		if pred(v) then
			return v
		end
	end
	return nil
end

return TableUtil
