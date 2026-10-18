--!strict
-- Economy/Assign: who gets which dorm room, apartment, desk and private office on this server (PURE: no services,
-- no clocks, no Instances; unit-tested in tests/shop). HousingService keeps one Pool per unit kind and two per live
-- company floor (desks and offices) and mirrors every claim onto the matching marker model.
--
--   Assign.OFFICE_RANK                         rank that earns a private office (v3 §13: rank >= 3)
--   Assign.contextsFor(state) -> Wants         { unit = "dorm" | "apartment" | nil, work = "desk" | "office" | nil }
--       state = { student: boolean, employed: boolean, rank: number, companyId: string?, track: string?,
--                 office: boolean? (the role's Config/Tracks flag; nil = rank >= OFFICE_RANK) }
--   Assign.floorKey(companyId, track) -> string
--   Assign.newPool(capacity) -> Pool           slots 1..capacity
--   Assign.claim(pool, owner, preferred?) -> index?   idempotent (an owner keeps its index); prefers `preferred`,
--                                              then the lowest free index; nil when the pool is full
--   Assign.release(pool, owner) -> index?      Assign.indexOf(pool, owner) -> index?   Assign.ownerOf(pool, i) -> owner?
--   Assign.freeCount(pool) -> number           Assign.resize(pool, capacity) -> { owner }  (owners that lost a slot)
--   Assign.work(desks, offices, owner, wantOffice, prefs?) -> (kind?, index?, note?)   prefs = { desk?, office? }
--       wantOffice and a free office -> "office"; otherwise a desk ("office_full" note when the office was wanted);
--       nil kind with note "desk_full" when the floor is full. Claiming one releases the other.

local Assign = {}

Assign.OFFICE_RANK = 3

export type Pool = { capacity: number, owners: { [number]: any }, byOwner: { [any]: number } }
export type State = {
	student: boolean?,
	employed: boolean?,
	rank: number?,
	companyId: string?,
	track: string?,
	office: boolean?, -- the role's own flag (Config/Tracks RoleDef.office); nil = rank >= OFFICE_RANK
}
export type Wants = { unit: string?, work: string?, companyId: string?, track: string? }
export type Prefs = { desk: number?, office: number? }

local function finite(x: any): boolean
	return type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge
end

function Assign.contextsFor(state: State): Wants
	local rank = if finite(state.rank) then math.floor(state.rank :: number) else 0
	if state.employed then
		local hasFloor = type(state.companyId) == "string"
			and state.companyId ~= ""
			and type(state.track) == "string"
			and state.track ~= ""
		local office = if state.office ~= nil then state.office == true else rank >= Assign.OFFICE_RANK
		return {
			unit = "apartment",
			work = if not hasFloor then nil elseif office then "office" else "desk",
			companyId = if hasFloor then state.companyId else nil,
			track = if hasFloor then state.track else nil,
		}
	end
	if state.student then
		return { unit = "dorm" }
	end
	-- between jobs (fired): no room is held for them; their decor stays saved
	return {}
end

function Assign.floorKey(companyId: string, track: string): string
	return companyId .. "|" .. track
end

function Assign.newPool(capacity: number): Pool
	return {
		capacity = math.max(0, math.floor(if finite(capacity) then capacity else 0)),
		owners = {},
		byOwner = {},
	}
end

function Assign.indexOf(pool: Pool, owner: any): number?
	return pool.byOwner[owner]
end

function Assign.ownerOf(pool: Pool, index: number): any
	return pool.owners[index]
end

function Assign.freeCount(pool: Pool): number
	local used = 0
	for i in pool.owners do
		if i >= 1 and i <= pool.capacity then
			used += 1
		end
	end
	return math.max(0, pool.capacity - used)
end

function Assign.claim(pool: Pool, owner: any, preferred: number?): number?
	if owner == nil then
		return nil
	end
	local have = pool.byOwner[owner]
	if have then
		return have
	end
	local pick: number? = nil
	if finite(preferred) then
		local p = math.floor(preferred :: number)
		if p >= 1 and p <= pool.capacity and pool.owners[p] == nil then
			pick = p
		end
	end
	if pick == nil then
		for i = 1, pool.capacity do
			if pool.owners[i] == nil then
				pick = i
				break
			end
		end
	end
	if pick == nil then
		return nil
	end
	pool.owners[pick] = owner
	pool.byOwner[owner] = pick
	return pick
end

function Assign.release(pool: Pool, owner: any): number?
	local index = pool.byOwner[owner]
	if index == nil then
		return nil
	end
	pool.byOwner[owner] = nil
	if pool.owners[index] == owner then
		pool.owners[index] = nil
	end
	return index
end

-- A floor rebuilt with a different number of slots: owners above the new capacity lose their index.
function Assign.resize(pool: Pool, capacity: number): { any }
	pool.capacity = math.max(0, math.floor(if finite(capacity) then capacity else 0))
	local evicted: { any } = {}
	for index, owner in pool.owners do
		if index > pool.capacity then
			table.insert(evicted, owner)
		end
	end
	for _, owner in evicted do
		Assign.release(pool, owner)
	end
	return evicted
end

function Assign.work(
	desks: Pool,
	offices: Pool?,
	owner: any,
	wantOffice: boolean,
	prefs: Prefs?
): (string?, number?, string?)
	local p: Prefs = prefs or {}
	if wantOffice and offices then
		local office = Assign.claim(offices, owner, p.office)
		if office then
			Assign.release(desks, owner)
			return "office", office, nil
		end
	end
	if offices then
		Assign.release(offices, owner)
	end
	local desk = Assign.claim(desks, owner, p.desk)
	if desk then
		return "desk", desk, if wantOffice then "office_full" else nil
	end
	return nil, nil, "desk_full"
end

return Assign
