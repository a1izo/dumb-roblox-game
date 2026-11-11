-- Their time ran out (11 s; remade 2026-11-11 as a scene death). A colossal clock face lying in a grey void (the set:
-- maps/venues/scenes/remade.py clock; the sky: SkySceneVoid), gears hanging in the fog round it, sand falling from
-- above in thin streams. The victim stands on it looking at their wrist; the hands sweep round under them; then time
-- moves only in ticks: each tick jumps the world (the hands, the falling sand, the victim, the camera) into its next
-- moment and holds it there, the ticks further and further apart; at the last one they are stopped dead mid-stride,
-- the colour goes out of them, and they run out as sand, falling through the face. No words, no faces.

local SceneDeaths = require(script.Parent)
local Cinema = require(script.Parent.Parent.Cinema)
local Vfx = require(script.Parent.Parent.Vfx)
local Sfx = require(script.Parent.Parent.Parent.Audio.Sfx)

local TICKS = { 2.7, 3.25, 3.9, 4.65, 5.55, 6.6 }
local STOP = 7.4
local HAND = Color3.fromRGB(26, 26, 30)
local SAND = Color3.fromRGB(190, 184, 170)

local function smooth(u: number): number
	u = math.clamp(u, 0, 1)
	return u * u * (3 - 2 * u)
end

