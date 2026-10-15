--!strict
-- Pure toast stack logic (no Instances): at most `maxVisible` toasts on screen, identical toasts
-- coalesce into one with a counter, overflow waits in a bounded queue, and a backlog shortens the
-- oldest visible toast so the queue keeps moving. The HUD turns the returned events into Instances.
--
--   local q = ToastQueue.new({ maxVisible = 4 })
--   local events = ToastQueue.push(q, "+$450", "cash", now)
--   events = ToastQueue.tick(q, now)          -- call a few times per second
--   events = ToastQueue.dismiss(q, id, now)   -- player tapped a toast
-- Event = { type = "show" | "update" | "hide", item = Item }

local ToastQueue = {}

export type Item = {
	id: number,
	key: string,
	text: string,
	kind: string,
	count: number,
	duration: number,
	shownAt: number?,
	expiresAt: number?,
}
export type Event = { type: string, item: Item }
export type Queue = {
	maxVisible: number,
	maxQueued: number,
	duration: number,
	backlogLinger: number,
	visible: { Item },
	queued: { Item },
	nextId: number,
	dropped: number,
}
export type Opts = { maxVisible: number?, maxQueued: number?, duration: number?, backlogLinger: number? }

function ToastQueue.new(opts: Opts?): Queue
	local o: Opts = opts or {}
	return {
		maxVisible = o.maxVisible or 4,
		maxQueued = o.maxQueued or 8,
		duration = o.duration or 4,
		backlogLinger = o.backlogLinger or 1.2,
		visible = {},
		queued = {},
		nextId = 0,
		dropped = 0,
	}
end

function ToastQueue.keyOf(text: string, kind: string): string
	return kind .. "\0" .. text
end

local function show(q: Queue, item: Item, now: number, events: { Event })
	item.shownAt = now
	item.expiresAt = now + item.duration
	table.insert(q.visible, item)
	table.insert(events, { type = "show", item = item })
end

-- While items wait, make sure the oldest visible toast leaves soon.
local function hurry(q: Queue, now: number)
	if #q.queued == 0 then
		return
	end
	local oldest = q.visible[1]
	if oldest and oldest.expiresAt then
		local soon = math.max(now, (oldest.shownAt or now) + q.backlogLinger)
		if oldest.expiresAt > soon then
			oldest.expiresAt = soon
		end
	end
end

local function promote(q: Queue, now: number, events: { Event })
	while #q.visible < q.maxVisible and #q.queued > 0 do
		local nextItem = table.remove(q.queued, 1) :: Item
		show(q, nextItem, now, events)
	end
	hurry(q, now)
end

function ToastQueue.push(
	q: Queue,
	text: string,
	kind: string?,
	now: number,
	opts: { count: number?, duration: number? }?
): { Event }
	local events: { Event } = {}
	local k = kind or "info"
	local key = ToastQueue.keyOf(text, k)
	local add = math.max(1, math.floor((opts and opts.count) or 1))
	for _, item in q.visible do
		if item.key == key then
			item.count += add
			item.expiresAt = now + item.duration
			table.insert(events, { type = "update", item = item })
			return events
		end
	end
	for _, item in q.queued do
		if item.key == key then
			item.count += add
			return events
		end
	end
	q.nextId += 1
	local item: Item = {
		id = q.nextId,
		key = key,
		text = text,
		kind = k,
		count = add,
		duration = (opts and opts.duration) or q.duration,
	}
	if #q.visible < q.maxVisible then
		show(q, item, now, events)
	else
		table.insert(q.queued, item)
		while #q.queued > q.maxQueued do
			table.remove(q.queued, 1)
			q.dropped += 1
		end
		hurry(q, now)
	end
	return events
end

-- Hides expired toasts and promotes queued ones.
function ToastQueue.tick(q: Queue, now: number): { Event }
	local events: { Event } = {}
	local i = 1
	while i <= #q.visible do
		local item = q.visible[i]
		if item.expiresAt ~= nil and now >= item.expiresAt then
			table.remove(q.visible, i)
			table.insert(events, { type = "hide", item = item })
		else
			i += 1
		end
	end
	promote(q, now, events)
	return events
end

function ToastQueue.dismiss(q: Queue, id: number, now: number): { Event }
	local events: { Event } = {}
	for i, item in q.visible do
		if item.id == id then
			table.remove(q.visible, i)
			table.insert(events, { type = "hide", item = item })
			break
		end
	end
	promote(q, now, events)
	return events
end

function ToastQueue.clear(q: Queue): { Event }
	local events: { Event } = {}
	for _, item in q.visible do
		table.insert(events, { type = "hide", item = item })
	end
	table.clear(q.visible)
	table.clear(q.queued)
	return events
end

-- Text shown for an item ("Saved" or "Saved  x3").
function ToastQueue.label(item: Item, countFormat: string?): string
	if item.count > 1 then
		local suffix = string.gsub(countFormat or "x{count}", "{count}", tostring(item.count))
		return item.text .. "  " .. suffix
	end
	return item.text
end

return ToastQueue
