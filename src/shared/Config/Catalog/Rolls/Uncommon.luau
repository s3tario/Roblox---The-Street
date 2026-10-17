--!strict
-- Catalog/Rolls: Uncommon Life Roll brands (J. Crewson, Plantain Republic, Tommy Hillford). Item and look definitions only; Rolls/init.luau fills in the roll fields
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

brand("j_crewson", "uncommon", {
	{
		id = "jc_oxford_pink",
		name = "J. Crewson Oxford, Pink",
		slot = "top",
		builder = "shirt",
		details = { "buttondown" },
		colors = c("#EBC3C8", "#DDB0B6", "#F4F4F0"),
		desc = "Washed pink oxford cloth with a button-down collar.",
	},
	{
		id = "jc_gingham_blue",
		name = "J. Crewson Gingham Shirt",
		slot = "top",
		builder = "shirt",
		details = { "gingham" },
		colors = c("#EEF2F7", "#DCE3EC", "#F4F4F0", "#5C7FB3"),
		desc = "Blue and white gingham poplin.",
	},
	{
		id = "jc_crew_kelly",
		name = "J. Crewson Lambswool Crew, Kelly",
		slot = "top",
		builder = "sweater",
		colors = c("#2F7A4B", "#256139", "#2F7A4B"),
		desc = "Kelly-green lambswool. Bold, but it's prep.",
	},
	{
		id = "jc_blazer_navy",
		name = "J. Crewson Ludlow Blazer",
		slot = "outer",
		builder = "blazer",
		colors = c("#24345A", "#1C2A49", "#C9C5BE"),
		desc = "Slim, soft-shouldered navy wool with patch pockets.",
	},
	{
		id = "jc_chinos_stone",
		name = "J. Crewson Chinos, Stone",
		slot = "bottom",
		builder = "chinos",
		colors = c("#C9BC9E", "#5A3A26", "#C9A54C"),
		desc = "Stone twill chinos with a tan belt.",
	},
	{
		id = "jc_chinos_navy",
		name = "J. Crewson Chinos, Navy",
		slot = "bottom",
		builder = "chinos",
		colors = c("#283553", "#3B2418", "#B8933F"),
		desc = "Navy chinos with turn-ups.",
	},
	{
		id = "jc_loafer_suede",
		name = "J. Crewson Suede Loafers, Tan",
		slot = "shoes",
		builder = "loafer",
		finish = "suede",
		colors = c("#A0764E", "#3B2A1E", "#7A5638"),
		desc = "Unlined tan suede penny loafers.",
	},
})
look("jc_weekday", "j_crewson", "J. Crewson Weekday", { "jc_oxford_pink", "jc_chinos_stone", "jc_loafer_suede" })
look("jc_campus", "j_crewson", "J. Crewson Campus", { "jc_crew_kelly", "jc_chinos_navy", "jc_loafer_suede" })
look(
	"jc_ludlow",
	"j_crewson",
	"J. Crewson Ludlow",
	{ "jc_gingham_blue", "jc_blazer_navy", "jc_chinos_stone", "jc_loafer_suede" }
)

brand("plantain_republic", "uncommon", {
	{
		id = "pr_tee_ecru",
		name = "Plantain Republic Supima Tee, Ecru",
		slot = "top",
		builder = "tee",
		colors = c("#E6DFCC", "#D5CDB7"),
		desc = "Long-staple cotton in a warm ecru.",
	},
	{
		id = "pr_utility_olive",
		name = "Plantain Republic Utility Overshirt",
		slot = "outer",
		builder = "overshirt",
		colors = c("#5C6142", "#4A4F34", "#2B2B2B"),
		desc = "Olive cotton-twill overshirt with flap pockets.",
	},
	{
		id = "pr_qzip_grey",
		name = "Plantain Republic Merino Quarter-Zip",
		slot = "top",
		builder = "quarterzip",
		colors = c("#6F7379", "#5A5E64", "#C0C4C8"),
		desc = "Fine-gauge grey merino for the train in.",
	},
	{
		id = "pr_chinos_khaki",
		name = "Plantain Republic Slim Chinos",
		slot = "bottom",
		builder = "chinos",
		colors = c("#B19A6E", "#4A3424", "#B8933F"),
		desc = "Slim stretch-twill khakis.",
	},
	{
		id = "pr_trousers_navy",
		name = "Plantain Republic Commuter Trousers",
		slot = "bottom",
		builder = "trousers",
		colors = c("#222E4A", "#2A1E16", "#C0C4C8"),
		desc = "Wrinkle-shy navy trousers with a sharp crease.",
	},
	{
		id = "pr_derby_brown",
		name = "Plantain Republic Derbies, Walnut",
		slot = "shoes",
		builder = "oxford",
		style = "derby",
		colors = c("#5A3A24", "#2A1A10", "#3B2618"),
		desc = "Walnut leather derbies.",
	},
})
look(
	"pr_safari",
	"plantain_republic",
	"Plantain Republic Safari",
	{ "pr_tee_ecru", "pr_utility_olive", "pr_chinos_khaki", "pr_derby_brown" }
)
look(
	"pr_commute",
	"plantain_republic",
	"Plantain Republic Commute",
	{ "pr_qzip_grey", "pr_trousers_navy", "pr_derby_brown" }
)

