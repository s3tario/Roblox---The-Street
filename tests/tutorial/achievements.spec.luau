-- tutorial: achievements (Config/Achievements + Logic/QuestLine/Awards) and side quests (Config/Quests.side +
-- Logic/QuestLine/Side): config integrity and the unlock rules.
local Shared = game:GetService("ReplicatedStorage").Shared
local Achievements = require(Shared.Config.Achievements)
local Quests = require(Shared.Config.Quests)
local Npcs = require(Shared.Config.Npcs)
local Rarity = require(Shared.Config.Rarity)
local QuestLine = require(Shared.Logic.QuestLine)

local Awards = QuestLine.Awards
local Side = QuestLine.Side

local NOW = 1_800_000_000

local EVENT_KINDS = {
	life_roll = true,
	task = true,
	exchange = true,
	talk = true,
	offer = true,
	hired = true,
	step = true,
	trade = true,
	promotion = true,
	review = true,
	status = true,
	lifeline = true,
	comeback = true,
	plaque = true,
	project = true,
	outfit = true,
	level = true,
}
local FILTER_KEYS = {
	kind = true,
	count = true,
	counter = true,
	minQuality = true,
	band = true,
	source = true,
	companyType = true,
	step = true,
	projectId = true,
	closed = true,
	rarity = true,
	schoolAtLeast = true,
	gpaAtLeast = true,
	pnlAtLeast = true,
	rankAtLeast = true,
	levelAtLeast = true,
	outfitLevel = true,
	meetsFirm = true,
	from = true,
	to = true,
	held = true,
	all = true,
}

local function unlock(event: { [string]: any }, unlocked: { [string]: any }?, progress: { [string]: any }?): { string }
	local u = unlocked or {}
	local p = progress or {}
	local ids = Awards.process(Achievements.list, u, p, event)
	for _, id in ids do
		u[id] = NOW
	end
	return ids
end

local function has(list: { string }, id: string): boolean
	return table.find(list, id) ~= nil
end

