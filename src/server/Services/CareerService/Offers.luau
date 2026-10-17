--!strict
-- CareerService/Offers (server, runtime only): job offers (contracts §5 GrantOffer / AcceptOffer).
--   offer = { companyId, track = "ib", rank = 1, source }  source: "recruiting" | "walk_on" | "email" | "headhunter"
-- The tutorial's Recruiting Board grants offers after a Superday (Logic/Recruiting decides the odds); M3 email
-- offers and headhunters use the same call. Accepting as a student, or after a firing, hires the player at the
-- offer's rank; accepting while employed is a lateral move. Other pending offers are declined on accept.
--
--   Offers.grant(svc, player, offer) -> offerId?
--   Offers.accept(svc, player, offerId) -> (ok, errKey?)   errKey: not_loaded | no_offer | company_closed |
--                                                          review_pending
--   Offers.decline(svc, player, offerId) -> (ok, errKey?)

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Guard = require(Shared.Guard)
local Tracks = require(Shared.Config.Tracks)
local Companies = require(Shared.Config.Companies)
local CareerState = require(Shared.Logic.CareerState)
local Deps = require(script.Parent.Deps)

local Offers = {}

local SOURCES = { recruiting = true, walk_on = true, email = true, headhunter = true, event = true, admin = true }

local function num(x: any, default: number): number
	if type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge then
		return x
	end
	return default
end

local function findOffer(career: { [string]: any }, offerId: any): (number?, { [string]: any }?)
	if type(offerId) ~= "string" or type(career.offers) ~= "table" then
		return nil, nil
	end
	for i, o in career.offers do
		if type(o) == "table" and o.id == offerId then
			return i, o
		end
	end
	return nil, nil
end

function Offers.grant(svc: any, player: Player, offer: any): string?
	local career = svc._careerOf(player)
	if not career or type(offer) ~= "table" then
		return nil
	end
	local companyId = Guard.id(offer.companyId)
	local track = Guard.id(offer.track) or "ib"
	local rank = Guard.int(offer.rank, 1, 20) or 1
	local company = if companyId then Companies.get(companyId) else nil
	if not company or not Companies.hires(company, track) then
		return nil
	end
	local role = Tracks.rankDef(track, rank)
	if not role then
		return nil
	end
	-- an offer for the job you already have (or a lower one at the same firm) means nothing
	if
		CareerState.isEmployed(career)
		and career.companyId == company.id
		and career.track == track
		and rank <= num(career.rank, 0)
	then
		return nil
	end
	local sourceRaw = Guard.id(offer.source)
	local source = if sourceRaw and SOURCES[sourceRaw] then sourceRaw else "recruiting"
	for _, existing in career.offers do
		if type(existing) == "table" and existing.companyId == company.id and existing.track == track then
			if rank > num(existing.rank, 1) then
				existing.rank = rank
				existing.source = source
				existing.at = os.time()
				svc:Touch(player)
			end
			Deps.notify(player, Tracks.text("offer_exists", { company = company.name }), "info")
			return existing.id
		end
	end
	while #career.offers >= CareerState.OFFERS_MAX do
		table.remove(career.offers, 1)
	end
	local id = "o" .. math.floor(num(career.nextOfferId, 1))
	career.nextOfferId = math.floor(num(career.nextOfferId, 1)) + 1
	table.insert(career.offers, {
		id = id,
		companyId = company.id,
		track = track,
		rank = rank,
		source = source,
		at = os.time(),
	})
	Deps.notify(player, Tracks.text("offer_received", { title = role.title, company = company.name }), "good")
	Deps.audit(player, "career_offer", { companyId = company.id, rank = rank, source = source })
	svc.OffersChanged:Fire(player)
	svc:Touch(player)
	return id
end

function Offers.decline(svc: any, player: Player, offerId: any): (boolean, string?)
	local career = svc._careerOf(player)
	if not career then
		return false, "not_loaded"
	end
	local index = findOffer(career, offerId)
	if not index then
		return false, "no_offer"
	end
	table.remove(career.offers, index)
	svc.OffersChanged:Fire(player)
	svc:Touch(player)
	return true, nil
end

function Offers.accept(svc: any, player: Player, offerId: any): (boolean, string?)
	local career = svc._careerOf(player)
	if not career then
		return false, "not_loaded"
	end
	local index, offer = findOffer(career, offerId)
	if not index or not offer then
		return false, "no_offer"
	end
	local company = Companies.get(offer.companyId)
	local role = Tracks.rankDef(offer.track, offer.rank)
	if not company or not role or not Companies.hires(company, offer.track) then
		table.remove(career.offers, index)
		svc:Touch(player)
		return false, "company_closed"
	end
	if career.reviewDue == true and CareerState.isEmployed(career) then
		return false, "review_pending"
	end

	local wasEmployed = CareerState.isEmployed(career)
	local wasFired = career.status == "fired"
	local oldStatus = if type(career.status) == "string" then career.status else "student"
	local reason = if wasEmployed then "lateral" else "hired"
	local active = Deps.activeSeconds(player)
	local oldRole = CareerState.hire(career, {
		companyId = company.id,
		trackId = offer.track,
		rank = offer.rank,
		now = os.time(),
		active = active,
	})
	if wasFired then
		career.comebacks = num(career.comebacks, 0) + 1
		svc._clearReentry(player)
	end
	career.onboarded = false
	career.offers = {}
	svc:_settleLevel(player)

	-- the campus tutorial reads campus.offer to open the subway to the Street
	local data = Deps.data(player)
	if data and type(data.campus) == "table" then
		data.campus.offer = true
		Deps.replicate(player, "campus")
	end

	svc._topBook(player, career, reason)
	CareerState.history(career, reason, os.time(), { title = role.title })
	if oldStatus ~= "active" then
		svc.StatusChanged:Fire(player, "active", oldStatus)
	end
	svc.RoleChanged:Fire(player, role.roleId, oldRole, reason)
	local subtitle = Tracks.text(if reason == "lateral" then "lateral_subtitle" else "hired_subtitle", {
		title = role.title,
		company = company.name,
	})
	Deps.banner(player, {
		title = Tracks.text(if reason == "lateral" then "lateral_title" else "hired_title"),
		subtitle = subtitle,
		style = "celebration",
		duration = 6,
	})
	Deps.objective(player, Tracks.text("objective_report", { company = company.name }))
	Deps.call("EmailService", "Send", player, {
		from = Companies.bossName(company.id, offer.track),
		subject = Tracks.text("mail_hired_subject", { company = company.name }),
		body = Tracks.text("mail_hired_body", {
			title = role.title,
			company = company.name,
			boss = Companies.bossName(company.id, offer.track),
		}),
		kind = "hr",
	})
	Deps.audit(player, "career_hired", { companyId = company.id, roleId = role.roleId, reason = reason })
	svc.OffersChanged:Fire(player)
	svc:Touch(player)
	Deps.save(player, "hired")
	return true, nil
end

return Offers
