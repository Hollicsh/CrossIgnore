local addonName, addonTable = ...
local L = addonTable.L
addonTable.UI = addonTable.UI or {}
local UI = addonTable.UI
local Theme = UI.Theme
local W = UI.Widgets

UI.State = UI.State or {
  activePanel = "ignoreList",
  ignoreFilterText = "",
  wordFilterText = "",
  selectedPlayer = nil,
  selectedWord = nil,
}
UI.Frames = UI.Frames or {}

local function BuildPopups(CrossIgnore, CrossIgnoreDB)
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
      CrossIgnore:UpdateWordsList(UI.State.wordFilterText or "")
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
  }

  StaticPopupDialogs["CROSSIGNORE_CONFIRM_REMOVE_ALL_PLAYERS"] = {
    text = L["REMOVE_ALL_PLAYERS_CONFIRM"] or "Are you sure you want to remove ALL ignored players?\n\nThis cannot be undone.",
    button1 = L["YES_BUTTON"] or "Yes",
    button2 = L["NO_BUTTON"] or "No",
    OnAccept = function()
      if CrossIgnore and CrossIgnore.ClearAllIgnoredPlayers then
        CrossIgnore:ClearAllIgnoredPlayers()
        UI.State.selectedPlayer = nil
        CrossIgnore.selectedPlayer = nil
        CrossIgnore.selectedRow = nil
        CrossIgnore:RefreshBlockedList(UI.State.ignoreFilterText or "")
      end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
  }
end

local function BuildLeftNav(leftPanel, panels, CrossIgnore)
  local function Btn(parent, text, x, y, w, h)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetPoint("TOP", x, y)
    b:SetSize(w, h)
    b:SetText(text)
    return b
  end

  local buttons = {
    ignoreList   = Btn(leftPanel, L["IGNORE_LIST_HEADER"], 0, -10, 120, 40),
    chatFilter   = Btn(leftPanel, L["CHAT_FILTER_HEADER"], 0, -60, 120, 40),
    optionsMain  = Btn(leftPanel, L["OPTIONS_HEADER"], 0, -110, 120, 40),
    optionsIgnore= Btn(leftPanel, L["OPTIONS_IGNORE"], 10, -155, 110, 30),
    optionsEI    = Btn(leftPanel, L["OPTIONS_E_I"], 10, -190, 110, 30),
    chatFilterDebug = Btn(leftPanel, "ChatFilter DeBug", 10, -225, 110, 30),
  }
  buttons.optionsIgnore:Hide()
  buttons.optionsEI:Hide()
  buttons.chatFilterDebug:Hide()

  local function HideAllPanels()
    for _, p in pairs(panels) do p:Hide() end
    if CrossIgnore.ChatFilter and CrossIgnore.ChatFilter.SetDebugActive then
      CrossIgnore.ChatFilter:SetDebugActive(false)
      if CrossIgnore.ChatFilter.ClearLog then CrossIgnore.ChatFilter:ClearLog() end
    end
  end

  local function ShowOptionsSubButtons(show)
    buttons.optionsIgnore:SetShown(show)
    buttons.optionsEI:SetShown(show)
    buttons.chatFilterDebug:SetShown(show)
  end

  local optionsConfig = {
    { btn = buttons.ignoreList, panel = panels.ignoreList, func = function() CrossIgnore:RefreshBlockedList(UI.State.ignoreFilterText or "") end },
    { btn = buttons.chatFilter, panel = panels.chatFilter, func = function() CrossIgnore:UpdateWordsList(UI.State.wordFilterText or "") end },
    { btn = buttons.optionsMain, panel = panels.optionsMain, func = function()
      if not CrossIgnore.optionsBuilt and CrossIgnore.CreateOptionsUI then CrossIgnore:CreateOptionsUI(panels.optionsMain); CrossIgnore.optionsBuilt = true end
    end },
    { btn = buttons.optionsIgnore, panel = panels.optionsIgnore, func = function()
      if not CrossIgnore.optionsIgnoreBuilt and CrossIgnore.CreateIgnoreOptions then CrossIgnore:CreateIgnoreOptions(panels.optionsIgnore); CrossIgnore.optionsIgnoreBuilt = true end
    end },
    { btn = buttons.optionsEI, panel = panels.optionsEI, func = function()
      if not CrossIgnore.optionsEIBuilt and CrossIgnore.CreateEIOptions then CrossIgnore:CreateEIOptions(panels.optionsEI); CrossIgnore.optionsEIBuilt = true end
    end },
    { btn = buttons.chatFilterDebug, panel = panels.chatFilterDebug, func = function()
      if not CrossIgnore.chatFilterDebugBuilt and CrossIgnore.CreateChatFilterDebugMenu then
        CrossIgnore:CreateChatFilterDebugMenu(panels.chatFilterDebug)
        CrossIgnore.chatFilterDebugBuilt = true
      end
      if CrossIgnore.ChatFilter and CrossIgnore.ChatFilter.SetDebugActive then
        CrossIgnore.ChatFilter:SetDebugActive(true)
      end
    end },
  }

  for _, cfg in ipairs(optionsConfig) do
    cfg.btn:SetScript("OnClick", function()
      HideAllPanels()
      cfg.panel:Show()
      if cfg.btn == buttons.optionsMain or cfg.btn == buttons.optionsIgnore or cfg.btn == buttons.optionsEI or cfg.btn == buttons.chatFilterDebug then
        ShowOptionsSubButtons(true)
      else
        ShowOptionsSubButtons(false)
      end
      cfg.func()
    end)
  end

  return buttons
