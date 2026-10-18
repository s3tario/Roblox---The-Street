--!strict
-- MarketService: live LED ticker bands (RUNTIME ONLY, server). Every instance tagged "TickerBand" or "TickerDisplay"
-- (Assets/Signs tickerBand faces, Props ticker_board, trading-floor walls in cloned office floors) has its TextLabels
-- named "TickerText" rewritten with live quotes every market tick. Tagged instances added later (office floors are
-- cloned at runtime) join automatically; destroyed ones drop out. Each label gets attribute TickerReps (how many
-- copies of the line it holds) so a client scroller can wrap seamlessly.
--
--   Bands.start()                      begin tracking tagged instances
--   Bands.update(line)                 write `line` (Logic/Market/Band.line) into every tracked label
--   Bands.count() -> number            tracked labels

local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Band = require(Shared.Logic.Market.Band)

local Bands = {}

Bands.TAGS = { "TickerBand", "TickerDisplay" }
Bands.LABEL = "TickerText"

type Entry = { label: TextLabel, width: number, pps: number }

local labels: { [TextLabel]: Entry } = {}
local roots: { [Instance]: { RBXScriptConnection } } = {}
local lastLine: string? = nil

local function attr(inst: Instance?, name: string): number?
	local node = inst
	for _ = 1, 4 do
		if not node then
			return nil
		end
		local v = node:GetAttribute(name)
		if type(v) == "number" and v > 0 then
			return v
		end
		node = node.Parent
	end
	return nil
end

local function track(label: Instance)
	if not label:IsA("TextLabel") or label.Name ~= Bands.LABEL or labels[label] then
		return
	end
	local face = label:FindFirstAncestorWhichIsA("BasePart")
	local width: number = attr(face, "BandWidth") or (if face then face.Size.X else 40)
	local pps: number = attr(face, "TickerPps") or 30
	labels[label] = { label = label, width = width, pps = pps }
	if not label.RichText then
		label.RichText = true -- the line carries <font color> tags
	end
	if lastLine then
		local text, reps = Band.fit(lastLine, width, pps, label.TextSize)
		label.Text = text
		label:SetAttribute("TickerReps", reps)
	end
end

local function unwatch(inst: Instance)
	local conns = roots[inst]
	if not conns then
		return
	end
	roots[inst] = nil
	for _, c in conns do
		c:Disconnect()
	end
	for label in labels do
		if label == inst or label:IsDescendantOf(inst) then
			labels[label] = nil
		end
	end
end

local function watch(inst: Instance)
	if roots[inst] then
		return
	end
	local conns: { RBXScriptConnection } = {}
	roots[inst] = conns
	table.insert(conns, inst.DescendantAdded:Connect(track))
	table.insert(
		conns,
		inst.Destroying:Connect(function()
			unwatch(inst)
		end)
	)
	track(inst)
	for _, d in inst:GetDescendants() do
		track(d)
	end
end

function Bands.start()
	for _, tag in Bands.TAGS do
		CollectionService:GetInstanceAddedSignal(tag):Connect(watch)
		CollectionService:GetInstanceRemovedSignal(tag):Connect(unwatch)
		for _, inst in CollectionService:GetTagged(tag) do
			watch(inst)
		end
	end
end

function Bands.update(line: string)
	if line == lastLine then
		return
	end
	lastLine = line
	local fits: { [string]: { text: string, reps: number } } = {}
	for label, entry in labels do
		if label.Parent == nil then
			labels[label] = nil
		else
			local key =
				string.format("%d|%d|%d", math.floor(entry.width), math.floor(entry.pps), math.floor(label.TextSize))
			local fit = fits[key]
			if not fit then
				local text, reps = Band.fit(line, entry.width, entry.pps, label.TextSize)
				fit = { text = text, reps = reps }
				fits[key] = fit
			end
			label.Text = fit.text
			if label:GetAttribute("TickerReps") ~= fit.reps then
				label:SetAttribute("TickerReps", fit.reps)
			end
		end
	end
end

function Bands.count(): number
	local n = 0
	for _ in labels do
		n += 1
	end
	return n
end

return Bands
