local Shared = game:GetService("ReplicatedStorage").Shared
local World = require(Shared.Config.World)
local Plan = require(game:GetService("ServerStorage").WorldBuilders.Street.Plan)
return function(t)
	t.it("raster", function()
		local rects = Plan.rects(World.towers)
		-- overlaps between lots (not fillers)
		for i, a in rects do
			for j, b in rects do
				if j > i and not string.find(a.id, "filler") and not string.find(b.id, "filler") then
					if a.x0 < b.x1 and b.x0 < a.x1 and a.z0 < b.z1 and b.z0 < a.z1 then
						print("LOT OVERLAP", a.id, b.id)
					end
				end
			end
		end
		for _, blk in Plan.blocks() do
			if blk.plaza then continue end
			-- inner area (inside sidewalks)
			local S = Plan.SIDEWALK
			local function onRoadSide(v, lo, hi, isLo) return false end
			local x0 = blk.x0 + (if blk.x0 > -Plan.EDGE then S else 0)
			local x1 = blk.x1 - (if blk.x1 < Plan.EDGE then S else 0)
			local z0 = blk.z0 + (if blk.z0 > -Plan.EDGE then S else 0)
			local z1 = blk.z1 - (if blk.z1 < Plan.EDGE then S else 0)
			local open = {}
			local nx, nz = math.floor(x1 - x0), math.floor(z1 - z0)
			local function key(i, k) return i * 10000 + k end
			for i = 0, nx - 1 do
				for k = 0, nz - 1 do
					local x, z = x0 + i + 0.5, z0 + k + 0.5
					if Plan.heightAt(rects, x, z) == 0 then
						open[key(i, k)] = true
					end
				end
			end
			-- narrow cells
			local narrow = 0
			local sample
			for kk in open do
				local i, k = kk // 10000, kk % 10000
				local function run(di, dk)
					local n = 0
					local a, b = i, k
					while open[key(a, b)] do n += 1; a += di; b += dk end
					return n
				end
				local hx = run(1, 0) + run(-1, 0) - 1
				local hz = run(0, 1) + run(0, -1) - 1
				-- cells on the block boundary connect to the sidewalk
				if hx < 6 and hz < 6 then
					narrow += 1
					sample = sample or (tostring(x0 + i) .. "," .. tostring(z0 + k))
				end
			end
			local count = 0
			for _ in open do count += 1 end
			local seen = {}
			for kk in open do
				if seen[kk] then continue end
				local stack = { kk }
				seen[kk] = true
				local bx0, bx1, bz0, bz1, n, thin = math.huge, -math.huge, math.huge, -math.huge, 0, 0
				while #stack > 0 do
					local c = table.remove(stack)
					local i, k = c // 10000, c % 10000
					n += 1
					bx0 = math.min(bx0, i); bx1 = math.max(bx1, i); bz0 = math.min(bz0, k); bz1 = math.max(bz1, k)
					local function run(di, dk)
						local m = 0
						local a, b = i, k
						while open[key(a, b)] do m += 1; a += di; b += dk end
						return m
					end
					if math.min(run(1, 0) + run(-1, 0) - 1, run(0, 1) + run(0, -1) - 1) < 4 then thin += 1 end
					for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
						local nk = key(i + d[1], k + d[2])
						if open[nk] and not seen[nk] then seen[nk] = true; table.insert(stack, nk) end
					end
				end
				local touches = bx0 == 0 or bz0 == 0 or bx1 == nx - 1 or bz1 == nz - 1
				print(string.format("   comp x[%d,%d] z[%d,%d] n=%d thin=%d edge=%s", x0 + bx0, x0 + bx1 + 1, z0 + bz0, z0 + bz1 + 1, n, thin, tostring(touches)))
			end
			print(blk.id, string.format("inner x[%d,%d] z[%d,%d] open=%d narrow=%d %s", x0, x1, z0, z1, count, narrow, sample or ""))
		end
	end)
end
