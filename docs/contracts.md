# The Street — Code Contracts

This file is the single source of truth for **interfaces between features**. A feature may change its
internals freely but must not change anything in this file without updating every caller. If you need a
new cross-feature API, add it here in the owning feature's section.

Design numbers live in `docs/superpowers/specs/2026-10-15-the-street-design.md`.

---

## 1. Rojo tree

| DataModel path | Source dir | Notes |
|---|---|---|
| `ReplicatedStorage.Shared` | `src/shared` | Shared modules (server + client). |
| `ServerScriptService.Server` | `src/server` | `Main.server.luau`, `Registry.luau`, `Services/*`, `Private/*`. |
| `ServerStorage.WorldBuilders` | `src/world` | World/zone builders (baked by Lune, callable at runtime). |
| `StarterPlayer.StarterPlayerScripts.Client` | `src/client` | `Main.client.luau`, `Registry.luau`, `Controllers/*`, `UI/*`. |
| `Workspace.World` | `build/World.rbxm` | Produced by `lune run tools/bake`. Never edit by hand. |
| `Workspace.Handmade` | `src/handmade` (optional `.rbxm`) | Owner's hand-edited content survives rebuilds. |

Shared layout:

```
src/shared/
  Net.luau                 remote registry (foundation)
  Guard.luau               argument validation (foundation)
  Util/                    Signal, Rng, Hash, Time, Format, TableUtil (foundation)
  Config/                  pure data tables (each file owned by one feature; see §12)
    World.luau             zones, anchors, doors, interiors, interaction ids (foundation)
    DataTemplate/          per-feature default profile data, merged by init.luau (§3)
  Logic/                   PURE logic (no Roblox services, no clocks): unit-tested in Lune
    Tasks/<taskId>.luau    work task modules (§7)
    Projects/<id>.luau     multi-step project modules (§8)
  Build/                   Kit.luau, Palette.luau (foundation): bake-safe builder primitives
  Assets/                  bake-safe asset builders: Props/, Wardrobe/, Signs/, Npc/
```

## 2. Runtime frameworks (foundation-owned)

### Server services
`src/server/Services/<Name>.luau` is auto-discovered by `Main.server.luau`.

```lua
local Service = { Name = "MarketService", Priority = 20 } -- lower Priority inits first (default 100)
function Service:Init() end   -- create remotes, connect signals. No yielding. No DataStore calls.
function Service:Start() end  -- spawned with task.spawn; loops and DataStore work go here.
return Service
```

Other services are reached lazily: `local Registry = require(script.Parent.Parent.Registry)` then
`Registry.CareerService:AddXP(...)`. Never cache a service at module top level before `Init`.
A missing optional service must not crash the caller: use `Registry.get("Name")`, which returns
nil and logs once.

Priorities: DataService 1, AuditService 2, NotifyService 5, MarketService 10, EventService 15,
everything else defaults to 100.

### Client controllers
`src/client/Controllers/<Name>.luau` has the same shape and is reached through
`require(script.Parent.Parent.Registry)`.

### Net (`Shared/Net`)
Remote names are namespaced by feature: `"Market.Trade"`. The server creates remotes lazily on first
use; the client waits up to 30 s.

```lua
-- server
Net.on(name, handler, opts?)          -- RemoteEvent; handler(player, ...). opts = {rate = per-second (default 8), burst = (default rate*3)}
Net.handle(name, handler, opts?)      -- RemoteFunction; handler(player, ...) -> ...; errors are caught -> returns nil, "error"
Net.fire(name, player, ...)
Net.fireAll(name, ...)
Net.fireList(name, players, ...)
Net.fireUnreliable(name, player, ...) / Net.fireAllUnreliable(name, ...)
-- client
Net.send(name, ...)                   -- fire server
Net.invoke(name, ...) -> ...          -- RemoteFunction with 15 s timeout -> nil, "timeout"
Net.listen(name, handler) -> RBXScriptConnection
```

