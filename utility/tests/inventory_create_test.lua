-- Pruebas aisladas de fase 2 y eliminación. Desde character-sheet con Lua 5.3/5.4.
-- No incluir en extension.xml ni ejecutar en campaña. DB sólo en memoria.
local roots, writes, fault = {}, 0, nil;
local handlers, deletionOrder = {}, {};
local function fire(path,event)
    local callbacks={};
    for _,fn in ipairs(handlers[path .. ":" .. event] or {}) do table.insert(callbacks,fn); end
    for _,fn in ipairs(callbacks) do fn(); end
end
local Session = { IsHost=true, UserName="Alice" };
local function child(parent, key, kind, value)
    local n = { parent=parent, key=key, path=parent and (parent.path .. "." .. key) or key,
        kind=kind or "node", value=value, children={} };
    if parent then parent.children[key]=n; else roots[key]=n; end
    return n;
end
local function resolve(base, path, create)
    if type(base)=="string" then
        local full=base .. (path and path~="" and "." .. path or "");
        local cursor;
        for key in full:gmatch("[^.]+") do
            local nextNode=cursor and cursor.children[key] or (not cursor and roots[key]);
            if not nextNode and create then nextNode=child(cursor,key); end
            cursor=nextNode;
            if not cursor then return nil; end
        end
        return cursor;
    end
    local cursor=base;
    for key in (path or ""):gmatch("[^.]+") do
        if not cursor then return nil; end
        local nextNode=cursor.children[key];
        if not nextNode and create then nextNode=child(cursor,key); end
        cursor=nextNode;
    end
    return cursor;
end
local function put(base,path,kind,value)
    local n=resolve(base,path,true); n.kind,n.value=kind,value; return n;
end
local DB={};
function DB.getChild(n,p) return resolve(n,p,false); end
function DB.findNode(p) return resolve(p,nil,false); end
function DB.getPath(n,p) return p and n.path .. "." .. p or n.path; end
function DB.getName(n) return n.key; end
function DB.getType(n) return n.kind; end
function DB.getChildren(n,p) local v=resolve(n,p,false); return v and v.children or {}; end
DB.getChildrenGlobal=DB.getChildren;
function DB.getValue(n,p,default)
    local v=resolve(n,p,false);
    if v and v.kind=="windowreference" then return v.value.class,v.value.path; end
    return v and v.value~=nil and v.value or default;
end
function DB.getParent(n) return n.parent; end
function DB.getModule(n) while n do if n.module then return n.module; end n=n.parent; end return ""; end
function DB.isReadOnly(n) while n do if n.readonly then return true; end n=n.parent; end return false; end
function DB.isOwner(n) while n do if n.owner then return n.owner==Session.UserName; end n=n.parent; end return false; end
function DB.createChild(n,p)
    writes=writes+1;
    if p then return resolve(n,p,true); end
    local i=1;
    while n.children[string.format("id-%05d",i)] do i=i+1; end
    return child(n,string.format("id-%05d",i));
end
function DB.setValue(n,p,kind,value,record)
    writes=writes+1;
    if fault and (fault==DB.getPath(n,p) or (fault=="carried" and p=="carried")) then fault=nil; return; end
    return put(n,p,kind,kind=="windowreference" and {class=value,path=record} or value);
end
function DB.addHandler(path,event,fn)
    local key=path .. ":" .. event; handlers[key]=handlers[key] or {}; table.insert(handlers[key],fn);
end
function DB.removeHandler(path,event,fn)
    local list=handlers[path .. ":" .. event] or {};
    for i=#list,1,-1 do if list[i]==fn then table.remove(list,i); end end
end
function DB.deleteNode(n)
    writes=writes+1;
    if fault==n.path then fault=nil; return; end
    if n.parent then n.parent.children[n.key]=nil; else roots[n.key]=nil; end
    table.insert(deletionOrder,n.path);
    fire(n.path,"onDelete");
    if n.parent then fire(n.parent.path,"onChildDeleted"); end
end
function DB.deleteChild(n,p) local v=resolve(n,p,false); if v then DB.deleteNode(v); end end
local function cloneValue(v)
    if type(v)~="table" then return v; end
    local t={}; for k,x in pairs(v) do t[k]=cloneValue(x); end return t;
