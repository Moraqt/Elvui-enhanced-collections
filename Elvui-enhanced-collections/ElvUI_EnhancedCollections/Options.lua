local E = unpack(ElvUI)
local A = ElvUIEnhancedCollections

function A:InsertOptions()
    E.Options.args.enhancedCollections = {
        type = "group", name = "Collections", order = 100,
        get = function(info) return A:DB()[info[#info]] end,
        set = function(info, value) A:DB()[info[#info]] = value; A:Refresh() end,
        args = {
            title = { type = "header", name = "Enhanced Collections", order = 1 },
            description = { type = "description", order = 2,
                name = "ElvUI styling for Whitemane/Rebuffed mounts, companions, toys, heirlooms and appearances. Collection actions remain controlled by the client." },
            enabled = { type = "toggle", name = "Enable skin", order = 3,
                set = function(info, value) A:DB().enabled = value; E:StaticPopup_Show("PRIVATE_RL") end },
            font = { type = "select", dialogControl = "LSM30_Font", name = "Font", order = 4,
                values = AceGUIWidgetLSMlists.font },
            fontSize = { type = "range", name = "Base font size", order = 5, min = 10, max = 16, step = 1 },
            fontOutline = { type = "select", name = "Font outline", order = 6,
                values = { [""] = "None", OUTLINE = "Outline", THICKOUTLINE = "Thick outline" } },
            opacity = { type = "range", name = "Panel opacity", order = 7, min = 0.75, max = 1, step = 0.05 },
            uncollectedAlpha = { type = "range", name = "Uncollected icon brightness", order = 8, min = 0.18, max = 0.65, step = 0.01 },
            refresh = { type = "execute", name = "Refresh skin", order = 9, func = function() A:Refresh() end },
        },
    }
end

SLASH_ENHANCEDCOLLECTIONS1 = "/eccollections"
SlashCmdList.ENHANCEDCOLLECTIONS = function()
    local dialog = E.Libs.AceConfigDialog
    if not (dialog and dialog.OpenFrames and dialog.OpenFrames.ElvUI) then E:ToggleOptionsUI() end
    dialog = E.Libs.AceConfigDialog
    if dialog and dialog.OpenFrames and dialog.OpenFrames.ElvUI then
        dialog:SelectGroup("ElvUI", "enhancedCollections")
    end
end
