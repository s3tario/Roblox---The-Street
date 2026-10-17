--!strict
-- OfficeController (client, owned by `offices`; spec v3 §14, contracts §11).
--   * opens the Elevator screen when the server accepts a lobby elevator panel ("Office.OpenElevator") and the
--     Directory screen for street kiosks and tower pickers ("Office.OpenDirectory"); adds the "Directory" menu
--     tab (and a Phone app when the phone feature is running)
--   * visitor rules, client side: ProximityPrompts marked EmployeesOnly = true are hidden while the local player
--     isn't an employee of that office's CompanyId (Store "career".companyId, plus Merger Mania pairs from the
--     global "events"); the server refuses visitors either way
--   * a small "Visitor · <Company>" badge while standing in another company's office
--
-- API (used by UI/Screens/Directory and UI/Screens/Elevator):
--   OfficeController:GetDirectory(force?) -> ({ Entry }?, errKey?)   cached server list (yields on first use)
--   OfficeController:Enter(companyId, floor?) -> (ok, message?)      Office.Enter (yields while travelling)
--   OfficeController:Ride(floor) -> (ok, message?)                   Office.Elevator
--   OfficeController:GetLocation() -> { companyId, floor }?          the office the player stands in
--   OfficeController:IsEmployeeOf(companyId) -> boolean
--   OfficeController:GetCompanyId() -> string?                       the player's own firm
--   OfficeController:OpenDirectory(args?) / :OpenElevator(payload)
--   OfficeController.LocationChanged : Signal(location?)

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Time = require(Shared.Util.Time)
local DoorRules = require(Shared.Logic.DoorRules)
local OfficeAlloc = require(Shared.Logic.OfficeAlloc)
local Registry = require(script.Parent.Parent.Registry)
local UIFolder = script.Parent.Parent:WaitForChild("UI")
local Kit = require(UIFolder:WaitForChild("Kit"))

local Text = DoorRules.Text

local OfficeController = {
	Name = "OfficeController",
	Priority = 30,
	LocationChanged = Signal.new(),
}

local DIRECTORY_SCREEN = "Directory"
local ELEVATOR_SCREEN = "Elevator"
local DIRECTORY_TTL = 30
local OFFICES_FOLDER = "Offices"

export type Location = { companyId: string, floor: string }

local localPlayer = Players.LocalPlayer
local directory: { OfficeAlloc.Entry }? = nil
local directoryAt = -math.huge
local directoryWaiters: { thread }? = nil

