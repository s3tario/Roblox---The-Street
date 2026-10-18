-- Work UI under Lune: every WorkKinds renderer draws every task module's payloads (both themes) and cleans up;
-- multi answers never have holes; the Work screen walks board -> runner -> results with a fake WorkController;
-- the pure view rules (prompt visibility, card actions, timers, empty states).
local Shared = game:GetService("ReplicatedStorage").Shared
local Client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
local Rng = require(Shared.Util.Rng)
local Signal = require(Shared.Util.Signal)
local Config = require(Shared.Config.Tasks)
local TasksFolder = Shared.Logic.Tasks
local Solve = require(TasksFolder._shared.Solve)
local Kinds = require(TasksFolder._shared.Kinds)
local Theme = require(Client.UI.Theme)
local WorkKinds = Client.UI.WorkKinds
local WorkScreen = require(Client.UI.Screens.Work)
local View = require(Client.UI.Screens.WorkParts.View)
local RunnerView = require(Client.UI.Screens.WorkParts.Runner)
local ResultsView = require(Client.UI.Screens.WorkParts.Results)
local BoardView = require(Client.UI.Screens.WorkParts.BoardView)

local function modules(): { any }
	local out: { any } = {}
	for _, child in TasksFolder:GetChildren() do
		if string.sub(child.Name, 1, 1) ~= "_" then
			table.insert(out, require(child))
		end
	end
	table.sort(out, function(a, b)
		return a.id < b.id
	end)
	return out
end
local MODS = modules()

local function container(): Frame
	local f = Instance.new("Frame")
	local layout = Instance.new("UIListLayout")
	layout.Parent = f
	return f
end

local function find(root: Instance, name: string): Instance?
	return root:FindFirstChild(name, true)
end

