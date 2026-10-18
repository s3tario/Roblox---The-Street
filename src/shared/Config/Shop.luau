--!strict
-- Shops, economy numbers and player-facing text for the cash economy, the shops and housing (owned by `shop`;
-- contracts §7, spec §11, v3 §5 and §13). Pure data plus small helpers: safe on the server, the client and in Lune.
--
--   Shop.shops = { ShopDef }          Shop.get(shopId) -> ShopDef?      Shop.ORDER = { shopId }
--   ShopDef = { id, name, short, tagline, kind = "wearable" | "decor", theme?, rules? = { Rule }, tabs = { Tab } }
--       Rule = { category, slots? }   a wearable is sold here when one rule matches its category (and slot)
--       Tab  = { id, label, slots? | categories? }   how the shop screen groups its stock
--   The `shop` interact (Config/World.interactIds.shop) carries attribute Shop = one of these ids.
--
--   Shop.economy   the numbers EconomyService uses (multiplier clamps, per-call caps, the income kinds)
--   Shop.strings / Shop.text(key, vars?)   every player-facing string ("{name}" placeholders)

local Shop = {}

export type Rule = { category: string, slots: { string }? }
export type Tab = { id: string, label: string, slots: { string }?, categories: { string }? }
export type ShopDef = {
	id: string,
	name: string,
	short: string,
	tagline: string,
	kind: string,
	rules: { Rule }?,
	tabs: { Tab },
}

Shop.shops = {
	{
		id = "tailor",
		name = "Hartwell Tailors",
		short = "Tailor",
		tagline = "Suits, shirts and ties for every rung of the ladder.",
		kind = "wearable",
		rules = {
			{ category = "suits" },
			{ category = "business" },
			{ category = "womens", slots = { "top", "bottom" } },
			{ category = "luxury" },
			{ category = "accessories", slots = { "neck", "head" } },
			{ category = "premium", slots = { "outer", "bottom", "neck", "top" } },
		},
		tabs = {
			{ id = "jackets", label = "Jackets", slots = { "outer" } },
			{ id = "shirts", label = "Shirts", slots = { "top" } },
			{ id = "trousers", label = "Trousers", slots = { "bottom" } },
			{ id = "ties", label = "Ties & Hats", slots = { "neck", "head" } },
		},
	},
	{
		id = "watch",
		name = "Vanta Watches & Eyewear",
		short = "Watches",
		tagline = "The status ladder, one wrist at a time.",
		kind = "wearable",
		rules = {
			{ category = "watches" },
			{ category = "accessories", slots = { "eyes" } },
			{ category = "premium", slots = { "wrist", "eyes" } },
		},
		tabs = {
			{ id = "watches", label = "Watches", slots = { "wrist" } },
			{ id = "eyewear", label = "Eyewear", slots = { "eyes" } },
		},
	},
	{
		id = "shoes",
		name = "Strider Shoes & Leather",
		short = "Shoes",
		tagline = "Oxfords, loafers and leather goods.",
		kind = "wearable",
		rules = {
			{ category = "shoes" },
			{ category = "business", slots = { "shoes" } },
			{ category = "womens", slots = { "shoes" } },
			{ category = "accessories", slots = { "bag" } },
			{ category = "premium", slots = { "shoes", "bag" } },
		},
		tabs = {
			{ id = "shoes", label = "Shoes", slots = { "shoes" } },
			{ id = "bags", label = "Bags", slots = { "bag" } },
		},
	},
	{
		id = "campus_store",
		name = "Eastbridge Campus Store",
		short = "Campus",
		tagline = "Hoodies, backpacks and everything a student can afford.",
		kind = "wearable",
		rules = {
			{ category = "campus" },
		},
		tabs = {
			{ id = "tops", label = "Tops", slots = { "top", "outer" } },
			{ id = "bottoms", label = "Bottoms", slots = { "bottom" } },
			{ id = "shoes", label = "Shoes", slots = { "shoes" } },
			{ id = "extras", label = "Extras", slots = { "neck", "wrist", "eyes", "head", "bag" } },
		},
	},
	{
		id = "decor",
		name = "Galleria Home & Office",
		short = "Decor",
		tagline = "Desk pieces, art and furniture for your desk, office and home.",
		kind = "decor",
		tabs = {
			{ id = "desk", label = "Desk", categories = { "desk" } },
			{ id = "art", label = "Art", categories = { "art" } },
			{ id = "furniture", label = "Furniture", categories = { "furniture" } },
			{ id = "plants", label = "Plants & Lamps", categories = { "plants", "lighting" } },
			{ id = "rugs", label = "Rugs", categories = { "rugs" } },
			{ id = "campus", label = "Dorm", categories = { "campus" } },
		},
	},
} :: { ShopDef }

