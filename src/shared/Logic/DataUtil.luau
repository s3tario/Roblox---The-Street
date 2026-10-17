--!strict
-- Pure helpers for player data: dotted paths, private-key filtering, template application, DataStore
-- safety (sanitising copies, JSON size estimates), ring buffers and backup rotation.
-- PURE: no services, no clocks, no Instances. Callers pass `now`.

local TableUtil = require(script.Parent.Parent.Util.TableUtil)
local Migrations = require(script.Parent.Migrations)

local DataUtil = {}

export type Issue = { path: string, reason: string }

---------------------------------------------------------------------------------------------------
-- Dotted paths: "campus.offer", "career.reviews.3"
---------------------------------------------------------------------------------------------------
local function segments(path: string): { string }
	local out = {}
	for seg in string.gmatch(path, "[^%.]+") do
		table.insert(out, seg)
	end
	return out
end

-- Resolve one segment against a table: the string key first, then the numeric key ("3" -> 3).
local function keyFor(node: { [any]: any }, seg: string): any
	if node[seg] ~= nil then
		return seg
	end
	local n = tonumber(seg)
	if n ~= nil and node[n] ~= nil then
		return n
	end
	return nil
end

function DataUtil.getPath(data: any, path: string): any
	local node = data
	for _, seg in segments(path) do
		if type(node) ~= "table" then
			return nil
		end
		local k = keyFor(node, seg)
		if k == nil then
			return nil
		end
		node = node[k]
	end
	return node
end

-- Key to create for a segment that doesn't exist yet. Writing inside an array (or starting one) keeps
-- numeric keys so the array stays an array; everything else uses the string.
local function newKey(node: { [any]: any }, seg: string): any
	local n = tonumber(seg)
	if n ~= nil and n == math.floor(n) and n >= 1 and (TableUtil.isArray(node) or (next(node) == nil and n == 1)) then
		return n
	end
	return seg
end

