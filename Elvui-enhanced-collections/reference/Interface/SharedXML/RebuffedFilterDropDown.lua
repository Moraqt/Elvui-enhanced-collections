-- Reuse the filter data contract, with presentation owned by RebuffedMenu.
RebuffedFilterDropDownButtonMixin = CreateFromMixins(FilterDropDownButtonMixin)

function RebuffedFilterDropDownButtonMixin:OnLoad()
    CallbackRegistryMixin.OnLoad(self)
    self.filters, self.menuLists = {}, {}
    self.dropdownInfo = { { text = CLOSE, notCheckable = true, func = function() self:CloseMenu() end } }
    self:GenerateCallbackEvents({ "OnFilterChanged", "OnFilterCleared" })
end

function RebuffedFilterDropDownButtonMixin:Initialize()
    self.initialized = true
end

-- What the button opens. The default is the list the filter API built; a button whose rows
-- depend on what is on screen overrides this and builds them at open.
function RebuffedFilterDropDownButtonMixin:GetMenuEntries()
    return self.dropdownInfo, self.menuLists
end

function RebuffedFilterDropDownButtonMixin:ToggleMenu()
    if RebuffedMenu:IsOpen(self) then self:CloseMenu()
    else RebuffedMenu:Open(self, self:GetMenuEntries()) end
end

function RebuffedFilterDropDownButtonMixin:CloseMenu()
    RebuffedMenu:Close(self)
end

function RebuffedFilterDropDownButtonMixin:OnHide()
    self:CloseMenu()
end

function RebuffedFilterDropDownButtonMixin:SetFilter(key, enabled)
    self.filters[key] = enabled and enabled or nil
    self:TriggerEvent("OnFilterChanged", key, enabled)
    self:UpdateClearFilterButton()
    RebuffedMenu:Refresh(self)
end

function RebuffedFilterDropDownButtonMixin:SetToSingleFilter(key)
    wipe(self.filters)
    self:SetFilter(key, true)
end

function RebuffedFilterDropDownButtonMixin:ClearFilters()
    wipe(self.filters)
    self:TriggerEvent("OnFilterChanged")
    self:TriggerEvent("OnFilterCleared")
    self:UpdateClearFilterButton()
    RebuffedMenu:Refresh(self)
end

function RebuffedFilterDropDownButtonMixin:CreateFilterInfo(text, color, icon, condition, tooltip)
    text = _G[text] or text
    local info = { text = color and color:WrapText(text) or text, condition = condition, keepShownOnClick = true }
    if tooltip then info.tooltipTitle, info.tooltipText = info.text, _G[tooltip] or tooltip end
    if icon then
        if icon:find("\\") then info.icon = icon else info.iconAtlas = icon end
    end
    return info
end

function RebuffedFilterDropDownButtonMixin:AddCategoryOption(key, name, tooltip)
    local info = self:CreateFilterInfo(name, nil, nil, nil, tooltip)
    info.arg1 = key
    tinsert(self.dropdownInfo, #self.dropdownInfo, info)
end

function RebuffedFilterDropDownButtonMixin:AddOptionSpacer(condition)
    tinsert(self.dropdownInfo, #self.dropdownInfo, { isTitle = true, notCheckable = true, condition = condition })
end
