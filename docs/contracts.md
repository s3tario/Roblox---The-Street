# The Street — Code Contracts (v3)

This file is the single source of truth for **interfaces between features**. A feature may change its internals
freely but must not change anything in this file without updating every caller. Design numbers live in
`docs/superpowers/specs/2026-10-17-the-street-design-v3.md`, which overrides
`docs/superpowers/specs/2026-10-15-the-street-design.md` where they conflict.

---

## 1. Rojo tree

| DataModel path | Source | Notes |
|---|---|---|
| `ReplicatedStorage.Shared` | `src/shared` | Shared modules (server + client). |
| `ServerScriptService.Server` | `src/server` | `Main.server.luau`, `Registry.luau`, `Services/*`. |
| `ServerStorage.WorldBuilders` | `src/world` | World, venue and office-template builders. |
| `ServerStorage.FirmTemplates` | `build/Templates.rbxm` | Baked office templates (lobby + one floor per department). Cloned at runtime by OfficeService. |
| `StarterPlayer.StarterPlayerScripts.Client` | `src/client` | `Main.client.luau`, `Registry.luau`, `Controllers/*`, `UI/*`. |
| `Workspace.World` | `build/World.rbxm` | Baked exteriors and venues. Never edit by hand. |
| `Workspace.Handmade` | `src/handmade` (optional) | The owner's hand-edited content survives rebuilds. |

```
src/shared/
  Net.luau, Guard.luau, Util/*            foundation
  Config/                                 pure data tables (each file owned by one feature, §14)
    World.luau                            regions, venues, office system, towers, doors, anchors, interact ids (foundation)
    DataTemplate/                         per-feature default player data, merged by init.luau (§3)
  Logic/                                  PURE logic (no services, no clocks, no Instances): unit-tested in Lune
    Tasks/<taskId>.luau                   work task modules (§8)
    Projects/<id>.luau                    multi-step project modules (§9)
  Build/                                  Kit.luau, Palette.luau (foundation)
  Assets/                                 bake-safe builders: Props/, Signs/, Wardrobe/, Npc/, Logos/, EventProps/
```

## 2. Runtime frameworks (foundation)

**Server services** (`src/server/Services/<Name>.luau`, auto-discovered):

```lua
local Service = { Name = "X", Priority = 100 }  -- lower inits first
function Service:Init() end   -- remotes and signals only; no yielding; no DataStore calls
function Service:Start() end  -- spawned; loops and DataStore work
```

- Reach other services with `local Registry = require(script.Parent.Parent.Registry)`. `Registry.X` errors if X is
  missing; `Registry.get("X")` returns nil (logged once). Guard every cross-feature call so a missing or erroring
  feature never breaks yours.
- Priorities: DataService 1, AuditService 2, NotifyService 5, MarketService 10, EventService 15, OfficeService 20.
- **Client controllers** (`src/client/Controllers/<Name>.luau`) have the same shape, reached via
  `require(script.Parent.Parent.Registry)`.

**Net** (`Shared/Net`): remotes are namespaced `Feature.Action`.

```lua
-- server
Net.on(name, handler, opts?)
Net.handle(name, handler, opts?)
Net.declare(name, kind?)
Net.fire(name, player, ...)
Net.fireAll(name, ...)
Net.fireList(name, players, ...)
Net.fireUnreliable(name, player, ...) / Net.fireAllUnreliable(name, ...)
-- client
Net.send(name, ...)
Net.invoke(name, ...) -> ... (15 s timeout)
Net.listen(name, handler, unreliable?)
```

Rate limiting is built in (`opts = {rate, burst}`). **Validate every argument with `Guard`.** Never trust client
numbers.

**Replicated state:**
- `DataService:Replicate(player, key)` pushes a top-level key to its owner (batched every 0.2 s).
- The client `Store` controller reads it: `Store:Get(key)`, `Store:GetPath("a.b")`, `Store:Changed(key)`,
  `Store:Wait(key)`, `Store:GetGlobal(key)`, `Store:GlobalChanged(key)`, `Store.Loaded`, `Store:IsLoaded()`.
- Global keys are set with `DataService:SetGlobal`: `events`, `serverInfo`, `market` (light summary).
- Private keys never replicate: `receipts`, `audit`, `flags`, `_session`.
- `_session` is a per-session scratch table (never saved).
- Wire protocol: `Data.Key(key, value, seq)`, `Data.Global(key, value, gseq)`, `Data.Snapshot`. Read through
  `Store` only.

