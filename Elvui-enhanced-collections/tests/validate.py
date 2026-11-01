from pathlib import Path
import hashlib
import json
import re
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / 'ElvUI_EnhancedCollections'
REF = ROOT / 'reference' / 'Interface'
LIVE = Path(r'C:\Users\Rodrigo\AppData\Local\Whitemane\Games\FrostmourneRebuffed')
sys.path.insert(0, str(ROOT.parent / 'merfin-equipped-items' / '.tools' / 'python'))
from lupa.lua51 import LuaRuntime


def source(relative):
    return (REF / relative).read_text(encoding='utf-8-sig')


def function(text, name):
    match = re.search(r'^function ' + re.escape(name) + r'\(.*?^end\s*$', text, re.M | re.S)
    assert match, name
    return match.group(0)


NATIVE = {
    'CollectionsListButtonMixin': ['SetEntry', 'OnClick', 'ToggleFavorite'],
    'ToySpellButtonMixin': ['Update', 'OnClick', 'OnDragStart'],
    'HeirloomButtonMixin': ['Update', 'OnClick'],
    'CollectionsJournalPanelMixin': ['ToggleSummon', 'SummonSelected', 'SummonRandomFavorite', 'ToggleFavorite'],
    'WardrobeItemsModelMixin': ['OnMouseDown'],
}
native_sources = {name: source('FrameXML/Rebuffed/' + ('Collections/ToyBox.lua' if name.startswith('Toy')
    else 'Collections/Heirlooms.lua' if name.startswith('Heirloom')
    else 'Wardrobe/Wardrobe.lua' if name.startswith('Wardrobe') else 'Collections/CollectionsJournal.lua'))
    for name in NATIVE}
skin_path = LIVE / 'Interface/AddOns/ElvUI/Modules/Skins/Skins.lua'
skin_bytes = skin_path.read_bytes()
real_handle = function(skin_bytes.decode('utf-8-sig'), 'S:HandleButton')

templates = {}
for path in REF.rglob('*.xml'):
    tree = ET.parse(path)
    for node in tree.getroot():
        if node.get('name'):
            templates[node.get('name')] = node

FRAME_TAGS = {'Frame','Button','CheckButton','EditBox','ScrollFrame','Slider','StatusBar','DressUpModel','PlayerModel','Cooldown'}
REGION_TAGS = {'Texture','FontString','ButtonText','NormalTexture','PushedTexture','DisabledTexture','HighlightTexture','BarTexture'}


def tag(node):
    return node.tag.split('}')[-1]


