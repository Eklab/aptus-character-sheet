-- Lógica real de consulta/contexto con DB e interfaz dobles; no es una prueba FGU.
return function(test)
    local m,DB,put,session=test.manager,test.DB,test.put,test.Session;
    local previous=m.APTUSStructureManager;local oldName,oldHost=session.UserName,session.IsHost;
    session.IsHost,session.UserName=true,"GM";
    local visibility,access,choices={},{},{};
    local structureDB=setmetatable({getChildren=function(node,path)
        if node=="aptus_structures" and path==nil then return choices; end
        return DB.getChildren(node,path);
    end},{__index=DB});
    local permissions={hasVisibility=function(node,user) return visibility[DB.getPath(node)..user]==true;end,
        hasAccess=function(node,user) return access[DB.getPath(node)..user]==true;end,
        subscribe=function()end,unsubscribe=function()end};
    local structure={DB=structureDB,Session=session,APTUSLocationPermissions=permissions,
        RecordDataManager={getRecordTypeFromRecordPath=function(path) return path:match("^aptus_structures%.[^.@]+$") and "aptus_structure" or "";end},
        WindowManager={getReadOnlyState=function()return false;end}};
    setmetatable(structure,{__index=_G});
    assert(loadfile("scripts/manager_aptus_structure.lua","t",structure))();
    structure.registerFeature("storage",{name="Almacenaje",implemented=true});
    for _,kind in ipairs({"location","vehicle"}) do
        structure.registerType(kind,{name=kind,category=kind=="location" and "locations" or "vehicles",icon="test",skin="default"});
    end
    m.APTUSStructureManager=structure;
    local function owner(id,kind,name)
        local node=test.newStructure("view_"..id);put(node,"type","string",kind);put(node,"name","string",name);
        put(node,"features.storage.enabled","number",1);choices[id]=node;return node;
    end
    local a=owner("a","location","A Cabaña");
    local b=owner("b","location","B Oculta");
    local c=owner("c","location","C Visible sin recursos");local v=owner("v","vehicle","Vehículo");
    visibility[DB.getPath(a).."Alice"],access[DB.getPath(a).."Alice"]=true,true;
    visibility[DB.getPath(c).."Alice"],visibility[DB.getPath(v).."Alice"]=true,true;
    local host={mode="host",username="GM"};local alice={mode="player_preview",username="Alice"};
    assert(#structure.getVisibleStructures("locations",host)==3);
    assert(#structure.getVisibleStructures("locations",alice)==2);
    assert(#structure.getVisibleStructures("vehicles",alice)==1);
    assert(not structure.canAccessAs(c,alice) and structure.canAccessAs(a,alice));
    local template=test.template("aptus_equipment_templates.view_box","view:box");
    put(template,"properties.type_id","string","storage");put(template,"properties.is_container","number",1);
    put(template,"properties.capacity","number",5);put(template,"properties.load_every","number",1);put(template,"properties.load_value","number",1);
    local bag=assert(m.createFromTemplate(a,template));local inner=assert(m.createFromTemplate(a,template,1,bag));
    local child=assert(m.createFromTemplate(a,template,1,inner));
    put(bag,"properties.hide_contents","number",1);put(inner,"properties.hide_contents","number",1);
    local before=test.writes();local full=m.getViewedInventory(a,host);local filtered=m.getViewedInventory(a,alice);
    assert(#full.items==3 and #filtered.items==1 and #filtered.roots[1].children==0);
    assert(not filtered.items[1].viewer_is_host and full.items[1].viewer_is_host);
    assert(filtered.items[1].content_load==full.items[1].content_load);
    put(bag,"properties.hide_contents","number",0);filtered=m.getViewedInventory(a,alice);
    assert(#filtered.items==2 and #filtered.roots[1].children==1 and #filtered.roots[1].children[1].children==0);
    assert(#m.getViewedInventory(c,alice).items==0 and test.writes()==before);
    -- Agrupador real: sólo lectura; Todo omite estructuras vacías o sin recursos.
    structure.APTUSInventoryManager=m;
    local groups=structure.getResourceGroups("locations",alice,false);
    assert(#groups==2 and groups[1].path==DB.getPath(a) and groups[2].path==DB.getPath(c));
    assert(groups[2].message=="Sin acceso a los recursos.");
    assert(#structure.getResourceGroups("locations",alice,true)==1);
    put(c,"features.storage.enabled","number",0);
    assert(structure.getResourceGroups("locations",alice,false)[2].message=="Almacenaje no disponible.");
    put(c,"features.storage.enabled","number",1);access[DB.getPath(c).."Alice"]=true;
    assert(structure.getResourceGroups("locations",alice,false)[2].message=="Almacenaje vacío.");
    visibility[DB.getPath(c).."Alice"]=false;
    assert(#structure.getResourceGroups("locations",alice,false)==1);
    assert(#structure.getResourceGroups("vehicles",alice,false)==1);
    assert(#structure.getResourceGroups("vehicles",alice,true)==0);
    assert(#structure.getResourceGroups("locations",host,false)==3);
    assert(test.writes()==before);
    -- Controlador real de la lista unificada con controles nativos simulados.
    local own=test.newCharacter();put(own,"attributes.fue.effective","number",2);local ownItem=assert(m.createFromTemplate(own,template));
    local vehicleItem=assert(m.createFromTemplate(v,template));before=test.writes();
    local effectiveViewer=alice;
    local function control()
        local c={visible=true};
        c.setValue=function(value)c.value=value;end;c.getValue=function()return c.value or "";end;
        c.setVisible=function(value)c.visible=value;end;c.setFont=function()end;c.setColor=function()end;
        c.setIcon=function()end;c.setTooltipText=function()end;c.setAnchor=function()end;c.setBackColor=function()end;
        c.setAnchoredWidth=function(value)c.width=value;end;c.setAnchoredHeight=function()end;
        return c;
    end
    local function equipmentWindow()
        local env={DB=DB,Session=session,APTUSInventoryManager=m,APTUSStructureManager=structure,
            APTUSLocationPermissions=permissions,getDatabaseNode=function()return own;end,
            getClass=function()return "aptus_char_equipment";end,
            StringManager={trim=function(value)return value:match("^%s*(.-)%s*$");end},
            WindowManager={getTopWindow=function()return {getStructureViewer=function()return effectiveViewer;end};end}};
        setmetatable(env,{__index=_G});env.self=env;
        for _,name in ipairs({"load_fill","add_equipment","heading_state","heading_name","heading_count","heading_location","heading_load",
            "load_title","load_track","load_capacity_mark","load_half_capacity_mark","load_one_half_capacity_mark","load_silhouette",
            "load_value","load_hint","load_penalty_1","load_penalty_2","search","empty_message","preview_notice","preview_scrollbar"}) do env[name]=control();end
        for n=0,4 do env["filter_label_"..n]=control();end
        env.preview=control();env.rows={};env.preview.closeAll=function()env.rows={};end;
        env.preview.getSize=function()return 483,232;end;env.preview.scrollToWindow=function()end;
        local function row(class)
            local w={class=class};
            w.setPreview=function(item)w.item=item;end;
            w.setGroup=function(group)w.group=group;end;
            table.insert(env.rows,w);return w;
        end
        env.preview.createWindow=function()return row("character");end;
        env.preview.createWindowWithClass=row;
        assert(loadfile("scripts/char_equipment_aptus.lua","t",env))();env.onInit();return env;
    end
    local ui=equipmentWindow();
    local ownLoad=ui.load_value.value;assert(ownLoad=="1 / 6");
    for n=1,5 do
        ui.selectView(n);
        assert(ui.load_value.value==ownLoad, "CARGA debe depender sólo del personaje en todas las pestañas");
        assert(ui.load_title.visible and ui.load_track.visible);
    end
    ui.selectView(1);
    assert(ui.rows[1].item.path==DB.getPath(ownItem));
    assert(ui.rows[2].group.path==DB.getPath(a) and #ui.rows==4);
    ui.selectView(2);assert(#ui.rows==1 and ui.rows[1].class=="character");
    ui.selectView(3);assert(#ui.rows==3 and ui.rows[1].group.path==DB.getPath(a));
    ui.selectView(2);ui.selectView(3);assert(#ui.rows==3);
    local independent=equipmentWindow();independent.selectView(3);assert(#independent.rows==3);
    ui.selectView(4);assert(#ui.rows==1 and ui.rows[1].group.message=="Sin acceso a los recursos.");
    access[DB.getPath(v).."Alice"]=true;ui.refreshPreview();assert(#ui.rows==2 and ui.rows[2].item.path==DB.getPath(vehicleItem));
    ui.selectView(1);assert(ui.rows[1].item.path==DB.getPath(ownItem));
    assert(ui.rows[2].group.category=="locations" and ui.rows[5].group.category=="vehicles");
    local seen={};for _,w in ipairs(ui.rows) do if w.item then assert(not seen[w.item.path]);seen[w.item.path]=true;end end
    effectiveViewer=host;ui.onStructureViewerChanged();assert(#ui.rows==7);
    effectiveViewer=alice;ui.onStructureViewerChanged();assert(#ui.rows==6);
    ui.search.setValue(DB.getValue(child,"name",""));ui.refreshPreview();
    -- El snapshot que alimenta la búsqueda no contiene el descendiente oculto.
    for _,w in ipairs(ui.rows) do if w.item then assert(w.item.path~=DB.getPath(child));end end
    ui.search.setValue("");ui.selectView(3);
    put(a,"features.storage.enabled","number",0);ui.refreshPreview();
    assert(#ui.rows==1 and ui.rows[1].group.message=="Almacenaje no disponible.");
    put(a,"features.storage.enabled","number",1);ui.refreshPreview();assert(#ui.rows==3);
    visibility[DB.getPath(a).."Alice"]=false;ui.refreshPreview();assert(#ui.rows==0);
    visibility[DB.getPath(a).."Alice"]=true;ui.refreshPreview();assert(#ui.rows==3);
    -- Enlaces a fichas independientes: sólo Visibilidad; sin requisito de Acceso/Almacenaje.
    local structureOpens,fronts={},0;
    ui.Interface={findWindow=function(class,path)
        if structureOpens[class..path]then return {bringToFront=function()fronts=fronts+1;end};end
    end,openWindow=function(class,node)
        assert((node==v and class=="aptus_structure")or(node~=v and class=="aptus_location"));
        structureOpens[class..DB.getPath(node)]=node;
    end};
    effectiveViewer=alice;
    assert(ui.openStructure(DB.getPath(a))and structureOpens["aptus_location"..DB.getPath(a)]==a);
    assert(ui.openStructure(DB.getPath(a))and fronts==1);
    assert(not ui.openStructure(DB.getPath(b)));
    visibility[DB.getPath(c).."Alice"]=true;access[DB.getPath(c).."Alice"]=false;
    put(c,"features.storage.enabled","number",0);
    ui.selectView(3);assert(ui.openStructure(DB.getPath(c)));
    put(c,"features.storage.enabled","number",1);assert(ui.openStructure(DB.getPath(c)));
    ui.selectView(4);assert(ui.openStructure(DB.getPath(v)));
    visibility[DB.getPath(v).."Alice"]=false;assert(not ui.openStructure(DB.getPath(v)));
    effectiveViewer=host;assert(ui.openStructure(DB.getPath(b)));
    session.IsHost,session.UserName=false,"Alice";assert(not ui.openStructure(DB.getPath(b)));
    assert(ui.openStructure(DB.getPath(a)));
    session.IsHost,session.UserName=true,"GM";effectiveViewer=alice;
    visibility[DB.getPath(v).."Alice"]=true;visibility[DB.getPath(c).."Alice"]=false;
    assert(test.writes()==before);
    -- Apertura real: clase normal para DJ y misma ficha en variante de consulta
    -- para Impersonar/jugador; inicialización diferida sin contenido previo al contexto.
    local opened={};local lastOpened;local earlyContent=0;
    local inspectionInterface={};
    function inspectionInterface.findWindow(class,path)
        local w=opened[class..path];return w and not w.closed and w or nil;
    end
    function inspectionInterface.openWindow(class,path)
        local w={DB=DB,Session=session,APTUSInventoryManager=m,APTUSLocationPermissions=permissions,
            getDatabaseNode=function()return DB.findNode(path);end,getClass=function()return class;end,
            super={onInit=function()end},menubar={subwindow={locked={setLocked=function()end,setReadOnly=function()end}}}};
        w.content={setValue=function(contentClass,itemPath)
            assert(contentClass=="aptus_inventory_item_main" and itemPath==path);
            w.loaded=true;w.content.subwindow={update=function()end,reload=function()end,onPersistentDataChanged=function()end};
        end};
        w.close=function()if not w.closed then w.closed=true;w.onClose();end end;w.bringToFront=function()end;
        setmetatable(w,{__index=_G});w.self=w;
        assert(loadfile("scripts/inventory_item_window_aptus.lua","t",w))();w.onInit();
        if class=="aptus_inventory_item_consult" then assert(not w.loaded);earlyContent=earlyContent+1;end
        opened[class..path]=w;lastOpened=w;return w;
    end
    ui.Interface=inspectionInterface;
    effectiveViewer=alice;
    assert(ui.canInspectStructureItem(DB.getPath(bag)) and not ui.canInspectStructureItem(DB.getPath(child)));
    for _,tab in ipairs({1,3})do
        ui.selectView(tab);assert(ui.inspectStructureItem(DB.getPath(bag)));
        assert(lastOpened.getClass()=="aptus_inventory_item_consult" and lastOpened.loaded and lastOpened.isInstanceLocked());
        lastOpened.onInstanceLockChanged(false);lastOpened.onPersistedLockChanged();assert(lastOpened.isInstanceLocked());
    end
    ui.selectView(4);assert(ui.inspectStructureItem(DB.getPath(vehicleItem)));
    assert(lastOpened.getClass()=="aptus_inventory_item_consult");
    assert(not ui.inspectStructureItem(DB.getPath(child)));
    access[DB.getPath(v).."Alice"]=false;lastOpened.onPermissionsChanged();assert(lastOpened.closed);
    access[DB.getPath(v).."Alice"]=true;
    assert(ui.inspectStructureItem(DB.getPath(inner)));local innerWindow=lastOpened;
    put(bag,"properties.hide_contents","number",1);ui.refreshPreview();assert(innerWindow.closed);
    put(bag,"properties.hide_contents","number",0);
    assert(ui.inspectStructureItem(DB.getPath(bag)));local contextWindow=lastOpened;
    effectiveViewer=host;ui.onStructureViewerChanged();assert(contextWindow.closed);
    assert(ui.inspectStructureItem(DB.getPath(child)) and lastOpened.getClass()=="aptus_inventory_item");
    lastOpened.close();
    effectiveViewer=alice;session.IsHost,session.UserName=false,"Alice";
    assert(ui.inspectStructureItem(DB.getPath(bag)) and lastOpened.getClass()=="aptus_inventory_item_consult");
    assert(not ui.inspectStructureItem(DB.getPath(child)));
    ui.onStructureViewerChanged();assert(lastOpened.closed);
    session.IsHost,session.UserName=true,"GM";
    assert(earlyContent>=5 and test.writes()==before);
    ui.onClose();independent.onClose();assert(test.writes()==before);
    -- Dos ventanas de personaje: variables locales de Lua separadas y propietario real.
    local character=test.newCharacter();character.owner="Alice";
    local other=test.newCharacter();other.owner="Bob";
    local dbProxy=setmetatable({getOwner=function(node)return node.owner or "";end},{__index=DB});
    local function window(node)
        local w={DB=dbProxy,Session=session,WindowTabManager={getTabDisplay=function()end},getDatabaseNode=function()return node;end};
        setmetatable(w,{__index=_G});w.self=w;
        assert(loadfile("scripts/char_container_aptus.lua","t",w))();return w;
    end
    local first,second=window(character),window(other);
    assert(first.getStructureViewer().mode=="host" and second.getStructureViewer().mode=="host");
    local btn={DB=dbProxy,Session=session,window={},WindowManager={getTopWindow=function()return first;end}};
    btn.setVisible=function(value)btn.visible=value;end;btn.setReadOnly=function()end;
    btn.setTooltipText=function(value)btn.tooltip=value;end;btn.setIcons=function(normal,pressed)btn.icon=normal;assert(normal==pressed);end;
    setmetatable(btn,{__index=_G});assert(loadfile("scripts/char_structure_preview_button.lua","t",btn))();
    first.overview={subwindow={aptus_impersonate_button=btn}};btn.onInit();
    assert(btn.visible and btn.tooltip=="Impersonar jugador (Alice)" and btn.icon=="aptus_impersonar_off");btn.onButtonPress();
    assert(first.getStructureViewer().username=="Alice" and first.getStructureViewer().mode=="player_preview");
    assert(second.getStructureViewer().mode=="host" and btn.icon=="aptus_impersonar_on");
    btn.onButtonPress();assert(btn.icon=="aptus_impersonar_off");
    btn.onButtonPress();assert(btn.icon=="aptus_impersonar_on");
    character.owner="Bob";first.refreshStructureViewer();assert(btn.tooltip=="Impersonar jugador (Bob)");
    character.owner="";first.refreshStructureViewer();assert(not btn.visible and first.getStructureViewer().mode=="host");
    character.owner="Alice";first.toggleStructureViewer();first.onClose();assert(window(character).getStructureViewer().mode=="host");
    assert(character.owner=="Alice" and session.IsHost and session.UserName=="GM" and test.writes()==before);
    -- Un jugador real no puede elevar su vista mediante un contexto host.
    session.IsHost,session.UserName=false,"Alice";
    assert(#structure.getVisibleStructures("locations",host)==1);
    btn.updateViewerUI();assert(not btn.visible);
    -- También el DJ real queda sin acciones desde la fila de consulta.
    session.IsHost,session.UserName=true,"GM";
    -- La fila de consulta no registra menús ni ejecuta ninguna acción.
    local readonly={getClass=function()return "aptus_structure_inventory_consult_row";end,
        registerMenuItem=function()error("Se registró una acción de edición");end};
    setmetatable(readonly,{__index=_G});assert(loadfile("scripts/char_equipment_row_aptus.lua","t",readonly))();readonly.onInit();
    assert(readonly.onMenuSelection(7)==false and readonly.editQuantity()==false and readonly.chooseLocation()==false);
    assert(readonly.chooseState()==false and readonly.openInstance()==false and readonly.startInventoryDrag({})==false);
    assert(readonly.onDrop(0,0,{})==true and test.writes()==before);
    -- Representación real de la fila: candado para DJ, Impersonar y jugador,
    -- gris propio y texto de Ubicación limitado sin perder su tooltip completo.
    for _,role in ipairs({{host=true,viewer=true},{host=true,viewer=false},{host=false,viewer=false}}) do
        local function widget(options)
            local w={text=options.text or "",visible=true};
            w.setText=function(value)w.text=value;end;w.setMaxWidth=function(value)w.limit=value;end;
            w.getSize=function()return math.min(#w.text*7,w.limit or 1000),14;end;
            w.setColor=function(value)w.color=value;end;w.setPosition=function()end;
            w.setVisible=function(value)w.visible=value;end;return w;
        end
        local function cell()
            local c=control();c.widgets={};c.setReadOnly=function()end;
            c.getFont=function()return "aptus_inventory_row_text";end;
            c.getSize=function()return 93,20;end;c.destroy=function()end;
            c.setTooltipText=function(value)c.tooltip=value;end;
            c.addTextWidget=function(options)local w=widget(options);table.insert(c.widgets,w);return w;end;
            c.addBitmapWidget=function(options)c.lock=widget(options);assert(options.icon=="padlock_closed" and options.w==12 and options.h==12);return c.lock;end;
            return c;
        end
        local r={Session={IsHost=role.host},APTUSInventoryManager=m,
            getClass=function()return "aptus_structure_inventory_consult_row";end,
            registerMenuItem=function()error("La consulta no registra menús");end,
            createControl=function()return cell();end};
        for _,key in ipairs({"type_icon","count","state","location","load","item_name"}) do r[key]=cell();end
        setmetatable(r,{__index=_G});assert(loadfile("scripts/char_equipment_row_aptus.lua","t",r))();r.onInit();
        local item={};for key,value in pairs(full.roots[1])do item[key]=value;end;
        item.hide_contents=true;item.viewer_is_host=role.viewer;item.location="Cofre de Seguridad con nombre muy largo";
        r.setPreview(item,false,false,false,true,{isReadOnlyInventory=function()return false;end},{following=false});
        assert(r.item_name.lock.visible and r.item_name.widgets[1].color=="FFB8B8B8" and r.item_name.widgets[2].color=="FFB8B8B8");
        assert(r.location.widgets[1].limit==93 and r.location.tooltip==item.location);
        item.hide_contents=false;r.setPreview(item,false,false,false,true,nil,{following=false});
        assert(not r.item_name.lock.visible and r.item_name.widgets[1].color==nil);
    end
    assert(test.writes()==before);
    m.APTUSStructureManager=previous;session.UserName,session.IsHost=oldName,oldHost;
    print("OK: consulta por categoría/usuario, mensajes, poda de ocultos, modo efímero independiente y acciones bloqueadas sin escrituras.");
end