local function count(root: Instance, prefix: string): number
	local n = 0
	for _, d in root:GetDescendants() do
		if string.sub(d.Name, 1, #prefix) == prefix then
			n += 1
		end
	end
	return n
end

local function sampleBoard(active: any?): any
	return {
		role = "ib:1",
		student = false,
		unemployed = false,
		day = 7,
		dayLabel = "Week 2 · Tue",
		nextIn = 200,
		now = 1000,
		atDesk = true,
		deskPct = 10,
		done = 1,
		total = 3,
		tasks = {
			{
				id = "comps_analysis",
				title = "Trading Comps",
				desc = "d",
				kind = "fill",
				category = "work",
				core = true,
				done = false,
				xp = 120,
				pay = 480,
				timeLimit = 270,
				stats = { "Skill" },
			},
			{
				id = "interview_ib",
				title = "First-Round Interview",
				desc = "d",
				kind = "multi",
				category = "interview",
				core = false,
				done = false,
				offered = true,
				label = "MG Freeman",
				expiresAt = 4000,
				xp = 80,
				pay = 0,
				timeLimit = 240,
				stats = {},
			},
			{
				id = "data_cleanup",
				title = "Data Clean-up",
				desc = "d",
				kind = "spot",
				category = "work",
				core = false,
				done = true,
				quality = 88,
				xp = 60,
				pay = 300,
				timeLimit = 180,
				stats = {},
			},
		},
		active = active,
		totals = { tasks = 3, xp = 300, pay = 900, late = 0 },
	}
end

local function activeFor(mod: any, seed: number): (any, any)
	local payload, secret = mod.generate(Rng.new(seed), { difficulty = 0.6, hints = 2 })
	return {
		instanceId = "inst-" .. mod.id,
		taskId = mod.id,
		title = payload.title,
		kind = payload.kind,
		payload = payload,
		startedAt = 1000,
		limit = 200,
		grace = 5,
		endsAt = 1200,
		how = Config.kinds[payload.kind].how,
		desk = true,
	},
		secret
end

return function(t)
	for _, themeName in Theme.names do
		t.describe("renderers under " .. themeName, function()
			Theme.set(themeName)
			t.it("every module's payloads mount, report answers and clean up", function()
				for _, mod in MODS do
					for _, d in { 0.1, 0.5, 0.9 } do
						for seed = 1, 3 do
							local payload = mod.generate(Rng.new(seed * 101), { difficulty = d, hints = 2 })
							local renderer = require(WorkKinds:FindFirstChild(payload.kind))
							local root = container()
							local reported: any = nil
							local ok, cleanup = pcall(renderer.mount, root, payload, {
								onChange = function(a: any)
									reported = a
								end,
							})
							if not ok then
								error(
									("%s (%s, d=%.1f seed %d) failed to mount: %s"):format(
										mod.id,
										payload.kind,
										d,
										seed,
										tostring(cleanup)
									)
								)
							end
							t.expect(#root:GetChildren()).toBeGreaterThan(1)
							if payload.kind == "multi" then
								t.expect(type(reported) == "table").toBeTruthy()
								for i = 1, #payload.sections do
									t.expect(type(reported[i]) == "table").toBeTruthy()
								end
							elseif payload.kind == "order" then
								t.expect(#reported).toBe(#payload.items)
							end
							cleanup()
							t.expect(#root:GetChildren()).toBe(1) -- only the layout is left
						end
					end
				end
			end)
			t.it("renderers restore previous answers (resume)", function()
				for _, mod in MODS do
					local payload, secret = mod.generate(Rng.new(55), { difficulty = 0.5, hints = 1 })
					local perfect = Solve.perfect(secret)
					local renderer = require(WorkKinds:FindFirstChild(payload.kind))
					local root = container()
					local reported: any = nil
					local cleanup = renderer.mount(root, payload, {
						answers = perfect,
						onChange = function(a: any)
							reported = a
						end,
					})
					if payload.kind == "order" then
						t.expect(reported).toEqual(perfect)
					elseif payload.kind == "multi" then
						for i, sub in perfect do
							if payload.sections[i].kind == "order" then
								t.expect(reported[i]).toEqual(sub)
							end
						end
					end
					cleanup()
				end
			end)
			t.it("mcq and dialogue draw one button per option", function()
				local quiz = require(TasksFolder.finance_club_quiz)
				local payload = quiz.generate(Rng.new(3), { difficulty = 0.9 })
				local root = container()
				local cleanup = require(WorkKinds.mcq).mount(root, payload, { onChange = function() end })
				local options = 0
				for _, q in payload.questions do
					options += #q.options
				end
				t.expect(count(root, "Option")).toBe(options)
				cleanup()
				local chat = require(TasksFolder.networking_chat)
				local dp = chat.generate(Rng.new(3), { difficulty = 0.9 })
				local droot = container()
				local dclean = require(WorkKinds.dialogue).mount(droot, dp, { onChange = function() end })
				t.expect(find(droot, "Turn1") ~= nil).toBeTruthy()
				-- only the first turn shows until it is answered
				t.expect((find(droot, "Turn2") :: any).Visible).toBe(false)
				dclean()
			end)
		end)
	end

	t.describe("screen parts", function()
		t.it("runner draws every module's payload with timer, hints and footer", function()
			for _, mod in MODS do
				local active = activeFor(mod, 9)
				local root = Instance.new("Frame")
				local runner = RunnerView.build(root, active, {
					now = function()
						return 1100
					end,
					confirm = function() end,
					onSubmit = function() end,
					onAbandon = function() end,
				})
				t.expect(find(root, "Submit") ~= nil).toBeTruthy()
				t.expect(find(root, "Timer") ~= nil).toBeTruthy()
				t.expect((find(root, "Timer") :: any).Text).toBe("1:40")
				t.expect(find(root, "RenderError")).toBeNil()
				if active.payload.hints then
					t.expect(find(root, "HintsToggle") ~= nil).toBeTruthy()
				end
				local progress = (find(root, "Progress") :: any).Text
				t.expect(string.find(progress, "/" .. Kinds.answerTotal(active.payload), 1, true) ~= nil).toBeTruthy()
				runner.destroy()
				t.expect(#root:GetChildren()).toBe(0)
			end
		end)
		t.it("runner shows overtime in the late state", function()
			local active = activeFor(MODS[1], 2)
			local root = Instance.new("Frame")
			local runner = RunnerView.build(root, active, {
				now = function()
					return 1265
				end,
				confirm = function() end,
				onSubmit = function() end,
				onAbandon = function() end,
			})
			t.expect(string.find((find(root, "Timer") :: any).Text, "1:05", 1, true) ~= nil).toBeTruthy()
			t.expect((find(root, "LateNote") :: any).Visible).toBe(true)
			runner.destroy()
		end)
		t.it("results show the score, rewards and every feedback note", function()
			local root = Instance.new("Frame")
			local r = ResultsView.build(root, {
				title = "Trading Comps",
				quality = 83,
				correct = 3,
				total = 4,
				feedback = {
					"Solid work.",
					"Median: about 9.4x (you entered 8.1x).",
					"Equity value = EV − net debt.",
				},
				sections = { { kind = "fill", score = 80 }, { kind = "mcq", score = 100 } },
				onTime = true,
				xp = 140,
				xpCapped = true,
				pay = 520,
				paid = true,
				rep = 1.1,
				stats = { "Skill", "Knowledge" },
			}, { onBack = function() end, onClose = function() end })
			t.expect((find(root, "Quality") :: any).Text).toBe("83")
			t.expect(find(root, "Note1") ~= nil).toBeTruthy()
			t.expect(find(root, "Note2") ~= nil).toBeTruthy()
			t.expect(find(root, "Parts") ~= nil).toBeTruthy()
			t.expect(find(root, "Capped") ~= nil).toBeTruthy()
			r.destroy()
		end)
		t.it("board shows a card per task with the right actions", function()
			local root = Instance.new("Frame")
			local b = BoardView.build(root, sampleBoard(nil), {
				now = function()
					return 1000
				end,
				onStart = function() end,
				onResume = function() end,
				onRefresh = function() end,
			})
			t.expect(find(root, "Card_comps_analysis") ~= nil).toBeTruthy()
			t.expect(find(root, "Card_interview_ib") ~= nil).toBeTruthy()
			t.expect(find(root, "OfferLabel") ~= nil).toBeTruthy()
			local doneCard = find(root, "Card_data_cleanup") :: Instance
			local label = ((doneCard:FindFirstChild("Action", true) :: Instance):FindFirstChild("Label", true) :: any).Text
			t.expect(label).toBe(Config.text("board_quality", { q = 88 }))
			b.destroy()
		end)
	end)

	t.describe("Work screen", function()
		local function fakeController(active: any?): any
			local ctl: any = { BoardChanged = Signal.new(), calls = {} }
			local board = sampleBoard(active)
			function ctl:GetBoard()
				table.insert(self.calls, "board")
				return true, board
			end
			function ctl:StartTask(id: string)
				table.insert(self.calls, "start:" .. id)
				return true, activeFor(require(TasksFolder[id]), 4)
			end
			function ctl:Submit(_id: string, _answers: any)
				table.insert(self.calls, "submit")
				return true,
					{
						title = "x",
						quality = 70,
						feedback = { "ok" },
						onTime = true,
						xp = 10,
						pay = 0,
						paid = false,
						rep = 0,
						stats = {},
					}
			end
			function ctl:Abandon(_id: string)
				table.insert(self.calls, "abandon")
				return true
			end
			function ctl:GetDraft()
				return nil
			end
			function ctl:SaveDraft() end
			return ctl
		end
		local function ctxFor(ctl: any): any
			local notes: { string } = {}
			return {
				Registry = {
					get = function(name: string)
						return if name == "WorkController" then ctl else nil
					end,
				},
				UI = {
					Notify = function(_self: any, text: string)
						table.insert(notes, text)
					end,
					Confirm = function(_self: any, _opts: any, cb: (boolean) -> ())
						cb(true)
					end,
				},
				close = function() end,
				now = function()
					return 1000
				end,
				_notes = notes,
			}
		end
		for _, themeName in Theme.names do
			t.it("opens on the board (" .. themeName .. ")", function()
				Theme.set(themeName)
				local ctl = fakeController(nil)
				local root = Instance.new("Frame")
				local handle = WorkScreen.open({}, root, ctxFor(ctl))
				t.expect(find(root, "BoardView") ~= nil).toBeTruthy()
				t.expect(find(root, "Card_comps_analysis") ~= nil).toBeTruthy()
				handle.close()
			end)
		end
		t.it("resumes the attempt in progress", function()
			local active = activeFor(require(TasksFolder.deal_process), 6)
			local ctl = fakeController(active)
			local root = Instance.new("Frame")
			local handle = WorkScreen.open({ instanceId = active.instanceId }, root, ctxFor(ctl))
			t.expect(find(root, "Runner") ~= nil).toBeTruthy()
			t.expect(find(root, "OrderList") ~= nil).toBeTruthy()
			handle.close()
		end)
		t.it("a board refresh that lands after a task started never replaces the runner", function()
			local ctl = fakeController(nil)
			local gated = false
			local parked: thread? = nil
			local baseGetBoard = ctl.GetBoard
			function ctl:GetBoard()
				if gated then
					parked = coroutine.running()
					coroutine.yield()
				end
				return baseGetBoard(self)
			end
			-- capture the board's handlers (the screen and this spec share the BoardView module)
			local handlers: any = nil
			local realBuild = BoardView.build
			BoardView.build = function(parent: Instance, board: any, h: any)
				handlers = h
				return realBuild(parent, board, h)
			end
			local ok, err = pcall(function()
				local root = Instance.new("Frame")
				local handle = WorkScreen.open({}, root, ctxFor(ctl))
				t.expect(find(root, "BoardView") ~= nil).toBeTruthy()
				gated = true
				handlers.onRefresh() -- in flight, parked
				t.expect(parked ~= nil).toBeTruthy()
				gated = false
				handlers.onStart("comps_analysis") -- resolves at once: the runner opens
				t.expect(find(root, "Runner") ~= nil).toBeTruthy()
				task.spawn(parked :: thread) -- the stale board reply arrives now
				t.expect(find(root, "Runner") ~= nil).toBeTruthy()
				t.expect(find(root, "BoardView")).toBeNil()
				handle.close()
			end)
			BoardView.build = realBuild
			if not ok then
				error(err, 0)
			end
		end)
		t.it("shows a polite message when the controller is missing", function()
			local root = Instance.new("Frame")
			local handle = WorkScreen.open(
				{},
				root,
				{ Registry = {
					get = function()
						return nil
					end,
				}, close = function() end }
			)
			local msg = find(root, "MessageText") :: any
			t.expect(msg ~= nil).toBeTruthy()
			t.expect(msg.Text).toBe(Config.text("err_unavailable"))
			handle.close()
		end)
	end)

	t.describe("view rules", function()
		t.it("desk prompts: office desks for that firm's employees, campus desks for students", function()
			local student = { status = "student", roleId = "student", companyId = "" }
			local banker = { status = "active", roleId = "ib_analyst", companyId = "mg_freeman" }
			local fired = { status = "fired", roleId = "unemployed", companyId = "" }
			local office = { employeesOnly = true, companyId = "mg_freeman" }
			local otherOffice = { employeesOnly = true, companyId = "evermoor" }
			local campus = { studentsOnly = true }
			t.expect(View.canUsePrompt(banker, nil, office, 0)).toBe(true)
			t.expect(View.canUsePrompt(banker, nil, otherOffice, 0)).toBe(false)
			t.expect(View.canUsePrompt(student, nil, office, 0)).toBe(false)
			t.expect(View.canUsePrompt(student, nil, campus, 0)).toBe(true)
			t.expect(View.canUsePrompt(fired, nil, campus, 0)).toBe(true)
			t.expect(View.canUsePrompt(banker, nil, campus, 0)).toBe(false)
			t.expect(View.canUsePrompt(nil, nil, office, 0)).toBe(false)
			t.expect(View.canUsePrompt(nil, nil, {}, 0)).toBe(true)
			local partners = function(_events: any, companyId: string): { [string]: boolean }
				return if companyId == "mg_freeman" then { evermoor = true } else {}
			end
			t.expect(View.canUsePrompt(banker, {}, otherOffice, 0, partners)).toBe(true)
		end)
		t.it("card actions follow done, active, cooldown and ready states", function()
			local card = { id = "a", done = false }
			t.expect(View.cardAction(card, 100, nil).action).toBe("start")
			t.expect(View.cardAction({ id = "a", done = true, quality = 71 }, 100, nil).action).toBe("done")
			t.expect(View.cardAction(card, 100, { taskId = "a" }).action).toBe("resume")
			t.expect(View.cardAction(card, 100, { taskId = "b" }).action).toBe("busy")
			local cooling = View.cardAction({ id = "a", cooldownUntil = 160 }, 100, nil)
			t.expect(cooling.action).toBe("cooldown")
			t.expect(cooling.enabled).toBe(false)
			t.expect(cooling.text).toBe(Config.text("board_cooldown", { time = "1:00" }))
		end)
		t.it("offer countdowns tick for open offers only", function()
			local offer = { id = "interview_ib", offered = true, done = false, expiresAt = 1125 }
			t.expect(View.expiryText(offer, 1000)).toBe(Config.text("board_expires", { time = "2m 05s" }))
			t.expect(View.expiryText(offer, 2000)).toBe(Config.text("board_expires", { time = "0s" }))
			t.expect(View.expiryText({ id = "a", offered = true, done = true, expiresAt = 1125 }, 1000)).toBeNil()
			t.expect(View.expiryText({ id = "a", offered = false, expiresAt = 1125 }, 1000)).toBeNil()
			t.expect(View.expiryText({ id = "a", offered = true }, 1000)).toBeNil()
			for _, tag in View.cardTags(offer, 1000) do
				t.expect(string.find(tag.text, "Expires", 1, true)).toBeNil()
			end
		end)
		t.it("headers and empty states read naturally", function()
			t.expect(View.title({ student = true })).toBe(Config.text("board_title_student"))
			t.expect(View.title({ student = false })).toBe(Config.text("board_title"))
			t.expect(View.subtitle(sampleBoard(nil))).toBe("Week 2 · Tue · 1/3 done")
			t.expect(View.emptyText(sampleBoard(nil))).toBeNil()
			t.expect(View.emptyText({ total = 0, unemployed = true })).toBe(Config.text("board_unemployed"))
			t.expect(View.emptyText({ total = 2, done = 2, nextIn = 125 }))
				.toBe(Config.text("board_all_done", { time = "2m 05s" }))
			t.expect(View.emptyText({ total = 2, done = 2, nextIn = -1 })).toBe(Config.text("board_friday"))
			t.expect(View.emptyText(nil)).toBe(Config.text("board_loading"))
		end)
		t.it("timers, quality colours and error text", function()
			t.expect((View.timer(200, 100))).toBe("1:40")
			local text, over = View.timer(100, 130)
			t.expect(over).toBe(true)
			t.expect(text).toBe(Config.text("runner_overtime", { time = "0:30" }))
			t.expect(View.qualityColor(90)).toBe("good")
			t.expect(View.qualityColor(10)).toBe("bad")
			t.expect(View.errorText("busy")).toBe(Config.text("err_busy"))
			t.expect(View.errorText("nonsense")).toBe(Config.text("err_generic"))
			t.expect(View.errorText("void")).toBe(Config.text("toast_void"))
		end)
	end)

	t.describe("config", function()
		t.it("every remote error key has text and every string is filled", function()
			for key, stringKey in Config.ERRORS do
				t.expect(type(Config.strings[stringKey]) == "string").toBeTruthy()
				t.expect(key ~= "").toBeTruthy()
			end
			for k, v in Config.strings do
				if type(v) ~= "string" or v == "" then
					error("empty string " .. k)
				end
			end
			for _, kind in Config.KIND_IDS do
				t.expect(WorkKinds:FindFirstChild(kind) ~= nil).toBeTruthy()
				t.expect(Config.kinds[kind] ~= nil).toBeTruthy()
			end
		end)
	end)
end
