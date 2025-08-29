local addonName, addonTable = ...
local L = addonTable.L

local CrossIgnoreUI = nil
local selectedPlayer = nil
local selectedWord = nil

local function CreateLabel(parent, text, anchor, x, y, font)
    local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
    label:SetPoint(anchor, x, y)
    label:SetText(text)
    return label
end

local function CreateButton(parent, text, anchor, x, y, width, height, onClick)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(width, height)
    btn:SetPoint(anchor, x, y)
    btn:SetText(text)
    if onClick then
        btn:SetScript("OnClick", onClick)
    end
    return btn
end

local function CreateEditBox(parent, width, height, anchor, x, y)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(width, height)
    box:SetPoint(anchor, x, y)
    box:SetAutoFocus(false)
    box:SetText("")
    return box
end

local function CreateScrollFrame(parent, width, height, anchor, x, y)
    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(width, height)
    scrollFrame:SetPoint(anchor, x, y)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(width, height)
    scrollFrame:SetScrollChild(scrollChild)

    return scrollFrame, scrollChild
end

local function FormatElapsedTime(added)
    local tsNum = tonumber(added)
    if not tsNum or tsNum == 0 then
        return L["NA_TEXT"]
    end

    local elapsed = time() - tsNum
    if elapsed < 0 then elapsed = 0 end

    local days = math.floor(elapsed / 86400)
    local hours = math.floor((elapsed % 86400) / 3600)
    local minutes = math.floor((elapsed % 3600) / 60)

    if days > 0 then
        if hours > 0 then
            return string.format("%dd %dh", days, hours)
        else
            return string.format("%dd", days)
        end
    elseif hours > 0 then
        return string.format("%dh %dm", hours, minutes)
    elseif minutes > 0 then
        return string.format("%dm", minutes)
    else
        return L["TIME_HEADER"]
    end
end

local function FormatExpiresTime(expires)
    local tsNum = tonumber(expires)
    if not tsNum or tsNum == 0 then
        return L["TIME_HEADER2"]
    end

    local remaining = tsNum - time()
    if remaining <= 0 then
        return L["TIME_HEADER3"]
    end

    local days = math.floor(remaining / 86400)
    local hours = math.floor((remaining % 86400) / 3600)
    local minutes = math.floor((remaining % 3600) / 60)

    if days > 0 then
        return string.format("%dd %dh", days, hours)
    elseif hours > 0 then
        return string.format("%dh %dm", hours, minutes)
    elseif minutes > 0 then
        return string.format("%dm", minutes)
    else
        return L["TIME_HEADER4"]
    end
end

local playerColumnMap = {
    [L["PLAYER_NAME_HEADER"]] = "name",
    [L["SERVER_HEADER"]] = "server",
    [L["NOTE_HEADER"]] = "note",
    [L["ADDED_HEADER"]] = "added",
    [L["EXPIRES_HEADER"]] = "expires",
}

local playerSortKey = "name" 
local playerSortAsc = true

CrossIgnore.playerList = CrossIgnore.playerList or {}

