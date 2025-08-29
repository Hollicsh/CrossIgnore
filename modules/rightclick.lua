local addonName, addonTable = ...
local L = addonTable.L

local function CreateStyledMenuFrame(name)
    local frame = CreateFrame("Frame", name, UIParent, "UIDropDownMenuTemplate")
    frame:SetFrameStrata("TOOLTIP")
    frame:Hide()
    return frame
end

local function ShowStyledDropdown(menuFrame, items, anchorFrame)
    local function initialize(self, level)
        if not level then return end
        for _, item in ipairs(items) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = item.text
            info.func = item.func
            info.notCheckable = true
            UIDropDownMenu_AddButton(info, level)
        end
    end

    UIDropDownMenu_Initialize(menuFrame, initialize, "MENU")
    ToggleDropDownMenu(1, nil, menuFrame, anchorFrame, 0, 0)
end

CrossIgnorePlayerDropdown = CreateStyledMenuFrame("CrossIgnorePlayerDropdown")
CrossIgnoreFilterDropdown = CreateStyledMenuFrame("CrossIgnoreFilterDropdown")

function CrossIgnore:ShowContextMenu(anchorFrame, playerData)
    local menuItems = {
        {
            text = L["EDIT_NOTE"],
            func = function()
                StaticPopup_Show("CROSSIGNORE_EDIT_NOTE", playerData.name or "Unknown", nil, playerData)
            end
        },
        {
            text = L["SET_EXPIRY"],
            func = function()
                StaticPopup_Show("CROSSIGNORE_SET_EXPIRE", playerData.name or "Unknown", nil, playerData)
            end
        },
        {
            text = L["REMOVE_ENTRY"],
            func = function()
                local fullName = playerData.name .. (playerData.server and playerData.server ~= "" and ("-" .. playerData.server) or "")
                CrossIgnore:DelIgnore(fullName)
                CrossIgnore:RefreshBlockedList()
            end
        },
        { text = L["CANCEL"], func = function() end }
    }

    ShowStyledDropdown(CrossIgnorePlayerDropdown, menuItems, anchorFrame)
end

function CrossIgnore:ShowWordContextMenu(anchorFrame, entry)
    local menuItems = {
        {
            text = L["EDIT_WORD"],
            func = function()
                StaticPopup_Show("CROSSIGNORE_EDIT_WORD", entry.word or "Unknown", nil, entry)
            end
        },
        {
            text = L["REMOVE_WORD"],
            func = function()
                CrossIgnore:RemoveSelectedWord(entry)
            end
        },
        { text = L["CANCEL"], func = function() end }
    }

    ShowStyledDropdown(CrossIgnoreFilterDropdown, menuItems, anchorFrame)
end

StaticPopupDialogs["CROSSIGNORE_SET_EXPIRE"] = {
    text = L["SET_EXPIRATION"],
    button1 = L["SET"],
    button2 = L["CANCEL"],
    hasEditBox = true,
    OnShow = function(self)
        local editBox = self.editBox or _G[self:GetName().."EditBox"]
        if editBox then
            editBox:SetText("7")
            editBox:SetFocus()
        end
    end,
    OnAccept = function(self)
        local editBox = self.editBox or _G[self:GetName().."EditBox"]
        local days = tonumber(editBox and editBox:GetText() or "")
        if not days or days < 0 then return end

        local expiresAt = time() + (days * 86400)
        local targetName = self.data.name
        local targetServer = self.data.server

        local entry = {
            name = targetName,
            server = targetServer,
            expires = expiresAt,
            lastModifiedExpires = time(),
        }

        CrossIgnore:EnsureGlobalPresence(entry, CrossIgnore.charDB.profile.settings.maxIgnoreLimit or 50)
        CrossIgnore:SyncLocalToGlobal()
        CrossIgnore:RefreshBlockedList()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = STATICPOPUP_NUMDIALOGS,
}

StaticPopupDialogs["CROSSIGNORE_EDIT_WORD"] = {
    text = L["EDIT_BLOCKED_WORD"],
    button1 = L["SAVE"],
    button2 = L["CANCEL"],
    hasEditBox = true,
    OnShow = function(self)
        local editBox = self.editBox or _G[self:GetName().."EditBox"]
        if editBox then
            editBox:SetText(self.data and self.data.word or "")
            editBox:SetFocus()
        end
    end,
    OnAccept = function(self)
        local editBox = self.editBox or _G[self:GetName().."EditBox"]
        local newWord = editBox and editBox:GetText() or ""
        if newWord == "" then return end

        local targetChannel = self.data.channelName
        local targetIndex   = self.data.wordIndex

        if CrossIgnoreDB and CrossIgnoreDB.global and CrossIgnoreDB.global.filters then
            local wordsTable = CrossIgnoreDB.global.filters.words or {}
            CrossIgnoreDB.global.filters.words = wordsTable

            local channelTable = wordsTable[targetChannel]
            if channelTable and channelTable[targetIndex] then
                channelTable[targetIndex] = {
                    word       = newWord,
                    normalized = newWord:lower(),
                }
            end
        end

        self.data.word = newWord

        CrossIgnore:UpdateWordsList(_G.CrossIgnoreUI.searchBox:GetText() or "")
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = STATICPOPUP_NUMDIALOGS,
}

StaticPopupDialogs["CROSSIGNORE_EDIT_NOTE"] = {
    text = L["EDIT_NOTE_FOR"],
    button1 = L["SAVE"],
    button2 = L["CANCEL"],
    hasEditBox = true,
    OnShow = function(self)
        local editBox = self.editBox or _G[self:GetName().."EditBox"]
        if editBox then
            editBox:SetText(self.data and self.data.note or "")
            editBox:SetFocus()
        end
    end,
    OnAccept = function(self)
        local editBox = self.editBox or _G[self:GetName().."EditBox"]
        local newNote = editBox and editBox:GetText() or ""
        local targetName = self.data.name
        local targetServer = self.data.server

        local function updateNoteInList(list)
            for _, entry in ipairs(list) do
                if entry.name == targetName and entry.server == targetServer then
                    entry.note = newNote
                    entry.lastModifiedNote = time()
                end
            end
        end

        updateNoteInList(CrossIgnore.charDB.profile.players or {})
        updateNoteInList(CrossIgnore.charDB.profile.overLimitPlayers or {})
        updateNoteInList(CrossIgnore.globalDB.global.players or {})
        updateNoteInList(CrossIgnore.globalDB.global.overLimitPlayers or {})

        CrossIgnore:RefreshBlockedList()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = STATICPOPUP_NUMDIALOGS,
}


function CrossIgnore:RemoveSelectedWord(entry)
    if not entry then return end

    local word = entry.word or entry.normalized
    if not word or word == "" then return end

    local channel = entry.channel or entry.channelName or L["CHANNEL_ALL"]
    if self.ChatFilter and self.ChatFilter.NormalizeChannelKey then
        channel = self.ChatFilter:NormalizeChannelKey(channel)
    end

    if self.ChatFilter then
        self.ChatFilter:RemoveWord(word, channel)
    end

    self:UpdateWordsList(_G.CrossIgnoreUI and _G.CrossIgnoreUI.searchBox:GetText() or "")
end
