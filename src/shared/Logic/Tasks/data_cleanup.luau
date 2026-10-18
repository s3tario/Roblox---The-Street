--!strict
-- data_cleanup (owned by `work`; contracts §8): scrubbing a client's quarterly numbers before they go in the model.
-- Kind "spot": a quarterly table (revenue, COGS, gross profit, margin) with two to four planted errors: a gross
-- profit that doesn't tie, a wrong margin, a figure in thousands among millions, a duplicated quarter, a flipped
-- sign or an out-of-sequence label. False flags cost points (less with higher Skill).

local Rng = require(script.Parent.Parent.Parent.Util.Rng)
local Common = require(script.Parent._shared.Common)
local Build = require(script.Parent._shared.Build)
local Grade = require(script.Parent._shared.Grade)
local Universe = require(script.Parent._shared.Universe)

local Task = {
	id = "data_cleanup",
	title = "Data Clean-up",
	desc = "The client's data dump is messy. Find the bad cells before they break the model.",
	kind = "spot",
	tracks = { "ib" },
	ranks = { 1 },
	category = "work",
	core = false,
	stats = { "skill", "discipline" },
	clientFacing = false,
	timeLimit = 180,
	baseXp = 50,
	basePay = 380,
	cooldown = 240,
}

local COLUMNS = { "Quarter", "Revenue ($M)", "COGS ($M)", "Gross profit ($M)", "Gross margin" }

type Row = { q: number, y: number, rev: number, cogs: number }

local function label(q: number, y: number): string
	return "Q" .. tostring(q) .. " " .. tostring(y)
end

local function cells(r: Row): { string }
	local gp = r.rev - r.cogs
	return {
		label(r.q, r.y),
		Common.commas(r.rev),
		Common.commas(r.cogs),
		Common.commas(gp),
		string.format("%.1f%%", gp / r.rev * 100),
	}
end

