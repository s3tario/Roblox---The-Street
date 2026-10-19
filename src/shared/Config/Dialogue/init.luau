--!strict
-- Dialogue trees (owned by `tutorial`): one conversation per NPC (Config/Npcs `dialogue`), run server-side by
-- DialogueService with the rules in Logic/Dialogue. Each child module returns { [treeId] = Tree }; this index
-- merges them. Pure data: safe on the server, the client and under Lune.
--
--   Dialogue.trees[id] -> Tree     Dialogue.get(id) -> Tree?     Dialogue.ids() -> { string } (sorted)
--
-- Writing trees: every node needs at least one unconditional option, every option either goes `to` a node or exits,
-- and every reachable node must still be able to reach an exit (tests/tutorial enforce all of it). Placeholders:
-- Logic/Dialogue.VARS. Actions and conditions: Logic/Dialogue header.

local Campus = require(script.Campus)
local CareerCenter = require(script.CareerCenter)
local Lecture = require(script.Lecture)
local Street = require(script.Street)
local Venues = require(script.Venues)
local Galleria = require(script.Galleria)
local Office = require(script.Office)

local Dialogue = {}

Dialogue.trees = {} :: { [string]: any }

for _, group in { Campus, CareerCenter, Lecture, Street, Venues, Galleria, Office } :: { any } do
	for id, tree in group :: { [string]: any } do
		assert(Dialogue.trees[id] == nil, "Dialogue: duplicate tree " .. id)
		tree.id = id
		Dialogue.trees[id] = tree
	end
end

function Dialogue.get(id: any): any
	if type(id) ~= "string" then
		return nil
	end
	return Dialogue.trees[id]
end

function Dialogue.ids(): { string }
	local out: { string } = {}
	for id in Dialogue.trees do
		table.insert(out, id)
	end
	table.sort(out)
	return out
end

return Dialogue
