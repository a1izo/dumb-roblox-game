-- Client side of the communication rules. The server enforces them; this controller
-- keeps the chat bar in the right state:
--   living, outside meetings -> no chat bar (quick-chat only)
--   living, meeting or vote  -> chat bar sends to the meeting channel
--   everyone else            -> normal chat (living players never receive it)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Terms = require(Shared:WaitForChild("Terms"))

local ClientState = require(script.Parent.Parent.ClientState)
local Kit = require(script.Parent.Parent.UI.Kit)
local LobbyChrome = require(script.Parent.Parent.UI.Core.LobbyChrome)

local ChatController = {}

local MEETING_CHANNEL = "LGameMeeting"
local SPECTER_CHANNEL = "LGameSpecters"

local function channel(name: string): TextChannel?
	local folder = TextChatService:FindFirstChild("TextChannels")
	local found = if folder then folder:FindFirstChild(name) else nil
	if found and found:IsA("TextChannel") then
		return found
	end
	return nil
end

local function update()
	local inputBar = TextChatService:FindFirstChildOfClass("ChatInputBarConfiguration")
	if not inputBar then
		return
	end
	-- The lobby's Hide UI hides chat as well (window, bubbles and the bar).
	local hidden = LobbyChrome.isHidden()
	local window = TextChatService:FindFirstChildOfClass("ChatWindowConfiguration")
	local bubbles = TextChatService:FindFirstChildOfClass("BubbleChatConfiguration")
	if window then
		window.Enabled = not hidden
	end
	if bubbles then
		bubbles.Enabled = not hidden
	end
	if hidden then
		inputBar.Enabled = false
		return
	end
	local phase = ClientState.phase()
	if ClientState.isSpecter() or ClientState.isAway() then
		-- Specters talk among themselves only (in the lobby too, while they wait there hidden).
		local specters = channel(SPECTER_CHANNEL)
		inputBar.Enabled = specters ~= nil
		if specters then
			inputBar.TargetTextChannel = specters
		end
	elseif ClientState.isLiving() and phase ~= "Reveal" and phase ~= "Outro" then
		local meeting = channel(MEETING_CHANNEL)
		if (phase == "Meeting" or phase == "Vote" or phase == "Verdict") and meeting then
			inputBar.TargetTextChannel = meeting
			inputBar.Enabled = true
		else
			inputBar.Enabled = false
		end
	else
		inputBar.Enabled = true
		local general = channel("RBXGeneral")
		if general then
			inputBar.TargetTextChannel = general
		end
	end
end

-- Meeting messages show the speaker's alias instead of their account name.
local function onIncomingMessage(message: TextChatMessage)
	local source = message.TextSource
	local textChannel = message.TextChannel
	if not source or not textChannel then
		return nil
	end
	local specters = textChannel.Name == SPECTER_CHANNEL
	if textChannel.Name ~= MEETING_CHANNEL and not specters then
		return nil
	end
	local alias = ClientState.aliasOf(source.UserId)
	if not alias then
		return nil
	end
	local properties = Instance.new("TextChatMessageProperties")
	properties.PrefixText = if specters
		then string.format('<font color="#A3AAB5">[%s] %s:</font>', Terms.NAMES.Specter, alias)
		else string.format('<font color="#F4F5F7">%s:</font>', alias)
	return properties
end

-- Quick-chat phrases appear as a speech bubble and in the chat window.
local function onQuickChat(payload)
	if type(payload) ~= "table" or type(payload.text) ~= "string" then
		return
	end
	local speaker = Players:GetPlayerByUserId(tonumber(payload.userId) or 0)
	local character = if speaker then speaker.Character else nil
	local head = if character then character:FindFirstChild("Head") else nil
	if head then
		pcall(function()
			TextChatService:DisplayBubble(head, payload.text)
		end)
	end
	local system = channel("RBXSystem") or channel("RBXGeneral")
	if system then
		pcall(function()
			local tag = if payload.specter then "[" .. Terms.NAMES.Specter .. "]" else "[Quick]"
			system:DisplaySystemMessage(string.format("%s %s: %s", tag, tostring(payload.name), payload.text))
		end)
	end
end

-- The chat window, the input bar and the speech bubbles in the Notch style: near-black panels, white
-- Montserrat text. The layout stays Roblox's (on phones the window stays where thumbs are not). Each
-- property is set on its own and guarded, so one a Studio version lacks cannot stop the rest.
local function setProps(config: Instance?, props: { [string]: any })
	if not config then
		return
	end
	for name, value in pairs(props) do
		pcall(function()
			(config :: any)[name] = value
		end)
	end
end

local function styleChat()
	local font = Kit.Tokens.font.body
	local C = Kit.color
	local phone = Kit.Layout.isPhone()
	setProps(TextChatService:FindFirstChildOfClass("ChatWindowConfiguration"), {
		FontFace = font,
		TextSize = if phone then 13 else 15,
		TextColor3 = C.white,
		TextStrokeTransparency = 1,
		BackgroundColor3 = C.g0,
		BackgroundTransparency = 0.25,
		HeightScale = if phone then 0.4 else 0.3,
		WidthScale = if phone then 0.5 else 0.32,
		-- Bottom left on a desktop, where the thumbs are not; top left on a phone, Roblox's default.
		VerticalAlignment = if phone then Enum.VerticalAlignment.Top else Enum.VerticalAlignment.Bottom,
	})
	setProps(TextChatService:FindFirstChildOfClass("ChatInputBarConfiguration"), {
		FontFace = font,
		TextSize = 15,
		TextColor3 = C.white,
		PlaceholderColor3 = C.g5,
		TextStrokeTransparency = 1,
		BackgroundColor3 = C.g0,
		BackgroundTransparency = 0.2,
	})
	setProps(TextChatService:FindFirstChildOfClass("BubbleChatConfiguration"), {
		FontFace = Kit.Tokens.font.bodyBold,
		TextSize = 16,
		TextColor3 = C.white,
		BackgroundColor3 = C.g0,
		BackgroundTransparency = 0.1,
	})
end

function ChatController.init()
	styleChat()
	TextChatService.ChildAdded:Connect(function()
		task.defer(styleChat)
	end)
	if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		TextChatService.OnIncomingMessage = onIncomingMessage
	end
	ClientState.PublicChanged:Connect(update)
	ClientState.PrivateChanged:Connect(update)
	LobbyChrome.Changed:Connect(update)
	Net.event("QuickChatMsg").OnClientEvent:Connect(onQuickChat)
	task.spawn(function()
		-- Channels are created by the server shortly after start.
		local folder = TextChatService:WaitForChild("TextChannels", 30)
		if folder then
			folder.ChildAdded:Connect(update)
		end
		update()
	end)
end

return ChatController