function Task.generate(rng: Rng.Rng, raw: any): ({ [string]: any }, { [string]: any })
	local ctx = Common.ctx(raw)
	local tier = Common.tier(ctx)
	local company = Universe.company(rng)
	local n = 5 + tier -- 6 / 7 / 8 quarters
	local base = rng:int(60, 400) * 2
	local margin = rng:range(0.28, 0.55)
	local year = Common.year(ctx) - 2
	local q = rng:int(1, 4)
	local rows: { Row } = {}
	for i = 1, n do
		local rev = math.floor(base * (1 + 0.025 * (i - 1)) * rng:range(0.96, 1.04) + 0.5)
		local cogs = math.floor(rev * (1 - margin + rng:range(-0.02, 0.02)) + 0.5)
		table.insert(rows, { q = q, y = year, rev = rev, cogs = cogs })
		q += 1
		if q > 4 then
			q = 1
			year += 1
		end
	end
	local grid: { { string } } = {}
	for _, r in rows do
		table.insert(grid, cells(r))
	end

	local errorCount = 1 + tier -- 2 / 3 / 4
	local kinds = rng:shuffle({ "gp", "margin", "units", "duplicate", "sign", "label" })
	-- each error sits on its own row (from row 2). A duplicated quarter copies the row above it, so neither that row
	-- nor the copy may carry another error; when no such slot is left, the duplicate swaps for a label error.
	local rowPool: { number } = {}
	for i = 2, n do
		table.insert(rowPool, i)
	end
	local plain: { string } = {}
	local wantDuplicate = false
	for i = 1, errorCount do
		if kinds[i] == "duplicate" then
			wantDuplicate = true
		else
			table.insert(plain, kinds[i])
		end
	end
	local errorRows = Common.pickN(rng, rowPool, #plain)
	local used: { [number]: boolean } = {}
	for _, ri in errorRows do
		used[ri] = true
	end
	local plan: { { kind: string, row: number } } = {}
	for i, kind in plain do
		table.insert(plan, { kind = kind, row = errorRows[i] })
	end
	if wantDuplicate then
		local slots: { number } = {}
		for ri = 2, n do
			if not used[ri] and not used[ri - 1] then
				table.insert(slots, ri)
			end
		end
		if #slots > 0 then
			table.insert(plan, { kind = "duplicate", row = rng:pick(slots) })
		else
			local free: { number } = {}
			for ri = 2, n do
				if not used[ri] then
					table.insert(free, ri)
				end
			end
			table.insert(plan, { kind = if table.find(plain, "label") then "sign" else "label", row = rng:pick(free) })
		end
	end
	local groups: { Build.SpotGroup } = {}
	local hintLines: { string } = {}
	for _, step in plan do
		local kind = step.kind
		local ri = step.row
		local r = rows[ri]
		local row = grid[ri]
		if kind == "gp" then
			local wrong = (r.rev - r.cogs) + rng:pick({ -40, -25, 30, 45 })
			row[4] = Common.commas(wrong)
			table.insert(groups, {
				cells = { { ri, 4 } },
				note = Common.fill("{q}: gross profit should be {rev} − {cogs} = {gp}.", {
					q = row[1],
					rev = Common.commas(r.rev),
					cogs = Common.commas(r.cogs),
					gp = Common.commas(r.rev - r.cogs),
				}),
			})
			table.insert(hintLines, "Gross profit must equal revenue minus COGS on every row.")
		elseif kind == "margin" then
			local right = (r.rev - r.cogs) / r.rev * 100
			row[5] = string.format("%.1f%%", right + rng:pick({ -8, -6, 6, 9 }))
			table.insert(groups, {
				cells = { { ri, 5 } },
				note = Common.fill("{q}: the margin is {gp} ÷ {rev} = {m}%.", {
					q = row[1],
					gp = Common.commas(r.rev - r.cogs),
					rev = Common.commas(r.rev),
					m = string.format("%.1f", right),
				}),
			})
			table.insert(hintLines, "Recompute a margin or two: gross profit ÷ revenue.")
		elseif kind == "units" then
			row[2] = Common.commas(r.rev * 1000)
			table.insert(groups, {
				cells = { { ri, 2 } },
				note = Common.fill("{q}: revenue is in thousands, 1,000x the other rows.", { q = row[1] }),
			})
			table.insert(hintLines, "Watch for a number about 1,000x bigger than its neighbours.")
		elseif kind == "duplicate" then
			local prev = grid[ri - 1]
			for c = 1, #prev do
				row[c] = prev[c]
			end
			local cellsList: { { number } } = {}
			for c = 1, #COLUMNS do
				table.insert(cellsList, { ri, c })
				table.insert(cellsList, { ri - 1, c })
			end
			table.insert(groups, {
				cells = cellsList,
				note = Common.fill("{q} appears twice: one quarter was pasted over the next.", { q = prev[1] }),
			})
			table.insert(hintLines, "Look for a quarter that appears twice.")
		elseif kind == "sign" then
			row[3] = "-" .. Common.commas(r.cogs)
			table.insert(groups, {
				cells = { { ri, 3 } },
				note = Common.fill(
					"{q}: COGS flipped sign. Every other row shows it as a positive cost.",
					{ q = row[1] }
				),
			})
			table.insert(hintLines, "Costs use one sign convention down the whole column.")
		else
			local wrongQ = if r.q == 4 then 2 else r.q + 2
			row[1] = label(wrongQ, r.y)
			table.insert(groups, {
				cells = { { ri, 1 } },
				note = Common.fill(
					"Row {i}: the quarters run in order, so this should be {q}.",
					{ i = ri, q = label(r.q, r.y) }
				),
			})
			table.insert(hintLines, "The quarters should run in order without gaps.")
		end
	end
	local tbl, secret = Build.spotTable(COLUMNS, grid, groups, errorCount + 2)
	secret.summary = {
		great = "Every bad cell caught. The model runs clean on the first try.",
		bad = "Bad data slipped through and the model's outputs are off. Check each row's maths.",
	}
	return {
		kind = "spot",
		title = Task.title,
		prompt = Common.fill(
			"{c}'s quarterly numbers. Tap each cell that's wrong (up to {n} flags). False flags cost points.",
			{ c = company.name, n = errorCount + 2 }
		),
		table = tbl,
		maxPicks = errorCount + 2,
		hints = Common.hints(ctx, hintLines),
	},
		secret
end

function Task.grade(secret: any, answers: any, raw: any): Grade.Result
	return Grade.auto(secret, answers, Common.ctx(raw))
end

return Task
