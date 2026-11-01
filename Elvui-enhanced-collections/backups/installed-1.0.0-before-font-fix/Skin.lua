local E = unpack(ElvUI)
local A = ElvUIEnhancedCollections
local S = E:GetModule("Skins")
local blank = E.media.blankTex or "Interface\\Buttons\\WHITE8x8"
local textColor, muted = { 0.91, 0.93, 0.95 }, { 0.52, 0.56, 0.60 }

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
        frame:SetTemplate("Default")
        A.frames[frame] = true
    end
    local color = inner and 0.045 or 0.075
    frame:SetBackdropColor(color, color + 0.006, color + 0.012, A:DB().opacity)
    frame:SetBackdropBorderColor(0.20, 0.22, 0.25, 1)
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
end

local function Button(button, glyph)
    if not button then return end
    if not button.ecButton then
        S:HandleButton(button)
        button.ecButton = true
        button:HookScript("OnEnable", ButtonFont)
        button:HookScript("OnDisable", ButtonFont)
    end
    ButtonFont(button)
    if glyph then
        if not button.ecGlyph then
            button.ecGlyph = button:CreateFontString(nil, "OVERLAY")
            button.ecGlyph:SetPoint("CENTER")
        end
        A:Font(button.ecGlyph, 2)
        button.ecGlyph:SetText(glyph)
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
        button.ecArrow:SetText("v")
    end
    A:Font(button.ecArrow, -1)
    button.ecArrow:SetTextColor(A:Accent())
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
    A:Font(box.Instructions)
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
    A:Font(frame.PageText)
end

local function Row(row)
    if not row then return end
    if not row.ecRow then
        row.ecRow = true
        Flat(row.Background, 0.075, 0.082, 0.095)
        local r, g, b = A:Accent()
        Flat(row.Selected or row.SelectedTexture, r, g, b, 0.25)
        local highlight = row.GetHighlightTexture and row:GetHighlightTexture() or row.HighlightTexture
        if highlight then Flat(highlight, r, g, b, 0.12) end
        Hide(row.IconBorder)
        if row.Icon then
            row.Icon:SetTexCoord(unpack(E.TexCoords))
            Edge(row, row.Icon, "ecIconBorder"):SetBackdropBorderColor(0.22, 0.25, 0.28, 1)
        end
        A:After(row, "SetEntry", Row)
    end
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
        if button.Icon then button.Icon:SetTexCoord(unpack(E.TexCoords)) end
        if button.IconUncollected then button.IconUncollected:SetTexCoord(unpack(E.TexCoords)) end
        if button.Highlight then Flat(button.Highlight, 1, 1, 1, 0.12) end
        A:After(button, "Update", Item)
    end
    A:Font(button.Name)
    A:Font(button.New, -2)
    local collected = button.Icon and button.Icon:IsShown()
    if button.Name then button.Name:SetTextColor(unpack(collected and textColor or muted)) end
    if button.IconUncollected then button.IconUncollected:SetAlpha(A:DB().uncollectedAlpha) end
    local r, g, b = A:Accent()
    button.ecBorder:SetBackdropBorderColor(collected and r or 0.20, collected and g or 0.22, collected and b or 0.25, 1)
    -- Cooldown, New, NewGlow and Favorite remain owned by the collection mixin.
end

local function ToyBox(panel)
    if not panel then return end
    Panel(panel.IconsFrame, true)
    Search(panel.SearchBox)
    SelectButton(panel.FilterButton)
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
    Progress(panel.ProgressBar)
    Paging(panel.PagingFrame)
    for _, button in ipairs(panel.buttons or {}) do Item(button) end
    for _, header in ipairs(panel.headers or {}) do A:Font(header, 1) end
end

local function ModelTile(model)
    if not model then return end
    Hide(model.Border)
    if not model.ecModel then
        model.ecModel = true
        Edge(model)
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
        else r, g, b = A:Accent() end
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
        A:Font(details.Name, 5)
        A:Font(details.LongName, 2)
        A:Font(details.Label, -1)
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
        tab.ecTab = true
        tab:HookScript("OnEnter", function(self) self.backdrop:SetBackdropBorderColor(A:Accent()) end)
        tab:HookScript("OnLeave", Tab)
    end
    A:Font(tab.Text or tab:GetFontString())
    local selected = tab.isSelected or tab.GetChecked and tab:GetChecked()
    local r, g, b = A:Accent()
    tab.backdrop:SetBackdropColor(0.075, 0.081, 0.087, 1)
    tab.backdrop:SetBackdropBorderColor(selected and r or 0.22, selected and g or 0.24, selected and b or 0.27, 1)
