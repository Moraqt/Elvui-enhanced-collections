-- Private menu instances for Rebuffed controls. No UIDropDownMenu state is used.
RebuffedMenu = {}
local ROW_HEIGHT, PADDING = 22, 8
local function value(field)
    if type(field) == "function" then return field() end
    return field
end

function RebuffedMenu:Close(owner)
    if self.frame and (not owner or owner == self.owner) then
        self.frame:Hide()
        self.owner = nil
    end
end

function RebuffedMenu:IsOpen(owner)
    return self.frame and self.frame:IsShown() and self.owner == owner
end

-- Whether any menu is up, for a control that has to stand aside for one.
function RebuffedMenu:IsAnyOpen()
    return self.frame ~= nil and self.frame:IsShown()
end

function RebuffedMenu:HideDeeper(depth)
    for index = depth + 1, #self.panels do self.panels[index]:Hide() end
end

function RebuffedMenu:Activate(row)
    if row.disabled or not row.info then return end
    local info = row.info
    if not info.func and info.menuList and self.menus[info.menuList] then
        self:EnterSubmenu(row)
        return
    end
    -- Close before invoking actions: their callback can open a different menu.
    local owner = self.owner
    if not info.keepShownOnClick then self:Close(owner) end
    if info.func then info.func(row, info.arg1, info.arg2, row.checked) end
    if info.keepShownOnClick then self:Refresh(owner) end
end

function RebuffedMenu:Focus(row)
    if self.focus and self.focus ~= row then
        self.focus:UnlockHighlight()
        if GameTooltip:IsOwned(self.focus) then GameTooltip:Hide() end
    end
    self:HideDeeper(row.depth)
    self.focus = row
    if row.info.menuList and not row.disabled and self.menus[row.info.menuList] then
        self:ShowLevel(row.depth + 1, self.menus[row.info.menuList], row)
    end
    if row.info.tooltipTitle or row.info.tooltipText then
        GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
        GameTooltip:SetText(row.info.tooltipTitle or row.info.text or "")
        if row.info.tooltipText then GameTooltip:AddLine(row.info.tooltipText, 1, 1, 1, true) end
        GameTooltip:Show()
    end
end

function RebuffedMenu:EnterSubmenu(row)
    if row.disabled or not row.info.menuList or not self.menus[row.info.menuList] then return end
    local panel = self:ShowLevel(row.depth + 1, self.menus[row.info.menuList], row)
    for index = 1, panel.count do
        if not panel.rows[index].disabled then
            self:Focus(panel.rows[index])
            self.focus:LockHighlight()
            return
        end
    end
end

function RebuffedMenu:CreateRow(panel, index)
    local row = CreateFrame("Button", nil, panel)
    row:SetHeight(ROW_HEIGHT)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row.Text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.Text:SetPoint("LEFT", 24, 0)
    row.Text:SetPoint("RIGHT", -20, 0)
    row.Text:SetJustifyH("LEFT")
    row.Check = row:CreateTexture(nil, "ARTWORK")
    row.Check:SetSize(16, 16)
    row.Check:SetPoint("LEFT", 3, 0)
    row.Check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    row.Arrow = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.Arrow:SetPoint("RIGHT", -5, 0)
    row.Arrow:SetText(">")
    row.Icon = row:CreateTexture(nil, "ARTWORK")
    row.Icon:SetSize(16, 16)
    row.Icon:SetPoint("LEFT", 3, 0)
    row:SetScript("OnClick", function(button) self:Activate(button) end)
    row:SetScript("OnEnter", function(button) self:Focus(button) end)
    row:SetScript("OnLeave", function(button)
        if GameTooltip:IsOwned(button) then GameTooltip:Hide() end
    end)
    row:SetScript("OnHide", function(button)
        if GameTooltip:IsOwned(button) then GameTooltip:Hide() end
    end)
    panel.rows[index] = row
    return row
end

