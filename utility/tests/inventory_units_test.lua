-- Se ejecuta desde inventory_create_test.lua, compartiendo su doble de DB.
-- Todas las operaciones llaman al gestor real; no se replica su algoritmo.
return function(test)
    local m,DB,put=test.manager,test.DB,test.put;
    test.Session.IsHost=true;
    local function makeTemplate(id,maximum,every,kind)
        local node=test.template("reference.aptus_equipment_templates.units_"..id,"module:units:"..id);
        put(node,"properties.type_id","string",kind or "ammunition");
        put(node,"properties.stackable","number",maximum and 1 or 0);
        put(node,"properties.max_stack","number",maximum or 1);
        put(node,"properties.load_every","number",every or 1);
        put(node,"properties.load_value","number",1);
        node.module="Catálogo de prueba"; node.readonly=true;
        return node;
    end
    local ammo=makeTemplate("9mm",50,50);
    local shotgun=makeTemplate("12",25,25);
    local grenade=makeTemplate("grenade",6,3);
    local other=makeTemplate("45",50,50);
    DB.setValue(ammo,"properties.extra_link","windowreference","aptus_equipment",
        "reference.aptus_equipment_templates.units_45@Catálogo de prueba");
    DB.setValue(other,"properties.extra_link","windowreference","aptus_equipment",
        "reference.aptus_equipment_templates.units_45@Catálogo de prueba");
    -- Misma imagen y propiedades; sólo la identidad de plantilla debe separar tipos.
    local sourceToken=m.getInstanceEditToken(ammo);
    local function items(character) return m.getCharacterInventory(character).items; end
    local function counts(character,templateId)
        local values,total={},0;
        for _,entry in ipairs(items(character)) do
            if not templateId or entry.template_id==templateId then
                table.insert(values,entry.count);total=total+entry.count;
                if entry.properties.stackable and entry.properties.stackable.value==1 then
                    assert(entry.count<=entry.properties.max_stack.value,"Se superó max_stack");
                end
            end
        end
        table.sort(values,function(a,b) return a>b; end);
        return table.concat(values,","),total;
    end
    for _,case in ipairs({{ammo,120,"50,50,20"},{shotgun,40,"25,15"},{grenade,10,"6,4"}}) do
        local character=test.newCharacter();assert(m.createFromTemplate(character,case[1],case[2]));
        local sizes,total=counts(character);assert(sizes==case[3] and total==case[2]);
    end
    local character=test.newCharacter();
    local first=assert(m.createFromTemplate(character,ammo,30));
    local linkClass,linkPath=DB.getValue(first,"properties.extra_link");
    assert(linkClass=="aptus_equipment" and linkPath=="reference.aptus_equipment_templates.units_45@Catálogo de prueba");
    assert(m.createFromTemplate(character,ammo,40));
    local sizes,total=counts(character);assert(sizes=="50,20" and total==70);
    assert(DB.getValue(first,"count")==50);
    assert(m.getInstanceEditToken(ammo)==sourceToken,"Se modificó la plantilla");
    local mixed=test.newCharacter();
    local nine=assert(m.createFromTemplate(mixed,ammo,30));
    local fortyFive=assert(m.createFromTemplate(mixed,other,40));
    assert(not m.areStackCompatible(nine,fortyFive));
    assert(#items(mixed)==2 and DB.getValue(nine,"count")==30);
    local before=test.writes();assert(not m.setQuantity(nine,-1));assert(not m.setQuantity(nine,1.5));
    assert(test.writes()==before);
    assert(m.setQuantity(nine,120));assert(select(2,counts(mixed,"module:units:9mm"))==120);
    assert(m.removeUnits(nine,10));assert(select(2,counts(mixed,"module:units:9mm"))==110);
    assert(not m.removeUnits(nine,1000));
    local customized=test.newCharacter();
    local custom=assert(m.createFromTemplate(customized,ammo,30));
    put(custom,"properties.description","string","Particular");
    assert(m.createFromTemplate(customized,ammo,40));assert(counts(customized)=="40,30");
    local stateChar=test.newCharacter();local equipped=assert(m.createFromTemplate(stateChar,ammo,30));
    put(equipped,"carried","number",2);assert(m.createFromTemplate(stateChar,ammo,40));assert(counts(stateChar)=="40,30");
    -- Fusión de dos pilas incompletas creadas por operaciones reales.
    local mergeChar=test.newCharacter();local pile=assert(m.createFromTemplate(mergeChar,ammo,70));
    local second=items(mergeChar)[2].node;assert(m.setQuantity(pile,30));
    assert(m.mergeStacks(second));assert(counts(mergeChar)=="50");
    -- CAR real del lector, aplicado por pila.
    for _,case in ipairs({{ammo,{1,20,50},{1,1,1}},{shotgun,{1,15,25},{1,1,1}},
        {grenade,{1,2,3,4,5,6},{1,1,1,2,2,2}}}) do
        for i,count in ipairs(case[2]) do
            local owner=test.newCharacter();local node=assert(m.createFromTemplate(owner,case[1],count));
            local writes=test.writes();local view=items(owner);
            assert(#view==1 and view[1].load==case[3][i] and m.getStackLoad(node)==case[3][i]);
            assert(test.writes()==writes,"La lectura de carga escribió datos");
        end
    end
    -- Transferencia completa y parcial, con fusión en el destino.
    local from,to=test.newCharacter(),test.newCharacter();
    local moving=assert(m.createFromTemplate(from,ammo,40));assert(m.createFromTemplate(to,ammo,30));
    local oldPath=DB.getPath(moving);assert(m.transfer(moving,to));
    assert(not DB.findNode(oldPath) and #items(from)==0 and counts(to)=="50,20");
    local partial=assert(m.createFromTemplate(from,ammo,50));assert(m.transfer(partial,to,15));
    assert(DB.getValue(partial,"count")==35);assert(select(2,counts(to))==85);
    local bagTemplate=makeTemplate("bag",false,1,"storage");
    put(bagTemplate,"properties.is_container","number",1);
    local owner=test.newCharacter();local bagA=assert(m.createFromTemplate(owner,bagTemplate));
    local bagB=assert(m.createFromTemplate(owner,bagTemplate));put(bagA,"carried","number",2);
    local child=assert(m.createFromTemplate(owner,ammo,30,bagA));
    assert(DB.getValue(child,"aptus.container")==DB.getName(bagA));
    local path=DB.getPath(child);assert(m.transfer(child,owner,nil,bagB));
    assert(DB.findNode(path)==child and DB.getValue(child,"aptus.container")==DB.getName(bagB));
    assert(m.transfer(bagB,owner,nil,bagA));
    local writes=test.writes();assert(not m.transfer(bagA,owner,nil,bagB));assert(test.writes()==writes);
    for _,entry in ipairs(items(owner)) do if entry.node==child then assert(entry.effective_carried==0); end end
    local loadOwner=test.newCharacter();
    local loadBagA=assert(m.createFromTemplate(loadOwner,bagTemplate));
    local loadBagB=assert(m.createFromTemplate(loadOwner,bagTemplate));
    assert(m.createFromTemplate(loadOwner,ammo,1,loadBagA));assert(m.createFromTemplate(loadOwner,ammo,1,loadBagB));
    local ammoLoad=0;
    for _,entry in ipairs(items(loadOwner)) do if entry.template_id=="module:units:9mm" then ammoLoad=ammoLoad+entry.load; end end
    assert(ammoLoad==2,"Se redondearon conjuntamente dos pilas de una unidad");
    writes=test.writes();assert(not m.transfer(bagA,to));assert(test.writes()==writes,"Traslado de árbol no soportado debe ser inofensivo");
    -- No apilables: se mantiene una fila de cantidad múltiple, sin fusión automática.
    local tool=makeTemplate("tool",false,1,"utility");local tools=test.newCharacter();
    local toolA=assert(m.createFromTemplate(tools,tool,7));local toolB=assert(m.createFromTemplate(tools,tool));
    assert(toolA~=toolB and counts(tools)=="7,1");assert(not m.mergeStacks(toolA));
    assert(m.transfer(toolA,to,2));assert(DB.getValue(toolA,"count")==5);
    -- Fallos reales de DB simulados: origen intacto y destino restaurado.
    local failing=test.newCharacter();local existing=assert(m.createFromTemplate(failing,ammo,30));
    test.fail(DB.getPath(existing,"count"));assert(not m.createFromTemplate(failing,ammo,40));
    assert(counts(failing)=="30");
    local failSource=test.newCharacter();local src=assert(m.createFromTemplate(failSource,ammo,40));
    test.fail(DB.getPath(existing,"count"));assert(not m.transfer(src,failing));
    assert(DB.getValue(src,"count")==40 and counts(failing)=="30");
    local empty=test.newCharacter();test.fail(DB.getPath(src));assert(not m.transfer(src,empty));
    assert(DB.getValue(src,"count")==40 and #items(empty)==0);
    local foreign=test.newCharacter();foreign.owner="Bob";test.Session.IsHost=false;
    writes=test.writes();assert(not m.transfer(src,foreign));assert(test.writes()==writes);test.Session.IsHost=true;
    -- Eliminar unidades hasta cero no deja nodos de cantidad cero.
    local remove=test.newCharacter();local last=assert(m.createFromTemplate(remove,grenade,2));
    assert(m.removeUnits(last,2));assert(#items(remove)==0);
    local draft=m.getInstanceDraft(existing);draft.max_stack=20;
    writes=test.writes();assert(not m.saveInstance(existing,draft,m.getInstanceEditToken(existing)));assert(test.writes()==writes);
    assert(m.getInstanceEditToken(ammo)==sourceToken);
    -- Selector de Ubicación: callbacks reales del gestor, sin otra lógica de movimiento.
    local locationOwner=test.newCharacter();put(locationOwner,"name","string","Miguel García");
    local backpack=assert(m.createFromTemplate(locationOwner,bagTemplate));
    put(backpack,"name","string","Mochila");
    local macheteTemplate=makeTemplate("location_machete",false,1,"melee_weapon");
    local machete=assert(m.createFromTemplate(locationOwner,macheteTemplate));put(machete,"name","string","Machete");
    assert(m.createFromTemplate(locationOwner,ammo,120));
    local menu;
    local previousInterface=m.Interface;
    m.Interface={openWindow=function(class,path)
        assert(class=="aptus_inventory_location" and path=="");
        return {requestSelectionByData=function(data) menu=data; end};
    end};
    local function ammoNodes()
        local nodes={};for _,entry in ipairs(items(locationOwner)) do
            if entry.template_id=="module:units:9mm" then table.insert(nodes,entry.node); end
        end;return nodes;
    end
    local piles=ammoNodes();local destinationPath=DB.getPath(backpack);
    local function choose(node,class,path)
        local notified;
        m.requestLocation(node,function(ok) notified=ok; end);
        assert(menu and #menu.options>=2);
        menu.callback({},nil,{{linkclass=class,linkrecord=path}});
        return notified;
    end
    local writesBeforeOptions=test.writes();local options=m.getLocationOptions(piles[1]);
    assert(#options==2 and options[1].text=="Raíz del inventario" and options[2].text=="Mochila");
    assert(test.writes()==writesBeforeOptions);
    assert(choose(piles[1],"aptus_inventory_item",destinationPath));
    assert(DB.getValue(piles[1],"aptus.container")==DB.getName(backpack));
    assert(choose(piles[2],"aptus_inventory_item",destinationPath));
    assert(select(2,counts(locationOwner,"module:units:9mm"))==120);
    assert(choose(piles[1],"charsheet",DB.getPath(locationOwner)));
    assert(select(2,counts(locationOwner,"module:units:9mm"))==120);
    local nestedBag=assert(m.createFromTemplate(locationOwner,bagTemplate,1,backpack));
    assert(#m.getLocationOptions(backpack)==1,"Se ofreció el propio objeto o su descendiente");
    local errorReported;
    m.requestLocation(backpack,function(ok) errorReported=not ok; end);
    local beforeCycle=test.writes();menu.callback({},nil,{{linkclass="aptus_inventory_item",linkrecord=DB.getPath(nestedBag)}});
    assert(errorReported and test.writes()==beforeCycle);
    errorReported=false;
    m.requestLocation(piles[1],function(ok) errorReported=not ok; end);
    put(piles[1],"count","number",DB.getValue(piles[1],"count")-1);
    local beforeStale=test.writes();menu.callback({},nil,{{linkclass="aptus_inventory_item",linkrecord=destinationPath}});
    assert(errorReported and test.writes()==beforeStale,"Un selector obsoleto escribió datos");
    m.Interface=previousInterface;
    print("OK: gestor real: reparto, fusión, límites, conservación, compatibilidad, CAR por pila, transferencias, contenedores, permisos y recuperación.");
end
