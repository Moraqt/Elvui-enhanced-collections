
--===================================================================================================================================
WardrobeOutfitDropDownMixin = { };

function WardrobeOutfitDropDownMixin:OnLoad()
	local button = _G[self:GetName().."Button"];
	button:SetScript("OnClick", function(self)
						PlaySound("igMainMenuOptionCheckBoxOn");
						WardrobeOutfitFrame:Toggle(self:GetParent());
						end
					);
	UIDropDownMenu_JustifyText(self, "LEFT");
	if ( self.width ) then
		UIDropDownMenu_SetWidth(self, self.width);
	end
end

function WardrobeOutfitDropDown_OnLoad(self)
	AttributesToKeyValues(self, "width", "minMenuStringWidth", "maxMenuStringWidth");
	MixinAndLoadScripts(self, "WardrobeOutfitDropDownMixin");
end

function WardrobeOutfitDropDownMixin:OnShow()
	self:RegisterEvent("TRANSMOG_OUTFITS_CHANGED");
	self:RegisterEvent("TRANSMOGRIFY_UPDATE");
	self:SelectOutfit(self:GetLastOutfitID(), true);
end

function WardrobeOutfitDropDownMixin:OnHide()
	self:UnregisterEvent("TRANSMOG_OUTFITS_CHANGED");
	self:UnregisterEvent("TRANSMOGRIFY_UPDATE");
	WardrobeOutfitFrame:ClosePopups(self);
	if ( WardrobeOutfitFrame.dropDown == self ) then
		WardrobeOutfitFrame:Hide();
	end
end

function WardrobeOutfitDropDownMixin:OnEvent(event)
	if ( event == "TRANSMOG_OUTFITS_CHANGED" ) then
		-- try to reselect the same outfit to update the name
		-- if it changed or clear the name if it got deleted, or select the one just saved
		self:SelectOutfit(self.selectedOutfitID or self.pendingOutfitID);
		self.pendingOutfitID = nil;
		if ( WardrobeOutfitFrame:IsShown() ) then
			WardrobeOutfitFrame:Update();
		end
	end
	-- don't need to do anything for "TRANSMOGRIFY_UPDATE" beyond updating the save button
	self:UpdateSaveButton();
end

function WardrobeOutfitDropDownMixin:UpdateSaveButton()
	if ( self.selectedOutfitID ) then
		self.SaveButton:SetEnabled(not self:IsOutfitDressed());
	else
		self.SaveButton:SetEnabled(false);
	end
end

function WardrobeOutfitDropDownMixin:OnOutfitSaved(outfitID)
end

function WardrobeOutfitDropDownMixin:SelectOutfit(outfitID, loadOutfit)
	local name;
	if ( outfitID ) then
		name = C_TransmogCollection.GetOutfitName(outfitID);
	end
	if ( name ) then
		UIDropDownMenu_SetText(self, name);
	else
		outfitID = nil;
		UIDropDownMenu_SetText(self, GRAY_FONT_COLOR_CODE..TRANSMOG_OUTFIT_NONE..FONT_COLOR_CODE_CLOSE);
	end
	self.selectedOutfitID = outfitID;
	if ( loadOutfit ) then
		self:LoadOutfit(outfitID);
	end
	self:UpdateSaveButton();
	self:OnSelectOutfit(outfitID);
end

function WardrobeOutfitDropDownMixin:OnSelectOutfit(outfitID)
	-- nothing to see here
end

function WardrobeOutfitDropDownMixin:GetLastOutfitID()
	return nil;
end

