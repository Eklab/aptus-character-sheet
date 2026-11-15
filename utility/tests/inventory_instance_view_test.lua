-- Vista local en memoria. No incluir en extension.xml; no usa campañas ni FGU.
-- Desde character-sheet: lua utility/tests/inventory_instance_view_test.lua
local file=assert(io.open("scripts/record_inventory_item_aptus.lua","r"));
local source=file:read("*a"); file:close();
local fields={{key="name",kind="string",default=""}, {key="type_id",kind="string",default="utility"},
    {key="is_wealth",kind="number",default=0}};
local node={name="Pistola",["properties.type_id"]="ranged_weapon",template_id="test",template_version=1};
local locked,fail,autoLock,now,saves=false,false,false,100,0;
local view,closed,renamed;
local function control()
    local c={value="",visible=true};
    function c.setValue(v) c.value=v; end
    function c.getValue() return c.value; end
    function c.setReadOnly(v) c.readonly=v; end
    function c.setVisible(v) c.visible=v; end
    function c.isVisible() return c.visible; end
    function c.getName() return c.name; end
    function c.sendToBack() end
    function c.setIcon(v) c.icon=v; end
    function c.setFont(v) c.font=v; end
    function c.getFont() return c.font or "aptus_inventory_text"; end
    function c.setTooltipText(v) c.tooltip=v; end
    function c.setAnchor() end
    function c.getSize() return 530,20; end
    function c.setPrototype(v) c.prototype=v; end
    function c.getWindows() return {}; end
    function c.addTextWidget(t)
        local w={text=t.text}; c.widget=w;
        function w.setText(v) w.text=v; end
        function w.setMaxWidth(v) w.maxWidth=v; end
        function w.getSize() return math.min(#w.text*7,w.maxWidth),14; end
        function w.setPosition(...) w.position={...}; end
        return w;
    end
    return c;
end
local damageModel=setmetatable({}, {__index=_G});
assert(loadfile("scripts/manager_aptus_equipment.lua","t",damageModel))();
local equipment={};
function equipment.getFields() return fields; end
function equipment.getEntryValue(t,key,default) return t and t[key] and t[key].value or default; end
function equipment.getTypeName(v) return ({ranged_weapon="Arma de proyectiles",utility="Utilidad",storage="Almacenaje",melee_weapon="Arma CC"})[v]; end
function equipment.getTypes() return {{id="utility",name="Utilidad"},{id="storage",name="Almacenaje"}}; end
local inventory={};
function inventory.canViewInstance() return true; end
function inventory.canEditInstance() return true; end
function inventory.canDeleteInstance() return true; end
function inventory.getEditableFields() return fields; end
function inventory.getInstanceEditToken() return "revision"; end
function inventory.getInstanceDraft()
    return {name=node.name,type_id=node["properties.type_id"],is_wealth=0,collections={qualities={},profiles={}}};
end
function inventory.saveInstance(_,draft)
    saves=saves+1;
    if fail then return false,"Fallo simulado; propiedades conservadas."; end
    node.name=draft.name; node["properties.type_id"]=draft.type_id;
    if autoLock then locked=true; view.update(); end
    view.updateHeader(); -- Simula el observador DB durante la operación.
    return true,"Instancia guardada.";
end
local env={Session={IsHost=true},APTUSInventoryManager=inventory,APTUSEquipmentManager=equipment,
    DB={getValue=function(_,key,default) if key=="locked" then return 0; end; local v=node[key]; if v==nil then return default; end return v; end,
        getPath=function() return "charsheet.test.inventorylist.item"; end},
    os={time=function() return now; end},
    WindowManager={getTopWindow=function() return {isInstanceLocked=function() return locked; end,close=function() closed=true; end,onNameUpdated=function() renamed=true; end}; end},
    getDatabaseNode=function() return node; end};
-- Controles locales del editor: no necesitan implementar el motor gráfico.
for name in source:gmatch('"([%w_]+)"') do env[name]=control(); end
for _,name in ipairs({"metadata","instance_context","requirements_note","page_title","tab_selected","preview",
    "save_button","save_art","discard_button","discard_art","delete_button","quality_list","profile_list","type_change_art",
    "label_hide_contents","draft_hide_contents","draft_picture","draft_capacity","draft_stackable","draft_max_stack","draft_is_container"}) do env[name]=control(); end
for _,f in ipairs(fields) do env["draft_"..f.key]=control(); end
for _,page in ipairs({"data","container","combat","qualities"}) do env["nav_label_"..page]=control(); end
env.getControls=function()
    local controls={};
    for name,c in pairs(env) do if type(c)=="table" and c.setVisible then c.name=name; table.insert(controls,c); end end
    return controls;
end
setmetatable(env,{__index=_G}); env.self=env; view=env;
assert(load(source,"instance view","t",env))();
locked=true; view.onInit();
assert(view.instance_context.value=="","Apertura bloqueada debe estar vacía");
assert(view.metadata.widget.text=="Pistola (Arma de proyectiles)");
assert(view.metadata.widget.maxWidth==530 and view.metadata.tooltip:find("Pistola",1,true));
assert(not view.save_button.visible and not view.discard_button.visible);
locked=false; view.onLockModeChanged();
assert(view.instance_context.value=="Edición activa.");
view.draft_name.setValue("Borrador no confirmado"); view.cycleType();
view.updateHeader(); assert(view.metadata.widget.text=="Pistola (Arma de proyectiles)");
locked=true; view.onLockModeChanged();
assert(view.instance_context.value=="Edición desactivada.");
assert(view.draft_name.value=="Borrador no confirmado" and saves==0);
locked=false; view.update(); view.discard();
assert(view.draft_name.value=="Pistola" and view.metadata.widget.text=="Pistola (Arma de proyectiles)");
assert(view.instance_context.value=="Cambios descartados." and saves==0);
-- Guardado con cambio interno de modo: prevalece confirmación, no el modo.
view.draft_name.setValue("Pistola particular"); view.cycleType(); autoLock=true;
view.save();
assert(view.metadata.widget.text=="Pistola particular (Utilidad)" and renamed);
assert(view.instance_context.value=="Instancia guardada.");
assert(not view.save_button.visible and not view.discard_button.visible);
locked=false; view.update(); assert(view.instance_context.value=="Instancia guardada.");
now=104; locked=true; view.update(); assert(view.instance_context.value=="Edición desactivada.");
-- Error persistente, con causa completa y sin perder el borrador.
locked=false; view.update(); view.draft_name.setValue("No guardar"); fail=true;
view.save();
assert(view.instance_context.value=="No se han podido guardar los cambios.");
assert(view.instance_context.tooltip:find("Fallo simulado",1,true));
assert(view.metadata.widget.text=="Pistola particular (Utilidad)");
now=1000; locked=true; view.update(); locked=false; view.update();
assert(view.instance_context.value=="No se han podido guardar los cambios.");
assert(view.draft_name.value=="No guardar");
view.discard(); assert(view.instance_context.value=="Cambios descartados.");
-- Nombres largos y ventanas independientes/cerradas: sin temporizadores pendientes.
node.name=string.rep("Objeto largo ",60); view.updateHeader();
assert(#view.metadata.tooltip>530 and view.metadata.widget.maxWidth==530);
-- Alternancia especializada: el editor conserva el borrador y no cambia el tipo por traducción.
node.name="Machete"; node["properties.type_id"]="melee_weapon"; locked=false; view.reload();
view.draft_name.setValue("Pendiente sin guardar");
locked=true; view.update();
assert(view.getConsultationClass()=="aptus_item_melee_view");
assert(view.metadata.widget.text=="Machete" and view.consultation.visible and not view.draft_name.visible);
assert(view.consult_background.icon=="aptus_item_melee_background");
locked=false; view.update();
assert(view.draft_name.value=="Pendiente sin guardar" and view.draft_name.visible and not view.consultation.visible);
assert(view.save_button.visible and view.discard_button.visible);
locked=true; node["properties.type_id"]="utility"; view.update();
assert(not view.getConsultationClass() and not view.consultation.visible and view.draft_name.readonly);
-- Consulta real: más de cuatro perfiles, signos, expresiones y cualidades separadas.
local profiles={};
for i=1,6 do profiles["profile_"..i]={name={value="Perfil "..i},attack_skill_id={value="pelea"},
    attack_modifier={value=i==1 and 0 or i==2 and -1 or 1},damage={value="d6"},critical={value="2d8"},qualities={name="Perfil "..i}}; end
damageModel.setProfileDamageType(profiles.profile_2,"slashing",true);
damageModel.setProfileDamageType(profiles.profile_3,"fire",true);
damageModel.setProfileDamageType(profiles.profile_3,"slashing",true);
local qenv={DB=env.DB, APTUSEquipmentManager={getEntryValue=equipment.getEntryValue,formatProfileDamageTypes=damageModel.formatProfileDamageTypes,
    getCollections=function() return {profiles=profiles,qualities={name="Generales"}}; end},
    APTUSInventoryManager=inventory, APTUSSkillsManager={getAttackSkills=function() return {}; end},
    getDatabaseNode=function() return node; end,
    APTUSQualityManager={summary=function(t) return t and t.name or ""; end,details=function(t) return t and ("Detalle "..t.name) or ""; end},
    description=control(),picture=control(),delete_button=control(),message=control(),blocks={rows={}}};
local subscribed;
qenv.APTUSQualityManager.subscribe=function(fn) subscribed=fn; end;
qenv.APTUSQualityManager.unsubscribe=function(fn) assert(fn==subscribed); subscribed=nil; end;
function qenv.blocks.closeAll() qenv.blocks.rows={}; end
function qenv.blocks.createWindow()
    local row={configure=function(kind,data) table.insert(qenv.blocks.rows,{kind=kind,data=data}); end}; return row;
end
setmetatable(qenv,{__index=_G});
assert(loadfile("scripts/item_melee_consultation_aptus.lua","t",qenv))();
node["properties.type_id"]="melee_weapon"; node["properties.description"]="Párrafo uno\nPárrafo dos";
node["properties.picture"]="test:misma-imagen";
qenv.onInit(); qenv.configure({getMessage=function() return "Mensaje","Detalle"; end},false);
assert(qenv.description.value=="Párrafo uno\nPárrafo dos" and qenv.picture.prototype=="test:misma-imagen");
assert(#qenv.blocks.rows==7 and qenv.blocks.rows[7].kind=="general");
assert(qenv.blocks.rows[1].data.skill=="Pelea" and qenv.blocks.rows[2].data.skill=="Pelea -1d" and qenv.blocks.rows[3].data.skill=="Pelea +1d");
assert(qenv.blocks.rows[1].data.damage=="d6" and qenv.blocks.rows[1].data.critical=="2d8");
assert(qenv.blocks.rows[1].data.qualities=="Perfil 1" and qenv.blocks.rows[7].data.qualities=="Generales");
assert(qenv.blocks.rows[1].data.damage_types=="Tipo: Nada");
assert(qenv.blocks.rows[2].data.damage_types=="Tipo: Cortante");
assert(qenv.blocks.rows[3].data.damage_types=="Tipos: Cortante, Fuego");
assert(qenv.message.value=="Mensaje"); qenv.onClose(); assert(not subscribed);
-- El bloque de combate conserva 52 px y recorta sus cualidades; generales separadas.
local rowenv={};
for _,name in ipairs({"profile_art","section_art","section_title","profile_name","skill","damage","critical","profile_qualities","qualities"}) do rowenv[name]=control(); end
rowenv.self=rowenv; setmetatable(rowenv,{__index=_G});
assert(loadfile("scripts/item_melee_block_aptus.lua","t",rowenv))();
local longQualities=string.rep("Cortante, Sangrado, ",40);
rowenv.configure("profile",{name="Corte",skill="Pelea +1d",damage="d6",critical="2d8",qualities=longQualities,details="Descripciones completas"});
assert(rowenv.profile_art.visible and not rowenv.qualities.visible);
assert(rowenv.profile_qualities.widget.maxWidth==381 and rowenv.profile_qualities.tooltip:find("Descripciones completas",1,true));
rowenv.configure("profile",{name="Sin cualidades",skill="Pelea",damage="d4",critical="d8",qualities="",details=""});
assert(rowenv.profile_art.visible and rowenv.profile_qualities.widget.text=="Tipo: Nada · Cualidades: Nada");
rowenv.configure("profile",{name="Corte",skill="Pelea",damage="d6",critical="d8",damage_types="Tipo: Cortante",qualities="Ocultable",details="Detalle de Ocultable"});
assert(rowenv.profile_qualities.widget.text=="Tipo: Cortante · Cualidades: Ocultable");
assert(rowenv.profile_qualities.tooltip:find("Detalle de Ocultable",1,true));
rowenv.configure("profile",{name="Mixto",skill="Pelea",damage="d6",critical="d8",damage_types="Tipos: Cortante, Fuego",qualities="",details=""});
assert(rowenv.profile_qualities.widget.text=="Tipos: Cortante, Fuego · Cualidades: Nada");
rowenv.configure("general",{qualities="Robusta",details="Detalle de Robusta"});
assert(not rowenv.profile_art.visible and rowenv.section_art.visible and rowenv.qualities.value=="Robusta");
view.draft_is_container.setValue(1); view.selectPage("container");
assert(view.label_hide_contents.visible and view.draft_hide_contents.visible);
env.Session.IsHost=false;view.update();assert(not view.label_hide_contents.visible and not view.draft_hide_contents.visible);
env.Session.IsHost=true;view.draft_is_container.setValue(0);view.update();assert(not view.draft_hide_contents.visible);
local message=view.instance_context.value; view.onClose(); view.showMessage("No mostrar","error");
assert(view.instance_context.value==message and not closed);
print("OK: título persistido, recorte nativo configurado, candado, mensajes, prioridad y borradores.");
