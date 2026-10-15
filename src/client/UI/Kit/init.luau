--!strict
-- UI Kit: themed, phone-friendly component builders. Every builder returns a table whose `frame` is the
-- root GuiObject (parent it yourself) plus small methods. Components restyle automatically when the theme
-- changes (Theme.set) and never call services while being built, so they also construct under Lune.
--
--   local Kit = require(Client.UI.Kit)
--   local win = Kit.Window({ title = "Terminal", onClose = ctx.close })
--   win.frame.Parent = root
--   local buy = Kit.Button({ text = Strings.get("buy"), onClick = function() ... end })
--   buy.frame.Parent = win.content
--
-- Components
--   Layout   Panel, Card, List, Grid, Scroll, Divider, Spacer, Tile
--   Text     Label, Heading, Badge, Countdown
--   Controls Button, IconButton, Toggle, Tabs
--   Inputs   Slider, NumberInput, TextInput, Dropdown
--   Feedback Window, Confirm, Toast, ProgressBar, StatPips
--   Data     Table, LineChart, Sparkline
-- Helpers
--   Kit.tween(inst, seconds | TweenInfo, props)   instant when reduced motion is on / no TweenService
--   Kit.themed(inst, function(tokens) ... end)    apply now + on every theme change
--   Kit.connect(inst, "Activated", fn)            safe event wiring (no-op under Lune)
--   Kit.modal(opts, build)                        custom modal sheet over the modal layer
--   Kit.color(tokens, "accent" | Color3), Kit.font(tokens, "mono"), Kit.textSize(tokens, "lg")
--   Kit.TAP (44), Kit.Math (pure chart/layout math), Kit.ToastQueue (pure toast stack logic)

local Core = require(script.Core)
local KitMath = require(script.Math)
local ToastQueue = require(script.ToastQueue)
local Text = require(script.Text)
local Layout = require(script.Layout)
local Controls = require(script.Controls)
local Inputs = require(script.Inputs)
local Fields = require(script.Fields)
local Feedback = require(script.Feedback)
local Data = require(script.Data)

export type Tokens = Core.Tokens
export type ColorSpec = Core.ColorSpec
export type Insets = Core.Insets
export type Host = Core.Host
export type Button = Controls.Button
export type ButtonStyle = Controls.ButtonStyle
export type Window = Feedback.Window
export type WindowOpts = Feedback.WindowOpts
export type ConfirmOpts = Feedback.ConfirmOpts
export type Toast = Feedback.Toast
export type ToastEvent = ToastQueue.Event
export type Label = Text.Label
export type Badge = Text.Badge
export type ProgressBar = Feedback.ProgressBar
export type IconButton = Controls.IconButton
export type Panel = Layout.Panel
export type LineChart = Data.LineChart
export type Series = Data.Series
export type Column = Data.Column

local Kit = {}

Kit.TAP = Core.TAP
Kit.Theme = Core.Theme
Kit.Core = Core
Kit.Math = KitMath
Kit.ToastQueue = ToastQueue
Kit.kinds = Core.kinds
Kit.InsetsChanged = Core.InsetsChanged

-- Layout
Kit.Panel = Layout.Panel
Kit.Card = Layout.Card
Kit.List = Layout.List
Kit.Grid = Layout.Grid
Kit.Scroll = Layout.Scroll
Kit.Divider = Layout.Divider
Kit.Spacer = Layout.Spacer
Kit.Tile = Layout.Tile
Kit.clear = Layout.clearGuiChildren

-- Text
Kit.Label = Text.Label
Kit.Heading = Text.Heading
Kit.Badge = Text.Badge
Kit.Countdown = Text.Countdown

-- Controls
Kit.Button = Controls.Button
Kit.IconButton = Controls.IconButton
Kit.Toggle = Controls.Toggle
Kit.Tabs = Controls.Tabs

-- Inputs
Kit.Slider = Inputs.Slider
Kit.NumberInput = Inputs.NumberInput
Kit.TextInput = Fields.TextInput
Kit.Dropdown = Fields.Dropdown

-- Feedback
Kit.Window = Feedback.Window
Kit.Confirm = Feedback.Confirm
Kit.Toast = Feedback.Toast
Kit.ProgressBar = Feedback.ProgressBar
Kit.StatPips = Feedback.StatPips

-- Data
Kit.Table = Data.Table
Kit.LineChart = Data.LineChart
Kit.Sparkline = Data.Sparkline

-- Helpers
Kit.tween = Core.tween
Kit.themed = Core.themed
Kit.connect = Core.connect
Kit.propChanged = Core.propChanged
Kit.onDestroy = Core.onDestroy
Kit.modal = Core.openModal
Kit.color = Core.color
Kit.font = Core.font
Kit.textSize = Core.textSize
Kit.shade = Core.shade
Kit.corner = Core.corner
Kit.stroke = Core.stroke
Kit.padding = Core.padding
Kit.list = Core.list
Kit.frame = Core.frame
Kit.unscaledSize = Core.unscaledSize
Kit.everySecond = Core.everySecond

-- Host wiring (UIController).
function Kit.setHost(host: Host)
	Core.host = host
end

function Kit.setReducedMotion(on: boolean)
	Core.reducedMotion = on == true
end

function Kit.reducedMotion(): boolean
	return Core.reducedMotion
end

function Kit.setInsets(insets: Insets)
	Core.setInsets(insets)
end

function Kit.insets(): Insets
	return Core.insets
end

function Kit.sound(name: string)
	Core.sound(name)
end

return Kit
