CrossIgnore = LibStub("AceAddon-3.0"):NewAddon("CrossIgnore", "AceConsole-3.0", "AceEvent-3.0")
local addonName, addonTable = ...
local L = addonTable.L

local currentRealm = GetNormalizedRealmName()

local options = {
    name = "CrossIgnore",
    handler = CrossIgnore,
    type = "group",
    args = {
        ui = {
            name = L["OPEN_UI"],
            desc = L["OPEN_UI_DESC"],
            type = "execute",
            func = function() CrossIgnore:ToggleGUI() end,
        },
        useGlobalIgnore = {
            type = "toggle",
            name = L["USE_GLOBAL_IGNORE"],
            desc = L["USE_GLOBAL_IGNORE_DESC"],
            get = function() return CrossIgnore.db.profile.settings.useGlobalIgnore end,
            set = function(_, value) CrossIgnore.db.profile.settings.useGlobalIgnore = value end,
        },
        showMinimapIcon = {
            type = "toggle",
            name = L["SHOW_MINIMAP_ICON"],
            desc = L["SHOW_MINIMAP_ICON_DESC"],
            get = function()
                return not CrossIgnore.iconDB.profile.minimap.hide
            end,
            set = function(_, value)
                CrossIgnore.iconDB.profile.minimap.hide = not value
                if value then
                    LibStub("LibDBIcon-1.0"):Show("CrossIgnore")
                else
                    LibStub("LibDBIcon-1.0"):Hide("CrossIgnore")
                end
            end,
        },
    },
}

function CrossIgnore:InitDB()
    self.globalDB = LibStub("AceDB-3.0"):New("CrossIgnoreDB", {
        global = {
            minimap = { hide = false },
            players = {},
            overLimitPlayers = {},
            pendingRemovals = {},
            filters = {
                words = {
                    ["All Channels"] = {},
                    ["Say"] = {},
                    ["Yell"] = {},
                    ["Whisper"] = {},
                    ["Guild"] = {},
                    ["Officer"] = {},
                    ["Party"] = {},
                    ["Raid"] = {},
                    ["Instance"] = {},
                    ["Custom"] = {},
                },
                selectedChannel = "All Channels",
				defaultsLoaded = false,
				removedDefaults = false,
            },
        },
    }, true)

    self.charDB = LibStub("AceDB-3.0"):New("CrossIgnoreSingleDB", {
        profile = {
            settings = {
                LFGBlock = true,
                UnitBlock = true,
                useGlobalIgnore = false,
                maxIgnoreLimit = 50,
				autoReplyEnabled = true,
				autoReplyMessage = L["AUTO_REPLY_DEFAULT"]
            },
            players = {},
            overLimitPlayers = {},
            pendingRemovals = {},
        },
    }, true)

    self.db = self.charDB
end

function CrossIgnore:OnInitialize()
    self:InitDB()
    self:InitMinimap()
	self:LoadDefaultBlockedWords()

    if self.ChatFilter and self.ChatFilter.Initialize then
        self.ChatFilter:Initialize()
    end

    if self.BlockHandler then
        if self.BlockHandler.Initialize then self.BlockHandler:Initialize() end
        if self.BlockHandler.Register then self.BlockHandler:Register() end
    end

    LibStub("AceConfig-3.0"):RegisterOptionsTable("CrossIgnore", options, {"CrossIgnore", "ci"})

    self:RegisterEvent("LFG_LIST_APPLICATION_STATUS_UPDATED", "OnLFGDecline")
    self:RegisterEvent("IGNORELIST_UPDATE", "DelayedUpdateIgnoreList")

    if LFGListFrame and LFGListFrame.SearchPanel then
        LFGListFrame:HookScript("OnHide", function()
            if LfgCache then
                for k in pairs(LfgCache) do LfgCache[k] = nil end
            end
        end)
    end

    self:HookFunctions()
end

