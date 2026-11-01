local E = unpack(ElvUI)
local A = ElvUIEnhancedCollections
local S = E:GetModule("Skins")
local blank = E.media.blankTex or "Interface\\Buttons\\WHITE8x8"
local textColor, muted = { 0.91, 0.93, 0.95 }, { 0.62, 0.66, 0.71 }
local border = { 0.24, 0.27, 0.31, 1 }

local function Label(label, offset, color)
    A:Font(label, offset)
    if label then label:SetTextColor(unpack(color or textColor)) end
end

local function Hide(texture)
    if texture and texture.SetAlpha then texture:SetAlpha(0) end
end

local function HideArt(frame)
    if not frame or not frame.GetRegions then return end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region:IsObjectType("Texture") then Hide(region) end
    end
end

local function Flat(texture, r, g, b, alpha)
    if not texture then return end
    texture:SetTexture(blank)
    texture:SetTexCoord(0, 1, 0, 1)
    texture:SetVertexColor(r, g, b, alpha or 1)
end

local function Panel(frame, inner)
    if not frame then return end
    if not A.frames[frame] then
        HideArt(frame)
        Hide(frame.NineSlice)
        -- CollectionsBackgroundTemplate has two named decorative child frames
        -- in addition to its own regions; neither owns an input or model.
        local name = frame:GetName()
        if name then
            Hide(_G[name .. "ShadowOverlay"])
            Hide(_G[name .. "InsetOverlay"])
        end
        frame:SetTemplate("Default")
        A.frames[frame] = true
    end
    local color = inner and 0.075 or 0.105
    frame:SetBackdropColor(color, color + 0.01, color + 0.022, A:DB().opacity)
    frame:SetBackdropBorderColor(unpack(border))
end

local function Edge(frame, relative, key)
    key = key or "ecBorder"
    if not frame[key] then
        local edge = CreateFrame("Frame", nil, frame)
        edge:EnableMouse(false)
        edge:SetTemplate("Default")
        edge:SetPoint("TOPLEFT", relative or frame, "TOPLEFT", -1, 1)
        edge:SetPoint("BOTTOMRIGHT", relative or frame, "BOTTOMRIGHT", 1, -1)
        edge:SetFrameLevel(frame:GetFrameLevel() + 1)
        edge:SetBackdropColor(0, 0, 0, 0)
        frame[key] = edge
    end
    return frame[key]
end

local function ButtonFont(button)
    local label = button.Text or button:GetFontString()
    A:Font(label)
    if label then label:SetTextColor(unpack(button:IsEnabled() and textColor or muted)) end
    if button.ecGlyph then
        button.ecGlyph:SetTextColor(unpack(button:IsEnabled() and textColor or muted))
        button.ecGlyph:SetAlpha(button:IsEnabled() and 1 or 0.4)
    end
end

local function ButtonSurface(button)
    button:SetBackdropColor(0.13, 0.145, 0.165, 1)
    button:SetBackdropBorderColor(unpack(border))
end

local function Button(button, glyph)
    if not button then return end
    if not button.ecButton then
        S:HandleButton(button)
        button.ecButton = true
        button:HookScript("OnEnable", ButtonFont)
        button:HookScript("OnDisable", ButtonFont)
        button:HookScript("OnLeave", ButtonSurface)
    end
    ButtonSurface(button)
    ButtonFont(button)
    if glyph then
        if not button.ecGlyph then
            button.ecGlyph = button:CreateFontString(nil, "OVERLAY")
            button.ecGlyph:SetPoint("CENTER")
        end
        A:Font(button.ecGlyph, 2)
        button.ecGlyph:SetText(glyph)
        local native = button:GetFontString()
        if native then native:SetAlpha(0) end
        ButtonFont(button)
    end
end

local function SelectButton(button)
    if not button then return end
    if not button.ecSelect then
        HideArt(button)
        button.ecSelect = true
    end
    Button(button)
    if not button.ecArrow then
        button.ecArrow = button:CreateFontString(nil, "OVERLAY")
        button.ecArrow:SetPoint("RIGHT", -7, 0)
        A:Font(button.ecArrow, -1)
        button.ecArrow:SetText("v")
    end
    A:Font(button.ecArrow, -1)
    button.ecArrow:SetTextColor(unpack(muted))
    local clear = button.ClearFilterButton
    if clear then Button(clear, "x") end
end

