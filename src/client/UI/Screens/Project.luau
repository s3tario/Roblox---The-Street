--!strict
-- Project screen (owned by `projects`; contracts §9 and §14 screen shape): big deals. list -> runner -> debrief after
-- every stage -> the results story with the big "Deal closed" moment.
--   * List: the deals of the player's track (ProjectParts/ListView). Start a new one or resume one in progress.
--   * Runner: the stage stepper, the deal room metrics and the stage payload drawn by UI/WorkKinds/<kind>
--     (ProjectParts/Runner). Answers are kept as a draft in ProjectController, so closing and reopening keeps them.
--   * Debrief: the stage score and what it did to the deal (ProjectParts/Debrief).
--   * Results: DEAL CLOSED / DEAL PULLED, the plaque, the story and the rewards (ProjectParts/Results).
-- Everything goes through ProjectController (ctx.Registry), which wraps the Project.* remotes. The campus/street
-- theme comes from UIController and the Kit.
--
--   args = { id?, filter?, source? }   (Project.Open from a deal desk, or the menu tab; id opens that deal)

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Registry = require(Shared:WaitForChild("Logic"):WaitForChild("Projects"):WaitForChild("_registry"))
local Kit = require(script.Parent.Parent:WaitForChild("Kit"))
local Parts = script.Parent:WaitForChild("ProjectParts")
local View = require(Parts:WaitForChild("View"))
local ListView = require(Parts:WaitForChild("ListView"))
local RunnerView = require(Parts:WaitForChild("Runner"))
local DebriefView = require(Parts:WaitForChild("Debrief"))
local ResultsView = require(Parts:WaitForChild("Results"))

local Project = { id = "Project" }

local text = Registry.text
local REFRESH_DEBOUNCE = 0.6

-- errors after which the run is gone (or moved on) server-side: go back to the list
local RUN_GONE = { not_active = true, done = true, broken = true, unknown = true, not_employed = true } :: {
	[string]: boolean,
}

