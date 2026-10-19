--!strict
-- Dialogue (owned by `tutorial`): conversation trees, PURE (no services, no clocks, no Instances). DialogueService
-- runs them server-side: it builds a Ctx from the player's data, shows Dialogue.view, validates every choice with
-- Dialogue.choose against the node the player is actually on, then performs the returned actions.
--
--   Dialogue.start(tree, ctx) -> nodeId              the first `start` entry whose condition holds
--   Dialogue.view(tree, nodeId, ctx) -> View?        the text (variant picked by ctx.seed, {vars} filled) and the
--                                                    options whose conditions hold
--   Dialogue.choose(tree, nodeId, optionId, ctx) -> (ok, Step | errKey)
--       Step = { option, next = nodeId?, exit, actions }   actions = the option's, then the next node's on-enter ones
--       errKey: "bad_node" | "bad_option" | "hidden"
--   Dialogue.check(cond, ctx) -> boolean             the condition language (below)
--   Dialogue.fill(text, vars) -> string              {placeholders}; unknown ones become ""
--   Dialogue.optionId(option, index) -> string       option.id, else "o<index>"
--   Dialogue.validate(tree) -> { string }            problems (empty = well formed): targets exist, every node keeps
--                                                    an unconditional option, every reachable node can still reach
--                                                    an exit, no orphan nodes, known actions/conditions/placeholders
--
-- Tree = { id, start = nodeId | { { node, cond? } }, nodes = { [nodeId] = Node } }
-- Node = { text = string | { string }, options = { Option }, actions = { Action }? (run on enter) }
-- Option = { id?, text, to? (next node), exit? (ends the talk), cond?, actions? }
-- Cond keys (all must hold): step, stepIn, done, notDone, flag, notFlag, status, band, shop,
--   booleans (built student employed fired hired club hasOffer visitor reviewDue talkedToday onboarded probation
--   firstTalk), numbers (rankAtLeast levelAtLeast reviewsAtLeast offersAtLeast networkedAtLeast),
--   stat = { [statId] = min }, all = { Cond }, any = { Cond }, ["not"] = Cond
-- Action = { kind, ... }: complete {step} | offerTask {task} | startTask {task} | open {target, args?} |
--   flag {flag} | statXp {stats, quality, key} | network {key} | joinClub | connection {companyId?, amount} |
--   notify {text, style?} | info {id} | reputation {amount, key}

local Hash = require(script.Parent.Parent.Util.Hash)

export type Cond = { [string]: any }
export type Action = { [string]: any }
export type Option = {
	id: string?,
	text: string,
	to: string?,
	exit: boolean?,
	cond: Cond?,
	actions: { Action }?,
}
export type Node = { text: string | { string }, options: { Option }, actions: { Action }? }
export type StartEntry = { node: string, cond: Cond? }
export type Tree = { id: string, start: string | { StartEntry }, nodes: { [string]: Node } }
export type Ctx = { [string]: any }
export type OptionView = { id: string, text: string, exit: boolean }
export type View = { node: string, text: string, options: { OptionView } }
export type Step = { option: Option, next: string?, exit: boolean, actions: { Action } }

local Dialogue = {}

Dialogue.BOOL_KEYS = {
	built = true,
	student = true,
	employed = true,
	fired = true,
	hired = true,
	club = true,
	hasOffer = true,
	visitor = true,
	reviewDue = true,
	talkedToday = true,
	onboarded = true,
	probation = true,
	firstTalk = true,
} :: { [string]: boolean }

Dialogue.NUM_KEYS = {
	rankAtLeast = "rank",
	levelAtLeast = "level",
	reviewsAtLeast = "reviews",
	offersAtLeast = "offers",
	networkedAtLeast = "networked",
} :: { [string]: string }

Dialogue.STR_KEYS = { status = "status", band = "lastBand", shop = "shop" } :: { [string]: string }

-- Required fields per action kind (validate).
Dialogue.ACTIONS = {
	complete = { "step" },
	offerTask = { "task" },
	startTask = { "task" },
	open = { "target" },
	flag = { "flag" },
	statXp = { "stats", "quality", "key" },
	network = { "key" },
	joinClub = {},
	connection = { "amount" },
	notify = { "text" },
	info = { "id" },
	reputation = { "amount", "key" },
} :: { [string]: { string } }

