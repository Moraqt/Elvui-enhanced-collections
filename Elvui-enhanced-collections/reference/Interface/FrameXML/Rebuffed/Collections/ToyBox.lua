-- The toy box: eighteen icons to a page, retail's Blizzard_ToyBox.lua on this client's API.
--
-- A toy is an item and shows as one. There is no model here and no details pane: retail shows a
-- grid of icons with the name beside each, and the tooltip -- the item's own -- says the rest.
--
-- What the account has learned, what it has starred and what the catalogue holds all come from
-- C_ToyBox, which the extension fills from SMSG_TOY_STATE. Names and icons are the item's, out of
-- the client's own cache, which answers a moment after the first ask; ReloadWhenNamed below is
-- what redraws the page when the answers land.

local TOYS_PER_PAGE = 18

-- Legion's /usetoy <name>, the macro command for a toy. /use finds a toy too (the extension wraps
-- UseItemByName), but a copy in the bags wins there; this one always means the toy.
SLASH_USETOY1 = "/usetoy"
SlashCmdList["USETOY"] = function(msg)
	local name = SecureCmdOptionParse(msg)
	if name and name ~= "" then
		UseToyByName(name)
	end
end

-- The client's macro parser knows a /use line by reading SLASH_USE1 to SLASH_USE9 whenever it looks
-- at a macro, and it is that line that gives a macro button its item's icon and cooldown. Listing
-- /usetoy there gives a /usetoy macro the toy's. Running the command is not affected: ChatFrame.lua
-- filled its table of secure commands before this file loaded, so /usetoy still reaches
-- SlashCmdList["USETOY"] above and always means the toy.
for i = 1, 9 do
	if not _G["SLASH_USE" .. i] then
		_G["SLASH_USE" .. i] = SLASH_USETOY1
		break
	end
end

-- A refused use gets its line wherever the toy was used from -- the window, an action bar or a
-- macro -- the way the client's own "not ready yet" follows an item on cooldown. The cooldown the
-- server sent with the result is the item's now, recorded by the extension where GetItemCooldown
-- reads it.
local toyUseResults = CreateFrame("Frame")
toyUseResults:RegisterEvent("REBUFFED_TOY_USE_RESULT")
toyUseResults:SetScript("OnEvent", function(self, event, itemID, result)
	if result ~= 0 then
		local line = _G["TOY_USE_ERROR_" .. result]
		if line then
			UIErrorsFrame:AddMessage(line, RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b, 1.0)
		end
	end
end)

-- How often a page with nameless rows is drawn again while the item cache fills.
local NAME_RETRY_SECONDS = 0.5

ToyBoxMixin = {}

function ToyBoxMixin:OnLoad()
	self.toys = {}

	-- The template's OnUpdate drives a Ctrl+F focus this client cannot answer, the way the
	-- journal panel's own search box is treated.
	self.SearchBox:SetScript("OnUpdate", nil)

	local filter = self.FilterButton
	filter:AddFilterOption("collected", filter:CreateFilterInfo(COLLECTIONS_FILTER_COLLECTED))
	filter:AddFilterOption("notcollected", filter:CreateFilterInfo(COLLECTIONS_FILTER_NOT_COLLECTED))
	filter:RegisterCallback("OnFilterChanged", self.RefreshList, self)

	for i = 1, TOYS_PER_PAGE do
		self.IconsFrame["Button" .. i].toyBox = self
	end

	-- The icons frame is a background as well as a container, and it is drawn over anything at a
	-- lower level: the paging strip sits inside it and has to be raised above it to be seen.
	self.PagingFrame:SetFrameLevel(self.IconsFrame:GetFrameLevel() + 5)
end

function ToyBoxMixin:OnShow()
	self:RegisterEvent("TOYS_UPDATED")
	self:RegisterEvent("NEW_TOY_ADDED")
	self:RegisterEvent("REBUFFED_ITEM_CACHED")
	self:RegisterEvent("SPELL_UPDATE_COOLDOWN")
	self:RefreshList()