**Time:** `Time.now()` in services; Logic takes `now`. Clocks: `Time.DAY_LEN` (market day 360 s),
`Time.REVIEW_WINDOW` (40 active min = 1 work week), `Time.WORKDAY` (8 active min).

**Rng/Hash:** deterministic; never `math.random`/`Random` in Logic or builders.

## 3. Player data (DataService, owned by `data`)

`Config/DataTemplate/init.luau` merges sibling modules (`{ [key] = default }`, plus an optional `_private` set). On
load, DataService deep-fills missing fields, so adding fields is safe.

| Key | Owner | Contents others may read |
|---|---|---|
| `meta` | data | `{schema, createdAt, lastSeen, sessions, activeSec, backupDay, backupSlot}` |
| `profile` | careerCore | `{built, firstName, familyName, school = {id, rarity}, degree = "bs"|"ms", gpa, family = {id, rarity}, clubs = {{id, rarity}}, perks = {[perkId] = count}, stats = {knowledge, skill, speed, charisma, network, discipline, risk, luck}, statXp = {}, ovr, archetype, focus, outfitRoll = {brand, rarity, itemIds}, rerollsLeft, refreshTokens, credits = {reroll, rebuild}, rebirths, incomeMult, pending}` |
| `career` | careerPath | `{level, xp, track, companyId, roleId, rank, title, status, reputation, week, weekday, weekActive, reviewDue, reviews = {}, signatures = {}, plaques = {{id, name, at, quality}}, prestige, wipeouts, comebacks, history = {}, offers = {}, applications = {}, connections = {[companyId] = n}, rival = {...}, xpToNext, promotion = {ready, missing = {string}}, fitScore, outfitLevel, lifeStartActive}` |
| `portfolio` | market | `{cash, positions = {[ticker] = {shares, avgCost}}, bookSize, realized, trades = {}, weekReturns = {}, peak, violations, credits = {capital}, paidCapital}` (positions are session-only: flattened on leave, §6) |
| `work` | work | `{completed = {[taskId] = n}, quality = {}, coreDone, lastTaskAt, cooldowns = {}}` |
| `projects` | projects | `{[projectId] = state}` |
| `campus` | tutorial | `{step, quests = {}, offer = false, applications = {}, club = false}` |
| `wallet` | shop | `{cash, earned, spent}` |
| `inventory` | wardrobe | `{owned = {[itemId] = true}, equipped = {[slot] = itemId}, presets = {}, wearAvatar = false}` |
| `housing` | shop | `{owned = {[decorId] = true}, placed = {[context] = {[slotId] = decorId}}, theme}` |
| `mail` | phone | `{inbox = {{id, from, subject, body, at, read, kind, data}}, nextId}` (ring of 60) |
| `daily` | careerCore | `{lastDay, streak, boosts = {{kind, mult, endsAt}}}` |
| `season` | monetization | `{id, xp, premium, claimed = {free = {}, premium = {}}, cosmetics = {}}` |
| `entitlements` | monetization | `{passes = {}, products = {}, robuxSpent, pending = {}}` |
| `boards` | leaderboards | last submitted values |
| `achievements` | tutorial | `{[achievementId] = unixTime}` |
| `settings` | ui | `{music, sfx, reducedMotion, showTicker, uiScale, showAuras}` |
| `receipts`, `audit`, `flags` | private | as before |

## 4. Career core (owned by `careerCore`): life roll, stats, rebirth, aura, daily

Rarity ids: `common uncommon rare epic legendary mythic`. `Config/Rarity` exports
`Rarity.list = { {id, name, odds, color, order} }`, `Rarity.get(id)` and `Rarity.oddsFor(rebirths)` (the v3 §1 shift).

