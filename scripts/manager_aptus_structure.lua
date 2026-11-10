-- Modelo común de Localizaciones y Vehículos. Sin reglas funcionales en fase 1.
local sRoot = "aptus_structures";
local sRecordType = "aptus_structure";
local tTypes, tFeatures = {}, {};
local tCategories = { locations = true, vehicles = true };

local function validId(s)
    return type(s) == "string" and s:match("^[a-z][a-z0-9_]*$") ~= nil;
end

function registerFeature(sId, tDefinition)
    if not validId(sId) or tFeatures[sId] or type(tDefinition) ~= "table"
        or type(tDefinition.name) ~= "string" then return false; end
    tFeatures[sId] = {
        id = sId, name = tDefinition.name,
        implemented = tDefinition.implemented == true,
        status = tDefinition.status,
    };
    return true;
end

function registerType(sId, tDefinition)
    if not validId(sId) or tTypes[sId] or type(tDefinition) ~= "table"
        or not tCategories[tDefinition.category] or type(tDefinition.name) ~= "string"
        or type(tDefinition.icon) ~= "string" or type(tDefinition.skin) ~= "string" then return false; end
    local tInitial = {};
    for _, sFeature in ipairs(tDefinition.initialFeatures or {}) do
        if not validId(sFeature) then return false; end
        table.insert(tInitial, sFeature);
    end
    tTypes[sId] = {
        id = sId, name = tDefinition.name, category = tDefinition.category,
        icon = tDefinition.icon, skin = tDefinition.skin, initialFeatures = tInitial,
    };
    return true;
end

function getType(sId) return tTypes[sId]; end
function getFeature(sId) return tFeatures[sId]; end
function getRootPath() return sRoot; end
function getRecordType() return sRecordType; end

function getTypes(sCategory)
    local tResult = {};
    for _, tType in pairs(tTypes) do
        if not sCategory or tType.category == sCategory then table.insert(tResult, tType); end
    end
    table.sort(tResult, function(a, b) return a.name == b.name and a.id < b.id or a.name < b.name; end);
    return tResult;
end

function getFeatures()
    local tResult = {};
    for _, tFeature in pairs(tFeatures) do table.insert(tResult, tFeature); end
    table.sort(tResult, function(a, b) return a.id < b.id; end);
    return tResult;
end

function getNodeType(node)
    return node and tTypes[DB.getValue(node, "type", "")];
end
function getTypeName(node)
    local tType = getNodeType(node);
    return tType and tType.name or Interface.getString("aptus_structure_type_unavailable");
end
function getCategory(node)
    local tType = getNodeType(node);
    return tType and tType.category or "";
end
function getIcon(node)
    local tType = getNodeType(node);
    return tType and tType.icon or "sidebar_icon_default";
end
function getSkin(node)
    local tType = getNodeType(node);
    return tType and tType.skin or "default";
end
function getIdentity(node) return DB.getValue(node, "identity", ""); end
function isStructure(node)
    return node ~= nil and RecordDataManager.getRecordTypeFromRecordPath(DB.getPath(node)) == sRecordType;
end
function canEdit(node)
    return Session.IsHost and isStructure(node) and not WindowManager.getReadOnlyState(node);
end
function isFeatureEnabled(node, sId)
    return tFeatures[sId] ~= nil and DB.getValue(node, "features." .. sId .. ".enabled", 0) == 1;
end
function isFeatureActive(node, sId)
    local tFeature = tFeatures[sId];
    return tFeature ~= nil and isFeatureImplemented(node, sId) and isFeatureEnabled(node, sId);
end
function isFeatureImplemented(node, sId)
    local tFeature = tFeatures[sId];
    if not tFeature then return false; end
    -- Sólo la vista provisional de Almacenaje de Localizaciones está disponible.
    return tFeature.implemented or (sId == "storage" and getCategory(node) == "locations");
end
function setFeatureEnabled(node, sId, bEnabled)
    local tFeature = tFeatures[sId];
    if not canEdit(node) or not tFeature or (bEnabled and not isFeatureImplemented(node, sId)) then return false; end
    local nValue = bEnabled and 1 or 0;
    if DB.getValue(node, "features." .. sId .. ".enabled", 0) ~= nValue then
        DB.setValue(node, "features." .. sId .. ".enabled", "number", nValue);
    end
    return true;
