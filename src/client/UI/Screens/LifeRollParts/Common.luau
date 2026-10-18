--!strict
-- LifeRollParts/Common: helpers shared by the LifeRoll and Stats screens and the StatCard (client UI, careerCore).
-- Safe to require under Lune: services are only touched inside Roblox (Kit.Core.LIVE).
--
--   Common.LIVE                                  true inside Roblox
--   Common.rarityColor(id) -> Color3             Common.rarityName(id) -> string
--   Common.ovrColor(ovr) -> Color3, rarityId     sports-card tier colour for an Overall rating
--   Common.prismatic(gui, speed?) -> stop()      animated Mythic gradient (static under Lune / reduced motion)
--   Common.animate(duration, step(alpha), done?) -> cancel()   per-frame animation (instant under Lune)
--   Common.fieldTitle(field) -> string           Common.valueText(field, value) -> string
--   Common.boostText(field, value) -> string     "+5 Knowledge, +5 Skill" for schools, clubs, degree, family
--   Common.reelFiller(field, n, seed) -> { {text, rarity?} }   names that scroll past before the reel lands
--   Common.api(ctx) -> CareerCoreController-like table (stub that always fails when the controller is missing)
--   Common.landSound(rarity) -> Sfx cue name

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config.LifeRoll)
local Rarity = require(Shared.Config.Rarity)
local Catalog = require(Shared.Config.Catalog)
local LifeRoll = require(Shared.Logic.LifeRoll)
local Hash = require(Shared.Util.Hash)
local Kit = require(script.Parent.Parent.Parent:WaitForChild("Kit"))

local Common = {}

Common.LIVE = Kit.Core.LIVE

function Common.rarityColor(id: any): Color3
	return Rarity.color(id)
end

function Common.rarityName(id: any): string
	return Rarity.name(id)
end

-- <50 grey, 50s green, 60s blue, 70s purple, 80s gold, 90+ prismatic (the first prismatic colour).
function Common.ovrColor(ovr: number): (Color3, string)
	local id = if ovr >= 90
		then "mythic"
		elseif ovr >= 80 then "legendary"
		elseif ovr >= 70 then "epic"
		elseif ovr >= 60 then "rare"
		elseif ovr >= 50 then "uncommon"
		else "common"
	return Rarity.color(id), id
end

---------------------------------------------------------------------------------------------------
-- Animation
---------------------------------------------------------------------------------------------------
local runService: RunService? = nil
local function frameSignal(): RBXScriptSignal?
	if not Common.LIVE then
		return nil
	end
	if runService == nil then
		local ok, rs = pcall(function()
			return game:GetService("RunService")
		end)
		if ok then
			runService = rs
		end
	end
	return if runService then runService.RenderStepped else nil
end

function Common.animate(duration: number, step: (alpha: number) -> (), done: (() -> ())?): () -> ()
	local signal = frameSignal()
	if signal == nil or duration <= 0 or Kit.reducedMotion() then
		step(1)
		if done then
			done()
		end
		return function() end
	end
	local start = os.clock()
	local conn: RBXScriptConnection? = nil
	local finished = false
	conn = signal:Connect(function()
		local a = math.clamp((os.clock() - start) / duration, 0, 1)
		local ok, err = pcall(function()
			step(a)
		end)
		if not ok then
			warn("[LifeRoll] animation step failed: " .. tostring(err))
			a = 1
		end
		if a >= 1 and not finished then
			finished = true
			if conn then
				conn:Disconnect()
			end
			if done then
				done()
			end
		end
	end)
	return function()
		if conn then
			conn:Disconnect()
		end
		finished = true
	end
end

local function prismaticSequence(): ColorSequence
	local list = Rarity.PRISMATIC
	local keys: { ColorSequenceKeypoint } = {}
	for i, c in list do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#list - 1), c))
	end
	return ColorSequence.new(keys)
end

-- Puts an animated prismatic UIGradient on `gui` (a TextLabel's text, a Frame's fill, or a UIStroke).
function Common.prismatic(gui: Instance, speed: number?): () -> ()
	local grad = Instance.new("UIGradient")
	grad.Name = "Prismatic"
	grad.Color = prismaticSequence()
	grad.Rotation = 20
	grad.Parent = gui
	local signal = frameSignal()
	if signal == nil or Kit.reducedMotion() then
		return function()
			grad:Destroy()
		end
	end
	local rate = speed or 90
	local conn = signal:Connect(function(dt: number)
		grad.Rotation = (grad.Rotation + dt * rate) % 360
	end)
	return function()
		conn:Disconnect()
		grad:Destroy()
	end
end

---------------------------------------------------------------------------------------------------
-- Text
---------------------------------------------------------------------------------------------------
function Common.fieldTitle(field: string): string
	return Config.text("field_" .. field)