function RebuffedMenu:ShowLevel(depth, entries, anchor)
    local panel = self.panels[depth]
    if not panel then
        panel = CreateFrame("Frame", nil, self.frame)
        panel:SetFrameLevel(self.frame:GetFrameLevel() + depth * 2)
        panel:EnableMouse(true)
        panel:SetClampedToScreen(true)
        panel:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16,
            edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
        panel:SetBackdropColor(0.08, 0.07, 0.06, 0.98)
        panel:SetBackdropBorderColor(0.55, 0.48, 0.34, 1)
        panel.rows = {}
        self.panels[depth] = panel
    end
    panel.entries, panel.anchor = entries, anchor
    panel:ClearAllPoints()
    -- A select drops from its button's right edge, where the arrow is; a menu opened by a click
    -- on something drops from that thing's left edge, or it hangs off the panel it came from.
    if depth == 1 and self.align == "LEFT" then panel:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
    elseif depth == 1 then panel:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -2)
    else panel:SetPoint("TOPLEFT", anchor, "TOPRIGHT", -2, 8) end
    local count, width = 0, 170
    for _, info in ipairs(entries) do
        if info.condition == nil or value(info.condition) then
            count = count + 1
            local row = panel.rows[count] or self:CreateRow(panel, count)
            row.info, row.depth, row.value = info, depth, info.value
            row.checked = value(info.checked) and true or false
            row.disabled = value(info.disabled) or info.isTitle or (not info.func and not info.menuList)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", PADDING, -PADDING - (count - 1) * ROW_HEIGHT)
            row:SetPoint("RIGHT", -PADDING, 0)
            row.Text:SetText(info.text or "")
            row.Text:SetTextColor(row.disabled and 0.55 or 1, row.disabled and 0.55 or 0.82, row.disabled and 0.55 or 0.45)
            row.Check:SetShown(not info.notCheckable and row.checked)
            row.Arrow:SetShown(info.menuList ~= nil)
            row.Icon:Hide()
            if info.iconAtlas then row.Icon:SetAtlas(info.iconAtlas); row.Icon:Show()
            elseif info.icon then row.Icon:SetTexture(info.icon); row.Icon:Show() end
            width = math.max(width, row.Text:GetStringWidth() + 64)
            row:Show()
        end
    end
    for index = count + 1, #panel.rows do panel.rows[index]:Hide() end
    panel.count = count
    panel:SetSize(width, count * ROW_HEIGHT + PADDING * 2)
    panel:Show()
    return panel
end

function RebuffedMenu:Refresh(owner)
    if not self:IsOpen(owner) then return end
    for depth, panel in ipairs(self.panels) do
        if panel:IsShown() then self:ShowLevel(depth, panel.entries, panel.anchor) end
    end
end

function RebuffedMenu:OnKeyDown(key)
    if key == "ESCAPE" then self:Close(); return end
    local depth = self.focus and self.focus.depth or 1
    local panel = self.panels[depth]
    if key == "RIGHT" then
        if self.focus then self:EnterSubmenu(self.focus) end
    elseif key == "ENTER" or key == "SPACE" then
        if self.focus then self:Activate(self.focus) end
    elseif key == "LEFT" and depth > 1 then
        local anchor = panel.anchor
        self:HideDeeper(depth - 1)
        self.focus:UnlockHighlight()
        self.focus = anchor
        anchor:LockHighlight()
    elseif key == "DOWN" or key == "UP" then
        local current = key == "DOWN" and 0 or 1
        for index = 1, panel.count do if panel.rows[index] == self.focus then current = index end end
        for step = 1, panel.count do
            local index = ((current - 1 + (key == "DOWN" and step or -step)) % panel.count) + 1
            local row = panel.rows[index]
            if not row.disabled then
                if self.focus then self.focus:UnlockHighlight() end
                self:Focus(row)
                row:LockHighlight()
                return
            end
        end
    end
end

function RebuffedMenu:Open(owner, entries, menus, align)
    if not self.frame then
        local frame = CreateFrame("Frame", "RebuffedPrivateMenu", UIParent)
        frame:Hide()
        frame:SetAllPoints(UIParent)
        frame:SetFrameStrata("FULLSCREEN_DIALOG")
        frame:EnableMouse(true)
        frame:EnableKeyboard(true)
        frame:SetScript("OnMouseDown", function() self:Close() end)
        frame:SetScript("OnKeyDown", function(_, key) self:OnKeyDown(key) end)
        frame:SetScript("OnUpdate", function()
            if self.owner and not self.owner:IsVisible() then self:Close() end
        end)
        frame:SetScript("OnHide", function()
            if self.focus then self.focus:UnlockHighlight() end
            self.focus = nil
        end)
        tinsert(UISpecialFrames, "RebuffedPrivateMenu")
        self.frame, self.panels = frame, {}
    end
    self:Close()
    self.owner, self.menus, self.align = owner, menus or {}, align
    self:HideDeeper(0)
    self.frame:Show()
    self:ShowLevel(1, entries, owner)
end