local function Search(box)
    if not box then return end
    if not box.ecSearch then
        HideArt(box)
        S:HandleEditBox(box)
        box.ecSearch = true
    end
    A:Font(box)
    Label(box.Instructions, 0, muted)
    if box.backdrop then
        box.backdrop:SetBackdropColor(0.065, 0.075, 0.088, 1)
        box.backdrop:SetBackdropBorderColor(unpack(border))
    end
    -- Search and clear icons belong to the edit box and keep their scripts.
    if box.searchIcon then box.searchIcon:SetAlpha(0.7) end
end

local function Progress(bar)
    if not bar then return end
    Hide(bar.border)
    if not bar.ecProgress then
        bar:SetStatusBarTexture(blank)
        Edge(bar)
        bar.ecProgress = true
    end
    bar:SetStatusBarColor(A:Accent())
    A:Font(bar.text, -1)
end

local function Paging(frame)
    if not frame then return end
    Button(frame.PrevPageButton, "<")
    Button(frame.NextPageButton, ">")
    frame.PrevPageButton:SetSize(26, 26)
    frame.NextPageButton:SetSize(26, 26)
    Label(frame.PageText, 0, muted)
end

local function Row(row)
    if not row then return end
    if not row.ecRow then
        row.ecRow = true
        Flat(row.Background, 0.09, 0.10, 0.115)
        local r, g, b = A:Accent()
        Flat(row.Selected or row.SelectedTexture, r, g, b, 0.14)
        local highlight = row.GetHighlightTexture and row:GetHighlightTexture() or row.HighlightTexture
        if highlight then Flat(highlight, 1, 1, 1, 0.055) end
        Hide(row.IconBorder)
        if row.Icon then
            row.Icon:SetTexCoord(unpack(E.TexCoords))
            Edge(row, row.Icon, "ecIconBorder"):SetBackdropBorderColor(0.22, 0.25, 0.28, 1)
        end
        row.ecSelection = row:CreateTexture(nil, "OVERLAY")
        row.ecSelection:SetPoint("TOPLEFT", 0, -3)
        row.ecSelection:SetPoint("BOTTOMLEFT", 0, 3)
        row.ecSelection:SetWidth(2)
        A:After(row, "SetEntry", Row)
    end
    Flat(row.ecSelection, A:Accent())
    local selected = row.Selected or row.SelectedTexture
    row.ecSelection:SetShown(selected and selected:IsShown() or false)
    A:Font(row.Name)
    A:Font(row.Label, -1)
    if row.entry and row.Name then
        row.Name:SetTextColor(unpack(row.entry.isCollected and textColor or muted))
    end
end

local function Rows(scroll)
    if not scroll then return end
    for _, row in ipairs(scroll.buttons or {}) do Row(row) end
end

-- Rebuffed uses a proportional Button-based scrollbar, not a Blizzard Slider.
-- Retain its thumb geometry, steppers, drag handlers and update implementation.
local function Scroll(scroll)
    if not scroll then return end
    local bar = scroll.scrollBar
    if bar then
        for _, texture in ipairs({ bar:GetRegions() }) do
            if texture:IsObjectType("Texture") then
                -- Recolour existing scrollbar art without changing its dimensions.
                texture:SetVertexColor(0.48, 0.53, 0.59)
            end
        end
        if bar.Thumb then
            for _, texture in ipairs({ bar.Thumb:GetRegions() }) do
                if texture:IsObjectType("Texture") then texture:SetVertexColor(0.58, 0.64, 0.70) end
            end
        end
    end
    -- The native steppers are small; keep their normal/disabled art and hit areas.
    Rows(scroll)
end

local function Item(button)
    if not button then return end
    if not button.ecItem then
        button.ecItem = true
        Hide(button.SlotFrameCollected)
        Hide(button.SlotFrameUncollected)
        Hide(button.SlotFrameUncollectedInnerGlow)
        Edge(button, button.Icon or button)
        button.ecCard = button:CreateTexture(nil, "BACKGROUND")
        button.ecCard:SetPoint("TOPLEFT", -4, 4)
        button.ecCard:SetPoint("BOTTOMRIGHT", button, "BOTTOMLEFT", 192, -4)
        Flat(button.ecCard, 0.105, 0.118, 0.135)
        if button.Icon then button.Icon:SetTexCoord(unpack(E.TexCoords)) end
        if button.IconUncollected then
            button.IconUncollected:SetTexCoord(unpack(E.TexCoords))
            if button.Icon then button.IconUncollected:SetAllPoints(button.Icon) end
        end
        if button.Highlight then Flat(button.Highlight, 1, 1, 1, 0.12) end
        A:After(button, "Update", Item)
    end
    A:Font(button.Name)
    A:Font(button.New, -2)
    local collected = button.Icon and button.Icon:IsShown()
    if button.Name then button.Name:SetTextColor(unpack(collected and textColor or muted)) end
    if button.IconUncollected then button.IconUncollected:SetAlpha(A:DB().uncollectedAlpha) end
    button.ecBorder:SetBackdropBorderColor(collected and 0.40 or 0.23, collected and 0.45 or 0.26, collected and 0.50 or 0.30, 1)
    -- Cooldown, New, NewGlow and Favorite remain owned by the collection mixin.