local LDB = LibStub("LibDataBroker-1.1"):NewDataObject("CrossIgnore", {
    type = "data source",
    text = "CrossIgnore",
    icon = "Interface\\AddOns\\CrossIgnore\\media\\icon",
    OnClick = function(_, button)
        if button == "LeftButton" then CrossIgnore:ToggleGUI() end
    end,
    OnTooltipShow = function(tooltip)
        tooltip:AddLine("CrossIgnore")
        tooltip:AddLine(L["LEFT_CLICK_OPEN_UI"], 1, 1, 1)
    end,
})

function CrossIgnore:InitMinimap()
    self.iconDB = LibStub("AceDB-3.0"):New("CrossIgnoreMinimapDB", {
        profile = { minimap = { hide = false } }
    })

    LibStub("LibDBIcon-1.0"):Register("CrossIgnore", LDB, self.iconDB.profile.minimap)
end

function CrossIgnore:ToggleGUI()
    if CrossIgnoreUI and CrossIgnoreUI:IsShown() then
        CrossIgnoreUI:Hide()
    else
        if not CrossIgnoreUI then self:CreateUI() end
        self:UpdateIgnoreList()
        self:CheckExpiredIgnores()
        CrossIgnoreUI:Show()
    end
end

function CrossIgnore:DelayedUpdateIgnoreList()
    if self.updateScheduled then return end
    self.updateScheduled = true
    C_Timer.After(0.5, function()
        self.updateScheduled = false
        self:UpdateIgnoreList()
    end)
end

function CrossIgnore:OnEnable()
    self:ProcessPendingRemovals()
end

local function StripRealm(name) return (name and name:match("^[^%-]+")) or name end
local function MakeKey(base, realm) if not base or not realm then return nil end return base .. "-" .. realm end

function CrossIgnore:NormalizePlayerName(name)
    if not name or name == "" then return nil, nil, nil end
    local base, realm = strsplit("-", name)
    if not base or base == "" then return nil, nil, nil end
    realm = realm or currentRealm or GetNormalizedRealmName() or "Unknown"
    return base .. "-" .. realm, base, realm
end

function CrossIgnore:GetActivePlayerTables()
    if self.charDB.profile.settings.useGlobalIgnore then
        return self.globalDB.global.players, self.globalDB.global.overLimitPlayers or {}
    else
        return self.charDB.profile.players, self.charDB.profile.overLimitPlayers
    end
end

function CrossIgnore:GetAllLists()
    return self.charDB.profile.players,
           self.charDB.profile.overLimitPlayers,
           self.globalDB.global.players,
           self.globalDB.global.overLimitPlayers or {}
end

local function listHas(list, base, realm)
    if not list then return false end
    for _, p in ipairs(list) do
        if p.name == base and p.server == realm then return true end
    end
    return false
end

function CrossIgnore:IsPlayerInAnyList(base, realm)
    if not base or not realm then return false end
    local c, co, g, go = self:GetAllLists()
    if listHas(c, base, realm) then return true end
    if listHas(co, base, realm) then return true end
    if listHas(g, base, realm) then return true end
    if listHas(go, base, realm) then return true end
    return false
end

local function shallowcopy(tbl)
    local t = {}
    for k, v in pairs(tbl or {}) do t[k] = v end
    return t
end

local function CopyEntry(entry)
    if CopyTable then return CopyTable(entry) end
    return shallowcopy(entry)
end

