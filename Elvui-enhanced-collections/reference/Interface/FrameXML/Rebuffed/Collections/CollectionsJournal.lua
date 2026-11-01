local MOUNTS_TAB = 1
local COMPANIONS_TAB = 2
local TOYS_TAB = 3
local HEIRLOOMS_TAB = 4

local MOUNT_FLAG_GROUND = 0x01
local MOUNT_FLAG_FLYING = 0x02
local MOUNT_FLAG_AQUATIC = 0x04

local ROW_HEIGHT = 46

local function ReadMount(id)
	local name, spellID, icon, isActive, isUsable, _, isFavorite, _, _, shouldHideOnChar, isCollected = C_MountJournal.GetMountInfoByID(id)
	return {
		id = id,
		name = name,
		spellID = spellID,
		icon = icon,
		isActive = isActive,
		isFavorite = isFavorite,
		shouldHideOnChar = shouldHideOnChar,
		isCollected = isCollected,
		-- Owned and within the level and Riding the mount asks: the one the server lets summon.
		isUsable = isUsable,
	}
end

local function ReadPet(id)
	local name, spellID, icon, isActive, _, _, isFavorite, isCollected, _, shouldHideOnChar = C_PetJournal.GetPetInfoByID(id)
	return {
		id = id,
		name = name,
		spellID = spellID,
		icon = icon,
		isActive = isActive,
		isFavorite = isFavorite,
		shouldHideOnChar = shouldHideOnChar,
		isCollected = isCollected,
		isUsable = isCollected,
	}
end

-- The button under the list says what the tab does with what is selected, as retail's does: a
-- mount is mounted and a companion is summoned. Both are dismissed.
local KINDS = {
	[MOUNTS_TAB] = { api = C_MountJournal, read = ReadMount, ids = "GetMountIDs", extra = "GetMountInfoExtraByID",
		total = TOTAL_MOUNTS, summon = MOUNT },
	[COMPANIONS_TAB] = { api = C_PetJournal, read = ReadPet, ids = "GetPetIDs", extra = "GetPetInfoExtraByID",
		total = TOTAL_COMPANIONS, summon = SUMMON },
}

--
-- Journal
--
CollectionsJournalMixin = {}

-- What the ring carries, per tab, and it is what retail carries: an icon. The era drew a model
-- there for a while -- a mount, a cat, the player -- and it was a mechanism to keep alive for a
-- 62-pixel circle. Three of these four are retail's own art, pulled with rb-casc because the era
-- has no icon of a mount journal, a pet journal or a chest of tiny glass animals; the wardrobe's
-- is the era's own, the same icon the transmogrifier's frame already wears.
local PORTRAITS = {
	[MOUNTS_TAB] = "Interface\\Icons\\MountJournalPortrait",
	[COMPANIONS_TAB] = "Interface\\Icons\\PetJournalPortrait",
	[TOYS_TAB] = "Interface\\Icons\\Trade_Archaeology_ChestofTinyGlassAnimals",
	[HEIRLOOMS_TAB] = "Interface\\Icons\\INV_Misc_EngGizmos_19",
	wardrobe = "Interface\\Icons\\INV_Chest_Cloth_17",
}

function CollectionsJournalMixin:OnLoad()
	-- The title names the tab, the way retail's does: "Mounts" rather than "Collections".
	-- SetPortrait already runs per tab, so the two travel together.
	self:RegisterForDrag("LeftButton")

	MixinAndLoad(self, "TabSystemMixin")
	self:SetTabTemplate("CollectionsTabTemplate")
	-- Retail's tabs stand apart from each other. Its own -16 is against a template that insets
	-- its art; the caps themselves carry no transparent bleed to spare -- measured, one pixel
	-- on the left of the inactive one and two on the right of the active -- so the same number
	-- here would overlap solid pixels, which is what it did.
	-- Measured on the caps: each carries about six pixels of transparent margin, so rects four
	-- pixels apart draw pills fifteen apart. Retail's tabs very nearly meet, which the rects can
	-- only do by overlapping.
	self:SetTabPadding(-8, 0)
	self:SetTabPoint("TOPLEFT", self, "BOTTOMLEFT", 11, 2)
	self:SetTabSelectedSound("igCharacterInfoTab")
	self:RegisterCallback("OnTabSelected", self.OnTabSelected, self)
	self:AddTab(MOUNTS, self.Journal)
	self:AddTab(COMPANIONS, self.Journal)
	self:AddTab(TOY_BOX, self.ToyBox)
	self:AddTab(HEIRLOOMS, self.Heirlooms)