function CrossIgnore:RefreshBlockedList(filterText)
    filterText = filterText or ""

    local players, overLimitPlayers = self:GetActivePlayerTables()

    if not _G.CrossIgnoreUI or not _G.CrossIgnoreUI:IsShown() then return end
    local UI = _G.CrossIgnoreUI
    local scrollChild = UI.scrollChild
    if not scrollChild then return end

    UI.rowPool = UI.rowPool or {}
    UI.activeRows = UI.activeRows or {}

    for _, row in ipairs(UI.activeRows) do
        for i = 1, #row.cols do
            row.cols[i]:SetText("")
        end
        row:Hide()
        table.insert(UI.rowPool, row)
    end
    wipe(UI.activeRows)

    local playerList = self.playerList
    wipe(playerList)

    local function addFiltered(src)
        for _, data in ipairs(src or {}) do
            local name = data.name or ""
            if filterText == "" or name:lower():find(filterText:lower()) then
                playerList[#playerList + 1] = data
            end
        end
    end
    addFiltered(players)
    addFiltered(overLimitPlayers)

    local sortKey = playerSortKey or "name"
    table.sort(playerList, function(a, b)
        local valA, valB = a[sortKey] or "", b[sortKey] or ""
        if sortKey == "added" or sortKey == "expires" then
            valA, valB = tonumber(valA) or 0, tonumber(valB) or 0
        else
            valA, valB = tostring(valA):lower(), tostring(valB):lower()
        end
        if playerSortAsc then
            return valA < valB
        else
            return valA > valB
        end
    end)

    if self.counterLabel then
        self.counterLabel:SetText(string.format(L["TOTAL_BLOCKED"], #playerList))
    end

    if not UI.header then
        local headerTitles = { L["PLAYER_NAME_HEADER"], L["SERVER_HEADER"], L["ADDED_HEADER"], L["EXPIRES_HEADER"], L["NOTE_HEADER"] }
        local colWidths    = { 60, 100, 90, 80, 70 }
        local xPos = 0

        UI.header = CreateFrame("Frame", nil, scrollChild)
        UI.header:SetSize(500, 20)
        UI.header.bg = UI.header:CreateTexture(nil, "BACKGROUND")
        UI.header.bg:SetAllPoints()
        UI.header.bg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
        UI.header.cols = {}

        for i, title in ipairs(headerTitles) do
            local btn = CreateFrame("Button", nil, UI.header)
            btn:SetSize(colWidths[i], 20)
            btn:SetPoint("LEFT", xPos, 0)

            local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            fs:SetPoint("CENTER")
            fs:SetText(title)
            btn.text = fs

            btn:SetScript("OnEnter", function()
                btn.text:SetTextColor(1, 1, 0)
            end)
            btn:SetScript("OnLeave", function()
                btn.text:SetTextColor(1, 1, 1)
            end)
            btn:SetScript("OnClick", function()
                local mapped = playerColumnMap[title] or "name"
                if playerSortKey == mapped then
                    playerSortAsc = not playerSortAsc
                else
                    playerSortKey = mapped
                    playerSortAsc = true
                end
                CrossIgnore:RefreshBlockedList(filterText)
            end)

            UI.header.cols[i] = btn
            xPos = xPos + colWidths[i]
        end

        UI.header:SetPoint("TOPLEFT", 0, -5)
    end
    UI.header:Show()

    local yOffset = -25
    local colWidths = { 90, 100, 80, 80, 150 }

    for idx, playerData in ipairs(playerList) do
        local row
        if #UI.rowPool > 0 then
            row = table.remove(UI.rowPool)
        else
            row = CreateFrame("Button", nil, scrollChild)
            row:SetSize(500, 20)
            row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints()

            local xPos = 0
            row.cols = {}
            for i = 1, 5 do
                local fs = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                fs:SetPoint("LEFT", xPos + 5, 0)
                fs:SetWidth(colWidths[i] - 10)
                fs:SetJustifyH("LEFT")
                if i == 5 then
                    fs:SetWordWrap(false)      
                    fs:SetNonSpaceWrap(false)   
                    fs:SetMaxLines(1)           
                end
                row.cols[i] = fs
                xPos = xPos + colWidths[i]
            end

            row:SetScript("OnEnter", function(self)
                self.bg:SetColorTexture(0.3, 0.3, 0.3, 0.8)
            end)
            row:SetScript("OnLeave", function(self)
                if CrossIgnore.selectedRow == self then
                    self.bg:SetColorTexture(0.4, 0.4, 0.4, 0.8)
                else
                    local c = self.alt and 0.15 or 0.1
                    self.bg:SetColorTexture(c, c, c, 0.8)
                end
            end)

            row:SetScript("OnClick", function(self, button)
                if button == "LeftButton" then
                    if CrossIgnore.selectedRow and CrossIgnore.selectedRow ~= self then
                        local c = CrossIgnore.selectedRow.alt and 0.15 or 0.1
                        CrossIgnore.selectedRow.bg:SetColorTexture(c, c, c, 0.8)
                    end
                    CrossIgnore.selectedRow = self
                    CrossIgnore.selectedPlayer = self.entry
                    self.bg:SetColorTexture(0.4, 0.4, 0.4, 0.8)

                elseif button == "RightButton" then
                    if CrossIgnore.ShowContextMenu then
                        CrossIgnore:ShowContextMenu(self, self.entry)
                    else
                        print(L["CONTEXT_NOT_LOADED"])
                    end
                end
            end)
        end

        row.entry = playerData

        row.alt = (idx % 2 == 0)
        local c = row.alt and 0.15 or 0.1

        if CrossIgnore.selectedPlayer
           and CrossIgnore.selectedPlayer.name == playerData.name
           and (CrossIgnore.selectedPlayer.server or CrossIgnore.selectedPlayer.realm) == (playerData.server or playerData.realm) then
            CrossIgnore.selectedRow = row
            row.bg:SetColorTexture(0.4, 0.4, 0.4, 0.8)
        else
            row.bg:SetColorTexture(c, c, c, 0.8)
        end

            local serverVal = playerData.server or playerData.realm or ""
            row.cols[1]:SetText(playerData.name or "")
            row.cols[2]:SetText(serverVal)
            row.cols[3]:SetText(FormatElapsedTime(playerData.added))
            row.cols[4]:SetText(FormatExpiresTime(playerData.expires))
            row.cols[5]:SetText(playerData.note or playerData.notes or "")

            local noteText = playerData.note or playerData.notes or ""
            if noteText ~= "" then
                row.cols[5]:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:AddLine(L["NOTE_HEADER"], 1, 1, 1)
                    GameTooltip:AddLine(noteText, nil, nil, nil, true) 
                    GameTooltip:Show()
                end)
                row.cols[5]:SetScript("OnLeave", function()
                    GameTooltip:Hide()
                end)
            else
                row.cols[5]:SetScript("OnEnter", nil)
                row.cols[5]:SetScript("OnLeave", nil)
            end


        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, yOffset)
        row:Show()

        UI.activeRows[#UI.activeRows + 1] = row
        yOffset = yOffset - 20
    end

    scrollChild:SetHeight(math.max(#playerList * 20 + 40, 350))
end

local function RemoveSelectedPlayer()
    if not selectedPlayer and not CrossIgnore.selectedPlayer then
        print(L["NO_PLAYER_SELECTED"])
        return
    end
    local p = selectedPlayer or CrossIgnore.selectedPlayer
    if not p or not p.name then
        print(L["NO_PLAYER_SELECTED"])
        return
    end

    local combined = p.name .. (p.server and p.server ~= "" and ("-" .. p.server) or "")
    local fullName, base, realm = CrossIgnore:NormalizePlayerName(combined)
    CrossIgnore:DelIgnore(fullName)

    selectedPlayer = nil
    if CrossIgnoreUI and CrossIgnoreUI.searchBox then
        CrossIgnore:RefreshBlockedList(CrossIgnoreUI.searchBox:GetText())
    else
        CrossIgnore:RefreshBlockedList()
    end
end

local wordColumnMap = {
    [L["BANNED_WORDS_HEADER2"]] = "word",
    [L["CHAT_TYPE_HEADER"]] = "channel",
    [L["STRICT_BAN_HEADER"]] = "strict",
}
local wordSortKey = "word"
local wordSortAsc = true

function CrossIgnore:UpdateWordsList(searchText)
    searchText = searchText or ""

    local UI = _G.CrossIgnoreUI
    if not UI or not UI.wordsScrollChild or not UI:IsShown() then return end
    local scrollChild = UI.wordsScrollChild

    UI.wordRowPool = UI.wordRowPool or {}
    UI.wordActiveRows = UI.wordActiveRows or {}

    for _, row in ipairs(UI.wordActiveRows) do
        row:Hide()
        table.insert(UI.wordRowPool, row)
    end
    wipe(UI.wordActiveRows)

    if not UI.wordsHeader then
        local headers = { L["BANNED_WORDS_HEADER2"], L["CHAT_TYPE_HEADER"], L["STRICT_BAN_HEADER"] }
        local colWidths = { 180, 140, 80 }
        local xPos = 10

        UI.wordsHeader = CreateFrame("Frame", nil, scrollChild)
        UI.wordsHeader:SetSize(420, 25)
        UI.wordsHeader:SetPoint("TOPLEFT", 0, 0)
        UI.wordsHeader.bg = UI.wordsHeader:CreateTexture(nil, "BACKGROUND")
        UI.wordsHeader.bg:SetAllPoints()
        UI.wordsHeader.bg:SetColorTexture(0.2, 0.2, 0.2, 0.8)

        UI.wordsHeader.cols = {}

        for i, title in ipairs(headers) do
            local btn = CreateFrame("Button", nil, UI.wordsHeader)
            btn:SetSize(colWidths[i], 25)
            btn:SetPoint("LEFT", xPos, 0)

            local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            fs:SetPoint("CENTER")
            fs:SetText(title)
            btn.text = fs

            btn:SetScript("OnEnter", function()
                btn.text:SetTextColor(1, 1, 0)
            end)
            btn:SetScript("OnLeave", function()
                local mapped = wordColumnMap[title]
                if wordSortKey == mapped then
                    btn.text:SetTextColor(1, 1, 0)
                else
                    btn.text:SetTextColor(1, 1, 1)
                end
            end)
            btn:SetScript("OnClick", function()
                local key = wordColumnMap[title]
                if wordSortKey == key then
                    wordSortAsc = not wordSortAsc
                else
                    wordSortKey = key
                    wordSortAsc = true
                end
                CrossIgnore:UpdateWordsList(searchText)
            end)

            UI.wordsHeader.cols[i] = btn
            xPos = xPos + colWidths[i]
        end
    end

    for _, btn in ipairs(UI.wordsHeader.cols) do
        local title = btn.text:GetText()
        if wordColumnMap[title] == wordSortKey then
            btn.text:SetTextColor(1, 1, 0)
        else
            btn.text:SetTextColor(1, 1, 1)
        end
    end
    UI.wordsHeader:Show()

    local filters = CrossIgnoreDB and CrossIgnoreDB.global and CrossIgnoreDB.global.filters and CrossIgnoreDB.global.filters.words or {}
    local combinedWords = {}
    for ch, words in pairs(filters) do
        if type(words) == "table" then
            for idx, w in ipairs(words) do
                if type(w) == "string" then
                    table.insert(combinedWords, { word = w, channel = ch, strict = false, wordIndex = idx, channelName = ch })
                elseif type(w) == "table" and w.word then
                    table.insert(combinedWords, { word = w.word, channel = ch, strict = w.strict or false, wordIndex = idx, channelName = ch })
                end
            end
        end
    end

    local filtered = {}
    local lowerSearch = searchText:lower()
    for _, entry in ipairs(combinedWords) do
        if lowerSearch == "" or (entry.word and entry.word:lower():find(lowerSearch, 1, true)) or (entry.channel and entry.channel:lower():find(lowerSearch, 1, true)) then
            table.insert(filtered, entry)
        end
    end

    table.sort(filtered, function(a, b)
        local valA, valB
        if wordSortKey == "strict" then
            valA = a.strict and 1 or 0
            valB = b.strict and 1 or 0
        else
            valA = tostring(a[wordSortKey] or ""):lower()
            valB = tostring(b[wordSortKey] or ""):lower()
        end
        if wordSortAsc then
            return valA < valB
        else
            return valA > valB
        end
    end)

    local rowHeight = 25
    local yOffset = rowHeight

    local function CreateRow()
        local row = CreateFrame("Button", nil, scrollChild)
        row:SetSize(420, rowHeight)
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp") 

        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()

        row.cols = {}

        row.cols[1] = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.cols[1]:SetPoint("LEFT", 10, 0)
        row.cols[1]:SetWidth(180)
        row.cols[1]:SetJustifyH("LEFT")

        row.cols[2] = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.cols[2]:SetPoint("LEFT", 195, 0)
        row.cols[2]:SetWidth(140)
        row.cols[2]:SetJustifyH("LEFT")

        row.strictCheck = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        row.strictCheck:SetPoint("LEFT", 350, 0)
        row.strictCheck:SetSize(20, 20)
		
		row.strictCheck:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(L["STRICT_BAN_HEADER"], 1, 1, 1)
    GameTooltip:AddLine(L["STRICT_BAN_TOOLTIP_TEXT"], nil, nil, nil, true)
    GameTooltip:Show()
end)
row.strictCheck:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

        row:SetScript("OnClick", function(self, button)
            if button == "LeftButton" then
                if CrossIgnore.selectedWordRow and CrossIgnore.selectedWordRow ~= self then
                    CrossIgnore.selectedWordRow.bg:SetColorTexture(0.1, 0.1, 0.1, 1)
                end
                CrossIgnore.selectedWordRow = self
                CrossIgnore.selectedWord = self.entry
                self.bg:SetColorTexture(0.4, 0.4, 0.4, 1)

            elseif button == "RightButton" then
                if CrossIgnore.ShowWordContextMenu then
                    CrossIgnore:ShowWordContextMenu(self, self.entry)
                else
                    print(L["WORD_CONTEXT_NOT_LOADED"])
                end
            end
        end)

        row.strictCheck:SetScript("OnClick", function(self)
            local newVal = self:GetChecked()
            local entry = row.entry
            if entry and CrossIgnoreDB and CrossIgnoreDB.global and CrossIgnoreDB.global.filters and CrossIgnoreDB.global.filters.words then
                local channelTable = CrossIgnoreDB.global.filters.words[entry.channelName]
                if channelTable and channelTable[entry.wordIndex] then
                    if type(channelTable[entry.wordIndex]) == "table" then
                        channelTable[entry.wordIndex].strict = newVal
                    else
                        channelTable[entry.wordIndex] = {
                            word = channelTable[entry.wordIndex],
                            normalized = tostring(channelTable[entry.wordIndex]):lower(),
                            strict = newVal
                        }
                    end
                end
            end
            row.entry.strict = newVal
            CrossIgnore.ChatFilter:SetWordStrict(entry.word, entry.channelName, newVal)
        end)

        row:SetScript("OnEnter", function(self)
            self.bg:SetColorTexture(0.3, 0.3, 0.3, 1)
        end)
        row:SetScript("OnLeave", function(self)
            if CrossIgnore.selectedWordRow == self then
                self.bg:SetColorTexture(0.4, 0.4, 0.4, 1)
            else
                self.bg:SetColorTexture(0.1, 0.1, 0.1, 1)
            end
        end)

        return row
    end

    for i, entry in ipairs(filtered) do
			local row = table.remove(UI.wordRowPool) or CreateRow()
		
			local function CapitalizeWords(str)
		return (str:gsub("(%a)([%w_']*)", function(first, rest)
			return first:upper() .. rest:lower()
		end))
	end

        row.cols[1]:SetText(entry.word)
        row.cols[2]:SetText(CapitalizeWords(entry.channel))

        row.strictCheck:SetChecked(entry.strict)

        row.entry = entry

        if CrossIgnore.selectedWord
           and CrossIgnore.selectedWord.word == entry.word
           and CrossIgnore.selectedWord.channel == entry.channel then
            CrossIgnore.selectedWordRow = row
            row.bg:SetColorTexture(0.4, 0.4, 0.4, 1)
        else
            row.bg:SetColorTexture(0.1, 0.1, 0.1, 1)
        end

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -yOffset)
        row:Show()

        UI.wordActiveRows[#UI.wordActiveRows + 1] = row
        yOffset = yOffset + rowHeight
    end

    scrollChild:SetHeight(math.max(yOffset + 10, 350))
end

local function AddNewWord()
    local input = CrossIgnoreUI.newWordInput
    local word = input:GetText()
    if word == "" then return end

    local channel = CrossIgnoreDB.selectedChannel or "all channels"
    local strict = CrossIgnoreUI.strictCheckBox and CrossIgnoreUI.strictCheckBox:GetChecked()

    channel = CrossIgnore.ChatFilter:NormalizeChannelKey(channel):lower()
    CrossIgnore.ChatFilter:AddWord(word, channel, strict)
    CrossIgnore:UpdateWordsList()
    input:SetText("")
end




local function UpdateChannelDropdown()
    local channelList = {
        L["CHANNEL_ALL"],
        L["CHANNEL_SAY"], L["CHANNEL_YELL"], L["CHANNEL_WHISPER"],
        L["CHANNEL_GUILD"], L["CHANNEL_OFFICER"],
        L["CHANNEL_PARTY"], L["CHANNEL_RAID"], L["CHANNEL_INSTANCE"],
    }

    local channels = { GetChannelList() }
    local seen = {}

    for i = 1, #channels, 3 do
        local channelName = channels[i+1]
        if channelName then
            local clean = channelName:gsub("^%d+%.%s*", "") 
            if not seen[clean:lower()] then
                table.insert(channelList, clean)
                seen[clean:lower()] = true
            end
        end
    end

    return channelList
end



local function RemoveSelectedWord()
    local sw = CrossIgnore.selectedWord
    if not sw then return end

    local channel = sw.channel or L["CHANNEL_ALL"]

    if CrossIgnore and CrossIgnore.ChatFilter and CrossIgnore.ChatFilter.NormalizeChannelKey then
        channel = CrossIgnore.ChatFilter:NormalizeChannelKey(channel)
    end

    CrossIgnore.ChatFilter:RemoveWord(sw.word, channel)

    CrossIgnore.selectedWord = nil
    CrossIgnore:UpdateWordsList()
end

local function UpdateChannelDropdown()
    local channelList = {
        L["CHANNEL_ALL"],
        L["CHANNEL_SAY"], L["CHANNEL_YELL"], L["CHANNEL_WHISPER"],
        L["CHANNEL_GUILD"], L["CHANNEL_OFFICER"],
        L["CHANNEL_PARTY"], L["CHANNEL_RAID"], L["CHANNEL_INSTANCE"],
    }

    local channels = { GetChannelList() }
    local seen = {}

    for i = 1, #channels, 3 do
        local channelNumber = channels[i]
        if channelNumber then
            local name, displayName = GetChannelName(channelNumber)

            local finalName = (type(name) == "string" and name) or displayName

            if finalName then
                local clean = finalName:gsub("^%d+%.%s*", "") 
                if not seen[clean:lower()] then
                    table.insert(channelList, clean)
                    seen[clean:lower()] = true
                end
            end
        end
    end

    return channelList
end


local function CreateChannelDropdown(parent)
    local dropdown = CreateFrame("Frame", "CrossIgnoreChannelDropdown", parent, "UIDropDownMenuTemplate")
    dropdown:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 10, 40)

    UIDropDownMenu_SetWidth(dropdown, 200)

    local function OnClick(self)
        CrossIgnoreDB.selectedChannel = self.value
        UIDropDownMenu_SetSelectedValue(dropdown, self.value)
        UIDropDownMenu_SetText(dropdown, self.value)

        ToggleDropDownMenu(1, nil, dropdown)
        ToggleDropDownMenu(1, nil, dropdown)
        CrossIgnore:UpdateWordsList()
    end

    UIDropDownMenu_Initialize(dropdown, function(self, level, menuList)
        if level ~= 1 then return end 

        local channels = UpdateChannelDropdown() 
        local selectedChannel = CrossIgnoreDB.selectedChannel or L["CHANNEL_ALL"]

        for _, channel in ipairs(channels) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = channel
            info.value = channel
            info.func = OnClick
            info.checked = (channel == selectedChannel)
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    UIDropDownMenu_SetSelectedValue(dropdown, CrossIgnoreDB.selectedChannel or L["CHANNEL_ALL"])
    UIDropDownMenu_SetText(dropdown, CrossIgnoreDB.selectedChannel or L["CHANNEL_ALL"])

    return dropdown
end

function CrossIgnore:CreateUI()
    if CrossIgnoreUI then return end

    StaticPopupDialogs = StaticPopupDialogs or {}
    StaticPopupDialogs["CROSSIGNORE_CONFIRM_REMOVE_ALL_WORDS"] = {
        text = L["REMOVE_ALL_CONFIRM"],
        button1 = L["YES_BUTTON"],
        button2 = L["NO_BUTTON"],
        OnAccept = function()
            if CrossIgnoreDB and CrossIgnoreDB.global and CrossIgnoreDB.global.filters then
                CrossIgnoreDB.global.filters.words = {}
				CrossIgnoreDB.global.filters.removedDefaults = true
            end
            print(L["REMOVE_ALL_DONE"])
            CrossIgnore:UpdateWordsList()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }

    CrossIgnoreUI = CreateFrame("Frame", "CrossIgnoreUI", UIParent, "BackdropTemplate")
    CrossIgnoreUI:SetSize(630, 520)
    CrossIgnoreUI:SetPoint("CENTER")
    CrossIgnoreUI:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    CrossIgnoreUI:SetMovable(true)
    CrossIgnoreUI:EnableMouse(true)
    CrossIgnoreUI:RegisterForDrag("LeftButton")
    CrossIgnoreUI:SetScript("OnDragStart", CrossIgnoreUI.StartMoving)
    CrossIgnoreUI:SetScript("OnDragStop", CrossIgnoreUI.StopMovingOrSizing)

    local title = CreateLabel(CrossIgnoreUI, L["TITLE_HEADER"], "TOP", 0, -12, "GameFontHighlightLarge")

    local closeButton = CreateButton(CrossIgnoreUI, L["CLOSE_BUTTON"], "TOPRIGHT", -10, -10, 70, 25, function()
        CrossIgnoreUI:Hide()
    end)

    local leftPanel = CreateFrame("Frame", nil, CrossIgnoreUI, "BackdropTemplate")
    leftPanel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    leftPanel:SetPoint("TOPLEFT", 10, -40)
    leftPanel:SetSize(140, 460)

    local ignoreListBtn = CreateButton(leftPanel, L["IGNORE_LIST_HEADER"], "TOP", 0, -10, 120, 40)
    local chatfilterBtn = CreateButton(leftPanel, L["CHAT_FILTER_HEADER"], "TOP", 0, -60, 120, 40)
    local optionsBtn = CreateButton(leftPanel, L["OPTIONS_HEADER"], "TOP", 0, -110, 120, 40)

    local rightPanel = CreateFrame("Frame", nil, CrossIgnoreUI, "BackdropTemplate")
    rightPanel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    rightPanel:SetPoint("TOPLEFT", leftPanel, "TOPRIGHT", 10, 0)
    rightPanel:SetSize(450, 460)

    local ignoreListPanel = CreateFrame("Frame", nil, rightPanel)
    ignoreListPanel:SetAllPoints()

	local searchBoxIgnore = CreateEditBox(ignoreListPanel, 425, 24, "TOPLEFT", 15, -10)

	local placeholderIgnore = searchBoxIgnore:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	placeholderIgnore:SetPoint("LEFT", searchBoxIgnore, "LEFT", 6, 0)
	placeholderIgnore:SetText(L["SEARCH_PLACEHOLDER"])
	
	searchBoxIgnore:SetScript("OnTextChanged", function(self)
		local text = self:GetText()
		if text == "" then
			placeholderIgnore:Show()
		else
			placeholderIgnore:Hide()
		end
		CrossIgnore:RefreshBlockedList(text)
	end)

	searchBoxIgnore:SetScript("OnEditFocusGained", function(self)
		if self:GetText() == "" then
			placeholderIgnore:Show()
		end
	end)

	searchBoxIgnore:SetScript("OnEditFocusLost", function(self)
		if self:GetText() == "" then
			placeholderIgnore:Show()
		end
	end)

    local counterLabel = CreateLabel(ignoreListPanel, string.format(L["TOTAL_BLOCKED"], 0), "TOPLEFT", 10, -45, "GameFontNormal")
    CrossIgnore.counterLabel = counterLabel

    local scrollFrameIgnore, scrollChildIgnore = CreateScrollFrame(ignoreListPanel, 410, 350, "TOPLEFT", 10, -70)
    scrollChildIgnore:SetSize(410, 800)

    local accountWideLabel = CreateLabel(ignoreListPanel, L["ACCOUNT_WIDE_LABEL"], "TOPRIGHT", -50, -43, "GameFontNormal")
    local accountWideCheckbox = CreateFrame("CheckButton", "CrossIgnoreAccountWideCheckbox", ignoreListPanel, "ChatConfigCheckButtonTemplate")
    accountWideCheckbox:SetPoint("LEFT", accountWideLabel, "RIGHT", 10, 0)
    accountWideCheckbox:SetChecked(CrossIgnore.charDB.profile.settings.useGlobalIgnore)
    accountWideCheckbox:SetScript("OnClick", function(button)
        local value = button:GetChecked()
        CrossIgnore.charDB.profile.settings.useGlobalIgnore = value
        if CrossIgnoreUI and CrossIgnoreUI:IsShown() then
            CrossIgnore:RefreshBlockedList()
        end
    end)

    local removeButtonIgnore = CreateButton(ignoreListPanel, L["REMOVE_SELECTED_BTN"], "BOTTOM", 0, 15, 180, 30, RemoveSelectedPlayer)

    CrossIgnoreUI.searchBox = searchBoxIgnore
    CrossIgnoreUI.scrollFrame = scrollFrameIgnore
    CrossIgnoreUI.scrollChild = scrollChildIgnore
    CrossIgnoreUI.removeButton = removeButtonIgnore

    local chatFilterPanel = CreateFrame("Frame", nil, rightPanel)
    chatFilterPanel:SetAllPoints()

    local filterTitle = CreateLabel(chatFilterPanel, L["CHAT_FILTER_TITLE"], "TOP", 0, -12, "GameFontHighlightLarge")

	local searchBoxChat = CreateEditBox(chatFilterPanel, 425, 24, "TOPLEFT", 15, -25)
	searchBoxChat:SetAutoFocus(false)

	local placeholder = searchBoxChat:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	placeholder:SetPoint("LEFT", searchBoxChat, "LEFT", 6, 0)
	placeholder:SetText(L["SEARCH_PLACEHOLDER"])

	searchBoxChat:SetScript("OnTextChanged", function(self)
		local text = self:GetText()
		if text == "" then
			placeholder:Show()
		else
			placeholder:Hide()
		end
		CrossIgnore:UpdateWordsList(text)
	end)

	searchBoxChat:SetScript("OnEditFocusGained", function(self)
		if self:GetText() == "" then
			placeholder:Show()
		end
	end)

	searchBoxChat:SetScript("OnEditFocusLost", function(self)
		if self:GetText() == "" then
			placeholder:Show()
		end
	end)

	CrossIgnoreUI.searchBox = searchBoxChat

    local wordsScrollFrame, wordsScrollChild = CreateScrollFrame(chatFilterPanel, 410, 280, "TOPLEFT", 10, -55)
    wordsScrollChild:SetSize(410, 800)
    CrossIgnoreUI.wordsScrollFrame = wordsScrollFrame
    CrossIgnoreUI.wordsScrollChild = wordsScrollChild

    local inputLabel = CreateLabel(chatFilterPanel, L["ADD_NEW_WORD_LABEL"], "BOTTOMLEFT", 10, 100)
    local newWordInput = CreateEditBox(chatFilterPanel, 200, 24, "BOTTOMLEFT", 15, 70)
    newWordInput:SetAutoFocus(false)
    CrossIgnoreUI.newWordInput = newWordInput

    local channelDropdown = CreateChannelDropdown(chatFilterPanel)
	channelDropdown:ClearAllPoints()
	channelDropdown:SetPoint("LEFT", newWordInput, "RIGHT", -10, -4)
	CrossIgnoreUI.channelDropdown = channelDropdown

    local addWordBtn = CreateButton(chatFilterPanel, L["ADD_WORD_BTN"], "BOTTOMLEFT", 10, 40, 90, 24, function()
        AddNewWord()
    end)
    addWordBtn:SetNormalFontObject("GameFontNormalSmall")
    addWordBtn:SetHighlightFontObject("GameFontHighlightSmall")
    CrossIgnoreUI.chatFilterAddBtn = addWordBtn

    local removeWordBtn = CreateButton(chatFilterPanel, L["REMOVE_WORD_BTN"], "BOTTOMLEFT", 100, 40, 90, 24, RemoveSelectedWord)
    removeWordBtn:SetNormalFontObject("GameFontNormalSmall")
    removeWordBtn:SetHighlightFontObject("GameFontHighlightSmall")
    CrossIgnoreUI.chatFilterRemoveBtn = removeWordBtn

    local removeAllBtn = CreateButton(chatFilterPanel, L["REMOVE_ALL_BTN"], "BOTTOMLEFT", 190, 40, 90, 24, function()
        StaticPopup_Show("CROSSIGNORE_CONFIRM_REMOVE_ALL_WORDS")
    end)
    removeAllBtn:SetNormalFontObject("GameFontNormalSmall")
    removeAllBtn:SetHighlightFontObject("GameFontHighlightSmall")
    CrossIgnoreUI.chatFilterRemoveAllBtn = removeAllBtn

    CrossIgnoreUI.wordsScrollFrame = wordsScrollFrame
    CrossIgnoreUI.wordsScrollChild = wordsScrollChild
    CrossIgnoreUI.newWordInput = newWordInput
    CrossIgnoreUI.channelDropdown = channelDropdown

local optionsPanel = CreateFrame("Frame", nil, rightPanel)
optionsPanel:SetAllPoints()

optionsPanel:SetScript("OnShow", function()
    if not CrossIgnore.optionsBuilt then
        CrossIgnore:CreateOptionsUI(optionsPanel)
        CrossIgnore.optionsBuilt = true
    end
end)

    local function ShowIgnoreList()
        ignoreListPanel:Show()
        chatFilterPanel:Hide()
        optionsPanel:Hide()
        ignoreListBtn:Disable()
        chatfilterBtn:Enable()
        optionsBtn:Enable()
        self:RefreshBlockedList()
    end

    local function ShowChatFilter()
        ignoreListPanel:Hide()
        chatFilterPanel:Show()
        optionsPanel:Hide()
        chatfilterBtn:Disable()
        ignoreListBtn:Enable()
        optionsBtn:Enable()
        CrossIgnore:UpdateWordsList()
    end

    local function ShowOptions()
        optionsPanel:Show()
        ignoreListPanel:Hide()
        chatFilterPanel:Hide()
        optionsBtn:Disable()
        ignoreListBtn:Enable()
        chatfilterBtn:Enable()
    end

ignoreListBtn:SetScript("OnClick", ShowIgnoreList)
chatfilterBtn:SetScript("OnClick", ShowChatFilter)
optionsBtn:SetScript("OnClick", ShowOptions)


ShowIgnoreList()

C_Timer.After(0, function()
    if CrossIgnoreUI then
        CrossIgnoreUI:SetPropagateKeyboardInput(true)
        CrossIgnoreUI:SetScript("OnKeyDown", function(self, key)
            if key == "ESCAPE" then
                self:Hide()
            end
        end)

        CrossIgnoreUI:SetScript("OnShow", function(self)
            CrossIgnore:RefreshBlockedList()
        end)
    end
end)

end
