local addonName, addonTable = ...
local L = addonTable.L
addonTable.Data = addonTable.Data or {}
local Data = addonTable.Data

local function safeLower(s) return tostring(s or ""):lower() end

function Data.BuildPlayerList(CrossIgnore, filterText)
  filterText = safeLower(filterText or "")
  local players, overLimitPlayers = CrossIgnore:GetActivePlayerTables()

  local out = {}
  local function add(src)
    for _, data in ipairs(src or {}) do
      local name = data.name or ""
      if filterText == "" or safeLower(name):find(filterText, 1, true) then
        out[#out+1] = data
      end
    end
  end
  add(players)
  add(overLimitPlayers)
  return out
end

function Data.MatchSelectedPlayer(selected, entry)
  if not selected or not entry then return false end
  if selected.name ~= entry.name then return false end
  local sa = selected.server or selected.realm or ""
  local sb = entry.server or entry.realm or ""
  return sa == sb
end

return Data
