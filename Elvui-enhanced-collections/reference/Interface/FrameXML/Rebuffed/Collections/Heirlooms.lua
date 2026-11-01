-- The heirloom collection: retail's Blizzard_HeirloomCollection.lua on this client's API.
--
-- Rows of items under a heading for each slot, paged. What the account has is drawn in its own
-- colours; what it has not is grey. Clicking one the account has puts a copy in the bags -- which
-- is the whole of it, because the era's own answer to "my other character wants this sword" was to
-- post it.
--
-- The catalogue, what the account has and what this character could wear all come from C_Heirloom,
-- which the extension fills from SMSG_HEIRLOOM_STATE. Names and icons are the item's, out of the
-- client's own cache.

local CATEGORY_HEAD = 1
local CATEGORY_SHOULDER = 2
local CATEGORY_CHEST = 3
local CATEGORY_LEGS = 4
local CATEGORY_BACK = 5
local CATEGORY_WEAPON = 6
local CATEGORY_TRINKET = 7

-- Retail's own order (ITEM_EQUIP_SLOT_SORT_ORDER), and its own headings.
local CATEGORY_ORDER = {
	CATEGORY_HEAD,
	CATEGORY_SHOULDER,
	CATEGORY_BACK,
	CATEGORY_CHEST,
	CATEGORY_LEGS,
	CATEGORY_WEAPON,
	CATEGORY_TRINKET,
}

local CATEGORY_NAME = {
	[CATEGORY_HEAD] = "HEIRLOOMS_CATEGORY_HEAD",
	[CATEGORY_SHOULDER] = "HEIRLOOMS_CATEGORY_SHOULDER",
	[CATEGORY_CHEST] = "HEIRLOOMS_CATEGORY_CHEST",
	[CATEGORY_LEGS] = "HEIRLOOMS_CATEGORY_LEGS",
	[CATEGORY_BACK] = "HEIRLOOMS_CATEGORY_BACK",
	[CATEGORY_WEAPON] = "HEIRLOOMS_CATEGORY_WEAPON",
	[CATEGORY_TRINKET] = "HEIRLOOMS_CATEGORY_TRINKETS_RINGS_AND_NECKLACES",
}

-- Retail's page geometry (Blizzard_HeirloomCollection.lua), which fits this frame because the
-- journal is the same size as retail's.
local BUTTON_WIDTH = 208
local BUTTON_HEIGHT = 50
local BUTTON_PADDING_Y = 16
local HEADER_HEIGHT = 37
local ADDITIONAL_HEADER_Y_PADDING = 16
local PAGE_WIDTH = 625
local PAGE_HEIGHT = 370
local START_OFFSET_X = 40
local START_OFFSET_Y = -25

-- Marks the point in a page's layout where the next button starts a row of its own.
local NEW_ROW = -1

-- How often a page with nameless rows is drawn again while the item cache fills.
local NAME_RETRY_SECONDS = 0.5

HeirloomsMixin = {}

function HeirloomsMixin:OnLoad()
	self.pages = {}
	self.buttons = {}
	self.headers = {}
	self.usableOnly = false

	-- The template's OnUpdate drives a Ctrl+F focus this client cannot answer, the way the other
	-- two tabs treat their own search box.
	self.SearchBox:SetScript("OnUpdate", nil)

	local filter = self.FilterButton
	filter:AddFilterOption("collected", filter:CreateFilterInfo(COLLECTIONS_FILTER_COLLECTED))
	filter:AddFilterOption("notcollected", filter:CreateFilterInfo(COLLECTIONS_FILTER_NOT_COLLECTED))
	filter:RegisterCallback("OnFilterChanged", self.RefreshList, self)

	self:SetUsableFilter(false)

	-- The icons frame is a background as well as a container, and it is drawn over anything at a
	-- lower level: the paging strip sits inside it and has to be raised above it to be seen.
	self.PagingFrame:SetFrameLevel(self.IconsFrame:GetFrameLevel() + 5)
end

function HeirloomsMixin:OnShow()
	self:RegisterEvent("HEIRLOOMS_UPDATED")
	self:RegisterEvent("NEW_HEIRLOOM_ADDED")
	self:RegisterEvent("REBUFFED_ITEM_CACHED")
	self:RegisterEvent("REBUFFED_HEIRLOOM_CREATE_RESULT")
	self:RegisterEvent("BAG_UPDATE")
	self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
	self:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
	C_Heirloom.Refresh()
	self:RefreshList()
end

