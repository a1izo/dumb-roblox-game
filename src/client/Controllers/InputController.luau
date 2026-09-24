-- Keyboard shortcuts. Every action also has an on-screen button for touch devices.
--   B evidence board   Q quick chat   N write/read note   G drop note
--   R Specter's Eyes read   Z Zero's desk

local UserInputService = game:GetService("UserInputService")

local ClientState = require(script.Parent.Parent.ClientState)
local EvidencePanel = require(script.Parent.Parent.UI.EvidencePanel)
local EyesController = require(script.Parent.EyesController)
local LPanel = require(script.Parent.Parent.UI.LPanel)
local NotePanel = require(script.Parent.Parent.UI.NotePanel)
local QuickChatPanel = require(script.Parent.Parent.UI.QuickChatPanel)

local InputController = {}

function InputController.init()
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed or UserInputService:GetFocusedTextBox() then
			return
		end
		local key = input.KeyCode
		if key == Enum.KeyCode.B then
			if ClientState.public.active then
				EvidencePanel.toggle()
			end
		elseif key == Enum.KeyCode.Q then
			if ClientState.isLiving() then
				QuickChatPanel.toggle()
			end
		elseif key == Enum.KeyCode.N then
			NotePanel.toggle()
		elseif key == Enum.KeyCode.G then
			NotePanel.drop()
		elseif key == Enum.KeyCode.R then
			EyesController.read()
		elseif key == Enum.KeyCode.Z then
			LPanel.toggle()
		end
	end)
end

return InputController
