-- Minimal WoW 3.3.5 UI model for exercising the companion with the real core.
local frames, nodes = {}, {}
Mock = { frames = frames, nodes = nodes, commands = {}, writes = {}, messages = {}, categories = {} }
SlashCmdList, UISpecialFrames, StaticPopupDialogs = {}, {}, {}
YES, CANCEL, STANDARD_TEXT_FONT = "Yes", "Cancel", "Fonts\\FRIZQT__.TTF"
LibStub = function()
    return { Fetch = function() return "Interface\\AddOns\\ElvUI\\Media\\Fonts\\Expressway.ttf" end }
end

local Node = {}
Node.__index = Node
local function newNode(kind, name, parent)
    local node = setmetatable({ kind = kind, name = name, parent = parent, shown = true,
        enabled = true, scripts = {}, points = {}, width = 0, height = 0, children = {} }, Node)
    nodes[#nodes + 1] = node
    node.index = #nodes
    if parent then parent.children[#parent.children + 1] = node end
    if name then _G[name] = node end
    return node
end
function CreateFrame(kind, name, parent)
    local frame = newNode(kind, name, parent)
    frames[#frames + 1] = frame
    return frame
end
function Node:SetSize(w, h) self.width, self.height = w, h end
function Node:SetWidth(w) self.width = w end
function Node:SetHeight(h) self.height = h end
function Node:GetWidth() return self.width end
function Node:GetHeight() return self.height end
function Node:SetPoint(point, relative, relativePoint, x, y)
    if type(relative) == "number" then
        x, y, relative, relativePoint = relative, relativePoint, self.parent, point
    elseif relative == nil then
        relative, relativePoint, x, y = self.parent, point, 0, 0
    else
        relativePoint, x, y = relativePoint or point, x or 0, y or 0
    end
    self.points[#self.points + 1] = { point, relative, relativePoint, x, y }
end
function Node:ClearAllPoints() self.points = {} end
function Node:SetAllPoints(relative) self.allPoints = relative or self.parent end
function Node:SetScript(name, callback) self.scripts[name] = callback end
function Node:GetScript(name) return self.scripts[name] end
function Node:RegisterEvent(event) self.event = event end
function Node:UnregisterEvent() self.event = nil end
function Node:CreateFontString(name) return newNode("FontString", name, self) end
function Node:CreateTexture(name, layer)
    local texture = newNode("Texture", name, self)
    texture.layer = layer
    return texture
end
function Node:SetText(value)
    self.text = tostring(value)
    if self.kind == "EditBox" and self.scripts.OnTextChanged then self.scripts.OnTextChanged(self, false) end
end
function Node:GetText() return self.text or "" end
function Node:SetFont(path, size, outline) self.font, self.fontSize, self.fontOutline = path, size, outline end
function Node:SetTextColor(...) self.textColor = {...} end
function Node:SetJustifyH(value) self.justifyH = value end
function Node:SetJustifyV(value) self.justifyV = value end
function Node:SetBackdrop(value) self.backdrop = value end
function Node:SetBackdropColor(...) self.backdropColor = {...} end
function Node:SetBackdropBorderColor(...) self.borderColor = {...} end
function Node:SetTexture(...) self.texture = {...} end
function Node:SetVertexColor(...) self.vertexColor = {...} end
function Node:SetCheckedTexture(texture) self.checkedTexture = texture end
function Node:SetChecked(value) self.checked = value and true or false end
function Node:GetChecked() return self.checked end
function Node:SetAlpha(value) self.alpha = value end
function Node:Enable()
    self.enabled = true
    if self.scripts.OnEnable then self.scripts.OnEnable(self) end
end
function Node:Disable()
    self.enabled = false
    if self.scripts.OnDisable then self.scripts.OnDisable(self) end
end
function Node:SetMinMaxValues(lower, upper)
    self.lower, self.upper = lower, upper
    if self.value then self:SetValue(self.value) end
end
function Node:GetMinMaxValues() return self.lower or 0, self.upper or 1 end
function Node:SetValueStep(step) self.step = step end
function Node:SetValue(value)
    value = math.max(self.lower or 0, math.min(self.upper or 1, value))
    if self.value ~= value then
        self.value = value
        if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, value) end
    end
end
function Node:GetValue() return self.value or self.lower or 0 end
function Node:SetThumbTexture(path)
    self.thumb = self:CreateTexture(nil, "OVERLAY")
    self.thumb:SetTexture(path)
end
function Node:GetThumbTexture() return self.thumb end
function Node:SetFocus() self.focus = true end
function Node:ClearFocus() self.focus = false end
function Node:Show()
    local previous = self.shown
    self.shown = true
    if not previous and self.scripts.OnShow then self.scripts.OnShow(self) end
end
function Node:Hide()
    local previous = self.shown
    self.shown = false
    if previous and self.scripts.OnHide then self.scripts.OnHide(self) end
end
function Node:IsShown() return self.shown end
function Node:IsVisible()
    return self.shown and (not self.parent or self.parent:IsVisible())
end
function Node:GetNumChildren() return #self.children end
function Node:GetChildren() return unpack(self.children) end
function Node:SetScale(value) self.scale = value end
function Node:GetScale() return self.scale or 1 end
function Node:GetCenter() return self.centerX or 0, self.centerY or 0 end
function Node:GetStringWidth() return #self:GetText() * (self.fontSize or 12) * 0.55 end
function Node:GetAlpha() return self.alpha or 1 end
function Node:GetName() return self.name end
function Node:GetParent() return self.parent end
function Node:GetNumPoints() return #self.points end
function Node:GetPoint(index) return unpack(self.points[index]) end
function Node:SetStatusBarColor(...) self.statusColor = {...} end
function Node:SetStatusBarTexture(value) self.statusTexture = value end
function Node:SetFrameLevel(value) self.frameLevel = value end
function Node:StartMoving() end
function Node:StopMovingOrSizing() end
function Node:SetFrameStrata() end
function Node:SetClampedToScreen() end
function Node:SetMovable() end
function Node:EnableMouse() end
function Node:RegisterForDrag() end
function Node:SetOrientation() end
function Node:SetAutoFocus() end
function Node:SetTextInsets() end
function Node:Click()
    if not self.enabled then return end
    if self.kind == "CheckButton" then self.checked = not self.checked end
    if self.scripts.OnClick then self.scripts.OnClick(self, "LeftButton") end
end

UIParent = CreateFrame("Frame", "UIParent")
UIParent:SetSize(1920, 1080)
WorldFrame = CreateFrame("Frame", "WorldFrame")
DEFAULT_CHAT_FRAME = { AddMessage = function(_, text) Mock.messages[#Mock.messages + 1] = text end }
function wipe(value) for key in pairs(value) do value[key] = nil end return value end
function hooksecurefunc() end
function InterfaceOptions_AddCategory(category) Mock.categories[#Mock.categories + 1] = category end
function StaticPopup_Show(name) Mock.lastPopup = name end

Mock.cvars = {
    nameplateAllowOverlap = "0", nameplateStacking = "0", spreadnameplates = "1",
    nameplateYSpace = "20", nameplateXSpace = "100", nameplateMaxRaiseDistance = "200",
    nameplateSpeedRaise = "1", nameplateSpeedLower = "1", nameplateSpeedReset = "1",
    nameplateShowFriends = "0", nameplateStackFriendly = "0",
}
function GetCVar(name) return Mock.cvars[name] end
function SetCVar(name, value)
    Mock.cvars[name] = tostring(value)
    Mock.writes[#Mock.writes + 1] = { name, tostring(value) }
end
function Mock.Login()
    for _, frame in ipairs(frames) do
        if frame.event == "PLAYER_LOGIN" then frame.scripts.OnEvent(frame, "PLAYER_LOGIN") end
    end
end
function Mock.WatchCommands()
    local core = SlashCmdList.STABLEPLATES
    SlashCmdList.STABLEPLATES = function(command)
        Mock.commands[#Mock.commands + 1] = command
        return core(command)
    end
end
function Mock.ClearCalls() Mock.commands, Mock.writes = {}, {} end
function Mock.UpdateCount()
    local count = 0
    for _, frame in ipairs(frames) do if frame.scripts.OnUpdate then count = count + 1 end end
    return count
end

function InCombatLockdown() return Mock.inCombat or false end
function UnitHealthMax() return 20000 end
RAID_CLASS_COLORS = { MAGE = { r=0.25, g=0.78, b=0.92 } }
function SetRaidTargetIconTexture(texture, index) texture.raidIcon = index end

function Mock.EnableElvPreview()
    local test = CreateFrame("Button", "ElvNP_Test", UIParent)
    test:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 250)
    test:SetSize(150, 50)
    test:Hide()
    test.UnitFrame = {
        oldHealthBar = CreateFrame("StatusBar", nil, test),
        oldName = test:CreateFontString(nil), oldLevel = test:CreateFontString(nil),
        Buffs = {}, Debuffs = {}, RaidIcon = test:CreateTexture(nil, "ARTWORK"),
    }
    local style = { health = { enable = true, width = 150, height = 16,
        text = { enable = true, font = 'Expressway', fontSize = 11, position = 'CENTER' } },
        name = { enable = true, font = 'Expressway', fontSize = 12, position = 'TOPLEFT' },
        castbar = { enable = true, width = 150, height = 10, font = 'Expressway', fontSize = 10 } }
    local plates = { Initialized = true, db = { units = { ENEMY_NPC = style, ENEMY_PLAYER = style,
        FRIENDLY_NPC = style, FRIENDLY_PLAYER = style }, statusbar = 'ElvUI Norm' } }
    plates.UpdateAllFrame = function(_, unitFrame)
        unitFrame.UnitType = unitFrame.oldName:GetText()
        Mock.previewRefreshes = (Mock.previewRefreshes or 0) + 1
    end
    local dialog = { OpenFrames = {}, SelectGroup = function(_, ...)
        Mock.selectedOptionsGroup = {...}
    end }
    local engine = {
        NamePlates = plates, myclass = "MAGE", mylevel = 80,
        Libs = { AceConfigDialog = dialog },
        ToggleOptionsUI = function()
            Mock.optionsOpens = (Mock.optionsOpens or 0) + 1
            dialog.OpenFrames.ElvUI = {}
        end,
    }
    ElvUI = { engine }
    local locale = setmetatable({}, { __index = function(_, key) return key end })
    local loadPreview = assert(loadstring("local NP, E, L, random = ...\n" .. Mock.nativePreviewSource))
    loadPreview(plates, engine, locale, math.random)
    Mock.originalPreviewFunction = plates.TogleTestFrame
    return test
end

function Mock.SettleCrowd()
    local frame = StablePlatesMenu.Crowd.window
    for i = 1, 400 do
        local update = frame:GetScript('OnUpdate')
        if not update then return end
        update(frame, 1 / 60)
    end
    error('Crowd animation did not stop')
end

function Mock.WorldPlate(x, y, width, target)
    local plate = CreateFrame('Frame', nil, WorldFrame)
    plate.centerX, plate.centerY = x, y
    plate.UnitFrame = CreateFrame('Frame', nil, plate)
    plate.UnitFrame.isTarget = target
    plate.UnitFrame.UnitType = 'ENEMY_NPC'
    plate.UnitFrame.Health = CreateFrame('StatusBar', nil, plate.UnitFrame)
    plate.UnitFrame.Health:SetSize(width, 16)
    return plate
end

function Mock.StepCore(elapsed)
    for _, frame in ipairs(Mock.frames) do
        if frame:GetScript('OnUpdate') and frame ~= StablePlatesMenu.Crowd.window then
            frame:GetScript('OnUpdate')(frame, elapsed)
        end
    end
end