function Project.open(args: any, root: Instance, ctx: any): { close: () -> () }
	local a: { [string]: any } = if type(args) == "table" then args else {}
	local registry = if type(ctx) == "table" then ctx.Registry else nil
	local ctl: any = nil
	if type(registry) == "table" and type(registry.get) == "function" then
		ctl = registry.get("ProjectController")
	end
	local ui = if type(ctx) == "table" then ctx.UI else nil
	local closeScreen = if type(ctx) == "table" and type(ctx.close) == "function" then ctx.close else function() end

	local win = Kit.Window({
		title = text("title"),
		subtitle = text("loading"),
		size = UDim2.fromScale(1, 1),
		maxSize = Vector2.new(820, 760),
		onClose = closeScreen,
		name = "ProjectWindow",
	})
	win.frame.Parent = root
	local body = Kit.frame("Body")
	body.Parent = win.content

	local closed = false
	local current: { destroy: () -> () }? = nil
	local mode = "loading"
	local lastList: any = nil
	-- every remote round trip remembers the view generation it started in; a reply that lands after the view moved on
	-- is dropped instead of replacing the newer view
	local generation = 0
	local function nextGeneration(): number
		generation += 1
		return generation
	end
	local function stale(gen: number): boolean
		return closed or gen ~= generation
	end

	local function notify(s: string, kind: string?)
		if ui and type(ui.Notify) == "function" then
			pcall(function()
				ui:Notify(s, kind)
			end)
		end
	end

	local function confirm(opts: { [string]: any }, cb: (boolean) -> ())
		if ui and type(ui.Confirm) == "function" then
			local ok = pcall(function()
				ui:Confirm(opts, cb)
			end)
			if ok then
				return
			end
		end
		Kit.Confirm(opts :: any, cb)
	end

	local function clear()
		local c = current
		if c then
			current = nil
			pcall(c.destroy)
		end
	end

	local function showMessage(s: string, retry: (() -> ())?)
		clear()
		mode = "message"
		local frame = Kit.frame("Message")
		frame.Parent = body
		local list = Kit.List({ gap = 12, align = "center", padding = 16, name = "MessageList" })
		list.frame.Parent = frame
		Kit.Label({ text = s, align = "center", color = "textDim", name = "MessageText", layoutOrder = 1 }).frame.Parent =
			list.frame
		if retry then
			Kit.Button({ text = text("retry"), name = "Retry", layoutOrder = 2, onClick = retry }).frame.Parent =
				list.frame
		end
		current = {
			destroy = function()
				frame:Destroy()
			end,
		}
	end

	local loadList: () -> ()
	local showRunner: (view: any) -> ()
	local openDeal: (id: string) -> ()

	local function showResults(view: any, rewards: any)
		nextGeneration()
		clear()
		mode = "results"
		win.setTitle(tostring(view.title or text("title")))
		current = ResultsView.build(body, view, rewards, {
			onBack = function()
				loadList()
			end,
			onClose = function()
				closeScreen()
			end,
		})
	end

	local function showDebrief(res: any)
		nextGeneration()
		clear()
		mode = "debrief"
		local after = if type(res.view) == "table" then res.view else nil
		local final = res.completed == true
		current = DebriefView.build(body, { result = res.result, final = final }, {
			onContinue = function()
				if final and after then
					showResults(after, res.rewards)
				elseif after and after.done ~= true then
					showRunner(after)
				else
					loadList()
				end
			end,
		})
	end

	showRunner = function(view: any)
		if type(view) ~= "table" then
			loadList()
			return
		end
		if view.done == true then
			showResults(view, nil)
			return
		end
		nextGeneration()
		clear()
		mode = "runner"
		local id = tostring(view.id)
		local stageIndex = math.floor(tonumber(view.stageIndex) or 1)
		win.setTitle(tostring(view.title or text("title")))
		if lastList then
			win.setSubtitle(View.subtitle(lastList))
		end
		local draft = if ctl and type(ctl.GetDraft) == "function" then ctl:GetDraft(id, stageIndex) else nil
		local runner: { [string]: any }
		runner = RunnerView.build(body, view, {
			draft = draft,
			confirm = confirm,
			onDraft = function(answers: any)
				if ctl and type(ctl.SaveDraft) == "function" then
					ctl:SaveDraft(id, stageIndex, answers)
				end
			end,
			onSubmit = function(answers: any)
				if not ctl then
					return
				end
				runner.setBusy(true)
				local gen = generation
				task.spawn(function()
					local ok, res, vars = ctl:Act(id, answers, stageIndex)
					if stale(gen) then
						return
					end
					if ok and type(res) == "table" then
						showDebrief(res)
						return
					end
					runner.setBusy(false)
					notify(View.errorText(res, vars), "warn")
					if res == "stale" then
						openDeal(id)
					elseif type(res) == "string" and RUN_GONE[res] then
						loadList()
					end
				end)
			end,
			onAbandon = function()
				if not ctl then
					return
				end
				runner.setBusy(true)
				local gen = generation
				task.spawn(function()
					local ok, err = ctl:Abandon(id)
					if stale(gen) then
						return
					end
					if not ok and err ~= "not_active" then
						notify(View.errorText(err), "warn")
					end
					loadList()
				end)
			end,
		})
		current = runner :: any
	end

	local function startDeal(id: string)
		if not ctl then
			return
		end
		local gen = nextGeneration()
		showMessage(text("loading"))
		mode = "starting"
		task.spawn(function()
			local ok, view, vars = ctl:StartDeal(id)
			if stale(gen) then
				return
			end
			if ok and type(view) == "table" then
				showRunner(view)
			else
				notify(View.errorText(view, vars), "warn")
				loadList()
			end
		end)
	end

	openDeal = function(id: string)
		if not ctl then
			return
		end
		local gen = nextGeneration()
		showMessage(text("loading"))
		task.spawn(function()
			local ok, view, vars = ctl:View(id)
			if stale(gen) then
				return
			end
			if ok and type(view) == "table" then
				showRunner(view)
			else
				if view ~= "not_active" then
					notify(View.errorText(view, vars), "warn")
				end
				loadList()
			end
		end)
	end

	local function showList(list: any)
		nextGeneration()
		clear()
		mode = "list"
		win.setTitle(text("title"))
		win.setSubtitle(View.subtitle(list))
		local receivedAt = os.clock()
		current = ListView.build(body, list, {
			clock = function(): number
				return os.clock() - receivedAt
			end,
			onStart = startDeal,
			onResume = openDeal,
			onRefresh = function()
				loadList()
			end,
		})
	end

	loadList = function()
		if not ctl then
			showMessage(text("err_unavailable"))
			return
		end
		local gen = nextGeneration()
		if mode ~= "list" then
			showMessage(text("loading"))
		end
		task.spawn(function()
			local ok, list, vars = ctl:List()
			if stale(gen) then
				return
			end
			if not ok or type(list) ~= "table" then
				showMessage(View.errorText(list, vars), function()
					loadList()
				end)
				return
			end
			lastList = list
			if ctl and type(ctl.NoteActive) == "function" then
				ctl:NoteActive(tonumber(list.activeCount) or 0)
			end
			showList(list)
		end)
	end

	-- the server changed a run (fired, moved firm, module reset, completed elsewhere): the list refetches; a runner
	-- for a run that is gone goes back to the list
	local pending = false
	local conn: any = nil
	if ctl and type(ctl.Changed) == "table" and type(ctl.Changed.Connect) == "function" then
		conn = ctl.Changed:Connect(function(info: any)
			if closed or pending then
				return
			end
			local reason = if type(info) == "table" then info.reason else nil
			local interrupts = reason == "fired" or reason == "role" or reason == "reset" or reason == "rebirth"
			if mode == "runner" and not interrupts then
				return
			end
			if mode ~= "list" and mode ~= "runner" and mode ~= "message" then
				return
			end
			pending = true
			task.delay(REFRESH_DEBOUNCE, function()
				pending = false
				if not closed and (mode == "list" or mode == "message" or (mode == "runner" and interrupts)) then
					loadList()
				end
			end)
		end)
	end

	if type(a.id) == "string" then
		openDeal(a.id)
	else
		loadList()
	end

	return {
		close = function()
			closed = true
			if conn then
				pcall(function()
					conn:Disconnect()
				end)
			end
			clear()
			win.close()
		end,
	}
end

return Project