end

function ToyBoxMixin:OnHide()
	self:UnregisterEvent("TOYS_UPDATED")
	self:UnregisterEvent("NEW_TOY_ADDED")
	self:UnregisterEvent("REBUFFED_ITEM_CACHED")
	self:UnregisterEvent("SPELL_UPDATE_COOLDOWN")
end

function ToyBoxMixin:OnEvent(event)
	if event == "SPELL_UPDATE_COOLDOWN" then
		self:UpdateButtons()
	elseif event == "REBUFFED_ITEM_CACHED" then
		-- Names affect the search results as well as the visible buttons.
		self:RefreshList()
	else
		self:RefreshList()
	end
end

-- The wait for the item cache to answer with the names a page needs.
function ToyBoxMixin:OnUpdate(elapsed)
	if self.waitingForNames or self.waitingForSearchNames then
		self.nameRetry = (self.nameRetry or 0) + elapsed
		if self.nameRetry >= NAME_RETRY_SECONDS then
			self.nameRetry = 0
			self:RefreshList()
		end
	end
end

function ToyBoxMixin:OnMouseWheel(delta)
	self.PagingFrame:OnMouseWheel(delta)
end

-- The paging strip calls this on its parent when the page changes.
function ToyBoxMixin:OnPageChanged()
	PlaySound("igAbiliityPageTurn")
	self:UpdateButtons()
end

