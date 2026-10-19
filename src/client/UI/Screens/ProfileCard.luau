--!strict
-- ProfileCard (client screen, owned by `tutorial`; design v3 §14b): tap any player to see their story.
-- Name with family name, school crest and rarity, degree, GPA, clubs, family, OVR and the 8 stats, archetype (the
-- careerCore StatCard when it is available, a plain fallback otherwise), company logo and title, level, Fit Score,
-- outfit level, deal plaques, rebirths, achievements and aura tier. "Exchange cards" (Social.Network) works within
-- 15 studs, once per pair per real day; the button says why when it can't.
-- Data: "Social.GetCard"(userId) through SocialController (public fields only).
--   args = { userId: number }

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Quests = require(Shared.Config.Quests)
local Rarity = require(Shared.Config.Rarity)
local Kit = require(script.Parent.Parent:WaitForChild("Kit"))

local ProfileCard = { id = "ProfileCard" }

type Scroll = { frame: ScrollingFrame, add: (child: any) -> GuiObject, clear: () -> () }

local RANGE_EVERY = 0.5
local LOGO_SIZE = 48
local STAT_ORDER = { "knowledge", "skill", "speed", "charisma", "network", "discipline", "risk", "luck" }
local STAT_NAMES = {
	knowledge = "Knowledge",
	skill = "Skill",
	speed = "Speed",
	charisma = "Charisma",
	network = "Network",
	discipline = "Discipline",
	risk = "Risk Sense",
	luck = "Luck",
} :: { [string]: string }

local function text(key: string, vars: { [string]: any }?): string
	return Quests.text(key, vars)
end

local function registryGet(ctx: any, name: string): any
	local registry = if type(ctx) == "table" then ctx.Registry else nil
	if not registry then
		return nil
	end
	local ok, c = pcall(function()
		return registry.get(name)
	end)
	return if ok then c else nil
end

local function hexColor(s: any, default: Color3): Color3
	if type(s) == "string" and string.match(s, "^#%x%x%x%x%x%x$") then
		local ok, c = pcall(Color3.fromHex, s)
		if ok then
			return c
		end
	end
	return default
end

local function num(x: any, default: number): number
	if type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge then
		return x
	end
	return default
end

-- Optional modules from other features, loaded once and guarded.
local statCardModule: any = nil
local statCardTried = false
local function statCard(): any
	if not statCardTried then
		statCardTried = true
		local ok, mod = pcall(function()
			local parts = script.Parent:FindFirstChild("LifeRollParts")
			local m = parts and parts:FindFirstChild("StatCard")
			return if m and m:IsA("ModuleScript") then (require :: any)(m) else nil
		end)
		if ok and type(mod) == "table" and type(mod.mount) == "function" then
			statCardModule = mod
		elseif not ok then
			warn("[ProfileCard] StatCard unavailable: " .. tostring(mod))
		end
	end
	return statCardModule
end

local logosModule: any = nil
local logosTried = false
local function logos(): any
	if not logosTried then
		logosTried = true
		local ok, mod = pcall(function()
			local assets = Shared:FindFirstChild("Assets")
			local m = assets and assets:FindFirstChild("Logos")
			return if m and m:IsA("ModuleScript") then (require :: any)(m) else nil
		end)
		if ok and type(mod) == "table" and type(mod.render) == "function" then
			logosModule = mod
		elseif not ok then
			warn("[ProfileCard] Logos unavailable: " .. tostring(mod))
		end
	end
	return logosModule
end

local function logoBox(parent: Instance, logoId: any, initials: string, primary: Color3, order: number)
	local box = Instance.new("Frame")
	box.Name = "Logo"
	box.Size = UDim2.fromOffset(LOGO_SIZE, LOGO_SIZE)
	box.BackgroundColor3 = Color3.fromRGB(245, 243, 238)
	box.BorderSizePixel = 0
	box.ClipsDescendants = true
	box.LayoutOrder = order
	Kit.corner(box, 8)
	box.Parent = parent
	local L = logos()
	local drawn = false
	if L and type(logoId) == "string" then
		drawn = pcall(function()
			L.render(box, logoId, { px = LOGO_SIZE, simple = true, padding = 0.1, name = "Mark" })
		end)
	end
	if not drawn then
		box.BackgroundColor3 = primary
		local mono = Instance.new("TextLabel")
		mono.Name = "Monogram"
		mono.BackgroundTransparency = 1
		mono.Size = UDim2.fromScale(1, 1)
		mono.Text = string.upper(string.sub(initials, 1, 2))
		mono.TextScaled = true
		mono.FontFace = Font.fromEnum(Enum.Font.GothamBold)
		mono.TextColor3 = Color3.new(1, 1, 1)
		mono.Parent = box
	end
