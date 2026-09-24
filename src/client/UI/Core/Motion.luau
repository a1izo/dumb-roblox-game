-- Tween presets for the UI. A new tween on the same instance cancels the previous one, and
-- with reduced motion (a player setting) every change is applied instantly.

local TweenService = game:GetService("TweenService")

local Motion = {}

local reduced = false
-- [instance][property list] = tween; a new tween only cancels one on the same properties.
local running: { [Instance]: { [string]: Tween } } = setmetatable({}, { __mode = "k" }) :: any

local function propertyKey(props: { [string]: any }): string
	local names = {}
	for name in pairs(props) do
		table.insert(names, name)
	end
	table.sort(names)
	return table.concat(names, ",")
end

function Motion.setReduced(value: boolean)
	reduced = value
end

function Motion.isReduced(): boolean
	return reduced
end

-- Tweens properties over `duration` seconds (0.2 by default) and returns the tween, or nil
-- when the change was applied instantly.
function Motion.tween(
	instance: Instance,
	props: { [string]: any },
	duration: number?,
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
): Tween?
	local key = propertyKey(props)
	local byInstance = running[instance]
	if not byInstance then
		byInstance = {}
		running[instance] = byInstance
	end
	local previous = byInstance[key]
	if previous then
		previous:Cancel()
		byInstance[key] = nil
	end
	local time = if reduced then 0 else (duration or 0.2)
	if time <= 0 then
		for name, value in pairs(props) do
			(instance :: any)[name] = value
		end
		return nil
	end
	local tween = TweenService:Create(
		instance,
		TweenInfo.new(time, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out),
		props
	)
	byInstance[key] = tween
	tween.Completed:Once(function()
		if byInstance[key] == tween then
			byInstance[key] = nil
		end
	end)
	tween:Play()
	return tween
end

local function uiScale(gui: GuiObject): UIScale
	local existing = gui:FindFirstChild("MotionScale")
	if existing and existing:IsA("UIScale") then
		return existing
	end
	local scale = Instance.new("UIScale")
	scale.Name = "MotionScale"
	scale.Parent = gui
	return scale
end

-- A window pops in: a quick scale-up from 94%.
function Motion.pop(gui: GuiObject)
	local scale = uiScale(gui)
	scale.Scale = if reduced then 1 else 0.94
	Motion.tween(scale, { Scale = 1 }, 0.18, Enum.EasingStyle.Back)
end

-- Fades a CanvasGroup (or any GuiObject's background) in or out.
function Motion.fade(gui: GuiObject, visible: boolean, duration: number?): Tween?
	if gui:IsA("CanvasGroup") then
		if visible then
			gui.GroupTransparency = if reduced then 0 else 1
			gui.Visible = true
		end
		return Motion.tween(gui, { GroupTransparency = if visible then 0 else 1 }, duration or 0.2)
	end
	gui.Visible = visible
	return nil
end

-- Slides a GuiObject in from an offset (in pixels) to its current position.
function Motion.slideIn(gui: GuiObject, fromOffset: Vector2, duration: number?)
	local target = gui.Position
	if reduced then
		return
	end
	gui.Position = target + UDim2.fromOffset(fromOffset.X, fromOffset.Y)
	Motion.tween(gui, { Position = target }, duration or 0.25)
end

-- A short nudge to draw the eye to something that changed.
function Motion.pulse(gui: GuiObject)
	if reduced then
		return
	end
	local scale = uiScale(gui)
	scale.Scale = 1.08
	Motion.tween(scale, { Scale = 1 }, 0.3, Enum.EasingStyle.Quad)
end

-- Counts a number label up from `from` to `to`; format turns the number into text.
function Motion.countUp(label: TextLabel, from: number, to: number, duration: number?, format: ((number) -> string)?)
	local show = format or function(value: number): string
		return tostring(math.floor(value + 0.5))
	end
	local total = if reduced then 0 else (duration or 0.8)
	if total <= 0 then
		label.Text = show(to)
		return
	end
	task.spawn(function()
		local started = os.clock()
		while label.Parent do
			local t = math.clamp((os.clock() - started) / total, 0, 1)
			local eased = 1 - (1 - t) ^ 3
			label.Text = show(from + (to - from) * eased)
			if t >= 1 then
				break
			end
			task.wait()
		end
	end)
end

return Motion
