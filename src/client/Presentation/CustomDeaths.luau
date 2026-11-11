--!strict
-- The custom deaths' effects (Shared/Cosmetics kind "reason", 2026-10-25): what the cause written in the Manual does
-- to the body as it falls, played on every screen by the death cutscene (Presenters/Death) a moment before the body
-- hits the floor. Each is layered from the VFX kit (Presentation/Vfx): a white-hot moment, a body of colour, the
-- floor answering, light thrown on the scene; none uses ink.
--
--   CustomDeaths.play(style, body)
--
-- (Since 2026-11-11 every custom death is a scene death with its own cutscene, Presentation/SceneDeaths: none plays
-- an effect at the table any more, so the table below is empty; it stays for one that would.)

local Vfx = require(script.Parent.Vfx)

local CustomDeaths = {}

-- `hit`: seconds from the effect's start to when the body hits the floor (Shared/Anim/DeathTiming), for the effects
-- whose impact lands with it.
type Fx = (body: Model, centre: Vector3, floor: Vector3, head: BasePart?, torso: BasePart?, hit: number?) -> ()

local FX: { [string]: Fx } = {}

local function floorOf(body: Model, at: Vector3): Vector3
	local hit = Vfx.Ground.at(at, { body }, 8)
	return hit
end

-- Plays the custom death `style` on `body` (a falling character), if there is one by that name. `timing.hit`: seconds
-- from now until the body hits the floor (Shared/Anim/DeathTiming), where the impact of a fall, a crushing or a breaking
-- lands.
function CustomDeaths.play(style: string?, body: Model?, timing: { hit: number? }?)
	local fx = if style then FX[style] else nil
	if not fx or not body then
		return
	end
	local torso = body:FindFirstChild("Torso") or body:FindFirstChild("HumanoidRootPart")
	local head = body:FindFirstChild("Head")
	if not torso or not torso:IsA("BasePart") then
		return
	end
	local centre = torso.Position
	fx(
		body,
		centre,
		floorOf(body, centre),
		if head and head:IsA("BasePart") then head else nil,
		if torso:IsA("BasePart") then torso else nil,
		if timing and timing.hit and timing.hit > 0 then timing.hit else nil
	)
end

-- (for checks: the styles there are)
function CustomDeaths.styles(): { string }
	local list = {}
	for name in pairs(FX) do
		table.insert(list, name)
	end
	table.sort(list)
	return list
end

return CustomDeaths
