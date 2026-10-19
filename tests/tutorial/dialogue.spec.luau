-- tutorial: dialogue resolution (Logic/Dialogue) and the integrity of every NPC's tree (Config/Npcs + Config/Dialogue).
local Shared = game:GetService("ReplicatedStorage").Shared
local World = require(Shared.Config.World)
local Npcs = require(Shared.Config.Npcs)
local Catalog = require(Shared.Config.Catalog)
local Quests = require(Shared.Config.Quests)
local Trees = require(Shared.Config.Dialogue)
local Dialogue = require(Shared.Logic.Dialogue)

local function sampleTree()
	return {
		id = "sample",
		start = {
			{ node = "fired", cond = { fired = true } },
			{ node = "hub" },
		},
		nodes = {
			hub = {
				text = { "Hello {name}.", "Hi again, {name}." },
				options = {
					{ id = "secret", text = "Charm them", to = "charm", cond = { stat = { charisma = 60 } } },
					{ id = "step", text = "Step only", to = "done", cond = { step = "advisor" } },
					{ text = "Ask", to = "answer", actions = { { kind = "flag", flag = "asked" } } },
					{ id = "bye", text = "Bye", exit = true },
				},
			},
			answer = {
				text = "An answer.",
				actions = { { kind = "statXp", stats = { "knowledge" }, quality = 50, key = "k" } },
				options = { { id = "back", text = "Back", to = "hub" } },
			},
			charm = { text = "Charmed.", options = { { id = "back", text = "Back", to = "hub" } } },
			done = {
				text = "Done.",
				options = { { id = "go", text = "Go", exit = true, actions = { { kind = "complete", step = "advisor" } } } },
			},
			fired = { text = "Sorry.", options = { { id = "bye", text = "Thanks", exit = true } } },
		},
	}
end

