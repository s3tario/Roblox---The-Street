--!strict
-- Street-level entrances (lot frame, see Mass): the ground storey of a building with its lobby, doors, the door
-- trigger (Kit.door) and the exterior front anchor (Kit.anchor). Two layouts:
--
--   "arcade"  a colonnade: the upper building overhangs a covered walk, behind it a glass lobby wall with
--             revolving doors and a lit lobby (marble floor, back wall, reception desk). Solid end piers.
--   "portal"  a solid base with storefront windows and a recessed stone doorway holding bronze-and-glass doors,
--             optionally under a canopy (cantilevered, or a residential marquee on posts to the curb).
--
-- The door trigger stands where the physical doors are, front face toward the approaching player. The anchor
-- stands 3 studs above the sidewalk in front of the door, facing the street (where players arrive when they leave
-- the lobby). Doorways are at least 6 wide and 10 tall; the doors themselves are closed (the trigger opens the
-- lobby instance), and revolving drums are filled with an invisible collider so nobody can wedge inside.
--
--   Entrance.build(parent, frame, spec) -> Result
--     Result = { model, door, anchor, fascia (lot CFrame: bottom-centre of the sign band on the facade, LookVector
--                out), fasciaWidth, fasciaHeight, top (lot y where the upper building starts) }
--   The sign band always sits on flat stone (an entablature over the arcade, plain stone over a portal), never on
--   a window grid.

local Deps = require(script.Parent.Deps)
local Look = require(script.Parent.Look)
local Mass = require(script.Parent.Mass)

local Kit = Deps.Kit
local Props = Deps.Props
local M = Enum.Material

local Entrance = {}

export type Spec = {
	w: number,
	d: number,
	bh: number, -- ground-storey height
	mode: string, -- "arcade" | "portal"
	doorId: string,
	anchorId: string,
	seed: string,
	stone: Color3, -- base stone
	stoneMat: Enum.Material,
	trim: Color3?, -- metal trim (brass / bronze)
	-- arcade
	recess: number?, -- glass line depth behind the building line (default 8)
	lobbyDepth: number?, -- lobby back wall depth (default 22)
	endPier: number?, -- solid end pier width (default 7)
	columns: number?, -- free-standing columns along the front (default by width)
	round: boolean?, -- round columns (default square)
	revolving: number?, -- revolving doors (1 or 2, default 1)
	lobbyWall: Color3?,
	lobbyLight: Color3?,
	-- portal
	doorWidth: number?, -- doorway width (default 12)
	doorHeight: number?, -- doorway height (default 12)
	shopLook: Mass.FacadeLook?, -- storefront windows either side of the doorway
	canopy: string?, -- nil | "cantilever" | "marquee"
	canopyColor: Color3?,
	canopyText: string?,
	-- both
	signRoom: number?, -- flat stone band reserved above the doors for the name (arcade 9, portal 7)
	anchorDepth: number?, -- how far in front of the facade the anchor stands (default 6)
	lit: boolean?,
}

export type Result = {
	model: Model,
	door: Part,
	anchor: Part,
	fascia: CFrame,
	fasciaWidth: number,
	fasciaHeight: number, -- room for the sign band (studs)
	top: number,
}

local function box(x0: number, x1: number, z0: number, z1: number, y0: number, y1: number): Mass.Box
	return { x0 = x0, x1 = x1, z0 = z0, z1 = z1, y0 = y0, y1 = y1 }
end

local function light(part: BasePart, color: Color3, range: number, brightness: number)
	Kit.light(part, "point", { Color = color, Range = range, Brightness = brightness })
end

