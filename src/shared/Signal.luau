-- Minimal signal used for in-process events between modules.

local Signal = {}
Signal.__index = Signal

export type Connection = { Disconnect: () -> () }

function Signal.new()
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal:Connect(handler: (...any) -> ()): Connection
	local handlers = self._handlers
	local entry = { handler = handler, connected = true }
	table.insert(handlers, entry)
	return {
		Disconnect = function()
			if not entry.connected then
				return
			end
			entry.connected = false
			local index = table.find(handlers, entry)
			if index then
				table.remove(handlers, index)
			end
		end,
	}
end

function Signal:Fire(...: any)
	-- Copy first so handlers may disconnect while the signal fires.
	for _, entry in ipairs(table.clone(self._handlers)) do
		if entry.connected then
			task.spawn(entry.handler, ...)
		end
	end
end

return Signal
