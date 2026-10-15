--!strict
-- SettingsService (server): validates and saves player settings (data.settings, owned by `ui`).
--   Remote "Settings.Set"(key, value)   key whitelisted in SCHEMA, value checked with Guard
--   Remote "Settings.Reset"()           back to the template defaults
--   SettingsService:Get(player) -> settings (defaults filled in)
--   SettingsService:Set(player, key, value) -> boolean
--   SettingsService.validate(key, value) -> (key?, value?)   pure (unit-tested)
-- Saved through DataService (autosave) and replicated with DataService:Replicate(player, "settings").

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Guard = require(Shared.Guard)
local TableUtil = require(Shared.Util.TableUtil)
local SettingsDefaults = require(Shared.Config.DataTemplate.Settings)
local Registry = require(script.Parent.Parent.Registry)

export type Spec = { kind: "number", min: number, max: number, step: number } | { kind: "boolean" }

local SettingsService = { Name = "SettingsService" }

SettingsService.SCHEMA = {
	music = { kind = "number", min = 0, max = 1, step = 0.01 },
	sfx = { kind = "number", min = 0, max = 1, step = 0.01 },
	uiScale = { kind = "number", min = 0.8, max = 1.2, step = 0.01 },
	reducedMotion = { kind = "boolean" },
	showTicker = { kind = "boolean" },
} :: { [string]: Spec }

SettingsService.DEFAULTS = SettingsDefaults.settings

-- Returns the whitelisted key and the cleaned value, or nil when the pair is invalid.
function SettingsService.validate(key: any, value: any): (string?, any)
	local k = Guard.oneOf(Guard.id(key), SettingsService.SCHEMA)
	if k == nil then
		return nil, nil
	end
	local spec = SettingsService.SCHEMA[k :: string]
	if spec.kind == "boolean" then
		local b = Guard.bool(value)
		if b == nil then
			return nil, nil
		end
		return k, b
	end
	local num = spec :: { kind: "number", min: number, max: number, step: number }
	-- A hair of tolerance for float noise from client-side stepping (e.g. 0.8 + 8 * 0.05).
	local n = Guard.num(value, num.min - 1e-6, num.max + 1e-6)
	if n == nil then
		return nil, nil
	end
	-- Round to the step (and to 2 decimals so float noise never reaches the save).
	local stepped = math.floor(n / num.step + 0.5) * num.step
	stepped = math.clamp(math.floor(stepped * 100 + 0.5) / 100, num.min, num.max)
	return k, stepped
end

local function dataService(): any
	return Registry.get("DataService")
end

function SettingsService:Get(player: Player): { [string]: any }
	local out = TableUtil.deepCopy(SettingsService.DEFAULTS)
	local ds = dataService()
	local data = ds and ds:Get(player)
	if type(data) == "table" and type(data.settings) == "table" then
		for k, v in data.settings do
			if SettingsService.SCHEMA[k] and type(v) == type(out[k]) then
				out[k] = v
			end
		end
	end
	return out
end

function SettingsService:Set(player: Player, key: string, value: any): boolean
	local k, v = SettingsService.validate(key, value)
	if k == nil then
		return false
	end
	local ds = dataService()
	if ds == nil then
		return false
	end
	local data = ds:Get(player)
	if type(data) ~= "table" then
		return false
	end
	local s = data.settings
	if type(s) ~= "table" then
		s = TableUtil.deepCopy(SettingsService.DEFAULTS)
		data.settings = s
	end
	if s[k] == v then
		return true
	end
	s[k] = v
	ds:Replicate(player, "settings")
	return true
end

function SettingsService:Reset(player: Player): boolean
	local ds = dataService()
	local data = ds and ds:Get(player)
	if type(data) ~= "table" then
		return false
	end
	data.settings = TableUtil.deepCopy(SettingsService.DEFAULTS)
	ds:Replicate(player, "settings")
	return true
end

function SettingsService:Init()
	-- Net is required lazily so this module (and its pure validate) also loads under Lune.
	local Net = require(Shared.Net)
	Net.on("Settings.Set", function(player: Player, key: any, value: any)
		local k, v = SettingsService.validate(key, value)
		if k == nil then
			return
		end
		SettingsService:Set(player, k, v)
	end, { rate = 6, burst = 12 })
	Net.on("Settings.Reset", function(player: Player)
		SettingsService:Reset(player)
	end, { rate = 0.5, burst = 2 })
end

return SettingsService