end

local function hrow(name: string, gap: number?): Frame
	local f = Kit.frame(name, UDim2.new(1, 0, 0, 0))
	f.AutomaticSize = Enum.AutomaticSize.Y
	local l = Kit.list(f, true, gap or 10)
	l.VerticalAlignment = Enum.VerticalAlignment.Center
	return f
end

-- A plain version of the player card for when the careerCore StatCard isn't there.
local function fallbackCard(scroll: Scroll, public: { [string]: any })
	local card = Kit.Card({ title = tostring(public.fullName or ""), name = "Story", gap = 6 })
	scroll.add(card)
	local school = if type(public.school) == "table" then public.school else nil
	if school then
		card.add(Kit.Label({
			text = ("%s · %s"):format(tostring(school.name), Rarity.name(school.rarity)),
			size = "md",
			font = "bodyBold",
			color = Rarity.color(school.rarity),
			name = "School",
		}))
	end
	local degree = if type(public.degree) == "table" then public.degree.name else nil
	local lineParts: { string } = {}
	if type(degree) == "string" then
		table.insert(lineParts, degree)
	end
	if type(public.gpa) == "number" then
		table.insert(lineParts, ("GPA %.2f"):format(public.gpa))
	end
	if #lineParts > 0 then
		card.add(Kit.Label({ text = table.concat(lineParts, " · "), size = "sm", name = "Degree" }))
	end
	local family = if type(public.family) == "table" then public.family else nil
	if family then
		card.add(Kit.Label({
			text = ("%s · %s"):format(tostring(family.name), Rarity.name(family.rarity)),
			size = "sm",
			color = Rarity.color(family.rarity),
			name = "Family",
		}))
	end
	if type(public.clubs) == "table" and #public.clubs > 0 then
		local names: { string } = {}
		for _, c in public.clubs do
			if type(c) == "table" then
				table.insert(names, tostring(c.name))
			end
		end
		card.add(Kit.Label({ text = table.concat(names, ", "), size = "sm", color = "textDim", name = "Clubs" }))
	end
	local arche = if type(public.archetype) == "table" then public.archetype.name else nil
	card.add(Kit.Label({
		text = ("OVR %d%s"):format(
			math.floor(num(public.ovr, 0)),
			if type(arche) == "string" then " · " .. arche else ""
		),
		size = "lg",
		font = "bodyBold",
		color = "accent",
		name = "Ovr",
	}))
	local stats = if type(public.stats) == "table" then public.stats else {}
	for _, id in STAT_ORDER do
		local v = math.floor(num(stats[id], 0))
		card.add(Kit.ProgressBar({
			value = v / 99,
			height = 18,
			label = ("%s  %d"):format(STAT_NAMES[id] or id, v),
			name = "Stat_" .. id,
		}))
	end
end

local function tile(grid: any, title: string, value: string, order: number)
	local panel =
		Kit.Panel({ name = "Tile" .. order, color = "panelAlt", padding = 8, list = true, gap = 2, autoSize = "none" })
	panel.frame.LayoutOrder = order
	panel.add(Kit.Label({ text = value, size = "lg", font = "bodyBold", align = "center", name = "Value" }))
	panel.add(Kit.Label({ text = title, size = "xs", color = "textDim", align = "center", name = "Title" }))
	grid.add(panel.frame)
	panel.frame.LayoutOrder = order
end

