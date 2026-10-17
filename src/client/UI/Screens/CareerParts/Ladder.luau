--!strict
-- CareerParts/Ladder (client): the Ladder tab of the Career hub: every title on the player's track (level band,
-- weekly pay, trading book, dress level, school gate) with the current rank highlighted, plus the other careers
-- that arrive in later updates ("Coming soon").
--   Ladder.build(scroll, career)

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Tracks = require(Shared.Config.Tracks)
local Companies = require(Shared.Config.Companies)
local Common = require(script.Parent.Common)
local Kit = Common.Kit

local Ladder = {}

local function num(x: any, default: number): number
	if type(x) == "number" and x == x then
		return x
	end
	return default
end

function Ladder.build(scroll: any, career: { [string]: any })
	local trackId = if type(career.track) == "string" and career.track ~= "" then career.track else "ib"
	local track = Tracks.get(trackId) or Tracks.get("ib")
	if not track then
		return
	end
	local company = Companies.get(career.companyId)
	local payMult = if company then company.payMult else 1
	local bookMult = if company then company.bookMult else 1
	local rank = math.floor(num(career.rank, 0))
	if career.status == "fired" and type(career.fired) == "table" then
		rank = math.floor(num(career.fired.rank, rank))
	end

	local card = Kit.Card({
		title = Common.text("ui_ladder", { track = track.name }),
		subtitle = track.difficulty,
		name = "Ladder",
	})
	scroll.add(card)
	for i = #track.ladder, 1, -1 do
		local role = track.ladder[i]
		local current = role.rank == rank
		local panel = Kit.Panel({
			color = if current then "surface" else "panelAlt",
			padding = 10,
			name = "Rank_" .. role.rank,
		})
		Kit.list(panel.frame, false, 4)
		local titleRow = Kit.frame("TitleRow", UDim2.new(1, 0, 0, 24))
		titleRow.LayoutOrder = 1
		titleRow.Parent = panel.frame
		local title = Kit.Label({
			text = role.title,
			size = "md",
			font = "bodyBold",
			color = if current then "accent" elseif role.rank < rank then "textDim" else "text",
			autoSize = "none",
			height = 24,
		})
		title.frame.Size = UDim2.new(1, -110, 1, 0)
		title.frame.Parent = titleRow
		local band = Kit.Badge({
			text = Common.text("ui_ladder_levels", { min = role.minLevel, max = role.maxLevel }),
			color = if current then "accent" else "border",
			size = "xs",
		})
		band.frame.AnchorPoint = Vector2.new(1, 0.5)
		band.frame.Position = UDim2.fromScale(1, 0.5)
		band.frame.Parent = titleRow
		local details = Common.text("ui_ladder_details", {
			pay = Common.compact((role.salary + role.bonus) * payMult),
			book = Common.compact(role.book * bookMult),
			dress = Tracks.dressLevelFor(role),
		})
		Kit.Label({ text = details, size = "xs", color = "textDim", layoutOrder = 2 }).frame.Parent = panel.frame
		if role.schoolGate then
			Kit.Label({
				text = Common.text("ui_ladder_gate", { tier = Tracks.tierName(role.schoolGate) }),
				size = "xs",
				color = "warn",
				layoutOrder = 3,
			}).frame.Parent =
				panel.frame
		end
		if current then
			Kit.Label({ text = Common.text("ui_ladder_you"), size = "xs", color = "accent", layoutOrder = 4 }).frame.Parent =
				panel.frame
		end
		card.add(panel)
	end

	local others = Kit.Card({ title = Common.text("ui_other_tracks"), name = "OtherTracks" })
	scroll.add(others)
	for _, t in Tracks.list do
		if t.id ~= track.id then
			local row = Kit.frame("Track_" .. t.id, UDim2.new(1, 0, 0, 30))
			local name = Kit.Label({ text = t.name, size = "sm", autoSize = "none", height = 30 })
			name.frame.Size = UDim2.new(1, -120, 1, 0)
			name.frame.Parent = row
			local chip = Kit.Badge({
				text = if t.available then t.entryTitle else Common.text("ui_coming_soon"),
				color = if t.available then "good" else "border",
				size = "xs",
			})
			chip.frame.AnchorPoint = Vector2.new(1, 0.5)
			chip.frame.Position = UDim2.fromScale(1, 0.5)
			chip.frame.Parent = row
			others.add(row)
		end
	end
end

return Ladder
