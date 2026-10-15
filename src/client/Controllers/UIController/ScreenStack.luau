--!strict
-- UIController's screen stack: discovers UI/Screens modules, keeps one full screen open at a time with a
-- short back history, tracks the modal stack, and binds gamepad B to Back while anything is open.

local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local ScreenStack = {}

export type ScreenModule = {
	id: string?,
	hideHud: boolean?,
	open: (args: any, root: Frame, ctx: any) -> any,
}

export type Deps = {
	layer: Frame, -- the screens layer
	folder: Instance?, -- UI/Screens
	makeCtx: (id: string, close: () -> ()) -> { [string]: any },
	onChanged: (id: string?, hideHud: boolean) -> (),
	sound: (name: string) -> (),
	onOpenError: (id: string) -> (),
}

export type Stack = {
	open: (id: string, args: any?) -> boolean,
	close: (id: string?) -> boolean,
	back: () -> boolean,
	isOpen: (id: string?) -> boolean,
	current: () -> string?,
	pushModal: (close: () -> ()) -> () -> (),
	hasModal: () -> boolean,
	loadAll: () -> (),
	known: () -> { string },
}

type Active = {
	id: string,
	args: any,
	container: Frame,
	handle: any,
	closing: boolean,
	hideHud: boolean,
}

local HISTORY_MAX = 6
local BACK_ACTION = "TheStreetUI_Back"
local GAMEPADS = {
	[Enum.UserInputType.Gamepad1] = true,
	[Enum.UserInputType.Gamepad2] = true,
	[Enum.UserInputType.Gamepad3] = true,
	[Enum.UserInputType.Gamepad4] = true,
}

local function callClose(handle: any, id: string)
	if type(handle) == "table" and type(handle.close) == "function" then
		local ok, err = pcall(handle.close)
		if not ok then
			warn(("[UIController] screen %s close failed: %s"):format(id, tostring(err)))
		end
	end
end

