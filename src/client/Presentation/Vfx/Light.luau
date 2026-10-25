--!strict
-- The VFX kit's lights: a flash that lights the scene round a hit and dies on a curve, and the flicker of a living
-- flame (its brightness wandering on noise, never a regular pulse).

local Clock = require(script.Parent.Clock)
local Ease = require(script.Parent.Ease)
local Emit = require(script.Parent.Emit)

local Light = {}

-- A point light at `at`: up to `brightness` at once, `range` studs, dying over `seconds` (outQuad).
function Light.flash(at: Vector3, color: Color3, range: number, brightness: number, seconds: number, shadows: boolean?)
	local p = Emit.point(at)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = shadows == true
	light.Parent = p
	Clock.tween(seconds, Ease.outQuad, function(u)
		light.Brightness = brightness * (1 - u)
		light.Range = range * (1 - 0.3 * u)
	end, function()
		p:Destroy()
	end)
end

-- A light that fades in and holds until the returned function fades it out.
function Light.hold(
	parent: Instance,
	color: Color3,
	range: number,
	brightness: number,
	fadeIn: number?
): (PointLight, (fadeOut: number?) -> ())
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = 0
	light.Shadows = false
	light.Parent = parent
	Clock.tween(fadeIn or 0.3, Ease.outQuad, function(u)
		light.Brightness = brightness * u
	end)
	local ended = false
	return light,
		function(fadeOut: number?)
			if ended then
				return
			end
			ended = true
			local from = light.Brightness
			Clock.tween(fadeOut or 0.4, Ease.outQuad, function(u)
				light.Brightness = from * (1 - u)
			end, function()
				light:Destroy()
			end)
		end
end

-- A flame's flicker on a light: its brightness and range wander about `brightness` by up to `amount` of it (two
-- noises, slow and quick), until the returned function stops it.
function Light.flicker(light: PointLight, brightness: number, range: number, amount: number?): () -> ()
	local seed = math.random() * 100
	local amp = amount or 0.25
	local stop = Clock.every(function(_, now)
		if not light.Parent then
			return false
		end
		local n = math.noise(now * 2.1, seed) * 0.65 + math.noise(now * 9.3, seed + 7) * 0.35
		light.Brightness = brightness * (1 + amp * n * 1.6)
		light.Range = range * (1 + amp * 0.35 * n)
		return true
	end)
	return stop
end

return Light
