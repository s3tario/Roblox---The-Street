--!strict
-- QuestLine/Network (owned by `tutorial`; design v3 §14b): business-card exchanges between players and the campus
-- networking count, PURE. Each player's data.campus.exchanges logs { [otherUserId as string] = day } for today only;
-- an exchange needs both logs free for the pair, so it happens once per pair per real (UTC) day whoever starts it.
--
--   Network.RANGE (15 studs)   Network.DAY (86400 s)
--   Network.day(now) -> number                           UTC day index
--   Network.key(userId) -> string                        log key for a user id
--   Network.prune(log, now) -> log                       drops entries from earlier days
--   Network.exchangedToday(log, otherUserId, now) -> boolean
--   Network.check(a, b, distance, now, range?) -> (ok, errKey?)
--       a/b = { userId, log }   errKey: "self" | "far" | "today"
--   Network.record(log, otherUserId, now)                write after a successful check (both sides)
--   Network.pairKey(a, b) -> string                      order-independent pair id ("12:34")
--   Network.addContact(net, key) -> (added, count)       the networking step's unique contacts
--       net = data.campus.network { count, ids }; key "npc:<npcId>" or "player:<userId>"

local Network = {}

Network.RANGE = 15
Network.DAY = 86400

export type Side = { userId: number, log: { [string]: number } }

local function num(x: any, default: number): number
	if type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge then
		return x
	end
	return default
end

function Network.day(now: number): number
	return math.floor(num(now, 0) / Network.DAY)
end

function Network.key(userId: number): string
	return string.format("%d", math.floor(num(userId, 0)))
end

function Network.prune(log: { [string]: number }, now: number): { [string]: number }
	local today = Network.day(now)
	for k, d in log do
		if type(d) ~= "number" or d ~= today then
			log[k] = nil
		end
	end
	return log
end

function Network.exchangedToday(log: { [string]: number }?, otherUserId: number, now: number): boolean
	if type(log) ~= "table" then
		return false
	end
	return log[Network.key(otherUserId)] == Network.day(now)
end

function Network.check(a: Side, b: Side, distance: number, now: number, range: number?): (boolean, string?)
	if a.userId == b.userId then
		return false, "self"
	end
	if num(distance, math.huge) > (range or Network.RANGE) then
		return false, "far"
	end
	if Network.exchangedToday(a.log, b.userId, now) or Network.exchangedToday(b.log, a.userId, now) then
		return false, "today"
	end
	return true, nil
end

function Network.record(log: { [string]: number }, otherUserId: number, now: number)
	Network.prune(log, now)
	log[Network.key(otherUserId)] = Network.day(now)
end

function Network.pairKey(a: number, b: number): string
	local lo, hi = math.min(a, b), math.max(a, b)
	return Network.key(lo) .. ":" .. Network.key(hi)
end

function Network.addContact(net: { [string]: any }, key: string): (boolean, number)
	if type(net.ids) ~= "table" then
		net.ids = {}
	end
	local added = false
	if net.ids[key] ~= true then
		net.ids[key] = true
		added = true
	end
	local n = 0
	for _ in net.ids do
		n += 1
	end
	net.count = n
	return added, n
end

return Network
