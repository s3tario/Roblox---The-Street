local Client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
local Theme = require(Client.UI.Theme)
local Kit = require(Client.UI.Kit)

local function isGui(x: any): boolean
	return typeof(x) == "Instance" and x:IsA("GuiObject")
end

local function minHeight(gui: any): number
	local h = gui.Size.Y.Offset
	for _, c in gui:GetChildren() do
		if c:IsA("UISizeConstraint") then
			h = math.max(h, c.MinSize.Y)
		end
	end
	return h
end

-- Every component with arguments that exercise its main options; each entry returns the built table.
local builders: { [string]: () -> any } = {
	Panel = function()
		return Kit.Panel({ list = true })
	end,
	Card = function()
		return Kit.Card({ title = "Title", subtitle = "Sub", onClick = function() end })
	end,
	List = function()
		local l = Kit.List({ direction = "horizontal", gap = 4 })
		l.add(Kit.Label({ text = "a" }))
		return l
	end,
	Grid = function()
		return Kit.Grid({ columns = 3, cellHeight = 100 })
	end,
	Scroll = function()
		local s = Kit.Scroll({})
		s.add(Kit.Label({ text = "row" }))
		return s
	end,
	Divider = function()
		return Kit.Divider({ vertical = true })
	end,
	Spacer = function()
		return Kit.Spacer(12)
	end,
	Tile = function()
		return Kit.Tile({ glyph = "$", title = "Bank", badge = "2" })
	end,
	Label = function()
		return Kit.Label({ text = "Hello", size = "lg", color = "accent", align = "center" })
	end,
	Heading = function()
		return Kit.Heading({ text = "Heading", level = 1 })
	end,
	Badge = function()
		return Kit.Badge({ text = "NEW", color = "good" })
	end,
	Countdown = function()
		return Kit.Countdown({
			seconds = 65,
			prefix = "Ends in",
			now = function()
				return 1000
			end,
		})
	end,
	Button = function()
		return Kit.Button({ text = "Buy", style = "primary", icon = "$", onClick = function() end })
	end,
	IconButton = function()
		return Kit.IconButton({ glyph = "✕" })
	end,
	Toggle = function()
		return Kit.Toggle({ value = true, label = "Sound", hint = "hint" })
	end,
	Tabs = function()
		return Kit.Tabs({ tabs = { { id = "a", title = "A" }, { id = "b", title = "B", badge = "3" } } })
	end,
	Slider = function()
		return Kit.Slider({ min = 0, max = 1, step = 0.05, value = 0.5, label = "Volume" })
	end,
	NumberInput = function()
		return Kit.NumberInput({ value = 10, min = 0, max = 100, step = 5 })
	end,
	TextInput = function()
		return Kit.TextInput({ placeholder = "Search", maxLength = 20 })
	end,
	Dropdown = function()
		return Kit.Dropdown({ options = { "One", { id = "two", text = "Two" } }, value = "two" })
	end,
	Window = function()
		return Kit.Window({ title = "Terminal", subtitle = "Markets", onClose = function() end })
	end,
	Confirm = function()
		return Kit.Confirm({ title = "Sure?", body = "Body", danger = true }, function() end)
	end,
	Toast = function()
		return Kit.Toast({ text = "+$450", kind = "cash", count = 3 })
	end,
	ProgressBar = function()
		return Kit.ProgressBar({ value = 0.4, label = "40%", height = 18 })
	end,
	StatPips = function()
		return Kit.StatPips({ value = 7 })
	end,
	Table = function()
		return Kit.Table({
			columns = { { key = "t", title = "Ticker" }, { key = "p", title = "Price", align = "right", width = 90 } },
			rows = { { t = "APX", p = 101.5 }, { t = "NMB", p = 22 } },
		})
	end,
	LineChart = function()
		return Kit.LineChart({ series = { { points = { 1, 3, 2, 5 } } }, baseline = 2 })
	end,
	Sparkline = function()
		return Kit.Sparkline({ points = { 5, 4, 6, 3 } })
	end,
}

