--!strict
-- Catalog/Rolls: Epic Life Roll brands (Briani, Canalé; v3 §1). Item and look definitions only; Rolls/init.luau
-- fills in the roll fields (currency "roll", category, price 0, the level from the rarity) and Catalog/init.luau
-- the rest of the schema. colors.trim is the colour of the brand's signature details.
--   Briani   Roman hand tailoring: pick-stitched lapel edges (detail "pick_stitch"), horn buttons
--   Canalé   soft Milanese suiting: the gold crescent "C" pin at the lapel (detail "crest_c")

local function c(primary: string, secondary: string?, accent: string?, trim: string?): { [string]: string? }
	return { primary = primary, secondary = secondary, accent = accent, trim = trim }
end

local items: { { [string]: any } } = {}
local looks: { { id: string, brand: string, name: string, itemIds: { string } } } = {}

local function brand(brandId: string, rarity: string, defs: { { [string]: any } })
	for _, d in defs do
		d.brand = brandId
		d.rarity = rarity
		table.insert(items, d)
	end
end

local function look(id: string, brandId: string, name: string, itemIds: { string })
	table.insert(looks, { id = id, brand = brandId, name = name, itemIds = itemIds })
end

---------------------------------------------------------------------------------------------------
-- Briani
---------------------------------------------------------------------------------------------------
brand("briani", "epic", {
	{
		id = "br_jacket_navy",
		name = "Briani Roma Suit Jacket, Navy",
		slot = "outer",
		builder = "jacket",
		style = "two_button",
		details = { "pick_stitch" },
		colors = c("#1C2744", "#162037", "#EDE6D6", "#C9B48A"),
		desc = "Hand-made in Rome: soft shoulders, pick-stitched lapels and a silk-lined barchetta pocket.",
	},
	{
		id = "br_trousers_navy",
		name = "Briani Roma Suit Trousers, Navy",
		slot = "bottom",
		builder = "trousers",
		style = "suit",
		colors = c("#1C2744", "#2A1E16", "#C0C4C8"),
		desc = "Matching navy trousers with side adjusters instead of belt loops.",
	},
	{
		id = "br_jacket_charcoal",
		name = "Briani Sera Double-Breasted Jacket",
		slot = "outer",
		builder = "jacket",
		style = "double_breasted",
		details = { "pick_stitch" },
		colors = c("#2E3036", "#25272C", "#E9E4DA", "#B9A27A"),
		desc = "Charcoal Super 150s double-breasted with horn buttons and hand-picked edges.",
	},
	{
		id = "br_trousers_charcoal",
		name = "Briani Sera Suit Trousers, Charcoal",
		slot = "bottom",
		builder = "trousers",
		style = "suit",
		colors = c("#2E3036", "#1A1512", "#C0C4C8"),
		desc = "Charcoal trousers pressed to a knife crease.",
	},
	{
		id = "br_shirt_white",
		name = "Briani Silk-Cotton Dress Shirt",
		slot = "top",
		builder = "shirt",
		colors = c("#F8F7F3", "#EAE8E2", "#F4F4F0"),
		desc = "A white silk-cotton shirt with mother-of-pearl buttons.",
	},
	{
		id = "br_shirt_lilac",
		name = "Briani End-on-End Shirt, Lilac",
		slot = "top",
		builder = "shirt",
		details = { "buttondown" },
		colors = c("#D9D2E6", "#C8BFD9", "#F4F4F0"),
		desc = "Pale lilac end-on-end cotton with a soft button-down collar.",
	},
	{
		id = "br_tie_sevenfold",
		name = "Briani Seven-Fold Silk Tie",
		slot = "neck",
		builder = "tie",
		style = "satin",
		colors = c("#5B1E2D", "#461623", "#7A2A3C"),
		desc = "Unlined seven-fold silk in deep garnet.",
	},
	{
		id = "br_oxford_black",
		name = "Briani Calf Oxfords",
		slot = "shoes",
		builder = "oxford",
		colors = c("#141313", "#0C0B0B", "#262424"),
		desc = "Black calf cap-toes on a closed channel sole.",
	},
	{
		id = "br_loafer_velvet",
		name = "Briani Velvet Slippers, Bordeaux",
		slot = "shoes",
		builder = "loafer",
		colors = c("#4A1424", "#2A0C15", "#C9A54C"),
		desc = "Bordeaux velvet evening slippers with gold piping.",
	},
})
look(
	"br_roma",
	"briani",
	"Briani Roma",
	{ "br_shirt_white", "br_jacket_navy", "br_trousers_navy", "br_oxford_black", "br_tie_sevenfold" }
)
look(
	"br_sera",
	"briani",
	"Briani Sera",
	{ "br_shirt_lilac", "br_jacket_charcoal", "br_trousers_charcoal", "br_loafer_velvet" }
)

