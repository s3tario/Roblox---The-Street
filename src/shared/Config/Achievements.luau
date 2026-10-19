--!strict
-- Achievements (owned by `tutorial`; design v1 §2 and v3 §9: permanent, kept through rebirths). AchievementService
-- feeds events from other features' signals into Logic/QuestLine/Awards, which decides what unlocks.
-- Pure data: safe on the server, the client and under Lune.
--
--   Achievements.list = { Def }   (Achievements.byId[id])     Achievements.get(id) -> Def?
--   Achievements.TIERS[tier] = { name, color ("#RRGGBB"), banner }   Achievements.text(key, vars?)
--
--   Def = { id, name, desc, glyph, tier = "bronze" | "silver" | "gold", hidden?, on = Filter }
--   Filter = { kind, ...fields } — the event kind plus conditions (Logic/QuestLine/Awards):
--     count = n (with counter = "kind:sub"? : the permanent counter for this event kind), minQuality, band,
--     source, companyType, step, projectId, closed, rarity (any rolled field), schoolAtLeast (rarity id),
--     gpaAtLeast, pnlAtLeast, rankAtLeast, levelAtLeast, outfitLevel, meetsFirm, from, to, held, all = { npcId }
--   Event kinds: life_roll task exchange talk offer hired step trade promotion review status lifeline comeback
--     plaque project outfit level

export type Def = {
	id: string,
	name: string,
	desc: string,
	glyph: string,
	tier: string,
	hidden: boolean?,
	on: { [string]: any },
}

local Achievements = {}

Achievements.TIERS = {
	bronze = { name = "Bronze", color = "#B07A4F", banner = false },
	silver = { name = "Silver", color = "#B8C2CC", banner = false },
	gold = { name = "Gold", color = "#D4AF37", banner = true },
} :: { [string]: { name: string, color: string, banner: boolean } }

