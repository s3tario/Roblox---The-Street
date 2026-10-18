--!strict
-- "format" renderer (owned by `work`; contracts §8): the document's lines in order. Tap a line to open its issue
-- tags, tap a tag to flag or clear it; a flagged line shows its count. Clean lines are simply left alone.
-- Answers { [elementId] = { issueId, ... } } (lines without flags are omitted).

local Kit = require(script.Parent.Parent:WaitForChild("Kit"))
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"):WaitForChild("Tasks"))
local C = require(script.Parent:WaitForChild("_Common"))

local Renderer = {}

function Renderer.mount(container: Frame, payload: { [string]: any }, api: { [string]: any }): () -> ()
	local created: { any } = {}
	local issues = if type(payload.issues) == "table" then payload.issues else {}
	local validIssue: { [string]: boolean } = {}
	for _, issue in issues do
		if type(issue) == "table" and type(issue.id) == "string" then
			validIssue[issue.id] = true
		end
	end
	local flags: { [string]: { [string]: boolean } } = {}
	if type(api.answers) == "table" then
		for elemId, list in api.answers do
			if type(elemId) == "string" and type(list) == "table" then
				local set: { [string]: boolean } = {}
				for _, issueId in list do
					if type(issueId) == "string" and validIssue[issueId] then
						set[issueId] = true
					end
				end
				flags[elemId] = set
			end
		end
	end
	local function snapshot(): { [string]: { string } }
		local out: { [string]: { string } } = {}
		for elemId, set in flags do
			local list: { string } = {}
			for _, issue in issues do
				if set[issue.id] then
					table.insert(list, issue.id)
				end
			end
			if #list > 0 then
				out[elemId] = list
			end
		end
		return out
	end
	local nextOrder = C.order()
	for ei, el in payload.elements or {} do
		local elemId = el.id
		local card = C.panel(container, nextOrder(), "Line" .. ei)
		table.insert(created, card)
		local function count(): number
			local n = 0
			local set = flags[elemId]
			if set then
				for _ in set do
					n += 1
				end
			end
			return n
		end
		local function lineText(): string
			local tag = if type(el.kind) == "string" and el.kind ~= "" then "[" .. el.kind .. "]  " else ""
			local n = count()
			local suffix = if n > 0 then "   " .. Config.text("format_flags", { n = n }) else ""
			return tag .. tostring(el.text) .. suffix
		end
		local tags = Kit.List({ direction = "horizontal", wraps = true, gap = 6, layoutOrder = 2, name = "Issues" })
		tags.frame.Size = UDim2.new(1, 0, 0, 0)
		tags.frame.AutomaticSize = Enum.AutomaticSize.Y
		tags.frame.Visible = count() > 0
		local line: C.Choice
		line = C.choice(card, {
			text = lineText(),
			order = 1,
			name = "LineButton",
			selected = count() > 0,
			onClick = function()
				tags.frame.Visible = not tags.frame.Visible
			end,
		})
		tags.frame.Parent = card
		for ii, issue in issues do
			local issueId = issue.id
			local chip: C.Choice
			chip = C.chip(tags.frame, {
				text = tostring(issue.text),
				order = ii,
				name = "Issue_" .. tostring(issueId),
				selected = flags[elemId] ~= nil and flags[elemId][issueId] == true,
				onClick = function()
					local set = flags[elemId]
					if not set then
						set = {}
						flags[elemId] = set
					end
					if set[issueId] then
						set[issueId] = nil
					else
						set[issueId] = true
					end
					chip.setSelected(set[issueId] == true)
					line.setText(lineText())
					line.setSelected(count() > 0)
					api.onChange(snapshot())
				end,
			})
		end
	end
	return function()
		C.cleanup(created)
	end
end

return Renderer
