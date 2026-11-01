FilterDropDownButtonMixin = CreateFromMixins(CallbackRegistryMixin)

function FilterDropDownButtonMixin:IsFiltered(key)
    return self.filters[key]
end 

function FilterDropDownButtonMixin:HasAnyFilters()
    return next(self.filters) ~= nil
end

function FilterDropDownButtonMixin:GetFilter()
    return self.filters
end

function FilterDropDownButtonMixin:GetFilterKeys()
    return GetKeysArray(self.filters)
end

function FilterDropDownButtonMixin:UpdateClearFilterButton()
    self.ClearFilterButton:SetShown(self:HasAnyFilters())
end

function FilterDropDownButtonMixin:GetDropDownInfoByKey(key)
    for index, info in pairs(self.dropdownInfo) do
        if info.arg1 == key then
            return info
        end
        if info.menuList then
            for _, subInfo in ipairs(self.menuLists[info.menuList]) do
                if subInfo.arg1 == key then
                    return subInfo
                end
            end
        end
    end
end

function FilterDropDownButtonMixin:AddFilterOption(filterKey, info)
    info.arg1 = filterKey
    info.checked = function()
        return self:IsFiltered(filterKey)
    end
    if info.func then
        local func = info.func
        info.func = function(_, key)
            func()
            self:SetFilter(key, not self:IsFiltered(key))
        end
    else
        info.func = function(_, key)
            self:SetFilter(key, not self:IsFiltered(key))
        end
    end
    -- insert at end (but not +1) to keep close button at the bottom
    tinsert(self.dropdownInfo, #self.dropdownInfo, table.Copy(info))
end

function FilterDropDownButtonMixin:AddSubFilterOption(parentFilterKey, subMenuKey, info)
    local parentInfo = self:GetDropDownInfoByKey(parentFilterKey)
    if not parentInfo then
        return
    end
    
    parentInfo.hasArrow = true
    parentInfo.menuList = parentFilterKey
    
    if not self.menuLists[parentFilterKey] then
        self.menuLists[parentFilterKey] = {}

        -- set checked function for parent to check if any subfilter is checked
        parentInfo.checked = function()
            if self:IsFiltered(parentInfo.arg1) then
                return true
            end
            for _, subInfo in ipairs(self.menuLists[parentFilterKey]) do
                if self.menuLists[subInfo.arg1] then
                    for _, subSubInfo in ipairs(self.menuLists[subInfo.arg1]) do
                        if self:IsFiltered(subSubInfo.arg1) then
                            return true
                        end
                    end
                end
                if self:IsFiltered(subInfo.arg1) then
                    return true
                end
            end

            return false
        end
    end

    info.arg1 = subMenuKey
    info.checked = function()
        return self:IsFiltered(subMenuKey)
    end
    if info.func then
        local func = info.func
        info.func = function(_, key)
            func()
            self:SetFilter(key, not self:IsFiltered(key))
        end
    else
        info.func = function(_, key)
            self:SetFilter(key, not self:IsFiltered(key))
        end
    end
    tinsert(self.menuLists[parentFilterKey], table.Copy(info))
end 


-- The button art retail's WowStyle1 dropdowns wear, on this client's widgets.
--
-- Retail draws that button from one 97x26 image and stretches it with SetTextureSliceMargins,
-- which the era has no notion of. Measured on the sheet, columns 0-9 and 79-96 are the caps -- the
-- second carries the caret -- and everything between them is one repeated column, so three pieces
-- redraw it exactly at any width. The art is retail's Interface\Common\CommonDropdown, pulled
-- with rb-casc; the atlas rows that cut it are in SharedXML/AtlasInfo.lua.
DropdownButtonArtMixin = {}

local DROPDOWN_ART = "common-dropdown-b-button"

function DropdownButtonArtMixin:SetArtState(state)
    local base = DROPDOWN_ART .. (state or "")

    -- Each cap is its own fixed width and only its width; nothing anchors it horizontally, so the
    -- atlas size is asked for and the button's height written back over the half of it that is
    -- wrong.
    self.Left:SetAtlas(base .. "-left", true)
    self.Right:SetAtlas(base .. "-right", true)
    local height = self:GetHeight()
    self.Left:SetHeight(height)
    self.Right:SetHeight(height)

    -- The middle is anchored corner to corner between them, so it needs no size of its own.
    self.Middle:SetAtlas(base .. "-middle")
end

function DropdownButtonArtMixin:UpdateArt()
    if not self:IsEnabled() or self:IsEnabled() == 0 then
        self:SetArtState("-disabled")
    elseif self.artPressed then
        self:SetArtState(self.artOver and "-pressedhover" or "-pressed")
    elseif self.artOver then
        self:SetArtState("-hover")
    else
        self:SetArtState("")
    end
end

function DropdownButtonArtMixin:OnEnter()
    self.artOver = true
    self:UpdateArt()
    if self.tooltipText then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.tooltipText)
        GameTooltip:Show()
    end
end

function DropdownButtonArtMixin:OnLeave()
    self.artOver = nil
    self:UpdateArt()
    if self.tooltipText then
        GameTooltip:Hide()
    end
end

function DropdownButtonArtMixin:OnMouseDown()
    self.artPressed = true
    self:UpdateArt()
end

function DropdownButtonArtMixin:OnMouseUp()
    self.artPressed = nil
    self:UpdateArt()
end

function DropdownButtonArtMixin:OnShow()
    self.artOver = nil
    self.artPressed = nil
    self:UpdateArt()
end

function DropdownButtonArtMixin:OnEnable()
    self:UpdateArt()
end

function DropdownButtonArtMixin:OnDisable()
    self:UpdateArt()
end

function DropdownButtonArtMixin:OnSizeChanged()
    self:UpdateArt()
end
