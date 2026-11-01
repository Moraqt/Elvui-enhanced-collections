BorderIconTemplateMixin = {}

function BorderIconTemplateMixin:SetRounded(rounded)
	self.rounded = rounded
	if not self.iconTexture then return end
	if rounded then
		self.Icon:SetPortraitTexture(self.iconTexture)
	else
		self.Icon:SetTexture(self.iconTexture)
	end
end

function BorderIconTemplateMixin:SetIcon(icon)
	if not icon or icon:len() == 0 then
		self.icon = nil
		self.Icon:SetTexture(nil)
		self.IconBorder:SetTexture(nil)
		return
	end

	self.Icon:SetTexCoord(0, 1, 0, 1)
	self.iconTexture = icon
	if self.rounded then
		self.Icon:SetPortraitTexture(icon)
	else
		self.Icon:SetTexture(icon)
	end
end 

function BorderIconTemplateMixin:SetIconAtlas(atlas, useAtlasSize)
	self.iconTexture = nil
	self.Icon:SetAtlas(atlas, useAtlasSize)
end

function BorderIconTemplateMixin:GetIcon()
	return self.Icon:GetTexture()
end

function BorderIconTemplateMixin:SetIconDesaturated(desaturated)
	self.Icon:SetDesaturated(desaturated)
end

function BorderIconTemplateMixin:SetIconColor(r, g, b, a)
	self.Icon:SetVertexColor(r, g, b, a)
end

function BorderIconTemplateMixin:SetIconBlendMode(blendMode)
	self.Icon:SetBlendMode(blendMode)
end

function BorderIconTemplateMixin:SetBorderTexture(texture)
	self.IconBorder:SetTexture(texture)
	self.IconBorder:SetTexCoord(0, 1, 0, 1)
end

function BorderIconTemplateMixin:SetBorderAtlas(atlas, useAtlasSize)
	self.IconBorder:SetAtlas(atlas, useAtlasSize)
end

function BorderIconTemplateMixin:SetBorderDesaturated(desaturated)
	self.IconBorder:SetDesaturated(desaturated)
end

function BorderIconTemplateMixin:SetBorderColor(r, g, b, a)
	self.IconBorder:SetVertexColor(r, g, b, a)
end

function BorderIconTemplateMixin:SetBorderBlendMode(blendMode)
	self.IconBorder:SetBlendMode(blendMode)
end

function BorderIconTemplateMixin:SetOverlayTexture(texture)
	self.Overlay:SetTexture(texture)
	self.Overlay:SetTexCoord(0, 1, 0, 1)
end

function BorderIconTemplateMixin:SetOverlayAtlas(atlas, useAtlasSize)
	self.Overlay:SetAtlas(atlas, useAtlasSize)
end

function BorderIconTemplateMixin:SetOverlayDesaturated(desaturated)
	self.Overlay:SetDesaturated(desaturated)
end

function BorderIconTemplateMixin:SetOverlayColor(r, g, b, a)
	self.Overlay:SetVertexColor(r, g, b, a)
end

function BorderIconTemplateMixin:SetOverlayBlendMode(blendMode)
	self.Overlay:SetBlendMode(blendMode)
end

function BorderIconTemplateMixin:SetBackgroundTexture(texture)
	self.Background:SetTexture(texture)
	self.Background:SetTexCoord(0, 1, 0, 1)
end

function BorderIconTemplateMixin:SetBackgroundAtlas(atlas, useAtlasSize)
	self.Background:SetAtlas(atlas, useAtlasSize)
end

function BorderIconTemplateMixin:SetBackgroundDesaturated(desaturated)
	self.Background:SetDesaturated(desaturated)
end

function BorderIconTemplateMixin:SetBackgroundColor(r, g, b, a)
	self.Background:SetVertexColor(r, g, b, a)
end

function BorderIconTemplateMixin:SetBackgroundBlendMode(blendMode)
	self.Background:SetBlendMode(blendMode)
end

function BorderIconTemplateMixin:SetBorderSize(width, height)
	self.IconBorder:ClearAndSetPoint("CENTER", self.Icon, "CENTER", self:GetAttribute("borderOffsetX") or 0, self:GetAttribute("borderOffsetY") or 0)
	self.IconBorder:SetSize(width, height)
end

function BorderIconTemplateMixin:SetBorderOffset(x, y)
	self:SetAttribute("borderOffsetX", x)
	self:SetAttribute("borderOffsetY", y)
	self.IconBorder:SetSize(self.IconBorder:GetSize())
	self.IconBorder:ClearAndSetPoint("CENTER", self.Icon, "CENTER", x, y)
end

