--!strict
-- UI theme tokens (spec §9). Two themes:
--   campus  gritty Eastbridge: charcoal panels, paper text, mustard accent, Special Elite headings, Source Sans body
--   street  polished Wall Street: navy, white, gold, Gotham headings and body, RobotoMono numbers
--
--   Theme.get() -> Tokens            current tokens
--   Theme.set(name) -> boolean       switch theme; fires Theme.Changed(tokens, name) when it changes
--   Theme.name() -> string
--   Theme.Changed : Signal(tokens, name)
--   Theme.accentFor(realm?) -> Color3   realm accent from Shared/Build/Palette.realm (current accent otherwise)
--   Theme.forRank(rank?) -> "campus" | "street"   rank 0 (student) or unknown -> campus
--   Theme.uiScale(viewportHeight, userScale?) -> number   root UIScale for this screen height
-- Pure: no services, safe to require under Lune.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Palette = require(Shared.Build.Palette)
local Signal = require(Shared.Util.Signal)

export type Colors = {
	bg: Color3,
	panel: Color3,
	panelAlt: Color3,
	surface: Color3,
	text: Color3,
	textDim: Color3,
	accent: Color3,
	accentText: Color3,
	good: Color3,
	bad: Color3,
	warn: Color3,
	border: Color3,
	overlay: Color3,
	shadow: Color3,
}

export type Fonts = {
	display: Font,
	heading: Font,
	body: Font,
	bodyBold: Font,
	mono: Font,
}

export type TextSizes = {
	xs: number,
	sm: number,
	md: number,
	lg: number,
	xl: number,
	xxl: number,
}

export type Tokens = {
	name: string,
	colors: Colors,
	fonts: Fonts,
	text: TextSizes,
	radius: number, -- corner radius (px) for panels and buttons
	radiusSm: number, -- small elements (chips, inputs)
	pad: number, -- inner padding
	gap: number, -- spacing between siblings
	stroke: number, -- border thickness
	panelTransparency: number, -- background transparency of HUD panels
}

local hex = Palette.hex

local campus: Tokens = {
	name = "campus",
	colors = {
		bg = hex("#1A1B1E"),
		panel = Palette.campus.charcoal, -- #24262A
		panelAlt = hex("#2D2F34"),
		surface = hex("#383A40"),
		text = Palette.campus.paper, -- #E9E2CF
		textDim = hex("#A59F8E"),
		accent = Palette.campus.mustard, -- #C9A13B
		accentText = hex("#1A1B1E"),
		good = hex("#86A85C"),
		bad = hex("#C4553F"),
		warn = hex("#D99A34"),
		border = hex("#4C4E54"),
		overlay = hex("#0B0B0C"),
		shadow = hex("#000000"),
	},
	fonts = {
		display = Font.fromEnum(Enum.Font.SpecialElite),
		heading = Font.fromEnum(Enum.Font.SpecialElite),
		body = Font.fromEnum(Enum.Font.SourceSans),
		bodyBold = Font.fromEnum(Enum.Font.SourceSansBold),
		mono = Font.fromEnum(Enum.Font.RobotoMono),
	},
	text = { xs = 13, sm = 15, md = 18, lg = 22, xl = 28, xxl = 38 },
	radius = 4,
	radiusSm = 3,
	pad = 12,
	gap = 8,
	stroke = 2,
	panelTransparency = 0.06,
}

