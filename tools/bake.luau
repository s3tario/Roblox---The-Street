-- Bakes every world builder listed in Config/World.builders into build/World.rbxm.
--   lune run tools/bake            -- bake all builders
--   lune run tools/bake Street HQ  -- bake only these (others are skipped; output still written)
-- Fails (exit 1) if a builder errors, exceeds its part budget, or places parts outside its zones.

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local V = require("./lib/vrequire")

V.init("default.project.json")

local World = V.requirePath("ReplicatedStorage/Shared/Config/World")

local only: { [string]: boolean } = {}
for _, a in process.args do
	only[a] = true
end
local filtered = next(only) ~= nil

local worldFolder = roblox.Instance.new("Folder")
worldFolder.Name = "World"

local MARGIN = 2
local function zoneBox(zoneId: string): (any, any)
	local r = World.regions[zoneId]
	if r then
		return r.min, r.max
	end
	return World.interiorBounds(zoneId)
end

local function inAnyZone(pos: any, zones: { string }): boolean
	for _, z in zones do
		local mn, mx = zoneBox(z)
		if
			pos.X >= mn.X - MARGIN
			and pos.X <= mx.X + MARGIN
			and pos.Y >= mn.Y - MARGIN
			and pos.Y <= mx.Y + MARGIN
			and pos.Z >= mn.Z - MARGIN
			and pos.Z <= mx.Z + MARGIN
		then
			return true
		end
	end
	return false
end

local problems = 0
local total = 0
local builders = V.resolve("ServerStorage/WorldBuilders")

for _, entry in World.builders do
	if filtered and not only[entry.module] then
		continue
	end
	local moduleProxy = builders:FindFirstChild(entry.module)
	if not moduleProxy then
		print(("SKIP  %-16s (src/world/%s.luau not written yet)"):format(entry.module, entry.module))
		continue
	end
	local t0 = os.clock()
	local ok, result = pcall(function()
		local builder = V.require(moduleProxy)
		assert(type(builder) == "table" and type(builder.build) == "function", "builder must export build(parent)")
		return builder.build(worldFolder)
	end)
	if not ok then
		problems += 1
		print(("FAIL  %-16s error: %s"):format(entry.module, tostring(result)))
		continue
	end
	if typeof(result) ~= "Instance" then
		problems += 1
		print(("FAIL  %-16s build() must return the Model it created"):format(entry.module))
		continue
	end
	result.Name = entry.module
	local parts, outside = 0, 0
	local firstOutside = nil
	for _, d in result:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
			local pos = d.Position
			if not inAnyZone(pos, entry.zones) then
				outside += 1
				firstOutside = firstOutside or (d:GetFullName() .. " @ " .. tostring(pos))
			end
		end
	end
	total += parts
	local status = "OK  "
	local note = ""
	if parts > entry.budget then
		status = "FAIL"
		problems += 1
		note = (" over budget (%d > %d)"):format(parts, entry.budget)
	end
	if outside > 0 then
		status = "FAIL"
		problems += 1
		note ..= (" %d parts outside zones, e.g. %s"):format(outside, tostring(firstOutside))
	end
	print(("%s  %-16s %6d parts  %5.2fs%s"):format(status, entry.module, parts, os.clock() - t0, note))
end

-- Office floor templates -> build/Templates.rbxm (ServerStorage.FirmTemplates). Each template is built at the
-- origin and must stay within +/- TEMPLATE_HALF (XZ) and y in [-10, TEMPLATE_HEIGHT].
local templatesFolder = roblox.Instance.new("Folder")
templatesFolder.Name = "FirmTemplates"
local H = World.TEMPLATE_HALF
local TH = World.TEMPLATE_HEIGHT
for _, entry in World.templates do
	if filtered and not only[entry.module] then
		continue
	end
	local moduleProxy = builders:FindFirstChild(entry.module)
	if not moduleProxy then
		print(("SKIP  %-16s (src/world/%s.luau not written yet)"):format(entry.module, entry.module))
		continue
	end
	for _, templateId in entry.templates do
		local t0 = os.clock()
		local ok, result = pcall(function()
			local builder = V.require(moduleProxy)
			assert(
				type(builder) == "table" and type(builder.build) == "function",
				"builder must export build(templateId, parent)"
			)
			return builder.build(templateId, templatesFolder)
		end)
		local label = entry.module .. ":" .. templateId
		if not ok or typeof(result) ~= "Instance" then
			problems += 1
			print(("FAIL  %-22s error: %s"):format(label, tostring(result)))
			continue
		end
		result.Name = templateId
		local parts, outside = 0, 0
		local firstOutside = nil
		for _, d in result:GetDescendants() do
			if d:IsA("BasePart") then
				parts += 1
				local p = d.Position
				if
					math.abs(p.X) > H + MARGIN
					or math.abs(p.Z) > H + MARGIN
					or p.Y < -10 - MARGIN
					or p.Y > TH + MARGIN
				then
					outside += 1
					firstOutside = firstOutside or (d:GetFullName() .. " @ " .. tostring(p))
				end
			end
		end
		total += parts
		local status, note = "OK  ", ""
		if parts > entry.budget then
			status = "FAIL"
			problems += 1
			note = (" over budget (%d > %d)"):format(parts, entry.budget)
		end
		if outside > 0 then
			status = "FAIL"
			problems += 1
			note ..= (" %d parts outside template bounds, e.g. %s"):format(outside, tostring(firstOutside))
		end
		print(("%s  %-22s %6d parts  %5.2fs%s"):format(status, label, parts, os.clock() - t0, note))
	end
end
local templatesOut = if filtered
	then "build/bake-templates-" .. table.concat(process.args, "-") .. ".rbxm"
	else "build/Templates.rbxm"
fs.writeDir("build")
fs.writeFile(templatesOut, roblox.serializeModel({ templatesFolder }))

-- A filtered bake never overwrites the full World.rbxm (concurrent agents bake their own modules).
local outPath = if filtered then "build/bake-" .. table.concat(process.args, "-") .. ".rbxm" else "build/World.rbxm"
fs.writeDir("build")
fs.writeFile(outPath, roblox.serializeModel({ worldFolder }))
print(("\nWrote %s with %d parts"):format(outPath, total))
if problems > 0 then
	print(("%d problem(s)"):format(problems))
	process.exit(1)
end
