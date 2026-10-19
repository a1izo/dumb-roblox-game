--!nonstrict
-- Settings > Controls: every control the player can rebind (Shared/Bindings), keyboard and gamepad apart, and
-- the touch buttons' layout. A change applies at once and is saved in the profile (ProfileRequest "keybinds",
-- the whole set each time, a moment after the last change).
--
-- Rebinding: pick a key slot, press the new key (Escape or the slot again cancels, Delete leaves the slot
-- empty). A key Roblox keeps for itself is refused. A key another action already uses at the same time is
-- offered as a swap: that action takes the key this slot had.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Bindings = require(Shared:WaitForChild("Bindings"))
local Net = require(Shared:WaitForChild("Net"))

local Actions = require(script.Parent.Parent.Input.Actions)
local InputRouter = require(script.Parent.Parent.Input.InputRouter)
local Keys = require(script.Parent.Parent.Input.Keys)
local Kit = require(script.Parent.Kit)
local Toasts = require(script.Parent.Toasts)

local C = Kit.color
local T = Kit.Tokens

local ProfileRequest = Net.event("ProfileRequest")

local ControlsPage = {}

local SEND_DELAY = 0.7
local SLOT_WIDTH = 104

-- The set being edited: { keyboard = { [id] = { names } }, gamepad = ..., touch = ... } (only what differs is
-- kept by the server, but the whole thing is sent).
local draft: any = {}
local sendQueued = false

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in pairs(value) do
		out[k] = deepCopy(v)
	end
	return out
end

local function send()
	if sendQueued then
		return
	end
	sendQueued = true
	task.delay(SEND_DELAY, function()
		sendQueued = false
		ProfileRequest:FireServer({ action = "keybinds", keybinds = Bindings.clean(draft) })
	end)
end

local function keysOf(id: string, platform: string): { string }
	return table.clone(Bindings.keys(id, platform, draft))
end

local function setKeys(id: string, platform: string, keys: { string })
	draft[platform] = draft[platform] or {}
	draft[platform][id] = keys
end

-- The actions that would share `key` with `id` at the same time on this platform.
local function sharing(id: string, platform: string, key: string): { string }
	local own = Bindings.get(id)
	local found = {}
	for _, other in ipairs(Bindings.ACTIONS) do
		if other.id ~= id and own and Bindings.together(own.context, other.context) then
			if table.find(Bindings.keys(other.id, platform, draft), key) then
				table.insert(found, other.id)
			end
		end
	end
	return found
end

-- Page state -------------------------------------------------------------------------------------------------------

local root: Frame
local body: ScrollingFrame
local platform = "keyboard"
local listening: { id: string, slot: number, button: TextButton }? = nil
local listenConn: RBXScriptConnection? = nil
local render: () -> ()
local chooseTab: ((string) -> ())? = nil

local function stopListening()
	InputRouter.setPaused(false)
	if listenConn then
		listenConn:Disconnect()
		listenConn = nil
	end
	listening = nil
end

