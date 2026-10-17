--!strict
-- DoorRules (offices, PURE): who may use a door, where an office exit leads, who counts as an employee of an
-- office instance (merger pairs included), which stage spawn a player belongs to and the world-safety rules.
-- No services, no clocks, no Instances: callers pass state and `now`.
--
--   DoorRules.check(requires?, state) -> (ok, reason?)        reason "rank" | "employed" | "flag" | "pass"
--       requires = Config/World door `requires` ({minRank, employed, flag, orMinRank, pass}); state = ReqState
--   DoorRules.stateFromData(data) -> ReqState                  from player data alone (the client's view)
--   DoorRules.lockedText(doorDef?, reason?) -> string          the door's lockedText or a generic line
--   DoorRules.kind(doorDef) -> "target" | "ride" | "company" | "picker" | nil
--   DoorRules.promptText(doorDef) -> (actionText, objectText)   the door's ProximityPrompt texts
--   DoorRules.officeDoorText(kind) -> (actionText, objectText)  office template doors ("exit" | "to_lobby")
--   DoorRules.getPath(data, "campus.offer") -> any
--   DoorRules.streetAccess(state) -> (ok, text?)               the campus -> Street gate (the subway's rules)
--   DoorRules.towerFor(companyId, towers?) -> TowerDef?        its own tower, else the tower that lists it as a tenant
--   DoorRules.resolveExit(memory?, companyId, towers?) -> anchorId
--       memory = {companyId, anchor?}: the exterior anchor remembered when the player entered
--   DoorRules.isEmployedCareer(career?) -> boolean
--   DoorRules.partnersOf(companyId, events?, now?) -> { [companyId] = true }   active merger_mania pairs
--   DoorRules.isEmployee(career?, companyId, events?, now?) -> boolean
--   DoorRules.promptAllowed(career?, employeesOnly, companyId?, events?, now?) -> boolean   client prompt hiding
--   DoorRules.visitorBadge(career?, officeCompanyId?, companyName?, events?, now?) -> string?   "Visitor · X"
--   DoorRules.stageFor({employed, rank, status}) -> "campus" | "street"
--   DoorRules.isCampusSide(zoneId?) -> boolean
--   DoorRules.zoneLabel(zoneId?) -> string
--   DoorRules.anchorZone(anchorId) -> zoneId?
--   DoorRules.safety(y, zoneId?, outSince?, now) -> (action?, outSince?)   action "fall" | "out_of_zone"
--   DoorRules.impossibleMove(from, to, dt, opts?) -> boolean   horizontal speed beyond anything walking allows
--   DoorRules.Text                                            player-facing strings (DoorRules/Text)

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local World = require(Shared.Config.World)
local Text = require(script.Text)

local DoorRules = {}

DoorRules.Text = Text

DoorRules.STREET_ACCESS_DOOR = "door_campus_subway"
DoorRules.FALL_Y = -50
DoorRules.OUT_OF_ZONE_SEC = 3
DoorRules.MAX_SPEED = 150 -- studs/s horizontally (walk speed is 18; physics flings rarely exceed this)
DoorRules.MIN_JUMP = 80 -- studs: shorter jumps are never reported (lag spikes)
DoorRules.FALLBACK_EXIT = "street_plaza"

export type ReqState = {
	rank: number?,
	employed: boolean?,
	data: { [any]: any }?, -- player data (or any table whose fields can be walked with a dot path)
	passes: { [string]: boolean }?,
}

export type Memory = { companyId: string, anchor: string? }

---------------------------------------------------------------------------------------------------
-- Requirements
---------------------------------------------------------------------------------------------------
function DoorRules.getPath(data: any, path: string): any
	if type(path) ~= "string" or path == "" then
		return nil
	end
	local node = data
	for seg in string.gmatch(path, "[^%.]+") do
		if type(node) ~= "table" then
			return nil
		end
		node = node[seg]
	end
	return node
end

local function truthy(v: any): boolean
	return v ~= nil and v ~= false
end

function DoorRules.check(requires: any, state: ReqState?): (boolean, string?)
	if type(requires) ~= "table" then
		return true, nil
	end
	local s: ReqState = state or {}
	local rank = if type(s.rank) == "number" and s.rank == s.rank then s.rank else 0
	if type(requires.minRank) == "number" and rank < requires.minRank then
		return false, "rank"
	end
	if requires.employed == true and s.employed ~= true then
		return false, "employed"
	end
	if type(requires.flag) == "string" then
		local ok = truthy(DoorRules.getPath(s.data, requires.flag))
		if not ok and type(requires.orMinRank) == "number" and rank >= requires.orMinRank then
			ok = true
		end
		if not ok then
			return false, "flag"
		end
	elseif type(requires.orMinRank) == "number" and rank < requires.orMinRank then
		-- orMinRank without a flag behaves like minRank
		return false, "rank"
	end
	if type(requires.pass) == "string" then
		local passes = s.passes
		if not (type(passes) == "table" and passes[requires.pass] == true) then
			return false, "pass"
		end
	end
	return true, nil
end

-- A ReqState from player data alone ({career, entitlements, campus, ...}; the client's replicated copy or the
-- server's saved data). Passes may be stored as a map {[key] = true} or a list {key}.
function DoorRules.stateFromData(data: any): ReqState
	local d = if type(data) == "table" then data else {}
	local career = d.career
	local rank = if type(career) == "table" and type(career.rank) == "number" then career.rank else 0
	local passes: { [string]: boolean } = {}
	local ent = d.entitlements
	local saved = if type(ent) == "table" then ent.passes else nil
	if type(saved) == "table" then
		for k, v in saved do
			if type(k) == "string" and v == true then
				passes[k] = true
			elseif type(k) == "number" and type(v) == "string" then
				passes[v] = true
			end
		end
	end
	return { rank = rank, employed = DoorRules.isEmployedCareer(career), data = d, passes = passes }
end

local REASON_TEXT = {
	rank = "locked_rank",
	employed = "locked_employed",
	flag = "locked_flag",
	pass = "locked_pass",
}

function DoorRules.lockedText(doorDef: any, reason: string?): string
	if type(doorDef) == "table" and type(doorDef.lockedText) == "string" and doorDef.lockedText ~= "" then
		return doorDef.lockedText
	end
	local key = if reason then REASON_TEXT[reason] else nil
	return Text.get(key or "door_locked_default")
end

function DoorRules.kind(doorDef: any): string?
	if type(doorDef) ~= "table" then
		return nil
	end
	if type(doorDef.ride) == "table" then
		return "ride"
	elseif type(doorDef.company) == "string" then
		return "company"
	elseif type(doorDef.picker) == "table" then
		return "picker"
	elseif type(doorDef.target) == "string" then
		return "target"
	end
	return nil
end

local function zoneKind(zoneId: string?): string?
	if type(zoneId) ~= "string" then
		return nil
	end
	local z = World.zones[zoneId]
	return if z then z.kind else nil
end

-- The ProximityPrompt texts for a World door: (ActionText, ObjectText).
--   target  "Enter" + the door's label, or "Exit" + the destination's name when it leads out of an interior
--   ride    "Board" + the line ("Subway: Downtown")
--   company / picker   "Enter" + the tower's name
function DoorRules.promptText(doorDef: any): (string, string)
	if type(doorDef) ~= "table" then
		return Text.get("door_enter"), ""
	end
	local label = if type(doorDef.label) == "string" then doorDef.label else ""
	local kind = DoorRules.kind(doorDef)
	if kind == "ride" then
		return Text.get("door_board"), label
	end
	if kind == "target" then
		local targetZone = DoorRules.anchorZone(doorDef.target)
		local leavesInterior = zoneKind(doorDef.zone) == "interior" and zoneKind(targetZone) == "region"
		if label == Text.get("door_exit") or leavesInterior then
			return Text.get("door_exit"), DoorRules.zoneLabel(targetZone)
		end
	end
	return Text.get("door_enter"), label
end

DoorRules.OFFICE_DOORS = { exit = true, to_lobby = true } :: { [string]: boolean }

-- The prompt texts for an office template door (OfficeDoor "exit" | "to_lobby").
function DoorRules.officeDoorText(kind: string?): (string, string)
	if kind == "to_lobby" then
		return Text.get("office_elevator"), Text.get("office_to_lobby")
	end
	return Text.get("door_exit"), Text.get("office_exit")
end

-- The campus -> Street gate: everything that moves a player from campus to the Street (the subway, the
-- Directory) applies the subway door's requirements.
function DoorRules.streetAccess(state: ReqState?): (boolean, string?)
	local door = (World.doors :: { [string]: any })[DoorRules.STREET_ACCESS_DOOR]
	if not door then
		return true, nil
	end
	local ok, reason = DoorRules.check(door.requires, state)
	if ok then
		return true, nil
	end
	return false, DoorRules.lockedText(door, reason)
end

---------------------------------------------------------------------------------------------------
-- Towers and exits
---------------------------------------------------------------------------------------------------
function DoorRules.towerFor(companyId: string, towers: { World.TowerDef }?): World.TowerDef?
	local list = towers or World.towers
	for _, t in list do
		if t.company == companyId then
			return t
		end
	end
	for _, t in list do
		if t.picker and table.find(t.picker, companyId) then
			return t
		end
	end
	return nil
end

local function towerAnchor(t: World.TowerDef): string
	return t.anchor or ("street_tower_" .. t.id .. "_front")
end

function DoorRules.resolveExit(memory: Memory?, companyId: string, towers: { World.TowerDef }?): string
	if
		type(memory) == "table"
		and memory.companyId == companyId
		and type(memory.anchor) == "string"
		and memory.anchor ~= ""
	then
		return memory.anchor
	end
	local t = DoorRules.towerFor(companyId, towers)
	if t then
		return towerAnchor(t)
	end
	return DoorRules.FALLBACK_EXIT
end

---------------------------------------------------------------------------------------------------
-- Employees and visitors
---------------------------------------------------------------------------------------------------
function DoorRules.isEmployedCareer(career: any): boolean
	if type(career) ~= "table" then
		return false
	end
	if type(career.companyId) ~= "string" or career.companyId == "" then
		return false
	end
	if career.status == "fired" then
		return false
	end
	if type(career.rank) == "number" and career.rank < 1 then
		return false
	end
	return true
end

local MERGER_ID = "merger_mania"

local function activeAt(entry: { [any]: any }, now: number?): boolean
	if now == nil then
		return true
	end
	local s, e = entry.startsAt, entry.endsAt
	if type(s) == "number" and now < s then
		return false
	end
	if type(e) == "number" and now >= e then
		return false
	end
	return true
end

-- Collects every company group of an active merger_mania entry. Accepts the documented
-- {id, startsAt, endsAt, data} entry with data.companies / data.pair / data.pairs / data.a+b and similar.
local function mergerGroups(events: any, now: number?): { { string } }
	local groups: { { string } } = {}
	if type(events) ~= "table" then
		return groups
	end
	local function addList(list: any)
		if type(list) ~= "table" then
			return
		end
		local g: { string } = {}
		for _, id in ipairs(list) do
			if type(id) == "string" then
				table.insert(g, id)
			end
		end
		if #g >= 2 then
			table.insert(groups, g)
		end
	end
	local function addEntry(entry: any)
		if type(entry) ~= "table" or entry.id ~= MERGER_ID or not activeAt(entry, now) then
			return
		end
		local d = entry.data
		if type(d) ~= "table" then
			return
		end
		addList(d.companies)
		addList(d.pair)
		if type(d.pairs) == "table" then
			for _, p in ipairs(d.pairs) do
				addList(p)
			end
		end
		for _, keys in { { "a", "b" }, { "companyA", "companyB" }, { "first", "second" }, { "left", "right" } } do
			local a, b = d[keys[1]], d[keys[2]]
			if type(a) == "string" and type(b) == "string" then
				table.insert(groups, { a, b })
			end
		end
	end
	for key, value in events do
		if type(value) == "table" then
			if value.id ~= nil then
				addEntry(value)
			elseif key ~= "upcoming" or now ~= nil then
				-- lists of entries (e.g. `upcoming` filtered by time, or an `active` list)
				for _, e in ipairs(value) do
					addEntry(e)
				end
			end
		end
	end
	return groups
end

function DoorRules.partnersOf(companyId: string, events: any, now: number?): { [string]: boolean }
	local out: { [string]: boolean } = {}
	for _, g in mergerGroups(events, now) do
		if table.find(g, companyId) then
			for _, other in g do
				if other ~= companyId then
					out[other] = true
				end
			end
		end
	end
	return out
end

function DoorRules.isEmployee(career: any, companyId: string?, events: any?, now: number?): boolean
	if type(companyId) ~= "string" or not DoorRules.isEmployedCareer(career) then
		return false
	end
	local own = career.companyId :: string
	if own == companyId then
		return true
	end
	return DoorRules.partnersOf(own, events, now)[companyId] == true
end

-- Should an interaction prompt show for this player? Prompts marked EmployeesOnly inside an office instance show
-- only to that company's employees (and merger partners); everything else always shows.
function DoorRules.promptAllowed(career: any, employeesOnly: any, companyId: any, events: any?, now: number?): boolean
	if employeesOnly ~= true or type(companyId) ~= "string" or companyId == "" then
		return true
	end
	return DoorRules.isEmployee(career, companyId, events, now)
end

-- The HUD badge while standing in an office: "Visitor · <Company>" in another company's office, nil in your own
-- (or a merger partner's) and outside offices.
function DoorRules.visitorBadge(
	career: any,
	officeCompanyId: any,
	companyName: string?,
	events: any?,
	now: number?
): string?
	if type(officeCompanyId) ~= "string" or officeCompanyId == "" then
		return nil
	end
	if DoorRules.isEmployee(career, officeCompanyId, events, now) then
		return nil
	end
	local name = if type(companyName) == "string" and companyName ~= "" then companyName else nil
	if name then
		return Text.format("visitor_at", { name = name })
	end
	return Text.get("visitor")
end

---------------------------------------------------------------------------------------------------
-- Stages, zones and safety
---------------------------------------------------------------------------------------------------
export type StageInfo = { employed: boolean?, rank: number?, status: string? }

-- Students (and anyone who never started a career) belong on campus; everyone who has been hired belongs on
-- the Street, including players between jobs (Career Services and re-entry live there).
function DoorRules.stageFor(info: StageInfo?): string
	local i: StageInfo = info or {}
	if i.employed == true then
		return "street"
	end
	if type(i.rank) == "number" and i.rank >= 1 then
		return "street"
	end
	if i.status == "fired" or i.status == "probation" then
		return "street"
	end
	return "campus"
end

DoorRules.STAGE_SPAWNS = { campus = "Spawn_campus", street = "Spawn_street" }

function DoorRules.isCampusSide(zoneId: string?): boolean
	if type(zoneId) ~= "string" then
		return false
	end
	local z = World.zones[zoneId]
	return z ~= nil and z.theme == "campus"
end

local function prettify(id: string): string
	local words = {}
	for w in string.gmatch(id, "[^_]+") do
		table.insert(words, string.upper(string.sub(w, 1, 1)) .. string.sub(w, 2))
	end
	return table.concat(words, " ")
end
DoorRules.prettify = prettify

function DoorRules.zoneLabel(zoneId: string?): string
	if type(zoneId) ~= "string" then
		return ""
	end
	local key = "zone_" .. zoneId
	local s = Text.get(key, "")
	if s ~= "" then
		return s
	end
	local z = World.zones[zoneId]
	if z and type(z.label) == "string" and z.label ~= zoneId then
		return z.label
	end
	return prettify(zoneId)
end

function DoorRules.anchorZone(anchorId: string): string?
	local a = World.anchors[anchorId]
	return if a then a.zone else nil
end

-- One safety sample. Returns the action to take now (if any) and the updated out-of-zone start time.
function DoorRules.safety(y: number, zoneId: string?, outSince: number?, now: number): (string?, number?)
	if y < DoorRules.FALL_Y then
		return "fall", nil
	end
	if zoneId ~= nil then
		return nil, nil
	end
	local since = outSince or now
	if now - since > DoorRules.OUT_OF_ZONE_SEC then
		return "out_of_zone", nil
	end
	return nil, since
end

export type MoveOpts = { maxSpeed: number?, minJump: number? }

function DoorRules.impossibleMove(from: Vector3, to: Vector3, dt: number, opts: MoveOpts?): boolean
	local o: MoveOpts = opts or {}
	local maxSpeed = o.maxSpeed or DoorRules.MAX_SPEED
	local minJump = o.minJump or DoorRules.MIN_JUMP
	local dx, dz = to.X - from.X, to.Z - from.Z
	local dist = math.sqrt(dx * dx + dz * dz)
	if dist < minJump then
		return false
	end
	local window = math.max(dt, 0.05)
	return dist > maxSpeed * window
end

return DoorRules
