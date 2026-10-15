--!strict
-- Profile schema migrations. PURE: no services, no clocks.
--
-- data.meta.schema records the schema a profile was written with (missing = 0, the unversioned
-- pre-release shape). Migrations.steps[n] upgrades a profile from schema n to n + 1, in place.
-- To change the profile shape: add steps[CURRENT_SCHEMA] and bump CURRENT_SCHEMA. Never edit an existing
-- step after it has shipped, and keep every step idempotent-safe (it only ever runs on schema-n data).
-- Missing fields don't need a migration: DataService deep-fills new template fields after migrating.

local TableUtil = require(script.Parent.Parent.Util.TableUtil)

local Migrations = {}

Migrations.CURRENT_SCHEMA = 1

export type Step = (data: { [string]: any }) -> ()
export type Status = "ok" | "future" | "error"

local function asTable(v: any): { [any]: any }?
	return if type(v) == "table" then v else nil
end

Migrations.steps = {
	-- 0 -> 1: introduce `meta`. Unversioned profiles kept bookkeeping at the top level and could hold the
	-- audit log as a map keyed by timestamp; fold both into the current shape.
	[0] = function(data: { [string]: any })
		local meta = asTable(data.meta) or {}
		data.meta = meta
		for _, field in { "createdAt", "lastSeen", "sessions", "activeSec" } do
			local legacy = data[field]
			if type(legacy) == "number" and meta[field] == nil then
				meta[field] = legacy
			end
			data[field] = nil
		end
		local audit = asTable(data.audit)
		if audit == nil then
			data.audit = nil
		elseif next(audit) ~= nil and not TableUtil.isArray(audit) then
			local list = {}
			for k, v in audit do
				if type(v) == "table" then
					local entry = table.clone(v)
					if type(entry.t) ~= "number" and type(k) == "number" then
						entry.t = k
					end
					table.insert(list, entry)
				end
			end
			table.sort(list, function(a, b)
				return (tonumber(a.t) or 0) < (tonumber(b.t) or 0)
			end)
			data.audit = list
		end
	end,
} :: { [number]: Step }

-- Schema a profile claims to be at (0 when unversioned, or when the field is garbage).
function Migrations.schemaOf(data: any): number
	local meta = if type(data) == "table" then asTable(data.meta) else nil
	local s = if meta then meta.schema else nil
	if type(s) == "number" and s >= 0 and s == math.floor(s) then
		return s
	end
	return 0
end

-- Upgrade `data` to `target` (default CURRENT_SCHEMA).
-- Returns (resultData, fromSchema, status, err?):
--   "ok"     resultData is at `target` (the same table if nothing needed doing)
--   "future" the profile was written by a newer build; resultData is the untouched input
--   "error"  a step failed or is missing; resultData is the untouched input (steps run on a copy)
function Migrations.run(
	data: { [string]: any },
	steps: { [number]: Step }?,
	target: number?
): ({ [string]: any }, number, Status, string?)
	local list = steps or Migrations.steps
	local goal = target or Migrations.CURRENT_SCHEMA
	local from = Migrations.schemaOf(data)
	if from == goal then
		return data, from, "ok" :: Status, nil
	elseif from > goal then
		return data, from, "future" :: Status, nil
	end
	local work = TableUtil.deepCopy(data)
	local schema = from
	while schema < goal do
		local step = list[schema]
		if step == nil then
			return data, from, "error" :: Status, ("no migration from schema %d"):format(schema)
		end
		local ok, err = (pcall :: any)(step, work)
		if not ok then
			return data,
				from,
				"error" :: Status,
				("migration %d->%d failed: %s"):format(schema, schema + 1, tostring(err))
		end
		schema += 1
		local meta: { [any]: any } = asTable(work.meta) or {}
		work.meta = meta
		meta.schema = schema
	end
	return work, from, "ok" :: Status, nil
end

return Migrations
