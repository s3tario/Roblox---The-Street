--!strict
-- Emblems: small marks drawn on garments as GUI (SurfaceGui on a thin layer plate) or as tiny parts.
--   Emblems.company(ctx, logo)      the player's company logo, left chest of a vest or quarter-zip (v3 §16):
--                                   logo = { id = logoId, monogram = string?, tint = Color3? }
--   Emblems.builders.emblem_windmill  the Pan Miller windmill (v3 §2): wearer's right chest of a tailored jacket
--                                   (the left breast holds the pocket square), left chest of a top
--   Emblems.builders.pick_stitch    Briani: hand-picked stitching along both lapel edges (tailored jackets)
--   Emblems.builders.crest_c        Canalé: the gold crescent "C" pin on the wearer's left lapel
--   Emblems.logos() -> Logos?        Shared/Assets/Logos when it exists and loads (nil otherwise)
--   Emblems.monogram(logoId) -> "MF"   fallback initials for a logo id ("mg_freeman")
-- GUI emblems use Logos.render when the logos feature is present, else an inline drawing (the windmill in Frames,
-- the company logo as a monogram). Every plate part is named "<slot>_<Piece>" like other layers. Bake-safe.

local Fit = require(script.Parent.Fit)

type Ctx = Fit.Ctx

local rad = math.rad
local SMOOTH = Enum.Material.SmoothPlastic
local FABRIC = Enum.Material.Fabric
local METAL = Enum.Material.Metal

local Emblems = {}

export type Logo = { id: string, monogram: string?, tint: Color3? }

---------------------------------------------------------------------------------------------------
-- Shared/Assets/Logos (owned by `logos`), loaded once, guarded: a missing or broken module never breaks a look
---------------------------------------------------------------------------------------------------
local logosModule: any = nil
local logosTried = false

function Emblems.logos(): any
	if logosTried then
		return logosModule
	end
	logosTried = true
	local ok, mod = pcall(function(): any
		local assets = script.Parent.Parent
		local m = assets:FindFirstChild("Logos")
		if m and m:IsA("ModuleScript") then
			return (require :: any)(m)
		end
		return nil
	end)
	if ok and type(mod) == "table" and type(mod.render) == "function" then
		logosModule = mod
	end
	return logosModule
end

-- Draws logoId into `canvas` with Logos.render; false when the module is missing or the call fails.
local function renderLogo(canvas: Frame, logoId: string, opts: { [string]: any }): boolean
	local L = Emblems.logos()
	if not L then
		return false
	end
	local ok = pcall(function()
		L.render(canvas, logoId, opts)
	end)
	if not ok then
		canvas:ClearAllChildren()
	end
	return ok
end

local function logoAspect(logoId: string): number
	local L = Emblems.logos()
	if L and type(L.aspect) == "function" then
		local ok, a = pcall(L.aspect, logoId)
		if ok and type(a) == "number" and a == a and a > 0 then
			return math.clamp(a, 1, 2.6)
		end
	end
	return 1
end

---------------------------------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------------------------------
local function luminance(c: Color3): number
	return 0.2126 * c.R + 0.7152 * c.G + 0.0722 * c.B
end

-- The thread colour that reads on `bg`: the first candidate with enough contrast, else white or ink.
local function threadOn(bg: Color3, candidates: { Color3 }): Color3
	local lb = luminance(bg)
	for _, c in candidates do
		if math.abs(luminance(c) - lb) > 0.28 then
			return c
		end
	end
	return if lb < 0.5 then Color3.fromRGB(244, 242, 236) else Color3.fromRGB(28, 32, 44)
end

local function chestVisible(ctx: Ctx): boolean
	return ctx.slot ~= "top" or not Fit.covered(ctx, "torso")
end

-- A thin plate on the torso front with a SurfaceGui canvas on its front face. Returns the canvas.
local function guiPlate(ctx: Ctx, x: number, y: number, w: number, h: number, plateColor: Color3, name: string): Frame?
	local s = Fit.size(ctx, "UpperTorso")
	if not s then
		return nil
	end
	local z = (ctx.state.torsoFront or -s.Z / 2) - 0.012
	local plate = Fit.box(ctx, "UpperTorso", CFrame.new(x, y, z), Vector3.new(w, h, 0.012), plateColor, FABRIC, name)
	if not plate then
		return nil
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Emblem"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 640
	gui.LightInfluence = 0.8
	gui.MaxDistance = 90
	gui.ClipsDescendants = true
	gui.Parent = plate
	local canvas = Instance.new("Frame")
	canvas.Name = "Canvas"
	canvas.BackgroundTransparency = 1
	canvas.BorderSizePixel = 0
	canvas.Size = UDim2.fromScale(1, 1)
	canvas.Parent = gui
	return canvas
