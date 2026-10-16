local Shared = game:GetService("ReplicatedStorage").Shared
local Catalog = require(Shared.Config.Catalog)
local NpcRig = require(Shared.Assets.Npc.Rig)
local Body = require(Shared.Assets.Npc.Body)
local Hair = require(Shared.Assets.Npc.Hair)
local Fit = require(Shared.Assets.Wardrobe.Fit)

local function close(a: CFrame, b: CFrame, eps: number): boolean
	if (a.Position - b.Position).Magnitude > eps then
		return false
	end
	return (a.LookVector - b.LookVector).Magnitude < eps and (a.UpVector - b.UpVector).Magnitude < eps
end

local function lowestFoot(model: Model): number
	local low = math.huge
	for _, name in { "LeftFoot", "RightFoot" } do
		local p = model:FindFirstChild(name) :: BasePart
		for _, x in { -1, 1 } do
			for _, y in { -1, 1 } do
				for _, z in { -1, 1 } do
					local c = (p.CFrame * CFrame.new(p.Size.X / 2 * x, p.Size.Y / 2 * y, p.Size.Z / 2 * z)).Position
					low = math.min(low, c.Y)
				end
			end
		end
	end
	return low
end

local function hairParts(model: Model): number
	local folder = model:FindFirstChild(Hair.FOLDER)
	if not folder then
		return 0
	end
	local n = 0
	for _, d in folder:GetChildren() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return n
end

