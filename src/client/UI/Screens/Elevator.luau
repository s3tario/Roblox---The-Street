--!strict
-- Elevator screen (offices; spec v3 §14): the lobby elevator panel. Lists the company's floors, top floor first,
-- with their department names; the floor you're on is marked, floors whose department hasn't opened yet are
-- greyed "Opening soon". Anyone may ride, visitors included (Office.Elevator through OfficeController).
--   args = the "Office.OpenElevator" payload { companyId, name, short, logo, primary?, accent?, current?,
--          floors = { { id, name, floor, available } }, outage? }
--
--   Elevator.rows(args) -> { OfficeAlloc.ElevatorRow }   the pure view model (tests/offices)

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local DoorRules = require(Shared.Logic.DoorRules)
local OfficeAlloc = require(Shared.Logic.OfficeAlloc)
local Kit = require(script.Parent.Parent:WaitForChild("Kit"))

local Text = DoorRules.Text

local Elevator = { id = "Elevator" }

local BADGE = 44
local HEADER_LOGO = 48

function Elevator.rows(args: any): { OfficeAlloc.ElevatorRow }
	if type(args) ~= "table" or type(args.floors) ~= "table" then
		return {}
	end
	return OfficeAlloc.elevatorRows(args.floors, if type(args.current) == "string" then args.current else nil)
end

local logosModule: any = nil
local function logos(): any
	if logosModule == nil then
		local ok, m = pcall(function()
			local assets = Shared:FindFirstChild("Assets")
			local mod = if assets then assets:FindFirstChild("Logos") else nil
			return if mod then (require :: any)(mod) else nil
		end)
		logosModule = if ok and type(m) == "table" then m else false
	end
	return if logosModule then logosModule else nil
end

local function header(args: { [string]: any }, isVisitor: boolean): Frame
	local list = Kit.List({ direction = "horizontal", gap = 12, align = "center", name = "Header" })
	local f = list.frame
	f.Size = UDim2.new(1, 0, 0, 0)
	f.AutomaticSize = Enum.AutomaticSize.Y

	local box = Instance.new("Frame")
	box.Name = "Logo"
	box.BorderSizePixel = 0
	box.Size = UDim2.fromOffset(HEADER_LOGO, HEADER_LOGO)
	box.ClipsDescendants = true
	Kit.corner(box, 8)
	Kit.themed(box, function(t)
		box.BackgroundColor3 = t.colors.surface
	end)
	local L = logos()
	local drawn = false
	if L and type(L.render) == "function" and type(args.logo) == "string" then
		drawn = pcall(L.render, box, args.logo, { simple = true, px = HEADER_LOGO, background = true, corner = 0.12 })
	end
	if not drawn then
		local mono = Kit.Label({
			text = if type(args.short) == "string" then args.short else "",
			size = "lg",
			font = "display",
			align = "center",
			autoSize = "none",
			height = HEADER_LOGO,
			name = "Monogram",
		})
		mono.frame.Parent = box
	end
	list.add(box)

	local col = Kit.List({ gap = 2, name = "Text" })
	col.frame.Size = UDim2.new(1, -(HEADER_LOGO + 12), 0, 0)
	list.add(col)
	col.add(Kit.Label({ text = Text.get("elevator_choose"), size = "md", font = "bodyBold", name = "Choose" }))
	if args.outage == true then
		col.add(Kit.Label({ text = Text.get("elevator_outage_notice"), size = "sm", color = "warn", name = "Outage" }))
	end
	if isVisitor then
		col.add(
			Kit.Label({ text = Text.get("elevator_visitor_note"), size = "sm", color = "textDim", name = "Visitor" })
		)
	end
	return f
end

type RowView = { card: { frame: GuiObject }, row: OfficeAlloc.ElevatorRow }

