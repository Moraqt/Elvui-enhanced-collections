-- The collection toast: the era's achievement alert in shape and timing (AlertFrames.xml), on the
-- Wardrobe's sheet. Retail 7.3.5 has none. Always loaded, one at a time, the rest wait their turn.
--
-- It began as the appearance toast and now speaks for all five collections and for the shop. Each
-- kind answers three questions -- what it is called, what it looks like, and what colour the name is
-- -- and the events it listens on carry one id, so the queue is a kind and an id.

local queue = { };
local waiting = { };

-- An item's name, icon and quality are the client's, out of the cache it fills from the server, and
-- a thing collected a moment ago is exactly the thing the cache is least likely to hold. Asking is
-- what the tab's own info call does, so this asks the same way and waits for REBUFFED_ITEM_CACHED.
local function ItemToast(itemID, ask)
	ask(itemID);
	local name, _, quality, _, _, _, _, _, _, icon = GetItemInfo(itemID);
	if ( not name ) then
		return nil;
	end
	local r, g, b = GetItemQualityColor(quality);
	return name, icon, r, g, b;
end

local function ToyToast(itemID)
	return ItemToast(itemID, C_ToyBox.GetToyInfo);
end

local function HeirloomToast(itemID)
	return ItemToast(itemID, C_Heirloom.GetHeirloomInfo);
end

local KINDS = {
	appearance = {
		event = "TRANSMOG_COLLECTION_SOURCE_ADDED",
		title = "TRANSMOG_APPEARANCE_COLLECTED",
		read = function(sourceID)
			local sourceInfo = C_TransmogCollection.GetSourceInfo(sourceID);
			if ( not sourceInfo ) then
				return nil;
			end
			local r, g, b = GetItemQualityColor(sourceInfo.quality);
			return sourceInfo.name, C_TransmogCollection.GetSourceIcon(sourceID), r, g, b;
		end,
	},
	mount = {
		title = "NEW_MOUNT_COLLECTED",
		ids = function() return C_MountJournal.GetMountIDs() end,
		read = function(spellID)
			local name, _, icon = C_MountJournal.GetMountInfoByID(spellID);
			return name, icon, 1, 1, 1;
		end,
		owns = function(spellID) return select(11, C_MountJournal.GetMountInfoByID(spellID)); end,
	},
	companion = {
		title = "NEW_COMPANION_COLLECTED",
		ids = function() return C_PetJournal.GetPetIDs() end,
		read = function(spellID)
			local name, _, icon = C_PetJournal.GetPetInfoByID(spellID);
			return name, icon, 1, 1, 1;
		end,
		owns = function(spellID) return select(8, C_PetJournal.GetPetInfoByID(spellID)); end,
	},
	toy = {
		event = "NEW_TOY_ADDED",
		title = "NEW_TOY_COLLECTED",
		read = ToyToast,
		waitsForItem = true,
	},
	heirloom = {
		event = "NEW_HEIRLOOM_ADDED",
		title = "NEW_HEIRLOOM_COLLECTED",
		read = HeirloomToast,
		waitsForItem = true,
	},
	-- The shop's, raised by the shop itself once the server confirms a purchase: the id is a
	-- table naming what was bought, its icon, and where it landed as the title.
	purchase = {
		title = function(toast) return toast.title; end,
		read = function(toast) return toast.name, toast.icon, 1, 1, 1; end,
	},
};

local BY_EVENT = { };
for kind, info in pairs(KINDS) do
	if ( info.event ) then
		BY_EVENT[info.event] = kind;
	end
end

-- The mounts and the companions have no event of their own. The era raises COMPANION_LEARNED and
-- says nothing more -- not which one, and not which of the two lists grew -- so what is owned is
-- remembered and the difference is the answer. The extension cannot do this for us: its event bus
-- hooks BroadcastEvent, and COMPANION_LEARNED does not come through there. Measured on this
-- client: a Lua frame registered for it is told, a subscriber inside the extension is not.
local owned = { };

