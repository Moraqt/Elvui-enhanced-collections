RegisterForSavePerCharacter("RebuffedWardrobeLastOutfit");

-- Rebuffed Wardrobe
-- Retail 7.3.5's Blizzard_Wardrobe.lua on the era's widgets, driven by the extension's
-- C_TransmogCollection, C_TransmogSets and C_Transmog. See client-old/docs/APPEARANCES.md.

local REMOVE_TRANSMOG_ID = 0;

-- 7.3.5's Constants.lua entries the Wardrobe reads, with the ranged slot the era still has.
TRANSMOG_SLOTS = {
	[1]  = { slot = "HEADSLOT",          transmogType = LE_TRANSMOG_TYPE_APPEARANCE, armorCategoryID = LE_TRANSMOG_COLLECTION_TYPE_HEAD },
	[2]  = { slot = "SHOULDERSLOT",      transmogType = LE_TRANSMOG_TYPE_APPEARANCE, armorCategoryID = LE_TRANSMOG_COLLECTION_TYPE_SHOULDER },
	[3]  = { slot = "BACKSLOT",          transmogType = LE_TRANSMOG_TYPE_APPEARANCE, armorCategoryID = LE_TRANSMOG_COLLECTION_TYPE_BACK },
	[4]  = { slot = "CHESTSLOT",         transmogType = LE_TRANSMOG_TYPE_APPEARANCE, armorCategoryID = LE_TRANSMOG_COLLECTION_TYPE_CHEST },
	[5]  = { slot = "TABARDSLOT",        transmogType = LE_TRANSMOG_TYPE_APPEARANCE, armorCategoryID = LE_TRANSMOG_COLLECTION_TYPE_TABARD },
	[6]  = { slot = "SHIRTSLOT",         transmogType = LE_TRANSMOG_TYPE_APPEARANCE, armorCategoryID = LE_TRANSMOG_COLLECTION_TYPE_SHIRT },
	[7]  = { slot = "WRISTSLOT",         transmogType = LE_TRANSMOG_TYPE_APPEARANCE, armorCategoryID = LE_TRANSMOG_COLLECTION_TYPE_WRIST },
	[8]  = { slot = "HANDSSLOT",         transmogType = LE_TRANSMOG_TYPE_APPEARANCE, armorCategoryID = LE_TRANSMOG_COLLECTION_TYPE_HANDS },
	[9]  = { slot = "WAISTSLOT",         transmogType = LE_TRANSMOG_TYPE_APPEARANCE, armorCategoryID = LE_TRANSMOG_COLLECTION_TYPE_WAIST },
	[10] = { slot = "LEGSSLOT",          transmogType = LE_TRANSMOG_TYPE_APPEARANCE, armorCategoryID = LE_TRANSMOG_COLLECTION_TYPE_LEGS },
	[11] = { slot = "FEETSLOT",          transmogType = LE_TRANSMOG_TYPE_APPEARANCE, armorCategoryID = LE_TRANSMOG_COLLECTION_TYPE_FEET },
	[12] = { slot = "MAINHANDSLOT",      transmogType = LE_TRANSMOG_TYPE_APPEARANCE },
	[13] = { slot = "SECONDARYHANDSLOT", transmogType = LE_TRANSMOG_TYPE_APPEARANCE },
	[14] = { slot = "RANGEDSLOT",        transmogType = LE_TRANSMOG_TYPE_APPEARANCE },
	[15] = { slot = "MAINHANDSLOT",      transmogType = LE_TRANSMOG_TYPE_ILLUSION },
	[16] = { slot = "SECONDARYHANDSLOT", transmogType = LE_TRANSMOG_TYPE_ILLUSION },
};
local TRANSMOGRIFY_FONT_COLOR = CreateColor(1, 0.5, 1);
local ENCHANT_EMPTY_SLOT_ICON = "Interface\\Icons\\INV_Scroll_05";
local WARDROBE_TOOLTIP_CYCLE_ARROW_ICON = "|TInterface\\Transmogrify\\transmog-tooltip-arrow:12:11:-1:-1|t";
local WARDROBE_TOOLTIP_CYCLE_SPACER_ICON = "|TInterface\\Common\\spacer:12:11:-1:-1|t";
local MODELFRAME_DRAG_ROTATION_CONSTANT = 0.010;

-- The era's dress-up window shown the way DressUpItemLink shows it, then dressed through the
-- extension's TryOn, which needs no item cache and carries an illusion.
local function WardrobeDressUp(sourceID, slot, illusionID)
	if ( not DressUpFrame:IsShown() ) then
		ShowUIPanel(DressUpFrame);
		DressUpModel:SetUnit("player");
	end
	DressUpModel:TryOn(sourceID, slot and GetInventorySlotInfo(slot) or nil, illusionID);
end

-- ************************************************************************************************************************************************************
-- **** MAIN **********************************************************************************************************************************************
-- ************************************************************************************************************************************************************

function WardrobeFrame_OnLoad(self)
	SetPortraitToTexture(WardrobeFramePortrait, "Interface\\Icons\\INV_Chest_Cloth_17");
	WardrobeFrameTitleText:SetText(TRANSMOGRIFY);
	self:RegisterForDrag("LeftButton");
end

function WardrobeFrame_OnDragStart(self)
	self:StartMoving();
end

function WardrobeFrame_OnDragStop(self)
	self:StopMovingOrSizing();
end

-- Walking away from the transmogrifier closes his window, the way it closes a merchant's. The era
-- client does that for its own windows and cannot do it for this one -- it has no interaction unit
-- to measure against, the server having answered the right-click with a message of its own -- so
-- the frame asks the extension, which kept the NPC's guid, and closes the session the same way the
-- close button does. Twice a second is often enough for a player on foot.
local WARDROBE_RANGE_CHECK = 0.5;

function WardrobeFrame_OnUpdate(self, elapsed)
	self.rangeCheck = (self.rangeCheck or 0) + elapsed;
	if ( self.rangeCheck < WARDROBE_RANGE_CHECK ) then
		return;
	end
	self.rangeCheck = 0;
	if ( not C_Transmog.IsAtTransmogrifier() ) then
		C_Transmog.Close();
	end
end

function WardrobeFrame_IsAtTransmogrifier()
	return WardrobeFrame and WardrobeFrame:IsShown();
end

-- ************************************************************************************************************************************************************
-- **** TRANSMOG **********************************************************************************************************************************************
-- ************************************************************************************************************************************************************

function WardrobeTransmogFrame_OnLoad(self)
	local race, fileName = UnitRace("player");
	local atlas = "transmog-background-race-"..fileName;
	self.Inset.BG:SetAtlas(atlas);

	self:RegisterEvent("TRANSMOGRIFY_UPDATE");
	self:RegisterEvent("TRANSMOGRIFY_SUCCESS");
end

function WardrobeTransmogFrame_OnEvent(self, event, ...)
	if ( event == "TRANSMOGRIFY_UPDATE" ) then
		local slotID, transmogType = ...;
		local slotButton = WardrobeTransmogFrame_GetSlotButton(slotID, transmogType);
		if ( slotButton ) then
			local isTransmogrified, hasPending, isPendingCollected, canTransmogrify, cannotTransmogrifyReason, hasUndo = C_Transmog.GetSlotInfo(slotID, slotButton.transmogType);
			if ( hasUndo ) then
				PlaySound("igMainMenuOptionCheckBoxOff");
			elseif ( not hasPending ) then
				if ( slotButton.hadUndo ) then
					PlaySound("igMainMenuOptionCheckBoxOn");
					slotButton.hadUndo = nil;
				end
			end
		elseif ( not slotID ) then
			-- the event without a slot follows the server's answer to an apply (and a clear)
			WardrobeTransmogFrame_ReportApplyErrors();
		end
		StaticPopup_Hide("TRANSMOG_APPLY_WARNING");
		self.dirty = true;
	elseif ( event == "PLAYER_EQUIPMENT_CHANGED" ) then
		C_Transmog.ValidateAllPending();
	elseif ( event == "TRANSMOGRIFY_SUCCESS" ) then
		local slotID, transmogType = ...;
		local slotButton = WardrobeTransmogFrame_GetSlotButton(slotID, transmogType);
		if ( slotButton ) then
			WardrobeTransmogFrame_AnimateSlotButton(slotButton);
			WardrobeTransmogFrame_UpdateSlotButton(slotButton);
			-- transmogging a weapon might allow/disallow enchants
			if ( slotButton.slot == "MAINHANDSLOT" ) then
				WardrobeTransmogFrame_UpdateSlotButton(WardrobeTransmogFrame.Model.MainHandEnchantButton);
			elseif ( slotButton.slot == "SECONDARYHANDSLOT" ) then
				WardrobeTransmogFrame_UpdateSlotButton(WardrobeTransmogFrame.Model.SecondaryHandEnchantButton);
			end
			WardrobeTransmogFrame_UpdateApplyButton();
		end
	end
end

-- The server's codes for a refused apply, as the lines the era can show (R28); the names are
-- TransmogMessages.hpp's. The whole-message results (1-6) arrive on every sent slot when the whole
-- apply was refused, the per-slot ones (10-26) otherwise; a name with no line of its own -- Refused,
-- CostChanged, NotAtTransmogrifier, Disabled, NothingToApply -- is shown as the plain refusal.
local TRANSMOG_APPLY_ERROR_TEXT = {
	NotEnoughMoney = "ERR_NOT_ENOUGH_MONEY",
	NotCollected = "TRANSMOGRIFY_STYLE_UNCOLLECTED",
	IllusionNotCollected = "TRANSMOGRIFY_STYLE_UNCOLLECTED",
	CannotUseSource = "ERR_TRANSMOGRIFY_CANT_EQUIP",
	ItemTypesDontMatch = "ERR_TRANSMOGRIFY_MISMATCH",
	ArmorTypesDontMatch = "ERR_TRANSMOGRIFY_MISMATCH",
	WeaponTypesDontMatch = "ERR_TRANSMOGRIFY_MISMATCH",
	EquipSlotsDontMatch = "ERR_TRANSMOGRIFY_MISMATCH",
	LegendaryNeedsWhitemanePlus = "TRANSMOGRIFY_INVALID_LEGENDARY_PLUS",
	UnknownSource = "ERR_TRANSMOGRIFY_INVALID_SOURCE",
	SourceNotAllowed = "ERR_TRANSMOGRIFY_INVALID_SOURCE",
	UnknownIllusion = "ERR_TRANSMOGRIFY_INVALID_SOURCE",
	TargetNotAllowed = "TRANSMOGRIFY_INVALID_DESTINATION",
	InvalidSlot = "TRANSMOGRIFY_INVALID_DESTINATION",
	EmptySlot = "TRANSMOGRIFY_INVALID_DESTINATION",
	HiddenOnlyArmor = "TRANSMOGRIFY_INVALID_DESTINATION",
	IllusionSlot = "TRANSMOGRIFY_INVALID_DESTINATION",
	IllusionNeedsMeleeWeapon = "TRANSMOGRIFY_INVALID_DESTINATION",
};

function WardrobeTransmogFrame_GetSlotErrorText(slotButton)
	local code, name = C_Transmog.GetSlotUseError(slotButton.slotID, slotButton.transmogType);
	if ( not code ) then
		return nil;
	end
	return _G[TRANSMOG_APPLY_ERROR_TEXT[name] or "TRANSMOGRIFY_APPLY_REFUSED"];
end

function WardrobeTransmogFrame_ReportApplyErrors()
	for i = 1, #WardrobeTransmogFrame.Model.SlotButtons do
		local text = WardrobeTransmogFrame_GetSlotErrorText(WardrobeTransmogFrame.Model.SlotButtons[i]);
		if ( text ) then
			UIErrorsFrame:AddMessage(text, RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b, 1.0);
			return;
		end
	end
end

function WardrobeTransmogFrame_OnShow(self)
	HideUIPanel(CollectionsJournal);
	WardrobeCollectionFrame_SetContainer(WardrobeFrame);

	PlaySound("igMainMenuOpen");
	self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED");
	WardrobeTransmogFrame.Model:SetUnit("player");
	WardrobeTransmogFrame.Model:ResetValues();

	WardrobeTransmogFrame_Update(self);
end

function WardrobeTransmogFrame_OnHide(self)
	PlaySound("igMainMenuClose");
	StaticPopup_Hide("TRANSMOG_APPLY_WARNING");
	self:UnregisterEvent("PLAYER_EQUIPMENT_CHANGED");
	-- SetTransmogrifierAppearancesShown drives the collected filter here and the menu does not
	-- offer it at an NPC, so an NPC with nothing transmogrifiable would leave it off for the
	-- Collections tab.
	C_TransmogCollection.SetCollectedShown(true);
	C_Transmog.Close();
end

function WardrobeTransmogFrameModel_OnLoad(self)
	MixinAndLoad(self, "ModelMixin");
	self:SetEnableDragRotation(true);
	self:SetEnableScrollZoom(true);
	self:SetMinMaxDistance(-1.4, 1.4);
	self.ClearAllPendingButton.Icon:SetAtlas("transmog-icon-revert-small", true);
end

function WardrobeTransmogFrame_OnUpdate(self)
	if ( self.dirty ) then
		self.dirty = nil;
		WardrobeTransmogFrame_Update(self);
	end
end

function WardrobeTransmogFrame_Update()
	for i = 1, #WardrobeTransmogFrame.Model.SlotButtons do
		WardrobeTransmogFrame_UpdateSlotButton(WardrobeTransmogFrame.Model.SlotButtons[i]);
	end
	WardrobeTransmogFrame_UpdateWeaponModel("MAINHANDSLOT");
	WardrobeTransmogFrame_UpdateWeaponModel("SECONDARYHANDSLOT");
	WardrobeTransmogFrame_UpdateApplyButton();
	WardrobeTransmogFrame.OutfitDropDown:UpdateSaveButton();
	
	if ( not WardrobeTransmogFrame.selectedSlotButton or WardrobeTransmogFrame.selectedSlotButton:IsEnabled() ~= 1 ) then
		-- select first valid slot or clear selection
		local validButton;
		for i = 1, #WardrobeTransmogFrame.Model.SlotButtons do
			local button = WardrobeTransmogFrame.Model.SlotButtons[i];
			if ( button:IsEnabled() == 1 and button.transmogType == LE_TRANSMOG_TYPE_APPEARANCE ) then
				validButton = WardrobeTransmogFrame.Model.SlotButtons[i];
				break;
			end
		end
		WardrobeTransmogButton_Select(validButton);
	else
		WardrobeTransmogButton_Select(WardrobeTransmogFrame.selectedSlotButton);
	end
end

function WardrobeTransmogFrame_UpdateSlotButton(slotButton)
	local slotID, defaultTexture = GetInventorySlotInfo(slotButton.slot);
	local isTransmogrified, hasPending, isPendingCollected, canTransmogrify, cannotTransmogrifyReason, hasUndo, isHideVisual, texture = C_Transmog.GetSlotInfo(slotID, slotButton.transmogType);
	local hasChange = (hasPending and canTransmogrify) or hasUndo;
	local errorText = WardrobeTransmogFrame_GetSlotErrorText(slotButton);

	if ( slotButton.transmogType == LE_TRANSMOG_TYPE_APPEARANCE ) then
		if ( canTransmogrify or hasChange ) then
			slotButton.Icon:SetTexture(texture);
			slotButton.NoItemTexture:Hide();
		else
			local tag = TRANSMOG_INVALID_CODES[cannotTransmogrifyReason];
			if ( tag  == "NO_ITEM" ) then
				slotButton.Icon:SetTexture(defaultTexture);
			else
				slotButton.Icon:SetTexture(texture);
			end
			slotButton.NoItemTexture:Show();
		end
	else
		-- check for weapons lacking visual attachments
		local correspondingWeaponButton = WardrobeTransmogFrame_GetSlotButton(slotButton.slotID, LE_TRANSMOG_TYPE_APPEARANCE);
		local sourceID = WardrobeTransmogFrame_GetDisplayedSource(correspondingWeaponButton);
		if ( sourceID ~= NO_TRANSMOG_SOURCE_ID and not WardrobeCollectionFrame_CanEnchantSource(sourceID) ) then
			if ( hasPending or hasUndo ) then
				-- clear anything in the enchant slot, otherwise cost and Apply button state will still reflect anything pending
				C_Transmog.ClearPending(slotButton.slotID, slotButton.transmogType);
			end
			isTransmogrified = false;	-- handle legacy, this weapon could have had an illusion applied previously
			canTransmogrify = false;
			slotButton.invalidWeapon = true;
		else
			slotButton.invalidWeapon = false;
		end

		if ( hasPending or hasUndo or canTransmogrify ) then
			slotButton.Icon:SetTexture(texture or ENCHANT_EMPTY_SLOT_ICON);
			slotButton.NoItemTexture:Hide();
		else
			slotButton.Icon:SetTexture(0, 0, 0);
			slotButton.NoItemTexture:Show();
		end
	end
	slotButton:SetEnabled(canTransmogrify or hasUndo);

	-- the red border for what the server refused; the pink one for a pending or applied change
	if ( errorText ) then
		WardrobeTransmogButton_SetStatusBorder(slotButton, "RED");
	elseif ( hasPending ) then
		if ( hasUndo or (isPendingCollected and canTransmogrify) ) then
			WardrobeTransmogButton_SetStatusBorder(slotButton, "PINK");
		else
			WardrobeTransmogButton_SetStatusBorder(slotButton, "NONE");
		end
	else
		if ( isTransmogrified and not hasChange and not slotButton.AnimFrame:IsShown() ) then
			WardrobeTransmogButton_SetStatusBorder(slotButton, "PINK");
		else
			WardrobeTransmogButton_SetStatusBorder(slotButton, "NONE");
		end
	end

	-- show ants frame is the item has a pending transmogrification and is not animating
	if ( hasChange and (hasUndo or isPendingCollected) and not slotButton.AnimFrame:IsShown() ) then
		slotButton.PendingFrame:Show();
		if ( hasUndo ) then
			slotButton.PendingFrame.Undo:Show();
		else
			slotButton.PendingFrame.Undo:Hide();
		end
	else
		slotButton.PendingFrame:Hide();
	end

	if ( isHideVisual and not hasUndo ) then
		if ( slotButton.HiddenVisualIcon ) then
			slotButton.HiddenVisualCover:Show();
			slotButton.HiddenVisualIcon:Show();
		end
		local baseTexture = GetInventoryItemTexture("player", slotID);
		slotButton.Icon:SetTexture(baseTexture);
	else
		if ( slotButton.HiddenVisualIcon ) then
			slotButton.HiddenVisualCover:Hide();
			slotButton.HiddenVisualIcon:Hide();
		end
	end

	local showModel = (slotButton.transmogType == LE_TRANSMOG_TYPE_APPEARANCE);
	if ( slotButton.slot == "MAINHANDSLOT" or slotButton.slot == "SECONDARYHANDSLOT" or slotButton.slot == "RANGEDSLOT" ) then
		-- weapons get done in WardrobeTransmogFrame_UpdateWeaponModel to package item and enchant together;
		-- the ranged slot is not drawn on the model at all (R24)
		showModel = false;
	end
	if ( showModel ) then
		local sourceID = WardrobeTransmogFrame_GetDisplayedSource(slotButton);
		if ( sourceID == NO_TRANSMOG_SOURCE_ID ) then
			WardrobeTransmogFrame.Model:UndressSlot(slotID);			
		else
			-- only update if different
			local existingAppearanceSourceID = WardrobeTransmogFrame.Model:GetSlotTransmogSources(slotID);
			if ( existingAppearanceSourceID ~= sourceID ) then
				WardrobeTransmogFrame.Model:TryOn(sourceID);
			end
		end
	end
end

function WardrobeTransmogFrame_UpdateWeaponModel(slot)
	local weaponSlotButton, enchantSlotButton;
	if ( slot == "MAINHANDSLOT" ) then
		weaponSlotButton = WardrobeTransmogFrame.Model.MainHandButton;
		enchantSlotButton = WardrobeTransmogFrame.Model.MainHandEnchantButton;
	else
		weaponSlotButton = WardrobeTransmogFrame.Model.SecondaryHandButton;
		enchantSlotButton = WardrobeTransmogFrame.Model.SecondaryHandEnchantButton;
	end
	local slotID = GetInventorySlotInfo(slot);
	local appearanceSourceID = WardrobeTransmogFrame_GetDisplayedSource(weaponSlotButton);
	if ( slot == "SECONDARYHANDSLOT" and appearanceSourceID ~= NO_TRANSMOG_SOURCE_ID ) then
		local mainSource = C_TransmogCollection.GetSourceInfo(WardrobeTransmogFrame_GetDisplayedSource(WardrobeTransmogFrame.Model.MainHandButton));
		local offSource = C_TransmogCollection.GetSourceInfo(appearanceSourceID);
		-- Match the native hand conflict without re-equipping an offhand it just removed.
		if ( mainSource and mainSource.invType == 17 and offSource and
			(offSource.invType == 14 or offSource.invType == 22 or offSource.invType == 23) ) then
			appearanceSourceID = NO_TRANSMOG_SOURCE_ID;
		end
	end
	if ( appearanceSourceID ~= NO_TRANSMOG_SOURCE_ID ) then
		local illusionSourceID = WardrobeTransmogFrame_GetDisplayedSource(enchantSlotButton);
		-- check existing equipped on model. we don't want to update it if the same because the hand will open/close.
		local existingAppearanceSourceID, existingIllustionSourceID = WardrobeTransmogFrame.Model:GetSlotTransmogSources(slotID);
		if ( existingAppearanceSourceID ~= appearanceSourceID or existingIllustionSourceID ~= illusionSourceID ) then
			-- don't specify a slot when applying or removing ranged weapons because of bows
			local categoryID = C_TransmogCollection.GetAppearanceSourceInfo(appearanceSourceID);
			local existingCategoryID = C_TransmogCollection.GetAppearanceSourceInfo(existingAppearanceSourceID);
			if ( WardrobeUtils_IsCategoryRanged(categoryID) or WardrobeUtils_IsCategoryRanged(existingCategoryID) ) then
				slot = nil;
			end
			WardrobeTransmogFrame.Model:TryOn(appearanceSourceID, slot and slotID or nil, illusionSourceID);
		end
	else
		WardrobeTransmogFrame.Model:UndressSlot(slotID);
	end
end

