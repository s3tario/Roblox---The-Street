--!strict
-- Catalog/Rolls: Rare Life Roll brands (Ralph Lorenzo, Brooks Brethren, Vineyard Wines, Patagonio). Item and look definitions only; Rolls/init.luau fills in the roll fields
-- (currency "roll", category, price 0, the level from the rarity) and Catalog/init.luau the rest of the schema.
-- colors.trim is the colour of the brand's signature details (emblems, monograms, pocket squares).

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

brand("ralph_lorenzo", "rare", {
	{
		id = "rl_polo_green",
		name = "Ralph Lorenzo Polo, Hunter Green",
		slot = "top",
		builder = "polo",
		details = { "emblem_pony" },
		colors = c("#24513A", "#1C412E", "#D9C38A", "#D9C38A"),
		desc = "Hunter-green mesh polo with the gold polo-player emblem.",
	},
	{
		id = "rl_cable_cream",
		name = "Ralph Lorenzo Cable-Knit Sweater",
		slot = "top",
		builder = "sweater",
		details = { "cable", "emblem_pony" },
		colors = c("#E8E0CB", "#D8CFB7", "#D8CFB7", "#1F2A4A"),
		desc = "Cream cotton cable knit with a navy emblem.",
	},
	{
		id = "rl_chinos_khaki",
		name = "Ralph Lorenzo Classic Chinos",
		slot = "bottom",
		builder = "chinos",
		colors = c("#B8A47E", "#5A3A26", "#B8933F"),
		desc = "Straight khaki twill on a bridle-leather belt.",
	},
	{
		id = "rl_trousers_navy",
		name = "Ralph Lorenzo Wool Trousers, Navy",
		slot = "bottom",
		builder = "trousers",
		colors = c("#1D2742", "#3A2418", "#C9A54C"),
		desc = "Pleated navy wool trousers.",
	},
	{
		id = "rl_loafer_cordovan",
		name = "Ralph Lorenzo Cordovan Loafers",
		slot = "shoes",
		builder = "loafer",
		colors = c("#5A1F22", "#2A1012", "#7A2A2E"),
		desc = "Burgundy shell-cordovan penny loafers.",
	},
})
look(
	"rl_polo_club",
	"ralph_lorenzo",
	"Ralph Lorenzo Polo Club",
	{ "rl_polo_green", "rl_chinos_khaki", "rl_loafer_cordovan" }
)
look(
	"rl_cable_knit",
	"ralph_lorenzo",
	"Ralph Lorenzo Cable Knit",
	{ "rl_cable_cream", "rl_trousers_navy", "rl_loafer_cordovan" }
)

brand("brooks_brethren", "rare", {
	{
		id = "bb_ocbd_blue",
		name = "Brooks Brethren Button-Down Oxford",
		slot = "top",
		builder = "shirt",
		details = { "buttondown" },
		colors = c("#B5CBE4", "#A3BAD6", "#F4F4F0"),
		desc = "The original button-down in blue oxford cloth.",
	},
	{
		id = "bb_repp_tie",
		name = "Brooks Brethren Repp Tie",
		slot = "neck",
		builder = "tie",
		pattern = "stripe",
		colors = c("#1E2A4A", "#172039", "#A32A2E"),
		desc = "Navy silk repp with claret stripes.",
	},
	{
		id = "bb_sack_blazer",
		name = "Brooks Brethren Sack Blazer",
		slot = "outer",
		builder = "blazer",
		colors = c("#1F2B47", "#18213A", "#C9A54C"),
		desc = "Natural-shoulder navy blazer with brass buttons.",
	},
	{
		id = "bb_flannel_grey",
		name = "Brooks Brethren Flannel Trousers",
		slot = "bottom",
		builder = "trousers",
		colors = c("#73767C", "#2A1E16", "#C0C4C8"),
		desc = "Mid-grey worsted flannel with turn-ups.",
	},
	{
		id = "bb_penny_brown",
		name = "Brooks Brethren Penny Loafers",
		slot = "shoes",
		builder = "loafer",
		colors = c("#4A2C1A", "#24160C", "#3A2414"),
		desc = "Dark brown calf penny loafers.",
	},
})
look(
	"bb_traditional",
	"brooks_brethren",
	"Brooks Brethren Traditional",
	{ "bb_ocbd_blue", "bb_sack_blazer", "bb_flannel_grey", "bb_penny_brown", "bb_repp_tie" }
)