```lua
ProfileService:GetProfile(player) -> profile?
ProfileService:GetStats(player) -> {knowledge, skill, speed, charisma, network, discipline, risk, luck}
ProfileService:GetStat(player, statId) -> number          -- 1..99
ProfileService:GetOVR(player) -> number
ProfileService:AwardStatXp(player, statIds: {string}, quality: number, source)  -- the ONLY way stats grow (focus applied inside)
ProfileService:HasPerk(player, perkId) -> boolean
ProfileService:ConsumePerk(player, perkId) -> boolean     -- e.g. "alumni_lifeline"
ProfileService:GrantCredit(player, "reroll" | "rebuild")  -- monetization (one reroll credit = one single-field reroll)
ProfileService:AddRefreshToken(player, n, source)
ProfileService:GetIncomeMult(player) -> number            -- rebirth multiplier (1.0..3.0)
ProfileService:GetSchoolTierOrder(player) -> number       -- 1 common .. 6 mythic (perk Boardroom Pedigree adds 1 for gating)
ProfileService.ProfileLocked : Signal(player)             -- life roll finished (first time and after each rebirth)
RebirthService:CanRebirth(player) -> (boolean, reason?)
RebirthService.Rebirthed : Signal(player, count)
DailyService:GetBoostMult(player, kind: "money"|"xp") -> number   -- active daily boosts (stack with events)
AuraService                                               -- server sets attribute AuraTier (0..5) on characters; AuraController renders
```

Rebirth: `RebirthService` (careerCore) runs the reset. It calls `CareerService:ResetForRebirth(player)` (careerPath
resets `career`, keeping `plaques`, `signatures`, `prestige` history and the comeback/wipeout counters) and
`PortfolioService:ResetForRebirth(player)` (market). It resets `work`, `projects` and `campus` to template defaults
itself, rerolls `profile` through a new Life Roll, and increments `profile.rebirths`/`incomeMult`. Cash, inventory,
housing, achievements and season data are never touched.

Stat effect helpers (pure, `Logic/Stats`) that work and project code use:

```lua
Stats.timerMult(speed) -> number           -- 0.8..1.2
Stats.hintCount(knowledge) -> 0..3
Stats.toleranceMult(skill) -> 1..1.5
Stats.charismaBonus(charisma) -> 0..8
```

Other modules: `Config/LifeRoll` (schools with crest specs, degrees, families, clubs with rarity/boosts/perks, stat
rules, archetypes, focus areas), `Logic/LifeRoll`, `Logic/Stats`, `Logic/Rebirth`, `Logic/DailyRewards`.

## 5. Career path (owned by `careerPath`): tracks, companies, levels, reviews, offers, rival

Track ids are `ib st pe credit wm am er corpbank vc re corp`. `Config/Tracks` holds each track's
`{id, name, entryTitle, ladder = { {rank, title, roleId, schoolGate?} }, difficulty, levelBands}`. Role ids look
like `ib_analyst`, `pe_senior_associate`, `corp_ceo`. Rank 0 = student, 1 = entry; the top index varies by track.

`Config/Companies` holds each company:
`{id, name, short, type, departments = {trackId}, colors = {primary, accent, text}, logo = logoId, tier,
payMult, bookMult, prestigeMult, minOutfitLevel, culture, bossNames = {[track] = name}, tagline, hiring =
{[track] = {eligibility}}}`.

```lua
CareerService.LevelChanged    : Signal(player, newLevel, oldLevel)
CareerService.RoleChanged     : Signal(player, newRoleId, oldRoleId, reason)  -- "hired"|"promotion"|"fired"|"lateral"|"reentry"|"reinstated"|"rebirth"
CareerService.StatusChanged   : Signal(player, new, old)                       -- active|probation|fired
CareerService.ReviewCompleted : Signal(player, review)                         -- {score, band, outcome = "promoted"|"keep_going"|"warning"|"fired", components, at, week}
CareerService:GetRole(player) -> roleDef?
CareerService:GetRank(player) -> number
CareerService:GetTrack(player) -> trackId?
CareerService:GetCompany(player) -> companyDef?
CareerService:GetLevel(player) -> number
CareerService:GetStatus(player) -> string
CareerService:IsEmployed(player) -> boolean
CareerService:IsEmployeeOf(player, companyId) -> boolean   -- used by every office interaction
CareerService:AddXP(player, amount, source) -> number
CareerService:AddReputation(player, amount, source)
CareerService:RecordWork(player, {taskId, quality, onTime, core, category, clientFacing?})
CareerService:RecordDeal(player, dealId, name, quality)    -- signature/project completion -> plaque + Deal Mastery
CareerService:GetRiskLimitMultiplier(player) -> number
CareerService:GrantOffer(player, offer)                     -- offer = {companyId, track, rank, source}; recruiting/email/headhunter
CareerService:AcceptOffer(player, offerId) -> (ok, err)
CareerService:GetWeek(player) -> (week, weekday)
CareerService:GetClientBonus(player) -> number              -- 1.0..1.1 (fit and dress code)
CareerService:GetOutfitLevel(player) -> number              -- 1..5 (v3 §5)
CareerService:MassFiring(companyId, reason) -> {players fired, players saved}  -- events
CareerService:GrantReinstatementCredit(player)
CareerService:GetBoardValues(player) -> {prestige, deal, comeback, fastestRunSec?}
CareerService:ResetForRebirth(player)
OfferService:AddConnection(player, companyId, amount, source)  -- networking events and NPC conversations
OfferService:GetConnections(player) -> {[companyId] = number}
OfferService:SendInvite(player, eventKind)                      -- networking invitations by email (EmailService)
ActivityService:GetActiveSeconds(player) -> number
ActivityService.ActiveTick : Signal(player, dt)
```

