return function(t)
	t.it("lod", function()
		local m = Instance.new("Model")
		local ok, err = pcall(function() (m :: any).LevelOfDetail = Enum.ModelLevelOfDetail.StreamingMesh end)
		print("LOD", ok, err)
		local ok2, err2 = pcall(function() (m :: any).ModelStreamingMode = Enum.ModelStreamingMode.Persistent end)
		print("MSM", ok2, err2)
	end)
end