Achievements.list = {
	-- The Life Roll
	{
		id = "new_life",
		name = "Welcome to Eastbridge",
		desc = "Lock in your first Life Roll.",
		glyph = "🎲",
		tier = "bronze",
		on = { kind = "life_roll" },
	},
	{
		id = "honor_roll",
		name = "Honor Roll",
		desc = "Roll a GPA of 3.80 or higher.",
		glyph = "📚",
		tier = "silver",
		on = { kind = "life_roll", gpaAtLeast = 3.8 },
	},
	{
		id = "legendary_roll",
		name = "Born Lucky",
		desc = "Roll a Legendary or Mythic school.",
		glyph = "🌟",
		tier = "gold",
		on = { kind = "life_roll", schoolAtLeast = "legendary" },
	},
	{
		id = "mythic_roll",
		name = "One in a Hundred",
		desc = "Roll anything Mythic in a Life Roll.",
		glyph = "💎",
		tier = "gold",
		hidden = true,
		on = { kind = "life_roll", rarity = "mythic" },
	},
	-- Campus
	{
		id = "club_member",
		name = "Card-Carrying Member",
		desc = "Join the Finance Club.",
		glyph = "🃏",
		tier = "bronze",
		on = { kind = "step", step = "club" },
	},
	{
		id = "campus_regular",
		name = "Campus Regular",
		desc = "Talk to every regular on campus.",
		glyph = "☕",
		tier = "silver",
		on = {
			kind = "talk",
			all = { "npc_alum", "npc_barista", "npc_bus_driver", "npc_professor", "npc_roommate", "npc_recruiter" },
		},
	},
	{
		id = "card_shark",
		name = "Card Shark",
		desc = "Exchange business cards with 5 players.",
		glyph = "🤝",
		tier = "bronze",
		on = { kind = "exchange", count = 5 },
	},
	{
		id = "rolodex",
		name = "The Rolodex",
		desc = "Exchange business cards with 25 players.",
		glyph = "📇",
		tier = "silver",
		on = { kind = "exchange", count = 25 },
	},
	-- Recruiting
	{
		id = "first_offer",
		name = "You're Hired (Almost)",
		desc = "Receive your first job offer.",
		glyph = "✉️",
		tier = "bronze",
		on = { kind = "offer" },
	},
	{
		id = "offer_magnet",
		name = "Offer Magnet",
		desc = "Hold three job offers at once.",
		glyph = "🧲",
		tier = "gold",
		on = { kind = "offer", held = 3 },
	},
	{
		id = "walk_on",
		name = "Through the Side Door",
		desc = "Take Sterling & Vance's walk-on seat.",
		glyph = "🚪",
		tier = "bronze",
		on = { kind = "hired", source = "walk_on" },
	},
	{
		id = "bulge_bracket",
		name = "Bulge Bracket",
		desc = "Get hired by a bulge-bracket bank.",
		glyph = "🏦",
		tier = "silver",
		on = { kind = "hired", companyType = "bulge" },
	},
	{
		id = "elite_boutique",
		name = "Boutique Material",
		desc = "Get hired by an elite boutique.",
		glyph = "🎩",
		tier = "gold",
		on = { kind = "hired", companyType = "elite" },
	},
	-- First days
	{
		id = "first_day",
		name = "First Day",
		desc = "Report to your boss on your first day.",
		glyph = "🏢",
		tier = "bronze",
		on = { kind = "step", step = "boss" },
	},
	{
		id = "first_task",
		name = "Clocked In",
		desc = "Finish your first graded task.",
		glyph = "✅",
		tier = "bronze",
		on = { kind = "task" },
	},
	{
		id = "perfectionist",
		name = "Perfectionist",
		desc = "Score 95 or better on a task.",
		glyph = "🎯",
		tier = "silver",
		on = { kind = "task", minQuality = 95 },
	},
	{
		id = "workhorse",
		name = "Workhorse",
		desc = "Finish 100 graded tasks.",
		glyph = "🐎",
		tier = "gold",
		on = { kind = "task", count = 100 },
	},
	{
		id = "onboarded",
		name = "Onboarded",
		desc = "Finish the whole onboarding, from the bus depot to your first desk.",
		glyph = "🎓",
		tier = "silver",
		on = { kind = "step", step = "done" },
	},
	-- Markets
	{
		id = "first_trade",
		name = "Ticket Writer",
		desc = "Make your first trade.",
		glyph = "📈",
		tier = "bronze",
		on = { kind = "trade" },
	},
	{
		id = "big_winner",
		name = "Big Winner",
		desc = "Realize a $10,000 gain on a single trade.",
		glyph = "💰",
		tier = "gold",
		on = { kind = "trade", pnlAtLeast = 10000 },
	},
	{
		id = "active_trader",
		name = "Active Trader",
		desc = "Make 100 trades.",
		glyph = "⚡",
		tier = "silver",
		on = { kind = "trade", count = 100 },
	},
	-- Reviews and the ladder
	{
		id = "star_review",
		name = "Gold Star",
		desc = "Earn a Star weekly review.",
		glyph = "⭐",
		tier = "silver",
		on = { kind = "review", band = "star" },
	},
	{
		id = "star_streak",
		name = "Constellation",
		desc = "Earn three Star reviews.",
		glyph = "✨",
		tier = "gold",
		on = { kind = "review", band = "star", count = 3, counter = "review:star" },
	},
	{
		id = "survived_probation",
		name = "Back from the Brink",
		desc = "Get off probation.",
		glyph = "🛟",
		tier = "silver",
		on = { kind = "status", from = "probation", to = "active" },
	},
	{
		id = "lifeline",
		name = "Alumni Lifeline",
		desc = "Be saved from a firing by the Alumni Lifeline.",
		glyph = "🪢",
		tier = "silver",
		hidden = true,
		on = { kind = "lifeline" },
	},
	{
		id = "comeback",
		name = "The Comeback",
		desc = "Get back on a desk after being let go.",
		glyph = "🔁",
		tier = "gold",
		on = { kind = "comeback" },
	},
	{
		id = "first_promotion",
		name = "Moving Up",
		desc = "Earn your first promotion.",
		glyph = "🪜",
		tier = "silver",
		on = { kind = "promotion" },
	},
	{
		id = "vice_president",
		name = "Corner Office Bound",
		desc = "Reach Vice President.",
		glyph = "🏙️",
		tier = "gold",
		on = { kind = "promotion", rankAtLeast = 3 },
	},
	{
		id = "managing_director",
		name = "Managing Director",
		desc = "Reach the top of the investment banking ladder.",
		glyph = "👑",
		tier = "gold",
		on = { kind = "promotion", rankAtLeast = 5 },
	},
	{
		id = "level_25",
		name = "Quarter Century",
		desc = "Reach level 25.",
		glyph = "🔷",
		tier = "silver",
		on = { kind = "level", levelAtLeast = 25 },
	},
	{
		id = "level_50",
		name = "Halfway to the Top",
		desc = "Reach level 50.",
		glyph = "🔶",
		tier = "gold",
		on = { kind = "level", levelAtLeast = 50 },
	},
	-- Deals
	{
		id = "first_plaque",
		name = "Tombstone",
		desc = "Earn your first lucite deal plaque.",
		glyph = "🧊",
		tier = "silver",
		on = { kind = "plaque" },
	},
	{
		id = "ipo_closed",
		name = "Ring the Bell",
		desc = "Take a company public.",
		glyph = "🔔",
		tier = "gold",
		on = { kind = "project", projectId = "ipo", closed = true },
	},
	-- Dress code
	{
		id = "dressed_for_firm",
		name = "Dressed for the Firm",
		desc = "Meet your firm's dress code.",
		glyph = "👔",
		tier = "bronze",
		on = { kind = "outfit", meetsFirm = true },
	},
	{
		id = "sharp_dresser",
		name = "Sharp Dresser",
		desc = "Reach Outfit Level 5.",
		glyph = "🕴️",
		tier = "gold",
		on = { kind = "outfit", outfitLevel = 5 },
	},
} :: { Def }

Achievements.byId = {} :: { [string]: Def }
for _, def in Achievements.list do
	assert(Achievements.byId[def.id] == nil, "Achievements: duplicate id " .. def.id)
	Achievements.byId[def.id] = def
end

function Achievements.get(id: any): Def?
	if type(id) ~= "string" then
		return nil
	end
	return Achievements.byId[id]
end

Achievements.strings = {
	unlocked = "Achievement unlocked: {name}",
	banner_title = "Achievement unlocked",
	banner_sub = "{glyph} {name}: {desc}",
}

function Achievements.text(key: string, vars: { [string]: any }?): string
	local s = (Achievements.strings :: { [string]: string })[key] or key
	if not vars then
		return s
	end
	return (
		string.gsub(s, "{([%w_]+)}", function(k: string): string
			local v = vars[k]
			return if v == nil then "{" .. k .. "}" else tostring(v)
		end)
	)
end

return Achievements
