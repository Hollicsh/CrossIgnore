local addonName, addonTable = ...
local L = addonTable.L

local function CreateStyledMenuFrame()
    local frame = CreateFrame("Frame", nil, UIParent, "UIDropDownMenuTemplate")
    frame:SetFrameStrata("TOOLTIP")
    frame:Hide()
    return frame
end

local function ShowStyledDropdown(items, anchorFrame)
    local menuFrame = CreateStyledMenuFrame()

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

local function CreateCustomPopup(title, defaultText, onAccept)
    local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    frame:SetSize(300, 100)
    frame:SetPoint("CENTER")
    frame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left=4, right=4, top=4, bottom=4 }
    })
    frame:SetBackdropColor(0,0,0,0.8)
    frame:Hide()
    frame:SetFrameStrata("DIALOG")

    local titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("TOP", 0, -10)
    titleText:SetText(title)

    local editBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    editBox:SetSize(260, 25)
    editBox:SetPoint("TOP", titleText, "BOTTOM", 0, -10)
    editBox:SetAutoFocus(true)
    editBox:SetText(defaultText or "")

    local acceptBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    acceptBtn:SetSize(80, 25)
    acceptBtn:SetPoint("BOTTOMLEFT", 20, 10)
    acceptBtn:SetText("Save")
    acceptBtn:SetScript("OnClick", function()
        if onAccept then onAccept(editBox:GetText()) end
        frame:Hide()
    end)

    local cancelBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    cancelBtn:SetSize(80, 25)
    cancelBtn:SetPoint("BOTTOMRIGHT", -20, 10)
    cancelBtn:SetText("Cancel")
    cancelBtn:SetScript("OnClick", function()
        frame:Hide()
    end)

    return frame, editBox
end

function CrossIgnore:ShowSetExpiryPopup(entry)
    if not entry then return end

    local defaultDays = CrossIgnore.charDB
        and CrossIgnore.charDB.profile
        and CrossIgnore.charDB.profile.settings.defaultExpireDays
        or 0

    local popup, editBox = CreateCustomPopup(
        L["SET_EXPIRATION"],
        tostring(defaultDays),
        function(daysText)
            local days = tonumber(daysText)
            if not days or days < 0 then return end

            local expiresAt = (days > 0) and (time() + (days * 86400)) or 0

            local newEntry = {
                name                = entry.name,
                server              = entry.server,
                expires             = expiresAt,
                lastModifiedExpires = time(),
            }

            CrossIgnore:EnsureGlobalPresence(newEntry, CrossIgnore.charDB.profile.settings.maxIgnoreLimit or 50)
            CrossIgnore:SyncLocalToGlobal()
            CrossIgnore:RefreshBlockedList()

            print(L["PLAYER_EXPIRE_SET"]:format(entry.name, (days == 0 and L["NEVER"] or days)))
        end
    )

    popup:Show()
    editBox:SetFocus()
end


function CrossIgnore:ShowContextMenu(anchorFrame, playerData)
    local menuItems = {
        {
            text = L["EDIT_NOTE"],
            func = function()
                self:ShowEditNotePopup(playerData)
            end
        },
        {
            text = L["SET_EXPIRY"],
            func = function()
                self:ShowSetExpiryPopup(playerData)
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

    ShowStyledDropdown(menuItems, anchorFrame)
end

function CrossIgnore:ShowWordContextMenu(anchorFrame, entry)
    local menuItems = {
        {
            text = L["EDIT_WORD"],
            func = function()
                self:ShowEditWordPopup(entry)
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

    ShowStyledDropdown(menuItems, anchorFrame)
end

function CrossIgnore:ShowEditWordPopup(entry)
    if not entry then return end
    local popup, editBox = CreateCustomPopup(
        L["EDIT_BLOCKED_WORD"],
        entry.word or "",
        function(newWord)
            if newWord == "" then return end
            entry.word = newWord
            entry.normalized = newWord:lower()
            self:UpdateWordsList(_G.CrossIgnoreUI.searchBox:GetText() or "")
            refreshLeftPanel()
        end
    )
    popup:Show()
    editBox:SetFocus()
end

function CrossIgnore:ShowEditNotePopup(entry)
    if not entry then return end

    local title = string.format(L["EDIT_NOTE_FOR"], entry.name or "Unknown")

    local popup, editBox = CreateCustomPopup(
        title,
        entry.note or "",
        function(newNote)
            entry.note = newNote
            entry.lastModifiedNote = time()
            self:RefreshBlockedList()
        end
    )

    popup:Show()
    editBox:SetFocus()
end


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
    refreshLeftPanel()
end
