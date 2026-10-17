# The Street — Design v3 (owner revisions, 2026-10-17)

**Precedence:** this document overrides `2026-10-15-the-street-design.md` wherever they conflict. Anything not
mentioned here stays as written in the v1/v2 spec. Code interfaces live in `docs/contracts.md`.

The goal, in the owner's words: *"This needs to feel like a MyCareer game."* That means a personal story, an
Overall rating, attributes that grow with performance, a boss who reviews you every week, a rival, email offers
and a career you can reroll and replay.

---

## 1. Rarity (all rolled things)

| Tier | Base odds | Colour | Stat boost when it's a school or club | Perk |
|---|---|---|---|---|
| Common | 50% | grey | none | — |
| Uncommon | 25% | green | +5 to 1 stat | — |
| Rare | 13% | blue | +5 to 2 stats | — |
| Epic | 7% | purple | +5 to 3 stats | — |
| Legendary | 4% | gold | +5 to 3 stats | one perk (e.g. **Alumni Lifeline** = 1 free revive) |
| Mythic | 1% | prismatic | +5 to 3 stats (+8 to one) | one perk + a Mythic flourish |

- Common pools hold the most options; each higher tier fewer; **Mythic holds exactly one option** per field.
- **Rebirth luck:** each rebirth moves 0.4 percentage points of probability from Common to the other tiers (split
  40/30/16/10/4 across Uncommon to Mythic), capped at 10 rebirths. "Very, very slightly better."
- Odds are always shown and always exact (Roblox paid-random policy).

## 2. Life Roll (start of every life, and after every rebirth)

Order:
1. Type a first name (filtered).
2. Spin **School**, then **Degree**, **GPA**, **Family**, **Clubs**, **Stats** and the **Starting outfit**.
3. Spend **3 free rerolls**, each rerolling ONE field.
4. Lock in.

- **School** (rarity): a crest logo built from GUI shapes, shown on the stats page and profile card. It decides
  recruiting doors and **caps the highest title you can reach** (§4).
- **Degree**: B.S. 80% / Master's 20%. Master's adds +5 Knowledge, opens Master's-friendly entry programs (PE,
  Asset Management, Wealth Management Associate) and gives a small offer-odds bonus.
- **GPA**: 2.70–4.00, triangular, peaking at 3.45.
- **Family** (rarity; the v2 dynasty parody names): starting cash, connections (offer odds) and an heirloom at
  Rare+. Never performance.
- **Clubs**: 1–3, each with its own rarity and stat boosts (§1 table); Legendary+ clubs carry perks.
- **Stats** (§3): rolled 25–55 each.
- **Starting outfit** (rarity): brands as in v2, except the Mythic brand is now **Pan Miller** (replaces
  "William Kingsley"), whose logo is a classic farm windmill (lattice tower, multi-blade wheel, tail vane).
- **Perks** from Legendary+ schools/clubs:
  - **Alumni Lifeline**: one free revive when fired; you keep your job on probation instead.
  - **Ivy Network**: +8% offer odds.
  - **Legacy Seat**: +1 extra reroll on every future Life Roll.
  - **Boardroom Pedigree**: the top-title school requirement is reduced by one tier.

## 3. Stats: attributes 1–99 and Overall rating

