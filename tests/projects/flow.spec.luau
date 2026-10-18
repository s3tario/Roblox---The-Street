-- ProjectService/Flow under Lune with fake services in the server Registry: a closed deal records the work, creates
-- the plaque (CareerService:RecordDeal with the deal name), banks XP, pays "salary" cash, adds reputation, trains
-- stats and adds Season XP; a pulled deal pays less and gets no plaque; a repeat run pays less; the context reads
-- stats, the role band and the market mood; IPO Frenzy's ipoMult reaches the IPO's pay. Every call is guarded, so
-- missing services never break a reward.
local ServerFolder = game:GetService("ServerScriptService").Server
local Shared = game:GetService("ReplicatedStorage").Shared
local ServerRegistry = require(ServerFolder.Registry)
local Flow = require(ServerFolder.Services.ProjectService.Flow)
local Registry = require(Shared.Logic.Projects._registry)
local sellside = require(Shared.Logic.Projects.ib_sellside)
local ipo = require(Shared.Logic.Projects.ipo)

local calls: { { any } } = {}
local frenzy = false

local function log(name: string, ...: any)
	table.insert(calls, { name, ... })
end

local function find(name: string): { any }?
	for _, c in calls do
		if c[1] == name then
			return c
		end
	end
	return nil
end

local function countOf(name: string): number
	local n = 0
	for _, c in calls do
		if c[1] == name then
			n += 1
		end
	end
	return n
end

local FAKES: { [string]: any } = {
	CareerService = {
		RecordWork = function(_self: any, _p: any, info: any)
			log("RecordWork", info)
		end,
		RecordDeal = function(_self: any, _p: any, id: string, name: string, quality: number)
			log("RecordDeal", id, name, quality)
			return { id = "p1", name = name }
		end,
		AddXP = function(_self: any, _p: any, amount: number, source: string)
			log("AddXP", amount, source)
			return amount
		end,
		AddReputation = function(_self: any, _p: any, amount: number, source: string)
			log("AddReputation", amount, source)
		end,
		GetCompany = function()
			return { id = "harrow_williams", name = "Harrow Williams", payMult = 1.2 }
		end,
		GetRole = function()
			return { minLevel = 25, maxLevel = 40 }
		end,
	},
	EconomyService = {
		AddCash = function(_self: any, _p: any, amount: number, source: string, kind: string)
			log("AddCash", amount, source, kind)
			return amount
		end,
	},
	ProfileService = {
		AwardStatXp = function(_self: any, _p: any, stats: any, quality: number, source: string)
			log("AwardStatXp", stats, quality, source)
		end,
		GetStats = function()
			return { knowledge = 70, skill = 60, speed = 50, charisma = 90, network = 40, discipline = 50 }
		end,
		GetOVR = function()
			return 58
		end,
	},
	SeasonService = {
		AddSeasonXP = function(_self: any, _p: any, amount: number, source: string)
			log("AddSeasonXP", amount, source)
		end,
	},
	EventService = {
		GetModifier = function(_self: any, name: string)
			return if name == "ipoMult" and frenzy then 2 else 1
		end,
		IsActive = function(_self: any, id: string)
			return id == "ipo_frenzy" and frenzy
		end,
	},
}

-- Registers the fakes once (the server Registry refuses duplicates); returns false when a real service of the same
-- name is already registered in this test process.
local function install(): boolean
	local all = ServerRegistry.all()
	for name, fake in FAKES do
		local existing = all[name]
		if existing == nil then
			ServerRegistry.register(name, fake)
		elseif existing ~= fake then
			return false
		end
	end
	return true
end

local PLAYER: any = { Name = "Tester", UserId = 1 }

local function who(rank: number): any
	return Registry.who({
		status = "active",
		track = "ib",
		rank = rank,
		level = 30,
		companyId = "harrow_williams",
		roleId = "ib_x",
	})
end

local function completion(closed: boolean, closedBefore: number): any
	return {
		quality = 90,
		closed = closed,
		dealName = "Project Falcon: $2.4B IPO of Harlow Foods",
		closedBefore = closedBefore,
		runsBefore = closedBefore,
		repeatRun = closedBefore > 0,
		firstClose = closed and closedBefore == 0,
	}
end