Boss reviews: the `boss_review` interact on each floor (OfficeAnchor `review_spot`/`boss_chair`) opens the weekly review
meeting when `career.reviewDue` and the player is an employee. The remote phone review applies after 10 overdue active
minutes. Logic modules: `Logic/Review`, `Logic/CareerState`, `Logic/Promotion` (requirements incl. outfit level and the
school gate), `Logic/Recruiting`, `Logic/Rival`, `Logic/FitScore`, `Logic/Leveling`.

## 6. Market (owned by `market`): per-server market

The market runs per server from a random server seed (v3 §11). Tickers: `APX NMB MRB VLT SMT TTN HBR CRL ORN BLF`
(`Config/Tickers`), benchmark `ST10`. Future prices are never replicated.

```lua
MarketService.Tick : Signal(now, prices)                    -- every 2 s
MarketService:GetPrice(ticker) / :GetPrices() / :GetQuote(ticker)
MarketService:GetCompanyFacts(ticker) -> {...}              -- fundamentals for tasks
MarketService:GetResearchSignal(ticker, quality) -> {direction, confidence}
MarketService:GetNews(limit) -> {...}
MarketService:TriggerEvent(eventId, params) -> boolean      -- events feature: crash|boom|flash_crash|meme_rally|rate_shock|earnings_frenzy|crazy_day|fed_day|holiday
MarketService:GetActiveEvent() -> {id, startsAt, endsAt, params}?
PortfolioService.Traded : Signal(player, trade)
PortfolioService.RiskViolation : Signal(player, info)
PortfolioService:GetEquity(player) -> number
PortfolioService:GetInvested(player) -> number              -- live market value of open positions
PortfolioService:GetWindowMetrics(player, fromActive, toActive) -> {twr, benchReturn, excess, maxDrawdown, volatility, trades, violations, active}
PortfolioService:SetBookSize(player, size, reason)
PortfolioService:WipeBook(player) -> number
PortfolioService:GrantCapitalCredit(player)
PortfolioService:FlattenAll(player, reason)                -- closes positions (on leave/shutdown)
PortfolioService:GetSeasonSkill(player) -> number?
```

## 7. Economy, shop, housing (owned by `shop`)

```lua
EconomyService:GetCash(player)
EconomyService:AddCash(player, amount, source, kind?)       -- salary/bonus: × EventService salaryMult × DailyService money boost × ProfileService:GetIncomeMult
EconomyService:SpendCash(player, amount, reason) -> boolean
EconomyService:ChargeLiving(player, amount) -> number
EconomyService.CashChanged : Signal(player, newCash, delta)
ShopService:GrantItem(player, itemId, source) -> boolean   -- wearable or decor (idempotent)
HousingService:GetAssignment(player) -> {context, unit?, desk?, office?}
HousingService:RefreshPlaques(player)                      -- career calls after RecordDeal; renders plaques on desk/bookshelf (v3 §13)
```

## 8. Work tasks (owned by `work`/`work2`; any feature may add task modules)

