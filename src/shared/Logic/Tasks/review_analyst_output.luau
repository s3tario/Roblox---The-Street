--!strict
-- review_analyst_output (owned by `work`; contracts §8): checking an analyst's comps sheet before it goes to the VP.
-- Kind "spot": a peer table (price, shares, equity value, net debt, EV, EBITDA, EV/EBITDA) with two to four
-- planted mistakes: equity value that isn't price × shares, net debt subtracted instead of added, a multiple that
-- doesn't divide out, EBITDA pasted in thousands, or a bank slipped into an industrial peer set.

local Rng = require(script.Parent.Parent.Parent.Util.Rng)
local Common = require(script.Parent._shared.Common)
local Build = require(script.Parent._shared.Build)
local Grade = require(script.Parent._shared.Grade)
local Universe = require(script.Parent._shared.Universe)

local Task = {
	id = "review_analyst_output",
	title = "Review the Analyst's Comps",
	desc = "Your analyst's comps sheet is due to the VP. Catch the mistakes before they do.",
	kind = "spot",
	tracks = { "ib" },
	ranks = { 2, 3 },
	category = "work",
	core = true,
	stats = { "skill", "discipline" },
	clientFacing = false,
	timeLimit = 210,
	baseXp = 70,
	basePay = 480,
	cooldown = 240,
}

local COLUMNS = {
	"Company",
	"Price ($)",
	"Shares (M)",
	"Equity value ($M)",
	"Net debt ($M)",
	"EV ($M)",
	"EBITDA ($M)",
	"EV/EBITDA",
}

local BANK_SUFFIXES = { "Bank", "Bancorp", "Savings & Loan", "Trust" }

function Task.generate(rng: Rng.Rng, raw: any): ({ [string]: any }, { [string]: any })
	local ctx = Common.ctx(raw)
	local tier = Common.tier(ctx)
	local sectorId = rng:pick({ "industrials", "consumer", "tech", "healthcare", "logistics", "media" })
	local sector = Universe.sector(sectorId)
	local n = if tier >= 3 then 6 else 5
	local names = Universe.peers(rng, sectorId, n)
	local grid: { { string } } = {}
	type Peer = { price: number, shares: number, equity: number, netDebt: number, ev: number, ebitda: number }
	local peers: { Peer } = {}
	for _, name in names do
		local price = math.floor(rng:range(15, 140) * 100 + 0.5) / 100
		local shares = rng:int(40, 600)
		local equity = math.floor(price * shares + 0.5)
		local netDebt = math.floor(equity * rng:range(0.05, 0.5) + 0.5)
		local ev = equity + netDebt
		local ebitda = math.floor(ev / rng:range(sector.evEbitda[1], sector.evEbitda[2]) + 0.5)
		table.insert(
			peers,
			{ price = price, shares = shares, equity = equity, netDebt = netDebt, ev = ev, ebitda = ebitda }
		)
		table.insert(grid, {
			name,
			string.format("%.2f", price),
			Common.commas(shares),
			Common.commas(equity),
			Common.commas(netDebt),
			Common.commas(ev),
			Common.commas(ebitda),
			string.format("%.1fx", ev / ebitda),
		})
	end
	local errorCount = 1 + tier -- 2 / 3 / 4
	local kinds = rng:shuffle({ "equity", "ev_sign", "multiple", "units", "wrong_peer" })
	local rowsPicked: { number } = {}
	for i = 1, n do
		rowsPicked[i] = i
	end
	rowsPicked = rng:shuffle(rowsPicked)
	local groups: { Build.SpotGroup } = {}
	local hintLines: { string } = {}
	for i = 1, errorCount do
		local kind = kinds[i]
		local ri = rowsPicked[i]
		local p = peers[ri]
		local row = grid[ri]
		if kind == "equity" then
			local wrong = math.floor(p.equity * rng:pick({ 0.9, 1.1, 1.2, 0.8 }) + 0.5)
			row[4] = Common.commas(wrong)
			table.insert(groups, {
				cells = { { ri, 4 } },
				note = Common.fill("{name}: equity value is {px} × {sh}M = ${eq}M.", {
					name = row[1],
					px = row[2],
					sh = row[3],
					eq = Common.commas(p.equity),
				}),
			})
			table.insert(hintLines, "Equity value = share price × shares outstanding: check a few rows.")
		elseif kind == "ev_sign" then
			local wrongEv = p.equity - p.netDebt
			row[6] = Common.commas(wrongEv)
			row[8] = string.format("%.1fx", wrongEv / p.ebitda)
			table.insert(groups, {
				cells = { { ri, 6 }, { ri, 8 } },
				note = Common.fill("{name}: net debt was subtracted. EV = equity + net debt = ${ev}M.", {
					name = row[1],
					ev = Common.commas(p.ev),
				}),
			})
			table.insert(hintLines, "EV = equity value + net debt, never minus.")
		elseif kind == "multiple" then
			local right = p.ev / p.ebitda
			row[8] = string.format("%.1fx", right + rng:pick({ -2.5, -1.8, 1.9, 2.6 }))
			table.insert(groups, {
				cells = { { ri, 8 } },
				note = Common.fill("{name}: {ev} ÷ {e} = {m}x.", {
					name = row[1],
					ev = Common.commas(p.ev),
					e = Common.commas(p.ebitda),
					m = string.format("%.1f", right),
				}),
			})
			table.insert(hintLines, "Divide EV by EBITDA on any row that looks out of line.")
		elseif kind == "units" then
			row[7] = Common.commas(p.ebitda * 1000)
			table.insert(groups, {
				cells = { { ri, 7 } },
				note = Common.fill("{name}: EBITDA was pasted in thousands.", { name = row[1] }),
			})
			table.insert(hintLines, "One column has a figure 1,000x its neighbours.")
		else
			local bankName = Universe.first(rng) .. " " .. rng:pick(BANK_SUFFIXES)
			row[1] = bankName
			table.insert(groups, {
				cells = { { ri, 1 } },
				note = Common.fill(
					"{name} is a bank, not a {sector} peer, and EV/EBITDA doesn't work for banks.",
					{ name = bankName, sector = string.lower(sector.name) }
				),
			})
			table.insert(hintLines, "Every company in the set should be a real peer in the same sector.")
		end
	end
	local tbl, secret = Build.spotTable(COLUMNS, grid, groups, errorCount + 2)
	secret.summary = {
		great = "Every mistake caught. You walk the analyst through the fixes, and the VP signs off.",
		bad = "The VP finds the mistakes you missed. Check the maths on each column, row by row.",
	}
	return {
		kind = "spot",
		title = Task.title,
		prompt = Common.fill(
			"{sector} comps from your analyst. Tap every wrong cell (up to {n} flags). False flags cost points.",
			{ sector = sector.name, n = errorCount + 2 }
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
