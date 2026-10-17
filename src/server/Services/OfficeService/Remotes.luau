--!strict
-- OfficeService/Remotes (server, runtime). Every argument is validated with Guard before it reaches the service;
-- the service then checks it against the catalog and the player's live position.
--
--   RemoteFunctions (each returns ok, errKey?, message?; message is player-facing text)
--     "Office.Enter"(companyId, floor?)   Directory screen / Phone: lobby by default, or a department floor
--     "Office.Elevator"(floor)            lobby elevator panel ("lobby" or a track id); visitors may ride
--     "Office.Directory"() -> { Entry }   every company with its availability (OfficeAlloc.Entry)
--   RemoteEvents (server -> client)
--     "Office.OpenElevator"(payload)      an elevator_panel prompt was accepted (Catalog.ElevatorPayload)
--     "Office.OpenDirectory"(args?)       a company_directory kiosk was used ({ source = "kiosk" })

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Guard = require(Shared.Guard)
local DoorRules = require(Shared.Logic.DoorRules)

local Text = DoorRules.Text

local Remotes = {}

Remotes.OPEN_ELEVATOR = "Office.OpenElevator"
Remotes.OPEN_DIRECTORY = "Office.OpenDirectory"

export type Service = {
	EnterFromRemote: (self: any, player: Player, companyId: string, floor: string?) -> (boolean, string?, string?),
	RideElevator: (self: any, player: Player, floor: string) -> (boolean, string?, string?),
	GetDirectory: (self: any) -> { any },
}

function Remotes.bind(service: Service)
	Net.declare(Remotes.OPEN_ELEVATOR)
	Net.declare(Remotes.OPEN_DIRECTORY)

	Net.handle("Office.Enter", function(player: Player, companyId: any, floor: any)
		local id = Guard.id(companyId)
		if not id then
			return false, "opening_soon", Text.get("unknown_company")
		end
		local fl: string? = nil
		if floor ~= nil then
			fl = Guard.id(floor)
			if not fl then
				return false, "no_floor", Text.get("tp_failed")
			end
		end
		return service:EnterFromRemote(player, id, fl)
	end, { rate = 1, burst = 3 })

	Net.handle("Office.Elevator", function(player: Player, floor: any)
		local fl = Guard.id(floor)
		if not fl then
			return false, "no_floor", Text.get("tp_failed")
		end
		return service:RideElevator(player, fl)
	end, { rate = 1, burst = 3 })

	Net.handle("Office.Directory", function(_player: Player)
		return service:GetDirectory()
	end, { rate = 1, burst = 5 })
end

function Remotes.openElevator(player: Player, payload: { [string]: any })
	Net.fire(Remotes.OPEN_ELEVATOR, player, payload)
end

function Remotes.openDirectory(player: Player, args: { [string]: any }?)
	Net.fire(Remotes.OPEN_DIRECTORY, player, args or {})
end

return Remotes
