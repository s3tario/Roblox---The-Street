--!strict
-- WardrobeService remotes (RUNTIME ONLY, server). Every argument is validated with Guard before it reaches the
-- service; the service then validates the request against the catalog and the player's live state.
--
--   RemoteFunctions (return ok, errKey?, ... ; errKey is a Catalog.strings suffix after "err_")
--     "Wardrobe.Equip"(slot, itemId | nil) -> ok, errKey?          nil itemId takes the slot off
--     "Wardrobe.SavePreset"(index 1-5, name?) -> ok, errKey?
--     "Wardrobe.LoadPreset"(index 1-5) -> ok, errKey?, droppedCount
--     "Wardrobe.SetWearAvatar"(on: boolean) -> ok, errKey?
--     "Wardrobe.GetAccess"() -> { rank, passes = { [passKey] = boolean }, companyLogo?, outfitLevel }
--   RemoteEvent (server -> client)
--     "Wardrobe.Open"(args?)       open the Wardrobe screen (sent after a wardrobe prompt is accepted)

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Guard = require(Shared.Guard)
local Catalog = require(Shared.Config.Catalog)

local Remotes = {}

Remotes.OPEN = "Wardrobe.Open"

local function slotArg(x: any): string?
	local id = Guard.id(x)
	if id and Catalog.SLOT_SET[id] then
		return id
	end
	return nil
end

-- service = WardrobeService (Equip, SavePreset, LoadPreset, SetWearAvatar, GetAccess)
function Remotes.bind(service: any)
	Net.declare(Remotes.OPEN)

	Net.handle("Wardrobe.Equip", function(player: Player, slot: any, itemId: any): (boolean, string?)
		local s = slotArg(slot)
		if not s then
			return false, "bad_slot"
		end
		local id: string? = nil
		if itemId ~= nil then
			id = Guard.id(itemId)
			if not id then
				return false, "unknown_item"
			end
		end
		return service:Equip(player, s, id)
	end, { rate = 6, burst = 14 })

	Net.handle("Wardrobe.SavePreset", function(player: Player, index: any, name: any): (boolean, string?)
		local i = Guard.int(index, 1, Catalog.PRESET_SLOTS.max)
		if not i then
			return false, "locked"
		end
		local n: string? = nil
		if name ~= nil then
			n = Guard.str(name, 200)
			if not n then
				return false, "bad_name"
			end
		end
		return service:SavePreset(player, i, n)
	end, { rate = 2, burst = 4 })

	Net.handle("Wardrobe.LoadPreset", function(player: Player, index: any): (boolean, string?, number)
		local i = Guard.int(index, 1, Catalog.PRESET_SLOTS.max)
		if not i then
			return false, "locked", 0
		end
		return service:LoadPreset(player, i)
	end, { rate = 2, burst = 4 })

	Net.handle("Wardrobe.SetWearAvatar", function(player: Player, on: any): (boolean, string?)
		local b = Guard.bool(on)
		if b == nil then
			return false, "generic"
		end
		return service:SetWearAvatar(player, b)
	end, { rate = 1, burst = 3 })

	Net.handle("Wardrobe.GetAccess", function(player: Player): { [string]: any }
		return service:GetAccess(player)
	end, { rate = 1, burst = 4 })
end

function Remotes.open(player: Player, args: { [string]: any }?)
	Net.fire(Remotes.OPEN, player, args or {})
end

return Remotes
