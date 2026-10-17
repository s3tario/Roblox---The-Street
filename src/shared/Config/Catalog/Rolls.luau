--!strict
-- Catalog: Life Roll outfits (owner v2, spec §4) and family heirlooms. Item definitions only (see
-- Catalog/init.luau for the schema).
--   items  roll pieces (currency "roll", never sold for cash) and heirlooms (currency "heirloom"); rarity comes
--          from the brand (Brands.luau), tier from the rarity
--   looks  the starting-outfit pool: { id, brand, name, itemIds } with top + bottom + shoes (optionally outer,
--          neck, wrist). Pool sizes: 12 common, 7 uncommon, 5 rare, 3 legendary, exactly 1 mythic.
-- Brand signatures come from the layer builders plus `details` (Assets/Wardrobe/Details.luau); colors.trim is
-- the colour of those details (emblems, monograms, pocket squares).

local function c(primary: string, secondary: string?, accent: string?, trim: string?): { [string]: string? }
	return { primary = primary, secondary = secondary, accent = accent, trim = trim }
end

local TIER = { common = 1, uncommon = 2, rare = 3, legendary = 4, mythic = 5 }

local items: { { [string]: any } } = {}
local looks: { { id: string, brand: string, name: string, itemIds: { string } } } = {}

local function brand(brandId: string, rarity: string, defs: { { [string]: any } })
	for _, d in defs do
		d.brand = brandId
		d.rarity = rarity
		d.tier = d.tier or TIER[rarity]
		d.currency = "roll"
		d.category = "roll"
		d.price = 0
		d.tags = d.tags or { "roll", rarity }
		table.insert(items, d)
	end
end

local function look(id: string, brandId: string, name: string, itemIds: { string })
	table.insert(looks, { id = id, brand = brandId, name = name, itemIds = itemIds })
end

---------------------------------------------------------------------------------------------------
-- Common: Kevin Kroos, Old Harbor, Gapline, Hanesworth
---------------------------------------------------------------------------------------------------
brand("kevin_kroos", "common", {
	{
		id = "kk_tee_black",
		name = "Kevin Kroos Logo Tee, Black",
		slot = "top",
		builder = "tee",
		details = { "wordmark" },
		colors = c("#18191B", "#101112", "#2A2B2E", "#EDEDEA"),
		desc = "Heavy black cotton with the small KK wordmark.",
	},
	{
		id = "kk_crew_charcoal",
		name = "Kevin Kroos Crew Sweater, Charcoal",
		slot = "top",
		builder = "sweater",
		details = { "wordmark" },
		colors = c("#3A3C40", "#2C2E31", "#2C2E31", "#E4E4E0"),
		desc = "Smooth-knit charcoal crew with a tonal wordmark.",
	},
	{
		id = "kk_shirt_black",
		name = "Kevin Kroos Black Poplin Shirt",
		slot = "top",
		builder = "shirt",
		colors = c("#18191B", "#111214", "#2C2D30"),
		desc = "Sharp black poplin, cut slim.",
	},
	{
		id = "kk_jeans_grey",
		name = "Kevin Kroos Slim Jeans, Washed Grey",
		slot = "bottom",
		builder = "jeans",
		colors = c("#5E6066", "#202124", "#9A9CA0"),
		desc = "Washed grey slim denim with tonal stitching.",
	},
	{
		id = "kk_trousers_black",
		name = "Kevin Kroos Slim Trousers, Black",
		slot = "bottom",
		builder = "trousers",
		style = "plain",
		colors = c("#1C1D20", "#121214", "#8E9397"),
		desc = "Flat-front black trousers with no fuss.",
	},
	{
		id = "kk_sneaker_white",
		name = "Kevin Kroos Minimal Sneakers",
		slot = "shoes",
		builder = "sneaker",
		colors = c("#F4F4F1", "#FFFFFF", "#1C1D20"),
		desc = "White leather low-tops with a black heel tab.",
	},
	{
		id = "kk_derby_black",
		name = "Kevin Kroos Black Derbies",
		slot = "shoes",
		builder = "oxford",
		style = "derby",
		colors = c("#18181A", "#0E0E0F", "#2A2A2C"),
		desc = "Plain black derbies on a slim sole.",
	},
})
look("kk_essentials", "kevin_kroos", "Kevin Kroos Essentials", { "kk_tee_black", "kk_jeans_grey", "kk_sneaker_white" })
look(
	"kk_monochrome",
	"kevin_kroos",
	"Kevin Kroos Monochrome",
	{ "kk_crew_charcoal", "kk_trousers_black", "kk_sneaker_white" }
)
look(
	"kk_after_dark",
	"kevin_kroos",
	"Kevin Kroos After Dark",
	{ "kk_shirt_black", "kk_trousers_black", "kk_derby_black" }
)

