-- Motor real de inventario, sobre el DB doble existente y un adaptador de permisos.
-- No ejecuta las ventanas ni simula la red de FGU. Nunca se incluye en extension.xml.
return function(test)
    local m,DB,put,session=test.manager,test.DB,test.put,test.Session;
    local previous=m.APTUSStructureManager;
    local access=false;
    m.APTUSStructureManager={
        isStructure=function(node) return node and DB.getPath(node):match("^aptus_structures%.[^.@]+$")~=nil; end,
        canEdit=function(node) return session.IsHost and not DB.isReadOnly(node); end,
        isFeatureActive=function(node,key) return key=="storage" and DB.getValue(node,"features.storage.enabled",0)==1; end,
        canAccessResources=function(node) return DB.getValue(node,"features.storage.enabled",0)==1 and (session.IsHost or access); end,
    };
    local function template(id,load,capacity,stackable)
        local node=test.template("aptus_equipment_templates.structure_"..id,"structure:"..id);
        put(node,"name","string",id);
        put(node,"properties.load_every","number",1);put(node,"properties.load_value","number",load);
        put(node,"properties.stackable","number",stackable and 1 or 0);
        put(node,"properties.max_stack","number",stackable and 50 or 1);
        if capacity then
            put(node,"properties.type_id","string","storage");put(node,"properties.is_container","number",1);
            put(node,"properties.capacity","number",capacity);
        end
        return node;
    end
    local source,bagTemplate=template("Municion",1,nil,true),template("Mochila",2,5);
    local insideTemplate=template("Caja",1,3);local unitTemplate=template("Objeto",1);
    for _,category in ipairs({"location","vehicle"}) do
        local owner=test.newStructure("test_"..category);put(owner,"type","string",category);
        local before=test.writes();assert(not m.createFromTemplate(owner,source));assert(test.writes()==before);
        put(owner,"features.storage.enabled","number",1);
        local piles=assert(m.createFromTemplate(owner,source,120));
        local view=m.getInventory(owner);assert(#view.items==3);
        local total=0;for _,item in ipairs(view.items) do
            assert(item.carried==0 and item.count<=50 and m.getInventoryOwner(item.node)==owner);
            total=total+item.count;
        end;assert(total==120);
        local bag=assert(m.createFromTemplate(owner,bagTemplate));
        local inner=assert(m.createFromTemplate(owner,insideTemplate,1,bag));
        local child=assert(m.createFromTemplate(owner,unitTemplate,4,inner));
        view=m.getInventory(owner);local outer;
        for _,item in ipairs(view.items) do if item.node==bag then outer=item; end;end
        assert(outer.content_load==5 and outer.effective_load==2,"Se encadenó Almacenaje");
        local draft=m.getInstanceDraft(inner);draft.hide_contents=1;
        assert(m.saveInstance(inner,draft,m.getInstanceEditToken(inner)));
        assert(m.transfer(inner,owner));assert(DB.getValue(inner,"carried")==0);
        assert(DB.getValue(child,"aptus.container")==DB.getName(inner));
        assert(DB.getValue(inner,"properties.hide_contents")==1);
        assert(m.transfer(inner,owner,nil,bag));
        assert(m.setQuantity(child,3));assert(DB.getValue(child,"count")==3);
        local options=m.getLocationOptions(child);assert(options[1].linkclass=="aptus_structure");
        assert(options[1].linkrecord==DB.getPath(owner));
        for _,option in ipairs(options) do assert(option.linkrecord:match("^aptus_structures%."));end
        before=test.writes();assert(not m.setState(bag,2));assert(test.writes()==before);
        local other=test.newStructure("other_"..category);put(other,"type","string",category);
        put(other,"features.storage.enabled","number",1);
        local character=test.newCharacter();
        before=test.writes();assert(not m.transfer(piles,other));assert(not m.transfer(piles,character));
        assert(test.writes()==before,"Se habilitó una transferencia fuera de fase");
        -- Acceso compartido permite consulta, nunca gestión en esta fase.
        session.IsHost=false;access=false;assert(#m.getInventory(owner).items==0);
        access=true;assert(#m.getInventory(owner).items>0);
        assert(m.canViewInstance(bag) and not m.canViewInstance(child));
        before=test.writes();assert(not m.setQuantity(piles,1));assert(not m.transfer(bag,owner));
        assert(test.writes()==before);
        session.IsHost=true;
        draft=m.getInstanceDraft(inner);draft.hide_contents=0;
        assert(m.saveInstance(inner,draft,m.getInstanceEditToken(inner)));
        local plan=assert(m.planDeleteInstance(inner));assert(#plan.entries==2);
        -- Prueba de borrado real con la confirmación ya existente.
        local dialog;local previousDialog=m.DialogManager;
        m.DialogManager={openDialog=function(_,data) dialog=data; end};
        assert(m.requestDeleteInstance(inner));assert(dialog);dialog.fnCallback("ok");
        assert(not DB.findNode(plan.path) and not DB.findNode(DB.getPath(child)));
        m.DialogManager=previousDialog;
        before=test.writes();m.getInventory(owner);assert(test.writes()==before);
        put(owner,"features.storage.enabled","number",0);assert(#m.getInventory(owner).items==0);
        put(owner,"features.storage.enabled","number",1);assert(#m.getInventory(owner).items>0);
    end
    m.APTUSStructureManager=previous;
    print("OK: motor único en Localizaciones/Vehículos, cantidades, anidamiento, Almacenaje, ocultación, permisos, borrado y bloqueo entre inventarios.");
end
