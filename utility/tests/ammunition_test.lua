-- lua utility/tests/ammunition_test.lua. DB simulada de sólo lectura; sin campaña.
local records = {};
local DB = {};
function DB.findNode(path) return records[path]; end
function DB.getChild(node, path) return node and node[path]; end
function DB.getType(node) return node.kind; end
function DB.getValue(node, path, default)
    if path then local child = node[path]; return child and child.value or default; end
    return node.value;
end
function DB.getPath(node) return node.path; end
function DB.getChildrenGlobal(root)
    local result = {};
    for path, node in pairs(records) do if path:match("^" .. root .. "%.") then table.insert(result, node); end end
    return result;
end
local model = setmetatable({DB=DB,RecordDataManager={getDataPaths=function() return {"aptus_equipment_templates"}; end}}, {__index=_G});
assert(loadfile("scripts/manager_aptus_equipment.lua", "t", model))();
model.registerType("ammunition", "Munición"); model.registerType("utility", "Utilidad");
local collections = {qualities={},profiles={}};
local key, profile = model.newProfile(collections.profiles);
assert(model.getProfileAmmunitionConsumption(profile)==0 and model.formatProfileAmmunition(profile)=="");
assert(profile.ammunition_consumption.value==1 and profile.ammunition_template==nil);
model.setEntryValue(profile,"uses_ammunition","number",1);
model.setEntryValue(profile,"ammunition_max","number",10);
assert(model.formatProfileAmmunition(profile)=="Munición: 1/10");
profile.ammunition_consumption=nil;
assert(model.getProfileAmmunitionConsumption(profile)==1 and not model.validateCollections(collections));
assert(profile.ammunition_consumption==nil,"La lectura migró un perfil antiguo");
for _, value in ipairs({1,2,3}) do
    model.setEntryValue(profile,"ammunition_consumption","number",value);
    assert(not model.validateCollections(collections));
    assert(model.formatProfileAmmunition(profile)=="Munición: "..value.."/10");
end
for _, value in ipairs({0,-1,1.5,math.huge}) do
    model.setEntryValue(profile,"ammunition_consumption","number",value);
    assert(model.validateCollections(collections));
end
profile.ammunition_consumption={kind="string",value="1"}; assert(model.validateCollections(collections));
model.setEntryValue(profile,"ammunition_consumption","number",3);
local path="aptus_equipment_templates.id-ammo@Prueba";
profile.ammunition_template={kind="windowreference",class="aptus_equipment",path=path};
assert(not model.validateCollections(collections),"Referencia inaccesible debe conservarse");
assert(model.getProfileAmmunitionName(profile)=="Munición no disponible");
records[path]={path=path,["name"]={kind="string",value="9 mm"},["properties.type_id"]={kind="string",value="ammunition"}};
local utility="aptus_equipment_templates.id-utility";
records[utility]={path=utility,name={kind="string",value="Linterna"},["properties.type_id"]={kind="string",value="utility"}};
assert(model.getProfileAmmunitionName(profile)=="9 mm");
local options=model.getAmmunitionOptions(); assert(#options==1 and options[1].linkrecord==path);
local original=profile.ammunition_template;
model.setEntryValue(profile,"uses_ammunition","number",0);
assert(model.getProfileAmmunitionConsumption(profile)==0 and model.formatProfileAmmunition(profile)=="");
assert(profile.ammunition_template==original and profile.ammunition_consumption.value==3);
model.setEntryValue(profile,"uses_ammunition","number",1);
assert(model.formatProfileAmmunition(profile)=="Munición: 3/10");
profile.ammunition_template=nil; assert(model.getProfileAmmunitionName(profile)=="Sin asignar");
print("OK: consumo, legado sin migración, referencias de módulos/inaccesibles, selector y conservación al desactivar.");