Rate-limited calls are dropped silently (and counted for AntiCheat). **Every handler validates every
argument with `Guard`** (`Guard.str(x, maxLen)`, `Guard.int(x, lo, hi)`, `Guard.num(x, lo, hi)`,
`Guard.oneOf(x, set)`, `Guard.id(x)` for `[%w_%-:]` ids up to 64 characters, and `Guard.map(x, maxKeys)`).
Handlers never trust client-sent prices, amounts, scores or times.

### Replicated player state
- Server: `DataService:Replicate(player, key)` queues top-level key `key` for that player (batched every
  0.2 s, deep-copied).
- Client: the `Store` controller exposes `Store:Get(key)`, `Store:Changed(key) -> Signal(newValue)`,
  `Store:Wait(key, timeout)`, `Store:GetGlobal(key)` and `Store:GlobalChanged(key)`.
- Global state: server `Registry.DataService:SetGlobal(key, value)` replicates to all players. Global
  keys: `events` (§10), `serverInfo`.
- Private keys are never replicated: `receipts`, `audit`, `flags`, `altCareers`, `_session`.

### Time (`Shared/Util/Time`)
- `Time.now()` returns synced server time in seconds (`workspace:GetServerTimeNow()`; `os.time()` in Lune).
- `Logic/*` modules never call it. Callers pass `now` in.

### Rng / Hash (`Shared/Util/Rng`, `Shared/Util/Hash`)
- `Rng.new(seed: number) -> rng` with `rng:next() -> [0,1)`, `rng:int(a, b)`, `rng:range(a, b)`,
  `rng:normal(mean, sd)`, `rng:pick(list)`, `rng:weighted({ {item, weight}, ... })`, `rng:shuffle(list)`,
  `rng:chance(p)`, `rng:clone()`.
- `Hash.u32(...)` returns a deterministic 32-bit hash of numbers/strings; `Hash.unit(...)` returns it in
  [0,1). Use these, never `math.random` or `Random`, in `Logic/`.

## 3. Player data (DataService, owned by `data`)

`Shared/Config/DataTemplate/init.luau` merges every sibling module. Each module returns
`{ [topLevelKey] = defaultValue }`, and the owning feature owns its key. On load, DataService deep-fills
missing fields from the template, so adding fields is always safe.

| Key | Owner | Contents (minimum other features may read) |
|---|---|---|
| `meta` | data | `{ schema, createdAt, lastSeen, sessions, activeSec }` |
| `profile` | career | `{ built, background = {school, gpa, major, region, family, strengths}, stats = {quant, communication, discipline, risk, network}, statXp = {}, refreshTokens, freeRerollUsed, credits = {reroll, rebuild} }` |
| `career` | career | `{ level, xp, roleId, track, status, reputation, rank, reviews = {}, signatures = {}, prestige, wipeouts, comebacks, history = {}, windowStartActive, lastReview }` |
| `portfolio` | market | `{ seasonId, cash, positions = {[ticker] = {shares, avgCost}}, bookSize, realized, trades = {}, flows = {}, peakEquity, violations, credits = {capital}, paidCapital }` |
| `work` | work | `{ completed = {[taskId] = n}, quality = {}, coreDone, lastTaskAt, cooldowns = {}, deal = nil }` |
| `realms` | realms | `{ [projectOrRealmId] = state }` |
| `campus` | tutorial | `{ step, quests = {}, offer = false, interviews = 0, club = false }` |
| `wallet` | shop | `{ cash, earned, spent }` |
| `inventory` | wardrobe | `{ owned = {[itemId] = true}, equipped = {[slot] = itemId}, presets = {}, wearAvatar = false }` |
| `housing` | housing | `{ owned = {[decorId] = true}, placed = {[context] = {[slotId] = decorId}}, theme }` |
| `season` | monetization | `{ id, xp, premium, claimed = {free = {}, premium = {}} }` |
| `entitlements` | monetization | `{ passes = {}, products = {} }` |
| `boards` | leaderboards | `{ prestige, deal, comeback, runBest = {}, skill = {} }` |
| `achievements` | social | `{ [achievementId] = unixTime }` |
| `settings` | ui | `{ music, sfx, reducedMotion }` |
| `receipts` | monetization (private) | `{ [purchaseId] = unixTime }` (ring-trimmed to 200) |
| `audit` | data (private) | ring buffer of 100 entries |
| `flags` | leaderboards (private) | `{ hidden, reasons = {} }` |
| `altCareers` | career (private) | `{ main = {...}, challenge = {...} }` swapped snapshots of the career-scoped keys `profile, career, portfolio, work, realms, campus` |