function WardrobeTransmogFrame_GetDisplayedSource(slotButton)
	local baseSourceID, baseVisualID, appliedSourceID, appliedVisualID, pendingSourceID, pendingVisualID, hasPendingUndo = C_Transmog.GetSlotVisualInfo(GetInventorySlotInfo(slotButton.slot), slotButton.transmogType);
	if ( pendingSourceID ~= REMOVE_TRANSMOG_ID ) then
		return pendingSourceID;
	elseif ( hasPendingUndo or appliedSourceID == NO_TRANSMOG_SOURCE_ID ) then
		return baseSourceID;
	else
		return appliedSourceID;
	end	
end

function WardrobeTransmogFrame_AnimateSlotButton(slotButton)
	-- don't do anything if this button is already animating;
	if ( slotButton.AnimFrame:IsShown() ) then
		return;
	end
	local isTransmogrified = C_Transmog.GetSlotInfo(slotButton.slotID, slotButton.transmogType);
	if ( isTransmogrified ) then
		slotButton.AnimFrame.Transition:Show();
	else
		slotButton.AnimFrame.Transition:Hide();
	end
	slotButton.AnimFrame:Show();
	WardrobeTransmogButton_PlayAnim(slotButton);
end

function WardrobeTransmogButton_PlayAnim(slotButton)
	local frame = slotButton.AnimFrame;
	frame.OuterGlow.Anim:Play();
	frame.Transition.Anim:Play();
	frame.Glow.Anim:Play();
end

function WardrobeTransmogFrame_UpdateApplyButton()
	local cost, numChanges = C_Transmog.GetCost();
	local canApply;
	if ( cost > GetMoney() ) then
		SetMoneyFrameColor("WardrobeTransmogMoneyFrame", "red");
	else
		SetMoneyFrameColor("WardrobeTransmogMoneyFrame");
		if (numChanges > 0 ) then
			canApply = true;
		end
	end
	if ( C_Transmog.IsApplying() or StaticPopup_FindVisible("TRANSMOG_APPLY_WARNING") ) then
		canApply = false;
	end
	MoneyFrame_Update("WardrobeTransmogMoneyFrame", cost);
	WardrobeTransmogFrame.ApplyButton:SetEnabled(canApply);
	WardrobeTransmogFrame.Model.ClearAllPendingButton:SetShown(canApply);
end

function WardrobeTransmogFrame_GetSlotButton(slotID, transmogType)
	for i = 1, #WardrobeTransmogFrame.Model.SlotButtons do
		local slotButton = WardrobeTransmogFrame.Model.SlotButtons[i];
		if ( slotButton.slotID == slotID and slotButton.transmogType == transmogType ) then
			return slotButton;
		end
	end
end

function WardrobeTransmogFrame_ApplyPending(lastAcceptedWarningIndex)
	if ( lastAcceptedWarningIndex == 0 or not WardrobeTransmogFrame.applyWarningsTable ) then
		WardrobeTransmogFrame.applyWarningsTable = C_Transmog.GetApplyWarnings();
	end
	if ( WardrobeTransmogFrame.applyWarningsTable and lastAcceptedWarningIndex < #WardrobeTransmogFrame.applyWarningsTable ) then
		lastAcceptedWarningIndex = lastAcceptedWarningIndex + 1;
		local warning = WardrobeTransmogFrame.applyWarningsTable[lastAcceptedWarningIndex];
		local name, _, quality, _, _, _, _, _, _, texture = GetItemInfo(warning.itemLink);
		local r, g, b = GetItemQualityColor(quality);
		local data = {
			["link"] = warning.itemLink,
			["texture"] = texture,
			["name"] = name,
			["color"] = { r, g, b, 1 },
			["warningIndex"] = lastAcceptedWarningIndex,
		};
		StaticPopup_Show("TRANSMOG_APPLY_WARNING", warning.text, nil, data);
		WardrobeTransmogFrame_UpdateApplyButton();
		-- return true to keep static popup open when chaining warnings
		return true;
	else
		local success = C_Transmog.ApplyAllPending();
		if ( success ) then
			WardrobeTransmogFrame_OnTransmogApplied();
			PlaySound("LOOTWINDOWCOINSOUND");
			WardrobeTransmogFrame.applyWarningsTable = nil;
		end
		return false;
	end
end

function WardrobeTransmogFrame_OnTransmogApplied()
	if WardrobeOutfitDropDown.selectedOutfitID and WardrobeOutfitDropDown:IsOutfitDressed() then
		WardrobeTransmogFrame.OutfitDropDown:OnOutfitApplied(WardrobeOutfitDropDown.selectedOutfitID);
	end
end

WardrobeOutfitMixin = { };

function WardrobeOutfitMixin:OnOutfitApplied(outfitID)
	RebuffedWardrobeLastOutfit = outfitID or 0;
end

function WardrobeOutfitMixin:LoadOutfit(outfitID)
	if ( not outfitID ) then
		return;
	end
	C_Transmog.LoadOutfit(outfitID);
end

function WardrobeOutfitMixin:GetSlotSourceID(slot, transmogType)
	local slotID = GetInventorySlotInfo(slot);
	local isTransmogrified, hasPending, isPendingCollected, canTransmogrify, cannotTransmogrifyReason, hasUndo = C_Transmog.GetSlotInfo(slotID, transmogType);
	if ( not canTransmogrify and not hasUndo ) then
		return NO_TRANSMOG_SOURCE_ID;
	end

	local _, _, sourceID = WardrobeCollectionFrame_GetInfoForEquippedSlot(slot, transmogType);
	return sourceID;
end

function WardrobeOutfitMixin:OnOutfitSaved(outfitID)
	local cost, numChanges = C_Transmog.GetCost();
	if numChanges == 0 then
		self:OnOutfitApplied(outfitID);
	end
end

function WardrobeOutfitMixin:OnSelectOutfit(outfitID)
	-- the first selection of a character is remembered; 0 stands for no outfit
	if ( RebuffedWardrobeLastOutfit == nil ) then
		RebuffedWardrobeLastOutfit = outfitID or 0;
	end
end

function WardrobeOutfitMixin:GetLastOutfitID()
	return RebuffedWardrobeLastOutfit;
end

-- ***** BUTTONS

function WardrobeTransmogButton_OnLoad(self, transmogType)
	AttributesToKeyValues(self, "slot");
	self.transmogType = transmogType;
	SetParentArray(self, "SlotButtons");
	local slotID, textureName = GetInventorySlotInfo(self.slot);
	self.slotID = slotID;
	if ( self.transmogType == LE_TRANSMOG_TYPE_APPEARANCE ) then
		self.Icon:SetTexture(textureName);
		self.Border:SetAtlas("transmog-frame", true);
		self.HiddenVisualCover:SetAtlas("transmog-frame-blackcover", true);
		self.HiddenVisualIcon:SetAtlas("transmog-icon-hidden", true);
		self.SelectedTexture:SetAtlas("transmog-frame-selected", true);
		self.HighlightTexture:SetAtlas("transmog-frame-highlighted");
	else
		self.Icon:SetTexture(ENCHANT_EMPTY_SLOT_ICON);
		self.Border:SetAtlas("transmog-frame-small", true);
		self.UndoIcon:SetAtlas("transmog-icon-revert-small", true);
		self.PendingFrame.Undo:SetAtlas("transmog-icon-revert-small", true);
		self.SelectedTexture:SetAtlas("transmog-frame-small-selected", true);
		self.HighlightTexture:SetAtlas("transmog-frame-highlighted-small");
	end
	self:RegisterForClicks("LeftButtonUp", "RightButtonUp");
end

function WardrobeTransmogButton_OnClick(self, button)
	local slotID = GetInventorySlotInfo(self.slot);
	local isTransmogrified, hasPending, isPendingCollected, canTransmogrify, cannotTransmogrifyReason, hasUndo = C_Transmog.GetSlotInfo(slotID, self.transmogType);
	-- save for sound to play on TRANSMOGRIFY_UPDATE event
	self.hadUndo = hasUndo;
	if ( button == "RightButton" ) then
		if ( hasPending or hasUndo ) then
			PlaySound("igMainMenuOptionCheckBoxOff");
			C_Transmog.ClearPending(slotID, self.transmogType);
			WardrobeTransmogButton_Select(self, true);
		elseif ( isTransmogrified ) then
			PlaySound("igMainMenuOptionCheckBoxOff");
			C_Transmog.SetPending(slotID, self.transmogType, 0);
			WardrobeTransmogButton_Select(self, true);
		end
	else
		PlaySound("igMainMenuOptionCheckBoxOn");
		WardrobeTransmogButton_Select(self, true);
	end
	if ( self.UndoButton ) then
		self.UndoButton:Hide();
	end
	WardrobeTransmogButton_OnEnter(self);
end

function WardrobeTransmogButton_OnEnter(self)
	local slotID = GetInventorySlotInfo(self.slot);
	local isTransmogrified, hasPending, isPendingCollected, canTransmogrify, cannotTransmogrifyReason, hasUndo = C_Transmog.GetSlotInfo(slotID, self.transmogType);

	if ( self.transmogType == LE_TRANSMOG_TYPE_ILLUSION ) then
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 0, 0);
		GameTooltip:SetText(WEAPON_ENCHANTMENT);
		local baseSourceID, baseVisualID, appliedSourceID, appliedVisualID, pendingSourceID, pendingVisualID, hasPendingUndo = C_Transmog.GetSlotVisualInfo(slotID, LE_TRANSMOG_TYPE_ILLUSION);
		if ( self.invalidWeapon ) then
			GameTooltip:AddLine(TRANSMOGRIFY_ILLUSION_INVALID_ITEM, TRANSMOGRIFY_FONT_COLOR.r, TRANSMOGRIFY_FONT_COLOR.g, TRANSMOGRIFY_FONT_COLOR.b, true);
		elseif ( hasPending or hasUndo or canTransmogrify ) then
			if ( baseSourceID > 0 ) then
				local _, name = C_TransmogCollection.GetIllusionSourceInfo(baseSourceID);
				GameTooltip:AddLine(name, GREEN_FONT_COLOR.r, GREEN_FONT_COLOR.g, GREEN_FONT_COLOR.b);
			end
			if ( hasUndo ) then
				GameTooltip:AddLine(TRANSMOGRIFY_TOOLTIP_REVERT, TRANSMOGRIFY_FONT_COLOR.r, TRANSMOGRIFY_FONT_COLOR.g, TRANSMOGRIFY_FONT_COLOR.b);
			elseif ( pendingSourceID > 0 ) then
				GameTooltip:AddLine(WILL_BE_TRANSMOGRIFIED_HEADER, TRANSMOGRIFY_FONT_COLOR.r, TRANSMOGRIFY_FONT_COLOR.g, TRANSMOGRIFY_FONT_COLOR.b);
				local _, name = C_TransmogCollection.GetIllusionSourceInfo(pendingSourceID);
				GameTooltip:AddLine(name, TRANSMOGRIFY_FONT_COLOR.r, TRANSMOGRIFY_FONT_COLOR.g, TRANSMOGRIFY_FONT_COLOR.b);
			elseif ( appliedSourceID > 0 ) then
				GameTooltip:AddLine(TRANSMOGRIFIED_HEADER, TRANSMOGRIFY_FONT_COLOR.r, TRANSMOGRIFY_FONT_COLOR.g, TRANSMOGRIFY_FONT_COLOR.b);
				local _, name = C_TransmogCollection.GetIllusionSourceInfo(appliedSourceID);
				GameTooltip:AddLine(name, TRANSMOGRIFY_FONT_COLOR.r, TRANSMOGRIFY_FONT_COLOR.g, TRANSMOGRIFY_FONT_COLOR.b);
			end
		else
			local itemBaseSourceID = C_Transmog.GetSlotVisualInfo(slotID, LE_TRANSMOG_TYPE_APPEARANCE);
			if ( itemBaseSourceID == NO_TRANSMOG_SOURCE_ID ) then
				GameTooltip:AddLine(TRANSMOGRIFY_INVALID_NO_ITEM, RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b, true);
			else
				GameTooltip:AddLine(TRANSMOGRIFY_ILLUSION_INVALID_ITEM, RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b, true);
			end
		end
		GameTooltip:Show();
	else
		if ( self.UndoButton and isTransmogrified and not ( hasPending or hasUndo ) ) then
			self.UndoButton:Show();
		end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 14, 0);
		if ( hasPending and not hasUndo and not isPendingCollected ) then
			GameTooltip:SetText(_G[self.slot]);
			GameTooltip:AddLine(TRANSMOGRIFY_STYLE_UNCOLLECTED, RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b, true);
			GameTooltip:Show();
		elseif ( not canTransmogrify and not hasUndo ) then
			GameTooltip:SetText(_G[self.slot]);
			local tag = TRANSMOG_INVALID_CODES[cannotTransmogrifyReason];
			local errorMsg;
			if ( tag == "ILLUSION_INVALID_ITEM" ) then
				errorMsg = TRANSMOGRIFY_ILLUSION_INVALID_ITEM;
			elseif ( tag ) then
				errorMsg = _G["TRANSMOGRIFY_INVALID_"..tag];
			end
			if ( errorMsg ) then
				GameTooltip:AddLine(errorMsg, RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b, true);
			end
			GameTooltip:Show();
		else
			GameTooltip:SetInventoryItem("player", slotID);
		end
	end
	local errorText = WardrobeTransmogFrame_GetSlotErrorText(self);
	if ( errorText ) then
		GameTooltip:AddLine(errorText, RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b, true);
		GameTooltip:Show();
	end
end

function WardrobeTransmogButton_OnLeave(self)
	if ( self.UndoButton and not self.UndoButton:IsMouseOver() ) then
		self.UndoButton:Hide();
	end
	GameTooltip:Hide();
end

function WardrobeTransmogButton_Select(button, fromOnClick)
	if ( WardrobeTransmogFrame.selectedSlotButton ) then
		WardrobeTransmogFrame.selectedSlotButton.SelectedTexture:Hide();
	end
	WardrobeTransmogFrame.selectedSlotButton = button;
	if ( button ) then
		button.SelectedTexture:Show();
		if (fromOnClick and WardrobeCollectionFrame.activeFrame ~= WardrobeCollectionFrame.ItemsCollectionFrame) then
			WardrobeCollectionFrame_ClickTab(WardrobeCollectionFrame.ItemsTab);
		end
		if ( WardrobeCollectionFrame.activeFrame == WardrobeCollectionFrame.ItemsCollectionFrame ) then
			local _, _, selectedSourceID = WardrobeCollectionFrame_GetInfoForEquippedSlot(button.slot, button.transmogType);
			local forceGo = (button.transmogType == LE_TRANSMOG_TYPE_ILLUSION);
			WardrobeCollectionFrame.ItemsCollectionFrame:GoToSourceID(selectedSourceID, button.slot, button.transmogType, forceGo);
			WardrobeCollectionFrame.ItemsCollectionFrame:SetTransmogrifierAppearancesShown(true);
		end
	else
		WardrobeCollectionFrame.ItemsCollectionFrame:SetTransmogrifierAppearancesShown(false);
	end
end

function WardrobeTransmogButton_SetStatusBorder(self, status)
	local atlas;
	if ( status == "RED" ) then
		if ( self.transmogType == LE_TRANSMOG_TYPE_APPEARANCE ) then
			atlas = "transmog-frame-red";
		else
			atlas = "transmog-frame-small-red";
		end
	elseif ( status == "PINK" ) then
		if ( self.transmogType == LE_TRANSMOG_TYPE_APPEARANCE ) then
			atlas = "transmog-frame-pink";
		else
			atlas = "transmog-frame-small-pink";
		end	
	end
	if ( atlas ) then
		self.StatusBorder:Show();
		self.StatusBorder:SetAtlas(atlas, true);
	else
		self.StatusBorder:Hide();
	end
end

-- ************************************************************************************************************************************************************
-- **** COLLECTION ********************************************************************************************************************************************
-- ************************************************************************************************************************************************************

local TAB_ITEMS = 1;
local TAB_SETS = 2;

-- Retail keeps these as GlobalStrings; the era has no such strings, so they are named here. The
-- values are what OnKeyDown is handed for those keys.
local WARDROBE_PREV_VISUAL_KEY = "LEFT";
local WARDROBE_NEXT_VISUAL_KEY = "RIGHT";
local WARDROBE_UP_VISUAL_KEY = "UP";
local WARDROBE_DOWN_VISUAL_KEY = "DOWN";
local WARDROBE_CYCLE_KEY = "TAB";

-- One step through a grid laid out in contentFrame.NUM_COLS columns, wrapping at both ends.
-- Up and down from an edge go to the far end rather than off it, which is what retail does.
function WardrobeUtils_GetAdjustedDisplayIndexFromKeyPress(contentFrame, index, numEntries, key)
	if ( key == WARDROBE_PREV_VISUAL_KEY ) then
		index = index - 1;
		if ( index < 1 ) then
			index = numEntries;
		end
	elseif ( key == WARDROBE_NEXT_VISUAL_KEY ) then
		index = index + 1;
		if ( index > numEntries ) then
			index = 1;
		end
	elseif ( key == WARDROBE_DOWN_VISUAL_KEY ) then
		local newIndex = index + contentFrame.NUM_COLS;
		if ( newIndex > numEntries ) then
			index = index == numEntries and 1 or numEntries;
		else
			index = newIndex;
		end
	elseif ( key == WARDROBE_UP_VISUAL_KEY ) then
		local newIndex = index - contentFrame.NUM_COLS;
		if ( newIndex < 1 ) then
			index = index == 1 and numEntries or 1;
		else
			index = newIndex;
		end
	end
	return index;
end

-- The era gives a frame every key or none, so the wardrobe hands back what it does not use.
-- Frame:SetPropagateKeyboardInput comes from the extension; without it enabling the keyboard here
-- would kill every binding for as long as the window is open.
function WardrobeCollectionFrame_OnKeyDown(self, key)
	-- Tab walks the items that share the look under the cursor, shift-Tab the other way. Only
	-- while a tooltip that lists more than one is up, so the key is the interface's own
	-- everywhere else.
	if ( self.tooltipCycle and key == WARDROBE_CYCLE_KEY and self.tooltipContentFrame ) then
		self:SetPropagateKeyboardInput(false);
		self.tooltipSourceIndex = (self.tooltipSourceIndex or 1) + (IsShiftKeyDown() and -1 or 1);
		self.tooltipContentFrame:RefreshAppearanceTooltip();
		return;
	end
	if ( key == WARDROBE_PREV_VISUAL_KEY or key == WARDROBE_NEXT_VISUAL_KEY
	     or key == WARDROBE_UP_VISUAL_KEY or key == WARDROBE_DOWN_VISUAL_KEY ) then
		if ( self.activeFrame and self.activeFrame:CanHandleKey(key) ) then
			self:SetPropagateKeyboardInput(false);
			self.activeFrame:HandleKey(key);
			return;
		end
	end
	self:SetPropagateKeyboardInput(true);
end

local SET_MODEL_PAN_AND_ZOOM_LIMITS = {
	["Draenei2"] = { maxZoom = 2.2105259895325, panMaxLeft = -0.56983226537705, panMaxRight = 0.82581323385239, panMaxTop = -0.17342753708363, panMaxBottom = -2.6428601741791 },
	["Draenei3"] = { maxZoom = 3.0592098236084, panMaxLeft = -0.33429977297783, panMaxRight = 0.29183092713356, panMaxTop = -0.079871296882629, panMaxBottom = -2.4141833782196 },
	["Scourge2"] = { maxZoom = 3.1710526943207, panMaxLeft = -0.3243542611599, panMaxRight = 0.5625838637352, panMaxTop = -0.054175414144993, panMaxBottom = -1.7261047363281 },
	["Scourge3"] = { maxZoom = 2.7105259895325, panMaxLeft = -0.35650563240051, panMaxRight = 0.41562974452972, panMaxTop = -0.07072202116251, panMaxBottom = -1.877711892128 },
	["Orc2"] = { maxZoom = 2.5526309013367, panMaxLeft = -0.64236557483673, panMaxRight = 0.77098786830902, panMaxTop = -0.075792260468006, panMaxBottom = -2.0818419456482 },
	["Orc3"] = { maxZoom = 3.2960524559021, panMaxLeft = -0.22763830423355, panMaxRight = 0.32022559642792, panMaxTop = -0.038521766662598, panMaxBottom = -2.0473554134369 },
	["Gnome3"] = { maxZoom = 2.9605259895325, panMaxLeft = -0.29900181293488, panMaxRight = 0.35779395699501, panMaxTop = -0.076380833983421, panMaxBottom = -0.99909907579422 },
	["Gnome2"] = { maxZoom = 2.8552639484406, panMaxLeft = -0.2777853012085, panMaxRight = 0.29651582241058, panMaxTop = -0.095201380550861, panMaxBottom = -1.0263166427612 },
	["Dwarf2"] = { maxZoom = 2.9605259895325, panMaxLeft = -0.50352156162262, panMaxRight = 0.4159924685955, panMaxTop = -0.07211934030056, panMaxBottom = -1.4946432113648 },
	["Dwarf3"] = { maxZoom = 2.8947370052338, panMaxLeft = -0.37057432532311, panMaxRight = 0.43383255600929, panMaxTop = -0.084960877895355, panMaxBottom = -1.7173190116882 },
	["BloodElf3"] = { maxZoom = 3.1644730567932, panMaxLeft = -0.2654082775116, panMaxRight = 0.28886350989342, panMaxTop = -0.049619361758232, panMaxBottom = -1.9943760633469 },
	["BloodElf2"] = { maxZoom = 3.1710524559021, panMaxLeft = -0.25901651382446, panMaxRight = 0.45525884628296, panMaxTop = -0.085230752825737, panMaxBottom = -2.0548067092895 },
	["Troll2"] = { maxZoom = 2.2697355747223, panMaxLeft = -0.58214980363846, panMaxRight = 0.5104039311409, panMaxTop = -0.05494449660182, panMaxBottom = -2.3443803787231 },
	["Troll3"] = { maxZoom = 3.1249995231628, panMaxLeft = -0.35141581296921, panMaxRight = 0.50875341892242, panMaxTop = -0.063820324838161, panMaxBottom = -2.4224486351013 },
	["Tauren2"] = { maxZoom = 2.1118416786194, panMaxLeft = -0.82946360111237, panMaxRight = 0.83975899219513, panMaxTop = -0.061676319688559, panMaxBottom = -2.035267829895 },
	["Tauren3"] = { maxZoom = 2.9605259895325, panMaxLeft = -0.37433895468712, panMaxRight = 0.40420442819595, panMaxTop = -0.1868137717247, panMaxBottom = -2.2116675376892 },
	["NightElf3"] = { maxZoom = 2.9539475440979, panMaxLeft = -0.27334463596344, panMaxRight = 0.27148312330246, panMaxTop = -0.094710879027844, panMaxBottom = -2.3087983131409 },
	["NightElf2"] = { maxZoom = 2.9144732952118, panMaxLeft = -0.45042458176613, panMaxRight = 0.47114592790604, panMaxTop = -0.10513981431723, panMaxBottom = -2.4612309932709 },
	["Human3"] = { maxZoom = 3.3618412017822, panMaxLeft = -0.19753229618072, panMaxRight = 0.26802557706833, panMaxTop = -0.073476828634739, panMaxBottom = -1.9255120754242 },
	["Human2"] = { maxZoom = 2.9605259895325, panMaxLeft = -0.33268970251083, panMaxRight = 0.36896070837975, panMaxTop = -0.14780110120773, panMaxBottom = -2.1662468910217 },
};

