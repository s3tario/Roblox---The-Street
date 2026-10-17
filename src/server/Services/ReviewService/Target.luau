--!strict
-- ReviewService/Target (server, runtime only): where the Friday review waypoint points (design v3 §6).
--   1. the player's own floor exists (OfficeService:GetFloor(companyId, track)): its boss_review interact (or the
--      boss_chair anchor)
--   2. the player is in their firm's lobby: the elevator panel
--   3. otherwise: the firm's tower door on the Street (Config/World towers, "street_tower_<id>_front" anchor)
--
--   Target.get(player, career) -> { kind = "boss" | "elevator" | "tower", position: Vector3, label: string }?

local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local World = require(Shared.Config.World)
local Tracks = require(Shared.Config.Tracks)
local Companies = require(Shared.Config.Companies)
local Deps = require(script.Parent.Parent.CareerService.Deps)
local Prompts = require(script.Parent.Parent.CareerService.Prompts)

local Target = {}

export type Info = { kind: string, position: Vector3, label: string }

local function partPosition(inst: Instance?): Vector3?
	if inst and inst:IsA("BasePart") then
		return inst.Position
	end
	if inst and inst:IsA("Model") then
		local ok, cf = pcall(function()
			return inst:GetPivot()
		end)
		if ok then
			return cf.Position
		end
	end
	return nil
end

local function towerAnchorId(companyId: string): string?
	for _, tower in World.towers do
		if tower.company == companyId then
			return tower.anchor
		end
	end
	for _, tower in World.towers do
		if tower.picker and table.find(tower.picker, companyId) then
			return tower.anchor
		end
	end
	return nil
end

local anchorCache: { [string]: BasePart } = {}
local function anchorPart(anchorId: string): BasePart?
	local cached = anchorCache[anchorId]
	if cached and cached.Parent and cached:IsDescendantOf(workspace) then
		return cached
	end
	for _, inst in CollectionService:GetTagged("Anchor") do
		if inst:IsA("BasePart") and inst:GetAttribute("AnchorId") == anchorId and inst:IsDescendantOf(workspace) then
			anchorCache[anchorId] = inst
			return inst
		end
	end
	return nil
end

function Target.get(player: Player, career: { [string]: any }): Info?
	local companyId = career.companyId
	local track = career.track
	if type(companyId) ~= "string" or companyId == "" or type(track) ~= "string" then
		return nil
	end
	local company = Companies.get(companyId)
	local boss = Companies.bossName(companyId, track)

	local okFloor, floor = Deps.call("OfficeService", "GetFloor", companyId, track)
	if okFloor and typeof(floor) == "Instance" and floor:IsDescendantOf(workspace) then
		for _, part in Prompts.find("boss_review", companyId, track) do
			if part:IsDescendantOf(floor) then
				return {
					kind = "boss",
					position = part.Position,
					label = Tracks.text("review_target_boss", { boss = boss }),
				}
			end
		end
		local okAnchor, anchor = Deps.call("OfficeService", "GetAnchor", companyId, track, "boss_chair")
		local pos = if okAnchor then partPosition(anchor) else nil
		if pos then
			return { kind = "boss", position = pos, label = Tracks.text("review_target_boss", { boss = boss }) }
		end
	end

	local okLoc, loc = Deps.call("OfficeService", "GetPlayerLocation", player)
	if okLoc and type(loc) == "table" and loc.companyId == companyId and loc.floor == "lobby" then
		for _, part in Prompts.find("elevator_panel", companyId) do
			return { kind = "elevator", position = part.Position, label = Tracks.text("review_target_elevator") }
		end
	end

	local anchorId = towerAnchorId(companyId)
	local part = if anchorId then anchorPart(anchorId) else nil
	if part then
		return {
			kind = "tower",
			position = part.Position,
			label = Tracks.text("review_target_tower", { company = if company then company.name else "" }),
		}
	end
	return nil
end

return Target
