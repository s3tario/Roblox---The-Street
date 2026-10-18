--!strict
-- Economy/Housing: decor placement rules (PURE: no services, no clocks, no Instances; unit-tested in tests/shop).
-- HousingService validates every Housing.Place / Housing.SetTheme request here before it touches data or the world.
--
--   Housing.normalize(raw) -> HousingData      repairs a loaded data.housing in place (or builds a new one)
--   Housing.accepts(slotKind, item) -> boolean  can this decor item stand in a slot of that kind (Decor.ACCEPTS)
--   Housing.fits(footprint?, limits?) -> boolean   size limits of a slot (MaxWidth / MaxHeight / MaxDepth studs)
--   Housing.partsUsed(placed, partsFor, skipSlot?) -> number   runtime parts that context's decor adds
--   Housing.checkPlace(h, ctx, slot, decorId, opts) -> (ok, err?)
--       err: no_context, bad_slot, unknown_item, not_owned, wrong_kind, context, rank, too_big, budget
--   Housing.place(h, ctx, slotId, decorId?) -> movedFrom?   writes (or clears with nil) one slot; an item already
--       standing elsewhere in the same context moves (one copy per context)
--   Housing.checkTheme(ctx, themeId, passes) -> (ok, err?)    err: no_context, not_themed, bad_theme, pass
--   Housing.setTheme(h, ctx, themeId)
--   Housing.themeOf(h, ctx) -> Theme              the theme to render (Decor.DEFAULT_THEME when unset or invalid)
--   Housing.visible(h, ctx, slots, rank?) -> { [slotId] = Item }   what to draw: placed items that still fit
--
-- slot = { id, kind, limits? = { width?, height?, depth? } }
-- opts = { rank: number, partsFor: (propId) -> number, footprintFor: ((propId) -> Vector3?)?,
--          budget: number? (default Decor.CONTEXTS[ctx].budget),
--          slots: { Slot }? (the context's other slots, so the budget skips placements that no longer exist) }

local Config = script.Parent.Parent.Parent.Config
local Decor = require(Config.Decor)

export type HousingData = {
	owned: { [string]: boolean },
	placed: { [string]: { [string]: string } },
	theme: { [string]: string },
}
export type Limits = { width: number?, height: number?, depth: number? }
export type Slot = { id: string, kind: string, limits: Limits? }
export type PlaceOpts = {
	rank: number?,
	partsFor: (propId: string) -> number,
	footprintFor: ((propId: string) -> Vector3?)?,
	budget: number?,
	slots: { Slot }?,
}

local Housing = {}

local MAX_ID = 64

local function finite(x: any): boolean
	return type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge
end

local function validId(x: any): boolean
	return type(x) == "string" and #x > 0 and #x <= MAX_ID
end

function Housing.normalize(raw: any): HousingData
	local h: any = if type(raw) == "table" then raw else {}
	local owned: { [string]: boolean } = {}
	if type(h.owned) == "table" then
		for id, v in h.owned do
			if v and validId(id) then
				owned[id] = true
			end
		end
	end
	h.owned = owned
	local placed: { [string]: { [string]: string } } = {}
	local rawPlaced = if type(h.placed) == "table" then h.placed else {}
	for ctx in Decor.CONTEXTS do
		local list: { [string]: string } = {}
		local src = rawPlaced[ctx]
		if type(src) == "table" then
			for slotId, decorId in src do
				if validId(slotId) and validId(decorId) then
					list[slotId] = decorId
				end
			end
		end
		placed[ctx] = list
	end
	h.placed = placed
	local theme: { [string]: string } = {}
	if type(h.theme) == "table" then
		for ctx, id in h.theme do
			if Decor.CONTEXTS[ctx] and Decor.theme(id) then
				theme[ctx] = id
			end
		end
	end
	h.theme = theme
	return h :: HousingData
end

function Housing.accepts(slotKind: string, item: Decor.Item?): boolean
	if item == nil then
		return false
	end
	local accepts = Decor.ACCEPTS[slotKind]
	if accepts == nil then
		return false
	end
	for _, kind in item.slots do
		if accepts[kind] then
			return true
		end
	end
	return false
end

function Housing.fits(footprint: Vector3?, limits: Limits?): boolean
	if footprint == nil or limits == nil then
		return true
	end
	local function ok(size: number, limit: number?): boolean
		return limit == nil or not finite(limit) or limit <= 0 or size <= limit + 1e-6
	end
	-- the item may turn 90 degrees to fit a slot that is deeper than it is wide
	local w, d = footprint.X, footprint.Z
	local straight = ok(w, limits.width) and ok(d, limits.depth)
	local turned = ok(d, limits.width) and ok(w, limits.depth)
	return (straight or turned) and ok(footprint.Y, limits.height)
end

function Housing.partsUsed(
	placed: { [string]: string },
	partsFor: (propId: string) -> number,
	skipSlot: string?,
	liveSlots: { [string]: boolean }?
): number
	local total = 0
	for slotId, decorId in placed do
		if slotId ~= skipSlot and (liveSlots == nil or liveSlots[slotId]) then
			local item = Decor.get(decorId)
			if item then
				local n = partsFor(item.prop)
				if finite(n) and n > 0 then
					total += n
				end
			end
		end
	end
	return total
end

function Housing.checkPlace(
	h: HousingData,
	ctx: string,
	slot: Slot?,
	decorId: string?,
	opts: PlaceOpts
): (boolean, string?)
	local context = Decor.CONTEXTS[ctx]
	if context == nil then
		return false, "no_context"
	end
	if slot == nil or not validId(slot.id) then
		return false, "bad_slot"
	end
	if decorId == nil then
		return true, nil -- clearing a slot is always allowed
	end
	if slot.kind == Decor.PLAQUE or table.find(Decor.PLACEABLE, slot.kind) == nil then
		return false, "wrong_kind"
	end
	local item = Decor.get(decorId)
	if item == nil then
		return false, "unknown_item"
	end
	if not h.owned[item.id] then
		return false, "not_owned"
	end
	if not Housing.accepts(slot.kind, item) then
		return false, "wrong_kind"
	end
	if not Decor.allowedIn(item, ctx) then
		return false, "context"
	end
	local rank = if finite(opts.rank) then opts.rank :: number else 0
	if item.minRank and rank < item.minRank then
		return false, "rank"
	end
	local footprintFor = opts.footprintFor
	local footprint = if footprintFor then footprintFor(item.prop) else nil
	if not Housing.fits(footprint, slot.limits) then
		return false, "too_big"
	end
	local live: { [string]: boolean }? = nil
	if opts.slots then
		local set: { [string]: boolean } = {}
		for _, s in opts.slots do
			set[s.id] = true
		end
		live = set
	end
	local placed: { [string]: string } = h.placed[ctx] or {}
	-- an item already standing elsewhere in this context moves here, so its old spot stops counting
	local skip: { [string]: boolean } = { [slot.id] = true }
	for sid, did in placed do
		if did == item.id then
			skip[sid] = true
		end
	end
	local others: { [string]: string } = {}
	for sid, did in placed do
		if not skip[sid] then
			others[sid] = did
		end
	end
	local used = Housing.partsUsed(others, opts.partsFor, nil, live)
	local budget = if finite(opts.budget) then opts.budget :: number else context.budget
	if used + opts.partsFor(item.prop) > budget then
		return false, "budget"
	end
	return true, nil
end

function Housing.place(h: HousingData, ctx: string, slotId: string, decorId: string?): string?
	local placed = h.placed[ctx]
	if placed == nil then
		placed = {}
		h.placed[ctx] = placed
	end
	local movedFrom: string? = nil
	if decorId ~= nil then
		for sid, did in placed do
			if did == decorId and sid ~= slotId then
				movedFrom = sid
			end
		end
		if movedFrom then
			placed[movedFrom] = nil
		end
	end
	if decorId ~= nil then
		placed[slotId] = decorId
	else
		placed[slotId] = nil
	end
	return movedFrom
end

function Housing.checkTheme(ctx: string, themeId: string?, passes: { [string]: any }?): (boolean, string?)
	local context = Decor.CONTEXTS[ctx]
	if context == nil then
		return false, "no_context"
	end
	if not context.themed then
		return false, "not_themed"
	end
	local theme = Decor.theme(themeId)
	if theme == nil then
		return false, "bad_theme"
	end
	if theme.pass then
		local p = passes or {}
		if not p[theme.pass] then
			return false, "pass"
		end
	end
	return true, nil
end

function Housing.setTheme(h: HousingData, ctx: string, themeId: string)
	if themeId == Decor.DEFAULT_THEME then
		h.theme[ctx] = nil
	else
		h.theme[ctx] = themeId
	end
end

-- The theme to draw. A pass theme whose pass is gone (refund, test account) falls back to the house style.
function Housing.themeOf(h: HousingData, ctx: string, passes: { [string]: any }?): Decor.Theme
	local fallback = Decor.theme(Decor.DEFAULT_THEME) :: Decor.Theme
	local context = Decor.CONTEXTS[ctx]
	if context == nil or not context.themed then
		return fallback
	end
	local theme = Decor.theme(h.theme[ctx])
	if theme == nil then
		return fallback
	end
	if theme.pass and passes ~= nil and not passes[theme.pass] then
		return fallback
	end
	return theme
end

-- Placed items to draw in a live context: owned, still matching their slot's kind and allowed there. Items over the
-- budget (a template with fewer slots, a budget change) are dropped from the end of the slot order.
function Housing.visible(
	h: HousingData,
	ctx: string,
	slots: { Slot },
	rank: number?,
	partsFor: ((propId: string) -> number)?
): { [string]: Decor.Item }
	local out: { [string]: Decor.Item } = {}
	local placed = h.placed[ctx]
	local context = Decor.CONTEXTS[ctx]
	if placed == nil or context == nil then
		return out
	end
	local r = if finite(rank) then rank :: number else 0
	local used = 0
	for _, slot in slots do
		local id = placed[slot.id]
		local item = if id then Decor.get(id) else nil
		if
			item
			and h.owned[item.id]
			and slot.kind ~= Decor.PLAQUE
			and Housing.accepts(slot.kind, item)
			and Decor.allowedIn(item, ctx)
			and not (item.minRank and r < item.minRank)
		then
			local cost = if partsFor then partsFor(item.prop) else 0
			if used + cost <= context.budget then
				used += cost
				out[slot.id] = item
			end
		end
	end
	return out
end

return Housing