end
function getFeatureDataNode(node, sId, bCreate)
    if not isStructure(node) or not tFeatures[sId] then return nil; end
    local sPath = "feature_data." .. sId;
    if bCreate then
        if not canEdit(node) or not isFeatureActive(node, sId) then return nil; end
        return DB.createChild(node, sPath);
    end
    return DB.getChild(node, sPath);
end

function createStructure(sTypeId, sCategory)
    local tType = tTypes[sTypeId];
    if not Session.IsHost or not tType or (sCategory and tType.category ~= sCategory) then return nil; end
    -- Validar todo antes de crear el nodo: no se usan tipos provisionales.
    for _, sFeature in ipairs(tType.initialFeatures) do
        if not tFeatures[sFeature] or not tFeatures[sFeature].implemented then return nil; end
    end
    local node = DB.createChild(sRoot);
    if not node then return nil; end
    local bOK = pcall(function()
        DB.setValue(node, "type", "string", sTypeId);
        local sBase = "structure_" .. DB.getName(node);
        local sIdentity, nSuffix = sBase, 2;
        while RecordManager.findRecordByString(sRecordType, "identity", sIdentity) do
            sIdentity = sBase .. "_" .. nSuffix;
            nSuffix = nSuffix + 1;
        end
        DB.setValue(node, "identity", "string", sIdentity);
        DB.setValue(node, "name", "string", tType.name);
        DB.setValue(node, "picture", "token", "");
        DB.setValue(node, "description", "formattedtext", "<p></p>");
        for sId in pairs(tFeatures) do DB.setValue(node, "features." .. sId .. ".enabled", "number", 0); end
        for _, sId in ipairs(tType.initialFeatures) do DB.setValue(node, "features." .. sId .. ".enabled", "number", 1); end
    end);
    if not bOK then
        DB.deleteNode(node);
        return nil;
    end
    RecordManager.onRecordAddEvent(sRecordType, node);
    return node;
end

function beginCreate(sCategory)
    if not Session.IsHost or not tCategories[sCategory] then return; end
    local sClass = sCategory == "locations" and "aptus_structure_type_locations" or "aptus_structure_type_vehicles";
    Interface.openWindow(sClass, "");
end

function onInit()
    registerFeature("storage", { name = Interface.getString("aptus_structure_feature_storage") });
    registerFeature("security", { name = Interface.getString("aptus_structure_feature_security") });
    registerFeature("simple_vehicle", { name = Interface.getString("aptus_structure_feature_simple_vehicle") });
    registerFeature("systems", { name = Interface.getString("aptus_structure_feature_systems"), status = Interface.getString("aptus_structure_under_construction") });
    registerType("location", { name = Interface.getString("aptus_structure_type_location"), category = "locations", icon = "sidebar_icon_recordtype_location", skin = "default", initialFeatures = {} });
    registerType("vehicle", { name = Interface.getString("aptus_structure_type_vehicle"), category = "vehicles", icon = "sidebar_icon_recordtype_vehicle", skin = "default", initialFeatures = {} });
    RecordDataManager.setRecordTypeData(sRecordType, {
        aDataMap = { sRoot }, sRecordDisplayClass = sRecordType,
        -- Dos vistas del mismo registro; los enlaces antiguos siguen siendo válidos.
        aRecordDisplayClasses = { sRecordType, "aptus_location" },
        fRecordDisplayClass = function(v)
            return v and getCategory(v) == "locations" and "aptus_location" or sRecordType;
        end,
        fGetLink = function() return "aptus_locations_index", sRoot; end,
        tOptions = { bHidden = true, bNoDuplicate = true, bNoCategories = true },
    });
    for _, sCategory in ipairs({ "locations", "vehicles" }) do
        RecordIndexViewManager.setRecordTypeView(sRecordType, sCategory, {
            sTitle = Interface.getString("aptus_structure_" .. sCategory),
            aColumns = { { sName = "name", sType = "string", sHeading = Interface.getString("aptus_structure_name"), nWidth = 280 } },
            aFilters = { { sCustom = "aptus_structure_" .. sCategory } }, aGroups = {},
        });
        local sViewCategory = sCategory;
        RecordIndexViewManager.setCustomFilterHandler("aptus_structure_" .. sCategory,
            function(node) return getCategory(node) == sViewCategory; end);
    end
end

function onTabletopInit()
    if Session.IsHost then DB.createNode(sRoot); end
end
