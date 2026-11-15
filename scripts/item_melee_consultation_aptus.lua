-- Presentación de melee_weapon sobre las propiedades persistidas de la instancia.
local owner;
local closed = false;
function onInit() APTUSQualityManager.subscribe(refresh); end
function onClose() closed = true; APTUSQualityManager.unsubscribe(refresh); end

function formatSkill(profile)
    local id = APTUSEquipmentManager.getEntryValue(profile, "attack_skill_id", "pelea");
    local label = ({ pelea="Pelea", punteria="Puntería" })[id] or id;
    for _, skill in ipairs(APTUSSkillsManager.getAttackSkills()) do
        if skill.id == id then label = skill.name; break; end
    end
    local modifier = APTUSEquipmentManager.getEntryValue(profile, "attack_modifier", 0);
    if type(modifier) == "number" and modifier == modifier and modifier > -math.huge and modifier < math.huge and modifier ~= 0 then
        label = label .. " " .. (modifier > 0 and "+" or "") .. string.format("%g", modifier) .. "d";
    end
    return label;
end

function refresh()
    if closed or not owner then return; end
    local node = getDatabaseNode();
    if not node or DB.getValue(node, "properties.type_id", "") ~= "melee_weapon" then return; end
    description.setValue(DB.getValue(node, "properties.description", ""));
    picture.setPrototype(DB.getValue(node, "properties.picture", ""));
    -- El lector común de asociaciones se reutiliza sin modificar datos.
    local collections = APTUSEquipmentManager.getCollections(node);
    blocks.closeAll();
    local keys = {};
    for key, profile in pairs(collections.profiles) do
        if type(profile) == "table" and not profile.kind then table.insert(keys, key); end
    end
    table.sort(keys);
    for _, key in ipairs(keys) do
        local profile = collections.profiles[key];
        local row = blocks.createWindow();
        row.configure("profile", {
            name=APTUSEquipmentManager.getEntryValue(profile, "name", ""), skill=formatSkill(profile),
            damage=APTUSEquipmentManager.getEntryValue(profile, "damage", ""),
            critical=APTUSEquipmentManager.getEntryValue(profile, "critical", ""),
            damage_types=APTUSEquipmentManager.formatProfileDamageTypes(profile),
            ammunition=APTUSEquipmentManager.formatProfileAmmunition(profile),
            qualities=APTUSQualityManager.summary(profile.qualities), details=APTUSQualityManager.details(profile.qualities),
        });
    end
    -- Sección posterior al último perfil real: participa en el mismo scroll.
    local general = blocks.createWindow();
    general.configure("general", { qualities=APTUSQualityManager.summary(collections.qualities),
        details=APTUSQualityManager.details(collections.qualities) });
end

function configure(parent)
    owner = parent;
    local text, detail = owner.getMessage();
    setMessage(text, detail);
    refresh();
end
function setMessage(text, detail)
    message.setValue(text or "");
    message.setTooltipText(detail or "");
end
