# The Street — Full Game Design Spec

Date: 2026-10-15 · Source: `docs/blueprint/The_Street_Game_Design_Blueprint.pdf` (v1.0) · Status: approved direction (Approach A), building.

This spec turns the blueprint into buildable decisions. Where the blueprint gives a rule, it is
repeated here only when we had to choose a number or a mechanism. The blueprint stays the
authority for intent; this document is the authority for numbers and mechanisms; `docs/contracts.md`
is the authority for code interfaces.

## 1. Decisions made with the owner

| Topic | Decision |
|---|---|
| Scope | Entire blueprint: levels 1–100, IB track, six specialist realms + Partner tier, all monetization products, season pass, five leaderboards. |
| Code home | `s3tario/Roblox---The-Street`, Rojo project, built `.rbxl` delivered with each update. |
| Build approach | **A — code-built, baked world.** Every asset is a Luau builder; a Lune bake step renders builders into `build/World.rbxm`, which Rojo bakes into the place so the city is visible in Studio edit mode. |
| Assets | Everything designed in-house: geometry from Parts/Wedges/Cylinders + built-in materials, signage/screens from SurfaceGui, clothing as fitted 3D layers + generated 2D Shirt/Pants templates (upload optional). No external asset IDs are required for the game to look complete. |
| Visual arc | **Campus + tutorial = gritty** (college town, off the Street: brick, rust, cracked asphalt, overcast). **Getting into IB = polished city** (marble, glass, brass, warm crisp light). |
| Random events | Four families, all included: weather/atmosphere, market shake-ups, bonus/social, chaos/fun. |
| Life Roll (v2) | Spin school, family (rarity tiers Common to Mythic), stats and starting outfit; type a first name; 3 rerolls, each rerolling one field (§4). |
| Firms (v2) | Recruiting yields job offers from fictional parody firms (MG Freeman, Anaeio, ...) based on school, GPA and stats (§4b). |
| Extras (v2) | Fit Score and dress codes, Rival, Morning Brief streak, deal-toy shelf, mentorship, headhunters, Mythic moments (§16). |

## 2. Player journey (first hour, then the long arc)

1. **Arrive** at Eastbridge Bus Depot on the edge of campus (gritty). Overcast, flickering lamps.
2. **Life Roll** (Career Center): type your first name, then spin school, family, stats and starting outfit, each
   with a rarity tier (Common to Mythic, odds always shown). Spend 3 single-field rerolls, then lock in (§4).
3. **Student life (L1–8, ~0–3 h):** Academics assignment (GPA-gated), Finance Club mock stock
   pitch, networking events (NPCs + players), coffee chats, mock interviews, then **recruiting**: apply to
   firms, first rounds and Superdays, collect offers and accept one (§4b). Offer → **Subway ride to Wall Street**
   (visual arc switch).
4. **IB Intern (L9–15):** pitchbook formatting, research notes, data cleanup; firm opens a
   practice book in the fictional market.
5. **Analyst → Associate → VP/Director/MD (L16–50):** comps, DCF, earnings reactions, deal
   teams, reviewing analyst output, deadlines, leading deals, mandate pitches. Signature IB
   project: **take a fictional company public (IPO)**.
6. **Exit to a specialist realm (L51–74):** Private Equity, Hedge Fund, Venture Capital, Real
   Estate, Corporate Development — each a distinct loop (§7).
7. **Partner / Portfolio Leader / Family Office (L75–100):** manage a portfolio of businesses or
   assets, signature projects, build and customize your own firm.
8. **Endgame (L100+):** harder contracts, firm customization, legacy goals, seasonal challenges.

Design rule from blueprint, enforced by tests: every 10–15 minutes the player makes a decision,
earns a visible reward, unlocks a task or gets feedback. The tutorial quest tracker always shows
the next concrete step.

## 3. Time model

All gameplay clocks are server-authoritative. Shared logic receives `now` as an argument and
never reads a clock itself.

| Clock | Value | Notes |
|---|---|---|
| Market day | 360 s real time | 300 s open session + 60 s after-hours (earnings and news drop after-hours). |
| Market tick (display) | 2 s | Prices are a continuous deterministic function of time; ticks are just samples. |
| Market week | 5 market days = 30 min | Used for earnings cadence and event slots. |
| Season | 28 real days | `SEASON_EPOCH = 1790812800` (2026-10-01 00:00 UTC). Season N starts at `EPOCH + N*2419200`. |
| Review window ("work week") | 40 active minutes | Counted per player in their own active play time (AFK > 120 s stops the count). |
| Workday | 8 active minutes | Five per review window; daily assignment refresh. |
| Day/night | 24 min full cycle | Cosmetic, global (`ClockTime` from server time). |

