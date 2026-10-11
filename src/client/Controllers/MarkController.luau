--!strict
-- Death's mark, as it shows on the players (the game itself is the server's, Services/LobbyMark; joining,
-- leaving and the card are Controllers/LobbyGamesController's).
--
-- The server marks two things on a character, and every client draws them:
--   MarkCarrier  the one carrying the mark: an outline in the danger red and a small red light over them
--   MarkDown     the one the bell just dropped: a hand to the chest and down (the heart clip), until the
--                server lifts it; this player's own body is held still meanwhile.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))

local PoseController = require(script.Parent.Parent.Anim.PoseController)
local Kit = require(script.Parent.Parent.UI.Kit)

local MarkController = {}

local LocalPlayer = Players.LocalPlayer
local RED = Kit.color.danger

local function showCarrier(character: Model)
	local on = character:GetAttribute("MarkCarrier") == true
	local old = character:FindFirstChild("DeathsMark")
	if old then
		old:Destroy()
	end
	local light = character:FindFirstChild("DeathsMarkLight", true)
	if light then
		light:Destroy()
	end
	if not on then
		return
	end
	Create("Highlight", {
		Name = "DeathsMark",
		FillTransparency = 1,
		OutlineColor = RED,
		OutlineTransparency = 0.1,
		DepthMode = Enum.HighlightDepthMode.Occluded,
		Parent = character,
	})
	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		Create("PointLight", {
			Name = "DeathsMarkLight",
			Color = RED,
			Range = 10,
			Brightness = 1.4,
			Shadows = false,
			Parent = head,
		})
	end
end

local function showDown(character: Model)
	local down = character:GetAttribute("MarkDown") == true
	if down then
		PoseController.play(character, "collapseHeart", { fadeIn = 0.1 })
	else
		PoseController.stop(character, "collapseHeart", 0.4)
	end
	if character == LocalPlayer.Character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.PlatformStand = down
		end
	end
end

local function watch(character: Model)
	character:GetAttributeChangedSignal("MarkCarrier"):Connect(function()
		showCarrier(character)
	end)
	character:GetAttributeChangedSignal("MarkDown"):Connect(function()
		showDown(character)
	end)
	if character:GetAttribute("MarkCarrier") then
		showCarrier(character)
	end
	if character:GetAttribute("MarkDown") then
		showDown(character)
	end
end

local function follow(player: Player)
	player.CharacterAdded:Connect(watch)
	if player.Character then
		watch(player.Character)
	end
end

function MarkController.init()
	for _, player in ipairs(Players:GetPlayers()) do
		follow(player)
	end
	Players.PlayerAdded:Connect(follow)
end

return MarkController
