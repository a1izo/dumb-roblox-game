--!strict
-- Where things go on screen. Screens are designed at desktop size (1280 x 820) and scaled by
-- Responsive; phones get their own arrangements (bottom sheets, thumb-reach action rows).
--
-- HUD zones inside the safe area:
--   topCenter     the phase banner and clock
--   topLeft       objectives
--   bottomLeft    who you are (seal and alias)
--   bottomRight   actions
--   right         slips (notifications)
--   bottomCenter  subtitles and announcements

local Responsive = require(script.Parent.Parent.Core.Responsive)
local Tokens = require(script.Parent.Tokens)

local Layout = {}

Layout.Changed = Responsive.Changed

function Layout.class(): string
	return Responsive.class()
end

function Layout.isPhone(): boolean
	return Responsive.class() == "phone"
end

-- Phones and tablets are laid out for thumbs.
function Layout.isTouch(): boolean
	return Responsive.isTouch()
end

local M = Tokens.space.l

Layout.ZONES = {
	topCenter = { anchor = Vector2.new(0.5, 0), position = UDim2.new(0.5, 0, 0, M) },
	topLeft = { anchor = Vector2.new(0, 0), position = UDim2.new(0, M, 0, M) },
	topRight = { anchor = Vector2.new(1, 0), position = UDim2.new(1, -M, 0, M) },
	bottomLeft = { anchor = Vector2.new(0, 1), position = UDim2.new(0, M, 1, -M) },
	bottomRight = { anchor = Vector2.new(1, 1), position = UDim2.new(1, -M, 1, -M) },
	bottomCenter = { anchor = Vector2.new(0.5, 1), position = UDim2.new(0.5, 0, 1, -M * 6) },
	right = { anchor = Vector2.new(1, 0), position = UDim2.new(1, -M, 0, 120) },
	center = { anchor = Vector2.new(0.5, 0.5), position = UDim2.fromScale(0.5, 0.5) },
}

-- Puts a GuiObject in a zone, nudged by `offset` pixels.
function Layout.place(gui: GuiObject, zone: string, offset: Vector2?)
	local z = Layout.ZONES[zone] or Layout.ZONES.center
	gui.AnchorPoint = z.anchor
	gui.Position = z.position + UDim2.fromOffset(if offset then offset.X else 0, if offset then offset.Y else 0)
end

-- Calls `apply(class)` now and whenever the device class changes.
function Layout.watch(apply: (string) -> ()): any
	apply(Responsive.class())
	local last = Responsive.class()
	return Responsive.Changed:Connect(function(class: string)
		if class ~= last then
			last = class
			apply(class)
		end
	end)
end

-- Builds a screen's own layout for the device: `phone` on a phone, `pc` everywhere else (desktop, tablet
-- and console share the PC layout; tablets get the same touch-sized controls). Each builder gets
-- (class, previous) and is called again when the device class changes between phone and not-phone,
-- so it should clear what it built before. Returns the connection.
--
--   Layout.variant({ phone = buildPhone, pc = buildPc })
function Layout.variant(builders: { phone: ((string) -> ())?, pc: ((string) -> ())? }): any
	local lastKind: string? = nil
	local function build(class: string)
		local kind = if class == "phone" then "phone" else "pc"
		if kind == lastKind then
			return
		end
		lastKind = kind
		local builder = if kind == "phone" then builders.phone or builders.pc else builders.pc or builders.phone
		if builder then
			builder(class)
		end
	end
	build(Responsive.class())
	return Responsive.Changed:Connect(build)
end

return Layout
