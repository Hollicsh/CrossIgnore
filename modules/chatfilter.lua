local ChatFilter = CrossIgnore.ChatFilter or {}
CrossIgnore.ChatFilter = ChatFilter

local CHAT_EVENTS = {
    Say          = { "CHAT_MSG_SAY" },
    Yell         = { "CHAT_MSG_YELL" },
    Whisper      = { "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM" },
    Guild        = { "CHAT_MSG_GUILD" },
    Officer      = { "CHAT_MSG_OFFICER" },
    Party        = { "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER" },
    Raid         = { "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING" },
    Instance     = { "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER" },
    Battleground = { "CHAT_MSG_BATTLEGROUND", "CHAT_MSG_BATTLEGROUND_LEADER" },
    Emote        = { "CHAT_MSG_EMOTE", "CHAT_MSG_TEXT_EMOTE" },
    Channel      = { "CHAT_MSG_CHANNEL" },
}

local channelCache = {}

local function RefreshChannelCache()
    wipe(channelCache)
    local chList = { GetChannelList() }
    for i = 1, #chList, 3 do
        local num  = tostring(chList[i])
        local name = tostring(chList[i + 1])
        local cleanName = name:lower()
        channelCache[num] = cleanName
        channelCache[cleanName] = cleanName
        channelCache[name] = cleanName
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("CHANNEL_UI_UPDATE")
f:RegisterEvent("CHANNEL_COUNT_UPDATE")
f:RegisterEvent("CHANNEL_ROSTER_UPDATE")
f:SetScript("OnEvent", RefreshChannelCache)
RefreshChannelCache()

local function NormalizeChannelKey(channel)
    local key = tostring(channel or "All Channels")
    if key == "" or key == "nil" then
        return "all channels"
    end
    local normalized = channelCache[key:lower()] or key
    return normalized:lower()
end
function ChatFilter:NormalizeChannelKey(ch)
    return NormalizeChannelKey(ch)
end

local function GetChannelCategory(event, ...)
    if event == "CHAT_MSG_CHANNEL" then
        for i = 1, select("#", ...) do
            local a = select(i, ...)
            if type(a) == "string" and a ~= "" then
                local clean = a:gsub("^%d+%.%s*", ""):lower()
                return channelCache[clean] or clean
            end
        end
        return nil
    end

    for channelName, events in pairs(CHAT_EVENTS) do
        for _, ev in ipairs(events) do
            if ev == event then
                return channelName:lower()
            end
        end
    end

    return nil
end

function ChatFilter:GetFilters()
    if not CrossIgnoreDB then return {} end
    CrossIgnoreDB.global = CrossIgnoreDB.global or {}
    CrossIgnoreDB.global.filters = CrossIgnoreDB.global.filters or {}
    CrossIgnoreDB.global.filters.words = CrossIgnoreDB.global.filters.words or {}
    CrossIgnoreDB.global.filters.words["all channels"] =
        CrossIgnoreDB.global.filters.words["all channels"] or {}
    return CrossIgnoreDB.global.filters.words
end

local function EscapeForPattern(text)
    return (text:gsub("(%W)", "%%%1"))
end

