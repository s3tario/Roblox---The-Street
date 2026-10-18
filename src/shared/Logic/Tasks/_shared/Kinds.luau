--!strict
-- Payload validation for work tasks (owned by `work`; contracts §8 payload table). PURE.
-- WorkService checks every generated payload with Kinds.validate before it reaches a client, so a module bug
-- becomes a polite "couldn't set up that task" instead of a broken screen. Tests use the same checks.
--
--   Kinds.IDS                                   the ten payload kinds
--   Kinds.validate(payload) -> (ok, err?)       shape check for one payload (multi checks every section)
--   Kinds.plain(value, limit?) -> boolean       plain data only (strings, finite numbers, booleans, tables with
--                                               string/integer keys, no metatables), bounded size and depth
--   Kinds.answerTotal(payload) -> number        how many answers a complete submission has (UI progress,
--                                               WorkService's speed check)
--   Kinds.answered(payload, answers) -> number  how many of those the answers fill

local Kinds = {}

Kinds.IDS = { "mcq", "fill", "order", "match", "spot", "alloc", "dialogue", "call", "format", "multi" }
local KNOWN: { [string]: boolean } = {}
for _, k in Kinds.IDS do
	KNOWN[k] = true
end
Kinds.KNOWN = KNOWN

local MAX_NODES = 2500
local MAX_DEPTH = 9
local MAX_STRING = 2000

local function finite(x: any): boolean
	return type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge
end

local function walk(v: any, depth: number, budget: { n: number, limit: number }): boolean
	budget.n += 1
	if budget.n > budget.limit or depth > MAX_DEPTH then
		return false
	end
	local t = type(v)
	if t == "string" then
		return #v <= MAX_STRING
	elseif t == "number" then
		return finite(v)
	elseif t == "boolean" then
		return true
	elseif t == "table" then
		if getmetatable(v) ~= nil then
			return false
		end
		for k, x in v do
			local kt = type(k)
			if kt == "number" then
				if not finite(k) or k ~= math.floor(k) then
					return false
				end
			elseif kt ~= "string" then
				return false
			end
			if not walk(x, depth + 1, budget) then
				return false
			end
		end
		return true
	end
	return false
end

function Kinds.plain(value: any, limit: number?): boolean
	return walk(value, 1, { n = 0, limit = limit or MAX_NODES })
end

local function isStr(x: any): boolean
	return type(x) == "string" and x ~= ""
end

local function isList(x: any): boolean
	if type(x) ~= "table" then
		return false
	end
	local n = #x
	local count = 0
	for _ in x do
		count += 1
	end
	return count == n
end

local function listOf(x: any, min: number): boolean
	return isList(x) and #x >= min
end

-- Every entry is {id = non-empty string, [textKey] = non-empty string}; ids unique (within `seen`).
local function idTexts(list: any, min: number, textKey: string, seen: { [string]: boolean }?): (boolean, string?)
	if not listOf(list, min) then
		return false, "needs at least " .. min .. " entries"
	end
	local used = seen or {}
	for i, e in list do
		if type(e) ~= "table" or not isStr(e.id) or not isStr(e[textKey]) then
			return false, "entry " .. i .. " needs id and " .. textKey
		end
		if used[e.id] then
			return false, "duplicate id " .. e.id
		end
		used[e.id] = true
	end
	return true, nil
end

local function validTable(t: any): (boolean, string?)
	if type(t) ~= "table" then
		return false, "table missing"
	end
	if not listOf(t.columns, 1) then
		return false, "table.columns"
	end
	for _, c in t.columns do
		if type(c) ~= "string" then
			return false, "table column not a string"
		end
	end
	if not listOf(t.rows, 1) then
		return false, "table.rows"
	end
	for i, row in t.rows do
		if not listOf(row, 1) or #row > #t.columns then
			return false, "table row " .. i
		end
		for _, cell in row do
			if type(cell) ~= "string" then
				return false, "table cell not a string"
			end
		end
	end
	return true, nil
end

local CHECKS: { [string]: (p: { [string]: any }) -> (boolean, string?) } = {}

CHECKS.mcq = function(p)
	if not listOf(p.questions, 1) then
		return false, "questions"
	end
	local seen: { [string]: boolean } = {}
	for i, q in p.questions do
		if type(q) ~= "table" or not isStr(q.id) or not isStr(q.text) then
			return false, "question " .. i
		end
		if seen[q.id] then
			return false, "duplicate question id"
		end
		seen[q.id] = true
		if not listOf(q.options, 2) then
			return false, "question " .. i .. " options"
		end
		for _, o in q.options do
			if not isStr(o) then
				return false, "question " .. i .. " option text"
			end
		end
		if q.context ~= nil and type(q.context) ~= "string" then
			return false, "question context"
		end
	end
	return true, nil
end

CHECKS.fill = function(p)
	local ok, err = idTexts(p.fields, 1, "label")
	if not ok then
		return false, "fields: " .. tostring(err)
	end
	for _, f in p.fields do
		if (f.unit ~= nil and type(f.unit) ~= "string") or (f.hint ~= nil and type(f.hint) ~= "string") then
			return false, "field unit/hint"
		end
	end
	if p.table ~= nil then
		return validTable(p.table)
	end
	return true, nil
end

CHECKS.order = function(p)
	return idTexts(p.items, 2, "text")
end

CHECKS.match = function(p)
	local seen: { [string]: boolean } = {}
	local ok, err = idTexts(p.left, 1, "text", seen)
	if not ok then
		return false, "left: " .. tostring(err)
	end
	ok, err = idTexts(p.right, #p.left, "text", seen)
	if not ok then
		return false, "right: " .. tostring(err)
	end
	return true, nil
end

CHECKS.spot = function(p)
	local ok, err = validTable(p.table)
	if not ok then
		return false, err
	end
	if not finite(p.maxPicks) or p.maxPicks < 1 or p.maxPicks ~= math.floor(p.maxPicks) then
		return false, "maxPicks"
	end
	return true, nil
end

CHECKS.alloc = function(p)
	local ok, err = idTexts(p.items, 2, "text")
	if not ok then
		return false, "items: " .. tostring(err)
	end
	if not finite(p.total) or p.total <= 0 or not finite(p.step) or p.step <= 0 then
		return false, "total/step"
	end
	if (p.minEach ~= nil and not finite(p.minEach)) or (p.maxEach ~= nil and not finite(p.maxEach)) then
		return false, "minEach/maxEach"
	end
	return true, nil
end

CHECKS.dialogue = function(p)
	if not isStr(p.speaker) then
		return false, "speaker"
	end
	local ok, err = idTexts(p.lines, 1, "text")
	if not ok then
		return false, "lines: " .. tostring(err)
	end
	for i, line in p.lines do
		local okOpts, errOpts = idTexts(line.options, 2, "text")
		if not okOpts then
			return false, "line " .. i .. " options: " .. tostring(errOpts)
		end
	end
	return true, nil
end

CHECKS.call = function(p)
	local ok, err = idTexts(p.items, 1, "label")
	if not ok then
		return false, "items: " .. tostring(err)
	end
	for i, item in p.items do
		if not listOf(item.chart, 2) then
			return false, "item " .. i .. " chart"
		end
		for _, v in item.chart do
			if not finite(v) then
				return false, "item " .. i .. " chart value"
			end
		end
		local news = item.news
		if not (type(news) == "string" or listOf(news, 0)) then
			return false, "item " .. i .. " news"
		end
	end
	if not listOf(p.options, 2) then
		return false, "options"
	end
	for _, o in p.options do
		if not isStr(o) then
			return false, "option text"
		end
	end
	return true, nil
end

CHECKS.format = function(p)
	local ok, err = idTexts(p.elements, 1, "text")
	if not ok then
		return false, "elements: " .. tostring(err)
	end
	ok, err = idTexts(p.issues, 1, "text")
	if not ok then
		return false, "issues: " .. tostring(err)
	end
	return true, nil
end

local function validate(payload: any, nested: boolean): (boolean, string?)
	if type(payload) ~= "table" then
		return false, "payload is not a table"
	end
	local kind = payload.kind
	if type(kind) ~= "string" or not KNOWN[kind] then
		return false, "unknown kind " .. tostring(kind)
	end
	if not isStr(payload.title) then
		return false, kind .. ": title"
	end
	if payload.prompt ~= nil and type(payload.prompt) ~= "string" then
		return false, kind .. ": prompt"
	end
	if payload.hints ~= nil then
		if not isList(payload.hints) then
			return false, kind .. ": hints"
		end
		for _, h in payload.hints do
			if type(h) ~= "string" then
				return false, kind .. ": hint text"
			end
		end
	end
	if kind == "multi" then
		if nested then
			return false, "multi inside multi"
		end
		if not listOf(payload.sections, 1) then
			return false, "multi: sections"
		end
		for i, s in payload.sections do
			local ok, err = validate(s, true)
			if not ok then
				return false, "multi section " .. i .. ": " .. tostring(err)
			end
		end
		return true, nil
	end
	local ok, err = CHECKS[kind](payload)
	if not ok then
		return false, kind .. ": " .. tostring(err)
	end
	return true, nil
end

function Kinds.validate(payload: any): (boolean, string?)
	if not Kinds.plain(payload) then
		return false, "payload is not plain data"
	end
	return validate(payload, false)
end

function Kinds.answerTotal(payload: any): number
	if type(payload) ~= "table" then
		return 0
	end
	local kind = payload.kind
	if kind == "mcq" then
		return if type(payload.questions) == "table" then #payload.questions else 0
	elseif kind == "fill" then
		return if type(payload.fields) == "table" then #payload.fields else 0
	elseif kind == "order" then
		return 1
	elseif kind == "match" then
		return if type(payload.left) == "table" then #payload.left else 0
	elseif kind == "spot" then
		return 1
	elseif kind == "alloc" then
		return 1
	elseif kind == "dialogue" then
		return if type(payload.lines) == "table" then #payload.lines else 0
	elseif kind == "call" then
		return if type(payload.items) == "table" then #payload.items else 0
	elseif kind == "format" then
		return 1
	elseif kind == "multi" then
		local n = 0
		if type(payload.sections) == "table" then
			for _, s in payload.sections do
				n += Kinds.answerTotal(s)
			end
		end
		return n
	end
	return 0
end

local function countKeys(list: any, answers: any, key: string): number
	if type(list) ~= "table" or type(answers) ~= "table" then
		return 0
	end
	local n = 0
	for _, e in list do
		if type(e) == "table" and answers[e[key]] ~= nil then
			n += 1
		end
	end
	return n
end

function Kinds.answered(payload: any, answers: any): number
	if type(payload) ~= "table" or type(answers) ~= "table" then
		return 0
	end
	local kind = payload.kind
	if kind == "mcq" then
		return countKeys(payload.questions, answers, "id")
	elseif kind == "fill" then
		return countKeys(payload.fields, answers, "id")
	elseif kind == "match" then
		return countKeys(payload.left, answers, "id")
	elseif kind == "dialogue" then
		return countKeys(payload.lines, answers, "id")
	elseif kind == "call" then
		return countKeys(payload.items, answers, "id")
	elseif kind == "order" then
		return if #answers > 0 then 1 else 0
	elseif kind == "spot" then
		return if #answers > 0 then 1 else 0
	elseif kind == "alloc" or kind == "format" then
		return if next(answers) ~= nil then 1 else 0
	elseif kind == "multi" then
		local n = 0
		if type(payload.sections) == "table" then
			for i, s in payload.sections do
				n += Kinds.answered(s, answers[i])
			end
		end
		return n
	end
	return 0
end

return Kinds