end

-- A straight bar between two points of a square canvas (scale units).
local function bar(
	parent: Instance,
	x1: number,
	y1: number,
	x2: number,
	y2: number,
	w: number,
	color: Color3,
	name: string
)
	local dx, dy = x2 - x1, y2 - y1
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale((x1 + x2) / 2, (y1 + y2) / 2)
	f.Size = UDim2.fromScale(w, math.sqrt(dx * dx + dy * dy))
	f.Rotation = math.deg(math.atan2(dx, -dy))
	f.Parent = parent
end

local function disc(parent: Instance, x: number, y: number, d: number, color: Color3, name: string): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(x, y)
	f.Size = UDim2.fromScale(d, d)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = f
	f.Parent = parent
	return f
end

---------------------------------------------------------------------------------------------------
-- The windmill, drawn in Frames (fallback for Logos "brand_pan_miller"): a lattice tower, a multi-blade wheel
-- with a rim and hub, and a tail vane.
---------------------------------------------------------------------------------------------------
function Emblems.drawWindmill(canvas: Instance, color: Color3)
	local cx, cy, r = 0.4, 0.3, 0.25
	-- tail vane: boom to the right and the vane plate
	bar(canvas, cx, cy, cx + 0.46, cy, 0.035, color, "Boom")
	local vane = Instance.new("Frame")
	vane.Name = "Vane"
	vane.BorderSizePixel = 0
	vane.BackgroundColor3 = color
	vane.AnchorPoint = Vector2.new(0.5, 0.5)
	vane.Position = UDim2.fromScale(cx + 0.47, cy - 0.02)
	vane.Size = UDim2.fromScale(0.13, 0.17)
	vane.Rotation = -6
	vane.Parent = canvas
	-- wheel: rim, blades, hub
	local rim = disc(canvas, cx, cy, r * 2, color, "Rim")
	rim.BackgroundTransparency = 1
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 2
	stroke.Parent = rim
	for i = 0, 11 do
		local a = rad(i * 30 + 15)
		local sx, sy = math.sin(a), -math.cos(a)
		bar(canvas, cx + sx * 0.06, cy + sy * 0.06, cx + sx * (r - 0.01), cy + sy * (r - 0.01), 0.055, color, "Blade")
	end
	disc(canvas, cx, cy, 0.09, color, "Hub")
	-- tower: two tapering legs, a platform and braces
	local top, base = cy + 0.08, 0.97
	local lt, rt = cx - 0.05, cx + 0.05
	local lb, rb = cx - 0.2, cx + 0.2
	bar(canvas, lt, top, lb, base, 0.035, color, "Leg")
	bar(canvas, rt, top, rb, base, 0.035, color, "Leg")
	local function legX(left: boolean, y: number): number
		local t = (y - top) / (base - top)
		return if left then lt + (lb - lt) * t else rt + (rb - rt) * t
	end
	bar(canvas, cx - 0.1, top + 0.02, cx + 0.1, top + 0.02, 0.03, color, "Platform")
	for _, y in { 0.62, 0.82 } do
		bar(canvas, legX(true, y), y, legX(false, y), y, 0.025, color, "Brace")
	end
	bar(canvas, legX(true, 0.62), 0.62, legX(false, 0.82), 0.82, 0.02, color, "Brace")
	bar(canvas, legX(false, 0.62), 0.62, legX(true, 0.82), 0.82, 0.02, color, "Brace")
end

local function windmill(ctx: Ctx)
	local s = Fit.size(ctx, "UpperTorso")
	if not s or not chestVisible(ctx) then
		return
	end
	local col = ctx.colors
	local thread = threadOn(col.primary, { col.accent, col.trim })
	local size = math.min(s.X * 0.1, 0.2)
	local x, y
	if ctx.slot == "outer" and type(ctx.state.lapelV) == "table" then
		-- mirror of the breast pocket, clear of the lapel and the stripes
		x, y = s.X * 0.33, s.Y / 2 - s.Y * 0.3
	else
		x, y = -s.X * 0.27, s.Y / 2 - 0.45
	end
	local canvas = guiPlate(ctx, x, y, size, size, Fit.shade(col.primary, 0.04), ctx.slot .. "_Windmill")
	if not canvas then
		return
	end
	if not renderLogo(canvas, "brand_pan_miller", { tint = thread, simple = true, px = 128 }) then
		Emblems.drawWindmill(canvas, thread)
	end
end

