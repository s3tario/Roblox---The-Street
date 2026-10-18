--!strict
-- LifeRollParts/Rows: one Life Roll field row (client UI, careerCore): the field name and rarity badge, a Reel
-- with the value, what it boosts, the eight rolled attributes (stats row only) and a 44 px reroll button.
--
--   local row = Rows.new(field, { onReroll = fn, layoutOrder = n })
--   row.frame.Parent = list
--   row.set(value, animate?, duration?, onLanded?)   spins to the server's value (or shows it at once)
--   row.setButton(text, style, disabled)             reroll button state (cost text, "Get rerolls", busy)
--   row.skip() / row.isSpinning() / row.destroy()

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config.LifeRoll)
local LifeRoll = require(Shared.Logic.LifeRoll)
local Kit = require(script.Parent.Parent.Parent:WaitForChild("Kit"))
local Common = require(script.Parent.Common)
local Reel = require(script.Parent.Reel)

export type Row = {
	frame: Frame,
	field: string,
	set: (value: any, animate: boolean?, duration: number?, onLanded: (() -> ())?) -> (),
	setButton: (text: string, style: Kit.ButtonStyle, disabled: boolean) -> (),
	skip: () -> (),
	isSpinning: () -> boolean,
	destroy: () -> (),
}

local Rows = {}

local BUTTON_W = 140
local spinSeed = 0

function Rows.new(field: string, opts: { onReroll: () -> (), layoutOrder: number? }): Row
	local panel = Kit.Panel({ name = "Row_" .. field, color = "panelAlt", padding = 10 })
	panel.frame.LayoutOrder = opts.layoutOrder or 0
	local frame = panel.frame

	local left = Kit.List({ gap = 4, name = "Left" })
	left.frame.Size = UDim2.new(1, -(BUTTON_W + 10), 0, 0)
	left.frame.Parent = frame

	local titleLine = Kit.List({ direction = "horizontal", gap = 8, name = "TitleLine" })
	left.add(titleLine)
	titleLine.add(Kit.Label({ text = Common.fieldTitle(field), size = "sm", color = "textDim", autoSize = "xy" }))
	local badge = Kit.Badge({ text = "", name = "Rarity" })
	badge.frame.Visible = false
	titleLine.add(badge)

	local reel = Reel.new({ name = "Reel" })
	left.add(reel.frame)

	local boost = Kit.Label({ text = "", size = "xs", color = "accent", name = "Boost" })
	boost.frame.Visible = false
	left.add(boost)

	local grid: { frame: Frame }? = nil
	local cells: { [string]: Kit.Label } = {}
	if field == "stats" then
		local g = Kit.Grid({ columns = 4, cellHeight = 22, gap = 4, name = "StatGrid" })
		left.add(g)
		for _, def in Config.stats do
			local cell = Kit.Label({ text = def.short, size = "sm", font = "mono", name = "Cell_" .. def.id })
			g.add(cell)
			cells[def.id] = cell
		end
		g.frame.Visible = false
		grid = g
	end

	local button = Kit.Button({
		text = Config.text("reroll"),
		icon = "🎲",
		style = "secondary",
		size = UDim2.fromOffset(BUTTON_W, Kit.TAP),
		textSize = "sm",
		name = "Reroll",
		onClick = opts.onReroll,
	})
	button.frame.AnchorPoint = Vector2.new(1, 0.5)
	button.frame.Position = UDim2.new(1, 0, 0.5, 0)
	button.frame.Parent = frame

	local function reveal(value: any)
		local rarity = LifeRoll.rarityOf(field, value)
		if rarity and field ~= "degree" then
			badge.setText(Common.rarityName(rarity))
			badge.setColor(Common.rarityColor(rarity))
			badge.frame.Visible = true
		else
			badge.frame.Visible = false
		end
		local b = Common.boostText(field, value)
		boost.setText(b)
		boost.frame.Visible = b ~= ""
		if grid and type(value) == "table" then
			for _, def in Config.stats do
				local cell = cells[def.id]
				local n = tonumber(value[def.id]) or 0
				cell.setText(def.short .. " " .. tostring(math.floor(n)))
			end
			grid.frame.Visible = true
		end
	end

	local function set(value: any, animate: boolean?, duration: number?, onLanded: (() -> ())?)
		local entry = { text = Common.valueText(field, value), rarity = LifeRoll.rarityOf(field, value) }
		if not animate then
			reel.set(entry)
			reveal(value)
			if onLanded then
				onLanded()
			end
			return
		end
		badge.frame.Visible = false
		boost.frame.Visible = false
		if grid then
			grid.frame.Visible = false
		end
		local d = duration or Config.SPIN.reroll
		spinSeed += 1
		local filler = Common.reelFiller(field, math.clamp(math.floor(d * 12), 10, 70), spinSeed)
		reel.spin(entry, filler, d, function()
			reveal(value)
			if onLanded then
				onLanded()
			end
		end)
	end

	return {
		frame = frame,
		field = field,
		set = set,
		setButton = function(text: string, style: Kit.ButtonStyle, disabled: boolean)
			button.setText(text)
			button.setStyle(style)
			button.setDisabled(disabled)
		end,
		skip = reel.skip,
		isSpinning = reel.isSpinning,
		destroy = function()
			reel.destroy()
			frame:Destroy()
		end,
	}
end

return Rows