local function Remember(kind)
	local info = KINDS[kind];
	local seen = { };
	for _, id in ipairs(info.ids()) do
		if ( info.owns(id) ) then
			seen[id] = true;
		end
	end
	owned[kind] = seen;
end

local function Announce(kind)
	local info = KINDS[kind];
	local before = owned[kind];
	local seen = { };
	for _, id in ipairs(info.ids()) do
		if ( info.owns(id) ) then
			seen[id] = true;
			if ( before and not before[id] ) then
				CollectionToast_Show(kind, id);
			end
		end
	end
	owned[kind] = seen;
end

function CollectionToast_OnLoad(self)
	self.Background:SetAtlas("transmog-toast-bg", true);
	for _, info in pairs(KINDS) do
		if ( info.event ) then
			self:RegisterEvent(info.event);
		end
	end
	self:RegisterEvent("REBUFFED_ITEM_CACHED");
	self:RegisterEvent("COMPANION_LEARNED");
	self:RegisterEvent("PLAYER_ENTERING_WORLD");
end

-- Above whichever of the era's own alerts is showing (DungeonCompletionAlertFrame_FixAnchors' idiom).
local function FixAnchors(self)
	self:ClearAllPoints();
	if ( DungeonCompletionAlertFrame1:IsShown() ) then
		self:SetPoint("BOTTOM", DungeonCompletionAlertFrame1, "TOP", 0, 10);
		return;
	end
	for i = MAX_ACHIEVEMENT_ALERTS, 1, -1 do
		local frame = _G["AchievementAlertFrame"..i];
		if ( frame and frame:IsShown() ) then
			self:SetPoint("BOTTOM", frame, "TOP", 0, 10);
			return;
		end
	end
	self:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 128);
end

function CollectionToast_OnEvent(self, event, id)
	if ( event == "PLAYER_ENTERING_WORLD" ) then
		-- Everything is new to a record that has none yet, so the first pass only remembers.
		Remember("mount");
		Remember("companion");
		return;
	end
	if ( event == "COMPANION_LEARNED" ) then
		Announce("mount");
		Announce("companion");
		return;
	end
	if ( event == "REBUFFED_ITEM_CACHED" ) then
		local kind = waiting[id];
		if ( kind ) then
			waiting[id] = nil;
			CollectionToast_Show(kind, id);
		end
		return;
	end
	CollectionToast_Show(BY_EVENT[event], id);
end

function CollectionToast_Show(kind, id)
	local info = KINDS[kind];
	if ( not info ) then
		return;
	end
	if ( CollectionToast:IsShown() ) then
		tinsert(queue, { kind = kind, id = id });
		return;
	end
	local name, icon, r, g, b = info.read(id);
	if ( not name ) then
		-- An item kind's read asked the cache for it, and REBUFFED_ITEM_CACHED brings us back
		-- here. A mount or a companion is read out of the client's own list, so there is nothing
		-- to wait for and nothing to say.
		if ( info.waitsForItem ) then
			waiting[id] = kind;
		end
		return;
	end
	CollectionToast.Title:SetText(type(info.title) == "function" and info.title(id) or _G[info.title]);
	CollectionToast.Icon:SetTexture(icon);
	CollectionToast.Name:SetText(name);
	CollectionToast.Name:SetTextColor(r, g, b);
	FixAnchors(CollectionToast);
	CollectionToast:Show();
	CollectionToast.animIn:Play();
	CollectionToast.waitAndAnimOut:Stop();
	CollectionToast.waitAndAnimOut:Play();
end

function CollectionToast_OnHide(self)
	if ( queue[1] ) then
		CollectionToastQueue:Show();
	end
end

function CollectionToastQueue_OnUpdate(self)
	self:Hide();
	local next = tremove(queue, 1);
	CollectionToast_Show(next.kind, next.id);
end