class Fixture:
    def __init__(self, start=True):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute((ROOT/'tests/wow_mock.lua').read_text(encoding='utf-8'))
        self.lua.execute((ROOT/'tests/collections_mock.lua').read_text(encoding='utf-8'))
        self.lua.execute('local S=Mock.Skins\n'+real_handle)
        for name, methods in NATIVE.items():
            self.lua.execute(name+'={}')
            for method in methods:
                self.lua.execute(function(native_sources[name], name+':'+method))
        self.lua.execute('local TAB_ITEMS,TAB_SETS=1,2\n'+function(source('FrameXML/Rebuffed/Wardrobe/Wardrobe.lua'), 'WardrobeCollectionFrame_SetTab'))
        self.lua.execute(source('SharedXML/RebuffedMenu.lua'))
        self.g = self.lua.globals()
        self.pending = []
        self.build(templates['CollectionsJournal'], self.g.UIParent)
        self.build(templates['WardrobeCollectionFrame'], self.g.UIParent)
        self.resolve()
        self.lua.execute('''
            local journal=CollectionsJournal
            local p=journal.Journal
            p.selectedID=2
            p.GetAPI=function() return {GetIsFavorite=function(id) return Mock.favorites[id],true end,
                SummonByID=function(id) table.insert(Mock.actions,{'summon',id}) end,
                Dismiss=function() table.insert(Mock.actions,{'dismiss'}) end,
                SetIsFavorite=function(id,v) Mock.favorites[id]=v end} end
            p.GetSelectedEntry=function(self) return self.selectedEntry end
            for k,v in pairs(CollectionsJournalPanelMixin) do p[k]=v end
            p.UpdateList=function(self) self.nativeUpdates=(self.nativeUpdates or 0)+1 end
            p.RefreshBackground=function(self) self.Display.Background:SetAtlas('mount-background') end
            journal.ToyBox.UpdateButtons=function(self) self.nativeUpdates=(self.nativeUpdates or 0)+1 end
            for i=1,18 do
                local b=journal.ToyBox.IconsFrame['Button'..i]
                for k,v in pairs(ToySpellButtonMixin) do b[k]=v end
                b.toyBox=journal.ToyBox
                b:SetScript('OnClick',b.OnClick)
            end
            journal.Heirlooms.buttons={}
            journal.Heirlooms.headers={}
            journal.Heirlooms.LayoutCurrentPage=function(self) self.nativeLayouts=(self.nativeLayouts or 0)+1 end
            journal.tabs={}
            journal.SelectTab=function(self,tab)
                for _,item in ipairs(self.tabs) do item.isSelected=(item==tab);item:SetChecked(item==tab) end
                self.currentTab=tab
            end
            journal.AddTab=function(self,tab) table.insert(self.tabs,tab) end
            local w=WardrobeCollectionFrame
            w.ItemsCollectionFrame.transmogType=LE_TRANSMOG_TYPE_APPEARANCE
            for _,panel in ipairs({w.ItemsCollectionFrame,w.SetsTransmogFrame}) do
                panel.Models={}
                for _,child in ipairs({panel:GetChildren()}) do
                    if child:GetObjectType()=='DressUpModel' and child.Border then
                        table.insert(panel.Models,child)
                        child.OnMouseDown=WardrobeItemsModelMixin.OnMouseDown
                        child:SetScript('OnMouseDown',child.OnMouseDown)
                        child.visualInfo={visualID=#panel.Models,isCollected=true,isUsable=true}
                    end
                end
                panel.SelectVisual=function(_,id) table.insert(Mock.actions,{'appearance',id}) end
                panel.UpdateItems=function(self) self.nativeUpdates=(self.nativeUpdates or 0)+1 end
                panel.UpdateSets=panel.UpdateItems
            end
            w.SetsCollectionFrame.ScrollFrame.buttons={}
            w.SetsCollectionFrame.ScrollFrame.Update=function(self) self.nativeUpdates=(self.nativeUpdates or 0)+1 end
            w.SetsCollectionFrame.DisplaySet=function(self,id) self.selectedSet=id end
            local details=w.SetsCollectionFrame.DetailsFrame
            details.itemFramesPool={EnumerateActive=function() return pairs({}) end}
            w.activeFrame=w.ItemsCollectionFrame
        ''')
        journal = self.g.CollectionsJournal
        for i, name in enumerate(['Mounts','Companions','Toys','Heirlooms','Appearances'], 1):
            tab_node = self.build(templates['CollectionsTabTemplate'], journal, name=f'CollectionTab{i}')
            tab_node.Text.SetText(tab_node.Text, name)
            tab_node.SetSize(tab_node, 98 if i != 2 else 116, 32)
            tab_node.SetPoint(tab_node,'TOPLEFT',journal,'BOTTOMLEFT',8+(i-1)*112,-2)
            journal.tabs[i] = tab_node
        self.add_rows(journal.Journal.List.ScrollFrame, journal.Journal, False)
        self.add_rows(self.g.WardrobeCollectionFrame.SetsCollectionFrame.ScrollFrame, None, True)
        self.resolve()
        def new_heirloom():
            panel = self.g.CollectionsJournal.Heirlooms
            button = self.build(templates['HeirloomButtonTemplate'], panel.IconsFrame)
            button.heirlooms = panel
            for key, value in self.g.HeirloomButtonMixin.items(): button[key] = value
            self.resolve()
            return button
        self.g.Mock.NewHeirloom = new_heirloom
        self.lua.execute('Mock.strictFonts=true')
        for filename in ['Core.lua','Skin.lua','Options.lua']:
            self.lua.execute('local __addonName=...\n'+(ADDON/filename).read_text(encoding='utf-8'), 'ElvUI_EnhancedCollections')
        if start:
            self.lua.execute('Mock.Start()')

    def build(self, element, parent, name=None, existing=None):
        kind = tag(element)
        object_name = name if name is not None else element.get('name')
        if object_name:
            object_name = object_name.replace('$parent',parent.GetName(parent) or 'MockParent')
        if existing is not None:
            obj = existing
        elif kind in REGION_TAGS:
            obj = parent.CreateFontString(parent, object_name) if kind in {'FontString','ButtonText'} else parent.CreateTexture(parent,object_name,'ARTWORK')
        else:
            obj = self.g.CreateFrame(kind,object_name,parent)
        self.apply(element,obj,parent)
        return obj

    def apply(self, element, obj, parent):
        for inherited in element.get('inherits','').split(','):
            inherited=inherited.strip()
            if inherited in templates:
                self.apply(templates[inherited],obj,parent)
            elif inherited=='PortraitFrameTemplate':
                obj.TitleText=obj.CreateFontString(obj,None)
                obj.TitleText.SetPoint(obj.TitleText,'TOP',obj,'TOP',0,-7)
                obj.portrait=obj.CreateTexture(obj,None,'ARTWORK')
                obj.CloseButton=self.g.CreateFrame('Button',None,obj)
                obj.CloseButton.SetSize(obj.CloseButton,20,20)
                obj.CloseButton.SetPoint(obj.CloseButton,'TOPRIGHT',obj,'TOPRIGHT',-4,-4)
            elif inherited in {'UIPanelButtonTemplate','DropdownButtonArtTemplate','UIMenuButtonStretchTemplate','RebuffedFilterDropDownButtonTemplate'}:
                if obj.Text is None:
                    obj.Text=obj.CreateFontString(obj,None)
                    obj.Text.SetPoint(obj.Text,'CENTER',obj,'CENTER',0,0)
                if obj.GetWidth(obj)==0: obj.SetSize(obj,85,22)
            elif inherited=='SearchBoxTemplate':
                obj.Instructions=obj.CreateFontString(obj,None)
                obj.Instructions.SetText(obj.Instructions,'Search')
                obj.Instructions.SetPoint(obj.Instructions,'LEFT',obj,'LEFT',8,0)
            elif inherited in {'CollectionsBackgroundTemplate','InsetFrameTemplate','InsetFrameTemplate2'}:
                obj.CreateTexture(obj,None,'BACKGROUND').SetTexture(obj.CreateTexture(obj,None,'BACKGROUND'),'Decorative')
            elif obj.GetObjectType(obj)=='FontString' and inherited:
                obj.SetFont(obj,'Original.ttf',12,'')
        if element.get('parentKey'):
            parent[element.get('parentKey')]=obj
        if tag(element)=='ButtonText': parent.Text=obj
        if tag(element) in {'NormalTexture','HighlightTexture','PushedTexture','DisabledTexture'}:
            parent[tag(element)]=obj
        if element.get('hidden')=='true': obj.Hide(obj)
        if element.get('text'): obj.SetText(obj,element.get('text'))
        if element.get('file'): obj.SetTexture(obj,element.get('file'))
        if element.get('alpha'): obj.SetAlpha(obj,float(element.get('alpha')))
        for child in element:
            typ=tag(child)
            if typ=='Size':
                size=next(iter(child),child)
                obj.SetSize(obj,float(size.get('x',0)),float(size.get('y',0)))
            elif typ=='Anchors': self.pending.append((obj,parent,child))
            elif typ in {'Frames','Layers','Layer'}: self.container(child,obj)
            elif typ in REGION_TAGS: self.build(child,obj)

    def container(self, node, parent):
        for child in node:
            typ=tag(child)
            if typ in FRAME_TAGS or typ in REGION_TAGS: self.build(child,parent)
            elif typ in {'Frames','Layers','Layer'}: self.container(child,parent)

    def resolve(self):
        for obj,parent,anchors in self.pending:
            obj.ClearAllPoints(obj)
            for anchor in anchors:
                relative_name=anchor.get('relativeTo')
                relative=self.g[relative_name.replace('$parent',parent.GetName(parent) or 'MockParent')] if relative_name else parent
                # A missing era template anchor is irrelevant to skin behavior.
                relative=relative if relative is not None else parent
                x,y=anchor.get('x','0'),anchor.get('y','0')
                offset=next((node for node in anchor.iter() if tag(node)=='AbsDimension'),None)
                if offset is not None: x,y=offset.get('x','0'),offset.get('y','0')
                obj.SetPoint(obj,anchor.get('point'),relative,anchor.get('relativePoint') or anchor.get('point'),float(x),float(y))
        self.pending=[]

    def add_rows(self, scroll, panel, sets):
        scroll.buttons=self.lua.table()
        for i in range(1,12):
            row=self.build(templates['WardrobeSetsScrollFrameButtonTemplate' if sets else 'CollectionsListButtonTemplate'],scroll,name=('SetRow' if sets else 'MountRow')+str(i))
            row.SetPoint(row,'TOPLEFT',scroll,'TOPLEFT',44,-(i-1)*46)
            if panel is not None:
                row.panel=panel
                for k,v in self.g.CollectionsListButtonMixin.items(): row[k]=v
                row.SetEntry(row,self.lua.table_from(dict(id=i,icon='icon:'+str(i),name='Training mount '+str(i),isCollected=i<6,isUsable=i<6)))
            else:
                row.Name.SetText(row.Name,'Appearance set '+str(i))
            scroll.buttons[i]=row

    def run(self, code):
        return self.lua.execute(code)