end

local function ToyBox(panel)
    if not panel then return end
    Panel(panel.IconsFrame, true)
    Search(panel.SearchBox)
    SelectButton(panel.FilterButton)
    panel.SearchBox:SetHeight(24)
    panel.FilterButton:SetHeight(24)
    panel.FilterButton:ClearAllPoints()
    panel.FilterButton:SetPoint("LEFT", panel.SearchBox, "RIGHT", 4, 0)
    Progress(panel.ProgressBar)
    Paging(panel.PagingFrame)
    for i = 1, 18 do Item(panel.IconsFrame["Button" .. i]) end
end

local function Heirlooms(panel)
    if not panel then return end
    Panel(panel.IconsFrame, true)
    Search(panel.SearchBox)
    SelectButton(panel.FilterButton)
    SelectButton(panel.ClassDropDown)
    panel.SearchBox:SetHeight(24)
    panel.FilterButton:SetHeight(24)
    panel.FilterButton:ClearAllPoints()
    panel.FilterButton:SetPoint("LEFT", panel.SearchBox, "RIGHT", 4, 0)
    panel.ClassDropDown:SetHeight(24)
    panel.ClassDropDown:ClearAllPoints()
    panel.ClassDropDown:SetPoint("LEFT", panel, "TOPLEFT", 70, -26)
    Progress(panel.ProgressBar)
    Paging(panel.PagingFrame)
    for _, button in ipairs(panel.buttons or {}) do Item(button) end
    for _, header in ipairs(panel.headers or {}) do Label(header, 1) end
end

local function ModelTile(model)
    if not model then return end
    Hide(model.Border)
    if not model.ecModel then
        model.ecModel = true
        Edge(model)
        -- Only the native background layer is recoloured. Model rendering,
        -- lighting, desaturation, camera and transmog indicators stay native.
        for _, texture in ipairs({ model:GetRegions() }) do
            if texture:IsObjectType("Texture") and texture:GetDrawLayer() == "BACKGROUND" then
                Flat(texture, 0.105, 0.118, 0.135)
            end
        end
        local r, g, b = A:Accent()
        if model.HighlightTexture then
            Flat(model.HighlightTexture, r, g, b, 0.15)
            model.HighlightTexture:SetAllPoints(model)
        end
    end
    local info = model.visualInfo
    local r, g, b = 0.21, 0.24, 0.28
    if info and info.isCollected then
        if info.isUsable == false then r, g, b = 0.85, 0.22, 0.22
        else r, g, b = 0.35, 0.40, 0.46 end
    end
    model.ecBorder:SetBackdropBorderColor(r, g, b, 1)
    A:Font(model.NewString, -2)
    -- No calls to SetModel, SetUnit, SetCreature, TryOn, lighting or camera APIs.
    -- Pending/current transmog textures, stars and hide-visual marks stay intact.
end

local function Models(panel)
    if not panel then return end
    Panel(panel, true)
    Paging(panel.PagingFrame)
    A:Font(panel.NoValidItemsLabel, 1)
    A:Font(panel.NoValidSetsLabel, 1)
    SelectButton(panel.WeaponDropDown)
    for _, model in ipairs(panel.Models or {}) do ModelTile(model) end
    if panel.SlotsFrame then
        for _, slot in ipairs({ panel.SlotsFrame:GetChildren() }) do
            -- Navigation icons and their selected rings are meaningful, so keep them.
            if slot:IsObjectType("Button") then A:Font(slot:GetFontString()) end
        end
    end
end

