--!strict
-- Reference solver for standard task secrets (owned by `work`). PURE, SERVER/TEST ONLY: it reads answer keys.
-- Tests use it to prove every module grades a perfect submission >= 95 and degrades monotonically; the rival
-- head-to-head (M3) can use Solve.degrade to simulate an NPC's work at a given accuracy.
--
--   Solve.perfect(secret) -> answers             the best possible answers for a standard secret (any kind)
--   Solve.degrade(secret, k) -> answers          perfect answers with k items made wrong (more k = worse)
--   Solve.items(secret) -> number                how many items degrade() can spoil

local Solve = {}

local function sortedKeys(t: any): { string }
	local out: { string } = {}
	if type(t) == "table" then
		for k in t do
			if type(k) == "string" then
				table.insert(out, k)
			end
		end
	end
	table.sort(out)
	return out
end

local function cell(key: string): { number }
	local r, c = string.match(key, "^(%d+):(%d+)$")
	return { tonumber(r) or 0, tonumber(c) or 0 }
end

local function bestOf(map: any): (any, number)
	local best, bestScore = nil, -math.huge
	if type(map) == "table" then
		local keys: { any } = {}
		for k in map do
			table.insert(keys, k)
		end
		table.sort(keys, function(a, b)
			return tostring(a) < tostring(b)
		end)
		for _, k in keys do
			local v = map[k]
			if type(v) == "number" and v > bestScore then
				best, bestScore = k, v
			end
		end
	end
	return best, bestScore
end

local function worstOf(map: any): any
	local worst, worstScore = nil, math.huge
	if type(map) == "table" then
		local keys: { any } = {}
		for k in map do
			table.insert(keys, k)
		end
		table.sort(keys, function(a, b)
			return tostring(a) < tostring(b)
		end)
		for _, k in keys do
			local v = map[k]
			if type(v) == "number" and v < worstScore then
				worst, worstScore = k, v
			end
		end
	end
	return worst
end

local function count(secret: any): number
	if type(secret) ~= "table" then
		return 0
	end
	local kind = secret.kind
	if kind == "mcq" or kind == "match" then
		return #sortedKeys(secret.key)
	elseif kind == "fill" then
		return #sortedKeys(secret.fields)
	elseif kind == "dialogue" then
		return #sortedKeys(secret.scores)
	elseif kind == "call" then
		return #sortedKeys(secret.credit)
	elseif kind == "alloc" then
		return #sortedKeys(secret.target)
	elseif kind == "order" then
		return math.max(0, (if type(secret.order) == "table" then #secret.order else 0) - 1)
	elseif kind == "spot" then
		return if type(secret.groups) == "table" then #secret.groups else 0
	elseif kind == "format" then
		local n = 0
		for _, id in sortedKeys(secret.issues) do
			n += #secret.issues[id]
		end
		return n
	elseif kind == "multi" then
		local n = 0
		for _, s in secret.sections or {} do
			n += count(s)
		end
		return n
	end
	return 0
end
Solve.items = count

local function solve(secret: any, k: number): any
	if type(secret) ~= "table" then
		return {}
	end
	local kind = secret.kind
	if kind == "mcq" then
		local out: { [string]: number } = {}
		for i, qid in sortedKeys(secret.key) do
			local right = secret.key[qid]
			out[qid] = if i <= k then (if right == 1 then 2 else 1) else right
		end
		return out
	elseif kind == "fill" then
		local out: { [string]: number } = {}
		local order = if type(secret.fieldOrder) == "table" and #secret.fieldOrder > 0
			then secret.fieldOrder
			else sortedKeys(secret.fields)
		for i, id in order do
			local f = secret.fields[id]
			local v = if type(f) == "table" and type(f.value) == "number" then f.value else 0
			out[id] = if i <= k then v * 3 + 1000 else v
		end
		return out
	elseif kind == "order" then
		local list: { string } = table.clone(secret.order or {})
		if k > 0 and #list > 1 then
			local first = table.remove(list, 1) :: string
			table.insert(list, math.min(k + 1, #list + 1), first)
		end
		return list
	elseif kind == "match" then
		local out: { [string]: string } = {}
		local ids = sortedKeys(secret.key)
		for i, id in ids do
			if i <= k then
				-- someone else's partner (or a nonsense id when there is only one pair)
				local other = ids[(i % #ids) + 1]
				local wrong = secret.key[other]
				out[id] = if wrong ~= secret.key[id] then wrong else "none"
			else
				out[id] = secret.key[id]
			end
		end
		return out
	elseif kind == "spot" then
		local out: { { number } } = {}
		for i, g in secret.groups or {} do
			if i > k and type(g.cells) == "table" and g.cells[1] then
				table.insert(out, cell(g.cells[1]))
			end
		end
		return out
	elseif kind == "alloc" then
		local out: { [string]: number } = {}
		for i, id in sortedKeys(secret.target) do
			local band = secret.target[id]
			local lo, hi = band[1] or 0, band[2] or band[1] or 0
			local mid = (lo + hi) / 2
			if i <= k then
				-- move this item well outside its band
				mid = if lo >= (secret.total or 0) * 0.25 then 0 else hi + (secret.total or 0) * 0.3
			end
			out[id] = mid
		end
		return out
	elseif kind == "dialogue" then
		local out: { [string]: string } = {}
		for i, lineId in sortedKeys(secret.scores) do
			local best = if type(secret.best) == "table" and secret.best[lineId]
				then secret.best[lineId]
				else bestOf(secret.scores[lineId])
			out[lineId] = if i <= k then worstOf(secret.scores[lineId]) else best
		end
		return out
	elseif kind == "call" then
		local out: { [string]: number } = {}
		for i, id in sortedKeys(secret.credit) do
			local best = bestOf(secret.credit[id])
			out[id] = if i <= k then worstOf(secret.credit[id]) else best
		end
		return out
	elseif kind == "format" then
		local out: { [string]: { string } } = {}
		local dropped = 0
		for _, id in sortedKeys(secret.issues) do
			local keep: { string } = {}
			for _, issueId in secret.issues[id] do
				if dropped < k then
					dropped += 1
				else
					table.insert(keep, issueId)
				end
			end
			out[id] = keep
		end
		return out
	elseif kind == "multi" then
		local out: { any } = {}
		local n = if type(secret.sections) == "table" then #secret.sections else 0
		local remaining = k
		local per: { number } = {}
		for i = 1, n do
			per[i] = 0
		end
		-- spread the damage round-robin over sections that still have items to spoil
		local guard = 0
		while remaining > 0 and guard < 1000 do
			guard += 1
			local progressed = false
			for i = 1, n do
				if remaining > 0 and per[i] < count(secret.sections[i]) then
					per[i] += 1
					remaining -= 1
					progressed = true
				end
			end
			if not progressed then
				break
			end
		end
		for i = 1, n do
			out[i] = solve(secret.sections[i], per[i])
		end
		return out
	end
	return {}
end

function Solve.perfect(secret: any): any
	return solve(secret, 0)
end

function Solve.degrade(secret: any, k: number): any
	return solve(secret, math.max(0, math.floor(k)))
end

return Solve