function WardrobeOutfitDropDownMixin:IsOutfitDressed()
	if ( not self.selectedOutfitID ) then
		return true;
	end
	local appearanceSources, mainHandEnchant, offHandEnchant = C_TransmogCollection.GetOutfitSources(self.selectedOutfitID);
	if ( not appearanceSources ) then
		return true;
	end

	for i = 1, #TRANSMOG_SLOTS do
		if ( TRANSMOG_SLOTS[i].transmogType == LE_TRANSMOG_TYPE_APPEARANCE ) then
			local sourceID = self:GetSlotSourceID(TRANSMOG_SLOTS[i].slot, LE_TRANSMOG_TYPE_APPEARANCE);
			local slotID = GetInventorySlotInfo(TRANSMOG_SLOTS[i].slot);
			if ( sourceID ~= NO_TRANSMOG_SOURCE_ID and sourceID ~= appearanceSources[slotID] ) then
				return false;
			end
		end
	end
	local mainHandSourceID = self:GetSlotSourceID("MAINHANDSLOT", LE_TRANSMOG_TYPE_ILLUSION);
	if ( mainHandSourceID ~= mainHandEnchant ) then
		return false;
	end
	local offHandSourceID = self:GetSlotSourceID("SECONDARYHANDSLOT", LE_TRANSMOG_TYPE_ILLUSION);
	if ( offHandSourceID ~= offHandEnchant ) then
		return false;
	end
	return true;
end

function WardrobeOutfitDropDownMixin:CheckOutfitForSave(name)
	local sources = { };
	local mainHandEnchant, offHandEnchant;
	local hadInvalidSources = false;

	for i = 1, #TRANSMOG_SLOTS do
		local sourceID = self:GetSlotSourceID(TRANSMOG_SLOTS[i].slot, TRANSMOG_SLOTS[i].transmogType);
		if ( sourceID ~= NO_TRANSMOG_SOURCE_ID ) then
			if ( TRANSMOG_SLOTS[i].transmogType == LE_TRANSMOG_TYPE_APPEARANCE ) then
				local slotID = GetInventorySlotInfo(TRANSMOG_SLOTS[i].slot);
				local isValidSource = C_TransmogCollection.PlayerKnowsSource(sourceID);
				if ( not isValidSource ) then
					local _, canCollect = C_TransmogCollection.PlayerCanCollectSource(sourceID);
					if ( canCollect ) then
						isValidSource = true;
					else
						hadInvalidSources = true;
					end
				end
				if ( isValidSource ) then
					sources[slotID] = sourceID;
				end
			elseif ( TRANSMOG_SLOTS[i].transmogType == LE_TRANSMOG_TYPE_ILLUSION ) then
				if ( TRANSMOG_SLOTS[i].slot == "MAINHANDSLOT" ) then
					mainHandEnchant = sourceID;
				else
					offHandEnchant = sourceID;
				end
			end
		end
	end

	-- store the state for this save
	WardrobeOutfitFrame.sources = sources;
	WardrobeOutfitFrame.mainHandEnchant = mainHandEnchant;
	WardrobeOutfitFrame.offHandEnchant = offHandEnchant;
	WardrobeOutfitFrame.hadInvalidSources = hadInvalidSources;
	WardrobeOutfitFrame.name = name;
	-- save the dropdown
	WardrobeOutfitFrame.popupDropDown = self;

	WardrobeOutfitFrame:EvaluateSaveState();
end

--===================================================================================================================================
WardrobeOutfitFrameMixin = { };

WardrobeOutfitFrameMixin.popups = {
	"NAME_TRANSMOG_OUTFIT",
	"CONFIRM_DELETE_TRANSMOG_OUTFIT",
	"CONFIRM_OVERWRITE_TRANSMOG_OUTFIT",
	"TRANSMOG_OUTFIT_SOME_INVALID_APPEARANCES",
	"TRANSMOG_OUTFIT_ALL_INVALID_APPEARANCES",
};

local OUTFIT_FRAME_MIN_STRING_WIDTH = 152;
local OUTFIT_FRAME_MAX_STRING_WIDTH = 216;
local OUTFIT_FRAME_ADDED_PIXELS = 90;	-- pixels added to string width

