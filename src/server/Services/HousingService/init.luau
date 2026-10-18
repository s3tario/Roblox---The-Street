--!strict
-- HousingService (server, owned by `shop`; contracts §7, spec §11, v3 §13): where each player lives and works on this
-- server, the decor they placed there, room themes, nameplates and their lucite deal plaques.
--
-- Contexts (Config/Decor.CONTEXTS) and who gets them (Logic/Economy/Assign):
--   dorm       students: a UnitSlot in the dorm interior
--   apartment  employees: a UnitSlot in the Ashford Residences
--   desk       employees below rank 3: a DeskSlot on their company's floor for their track
--   office     rank 3 and above: an OfficeSlot on that floor (a desk while every office is taken)
-- Floors only exist while someone is in that company's office (OfficeService builds them lazily), so desks and offices
-- are claimed on OfficeService.FloorCreated (or OfficeService:GetFloor) and dropped on FloorRemoved; the player keeps
-- a preferred index so the same desk comes back. Assignments are re-checked on CareerService.RoleChanged /
-- StatusChanged (a promotion moves you into an office, firing releases the desk) and released when the player leaves.
-- A claimed container carries OwnerUserId / OwnerName (OfficeService's NPC coworkers leave owned desks).
--
-- Drawing (HousingService/Render): placed decor through Props.build on the container's DecorSlots, the nameplate
-- ("name / title"), the room theme on ThemeWall / ThemeFloor parts, and deal plaques (v3 §13): the newest 3 on the
-- desk's plaque slots, up to 24 on an office bookshelf. Each container is redrawn only when what it shows changed.
--
-- Data: data.housing (Config/DataTemplate/Housing) = { owned, placed = { [context] = { [slotId] = decorId } }, theme }.
--
-- API (contracts §7):
--   HousingService:GetAssignment(player) -> { context?, unit?, desk?, office? }
--       unit = { kind, index, where }   desk / office = { companyId, track, index, where }
--   HousingService:RefreshPlaques(player)            careerPath calls it after RecordDeal and promotions
-- Extras:
--   HousingService:Place(player, context, slotId, decorId?) -> (ok, errKey?)   nil decorId clears the spot
--   HousingService:SetTheme(player, context, themeId) -> (ok, errKey?)          (may yield: pass check)
--   HousingService:GetView(player) -> View          what the Housing screen shows (may yield: pass check)
--   HousingService:OpenFor(player, args?)           opens the Housing screen ({ context? })
--   HousingService.AssignmentChanged : Signal(player, assignment)
-- Remotes: HousingService/Remotes ("Housing.Get", "Housing.Place", "Housing.SetTheme"; "Housing.Open" and
-- "Housing.Changed" server -> client). Interact: `housing_panel` (attribute Context); inside office instances only
-- employees may use it, and only the owner of the desk/office/room it belongs to can customize it.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Signal = require(Shared.Util.Signal)
local Shop = require(Shared.Config.Shop)
local Decor = require(Shared.Config.Decor)
local Props = require(Shared.Assets.Props)
local Assign = require(Shared.Logic.Economy.Assign)
local Housing = require(Shared.Logic.Economy.Housing)
local Plaques = require(Shared.Logic.Economy.Plaques)
local Deps = require(script.Parent.ShopService.Deps)
local Prompts = require(script.Parent.ShopService.Prompts)
local Markers = require(script.Markers)
local Render = require(script.Render)
local Remotes = require(script.Remotes)

local HousingService = {
	Name = "HousingService",
	Priority = 40,
	AssignmentChanged = Signal.new(), -- (player, assignment)
}

HousingService.Markers = Markers
HousingService.Render = Render

local SWEEP_EVERY = 15
local OPEN_COOLDOWN = 0.5
local UNIT_SCAN_RETRIES = 6
local UNIT_SCAN_WAIT = 5
local LOBBY = "lobby"

type FloorRec = {
	key: string,
	companyId: string,
	track: string,
	model: Instance,
	desks: { Instance },
	offices: { Instance },
	deskPool: Assign.Pool,
	officePool: Assign.Pool,
}
type UnitSet = { list: { Instance }, pool: Assign.Pool }
type Held = { kind: string, index: number, inst: Instance, key: string?, sig: string? }
type PState = {
	player: Player,
	loaded: boolean,
	unit: Held?,
	work: Held?,
	wants: Assign.Wants,
	prefs: { [string]: number },
	notes: { [string]: boolean },
	lastOpen: number,
	passes: { [string]: boolean }?,
}

export type Assignment = {
	context: string?,
	unit: { kind: string, index: number, where: string }?,
	desk: { companyId: string, track: string, index: number, where: string }?,
	office: { companyId: string, track: string, index: number, where: string }?,
}

local states: { [Player]: PState } = {}
local floors: { [string]: FloorRec } = {}
local units: { [string]: UnitSet } = {}
local slotCache: { [Instance]: { Markers.Slot } } = setmetatable({}, { __mode = "k" }) :: any

---------------------------------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------------------------------
local function partsFor(propId: string): number
	local info = Props.get(propId)
	return if info then info.maxParts else 0
end

local function footprintFor(propId: string): Vector3?
	local info = Props.get(propId)
	return if info then info.footprint else nil
end

-- data.housing, repaired once per save table (weak: a restored save brings a fresh table that is repaired again).
local repaired: { [any]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local function housingOf(player: Player): Housing.HousingData?
	local data = Deps.data(player)
	if not data then
		return nil
	end
	local raw = data.housing
	if type(raw) == "table" and repaired[raw] then
		return raw :: Housing.HousingData
	end
	local h = Housing.normalize(raw)
	data.housing = h
	repaired[h] = true
	return h
end

local function slotsOf(container: Instance): { Markers.Slot }
	local cached = slotCache[container]
	if cached then
		return cached
	end
	local list = Markers.slots(container)
	slotCache[container] = list
	return list
end

local function splitSlots(container: Instance): ({ Markers.Slot }, { Markers.Slot })
	local decor: { Markers.Slot } = {}
	local plaques: { Markers.Slot } = {}
	for _, slot in slotsOf(container) do
		if slot.kind == Decor.PLAQUE then
			table.insert(plaques, slot)
		else
			table.insert(decor, slot)
		end
	end
	return decor, plaques
end

local function asHousingSlots(list: { Markers.Slot }): { Housing.Slot }
	local out: { Housing.Slot } = {}
	for _, s in list do
		table.insert(out, { id = s.id, kind = s.kind, limits = s.limits })
	end
	return out
end

local function whereText(kind: string, index: number): string
	if kind == "desk" then
		return Shop.text("where_desk", { n = index })
	elseif kind == "office" then
		return Shop.text("where_office", { n = index })
	elseif kind == "dorm" then
		return Shop.text("where_room", { n = index })
	end
	return Shop.text("where_unit", { n = index })
end

local function alive(inst: Instance?): boolean
	return inst ~= nil and inst.Parent ~= nil and inst:IsDescendantOf(workspace)
end

local function heldFor(ps: PState, ctx: string): Held?
	if ps.unit and ps.unit.kind == ctx then
		return ps.unit
	end
	if ps.work and ps.work.kind == ctx then
		return ps.work
	end
	return nil
end

local function prefKey(kind: string, key: string?): string
	return if key then kind .. "|" .. key else kind
end

---------------------------------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------------------------------
local function placedSignature(placed: { [string]: string }?): string
	if not placed then
		return ""
	end
	local list: { string } = {}
	for slotId, decorId in placed do
		table.insert(list, slotId .. "=" .. decorId)
	end
	table.sort(list)
	return table.concat(list, ",")
end

-- Draws one held container. Skipped when nothing it shows changed (no flicker on re-syncs).
local function draw(player: Player, ps: PState, held: Held, force: boolean?)
	local container = held.inst
	if not alive(container) then
		return
	end
	local h = housingOf(player)
	if not h then
		return
	end
	local ctx = held.kind
	local context = Decor.CONTEXTS[ctx]
	local career = Deps.career(player)
	local name = Deps.displayName(player)
	local title = if career.title ~= "" then career.title else (if context then context.label else "")
	local theme = Housing.themeOf(h, ctx, ps.passes)
	local cap = Plaques.capacityFor(ctx)
	local newest: { Plaques.Plaque } = if cap > 0 then Plaques.newest(Deps.plaques(player), cap) else {}
	local plaqueIds: { string } = {}
	for _, p in newest do
		table.insert(plaqueIds, p.id .. "@" .. tostring(p.at))
	end
	local sig = table.concat({
		tostring(held.index),
		held.key or "",
		name,
		title,
		tostring(career.rank),
		theme.id,
		placedSignature(h.placed[ctx]),
		table.concat(plaqueIds, ","),
	}, "|")
	if not force and held.sig == sig and container:GetAttribute("OwnerUserId") == player.UserId then
		return
	end
	held.sig = sig

	Render.setOwner(container, player.UserId, player.DisplayName)
	Render.nameplate(container, Shop.text("nameplate_text", { name = name, title = title }))
	local decorSlots, plaqueSlots = splitSlots(container)
	local visible = Housing.visible(h, ctx, asHousingSlots(decorSlots), career.rank, partsFor)
	Render.decor(container, decorSlots, visible)
	if context and context.themed then
		Render.theme(container, if theme.id == Decor.DEFAULT_THEME then nil else theme)
	end
	if cap > 0 then
		local ids: { string } = {}
		for _, s in plaqueSlots do
			table.insert(ids, s.id)
		end
		Render.plaques(container, plaqueSlots, Plaques.layout(newest, ids, cap))
	end
end

local function drawAll(player: Player, ps: PState, force: boolean?)
	if ps.unit then
		draw(player, ps, ps.unit, force)
	end
	if ps.work then
		draw(player, ps, ps.work, force)
	end
end

---------------------------------------------------------------------------------------------------
-- Pools
---------------------------------------------------------------------------------------------------
local function registerFloor(companyId: string, track: string, model: Instance): FloorRec
	local key = Assign.floorKey(companyId, track)
	local existing = floors[key]
	if existing and existing.model == model then
		return existing
	end
	local desks = Markers.containers(model, "desk")
	local offices = Markers.containers(model, "office")
	local rec: FloorRec = {
		key = key,
		companyId = companyId,
		track = track,
		model = model,
		desks = desks,
		offices = offices,
		deskPool = Assign.newPool(#desks),
		officePool = Assign.newPool(#offices),
	}
	floors[key] = rec
	-- anyone still holding a container of the old model lost it with that model
	for _, ps in states do
		if ps.work and ps.work.key == key and not alive(ps.work.inst) then
			ps.work = nil
		end
	end
	return rec
end

local function floorFor(companyId: string, track: string): FloorRec?
	local key = Assign.floorKey(companyId, track)
	local rec = floors[key]
	if rec and alive(rec.model) then
		return rec
	end
	floors[key] = nil
	local ok, model = Deps.call("OfficeService", "GetFloor", companyId, track)
	if ok and typeof(model) == "Instance" and alive(model) then
		return registerFloor(companyId, track, model)
	end
	return nil
end

local function scanUnits(): number
	local found: { [string]: { Instance } } = { dorm = {}, apartment = {} }
	for _, c in Markers.containers(workspace, "unit") do
		local kind = Markers.unitKind(c)
		if kind and found[kind] then
			table.insert(found[kind], c)
		end
	end
	local total = 0
	for kind, list in found do
		units[kind] = { list = list, pool = Assign.newPool(#list) }
		total += #list
	end
	return total
end

---------------------------------------------------------------------------------------------------
-- Assignment
---------------------------------------------------------------------------------------------------
local function noteOnce(player: Player, ps: PState, key: string, text: string)
	if ps.notes[key] then
		return
	end
	ps.notes[key] = true
	Deps.notify(player, text, "info")
end

local function release(ps: PState, which: "unit" | "work")
	local held = if which == "unit" then ps.unit else ps.work
	if not held then
		return
	end
	if which == "unit" then
		ps.unit = nil
		local set = units[held.kind]
		if set then
			Assign.release(set.pool, ps.player)
		end
	else
		ps.work = nil
		local rec = if held.key then floors[held.key] else nil
		if rec then
			Assign.release(rec.deskPool, ps.player)
			Assign.release(rec.officePool, ps.player)
		end
	end
	ps.prefs[prefKey(held.kind, held.key)] = held.index
	if held.inst.Parent and held.inst:GetAttribute("OwnerUserId") == ps.player.UserId then
		Render.clear(held.inst)
	end
end

local function claimUnit(player: Player, ps: PState, kind: string)
	local set = units[kind]
	if not set or set.pool.capacity == 0 then
		return
	end
	local index = Assign.claim(set.pool, player, ps.prefs[kind])
	if not index then
		noteOnce(player, ps, "unit_full_" .. kind, Shop.text("unit_full"))
		return
	end
	local inst = set.list[index]
	local pref = ps.prefs[kind]
	ps.unit = { kind = kind, index = index, inst = inst }
	ps.prefs[kind] = index
	ps.notes["unit_full_" .. kind] = nil
	if pref ~= index then
		local def = Decor.CONTEXTS[kind]
		Deps.notify(
			player,
			Shop.text(
				"assigned_unit",
				{ kind = string.lower(if def then def.label else kind), where = whereText(kind, index) }
			),
			"good"
		)
	end
end

local function claimWork(player: Player, ps: PState, wants: Assign.Wants)
	local companyId, track = wants.companyId, wants.track
	if not companyId or not track or not wants.work then
		return
	end
	local rec = floorFor(companyId, track)
	if not rec then
		return -- the floor isn't built yet: claimed on FloorCreated
	end
	local key = rec.key
	local kind, index, note = Assign.work(rec.deskPool, rec.officePool, player, wants.work == "office", {
		desk = ps.prefs[prefKey("desk", key)],
		office = ps.prefs[prefKey("office", key)],
	})
	if note == "office_full" then
		noteOnce(player, ps, key .. ":office_full", Shop.text("office_full"))
	elseif note == "desk_full" then
		noteOnce(player, ps, key .. ":desk_full", Shop.text("desk_full"))
	end
	if not kind or not index then
		if ps.work then
			release(ps, "work")
		end
		return
	end
	local inst = if kind == "office" then rec.offices[index] else rec.desks[index]
	local old = ps.work
	if old and old.inst == inst and old.kind == kind then
		return
	end
	if old and old.inst ~= inst and old.inst.Parent and old.inst:GetAttribute("OwnerUserId") == player.UserId then
		Render.clear(old.inst)
	end
	local isNew = old == nil or old.kind ~= kind or old.index ~= index
	local pref = ps.prefs[prefKey(kind, key)]
	ps.work = { kind = kind, index = index, inst = inst, key = key }
	ps.prefs[prefKey(kind, key)] = index
	if isNew and pref ~= index then
		local textKey = if kind == "office" then "assigned_office" else "assigned_desk"
		Deps.notify(player, Shop.text(textKey, { where = whereText(kind, index) }), "good")
	end
	if note ~= "office_full" then
		ps.notes[key .. ":office_full"] = nil
	end
	ps.notes[key .. ":desk_full"] = nil
end

local function assignmentOf(ps: PState): Assignment
	local out: Assignment = {}
	local unit = ps.unit
	if unit then
		out.unit = { kind = unit.kind, index = unit.index, where = whereText(unit.kind, unit.index) }
	end
	local work = ps.work
	if work then
		local rec = if work.key then floors[work.key] else nil
		local entry = {
			companyId = if rec then rec.companyId else "",
			track = if rec then rec.track else "",
			index = work.index,
			where = whereText(work.kind, work.index),
		}
		if work.kind == "office" then
			out.office = entry
		else
			out.desk = entry
		end
	end
	out.context = if work then work.kind elseif unit then unit.kind else nil
	return out
end

local function assignmentSig(ps: PState): string
	local u = ps.unit
	local w = ps.work
	return (if u then u.kind .. tostring(u.index) else "-")
		.. "/"
		.. (if w then w.kind .. tostring(w.index) .. (w.key or "") else "-")
end

-- Reconciles what the player holds with what their career wants, then redraws what changed. Never yields.
local function sync(player: Player, force: boolean?)
	local ps = states[player]
	if not ps or not ps.loaded or player.Parent ~= Players then
		return
	end
	local before = assignmentSig(ps)
	local wants = Assign.contextsFor(Deps.career(player))
	ps.wants = wants

	-- dorm / apartment
	local unit = ps.unit
	if unit and (unit.kind ~= wants.unit or not alive(unit.inst)) then
		release(ps, "unit")
	end
	if wants.unit and not ps.unit then
		claimUnit(player, ps, wants.unit)
	end

	-- desk / office
	local key = if wants.work
			and wants.companyId
			and wants.track
		then Assign.floorKey(wants.companyId, wants.track)
		else nil
	local work = ps.work
	if work and (key == nil or work.key ~= key or not alive(work.inst)) then
		release(ps, "work")
	end
	if key then
		claimWork(player, ps, wants)
	end

	drawAll(player, ps, force)
	if assignmentSig(ps) ~= before then
		local a = assignmentOf(ps)
		HousingService.AssignmentChanged:Fire(player, a)
		Remotes.changed(player)
	end
end

---------------------------------------------------------------------------------------------------
-- API
---------------------------------------------------------------------------------------------------
function HousingService:GetAssignment(player: Player): Assignment
	local ps = states[player]
	if not ps then
		return {}
	end
	return assignmentOf(ps)
end

function HousingService:RefreshPlaques(player: Player)
	local ps = states[player]
	if not ps or not ps.loaded then
		return
	end
	sync(player)
	if ps.work then
		draw(player, ps, ps.work, false)
	end
end

function HousingService:Place(player: Player, ctx: string, slotId: string, decorId: string?): (boolean, string?)
	local ps = states[player]
	local h = housingOf(player)
	if not ps or not h or not ps.loaded then
		return false, "not_loaded"
	end
	if Decor.CONTEXTS[ctx] == nil then
		return false, "no_context"
	end
	local held = heldFor(ps, ctx)
	if not held then
		return false, "no_context"
	end
	if not alive(held.inst) then
		return false, "not_live"
	end
	local decorSlots = asHousingSlots((splitSlots(held.inst)))
	local slot: Housing.Slot? = nil
	for _, s in decorSlots do
		if s.id == slotId then
			slot = s
		end
	end
	if not slot then
		return false, "bad_slot"
	end
	local career = Deps.career(player)
	local ok, err = Housing.checkPlace(h, ctx, slot, decorId, {
		rank = career.rank,
		partsFor = partsFor,
		footprintFor = footprintFor,
		slots = decorSlots,
	})
	if not ok then
		return false, err
	end
	if h.placed[ctx][slotId] == decorId then
		return true, nil
	end
	Housing.place(h, ctx, slotId, decorId)
	Deps.replicate(player, "housing")
	draw(player, ps, held, false)
	return true, nil
end

local function refreshPasses(player: Player): { [string]: boolean }
	local passes = { [Decor.THEME_PASS] = Deps.ownsPass(player, Decor.THEME_PASS) }
	local ps = states[player]
	if ps then
		local changed = ps.passes == nil or ps.passes[Decor.THEME_PASS] ~= passes[Decor.THEME_PASS]
		ps.passes = passes
		if changed then
			drawAll(player, ps, false)
		end
	end
	return passes
end

function HousingService:SetTheme(player: Player, ctx: string, themeId: string): (boolean, string?)
	local ps = states[player]
	if not ps or not ps.loaded or not housingOf(player) then
		return false, "not_loaded"
	end
	local wants = ps.wants
	local holds = heldFor(ps, ctx) ~= nil or wants.unit == ctx or wants.work == ctx
	if not holds then
		return false, "no_context"
	end
	local passes = refreshPasses(player) -- yields while MonetizationService answers
	local ok, err = Housing.checkTheme(ctx, themeId, passes)
	if not ok then
		return false, err
	end
	local h = housingOf(player)
	if not h or states[player] ~= ps then
		return false, "not_loaded"
	end
	Housing.setTheme(h, ctx, themeId)
	Deps.replicate(player, "housing")
	local held = heldFor(ps, ctx)
	if held then
		draw(player, ps, held, false)
	end
	return true, nil
end

export type ContextView = {
	id: string,
	label: string,
	title: string,
	held: boolean,
	live: boolean,
	where: string?,
	themed: boolean,
	theme: string,
	budget: number,
	used: number,
	slots: { { id: string, kind: string } },
	plaqueSlots: number,
	plaquesShown: number,
}
export type View = {
	loaded: boolean,
	name: string,
	title: string,
	rank: number,
	passes: { [string]: boolean },
	plaqueCount: number,
	assignment: Assignment,
	contexts: { ContextView },
}

function HousingService:GetView(player: Player): View
	local ps = states[player]
	local h = housingOf(player)
	if not ps or not h or not ps.loaded then
		return {
			loaded = false,
			name = player.DisplayName,
			title = "",
			rank = 0,
			passes = {},
			plaqueCount = 0,
			assignment = {},
			contexts = {},
		}
	end
	local passes = refreshPasses(player)
	-- the pass check may have yielded: re-read everything after it
	ps = states[player]
	h = housingOf(player)
	if not ps or not h then
		return {
			loaded = false,
			name = player.DisplayName,
			title = "",
			rank = 0,
			passes = {},
			plaqueCount = 0,
			assignment = {},
			contexts = {},
		}
	end
	sync(player)
	local career = Deps.career(player)
	local plaques = Deps.plaques(player)
	local list: { ContextView } = {}
	for _, ctx in Decor.CONTEXT_ORDER do
		local def = Decor.CONTEXTS[ctx]
		local held = heldFor(ps, ctx)
		-- a wanted place shows (as "head there") only while nothing else of its kind is held: a VP who got a desk
		-- because every office was taken sees the desk, not an empty office tab
		local wanted = (ps.wants.unit == ctx and ps.unit == nil) or (ps.wants.work == ctx and ps.work == nil)
		if def and (held or wanted) then
			local slots: { { id: string, kind: string } } = {}
			local used = 0
			local plaqueSlots, shown = 0, 0
			local live = held ~= nil and alive(held.inst)
			if held and live then
				local decorSlots, pSlots = splitSlots(held.inst)
				local liveSlots: { [string]: boolean } = {}
				for _, s in decorSlots do
					table.insert(slots, { id = s.id, kind = s.kind })
					liveSlots[s.id] = true
				end
				used = Housing.partsUsed(h.placed[ctx] or {}, partsFor, nil, liveSlots)
				plaqueSlots = #pSlots
				local cap = math.min(Plaques.capacityFor(ctx), plaqueSlots)
				shown = math.min(cap, Plaques.count(plaques))
			end
			table.insert(list, {
				id = ctx,
				label = def.label,
				title = def.title,
				held = held ~= nil,
				live = live,
				where = if held then whereText(held.kind, held.index) else nil,
				themed = def.themed,
				theme = Housing.themeOf(h, ctx, passes).id,
				budget = def.budget,
				used = used,
				slots = slots,
				plaqueSlots = plaqueSlots,
				plaquesShown = shown,
			})
		end
	end
	return {
		loaded = true,
		name = Deps.displayName(player),
		title = career.title,
		rank = career.rank,
		passes = passes,
		plaqueCount = Plaques.count(plaques),
		assignment = assignmentOf(ps),
		contexts = list,
	}
end

function HousingService:OpenFor(player: Player, args: { [string]: any }?)
	Remotes.open(player, args)
end

---------------------------------------------------------------------------------------------------
-- The housing_panel interact
---------------------------------------------------------------------------------------------------
local function onPanel(player: Player, inst: Instance, _prompt: ProximityPrompt, companyId: string?)
	local ps = states[player]
	if not ps then
		return
	end
	local now = os.clock()
	if now - ps.lastOpen < OPEN_COOLDOWN then
		return
	end
	ps.lastOpen = now
	if companyId and not Deps.isEmployeeOf(player, companyId) then
		Deps.notify(player, Shop.text("employees_only"), "warn")
		return
	end
	if not ps.loaded then
		Deps.notify(player, Shop.errorText("not_loaded"), "warn")
		return
	end
	local attr = inst:GetAttribute("Context")
	local container, ckind = Markers.containerOf(inst)
	if not container then
		HousingService:OpenFor(player, { context = if type(attr) == "string" then attr else nil })
		return
	end
	-- an office instance's floors are built lazily: make sure this one is known before deciding
	sync(player)
	local owner = container:GetAttribute("OwnerUserId")
	if owner == player.UserId then
		local held = if ps.work and ps.work.inst == container
			then ps.work
			elseif ps.unit and ps.unit.inst == container then ps.unit
			else nil
		HousingService:OpenFor(player, { context = if held then held.kind else attr })
		return
	end
	if type(owner) == "number" then
		local name = container:GetAttribute("OwnerName")
		Deps.notify(player, Shop.text("not_yours", { name = if type(name) == "string" then name else "" }), "info")
		return
	end
	local mine: Held? = nil
	if ckind == "unit" then
		mine = ps.unit
	else
		mine = ps.work
	end
	if mine then
		Deps.notify(player, Shop.text("not_yours_free", { where = whereText(mine.kind, mine.index) }), "info")
	else
		Deps.notify(player, Shop.text("not_yours_none"), "info")
	end
end

local function panelText(inst: Instance): string?
	local ctx = inst:GetAttribute("Context")
	local def = if type(ctx) == "string" then Decor.CONTEXTS[ctx] else nil
	return if def then def.title else nil
end

---------------------------------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------------------------------
local function stateFor(player: Player): PState?
	if player.Parent ~= Players then
		return nil
	end
	local ps = states[player]
	if not ps then
		ps = {
			player = player,
			loaded = false,
			unit = nil,
			work = nil,
			wants = {},
			prefs = {},
			notes = {},
			lastOpen = 0,
			passes = nil,
		}
		states[player] = ps
	end
	return ps
end

local function onLoaded(player: Player)
	local ps = stateFor(player)
	if not ps then
		return
	end
	if not housingOf(player) then
		return
	end
	ps.loaded = true
	Deps.replicate(player, "housing")
	-- deferred: the career's own ProfileLoaded handling (repair, derived fields) runs first
	task.defer(sync, player)
	task.spawn(refreshPasses, player)
end

local function onRemoving(player: Player)
	local ps = states[player]
	if not ps then
		return
	end
	release(ps, "unit")
	release(ps, "work")
	states[player] = nil
end

local function onFloorCreated(companyId: string, track: string, model: Instance)
	if type(companyId) ~= "string" or type(track) ~= "string" or track == LOBBY or typeof(model) ~= "Instance" then
		return
	end
	registerFloor(companyId, track, model)
	local key = Assign.floorKey(companyId, track)
	for player, ps in states do
		local w = ps.wants
		if ps.loaded and w.work and w.companyId and w.track and Assign.floorKey(w.companyId, w.track) == key then
			sync(player)
		end
	end
end

local function onFloorRemoved(companyId: string, track: string)
	if type(companyId) ~= "string" or type(track) ~= "string" then
		return
	end
	local key = Assign.floorKey(companyId, track)
	floors[key] = nil
	for _, ps in states do
		local work = ps.work
		if work and work.key == key then
			ps.prefs[prefKey(work.kind, key)] = work.index
			ps.work = nil
		end
	end
end

function HousingService:Init()
	Remotes.bind(HousingService)
	Deps.connect("DataService", "ProfileLoaded", function(player: Player)
		onLoaded(player)
	end)
end

function HousingService:Start()
	Players.PlayerRemoving:Connect(onRemoving)

	local function deferSync(player: Player)
		if typeof(player) == "Instance" and player:IsA("Player") then
			task.defer(sync, player)
		end
	end
	Deps.connect("CareerService", "RoleChanged", deferSync)
	Deps.connect("CareerService", "StatusChanged", deferSync)
	Deps.connect("CareerService", "DealRecorded", function(player: Player)
		if states[player] then
			task.defer(HousingService.RefreshPlaques, HousingService, player)
		end
	end)
	Deps.connect("ProfileService", "ProfileLocked", deferSync) -- a new name on the nameplate
	Deps.connect("OfficeService", "FloorCreated", onFloorCreated)
	Deps.connect("OfficeService", "FloorRemoved", onFloorRemoved)

	Prompts.watch({
		interactId = "housing_panel",
		promptName = "HousingPrompt",
		actionText = Shop.text("prompt_housing"),
		objectText = panelText,
		onTriggered = onPanel,
	})

	-- the baked world is in place when the server starts; retry briefly in case it streams in late
	local total = scanUnits()
	local tries = 0
	while total == 0 and tries < UNIT_SCAN_RETRIES do
		tries += 1
		task.wait(UNIT_SCAN_WAIT)
		total = scanUnits()
	end
	if total == 0 then
		warn("[HousingService] no UnitSlot markers found: dorm rooms and apartments are unavailable")
	end

	for _, player in Players:GetPlayers() do
		if Deps.isLoaded(player) then
			task.spawn(onLoaded, player)
		end
	end

	-- safety net: floors that appeared without a FloorCreated we saw, containers destroyed behind our back
	while true do
		task.wait(SWEEP_EVERY)
		for player, ps in states do
			if ps.loaded then
				local ok, err = pcall(function()
					sync(player)
				end)
				if not ok then
					warn("[HousingService] sync failed: " .. tostring(err))
				end
			end
		end
	end
end

return HousingService
