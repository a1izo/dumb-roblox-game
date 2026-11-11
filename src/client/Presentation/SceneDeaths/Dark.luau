-- Taken by the dark (11 s; remade 2026-11-11 as a scene death; the user, 2026-11-10: "make it so in taken by the dark
-- you completely disappear into the dark"). A long hallway of an old house at night (the set:
-- maps/venues/scenes/remade.py dark), doors down both sides, bulbs on cords down its length; behind the victim it runs
-- on into black. A sound behind: they look back; the bulbs behind them go out one by one, the dark coming up the hall;
-- they walk on, faster; the bulb over them fails, two red eyes in the black; they run; arms of shadow reach out of the
-- dark and take their legs; dragged back down the hall in pulls, clawing at the boards, into the black, gone. Nothing
-- is left of them (the server leaves no body either: RagdollService). No words, no faces.

local Cinema = require(script.Parent.Parent.Cinema)
local Vfx = require(script.Parent.Parent.Vfx)
local Sfx = require(script.Parent.Parent.Parent.Audio.Sfx)

local BULB = Color3.fromRGB(255, 214, 160)
local EYES = Color3.fromRGB(255, 30, 36)
-- the bulbs down the hall (z) and when each goes out (nil: stays lit); behind the victim is +z
local BULBS = {
	{ 34.0, 1.6 },
	{ 26.0, 2.3 },
	{ 18.0, 3.0 },
	{ 10.0, 3.9 },
	{ 2.0, 4.85 },
	{ -6.0, 9.6 },
	{ -14.0, 10.2 },
	{ -22.0, 10.6 },
}
local YANK = 6.15