function CrossIgnore:EnsureGlobalPresence(entry, maxIgnoreLimit)
    local g = self.globalDB.global
    g.players = g.players or {}
    g.overLimitPlayers = g.overLimitPlayers or {}

    local key = MakeKey(entry.name, entry.server)

    local function updateIfFound(list)
        for _, p in ipairs(list) do
            if MakeKey(p.name, p.server) == key then
                if entry.note ~= p.note then
                    if (entry.lastModifiedNote or 0) > (p.lastModifiedNote or 0) then
                        p.note = entry.note
                        p.lastModifiedNote = entry.lastModifiedNote or time()
                    else
                        entry.note = p.note
                        entry.lastModifiedNote = p.lastModifiedNote or time()
                    end
                end

                if entry.expires ~= p.expires then
                    if (entry.lastModifiedExpires or 0) > (p.lastModifiedExpires or 0) then
                        p.expires = entry.expires
                        p.lastModifiedExpires = entry.lastModifiedExpires or time()
                    else
                        entry.expires = p.expires
                        entry.lastModifiedExpires = p.lastModifiedExpires or time()
                    end
                end

                if entry.added and (not p.added or entry.added < p.added) then
                    p.added = entry.added
                elseif p.added and (not entry.added or p.added < entry.added) then
                    entry.added = p.added
                end

                if entry.addedBy then p.addedBy = entry.addedBy end
                if entry.source   then p.source   = entry.source end
                if entry.type     then p.type     = entry.type end
                if entry.ignored ~= nil then p.ignored = entry.ignored end

                return true
            end
        end
        return false
    end

    if updateIfFound(g.players) then return end
    if updateIfFound(g.overLimitPlayers) then return end

    local e = CopyEntry(entry)
    e.lastModifiedNote = e.lastModifiedNote or time()
    e.lastModifiedExpires = e.lastModifiedExpires or time()

    if #g.players < (maxIgnoreLimit or 50) then
        table.insert(g.players, e)
    else
        table.insert(g.overLimitPlayers, e)
    end
end

function CrossIgnore:SyncLocalToGlobal()
    local max = (self.charDB.profile.settings and self.charDB.profile.settings.maxIgnoreLimit) or 50
    self.charDB.profile.players = self.charDB.profile.players or {}
    self.charDB.profile.overLimitPlayers = self.charDB.profile.overLimitPlayers or {}
    self.globalDB.global.players = self.globalDB.global.players or {}
    self.globalDB.global.overLimitPlayers = self.globalDB.global.overLimitPlayers or {}

    for _, entry in ipairs(self.charDB.profile.players) do
        self:EnsureGlobalPresence(entry, max)
    end
    for _, entry in ipairs(self.charDB.profile.overLimitPlayers) do
        self:EnsureGlobalPresence(entry, max)
    end
end

function CrossIgnore:RemoveFromAllAddonLists(base, realm)
    local function removeFromList(list)
        for i = #list, 1, -1 do
            local p = list[i]
            if p.name == base and p.server == realm then
					if self.maybeMarkPendingRemoval and self:maybeMarkPendingRemoval(base, realm, p.addedBy) then
                    table.remove(list, i)
                    return
                end
                table.remove(list, i)
            end
        end
    end

    removeFromList(self.charDB.profile.players)
    removeFromList(self.charDB.profile.overLimitPlayers or {})
    removeFromList(self.globalDB.global.players or {})
    removeFromList(self.globalDB.global.overLimitPlayers or {})
end

function CrossIgnore:GetBlizzardIgnoreSet()
    local ignoreSet = {}
    local numIgnored = C_FriendList.GetNumIgnores()
    for i = 1, numIgnored do
        local playerName = C_FriendList.GetIgnoreName(i)
        if playerName then
            local _, name, server = self:NormalizePlayerName(playerName)
            if name and server then ignoreSet[MakeKey(name, server)] = true end
        end
    end
    return ignoreSet
end

function CrossIgnore:GetAddonIgnoreSet()
    local addonSet = {}
    for _, player in ipairs(self.charDB.profile.players) do
        if player.name and player.server then
            addonSet[MakeKey(player.name, player.server)] = true
        end
    end
    return addonSet
end