### The market is global and deterministic

Prices are computed from `(seasonSeed, ticker, time)`, so every server in the world shows the same
price at the same moment. Server-hopping can't find better prices, and global leaderboards compare
like with like. Market shake-up events come from the same seed, so a "Crazy Day" happens
everywhere at once. At season rollover all positions are closed at the final close, cash is kept,
and the new season's market starts.

## 4. The Life Roll (owner v2 design; replaces the blueprint's three-package roll)

Character creation is a spin-the-reels moment: exciting, readable and honest about its odds.

**Flow (Life Roll screen at the Eastbridge Career Center, first join):**
1. **Name.** The player types a first name, 2–16 letters. It's filtered with `TextService:FilterStringAsync` and
   shown filtered to others (Roblox requires this). Their family name comes from the family roll, so the card
   reads "Maya Kennerly".
2. **Spin School.** A slot-reel animation lands on a school with a rarity.
3. **Spin Family.** Same, for the family background.
4. **Spin Stats.** GPA, clubs and the eight skill stats roll together in one reel burst.
5. **Spin Starting Outfit.** A clothing brand and item with a rarity.
6. **Rerolls.** The player has **3 free rerolls; each one rerolls exactly ONE field** they pick (school, family,
   GPA, clubs, one stat, or the outfit). Then they lock in. Extra rerolls come from earned Profile Refresh tokens
   or the paid Profile Reroll product (one field per purchase, with odds disclosed and PolicyService gating).
   Background Rebuild (deterministic editor) stays available.

**Rarity tiers and odds** (the same table for every rolled field that has rarity, always visible on screen):

| Tier | Odds | Colour |
|---|---|---|
| Common | 55% | grey |
| Uncommon | 25% | green |
| Rare | 13% | blue |
| Legendary | 6% | gold |
| Mythic | 1% | prismatic magenta/cyan gradient |

Common pools hold many options; each higher tier holds fewer; **Mythic holds exactly one option**. A Mythic roll
triggers a server-wide announcement banner. All names are fictional parodies (no real people, brands or schools).

**Schools** (affect recruiting: which firms will interview you, base offer odds, Academics difficulty):

| Tier | Schools |
|---|---|
| Common | Eastbridge State, Coastal Community College, Midvale University, Riverbend College, Pinecrest State, Union Valley Tech |
| Uncommon | Lakeshore University, Granite Institute of Technology, Harborview College |
| Rare | Northfield University, Ridgemont University |
| Legendary | Whartonia School of Business, Stanfjord University |
| Mythic | Harvale University |

**Families** (named as parodies of famous dynasties). Family affects lifestyle and connections, never
performance: starting cash, an extra Network bonus, recruiting "connections" (offer odds), weekly living cost,
and a family heirloom cosmetic at Rare and above. It never touches market returns, review scoring or
task grading.

| Tier | Family names | Starting cash | Network bonus | Offer odds bonus | Heirloom |
|---|---|---|---|---|---|
| Common | Williams, Johnson, Smith, Garcia, Nguyen, Brown, Miller, Davis, Martinez, Lee, Patel, Okafor | $500 | +0 | +0% | — |
| Uncommon | Carnaby, Hiltop, Hurst, Gettis | $2,000 | +1 | +3% | — |
| Rare | Vandermont, DuMont, Mellonby | $6,000 | +1 | +6% | signet ring |
| Legendary | Kennerly, Rockwell, Morganthal | $15,000 | +2 | +10% | vintage family watch |
| Mythic | Vanderfeller | $40,000 | +3 | +15% | the Vanderfeller crest blazer |

(The owner suggested "Rothsburger" for Mythic. We swapped it for "Vanderfeller" because Rothschild parodies are
tied to antisemitic conspiracy tropes and would likely get the experience moderated.)

**Stats.** Each is 1–10 and trainable through play:
- **Knowledge**: finance concepts. Graded tasks show more hints.
- **Skill**: Excel/modeling craft. Fill/spot tasks get tolerance help.
- **Speed**: work speed. Task timers get +3% per point above 5.
- **Charisma**: interviews, networking, pitches, dialogue success.
- **Network**: contacts, offer odds, mentor access.
- **Discipline**: deadlines, risk-limit warnings and living-cost resilience.
- **Risk Sense**: starting risk-limit headroom and review risk-component guidance.
- **Luck**: small cosmetic and event perks (golden briefcase hints, bonus spin on rare drops). Never returns or grades.