DataService API:
```lua
DataService.ProfileLoaded    : Signal(player, data)
DataService.ProfileReleasing : Signal(player, data)    -- fired before the final save on leave
DataService:Get(player) -> data?                       -- nil until loaded
DataService:WaitFor(player, timeout?) -> data?
DataService:Replicate(player, key)
DataService:Save(player, reason) -> boolean
DataService:Audit(player, kind: string, details: table)
DataService:SetGlobal(key, value)
DataService:GetGlobal(key)
```

## 4. Career, profile, reviews (owned by `career`)

Role ids and rank order:
`student(0) intern(1) analyst(2) associate(3) vp(4) director(5) md(6)`, then realm bands `band1(7) band2(8) band3(9)`,
then `partner(10) senior_partner(11) founder(12)`.

Realm band role ids: `pe_associate pe_vp pe_principal`, `hf_analyst hf_pm hf_senior_pm`,
`vc_associate vc_principal vc_partner`, `re_analyst re_acquisitions re_director`,
`cd_manager cd_director cd_vp`. Partner tier ids are `partner senior_partner founder` with realm-specific
display titles.

Realm ids: `ib pe hf vc re cd`. Status values: `active review_due coaching probation fired`.

`Shared/Config/Careers.luau` exports:
- `Careers.roles[roleId] = {id, title, rank, minLevel, maxLevel, realm, bookSize, salary, perks}`
- `Careers.rankOf(roleId)`
- `Careers.roleForLevel(realm, level)`
- `Careers.xpForLevel(level)` (XP needed to go from `level` to `level+1`)

```lua
CareerService.LevelChanged  : Signal(player, newLevel, oldLevel)
CareerService.RoleChanged   : Signal(player, newRoleId, oldRoleId, reason) -- "promotion"|"fired"|"reentry"|"reinstated"|"fresh_start"|"realm_switch"|"challenge"|"hired"
CareerService.StatusChanged : Signal(player, newStatus, oldStatus)
CareerService.ReviewCompleted : Signal(player, review)  -- review = {score, band, components = {invest, risk, work, rep}, at}
CareerService:GetRole(player) -> roleDef
CareerService:GetRank(player) -> number
CareerService:GetLevel(player) -> number
CareerService:GetStatus(player) -> string
CareerService:IsEmployed(player) -> boolean            -- rank >= 1 and status ~= "fired"
CareerService:AddXP(player, amount, source) -> number   -- returns XP actually applied (role caps)
CareerService:AddReputation(player, amount, source)
CareerService:TrainStat(player, statId, amount)
CareerService:RecordWork(player, result)                -- result = {taskId, quality: 0..100, onTime: boolean, core: boolean, category: string}
CareerService:RecordSignature(player, signatureId, quality)
CareerService:GetRiskLimitMultiplier(player) -> number  -- 1, or 0.6 on probation
CareerService:HireIntern(player)                         -- called by tutorial when the internship offer is accepted
CareerService:GrantReinstatementCredit(player)           -- monetization (receipt-safe, idempotent per call)
ProfileService:GrantCredit(player, "reroll" | "rebuild") -- monetization
ProfileService:AddRefreshToken(player, n, source)
ProfileService:GetStats(player) -> {quant, communication, discipline, risk, network}
ActivityService:GetActiveSeconds(player) -> number       -- lifetime active seconds (AFK excluded)
ActivityService.ActiveTick : Signal(player, deltaSec)    -- every 10 s while active
```

