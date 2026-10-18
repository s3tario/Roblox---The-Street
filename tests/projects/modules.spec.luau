-- Big-deal modules (contracts §9): every module ProjectService would discover (Logic/Projects, names not starting
-- with "_", not run by another service) follows the contract; perfect play scores >= 85 at every difficulty;
-- reckless and garbage play score low without errors; every stage's view payload is a valid contracts §8 payload
-- with no unfilled template text and no answer key; the state stays JSON-safe after every stage; runs are
-- deterministic; and a lost stage rebuilds identically from the saved seed.
local Shared = game:GetService("ReplicatedStorage").Shared
local Rng = require(Shared.Util.Rng)
local TableUtil = require(Shared.Util.TableUtil)
local Kinds = require(Shared.Logic.Tasks._shared.Kinds)
local Solve = require(Shared.Logic.Tasks._shared.Solve)
local ProjectsFolder = Shared.Logic.Projects
local Registry = require(ProjectsFolder._registry)

local DIFFICULTIES = { 0.25, 0.55, 0.85 }
local SEEDS = 12
local NOW = 1790812800

local function discover(): { any }
	local out = {}
	for _, child in ProjectsFolder:GetChildren() do
		local name = child.Name
		if child:IsA("ModuleScript") and string.sub(name, 1, 1) ~= "_" and not Registry.EXTERNAL[name] then
			table.insert(out, require(child))
		end
	end
	table.sort(out, function(a, b)
		return a.id < b.id
	end)
	return out
end

local MODULES = discover()

local function ctxFor(mod: any, difficulty: number): { [string]: any }
	local lo = Registry.rankRange(mod)
	return {
		level = 20 + lo * 8,
		rank = lo,
		track = mod.track,
		difficulty = difficulty,
		hints = 2,
		now = NOW,
		toleranceMult = 1,
		charismaBonus = 0,
		marketMood = 1,
		companyName = "Harrow Williams",
	}
end

-- Every string inside a payload, for template checks.
local function strings(v: any, out: { string })
	if type(v) == "string" then
		table.insert(out, v)
	elseif type(v) == "table" then
		for _, x in v do
			strings(x, out)
		end
	end
end

local SECRET_KEYS =
	{ key = true, scores = true, best = true, target = true, credit = true, valid = true, secret = true }

local function hasSecret(v: any, depth: number): boolean
	if type(v) ~= "table" or depth > 8 then
		return false
	end
	for k, x in v do
		if type(k) == "string" and SECRET_KEYS[k] then
			return true
		end
		if hasSecret(x, depth + 1) then
			return true
		end
	end
	return false
end

local function play(mod: any, seed: number, ctx: any, answer: (secret: any) -> any, check: ((any, any) -> ())?): any
	local state = mod.new(Rng.new(seed), ctx)
	local guard = 0
	while not state.done do
		guard += 1
		assert(guard <= 20, "deal never finished")
		local view = mod.view(state, ctx)
		if check then
			check(state, view)
		end
		local result
		state, result = mod.act(state, answer(state.current.secret), ctx)
		assert(result.ok, "act failed: " .. tostring(result.err))
	end
	return state
end