function WardrobeCollectionFrame_SetContainer(parent)
	local collectionFrame = WardrobeCollectionFrame;
	collectionFrame:SetParent(parent);
	collectionFrame:ClearAllPoints();
	if ( parent == CollectionsJournal ) then
		collectionFrame:SetPoint("TOPLEFT", CollectionsJournal);
		collectionFrame:SetPoint("BOTTOMRIGHT", CollectionsJournal);
		collectionFrame.ItemsCollectionFrame.ModelR1C1:SetPoint("TOP", -238, -85);
		collectionFrame.ItemsCollectionFrame.SlotsFrame:Show();
		collectionFrame.ItemsCollectionFrame.BGCornerTopLeft:Hide();
		collectionFrame.ItemsCollectionFrame.BGCornerTopRight:Hide();
		collectionFrame.ItemsCollectionFrame.WeaponDropDown:SetPoint("TOPRIGHT", -6, -22);
		collectionFrame.ItemsCollectionFrame.NoValidItemsLabel:Hide();
		collectionFrame.FilterButton:SetText(FILTER);
		collectionFrame.ItemsTab:SetPoint("TOPLEFT", 58, -28);
		WardrobeCollectionFrame_SetTab(collectionFrame.selectedCollectionTab);
	elseif ( parent == WardrobeFrame ) then
		collectionFrame:SetPoint("TOPRIGHT", 0, 0);
		collectionFrame:SetSize(662, 606);
		collectionFrame.ItemsCollectionFrame.ModelR1C1:SetPoint("TOP", -235, -71);
		collectionFrame.ItemsCollectionFrame.SlotsFrame:Hide();
		collectionFrame.ItemsCollectionFrame.BGCornerTopLeft:Show();
		collectionFrame.ItemsCollectionFrame.BGCornerTopRight:Show();
		collectionFrame.ItemsCollectionFrame.WeaponDropDown:SetPoint("TOPRIGHT", -32, -25);
		collectionFrame.FilterButton:SetText(SOURCES);
		collectionFrame.ItemsTab:SetPoint("TOPLEFT", 8, -28);
		WardrobeCollectionFrame_SetTab(collectionFrame.selectedTransmogTab);
	end
	collectionFrame:Show();
end

function WardrobeCollectionFrame_ClickTab(tab)
	WardrobeCollectionFrame_SetTab(tab:GetID());
	PanelTemplates_TabResize(WardrobeCollectionFrame.ItemsTab, 0);
	PanelTemplates_TabResize(WardrobeCollectionFrame.SetsTab, 0);
	PlaySound("igMainMenuOptionCheckBoxOn");
end

function WardrobeCollectionFrame_SetTab(tabID)
	PanelTemplates_SetTab(WardrobeCollectionFrame, tabID);
	local atTransmogrifier = WardrobeFrame_IsAtTransmogrifier();
	if ( atTransmogrifier ) then
		WardrobeCollectionFrame.selectedTransmogTab = tabID;
	else
		WardrobeCollectionFrame.selectedCollectionTab = tabID;
	end
	if ( tabID == TAB_ITEMS ) then
		WardrobeCollectionFrame.activeFrame = WardrobeCollectionFrame.ItemsCollectionFrame;
		WardrobeCollectionFrame.ItemsCollectionFrame:Show();
		WardrobeCollectionFrame.SetsCollectionFrame:Hide();
		WardrobeCollectionFrame.SetsTransmogFrame:Hide();
		WardrobeCollectionFrame.searchBox:ClearAllPoints();
		WardrobeCollectionFrame.searchBox:SetPoint("TOPRIGHT", -107, -35);
		WardrobeCollectionFrame.searchBox:SetWidth(115);
		WardrobeCollectionFrame.searchBox:SetEnabled(WardrobeCollectionFrame.ItemsCollectionFrame.transmogType == LE_TRANSMOG_TYPE_APPEARANCE);
		WardrobeCollectionFrame.FilterButton:Show();
		WardrobeCollectionFrame.FilterButton:SetEnabled(WardrobeCollectionFrame.ItemsCollectionFrame.transmogType == LE_TRANSMOG_TYPE_APPEARANCE);
	elseif ( tabID == TAB_SETS ) then
		WardrobeCollectionFrame.ItemsCollectionFrame:Hide();
		WardrobeCollectionFrame.searchBox:ClearAllPoints();
		if ( atTransmogrifier )  then
			WardrobeCollectionFrame.activeFrame = WardrobeCollectionFrame.SetsTransmogFrame;
			WardrobeCollectionFrame.searchBox:SetPoint("TOPRIGHT", -107, -35);
			WardrobeCollectionFrame.searchBox:SetWidth(115);
			WardrobeCollectionFrame.FilterButton:Hide();
		else
			WardrobeCollectionFrame.activeFrame = WardrobeCollectionFrame.SetsCollectionFrame;
			WardrobeCollectionFrame.searchBox:SetPoint("TOPLEFT", 19, -69);
			WardrobeCollectionFrame.searchBox:SetWidth(145);
			WardrobeCollectionFrame.FilterButton:Show();
			WardrobeCollectionFrame.FilterButton:SetEnabled(true);
		end
		WardrobeCollectionFrame.searchBox:SetEnabled(true);
		WardrobeCollectionFrame.SetsCollectionFrame:SetShown(not atTransmogrifier);
		WardrobeCollectionFrame.SetsTransmogFrame:SetShown(atTransmogrifier);
	end
end

function WardrobeCollectionFrame_OnLoad(self)
	PanelTemplates_SetNumTabs(self, 2);
	Mixin(self.FilterButton, WardrobeFilterButtonMixin);

	-- The search box and the filter button are shared by both tabs and move with them. On the sets
	-- tab they land over that pane's LeftInset, which sits at the same frame level and paints its
	-- own background over their art -- the text survived, the button did not, so it read as an
	-- unstyled label. Raising them once puts them above every pane.
	local above = self:GetFrameLevel() + 10;
	self.searchBox:SetFrameLevel(above);
	self.FilterButton:SetFrameLevel(above);
	PanelTemplates_SetTab(self, TAB_ITEMS);
	PanelTemplates_TabResize(self.ItemsTab, 0);
	PanelTemplates_TabResize(self.SetsTab, 0);
	self.selectedCollectionTab = TAB_ITEMS;
	self.selectedTransmogTab = TAB_ITEMS;
end

WardrobeItemsCollectionMixin = { };

function WardrobeItemsCollectionMixin:CreateSlotButtons()
	-- Retail's gaps are 24 and 12; the ranged slot the era has adds a button to the row, and with
	-- the row 12 px further left these gaps leave the weapon dropdown its place beside it.
	local slots = { "head", "shoulder", "back", "chest", "shirt", "tabard", "wrist", 16, "hands", "waist", "legs", "feet", 16, "mainhand", 8, "secondaryhand", 8, "ranged" };
	local parentFrame = self.SlotsFrame;
	local lastButton;
	local xOffset = 2;
	local mainHandButton, secondaryHandButton;
	for i = 1, #slots do
		local value = tonumber(slots[i]);
		if ( value ) then
			-- this is a spacer
			xOffset = value;
		else
			local button = CreateFrame("BUTTON", nil, parentFrame, "WardrobeSlotButtonTemplate");
			if ( slots[i] == "ranged" ) then
				-- No sheet of retail's has a transmog-nav-slot-ranged: the era has the slot, retail
				-- never did. The transmog sheet's frames are rounded squares, so the disc is the
				-- minimap's round backdrop, and the glyph is the era's bow icon, desaturated and
				-- added over it so that the icon's black square drops out.
				button.NormalTexture:SetTexture("Interface\\Minimap\\UI-Minimap-Background");
				button.NormalTexture:SetSize(38, 38);
				local glyph = button:CreateTexture(nil, "OVERLAY");
				glyph:SetTexture("Interface\\Icons\\INV_Weapon_Bow_07");
				glyph:SetTexCoord(0.08, 0.92, 0.08, 0.92);
				glyph:SetSize(22, 22);
				glyph:SetPoint("CENTER", button.NormalTexture, "CENTER", 0, 0);
				glyph:SetDesaturated(true);
				glyph:SetBlendMode("ADD");
				glyph:SetVertexColor(0.85, 0.85, 0.85);
			else
				button.NormalTexture:SetAtlas("transmog-nav-slot-"..slots[i], true);
			end
			if ( lastButton ) then
				button:SetPoint("LEFT", lastButton, "RIGHT", xOffset, 0);
			else
				button:SetPoint("TOPLEFT");
			end
			button.slot = string.upper(slots[i]).."SLOT";
			xOffset = 2;
			lastButton = button;
			if ( slots[i] == "mainhand" ) then
				mainHandButton = button;
			elseif ( slots[i] == "secondaryhand" ) then
				secondaryHandButton = button;
			end
		end
	end
	-- enchant buttons
	local mainHandEnchantButton = CreateFrame("BUTTON", nil, parentFrame, "WardrobeEnchantButtonTemplate");
	mainHandEnchantButton:SetPoint("BOTTOMRIGHT", mainHandButton, "TOPRIGHT", 16, -15);
	mainHandEnchantButton.slot = mainHandButton.slot;
	local secondaryHandEnchantButton = CreateFrame("BUTTON", nil, parentFrame, "WardrobeEnchantButtonTemplate");
	secondaryHandEnchantButton:SetPoint("BOTTOMRIGHT", secondaryHandButton, "TOPRIGHT", 16, -15);
	secondaryHandEnchantButton.slot = secondaryHandButton.slot;
	parentFrame.EnchantButtons = { mainHandEnchantButton, secondaryHandEnchantButton };
end

function WardrobeItemsCollectionMixin:OnEvent(event, ...)
	if ( event == "TRANSMOGRIFY_UPDATE" or event == "TRANSMOGRIFY_SUCCESS" or event == "PLAYER_EQUIPMENT_CHANGED" ) then
		local slotID = ...;
		if ( slotID and self.transmogType == LE_TRANSMOG_TYPE_APPEARANCE ) then
			if ( slotID == GetInventorySlotInfo(self.activeSlot) ) then
				self:RefreshVisualsList();
				self:UpdateItems();
			end
		else
			-- generic update
			self:RefreshVisualsList();
			self:UpdateItems();
		end
	elseif ( event == "TRANSMOG_COLLECTION_UPDATED") then
		self:CheckLatestAppearance(true);
		self:ValidateChosenVisualSources();
		if ( self:IsVisible() ) then
			self:RefreshVisualsList();
			self:UpdateItems();
		end
		WardrobeCollectionFrame_UpdateTabButtons();
	end
end

function WardrobeCollectionFrame_OnEvent(self, event, ...)
	if ( event == "DISPLAY_SIZE_CHANGED" ) then
		WardrobeCollectionFrame_RefreshCameras();
	elseif ( event == "UNIT_MODEL_CHANGED" ) then
		-- Retail acts on this when the alternate form flipped or when a slot change asked it
		-- to. This era has no alternate player form and no HasAlternateForm, so the deferred
		-- half is all that is left -- and it is the half that matters: an applied transmog
		-- fires this event too, and tearing the dressed cells down to redress them while the
		-- player's model is still reloading leaves every cell showing the plain player.
		if ( self.updateOnModelChanged and self.activeFrame and self.activeFrame.OnUnitModelChangedEvent ) then
			if ( self.activeFrame:OnUnitModelChangedEvent() ) then
				self.updateOnModelChanged = nil;
			end
		end
	elseif ( event == "PLAYER_LEVEL_UP" or event == "SKILL_LINES_CHANGED"
	         or event == "UPDATE_FACTION" or event == "SPELLS_CHANGED" ) then
		WardrobeCollectionFrame_UpdateUsableAppearances();
	end
end

-- What a character may transmogrify changes with level, skill, reputation and known spells, and
-- all four can arrive together. Retail coalesces them with C_Timer.After(0); the era has no timer
-- API, so the frame asks for one OnUpdate and drops it again, which is the same one call per frame.
local usableAppearancesPending = false;

function WardrobeCollectionFrame_UpdateUsableAppearances()
	if ( usableAppearancesPending ) then
		return;
	end
	usableAppearancesPending = true;
	WardrobeCollectionFrame:SetScript("OnUpdate", function(self)
		self:SetScript("OnUpdate", nil);
		usableAppearancesPending = false;
		C_TransmogCollection.UpdateUsableAppearances();
	end);
end

function WardrobeCollectionFrame_RefreshCameras()
	for i, frame in ipairs(WardrobeCollectionFrame.ContentFrames) do
		frame:RefreshCameras();
	end
end

function WardrobeItemsCollectionMixin:CheckLatestAppearance(changeTab)
	local latestAppearanceID, latestAppearanceCategoryID = C_TransmogCollection.GetLatestAppearance();
	if ( self.latestAppearanceID ~= latestAppearanceID ) then
		self.latestAppearanceID = latestAppearanceID;
		self.jumpToLatestAppearanceID = latestAppearanceID;
		self.jumpToLatestCategoryID = latestAppearanceCategoryID;

		-- Not at the transmogrifier: selecting the tab there would reparent the collection frame
		-- out of WardrobeFrame and close the session.
		if ( changeTab and not CollectionsJournal:IsShown() and not WardrobeFrame_IsAtTransmogrifier() ) then
			CollectionsJournal:SelectTab(CollectionsJournal:GetTabByID(CollectionsJournal.wardrobeTabID), true);
		end
	end
end

function WardrobeItemsCollectionMixin:OnLoad()
	self:CreateSlotButtons();
	self.BGCornerTopLeft:Hide();
	self.BGCornerTopRight:Hide();
	self:EnableMouseWheel(true);

	self.chosenVisualSources = { };

	self.NUM_ROWS = 3;
	self.NUM_COLS = 6;
	self.PAGE_SIZE = self.NUM_ROWS * self.NUM_COLS;

	self:RegisterEvent("TRANSMOG_COLLECTION_UPDATED");

	self:CheckLatestAppearance();
end

function WardrobeItemsCollection_OnLoad(self)
	SetParentArray(self, "ContentFrames");
	self.searchType = LE_TRANSMOG_SEARCH_TYPE_ITEMS;
	MixinAndLoadScripts(self, "WardrobeItemsCollectionMixin");
end

function WardrobeItemsCollectionMixin:OnShow()
	self:RegisterEvent("TRANSMOGRIFY_UPDATE");
	self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED");
	self:RegisterEvent("TRANSMOGRIFY_SUCCESS");

	local needsUpdate = false;	-- we don't need to update if we call WardrobeCollectionFrame_SetActiveSlot as that will do an update
	if ( self.jumpToLatestCategoryID and self.jumpToLatestCategoryID ~= self.activeCategory ) then
		local slot = WardrobeCollectionFrame_GetSlotFromCategoryID(self.jumpToLatestCategoryID);
		self:SetActiveSlot(slot, LE_TRANSMOG_TYPE_APPEARANCE, self.jumpToLatestCategoryID);
		self.jumpToLatestCategoryID = nil;
	elseif ( self.activeSlot ) then
		-- redo the model for the active slot
		self:ChangeModelsSlot();
		needsUpdate = true;
	else
		self:SetActiveSlot("HEADSLOT", LE_TRANSMOG_TYPE_APPEARANCE);
	end

	if ( needsUpdate ) then
		self:RefreshVisualsList();
		self:UpdateItems();
		self:UpdateWeaponDropDown();
	end
end

function WardrobeItemsCollectionMixin:OnHide()
	self:UnregisterEvent("TRANSMOGRIFY_UPDATE");
	self:UnregisterEvent("PLAYER_EQUIPMENT_CHANGED");
	self:UnregisterEvent("TRANSMOGRIFY_SUCCESS");

	WardrobeCollectionFrame_ClearSearch(LE_TRANSMOG_SEARCH_TYPE_ITEMS);

	self.visualsList = nil;
	self.filteredVisualsList = nil;
end

function WardrobeCollectionFrame_OnShow(self)
	self:RegisterEvent("DISPLAY_SIZE_CHANGED");
	self:RegisterEvent("UNIT_MODEL_CHANGED");
	self:RegisterEvent("PLAYER_LEVEL_UP");
	self:RegisterEvent("SKILL_LINES_CHANGED");
	self:RegisterEvent("UPDATE_FACTION");
	self:RegisterEvent("SPELLS_CHANGED");

	if ( WardrobeFrame_IsAtTransmogrifier() ) then
		WardrobeCollectionFrame_SetTab(self.selectedTransmogTab);
	else
		WardrobeCollectionFrame_SetTab(self.selectedCollectionTab);
	end
	WardrobeCollectionFrame_UpdateTabButtons();
end

function WardrobeCollectionFrame_OnHide(self)
	self:UnregisterEvent("DISPLAY_SIZE_CHANGED");
	self.jumpToVisualID = nil;
end

function WardrobeCollectionFrame_UpdateTabButtons()
	-- sets tab
	WardrobeCollectionFrame.SetsTab.FlashFrame:SetShown(C_TransmogSets.GetLatestSource() ~= NO_TRANSMOG_SOURCE_ID and not WardrobeFrame_IsAtTransmogrifier());
end

function WardrobeItemsCollectionMixin:OnMouseWheel(delta)
	self.PagingFrame:OnMouseWheel(delta);
end

function WardrobeItemsCollectionMixin:ChangeModelsSlot()
	-- The player's model is gone for a moment whenever it reloads, and a cell reloaded
	-- against a missing player comes back empty. Retail leaves the slot change for the
	-- model-changed event to finish; this is the flag that asks for it.
	WardrobeCollectionFrame.updateOnModelChanged = nil;
	if ( not self.Models[1]:CanSetUnit("player") ) then
		WardrobeCollectionFrame.updateOnModelChanged = true;
		for i = 1, #self.Models do
			self.Models[i]:ClearModel();
		end
		return;
	end
	for i = 1, #self.Models do
		local model = self.Models[i];
		model:Reload(self.activeSlot);
		model.visualInfo = nil;
	end
	self.illusionWeaponVisualID = nil;
end

function WardrobeItemsCollectionMixin:RefreshCameras()
	if ( self:IsShown() ) then
		for i, model in ipairs(self.Models) do
			model:RefreshCamera();
		end
	end
end

function WardrobeUtils_IsCategoryRanged(category)
	return (category == LE_TRANSMOG_COLLECTION_TYPE_BOW) or (category == LE_TRANSMOG_COLLECTION_TYPE_GUN) or (category == LE_TRANSMOG_COLLECTION_TYPE_CROSSBOW)
		or (category == LE_TRANSMOG_COLLECTION_TYPE_WAND) or (category == LE_TRANSMOG_COLLECTION_TYPE_THROWN);
end

-- Which of the three weapon slots a weapon category belongs in.
function WardrobeUtils_CategoryFitsSlot(categoryID, slot, canMainHand, canOffHand)
	if ( slot == "RANGEDSLOT" ) then
		return WardrobeUtils_IsCategoryRanged(categoryID);
	end
	return not WardrobeUtils_IsCategoryRanged(categoryID) and ((slot == "MAINHANDSLOT" and canMainHand) or (slot == "SECONDARYHANDSLOT" and canOffHand));
end

function WardrobeUtils_GetArmorCategoryIDFromSlot(slot)
	for i = 1, #TRANSMOG_SLOTS do
		if ( TRANSMOG_SLOTS[i].slot == slot ) then
			return TRANSMOG_SLOTS[i].armorCategoryID;
		end
	end
end

function WardrobeUtils_GetValidIndexForNumSources(index, numSources)
	index = index - 1;
	if ( index < 0 ) then
		index = numSources + index;
	end
	return mod(index, numSources) + 1;
end

local function GetPage(entryIndex, pageSize)
	return floor((entryIndex-1) / pageSize) + 1;
end

function WardrobeItemsCollectionMixin:GetActiveSlot()
	return self.activeSlot;
end

function WardrobeItemsCollectionMixin:GetActiveCategory()
	return self.activeCategory;
end

-- At the transmogrifier the worn item decides which weapon categories fit, the same way in both
-- hands: Whitemane+ puts a two-hander's look on an off-hand weapon, and a shield takes only a shield.
function WardrobeUtils_CategoryFitsWornItem(categoryID, slot, equippedItemID)
	return WardrobeUtils_IsCategoryRanged(categoryID) == (slot == "RANGEDSLOT")
		and C_TransmogCollection.IsCategoryValidForItem(categoryID, equippedItemID);
end

function WardrobeItemsCollectionMixin:IsValidWeaponCategoryForSlot(categoryID, slot)
	local name, isWeapon, canEnchant, canMainHand, canOffHand = C_TransmogCollection.GetCategoryInfo(categoryID);
	if ( not name or not isWeapon ) then
		return false;
	end
	if ( WardrobeFrame_IsAtTransmogrifier() ) then
		local equippedItemID = GetInventoryItemID("player", GetInventorySlotInfo(slot));
		return WardrobeUtils_CategoryFitsWornItem(categoryID, slot, equippedItemID);
	end
	return WardrobeUtils_CategoryFitsSlot(categoryID, slot, canMainHand, canOffHand);
end

