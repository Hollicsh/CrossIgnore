function CrossIgnore:LoadDefaultBlockedWords()
    local filters = self.ChatFilter:GetFilters()

    if filters.defaultsLoaded then
        return
    end

    local defaultBlockedWords = {
        ["4. Services"] = { "WTS", "WTB", "BOOST", "CARRY" },
    }

    for channel, words in pairs(defaultBlockedWords) do
        filters[channel] = filters[channel] or {}
        local existing = {}
        for _, entry in ipairs(filters[channel]) do
            local word = type(entry) == "table" and entry.normalized or entry
            if word then existing[word:lower()] = true end
        end

        for _, word in ipairs(words) do
            if not existing[word:lower()] then
                table.insert(filters[channel], {
                    word       = word,
                    normalized = word:lower(),
                    strict     = true, 
                })
            end
        end
    end

    filters.defaultsLoaded = true
end
