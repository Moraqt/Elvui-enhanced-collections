local E, L, V, P = unpack(ElvUI)
local Addon = E:NewModule("EnhancedCollections", "AceEvent-3.0")
ElvUIEnhancedCollections = Addon
Addon.addonName = ...
Addon.version = "1.1.0"
Addon.frames = setmetatable({}, { __mode = "k" })
Addon.hooks = setmetatable({}, { __mode = "k" })

P.enhancedCollections = {
    enabled = true,
    font = "Expressway",
    fontSize = 12,
    fontOutline = "OUTLINE",
    opacity = 1,
    uncollectedAlpha = 0.45,
}

function Addon:DB()
    return E.db.enhancedCollections
end

function Addon:Accent()
    return unpack(E.media.rgbvaluecolor or { 0.09, 0.52, 0.82 })
end

function Addon:Font(label, offset)
    if not label or not label.SetFont then return end
    local db = self:DB()
    local media = E.Libs and E.Libs.LSM or E.LSM
    local path = media and media:Fetch("font", db.font, true)
        or E.media.normFont or STANDARD_TEXT_FONT
    local size, outline = math.max(8, db.fontSize + (offset or 0)), db.fontOutline
    local current, currentSize, currentOutline = label:GetFont()
    if current ~= path or currentSize ~= size or currentOutline ~= outline then
        label:SetFont(path, size, outline)
    end
end

-- Observe existing refresh methods. Never replace a click/drag/event/update script.
function Addon:After(object, method, callback)
    if not object or type(object[method]) ~= "function" then return end
    self.hooks[object] = self.hooks[object] or {}
    if self.hooks[object][method] then return end
    self.hooks[object][method] = true
    hooksecurefunc(object, method, callback)
end

function Addon:IsCollectionObject(object)
    for i = 1, 32 do
        if not object then return false end
        if object == CollectionsJournal or object == WardrobeCollectionFrame then return true end
        object = object.GetParent and object:GetParent()
    end
    return false
end

function Addon:Initialize()
    E.Libs.EP:RegisterPlugin(self.addonName, function() self:InsertOptions() end)
    if not self:DB().enabled then return end
    if E.private.skins and E.private.skins.blizzard and not E.private.skins.blizzard.enable then return end
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnReady")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnReady")
    self:RegisterEvent("ADDON_LOADED", "OnReady")
    self:OnReady()
end

function Addon:OnReady()
    if InCombatLockdown() then return end
    if self.installed then
        self:UnregisterAllEvents()
    elseif CollectionsJournal and WardrobeCollectionFrame then
        self:Install()
        self:UnregisterAllEvents()
    end
end

function Addon:Refresh()
    if not self.installed or not self:DB().enabled then return end
    if InCombatLockdown() then
        self.refreshPending = true
        self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
            self:UnregisterEvent("PLAYER_REGEN_ENABLED")
            self.refreshPending = nil
            self:Refresh()
        end)
        return
    end
    self:SkinAll()
end

E:RegisterModule(Addon:GetName(), function() Addon:Initialize() end)