return function(t)
	t.describe("discovery", function()
		t.it("finds the M1 Investment Banking deals and skips helpers and external modules", function()
			local ids = {}
			for _, mod in MODULES do
				table.insert(ids, mod.id)
			end
			t.expect(table.find(ids, "ib_sellside")).toBeTruthy()
			t.expect(table.find(ids, "ipo")).toBeTruthy()
			t.expect(table.find(ids, "reentry")).toBeNil()
			t.expect(table.find(ids, "_registry")).toBeNil()
		end)
		t.it("every module passes the contract check and is listed", function()
			for _, mod in MODULES do
				local ok, err = Registry.check(mod)
				t.expect(ok).toBe(true)
				t.expect(err).toBeNil()
				t.expect(Registry.listed(mod)).toBe(true)
				t.expect(type(mod.desc)).toBe("string")
				t.expect(type(mod.version)).toBe("number")
				for _, stat in Registry.statsOf(mod) do
					t.expect(
						table.find(
							{ "knowledge", "skill", "speed", "charisma", "network", "discipline", "risk", "luck" },
							stat
						)
					).toBeTruthy()
				end
			end
		end)
	end)

	t.describe("play", function()
		t.it("perfect play scores >= 85 (and closes) at every difficulty", function()
			for _, mod in MODULES do
				for _, d in DIFFICULTIES do
					local ctx = ctxFor(mod, d)
					for seed = 1, SEEDS do
						local state = play(mod, seed, ctx, Solve.perfect)
						local score = mod.score(state)
						t.expect(score.quality).toBeGreaterThanOrEqual(85)
						t.expect(state.quality).toBe(score.quality)
						t.expect(state.outcome.closed).toBe(true)
						t.expect(score.metrics.closed).toBe(true)
					end
				end
			end
		end)
		t.it("reckless play scores low and does not close", function()
			for _, mod in MODULES do
				for _, d in DIFFICULTIES do
					local ctx = ctxFor(mod, d)
					for seed = 1, SEEDS do
						local state = play(mod, seed, ctx, function(secret)
							return Solve.degrade(secret, 99)
						end)
						t.expect(state.quality).toBeLessThanOrEqual(30)
						t.expect(state.outcome.closed).toBe(false)
					end
				end
			end
		end)
		t.it("garbage and blank answers never error and score low", function()
			local garbage = { "garbage", 42, {}, { [1] = 5, x = "y" }, { a = { b = { c = true } } } }
			for _, mod in MODULES do
				local ctx = ctxFor(mod, 0.5)
				for seed = 1, 4 do
					for _, g in garbage do
						local state = play(mod, seed, ctx, function()
							return g
						end)
						t.expect(state.done).toBe(true)
						t.expect(state.quality).toBeLessThanOrEqual(35)
					end
					local blank = play(mod, seed, ctx, function()
						return nil
					end)
					t.expect(blank.quality).toBeLessThanOrEqual(35)
				end
			end
		end)
		t.it("more mistakes never score better (on average)", function()
			for _, mod in MODULES do
				local ctx = ctxFor(mod, 0.55)
				local totals = { 0, 0, 0, 0 }
				for seed = 1, SEEDS do
					for i, k in { 0, 1, 3, 99 } do
						local state = play(mod, seed, ctx, function(secret)
							return Solve.degrade(secret, k)
						end)
						totals[i] += state.quality
					end
				end
				t.expect(totals[1]).toBeGreaterThanOrEqual(totals[2])
				t.expect(totals[2]).toBeGreaterThanOrEqual(totals[3])
				t.expect(totals[3]).toBeGreaterThan(totals[4])
			end
		end)
		t.it("Charisma lifts dialogue-heavy deals a little, never past 100", function()
			for _, mod in MODULES do
				local plain = ctxFor(mod, 0.55)
				local charming = table.clone(plain)
				charming.charismaBonus = 8
				local a, b = 0, 0
				for seed = 1, 6 do
					a += play(mod, seed, plain, function(secret)
						return Solve.degrade(secret, 2)
					end).quality
					local s = play(mod, seed, charming, function(secret)
						return Solve.degrade(secret, 2)
					end)
					t.expect(s.quality).toBeLessThanOrEqual(100)
					b += s.quality
				end
				t.expect(b).toBeGreaterThanOrEqual(a)
			end
		end)
	end)

	t.describe("views", function()
		t.it("every stage's view is a valid, fully written payload with no answer key", function()
			for _, mod in MODULES do
				for _, d in DIFFICULTIES do
					local ctx = ctxFor(mod, d)
					for seed = 1, 6 do
						local final = play(mod, seed, ctx, Solve.perfect, function(state, view)
							t.expect(view.id).toBe(mod.id)
							t.expect(view.stageCount).toBe(#mod.stages)
							t.expect(view.stageIndex).toBe(state.stageIndex)
							t.expect(view.stage.id).toBe(mod.stages[view.stageIndex].id)
							t.expect(view.done).toBe(false)
							t.expect(type(view.dealName)).toBe("string")
							t.expect(#view.stages).toBe(#mod.stages)
							local ok, err = Kinds.validate(view.payload)
							if not ok then
								error(mod.id .. " stage " .. view.stage.id .. ": " .. tostring(err))
							end
							t.expect(view.payload.kind).toBe(mod.stages[view.stageIndex].kind)
							t.expect(hasSecret(view.payload, 1)).toBe(false)
							t.expect(Kinds.answerTotal(view.payload)).toBeGreaterThan(0)
							t.expect(type(view.summary.text)).toBe("string")
							t.expect(#view.summary.metrics).toBeGreaterThan(0)
							local all: { string } = {}
							strings(view.payload, all)
							strings(view.summary, all)
							table.insert(all, view.dealName)
							for _, s in all do
								if string.find(s, "{[%w_]+}") then
									error(mod.id .. ": unfilled template text: " .. s)
								end
							end
							-- the view is a copy: editing it never touches the saved state
							view.payload.title = "changed"
							t.expect(state.current.payload.title).never("changed")
						end)
						local done = mod.view(final, ctx)
						t.expect(done.done).toBe(true)
						t.expect(done.payload).toBeNil()
						t.expect(done.outcome).toBeTruthy()
						t.expect(type(done.outcome.headline)).toBe("string")
						t.expect(#done.outcome.figures).toBeGreaterThan(0)
						for _, entry in done.stages do
							t.expect(entry.status).toBe("done")
							t.expect(type(entry.score)).toBe("number")
						end
						local all: { string } = {}
						strings(done.outcome, all)
						for _, s in all do
							if string.find(s, "{[%w_]+}") then
								error(mod.id .. ": unfilled outcome text: " .. s)
							end
						end
					end
				end
			end
		end)
		t.it("hints follow ctx.hints (Knowledge)", function()
			for _, mod in MODULES do
				local none = ctxFor(mod, 0.5)
				none.hints = 0
				local three = ctxFor(mod, 0.5)
				three.hints = 3
				local a = mod.view(mod.new(Rng.new(3), none), none)
				local b = mod.view(mod.new(Rng.new(3), three), three)
				t.expect(a.payload.hints).toBeNil()
				t.expect(#b.payload.hints).toBe(3)
			end
		end)
	end)

	t.describe("state", function()
		t.it("is JSON-safe (DataStore) after every stage and at the end", function()
			for _, mod in MODULES do
				local ctx = ctxFor(mod, 0.85)
				for seed = 1, 6 do
					local final = play(mod, seed, ctx, function(secret)
						return Solve.degrade(secret, 1)
					end, function(state)
						local ok, err = Registry.plain(state)
						if not ok then
							error(mod.id .. ": " .. tostring(err))
						end
					end)
					local ok, err = Registry.plain(final)
					t.expect(err).toBeNil()
					t.expect(ok).toBe(true)
					t.expect(final.version).toBe(mod.version)
					t.expect(final.current).toBeNil()
				end
			end
		end)
		t.it("is deterministic: same seed and ctx, same deal", function()
			for _, mod in MODULES do
				local ctx = ctxFor(mod, 0.55)
				local a = mod.new(Rng.new(77), ctx)
				local b = mod.new(Rng.new(77), ctx)
				t.expect(TableUtil.deepEqual(a, b)).toBe(true)
				local fa = play(mod, 77, ctx, function(secret)
					return Solve.degrade(secret, 1)
				end)
				local fb = play(mod, 77, ctx, function(secret)
					return Solve.degrade(secret, 1)
				end)
				t.expect(fa.quality).toBe(fb.quality)
				t.expect(fa.dealName).toBe(fb.dealName)
				t.expect(TableUtil.deepEqual(fa, fb)).toBe(true)
				local names: { [string]: boolean } = {}
				for seed = 1, 10 do
					names[mod.view(mod.new(Rng.new(seed), ctx), ctx).dealName] = true
				end
				t.expect(TableUtil.count(names)).toBeGreaterThan(3)
			end
		end)
		t.it("rebuilds a lost stage identically, even after a level-up mid-deal", function()
			for _, mod in MODULES do
				local ctx = ctxFor(mod, 0.4)
				local state = mod.new(Rng.new(9), ctx)
				state = mod.act(state, Solve.perfect(state.current.secret), ctx)
				local before = TableUtil.deepCopy(state.current)
				state.current = nil
				local promoted = table.clone(ctx)
				promoted.difficulty = 0.95
				promoted.level = 60
				local view = mod.view(state, promoted)
				t.expect(TableUtil.deepEqual(state.current, before)).toBe(true)
				t.expect(view.payload.title).toBe(before.payload.title)
			end
		end)
		t.it("refuses to act on a finished deal", function()
			for _, mod in MODULES do
				local ctx = ctxFor(mod, 0.5)
				local state = play(mod, 5, ctx, Solve.perfect)
				local q = state.quality
				local _, result = mod.act(state, {}, ctx)
				t.expect(result.ok).toBe(false)
				t.expect(result.err).toBe("done")
				t.expect(state.quality).toBe(q)
			end
		end)
		t.it("scores an unfinished deal without the outcome", function()
			for _, mod in MODULES do
				local ctx = ctxFor(mod, 0.5)
				local state = mod.new(Rng.new(4), ctx)
				t.expect(mod.score(state).quality).toBe(0)
				state = mod.act(state, Solve.perfect(state.current.secret), ctx)
				local q = mod.score(state).quality
				t.expect(q).toBeGreaterThan(0)
				t.expect(q).toBeLessThan(50)
				t.expect(mod.score(state).metrics.done).toBe(false)
			end
		end)
	end)
end
