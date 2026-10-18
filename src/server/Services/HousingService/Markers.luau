--!strict
-- HousingService/Markers: finds the housing markers inside world and office models. No services and no yields, so it
-- also runs under Lune (tests/shop/markers.spec.luau).
--
-- Containers (a Model or a part; name, attribute or CollectionService tag, like OfficeService/Template.deskSlots):
--   DeskSlot    an open-plan desk on a company floor (24 per floor template)
--   OfficeSlot  a private office on a company floor (8 per floor template)
--   UnitSlot    a dorm room or an apartment (attribute UnitKind / Context = "dorm" | "apartment", else the zone it
--               stands in: Config/World "dorm" interior -> dorm, "apartments" -> apartment)
-- Inside a container:
--   DecorSlot   a marker part with attribute SlotKind (Config/Decor.SLOT_KINDS). Optional: SlotId (stable id),
--               SlotIndex (ordering), MaxWidth / MaxHeight / MaxDepth (studs). Floor and desk items stand on the
--               part's bottom face; wall items hang from its back face (+Z), facing its front (-Z).
--   Nameplate   a part or model named / tagged "Nameplate" (its TextLabels get "name / title")
--   ThemeWall / ThemeFloor   parts tagged (or attribute Theme = "wall" | "floor") that room themes recolour
-- Slot ids without SlotId are "<kind>_<n>", numbered by SlotIndex, then by position in the container's own frame,
-- so every copy of a template (any company, any rotation) shares them.
--
--   Markers.containerKind(inst) -> ("desk" | "office" | "unit")?
--   Markers.containers(root, kind) -> { Instance }      top-level containers of a kind, in slot order
--   Markers.containerOf(inst) -> (container?, kind?)    nearest container at or above inst
--   Markers.unitKind(container) -> ("dorm" | "apartment")?
--   Markers.slots(container) -> { Slot }                its DecorSlots (not those of nested containers)
--   Markers.nameplates(container) -> { Instance }       Markers.themeParts(container) -> (walls, floors)
--   Markers.mountCFrame(part, mount) -> CFrame          where a Props model with that mount stands on the slot
--   Markers.position(inst) -> Vector3                   Markers.refCFrame(container) -> CFrame

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local World = require(Shared.Config.World)
local Decor = require(Shared.Config.Decor)

local Markers = {}

export type Limits = { width: number?, height: number?, depth: number? }
export type Slot = { id: string, kind: string, part: BasePart, limits: Limits? }

Markers.CONTAINERS = { desk = "DeskSlot", office = "OfficeSlot", unit = "UnitSlot" }
Markers.DECOR_SLOT = "DecorSlot"
Markers.NAMEPLATE = "Nameplate"
Markers.THEME_WALL = "ThemeWall"
Markers.THEME_FLOOR = "ThemeFloor"

local ORDER = { "desk", "office", "unit" }
local INDEX_ATTRS = { "SlotIndex", "Index", "Slot" }

local function finite(x: any): boolean
	return type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge
end

local function marked(inst: Instance, name: string): boolean
	return inst.Name == name or inst:GetAttribute(name) ~= nil or inst:HasTag(name)
end

function Markers.containerKind(inst: Instance): string?
	for _, kind in ORDER do
		if marked(inst, Markers.CONTAINERS[kind]) then
			return kind
		end
	end
	return nil
end

function Markers.containerOf(inst: Instance): (Instance?, string?)
	local node: Instance? = inst
	while node and node ~= game do
		local kind = Markers.containerKind(node)
		if kind then
			return node, kind
		end
		node = node.Parent
	end
	return nil, nil
end

function Markers.position(inst: Instance): Vector3
	if inst:IsA("BasePart") then
		return inst.CFrame.Position
	end
	if inst:IsA("Model") and inst.PrimaryPart then
		return inst.PrimaryPart.CFrame.Position
	end
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") then
			return d.CFrame.Position
		end
	end
	return Vector3.zero
end

-- The container's own frame: the part itself, the model's PrimaryPart, else its first part (every clone of a
-- template lists its descendants in the same order, so the same part is picked in every copy).
function Markers.refCFrame(container: Instance): CFrame
	if container:IsA("BasePart") then
		return container.CFrame
	end
	if container:IsA("Model") and container.PrimaryPart then
		return container.PrimaryPart.CFrame
	end
	for _, d in container:GetDescendants() do
		if d:IsA("BasePart") then
			return d.CFrame
		end
	end
	return CFrame.identity
end

local function indexOf(inst: Instance, own: string?): number?
	if own then
		local v = inst:GetAttribute(own)
		if finite(v) then
			return v :: number
		end
	end
	for _, attr in INDEX_ATTRS do
		local v = inst:GetAttribute(attr)
		if finite(v) then
			return v :: number
		end
	end
	local n = string.match(inst.Name, "(%d+)$")
	return if n then tonumber(n) else nil
end

local function round(x: number): number
	return math.floor(x * 10 + 0.5) / 10
end