brand("old_harbor", "common", {
	{
		id = "oh_tee_navy",
		name = "Old Harbor Pocket Tee, Navy",
		slot = "top",
		builder = "tee",
		style = "pocket",
		colors = c("#22325A", "#1A2748"),
		desc = "Soft navy jersey with a chest pocket.",
	},
	{
		id = "oh_hoodie_red",
		name = "Old Harbor Pullover Hoodie, Red",
		slot = "top",
		builder = "hoodie",
		colors = c("#A3302B", "#86251F", "#F1F0EB"),
		desc = "Bright red fleece with white drawstrings.",
	},
	{
		id = "oh_tee_grey",
		name = "Old Harbor Crew Tee, Heather",
		slot = "top",
		builder = "tee",
		colors = c("#9B9EA4", "#878A90"),
		desc = "Heather grey crew neck for layering.",
	},
	{
		id = "oh_flannel_blue",
		name = "Old Harbor Flannel, Blue Plaid",
		slot = "outer",
		builder = "overshirt",
		pattern = "plaid",
		colors = c("#2F4E7A", "#1B2238", "#C7CDD6"),
		desc = "Brushed blue plaid worn open.",
	},
	{
		id = "oh_cargo_khaki",
		name = "Old Harbor Cargo Pants, Khaki",
		slot = "bottom",
		builder = "cargo",
		colors = c("#A8946C", "#3B2A1E", "#8A7A58"),
		desc = "Relaxed khaki cargos with flap pockets.",
	},
	{
		id = "oh_jeans_light",
		name = "Old Harbor Light-Wash Jeans",
		slot = "bottom",
		builder = "jeans",
		colors = c("#7C95B5", "#3B2A1E", "#C98A3B"),
		desc = "Sun-faded straight jeans.",
	},
	{
		id = "oh_canvas_navy",
		name = "Old Harbor Canvas Low-Tops, Navy",
		slot = "shoes",
		builder = "sneaker",
		style = "canvas",
		colors = c("#23314F", "#F1F0EB", "#F1F0EB"),
		desc = "Navy canvas with a white rubber toe.",
	},
})
look("oh_weekend", "old_harbor", "Old Harbor Weekend", { "oh_tee_navy", "oh_cargo_khaki", "oh_canvas_navy" })
look("oh_pullover", "old_harbor", "Old Harbor Pullover", { "oh_hoodie_red", "oh_jeans_light", "oh_canvas_navy" })
look(
	"oh_flannel",
	"old_harbor",
	"Old Harbor Flannel Days",
	{ "oh_tee_grey", "oh_flannel_blue", "oh_jeans_light", "oh_canvas_navy" }
)

brand("gapline", "common", {
	{
		id = "gl_hoodie_navy",
		name = "Gapline Arch Hoodie, Navy",
		slot = "top",
		builder = "hoodie",
		details = { "logo_arch" },
		colors = c("#1F2B4A", "#18223B", "#F1F0EB", "#F1F0EB"),
		desc = "The arch-logo hoodie everybody's older sibling had.",
	},
	{
		id = "gl_tee_white",
		name = "Gapline Essential Tee, White",
		slot = "top",
		builder = "tee",
		colors = c("#F2F1EC", "#DEDDD7"),
		desc = "A clean white tee, washed soft.",
	},
	{
		id = "gl_tee_olive",
		name = "Gapline Pocket Tee, Olive",
		slot = "top",
		builder = "tee",
		style = "pocket",
		colors = c("#5F6440", "#4C5133"),
		desc = "Garment-dyed olive with a patch pocket.",
	},
	{
		id = "gl_denim_jacket",
		name = "Gapline Icon Denim Jacket",
		slot = "outer",
		builder = "overshirt",
		style = "denim",
		colors = c("#6C8BB0", "#56739A", "#C98A3B"),
		desc = "Mid-blue trucker jacket with copper buttons.",
	},
	{
		id = "gl_khakis",
		name = "Gapline Easy Khakis",
		slot = "bottom",
		builder = "chinos",
		colors = c("#BDA982", "#4A3424", "#B8933F"),
		desc = "Relaxed khakis with a brown belt.",
	},
	{
		id = "gl_jeans_mid",
		name = "Gapline Mid-Wash Jeans",
		slot = "bottom",
		builder = "jeans",
		colors = c("#46628A", "#3B2A1E", "#C98A3B"),
		desc = "Everyday mid-wash denim.",
	},
	{
		id = "gl_sneaker_white",
		name = "Gapline Court Sneakers",
		slot = "shoes",
		builder = "sneaker",
		colors = c("#EDECE6", "#FFFFFF", "#8E9397"),
		desc = "White court sneakers with a grey tab.",
	},
})
look("gl_classic", "gapline", "Gapline Classic", { "gl_hoodie_navy", "gl_khakis", "gl_sneaker_white" })
look("gl_denim", "gapline", "Gapline Denim Day", { "gl_tee_white", "gl_denim_jacket", "gl_khakis", "gl_sneaker_white" })
look("gl_pocket", "gapline", "Gapline Pocket Tee", { "gl_tee_olive", "gl_jeans_mid", "gl_sneaker_white" })

