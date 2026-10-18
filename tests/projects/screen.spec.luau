-- Project UI under Lune: the runner draws every stage of every deal (both themes) through the work feature's
-- renderers and cleans up; the debrief and results story (closed and pulled) build; the list shows the right action
-- per card; the Project screen walks list -> runner -> debrief -> ... -> results with a fake ProjectController that
-- runs the real deal modules through the real run lifecycle; and the pure view helpers.
local Shared = game:GetService("ReplicatedStorage").Shared
local Client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
local Signal = require(Shared.Util.Signal)
local Solve = require(Shared.Logic.Tasks._shared.Solve)
local Kinds = require(Shared.Logic.Tasks._shared.Kinds)
local Registry = require(Shared.Logic.Projects._registry)
local sellside = require(Shared.Logic.Projects.ib_sellside)
local ipo = require(Shared.Logic.Projects.ipo)
local Theme = require(Client.UI.Theme)
local ProjectScreen = require(Client.UI.Screens.Project)
local Parts = Client.UI.Screens.ProjectParts
local View = require(Parts.View)
local RunnerView = require(Parts.Runner)
local DebriefView = require(Parts.Debrief)
local ResultsView = require(Parts.Results)
local ListView = require(Parts.ListView)

local Runs = Registry.Runs
local NOW = 1790812800
local MODS = { sellside, ipo }

local function career(rank: number): { [string]: any }
	return {
		status = "active",
		track = "ib",
		rank = rank,
		level = 10 + rank * 12,
		companyId = "harrow_williams",
		roleId = "ib_x",
	}
end

local function ctxFor(mod: any): { [string]: any }
	local lo = Registry.rankRange(mod)
	return { level = 10 + lo * 12, rank = lo, track = "ib", difficulty = 0.6, hints = 2, now = NOW }
end

local function find(root: Instance, name: string): Instance?
	return root:FindFirstChild(name, true)
end

-- Every public view of a perfect run, stage by stage, then the finished view.
local function views(mod: any, seed: number): ({ any }, any)
	local ctx = ctxFor(mod)
	local record = Registry.record(nil)
	local lo = Registry.rankRange(mod)
	assert(Runs.start(mod, record, Registry.who(career(lo)), NOW, { seed = seed, ctx = ctx }))
	local out = {}
	while Runs.isActive(record) do
		table.insert(out, Runs.publicView(mod, record, ctx))
		assert(Runs.act(mod, record, Solve.perfect(record.state.current.secret), ctx, NOW, record.state.stageIndex))
	end
	record.lastRewards = { xp = 640, pay = 4200, paid = true, rep = 4.5, plaque = true, stats = { "Skill" } }
	return out, Runs.publicView(mod, record, ctx)
end

-- A fake ProjectController backed by the real modules and Runs (the "server" plays every stage perfectly, whatever
-- the screen sends, so the flow always reaches the results).
local function fakeController(rank: number): any
	local projects: { [string]: any } = {}
	local who = Registry.who(career(rank))
	local ctl: any = { Changed = Signal.new(), calls = {} }
	local function modOf(id: string): any
		return if id == "ipo" then ipo elseif id == "ib_sellside" then sellside else nil
	end
	local function record(id: string): any
		projects[id] = Registry.record(projects[id])
		return projects[id]
	end
	function ctl:List()
		table.insert(self.calls, "list")
		return true,
			{
				who = {
					employed = true,
					track = "ib",
					rank = rank,
					title = "Analyst",
					trackName = "Investment Banking",
				},
				cards = Runs.list(MODS, projects, who, NOW),
				activeCount = #Runs.activeIds(projects, { ipo = ipo, ib_sellside = sellside }),
				maxActive = 2,
			}
	end
	function ctl:StartDeal(id: string)
		table.insert(self.calls, "start:" .. id)
		local mod = modOf(id)
		local r = record(id)
		local ok, err = Runs.start(mod, r, who, NOW, { seed = 3, ctx = ctxFor(mod) })
		if not ok then
			return false, err
		end
		return true, Runs.publicView(mod, r, ctxFor(mod))
	end
	function ctl:View(id: string)
		local mod = modOf(id)
		local r = record(id)
		local v = Runs.publicView(mod, r, ctxFor(mod))
		if not v then
			return false, "not_active"
		end
		return true, v
	end
	function ctl:Act(id: string, _answers: any, stageIndex: number)
		table.insert(self.calls, "act:" .. stageIndex)
		local mod = modOf(id)
		local r = record(id)
		local ok, err, result, completion =
			Runs.act(mod, r, Solve.perfect(r.state.current.secret), ctxFor(mod), NOW, stageIndex)
		if not ok then
			return false, err
		end
		local rewards = if completion then { xp = 300, pay = 2000, paid = true, rep = 3, stats = { "Skill" } } else nil
		if completion then
			r.lastRewards = rewards
		end
		return true,
			{
				result = result,
				view = Runs.publicView(mod, r, ctxFor(mod)),
				rewards = rewards,
				completed = completion ~= nil,
			}
	end
	function ctl:Abandon(id: string)
		table.insert(self.calls, "abandon")
		return Runs.abandon(record(id), NOW), nil
	end
	function ctl:GetDraft()
		return nil
	end
	function ctl:SaveDraft() end
	function ctl:NoteActive() end
	return ctl