local function walkAll(tree: any, ctxs: { any }): number
	-- drives every visible option from every start for several contexts; returns nodes visited
	local visited = 0
	for _, ctx in ctxs do
		local seen: { [string]: boolean } = {}
		local queue = { Dialogue.start(tree, ctx) }
		while #queue > 0 do
			local nodeId = table.remove(queue) :: string
			if not seen[nodeId] then
				seen[nodeId] = true
				visited += 1
				local view = Dialogue.view(tree, nodeId, ctx)
				assert(view, "no view for " .. nodeId)
				assert(#view.options > 0, tree.id .. "." .. nodeId .. " shows no options")
				assert(not string.find(view.text, "{", 1, true), tree.id .. "." .. nodeId .. " left a placeholder")
				for _, o in view.options do
					local ok, step = Dialogue.choose(tree, nodeId, o.id, ctx)
					assert(ok, ("choose %s.%s/%s failed: %s"):format(tree.id, nodeId, o.id, tostring(step)))
					if step.next then
						table.insert(queue, step.next)
					end
				end
			end
		end
	end
	return visited
end

local VARS = {
	name = "Maya",
	full = "Maya Kennerly",
	npc = "Catherine Ashby",
	company = "MG Freeman",
	boss = "Catherine Ashby",
	school = "Eastbridge State",
	title = "Analyst",
	department = "Investment Banking",
	headline = "Apex AI beats estimates.",
	index = "1,024.50",
	level = 12,
	week = 2,
	apps = 2,
	max = 5,
	networked = 1,
	goal = 3,
	place = "MG Freeman",
}

local function ctxs(): { any }
	local base = function(over: any)
		local c = {
			seed = "seed",
			step = "advisor",
			done = {},
			flags = {},
			built = true,
			student = true,
			stats = { charisma = 50 },
			vars = VARS,
		}
		for k, v in over do
			c[k] = v
		end
		return c
	end
	local list = {
		base({}),
		base({ built = false }),
		base({ step = "club", done = { advisor = 1 }, club = false }),
		base({ step = "pitch", done = { advisor = 1, club = 1 }, club = true }),
		base({ step = "recruiting", done = { advisor = 1, club = 1 }, club = true, hasOffer = false }),
		base({ step = "offers", hasOffer = true }),
		base({ step = "tower", student = false, employed = true, hired = true }),
		base({ step = "receptionist", student = false, employed = true, hired = true }),
		base({ step = "boss", student = false, employed = true, hired = true, done = { receptionist = 1 } }),
		base({ step = "done", student = false, employed = true, hired = true, reviewDue = true }),
		base({ step = "done", student = false, employed = true, hired = true, probation = true }),
		base({ step = "done", student = false, fired = true, hired = true }),
		base({ visitor = true }),
		base({ stats = { charisma = 90 } }),
	}
	return list
end

return function(t)
	t.describe("Logic/Dialogue", function()
		t.it("picks the first start whose condition holds", function()
			local tree = sampleTree()
			t.expect(Dialogue.start(tree, { fired = true })).toBe("fired")
			t.expect(Dialogue.start(tree, { fired = false })).toBe("hub")
		end)
		t.it("filters options by condition and fills placeholders", function()
			local tree = sampleTree()
			local view = Dialogue.view(tree, "hub", { vars = { name = "Maya" }, stats = { charisma = 40 }, seed = 1 })
			t.expect(view).never(nil)
			t.expect(#view.options).toBe(2)
			t.expect(view.options[1].id).toBe("o3")
			t.expect(view.options[2].exit).toBe(true)
			t.expect(string.find(view.text, "Maya", 1, true) ~= nil).toBe(true)
			local charming = Dialogue.view(tree, "hub", { stats = { charisma = 75 }, step = "advisor" })
			t.expect(#charming.options).toBe(4)
		end)
		t.it("picks text variants deterministically by seed", function()
			local tree = sampleTree()
			local a = Dialogue.view(tree, "hub", { seed = "x", vars = {} })
			local b = Dialogue.view(tree, "hub", { seed = "x", vars = {} })
			t.expect(a.text).toBe(b.text)
			local seen: { [string]: boolean } = {}
			for i = 1, 40 do
				seen[Dialogue.view(tree, "hub", { seed = i, vars = {} }).text] = true
			end
			local n = 0
			for _ in seen do
				n += 1
			end
			t.expect(n).toBe(2)
		end)
		t.it("validates choices against the current node", function()
			local tree = sampleTree()
			local ctx = { stats = { charisma = 40 }, step = "club" }
			local ok, err = Dialogue.choose(tree, "hub", "secret", ctx)
			t.expect(ok).toBe(false)
			t.expect(err).toBe("hidden")
			ok, err = Dialogue.choose(tree, "hub", "nope", ctx)
			t.expect(ok).toBe(false)
			t.expect(err).toBe("bad_option")
			ok, err = Dialogue.choose(tree, "missing", "bye", ctx)
			t.expect(ok).toBe(false)
			t.expect(err).toBe("bad_node")
		end)
		t.it("returns option actions followed by the next node's on-enter actions", function()
			local tree = sampleTree()
			local ok, step = Dialogue.choose(tree, "hub", "o3", {})
			t.expect(ok).toBe(true)
			t.expect(step.next).toBe("answer")
			t.expect(step.exit).toBe(false)
			t.expect(#step.actions).toBe(2)
			t.expect(step.actions[1].kind).toBe("flag")
			t.expect(step.actions[2].kind).toBe("statXp")
			local ok2, bye = Dialogue.choose(tree, "hub", "bye", {})
			t.expect(ok2).toBe(true)
			t.expect(bye.exit).toBe(true)
			t.expect(bye.next).toBeNil()
		end)
		t.it("evaluates any / all / not, numbers and strings", function()
			t.expect(Dialogue.check({ any = { { fired = true }, { employed = true } } }, { employed = true })).toBe(true)
			t.expect(Dialogue.check({ all = { { built = true }, { student = true } } }, { built = true })).toBe(false)
			t.expect(Dialogue.check({ ["not"] = { visitor = true } }, { visitor = false })).toBe(true)
			t.expect(Dialogue.check({ rankAtLeast = 2 }, { rank = 3 })).toBe(true)
			t.expect(Dialogue.check({ rankAtLeast = 2 }, { rank = 1 })).toBe(false)
			t.expect(Dialogue.check({ status = "probation" }, { status = "probation" })).toBe(true)
			t.expect(Dialogue.check({ unknownKey = true }, {})).toBe(false)
			t.expect(Dialogue.check(nil, {})).toBe(true)
		end)
		t.it("validate() accepts the sample and catches broken trees", function()
			t.expect(#Dialogue.validate(sampleTree())).toBe(0)
			local broken = sampleTree()
			broken.nodes.answer.options = { { id = "x", text = "Loop", to = "charm2" } }
			t.expect(#Dialogue.validate(broken) > 0).toBe(true)
			local trapped = sampleTree()
			trapped.nodes.answer.options = { { id = "loop", text = "Again", to = "answer" } }
			local problems = Dialogue.validate(trapped)
			local found = false
			for _, p in problems do
				if string.find(p, "no way out", 1, true) then
					found = true
				end
			end
			t.expect(found).toBe(true)
			local allCond = sampleTree()
			allCond.nodes.fired.options = { { id = "x", text = "Bye", exit = true, cond = { built = true } } }
			t.expect(#Dialogue.validate(allCond) > 0).toBe(true)
			local orphan = sampleTree()
			orphan.nodes.lonely = { text = "Nobody comes here.", options = { { id = "bye", text = "Bye", exit = true } } }
			t.expect(#Dialogue.validate(orphan) > 0).toBe(true)
			local badAction = sampleTree()
			badAction.nodes.fired.options[1].actions = { { kind = "teleportToMoon" } }
			t.expect(#Dialogue.validate(badAction) > 0).toBe(true)
			local badVar = sampleTree()
			badVar.nodes.fired.text = "Hello {nobody}"
			t.expect(#Dialogue.validate(badVar) > 0).toBe(true)
		end)
	end)

	t.describe("NPC config", function()
		t.it("every World.npcSpots NPC has config, a preset outfit and a dialogue tree", function()
			local count = 0
			for zone, ids in World.npcSpots do
				for _, id in ids do
					count += 1
					local def = Npcs.get(id)
					assert(def, "no Config/Npcs entry for " .. id)
					t.expect(def.zone).toBe(zone)
					t.expect(type(def.name) == "string" and #def.name > 1).toBe(true)
					t.expect(type(def.title) == "string" and #def.title > 1).toBe(true)
					assert(Catalog.presets[def.preset], id .. " uses unknown preset " .. def.preset)
					assert(Trees.get(def.dialogue), id .. " has no dialogue tree " .. def.dialogue)
				end
			end
			t.expect(count).toBe(#Npcs.list)
		end)
		t.it("the office staff have dialogue trees", function()
			for role, def in Npcs.office do
				assert(Trees.get(def.dialogue), "office " .. role .. " has no tree")
			end
		end)
	end)

	t.describe("dialogue trees", function()
		for _, id in Trees.ids() do
			t.it(id .. " is well formed", function()
				local problems = Dialogue.validate(Trees.get(id))
				if #problems > 0 then
					error(table.concat(problems, "\n"))
				end
			end)
			t.it(id .. " can be walked in every context without dead ends", function()
				t.expect(walkAll(Trees.get(id), ctxs())).toBeGreaterThan(0)
			end)
		end
		t.it("every 'complete' action names a real chain step and every task offer a student task", function()
			for _, id in Trees.ids() do
				local tree = Trees.get(id)
				for nodeId, node in tree.nodes do
					local lists = { node.actions or {} }
					for _, o in node.options do
						table.insert(lists, o.actions or {})
					end
					for _, list in lists do
						for _, a in list do
							if a.kind == "complete" then
								assert(Quests.stepById[a.step], ("%s.%s completes unknown step %s"):format(id, nodeId, a.step))
							elseif a.kind == "statXp" then
								for _, s in a.stats do
									assert(
										table.find({ "knowledge", "skill", "speed", "charisma", "network", "discipline", "risk", "luck" }, s),
										id .. " trains unknown stat " .. s
									)
								end
							end
						end
					end
				end
			end
		end)
		t.it("the steps finished by conversation are completable by some NPC", function()
			local completable: { [string]: boolean } = {}
			for _, id in Trees.ids() do
				for _, node in Trees.get(id).nodes do
					local lists = { node.actions or {} }
					for _, o in node.options do
						table.insert(lists, o.actions or {})
					end
					for _, list in lists do
						for _, a in list do
							if a.kind == "complete" then
								completable[a.step] = true
							end
						end
					end
				end
			end
			for _, step in { "advisor", "club", "receptionist", "boss" } do
				t.expect(completable[step]).toBe(true)
			end
		end)
	end)
end
