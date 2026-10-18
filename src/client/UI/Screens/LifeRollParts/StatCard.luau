--!strict
-- LifeRollParts/StatCard: the MyCareer-style player card (design v3 §14b) — big OVR, archetype, school crest,
-- name with family name, degree / GPA / clubs / family with rarity colours, the eight attribute bars with this
-- week's growth, and perks. Used by the Stats and LifeRoll screens and REUSED BY the ProfileCard (tutorial):
--
--   local StatCard = require(Client.UI.Screens.LifeRollParts.StatCard)
--   local cleanup = StatCard.mount(container, publicProfile, opts?)
--   ...
--   cleanup()                                -- destroys everything it created
--
--   container       any GuiObject; the card fills its width and grows in height (AutomaticSize Y)
--   publicProfile   Logic/LifeRoll.publicView(profile, {userId, displayName}) — the shape of
--                   ProfileService:GetPublicProfile / the "Profile.GetPublic" remote / CareerCoreController:GetPublic
--   opts = { growth: boolean? (default true: "+n this week"), perks: boolean? (default true),
--            compact: boolean? (smaller crest and OVR for side panels), layoutOrder: number? }
-- Pure UI: no services, no remotes; safe under Lune.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config.LifeRoll)
local Kit = require(script.Parent.Parent.Parent:WaitForChild("Kit"))
local Common = require(script.Parent.Common)
local Crest = require(script.Parent.Crest)

export type Opts = { growth: boolean?, perks: boolean?, compact: boolean?, layoutOrder: number? }

local StatCard = {}

local function chip(text: string, rarity: string?, layoutOrder: number): Kit.Badge
	local color = Common.rarityColor(rarity)
	local b = Kit.Badge({
		text = text,
		color = color,
		size = "sm",
		name = "Chip",
		layoutOrder = layoutOrder,
	})
	return b
end

local function row(parent: Instance, name: string, height: number?, order: number): Frame
	local f = Kit.frame(name, UDim2.new(1, 0, 0, height or 0))
	if not height then
		f.AutomaticSize = Enum.AutomaticSize.Y
	end
	f.LayoutOrder = order
	f.Parent = parent
	return f
end