end

local function Tabs(journal)
    for _, tab in ipairs(journal.tabs or {}) do Tab(tab) end
end

local function Wardrobe()
    local frame = WardrobeCollectionFrame
    if not frame then return end
    Search(frame.searchBox)
    SelectButton(frame.FilterButton)
    Progress(frame.progressBar)
    Tab(frame.ItemsTab)
    Tab(frame.SetsTab)
    -- The wardrobe's legacy sub-tabs are Buttons, with selection tracked on the
    -- parent, rather than Collections' CheckButtons.
    if frame.activeFrame then
        local r, g, b = A:Accent()
        for _, tab in ipairs({ frame.ItemsTab, frame.SetsTab }) do
            local active = (tab == frame.ItemsTab and frame.activeFrame == frame.ItemsCollectionFrame)
                or (tab == frame.SetsTab and (frame.activeFrame == frame.SetsCollectionFrame or frame.activeFrame == frame.SetsTransmogFrame))
            if tab.backdrop then tab.backdrop:SetBackdropBorderColor(active and r or 0.22, active and g or 0.24, active and b or 0.27, 1) end
        end
    end
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
    A:Font(journal.TitleText, 2)
    if journal.TitleText then journal.TitleText:SetTextColor(unpack(textColor)) end
    Button(journal.CloseButton or _G.CollectionsJournalCloseButton, "x")
    Tabs(journal)
    local panel = journal.Journal
    if panel then
        Panel(panel.List, true)
        Panel(panel.Count)
        if panel.Count then
            panel.Count:SetWidth(190)
            A:Font(panel.Count.Label, -1)
            A:Font(panel.Count.Total, -1)
        end
        Panel(panel.Display, true)
        if panel.Display then
            Hide(panel.Display.Background)
            Hide(panel.Display.Model and panel.Display.Model.Background)
            local info = panel.Display.Info
            if info then A:Font(info.Name, 3); A:Font(info.Source, -1); A:Font(info.Description) end
            Button(panel.Display.RotateLeftButton, "<")
            Button(panel.Display.RotateRightButton, ">")
            if panel.Display.ShowPlayer then
                if not panel.Display.ShowPlayer.ecCheck then
                    S:HandleCheckBox(panel.Display.ShowPlayer)
                    panel.Display.ShowPlayer.ecCheck = true
                end
                local check = panel.Display.ShowPlayer
                A:Font(check.Text or check.text or check:GetFontString()
                    or (check:GetName() and _G[check:GetName() .. "Text"]))
            end
        end
        Search(panel.SearchBox)
        SelectButton(panel.FilterButton)
        Scroll(panel.List and panel.List.ScrollFrame)
        Button(panel.SummonButton)
        Button(panel.RandomFavoriteButton)
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
        menuSaved[panel] = nil
    end
end

local function MenuLevel(menu, depth)
    if not A:IsCollectionObject(menu.owner) then RestoreMenus(); return end
    local panel = menu.panels and menu.panels[depth]
    if not panel then return end
    if not menuSaved[panel] then
        menuSaved[panel] = { backdrop = panel:GetBackdrop(), color = { panel:GetBackdropColor() },
            border = { panel:GetBackdropBorderColor() }, fonts = {} }
    end
    local saved = menuSaved[panel]
    panel:SetBackdrop({ bgFile = blank, edgeFile = blank, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 } })
    panel:SetBackdropColor(0.075, 0.081, 0.087, 1)
    panel:SetBackdropBorderColor(0.22, 0.24, 0.27, 1)
    local width = panel:GetWidth()
    for _, row in ipairs(panel.rows or {}) do
        for _, label in ipairs({ row.Text, row.Arrow }) do
            if not saved.fonts[label] then saved.fonts[label] = { label:GetFont() } end
            A:Font(label)
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
    self.installed = true
    self:SkinAll()
    local journal, wardrobe = CollectionsJournal, WardrobeCollectionFrame
    journal:HookScript("OnShow", function() self:Refresh() end)
    wardrobe:HookScript("OnShow", Wardrobe)
    self:After(journal, "SelectTab", function() Tabs(journal); Journal() end)
    self:After(journal, "AddTab", function() Tabs(journal) end)
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
end
