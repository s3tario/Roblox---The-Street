--!strict
-- Career (client screen, owned by `careerPath`): the MyCareer hub. Title and company logo, level and XP, this
-- week, the promotion checklist, career stats, review history chart, the timeline and the ladder.
-- Opened from the "Career" menu tab (quick button). Reads the replicated career; refreshes while open.
--   args = { tab = "overview" | "reviews" | "timeline" | "ladder" }?

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Kit = require(script.Parent.Parent:WaitForChild("Kit"))
local Parts = script.Parent:WaitForChild("CareerParts")
local Common = require(Parts:WaitForChild("Common"))
local Overview = require(Parts:WaitForChild("Overview"))
local History = require(Parts:WaitForChild("History"))
local Ladder = require(Parts:WaitForChild("Ladder"))
local Tracks = require(Shared.Config.Tracks)

local Career = { id = "Career" }

local TABS = { "overview", "reviews", "timeline", "ladder" }
local REFRESH_DEBOUNCE = 0.3

function Career.open(args: any, root: Instance, ctx: any): { close: () -> () }
	local a = if type(args) == "table" then args else {}
	local selected = if type(a.tab) == "string" and table.find(TABS, a.tab) then a.tab else "overview"
	local closed = false
	local conns: { any } = {}

	local career = Common.careerOrEmpty(ctx)
	local win = Kit.Window({
		title = Tracks.text("career_title"),
		subtitle = career.weekLabel,
		size = UDim2.fromScale(1, 1),
		maxSize = Vector2.new(720, 720),
		onClose = ctx.close,
		name = "CareerWindow",
	})
	win.frame.Parent = root

	local scroll: any = nil
	local render: () -> ()
	local tabs = Kit.Tabs({
		tabs = {
			{ id = "overview", title = Tracks.text("tab_overview") },
			{ id = "reviews", title = Tracks.text("tab_reviews") },
			{ id = "timeline", title = Tracks.text("tab_timeline") },
			{ id = "ladder", title = Tracks.text("tab_ladder") },
		},
		selected = selected,
		onSelect = function(id: string)
			if id ~= selected then
				selected = id
				if scroll then
					scroll.frame.CanvasPosition = Vector2.zero
				end
				render()
			end
		end,
		name = "Tabs",
	})
	tabs.frame.Parent = win.content

	local body = Kit.frame("Body", UDim2.new(1, 0, 1, -56))
	body.Position = UDim2.fromOffset(0, 56)
	body.Parent = win.content
	local list = Kit.Scroll({ padding = 2, gap = 10, name = "Scroll" })
	list.frame.Parent = body
	scroll = list

	render = function()
		if closed then
			return
		end
		local scroll = list
		local c = Common.careerOrEmpty(ctx)
		local keep = scroll.frame.CanvasPosition
		scroll.clear()
		win.setSubtitle(if type(c.weekLabel) == "string" then c.weekLabel else nil)
		Common.safe(function()
			if selected == "reviews" then
				History.reviews(scroll, c)
			elseif selected == "timeline" then
				History.timeline(scroll, c)
			elseif selected == "ladder" then
				Ladder.build(scroll, c)
			else
				Overview.build(scroll, c, ctx)
			end
		end)
		task.defer(function()
			if not closed and scroll.frame.Parent then
				scroll.frame.CanvasPosition = keep
			end
		end)
	end

	local pending = false
	local function schedule()
		if pending or closed then
			return
		end
		pending = true
		task.delay(REFRESH_DEBOUNCE, function()
			pending = false
			render()
		end)
	end

	render()

	local store = ctx.Store
	if store then
		local ok, conn = pcall(function()
			return store:Changed("career"):Connect(schedule)
		end)
		if ok and conn then
			table.insert(conns, conn)
		end
	end

	return {
		close = function()
			closed = true
			for _, c in conns do
				pcall(function()
					c:Disconnect()
				end)
			end
			win.close()
		end,
	}
end

return Career