-- Puts `key` in the slot, swapping it away from the actions that had it (they take this slot's old key).
local function place(id: string, slot: number, key: string?, swapWith: { string }?)
	local keys = keysOf(id, platform)
	local old = keys[slot]
	if key then
		local at = table.find(keys, key)
		if at then
			table.remove(keys, at)
			if at < slot then
				slot -= 1
			end
		end
		if slot > #keys then
			table.insert(keys, key)
		else
			keys[slot] = key
		end
	elseif keys[slot] then
		table.remove(keys, slot)
	end
	setKeys(id, platform, keys)
	for _, other in ipairs(swapWith or {}) do
		local theirs = keysOf(other, platform)
		local at = key and table.find(theirs, key)
		if at then
			if old and not table.find(theirs, old) then
				theirs[at] = old
			else
				table.remove(theirs, at)
			end
			setKeys(other, platform, theirs)
		end
	end
	send()
end

local function inputMatches(input: InputObject): boolean
	if platform == "keyboard" then
		return input.UserInputType == Enum.UserInputType.Keyboard
	end
	return string.find(input.UserInputType.Name, "^Gamepad") ~= nil
end

-- Waits for the next key (or button) for one slot.
local function listen(id: string, slot: number, button: TextButton)
	local same = listening and listening.id == id and listening.slot == slot
	stopListening()
	if same then
		render()
		return
	end
	listening = { id = id, slot = slot, button = button }
	InputRouter.setPaused(true)
	Kit.setText(button, if platform == "keyboard" then "Press a key" else "Press a button", false)
	listenConn = UserInputService.InputBegan:Connect(function(input: InputObject)
		if not inputMatches(input) then
			return
		end
		local name = input.KeyCode.Name
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
			stopListening()
			render()
			return
		end
		if input.KeyCode == Enum.KeyCode.Delete then
			stopListening()
			place(id, slot, nil)
			render()
			return
		end
		if string.find(name, "^Thumbstick") then
			return
		end
		if not Bindings.keyAllowed(name) then
			Toasts.show("That key is Roblox's own: pick another.", "error")
			return
		end
		stopListening()
		local others = sharing(id, platform, name)
		if #others == 0 then
			place(id, slot, name)
			render()
			return
		end
		-- Offered as a swap, in the row itself.
		local labels = {}
		for _, other in ipairs(others) do
			local action = Bindings.get(other)
			table.insert(labels, if action then action.label else other)
		end
		local row = button.Parent and button.Parent.Parent
		if not row then
			return
		end
		local ask = Kit.frame({
			Name = "Swap",
			Size = UDim2.new(1, 0, 0, T.touch),
			LayoutOrder = (row.LayoutOrder or 0) + 1,
			Parent = row.Parent,
		})
		Kit.list(ask, T.space.s, true, Enum.HorizontalAlignment.Right)
		Kit.label({
			Text = string.format("%s is on %s.", Bindings.label(name), table.concat(labels, ", ")),
			size = "small",
			color = C.dim,
			TextWrapped = false,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			LayoutOrder = 1,
			Parent = ask,
		})
		Kit.button({ text = "Swap", size = "s", variant = "primary", LayoutOrder = 2, Parent = ask }, function()
			place(id, slot, name, others)
			render()
		end)
		Kit.button({ text = "Cancel", size = "s", variant = "ghost", LayoutOrder = 3, Parent = ask }, function()
			render()
		end)
	end)
end

-- Rows -------------------------------------------------------------------------------------------------------------

local function header(text: string, order: number)
	Kit.heading({ text = text, LayoutOrder = order, Parent = body })
end

local function keyRow(id: string, order: number)
	local action = Bindings.get(id)
	if not action then
		return
	end
	local row =
		Kit.frame({ Name = "Row_" .. id, Size = UDim2.new(1, 0, 0, T.touch), LayoutOrder = order, Parent = body })
	Kit.label({
		Text = action.label,
		size = "small",
		color = C.bone,
		TextWrapped = true,
		Size = UDim2.new(1, -(SLOT_WIDTH * 2 + T.touch + T.space.s * 3), 1, 0),
		AutomaticSize = Enum.AutomaticSize.None,
		TextYAlignment = Enum.TextYAlignment.Center,
		Parent = row,
	})
	local slots = Kit.frame({
		Name = "Slots",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, SLOT_WIDTH * 2 + T.touch + T.space.s * 2, 1, 0),
		Parent = row,
	})
	Kit.list(slots, T.space.s, true, Enum.HorizontalAlignment.Right)
	local keys = Bindings.keys(id, platform, draft)
	for slot = 1, Bindings.MAX_KEYS do
		local name = keys[slot]
		local button = Kit.button({
			text = if name then Bindings.label(name) else "—",
			size = "s",
			variant = if name then "secondary" else "ghost",
			upper = false,
			width = SLOT_WIDTH,
			LayoutOrder = slot,
			Parent = slots,
		})
		button.Activated:Connect(function()
			listen(id, slot, button)
		end)
	end
	Kit.iconButton({ icon = "back", size = T.touch, LayoutOrder = 3, Parent = slots }, function()
		stopListening()
		if draft[platform] then
			draft[platform][id] = nil
		end
		send()
		render()
	end)
end

-- The pad's sticks: one switch swaps walking and looking round.
local function stickRow(order: number)
	local swapped = Bindings.keys("move", "gamepad", draft)[1] == "Thumbstick2"
	Kit.toggle(
		{ LayoutOrder = order, Parent = body },
		"Walk with the right stick, look with the left",
		swapped,
		function(on)
			setKeys("move", "gamepad", { if on then "Thumbstick2" else "Thumbstick1" })
			setKeys("look", "gamepad", { if on then "Thumbstick1" else "Thumbstick2" })
			send()
		end
	)
end

local function resetRow(order: number, label: string, apply: () -> ())
	local row = Kit.frame({ Size = UDim2.new(1, 0, 0, T.touch + T.space.s), LayoutOrder = order, Parent = body })
	Kit.list(row, T.space.m, true)
	local armed = false
	local button
	button = Kit.button({ text = label, size = "s", variant = "ghost", Parent = row }, function()
		if not armed then
			armed = true
			Kit.setText(button, "Sure? Press again")
			task.delay(3, function()
				if armed and button.Parent then
					armed = false
					Kit.setText(button, label)
				end
			end)
			return
		end
		armed = false
		stopListening()
		apply()
		send()
		render()
	end)
end

