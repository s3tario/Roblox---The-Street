--!strict
-- Minimal signal: Connect / Once / Wait / Fire / DisconnectAll.
-- Handlers run via task.spawn so a yielding or erroring handler never blocks the firer.

export type Connection = { Connected: boolean, Disconnect: (self: Connection) -> () }
export type Signal = {
	Connect: (self: Signal, fn: (...any) -> ()) -> Connection,
	Once: (self: Signal, fn: (...any) -> ()) -> Connection,
	Wait: (self: Signal) -> ...any,
	Fire: (self: Signal, ...any) -> (),
	DisconnectAll: (self: Signal) -> (),
}

local Signal = {}
Signal.__index = Signal

local Connection = {}
Connection.__index = Connection

function Connection:Disconnect()
	if not self.Connected then
		return
	end
	self.Connected = false
	local list = self._signal._handlers
	for i, c in list do
		if c == self then
			table.remove(list, i)
			break
		end
	end
end

function Signal.new(): Signal
	return setmetatable({ _handlers = {} }, Signal) :: any
end

function Signal:Connect(fn)
	local c = setmetatable({ Connected = true, _fn = fn, _signal = self }, Connection)
	table.insert(self._handlers, c)
	return c
end

function Signal:Once(fn)
	local c
	c = self:Connect(function(...)
		c:Disconnect()
		fn(...)
	end)
	return c
end

function Signal:Wait()
	local thread = coroutine.running()
	self:Once(function(...)
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function Signal:Fire(...)
	-- Snapshot so handlers may disconnect while iterating.
	local snapshot: { any } = table.clone(self._handlers)
	for _, c in snapshot do
		if c.Connected then
			task.spawn(c._fn, ...)
		end
	end
end

function Signal:DisconnectAll()
	for _, c in self._handlers do
		c.Connected = false
	end
	table.clear(self._handlers)
end

return Signal