brand("hanesworth", "common", {
	{
		id = "hw_tee_heather",
		name = "Hanesworth Heather Tee",
		slot = "top",
		builder = "tee",
		colors = c("#A4A7AC", "#909398"),
		desc = "The softest heather tee in the pack.",
	},
	{
		id = "hw_crew_grey",
		name = "Hanesworth Crew Sweatshirt",
		slot = "top",
		builder = "sweater",
		colors = c("#7E8187", "#6A6D73", "#9A9DA2"),
		desc = "Loopback grey crew sweatshirt.",
	},
	{
		id = "hw_hoodie_black",
		name = "Hanesworth Pullover Hoodie, Black",
		slot = "top",
		builder = "hoodie",
		colors = c("#222326", "#1A1B1D", "#D9D9D4"),
		desc = "Black fleece pullover for late study sessions.",
	},
	{
		id = "hw_joggers_grey",
		name = "Hanesworth Joggers, Grey",
		slot = "bottom",
		builder = "trousers",
		style = "jogger",
		colors = c("#75787E", "#5E6166", "#E9E9E4"),
		desc = "Fleece joggers with ribbed ankles and a drawstring.",
	},
	{
		id = "hw_joggers_black",
		name = "Hanesworth Joggers, Black",
		slot = "bottom",
		builder = "trousers",
		style = "jogger",
		colors = c("#202124", "#17181A", "#D9D9D4"),
		desc = "Black fleece joggers, cuffed at the ankle.",
	},
	{
		id = "hw_jeans_rinse",
		name = "Hanesworth Rinse Jeans",
		slot = "bottom",
		builder = "jeans",
		colors = c("#263552", "#3B2A1E", "#B98A4B"),
		desc = "Dark rinse straight jeans.",
	},
	{
		id = "hw_canvas_white",
		name = "Hanesworth Canvas Sneakers",
		slot = "shoes",
		builder = "sneaker",
		style = "canvas",
		colors = c("#EEEDE7", "#FFFFFF", "#F7F6F1"),
		desc = "All-white canvas low-tops.",
	},
})
look("hw_heather", "hanesworth", "Hanesworth Heather", { "hw_tee_heather", "hw_joggers_grey", "hw_canvas_white" })
look("hw_crew", "hanesworth", "Hanesworth Crew", { "hw_crew_grey", "hw_jeans_rinse", "hw_canvas_white" })
look("hw_pullover", "hanesworth", "Hanesworth Pullover", { "hw_hoodie_black", "hw_joggers_black", "hw_canvas_white" })

---------------------------------------------------------------------------------------------------
-- Uncommon: J. Crewson, Plantain Republic, Tommy Hillford
---------------------------------------------------------------------------------------------------
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

---------------------------------------------------------------------------------------------------
-- Rare: Ralph Lorenzo, Brooks Brethren, Vineyard Wines, Patagonio
---------------------------------------------------------------------------------------------------
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

