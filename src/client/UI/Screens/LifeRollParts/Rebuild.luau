--!strict
-- LifeRollParts/Rebuild: the Background Rebuild editor (client UI, careerCore; blueprint "deterministic editor").
-- One Background Rebuild credit lets the player swap their school, family or any club for another option of the
-- SAME rarity: they choose exactly, nothing is random and no rarity is gained. The server re-checks everything.
--
--   Rebuild.open(profile, api, notify) -> close()
--     profile  the player's replicated profile (built)
--     api      CareerCoreController (api:Rebuild(edits) -> ok, errKey)
--     notify   (text, kind) -> ()   toast

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config.LifeRoll)
local LifeRoll = require(Shared.Logic.LifeRoll)
local Kit = require(script.Parent.Parent.Parent:WaitForChild("Kit"))

local Rebuild = {}

local function option(kind: string, id: string): { id: string, text: string }
	local def: any = if kind == "school"
		then Config.school(id)
		elseif kind == "family" then Config.family(id)
		else Config.club(id)
	return { id = id, text = if def then def.name else id }
end

function Rebuild.open(profile: any, api: any, notify: (string, string?) -> ()): () -> ()
	local opts = LifeRoll.rebuildOptions(profile)
	local current = {
		school = if type(profile.school) == "table" then profile.school.id else "",
		family = if type(profile.family) == "table" then profile.family.id else "",
		clubs = {} :: { string },
	}
	if type(profile.clubs) == "table" then
		for i, c in profile.clubs do
			current.clubs[i] = c.id
		end
	end
	local chosen = {
		school = current.school,
		family = current.family,
		clubs = table.clone(current.clubs),
	}

	local modal = Kit.modal({ width = 480, name = "LifeRollRebuild" }, function(card: Frame, close: () -> ())
		Kit.list(card, false, 10)
		local order = 0
		local function add(child: any)
			order += 1
			local inst = if typeof(child) == "Instance" then child else child.frame
			inst.LayoutOrder = order
			inst.Parent = card
		end
		add(Kit.Heading({ text = Config.text("rebuild_title"), level = 2 }))
		add(Kit.Label({ text = Config.text("rebuild_body"), size = "sm", color = "textDim" }))

		local function picker(title: string, kind: string, ids: { string }, value: string, onChange: (string) -> ())
			add(Kit.Label({ text = title, size = "sm", font = "bodyBold" }))
			local list = {}
			for _, id in ids do
				table.insert(list, option(kind, id))
			end
			add(Kit.Dropdown({
				options = list,
				value = value,
				title = title,
				onChange = onChange,
				name = "Pick_" .. title,
			}))
		end

		if #opts.school > 1 then
			picker(Config.text("field_school"), "school", opts.school, chosen.school, function(id: string)
				chosen.school = id
			end)
		end
		if #opts.family > 1 then
			picker(Config.text("field_family"), "family", opts.family, chosen.family, function(id: string)
				chosen.family = id
			end)
		end
		for i, ids in opts.clubs do
			local list = table.clone(ids)
			if current.clubs[i] and not table.find(list, current.clubs[i]) then
				table.insert(list, 1, current.clubs[i])
			end
			if #list > 1 then
				picker(Config.text("rebuild_club", { n = i }), "club", list, current.clubs[i], function(id: string)
					chosen.clubs[i] = id
				end)
			end
		end

		local busy = false
		local apply = Kit.Button({
			text = Config.text("rebuild_apply"),
			fill = true,
			onClick = function()
				if busy then
					return
				end
				local edits: { [string]: any } = {}
				if chosen.school ~= current.school then
					edits.school = chosen.school
				end
				if chosen.family ~= current.family then
					edits.family = chosen.family
				end
				local clubEdits: { [string]: string } = {}
				local anyClub = false
				for i, id in chosen.clubs do
					if id ~= current.clubs[i] then
						clubEdits[tostring(i)] = id
						anyClub = true
					end
				end
				if anyClub then
					edits.clubs = clubEdits
				end
				if next(edits) == nil then
					notify(Config.err("no_change"), "warn")
					return
				end
				busy = true
				task.spawn(function()
					local ok, err = api:Rebuild(edits)
					busy = false
					if ok then
						close()
					else
						notify(Config.err(err), "bad")
					end
				end)
			end,
		})
		add(apply)
		add(Kit.Button({ text = Config.text("rebuild_keep"), style = "ghost", fill = true, onClick = close }))
	end)
	return modal.close
end

return Rebuild
