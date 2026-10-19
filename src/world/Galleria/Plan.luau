--!strict
-- The Galleria floor plan (local frame around the interior slot origin: +X east, +Z south, floor top at y = 0). Pure
-- numbers and CFrames: the builders and the tests both read it. Bake-safe.
--
--   the atrium      x in [-AX, AX], z in [-Z, Z], ceiling at ATRIUM_H, a glass barrel vault (radius VAULT_R, spring
--                   line VAULT_SPRING) over z in [-VAULT_Z, VAULT_Z] under a painted sky box; the street doors in
--                   the south wall (z = Z)
--   four boutiques  DEPTH deep behind glazed shopfronts on the atrium's long sides, two per side either side of a
--                   partition at z in [-PART_HALF, PART_HALF]:
--                       west / north  Hartwell Tailors (tailor)       east / north  Strider Shoes (shoes)
--                       west / south  Vanta Watches (watch)           east / south  Atelier Maison (decor)
--
--   Plan.shops = { ShopSpot }   ShopSpot = { id (Config/Shop id), model, side, half, cz, frame }
--       frame = CFrame (relative to the venue origin) at the centre of the shopfront's atrium face, at floor level,
--       LookVector into the boutique. Boutique-local: sx along the front (-HALF_L..HALF_L), sd = depth from the
--       atrium face (0..DEPTH; the shopfront wall itself takes 0..FRONT_T).
--   Plan.point(frame, sx, y, sd) -> CFrame     a point in a boutique frame (same orientation as the frame)
--   Plan.shop(id) -> ShopSpot?

local Plan = {}

-- shell
Plan.X = 46 -- the boutiques' back walls (inner faces at x = +/-X)
Plan.Z = 45 -- the end walls (inner faces at z = +/-Z)
Plan.WALL = 1

-- atrium
Plan.AX = 18 -- shopfront planes at x = +/-AX
Plan.ATRIUM_H = 36 -- underside of the atrium ceiling
Plan.SLAB = 1
Plan.VAULT_R = 13
Plan.VAULT_SPRING = Plan.ATRIUM_H + Plan.SLAB -- the vault stands on the ceiling slab's inner edges
Plan.VAULT_Z = 38 -- the gables' inner faces
Plan.VAULT_SEGMENTS = 6
Plan.RIB_Z = { -38, -30, -15, 0, 15, 30, 38 }
Plan.SKY_X = 17 -- the sky box around the vault
Plan.SKY_TOP = 54
Plan.PILASTER_Z = { -45, -30, -15, 0, 15, 30, 45 }

-- boutiques
Plan.FRONT_T = 1
Plan.DEPTH = Plan.X - Plan.AX -- 28
Plan.PART_HALF = 1
Plan.HALF_L = (Plan.Z - Plan.PART_HALF) / 2 -- 22: each boutique runs 44 along the atrium
Plan.SHOP_H = 14 -- boutique clear height
Plan.FRONT_H = 16 -- top of the shopfronts (the upper atrium wall starts here)
Plan.DOOR_W = 8
Plan.DOOR_H = 10.5
Plan.GLASS_Y0 = 1.2 -- stall riser height
Plan.PIER = 1 -- solid piers at the shopfront ends and either side of the door
Plan.WINDOW_D = 4.5 -- display-window plinth depth behind the glass

-- the entrance
Plan.ENTRY_Z = Plan.Z - 10 -- arrival point, 10 studs inside the doors

export type ShopSpot = {
	id: string,
	model: string,
	side: string,
	half: string,
	cz: number,
	frame: CFrame,
}

local CZ = Plan.PART_HALF + Plan.HALF_L

local SHOPS: { { id: string, model: string, side: string, half: string } } = {
	{ id = "tailor", model = "HartwellTailors", side = "west", half = "north" },
	{ id = "watch", model = "VantaWatches", side = "west", half = "south" },
	{ id = "shoes", model = "StriderShoes", side = "east", half = "north" },
	{ id = "decor", model = "AtelierMaison", side = "east", half = "south" },
}

local function spot(def: { id: string, model: string, side: string, half: string }): ShopSpot
	local cz = if def.half == "north" then -CZ else CZ
	local west = def.side == "west"
	local x = if west then -Plan.AX else Plan.AX
	-- west boutiques look west (-X), east boutiques look east (+X)
	local yaw = if west then math.pi / 2 else -math.pi / 2
	return {
		id = def.id,
		model = def.model,
		side = def.side,
		half = def.half,
		cz = cz,
		frame = CFrame.new(x, 0, cz) * CFrame.Angles(0, yaw, 0),
	}
end

Plan.shops = {} :: { ShopSpot }
for _, def in SHOPS do
	table.insert(Plan.shops, spot(def))
end

function Plan.shop(id: string): ShopSpot?
	for _, s in Plan.shops do
		if s.id == id then
			return s
		end
	end
	return nil
end

function Plan.point(frame: CFrame, sx: number, y: number, sd: number): CFrame
	return frame * CFrame.new(sx, y, -sd)
end

return Plan
