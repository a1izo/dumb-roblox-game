--!strict
-- What kind of device this is, asked in one place: is it a touch screen without a keyboard (a phone or tablet), and
-- what did the player touch last. Every touch check in the client goes through here, so a Studio test can play the
-- game as a phone: the Workspace attribute DGForceDevice = "phone" or "tablet" (honoured in Studio only) makes the
-- game take this for a touch screen, its last input a touch.

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Device = {}

-- "phone" or "tablet" when a Studio test plays as one, else nil.
function Device.forced(): string?
	if not RunService:IsStudio() then
		return nil
	end
	local value = workspace:GetAttribute("DGForceDevice")
	return if value == "phone" or value == "tablet" then value else nil
end

-- A touch screen with no keyboard: a phone or a tablet.
function Device.touch(): boolean
	if Device.forced() then
		return true
	end
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

-- A mouse is the pointer (a computer, not a touch screen).
function Device.mouse(): boolean
	return UserInputService.MouseEnabled and not UserInputService.TouchEnabled and Device.forced() == nil
end

-- The input the player used last (a touch, always, on a forced touch screen).
function Device.lastInput(): Enum.UserInputType
	if Device.forced() then
		return Enum.UserInputType.Touch
	end
	return UserInputService:GetLastInputType()
end

return Device
