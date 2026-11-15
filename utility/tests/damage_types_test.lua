-- Prueba aislada: modelo real y editor de perfil con controles en memoria.
-- Desde character-sheet: lua utility/tests/damage_types_test.lua (Lua 5.3/5.4).
-- No cargar en extension.xml. Sin campañas ni escrituras DB.
local model=setmetatable({}, {__index=_G});
assert(loadfile("scripts/manager_aptus_equipment.lua","t",model))();
local ids={"bludgeoning","slashing","piercing","fire","ice","electric","chemical","radiation","supernatural"};
local labels={"Contundente","Cortante","Perforante","Fuego","Hielo","Eléctrico","Químico","Radiación","Sobrenatural"};
local abbreviations={"CON","COR","PER","FUE","HIE","ELE","QUI","RAD","SOB"};
local catalogue=model.getDamageTypes(); assert(#catalogue==9);
for i,t in ipairs(catalogue) do assert(t.id==ids[i] and t.name==labels[i] and t.abbreviation==abbreviations[i]); end
catalogue[1].name="No alterar"; assert(model.getDamageTypes()[1].name=="Contundente");
local collections={}; local key,profile=model.newProfile(collections);
assert(not next(profile.damage_types)); profile.damage_types=nil; -- Perfil antiguo.
assert(model.formatProfileDamageTypes(profile)=="Tipo: Nada");
assert(not model.validateCollections({profiles=collections,qualities={}}));
assert(profile.damage_types==nil,"Leer/validar migró el perfil antiguo");
assert(model.setProfileDamageType(profile,"slashing",true));
assert(model.formatProfileDamageTypes(profile)=="Tipo: Cortante");
assert(model.setProfileDamageType(profile,"slashing",true));
local count=0; for _ in pairs(profile.damage_types) do count=count+1; end; assert(count==1);
assert(model.setProfileDamageType(profile,"fire",true));
assert(model.setProfileDamageType(profile,"piercing",true));
assert(model.formatProfileDamageTypes(profile)=="Tipos: Cortante, Perforante, Fuego");
assert(not model.setProfileDamageType(profile,"unknown",true));
assert(not model.setProfileDamageType(profile,"ice",1));
assert(model.setProfileDamageType(profile,"fire",false));
assert(model.formatProfileDamageTypes(profile)=="Tipos: Cortante, Perforante");
assert(model.setProfileDamageType(profile,"slashing",false));
assert(model.setProfileDamageType(profile,"piercing",false));
assert(profile.damage_types==nil and model.formatProfileDamageTypes(profile)=="Tipo: Nada");
assert(model.validateDamageTypes({unknown={kind="number",value=1}}));
assert(model.validateDamageTypes({slashing={kind="string",value="1"}}));
assert(model.validateDamageTypes({slashing={kind="number",value=0}}));
assert(model.validateDamageTypes({slashing={kind="number",value=1,extra=true}}));
assert(not model.validateDamageTypes(nil) and not model.validateDamageTypes({}));

local editor,controls,canEdit={},{},true;
local function control(name,checkbox)
    local c={value="",name=name}; controls[name]=c;
    function c.setValue(v) c.value=v; if checkbox then editor.damageTypeChanged(name:sub(13),v==1); end end
    function c.getValue() return c.value; end
    function c.setReadOnly(v) c.readonly=v; end
    function c.setVisible(v) c.visible=v; end
    function c.setTooltipText(v) c.tooltip=v; end
    function c.setAnchor(_,_,_,_,v) c.anchor=v; end
    function c.setAnchoredWidth(v) c.width=v; end
    function c.setAnchoredHeight(v) c.height=v; end
    return c;
end
editor.APTUSEquipmentManager=model;
local listener;
editor.APTUSQualityManager={summary=function() return ""; end,details=function() return ""; end,
    subscribe=function(fn) listener=fn; end,unsubscribe=function(fn) assert(fn==listener); listener=nil; end};
editor.createControl=function(template,name) return control(name,template=="aptus_profile_damage_checkbox"); end
for _,name in ipairs({"name","range","attack_modifier","damage","critical","uses_ammunition","ammunition_max","ammunition_consumption"}) do editor["edit_"..name]=control("edit_"..name); end
for _,name in ipairs({"skill_display","skill_change","delete_button","quality_names","ammunition_name",
    "ammunition_select","ammunition_clear","label_ammunition_template","label_ammunition_consumption","label_ammunition_max"}) do editor[name]=control(name); end
editor.self=editor; setmetatable(editor,{__index=_G});
assert(loadfile("scripts/equipment_profile_aptus.lua","t",editor))(); editor.onInit();
local owner={isEditable=function() return canEdit; end};
editor.configure(profile,owner,key,"profile",true);
assert(profile.damage_types==nil,"Inicializar casillas cambió el borrador");
local boxes=0;
for _,id in ipairs(ids) do local c=controls["damage_type_"..id]; assert(c and c.value==0 and c.width==20 and c.height==20); boxes=boxes+1; end
assert(boxes==9);
controls.damage_type_slashing.setValue(1); controls.damage_type_fire.setValue(1);
assert(profile.damage_types.slashing.kind=="number" and profile.damage_types.slashing.value==1);
assert(model.formatProfileDamageTypes(profile)=="Tipos: Cortante, Fuego");
controls.damage_type_slashing.setValue(0); assert(not profile.damage_types.slashing);
editor.setEditable(false); assert(controls.damage_type_ice.readonly);
controls.damage_type_ice.setValue(1); assert(not model.hasProfileDamageType(profile,"ice"));
editor.setEditable(true); canEdit=false; controls.damage_type_ice.setValue(1);
assert(not model.hasProfileDamageType(profile,"ice")); canEdit=true;
-- Descartar/reabrir enlaza un borrador nuevo, sin conservar selecciones locales.
local fresh={}; local freshKey,freshProfile=model.newProfile(fresh); freshProfile.damage_types=nil;
editor.configure(freshProfile,owner,freshKey,"profile",true);
assert(controls.damage_type_fire.value==0 and freshProfile.damage_types==nil);
for _,id in ipairs(ids) do controls["damage_type_"..id].setValue(1); end
assert(model.formatProfileDamageTypes(freshProfile)=="Tipos: "..table.concat(labels,", "));
assert(not model.validateCollections({profiles=fresh,qualities={}}));
-- Los campos condicionales conservan sus valores en el mismo borrador.
assert(not controls.ammunition_name.visible);
editor.edit_uses_ammunition.setValue(1); editor.updateAmmo();
assert(controls.ammunition_name.visible and controls.edit_ammunition_consumption.visible);
editor.edit_ammunition_consumption.setValue(3); editor.capture();
assert(freshProfile.ammunition_consumption.value==3);
freshProfile.ammunition_template={kind="windowreference",class="aptus_equipment",path="aptus_equipment_templates.id-ammo@Prueba"};
editor.edit_uses_ammunition.setValue(0); editor.updateAmmo(); editor.capture();
assert(not controls.ammunition_name.visible and not controls.edit_ammunition_max.visible);
assert(freshProfile.ammunition_consumption.value==3 and freshProfile.ammunition_template.path:find("@Prueba",1,true));
editor.edit_uses_ammunition.setValue(1); editor.updateAmmo(); editor.capture();
assert(freshProfile.ammunition_consumption.value==3);
editor.onClose(); assert(listener==nil);
print("OK: catálogo único, cero/uno/varios, orden, exclusión de duplicados, legado, casillas y borrador local.");