brand("vineyard_wines", "rare", {
	{
		id = "vw_qzip_pink",
		name = "Vineyard Wines Quarter-Zip, Pastel Pink",
		slot = "top",
		builder = "quarterzip",
		details = { "emblem_whale" },
		colors = c("#F0B9C6", "#E2A6B4", "#C0C4C8", "#1F2A4A"),
		desc = "Pastel pink pullover with the navy whale.",
	},
	{
		id = "vw_chinos_stone",
		name = "Vineyard Wines Breaker Chinos",
		slot = "bottom",
		builder = "chinos",
		colors = c("#D3C7A8", "#1F2A4A", "#C0C4C8"),
		desc = "Pale stone chinos on a navy belt.",
	},
	{
		id = "vw_boat_brown",
		name = "Vineyard Wines Boat Shoes",
		slot = "shoes",
		builder = "loafer",
		style = "boat",
		colors = c("#7A4E2E", "#F1EEE6", "#C9B79A"),
		desc = "Hand-sewn moc boat shoes on white soles.",
	},
})
look(
	"vw_island",
	"vineyard_wines",
	"Vineyard Wines Island Weekend",
	{ "vw_qzip_pink", "vw_chinos_stone", "vw_boat_brown" }
)

brand("patagonio", "rare", {
	{
		id = "pt_shirt_blue",
		name = "Patagonio Oxford Shirt, Blue",
		slot = "top",
		builder = "shirt",
		details = { "buttondown" },
		colors = c("#BCD0E6", "#AAC0D9", "#F4F4F0"),
		desc = "Blue button-down. The vest's best friend.",
	},
	{
		id = "pt_vest_fleece",
		name = "Patagonio Fleece Vest",
		slot = "outer",
		builder = "vest",
		style = "fleece",
		details = { "emblem_peak" },
		colors = c("#2C3340", "#222833", "#B8BCC2", "#E07B39"),
		desc = "The Midtown uniform: a zip fleece vest with the peak patch.",
	},
	{
		id = "pt_chinos_grey",
		name = "Patagonio Stretch Chinos, Grey",
		slot = "bottom",
		builder = "chinos",
		colors = c("#6E6F70", "#2A2B2E", "#8E9397"),
		desc = "Grey stretch chinos that survive a bike commute.",
	},
	{
		id = "pt_sneaker_trail",
		name = "Patagonio Trail Sneakers",
		slot = "shoes",
		builder = "sneaker",
		colors = c("#5B5F66", "#2A2B2E", "#E07B39"),
		desc = "Grey trail runners with orange accents.",
	},
})
look(
	"pt_midtown",
	"patagonio",
	"Patagonio Midtown Uniform",
	{ "pt_shirt_blue", "pt_vest_fleece", "pt_chinos_grey", "pt_sneaker_trail" }
)

brand("patagonio", "rare", {
	{
		id = "pt_qzip_snap",
		name = "Patagonio Snap Fleece Pullover",
		slot = "top",
		builder = "quarterzip",
		details = { "emblem_peak" },
		colors = c("#3E5A4C", "#33493E", "#C9B79A", "#E07B39"),
		desc = "Forest-green pile fleece with a zip collar and the peak patch.",
	},
	{
		id = "pt_jeans_rinse",
		name = "Patagonio Organic Rinse Jeans",
		slot = "bottom",
		builder = "jeans",
		colors = c("#2A3A58", "#3B2A1E", "#C98A3B"),
		desc = "Organic-cotton rinse denim, built to be repaired.",
	},
})
look("pt_basecamp", "patagonio", "Patagonio Basecamp", { "pt_qzip_snap", "pt_jeans_rinse", "pt_sneaker_trail" })

return { items = items, looks = looks }