results=[]
def check(name, code, start=True):
    fixture=Fixture(start)
    fixture.run(code)
    results.append(name)
    print('PASS:',name)


check('All five Collections areas receive the skin without collection API actions', '''
    local a=ElvUIEnhancedCollections
    assert(a.installed and #Mock.actions==0 and #Mock.writes==0)
    assert(CollectionsJournal.backdropColor[1]==.105)
    assert(CollectionsJournal.NineSlice:GetAlpha()==0)
    assert(CollectionsJournal.ToyBox.IconsFrame.backdropColor[1]==.075)
    assert(CollectionsJournal.Heirlooms.IconsFrame.backdropColor[1]==.075)
    assert(WardrobeCollectionFrame.ItemsCollectionFrame.Models[1].ecModel)
    assert(WardrobeCollectionFrame.SetsCollectionFrame.RightInset.backdropColor[1]==.075)
''')
check('Mount row font survives native SetEntry font-object replacement and keeps selection/favorites', '''
    local row=CollectionsJournal.Journal.List.ScrollFrame.buttons[1]
    row:SetEntry({id=2,name='Collected',icon='native',isCollected=true,isUsable=true})
    assert(row.Name:GetFont()=='Expressway.ttf')
    assert(row.Selected:IsShown() and row.entry.id==2 and row.Icon.texture[1]=='native')
    row:SetEntry({id=90,name='Missing',icon='missing',isCollected=false,isUsable=false})
    assert(row.Name:GetFont()=='Expressway.ttf' and not row.Selected:IsShown())
    assert(row.Icon.desaturated and row.Name.textColor[1]==.62)
''')
check('Mount summon, dismiss, random favorite and favorite callbacks retain native actions', '''
    local panel=CollectionsJournal.Journal
    panel:ToggleSummon({id=42,isCollected=true,isActive=false})
    panel:ToggleSummon({id=42,isCollected=true,isActive=true})
    panel:SummonRandomFavorite()
    panel:ToggleFavorite({id=42,isFavorite=false})
    assert(Mock.actions[1][1]=='summon' and Mock.actions[1][2]==42)
    assert(Mock.actions[2][1]=='dismiss' and Mock.actions[3][2]==0 and Mock.favorites[42])
''')
check('Native toy update retains collected states, ownership, favorite and cooldown data', '''
    local b=CollectionsJournal.ToyBox.IconsFrame.Button1
    b.toyBox=CollectionsJournal.ToyBox
    Mock.owned[7]=true;Mock.favorites[7]=true
    b:Update(7)
    -- The initial fixture button has not yet been observed after adding methods.
    CollectionsJournal.ToyBox:UpdateButtons()
    b:Update(7)
    assert(b.Name:GetFont()=='Expressway.ttf' and b.Icon:IsShown() and b.Favorite:IsShown())
    assert(b.Cooldown.timer[1]==7 and b.Cooldown.timer[2]==10)
    b:Update(8)
    assert(not b.Icon:IsShown() and b.IconUncollected:IsShown() and b.IconUncollected:GetAlpha()==.45)
    assert(b.Name.textColor[1]==.62 and not b.Favorite:IsShown())
    local before=Mock.cooldowns
    ElvUIEnhancedCollections:Refresh()
    assert(Mock.cooldowns==before)
''')
check('Toy use and favorite clicks still execute the original client functions', '''
    local b=CollectionsJournal.ToyBox.IconsFrame.Button1
    b.itemID=7;Mock.owned[7]=true
    ToySpellButtonMixin.OnClick(b,'LeftButton')
    ToySpellButtonMixin.OnClick(b,'RightButton')
    assert(Mock.actions[1][1]=='toy' and Mock.actions[1][2]==7 and Mock.favorites[7])
''')
check('New heirloom buttons and headers receive styling after native layout', '''
    local panel=CollectionsJournal.Heirlooms
    local b=Mock.NewHeirloom()
    b.heirlooms=panel
    for k,v in pairs(HeirloomButtonMixin) do b[k]=v end
    panel.buttons[1]=b
    local header=panel.IconsFrame:CreateFontString(nil,'ARTWORK','GameFontNormalLarge')
    header:SetText('Shoulder');panel.headers[1]=header
    panel:LayoutCurrentPage()
    Mock.owned[12]=true;b:Update(12)
    assert(header:GetFont()=='Expressway.ttf' and b.Name:GetFont()=='Expressway.ttf')
    HeirloomButtonMixin.OnClick(b)
    assert(Mock.actions[1][1]=='heirloom' and Mock.actions[1][2]==12)
''')
check('Model tiles retain camera/mouse scripts, pending state and favorite marks', '''
    local panel=WardrobeCollectionFrame.ItemsCollectionFrame
    local m=panel.Models[1]
    local mouse=m:GetScript('OnMouseDown')
    m.Favorite.Icon:Show();m.TransmogStateTexture:Show()
    m.visualInfo={visualID=42,isCollected=true,isUsable=false}
    panel:UpdateItems()
    assert(m.ecBorder.borderColor[1]==.85 and m.ecBorder.borderColor[2]==.22)
    assert(m:GetScript('OnMouseDown')==mouse and m.Favorite.Icon:IsShown() and m.TransmogStateTexture:IsShown())
    m:RunScript('OnMouseDown','LeftButton')
    assert(Mock.actions[1][1]=='appearance' and Mock.actions[1][2]==42)
''')
check('Selecting Collections tabs updates the accent underline without changing tab state', '''
    local j=CollectionsJournal
    j:SelectTab(j.tabs[5])
    assert(j.tabs[5].isSelected and j.tabs[5]:GetChecked())
    assert(j.tabs[5].ecUnderline:IsShown() and not j.tabs[1].ecUnderline:IsShown())
''')
check('The native Items/Sets switch preserves panel visibility and updates active styling', '''
    local w=WardrobeCollectionFrame
    WardrobeCollectionFrame_SetTab(2)
    assert(w.activeFrame==w.SetsCollectionFrame and not w.ItemsCollectionFrame:IsShown())
    assert(w.SetsTab.ecUnderline:IsShown() and not w.ItemsTab.ecUnderline:IsShown())
    WardrobeCollectionFrame_SetTab(1)
    assert(w.activeFrame==w.ItemsCollectionFrame and w.ItemsTab.ecUnderline:IsShown())
''')
check('Shared filter menus are skinned for Collections and restored on close', '''
    local entries={{text='Collected',checked=true,func=function() Mock.menuAction=true end}}
    local owner=CollectionsJournal.Journal.FilterButton
    RebuffedMenu:Open(owner,entries)
    local panel=RebuffedMenu.panels[1]
    assert(panel.rows[1].Text:GetFont()=='Expressway.ttf')
    assert(panel.rows[1].Text.textColor[1]==.91)
    assert(panel:GetBackdrop().edgeSize==1 and panel.rows[1].Check:IsShown())
    RebuffedMenu:Activate(panel.rows[1])
    assert(Mock.menuAction and panel:GetBackdrop().edgeSize==12)
    assert(panel.rows[1].Text:GetFont()=='Original.ttf')
    assert(panel.rows[1].Text.textColor[1]==1 and panel.rows[1].Text.textColor[2]==.82)
    local unrelated=CreateFrame('Button',nil,UIParent)
    RebuffedMenu:Open(unrelated,entries)
    assert(panel:GetBackdrop().edgeSize==12 and panel.rows[1].Text:GetFont()=='Original.ttf')
''')
check('Repeated refreshes do not allocate more skin frames or install duplicate hooks', '''
    local frames,hooks=#Mock.frames,Mock.hookCount
    for i=1,10 do ElvUIEnhancedCollections:Refresh() end
    assert(#Mock.frames==frames and Mock.hookCount==hooks)
    assert(#Mock.writes==0 and #Mock.actions==0)
''')
check('The skin adds no OnUpdate handler or recurring timer', '''
    assert(Mock.UpdateCount()==0)
    for _,frame in ipairs(Mock.frames) do assert(not frame:GetScript('OnUpdate')) end
''')
check('Every new dropdown arrow has a font before its initial SetText call', '''
    for _,button in ipairs({CollectionsJournal.Journal.FilterButton,
        CollectionsJournal.ToyBox.FilterButton,CollectionsJournal.Heirlooms.FilterButton,
        CollectionsJournal.Heirlooms.ClassDropDown,WardrobeCollectionFrame.FilterButton,
        WardrobeCollectionFrame.ItemsCollectionFrame.WeaponDropDown}) do
        assert(button.ecArrow and button.ecArrow:GetText()=='v')
        assert(button.ecArrow:GetFont()=='Expressway.ttf')
    end
''')
check('Successful installation reaches Toys and Heirlooms and registers their page hooks', '''
    local a=ElvUIEnhancedCollections
    assert(a.installed)
    assert(a.hooks[CollectionsJournal.ToyBox].UpdateButtons)
    assert(a.hooks[CollectionsJournal.Heirlooms].LayoutCurrentPage)
    assert(a.hooks[WardrobeCollectionFrame.ItemsCollectionFrame].UpdateItems)
''')
check('Options update presentation only and select the correct options page', '''
    Mock.optionsCallback()
    local o=Mock.Engine.Options.args.enhancedCollections
    o.set({'font'},'Montserrat')
    assert(CollectionsJournal.Journal.List.ScrollFrame.buttons[1].Name:GetFont()=='Montserrat.ttf')
    o.set({'fontSize'},14)
    local _,size=CollectionsJournal.TitleText:GetFont()
    assert(size==16 and #Mock.actions==0 and #Mock.writes==0)
    SlashCmdList.ENHANCEDCOLLECTIONS()
    assert(Mock.selectedGroup[2]=='enhancedCollections')
    o.args.enabled.set(nil,false)
    assert(Mock.popup=='PRIVATE_RL')
''')
check('Installation waits until outside combat', '''
    Mock.inCombat=true
    Mock.Start()
    assert(not ElvUIEnhancedCollections.installed)
    Mock.inCombat=false
    ElvUIEnhancedCollections:OnReady()
    assert(ElvUIEnhancedCollections.installed)
''', start=False)
check('Missing Collections UI waits without creating replacement functionality', '''
    CollectionsJournal=nil
    Mock.Start()
    assert(not ElvUIEnhancedCollections.installed)
    assert(ElvUIEnhancedCollections.events.ADDON_LOADED)
''', start=False)
check('Disabling the skin preserves the original appearance on startup', '''
    Mock.Start=function()
        Mock.Engine.db.enhancedCollections={}
        for k,v in pairs(Mock.Defaults.enhancedCollections) do Mock.Engine.db.enhancedCollections[k]=v end
        Mock.Engine.db.enhancedCollections.enabled=false
        Mock.initializer()
    end
    Mock.Start()
    assert(not ElvUIEnhancedCollections.installed and CollectionsJournal.backdropColor==nil)
''', start=False)

report={'runtime':'Lua 5.1','check_count':len(results),'passed_checks':results,
    'client_files_modified':False,'in_game_validation':'pending',
    'installed_elvui_skins_sha256':hashlib.sha256(skin_bytes).hexdigest(),
    'installed_elvui_skins_unchanged':skin_path.read_bytes()==skin_bytes,
    'reference_sources':{str(path.relative_to(ROOT)):hashlib.sha256(path.read_bytes()).hexdigest()
        for path in REF.rglob('*') if path.is_file()}}
(ROOT/'validation.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(f'PASS: {len(results)} checks; client files unchanged; in-game validation pending')
