-- Tiny test framework for Lune specs.
-- A spec file returns function(t) ... end and uses t.describe / t.it / t.expect.

local TestKit = {}

local function fmt(v: any): string
	if type(v) == "table" then
		local parts = {}
		local n = 0
		for k, x in v do
			n += 1
			if n > 8 then
				table.insert(parts, "...")
				break
			end
			table.insert(parts, tostring(k) .. "=" .. (if type(x) == "table" then "{...}" else tostring(x)))
		end
		return "{" .. table.concat(parts, ", ") .. "}"
	end
	return tostring(v)
end

local function deepEqual(a: any, b: any): boolean
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		if type(a) == "number" and type(b) == "number" then
			return math.abs(a - b) < 1e-9
		end
		return false
	end
	for k, v in a do
		if not deepEqual(v, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end

function TestKit.expect(actual: any)
	local e = {}
	local function fail(msg: string)
		error("expectation failed: " .. msg, 3)
	end
	function e.toBe(expected: any)
		if actual ~= expected then
			fail(("expected %s to be %s"):format(fmt(actual), fmt(expected)))
		end
	end
	function e.never(expected: any)
		if actual == expected then
			fail(("expected %s not to be %s"):format(fmt(actual), fmt(expected)))
		end
	end
	function e.toEqual(expected: any)
		if not deepEqual(actual, expected) then
			fail(("expected %s to deep-equal %s"):format(fmt(actual), fmt(expected)))
		end
	end
	function e.toBeCloseTo(expected: number, eps: number?)
		if type(actual) ~= "number" or math.abs(actual - expected) > (eps or 1e-6) then
			fail(("expected %s to be within %s of %s"):format(fmt(actual), tostring(eps or 1e-6), fmt(expected)))
		end
	end
	function e.toBeTruthy()
		if not actual then
			fail(("expected %s to be truthy"):format(fmt(actual)))
		end
	end
	function e.toBeFalsy()
		if actual then
			fail(("expected %s to be falsy"):format(fmt(actual)))
		end
	end
	function e.toBeNil()
		if actual ~= nil then
			fail(("expected %s to be nil"):format(fmt(actual)))
		end
	end
	function e.toBeGreaterThan(x: number)
		if not (type(actual) == "number" and actual > x) then
			fail(("expected %s > %s"):format(fmt(actual), fmt(x)))
		end
	end
	function e.toBeGreaterThanOrEqual(x: number)
		if not (type(actual) == "number" and actual >= x) then
			fail(("expected %s >= %s"):format(fmt(actual), fmt(x)))
		end
	end
	function e.toBeLessThan(x: number)
		if not (type(actual) == "number" and actual < x) then
			fail(("expected %s < %s"):format(fmt(actual), fmt(x)))
		end
	end
	function e.toBeLessThanOrEqual(x: number)
		if not (type(actual) == "number" and actual <= x) then
			fail(("expected %s <= %s"):format(fmt(actual), fmt(x)))
		end
	end
	function e.toBeBetween(lo: number, hi: number)
		if not (type(actual) == "number" and actual >= lo and actual <= hi) then
			fail(("expected %s to be in [%s, %s]"):format(fmt(actual), fmt(lo), fmt(hi)))
		end
	end
	function e.toBeType(typeName: string)
		if typeof(actual) ~= typeName then
			fail(("expected type %s, got %s"):format(typeName, typeof(actual)))
		end
	end
	function e.toContain(x: any)
		if type(actual) == "string" then
			if not string.find(actual, x, 1, true) then
				fail(("expected '%s' to contain '%s'"):format(actual, tostring(x)))
			end
			return
		end
		for _, v in actual do
			if deepEqual(v, x) then
				return
			end
		end
		fail(("expected %s to contain %s"):format(fmt(actual), fmt(x)))
	end
	function e.toThrow(pattern: string?)
		local ok, err = pcall(actual)
		if ok then
			fail("expected function to throw")
		end
		if pattern and not string.find(tostring(err), pattern) then
			fail(("expected error matching '%s', got '%s'"):format(pattern, tostring(err)))
		end
	end
	function e.toHaveLength(n: number)
		if #actual ~= n then
			fail(("expected length %d, got %d"):format(n, #actual))
		end
	end
	return e
end

export type Result = { name: string, ok: boolean, err: string? }

function TestKit.run(specFn: (any) -> (), fileName: string): { Result }
	local results: { Result } = {}
	local stack: { string } = {}
	local t = {}
	t.expect = TestKit.expect
	function t.describe(name: string, fn: () -> ())
		table.insert(stack, name)
		local ok, err = pcall(fn)
		if not ok then
			table.insert(
				results,
				{ name = table.concat(stack, " > ") .. " (describe body)", ok = false, err = tostring(err) }
			)
		end
		table.remove(stack)
	end
	function t.it(name: string, fn: () -> ())
		local full = table.concat(stack, " > ") .. (if #stack > 0 then " > " else "") .. name
		local ok, err = xpcall(fn, function(m)
			return debug.traceback(tostring(m), 2)
		end)
		table.insert(results, { name = full, ok = ok, err = if ok then nil else tostring(err) })
	end
	t.test = t.it
	local ok, err = pcall(specFn, t)
	if not ok then
		table.insert(results, { name = fileName .. " (spec body)", ok = false, err = tostring(err) })
	end
	return results
end

return TestKit
