--!strict
-- Eastbridge building kit: brick blocks with plinths, string courses, cornices, punched windows, painted secondary
-- facades, roof clutter (water tanks, AC units, vents, bulkheads), fire escapes, grime and graffiti, plus
-- storefronts with hollow ground-floor shops you can see (or walk) into. Bake-safe.
--
--   Buildings.block(parent, o) -> (Model, Frame)
--       o.cf = centre of the footprint at ground level, LookVector = the front's outward normal.
--       Local frame: front face at z = -d/2, back at +d/2, sides at x = +/- w/2.
--       Frame = { cf, w, d, h, front: CFrame (front plane, ground, centred), shop: {depth, height}? }
--   Buildings.storefront(parent, frontCf, width, o) -> Model    glass, door, bulkhead, sign band, awning
--   Buildings.roof(parent, cf, w, d, h, rng, o)                 tanks, AC units, vents and a stair bulkhead
--   Buildings.waterTank(parent, cf, rng)                        the classic timber tank on steel legs

local Deps = require(script.Parent.Deps)
local Geo = require(script.Parent.Geo)
local Paint = require(script.Parent.Paint)
local Text = require(script.Parent.Text)

local Kit = Deps.Kit
local Props = Deps.Props
local Signs = Deps.Signs
local P = Deps.Palette
local C = P.campus
local hex = P.hex
local M = Enum.Material

local Buildings = {}

local function L(cf: CFrame, x: number, y: number, z: number): CFrame
	return cf * CFrame.new(x, y, z)
end

---------------------------------------------------------------------------------------------------
-- Roofs
---------------------------------------------------------------------------------------------------
function Buildings.waterTank(parent: Instance, cf: CFrame, rng: Deps.RngT): Model
	local m = Kit.model(parent, "WaterTank")
	local steel = Geo.vary(C.rustDark, rng, 0.1)
	local wood = Geo.vary(hex("#5A4636"), rng, 0.12)
	local legH = rng:range(4.5, 6.5)
	for _, s in { { -1, -1 }, { 1, 1 } } do
		-- two cross-braced leg frames read as four legs from any angle
		Kit.detail(m, L(cf, s[1] * 3.2, legH / 2, 0), Vector3.new(0.5, legH, 6.8), steel, M.CorrodedMetal)
	end
	Kit.block(m, L(cf, 0, legH + 0.3, 0), Vector3.new(8, 0.6, 8), steel, M.CorrodedMetal)
	local tankH = rng:range(7, 9.5)
	Kit.cylinder(m, L(cf, 0, legH + 0.6 + tankH / 2, 0), tankH, 7.6, wood, M.WoodPlanks)
	-- steel hoops
	for i = 1, 3 do
		local y = legH + 0.6 + tankH * (i / 4)
		Geo.ghost(Kit.cylinder(m, L(cf, 0, y, 0), 0.25, 7.75, hex("#2E2A26"), M.Metal))
	end
	-- conical roof: two stacked discs and a finial
	Kit.cylinder(m, L(cf, 0, legH + 0.6 + tankH + 0.4, 0), 0.8, 8.2, Geo.vary(hex("#3A332C"), rng, 0.1), M.Slate)
	Geo.ghost(Kit.cylinder(m, L(cf, 0, legH + 0.6 + tankH + 1.2, 0), 0.8, 4.6, hex("#3A332C"), M.Slate))
	Geo.ghost(Kit.cylinder(m, L(cf, 0, legH + 0.6 + tankH + 1.9, 0), 0.6, 1.2, hex("#2A2A2A"), M.Metal))
	return m
end

local function acUnit(parent: Instance, cf: CFrame, rng: Deps.RngT)
	local body = Geo.vary(hex("#B9B4A6"), rng, 0.12)
	Kit.block(parent, L(cf, 0, 1.6, 0), Vector3.new(5, 3.2, 4), body, M.Metal)
	Geo.ghost(Kit.cylinder(parent, L(cf, 0, 3.25, 0), 0.15, 3.2, hex("#2A2C2E"), M.DiamondPlate))
	Kit.detail(parent, L(cf, 2.9, 0.8, 0.8), Vector3.new(1.0, 1.0, 1.2), Geo.vary(C.steel, rng, 0.1), M.CorrodedMetal)
end

export type RoofOpts = { tanks: number?, ac: number?, vents: number?, hatch: boolean?, margin: number? }