function HeirloomsMixin:OnHide()
	self:UnregisterEvent("HEIRLOOMS_UPDATED")
	self:UnregisterEvent("NEW_HEIRLOOM_ADDED")
	self:UnregisterEvent("REBUFFED_ITEM_CACHED")
	self:UnregisterEvent("REBUFFED_HEIRLOOM_CREATE_RESULT")
	self:UnregisterEvent("BAG_UPDATE")
	self:UnregisterEvent("PLAYER_EQUIPMENT_CHANGED")
	self:UnregisterEvent("PLAYERBANKSLOTS_CHANGED")
	self.creationRefresh = nil
end

function HeirloomsMixin:OnEvent(event, arg1, arg2)
	if event == "BAG_UPDATE" or event == "PLAYER_EQUIPMENT_CHANGED" or event == "PLAYERBANKSLOTS_CHANGED" then
		-- Bag/equipment updates arrive in bursts. Counts include the bank, so ask the server
		-- once after the burst instead of relying on the client's possibly unopened bank cache.
		self.creationRefresh = 0.2
	elseif event == "REBUFFED_HEIRLOOM_CREATE_RESULT" then
		self:OnCreateResult(arg1, arg2)
	elseif event == "REBUFFED_ITEM_CACHED" then
		-- A name that was missing has arrived. The list is built again rather than redrawn: a name
		-- is what the search box reads.
		self:RefreshList()
	else
		self:RefreshList()
	end
end

function HeirloomsMixin:OnUpdate(elapsed)
	if self.creationRefresh then
		self.creationRefresh = self.creationRefresh - elapsed
		if self.creationRefresh <= 0 then
			self.creationRefresh = nil
			C_Heirloom.Refresh()
		end
	end
	if not self.waitingForNames then
		return
	end

	self.nameRetry = (self.nameRetry or 0) + elapsed
	if self.nameRetry < NAME_RETRY_SECONDS then
		return
	end
	self.nameRetry = 0
	self:LayoutCurrentPage()
end

function HeirloomsMixin:OnMouseWheel(delta)
	self.PagingFrame:OnMouseWheel(delta)
end

-- The paging strip calls this on its parent when the page changes.
function HeirloomsMixin:OnPageChanged()
	PlaySound("igAbiliityPageTurn")
	self:LayoutCurrentPage()
end

function HeirloomsMixin:OnCreateResult(itemID, result)
	if result ~= 0 then
		local line = _G["HEIRLOOM_CREATE_ERROR_" .. result]
		if line then
			UIErrorsFrame:AddMessage(line, RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b, 1.0)
		end
	end
	self:RefreshList()
end

--
-- Whose heirlooms to show
--
-- Retail's dropdown picks a class. This era's heirlooms carry no class at all -- every one of the
-- thirty-nine is AllowableClass -1 -- so there is nothing in the data to pick by. What the data
-- does answer is whether the character in play can equip one, which is what the server sends with
-- the catalogue: armour proficiency, weapon skill, level and race, through CanUseItem. So the
-- choice is between everything and what this character could wear, which is the half of retail's
-- dropdown that means something here.
function HeirloomsMixin:GetClassMenuEntries()
	return {
		{
			text = ALL,
			value = false,
			checked = function() return not self.usableOnly end,
			func = function() self:SetUsableFilter(false) end,
		},
		{
			text = HEIRLOOMS_USABLE_ONLY,
			value = true,
			checked = function() return self.usableOnly end,
			func = function() self:SetUsableFilter(true) end,
		},
	}
end

function HeirloomsMixin:ToggleClassMenu()
	if ( RebuffedMenu:IsOpen(self.ClassDropDown) ) then
		RebuffedMenu:Close(self.ClassDropDown)
		return
	end
	RebuffedMenu:Open(self.ClassDropDown, self:GetClassMenuEntries())
end

function HeirloomsMixin:SetUsableFilter(usableOnly)
	self.usableOnly = usableOnly and true or false
	self.ClassDropDown:SetText(self.usableOnly and HEIRLOOMS_USABLE_ONLY or ALL)

	if self:IsShown() then
		self:RefreshList()
	end
end

