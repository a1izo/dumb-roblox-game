-- The one countdown source for the UI. Labels bound here are refreshed five times a second
-- from the server clock, so every timer on screen agrees with the server.

local RunService = game:GetService("RunService")

local ClientState = require(script.Parent.Parent.Parent.ClientState)

local Clock = {}

type Binding = { label: TextLabel, format: (number) -> string, endsAt: (() -> number)? }

local bindings: { [TextLabel]: Binding } = {}

function Clock.now(): number
	return workspace:GetServerTimeNow()
end

-- Seconds left in the current phase.
function Clock.phaseLeft(): number
	return ClientState.timeLeft()
end

-- "1:05", "0:09"
function Clock.format(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", whole // 60, whole % 60)
end

local function refresh(binding: Binding)
	local left = if binding.endsAt then math.max(0, binding.endsAt() - Clock.now()) else Clock.phaseLeft()
	binding.label.Text = binding.format(left)
end

-- Keeps `label` showing format(secondsLeft). By default it counts down the current phase;
-- pass endsAt to count down to another server time. Returns a function that unbinds.
function Clock.bind(label: TextLabel, format: ((number) -> string)?, endsAt: (() -> number)?): () -> ()
	local binding = { label = label, format = format or Clock.format, endsAt = endsAt }
	bindings[label] = binding
	refresh(binding)
	return function()
		if bindings[label] == binding then
			bindings[label] = nil
		end
	end
end

function Clock.init()
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.2 then
			return
		end
		elapsed = 0
		for label, binding in pairs(bindings) do
			if label.Parent == nil then
				bindings[label] = nil
			elseif label.Visible then
				refresh(binding)
			end
		end
	end)
end

return Clock