return function(t)
	for _, themeName in Theme.names do
		t.describe("Kit under " .. themeName, function()
			Theme.set(themeName)
			for name, build in builders do
				t.it(name .. " constructs and returns a frame", function()
					local built = build()
					t.expect(type(built)).toBe("table")
					t.expect(typeof(built.frame)).toBe("Instance")
					t.expect(built.frame:IsA("GuiObject")).toBeTruthy()
				end)
			end
		end)
	end

	t.describe("Kit shapes", function()
		t.it("Window returns frame, content, setTitle and close", function()
			local w = Kit.Window({ title = "A", onClose = function() end })
			t.expect(isGui(w.content)).toBeTruthy()
			t.expect(isGui(w.panel)).toBeTruthy()
			w.setTitle("B")
			t.expect(type(w.close)).toBe("function")
		end)
		t.it("buttons are at least 44 px tall", function()
			t.expect(minHeight(Kit.Button({ text = "x" }).frame)).toBeGreaterThanOrEqual(44)
			t.expect(minHeight(Kit.Button({ text = "x", size = UDim2.fromOffset(80, 20) }).frame))
				.toBeGreaterThanOrEqual(44)
			t.expect(minHeight(Kit.IconButton({ glyph = "+" }).frame)).toBeGreaterThanOrEqual(44)
			t.expect(minHeight(Kit.Toggle({}).frame)).toBeGreaterThanOrEqual(44)
			t.expect(minHeight(Kit.Dropdown({}).frame)).toBeGreaterThanOrEqual(44)
		end)
		t.it("Button disabled state and styles", function()
			local b = Kit.Button({ text = "Go", disabled = true })
			t.expect(b.isDisabled()).toBe(true)
			b.setDisabled(false)
			t.expect(b.isDisabled()).toBe(false)
			for _, style in { "primary", "secondary", "ghost", "danger" } do
				b.setStyle(style :: any)
			end
			b.setText("Again")
			t.expect(b.label.Text).toBe("Again")
		end)
		t.it("Toggle, Slider and NumberInput set/get", function()
			local tg = Kit.Toggle({ value = false })
			tg.set(true)
			t.expect(tg.get()).toBe(true)
			local changed = nil
			local s = Kit.Slider({
				min = 0.8,
				max = 1.2,
				step = 0.05,
				value = 1,
				onChange = function(v)
					changed = v
				end,
			})
			s.set(1.13)
			t.expect(s.get()).toBeCloseTo(1.15, 1e-6)
			t.expect(changed).toBeCloseTo(1.15, 1e-6)
			s.set(5)
			t.expect(s.get()).toBeCloseTo(1.2, 1e-6)
			local n = Kit.NumberInput({ value = 3, min = 0, max = 10, step = 2 })
			t.expect(n.get()).toBe(4)
			n.set(99)
			t.expect(n.get()).toBe(10)
		end)
		t.it("Tabs select and Dropdown set", function()
			local picked = nil
			local tabs = Kit.Tabs({
				tabs = { { id = "a", title = "A" }, { id = "b", title = "B" } },
				onSelect = function(id)
					picked = id
				end,
			})
			t.expect(tabs.getSelected()).toBe("a")
			tabs.select("b")
			t.expect(picked).toBe("b")
			local d = Kit.Dropdown({ options = { "x", "y" } })
			t.expect(d.get()).toBeNil()
			d.set("y")
			t.expect(d.get()).toBe("y")
		end)
		t.it("ProgressBar and StatPips clamp", function()
			local p = Kit.ProgressBar({ value = 2 })
			t.expect(p.get()).toBe(1)
			p.set(-1, true)
			t.expect(p.get()).toBe(0)
			local pips = Kit.StatPips({ value = 12 })
			t.expect(pips.get()).toBe(10)
			pips.set(3.4)
			t.expect(pips.get()).toBe(3)
		end)
		t.it("Table renders a row per entry and handles setRows", function()
			local tbl = Kit.Table({ columns = { { key = "a", title = "A" } }, rows = { { a = 1 }, { a = 2 } } })
			local count = 0
			for _, c in tbl.body:GetChildren() do
				if c.Name:sub(1, 3) == "Row" then
					count += 1
				end
			end
			t.expect(count).toBe(2)
			tbl.setRows({})
			count = 0
			for _, c in tbl.body:GetChildren() do
				if c.Name:sub(1, 3) == "Row" then
					count += 1
				end
			end
			t.expect(count).toBe(0)
		end)
		t.it("LineChart handles 2..240 points and more", function()
			local chart = Kit.LineChart({ width = 300, height = 150 })
			chart.set({ { points = { 1, 2 } } })
			t.expect(chart.segmentCount()).toBe(1)
			local many = {}
			for i = 1, 240 do
				many[i] = math.sin(i / 10) * 10 + 50
			end
			chart.set({ { points = many }, { points = { 40, 60 }, color = "bad" } })
			t.expect(chart.segmentCount()).toBe(239 + 1)
			local lots = {}
			for i = 1, 1000 do
				lots[i] = i
			end
			chart.set({ { points = lots } })
			t.expect(chart.segmentCount()).toBeLessThanOrEqual(239)
			chart.set({ { points = {} } })
			t.expect(chart.segmentCount()).toBe(0)
			local lo, hi = chart.bounds()
			t.expect(hi > lo).toBeTruthy()
		end)
		t.it("Countdown formats remaining time", function()
			local now = 1000
			local c = Kit.Countdown({
				endsAt = 1065,
				now = function()
					return now
				end,
			})
			t.expect(c.frame.Text).toBe("1:05")
			t.expect(c.remaining()).toBe(65)
			c.set(nil)
			t.expect(c.frame.Text).toBe("--:--")
		end)
		t.it("Confirm calls back exactly once", function()
			local calls = 0
			local result = nil
			local m = Kit.Confirm({ title = "x" }, function(v)
				calls += 1
				result = v
			end)
			m.close(true)
			m.close(false)
			t.expect(calls).toBe(1)
			t.expect(result).toBe(true)
		end)
	end)

	t.describe("Kit theming", function()
		t.it("components restyle when the theme changes", function()
			Theme.set("campus")
			local label = Kit.Label({ text = "x" })
			local panel = Kit.Panel({})
			t.expect(label.frame.TextColor3).toEqual(Theme.themes.campus.colors.text)
			Theme.set("street")
			t.expect(label.frame.TextColor3).toEqual(Theme.themes.street.colors.text)
			t.expect(panel.frame.BackgroundColor3).toEqual(Theme.themes.street.colors.panel)
			t.expect(label.frame.FontFace).toEqual(Theme.themes.street.fonts.body)
			Theme.set("campus")
			t.expect(panel.frame.BackgroundColor3).toEqual(Theme.themes.campus.colors.panel)
		end)
		t.it("truncate counts characters, not bytes", function()
			t.expect(Kit.Core.truncate("héllo", 2)).toBe("hé")
			t.expect(Kit.Core.truncate("abc", 5)).toBe("abc")
			t.expect(Kit.Core.truncate("\255abc", 2)).toBe("\255a")
		end)
		t.it("tween applies instantly without TweenService", function()
			local f = Instance.new("Frame")
			local tw = Kit.tween(f, 0.3, { BackgroundTransparency = 0.5 })
			t.expect(tw).toBeNil()
			t.expect(f.BackgroundTransparency).toBeCloseTo(0.5, 1e-6)
		end)
	end)
end
