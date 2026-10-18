--!strict
-- "spot" renderer (owned by `work`; contracts §8): the table with tappable cells. Tap a cell to flag it, tap again
-- to clear; at most payload.maxPicks flags. Wide tables scroll sideways. Answers { {row, col}, ... }.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"):WaitForChild("Tasks"))
local C = require(script.Parent:WaitForChild("_Common"))

local Renderer = {}

function Renderer.mount(container: Frame, payload: { [string]: any }, api: { [string]: any }): () -> ()
	local created: { any } = {}
	local tbl = if type(payload.table) == "table" then payload.table else { columns = {}, rows = {} }
	local columns = if type(tbl.columns) == "table" then tbl.columns else {}
	local rows = if type(tbl.rows) == "table" then tbl.rows else {}
	local maxPicks = if type(payload.maxPicks) == "number" then math.max(1, math.floor(payload.maxPicks)) else 3
	local picks: { { number } } = {}
	local function find(r: number, c: number): number?
		for i, p in picks do
			if p[1] == r and p[2] == c then
				return i
			end
		end
		return nil
	end
	local counter = C.text(container, "", { size = "sm", color = "textDim", order = 1, name = "Counter" })
	table.insert(created, counter.frame)
	local function updateCounter()
		counter.setText(Config.text("spot_counter", { n = #picks, max = maxPicks }))
		counter.setColor(if #picks >= maxPicks then "warn" else "textDim")
	end
	local grid: C.Grid
	grid = C.grid(container, columns, rows, {
		order = 2,
		name = "SpotTable",
		onCell = function(r: number, c: number)
			local i = find(r, c)
			if i then
				table.remove(picks, i)
				grid.setMarked(r, c, false)
			elseif #picks < maxPicks then
				table.insert(picks, { r, c })
				grid.setMarked(r, c, true)
			end
			updateCounter()
			api.onChange(C.copy(picks))
		end,
	})
	table.insert(created, grid.frame)
	if type(api.answers) == "table" then
		for _, p in api.answers do
			if type(p) == "table" and type(p[1]) == "number" and type(p[2]) == "number" and #picks < maxPicks then
				if not find(p[1], p[2]) and rows[p[1]] ~= nil and p[2] >= 1 and p[2] <= #columns then
					table.insert(picks, { p[1], p[2] })
					grid.setMarked(p[1], p[2], true)
				end
			end
		end
	end
	updateCounter()
	return function()
		C.cleanup(created)
	end
end

return Renderer