return function(t)
	t.describe("NpcRig.build", function()
		t.it("has every R15 part, a root, a humanoid and consistent Motor6Ds", function()
			local rig = NpcRig.build({ name = "Tester", strict = true })
			t.expect(rig.Name).toBe("Tester")
			for _, name in Fit.BODY do
				local p = rig:FindFirstChild(name)
				t.expect(p ~= nil and p:IsA("BasePart")).toBeTruthy()
			end
			local root = rig:FindFirstChild("HumanoidRootPart") :: BasePart
			t.expect(rig.PrimaryPart).toBe(root)
			t.expect(root.Transparency).toBe(1)
			local hum = rig:FindFirstChildOfClass("Humanoid") :: Humanoid
			t.expect(hum ~= nil).toBeTruthy()
			t.expect(hum.RigType).toBe(Enum.HumanoidRigType.R15)
			t.expect(hum.DisplayDistanceType).toBe(Enum.HumanoidDisplayDistanceType.None)
			t.expect(hum.HipHeight).toBeCloseTo(2, 1e-3)
			local motors = 0
			for _, d in rig:GetDescendants() do
				if d:IsA("Motor6D") then
					motors += 1
					local p0, p1 = d.Part0 :: BasePart, d.Part1 :: BasePart
					t.expect(d.Parent).toBe(p1)
					if not close(p0.CFrame * d.C0, p1.CFrame * d.C1, 1e-3) then
						error("joint " .. d.Name .. " disagrees with the part positions")
					end
				end
			end
			t.expect(motors).toBe(#Body.JOINTS)
			local head = rig:FindFirstChild("Head") :: BasePart
			t.expect(head:FindFirstChild("Face") ~= nil).toBeTruthy()
			t.expect(head:FindFirstChild("HairAttachment") ~= nil).toBeTruthy()
		end)

		t.it("builds with every hair style and every pose", function()
			for _, style in NpcRig.HAIR_STYLES do
				for _, pose in NpcRig.POSES do
					local rig = NpcRig.build({
						name = style .. "_" .. pose,
						hairStyle = style,
						hairColor = "#3B2A1E",
						pose = pose,
						equipped = Catalog.presets.analyst.equipped,
						strict = true,
					})
					t.expect(rig:GetAttribute("Pose")).toBe(pose)
					t.expect(rig:GetAttribute("HairStyle")).toBe(style)
					if style == "none" then
						t.expect(hairParts(rig)).toBe(0)
					else
						t.expect(hairParts(rig)).toBeGreaterThan(0)
					end
					for _, d in rig:GetDescendants() do
						if d:IsA("Motor6D") then
							local p0, p1 = d.Part0 :: BasePart, d.Part1 :: BasePart
							if not close(p0.CFrame * d.C0, p1.CFrame * d.C1, 1e-3) then
								error(pose .. ": joint " .. d.Name .. " disagrees with the part positions")
							end
						end
					end
				end
			end
		end)

		t.it("keeps the feet on the floor point, or the thighs on the seat", function()
			local spot = CFrame.new(10, 3, -4) * CFrame.Angles(0, math.rad(90), 0)
			for _, pose in { "stand", "arms_crossed", "wave" } do
				local rig = NpcRig.build({ pose = pose, cframe = spot, strict = true })
				t.expect(lowestFoot(rig)).toBeCloseTo(3, 1e-3)
				local root = rig:FindFirstChild("HumanoidRootPart") :: BasePart
				-- facing the spot's look direction
				t.expect((root.CFrame.LookVector - spot.LookVector).Magnitude).toBeLessThan(1e-3)
			end
			local seat = CFrame.new(0, 1.8, 0)
			local sitter = NpcRig.build({ pose = "sit", cframe = seat, strict = true })
			local thigh = sitter:FindFirstChild("LeftUpperLeg") :: BasePart
			local underside = math.huge
			for _, y in { -1, 1 } do
				for _, z in { -1, 1 } do
					local c = (thigh.CFrame * CFrame.new(0, thigh.Size.Y / 2 * y, thigh.Size.Z / 2 * z)).Position
					underside = math.min(underside, c.Y)
				end
			end
			t.expect(underside).toBeCloseTo(1.8, 1e-3)
			t.expect(lowestFoot(sitter)).toBeCloseTo(1.8 - NpcRig.seatHeight(), 1e-3)
			t.expect(NpcRig.seatHeight()).toBeGreaterThan(0.5)
			t.expect(NpcRig.seatHeight(2)).toBeCloseTo(NpcRig.seatHeight() * 2, 1e-3)
		end)

		t.it("poses move the right limbs", function()
			local d = Body.dims()
			local stand = Body.solve(d, Body.POSES.stand).cframes
			local wave = Body.solve(d, Body.POSES.wave).cframes
			local crossed = Body.solve(d, Body.POSES.arms_crossed).cframes
			local sit = Body.solve(d, Body.POSES.sit).cframes
			-- the waving hand is up by the head
			t.expect(wave.RightHand.Position.Y).toBeGreaterThan(stand.UpperTorso.Position.Y + d.UpperTorso.Y / 2)
			t.expect(wave.LeftHand.Position.Y).toBeCloseTo(stand.LeftHand.Position.Y, 0.05)
			-- folded arms: hands in front of the chest, inside the shoulders
			for _, side in { "Left", "Right" } do
				local hand = crossed[side .. "Hand"].Position
				t.expect(hand.Z).toBeLessThan(-d.UpperTorso.Z / 2 + 0.2)
				t.expect(math.abs(hand.X)).toBeLessThan(math.abs(stand[side .. "Hand"].Position.X) - 0.4)
				t.expect(hand.Y).toBeGreaterThan(stand.LowerTorso.Position.Y)
			end
			-- seated: thighs horizontal and pointing forward, shins upright
			for _, side in { "Left", "Right" } do
				t.expect(math.abs(sit[side .. "UpperLeg"].UpVector.Y)).toBeLessThan(0.05)
				t.expect(sit[side .. "LowerLeg"].UpVector.Y).toBeGreaterThan(0.99)
				t.expect(sit[side .. "LowerLeg"].Position.Z).toBeLessThan(0)
			end
		end)

		t.it("dresses every NPC preset with its outfit", function()
			for preset, def in Catalog.presets do
				local rig = NpcRig.build({ preset = preset, strict = true })
				t.expect(rig:GetAttribute("Preset")).toBe(preset)
				local folder = rig:FindFirstChild("CareerLook")
				t.expect(folder ~= nil).toBeTruthy()
				local sig = (folder :: Instance):GetAttribute("CareerLookItems")
				for slot, id in def.equipped do
					if not string.find(sig, slot .. "=" .. id, 1, true) then
						error(("preset %s is not wearing %s"):format(preset, id))
					end
				end
			end
		end)

		t.it("is deterministic and varies by name", function()
			local a = NpcRig.resolve({ name = "Passerby 1" })
			local b = NpcRig.resolve({ name = "Passerby 1" })
			t.expect(a.skin).toEqual(b.skin)
			t.expect(a.hairStyle).toBe(b.hairStyle)
			t.expect(a.expression).toBe(b.expression)
			local styles = {}
			for i = 1, 40 do
				styles[NpcRig.resolve({ name = "Passerby " .. i }).hairStyle] = true
			end
			local n = 0
			for _ in styles do
				n += 1
			end
			t.expect(n).toBeGreaterThanOrEqual(4)
			-- explicit options win over the preset
			local r = NpcRig.resolve({ preset = "md", hairStyle = "bun", skin = Color3.new(1, 0, 0), pose = "wave" })
			t.expect(r.hairStyle).toBe("bun")
			t.expect(r.skin).toEqual(Color3.new(1, 0, 0))
			t.expect(r.pose).toBe("wave")
			t.expect(r.equipped.wrist).toBe("watch_astra_moonphase")
			-- junk options fall back safely
			local j = NpcRig.resolve({ hairStyle = "mohawk", pose = "dab", skin = "red", scale = -3 } :: any)
			t.expect(Hair.isStyle(j.hairStyle)).toBeTruthy()
			t.expect(j.pose).toBe("stand")
			t.expect(j.scale).toBe(1)
		end)

		t.it("drops crown hair under hats and supports welded (unanchored) rigs", function()
			local bare = NpcRig.build({ hairStyle = "curly", hairColor = "#1C1712", strict = true })
			local hatted = NpcRig.build({
				hairStyle = "curly",
				hairColor = "#1C1712",
				equipped = { head = "beanie_charcoal" },
				strict = true,
			})
			t.expect(hairParts(hatted)).toBeLessThan(hairParts(bare))
			local loose = NpcRig.build({ anchored = false, preset = "trader", strict = true })
			for _, d in loose:GetDescendants() do
				if d:IsA("BasePart") then
					t.expect(d.Anchored).toBeFalsy()
				end
			end
			local hairFolder = loose:FindFirstChild(Hair.FOLDER) :: Instance
			for _, p in hairFolder:GetChildren() do
				local w = p:FindFirstChildOfClass("WeldConstraint")
				t.expect(w ~= nil).toBeTruthy()
				t.expect((w :: WeldConstraint).Part0).toBe(loose:FindFirstChild("Head"))
			end
		end)

		t.it("parents to opts.parent and can skip the face and humanoid", function()
			local folder = Instance.new("Folder")
			local rig = NpcRig.build({ parent = folder, face = false, humanoid = false, preset = "mannequin" })
			t.expect(rig.Parent).toBe(folder)
			t.expect((rig:FindFirstChild("Head") :: Instance):FindFirstChild("Face")).toBeNil()
			t.expect(rig:FindFirstChildOfClass("Humanoid")).toBeNil()
			t.expect(rig:FindFirstChild(Hair.FOLDER)).toBeNil() -- the mannequin is bald with no hair colour
		end)
	end)
end
