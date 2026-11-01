-- Keep the native achievement panel and its progress widgets. Collection counters
-- need a localized label as well: unlike stock single-bar achievements, one
-- achievement may contain several unrelated account collection counters.
local loader = CreateFrame("Frame");
loader:RegisterEvent("ADDON_LOADED");
loader:SetScript("OnEvent", function(self, event, name)
    if name ~= "Blizzard_AchievementUI" then return; end
    self:UnregisterEvent("ADDON_LOADED");

    local display = AchievementObjectives_DisplayCriteria;
    local resized = {};
    AchievementObjectives_DisplayCriteria = function(frame, achievementID)
        -- Widgets are pooled by Blizzard; restore them before any stock row uses them.
        for bar, size in pairs(resized) do
            bar:SetWidth(size[1]);
            bar:SetHeight(size[2]);
            bar.text:SetWidth(0); -- Blizzard's template uses automatic text width.
            resized[bar] = nil;
        end
        display(frame, achievementID);
        if not achievementID then return; end

        local index, extraHeight = 0, 0;
        for i = 1, GetAchievementNumCriteria(achievementID) do
            local description, kind, completed, count, goal, character, flags, asset, quantity =
                GetAchievementCriteriaInfo(achievementID, i);
            if kind ~= CRITERIA_TYPE_ACHIEVEMENT and
                bit.band(flags, ACHIEVEMENT_CRITERIA_PROGRESS_BAR) ~= 0 then
                index = index + 1;
                if kind >= 124 and kind <= 128 then
                    local bar = AchievementButton_GetProgressBar(index);
                    local width, height = bar:GetWidth(), bar:GetHeight();
                    resized[bar] = {width, height};
                    bar:SetWidth(ACHIEVEMENTUI_MAXCONTENTWIDTH);
                    bar.text:SetWidth(ACHIEVEMENTUI_MAXCONTENTWIDTH - 12);
                    bar.text:SetText(description .. "\n" .. quantity);
                    local newHeight = math.max(height, bar.text:GetStringHeight() + 8);
                    bar:SetHeight(newHeight);
                    extraHeight = extraHeight + newHeight - height;
                end
            end
        end
        frame:SetHeight(frame:GetHeight() + extraHeight);
    end
end);
