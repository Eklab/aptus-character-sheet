-- Suite del gestor de producción, ejecutada desde inventory_create_test.lua.
return function(test)
    local m, DB, put = test.manager, test.DB, test.put;
    local function template(id, own, every, capacity)
        local node = test.template("aptus_equipment_templates.capacity_" .. id, "capacity:" .. id);
        put(node,"name","string",id=="bag" and "Mochila" or id);
        put(node,"properties.load_value","number",own);
        put(node,"properties.load_every","number",every);
        if capacity ~= nil then
            put(node,"properties.type_id","string","storage");
            put(node,"properties.is_container","number",1);
            put(node,"properties.capacity","number",capacity);
        else
            put(node,"properties.stackable","number",1);
            put(node,"properties.max_stack","number",50);
        end
        return node;
    end
    local bagTemplate = template("bag",2,1,5);
    local innerTemplate = template("inner",1,1,3);
    local unitTemplate = template("unit",1,1);
    local pileTemplate = template("pile",1,50);
    local function read(character)
        local writes = test.writes();
        local result = m.getCharacterInventory(character);
        assert(test.writes()==writes,"El cálculo de contenedores escribió en DB");
        return result;
    end
    local function find(view,node)
        for _,item in ipairs(view.items) do if item.node==node then return item; end end
        error("Objeto no encontrado");
    end
    for _,case in ipairs({{0,2},{1,2},{4,2},{5,2},{6,8},{7,9}}) do
        local owner=test.newCharacter();local bag=assert(m.createFromTemplate(owner,bagTemplate));
        if case[1]>0 then assert(m.createFromTemplate(owner,unitTemplate,case[1],bag)); end
        local view=read(owner);local item=find(view,bag);
        assert(item.own_load==2 and item.content_load==case[1] and item.capacity_load==5);
        assert(item.effective_load==case[2] and item.load==case[2]);
        assert(view.load_complete and view.total_load==case[2]);
        assert(item.overloaded==(case[1]>5));
        assert(m.getContainerDisplayName(item)=="Mochila ("..case[1].."/5)");
    end
    local owner=test.newCharacter();local bag=assert(m.createFromTemplate(owner,bagTemplate));
    local child=assert(m.createFromTemplate(owner,unitTemplate,6,bag));
    assert(read(owner).total_load==8);
    assert(m.setQuantity(child,5));assert(read(owner).total_load==2 and not find(read(owner),bag).overloaded);
    assert(m.removeUnits(child,5));assert(find(read(owner),bag).content_load==0 and read(owner).total_load==2);
    -- Cada pila usa getStackLoad; no se agregan primero las unidades del mismo tipo.
    assert(m.createFromTemplate(owner,pileTemplate,120,bag));
    local piles=read(owner);assert(find(piles,bag).content_load==3 and piles.total_load==2);
    for _,item in ipairs(piles.items) do if not item.is_container then assert(item.load==m.getStackLoad(item.node)); end end
    -- El Almacenaje interior no se encadena: el padre cuenta CAR íntegra.
    local nested=test.newCharacter();local outer=assert(m.createFromTemplate(nested,bagTemplate));
    local inner=assert(m.createFromTemplate(nested,innerTemplate,1,outer));
    local content=assert(m.createFromTemplate(nested,unitTemplate,2,inner));
    local view=read(nested);
    assert(find(view,inner).content_load==2 and find(view,inner).effective_load==3);
    assert(find(view,outer).content_load==3 and view.total_load==2);
    assert(m.setQuantity(content,4));view=read(nested);
    assert(find(view,inner).effective_load==5 and find(view,outer).content_load==5 and view.total_load==2);
    assert(m.setQuantity(content,5));view=read(nested);
    assert(find(view,inner).effective_load==6 and find(view,outer).content_load==6 and view.total_load==8);
    assert(m.setQuantity(content,3));assert(read(nested).total_load==2);
    assert(m.transfer(content,nested));view=read(nested);
    assert(find(view,inner).content_load==0 and find(view,outer).content_load==1 and view.total_load==5);
    assert(m.transfer(content,nested,nil,inner));assert(read(nested).total_load==2);
    assert(m.transfer(inner,nested));view=read(nested);
    assert(#view.roots==2 and view.total_load==3 and find(view,outer).content_load==0);
    -- Tres niveles: ni Bolsa ni el contenedor intermedio reducen al estar guardados.
    local deep=test.newCharacter();local a=assert(m.createFromTemplate(deep,bagTemplate));
    local b=assert(m.createFromTemplate(deep,innerTemplate,1,a));
    local c=assert(m.createFromTemplate(deep,innerTemplate,1,b));
    local leaf=assert(m.createFromTemplate(deep,unitTemplate,3,c));
    view=read(deep);
    assert(find(view,a).content_load==5 and view.total_load==2);
    assert(find(view,b).effective_load==5 and find(view,c).effective_load==4);
    assert(not find(view,b).reduction_active and not find(view,c).reduction_active);
    assert(m.setQuantity(leaf,4));view=read(deep);
    assert(find(view,a).content_load==6 and view.total_load==8);
    assert(m.setQuantity(leaf,3));assert(read(deep).total_load==2);
    -- Capacidad dinámica, estados y límites exactos usando el gestor real.
    local person=test.newCharacter();local units=assert(m.createFromTemplate(person,unitTemplate,3));
    local capacities={2,4,6,8,10};
    for strength=0,4 do
        put(person,"attributes.fue.effective","number",strength);
        assert(m.getLoadCapacity(person)==capacities[strength+1]);
    end
    put(person,"attributes.fue.effective","number",2);
    for _,case in ipairs({{1,"LIGERO"},{2,"LIGERO"},{3,"CARGADO"},{5,"CARGADO"},{6,"SOBRECARGADO"},{8,"SOBRECARGADO"},{9,"LASTRADO"},{11,"LASTRADO"},{12,"INMOVILIZADO"},{13,"INMOVILIZADO"}}) do
        assert(m.setQuantity(units,case[1]));local writes=test.writes();
        local status=m.getLoadStatus(person,read(person));
        assert(status.complete and status.capacity==6 and status.total_load==case[1]);
        assert(status.state==case[2] and status.fraction==math.min(1,case[1]/12));
        assert(test.writes()==writes,"El estado de carga escribió en DB");
    end
    local images={LIGERO=0,CARGADO=50,SOBRECARGADO=100,LASTRADO=150,INMOVILIZADO=200};
    for _,gender in ipairs({"Masculino","Femenino","", "desconocido", " Femenino "}) do
        put(person,"gender","string",gender);
        for _,amount in ipairs({0,3,6,9,12}) do
            -- Snapshot explícito para probar cero sin crear pilas de cantidad cero.
            local writes=test.writes();
            local status=m.getLoadStatus(person,{total_load=amount,load_complete=true});
            local sex=(gender=="Femenino" or gender==" Femenino ") and "female" or "male";
            assert(status.icon=="aptus_load_"..sex.."_"..images[status.state]);
            assert(status.fraction==math.min(1,amount/12));
            assert(test.writes()==writes);
        end
    end
    DB.deleteChild(person,"gender");
    assert(m.getLoadStatus(person).icon=="aptus_load_male_200");
    -- Fracciones próximas a los límites: no redondear para clasificar.
    for _,case in ipairs({{2.999,"LIGERO"},{5.999,"CARGADO"},{8.999,"SOBRECARGADO"},{11.999,"LASTRADO"}}) do
        assert(m.getLoadStatus(person,{total_load=case[1],load_complete=true}).state==case[2]);
    end
    put(person,"attributes.fue.effective","number",4);
    assert(m.getLoadStatus(person).state=="SOBRECARGADO");
    DB.deleteChild(person,"attributes.fue.effective");
    assert(not m.getLoadStatus(person).complete and m.getLoadCapacity(person)==nil);
    assert(m.getBaseLoadCapacity(-1)==nil and m.getBaseLoadCapacity("2")==nil);
    -- Carga cero sigue siendo conocida; no se transforma en nil ni en carga simulada.
    local zeroTemplate=template("zero",0,1,0);local empty=test.newCharacter();
    assert(m.createFromTemplate(empty,zeroTemplate));assert(read(empty).total_load==0);
    put(empty,"attributes.fue.effective","number",2);
    local emptyStatus=m.getLoadStatus(empty,read(empty));
    assert(emptyStatus.state=="LIGERO" and emptyStatus.fraction==0);
    -- Datos insuficientes: no mostrar una reducción o un total falsamente bajos.
    DB.deleteChild(content,"properties.load_every");view=read(nested);
    assert(not view.load_complete and view.total_load==nil);
    assert(find(view,inner).content_load==nil and find(view,inner).effective_load==nil);
    assert(m.getContainerLoadIndicator(find(view,inner))==" (—/3)");
    put(content,"properties.load_every","number",1);
    -- Las protecciones de ciclos anteriores continúan excluyendo esas ramas.
    put(outer,"aptus.container","string",DB.getName(inner));
    put(inner,"aptus.container","string",DB.getName(outer));
    view=read(nested);assert(view.ignored==3 and not view.load_complete and view.total_load==nil);
    print("OK: gestor real, capacidad reductora completa, igualdad, recuperación, pilas/unidades, anidados, traslados, total sin duplicidades y lectura sin escrituras.");
end
