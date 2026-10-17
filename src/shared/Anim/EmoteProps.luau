--!strict
-- What emotes hold or set down, by clip (EmoteController.dress puts them on, on every client that sees the
-- emote, and takes them away when it ends). The data lives in Anim/EmoteMeta, in plain numbers the art
-- scripts read as well; this module turns it into CFrames, Vector3s and Color3s once.
--
--   model   the Core model's key (ModelLibrary)
--   size    its biggest side in studs (the model is scaled to it)
--   stand   the stand-in: a part's shape ("Block", "Ball" or "Cylinder"), size and colour
--   mount   the body part it goes on ("Right Arm", "Left Arm", "Head", "Torso"), or "floor": standing on the
--           floor under the body, turned with it
--   at      where it sits, from the middle of that part (or from that point on the floor)
--   show    seconds into the clip it appears (at the start when nil); hide: when it goes (at the end when nil)
--   moves   carried somewhere else at a time: { at = seconds, mount = part?, to = CFrame }
--   tosses  thrown up off the hand and caught: { at, back, height, spin (turns) }
--   stack   copies set one on another: { step = CFrame, times = { seconds, ... } } (one at each time)
--   core    the Core import whose mesh this hold is made for: an older import shows the stand-in instead
--   drop    falls into place from above when it shows: { height = studs, time = seconds } (a thud as it lands)
--   sink    sinks down through the floor and goes: { at = seconds, time = seconds }

local EmoteMeta = require(script.Parent.EmoteMeta) :: any

local EmoteProps = {}

export type Move = { at: number, mount: string?, to: CFrame }
export type Toss = { at: number, back: number, height: number, spin: number }
export type Stack = { step: CFrame, times: { number } }
export type Stand = { shape: string, size: Vector3, color: Color3 }
export type Drop = { height: number, time: number }
export type Sink = { at: number, time: number }
export type Prop = {
	model: string,
	size: number,
	stand: Stand,
	mount: string,
	at: CFrame,
	show: number?,
	hide: number?,
	moves: { Move }?,
	tosses: { Toss }?,
	stack: Stack?,
	core: number?,
	drop: Drop?,
	sink: Sink?,
}

local rad = math.rad

-- A list of steps ({ p = {x, y, z} } moves, { r = {x, y, z} } turns in degrees), applied in order.
function EmoteProps.steps(steps: { any }?): CFrame
	local cf = CFrame.identity
	for _, step in ipairs(steps or {}) do
		if step.p then
			cf *= CFrame.new(step.p[1], step.p[2], step.p[3])
		end
		if step.r then
			cf *= CFrame.Angles(rad(step.r[1]), rad(step.r[2]), rad(step.r[3]))
		end
	end
	return cf
end

local function vector(list: { number }): Vector3
	return Vector3.new(list[1], list[2], list[3])
end

local function prop(raw: any): Prop
	local moves: { Move }? = nil
	if raw.moves then
		local list: { Move } = {}
		for _, move in ipairs(raw.moves) do
			table.insert(list, { at = move.at, mount = move.mount, to = EmoteProps.steps(move.to) })
		end
		moves = list
	end
	local stack: Stack? = nil
	if raw.stack then
		stack = { step = EmoteProps.steps(raw.stack.step), times = raw.stack.times }
	end
	return {
		model = raw.model,
		size = raw.size,
		stand = {
			shape = raw.stand.shape,
			size = vector(raw.stand.size),
			color = Color3.fromRGB(raw.stand.color[1], raw.stand.color[2], raw.stand.color[3]),
		},
		mount = raw.mount,
		at = EmoteProps.steps(raw.at),
		show = raw.show,
		hide = raw.hide,
		moves = moves,
		tosses = raw.tosses,
		stack = stack,
		core = raw.core,
		drop = raw.drop,
		sink = raw.sink,
	}
end

local CLIPS: { [string]: { Prop } } = {}
for clip, meta in pairs(EmoteMeta) do
	if meta.props and #meta.props > 0 then
		local list: { Prop } = {}
		for _, raw in ipairs(meta.props) do
			table.insert(list, prop(raw))
		end
		CLIPS[clip] = list
	end
end

-- What a clip holds (an empty list for one that holds nothing).
function EmoteProps.of(clip: string): { Prop }
	return CLIPS[clip] or {}
end

-- Every clip that holds something (for checks).
function EmoteProps.clips(): { string }
	local list = {}
	for clip in pairs(CLIPS) do
		table.insert(list, clip)
	end
	table.sort(list)
	return list
end

return EmoteProps
