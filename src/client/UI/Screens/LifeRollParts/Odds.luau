--!strict
-- LifeRollParts/Odds: the exact-odds sheet for every rolled field (client UI, careerCore; design v3 §1 "odds are
-- always shown and always exact"). Every number comes from Logic/LifeRoll.oddsAll, the same tables the server rolls
-- with, including the player's rebirth luck.
--
--   Odds.open(rebirths?) -> close()   a modal over the modal layer (Back / tap outside closes it)
--   Odds.build(parent, rebirths?)     fills `parent` with the sections (also used by tests)

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config.LifeRoll)
local Rarity = require(Shared.Config.Rarity)
local LifeRoll = require(Shared.Logic.LifeRoll)
local Kit = require(script.Parent.Parent.Parent:WaitForChild("Kit"))
local Common = require(script.Parent.Common)

local Odds = {}

local function line(text: string, rarity: string?): Kit.Label
	local l = Kit.Label({ text = text, size = "sm", name = "Line" })
	if rarity and rarity ~= "common" then
		l.setColor(Common.rarityColor(rarity))
	end
	return l
end

function Odds.build(parent: Instance, rebirths: number?)
	local all = LifeRoll.oddsAll(rebirths)
	local order = 0
	local function add(child: any)
		order += 1
		local inst = if typeof(child) == "Instance" then child else child.frame
		inst.LayoutOrder = order
		inst.Parent = parent
	end
	if (rebirths or 0) > 0 then
		add(Kit.Label({ text = Config.text("odds_rebirths", { n = rebirths }), size = "sm", color = "accent" }))
	end
	for _, field in Config.FIELDS do
		local tbl = all[field]
		local section = Kit.Panel({ name = "Odds_" .. field, list = true, gap = 2, color = "panelAlt" })
		local n = 0
		local function push(l: any)
			n += 1
			l.frame.LayoutOrder = n
			l.frame.Parent = section.frame
		end
		push(Kit.Label({ text = Common.fieldTitle(field), size = "md", font = "bodyBold" }))
		if tbl.tiers then
			for _, tier in tbl.tiers do
				local count = tier.count or 0
				local text = Config.text("odds_tier_note", {
					tier = tier.name,
					odds = Rarity.percent(tier.odds),
					count = count,
					each = Rarity.percent(if count > 0 then tier.odds / count else 0),
				})
				push(line(text, tier.id))
				local names: { string } = {}
				for _, row in tbl.rows do
					if row.rarity == tier.id then
						table.insert(names, row.name)
					end
				end
				if #names > 0 then
					push(
						Kit.Label({ text = table.concat(names, ", "), size = "xs", color = "textDim", name = "Names" })
					)
				end
			end
		elseif #tbl.rows > 0 then
			for _, row in tbl.rows do
				push(line(row.name .. ": " .. Rarity.percent(row.odds), row.rarity))
			end
		end
		if tbl.counts then
			for _, c in tbl.counts do
				push(Kit.Label({
					text = Config.text("odds_clubs_count", { n = c.name, odds = Rarity.percent(c.odds) }),
					size = "sm",
				}))
			end
		end
		for _, note in tbl.notes do
			push(Kit.Label({ text = note, size = "xs", color = "textDim" }))
		end
		add(section)
	end
end

function Odds.open(rebirths: number?): () -> ()
	local modal = Kit.modal({ width = 560, name = "LifeRollOdds" }, function(card: Frame, close: () -> ())
		Kit.list(card, false, 10)
		local title = Kit.Heading({ text = Config.text("odds_title"), level = 2, layoutOrder = 1 })
		title.frame.Parent = card
		local body = Kit.Label({ text = Config.text("odds_body"), size = "sm", color = "textDim", layoutOrder = 2 })
		body.frame.Parent = card
		local scroll = Kit.Scroll({ size = UDim2.new(1, 0, 0, 380), gap = 8, name = "OddsList", layoutOrder = 3 })
		scroll.frame.Parent = card
		Odds.build(scroll.content, rebirths)
		local ok = Kit.Button({ text = Config.text("done_continue"), fill = true, onClick = close, layoutOrder = 4 })
		ok.frame.Parent = card
	end)
	return modal.close
end

return Odds