function BorderIconTemplateMixin:SetOverlaySize(width, height)
	self.Overlay:ClearAndSetPoint("CENTER", self.Icon, "CENTER", self:GetAttribute("overlayOffsetX") or 0, self:GetAttribute("overlayOffsetY") or 0)
	self.Overlay:SetSize(width, height)
end

function BorderIconTemplateMixin:SetOverlayOffset(x, y)
	self:SetAttribute("overlayOffsetX", x)
	self:SetAttribute("overlayOffsetY", y)
	self.Overlay:SetSize(self.Overlay:GetSize())
	self.Overlay:ClearAndSetPoint("CENTER", self.Icon, "CENTER", x, y)
end

function BorderIconTemplateMixin:SetBackgroundSize(width, height)
	self.Background:ClearAndSetPoint("CENTER", self.Icon, "CENTER", self:GetAttribute("backgroundOffsetX") or 0, self:GetAttribute("backgroundOffsetY") or 0)
	self.Background:SetSize(width, height)
end

function BorderIconTemplateMixin:SetBackgroundOffset(x, y)
	self:SetAttribute("backgroundOffsetX", x)
	self:SetAttribute("backgroundOffsetY", y)
	self.Background:SetSize(self.Background:GetSize())
	self.Background:ClearAndSetPoint("CENTER", self.Icon, "CENTER", x, y)
end

function BorderIconTemplateMixin:SetIconDesaturated(desaturated)
	self.Icon:SetDesaturated(desaturated)
end

function BorderIconTemplateMixin:SetBorderDesaturated(desaturated)
	self.IconBorder:SetDesaturated(desaturated)
end

function BorderIconTemplateMixin:SetOverlayDesaturated(desaturated)
	self.Overlay:SetDesaturated(desaturated)
end

function BorderIconTemplateMixin:SetOverlayAlpha(alpha)
	self.Overlay:SetAlpha(alpha)
end

function BorderIconTemplateMixin:SetBorderAlpha(alpha)
	self.IconBorder:SetAlpha(alpha)
end

function BorderIconTemplateMixin:SetBackgroundAlpha(alpha)
	self.Background:SetAlpha(alpha)
end

function BorderIconTemplateMixin:SetDesaturated(desaturated)
	self:SetIconDesaturated(desaturated)
	self:SetBorderDesaturated(desaturated)
	self:SetOverlayDesaturated(desaturated)
end

SpellIconTemplateMixin = CreateFromMixins(BorderIconTemplateMixin, CallbackRegistryMixin)

function SpellIconTemplateMixin:OnLoad()
	CallbackRegistryMixin.OnLoad(self)
	self:GenerateCallbackEvents({ "OnSpellChanged" })
end

function SpellIconTemplateMixin:SetSpell(spellID)
	if not spellID or spellID <= 0 then
		self.spell = nil
		self:SetIcon()
		return
	end

	self.spell = Spell:CreateFromID(spellID)
	self:SetIcon(select(3, GetSpellInfo(spellID)))
	if self.useQuality then
		local quality = C_CharacterAdvancement.GetQualityInfo(self.spell.spellID)
		self:SetQuality(quality)
	end

	if GameTooltip:IsOwned(self) then
		self:OnEnter()
	end

	self:TriggerEvent("OnSpellChanged", self.spell)
end

function SpellIconTemplateMixin:SetQuality(quality)
	if quality and quality > Enum.SpellQuality.Common then
		local atlas = QUICKSLOT_QUALITY_BORDER_ATLAS[quality]
		self:SetBorderAtlas(atlas)
		self:SetOverlayAtlas(atlas)
	else
		local atlas = QUICKSLOT_QUALITY_BORDER_ATLAS[Enum.SpellQuality.Poor]
		self:SetBorderAtlas(atlas)
		self:SetOverlayAtlas(nil)
	end
end

function SpellIconTemplateMixin:OnEnter()
	if self.spell then
		local tooltip = GameTooltip or GlueTooltip
		tooltip:SetOwner(self, "ANCHOR_RIGHT")
		tooltip:SetHyperlink("spell:" .. self.spell.spellID)
	else
		GameTooltip_GenericTooltip(self)
	end
end 

function SpellIconTemplateMixin:OnLeave()
	local tooltip = GameTooltip or GlueTooltip
	tooltip:Hide()
end

function SpellIconTemplateMixin:OnClick()
	if self.spell then
		if IsModifiedClick("CHATLINK") then
			local link = GetSpellLink(self.spell.spellID)
			if link then
				ChatEdit_InsertLink(link)
			end
		elseif self.OnClickHandler then
			self:OnClickHandler()
		end
	end
end