return function(t)
	t.describe("Config/Achievements", function()
		t.it("has about 30 achievements with unique ids and complete fields", function()
			t.expect(#Achievements.list).toBeBetween(28, 45)
			local seen: { [string]: boolean } = {}
			for _, def in Achievements.list do
				assert(not seen[def.id], "duplicate achievement " .. def.id)
				seen[def.id] = true
				t.expect(string.match(def.id, "^[a-z0-9_]+$") ~= nil).toBe(true)
				t.expect(#def.name > 0 and #def.desc > 0 and #def.glyph > 0).toBe(true)
				assert(Achievements.TIERS[def.tier], def.id .. " has unknown tier " .. tostring(def.tier))
				assert(EVENT_KINDS[def.on.kind], def.id .. " listens to unknown event " .. tostring(def.on.kind))
				for key in def.on do
					assert(FILTER_KEYS[key], def.id .. " uses unknown filter " .. tostring(key))
				end
				if def.on.rarity then
					assert(Rarity.get(def.on.rarity), def.id .. " unknown rarity")
				end
				if def.on.schoolAtLeast then
					assert(Rarity.get(def.on.schoolAtLeast), def.id .. " unknown school rarity")
				end
				if def.on.all then
					for _, npcId in def.on.all do
						assert(Npcs.get(npcId), def.id .. " needs unknown NPC " .. npcId)
					end
				end
				if def.on.kind == "step" and def.on.step then
					assert(
						def.on.step == Quests.DONE or Quests.stepById[def.on.step],
						def.id .. " waits for unknown step " .. def.on.step
					)
				end
			end
			t.expect(Achievements.get("first_trade")).never(nil)
			t.expect(Achievements.get("nope")).toBeNil()
		end)

		t.it("covers the signals the design asks for", function()
			for _, id in
				{
					"first_trade",
					"first_task",
					"first_promotion",
					"star_review",
					"survived_probation",
					"lifeline",
					"first_plaque",
					"ipo_closed",
					"mythic_roll",
					"dressed_for_firm",
				}
			do
				assert(Achievements.get(id), "missing achievement " .. id)
			end
		end)

		t.it("text helpers fill placeholders", function()
			t.expect(Achievements.text("unlocked", { name = "Ticket Writer" }))
				.toBe("Achievement unlocked: Ticket Writer")
		end)
	end)

	t.describe("Awards rules", function()
		t.it("first trade, first task and first promotion unlock once", function()
			local unlocked, progress = {}, {}
			t.expect(has(unlock({ kind = "trade", pnl = 0 }, unlocked, progress), "first_trade")).toBe(true)
			t.expect(has(unlock({ kind = "trade", pnl = 0 }, unlocked, progress), "first_trade")).toBe(false)
			t.expect(progress.trade).toBe(2)
			t.expect(
				has(
					unlock({ kind = "task", taskId = "comps_analysis", quality = 60 }, unlocked, progress),
					"first_task"
				)
			)
				.toBe(true)
			t.expect(has(unlock({ kind = "promotion", rank = 2 }, unlocked, progress), "first_promotion")).toBe(true)
			t.expect(unlocked.vice_president).toBeNil()
			t.expect(has(unlock({ kind = "promotion", rank = 3 }, unlocked, progress), "vice_president")).toBe(true)
		end)

		t.it("quality, pnl and count thresholds", function()
			local unlocked, progress = {}, {}
			t.expect(has(unlock({ kind = "task", taskId = "x", quality = 94 }, unlocked, progress), "perfectionist"))
				.toBe(false)
			t.expect(has(unlock({ kind = "task", taskId = "x", quality = 95 }, unlocked, progress), "perfectionist"))
				.toBe(true)
			t.expect(has(unlock({ kind = "trade", pnl = 9999 }, unlocked, progress), "big_winner")).toBe(false)
			t.expect(has(unlock({ kind = "trade", pnl = 10000 }, unlocked, progress), "big_winner")).toBe(true)
			for i = 1, 4 do
				t.expect(has(unlock({ kind = "exchange" }, unlocked, progress), "card_shark")).toBe(false)
			end
			t.expect(has(unlock({ kind = "exchange" }, unlocked, progress), "card_shark")).toBe(true)
		end)

		t.it("Star reviews: the first one, then three in total", function()
			local unlocked, progress = {}, {}
			t.expect(has(unlock({ kind = "review", band = "on_track" }, unlocked, progress), "star_review")).toBe(false)
			t.expect(has(unlock({ kind = "review", band = "star" }, unlocked, progress), "star_review")).toBe(true)
			t.expect(has(unlock({ kind = "review", band = "star" }, unlocked, progress), "star_streak")).toBe(false)
			t.expect(has(unlock({ kind = "review", band = "star" }, unlocked, progress), "star_streak")).toBe(true)
			t.expect(progress["review:star"]).toBe(3)
		end)

		t.it("Life Roll rarities, school tier and GPA", function()
			local ids =
				unlock({ kind = "life_roll", rarities = { "common", "mythic" }, schoolRarity = "common", gpa = 3.2 })
			t.expect(has(ids, "new_life")).toBe(true)
			t.expect(has(ids, "mythic_roll")).toBe(true)
			t.expect(has(ids, "legendary_roll")).toBe(false)
			t.expect(has(ids, "honor_roll")).toBe(false)
			local ids2 =
				unlock({ kind = "life_roll", rarities = { "legendary" }, schoolRarity = "legendary", gpa = 3.8 })
			t.expect(has(ids2, "legendary_roll")).toBe(true)
			t.expect(has(ids2, "honor_roll")).toBe(true)
			t.expect(has(ids2, "mythic_roll")).toBe(false)
		end)

		t.it("dress code, probation, lifeline, IPO and the walk-on", function()
			t.expect(has(unlock({ kind = "outfit", level = 3, required = 3 }), "dressed_for_firm")).toBe(true)
			t.expect(has(unlock({ kind = "outfit", level = 2, required = 3 }), "dressed_for_firm")).toBe(false)
			t.expect(has(unlock({ kind = "outfit", level = 5 }), "dressed_for_firm")).toBe(false) -- no firm yet
			t.expect(has(unlock({ kind = "outfit", level = 5 }), "sharp_dresser")).toBe(true)
			t.expect(has(unlock({ kind = "status", from = "probation", to = "active" }), "survived_probation"))
				.toBe(true)
			t.expect(has(unlock({ kind = "status", from = "active", to = "probation" }), "survived_probation"))
				.toBe(false)
			t.expect(has(unlock({ kind = "lifeline" }), "lifeline")).toBe(true)
			t.expect(has(unlock({ kind = "project", projectId = "ipo", closed = true }), "ipo_closed")).toBe(true)
			t.expect(has(unlock({ kind = "project", projectId = "ipo", closed = false }), "ipo_closed")).toBe(false)
			t.expect(has(unlock({ kind = "hired", source = "walk_on", companyType = "regional" }), "walk_on"))
				.toBe(true)
			t.expect(has(unlock({ kind = "hired", source = "recruiting", companyType = "bulge" }), "bulge_bracket"))
				.toBe(true)
			t.expect(has(unlock({ kind = "offer", held = 3 }), "offer_magnet")).toBe(true)
			t.expect(has(unlock({ kind = "offer", held = 1 }), "offer_magnet")).toBe(false)
		end)

		t.it("talking to every campus regular", function()
			local unlocked, progress = {}, {}
			local regulars = Achievements.get("campus_regular").on.all
			for i, npcId in regulars do
				local ids = unlock({ kind = "talk", npcId = npcId }, unlocked, progress)
				t.expect(has(ids, "campus_regular")).toBe(i == #regulars)
			end
		end)

		t.it("check() catches up without bumping counters; count() counts unlocks", function()
			local progress = {}
			local ids = Awards.check(Achievements.list, {}, progress, { kind = "level", level = 30 })
			t.expect(has(ids, "level_25")).toBe(true)
			t.expect(has(ids, "level_50")).toBe(false)
			t.expect(progress.level).toBeNil()
			t.expect(Awards.count({ a = 1, b = 2 })).toBe(2)
			t.expect(Awards.count(nil)).toBe(0)
		end)

		t.it("only player-made fills count as trades", function()
			t.expect(Awards.isPlayerTrade({ kind = "trade" })).toBe(true)
			t.expect(Awards.isPlayerTrade({ kind = "take" })).toBe(true)
			t.expect(Awards.isPlayerTrade({ kind = "leave" })).toBe(false)
			t.expect(Awards.isPlayerTrade({ kind = "flatten" })).toBe(false)
			t.expect(Awards.isPlayerTrade(nil)).toBe(false)
		end)
	end)

	t.describe("Side quests", function()
		t.it("config integrity: unique ids, known NPCs and tasks, rewards", function()
			local seen: { [string]: boolean } = {}
			for _, q in Quests.side do
				assert(not seen[q.id], "duplicate side quest " .. q.id)
				seen[q.id] = true
				t.expect(q.goal >= 1).toBe(true)
				t.expect(q.phase == "campus" or q.phase == "street").toBe(true)
				t.expect((q.reward.xp or 0) + (q.reward.cash or 0) > 0).toBe(true)
				if q.on.kind == "talk" then
					t.expect(#q.on.npcs >= q.goal).toBe(true)
					for _, npcId in q.on.npcs do
						assert(Npcs.get(npcId), q.id .. " talks to unknown NPC " .. npcId)
					end
				elseif q.on.kind == "task" then
					assert(
						Shared.Logic.Tasks:FindFirstChild(q.on.taskId),
						q.id .. " needs missing task " .. q.on.taskId
					)
				end
			end
		end)

		t.it("progress counts unique NPCs, thresholds and finishes once", function()
			local quests = {}
			local defs = Quests.side
			local galleria = Quests.sideById.side_galleria
			local done = Side.apply(quests, defs, { kind = "talk", npcId = "npc_tailor" }, NOW)
			t.expect(#done).toBe(0)
			Side.apply(quests, defs, { kind = "talk", npcId = "npc_tailor" }, NOW)
			t.expect((Side.progress(quests, galleria))).toBe(1)
			Side.apply(quests, defs, { kind = "talk", npcId = "npc_watchmaker" }, NOW)
			Side.apply(quests, defs, { kind = "talk", npcId = "npc_shoe_clerk" }, NOW)
			done = Side.apply(quests, defs, { kind = "talk", npcId = "npc_decorator" }, NOW)
			t.expect(#done).toBe(1)
			t.expect(done[1].id).toBe("side_galleria")
			local n, finished = Side.progress(quests, galleria)
			t.expect(n).toBe(4)
			t.expect(finished).toBe(true)
			t.expect(#Side.apply(quests, defs, { kind = "talk", npcId = "npc_decorator" }, NOW)).toBe(0)

			-- quality floors, profitable trades and outfit levels
			t.expect(#Side.apply(quests, defs, { kind = "task", taskId = "finance_club_quiz", quality = 69 }, NOW))
				.toBe(0)
			t.expect(#Side.apply(quests, defs, { kind = "task", taskId = "finance_club_quiz", quality = 70 }, NOW))
				.toBe(1)
			Side.apply(quests, defs, { kind = "trade", pnl = -5 }, NOW)
			t.expect((Side.progress(quests, Quests.sideById.side_green_screen))).toBe(0)
			Side.apply(quests, defs, { kind = "trade", pnl = 5 }, NOW)
			t.expect((Side.progress(quests, Quests.sideById.side_green_screen))).toBe(1)
			t.expect(#Side.apply(quests, defs, { kind = "outfit", level = 1 }, NOW)).toBe(0)
			t.expect(#Side.apply(quests, defs, { kind = "outfit", level = 2 }, NOW)).toBe(1)
		end)

		t.it("view rows and reward text", function()
			local rows = Side.view({}, Quests.side, "street")
			t.expect(#rows > 0).toBe(true)
			for _, r in rows do
				t.expect(r.phase).toBe("street")
				t.expect(r.done).toBe(false)
				t.expect(r.n).toBe(0)
			end
			t.expect(Side.rewardText({ xp = 60, cash = 150 })).toBe("60 XP + $150")
			t.expect(Side.rewardText({ xp = 40 })).toBe("40 XP")
		end)
	end)
end
