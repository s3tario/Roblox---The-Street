--!strict
-- Player wardrobe data (owned by `wardrobe`, docs/contracts.md §3). Replicated to the owner as key "inventory".
--   owned       { [itemId] = true }            pieces bought, granted (Life Roll, heirlooms, season, events) or
--                                              handed out as starter outfits
--   equipped    { [slot] = itemId }            the Career Look; slots top outer bottom shoes neck wrist eyes head bag
--   presets     { ["1".."5"] = { name, equipped = { [slot] = itemId } } }   saved outfits (string keys so the
--                                              DataStore never sees a sparse array)
--   wearAvatar  boolean                        true = show the player's own Roblox avatar instead of the Career Look
--   stages      { [stageId] = true }           starter outfits already granted (student, intern, analyst)

return {
	inventory = {
		owned = {},
		equipped = {},
		presets = {},
		wearAvatar = false,
		stages = {},
	},
}