end

function UI:BuildMainFrame(CrossIgnore, CrossIgnoreDB)
  if UI.Frames.main then return UI.Frames.main end

  BuildPopups(CrossIgnore, CrossIgnoreDB)

  local f = CreateFrame("Frame", "CrossIgnoreUI", UIParent, "BackdropTemplate")
  f:SetSize(Theme.frame.width, Theme.frame.height)
  f:SetPoint("CENTER")
  f:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
  })
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)

  W:CreateLabel(f, L["TITLE_HEADER"], "TOP", 0, -12, "GameFontHighlightLarge")
  W:CreateButton(f, L["CLOSE_BUTTON"], "TOPRIGHT", -10, -10, 70, 25, function() f:Hide() end)

  tinsert(UISpecialFrames, "CrossIgnoreUI")

  local leftPanel = CreateFrame("Frame", nil, f, "BackdropTemplate")
  leftPanel:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
  })
  leftPanel:SetPoint("TOPLEFT", 10, -40)
  leftPanel:SetSize(140, 460)

  local rightPanel = CreateFrame("Frame", nil, f, "BackdropTemplate")
  rightPanel:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
  })
  rightPanel:SetPoint("TOPLEFT", leftPanel, "TOPRIGHT", 10, 0)
  rightPanel:SetSize(450, 460)

  local panels = {
    ignoreList   = CreateFrame("Frame", nil, rightPanel),
    chatFilter   = CreateFrame("Frame", nil, rightPanel),
    optionsMain  = CreateFrame("Frame", nil, rightPanel),
    optionsIgnore= CreateFrame("Frame", nil, rightPanel),
    optionsEI    = CreateFrame("Frame", nil, rightPanel),
    chatFilterDebug = CreateFrame("Frame", nil, rightPanel),
  }
  for _, p in pairs(panels) do p:SetAllPoints(); p:Hide() end
  panels.ignoreList:Show()

  UI.Frames.main = f
  UI.Frames.leftPanel = leftPanel
  UI.Frames.rightPanel = rightPanel
  UI.Frames.panels = panels

  BuildLeftNav(leftPanel, panels, CrossIgnore)

  return f
end

return UI