function WardrobeItemsCollectionMixin:SetActiveSlot(slot, transmogType, category)
	local previousSlot = self.activeSlot;
	self.activeSlot = slot;
	self.transmogType = transmogType;

	-- figure out a category
	if ( not category ) then
		if ( transmogType == LE_TRANSMOG_TYPE_ILLUSION ) then
			category = nil;
		elseif ( transmogType == LE_TRANSMOG_TYPE_APPEARANCE ) then
			local useLastWeaponCategory = (slot == "MAINHANDSLOT" or slot == "SECONDARYHANDSLOT" or slot == "RANGEDSLOT") and
											self.lastWeaponCategory and
											self:IsValidWeaponCategoryForSlot(self.lastWeaponCategory, slot);
			if ( useLastWeaponCategory ) then
				category = self.lastWeaponCategory;
			else
				local appliedSourceID, appliedVisualID, selectedSourceID, selectedVisualID = self:GetActiveSlotInfo();
				if ( selectedSourceID ~= NO_TRANSMOG_SOURCE_ID ) then
					category = C_TransmogCollection.GetAppearanceSourceInfo(selectedSourceID);
				end
			end
			if ( not category ) then
				if ( slot == "MAINHANDSLOT" or slot == "SECONDARYHANDSLOT" or slot == "RANGEDSLOT" ) then
					-- find the first valid weapon category
					for categoryID = FIRST_TRANSMOG_COLLECTION_WEAPON_TYPE, LAST_TRANSMOG_COLLECTION_WEAPON_TYPE do
						if ( self:IsValidWeaponCategoryForSlot(categoryID, slot) ) then
							category = categoryID;
							break;
						end
					end
				else
					category = WardrobeUtils_GetArmorCategoryIDFromSlot(slot);
				end
			end
		end
	end

	if ( previousSlot ~= slot ) then
		self:ChangeModelsSlot();
	end
	-- set only if category is different or slot is different
	if ( category ~= self.activeCategory or slot ~= previousSlot ) then
		RebuffedMenu:Close();
		self:SetActiveCategory(category);
	end
end

function WardrobeItemsCollectionMixin:SetTransmogrifierAppearancesShown(hasAnyValidSlots)
	self.NoValidItemsLabel:SetShown(not hasAnyValidSlots);
	C_TransmogCollection.SetCollectedShown(hasAnyValidSlots);
end

function WardrobeItemsCollectionMixin:UpdateWeaponDropDown()
	local dropdown = self.WeaponDropDown;
	local name, isWeapon;
	if ( self.transmogType == LE_TRANSMOG_TYPE_APPEARANCE ) then
		name, isWeapon = C_TransmogCollection.GetCategoryInfo(self.activeCategory);
	end
	if ( not isWeapon ) then
		if ( WardrobeFrame_IsAtTransmogrifier() ) then
			dropdown:Hide();
		else
			dropdown:Show();
			dropdown:SetText("");
			dropdown:Disable();
		end
	else
		dropdown:Show();
		dropdown:SetText(name);
		local _, validCategories = WardrobeCollectionFrameWeaponDropDown_GetEntries();
		if ( validCategories > 1 ) then
			dropdown:Enable();
		else
			dropdown:Disable();
		end
	end
end

function WardrobeItemsCollectionMixin:SetActiveCategory(category)
	self.activeCategory = category;
	if ( self.transmogType == LE_TRANSMOG_TYPE_APPEARANCE ) then
		C_TransmogCollection.SetSearchAndFilterCategory(category);
		local name, isWeapon = C_TransmogCollection.GetCategoryInfo(category);
		if ( isWeapon ) then
			self.lastWeaponCategory = category;
		end
	end
	self:RefreshVisualsList();
	self:UpdateWeaponDropDown();

	local slotButtons = self.SlotsFrame.Buttons;
	for i = 1, #slotButtons do
		local button = slotButtons[i];
		button.SelectedTexture:SetShown(button.slot == self.activeSlot and button.transmogType == self.transmogType);
	end

	if ( WardrobeFrame_IsAtTransmogrifier() ) then
		self.jumpToVisualID = select(4, self:GetActiveSlotInfo());
	end
	self:ResetPage();
	WardrobeCollectionFrame_SwitchSearchCategory();
end

function WardrobeItemsCollectionMixin:ResetPage()
	local page = 1;
	local selectedVisualID = NO_TRANSMOG_VISUAL_ID;
	if ( self.jumpToVisualID ) then
		selectedVisualID = self.jumpToVisualID;
		self.jumpToVisualID = nil;
	elseif ( self.jumpToLatestAppearanceID ) then
		selectedVisualID = self.jumpToLatestAppearanceID;
		self.jumpToLatestAppearanceID = nil;
	end
	if ( selectedVisualID and selectedVisualID ~= NO_TRANSMOG_VISUAL_ID ) then
		local visualsList = self:GetFilteredVisualsList();
		for i = 1, #visualsList do
			if ( visualsList[i].visualID == selectedVisualID ) then
				page = GetPage(i, self.PAGE_SIZE);
				break;
			end
		end
	end
	self.PagingFrame:SetCurrentPage(page);
	self:UpdateItems();
end

function WardrobeItemsCollectionMixin:FilterVisuals()
	local isAtTransmogrifier = WardrobeFrame_IsAtTransmogrifier();
	local visualsList = self.visualsList;
	local filteredVisualsList = { };
	for i = 1, #visualsList do
		if ( isAtTransmogrifier ) then
			-- Everything collected, the unusable among it: 7.3.5 dropped those from the list, and
			-- here they are the offer -- greyed, with the line that names what would lift them.
			if ( visualsList[i].isCollected ) then
				tinsert(filteredVisualsList, visualsList[i]);
			end
		else
			if ( not visualsList[i].isHideVisual ) then
				tinsert(filteredVisualsList, visualsList[i]);
			end
		end
	end
	self.filteredVisualsList = filteredVisualsList;
end

function WardrobeItemsCollectionMixin:SortVisuals()
	local comparison = function(source1, source2)
		if ( source1.isCollected ~= source2.isCollected ) then
			return source1.isCollected;
		end
		if ( source1.isUsable ~= source2.isUsable ) then
			return source1.isUsable;
		end
		if ( source1.isFavorite ~= source2.isFavorite ) then
			return source1.isFavorite;
		end
		if ( source1.isHideVisual ~= source2.isHideVisual ) then
			return source1.isHideVisual;
		end
		if ( source1.hasActiveRequiredHoliday ~= source2.hasActiveRequiredHoliday ) then
			return source1.hasActiveRequiredHoliday;
		end
		if ( source1.uiOrder and source2.uiOrder ) then
			return source1.uiOrder > source2.uiOrder;
		end
		return source1.sourceID > source2.sourceID;
	end

	table.sort(self.filteredVisualsList, comparison);
end

-- Retail takes the arrow keys for the appearance grid only at the transmogrifier, where picking
-- a visual is what the window is for. In the collection they stay with the player.
-- Reached only for a slot change ChangeModelsSlot could not finish, so the guard is whether the
-- player's model is back yet; a false answer leaves the flag up for the next one.
function WardrobeItemsCollectionMixin:OnUnitModelChangedEvent()
	if ( not self.Models[1]:CanSetUnit("player") ) then
		return false;
	end
	self:ChangeModelsSlot();
	self:UpdateItems();
	return true;
end

function WardrobeItemsCollectionMixin:CanHandleKey(key)
	return WardrobeFrame_IsAtTransmogrifier()
	       and ( key == WARDROBE_PREV_VISUAL_KEY or key == WARDROBE_NEXT_VISUAL_KEY
	             or key == WARDROBE_UP_VISUAL_KEY or key == WARDROBE_DOWN_VISUAL_KEY );
end