---------------------------------------------------------------------------------------------------
-- Store access (the data feature's Store may be missing: everything degrades to "not an employee")
---------------------------------------------------------------------------------------------------
local function store(): any
	return Registry.get("Store")
end

local function storeGet(key: string): any
	local s = store()
	if not s then
		return nil
	end
	local ok, v = pcall(function()
		return s:Get(key)
	end)
	return if ok then v else nil
end

local function storeGlobal(key: string): any
	local s = store()
	if not s then
		return nil
	end
	local ok, v = pcall(function()
		return s:GetGlobal(key)
	end)
	return if ok then v else nil
end

local function ui(): any
	return Registry.get("UIController")
end

function OfficeController:GetCompanyId(): string?
	local career = storeGet("career")
	if DoorRules.isEmployedCareer(career) then
		return career.companyId
	end
	return nil
end

function OfficeController:IsEmployeeOf(companyId: string?): boolean
	return DoorRules.isEmployee(storeGet("career"), companyId, storeGlobal("events"), Time.now())
end

function OfficeController:GetLocation(): Location?
	local c = localPlayer:GetAttribute("OfficeCompany")
	local f = localPlayer:GetAttribute("OfficeFloor")
	if type(c) == "string" and c ~= "" then
		return { companyId = c, floor = if type(f) == "string" then f else OfficeAlloc.LOBBY }
	end
	return nil
end

---------------------------------------------------------------------------------------------------
-- Server calls
---------------------------------------------------------------------------------------------------
-- RemoteFunction results arrive as (ok, errKey?, message?) or (nil, "timeout" | "rate_limited" | "error").
local function call(name: string, ...: any): (boolean, string?)
	local okCall, a, b, c = pcall(Net.invoke, name, ...)
	if not okCall then
		return false, Text.get("tp_failed")
	end
	if a == true then
		return true, nil
	end
	if type(c) == "string" and c ~= "" then
		return false, c
	end
	if a == nil and b == "rate_limited" then
		return false, Text.get("tp_cooldown")
	end
	if b == "cooldown" then
		return false, Text.get("tp_cooldown")
	elseif b == "busy" then
		return false, Text.get("tp_busy")
	end
	return false, Text.get("tp_failed")
end

function OfficeController:Enter(companyId: string, floor: string?): (boolean, string?)
	if type(companyId) ~= "string" or companyId == "" then
		return false, Text.get("unknown_company")
	end
	return call("Office.Enter", companyId, floor)
end

function OfficeController:Ride(floor: string): (boolean, string?)
	if type(floor) ~= "string" or floor == "" then
		return false, Text.get("tp_failed")
	end
	return call("Office.Elevator", floor)
end

local function validEntries(list: any): { OfficeAlloc.Entry }?
	if type(list) ~= "table" then
		return nil
	end
	local out: { OfficeAlloc.Entry } = {}
	for _, e in list do
		if type(e) == "table" and type(e.id) == "string" and type(e.name) == "string" then
			if type(e.departments) ~= "table" then
				e.departments = {}
			end
			table.insert(out, e :: any)
		end
	end
	return out
end

-- One request at a time; concurrent callers wait for it.
function OfficeController:GetDirectory(force: boolean?): ({ OfficeAlloc.Entry }?, string?)
	local cached = directory
	if cached and not force and os.clock() - directoryAt < DIRECTORY_TTL then
		return cached, nil
	end
	local waiters = directoryWaiters
	if waiters then
		table.insert(waiters, coroutine.running())
		coroutine.yield()
		return directory, if directory then nil else "error"
	end
	local mine: { thread } = {}
	directoryWaiters = mine
	local ok, result, err = pcall(Net.invoke, "Office.Directory")
	local entries = if ok then validEntries(result) else nil
	if entries then
		directory = entries
		directoryAt = os.clock()
	end
	directoryWaiters = nil
	for _, th in mine do
		task.spawn(th)
	end
	if entries then
		return entries, nil
	end
	-- a stale list beats nothing
	return directory, if ok and type(err) == "string" then err else "error"
end

function OfficeController:OpenDirectory(args: { [string]: any }?)
	local u = ui()
	if u then
		u:Open(DIRECTORY_SCREEN, args or {})
	end
end

function OfficeController:OpenElevator(payload: { [string]: any })
	local u = ui()
	if u then
		u:Open(ELEVATOR_SCREEN, payload)
	end
end

---------------------------------------------------------------------------------------------------
-- EmployeesOnly prompts (any feature's): hidden locally for visitors
---------------------------------------------------------------------------------------------------
local tracked: { [ProximityPrompt]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local hiddenByUs: { [ProximityPrompt]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local watchedRoots: { [Instance]: RBXScriptConnection } = {}

local function companyOf(inst: Instance): string?
	local node: Instance? = inst
	while node and node ~= workspace and node ~= game do
		local id = node:GetAttribute("CompanyId")
		if type(id) == "string" and id ~= "" then
			return id
		end
		node = node.Parent
	end
	return nil
end

local function evaluate(prompt: ProximityPrompt)
	if prompt.Parent == nil then
		return
	end
	local allowed = DoorRules.promptAllowed(
		storeGet("career"),
		prompt:GetAttribute("EmployeesOnly"),
		companyOf(prompt),
		storeGlobal("events"),
		Time.now()
	)
	if not allowed then
		if prompt.Enabled then
			prompt.Enabled = false
			hiddenByUs[prompt] = true
		end
	elseif hiddenByUs[prompt] then
		hiddenByUs[prompt] = nil
		prompt.Enabled = true
	end
end

local function evaluateAll()
	for prompt in tracked do
		evaluate(prompt)
	end
end

local function track(inst: Instance)
	if not inst:IsA("ProximityPrompt") or tracked[inst] then
		return
	end
	tracked[inst] = true
	inst:GetAttributeChangedSignal("EmployeesOnly"):Connect(function()
		evaluate(inst)
	end)
	inst:GetAttributeChangedSignal("CompanyId"):Connect(function()
		evaluate(inst)
	end)
	evaluate(inst)
end

local officesFolder: Instance? = nil

local function watchRoot(root: Instance)
	if watchedRoots[root] then
		return
	end
	local folder = officesFolder
	if folder and root ~= folder and root:IsDescendantOf(folder) then
		return -- already covered by the Offices folder watch
	end
	watchedRoots[root] = root.DescendantAdded:Connect(track)
	for _, d in root:GetDescendants() do
		track(d)
	end
end

local function unwatchRoot(root: Instance)
	local conn = watchedRoots[root]
	if conn then
		watchedRoots[root] = nil
		conn:Disconnect()
	end
end

local function startPromptRules()
	-- Office instances live under Workspace.Offices (parts stream in and out; DescendantAdded sees each one).
	task.spawn(function()
		local folder = workspace:WaitForChild(OFFICES_FOLDER, 1e9)
		if folder then
			officesFolder = folder
			watchRoot(folder)
		end
	end)
	-- EmployeesOnly prompts elsewhere hang under "Interact"-tagged parts.
	CollectionService:GetInstanceAddedSignal("Interact"):Connect(watchRoot)
	CollectionService:GetInstanceRemovedSignal("Interact"):Connect(unwatchRoot)
	for _, inst in CollectionService:GetTagged("Interact") do
		watchRoot(inst)
	end
end

---------------------------------------------------------------------------------------------------
-- Visitor badge
---------------------------------------------------------------------------------------------------
local badge: Kit.Badge? = nil
local badgeHolder: Frame? = nil

local function companyName(companyId: string): string?
	local offices = workspace:FindFirstChild(OFFICES_FOLDER)
	local inst = if offices then offices:FindFirstChild("Office_" .. companyId) else nil
	local name = if inst then inst:GetAttribute("CompanyName") else nil
	if type(name) == "string" and name ~= "" then
		return name
	end
	local list = directory
	if list then
		for _, e in list do
			if e.id == companyId then
				return e.name
			end
		end
	end
	return OfficeAlloc.prettify(companyId)
end

local function ensureBadge(): (Frame?, Kit.Badge?)
	local holder = badgeHolder
	if holder and holder.Parent then
		return holder, badge
	end
	local u = ui()
	if not u or type(u.GetLayer) ~= "function" then
		return nil, nil
	end
	local ok, layer = pcall(u.GetLayer, u, "hud")
	if not ok or typeof(layer) ~= "Instance" then
		return nil, nil
	end
	local frame = Kit.frame("VisitorBadge", UDim2.new(1, 0, 0, 30))
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Visible = false
	local list = Kit.list(frame, true, 0)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local b = Kit.Badge({ text = Text.get("visitor"), color = "warn", size = "sm", name = "Badge" })
	b.frame.Parent = frame
	local function place()
		frame.Position = UDim2.new(0.5, 0, 0, Kit.Core.insets.top + 6)
	end
	place()
	Kit.InsetsChanged:Connect(place)
	frame.Parent = layer
	badgeHolder = frame
	badge = b
	return frame, b
end

local function refreshBadge()
	local loc = OfficeController:GetLocation()
	local text = if loc
		then DoorRules.visitorBadge(
			storeGet("career"),
			loc.companyId,
			companyName(loc.companyId),
			storeGlobal("events"),
			Time.now()
		)
		else nil
	if text == nil then
		local holder = badgeHolder
		if holder then
			holder.Visible = false
		end
		return
	end
	local holder, b = ensureBadge()
	if holder and b then
		b.setText(text)
		holder.Visible = true
	end
end

local lastLocationKey: string? = nil
local function onLocationAttr()
	local loc = OfficeController:GetLocation()
	local key = if loc then loc.companyId .. "/" .. loc.floor else nil
	if key ~= lastLocationKey then
		lastLocationKey = key
		OfficeController.LocationChanged:Fire(loc)
	end
	refreshBadge()
end

---------------------------------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------------------------------
local function registerTabs()
	local u = ui()
	if u and type(u.RegisterMenuTab) == "function" then
		u:RegisterMenuTab({
			id = "directory",
			title = Text.get("directory_menu"),
			glyph = "🏢",
			order = 45,
			screen = DIRECTORY_SCREEN,
		})
	end
	-- The Phone (milestone 3) lists the Directory as an app when it is running.
	local phone = Registry.all().PhoneController
	if type(phone) == "table" and type(phone.RegisterApp) == "function" then
		local ok, err = pcall(phone.RegisterApp, phone, {
			id = "directory",
			title = Text.get("directory_menu"),
			glyph = "🏢",
			order = 40,
			open = function()
				OfficeController:OpenDirectory({ source = "phone" })
			end,
		})
		if not ok then
			warn("[OfficeController] PhoneController:RegisterApp failed: " .. tostring(err))
		end
	end
end

function OfficeController:Init() end

function OfficeController:Start()
	registerTabs()
	Net.listen("Office.OpenElevator", function(payload: any)
		if type(payload) == "table" and type(payload.companyId) == "string" and type(payload.floors) == "table" then
			OfficeController:OpenElevator(payload)
		end
	end)
	Net.listen("Office.OpenDirectory", function(args: any)
		local open: { [string]: any } = {}
		if type(args) == "table" then
			if type(args.source) == "string" then
				open.source = args.source
			end
			if type(args.title) == "string" then
				open.title = args.title
			end
			if type(args.doorId) == "string" then
				open.doorId = args.doorId
			end
			if type(args.tenants) == "table" then
				local tenants: { string } = {}
				for _, id in args.tenants do
					if type(id) == "string" then
						table.insert(tenants, id)
					end
				end
				open.tenants = tenants
			end
		end
		OfficeController:OpenDirectory(open)
	end)

	startPromptRules()
	localPlayer:GetAttributeChangedSignal("OfficeCompany"):Connect(onLocationAttr)
	localPlayer:GetAttributeChangedSignal("OfficeFloor"):Connect(onLocationAttr)
	local s = store()
	if s then
		pcall(function()
			s:Changed("career"):Connect(function()
				evaluateAll()
				refreshBadge()
			end)
			s:GlobalChanged("events"):Connect(function()
				evaluateAll()
				refreshBadge()
			end)
			s.Loaded:Connect(function()
				evaluateAll()
				refreshBadge()
			end)
		end)
	end
	onLocationAttr()
	-- Merger windows open and close on the clock, not only when "events" changes.
	task.spawn(function()
		while true do
			task.wait(15)
			evaluateAll()
			refreshBadge()
		end
	end)
end

return OfficeController