return function(t)
	local ready = install()

	t.describe("setup", function()
		t.it("the fake services are installed", function()
			t.expect(ready).toBe(true)
		end)
	end)

	t.describe("rewards", function()
		t.it("a closed deal records the work and the plaque, banks XP, pays salary and trains stats", function()
			if not ready then
				return
			end
			table.clear(calls)
			local r = Flow.reward(PLAYER, ipo, completion(true, 0), who(3))
			local deal = find("RecordDeal")
			t.expect(deal).toBeTruthy()
			t.expect((deal :: any)[2]).toBe("ipo")
			t.expect((deal :: any)[3]).toBe("Project Falcon: $2.4B IPO of Harlow Foods")
			t.expect((deal :: any)[4]).toBe(90)
			local work = find("RecordWork") :: any
			t.expect(work[2].taskId).toBe("ipo")
			t.expect(work[2].quality).toBe(90)
			local cash = find("AddCash") :: any
			t.expect(cash[4]).toBe("salary")
			t.expect(cash[3]).toBe("project")
			local expected = Registry.rewards(ipo, 90, 3, { runs = 0, closed = true, payMult = 1.2 })
			t.expect(r.pay).toBe(expected.pay)
			t.expect(r.paid).toBe(true)
			t.expect(r.xp).toBe(expected.xp)
			t.expect(r.plaque).toBe(true)
			t.expect(r.rep).toBeGreaterThan(0)
			t.expect(r.pulled).toBe(false)
			t.expect((find("AwardStatXp") :: any)[4]).toBe("deal")
			t.expect((find("AddSeasonXP") :: any)[2]).toBe(math.floor(r.xp * Registry.TUNING.seasonShare + 0.5))
			t.expect(#r.stats).toBe(#ipo.stats)
			t.expect((Registry.plain(r))).toBe(true)
		end)
		t.it("a pulled deal gets no plaque, no reputation and less pay", function()
			if not ready then
				return
			end
			table.clear(calls)
			local closed = Flow.reward(PLAYER, sellside, completion(true, 0), who(1))
			table.clear(calls)
			local pulled = Flow.reward(PLAYER, sellside, completion(false, 0), who(1))
			t.expect(find("RecordDeal")).toBeNil()
			t.expect(find("AddReputation")).toBeNil()
			t.expect(find("RecordWork")).toBeTruthy()
			t.expect(pulled.plaque).toBe(false)
			t.expect(pulled.pulled).toBe(true)
			t.expect(pulled.pay).toBeLessThan(closed.pay)
			t.expect(pulled.xp).toBeLessThan(closed.xp)
		end)
		t.it("a repeat run pays less than the first close", function()
			if not ready then
				return
			end
			local first = Flow.reward(PLAYER, sellside, completion(true, 0), who(2))
			local again = Flow.reward(PLAYER, sellside, completion(true, 3), who(2))
			t.expect(again.repeatRun).toBe(true)
			t.expect(again.pay).toBeLessThan(first.pay)
			t.expect(again.repeatPct).toBe(math.floor(Registry.TUNING.repeatMult * 100 + 0.5))
		end)
		t.it("IPO Frenzy doubles IPO pay through the module's payModifier", function()
			if not ready then
				return
			end
			frenzy = false
			local calm = Flow.reward(PLAYER, ipo, completion(true, 0), who(3))
			frenzy = true
			local hot = Flow.reward(PLAYER, ipo, completion(true, 0), who(3))
			local sell = Flow.mults(PLAYER, who(1), sellside)
			frenzy = false
			t.expect(hot.pay).toBeGreaterThan(calm.pay)
			t.expect(math.abs(hot.pay - calm.pay * 2)).toBeLessThanOrEqual(2)
			t.expect(sell.eventMult).toBe(1)
		end)
		t.it("each graded stage trains that stage's stats", function()
			if not ready then
				return
			end
			table.clear(calls)
			Flow.stageStats(PLAYER, sellside, "cim", 80)
			local award = find("AwardStatXp") :: any
			t.expect(table.concat(award[2], ",")).toBe("discipline,skill")
			t.expect(award[3]).toBe(80)
			t.expect(award[4]).toBe("task")
			t.expect(countOf("AwardStatXp")).toBe(1)
		end)
	end)

	t.describe("context", function()
		t.it("reads stats, the role band, the firm and the market mood", function()
			if not ready then
				return
			end
			frenzy = true
			local ctx = Flow.context(PLAYER, { profile = { firstName = "Ava" } }, who(2))
			frenzy = false
			t.expect(ctx.rank).toBe(2)
			t.expect(ctx.track).toBe("ib")
			t.expect(ctx.ovr).toBe(58)
			t.expect(ctx.companyName).toBe("Harrow Williams")
			t.expect(ctx.firstName).toBe("Ava")
			t.expect(ctx.hints).toBeGreaterThanOrEqual(1)
			t.expect(ctx.charismaBonus).toBeGreaterThan(0)
			t.expect(ctx.difficulty).toBe(Registry.difficulty(2, 30, 25, 40))
			t.expect(ctx.marketMood).toBeGreaterThan(1)
			-- the context is a valid deal ctx: a deal starts and views with it
			local state = ipo.new(require(Shared.Util.Rng).new(1), ctx)
			t.expect(ipo.view(state, ctx).payload).toBeTruthy()
		end)
	end)
end
