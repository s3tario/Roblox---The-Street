--!strict
-- NpcRig (owned by `wardrobe`, docs/contracts.md §9): blocky R15-proportioned figures built from Parts,
-- for baked mannequins, NPC stand-ins and the wardrobe's viewport preview. BAKE-SAFE.
--
--   NpcRig.build(opts?) -> Model
--     opts = {
--       name, preset,                  -- preset = Catalog.presets id ("barista", "md", ...); explicit opts win
--       skin, hairColor,               -- Color3 or "#RRGGBB" (defaults: picked from Palette by name)
--       hairStyle,                     -- short side_part bun long curly buzz ponytail bald none
--       equipped,                      -- { [slot] = itemId } (Wardrobe.apply; base pieces fill top/bottom/shoes)
--       pose,                          -- stand | sit | arms_crossed | wave
--       scale, dims,                   -- uniform scale (default 1) / per-part size overrides (Body.dims)
--       cframe,                        -- placement: the floor point under the figure, facing its LookVector;
--                                      -- for pose "sit" it is the TOP OF THE SEAT under the hips
--       parent, anchored (default true), humanoid (default true), face (default true),
--       expression,                    -- smile | neutral | grin | focused (default picked by name)
--       glint, strict,                 -- passed to Wardrobe.apply
--     }
--     The model has the standard R15 part names, a HumanoidRootPart (PrimaryPart), a Humanoid, Motor6Ds
--     matching the pose, a SurfaceGui face, hair (Folder "Hair") and the Career Look (Folder "CareerLook").
--   NpcRig.seatHeight(scale?) -> number    floor-to-seat height at which a seated rig's feet touch the floor
--   NpcRig.resolve(opts?) -> Resolved      the defaults build() would use (also used by NpcRig.spawn)
--   NpcRig.spawn(opts) -> Model?           RUNTIME ONLY (server): see Npc/Spawn.luau
--   NpcRig.HAIR_STYLES, NpcRig.POSES, NpcRig.EXPRESSIONS

local Shared = script.Parent.Parent.Parent
local Catalog = require(Shared.Config.Catalog)
local Palette = require(Shared.Build.Palette)
local Hash = require(Shared.Util.Hash)
local Wardrobe = require(script.Parent.Parent.Wardrobe)
local Body = require(script.Parent.Body)
local Hair = require(script.Parent.Hair)
local Face = require(script.Parent.Face)

local NpcRig = {}

NpcRig.HAIR_STYLES = table.clone(Hair.STYLES)
table.insert(NpcRig.HAIR_STYLES, "none")
NpcRig.POSES = Body.POSE_IDS
NpcRig.EXPRESSIONS = Face.EXPRESSIONS
NpcRig.Body = Body

export type BuildOpts = {
	name: string?,
	preset: string?,
	skin: any?,
	hairColor: any?,
	hairStyle: string?,
	equipped: { [string]: string }?,
	pose: string?,
	scale: number?,
	dims: { [string]: Vector3 }?,
	cframe: CFrame?,
	parent: Instance?,
	anchored: boolean?,
	humanoid: boolean?,
	face: boolean?,
	expression: string?,
	glint: boolean?,
	strict: boolean?,
	anchorRoot: boolean?, -- spawn only
	seed: any?,
}

export type Resolved = {
	name: string,
	skin: Color3,
	hairStyle: string,
	hairColor: Color3?,
	equipped: { [string]: string },
	pose: string,
	expression: string,
	scale: number,
}

local PART_ORDER = {
	"HumanoidRootPart",
	"LowerTorso",
	"UpperTorso",
	"Head",
	"LeftUpperArm",
	"LeftLowerArm",
	"LeftHand",
	"RightUpperArm",
	"RightLowerArm",
	"RightHand",
	"LeftUpperLeg",
	"LeftLowerLeg",
	"LeftFoot",
	"RightUpperLeg",
	"RightLowerLeg",
	"RightFoot",
}

local function toColor(v: any): Color3?
	if typeof(v) == "Color3" then
		return v
	end
	if type(v) == "string" and string.match(v, "^#%x%x%x%x%x%x$") then
		return Palette.hex(v)
	end
	return nil
end