-- The outfit's icon: its first piece's, in slot order (the icon retail saved with the outfit;
-- the extension keeps none).
local function GetOutfitIcon(outfitID)
	local appearanceSources = C_TransmogCollection.GetOutfitSources(outfitID);
	for i = 1, #TRANSMOG_SLOTS do
		if ( TRANSMOG_SLOTS[i].transmogType == LE_TRANSMOG_TYPE_APPEARANCE ) then
			local sourceID = appearanceSources[GetInventorySlotInfo(TRANSMOG_SLOTS[i].slot)];
			if ( sourceID ) then
				return C_TransmogCollection.GetSourceIcon(sourceID);
			end
		end
	end
end

function WardrobeOutfitFrame_OnLoad(self)
	MixinAndLoadScripts(self, "WardrobeOutfitFrameMixin");
end

function WardrobeOutfitFrameMixin:OnHide()
	self.timer = nil;
end

function WardrobeOutfitFrameMixin:Toggle(dropDown)
	if ( self.dropDown == dropDown and self:IsShown() ) then
		WardrobeOutfitFrame:Hide();
	else
		-- Stand aside for whatever menu is up: ours first, and the stock lists too, because an
		-- addon may still be using them.
		RebuffedMenu:Close();
		CloseDropDownMenus();
		self.dropDown = dropDown;
		self:Show();
		self:SetPoint("TOPLEFT", self.dropDown, "BOTTOMLEFT", 8, -3);
		self:Update();
	end
end

function WardrobeOutfitFrameMixin:OnUpdate(elapsed)
	local mouseFocus = GetMouseFocus();
	for i = 1, #self.Buttons do
		local button = self.Buttons[i];
		if ( button == mouseFocus or button:IsMouseOver() ) then
			if ( button.outfitID ) then
				button.EditButton:Show();
			else
				button.EditButton:Hide();
			end
			button.Highlight:Show();
		else
			button.EditButton:Hide();
			button.Highlight:Hide();
		end
	end
	-- Retail asks UIDROPDOWNMENU_OPEN_MENU, but the era only ever sets that global and never
	-- clears it. Every menu in this window is RebuffedMenu now, so that is what to stand aside
	-- for; DropDownList1 is still checked because an addon's menu can be up over this frame.
	if ( RebuffedMenu:IsAnyOpen() or DropDownList1:IsShown() ) then
		self:Hide();
	end
	if ( self.timer ) then
		self.timer = self.timer - elapsed;
		if ( self.timer < 0 ) then
			self:Hide();
		end
	end
end

function WardrobeOutfitFrameMixin:StartHideCountDown()
	self.timer = UIDROPDOWNMENU_SHOW_TIME;
end

function WardrobeOutfitFrameMixin:StopHideCountDown()
	self.timer = nil;
end

