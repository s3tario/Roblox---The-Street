--!strict
-- Work screen (owned by `work`; contracts §8 and §14 screen shape): board -> runner -> results.
--   * Board: today's tasks (WorkParts/BoardView). Opening the screen while an attempt is in progress resumes it.
--   * Runner: the payload drawn by UI/WorkKinds/<kind>, the timer, hints, Submit / Abandon (WorkParts/Runner).
--     Answers are kept as a draft in WorkController, so closing and reopening the screen keeps them.
--   * Results: quality, rewards and feedback (WorkParts/Results).
-- Everything goes through WorkController (ctx.Registry), which wraps the Work.* remotes. Both themes (campus for
-- students, street once employed) come from the Kit and UIController.
--
--   args = { instanceId?, taskId?, source? }   (Work.Open from a desk prompt or WorkService:StartTask)

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Time = require(Shared:WaitForChild("Util"):WaitForChild("Time"))
local Config = require(Shared:WaitForChild("Config"):WaitForChild("Tasks"))
local Kit = require(script.Parent.Parent:WaitForChild("Kit"))
local Parts = script.Parent:WaitForChild("WorkParts")
local View = require(Parts:WaitForChild("View"))
local BoardView = require(Parts:WaitForChild("BoardView"))
local RunnerView = require(Parts:WaitForChild("Runner"))
local ResultsView = require(Parts:WaitForChild("Results"))

local Work = { id = "Work" }

local REFRESH_DEBOUNCE = 0.6

-- errors after which the attempt is gone server-side: go back to the board
local ATTEMPT_GONE = { expired = true, void = true, no_active = true, wrong_task = true } :: { [string]: boolean }