## 5. Market and portfolio (owned by `market`)

Tickers: `APX NMB MRB VLT SMT TTN HBR CRL ORN BLF`, plus benchmark id `ST10`.

The market secret seed lives only on the server: generated once into DataStore `MarketSecret/v1` with
`UpdateAsync`, or random per session in Studio mock mode. **Never replicate the seed or any future price.**

```lua
MarketService.Tick      : Signal(now, prices)            -- every 2 s; prices = {[ticker] = number, ST10 = number}
MarketService.DayClosed : Signal(dayIndex)
MarketService:GetPrice(ticker) -> number
MarketService:GetPrices() -> {[ticker] = number}
MarketService:GetQuote(ticker) -> {price, open, prevClose, high, low, changePct}
MarketService:GetSeason() -> number
MarketService:GetDayIndex() -> number                    -- market day within season
MarketService:GetCompanyFacts(ticker) -> {name, sector, price, shares, revenue, ebitda, netIncome, eps, growth, debt, cash, peerPe, nextEarningsDay, consensusEps}
MarketService:GetResearchSignal(ticker, quality) -> {direction = "beat"|"miss"|"inline", confidence = 0..1, accurate: boolean (server only)}
MarketService:GetNews(limit) -> { {at, headline, body, tickers, kind} }
MarketService:GetMarketEvents(fromTime, toTime) -> { {id, startsAt, endsAt, announcedAt, params} }  -- global shake-ups (§10)
PortfolioService.Traded        : Signal(player, trade)
PortfolioService.RiskViolation : Signal(player, info)    -- info = {kind, ticker, severity}
PortfolioService:GetEquity(player) -> number
PortfolioService:GetWindowMetrics(player, fromTime, toTime) -> {twr, benchReturn, excess, maxDrawdown, volatility, trades, violations, warningsIgnored, active: boolean}
PortfolioService:SetBookSize(player, size, reason)      -- top-up/down as an external flow (doesn't change returns)
PortfolioService:WipeBook(player) -> number              -- returns the amount lost; resets to max(10%, 5000)
PortfolioService:GrantCapitalCredit(player)              -- monetization
PortfolioService:GetSeasonSkill(player) -> number?       -- risk-adjusted season score, nil if below the activity threshold
```

## 6. Economy, shop, housing (owned by `shop`)

```lua
EconomyService:GetCash(player) -> number
EconomyService:AddCash(player, amount, source, kind?)    -- kind "salary"|"bonus"|"reward"|"refund"; salary/bonus apply EventService salaryMult
EconomyService:SpendCash(player, amount, reason) -> boolean
EconomyService.CashChanged : Signal(player, newCash, delta)
HousingService:GetAssignment(player) -> {unit = n?, desk = n?, office = n?}
```

Catalog items (wardrobe and decor) are bought through `Shop.Buy` (`ShopService`), which checks price,
`pass`, `minRank` and the event discount.

## 7. Work tasks (owned by `work`; task modules may be added by any feature)

Task module `Shared/Logic/Tasks/<taskId>.luau`. WorkService auto-discovers the folder.

```lua
return {
  id = "pitchbook_format", title = "Pitchbook Formatting", desc = "...",
  roles = { "intern", "analyst" },       -- allowed role ids (any realm role id allowed)
  category = "work",                     -- "academics"|"networking"|"interview"|"work"|"evaluation"|"reentry"|"campus"
  core = true, stat = "discipline", timeLimit = 150, baseXp = 140, basePay = 450, cooldown = 0,
  generate = function(rng, ctx) return publicPayload, secret end,
    -- ctx = {level, roleId, rank, stats, difficulty = 0..1, facts = {[ticker] = companyFacts}, now}
  grade = function(secret, answers, ctx) return {quality = 0..100, correct = n, total = n, feedback = {string}} end,
}
```