function SpellIconTemplateMixin:OnDragStart()
	if self.DragEnabled and self.spell.spellID then
		local spellName = GetSpellInfo(self.spell.spellID)
		if spellName then
			PickupSpell(spellName)
		end
	end
end

function SpellIconTemplateMixin:EnableDrag()
	self:RegisterForDrag("LeftButton")
	self.DragEnabled = true
end

function SpellIconTemplateMixin:DisableDrag()
	self:RegisterForDrag()
	self.DragEnabled = nil
end

function SpellIconTemplateMixin:UseQuality(useQuality)
	self.useQuality = useQuality
	if useQuality then
		self:SetOverlayBlendMode("ADD")
	end

	if self.spell and self:IsVisible() then
		self:SetSpell(self.spell.spellID)
	end
end

ItemIconTemplateMixin = CreateFromMixins(BorderIconTemplateMixin, CallbackRegistryMixin)

function ItemIconTemplateMixin:OnLoad()
	CallbackRegistryMixin.OnLoad(self)
	self:GenerateCallbackEvents({ "OnItemChanged" })
end

function ItemIconTemplateMixin:SetCount(amount)
	if not amount or amount <= 1 then
		self.Count:SetText("")
	else
		self.Count:SetText(amount)
	end
end

function ItemIconTemplateMixin:SetItem(itemID, amount)
	-- Whatever the last item was waiting for, nobody is looking at the answer any more.
	if self.cancelItemLoad then
		self.cancelItemLoad()
		self.cancelItemLoad = nil
	end

	self:SetCount(amount)
	if not itemID or itemID <= 0 then
		self.item = nil
		self:SetIcon()
		self:SetCount()
		return
	end

	self.item = Item:CreateFromID(itemID)
	self:SetIcon(self.item:GetIcon())

	-- A cold item has no icon yet, and asking the cache is what brings one. The handle is kept so
	-- that replacing or clearing the item before the answer lands cannot paint the wrong icon.
	if not self.item:IsItemDataCached() then
		local item = self.item
		self.cancelItemLoad = item:CancelableContinueOnLoad(function()
			if self.item == item then
				self:SetIcon(item:GetIcon())
				if self:IsMouseOver() then self:OnEnter() end
			end
		end)
	end

	if self:IsMouseOver() then
		self:OnEnter()
	end
	self:TriggerEvent("OnItemChanged", self.item)
end

function ItemIconTemplateMixin:OnEnter()
	if self.item then
		local tooltip = GameTooltip or GlueTooltip
		tooltip:SetOwner(self, "ANCHOR_RIGHT")
		tooltip:SetHyperlink("item:" .. self.item.itemID)
	else
		GameTooltip_GenericTooltip(self)
	end
end

function ItemIconTemplateMixin:OnLeave()
	local tooltip = GameTooltip or GlueTooltip
	tooltip:Hide()
end

function ItemIconTemplateMixin:OnClick()
	if self.item then
		if IsModifiedClick("CHATLINK") then
			local link = GetItemLink(self.item.itemID)
			if link then
				ChatEdit_InsertLink(link)
			end
		elseif self.OnClickHandler then
			self:OnClickHandler()
		end
	end
end

CooldownItemIconTemplateMixin = CreateFromMixins(ItemIconTemplateMixin)

function CooldownItemIconTemplateMixin:OnLoad()
	ItemIconTemplateMixin.OnLoad(self)
end

function CooldownItemIconTemplateMixin:SetItem(itemID, amount)
	ItemIconTemplateMixin.SetItem(self, itemID, amount)
	if self:IsShown() then
		self:RegisterEvent("SPELL_UPDATE_COOLDOWN")
		self:RegisterEvent("BAG_UPDATE_COOLDOWN")
		self:UpdateCooldown()
	end
end

function CooldownItemIconTemplateMixin:OnShow()
	if not self.item then return end
	self:RegisterEvent("SPELL_UPDATE_COOLDOWN")
	self:RegisterEvent("BAG_UPDATE_COOLDOWN")
	self:UpdateCooldown()
end

function CooldownItemIconTemplateMixin:OnHide()
	self:UnregisterEvent("SPELL_UPDATE_COOLDOWN")
	self:UnregisterEvent("BAG_UPDATE_COOLDOWN")
end

function CooldownItemIconTemplateMixin:OnEvent()
	self:UpdateCooldown()
end

function CooldownItemIconTemplateMixin:UpdateCooldown()
	if not self.item then
		return self.Cooldown:Hide()
	end
	local start, duration, enable = GetItemCooldown(self.item:GetItemID())
	if start and start > 0 and duration and duration > 0 and enable and enable > 0 then
		self.Cooldown:SetCooldown(start, duration)
		self.Cooldown:Show()
	else
		self.Cooldown:Hide()
	end
end 