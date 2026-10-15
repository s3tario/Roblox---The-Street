--!strict
-- Phone menu: a grid of app tiles, one per tab registered with UIController:RegisterMenuTab.
-- Empty-safe (shows a hint when nothing is registered) and refreshes while open when tabs change.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Strings = require(Shared.Config.Strings)
local Kit = require(script.Parent.Parent:WaitForChild("Kit"))

local Menu = { id = "Menu" }

local COLUMNS = 3

local function getTabs(ui: any): { any }
	if ui == nil or type(ui.GetMenuTabs) ~= "function" then
		return {}
	end
	local ok, list = pcall(function()
		return ui:GetMenuTabs()
	end)
	if ok and type(list) == "table" then
		return list
	end
	return {}
end

function Menu.open(_args: any, root: Instance, ctx: any): { close: () -> () }
	local ui = if type(ctx) == "table" then ctx.UI else nil
	local closeScreen = if type(ctx) == "table" and type(ctx.close) == "function" then ctx.close else nil

	local win = Kit.Window({
		title = Strings.get("menu_title"),
		size = UDim2.fromScale(1, 1),
		maxSize = Vector2.new(460, 660),
		onClose = closeScreen,
		name = "MenuWindow",
	})
	win.frame.Parent = root

	local scroll = Kit.Scroll({ padding = 4, gap = 12 })
	scroll.frame.Parent = win.content

	local grid = Kit.Grid({ columns = COLUMNS, cellHeight = 118, gap = 10, name = "Apps" })
	scroll.add(grid)
	local empty = Kit.Label({ text = Strings.get("menu_empty"), align = "center", color = "textDim", name = "Empty" })
	scroll.add(empty)

	local function rebuild()
		grid.clear()
		local tabs = getTabs(ui)
		for i, tab in tabs do
			if type(tab) == "table" and type(tab.id) == "string" then
				local id = tab.id
				local tile = Kit.Tile({
					glyph = if type(tab.glyph) == "string" then tab.glyph else nil,
					title = if type(tab.title) == "string" then tab.title else id,
					badge = if type(tab.badge) == "string" then tab.badge else nil,
					locked = tab.locked == true,
					name = "App_" .. id,
					layoutOrder = i,
					onClick = function()
						if ui and type(ui.ActivateTab) == "function" then
							ui:ActivateTab(id)
						end
					end,
				})
				grid.add(tile.frame)
				tile.frame.LayoutOrder = i
			end
		end
		empty.frame.Visible = #tabs == 0
		grid.frame.Visible = #tabs > 0
	end
	rebuild()

	local conn: any = nil
	if ui and type(ui.MenuTabsChanged) == "table" then
		conn = ui.MenuTabsChanged:Connect(rebuild)
	end

	return {
		close = function()
			if conn then
				conn:Disconnect()
				conn = nil
			end
			win.close()
		end,
	}
end

return Menu
