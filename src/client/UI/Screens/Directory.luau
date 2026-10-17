--!strict
-- Directory screen (offices; spec v3 §14): every company on the Street with its logo, tier, departments and a
-- Visit button that takes the player to its lobby (Office.Enter through OfficeController). Unavailable firms are
-- greyed "Opening soon". Opened from the menu tab, the street directory kiosks, the Phone, and tower doors:
--   args = { source = "menu" | "kiosk" | "phone" | "tower", title?, tenants? = { companyId }, doorId? }
-- With `tenants` (a multi-tenant tower) it lists only that tower's firms, in the tower's order.
--
--   Directory.rows(entries, opts) -> { Row }    the pure view model (tests/offices)

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local DoorRules = require(Shared.Logic.DoorRules)
local OfficeAlloc = require(Shared.Logic.OfficeAlloc)
local Kit = require(script.Parent.Parent:WaitForChild("Kit"))

local Text = DoorRules.Text

local Directory = { id = "Directory" }

local LOGO = 60
local ACTION_W = 124
local TABS = { "open", "all" }

export type Row = {
	id: string,
	name: string,
	short: string,
	logo: string,
	primary: Color3?,
	meta: string, -- tier label
	departments: string,
	tagline: string?,
	available: boolean,
	own: boolean,
	status: string?, -- "Opening soon" for unavailable firms
}
export type RowOpts = { tab: string?, tenants: { string }?, ownCompany: string? }

-- Rows to show: a tower's tenants (all of them, open or not), else the Directory tab ("open" | "all").
function Directory.rows(entries: { OfficeAlloc.Entry }, opts: RowOpts?): { Row }
	local o: RowOpts = opts or {}
	local list: { OfficeAlloc.Entry }
	if o.tenants then
		list = OfficeAlloc.pickerEntries(entries, o.tenants)
	else
		list = OfficeAlloc.filterOpen(entries, (o.tab or "open") == "open")
	end
	local rows: { Row } = {}
	for _, e in list do
		table.insert(rows, {
			id = e.id,
			name = e.name,
			short = e.short,
			logo = e.logo,
			primary = e.primary,
			meta = e.tierLabel,
			departments = OfficeAlloc.departmentLine(e, not e.available),
			tagline = e.tagline,
			available = e.available,
			own = o.ownCompany ~= nil and e.id == o.ownCompany,
			status = if e.available then nil else Text.get("opening_soon"),
		})
	end
	return rows
end

---------------------------------------------------------------------------------------------------
-- Pieces
---------------------------------------------------------------------------------------------------
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

-- A square logo tile: the company's drawn logo, or its initials on its colour.
local function logoBox(row: Row, size: number, dim: boolean): Frame
	local box = Instance.new("Frame")
	box.Name = "Logo"
	box.BorderSizePixel = 0
	box.Size = UDim2.fromOffset(size, size)
	box.ClipsDescendants = true
	Kit.corner(box, 8)
	Kit.themed(box, function(t)
		box.BackgroundColor3 = t.colors.surface
	end)
	local drawn = false
	local L = logos()
	if L and type(L.render) == "function" then
		local ok = pcall(L.render, box, row.logo, { simple = true, px = size, background = true, corner = 0.12 })
		drawn = ok
	end
	if not drawn then
		box.BackgroundColor3 = row.primary or box.BackgroundColor3
		local mono = Instance.new("TextLabel")
		mono.Name = "Monogram"
		mono.BackgroundTransparency = 1
		mono.Size = UDim2.fromScale(1, 1)
		mono.Text = row.short
		mono.TextScaled = true
		mono.TextColor3 = Kit.Theme.contrastText(box.BackgroundColor3)
		mono.Parent = box
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = math.floor(size * 0.4)
		limit.Parent = mono
		Kit.themed(mono, function(t)
			mono.FontFace = t.fonts.display
		end)
	end
	if dim then
		local veil = Instance.new("Frame")
		veil.Name = "Veil"
		veil.BorderSizePixel = 0
		veil.Size = UDim2.fromScale(1, 1)
		veil.BackgroundColor3 = Color3.new(0, 0, 0)
		veil.BackgroundTransparency = 0.45
		veil.ZIndex = 10
		veil.Parent = box
	end
	return box
