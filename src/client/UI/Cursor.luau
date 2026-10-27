--!strict
-- The pointer's look (2026-10-27). Locked in the middle of the screen in a case's free roam (World/ShoulderCam):
-- the closed-eyes mark the user drew, white with a black outline (Assets.images.CursorLock). Everywhere else (the
-- lobby, menus, a screen open in a case, the results): a bone-white fountain-pen nib with a black outline, its point
-- where you click (Assets.images.CursorFree). Both are drawn by art/scripts/ui/cursors.py with the hot spot in the
-- middle of the picture (Roblox centres a custom pointer on the mouse). Roblox's own pointer stands in until the
-- pictures are uploaded.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Assets = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Assets"))

local Cursor = {}

local locked = false

local function apply()
	local id = Assets.images[if locked then "CursorLock" else "CursorFree"] or ""
	UserInputService.MouseIcon = if id ~= "" then Assets.contentId(id) else ""
end

-- Locked in the middle (the closed-eyes mark) or free (the nib).
function Cursor.setLocked(on: boolean)
	if on ~= locked then
		locked = on
		apply()
	end
end

function Cursor.init()
	apply()
end

return Cursor
