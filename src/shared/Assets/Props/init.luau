--!strict
-- Props: reusable 3D props built entirely from Parts, built-in materials and SurfaceGuis. Bake-safe
-- (contracts §13), so world builders call it at bake time and housing calls it at runtime.
--
--   Props.build(id, parent, cf, opts?) -> Model
--       cf = the prop's floor contact point (see mount below); the prop faces cf.LookVector (front = -Z).
--       Every model has PrimaryPart "Root" (invisible, non-colliding, at cf), attributes PropId,
--       PropCategory, PropMount, tag "Prop", an Attachment "Use" under Root (where a ProximityPrompt
--       belongs) and only anchored parts. Unknown ids raise an error (use Props.has or Props.tryBuild).
--   Props.tryBuild(id, parent, cf, opts?) -> (Model?, string?)   never throws
--   Props.list() -> { {id, category, footprint, maxParts, tags, mount, surface?, offset?, scales?, maxOpts?} }
--       footprint = approximate X/Y/Z size of the default build; offset = local centre of that box when the
--       prop is deliberately off-centre (default zero); surface = usable top height; scales = option names
--       that change the size (maxOpts maps each to its largest value, which maxParts covers).
--   Props.has(id) -> boolean,  Props.get(id) -> Info?,  Props.ids(category?) -> {string}
--
-- Common opts: color (main colour), accent, variant (number or string), seed, lit (lamps, screens),
-- text (nameplates, signs), tier (1-4 quality ladder), seat (true = real Seat parts players can sit on).
-- Mounts: "floor" | "desk" (cf on the table top) | "wall" (cf = bottom-centre of the back face) |
-- "ceiling" (cf = lowest point; the fixture rises footprint.Y to the ceiling).

local Common = require(script.Common)
local Rng = require(script.Parent.Parent.Util.Rng)
local Hash = require(script.Parent.Parent.Util.Hash)

export type Opts = Common.Opts
export type Info = {
	id: string,
	category: string,
	footprint: Vector3,
	maxParts: number,
	tags: { string },
	mount: string,
	surface: number?,
	offset: Vector3?,
	scales: { string }?,
	maxOpts: { [string]: any }?,
}

local Props = {}

local CATEGORIES: { { Common.Def } } = {
	require(script.Office),
	require(script.Decor),
	require(script.Campus),
	require(script.Street),
	require(script.Vehicles),
	require(script.Lux),
	require(script.Retail),
}

local defs: { [string]: Common.Def } = {}
local order: { Common.Def } = {}
for _, list in CATEGORIES do
	for _, def in list do
		assert(defs[def.id] == nil, "Props: duplicate prop id " .. def.id)
		defs[def.id] = def
		table.insert(order, def)
	end
end

local INHERITED = { "seat", "lit" }

local function seedFor(id: string, cf: CFrame, o: Opts): number
	local s = o.seed
	if type(s) == "number" and s == s then
		return Hash.u32("prop", id, s)
	elseif type(s) == "string" then
		return Hash.u32("prop", id, s)
	end
	-- No seed: vary by placement so neighbouring copies differ, but stay identical across bakes.
	local p = cf.Position
	return Hash.u32("prop", id, math.floor(p.X * 4 + 0.5), math.floor(p.Y * 4 + 0.5), math.floor(p.Z * 4 + 0.5))
end

-- Where the "Use" attachment goes when a builder doesn't pick a spot: just in front of the prop's front
-- face (never inside its collidable body, where a line-of-sight ProximityPrompt would be blocked).
local function defaultUse(def: Common.Def): Vector3
	local fp = def.footprint
	local off = def.offset or Vector3.zero
	local mount = def.mount or "floor"
	if mount == "wall" then
		return Vector3.new(off.X, math.clamp(fp.Y * 0.5, 0.5, 4), -fp.Z - 0.5)
	elseif mount == "ceiling" then
		return Vector3.new(off.X, -0.5, off.Z)
	end
	local gap = if mount == "desk" then 0.2 else 0.5
	return Vector3.new(off.X, math.clamp(fp.Y * 0.6, 0.3, 4), off.Z - fp.Z / 2 - gap)
end

local subBuild: Common.SubBuilder
subBuild = function(pc: Common.Ctx, subId: string, lcf: CFrame, subOpts: Opts?): Model
	local def = defs[subId]
	assert(def ~= nil, "Props: unknown sub-prop " .. subId)
	local o: Opts = if subOpts then table.clone(subOpts) else {}
	for _, k in INHERITED do
		if o[k] == nil then
			o[k] = pc.o[k]
		end
	end
	local sm = Instance.new("Model")
	sm.Name = subId
	sm:SetAttribute("SubProp", subId)
	local rng = Rng.new(Hash.u32("sub", subId, pc.rng:int(0, 2147483646)))
	local c = Common.ctx(sm, pc.cf * lcf, o, rng, subId, subBuild)
	def.build(c)
	sm.Parent = pc.m
	return sm
end

function Props.build(id: string, parent: Instance?, cf: CFrame, opts: Opts?): Model
	local def = if type(id) == "string" then defs[id] else nil
	if def == nil then
		error(string.format("Props.build: unknown prop id '%s'", tostring(id)), 2)
	end
	local o: Opts = if type(opts) == "table" then opts else {}
	local model, root = Common.shell(Common.optStr(o, "name", id, 60), cf)
	model:SetAttribute("PropId", id)
	model:SetAttribute("PropCategory", def.category)
	model:SetAttribute("PropMount", def.mount or "floor")
	model:AddTag("Prop")
	local c = Common.ctx(model, cf, o, Rng.new(seedFor(id, cf, o)), id, subBuild)
	def.build(c)
	Common.useAttachment(root, c.usePos or defaultUse(def))
	if parent then
		model.Parent = parent
	end
	return model
end

function Props.tryBuild(id: string, parent: Instance?, cf: CFrame, opts: Opts?): (Model?, string?)
	if type(id) ~= "string" or defs[id] == nil then
		return nil, "unknown prop id " .. tostring(id)
	end
	local ok, result = pcall(Props.build, id, parent, cf, opts)
	if ok then
		return result, nil
	end
	return nil, tostring(result)
end

local function info(d: Common.Def): Info
	local scaleNames: { string }? = nil
	if d.scales then
		local names = {}
		for k in d.scales do
			table.insert(names, k)
		end
		table.sort(names)
		scaleNames = names
	end
	return {
		id = d.id,
		category = d.category,
		footprint = d.footprint,
		maxParts = d.maxParts,
		tags = table.clone(d.tags),
		mount = d.mount or "floor",
		surface = d.surface,
		offset = d.offset,
		scales = scaleNames,
		maxOpts = if d.scales then table.clone(d.scales) else nil,
	}
end

function Props.list(): { Info }
	local out = {}
	for _, d in order do
		table.insert(out, info(d))
	end
	return out
end

function Props.has(id: any): boolean
	return type(id) == "string" and defs[id] ~= nil
end

function Props.get(id: string): Info?
	local d = defs[id]
	return if d then info(d) else nil
end

function Props.ids(category: string?): { string }
	local out = {}
	for _, d in order do
		if category == nil or d.category == category then
			table.insert(out, d.id)
		end
	end
	return out
end

return Props