function StatCard.mount(container: Instance, view: any, opts: Opts?): () -> ()
	local o: Opts = opts or {}
	local v = if type(view) == "table" then view else {}
	local stats = if type(v.stats) == "table" then v.stats else {}
	local gains = if type(v.weekGains) == "table" then v.weekGains else {}
	local compact = o.compact == true
	local stops: { () -> () } = {}

	local card = Kit.Panel({ name = "StatCard", list = true, gap = 10, color = "panelAlt" })
	card.frame.LayoutOrder = o.layoutOrder or 0

	-- Header: crest | name, school, archetype | OVR
	local crestSize = if compact then 64 else 92
	local header = row(card.frame, "Header", crestSize, 1)
	Crest.mount(header, v.school, crestSize)

	local ovr = tonumber(v.ovr) or 1
	local ovrColor, ovrTier = Common.ovrColor(ovr)
	local ovrW = if compact then 72 else 96
	local ovrBox = Instance.new("Frame")
	ovrBox.Name = "OVR"
	ovrBox.AnchorPoint = Vector2.new(1, 0)
	ovrBox.Position = UDim2.fromScale(1, 0)
	ovrBox.Size = UDim2.fromOffset(ovrW, crestSize)
	ovrBox.BorderSizePixel = 0
	ovrBox.Parent = header
	local ovrCorner = Kit.corner(ovrBox)
	local ovrStroke = Kit.stroke(ovrBox)
	ovrStroke.Color = ovrColor
	ovrStroke.Thickness = 2
	local ovrNum = Instance.new("TextLabel")
	ovrNum.Name = "Value"
	ovrNum.BackgroundTransparency = 1
	ovrNum.Size = UDim2.new(1, 0, 0.68, 0)
	ovrNum.Text = tostring(ovr)
	ovrNum.TextScaled = true
	ovrNum.TextColor3 = ovrColor
	ovrNum.Parent = ovrBox
	local ovrPad = Instance.new("UIPadding")
	ovrPad.PaddingTop = UDim.new(0, 6)
	ovrPad.Parent = ovrNum
	local ovrCap = Instance.new("TextLabel")
	ovrCap.Name = "Caption"
	ovrCap.BackgroundTransparency = 1
	ovrCap.Position = UDim2.fromScale(0, 0.68)
	ovrCap.Size = UDim2.new(1, 0, 0.32, 0)
	ovrCap.Text = Config.text("stats_overall")
	ovrCap.Parent = ovrBox
	Kit.themed(ovrBox, function(t)
		ovrBox.BackgroundColor3 = t.colors.panel
		ovrCorner.CornerRadius = UDim.new(0, t.radius)
		ovrNum.FontFace = t.fonts.display
		ovrCap.FontFace = t.fonts.bodyBold
		ovrCap.TextSize = t.text.sm
		ovrCap.TextColor3 = t.colors.textDim
	end)
	if ovrTier == "mythic" then
		ovrNum.TextColor3 = Color3.new(1, 1, 1)
		table.insert(stops, Common.prismatic(ovrNum))
		table.insert(stops, Common.prismatic(ovrStroke))
	end

	local titles = Kit.List({ gap = 2, name = "Titles", autoSize = "none" })
	titles.frame.Position = UDim2.fromOffset(crestSize + 12, 0)
	titles.frame.Size = UDim2.new(1, -(crestSize + ovrW + 24), 1, 0)
	titles.layout.VerticalAlignment = Enum.VerticalAlignment.Center
	titles.frame.Parent = header
	titles.add(Kit.Heading({
		text = if type(v.fullName) == "string" and v.fullName ~= "" then v.fullName else "—",
		level = if compact then 3 else 2,
		name = "Name",
	}))
	local school = v.school
	if type(school) == "table" then
		local schoolLabel = Kit.Label({ text = school.name, size = "md", font = "bodyBold", name = "School" })
		if school.rarity ~= "common" then
			schoolLabel.setColor(Common.rarityColor(school.rarity))
		end
		titles.add(schoolLabel)
		if school.rarity == "mythic" then
			schoolLabel.setColor(Color3.new(1, 1, 1))
			table.insert(stops, Common.prismatic(schoolLabel.frame))
		end
	end
	local arche = if type(v.archetype) == "table" then v.archetype else nil
	if arche and v.built ~= false then
		titles.add(
			Kit.Label({ text = arche.name, size = "sm", color = "accent", font = "bodyBold", name = "Archetype" })
		)
	end

	-- Background: degree / GPA, family, clubs
	if v.built ~= false then
		local bg = Kit.List({ gap = 6, name = "Background", layoutOrder = 2 })
		bg.frame.Parent = card.frame
		local degree = if type(v.degree) == "table" then v.degree else nil
		local gpa = tonumber(v.gpa) or 0
		if degree then
			bg.add(Kit.Label({
				text = Config.text("degree_line", { degree = degree.long, gpa = string.format("%.2f", gpa) }),
				size = "sm",
				name = "Degree",
			}))
		end
		local chips = Kit.List({
			direction = "horizontal",
			wraps = true,
			gap = 6,
			name = "Chips",
			size = UDim2.new(1, 0, 0, 0),
			autoSize = "y",
		})
		bg.add(chips)
		local order = 0
		local family = v.family
		if type(family) == "table" then
			order += 1
			chips.add(chip(Config.text("family_line", { family = family.name }), family.rarity, order))
		end
		if type(v.clubs) == "table" then
			for _, c in v.clubs do
				order += 1
				chips.add(chip((c.glyph or "") .. " " .. tostring(c.name), c.rarity, order))
			end
		end
		if type(school) == "table" and type(school.motto) == "string" and not compact then
			bg.add(Kit.Label({ text = "“" .. school.motto .. "”", size = "xs", color = "textDim", name = "Motto" }))
		end
	end

	-- Attributes
	local attrs = Kit.List({ gap = 4, name = "Attributes", layoutOrder = 3 })
	attrs.frame.Parent = card.frame
	for i, def in Config.stats do
		local value = math.clamp(math.floor(tonumber(stats[def.id]) or 1), 1, 99)
		local line = Kit.frame("Stat_" .. def.id, UDim2.new(1, 0, 0, 24))
		line.LayoutOrder = i
		line.Parent = attrs.frame
		local name = Kit.Label({ text = def.name, size = "sm", autoSize = "none", height = 24, name = "Name" })
		name.frame.Size = UDim2.new(0, 104, 1, 0)
		name.frame.Parent = line
		local gain = math.floor(tonumber(gains[def.id]) or 0)
		local showGain = o.growth ~= false and gain > 0
		local rightW = if showGain then 104 else 40
		local barColor = Common.ovrColor(value)
		local bar = Kit.ProgressBar({ value = value / 99, color = barColor, height = 10, name = "Bar" })
		bar.frame.AnchorPoint = Vector2.new(0, 0.5)
		bar.frame.Position = UDim2.new(0, 110, 0.5, 0)
		bar.frame.Size = UDim2.new(1, -(110 + rightW + 6), 0, 10)
		bar.frame.Parent = line
		local num = Kit.Label({
			text = tostring(value),
			size = "md",
			font = "mono",
			align = "right",
			autoSize = "none",
			height = 24,
			name = "Value",
		})
		num.frame.AnchorPoint = Vector2.new(1, 0)
		num.frame.Position = UDim2.new(1, -(rightW - 40), 0, 0)
		num.frame.Size = UDim2.new(0, 40, 1, 0)
		num.frame.Parent = line
		if showGain then
			local g = Kit.Label({
				text = Config.text("stats_week", { n = gain }),
				size = "xs",
				color = "good",
				align = "right",
				autoSize = "none",
				height = 24,
				name = "Gain",
			})
			g.frame.AnchorPoint = Vector2.new(1, 0)
			g.frame.Position = UDim2.fromScale(1, 0)
			g.frame.Size = UDim2.new(0, 60, 1, 0)
			g.frame.Parent = line
		end
	end

	-- Perks
	if o.perks ~= false and v.built ~= false then
		local perks = if type(v.perks) == "table" then v.perks else {}
		local box = Kit.List({ gap = 4, name = "Perks", layoutOrder = 4 })
		box.frame.Parent = card.frame
		box.add(Kit.Label({ text = Config.text("stats_perks"), size = "sm", font = "bodyBold", color = "textDim" }))
		if #perks == 0 then
			box.add(Kit.Label({ text = Config.text("stats_no_perks"), size = "sm", color = "textDim", name = "None" }))
		end
		for _, perk in perks do
			local label = if (tonumber(perk.count) or 1) > 1
				then Config.text("perk_uses", { name = perk.name, n = perk.count })
				else tostring(perk.name)
			box.add(Kit.Label({
				text = tostring(perk.glyph or "") .. " " .. label .. " — " .. tostring(perk.desc or ""),
				size = "sm",
				name = "Perk_" .. tostring(perk.id),
			}))
		end
		if (tonumber(v.rebirths) or 0) > 0 then
			box.add(
				Kit.Label({ text = Config.text("stats_rebirths", { n = v.rebirths }), size = "sm", color = "accent" })
			)
		end
	end

	card.frame.Parent = container

	local done = false
	return function()
		if done then
			return
		end
		done = true
		for _, stop in stops do
			pcall(stop)
		end
		card.frame:Destroy()
	end
end

return StatCard