Shop.ORDER = {} :: { string }
local byId: { [string]: ShopDef } = {}
for _, s in Shop.shops do
	assert(byId[s.id] == nil, "Shop: duplicate shop id " .. s.id)
	byId[s.id] = s
	table.insert(Shop.ORDER, s.id)
end

function Shop.get(id: any): ShopDef?
	if type(id) ~= "string" then
		return nil
	end
	return byId[id]
end

-- The shop a student lands in first (campus) and everyone else (tailor).
Shop.DEFAULT_STUDENT = "campus_store"
Shop.DEFAULT = "tailor"

---------------------------------------------------------------------------------------------------
-- Economy (EconomyService)
---------------------------------------------------------------------------------------------------
-- Income kinds. salary/bonus get every multiplier (contracts §7); reward gets the rebirth income multiplier only;
-- refund and admin are credited exactly.
export type KindRule = { event: boolean, daily: boolean, income: boolean }
Shop.economy = {
	maxCredit = 50000000, -- most cash one AddCash call may credit (after multipliers)
	maxSpend = 50000000, -- largest single SpendCash
	maxLiving = 1000000, -- largest single living charge
	recent = 12, -- wallet.recent ring (newest last)
	defaultKind = "reward",
	kinds = {
		salary = { event = true, daily = true, income = true },
		bonus = { event = true, daily = true, income = true },
		reward = { event = false, daily = false, income = true },
		refund = { event = false, daily = false, income = false },
		admin = { event = false, daily = false, income = false },
	} :: { [string]: KindRule },
	-- multiplier sanity clamps (a buggy event or boost never prints money)
	eventMult = { 0, 5 },
	dailyMult = { 1, 5 },
	incomeMult = { 1, 3 },
	-- EventService:GetModifier("shopDiscount") is the fraction off (Fashion Week = 0.25); anything outside
	-- (0, maxDiscount] is ignored or capped.
	maxDiscount = 0.5,
	-- audit every credit at least this large (plus every non-salary credit)
	auditAbove = 100000,
	-- a purchase asks DataService for an early save at most this often (seconds)
	saveEvery = 90,
	saveAbove = 5000, -- only for purchases at least this large
}

-- Students see this outfit level as the target ("Banks on the Street expect Level 3").
Shop.STUDENT_TARGET_LEVEL = 3