function CrossIgnore:UpdateIgnoreList()
    local blizzSet = self:GetBlizzardIgnoreSet()
    local addonSet = self:GetAddonIgnoreSet() 
    local changed = false

    for blizzName in pairs(blizzSet) do
        if not addonSet[blizzName] then changed = true break end
    end
    if not changed then
        for addonName in pairs(addonSet) do
            if not blizzSet[addonName] then changed = true break end
        end
    end

    if not changed then
        self:SyncLocalToGlobal()
        self:RefreshBlockedList()
        return
    end

    local list = self.charDB.profile.players

    for blizzName in pairs(blizzSet) do
        if not addonSet[blizzName] then
            local base, realm = strsplit("-", blizzName)

            local existingNote, existingExpires = "", 0

            for _, existing in ipairs(list) do
                if existing.name == base and existing.server == realm then
                    if existing.note ~= nil then existingNote = existing.note end
                    if existing.expires ~= nil then existingExpires = existing.expires end
                    break
                end
            end

            if (existingNote == "" or existingExpires == 0)
            and self.globalDB and self.globalDB.global and self.globalDB.global.players then
                for _, existing in ipairs(self.globalDB.global.players) do
                    if existing.name == base and existing.server == realm then
                        if existing.note ~= nil then existingNote = existing.note end
                        if existing.expires ~= nil then existingExpires = existing.expires end
                        break
                    end
                end
            end

            if existingExpires == 0 then
                local defaultDays = self.charDB.profile.settings.defaultExpireDays or 0
                if defaultDays > 0 then
                    existingExpires = time() + (defaultDays * 86400)
                end
            end

            local entry = {
                name     = base,
                server   = realm,
                added    = time(),
                ignored  = true,
                source   = "blizzard",
                type     = "player",
                note     = existingNote,
                expires  = existingExpires,
                addedBy  = UnitName("player") .. "-" .. GetNormalizedRealmName(),
            }

            table.insert(list, entry)

            self:EnsureGlobalPresence(entry, self.charDB.profile.settings.maxIgnoreLimit or 50)
        end
    end

    for i = #list, 1, -1 do
        local p = list[i]
        local full = MakeKey(p.name, p.server)
        if not blizzSet[full] then
            table.remove(list, i)
            self:RemoveFromAllAddonLists(p.name, p.server)
        end
    end

    self:SyncLocalToGlobal()
    self:RefreshBlockedList()
end


function CrossIgnore:AddIgnore(name, note, duration)
    if not name or name == "" then return end

    local fullName, base, realm = self:NormalizePlayerName(name)
    if not base or not realm then
        realm = GetNormalizedRealmName()
        if not base or not realm then return end
    end

    if self:IsPlayerInAnyList(base, realm) then return end

    local maxIgnoreLimit = self.charDB.profile.settings.maxIgnoreLimit or 50

    local dur = tonumber(duration)
    if not dur then
        local defaultDays = self.charDB.profile.settings.defaultExpireDays or 0
        dur = (defaultDays > 0) and (defaultDays * 86400) or 0
    end

    local expiresAt = (dur > 0) and (time() + dur) or 0

    local entry = {
        name       = base,
        server     = realm,
        added      = time(),
        ignored    = true,
        source     = "blizzard",
        type       = "player",
        note       = note or "",
        expires    = expiresAt,
        addedBy    = UnitName("player") .. "-" .. GetNormalizedRealmName(),
    }

    if #self.charDB.profile.players < maxIgnoreLimit then
        C_FriendList.AddIgnore(fullName)
        entry.source = "blizzard"
        table.insert(self.charDB.profile.players, CopyEntry(entry))
    else
        entry.source = "addon"
        table.insert(self.charDB.profile.overLimitPlayers, CopyEntry(entry))
    end

    self:EnsureGlobalPresence(entry, maxIgnoreLimit)

    if CrossIgnoreUI and CrossIgnoreUI:IsShown() then
        self:RefreshBlockedList()
    end
end


function CrossIgnore:maybeMarkPendingRemoval(base, realm, addedBy)
    local myChar = UnitName("player") .. "-" .. GetNormalizedRealmName()
    if addedBy and addedBy ~= myChar then
        local t = self.charDB.profile.settings.useGlobalIgnore and self.globalDB.global.pendingRemovals or self.charDB.profile.pendingRemovals
        table.insert(t, { name = base, server = realm, addedBy = addedBy, markedBy = myChar, markedAt = time() })
        return true
    end
    return false
end