end
function DB.copyNode(source,target)
    writes=writes+1;
    if fault=="copy" then fault=nil; error("Fallo simulado de copia"); end
    local function copy(a,b)
        b.kind,b.value=a.kind,cloneValue(a.value);
        for key,n in pairs(a.children) do copy(n,child(b,key)); end
    end
    copy(source,target);
end
local common={ DB=DB, Session=Session,
    WindowManager={ getReadOnlyState=function(n) return DB.isReadOnly(n) or DB.getValue(n,"locked",0)==1; end },
    RecordDataManager={ getRecordTypeFromRecordPath=function(path)
        if path:match("^aptus_equipment_templates%.[^.]+$") or path:match("^reference%.aptus_equipment_templates%.[^.]+$") then return "aptus_equipment"; end
        return "";
    end }, Debug={ console=function() end } };
local equipment=setmetatable({}, { __index=function(_,k) return common[k] or _G[k]; end });
assert(loadfile("scripts/manager_aptus_equipment.lua","t",equipment))();
common.APTUSEquipmentManager=equipment;
local manager=setmetatable({}, { __index=function(_,k) return common[k] or _G[k]; end });
assert(loadfile("scripts/manager_aptus_inventory.lua","t",manager))();
local function template(path,id)
    local n=resolve(path,nil,true);
    for _,f in ipairs(equipment.getFields()) do put(n,f.path,f.kind,f.default); end
    put(n,"name","string","Plantilla"); put(n,"properties.description","string","Descripción original");
    put(n,"properties.extra","string","Propiedad particular desconocida");
    put(n,"template_id","string",id); put(n,"template_version","number",3); put(n,"schema_version","number",1);
    return n;