---------------------------------------------------------------------------------------------------
-- Strings
---------------------------------------------------------------------------------------------------
Shop.strings = {
	-- shop screen
	menu_shop = "Shop",
	menu_home = "Home",
	shop_title = "Shops",
	shop_subtitle = "Cash only. Every piece is yours to keep.",
	cash = "{cash}",
	cash_label = "Cash",
	sale_badge = "Sale -{pct}%",
	sale_hint = "{event}: everything {pct}% off",
	sale_event = "Fashion Week",
	dress_firm = "Your firm requires Level {level}",
	dress_firm_ok = "Your firm requires Level {level}. You're dressed for it.",
	dress_firm_short = "Your firm requires Level {level}. You're Level {current}.",
	dress_student = "Banks on the Street expect Level {level} or higher. You're Level {current}.",
	level_badge = "Lv {level}",
	level_meets = "Meets your firm's Level {level}",
	level_below = "Below your firm's Level {level}",
	owned = "Owned",
	wearing = "Wearing",
	requires_rank = "Requires {title}",
	requires_pass = "{pass}",
	pass_corner_office = "Corner Office Collection",
	pass_executive_club = "Executive Club",
	pass_office_themes = "Office Theme Pass",
	pass_generic = "Game pass",
	pass_hint = "Included with the {pass}. Find it at the Store.",
	buy = "Buy",
	buy_price = "Buy · {price}",
	buy_confirm_title = "Buy {name}?",
	buy_confirm_body = "{price} from your cash ({cash} left after).",
	buy_confirm_yes = "Buy it",
	buy_short = "Short {missing}",
	bought = "Bought {name} for {price}.",
	bought_decor = "Bought {name}. Place it from Home.",
	wear_now = "Wear it",
	worn = "Wearing it now.",
	place_now = "Place it",
	open_store = "Open Store",
	empty_tab = "Nothing here yet.",
	preview_hint = "Drag to turn",
	select_hint = "Tap an item to preview it.",
	price_was = "was {price}",
	free = "Free",
	busy = "One moment...",
	sold_in = "Sold at {shop}",
	decor_fits = "Fits: {kinds}",
	decor_where = "Use in: {contexts}",
	decor_everywhere = "Anywhere you live or work",

	-- prompts and toasts
	prompt_shop = "Shop",
	prompt_housing = "Customize",
	employees_only = "Employees only. This desk belongs to the firm's staff.",
	not_yours = "This belongs to {name}.",
	not_yours_free = "This one's free. Yours is {where}.",
	not_yours_none = "You don't have a place here yet.",
	assigned_desk = "Your desk: {where}",
	assigned_office = "Your office: {where}",
	assigned_unit = "Your {kind}: {where}",
	where_desk = "Desk {n}",
	where_office = "Office {n}",
	where_unit = "Unit {n}",
	where_room = "Room {n}",
	office_full = "Every private office on your floor is taken, so you keep a desk for now.",
	desk_full = "Your floor is full. Your desk frees up when someone leaves.",
	your_desk = "Your desk",
	your_office = "Your office",
	your_room = "Your room",
	your_apartment = "Your apartment",

	-- housing screen
	housing_title = "Home",
	housing_subtitle = "Decorate your desk, office and place to live.",
	housing_none = "You don't have a place to decorate yet.",
	housing_not_live = "Head to {where} to customize it.",
	housing_floor = "your floor",
	housing_slots = "Spots",
	housing_theme = "Room theme",
	housing_theme_locked = "Office Theme Pass",
	housing_budget = "Detail {used} / {budget}",
	housing_empty_slot = "Empty",
	housing_change = "Change",
	housing_remove = "Remove",
	housing_pick_title = "Pick for {slot}",
	housing_pick_none = "You don't own anything that fits here yet.",
	housing_shop_decor = "Shop decor",
	housing_plaques = "Deal plaques: {shown} on display of {total}",
	housing_plaques_none = "Close a big deal to earn your first lucite deal plaque.",
	housing_nameplate = "{name} · {title}",
	housing_saved = "Placed {name}.",
	housing_removed = "Cleared the spot.",
	housing_theme_set = "Theme set to {name}.",

	-- errors (keys after "err_"); the Wardrobe screen reads the same Shop.Buy keys
	err_unknown_item = "That item doesn't exist.",
	err_not_for_sale = "That piece isn't sold in the shops.",
	err_owned = "You already own that.",
	err_rank = "Your career rank is too low for that.",
	err_pass = "That comes with a game pass.",
	err_funds = "Not enough cash for that yet.",
	err_not_loaded = "Your save is still loading.",
	err_shop = "Couldn't buy that. Please try again.",
	err_bad_shop = "That shop doesn't sell it.",
	err_grant = "Couldn't deliver that item. You were not charged.",
	err_not_owned = "You don't own that yet.",
	err_bad_slot = "That spot isn't here.",
	err_wrong_kind = "That doesn't fit in this spot.",
	err_context = "That doesn't belong here.",
	err_too_big = "That's too big for this spot.",
	err_budget = "This space is full. Clear a spot first.",
	err_no_context = "You don't have that place right now.",
	err_not_live = "Head there first, then customize it.",
	err_bad_theme = "That theme doesn't exist.",
	err_not_themed = "Themes don't apply here.",
	err_timeout = "The server took too long to answer.",
	err_rate_limited = "Slow down a little.",
	err_generic = "Something went wrong. Please try again.",
} :: { [string]: string }

function Shop.text(key: string, vars: { [string]: any }?): string
	local s = Shop.strings[key]
	if s == nil then
		return key
	end
	if vars then
		s = (string.gsub(s, "{(%w+)}", function(k)
			local v = vars[k]
			return if v ~= nil then tostring(v) else "{" .. k .. "}"
		end))
	end
	return s
end

-- Player-facing text for an error key (falls back to the generic message).
function Shop.errorText(err: string?): string
	local key = "err_" .. (err or "generic")
	return Shop.strings[key] or Shop.strings.err_generic
end

-- Display names of game passes items or themes need.
Shop.PASS_NAMES = {
	CornerOffice = "pass_corner_office",
	ExecutiveClub = "pass_executive_club",
	OfficeThemes = "pass_office_themes",
} :: { [string]: string }

function Shop.passName(passKey: any): string
	local key = if type(passKey) == "string" then Shop.PASS_NAMES[passKey] else nil
	return Shop.text(key or "pass_generic")
end

return Shop
