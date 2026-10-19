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
	settle(model)
	return model
end

return Street