function WardrobeOutfitFrameMixin:Update()
	local outfits = C_TransmogCollection.GetOutfits();
	local buttons = self.Buttons;
	local numButtons = 0;
	local stringWidth = 0;
	local minStringWidth = self.dropDown.minMenuStringWidth or OUTFIT_FRAME_MIN_STRING_WIDTH;
	local maxStringWidth = self.dropDown.maxMenuStringWidth or OUTFIT_FRAME_MAX_STRING_WIDTH;
	self:SetWidth(maxStringWidth + OUTFIT_FRAME_ADDED_PIXELS);
	for i = 1, C_TransmogCollection.GetNumMaxOutfits() do
		local newOutfitButton = (i == (#outfits + 1));
		if ( outfits[i] or newOutfitButton ) then
			local button = buttons[i];
			if ( not button ) then
				button = CreateFrame("BUTTON", nil, self, "WardrobeOutfitButtonTemplate");
				button:SetPoint("TOPLEFT", buttons[i-1], "BOTTOMLEFT", 0, 0);
				button:SetPoint("TOPRIGHT", buttons[i-1], "BOTTOMRIGHT", 0, 0);
			end
			button:Show();
			if ( newOutfitButton ) then
				button:SetText(GREEN_FONT_COLOR_CODE..TRANSMOG_OUTFIT_NEW..FONT_COLOR_CODE_CLOSE);
				button.Icon:SetTexture("Interface\\Buttons\\UI-PlusButton-Up");
				button.outfitID = nil;
				button.Check:Hide();
				button.Selection:Hide();
			else
				if ( outfits[i].outfitID == self.dropDown.selectedOutfitID ) then
					button.Check:Show();
					button.Selection:Show();
				else
					button.Selection:Hide();
					button.Check:Hide();
				end
				button.Text:SetWidth(0);
				button:SetText(NORMAL_FONT_COLOR_CODE..outfits[i].name..FONT_COLOR_CODE_CLOSE);
				button.Icon:SetTexture(GetOutfitIcon(outfits[i].outfitID));
				button.outfitID = outfits[i].outfitID;
			end
			stringWidth = max(stringWidth, button.Text:GetStringWidth());
			if ( button.Text:GetStringWidth() > maxStringWidth) then
				button.Text:SetWidth(maxStringWidth);
			end
			numButtons = numButtons + 1;
		else
			if ( buttons[i] ) then
				buttons[i]:Hide();
			end
		end
	end
	stringWidth = max(stringWidth, minStringWidth);
	stringWidth = min(stringWidth, maxStringWidth);
	self:SetWidth(stringWidth + OUTFIT_FRAME_ADDED_PIXELS);
	self:SetHeight(30 + numButtons * 20);
end

function WardrobeOutfitFrameMixin:SaveOutfit(name, existingOutfitID)
	local outfitID = C_TransmogCollection.SaveOutfit(name, self.sources, self.mainHandEnchant, self.offHandEnchant, existingOutfitID);
	if ( not outfitID ) then
		UIErrorsFrame:AddMessage(ERR_TRANSMOGRIFY_INVALID_SOURCE, 1.0, 0.1, 0.1, 1.0);
		return;
	end
	if ( self.popupDropDown ) then
		-- SaveOutfit predicts the id, but the outfit itself only arrives with the server's list on
		-- TRANSMOG_OUTFITS_CHANGED, so SelectOutfit finds no name for it yet and drops it. OnEvent
		-- picks the id up from here once the list is in.
		self.popupDropDown.pendingOutfitID = outfitID;
		self.popupDropDown:SelectOutfit(outfitID);
		self.popupDropDown:OnOutfitSaved(outfitID);
	end
end

function WardrobeOutfitFrameMixin:DeleteOutfit(outfitID)
	C_TransmogCollection.DeleteOutfit(outfitID);
end

function WardrobeOutfitFrameMixin:NameOutfit(newName, outfitID)
	local outfits = C_TransmogCollection.GetOutfits();
	for i = 1, #outfits do
		if ( outfits[i].name == newName ) then
			if ( outfitID ) then
				UIErrorsFrame:AddMessage(TRANSMOG_OUTFIT_ALREADY_EXISTS, 1.0, 0.1, 0.1, 1.0);
			else
				WardrobeOutfitFrame:ShowPopup("CONFIRM_OVERWRITE_TRANSMOG_OUTFIT", newName, nil, {name = newName, outfitID = outfits[i].outfitID});
			end
			return;
		end
	end
	if ( outfitID ) then
		-- this is a rename
		C_TransmogCollection.ModifyOutfit(outfitID, newName);
	else
		-- this is a new outfit
		self:SaveOutfit(newName);
	end
end

function WardrobeOutfitFrameMixin:ShowPopup(popup, ...)
	-- close all other popups
	for _, listPopup in pairs(self.popups) do
		if ( listPopup ~= popup ) then
			StaticPopup_Hide(listPopup);
		end
	end
	if ( popup ~= WardrobeOutfitEditFrame ) then
		StaticPopupSpecial_Hide(WardrobeOutfitEditFrame);
	end

	self.popupDropDown = self.dropDown;
	if ( popup == WardrobeOutfitEditFrame ) then
		StaticPopupSpecial_Show(WardrobeOutfitEditFrame);
	else
		StaticPopup_Show(popup, ...);
	end
end

function WardrobeOutfitFrameMixin:ClosePopups(requestingDropDown)
	if ( requestingDropDown and requestingDropDown ~= self.popupDropDown ) then
		return;
	end
	for _, popup in pairs(self.popups) do
		StaticPopup_Hide(popup);
	end
	StaticPopupSpecial_Hide(WardrobeOutfitEditFrame);

	-- clean up
	self.sources = nil;
	self.mainHandEnchant = nil;
	self.offHandEnchant = nil;
	self.hadInvalidSources = nil;
	self.name = nil;
	self.popupDropDown = nil;
end

function WardrobeOutfitFrameMixin:EvaluateSaveState()
	if ( self.hadInvalidSources ) then
		if ( next(self.sources) ) then
			-- warn
			WardrobeOutfitFrame:ShowPopup("TRANSMOG_OUTFIT_SOME_INVALID_APPEARANCES");
		else
			-- stop
			WardrobeOutfitFrame:ShowPopup("TRANSMOG_OUTFIT_ALL_INVALID_APPEARANCES");
		end
	else
		WardrobeOutfitFrame:ContinueWithSave();
	end
end

function WardrobeOutfitFrameMixin:ContinueWithSave()
	if ( self.name ) then
		WardrobeOutfitFrame:SaveOutfit(self.name);
		WardrobeOutfitFrame:ClosePopups();
	else
		WardrobeOutfitFrame:ShowPopup("NAME_TRANSMOG_OUTFIT");
	end
end

--===================================================================================================================================
WardrobeOutfitButtonMixin = { };

function WardrobeOutfitButton_OnLoad(self)
	SetParentArray(self, "Buttons");
	self.Selection:SetDesaturated(true);
	self.EditButton.tooltipText = TRANSMOG_OUTFIT_EDIT;
	self.Check:SetPoint("LEFT", self.Text, "RIGHT", 4, 0);
	MixinAndLoadScripts(self, "WardrobeOutfitButtonMixin");
end

function WardrobeOutfitButtonMixin:OnClick()
	PlaySound("igMainMenuOptionCheckBoxOn");
	WardrobeOutfitFrame:Hide();
	if ( self.outfitID ) then
		WardrobeOutfitFrame.dropDown:SelectOutfit(self.outfitID, true);
	else
		WardrobeOutfitFrame.dropDown:CheckOutfitForSave();
	end
end

--===================================================================================================================================
WardrobeOutfitEditFrameMixin = { };

function WardrobeOutfitEditFrame_OnLoad(self)
	Mixin(self, "WardrobeOutfitEditFrameMixin");
	self.exclusive = true;
	self.hideOnEscape = true;
	self.DeleteButton:SetWidth(self.DeleteButton:GetTextWidth() + 50);
end

function WardrobeOutfitEditFrameMixin:ShowForOutfit(outfitID)
	WardrobeOutfitFrame:Hide();
	WardrobeOutfitFrame:ShowPopup(self);
	self.outfitID = outfitID;
	self.EditBox:SetText(C_TransmogCollection.GetOutfitName(outfitID));
end

function WardrobeOutfitEditFrameMixin:OnDelete()
	WardrobeOutfitFrame:Hide();
	local name = C_TransmogCollection.GetOutfitName(self.outfitID);
	WardrobeOutfitFrame:ShowPopup("CONFIRM_DELETE_TRANSMOG_OUTFIT", name, nil,  self.outfitID);
end

function WardrobeOutfitEditFrameMixin:OnAccept()
	if ( self.AcceptButton:IsEnabled() ~= 1 ) then
		return;
	end
	StaticPopupSpecial_Hide(self);
	WardrobeOutfitFrame:NameOutfit(self.EditBox:GetText(), self.outfitID);
end