local function floorRow(row: OfficeAlloc.ElevatorRow, onPick: ((RowView) -> ())?): RowView
	local view: RowView = nil :: any
	local clickable = row.available and not row.here and onPick ~= nil
	local card = Kit.Card({
		name = "Floor_" .. row.id,
		padding = 8,
		gap = 0,
		color = if row.here then "surface" else nil,
		onClick = if clickable
			then function()
				(onPick :: (RowView) -> ())(view)
			end
			else nil,
	})
	local line = Kit.List({ direction = "horizontal", gap = 12, align = "center", name = "Row" })
	line.frame.Size = UDim2.new(1, 0, 0, 0)
	line.frame.AutomaticSize = Enum.AutomaticSize.Y
	card.add(line)

	local badge = Instance.new("Frame")
	badge.Name = "Number"
	badge.BorderSizePixel = 0
	badge.Size = UDim2.fromOffset(BADGE, BADGE)
	Kit.corner(badge, 999)
	local stroke = Kit.stroke(badge, 2)
	local num = Instance.new("TextLabel")
	num.Name = "Text"
	num.BackgroundTransparency = 1
	num.Size = UDim2.fromScale(1, 1)
	num.Text = row.badge
	num.Parent = badge
	Kit.themed(badge, function(t)
		local lit = row.here
		badge.BackgroundColor3 = if lit then t.colors.accent else t.colors.panel
		stroke.Color = if row.available then t.colors.accent else t.colors.border
		num.FontFace = t.fonts.display
		num.TextSize = t.text.lg
		num.TextColor3 = if lit then t.colors.accentText elseif row.available then t.colors.text else t.colors.textDim
	end)
	line.add(badge)

	local col = Kit.List({ gap = 0, name = "Text" })
	col.frame.Size = UDim2.new(1, -(BADGE + 12), 0, 0)
	line.add(col)
	col.add(Kit.Label({
		text = row.name,
		size = "md",
		font = "bodyBold",
		color = if row.available then "text" else "textDim",
		name = "Name",
	}))
	local sub: string
	if row.here then
		sub = Text.get("you_are_here")
	elseif not row.available then
		sub = Text.get("opening_soon")
	elseif row.floor == 0 then
		sub = Text.get("lobby")
	else
		sub = Text.format("elevator_floor", { n = row.floor })
	end
	col.add(Kit.Label({
		text = sub,
		size = "sm",
		color = if row.here then "accent" else "textDim",
		name = "Status",
	}))
	view = { card = card, row = row }
	return view
end

local function apiFrom(ctx: any): any
	local reg = if type(ctx) == "table" then ctx.Registry else nil
	if reg and type(reg.get) == "function" then
		local ok, api = pcall(reg.get, "OfficeController")
		if ok and type(api) == "table" then
			return api
		end
	end
	return nil
end

function Elevator.open(args: any, root: Instance, ctx: any): { close: () -> () }
	local a: { [string]: any } = if type(args) == "table" then args else {}
	local api = apiFrom(ctx)
	local ui = if type(ctx) == "table" then ctx.UI else nil
	local closeScreen = if type(ctx) == "table" and type(ctx.close) == "function" then ctx.close else nil
	local closed = false
	local busy = false

	local isVisitor = false
	if api and type(api.IsEmployeeOf) == "function" and type(a.companyId) == "string" then
		local ok, employee = pcall(api.IsEmployeeOf, api, a.companyId)
		isVisitor = ok and employee == false
	end

	local win = Kit.Window({
		title = if type(a.name) == "string" and a.name ~= "" then a.name else Text.get("elevator_title"),
		subtitle = Text.get("elevator_title"),
		size = UDim2.fromScale(1, 1),
		maxSize = Vector2.new(460, 640),
		onClose = closeScreen,
		accent = if typeof(a.accent) == "Color3"
			then a.accent
			elseif typeof(a.primary) == "Color3" then a.primary
			else nil,
		name = "ElevatorWindow",
	})
	win.frame.Parent = root

	local scroll = Kit.Scroll({ gap = 8, name = "Floors" })
	scroll.frame.Parent = win.content
	scroll.add(header(a, isVisitor))

	local function notify(text: string)
		if ui and type(ui.Notify) == "function" then
			ui:Notify(text, "warn")
		end
	end

	local function pick(view: RowView)
		if busy or closed then
			return
		end
		if not (api and type(api.Ride) == "function") then
			notify(Text.get("tp_failed"))
			return
		end
		busy = true
		local status = view.card.frame:FindFirstChild("Status", true)
		if status and status:IsA("TextLabel") then
			status.Text = Text.get("elevator_riding")
		end
		task.spawn(function()
			local ok, rode, message = pcall(api.Ride, api, view.row.id)
			if closed then
				return
			end
			if ok and rode == true then
				if closeScreen then
					closeScreen()
				end
				return
			end
			busy = false
			if status and status:IsA("TextLabel") then
				status.Text = if view.row.floor == 0
					then Text.get("lobby")
					else Text.format("elevator_floor", { n = view.row.floor })
			end
			notify(if ok and type(message) == "string" and message ~= "" then message else Text.get("tp_failed"))
		end)
	end

	local rows = Elevator.rows(a)
	if #rows == 0 then
		scroll.add(Kit.Label({ text = Text.get("tp_failed"), color = "textDim", align = "center", name = "Empty" }))
	end
	for _, row in rows do
		scroll.add(floorRow(row, pick).card)
	end

	return {
		close = function()
			if closed then
				return
			end
			closed = true
			win.close()
		end,
	}
end

return Elevator
