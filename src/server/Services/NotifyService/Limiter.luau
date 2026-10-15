--!strict
-- Pure per-recipient notification limiter (no services, no clocks: callers pass `now`).
--   * at most `max` sends per sliding `window` seconds
--   * an identical key sent less than `dupWindow` seconds ago is held and coalesced: repeats bump a
--     counter and go out once, as "text x N", when the duplicate window ends
--   * over-budget items wait in a bounded pending queue (identical pending items coalesce); when the
--     queue is full the oldest pending item is dropped
-- Used by NotifyService for toasts, banners and the global ticker.

local Limiter = {}

export type Entry = { key: string, payload: any, count: number, notBefore: number }
export type Config = { max: number?, window: number?, dupWindow: number?, maxPending: number? }
export type State = {
	max: number,
	window: number,
	dupWindow: number,
	maxPending: number,
	sent: { number }, -- send times inside the window (oldest first)
	lastSent: { [string]: number },
	pending: { Entry },
	dropped: number,
}

function Limiter.new(config: Config?): State
	local c: Config = config or {}
	return {
		max = c.max or 6,
		window = c.window or 2,
		dupWindow = c.dupWindow or 2,
		maxPending = c.maxPending or 6,
		sent = {},
		lastSent = {},
		pending = {},
		dropped = 0,
	}
end

local function prune(state: State, now: number)
	local sent = state.sent
	local cutoff = now - state.window
	local drop = 0
	for i = 1, #sent do
		if sent[i] <= cutoff then
			drop = i
		else
			break
		end
	end
	if drop > 0 then
		for _ = 1, drop do
			table.remove(sent, 1)
		end
	end
	-- Forget old duplicate stamps so the table can't grow without bound.
	for key, at in state.lastSent do
		if now - at >= math.max(state.dupWindow, state.window) then
			state.lastSent[key] = nil
		end
	end
end

local function record(state: State, key: string, now: number)
	table.insert(state.sent, now)
	state.lastSent[key] = now
end

local function enqueue(state: State, entry: Entry)
	table.insert(state.pending, entry)
	while #state.pending > state.maxPending do
		table.remove(state.pending, 1)
		state.dropped += 1
	end
end

-- Offers one item. Returns the entries to send right now (0 or 1).
function Limiter.offer(state: State, key: string, payload: any, now: number): { Entry }
	prune(state, now)
	for _, p in state.pending do
		if p.key == key then
			p.count += 1
			p.payload = payload
			return {}
		end
	end
	local last = state.lastSent[key]
	if last ~= nil and now - last < state.dupWindow then
		enqueue(state, { key = key, payload = payload, count = 1, notBefore = last + state.dupWindow })
		return {}
	end
	if #state.sent < state.max then
		record(state, key, now)
		return { { key = key, payload = payload, count = 1, notBefore = now } }
	end
	enqueue(state, { key = key, payload = payload, count = 1, notBefore = now })
	return {}
end

-- Releases pending entries whose time has come, within the send budget.
function Limiter.drain(state: State, now: number): { Entry }
	prune(state, now)
	local out: { Entry } = {}
	local i = 1
	while i <= #state.pending and #state.sent < state.max do
		local p = state.pending[i]
		if p.notBefore <= now then
			table.remove(state.pending, i)
			record(state, p.key, now)
			table.insert(out, p)
		else
			i += 1
		end
	end
	return out
end

function Limiter.pendingCount(state: State): number
	return #state.pending
end

-- True when nothing is pending and no send is inside the window (state may be discarded).
function Limiter.idle(state: State, now: number): boolean
	prune(state, now)
	return #state.pending == 0 and #state.sent == 0 and next(state.lastSent) == nil
end

return Limiter