-- Placeholders the service fills (DialogueService builds ctx.vars with all of them).
Dialogue.VARS = {
	name = true, -- the player's first name
	full = true, -- first + family name
	npc = true, -- the NPC's name
	company = true, -- the player's firm (or "your firm")
	boss = true, -- the player's boss
	school = true,
	title = true, -- the player's job title
	department = true,
	headline = true, -- the latest market headline (MarketService)
	index = true, -- the ST10 benchmark level
	level = true,
	week = true,
	apps = true, -- recruiting applications used
	max = true,
	networked = true,
	goal = true,
	place = true, -- where the NPC is (office: the company name)
} :: { [string]: boolean }

local function num(x: any, default: number): number
	if type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge then
		return x
	end
	return default
end

---------------------------------------------------------------------------------------------------
-- Conditions
---------------------------------------------------------------------------------------------------
local function setHas(set: any, key: any): boolean
	return type(set) == "table" and set[key] ~= nil and set[key] ~= false
end

function Dialogue.check(cond: Cond?, ctx: Ctx): boolean
	if cond == nil then
		return true
	end
	if type(cond) ~= "table" then
		return false
	end
	for key, want in cond do
		if key == "all" then
			if type(want) ~= "table" then
				return false
			end
			for _, c in want do
				if not Dialogue.check(c, ctx) then
					return false
				end
			end
		elseif key == "any" then
			if type(want) ~= "table" then
				return false
			end
			local hit = false
			for _, c in want do
				if Dialogue.check(c, ctx) then
					hit = true
					break
				end
			end
			if not hit then
				return false
			end
		elseif key == "not" then
			if Dialogue.check(want, ctx) then
				return false
			end
		elseif key == "step" then
			if ctx.step ~= want then
				return false
			end
		elseif key == "stepIn" then
			if type(want) ~= "table" or table.find(want, ctx.step) == nil then
				return false
			end
		elseif key == "done" then
			if not setHas(ctx.done, want) then
				return false
			end
		elseif key == "notDone" then
			if setHas(ctx.done, want) then
				return false
			end
		elseif key == "flag" then
			if not setHas(ctx.flags, want) then
				return false
			end
		elseif key == "notFlag" then
			if setHas(ctx.flags, want) then
				return false
			end
		elseif key == "stat" then
			if type(want) ~= "table" then
				return false
			end
			local stats = if type(ctx.stats) == "table" then ctx.stats else {}
			for statId, min in want do
				if num(stats[statId], 0) < num(min, 0) then
					return false
				end
			end
		elseif Dialogue.BOOL_KEYS[key] then
			if (ctx[key] == true) ~= (want == true) then
				return false
			end
		elseif Dialogue.NUM_KEYS[key] then
			if num(ctx[Dialogue.NUM_KEYS[key]], 0) < num(want, math.huge) then
				return false
			end
		elseif Dialogue.STR_KEYS[key] then
			if ctx[Dialogue.STR_KEYS[key]] ~= want then
				return false
			end
		else
			return false -- unknown keys fail closed (validate reports them)
		end
	end
	return true
end

local function knownCond(cond: any, problems: { string }, where: string)
	if type(cond) ~= "table" then
		table.insert(problems, where .. ": condition is not a table")
		return
	end
	for key, want in cond do
		if key == "all" or key == "any" then
			if type(want) ~= "table" or #want == 0 then
				table.insert(problems, where .. ": " .. key .. " needs a list")
			else
				for _, c in want do
					knownCond(c, problems, where)
				end
			end
		elseif key == "not" then
			knownCond(want, problems, where)
		elseif key == "stat" then
			if type(want) ~= "table" then
				table.insert(problems, where .. ": stat needs { statId = min }")
			end
		elseif
			not (
				key == "step"
				or key == "stepIn"
				or key == "done"
				or key == "notDone"
				or key == "flag"
				or key == "notFlag"
				or Dialogue.BOOL_KEYS[key]
				or Dialogue.NUM_KEYS[key]
				or Dialogue.STR_KEYS[key]
			)
		then
			table.insert(problems, where .. ": unknown condition " .. tostring(key))
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Text
---------------------------------------------------------------------------------------------------
function Dialogue.fill(text: string, vars: { [string]: any }?): string
	local v = vars or {}
	return (string.gsub(text, "{([%w_]+)}", function(k: string): string
		local x = v[k]
		if x == nil then
			return ""
		end
		return tostring(x)
	end))