The eight stats roll as a package summing to **40 ± 2**, so stats can't be maxed by luck. Rarity lives in school,
family and outfit; stats are about shape, not size.

**Other rolled fields:**
- **GPA**: 2.70–4.00, triangular, peaking at 3.45. Gates firm interview cut-offs.
- **Clubs**: 1–3 from Finance Club, Investment Society, Debate Team, Varsity Rowing, Startup Club, Student
  Government, Quant Society, Model UN, each with a small stat or recruiting perk. For example, Investment
  Society gives +1 Knowledge and unlocks a Superday tip; Varsity Rowing gives +1 Discipline and a +2% offer
  bonus at some firms.

**Starting outfit roll** (a full starter look branded by the rolled clothing brand; wardrobe Catalog
`brand`/`rarity` fields):

| Tier | Brands | Items in the pool |
|---|---|---|
| Common | Kevin Kroos, Old Harbor, Gapline, Hanesworth | many, about 12 |
| Uncommon | J. Crewson, Plantain Republic, Tommy Hillford | about 7 |
| Rare | Ralph Lorenzo, Brooks Brethren, Vineyard Wines, Patagonio | about 5 |
| Legendary | Tom Fordham, Zegnatti, Bruno Cucina | 3 |
| Mythic | William Kingsley | exactly 1: the William Kingsley Signature look |

Rolled outfits are owned forever and are tradeable only as showpieces (no trading in this build).

**Fairness, restated:** a great roll is a head start in money, looks and recruiting doors, not a better
career engine. Grades, market results and reviews are skill-driven for everyone.

## 4b. Weeks, recruiting and firms (owner v2)

**Week-to-week rhythm.** Each review window is presented as a **work week**: Week N, Monday–Friday, with
each workday = 8 active minutes. Work tasks refresh daily. **Friday** brings the paycheck (base salary +
bonus), rent/living cost, and the weekly review. After the Friday review the "weekend" (the 60 s after-hours
plus social events) runs. The HUD shows "Week 12 · Wed".

**Recruiting (end of the campus tutorial).** The player applies to up to 5 firms on the campus Recruiting Board.
Each firm sets eligibility (school tier, GPA cut-off, optional club or stat requirements). Eligible applications
lead to a first-round interview task, then a Superday. Each firm makes an offer or not, based on interview
quality, school, GPA, stats, family connections and the Recruiting Fair event bonus. The odds are shown
honestly. The player may hold several offers and accepts one. With no offers, a "walk-on" path is always open:
Sterling & Vance's regional desk hires anyone who passes its Superday at the base bar, so nobody soft-locks.

**Firms** (fictional parodies). The firm decides branding, a pay multiplier, a book-size multiplier, prestige per
week, culture (task volume) and dress code.

| Tier | Firms | Pay x | Book x | Prestige x | Interviews from |
|---|---|---|---|---|---|
| Bulge Bracket | MG Freeman, Goldfield Saxe, Morrow Stanton, Merriweather Lynch | 1.00 | 1.2 | 1.3 | Rare+ school or GPA ≥ 3.6 |
| Elite Boutique | Evermoor Partners, Lazaro Frères, Centerline Partners | 1.15 | 1.0 | 1.4 | Legendary+ school, or Rare + GPA ≥ 3.7 |
| Middle Market | Harrow Williams, Blairmont & Co., Houlton Lockey | 0.90 | 0.9 | 1.0 | Uncommon+ or GPA ≥ 3.3 |
| Regional | Sterling & Vance Regional, Eastbridge Capital Advisors | 0.80 | 0.8 | 0.8 | anyone |

Specialist-realm exits (L50) offer firm choices too. PE: Bluestone Group, KRK Partners, Ironclad Capital.
HF/Asset Management: Anaeio, Bridgecrest Associates, Citrine Capital, Quantum Ridge. VC: Sequel Capital,
a17z, Seedline Ventures. Real Estate: Brookfold Properties, Keystone Realty. Corporate Development: Northwind
Holdings, Applewood Industries.