-- Glass sheet segments across [x0, x1] at depth z, leaving gaps around each door centre.
local function glassWall(
	m: Instance,
	frame: CFrame,
	x0: number,
	x1: number,
	z: number,
	h: number,
	gaps: { number },
	gapW: number,
	trim: Color3
)
	local cuts: { { number } } = {}
	for _, gx in gaps do
		table.insert(cuts, { gx - gapW / 2, gx + gapW / 2 })
	end
	table.sort(cuts, function(a, b)
		return a[1] < b[1]
	end)
	local cursor = x0
	local spans: { { number } } = {}
	for _, c in cuts do
		table.insert(spans, { cursor, c[1] })
		cursor = c[2]
	end
	table.insert(spans, { cursor, x1 })
	for _, s in spans do
		local len = s[2] - s[1]
		if len > 0.3 then
			local g = Kit.block(
				m,
				frame * CFrame.new((s[1] + s[2]) / 2, h / 2, z),
				Vector3.new(len, h, 0.4),
				Look.lobbyGlass,
				M.Glass,
				{ Transparency = 0.55, Reflectance = 0.2, CastShadow = false }
			)
			g.Name = "LobbyGlass"
			-- brass mullions every ~8 studs and a transom at door height
			local n = math.max(1, math.floor(len / 8 + 0.5))
			for i = 1, n - 1 do
				local x = s[1] + len * i / n
				Kit.detail(m, frame * CFrame.new(x, h / 2, z - 0.25), Vector3.new(0.35, h, 0.3), trim, M.Metal)
			end
			Kit.detail(
				m,
				frame * CFrame.new((s[1] + s[2]) / 2, math.min(12, h - 1), z - 0.25),
				Vector3.new(len, 0.35, 0.3),
				trim,
				M.Metal
			)
		end
	end
	-- head rail across the whole glass line
	Kit.detail(m, frame * CFrame.new((x0 + x1) / 2, h - 0.3, z - 0.3), Vector3.new(x1 - x0, 0.6, 0.5), trim, M.Metal)
end

