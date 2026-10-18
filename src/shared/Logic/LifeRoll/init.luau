--!strict
-- Life Roll rules (owned by `careerCore`; design v3 §1-§3, contracts §4). PURE: no services, no clocks, no
-- Instances; every random draw comes from the caller's Shared/Util/Rng. Unit-tested in tests/careerCore.
--
-- Rolling (Roll.luau)
--   LifeRoll.FIELDS                                   spin order: school degree gpa family clubs stats outfit
--   LifeRoll.rollAll(rng, ctx?) -> Roll               ctx = { rebirths? } (rebirth luck)
--   LifeRoll.rollField(field, rng, ctx?) -> value
--   LifeRoll.rerollField(roll, field, rng, ctx?) -> Roll   a copy with exactly ONE field re-rolled
--   LifeRoll.normalizeRoll(raw) -> Roll?              LifeRoll.copyRoll(roll) -> Roll
--   LifeRoll.describe(field, value) -> string         LifeRoll.rarityOf(field, value) -> rarity?
--   LifeRoll.mythics(roll, fields?) -> { {field, text} }
--   LifeRoll.gpaCdf(x) / LifeRoll.gpaFromUnit(u) / LifeRoll.clubCount(u)
-- Odds disclosure (Odds.luau)
--   LifeRoll.odds(field, rebirths?) -> OddsTable      LifeRoll.oddsAll(rebirths?) -> { [field] = OddsTable }
-- Profile (Apply.luau)
--   LifeRoll.validName, startRoll, rerollSource, reroll, lock, recompute, boosts, boostSources, perks, finalStats,
--   hasPerk, consumePerk, schoolTierOrder, incomeMult, weekKey, setFocus, canChangeFocus, rebuildOptions, rebuild
--   (signatures in Apply.luau)
-- Load repair and the public view (View.luau)
--   LifeRoll.normalize(profile) -> profile          LifeRoll.publicView(profile, extra?) -> PublicProfile
--
-- Roll = { school = {id, rarity}, degree = "bs"|"ms", gpa, family = {id, rarity}, clubs = { {id, rarity} },
--          stats = { [statId] = 25..55 }, outfit = { lookId, brand, rarity, itemIds, name } }

local Roll = require(script.Roll)
local Odds = require(script.Odds)
local Apply = require(script.Apply)
local View = require(script.View)
local Config = require(game:GetService("ReplicatedStorage").Shared.Config.LifeRoll)

export type Pick = Roll.Pick
export type Outfit = Roll.Outfit
export type Roll = Roll.Roll
export type Ctx = Roll.Ctx
export type OddsTable = Odds.OddsTable
export type OddsRow = Odds.Row
export type LockResult = Apply.LockResult
export type PublicProfile = View.PublicProfile
export type BoostSource = Apply.BoostSource

local LifeRoll = {}

LifeRoll.FIELDS = Config.FIELDS

-- Rolling
LifeRoll.rollAll = Roll.rollAll
LifeRoll.rollField = Roll.rollField
LifeRoll.rerollField = Roll.rerollField
LifeRoll.normalizeRoll = Roll.normalize
LifeRoll.copyRoll = Roll.copy
LifeRoll.describe = Roll.describe
LifeRoll.rarityOf = Roll.rarityOf
LifeRoll.mythics = Roll.mythics
LifeRoll.gpaCdf = Roll.gpaCdf
LifeRoll.gpaFromUnit = Roll.gpaFromUnit
LifeRoll.clubCount = Roll.clubCount

-- Odds
LifeRoll.odds = Odds.table
LifeRoll.oddsAll = Odds.all

-- Profile
LifeRoll.validName = Apply.validName
LifeRoll.hasPending = Apply.hasPending
LifeRoll.startRoll = Apply.startRoll
LifeRoll.rerollSource = Apply.rerollSource
LifeRoll.reroll = Apply.reroll
LifeRoll.lock = Apply.lock
LifeRoll.recompute = Apply.recompute
LifeRoll.boosts = Apply.boosts
LifeRoll.boostSources = Apply.boostSources
LifeRoll.perks = Apply.perks
LifeRoll.finalStats = Apply.finalStats
LifeRoll.hasPerk = Apply.hasPerk
LifeRoll.consumePerk = Apply.consumePerk
LifeRoll.schoolTierOrder = Apply.schoolTierOrder
LifeRoll.incomeMult = Apply.incomeMult
LifeRoll.weekKey = Apply.weekKey
LifeRoll.setFocus = Apply.setFocus
LifeRoll.canChangeFocus = Apply.canChangeFocus
LifeRoll.rebuildOptions = Apply.rebuildOptions
LifeRoll.rebuild = Apply.rebuild
LifeRoll.normalize = View.normalize
LifeRoll.publicView = View.publicView

return LifeRoll