local function build(ctx)
	if ctx:set() == nil then
		ctx:part({ size = Vector3.new(9, 1, 100), at = Vector3.new(0, -0.5, 10), color = Color3.fromRGB(36, 28, 24) })
	end
	-- the bulbs: a glowing bulb on its cord, its light; each goes out with a flicker on its moment
	for k, spec in ipairs(BULBS) do
		local z, out = spec[1], spec[2]
		ctx:part({
			size = Vector3.new(0.05, 2.4, 0.05),
			at = Vector3.new(0, 8.8, z),
			color = Color3.fromRGB(20, 20, 20),
		})
		local bulb = ctx:part({
			size = Vector3.new(0.5, 0.6, 0.5),
			at = Vector3.new(0, 7.4, z),
			color = BULB,
			glow = true,
			shape = "Ball",
		})
		local light = ctx:light(Vector3.new(0, 7.1, z), BULB, 16, 1.3, k == 5)
		ctx:during(out - 0.45, out, function(t)
			local on = math.floor(t * 22 + k) % 3 ~= 0
			light.Brightness = if on then 1.3 else 0.1
			bulb.Transparency = if on then 0 else 0.85
		end)
		ctx:at(out, function()
			light.Brightness = 0
			bulb.Color = Color3.fromRGB(40, 36, 30)
			bulb.Material = Enum.Material.SmoothPlastic
			Sfx.play("uiHover", { pitch = 0.4, volume = 0.6 })
		end)
	end

	local victim =
		ctx:actor(ctx.victim or "figure", CFrame.lookAt(Vector3.zero, Vector3.new(0, 0, -6)), "sceneDarkVictim")
	local function at(limb: string, fallback: Vector3): Vector3
		local p = victim and ctx:limb(victim, limb)
		return if p then ctx.origin:PointToObjectSpace(p.Position) else fallback
	end
	local function head(): Vector3
		return at("Head", Vector3.new(0, 4.5, 0))
	end
	local function chest(): Vector3
		return at("Torso", Vector3.new(0, 3, 0))
	end

	-- the dark itself: a wall of black haze coming up the hall behind the last lit bulb
	local front = 40
	local haze = ctx:part({
		size = Vector3.new(9, 11, 2),
		at = Vector3.new(0, 5, front),
		color = Color3.new(0, 0, 0),
		alpha = 0.05,
		cast = false,
	})
	ctx:during(0, 11, function(t)
		-- (the dark's front: where the bulbs have gone out to, then on over the body)
		local reach = 40
		for _, spec in ipairs(BULBS) do
			if t >= spec[2] and spec[1] < reach then
				reach = spec[1] + 4
			end
		end
		if t > YANK then
			reach = math.min(reach, at("Torso", Vector3.new(0, 0, 0)).Z + 6)
		end
		front += (reach - front) * 0.08
		haze.CFrame = ctx.origin * CFrame.new(0, 5, front + 1)
	end)
	-- two red eyes in the black, behind them, when the bulb over them fails
	local eyes = {}
	ctx:at(4.85, function()
		for _, x in ipairs({ -0.5, 0.5 }) do
			local e = ctx:part({
				size = Vector3.new(0.22, 0.12, 0.05),
				at = Vector3.new(x, 5.6, 14),
				color = EYES,
				glow = true,
			})
			e.Transparency = 1
			ctx:tween(e, 0.4, { Transparency = 0 })
			table.insert(eyes, e)
		end
		Cinema.flash(Color3.fromRGB(60, 0, 0), 0.2, 0.3)
	end)
	ctx:during(4.85, 11, function(t)
		local z = 14 - math.min(8, (t - 4.85) * 1.6)
		for k, e in ipairs(eyes) do
			e.CFrame = ctx.origin * CFrame.new((k - 1.5) * 1.0, 5.6, z)
		end
	end)
	-- the arms of shadow: dark tendrils out of the black, round the legs, dragging
	local tendrils = {}
	ctx:at(YANK - 0.1, function()
		for k = 1, 5 do
			local beam, stop = Vfx.Beams.line(Vector3.zero, Vector3.new(0, 0, 1), {
				tex = "VfxWisp",
				color = Color3.new(0, 0, 0),
				width = 0.6,
				width1 = 0.2,
				light = 0,
				bright = 1,
				alpha = NumberSequence.new(0.05),
				segments = 12,
			})
			beam.CurveSize0 = (k - 3) * 1.5
			beam.CurveSize1 = (3 - k) * 1.2
			table.insert(tendrils, { beam = beam, stop = stop, k = k })
		end
		Vfx.Screen.shake(1.6, 0.5)
		Sfx.play("thunder", { volume = 0.4, pitch = 0.5 })
	end)
	ctx:during(YANK - 0.1, 10.6, function(_t)
		local legs = victim and (ctx:limb(victim, "Left Leg") or ctx:limb(victim, "Right Leg"))
		for _, td in ipairs(tendrils) do
			local beam = td.beam
			local a0, a1 = beam.Attachment0, beam.Attachment1
			if legs and a0 and a1 then
				local foot = legs.Position + Vector3.new((td.k - 3) * 0.3, -0.6, 0)
				local from = ctx:world(Vector3.new((td.k - 3) * 1.4, 2 + td.k * 0.6, front + 2))
				a0.WorldCFrame = CFrame.lookAt(from, foot) * CFrame.Angles(0, math.rad(90), 0)
				a1.WorldCFrame = CFrame.lookAt(foot, foot + (foot - from)) * CFrame.Angles(0, math.rad(90), 0)
			end
		end
	end)
	-- into the black: the body fades into the dark as it is dragged in; the tendrils go with it
	ctx:at(9.4, function()
		if victim then
			ctx:fadeOut(victim, 1.2)
		end
	end)
	ctx:at(10.6, function()
		for _, td in ipairs(tendrils) do
			td.stop(0.3)
		end
		for _, e in ipairs(eyes) do
			ctx:tween(e, 0.4, { Transparency = 1 })
		end
	end)

	-- cameras
	-- 0.0 low ahead of them, looking back down the hall: walking toward the lens, the black behind
	ctx:camera(0, 1.9, function(_t)
		local h = head()
		return CFrame.lookAt(Vector3.new(0.7, 4.0, h.Z - 7.5), h + Vector3.new(0, -0.6, 4)), 40
	end)
	-- 1.9 over the shoulder, back into the black: the bulbs behind going out one by one
	ctx:camera(1.9, 3.3, function(_t)
		local h = head()
		return CFrame.lookAt(h + Vector3.new(-0.9, 0.3, -1.4), Vector3.new(0, 5, 30)), 40
	end)
	-- 3.3 alongside them as they walk on, faster
	ctx:camera(3.3, 4.85, function(_t)
		local c = chest()
		return CFrame.lookAt(Vector3.new(3.6, 4.4, c.Z - 1.0), c + Vector3.new(0, 0.6, 0)), 40
	end)
	-- 4.85 from out of the black behind them, low: the red eyes' view of them running
	ctx:camera(4.85, YANK + 0.5, function(_t)
		local h = head()
		return CFrame.lookAt(Vector3.new(0.6, 2.4, 13), h), 36
	end)
	-- 6.65 on the floor ahead of them: the face clawing toward the lens, dragged away from it
	ctx:camera(YANK + 0.5, 9.0, function(_t)
		local h = head()
		return CFrame.lookAt(Vector3.new(0.5, 0.9, -5.5), h + Vector3.new(0, -0.2, 0)), 34
	end)
	-- 9.0 far up the hall: the body dragged on down it into the black, gone; the last bulbs going out
	ctx:camera(9.0, 11, function(t)
		local u = math.clamp((t - 9.0) / 2.0, 0, 1)
		return CFrame.lookAt(Vector3.new(0, 5, -20 - 2 * u), Vector3.new(0, 2.5, 14)), 34 - 4 * u
	end)
	ctx:grade(0, nil, { Saturation = -0.35, Contrast = 0.22, TintColor = Color3.fromRGB(240, 226, 210) }, 0.1)
	ctx:grade(4.85, nil, { Saturation = -0.55, Contrast = 0.3, Brightness = -0.04 }, 0.5)
end

return { length = 11, build = build }
