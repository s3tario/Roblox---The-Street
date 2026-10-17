--!strict
-- Catalog/Rolls: Common Life Roll brands (Kevin Kroos, Old Harbor, Gapline, Hanesworth). Item and look definitions only; Rolls/init.luau fills in the roll fields
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

return { items = items, looks = looks }
