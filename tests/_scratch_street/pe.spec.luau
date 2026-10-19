return function(t)
	t.it("pe", function()
		local p = Instance.new("Part")
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/smoke_main.dds"
		e.Rate = 6
		e.Lifetime = NumberRange.new(2, 3.5)
		e.Speed = NumberRange.new(3, 5)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 7) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
		e.Color = ColorSequence.new(Color3.new(1, 1, 1))
		e.SpreadAngle = Vector2.new(12, 12)
		e.Acceleration = Vector3.new(1, 1, 0)
		e.LightInfluence = 1
		e.Parent = p
		print("ok", e.Rate)
		local a = Instance.new("Attachment")
		a.Parent = p
		local b = Instance.new("Beam")
		print("beam ok")
		local h = Instance.new("Highlight")
		print("hl ok")
	end)
end