-- The list this page draws from: the catalogue, cut by the search box and the filter, in the
-- order the server sent it.
function ToyBoxMixin:RefreshList()
	local filter = self.FilterButton
	local search = strtrim(self.SearchBox:GetText() or ""):lower()
	local stateFiltered = filter:IsFiltered("collected") or filter:IsFiltered("notcollected")

	wipe(self.toys)
	self.waitingForSearchNames = false
	local collected = 0
	for _, itemID in ipairs(C_ToyBox.GetToyIDs()) do
		local isCollected = C_ToyBox.PlayerHasToy(itemID)
		local shown = true
		if stateFiltered then
			shown = filter:IsFiltered(isCollected and "collected" or "notcollected")
		end
		if shown and search ~= "" then
			local name = GetItemInfo(itemID)
			self.waitingForSearchNames = self.waitingForSearchNames or name == nil
			shown = name ~= nil and name:lower():find(search, 1, true) ~= nil
		end
		if shown then
			tinsert(self.toys, itemID)
			if isCollected then
				collected = collected + 1
			end
		end
	end

	self.PagingFrame:SetMaxPages(1 + math.floor(math.max(#self.toys - 1, 0) / TOYS_PER_PAGE))
	self.ProgressBar:SetProgress(collected, #self.toys)
	self:UpdateButtons()
end

function ToyBoxMixin:UpdateButtons()
	local first = (self.PagingFrame:GetCurrentPage() - 1) * TOYS_PER_PAGE
	self.waitingForNames = false
	for i = 1, TOYS_PER_PAGE do
		self.IconsFrame["Button" .. i]:Update(self.toys[first + i])
	end
end

--
-- One toy
--
ToySpellButtonMixin = {}

function ToySpellButtonMixin:OnLoad()
	self:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	-- Legion's ToySpellButton_OnDrag: the toy goes on the cursor as its item, which an action bar
	-- takes and the extension uses as the toy.
	self:RegisterForDrag("LeftButton")
	self:SetScript("OnDragStart", self.OnDragStart)
	self.SlotFrameCollected:SetAtlas("collections-itemborder-collected")
	self.SlotFrameUncollected:SetAtlas("collections-itemborder-uncollected")
	self.SlotFrameUncollectedInnerGlow:SetAtlas("collections-itemborder-uncollected-innerglow", true)
	self.NewGlow:SetAtlas("collections-newglow")
	self.Favorite:SetAtlas("collections-icon-favorites", true)
end

function ToySpellButtonMixin:Update(itemID)
	self.itemID = itemID
	if not itemID then
		self:Hide()
		return
	end

	self:Show()

	local toyBox = self.toyBox
	local name, _, quality, _, _, _, _, _, _, icon = GetItemInfo(itemID)
	if not name then
		-- The cache has not answered yet. The row says so and the box asks again shortly, which
		-- is the first visit after a fresh install and no longer.
		toyBox.waitingForNames = true
		name = RETRIEVING_ITEM_INFO
	end

	local isCollected = C_ToyBox.PlayerHasToy(itemID)
	self.Icon:SetTexture(icon)
	self.IconUncollected:SetTexture(icon)
	self.IconUncollected:SetDesaturated(true)
	self.Icon:SetShown(isCollected)
	self.IconUncollected:SetShown(not isCollected)
	self.SlotFrameCollected:SetShown(isCollected)
	self.SlotFrameUncollected:SetShown(not isCollected)
	self.SlotFrameUncollectedInnerGlow:SetShown(not isCollected)

	self.Name:SetText(name)
	if isCollected then
		self.Name:SetTextColor(1, 0.82, 0, 1)
		self.Name:SetShadowColor(0, 0, 0, 1)
	else
		self.Name:SetTextColor(0.33, 0.27, 0.20, 1)
		self.Name:SetShadowColor(0, 0, 0, 0.33)
	end

	local _, _, _, _, isFavorite, isNew = C_ToyBox.GetToyInfo(itemID)
	self.Favorite:SetShown(isFavorite)
	self.New:SetShown(isNew)
	self.NewGlow:SetShown(isNew)

	CooldownFrame_SetTimer(self.Cooldown, GetItemCooldown(itemID))
end

function ToySpellButtonMixin:OnDragStart()
	if self.itemID then
		C_ToyBox.PickupToyBoxItem(self.itemID)
	end
end

function ToySpellButtonMixin:OnClick(button)
	if not self.itemID then
		return
	end

	-- A held modifier means the click is about the item, not about using it: the client's own
	-- handler puts the link in the chat box and opens the dressing room, the same as a click in a
	-- bag. It returns either way -- with no chat box open the link goes nowhere, and a click that
	-- was meant to link one must not fire it instead.
	if IsModifiedClick("CHATLINK") or IsModifiedClick("DRESSUP") then
		local link = select(2, GetItemInfo(self.itemID))
		if link then
			HandleModifiedItemClick(link)
		end
		return
	end

	if button == "RightButton" then
		if C_ToyBox.PlayerHasToy(self.itemID) then
			C_ToyBox.SetIsFavorite(self.itemID, not C_ToyBox.GetIsFavorite(self.itemID))
		end
		return
	end

	C_ToyBox.ClearNewToy(self.itemID)
	C_ToyBox.UseToy(self.itemID)
end

function ToySpellButtonMixin:OnEnter()
	if not self.itemID then
		return
	end

	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	-- Naming the thing and leaving the item level off belong to any tooltip of a toy and are done
	-- for all of them in GameTooltip_OnSetItem. The price is this window's alone: a toy in the box
	-- is a record that it was learned, and there is nothing to carry to a vendor.
	GameTooltip.hideSellPrice = true
	GameTooltip:SetHyperlink("item:" .. self.itemID)
	GameTooltip.hideSellPrice = nil

	-- Where the toy comes from is the catalogue's line, not the item's, so the tooltip is where
	-- it goes now that there is no details pane to hold it.
	local _, _, sourceText = C_ToyBox.GetToyInfo(self.itemID)
	if sourceText and sourceText ~= "" then
		GameTooltip:AddLine(sourceText, 1, 1, 1)
	end
	GameTooltip:AddLine(TOY_BOX_FAVORITE_HINT, 0.5, 0.5, 0.5)
	GameTooltip:Show()

	C_ToyBox.ClearNewToy(self.itemID)
	self:Update(self.itemID)
end

function ToySpellButtonMixin:OnLeave()
	GameTooltip:Hide()
end