```lua
-- Shared/Logic/Tasks/<taskId>.luau
return {
  id, title, desc,
  tracks = {"ib"} | nil, ranks = {1, 2} | nil, student = boolean?, -- availability
  category = "academics"|"networking"|"interview"|"work"|"client"|"reentry"|"campus"|"headtohead",
  core = true, stats = {"skill", "knowledge"}, clientFacing = false,
  timeLimit, baseXp, basePay, cooldown,
  generate = function(rng, ctx) return payload, secret end,
    -- ctx = {level, rank, track, stats, ovr, difficulty (0..1), facts, now, hints (0..3), toleranceMult, charismaBonus}
  grade = function(secret, answers, ctx) return {quality, correct, total, feedback} end,
}
WorkService:OfferTask(player, taskId, opts?) -> boolean
WorkService:StartTask(player, taskId, opts?) -> (instanceId?, err?)
WorkService.TaskCompleted : Signal(player, taskId, result)  -- result = {quality, onTime, xp, pay, category, stats}
WorkService:GetLastTaskTime(player) -> number?
```

Rewards: `xp = baseXp × qualityFactor × rankScale × DailyService xp boost`. Pay goes through
`EconomyService:AddCash(..., "salary")`. Each completion calls `CareerService:RecordWork` and
`ProfileService:AwardStatXp(module.stats, quality)`. The timer is multiplied by `Stats.timerMult(speed)` and the
pizza buff.

Payload kinds (renderers `src/client/UI/WorkKinds/<kind>.luau`), as before:

| kind | payload | answers |
|---|---|---|
| `mcq` | `{prompt, questions = {{id, text, options, context?}}}` | `{[qid] = optionIndex}` |
| `fill` | `{prompt, table?, fields = {{id, label, unit?, hint?}}}` | `{[fieldId] = number}` |
| `order` | `{prompt, items = {{id, text}}}` | `{itemId, ...}` |
| `match` | `{prompt, left, right}` | `{[leftId] = rightId}` |
| `spot` | `{prompt, table, maxPicks}` | `{{row, col}, ...}` |
| `alloc` | `{prompt, items, total, step, minEach?, maxEach?}` | `{[itemId] = number}` |
| `dialogue` | `{prompt, speaker, lines = {{id, text, options}}}` | `{[lineId] = optionId}` |
| `call` | `{prompt, items = {{id, label, chart, news}}, options}` | `{[itemId] = optionIndex}` |
| `format` | `{prompt, elements, issues}` | `{[elementId] = {issueId}}` |
| `multi` | `{prompt, sections}` | `{[i] = answers}` |

Every payload has `kind`, `title`, and an optional `hints = {string}`. Renderers expose
`mount(container, payload, api) -> cleanup`.

## 9. Projects / big deals (owned by `projects`; modules may come from any feature)

```lua
-- Shared/Logic/Projects/<id>.luau
return { id, title, track, ranks = {...}, signature = true, stages = {...},
  new(rng, ctx) -> state, view(state, ctx) -> {stage, stageIndex, stageCount, summary, payload}, act(state, answers, ctx) -> (state, result), score(state) -> {quality, metrics} }
ProjectService.ProjectCompleted : Signal(player, projectId, result)
```

State lives in `data.projects[id]`. Completion calls `CareerService:RecordDeal(player, id, dealName, quality)`, which
creates the deal plaque. Signature deals: `ipo` (IB), `st_book` (S&T), `pe_buyout` (PE), `credit_direct_lending`
(Credit), `wm_client_book` (WM), `am_mandate` (AM/HF), `er_initiation` (ER), `corpbank_facility` (Corp Banking),
`vc_fund` (VC), `re_tower` (RE), `corp_acquisition` (Corp), plus `reentry` (careerPath) and `contract_*` (endgame).

## 10. Wardrobe, logos, characters (owned by `wardrobe` and `logos`)

```lua
-- Config/Catalog: items {id, name, slot, category, price, currency = "cash"|"pass"|"roll"|"heirloom", pass?, minRank?,
--   colors, builder, tier (= clothing level 1..5), brand, rarity, desc}; Catalog.brands, Catalog.rollPools[rarity]
Wardrobe.apply(character, equipped, opts) -- opts.companyLogo = logoId: drawn ONLY on vest/quarter-zip items (v3 §16)
Wardrobe.clear(character)
WardrobeService:ApplyLook(player) / :Equip(player, slot, itemId) / :Grant(player, itemId, source) / :Owns(player, itemId)
NpcRig.build(opts) -> Model ; NpcRig.spawn(opts) -> Model
-- Shared/Assets/Logos (logos feature, bake-safe):
Logos.render(container: GuiObject, logoId: string, opts?) -> Frame  -- company ids, school ids, brand ids; unknown -> monogram
Logos.surface(part: BasePart, face: Enum.NormalId, logoId, opts?) -> SurfaceGui
Logos.has(logoId) -> boolean
```