function WardrobeItemsCollectionMixin:HandleKey(key)
	local _, _, _, selectedVisualID = self:GetActiveSlotInfo();
	local visualsList = self:GetFilteredVisualsList();
	local visualIndex;
	for i = 1, #visualsList do
		if ( visualsList[i].visualID == selectedVisualID ) then
			visualIndex = i;
			break;
		end
	end
	if ( visualIndex ) then
		visualIndex = WardrobeUtils_GetAdjustedDisplayIndexFromKeyPress(self, visualIndex, #visualsList, key);
		self:SelectVisual(visualsList[visualIndex].visualID);
		self.jumpToVisualID = visualsList[visualIndex].visualID;
		self:ResetPage();
	end
end
function WardrobeItemsCollectionMixin:GetActiveSlotInfo()
	return WardrobeCollectionFrame_GetInfoForEquippedSlot(self.activeSlot, self.transmogType);
end

function WardrobeCollectionFrame_GetInfoForEquippedSlot(slot, transmogType)
	local baseSourceID, baseVisualID, appliedSourceID, appliedVisualID, pendingSourceID, pendingVisualID, hasPendingUndo = C_Transmog.GetSlotVisualInfo(GetInventorySlotInfo(slot), transmogType);
	if ( appliedSourceID == NO_TRANSMOG_SOURCE_ID ) then
		appliedSourceID = baseSourceID;
		appliedVisualID = baseVisualID;
	end
	local selectedSourceID, selectedVisualID;
	if ( pendingSourceID ~= REMOVE_TRANSMOG_ID ) then
		selectedSourceID = pendingSourceID;
		selectedVisualID = pendingVisualID;
	elseif ( hasPendingUndo ) then
		selectedSourceID = baseSourceID;
		selectedVisualID = baseVisualID;
	else
		selectedSourceID = appliedSourceID;
		selectedVisualID = appliedVisualID;
	end
	return appliedSourceID, appliedVisualID, selectedSourceID, selectedVisualID;
end

function WardrobeCollectionFrame_GetWeaponInfoForEnchant(slot)
	if ( not WardrobeFrame_IsAtTransmogrifier() and DressUpFrame:IsShown() ) then
		local appearanceSourceID = DressUpModel:GetSlotTransmogSources(GetInventorySlotInfo(slot));
		if ( WardrobeCollectionFrame_CanEnchantSource(appearanceSourceID) ) then
			local _, appearanceVisualID = C_TransmogCollection.GetAppearanceSourceInfo(appearanceSourceID);
			return appearanceSourceID, appearanceVisualID;
		end
	end

	local appliedSourceID, appliedVisualID, selectedSourceID, selectedVisualID = WardrobeCollectionFrame_GetInfoForEquippedSlot(slot, LE_TRANSMOG_TYPE_APPEARANCE);
	if ( WardrobeCollectionFrame_CanEnchantSource(selectedSourceID) ) then
		return selectedSourceID, selectedVisualID;
	else
		local appearanceSourceID = C_TransmogCollection.GetIllusionFallbackWeaponSource();
		local _, appearanceVisualID = C_TransmogCollection.GetAppearanceSourceInfo(appearanceSourceID);
		return appearanceSourceID, appearanceVisualID;
	end
end

function WardrobeCollectionFrame_CanEnchantSource(sourceID)
	local _, _, canEnchant = C_TransmogCollection.GetAppearanceSourceInfo(sourceID);
	return canEnchant;
end

function WardrobeItemsCollectionMixin:UpdateItems()
	local isArmor;
	local cameraID;
	local appearanceSourceID, appearanceVisualID;	-- for weapon when looking at enchants
	local changeModel = false;
	local isAtTransmogrifier = WardrobeFrame_IsAtTransmogrifier();

	if ( self.transmogType == LE_TRANSMOG_TYPE_ILLUSION ) then
		-- for enchants we need to get the visual of the item in that slot
		appearanceSourceID, appearanceVisualID = WardrobeCollectionFrame_GetWeaponInfoForEnchant(self.activeSlot);
		cameraID = C_TransmogCollection.GetAppearanceCameraIDBySource(appearanceSourceID);
		if ( appearanceVisualID ~= self.illusionWeaponVisualID ) then
			self.illusionWeaponVisualID = appearanceVisualID;
			changeModel = true;
		end
	else
		local _, isWeapon = C_TransmogCollection.GetCategoryInfo(self.activeCategory);
		isArmor = not isWeapon;
	end

	local baseSourceID, baseVisualID, appliedSourceID, appliedVisualID, pendingSourceID, pendingVisualID, hasPendingUndo;
	local showUndoIcon;
	if ( isAtTransmogrifier ) then
		baseSourceID, baseVisualID, appliedSourceID, appliedVisualID, pendingSourceID, pendingVisualID, hasPendingUndo = C_Transmog.GetSlotVisualInfo(GetInventorySlotInfo(self.activeSlot), self.transmogType);
		if ( appliedVisualID ~= NO_TRANSMOG_VISUAL_ID ) then
			if ( hasPendingUndo ) then
				pendingVisualID = baseVisualID;
				showUndoIcon = true;
			end
			-- current border (yellow) should only show on untransmogrified items
			baseVisualID = nil;
		end	
		-- hide current border (yellow) or current-transmogged border (purple) if there's something pending
		if ( pendingVisualID ~= NO_TRANSMOG_VISUAL_ID ) then
			baseVisualID = nil;
			appliedVisualID = nil;
		end
	end

	local pendingTransmogModelFrame = nil;
	local indexOffset = (self.PagingFrame:GetCurrentPage() - 1) * self.PAGE_SIZE;
	for i = 1, self.PAGE_SIZE do
		local model = self.Models[i];
		local index = i + indexOffset;
		local visualInfo = self.filteredVisualsList[index];
		if ( visualInfo ) then
			model:Show();

			-- camera
			if ( self.transmogType == LE_TRANSMOG_TYPE_APPEARANCE ) then
				cameraID = C_TransmogCollection.GetAppearanceCameraIDBySource(self:GetAnAppearanceSourceFromVisual(visualInfo.visualID));
			end

			if ( visualInfo ~= model.visualInfo or changeModel ) then
				if ( isArmor ) then
					local sourceID = self:GetAnAppearanceSourceFromVisual(visualInfo.visualID);
					model:TryOn(sourceID);
				else
					-- A weapon is drawn on its own, the way 8.x draws these cells: the item's
					-- model with its texture and nothing to hold it.
					if ( appearanceSourceID ) then
						-- appearanceSourceID is only set when looking at enchants
						model:SetItemModel(appearanceSourceID, visualInfo.visualID);
					else
						model:SetItemModel(self:GetAnAppearanceSourceFromVisual(visualInfo.visualID));
					end
				end
			end
			model.visualInfo = visualInfo;
			model:ApplyUICamera(cameraID);

			-- state at the transmogrifier
			local transmogStateAtlas;
			if ( visualInfo.visualID == appliedVisualID ) then
				transmogStateAtlas = "transmog-wardrobe-border-current-transmogged";
			elseif ( visualInfo.visualID == baseVisualID ) then
				transmogStateAtlas = "transmog-wardrobe-border-current";
			elseif ( visualInfo.visualID == pendingVisualID ) then
				transmogStateAtlas = "transmog-wardrobe-border-selected";
				pendingTransmogModelFrame = model;
			end
			if ( transmogStateAtlas ) then
				model.TransmogStateTexture:SetAtlas(transmogStateAtlas, true);
				model.TransmogStateTexture:Show();
			else
				model.TransmogStateTexture:Hide();
			end

			-- border
			if ( not visualInfo.isCollected ) then
				model.Border:SetAtlas("transmog-wardrobe-border-uncollected");
			elseif ( not visualInfo.isUsable ) then
				model.Border:SetAtlas("transmog-wardrobe-border-unusable");
			else
				model.Border:SetAtlas("transmog-wardrobe-border-collected");
			end
			-- Retail's reading of a dim cell, on both windows: in the collection it is a look the
			-- account has not got, and at the transmogrifier -- where only collected looks are
			-- listed -- it is one this character cannot put on. The red border marks the second
			-- case in the collection, and the tooltip says why.
			if ( isAtTransmogrifier ) then
				model:SetDimmed(not visualInfo.isUsable);
			else
				model:SetDimmed(not visualInfo.isCollected);
			end

			if ( C_TransmogCollection.IsNewAppearance(visualInfo.visualID) ) then
				model.NewString:Show();
				model.NewGlow:Show();
			else
				model.NewString:Hide();
				model.NewGlow:Hide();
			end
			-- favorite
			model.Favorite.Icon:SetShown(visualInfo.isFavorite);
			-- hide visual option
			model.HideVisual.Icon:SetShown(isAtTransmogrifier and visualInfo.isHideVisual);

			if ( GameTooltip:GetOwner() == model ) then
				model:OnEnter();
			end
			
		else
			model:Hide();
			model.visualInfo = nil;
		end
	end
	if ( pendingTransmogModelFrame ) then
		self.PendingTransmogFrame:SetParent(pendingTransmogModelFrame);
		self.PendingTransmogFrame:SetPoint("CENTER");
		self.PendingTransmogFrame:Show();
		if ( self.PendingTransmogFrame.visualID ~= pendingVisualID ) then
			WardrobePendingTransmogFrame_PlayAnims(self.PendingTransmogFrame);
		end
		self.PendingTransmogFrame.UndoIcon:SetShown(showUndoIcon);
		self.PendingTransmogFrame.visualID = pendingVisualID;
	else
		self.PendingTransmogFrame:Hide();
	end
	-- progress bar
	self:UpdateProgressBar();
end

function WardrobeItemsCollectionMixin:UpdateProgressBar()
	local collected, total;
	if ( self.transmogType == LE_TRANSMOG_TYPE_ILLUSION ) then
		total = #self.visualsList;
		collected = 0;
		for i, illusion in ipairs(self.visualsList) do
			if ( illusion.isCollected ) then
				collected = collected + 1;
			end
		end
	else
		collected = C_TransmogCollection.GetCategoryCollectedCount(self.activeCategory);
		total = C_TransmogCollection.GetCategoryTotal(self.activeCategory);
	end
	WardrobeCollectionFrame.progressBar:SetProgress(collected, total);
end

function WardrobeCollectionFrame_SortSources(sources, primaryVisualID, primarySourceID)
	local comparison = function(source1, source2)
		-- if a primary visual is given, sources for that are grouped by themselves above all others
		if ( primaryVisualID and source1.visualID ~= source2.visualID ) then
			return source1.visualID == primaryVisualID;
		end

		if ( source1.isCollected ~= source2.isCollected ) then
			return source1.isCollected;
		end

		if ( primarySourceID ) then
			local source1IsPrimary = (source1.sourceID == primarySourceID);
			local source2IsPrimary = (source2.sourceID == primarySourceID);
			if ( source1IsPrimary ~= source2IsPrimary ) then
				return source1IsPrimary;
			end
		end

		if ( source1.quality and source2.quality ) then
			if ( source1.quality ~= source2.quality ) then
				return source1.quality > source2.quality;
			end
		else
			return source1.quality;
		end

		return source1.sourceID > source2.sourceID;
	end
	table.sort(sources, comparison);
	return sources;
end

function WardrobeCollectionFrame_GetSortedAppearanceSources(visualID, slotID, categoryID)
	local sources = C_TransmogCollection.GetAppearanceSources(visualID, slotID, categoryID);
	return WardrobeCollectionFrame_SortSources(sources);
end

-- The inventory slot the looks would go into, and only at the transmogrifier: the armour type is
-- asked of the pair, a look against the item worn in the slot, so it has no answer in the
-- collection window, where nothing is being put on anything.
function WardrobeItemsCollectionMixin:GetTransmogrifySlotID()
	if ( WardrobeFrame_IsAtTransmogrifier() and self.activeSlot ) then
		return GetInventorySlotInfo(self.activeSlot);
	end
end

function WardrobeItemsCollectionMixin:RefreshVisualsList()
	if ( self.transmogType == LE_TRANSMOG_TYPE_ILLUSION ) then
		self.visualsList = C_TransmogCollection.GetIllusions();
	else
		self.visualsList = C_TransmogCollection.GetCategoryAppearances(self.activeCategory, self:GetTransmogrifySlotID());
	end
	self:FilterVisuals();
	self:SortVisuals();
	self.PagingFrame:SetMaxPages(ceil(#self.filteredVisualsList / self.PAGE_SIZE));
end

function WardrobeItemsCollectionMixin:GetFilteredVisualsList()
	return self.filteredVisualsList;
end

function WardrobeItemsCollectionMixin:GetAnAppearanceSourceFromVisual(visualID, mustBeUsable)
	local chosen = self:GetChosenVisualSource(visualID);
	local sources = WardrobeCollectionFrame_GetSortedAppearanceSources(visualID, self:GetTransmogrifySlotID(), self.activeCategory);
	local first = NO_TRANSMOG_SOURCE_ID;
	for i = 1, #sources do
		local source = sources[i];
		if ( not mustBeUsable or (source.isCollected and not source.useError) ) then
			if ( source.sourceID == chosen ) then
				return chosen;
			end
			if ( first == NO_TRANSMOG_SOURCE_ID ) then
				first = source.sourceID;
			end
		end
	end
	return first;
end

function WardrobeItemsCollectionMixin:SelectVisual(visualID)
	if ( not WardrobeFrame_IsAtTransmogrifier() ) then
		return;
	end

	local sourceID;
	if ( self.transmogType == LE_TRANSMOG_TYPE_APPEARANCE ) then
		sourceID = self:GetAnAppearanceSourceFromVisual(visualID, true);
	else
		local visualsList = self:GetFilteredVisualsList();
		for i = 1, #visualsList do
			if ( visualsList[i].visualID == visualID ) then
				sourceID = visualsList[i].sourceID;
				break;
			end
		end
	end
	-- No eligible source is a refusal, never the zero used by an explicit undo.
	if ( self.transmogType == LE_TRANSMOG_TYPE_APPEARANCE and sourceID == NO_TRANSMOG_SOURCE_ID ) then
		local sources = WardrobeCollectionFrame_GetSortedAppearanceSources(visualID, self:GetTransmogrifySlotID(), self.activeCategory);
		local message = sources[1] and sources[1].useError or ERR_TRANSMOGRIFY_INVALID_SOURCE;
		UIErrorsFrame:AddMessage(message, RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b, 1.0);
		return;
	end

	local slotID = GetInventorySlotInfo(self.activeSlot);
	C_Transmog.SetPending(slotID, self.transmogType, sourceID);
	PlaySound("igMainMenuOptionCheckBoxOn");
end

function WardrobeCollectionFrame_OpenTransmogLink(link)
	if ( not CollectionsJournal:IsVisible() ) then
		ToggleCollections();
	end
	if ( not WardrobeCollectionFrame:IsVisible() ) then
		CollectionsJournal:SelectTabID(CollectionsJournal.wardrobeTabID);
	end

	local linkType, id = strsplit(":", link);

	if ( linkType == "transmogappearance" ) then
		local sourceID = tonumber(id);
		WardrobeCollectionFrame_SetTab(TAB_ITEMS);
		WardrobeCollectionFrame.ItemsCollectionFrame:GoToSourceID(sourceID, nil, LE_TRANSMOG_TYPE_APPEARANCE);
	elseif ( linkType == "transmogset") then
		local setID = tonumber(id);
		WardrobeCollectionFrame_SetTab(TAB_SETS);
		WardrobeCollectionFrame.SetsCollectionFrame:SelectSet(setID);
	end
end

function WardrobeItemsCollectionMixin:GoToSourceID(sourceID, slot, transmogType, forceGo)
	local categoryID, visualID;
	if ( transmogType == LE_TRANSMOG_TYPE_APPEARANCE ) then
		categoryID, visualID = C_TransmogCollection.GetAppearanceSourceInfo(sourceID);
		slot = slot or WardrobeCollectionFrame_GetSlotFromCategoryID(categoryID);
	elseif ( transmogType == LE_TRANSMOG_TYPE_ILLUSION ) then
		visualID = C_TransmogCollection.GetIllusionSourceInfo(sourceID);
		slot = slot or "MAINHANDSLOT";
	end
	if ( visualID or forceGo ) then
		self.jumpToVisualID = visualID;
		if ( self.activeCategory ~= categoryID or self.activeSlot ~= slot ) then
			self:SetActiveSlot(slot, transmogType, categoryID);
		else
			self:ResetPage();
		end
	end
end

function WardrobeItemsCollectionMixin:SetAppearanceTooltip(frame)
	GameTooltip:SetOwner(frame, "ANCHOR_RIGHT");
	self.tooltipVisualID = frame.visualInfo.visualID;
	self:RefreshAppearanceTooltip();
end

function WardrobeItemsCollectionMixin:RefreshAppearanceTooltip()
	if ( not self.tooltipVisualID ) then
		return;
	end
	local sources = WardrobeCollectionFrame_GetSortedAppearanceSources(self.tooltipVisualID, self:GetTransmogrifySlotID(), self.activeCategory);
	local chosenSourceID = self:GetChosenVisualSource(self.tooltipVisualID);
	WardrobeCollectionFrame_SetAppearanceTooltip(self, sources, chosenSourceID);
end

function WardrobeItemsCollectionMixin:ClearAppearanceTooltip()
	self.tooltipVisualID = nil;
	WardrobeCollectionFrame_HideAppearanceTooltip();
end

function WardrobeCollectionFrame_GetSlotFromCategoryID(categoryID)
	local slot;
	for i = 1, #TRANSMOG_SLOTS do
		if ( TRANSMOG_SLOTS[i].armorCategoryID == categoryID ) then
			slot = TRANSMOG_SLOTS[i].slot;
			break;
		end
	end
	if ( not slot ) then
		local name, isWeapon, canEnchant, canMainHand, canOffHand = C_TransmogCollection.GetCategoryInfo(categoryID);
		if ( WardrobeUtils_IsCategoryRanged(categoryID) ) then
			slot = "RANGEDSLOT";
		elseif ( canMainHand ) then
			slot = "MAINHANDSLOT";
		elseif ( canOffHand ) then
			slot = "SECONDARYHANDSLOT";
		end
	end
	return slot;
end

-- ***** MODELS

WardrobeItemsModelMixin = { };

-- The era's SetLight takes its two flags as numbers; a boolean is a usage error that ends OnLoad.
-- A cell is greyed by a fraction of the ambient, which is how a model frame greys out at all: it
-- has no desaturation, and dimming the frame itself would take the border with it.
local ITEMS_MODEL_LIGHT = { 1, 0, -1, 1, -1, 1.05, 1, 1, 1, 0, 1, 1, 1 };
local ITEMS_MODEL_LIGHT_DIM = { 1, 0, -1, 1, -1, 0.4, 1, 1, 1, 0, 1, 1, 1 };

function WardrobeItemsModelMixin:OnLoad()
	self:SetAutoDress(false);
	self:SetLight(unpack(ITEMS_MODEL_LIGHT));
end

function WardrobeItemsModelMixin:SetDimmed(dimmed)
	self:SetLight(unpack(dimmed and ITEMS_MODEL_LIGHT_DIM or ITEMS_MODEL_LIGHT));
end

function WardrobeItemsModel_OnLoad(self)
	Mixin(self, "WardrobeItemsModelMixin");
	SetParentArray(self, "Models");
	self.Border:SetAtlas("transmog-wardrobe-border-collected", true);
	self.NewGlow:SetAtlas("collections-newglow");
	self.HighlightTexture:SetAtlas("transmog-wardrobe-border-highlighted", true);
	self.Favorite.Icon:SetAtlas("collections-icon-favorites", true);
	self.HideVisual.Icon:SetAtlas("transmog-icon-hidden", true);
	self:OnLoad();
end

function WardrobeItemsModelMixin:OnMouseDown(button)
	local transmogType = self:GetParent().transmogType;
	if ( IsModifiedClick("CHATLINK") ) then
		-- An illusion has no item link of its own, so only an appearance can be linked here.
		if ( transmogType ~= LE_TRANSMOG_TYPE_ILLUSION and WardrobeCollectionFrame.tooltipSourceIndex ) then
			local parent = self:GetParent();
			local sources = WardrobeCollectionFrame_GetSortedAppearanceSources(self.visualInfo.visualID, parent:GetTransmogrifySlotID(), parent.activeCategory);
			local index = WardrobeUtils_GetValidIndexForNumSources(WardrobeCollectionFrame.tooltipSourceIndex, #sources);
			local link = select(6, C_TransmogCollection.GetAppearanceSourceInfo(sources[index].sourceID));
			if ( link ) then
				HandleModifiedItemClick(link);
			end
		end
		return;
	elseif ( IsModifiedClick("DRESSUP") ) then
		local slot = self:GetParent():GetActiveSlot();
		if ( transmogType == LE_TRANSMOG_TYPE_APPEARANCE ) then
			local sourceID = self:GetParent():GetAnAppearanceSourceFromVisual(self.visualInfo.visualID);
			-- don't specify a slot for ranged weapons
			if ( WardrobeUtils_IsCategoryRanged(self:GetParent():GetActiveCategory()) ) then
				slot = nil;
			end
			WardrobeDressUp(sourceID, slot);
		elseif ( transmogType == LE_TRANSMOG_TYPE_ILLUSION ) then
			local weaponSourceID = WardrobeCollectionFrame_GetWeaponInfoForEnchant(slot);
			WardrobeDressUp(weaponSourceID, slot, self.visualInfo.sourceID);
		end
		return;
	end

	if ( button == "LeftButton" ) then
		RebuffedMenu:Close();
		self:GetParent():SelectVisual(self.visualInfo.visualID);
	elseif ( button == "RightButton" ) then
		if ( RebuffedMenu:IsOpen(self) ) then
			RebuffedMenu:Close(self);
			return;
		end
		RebuffedMenu:Close();
		if ( not self.visualInfo.isCollected or self.visualInfo.isHideVisual or transmogType == LE_TRANSMOG_TYPE_ILLUSION ) then
			return;
		end
		RebuffedMenu:Open(self, self:GetParent():GetModelMenuEntries(self), nil, "LEFT");
		PlaySound("igMainMenuOptionCheckBoxOn");
	end
end

function WardrobeItemsModelMixin:OnEnter()
	if ( not self.visualInfo ) then
		return;
	end
	self:SetScript("OnUpdate", self.OnUpdate);
	if ( C_TransmogCollection.IsNewAppearance(self.visualInfo.visualID) ) then
		C_TransmogCollection.ClearNewAppearance(self.visualInfo.visualID);
		self.NewString:Hide();
		self.NewGlow:Hide();
	end
	if ( self:GetParent().transmogType == LE_TRANSMOG_TYPE_ILLUSION ) then
		local visualID, name = C_TransmogCollection.GetIllusionSourceInfo(self.visualInfo.sourceID);
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		GameTooltip:SetText(name);
		GameTooltip:Show();
	else
		self:GetParent():SetAppearanceTooltip(self);
	end
end

function WardrobeItemsModelMixin:OnLeave()
	self:SetScript("OnUpdate", nil);
	ResetCursor();
	self:GetParent():ClearAppearanceTooltip();
end

function WardrobeItemsModelMixin:OnUpdate()
	if IsModifiedClick("DRESSUP") then
		ShowInspectCursor();
	else
		ResetCursor();
	end
end

-- An armour slot's cells show the mannequin; a weapon slot's cells show the weapon alone, each
-- one set by UpdateItems, so they only drop the character here.
function WardrobeItemsModelMixin:Reload(slot)
	if ( WardrobeUtils_GetArmorCategoryIDFromSlot(slot) ) then
		self:SetUnit("player", false);
	else
		self:ClearModel();
	end
	self.cameraID = nil;
end

WardrobeSetsTransmogModelMixin = { };

function WardrobeSetsTransmogModelMixin:OnLoad()
	self:RegisterEvent("DISPLAY_SIZE_CHANGED");
	self:SetAutoDress(false);
	self:SetUnit("player");
	self:SetLight(1, 0, -1, 1, -1, 1, 1, 1, 1, 0, 1, 1, 1);
end

function WardrobeSetsTransmogModelMixin:OnEvent()
	self:RefreshCamera();
end

function WardrobeSetsTransmogModel_OnLoad(self)
	SetParentArray(self, "Models");
	self.Border:SetAtlas("transmog-set-border-collected", true);
	self.HighlightTexture:SetAtlas("transmog-set-border-highlighted", true);
	self.Favorite.Icon:SetAtlas("collections-icon-favorites", true);
	MixinAndLoadScripts(self, "WardrobeSetsTransmogModelMixin");
end

function WardrobeSetsTransmogModelMixin:OnMouseDown(button)
	if ( button == "LeftButton" ) then
		self:GetParent():SelectSet(self.setID);
		PlaySound("igMainMenuOptionCheckBoxOn");
	elseif ( button == "RightButton" ) then
		if ( RebuffedMenu:IsOpen(self) ) then
			RebuffedMenu:Close(self);
			return;
		end
		RebuffedMenu:Open(self, self:GetParent():GetModelMenuEntries(self.setID), nil, "LEFT");
		PlaySound("igMainMenuOptionCheckBoxOn");
	end
end

-- ITEM_QUALITY_COLORS stops at 6. An heirloom is quality 7 -- fourteen of the appearance sources
-- on this realm are -- so indexing that table by an item's quality is nil for them, and the
-- tooltip that reads .r off it dies while the page is being drawn. The client's own
-- GetItemQualityColor answers 7 (with the artifact gold), so it is asked instead of the table.
local function QualityColor(quality)
	local r, g, b, hex = GetItemQualityColor(quality or 1);
	return { r = r, g = g, b = b, hex = hex };
end
function WardrobeSetsTransmogModelMixin:OnEnter()
	self:GetParent().tooltipModel = self;
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
	self:RefreshTooltip();
end

function WardrobeSetsTransmogModelMixin:RefreshTooltip()
	local totalQuality = 0;
	local numTotalSlots = 0;
	local sourceQualityTable = self:GetParent().sourceQualityTable;
	local sources = C_TransmogSets.GetSetSources(self.setID);
	for sourceID in pairs(sources) do
		numTotalSlots = numTotalSlots + 1;
		if ( not sourceQualityTable[sourceID] ) then
			sourceQualityTable[sourceID] = C_TransmogCollection.GetSourceInfo(sourceID).quality;
		end
		totalQuality = totalQuality + sourceQualityTable[sourceID];
	end
	local setQuality = Round(totalQuality / numTotalSlots);
	local color = QualityColor(setQuality);
	local setInfo = C_TransmogSets.GetSetInfo(self.setID);
	GameTooltip:SetText(setInfo.name, color.r, color.g, color.b);
	if ( setInfo.label ) then
		GameTooltip:AddLine(setInfo.label);
		GameTooltip:Show();
	end
end

function WardrobeSetsTransmogModelMixin:OnLeave()
	GameTooltip:Hide();
	self:GetParent().tooltipModel = nil;
end

function WardrobeSetsTransmogModelMixin:OnHide()
	self.setID = nil;
end

function WardrobeCollectionFrame_HideAppearanceTooltip()
	WardrobeCollectionFrame.tooltipSourceIndex = nil;
	WardrobeCollectionFrame.tooltipCycle = nil;
	WardrobeCollectionFrame.tooltipContentFrame = nil;
	WardrobeCollectionFrame:SetPropagateKeyboardInput(true);
	GameTooltip:Hide();
end

function WardrobeCollectionFrame_GetDefaultSourceIndex(sources, primarySourceID)
	local collectedSourceIndex;
	local uncollectedSourceIndex;
	-- default sourceIndex is, in order of preference:
	-- 1. primarySourceID, if collected
	-- 2. collected
	-- 3. uncollected primarySourceID
	-- 4. uncollected
	for i, sourceInfo in ipairs(sources) do
		if ( sourceInfo.isCollected ) then
			if ( primarySourceID == sourceInfo.sourceID ) then
				-- found #1
				collectedSourceIndex = i;
				break;
			elseif ( not collectedSourceIndex ) then
				collectedSourceIndex = i;
				if ( primarySourceID == NO_TRANSMOG_SOURCE_ID ) then
					-- done
					break;
				end
			end
		else
			if ( not uncollectedSourceIndex or primarySourceID == sourceInfo.sourceID ) then
				uncollectedSourceIndex = i;
			end
		end
	end
	return collectedSourceIndex or uncollectedSourceIndex or 1;
end

function WardrobeCollectionFrame_SetAppearanceTooltip(contentFrame, sources, primarySourceID)
	WardrobeCollectionFrame.tooltipContentFrame = contentFrame;
	for i = 1, #sources do
		if ( sources[i].isHideVisual ) then
			GameTooltip:SetText(sources[i].name);
			return;
		end
	end

	local firstVisualID = sources[1].visualID;
	local passedFirstVisualID = false;

	local headerIndex;
	if ( not WardrobeCollectionFrame.tooltipSourceIndex ) then
		headerIndex = WardrobeCollectionFrame_GetDefaultSourceIndex(sources, primarySourceID);
	else
		headerIndex = WardrobeUtils_GetValidIndexForNumSources(WardrobeCollectionFrame.tooltipSourceIndex, #sources);
	end
	WardrobeCollectionFrame.tooltipSourceIndex = headerIndex;

	local name, nameColor, sourceText, sourceColor = WardrobeCollectionFrameModel_GetSourceTooltipInfo(sources[headerIndex]);
	GameTooltip:SetText(name, nameColor.r, nameColor.g, nameColor.b);

	if ( sourceText ) then
		GameTooltip:AddLine(sourceText, sourceColor.r, sourceColor.g, sourceColor.b, 1, 1);
	end

	local appearanceCollected = sources[headerIndex].isCollected
	if ( #sources > 1 ) then
		-- only add "Other items using this appearance" if we're continuing to the same visualID
		if ( firstVisualID == sources[2].visualID ) then
			GameTooltip:AddLine(" ");
			GameTooltip:AddLine(WARDROBE_OTHER_ITEMS, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b);
		end
		for i = 1, #sources do
			-- first time we transition to a different visualID, add "Other items that unlock this slot"
			if ( not passedFirstVisualID and firstVisualID ~= sources[i].visualID ) then
				passedFirstVisualID = true;
				GameTooltip:AddLine(" ");
				GameTooltip:AddLine(WARDROBE_ALTERNATE_ITEMS);
			end

			local name, nameColor, sourceText, sourceColor = WardrobeCollectionFrameModel_GetSourceTooltipInfo(sources[i]);
			if ( i == headerIndex ) then
				name = WARDROBE_TOOLTIP_CYCLE_ARROW_ICON..name;
			else
				name = WARDROBE_TOOLTIP_CYCLE_SPACER_ICON..name;
			end
			GameTooltip:AddDoubleLine(name, sourceText or "", nameColor.r, nameColor.g, nameColor.b, sourceColor.r, sourceColor.g, sourceColor.b);
		end
		GameTooltip:AddLine(" ");
		GameTooltip:AddLine(WARDROBE_TOOLTIP_CYCLE, GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b, true);
		WardrobeCollectionFrame.tooltipCycle = true;
	else
		WardrobeCollectionFrame.tooltipCycle = nil;
	end

	-- What this character cannot wear, and why, in the place retail says it: the class or race the
	-- item asks for, or the level. Nothing says it when the account carries Whitemane+, which the
	-- server answers by sending no requirements at all.
	local useError = sources[headerIndex].useError;
	if ( useError ) then
		GameTooltip:AddLine(useError, RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b, true);
	elseif ( appearanceCollected and not WardrobeFrame_IsAtTransmogrifier() ) then
		GameTooltip:AddLine(WARDROBE_TOOLTIP_TRANSMOGRIFIER, GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b, 1, 1);
	end

	GameTooltip:Show();
end


function WardrobeCollectionFrameModel_GetSourceTooltipInfo(source)
	local name = source.name;
	local nameColor = QualityColor(source.quality);

	local sourceText, sourceColor;
	if ( source.isCollected ) then
		sourceText = COLLECTIONS_FILTER_COLLECTED;
		sourceColor = GREEN_FONT_COLOR;
	else
		if ( source.sourceType ~= 0 ) then
			sourceText = _G["TRANSMOG_SOURCE_"..source.sourceType];
		end
		sourceColor = HIGHLIGHT_FONT_COLOR;
	end

	return name, nameColor, sourceText, sourceColor;
end

function WardrobeItemsCollectionMixin:GetChosenVisualSource(visualID)
	return self.chosenVisualSources[visualID] or NO_TRANSMOG_SOURCE_ID;
end

function WardrobeItemsCollectionMixin:SetChosenVisualSource(visualID, sourceID)
	self.chosenVisualSources[visualID] = sourceID;
end

function WardrobeItemsCollectionMixin:ValidateChosenVisualSources()
	for visualID, sourceID in pairs(self.chosenVisualSources) do
		if ( sourceID ~= NO_TRANSMOG_SOURCE_ID ) then
			local keep = false;
			local sources = C_TransmogCollection.GetAppearanceSources(visualID);
			if ( sources ) then
				for i = 1, #sources do
					if ( sources[i].sourceID == sourceID ) then
						if ( sources[i].isCollected ) then
							keep = true;
						end
						break;
					end
				end
			end
			if ( not keep ) then
				self.chosenVisualSources[visualID] = NO_TRANSMOG_SOURCE_ID;
			end
		end
	end
end

-- The appearance's own menu, as a list of entries for RebuffedMenu: favourite, cancel, and every
-- collected source this visual can be worn as. No UIDropDownMenu state is kept for it.
function WardrobeItemsCollectionMixin:GetModelMenuEntries(modelFrame)
	local appearanceID = modelFrame.visualInfo.visualID;
	local isFavorite = C_TransmogCollection.GetIsAppearanceFavorite(appearanceID);
	local entries = {
		{
			text = isFavorite and BATTLE_PET_UNFAVORITE or BATTLE_PET_FAVORITE,
			notCheckable = true,
			func = function() C_TransmogCollection.SetIsAppearanceFavorite(appearanceID, not isFavorite); end,
		},
		{ text = CANCEL, notCheckable = true, func = function() end },
	};

	local sources = WardrobeCollectionFrame_GetSortedAppearanceSources(appearanceID, self:GetTransmogrifySlotID(), self.activeCategory);
	local chosenSourceID = self:GetChosenVisualSource(appearanceID);
	local headerInserted = false;
	for i = 1, #sources do
		if ( sources[i].isCollected ) then
			if ( not headerInserted ) then
				headerInserted = true;
				entries[#entries + 1] = { text = " ", notCheckable = true, disabled = true };
				entries[#entries + 1] = {
					text = NORMAL_FONT_COLOR_CODE..WARDROBE_TRANSMOGRIFY_AS..FONT_COLOR_CODE_CLOSE,
					notCheckable = true,
					isTitle = true,
				};
			end
			local sourceID = sources[i].sourceID;
			-- The first collected source is the chosen one until one is picked explicitly.
			if ( chosenSourceID == NO_TRANSMOG_SOURCE_ID ) then
				chosenSourceID = sourceID;
			end
			entries[#entries + 1] = {
				text = QualityColor(sources[i].quality).hex..sources[i].name..FONT_COLOR_CODE_CLOSE,
				checked = (chosenSourceID == sourceID),
				func = function() self:SetChosenVisualSource(appearanceID, sourceID); end,
			};
		end
	end

	return entries;
end

-- ***** WEAPON DROPDOWN

function WardrobeCollectionFrameWeaponDropDown_OnLoad(self)
	-- The era replaces an inherited handler rather than chaining it, so the art template's own
	-- OnLoad never runs for this button and its mixin is taken here instead. The button is 140
	-- wide because that is what the widest name needs: "One-Handed Swords" measures 104 px and
	-- the two caps take 28. The stock dropdown's 140 was its text width, which is why the frame
	-- used to be wider than this.
	MixinAndLoadScripts(self, "DropdownButtonArtMixin");
	self:UpdateArt();
end

function WardrobeCollectionFrameWeaponDropDown_Toggle(self)
	if ( RebuffedMenu:IsOpen(self) ) then
		RebuffedMenu:Close(self);
		return;
	end
	RebuffedMenu:Open(self, (WardrobeCollectionFrameWeaponDropDown_GetEntries()));
end

function WardrobeCollectionFrameWeaponDropDown_GetEntries()

	-- Initialize runs this once from OnLoad, while the collection frame's children are still
	-- loading: its methods arrive with its own OnLoad, after this one, so the era has nothing to
	-- ask yet. Retail's XML mixin attribute gave the frame its methods before any child loaded.
	local itemsFrame = WardrobeCollectionFrame.ItemsCollectionFrame;
	local slot = itemsFrame and itemsFrame.GetActiveSlot and itemsFrame:GetActiveSlot();
	if ( not slot ) then
		return {}, 0;
	end

	local selectedValue = itemsFrame:GetActiveCategory();
	local entries = {};

	local equippedItemID = GetInventoryItemID("player", GetInventorySlotInfo(slot));
	local checkCategory = equippedItemID and WardrobeFrame_IsAtTransmogrifier();
	if ( checkCategory ) then
		-- if the equipped item cannot be transmogrified, relax restrictions
		local isTransmogrified, hasPending, isPendingCollected, canTransmogrify, cannotTransmogrifyReason, hasUndo = C_Transmog.GetSlotInfo(GetInventorySlotInfo(slot), LE_TRANSMOG_TYPE_APPEARANCE);
		if ( not canTransmogrify and not hasUndo ) then
			checkCategory = false;
		end
	end
	local buttonsAdded = 0;
	
	for categoryID = FIRST_TRANSMOG_COLLECTION_WEAPON_TYPE, LAST_TRANSMOG_COLLECTION_WEAPON_TYPE do
		local name, isWeapon, canEnchant, canMainHand, canOffHand = C_TransmogCollection.GetCategoryInfo(categoryID);
		if ( name and isWeapon ) then
			local fits;
			if ( checkCategory ) then
				fits = WardrobeUtils_CategoryFitsWornItem(categoryID, slot, equippedItemID);
			else
				fits = WardrobeUtils_CategoryFitsSlot(categoryID, slot, canMainHand, canOffHand);
			end
			if ( fits ) then
				buttonsAdded = buttonsAdded + 1;
				entries[buttonsAdded] = {
					text = name,
					value = categoryID,
					arg1 = categoryID,
					checked = categoryID == selectedValue,
					func = WardrobeCollectionFrameWeaponDropDown_OnClick,
				};
			end
		end
	end
	return entries, buttonsAdded;
end

function WardrobeCollectionFrameWeaponDropDown_OnClick(self, category)
	if ( category and WardrobeCollectionFrame.ItemsCollectionFrame:GetActiveCategory() ~= category ) then
		WardrobeCollectionFrame.ItemsCollectionFrame:SetActiveCategory(category);
	end	
end

-- ***** NAVIGATION

-- Turning to a page whose models the client has never read out of the archive stalls one long
-- frame while it reads them. Measured on a slot nothing had opened: a single 291 ms frame for
-- three pages, against a worst of 17 ms once the same pages are warm. Freeing the cache is not
-- what costs -- purging twice and returning still measures 18 ms -- so the only thing left is to
-- do the reading before it is asked for. The next page is known the moment this one is drawn, so
-- its appearances are handed to an off-screen model a few per frame while the player looks at the
-- current page. Measured after: 63 ms for the pages that had been asked for ahead.
local PREFETCH_PER_FRAME = 3;

function WardrobeItemsCollectionMixin:QueuePrefetch()
	local queue = {};
	local offset = self.PagingFrame:GetCurrentPage() * self.PAGE_SIZE;   -- the page after this one
	for i = 1, self.PAGE_SIZE do
		local visualInfo = self.filteredVisualsList and self.filteredVisualsList[i + offset];
		if ( visualInfo ) then
			local sourceID = self:GetAnAppearanceSourceFromVisual(visualInfo.visualID);
			if ( sourceID ) then
				queue[#queue + 1] = sourceID;
			end
		end
	end
	self.prefetchQueue = queue;
	self.prefetchIndex = 1;
	self.PrefetchModel:SetShown(#queue > 0);
end

function WardrobeItemsCollectionMixin:PrefetchStep()
	local queue = self.prefetchQueue;
	if ( not queue ) then
		self.PrefetchModel:Hide();
		return;
	end

	for _ = 1, PREFETCH_PER_FRAME do
		local sourceID = queue[self.prefetchIndex];
		if ( not sourceID ) then
			-- Done. The model keeps the last one it was given, which is one more the cache holds.
			self.prefetchQueue = nil;
			self.PrefetchModel:Hide();
			return;
		end
		self.prefetchIndex = self.prefetchIndex + 1;
		self.PrefetchModel:TryOn(sourceID);
	end
end

function WardrobeItemsCollectionMixin:OnPageChanged(userAction)
	PlaySound("igAbiliityPageTurn");
	RebuffedMenu:Close();
	if ( userAction ) then
		self:UpdateItems();
	end
	-- The page just turned, so the models the last one staged are drawn by nothing. The client
	-- would free them ten seconds from now, which is slower than anyone pages: measured over
	-- all 63 pages of the appearance list, a page turn costs 5.7 ms over the first ten and
	-- 83.5 ms over the last ten, and 4.5 ms throughout with this call.
	C_TransmogCollection.PurgeModelCache();
	self:QueuePrefetch();
end

-- ***** SEARCHING

function WardrobeCollectionFrame_SwitchSearchCategory()
	if ( WardrobeCollectionFrame.ItemsCollectionFrame.transmogType == LE_TRANSMOG_TYPE_ILLUSION ) then
		WardrobeCollectionFrame_ClearSearch();
		WardrobeCollectionFrame.searchBox:Disable();
		WardrobeCollectionFrame.FilterButton:Disable();
		return;
	end

	WardrobeCollectionFrame.searchBox:Enable();
	WardrobeCollectionFrame.FilterButton:Enable();
	-- On the first show the items pane's OnShow runs before the collection frame's own OnShow has
	-- picked a tab, so there is no active frame to search yet.
	local activeFrame = WardrobeCollectionFrame.activeFrame;
	if ( activeFrame and WardrobeCollectionFrame.searchBox:GetText() ~= "" )  then
		C_TransmogCollection.SetSearch(activeFrame.searchType, WardrobeCollectionFrame.searchBox:GetText());
		activeFrame:OnSearchUpdate();
	end
end

function WardrobeItemsCollectionMixin:OnSearchUpdate()
	self:RefreshVisualsList();
	if ( WardrobeFrame_IsAtTransmogrifier() and WardrobeCollectionFrameSearchBox:GetText() == "" ) then
		local _, _, selectedSourceID = WardrobeCollectionFrame_GetInfoForEquippedSlot(self.activeSlot, self.transmogType);
		local categoryID = C_TransmogCollection.GetAppearanceSourceInfo(selectedSourceID);
		if ( categoryID == self:GetActiveCategory() ) then
			WardrobeCollectionFrame.ItemsCollectionFrame:GoToSourceID(selectedSourceID, self.activeSlot, self.transmogType, true);
		else
			self:UpdateItems();
		end
	else
		self:UpdateItems();
	end
end

function WardrobeCollectionFrame_ClearSearch(searchType)
	WardrobeCollectionFrame.searchBox:SetText("");
	C_TransmogCollection.ClearSearch(searchType or WardrobeCollectionFrame.activeFrame.searchType);
end

function WardrobeCollectionFrameSearchBox_OnLoad(self)
	SearchBoxTemplate_OnLoad(self);
	-- The template's OnUpdate drives its Ctrl+F focus, which needs IsKeyDown; the world has none.
	self:SetScript("OnUpdate", nil);
end

function WardrobeCollectionFrameSearchBox_OnTextChanged(self)
	SearchBoxTemplate_OnTextChanged(self);

	local text = self:GetText();
	if ( text == "" ) then
		C_TransmogCollection.ClearSearch(WardrobeCollectionFrame.activeFrame.searchType);
	else
		C_TransmogCollection.SetSearch(WardrobeCollectionFrame.activeFrame.searchType, text);
	end

	WardrobeCollectionFrame.activeFrame:OnSearchUpdate();
end

-- ***** FILTER

-- The shared filter button keeps its rows in a table the filter API fills. The wardrobe's filters
-- live in C_TransmogCollection and C_TransmogSets and differ per tab, so its button builds them
-- when the menu opens instead. Everything else about the control -- art, toggle, close on hide,
-- the clear-filter button -- comes from the template.
WardrobeFilterButtonMixin = { };

function WardrobeFilterButtonMixin:GetMenuEntries()
	local activeFrame = WardrobeCollectionFrame.activeFrame;
	if ( not activeFrame ) then
		return { };
	end
	if ( activeFrame.searchType == LE_TRANSMOG_SEARCH_TYPE_ITEMS ) then
		return WardrobeFilterDropDown_GetItemEntries();
	elseif ( activeFrame.searchType == LE_TRANSMOG_SEARCH_TYPE_BASE_SETS ) then
		return WardrobeFilterDropDown_GetBaseSetEntries();
	end
	return { };
end

-- The era handed a row's func the value the click had just flipped to; RebuffedMenu hands it the
-- value as drawn, so each row states its own negation. Every `checked` is a function, which is what
-- lets Refresh redraw the ticks in place after keepShownOnClick.
local function SourceEntries()
	local entries = {
		{
			text = CHECK_ALL,
			notCheckable = true,
			keepShownOnClick = true,
			func = function() C_TransmogCollection.SetAllSourceTypeFilters(true); end,
		},
		{
			text = UNCHECK_ALL,
			notCheckable = true,
			keepShownOnClick = true,
			func = function() C_TransmogCollection.SetAllSourceTypeFilters(false); end,
		},
	};
	for i = 1, C_TransmogCollection.GetNumTransmogSources() do
		entries[#entries + 1] = {
			text = _G["TRANSMOG_SOURCE_"..i],
			keepShownOnClick = true,
			checked = function() return not C_TransmogCollection.IsSourceTypeFilterChecked(i); end,
			func = function()
				C_TransmogCollection.SetSourceTypeFilter(i, C_TransmogCollection.IsSourceTypeFilterChecked(i));
			end,
		};
	end
	return entries;
end

function WardrobeFilterDropDown_GetItemEntries()
	local sources = SourceEntries();
	-- At the transmogrifier the collected/uncollected pair is not offered, so the sources are the
	-- whole menu rather than a branch of it.
	if ( WardrobeFrame_IsAtTransmogrifier() ) then
		return sources;
	end
	local entries = {
		{
			text = COLLECTIONS_FILTER_COLLECTED,
			keepShownOnClick = true,
			checked = function() return C_TransmogCollection.GetCollectedShown(); end,
			func = function() C_TransmogCollection.SetCollectedShown(not C_TransmogCollection.GetCollectedShown()); end,
		},
		{
			text = COLLECTIONS_FILTER_NOT_COLLECTED,
			keepShownOnClick = true,
			checked = function() return C_TransmogCollection.GetUncollectedShown(); end,
			func = function() C_TransmogCollection.SetUncollectedShown(not C_TransmogCollection.GetUncollectedShown()); end,
		},
		{
			text = SOURCES,
			notCheckable = true,
			menuList = "sources",
		},
	};
	return entries, { sources = sources };
end

function WardrobeFilterDropDown_GetBaseSetEntries()
	local function SetFilterEntry(text, filter)
		return {
			text = text,
			keepShownOnClick = true,
			checked = function() return C_TransmogSets.GetBaseSetsFilter(filter); end,
			func = function() C_TransmogSets.SetBaseSetsFilter(filter, not C_TransmogSets.GetBaseSetsFilter(filter)); end,
		};
	end
	return {
		SetFilterEntry(COLLECTIONS_FILTER_COLLECTED, LE_TRANSMOG_SET_FILTER_COLLECTED),
		SetFilterEntry(COLLECTIONS_FILTER_NOT_COLLECTED, LE_TRANSMOG_SET_FILTER_UNCOLLECTED),
		{ text = " ", isTitle = true, notCheckable = true },
		SetFilterEntry(TRANSMOG_SET_PVE, LE_TRANSMOG_SET_FILTER_PVE),
		SetFilterEntry(TRANSMOG_SET_PVP, LE_TRANSMOG_SET_FILTER_PVP),
	};
end

-- ************************************************************************************************************************************************************
-- **** SETS LIST *********************************************************************************************************************************************
-- ************************************************************************************************************************************************************

local BASE_SET_BUTTON_HEIGHT = 46;
local SET_PROGRESS_BAR_MAX_WIDTH = 204;
local QUESTION_MARK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark";
local IN_PROGRESS_FONT_COLOR = CreateColor(0.251, 0.753, 0.251);
local IN_PROGRESS_FONT_COLOR_CODE = "|cff40c040";
-- The paperdoll's order for a set's pieces, by inventory type (7.3.5 asked the encounter journal).
local INV_TYPE_SORT_ORDER = { [1] = 1, [3] = 2, [16] = 3, [5] = 4, [20] = 4, [4] = 5, [19] = 6, [9] = 7, [10] = 8, [6] = 9, [7] = 10, [8] = 11, [13] = 12, [21] = 12, [17] = 12, [14] = 13, [22] = 13, [23] = 13, [15] = 14, [25] = 14, [26] = 14 };

WardrobeSetsDataProviderMixin = {};

function WardrobeSetsDataProviderMixin:SortSets(sets, reverseUIOrder)
	local comparison = function(set1, set2)
		local groupFavorite1 = set1.favoriteSetID and true;
		local groupFavorite2 = set2.favoriteSetID and true;
		if ( groupFavorite1 ~= groupFavorite2 ) then
			return groupFavorite1;
		end
		if ( set1.favorite ~= set2.favorite ) then
			return set1.favorite;
		end
		if ( set1.uiOrder ~= set2.uiOrder ) then
			if ( reverseUIOrder ) then
				return set1.uiOrder < set2.uiOrder;
			else
				return set1.uiOrder > set2.uiOrder;
			end
		end
		return set1.setID > set2.setID;
	end

	table.sort(sets, comparison);
end

function WardrobeSetsDataProviderMixin:GetBaseSets()
	if ( not self.baseSets ) then
		self.baseSets = C_TransmogSets.GetBaseSets();
		self:DetermineFavorites();
		self:SortSets(self.baseSets);
	end
	return self.baseSets;
end

function WardrobeSetsDataProviderMixin:GetBaseSetByID(baseSetID)
	local baseSets = self:GetBaseSets();
	for i = 1, #baseSets do
		if ( baseSets[i].setID == baseSetID ) then
			return baseSets[i], i;
		end
	end
	return nil, nil;
end

function WardrobeSetsDataProviderMixin:GetUsableSets()
	if ( not self.usableSets ) then
		self.usableSets = C_TransmogSets.GetUsableSets();
		self:SortSets(self.usableSets);
		-- group sets by baseSetID, except for favorited sets since those are to remain bucketed to the front
		for i, set in ipairs(self.usableSets) do
			if ( not set.favorite ) then
				local baseSetID = set.baseSetID or set.setID;
				local numRelatedSets = 0;
				for j = i + 1, #self.usableSets do
					if ( self.usableSets[j].baseSetID == baseSetID or self.usableSets[j].setID == baseSetID ) then
						numRelatedSets = numRelatedSets + 1;
						-- no need to do anything if already contiguous
						if ( j ~= i + numRelatedSets ) then
							local relatedSet = self.usableSets[j];
							tremove(self.usableSets, j);
							tinsert(self.usableSets, i + numRelatedSets, relatedSet);
						end
					end
				end
			end
		end
	end
	return self.usableSets;
end

function WardrobeSetsDataProviderMixin:GetVariantSets(baseSetID)
	if ( not self.variantSets ) then
		self.variantSets = { };
	end

	local variantSets = self.variantSets[baseSetID];
	if ( not variantSets ) then
		variantSets = C_TransmogSets.GetVariantSets(baseSetID);
		self.variantSets[baseSetID] = variantSets;
		if ( #variantSets > 0 ) then
			-- add base to variants and sort
			local baseSet = self:GetBaseSetByID(baseSetID);
			if ( baseSet ) then
				tinsert(variantSets, baseSet);
			end
			self:SortSets(variantSets, true);
		end
	end
	return variantSets;
end

function WardrobeSetsDataProviderMixin:GetSetSourceData(setID)
	if ( not self.sourceData ) then
		self.sourceData = { };
	end

	local sourceData = self.sourceData[setID];
	if ( not sourceData ) then
		-- TransmogSetItem names several sources for one slot (set 838: 29 sources over 8 slots), so a
		-- set is measured per slot: one primary source per slot -- its first collected source in the
		-- sorted order, or its first when none is collected -- and a slot counts as collected when
		-- any of its sources is.
		sourceData = { sources = C_TransmogSets.GetSetSources(setID) };
		-- GetSortedSetSources reads the sources back out of this entry, so it is stored first.
		self.sourceData[setID] = sourceData;
		local sortedSources = self:GetSortedSetSources(setID);
		local primarySources = { };
		local slotIndex = { };
		local slotCollected = { };
		local numCollected = 0;
		for i = 1, #sortedSources do
			local transmogSlot = C_Transmog.GetSlotForInventoryType(sortedSources[i].invType);
			local index = slotIndex[transmogSlot];
			if ( not index ) then
				index = #primarySources + 1;
				slotIndex[transmogSlot] = index;
				primarySources[index] = sortedSources[i];
			end
			if ( sortedSources[i].collected and not slotCollected[transmogSlot] ) then
				slotCollected[transmogSlot] = true;
				numCollected = numCollected + 1;
				primarySources[index] = sortedSources[i];
			end
		end
		sourceData.primarySources = primarySources;
		sourceData.numCollected = numCollected;
		sourceData.numTotal = #primarySources;
	end
	return sourceData;
end

function WardrobeSetsDataProviderMixin:GetSetSources(setID)
	return self:GetSetSourceData(setID).sources;
end

function WardrobeSetsDataProviderMixin:GetSetSourceCounts(setID)
	local sourceData = self:GetSetSourceData(setID);
	return sourceData.numCollected, sourceData.numTotal;
end

function WardrobeSetsDataProviderMixin:GetBaseSetData(setID)
	if ( not self.baseSetsData ) then
		self.baseSetsData = { };
	end
	if ( not self.baseSetsData[setID] ) then
		local baseSetID = C_TransmogSets.GetBaseSetID(setID);
		if ( baseSetID ~= setID ) then
			return;
		end
		local topCollected, topTotal = self:GetSetSourceCounts(setID);
		local variantSets = self:GetVariantSets(setID);
		for i = 1, #variantSets do
			local numCollected, numTotal = self:GetSetSourceCounts(variantSets[i].setID);
			-- A completed variant outranks an incomplete top: a bought 7-slot variant of an 8-slot
			-- base ties it at 7 and must still show the set complete.
			local complete, topComplete = (numTotal > 0 and numCollected == numTotal), (topTotal > 0 and topCollected == topTotal);
			if ( (complete and not topComplete) or (complete == topComplete and numCollected > topCollected) ) then
				topCollected = numCollected;
				topTotal = numTotal;
			end
		end
		local setInfo = { topCollected = topCollected, topTotal = topTotal, completed = (topCollected == topTotal) };
		self.baseSetsData[setID] = setInfo;
	end
	return self.baseSetsData[setID];
end

function WardrobeSetsDataProviderMixin:GetSetSourceTopCounts(setID)
	local baseSetData = self:GetBaseSetData(setID);
	if ( baseSetData ) then
		return baseSetData.topCollected, baseSetData.topTotal;
	else
		return self:GetSetSourceCounts(setID);
	end
end

function WardrobeSetsDataProviderMixin:IsBaseSetNew(baseSetID)
	local baseSetData = self:GetBaseSetData(baseSetID)
	if ( not baseSetData.newStatus ) then
		local newStatus = C_TransmogSets.SetHasNewSources(baseSetID);
		if ( not newStatus ) then
			-- check variants
			local variantSets = self:GetVariantSets(baseSetID);
			for i, variantSet in ipairs(variantSets) do
				if ( C_TransmogSets.SetHasNewSources(variantSet.setID) ) then
					newStatus = true;
					break;
				end
			end
		end
		baseSetData.newStatus = newStatus;
	end
	return baseSetData.newStatus;
end

function WardrobeSetsDataProviderMixin:ResetBaseSetNewStatus(baseSetID)
	local baseSetData = self:GetBaseSetData(baseSetID)
	if ( baseSetData ) then
		baseSetData.newStatus = nil;
	end
end

function WardrobeSetsDataProviderMixin:GetSortedSetSources(setID)
	local returnTable = { };
	local sourceData = self:GetSetSourceData(setID);
	for sourceID, collected in pairs(sourceData.sources) do
		local sourceInfo = C_TransmogCollection.GetSourceInfo(sourceID);
		if ( sourceInfo ) then
			local sortOrder = INV_TYPE_SORT_ORDER[sourceInfo.invType] or 15;
			tinsert(returnTable, { sourceID = sourceID, collected = collected, sortOrder = sortOrder, itemID = sourceInfo.itemID, invType = sourceInfo.invType });
		end
	end

	local comparison = function(entry1, entry2)
		if ( entry1.sortOrder == entry2.sortOrder ) then
			return entry1.itemID < entry2.itemID;
		else
			return entry1.sortOrder < entry2.sortOrder;
		end
	end
	table.sort(returnTable, comparison);
	return returnTable;
end

function WardrobeSetsDataProviderMixin:ClearSets()
	self.baseSets = nil;
	self.baseSetsData = nil;
	self.variantSets = nil;
	self.usableSets = nil;
	self.sourceData = nil;
end

function WardrobeSetsDataProviderMixin:ClearBaseSets()
	self.baseSets = nil;
end

function WardrobeSetsDataProviderMixin:ClearVariantSets()
	self.variantSets = nil;
end

function WardrobeSetsDataProviderMixin:ClearUsableSets()
	self.usableSets = nil;
end

function WardrobeSetsDataProviderMixin:GetIconForSet(setID)
	local sourceData = self:GetSetSourceData(setID);
	if ( not sourceData.icon ) then
		local sortedSources = self:GetSortedSetSources(setID);
		if ( sortedSources[1] ) then
			sourceData.icon = C_TransmogCollection.GetSourceIcon(sortedSources[1].sourceID) or QUESTION_MARK_ICON;
		else
			sourceData.icon = QUESTION_MARK_ICON;
		end
	end
	return sourceData.icon;
end

function WardrobeSetsDataProviderMixin:DetermineFavorites()
	-- if a variant is favorited, so is the base set
	-- keep track of which set is favorited
	local baseSets = self:GetBaseSets();
	for i = 1, #baseSets do
		local baseSet = baseSets[i];
		baseSet.favoriteSetID = nil;
		if ( baseSet.favorite ) then
			baseSet.favoriteSetID = baseSet.setID;
		else
			local variantSets = self:GetVariantSets(baseSet.setID);
			for j = 1, #variantSets do
				if ( variantSets[j].favorite ) then
					baseSet.favoriteSetID = variantSets[j].setID;
					break;
				end
			end
		end
	end
end

function WardrobeSetsDataProviderMixin:RefreshFavorites()
	self.baseSets = nil;
	self.variantSets = nil;
	self:DetermineFavorites();
end

local SetsDataProvider = CreateFromMixins(WardrobeSetsDataProviderMixin);

WardrobeSetsCollectionMixin = {};

function WardrobeSetsCollectionMixin:OnLoad()
	self.RightInset.BGCornerTopLeft:Hide();
	self.RightInset.BGCornerTopRight:Hide();

	self.DetailsFrame.itemFramesPool = CreateFramePool("FRAME", self.DetailsFrame, "WardrobeSetsDetailsItemFrameTemplate");

	self.selectedVariantSets = { };
end

function WardrobeSetsCollection_OnLoad(self)
	SetParentArray(self, "ContentFrames");
	self.searchType = LE_TRANSMOG_SEARCH_TYPE_BASE_SETS;
	self.DetailsFrame.ModelFadeTexture:SetAtlas("transmog-set-model-cutoff-fade");
	self.DetailsFrame.IconRowBackground:SetAtlas("transmog-set-iconrow-background", true);
	MixinAndLoadScripts(self, "WardrobeSetsCollectionMixin");
end

function WardrobeSetsCollectionMixin:OnShow()
	self:RegisterEvent("TRANSMOG_COLLECTION_UPDATED");
	-- select the first set if not init
	local baseSets = SetsDataProvider:GetBaseSets();
	if ( not self.init ) then
		self.init = true;
		if ( baseSets and baseSets[1] ) then
			self:SelectSet(self:GetDefaultSetIDForBaseSet(baseSets[1].setID));
		end
	else
		self:Refresh();
	end

	local latestSource = C_TransmogSets.GetLatestSource();
	if ( latestSource ~= NO_TRANSMOG_SOURCE_ID ) then
		local sets = C_TransmogSets.GetSetsContainingSourceID(latestSource);
		local setID = sets and sets[1];
		if ( setID ) then
			self:SelectSet(setID);
			local baseSetID = C_TransmogSets.GetBaseSetID(setID);
			self:ScrollToSet(baseSetID);
		end
		self:ClearLatestSource();
	end

	WardrobeCollectionFrame.progressBar:SetProgress(C_TransmogSets.GetBaseSetsCounts());
	self:RefreshCameras();
end

function WardrobeSetsCollectionMixin:OnHide()
	self:UnregisterEvent("TRANSMOG_COLLECTION_UPDATED");
	SetsDataProvider:ClearSets();
	WardrobeCollectionFrame_ClearSearch(LE_TRANSMOG_SEARCH_TYPE_BASE_SETS);
end

function WardrobeSetsCollectionMixin:OnEvent(event, ...)
	if ( event == "TRANSMOG_COLLECTION_UPDATED" ) then
		SetsDataProvider:ClearSets();
		self:Refresh();
		WardrobeCollectionFrame.progressBar:SetProgress(C_TransmogSets.GetBaseSetsCounts());
		self:ClearLatestSource();
	end
end

function WardrobeSetsCollectionMixin:ClearLatestSource()
	C_TransmogSets.ClearLatestSource();
	WardrobeCollectionFrame_UpdateTabButtons();
end

function WardrobeSetsCollectionMixin:Refresh()
	self.ScrollFrame:Update();
	self:DisplaySet(self:GetSelectedSetID());
end

function WardrobeSetsCollectionMixin:DisplaySet(setID)
	local setInfo = (setID and C_TransmogSets.GetSetInfo(setID)) or nil;
	if ( not setInfo ) then
		self.DetailsFrame:Hide();
		self.Model:Hide();
		return;
	else
		self.DetailsFrame:Show();
		self.Model:Show();
	end

	self.DetailsFrame.Name:SetText(setInfo.name);
	if ( self.DetailsFrame.Name:GetStringWidth() > self.DetailsFrame.Name:GetWidth() ) then
		self.DetailsFrame.Name:Hide();
		self.DetailsFrame.LongName:SetText(setInfo.name);
		self.DetailsFrame.LongName:Show();
	else
		self.DetailsFrame.Name:Show();
		self.DetailsFrame.LongName:Hide();
	end
	self.DetailsFrame.Label:SetText(setInfo.label);

	self.DetailsFrame.itemFramesPool:ReleaseAll();
	-- OnLoad can run before the player unit exists. Rebind after showing the model.
	self.Model:SetUnit("player");
	self.Model:RefreshCamera();
	self.Model:Undress();
	local BUTTON_SPACE = 37;	-- button width + spacing between 2 buttons
	-- One frame per slot: the set lists several sources for the same slot, and the tooltip cycles
	-- the rest of them through C_TransmogSets.GetSourcesForSlot.
	local primarySources = SetsDataProvider:GetSetSourceData(setID).primarySources;
	local xOffset = -floor((#primarySources - 1) * BUTTON_SPACE / 2);
	for i = 1, #primarySources do
		local itemFrame = self.DetailsFrame.itemFramesPool:Acquire();
		itemFrame.sourceID = primarySources[i].sourceID;
		itemFrame.itemID = primarySources[i].itemID;
		itemFrame.collected = primarySources[i].collected;
		itemFrame.invType = primarySources[i].invType;
		local texture = C_TransmogCollection.GetSourceIcon(primarySources[i].sourceID);
		itemFrame.Icon:SetTexture(texture);
		if ( primarySources[i].collected ) then
			itemFrame.Icon:SetDesaturated(false);
			itemFrame.Icon:SetAlpha(1);
			itemFrame.IconBorder:SetDesaturated(false);
			itemFrame.IconBorder:SetAlpha(1);

			local transmogSlot = C_Transmog.GetSlotForInventoryType(itemFrame.invType);
			if ( C_TransmogSets.SetHasNewSourcesForSlot(setID, transmogSlot) ) then
				itemFrame.New:Show();
				itemFrame.New.Anim:Play();
			else
				itemFrame.New:Hide();
				itemFrame.New.Anim:Stop();
			end
		else
			itemFrame.Icon:SetDesaturated(true);
			itemFrame.Icon:SetAlpha(0.3);
			itemFrame.IconBorder:SetDesaturated(true);
			itemFrame.IconBorder:SetAlpha(0.3);
			itemFrame.New:Hide();
		end
		self:SetItemFrameQuality(itemFrame);
		itemFrame:SetPoint("TOP", self.DetailsFrame, "TOP", xOffset + (i - 1) * BUTTON_SPACE, -94);
		itemFrame:Show();
		self.Model:TryOn(primarySources[i].sourceID);
	end

	-- variant sets
	local baseSetID = C_TransmogSets.GetBaseSetID(setID);
	local variantSets = SetsDataProvider:GetVariantSets(baseSetID);
	if ( #variantSets == 0 )  then
		self.DetailsFrame.VariantSetsButton:Hide();
	else
		self.DetailsFrame.VariantSetsButton:Show();
		self.DetailsFrame.VariantSetsButton:SetText(setInfo.description);
	end
end

function WardrobeSetsCollectionMixin:SetItemFrameQuality(itemFrame)
	if ( itemFrame.collected ) then
		local quality = C_TransmogCollection.GetSourceInfo(itemFrame.sourceID).quality;
		if ( quality == Enum.ItemQuality.Uncommon ) then
			itemFrame.IconBorder:SetAtlas("loottab-set-itemborder-green", true);
		elseif ( quality == Enum.ItemQuality.Rare ) then
			itemFrame.IconBorder:SetAtlas("loottab-set-itemborder-blue", true);
		elseif ( quality == Enum.ItemQuality.Epic ) then
			itemFrame.IconBorder:SetAtlas("loottab-set-itemborder-purple", true);
		end
	end
	
end

function WardrobeSetsCollectionMixin:OnSearchUpdate()
	if ( self.init ) then
		SetsDataProvider:ClearBaseSets();
		SetsDataProvider:ClearVariantSets();
		SetsDataProvider:ClearUsableSets();
		self:Refresh();
	end
end

function WardrobeSetsCollectionMixin:RefreshCameras()
	if ( self:IsShown() ) then
		local detailsCameraID = C_TransmogSets.GetCameraIDs();
		local model = self.Model;
		if ( model.cameraID ~= detailsCameraID ) then
			model.defaultPosX, model.defaultPosY, model.defaultPosZ, model.yaw = UICamera:GetCameraInfo(detailsCameraID);
		end
		model:ApplyUICamera(detailsCameraID, true);
	end
end

function WardrobeSetsCollectionMixin:GetVariantSetEntries()
	local selectedSetID = self:GetSelectedSetID();
	if ( not selectedSetID ) then
		return {};
	end
	local entries = {};
	local baseSetID = C_TransmogSets.GetBaseSetID(selectedSetID);
	local variantSets = SetsDataProvider:GetVariantSets(baseSetID);
	for i = 1, #variantSets do
		local variantSet = variantSets[i];
		local numSourcesCollected, numSourcesTotal = SetsDataProvider:GetSetSourceCounts(variantSet.setID);
		local colorCode = IN_PROGRESS_FONT_COLOR_CODE;
		if ( numSourcesCollected == numSourcesTotal ) then
			colorCode = NORMAL_FONT_COLOR_CODE;
		elseif ( numSourcesCollected == 0 ) then
			colorCode = GRAY_FONT_COLOR_CODE;
		end
		entries[i] = {
			text = format(ITEM_SET_NAME, variantSet.description..colorCode, numSourcesCollected, numSourcesTotal),
			checked = variantSet.setID == selectedSetID,
			func = function() self:SelectSet(variantSet.setID); end,
		};
	end
	return entries;
end

function WardrobeSetsCollectionMixin:ToggleVariantSetsMenu(owner)
	if ( RebuffedMenu:IsOpen(owner) ) then
		RebuffedMenu:Close(owner);
		return;
	end
	RebuffedMenu:Open(owner, self:GetVariantSetEntries());
end

function WardrobeSetsCollectionMixin:GetDefaultSetIDForBaseSet(baseSetID)
	if ( SetsDataProvider:IsBaseSetNew(baseSetID) ) then
		if ( C_TransmogSets.SetHasNewSources(baseSetID) ) then
			return baseSetID;
		else
			local variantSets = SetsDataProvider:GetVariantSets(baseSetID);
			for i, variantSet in ipairs(variantSets) do
				if ( C_TransmogSets.SetHasNewSources(variantSet.setID) ) then
					return variantSet.setID;
				end
			end
		end
	end

	if ( self.selectedVariantSets[baseSetID] ) then
		return self.selectedVariantSets[baseSetID];
	end

	local baseSet = SetsDataProvider:GetBaseSetByID(baseSetID);
	if ( baseSet.favoriteSetID ) then
		return baseSet.favoriteSetID;
	end
	-- pick the one with most collected, higher difficulty wins ties
	local highestCount = 0;
	local highestCountSetID;
	local variantSets = SetsDataProvider:GetVariantSets(baseSetID);	
	for i = 1, #variantSets do
		local variantSetID = variantSets[i].setID;
		local numCollected = SetsDataProvider:GetSetSourceCounts(variantSetID);
		if ( numCollected > 0 and numCollected >= highestCount ) then
			highestCount = numCollected;
			highestCountSetID = variantSetID;
		end
	end
	return highestCountSetID or baseSetID;
end

-- The set list is a list, not a grid, so only up and down mean anything here.
function WardrobeSetsCollectionMixin:OnUnitModelChangedEvent()
	if ( not self.Model:CanSetUnit("player") ) then
		return false;
	end
	self.Model:RefreshUnit();
	-- cleared so the camera is worked out again rather than kept from the old model
	self.Model.cameraID = nil;
	self:RefreshCameras();
	self:Refresh();
	return true;
end

function WardrobeSetsCollectionMixin:CanHandleKey(key)
	return key == WARDROBE_UP_VISUAL_KEY or key == WARDROBE_DOWN_VISUAL_KEY;
end

function WardrobeSetsCollectionMixin:HandleKey(key)
	if ( not self:GetSelectedSetID() ) then
		return;
	end
	local baseSetID = C_TransmogSets.GetBaseSetID(self:GetSelectedSetID());
	local _, index = SetsDataProvider:GetBaseSetByID(baseSetID);
	if ( not index ) then
		return;
	end
	if ( key == WARDROBE_DOWN_VISUAL_KEY ) then
		index = index + 1;
	else
		index = index - 1;
	end
	local sets = SetsDataProvider:GetBaseSets();
	index = Clamp(index, 1, #sets);
	self:SelectSet(self:GetDefaultSetIDForBaseSet(sets[index].setID));
end
function WardrobeSetsCollectionMixin:SelectSetFromButton(setID)
	RebuffedMenu:Close();
	self:SelectSet(self:GetDefaultSetIDForBaseSet(setID));
end

function WardrobeSetsCollectionMixin:SelectSet(setID)
	self.selectedSetID = setID;

	local baseSetID = C_TransmogSets.GetBaseSetID(setID);
	local variantSets = SetsDataProvider:GetVariantSets(baseSetID);
	if ( #variantSets > 0 ) then
		self.selectedVariantSets[baseSetID] = setID;
	end

	self:Refresh();
end

function WardrobeSetsCollectionMixin:GetSelectedSetID()
	return self.selectedSetID;
end

function WardrobeSetsCollectionMixin:SetAppearanceTooltip(frame)
	GameTooltip:SetOwner(frame, "ANCHOR_RIGHT");
	self.tooltipTransmogSlot = C_Transmog.GetSlotForInventoryType(frame.invType);
	self.tooltipPrimarySourceID = frame.sourceID;
	self:RefreshAppearanceTooltip();
end

function WardrobeSetsCollectionMixin:RefreshAppearanceTooltip()
	if ( not self.tooltipTransmogSlot ) then
		return;
	end

	local sources = C_TransmogSets.GetSourcesForSlot(self:GetSelectedSetID(), self.tooltipTransmogSlot);
	if ( #sources == 0 ) then
		-- can happen if a slot only has HiddenUntilCollected sources
		local sourceInfo = C_TransmogCollection.GetSourceInfo(self.tooltipPrimarySourceID);
		tinsert(sources, sourceInfo);
	end
	WardrobeCollectionFrame_SortSources(sources, sources[1].visualID, self.tooltipPrimarySourceID);
	WardrobeCollectionFrame_SetAppearanceTooltip(self, sources, self.tooltipPrimarySourceID);
end

function WardrobeSetsCollectionMixin:ClearAppearanceTooltip()
	self.tooltipTransmogSlot = nil;
	self.tooltipPrimarySourceID = nil;
	WardrobeCollectionFrame_HideAppearanceTooltip();
end

function WardrobeSetsCollectionMixin:ScrollToSet(setID)
	local totalHeight = 0;
	local scrollFrameHeight = self.ScrollFrame:GetHeight();
	local buttonHeight = self.ScrollFrame.buttonHeight;
	for i, set in ipairs(SetsDataProvider:GetBaseSets()) do
		if ( set.setID == setID ) then
			local offset = self.ScrollFrame.scrollBar:GetValue();
			if ( totalHeight + buttonHeight > offset + scrollFrameHeight ) then
				offset = totalHeight + buttonHeight - scrollFrameHeight;
			elseif ( totalHeight < offset ) then
				offset = totalHeight;
			end
			self.ScrollFrame.scrollBar:SetValue(offset, true);
			break;
		end
		totalHeight = totalHeight + buttonHeight;
	end
end


WardrobeSetsCollectionScrollFrameMixin = { };

-- The base set's favourite menu as entries for RebuffedMenu. A base set with variants names the
-- variant that carries the favourite, which is why the description is read for those.
function WardrobeSetsCollectionScrollFrameMixin:GetFavoriteMenuEntries(baseSetID)
	local baseSet = baseSetID and SetsDataProvider:GetBaseSetByID(baseSetID);
	if ( not baseSet ) then
		return { { text = CANCEL, notCheckable = true, func = function() end } };
	end

	local useDescription = (#SetsDataProvider:GetVariantSets(baseSetID) > 0);
	local text, func;
	if ( baseSet.favoriteSetID ) then
		local favoriteSetID = baseSet.favoriteSetID;
		if ( useDescription ) then
			text = format(TRANSMOG_SETS_UNFAVORITE_WITH_DESCRIPTION, C_TransmogSets.GetSetInfo(favoriteSetID).description);
		else
			text = BATTLE_PET_UNFAVORITE;
		end
		func = function() C_TransmogSets.SetIsFavorite(favoriteSetID, false); end
	else
		local targetSetID = WardrobeCollectionFrame.SetsCollectionFrame:GetDefaultSetIDForBaseSet(baseSetID);
		if ( useDescription ) then
			text = format(TRANSMOG_SETS_FAVORITE_WITH_DESCRIPTION, C_TransmogSets.GetSetInfo(targetSetID).description);
		else
			text = BATTLE_PET_FAVORITE;
		end
		func = function() C_TransmogSets.SetIsFavorite(targetSetID, true); end
	end

	return {
		{ text = text, notCheckable = true, func = func },
		{ text = CANCEL, notCheckable = true, func = function() end },
	};
end

function WardrobeSetsCollectionScrollFrameMixin:OnLoad()
	RebuffedHybridScrollFrame_OnLoad(self);
	self.scrollBar.doNotHide = true;
	-- The era's RebuffedHybridScrollFrame_SetOffset calls self.update() with no argument, not self:update().
	self.update = function() self:Update(); end
	RebuffedHybridScrollFrame_CreateButtons(self, "WardrobeSetsScrollFrameButtonTemplate", 44, 0);
end

function WardrobeSetsCollectionScrollFrame_OnLoad(self)
	MixinAndLoadScripts(self, "WardrobeSetsCollectionScrollFrameMixin");
end

function WardrobeSetsCollectionScrollFrameMixin:OnShow()
	self:RegisterEvent("TRANSMOG_SETS_UPDATE_FAVORITE");
end

function WardrobeSetsCollectionScrollFrameMixin:OnHide()
	self:UnregisterEvent("TRANSMOG_SETS_UPDATE_FAVORITE");
end

function WardrobeSetsCollectionScrollFrameMixin:OnEvent(event, ...)
	if ( event == "TRANSMOG_SETS_UPDATE_FAVORITE" ) then
		SetsDataProvider:RefreshFavorites();
		self:Update();
	end
end

function WardrobeSetsCollectionScrollFrameMixin:Update()
	local offset = RebuffedHybridScrollFrame_GetOffset(self);
	local buttons = self.buttons;
	local baseSets = SetsDataProvider:GetBaseSets();

	-- show the base set as selected
	local selectedSetID = self:GetParent():GetSelectedSetID();
	local selectedBaseSetID = selectedSetID and C_TransmogSets.GetBaseSetID(selectedSetID);

	for i = 1, #buttons do
		local button = buttons[i];
		local setIndex = i + offset;
		if ( setIndex <= #baseSets ) then
			local baseSet = baseSets[setIndex];
			button:Show();
			button.Name:SetText(baseSet.name);
			local topSourcesCollected, topSourcesTotal = SetsDataProvider:GetSetSourceTopCounts(baseSet.setID);
			local setCollected = C_TransmogSets.IsBaseSetCollected(baseSet.setID);
			local color = IN_PROGRESS_FONT_COLOR;
			if ( setCollected ) then
				color = NORMAL_FONT_COLOR;
			elseif ( topSourcesCollected == 0 ) then
				color = GRAY_FONT_COLOR;
			end
			button.Name:SetTextColor(color.r, color.g, color.b);
			button.Label:SetText(baseSet.label);
			button.Icon:SetTexture(SetsDataProvider:GetIconForSet(baseSet.setID));
			button.Icon:SetDesaturated(topSourcesCollected == 0);
			button.SelectedTexture:SetShown(baseSet.setID == selectedBaseSetID);
			button.Favorite:SetShown(baseSet.favoriteSetID);
			button.New:SetShown(SetsDataProvider:IsBaseSetNew(baseSet.setID));
			button.setID = baseSet.setID;

			if ( topSourcesCollected == 0 or setCollected ) then
				button.ProgressBar:Hide();
			else
				button.ProgressBar:Show();
				button.ProgressBar:SetWidth(SET_PROGRESS_BAR_MAX_WIDTH * topSourcesCollected / topSourcesTotal);
			end
			button.IconCover:SetShown(not setCollected);
		else
			button:Hide();
		end
	end
	
	local extraHeight = (self.largeButtonHeight and self.largeButtonHeight - BASE_SET_BUTTON_HEIGHT) or 0;
	local totalHeight = #baseSets * BASE_SET_BUTTON_HEIGHT + extraHeight;
	RebuffedHybridScrollFrame_Update(self, totalHeight, self:GetHeight());
end

WardrobeSetsDetailsModelMixin = { };

function WardrobeSetsDetailsModelMixin:OnLoad()
	self:SetAutoDress(false);
	self:SetUnit("player");
	-- The era does not deliver OnMouseWheel until the frame asks for it, as the two grids do.
	self:EnableMouseWheel(true);
	self:UpdatePanAndZoomModelType();
	self:SetLight(1, 0, -1, 0, 0, .7, .7, .7, .7, .6, 1, 1, 1);
end

function WardrobeSetsDetailsModel_OnLoad(self)
	MixinAndLoadScripts(self, "WardrobeSetsDetailsModelMixin");
end

function WardrobeSetsDetailsModelMixin:UpdatePanAndZoomModelType()
	local _, race = UnitRace("player");
	local sex = UnitSex("player");
	self.panAndZoomModelType = race..sex;
end

function WardrobeSetsDetailsModelMixin:GetPanAndZoomLimits()
	return SET_MODEL_PAN_AND_ZOOM_LIMITS[self.panAndZoomModelType];
end

function WardrobeSetsDetailsModelMixin:OnUpdate(elapsed)
	if ( self.rotating ) then
		local x = GetCursorPosition();
		local diff = (x - self.rotateStartCursorX) * MODELFRAME_DRAG_ROTATION_CONSTANT;
		self.rotateStartCursorX = GetCursorPosition();
		self.yaw = self.yaw + diff;
		if ( self.yaw < 0 ) then
			self.yaw = self.yaw + (2 * PI);
		end
		if ( self.yaw > (2 * PI) ) then
			self.yaw = self.yaw - (2 * PI);
		end
		self:SetRotation(self.yaw, false);
	elseif ( self.panning ) then
		local cursorX, cursorY = GetCursorPosition();
		local modelX = self:GetPosition();
		local panSpeedModifier = 100 * sqrt(1 + modelX - self.defaultPosX);
		local modelY = self.panStartModelY + (cursorX - self.panStartCursorX) / panSpeedModifier;
		local modelZ = self.panStartModelZ + (cursorY - self.panStartCursorY) / panSpeedModifier;
		local limits = self:GetPanAndZoomLimits();
		modelY = Clamp(modelY, limits.panMaxLeft, limits.panMaxRight);
		modelZ = Clamp(modelZ, limits.panMaxBottom, limits.panMaxTop);
		self:SetPosition(modelX, modelY, modelZ);
	end
end

function WardrobeSetsDetailsModelMixin:OnMouseDown(button)
	if ( button == "LeftButton" ) then
		self.rotating = true;
		self.rotateStartCursorX = GetCursorPosition();
	elseif ( button == "RightButton" ) then
		self.panning = true;
		self.panStartCursorX, self.panStartCursorY = GetCursorPosition();
		local modelX, modelY, modelZ = self:GetPosition();
		self.panStartModelY = modelY;
		self.panStartModelZ = modelZ;
	end
end

function WardrobeSetsDetailsModelMixin:OnMouseUp(button)
	if ( button == "LeftButton" ) then
		self.rotating = false;
	elseif ( button == "RightButton" ) then
		self.panning = false;
	end
end

function WardrobeSetsDetailsModelMixin:OnMouseWheel(delta)
	local posX, posY, posZ = self:GetPosition();
	posX = posX + delta * 0.5;
	local limits = self:GetPanAndZoomLimits();
	posX = Clamp(posX, self.defaultPosX, limits.maxZoom);
	self:SetPosition(posX, posY, posZ);
end

WardrobeSetsDetailsItemMixin = { };

function WardrobeSetsDetailsItemFrame_OnLoad(self)
	self.IconBorder:SetAtlas("loottab-set-itemborder-green", true);
	self.New:SetAtlas("GarrMission-AbilityHighlight");
	MixinAndLoadScripts(self, "WardrobeSetsDetailsItemMixin");
end

function WardrobeSetsDetailsItemMixin:OnEnter()
	self:GetParent():GetParent():SetAppearanceTooltip(self)

	self:SetScript("OnUpdate", 
		function()
			if IsModifiedClick("DRESSUP") then
				ShowInspectCursor();
			else
				ResetCursor();
			end
		end
	);

	if ( self.New:IsShown() ) then
		local transmogSlot = C_Transmog.GetSlotForInventoryType(self.invType);
		local setID = WardrobeCollectionFrame.SetsCollectionFrame:GetSelectedSetID();
		C_TransmogSets.ClearSetNewSourcesForSlot(setID, transmogSlot);
		local baseSetID = C_TransmogSets.GetBaseSetID(setID);
		SetsDataProvider:ResetBaseSetNewStatus(baseSetID);
		WardrobeCollectionFrame.SetsCollectionFrame:Refresh();
	end
end

function WardrobeSetsDetailsItemMixin:OnLeave()
	self:SetScript("OnUpdate", nil);
	ResetCursor();
	WardrobeCollectionFrame_HideAppearanceTooltip();
end

function WardrobeSetsDetailsItemMixin:OnMouseDown()
	if ( IsModifiedClick("CHATLINK") ) then
		local sourceInfo = C_TransmogCollection.GetSourceInfo(self.sourceID);
		local slot = C_Transmog.GetSlotForInventoryType(sourceInfo.invType);
		local sources = C_TransmogSets.GetSourcesForSlot(self:GetParent():GetParent():GetSelectedSetID(), slot);
		if ( #sources == 0 ) then
			-- can happen if a slot only has HiddenUntilCollected sources
			tinsert(sources, sourceInfo);
		end
		WardrobeCollectionFrame_SortSources(sources, sourceInfo.visualID, self.sourceID);
		if ( WardrobeCollectionFrame.tooltipSourceIndex ) then
			local index = WardrobeUtils_GetValidIndexForNumSources(WardrobeCollectionFrame.tooltipSourceIndex, #sources);
			local link = select(6, C_TransmogCollection.GetAppearanceSourceInfo(sources[index].sourceID));
			if ( link ) then
				HandleModifiedItemClick(link);
			end
		end
	elseif ( IsModifiedClick("DRESSUP") ) then
		WardrobeDressUp(self.sourceID);
	end
end

WardrobeSetsTransmogMixin = { };

function WardrobeSetsTransmogMixin:OnLoad()
	self.NUM_ROWS = 2;
	self.NUM_COLS = 4;
	self.PAGE_SIZE = self.NUM_ROWS * self.NUM_COLS;
	self.APPLIED_SOURCE_INDEX = 1;
	self.SELECTED_SOURCE_INDEX = 3;
end

function WardrobeSetsTransmog_OnLoad(self)
	SetParentArray(self, "ContentFrames");
	self.searchType = LE_TRANSMOG_SEARCH_TYPE_USABLE_SETS;
	self:EnableMouseWheel(true);
	MixinAndLoadScripts(self, "WardrobeSetsTransmogMixin");
end

function WardrobeSetsTransmogMixin:OnShow()
	self:RegisterEvent("TRANSMOGRIFY_UPDATE");
	self:RegisterEvent("TRANSMOGRIFY_SUCCESS");
	self:RegisterEvent("TRANSMOG_COLLECTION_UPDATED");
	self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED");
	self:RegisterEvent("TRANSMOG_SETS_UPDATE_FAVORITE");
	self:RefreshCameras();
	local RESET_SELECTION = true;
	self:Refresh(RESET_SELECTION);
	WardrobeCollectionFrame.progressBar:SetProgress(C_TransmogSets.GetBaseSetsCounts());
	self.sourceQualityTable = { };
end

function WardrobeSetsTransmogMixin:OnHide()
	self:UnregisterEvent("TRANSMOGRIFY_UPDATE");
	self:UnregisterEvent("TRANSMOGRIFY_SUCCESS");
	self:UnregisterEvent("TRANSMOG_COLLECTION_UPDATED");
	self:UnregisterEvent("PLAYER_EQUIPMENT_CHANGED");
	self:UnregisterEvent("TRANSMOG_SETS_UPDATE_FAVORITE");
	SetsDataProvider:ClearSets();
	WardrobeCollectionFrame_ClearSearch(LE_TRANSMOG_SEARCH_TYPE_USABLE_SETS);
	self.sourceQualityTable = nil;
end

function WardrobeSetsTransmogMixin:OnEvent(event, ...)
	if ( event == "TRANSMOGRIFY_UPDATE" and not self.ignoreTransmogrifyUpdateEvent ) then
		SetsDataProvider:ClearUsableSets();
		self:Refresh();
	elseif ( event == "TRANSMOGRIFY_SUCCESS" )  then
		-- this event fires once per slot so in the case of a set there would be up to 9 of them
		self.dirty = true;
	elseif ( event == "TRANSMOG_COLLECTION_UPDATED" or event == "TRANSMOG_SETS_UPDATE_FAVORITE" ) then
		SetsDataProvider:ClearSets();
		self:Refresh();
		WardrobeCollectionFrame.progressBar:SetProgress(C_TransmogSets.GetBaseSetsCounts());
	elseif ( event == "PLAYER_EQUIPMENT_CHANGED" ) then
		SetsDataProvider:ClearUsableSets();
		if ( self.selectedSetID ) then
			self:LoadSet(self.selectedSetID);
		end
		self:Refresh();
	end
end

function WardrobeSetsTransmogMixin:OnUpdate()
	if ( self.dirty ) then
		self.dirty = nil;
		self:Refresh();
	end
end

function WardrobeSetsTransmogMixin:OnMouseWheel(value)
	self.PagingFrame:OnMouseWheel(value);
end

function WardrobeSetsTransmogMixin:Refresh(resetSelection)
	self.appliedSetID = self:GetFirstMatchingSetID(self.APPLIED_SOURCE_INDEX);
	if ( resetSelection ) then
		self.selectedSetID = self:GetFirstMatchingSetID(self.SELECTED_SOURCE_INDEX);
		self:ResetPage();
	else
		self:UpdateSets();
	end
end

function WardrobeSetsTransmogMixin:UpdateSets()
	local usableSets = SetsDataProvider:GetUsableSets();
	self.PagingFrame:SetMaxPages(ceil(#usableSets / self.PAGE_SIZE));
	local pendingTransmogModelFrame = nil;
	local indexOffset = (self.PagingFrame:GetCurrentPage() - 1) * self.PAGE_SIZE;
	for i = 1, self.PAGE_SIZE do
		local model = self.Models[i];
		local index = i + indexOffset;
		local set = usableSets[index];
		if ( set ) then
			local wasShown = model:IsShown();
			model:Show();
			if ( not wasShown or model.setID ~= set.setID ) then
				model:SetUnit("player");
				model:RefreshCamera();
				model:Undress();
				-- One source per slot: the set names several for the same slot, and dressing them
				-- all left whichever came last in hash order on the model -- not the one LoadSet
				-- would apply. Set 838 is 29 sources over 8 slots.
				local primarySources = SetsDataProvider:GetSetSourceData(set.setID).primarySources;
				for j = 1, #primarySources do
					model:TryOn(primarySources[j].sourceID);
				end
			end
			local transmogStateAtlas;
			if ( set.setID == self.appliedSetID and set.setID == self.selectedSetID ) then
				transmogStateAtlas = "transmog-set-border-current-transmogged";
			elseif ( set.setID == self.selectedSetID ) then
				transmogStateAtlas = "transmog-set-border-selected";
				pendingTransmogModelFrame = model;
			end
			if ( transmogStateAtlas ) then
				model.TransmogStateTexture:SetAtlas(transmogStateAtlas, true);
				model.TransmogStateTexture:Show();
			else
				model.TransmogStateTexture:Hide();
			end
			model.Favorite.Icon:SetShown(set.favorite);
			model.setID = set.setID;
		else
			model:Hide();
			-- The next Show copies the unit's own clothes onto the model; the set has to go on again.
			model.setID = nil;
		end
	end

	if ( pendingTransmogModelFrame ) then
		self.PendingTransmogFrame:SetParent(pendingTransmogModelFrame);
		self.PendingTransmogFrame:SetPoint("CENTER");
		self.PendingTransmogFrame:Show();
		if ( self.PendingTransmogFrame.setID ~= pendingTransmogModelFrame.setID ) then
			WardrobePendingTransmogFrame_PlayAnims(self.PendingTransmogFrame);
		end
		self.PendingTransmogFrame.setID = pendingTransmogModelFrame.setID;
	else
		self.PendingTransmogFrame:Hide();
	end

	self.NoValidSetsLabel:SetShown(not C_TransmogSets.HasUsableSets());
end

function WardrobeSetsTransmogMixin:OnPageChanged(userAction)
	PlaySound("igAbiliityPageTurn");
	RebuffedMenu:Close();
	if ( userAction ) then
		self:UpdateSets();
	end
	-- The page just turned, so the models the last one staged are drawn by nothing. The client
	-- would free them ten seconds from now, which is slower than anyone pages: measured over
	-- all 63 pages of the appearance list, a page turn costs 5.7 ms over the first ten and
	-- 83.5 ms over the last ten, and 4.5 ms throughout with this call.
	C_TransmogCollection.PurgeModelCache();
end

function WardrobeSetsTransmogMixin:LoadSet(setID)
	local transmogSources = { };
	local checkedSlots = { };
	local sources = C_TransmogSets.GetSetSources(setID);
	for sourceID in pairs(sources) do
		local sourceInfo = C_TransmogCollection.GetSourceInfo(sourceID);
		local slot = sourceInfo and C_Transmog.GetSlotForInventoryType(sourceInfo.invType);
		if ( slot and slot > 0 and not checkedSlots[slot] ) then
			checkedSlots[slot] = true;
			local slotSources = C_TransmogSets.GetSourcesForSlot(setID, slot, slot);
			WardrobeCollectionFrame_SortSources(slotSources, sourceInfo.visualID);
			for i = 1, #slotSources do
				if ( slotSources[i].isCollected and not slotSources[i].useError ) then
					transmogSources[slot] = slotSources[i].sourceID;
					break;
				end
			end
		end
	end
	-- if we don't ignore the event, clearing will momentarily set the page to the one with the set the user currently has transmogged
	-- if that's a different page from the current one then the models will flicker as we swap the gear to different sets and back
	self.ignoreTransmogrifyUpdateEvent = true;
	C_Transmog.ClearPending();
	self.ignoreTransmogrifyUpdateEvent = false;
	C_Transmog.LoadSources(transmogSources, -1, -1);
end

function WardrobeSetsTransmogMixin:GetFirstMatchingSetID(sourceIndex)
	local transmogSourceIDs = { };
	for _, button in ipairs(WardrobeTransmogFrame.Model.SlotButtons) do
		local slotID = GetInventorySlotInfo(button.slot);
		local sourceID = select(sourceIndex, WardrobeCollectionFrame_GetInfoForEquippedSlot(button.slot, LE_TRANSMOG_TYPE_APPEARANCE));
		if ( sourceID ~= NO_TRANSMOG_SOURCE_ID ) then
			transmogSourceIDs[slotID] = sourceID;
		end
	end

	local usableSets = SetsDataProvider:GetUsableSets();
	for _, set in ipairs(usableSets) do
		local setMatched = false;
		for slotID, transmogSourceID in pairs(transmogSourceIDs) do
			local sourceIDs = C_TransmogSets.GetSourceIDsForSlot(set.setID, slotID);
			-- if there are no sources for a slot, that slot is considered matched
			local slotMatched = (#sourceIDs == 0);
			for _, sourceID in ipairs(sourceIDs) do
				if ( transmogSourceID == sourceID ) then
					slotMatched = true;
					break;
				end
			end
			setMatched = slotMatched;
			if ( not setMatched ) then
				break;
			end
		end
		if ( setMatched ) then
			return set.setID;
		end
	end
	return nil;
end

function WardrobeSetsTransmogMixin:RefreshCameras()
	if ( self:IsShown() ) then
		local _, transmogCameraID = C_TransmogSets.GetCameraIDs();
		for i, model in ipairs(self.Models) do
			model:ApplyUICamera(transmogCameraID, true);
		end
	end
end

function WardrobeSetsTransmogMixin:OnSearchUpdate()
	SetsDataProvider:ClearUsableSets();
	self:UpdateSets();
end

function WardrobeSetsTransmogMixin:OnUnitModelChangedEvent()
	if ( not self.Models[1]:CanSetUnit("player") ) then
		return false;
	end
	for i, model in ipairs(self.Models) do
		model:RefreshUnit();
		model.setID = nil;
	end
	self:RefreshCameras();
	self:UpdateSets();
	return true;
end

function WardrobeSetsTransmogMixin:CanHandleKey(key)
	return key == WARDROBE_PREV_VISUAL_KEY or key == WARDROBE_NEXT_VISUAL_KEY
	       or key == WARDROBE_UP_VISUAL_KEY or key == WARDROBE_DOWN_VISUAL_KEY;
end

function WardrobeSetsTransmogMixin:HandleKey(key)
	if ( not self.selectedSetID ) then
		return;
	end
	local usableSets = SetsDataProvider:GetUsableSets();
	local setIndex;
	for i = 1, #usableSets do
		if ( usableSets[i].setID == self.selectedSetID ) then
			setIndex = i;
			break;
		end
	end
	if ( setIndex ) then
		setIndex = WardrobeUtils_GetAdjustedDisplayIndexFromKeyPress(self, setIndex, #usableSets, key);
		self:SelectSet(usableSets[setIndex].setID);
	end
end
function WardrobeSetsTransmogMixin:SelectSet(setID)
	self.selectedSetID = setID;
	self:LoadSet(setID);
	self:ResetPage();
end

function WardrobeSetsTransmogMixin:ResetPage()
	local page = 1;
	if ( self.selectedSetID ) then
		local usableSets = SetsDataProvider:GetUsableSets();
		self.PagingFrame:SetMaxPages(ceil(#usableSets / self.PAGE_SIZE));
		for i, set in ipairs(usableSets) do
			if ( set.setID == self.selectedSetID ) then
				page = GetPage(i, self.PAGE_SIZE);
				break;
			end
		end
	end
	self.PagingFrame:SetCurrentPage(page);
	self:UpdateSets();
end

-- The set model's own menu as entries for RebuffedMenu.
function WardrobeSetsTransmogMixin:GetModelMenuEntries(setID)
	local isFavorite = C_TransmogSets.GetIsFavorite(setID);
	return {
		{
			text = isFavorite and BATTLE_PET_UNFAVORITE or BATTLE_PET_FAVORITE,
			notCheckable = true,
			func = function() self:SetFavorite(setID, not isFavorite); end,
		},
		{ text = CANCEL, notCheckable = true, func = function() end },
	};
end

function WardrobeSetsTransmogMixin:SetFavorite(setID, favorite)
	if ( favorite ) then
		-- remove any existing favorite in this group
		local _, isGroupFavorite = C_TransmogSets.GetIsFavorite(setID);
		if ( isGroupFavorite ) then
			local baseSetID = C_TransmogSets.GetBaseSetID(setID);
			C_TransmogSets.SetIsFavorite(baseSetID, false);
			local variantSets = C_TransmogSets.GetVariantSets(baseSetID);
			for i, variantSet in ipairs(variantSets) do
				C_TransmogSets.SetIsFavorite(variantSet.setID, false);
			end
		end
		C_TransmogSets.SetIsFavorite(setID, true);
	else
		C_TransmogSets.SetIsFavorite(setID, false);
	end
end


-- ***** HELPERS FOR THE XML

function WardrobeSlotButton_OnLoad(self)
	SetParentArray(self, "Buttons");
	self.transmogType = LE_TRANSMOG_TYPE_APPEARANCE;
	self.Highlight:SetAtlas("bags-roundhighlight");
	self.SelectedTexture:SetAtlas("transmog-nav-slot-selected", true);
end

function WardrobeEnchantButton_OnLoad(self)
	SetParentArray(self, "Buttons");
	self.transmogType = LE_TRANSMOG_TYPE_ILLUSION;
	self.NormalTexture:SetAtlas("transmog-nav-slot-enchant", true);
	self.Highlight:SetAtlas("bags-roundhighlight");
	self.SelectedTexture:SetAtlas("transmog-nav-slot-selected-small", true);
end

function WardrobeSetsScrollFrameButton_OnLoad(self)
	self.Background:SetAtlas("PetList-ButtonBackground");
	self.SelectedTexture:SetAtlas("PetList-ButtonSelect");
	self.Favorite:SetAtlas("collections-icon-favorites", true);
	self.New:SetAtlas("GarrMission-AbilityHighlight");
	self.HighlightTexture:SetAtlas("PetList-ButtonHighlight");
end

-- A quarter turn of a texture's atlas cell, the way retail's Rotation animations turned the wisps.
local function TurnTexCoords(texture, clockwise)
	local ULx, ULy, LLx, LLy, URx, URy, LRx, LRy = texture:GetTexCoord();
	if ( clockwise ) then
		texture:SetTexCoord(LLx, LLy, LRx, LRy, ULx, ULy, URx, URy);
	else
		texture:SetTexCoord(URx, URy, ULx, ULy, LRx, LRy, LLx, LLy);
	end
	local width, height = texture:GetSize();
	texture:SetSize(height, width);
end

function WardrobePendingTransmogFrame_OnLoad(self)
	self.Glowframe:SetAtlas(self:GetAttribute("glowAtlas"), true);
	self.Animated = { self.Glowframe };
	for i = 1, 12 do
		local wisp = self["Wisp"..i];
		wisp:SetAtlas("transmog-wardrobe-border-selected-wisp", true);
		local turn = mod(i, 4);
		if ( turn == 2 ) then
			wisp:FlipX();
			wisp:FlipY();
		elseif ( turn == 3 ) then
			TurnTexCoords(wisp, true);
		elseif ( turn == 0 ) then
			TurnTexCoords(wisp, false);
		end
		tinsert(self.Animated, wisp);
	end
	for i = 1, 4 do
		local smoke = self["Smoke"..i];
		smoke:SetAtlas("transmog-wardrobe-border-selected-smoke", true);
		if ( mod(i, 2) == 0 ) then
			smoke:FlipY();
		end
		tinsert(self.Animated, smoke);
	end
	if ( self.UndoIcon ) then
		self.UndoIcon:SetAtlas("transmog-icon-revert", true);
	end
end

function WardrobePendingTransmogFrame_PlayAnims(self)
	for _, texture in ipairs(self.Animated) do
		texture.Anim:Stop();
		texture.Anim:Play();
	end
end

-- ***** POPUPS (7.3.5's StaticPopup.lua entries for the Wardrobe)

StaticPopupDialogs["NAME_TRANSMOG_OUTFIT"] = {
	text = TRANSMOG_OUTFIT_NAME,
	button1 = SAVE,
	button2 = CANCEL,
	OnAccept = function(self)
		WardrobeOutfitFrame:NameOutfit(self.editBox:GetText(), self.data);
	end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	hasEditBox = 1,
	maxLetters = 31,
	OnShow = function(self)
		self.button1:Disable();
		self.button2:Enable();
		self.editBox:SetFocus();
	end,
	OnHide = function(self)
		self.editBox:SetText("");
	end,
	EditBoxOnEnterPressed = function(self)
		if ( self:GetParent().button1:IsEnabled() == 1 ) then
			StaticPopup_OnClick(self:GetParent(), 1);
		end
	end,
	EditBoxOnTextChanged = function (self)
		local parent = self:GetParent();
		if ( parent.editBox:GetText() ~= "" ) then
			parent.button1:Enable();
		else
			parent.button1:Disable();
		end
	end,
	EditBoxOnEscapePressed = function(self)
		self:GetParent():Hide();
	end
};

StaticPopupDialogs["CONFIRM_OVERWRITE_TRANSMOG_OUTFIT"] = {
	text = TRANSMOG_OUTFIT_CONFIRM_OVERWRITE,
	button1 = YES,
	button2 = NO,
	OnAccept = function (self) WardrobeOutfitFrame:SaveOutfit(self.data.name, self.data.outfitID) end,
	OnCancel = function (self)
		local name = self.data.name;
		self:Hide();
		local dialog = StaticPopup_Show("NAME_TRANSMOG_OUTFIT");
		if ( dialog ) then
			dialog.editBox:SetText(name);
		end
	end,
	hideOnEscape = 1,
	timeout = 0,
	whileDead = 1,
	noCancelOnEscape = 1,
}

StaticPopupDialogs["CONFIRM_DELETE_TRANSMOG_OUTFIT"] = {
	text = TRANSMOG_OUTFIT_CONFIRM_DELETE,
	button1 = YES,
	button2 = NO,
	OnAccept = function (self) WardrobeOutfitFrame:DeleteOutfit(self.data); end,
	OnCancel = function (self) end,
	hideOnEscape = 1,
	timeout = 0,
	whileDead = 1,
}

StaticPopupDialogs["TRANSMOG_OUTFIT_ALL_INVALID_APPEARANCES"] = {
	text = TRANSMOG_OUTFIT_ALL_INVALID_APPEARANCES,
	button1 = OKAY,
	hideOnEscape = 1,
	timeout = 0,
	whileDead = 1,
}

StaticPopupDialogs["TRANSMOG_OUTFIT_SOME_INVALID_APPEARANCES"] = {
	text = TRANSMOG_OUTFIT_SOME_INVALID_APPEARANCES,
	button1 = OKAY,
	button2 = CANCEL,
	OnShow = function(self)
		if ( WardrobeOutfitFrame.name ) then
			self.button1:SetText(SAVE);
		else
			self.button1:SetText(CONTINUE);
		end
	end,
	OnAccept = function(self)
		WardrobeOutfitFrame:ContinueWithSave();
	end,
	hideOnEscape = 1,
	timeout = 0,
	whileDead = 1,
}

StaticPopupDialogs["TRANSMOG_APPLY_WARNING"] = {
	text = "%s",
	button1 = OKAY,
	button2 = CANCEL,
	OnAccept = function(self)
		return WardrobeTransmogFrame_ApplyPending(self.data.warningIndex);
	end,
	OnHide = function()
		WardrobeTransmogFrame_UpdateApplyButton();
	end,
	timeout = 0,
	hideOnEscape = 1,
	hasItemFrame = 1,
}
