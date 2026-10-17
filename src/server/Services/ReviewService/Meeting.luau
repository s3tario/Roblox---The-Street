--!strict
-- ReviewService/Meeting (server, runtime only): the payload the ReviewMeeting screen plays (design v3 §6).
-- Everything the cinematic needs travels in one table, already decided by the server: typed boss lines that vary
-- with the outcome and the component strengths, the breakdown card, pay, and where the camera should look.
--
--   Meeting.build(ctx) -> Payload
--   Meeting.camera(companyId, trackId) -> { bossModel?, bossCFrame?, spotCFrame? }
--   Meeting.send(player, payload)            fires "Career.Meeting"
--   Meeting.REMOTE = "Career.Meeting"

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Format = require(Shared.Util.Format)
local Tracks = require(Shared.Config.Tracks)
local Companies = require(Shared.Config.Companies)
local Review = require(Shared.Logic.Review)
local Deps = require(script.Parent.Parent.CareerService.Deps)

local Meeting = {}

Meeting.REMOTE = "Career.Meeting"

export type Ctx = {
	player: Player,
	mode: string, -- "office" | "phone" | "discipline"
	reviewId: string?,
	week: number,
	companyId: string,
	trackId: string,
	firstName: string,
	title: string, -- the title before the meeting
	newTitle: string?, -- set when promoted
	newOffice: boolean?,
	score: number?,
	band: string?,
	components: Review.Components?,
	investmentKind: string?,
	workCount: number?,
	excess: number?,
	outcome: string,
	status: string,
	lifeline: boolean?,
	fireReason: string?,
	blocked: string?,
	blockedNeed: any?,
	blockedTier: string?,
	missing: { string }?,
	pay: { salary: number, bonus: number, living: number }?,
	xp: number?,
	prestige: number?,
	breakdown: boolean,
}

local function cframeOf(inst: any): CFrame?
	if typeof(inst) ~= "Instance" then
		return nil
	end
	if inst:IsA("BasePart") then
		return inst.CFrame
	end
	if inst:IsA("Model") then
		local ok, cf = pcall(function()
			return inst:GetPivot()
		end)
		if ok then
			return cf
		end
	end
	return nil
end

function Meeting.camera(companyId: string, trackId: string): { [string]: any }
	local out: { [string]: any } = {}
	local okNpc, npc = Deps.call("OfficeService", "GetBossNpc", companyId, trackId)
	if okNpc and typeof(npc) == "Instance" and npc:IsA("Model") then
		out.bossModel = npc
		local head = npc:FindFirstChild("Head")
		local headCf = cframeOf(head)
		out.bossCFrame = cframeOf(npc)
		if headCf then
			out.headPosition = headCf.Position
		end
	end
	if not out.bossCFrame then
		local okChair, chair = Deps.call("OfficeService", "GetAnchor", companyId, trackId, "boss_chair")
		if okChair then
			out.bossCFrame = cframeOf(chair)
		end
	end
	local okSpot, spot = Deps.call("OfficeService", "GetAnchor", companyId, trackId, "review_spot")
	if okSpot then
		out.spotCFrame = cframeOf(spot)
	end
	return out
end

function Meeting.build(ctx: Ctx): { [string]: any }
	local company = Companies.get(ctx.companyId)
	local boss = Companies.bossName(ctx.companyId, ctx.trackId)
	local components = ctx.components or { investment = 65, risk = 65, work = 65, reputation = 65 }
	local excess = ctx.excess
	local vars = {
		name = ctx.firstName,
		boss = boss,
		company = if company then company.name else "",
		title = ctx.title,
		newTitle = ctx.newTitle or "",
		score = ctx.score or 0,
		excess = if type(excess) == "number" then Format.pct(math.abs(excess), 1) else "",
		need = if ctx.blockedNeed ~= nil then ctx.blockedNeed else "",
		tier = ctx.blockedTier or "",
		week = ctx.week,
	}
	-- the "next title" in blocked lines is the title the player was aiming for
	if ctx.blocked and not ctx.newTitle then
		local career = Deps.career(ctx.player)
		local nextRole = if career then Tracks.rankDef(career.track, (career.rank or 0) + 1) else nil
		vars.newTitle = if nextRole then nextRole.title else ""
	end
	local lines, outcomeAt = Review.dialogue({
		seed = tostring(ctx.player.UserId) .. ":" .. tostring(ctx.week) .. ":" .. tostring(ctx.reviewId or ctx.mode),
		mode = ctx.mode,
		outcome = ctx.outcome,
		band = ctx.band or "under",
		components = components,
		investmentKind = ctx.investmentKind,
		workCount = ctx.workCount,
		lifeline = ctx.lifeline,
		fireReason = ctx.fireReason,
		blocked = ctx.blocked,
		vars = vars,
	})
	local cam = if ctx.mode == "office" then Meeting.camera(ctx.companyId, ctx.trackId) else {}
	return {
		id = ctx.reviewId,
		mode = ctx.mode,
		week = ctx.week,
		score = ctx.score,
		band = ctx.band,
		bandName = if ctx.band then Tracks.text("band_" .. ctx.band) else nil,
		outcome = ctx.outcome,
		status = ctx.status,
		lines = lines,
		outcomeAt = outcomeAt,
		breakdown = ctx.breakdown,
		components = components,
		weights = table.clone(Review.WEIGHTS),
		company = {
			id = ctx.companyId,
			name = if company then company.name else "",
			short = if company then company.short else "",
			logo = if company then company.logo else ctx.companyId,
			primary = if company then company.colors.primary else Color3.fromRGB(11, 31, 58),
			accent = if company then company.colors.accent else Color3.fromRGB(201, 165, 76),
		},
		boss = { name = boss },
		title = ctx.title,
		newTitle = ctx.newTitle,
		newOffice = ctx.newOffice == true,
		lifeline = ctx.lifeline == true,
		fireReason = ctx.fireReason,
		missing = ctx.missing or {},
		pay = ctx.pay,
		xp = ctx.xp,
		prestige = ctx.prestige,
		camera = cam,
	}
end

function Meeting.send(player: Player, payload: { [string]: any })
	if Deps.isLive(player) then
		local ok, err = pcall(function()
			Net.fire(Meeting.REMOTE, player, payload)
		end)
		if not ok then
			warn("[ReviewService] meeting send failed: " .. tostring(err))
		end
	end
end

return Meeting
