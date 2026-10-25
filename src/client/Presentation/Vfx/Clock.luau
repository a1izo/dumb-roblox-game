--!strict
-- The VFX kit's clock: everything an effect does over time (growing, fading, moving, flickering, the next beat) runs
-- off one per-frame loop here, on the kit's own time, never TweenService (whose Completed a throttled client can miss).
-- The time can be held still (Clock.hold, for the harness's pictures: every live particle stops with it), and steps
-- are each wrapped so one effect's error never stops another's.

local RunService = game:GetService("RunService")

local Clock = {}

type Job = { step: (dt: number, now: number) -> boolean?, alive: boolean }

local jobs: { Job } = {}
local now = 0
local held = false
local emitters: { [ParticleEmitter]: number } = setmetatable({}, { __mode = "k" }) :: any
local beams: { [Beam]: number } = setmetatable({}, { __mode = "k" }) :: any
local connection: RBXScriptConnection? = nil

local function run(dt: number)
	if held then
		return
	end
	now += dt
	local k = 1
	while k <= #jobs do
		local job = jobs[k]
		local keep = job.alive
		if keep then
			local ok, result = pcall(job.step, dt, now)
			if not ok then
				warn("[DeathsGambit] VFX step failed: " .. tostring(result))
				keep = false
			elseif result == false then
				keep = false
			end
		end
		if keep then
			k += 1
		else
			job.alive = false
			jobs[k] = jobs[#jobs]
			jobs[#jobs] = nil
		end
	end
end

local function start()
	if not connection then
		connection = RunService.Heartbeat:Connect(run)
	end
end

-- (running from the start: the time moves on whether or not anything waits on it)
start()

-- The kit's time now (seconds).
function Clock.now(): number
	return now
end

-- Calls step(dt, now) every frame until it returns false or the returned cancel is called.
function Clock.every(step: (dt: number, now: number) -> boolean?): () -> ()
	start()
	local job: Job = { step = step, alive = true }
	table.insert(jobs, job)
	return function()
		job.alive = false
	end
end

-- Calls fn once `seconds` from now (kit time).
function Clock.after(seconds: number, fn: () -> ()): () -> ()
	local at = now + seconds
	return Clock.every(function(_, t)
		if t >= at then
			fn()
			return false
		end
		return true
	end)
end

-- Calls fn(eased u) every frame for `seconds`, u running 0 to 1, and fn(1) at the end; then done() if given.
function Clock.tween(seconds: number, ease: ((number) -> number)?, fn: (number) -> (), done: (() -> ())?): () -> ()
	local began = now
	local curve = ease or function(u: number): number
		return u
	end
	fn(curve(0))
	return Clock.every(function(_, t)
		local u = if seconds > 0 then math.clamp((t - began) / seconds, 0, 1) else 1
		fn(curve(u))
		if u >= 1 then
			if done then
				done()
			end
			return false
		end
		return true
	end)
end

-- Particle emitters and beams the kit made, so holding the clock holds them too.
function Clock.watch(item: Instance)
	if item:IsA("ParticleEmitter") then
		emitters[item] = item.TimeScale
	elseif item:IsA("Beam") then
		beams[item] = item.TextureSpeed
	end
end

-- Holds the kit's time still (true) or lets it run on (false): for pictures of an effect at a given moment.
function Clock.hold(on: boolean)
	if held == on then
		return
	end
	held = on
	for emitter, scale in pairs(emitters) do
		if emitter.Parent then
			emitter.TimeScale = if on then 0 else scale
		end
	end
	for beam, speed in pairs(beams) do
		if beam.Parent then
			beam.TextureSpeed = if on then 0 else speed
		end
	end
end

function Clock.held(): boolean
	return held
end

return Clock
