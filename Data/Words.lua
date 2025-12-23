local addonName, addonTable = ...
local L = addonTable.L
addonTable.Data = addonTable.Data or {}
local Data = addonTable.Data

local function safeLower(s) return tostring(s or ""):lower() end

function Data.BuildWordList(CrossIgnoreDB)
  local filters = CrossIgnoreDB and CrossIgnoreDB.global and CrossIgnoreDB.global.filters and CrossIgnoreDB.global.filters.words or {}
  local out = {}
  for ch, words in pairs(filters) do
    if type(words) == "table" then
      for idx, w in ipairs(words) do
        if type(w) == "string" then
          out[#out+1] = { word = w, channel = ch, strict = false, wordIndex = idx, channelName = ch }
        elseif type(w) == "table" and w.word then
          out[#out+1] = { word = w.word, channel = ch, strict = w.strict or false, wordIndex = idx, channelName = ch }
        end
      end
    end
  end
  return out
end

function Data.FilterWords(list, searchText)
  local lower = safeLower(searchText or "")
  if lower == "" then return list end
  local out = {}
  for _, e in ipairs(list or {}) do
    if (e.word and safeLower(e.word):find(lower, 1, true)) or (e.channel and safeLower(e.channel):find(lower, 1, true)) then
      out[#out+1] = e
    end
  end
  return out
end

return Data