---------------------------------------------------------------------------------------------------
-- Canalé
---------------------------------------------------------------------------------------------------
brand("canale", "epic", {
	{
		id = "cn_jacket_grey",
		name = "Canalé Milano Suit Jacket, Dove Grey",
		slot = "outer",
		builder = "jacket",
		style = "two_button",
		details = { "crest_c" },
		colors = c("#7C8089", "#6B6F78", "#F1EEE8", "#D4AF37"),
		desc = "Dove-grey wool with a rolled lapel, a crescent breast pocket and the gold C pin.",
	},
	{
		id = "cn_trousers_grey",
		name = "Canalé Milano Suit Trousers, Dove Grey",
		slot = "bottom",
		builder = "trousers",
		style = "suit",
		colors = c("#7C8089", "#3A2A1E", "#C0C4C8"),
		desc = "Dove-grey trousers with a single forward pleat.",
	},
	{
		id = "cn_shirt_sky",
		name = "Canalé Twill Shirt, Sky",
		slot = "top",
		builder = "shirt",
		colors = c("#C9DCF0", "#B7CCE4", "#F4F4F0"),
		desc = "Sky-blue cotton twill with a cutaway collar.",
	},
	{
		id = "cn_tie_knit",
		name = "Canalé Silk Knit Tie, Ink",
		slot = "neck",
		builder = "tie",
		style = "knit",
		colors = c("#1A2338", "#131A2B", "#26314D"),
		desc = "Square-ended ink silk knit.",
	},
	{
		id = "cn_loafer_brown",
		name = "Canalé Penny Loafers, Chestnut",
		slot = "shoes",
		builder = "loafer",
		colors = c("#6A3B22", "#2E190E", "#4E2A18"),
		desc = "Chestnut calf penny loafers, hand-stained.",
	},
	{
		id = "cn_qzip_navy",
		name = "Canalé Cashmere Quarter-Zip, Navy",
		slot = "top",
		builder = "quarterzip",
		colors = c("#1E2840", "#172036", "#D4AF37"),
		desc = "Fine-gauge navy cashmere with a gold zip pull.",
	},
	{
		id = "cn_trousers_flannel",
		name = "Canalé Flannel Trousers, Stone",
		slot = "bottom",
		builder = "trousers",
		colors = c("#B9B2A4", "#4A3424", "#C9A54C"),
		desc = "Stone flannel trousers on a suede belt.",
	},
	{
		id = "cn_loafer_suede",
		name = "Canalé Suede Tassel Loafers, Tobacco",
		slot = "shoes",
		builder = "loafer",
		style = "tassel",
		finish = "suede",
		colors = c("#6B4A30", "#2E1E12", "#8A6644"),
		desc = "Tobacco suede tassel loafers on a leather sole.",
	},
})
look(
	"cn_milano",
	"canale",
	"Canalé Milano",
	{ "cn_shirt_sky", "cn_jacket_grey", "cn_trousers_grey", "cn_loafer_brown", "cn_tie_knit" }
)
look("cn_lago", "canale", "Canalé Lago", { "cn_qzip_navy", "cn_trousers_flannel", "cn_loafer_suede" })

return { items = items, looks = looks }
