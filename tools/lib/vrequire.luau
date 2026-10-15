-- Virtual DataModel for Lune: lets game modules written for Roblox (require(script.Parent.X),
-- game:GetService("ReplicatedStorage").Shared...) run unchanged under Lune for tests and bakes.
-- It mirrors the Rojo tree in default.project.json using Rojo's file-naming rules.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local task = require("@lune/task")

local V = {}

type Node = {
	name: string,
	className: string,
	file: string?, -- source file for scripts
	dir: string?, -- directory whose entries become children
	parent: Node?,
	explicit: { [string]: Node },
	childrenCache: { Node }?,
	proxy: any?,
}

local SCRIPT_SUFFIXES = {
	{ ".server.luau", "Script" },
	{ ".client.luau", "LocalScript" },
	{ ".server.lua", "Script" },
	{ ".client.lua", "LocalScript" },
	{ ".luau", "ModuleScript" },
	{ ".lua", "ModuleScript" },
}

local function endsWith(s: string, suffix: string): boolean
	return #s >= #suffix and string.sub(s, -#suffix) == suffix
end

local function classifyFile(fileName: string): (string?, string?)
	for _, pair in SCRIPT_SUFFIXES do
		if endsWith(fileName, pair[1]) then
			return string.sub(fileName, 1, #fileName - #pair[1]), pair[2]
		end
	end
	return nil, nil
end

local function newNode(name: string, className: string, parent: Node?): Node
	return { name = name, className = className, parent = parent, explicit = {} }
end

-- Build a node for a filesystem path following Rojo conventions.
local function nodeFromPath(name: string, path: string, parent: Node?): Node?
	if fs.isDir(path) then
		for _, init in { "init.luau", "init.lua", "init.server.luau", "init.client.luau" } do
			local p = path .. "/" .. init
			if fs.isFile(p) then
				local _, cls = classifyFile(init)
				local n = newNode(name, cls :: string, parent)
				n.file = p
				n.dir = path
				return n
			end
		end
		local n = newNode(name, "Folder", parent)
		n.dir = path
		return n
	elseif fs.isFile(path) then
		if endsWith(path, ".rbxm") or endsWith(path, ".rbxmx") then
			return newNode(name, "Model", parent) -- opaque in the virtual tree
		end
		local _, cls = classifyFile(path)
		if cls then
			local n = newNode(name, cls, parent)
			n.file = path
			return n
		end
	end
	return nil
end

local function children(node: Node): { Node }
	if node.childrenCache then
		return node.childrenCache
	end
	local list: { Node } = {}
	local seen: { [string]: boolean } = {}
	for _, c in node.explicit do
		table.insert(list, c)
		seen[c.name] = true
	end
	if node.dir then
		local entries = fs.readDir(node.dir)
		table.sort(entries)
		for _, entry in entries do
			local full = node.dir .. "/" .. entry
			local childName: string? = nil
			if fs.isDir(full) then
				childName = entry
			else
				local base = classifyFile(entry)
				if base and base ~= "init" then
					childName = base
				end
			end
			if childName and not seen[childName] then
				local c = nodeFromPath(childName, full, node)
				if c then
					seen[childName] = true
					table.insert(list, c)
				end
			end
		end
	end
	node.childrenCache = list
	return list
end

local function findChild(node: Node, name: string): Node?
	for _, c in children(node) do
		if c.name == name then
			return c
		end
	end
	return nil
end

local function fullName(node: Node): string
	local parts = {}
	local n: Node? = node
	while n and n.parent do
		table.insert(parts, 1, n.name)
		n = n.parent
	end
	return table.concat(parts, ".")
end

---------------------------------------------------------------------------------------------------
-- Proxies that behave enough like Instances for module code
---------------------------------------------------------------------------------------------------
local CLASS_ISA = {
	ModuleScript = { ModuleScript = true, LuaSourceContainer = true, Instance = true },
	Script = { Script = true, BaseScript = true, LuaSourceContainer = true, Instance = true },
	LocalScript = { LocalScript = true, Script = true, BaseScript = true, LuaSourceContainer = true, Instance = true },
	Folder = { Folder = true, Instance = true },
	Model = { Model = true, PVInstance = true, Instance = true },
	DataModel = { DataModel = true, Instance = true },
}

local proxyToNode: { [any]: Node } = setmetatable({}, { __mode = "k" }) :: any

local function proxyOf(node: Node): any
	if node.proxy then
		return node.proxy
	end
	local methods = {}
	function methods.FindFirstChild(_, name: string)
		local c = findChild(node, name)
		return if c then proxyOf(c) else nil
	end
	function methods.WaitForChild(_, name: string)
		local c = findChild(node, name)
		if not c then
			error(("[vrequire] WaitForChild: %s has no child '%s'"):format(fullName(node), name), 2)
		end
		return proxyOf(c)
	end
	function methods.GetChildren(_)
		local out = {}
		for _, c in children(node) do
			table.insert(out, proxyOf(c))
		end
		return out
	end
	function methods.GetDescendants(_)
		local out = {}
		local function walk(n: Node)
			for _, c in children(n) do
				table.insert(out, proxyOf(c))
				walk(c)
			end
		end
		walk(node)
		return out
	end
	function methods.IsA(_, cls: string)
		local set = CLASS_ISA[node.className]
		return set ~= nil and set[cls] == true
	end
	function methods.GetFullName(_)
		return fullName(node)
	end
	function methods.GetAttribute(_, _name: string)
		return nil
	end
	function methods.GetService(_, serviceName: string)
		local c = findChild(node, serviceName)
		if not c then
			error(("[vrequire] service '%s' is not available under Lune (not in the Rojo tree)"):format(serviceName), 2)
		end
		return proxyOf(c)
	end

	local proxy = setmetatable({}, {
		__index = function(_, key)
			if key == "Name" then
				return node.name
			elseif key == "ClassName" then
				return node.className
			elseif key == "Parent" then
				return if node.parent then proxyOf(node.parent) else nil
			end
			local m = methods[key]
			if m then
				return m
			end
			local c = findChild(node, key)
			if c then
				return proxyOf(c)
			end
			error(
				("[vrequire] %s is not a valid member of %s '%s'"):format(tostring(key), node.className, fullName(node)),
				2
			)
		end,
		__tostring = function()
			return fullName(node)
		end,
	})
	node.proxy = proxy
	proxyToNode[proxy] = node
	return proxy
end

---------------------------------------------------------------------------------------------------
-- Project tree
---------------------------------------------------------------------------------------------------
local function buildTree(def: { [string]: any }, name: string, parent: Node?): Node
	local node: Node
	local path = def["$path"]
	if type(path) == "table" then
		path = path.optional
	end
	if type(path) == "string" and (fs.isDir(path) or fs.isFile(path)) then
		node = nodeFromPath(name, path, parent) or newNode(name, def["$className"] or "Folder", parent)
	else
		node = newNode(name, def["$className"] or "Folder", parent)
	end
	for key, sub in def do
		if string.sub(key, 1, 1) ~= "$" and type(sub) == "table" then
			node.explicit[key] = buildTree(sub, key, node)
		end
	end
	return node
end

local root: Node? = nil

-- Lune's fs calls yield, and yielding inside __index metamethods is illegal, so the whole tree is
-- scanned eagerly here and metamethods only read the cache.
local function scanAll(node: Node)
	for _, c in children(node) do
		scanAll(c)
	end
end

function V.init(projectFile: string?)
	local project = serde.decode("json", fs.readFile(projectFile or "default.project.json"))
	root = buildTree(project.tree, "game", nil)
	root.className = "DataModel"
	scanAll(root)
end

-- Re-scan the filesystem (e.g. after a test writes files).
function V.rescan()
	assert(root, "vrequire: call V.init() first")
	local function reset(n: Node)
		if n.childrenCache then
			for _, c in n.childrenCache do
				reset(c)
			end
		end
		n.childrenCache = nil
	end
	reset(root)
	scanAll(root)
end

function V.game(): any
	assert(root, "vrequire: call V.init() first")
	return proxyOf(root)
end

-- Resolve "ReplicatedStorage/Shared/Logic/Review" to a proxy.
function V.resolve(path: string): any
	assert(root, "vrequire: call V.init() first")
	local node: Node = root
	for seg in string.gmatch(path, "[^/%.]+") do
		local c = findChild(node, seg)
		if not c then
			error("[vrequire] cannot resolve " .. path .. " (missing " .. seg .. ")")
		end
		node = c
	end
	return proxyOf(node)
end

---------------------------------------------------------------------------------------------------
-- Module loading
---------------------------------------------------------------------------------------------------
local moduleCache: { [string]: any } = {}
local loading: { [string]: boolean } = {}

local baseEnv: { [string]: any } = {}
for k, v in roblox do
	if type(k) == "string" and string.match(k, "^%u") then
		baseEnv[k] = v -- Instance, Vector3, CFrame, Color3, Enum, UDim2, Font, ...
	end
end
baseEnv.task = task
baseEnv.warn = function(...)
	print("[warn]", ...)
end
baseEnv.tick = os.clock
-- deliberately absent: workspace, Random, DateTime, wait, spawn, delay

local vrequire

local function makeEnv(scriptProxy: any): { [string]: any }
	local env = table.clone(baseEnv)
	env.script = scriptProxy
	env.game = V.game()
	env.require = vrequire
	return env
end

function V.loadFile(path: string, scriptProxy: any?): any
	local source = fs.readFile(path)
	local chunk = luau.load(source, { debugName = path, environment = makeEnv(scriptProxy), injectGlobals = true })
	return chunk()
end

vrequire = function(target: any): any
	if type(target) == "string" then
		error("[vrequire] string requires are not supported inside game modules: " .. target, 2)
	end
	local node = proxyToNode[target]
	if not node then
		error("[vrequire] require() expects a ModuleScript proxy, got " .. typeof(target), 2)
	end
	if node.className ~= "ModuleScript" or not node.file then
		error("[vrequire] " .. fullName(node) .. " is not a ModuleScript", 2)
	end
	local file = node.file :: string
	local cached = moduleCache[file]
	if cached ~= nil then
		return cached
	end
	if loading[file] then
		error("[vrequire] circular require of " .. fullName(node), 2)
	end
	loading[file] = true
	local ok, result = pcall(V.loadFile, file, target)
	loading[file] = nil
	if not ok then
		error(("[vrequire] error loading %s:\n%s"):format(fullName(node), tostring(result)), 0)
	end
	if result == nil then
		error("[vrequire] module returned nil: " .. fullName(node), 2)
	end
	moduleCache[file] = result
	return result
end

V.require = vrequire

-- Convenience: require by DataModel path string.
function V.requirePath(path: string): any
	return vrequire(V.resolve(path))
end

-- Environment for test specs (no `script`).
function V.specEnv(): { [string]: any }
	return makeEnv(nil)
end

function V.clearCache()
	table.clear(moduleCache)
end

return V
