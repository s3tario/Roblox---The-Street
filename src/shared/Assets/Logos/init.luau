--!strict
-- Logos (owned by `logos`, contracts §10 and §16; design v3 §16): every company logo, school crest and
-- clothing-brand mark in the game, drawn from GUI shapes because the game ships no uploaded images.
-- Bake-safe (contracts §15): GUI instances only, no services, no clocks, no asset ids.
--
--   Logos.render(container, logoId, opts?) -> Frame
--       Fills `container` (any GuiObject, ScreenGui or SurfaceGui) with the logo, letterboxed to the logo's
--       aspect by a UIAspectRatioConstraint inside the returned frame.
--   Logos.surface(part, face, logoId, opts?) -> SurfaceGui
--       A PixelsPerStud SurfaceGui (LightInfluence 0.6) on `part` with the logo; transparent background
--       unless opts.background.
--   Logos.has(logoId) -> boolean        a designed logo exists (company, school, brand_<brandId>)
--   Logos.list(kind?) -> { logoId }     every logo id, or those of one kind ("company" | "school" | "brand")
--   Logos.info(logoId) -> Info?         { id, kind, name, aspect, rarity? }
--   Logos.aspect(logoId) -> number      width / height (1 for marks and crests, wider for wordmarks)
--   Logos.clear(target)                 removes logos this module created directly under `target`
--
-- Unknown ids render a tasteful monogram (Logos.has returns false for them). Ids that are missing here but
-- appear in Config/Companies, Config/LifeRoll or Config/Catalog get a generated mark in their colours.
--
-- Options:
--   theme       "light" (default: brand colours for a light background) | "dark" | "color" (reversed out of
--               the brand colour; implies a background)
--   tint        Color3: a single-ink version (engraving, embossing, signage)
--   background  true (the theme's background colour) | Color3 | false
--   corner      background corner radius as a fraction of the smaller side (0..0.5)
--   padding     inset of the artwork as a fraction of each side (default 0.12 with a background, else 0)
--   simple      drop fine detail (stipple, tiny captions) for small icons
--   px          render: the container's pixel size (number for square, or Vector2) for exact strokes
--               surface: the canvas size in pixels along the face's longer side (default 384)
--   name        name of the created instance (default "Logo")
--   surface only: lightInfluence (0.6), brightness (1), maxDistance (0 = unlimited), alwaysOnTop

local P = require(script.Primitives)
local Colors = require(script.Colors)
local Hash = require(script.Parent.Parent.Util.Hash)

export type Opts = {
	theme: string?,
	tint: Color3?,
	background: (boolean | Color3)?,
	corner: number?,
	padding: number?,
	simple: boolean?,
	px: (number | Vector2)?,
	name: string?,
	lightInfluence: number?,
	brightness: number?,
	maxDistance: number?,
	alwaysOnTop: boolean?,
}

export type Info = { id: string, kind: string, name: string, aspect: number, rarity: string? }

local Logos = {}

---------------------------------------------------------------------------------------------------
-- Registry
---------------------------------------------------------------------------------------------------
local specs: { [string]: P.Spec } = {}
local order: { string } = {}

local function register(list: { P.Spec })
	for _, s in list do
		assert(specs[s.id] == nil, "Logos: duplicate logo id " .. s.id)
		specs[s.id] = s
		table.insert(order, s.id)
	end
end

local Schools = require(script.Schools)

register(require(script.Banks))
register(require(script.Anaeio))
register(require(script.Funds))
register(require(script.Lotus))
register(require(script.Ventures))
register(Schools.list)
register(require(script.Brands))
register(require(script.Windmill))
register(require(script.HouseBrands))

---------------------------------------------------------------------------------------------------
-- Optional config lookups (other features' data; every read is guarded)
---------------------------------------------------------------------------------------------------
local function configModule(name: string): any
	local ok, result = pcall(function(): any
		local shared = script.Parent.Parent
		local config = shared:FindFirstChild("Config")
		local mod = config and config:FindFirstChild(name)
		if mod and mod:IsA("ModuleScript") then
			return (require :: any)(mod)
		end
		return nil
	end)
	if ok and type(result) == "table" then
		return result
	end
	return nil
end

local function toColor(v: any): Color3?
	if typeof(v) == "Color3" then
		return v :: Color3
	elseif type(v) == "string" and string.match(v, "^#?%x%x%x%x%x%x$") then
		return Colors.hex(v)
	end
	return nil
end

-- Finds the entry with .id == id in a list or map table (or under a list/map field of it).
local function findEntry(tbl: any, id: string, fields: { string }): any
	if type(tbl) ~= "table" then
		return nil
	end
	local sources = { tbl }
	for _, f in fields do
		if type(tbl[f]) == "table" then
			table.insert(sources, tbl[f])
		end
	end
	for _, src in sources do
		local direct = src[id]
		if type(direct) == "table" then
			return direct
		end
		for _, v in src do
			if type(v) == "table" and (v.id == id or v.logo == id) then
				return v
			end
		end
	end
	return nil
end

local catalogBrands: { [string]: { name: string, rarity: string? } }? = nil
local function catalog(): { [string]: { name: string, rarity: string? } }
	local cached = catalogBrands
	if cached then
		return cached
	end
	local out: { [string]: { name: string, rarity: string? } } = {}
	local cat = configModule("Catalog")
	if cat and type(cat.brands) == "table" then
		for id, b in cat.brands do
			if type(id) == "string" and type(b) == "table" then
				out[id] = {
					name = if type(b.name) == "string" then b.name else id,
					rarity = if type(b.rarity) == "string" then b.rarity else nil,
				}
			end
		end
	end
	catalogBrands = out
	return out
end

local rarityCache: { [string]: Color3 } = {}
local function rarityColor(rarity: string): Color3
	local cached = rarityCache[rarity]
	if cached then
		return cached
	end
	local c: Color3? = nil
	local Rarity = configModule("Rarity")
	if Rarity then
		local ok, def = pcall(function(): any
			if type(Rarity.get) == "function" then
				return Rarity.get(rarity)
			end
			return findEntry(Rarity, rarity, { "list", "tiers" })
		end)
		if ok and type(def) == "table" then
			c = toColor(def.color)
		end
	end
	local out = c or Colors.RARITY_FALLBACK[rarity] or Colors.RARITY_FALLBACK.common
	rarityCache[rarity] = out
	return out
end

---------------------------------------------------------------------------------------------------
-- Generated marks (monogram fallback and config-only ids)
---------------------------------------------------------------------------------------------------
local STOP = { ["and"] = true, ["of"] = true, ["the"] = true, ["co"] = true, ["brand"] = true }

local function initialsOf(text: string): string
	local letters = {}
	for word in string.gmatch(text, "[%w']+") do
		local lw = string.lower(word)
		if not STOP[lw] then
			table.insert(letters, string.upper(string.sub(word, 1, 1)))
		end
		if #letters >= 2 then
			break
		end
	end
	if #letters == 0 then
		return "?"
	end
	return table.concat(letters)
end

local function titleOf(id: string): string
	local words = {}
	for w in string.gmatch(id, "[^_%s]+") do
		table.insert(words, string.upper(string.sub(w, 1, 1)) .. string.sub(w, 2))
	end
	return table.concat(words, " ")
end

local MONO_COLORS = {
	Colors.hex("#1F3A5F"),
	Colors.hex("#3B2F4A"),
	Colors.hex("#24453A"),
	Colors.hex("#5A2E2E"),
	Colors.hex("#2F3B45"),
	Colors.hex("#4A3B22"),
	Colors.hex("#2C4A5A"),
	Colors.hex("#3D3D46"),
}

local function monogramSpec(id: string, name: string, kind: string, main: Color3?, accent: Color3?): P.Spec
	local h = Hash.u32("logo-monogram", id)
	local base = main or MONO_COLORS[h % #MONO_COLORS + 1]
	return {
		id = id,
		kind = kind,
		name = name,
		initials = initialsOf(name),
		colors = { main = base, accent = accent or Colors.hex("#C9A54C"), counter = Colors.hex("#FFFFFF") },
		draw = function(cv, c, ctx)
			P.circle(cv, 50, 50, 48, c.main)
			P.ring(cv, 50, 50, 43, 1.6, c.accent)
			local txt = ctx.initials
			local w = if #txt > 1 then 64 else 44
			P.text(cv, txt, 50 - w / 2, 27, w, 46, c.counter, { font = Enum.Font.Merriweather })
		end,
	}
end

local function brandMarkSpec(id: string, name: string, rarity: string?): P.Spec
	local h = Hash.u32("logo-brand", id)
	local fonts = { Enum.Font.Merriweather, Enum.Font.Garamond, Enum.Font.JosefinSans, Enum.Font.Michroma }
	local font = fonts[h % #fonts + 1]
	local base = MONO_COLORS[(h // 7) % #MONO_COLORS + 1]
	return {
		id = id,
		kind = "brand",
		name = name,
		rarity = rarity,
		initials = initialsOf(name),
		colors = { main = base, accent = Colors.hex("#B8933F"), counter = Colors.hex("#FFFFFF") },
		draw = function(cv, c, ctx)
			-- A woven-label tag: a rounded outline, the initials and a fine rule.
			P.frameOutline(cv, 6, 18, 88, 64, 2.4, c.main, { radius = 8 })
			P.text(cv, ctx.initials, 18, 26, 64, 34, c.main, { font = font })
			P.rect(cv, 34, 63, 32, 1.2, c.accent)
			if not ctx.simple then
				P.text(cv, string.upper(name), 14, 67, 72, 9, c.main, { font = Enum.Font.Gotham })
			end
		end,
	}
end

local function crestSpec(id: string, name: string, rarity: string?): P.Spec
	return Schools.generic(id, name, rarity or "common")
end

-- Ids that are not designed here but exist in another feature's config.
local generated: { [string]: P.Spec | false } = {}
local function generatedSpec(id: string): P.Spec?
	local hit = generated[id]
	if hit == false then
		return nil
	elseif hit ~= nil then
		return hit :: P.Spec
	end
	local spec: P.Spec? = nil
	if string.sub(id, 1, 6) == "brand_" then
		local b = catalog()[string.sub(id, 7)]
		if b then
			spec = brandMarkSpec(id, b.name, b.rarity)
		end
	end
	if not spec then
		local Companies = configModule("Companies")
		local entry = Companies and findEntry(Companies, id, { "list", "companies", "byId" })
		if entry then
			local colors = if type(entry.colors) == "table" then entry.colors else {}
			local nm = if type(entry.name) == "string" then entry.name else titleOf(id)
			spec = monogramSpec(id, nm, "company", toColor(colors.primary), toColor(colors.accent))
		end
	end
	if not spec then
		local LifeRoll = configModule("LifeRoll")
		local entry = LifeRoll and findEntry(LifeRoll, id, { "schools" })
		if entry and (entry.rarity ~= nil or entry.tier ~= nil) then
			local nm = if type(entry.name) == "string" then entry.name else titleOf(id)
			local rarity = if type(entry.rarity) == "string" then entry.rarity else nil
			spec = crestSpec(id, nm, rarity)
		end
	end
	generated[id] = spec or false
	return spec
end

local function resolveSpec(logoId: string): (P.Spec, boolean)
	local s = specs[logoId]
	if s then
		return s, true
	end
	local g = generatedSpec(logoId)
	if g then
		return g, true
	end
	local stripped = if string.sub(logoId, 1, 6) == "brand_" then string.sub(logoId, 7) else logoId
	local name = if stripped ~= "" then titleOf(stripped) else "?"
	return monogramSpec(logoId, name, "monogram"), false
end

---------------------------------------------------------------------------------------------------
-- Rendering
---------------------------------------------------------------------------------------------------
local function aspectOf(spec: P.Spec): number
	return math.clamp(spec.aspect or 1, 0.2, 8)
end

-- Pixel size of the artwork when the container is cw x ch pixels.
local function artPixels(cw: number, ch: number, aspect: number, pad: number): (number, number)
	local w, h = cw, ch
	if w / math.max(h, 1e-6) > aspect then
		w = h * aspect
	else
		h = w / aspect
	end
	return w * (1 - 2 * pad), h * (1 - 2 * pad)
end

local function build(
	parent: Instance,
	logoId: string,
	o: Opts,
	baseZ: number,
	ppu: number?,
	textPpu: number?,
	containerPx: Vector2?
): Frame
	local spec, known = resolveSpec(logoId)
	local aspect = aspectOf(spec)
	local theme: string = o.theme or "light"
	if theme ~= "dark" and theme ~= "color" then
		theme = "light"
	end
	local base = spec.colors
	if spec.rarity then
		base = table.clone(base)
		base.tier = rarityColor(spec.rarity)
	end
	local pal: Colors.Palette, bg: Color3
	if spec.keepColors and not o.tint and theme ~= "light" then
		pal = Colors.resolve(base, "light", nil, spec.themes)
		bg = if theme == "dark" then Colors.DARK_BG else (base.field or base.main or Colors.INK)
		pal.bg = bg
	else
		pal, bg = Colors.resolve(base, theme, o.tint, spec.themes)
	end

	local wantBg: boolean | Color3 = if o.background ~= nil then o.background else theme == "color"
	local pad = math.clamp(o.padding or (if wantBg ~= false then 0.12 else 0), 0, 0.45)

	local root = Instance.new("Frame")
	root.Name = o.name or "Logo"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromScale(1, 1)
	root.BorderSizePixel = 0
	root.BackgroundTransparency = 1
	root.ZIndex = baseZ
	root:SetAttribute("LogoId", logoId)
	root:SetAttribute("LogoKind", if known then spec.kind else "monogram")
	root:AddTag("Logo")

	local arc = Instance.new("UIAspectRatioConstraint")
	arc.AspectRatio = aspect
	arc.AspectType = Enum.AspectType.FitWithinMaxSize
	arc.DominantAxis = Enum.DominantAxis.Width
	arc.Parent = root

	if wantBg ~= false then
		root.BackgroundTransparency = 0
		root.BackgroundColor3 = if typeof(wantBg) == "Color3" then wantBg else bg
		if o.corner and o.corner > 0 then
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(math.clamp(o.corner, 0, 0.5), 0)
			c.Parent = root
		end
	end

	local art: GuiObject = root
	if pad > 0 then
		local f = Instance.new("Frame")
		f.Name = "Art"
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(0.5, 0.5)
		f.Size = UDim2.fromScale(1 - 2 * pad, 1 - 2 * pad)
		f.BackgroundTransparency = 1
		f.BorderSizePixel = 0
		f.ZIndex = baseZ + 1
		f.Parent = root
		art = f
	end

	local W, H = 100 * aspect, 100
	local exact: number? = nil
	local hint: number? = textPpu
	if containerPx then
		local _, ah = artPixels(containerPx.X, containerPx.Y, aspect, pad)
		if ppu then
			exact = ah / H
		else
			hint = ah / H
		end
	end
	local cv = P.new(art, W, H, exact, hint, baseZ + 2, o.simple)
	local ctx: P.Ctx = {
		theme = theme,
		tinted = o.tint ~= nil,
		simple = o.simple == true,
		name = spec.name,
		initials = spec.initials or initialsOf(spec.name),
	}
	spec.draw(cv, pal, ctx)
	root:SetAttribute("LogoShapes", cv.count)
	root.Parent = parent
	return root
end

local function vec(px: (number | Vector2)?): Vector2?
	if typeof(px) == "Vector2" then
		return px :: Vector2
	elseif type(px) == "number" and px > 0 then
		return Vector2.new(px, px)
	end
	return nil
end

function Logos.render(container: Instance, logoId: string, opts: Opts?): Frame
	local o: Opts = opts or {}
	local baseZ = 1
	local measured: Vector2? = vec(o.px)
	local exact = measured ~= nil
	if container:IsA("GuiObject") then
		baseZ = (container :: GuiObject).ZIndex + 1
		if not measured then
			-- A layout hint for text only (strokes stay scale-based so the logo can resize later).
			local ok, size = pcall(function(): Vector2
				return (container :: GuiObject).AbsoluteSize
			end)
			if ok and typeof(size) == "Vector2" and size.X > 1 and size.Y > 1 then
				measured = size
			end
		end
	end
	return build(container, logoId, o, baseZ, if exact then 1 else nil, nil, measured)
end

local function faceSize(size: Vector3, face: Enum.NormalId): (number, number)
	if face == Enum.NormalId.Front or face == Enum.NormalId.Back then
		return size.X, size.Y
	elseif face == Enum.NormalId.Left or face == Enum.NormalId.Right then
		return size.Z, size.Y
	end
	return size.X, size.Z
end

function Logos.surface(part: BasePart, face: Enum.NormalId, logoId: string, opts: Opts?): SurfaceGui
	local o: Opts = opts or {}
	local fw, fh = faceSize(part.Size, face)
	fw, fh = math.max(fw, 0.05), math.max(fh, 0.05)
	local target = if type(o.px) == "number" and o.px > 0 then o.px else 384
	local pps = math.clamp(target / math.max(fw, fh), 4, 400)
	pps = math.min(pps, 1024 / math.max(fw, fh))

	local gui = Instance.new("SurfaceGui")
	gui.Name = o.name or "Logo"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pps
	gui.LightInfluence = o.lightInfluence or 0.6
	gui.Brightness = o.brightness or 1
	gui.MaxDistance = o.maxDistance or 0
	gui.AlwaysOnTop = o.alwaysOnTop == true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.ClipsDescendants = true
	gui.ResetOnSpawn = false
	gui:SetAttribute("LogoId", logoId)
	gui:AddTag("Logo")

	local inner: Opts = table.clone(o)
	inner.name = "Logo"
	if inner.background == nil and inner.theme ~= "color" then
		inner.background = false
	end
	build(gui, logoId, inner, 1, 1, nil, Vector2.new(fw * pps, fh * pps))
	gui.Parent = part
	return gui
end

function Logos.has(logoId: string): boolean
	if type(logoId) ~= "string" then
		return false
	end
	return specs[logoId] ~= nil or generatedSpec(logoId) ~= nil
end

function Logos.list(kind: string?): { string }
	local out: { string } = {}
	local seen: { [string]: boolean } = {}
	for _, id in order do
		if kind == nil or specs[id].kind == kind then
			table.insert(out, id)
			seen[id] = true
		end
	end
	if kind == nil or kind == "brand" then
		local extra: { string } = {}
		for brandId in catalog() do
			local id = "brand_" .. brandId
			if not seen[id] then
				table.insert(extra, id)
			end
		end
		table.sort(extra)
		for _, id in extra do
			table.insert(out, id)
		end
	end
	return out
end

function Logos.info(logoId: string): Info?
	if not Logos.has(logoId) then
		return nil
	end
	local spec = resolveSpec(logoId)
	return { id = logoId, kind = spec.kind, name = spec.name, aspect = aspectOf(spec), rarity = spec.rarity }
end

function Logos.aspect(logoId: string): number
	local spec = resolveSpec(logoId)
	return aspectOf(spec)
end

function Logos.clear(target: Instance)
	for _, child in target:GetChildren() do
		if child:HasTag("Logo") and child:GetAttribute("LogoId") ~= nil then
			child:Destroy()
		end
	end
end

return Logos
