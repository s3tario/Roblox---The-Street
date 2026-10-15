--!strict
-- Settings screen: music/sfx volume, interface size, reduced motion and the news ticker.
-- Changes apply immediately (UIController:SetSetting) and are saved by SettingsService through the
-- validated "Settings.Set" remote. Slider ranges match SettingsService.SCHEMA (tests check this).

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Strings = require(Shared.Config.Strings)
local SettingsDefaults = require(Shared.Config.DataTemplate.Settings)
local Kit = require(script.Parent.Parent:WaitForChild("Kit"))

export type Field = {
	key: string,
	kind: "slider" | "toggle",
	section: string,
	label: string, -- Strings key
	hint: string?, -- Strings key
	min: number?,
	max: number?,
	step: number?,
	live: boolean?, -- apply while dragging (false for uiScale: rescaling under the finger feeds back)
}

local Settings = { id = "Settings" }

Settings.sections = { "settings_audio", "settings_display" }

Settings.fields = {
	{
		key = "music",
		kind = "slider",
		section = "settings_audio",
		label = "music_volume",
		min = 0,
		max = 1,
		step = 0.05,
		live = true,
	},
	{
		key = "sfx",
		kind = "slider",
		section = "settings_audio",
		label = "sfx_volume",
		min = 0,
		max = 1,
		step = 0.05,
		live = true,
	},
	{
		key = "uiScale",
		kind = "slider",
		section = "settings_display",
		label = "ui_scale",
		min = 0.8,
		max = 1.2,
		step = 0.05,
		live = false,
	},
	{
		key = "reducedMotion",
		kind = "toggle",
		section = "settings_display",
		label = "reduced_motion",
		hint = "reduced_motion_hint",
	},
	{
		key = "showTicker",
		kind = "toggle",
		section = "settings_display",
		label = "show_ticker",
		hint = "show_ticker_hint",
	},
} :: { Field }

local function percent(v: number): string
	return string.format("%d%%", math.floor(v * 100 + 0.5))
end

type Control = { set: (value: any, silent: boolean?) -> () }

function Settings.open(_args: any, root: Instance, ctx: any): { close: () -> () }
	local ui = if type(ctx) == "table" then ctx.UI else nil
	local net = if type(ctx) == "table" then ctx.Net else nil
	local closeScreen = if type(ctx) == "table" and type(ctx.close) == "function" then ctx.close else nil

	local function currentSettings(): { [string]: any }
		if ui and type(ui.GetSettings) == "function" then
			local ok, s = pcall(function()
				return ui:GetSettings()
			end)
			if ok and type(s) == "table" then
				return s
			end
		end
		return table.clone(SettingsDefaults.settings)
	end

	local function apply(key: string, value: any, localOnly: boolean)
		if ui and type(ui.SetSetting) == "function" then
			ui:SetSetting(key, value, localOnly)
		elseif net and not localOnly and type(net.send) == "function" then
			net.send("Settings.Set", key, value)
		end
	end

	local values = currentSettings()

	local win = Kit.Window({
		title = Strings.get("settings"),
		size = UDim2.fromScale(1, 1),
		maxSize = Vector2.new(580, 660),
		onClose = closeScreen,
		name = "SettingsWindow",
	})
	win.frame.Parent = root

	local scroll = Kit.Scroll({ padding = 4, gap = 10 })
	scroll.frame.Parent = win.content

	local controls: { [string]: Control } = {}

	for _, section in Settings.sections do
		local heading = Kit.Label({
			text = string.upper(Strings.get(section)),
			size = "xs",
			font = "bodyBold",
			color = "accent",
			name = "Section_" .. section,
		})
		scroll.add(heading)
		local panel = Kit.Panel({ list = true, gap = 10, name = "Panel_" .. section, color = "panelAlt" })
		scroll.add(panel)
		for _, field in Settings.fields do
			if field.section == section then
				local key = field.key
				if field.kind == "slider" then
					local slider = Kit.Slider({
						label = Strings.get(field.label),
						min = field.min,
						max = field.max,
						step = field.step,
						value = tonumber(values[key]) or tonumber(SettingsDefaults.settings[key]) or 0,
						format = percent,
						name = "Setting_" .. key,
						onChange = function(v: number)
							if field.live ~= false then
								apply(key, v, true)
							end
						end,
						onCommit = function(v: number)
							apply(key, v, false)
						end,
					})
					panel.add(slider)
					controls[key] = slider :: any
				else
					local toggle = Kit.Toggle({
						label = Strings.get(field.label),
						hint = if field.hint then Strings.get(field.hint) else nil,
						value = values[key] == true,
						name = "Setting_" .. key,
						onChange = function(v: boolean)
							apply(key, v, false)
						end,
					})
					panel.add(toggle)
					controls[key] = toggle :: any
				end
			end
		end
	end

	local function refresh(s: { [string]: any })
		for key, control in controls do
			local v = s[key]
			if v ~= nil then
				control.set(v, true)
			end
		end
	end

	local reset = Kit.Button({
		text = Strings.get("settings_reset"),
		style = "secondary",
		name = "Reset",
		onClick = function()
			Kit.Confirm({
				title = Strings.get("settings_reset_title"),
				body = Strings.get("settings_reset_body"),
				confirmText = Strings.get("reset"),
				danger = true,
			}, function(confirmed: boolean)
				if not confirmed then
					return
				end
				if ui and type(ui.ResetSettings) == "function" then
					ui:ResetSettings()
				elseif net and type(net.send) == "function" then
					net.send("Settings.Reset")
				end
				refresh(currentSettings())
			end)
		end,
	})
	scroll.add(reset)

	local conn: any = nil
	if ui and type(ui.SettingsChanged) == "table" then
		conn = ui.SettingsChanged:Connect(function(s: any)
			if type(s) == "table" then
				refresh(s)
			end
		end)
	end

	return {
		close = function()
			if conn then
				conn:Disconnect()
				conn = nil
			end
			win.close()
		end,
	}
end

return Settings