- Eight attributes: Knowledge, Skill, Speed, Charisma, Network, Discipline, Risk Sense, Luck. Each is rolled
  25–55 (a package summing to 320 ± 16, so luck shapes it but can't max it), plus school/club boosts.
- **Overall (OVR)** = the rounded mean, shown big on the profile like a sports card. An **Archetype** comes from
  the top two stats (e.g. Quant Machine, Rainmaker, Grinder, Closer, Floor Trader, Diplomat).
- **No direct upgrades.** Stats grow only from performance: each graded task and project awards stat XP to its
  stat(s), scaled by quality (bad work gives almost nothing). Weekly review bands add a bonus. Growth slows near 99.
- **Focus area:** the player picks one focus at a time (Modeling, Markets, Client Coverage, Leadership, Execution,
  Risk). Its two linked stats grow 2× while the others grow at 0.75×. It can be changed once per week.
- Effects (applied consistently by work/project code):
  - Speed: task timer ±0.4% per point from 50, capped ±20%.
  - Knowledge: hint lines 0/1/2/3 at <30 / 30–59 / 60–84 / 85+.
  - Skill: numeric tolerance in fill/spot grading widens by up to +50% at 99.
  - Charisma: up to +8 quality points on dialogue sections.
  - Network: offer odds and networking-event invites.
  - Discipline: deadline grace and resistance to living costs.
  - Risk Sense: risk-limit headroom (concentration limits +0–5%).
  - Luck: cosmetic/event perks only.

## 4. Career tracks, companies and titles

After college the player picks from the entry jobs they actually got offers for. Difficulty follows real
graduate hiring:

| Track | Entry title | How hard to get | Ladder (title per rank 1..N) | Top title gated by school |
|---|---|---|---|---|
| Investment Banking | Analyst | Very hard at bulge bracket/elite boutique, medium at middle market, easy regional | Analyst, Associate, VP, Director, **Managing Director** | MD: Rare+ |
| Sales & Trading | Analyst | Hard | Analyst, Associate, VP, Director, **Managing Director** | MD: Rare+ |
| Private Equity | Analyst | Extremely hard (few seats; Epic+ school, or Master's + Rare+, GPA 3.7+) | Analyst, Associate, Senior Associate, VP, Principal, Partner, **Senior Partner** | Partner: Rare+, Senior Partner: Epic+ |
| Private Credit | Analyst | Hard | Analyst, Associate, VP, Director, **Managing Director** | MD: Rare+ |
| Wealth Management | Associate | Hard at top firms (connections and Charisma matter) | Associate, Financial Advisor, Senior Advisor, Director, Managing Director, **Partner** | MD: Rare+, Partner: Epic+ |
| Asset Mgmt / Hedge Fund | Analyst | Very hard | Analyst, Associate, Portfolio Manager, Senior PM, **Chief Investment Officer** | CIO: Epic+ |
| Equity Research | Research Associate | Medium | Research Associate, Research Analyst, Senior Analyst, **Director of Research** | Director: Uncommon+ |
| Corporate Banking | Analyst | Medium-easy | Analyst, Associate, VP, Director, **Managing Director** | MD: Uncommon+ |
| Venture Capital | Analyst | Very hard, rare seats | Analyst, Associate, Principal, Partner, **General Partner** | Partner: Epic+, GP: Legendary+ |
| Real Estate | Analyst | Medium | Analyst, Associate, VP, Director, **Managing Director** | MD: Rare+ |
| Corporate Finance | Financial Analyst | Easy (walk-on always available) | Financial Analyst, Senior Analyst, Finance Manager, Director, VP Finance, CFO, CEO, **Board Member** | CFO: Rare+, CEO: Epic+, Board: Legendary+ |

- A school below the requirement stalls the player one rank short of the top, with a clear explanation. Rebirth
  (§9) is the way to reroll the school. The **Boardroom Pedigree** perk lowers the requirement by one tier.
- **Levels 1–100** stay the global progression. Each track maps its ranks onto level bands (longer ladders mean
  narrower bands), tuned so the longest ladder reaches L100 in 55–65 active hours.
- **Companies** (fictional parodies; full list in `Config/Companies`). Each has a type, the departments (tracks) it
  hires for, logo spec, colours, prestige tier, pay/book/prestige multipliers, minimum outfit level and culture.
  Examples:
  - Banks: MG Freeman, Goldfield Saxe, Morrow Stanton, Merriweather Lynch (IB, S&T, WM, ER, Corp Banking, Credit)
  - Elite boutiques: Evermoor, Lazaro Frères, Centerline
  - Middle market: Harrow Williams, Blairmont, Houlton Lockey
  - Regional: Sterling & Vance, Eastbridge Capital
  - Asset management: Anaeio (AM, WM, Credit; the owner's logo, rebuilt geometrically)
  - Private equity: Bluestone Group, KRK Partners, Ironclad Capital
  - Private credit: Aresmont Credit, Gray Heron Capital
  - Hedge funds: Bridgecrest Associates, Citrine Capital, Quantum Ridge
  - Wealth management: Lotus Private Wealth (lotus logo from the owner's image)
  - VC: Sequel Capital, a17z, Seedline Ventures
  - Real estate: Brookfold Properties, Keystone Realty
  - Corporations: Applewood Industries, Northwind Holdings
- **Lateral moves:** offers can switch company and/or track. Rank maps across tracks by seniority (e.g. IB Associate
  to PE Associate is the classic exit).

## 5. Dress requirements (clothing level)

- Every wearable has a **level 1–5** (its tier). **Outfit Level** = the lowest level among the equipped core slots
  (top/outer, bottom, shoes).
- Companies require a minimum Outfit Level to hire you and to let you work: Corporate/Regional 2, Middle Market/Corp
  Banking/ER/RE 3, Bulge Bracket/S&T/Credit/HF/VC 3, Elite Boutique/PE/WM 4.
- **Promotions** require Outfit Level ≥ min(5, rank + 1) at the new rank (VP needs 4, MD needs 5). The boss says
  it plainly: "Come back dressed for the role."
- Fit Score (v2 §16) remains the social/cosmetic layer and the client-facing reputation nudge.

## 6. The week and the boss review

- The work week persists exactly where you left it: workday and minutes carry across sessions.
- Monday–Friday, 8 active minutes per day. Friday afternoon: **"Your weekly review is ready. Head to <Boss>'s
  office."** A waypoint leads to the boss NPC's office on your floor. The review meeting is a short cutscene
  (camera to the desk, the boss speaks, a breakdown card of the four components) with one outcome:
  - **Promoted**: all promotion requirements met (score, level, core work, outfit level, school gate). Celebration,
    new title, new desk or office.
  - **Keep up the good work**: no change, with specific feedback.
  - **Warning / probation**: the v1 bands.
  - **Fired**: two consecutive criticals, a major risk violation, or a mass firing (§10). The Alumni Lifeline auto-
    saves you once if you own it.
- If the player doesn't visit within 10 active minutes, the boss calls the phone and the review happens remotely,
  so nothing can soft-lock.

## 7. Networking events, email and job offers

- The **Phone** (a HUD button) has these apps: Email, Calendar (week view), Stats (OVR card), Directory (teleport to
  any company), Market, Contacts.
- Performing well (On track or better twice in a row, rising OVR) earns **networking invitations by email**: rooftop
  mixers, alumni dinners, industry conferences (server events or personal invites). Meeting NPC executives there
  builds **Connections** with their companies.
- Connections plus continued good reviews produce **job offers by email**, or postings you can **apply** to. Applying
  runs an interview task, then an offer or rejection. Offers show title, company, track, pay, prestige, dress
  level and school gate.

## 8. The Rival (made viable)

- A named rival from your intake class works at **your company, on your floor**: a real NPC at a nearby desk. They
  have their own OVR, rank and weekly scores, simulated from a deterministic model that rubber-bands within ±10%
  of you so it stays a race.
- **Weekly head-to-head:** the same task for both of you; the winner earns a bonus and bragging rights in the review.
- They can get promoted before you (narrative pressure) and comment on your reviews.
- Beat them three weeks running and they get poached by a competitor. They reappear later at another company,
  emailing a "see you at the deal table" taunt, and a new rival arrives.

## 9. Rebirth (a voluntary reset)

- Unlocked after your first promotion. At Career Services, Rebirth resets level, rank, track, company, book and
  stats, and starts a new Life Roll with the improved odds (§1).
- **Kept:** cash, cosmetics, housing décor, achievements, deal plaques, perks unlocked by achievements, and the
  rebirth count.
- Each rebirth adds **+0.1× to all cash income** (×1.1 after one, ×1.2 after two, ... capped at ×3.0).
- Rebirth count shows on the profile card and has its own leaderboard.

## 10. Server events (per server)

The **market now runs per server** (§11), so market events can be local to the server, as the owner asked.
Families:
- **Market:**
  - Market Crash: −15% to −25% over about 3 minutes, then a slow partial recovery.
  - Market Boom: +10% to +20%.
  - Flash Crash, Meme Rally, Rate Shock, Earnings Frenzy, Crazy Day.
  - Fed Day: high volatility around a "rate decision" moment.
- **Corporate:**
  - **Mass Firing**: layoffs at one company present on the server. Its employees whose last review was below On
    track are let go (Lifeline applies) and survivors get a morale bonus. Desks get boxes for the event.
  - Bonus Season: weekly bonus ×2.
  - Hiring Spree: offer odds +15%.
  - Merger Mania: two companies' employees share both offices and get a joint deal task.
  - Regulatory Audit: a dress-code and risk-limit check, with warnings for violators and a reward for the compliant.
  - IPO Frenzy: IPO and capital-markets tasks pay ×2.
  - Market Holiday: market closed, social events instead.
- **Weather/atmosphere** and **chaos/fun** families as in v1.
- **Daily-reward boosts** (§12) stack with events.

Every event shows a banner, a ticker line and an email explaining fairness: reviews compare you to the benchmark
over the same window.

## 11. Market per server (replaces "global and deterministic")

- Each server runs its own market from a random server seed. Prices, news, earnings and events are local.
- **Books are session-based:** open positions are flattened at the current price when you leave the server or it
  shuts down ("desk policy: end the session flat"). Cash and P/L persist. This stops server-hopping exploits.
- Review and Market Skill metrics chain the per-session returns over the week. Flattening isn't a flow.
- **Live invested** = the market value of your open positions. It's shown on the HUD and feeds a leaderboard
  (updated every 60 s while online; 0 when offline).

## 12. Morning Brief and daily rewards

- The daily login screen (first join each UTC day) shows headlines, your week and today's events, plus a **7-day
  reward calendar**: e.g. **2× money for 5 minutes**, +25% XP for 10 minutes, cash, Season XP, a cosmetic, and a
  Refresh token on day 7. Missing a day resets the streak with no penalty.
- **Morning Brief Premium** (a Robux game pass): bigger guaranteed versions (2× money for 15 minutes, +50% XP,
  double cash, an extra Refresh token weekly). No paid randomness. Boosts affect Cash and XP only, never market
  returns or review scores.

## 13. Deal plaques

Every completed big deal (signature/project completion) creates a **lucite deal plaque** named after the deal and
its date.
- While you work at a desk, the latest 3 sit on your desk.
- Once you have your own office (rank ≥ 3), they move to a **bookshelf** that shows up to 24.
- Plaques are permanent and count on the profile card.

## 14. Offices: one company, one office, many floors

- **Same company = same office.** Each company gets its own office instance on the server (built at runtime from
  baked templates), shared by all its employees on that server.
- **Floors per department:** every company has a branded **lobby** (logo wall, reception, an elevator panel listing
  its floors) and one floor per department it runs. Each floor has open-plan desks, a **boss office** (review
  meetings), private offices for senior ranks, a conference room and a pantry.
- **Floor styles by department:**
  - **IB**: the owner's reference photo. Open plan, exposed silver ductwork and concrete ceiling, concrete
    columns with brass bands, long white desk pods with terrazzo/marble end panels, 4–6 monitor arrays, black mesh
    chairs with orange seats, cylinder pendant lights, carpet, big windows.
  - **S&T**: a dense trading floor with 6–8 monitor turrets, a ticker wall and LED strips.
  - **PE**: quiet walnut panelling, glass-walled offices, a deal room and leather.
  - **Credit**: sleek light grey and teal with glass meeting pods.
  - **WM**: warm client lounges, a fireplace, art and private meeting rooms.
  - **Hedge fund/AM**: dark, cyan LEDs, risk dashboards.
  - **ER**: library-like, books and whiteboards.
  - **Corporate Banking**: classic bank pods.
  - **VC**: a bright loft with plants and beanbags.
  - **RE**: warm timber with architectural models.
  - **Corporate**: a modern HQ with an executive suite and boardroom.
- **Visiting:** anyone can teleport to any company's lobby (Phone Directory or the street directory kiosks) and
  walk its floors, but visitors **can't interact**: prompts are hidden or show "Employees only".
- The Street keeps Bank Row and landmark towers. Their doors lead to the matching company lobby (multi-tenant towers
  open a tenant picker).

## 14b. Click a player to see their story

Clicking or tapping any player in the world opens their **profile card**:
- name with family name
- school crest and rarity
- degree, GPA and clubs
- OVR and the 8 stats
- archetype
- company logo and title
- rebirths, plaques, Fit Score
- aura tier

## 15. Aura

- A Legendary or Mythic **school** gives a **plain, colourless glow**: a subtle white outline/light that makes the
  player stand out a bit. Nothing flashy.
- The aura **grows with level**: brighter at L25/L50/L75, and at L100 a faint white shimmer. It's still
  colourless. A player with a lower-tier school starts showing the level aura from L50.

## 16. Logos (no image uploads: built from GUI shapes)

- `Assets/Logos` draws every company logo, school crest and clothing-brand mark from Frames, UICorner, UIStroke,
  rotated bars and text:
  - **Anaeio**: rebuilt geometrically from the owner's wordmark (rounded lowercase "anaeio", tail strokes on the a's,
    the i-dot, the split o).
  - **Lotus Private Wealth**: a petal lotus (rounded rotated frames, optional dot stipple).
  - **Pan Miller**: a farm windmill.
  - The rest: monograms and shields in each company's colours.
- **Company logo on clothing:** only on a **vest or quarter-zip**, as a small left-chest emblem of the player's
  company. Never on suits, dress shirts or other items.

## 17. Leaderboards (top 50 each)

The v1 five (Career Prestige, Market Skill, Deal Mastery, Fastest Run (now: fastest active time from a life start to
the track's top title), Comeback) plus the owner's five:
- **Robux Spent**: from processed receipts.
- **Time Played**: active hours.
- **Most Money Invested (live)**: §11.
- **Most Rebirths.**
- **Highest Stats Level**: OVR, ties broken by stat total.

The integrity footnote stays on the skill boards. Robux Spent is kept separate and labelled as a supporter board.

## 18. Removed or simplified from v1/v2

- The single shared HQ with client-side re-skinning is replaced by per-company office instances (§14).
- The "specialist realm at L51" structure is replaced by tracks from day one plus lateral moves (§4). Realm
  signature projects stay as each track's signature deals.
- The Challenge Run mode is replaced by Rebirth (§9). Fastest Run uses life/rebirth starts.
- The global deterministic market is replaced by the per-server market (§11).
