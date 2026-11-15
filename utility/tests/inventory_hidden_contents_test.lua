-- Se ejecuta desde inventory_create_test.lua. DB en memoria; nunca en una campaña.
return function(test)
    local m,DB,put,session=test.manager,test.DB,test.put,test.Session;
    local function template(id,load,capacity)
        local node=test.template("aptus_equipment_templates.hidden_"..id,"hidden:"..id);
        put(node,"name","string",id);
        put(node,"properties.load_value","number",load);
        put(node,"properties.load_every","number",1);
        if capacity then
            put(node,"properties.type_id","string","storage");
            put(node,"properties.is_container","number",1);
            put(node,"properties.capacity","number",capacity);
        end
        return node;
    end
    local owner=test.newCharacter();local bagTemplate=template("Mochila",2,5);
    local boxTemplate=template("Caja",1,3);local innerTemplate=template("Interior",1,10);
    local lampTemplate=template("Linterna",1);local itemTemplate=template("Diario",4);
    local bag=assert(m.createFromTemplate(owner,bagTemplate));
    local lamp=assert(m.createFromTemplate(owner,lampTemplate,1,bag));
    local box=assert(m.createFromTemplate(owner,boxTemplate,1,bag));
    local inner=assert(m.createFromTemplate(owner,innerTemplate,1,box));
    local item=assert(m.createFromTemplate(owner,itemTemplate,1,inner));
    local function read()
        local before=test.writes();local view=m.getCharacterInventory(owner);
        assert(test.writes()==before);return view;
    end
    local function visible()
        local count=0;for _,entry in ipairs(read().items) do if entry.visible_to_user then count=count+1;end;end
        return count;
    end
    local function hide(node,value)
        local draft=m.getInstanceDraft(node);draft.hide_contents=value;
        assert(m.saveInstance(node,draft,m.getInstanceEditToken(node)));
    end
    assert(m.getInstanceDraft(box).hide_contents==0);
    assert(not DB.getChild(box,"properties.hide_contents")); -- no se crea al leer
    local originalLoad=read().total_load;assert(originalLoad==9);
    hide(box,1);assert(DB.getValue(box,"properties.hide_contents")==1);
    assert(visible()==5 and m.canViewInstance(item)); -- DJ
    session.IsHost=false;
    assert(visible()==3 and m.isItemVisible(box) and not m.isItemVisible(inner) and not m.canViewInstance(item));
    assert(read().total_load==originalLoad and #read().items==5);
    local before=test.writes();
    assert(not m.setQuantity(item,2));assert(not m.setState(item,2));assert(not m.transfer(item,owner));
    assert(#m.getLocationOptions(item)==0 and not m.planDeleteInstance(item));
    assert(test.writes()==before);
    for _,option in ipairs(m.getLocationOptions(lamp)) do
        assert(option.linkrecord~=DB.getPath(inner),"Se filtró un destino oculto");
    end
    local draft=m.getInstanceDraft(box);draft.hide_contents=0;
    assert(not m.saveInstance(box,draft,m.getInstanceEditToken(box)));assert(test.writes()==before);
    draft=m.getInstanceDraft(box);draft.name="Caja particular";
    assert(m.saveInstance(box,draft,m.getInstanceEditToken(box))); -- propiedad preservada al editar otros campos
    assert(DB.getValue(box,"properties.hide_contents")==1);
    session.IsHost=true;hide(bag,1);
    session.IsHost=false;assert(visible()==1 and read().total_load==originalLoad);
    session.IsHost=true;hide(bag,0);
    session.IsHost=false;assert(visible()==3 and not m.isItemVisible(item)); -- sigue oculta la Caja
    -- El contenedor visible se puede mover con todo su árbol, sin acceder a sus descendientes.
    assert(m.transfer(box,owner));assert(DB.getValue(box,"properties.hide_contents")==1);
    assert(DB.getValue(inner,"aptus.container")==DB.getName(box));
    assert(DB.getValue(item,"aptus.container")==DB.getName(inner));
    assert(m.setState(box,2));assert(DB.getValue(box,"properties.hide_contents")==1);
    local movedLoad=read().total_load;assert(movedLoad==8);
    session.IsHost=true;hide(box,0);
    session.IsHost=false;assert(visible()==5 and m.canViewInstance(item) and read().total_load==movedLoad);
    session.IsHost=true;
    -- Al dejar de ser contenedor no se conserva una ocultación activa.
    local empty=assert(m.createFromTemplate(owner,boxTemplate));hide(empty,1);
    draft=m.getInstanceDraft(empty);draft.is_container=0;
    assert(m.saveInstance(empty,draft,m.getInstanceEditToken(empty)));
    assert(DB.getValue(empty,"properties.hide_contents")==0);
    -- Un dato antiguo en un no contenedor no activa la política.
    put(lamp,"properties.hide_contents","number",1);
    session.IsHost=false;assert(m.isItemVisible(lamp));
    session.IsHost=true;
    -- La copia existente de un contenedor vacío mantiene la propiedad sin lógica especial.
    local another=test.newCharacter();local portable=assert(m.createFromTemplate(owner,boxTemplate));hide(portable,1);
    local moved=assert(m.transfer(portable,another));assert(DB.getValue(moved,"properties.hide_contents")==1);
    -- El selector de Ubicación cancela su lista aun sin la ficha de personaje abierta.
    session.IsHost=false;
    local closed,nativeCalls=0,0;local env;
    env={DB=DB,Session=session,super={activateNextSelection=function() nativeCalls=nativeCalls+1; end},
        getSelectionQueue=function() return {{options={{linkclass="charsheet",linkrecord=DB.getPath(owner)}}}};end,
        close=function() closed=closed+1;env.onClose();end};
    setmetatable(env,{__index=_G});
    assert(loadfile("scripts/inventory_location_aptus.lua","t",env))();
    before=test.writes();env.activateNextSelection();assert(nativeCalls==1 and test.writes()==before);
    env.onContentsVisibilityChanged();env.onContentsVisibilityChanged();assert(closed==1 and test.writes()==before);
    session.IsHost=true;
    print("OK: ocultación por antecesores, DJ/jugador, guardas, no migraciones, carga íntegra, destinos filtrados y propiedad preservada en movimientos.");
end
