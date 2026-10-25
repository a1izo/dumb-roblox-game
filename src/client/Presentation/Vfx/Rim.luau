--!strict
-- The VFX kit's rim: a body lit at its edges (a Highlight's outline, a faint fill) that comes up and dies on a curve,
-- for a power coming over someone (Ink Game's red-edged figure). Roblox draws a limited number of Highlights at once,
-- so a rim is skipped when too many are already up.

local Clock = require(script.Parent.Clock)
local Ease = require(script.Parent.Ease)

local Rim = {}

local LIMIT = 12
local live = 0

-- An edge of `color` round `model` (and a fill of it at `fill` strength, 0..1) for `hold` seconds, in over `fadeIn`
-- and out over `fadeOut`; returns a function that ends it early.
function Rim.glow(
	model: Model,
	color: Color3,
	hold: number,
	options: { fill: number?, fadeIn: number?, fadeOut: number?, front: boolean? }?
): () -> ()
	if live >= LIMIT then
		return function() end
	end
	local o = options or {}
	local fill = o.fill or 0.15
	local h = Instance.new("Highlight")
	h.Name = "DGVfxRim"
	h.FillColor = color
	h.OutlineColor = color
	h.FillTransparency = 1
	h.OutlineTransparency = 1
	h.DepthMode = if o.front then Enum.HighlightDepthMode.AlwaysOnTop else Enum.HighlightDepthMode.Occluded
	h.Adornee = model
	h:SetAttribute("DGEmote", true)
	h.Parent = model
	live += 1
	local done = false
	local function finish()
		if done then
			return
		end
		done = true
		local f0, o0 = h.FillTransparency, h.OutlineTransparency
		Clock.tween(o.fadeOut or 0.5, Ease.inQuad, function(u)
			h.FillTransparency = f0 + (1 - f0) * u
			h.OutlineTransparency = o0 + (1 - o0) * u
		end, function()
			h:Destroy()
			live -= 1
		end)
	end
	Clock.tween(o.fadeIn or 0.2, Ease.outQuad, function(u)
		h.FillTransparency = 1 - fill * u
		h.OutlineTransparency = 1 - u
	end, function()
		if hold < math.huge then
			Clock.after(hold, finish)
		end
	end)
	return finish
end

return Rim
