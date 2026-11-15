-- Gestor real sobre el doble DB existente. No se incluye en la extensión.
return function(test)
    local m, DB, put = test.manager, test.DB, test.put;
    local function template(id, own, capacity, stackable)
        local node=test.template("aptus_equipment_templates.state_"..id,"state:"..id);
        put(node,"name","string",id);
        put(node,"properties.load_every","number",1);
        put(node,"properties.load_value","number",own);
        put(node,"properties.stackable","number",stackable and 1 or 0);
        put(node,"properties.max_stack","number",stackable and 50 or 1);
        if capacity then
            put(node,"properties.type_id","string","storage");
            put(node,"properties.is_container","number",1);
            put(node,"properties.capacity","number",capacity);
        end
        return node;
    end
    local unit=template("unit",1);local bagTemplate=template("bag",2,5);
    local innerTemplate=template("inner",1,3);local ammo=template("ammo",1,nil,true);
    local function read(owner)
        local before=test.writes();local view=m.getCharacterInventory(owner);
        assert(test.writes()==before,"La lectura escribió en DB");return view;
    end
    local function find(owner,node)
        for _,item in ipairs(read(owner).items) do if item.node==node then return item; end end
        error("Objeto ausente");
    end
    local owner=test.newCharacter();local item=assert(m.createFromTemplate(owner,unit,4));
    for _,state in ipairs({0,2,1}) do
        assert(m.setState(item,state));
        assert(DB.getValue(item,"carried")==state and (DB.getValue(item,"aptus.container","")==""));
        assert(read(owner).total_load==(state==0 and 0 or 4));
        local before=test.writes();assert(m.setState(item,state));assert(test.writes()==before);
        before=test.writes();assert(m.transfer(item,owner));assert(test.writes()==before);
    end
    local bag=assert(m.createFromTemplate(owner,bagTemplate));
    assert(m.transfer(item,owner,nil,bag));
    assert(DB.getValue(item,"carried")==0 and find(owner,item).state=="Contenido");
    assert(find(owner,bag).content_load==4 and read(owner).total_load==2);
    local before=test.writes();assert(m.setState(item,0));assert(test.writes()==before);
    -- Compatibilidad: estados almacenados antiguos no se reescriben al leer.
    put(item,"carried","number",2);before=test.writes();
    assert(find(owner,item).effective_carried==0 and read(owner).total_load==2);
    assert(test.writes()==before and DB.getValue(item,"carried")==2);
    assert(m.transfer(item,owner,nil,bag));assert(test.writes()==before);
    assert(m.transfer(item,owner));assert(DB.getValue(item,"carried")==1);
    for _,state in ipairs({2,1}) do
        assert(m.transfer(item,owner,nil,bag));assert(m.setState(item,state));
        assert(DB.getValue(item,"carried")==state and DB.getValue(item,"aptus.container","")=="");
        assert(read(owner).total_load==6);
    end
    -- Cambio entre contenedores y extracción de un árbol: relaciones internas intactas.
    local nested=test.newCharacter();local outer=assert(m.createFromTemplate(nested,bagTemplate));
    local inner=assert(m.createFromTemplate(nested,innerTemplate,1,outer));
    local leaf=assert(m.createFromTemplate(nested,unit,3,inner));
    put(leaf,"carried","number",2);
    assert(find(nested,outer).content_load==4 and find(nested,inner).effective_load==4);
    assert(read(nested).total_load==2);
    assert(m.setState(outer,0));assert(read(nested).total_load==0);
    assert(find(nested,outer).content_load==4);
    assert(m.setState(outer,1));assert(m.setState(inner,2));
    assert(DB.getValue(leaf,"aptus.container")==DB.getName(inner));
    assert(DB.getValue(inner,"carried")==2 and read(nested).total_load==3);
    assert(m.transfer(inner,nested,nil,outer));assert(DB.getValue(inner,"carried")==0);
    -- Fallo al extraer: se restaura padre y carried, también para contenedores llenos.
    local token=m.getInstanceEditToken(inner);test.fail(DB.getPath(inner,"carried"));
    assert(not m.setState(inner,2));assert(m.getInstanceEditToken(inner)==token);
    token=m.getInstanceEditToken(leaf);test.fail(DB.getPath(leaf,"carried"));
    assert(not m.setState(leaf,1));assert(m.getInstanceEditToken(leaf)==token);
    -- Estado destino participa en la fusión: no fusionar con otra pila de estado distinto.
    local piles=test.newCharacter();local storage=assert(m.createFromTemplate(piles,bagTemplate));
    local loose=assert(m.createFromTemplate(piles,ammo,10));assert(m.setState(loose,2));
    local carried=assert(m.createFromTemplate(piles,ammo,5));
    local contained=assert(m.createFromTemplate(piles,ammo,3,storage));
    assert(m.setState(contained,1));
    assert(DB.getValue(loose,"count")==10 and DB.getValue(loose,"carried")==2);
    assert(DB.getValue(carried,"count")==8 and DB.getValue(carried,"carried")==1);
    -- Selección directa/cancelación: configurar no escribe; sólo el callback confirma.
    local previousInterface=m.Interface;local callback,current,closed;
    m.Interface={findWindow=function() end,openWindow=function(class,path)
        assert(class=="aptus_inventory_state" and path=="");
        return {configure=function(value,apply) current,callback=value,apply; end};
    end};
    before=test.writes();m.requestState(item);assert(current==1 and callback and test.writes()==before);
    callback=nil;assert(test.writes()==before); -- cerrar sin seleccionar
    local notified;m.requestState(item,function(ok) notified=ok; end);callback(0);
    assert(notified and DB.getValue(item,"carried")==0);
    m.requestState(item,function(ok) notified=ok; end);put(item,"count","number",3);
    before=test.writes();callback(2);assert(not notified and test.writes()==before);
    -- Diálogo real: cierre sin callback y una sola aplicación aunque se repita el evento.
    local env={close=function() closed=true; end};setmetatable(env,{__index=_G});env.self=env;
    for value=0,2 do env["current_"..value]={setVisible=function() end};end
    assert(loadfile("scripts/inventory_state_aptus.lua","t",env))();
    local calls=0;env.configure(2,function(value) calls=calls+1;assert(value==1); end);
    assert(calls==0);env.onClose();env.selectState(1);assert(calls==0);
    env.configure(2,function(value) calls=calls+1;assert(value==1); end);
    env.selectState(1);env.selectState(1);assert(closed and calls==1);
    m.Interface=previousInterface;
    -- Operación compuesta: un único final lógico, después de las escrituras internas.
    local completed=0;local function finished() assert(not m.isUpdatingInventory());completed=completed+1;end
    m.addOperationListener(finished);assert(m.setState(item,1));assert(completed==1);
    m.removeOperationListener(finished);
    local stateField=DB.getChild(item,"carried");stateField.readonly=true;
    before=test.writes();assert(not m.setState(item,2));assert(test.writes()==before);stateField.readonly=nil;
    assert(not m.setState(item,3));
    print("OK: estados directos, no-op, contenido, extracción, Almacenaje, fusiones, permisos, recuperación, diálogo y operación lógica única.");
end