---------------------------------------------------------------------------------------------------
-- Company logo (v3 §16)
---------------------------------------------------------------------------------------------------
function Emblems.monogram(logoId: string): string
	local letters = {}
	for word in string.gmatch(logoId, "[^_%s]+") do
		local first = string.match(word, "%a")
		if first then
			table.insert(letters, string.upper(first))
		end
		if #letters >= 3 then
			break
		end
	end
	if #letters == 1 then
		local two = string.match(logoId, "^%a%a")
		return if two then string.upper(string.sub(two, 1, 1)) .. string.lower(string.sub(two, 2, 2)) else letters[1]
	end
	return if #letters > 0 then table.concat(letters) else "?"
end

-- The emblem goes on the wearer's left chest of the current slot's garment; Wardrobe.apply calls this right
-- after that garment (and its details) is built.
function Emblems.company(ctx: Ctx, logo: Logo)
	local s = Fit.size(ctx, "UpperTorso")
	if not s or type(logo.id) ~= "string" or logo.id == "" then
		return
	end
	local col = ctx.colors
	local thread = logo.tint or threadOn(col.primary, { col.accent, col.trim })
	local h = math.min(s.Y * 0.1, 0.16)
	local w = math.min(h * logoAspect(logo.id), s.X * 0.2)
	local x, y = -s.X * 0.27, s.Y / 2 - 0.45
	local canvas = guiPlate(ctx, x, y, w, h, Fit.shade(col.primary, 0.05), ctx.slot .. "_CompanyLogo")
	if not canvas then
		return
	end
	local plate = canvas.Parent and canvas.Parent.Parent
	if plate then
		plate:SetAttribute("LogoId", logo.id)
	end
	if renderLogo(canvas, logo.id, { tint = thread, simple = true, px = 160 }) then
		return
	end
	local label = Instance.new("TextLabel")
	label.Name = "Monogram"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = logo.monogram or Emblems.monogram(logo.id)
	label.TextColor3 = thread
	label.TextScaled = true
	label.FontFace = Font.fromEnum(Enum.Font.GothamBold)
	label.Parent = canvas
end

---------------------------------------------------------------------------------------------------
-- Lapel details (tailored jackets publish ctx.state.lapelV)
---------------------------------------------------------------------------------------------------
type LapelV = { width: number, topY: number, apexY: number, lapel: number, front: number }

local function lapelLine(ctx: Ctx): LapelV?
	local v = ctx.state.lapelV
	if type(v) ~= "table" then
		return nil
	end
	return v :: LapelV
end

-- Briani: a thin line of hand stitching just inside each lapel edge.
local function pickStitch(ctx: Ctx)
	local v = lapelLine(ctx)
	if not v then
		return
	end
	local dx, dy = v.width / 2, v.topY - v.apexY
	local L = math.sqrt(dx * dx + dy * dy)
	if L < 0.1 then
		return
	end
	local z = v.front - 0.006
	for _, side in { -1, 1 } do
		local nx, ny = side * dy / L, -dx / L -- outward, onto the lapel
		local off = math.min(v.lapel * 0.22, 0.05)
		local function at(t: number): Vector3
			return Vector3.new(side * dx * t + nx * off, v.apexY + dy * t + ny * off, z)
		end
		Fit.strip(
			ctx,
			"UpperTorso",
			at(0.12),
			at(0.9),
			0.012,
			0.006,
			ctx.colors.trim,
			SMOOTH,
			ctx.slot .. "_PickStitch"
		)
	end
end

-- Canalé: a gold crescent "C" on the wearer's left lapel (a gold disc with a lapel-coloured bite).
local function crestC(ctx: Ctx)
	local v = lapelLine(ctx)
	if not v then
		return
	end
	local dx, dy = v.width / 2, v.topY - v.apexY
	local L = math.sqrt(dx * dx + dy * dy)
	if L < 0.1 then
		return
	end
	local t = 0.68
	local nx, ny = -dy / L, -dx / L
	local off = v.lapel * t * 0.5
	local px, py = -dx * t + nx * off, v.apexY + dy * t + ny * off
	local z = v.front - 0.01
	Fit.cyl(
		ctx,
		"UpperTorso",
		CFrame.new(px, py, z) * CFrame.Angles(rad(90), 0, 0),
		0.016,
		0.09,
		ctx.colors.trim,
		METAL,
		ctx.slot .. "_CrestC"
	)
	Fit.cyl(
		ctx,
		"UpperTorso",
		CFrame.new(px + 0.022, py, z - 0.01) * CFrame.Angles(rad(90), 0, 0),
		0.008,
		0.062,
		ctx.colors.primary,
		FABRIC,
		ctx.slot .. "_CrestCBite"
	)
end

Emblems.builders = {
	emblem_windmill = windmill,
	pick_stitch = pickStitch,
	crest_c = crestC,
} :: { [string]: (Ctx) -> () }

return Emblems
