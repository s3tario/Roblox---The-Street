-- tutorial: business-card exchanges (Logic/QuestLine/Network): within 15 studs, once per pair per real day.
local Shared = game:GetService("ReplicatedStorage").Shared
local QuestLine = require(Shared.Logic.QuestLine)

local Network = QuestLine.Network

local DAY = 86400
local NOON = 20_000 * DAY + DAY / 2 -- midday UTC of some day

local function side(userId: number, log: { [string]: number }?): Network.Side
	return { userId = userId, log = log or {} }
end

-- What SocialService:Exchange does after a successful check.
local function exchange(a: Network.Side, b: Network.Side, distance: number, now: number): (boolean, string?)
	Network.prune(a.log, now)
	Network.prune(b.log, now)
	local ok, err = Network.check(a, b, distance, now)
	if ok then
		Network.record(a.log, b.userId, now)
		Network.record(b.log, a.userId, now)
	end
	return ok, err
end

return function(t)
	t.describe("Network exchanges", function()
		t.it("works within 15 studs and not beyond", function()
			t.expect(Network.RANGE).toBe(15)
			t.expect((Network.check(side(1), side(2), 15, NOON))).toBe(true)
			local ok, err = Network.check(side(1), side(2), 15.01, NOON)
			t.expect(ok).toBe(false)
			t.expect(err).toBe("far")
			local okInf, errInf = Network.check(side(1), side(2), math.huge, NOON)
			t.expect(okInf).toBe(false)
			t.expect(errInf).toBe("far")
		end)

		t.it("you can't exchange with yourself", function()
			local ok, err = Network.check(side(7), side(7), 0, NOON)
			t.expect(ok).toBe(false)
			t.expect(err).toBe("self")
		end)

		t.it("happens once per pair per day, whoever starts it", function()
			local a, b = side(1), side(2)
			t.expect((exchange(a, b, 3, NOON))).toBe(true)
			local again, err = exchange(a, b, 3, NOON + 60)
			t.expect(again).toBe(false)
			t.expect(err).toBe("today")
			-- the other player starting it is the same pair
			local back, err2 = exchange(b, a, 3, NOON + 120)
			t.expect(back).toBe(false)
			t.expect(err2).toBe("today")
			-- even if one side's log was lost (a rejoin on an old save), the other side's log still blocks it
			local fresh = side(2, {})
			local ok3, err3 = exchange(a, fresh, 3, NOON + 180)
			t.expect(ok3).toBe(false)
			t.expect(err3).toBe("today")
		end)

		t.it("other pairs are independent", function()
			local a, b, c = side(1), side(2), side(3)
			t.expect((exchange(a, b, 3, NOON))).toBe(true)
			t.expect((exchange(a, c, 3, NOON))).toBe(true)
			t.expect((exchange(b, c, 3, NOON))).toBe(true)
			t.expect(Network.exchangedToday(a.log, 2, NOON)).toBe(true)
			t.expect(Network.exchangedToday(a.log, 3, NOON)).toBe(true)
			t.expect(Network.exchangedToday(a.log, 4, NOON)).toBe(false)
		end)

		t.it("resets at the next UTC day and prunes old entries", function()
			local a, b = side(1), side(2)
			t.expect((exchange(a, b, 3, NOON))).toBe(true)
			local tomorrow = NOON + DAY
			t.expect(Network.exchangedToday(a.log, 2, tomorrow)).toBe(false)
			t.expect((exchange(a, b, 3, tomorrow))).toBe(true)
			-- a day boundary, not 24 hours: just before and just after midnight are different days
			local beforeMidnight = (20_010 * DAY) - 1
			local x, y = side(10), side(11)
			t.expect((exchange(x, y, 1, beforeMidnight))).toBe(true)
			t.expect((exchange(x, y, 1, beforeMidnight + 2))).toBe(true)
			-- prune keeps only today's keys
			local log = { ["5"] = Network.day(NOON) - 3, ["6"] = Network.day(NOON) }
			Network.prune(log, NOON)
			t.expect(log["5"]).toBeNil()
			t.expect(log["6"]).toBe(Network.day(NOON))
		end)

		t.it("pair keys are order independent and user keys are integers", function()
			t.expect(Network.pairKey(5, 9)).toBe(Network.pairKey(9, 5))
			t.expect(Network.key(123456789012)).toBe("123456789012")
		end)

		t.it("contacts count each person once for the networking step", function()
			local net = { count = 0, ids = {} }
			local added, n = Network.addContact(net, "npc:npc_alum")
			t.expect(added).toBe(true)
			t.expect(n).toBe(1)
			added, n = Network.addContact(net, "npc:npc_alum")
			t.expect(added).toBe(false)
			t.expect(n).toBe(1)
			Network.addContact(net, "player:42")
			added, n = Network.addContact(net, "npc:npc_professor")
			t.expect(n).toBe(3)
			t.expect(net.count).toBe(3)
		end)
	end)
end
