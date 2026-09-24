--!strict
-- Collects things to clean up later: instances, connections, tweens, threads and plain
-- functions. Panels and cutscenes create a scope when they open and destroy it when they
-- close, so nothing they created or connected outlives them.

local Scope = {}
Scope.__index = Scope

export type Scope = typeof(setmetatable({} :: { items: { any } }, Scope))

function Scope.new(): Scope
	return setmetatable({ items = {} }, Scope)
end

-- Adds an item and returns it, so creation and registration fit on one line.
function Scope.add<T>(self: Scope, item: T): T
	table.insert(self.items, item)
	return item
end

function Scope.connect(self: Scope, signal: any, handler: (...any) -> ()): any
	return self:add(signal:Connect(handler))
end

-- A child scope is destroyed together with this one, or on its own earlier.
function Scope.child(self: Scope): Scope
	local child = Scope.new()
	self:add(function()
		child:destroy()
	end)
	return child
end

local function clean(item: any)
	local kind = typeof(item)
	local disconnectable = kind == "RBXScriptConnection" or (kind == "table" and type(item.Disconnect) == "function")
	if kind == "Instance" then
		if item:IsA("Tween") then
			item:Cancel()
		end
		item:Destroy()
	elseif disconnectable then
		item:Disconnect()
	elseif kind == "thread" then
		pcall(task.cancel, item)
	elseif kind == "function" then
		item()
	elseif kind == "table" and type(item.destroy) == "function" then
		item:destroy()
	end
end

-- Cleans up in reverse order of creation. The scope can be reused afterwards.
function Scope.destroy(self: Scope)
	local items = self.items
	self.items = {}
	for index = #items, 1, -1 do
		clean(items[index])
	end
end

return Scope