## 11. Offices (owned by `offices`)

```lua
OfficeService:EnterCompany(player, companyId, floor?: "lobby"|trackId) -> (ok, err)  -- creates the instance/floor lazily, teleports
OfficeService:GetInstance(companyId) -> Model?            -- lobby + floors (Model attribute CompanyId)
OfficeService:GetFloor(companyId, trackId) -> Model?      -- floor model (attributes CompanyId, Department, LightingPreset)
OfficeService:GetPlayerLocation(player) -> {companyId, floor}?
OfficeService.FloorCreated : Signal(companyId, trackId, model)     -- housing, NPCs and events listen
OfficeService.FloorRemoved : Signal(companyId, trackId)
WorldService:Teleport(player, cframe, opts?) -> ok          -- fade, streaming request, PivotTo, cooldown
WorldService.ZoneChanged : Signal(player, zoneId)
```

- Floors are cloned from `ServerStorage.FirmTemplates[<trackId>]`, the lobby from `[lobby]`, placed with
  `World.officeOrigin(instanceIndex, floorIndex)`. They're branded server-side on clone: parts tagged `CompanyLogo` get
  `Logos.surface` with the company logo; TextLabels named `CompanyName` get the name; parts tagged `FirmColor` get the
  primary colour. Empty floors are removed after 3 minutes.
- `CareerService:IsEmployeeOf` also returns true for the partner company while `merger_mania` pairs two companies
  (EventService:IsActive and its event data).
- Visitors can walk around but every interaction inside an instance must check
  `CareerService:IsEmployeeOf(player, instance.CompanyId)`. Prompts are hidden client-side for visitors
  (attribute-driven) and refused server-side.

Template markers: see `Config/World.templateMarkers`, `World.floorSlots` and `World.templateEventSpots`.
- Every floor has exactly 24 `DeskSlot` models (each with 3 `DecorSlot` of `SlotKind = "plaque"` plus 2 desk decor
  slots) and 8 `OfficeSlot` models (each with a bookshelf holding 24 plaque slots, decor slots, a `Nameplate`, and
  `ThemeWall`/`ThemeFloor` tags).
- `OfficeAnchor` markers: `floor_entry`, `boss_chair`, `review_spot`, `rival_desk` (and on the lobby: `entry`,
  `elevators`, `receptionist`). `OfficeDoor` markers: `to_lobby` (and `exit` on the lobby).
- Interacts: `work_desk`, `terminal`, `project_desk`, `boss_review`, `housing_panel` (Context desk/office),
  `elevator_panel` (lobby).

## 12. Phone and email (owned by `phone`)

```lua
EmailService:Send(player, mail) -> mailId   -- mail = {from, subject, body, kind = "offer"|"invite"|"hr"|"rival"|"event"|"system", data?, actions? = {{id, label}}}
EmailService.Action : Signal(player, mailId, actionId, data)   -- e.g. "accept_offer", "apply", "rsvp"
PhoneController:Open(appId?)                                   -- client; apps: mail calendar stats directory market contacts
PhoneController:RegisterApp({id, title, glyph, order, open})
```

## 13. Events (owned by `events`): per server

The global `events` key:
`{ weather?, bonus?, chaos?, market?, corporate?, upcoming = {...} }`, where each entry is
`{id, startsAt, endsAt, data}`.

```lua
EventService:IsActive(eventId) -> boolean
EventService:GetModifier(name) -> number    -- salaryMult taskPayMult taskCooldownMult shopDiscount interviewBonus offerBonus bonusMult ipoMult reputationMult
EventService:GetPlayerBuff(player, name) -> number
EventService.EventStarted / EventEnded : Signal(family, eventId)
```