---------------------------------------------------------------------------------------------------
-- Legendary: Tom Fordham, Zegnatti, Bruno Cucina
---------------------------------------------------------------------------------------------------
brand("tom_fordham", "legendary", {
	{
		id = "tf_velvet_tux",
		name = "Tom Fordham Velvet Tuxedo Jacket",
		slot = "outer",
		builder = "jacket",
		style = "shawl",
		finish = "velvet",
		colors = c("#0F4A3A", "#0C0C0E", "#F4F4F0"),
		desc = "Emerald velvet with black satin shawl lapels.",
	},
	{
		id = "tf_dress_shirt",
		name = "Tom Fordham Dress Shirt",
		slot = "top",
		builder = "shirt",
		colors = c("#F7F7F4", "#E9E9E5", "#1A1A1C"),
		desc = "Crisp white cotton with onyx studs.",
	},
	{
		id = "tf_bowtie",
		name = "Tom Fordham Silk Bow Tie",
		slot = "neck",
		builder = "bowtie",
		colors = c("#0E0E10", "#08080A", "#1A1A1C"),
		desc = "Black barathea silk bow tie.",
	},
	{
		id = "tf_evening_trousers",
		name = "Tom Fordham Evening Trousers",
		slot = "bottom",
		builder = "trousers",
		style = "evening",
		colors = c("#121214", "#0A0A0B", "#0A0A0B"),
		desc = "Black trousers with a satin side stripe.",
	},
	{
		id = "tf_patent_oxford",
		name = "Tom Fordham Patent Oxfords",
		slot = "shoes",
		builder = "oxford",
		finish = "patent",
		colors = c("#0C0C0D", "#070707", "#1C1C1E"),
		desc = "Mirror-black patent oxfords.",
	},
})
look(
	"tf_black_tie",
	"tom_fordham",
	"Tom Fordham Black Tie",
	{ "tf_dress_shirt", "tf_velvet_tux", "tf_evening_trousers", "tf_patent_oxford", "tf_bowtie" }
)

brand("zegnatti", "legendary", {
	{
		id = "zg_jacket",
		name = "Zegnatti Trofeo Suit Jacket",
		slot = "outer",
		builder = "jacket",
		style = "two_button",
		colors = c("#46566E", "#3A4860", "#E9EEF5"),
		desc = "Feather-light blue-grey wool from the family mill.",
	},
	{
		id = "zg_trousers",
		name = "Zegnatti Trofeo Suit Trousers",
		slot = "bottom",
		builder = "trousers",
		style = "suit",
		colors = c("#46566E", "#2A1E16", "#C0C4C8"),
		desc = "Matching blue-grey trousers, pressed sharp.",
	},
	{
		id = "zg_shirt_sky",
		name = "Zegnatti Sky Poplin Shirt",
		slot = "top",
		builder = "shirt",
		colors = c("#CFE0F2", "#BDD0E6", "#F4F4F0"),
		desc = "Sky-blue two-ply poplin.",
	},
	{
		id = "zg_knit_tie",
		name = "Zegnatti Silk Knit Tie, Navy",
		slot = "neck",
		builder = "tie",
		style = "knit",
		colors = c("#1C2846", "#141E36", "#26345A"),
		desc = "Square-ended navy silk knit.",
	},
	{
		id = "zg_tassel_suede",
		name = "Zegnatti Suede Tassel Loafers",
		slot = "shoes",
		builder = "loafer",
		style = "tassel",
		finish = "suede",
		colors = c("#4A3022", "#21150E", "#6B4A33"),
		desc = "Chocolate suede tassel loafers.",
	},
})
look(
	"zg_milano",
	"zegnatti",
	"Zegnatti Milano",
	{ "zg_shirt_sky", "zg_jacket", "zg_trousers", "zg_tassel_suede", "zg_knit_tie" }
)

brand("bruno_cucina", "legendary", {
	{
		id = "bc_blazer_taupe",
		name = "Bruno Cucina Cashmere Blazer",
		slot = "outer",
		builder = "blazer",
		colors = c("#8C7B68", "#7A6A58", "#5A4A3A"),
		desc = "Unlined taupe cashmere that drapes like a cardigan.",
	},
	{
		id = "bc_cashmere_crew",
		name = "Bruno Cucina Cashmere Crew",
		slot = "top",
		builder = "sweater",
		colors = c("#D8CCB6", "#C8BBA3", "#D8CCB6"),
		desc = "Oatmeal twelve-ply cashmere.",
	},
	{
		id = "bc_flannel_cream",
		name = "Bruno Cucina Cream Flannel Trousers",
		slot = "bottom",
		builder = "trousers",
		colors = c("#E3DACA", "#6B4A33", "#B8933F"),
		desc = "Winter-white flannel on a suede belt.",
	},
	{
		id = "bc_suede_sneaker",
		name = "Bruno Cucina Suede Sneakers",
		slot = "shoes",
		builder = "sneaker",
		finish = "suede",
		colors = c("#C8B79C", "#F1EEE6", "#8C7B68"),
		desc = "Sand suede low-tops on cream soles.",
	},
	{
		id = "bc_scarf",
		name = "Bruno Cucina Cashmere Scarf",
		slot = "neck",
		builder = "scarf",
		colors = c("#9A9590", "#86817C", "#B3AEA8"),
		desc = "A fog-grey cashmere scarf, looped once.",
	},
})
look(
	"bc_quiet_luxury",
	"bruno_cucina",
	"Bruno Cucina Quiet Luxury",
	{ "bc_cashmere_crew", "bc_blazer_taupe", "bc_flannel_cream", "bc_suede_sneaker", "bc_scarf" }
)

