--!strict
-- The lobby's palette: polished city (design §9: marble, glass, brass, warm crisp light). Company colours are not
-- baked: FirmColor / FirmAccent parts carry these neutral placeholders until OfficeService brands the clone.
-- Bake-safe (pure data).

local Deps = require(script.Parent.Deps)

local hex = Deps.Palette.hex

local Look = {
	marble = hex("#ECE8E1"),
	marbleWarm = hex("#E2D9CB"),
	marbleVein = hex("#A9A39A"),
	nero = hex("#26262A"), -- black marble
	neroVein = hex("#8D8A86"),
	limestone = hex("#D6CDBD"),
	limestoneDark = hex("#B9AE9C"),
	onyx = hex("#F2E9D8"), -- the backlit logo panel
	granite = hex("#4A4C50"),
	brass = hex("#B8933F"),
	brassDark = hex("#8A6A2C"),
	walnut = hex("#5A3A26"),
	walnutDark = hex("#3E281B"),
	oak = hex("#A07A52"),
	steel = hex("#A7ABB0"),
	black = hex("#141518"),
	glass = hex("#A9C6D4"),
	glassDark = hex("#5E7F92"),
	leather = hex("#3B2A20"),
	leatherTan = hex("#8C6A4C"),
	velvet = hex("#29433A"),
	navy = hex("#1B2A44"),
	rugBase = hex("#3B4048"),
	rugAccent = hex("#C9A54C"),
	plaster = hex("#EFECE6"),
	warmLight = hex("#FFE2B0"),
	coolLight = hex("#F4F6F8"),
	firm = hex("#0B1F3A"), -- FirmColor placeholder (branded at runtime)
	firmAccent = hex("#C9A54C"), -- FirmAccent placeholder
	-- the Street outside
	pavement = hex("#A9A59C"),
	kerb = hex("#8E8C86"),
	asphalt = hex("#2B2D30"),
	laneWhite = hex("#E9E7E1"),
	laneYellow = hex("#E2B93B"),
	bark = hex("#4A3A2C"),
	leaf = hex("#46703C"),
	leafLight = hex("#5F8A4A"),
	facades = {
		hex("#C9BBA3"),
		hex("#8E8678"),
		hex("#B4A48A"),
		hex("#7A5B48"),
		hex("#A9ACAE"),
		hex("#D2C6B0"),
		hex("#6F7478"),
	},
	awnings = { hex("#1F4D3A"), hex("#7A1F24"), hex("#0B1F3A"), hex("#3B3F3A"), hex("#5A3A26") },
}

return Look