local function pick<T>(list: { T }, ...: any): T
	return list[(Hash.u32(...) % #list) + 1]
end

function NpcRig.resolve(opts: BuildOpts?): Resolved
	local o: BuildOpts = opts or {}
	local preset: { [string]: any } = (if o.preset then Catalog.presets[o.preset] else nil) or {}
	local name = o.name or (if o.preset then "Npc_" .. o.preset else "Npc")
	local seed = if o.seed ~= nil then o.seed else name
	local skin = toColor(o.skin) or toColor(preset.skin) or pick(Palette.skin, seed, "skin")
	local explicitHair = toColor(o.hairColor) or toColor(preset.hairColor)
	local style = o.hairStyle or preset.hairStyle
	if style == nil or not (Hair.isStyle(style) or style == "none") then
		style = pick({ "short", "side_part", "bun", "long", "curly", "buzz", "ponytail" }, seed, "hair")
	end
	local hairColor = explicitHair
	if hairColor == nil and style ~= "bald" and style ~= "none" then
		hairColor = pick(Palette.hair, seed, "hairColor")
	end
	local equipped: { [string]: string } = {}
	local source = o.equipped or preset.equipped
	if type(source) == "table" then
		for slot, id in source do
			if type(slot) == "string" and type(id) == "string" then
				equipped[slot] = id
			end
		end
	end
	local pose = o.pose or preset.pose
	if pose == nil or Body.POSES[pose] == nil then
		pose = "stand"
	end
	local expression = o.expression
	if expression == nil or table.find(Face.EXPRESSIONS, expression) == nil then
		expression = pick({ "smile", "smile", "neutral", "grin", "focused" }, seed, "face")
	end
	local scale = if type(o.scale) == "number" and o.scale > 0.2 and o.scale < 5 then o.scale else 1
	return {
		name = name,
		skin = skin,
		hairStyle = style :: string,
		hairColor = hairColor,
		equipped = equipped,
		pose = pose :: string,
		expression = expression :: string,
		scale = scale,
	}
end

function NpcRig.seatHeight(scale: number?): number
	return Body.solve(Body.dims(scale), Body.POSES.sit).seatHeight
end

local function addAttachment(part: BasePart, name: string, offset: CFrame)
	local a = Instance.new("Attachment")
	a.Name = name
	a.CFrame = offset
	a.Parent = part
end

function NpcRig.build(opts: BuildOpts?): Model
	local o: BuildOpts = opts or {}
	local r = NpcRig.resolve(o)
	local anchored = o.anchored ~= false
	local dims = Body.dims(r.scale, o.dims)
	local solved = Body.solve(dims, Body.POSES[r.pose])
	local base = o.cframe or CFrame.identity
	if r.pose == "sit" then
		base = base * CFrame.new(0, -solved.seatHeight, 0)
	end

	local model = Instance.new("Model")
	model.Name = r.name
	local parts: { [string]: Part } = {}
	for _, name in PART_ORDER do
		local p = Instance.new("Part")
		p.Name = name
		p.Size = dims[name]
		p.CFrame = base * solved.cframes[name]
		p.Color = r.skin
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Anchored = anchored
		p.CanTouch = false
		if name == "HumanoidRootPart" then
			p.Transparency = 1
			p.CastShadow = false
			p.CanCollide = anchored -- a solid block so players don't walk through displays
			p.CanQuery = false
		else
			p.CanCollide = false
			p.CanQuery = true
		end
		p.Parent = model
		parts[name] = p
	end

	for _, m in solved.motors do
		local motor = Instance.new("Motor6D")
		motor.Name = m.name
		motor.Part0 = parts[m.parent]
		motor.Part1 = parts[m.child]
		motor.C0 = m.c0
		motor.C1 = m.c1
		motor.Parent = parts[m.child]
	end

	local head = parts.Head
	local h = head.Size
	addAttachment(head, "HairAttachment", CFrame.new(0, h.Y / 2, 0))
	addAttachment(head, "HatAttachment", CFrame.new(0, h.Y / 2, 0))
	addAttachment(head, "FaceFrontAttachment", CFrame.new(0, 0, -h.Z / 2))
	addAttachment(head, "FaceCenterAttachment", CFrame.identity)

	if o.humanoid ~= false then
		local hum = Instance.new("Humanoid")
		hum.RigType = Enum.HumanoidRigType.R15
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		hum.HipHeight = solved.cframes.HumanoidRootPart.Position.Y - dims.HumanoidRootPart.Y / 2
		hum.BreakJointsOnDeath = false
		hum.Parent = model
	end

	if o.face ~= false then
		Face.build(head, {
			skin = r.skin,
			brow = if r.hairColor then r.hairColor:Lerp(Color3.new(0, 0, 0), 0.25) else nil,
			expression = r.expression,
			lashes = r.hairStyle == "long" or r.hairStyle == "bun" or r.hairStyle == "ponytail",
		})
	end

	local hairColor = r.hairColor
	if hairColor and r.hairStyle ~= "none" then
		Hair.build(head, r.hairStyle, hairColor, {
			anchored = anchored,
			parent = model,
			hatted = r.equipped.head ~= nil,
		})
	end

	Wardrobe.apply(model, r.equipped, { anchored = anchored, glint = o.glint, skin = r.skin, strict = o.strict })

	model.PrimaryPart = parts.HumanoidRootPart
	model:SetAttribute("NpcRig", true)
	model:SetAttribute("Pose", r.pose)
	model:SetAttribute("HairStyle", r.hairStyle)
	if o.preset then
		model:SetAttribute("Preset", o.preset)
	end
	if o.parent then
		model.Parent = o.parent
	end
	return model
end

-- Runtime-only (server): a real Roblox R15 character model dressed in the Career Look. The module is
-- required lazily so Rig.luau stays bake-safe.
function NpcRig.spawn(opts: BuildOpts?): Model?
	local Spawn = (require :: any)(script.Parent.Spawn)
	return Spawn.spawn(opts or {})
end

return NpcRig
