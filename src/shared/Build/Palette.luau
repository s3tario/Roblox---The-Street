--!strict
-- Named colours for the two visual worlds. Use these instead of ad-hoc RGB so the art direction
-- stays coherent: gritty Eastbridge campus vs polished Wall Street. Bake-safe.

local function hex(s: string): Color3
	s = string.gsub(s, "#", "")
	return Color3.fromRGB(
		tonumber(string.sub(s, 1, 2), 16),
		tonumber(string.sub(s, 3, 4), 16),
		tonumber(string.sub(s, 5, 6), 16)
	)
end

local Palette = {}
Palette.hex = hex

-- Eastbridge (gritty college town)
Palette.campus = {
	brick = hex("#7A3B2E"),
	brickDark = hex("#5C2A21"),
	brickFaded = hex("#8E5A4A"),
	mortar = hex("#9C9488"),
	concrete = hex("#8A8780"),
	concreteDark = hex("#5F5D58"),
	concreteStain = hex("#6E6A5F"),
	asphalt = hex("#2E2F31"),
	asphaltPatch = hex("#3A3B3D"),
	asphaltLine = hex("#C9B458"),
	rust = hex("#8B4A23"),
	rustDark = hex("#5E3218"),
	steel = hex("#5A5F63"),
	chainlink = hex("#8E9397"),
	wood = hex("#6B4E35"),
	woodWorn = hex("#7F6A55"),
	grass = hex("#56613A"),
	dirt = hex("#5B4A37"),
	puddle = hex("#3B4650"),
	sodium = hex("#FFB25C"), -- street lamp glow
	neonSign = hex("#FF4F5E"),
	busYellow = hex("#C9A227"),
	paper = hex("#E9E2CF"),
	ink = hex("#2A2622"),
	mustard = hex("#C9A13B"),
	charcoal = hex("#24262A"),
	tarp = hex("#3E5B6B"),
	graffitiTeal = hex("#2F8C8C"),
	graffitiMagenta = hex("#A33B7A"),
	dumpster = hex("#2F5A3A"),
	windowDim = hex("#3A4248"),
	windowWarm = hex("#E8B66A"),
}

-- Wall Street district (polished)
Palette.street = {
	limestone = hex("#D9D2C3"),
	limestoneDark = hex("#BEB5A3"),
	marble = hex("#ECEAE6"),
	marbleVein = hex("#C9C5BE"),
	granite = hex("#4A4C50"),
	graniteLight = hex("#76787C"),
	glass = hex("#8FB3C9"),
	glassDark = hex("#3E5E73"),
	glassTint = hex("#5E8BA6"),
	brass = hex("#B8933F"),
	gold = hex("#C9A54C"),
	goldBright = hex("#E3C46F"),
	navy = hex("#0B1F3A"),
	navyLight = hex("#173459"),
	black = hex("#121417"),
	white = hex("#F7F6F2"),
	steelBrushed = hex("#A7ABB0"),
	asphalt = hex("#26282B"),
	asphaltLine = hex("#F2F2F2"),
	curb = hex("#9A9A96"),
	sidewalk = hex("#B9B6AE"),
	planter = hex("#3B3F3A"),
	foliage = hex("#3F6B3A"),
	foliageLight = hex("#5A8A4A"),
	taxi = hex("#F2C230"),
	awningGreen = hex("#1F4D3A"),
	awningRed = hex("#7A1F24"),
	walnut = hex("#5A3A26"),
	oak = hex("#A07A52"),
	leather = hex("#3B2A20"),
	carpetNavy = hex("#1B2A44"),
	carpetGrey = hex("#5C6168"),
	screenBlue = hex("#0E2238"),
	tickerGreen = hex("#2BD67B"),
	tickerRed = hex("#FF5A5F"),
	warmLight = hex("#FFE2B0"),
}

-- Realm accent palettes (offices, UI accents)
Palette.realm = {
	ib = { primary = hex("#0B1F3A"), accent = hex("#C9A54C") },
	pe = { primary = hex("#2B2B2B"), accent = hex("#B5482F") }, -- Ironclad: iron + oxide
	hf = { primary = hex("#0E1A24"), accent = hex("#2BD6C0") }, -- Quantum Ridge: dark + cyan
	vc = { primary = hex("#F2EFE8"), accent = hex("#5B8C3A") }, -- Seedline: bright + green
	re = { primary = hex("#3D3328"), accent = hex("#D49A4A") }, -- Keystone: earth + amber
	cd = { primary = hex("#1E2B3A"), accent = hex("#7FA7D9") }, -- Northwind: slate + sky
	partner = { primary = hex("#15110C"), accent = hex("#E3C46F") },
}

-- Skin tones for NPCs (diverse range)
Palette.skin = {
	hex("#F1D2B6"),
	hex("#E6B98F"),
	hex("#D19A6A"),
	hex("#B07A4F"),
	hex("#8D5A3A"),
	hex("#6B4128"),
	hex("#4E2E1C"),
	hex("#F4DCC8"),
}

Palette.hair = {
	hex("#1C1712"),
	hex("#3B2A1E"),
	hex("#5C3D25"),
	hex("#8A5A33"),
	hex("#B98A52"),
	hex("#D9B97A"),
	hex("#6E6E6E"),
	hex("#C8C8C8"),
	hex("#7A2E1E"),
}

return Palette