Both functions are pure (no services). The secret never leaves the server. Reward:
`xp = baseXp * qualityFactor * roleScale`, and `pay` likewise, times `EventService:GetModifier("taskPayMult")`.
Every completion calls `CareerService:RecordWork`, `CareerService:TrainStat`, `EconomyService:AddCash(..., "salary")`
and `SeasonService:AddSeasonXP`.

**Payload kinds** (rendered by `src/client/UI/WorkKinds/<kind>.luau`, owned by `work`):

| kind | payload | answers |
|---|---|---|
| `mcq` | `{prompt, questions = {{id, text, options = {string}, context?}}}` | `{[qid] = optionIndex}` |
| `fill` | `{prompt, table? = {headers, rows}, fields = {{id, label, unit?, hint?}}}` | `{[fieldId] = number}` |
| `order` | `{prompt, items = {{id, text}}}` | `{itemId, ...}` (in order) |
| `match` | `{prompt, left = {{id, text}}, right = {{id, text}}}` | `{[leftId] = rightId}` |
| `spot` | `{prompt, table = {headers, rows}, maxPicks}` | `{{row, col}, ...}` |
| `alloc` | `{prompt, items = {{id, text, info?}}, total = 100, step = 5, minEach?, maxEach?}` | `{[itemId] = number}` |
| `dialogue` | `{prompt, speaker, lines = {{id, text, options = {{id, text}}}}}` | `{[lineId] = optionId}` |
| `call` | `{prompt, items = {{id, label, chart = {number}, news = {string}}}, options = {string}}` | `{[itemId] = optionIndex}` |
| `format` | `{prompt, elements = {{id, text, style = {font, size, align, color}}}, issues = {{id, label}}}` | `{[elementId] = {issueId, ...}}` |
| `multi` | `{prompt, sections = {payload, ...}}` | `{[sectionIndex] = answers}` |

Every payload has `kind` and `title`. Renderer interface:
`mount(container: Frame, payload, api) -> cleanup()`, where `api = {setAnswers(answers), theme}`.

## 8. Multi-step projects (owned by `realms`; project modules may be added by any feature)

Project module `Shared/Logic/Projects/<projectId>.luau`. ProjectService auto-discovers the folder.
Used for the IB IPO signature (`ipo`, written by `work`), realm signature projects (`pe_buyout hf_mandate
vc_fund re_tower cd_acquisition`), partner firm (`partner_firm`), endgame contracts (`contract_*`) and
re-entry (`reentry`, written by `career`).

```lua
return {
  id = "pe_buyout", title = "...", realm = "pe", roles = { "pe_associate", ... }, signature = true,
  stages = { "screen", "bid", "finance", "operate", "exit" },
  new = function(rng, ctx) return state end,                     -- full server state (serializable, no Instances)
  view = function(state, ctx) return { stage, stageIndex, stageCount, summary = {...}, payload = <§7 payload> } end,
  act = function(state, answers, ctx) return state, { ok, message, done, quality? } end,
  score = function(state) return { quality = 0..100, metrics = {...} } end,
}
```

State persists in `data.realms[projectId]`. Completion of a `signature` project calls
`CareerService:RecordSignature(player, projectId, quality)`.

## 9. Wardrobe, characters, NPC rigs (owned by `wardrobe`)

`Shared/Config/Catalog.luau` exports `Catalog.items[itemId] = {id, name, slot, category, price, currency = "cash"|"pass",
pass?, minRank?, colors, builder, tier, desc}`. Slots: `top outer bottom shoes neck wrist eyes head bag`.

