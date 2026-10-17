--!strict
-- CareerService/Remotes (server, runtime only). Every argument is validated with Guard; results are
-- (ok, errKey?, ...) so CareerController can show the matching Tracks string ("err_<key>").
--   RemoteFunctions (client -> server):
--     "Career.AcceptOffer"(offerId) -> (ok, err?)
--     "Career.DeclineOffer"(offerId) -> (ok, err?)
--     "Career.Services"() -> info                       the CareerServices screen (CareerService/Recovery.info)
--     "Career.Reentry"(action, answers?) -> (ok, err?, view?, result?)   action "start" | "view" | "submit"
--     "Career.Reinstate"() -> (ok, err?)
--     "Career.UseCapital"() -> (ok, err?)
--     "Career.FreshStart"() -> (ok, err?)
--   RemoteEvents (server -> client):
--     "Career.Open"(screenId, args)                     open a career screen (Career Services prompt)
--     "Career.Objective"(text)                          objective line when the tutorial's QuestService is absent

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Guard = require(Shared.Guard)
local Deps = require(script.Parent.Deps)

local Remotes = {}

Remotes.OPEN = "Career.Open"
Remotes.OBJECTIVE = Deps.OBJECTIVE_REMOTE

local REENTRY_ACTIONS = { start = true, view = true, submit = true }

function Remotes.bind(svc: any)
	Net.declare(Remotes.OPEN)
	Net.declare(Remotes.OBJECTIVE)

	Net.handle("Career.AcceptOffer", function(player: Player, offerId: any): (boolean, string?)
		local id = Guard.id(offerId)
		if not id then
			return false, "no_offer"
		end
		return svc:AcceptOffer(player, id)
	end, { rate = 1, burst = 3 })

	Net.handle("Career.DeclineOffer", function(player: Player, offerId: any): (boolean, string?)
		local id = Guard.id(offerId)
		if not id then
			return false, "no_offer"
		end
		return svc:DeclineOffer(player, id)
	end, { rate = 2, burst = 6 })

	Net.handle("Career.Services", function(player: Player): { [string]: any }
		return svc:GetServicesInfo(player)
	end, { rate = 1, burst = 4 })

	Net.handle("Career.Reentry", function(player: Player, action: any, answers: any): (boolean, string?, any, any)
		local a = Guard.oneOf(action, REENTRY_ACTIONS)
		if not a then
			return false, "bad_answers", nil, nil
		end
		local clean: any = nil
		if a == "submit" then
			if answers == nil then
				clean = {}
			else
				clean = Guard.map(answers, 64, 3)
				if clean == nil then
					return false, "bad_answers", nil, nil
				end
			end
		end
		return svc:Reentry(player, a, clean)
	end, { rate = 1, burst = 4 })

	Net.handle("Career.Reinstate", function(player: Player): (boolean, string?)
		return svc:Reinstate(player)
	end, { rate = 0.5, burst = 2 })

	Net.handle("Career.UseCapital", function(player: Player): (boolean, string?)
		return svc:UseCapitalCredit(player)
	end, { rate = 0.5, burst = 2 })

	Net.handle("Career.FreshStart", function(player: Player): (boolean, string?)
		return svc:FreshStart(player)
	end, { rate = 0.5, burst = 2 })
end

return Remotes
