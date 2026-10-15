local Shared = game:GetService("ReplicatedStorage").Shared
local Meta = require(Shared.Config.DataTemplate.Meta)
local DataTemplate = require(Shared.Config.DataTemplate)
local DataUtil = require(Shared.Logic.DataUtil)
local Migrations = require(Shared.Logic.Migrations)

return function(t)
	t.describe("Meta template", function()
		t.it("defines the contract fields of meta", function()
			for _, field in { "schema", "createdAt", "lastSeen", "sessions", "activeSec" } do
				t.expect(type(Meta.meta[field])).toBe("number")
			end
			t.expect(Meta.meta.schema).toBe(Migrations.CURRENT_SCHEMA)
		end)
		t.it("defines the audit ring as private", function()
			t.expect(type(Meta.audit)).toBe("table")
			t.expect(Meta._private.audit).toBe(true)
		end)
	end)

	t.describe("merged DataTemplate", function()
		t.it("includes meta and audit, and marks the contract's private keys", function()
			t.expect(DataTemplate.template.meta).never(nil)
			t.expect(DataTemplate.template.audit).never(nil)
			for _, key in { "receipts", "audit", "flags", "altCareers", "_session" } do
				t.expect(DataTemplate.private[key]).toBe(true)
			end
		end)
		t.it("produces a saveable new profile with no private keys replicated", function()
			local profile = DataUtil.newProfile(DataTemplate.template, 1_800_000_000, Migrations.CURRENT_SCHEMA)
			local _, issues = DataUtil.toSaveable(profile)
			if #issues > 0 then
				error(("template is not saveable at %s: %s"):format(issues[1].path, issues[1].reason))
			end
			local public = DataUtil.filterPrivate(profile, DataTemplate.private)
			t.expect(public.audit).toBeNil()
			t.expect(public.meta).never(nil)
		end)
	end)
end