local function build(ctx)
	if ctx:set() == nil then
		ctx:part({
			size = Vector3.new(4, 68, 68),
			at = Vector3.new(0, -2, 0),
			rot = Vector3.new(0, 0, 90),
			color = Color3.fromRGB(220, 218, 212),
			shape = "Cylinder",
		})
	end
	ctx:light(Vector3.new(10, 40, -20), Color3.fromRGB(236, 236, 240), 120, 0.9)

	-- the hands: the hour hand, the minute hand, the thin second hand, turning on the hub
	local function hand(length: number, width: number, height: number, color: Color3): BasePart
		local p = ctx:part({
			size = Vector3.new(width, 0.3, length),
			at = Vector3.new(0, height, 0),
			color = color,
			material = Enum.Material.Metal,
		})
		p.CastShadow = true
		return p
	end
	local hour = hand(20, 1.6, 0.6, HAND)
	local minute = hand(29, 1.0, 0.95, HAND)
	local second = hand(31, 0.25, 1.3, Color3.fromRGB(150, 30, 34))
	local function setHand(p: BasePart, angle: number, length: number, height: number)
		-- (from the hub out along `angle`, clockwise seen from above, 12 at -z)
		local dir = Vector3.new(math.sin(angle), 0, -math.cos(angle))
		local mid = dir * (length / 2 - 2)
		p.CFrame = ctx.origin * CFrame.lookAt(mid + Vector3.new(0, height, 0), mid + dir + Vector3.new(0, height, 0))
	end
	-- the time the clock shows, scene seconds: running smooth until the first tick, then only on ticks
	local function shown(t: number): number
		if t < TICKS[1] then
			return t * 6
		end
		local last = TICKS[1]
		for _, tick in ipairs(TICKS) do
			if t >= tick then
				last = tick
			end
		end
		return last * 6
	end
	ctx:during(0, 11, function(t)
		local s = shown(math.min(t, STOP))
		setHand(second, s * math.pi * 2 / 12, 31, 1.3)
		setHand(minute, s * math.pi * 2 / 160 + 1.0, 29, 0.95)
		setHand(hour, s * math.pi * 2 / 900 + 3.4, 20, 0.6)
	end)

	-- sand falling from far above in thin streams round them; held still between the ticks
	local streams = {}
	for k = 1, 5 do
		local a = k * 1.3
		local e =
			SceneDeaths.emit(ctx, Vector3.new(math.cos(a) * 9, 40, math.sin(a) * 9 - 2), Vector3.new(0.4, 0.4, 0.4), {
				tex = "VfxDust",
				color = SAND,
				size = { { 0, 0.14 }, { 1, 0.1 } },
				life = { 2.6, 3 },
				speed = { 14, 16 },
				dir = Enum.NormalId.Bottom,
				spread = 1,
				lit = 0.8,
				rate = 60,
			})
		table.insert(streams, e)
	end
	ctx:during(TICKS[1], 11, function(t)
		local moving = false
		for _, tick in ipairs(TICKS) do
			if t >= tick and t < tick + 0.12 then
				moving = true
			end
		end
		for _, e in ipairs(streams) do
			e.TimeScale = if moving then 1 else 0
		end
	end)

	local victim =
		ctx:actor(ctx.victim or "figure", CFrame.lookAt(Vector3.zero, Vector3.new(0, 0, -6)), "sceneClockVictim")
	local function at(limb: string, fallback: Vector3): Vector3
		local p = victim and ctx:limb(victim, limb)
		return if p then ctx.origin:PointToObjectSpace(p.Position) else fallback
	end
	local function head(): Vector3
		return at("Head", Vector3.new(0, 4.5, 0))
	end

	-- the ticking: a hard tick on every second of the sweep, then each tick of the stopped time louder and slower,
	-- a pale ring running out over the face from under them
	for k = 0, 4 do
		ctx:at(0.3 + k * 0.5, function()
			Sfx.play("clockTick", { volume = 0.4 })
		end)
	end
	for k, tick in ipairs(TICKS) do
		ctx:at(tick, function()
			Sfx.play("clockTick", { volume = 0.7 + k * 0.1, pitch = 1 - k * 0.07 })
			local feet = at("Torso", Vector3.zero)
			Vfx.Beams.wave(
				CFrame.new(ctx:world(Vector3.new(feet.X, 0.15, feet.Z))),
				1,
				10 + k * 3,
				0.5,
				{ color = Color3.fromRGB(236, 236, 240), width = 0.9, bright = 2 }
			)
			Cinema.flash(Color3.new(1, 1, 1), 0.12 + k * 0.03, 0.15)
		end)
	end
	-- stopped: the colour goes out of them, then they run out as sand from the head down, falling through the face
	ctx:at(STOP, function()
		Sfx.play("clockTick", { volume = 1.2, pitch = 0.5 })
		if not victim then
			return
		end
		for _, p in ipairs(victim:GetDescendants()) do
			if p:IsA("BasePart") and p.Transparency < 1 and p.Name ~= "HumanoidRootPart" then
				local _, _, v = p.Color:ToHSV()
				ctx:tween(p, 0.8, { Color = Color3.fromHSV(0, 0, v * 0.75) })
				if p:IsA("MeshPart") and p.TextureID ~= "" then
					task.delay(0.5, function()
						p.TextureID = ""
					end)
				end
			end
		end
	end)
	ctx:at(STOP + 1.0, function()
		if not victim then
			return
		end
		local list = {}
		for _, p in ipairs(victim:GetDescendants()) do
			if p:IsA("BasePart") and p.Transparency < 1 and p.Name ~= "HumanoidRootPart" then
				table.insert(list, p)
			end
		end
		table.sort(list, function(a, b)
			return a.Position.Y > b.Position.Y
		end)
		for i, p in ipairs(list) do
			task.delay((i - 1) / math.max(1, #list) * 1.4, function()
				if not p.Parent then
					return
				end
				Vfx.Emit.burst(p.Position, {
					tex = "VfxDust",
					color = SAND,
					size = { { 0, 0.14 }, { 1, 0.08 } },
					life = { 1.2, 2 },
					speed = { 0.2, 1 },
					spread = 180,
					accel = Vector3.new(0, -14, 0),
					lit = 0.8,
				}, 28, p.Size)
				ctx:tween(p, 0.4, { Transparency = 1 })
				for _, d in ipairs(p:GetDescendants()) do
					if d:IsA("Decal") then
						ctx:tween(d, 0.3, { Transparency = 1 })
					end
				end
			end)
		end
	end)

	-- cameras
	-- 0.0 close on the wrist they are looking at, the face of the great clock out of focus beyond
	ctx:camera(0, 1.6, function(_t)
		local w = at("Left Arm", Vector3.new(-0.5, 3, -0.8))
		return CFrame.lookAt(w + Vector3.new(0.9, 0.9, -1.6), w + Vector3.new(0, -0.6, 0)), 34
	end)
	-- 1.6 straight down from high above: a tiny figure on the colossal face, the hands sweeping under it
	ctx:camera(1.6, TICKS[1], function(t)
		local u = smooth((t - 1.6) / (TICKS[1] - 1.6))
		return CFrame.lookAt(Vector3.new(0.1, 48 - 16 * u, 6 - 2 * u), Vector3.new(0, 0, 0)), 40
	end)
	-- each tick a hard cut to a new, still angle
	local angles = {
		{ Vector3.new(-7, 3, -7), 32 },
		{ Vector3.new(6, 1.2, -5), 36 },
		{ Vector3.new(0, 9, -12), 34 },
		{ Vector3.new(-4, 2, 4), 38 },
		{ Vector3.new(5, 5, -9), 30 },
	}
	for k, spec in ipairs(angles) do
		ctx:shot(TICKS[k], function()
			return head() + spec[1]
		end, function()
			return head() + Vector3.new(0, -1.0, 0)
		end, spec[2])
	end
	-- the last tick: in on the face
	ctx:shot(TICKS[6], function()
		return head() + Vector3.new(0.6, -0.2, -2.2)
	end, function()
		return head()
	end, 30)
	-- stopped: rising slowly away as they run out into sand on the face
	ctx:camera(STOP + 0.6, 11, function(t)
		local u = smooth((t - STOP - 0.6) / (11 - STOP - 0.6))
		local h = Vector3.new(0, 2.5, -1.7)
		return CFrame.lookAt(h + Vector3.new(3 + 6 * u, 3 + 18 * u, -6 - 10 * u), h), 36 + 6 * u
	end)
	ctx:grade(0, nil, { Saturation = -0.5, Contrast = 0.12 }, 0.1)
	ctx:grade(STOP, nil, { Saturation = -0.9, Contrast = 0.16 }, 0.6)
end

return { length = 11, build = build }
