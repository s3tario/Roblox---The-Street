--!strict
-- Housing screen view model (PURE: no services, no Instances; unit-tested in tests/shop/view.spec.luau). The server's
-- Housing.Get view says which contexts the player holds and which decor spots each has; the replicated `housing`
-- key says what is owned and placed. Placement rules come from Logic/Economy/Housing, like the server's.
--
--   HousingView.contexts(view) -> { ContextView }          the tabs, in Config/Decor.CONTEXT_ORDER
--   HousingView.rows(ctx, housing) -> { Row }              one row per decor spot (kind label, what stands there)
--   HousingView.candidates(ctxId, slotKind, housing, rank) -> { Decor.Item }   owned pieces that fit that spot
--   HousingView.themes(ctx, passes) -> { ThemeRow }        room themes with locked / selected flags
--   HousingView.status(ctx) -> string                      "Desk 5" or "Head to your floor to customize it."
--   HousingView.budget(ctx) -> (fraction, text)            "Detail 42 / 90"
--   HousingView.plaqueLine(ctx, total) -> string?          desk / office deal plaque summary

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Shop = require(Shared.Config.Shop)
local Decor = require(Shared.Config.Decor)
local Housing = require(Shared.Logic.Economy.Housing)

local HousingView = {}

export type SlotView = { id: string, kind: string }
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
	slots: { SlotView },
	plaqueSlots: number,
	plaquesShown: number,
}
export type Row = {
	slotId: string,
	kind: string,
	label: string,
	item: Decor.Item?,
	text: string,
}
export type ThemeRow = { id: string, name: string, desc: string, locked: boolean, selected: boolean }

local function num(x: any, default: number): number
	return if type(x) == "number" and x == x then x else default
end

function HousingView.contexts(view: any): { ContextView }
	local out: { ContextView } = {}
	if type(view) ~= "table" or type(view.contexts) ~= "table" then
		return out
	end
	local byId: { [string]: ContextView } = {}
	for _, raw in view.contexts do
		if type(raw) == "table" and type(raw.id) == "string" and Decor.CONTEXTS[raw.id] then
			local def = Decor.CONTEXTS[raw.id]
			local slots: { SlotView } = {}
			if type(raw.slots) == "table" then
				for _, s in raw.slots do
					if type(s) == "table" and type(s.id) == "string" and type(s.kind) == "string" then
						table.insert(slots, { id = s.id, kind = s.kind })
					end
				end
			end
			byId[raw.id] = {
				id = raw.id,
				label = if type(raw.label) == "string" then raw.label else def.label,
				title = if type(raw.title) == "string" then raw.title else def.title,
				held = raw.held == true,
				live = raw.live == true,
				where = if type(raw.where) == "string" then raw.where else nil,
				themed = def.themed,
				theme = if type(raw.theme) == "string" then raw.theme else Decor.DEFAULT_THEME,
				budget = num(raw.budget, def.budget),
				used = num(raw.used, 0),
				slots = slots,
				plaqueSlots = num(raw.plaqueSlots, 0),
				plaquesShown = num(raw.plaquesShown, 0),
			}
		end
	end
	for _, id in Decor.CONTEXT_ORDER do
		local c = byId[id]
		if c then
			table.insert(out, c)
		end
	end
	return out
end

function HousingView.rows(ctx: ContextView, housing: any): { Row }
	local placed: { [string]: any } = {}
	if type(housing) == "table" and type(housing.placed) == "table" and type(housing.placed[ctx.id]) == "table" then
		placed = housing.placed[ctx.id]
	end
	local counts: { [string]: number } = {}
	local out: { Row } = {}
	for _, slot in ctx.slots do
		counts[slot.kind] = (counts[slot.kind] or 0) + 1
		local item = Decor.get(placed[slot.id])
		table.insert(out, {
			slotId = slot.id,
			kind = slot.kind,
			label = (Decor.KIND_LABELS[slot.kind] or slot.kind) .. " " .. counts[slot.kind],
			item = item,
			text = if item then item.name else Shop.text("housing_empty_slot"),
		})
	end
	return out
end

local CATEGORY_ORDER: { [string]: number } = {}
for i, c in Decor.CATEGORIES do
	CATEGORY_ORDER[c.id] = i
end

function HousingView.candidates(ctxId: string, slotKind: string, housing: any, rank: number?): { Decor.Item }
	local owned: { [string]: any } = {}
	if type(housing) == "table" and type(housing.owned) == "table" then
		owned = housing.owned
	end
	local r = num(rank, 0)
	local out: { Decor.Item } = {}
	for _, item in Decor.list() do
		if
			owned[item.id]
			and Housing.accepts(slotKind, item)
			and Decor.allowedIn(item, ctxId)
			and not (item.minRank and r < item.minRank)
		then
			table.insert(out, item)
		end
	end
	table.sort(out, function(a, b)
		local ca, cb = CATEGORY_ORDER[a.category] or 99, CATEGORY_ORDER[b.category] or 99
		if ca ~= cb then
			return ca < cb
		end
		if a.price ~= b.price then
			return a.price < b.price
		end
		return a.id < b.id
	end)
	return out
end

function HousingView.themes(ctx: ContextView, passes: { [string]: any }?): { ThemeRow }
	local out: { ThemeRow } = {}
	if not ctx.themed then
		return out
	end
	local p = passes or {}
	for _, th in Decor.themes do
		table.insert(out, {
			id = th.id,
			name = th.name,
			desc = th.desc,
			locked = th.pass ~= nil and not p[th.pass],
			selected = th.id == ctx.theme,
		})
	end
	return out
end

function HousingView.status(ctx: ContextView): string
	if ctx.held and ctx.live then
		return ctx.where or ctx.title
	end
	if ctx.held then
		return Shop.text("housing_not_live", { where = ctx.where or Shop.text("housing_floor") })
	end
	return Shop.text("housing_not_live", { where = Shop.text("housing_floor") })
end

function HousingView.budget(ctx: ContextView): (number, string)
	local b = math.max(1, ctx.budget)
	return math.clamp(ctx.used / b, 0, 1), Shop.text("housing_budget", { used = ctx.used, budget = ctx.budget })
end

function HousingView.plaqueLine(ctx: ContextView, total: number?): string?
	if ctx.plaqueSlots <= 0 then
		return nil
	end
	local t = num(total, 0)
	if t <= 0 then
		return Shop.text("housing_plaques_none")
	end
	return Shop.text("housing_plaques", { shown = ctx.plaquesShown, total = t })
end

return HousingView