brand("tommy_hillford", "uncommon", {
	{
		id = "th_polo_white",
		name = "Tommy Hillford Flag Polo, White",
		slot = "top",
		builder = "polo",
		details = { "emblem_flag", "tipping" },
		colors = c("#F3F3EF", "#E3E3DE", "#1F2A4A", "#1F2A4A"),
		desc = "White pique with navy tipping and the flag emblem.",
	},
	{
		id = "th_polo_stripe",
		name = "Tommy Hillford Rugby-Stripe Polo",
		slot = "top",
		builder = "polo",
		details = { "rugby_stripes", "emblem_flag" },
		colors = c("#1F2A4A", "#F1F0EB", "#B22234", "#F1F0EB"),
		desc = "Navy and white hoops with the flag emblem.",
	},
	{
		id = "th_chinos_navy",
		name = "Tommy Hillford Chinos, Navy",
		slot = "bottom",
		builder = "chinos",
		colors = c("#1E2946", "#8E1F26", "#C0C4C8"),
		desc = "Navy chinos on a red webbing belt.",
	},
	{
		id = "th_jeans",
		name = "Tommy Hillford Straight Jeans",
		slot = "bottom",
		builder = "jeans",
		colors = c("#2E4166", "#3B2A1E", "#C98A3B"),
		desc = "Classic straight-leg indigo.",
	},
	{
		id = "th_sneaker_flag",
		name = "Tommy Hillford Court Sneakers",
		slot = "shoes",
		builder = "sneaker",
		colors = c("#F4F4F0", "#FFFFFF", "#B22234"),
		desc = "White leather with a red heel tab.",
	},
})
look("th_prep", "tommy_hillford", "Tommy Hillford Prep", { "th_polo_white", "th_chinos_navy", "th_sneaker_flag" })
look("th_stripe", "tommy_hillford", "Tommy Hillford Stripes", { "th_polo_stripe", "th_jeans", "th_sneaker_flag" })
brand("tommy_hillford", "uncommon", {
	{
		id = "th_qzip_navy",
		name = "Tommy Hillford Flag Quarter-Zip",
		slot = "top",
		builder = "quarterzip",
		details = { "emblem_flag" },
		colors = c("#1F2A4A", "#18213A", "#C0C4C8", "#F1F0EB"),
		desc = "Navy cotton quarter-zip with the flag emblem.",
	},
	{
		id = "th_chinos_stone",
		name = "Tommy Hillford Chinos, Stone",
		slot = "bottom",
		builder = "chinos",
		colors = c("#CDBF9F", "#1F2A4A", "#C0C4C8"),
		desc = "Stone chinos on a navy webbing belt.",
	},
	{
		id = "th_boat_shoe",
		name = "Tommy Hillford Boat Shoes",
		slot = "shoes",
		builder = "loafer",
		style = "boat",
		colors = c("#2A3552", "#F1EEE6", "#B22234"),
		desc = "Navy leather boat shoes with red laces.",
	},
})
look("th_harbour", "tommy_hillford", "Tommy Hillford Harbour", { "th_qzip_navy", "th_chinos_stone", "th_boat_shoe" })

return { items = items, looks = looks }
