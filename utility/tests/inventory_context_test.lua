-- Contexto/autorización reales, DB en memoria. Ejecutar mediante inventory_create_test.lua.
return function(test)
    local m,DB,session,put=test.manager,test.DB,test.Session,test.put;
    local oldHost,oldName=session.IsHost,session.UserName;
    session.IsHost,session.UserName=true,"GM";
    local a,b=test.newCharacter(),test.newCharacter();a.owner,b.owner="Alice","Bob";
    local function window(node)
        local w={DB=DB,Session=session,getDatabaseNode=function()return node;end,
            WindowTabManager={getTabDisplay=function()return nil;end}};
        setmetatable(w,{__index=_G});w.self=w;
        assert(loadfile("scripts/char_container_aptus.lua","t",w))();return w;
    end
    local wa,wb=window(a),window(b);
    local host=wa.getInventoryContext();assert(host.actor_real=="GM" and host.actor_effective=="GM" and not host.impersonating);
    local invalidA,invalidB=0,0;
    host.onInvalidate(function()invalidA=invalidA+1;end);
    wb.getInventoryContext().onInvalidate(function()invalidB=invalidB+1;end);
    assert(m.canManageInventory(a,host) and m.canManageInventory(b,host));
    wa.toggleStructureViewer();local ctx=wa.getInventoryContext();
    assert(invalidA==1 and invalidB==0);
    assert(ctx.actor_real=="GM" and ctx.actor_effective=="Alice" and ctx.character_path==DB.getPath(a) and ctx.impersonating);
    assert(not m.isContextValid(host) and m.isContextValid(ctx));
    assert(wb.getInventoryContext().mode=="host" and m.canManageInventory(a,ctx) and not m.canManageInventory(b,ctx));
    local template=test.template("aptus_equipment_templates.context_stack","ctx:stack");
    put(template,"properties.stackable","number",1);put(template,"properties.max_stack","number",50);
    put(template,"properties.load_every","number",1);put(template,"properties.load_value","number",1);
    local item=assert(m.createFromTemplate(a,template,3,nil,ctx));
    local countBefore=test.writes();assert(not m.createFromTemplate(b,template,1,nil,ctx));assert(test.writes()==countBefore);
    assert(m.setQuantity(item,4,ctx));assert(DB.getValue(item,"count")==4);
    assert(m.createFromTemplate(a,template,2,nil,ctx));assert(DB.getValue(item,"count")==6);
    assert(m.mergeStacks(item,ctx) and DB.getValue(item,"count")==6);
    assert(m.setState(item,2,ctx));assert(DB.getValue(item,"carried")==2);
    assert(m.setState(item,1,ctx));
    local boxTemplate=test.template("aptus_equipment_templates.context_box","ctx:box");
    put(boxTemplate,"properties.type_id","string","storage");put(boxTemplate,"properties.is_container","number",1);
    put(boxTemplate,"properties.stackable","number",0);put(boxTemplate,"properties.capacity","number",5);
    local box=assert(m.createFromTemplate(a,boxTemplate,1));
    local inner=assert(m.createFromTemplate(a,template,1,box));
    put(box,"properties.hide_contents","number",1);
    assert(m.canViewInstance(box,ctx) and not m.canViewInstance(inner,ctx));
    assert(not m.canSelectTransferDestination(a,box,item,ctx));
    assert(m.canSelectTransferSource(box,ctx) and not m.canSelectTransferSource(inner,ctx));
    assert(m.canTransfer(item,a,1,nil,ctx) and not m.canTransfer(item,b,1,nil,ctx));
    assert(not m.canSelectTransferDestination(a,box,box,ctx));
    local before=test.writes();local filtered=m.getCharacterInventory(a,ctx);
    assert(#filtered.items==3 and test.writes()==before);
    for _,entry in ipairs(filtered.items)do if entry.node==inner then assert(not entry.visible_to_user);end end
    assert(not m.setQuantity(inner,2,ctx) and not m.setState(inner,1,ctx));assert(test.writes()==before);
    local draft=m.getInstanceDraft(item);draft.name="Particular";
    assert(m.saveInstance(item,draft,m.getInstanceEditToken(item),ctx));
    put(box,"properties.hide_contents","number",0);
    assert(m.transfer(item,a,nil,box,nil,ctx));assert(DB.getValue(item,"carried")==0);
    assert(DB.getValue(item,"aptus.container")==DB.getName(box));
    assert(m.setState(item,1,ctx));assert(DB.getValue(item,"carried")==1);
    assert((DB.getValue(item,"aptus.container","") or "")=="" and DB.getValue(item,"count")==6);
    put(box,"properties.hide_contents","number",1);
    local hiddenDraft=m.getInstanceDraft(box);hiddenDraft.hide_contents=0;before=test.writes();
    assert(not m.saveInstance(box,hiddenDraft,m.getInstanceEditToken(box),ctx));assert(test.writes()==before);
    -- Ventana independiente sin contexto conserva permisos reales del DJ.
    assert(m.canViewInstance(inner) and m.canEditInstance(inner));assert(m.setQuantity(inner,2));
    -- Comparación con jugador real para lectura/edición de su personaje.
    session.IsHost,session.UserName=false,"Alice";
    local client=window(a).getInventoryContext();
    assert(not client.impersonating and m.canManageInventory(a,client) and not m.canManageInventory(b,client));
    assert(m.canViewInstance(box,client) and not m.canViewInstance(inner,client));
    assert(m.canEditInstance(item,client) and not m.canEditInstance(inner,client));
    session.IsHost,session.UserName=true,"GM";
    -- Acceso a estructuras prepara transferencias pero no habilita edición ni ejecución cruzada.
    local oldStructures,oldPermissions=m.APTUSStructureManager,m.APTUSLocationPermissions;
    local access,visible=true,true;
    local permissions={hasVisibility=function(_,user)return user=="Alice" and visible;end,
        hasAccess=function(_,user)return user=="Alice" and visible and access;end};
    local structures={DB=DB,Session=session,APTUSLocationPermissions=permissions,
        RecordDataManager={getRecordTypeFromRecordPath=function(path)return path:match("^aptus_structures%.[^.@]+$") and "aptus_structure" or "";end},
        WindowManager={getReadOnlyState=function()return false;end}};
    setmetatable(structures,{__index=_G});assert(loadfile("scripts/manager_aptus_structure.lua","t",structures))();
    structures.registerFeature("storage",{name="Almacenaje",implemented=true});
    structures.registerType("location",{name="Localización",category="locations",icon="test",skin="default"});
    m.APTUSStructureManager,m.APTUSLocationPermissions=structures,permissions;
    local structure=test.newStructure("context_location");put(structure,"type","string","location");
    put(structure,"features.storage.enabled","number",1);
    local resource=assert(m.createFromTemplate(structure,template,2));
    ctx=wa.getInventoryContext();assert(m.canAccessInventory(structure,ctx));
    assert(m.canSelectTransferSource(resource,ctx) and m.canTransfer(resource,a,1,nil,ctx));
    assert(m.canSelectTransferDestination(structure,nil,item,ctx));
    before=test.writes();assert(not m.canEditInstance(resource,ctx));assert(not m.setQuantity(resource,3,ctx));
    assert(not m.transfer(resource,a,1,nil,nil,ctx));assert(test.writes()==before);
    access=false;assert(not m.canAccessInventory(structure,ctx));access=true;
    visible=false;assert(not m.canReadInventory(structure,ctx));visible=true;
    put(structure,"features.storage.enabled","number",0);assert(not m.canSelectTransferDestination(structure,nil,item,ctx));
    put(structure,"features.storage.enabled","number",1);
    assert(m.canManageInventory(structure) and m.setQuantity(resource,3));
    m.APTUSStructureManager,m.APTUSLocationPermissions=oldStructures,oldPermissions;
    -- Diálogos pendientes: cantidad, Estado, Ubicación y confirmación de eliminación.
    local oldInterface,oldDialogs,oldChat=m.Interface,m.DialogManager,m.ChatManager;
    local pending;
    m.ChatManager={SystemMessage=function()end};
    m.Interface={findWindow=function()return nil;end,openWindow=function(class)
        return {configure=function(first,second,third)pending=third or second;end,
            requestSelectionByData=function(data)pending=data.callback;end};
    end};
    local function invalidate()wa.toggleStructureViewer();end
    local function preview()if wa.getStructureViewer().mode~="player_preview"then wa.toggleStructureViewer();end;return wa.getInventoryContext();end
    ctx=preview();m.requestSetQuantity(item,ctx);local callback=pending;invalidate();before=test.writes();callback(20);assert(test.writes()==before);
    ctx=preview();m.requestState(item,function()end,ctx);callback=pending;invalidate();before=test.writes();callback(2);assert(test.writes()==before);
    ctx=preview();m.requestLocation(item,function()end,ctx);callback=pending;invalidate();before=test.writes();
    callback({},nil,{{linkclass="charsheet",linkrecord=DB.getPath(a)}});assert(test.writes()==before);
    m.DialogManager={openDialog=function(_,data)pending=data.fnCallback;end};
    ctx=preview();assert(m.requestDeleteInstance(item,function()end,nil,ctx));callback=pending;invalidate();before=test.writes();callback("ok");assert(test.writes()==before);
    -- Cancelar sólo la entrada del selector de esta ficha, sin cerrar una cola ajena.
    local previousInterface=m.Interface;local activeSelector;
    m.Interface={findWindow=function(class)if class=="aptus_inventory_location"then return activeSelector;end end};
    local foreign,ownSelection={},{};local queue={foreign,ownSelection};local activated=0;
    activeSelector={getSelectionQueue=function()return queue;end,activateNextSelection=function()activated=activated+1;end};
    ctx=preview();m.trackContextDialog(ctx,activeSelector,"aptus_inventory_location",ownSelection);invalidate();
    assert(#queue==1 and queue[1]==foreign and activated==0);
    ownSelection={};queue={ownSelection,foreign};
    ctx=preview();m.trackContextDialog(ctx,activeSelector,"aptus_inventory_location",ownSelection);invalidate();
    assert(#queue==1 and queue[1]==foreign and activated==1);
    m.Interface=previousInterface;
    -- Misma ficha reutilizada: el objeto propio es editable en Impersonar,
    -- sin imponer consulta incondicional ni permitir escrituras con contexto antiguo.
    ctx=preview();local sheet={DB=DB,Session=session,APTUSInventoryManager=m,
        getClass=function()return "aptus_inventory_item_consult";end,getDatabaseNode=function()return item;end,
        super={onInit=function()end},content={setValue=function()end}};
    sheet.close=function()if not sheet.closed then sheet.closed=true;sheet.onClose();end end;
    setmetatable(sheet,{__index=_G});sheet.self=sheet;
    assert(loadfile("scripts/inventory_item_window_aptus.lua","t",sheet))();sheet.onInit();
    sheet.configureInspection({canInspectItem=function(path,context)return m.canViewInstance(DB.findNode(path),context);end,
        forgetInspection=function()end},ctx);
    assert(not sheet.isInspectionOnly() and sheet.isInstanceLocked());
    sheet.onInstanceLockChanged(false);assert(not sheet.isInstanceLocked() and m.canEditInstance(item,ctx));
    invalidate();before=test.writes();sheet.onInstanceLockChanged(false);assert(test.writes()==before);
    assert(not sheet.canViewInWindow() and m.canEditInstance(item));sheet.onInventoryChanged();assert(sheet.closed);
    -- No vuelve a ser válido un contexto antiguo aunque se restaure el mismo modo.
    wa.toggleStructureViewer();assert(not m.isContextValid(ctx));
    local current=wa.getInventoryContext();a.owner="Carol";assert(not m.isContextValid(current));a.owner="Alice";
    current=wa.getInventoryContext();wa.onClose();assert(not m.isContextValid(current));
    assert(wb.getInventoryContext().mode=="host");
    m.Interface,m.DialogManager,m.ChatManager=oldInterface,oldDialogs,oldChat;
    session.IsHost,session.UserName=oldHost,oldName;
    print("OK contexto: actores, permisos efectivos, dos fichas, ocultación, acciones reales propias, diálogos obsoletos rechazados e independientes intactas.");
end