Event ids:
- Weather: `clear fog rain storm snow heatwave blackout`
- Market: `crash boom flash_crash meme_rally rate_shock earnings_frenzy crazy_day fed_day holiday`
- Corporate: `mass_firing bonus_season hiring_spree merger_mania regulatory_audit ipo_frenzy`
- Bonus: `recruiting_fair fashion_week mixer`
- Chaos: `fire_drill ceo_walkthrough pigeons pizza_party golden_briefcase elevator_outage`

## 14. Feature ownership (v3)

| Feature | Owns |
|---|---|
| foundation | `default.project.json`, `Net`, `Guard`, `Util/*`, `Build/*`, `Config/World`, `Config/DataTemplate/init`, `src/server/Main+Registry`, `src/client/Main+Registry`, `tools/*`, `tests/foundation` |
| data | `DataService`, `AuditService`, `Logic/{SessionLock,Migrations,DataUtil}`, `DataTemplate/Meta`, `Controllers/Store` |
| ui | `UI/Theme`, `UI/Kit/*`, `UI/Sfx`, `UIController`, `HudController`, `NotifyService`, `SettingsService`, `UI/Screens/{Menu,Settings}`, `Config/{Sounds,Strings}`, `DataTemplate/Settings` |
| props | `Assets/Props/*`, `Assets/Signs/*` |
| wardrobe | `Config/Catalog/*`, `Config/ClothingIds`, `Assets/Wardrobe/*`, `Assets/Npc/*`, `WardrobeService`, `WardrobeController`, `UI/Screens/Wardrobe`, `tools/clothing/*`, `assets/clothing/*`, `DataTemplate/Inventory` |
| logos | `Assets/Logos/*` (company logos, school crests, brand marks incl. the Pan Miller windmill, Anaeio, Lotus) |
| market | `Config/Tickers`, `Logic/Market/*`, `Logic/Portfolio/*`, `MarketService`, `PortfolioService`, `TerminalController`, `UI/Screens/Terminal*`, `DataTemplate/Portfolio` |
| careerCore | `Config/{Rarity,LifeRoll}`, `Logic/{LifeRoll,Stats,Rebirth,DailyRewards}`, `ProfileService`, `RebirthService`, `DailyService`, `AuraService`, `Controllers/{CareerCoreController,AuraController}`, `UI/Screens/{LifeRoll,Stats,MorningBrief,Rebirth}`, `DataTemplate/{Profile,Daily}` |
| careerPath | `Config/{Tracks,Companies}`, `Logic/{Leveling,Review,CareerState,Promotion,Recruiting,Rival,FitScore}`, `CareerService`, `ReviewService`, `ActivityService`, `RivalService`, `OfferService`, `Controllers/CareerController`, `UI/Screens/{Career,CareerServices,Offers,ReviewMeeting}`, `Logic/Projects/reentry`, `DataTemplate/Career` |
| phone | `EmailService`, `Controllers/PhoneController`, `UI/Screens/Phone*`, `DataTemplate/Mail` |
| work | `WorkService`, `Controllers/WorkController`, `UI/WorkKinds/*`, `UI/Screens/Work*`, `Config/Tasks`, `Logic/Tasks/` (student + ib, er, corpbank, corp entry/core tasks + `_shared`), `DataTemplate/Work` |
| work2 | `Logic/Tasks/` (st, pe, credit, wm, am, vc, re tasks + senior/client/head-to-head/reentry tasks + `_senior`), `Logic/Projects/ipo` |
| projects | `ProjectService`, `Controllers/ProjectController`, `UI/Screens/Project*`, `Logic/Projects/{st_book,pe_buyout,credit_direct_lending,wm_client_book,am_mandate}`, `DataTemplate/Projects` |
| projects2 | `Logic/Projects/{er_initiation,corpbank_facility,vc_fund,re_tower,corp_acquisition,contract_*}` |
| events | `Config/Events`, `Logic/EventDirector`, `EventService`, `Controllers/{EnvironmentController,EventFxController}`, `UI/Screens/Events`, `Assets/EventProps/*` |
| shop | `Config/{Decor,Shop}`, `Logic/Economy`, `EconomyService`, `ShopService`, `HousingService`, `Controllers/ShopController`, `UI/Screens/{Shop,Housing}*`, `DataTemplate/{Wallet,Housing}` |
| offices | `OfficeService`, `WorldService`, `Logic/DoorRules`, `Controllers/{WorldController,OfficeController}`, `UI/Screens/{Directory,Elevator}` |
| officesA | `src/world/{OfficeLobby,OfficeFloorsA}*` |
| officesB | `src/world/{OfficeFloorsB,OfficeFloorsC}*` |
| campus | `src/world/{Campus,CampusInteriors}*` |
| street | `src/world/Street*` |
| venues | `src/world/{CareerServices,ExecClub,Rooftop,Apartments,Galleria}*` |
| monetization | `Config/{Products,Season}`, `Logic/{Receipts,SeasonPass}`, `MonetizationService`, `SeasonService`, `Controllers/StoreController`, `UI/Screens/{Store,SeasonPass}`, `DataTemplate/{Season,Entitlements,Receipts}` |
| leaderboards | `Config/Leaderboards`, `Logic/Scores`, `LeaderboardService`, `AntiCheatService`, `Controllers/LeaderboardController`, `UI/Screens/Leaderboards`, `DataTemplate/{Boards,Flags}` |
| tutorial | `TutorialService`, `QuestService`, `NpcService`, `DialogueService`, `SocialService`, `AchievementService`, `Config/{Npcs,Dialogue,Quests,Achievements}`, `Logic/{QuestLine,Dialogue}`, `Controllers/{TutorialController,SocialController}`, `UI/Screens/{Dialogue,Quests,ProfileCard,Recruiting}`, `DataTemplate/{Campus,Achievements}` |

