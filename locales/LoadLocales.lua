local addonName, addonTable = ...
addonTable.Locales = addonTable.Locales or {}

local locale = GetLocale()
addonTable.L = addonTable.Locales[locale] or addonTable.Locales["enUS"]