---------------------------------------------------------------------------------------------------
-- Mythic: the William Kingsley Signature look (exactly one)
---------------------------------------------------------------------------------------------------
brand("william_kingsley", "mythic", {
	{
		id = "wk_jacket",
		name = "William Kingsley Signature Jacket",
		slot = "outer",
		builder = "jacket",
		style = "kingsley",
		pattern = "pinstripe",
		details = { "lapel_pin" },
		colors = c("#1A2233", "#141B2A", "#D4AF37", "#7A1428"),
		desc = "Hand-cut chalk-stripe double-breasted: gold crest buttons, a crest lapel pin and a claret silk square.",
	},
	{
		id = "wk_shirt",
		name = "William Kingsley Monogrammed Shirt",
		slot = "top",
		builder = "shirt",
		details = { "monogram_cuff" },
		colors = c("#FAF9F5", "#ECEAE3", "#F4F1E8", "#7A1428"),
		desc = "Sea-island cotton with a claret WK monogram on the cuff.",
	},
	{
		id = "wk_trousers",
		name = "William Kingsley Signature Trousers",
		slot = "bottom",
		builder = "trousers",
		style = "suit",
		pattern = "pinstripe",
		colors = c("#1A2233", "#2A1E16", "#D4AF37"),
		desc = "Chalk-stripe trousers with a gold buckle.",
	},
	{
		id = "wk_tie",
		name = "William Kingsley Silk Tie & Gold Bar",
		slot = "neck",
		builder = "tie",
		style = "bar",
		colors = c("#7A1428", "#5E0F1F", "#D4AF37"),
		desc = "Claret seven-fold silk held by a crest-engraved gold bar.",
	},
	{
		id = "wk_oxford",
		name = "William Kingsley Mirror-Shine Wholecuts",
		slot = "shoes",
		builder = "oxford",
		style = "wholecut",
		colors = c("#3A1416", "#140809", "#5A2024"),
		desc = "Oxblood wholecuts polished to a mirror.",
	},
	{
		id = "wk_watch",
		name = "William Kingsley Signature Chronometer",
		slot = "wrist",
		builder = "watch",
		style = "gold",
		colors = c("#D4AF37", "#2A1A12", "#F4EEDC"),
		desc = "Rose-gold chronometer on oxblood alligator.",
	},
})
look(
	"wk_signature",
	"william_kingsley",
	"The William Kingsley Signature",
	{ "wk_shirt", "wk_jacket", "wk_trousers", "wk_oxford", "wk_tie", "wk_watch" }
)

---------------------------------------------------------------------------------------------------
-- Family heirlooms (granted by the Life Roll family result; never sold)
---------------------------------------------------------------------------------------------------
local heirlooms: { { [string]: any } } = {
	{
		id = "heirloom_signet_ring",
		name = "Family Signet Ring",
		slot = "wrist",
		builder = "ring",
		rarity = "rare",
		tier = 3,
		colors = c("#D4AF37", "#B8933F", "#6E5320"),
		desc = "A worn gold signet with the family crest. Rare families only.",
	},
	{
		id = "heirloom_family_watch",
		name = "Vintage Family Watch",
		slot = "wrist",
		builder = "watch",
		style = "gold",
		rarity = "legendary",
		tier = 4,
		colors = c("#C9A54C", "#4A2E1C", "#F1E7CF"),
		desc = "Grandfather's gold dress watch on a fresh brown strap.",
	},
	{
		id = "heirloom_vanderfeller_crest_blazer",
		name = "The Vanderfeller Crest Blazer",
		slot = "outer",
		builder = "blazer",
		style = "heirloom",
		rarity = "mythic",
		tier = 5,
		colors = c("#13213B", "#0E1A30", "#D4AF37", "#7A1428"),
		desc = "Midnight navy with gold crest buttons, gold piping and the Vanderfeller crest.",
	},
}
for _, d in heirlooms do
	d.brand = "family_heirloom"
	d.currency = "heirloom"
	d.category = "heirloom"
	d.price = 0
	d.tags = { "heirloom", d.rarity }
	table.insert(items, d)
end

return { items = items, looks = looks }
