--!strict
-- Body: proportions, skeleton and static poses for the blocky R15 NPC rig (pure CFrame math, bake-safe).
--
--   Body.dims(scale?, overrides?) -> Dims          part sizes (standard R15 names + HumanoidRootPart)
--   Body.rest(dims) -> { [part] = CFrame }         rest pose, origin = floor point under the hips, facing -Z
--   Body.solve(dims, pose) -> Solved               posed CFrames and Motor6D C0/C1 for every joint, grounded
--   Body.JOINTS                                    { name, parent, child } in parent-first order
--   Body.POSES                                     stand, sit, arms_crossed, wave
--
-- Joint math: every joint has a rest pivot P (in rig space). C0 = rest(parent)^-1 * P and
-- C1 = rest(child)^-1 * P, so rest(parent) * C0 == rest(child) * C1. A pose rotates the joint by R:
-- posed(child) = posed(parent) * C0 * R * C1^-1, and the baked Motor6D gets C0' = C0 * R so the anchored
-- parts and their joints agree.

local Body = {}

export type Dims = { [string]: Vector3 }
export type Pose = { [string]: CFrame }
export type Solved = {
	cframes: { [string]: CFrame },
	motors: { { name: string, parent: string, child: string, c0: CFrame, c1: CFrame } },
	seatHeight: number, -- floor to the underside of the thighs (meaningful for "sit")
	height: number, -- floor to the top of the head
}

local rad = math.rad

-- Standard blocky R15 proportions at scale 1 (5.2 studs tall; arms and legs are 2 studs, like R6).
Body.BASE = {
	Head = Vector3.new(1.2, 1.2, 1.2),
	UpperTorso = Vector3.new(2, 1.6, 1),
	LowerTorso = Vector3.new(2, 0.4, 1),
	UpperArm = Vector3.new(1, 1.0, 1),
	LowerArm = Vector3.new(1, 0.75, 1),
	Hand = Vector3.new(1, 0.25, 1),
	UpperLeg = Vector3.new(1, 1.0, 1),
	LowerLeg = Vector3.new(1, 0.75, 1),
	Foot = Vector3.new(1, 0.25, 1),
	HumanoidRootPart = Vector3.new(2, 2, 1),
}

local LIMBS = { "UpperArm", "LowerArm", "Hand", "UpperLeg", "LowerLeg", "Foot" }

-- Part sizes for a rig. overrides may use generic limb names ("UpperArm") or full names ("LeftUpperArm").
function Body.dims(scale: number?, overrides: { [string]: Vector3 }?): Dims
	local k = if type(scale) == "number" and scale > 0 then scale else 1
	local out: Dims = {}
	local function get(name: string, generic: string?): Vector3
		local o = overrides
		if o then
			if o[name] then
				return o[name]
			end
			if generic and o[generic] then
				return o[generic]
			end
		end
		return (Body.BASE :: any)[generic or name] * k
	end
	out.Head = get("Head")
	out.UpperTorso = get("UpperTorso")
	out.LowerTorso = get("LowerTorso")
	out.HumanoidRootPart = get("HumanoidRootPart")
	for _, side in { "Left", "Right" } do
		for _, limb in LIMBS do
			out[side .. limb] = get(side .. limb, limb)
		end
	end
	return out
end

Body.JOINTS = {
	{ name = "Root", parent = "HumanoidRootPart", child = "LowerTorso" },
	{ name = "Waist", parent = "LowerTorso", child = "UpperTorso" },
	{ name = "Neck", parent = "UpperTorso", child = "Head" },
	{ name = "LeftShoulder", parent = "UpperTorso", child = "LeftUpperArm" },
	{ name = "LeftElbow", parent = "LeftUpperArm", child = "LeftLowerArm" },
	{ name = "LeftWrist", parent = "LeftLowerArm", child = "LeftHand" },
	{ name = "RightShoulder", parent = "UpperTorso", child = "RightUpperArm" },
	{ name = "RightElbow", parent = "RightUpperArm", child = "RightLowerArm" },
	{ name = "RightWrist", parent = "RightLowerArm", child = "RightHand" },
	{ name = "LeftHip", parent = "LowerTorso", child = "LeftUpperLeg" },
	{ name = "LeftKnee", parent = "LeftUpperLeg", child = "LeftLowerLeg" },
	{ name = "LeftAnkle", parent = "LeftLowerLeg", child = "LeftFoot" },
	{ name = "RightHip", parent = "LowerTorso", child = "RightUpperLeg" },
	{ name = "RightKnee", parent = "RightUpperLeg", child = "RightLowerLeg" },
	{ name = "RightAnkle", parent = "RightLowerLeg", child = "RightFoot" },
}