local function renderKeys(order: () -> number)
	resetRow(order(), if platform == "keyboard" then "Reset every key" else "Reset every button", function()
		draft[platform] = nil
	end)
	Kit.label({
		Text = if platform == "keyboard"
			then "Pick a slot, then press the new key. Escape cancels; Delete leaves the slot empty."
			else "Pick a slot, then press the new button. B cancels.",
		size = "small",
		color = C.dim,
		LayoutOrder = order(),
		Parent = body,
	})
	local stickDone = false
	for _, section in ipairs(Bindings.SECTIONS) do
		local shown = {}
		for _, id in ipairs(section.ids) do
			local action = Bindings.get(id)
			local isStick = id == "move" or id == "look"
			-- (a pad walks, looks round and picks wheel slots with its sticks: those keyboard keys have no row)
			local keyboardOnly = action ~= nil
				and #action.gamepad == 0
				and (action.context == "move" or action.context == "camera" or action.context == "wheel")
			-- (the one stick switch, under Moving, covers looking round too)
			local lookRow = platform == "gamepad" and id == "look"
			if
				action
				and not (platform == "keyboard" and isStick)
				and not (platform == "gamepad" and keyboardOnly)
				and not lookRow
			then
				table.insert(shown, id)
			end
		end
		if #shown > 0 then
			header(section.title, order())
			for _, id in ipairs(shown) do
				if id == "move" or id == "look" then
					if not stickDone then
						stickDone = true
						stickRow(order())
					end
				else
					keyRow(id, order())
					order() -- (room for a swap question under the row)
				end
			end
		end
	end
end

local function renderTouch(order: () -> number)
	local layout = Bindings.touchLayout(draft)
	local function setTouch(key: string, value: any)
		draft.touch = draft.touch or {}
		draft.touch[key] = value
		send()
	end
	resetRow(order(), "Reset the layout", function()
		draft.touch = nil
	end)
	header("The action buttons", order())
	Kit.toggle({ LayoutOrder = order(), Parent = body }, "On the left side", layout.side == "left", function(on)
		setTouch("side", if on then "left" else "right")
	end)
	local range = Bindings.TOUCH_RANGE
	Kit.slider(
		{ LayoutOrder = order(), Parent = body },
		"Size",
		layout.size,
		range.size[1],
		range.size[2],
		0.05,
		function(v)
			setTouch("size", v)
		end
	)
	Kit.slider(
		{ LayoutOrder = order(), Parent = body },
		"Height on screen",
		layout.height,
		range.height[1],
		range.height[2],
		0.01,
		function(v)
			setTouch("height", v)
		end
	)
	Kit.slider(
		{ LayoutOrder = order(), Parent = body },
		"Prompt buttons (stations, notes, emotes)",
		layout.prompts,
		range.prompts[1],
		range.prompts[2],
		0.05,
		function(v)
			setTouch("prompts", v)
		end
	)
	header("Buttons shown", order())
	Kit.label({
		Text = "A hidden button's action still works where it has its own prompt or panel.",
		size = "small",
		color = C.dim,
		LayoutOrder = order(),
		Parent = body,
	})
	for _, section in ipairs(Bindings.SECTIONS) do
		for _, id in ipairs(section.ids) do
			local action = Bindings.get(id)
			-- (the ones the action bar shows as buttons)
			if action and Actions.get(id) then
				Kit.toggle({ LayoutOrder = order(), Parent = body }, action.label, not layout.hide[id], function(on)
					draft.touch = draft.touch or {}
					draft.touch.hide = draft.touch.hide or {}
					draft.touch.hide[id] = if on then nil else true
					send()
				end)
			end
		end
	end
end

render = function()
	stopListening()
	local scroll = body.CanvasPosition
	Kit.clear(body)
	local order = Kit.counter()
	if platform == "touch" then
		renderTouch(order)
	else
		renderKeys(order)
	end
	body.CanvasPosition = scroll
end

-- Builds the page into `parent` (it fills it). Call `opened` each time Settings shows it.
function ControlsPage.new(parent: GuiObject): { opened: () -> () }
	root = Kit.frame({ Name = "Controls", Size = UDim2.fromScale(1, 1), Parent = parent })
	local _, choose = Kit.tabs({
		items = {
			{ id = "keyboard", label = "Keyboard" },
			{ id = "gamepad", label = "Gamepad" },
			{ id = "touch", label = "Touch" },
		},
		selected = platform,
		Size = UDim2.new(1, 0, 0, T.touch),
		Parent = root,
	}, function(id)
		platform = id
		body.CanvasPosition = Vector2.zero
		render()
	end)
	body = Kit.scroll({
		Position = UDim2.new(0, 0, 0, T.touch + T.space.s),
		Size = UDim2.new(1, 0, 1, -(T.touch + T.space.s)),
		Parent = root,
	})
	Kit.list(body, T.space.xs)
	Kit.pad(body, 0, T.space.xs)
	chooseTab = choose
	return {
		opened = function()
			ControlsPage.open()
		end,
	}
end

-- Shows the page afresh from the saved set, on a platform's tab (the input in the player's hands by default).
function ControlsPage.open(on: string?)
	draft = deepCopy(Bindings.clean(Keys.saved()))
	if chooseTab then
		chooseTab(on or Keys.input())
	end
end

-- For checks: the rows the page shows now ({ id = the keys' text }) and the platform shown.
function ControlsPage.rows(): ({ [string]: string }, string)
	local out = {}
	if body then
		for _, row in ipairs(body:GetChildren()) do
			local id = string.match(row.Name, "^Row_(.+)$")
			if id then
				out[id] = Bindings.text(id, platform, draft)
			end
		end
	end
	return out, platform
end

-- Stops waiting for a key (Settings closed or left this page).
function ControlsPage.closed()
	stopListening()
end

return ControlsPage
