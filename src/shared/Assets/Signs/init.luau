--!strict
-- Signs: building names, plaques, street blades, wayfinding, neon, LED ticker bands, posters and
-- billboards, built from Parts + SurfaceGuis (no image ids). Bake-safe (contracts §13).
--
-- Every function is fn(parent: Instance?, cf: CFrame, opts?) -> Model. The model has PrimaryPart "Root"
-- (invisible, non-colliding, at cf), attributes SignKind / SignMount (and SignStyle for building names),
-- tag "Sign", and only anchored parts. opts.seed varies seeded choices; without it they vary by placement
-- but stay identical between bakes.
--
-- Mounts:
--   "wall"   cf = bottom-centre of the sign's back face, flat on the facade, LookVector out of the wall.
--            buildingName, plaque, neon, tickerBand, poster
--   "floor"  cf = centre of the base on the ground, LookVector = main reading side.
--            streetName, wayfinding, billboard (on a roof)
--
-- Signs.buildingName(parent, cf, {text, width?, height?, style = "brass"|"neon"|"stone"|"paint"|"lightbox",
--                                 color?, accent?, font?, lit?, flicker?, firmBrand?})
--     firmBrand = true names the main label "BrandText" and tags its part "FirmBrand" (contracts §11).
-- Signs.plaque(parent, cf, {title?, text?, width?, height?, color?, accent?})
-- Signs.streetName(parent, cf, {text?, text2? (false = one blade), height?, color?, accent?})
-- Signs.wayfinding(parent, cf, {title?, entries? = {string}, width?, height?, color?, accent?, lit?})
-- Signs.neon(parent, cf, {text?, color?, width?, height?, font?, lit?, flicker?})
-- Signs.tickerBand(parent, cf, {width?, height?, text?, color?, background?, accent?})
--     LED faces are tagged "TickerDisplay"; each holds TextLabel "TickerText" (see Panels.luau for scrolling).
-- Signs.poster(parent, cf, {title?, body?, colors? = {background, accent, text}, width?, height?, frame?})
-- Signs.billboard(parent, cf, {brand?, slogan?, width?, height?, legs?, lit?, color?, accent?})
-- Signs.build(kind, parent, cf, opts?) dispatches by kind name; Signs.list() describes every kind.
-- font names: "serif" | "sans" | "slab" | "type" | "tech" | "script" | "fun".

local Facade = require(script.Facade)
local SignsStreet = require(script.Street)
local Panels = require(script.Panels)

export type Opts = { [string]: any }
export type Builder = (parent: Instance?, cf: CFrame, opts: Opts?) -> Model
export type Info = { kind: string, mount: string }

local Signs = {}

Signs.STYLES = table.clone(Facade.STYLES)

Signs.buildingName = Facade.buildingName :: Builder
Signs.plaque = Facade.plaque :: Builder
Signs.neon = Facade.neon :: Builder
Signs.streetName = SignsStreet.streetName :: Builder
Signs.wayfinding = SignsStreet.wayfinding :: Builder
Signs.billboard = SignsStreet.billboard :: Builder
Signs.tickerBand = Panels.tickerBand :: Builder
Signs.poster = Panels.poster :: Builder

local KINDS: { { kind: string, mount: string, fn: Builder } } = {
	{ kind = "buildingName", mount = "wall", fn = Facade.buildingName },
	{ kind = "plaque", mount = "wall", fn = Facade.plaque },
	{ kind = "neon", mount = "wall", fn = Facade.neon },
	{ kind = "tickerBand", mount = "wall", fn = Panels.tickerBand },
	{ kind = "poster", mount = "wall", fn = Panels.poster },
	{ kind = "streetName", mount = "floor", fn = SignsStreet.streetName },
	{ kind = "wayfinding", mount = "floor", fn = SignsStreet.wayfinding },
	{ kind = "billboard", mount = "floor", fn = SignsStreet.billboard },
}

local byKind: { [string]: Builder } = {}
for _, k in KINDS do
	byKind[k.kind] = k.fn
end

function Signs.list(): { Info }
	local out = {}
	for _, k in KINDS do
		table.insert(out, { kind = k.kind, mount = k.mount })
	end
	return out
end

function Signs.has(kind: any): boolean
	return type(kind) == "string" and byKind[kind] ~= nil
end

function Signs.build(kind: string, parent: Instance?, cf: CFrame, opts: Opts?): Model
	local fn = if type(kind) == "string" then byKind[kind] else nil
	if fn == nil then
		error(string.format("Signs.build: unknown sign kind '%s'", tostring(kind)), 2)
	end
	return fn(parent, cf, opts)
end

return Signs