---------------------------------------------------------------------------------------------------
-- Screen
---------------------------------------------------------------------------------------------------
function ProfileCard.open(args: any, root: Instance, ctx: any): { close: () -> () }
	local a = if type(args) == "table" then args else {}
	local userId = math.floor(num(a.userId, 0))
	local social = registryGet(ctx, "SocialController")
	local ui = if type(ctx) == "table" then ctx.UI else nil
	local closed = false
	local busy = false
	local card: { [string]: any }? = nil
	local loadErr: string? = nil
	local cleanups: { () -> () } = {}
	local exchangeButton: Kit.Button? = nil

	local win = Kit.Window({
		title = text("card_title"),
		size = UDim2.fromScale(1, 1),
		maxSize = Vector2.new(560, 760),
		onClose = if type(ctx) == "table" then ctx.close else nil,
		name = "ProfileCardWindow",
	})
	win.frame.Parent = root
	local scroll: Scroll = Kit.Scroll({ padding = 2, gap = 10, name = "Scroll" })
	scroll.frame.Parent = win.content

	local function runCleanups()
		for _, fn in cleanups do
			pcall(fn)
		end
		table.clear(cleanups)
	end

	local function targetPlayer(): Player?
		if userId <= 0 then
			return nil
		end
		return Players:GetPlayerByUserId(userId)
	end

	local function distance(): number
		local me = Players.LocalPlayer.Character
		local other = targetPlayer()
		local them = if other then other.Character else nil
		local a1 = if me then me:FindFirstChild("HumanoidRootPart") else nil
		local b1 = if them then them:FindFirstChild("HumanoidRootPart") else nil
		if a1 and b1 and a1:IsA("BasePart") and b1:IsA("BasePart") then
			return (a1.Position - b1.Position).Magnitude
		end
		return math.huge
	end

	-- The exchange button's state: self, already today, too far, or ready.
	local function paintExchange()
		local b = exchangeButton
		local c = card
		if not b or not c then
			return
		end
		local range = num(c.range, 15)
		if c.isSelf == true then
			b.setText(text("card_self"))
			b.setDisabled(true)
		elseif c.exchangedToday == true then
			b.setText(text("card_exchanged"))
			b.setDisabled(true)
		elseif distance() > range then
			b.setText(text("card_too_far"))
			b.setDisabled(true)
		else
			b.setText(text("card_exchange"))
			b.setDisabled(busy)
		end
	end

	local render: () -> ()

	local function fetch()
		if closed or not social then
			return
		end
		task.spawn(function()
			local ok, c, err = pcall(function()
				return social:GetCard(userId)
			end)
			if closed then
				return
			end
			if ok and type(c) == "table" then
				card = c
				loadErr = nil
			else
				loadErr = if ok and type(err) == "string" then err else "generic"
			end
			render()
		end)
	end

	local function exchange()
		local c = card
		if busy or closed or not social or not c then
			return
		end
		busy = true
		paintExchange()
		task.spawn(function()
			local ok, success, err, fresh = pcall(function()
				return social:Exchange(userId)
			end)
			busy = false
			if closed then
				return
			end
			if ok and type(fresh) == "table" then
				card = fresh
			end
			if not ok or success ~= true then
				local key = "exchange_err_" .. tostring(if ok then err else "generic")
				local msg = if type(Quests.strings[key]) == "string" then text(key) else text("exchange_err_generic")
				if ui and type(ui.Notify) == "function" then
					ui:Notify(msg, "warn")
				end
			end
			render()
		end)
	end

	render = function()
		if closed then
			return
		end
		runCleanups()
		scroll.clear()
		exchangeButton = nil
		local c = card
		if not c then
			scroll.add(Kit.Label({
				text = if loadErr then text("card_unavailable") else text("card_loading"),
				color = "textDim",
				align = "center",
				name = "Status",
			}))
			return
		end
		local public = if type(c.public) == "table" then c.public else {}
		local career = if type(c.career) == "table" then c.career else {}
		local name = tostring(c.name or public.fullName or c.displayName or "")
		win.setTitle(if name ~= "" then name else text("card_title"))
		win.setSubtitle(text("card_level", { level = math.floor(num(career.level, 1)) }))

		-- Career line: company logo, title and firm in its colours (or Student and their school)
		local company = if type(c.company) == "table" then c.company else nil
		local head = Kit.Panel({ name = "Career", color = "panelAlt", padding = 10 })
		local line = hrow("Line", 10)
		line.Parent = head.frame
		if company then
			local primary = hexColor(company.primary, Color3.fromRGB(40, 50, 70))
			logoBox(line, company.logo, tostring(company.name or "?"), primary, 1)
		end
		local who = Kit.frame("Who", UDim2.new(1, if company then -(LOGO_SIZE + 12) else 0, 0, 0))
		who.AutomaticSize = Enum.AutomaticSize.Y
		who.LayoutOrder = 2
		who.Parent = line
		Kit.list(who, false, 2)
		local titleText = if type(career.title) == "string" and career.title ~= ""
			then career.title
			else text("card_student")
		Kit.Label({ text = titleText, size = "lg", font = "bodyBold", name = "Title", layoutOrder = 1 }).frame.Parent =
			who
		if company then
			local accent = hexColor(company.accent, Color3.fromRGB(201, 165, 76))
			local primary = hexColor(company.primary, accent)
			-- the brighter of the firm's two colours reads best on a dark card
			local function lum(col: Color3): number
				return 0.2126 * col.R + 0.7152 * col.G + 0.0722 * col.B
			end
			Kit.Label({
				text = tostring(company.name)
					.. (if type(company.typeName) == "string" then " · " .. company.typeName else ""),
				size = "sm",
				color = if lum(accent) >= lum(primary) then accent else primary,
				name = "Company",
				layoutOrder = 2,
			}).frame.Parent =
				who
		elseif type(public.school) == "table" then
			Kit.Label({
				text = tostring(public.school.name),
				size = "sm",
				color = Rarity.color(public.school.rarity),
				name = "School",
				layoutOrder = 2,
			}).frame.Parent =
				who
		end
		if career.status == "probation" or career.status == "fired" then
			Kit.Label({
				text = text("card_status_" .. tostring(career.status)),
				size = "xs",
				color = "warn",
				name = "Status",
				layoutOrder = 3,
			}).frame.Parent =
				who
		end
		scroll.add(head)

		-- The story (Life Roll public view)
		if public.built == true then
			local holder = Kit.frame("StoryHolder", UDim2.new(1, 0, 0, 0))
			holder.AutomaticSize = Enum.AutomaticSize.Y
			scroll.add(holder)
			local SC = statCard()
			local mounted = false
			if SC then
				local ok, cleanup = pcall(SC.mount, holder, public, { growth = false, perks = true })
				if ok then
					mounted = true
					if type(cleanup) == "function" then
						table.insert(cleanups, cleanup)
					end
				else
					warn("[ProfileCard] StatCard failed: " .. tostring(cleanup))
					Kit.clear(holder)
				end
			end
			if not mounted then
				holder:Destroy()
				fallbackCard(scroll, public)
			end
		else
			scroll.add(
				Kit.Label({ text = text("card_unbuilt"), color = "textDim", align = "center", name = "Unbuilt" })
			)
		end

		-- Career numbers
		local grid = Kit.Grid({ columns = 3, cellHeight = 74, gap = 8, name = "Numbers" })
		scroll.add(grid)
		local aura = math.floor(num(c.aura, 0))
		local cells = {
			{ text("card_career"), text("card_level", { level = math.floor(num(career.level, 1)) }) },
			{ text("card_fit"), tostring(math.floor(num(c.fitScore, 0))) },
			{ text("card_outfit"), tostring(math.floor(num(c.outfitLevel, 1))) },
			{ text("card_plaques"), tostring(math.floor(num(c.plaques, 0))) },
			{ text("card_rebirths"), tostring(math.floor(num(c.rebirths, 0))) },
			{
				text("card_achievements"),
				("%d/%d"):format(math.floor(num(c.achievements, 0)), math.floor(num(c.achievementsTotal, 0))),
			},
			{ text("card_aura"), if aura > 0 then text("card_aura_tier", { tier = aura }) else text("card_aura_none") },
		}
		for i, cell in cells do
			tile(grid, cell[1], cell[2], i)
		end

		-- Exchange cards
		local b = Kit.Button({
			text = text("card_exchange"),
			fill = true,
			name = "Exchange",
			onClick = exchange,
		})
		scroll.add(b)
		exchangeButton = b
		paintExchange()
	end

	render()
	if userId > 0 and social then
		fetch()
	else
		loadErr = "gone"
		render()
	end

	-- the button follows the distance as either player walks; the card closes if they leave
	local leftConn = Players.PlayerRemoving:Connect(function(p: Player)
		if p.UserId == userId and not closed then
			card = nil
			loadErr = "gone"
			render()
		end
	end)
	task.spawn(function()
		while not closed do
			task.wait(RANGE_EVERY)
			if not closed then
				paintExchange()
			end
		end
	end)

	return {
		close = function()
			if closed then
				return
			end
			closed = true
			leftConn:Disconnect()
			runCleanups()
			win.close()
		end,
	}
end

return ProfileCard
