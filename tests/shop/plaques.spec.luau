-- Deal plaque layout (Logic/Economy/Plaques, v3 §13): the newest 3 on a desk, up to 24 on an office bookshelf, the
-- engraving text and the UTC date.

local Shared = game:GetService("ReplicatedStorage").Shared
local Economy = require(Shared.Logic.Economy)
local World = require(Shared.Config.World)
local Plaques = Economy.Plaques

local DAY = 86400
local BASE = 1792281600 -- 2026-10-18 00:00:00 UTC

local function make(n: number): { any }
	local list = {}
	for i = 1, n do
		table.insert(list, { id = "p" .. i, name = "Deal " .. i, at = BASE + i * DAY, quality = 80 })
	end
	return list
end

local function slots(n: number): { string }
	local out = {}
	for i = 1, n do
		table.insert(out, "plaque_" .. i)
	end
	return out
end

return function(t)
	t.it("capacities match the world templates", function()
		t.expect(Plaques.capacityFor("desk")).toBe(World.floorSlots.plaquesPerDesk)
		t.expect(Plaques.capacityFor("office")).toBe(World.floorSlots.plaquesPerShelf)
		t.expect(Plaques.capacityFor("apartment")).toBe(0)
		t.expect(Plaques.capacityFor(nil)).toBe(0)
	end)

	t.it("a desk shows the newest three, newest first", function()
		local layout = Plaques.layout(make(10), slots(3), Plaques.DESK)
		t.expect(#layout).toBe(3)
		t.expect(layout[1].plaque.id).toBe("p10")
		t.expect(layout[1].slotId).toBe("plaque_1")
		t.expect(layout[2].plaque.id).toBe("p9")
		t.expect(layout[3].plaque.id).toBe("p8")
	end)

	t.it("a bookshelf shows up to 24", function()
		t.expect(#Plaques.layout(make(30), slots(24), Plaques.SHELF)).toBe(24)
		t.expect(#Plaques.layout(make(5), slots(24), Plaques.SHELF)).toBe(5)
		local layout = Plaques.layout(make(30), slots(24), Plaques.SHELF)
		t.expect(layout[24].plaque.id).toBe("p7")
	end)

	t.it("never uses more slots than the template has", function()
		t.expect(#Plaques.layout(make(10), slots(2), Plaques.DESK)).toBe(2)
		t.expect(#Plaques.layout(make(10), {}, Plaques.DESK)).toBe(0)
		t.expect(#Plaques.layout({}, slots(3), Plaques.DESK)).toBe(0)
	end)

	t.it("orders by time, then by plaque number for deals closed the same second", function()
		local list = {
			{ id = "p2", name = "B", at = BASE },
			{ id = "p10", name = "C", at = BASE },
			{ id = "p1", name = "A", at = BASE - 5 },
		}
		local newest = Plaques.newest(list, 3)
		t.expect(newest[1].id).toBe("p10")
		t.expect(newest[2].id).toBe("p2")
		t.expect(newest[3].id).toBe("p1")
	end)

	t.it("skips broken entries and counts the valid ones", function()
		local list = { { id = "p1", name = "Good", at = BASE }, "junk", { name = "No time" }, { at = BASE } }
		t.expect(Plaques.count(list)).toBe(1)
		t.expect(#Plaques.newest(list, 5)).toBe(1)
		t.expect(Plaques.count(nil)).toBe(0)
	end)

	t.it("formats UTC dates without a clock", function()
		t.expect(Plaques.dateText(BASE)).toBe("Oct 18, 2026")
		t.expect(Plaques.dateText(0)).toBe("Jan 1, 1970")
		t.expect(Plaques.dateText(951782400)).toBe("Feb 29, 2000") -- leap day
		t.expect(Plaques.dateText(BASE + DAY - 1)).toBe("Oct 18, 2026")
		t.expect(Plaques.dateText(0 / 0)).toBe("")
	end)

	t.it("engraves the deal name and date, trimming long names", function()
		t.expect(Plaques.label({ id = "p1", name = "Project Falcon IPO", at = BASE }))
			.toBe("Project Falcon IPO\nOct 18, 2026")
		local long = Plaques.label({ id = "p1", name = string.rep("X", 100), at = BASE })
		local first = string.split(long, "\n")[1]
		t.expect(#first).toBe(Plaques.MAX_NAME)
		t.expect(string.sub(first, -3)).toBe("...")
	end)
end
