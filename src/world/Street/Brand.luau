--!strict
-- Company branding on the Street: black-and-gold fascia signs, logo plates, tenant directory boards and address
-- plaques. Logo plates are tagged "CompanyLogo" with attributes LogoId and LogoFace (the same contract the office
-- templates use), and get the company's logo at bake time through Assets/Logos when it is available; otherwise a
-- gilt text label stands in. Names come from Config/Companies (guarded), else the tower label. Bake-safe.
--
--   Brand.name(companyId, fallback?) -> string
--   Brand.colors(companyId) -> (primary: Color3, accent: Color3)
--   Brand.aspect(logoId) -> number                             logo width / height (1 when Logos is missing)
--   Brand.logo(parent, cf, w, h, logoId, opts?) -> Part        cf = bottom-centre of the plate's back, LookVector out
--   Brand.fascia(parent, cf, maxW, companyId, opts?) -> Model   logo + gilt name on a black granite band (wall mount)
--   Brand.title(parent, cf, text, maxW, opts?) -> Model         a building name in gilt letters on a black band
--   Brand.directory(parent, cf, title, tenants, opts?) -> Model tenant board (floor mount, reads from LookVector)
--   Brand.plaque(parent, cf, title, text) -> Model              brass address plaque (wall mount)

local Deps = require(script.Parent.Deps)
local Look = require(script.Parent.Look)
local Text = require(script.Parent.Text)

local Kit = Deps.Kit
local Signs = Deps.Signs
local Gui = Deps.Gui
local M = Enum.Material

local Brand = {}

local function company(id: string?): any
	local Companies = Deps.Companies
	if id == nil or Companies == nil or type(Companies.get) ~= "function" then
		return nil
	end
	local ok, def = pcall(Companies.get, id)
	return if ok and type(def) == "table" then def else nil
end

function Brand.name(id: string?, fallback: string?): string
	local def = company(id)
	if def and type(def.name) == "string" and def.name ~= "" then
		return def.name
	end
	return fallback or id or ""
end

function Brand.colors(id: string?): (Color3, Color3)
	local def = company(id)
	local primary, accent = Look.navy, Look.gold
	if def and type(def.colors) == "table" then
		if typeof(def.colors.primary) == "Color3" then
			primary = def.colors.primary
		end
		if typeof(def.colors.accent) == "Color3" then
			accent = def.colors.accent
		end
	end
	return primary, accent
end

local function logoAspect(id: string): number
	local Logos = Deps.Logos
	if Logos and type(Logos.aspect) == "function" then
		local ok, a = pcall(Logos.aspect, id)
		if ok and type(a) == "number" and a > 0 then
			return math.clamp(a, 0.5, 4)
		end
	end
	return 1
end

Brand.aspect = logoAspect

export type LogoOpts = {
	label: string?,
	theme: string?, -- Logos theme for the plate background ("dark" on black, "light" on stone)
	plate: Color3?,
	plateMat: Enum.Material?,
	glow: boolean?,
	px: number?,
}

-- A logo plate, tagged CompanyLogo. Falls back to the label in gilt letters when Logos is missing or fails.
function Brand.logo(parent: Instance, cf: CFrame, w: number, h: number, logoId: string, o: LogoOpts?): Part
	local opts: LogoOpts = o or {}
	local plate = Kit.detail(
		parent,
		cf * CFrame.new(0, h / 2, -0.2),
		Vector3.new(w, h, 0.4),
		opts.plate or Look.black,
		opts.plateMat or M.Granite
	)
	plate.Name = "CompanyLogo"
	plate:AddTag("CompanyLogo")
	plate:SetAttribute("LogoId", logoId)
	plate:SetAttribute("LogoFace", "Front")
	local drawn = false
	local Logos = Deps.Logos
	if Logos and type(Logos.surface) == "function" then
		local ok = pcall(Logos.surface, plate, Enum.NormalId.Front, logoId, {
			theme = opts.theme or "dark",
			lightInfluence = if opts.glow then 0 else 0.6,
			brightness = if opts.glow then 1.4 else 1,
			px = opts.px or 512,
			padding = 0.08,
		})
		drawn = ok
	end
	if not drawn then
		Kit.sign(plate, opts.label or Brand.name(logoId), {
			color = Look.gold,
			font = Enum.Font.Garamond,
			pixelsPerStud = 40,
			glow = opts.glow,
		})
	end
	return plate