end

type RowView = { frame: GuiObject, button: Kit.Button? }

local function buildRow(row: Row, onVisit: (row: Row, button: Kit.Button) -> ()): RowView
	local card = Kit.Card({ name = "Firm_" .. row.id, padding = 10, gap = 0 })
	local line = Kit.List({ direction = "horizontal", gap = 12, align = "center", name = "Row" })
	line.frame.Size = UDim2.new(1, 0, 0, 0)
	line.frame.AutomaticSize = Enum.AutomaticSize.Y
	card.add(line)

	line.add(logoBox(row, LOGO, not row.available))

	local info = Kit.List({ gap = 2, name = "Info" })
	info.frame.Size = UDim2.new(1, -(LOGO + ACTION_W + 24), 0, 0)
	line.add(info)
	local name = Kit.Label({
		text = row.name,
		size = "lg",
		font = "bodyBold",
		color = if row.available then "text" else "textDim",
		name = "Name",
	})
	info.add(name)
	if row.meta ~= "" or row.own then
		local meta = Kit.List({ direction = "horizontal", gap = 6, name = "Meta" })
		info.add(meta)
		if row.meta ~= "" then
			meta.add(Kit.Label({ text = row.meta, size = "sm", color = "accent", autoSize = "xy", name = "Tier" }))
		end
		if row.own then
			meta.add(Kit.Badge({ text = Text.get("directory_your_firm"), color = "good", name = "Own" }))
		end
	end
	info.add(Kit.Label({ text = row.departments, size = "sm", color = "textDim", name = "Departments" }))
	if row.tagline then
		info.add(Kit.Label({
			text = row.tagline,
			size = "xs",
			color = "textDim",
			transparency = 0.2,
			name = "Tagline",
		}))
	end

	local action = Kit.frame("Action", UDim2.fromOffset(ACTION_W, Kit.TAP))
	line.add(action)
	local button: Kit.Button? = nil
	if row.available then
		local b: Kit.Button
		b = Kit.Button({
			text = Text.get("visit"),
			style = "primary",
			size = UDim2.fromOffset(ACTION_W, Kit.TAP),
			name = "Visit",
			onClick = function()
				onVisit(row, b)
			end,
		})
		b.frame.Parent = action
		button = b
	else
		local soon = Kit.Badge({ text = row.status or Text.get("opening_soon"), color = "surface", name = "Soon" })
		soon.frame.AnchorPoint = Vector2.new(0.5, 0.5)
		soon.frame.Position = UDim2.fromScale(0.5, 0.5)
		soon.frame.Parent = action
	end
	return { frame = card.frame, button = button }
end

---------------------------------------------------------------------------------------------------
-- Screen
---------------------------------------------------------------------------------------------------
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

