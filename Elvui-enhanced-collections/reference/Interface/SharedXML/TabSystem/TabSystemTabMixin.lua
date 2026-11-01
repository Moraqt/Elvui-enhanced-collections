TabSystemTabMixin = {}

function TabSystemTabMixin:Init(tabID, text)
	self:SetTabID(tabID)
	self.tabText = text
	self:SetTabText(text)
end

function TabSystemTabMixin:SetTooltipAnchor(anchor)
	self.tooltipAnchor = anchor
end

function TabSystemTabMixin:SetTabSelected(selected)
	if self.isSelected and not selected then
		self:OnDeselected()
	elseif not self.isSelected and selected then
		self:OnSelected()
	end
	self:SetEnabled(not selected and not self.forceDisabled)
	self.isSelected = selected
	self:SetChecked(selected)
	local tooltip = GameTooltip or GlueTooltip
	if tooltip:IsOwned(self) then
		tooltip:Hide()
	end
	if self.UpdateButton then
		self:UpdateButton()
	end
end

function TabSystemTabMixin:SetTabText(text)
	self.Text:SetText(text)
	self:UpdateWidth()
end

function TabSystemTabMixin:SetTabEnabled(enabled, reason)
	self.forceDisabled = not enabled
	self:SetEnabled(enabled)
	if not enabled then
		self.isSelected = false
		self:SetChecked(false)
	end
	local text = enabled and self.tabText or DISABLED_FONT_COLOR:WrapText(self.tabText)
	self:SetTabText(text)
	if not enabled then
		if reason then
			self.tooltipTitle = RED_FONT_COLOR:WrapText(reason)
			self:SetTooltip(reason)
		end
	else
		self.tooltipTitle = self.internalTooltipTitle
	end
	if self.UpdateButton then
		self:UpdateButton()
	end
end

function TabSystemTabMixin:IsTabEnabled()
	return not self.forceDisabled
end

function TabSystemTabMixin:SetTooltip(title, ...)
	self.internalTooltipTitle = not self.forceDisabled and title
	self.tooltipTitle = title
	local tooltipText = ...
	if type(tooltipText) == "function" then
		self.tooltipText = tooltipText
	else
		self.tooltipText = { ... }
	end
end

function TabSystemTabMixin:OnEnter()
	if self.tooltipTitle then
		GameTooltip:SetOwner(self, self.tooltipAnchor or "ANCHOR_RIGHT")
		if type(self.tooltipTitle) == "function" then
			GameTooltip:SetText(self.tooltipTitle(), 1, 1, 1)
		else
			GameTooltip:SetText(self.tooltipTitle, 1, 1, 1)
		end

		if self.tooltipText and self:IsTabEnabled() then
			local tooltipText
			if type(self.tooltipText) == "function" then
				tooltipText = { self.tooltipText() }
			else
				tooltipText = self.tooltipText
			end
			for i, text in ipairs(self.tooltipText) do
				GameTooltip:AddLine(text, nil, nil, nil, true)
			end
		end

		GameTooltip:Show()
	end
end

function TabSystemTabMixin:OnLeave()
	GameTooltip:Hide()
end

function TabSystemTabMixin:OnShow()
	self:UpdateWidth()
end

function TabSystemTabMixin:SetTextPadding(value)
	self.textPadding = value
	if self:IsShown() then
		self:UpdateWidth()
	end
end

function TabSystemTabMixin:UpdateWidth()
	local sidesWidth
	if self.leftAtlasInfo and self.rightAtlasInfo then
		sidesWidth = (self.leftAtlasInfo.width + self.rightAtlasInfo.width) / 2
	else
		sidesWidth = 0
	end

	local width = sidesWidth + self.Text:GetWidth() + (self.textPadding and self.textPadding or 0)
	local minTabWidth, maxTabWidth = self:GetTabSystem():GetTabWidthConstraints()
	local textWidth

	if maxTabWidth and width > maxTabWidth then
		width = maxTabWidth;
		textWidth = width - 10
	elseif minTabWidth and width < minTabWidth then
		width = minTabWidth
		textWidth = width - 10
	end

	self:SetWidth(width)
end

function TabSystemTabMixin:GetTabSystem()
	return self.tabSystem or self:GetParent()
end

function TabSystemTabMixin:SetTabSystem(tabSystem)
	self.tabSystem = tabSystem
end

function TabSystemTabMixin:SetTabID(tabID)
	self.tabID = tabID
end

function TabSystemTabMixin:GetTabID()
	return self.tabID
end

function TabSystemTabMixin:OnClick()
	self:GetTabSystem():SelectTab(self)
end

function TabSystemTabMixin:SetPreClick(callback)
	self.preClick = callback
end

TabSystemTabMixin.OnSelected = nop
TabSystemTabMixin.OnDeselected = nop