--
-- The list, its pages, and the page on screen
--
function HeirloomsMixin:RefreshList()
	local filter = self.FilterButton
	local search = strtrim(self.SearchBox:GetText() or ""):lower()
	local stateFiltered = filter:IsFiltered("collected") or filter:IsFiltered("notcollected")

	local buckets = {}
	local collected, total = 0, 0
	self.waitingForNames = false

	for _, itemID in ipairs(C_Heirloom.GetHeirloomItemIDs()) do
		local _, category, _, _, isCollected, _, isUsable = C_Heirloom.GetHeirloomInfo(itemID)
		local shown = not self.usableOnly or isUsable

		-- The count under the bar is what this first choice leaves, the way retail counts it: the
		-- other filters hide rows without changing what there is to collect.
		if shown then
			total = total + 1
			if isCollected then
				collected = collected + 1
			end
		end

		if shown and stateFiltered then
			shown = filter:IsFiltered(isCollected and "collected" or "notcollected")
		end
		if shown and search ~= "" then
			local name = GetItemInfo(itemID)
			shown = name ~= nil and name:lower():find(search, 1, true) ~= nil
		end

		if shown and category ~= 0 then
			buckets[category] = buckets[category] or {}
			tinsert(buckets[category], itemID)
		end
	end

	self:SortBucketsIntoPages(buckets)
	self.PagingFrame:SetMaxPages(#self.pages)
	self.ProgressBar:SetProgress(collected, total)
	self:LayoutCurrentPage()
end

-- Retail's own page filler: a heading, then rows of items under it, and a new page whenever what
-- is left of the height cannot hold the next thing.
function HeirloomsMixin:SortBucketsIntoPages(buckets)
	wipe(self.pages)

	local page = {}
	local heightLeft = PAGE_HEIGHT
	local widthLeft = PAGE_WIDTH

	for _, category in ipairs(CATEGORY_ORDER) do
		local bucket = buckets[category]
		if bucket then
			if heightLeft < HEADER_HEIGHT + BUTTON_PADDING_Y + BUTTON_HEIGHT then
				tinsert(self.pages, page)
				page = {}
				heightLeft = PAGE_HEIGHT
			end

			tinsert(page, _G[CATEGORY_NAME[category]] or CATEGORY_NAME[category])
			if #page > 1 then
				heightLeft = heightLeft - ADDITIONAL_HEADER_Y_PADDING - BUTTON_HEIGHT - BUTTON_PADDING_Y
			end
			widthLeft = PAGE_WIDTH
			heightLeft = heightLeft - HEADER_HEIGHT

			for _, itemID in ipairs(bucket) do
				if widthLeft < BUTTON_WIDTH then
					widthLeft = PAGE_WIDTH
					if heightLeft < BUTTON_HEIGHT + BUTTON_PADDING_Y then
						tinsert(self.pages, page)
						page = {}
						heightLeft = PAGE_HEIGHT - HEADER_HEIGHT
					else
						tinsert(page, NEW_ROW)
						heightLeft = heightLeft - BUTTON_HEIGHT - BUTTON_PADDING_Y
					end
				end

				widthLeft = widthLeft - BUTTON_WIDTH
				tinsert(page, itemID)
			end
		end
	end

	tinsert(self.pages, page)
end

function HeirloomsMixin:AcquireButton(index)
	if not self.buttons[index] then
		self.buttons[index] = CreateFrame("Button", nil, self.IconsFrame, "HeirloomButtonTemplate")
		self.buttons[index].heirlooms = self
	end
	return self.buttons[index]
end

function HeirloomsMixin:AcquireHeader(index)
	if not self.headers[index] then
		local header = self.IconsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
		header:SetJustifyH("LEFT")
		self.headers[index] = header
	end
	return self.headers[index]
end

function HeirloomsMixin:LayoutCurrentPage()
	local page = self.pages[self.PagingFrame:GetCurrentPage()]
	local buttonsUsed, headersUsed = 0, 0

	if page then
		local offsetX, offsetY = START_OFFSET_X, START_OFFSET_Y
		for index, entry in ipairs(page) do
			if entry == NEW_ROW then
				offsetX = START_OFFSET_X
				offsetY = offsetY - BUTTON_HEIGHT - BUTTON_PADDING_Y
			elseif type(entry) == "string" then
				headersUsed = headersUsed + 1
				local header = self:AcquireHeader(headersUsed)
				header:SetText(entry)
				if index > 1 then
					offsetY = offsetY - ADDITIONAL_HEADER_Y_PADDING - BUTTON_HEIGHT - BUTTON_PADDING_Y
				end
				header:ClearAllPoints()
				header:SetPoint("TOPLEFT", self.IconsFrame, "TOPLEFT", START_OFFSET_X, offsetY)
				offsetY = offsetY - HEADER_HEIGHT
				offsetX = START_OFFSET_X
			else
				buttonsUsed = buttonsUsed + 1
				local button = self:AcquireButton(buttonsUsed)
				button:ClearAllPoints()
				button:SetPoint("TOPLEFT", self.IconsFrame, "TOPLEFT", offsetX, offsetY)
				button:Update(entry)
				offsetX = offsetX + BUTTON_WIDTH
			end
		end
	end

	-- The icons frame is a background as well as a container and draws over anything at a lower
	-- level. A button keeps the level it was created at, and the frame is raised afterwards, so
	-- the two drift apart and the buttons end up behind it -- visible to the mouse, invisible to
	-- the eye. The paging strip is raised the same way, in OnLoad.
	local above = self.IconsFrame:GetFrameLevel() + 1
	for i = 1, buttonsUsed do
		self.buttons[i]:SetFrameLevel(above)
		self.buttons[i]:Show()
		if GameTooltip:IsOwned(self.buttons[i]) then
			self.buttons[i]:OnEnter()
		end
	end
	for i = buttonsUsed + 1, #self.buttons do
		self.buttons[i]:Hide()
	end
	for i = 1, headersUsed do
		self.headers[i]:Show()
	end
	for i = headersUsed + 1, #self.headers do
		self.headers[i]:Hide()
	end
end

--
-- One heirloom
--
HeirloomButtonMixin = {}

function HeirloomButtonMixin:OnLoad()
	self:RegisterForClicks("LeftButtonUp")
	self.SlotFrameCollected:SetAtlas("collections-itemborder-collected")
	self.SlotFrameUncollected:SetAtlas("collections-itemborder-uncollected")
	self.SlotFrameUncollectedInnerGlow:SetAtlas("collections-itemborder-uncollected-innerglow", true)
	self.NewGlow:SetAtlas("collections-newglow")
	self.Favorite:Hide()
end

function HeirloomButtonMixin:Update(itemID)
	self.itemID = itemID
	if not itemID then
		self:Hide()
		return
	end

	self:Show()

	local name, _, _, _, _, _, _, _, _, icon = GetItemInfo(itemID)
	if not name then
		-- The cache has not answered yet. The row says so and the page draws itself again shortly,
		-- which is the first visit after a fresh install and no longer.
		self.heirlooms.waitingForNames = true
		name = RETRIEVING_ITEM_INFO
	end

	local isCollected = C_Heirloom.PlayerHasHeirloom(itemID)
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

	local _, _, _, _, _, isNew = C_Heirloom.GetHeirloomInfo(itemID)
	self.New:SetShown(isNew)
	self.NewGlow:SetShown(isNew)
end

function HeirloomButtonMixin:OnClick()
	if not self.itemID then
		return
	end

	-- Linking and trying one on are about the item and do not need it collected, so they come
	-- before the check that does. The client's own handler is what a click in a bag runs, and this
	-- returns either way: with no chat box open the link goes nowhere, and a click that was meant to
	-- link one must not put it in the bags instead.
	if IsModifiedClick("CHATLINK") or IsModifiedClick("DRESSUP") then
		local link = select(2, GetItemInfo(self.itemID))
		if link then
			HandleModifiedItemClick(link)
		end
		return
	end

	if not C_Heirloom.PlayerHasHeirloom(self.itemID) then
		return
	end
	local owned, limit = C_Heirloom.GetCreationInfo(self.itemID)
	if limit > 0 and owned >= limit then
		self.heirlooms:OnCreateResult(self.itemID, 4)
		return
	end

	C_Heirloom.ClearNewHeirloom(self.itemID)
	C_Heirloom.CreateHeirloom(self.itemID)
end

function HeirloomButtonMixin:OnEnter()
	if not self.itemID then
		return
	end

	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:SetHyperlink("item:" .. self.itemID)

	-- Where it comes from is the catalogue's line, not the item's, and what a click does is worth
	-- saying: nothing on the tile shows it.
	local _, _, _, sourceText, isCollected = C_Heirloom.GetHeirloomInfo(self.itemID)
	if sourceText and sourceText ~= "" then
		GameTooltip:AddLine(sourceText, 1, 1, 1, true)
	end
	if isCollected then
		local owned, limit = C_Heirloom.GetCreationInfo(self.itemID)
		if limit > 0 and owned >= limit then
			GameTooltip:AddLine(HEIRLOOM_CREATE_ERROR_4, 1, 0.2, 0.2, true)
		else
			GameTooltip:AddLine(HEIRLOOM_CREATE_HINT, 0.5, 0.5, 0.5)
		end
	end
	GameTooltip:Show()

	C_Heirloom.ClearNewHeirloom(self.itemID)
	self:Update(self.itemID)
end

function HeirloomButtonMixin:OnLeave()
	GameTooltip:Hide()
end
