--!strict
-- CareerService/Deals (server, runtime only): deal plaques (design v3 §13, contracts §9). A completed signature deal
-- or project (ProjectService) creates a lucite plaque named after the deal and its date, adds Deal Mastery and
-- Career Prestige (scaled by quality and the firm's prestige multiplier), writes the timeline, and asks
-- HousingService to re-render the desk/bookshelf plaques.
--
--   Deals.record(svc, player, dealId, name, quality) -> plaque?
--       plaque = { id, dealId, name, at, quality, companyId, week }

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Tracks = require(Shared.Config.Tracks)
local Companies = require(Shared.Config.Companies)
local CareerState = require(Shared.Logic.CareerState)
local Deps = require(script.Parent.Deps)

local Deals = {}

Deals.MAX_NAME = 80
Deals.MAX_ID = 40

local function num(x: any, default: number): number
	if type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge then
		return x
	end
	return default
end

-- Deal Mastery for one deal: 10 + 0.9 x quality, times the firm's prestige multiplier.
function Deals.mastery(quality: number, prestigeMult: number): number
	return math.floor((10 + quality * 0.9) * prestigeMult + 0.5)
end

-- Career Prestige for one deal: twice the rank's weekly prestige, scaled by quality (50%..100%).
function Deals.prestige(basePrestige: number, quality: number, prestigeMult: number): number
	return math.floor(basePrestige * 2 * prestigeMult * (0.5 + quality / 200) + 0.5)
end

function Deals.record(svc: any, player: Player, dealId: any, name: any, quality: any): { [string]: any }?
	local career = svc._careerOf(player)
	if not career or type(dealId) ~= "string" or dealId == "" then
		return nil
	end
	local q = math.clamp(num(quality, 0), 0, 100)
	local dealName = if type(name) == "string" and name ~= "" then string.sub(name, 1, Deals.MAX_NAME) else dealId
	local nextId = math.floor(num(career.nextPlaqueId, 1))
	career.nextPlaqueId = nextId + 1
	local company = Companies.get(career.companyId)
	local plaque = {
		id = "p" .. nextId,
		dealId = string.sub(dealId, 1, Deals.MAX_ID),
		name = dealName,
		at = os.time(),
		quality = math.floor(q + 0.5),
		companyId = if type(career.companyId) == "string" then career.companyId else "",
		week = math.floor(num(career.week, 0)),
	}
	CareerState.pushRing(career.plaques, plaque, CareerState.PLAQUES_KEPT)
	career.plaqueCount = math.floor(num(career.plaqueCount, 0)) + 1
	career.signatures[plaque.dealId] = math.floor(num(career.signatures[plaque.dealId], 0)) + 1
	local prestigeMult = if company then company.prestigeMult else 1
	local role = Tracks.rankDef(career.track, career.rank)
	career.dealMastery = num(career.dealMastery, 0) + Deals.mastery(q, prestigeMult)
	career.prestige = num(career.prestige, 0) + Deals.prestige(if role then role.prestige else 5, q, prestigeMult)
	CareerState.history(career, "deal", os.time(), { name = dealName })
	Deps.notify(player, Tracks.text("deal_plaque", { name = dealName }), "good")
	Deps.banner(player, { title = Tracks.text("deal_plaque_title"), subtitle = dealName, style = "celebration" })
	task.spawn(function()
		Deps.call("HousingService", "RefreshPlaques", player)
	end)
	svc.DealRecorded:Fire(player, table.clone(plaque))
	svc._submitBoards(player)
	Deps.audit(player, "career_deal", { dealId = plaque.dealId, quality = plaque.quality })
	svc:Touch(player)
	Deps.save(player, "deal")
	return plaque
end

return Deals