Other documented calls:

```lua
NotifyService:Notify(player, text, kind?) / :NotifyAll(text, kind?) / :Banner(playerOrNil, {title, subtitle, style, duration}) / :Ticker(text)
QuestService:SetObjective(player, questId, text) / :Complete(player, questId)
DialogueService:Open(player, npcId, dialogueId)
SeasonService:AddSeasonXP(player, amount, source)
MonetizationService:OwnsPass(player, key)    -- "ExecutiveClub"|"CornerOffice"|"OfficeThemes"|"MorningBriefPremium"
MonetizationService:GetRobuxSpent(player) -> number
LeaderboardService:Submit(player, boardId, value)  -- CareerPrestige MarketSkill DealMastery FastestRun Comeback RobuxSpent TimePlayed LiveInvested Rebirths TopStats
AntiCheatService:Flag(player, kind, details) / :IsFlagged(player)
SocialService:GetXpBoost(player) / :ConsumeXpBoost(player)
UIController:Open(id, args?) / :Close(id) / :Toggle(id) / :RegisterMenuTab({id, title, glyph, order, screen, quick?})
HudController:SetObjective(text) / :Flash(text, kind)
```

Client screens: `src/client/UI/Screens/<Id>.luau` returning `{id, open(args, root, ctx) -> {close}}`.

## 15. Bake-safe rules (Shared/Build, Shared/Assets, src/world)

Allowed:
- `Instance.new`, properties, `.Parent`, `.Name`, attributes, tags (`AddTag`/`HasTag`), `FindFirstChild`/`GetChildren`/
  `GetDescendants`/`Clone`/`Destroy`/`IsA`
- the Roblox datatypes
- `math string table`, `Shared/Util/*`
- GUI instances

Forbidden: `game`, `workspace`, `task`, any service, `PivotTo`/`GetPivot`/`GetBoundingBox`, CSG, `TweenService`,
`Random`/`math.random`, clocks, asset ids.

## 16. Canonical ids (shared by config, logos and world builders)

- **School ids:**
  - Common: `eastbridge_state coastal_cc midvale riverbend pinecrest_state union_valley_tech`
  - Uncommon: `lakeshore granite_tech harborview`
  - Rare: `northfield ridgemont`
  - Epic: `kingsbridge ashworth`
  - Legendary: `whartonia stanfjord`
  - Mythic: `harvale`
- **Company ids:** `mg_freeman goldfield_saxe morrow_stanton merriweather_lynch evermoor lazaro_freres centerline
  harrow_williams blairmont houlton_lockey sterling_vance eastbridge_capital anaeio bluestone krk ironclad aresmont
  gray_heron bridgecrest citrine quantum_ridge lotus_wealth sequel a17z seedline brookfold keystone northwind
  applewood`
- **Logo ids:** the company id, the school id, or `brand_<brandId>` for clothing brands (e.g. `brand_pan_miller`).
- **Track ids:** `ib st pe credit wm am er corpbank vc re corp`