-- Set a value at a dotted path, creating missing intermediate tables. Returns (ok, topLevelKey) so the
-- caller knows which key to replicate. Fails (false) on an empty path or a non-table intermediate.
function DataUtil.setPath(data: { [any]: any }, path: string, value: any): (boolean, string?)
	local segs = segments(path)
	if #segs == 0 or type(data) ~= "table" then
		return false, nil
	end
	local node: { [any]: any } = data
	for i = 1, #segs - 1 do
		local seg = segs[i]
		local k = keyFor(node, seg)
		local child = if k ~= nil then node[k] else nil
		if child == nil then
			child = {}
			node[newKey(node, seg)] = child
		elseif type(child) ~= "table" then
			return false, nil
		end
		node = child
	end
	local last = segs[#segs]
	local k = keyFor(node, last)
	if k == nil then
		k = newKey(node, last)
	end
	node[k] = value
	return true, segs[1]
end

---------------------------------------------------------------------------------------------------
-- Replication
---------------------------------------------------------------------------------------------------
-- Shallow copy of `data` without the private top-level keys. Values are shared, not copied.
function DataUtil.filterPrivate(data: { [string]: any }, privateSet: { [string]: boolean }): { [string]: any }
	local out = {}
	for k, v in data do
		if not privateSet[k] then
			out[k] = v
		end
	end
	return out
end

---------------------------------------------------------------------------------------------------
-- Templates
---------------------------------------------------------------------------------------------------
local function fill(target: { [any]: any }, template: { [any]: any }, prefix: string, repaired: { string })
	for k, v in template do
		local cur = target[k]
		if cur == nil then
			target[k] = TableUtil.deepCopy(v)
		elseif type(v) == "table" then
			if type(cur) ~= "table" then
				-- The template says this is a table but the save holds a scalar: code indexing into it would
				-- crash, so reset it to the default and report it.
				target[k] = TableUtil.deepCopy(v)
				table.insert(repaired, prefix .. tostring(k))
			elseif not TableUtil.isArray(v) then
				fill(cur, v, prefix .. tostring(k) .. ".", repaired)
			end
		end
	end
end

-- Deep-fill missing fields from the template (never overwriting existing values, never descending into
-- template arrays), and reset fields whose saved value is not a table where the template has a table.
-- Returns the data and the list of repaired paths.
function DataUtil.applyTemplate(data: { [string]: any }, template: { [string]: any }): ({ [string]: any }, { string })
	local repaired = {}
	fill(data, template, "", repaired)
	return data, repaired
end

-- A brand-new profile: a deep copy of the template with meta stamped.
function DataUtil.newProfile(template: { [string]: any }, now: number, schema: number): { [string]: any }
	local data = TableUtil.deepCopy(template)
	local meta = data.meta
	if type(meta) ~= "table" then
		meta = {}
		data.meta = meta
	end
	meta.schema = schema
	meta.createdAt = math.floor(now)
	return data
end

---------------------------------------------------------------------------------------------------
-- DataStore safety
---------------------------------------------------------------------------------------------------
local function join(path: string, key: any): string
	return if path == "" then tostring(key) else path .. "." .. tostring(key)
end

local function finite(x: number): boolean
	return x == x and x ~= math.huge and x ~= -math.huge
end

-- A table whose keys are exactly 1..n.
local function isSequence(t: { [any]: any }): (boolean, number)
	local count = 0
	for k in t do
		if type(k) ~= "number" then
			return false, 0
		end
		count += 1
	end
	for k in t do
		if k < 1 or k > count or k ~= math.floor(k) then
			return false, 0
		end
	end
	return true, count
end

-- Deep copy that a DataStore (and JSONEncode) will accept, plus a list of everything that had to change:
-- non-finite numbers, invalid UTF-8, functions/Instances/userdata and cycles are dropped; tables mixing
-- numeric and string keys (or sparse arrays) have their numeric keys turned into strings. Holes left in
-- arrays by dropped elements are closed. `skipTopKeys` are left out of the copy entirely.
function DataUtil.toSaveable(value: any, skipTopKeys: { [string]: boolean }?): (any, { Issue })
	local issues: { Issue } = {}
	local stack: { [any]: boolean } = {}
	local function issue(path: string, reason: string)
		table.insert(issues, { path = if path == "" then "<root>" else path, reason = reason })
	end
	local function visit(v: any, path: string, top: boolean): any
		local t = type(v)
		if t == "number" then
			if not finite(v) then
				issue(path, "non-finite number")
				return nil
			end
			return v
		elseif t == "string" then
			if utf8.len(v) == nil then
				issue(path, "invalid UTF-8 string")
				return nil
			end
			return v
		elseif t == "boolean" then
			return v
		elseif t == "nil" then
			return nil
		elseif t ~= "table" then
			issue(path, "unsupported value type " .. typeof(v))
			return nil
		end
		if stack[v] then
			issue(path, "reference cycle")
			return nil
		end
		stack[v] = true
		local out: { [any]: any } = {}
		local seq, n = isSequence(v)
		if seq then
			for i = 1, n do
				local x = visit(v[i], join(path, i), false)
				if x ~= nil then
					table.insert(out, x)
				end
			end
		else
			local mixedReported = false
			for k, x in v do
				local kt = type(k)
				local key: string? = nil
				if kt == "string" then
					if utf8.len(k) == nil then
						issue(path, "invalid UTF-8 key")
					elseif not (top and skipTopKeys and skipTopKeys[k]) then
						key = k
					end
				elseif kt == "number" and finite(k) then
					if not mixedReported then
						issue(path, "numeric keys in a dictionary or sparse array (saved as strings)")
						mixedReported = true
					end
					key = tostring(k)
				else
					issue(path, "unsupported key type " .. typeof(k))
				end
				if key ~= nil then
					local sx = visit(x, join(path, key), false)
					if sx ~= nil then
						out[key] = sx
					end
				end
			end
		end
		stack[v] = nil
		return out
	end
	return visit(value, "", true), issues
end

-- Byte length of the JSON encoding of `value` (pure estimator; mirrors HttpService:JSONEncode closely
-- enough for size budgeting and tests). Tables with keys exactly 1..n encode as arrays.
function DataUtil.estimateSize(value: any): number
	local t = type(value)
	if t == "nil" then
		return 4
	elseif t == "boolean" then
		return if value then 4 else 5
	elseif t == "number" then
		if value == math.floor(value) and math.abs(value) < 2 ^ 53 then
			return #string.format("%d", value)
		end
		return #tostring(value)
	elseif t == "string" then
		local n = 2
		for i = 1, #value do
			local b = string.byte(value, i)
			if b == 34 or b == 92 or b == 8 or b == 9 or b == 10 or b == 12 or b == 13 then
				n += 2
			elseif b < 32 then
				n += 6
			else
				n += 1
			end
		end
		return n
	elseif t == "table" then
		local seq, count = isSequence(value)
		if count == 0 and next(value) == nil then
			return 2
		end
		local n = 2
		local first = true
		if seq then
			for i = 1, count do
				n += DataUtil.estimateSize(value[i]) + (if first then 0 else 1)
				first = false
			end
		else
			for k, v in value do
				n += DataUtil.estimateSize(tostring(k)) + 1 + DataUtil.estimateSize(v) + (if first then 0 else 1)
				first = false
			end
		end
		return n
	end
	return #tostring(value) + 2
end

---------------------------------------------------------------------------------------------------
-- Audit helpers
---------------------------------------------------------------------------------------------------
-- Append `entry` and keep only the newest `max` entries (oldest are dropped from the front).
function DataUtil.pushRing(list: { any }, entry: any, max: number): { any }
	table.insert(list, entry)
	TableUtil.trimFront(list, max)
	return list
end

-- At most maxLen bytes of `s`, cut on a UTF-8 character boundary.
local function utf8Cut(s: string, maxLen: number): string
	if #s <= maxLen then
		return s
	end
	local cut = string.sub(s, 1, maxLen)
	while #cut > 0 and utf8.len(cut) == nil do
		cut = string.sub(cut, 1, #cut - 1)
	end
	return cut
end

local function truncate(s: string, maxLen: number): string
	if #s <= maxLen then
		return s
	end
	return utf8Cut(s, maxLen) .. "..."
end

-- Small, saveable copy of arbitrary details for audit entries: depth, key count and string length are
-- bounded; anything that can't be saved (Instances, functions, NaN) becomes a short string.
function DataUtil.compact(value: any, maxDepth: number?, maxKeys: number?, maxStr: number?): any
	local depthLimit = maxDepth or 3
	local keyLimit = maxKeys or 16
	local strLimit = maxStr or 200
	local function visit(v: any, depth: number): any
		local t = type(v)
		if t == "nil" or t == "boolean" then
			return v
		elseif t == "number" then
			return if finite(v) then v else tostring(v)
		elseif t == "string" then
			if utf8.len(v) == nil then
				return "<binary>"
			end
			return truncate(v, strLimit)
		elseif t == "table" then
			if depth >= depthLimit then
				return "{...}"
			end
			local seq, n = isSequence(v)
			local out: { [any]: any } = {}
			if seq then
				for i = 1, math.min(n, keyLimit) do
					table.insert(out, visit(v[i], depth + 1))
				end
				if n > keyLimit then
					table.insert(out, ("...%d more"):format(n - keyLimit))
				end
			else
				local count = 0
				for k, x in v do
					count += 1
					if count > keyLimit then
						out["_more"] = true
						break
					end
					local key = if type(k) == "string" and utf8.len(k) ~= nil then truncate(k, 64) else tostring(k)
					out[key] = visit(x, depth + 1)
				end
			end
			return out
		end
		return truncate(tostring(v), strLimit)
	end
	return visit(value, 0)
end

DataUtil.AUDIT_KIND_MAX = 32 -- bytes
DataUtil.AUDIT_ENTRY_BYTES = 2048 -- JSON budget for one entry's details

export type AuditEntry = { t: number, kind: string, d: any }

-- One audit ring entry { t, kind, d }. `details` is compacted, and if its JSON would still exceed `maxBytes`
-- it is compacted harder, then replaced by a stub, so a caller passing a huge table can never bloat the
-- profile (100 entries) or the Audit_v1 log (200 entries) toward the DataStore size limit.
-- Returns nil when `kind` is not a non-empty string.
function DataUtil.auditEntry(now: number, kind: any, details: any, maxBytes: number?): AuditEntry?
	if type(kind) ~= "string" or kind == "" then
		return nil
	end
	local k = if utf8.len(kind) == nil then "invalid_kind" else utf8Cut(kind, DataUtil.AUDIT_KIND_MAX)
	local limit = maxBytes or DataUtil.AUDIT_ENTRY_BYTES
	local d = DataUtil.compact(details)
	local size = DataUtil.estimateSize(d)
	if size > limit then
		d = DataUtil.compact(details, 2, 8, 64)
		local smaller = DataUtil.estimateSize(d)
		if smaller > limit then
			d = { truncated = true, bytes = size }
		end
	end
	return { t = math.floor(now), kind = k, d = d }
end

---------------------------------------------------------------------------------------------------
-- Timing and backups
---------------------------------------------------------------------------------------------------
-- Exponential backoff: base, 2*base, 4*base ... capped.
function DataUtil.backoff(attempt: number, base: number?, cap: number?): number
	local b = base or 1
	return math.min(cap or 30, b * 2 ^ math.max(0, attempt - 1))
end

-- UTC day number (unix seconds -> whole days since the epoch).
function DataUtil.utcDay(now: number): number
	return math.floor(now / 86400)
end

-- The backup slot due for this profile today, or nil if one was already written today.
-- meta.backupDay / meta.backupSlot record the last backup; slots rotate 1..slots.
function DataUtil.backupSlotDue(meta: any, today: number, slots: number): number?
	local m = if type(meta) == "table" then meta else {}
	if m.backupDay == today then
		return nil
	end
	local last = m.backupSlot
	if type(last) ~= "number" or last ~= math.floor(last) or last < 0 or last > slots then
		last = 0
	end
	return (last :: number) % slots + 1
end

---------------------------------------------------------------------------------------------------
-- Loading and backups
---------------------------------------------------------------------------------------------------
export type Prepared = {
	status: "ok" | "future" | "error",
	data: { [string]: any }?, -- the in-memory profile (status "ok" only)
	isNew: boolean,
	fromSchema: number,
	repaired: { string }, -- fields reset to their template default because their type was wrong
	backupSlot: number?, -- today's rolling backup is due into this slot ...
	backupSnapshot: { [string]: any }?, -- ... with this copy of the save exactly as it was loaded
	err: string?,
}

export type PrepareOpts = {
	transient: { [string]: boolean }?, -- keys never kept from the save; reset to an empty table
	backupSlots: number?, -- rolling backup slots (default 3)
	steps: { [number]: Migrations.Step }?, -- migration steps (default Migrations.steps)
	schema: number?, -- target schema (default Migrations.CURRENT_SCHEMA)
}

-- Turn the `data` field of a freshly locked record into the in-memory profile:
--   nil -> a new profile from the template; otherwise migrate -> drop transient keys -> deep-fill the
--   template -> stamp meta (schema, sessions + 1, lastSeen, createdAt when unknown).
-- Never mutates `raw` when it returns "future" or "error".
function DataUtil.prepareLoaded(raw: any, template: { [string]: any }, now: number, opts: PrepareOpts?): Prepared
	local o: PrepareOpts = opts or {}
	local schema = o.schema or Migrations.CURRENT_SCHEMA
	local result: Prepared = {
		status = "ok",
		data = nil,
		isNew = false,
		fromSchema = schema,
		repaired = {},
		backupSlot = nil,
		backupSnapshot = nil,
		err = nil,
	}
	local data: { [string]: any }
	if type(raw) ~= "table" then
		data = DataUtil.newProfile(template, now, schema)
		result.isNew = true
	else
		local migrated, from, status: Migrations.Status, err = Migrations.run(raw, o.steps, schema)
		result.fromSchema = from
		if status ~= "ok" then
			result.status = status
			result.err = err
			return result
		end
		local slot = DataUtil.backupSlotDue(raw.meta, DataUtil.utcDay(now), o.backupSlots or 3)
		if slot ~= nil then
			result.backupSlot = slot
			-- migrated is a copy whenever a step ran; otherwise it is `raw` itself, which is about to be filled.
			result.backupSnapshot = TableUtil.deepCopy(raw)
		end
		data = migrated
	end
	if o.transient then
		for k in o.transient do
			data[k] = nil
		end
	end
	local _, repaired = DataUtil.applyTemplate(data, template)
	result.repaired = repaired
	if o.transient then
		for k in o.transient do
			if type(data[k]) ~= "table" then
				data[k] = {}
			end
		end
	end
	local meta = data.meta
	if type(meta) ~= "table" then
		meta = {}
		data.meta = meta
	end
	meta.schema = schema
	meta.sessions = (tonumber(meta.sessions) or 0) + 1
	meta.lastSeen = math.floor(now)
	if (tonumber(meta.createdAt) or 0) <= 0 then
		meta.createdAt = math.floor(now)
	end
	result.data = data
	return result
end

-- Value stored in PlayerBackup_v1 for one slot.
function DataUtil.backupRecord(
	data: { [string]: any },
	now: number,
	slot: number | string,
	reason: string?
): { [string]: any }
	return {
		data = data,
		savedAt = math.floor(now),
		day = DataUtil.utcDay(now),
		slot = slot,
		schema = Migrations.schemaOf(data),
		reason = reason or "daily",
	}
end

-- Support-facing summary of a stored backup value (nil when the slot is empty or unreadable).
function DataUtil.backupSummary(slot: number | string, value: any): { [string]: any }?
	if type(value) ~= "table" or type(value.data) ~= "table" then
		return nil
	end
	local d = value.data
	local function sub(key: string): { [string]: any }
		local v = d[key]
		return if type(v) == "table" then v else {}
	end
	return {
		slot = slot,
		savedAt = value.savedAt,
		schema = Migrations.schemaOf(d),
		reason = value.reason,
		sessions = sub("meta").sessions,
		level = sub("career").level,
		roleId = sub("career").roleId,
		cash = sub("wallet").cash,
		bytes = DataUtil.estimateSize(d),
	}
end

return DataUtil