end

function Common.valueText(field: string, value: any): string
	if field == "degree" then
		local def = Config.degree(value)
		return if def then def.long else ""
	elseif field == "family" then
		local name = LifeRoll.describe(field, value)
		return if name ~= "" then Config.text("family_line", { family = name }) else ""
	elseif field == "clubs" then
		local text = LifeRoll.describe(field, value)
		return if text ~= "" then text else Config.text("clubs_none")
	elseif field == "stats" then
		if type(value) ~= "table" then
			return ""
		end
		local total = tonumber(LifeRoll.describe(field, value)) or 0
		return Config.text("stats_total", { total = total, ovr = math.floor(total / #Config.STAT_IDS + 0.5) })
	elseif field == "outfit" then
		if type(value) ~= "table" then
			return ""
		end
		local brand = Catalog.brand(value.brand)
		local name = tostring(value.name or "")
		return if brand and not string.find(name, brand.name, 1, true) then brand.name .. " · " .. name else name
	end
	return LifeRoll.describe(field, value)
end

function Common.boostText(field: string, value: any): string
	local fields: { [string]: any } = {}
	if field == "school" or field == "family" then
		fields[field] = value
	elseif field == "clubs" then
		fields.clubs = value
	elseif field == "degree" then
		fields.degree = value
	else
		return ""
	end
	local parts: { string } = {}
	for _, b in LifeRoll.boostSources(fields) do
		local def = Config.stat(b.stat)
		table.insert(parts, Config.text("boost_line", { n = b.amount, stat = if def then def.name else b.stat }))
	end
	return table.concat(parts, ", ")
end

---------------------------------------------------------------------------------------------------
-- Reel filler: plausible values scrolling past (deterministic, so it also works under Lune)
---------------------------------------------------------------------------------------------------
local function poolNames(field: string): { { text: string, rarity: string? } }
	local out: { { text: string, rarity: string? } } = {}
	if field == "school" then
		for _, d in Config.schools do
			table.insert(out, { text = d.name, rarity = d.rarity })
		end
	elseif field == "family" then
		for _, d in Config.families do
			table.insert(out, { text = Config.text("family_line", { family = d.name }), rarity = d.rarity })
		end
	elseif field == "clubs" then
		for _, d in Config.clubs do
			table.insert(out, { text = d.name, rarity = d.rarity })
		end
	elseif field == "degree" then
		for _, d in Config.degrees do
			table.insert(out, { text = d.long, rarity = d.rarity })
		end
	elseif field == "outfit" then
		for _, r in Rarity.ids do
			local pool: { Catalog.Look } = Catalog.rollPools[r] or {}
			for _, look in pool do
				table.insert(out, { text = look.name, rarity = r })
			end
		end
	end
	return out
end

function Common.reelFiller(field: string, n: number, seed: any): { { text: string, rarity: string? } }
	local pool = poolNames(field)
	local out: { { text: string, rarity: string? } } = {}
	for i = 1, n do
		local u = Hash.unit("reel", field, seed, i)
		if field == "gpa" then
			table.insert(out, { text = string.format("%.2f", LifeRoll.gpaFromUnit(u)) })
		elseif field == "stats" then
			local total = 304 + math.floor(u * 33)
			table.insert(out, {
				text = Config.text("stats_total", { total = total, ovr = math.floor(total / 8 + 0.5) }),
			})
		elseif #pool > 0 then
			table.insert(out, pool[math.floor(u * #pool) + 1])
		end
	end
	return out
end

function Common.landSound(rarity: string?): string
	if rarity == "mythic" then
		return "promotion"
	elseif rarity == "legendary" then
		return "levelup"
	elseif rarity == "epic" then
		return "chime"
	elseif rarity == "rare" or rarity == "uncommon" then
		return "good"
	end
	return "click"
end

---------------------------------------------------------------------------------------------------
-- Controller access
---------------------------------------------------------------------------------------------------
local function fail(): (boolean, string?, any)
	return false, "generic", nil
end

local STUB = {
	GetProfile = function(_self: any): any
		return nil
	end,
	PublicView = function(_self: any, profile: any): any
		return LifeRoll.publicView(profile)
	end,
	SetName = fail,
	Reroll = fail,
	Lock = fail,
	SetFocus = fail,
	Rebuild = fail,
	FetchState = fail,
	BuyReroll = function() end,
	OpenStats = function() end,
	OpenLifeRoll = function() end,
	Changed = nil,
}

function Common.api(ctx: any): any
	local registry = if type(ctx) == "table" then ctx.Registry else nil
	if type(registry) == "table" then
		local ok, controller = pcall(function()
			return registry.get("CareerCoreController")
		end)
		if ok and type(controller) == "table" then
			return controller
		end
	end
	return STUB
end

return Common