function Work.open(_args: any, root: Instance, ctx: any): { close: () -> () }
	local registry = if type(ctx) == "table" then ctx.Registry else nil
	local ctl: any = nil
	if type(registry) == "table" and type(registry.get) == "function" then
		ctl = registry.get("WorkController")
	end
	local ui = if type(ctx) == "table" then ctx.UI else nil
	local closeScreen = if type(ctx) == "table" and type(ctx.close) == "function" then ctx.close else function() end
	local now: () -> number = if type(ctx) == "table" and type(ctx.now) == "function" then ctx.now else Time.now

	local win = Kit.Window({
		title = Config.text("board_title"),
		subtitle = Config.text("board_loading"),
		size = UDim2.fromScale(1, 1),
		maxSize = Vector2.new(760, 720),
		onClose = closeScreen,
		name = "WorkWindow",
	})
	win.frame.Parent = root
	local body = Kit.frame("Body")
	body.Parent = win.content

	local closed = false
	local current: { [string]: any }? = nil
	local mode = "loading"
	local starting = false
	local lastBoard: any = nil
	-- Every remote round trip remembers the view generation it started in; a reply that arrives after the view
	-- moved on (a board refresh landing after the player already started a task) is dropped instead of
	-- replacing the newer view.
	local generation = 0
	local function nextGeneration(): number
		generation += 1
		return generation
	end
	local function stale(gen: number): boolean
		return closed or gen ~= generation
	end

	local function notify(text: string, kind: string?)
		if ui and type(ui.Notify) == "function" then
			pcall(function()
				ui:Notify(text, kind)
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
		if current then
			local c = current
			current = nil
			pcall(c.destroy)
		end
	end

	local function showMessage(text: string)
		clear()
		mode = "message"
		local frame = Kit.frame("Message")
		frame.Parent = body
		local list = Kit.List({ gap = 12, align = "center", padding = 16, name = "MessageList" })
		list.frame.Parent = frame
		Kit.Label({ text = text, align = "center", color = "textDim", name = "MessageText", layoutOrder = 1 }).frame.Parent =
			list.frame
		current = {
			destroy = function()
				frame:Destroy()
			end,
		}
		return list.frame
	end

	local loadBoard: (resume: boolean) -> ()

	local function showResults(result: any)
		nextGeneration()
		clear()
		mode = "results"
		win.setTitle(Config.text("result_title"))
		current = ResultsView.build(body, result, {
			onBack = function()
				loadBoard(false)
			end,
			onClose = function()
				closeScreen()
			end,
		})
	end

	local function showRunner(active: any)
		nextGeneration()
		clear()
		mode = "runner"
		win.setTitle(tostring(active.title or Config.text("board_title")))
		win.setSubtitle(if lastBoard then View.subtitle(lastBoard) else nil)
		local instanceId = active.instanceId
		local draft = if ctl and type(ctl.GetDraft) == "function" then ctl:GetDraft(instanceId) else nil
		local runner: { [string]: any }
		runner = RunnerView.build(body, active, {
			now = now,
			draft = draft,
			confirm = confirm,
			onDraft = function(answers: any)
				if ctl and type(ctl.SaveDraft) == "function" then
					ctl:SaveDraft(instanceId, answers)
				end
			end,
			onSubmit = function(answers: any)
				if not ctl then
					return
				end
				runner.setBusy(true)
				task.spawn(function()
					local ok, res = ctl:Submit(instanceId, answers)
					if closed or current ~= runner then
						return
					end
					if ok then
						showResults(res)
						return
					end
					runner.setBusy(false)
					notify(View.errorText(res), "warn")
					if type(res) == "string" and ATTEMPT_GONE[res] then
						loadBoard(false)
					end
				end)
			end,
			onAbandon = function()
				if not ctl then
					return
				end
				runner.setBusy(true)
				task.spawn(function()
					local ok, err = ctl:Abandon(instanceId)
					if closed then
						return
					end
					if not ok then
						notify(View.errorText(err), "warn")
					end
					loadBoard(false)
				end)
			end,
		})
		current = runner
	end

	local function startTask(taskId: string)
		if not ctl or starting then
			return
		end
		starting = true
		mode = "starting" -- live board refreshes pause while the start is in flight
		local gen = nextGeneration()
		task.spawn(function()
			local ok, res = ctl:StartTask(taskId)
			starting = false
			if stale(gen) then
				return
			end
			if ok and type(res) == "table" then
				showRunner(res)
			else
				notify(View.errorText(res), "warn")
				loadBoard(false)
			end
		end)
	end

	local function showBoard(board: any)
		nextGeneration()
		clear()
		mode = "board"
		win.setTitle(View.title(board))
		win.setSubtitle(View.subtitle(board))
		current = BoardView.build(body, board, {
			now = now,
			onStart = startTask,
			onResume = function()
				if board.active then
					showRunner(board.active)
				end
			end,
			onRefresh = function()
				loadBoard(false)
			end,
		})
	end

	loadBoard = function(resume: boolean)
		if not ctl then
			showMessage(Config.text("err_unavailable"))
			return
		end
		-- a newer load (or any other view change) supersedes this one
		local gen = nextGeneration()
		if mode ~= "board" then
			showMessage(Config.text("board_loading"))
		end
		task.spawn(function()
			local ok, board = ctl:GetBoard()
			if stale(gen) then
				return
			end
			if not ok or type(board) ~= "table" then
				local list = showMessage(View.errorText(board) .. "\n" .. Config.text("board_error"))
				Kit.Button({
					text = Config.text("board_retry"),
					name = "Retry",
					layoutOrder = 2,
					onClick = function()
						loadBoard(resume)
					end,
				}).frame.Parent =
					list
				return
			end
			lastBoard = board
			if resume and type(board.active) == "table" then
				showRunner(board.active)
			else
				showBoard(board)
			end
		end)
	end

	-- live refresh while the board is showing (the board replicates; the server also pings Work.Changed)
	local pending = false
	local conn: any = nil
	if ctl and type(ctl.BoardChanged) == "table" and type(ctl.BoardChanged.Connect) == "function" then
		conn = ctl.BoardChanged:Connect(function()
			if closed or pending or mode ~= "board" then
				return
			end
			pending = true
			task.delay(REFRESH_DEBOUNCE, function()
				pending = false
				if not closed and mode == "board" then
					loadBoard(false)
				end
			end)
		end)
	end

	-- opening from a desk, the menu or WorkService:StartTask all land on the attempt in progress when there is one
	loadBoard(true)

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

return Work