**Headhunters.** After two Star reviews in a row, headhunters call with lateral offers from a higher-tier firm
at the same rank. Accepting switches firm branding and multipliers and keeps the career.

**One shared tower, many brands.** The Street has a "Bank Row" of branded firm towers. Every IB firm's door
leads into the shared HQ interior, and each player's client re-skins the interior signage (parts tagged
`FirmBrand`) with their own firm's name and colours. Everyone works in "their" firm while still seeing each
other. Realm offices do the same per realm.

## 5. Career and level curve (blueprint §04)

| Levels | Role(s) | Cumulative active time target |
|---|---|---|
| 1–8 | College Student | 0–3 h |
| 9–15 | IB Intern | 3–7 h |
| 16–30 | IB Analyst (I/II/III bands at 16/21/26) | 7–17 h |
| 31–40 | IB Associate | 17–25 h |
| 41–44 / 45–47 / 48–50 | VP / Director / Managing Director | 25–32 h |
| 51–74 | Specialist realm roles (3 per realm: 51–58, 59–66, 67–74) | 32–45 h |
| 75–100 | Partner tier (75–84, 85–94, 95–100) | 45–60 h |

- An automated pacing test simulates a "typical engaged player" (mean task quality 72, standard
  review outcomes, typical event participation) and asserts L100 at 55–65 active hours.
- **Role caps:** XP can't push a player past their role's max level until they're promoted.
- **Promotion** needs all of: reach the role cap, complete N core assignments, reputation ≥ threshold,
  pass a **skills evaluation** (a harder graded task). **Fast-track** (last review ≥ 85, plus a
  sustained positive excess return, plus a completed signature) cuts assignment and reputation
  requirements by 20%. **Alternative route:** a weak market score is offset when work quality ≥ 80
  and there were zero risk violations in the last two reviews.
- **Career exit:** at MD (L50) with the IB signature complete, the player picks a realm at
  Career Services. Switching realms later archives the current realm record (achievements kept)
  and starts the new realm at its first band.
- **Challenge Run** (for the Fastest Career Run board): an alternate career record with a
  standardized profile, standard capital and fixed seed. The main career is saved and paused
  while a challenge is active.

## 6. Reviews, firing and The Wipeout (blueprint §05)

- Review score = 35% risk-adjusted investment + 25% risk management + 25% work quality + 15%
  team/client reputation, all computed on the server for the closing 40-minute window.
- Investment component: excess time-weighted return vs the STREET 10 benchmark over the window,
  penalised for max drawdown and volatility, then mapped to 0–100. **Event fairness:** during market
  shake-ups, scoring stays relative to the benchmark *for the same interval*, so a crash that hits
  everyone doesn't hurt one player more. Players with no trading activity get a neutral 55 for
  the investment component (students and interns without a book get 60).
- Bands and outcomes exactly as the blueprint lists: 85+ Star, 70–84 On track, 55–69
  Underperforming (coaching tasks), 40–54 Probation (risk limits ×0.6, next review high stakes),
  below 40 Critical.
- State machine: `active → review_due → (active | coaching | probation) → fired → (reentry | reinstated | fresh_start) → active`.
- **Firing** happens on two critical reviews in a row *or* a major repeated risk violation (three
  unresolved limit breaches inside one window after warnings).
- **Wipeout losses** (each shown before the final confirmation): current job status, the active
  deal pipeline, 25% of XP earned inside the current role band, and the trading book reset to 10%
  (minimum $5,000). **Never lost:** Robux purchases, cosmetics, badges, career history,
  achievements, housing.