local function Sets(panel)
    if not panel then return end
    Panel(panel.LeftInset, true)
    Panel(panel.RightInset, true)
    Scroll(panel.ScrollFrame)
    local details = panel.DetailsFrame
    if details then
        Hide(details.ModelFadeTexture)
        Hide(details.IconRowBackground)
        Label(details.Name, 5)
        Label(details.LongName, 2)
        Label(details.Label, -1, muted)
        SelectButton(details.VariantSetsButton)
        if details.itemFramesPool then
            for item in details.itemFramesPool:EnumerateActive() do
                if item.Icon then
                    item.Icon:SetTexCoord(unpack(E.TexCoords))
                    -- Keep the native quality border and ownership alpha.
                end
            end
        end
    end
end

local function IsSelected(tab)
    local w = WardrobeCollectionFrame
    if w and tab == w.ItemsTab then return w.activeFrame == w.ItemsCollectionFrame end
    if w and tab == w.SetsTab then
        return w.activeFrame == w.SetsCollectionFrame or w.activeFrame == w.SetsTransmogFrame
    end
    return tab.isSelected or tab.GetChecked and tab:GetChecked()
end

local function Tab(tab)
    if not tab then return end
    if not tab.ecTab then
        HideArt(tab)
        -- ThreeSlice updates its art during selection; alpha survives SetAtlas.
        Hide(tab.Left)
        Hide(tab.Middle)
        Hide(tab.Right)
        tab:CreateBackdrop("Default")
        tab.backdrop:ClearAllPoints()
        tab.backdrop:SetPoint("TOPLEFT", 5, -4)
        tab.backdrop:SetPoint("BOTTOMRIGHT", -5, 4)
        tab.ecUnderline = tab:CreateTexture(nil, "OVERLAY")
        tab.ecUnderline:SetPoint("BOTTOMLEFT", tab.backdrop, "BOTTOMLEFT", 1, 0)
        tab.ecUnderline:SetPoint("BOTTOMRIGHT", tab.backdrop, "BOTTOMRIGHT", -1, 0)
        tab.ecUnderline:SetHeight(2)
        tab.ecTab = true
        tab:HookScript("OnEnter", function(self)
            self.backdrop:SetBackdropColor(0.16, 0.18, 0.21, 1)
            Label(self.Text or self:GetFontString())
        end)
        tab:HookScript("OnLeave", Tab)
        A:After(tab, "UpdateButton", Tab)
        A:After(tab, "SetTabSelected", Tab)
        A:After(tab, "UpdateWidth", function(self)
            if self.ecWidth then self:SetWidth(self.ecWidth) end
        end)
    end
    local selected = IsSelected(tab)
    Label(tab.Text or tab:GetFontString(), 0, selected and textColor or muted)
    tab.backdrop:SetBackdropColor(selected and 0.15 or 0.105, selected and 0.17 or 0.118, selected and 0.20 or 0.135, 1)
    tab.backdrop:SetBackdropBorderColor(unpack(border))
    Flat(tab.ecUnderline, A:Accent())
    tab.ecUnderline:SetShown(selected and true or false)
end

local function Tabs(journal)
    local tabs = journal.tabs or {}
    if #tabs == 0 then return end
    local width = math.floor((journal:GetWidth() - 16) / #tabs)
    for i, tab in ipairs(tabs) do
        Tab(tab)
        tab.ecWidth = width
        tab:SetSize(width, 34)
        tab:ClearAllPoints()
        tab:SetPoint("TOPLEFT", journal, "BOTTOMLEFT", 8 + (i - 1) * width, 0)
        if tab.Text then
            tab.Text:ClearAllPoints()
            tab.Text:SetPoint("CENTER", tab, "CENTER", 0, 0)
        end
    end
end

local function Wardrobe()
    local frame = WardrobeCollectionFrame
    if not frame then return end
    if not frame.ecTabClicks then
        -- XML stores the original click function before global post-hooks are
        -- installed. A script hook runs after its final legacy TabResize call.
        frame.ItemsTab:HookScript("OnClick", Wardrobe)
        frame.SetsTab:HookScript("OnClick", Wardrobe)
        frame.ecTabClicks = true
    end
    Search(frame.searchBox)
    SelectButton(frame.FilterButton)
    frame.searchBox:SetHeight(24)
    frame.FilterButton:SetHeight(24)
    frame.FilterButton:ClearAllPoints()
    frame.FilterButton:SetPoint("LEFT", frame.searchBox, "RIGHT", 4, 0)
    Progress(frame.progressBar)
    Tab(frame.ItemsTab)
    Tab(frame.SetsTab)
    -- The wardrobe panel is reparented at the transmogrifier. Anchor only its
    -- own sub-tabs to itself, keeping the client-owned surrounding layout.
    frame.ItemsTab:SetSize(76, 32)
    frame.ItemsTab:ClearAllPoints()
    frame.ItemsTab:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -28)
    frame.SetsTab:SetSize(76, 32)
    frame.SetsTab:ClearAllPoints()
    frame.SetsTab:SetPoint("LEFT", frame.ItemsTab, "RIGHT", 0, 0)
    for _, tab in ipairs({ frame.ItemsTab, frame.SetsTab }) do
        local label = tab.Text or tab:GetFontString()
        if label then
            label:ClearAllPoints()
            label:SetPoint("CENTER", tab, "CENTER", 0, 0)
        end
    end
    -- Native progress positioning follows the old tab's origin. Give it a
    -- stable anchor so the collection counter stays clear of both sub-tabs.
    frame.progressBar:ClearAllPoints()
    frame.progressBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 253, -39)
    Models(frame.ItemsCollectionFrame)
    Models(frame.SetsTransmogFrame)
    Sets(frame.SetsCollectionFrame)