function Buildings.roof(parent: Instance, cf: CFrame, w: number, d: number, h: number, rng: Deps.RngT, o: RoofOpts?)
	local opts: RoofOpts = o or {}
	local m = Kit.model(parent, "Roof")
	local margin = opts.margin or 5
	local function spot(): CFrame
		local x = rng:range(-w / 2 + margin, w / 2 - margin)
		local z = rng:range(-d / 2 + margin, d / 2 - margin)
		return L(cf, x, h, z) * CFrame.Angles(0, math.rad(rng:pick({ 0, 90, 180, 270 }) + rng:range(-4, 4)), 0)
	end
	for _ = 1, opts.tanks or 0 do
		if w > 16 and d > 16 then
			Buildings.waterTank(m, spot(), rng)
		end
	end
	for _ = 1, opts.ac or 0 do
		acUnit(m, spot(), rng)
	end
	for _ = 1, opts.vents or 0 do
		local s = spot()
		local vh = rng:range(2, 5)
		Geo.ghost(Kit.cylinder(m, L(s, 0, vh / 2, 0), vh, rng:range(0.6, 1.4), Geo.vary(C.steel, rng, 0.15), M.CorrodedMetal))
	end
	if opts.hatch and w > 14 and d > 14 then
		local s = spot()
		Kit.block(m, L(s, 0, 3.5, 0), Vector3.new(7, 7, 8), Geo.vary(C.brickDark, rng, 0.05), M.Brick)
		Kit.detail(m, L(s, 0, 3.4, -4.05), Vector3.new(3.2, 6.4, 0.2), hex("#4A3A30"), M.CorrodedMetal)
	end
	return m
end

---------------------------------------------------------------------------------------------------
-- Brick blocks
---------------------------------------------------------------------------------------------------
export type WindowSpec = {
	cols: number,
	w: number?,
	h: number?,
	from: number?, -- first storey with 3D windows (1 = ground)
	to: number?,
	lit: number?,
	ac: number?, -- chance of a window AC box under the pane
	margin: number?, -- studs kept clear at each end of the facade
	style: string?, -- "punched" (default) | "arched" (stone keystone lintel)
	-- facade x ranges kept clear of windows on storeys s0..s1 (entrances, pavilions)
	skip: { { x0: number, x1: number, s0: number, s1: number } }?,
}

export type PaintedSpec = { face: string, cols: number, rows: number?, lit: number?, ghost: { string }?, ac: number? }
export type FaceOpts = { lit: number?, ghost: { string }?, ac: number? }

-- A painted secondary facade (face = "front" | "back" | "left" | "right"; rows default to the upper storeys).
function Buildings.face(face: string, cols: number, rows: number?, o: FaceOpts?): PaintedSpec
	local opts: FaceOpts = o or {}
	return { face = face, cols = cols, rows = rows, lit = opts.lit, ghost = opts.ghost, ac = opts.ac }
end

export type BlockOpts = {
	name: string,
	cf: CFrame,
	w: number,
	d: number,
	h: number,
	seed: any,
	storeys: number,
	groundH: number?,
	color: Color3?,
	material: Enum.Material?,
	trim: Color3?,
	cornice: boolean?,
	plinth: boolean?,
	windows: WindowSpec?,
	painted: { PaintedSpec }?,
	shop: { depth: number, height: number, inset: number? }?,
	roof: RoofOpts?,
	grime: boolean?,
	graffiti: { string }?,
	graffitiFace: string?, -- shop buildings: the side wall that gets tagged (default "left")
	fireEscape: { x: number, floors: number }?,
}

export type Frame = { cf: CFrame, w: number, d: number, h: number, front: CFrame, model: Model, rng: Deps.RngT }

local FACES: { [string]: Enum.NormalId } = {
	front = Enum.NormalId.Front,
	back = Enum.NormalId.Back,
	left = Enum.NormalId.Left,
	right = Enum.NormalId.Right,
}

