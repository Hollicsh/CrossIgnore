local BlockHandler = {}

local BLOCK_CHAT_EVENTS = {
    "CHAT_MSG_WHISPER",
    "CHAT_MSG_WHISPER_INFORM",
    "CHAT_MSG_BN_WHISPER",
    "CHAT_MSG_BN_WHISPER_INFORM",
}

local BLOCK_MISC_EVENTS = {
    "TRADE_SHOW",
    "DUEL_REQUESTED",
    "PARTY_INVITE_REQUEST",
}

local function IsBlockedPlayer(sender)
    if not sender then return false end
    local fullName = CrossIgnore:NormalizePlayerName(sender)
    return CrossIgnore:IsPlayerBlocked(fullName or sender)
end

local function ChatEventFilter(event, msg, sender, ...)
    if IsBlockedPlayer(sender) then
        return true 
    end
    return false
end

local function HookWhisperFrames()
    if not CrossIgnore.db.profile.settings.forceBlockAllWhispers then return end

    for i = 1, NUM_CHAT_WINDOWS do
        local frame = _G["ChatFrame" .. i]
        if frame and not frame.__CrossIgnoreHooked then
            frame.__CrossIgnoreHooked = true
            hooksecurefunc(frame, "AddMessage", function(self, text, ...)
                if type(text) == "string" then
                    local name = text:match("|Hplayer:([^:]+)")
                    if name and IsBlockedPlayer(name) then
                        self:Clear() 
                        return
                    end
                end
            end)
        end
    end
end

local function BlockEventFrameHandler(self, event, ...)
    local name = UnitName("npc") or UnitName("target") or UnitName("mouseover")
    if name and IsBlockedPlayer(name) then
        CrossIgnore:Print("Blocked " .. event .. " from ignored player: " .. name)

        if event == "TRADE_SHOW" then CancelTrade() end
        if event == "DUEL_REQUESTED" then CancelDuel() end
        if event == "PARTY_INVITE_REQUEST" then DeclineGroup() StaticPopup_Hide("PARTY_INVITE") end
    end
end

function BlockHandler:Register()
    for _, event in ipairs(BLOCK_CHAT_EVENTS) do
        ChatFrame_AddMessageEventFilter(event, ChatEventFilter)
    end

    local frame = CreateFrame("Frame")
    for _, event in ipairs(BLOCK_MISC_EVENTS) do
        frame:RegisterEvent(event)
    end
    frame:SetScript("OnEvent", BlockEventFrameHandler)

    HookWhisperFrames()

local whisperFrame = CreateFrame("Frame")
whisperFrame:RegisterEvent("CHAT_MSG_WHISPER")
whisperFrame:RegisterEvent("CHAT_MSG_BN_WHISPER")
whisperFrame:SetScript("OnEvent", function(_, event, msg, sender, ...)
    if CrossIgnore.charDB.profile.settings.autoReplyEnabled and IsBlockedPlayer(sender) then
        local replyMsg = CrossIgnore.charDB.profile.settings.autoReplyMessage

        if event == "CHAT_MSG_WHISPER" then
            SendChatMessage(replyMsg, "WHISPER", nil, sender)
        elseif event == "CHAT_MSG_BN_WHISPER" then
            local bnetIDAccount = select(13, ...)
            if bnetIDAccount then
                BNSendWhisper(bnetIDAccount, replyMsg)
            end
        end
    end
end)

end



function BlockHandler:Initialize()
    local settings = CrossIgnore.db.profile.settings
    if settings.forceBlockAllWhispers == nil then
        settings.forceBlockAllWhispers = true
    end
end

CrossIgnore.BlockHandler = BlockHandler