- **Recovery (neutral Career Services screen, no pop-up, no timer):** Re-entry interview (free,
  15–25 min, three tasks + interview, rejoin one rank lower with modest capital), Career
  Reinstatement (129 R$, former title and rank eligibility, probation still applies), Capital
  Reconstruction (79 R$, restores 50% of the lost book, capped at $250k, flagged as external and
  paid so it's excluded from competitive scores), Fresh start (free).

## 7. Fictional market, deals and specialist realms (blueprint §06)

**Companies (10) + benchmark.** APX Apex AI (Tech), NMB Nimbus Cloud (Tech), MRB Meridian Bank
(Financials), VLT Volt Automotive (Autos), SMT Summit Properties (Real Estate), TTN Titan Energy
(Energy), HBR Harbor Health (Healthcare), CRL Crestline Retail (Consumer), ORN Orion Aerospace
(Industrials), BLF Bluefin Foods (Staples). Benchmark **STREET 10** is cap-weighted.

**Price model.** Each day's return = drift toward a fair value (EPS × sector P/E) + sector factor +
market factor + idiosyncratic noise + scheduled catalysts. Intraday prices follow a Brownian
bridge from open to close. Every company reports earnings every 8 market days, staggered;
consensus is published 2 days before, and the surprise is drawn from the seed. Research tasks give
an honest, noisy signal of the surprise direction: an edge earned by work, never sold. Sector
catalysts are announced one day ahead with stated odds.

**Trading.** Market orders with a 0.05% spread, optional stop-loss and take-profit, a
concentration limit (40% of equity per ticker for intern/analyst, 50% associate+), shorting from
Analyst up (gross exposure ≤ 150% of equity), and position limits by role. Book size by role:
Student $5k paper account, Intern $100k, Analyst $250k, Associate $500k, VP+ $1M. Promotion
top-ups count as external flows, so they don't affect return %. Trades are idempotent through a
client transaction ID.

**IB signature: Take a company public.** Build valuation (comps + DCF), prepare the pitchbook,
answer buyer questions, set the price range. The quality of the range and the answers decides
the IPO-day pop.

| Realm | Signature project | Distinct mechanic in this build |
|---|---|---|
| Private Equity (Ironclad Capital) | Acquire and improve a struggling company | Bid price vs competing bidders, debt/equity mix (interest coverage), 100-day operational plan cards, exit timing vs market cycle; IRR/MOIC graded. |
| Hedge Fund (Quantum Ridge) | Beat the benchmark without breaching limits | Allocate a fund sleeve across tickers with long/short; drawdown hard limit; catalyst calendar; Sharpe-graded over a multi-day window. |
| Venture Capital (Seedline Ventures) | Back startups across rounds | Founder meetings reveal signals; probability-weighted outcomes; portfolio construction (power law); follow-on decisions at Seed→A→B. |
| Real Estate (Keystone Realty) | Buy, renovate, lease an office building | Purchase at a cap rate, renovation budget allocation, tenant offers (rent vs occupancy), refinance/sell; NOI and yield graded. |
| Corporate Development (Northwind Holdings) | Recommend an acquisition to the board | Screen targets for strategic fit, valuation range, integration-risk register, board Q&A; board vote outcome. |
| Partner / Family Office (Your firm) | Build a firm | Hire NPC staff, allocate across realm strategies, legacy goals, firm branding and office customization. |

**Lifestyle.** Ordinary clothing, watches, accessories, desk items and apartment upgrades are
bought with in-game salary **Cash**. Robux cosmetics add styles only.

## 8. Random world events (owner addition)

The event director runs on every server. Weather, bonus and chaos events are server-local and
random. Market shake-ups are global and deterministic (§3). At most one of each family is active
at a time.

| Family | Events | Effect | Cadence |
|---|---|---|---|
| Weather / atmosphere | Clear, Foggy Day, Rainstorm, Thunderstorm, Snow Day, Heat Wave, Blackout Evening (night only) | Lighting, Atmosphere, ColorCorrection, rain/snow particles, wet-street reflectance, lightning flashes, blackout: street lights off, emergency lights on. Cosmetic only. | New roll every 6–12 min, weighted. |
| Market shake-ups | Crazy Day (vol ×3 for a market day), Flash Crash (index −6–9% fast, 70% recovery over the day), Earnings Frenzy (3 reports same day), Rate Shock (Financials/Real Estate down, rotation), Meme Rally (one ticker +30–80% then fades over 2 days) | Changes the global price path. Announced on the news ticker one market day ahead ("Volatility advisory"; flash crash shows only a risk window). Reviews stay benchmark-relative. | ~45% chance per 5-day slot. |
| Bonus / social | Recruiting Fair (campus booths, +interview odds), Bonus Day (salary ×1.5), Deal Rush (task pay ×2, task cooldowns ÷2), Fashion Week (cash shop −25%, runway show on the plaza), Networking Mixer (rooftop, reputation bonus) | Temporary modifiers + spawned set dressing. Never touches market scoring. | Every ~15 min, 60% chance. |
| Chaos / fun | Fire Drill (alarm, evacuate to the muster point in 60 s → small reward), CEO Walkthrough (NPC CEO tours the floor; players working at a desk earn reputation), Pigeon Invasion (shoo pigeons on the Street for cash), Pizza Party (grab a slice: +10% task timer buff), Golden Briefcase Hunt (hidden briefcase, first finder wins cash + season XP), Elevator Outage (lobby elevators closed, stairs only, coffee voucher reward) | Funny, short (2–5 min), small rewards; never a penalty. | Every ~12 min, 35% chance. |

Every event shows a banner, plays a chime and posts on the news ticker. Events that need player
action add a tracker entry.

## 9. Visual direction

- **Campus (Eastbridge, gritty):** red-brown brick, stained concrete, corroded metal, chain-link,
  cracked asphalt with patching, puddles, fire escapes, dumpsters, a bus depot, a 24h diner, a
  laundromat, flickering sodium lamps. Lighting: overcast, cool-desaturated
  (`ColorCorrection` saturation −0.25), denser Atmosphere haze. UI theme "Campus":
  charcoal/paper/mustard, Special Elite + Source Sans fonts.
- **Wall Street district (polished):** limestone and marble facades, glass curtain walls with brass
  mullions, a granite plaza, black-and-gold signage, planters, clean streets, yellow cabs, the
  Metropolitan Exchange with a ticker band, the Sterling & Vance HQ tower. Lighting: crisp warm
  sun, bloom, light haze. UI theme "Street": navy `#0B1F3A`, white, gold `#C9A54C`, Gotham/Montserrat,
  RobotoMono for numbers.
- **Interiors:** polished offices that get larger and finer with rank (bullpen → associate pod →
  VP office → MD corner office), a trading floor, conference rooms, realm offices with distinct
  palettes, an apartment tower (one unit per player per server), shops (Hartwell Tailors, Vanta
  Watches, Strider Shoes), the Executive Club lounge, Career Services.
- **Budgets:** campus ≤ 9k parts, Street exterior ≤ 14k, all interiors ≤ 14k combined, runtime
  props/NPCs ≤ 2k. `StreamingEnabled` on.

## 10. Wardrobe and characters

- In-game outfits switch the player into a **Career Look**: a standardized blocky R15 body with the
  player's skin tone, face and hair kept, and their own shirts and pants hidden. A "Wear my avatar"
  toggle restores their own look at any time.
- Clothing is made of **fitted 3D layers** welded to body parts and sized from the actual part
  sizes: jacket shell, lapels, shirt front, tie, collar, pocket square, buttons, cuffs, belt,
  trouser shell, shoes, watch, glasses, bags, hats, scarves, quarter-zip with a zipper pull,
  hoodie with a hood, backpack. Limb colours are set per part (hands keep the skin tone).
- **2D templates:** a Python generator paints Roblox Shirt/Pants templates (585×559) for every
  outfit. `tools/clothing/upload.py` uploads them with an Open Cloud key and writes IDs into
  `Config/ClothingIds.luau`. When IDs exist, they're applied under the 3D layers for extra detail.
- Catalog: about 60 items across campus wear, business casual, suits (three cuts × six colours),
  accessories, watches (tiered), shoes, and premium Robux collections (Corner Office Collection,
  Executive Club set).

## 11. Economy and monetization (blueprint §07)

Currencies: **Cash** (salary; lifestyle purchases), **Book capital** (trading; never purchasable
except the capped, flagged Capital Reconstruction), **Season XP**, **Profile Refresh tokens**.

**Salary scale (typical Cash earned per active hour, all sources):**

| Role | Cash / hr | Role | Cash / hr |
|---|---|---|---|
| Student | $300 | Director | $32,000 |
| Intern | $3,000 | MD | $45,000 |
| Analyst | $8,000 | Realm band 1 / 2 / 3 | $55k / $70k / $90k |
| Associate | $15,000 | Partner / Senior Partner / Founder | $120k / $160k / $220k |
| VP | $25,000 | | |

About 70% comes from task/project pay and 30% from the per-review base salary plus bonus (bonus
scales with review score: Star 1.5×, On track 1×, below that 0.5×, fired 0).

**Price anchors:**
- Campus wear $40–$250
- Business casual $150–$600
- Suits $900–$6,000
- Shoes $120–$2,500
- Watches $300–$80,000 (the status ladder)
- Desk items $50–$3,000
- Furniture $400–$25,000
- Art $2,000–$150,000

Weekly living cost (deducted per review window, by region/family): $50–$400 for students, scaling to about
2% of review-window income later. It never pushes cash below $0.

Launch products (8): Profile Reroll 49 (developer product, paid random, odds disclosed, policy
gated), Background Rebuild 99 (developer product), Career Reinstatement 129 (developer product),
Capital Reconstruction 79 (developer product), Season Pass Premium 229 (developer product, one
per season), Corner Office Collection 199 (game pass), Office Theme Pass 199 (game pass),
Executive Club 499 (game pass: VIP lounge, profile frame, outfit presets, cosmetics; no
multipliers).

Rules (all enforced in code and covered by tests):
- Idempotent receipt processing
- Grants only after a verified receipt
- Paid values excluded from every competitive score
- Exact contents shown before purchase
- No purchase pop-up on firing
- Bug-loss restores are support actions, never products

Product IDs are `0` until the owner creates them. Unconfigured products show "Coming soon"
instead of failing.

## 12. Leaderboards (blueprint §08)

Five boards: Career Prestige (all-time), Market Skill (seasonal), Deal Mastery (all-time),
Fastest Career Run (seasonal, lower is better), Comeback Board (all-time). Scores are written by
the server at checkpoints into OrderedDataStores, read with a 60 s cache, and shown on in-world
plaza monoliths plus a menu UI with Global / Friends tabs.

Abuse controls: rate-limited remotes; server validation of every value; flags for impossible
returns, implausible trade volume, teleport/timer exploits, and repeated disconnects mid-review.
Flagged players are hidden from boards pending review (`AuditService` keeps the evidence).

## 13. Persistence (blueprint §09)

One DataStore profile per user with:
- Session locking
- Schema version + migrations
- Autosave every 120 s, save on leave and on `BindToClose`
- Transaction IDs for trades
- Receipt ledger
- An audit ring buffer

Leaderboards live in separate OrderedDataStores. Studio without API access falls back to
an in-memory mock with a warning.

## 14. Testing and verification

The Roblox engine can't run in the build container, so:
1. **Unit tests (Lune)** for all pure logic: profile roll fairness, level pacing, review scoring and
   the state machine, market determinism and statistics, event scheduling, realm sims, task
   graders, receipt idempotency, migrations, wardrobe fitting math.
2. **Static analysis:** `luau-lsp analyze` with Roblox type definitions over the whole tree (strict
   for `Shared/Logic`).
3. **Bake test:** every world/prop/wardrobe builder runs under Lune with real Roblox datatypes,
   produces instances, and stays within part budgets.
4. **Build:** `rojo build` produces `build/TheStreet.rbxl`.
5. **Owner playtest** in Studio covers physics, rendering, purchases and multiplayer feel, the
   things automated checks can't reach.

## 15. Out of scope for this build

- Voice chat features
- Trading between players
- Real-money anything
- Real stock data
- Mobile-specific haptics
- Localization beyond English (all text goes through `Shared/Strings` so it can be added later)

## 16. Additional features (owner asked for more ideas, v2)

1. **Mythic moments.** Any Mythic roll (life roll, outfit, rare event drop) fires a server-wide banner and a
   brief prismatic effect around the player.
2. **Dress code and Fit Score.** Each firm has a dress code (Bulge Bracket: suit; Elite Boutique: suit with
   tie; Middle Market: business casual; Regional: smart casual; VC: smart casual; PE/HF: business formal). The
   outfit's Fit Score (tier and rarity of the equipped pieces plus dress-code match) shows on the profile card. A
   matching outfit adds a small reputation bonus on client-facing tasks (pitch, mandate, roadshow), never on
   graded quality. Fashion matters socially without buying success.
3. **The Rival.** Every player gets a recurring NPC rival from their intake class (e.g. "Chad Whitmore III" or
   "Priya Sharma-Lowe", rolled). The rival's weekly review score and promotions are simulated alongside yours,
   with banter in the Friday review screen and a "beat your rival" weekly side goal.
4. **Morning Brief login streak.** The first login of each real day shows a Morning Brief: market headlines,
   your week, today's events. A streak gives small cash, Season XP and a Profile Refresh token on day 7. A missed
   day resets the streak with no penalty.
5. **Deal-toy shelf.** Every completed signature project awards a lucite deal toy (named after the deal),
   displayed on a shelf decor slot in your office or apartment and counted on the profile card.
6. **Mentorship.** Players at Associate+ can mentor a junior once per real day ("Coffee chat"). The junior
   gets a 10% XP boost on their next 3 tasks; the mentor gets reputation and a Mentor achievement track.
7. **Headhunter calls.** See §4b.