function Buildings.block(parent: Instance, o: BlockOpts): (Model, Frame)
	local rng = Deps.Rng.new(o.seed)
	local m = Kit.model(parent, o.name)
	local cf, w, d, h = o.cf, o.w, o.d, o.h
	local color = o.color or Geo.brick(rng)
	local mat = o.material or M.Brick
	local trim = o.trim or Geo.vary(C.mortar, rng, 0.08)
	local groundH = o.groundH or (h / o.storeys)
	local upperH = if o.storeys > 1 then (h - groundH - 2) / (o.storeys - 1) else 0
	local front = L(cf, 0, 0, -d / 2)

	-- the masonry mass (hollowed at the front of the ground floor when there is a shop)
	local body: Part
	if o.shop then
		local sd, sh = o.shop.depth, o.shop.height
		body = Kit.block(m, L(cf, 0, h / 2, sd / 2), Vector3.new(w, h, d - sd), color, mat)
		Kit.block(m, L(cf, 0, sh + (h - sh) / 2, -d / 2 + sd / 2), Vector3.new(w, h - sh, sd), color, mat).Name =
			"Upper"
		for _, sx in { -1, 1 } do
			Kit.block(m, L(cf, sx * (w / 2 - 0.6), sh / 2, -d / 2 + sd / 2), Vector3.new(1.2, sh, sd), color, mat).Name =
				"ShopWall"
		end
		-- shop ceiling and floor finishes
		Kit.detail(m, L(cf, 0, sh - 0.15, -d / 2 + sd / 2), Vector3.new(w - 2.4, 0.3, sd - 0.2), hex("#D8D2C2"), M.SmoothPlastic).Name =
			"ShopCeiling"
	else
		body = Kit.block(m, L(cf, 0, h / 2, 0), Vector3.new(w, h, d), color, mat)
	end
	body.Name = "Body"

	if o.plinth ~= false then
		local pl = Geo.vary(C.concreteDark, rng, 0.06)
		if o.shop then
			Kit.block(m, L(cf, 0, 1.2, o.shop.depth / 2), Vector3.new(w + 0.5, 2.4, d - o.shop.depth + 0.5), pl, M.Concrete)
		else
			Kit.block(m, L(cf, 0, 1.2, 0), Vector3.new(w + 0.5, 2.4, d + 0.5), pl, M.Concrete)
		end
	end

	-- string courses on the front between storeys
	for s = 1, o.storeys - 1 do
		local y = groundH + (s - 1) * upperH
		Kit.detail(m, L(cf, 0, y, -d / 2 - 0.2), Vector3.new(w + 0.4, 0.6, 0.5), trim, M.Concrete)
	end

	if o.cornice ~= false then
		Kit.detail(m, L(cf, 0, h - 0.8, 0), Vector3.new(w + 1.4, 1.6, d + 1.4), Kit.shade(trim, -0.1), M.Concrete).Name =
			"Cornice"
		Kit.block(m, L(cf, 0, h + 0.3, 0), Vector3.new(w + 2.2, 0.6, d + 2.2), Kit.shade(trim, -0.25), M.Concrete).Name =
			"CorniceCap"
	end

	-- punched windows on the front
	local win = o.windows
	if win then
		local margin = win.margin or 3
		local bay = (w - margin * 2) / win.cols
		local ww = win.w or math.min(bay * 0.55, 5)
		local wh = win.h or math.min(upperH * 0.58, 7.5)
		for s = win.from or 2, win.to or o.storeys do
			local y0 = if s == 1 then 0 else groundH + (s - 2) * upperH
			local sh = if s == 1 then groundH else upperH
			local yc = y0 + sh * 0.52
			for c = 0, win.cols - 1 do
				local x = -w / 2 + margin + bay * (c + 0.5)
				local skipped = false
				local skips = win.skip
				if skips then
					for _, k in skips do
						if s >= k.s0 and s <= k.s1 and x + ww / 2 > k.x0 and x - ww / 2 < k.x1 then
							skipped = true
						end
					end
				end
				if skipped then
					continue
				end
				local lit = rng:chance(win.lit or 0.12)
				local pane = Kit.detail(
					m,
					L(cf, x, yc, -d / 2 - 0.05),
					Vector3.new(ww, wh, 0.2),
					if lit then Geo.vary(C.windowWarm, rng, 0.1) else Geo.vary(C.windowDim, rng, 0.2),
					if lit then M.Neon else M.Glass
				)
				pane.Name = "Window"
				if lit then
					pane.Transparency = 0.45
					pane:AddTag("LitWindow")
				else
					pane.Reflectance = 0.18
				end
				Kit.detail(m, L(cf, x, yc - wh / 2 - 0.2, -d / 2 - 0.35), Vector3.new(ww + 1, 0.45, 0.8), trim, M.Concrete)
				if win.style == "arched" then
					Kit.detail(m, L(cf, x, yc + wh / 2 + 0.6, -d / 2 - 0.15), Vector3.new(ww + 1.2, 1.2, 0.4), trim, M.Limestone)
				else
					Kit.detail(m, L(cf, x, yc + wh / 2 + 0.35, -d / 2 - 0.12), Vector3.new(ww + 0.8, 0.7, 0.3), Kit.shade(color, -0.25), M.Brick)
				end
				if win.ac and rng:chance(win.ac) then
					Kit.detail(m, L(cf, x + rng:range(-0.6, 0.6), yc - wh * 0.22, -d / 2 - 0.9), Vector3.new(2.4, 1.6, 1.8), Geo.vary(hex("#BDB7A8"), rng, 0.1), M.Metal)
				end
			end
		end
	end

	-- painted windows, grime and ghost signs on the other faces (one SurfaceGui per face)
	local painted: { PaintedSpec } = o.painted or {}
	local frontPainted = false
	for _, spec in painted do
		if spec.face == "front" then
			frontPainted = true
		end
		local face = FACES[spec.face]
		if face then
			local target: BasePart = body
			local gui, W, H = Paint.surface(target, face, 6)
			gui.Name = "Facade_" .. spec.face
			local rows = spec.rows or o.storeys - 1
			Paint.windows(gui, W, H, rng, {
				cols = spec.cols,
				rows = rows,
				top = 0.06,
				bottom = math.clamp(groundH / h, 0.05, 0.5),
				lit = spec.lit or 0.12,
				boarded = 0.05,
				acUnits = spec.ac,
			})
			if o.grime ~= false then
				Paint.grime(gui, W, H, rng, { streaks = math.floor(W / 40) + 4 })
			end
			if spec.ghost then
				local g = Instance.new("Frame")
				g.BackgroundTransparency = 1
				g.Size = UDim2.fromScale(0.5, 0.22)
				g.Position = UDim2.fromScale(rng:range(0.1, 0.4), 0.12)
				g.Parent = gui
				Paint.ghostSign(g, spec.ghost[1], spec.ghost[2])
			end
		end
	end
	if not frontPainted and (o.grime ~= false or o.graffiti) then
		local target: BasePart = body
		if o.shop then
			-- the front of a shop building is the upper mass; grime goes there
			local upper = m:FindFirstChild("Upper")
			if upper and upper:IsA("BasePart") then
				target = upper
			end
		end
		local gui, W, H = Paint.surface(target, Enum.NormalId.Front, 5)
		gui.Name = "Facade_front"
		if o.grime ~= false then
			Paint.grime(gui, W, H, rng, { streaks = math.floor(W / 30) + 3, soot = 0.08 })
		end
		if o.graffiti and not o.shop then
			for _, t in o.graffiti do
				Paint.graffiti(gui, W, H, rng, t)
			end
		end
	end
	if o.graffiti and o.shop then
		-- tags low on a side wall, where they really go
		local gui, W, H = Paint.surface(body, FACES[o.graffitiFace or "left"] or Enum.NormalId.Left, 5)
		gui.Name = "Tags"
		for _, t in o.graffiti do
			Paint.graffiti(gui, W, H, rng, t, { y = rng:range(0.82, 0.9), h = 0.08, x = rng:range(0.05, 0.6), w = 0.3 })
		end
	end

	if o.roof then
		Buildings.roof(m, cf, w, d, h + 0.6, rng, o.roof)
	end

	if o.fireEscape then
		local fe = o.fireEscape
		Props.build("fire_escape", m, L(cf, fe.x, 0, -d / 2 - 0.1), {
			floors = fe.floors,
			storey = math.clamp(upperH, 8, 16),
			seed = Deps.Hash.u32(tostring(o.seed), "fe"),
		})
	end

	return m, { cf = cf, w = w, d = d, h = h, front = front, model = m, rng = rng }