function ScreenStack.new(deps: Deps): Stack
	local modules: { [string]: ModuleScript } = {}
	local screens: { [string]: ScreenModule } = {}
	local scannedAll = false
	local active: Active? = nil
	local history: { { id: string, args: any } } = {}
	local modals: { { close: () -> () } } = {}
	local backBound = false
	local stack: Stack

	local function index()
		local folder = deps.folder
		if folder == nil then
			return
		end
		for _, child in folder:GetChildren() do
			if child:IsA("ModuleScript") then
				modules[child.Name] = child
			end
		end
	end

	local function load(module: ModuleScript): ScreenModule?
		local ok, mod = pcall(require, module)
		if not ok then
			warn(("[UIController] screen %s failed to load: %s"):format(module.Name, tostring(mod)))
			return nil
		end
		local m = mod :: any
		if type(m) ~= "table" or type(m.open) ~= "function" then
			return nil -- helper module, not a screen
		end
		local id = if type(m.id) == "string" then m.id else module.Name
		screens[id] = m
		if screens[module.Name] == nil then
			screens[module.Name] = m
		end
		return m
	end

	local function loadAll()
		scannedAll = true
		index()
		for name, module in modules do
			if screens[name] == nil then
				load(module)
			end
		end
	end

	local function resolve(id: string): ScreenModule?
		local cached = screens[id]
		if cached then
			return cached
		end
		local module = modules[id]
		if module then
			load(module)
			if screens[id] then
				return screens[id]
			end
		end
		if not scannedAll then
			loadAll()
			return screens[id]
		end
		return nil
	end

	local function updateBackBinding()
		local want = active ~= nil or #modals > 0
		if want and not backBound then
			backBound = true
			ContextActionService:BindActionAtPriority(
				BACK_ACTION,
				function(_name: string, state: Enum.UserInputState, _input: InputObject): Enum.ContextActionResult?
					if state == Enum.UserInputState.Begin then
						stack.back()
					end
					return Enum.ContextActionResult.Sink
				end,
				false,
				Enum.ContextActionPriority.High.Value + 50,
				Enum.KeyCode.ButtonB
			)
		elseif not want and backBound then
			backBound = false
			ContextActionService:UnbindAction(BACK_ACTION)
		end
	end

	local function clearSelectionIn(container: Instance)
		local sel = GuiService.SelectedObject
		if sel and sel:IsDescendantOf(container) then
			GuiService.SelectedObject = nil
		end
	end

	-- Gamepad players get the first button selected so they can navigate at once.
	local function selectFirstButton(container: Instance)
		if not GAMEPADS[UserInputService:GetLastInputType()] then
			return
		end
		task.delay(0.1, function()
			if container.Parent == nil then
				return
			end
			for _, d in container:GetDescendants() do
				if d:IsA("GuiButton") and d.Visible and d.Selectable and d.Name ~= "Close" then
					GuiService.SelectedObject = d
					return
				end
			end
		end)
	end

	local function closeActive(playSound: boolean)
		local entry = active
		if entry == nil then
			return
		end
		active = nil
		entry.closing = true
		callClose(entry.handle, entry.id)
		clearSelectionIn(entry.container)
		entry.container:Destroy()
		if playSound then
			deps.sound("close")
		end
	end

	local function openInternal(id: string, args: any, pushHistory: boolean): boolean
		local mod = resolve(id)
		if mod == nil then
			warn("[UIController] unknown screen " .. tostring(id))
			return false
		end
		local current = active
		if current then
			if current.id == id and args == nil then
				return true
			end
			if pushHistory and current.id ~= id then
				for i = #history, 1, -1 do
					if history[i].id == current.id then
						table.remove(history, i)
					end
				end
				table.insert(history, { id = current.id, args = current.args })
				while #history > HISTORY_MAX do
					table.remove(history, 1)
				end
			end
			closeActive(false)
		end
		for i = #history, 1, -1 do
			if history[i].id == id then
				table.remove(history, i)
			end
		end

		local screenArgs = if type(args) == "table" then args else {}
		local container = Instance.new("Frame")
		container.Name = id
		container.BackgroundTransparency = 1
		container.BorderSizePixel = 0
		container.Size = UDim2.fromScale(1, 1)
		container.Parent = deps.layer

		local entry: Active = {
			id = id,
			args = args,
			container = container,
			handle = nil,
			closing = false,
			hideHud = screenArgs.hideHud == true or mod.hideHud == true,
		}
		active = entry
		updateBackBinding()
		deps.sound("open")
		deps.onChanged(id, entry.hideHud)

		local ctx = deps.makeCtx(id, function()
			if active == entry then
				stack.close(id)
			end
		end)
		-- open() may yield (Net.invoke etc.): never block the caller, and cope with a close that
		-- happens before open() returns.
		task.spawn(function()
			local ok, handle = pcall(mod.open, screenArgs, container, ctx)
			if not ok then
				warn(("[UIController] screen %s failed to open: %s"):format(id, tostring(handle)))
				if active == entry then
					stack.close(id)
				end
				deps.onOpenError(id)
				return
			end
			entry.handle = handle
			if entry.closing then
				callClose(handle, id)
				return
			end
			selectFirstButton(container)
		end)
		return true
	end

	stack = {
		open = function(id: string, args: any?): boolean
			if type(id) ~= "string" or id == "" then
				return false
			end
			return openInternal(id, args, true)
		end,
		close = function(id: string?): boolean
			local current = active
			if current == nil or (id ~= nil and current.id ~= id) then
				return false
			end
			table.clear(history)
			closeActive(true)
			updateBackBinding()
			deps.onChanged(nil, false)
			return true
		end,
		back = function(): boolean
			local top = modals[#modals]
			if top then
				-- The modal's close releases its record; a non-dismissable modal stays open.
				local ok, err = pcall(top.close :: any)
				if not ok then
					warn("[UIController] modal close failed: " .. tostring(err))
				end
				updateBackBinding()
				return true
			end
			if active then
				local prev = table.remove(history)
				closeActive(true)
				if prev and openInternal(prev.id, prev.args, false) then
					return true
				end
				updateBackBinding()
				deps.onChanged(nil, false)
				return true
			end
			return false
		end,
		isOpen = function(id: string?): boolean
			local current = active
			if current == nil then
				return false
			end
			return id == nil or current.id == id
		end,
		current = function(): string?
			local current = active
			return if current then current.id else nil
		end,
		pushModal = function(close: () -> ()): () -> ()
			local rec = { close = close }
			table.insert(modals, rec)
			updateBackBinding()
			return function()
				local i = table.find(modals, rec)
				if i then
					table.remove(modals, i)
				end
				updateBackBinding()
			end
		end,
		hasModal = function(): boolean
			return #modals > 0
		end,
		loadAll = loadAll,
		known = function(): { string }
			if not scannedAll then
				loadAll()
			end
			local list: { string } = {}
			for id in screens do
				table.insert(list, id)
			end
			table.sort(list)
			return list
		end,
	}

	index()
	return stack
end

return ScreenStack
