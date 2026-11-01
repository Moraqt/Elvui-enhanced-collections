-- Extend the reusable UI model. This is a test-only API, never packaged.
local N = getmetatable(UIParent)
tinsert,tremove,format=table.insert,table.remove,string.format
local originalCreateFontString,originalSetText=N.CreateFontString,N.SetText
function N:CreateFontString(name,layer,template)
    local label=originalCreateFontString(self,name)
    if template then label:SetFont('Original.ttf',12,'') end
    label.strictFont=Mock.strictFonts
    return label
end
function N:SetText(value)
    if self.kind=='FontString' and self.strictFont and not self.font then
        error('SetText(): Font not set')
    end
    return originalSetText(self,value)
end
Mock.templateCalls, Mock.events, Mock.actions = {}, {}, {}
Mock.scriptWrites, Mock.hookCount, Mock.apiCalls = 0, 0, 0
function N:GetObjectType() return self.kind end
function N:IsObjectType(kind)
    return self.kind == kind or (kind == 'Button' and self.kind == 'CheckButton')
        or (kind == 'Frame' and self.kind ~= 'Texture' and self.kind ~= 'FontString')
end
function N:GetRegions()
    local regions = {}
    for _, child in ipairs(self.children) do
        if child.kind == 'Texture' or child.kind == 'FontString' then regions[#regions+1]=child end
    end
    return unpack(regions)
end
function N:GetChildren()
    local children = {}
    for _, child in ipairs(self.children) do
        if child.kind ~= 'Texture' and child.kind ~= 'FontString' then children[#children+1]=child end
    end
    return unpack(children)
end
function N:GetFont() return self.font or 'Original.ttf', self.fontSize or 12, self.fontOutline or '' end
function N:GetTextColor() return unpack(self.textColor or {1,1,1,1}) end
function N:SetFontObject(object)
    self.fontObject = object
    self:SetFont('Original.ttf',12,'')
end
function N:GetFontString() return self.Text or self.textLabel end
function N:GetDrawLayer() return self.layer or 'ARTWORK' end
function N:IsEnabled() return self.enabled end
function N:SetEnabled(value) if value then self:Enable() else self:Disable() end end
function N:SetShown(value) if value then self:Show() else self:Hide() end end
function N:HookScript(name, callback)
    self.extraHooks = self.extraHooks or {}
    self.extraHooks[name] = self.extraHooks[name] or {}
    table.insert(self.extraHooks[name],callback)
    Mock.hookCount = Mock.hookCount + 1
end
function N:RunScript(name,...)
    if self.scripts[name] then self.scripts[name](self,...) end
    for _, hook in ipairs(self.extraHooks and self.extraHooks[name] or {}) do hook(self,...) end
end
function N:SetAllPoints(relative) self.allPoints=relative or self.parent end
function N:Click(button) if self.enabled then self:RunScript('OnClick',button or 'LeftButton') end end
function N:GetFrameLevel() return self.frameLevel or 1 end
function N:GetBackdrop() return self.backdrop end
function N:GetBackdropColor() return unpack(self.backdropColor or {0,0,0,1}) end
function N:GetBackdropBorderColor() return unpack(self.borderColor or {0,0,0,1}) end
function N:SetTemplate()
    self:SetBackdrop({bgFile='Blank',edgeFile='Blank',edgeSize=1})
    self:SetBackdropColor(0.08,0.08,0.08,1)
    self:SetBackdropBorderColor(0.2,0.2,0.2,1)
end
function N:CreateBackdrop()
    if self.backdrop and self.backdrop.kind then return end
    self.backdrop = CreateFrame('Frame',nil,self)
    self.backdrop:SetAllPoints(self)
    self.backdrop:SetTemplate()
end
-- In the real API the backdrop region is not a Lua property named 'backdrop'.
function N:SetBackdrop(value) self.backdropDefinition = value end
function N:GetBackdrop() return self.backdropDefinition end
function N:SetTexCoord(...) self.texCoord={...} end
function N:SetAtlas(name) self.atlas=name; self.texture={name} end
function N:SetHighlightAtlas(name) self:GetOrMakeTexture('HighlightTexture'):SetAtlas(name) end
function N:SetDesaturated(value) self.desaturated=value end
function N:GetOrMakeTexture(key)
    if not self[key] then self[key]=self:CreateTexture(nil,'ARTWORK') end
    return self[key]
end
function N:SetNormalTexture(path) self:GetOrMakeTexture('NormalTexture'):SetTexture(path) end
function N:GetNormalTexture() return self.NormalTexture end
function N:SetHighlightTexture(path) self:GetOrMakeTexture('HighlightTexture'):SetTexture(path) end
function N:GetHighlightTexture() return self.HighlightTexture end
function N:SetPushedTexture(path) self:GetOrMakeTexture('PushedTexture'):SetTexture(path) end
function N:SetDisabledTexture(path) self:GetOrMakeTexture('DisabledTexture'):SetTexture(path) end
function N:SetStatusBarTexture(path) self.statusTexture=path end
function N:SetShadowColor(...) self.shadowColor={...} end
function N:SetParent(parent) self.parent=parent end
function N:RegisterForClicks() end
function N:EnableKeyboard() end
function N:LockHighlight() self.locked=true end
function N:UnlockHighlight() self.locked=false end
function N:ClearAndSetPoint(...) self:ClearAllPoints();self:SetPoint(...) end

function hooksecurefunc(object,method,callback)
    local old=object[method]
    assert(type(old)=='function',method)
    Mock.hookCount=Mock.hookCount+1
    object[method]=function(...)
        local values={old(...)}
        callback(...)
        return unpack(values)
    end
end

GameFontNormal,GameFontDisable='normal','disabled'
NORMAL_FONT_COLOR,GRAY_FONT_COLOR={r=1,g=.82,b=0},{r=.5,g=.5,b=.5}
IN_PROGRESS_FONT_COLOR={r=1,g=.82,b=0}
RETRIEVING_ITEM_INFO='Loading'
function GetItemInfo(id)
    return 'Sample item '..id,'item:'..id,4,80,0,'Armor','Cloth',1,'', 'icon:'..id
end
function GetItemCooldown(id) return id,10,1 end
function CooldownFrame_SetTimer(frame,...)
    frame.timer={...};Mock.cooldowns=(Mock.cooldowns or 0)+1
end
Mock.owned,Mock.favorites={},{}
C_ToyBox={PlayerHasToy=function(id) return Mock.owned[id] or false end,
    GetToyInfo=function(id) return nil,nil,nil,nil,Mock.favorites[id],false end,
    GetIsFavorite=function(id) return Mock.favorites[id] end,
    SetIsFavorite=function(id,value) Mock.favorites[id]=value end,
    ClearNewToy=function() end,UseToy=function(id) Mock.actions[#Mock.actions+1]={'toy',id} end}
C_Heirloom={PlayerHasHeirloom=C_ToyBox.PlayerHasToy,
    GetHeirloomInfo=function(id) return nil,nil,nil,nil,nil,false end,
    GetCreationInfo=function() return 0,1 end,ClearNewHeirloom=function() end,
    CreateHeirloom=function(id) Mock.actions[#Mock.actions+1]={'heirloom',id} end}
function IsModifiedClick() return false end
function PickupItem(id) Mock.actions[#Mock.actions+1]={'pickup',id} end
function PlaySound() end
function WardrobeFrame_IsAtTransmogrifier() return Mock.atNPC or false end
LE_TRANSMOG_TYPE_APPEARANCE=0
function PanelTemplates_SetTab(frame,id) frame.selectedTab=id end

GameTooltip={IsOwned=function() return false end,Hide=function() end}
local modules={}
local skins={}
local E={Modules=modules,media={blankTex='Blank',normFont='Expressway.ttf',rgbvaluecolor={.09,.52,.82}},
    TexCoords={.08,.92,.08,.92},Options={args={}},db={},private={skins={blizzard={enable=true}}},
    Libs={LSM={Fetch=function(_,_,font) return font..'.ttf' end},
        EP={RegisterPlugin=function(_,name,callback) Mock.optionsCallback=callback end},
        AceConfigDialog={OpenFrames={},SelectGroup=function(_,...) Mock.selectedGroup={...} end}}}
local P={}
ElvUI={E,{}, {},P,{}}
function E:GetModule(name) return name=='Skins' and skins or modules[name] end
function E:NewModule(name)
    local module={name=name,events={}}
    function module:GetName() return self.name end
    function module:RegisterEvent(event,callback) self.events[event]=callback end
    function module:UnregisterEvent(event) self.events[event]=nil end
    function module:UnregisterAllEvents() self.events={} end
    modules[name]=module
    return module
end
function E:RegisterModule(name,callback) Mock.initializer=callback end
function E:StaticPopup_Show(name) Mock.popup=name end
function E:ToggleOptionsUI() E.Libs.AceConfigDialog.OpenFrames.ElvUI={} end
AceGUIWidgetLSMlists={font={Expressway='Expressway',Montserrat='Montserrat'}}
function skins:HandleEditBox(box) box:CreateBackdrop() end
function skins:HandleCheckBox(box) box:SetTemplate() end
function skins:SetModifiedBackdrop() self:SetBackdropBorderColor(.09,.52,.82,1) end
function skins:SetOriginalBackdrop() self:SetBackdropBorderColor(.2,.2,.2,1) end
-- Real HandleButton from the user's installed ElvUI is loaded by validate.py.
Mock.Skins,Mock.Engine,Mock.Defaults=skins,E,P

function Mock.Start()
    E.db.enhancedCollections={}
    for key,value in pairs(P.enhancedCollections) do E.db.enhancedCollections[key]=value end
    Mock.initializer()
end