type Layout = { cframes: { [string]: CFrame }, pivots: { [string]: Vector3 } }

-- Rest positions and joint pivots (rig space: origin on the floor under the hips, -Z = front).
local function layout(d: Dims): Layout
	local cf: { [string]: CFrame } = {}
	local pv: { [string]: Vector3 } = {}
	local ut, lt, head = d.UpperTorso, d.LowerTorso, d.Head
	local hipY = 0
	for _, side in { "Left", "Right" } do
		hipY = math.max(hipY, d[side .. "UpperLeg"].Y + d[side .. "LowerLeg"].Y + d[side .. "Foot"].Y)
	end
	local waistY = hipY + lt.Y
	local shoulderTop = waistY + ut.Y
	cf.LowerTorso = CFrame.new(0, hipY + lt.Y / 2, 0)
	cf.UpperTorso = CFrame.new(0, waistY + ut.Y / 2, 0)
	cf.Head = CFrame.new(0, shoulderTop + head.Y / 2, 0)
	local root = d.HumanoidRootPart
	cf.HumanoidRootPart = CFrame.new(0, hipY + root.Y / 2, 0)
	pv.Root = Vector3.new(0, hipY + lt.Y / 2, 0)
	pv.Waist = Vector3.new(0, waistY, 0)
	pv.Neck = Vector3.new(0, shoulderTop, 0)
	for i, side in { "Left", "Right" } do
		local sx = if i == 1 then -1 else 1
		local ua, la, hand = d[side .. "UpperArm"], d[side .. "LowerArm"], d[side .. "Hand"]
		local ax = sx * (ut.X / 2 + ua.X / 2)
		cf[side .. "UpperArm"] = CFrame.new(ax, shoulderTop - ua.Y / 2, 0)
		cf[side .. "LowerArm"] = CFrame.new(ax, shoulderTop - ua.Y - la.Y / 2, 0)
		cf[side .. "Hand"] = CFrame.new(ax, shoulderTop - ua.Y - la.Y - hand.Y / 2, 0)
		-- shoulder pivot inside the top of the arm; elbow and wrist pivots on their joint lines
		pv[side .. "Shoulder"] = Vector3.new(ax, shoulderTop - math.min(ua.X, ua.Y) * 0.4, 0)
		pv[side .. "Elbow"] = Vector3.new(ax, shoulderTop - ua.Y, 0)
		pv[side .. "Wrist"] = Vector3.new(ax, shoulderTop - ua.Y - la.Y, 0)
		local ul, ll, foot = d[side .. "UpperLeg"], d[side .. "LowerLeg"], d[side .. "Foot"]
		local lx = sx * (lt.X / 4)
		local base = hipY - ul.Y - ll.Y - foot.Y
		cf[side .. "UpperLeg"] = CFrame.new(lx, hipY - ul.Y / 2, 0)
		cf[side .. "LowerLeg"] = CFrame.new(lx, base + foot.Y + ll.Y / 2, 0)
		cf[side .. "Foot"] = CFrame.new(lx, base + foot.Y / 2, 0)
		-- hip pivot below the hip line (thighs swing forward from under the pelvis); knee pivot half a
		-- shin-depth above the knee line (shins hang flush from the front of the thighs when seated)
		pv[side .. "Hip"] = Vector3.new(lx, hipY - math.min(ul.Z * 0.15, ul.Y * 0.3), 0)
		pv[side .. "Knee"] = Vector3.new(lx, hipY - ul.Y + math.min(ll.Z / 2, ul.Y / 2), 0)
		pv[side .. "Ankle"] = Vector3.new(lx, base + foot.Y, 0)
	end
	return { cframes = cf, pivots = pv }
