--!strict
-- Common player-facing UI strings (owned by `ui`). Every Kit component and the HUD read their text from
-- here so it can be localized later. Features keep their own copy in their own config, or add generic
-- entries here through the ui owner.
--
--   Strings.get("close")                       --> "Close"
--   Strings.get("unknown_key", "Fallback")     --> "Fallback"
--   Strings.format("hud_level", { level = 7 }) --> "Lv 7"

local Strings = {}

Strings.en = {
	-- Generic actions
	close = "Close",
	back = "Back",
	confirm = "Confirm",
	cancel = "Cancel",
	ok = "OK",
	yes = "Yes",
	no = "No",
	buy = "Buy",
	sell = "Sell",
	equip = "Equip",
	equipped = "Equipped",
	unequip = "Unequip",
	owned = "Owned",
	locked = "Locked",
	unlock = "Unlock",
	coming_soon = "Coming soon",
	free = "Free",
	price = "Price",
	select = "Select",
	selected = "Selected",
	save = "Save",
	saved = "Saved",
	reset = "Reset",
	apply = "Apply",
	done = "Done",
	next = "Next",
	previous = "Previous",
	continue = "Continue",
	start = "Start",
	submit = "Submit",
	accept = "Accept",
	decline = "Decline",
	claim = "Claim",
	claimed = "Claimed",
	retry = "Retry",
	details = "Details",
	more = "More",
	search = "Search",
	search_placeholder = "Type to search...",
	on = "On",
	off = "Off",
	loading = "Loading...",
	empty = "Nothing here yet.",
	dropdown_placeholder = "Choose...",
	text_placeholder = "Type here...",

	-- Generic feedback
	error_generic = "Something went wrong. Please try again.",
	error_timeout = "The server took too long to answer. Please try again.",
	error_screen = "That screen couldn't open. Please try again.",
	not_enough_cash = "Not enough cash.",
	requires_role = "Requires {role}.",
	unlocks_at_level = "Unlocks at level {level}.",
	count_suffix = "x{count}",

	-- Menu (phone)
	menu = "Menu",
	menu_title = "Phone",
	menu_empty = "No apps yet. Keep playing to unlock more.",
	menu_open = "Open menu",

	-- Settings
	settings = "Settings",
	settings_audio = "Audio",
	settings_display = "Display",
	music_volume = "Music volume",
	sfx_volume = "Sound effects",
	ui_scale = "Interface size",
	reduced_motion = "Reduced motion",
	reduced_motion_hint = "Turns off sliding and scrolling animations.",
	show_ticker = "News ticker",
	show_ticker_hint = "Shows the scrolling news band at the bottom of the screen.",
	settings_reset = "Reset to defaults",
	settings_reset_title = "Reset settings?",
	settings_reset_body = "Volume, interface size and motion settings go back to their defaults.",

	-- HUD
	hud_level = "Lv {level}",
	hud_xp = "{xp} / {next} XP",
	hud_xp_only = "{xp} XP",
	hud_review_in = "Review in {time}",
	hud_objective = "Objective",
	ticker_campus = "CAMPUS WIRE",
	ticker_street = "STREET WIRE",
	role_student = "College Student",

	-- Career status chips
	status_active = "On track",
	status_review_due = "Review due",
	status_coaching = "Coaching",
	status_probation = "Probation",
	status_fired = "Between jobs",
	status_student = "Student",
}

local current: { [string]: string } = Strings.en

-- Text for `key`; the fallback (or the key itself) when the key is unknown.
function Strings.get(key: string, fallback: string?): string
	local s = current[key]
	if s ~= nil then
		return s
	end
	local base = Strings.en[key]
	if base ~= nil then
		return base
	end
	return fallback or key
end

-- Like get(), then replaces {name} placeholders with tostring(vars.name). Unknown placeholders stay.
function Strings.format(key: string, vars: { [string]: any }?, fallback: string?): string
	local s = Strings.get(key, fallback)
	if vars == nil then
		return s
	end
	local v = vars
	return (
		string.gsub(s, "{([%w_]+)}", function(name: string): string
			local value = v[name]
			if value == nil then
				return "{" .. name .. "}"
			end
			return tostring(value)
		end)
	)
end

-- Fills {name} placeholders in an arbitrary template string (for feature-owned text).
function Strings.fill(template: string, vars: { [string]: any }): string
	return (
		string.gsub(template, "{([%w_]+)}", function(name: string): string
			local value = vars[name]
			if value == nil then
				return "{" .. name .. "}"
			end
			return tostring(value)
		end)
	)
end

-- Switch the active table (localization hook). Missing keys fall back to English.
function Strings.setLanguage(tableOrNil: { [string]: string }?)
	current = tableOrNil or Strings.en
end

function Strings.has(key: string): boolean
	return current[key] ~= nil or Strings.en[key] ~= nil
end

return Strings