local function arcade(m: Model, frame: CFrame, s: Spec): Result
	local w, d, bh = s.w, s.d, s.bh
	local rc = s.recess or 8
	local ld = math.min(s.lobbyDepth or 22, d - 6)
	local ep = s.endPier or 7
	local trim = s.trim or Look.brass
	local wall = s.lobbyWall or Look.marble
	local rng = Deps.Rng.new(s.seed)
	-- solid ground storey: end piers and the block behind the lobby
	for _, sx in { -1, 1 } do
		local xa, xb = sx * (w / 2 - ep), sx * w / 2
		Mass.slab(m, frame, box(math.min(xa, xb), math.max(xa, xb), 0, ld, 0, bh), s.stone, s.stoneMat).Name = "Pier"
		-- base course and a brass band on each pier face
		Mass.slab(
			m,
			frame,
			box(math.min(xa, xb) - 0.3, math.max(xa, xb) + 0.3, -0.3, ld, 0, 2.2),
			Kit.shade(s.stone, -0.25),
			M.Granite,
			false
		)
	end
	Mass.slab(m, frame, box(-w / 2, w / 2, ld, d, 0, bh), s.stone, s.stoneMat).Name = "BaseBlock"
	-- doors
	local nRev = math.clamp(s.revolving or 1, 1, 2)
	local doorXs: { number } = if nRev == 2 then { -6.5, 6.5 } else { 0 }
	for i, x in doorXs do
		Props.build("revolving_door", m, frame * CFrame.new(x, 0, rc), { seed = s.seed .. ":rev" .. i, accent = trim })
		local blocker = Kit.block(m, frame * CFrame.new(x, 4.75, rc), Vector3.new(7.4, 9.5, 7.4), Look.white, M.Glass, {
			Transparency = 1,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
		})
		blocker.Name = "DoorBlocker"
	end
	local gapW = 8.9
	glassWall(m, frame, -w / 2 + ep, w / 2 - ep, rc, bh, doorXs, gapW, trim)
	-- glass over each drum up to the head rail
	for _, x in doorXs do
		if bh > 10.2 then
			Kit.block(
				m,
				frame * CFrame.new(x, (9.8 + bh) / 2, rc),
				Vector3.new(gapW, bh - 9.8, 0.4),
				Look.lobbyGlass,
				M.Glass,
				{ Transparency = 0.55, Reflectance = 0.2, CastShadow = false }
			).Name =
				"Transom"
		end
	end
	-- the lobby behind the glass (seen, never entered)
	local lx0, lx1 = -w / 2 + ep, w / 2 - ep
	Mass.slab(m, frame, box(lx0, lx1, rc + 0.2, ld, 0, 0.08), Look.marble, M.Marble, false).Name = "LobbyFloor"
	local back = Mass.slab(m, frame, box(lx0, lx1, ld - 0.3, ld, 0, bh), wall, M.Marble, false)
	back.Name = "LobbyWall"
	local deskW = math.min(16, (lx1 - lx0) * 0.4)
	Mass.slab(m, frame, box(-deskW / 2, deskW / 2, ld - 6, ld - 3.5, 0, 3.6), Look.walnut, M.Wood, false).Name =
		"ReceptionDesk"
	Mass.slab(
		m,
		frame,
		box(-deskW / 2 - 0.1, deskW / 2 + 0.1, ld - 6.1, ld - 3.4, 3.6, 3.85),
		Look.blackGranite,
		M.Granite,
		false
	)
	local glow = Mass.slab(
		m,
		frame,
		box(lx0 + 2, lx1 - 2, rc + 2, ld - 2, bh - 0.4, bh - 0.2),
		s.lobbyLight or Look.warmLight,
		M.Neon,
		false
	)
	glow.Name = "LobbyLight"
	glow.Transparency = 0.25
	glow.CastShadow = false
	glow:AddTag("InteriorLight")
	light(glow, s.lobbyLight or Look.warmLight, 26, 1.2)
	-- columns along the front of the arcade, kept clear of the doors
	local span = (w - 2 * ep)
	local n = s.columns or math.max(2, math.floor(span / 14))
	local colZ = math.max(1.6, rc * 0.4)
	for i = 1, n do
		local x = -span / 2 + span * (i - 0.5) / n
		local clear = true
		for _, dx in doorXs do
			if math.abs(x - dx) < 7.5 then
				clear = false
			end
		end
		if clear then
			if s.round then
				Kit.cylinder(m, frame * CFrame.new(x, bh / 2, colZ), bh, 3.2, s.stone, s.stoneMat).Name = "Column"
				Mass.slab(
					m,
					frame,
					box(x - 2.2, x + 2.2, colZ - 2.2, colZ + 2.2, 0, 1.4),
					Kit.shade(s.stone, -0.2),
					M.Granite,
					false
				)
				Mass.slab(m, frame, box(x - 2.1, x + 2.1, colZ - 2.1, colZ + 2.1, bh - 1.4, bh), trim, M.Metal, false)
			else
				Mass.slab(m, frame, box(x - 1.6, x + 1.6, colZ - 1.6, colZ + 1.6, 0, bh), s.stone, s.stoneMat).Name =
					"Column"
				Mass.slab(m, frame, box(x - 1.75, x + 1.75, colZ - 1.75, colZ + 1.75, 1.6, 2.0), trim, M.Metal, false)
			end
		end
	end
	-- arcade soffit downlights
	for i = 1, 3 do
		local x = -span / 2 + span * (i - 0.5) / 3 + rng:range(-1, 1)
		local dl = Mass.slab(
			m,
			frame,
			box(x - 1.2, x + 1.2, rc * 0.5 - 1.2, rc * 0.5 + 1.2, bh - 0.12, bh - 0.02),
			Look.lampGlow,
			M.Neon,
			false
		)
		dl.CastShadow = false
		dl:AddTag("StreetLight")
	end
	-- the trigger in front of the drums (all doors share one trigger) and the anchor on the sidewalk
	local doorSpan = (doorXs[#doorXs] - doorXs[1]) + gapW + 1
	local door = Kit.door(m, s.doorId, frame * CFrame.new(0, 5.2, rc - 4.4 - 1.2), Vector3.new(doorSpan, 10, 2.4))
	door.Name = s.doorId
	local anchor = Kit.anchor(m, s.anchorId, frame * CFrame.new(0, 3, -(s.anchorDepth or 6)))
	-- entablature over the colonnade: flat stone for the name, a cornice lip above
	local room = s.signRoom or 9
	Mass.slab(m, frame, box(-w / 2, w / 2, 0, d, bh, bh + room), s.stone, s.stoneMat).Name = "Entablature"
	Mass.slab(
		m,
		frame,
		box(-w / 2 - 0.6, w / 2 + 0.6, -0.8, d, bh + room - 0.9, bh + room),
		Kit.shade(s.stone, 0.08),
		s.stoneMat,
		false
	)
	Mass.slab(m, frame, box(-w / 2 - 0.2, w / 2 + 0.2, -0.3, 0.6, bh - 0.1, bh + 0.5), trim, M.Metal, false)
	return {
		model = m,
		door = door,
		anchor = anchor,
		fascia = CFrame.new(0, bh + 1.0, 0),
		fasciaWidth = w - 2 * ep - 4,
		fasciaHeight = room - 2.3,
		top = bh + room,
	}
end

local function doorPair(
	m: Instance,
	frame: CFrame,
	x: number,
	z: number,
	w: number,
	h: number,
	trim: Color3,
	lit: boolean
)
	-- warm lobby glow behind dark glass leaves in a bronze frame
	local glow = Kit.detail(m, frame * CFrame.new(x, h / 2, z + 0.6), Vector3.new(w, h, 0.1), Look.lampGlow, M.Neon)
	glow.Transparency = if lit then 0.35 else 0.7
	glow.CastShadow = false
	glow:AddTag("InteriorLight")
	local leaf = Kit.block(m, frame * CFrame.new(x, h / 2, z), Vector3.new(w, h, 0.3), Look.glassBronze, M.Glass, {
		Transparency = 0.35,
		Reflectance = 0.2,
		CastShadow = false,
	})
	leaf.Name = "Doors"
	Kit.detail(m, frame * CFrame.new(x, h / 2, z - 0.2), Vector3.new(0.4, h, 0.3), trim, M.Metal)
	Kit.detail(m, frame * CFrame.new(x, h * 0.72, z - 0.2), Vector3.new(w, 0.35, 0.3), trim, M.Metal)
	for _, sx in { -1, 1 } do
		Kit.detail(
			m,
			frame * CFrame.new(x + sx * (w / 2 - 0.2), h / 2, z - 0.2),
			Vector3.new(0.4, h, 0.35),
			trim,
			M.Metal
		)
		Kit.detail(
			m,
			frame * CFrame.new(x + sx * 0.9, 4.2, z - 0.4),
			Vector3.new(0.18, 2.6, 0.18),
			Look.goldBright,
			M.Metal
		)
	end
end

local function portal(m: Model, frame: CFrame, s: Spec): Result
	local w, d = s.w, s.d
	local aw = math.max(s.doorWidth or 12, 7)
	local ah = math.max(s.doorHeight or 12, 10)
	local ad = 4
	local trim = s.trim or Look.bronze
	-- the name band goes above the doorway (and above the canopy); the base grows to make room for it
	local fasciaY = if s.canopy == "marquee" then ah + 3.2 elseif s.canopy then ah + 3.6 else ah + 2.0
	local room = s.signRoom or 7
	local bh = math.max(s.bh, fasciaY + room)
	-- solid base around a recessed doorway
	Mass.slab(m, frame, box(-w / 2, -aw / 2, 0, d, 0, bh), s.stone, s.stoneMat).Name = "BaseLeft"
	Mass.slab(m, frame, box(aw / 2, w / 2, 0, d, 0, bh), s.stone, s.stoneMat).Name = "BaseRight"
	Mass.slab(m, frame, box(-aw / 2, aw / 2, 0, d, ah, bh), s.stone, s.stoneMat).Name = "Lintel"
	Mass.slab(m, frame, box(-aw / 2, aw / 2, ad, d, 0, ah), s.stone, s.stoneMat).Name = "DoorBack"
	-- granite plinth along the base
	Mass.slab(m, frame, box(-w / 2 - 0.2, -aw / 2 - 1.2, -0.3, 0.1, 0, 2), Kit.shade(s.stone, -0.3), M.Granite, false)
	Mass.slab(m, frame, box(aw / 2 + 1.2, w / 2 + 0.2, -0.3, 0.1, 0, 2), Kit.shade(s.stone, -0.3), M.Granite, false)
	-- stone surround
	local sur = Kit.shade(s.stone, 0.12)
	for _, sx in { -1, 1 } do
		Mass.slab(m, frame, box(sx * aw / 2 - 1.2, sx * aw / 2 + 1.2, -0.6, 0, 0, ah + 1.2), sur, s.stoneMat, false)
	end
	Mass.slab(m, frame, box(-aw / 2 - 1.2, aw / 2 + 1.2, -0.7, 0, ah, ah + 1.6), sur, s.stoneMat, false)
	-- marble threshold and the doors at the back of the recess
	Mass.slab(m, frame, box(-aw / 2, aw / 2, 0, ad, 0, 0.06), Look.marble, M.Marble, false)
	doorPair(m, frame, 0, ad - 0.15, aw - 1, math.min(ah - 0.5, 11), trim, s.lit ~= false)
	if ah - 0.5 > 11.6 then
		local tr = Kit.detail(
			m,
			frame * CFrame.new(0, (11 + ah) / 2, ad - 0.15),
			Vector3.new(aw - 1, ah - 11.5, 0.2),
			Look.lampGlow,
			M.Neon
		)
		tr.Transparency = 0.45
		tr.CastShadow = false
		tr:AddTag("InteriorLight")
	end
	-- storefront windows either side
	if s.shopLook then
		for _, sx in { -1, 1 } do
			local x0 = if sx < 0 then -w / 2 + 2 else aw / 2 + 3
			local x1 = if sx < 0 then -aw / 2 - 3 else w / 2 - 2
			local wh = ah - 3
			if x1 - x0 >= 6 and wh >= 4 then
				local cf = frame * CFrame.new((x0 + x1) / 2, 2.4 + wh / 2, -0.11)
				Mass.grid(m, cf, x1 - x0, wh, s.shopLook, s.seed .. ":shop" .. sx, { rows = 1, lit = 0.6 })
			end
		end
	end
	-- canopy
	if s.canopy then
		local cc = s.canopyColor or Look.black
		local cw = aw + 6
		if s.canopy == "marquee" then
			-- residential marquee out to the curb on brass posts
			local depth = 12.5
			local cy = ah + 1.2
			Mass.slab(m, frame, box(-cw / 2, cw / 2, -depth, -0.1, cy, cy + 1.4), cc, M.Fabric).Name = "Canopy"
			Mass.slab(
				m,
				frame,
				box(-cw / 2 - 0.1, cw / 2 + 0.1, -depth - 0.1, -0.1, cy - 0.3, cy),
				trim,
				M.Metal,
				false
			)
			for _, sx in { -1, 1 } do
				Kit.cylinder(m, frame * CFrame.new(sx * (cw / 2 - 0.4), cy / 2, -depth + 0.5), cy, 0.35, trim, M.Metal)
				Kit.cylinder(
					m,
					frame * CFrame.new(sx * (cw / 2 - 0.4), 0.15, -depth + 0.5),
					0.3,
					1.1,
					Kit.shade(trim, -0.3),
					M.Metal,
					{ CanCollide = false }
				)
			end
			local front =
				Kit.detail(m, frame * CFrame.new(0, cy + 0.7, -depth - 0.12), Vector3.new(cw, 1.2, 0.1), cc, M.Fabric)
			if s.canopyText then
				Kit.sign(front, s.canopyText, { color = Look.gold, font = Enum.Font.Garamond, pixelsPerStud = 50 })
			end
			for _, sx in { -1, 1 } do
				local side = Kit.detail(
					m,
					frame * CFrame.new(sx * (cw / 2 + 0.06), cy + 0.7, -depth / 2),
					Vector3.new(0.1, 1.2, depth),
					cc,
					M.Fabric
				)
				if s.canopyText then
					Kit.sign(side, s.canopyText, {
						face = if sx > 0 then Enum.NormalId.Right else Enum.NormalId.Left,
						color = Look.gold,
						font = Enum.Font.Garamond,
						pixelsPerStud = 30,
					})
				end
			end
			local under = Kit.detail(
				m,
				frame * CFrame.new(0, cy - 0.35, -depth / 2),
				Vector3.new(1.4, 0.1, 1.4),
				Look.lampGlow,
				M.Neon
			)
			under.CastShadow = false
			under:AddTag("StreetLight")
			light(under, Look.lampGlow, 16, 0.9)
		else
			local depth = 7
			local cy = ah + 1.6
			Mass.slab(m, frame, box(-cw / 2, cw / 2, -depth, 0, cy, cy + 0.8), cc, M.Metal).Name = "Canopy"
			Mass.slab(
				m,
				frame,
				box(-cw / 2 - 0.05, cw / 2 + 0.05, -depth - 0.08, -depth + 0.25, cy - 0.15, cy + 1.0),
				trim,
				M.Metal,
				false
			)
			for i = -1, 1 do
				local dl = Kit.detail(
					m,
					frame * CFrame.new(i * cw / 3, cy - 0.06, -depth / 2),
					Vector3.new(1, 0.1, 1),
					Look.lampGlow,
					M.Neon
				)
				dl.CastShadow = false
				dl:AddTag("StreetLight")
			end
			if s.canopyText then
				local f = Kit.detail(
					m,
					frame * CFrame.new(0, cy + 0.42, -depth - 0.13),
					Vector3.new(cw - 1, 0.9, 0.05),
					cc,
					M.Metal
				)
				Kit.sign(f, s.canopyText, { color = Look.gold, font = Enum.Font.Garamond, pixelsPerStud = 50 })
			end
		end
	end
	local door = Kit.door(m, s.doorId, frame * CFrame.new(0, 5.2, ad / 2 - 0.4), Vector3.new(aw - 1, 10, ad + 0.8))
	door.Name = s.doorId
	local anchor = Kit.anchor(m, s.anchorId, frame * CFrame.new(0, 3, -(s.anchorDepth or 6)))
	return {
		model = m,
		door = door,
		anchor = anchor,
		fascia = CFrame.new(0, fasciaY, 0),
		fasciaWidth = math.min(w - 6, math.max(aw + 10, w * 0.6)),
		fasciaHeight = bh - fasciaY - 0.8,
		top = bh,
	}
end

function Entrance.build(parent: Instance, frame: CFrame, s: Spec): Result
	local m = Kit.model(parent, "Entrance")
	if s.mode == "arcade" then
		return arcade(m, frame, s)
	end
	return portal(m, frame, s)
end

return Entrance