function Markers.containers(root: Instance, kind: string): { Instance }
	local name = Markers.CONTAINERS[kind]
	if name == nil then
		return {}
	end
	local out: { Instance } = {}
	for _, d in root:GetDescendants() do
		if marked(d, name) then
			-- only the outermost marker of a container counts
			local parent = d.Parent
			local nested = false
			while parent and parent ~= root do
				if marked(parent, name) then
					nested = true
					break
				end
				parent = parent.Parent
			end
			if not nested then
				table.insert(out, d)
			end
		end
	end
	local keys: { [Instance]: { number } } = {}
	for _, d in out do
		local p = Markers.position(d)
		keys[d] = { indexOf(d, name) or math.huge, round(p.X), round(p.Z), round(p.Y) }
	end
	table.sort(out, function(a, b)
		local ka, kb = keys[a], keys[b]
		for i = 1, 4 do
			if ka[i] ~= kb[i] then
				return ka[i] < kb[i]
			end
		end
		return a.Name < b.Name
	end)
	return out
end

function Markers.unitKind(container: Instance): string?
	for _, attr in { "UnitKind", "Context" } do
		local v = container:GetAttribute(attr)
		if v == "dorm" or v == "apartment" then
			return v
		end
	end
	local zone = World.zoneAt(Markers.position(container))
	if zone == "dorm" then
		return "dorm"
	elseif zone == "apartments" then
		return "apartment"
	end
	return nil
end

-- True when inst's nearest container is `container` (DecorSlots of a nested container belong to that one).
local function ownedBy(inst: Instance, container: Instance): boolean
	local node = inst.Parent
	while node and node ~= container do
		if Markers.containerKind(node) then
			return false
		end
		node = node.Parent
	end
	return node == container
end

local function limitsOf(part: BasePart): Limits?
	local w, h, d = part:GetAttribute("MaxWidth"), part:GetAttribute("MaxHeight"), part:GetAttribute("MaxDepth")
	if not (finite(w) or finite(h) or finite(d)) then
		return nil
	end
	return {
		width = if finite(w) then w :: number else nil,
		height = if finite(h) then h :: number else nil,
		depth = if finite(d) then d :: number else nil,
	}
end

local function validId(x: any): boolean
	return type(x) == "string" and #x > 0 and #x <= 64 and string.find(x, "^[%w_%-:]+$") ~= nil
end

function Markers.slots(container: Instance): { Slot }
	local ref = Markers.refCFrame(container)
	local byKind: { [string]: { { part: BasePart, key: { number }, explicit: string? } } } = {}
	for _, d in container:GetDescendants() do
		if d:IsA("BasePart") and marked(d, Markers.DECOR_SLOT) and ownedBy(d, container) then
			local kind = d:GetAttribute("SlotKind")
			if type(kind) == "string" and Decor.ACCEPTS[kind] ~= nil then
				local list = byKind[kind]
				if not list then
					list = {}
					byKind[kind] = list
				end
				local lp = ref:PointToObjectSpace(d.CFrame.Position)
				local explicit = d:GetAttribute("SlotId")
				table.insert(list, {
					part = d,
					key = { indexOf(d, nil) or math.huge, round(lp.X), round(lp.Z), round(lp.Y) },
					explicit = if validId(explicit) then explicit :: string else nil,
				})
			end
		end
	end
	local out: { Slot } = {}
	local used: { [string]: boolean } = {}
	for _, kind in Decor.SLOT_KINDS do
		local list = byKind[kind]
		if list then
			table.sort(list, function(a, b)
				for i = 1, 4 do
					if a.key[i] ~= b.key[i] then
						return a.key[i] < b.key[i]
					end
				end
				return a.part.Name < b.part.Name
			end)
			for i, entry in list do
				local id = entry.explicit or (kind .. "_" .. i)
				local n = 2
				local base = id
				while used[id] do
					id = base .. "_" .. n
					n += 1
				end
				used[id] = true
				table.insert(out, { id = id, kind = kind, part = entry.part, limits = limitsOf(entry.part) })
			end
		end
	end
	return out
end

function Markers.nameplates(container: Instance): { Instance }
	local out: { Instance } = {}
	for _, d in container:GetDescendants() do
		if (d.Name == Markers.NAMEPLATE or d:HasTag(Markers.NAMEPLATE)) and ownedBy(d, container) then
			-- skip a nameplate nested inside another nameplate (a model and its part)
			local inner = false
			local node = d.Parent
			while node and node ~= container do
				if node.Name == Markers.NAMEPLATE or node:HasTag(Markers.NAMEPLATE) then
					inner = true
					break
				end
				node = node.Parent
			end
			if not inner then
				table.insert(out, d)
			end
		end
	end
	return out
end

function Markers.themeParts(container: Instance): ({ BasePart }, { BasePart })
	local walls: { BasePart } = {}
	local floors: { BasePart } = {}
	for _, d in container:GetDescendants() do
		if d:IsA("BasePart") and ownedBy(d, container) then
			local attr = d:GetAttribute("Theme")
			if d:HasTag(Markers.THEME_WALL) or attr == "wall" then
				table.insert(walls, d)
			elseif d:HasTag(Markers.THEME_FLOOR) or attr == "floor" then
				table.insert(floors, d)
			end
		end
	end
	return walls, floors
end

-- Props cf conventions (Assets/Props): floor/desk = the contact point on the surface; wall = bottom-centre of the
-- back face. The marker's front (-Z) faces the room, so the prop faces the same way.
function Markers.mountCFrame(part: BasePart, mount: string): CFrame
	local size = part.Size
	if mount == "wall" then
		return part.CFrame * CFrame.new(0, -size.Y / 2, size.Z / 2)
	end
	return part.CFrame * CFrame.new(0, -size.Y / 2, 0)
end

return Markers