local function buildStrictCore(wordLower)
    local chars = {}
    for c in wordLower:gmatch(".") do
        chars[#chars+1] = EscapeForPattern(c)
    end
    if #chars == 0 then return nil end
    if #chars == 1 then
        return "%f[%z\1-\255]" .. chars[1] .. "%f[%z\1-\255]"
    end
    return table.concat(chars, "[%s%p]*")
end


local function buildNonStrictList(wordLower)
    local out = {}
    local exact = EscapeForPattern(wordLower)
    local chars = {}
    for c in wordLower:gmatch(".") do
        chars[#chars+1] = EscapeForPattern(c)
    end
    local spaced
    if #chars >= 2 then
        spaced = chars[1]
        for i = 2, #chars do
            spaced = spaced .. "%s+" .. chars[i]
        end
    end

    local function pushBoundaryVariants(core)
        out[#out+1] = "^" .. core .. "%s+"
        out[#out+1] = "^" .. core .. "$"
        out[#out+1] = "%s+" .. core .. "%s+"
        out[#out+1] = "%s+" .. core .. "$"
    end

    pushBoundaryVariants(exact)
    if spaced then
        pushBoundaryVariants(spaced)
    end
    return out
end

local compiledMatchers = {}

local function buildChannelMatcher(patterns)
    if not patterns or #patterns == 0 then return nil end

    local lines = {
        "return function(msg, sender)",
        "  msg = (msg or \"\"):lower()",
        "  sender = (sender or \"\"):lower()",
    }
    for i = 1, #patterns do
        lines[#lines+1] = ("  if msg:find(%q) then return true end"):format(patterns[i])
        lines[#lines+1] = ("  if sender:find(%q) then return true end"):format(patterns[i])
    end
    lines[#lines+1] = "  return false"
    lines[#lines+1] = "end"

    local chunk, err = loadstring(table.concat(lines, "\n"))
    if not chunk then
        return function(msg, sender)
            msg = (msg or ""):lower()
            sender = (sender or ""):lower()
            for i = 1, #patterns do
                local p = patterns[i]
                if msg:find(p) or sender:find(p) then return true end
            end
            return false
        end
    end
    return chunk()
end

local function CompilePatterns()
    wipe(compiledMatchers)

    local filters = ChatFilter:GetFilters()
    for channelKey, list in pairs(filters) do
        if type(list) == "table" and #list > 0 then
            local bucket = {}
            for _, entry in ipairs(list) do
                local wordLower =
                    (type(entry) == "table" and entry.normalized)
                    or (type(entry) == "string" and entry:lower())
                if wordLower and wordLower ~= "" then
                    if type(entry) == "table" and entry.strict then
                        local core = buildStrictCore(wordLower)
                        if core then bucket[#bucket+1] = core end
                    else
                        local plist = buildNonStrictList(wordLower)
                        for i = 1, #plist do
                            bucket[#bucket+1] = plist[i]
                        end
                    end
                end
            end
            if #bucket > 0 then
                compiledMatchers[channelKey:lower()] = buildChannelMatcher(bucket)
            end
        end
    end
end

local function IsFilteredMessage(msg, sender, event, ...)
    msg = msg or ""
    sender = sender or ""

    local fnAll = compiledMatchers["all channels"]
    if fnAll and fnAll(msg, sender) then
        return true
    end

    local channelKey = GetChannelCategory(event, ...)
    if not channelKey then return false end
    channelKey = NormalizeChannelKey(channelKey):lower()
    local fnChan = compiledMatchers[channelKey]
    if fnChan and fnChan(msg, sender) then
        return true
    end

    return false
end

local function ChatEventFilter(_, event, msg, sender, ...)
    return IsFilteredMessage(msg, sender, event, ...)
end

function ChatFilter:UpdateEventRegistration()
    for _, events in pairs(CHAT_EVENTS) do
        for _, ev in ipairs(events) do
            pcall(ChatFrame_RemoveMessageEventFilter, ev, ChatEventFilter)
        end
    end

    CompilePatterns()
    local haveAny = next(compiledMatchers) ~= nil
    if not haveAny then return end

    for channelName, events in pairs(CHAT_EVENTS) do
        local shouldHook = false
        local keyLower = channelName:lower()

        if compiledMatchers["all channels"] then
            shouldHook = true
        end

        if not shouldHook and compiledMatchers[keyLower] then
            shouldHook = true
        end

        if not shouldHook and channelName == "Channel" then
            for key, _ in pairs(compiledMatchers) do
                if key ~= "all channels" and not CHAT_EVENTS[key] then
                    shouldHook = true
                    break
                end
            end
        end

        if shouldHook then
            for _, ev in ipairs(events) do
                pcall(ChatFrame_AddMessageEventFilter, ev, ChatEventFilter)
            end
        end
    end
end

function ChatFilter:AddWord(word, channel, strict)
    if not word or word == "" then return end
    local filters = self:GetFilters()
    local key = NormalizeChannelKey(channel or "all channels"):lower()
    filters[key] = filters[key] or {}
    local normWord = word:lower()

    for _, v in ipairs(filters[key]) do
        local existing = (type(v) == "table" and v.normalized) or (type(v) == "string" and v:lower())
        if existing == normWord then
            if type(v) == "table" then
                v.strict = not not strict
            else
                for i, e in ipairs(filters[key]) do
                    if e == v then
                        filters[key][i] = { word = v, normalized = existing, strict = not not strict }
                        break
                    end
                end
            end
            self:UpdateEventRegistration()
            return
        end
    end

    table.insert(filters[key], { word = word, normalized = normWord, strict = not not strict })
    self:UpdateEventRegistration()
end

function ChatFilter:RemoveWord(word, channel)
    if not word or word == "" then return end
    local filters = self:GetFilters()
    local key = NormalizeChannelKey(channel or "all channels"):lower()
    local list = filters[key]
    if not list then return end

    local lowered = word:lower()
    for i = #list, 1, -1 do
        local entry = list[i]
        local normalized = (type(entry) == "table" and entry.normalized) or (type(entry) == "string" and entry:lower()) or ""
        if normalized == lowered then
            table.remove(list, i)
            break
        end
    end

    self:UpdateEventRegistration()
end

function ChatFilter:SetWordStrict(word, channel, strict)
    if not word or word == "" then return end
    local filters = self:GetFilters()
    local key = NormalizeChannelKey(channel or "all channels"):lower()
    filters[key] = filters[key] or {}

    for idx, entry in ipairs(filters[key]) do
        if (type(entry) == "table" and entry.word and entry.word:lower() == word:lower())
        or (type(entry) == "string" and entry:lower() == word:lower()) then
            if type(entry) == "table" then
                entry.strict = not not strict
            else
                local normalized = entry:lower()
                filters[key][idx] = { word = entry, normalized = normalized, strict = not not strict }
            end
            break
        end
    end

    self:UpdateEventRegistration()
end

function ChatFilter:Initialize()
    self:UpdateEventRegistration()
end

return ChatFilter