end

function CollectionsJournalMixin:OnShow()
	PlaySound("igCharacterInfoOpen")
	if not self:GetCurrentTabID() then
		self:SelectTab(self:GetTabByID(MOUNTS_TAB), true)
	elseif self:GetCurrentTabID() == self.wardrobeTabID then
		-- The tab is already the selected one, so the tab system fires no OnTabSelected; after a
		-- visit to the transmogrifier the panel would stay parented to the hidden WardrobeFrame.
		self:OnTabSelected(self.wardrobeTabID)
	end
	UpdateMicroButtons()
end

function CollectionsJournalMixin:OnHide()
	PlaySound("igCharacterInfoClose")
	UpdateMicroButtons()
end

function CollectionsJournalMixin:SetPortrait(tabID)
	SetPortraitToTexture(self.portrait,
		tabID == self.wardrobeTabID and PORTRAITS.wardrobe or PORTRAITS[tabID])
	local tab = self:GetTabByID(tabID)
	if tab then
		self.TitleText:SetText(tab.Text:GetText())
	end
end

-- The two arrows under the preview model. A tap turns it one step, holding spins it; retail does
-- both and the era's own dress-up buttons only do the step.
--
-- The turn does not go through the era's Model_Rotate*: those move model.rotation with SetRotation,
-- and this model is driven by SetFacing, which is what its drag rotation and its OnLoad use. The
-- step and the sound are the era's.
local MODEL_ROTATION_STEP = 0.03
local MODEL_ROTATION_RATE = 1.4    -- radians a second while the button is held

local function TurnModel(button, amount)
	local model = button:GetParent().Model
	model:SetFacing(model:GetFacing() + button.rotateDirection * amount)
end

local function RotateButton_OnUpdate(button, elapsed)
	-- Released anywhere, not just over the button, ends the spin.
	if not IsMouseButtonDown("LeftButton") then
		button:SetScript("OnUpdate", nil)
		return
	end
	TurnModel(button, MODEL_ROTATION_RATE * elapsed)
end

function CollectionsRotateButton_OnMouseDown(button, direction)
	button.rotateDirection = direction
	TurnModel(button, MODEL_ROTATION_STEP)
	PlaySound("igInventoryRotateCharacter")
	button:SetScript("OnUpdate", RotateButton_OnUpdate)
end

