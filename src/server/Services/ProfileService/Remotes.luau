--!strict
-- ProfileService remotes (RUNTIME ONLY, server). Every argument is validated with Shared/Guard here; the service
-- methods then apply the rules. RemoteFunctions answer (ok: boolean, errKey: string?, payload: any?); errKey is a
-- Config/LifeRoll "err_<key>" suffix.
--
--   Profile.Get()                        -> true, nil, { profile, rebirths }
--   Profile.SetName(name)                -> ok, err, { name, fallback, pending, rerollsLeft }
--   Profile.RerollField(field)           -> ok, err, { field, value, source, rerollsLeft, refreshTokens, credits }
--                                           err "needs_purchase" when no free reroll, token or credit is left
--   Profile.Lock()                       -> ok, err
--   Profile.SetFocus(focusId)            -> ok, err
--   Profile.Rebuild({school?, family?, clubs? = {[i] = id}})   -> ok, err (spends a Background Rebuild credit)
--   Profile.GetPublic(player)            -> true, nil, PublicProfile   (any player in this server)
--   Profile.Open (server -> client)      args = { source }   opens the Life Roll screen

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Guard = require(Shared.Guard)
local Config = require(Shared.Config.LifeRoll)

local Remotes = {}

Remotes.OPEN = "Profile.Open"

-- Rebuild edits: { school = id?, family = id?, clubs = { [index] = id }? } with string or number club indices.
local function cleanEdits(raw: any): { [string]: any }?
	local t = Guard.map(raw, 12, 2)
	if not t then
		return nil
	end
	local out: { [string]: any } = {}
	if t.school ~= nil then
		out.school = Guard.id(t.school)
		if not out.school then
			return nil
		end
	end
	if t.family ~= nil then
		out.family = Guard.id(t.family)
		if not out.family then
			return nil
		end
	end
	if t.clubs ~= nil then
		if type(t.clubs) ~= "table" then
			return nil
		end
		local clubs: { [number]: string } = {}
		for k, v in t.clubs do
			local i = Guard.int(tonumber(k), 1, #Config.rules.clubCountOdds)
			local id = Guard.id(v)
			if not i or not id then
				return nil
			end
			clubs[i] = id
		end
		out.clubs = clubs
	end
	return out
end

function Remotes.bind(svc: any)
	Net.declare(Remotes.OPEN)

	Net.handle("Profile.Get", function(player: Player)
		return svc:RemoteGet(player)
	end, { rate = 2, burst = 6 })

	Net.handle("Profile.SetName", function(player: Player, name: any)
		local s = Guard.str(name, 64)
		if not s then
			return false, "bad_name"
		end
		return svc:SetName(player, s)
	end, { rate = 0.5, burst = 3 })

	Net.handle("Profile.RerollField", function(player: Player, field: any)
		local f = Guard.oneOf(field, Config.FIELD_SET)
		if type(f) ~= "string" then
			return false, "bad_field"
		end
		return svc:RerollField(player, f)
	end, { rate = 1.5, burst = 4 })

	Net.handle("Profile.Lock", function(player: Player)
		return svc:Lock(player)
	end, { rate = 0.5, burst = 2 })

	Net.handle("Profile.SetFocus", function(player: Player, focusId: any)
		local id = Guard.id(focusId)
		if not id then
			return false, "bad_focus"
		end
		return svc:SetFocus(player, id)
	end, { rate = 1, burst = 3 })

	Net.handle("Profile.Rebuild", function(player: Player, edits: any)
		local clean = cleanEdits(edits)
		if not clean then
			return false, "bad_rebuild"
		end
		return svc:Rebuild(player, clean)
	end, { rate = 0.5, burst = 2 })

	Net.handle("Profile.GetPublic", function(_player: Player, target: any)
		if typeof(target) ~= "Instance" or not target:IsA("Player") or target.Parent ~= Players then
			return false, "generic"
		end
		local view = svc:GetPublicProfile(target)
		if not view then
			return false, "not_loaded"
		end
		return true, nil, view
	end, { rate = 3, burst = 10 })
end

function Remotes.open(player: Player, args: { [string]: any }?)
	if player.Parent == Players then
		Net.fire(Remotes.OPEN, player, args or {})
	end
end

return Remotes
