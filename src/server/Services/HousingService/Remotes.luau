--!strict
-- HousingService remotes (RUNTIME ONLY, server). Every argument is validated with Guard before it reaches the
-- service, which then validates the request against the player's live assignment and Logic/Economy/Housing.
--
--   RemoteFunctions (errKey = a Config/Shop "err_" suffix)
--     "Housing.Get"() -> View                                    what the Housing screen shows
--     "Housing.Place"(context, slotId, decorId | nil) -> ok, errKey?   nil decorId clears the spot
--     "Housing.SetTheme"(context, themeId) -> ok, errKey?
--   RemoteEvents (server -> client)
--     "Housing.Open"(args)      open the Housing screen ({ context? }) after a housing_panel prompt
--     "Housing.Changed"()       the player's assignment changed (an open Housing screen reloads)

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Guard = require(Shared.Guard)
local Decor = require(Shared.Config.Decor)

local Remotes = {}

Remotes.OPEN = "Housing.Open"
Remotes.CHANGED = "Housing.Changed"

local function contextArg(x: any): string?
	local id = Guard.id(x)
	return if id and Decor.CONTEXTS[id] then id else nil
end

-- service = HousingService (Place, SetTheme, GetView)
function Remotes.bind(service: any)
	Net.declare(Remotes.OPEN)
	Net.declare(Remotes.CHANGED)

	Net.handle("Housing.Get", function(player: Player): any
		return service:GetView(player)
	end, { rate = 2, burst = 6 })

	Net.handle("Housing.Place", function(player: Player, ctx: any, slotId: any, decorId: any): (boolean, string?)
		local c = contextArg(ctx)
		if not c then
			return false, "no_context"
		end
		local s = Guard.id(slotId)
		if not s then
			return false, "bad_slot"
		end
		local d: string? = nil
		if decorId ~= nil then
			d = Guard.id(decorId)
			if not d or Decor.get(d) == nil then
				return false, "unknown_item"
			end
		end
		return service:Place(player, c, s, d)
	end, { rate = 4, burst = 10 })

	Net.handle("Housing.SetTheme", function(player: Player, ctx: any, themeId: any): (boolean, string?)
		local c = contextArg(ctx)
		if not c then
			return false, "no_context"
		end
		local th = Guard.id(themeId)
		if not th or Decor.theme(th) == nil then
			return false, "bad_theme"
		end
		return service:SetTheme(player, c, th)
	end, { rate = 1, burst = 4 })
end

function Remotes.open(player: Player, args: { [string]: any }?)
	if player.Parent == Players then
		Net.fire(Remotes.OPEN, player, args or {})
	end
end

function Remotes.changed(player: Player)
	if player.Parent == Players then
		Net.fire(Remotes.CHANGED, player)
	end
end

return Remotes