end

local function screenCtx(ctl: any): any
	local notes: { string } = {}
	return {
		Registry = {
			get = function(name: string)
				return if name == "ProjectController" then ctl else nil
			end,
		},
		UI = {
			Notify = function(_self: any, s: string)
				table.insert(notes, s)
			end,
			Confirm = function(_self: any, _opts: any, cb: (boolean) -> ())
				cb(true)
			end,
		},
		close = function() end,
		_notes = notes,
	}
end

return function(t)
	for _, themeName in Theme.names do
		t.describe("parts under " .. themeName, function()
			Theme.set(themeName)
			t.it("the runner draws every stage of every deal and cleans up", function()
				for _, mod in MODS do
					for seed = 1, 3 do
						local list = views(mod, seed)
						t.expect(#list).toBe(#mod.stages)
						for i, view in list do
							local root = Instance.new("Frame")
							local draft: any = nil
							local runner = RunnerView.build(root, view, {
								confirm = function() end,
								onSubmit = function() end,
								onAbandon = function() end,
								onDraft = function(a: any)
									draft = a
								end,
							})
							if find(root, "RenderError") then
								error(("%s stage %d (%s) failed to render"):format(mod.id, i, view.payload.kind))
							end
							t.expect(find(root, "Submit") ~= nil).toBeTruthy()
							t.expect(find(root, "DealRoom") ~= nil).toBeTruthy()
							t.expect(find(root, "Stepper") ~= nil).toBeTruthy()
							t.expect(find(root, "Stage" .. i) ~= nil).toBeTruthy()
							local progress = (find(root, "Progress") :: any).Text
							local total = Kinds.answerTotal(view.payload)
							t.expect(string.find(progress, "/" .. total, 1, true) ~= nil).toBeTruthy()
							-- the final stage closes the deal
							local label = ((find(root, "Submit") :: Instance):FindFirstChild("Label", true) :: any).Text
							if i == #list then
								t.expect(string.find(label, Registry.text("runner_final"), 1, true) ~= nil).toBeTruthy()
							end
							if view.payload.kind == "multi" then
								t.expect(type(draft) == "table").toBeTruthy()
							end
							runner.destroy()
							t.expect(#root:GetChildren()).toBe(0)
						end
					end
				end
			end)
			t.it("the debrief and the results story build, closed and pulled", function()
				for _, mod in MODS do
					local _, done = views(mod, 4)
					local root = Instance.new("Frame")
					local d = DebriefView.build(root, {
						result = {
							stageTitle = "The CIM",
							score = 72,
							debrief = "Buyers liked it.",
							feedback = { "Fix the footer." },
							nextStage = "Bids",
						},
						final = false,
					}, { onContinue = function() end })
					t.expect((find(root, "Score") :: any).Text).toBe("72")
					t.expect(find(root, "Debrief") ~= nil).toBeTruthy()
					t.expect(find(root, "Next") ~= nil).toBeTruthy()
					d.destroy()
					t.expect(#root:GetChildren()).toBe(0)

					local r = ResultsView.build(root, done, nil, { onBack = function() end, onClose = function() end })
					t.expect((find(root, "Stamp") :: any).Text).toBe(Registry.text("result_closed"))
					t.expect((find(root, "DealName") :: any).Text).toContain(done.dealName)
					t.expect(find(root, "Figure1") ~= nil).toBeTruthy()
					t.expect(find(root, "Trained") ~= nil).toBeTruthy()
					r.destroy()

					local pulled = table.clone(done)
					pulled.outcome = table.clone(done.outcome)
					pulled.outcome.closed = false
					local p = ResultsView.build(root, pulled, {}, { onBack = function() end, onClose = function() end })
					t.expect((find(root, "Stamp") :: any).Text).toBe(Registry.text("result_pulled"))
					p.destroy()
					t.expect(#root:GetChildren()).toBe(0)
				end
			end)
			t.it("the list shows one card per deal with the right action", function()
				local projects: { [string]: any } = { ib_sellside = Registry.record(nil) }
				local who = Registry.who(career(1))
				Runs.start(sellside, projects.ib_sellside, who, NOW, { seed = 2, ctx = ctxFor(sellside) })
				local list = {
					who = { employed = true, track = "ib", rank = 1, title = "Analyst" },
					cards = Runs.list(MODS, projects, who, NOW),
					activeCount = 1,
					maxActive = 2,
				}
				local root = Instance.new("Frame")
				local lv = ListView.build(root, list, {
					clock = function()
						return 0
					end,
					onStart = function() end,
					onResume = function() end,
					onRefresh = function() end,
				})
				local sellCard = find(root, "Deal_ib_sellside") :: Instance
				local ipoCard = find(root, "Deal_ipo") :: Instance
				t.expect(sellCard ~= nil).toBeTruthy()
				t.expect(ipoCard ~= nil).toBeTruthy()
				local sellLabel = (
					(sellCard:FindFirstChild("Action", true) :: Instance):FindFirstChild("Label", true) :: any
				).Text
				t.expect(sellLabel).toBe(Registry.text("card_resume", { i = 1, n = #sellside.stages }))
				local ipoLabel = (
					(ipoCard:FindFirstChild("Action", true) :: Instance):FindFirstChild("Label", true) :: any
				).Text
				t.expect(ipoLabel).toContain(Registry.rankTitle("ib", 3))
				lv.destroy()
				-- students see the empty state
				local empty = ListView.build(root, { who = { employed = false }, cards = {} }, {
					clock = function()
						return 0
					end,
					onStart = function() end,
					onResume = function() end,
					onRefresh = function() end,
				})
				t.expect((find(root, "EmptyText") :: any).Text).toBe(Registry.text("empty_student"))
				empty.destroy()
			end)
		end)
	end

	t.describe("Project screen", function()
		t.it("walks list -> runner -> debrief -> results for a whole deal", function()
			local ctl = fakeController(1)
			-- capture the handlers the screen passes to its parts (the screen and this spec share the modules)
			local listHandlers: any, runnerHandlers: any, debriefHandlers: any = nil, nil, nil
			local realList, realRunner, realDebrief = ListView.build, RunnerView.build, DebriefView.build
			ListView.build = function(p: Instance, l: any, h: any)
				listHandlers = h
				return realList(p, l, h)
			end
			RunnerView.build = function(p: Instance, v: any, h: any)
				runnerHandlers = h
				return realRunner(p, v, h)
			end
			DebriefView.build = function(p: Instance, i: any, h: any)
				debriefHandlers = h
				return realDebrief(p, i, h)
			end
			local ok, err = pcall(function()
				local root = Instance.new("Frame")
				local handle = ProjectScreen.open({}, root, screenCtx(ctl))
				t.expect(find(root, "DealList") ~= nil).toBeTruthy()
				listHandlers.onStart("ib_sellside")
				t.expect(find(root, "Runner") ~= nil).toBeTruthy()
				local guard = 0
				while find(root, "Results") == nil do
					guard += 1
					assert(guard <= 12, "never reached the results")
					runnerHandlers.onSubmit({})
					t.expect(find(root, "Debrief") ~= nil).toBeTruthy()
					debriefHandlers.onContinue()
				end
				t.expect((find(root, "Stamp") :: any).Text).toBe(Registry.text("result_closed"))
				t.expect(table.find(ctl.calls, "act:" .. #sellside.stages)).toBeTruthy()
				handle.close()
				t.expect(#root:GetChildren()).toBe(0)
			end)
			ListView.build, RunnerView.build, DebriefView.build = realList, realRunner, realDebrief
			if not ok then
				error(err)
			end
		end)
		t.it("opens a deal directly and goes back to the list after abandoning", function()
			local ctl = fakeController(3)
			local runnerHandlers: any = nil
			local realRunner = RunnerView.build
			RunnerView.build = function(p: Instance, v: any, h: any)
				runnerHandlers = h
				return realRunner(p, v, h)
			end
			local ok, err = pcall(function()
				ctl:StartDeal("ipo")
				local root = Instance.new("Frame")
				local handle = ProjectScreen.open({ id = "ipo" }, root, screenCtx(ctl))
				t.expect(find(root, "Runner") ~= nil).toBeTruthy()
				runnerHandlers.onAbandon()
				t.expect(find(root, "DealList") ~= nil).toBeTruthy()
				t.expect(table.find(ctl.calls, "abandon")).toBeTruthy()
				handle.close()
			end)
			RunnerView.build = realRunner
			if not ok then
				error(err)
			end
		end)
		t.it("shows a retry message when the list can't load", function()
			local ctl = fakeController(1)
			function ctl:List()
				return false, "not_loaded"
			end
			local root = Instance.new("Frame")
			local handle = ProjectScreen.open({}, root, screenCtx(ctl))
			t.expect((find(root, "MessageText") :: any).Text).toBe(Registry.text("err_not_loaded"))
			t.expect(find(root, "Retry") ~= nil).toBeTruthy()
			handle.close()
		end)
	end)

	t.describe("view helpers", function()
		t.it("wire() keeps dense arrays and string-keys tables with holes", function()
			local dense = View.wire({ { q1 = 2 }, { a = 1 } })
			t.expect(dense[1].q1).toBe(2)
			t.expect(dense[2].a).toBe(1)
			local holes = View.wire({ [2] = { x = 1 } })
			t.expect(holes["2"].x).toBe(1)
			t.expect(holes[2]).toBeNil()
			local mixed = View.wire({ [1] = "a", b = "c" })
			t.expect(mixed["1"]).toBe("a")
			t.expect(mixed.b).toBe("c")
			t.expect(View.wire("x")).toBe("x")
		end)
		t.it("error text falls back politely", function()
			t.expect(View.errorText("not_loaded")).toBe(Registry.text("err_not_loaded"))
			t.expect(View.errorText("no_such_error")).toBe(Registry.text("err_generic"))
			t.expect(View.errorText(nil)).toBe(Registry.text("err_generic"))
			t.expect(View.errorText("missing")).toBe(Registry.text("err_unavailable"))
			t.expect(View.errorText("cooldown", { time = "4m 05s" })).toContain("4m 05s")
			t.expect(View.errorText("cooldown")).never(Registry.text("err_cooldown"))
		end)
		t.it("card actions follow status and count cooldowns down", function()
			t.expect(View.cardAction({ status = "available" }, 0).kind).toBe("start")
			t.expect(View.cardAction({ status = "active", stageIndex = 2, stageCount = 5 }, 0).kind).toBe("resume")
			local wait = View.cardAction({ status = "cooldown", cooldownLeft = 90 }, 30)
			t.expect(wait.kind).toBe("wait")
			t.expect(wait.label).toContain("1m 00s")
			t.expect(View.cardAction({ status = "cooldown", cooldownLeft = 90 }, 95).kind).toBe("start")
			t.expect(View.cardAction({ status = "locked", reason = "rank_low", vars = { title = "VP" } }, 0).label)
				.toContain("VP")
		end)
		t.it("empty states and the subtitle", function()
			t.expect(View.emptyText({ who = { fired = true }, cards = {} })).toBe(Registry.text("empty_fired"))
			t.expect(View.emptyText({ who = { employed = true }, cards = {} })).toBe(Registry.text("empty_track"))
			t.expect(View.emptyText({ who = { employed = true }, cards = { {} } })).toBeNil()
			t.expect(View.subtitle({ who = { employed = true, title = "Analyst", trackName = "Investment Banking" } }))
				.toBe("Investment Banking · Analyst")
			t.expect(View.subtitle({})).toBe(Registry.text("subtitle_none"))
		end)
	end)
end