end

local function Journal()
    local journal = CollectionsJournal
    Panel(journal)
    Hide(journal.portrait)
    Hide(journal.PortraitFrame)
    Hide(journal.portraitFrame)
    if not journal.ecHeader then
        journal.ecHeader = journal:CreateTexture(nil, "BACKGROUND")
        journal.ecHeader:SetPoint("TOPLEFT", 1, -1)
        journal.ecHeader:SetPoint("TOPRIGHT", -1, -1)
        journal.ecHeader:SetHeight(27)
        Flat(journal.ecHeader, 0.14, 0.155, 0.175)
        journal.ecNavigation = journal:CreateTexture(nil, "BACKGROUND")
        journal.ecNavigation:SetPoint("TOPLEFT", journal, "BOTTOMLEFT", 0, 0)
        journal.ecNavigation:SetPoint("TOPRIGHT", journal, "BOTTOMRIGHT", 0, 0)
        journal.ecNavigation:SetHeight(36)
        Flat(journal.ecNavigation, 0.105, 0.115, 0.127)
    end
    Label(journal.TitleText, 2)
    if journal.TitleText then
        journal.TitleText:ClearAllPoints()
        journal.TitleText:SetPoint("LEFT", journal, "TOPLEFT", 16, -14)
    end
    local close = journal.CloseButton or _G.CollectionsJournalCloseButton
    Button(close, "x")
    if close then
        close:SetSize(22, 22)
        close:ClearAllPoints()
        close:SetPoint("TOPRIGHT", journal, "TOPRIGHT", -5, -3)
    end
    Tabs(journal)
    local panel = journal.Journal
    if panel then
        Panel(panel.List, true)
        Panel(panel.Count)
        if panel.Count then
            panel.Count:SetSize(240, 24)
            panel.Count:ClearAllPoints()
            panel.Count:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -8)
            panel.Count:SetBackdropColor(0, 0, 0, 0)
            panel.Count:SetBackdropBorderColor(0, 0, 0, 0)
            Label(panel.Count.Label, 0, muted)
            Label(panel.Count.Total)
        end
        Panel(panel.Display, true)
        if panel.Display then
            Hide(panel.Display.Background)
            Hide(panel.Display.Model and panel.Display.Model.Background)
            local info = panel.Display.Info
            if info then
                Label(info.Name, 3)
                Label(info.Source, -1, muted)
                Label(info.Description, 0, muted)
                -- The native description is wider than its panel. Insets keep
                -- long mount names and wrapped text away from the border.
                for _, label in ipairs({ info.Name, info.Source, info.Description }) do
                    label:SetWidth(math.max(120, panel.Display:GetWidth() - 28))
                end
            end
            Button(panel.Display.RotateLeftButton, "<")
            Button(panel.Display.RotateRightButton, ">")
            panel.Display.RotateLeftButton:SetSize(26, 26)
            panel.Display.RotateRightButton:SetSize(26, 26)
            if panel.Display.ShowPlayer then
                if not panel.Display.ShowPlayer.ecCheck then
                    S:HandleCheckBox(panel.Display.ShowPlayer)
                    panel.Display.ShowPlayer.ecCheck = true
                end
                local check = panel.Display.ShowPlayer
                Label(check.Text or check.text or check:GetFontString()
                    or (check:GetName() and _G[check:GetName() .. "Text"]))
            end
        end
        Search(panel.SearchBox)
        SelectButton(panel.FilterButton)
        panel.SearchBox:SetHeight(24)
        panel.FilterButton:SetHeight(24)
        panel.SearchBox:ClearAllPoints()
        panel.SearchBox:SetPoint("TOPLEFT", panel.List, "TOPLEFT", 12, -8)
        panel.FilterButton:ClearAllPoints()
        panel.FilterButton:SetPoint("TOPRIGHT", panel.List, "TOPRIGHT", -5, -8)
        Scroll(panel.List and panel.List.ScrollFrame)
        Button(panel.SummonButton)
        Button(panel.RandomFavoriteButton)
        panel.SummonButton:SetSize(260, 24)
        panel.RandomFavoriteButton:SetHeight(24)
        panel.RandomFavoriteButton:ClearAllPoints()
        panel.RandomFavoriteButton:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -8)
    end
    ToyBox(journal.ToyBox)
    Heirlooms(journal.Heirlooms)