end
local char=resolve("charsheet.id-owner",nil,true); char.owner="Alice";
local legacy=put(char,"inventorylist.legacy","node");
put(legacy,"name","string","Heredado"); put(legacy,"count","number",8); put(legacy,"carried","number",0); put(legacy,"location","string","Plantilla");
local legacyBefore=manager.getInstanceEditToken(legacy);
local source=template("aptus_equipment_templates.id-source","source:1");
local origin=manager.getInstanceEditToken(source);
local a,err=manager.createFromTemplate(char,source); assert(a,err);
local b=assert(manager.createFromTemplate(char,source));
assert(a~=b and a.path~=b.path,"Se apilaron altas independientes");
assert(manager.isInstance(a));
assert(DB.getValue(a,"count")==1 and DB.getValue(a,"carried")==1 and DB.getValue(a,"aptus.container")=="");
assert(DB.getValue(a,"template_id")=="source:1" and DB.getValue(a,"template_version")==3);
assert(DB.getValue(a,"properties.extra")=="Propiedad particular desconocida");
assert(manager.getInstanceEditToken(source)==origin,"La creación modificó la plantilla");
assert(#manager.getCharacterInventory(char).items==2);
assert(manager.getInstanceEditToken(legacy)==legacyBefore,"Se alteró un registro heredado");
local draft=manager.getInstanceDraft(a);
-- Editar una instancia preserva procedencia, cantidad, estado y ubicación.
local token=manager.getInstanceEditToken(a);
draft.name="Nombre particular"; draft.description="Descripción particular"; draft.pro=2;
assert(manager.saveInstance(a,draft,token));
assert(DB.getValue(a,"name")=="Nombre particular" and DB.getValue(a,"properties.defense.pro")==2);
assert(DB.getValue(b,"name")=="Plantilla" and manager.getInstanceEditToken(source)==origin);
assert(DB.getValue(a,"count")==1 and DB.getValue(a,"carried")==1 and DB.getValue(a,"aptus.container")=="");
assert(DB.getValue(a,"template_id")=="source:1" and DB.getValue(a,"template_version")==3);
assert(DB.getValue(a,"properties.extra")=="Propiedad particular desconocida");
-- Cambio posterior de catálogo: no altera ninguna instancia.
put(source,"properties.description","string","Catálogo posterior");
assert(DB.getValue(a,"properties.description")=="Descripción particular");
assert(DB.getValue(b,"properties.description")=="Descripción original");
local current=manager.getInstanceEditToken(a);
local edit=manager.getInstanceDraft(a); edit.count=2;
local nWrites=writes; assert(not manager.saveInstance(a,edit,current)); assert(writes==nWrites);
edit=manager.getInstanceDraft(a); assert(not manager.saveInstance(a,edit,token)); assert(writes==nWrites);
-- Fallo de escritura escalar: restaurar nombre/propiedades, sin tocar otras instancias.
edit=manager.getInstanceDraft(a); edit.name="No guardar"; edit.description="No guardar";
fault=DB.getPath(a,"properties.description");
assert(not manager.saveInstance(a,edit,current)); assert(manager.getInstanceEditToken(a)==current);
-- Fallo sobre ramas antes ausentes: retirar sólo los campos/ramas nuevos.
DB.deleteChild(b,"properties.defense");
local old=manager.getInstanceEditToken(b); edit=manager.getInstanceDraft(b); edit.pro=4; edit.def=5;
fault=DB.getPath(b,"properties.defense.def");
assert(not manager.saveInstance(b,edit,old)); assert(manager.getInstanceEditToken(b)==old);
local function countItems() local n=0; for _ in pairs(DB.getChildren(char,"inventorylist")) do n=n+1; end return n; end
-- Fallo de creación: no dejar una instancia parcial ni borrar las anteriores.
local count=countItems(); fault="copy";
assert(not manager.createFromTemplate(char,source)); assert(countItems()==count);
fault="carried";
assert(not manager.createFromTemplate(char,source)); assert(countItems()==count);
assert(DB.findNode(a.path)==a and DB.findNode(b.path)==b);
-- Fuente inválida / enlace a una instancia / estructura destino: rechazos sin escrituras.
put(source,"schema_version","number",2); nWrites=writes;
assert(not manager.createFromTemplate(char,source)); assert(writes==nWrites);
put(source,"schema_version","number",1); nWrites=writes;
assert(not manager.createFromTemplate(char,a)); assert(writes==nWrites);
assert(not manager.createFromTemplate(char,nil)); assert(writes==nWrites);
put(source,"properties.max_stack","string","1");
assert(not manager.createFromTemplate(char,source)); assert(writes==nWrites);
put(source,"properties.max_stack","number",1);
local conflict=template("reference.aptus_equipment_templates.id-conflict","source:1");
nWrites=writes;
assert(not manager.createFromTemplate(char,source)); assert(writes==nWrites);
DB.deleteNode(conflict); nWrites=writes;
local structure=resolve("aptus_structures.id-test",nil,true);
assert(not manager.createFromTemplate(structure,source)); assert(writes==nWrites);
-- Módulo disponible, sólo lectura: copiar a instancia propia sí está permitido.
local module=template("reference.aptus_equipment_templates.id-module","module:1"); module.module="Prueba"; module.readonly=true;
assert(manager.createFromTemplate(char,module));
local options=manager.getTemplateOptions(); assert(#options==2);
-- La edición del nombre de un contenedor no cambia relaciones por nodo.
local bagTemplate=template("aptus_equipment_templates.id-bag","source:bag");
put(bagTemplate,"properties.type_id","string","storage"); put(bagTemplate,"properties.is_container","number",1);
local bag=assert(manager.createFromTemplate(char,bagTemplate));
local contained=assert(manager.createFromTemplate(char,source));
put(contained,"aptus.container","string",DB.getName(bag));
local bagDraft=manager.getInstanceDraft(bag); bagDraft.name="Bolsa particular";
assert(manager.saveInstance(bag,bagDraft,manager.getInstanceEditToken(bag)));
for _,entry in ipairs(manager.getCharacterInventory(char).items) do
    if entry.path==contained.path then assert(entry.location=="Bolsa particular" and entry.effective_carried==0); end
end
-- Revisión de ficha: candado, colecciones particulares y clasificación opcional.
local unlockedToken=manager.getInstanceEditToken(a);
put(a,"locked","number",1);
assert(manager.getInstanceEditToken(a)==unlockedToken,"El candado invalidó la revisión del borrador");
local lockedDraft=manager.getInstanceDraft(a); lockedDraft.name="No guardar cerrado";
nWrites=writes; assert(not manager.saveInstance(a,lockedDraft,unlockedToken)); assert(writes==nWrites);
put(a,"locked","number",0);
assert(manager.canEditInstance(a));
local sourceBeforeEdit=manager.getInstanceEditToken(source);
local instanceDraft=manager.getInstanceDraft(a);
instanceDraft.is_wealth=1;
local profileKey,profile=equipment.newProfile(instanceDraft.collections.profiles);
equipment.setEntryValue(profile,"name","string","Perfil particular");
instanceDraft.collections.qualities.entry_0001={quality_id={kind="string",value="quality:test"}};
profile.qualities={entry_0001={quality_id={kind="string",value="quality:profile"}}};
local revision=manager.getInstanceEditToken(a);
assert(manager.saveInstance(a,instanceDraft,revision));
assert(DB.getValue(a,"properties.is_wealth")==1);
assert(DB.getValue(a,"properties.profiles." .. profileKey .. ".name")=="Perfil particular");
assert(DB.getValue(a,"properties.qualities.entry_0001.quality_id")=="quality:test");
assert(DB.getValue(a,"properties.profiles." .. profileKey .. ".qualities.entry_0001.quality_id")=="quality:profile");
assert(manager.getInstanceEditToken(source)==sourceBeforeEdit,"La personalización modificó el catálogo");
put(source,"properties.is_wealth","number",0);
assert(DB.getValue(a,"properties.is_wealth")==1,"Riqueza se propagó desde la plantilla");
put(source,"properties.is_wealth","number",1);
local wealthy=assert(manager.createFromTemplate(char,source));
assert(DB.getValue(wealthy,"properties.is_wealth")==1,"No se copió Riqueza al crear");
DB.deleteChild(b,"properties.is_wealth");
nWrites=writes; local absentDraft=manager.getInstanceDraft(b);
assert(absentDraft.is_wealth==0 and writes==nWrites and not DB.getChild(b,"properties.is_wealth"));
-- Valores inválidos de Riqueza/asociaciones se rechazan antes de escribir.
local invalidDraft=manager.getInstanceDraft(a); invalidDraft.is_wealth=2;
nWrites=writes; assert(not manager.saveInstance(a,invalidDraft,manager.getInstanceEditToken(a))); assert(writes==nWrites);
invalidDraft=manager.getInstanceDraft(a);
invalidDraft.collections.qualities.invalid={quality_id={kind="number",value=5}};
assert(not manager.saveInstance(a,invalidDraft,manager.getInstanceEditToken(a))); assert(writes==nWrites);
-- Restauración de colecciones, incluidos los campos particulares desconocidos.
put(a,"properties.profiles." .. profileKey .. ".extra","string","Conservar");
revision=manager.getInstanceEditToken(a); instanceDraft=manager.getInstanceDraft(a);
equipment.setEntryValue(instanceDraft.collections.profiles[profileKey],"name","string","Fallo de colección");
fault=DB.getPath(a,"properties.profiles." .. profileKey .. ".name");
assert(not manager.saveInstance(a,instanceDraft,revision));
assert(manager.getInstanceEditToken(a)==revision,"No se restauraron las colecciones");
instanceDraft=manager.getInstanceDraft(a);
instanceDraft.collections.profiles[profileKey]=nil;
instanceDraft.collections.qualities={};
assert(manager.saveInstance(a,instanceDraft,revision));
assert(not next(DB.getChildren(a,"properties.profiles")) and not next(DB.getChildren(a,"properties.qualities")));
-- No deshacer contención al cambiar propiedades de un contenedor ocupado.
bagDraft=manager.getInstanceDraft(bag); bagDraft.is_container=0;
nWrites=writes; assert(not manager.saveInstance(bag,bagDraft,manager.getInstanceEditToken(bag))); assert(writes==nWrites);
-- Presentación preparada: no se inventa carga acumulada ni se usa cero simulado.
local displayItem={name="Mochila",is_container=true,properties={capacity={kind="number",value=20}}};
assert(manager.getContainerDisplayName(displayItem)=="Mochila");
assert(manager.getContainerDisplayName(displayItem,6)=="Mochila (6/20)");
-- Permisos normales: jugador propietario sí, personaje ajeno no.
Session.IsHost=false;
assert(manager.createFromTemplate(char,source));
local other=resolve("charsheet.id-other",nil,true); other.owner="Bob"; nWrites=writes;
assert(not manager.createFromTemplate(other,source)); assert(writes==nWrites);
assert(manager.canEditInstance(a)); local ownerBefore=char.owner; char.owner="Bob";
assert(not manager.canEditInstance(a)); assert(not manager.saveInstance(a,manager.getInstanceDraft(a),manager.getInstanceEditToken(a)));
char.owner=ownerBefore; char.readonly=true; nWrites=writes;
assert(not manager.createFromTemplate(char,source)); assert(writes==nWrites);
print("APTUS inventario fase 2: altas independientes, permisos, módulos, edición protegida, conservación y recuperación OK");


-- Eliminación funcional adelantada: se reutiliza la misma DB sólo en memoria.
Session.IsHost=true;
local dialogs={};
common.DialogManager={openDialog=function(class,data)
    assert(class=="dialog_okcancel"); table.insert(dialogs,data);
end};
local function answer(result)
    local dialog=table.remove(dialogs,1); assert(dialog,"Falta confirmación nativa");
    dialog.fnCallback(result); return dialog;
end
local serial=0;
local function scenario()
    serial=serial+1;
    local character=resolve("charsheet.delete_" .. serial,nil,true); character.owner="Alice";
    return character;
end
local function item(character,id,name,parent,container,count)
    local n=resolve(character,"inventorylist." .. id,true);
    for key,value in pairs({name=name,template_id="test:delete",["aptus.container"]=parent or "",
        ["properties.type_id"]=container and "storage" or "utility"}) do put(n,key,"string",value); end
    for key,value in pairs({count=count or 1,carried=1,template_version=1,["aptus.instance_schema"]=1,
        ["properties.is_container"]=container and 1 or 0}) do put(n,key,"number",value); end
    return n;
end
local result;
local function request(n,active)
    result=nil;
    return manager.requestDeleteInstance(n,function(ok,message,outcome) result={ok=ok,message=message,outcome=outcome}; end,active);
end
local function untouched(n,token) assert(DB.findNode(n.path)==n and manager.getInstanceEditToken(n)==token); end
local dc=scenario();
local single=item(dc,"one","Pistola"); local duplicate=item(dc,"other","Pistola");
local duplicateToken=manager.getInstanceEditToken(duplicate);
local beforeCancel=manager.getInstanceEditToken(single); nWrites=writes;
assert(manager.planDeleteInstance(single)); assert(writes==nWrites,"Planificar escribió datos");
assert(manager.executeDeletePlan==nil,"Se expuso ejecución sin confirmación");
assert(request(single)); assert(writes==nWrites and dialogs[1].sText:find("¿Quieres eliminar Pistola?",1,true));
answer("cancel"); assert(result.outcome=="cancelled" and writes==nWrites);
untouched(single,beforeCancel); untouched(duplicate,duplicateToken);
assert(request(single)); local firstDialog=answer("ok"); assert(result.ok and not DB.findNode(single.path));
local afterDelete=writes; firstDialog.fnCallback("ok"); assert(writes==afterDelete,"Confirmación duplicada");
untouched(duplicate,duplicateToken);
-- Pila completa y contenedor vacío. El candado de instancia y personaje no bloquea inventario.
local stack=item(dc,"stack","Daga","",false,5);
put(stack,"locked","number",1); put(dc,"locked","number",1);
assert(manager.canDeleteInstance(stack)); assert(request(stack));
assert(dialogs[1].sText:find("Daga ×5",1,true) and dialogs[1].sText:find("5 unidades",1,true));
answer("ok"); assert(result.ok and not DB.findNode(stack.path));
local empty=item(dc,"empty","Mochila","",true);
assert(request(empty)); assert(dialogs[1].sText=="¿Quieres eliminar Mochila?"); answer("ok"); assert(result.ok);
-- Subárbol no ordenado por posición o nombre; hermanos y registros heredados intactos.
local nested=scenario();
local root=item(nested,"zroot","Mochila","",true);
local bag=item(nested,"abag","Bolsa","zroot",true);
local kit=item(nested,"zkit","Botiquín","abag");
local box=item(nested,"box","Caja","abag",true);
local doc=item(nested,"doc","Documento","box");
local light=item(nested,"light","Linterna","zroot");
local unrelated=item(nested,"other","Mochila");
-- El plan de eliminación debe aceptar raíces persistidas sin padre vacío físico.
root.children.aptus.children.container = nil;
unrelated.children.aptus.children.container = nil;
local beforePlan = writes;
local absentParentPlan = assert(manager.planDeleteInstance(root));
assert(#absentParentPlan.entries == 6 and writes == beforePlan);
local old=resolve(nested,"inventorylist.legacy",true); put(old,"name","string","Mochila");
local otherToken,oldToken=manager.getInstanceEditToken(unrelated),manager.getInstanceEditToken(old);
-- Cargar el controlador real de ventana para verificar cierre mediante onDelete.
local function openInstance(n)
    local w={getDatabaseNode=function() return n; end,super={onInit=function() end},content={setValue=function() end}};
    function w.close() w.closed=true; w.onClose(); end
    setmetatable(w,{__index=function(_,key) return common[key] or _G[key]; end});
    assert(loadfile("scripts/inventory_item_window_aptus.lua","t",w))(); w.onInit(); return w;
end
local rootWindow,childWindow=openInstance(root),openInstance(doc);
-- Cargar los observadores reales de EQUIPO; sustituir sólo el renderizado FGU.
local refreshes=0;
local pane={getDatabaseNode=function() return nested; end,load_fill={setVisible=function() end}};
setmetatable(pane,{__index=function(_,key) return common[key] or _G[key]; end});
assert(loadfile("scripts/char_equipment_aptus.lua","t",pane))();
pane.refreshPreview=function() refreshes=refreshes+1; end; pane.selectView=function() end;
pane.onInit();
assert(request(root)); assert(dialogs[1].sText:find("Registros afectados: 6",1,true));
deletionOrder={}; answer("ok"); assert(result.ok and rootWindow.closed and childWindow.closed);
assert(refreshes==6,"EQUIPO no recibió todas las eliminaciones"); pane.onClose();
local positions={}; for index,path in ipairs(deletionOrder) do positions[path]=index; end
assert(positions[doc.path]<positions[box.path] and positions[box.path]<positions[bag.path] and positions[bag.path]<positions[root.path]);
assert(positions[kit.path]<positions[bag.path] and positions[light.path]<positions[root.path]);
for _,n in ipairs({root,bag,kit,box,doc,light}) do assert(not DB.findNode(n.path)); end
untouched(unrelated,otherToken); untouched(old,oldToken);
-- Sin límite lógico de profundidad: 300 contenedores en cadena, recorrido iterativo.
local deep=scenario(); local top,last;
for i=1,300 do
    local id="depth_" .. i; local n=item(deep,id,"Contenedor",last and DB.getName(last) or "",true);
    top=top or n; last=n;
end
assert(#assert(manager.planDeleteInstance(top)).entries==300);
assert(request(top)); answer("ok"); assert(result.ok and not next(DB.getChildren(deep,"inventorylist")));
-- Referencia padre inválida, hijo heredado, no contenedor y ciclos: ningún borrado.
local invalid=scenario(); local orphan=item(invalid,"orphan","Objeto","missing");
nWrites=writes; assert(not request(orphan)); assert(result.outcome=="error" and writes==nWrites and #dialogs==0);
local parent=item(invalid,"parent","Contenedor","",true);
local legacyChild=resolve(invalid,"inventorylist.oldchild",true); put(legacyChild,"aptus.container","string","parent");
nWrites=writes; assert(not request(parent)); assert(writes==nWrites and DB.findNode(legacyChild.path));
DB.deleteNode(legacyChild);
local plain=item(invalid,"plain","Sin contenedor"); item(invalid,"child","Hijo","plain");
nWrites=writes; assert(not request(plain)); assert(writes==nWrites);
local cycleA=item(invalid,"cycleA","A","cycleB",true); item(invalid,"cycleB","B","cycleA",true);
nWrites=writes; assert(not request(cycleA)); assert(writes==nWrites);
-- Una relación APTUS ilegible impide excluir con seguridad un posible descendiente.
local malformed=item(invalid,"malformed","Relación ilegible"); put(malformed,"aptus.container","number",4);
nWrites=writes; assert(not request(parent)); assert(writes==nWrites);
-- Cambios mientras se confirma: replanificar y pedir otra confirmación, nunca reutilizarla.
local change=scenario(); local changing=item(change,"root","Mochila","",true);
assert(request(changing)); local added=item(change,"new","Nuevo","root"); nWrites=writes;
answer("ok"); assert(writes==nWrites and result==nil and #dialogs==1);
assert(dialogs[1].sText:find("ha cambiado",1,true) and dialogs[1].sText:find("Registros afectados: 2",1,true));
answer("cancel"); assert(DB.findNode(changing.path) and DB.findNode(added.path));
assert(request(changing)); put(added,"count","number",7); nWrites=writes;
answer("ok"); assert(writes==nWrites and #dialogs==1); answer("ok"); assert(result.ok);
local movedRoot=item(change,"mroot","Bolsa","",true); local moved=item(change,"mchild","Objeto","mroot");
assert(request(movedRoot)); put(moved,"aptus.container","string",""); nWrites=writes;
answer("ok"); assert(writes==nWrites and #dialogs==1); answer("ok");
assert(result.ok and DB.findNode(moved.path),"Se borró un objeto que salió del subárbol");
-- Cambiar únicamente el candado no invalida una confirmación.
assert(request(moved)); put(moved,"locked","number",1); answer("ok"); assert(result.ok and #dialogs==0);
-- Permisos de propietario, ajeno, read-only y revocación durante la confirmación.
local permissions=scenario(); local own=item(permissions,"own","Propio"); Session.IsHost=false;
assert(manager.canDeleteInstance(own)); assert(request(own)); answer("cancel");
permissions.owner="Bob"; nWrites=writes; assert(not request(own)); assert(writes==nWrites);
permissions.owner="Alice"; own.readonly=true; assert(not request(own)); own.readonly=nil;
local noPermission=item(permissions,"restricted","Contenido","own"); put(own,"properties.is_container","number",1);
noPermission.owner="Bob"; nWrites=writes; assert(not request(own)); assert(writes==nWrites);
noPermission.owner="Alice"; assert(request(own)); permissions.owner="Bob"; nWrites=writes;
answer("ok"); assert(not result.ok and writes==nWrites); permissions.owner="Alice";
-- Ficha cerrada mientras se confirma: cancelación sin escrituras.
assert(request(own,function() return false; end)); nWrites=writes; answer("ok"); assert(writes==nWrites);
Session.IsHost=true;
-- Fallo de borrado tras una hoja: detenerse y conservar padre/hermanos restantes.
local failure=scenario(); local failRoot=item(failure,"root","Contenedor","",true);
local leafA=item(failure,"a","A","root"); local leafB=item(failure,"b","B","root");
assert(request(failRoot)); fault=leafA.path; answer("ok");
assert(not result.ok and result.message:find("1 de 3",1,true));
assert(DB.findNode(failRoot.path) and DB.findNode(leafA.path) and not DB.findNode(leafB.path));
-- Fixture final íntegro: las referencias restantes tienen un padre presente.
assert(#manager.getCharacterInventory(failure).items==2);
untouched(duplicate,duplicateToken); untouched(unrelated,otherToken); untouched(old,oldToken);
print("APTUS eliminación: confirmación, cancelación, pilas, subárboles, ciclos, concurrencia, permisos, ventanas y EQUIPO OK");


-- Nuevas aperturas: bloqueo local incluso si locked persistido es cero/ausente.
local openingChar=scenario(); local openingItem=item(openingChar,"opening","Apertura");
local openingToken=manager.getInstanceEditToken(openingItem); nWrites=writes;
local openingWindow=openInstance(openingItem);
assert(openingWindow.isInstanceLocked() and writes==nWrites);
assert(not DB.getChild(openingItem,"locked"),"Abrir materializó el candado en DB");
untouched(openingItem,openingToken);
openingWindow.onInstanceLockChanged(false);
assert(not openingWindow.isInstanceLocked() and writes==nWrites);
openingWindow.onInstanceLockChanged(true); assert(openingWindow.isInstanceLocked());
assert(DB.getValue(openingItem,"locked")==1);
openingWindow.onInstanceLockChanged(false); assert(DB.getValue(openingItem,"locked")==0);
openingWindow.close(); nWrites=writes;
local reopened=openInstance(openingItem); assert(reopened.isInstanceLocked() and writes==nWrites);
-- Botón nativo: inicializar y sincronizar iconos no ejecuta el gesto manual.
local presses=0;
local button={};
function button.setValue(v) button.value=v; if button.onValueChanged then button.onValueChanged(); end end
function button.getValue() return button.value; end
function button.setColor() end
button.self=button;
button.window={};
button.ToolbarManager={initButtonField=function(_,key) assert(key=="locked"); end};
button.ColorManager={getWindowMenuIconColor=function() return "FF000000"; end};
button.WindowManager={getTopWindow=function() return {onInstanceLockChanged=function() presses=presses+1; end}; end};
setmetatable(button,{__index=_G});
assert(loadfile("scripts/inventory_item_lock_aptus.lua","t",button))();
button.onInit(); assert(button.value==1 and presses==0 and writes==nWrites);
button.setLocked(false); assert(button.value==0 and presses==0);
button.setValue(1); assert(presses==1);
reopened.close();
print("APTUS apertura: candado local inicialmente cerrado sin escrituras, reapertura y sincronización de botón OK");

-- Colección de tipos de daño copiada de plantilla a instancias, sin vinculación.
local damageSource=template("aptus_equipment_templates.damage_source","source:damage_types");
local damagePrefix="properties.profiles.entry_0001.";
for key,value in pairs({profile_id="attack",name="Corte",damage="d6",critical="2d8",attack_skill_id="pelea"}) do
    put(damageSource,damagePrefix..key,"string",value);
end
put(damageSource,damagePrefix.."damage_types.slashing","number",1);
put(damageSource,damagePrefix.."damage_types.fire","number",1);
local sourceDamageToken=manager.getInstanceEditToken(damageSource);
local damageCharacter=scenario();
local damageInstance=assert(manager.createFromTemplate(damageCharacter,damageSource));
local damageSibling=assert(manager.createFromTemplate(damageCharacter,damageSource));
assert(manager.getInstanceEditToken(damageSource)==sourceDamageToken);
assert(DB.getValue(damageInstance,damagePrefix.."damage_types.slashing")==1);
local damageEdit=manager.getInstanceDraft(damageInstance);
local damageEntry=damageEdit.collections.profiles.entry_0001;
assert(equipment.formatProfileDamageTypes(damageEntry)=="Tipos: Cortante, Fuego");
local instanceDamageToken=manager.getInstanceEditToken(damageInstance); nWrites=writes;
equipment.setProfileDamageType(damageEntry,"slashing",false);
equipment.setProfileDamageType(damageEntry,"piercing",true);
assert(writes==nWrites and manager.getInstanceEditToken(damageInstance)==instanceDamageToken);
assert(manager.saveInstance(damageInstance,damageEdit,instanceDamageToken));
local reopenedDamage=manager.getInstanceDraft(damageInstance).collections.profiles.entry_0001;
assert(equipment.formatProfileDamageTypes(reopenedDamage)=="Tipos: Perforante, Fuego");
assert(manager.getInstanceEditToken(damageSource)==sourceDamageToken);
assert(DB.getValue(damageSibling,damagePrefix.."damage_types.slashing")==1);
assert(DB.getValue(damageInstance,damagePrefix.."damage")=="d6" and DB.getValue(damageInstance,damagePrefix.."critical")=="2d8");
put(damageSource,damagePrefix.."damage_types.chemical","number",1);
assert(not DB.getChild(damageInstance,damagePrefix.."damage_types.chemical"));
assert(not DB.getChild(damageSibling,damagePrefix.."damage_types.chemical"));
-- Fallo al guardar la colección nueva: se conserva el perfil anterior completo.
instanceDamageToken=manager.getInstanceEditToken(damageInstance);
damageEdit=manager.getInstanceDraft(damageInstance);
equipment.setProfileDamageType(damageEdit.collections.profiles.entry_0001,"ice",true);
fault=DB.getPath(damageInstance,damagePrefix.."damage_types.ice");
assert(not manager.saveInstance(damageInstance,damageEdit,instanceDamageToken));
assert(manager.getInstanceEditToken(damageInstance)==instanceDamageToken);
print("OK: tipos de daño copiados, edición independiente, reapertura, descarte local y recuperación.");

-- Pruebas funcionales del gestor real sobre el doble DB ya utilizado por la suite.
assert(loadfile("utility/tests/inventory_units_test.lua"))()({
    manager=manager, equipment=equipment, DB=DB, Session=Session, newCharacter=scenario,
    template=template, put=put, writes=function() return writes; end,
    fail=function(path) fault=path; end,
    dialogs=common.DialogManager,
});
assert(loadfile("utility/tests/inventory_container_load_test.lua"))()({
    manager=manager, DB=DB, newCharacter=scenario, template=template, put=put,
    writes=function() return writes; end,
});

assert(loadfile("utility/tests/inventory_state_test.lua"))()({
    manager=manager, DB=DB, Session=Session, newCharacter=scenario, template=template, put=put,
    writes=function() return writes; end, fail=function(path) fault=path; end,
});

assert(loadfile("utility/tests/inventory_hidden_contents_test.lua"))()({
    manager=manager, DB=DB, Session=Session, newCharacter=scenario, template=template, put=put,
    writes=function() return writes; end,
});