function CrossIgnore:DelIgnore(name)
    if not name or name == "" then return end

    local fullName, base, realm = self:NormalizePlayerName(name)
    if not base or not realm then return end

    local removedAny = self:RemoveFromAllAddonLists(base, realm)

    local myChar = UnitName("player") .. "-" .. GetNormalizedRealmName()
    local addedBySameChar = true 

    for i = 1, C_FriendList.GetNumIgnores() do
        local nameOnList = C_FriendList.GetIgnoreName(i)
        if nameOnList then
            local _, b, r = self:NormalizePlayerName(nameOnList)
            if b == base and r == realm then
                C_FriendList.DelIgnore(nameOnList)
                removedAny = true
                break
            elseif StripRealm(nameOnList):lower() == base:lower() then
                C_FriendList.DelIgnore(nameOnList)
                removedAny = true
                break
            end
        end
    end

    if removedAny then
        if CrossIgnoreUI and CrossIgnoreUI:IsShown() then self:RefreshBlockedList() end
    end
end

function CrossIgnore:ProcessPendingRemovals()
    local myChar = UnitName("player") .. "-" .. GetNormalizedRealmName()
    local function processList(pendingList)
        for i = #pendingList, 1, -1 do
            local rem = pendingList[i]
            if rem.addedBy == myChar then
                local full = MakeKey(rem.name, rem.server)
                self:RemoveFromAllAddonLists(rem.name, rem.server)
                for j = 1, C_FriendList.GetNumIgnores() do
                    local nameOnList = C_FriendList.GetIgnoreName(j)
                    if nameOnList and (nameOnList == full or StripRealm(nameOnList) == rem.name) then
                        C_FriendList.DelIgnore(nameOnList)
                        break
                    end
                end
                table.remove(pendingList, i)
            end
        end
    end
    processList(self.charDB.profile.pendingRemovals)
    processList(self.globalDB.global.pendingRemovals)
end

function CrossIgnore:AddOrDelIgnore(name)
    if self:IsPlayerBlocked(name) then
        self:DelIgnore(name)
    else
        self:AddIgnore(name)
    end
    self:RefreshBlockedList()

    if LFGListFrame and LFGListFrame.SearchPanel and LFGListFrame.SearchPanel:IsShown() then
        LFGListSearchPanel_UpdateResults(LFGListFrame.SearchPanel)
    end
end

function CrossIgnore:CreateBlockUnblockButton(root, fullName)
    if not fullName then return end
    root:CreateDivider()
    root:CreateTitle("|cFFffd100CrossIgnore|r")
    local isBlocked = self:IsPlayerBlocked(fullName)
    root:CreateButton(isBlocked and "Unblock Player" or "Block Player", function()
        self:AddOrDelIgnore(fullName)
    end)
end

function CrossIgnore:CrossIgnore_LFG_ApplicantMenu(owner, root)
    if not owner or not owner.resultID then return end
    local info = C_LFGList.GetSearchResultInfo(owner.resultID)
    if not info or not info.leaderName then return end
    local fullName = self:NormalizePlayerName(info.leaderName)
    self:CreateBlockUnblockButton(root, fullName)
end

function CrossIgnore:CrossIgnore_UnitMenu(owner, root, contextData)
    local name, realm = UnitFullName(contextData.unit)
    if not name then return end
    local fullName = self:NormalizePlayerName(name .. (realm and "-" .. realm or ""))
    self:CreateBlockUnblockButton(root, fullName)
end

function CrossIgnore:ClearLFGCache()
    if self.LFGCacheTimer then
        self.LFGCacheTimer:Cancel()
        self.LFGCacheTimer = nil
    end
end

function CrossIgnore:ShowBlockedIconOnTooltip()
    if TooltipDataProcessor and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip)
            local _, unit = tooltip:GetUnit()
            if unit and UnitIsPlayer(unit) then
                local name, realm = UnitName(unit)
                if name then
                    addon:CheckTooltipForIgnoredPlayer(tooltip, name, realm)
                end
            end
        end)
    else
        GameTooltip:HookScript("OnTooltipSetUnit", function(tooltip)
            local _, unit = tooltip:GetUnit()
            if unit and UnitIsPlayer(unit) then
                local name, realm = UnitName(unit)
                if name then
                    addon:CheckTooltipForIgnoredPlayer(tooltip, name, realm)
                end
            end
    end)
	end
end