```lua
Wardrobe.apply(character: Model, equipped: {[slot] = itemId}, opts) -- Shared/Assets/Wardrobe/init.luau; bake-safe; builds fitted layers into folder "CareerLook"
Wardrobe.clear(character)
WardrobeService:ApplyLook(player)                  -- server: standardizes the body, then Wardrobe.apply
WardrobeService:Equip(player, slot, itemId) -> ok
NpcRig.build({name, skin, equipped, hairStyle, hairColor}) -> Model  -- Shared/Assets/Npc/Rig.luau; R15-named Parts; bake-safe
NpcRig.spawn(...) -> Model                         -- server runtime: Players:CreateHumanoidModelFromDescription + Wardrobe.apply
```

## 10. Events (owned by `events`)

Global market shake-ups are computed by `market` (`MarketService:GetMarketEvents`). EventService adds
server-local weather, bonus and chaos events and presents all four families.

```lua
-- Global replicated key "events":
{ weather = {id, startsAt, endsAt, intensity}?, bonus = {id, startsAt, endsAt}?, chaos = {id, startsAt, endsAt, data}?,
  market = { {id, startsAt, endsAt, announcedAt, params}, ... }, upcoming = { ... } }
EventService:IsActive(eventId) -> boolean
EventService:GetModifier(name) -> number     -- names: salaryMult taskPayMult taskCooldownMult shopDiscount interviewBonus reputationMult (default 1, or 0 for shopDiscount/interviewBonus)
EventService:GetPlayerBuff(player, name) -> number   -- "taskTimer" (1 = none)
EventService.EventStarted : Signal(family, eventId)
EventService.EventEnded   : Signal(family, eventId)
```

Event ids:
- Weather: `clear fog rain storm snow heatwave blackout`
- Market: `crazy_day flash_crash earnings_frenzy rate_shock meme_rally`
- Bonus: `recruiting_fair bonus_day deal_rush fashion_week mixer`
- Chaos: `fire_drill ceo_walkthrough pigeons pizza_party golden_briefcase elevator_outage`

## 11. World (foundation config, world agents build)

`Shared/Config/World.luau` (authoritative) defines regions, zones (AABBs with lighting preset and
theme), anchors, doors, interior slots and interaction ids. Builders (`src/world/<Zone>.luau`) return
`build(parent: Instance) -> Model` and must:
- place geometry only inside their region or interior slot bounds
- create every anchor and door they're responsible for, using `Kit.anchor(parent, anchorId, cframe)` and
  `Kit.door(parent, doorId, cframe, size)`
- tag interaction points with `Kit.interact(part, interactId, attrs)`. `interactId` must be listed in
  `World.interactIds`, and the owning feature wires the ProximityPrompt at runtime
- keep within their part budget (checked by bake).

Instance conventions (bake-safe, since Lune supports attributes): anchors carry attribute `AnchorId`, doors
`DoorId`, interaction points `InteractId` plus extras. Housing slots: `DeskSlot = n`, `OfficeSlot = n`,
`UnitSlot = n`, and `DecorSlot = "<slotId>"` with `SlotKind` (`desk_item wall_art floor plant lamp rug chair
monitor`) parented under their slot model. Leaderboard monoliths: a part named `Screen` with attribute
`BoardId`. Event spots: interaction-less parts with attribute `EventSpot = "<id>"` (see `World.eventSpots`).

`WorldService` (owned by `interiorsA`) wires doors, teleports (fade + `PivotTo`), access requirements,
spawn selection by career stage, and region bounds.

