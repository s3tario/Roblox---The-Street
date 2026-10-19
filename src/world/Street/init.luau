--!strict
local Deps = require(script.Deps)
local Plan = require(script.Plan)
local Ground = require(script.Ground)
local Towers = require(script.Towers)
local Exchange = require(script.Exchange)
local Plaza = require(script.Plaza)
local Venues = require(script.Venues)
local Fillers = require(script.Fillers)
local Backdrop = require(script.Backdrop)
local Life = require(script.Life)

local Kit = Deps.Kit

local Street = {}

-- Lune's DOM stores Position separately from CFrame (with no default), so tools reading part.Position (the bake's
-- zone check, tests) fail on parts that only had a CFrame. Writing Position = CFrame.Position is a no-op in Roblox
-- and the binary .rbxm writer keeps only CFrame.
local function settle(root: Instance)
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			d.Position = d.CFrame.Position
		end
	end
end

-- Draw distance for every sign and screen that didn't choose one: a SurfaceGui stops rendering beyond MaxDistance,
-- so the ~400 boards, plaques and shop signs cost nothing from across the district, while big faces (fascias,
-- crown logos, billboards) stay readable down the avenues.
local GUI_MIN, GUI_MAX, GUI_PER_STUD = 150, 1200, 35

local function faceSpan(part: BasePart, face: Enum.NormalId): number
	local s = part.Size
	if face == Enum.NormalId.Front or face == Enum.NormalId.Back then
		return math.max(s.X, s.Y)
	elseif face == Enum.NormalId.Left or face == Enum.NormalId.Right then
		return math.max(s.Z, s.Y)
	end
	return math.max(s.X, s.Z)
end

local function cullGuis(root: Instance)
	for _, d in root:GetDescendants() do
		if d:IsA("SurfaceGui") and d.MaxDistance <= 0 then
			local part = d.Parent
			if part and part:IsA("BasePart") then
				d.MaxDistance = math.clamp(faceSpan(part, d.Face) * GUI_PER_STUD, GUI_MIN, GUI_MAX)
			end
		end
	end
end

function Street.build(parent: Instance): Model
	local model = Kit.model(parent, "Street")
	local rects = Plan.rects(Deps.World.towers)
	Ground.build(model)
	Towers.build(model, rects)
	Exchange.build(model, rects)
	Plaza.build(model)
	Venues.build(model, rects)
	Fillers.build(model, rects)
	Backdrop.build(model, rects)
	Life.build(model)
	cullGuis(model)
	settle(model)
	return model
end

return Street