end

local function pickText(text: string | { string }, ctx: Ctx, nodeId: string): string
	if type(text) == "string" then
		return text
	end
	if type(text) == "table" and #text > 0 then
		local i = (Hash.u32(tostring(ctx.seed or ""), nodeId) % #text) + 1
		return text[i]
	end
	return ""
end

function Dialogue.optionId(option: Option, index: number): string
	if type(option.id) == "string" and option.id ~= "" then
		return option.id
	end
	return "o" .. index
end

---------------------------------------------------------------------------------------------------
-- Running a tree
---------------------------------------------------------------------------------------------------
function Dialogue.start(tree: Tree, ctx: Ctx): string?
	local s = tree.start
	if type(s) == "string" then
		return if tree.nodes[s] then s else nil
	end
	if type(s) == "table" then
		for _, entry in s do
			if type(entry) == "table" and tree.nodes[entry.node] and Dialogue.check(entry.cond, ctx) then
				return entry.node
			end
		end
	end
	return nil
end

function Dialogue.view(tree: Tree, nodeId: string, ctx: Ctx): View?
	local node = tree.nodes[nodeId]
	if not node then
		return nil
	end
	local vars = if type(ctx.vars) == "table" then ctx.vars else {}
	local options: { OptionView } = {}
	for i, opt in node.options do
		if Dialogue.check(opt.cond, ctx) then
			table.insert(options, {
				id = Dialogue.optionId(opt, i),
				text = Dialogue.fill(opt.text, vars),
				exit = opt.exit == true or opt.to == nil,
			})
		end
	end
	return { node = nodeId, text = Dialogue.fill(pickText(node.text, ctx, nodeId), vars), options = options }
end

function Dialogue.enterActions(tree: Tree, nodeId: string?): { Action }
	local node = if nodeId then tree.nodes[nodeId] else nil
	local out: { Action } = {}
	if node and node.actions then
		for _, a in node.actions do
			table.insert(out, a)
		end
	end
	return out
end

function Dialogue.choose(tree: Tree, nodeId: string, optionId: string, ctx: Ctx): (boolean, any)
	local node = tree.nodes[nodeId]
	if not node then
		return false, "bad_node"
	end
	for i, opt in node.options do
		if Dialogue.optionId(opt, i) == optionId then
			if not Dialogue.check(opt.cond, ctx) then
				return false, "hidden"
			end
			local nextId = if opt.exit == true then nil else opt.to
			if nextId ~= nil and tree.nodes[nextId] == nil then
				nextId = nil
			end
			local actions: { Action } = {}
			local own: { Action } = opt.actions or {}
			for _, a in own do
				table.insert(actions, a)
			end
			for _, a in Dialogue.enterActions(tree, nextId) do
				table.insert(actions, a)
			end
			local step: Step = { option = opt, next = nextId, exit = nextId == nil, actions = actions }
			return true, step
		end
	end
	return false, "bad_option"
end

---------------------------------------------------------------------------------------------------
-- Validation (tests and a load-time check in DialogueService)
---------------------------------------------------------------------------------------------------
local function checkText(text: string, problems: { string }, where: string)
	if text == "" then
		table.insert(problems, where .. ": empty text")
	end
	for k in string.gmatch(text, "{([%w_]+)}") do
		if not Dialogue.VARS[k] then
			table.insert(problems, where .. ": unknown placeholder {" .. k .. "}")
		end
	end
end

local function checkActions(actions: any, problems: { string }, where: string)
	if actions == nil then
		return
	end
	if type(actions) ~= "table" then
		table.insert(problems, where .. ": actions must be a list")
		return
	end
	for _, a in actions do
		local need = if type(a) == "table" then Dialogue.ACTIONS[a.kind] else nil
		if not need then
			table.insert(problems, where .. ": unknown action " .. tostring(if type(a) == "table" then a.kind else a))
		else
			for _, field in need do
				if a[field] == nil then
					table.insert(problems, ("%s: action %s needs %s"):format(where, a.kind, field))
				end
			end
		end
	end
end

function Dialogue.validate(tree: any): { string }
	local problems: { string } = {}
	if type(tree) ~= "table" or type(tree.nodes) ~= "table" then
		return { "tree has no nodes" }
	end
	local id = tostring(tree.id)
	local nodes = tree.nodes :: { [string]: Node }

	-- starts
	local starts: { string } = {}
	if type(tree.start) == "string" then
		table.insert(starts, tree.start)
	elseif type(tree.start) == "table" and #tree.start > 0 then
		for i, entry in tree.start do
			if type(entry) ~= "table" or type(entry.node) ~= "string" then
				table.insert(problems, ("%s: start entry %d is malformed"):format(id, i))
			else
				table.insert(starts, entry.node)
				if entry.cond ~= nil then
					knownCond(entry.cond, problems, id .. " start " .. i)
				end
			end
		end
		local last = tree.start[#tree.start]
		if type(last) == "table" and last.cond ~= nil then
			table.insert(problems, id .. ": the last start entry must be unconditional")
		end
	else
		table.insert(problems, id .. ": missing start")
	end
	for _, s in starts do
		if nodes[s] == nil then
			table.insert(problems, ("%s: start node %s does not exist"):format(id, s))
		end
	end

	-- nodes and options
	local edges: { [string]: { string } } = {}
	local exits: { [string]: boolean } = {}
	for nodeId, node in nodes do
		local where = id .. "." .. nodeId
		edges[nodeId] = {}
		if type(node.text) == "table" then
			if #node.text == 0 then
				table.insert(problems, where .. ": empty text list")
			end
			for _, t in node.text :: { string } do
				checkText(t, problems, where)
			end
		elseif type(node.text) == "string" then
			checkText(node.text, problems, where)
		else
			table.insert(problems, where .. ": missing text")
		end
		checkActions(node.actions, problems, where)
		if type(node.options) ~= "table" or #node.options == 0 then
			table.insert(problems, where .. ": no options (every node needs a way on or out)")
			continue
		end
		local seen: { [string]: boolean } = {}
		local unconditional = false
		for i, opt in node.options do
			local ow = where .. " option " .. i
			local oid = Dialogue.optionId(opt, i)
			if seen[oid] then
				table.insert(problems, ow .. ": duplicate option id " .. oid)
			end
			seen[oid] = true
			if type(opt.text) ~= "string" then
				table.insert(problems, ow .. ": missing text")
			else
				checkText(opt.text, problems, ow)
			end
			if opt.cond == nil then
				unconditional = true
			else
				knownCond(opt.cond, problems, ow)
			end
			checkActions(opt.actions, problems, ow)
			if opt.exit == true or opt.to == nil then
				exits[nodeId] = true
				if opt.to ~= nil then
					table.insert(problems, ow .. ": has both exit and a target")
				end
			else
				if nodes[opt.to :: string] == nil then
					table.insert(problems, ("%s: target %s does not exist"):format(ow, tostring(opt.to)))
				else
					table.insert(edges[nodeId], opt.to :: string)
				end
			end
		end
		if not unconditional then
			table.insert(problems, where .. ": every option is conditional (the player could be stuck)")
		end
	end

	-- reachability: everything reachable from a start, and an exit reachable from everything
	local reach: { [string]: boolean } = {}
	local queue: { string } = {}
	for _, s in starts do
		if nodes[s] and not reach[s] then
			reach[s] = true
			table.insert(queue, s)
		end
	end
	local head = 1
	while head <= #queue do
		local n = queue[head]
		head += 1
		local out: { string } = edges[n] or {}
		for _, to in out do
			if not reach[to] then
				reach[to] = true
				table.insert(queue, to)
			end
		end
	end
	local canExit: { [string]: boolean } = {}
	for n in exits do
		canExit[n] = true
	end
	local changed = true
	while changed do
		changed = false
		for n, list in edges do
			if not canExit[n] then
				for _, to in list do
					if canExit[to] then
						canExit[n] = true
						changed = true
						break
					end
				end
			end
		end
	end
	for nodeId in nodes do
		if not reach[nodeId] then
			table.insert(problems, ("%s.%s: unreachable node"):format(id, nodeId))
		elseif not canExit[nodeId] then
			table.insert(problems, ("%s.%s: no way out of the conversation from here"):format(id, nodeId))
		end
	end
	table.sort(problems)
	return problems
end

return Dialogue