-- The character in the saddle. The model is thrown away and made again on every SetCreature, so
-- what the box asks for is kept here and put back by ShowCreature; the widget method answers
-- whether the character is on it now, which is no while the model is still loading.
function CollectionsShowPlayer_OnClick(button)
	local panel = button:GetParent():GetParent()
	panel.showPlayer = button:GetChecked() and true or nil
	PlaySound(panel.showPlayer and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff")
	panel:RefreshShowPlayer()
end

function CollectionsRotateButton_OnMouseUp(button)
	button:SetScript("OnUpdate", nil)
end

function CollectionsJournalMixin:OnDragStart()
	self:StartMoving()
end

function CollectionsJournalMixin:OnDragStop()
	self:StopMovingOrSizing()
end

function CollectionsJournalMixin:OnTabSelected(tabID)
	-- The Appearances tab's panel is WardrobeCollectionFrame; the tab system shows it and hides
	-- the journal panel by itself. After a visit to the transmogrifier the panel is still parented
	-- to WardrobeFrame, so it is brought back here -- but only while the transmogrifier is closed:
	-- retail's CollectionsJournal_UpdateSelectedTab left the frame alone when WardrobeFrame had it.
	self:SetPortrait(tabID)
	if KINDS[tabID] then
		self.Journal:SetKind(tabID)
	elseif tabID == self.wardrobeTabID then
		if not (WardrobeFrame and WardrobeFrame:IsShown()) then
			WardrobeCollectionFrame_SetContainer(self)
		end
	end
end

--
-- Journal Panel
--
CollectionsJournalPanelMixin = {}

function CollectionsJournalPanelMixin:OnLoad()
	self.kind = MOUNTS_TAB
	self.entries = {}

	local scrollFrame = self.List.ScrollFrame
	-- The 44 is retail's view:SetPadding(0, 0, 44, 0, 0): the gutter the row's icon hangs in,
	-- outside the pill. The rows start after it and the pill fills what is left.
	RebuffedHybridScrollFrame_CreateButtons(scrollFrame, "CollectionsListButtonTemplate", 44, 0)
	scrollFrame.scrollBar.doNotHide = true
	scrollFrame.update = function()
		self:UpdateList()
	end

	-- The template's OnUpdate drives its Ctrl+F focus and modifier commands; the first needs
	-- IsKeyDown and the second C_Hook, and the world has neither.
	self.SearchBox:SetScript("OnUpdate", nil)

	-- Both sit inside the list frame, as retail's do. Regions of frames on one level are drawn
	-- layer by layer across the level, so the inset's border would cover the filter's own
	-- background art; a level of its own puts the button in front of the frame it sits in.
	local above = self.List:GetFrameLevel() + 5
	self.SearchBox:SetFrameLevel(above)
	self.FilterButton:SetFrameLevel(above)

	local filter = self.FilterButton
	local function isMounts()
		return self.kind == MOUNTS_TAB
	end
	filter:AddFilterOption("collected", filter:CreateFilterInfo(COLLECTIONS_FILTER_COLLECTED))
	filter:AddFilterOption("notcollected", filter:CreateFilterInfo(COLLECTIONS_FILTER_NOT_COLLECTED))
	filter:AddFilterOption("ground", filter:CreateFilterInfo(COLLECTIONS_FILTER_GROUND, nil, nil, isMounts))
	filter:AddFilterOption("flying", filter:CreateFilterInfo(COLLECTIONS_FILTER_FLYING, nil, nil, isMounts))
	filter:AddFilterOption("aquatic", filter:CreateFilterInfo(COLLECTIONS_FILTER_AQUATIC, nil, nil, isMounts))
	filter:RegisterCallback("OnFilterChanged", self.RefreshList, self)

	self:RefreshBackground()
end

function CollectionsJournalPanelMixin:OnShow()
	self:RegisterEvent("REBUFFED_COLLECTION_UPDATED")
	self:RegisterEvent("REBUFFED_CREATURE_CACHED")
	self:RegisterEvent("COMPANION_LEARNED")
	self:RegisterEvent("COMPANION_UNLEARNED")
	self:RegisterEvent("COMPANION_UPDATE")
	-- A mount owned but out of reach becomes usable with a Riding rank or a level.
	self:RegisterEvent("SKILL_LINES_CHANGED")
	self:RegisterEvent("PLAYER_LEVEL_UP")
	self:RefreshList()
end

function CollectionsJournalPanelMixin:OnHide()
	-- Whatever the cache was asked for, nobody is looking at the answer any more.
	self.waitingForCreature = nil
	self:SetDisplayState("empty")
	self.FilterButton:CloseMenu()
	self:UnregisterEvent("REBUFFED_COLLECTION_UPDATED")
	self:UnregisterEvent("REBUFFED_CREATURE_CACHED")
	self:UnregisterEvent("COMPANION_LEARNED")
	self:UnregisterEvent("COMPANION_UNLEARNED")
	self:UnregisterEvent("COMPANION_UPDATE")
	self:UnregisterEvent("SKILL_LINES_CHANGED")
	self:UnregisterEvent("PLAYER_LEVEL_UP")
end

function CollectionsJournalPanelMixin:OnEvent(event, arg1, arg2, arg3)
	if event == "REBUFFED_CREATURE_CACHED" then
		-- The creature asked for when the entry was shown; the widget could not draw it until now.
		-- A different creature is somebody else's answer and leaves this request waiting.
		-- The extension raises this only when a block arrived, and with the entry alone, so an
		-- absent second argument means it arrived. An explicit false is the refusal, which is what
		-- the failure state is for when the extension starts carrying it.
		if arg1 == self.waitingForCreature then
			if arg2 == false then
				self.waitingForCreature = nil
				self:SetDisplayState("failed")
			else
				self:ShowCreature(arg1)
			end
		end
	elseif event == "COMPANION_UPDATE" then
		self:RedrawList()
	else
		self:RefreshList()
	end
end

function CollectionsJournalPanelMixin:GetKind()
	return KINDS[self.kind]
end

function CollectionsJournalPanelMixin:GetAPI()
	return KINDS[self.kind].api
end

function CollectionsJournalPanelMixin:GetExtra(id)
	local kind = self:GetKind()
	return kind.api[kind.extra](id)
end

function CollectionsJournalPanelMixin:SetKind(kind)
	self.kind = kind
	self.selectedID = nil
	self.Count.Label:SetText(KINDS[kind].total)
	self:RefreshBackground()
	self.SearchBox:SetText("")
	self.FilterButton:ClearFilters()
	self:RefreshShowPlayer()
	self:RefreshList()
end

function CollectionsJournalPanelMixin:RefreshBackground()
	-- The size is written by hand because the client writes its own over the anchors. Measured on
	-- this pane: two corner anchors give 409x536, and after the texture is set some files leave
	-- that alone (the era's PetDressUpBackground) while others replace it with the file's own
	-- dimensions (retail's MountJournal-BG, 512x512). Re-anchoring afterwards does not undo it, so
	-- the pane's size is put back explicitly. This is a compensation, not geometry.
	local display = self.Display
	local atlas = self.kind == MOUNTS_TAB and "collections-background-mount"
		or "DressUpBackground-pet-beast"

	-- Twice, and not by accident. The pane's own copy is what shows when the model is hidden --
	-- nothing selected, waiting for the cache, refused -- and the model's copy is what shows when
	-- it is drawn, because this era's Model widget clears its viewport to black and has no
	-- SetBackgroundColor to stop it. Retail needs only the first.
	for _, background in ipairs({ display.Background, display.Model.Background }) do
		background:SetAtlas(atlas)
		background:SetSize(display:GetWidth() - 4, display:GetHeight() - 4)
	end

end

function CollectionsJournalPanelMixin:GetEntry(index)
	return self.entries[index]
end

function CollectionsJournalPanelMixin:GetSelectedEntry()
	for _, entry in ipairs(self.entries) do
		if entry.id == self.selectedID then
			return entry
		end
	end
end

function CollectionsJournalPanelMixin:GetSourceText(id)
	local _, _, sourceText = self:GetExtra(id)
	return sourceText
end

function CollectionsJournalPanelMixin:RefreshList()
	local kind = self:GetKind()
	local filter = self.FilterButton
	local search = strtrim(self.SearchBox:GetText()):lower()
	local stateFiltered = filter:IsFiltered("collected") or filter:IsFiltered("notcollected")
	local typeMask = 0
	if self.kind == MOUNTS_TAB then
		if filter:IsFiltered("ground") then
			typeMask = bit.bor(typeMask, MOUNT_FLAG_GROUND)
		end
		if filter:IsFiltered("flying") then
			typeMask = bit.bor(typeMask, MOUNT_FLAG_FLYING)
		end
		if filter:IsFiltered("aquatic") then
			typeMask = bit.bor(typeMask, MOUNT_FLAG_AQUATIC)
		end
	end

	wipe(self.entries)
	-- Retail's mount journal counts one thing, what the account owns, and prints it beside
	-- "Total Mounts"; there is no denominator on this tab.
	local collected = 0
	-- What the character knows comes first and in name order, the way retail lists both journals;
	-- what it does not keeps the order the ids arrive in. Two lists rather than one sort, because
	-- table.sort is not stable: a comparator that only looks at the state would shuffle the
	-- unknown group, and one that falls back on the name would sort a group this does not order.
	local known, unknown = {}, {}
	for _, id in ipairs(kind.api[kind.ids]()) do
		local entry = kind.read(id)
		if entry.isCollected then
			collected = collected + 1
		end

		local shown = entry.isCollected or not entry.shouldHideOnChar
		if shown and stateFiltered then
			shown = filter:IsFiltered(entry.isCollected and "collected" or "notcollected")
		end
		if shown and typeMask ~= 0 then
			local _, _, _, _, mountTypeID = self:GetExtra(id)
			shown = bit.band(mountTypeID, typeMask) ~= 0
		end
		if shown and search ~= "" then
			shown = entry.name:lower():find(search, 1, true) ~= nil
		end
		if shown then
			tinsert(entry.isCollected and known or unknown, entry)
		end
	end

	table.sort(known, function(a, b) return (a.name or "") < (b.name or "") end)
	for _, entry in ipairs(known) do
		tinsert(self.entries, entry)
	end
	for _, entry in ipairs(unknown) do
		tinsert(self.entries, entry)
	end

	self.Count.Total:SetText(collected)
	self:RefreshSelection()
end

function CollectionsJournalPanelMixin:RedrawList()
	local kind = self:GetKind()
	for index, entry in ipairs(self.entries) do
		self.entries[index] = kind.read(entry.id)
	end
	self:RefreshSelection()
end

function CollectionsJournalPanelMixin:UpdateList()
	local scrollFrame = self.List.ScrollFrame
	local offset = RebuffedHybridScrollFrame_GetOffset(scrollFrame)
	for i, button in ipairs(scrollFrame.buttons) do
		local entry = self.entries[offset + i]
		if entry then
			button:SetEntry(entry)
			button:Show()
		else
			button:Hide()
		end
	end
	RebuffedHybridScrollFrame_Update(scrollFrame, #self.entries * ROW_HEIGHT, scrollFrame:GetHeight())
end

function CollectionsJournalPanelMixin:RefreshSelection()
	self:UpdateList()
	self:RefreshDisplay(self:GetSelectedEntry())
end

function CollectionsJournalPanelMixin:SetSelectedEntry(entry)
	self.selectedID = entry.id
	self:UpdateList()
	self:RefreshDisplay(entry)
end

-- The pane answers four states, and the era needs all four: nothing selected, waiting for the
-- creature cache, drawn, and the cache refused. An empty DressUpModel draws the player untextured,
-- so anything short of "ready" has to hide the model rather than leave what was there. The
-- background is the pane's own and stays whatever the state is, which is why it moved off the model.
function CollectionsJournalPanelMixin:SetDisplayState(state)
	self.displayState = state
	self.Display.Model:SetShown(state == "ready")
	self.Display.Spinner:SetShown(state == "loading")
end

function CollectionsJournalPanelMixin:ShowCreature(creatureID)
	self.waitingForCreature = nil
	self.Display.Model:SetCreature(creatureID)
	self.Display.Model:ResetValues()
	self:SetDisplayState("ready")
	self:RefreshShowPlayer()
end

-- Only the mounts offer it, the way retail does: the panel is shared with the companions, and a
-- battle pet has nobody to carry. The tab gates the character as well as the box -- hiding the box
-- alone left a character ticked on the mounts sitting on the next companion shown.
function CollectionsJournalPanelMixin:RefreshShowPlayer()
	local box = self.Display.ShowPlayer
	local mounts = self.kind == MOUNTS_TAB
	box:SetShown(mounts)
	box:SetChecked(self.showPlayer)
	self.Display.Model:SetShowPlayer(mounts and self.showPlayer and self.displayState == "ready")
end

function CollectionsJournalPanelMixin:RefreshDisplay(entry)
	local display = self.Display
	if ( not entry ) then
		self.waitingForCreature = nil
		self:SetDisplayState("empty")
		display.Info:Hide()
		self.SummonButton:SetText(self:GetKind().summon)
		self.SummonButton:Disable()
		return
	end

	display.Info.Name:SetText(entry.name)
	-- The description as the spell tooltip formats it, a mount's $j speeds included.
	local creatureID, description, sourceText = self:GetExtra(entry.id)
	display.Info.Source:SetText(sourceText)
	display.Info.Description:SetText(description or "")
	display.Info:Show()

	self.SummonButton:SetText(entry.isActive and PET_DISMISS or self:GetKind().summon)
	self.SummonButton:SetEnabled(entry.isActive or entry.isUsable)

	if ( creatureID == 0 ) then
		self.waitingForCreature = nil
		self:SetDisplayState("empty")
		return
	end

	-- Ask the cache rather than the widget: SetCreature on a creature the client has not loaded
	-- leaves the model empty, and an empty one is the player. REBUFFED_CREATURE_CACHED says when.
	if ( self:GetAPI().GetCreatureCacheStatus(creatureID) == "ready" ) then
		self:ShowCreature(creatureID)
	else
		self.waitingForCreature = creatureID
		self:SetDisplayState("loading")
	end
end

function CollectionsJournalPanelMixin:ToggleSummon(entry)
	if not entry.isCollected then
		return
	end
	local api = self:GetAPI()
	if entry.isActive then
		api.Dismiss()
	else
		api.SummonByID(entry.id)
	end
end

function CollectionsJournalPanelMixin:SummonSelected()
	local entry = self:GetSelectedEntry()
	if entry then
		self:ToggleSummon(entry)
	end
end

function CollectionsJournalPanelMixin:SummonRandomFavorite()
	self:GetAPI().SummonByID(0)
end

function CollectionsJournalPanelMixin:ToggleFavorite(entry)
	self:GetAPI().SetIsFavorite(entry.id, not entry.isFavorite)
end

function CollectionsJournalPanelMixin:Pickup(entry)
	if entry.isCollected then
		self:GetAPI().Pickup(entry.id)
	end
end

--
-- List Button
--
CollectionsListButtonMixin = {}

function CollectionsListButtonMixin:OnLoad()
	self.panel = self:GetParent():GetParent():GetParent():GetParent()
	self:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	self:RegisterForDrag("LeftButton")
	-- The icon sits in the gutter, outside the pill, so the row's own rectangle does not cover it.
	-- Without this the icon is neither clickable nor draggable, which it is in retail.
	self:SetHitRectInsets(-44, 0, 0, 0)
	self.Background:SetAtlas("PetList-ButtonBackground")
	self.Selected:SetAtlas("PetList-ButtonSelect")
	self:SetHighlightAtlas("PetList-ButtonHighlight")
	self.Favorite.Icon:SetAtlas("collections-icon-favorites")
end

function CollectionsListButtonMixin:SetEntry(entry)
	self.entry = entry

	self.Icon:SetTexture(entry.icon)
	self.Icon:SetDesaturated(not entry.isCollected)
	-- Owned but not usable by this character yet, in retail's red.
	if entry.isCollected and not entry.isUsable then
		self.Icon:SetVertexColor(1, 0.25, 0.25)
	else
		self.Icon:SetVertexColor(1, 1, 1)
	end
	self.Name:SetText(entry.name)
	self.Name:SetFontObject(entry.isCollected and GameFontNormal or GameFontDisable)
	self.Selected:SetShown(entry.id == self.panel.selectedID)

	local isFavorite, canSetFavorite = self.panel:GetAPI().GetIsFavorite(entry.id)
	self.Favorite:SetShown(canSetFavorite)
	self.Favorite.Icon:SetAlpha(isFavorite and 1 or 0.3)
end

function CollectionsListButtonMixin:OnClick(button)
	-- A mount and a companion are spells here, so there is no item link to hand to
	-- HandleModifiedItemClick. What goes in the chat box is a link of the collection's own type,
	-- carrying the spell id: clicking it shows what this window shows about the thing rather than
	-- the spell's tooltip. Collected or not, the entry exists and retail links either. It returns
	-- either way, because with no chat box open the link goes nowhere and a click that was meant to
	-- link one must not summon it instead.
	if IsModifiedClick("CHATLINK") then
		if self.entry.spellID then
			local linkType = self.panel.kind == MOUNTS_TAB and "mount" or "battlepet"
			ChatEdit_InsertLink(CollectionLink(linkType, self.entry.spellID, self.entry.name))
		end
		return
	end

	if button == "RightButton" then
		self.panel:ToggleSummon(self.entry)
	else
		self.panel:SetSelectedEntry(self.entry)
	end
end

function CollectionsListButtonMixin:OnDoubleClick()
	self.panel:ToggleSummon(self.entry)
end

function CollectionsListButtonMixin:OnDragStart()
	self.panel:Pickup(self.entry)
end

function CollectionsListButtonMixin:OnEnter()
	if not self.entry.isCollected then
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(self.entry.name)
		GameTooltip:AddLine(self.panel:GetSourceText(self.entry.id), 1, 1, 1, true)
		GameTooltip:Show()
	end
end

function CollectionsListButtonMixin:OnLeave()
	GameTooltip:Hide()
end

function CollectionsListButtonMixin:ToggleFavorite()
	self.panel:ToggleFavorite(self.entry)
end