end

-- RebuffedMenu is shared by the whole client. Save and restore only presentation
-- while a Collections owner uses it, so unrelated menus retain their own style.
local menuSaved = setmetatable({}, { __mode = "k" })
local function RestoreMenus()
    for panel, saved in pairs(menuSaved) do
        panel:SetBackdrop(saved.backdrop)
        panel:SetBackdropColor(unpack(saved.color))
        panel:SetBackdropBorderColor(unpack(saved.border))
        for label, font in pairs(saved.fonts) do label:SetFont(unpack(font)) end
        for label, color in pairs(saved.colors) do label:SetTextColor(unpack(color)) end
        menuSaved[panel] = nil
    end
end

local function MenuLevel(menu, depth)
    if not A:IsCollectionObject(menu.owner) then RestoreMenus(); return end
    local panel = menu.panels and menu.panels[depth]
    if not panel then return end
    if not menuSaved[panel] then
        menuSaved[panel] = { backdrop = panel:GetBackdrop(), color = { panel:GetBackdropColor() },
            border = { panel:GetBackdropBorderColor() }, fonts = {}, colors = {} }
    end
    local saved = menuSaved[panel]
    panel:SetBackdrop({ bgFile = blank, edgeFile = blank, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 } })
    panel:SetBackdropColor(0.105, 0.118, 0.135, 1)
    panel:SetBackdropBorderColor(unpack(border))
    local width = panel:GetWidth()
    for _, row in ipairs(panel.rows or {}) do
        for _, label in ipairs({ row.Text, row.Arrow }) do
            if not saved.fonts[label] then saved.fonts[label] = { label:GetFont() } end
            if not saved.colors[label] then saved.colors[label] = { label:GetTextColor() } end
            Label(label, 0, row.disabled and muted or textColor)
        end
        if row.Text then width = math.max(width, row.Text:GetStringWidth() + 64) end
    end
    panel:SetWidth(width)
end

function A:SkinAll()
    Journal()
    Wardrobe()
end

function A:Install()
    if self.installed then return end
    self:SkinAll()
    local journal, wardrobe = CollectionsJournal, WardrobeCollectionFrame
    journal:HookScript("OnShow", function() self:Refresh() end)
    wardrobe:HookScript("OnShow", Wardrobe)
    self:After(journal, "SelectTab", function() Tabs(journal); Journal() end)
    self:After(journal, "AddTab", function() Tabs(journal) end)
    self:After(journal, "UpdateTabLayout", function() Tabs(journal) end)
    self:After(journal.Journal, "RefreshBackground", function(panel)
        Hide(panel.Display.Background)
        Hide(panel.Display.Model.Background)
    end)
    self:After(journal.Journal, "UpdateList", function(panel) Rows(panel.List.ScrollFrame) end)
    self:After(journal.ToyBox, "UpdateButtons", function(panel) ToyBox(panel) end)
    self:After(journal.Heirlooms, "LayoutCurrentPage", Heirlooms)
    self:After(wardrobe.ItemsCollectionFrame, "UpdateItems", Models)
    self:After(wardrobe.SetsTransmogFrame, "UpdateSets", Models)
    self:After(wardrobe.SetsCollectionFrame.ScrollFrame, "Update", Rows)
    self:After(wardrobe.SetsCollectionFrame, "DisplaySet", Sets)
    self:After(_G, "WardrobeCollectionFrame_SetTab", Wardrobe)
    if RebuffedMenu then
        self:After(RebuffedMenu, "ShowLevel", MenuLevel)
        self:After(RebuffedMenu, "Close", RestoreMenus)
    end
    self.installed = true
end
