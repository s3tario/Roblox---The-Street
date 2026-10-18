--!strict
-- Economy/Plaques: which lucite deal plaques stand where (PURE: no services, no clocks, no Instances; unit-tested in
-- tests/shop). Design v3 §13: at a desk the newest 3 sit on the desk; with a private office (rank >= 3) up to 24
-- move to the bookshelf.
--
--   Plaques.DESK (3), Plaques.SHELF (24)
--   Plaques.capacityFor(context) -> number          desk 3, office 24, anything else 0
--   Plaques.newest(plaques, n) -> { Plaque }         valid plaques, newest first (by `at`, then by id number)
--   Plaques.layout(plaques, slotIds, n?) -> { { slotId, plaque } }   newest in the first slot; at most
--                                                    min(n, #slotIds) entries
--   Plaques.dateText(unixTime) -> "Oct 18, 2026"     UTC calendar date, computed without os.date
--   Plaques.label(plaque) -> "Deal name\nOct 18, 2026"   the engraving on the lucite block
--   Plaques.count(plaques) -> number                 valid plaques (the profile card count)

local Plaques = {}

Plaques.DESK = 3
Plaques.SHELF = 24
Plaques.MAX_NAME = 48

export type Plaque = { id: string, name: string, at: number, quality: number?, dealId: string? }
export type Placement = { slotId: string, plaque: Plaque }

local MONTHS = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }

local function finite(x: any): boolean
	return type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge
end

function Plaques.capacityFor(context: string?): number
	if context == "desk" then
		return Plaques.DESK
	elseif context == "office" then
		return Plaques.SHELF
	end
	return 0
end

local function idNumber(id: string): number
	local n = string.match(id, "(%d+)$")
	return if n then tonumber(n) or 0 else 0
end

local function valid(p: any): Plaque?
	if type(p) ~= "table" or not finite(p.at) then
		return nil
	end
	local name = if type(p.name) == "string" and p.name ~= "" then p.name else nil
	local id = if type(p.id) == "string" and p.id ~= "" then p.id else nil
	if name == nil and id == nil then
		return nil
	end
	return {
		id = id or ("p" .. tostring(math.floor(p.at))),
		name = name or (id :: string),
		at = p.at,
		quality = if finite(p.quality) then p.quality else nil,
		dealId = if type(p.dealId) == "string" then p.dealId else nil,
	}
end

function Plaques.count(plaques: any): number
	local n = 0
	if type(plaques) == "table" then
		for _, p in plaques do
			if valid(p) then
				n += 1
			end
		end
	end
	return n
end

function Plaques.newest(plaques: any, n: number): { Plaque }
	local list: { { p: Plaque, order: number } } = {}
	if type(plaques) == "table" then
		for i, raw in plaques do
			local p = valid(raw)
			if p then
				table.insert(list, { p = p, order = if type(i) == "number" then i else 0 })
			end
		end
	end
	table.sort(list, function(a, b)
		if a.p.at ~= b.p.at then
			return a.p.at > b.p.at
		end
		local ia, ib = idNumber(a.p.id), idNumber(b.p.id)
		if ia ~= ib then
			return ia > ib
		end
		return a.order > b.order
	end)
	local out: { Plaque } = {}
	local limit = if finite(n) then math.max(0, math.floor(n)) else 0
	for i = 1, math.min(limit, #list) do
		out[i] = list[i].p
	end
	return out
end

function Plaques.layout(plaques: any, slotIds: { string }, n: number?): { Placement }
	local cap = #slotIds
	if finite(n) then
		cap = math.min(cap, math.max(0, math.floor(n :: number)))
	end
	local out: { Placement } = {}
	for i, p in Plaques.newest(plaques, cap) do
		table.insert(out, { slotId = slotIds[i], plaque = p })
	end
	return out
end

-- Howard Hinnant's days-to-civil conversion (proleptic Gregorian, UTC).
local function civil(days: number): (number, number, number)
	local z = days + 719468
	local era = (if z >= 0 then z else z - 146096) // 146097
	local doe = z - era * 146097
	local yoe = (doe - doe // 1460 + doe // 36524 - doe // 146096) // 365
	local y = yoe + era * 400
	local doy = doe - (365 * yoe + yoe // 4 - yoe // 100)
	local mp = (5 * doy + 2) // 153
	local d = doy - (153 * mp + 2) // 5 + 1
	local m = if mp < 10 then mp + 3 else mp - 9
	if m <= 2 then
		y += 1
	end
	return y, m, d
end

function Plaques.dateText(at: number): string
	if not finite(at) then
		return ""
	end
	local y, m, d = civil(math.floor(at / 86400))
	return string.format("%s %d, %d", MONTHS[m], d, y)
end

function Plaques.label(p: Plaque): string
	local name = p.name
	if #name > Plaques.MAX_NAME then
		name = string.sub(name, 1, Plaques.MAX_NAME - 3) .. "..."
	end
	local date = Plaques.dateText(p.at)
	return if date ~= "" then name .. "\n" .. date else name
end

return Plaques
