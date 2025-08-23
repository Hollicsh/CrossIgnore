function CrossIgnore:CreateOptionsUI(parent)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    label:SetPoint("TOPLEFT", 10, -10)
    label:SetText("CrossIgnore Options")

    local lfgLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lfgLabel:SetPoint("TOPLEFT", 10, -50)
    lfgLabel:SetText("Enable LFG Auto Block")

    local lfgCheckbox = CreateFrame("CheckButton", "CrossIgnoreLFGBlockCheckbox", parent, "ChatConfigCheckButtonTemplate")
    lfgCheckbox:SetPoint("LEFT", lfgLabel, "RIGHT", 10, 0)
    lfgCheckbox:SetChecked(CrossIgnore.charDB.profile.settings.LFGBlock)
    lfgCheckbox:SetScript("OnClick", function(button)
        local value = button:GetChecked()
        CrossIgnore.charDB.profile.settings.LFGBlock = value
        print("LFG Block " .. (value and "enabled" or "disabled"))
    end)
end
