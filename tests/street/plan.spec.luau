-- The Street's layout data (src/world/Street/Plan): lots for every tower, no overlapping buildings, buildings off
-- the roads and sidewalks, no gaps between buildings too narrow to walk through, street furniture and event spots
-- where they belong, and every text key the plan names present in Street/Text.

local Shared = game:GetService("ReplicatedStorage").Shared
local World = require(Shared.Config.World)
local Builders = game:GetService("ServerStorage").WorldBuilders
local Plan = require(Builders.Street.Plan)
local Text = require(Builders.Street.Text)

local function overlaps(a: Plan.Rect, b: Plan.Rect): boolean
	return a.x0 < b.x1 - 0.01 and b.x0 < a.x1 - 0.01 and a.z0 < b.z1 - 0.01 and b.z0 < a.z1 - 0.01
end

local function onSidewalkOrRoad(x: number, z: number): boolean
	return Plan.inRoad(x, z, Plan.SIDEWALK - 0.01)
end

return function(t)
	t.describe("lots", function()
		t.it("gives every tower in Config/World a lot", function()
			local lots = Plan.assignLots(World.towers)
			for _, tower in World.towers do
				t.expect(lots[tower.id] ~= nil).toBeTruthy()
			end
		end)

		t.it("hands spare lots to towers added later, in order", function()
			local towers = table.clone(World.towers) :: { any }
			table.insert(towers, { id = "future_tower_a" })
			table.insert(towers, { id = "future_tower_b" })
			local lots, spare = Plan.assignLots(towers)
			t.expect(lots.future_tower_a).toBe(Plan.spareLots[1])
			t.expect(lots.future_tower_b).toBe(Plan.spareLots[2])
			t.expect(#spare).toBe(#Plan.spareLots - 2)
		end)

		t.it("never overlaps two lots, venues or the Exchange", function()
			local rects = Plan.rects(World.towers)
			for i, a in rects do
				for j, b in rects do
					if j > i and not string.find(a.id, "^filler") and not string.find(b.id, "^filler") then
						if overlaps(a, b) then
							error(a.id .. " overlaps " .. b.id)
						end
					end
				end
			end
		end)

		t.it("keeps every building off the roads and sidewalks and inside the district", function()
			for _, r in Plan.rects(World.towers) do
				for _, p in
					{
						{ r.x0 + 0.5, r.z0 + 0.5 },
						{ r.x1 - 0.5, r.z0 + 0.5 },
						{ r.x0 + 0.5, r.z1 - 0.5 },
						{ r.x1 - 0.5, r.z1 - 0.5 },
						{ (r.x0 + r.x1) / 2, (r.z0 + r.z1) / 2 },
					}
				do
					if onSidewalkOrRoad(p[1], p[2]) then
						error(("%s reaches the street at (%g, %g)"):format(r.id, p[1], p[2]))
					end
				end
				t.expect(math.max(math.abs(r.x0), math.abs(r.x1), math.abs(r.z0), math.abs(r.z1)))
					.toBeLessThanOrEqual(Plan.EDGE)
				t.expect(r.h).toBeLessThan(World.regions.street.max.Y - 20)
			end
		end)

		t.it("puts every lot front on a building line (the back of a sidewalk)", function()
			local lots = Plan.assignLots(World.towers)
			local all: { Plan.Lot } = {}
			for _, lot in lots do
				table.insert(all, lot)
			end
			for _, lot in Plan.venueLots do
				table.insert(all, lot)
			end
			local P = Plan.plaza
			for _, lot in all do
				local front = Plan.lotFrame(lot) * CFrame.new(0, 0, -1)
				local fx, fz = front.Position.X, front.Position.Z
				local onPlaza = fx > P.x0 and fx < P.x1 and fz > P.z0 and fz < P.z1
				if not (onSidewalkOrRoad(fx, fz) or onPlaza) then
					error(("a lot at %s %g/%g fronts no street or plaza"):format(lot.face, lot.line, lot.at))
				end
				local inside = Plan.lotFrame(lot) * CFrame.new(0, 0, 1)
				t.expect(onSidewalkOrRoad(inside.Position.X, inside.Position.Z)).toBeFalsy()
			end
		end)

		t.it("leaves no gap between buildings narrower than a doorway", function()
			local rects = Plan.rects(World.towers)
			for _, blk in Plan.blocks() do
				if blk.plaza then
					continue
				end
				local S = Plan.SIDEWALK
				local x0 = blk.x0 + (if blk.x0 > -Plan.EDGE then S else 0)
				local x1 = blk.x1 - (if blk.x1 < Plan.EDGE then S else 0)
				local z0 = blk.z0 + (if blk.z0 > -Plan.EDGE then S else 0)
				local z1 = blk.z1 - (if blk.z1 < Plan.EDGE then S else 0)
				local open: { [number]: boolean } = {}
				local nx, nz = math.floor(x1 - x0), math.floor(z1 - z0)
				local function key(i: number, k: number): number
					return i * 10000 + k
				end
				for i = 0, nx - 1 do
					for k = 0, nz - 1 do
						if Plan.heightAt(rects, x0 + i + 0.5, z0 + k + 0.5) == 0 then
							open[key(i, k)] = true
						end
					end
				end
				for kk in open do
					local i, k = kk // 10000, kk % 10000
					local function run(di: number, dk: number): number
						local n, a, b = 0, i, k
						while open[key(a, b)] do
							n += 1
							a += di
							b += dk
						end
						return n
					end
					local across = math.min(run(1, 0) + run(-1, 0) - 1, run(0, 1) + run(0, -1) - 1)
					-- cells on the block's sidewalk edge just widen the sidewalk
					local edge = i == 0 or k == 0 or i == nx - 1 or k == nz - 1
					if across < 6 and not edge then
						error(("narrow gap in block %s at (%g, %g)"):format(blk.id, x0 + i, z0 + k))
					end
				end
			end
		end)
	end)

	t.describe("placements", function()
		t.it("parks every vehicle on a road, clear of the crosswalks", function()
			for i, v in Plan.vehicles do
				t.expect(Plan.inRoad(v.pos.X, v.pos.Z)).toBeTruthy()
				t.expect(Plan.FACE_DIR[v.dir] ~= nil).toBeTruthy()
				for _, it in Plan.intersections() do
					local dx = math.abs(v.pos.X - it.x) - it.ns.w / 2
					local dz = math.abs(v.pos.Z - it.z) - it.ew.w / 2
					if dx < Plan.SIDEWALK + 6 and dz < Plan.SIDEWALK + 6 then
						error("vehicle " .. i .. " stands in an intersection")
					end
				end
			end
		end)

		t.it("stands steam stacks and manholes in the road", function()
			for _, v in Plan.steamVents do
				t.expect(Plan.inRoad(v.X, v.Z, -1)).toBeTruthy()
			end
			for _, v in Plan.manholes do
				t.expect(Plan.inRoad(v.X, v.Z)).toBeTruthy()
			end
		end)

		t.it("keeps kiosks, carts and event spots off the roads and inside the walls", function()
			local points: { Vector3 } = {
				Plan.subway.pos,
				Plan.station,
				Plan.newsstand.pos,
				Plan.storeKiosk.pos,
				Plan.bikeDock.pos,
				Plan.phoneBooth.pos,
				Plan.busStop.pos,
				Plan.scaffold.pos,
				Plan.streetClock,
				Plan.plaza.anchor,
				Plan.plaza.muster,
				Plan.plaza.pigeons,
			}
			for _, c in Plan.foodCarts do
				table.insert(points, c.pos)
			end
			for _, a in Plan.atms do
				table.insert(points, a.pos)
			end
			for _, d in Plan.directories do
				table.insert(points, d.pos)
			end
			for _, b in Plan.briefcases do
				table.insert(points, b)
			end
			for _, p in points do
				t.expect(Plan.inRoad(p.X, p.Z)).toBeFalsy()
				t.expect(math.abs(p.X)).toBeLessThan(Plan.WALL - 2)
				t.expect(math.abs(p.Z)).toBeLessThan(Plan.WALL - 2)
			end
		end)

		t.it("names the four briefcase spots the events feature hides the Golden Briefcase in", function()
			for _, id in World.eventSpots.street do
				if string.find(id, "^briefcase_") then
					t.expect(Plan.briefcases[id] ~= nil).toBeTruthy()
				end
			end
		end)

		t.it("lays out one monolith per leaderboard", function()
			t.expect(#Plan.boards).toBe(10)
			t.expect(#Plan.plaza.boardZ * 2).toBe(#Plan.boards)
			local seen = {}
			for _, id in Plan.boards do
				t.expect(seen[id] == nil).toBeTruthy()
				seen[id] = true
			end
		end)
	end)

	t.describe("text", function()
		t.it("has every string the plan refers to", function()
			local keys = {}
			for _, r in Plan.roads do
				table.insert(keys, r.name)
			end
			for _, f in Plan.fillers do
				for _, k in f.shops or {} do
					table.insert(keys, k)
				end
			end
			for _, lot in Plan.spareLots do
				for _, k in lot.shops or {} do
					table.insert(keys, k)
				end
			end
			for _, b in Plan.billboards do
				table.insert(keys, b.brand)
				table.insert(keys, b.slogan)
			end
			for _, id in Plan.boards do
				table.insert(keys, "board_" .. id)
			end
			for _, k in keys do
				if Text.strings[k] == nil then
					error("Street/Text has no string " .. k)
				end
			end
		end)

		t.it("fills placeholders and returns unknown keys unchanged", function()
			t.expect(Text.get("address", { n = 12, street = "BANK ROW" })).toBe("12 BANK ROW")
			t.expect(Text.get("no_such_key")).toBe("no_such_key")
		end)
	end)
end