end

---------------------------------------------------------------------------------------------------
-- Storefronts
---------------------------------------------------------------------------------------------------
export type StoreOpts = {
	height: number, -- shop height (the sign band sits at the top)
	sign: string?,
	signSub: string?,
	signStyle: string?, -- Signs.buildingName style ("paint" | "lightbox" | "neon") or "band" (painted fascia)
	signColor: Color3?,
	signInk: Color3?,
	door: number?, -- door centre offset along the front (default 0)
	doorWidth: number?,
	open: boolean?, -- an open doorway you can walk through (enterable shop)
	awning: Color3?,
	awningStripe: Color3?,
	grille: number?, -- 0..1: how far the roller shutter is pulled down over the glass
	glass: Color3?,
	frame: Color3?,
	bulkhead: Color3?,
	seed: any?,
	-- a walk-up service window: an open bay in the glass (x centre, width, counter-ledge height)
	hatch: { x: number, w: number, sill: number }?,
}

-- frontCf: on the building's front plane at ground level, centred, LookVector out to the street.
function Buildings.storefront(parent: Instance, frontCf: CFrame, width: number, o: StoreOpts): Model
	local rng = Deps.Rng.new(o.seed or o.sign or "store")
	local m = Kit.model(parent, "Storefront")
	local H = o.height
	local frameC = o.frame or Geo.vary(hex("#2B2D2F"), rng, 0.1)
	local glassC = o.glass or hex("#6E8088")
	local bulk = o.bulkhead or Geo.vary(C.concreteDark, rng, 0.08)
	local dw = o.doorWidth or 6
	local dx = o.door or 0
	local glassTop = H - 3.2
	local doorTop = 9
	-- bulkhead and glass either side of the door
	local segments = { { -width / 2 + 0.6, dx - dw / 2 }, { dx + dw / 2, width / 2 - 0.6 } }
	local hatch = o.hatch
	if hatch then
		-- cut the hatch bay out of whichever glass run holds it
		local ha, hb = hatch.x - hatch.w / 2, hatch.x + hatch.w / 2
		local split = {}
		for _, seg in segments do
			if hb <= seg[1] or ha >= seg[2] then
				table.insert(split, seg)
			else
				table.insert(split, { seg[1], math.max(seg[1], ha) })
				table.insert(split, { math.min(seg[2], hb), seg[2] })
			end
		end
		segments = split
		-- the bay itself: a raised bulkhead, a worn counter ledge and frame posts, open above
		local sill = hatch.sill
		Kit.block(m, L(frontCf, hatch.x, sill / 2, -0.4), Vector3.new(hatch.w, sill, 0.8), bulk, M.Concrete).Name =
			"HatchBulkhead"
		Kit.block(m, L(frontCf, hatch.x, sill + 0.15, -0.9), Vector3.new(hatch.w + 0.4, 0.3, 1.8), Geo.vary(hex("#6B4E35"), rng, 0.1), M.Wood).Name =
			"HatchLedge"
		for _, sx in { -1, 1 } do
			Kit.detail(m, L(frontCf, hatch.x + sx * (hatch.w / 2), sill + (glassTop - sill) / 2, -0.45), Vector3.new(0.4, glassTop - sill, 0.5), frameC, M.Metal)
		end
	end
	for _, seg in segments do
		local a, b = seg[1], seg[2]
		local len = b - a
		if len > 0.5 then
			local cx = (a + b) / 2
			Kit.block(m, L(frontCf, cx, 1.5, -0.4), Vector3.new(len, 2.4, 0.8), bulk, M.Concrete).Name = "Bulkhead"
			local g = Kit.block(m, L(frontCf, cx, 2.7 + (glassTop - 2.7) / 2, -0.2), Vector3.new(len, glassTop - 2.7, 0.3), glassC, M.Glass)
			g.Name = "ShopGlass"
			g.Transparency = 0.45
			g.Reflectance = 0.15
			g.CastShadow = false
			-- a mullion splitting long panes
			if len > 12 then
				Kit.detail(m, L(frontCf, cx, 2.7 + (glassTop - 2.7) / 2, -0.45), Vector3.new(0.4, glassTop - 2.7, 0.3), frameC, M.Metal)
			end
		end
	end
	-- door frame, transom and the door itself
	for _, sx in { -1, 1 } do
		Kit.detail(m, L(frontCf, dx + sx * (dw / 2 + 0.2), doorTop / 2 + 0.5, -0.45), Vector3.new(0.4, doorTop, 0.5), frameC, M.Metal)
	end
	Kit.detail(m, L(frontCf, dx, glassTop - 0.2, -0.45), Vector3.new(width - 1.2, 0.5, 0.5), frameC, M.Metal)
	if glassTop > doorTop + 0.6 then
		local tr = Kit.block(m, L(frontCf, dx, doorTop + 0.5 + (glassTop - doorTop - 0.5) / 2, -0.2), Vector3.new(dw, glassTop - doorTop - 0.5, 0.3), glassC, M.Glass)
		tr.Transparency = 0.45
		tr.CastShadow = false
	end
	if o.open then
		-- the door leaf stands open against the jamb
		local leaf = Kit.detail(m, L(frontCf, dx - dw / 2 + 0.1, doorTop / 2 + 0.5, 1.5) * CFrame.Angles(0, math.rad(80), 0), Vector3.new(3, doorTop - 0.4, 0.2), glassC, M.Glass)
		leaf.Transparency = 0.4
	else
		local door = Kit.block(m, L(frontCf, dx, doorTop / 2 + 0.5, -0.2), Vector3.new(dw, doorTop - 0.2, 0.3), glassC, M.Glass)
		door.Name = "ShopDoor"
		door.Transparency = 0.35
		Kit.detail(m, L(frontCf, dx, 4.2, -0.45), Vector3.new(dw * 0.7, 0.25, 0.3), hex("#B8B8B0"), M.Metal)
	end
	-- the sign band
	local bandC = o.signColor or Geo.vary(hex("#1F2A30"), rng, 0.15)
	local band = Kit.detail(m, L(frontCf, 0, H - 1.5, -0.55), Vector3.new(width - 0.4, 3, 0.5), bandC, M.SmoothPlastic)
	band.Name = "SignBand"
	if o.sign then
		local style = o.signStyle or "band"
		if style == "band" then
			Kit.sign(band, o.sign, {
				font = Enum.Font.Oswald,
				color = o.signInk or C.paper,
				pixelsPerStud = 24,
				padding = 0.12,
			})
		else
			Signs.buildingName(m, L(frontCf, 0, H - 2.7, -0.8), {
				text = o.sign,
				style = style,
				height = 2.0,
				width = math.min(width - 2, #o.sign * 1.6 + 4),
				color = o.signInk,
				seed = o.seed,
			})
		end
	end
	if o.signSub then
		local sub = Kit.detail(m, L(frontCf, 0, glassTop - 1.0, -0.38), Vector3.new(width - 3, 1.1, 0.05), Color3.new(1, 1, 1), M.SmoothPlastic)
		sub.Transparency = 1
		Kit.sign(sub, o.signSub, { font = Enum.Font.SpecialElite, color = C.paper, pixelsPerStud = 30, padding = 0.05 })
	end
	if o.awning then
		-- a canvas sheet sloping down and out from just under the sign band, with a striped valance
		local depth = 4.5
		local tilt = math.rad(22)
		local topY = H - 3.4
		local aw = Kit.detail(
			m,
			L(frontCf, 0, topY - (depth / 2) * math.tan(tilt), -depth / 2 - 0.3) * CFrame.Angles(-tilt, 0, 0),
			Vector3.new(width - 0.6, 0.25, depth / math.cos(tilt)),
			o.awning,
			M.Fabric
		)
		aw.Name = "Awning"
		local val = Kit.detail(
			m,
			L(frontCf, 0, topY - depth * math.tan(tilt) - 0.45, -depth - 0.35),
			Vector3.new(width - 0.6, 0.9, 0.1),
			o.awning,
			M.Fabric
		)
		if o.awningStripe then
			local gui = Paint.surface(val, Enum.NormalId.Front, 10)
			Deps.Gui.Core.stripes(Deps.Gui.Core.bg(gui, o.awning), { o.awning, o.awningStripe }, 9, 0)
		end
	end
	if o.grille and o.grille > 0 then
		local gh = (glassTop - 2.7) * o.grille
		local sh = Kit.detail(m, L(frontCf, 0, glassTop - gh / 2, -0.7), Vector3.new(width - 1.2, gh, 0.15), Geo.vary(C.steel, rng, 0.1), M.CorrodedMetal)
		sh.Name = "Shutter"
		Kit.detail(m, L(frontCf, 0, glassTop + 0.4, -0.85), Vector3.new(width - 1, 0.9, 0.9), Geo.vary(C.steel, rng, 0.1), M.CorrodedMetal)
	end
	return m
end

-- A painted "FOR LEASE" sheet or poster taped inside a shop window (cheap: one transparent carrier part).
function Buildings.windowPoster(parent: Instance, cf: CFrame, size: Vector3, title: string, body: string?, seed: any)
	local rng = Deps.Rng.new(seed)
	local p = Kit.detail(parent, cf, size, Color3.new(1, 1, 1), M.SmoothPlastic)
	p.Transparency = 1
	local gui = Paint.surface(p, Enum.NormalId.Front, 30)
	Deps.Gui.Art.poster(gui, title, body or "", { hex("#F4F1EA"), hex("#C8553D"), hex("#1A1A1A") }, rng)
	return p
end

Buildings.Text = Text

return Buildings
