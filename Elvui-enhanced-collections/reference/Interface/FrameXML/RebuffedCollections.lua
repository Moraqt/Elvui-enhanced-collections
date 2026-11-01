-- Built-in Collections and Wardrobe entry points.

UIPanelWindows["CollectionsJournal"] = { area = "left", pushable = 0, whileDead = 1 }
UIPanelWindows["WardrobeFrame"] = { area = "left", pushable = 0, width = 965 }

function Collections_LoadUI()
	assert(CollectionsJournal and WardrobeCollectionFrame, "Rebuffed Collections did not initialize")
	if not CollectionsJournal.wardrobeTabID then
		CollectionsJournal.wardrobeTabID = CollectionsJournal:AddTab(WARDROBE, WardrobeCollectionFrame):GetTabID()
	end
end

function ToggleCollections()
	Collections_LoadUI()
	if CollectionsJournal then
		ToggleFrame(CollectionsJournal)
	end
end

SLASH_COLLECTIONS1 = "/collections"
SlashCmdList["COLLECTIONS"] = function()
	ToggleCollections()
end

-- A mount and a companion are spells on this client, so a link to one carries the spell id -- which
-- is also the id the journals key on, and which is what retail's own mount link leads with. The type
-- is its own so that a click shows what the collection knows about the thing, its source and its
-- description, rather than the spell's tooltip. The server takes these two the way it takes a spell
-- link, so they survive a trip through the chat.
function CollectionLink(linkType, id, name)
	return format("|cff71d5ff|H%s:%d|h[%s]|h|r", linkType, id, name)
end

local function CollectionLinkInfo(linkType, id)
	if linkType == "mount" then
		local name = C_MountJournal.GetMountInfoByID(id)
		local _, description, source = C_MountJournal.GetMountInfoExtraByID(id)
		return name, source, description
	end
	local name = C_PetJournal.GetPetInfoByID(id)
	local _, description, source = C_PetJournal.GetPetInfoExtraByID(id)
	return name, source, description
end

local function ShowCollectionLink(linkType, id)
	local name, source, description = CollectionLinkInfo(linkType, id)
	if not name then
		return
	end

	ShowUIPanel(ItemRefTooltip)
	if not ItemRefTooltip:IsShown() then
		ItemRefTooltip:SetOwner(UIParent, "ANCHOR_PRESERVE")
	end
	ItemRefTooltip:ClearLines()
	ItemRefTooltip:AddLine(name, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
	if source and source ~= "" then
		ItemRefTooltip:AddLine(source, 1, 1, 1, true)
	end
	if description and description ~= "" then
		ItemRefTooltip:AddLine(description, 1, 1, 1, true)
	end
	ItemRefTooltip:Show()
end

-- A transmogappearance: or transmogset: link opens the Appearances tab on it; a modified click on
-- an appearance link is the item link's modified click. ItemRef.lua loads after this file, so the
-- stock SetItemRef is wrapped at PLAYER_LOGIN.
local function WrapSetItemRef()
	local origSetItemRef = SetItemRef
	function SetItemRef(link, text, button, chatFrame)
		local linkType, id = strsplit(":", link)
		if linkType == "mount" or linkType == "battlepet" then
			-- Passing a link on is what every other link does with a modified click, and the
			-- caption already carries the brackets.
			if IsModifiedClick("CHATLINK") then
				ChatEdit_InsertLink("|cff71d5ff|H" .. link .. "|h" .. text .. "|h|r")
			else
				ShowCollectionLink(linkType, tonumber(id))
			end
			return
		end
		if linkType == "transmogappearance" or linkType == "transmogset" then
			if linkType == "transmogappearance" and IsModifiedClick("CHATLINK") then
				local itemLink = select(6, C_TransmogCollection.GetAppearanceSourceInfo(tonumber(id)))
				if itemLink then
					HandleModifiedItemClick(itemLink)
				end
			else
				Collections_LoadUI()
				WardrobeCollectionFrame_OpenTransmogLink(link)
			end
			return
		end
		return origSetItemRef(link, text, button, chatFrame)
	end
end

local glue = CreateFrame("Frame")
glue:RegisterEvent("PLAYER_LOGIN")
glue:RegisterEvent("TRANSMOGRIFY_OPEN")
glue:RegisterEvent("TRANSMOGRIFY_CLOSE")
glue:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_LOGIN" then
		Collections_LoadUI()
		WrapSetItemRef()
	elseif event == "TRANSMOGRIFY_OPEN" then
		Collections_LoadUI()
		ShowUIPanel(WardrobeFrame)
		-- The extension and the server count the window open from this event on, and take every
		-- later message from the same transmogrifier for that window being told again -- which
		-- opens nothing. So a window that did not come up here is closed at once, and the next
		-- click at the NPC is a new window.
		if ( not WardrobeFrame or not WardrobeFrame:IsShown() ) then
			C_Transmog.Close()
		end
	elseif event == "TRANSMOGRIFY_CLOSE" then
		if WardrobeFrame then
			HideUIPanel(WardrobeFrame)
		end
	end
end)
