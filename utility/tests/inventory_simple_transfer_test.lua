-- Lógica real del motor/OOB con dobles DB y transporte. No se ejecuta en campañas.
return function(test)
    local m,DB,session,put=test.manager,test.DB,test.Session,test.put;
    local oldHost,oldUser=session.IsHost,session.UserName;
    local oldStructures,oldPermissions,oldOOB,oldComm,oldChat=m.APTUSStructureManager,m.APTUSLocationPermissions,m.OOBManager,m.Comm,m.ChatManager;
    session.IsHost,session.UserName=true,"GM";
    local visible,access={},{};
    local permissions={hasVisibility=function(node,user)return visible[DB.getPath(node)..user]==true;end,
        hasAccess=function(node,user)return visible[DB.getPath(node)..user]==true and access[DB.getPath(node)..user]==true;end};
    local structures={DB=DB,Session=session,APTUSLocationPermissions=permissions,
        WindowManager={getReadOnlyState=function()return false;end},
        RecordDataManager={getRecordTypeFromRecordPath=function(path)return path:match("^aptus_structures%.[^.@]+$") and "aptus_structure" or "";end}};
    setmetatable(structures,{__index=_G});assert(loadfile("scripts/manager_aptus_structure.lua","t",structures))();
    structures.registerFeature("storage",{name="Almacenaje",implemented=true});
    structures.registerType("location",{name="Localización",category="locations",icon="test",skin="default"});
    structures.registerType("vehicle",{name="Vehículo",category="vehicles",icon="test",skin="default"});
    m.APTUSStructureManager,m.APTUSLocationPermissions=structures,permissions;
    local handlers,wire,notices={},{},{};
    m.OOBManager={registerOOBMsgHandler=function(kind,callback)handlers[kind]=callback;end};
    m.Comm={deliverOOBMessage=function(packet,recipient)table.insert(wire,{packet=packet,recipient=recipient});end};
    m.ChatManager={SystemMessage=function(message)table.insert(notices,message);end};m.onInit();
    local serial=0;
    local function owner(kind,user)
        if kind=="character" then
            local node=test.newCharacter();node.owner=user;put(node,"attributes.fue.effective","number",2);return node;
        end
        serial=serial+1;local node=test.newStructure("simple_"..serial);
        put(node,"type","string",kind);put(node,"name","string",kind..serial);put(node,"features.storage.enabled","number",1);
        visible[DB.getPath(node).."Alice"],access[DB.getPath(node).."Alice"]=true,true;return node;
    end
    local ammo=test.template("aptus_equipment_templates.simple_ammo","simple:9mm@initial");
    put(ammo,"properties.type_id","string","ammunition");put(ammo,"properties.stackable","number",1);
    put(ammo,"properties.max_stack","number",50);put(ammo,"properties.load_every","number",50);put(ammo,"properties.load_value","number",1);
    local otherAmmo=test.template("aptus_equipment_templates.simple_other_ammo","simple:45@initial");
    put(otherAmmo,"properties.type_id","string","ammunition");put(otherAmmo,"properties.stackable","number",1);
    put(otherAmmo,"properties.max_stack","number",50);put(otherAmmo,"properties.load_every","number",50);put(otherAmmo,"properties.load_value","number",1);
    local boxTemplate=test.template("aptus_equipment_templates.simple_box","simple:box");
    put(boxTemplate,"properties.type_id","string","storage");put(boxTemplate,"properties.is_container","number",1);
    put(boxTemplate,"properties.stackable","number",0);put(boxTemplate,"properties.max_stack","number",1);
    put(boxTemplate,"properties.capacity","number",5);put(boxTemplate,"properties.load_value","number",2);
    local function seed(destination,count,template,parent)return assert(m.createFromTemplate(destination,template or ammo,count or 1,parent));end
    local function total(destination)
        local count=0;for _,item in ipairs(m.getCharacterInventory(destination).items)do count=count+item.count;end;return count;
    end
    local function submit(request,context)
        local out;assert(m.submitSimpleTransferRequest(request,function(result)out=result;end,context));assert(out,"Faltó resultado de anfitrión");return out;
    end
    local function move(node,destination,count,parent,context)
        local request,problem=m.buildSimpleTransferRequest(node,destination,count,parent,context);assert(request,problem);
        return submit(request,context),request;
    end
    -- Matriz administrativa completa: origen/destino, propiedades y estados.
    for _,pair in ipairs({{"character","location"},{"location","character"},{"character","vehicle"},{"vehicle","character"},
        {"location","location"},{"location","vehicle"},{"vehicle","location"},{"vehicle","vehicle"},{"character","character"}})do
        local sourceOwner,target=owner(pair[1],"Alice"),owner(pair[2],"Bob");local node=seed(sourceOwner,3);
        local originalPath=DB.getPath(node);local out=move(node,target,3);
        assert(out.ok and out.status=="success" and not DB.findNode(originalPath));
        local result=assert(DB.findNode(out.result_path));
        assert(m.getInventoryOwner(result)==target and DB.getValue(result,"count")==3);
        assert(DB.getValue(result,"carried")== (pair[2]=="character" and 1 or 0));
        assert(DB.getValue(result,"template_id")=="simple:9mm@initial" and DB.getValue(result,"properties.extra")=="Propiedad particular desconocida");
        assert(total(sourceOwner)==0 and total(target)==3);
    end
    -- Parcial y fusión: llenar 30 hasta 50 y crear 20, conservando 70 unidades.
    local sourceOwner,target=owner("character","Alice"),owner("location");local source=seed(sourceOwner,40);seed(target,30);
    local out=move(source,target,40);assert(out.ok and total(target)==70 and total(sourceOwner)==0);
    local counts={};for _,item in ipairs(m.getCharacterInventory(target).items)do table.insert(counts,item.count);assert(item.count<=50);end
    table.sort(counts);assert(#counts==2 and counts[1]==20 and counts[2]==50);
    sourceOwner,target=owner("location"),owner("vehicle");source=seed(sourceOwner,10);
    out=move(source,target,4);assert(out.ok and DB.getValue(source,"count")==6 and total(target)==4 and total(sourceOwner)==6);
    -- Entrada heredada sobredimensionada: distribuir usando max_stack existente.
    sourceOwner,target=owner("location"),owner("vehicle");source=seed(sourceOwner);put(source,"count","number",120);
    out=move(source,target,120);assert(out.ok and total(target)==120);
    counts={};for _,item in ipairs(m.getCharacterInventory(target).items)do assert(item.count<=50);table.insert(counts,item.count);end
    table.sort(counts);assert(#counts==3 and counts[1]==20 and counts[2]==50 and counts[3]==50);
    -- Identidad de plantilla: misma categoría/nombre/carga no basta para fusionar.
    sourceOwner,target=owner("location"),owner("location");source=seed(sourceOwner,5);seed(target,3,otherAmmo);
    out=move(source,target,5);assert(out.ok and #m.getCharacterInventory(target).items==2 and total(target)==8);
    -- Contenedor destino anidado: estado cero, reducción y CARGA real sin límite duro.
    sourceOwner,target=owner("vehicle"),owner("character","Alice");source=seed(sourceOwner,40);
    local box=seed(target,1,boxTemplate);local bag=seed(target,1,boxTemplate,box);
    out=move(source,target,40,bag);assert(out.ok);
    local result=DB.findNode(out.result_path);assert(DB.getValue(result,"carried")==0 and DB.getValue(result,"aptus.container")==DB.getName(bag));
    local inventory=m.getCharacterInventory(target);local status=m.getLoadStatus(target,inventory);
    assert(status.total_load==2 and status.capacity==6);
    -- Un contenedor vacío viaja como una instancia; conservar hide_contents.
    sourceOwner,target=owner("location"),owner("vehicle");source=seed(sourceOwner,1,boxTemplate);put(source,"properties.hide_contents","number",1);
    out=move(source,target,1);assert(out.ok and DB.getValue(DB.findNode(out.result_path),"properties.hide_contents")==1);
    -- No apilables permanecen no apilables, sin fusiones artificiales.
    local tool=test.template("aptus_equipment_templates.simple_tool","simple:tool");
    sourceOwner,target=owner("location"),owner("vehicle");source=seed(sourceOwner,1,tool);seed(target,1,tool);
    out=move(source,target,1);assert(out.ok and #m.getCharacterInventory(target).items==2);
    -- Contenido directo/incompatible también impide mover un contenedor.
    sourceOwner,target=owner("location"),owner("vehicle");source=seed(sourceOwner,1,boxTemplate);seed(sourceOwner,1,ammo,source);
    local before=test.writes();out=move(source,target,1);assert(not out.ok and test.writes()==before and total(target)==0);
    -- Replay/id duplicado: mismo resultado, ninguna segunda ejecución.
    sourceOwner,target=owner("location"),owner("vehicle");source=seed(sourceOwner,5);
    local first,request=move(source,target,5);before=test.writes();out=submit(request);
    assert(first.ok and out.ok and out.replayed and test.writes()==before and total(target)==5);
    local changed={};for key,value in pairs(request)do changed[key]=value;end;changed.quantity="1";
    out=submit(changed);assert(not out.ok and test.writes()==before);
    -- Dos solicitudes válidas al abrir el diálogo: sólo la primera consume el origen.
    sourceOwner,target=owner("location"),owner("vehicle");source=seed(sourceOwner,1);
    local r1=assert(m.buildSimpleTransferRequest(source,target,1));local r2=assert(m.buildSimpleTransferRequest(source,target,1));
    assert(submit(r1).ok);before=test.writes();assert(not submit(r2).ok and test.writes()==before and total(target)==1);
    sourceOwner,target=owner("location"),owner("vehicle");source=seed(sourceOwner,10);
    r1=assert(m.buildSimpleTransferRequest(source,target,4));r2=assert(m.buildSimpleTransferRequest(source,target,7));
    assert(submit(r1).ok);before=test.writes();assert(not submit(r2).ok and test.writes()==before and DB.getValue(source,"count")==6);
    -- Revisión y ubicación desactualizadas se rechazan sin incorporar nada.
    r1=assert(m.buildSimpleTransferRequest(source,target,1));put(source,"properties.description","string","Cambió");
    before=test.writes();assert(not submit(r1).ok and test.writes()==before);
    r1=assert(m.buildSimpleTransferRequest(source,target,1));r1.source_parent="inexistente";
    assert(not submit(r1).ok and test.writes()==before);
    -- Reentrada durante una escritura: la segunda solicitud espera al final de la primera.
    sourceOwner,target=owner("location"),owner("vehicle");source=seed(sourceOwner,1);
    local nextSource=seed(sourceOwner,1,otherAmmo);
    r1=assert(m.buildSimpleTransferRequest(source,target,1));r2=assert(m.buildSimpleTransferRequest(nextSource,target,1));
    local originalSet=DB.setValue;local enqueued=false;local order={};
    DB.setValue=function(node,path,kind,value,record)
        local result=originalSet(node,path,kind,value,record);
        if not enqueued and DB.getPath(node):find(DB.getPath(target)..".inventorylist",1,true)==1 then
            enqueued=true;assert(m.isUpdatingInventory());
            assert(m.submitSimpleTransferRequest(r2,function(reply)assert(reply.ok);table.insert(order,"second");end));
            assert(#order==0);
        end
        return result;
    end;
    assert(m.submitSimpleTransferRequest(r1,function(reply)assert(reply.ok);table.insert(order,"first");end));
    DB.setValue=originalSet;assert(enqueued and order[1]=="first" and order[2]=="second" and total(target)==2);
    -- Actor efectivo: Acceso permite transferencia, no edición arbitraria.
    local contextValid=true;local character=owner("character","Alice");local otherCharacter=owner("character","Alice");
    local ctx={aptus_inventory_context=true,actor_real="GM",actor_effective="Alice",username="Alice",mode="player_preview",impersonating=true,
        character_path=DB.getPath(character),isValid=function()return contextValid;end};
    sourceOwner=owner("location");source=seed(sourceOwner,4);out=move(source,character,2,nil,ctx);
    assert(out.ok and DB.getValue(source,"count")==2 and total(character)==2 and not m.canEditInstance(source,ctx));
    local ownItem=m.getCharacterInventory(character).items[1].node;
    assert(not m.buildSimpleTransferRequest(ownItem,otherCharacter,1,nil,ctx));
    r1=assert(m.buildSimpleTransferRequest(source,character,1,nil,ctx));access[DB.getPath(sourceOwner).."Alice"]=false;
    before=test.writes();assert(not submit(r1,ctx).ok and test.writes()==before);access[DB.getPath(sourceOwner).."Alice"]=true;
    visible[DB.getPath(sourceOwner).."Alice"]=false;assert(not m.buildSimpleTransferRequest(source,character,1,nil,ctx));visible[DB.getPath(sourceOwner).."Alice"]=true;
    put(sourceOwner,"features.storage.enabled","number",0);assert(not m.buildSimpleTransferRequest(source,character,1,nil,ctx));put(sourceOwner,"features.storage.enabled","number",1);
    local hidden=seed(sourceOwner,1,boxTemplate);local inside=seed(sourceOwner,1,ammo,hidden);put(hidden,"properties.hide_contents","number",1);
    assert(not m.buildSimpleTransferRequest(inside,character,1,nil,ctx));assert(not m.buildSimpleTransferRequest(ownItem,sourceOwner,1,hidden,ctx));
    r1=assert(m.buildSimpleTransferRequest(source,character,1,nil,ctx));contextValid=false;before=test.writes();
    assert(not m.submitSimpleTransferRequest(r1,function()error("No debe ejecutarse");end,ctx) and test.writes()==before);contextValid=true;
    -- Fallo al copiar: origen intacto. Fallos al retirar: destino verificado permanece.
    sourceOwner,target=owner("location"),owner("vehicle");source=seed(sourceOwner,3);
    test.fail(DB.getPath(target)..".inventorylist.id-00001.properties.description");out=move(source,target,3);
    assert(not out.ok and DB.getValue(source,"count")==3 and total(target)==0);
    test.fail(DB.getPath(source));local noticeBefore=#notices;out,request=move(source,target,3);
    assert(not out.ok and out.status=="uncertain" and total(target)==3 and DB.getValue(source,"count")==3 and #notices==noticeBefore+1);
    before=test.writes();assert(submit(request).replayed and test.writes()==before and #notices==noticeBefore+1);
    sourceOwner,target=owner("location"),owner("vehicle");source=seed(sourceOwner,10);
    test.fail(DB.getPath(source)..".count");out=move(source,target,4);
    assert(out.status=="uncertain" and total(target)==4 and DB.getValue(source,"count")==10);
    -- Error después de un borrado efectivo: verificar desaparición evita falsa recuperación.
    sourceOwner,target=owner("location"),owner("vehicle");source=seed(sourceOwner,1);
    local deletingPath=DB.getPath(source);local originalDelete=DB.deleteNode;
    DB.deleteNode=function(node)originalDelete(node);if DB.getPath(node)==deletingPath then error("fallo tras borrar");end end;
    out=move(source,target,1);DB.deleteNode=originalDelete;
    assert(out.ok and total(target)==1 and not DB.findNode(deletingPath));
    -- Actualización final agrupada y CARGA propia del personaje.
    sourceOwner,target=owner("character","Alice"),owner("character","Bob");source=seed(sourceOwner,3);put(source,"carried","number",2);
    local refreshes,observedSource,observedTarget=0;local function changedInventory()
        refreshes=refreshes+1;observedSource=m.getLoadStatus(sourceOwner).total_load;observedTarget=m.getLoadStatus(target).total_load;
    end
    m.addOperationListener(changedInventory);out=move(source,target,3);m.removeOperationListener(changedInventory);
    assert(out.ok and refreshes==1 and observedSource==0 and observedTarget==1 and DB.getValue(DB.findNode(out.result_path),"carried")==1);
    -- OOB real: cliente no escribe, host ejecuta, respuesta dirigida; repetición sin consumir.
    sourceOwner=owner("location");target=owner("character","Alice");source=seed(sourceOwner,2);
    session.IsHost,session.UserName=false,"Alice";m.onInit();wire={};local clientResult;
    request=assert(m.buildSimpleTransferRequest(source,target,1));before=test.writes();
    assert(m.submitSimpleTransferRequest(request,function(value)clientResult=value;end));
    assert(test.writes()==before and #wire==1 and not clientResult);
    assert(not request.properties and not request.children and not request.expected_revision:find("Descripción",1,true));
    session.IsHost,session.UserName=true,"GM";handlers[wire[1].packet.type](wire[1].packet);
    assert(#wire==2 and wire[2].recipient=="Alice" and total(target)==1 and DB.getValue(source,"count")==1);
    session.IsHost,session.UserName=false,"Alice";handlers[wire[2].packet.type](wire[2].packet);
    assert(clientResult and clientResult.ok and not clientResult.replayed);
    wire={};clientResult=nil;assert(m.submitSimpleTransferRequest(request,function(value)clientResult=value;end));
    session.IsHost,session.UserName=true,"GM";before=test.writes();handlers[wire[1].packet.type](wire[1].packet);
    assert(test.writes()==before);session.IsHost,session.UserName=false,"Alice";handlers[wire[2].packet.type](wire[2].packet);
    assert(clientResult.ok and clientResult.replayed);
    m.APTUSStructureManager,m.APTUSLocationPermissions,m.OOBManager,m.Comm,m.ChatManager=oldStructures,oldPermissions,oldOOB,oldComm,oldChat;
    session.IsHost,session.UserName=oldHost,oldUser;
    print("OK transferencias simples: matriz, parciales, fusión, max_stack, estados/CARGA, actores, OOB, revisiones, repetición y fallos sin retirada prematura.");
end
