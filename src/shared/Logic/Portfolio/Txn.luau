--!strict
-- Client transaction ids (owned by `market`; blueprint: "use transaction IDs to avoid duplicate trades"). PURE.
-- A bounded per-player cache of recent results keyed by the client's transaction id: a retried request (a timeout,
-- a double tap, a resend after a lag spike) gets the original answer instead of a second fill.
--
--   Txn.new(max?) -> Cache     Txn.get(cache, id) -> result?     Txn.put(cache, id, result)     Txn.size(cache)

export type Cache = { max: number, order: { string }, map: { [string]: any } }

local Txn = {}

Txn.DEFAULT_MAX = 64

function Txn.new(max: number?): Cache
	return { max = math.max(1, max or Txn.DEFAULT_MAX), order = {}, map = {} }
end

function Txn.get(cache: Cache, id: string): any
	return cache.map[id]
end

function Txn.put(cache: Cache, id: string, result: any)
	if cache.map[id] == nil then
		table.insert(cache.order, id)
	end
	cache.map[id] = result
	while #cache.order > cache.max do
		local old = table.remove(cache.order, 1)
		if old then
			cache.map[old] = nil
		end
	end
end

function Txn.size(cache: Cache): number
	return #cache.order
end

return Txn
