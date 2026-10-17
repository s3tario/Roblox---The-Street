--!strict
-- Promotion requirements (owned by `careerPath`; spec §5, design v3 §4-§6). PURE: no services, no clocks.
--
--   Promotion.evaluate(input) -> Result
--       input = { trackId, rank, level, coreDone, band?, fastTrack?, outfitLevel, schoolTier?, ovr? }
--       band   this week's review band. Given at the review (the score requirement is checked); nil for the
--              live checklist (the score item is "pending": it is decided at the next weekly review).
--   Promotion.blocker(result) -> id?     the requirement the boss mentions first ("outfit" | "school" | "ovr" |
--                                        "core" | "level"); nil when only the score was missing
--   Promotion.needLevel(role, fastTrack) / Promotion.needCore(role, fastTrack)
--
-- Requirements to move from rank r to r + 1 (all must pass):
--   level   the role's level cap (maxLevel); Star reviews fast-track it by 20% of the band
--   core    the role's core assignments at this rank (coreToPromote; -20% on the fast track)
--   score   On track (70) or better at this week's review
--   outfit  Outfit Level >= the new title's dress level (min(5, newRank + 1): VP needs 4, MD needs 5)
--   school  the new title's school gate (tier order, Boardroom Pedigree already applied by the caller)
--   ovr     the new title's minimum Overall rating (skipped when the OVR is unknown)

local Tracks = require(script.Parent.Parent.Config.Tracks)

export type Input = {
	trackId: string?,
	rank: number,
	level: number,
	coreDone: number?,
	band: string?,
	fastTrack: boolean?,
	outfitLevel: number?,
	schoolTier: number?,
	ovr: number?,
}
export type Item = { id: string, ok: boolean, pending: boolean, text: string }
export type Result = {
	applicable: boolean, -- false for students and players between jobs
	ready: boolean,
	top: boolean,
	nextRole: Tracks.RoleDef?,
	items: { Item },
	missing: { string },
	missingIds: { string },
	fastTrack: boolean,
	needLevel: number,
	needCore: number,
	needOutfit: number,
	headline: string,
}

local Promotion = {}

Promotion.FAST_TRACK = 0.2
Promotion.ORDER = { "level", "core", "score", "outfit", "school", "ovr" }
Promotion.BLOCKER_ORDER = { "outfit", "school", "ovr", "core", "level" }

local BAND_ORDER: { [string]: number } = { critical = 1, probation = 2, under = 3, on_track = 4, star = 5 }

function Promotion.needLevel(role: Tracks.RoleDef, fastTrack: boolean?): number
	if fastTrack then
		local band = role.maxLevel - role.minLevel + 1
		return math.max(role.minLevel, role.maxLevel - math.floor(band * Promotion.FAST_TRACK))
	end
	return role.maxLevel
end

function Promotion.needCore(role: Tracks.RoleDef, fastTrack: boolean?): number
	local base = role.coreToPromote or 0
	if fastTrack then
		return math.ceil(base * (1 - Promotion.FAST_TRACK))
	end
	return base
end

local function num(x: any, default: number): number
	if type(x) == "number" and x == x then
		return x
	end
	return default
end

function Promotion.evaluate(input: Input): Result
	local result: Result = {
		applicable = false,
		ready = false,
		top = false,
		nextRole = nil,
		items = {},
		missing = {},
		missingIds = {},
		fastTrack = false,
		needLevel = 0,
		needCore = 0,
		needOutfit = 0,
		headline = "",
	}
	local rank = math.floor(num(input.rank, 0))
	local role = if rank >= 1 then Tracks.rankDef(input.trackId, rank) else nil
	if not role then
		return result
	end
	result.applicable = true
	local track = Tracks.get(input.trackId)
	local nextRole = Tracks.rankDef(input.trackId, rank + 1)
	if not nextRole then
		result.top = true
		result.headline = Tracks.text("promo_top", { track = if track then track.name else "" })
		return result
	end
	result.nextRole = nextRole

	local band = input.band
	local fast = if band ~= nil then band == "star" else input.fastTrack == true
	result.fastTrack = fast

	local level = math.floor(num(input.level, 1))
	local needLevel = Promotion.needLevel(role, fast)
	local coreDone = math.floor(num(input.coreDone, 0))
	local needCore = Promotion.needCore(role, fast)
	local outfit = math.floor(num(input.outfitLevel, 1))
	local needOutfit = Tracks.dressLevelFor(nextRole)
	local school = math.floor(num(input.schoolTier, 1))
	result.needLevel, result.needCore, result.needOutfit = needLevel, needCore, needOutfit

	local function add(id: string, ok: boolean, pending: boolean, text: string)
		table.insert(result.items, { id = id, ok = ok, pending = pending, text = text })
		if not ok and not pending then
			table.insert(result.missing, text)
			table.insert(result.missingIds, id)
		end
	end

	local levelText = if fast
		then Tracks.text("missing_level_fast", { need = needLevel, cap = role.maxLevel, current = level })
		else Tracks.text("missing_level", { need = needLevel, current = level })
	add("level", level >= needLevel, false, levelText)

	add(
		"core",
		coreDone >= needCore,
		false,
		Tracks.text("missing_core", { need = needCore, done = math.min(coreDone, needCore), title = role.title })
	)

	local scoreOk = band ~= nil and (BAND_ORDER[band] or 0) >= BAND_ORDER.on_track
	add("score", scoreOk, band == nil, Tracks.text("missing_score", { score = 70 }))

	add(
		"outfit",
		outfit >= needOutfit,
		false,
		Tracks.text("missing_outfit", { title = nextRole.title, need = needOutfit, current = outfit })
	)

	if nextRole.schoolGate then
		add(
			"school",
			school >= nextRole.schoolGate,
			false,
			Tracks.text("missing_school", { title = nextRole.title, tier = Tracks.tierName(nextRole.schoolGate) })
		)
	end

	if nextRole.minOvr > 0 then
		local ovr = input.ovr
		local known = type(ovr) == "number" and ovr == ovr
		add(
			"ovr",
			not known or (ovr :: number) >= nextRole.minOvr,
			false,
			Tracks.text("missing_ovr", {
				need = nextRole.minOvr,
				title = nextRole.title,
				current = if known then math.floor(ovr :: number) else "?",
			})
		)
	end

	result.ready = #result.missing == 0 and (band == nil or scoreOk)
	if result.ready then
		result.headline = Tracks.text("promo_ready", { title = nextRole.title })
	else
		result.headline = Tracks.text("promo_next", { title = nextRole.title })
	end
	return result
end

-- The requirement the boss names when a good week still can't be a promotion.
function Promotion.blocker(result: Result): string?
	for _, id in Promotion.BLOCKER_ORDER do
		if table.find(result.missingIds, id) then
			return id
		end
	end
	return nil
end

return Promotion