Kit marker helpers (all set the attribute **and** a CollectionService tag of the same name):
`Kit.anchor(parent, anchorId, cf)` → tag `Anchor`; `Kit.door(parent, doorId, cf, size)` → tag `Door`;
`Kit.interact(part, interactId, attrs)` / `Kit.interactPoint(parent, interactId, cf, attrs)` → tag `Interact`;
`Kit.npcSpot(parent, npcId, cf)` (an `Interact` with `InteractId = "npc"`); `Kit.eventSpot(parent, spotId, cf)` →
tag `EventSpot`; `Kit.spawn(parent, "Spawn_campus" | "Spawn_street", cf)` → SpawnLocation. Housing slot models
carry `DeskSlot`/`OfficeSlot`/`UnitSlot`/`FirmSlot` attributes and a tag of the same name; decor slots carry
`DecorSlot` + `SlotKind` and tag `DecorSlot`. Exact counts are in `World.housing`. NPC ids per zone are in
`World.npcSpots`, event spots per zone in `World.eventSpots`.

## 12. Feature ownership

| Feature key | Owns |
|---|---|
| foundation | `default.project.json`, `Net`, `Guard`, `Util/*`, `Build/*`, `Config/World`, `Config/DataTemplate/init`, `src/server/Main`, `src/server/Registry`, `src/client/Main`, `src/client/Registry`, `tools/*` core, `tests/foundation/*` |
| data | `DataService`, `AuditService`, `Logic/Migrations`, `Logic/DataUtil`, `DataTemplate/Meta`, `src/client/Controllers/Store` |
| ui | `src/client/UI/Theme`, `UI/Kit/*`, `UI/Screens/Menu`, `UI/Screens/Settings`, `HudController`, `UIController`, `NotifyService`, `Config/Sounds`, `Config/Strings`, `DataTemplate/Settings` |
| props | `Shared/Assets/Props/*`, `Shared/Assets/Signs/*` (desks, chairs, monitors, lamps, plants, sofas, shelves, cabinets, street furniture, vehicles, signage) |
| wardrobe | `Config/Catalog` (wearables), `Assets/Wardrobe/*`, `Assets/Npc/*`, `WardrobeService`, `WardrobeController`, `UI/Screens/Wardrobe`, `tools/clothing/*`, `Config/ClothingIds`, `DataTemplate/Inventory` |
| market | `Config/Companies`, `Logic/Market*`, `Logic/Portfolio*`, `MarketService`, `PortfolioService`, `TerminalController`, `UI/Screens/Terminal`, `DataTemplate/Portfolio` |
| career | `Config/Careers`, `Config/Backgrounds`, `Logic/ProfileGen`, `Logic/Leveling`, `Logic/Review`, `Logic/CareerState`, `ProfileService`, `CareerService`, `ReviewService`, `ActivityService`, `UI/Screens/ProfileBuilder`, `UI/Screens/Career`, `UI/Screens/CareerServices`, `Logic/Projects/reentry`, `DataTemplate/Profile`, `DataTemplate/Career` |
| work | `Config/Tasks`, `Logic/Tasks/*` (student, intern, analyst, associate, VP/MD, evaluation), `WorkService`, `WorkController`, `UI/WorkKinds/*`, `UI/Screens/Work`, `Logic/Projects/ipo`, `DataTemplate/Work` |
| realmsA | `ProjectService`, `ProjectController`, `UI/Screens/Project`, `Logic/Projects/pe_* hf_* vc_*`, `Config/Realms`, `DataTemplate/Realms` |
| realmsB | `Logic/Projects/re_* cd_* partner_* contract_*`, `UI/Screens/Firm` |
| events | `Config/Events`, `Logic/EventDirector`, `EventService`, `EnvironmentController` (zone lighting, weather FX, day/night), `EventFxController`, `UI/Screens/Events` |
| campus | `src/world/Campus*.luau` |
| street | `src/world/Street*.luau` |
| interiorsA | `src/world/HQ*.luau`, `src/world/CareerServices.luau`, `src/world/ExecClub.luau`, `src/world/Rooftop.luau`, `WorldService`, `WorldController` |
| interiorsB | `src/world/Realm*.luau`, `src/world/Apartments.luau`, `src/world/Galleria.luau`, `src/world/PartnerFirm.luau` |
| shop | `Config/Decor`, `Config/Shop`, `EconomyService`, `ShopService`, `HousingService`, `UI/Screens/Shop`, `UI/Screens/Housing`, `DataTemplate/Wallet`, `DataTemplate/Housing` |
| monetization | `Config/Products`, `MonetizationService`, `SeasonService`, `Config/Season`, `UI/Screens/Store`, `UI/Screens/SeasonPass`, `DataTemplate/Season`, `DataTemplate/Entitlements`, `DataTemplate/Receipts` |
| leaderboards | `Config/Leaderboards`, `LeaderboardService`, `AntiCheatService`, `UI/Screens/Leaderboards`, `DataTemplate/Boards`, `DataTemplate/Flags` |
| tutorial | `TutorialService`, `QuestService`, `NpcService`, `DialogueService`, `SocialService`, `AchievementService`, `Config/Npcs`, `Config/Dialogue`, `Config/Quests`, `Config/Achievements`, `UI/Screens/Dialogue`, `UI/Screens/Quests`, `UI/Screens/ProfileCard`, `DataTemplate/Campus`, `DataTemplate/Achievements` |