end

local function fitWidth(text: string, h: number): number
	return math.max(4, #text * h * 0.62)
end

export type FasciaOpts = { height: number?, band: Color3?, gold: Color3?, lit: boolean?, noBand: boolean? }

-- Black granite band with a gold edge, the logo plate on the left and the name in gilt letters (wordmark logos
-- stand alone). cf = bottom-centre of the band's back face on the facade, LookVector out.
function Brand.fascia(parent: Instance, cf: CFrame, maxW: number, companyId: string, o: FasciaOpts?): Model
	local opts: FasciaOpts = o or {}
	local m = Kit.model(parent, "Fascia")
	local H = opts.height or 4.5
	local gold = opts.gold or Look.gold
	local aspect = logoAspect(companyId)
	local name = Brand.name(companyId)
	local wordmark = aspect >= 2
	local logoH = H * (if wordmark then 0.8 else 1.0)
	local logoW = logoH * aspect
	local nameH = H * 0.55
	local nameW = if wordmark then 0 else fitWidth(name, nameH)
	local gap = if wordmark then 0 else H * 0.4
	local total = logoW + gap + nameW
	if total > maxW then
		local k = maxW / total
		logoW, logoH, nameW, nameH, gap = logoW * k, logoH * k, nameW * k, nameH * k, gap * k
		total = maxW
	end
	local bandH = math.max(logoH, nameH) + 1.2
	if not opts.noBand then
		Kit.detail(
			m,
			cf * CFrame.new(0, bandH / 2, -0.25),
			Vector3.new(total + 3, bandH, 0.5),
			opts.band or Look.black,
			M.Granite
		).Name =
			"Band"
		for _, sy in { 0.12, bandH - 0.12 } do
			Kit.detail(m, cf * CFrame.new(0, sy, -0.55), Vector3.new(total + 3, 0.18, 0.12), gold, M.Metal)
		end
	end
	local x0 = -total / 2
	Brand.logo(m, cf * CFrame.new(x0 + logoW / 2, (bandH - logoH) / 2, -0.55), logoW, logoH, companyId, {
		label = name,
		theme = "dark",
		glow = opts.lit,
	})
	if not wordmark then
		Signs.buildingName(m, cf * CFrame.new(x0 + logoW + gap + nameW / 2, (bandH - nameH) / 2 - 0.2, -0.55), {
			text = name,
			style = "brass",
			height = nameH,
			width = nameW,
			color = gold,
			font = "serif",
			seed = "fascia:" .. companyId,
		})
	end
	return m
end

-- A building name in gilt letters on a black band (multi-tenant towers, venues).
function Brand.title(parent: Instance, cf: CFrame, text: string, maxW: number, o: FasciaOpts?): Model
	local opts: FasciaOpts = o or {}
	local m = Kit.model(parent, "Title")
	local H = opts.height or 3.2
	local W = math.min(maxW, fitWidth(text, H))
	H = math.min(H, W / math.max(#text * 0.62, 1))
	local bandH = H + 1.2
	if not opts.noBand then
		Kit.detail(
			m,
			cf * CFrame.new(0, bandH / 2, -0.25),
			Vector3.new(W + 3, bandH, 0.5),
			opts.band or Look.black,
			M.Granite
		).Name =
			"Band"
		for _, sy in { 0.12, bandH - 0.12 } do
			Kit.detail(
				m,
				cf * CFrame.new(0, sy, -0.55),
				Vector3.new(W + 3, 0.18, 0.12),
				opts.gold or Look.gold,
				M.Metal
			)
		end
	end
	Signs.buildingName(m, cf * CFrame.new(0, 0.4, -0.55), {
		text = text,
		style = "brass",
		height = H,
		width = W,
		color = opts.gold or Look.gold,
		font = "serif",
		lit = opts.lit,
		seed = "title:" .. text,
	})
	return m
end

export type DirectoryOpts = { width: number?, labels: { [string]: string }? }

-- A black granite tenant board with a brass frame. Each row: the tenant's logo, its name and "Lobby >".
-- cf = centre of the base on the ground, LookVector = the reading side.
function Brand.directory(parent: Instance, cf: CFrame, title: string, tenants: { string }, o: DirectoryOpts?): Model
	local opts: DirectoryOpts = o or {}
	local m = Kit.model(parent, "TenantDirectory")
	local n = math.max(1, #tenants)
	local W = opts.width or 6
	local H = math.clamp(2.6 + n * 1.3, 4.5, 9.5)
	Kit.block(m, cf * CFrame.new(0, 0.25, 0), Vector3.new(W + 0.8, 0.5, 1.6), Look.graniteDark, M.Granite).Name =
		"Plinth"
	local body = Kit.block(m, cf * CFrame.new(0, 0.5 + H / 2, 0), Vector3.new(W, H, 0.6), Look.blackGranite, M.Granite)
	body.Name = "Board"
	Kit.detail(m, cf * CFrame.new(0, 0.5 + H + 0.1, 0), Vector3.new(W + 0.3, 0.2, 0.8), Look.brass, M.Metal)
	for _, sx in { -1, 1 } do
		Kit.detail(
			m,
			cf * CFrame.new(sx * (W / 2 + 0.05), 0.5 + H / 2, 0),
			Vector3.new(0.12, H, 0.7),
			Look.brass,
			M.Metal
		)
	end
	local gui, gw, gh = Gui.Core.surface(body, Enum.NormalId.Front, {
		glow = true,
		brightness = 1.1,
		pps = 60,
		maxDistance = 90,
		name = "Directory",
	})
	Gui.Core.bg(gui, Look.blackGranite)
	Gui.Core.label(gui, string.upper(title), 0.06, 0.03, 0.88, 0.1, Look.gold, {
		font = Enum.Font.Garamond,
		align = Enum.TextXAlignment.Center,
	})
	Gui.Core.label(gui, Text.get("tenants_title"), 0.06, 0.13, 0.88, 0.06, Look.limestoneDark, {
		font = Enum.Font.GothamMedium,
		align = Enum.TextXAlignment.Center,
	})
	Gui.Core.frame(gui, 0.08, 0.205, 0.84, 0.006, Look.gold)
	local rowTop, rowH = 0.23, math.min(0.72 / n, 0.16)
	for i, id in tenants do
		local y = rowTop + (i - 1) * rowH
		local row = Gui.Core.frame(gui, 0.06, y + rowH * 0.08, 0.88, rowH * 0.84, Look.black, 0.4)
		local box = Gui.Core.frame(row, 0.02, 0.1, 0.8 * (rowH * 0.84 * gh) / (0.88 * gw), 0.8, Look.black, 1)
		local Logos = Deps.Logos
		local drew = false
		if Logos and type(Logos.render) == "function" then
			drew = pcall(Logos.render, box, id, { theme = "dark", simple = true })
		end
		if not drew then
			Gui.Core.label(box, string.sub(Brand.name(id), 1, 1), 0, 0, 1, 1, Look.gold, {
				font = Enum.Font.Garamond,
				align = Enum.TextXAlignment.Center,
			})
		end
		local label = if opts.labels then opts.labels[id] else nil
		Gui.Core.label(row, label or Brand.name(id), 0.22, 0.15, 0.56, 0.7, Look.white, {
			font = Enum.Font.GothamMedium,
		})
		Gui.Core.label(row, Text.get("tenant_floor"), 0.78, 0.2, 0.2, 0.6, Look.gold, {
			font = Enum.Font.GothamMedium,
			align = Enum.TextXAlignment.Right,
		})
	end
	return m
end

function Brand.plaque(parent: Instance, cf: CFrame, title: string, text: string): Model
	return Signs.plaque(parent, cf, { title = title, text = text, width = 3.2, height = 1.9 })
end

return Brand