end

function Body.rest(d: Dims): { [string]: CFrame }
	return layout(d).cframes
end

local function corners(cf: CFrame, size: Vector3): { Vector3 }
	local out = {}
	local h = size / 2
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				table.insert(out, (cf * CFrame.new(h.X * x, h.Y * y, h.Z * z)).Position)
			end
		end
	end
	return out
end

local function minY(cf: CFrame, size: Vector3): number
	local m = math.huge
	for _, p in corners(cf, size) do
		m = math.min(m, p.Y)
	end
	return m
end

local function maxY(cf: CFrame, size: Vector3): number
	local m = -math.huge
	for _, p in corners(cf, size) do
		m = math.max(m, p.Y)
	end
	return m
end

-- Poses the rig, then lifts/lowers it so the lowest foot corner rests on the floor (y = 0).
function Body.solve(d: Dims, pose: Pose?): Solved
	local L = layout(d)
	local rest, pivots = L.cframes, L.pivots
	local R = pose or {}
	local posed: { [string]: CFrame } = { HumanoidRootPart = rest.HumanoidRootPart }
	local motors = {}
	for _, j in Body.JOINTS do
		local p = CFrame.new(pivots[j.name])
		local c0 = rest[j.parent]:Inverse() * p
		local c1 = rest[j.child]:Inverse() * p
		local rot = R[j.name] or CFrame.identity
		posed[j.child] = posed[j.parent] * c0 * rot * c1:Inverse()
		table.insert(motors, { name = j.name, parent = j.parent, child = j.child, c0 = c0 * rot, c1 = c1 })
	end
	local floor = math.huge
	for _, side in { "Left", "Right" } do
		floor = math.min(floor, minY(posed[side .. "Foot"], d[side .. "Foot"]))
		floor = math.min(floor, minY(posed[side .. "LowerLeg"], d[side .. "LowerLeg"]))
	end
	local lift = CFrame.new(0, -floor, 0)
	local out: { [string]: CFrame } = {}
	for name, cf in posed do
		out[name] = lift * cf
	end
	local seat = math.huge
	for _, side in { "Left", "Right" } do
		seat = math.min(seat, minY(out[side .. "UpperLeg"], d[side .. "UpperLeg"]))
	end
	return {
		cframes = out,
		motors = motors,
		seatHeight = seat,
		height = maxY(out.Head, d.Head),
	}
end

---------------------------------------------------------------------------------------------------
-- Poses (joint rotations)
---------------------------------------------------------------------------------------------------
local function X(deg: number): CFrame
	return CFrame.Angles(rad(deg), 0, 0)
end

local function Z(deg: number): CFrame
	return CFrame.Angles(0, 0, rad(deg))
end

local function Y(deg: number): CFrame
	return CFrame.Angles(0, rad(deg), 0)
end

Body.POSES = {
	-- relaxed: arms a touch away from the body, soft elbows
	stand = {
		LeftShoulder = Z(-3),
		RightShoulder = Z(3),
		LeftElbow = X(6),
		RightElbow = X(6),
	},
	-- seated upright, hands resting beside the knees
	sit = {
		LeftHip = X(90),
		RightHip = X(90),
		LeftKnee = X(-90),
		RightKnee = X(-90),
		LeftShoulder = X(6),
		RightShoulder = X(6),
		LeftElbow = X(50),
		RightElbow = X(50),
	},
	-- forearms folded across the chest, right arm over the left. The elbow twists about the upper arm
	-- (Y) and then bends forward (X), so the forearm lies flat across the body.
	arms_crossed = {
		RightShoulder = X(26),
		RightElbow = Y(68) * X(94),
		LeftShoulder = X(17),
		LeftElbow = Y(-72) * X(92),
		RightWrist = X(-6),
		LeftWrist = X(-6),
	},
	-- right arm raised in a greeting wave, forearm upright
	wave = {
		LeftShoulder = Z(-3),
		LeftElbow = X(6),
		RightShoulder = Z(104) * X(-10),
		RightElbow = Z(62),
		RightWrist = Z(8),
	},
} :: { [string]: Pose }

Body.POSE_IDS = { "stand", "sit", "arms_crossed", "wave" }

return Body
