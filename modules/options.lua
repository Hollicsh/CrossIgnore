local addonName, addonTable = ...
local L = addonTable.L

function CrossIgnore:CreateOptionsUI(parent)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    label:SetPoint("TOP", 0, -12)
    label:SetText(L["CI_OPTIONS"])

    -- LFG Auto Block
    local lfgLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lfgLabel:SetPoint("TOPLEFT", 10, -50)
    lfgLabel:SetText(L["LFG_AUTO_BLOCK"])

    local lfgCheckbox = CreateFrame("CheckButton", "CrossIgnoreLFGBlockCheckbox", parent, "ChatConfigCheckButtonTemplate")
    lfgCheckbox:SetPoint("LEFT", lfgLabel, "RIGHT", 10, 0)
    lfgCheckbox:SetChecked(CrossIgnore.charDB.profile.settings.LFGBlock)
    lfgCheckbox:SetScript("OnClick", function(button)
        local value = button:GetChecked()
        CrossIgnore.charDB.profile.settings.LFGBlock = value
        print("LFG Block " .. (value and "enabled" or "disabled"))
    end)

    lfgCheckbox:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["AUTOMATICALLY_BLOCK_LEADER_OF_THE_GROUP"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    lfgCheckbox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Default Expire Days
    local expireLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    expireLabel:SetPoint("TOPLEFT", lfgLabel, "BOTTOMLEFT", 0, -30)
    expireLabel:SetText(L["DEFAULT_EXPIRE_LABEL"])

    local expireBox = CreateFrame("EditBox", "CrossIgnoreDefaultExpireBox", parent, "InputBoxTemplate")
    expireBox:SetSize(50, 20)
    expireBox:SetPoint("LEFT", expireLabel, "RIGHT", 10, 0)
    expireBox:SetAutoFocus(false)
    expireBox:SetNumeric(true)

    local defaultDays = CrossIgnore.charDB.profile.settings.defaultExpireDays or 0
    expireBox:SetText(tostring(defaultDays))

    local expireOkayBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    expireOkayBtn:SetSize(60, 22)
    expireOkayBtn:SetPoint("LEFT", expireBox, "RIGHT", 10, 0)
    expireOkayBtn:SetText(OKAY)

    expireOkayBtn:SetScript("OnClick", function()
        local days = tonumber(expireBox:GetText()) or 0
        if days < 0 then days = 0 end
        CrossIgnore.charDB.profile.settings.defaultExpireDays = days
        print(L["DEFAULT_EXPIRE_SET"]:format((days == 0 and L["NEVER"] or days)))
    end)

    -- ========================
    -- Auto Reply Section
    -- ========================
    local autoReplyLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    autoReplyLabel:SetPoint("TOPLEFT", expireLabel, "BOTTOMLEFT", 0, -40)
    autoReplyLabel:SetText(L["AUTO_REPLY_ENABLE_CHECK"])

    local autoReplyCheckbox = CreateFrame("CheckButton", "CrossIgnoreAutoReplyCheckbox", parent, "ChatConfigCheckButtonTemplate")
    autoReplyCheckbox:SetPoint("LEFT", autoReplyLabel, "RIGHT", 10, 0)
    autoReplyCheckbox:SetChecked(CrossIgnore.charDB.profile.settings.autoReplyEnabled or false)
    autoReplyCheckbox:SetScript("OnClick", function(button)
        local value = button:GetChecked()
        CrossIgnore.charDB.profile.settings.autoReplyEnabled = value
    end)

    local autoReplyBox = CreateFrame("EditBox", "CrossIgnoreAutoReplyBox", parent, "InputBoxTemplate")
    autoReplyBox:SetSize(300, 40)
    autoReplyBox:SetPoint("TOPLEFT", autoReplyLabel, "BOTTOMLEFT", 0, -10)
    autoReplyBox:SetAutoFocus(false)
    autoReplyBox:SetMultiLine(true)
    autoReplyBox:SetText(CrossIgnore.charDB.profile.settings.autoReplyMessage)

    local autoReplyOkayBtn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    autoReplyOkayBtn:SetSize(60, 22)
    autoReplyOkayBtn:SetPoint("LEFT", autoReplyBox, "RIGHT", 10, 0)
    autoReplyOkayBtn:SetText(OKAY)

    autoReplyOkayBtn:SetScript("OnClick", function()
        local msg = autoReplyBox:GetText()
        CrossIgnore.charDB.profile.settings.autoReplyMessage = msg
    end)
end

