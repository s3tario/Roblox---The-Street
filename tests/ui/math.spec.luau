local Client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
local KitMath = require(Client.UI.Kit.Math)

return function(t)
	t.describe("Chart bounds", function()
		t.it("pads the data range", function()
			local lo, hi = KitMath.bounds({ { 10, 20 } }, { pad = 0.1 })
			t.expect(lo).toBeCloseTo(9, 1e-9)
			t.expect(hi).toBeCloseTo(21, 1e-9)
		end)
		t.it("covers every series and the baseline", function()
			local lo, hi = KitMath.bounds({ { 5, 6 }, { 1, 2 } }, { baseline = 10, pad = 0 })
			t.expect(lo).toBe(1)
			t.expect(hi).toBe(10)
		end)
		t.it("widens a flat series instead of dividing by zero", function()
			local lo, hi = KitMath.bounds({ { 100, 100, 100 } })
			t.expect(lo < 100 and hi > 100).toBeTruthy()
			local zlo, zhi = KitMath.bounds({ { 0, 0 } })
			t.expect(zlo).toBe(-1)
			t.expect(zhi).toBe(1)
			local elo, ehi = KitMath.bounds({})
			t.expect(ehi > elo).toBeTruthy()
		end)
		t.it("honours fixed minY / maxY", function()
			local lo, hi = KitMath.bounds({ { 3, 7 } }, { minY = 0, maxY = 10 })
			t.expect(lo).toBe(0)
			t.expect(hi).toBe(10)
		end)
		t.it("ignores NaN and infinities", function()
			local cleaned = KitMath.clean({ 1, 0 / 0, math.huge, 2, "x", -math.huge, 3 })
			t.expect(cleaned).toEqual({ 1, 2, 3 })
			t.expect(#KitMath.clean(nil)).toBe(0)
		end)
	end)

	t.describe("Chart projection", function()
		t.it("maps min to the bottom and max to the top", function()
			local pts = KitMath.project({ 0, 5, 10 }, 200, 100, 0, 10)
			t.expect(pts[1].x).toBe(0)
			t.expect(pts[1].y).toBe(100)
			t.expect(pts[2].x).toBe(100)
			t.expect(pts[2].y).toBe(50)
			t.expect(pts[3].x).toBe(200)
			t.expect(pts[3].y).toBe(0)
		end)
		t.it("centres a single point", function()
			local pts = KitMath.project({ 4 }, 200, 100, 0, 8)
			t.expect(pts[1].x).toBe(100)
			t.expect(pts[1].y).toBe(50)
		end)
		t.it("segments have the right centre, length and angle", function()
			local seg = KitMath.segment({ x = 0, y = 0 }, { x = 30, y = 40 })
			t.expect(seg.x).toBe(15)
			t.expect(seg.y).toBe(20)
			t.expect(seg.length).toBeCloseTo(50, 1e-9)
			t.expect(seg.angle).toBeCloseTo(math.deg(math.atan2(40, 30)), 1e-9)
			local flat = KitMath.segment({ x = 0, y = 10 }, { x = 10, y = 10 })
			t.expect(flat.angle).toBeCloseTo(0, 1e-9)
			local up = KitMath.segment({ x = 0, y = 10 }, { x = 10, y = 0 })
			t.expect(up.angle).toBeCloseTo(-45, 1e-9) -- rising lines rotate counter-clockwise
		end)
		t.it("layout handles 2 and 240 points and caps longer series", function()
			local two = KitMath.layout({ { 1, 2 } }, 300, 150)
			t.expect(#two.lines[1].segments).toBe(1)
			local many = {}
			for i = 1, 240 do
				many[i] = (i % 17) * 3
			end
			local full = KitMath.layout({ many }, 300, 150)
			t.expect(#full.lines[1].points).toBe(240)
			t.expect(#full.lines[1].segments).toBe(239)
			local huge = {}
			for i = 1, 5000 do
				huge[i] = math.sin(i / 50)
			end
			local capped = KitMath.layout({ huge }, 300, 150)
			t.expect(#capped.lines[1].points).toBeLessThanOrEqual(KitMath.MAX_POINTS)
			-- every projected point stays inside the plot
			for _, line in { two, full, capped } do
				for _, p in line.lines[1].points do
					t.expect(p.x).toBeBetween(0, 300)
					t.expect(p.y).toBeBetween(0, 150)
				end
			end
		end)
		t.it("places the baseline", function()
			local layout = KitMath.layout({ { 0, 10 } }, 100, 100, { baseline = 5, pad = 0 })
			t.expect(layout.baselineY).toBeCloseTo(50, 1e-9)
		end)
	end)

	t.describe("Downsampling", function()
		t.it("keeps endpoints and extremes", function()
			local pts = {}
			for i = 1, 1000 do
				pts[i] = 50
			end
			pts[500] = 0 -- flash crash
			pts[700] = 100 -- spike
			pts[1], pts[1000] = 10, 20
			local out = KitMath.downsample(pts, 100)
			t.expect(#out).toBeLessThanOrEqual(100)
			t.expect(out[1]).toBe(10)
			t.expect(out[#out]).toBe(20)
			t.expect(out).toContain(0)
			t.expect(out).toContain(100)
		end)
		t.it("returns a copy when already small", function()
			local pts = { 1, 2, 3 }
			local out = KitMath.downsample(pts, 10)
			t.expect(out).toEqual(pts)
			out[1] = 99
			t.expect(pts[1]).toBe(1)
		end)
	end)

	t.describe("Ticks", function()
		t.it("uses nice steps inside the range", function()
			local ticks = KitMath.ticks(0, 100, 4)
			t.expect(ticks).toEqual({ 0, 20, 40, 60, 80, 100 })
			local small = KitMath.ticks(0.12, 0.47, 4)
			for _, v in small do
				t.expect(v).toBeBetween(0.12, 0.47)
			end
			t.expect(#small).toBeGreaterThan(1)
			t.expect(#KitMath.ticks(5, 5, 4)).toBe(0)
		end)
		t.it("removes float noise", function()
			local ticks = KitMath.ticks(0, 1, 10)
			t.expect(ticks[4]).toBe(0.3)
			t.expect(ticks[8]).toBe(0.7)
		end)
	end)

	t.describe("Columns and snapping", function()
		t.it("column widths fill the row", function()
			local cols = KitMath.columnWidths({ nil, 90, 0.25, nil }, 4)
			t.expect(cols[2]).toEqual({ scale = 0, offset = 90 })
			t.expect(cols[3]).toEqual({ scale = 0.25, offset = 0 })
			local scale, offset = 0, 0
			for _, c in cols do
				scale += c.scale
				offset += c.offset
			end
			t.expect(scale).toBeCloseTo(1, 1e-9)
			t.expect(offset).toBeCloseTo(0, 1e-9)
		end)
		t.it("snap clamps and rounds to the step", function()
			t.expect(KitMath.snap(0.537, 0, 1, 0.05)).toBeCloseTo(0.55, 1e-9)
			t.expect(KitMath.snap(1.13, 0.8, 1.2, 0.05)).toBeCloseTo(1.15, 1e-9)
			t.expect(KitMath.snap(-3, 0, 1, 0.1)).toBe(0)
			t.expect(KitMath.snap(9, 0, 1, 0.1)).toBe(1)
			t.expect(KitMath.snap(0 / 0, 2, 4, 1)).toBe(2)
			t.expect(KitMath.fraction(5, 0, 10)).toBe(0.5)
			t.expect(KitMath.fraction(5, 5, 5)).toBe(0)
		end)
	end)
end