Cross-feature calls not listed in §3–§11, documented by their owners:

```lua
NotifyService:Notify(player, text, kind?)               -- kind "info"|"good"|"bad"|"warn"|"cash"|"xp"
NotifyService:NotifyAll(text, kind?)
NotifyService:Banner(playerOrNil, {title, subtitle, style, duration})
NotifyService:Ticker(text)                               -- news ticker line for everyone
QuestService:SetObjective(player, questId, text)
QuestService:Complete(player, questId)
DialogueService:Open(player, npcId, dialogueId)
SeasonService:AddSeasonXP(player, amount, source)
MonetizationService:OwnsPass(player, passKey) -> boolean -- passKey "ExecutiveClub"|"CornerOffice"|"OfficeThemes"
LeaderboardService:Submit(player, boardId, value)        -- boardId "CareerPrestige"|"MarketSkill"|"DealMastery"|"FastestRun"|"Comeback"
AntiCheatService:Flag(player, kind, details)
AntiCheatService:IsFlagged(player) -> boolean
UIController:Open(screenId, args?) / :Close(screenId) / :Toggle(screenId)    -- client
UIController:RegisterMenuTab({id, title, glyph, order, screen})              -- client
HudController:SetObjective(text) / :Flash(text, kind)                        -- client
```

Client screens live in `src/client/UI/Screens/<Id>.luau` and return
`{ id = "Terminal", open = function(args, root: ScreenGui, ctx) return {close = fn} end }`, where
`ctx = {Registry, Net, Theme, Kit}`. UIController auto-discovers them.

## 13. Bake-safe rules (everything under `Shared/Build`, `Shared/Assets`, `src/world`)

These modules run inside Lune at bake time, so they may use **only**:
- `Instance.new`, property assignment, `.Parent`, `.Name`, `:SetAttribute`, `:GetAttribute`, `:AddTag`, `:HasTag`,
  `:FindFirstChild`, `:GetChildren`, `:GetDescendants`, `:Clone`, `:Destroy`, `:IsA`
- the datatypes `Vector3 Vector2 CFrame Color3 BrickColor UDim UDim2 Enum NumberSequence
  NumberSequenceKeypoint ColorSequence ColorSequenceKeypoint NumberRange Font PhysicalProperties Rect Faces Axes`
- `math string table` and `Shared/Util/*`.

**Forbidden:** `game`, `workspace`, `script` (except `require(script.Parent...)`), `task`, `wait`, any
`:GetService`, `:PivotTo`, `:GetPivot`, `:GetBoundingBox`, `:ScaleTo`, CSG, `TweenService`, `Random`,
`math.random`, `tick`, `os.time`, and asset ids. Use `Rng` for variation. Set `Model.PrimaryPart` when
useful.