local street: Tokens = {
	name = "street",
	colors = {
		bg = hex("#06142A"),
		panel = Palette.street.navy, -- #0B1F3A
		panelAlt = hex("#12294A"),
		surface = hex("#1A355C"),
		text = hex("#FFFFFF"),
		textDim = hex("#A7B3C6"),
		accent = Palette.street.gold, -- #C9A54C
		accentText = Palette.street.navy,
		good = Palette.street.tickerGreen,
		bad = Palette.street.tickerRed,
		warn = hex("#F2B544"),
		border = hex("#2A4670"),
		overlay = hex("#000814"),
		shadow = hex("#000000"),
	},
	fonts = {
		display = Font.fromEnum(Enum.Font.GothamBold),
		heading = Font.fromEnum(Enum.Font.GothamMedium),
		body = Font.fromEnum(Enum.Font.Gotham),
		bodyBold = Font.fromEnum(Enum.Font.GothamBold),
		mono = Font.fromEnum(Enum.Font.RobotoMono),
	},
	text = { xs = 12, sm = 14, md = 16, lg = 20, xl = 26, xxl = 34 },
	radius = 10,
	radiusSm = 6,
	pad = 12,
	gap = 8,
	stroke = 1,
	panelTransparency = 0.04,
}

local Theme = {}

Theme.themes = { campus = campus, street = street } :: { [string]: Tokens }
Theme.names = { "campus", "street" }
Theme.COLOR_KEYS = {
	"bg",
	"panel",
	"panelAlt",
	"surface",
	"text",
	"textDim",
	"accent",
	"accentText",
	"good",
	"bad",
	"warn",
	"border",
	"overlay",
	"shadow",
}
Theme.FONT_KEYS = { "display", "heading", "body", "bodyBold", "mono" }
Theme.TEXT_KEYS = { "xs", "sm", "md", "lg", "xl", "xxl" }

-- Fired with (tokens, name) after the theme changes.
Theme.Changed = Signal.new()

local currentName = "campus"
local current: Tokens = campus

function Theme.get(): Tokens
	return current
end

function Theme.name(): string
	return currentName
end

function Theme.set(name: string): boolean
	local tokens = Theme.themes[name]
	if tokens == nil then
		warn("[Theme] unknown theme " .. tostring(name))
		return false
	end
	if name == currentName then
		return false
	end
	currentName = name
	current = tokens
	Theme.Changed:Fire(tokens, name)
	return true
end

-- Rank 0 (student) or unknown -> campus; employed ranks -> street.
function Theme.forRank(rank: number?): string
	if type(rank) == "number" and rank >= 1 then
		return "street"
	end
	return "campus"
end

-- Realm accent colour (ib pe hf vc re cd partner), or the current theme accent.
function Theme.accentFor(realm: string?): Color3
	if realm then
		local r = (Palette.realm :: any)[realm]
		if r and typeof(r.accent) == "Color3" then
			return r.accent
		end
	end
	return current.colors.accent
end

function Theme.primaryFor(realm: string?): Color3
	if realm then
		local r = (Palette.realm :: any)[realm]
		if r and typeof(r.primary) == "Color3" then
			return r.primary
		end
	end
	return current.colors.panel
end

-- Root UIScale: scales with viewport height (reference 800 px) clamped to [0.75, 1.15], times the
-- player's uiScale setting (clamped to [0.8, 1.2]).
Theme.SCALE_REFERENCE = 800
Theme.SCALE_MIN = 0.75
Theme.SCALE_MAX = 1.15
function Theme.uiScale(viewportHeight: number, userScale: number?): number
	local h = if viewportHeight > 0 then viewportHeight else Theme.SCALE_REFERENCE
	local base = math.clamp(h / Theme.SCALE_REFERENCE, Theme.SCALE_MIN, Theme.SCALE_MAX)
	local user = math.clamp(if type(userScale) == "number" and userScale == userScale then userScale else 1, 0.8, 1.2)
	return math.floor(base * user * 1000 + 0.5) / 1000
end

-- Readable text colour (near-black or white) for a given background.
function Theme.contrastText(bg: Color3): Color3
	local lum = 0.2126 * bg.R + 0.7152 * bg.G + 0.0722 * bg.B
	if lum > 0.55 then
		return Color3.fromRGB(20, 22, 26)
	end
	return Color3.fromRGB(255, 255, 255)
end

return Theme
