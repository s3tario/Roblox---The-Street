--!strict
-- Player settings defaults (owned by `ui`). Saved in data.settings, changed through the validated
-- "Settings.Set" remote (SettingsService) and replicated with DataService:Replicate(player, "settings").
--   music, sfx    volume 0..1
--   reducedMotion turns off UI slide/scroll animations
--   showTicker    shows the HUD news ticker band
--   uiScale       interface size multiplier 0.8..1.2

return {
	settings = {
		music = 0.5,
		sfx = 0.8,
		reducedMotion = false,
		showTicker = true,
		uiScale = 1,
	},
}
