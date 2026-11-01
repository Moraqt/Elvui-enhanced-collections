-- Pieces every collection page shares, from retail's Blizzard_CollectionTemplates.lua.
--
-- They were the wardrobe's until the toy box needed them as well, and the wardrobe addon loads
-- after this one, so they live here where both can reach them.

-- The paging strip of a collection page (7.3.5's Blizzard_CollectionTemplates.lua:135-202).
CollectionsPagingMixin = { };

function CollectionsPagingMixin:OnLoad()
	self.currentPage = 1;
	self.maxPages = 1;
	self:Update();
	-- The era's XML loader builds Layers before Frames, so PageText cannot name the button in XML.
	self.PageText:SetPoint("RIGHT", self.PrevPageButton, "LEFT", -11, 0);
end

function CollectionsPagingMixin:SetMaxPages(maxPages)
	maxPages = math.max(maxPages, 1);
	if ( self.maxPages == maxPages ) then
		return;
	end
	self.maxPages= maxPages;
	if ( self.maxPages < self.currentPage ) then
		self.currentPage = self.maxPages;
	end
	self:Update();
end

function CollectionsPagingMixin:SetCurrentPage(page, userAction)
	page = Clamp(page, 1, self.maxPages);
	if ( self.currentPage ~= page ) then
		self.currentPage = page;
		self:Update();
		if ( self:GetParent().OnPageChanged ) then
			self:GetParent():OnPageChanged(userAction);
		end
	end
end

function CollectionsPagingMixin:GetCurrentPage()
	return self.currentPage;
end

function CollectionsPagingMixin:NextPage()
	self:SetCurrentPage(self.currentPage + 1, true);
end

function CollectionsPagingMixin:PreviousPage()
	self:SetCurrentPage(self.currentPage - 1, true);
end

function CollectionsPagingMixin:OnMouseWheel(delta)
	if ( delta > 0 ) then
		self:PreviousPage();
	else
		self:NextPage();
	end
end

function CollectionsPagingMixin:Update()
	self.PageText:SetFormattedText(COLLECTION_PAGE_NUMBER, self.currentPage, self.maxPages);
	if ( self.currentPage <= 1 ) then
		self.PrevPageButton:Disable();
	else
		self.PrevPageButton:Enable();
	end
	if ( self.currentPage >= self.maxPages ) then
		self.NextPageButton:Disable();
	else
		self.NextPageButton:Enable();
	end
end

-- The bar over every collection page: how many of the tab's things the account has. Retail draws
-- one on the toy box and the heirlooms; the mount and companion pages had a bare "Collected N of M"
-- line instead, and the four tabs now read the same.
CollectionsProgressBarMixin = { };

function CollectionsProgressBarMixin:SetProgress(collected, total)
	self:SetMinMaxValues(0, total);
	self:SetValue(collected);
	self.text:SetFormattedText("%d/%d", collected, total);
end