function CrossIgnore:HookFunctions()
    if Menu and Menu.ModifyMenu then
        if LFGListFrame then
            Menu.ModifyMenu("MENU_LFG_FRAME_SEARCH_ENTRY", function(...)
                self:CrossIgnore_LFG_ApplicantMenu(...)
            end)

            LFGListFrame:HookScript("OnShow", function()
                LFGFrameIsOpen = true
                CrossIgnore:ClearLFGCache()
            end)
            LFGListFrame:HookScript("OnHide", function()
                LFGFrameIsOpen = false
                CrossIgnore:ClearLFGCache()
            end)

            hooksecurefunc("LFGListSearchEntry_Update", function(entry)
                if not LFGFrameIsOpen or not entry.resultID then return end
                local info = C_LFGList.GetSearchResultInfo(entry.resultID)
                if info and info.leaderName then
                    if CrossIgnore:IsPlayerBlocked(info.leaderName) then
                        if not entry.Backdrop then
                            entry.Backdrop = entry:CreateTexture(nil, "BACKGROUND")
                            entry.Backdrop:SetAllPoints(entry)
                        end
                        entry.Backdrop:SetColorTexture(1, 0, 0, 0.3)
                    elseif entry.Backdrop then
                        entry.Backdrop:SetColorTexture(0, 0, 0, 0)
                    end
                end
            end)

            hooksecurefunc("LFGListSearchEntry_OnEnter", function(selfEntry)
                if not LFGFrameIsOpen or not selfEntry.resultID then return end
                local info = C_LFGList.GetSearchResultInfo(selfEntry.resultID)
                if info and info.leaderName and CrossIgnore:IsPlayerBlocked(info.leaderName) then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine(L["CI_ALERT_LEADER_BLOCKED"], 1, 0.3, 0.3)
                    GameTooltip:Show()
                end
            end)
        end

        if self.db.profile.settings.UnitBlock then
            for _, menu in pairs({"MENU_UNIT_ENEMY_PLAYER", "MENU_UNIT_PLAYER", "MENU_UNIT_PARTY", "MENU_UNIT_RAID_PLAYER"}) do
                Menu.ModifyMenu(menu, function(...)
                    self:CrossIgnore_UnitMenu(...)
                end)
            end
        end

        Menu.ModifyMenu("MENU_CHAT_ROSTER", function(owner, root)
            local name = owner and owner.name
            if not name then return end
            local fullName = self:NormalizePlayerName(name)
            self:CreateBlockUnblockButton(root, fullName)
        end)
    end
end

function CrossIgnore:OnLFGDecline(event, id, status)
    if self.db.profile.settings.LFGBlock and status == "declined" then
        local info = C_LFGList.GetSearchResultInfo(id)
        if info and info.leaderName then
            self:AddIgnore(info.leaderName)
        end
    end
end


function CrossIgnore:CheckExpiredIgnores()
    local now = time()
    local function CheckAndRemove(list)
        for i = #list, 1, -1 do
            local entry = list[i]
            if entry.expires and entry.expires > 0 and entry.expires <= now then
                local base, realm = entry.name, entry.server
                local fullName = MakeKey(base, realm)
                self:RemoveFromAllAddonLists(base, realm)
                for j = 1, C_FriendList.GetNumIgnores() do
                    local nameOnList = C_FriendList.GetIgnoreName(j)
                    if nameOnList and (nameOnList == fullName or StripRealm(nameOnList) == base) then
                        C_FriendList.DelIgnore(nameOnList)
                        break
                    end
                end
            end
        end
    end
    CheckAndRemove(self.charDB.profile.players)
    CheckAndRemove(self.charDB.profile.overLimitPlayers)
    CheckAndRemove(self.globalDB.global.players)
    self:RefreshBlockedList()
end

function CrossIgnore:IsPlayerBlocked(playerName)
    local _, name, server = self:NormalizePlayerName(playerName)
    if not name or not server then return false end
    return self:IsPlayerInAnyList(name, server)
end

function CrossIgnore:OnLFGDecline(event, id, status)
    if status == "declined" then
        local info = C_LFGList.GetSearchResultInfo(id)
        if info and info.leaderName then
            self:AddIgnore(info.leaderName)
        end
    end
end