function Directory.open(args: any, root: Instance, ctx: any): { close: () -> () }
	local a = if type(args) == "table" then args else {}
	local tenants: { string }? = if type(a.tenants) == "table" then a.tenants else nil
	local api = apiFrom(ctx)
	local ui = if type(ctx) == "table" then ctx.UI else nil
	local closeScreen = if type(ctx) == "table" and type(ctx.close) == "function" then ctx.close else nil

	local closed = false
	local busy = false
	local tab = "open"
	local entries: { OfficeAlloc.Entry } = {}
	local loaded = false
	local views: { RowView } = {}
	local render: (() -> ())? = nil
	local load: ((force: boolean) -> ())? = nil

	local function notify(text: string)
		if ui and type(ui.Notify) == "function" then
			ui:Notify(text, "warn")
		end
	end

	local win = Kit.Window({
		title = if type(a.title) == "string" and a.title ~= "" then a.title else Text.get("directory_title"),
		subtitle = Text.get(if tenants then "picker_subtitle" else "directory_subtitle"),
		size = UDim2.fromScale(1, 1),
		maxSize = Vector2.new(720, 680),
		onClose = closeScreen,
		name = "DirectoryWindow",
	})
	win.frame.Parent = root

	local top = Kit.frame("Top", UDim2.new(1, 0, 0, Kit.TAP + 4))
	top.Parent = win.content
	if tenants == nil then
		local tabs = Kit.Tabs({
			tabs = {
				{ id = "open", title = Text.get("tab_open") },
				{ id = "all", title = Text.get("tab_all") },
			},
			selected = tab,
			name = "Tabs",
			onSelect = function(id: string)
				if table.find(TABS, id) and id ~= tab then
					tab = id
					local r = render
					if r then
						r()
					end
				end
			end,
		})
		tabs.frame.Parent = top
	else
		local hint =
			Kit.Label({ text = Text.get("directory_lobby_hint"), size = "sm", color = "textDim", name = "Hint" })
		hint.frame.AnchorPoint = Vector2.new(0, 0.5)
		hint.frame.Position = UDim2.fromScale(0, 0.5)
		hint.frame.Parent = top
	end

	local scroll = Kit.Scroll({ gap = 8, name = "Firms" })
	scroll.frame.Position = UDim2.fromOffset(0, Kit.TAP + 12)
	scroll.frame.Size = UDim2.new(1, 0, 1, -(Kit.TAP + 12))
	scroll.frame.Parent = win.content

	local function showStatus(key: string, withRetry: boolean)
		scroll.clear()
		views = {}
		scroll.add(Kit.Label({ text = Text.get(key), align = "center", color = "textDim", name = "Status" }))
		if withRetry then
			scroll.add(Kit.Button({
				text = Text.get("retry"),
				style = "secondary",
				name = "Retry",
				onClick = function()
					local l = load
					if l then
						l(true)
					end
				end,
			}))
		end
	end

	local function ownCompany(): string?
		if api and type(api.GetCompanyId) == "function" then
			local ok, id = pcall(api.GetCompanyId, api)
			if ok and type(id) == "string" then
				return id
			end
		end
		return nil
	end

	local function setButtonsDisabled(on: boolean)
		for _, v in views do
			local b = v.button
			if b then
				b.setDisabled(on)
			end
		end
	end

	local function visit(row: Row, button: Kit.Button)
		if busy or closed then
			return
		end
		if not (api and type(api.Enter) == "function") then
			notify(Text.get("tp_failed"))
			return
		end
		busy = true
		setButtonsDisabled(true)
		button.setText(Text.get("visiting"))
		task.spawn(function()
			local ok, entered, message = pcall(api.Enter, api, row.id, nil)
			if closed then
				return
			end
			if ok and entered == true then
				if closeScreen then
					closeScreen()
				end
				return
			end
			busy = false
			button.setText(Text.get("visit"))
			setButtonsDisabled(false)
			notify(if ok and type(message) == "string" and message ~= "" then message else Text.get("tp_failed"))
		end)
	end

	render = function()
		if closed or not loaded then
			return
		end
		local rows = Directory.rows(entries, { tab = tab, tenants = tenants, ownCompany = ownCompany() })
		if #rows == 0 then
			showStatus(if #entries > 0 and tab == "open" then "directory_none_open" else "directory_empty", false)
			return
		end
		scroll.clear()
		views = {}
		for _, row in rows do
			local view = buildRow(row, visit)
			table.insert(views, view)
			scroll.add(view.frame)
		end
		scroll.scrollToTop()
		if busy then
			setButtonsDisabled(true)
		end
	end

	local function startLoad(force: boolean)
		showStatus("directory_loading", false)
		task.spawn(function()
			local list: any = nil
			if api and type(api.GetDirectory) == "function" then
				local ok, l = pcall(api.GetDirectory, api, force)
				list = if ok then l else nil
			end
			if closed then
				return
			end
			if type(list) == "table" then
				entries = list
				loaded = true
				local r = render
				if r then
					r()
				end
			else
				showStatus("directory_error", true)
			end
		end)
	end
	load = startLoad
	startLoad(false)

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

return Directory
